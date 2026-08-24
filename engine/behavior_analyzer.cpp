#include "behavior_analyzer.h"

#include <algorithm>
#include <numeric>

namespace BehaviorAnalyzer {

namespace {
constexpr size_t kHistoryWindow = 5;
constexpr double kCpuBoundThreshold = 15.0;
constexpr double kShortBurstThreshold = 4.0;
// INTERACTIVE interpretation note: PRD.md §6.3 asks for "responseTime was low
// historically (repeatedly re-enters READY quickly after being scheduled)",
// but Process (process.h, locked) only tracks a single responseTime (set once,
// on first schedule) — there is no rolling per-reentry history field to read.
// Proxy used here: a low *first* response time is treated as evidence the
// process is the kind that gets picked quickly once ready, combined with the
// already-required short average burst. responseTime <= kLowResponseTicks is
// "low"; -1 (never scheduled yet) does not count as interactive.
constexpr int kLowResponseTicks = 3;

double averageBurst(const std::vector<int>& history) {
    if (history.empty()) return 0.0;
    double sum = std::accumulate(history.begin(), history.end(), 0.0);
    return sum / static_cast<double>(history.size());
}
} // namespace

void recordCompletedBurst(Process& p, int burstLength) {
    // Called by the simulator both on full completion and on preemption at a
    // quantum boundary — burstLength is however many ticks that slice
    // actually ran (not necessarily the process's whole burstTime), so a
    // preemptive scheduler (RR/AARS) accumulates real per-slice history
    // instead of a single all-or-nothing entry.
    p.burstHistory.push_back(burstLength);
    if (p.burstHistory.size() > kHistoryWindow) {
        p.burstHistory.erase(p.burstHistory.begin());
    }
}

// Revised 2026-08-24 (logged, see PRD.md §6.3): classification used to require
// **two** completed bursts before it would commit to anything, and to look only
// at completed bursts. Under the three non-preemptive algorithms a process runs
// exactly once and then terminates, so it never accumulated a second burst and
// every row in the UI read UNKNOWN for the entire run — the classifier was
// effectively dead outside RR and AARS, and UNKNOWN meant "the analyzer never
// got to speak", which is not something a viewer can be expected to infer.
//
// Two changes fix that without loosening what the labels mean:
//
//   1. One completed burst is enough. A process that has run 22 ticks to
//      completion is CPU-bound on any reading; demanding a second sample only
//      withholds a conclusion already supported by the evidence.
//   2. CPU consumed *so far* counts as evidence for the CPU_BOUND case, even
//      mid-burst. A process that has already held the CPU for more than the
//      threshold is CPU-bound whether or not it has finished — waiting for it
//      to finish before saying so is the classifier being least useful exactly
//      when the information matters most.
//
// UNKNOWN now means only "has not run yet", which is a state a viewer can see
// for themselves on the timeline, and the UI labels it PENDING to say so.
void updateClassifications(std::vector<Process>& processes) {
    for (Process& p : processes) {
        // Ticks of CPU this process has consumed across all its slices.
        const int consumed = p.burstTime - p.remainingTime;

        if (p.burstHistory.empty() && consumed <= 0) {
            p.predictedClass = ProcessClass::UNKNOWN;  // genuinely nothing to go on
            continue;
        }

        const double avgBurst = p.burstHistory.empty()
                                    ? static_cast<double>(consumed)
                                    : averageBurst(p.burstHistory);

        // For the CPU-bound test, take the strongest evidence available: a
        // long *current* run counts even if no burst has completed yet.
        const double cpuEvidence = std::max(avgBurst, static_cast<double>(consumed));

        if (cpuEvidence > kCpuBoundThreshold) {
            p.predictedClass = ProcessClass::CPU_BOUND;
        } else if (p.burstHistory.empty()) {
            // Still mid-first-burst and not yet long enough to be CPU-bound.
            // The short-burst classes below need a *completed* burst: a process
            // three ticks into a thirty-tick run would otherwise be labelled
            // interactive purely because it has not run long yet.
            p.predictedClass = ProcessClass::UNKNOWN;
        } else if (avgBurst < kShortBurstThreshold && p.ioEvents > 0) {
            p.predictedClass = ProcessClass::IO_BOUND;
        } else if (avgBurst < kShortBurstThreshold &&
                   p.responseTime >= 0 && p.responseTime <= kLowResponseTicks) {
            p.predictedClass = ProcessClass::INTERACTIVE;
        } else {
            p.predictedClass = ProcessClass::BALANCED;
        }
    }
}

} // namespace BehaviorAnalyzer
