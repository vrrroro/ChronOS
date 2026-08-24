#pragma once

#include <string>
#include "simulator.h"

// Shared by chronos (CLI) and chronos_app (GUI) — pulled out of main.cpp so
// both link identical workload-loading behavior instead of duplicating it.
Workload loadWorkload(const std::string& path);
