#pragma once

#include "scheduler_base.h"

class FCFSScheduler : public Scheduler {
public:
    int selectNext(std::vector<Process>& readyQueue, int currentTick) override;
    DecisionLog explainLastDecision() const override;
    std::string name() const override { return "FCFS"; }

private:
    DecisionLog lastDecision_;
};
