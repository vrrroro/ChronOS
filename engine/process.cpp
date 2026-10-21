#include "process.h"

#include <algorithm>

int niceFromPriority(int priority) {
    return std::clamp((5 - priority) * 2, -20, 19);
}

std::string stateToString(State s) {
    switch (s) {
        case State::NEW: return "NEW";
        case State::READY: return "READY";
        case State::RUNNING: return "RUNNING";
        case State::WAITING: return "WAITING";
        case State::TERMINATED: return "TERMINATED";
    }
    return "UNKNOWN";
}

std::string processClassToString(ProcessClass c) {
    switch (c) {
        case ProcessClass::UNKNOWN: return "UNKNOWN";
        case ProcessClass::CPU_BOUND: return "CPU_BOUND";
        case ProcessClass::IO_BOUND: return "IO_BOUND";
        case ProcessClass::INTERACTIVE: return "INTERACTIVE";
        case ProcessClass::BALANCED: return "BALANCED";
    }
    return "UNKNOWN";
}
