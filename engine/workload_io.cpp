#include "workload_io.h"

#include <fstream>
#include <set>
#include <stdexcept>
#include <string>

#include "json.hpp"

using json = nlohmann::json;

namespace {

// An optional scheduler-block field: absent or 0 means "derive from quantum";
// a negative value is a typo, not a request, so it is rejected rather than
// silently treated as absent.
int blockField(const json& block, const char* blockName, const char* field) {
    const int v = block.value(field, 0);
    if (v < 0) {
        throw std::runtime_error(std::string(blockName) + "." + field + " must be >= 0 (0 = derive from quantum)");
    }
    return v;
}

Workload parseWorkload(const json& j, const std::string& path) {
    if (!j.is_object()) throw std::runtime_error("workload must be a JSON object: " + path);

    Workload w;
    w.name = j.value("name", path);
    w.quantum = j.value("quantum", 4);
    if (w.quantum < 1) throw std::runtime_error("quantum must be >= 1 in " + path);

    // Optional scheduler blocks (PRD.md §5.2). Absent fields stay 0, which
    // means "derive from quantum" — see resolveMlfq() / resolveCfs().
    if (j.contains("mlfq")) {
        const json& m = j.at("mlfq");
        w.mlfq.levels = blockField(m, "mlfq", "levels");
        w.mlfq.baseQuantum = blockField(m, "mlfq", "baseQuantum");
        w.mlfq.boostInterval = blockField(m, "mlfq", "boostInterval");
    }
    if (j.contains("cfs")) {
        const json& c = j.at("cfs");
        w.cfs.targetLatency = blockField(c, "cfs", "targetLatency");
        w.cfs.minGranularity = blockField(c, "cfs", "minGranularity");
        w.cfs.wakeupGranularity = blockField(c, "cfs", "wakeupGranularity");
    }

    // Validated here because the tick loop trusts it: a zero-length burst
    // would never reach remainingTime == 0, duplicate PIDs would make every
    // per-PID lookup downstream ambiguous, and -1 is the simulator's "no
    // process" sentinel — a process with that PID would never be dispatched,
    // so the run would never end.
    const json& list = j.at("processes");
    if (!list.is_array() || list.empty()) {
        throw std::runtime_error("workload has no processes: " + path);
    }
    std::set<int> seen;
    int index = 0;
    for (const auto& jp : list) {
        ++index;
        Process p;
        try {
            p.pid = jp.value("pid", index);
            p.arrivalTime = jp.at("arrivalTime").get<int>();
            p.burstTime = jp.at("burstTime").get<int>();
            p.basePriority = jp.value("priority", 5);
            p.nice = jp.contains("nice") ? jp.at("nice").get<int>() : niceFromPriority(p.basePriority);
        } catch (const json::exception& e) {
            // nlohmann names the JSON type, not the field or the process.
            throw std::runtime_error("process #" + std::to_string(index) +
                                     ": pid, arrivalTime, burstTime, priority and nice must be integers (" +
                                     e.what() + ")");
        }
        p.remainingTime = p.burstTime;

        const std::string who = "P" + std::to_string(p.pid);
        if (p.pid < 0) throw std::runtime_error(who + ": pid must be >= 0");
        if (p.burstTime < 1) throw std::runtime_error(who + ": burstTime must be >= 1");
        if (p.arrivalTime < 0) throw std::runtime_error(who + ": arrivalTime must be >= 0");
        if (p.basePriority < 1 || p.basePriority > 10) {
            throw std::runtime_error(who + ": priority must be in 1..10");
        }
        if (p.nice < -20 || p.nice > 19) throw std::runtime_error(who + ": nice must be in -20..19");
        if (!seen.insert(p.pid).second) {
            throw std::runtime_error("duplicate pid " + std::to_string(p.pid) + " in " + path);
        }
        w.processes.push_back(p);
    }
    return w;
}

}  // namespace

Workload loadWorkload(const std::string& path) {
    std::ifstream in(path);
    if (!in) {
        throw std::runtime_error("could not open workload file: " + path);
    }
    json j;
    try {
        in >> j;
    } catch (const json::parse_error& e) {
        throw std::runtime_error("parse error in " + path + ": " + e.what());
    }
    try {
        return parseWorkload(j, path);
    } catch (const json::exception& e) {
        // Anything else nlohmann raises — a missing "processes" key, a block
        // that is not an object — named with the file it came from.
        throw std::runtime_error("invalid workload " + path + ": " + e.what());
    }
}
