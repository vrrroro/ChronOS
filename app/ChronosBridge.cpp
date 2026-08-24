#include "ChronosBridge.h"

#include <algorithm>
#include <cmath>
#include <vector>

#include "scheduler_factory.h"
#include "workload_io.h"

namespace {

const QStringList kAlgorithmKeys = {"fcfs", "sjf", "rr", "priority", "aars"};
const QStringList kAlgorithmLabels = {"FCFS", "SJF", "Round Robin", "Priority", "AARS"};

// One-line descriptions for the picker's hover card. These describe what each
// algorithm *does with a load*, not what it is — a viewer choosing a run wants
// to know what they are about to watch happen, and "first come, first served"
// tells them nothing they can see on screen.
const QStringList kAlgorithmDescriptions = {
    "Runs each process to completion in arrival order. Never preempts, so one long "
    "job at the front stalls everything behind it — the convoy effect, at its purest.",
    "Always picks the shortest remaining job. Provably optimal average waiting time, "
    "but long jobs are pushed back every time a shorter one arrives, so they can wait "
    "indefinitely.",
    "Gives every process a fixed time slice in rotation. Nothing starves and response "
    "time is even, paid for with a context switch at every quantum boundary.",
    "Always runs the highest-priority process, with aging to rescue anything that has "
    "waited too long. Without the aging term, low-priority work starves outright.",
    "Scores every ready process each tick on wait, burst, priority and observed "
    "behavior, then runs the winner. Adapts to the workload rather than assuming one — "
    "and logs why it chose what it chose.",
};

// EDRD.md §2.3 — per-process identity is a fill glyph plus a green brightness
// step, indexed pid % 8, replacing the earlier eight-hue palette. Monochrome is
// the point of the Terminal CLI system, and a fill character survives greyscale,
// a projector, and deuteranopia in a way hue does not. The shades here must stay
// in sync with Theme.qml's procShades — QML resolves the glyph from the slot,
// C++ still hands out the shade for anything that needs a color directly.
const QStringList kProcessShades = {
    QStringLiteral("#33FF00"), QStringLiteral("#5CFF3D"), QStringLiteral("#29CC00"), QStringLiteral("#21A600"),
    QStringLiteral("#8AFF75"), QStringLiteral("#1E8F10"), QStringLiteral("#B8FFA8"), QStringLiteral("#177A0C"),
};

} // namespace

ChronosBridge::ChronosBridge(QObject* parent)
    : QObject(parent), m_workloadModel(new WorkloadListModel(this)) {
    m_selectedAlgorithm = kAlgorithmKeys.first();
}

QStringList ChronosBridge::algorithmKeys() const { return kAlgorithmKeys; }
QStringList ChronosBridge::algorithmLabels() const { return kAlgorithmLabels; }
QStringList ChronosBridge::algorithmDescriptions() const { return kAlgorithmDescriptions; }

void ChronosBridge::setSelectedAlgorithm(const QString& algo) {
    if (m_selectedAlgorithm == algo) return;
    m_selectedAlgorithm = algo;
    emit selectedAlgorithmChanged();
}

void ChronosBridge::setSelectedWorkloadPath(const QString& path) {
    if (m_selectedWorkloadPath == path) return;
    m_selectedWorkloadPath = path;
    emit selectedWorkloadPathChanged();
}

int ChronosBridge::maxTick() const {
    int m = 0;
    for (const auto& g : m_result.gantt) m = std::max(m, g.end);
    for (const auto& p : m_result.processStats) m = std::max(m, p.completionTime);
    return m;
}

QString ChronosBridge::resultAlgorithmName() const { return QString::fromStdString(m_result.algorithm); }
QString ChronosBridge::resultWorkloadName() const { return QString::fromStdString(m_result.workloadName); }
bool ChronosBridge::isAars() const { return resultAlgorithmName().compare(QStringLiteral("AARS"), Qt::CaseInsensitive) == 0; }
int ChronosBridge::processCount() const { return static_cast<int>(m_result.processStats.size()); }

QString ChronosBridge::processColor(int pid) const {
    const int n = kProcessShades.size();
    int idx = ((pid % n) + n) % n;
    return kProcessShades.at(idx);
}

// EDRD.md §2.3 — the slot index QML uses to resolve both the fill glyph and
// the shade from Theme. Kept alongside processColor() rather than replacing it:
// a few call sites genuinely want a color and nothing else.
int ChronosBridge::processSlot(int pid) const {
    const int n = kProcessShades.size();
    return ((pid % n) + n) % n;
}

