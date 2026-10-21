#include "mlfq.h"

#include <algorithm>
#include <utility>

MlfqParams resolveMlfq(const MlfqConfig& config, int workloadQuantum) {
    const int levels = config.levels > 0 ? std::clamp(config.levels, 2, 8) : 3;
    const int base = std::max(1, config.baseQuantum > 0 ? config.baseQuantum : workloadQuantum);

    MlfqParams p;
    for (int i = 0; i < levels; ++i) p.quanta.push_back(base << i);
    p.boostInterval = config.boostInterval > 0 ? config.boostInterval : 10 * base;
    return p;
}

MLFQScheduler::MLFQScheduler(MlfqParams params)
    : params_(std::move(params)), nextBoost_(params_.boostInterval) {}

MLFQScheduler::Track& MLFQScheduler::track(const Process& p) {
    auto it = tracks_.find(p.pid);
    if (it == tracks_.end()) {
        // Rule 3: a process the scheduler has never seen starts in Q0.
        Track t;
        t.lastConsumed = p.burstTime - p.remainingTime;
        it = tracks_.emplace(p.pid, t).first;
    }
    return it->second;
}

int MLFQScheduler::levelOf(const Process& p) const {
    auto it = tracks_.find(p.pid);
    return it == tracks_.end() ? 0 : it->second.level;
}

// Folds the CPU a process has used since it was last looked at into its
// allotment, and applies rule 4. Usage is read off remainingTime, so the
// scheduler needs no extra signal from the simulator about slice ends.
void MLFQScheduler::account(const Process& p) {
    Track& t = track(p);
    const int consumed = p.burstTime - p.remainingTime;
    t.used += consumed - t.lastConsumed;
    t.lastConsumed = consumed;

    const int lastLevel = static_cast<int>(params_.quanta.size()) - 1;
    if (t.used >= params_.quanta[static_cast<size_t>(t.level)]) {
        if (t.level < lastLevel) {
            ++t.level;
            pendingEvents_.push_back("demoted:P" + std::to_string(p.pid) + "_to_Q" +
                                     std::to_string(t.level));
        }
        t.used = 0;  // a fresh allotment at the new level (or another bottom-queue turn)
    }
}

// Rule 5. Idempotent within a tick, so it is safe to call from both
// selectNext() and shouldPreempt().
void MLFQScheduler::applyBoost(int currentTick, const Process* running) {
    bool boosted = false;
    while (currentTick >= nextBoost_) {
        nextBoost_ += params_.boostInterval;
        boosted = true;
    }
    if (!boosted) return;

    for (auto& entry : tracks_) {
        entry.second.level = 0;
        entry.second.used = 0;
    }
    // The running process's CPU since its last accounting belongs to the
    // level it has just left, so it does not count against its new Q0
    // allotment.
    if (running) track(*running).lastConsumed = running->burstTime - running->remainingTime;
    pendingEvents_.push_back("priority_boost");
}

int MLFQScheduler::selectNext(std::vector<Process>& readyQueue, int currentTick) {
    lastDecision_ = DecisionLog{currentTick, -1, {}, {}};

    for (const Process& p : readyQueue) account(p);
    applyBoost(currentTick, nullptr);

    if (readyQueue.empty()) {
        pendingEvents_.clear();
        preemptedPid_ = -1;
        return -1;
    }

    // Rules 1 + 2: the highest non-empty queue, first in arrival-to-queue
    // order. readyQueue is FIFO (the simulator only ever appends), so the
    // first process found at the best level is the one that has waited
    // there longest.
    const Process* best = nullptr;
    int bestLevel = 0;
    int sameLevel = 0;
    for (const Process& p : readyQueue) {
        const int lvl = levelOf(p);
        if (best == nullptr || lvl < bestLevel) {
            best = &p;
            bestLevel = lvl;
        }
    }
    for (const Process& p : readyQueue) {
        if (levelOf(p) == bestLevel) ++sameLevel;
        lastDecision_.candidates.push_back(Candidate{p.pid, static_cast<double>(levelOf(p)),
                                                     p.basePriority, p.remainingTime,
                                                     processClassToString(p.predictedClass)});
    }

    const Track& t = tracks_.at(best->pid);
    std::vector<std::string>& tags = lastDecision_.reasonTags;
    tags.push_back(readyQueue.size() == 1 ? "only_candidate" : "highest_queue");
    tags.push_back("queue:Q" + std::to_string(bestLevel));
    tags.push_back("allotment:" + std::to_string(params_.quanta[static_cast<size_t>(bestLevel)] - t.used) +
                   "_of_" + std::to_string(params_.quanta[static_cast<size_t>(bestLevel)]));
    if (sameLevel > 1) tags.push_back("round_robin_in_queue");
    if (preemptedPid_ != -1) tags.push_back("preempted:P" + std::to_string(preemptedPid_));
    for (const std::string& e : pendingEvents_) tags.push_back(e);

    pendingEvents_.clear();
    preemptedPid_ = -1;
    lastDecision_.chosen = best->pid;
    return best->pid;
}

int MLFQScheduler::currentQuantum(const Process& running) const {
    auto it = tracks_.find(running.pid);
    if (it == tracks_.end()) return std::max(1, params_.quanta.front());
    const Track& t = it->second;
    return std::max(1, params_.quanta[static_cast<size_t>(t.level)] - t.used);
}

bool MLFQScheduler::shouldPreempt(const Process& running, const std::vector<Process>& readyQueue,
                                  int currentTick) {
    applyBoost(currentTick, &running);
    const int runningLevel = levelOf(running);
    for (const Process& p : readyQueue) {
        if (levelOf(p) < runningLevel) {
            preemptedPid_ = running.pid;
            return true;
        }
    }
    return false;
}

DecisionLog MLFQScheduler::explainLastDecision() const {
    return lastDecision_;
}
