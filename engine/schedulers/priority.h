#pragma once

#include "scheduler_base.h"

class PriorityScheduler : public Scheduler {
public:
    int selectNext(std::vector<Process>& readyQueue, int currentTick) override;
    DecisionLog explainLastDecision() const override;
    std::string name() const override { return "Priority"; }

private:
    // Milestone-1 basic aging (PRD.md item 5): +1 effective priority per
    // AGING_INTERVAL ticks waited — a placeholder, not the full AARS formula
    // (that lives in aars.cpp). Chosen so a process waiting the length of a
    // typical CPU-heavy burst (~20 ticks) picks up a few points, without
    // dominating basePriority (1-10) immediately.
    static constexpr int AGING_INTERVAL = 5;

    DecisionLog lastDecision_;
};