void ChronosBridge::rebuildMeta() {
    m_meta.clear();
    for (const auto& p : m_result.processStats) {
        ProcessMeta meta;
        meta.turnaroundTime = p.turnaroundTime;
        meta.waitingTimeFinal = p.waitingTime;
        meta.responseTime = p.responseTime;
        meta.completionTime = p.completionTime;
        // Read directly rather than back-derived: ProcessStat now carries
        // arrivalTime/burstTime (PRD §5.3), and the old
        // `burst = turnaround - waiting` identity silently breaks the moment
        // any I/O wait time enters the model.
        meta.burstTime = p.burstTime;
        meta.arrivalTime = p.arrivalTime;
        meta.contextSwitches = p.contextSwitches;
        meta.predictedClass = QString::fromStdString(processClassToString(p.predictedClass));
        m_meta[p.pid] = meta;
    }
}

bool ChronosBridge::runSelectedSimulation() {
    m_errorMessage.clear();
    try {
        Workload workload = loadWorkload(m_selectedWorkloadPath.toStdString());
        auto scheduler = makeScheduler(m_selectedAlgorithm.toStdString(), workload);
        m_result = ::runSimulation(workload, *scheduler, algorithmDisplayName(m_selectedAlgorithm.toStdString()));
        rebuildMeta();
        m_hasResult = true;
        emit resultChanged();
        return true;
    } catch (const std::exception& e) {
        m_errorMessage = QString::fromStdString(e.what());
        m_hasResult = false;
        emit errorChanged();
        emit resultChanged();
        return false;
    }
}

int ChronosBridge::ticksRunUpTo(int pid, int tick) const {
    int sum = 0;
    for (const auto& g : m_result.gantt) {
        if (g.pid != pid) continue;
        sum += std::max(0, std::min(g.end, tick) - g.start);
    }
    return sum;
}

const DecisionLog* ChronosBridge::lastDecisionAt(int tick) const {
    const DecisionLog* found = nullptr;
    for (const auto& d : m_result.decisionLog) {
        if (d.tick <= tick) found = &d;
        else break;
    }
    return found;
}

const GanttEntry* ChronosBridge::runningSegmentAt(int tick) const {
    for (const auto& g : m_result.gantt) {
        if (tick >= g.start && tick < g.end) return &g;
    }
    return nullptr;
}

int ChronosBridge::cpuUtilizationAt(int tick) const {
    if (tick <= 0) return 0;
    int busy = 0;
    for (const auto& g : m_result.gantt) {
        busy += std::max(0, std::min(g.end, tick) - std::min(g.start, tick));
    }
    return static_cast<int>(std::lround(100.0 * busy / tick));
}

int ChronosBridge::contextSwitchesAt(int tick) const {
    int switches = 0;
    const DecisionLog* prev = nullptr;
    for (const auto& d : m_result.decisionLog) {
        if (d.tick > tick) break;
        if (prev && prev->chosen != d.chosen) switches++;
        prev = &d;
    }
    return switches;
}

QVariantList ChronosBridge::ganttSegments() const {
    QVariantList out;
    for (const auto& g : m_result.gantt) {
        QVariantMap m;
        m["pid"] = g.pid;
        m["start"] = g.start;
        m["end"] = g.end;
        m["reason"] = QString::fromStdString(g.reason);
        m["color"] = processColor(g.pid);
        out.push_back(m);
    }
    return out;
}

