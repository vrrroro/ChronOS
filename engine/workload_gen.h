#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "simulator.h"

// Synthetic workload generation for the GUI's CUSTOM WORKLOAD builder (added
// 2026-10-16, explicit user request). Lives in chronos_core rather than app/
// for the same reason workload_io does: anything that decides what processes
// exist is engine logic, and the CLI should be able to reuse it unchanged.
//
// Deterministic by construction — the same spec and seed always yield the
// same process list (own integer mapping over std::mt19937, never
// std::uniform_int_distribution, whose output is implementation-defined), so a
// custom run can be reproduced exactly.

// Process "type" a group is drawn from. Each sets *default* burst and priority
// ranges; the group can then override either range freely.
enum class ProcessKind { CPU_BOUND, BALANCED, INTERACTIVE };

enum class ArrivalPattern {
    ALL_AT_ONCE,  // every process at tick 0
    STAGGERED,    // one at a time, a random 0..2*spacing gap between each
    CLUSTERED,    // batches of 4 arriving together, `spacing` ticks apart
};

struct ProcessGroup {
    ProcessKind kind = ProcessKind::BALANCED;
    int count = 3;
    int burstMin = 5;
    int burstMax = 12;
    int priorityMin = 4;
    int priorityMax = 6;
};

struct WorkloadSpec {
    std::string name = "Custom Workload";
    int quantum = 4;
    std::uint32_t seed = 1;
    ArrivalPattern arrival = ArrivalPattern::STAGGERED;
    int spacing = 2;
    std::vector<ProcessGroup> groups;
};

// The default ranges a group of `kind` starts from.
ProcessGroup defaultGroup(ProcessKind kind, int count);

// Builds the workload. PIDs are assigned 1..N in arrival order; group
// membership is shuffled (seeded) before arrivals are handed out, so one type
// does not arrive as a solid block ahead of the others.
Workload generateWorkload(const WorkloadSpec& spec);

// Kind of the process with this pid in the last generated order, for the
// builder's preview list. Parallel to Workload::processes.
std::vector<ProcessKind> generatedKinds(const WorkloadSpec& spec);

std::string processKindToString(ProcessKind k);
std::string arrivalPatternToString(ArrivalPattern a);
