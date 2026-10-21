#pragma once

#include <map>
#include <string>
#include <vector>

#include "scheduler_base.h"

// Completely Fair Scheduler — Linux's default from 2.6.23 until EEVDF
// replaced it in 6.6. PRD.md §6.7. Shown in the GUI as "CFS (Linux)".
//
// Every process carries a virtual runtime: the CPU it has received, scaled
// by 1024 / weight, so a heavier (lower-nice) process accrues vruntime more
// slowly and therefore gets picked more often. The scheduler always runs the
// process with the smallest vruntime — the leftmost node of a red-black tree,
// which is literally what std::set is in every mainstream standard library.
//
// Slice length is not fixed: each process gets its weight's share of a target
// latency period (Linux's sched_slice), never less than the minimum
// granularity. A newly arrived process is placed at the run queue's
// min_vruntime, and preempts the running one if the running one is ahead of
// it by more than the wakeup granularity (Linux's check_preempt_wakeup).
//
// Time scale: Linux's defaults are 6 ms latency, 0.75 ms minimum granularity
// and 1 ms wakeup granularity (8 : 1 : 1.33). Ticks here are not
// milliseconds of a real machine, so those *ratios* are kept and anchored to
// the workload's own quantum: min granularity = quantum. Linux also adds a
// START_DEBIT penalty to newly forked tasks; that is left off, so CFS is
// placed in the most favourable light rather than handicapped.

// Optional per-workload overrides (PRD.md §5.2, "cfs" block). 0 = derive.
struct CfsConfig {
    int targetLatency = 0;      // default 8 x minGranularity
    int minGranularity = 0;     // default = the workload's quantum
    int wakeupGranularity = 0;  // default round(4/3 x minGranularity)
};

struct CfsParams {
    int targetLatency = 32;
    int minGranularity = 4;
    int wakeupGranularity = 5;
};

CfsParams resolveCfs(const CfsConfig& config, int workloadQuantum);

// Linux's sched_prio_to_weight table (kernel/sched/core.c): nice 0 = 1024,
// each step ~1.25x. `nice` is clamped to -20..19.
int cfsWeight(int nice);

class CFSScheduler : public Scheduler {
public:
    explicit CFSScheduler(CfsParams params) : params_(params) {}

    int selectNext(std::vector<Process>& readyQueue, int currentTick) override;
    int currentQuantum(const Process& running) const override;
    bool shouldPreempt(const Process& running, const std::vector<Process>& readyQueue,
                       int currentTick) override;
    DecisionLog explainLastDecision() const override;
    std::string name() const override { return "CFS (Linux)"; }

private:
    struct Entity {
        double vruntime = 0.0;
        int weight = 1024;
        int lastConsumed = 0;
    };

    bool known(int pid) const { return entities_.count(pid) > 0; }
    void update(const Process& p);
    void raiseMinVruntime(const std::vector<const Process*>& runnable);
    void place(const Process& p);

    CfsParams params_;
    std::map<int, Entity> entities_;
    double minVruntime_ = 0.0;
    int lastSlice_ = 1;
    int preemptedPid_ = -1;
    DecisionLog lastDecision_{};
};
