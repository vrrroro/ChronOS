#include "sjf.h"

// Shortest-Job-First (non-preemptive): smallest remainingTime wins, lowest
// PID breaks ties. Non-preemptive, so remainingTime == burstTime for every
// candidate at selection time (a process only ever enters readyQueue once,
// before it has run at all).
int SJFScheduler::selectNext(std::vector<Process>& readyQueue, int currentTick) {
    lastDecision_ = DecisionLog{currentTick, -1, {}, {}};
    if (readyQueue.empty()) return -1;

    const Process* best = &readyQueue[0];
    for (const auto& p : readyQueue) {
        if (p.remainingTime < best->remainingTime ||
            (p.remainingTime == best->remainingTime && p.pid < best->pid)) {
            best = &p;
        }
    }

    for (const auto& p : readyQueue) {
        lastDecision_.candidates.push_back(Candidate{p.pid, static_cast<double>(-p.remainingTime),
                                                       p.basePriority, p.remainingTime,
                                                       processClassToString(p.predictedClass)});
    }
    lastDecision_.chosen = best->pid;
    lastDecision_.reasonTags.push_back("shortest_burst");
    if (readyQueue.size() > 1) lastDecision_.reasonTags.push_back("tie_break:lowest_pid");

    return best->pid;
}

DecisionLog SJFScheduler::explainLastDecision() const {
    return lastDecision_;
}
