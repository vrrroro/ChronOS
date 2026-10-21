#include <iostream>
#include <memory>

#include "comparison.h"
#include "process.h"
#include "simulator.h"
#include "workload_io.h"
#include "scheduler_factory.h"

namespace {

void usage() {
    std::cerr << "usage: chronos --algorithm <" << kAlgorithmUsage << "> --workload <path> --out <path>\n"
              << "       chronos --compare <a>,<b> --workload <path> [--out <dir>]\n"
              << "         runs both algorithms on the same processes and prints which is better\n"
              << "         on each metric; with --out, also writes <dir>/<name>_<a>.json and _<b>.json\n";
}

}  // namespace

int main(int argc, char** argv) {
    std::string algorithm, workloadPath, outPath, compare;

    try {
        for (int i = 1; i < argc; ++i) {
            std::string arg = argv[i];
            auto nextArg = [&](const char* flag) -> std::string {
                if (i + 1 >= argc) throw std::runtime_error(std::string("missing value for ") + flag);
                return argv[++i];
            };
            if (arg == "--algorithm") algorithm = nextArg("--algorithm");
            else if (arg == "--workload") workloadPath = nextArg("--workload");
            else if (arg == "--out") outPath = nextArg("--out");
            else if (arg == "--compare") compare = nextArg("--compare");
            else {
                std::cerr << "unknown argument: " << arg << "\n";
                usage();
                return 1;
            }
        }
    } catch (const std::exception& e) {
        std::cerr << "chronos: error: " << e.what() << "\n";
        usage();
        return 1;
    }

    // --compare a,b: one workload, two schedulers, one scoreboard.
    if (!compare.empty()) {
        const size_t comma = compare.find(',');
        if (workloadPath.empty() || comma == std::string::npos) {
            usage();
            return 1;
        }
        const std::string keyA = compare.substr(0, comma);
        const std::string keyB = compare.substr(comma + 1);
        if (keyA == keyB) {
            std::cerr << "chronos: error: --compare needs two different algorithms\n";
            return 1;
        }
        try {
            Workload workload = loadWorkload(workloadPath);
            auto schedA = makeScheduler(keyA, workload);
            auto schedB = makeScheduler(keyB, workload);
            SimulationResult a = runSimulation(workload, *schedA, algorithmDisplayName(keyA));
            SimulationResult b = runSimulation(workload, *schedB, algorithmDisplayName(keyB));
            if (!outPath.empty()) {
                std::string stem = workloadPath.substr(workloadPath.find_last_of("/\\") + 1);
                stem = stem.substr(0, stem.find_last_of('.'));
                writeResultJson(a, outPath + "/" + stem + "_" + keyA + ".json");
                writeResultJson(b, outPath + "/" + stem + "_" + keyB + ".json");
            }
            std::cout << formatComparison(compareRuns(a, b));
        } catch (const std::exception& e) {
            std::cerr << "chronos: error: " << e.what() << "\n";
            return 1;
        }
        return 0;
    }

    if (algorithm.empty() || workloadPath.empty() || outPath.empty()) {
        usage();
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
