#include "behavior_analyzer.h"

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

void updateClassifications(std::vector<Process>& processes) {
    for (Process& p : processes) {
        if (p.burstHistory.size() < 2) {
            p.predictedClass = ProcessClass::UNKNOWN;
            continue;
        }

        double avgBurst = averageBurst(p.burstHistory);

        if (avgBurst > kCpuBoundThreshold) {
            p.predictedClass = ProcessClass::CPU_BOUND;
        } else if (avgBurst < kShortBurstThreshold && p.ioEvents > 0) {
            p.predictedClass = ProcessClass::IO_BOUND;
        } else if (avgBurst < kShortBurstThreshold &&
                   p.responseTime >= 0 && p.responseTime <= kLowResponseTicks) {
            p.predictedClass = ProcessClass::INTERACTIVE;
        } else {
            p.predictedClass = ProcessClass::UNKNOWN;
        }
    }
}

} // namespace BehaviorAnalyzer
