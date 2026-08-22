#include "round_robin.h"

// Round Robin: always take the head of readyQueue. simulator.cpp only ever
// appends to readyQueue (new arrivals and preempted processes both go to the
// back), so index 0 is genuinely "whoever has waited longest in FIFO order" —
// no extra bookkeeping needed here.
int RoundRobinScheduler::selectNext(std::vector<Process>& readyQueue, int currentTick) {
    lastDecision_ = DecisionLog{currentTick, -1, {}, {}};
    if (readyQueue.empty()) return -1;

    for (size_t i = 0; i < readyQueue.size(); ++i) {
        double score = static_cast<double>(readyQueue.size() - i); // head = highest score, purely illustrative
        const Process& p = readyQueue[i];
        lastDecision_.candidates.push_back(Candidate{p.pid, score, p.basePriority, p.remainingTime,
                                                       processClassToString(p.predictedClass)});
    }

    int chosen = readyQueue[0].pid;
    lastDecision_.chosen = chosen;
    lastDecision_.reasonTags.push_back("head_of_ready_queue");
    lastDecision_.reasonTags.push_back("quantum:" + std::to_string(quantum_));

    return chosen;
}

DecisionLog RoundRobinScheduler::explainLastDecision() const {
    return lastDecision_;
}
