#pragma once

#include "scheduler_base.h"

class RoundRobinScheduler : public Scheduler {
public:
    explicit RoundRobinScheduler(int quantum) : quantum_(quantum) {}

    int selectNext(std::vector<Process>& readyQueue, int currentTick) override;
    int currentQuantum(const Process& running) const override { return quantum_; }
    DecisionLog explainLastDecision() const override;
    std::string name() const override { return "Round Robin"; }

private:
    int quantum_;
    DecisionLog lastDecision_;
};
