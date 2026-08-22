#pragma once

#include "scheduler_base.h"

class SJFScheduler : public Scheduler {
public:
    int selectNext(std::vector<Process>& readyQueue, int currentTick) override;
    DecisionLog explainLastDecision() const override;
    std::string name() const override { return "SJF"; }

private:
    DecisionLog lastDecision_;
};
