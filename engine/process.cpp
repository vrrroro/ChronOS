#include "process.h"

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
    }
    return "UNKNOWN";
}
