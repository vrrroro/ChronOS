#pragma once

#include <string>
#include <vector>

// PRD.md §5.1 — verbatim. Do not rename/restructure without updating the PRD
// and every consumer (engine writer, dashboard reader, analysis.py reader).

enum class State { NEW, READY, RUNNING, WAITING, TERMINATED };
// BALANCED added 2026-08-24 (logged, PRD.md §5.1/§6.3). It splits what used to
// be one overloaded value: UNKNOWN now means strictly "has not run yet, nothing
// to classify from", and BALANCED means "classified, and it is neither short-
// burst nor long-burst". Previously both collapsed into UNKNOWN, so a viewer
// could not tell a process the analyzer had never seen from one it had judged
// unremarkable. Behaviourally inert in AARS — BALANCED takes the same neutral
// quantum and zero I/O bonus UNKNOWN already took, so no weights move.
enum class ProcessClass { UNKNOWN, CPU_BOUND, IO_BOUND, INTERACTIVE, BALANCED };

struct Process {
    int pid = 0;
    int arrivalTime = 0;
    int burstTime = 0;          // total CPU time needed
    int remainingTime = 0;
    int basePriority = 5;       // 1 (low) .. 10 (high)
    int waitingTime = 0;
    int turnaroundTime = 0;
    int responseTime = -1;      // -1 until first scheduled
    int startTime = -1;
    int completionTime = -1;
    int contextSwitches = 0;
    // Unix-style niceness (-20 .. 19, lower = more CPU), read only by CFS for
    // its load weight. Added 2026-10-22 (PRD.md §5.1). Workloads may set it
    // per process; otherwise it is derived from basePriority by
    // niceFromPriority(), so every existing workload runs under CFS unchanged.
    int nice = 0;

    State state = State::NEW;

    // behavior tracking (used by AARS + behavior analyzer)
    std::vector<int> burstHistory;   // completed burst lengths so far, capped at last 5
    int ioEvents = 0;                // count of times it voluntarily gave up CPU early
    ProcessClass predictedClass = ProcessClass::UNKNOWN;
};

// basePriority 1..10 (10 = most important) onto nice: 5 -> 0, two nice steps
// per priority level, so 10 -> -10 and 1 -> +8. Each nice step is ~1.25x CPU
// share under CFS, so one priority level is ~1.56x.
int niceFromPriority(int priority);

std::string stateToString(State s);
std::string processClassToString(ProcessClass c);
