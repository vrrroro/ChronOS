#include "aars.h"

#include <algorithm>
#include <cmath>
#include <numeric>
#include <sstream>

namespace {

// PRD.md §6.2 starting weights now live as AarsParams' defaults (aars.h) —
// do not retune those defaults to chase "better" numbers (AGENTS.md); they are
// the honest, as-specified formula. A viewer can override them per run from
// the GUI, and such a run is labelled as tuned.

double averageBurstHistory(const Process& p) {
    if (p.burstHistory.empty()) return 0.0;
    double sum = std::accumulate(p.burstHistory.begin(), p.burstHistory.end(), 0.0);
    return sum / static_cast<double>(p.burstHistory.size());
}

double basePriorityTerm(const Process& p, const AarsParams& k) {
    return k.priorityWeight * p.basePriority;
}

double agingBonus(const Process& p, const AarsParams& k) {
    if (k.agingDivisor <= 0.0) return 0.0;
    return std::min(p.waitingTime / k.agingDivisor, k.agingCap);
}

double ioBonus(const Process& p, const AarsParams& k) {
    switch (p.predictedClass) {
        case ProcessClass::IO_BOUND: return k.ioBoundBonus;
        case ProcessClass::INTERACTIVE: return k.interactiveBonus;
        default: return 0.0;
    }
}

double responseBonus(const Process& p, const AarsParams& k) {
    return (p.responseTime == -1) ? k.responseBonus : 0.0;
}

double burstPenalty(const Process& p, const AarsParams& k) {
    if (k.burstPenaltyDivisor <= 0.0) return 0.0;
    return std::min(averageBurstHistory(p) / k.burstPenaltyDivisor, k.burstPenaltyCap);
}

double totalScore(const Process& p, const AarsParams& k) {
    return basePriorityTerm(p, k) + agingBonus(p, k) + ioBonus(p, k) + responseBonus(p, k)
           - burstPenalty(p, k);
}

// Formats a numeric delta as "+4" or "+1.5" / "-2" — trims a trailing ".0".
std::string formatDelta(double value, bool withSign) {
    std::ostringstream oss;
    if (withSign && value >= 0) oss << "+";
    if (std::abs(value - std::round(value)) < 1e-9) {
        oss << static_cast<long long>(std::round(value));
    } else {
        oss.precision(1);
        oss << std::fixed << value;
    }
    return oss.str();
}

std::string classTag(ProcessClass c) {
    switch (c) {
        case ProcessClass::CPU_BOUND: return "classified_cpu_bound";
        case ProcessClass::IO_BOUND: return "classified_io_bound";
        case ProcessClass::INTERACTIVE: return "classified_interactive";
        case ProcessClass::BALANCED: return "classified_balanced";
        case ProcessClass::UNKNOWN: return "classified_unknown";
    }
    return "classified_unknown";
}

} // namespace

bool AarsParams::operator==(const AarsParams& o) const {
    return priorityWeight == o.priorityWeight && agingDivisor == o.agingDivisor &&
           agingCap == o.agingCap && ioBoundBonus == o.ioBoundBonus &&
           interactiveBonus == o.interactiveBonus && responseBonus == o.responseBonus &&
           burstPenaltyDivisor == o.burstPenaltyDivisor && burstPenaltyCap == o.burstPenaltyCap &&
           quantumCpuBound == o.quantumCpuBound && quantumBalanced == o.quantumBalanced &&
           quantumInteractive == o.quantumInteractive && quantumIoBound == o.quantumIoBound;
}

int AARSScheduler::selectNext(std::vector<Process>& readyQueue, int currentTick) {
    lastDecision_ = DecisionLog{};
    lastDecision_.tick = currentTick;

    if (readyQueue.empty()) {
        lastDecision_.chosen = -1;
        return -1;
    }

    const Process* winner = nullptr;
    double winnerScore = 0.0;

    for (const Process& p : readyQueue) {
        double score = totalScore(p, params_);
        lastDecision_.candidates.push_back(Candidate{p.pid, score, p.basePriority, p.remainingTime,
                                                       processClassToString(p.predictedClass)});

        if (winner == nullptr || score > winnerScore ||
            (score == winnerScore && p.pid < winner->pid)) {
            winner = &p;
            winnerScore = score;
        }
    }

    lastDecision_.chosen = winner->pid;

    // Build reason tags for the winner, mirroring the style already used in
    // dashboard/sample-results.json.
    // All five PRD §6.1 formula terms are always tagged as "name:±value",
    // even when a term is 0 — the dashboard's score-breakdown bar (EDRD §7.1)
    // renders a fixed 5-segment bar and needs every term present every time,
    // not just the ones currently contributing.
    std::vector<std::string>& tags = lastDecision_.reasonTags;
    tags.push_back(readyQueue.size() == 1 ? "only_candidate" : "highest_score");

    tags.push_back("base_priority:" + formatDelta(basePriorityTerm(*winner, params_), true));

    double aging = agingBonus(*winner, params_);
    tags.push_back("aging_bonus:" + formatDelta(aging, true));

    double io = ioBonus(*winner, params_);
    tags.push_back("io_bonus:" + formatDelta(io, true));
    if (io > 0.0) tags.push_back(classTag(winner->predictedClass));

    double resp = responseBonus(*winner, params_);
    tags.push_back("response_bonus:" + formatDelta(resp, true));

    double penalty = burstPenalty(*winner, params_);
    tags.push_back("cpu_burst_penalty:" + formatDelta(-penalty, true));

    return winner->pid;
}

int AARSScheduler::currentQuantum(const Process& running) const {
    // PRD.md §6.4 dynamic time quantum, keyed on predictedClass.
    switch (running.predictedClass) {
        case ProcessClass::CPU_BOUND: return std::max(1, params_.quantumCpuBound);
        case ProcessClass::INTERACTIVE: return std::max(1, params_.quantumInteractive);
        case ProcessClass::IO_BOUND: return std::max(1, params_.quantumIoBound);
        // BALANCED and UNKNOWN share the neutral quantum: one is "judged
        // unremarkable", the other "not yet judged", and neither is a reason
        // to lengthen or shorten the slice.
        case ProcessClass::BALANCED:
        case ProcessClass::UNKNOWN: default: return std::max(1, params_.quantumBalanced);
    }
}

DecisionLog AARSScheduler::explainLastDecision() const {
    return lastDecision_;
}

std::string AARSScheduler::name() const {
    return name_;
}
