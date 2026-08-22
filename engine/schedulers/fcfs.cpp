#include "fcfs.h"

#include <algorithm>

// First-Come-First-Served: earliest arrivalTime wins, lowest PID breaks ties.
// Score reported to the decision log is -arrivalTime (earlier arrival = higher
// score) purely so the why-panel has something meaningful to show; FCFS
// itself only ever compares arrivalTime/pid directly.
int FCFSScheduler::selectNext(std::vector<Process>& readyQueue, int currentTick) {
    lastDecision_ = DecisionLog{currentTick, -1, {}, {}};
    if (readyQueue.empty()) return -1;

    const Process* best = &readyQueue[0];
    for (const auto& p : readyQueue) {
        if (p.arrivalTime < best->arrivalTime ||
            (p.arrivalTime == best->arrivalTime && p.pid < best->pid)) {
            best = &p;
        }
    }

    for (const auto& p : readyQueue) {
        lastDecision_.candidates.push_back(Candidate{p.pid, static_cast<double>(-p.arrivalTime),
                                                       p.basePriority, p.remainingTime,
                                                       processClassToString(p.predictedClass)});
    }
    lastDecision_.chosen = best->pid;
    lastDecision_.reasonTags.push_back("earliest_arrival");
    if (readyQueue.size() > 1) lastDecision_.reasonTags.push_back("tie_break:lowest_pid");

    return best->pid;
}

DecisionLog FCFSScheduler::explainLastDecision() const {
    return lastDecision_;
}
