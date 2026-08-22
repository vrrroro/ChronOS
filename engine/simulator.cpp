#include "simulator.h"

#include <algorithm>
#include <fstream>
#include <sstream>

#include "behavior_analyzer.h"
#include "json.hpp"

using json = nlohmann::json;

namespace {

std::string summarizeReason(const DecisionLog& dl) {
    if (dl.reasonTags.empty()) return "Scheduling decision";
    std::ostringstream oss;
    oss << "Selected P" << dl.chosen << ": ";
    for (size_t i = 0; i < dl.reasonTags.size(); ++i) {
        if (i > 0) oss << ", ";
        oss << dl.reasonTags[i];
    }
    return oss.str();
}

} // namespace

// ARCHITECTURE.md §3.3, corrected in one deliberate way: the pseudocode calls
// scheduler.selectNext(readyQueue, tick) BEFORE pushing the just-preempted
// running process back into readyQueue, which would make it structurally
// impossible for a quantum-based scheduler (RR/AARS) to ever reselect the
// same process when it's the only one ready. Here the preempted process is
// pushed back into readyQueue first, then selectNext sees the full candidate
// set (itself included) — this is required for RR to behave correctly and
// does not change behavior for non-preemptive schedulers (FCFS/SJF/Priority
// never revisit a process mid-slice since their currentQuantum() is -1).
SimulationResult runSimulation(const Workload& workload, Scheduler& scheduler, const std::string& algorithmName) {
    SimulationResult result;
    result.algorithm = algorithmName;
    result.workloadName = workload.name;

    const int totalProcesses = static_cast<int>(workload.processes.size());
    if (totalProcesses == 0) {
        result.summary = Summary{};
        return result;
    }

    std::vector<Process> newQueue = workload.processes;
    std::sort(newQueue.begin(), newQueue.end(),
              [](const Process& a, const Process& b) { return a.arrivalTime < b.arrivalTime; });

    std::vector<Process> readyQueue;
    std::vector<Process> completed;
    size_t newIdx = 0;

    bool hasRunning = false;
    Process running{};
    int quantumRemaining = 0;
    int ticksInSlice = 0;
    int totalBusyTicks = 0;
    int tick = 0;
    std::string lastReason;
    int lastDispatchedPid = -1; // persists across completions/idle gaps, unlike `running`

    // Tracks a process's CPU burst as "cumulative time on the CPU since it
    // was last displaced by a DIFFERENT process," not per-quantum-dispatch.
    // Integration-time fix: recording a raw quantum-truncated slice (as
    // ARCHITECTURE §3.3's literal pseudocode implies) caps every burst
    // history entry at AARS's own quantum table (max 8 — PRD §6.4), which
    // is below the CPU_BOUND threshold (avgBurst>15 — PRD §6.3), making
    // that classification mathematically unreachable regardless of how
    // CPU-hungry a process actually is. A process that keeps winning
    // reselection against nothing/weaker competition (the real signature
    // of CPU-bound behavior) now keeps accumulating instead of having its
    // history reset at every quantum boundary.
    int burstAccumPid = -1;
    int burstAccumTicks = 0;

    while (static_cast<int>(completed.size()) < totalProcesses) {
        // 1. Admit newly-arrived processes.
        while (newIdx < newQueue.size() && newQueue[newIdx].arrivalTime == tick) {
            Process p = newQueue[newIdx];
            p.state = State::READY;
            readyQueue.push_back(p);
            ++newIdx;
        }

        // 2. Update waiting stats for everyone sitting in readyQueue.
        for (auto& p : readyQueue) p.waitingTime++;

        // 3. (Re)classify anyone whose burst history may have changed.
        BehaviorAnalyzer::updateClassifications(readyQueue);

        // 4. Scheduling decision.
        if (!hasRunning || quantumRemaining == 0) {
            if (hasRunning) {
                // Don't record yet — the same process may win reselection
                // immediately (quantum simply ran out with nothing better
                // ready), in which case this isn't a real burst boundary.
                // Accumulate; only record once we know it was genuinely
                // displaced (below) or it completes (step 6).
                if (burstAccumPid == running.pid) {
                    burstAccumTicks += ticksInSlice;
                } else {
                    burstAccumPid = running.pid;
                    burstAccumTicks = ticksInSlice;
                }
                running.state = State::READY;
                readyQueue.push_back(running);
                hasRunning = false;
            }

            int nextPid = scheduler.selectNext(readyQueue, tick);

            if (nextPid != -1) {
                auto it = std::find_if(readyQueue.begin(), readyQueue.end(),
                                        [&](const Process& p) { return p.pid == nextPid; });
                Process chosen = *it;
                readyQueue.erase(it);

                // The previously-accumulating process lost reselection to a
                // different process — that's a genuine burst boundary, so
                // close out its accumulated run now. (Found fresh, after the
                // erase above, since erase() can invalidate other iterators
                // into the same vector.)
                if (burstAccumPid != -1 && burstAccumPid != nextPid) {
                    auto dispIt = std::find_if(readyQueue.begin(), readyQueue.end(),
                                                [&](const Process& p) { return p.pid == burstAccumPid; });
                    if (dispIt != readyQueue.end()) {
                        BehaviorAnalyzer::recordCompletedBurst(*dispIt, burstAccumTicks);
                    }
                    burstAccumPid = -1;
                    burstAccumTicks = 0;
                }

                // Counts any actual change of occupant on the CPU — including a
                // process completing and a different one starting, not just a
                // mid-slice preemption (ARCHITECTURE.md §3.3's invariant: "counted
                // only when the running PID actually changes"). lastDispatchedPid
                // survives completions/idle gaps so this comparison is correct
                // across them; the very first-ever dispatch (-1) never counts.
                if (lastDispatchedPid != -1 && lastDispatchedPid != nextPid) {
                    chosen.contextSwitches++;
                    result.summary.contextSwitches++;
                }
                lastDispatchedPid = nextPid;

                chosen.state = State::RUNNING;
                if (chosen.responseTime == -1) {
                    chosen.startTime = tick;
                    chosen.responseTime = tick - chosen.arrivalTime;
                }

                running = chosen;
                hasRunning = true;
                ticksInSlice = 0;
                quantumRemaining = scheduler.currentQuantum(running);
            }

            DecisionLog dl = scheduler.explainLastDecision();
            result.decisionLog.push_back(dl);
            lastReason = summarizeReason(dl);
        }

        // 5. Execute one tick.
        if (hasRunning) {
            if (!result.gantt.empty() && result.gantt.back().pid == running.pid &&
                result.gantt.back().end == tick) {
                result.gantt.back().end = tick + 1;
            } else {
                result.gantt.push_back(GanttEntry{running.pid, tick, tick + 1, lastReason});
            }

            running.remainingTime--;
            ticksInSlice++;
            if (quantumRemaining > 0) quantumRemaining--;
            totalBusyTicks++;

            // 6. Check completion.
            if (running.remainingTime == 0) {
                running.completionTime = tick + 1;
                running.turnaroundTime = running.completionTime - running.arrivalTime;
                running.waitingTime = running.turnaroundTime - running.burstTime;
                running.state = State::TERMINATED;
                // Completion always closes the burst outright — fold in any
                // accumulated run from earlier same-PID reselections so the
                // recorded length reflects the whole uninterrupted stretch,
                // not just this final (often short, leftover) dispatch.
                int finalBurst = ticksInSlice;
                if (burstAccumPid == running.pid) {
                    finalBurst += burstAccumTicks;
                    burstAccumPid = -1;
                    burstAccumTicks = 0;
                }
                BehaviorAnalyzer::recordCompletedBurst(running, finalBurst);
                completed.push_back(running);
                hasRunning = false;
                quantumRemaining = 0;
            }
        }

        ++tick;
    }

    // Build processStats + summary from completed processes.
    double sumWaiting = 0, sumTurnaround = 0, sumResponse = 0;
    for (const auto& p : completed) {
        result.processStats.push_back(ProcessStat{p.pid, p.waitingTime, p.turnaroundTime, p.responseTime, p.completionTime});
        sumWaiting += p.waitingTime;
        sumTurnaround += p.turnaroundTime;
        sumResponse += p.responseTime;
    }
    std::sort(result.processStats.begin(), result.processStats.end(),
              [](const ProcessStat& a, const ProcessStat& b) { return a.pid < b.pid; });

    result.summary.avgWaitingTime = sumWaiting / totalProcesses;
    result.summary.avgTurnaroundTime = sumTurnaround / totalProcesses;
    result.summary.avgResponseTime = sumResponse / totalProcesses;
    result.summary.cpuUtilization = tick > 0 ? static_cast<double>(totalBusyTicks) / tick : 0.0;
    result.summary.throughput = tick > 0 ? static_cast<double>(totalProcesses) / tick : 0.0;

    return result;
}

