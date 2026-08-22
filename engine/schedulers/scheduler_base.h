#pragma once

#include <string>
#include <vector>
#include "../process.h"

// ARCHITECTURE.md §3.2 — the internal contract every algorithm implements.
// simulator.cpp is written once against this interface; adding a new
// scheduler or retuning an existing one never touches the simulator core.

// Extended beyond PRD.md's original {pid, score} pair (integration-time fix,
// documented in PRD.md §5.3): the dashboard's ready-queue table (EDRD.md
// §5.3) needs PRIORITY/BURST/CLASS columns, and the JSON schema had nowhere
// to carry them except here, on each decision's candidate list.
struct Candidate {
    int pid;
    double score;
    int priority = 0;
    int burstRemaining = 0;
    std::string predictedClass = "UNKNOWN";
};

// Mirrors the decisionLog entry shape in PRD.md §5.3 exactly — this struct
// is what gets serialized into the result JSON's decisionLog[] array and
// rendered (via logs/scheduler.log) as plain text.
struct DecisionLog {
    int tick;
    int chosen;
    std::vector<Candidate> candidates;
    std::vector<std::string> reasonTags;
};

class Scheduler {
public:
    virtual ~Scheduler() = default;

    // Called once per tick. Given the current ready queue and tick number,
    // return the PID to run next (or -1 if nothing is ready).
    virtual int selectNext(std::vector<Process>& readyQueue, int currentTick) = 0;

    // Called once per tick after selectNext, for schedulers with a
    // time-quantum concept (RR, MLFQ, AARS). Return ticks remaining
    // in the current process's slice, or -1 if not quantum-based.
    virtual int currentQuantum(const Process& running) const { return -1; }

    // For logging/dashboard: explain the selectNext decision just made.
    // Must be populated with real candidate scores + reason tags every
    // call — this feeds the dashboard's why-panel directly (EDRD.md §5.4).
    virtual DecisionLog explainLastDecision() const = 0;

    virtual std::string name() const = 0;
};

// --------------------------------------------------------------------------
// Fixed per-scheduler naming contract (so main.cpp can be written against
// headers that don't exist yet, without touching a shared file later):
//
//   schedulers/fcfs.h         class FCFSScheduler         : public Scheduler
//   schedulers/sjf.h          class SJFScheduler          : public Scheduler
//   schedulers/round_robin.h  class RoundRobinScheduler   : public Scheduler
//                                  RoundRobinScheduler(int quantum)
//   schedulers/priority.h     class PriorityScheduler     : public Scheduler
//   schedulers/aars.h         class AARSScheduler         : public Scheduler
//
// All five are default-constructible except RoundRobinScheduler, which
// takes the workload's "quantum" field (PRD.md §5.2) as its one constructor
// argument. None of them take any other constructor arguments.
// --------------------------------------------------------------------------
