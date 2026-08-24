#include "workload_io.h"

#include <fstream>
#include <stdexcept>

#include "json.hpp"

using json = nlohmann::json;

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
