#pragma once

#include <string>
#include <vector>
#include "process.h"
#include "schedulers/scheduler_base.h"

// PRD.md §5.2 — engine input.
struct Workload {
    std::string name;
    int quantum = 0;
    std::vector<Process> processes;
};

// PRD.md §5.3 — the pieces of the result JSON built by the tick loop.
struct GanttEntry {
    int pid;
    int start;
    int end;
    std::string reason;
};

struct ProcessStat {
    int pid;
    int waitingTime;
    int turnaroundTime;
    int responseTime;
    int completionTime;
    // Added 2026-08-24 (PRD.md §5.3, additive — no existing field changed):
    // the inputs and the final verdict a consumer needs to describe a finished
    // process without re-reading the workload file alongside the result.
    int arrivalTime = 0;
    int burstTime = 0;
    int contextSwitches = 0;
    ProcessClass predictedClass = ProcessClass::UNKNOWN;
};

struct Summary {
    double avgWaitingTime = 0;
    double avgTurnaroundTime = 0;
    double avgResponseTime = 0;
    int contextSwitches = 0;
    double cpuUtilization = 0;
    double throughput = 0;
};

struct SimulationResult {
    std::string algorithm;
    std::string workloadName;
    std::vector<GanttEntry> gantt;
    std::vector<DecisionLog> decisionLog;
    std::vector<ProcessStat> processStats;
    Summary summary;
};

// ARCHITECTURE.md §3.3 — the tick loop. Scheduler-agnostic: works identically
// for every algorithm because it only ever talks to the Scheduler interface.
SimulationResult runSimulation(const Workload& workload, Scheduler& scheduler, const std::string& algorithmName);

// PRD.md §5.3 — write the result JSON via nlohmann::json (never hand-built).
void writeResultJson(const SimulationResult& result, const std::string& outPath);

// PRD.md §11 — human-readable rendering of the same decisionLog entries.
void writeSchedulerLog(const SimulationResult& result, const std::string& logPath);
