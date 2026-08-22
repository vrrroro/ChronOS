#pragma once

#include <vector>
#include "process.h"

// ARCHITECTURE.md §3.4 — stateless with respect to the simulator loop; only
// reads/writes fields already on Process (burstHistory, ioEvents,
// predictedClass). Implemented in behavior_analyzer.cpp against PRD.md §6.3's
// threshold rules. simulator.cpp calls this every tick; only aars.cpp reads
// the predictedClass/burstHistory fields it maintains.

namespace BehaviorAnalyzer {

// Called when a process finishes a burst (completes entirely or is
// preempted): appends burstLength (ticks actually run in that slice —
// the simulator tracks this since it's the only piece that knows when a
// slice starts/ends) to p.burstHistory, capped at last 5.
void recordCompletedBurst(Process& p, int burstLength);

// Called once per tick, before scheduling: recomputes predictedClass for
// any process whose burstHistory changed since last check.
void updateClassifications(std::vector<Process>& processes);

} // namespace BehaviorAnalyzer
