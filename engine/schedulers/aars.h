#pragma once

#include "scheduler_base.h"

// Every weight in the AARS score and every entry of its quantum table.
//
// The defaults ARE PRD.md §6.2 / §6.4 exactly. Added 2026-10-16 (logged,
// explicit user request): the GUI's AARS tuner lets a viewer retune these at
// runtime. That is a viewer exploring the formula, not the project retuning
// it — the defaults do not move, an untuned run is byte-identical to the old
// fixed-weight AARS, and a run with any non-default weight is labelled
// "AARS (tuned)" so its numbers can never be passed off as the honest
// as-specified formula's (AGENTS.md Algorithm rules).
struct AarsParams {
    // --- PRD §6.1 / §6.2 terms ---
    double priorityWeight = 1.0;       // × basePriority
    double agingDivisor = 2.0;         // aging = min(wait / divisor, cap); <= 0 disables
    double agingCap = 10.0;
    double ioBoundBonus = 4.0;
    double interactiveBonus = 2.0;
    double responseBonus = 3.0;        // one-time, until first scheduled
    double burstPenaltyDivisor = 5.0;  // penalty = min(avgBurst / divisor, cap); <= 0 disables
    double burstPenaltyCap = 8.0;

    // --- PRD §6.4 dynamic quantum ---
    int quantumCpuBound = 8;
    int quantumBalanced = 5;           // BALANCED and UNKNOWN share this
    int quantumInteractive = 3;
    int quantumIoBound = 2;

    bool operator==(const AarsParams& o) const;
    bool operator!=(const AarsParams& o) const { return !(*this == o); }
};

// PRD.md §6 — Adaptive Aging & Response Scheduler.
// Score(process, currentTick) =
//   Base Priority + Aging Bonus + I/O Bonus + Response Bonus - CPU Burst Penalty
// Highest score among READY candidates wins; ties -> lowest PID.
class AARSScheduler : public Scheduler {
public:
    AARSScheduler() = default;
    explicit AARSScheduler(const AarsParams& params, std::string name = "AARS")
        : params_(params), name_(std::move(name)) {}

    int selectNext(std::vector<Process>& readyQueue, int currentTick) override;
    int currentQuantum(const Process& running) const override;
    DecisionLog explainLastDecision() const override;
    std::string name() const override;

private:
    AarsParams params_{};
    std::string name_ = "AARS";
    DecisionLog lastDecision_{};
};
