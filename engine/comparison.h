#pragma once

#include <string>
#include <vector>

#include "simulator.h"

// Head-to-head comparison of two runs over the same workload (added
// 2026-10-22, PRD.md §8.3). Lives in chronos_core so the GUI's compare screen
// and the CLI's --compare print exactly the same numbers and the same verdict;
// analysis/analysis.py mirrors these definitions for the multi-workload report.
//
// Every value is computed from a SimulationResult — nothing here is authored
// or estimated (AGENTS.md: no illustrative metrics).

struct MetricSpec {
    std::string key;
    std::string label;
    std::string unit;      // shown after the value; empty for none
    bool lowerIsBetter;
    int decimals;
    std::string meaning;   // one plain-language line for the scoreboard
};

// The fixed metric list, in display order.
const std::vector<MetricSpec>& comparisonMetrics();

// Value of one metric for one run (by MetricSpec::key).
double metricValue(const SimulationResult& result, const std::string& key);

struct MetricRow {
    MetricSpec spec;
    double a = 0.0;
    double b = 0.0;
    int winner = -1;  // 0 = A, 1 = B, -1 = tie
};

struct Comparison {
    std::string nameA;
    std::string nameB;
    std::string workloadName;
    std::vector<MetricRow> rows;
    int winsA = 0;
    int winsB = 0;
    int ties = 0;
};

Comparison compareRuns(const SimulationResult& a, const SimulationResult& b);

// Plain-text scoreboard for the CLI.
std::string formatComparison(const Comparison& c);