void writeResultJson(const SimulationResult& result, const std::string& outPath) {
    json j;
    j["algorithm"] = result.algorithm;
    j["workloadName"] = result.workloadName;

    j["gantt"] = json::array();
    for (const auto& g : result.gantt) {
        j["gantt"].push_back({{"pid", g.pid}, {"start", g.start}, {"end", g.end}, {"reason", g.reason}});
    }

    j["decisionLog"] = json::array();
    for (const auto& dl : result.decisionLog) {
        json candidates = json::array();
        for (const auto& c : dl.candidates) {
            candidates.push_back({{"pid", c.pid}, {"score", c.score}, {"priority", c.priority},
                                   {"burstRemaining", c.burstRemaining}, {"class", c.predictedClass}});
        }
        j["decisionLog"].push_back({{"tick", dl.tick}, {"chosen", dl.chosen},
                                     {"candidates", candidates}, {"reasonTags", dl.reasonTags}});
    }

    j["processStats"] = json::array();
    for (const auto& p : result.processStats) {
        j["processStats"].push_back({{"pid", p.pid}, {"waitingTime", p.waitingTime},
                                      {"turnaroundTime", p.turnaroundTime}, {"responseTime", p.responseTime},
                                      {"completionTime", p.completionTime}});
    }

    j["summary"] = {
        {"avgWaitingTime", result.summary.avgWaitingTime},
        {"avgTurnaroundTime", result.summary.avgTurnaroundTime},
        {"avgResponseTime", result.summary.avgResponseTime},
        {"contextSwitches", result.summary.contextSwitches},
        {"cpuUtilization", result.summary.cpuUtilization},
        {"throughput", result.summary.throughput},
    };

    std::ofstream out(outPath);
    out << j.dump(2);
}

void writeSchedulerLog(const SimulationResult& result, const std::string& logPath) {
    std::ofstream out(logPath);
    out << "ChronOS scheduler decision log\n";
    out << "algorithm: " << result.algorithm << "\n";
    out << "workload: " << result.workloadName << "\n";
    out << "----------------------------------------\n";
    for (const auto& dl : result.decisionLog) {
        out << "tick " << dl.tick << ": chose P" << dl.chosen << "\n";
        out << "  candidates:";
        for (const auto& c : dl.candidates) {
            out << " P" << c.pid << "=" << c.score;
        }
        out << "\n  reasons:";
        for (const auto& tag : dl.reasonTags) {
            out << " " << tag;
        }
        out << "\n";
    }
}
