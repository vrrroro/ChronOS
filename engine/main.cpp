#include <cstring>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>

#include "json.hpp"
#include "process.h"
#include "simulator.h"
#include "schedulers/fcfs.h"
#include "schedulers/sjf.h"
#include "schedulers/round_robin.h"
#include "schedulers/priority.h"
#include "schedulers/aars.h"

using json = nlohmann::json;

namespace {

Workload loadWorkload(const std::string& path) {
    std::ifstream in(path);
    if (!in) {
        throw std::runtime_error("could not open workload file: " + path);
    }
    json j;
    in >> j;

    Workload w;
    w.name = j.value("name", path);
    w.quantum = j.value("quantum", 4);

    int pidCounter = 1;
    for (const auto& jp : j.at("processes")) {
        Process p;
        p.pid = jp.value("pid", pidCounter++);
        p.arrivalTime = jp.at("arrivalTime").get<int>();
        p.burstTime = jp.at("burstTime").get<int>();
        p.remainingTime = p.burstTime;
        p.basePriority = jp.value("priority", 5);
        w.processes.push_back(p);
    }
    return w;
}

std::unique_ptr<Scheduler> makeScheduler(const std::string& algorithm, const Workload& workload) {
    if (algorithm == "fcfs") return std::make_unique<FCFSScheduler>();
    if (algorithm == "sjf") return std::make_unique<SJFScheduler>();
    if (algorithm == "rr") return std::make_unique<RoundRobinScheduler>(workload.quantum);
    if (algorithm == "priority") return std::make_unique<PriorityScheduler>();
    if (algorithm == "aars") return std::make_unique<AARSScheduler>();
    throw std::runtime_error("unknown algorithm: " + algorithm + " (expected fcfs|sjf|rr|priority|aars)");
}

std::string algorithmDisplayName(const std::string& algorithm) {
    if (algorithm == "fcfs") return "FCFS";
    if (algorithm == "sjf") return "SJF";
    if (algorithm == "rr") return "Round Robin";
    if (algorithm == "priority") return "Priority";
    if (algorithm == "aars") return "AARS";
    return algorithm;
}

} // namespace

int main(int argc, char** argv) {
    std::string algorithm, workloadPath, outPath;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        auto nextArg = [&](const char* flag) -> std::string {
            if (i + 1 >= argc) throw std::runtime_error(std::string("missing value for ") + flag);
            return argv[++i];
        };
        if (arg == "--algorithm") algorithm = nextArg("--algorithm");
        else if (arg == "--workload") workloadPath = nextArg("--workload");
        else if (arg == "--out") outPath = nextArg("--out");
        else {
            std::cerr << "unknown argument: " << arg << "\n";
            return 1;
        }
    }

    if (algorithm.empty() || workloadPath.empty() || outPath.empty()) {
        std::cerr << "usage: chronos --algorithm <fcfs|sjf|rr|priority|aars> --workload <path> --out <path>\n";
        return 1;
    }

    try {
        Workload workload = loadWorkload(workloadPath);
        std::unique_ptr<Scheduler> scheduler = makeScheduler(algorithm, workload);

        SimulationResult result = runSimulation(workload, *scheduler, algorithmDisplayName(algorithm));

        writeResultJson(result, outPath);
        writeSchedulerLog(result, "logs/scheduler.log");

        std::cout << "chronos: wrote " << outPath << " (" << result.processStats.size()
                  << " processes, " << result.gantt.size() << " gantt segments)\n";
    } catch (const std::exception& e) {
        std::cerr << "chronos: error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
