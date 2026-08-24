#pragma once

#include <memory>
#include <string>
#include "simulator.h"
#include "schedulers/scheduler_base.h"

// Shared by chronos (CLI) and chronos_app (GUI) — pulled out of main.cpp so
// both construct schedulers identically. Throws std::runtime_error for an
// unknown algorithm key (expected: fcfs|sjf|rr|priority|aars).
std::unique_ptr<Scheduler> makeScheduler(const std::string& algorithm, const Workload& workload);

// Human-readable display name for a CLI-style algorithm key, e.g. "rr" -> "Round Robin".
std::string algorithmDisplayName(const std::string& algorithm);
