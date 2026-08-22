#include "priority.h"

// Priority scheduling (non-preemptive) with basic fixed-interval aging:
// effective priority = basePriority + floor(waitingTime / AGING_INTERVAL).
// Highest effective priority wins, lowest PID breaks ties.
int PriorityScheduler::selectNext(std::vector<Process>& readyQueue, int currentTick) {
    lastDecision_ = DecisionLog{currentTick, -1, {}, {}};
    if (readyQueue.empty()) return -1;

    auto effectivePriority = [](const Process& p) {
        return p.basePriority + (p.waitingTime / PriorityScheduler::AGING_INTERVAL);
    };

    const Process* best = &readyQueue[0];
    int bestEff = effectivePriority(*best);
    for (const auto& p : readyQueue) {
        int eff = effectivePriority(p);
        if (eff > bestEff || (eff == bestEff && p.pid < best->pid)) {
            best = &p;
            bestEff = eff;
        }
    }

    for (const auto& p : readyQueue) {
        lastDecision_.candidates.push_back(Candidate{p.pid, static_cast<double>(effectivePriority(p)),
                                                       p.basePriority, p.remainingTime,
                                                       processClassToString(p.predictedClass)});
    }
    lastDecision_.chosen = best->pid;
    lastDecision_.reasonTags.push_back("highest_effective_priority");
    if (best->waitingTime >= PriorityScheduler::AGING_INTERVAL) {
        lastDecision_.reasonTags.push_back(
            "aging_bonus:+" + std::to_string(best->waitingTime / PriorityScheduler::AGING_INTERVAL));
    }
    if (readyQueue.size() > 1) lastDecision_.reasonTags.push_back("tie_break:lowest_pid");

    return best->pid;
}

DecisionLog PriorityScheduler::explainLastDecision() const {
    return lastDecision_;
}