QVariantList ChronosBridge::readyQueueAt(int tick) const {
    QVariantList out;
    const DecisionLog* decision = lastDecisionAt(tick);
    if (!decision) return out;

    const GanttEntry* runningSeg = runningSegmentAt(tick);
    const int runningPid = runningSeg ? runningSeg->pid : -1;
    const bool aars = isAars();

    struct Row {
        int pid;
        double score;
        int priority;
        int burstRemaining;
        int wait;
        QString cls;
        bool isRunning;
    };
    std::vector<Row> rows;

    for (const auto& c : decision->candidates) {
        auto it = m_meta.find(c.pid);
        if (it == m_meta.end()) continue;
        const ProcessMeta& meta = it->second;
        if (meta.arrivalTime > tick || meta.completionTime <= tick) continue;

        const int ranSoFar = ticksRunUpTo(c.pid, tick);
        const int waitSoFar = std::max(0, tick - meta.arrivalTime - ranSoFar);

        rows.push_back(Row{
            c.pid, c.score, c.priority, meta.burstTime - ranSoFar, waitSoFar,
            QString::fromStdString(c.predictedClass), c.pid == runningPid,
        });
    }

    if (aars) {
        std::sort(rows.begin(), rows.end(), [](const Row& a, const Row& b) { return a.score > b.score; });
    } else {
        std::sort(rows.begin(), rows.end(), [](const Row& a, const Row& b) {
            if (a.priority != b.priority) return a.priority > b.priority;
            return a.pid < b.pid;
        });
    }

    for (const auto& r : rows) {
        QVariantMap m;
        m["pid"] = r.pid;
        m["score"] = r.score;
        m["priority"] = r.priority;
        m["burstRemaining"] = r.burstRemaining;
        m["wait"] = r.wait;
        // UNKNOWN reads as an error state to anyone who has not read the
        // classifier. It only ever means "this process has not run yet, so
        // there is nothing to classify from" — PENDING says exactly that, and
        // is a thing the viewer can watch resolve on the timeline.
        m["cls"] = (r.cls == QStringLiteral("UNKNOWN")) ? QStringLiteral("PENDING") : r.cls;
        m["isRunning"] = r.isRunning;
        m["slot"] = processSlot(r.pid);
        m["color"] = processColor(r.pid);
        out.push_back(m);
    }
    return out;
}

QVariantMap ChronosBridge::whyPanelAt(int tick) const {
    QVariantMap out;
    const DecisionLog* decision = lastDecisionAt(tick);
    if (!decision) {
        out["hasDecision"] = false;
        return out;
    }
    out["hasDecision"] = true;
    out["pid"] = decision->chosen;
    out["color"] = processColor(decision->chosen);

    double score = 0;
    for (const auto& c : decision->candidates) {
        if (c.pid == decision->chosen) { score = c.score; break; }
    }
    out["score"] = score;

    QVariantList reasons;
    std::vector<std::pair<QString, double>> positives, negatives;

    for (const auto& tagStd : decision->reasonTags) {
        const QString tag = QString::fromStdString(tagStd);
        QVariantMap reason;
        bool parsed = false;

        const int colon = tag.lastIndexOf(QLatin1Char(':'));
        if (colon > 0) {
            const QString namePart = tag.left(colon);
            const QString valuePart = tag.mid(colon + 1);
            if (!valuePart.isEmpty() && (valuePart.at(0) == QLatin1Char('+') || valuePart.at(0) == QLatin1Char('-'))) {
                bool ok = false;
                const double val = valuePart.toDouble(&ok);
                if (ok) {
                    parsed = true;
                    QString label = namePart;
                    label.replace(QLatin1Char('_'), QLatin1Char(' '));
                    label = label.toUpper();
                    const bool positive = val >= 0;
                    reason["text"] = label + QStringLiteral(": ");
                    reason["delta"] = QStringLiteral("%1%2 %3")
                                           .arg(positive ? QStringLiteral("+") : QStringLiteral("−"))
                                           .arg(std::abs(val))
                                           .arg(positive ? QStringLiteral("▲") : QStringLiteral("▼"));
                    reason["positive"] = positive;
                    if (positive) positives.push_back({label, val});
                    else negatives.push_back({label, std::abs(val)});
                }
            }
        }

        if (!parsed) {
            if (tag == QStringLiteral("only_candidate")) {
                reason["text"] = QStringLiteral("Only ready process — no other candidates this decision");
            } else if (tag == QStringLiteral("highest_score")) {
                if (decision->candidates.size() > 1) {
                    std::vector<Candidate> sorted = decision->candidates;
                    std::sort(sorted.begin(), sorted.end(), [](const Candidate& a, const Candidate& b) { return a.score > b.score; });
                    // Kept short deliberately: this is the widest line in the why-panel,
                    // and at the panel's width the longer phrasing wrapped to a
                    // second line, pushing the last score term out of view.
                    reason["text"] = QStringLiteral("Top score %1 (next %2)")
                                          .arg(sorted[0].score, 0, 'f', 1)
                                          .arg(sorted[1].score, 0, 'f', 1);
                } else {
                    reason["text"] = QStringLiteral("Highest adaptive score");
                }
            } else {
                QString t = tag;
                t.replace(QLatin1Char('_'), QLatin1Char(' '));
                reason["text"] = t;
            }
        }
        reasons.push_back(reason);
    }
    out["reasons"] = reasons;

    double totalAbs = 0;
    for (const auto& p : positives) totalAbs += p.second;
    for (const auto& n : negatives) totalAbs += n.second;
    if (totalAbs <= 0) totalAbs = 1;

    QVariantList segments;
    for (const auto& p : positives) {
        QVariantMap seg;
        seg["label"] = p.first;
        seg["pct"] = (p.second / totalAbs) * 100.0;
        seg["positive"] = true;
        segments.push_back(seg);
    }
    for (const auto& n : negatives) {
        QVariantMap seg;
        seg["label"] = n.first;
        seg["pct"] = (n.second / totalAbs) * 100.0;
        seg["positive"] = false;
        segments.push_back(seg);
    }
    out["scoreSegments"] = segments;

    return out;
}

