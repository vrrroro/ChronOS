#include "workload_gen.h"

#include <algorithm>
#include <random>
#include <utility>

namespace {

// Inclusive [lo, hi], reproducible across standard libraries.
int drawInt(std::mt19937& rng, int lo, int hi) {
    if (hi < lo) std::swap(lo, hi);
    const std::uint32_t span = static_cast<std::uint32_t>(hi - lo) + 1u;
    return lo + static_cast<int>(rng() % span);
}

// Fisher–Yates over our own drawInt, for the same reproducibility reason
// (std::shuffle's use of the engine is implementation-defined too).
template <typename T>
void seededShuffle(std::vector<T>& v, std::mt19937& rng) {
    for (int i = static_cast<int>(v.size()) - 1; i > 0; --i) {
        std::swap(v[static_cast<size_t>(i)], v[static_cast<size_t>(drawInt(rng, 0, i))]);
    }
}

struct Draft {
    ProcessKind kind;
    int burst;
    int priority;
};

std::vector<Draft> drafts(const WorkloadSpec& spec, std::mt19937& rng) {
    std::vector<Draft> out;
    for (const ProcessGroup& g : spec.groups) {
        const int bLo = std::max(1, std::min(g.burstMin, g.burstMax));
        const int bHi = std::max(1, std::max(g.burstMin, g.burstMax));
        const int pLo = std::clamp(std::min(g.priorityMin, g.priorityMax), 1, 10);
        const int pHi = std::clamp(std::max(g.priorityMin, g.priorityMax), 1, 10);
        for (int i = 0; i < std::max(0, g.count); ++i) {
            out.push_back(Draft{g.kind, drawInt(rng, bLo, bHi), drawInt(rng, pLo, pHi)});
        }
    }
    seededShuffle(out, rng);
    return out;
}

}  // namespace

ProcessGroup defaultGroup(ProcessKind kind, int count) {
    ProcessGroup g;
    g.kind = kind;
    g.count = count;
    switch (kind) {
        // Above the classifier's CPU_BOUND threshold (behavior_analyzer.cpp,
        // 15 ticks), so these genuinely read as CPU-bound once they run.
        case ProcessKind::CPU_BOUND:   g.burstMin = 16; g.burstMax = 30; g.priorityMin = 2; g.priorityMax = 4; break;
        case ProcessKind::BALANCED:    g.burstMin = 5;  g.burstMax = 12; g.priorityMin = 4; g.priorityMax = 6; break;
        // Below the 4-tick short-burst threshold, so they can classify INTERACTIVE.
        case ProcessKind::INTERACTIVE: g.burstMin = 1;  g.burstMax = 3;  g.priorityMin = 6; g.priorityMax = 9; break;
    }
    return g;
}

Workload generateWorkload(const WorkloadSpec& spec) {
    std::mt19937 rng(spec.seed);
    std::vector<Draft> ds = drafts(spec, rng);

    Workload w;
    w.name = spec.name;
    w.quantum = std::max(1, spec.quantum);

    const int spacing = std::max(0, spec.spacing);
    int arrival = 0;
    for (size_t i = 0; i < ds.size(); ++i) {
        switch (spec.arrival) {
            case ArrivalPattern::ALL_AT_ONCE:
                arrival = 0;
                break;
            case ArrivalPattern::STAGGERED:
                if (i > 0) arrival += drawInt(rng, 0, spacing * 2);
                break;
            case ArrivalPattern::CLUSTERED:
                arrival = static_cast<int>(i / 4) * spacing;
                break;
        }
        Process p;
        p.pid = static_cast<int>(i) + 1;
        p.arrivalTime = arrival;
        p.burstTime = ds[i].burst;
        p.remainingTime = p.burstTime;
        p.basePriority = ds[i].priority;
        p.nice = niceFromPriority(p.basePriority);
        w.processes.push_back(p);
    }
    return w;
}

std::vector<ProcessKind> generatedKinds(const WorkloadSpec& spec) {
    // Replays the same draws generateWorkload makes, so the order matches.
    std::mt19937 rng(spec.seed);
    std::vector<ProcessKind> kinds;
    for (const Draft& d : drafts(spec, rng)) kinds.push_back(d.kind);
    return kinds;
}

std::string processKindToString(ProcessKind k) {
    switch (k) {
        case ProcessKind::CPU_BOUND: return "CPU-BOUND";
        case ProcessKind::BALANCED: return "BALANCED";
        case ProcessKind::INTERACTIVE: return "INTERACTIVE";
    }
    return "BALANCED";
}

std::string arrivalPatternToString(ArrivalPattern a) {
    switch (a) {
        case ArrivalPattern::ALL_AT_ONCE: return "ALL AT ONCE";
        case ArrivalPattern::STAGGERED: return "STAGGERED";
        case ArrivalPattern::CLUSTERED: return "CLUSTERED";
    }
    return "STAGGERED";
}
