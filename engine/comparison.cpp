#include "comparison.h"

#include <algorithm>
#include <cmath>
#include <iomanip>
#include <sstream>
#include <stdexcept>

namespace {

double mean(const std::vector<double>& v) {
    if (v.empty()) return 0.0;
    double s = 0.0;
    for (double x : v) s += x;
    return s / static_cast<double>(v.size());
}

// Equal at the precision anything is ever shown or reasoned about. Averages
// over integer tick counts are exact enough that this only absorbs float noise.
bool same(double a, double b) {
    return std::llround(a * 1e6) == std::llround(b * 1e6);
}

std::string fmt(double v, int decimals) {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(decimals) << v;
    return oss.str();
}

}  // namespace

const std::vector<MetricSpec>& comparisonMetrics() {
    static const std::vector<MetricSpec> kMetrics = {
        {"avgWaitingTime", "AVG WAITING", "ticks", true, 2,
         "time spent ready but not running, per process"},
        {"avgTurnaroundTime", "AVG TURNAROUND", "ticks", true, 2,
         "arrival to completion, per process"},
        {"avgResponseTime", "AVG RESPONSE", "ticks", true, 2,
         "arrival to first time on the CPU"},
        {"maxWaitingTime", "WORST WAITING", "ticks", true, 0,
         "the single longest wait - how close anything came to starving"},
        {"avgSlowdown", "AVG SLOWDOWN", "x", true, 2,
         "turnaround / burst - how much longer than its own work a process took"},
        {"contextSwitches", "CONTEXT SWITCHES", "", true, 0,
         "times the CPU changed hands - each one is overhead on a real machine"},
        {"fairness", "FAIRNESS (JAIN)", "", false, 3,
         "Jain's index over burst / turnaround - 1.000 = every process slowed equally"},
        {"cpuUtilization", "CPU UTILIZATION", "%", false, 1,
         "share of ticks the CPU was busy"},
        {"throughput", "THROUGHPUT", "/tick", false, 3,
         "processes completed per tick"},
    };
    return kMetrics;
}

double metricValue(const SimulationResult& r, const std::string& key) {
    const Summary& s = r.summary;
    if (key == "avgWaitingTime") return s.avgWaitingTime;
    if (key == "avgTurnaroundTime") return s.avgTurnaroundTime;
    if (key == "avgResponseTime") return s.avgResponseTime;
    if (key == "contextSwitches") return s.contextSwitches;
    if (key == "cpuUtilization") return s.cpuUtilization * 100.0;
    if (key == "throughput") return s.throughput;

    if (key == "maxWaitingTime") {
        int worst = 0;
        for (const auto& p : r.processStats) worst = std::max(worst, p.waitingTime);
        return worst;
    }

    std::vector<double> ratio;  // burst / turnaround, in (0, 1]
    std::vector<double> slowdown;
    for (const auto& p : r.processStats) {
        if (p.burstTime <= 0 || p.turnaroundTime <= 0) continue;
        ratio.push_back(static_cast<double>(p.burstTime) / p.turnaroundTime);
        slowdown.push_back(static_cast<double>(p.turnaroundTime) / p.burstTime);
    }
    if (key == "avgSlowdown") return mean(slowdown);
    if (key == "fairness") {
        // Jain (1984): (sum x)^2 / (n * sum x^2). 1 when every x is equal.
        if (ratio.empty()) return 1.0;
        double sum = 0.0, sumSq = 0.0;
        for (double x : ratio) {
            sum += x;
            sumSq += x * x;
        }
        return (sum * sum) / (static_cast<double>(ratio.size()) * sumSq);
    }
    throw std::runtime_error("unknown metric: " + key);
}

Comparison compareRuns(const SimulationResult& a, const SimulationResult& b) {
    Comparison c;
    c.nameA = a.algorithm;
    c.nameB = b.algorithm;
    c.workloadName = a.workloadName;

    for (const MetricSpec& spec : comparisonMetrics()) {
        MetricRow row;
        row.spec = spec;
        row.a = metricValue(a, spec.key);
        row.b = metricValue(b, spec.key);
        if (same(row.a, row.b)) {
            row.winner = -1;
            ++c.ties;
        } else {
            const bool aBetter = spec.lowerIsBetter ? row.a < row.b : row.a > row.b;
            row.winner = aBetter ? 0 : 1;
            ++(aBetter ? c.winsA : c.winsB);
        }
        c.rows.push_back(row);
    }
    return c;
}

std::string formatComparison(const Comparison& c) {
    std::ostringstream out;
    out << "workload: " << c.workloadName << "\n";
    out << "A: " << c.nameA << "\nB: " << c.nameB << "\n\n";
    out << std::left << std::setw(20) << "METRIC" << std::right << std::setw(12) << "A"
        << std::setw(12) << "B" << "   BETTER\n";
    out << std::string(52, '-') << "\n";
    for (const MetricRow& r : c.rows) {
        out << std::left << std::setw(20) << r.spec.label << std::right << std::setw(12)
            << fmt(r.a, r.spec.decimals) << std::setw(12) << fmt(r.b, r.spec.decimals) << "   "
            << (r.winner == 0 ? "A" : r.winner == 1 ? "B" : "tie") << "\n";
    }
    out << std::string(52, '-') << "\n";
    out << c.nameA << ": " << c.winsA << " wins   " << c.nameB << ": " << c.winsB << " wins   ties: "
        << c.ties << "\n";
    if (c.winsA != c.winsB) {
        out << "overall: " << (c.winsA > c.winsB ? c.nameA : c.nameB) << " wins more metrics\n";
    } else {
        out << "overall: even\n";
    }
    return out.str();
}
