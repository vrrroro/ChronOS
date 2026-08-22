#pragma once

#include "scheduler_base.h"

// PRD.md §6 — Adaptive Aging & Response Scheduler.
// Score(process, currentTick) =
//   Base Priority + Aging Bonus + I/O Bonus + Response Bonus - CPU Burst Penalty
// Highest score among READY candidates wins; ties -> lowest PID.
class AARSScheduler : public Scheduler {
public:
    AARSScheduler() = default;

    int selectNext(std::vector<Process>& readyQueue, int currentTick) override;
    int currentQuantum(const Process& running) const override;
    DecisionLog explainLastDecision() const override;
    std::string name() const override;

private:
    DecisionLog lastDecision_{};
};
