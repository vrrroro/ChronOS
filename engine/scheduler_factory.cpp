#include "scheduler_factory.h"

#include <stdexcept>

#include "schedulers/fcfs.h"
#include "schedulers/sjf.h"
#include "schedulers/round_robin.h"
#include "schedulers/priority.h"
#include "schedulers/aars.h"
#include "schedulers/mlfq.h"
#include "schedulers/cfs.h"

std::unique_ptr<Scheduler> makeScheduler(const std::string& algorithm, const Workload& workload) {
    if (algorithm == "fcfs") return std::make_unique<FCFSScheduler>();
    if (algorithm == "sjf") return std::make_unique<SJFScheduler>();
    if (algorithm == "rr") return std::make_unique<RoundRobinScheduler>(workload.quantum);
    if (algorithm == "priority") return std::make_unique<PriorityScheduler>();
    if (algorithm == "aars") return std::make_unique<AARSScheduler>();
    if (algorithm == "mlfq") return std::make_unique<MLFQScheduler>(resolveMlfq(workload.mlfq, workload.quantum));
    if (algorithm == "cfs") return std::make_unique<CFSScheduler>(resolveCfs(workload.cfs, workload.quantum));
    throw std::runtime_error("unknown algorithm: " + algorithm + " (expected " + kAlgorithmUsage + ")");
}

std::unique_ptr<Scheduler> makeScheduler(const std::string& algorithm, const Workload& workload,
                                         const AarsParams& params) {
    if (algorithm == "aars") {
        return std::make_unique<AARSScheduler>(params, params == AarsParams{} ? "AARS" : "AARS (tuned)");
    }
    return makeScheduler(algorithm, workload);
}

std::string algorithmDisplayName(const std::string& algorithm) {
    if (algorithm == "fcfs") return "FCFS";
    if (algorithm == "sjf") return "SJF";
    if (algorithm == "rr") return "Round Robin";
    if (algorithm == "priority") return "Priority";
    if (algorithm == "aars") return "AARS";
    if (algorithm == "mlfq") return "MLFQ (Windows)";
    if (algorithm == "cfs") return "CFS (Linux)";
    return algorithm;
}
