#include "cfs.h"

#include <algorithm>
#include <cmath>
#include <set>
#include <sstream>
#include <utility>

namespace {

// kernel/sched/core.c, sched_prio_to_weight[40], nice -20 .. 19.
constexpr int kPrioToWeight[40] = {
    88761, 71755, 56483, 46273, 36291,
    29154, 23254, 18705, 14949, 11916,
    9548,  7620,  6100,  4904,  3906,
    3121,  2501,  1991,  1586,  1277,
    1024,  820,   655,   526,   423,
    335,   272,   215,   172,   137,
    110,   87,    70,    56,    45,
    36,    29,    23,    18,    15,
};
constexpr double kNice0Weight = 1024.0;

std::string oneDecimal(double v) {
    std::ostringstream oss;
    oss.precision(1);
    oss << std::fixed << v;
    return oss.str();
}

}  // namespace

CfsParams resolveCfs(const CfsConfig& config, int workloadQuantum) {
    CfsParams p;
    p.minGranularity = std::max(1, config.minGranularity > 0 ? config.minGranularity : workloadQuantum);
    p.targetLatency = config.targetLatency > 0 ? config.targetLatency : 8 * p.minGranularity;
    p.wakeupGranularity = config.wakeupGranularity > 0
                              ? config.wakeupGranularity
                              : std::max(1, static_cast<int>(std::lround(p.minGranularity * 4.0 / 3.0)));
    return p;
}

int cfsWeight(int nice) {
    return kPrioToWeight[std::clamp(nice, -20, 19) + 20];
}

// Folds CPU used since the last look into vruntime (Linux's update_curr).
void CFSScheduler::update(const Process& p) {
    Entity& e = entities_.at(p.pid);
    const int consumed = p.burstTime - p.remainingTime;
    e.vruntime += (consumed - e.lastConsumed) * kNice0Weight / e.weight;
    e.lastConsumed = consumed;
}

// min_vruntime only ever moves forward, and follows the smallest vruntime
// among processes already on the run queue (update_min_vruntime).
void CFSScheduler::raiseMinVruntime(const std::vector<const Process*>& runnable) {
    bool any = false;
    double lowest = 0.0;
    for (const Process* p : runnable) {
        if (!known(p->pid)) continue;
        const double v = entities_.at(p->pid).vruntime;
        if (!any || v < lowest) lowest = v;
        any = true;
    }
    if (any) minVruntime_ = std::max(minVruntime_, lowest);
}

// A new arrival joins at min_vruntime: far enough forward that it cannot
// monopolise the CPU to "catch up", not so far that it waits behind everyone.
void CFSScheduler::place(const Process& p) {
    Entity e;
    e.vruntime = minVruntime_;
    e.weight = cfsWeight(p.nice);
    e.lastConsumed = p.burstTime - p.remainingTime;
    entities_.emplace(p.pid, e);
}

int CFSScheduler::selectNext(std::vector<Process>& readyQueue, int currentTick) {
    lastDecision_ = DecisionLog{currentTick, -1, {}, {}};
    if (readyQueue.empty()) {
        preemptedPid_ = -1;
        return -1;
    }

    std::vector<const Process*> runnable;
    for (const Process& p : readyQueue) {
        runnable.push_back(&p);
        if (known(p.pid)) update(p);
    }
    raiseMinVruntime(runnable);
    for (const Process& p : readyQueue) {
        if (!known(p.pid)) place(p);
    }

    // The timeline: an ordered set keyed on (vruntime, pid). Its first
    // element is the leftmost node — the next process to run. Ties go to the
    // lowest PID, as everywhere else in ChronOS.
    std::set<std::pair<double, int>> timeline;
    double totalWeight = 0.0;
    for (const Process& p : readyQueue) {
        const Entity& e = entities_.at(p.pid);
        timeline.emplace(e.vruntime, p.pid);
        totalWeight += e.weight;
        lastDecision_.candidates.push_back(Candidate{p.pid, e.vruntime, p.basePriority, p.remainingTime,
                                                     processClassToString(p.predictedClass)});
    }
    const int chosen = timeline.begin()->second;
    const Entity& winner = entities_.at(chosen);

    // sched_slice(): the period stretches once there are more runnable
    // processes than fit in the target latency at minimum granularity.
    const int nr = static_cast<int>(readyQueue.size());
    const int period = std::max(params_.targetLatency, nr * params_.minGranularity);
    const double share = period * winner.weight / totalWeight;
    lastSlice_ = std::max({1, params_.minGranularity, static_cast<int>(std::lround(share))});

    std::vector<std::string>& tags = lastDecision_.reasonTags;
    tags.push_back(nr == 1 ? "only_candidate" : "lowest_vruntime");
    tags.push_back("vruntime:" + oneDecimal(winner.vruntime));
    if (nr > 1) tags.push_back("next_vruntime:" + oneDecimal(std::next(timeline.begin())->first));
    const Process& w = *std::find_if(readyQueue.begin(), readyQueue.end(),
                                     [&](const Process& p) { return p.pid == chosen; });
    tags.push_back("nice:" + std::to_string(w.nice) + "_weight_" + std::to_string(winner.weight));
    tags.push_back("slice:" + std::to_string(lastSlice_) + "_of_" + std::to_string(period));
    if (preemptedPid_ != -1) tags.push_back("wakeup_preempted:P" + std::to_string(preemptedPid_));

    preemptedPid_ = -1;
    lastDecision_.chosen = chosen;
    return chosen;
}

int CFSScheduler::currentQuantum(const Process&) const {
    return lastSlice_;
}

// check_preempt_wakeup(): only a process that has just joined the run queue
// can preempt mid-slice. Everyone else waits for the slice to end.
bool CFSScheduler::shouldPreempt(const Process& running, const std::vector<Process>& readyQueue,
                                 int) {
    update(running);

    std::vector<const Process*> runnable{&running};
    for (const Process& p : readyQueue) runnable.push_back(&p);
    raiseMinVruntime(runnable);

    bool preempt = false;
    const double runningV = entities_.at(running.pid).vruntime;
    for (const Process& p : readyQueue) {
        if (known(p.pid)) continue;
        place(p);
        const Entity& e = entities_.at(p.pid);
        const double gran = params_.wakeupGranularity * kNice0Weight / e.weight;
        if (runningV - e.vruntime > gran) preempt = true;
    }
    if (preempt) preemptedPid_ = running.pid;
    return preempt;
}

DecisionLog CFSScheduler::explainLastDecision() const {
    return lastDecision_;
}
