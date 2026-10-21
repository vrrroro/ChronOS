#pragma once

#include <map>
#include <string>
#include <vector>

#include "scheduler_base.h"

// Multilevel Feedback Queue — the textbook algorithm (Arpaci-Dusseau, OSTEP
// ch. 8; Silberschatz §5.3.6), PRD.md §6.6. Shown in the GUI as
// "MLFQ (Windows)": Windows' scheduler is a member of this family (dynamic
// priorities, feedback, boosts), but what is implemented here is the plain
// textbook version, not Windows' 32-level variant.
//
// Rules, exactly as OSTEP states them:
//   1. A process in a higher queue always runs before one in a lower queue.
//   2. Within a queue, processes take turns (round robin).
//   3. A new process enters the top queue (Q0).
//   4. Once a process has used up its allotment at a level — however many
//      slices that took — it moves down one queue. The bottom queue is plain
//      round robin.
//   5. Every boostInterval ticks, every process moves back to Q0.
// Rule 1 is preemptive: a process arriving in a higher queue takes the CPU
// immediately (shouldPreempt), and the preempted process keeps what is left
// of its allotment rather than starting it again.

// Optional per-workload overrides (PRD.md §5.2, "mlfq" block). 0 = derive.
struct MlfqConfig {
    int levels = 0;         // number of queues; default 3, clamped 2..8
    int baseQuantum = 0;    // Q0's quantum; default = the workload's quantum
    int boostInterval = 0;  // ticks between priority boosts; default 10 x baseQuantum
};

// Resolved values the scheduler actually runs with.
struct MlfqParams {
    std::vector<int> quanta;  // per level, doubling: q, 2q, 4q, ...
    int boostInterval = 40;
};

MlfqParams resolveMlfq(const MlfqConfig& config, int workloadQuantum);

class MLFQScheduler : public Scheduler {
public:
    explicit MLFQScheduler(MlfqParams params);

    int selectNext(std::vector<Process>& readyQueue, int currentTick) override;
    int currentQuantum(const Process& running) const override;
    bool shouldPreempt(const Process& running, const std::vector<Process>& readyQueue,
                       int currentTick) override;
    DecisionLog explainLastDecision() const override;
    std::string name() const override { return "MLFQ (Windows)"; }

private:
    struct Track {
        int level = 0;
        int used = 0;          // ticks of this level's allotment already spent
        int lastConsumed = 0;  // burstTime - remainingTime when last accounted
    };

    Track& track(const Process& p);
    int levelOf(const Process& p) const;
    void account(const Process& p);
    void applyBoost(int currentTick, const Process* running);

    MlfqParams params_;
    std::map<int, Track> tracks_;
    int nextBoost_;
    // Events since the last decision, reported in its reason tags.
    std::vector<std::string> pendingEvents_;
    int preemptedPid_ = -1;
    DecisionLog lastDecision_{};
};
