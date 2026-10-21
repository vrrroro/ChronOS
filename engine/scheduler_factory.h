#pragma once

#include <memory>
#include <string>
#include "simulator.h"
#include "schedulers/scheduler_base.h"
#include "schedulers/aars.h"

// Shared by chronos (CLI) and chronos_app (GUI) — pulled out of main.cpp so
// both construct schedulers identically. Throws std::runtime_error for an
// unknown algorithm key. mlfq and cfs (added 2026-10-22) resolve their
// parameters from the workload's quantum and optional "mlfq"/"cfs" blocks.
inline constexpr const char* kAlgorithmUsage = "fcfs|sjf|rr|priority|aars|mlfq|cfs";

std::unique_ptr<Scheduler> makeScheduler(const std::string& algorithm, const Workload& workload);

// Same, but "aars" is built from the given weights instead of the PRD §6.2
// defaults (other keys ignore `params`). An "aars" run whose
// params differ from the defaults is named "AARS (tuned)" so its results can
// never be mistaken for the as-specified formula's.
std::unique_ptr<Scheduler> makeScheduler(const std::string& algorithm, const Workload& workload,
                                         const AarsParams& params);

// Human-readable display name for a CLI-style algorithm key, e.g. "rr" -> "Round Robin".
std::string algorithmDisplayName(const std::string& algorithm);
