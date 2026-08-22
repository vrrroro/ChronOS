#pragma once

#include <string>
#include <vector>

// PRD.md §5.1 — verbatim. Do not rename/restructure without updating the PRD
// and every consumer (engine writer, dashboard reader, analysis.py reader).

enum class State { NEW, READY, RUNNING, WAITING, TERMINATED };
enum class ProcessClass { UNKNOWN, CPU_BOUND, IO_BOUND, INTERACTIVE };

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

    State state = State::NEW;

    // behavior tracking (used by AARS + behavior analyzer)
    std::vector<int> burstHistory;   // completed burst lengths so far, capped at last 5
    int ioEvents = 0;                // count of times it voluntarily gave up CPU early
    ProcessClass predictedClass = ProcessClass::UNKNOWN;
};

std::string stateToString(State s);
std::string processClassToString(ProcessClass c);
