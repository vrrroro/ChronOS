#include <iostream>
#include <memory>

#include "process.h"
#include "simulator.h"
#include "workload_io.h"
#include "scheduler_factory.h"

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