QVariantList ChronosBridge::agingListAt(int tick) const {
    QVariantList out;
    const DecisionLog* decision = lastDecisionAt(tick);
    if (!decision) return out;

    const GanttEntry* runningSeg = runningSegmentAt(tick);
    const int runningPid = runningSeg ? runningSeg->pid : -1;

    for (const auto& c : decision->candidates) {
        if (c.pid == runningPid) continue;
        auto it = m_meta.find(c.pid);
        if (it == m_meta.end()) continue;
        const ProcessMeta& meta = it->second;
        if (meta.arrivalTime > tick || meta.completionTime <= tick) continue;

        const int ranSoFar = ticksRunUpTo(c.pid, tick);
        const int waitSoFar = std::max(0, tick - meta.arrivalTime - ranSoFar);
        const double bonus = std::min(waitSoFar / 2.0, 10.0);
        if (bonus <= 0) continue;

        QVariantMap m;
        m["pid"] = c.pid;
        m["waitSoFar"] = waitSoFar;
        m["bonus"] = bonus;
        m["aboveThreshold"] = bonus >= 8.0;
        out.push_back(m);
    }
    return out;
}

QVariantList ChronosBridge::processTickerAt(int tick) const {
    QVariantList out;
    for (const auto& p : m_result.processStats) {
        auto it = m_meta.find(p.pid);
        if (it == m_meta.end()) continue;
        const ProcessMeta& meta = it->second;

        const int ranSoFar = std::min(meta.burstTime, ticksRunUpTo(p.pid, tick));
        const bool done = tick >= meta.completionTime;
        const double pct = meta.burstTime > 0 ? (100.0 * ranSoFar / meta.burstTime) : 100.0;

        QVariantMap m2;
        m2["pid"] = p.pid;
        m2["slot"] = processSlot(p.pid);
        m2["color"] = processColor(p.pid);
        m2["progressPct"] = pct;
        m2["done"] = done;
        m2["arrived"] = tick >= meta.arrivalTime;
        // Everything below feeds the hover HUD (EDRD §5.10). Computed here
        // rather than in QML so the panel stays a view over derived data.
        m2["running"] = runningSegmentAt(tick) && runningSegmentAt(tick)->pid == p.pid;
        m2["ranSoFar"] = ranSoFar;
        m2["burstTime"] = meta.burstTime;
        m2["remaining"] = std::max(0, meta.burstTime - ranSoFar);
        m2["arrivalTime"] = meta.arrivalTime;
        m2["completionTime"] = meta.completionTime;
        m2["waitingTime"] = meta.waitingTimeFinal;
        m2["turnaroundTime"] = meta.turnaroundTime;
        m2["responseTime"] = meta.responseTime;
        m2["contextSwitches"] = meta.contextSwitches;
        // UNKNOWN means "never ran", which is only ever true before the first
        // dispatch. PENDING says that in a word a viewer can act on.
        m2["cls"] = meta.predictedClass == QStringLiteral("UNKNOWN")
                        ? QStringLiteral("PENDING") : meta.predictedClass;
        m2["state"] = done ? QStringLiteral("DONE")
                           : (tick < meta.arrivalTime ? QStringLiteral("NOT ARRIVED")
                                                      : (m2["running"].toBool()
                                                             ? QStringLiteral("RUNNING")
                                                             : QStringLiteral("READY")));
        out.push_back(m2);
    }
    return out;
}
