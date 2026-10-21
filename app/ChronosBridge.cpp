#include "ChronosBridge.h"

#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <vector>

#include "comparison.h"
#include "scheduler_factory.h"
#include "workload_io.h"

namespace {

// Order is the picker's order. Everything from kOsSectionStart on is listed in
// the picker's second section, the real operating-system schedulers.
const QStringList kAlgorithmKeys = {"fcfs", "sjf", "rr", "priority", "aars", "mlfq", "cfs"};
const QStringList kAlgorithmLabels = {"FCFS", "SJF", "Round Robin", "Priority", "AARS",
                                      "MLFQ (Windows)", "CFS (Linux)"};
constexpr int kOsSectionStart = 5;

// One-line descriptions. These describe what each algorithm *does with a
// load*, not what it is — a viewer choosing a run wants to know what they are
// about to watch happen.
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
    "Stacks round-robin queues by priority. New work starts at the top and sinks as it "
    "uses up its slices, so short jobs finish first without anyone knowing burst lengths.",
    "Runs whichever process has had the least weighted CPU time, in slices that shrink as "
    "load grows. Fair by construction rather than fast by design.",
};

// The picker's ABOUT card (added 2026-10-16, explicit user request). Editorial
// prose about how each algorithm behaves — deliberately no measured numbers,
// since AGENTS.md forbids illustrative metrics: anything quantitative a viewer
// wants comes from actually running it.
struct AboutEntry {
    const char* tagline;
    std::vector<std::pair<const char*, const char*>> traits;
    std::vector<const char*> strengths;
    std::vector<const char*> weaknesses;
};

const std::vector<AboutEntry> kAlgorithmAbout = {
    {"Runs each process to completion in the order it arrived.",
     {{"PICKS", "earliest arrival"}, {"PREEMPTS", "never"}, {"QUANTUM", "none"},
      {"NEEDS BURST LENGTHS", "no"}, {"STARVATION", "impossible"}},
     {"Simplest scheduler there is - trivial to implement and to predict",
      "Fewest context switches: one per process",
      "Nobody jumps the queue, so nothing ever starves"},
     {"Convoy effect: one long job at the front stalls every short job behind it",
      "Poor average waiting and response time on mixed loads",
      "Ignores priority entirely"}},
    {"Always runs the shortest waiting job next, to completion.",
     {{"PICKS", "smallest burst"}, {"PREEMPTS", "never"}, {"QUANTUM", "none"},
      {"NEEDS BURST LENGTHS", "yes - exact, in advance"}, {"STARVATION", "possible for long jobs"}},
     {"Provably minimal average waiting time when all jobs are ready together",
      "Few context switches",
      "Clears short jobs fast, so many processes finish early"},
     {"Needs burst lengths up front - a real OS can only estimate them",
      "Long jobs can wait indefinitely while shorter ones keep arriving",
      "Non-preemptive: a short arrival still waits for the job already running"}},
    {"Gives every ready process a fixed time slice, in turn.",
     {{"PICKS", "head of the FIFO queue"}, {"PREEMPTS", "at every quantum boundary"},
      {"QUANTUM", "fixed, set by the workload"}, {"NEEDS BURST LENGTHS", "no"},
      {"STARVATION", "impossible"}},
     {"Low, even response time - every process runs soon after it arrives",
      "Fair share of the CPU, no starvation",
      "Needs no knowledge of burst lengths"},
     {"Most context switches of the classic algorithms",
      "Turnaround often worse than FCFS/SJF when bursts are similar",
      "Quantum is a trade-off: too small thrashes, too large becomes FCFS"}},
    {"Runs the highest-priority process, with aging so low-priority work still gets a turn.",
     {{"PICKS", "highest priority + aging"}, {"PREEMPTS", "never"}, {"QUANTUM", "none"},
      {"NEEDS BURST LENGTHS", "no"}, {"STARVATION", "prevented by aging (+1 per 5 ticks)"}},
     {"Important work goes first",
      "Aging guarantees every process eventually runs",
      "Few context switches"},
     {"Only as good as the priorities it was given",
      "Low-priority work can still wait a long time before aging catches up",
      "Ignores burst length, so convoys still form behind long high-priority jobs"}},
    {"Scores every ready process on priority, wait, observed behavior and burst history; runs the winner.",
     {{"PICKS", "highest adaptive score"}, {"PREEMPTS", "at quantum boundaries"},
      {"QUANTUM", "adaptive, by process class"}, {"NEEDS BURST LENGTHS", "no - learns them"},
      {"STARVATION", "prevented by capped aging"}},
     {"Adapts to behavior it observes instead of assuming one workload shape",
      "Response bonus gets new processes onto the CPU quickly",
      "Every decision is explained term by term in the why-panel"},
     {"More context switches than the non-preemptive algorithms",
      "Weights are hand-chosen starting guesses, not optimized",
      "No I/O model yet, so its I/O bonus never fires; no arrival preemption"}},
    {"Round-robin queues stacked by priority: a process sinks a level each time it uses up "
     "its allotment, and a periodic boost lifts everyone back to the top.",
     {{"PICKS", "head of highest non-empty queue"}, {"PREEMPTS", "yes - a higher queue wins at once"},
      {"QUANTUM", "doubles per level: q, 2q, 4q"}, {"NEEDS BURST LENGTHS", "no - learns from use"},
      {"STARVATION", "prevented by periodic boost"}},
     {"Short jobs finish in the top queue before long ones get going - SJF-like, without knowing bursts",
      "New arrivals start at the top and preempt, so response time is low",
      "Long jobs sink to long slices, so they switch less once there"},
     {"Many knobs (levels, quanta, boost period) and results depend on all of them",
      "Long jobs wait behind every new arrival until the next boost",
      "Textbook MLFQ: Windows' real scheduler adds 32 levels and I/O / GUI wake-up boosts this "
      "simulator cannot model"}},
    {"Tracks how much CPU each process has had, weighted by its nice value, and always runs "
     "whichever has had the least - the leftmost node of a red-black tree.",
     {{"PICKS", "lowest virtual runtime"}, {"PREEMPTS", "slice end, or a far-behind arrival"},
      {"QUANTUM", "weighted share of a period"}, {"NEEDS BURST LENGTHS", "no"},
      {"STARVATION", "impossible by construction"}},
     {"Proportional fairness: CPU share follows weight (nice), and nothing starves",
      "No queues or class rules - one number per process decides",
      "Slices shrink as load grows, so every process runs within a bounded period"},
     {"Fair is not fast: short jobs are not favoured, so average waiting can be high",
      "Small slices under load mean many context switches",
      "Real kernels credit tasks waking from sleep; nothing in this simulator sleeps, so that never applies"}},
};

ProcessKind kindFromKey(const QString& k) {
    if (k == QStringLiteral("CPU-BOUND")) return ProcessKind::CPU_BOUND;
    if (k == QStringLiteral("INTERACTIVE")) return ProcessKind::INTERACTIVE;
    return ProcessKind::BALANCED;
}

ArrivalPattern arrivalFromKey(const QString& k) {
    if (k == QStringLiteral("ALL AT ONCE")) return ArrivalPattern::ALL_AT_ONCE;
    if (k == QStringLiteral("CLUSTERED")) return ArrivalPattern::CLUSTERED;
    return ArrivalPattern::STAGGERED;
}

constexpr int kMaxCustomProcesses = 40;
constexpr int kMaxCustomGroups = 6;

// EDRD.md §2.3 — per-process identity is a neon hue, indexed pid % 8. QML
// resolves the same table through Theme.procShade(); this copy exists for
// the few C++ call sites that hand a color out directly, and must match it.
const QStringList kProcessShades = {
    QStringLiteral("#33FF00"), QStringLiteral("#00E5FF"), QStringLiteral("#FF3EC9"), QStringLiteral("#FFB000"),
    QStringLiteral("#4D9FFF"), QStringLiteral("#FF7A29"), QStringLiteral("#C77DFF"), QStringLiteral("#D4FF3E"),
};

QString signedInt(int v) {
    return v > 0 ? QStringLiteral("+%1").arg(v) : QString::number(v);
}

// One reason tag as the why-panel shows it: a sentence, plus — for the AARS
// formula terms and Priority's aging, which carry a signed contribution — a
// delta with its sign and arrow (EDRD §2.6: never color alone).
QVariantMap describeTag(const QString& tag, const DecisionLog& d) {
    QVariantMap out;
    const int colon = tag.indexOf(QLatin1Char(':'));
    const QString name = colon > 0 ? tag.left(colon) : tag;
    const QString value = colon > 0 ? tag.mid(colon + 1) : QString();
    const auto parts = [&]() { return value.split(QStringLiteral("_")); };

    // Signed formula terms: "aging_bonus:+4", "cpu_burst_penalty:-2.4".
    if (!value.isEmpty() && (value.at(0) == QLatin1Char('+') || value.at(0) == QLatin1Char('-'))) {
        bool ok = false;
        const double val = value.toDouble(&ok);
        if (ok) {
            QString label = name;
            label.replace(QLatin1Char('_'), QLatin1Char(' '));
            const bool positive = val >= 0;
            out["text"] = label.toUpper() + QStringLiteral(": ");
            out["delta"] = QStringLiteral("%1%2 %3")
                               .arg(positive ? QStringLiteral("+") : QStringLiteral("−"))
                               .arg(std::abs(val))
                               .arg(positive ? QStringLiteral("▲") : QStringLiteral("▼"));
            out["positive"] = positive;
            out["signed"] = true;
            out["label"] = label.toUpper();
            out["magnitude"] = std::abs(val);
            return out;
        }
    }

    QString text;
    if (name == QStringLiteral("only_candidate")) {
        text = QStringLiteral("Only ready process — no other candidates this decision");
    } else if (name == QStringLiteral("highest_score")) {
        if (d.candidates.size() > 1) {
            std::vector<Candidate> sorted = d.candidates;
            std::sort(sorted.begin(), sorted.end(),
                      [](const Candidate& a, const Candidate& b) { return a.score > b.score; });
            // Kept short deliberately: this is the widest line in the why-panel.
            text = QStringLiteral("Top score %1 (next %2)")
                       .arg(sorted[0].score, 0, 'f', 1)
                       .arg(sorted[1].score, 0, 'f', 1);
        } else {
            text = QStringLiteral("Highest adaptive score");
        }
    } else if (name == QStringLiteral("earliest_arrival")) {
        text = QStringLiteral("Earliest arrival among ready processes");
    } else if (name == QStringLiteral("shortest_burst")) {
        text = QStringLiteral("Shortest remaining burst");
    } else if (name == QStringLiteral("head_of_ready_queue")) {
        text = QStringLiteral("Head of the FIFO ready queue");
    } else if (name == QStringLiteral("highest_effective_priority")) {
        text = QStringLiteral("Highest effective priority (base + aging)");
    } else if (name == QStringLiteral("tie_break")) {
        text = QStringLiteral("Ties go to the lowest PID");
    } else if (name == QStringLiteral("quantum")) {
        text = QStringLiteral("Time slice: %1 ticks").arg(value);
    // --- MLFQ ---
    } else if (name == QStringLiteral("highest_queue")) {
        text = QStringLiteral("Highest non-empty queue runs first");
    } else if (name == QStringLiteral("queue")) {
        text = QStringLiteral("Runs from queue %1").arg(value);
    } else if (name == QStringLiteral("allotment")) {
        const QStringList p = parts();
        text = QStringLiteral("Allotment left at this level: %1 of %2 ticks")
                   .arg(p.value(0), p.value(2));
    } else if (name == QStringLiteral("round_robin_in_queue")) {
        text = QStringLiteral("Takes turns with the others in its queue");
    } else if (name == QStringLiteral("preempted")) {
        text = QStringLiteral("Preempted %1 — a higher queue had work").arg(value);
    } else if (name == QStringLiteral("demoted")) {
        const QStringList p = parts();
        text = QStringLiteral("%1 used its allotment → down to %2").arg(p.value(0), p.value(2));
    } else if (name == QStringLiteral("priority_boost")) {
        text = QStringLiteral("Priority boost: every process back to Q0");
    // --- CFS ---
    } else if (name == QStringLiteral("lowest_vruntime")) {
        text = QStringLiteral("Lowest vruntime — leftmost in the tree");
    } else if (name == QStringLiteral("vruntime")) {
        text = QStringLiteral("Its vruntime: %1").arg(value);
    } else if (name == QStringLiteral("next_vruntime")) {
        text = QStringLiteral("Next lowest vruntime: %1").arg(value);
    } else if (name == QStringLiteral("nice")) {
        const QStringList p = parts();
        text = QStringLiteral("nice %1 → weight %2").arg(signedInt(p.value(0).toInt()), p.value(2));
    } else if (name == QStringLiteral("slice")) {
        const QStringList p = parts();
        text = QStringLiteral("Slice: %1 of a %2-tick period").arg(p.value(0), p.value(2));
    } else if (name == QStringLiteral("wakeup_preempted")) {
        text = QStringLiteral("New arrival preempted %1 (it was too far ahead)").arg(value);
    } else {
        text = tag;
        text.replace(QLatin1Char('_'), QLatin1Char(' '));
    }
    out["text"] = text;
    return out;
}

}  // namespace

ChronosBridge::ChronosBridge(QObject* parent)
    : QObject(parent), m_workloadModel(new WorkloadListModel(this)) {
    m_selectedAlgorithm = kAlgorithmKeys.first();

    // Starting point for the custom workload builder: a small mix of all
    // three kinds, so the first thing a viewer sees already separates the
    // algorithms rather than an empty form.
    m_customSpec.seed = 7;
    m_customSpec.groups = {defaultGroup(ProcessKind::CPU_BOUND, 2),
                           defaultGroup(ProcessKind::BALANCED, 3),
                           defaultGroup(ProcessKind::INTERACTIVE, 4)};
}

QVariantList ChronosBridge::algorithmAbout() const {
    QVariantList out;
    for (const AboutEntry& a : kAlgorithmAbout) {
        QVariantList traits, strengths, weaknesses;
        for (const auto& t : a.traits) {
            traits.push_back(QVariantMap{{QStringLiteral("label"), QString::fromUtf8(t.first)},
                                         {QStringLiteral("value"), QString::fromUtf8(t.second)}});
        }
        for (const char* x : a.strengths) strengths.push_back(QString::fromUtf8(x));
        for (const char* x : a.weaknesses) weaknesses.push_back(QString::fromUtf8(x));
        out.push_back(QVariantMap{{QStringLiteral("tagline"), QString::fromUtf8(a.tagline)},
                                  {QStringLiteral("traits"), traits},
                                  {QStringLiteral("strengths"), strengths},
                                  {QStringLiteral("weaknesses"), weaknesses}});
    }
    return out;
}

// --- Tuning ----------------------------------------------------------------

QVariantMap ChronosBridge::paramsToMap(const AarsParams& p) {
    return {
        {QStringLiteral("priorityWeight"), p.priorityWeight},
        {QStringLiteral("agingDivisor"), p.agingDivisor},
        {QStringLiteral("agingCap"), p.agingCap},
        {QStringLiteral("ioBoundBonus"), p.ioBoundBonus},
        {QStringLiteral("interactiveBonus"), p.interactiveBonus},
        {QStringLiteral("responseBonus"), p.responseBonus},
        {QStringLiteral("burstPenaltyDivisor"), p.burstPenaltyDivisor},
        {QStringLiteral("burstPenaltyCap"), p.burstPenaltyCap},
        {QStringLiteral("quantumCpuBound"), p.quantumCpuBound},
        {QStringLiteral("quantumBalanced"), p.quantumBalanced},
        {QStringLiteral("quantumInteractive"), p.quantumInteractive},
        {QStringLiteral("quantumIoBound"), p.quantumIoBound},
    };
}

void ChronosBridge::setAarsTuning(const QString& field, const QVariant& value) {
    AarsParams* p = &m_aarsParams;
    const double d = value.toDouble();
    const int i = std::max(1, value.toInt());
    if (field == QStringLiteral("priorityWeight")) p->priorityWeight = d;
    else if (field == QStringLiteral("agingDivisor")) p->agingDivisor = std::max(0.0, d);
    else if (field == QStringLiteral("agingCap")) p->agingCap = std::max(0.0, d);
    else if (field == QStringLiteral("ioBoundBonus")) p->ioBoundBonus = d;
    else if (field == QStringLiteral("interactiveBonus")) p->interactiveBonus = d;
    else if (field == QStringLiteral("responseBonus")) p->responseBonus = d;
    else if (field == QStringLiteral("burstPenaltyDivisor")) p->burstPenaltyDivisor = std::max(0.0, d);
    else if (field == QStringLiteral("burstPenaltyCap")) p->burstPenaltyCap = std::max(0.0, d);
    else if (field == QStringLiteral("quantumCpuBound")) p->quantumCpuBound = i;
    else if (field == QStringLiteral("quantumBalanced")) p->quantumBalanced = i;
    else if (field == QStringLiteral("quantumInteractive")) p->quantumInteractive = i;
    else if (field == QStringLiteral("quantumIoBound")) p->quantumIoBound = i;
    else return;
    emit tuningChanged();
}

// Back to the PRD §6.2 / §6.4 starting values — an untuned AARS again.
void ChronosBridge::resetAarsTuning() {
    m_aarsParams = AarsParams{};
    emit tuningChanged();
}

// --- Custom workload --------------------------------------------------------

void ChronosBridge::setUseCustomWorkload(bool on) {
    if (m_useCustomWorkload == on) return;
    m_useCustomWorkload = on;
    emit customWorkloadChanged();
}

int ChronosBridge::customProcessTotal() const {
    int n = 0;
    for (const auto& g : m_customSpec.groups) n += g.count;
    return n;
}

QVariantMap ChronosBridge::customSpec() const {
    QVariantList groups;
    for (const auto& g : m_customSpec.groups) {
        groups.push_back(QVariantMap{
            {QStringLiteral("kind"), QString::fromStdString(processKindToString(g.kind))},
            {QStringLiteral("count"), g.count},
            {QStringLiteral("burstMin"), g.burstMin},
            {QStringLiteral("burstMax"), g.burstMax},
            {QStringLiteral("priorityMin"), g.priorityMin},
            {QStringLiteral("priorityMax"), g.priorityMax},
        });
    }
    return {
        {QStringLiteral("name"), QString::fromStdString(m_customSpec.name)},
        {QStringLiteral("quantum"), m_customSpec.quantum},
        {QStringLiteral("seed"), static_cast<int>(m_customSpec.seed)},
        {QStringLiteral("arrival"), QString::fromStdString(arrivalPatternToString(m_customSpec.arrival))},
        {QStringLiteral("spacing"), m_customSpec.spacing},
        {QStringLiteral("groups"), groups},
        {QStringLiteral("total"), customProcessTotal()},
        {QStringLiteral("maxTotal"), kMaxCustomProcesses},
        {QStringLiteral("maxGroups"), kMaxCustomGroups},
    };
}

// Everything the workload card shows for the generated workload. The stats
// come from the *generated processes* through WorkloadListModel::summarize —
// the same arithmetic a preset file gets — and the description is assembled
// from the spec itself, so the card can never claim something the run won't do.
QVariantMap ChronosBridge::customSummary() const {
    const Workload w = generateWorkload(m_customSpec);
    const std::vector<ProcessKind> kinds = generatedKinds(m_customSpec);

    QVector<WorkloadListModel::ProcSpec> specs;
    for (const auto& p : w.processes) specs.push_back({p.arrivalTime, p.burstTime, p.basePriority});
    QVariantMap out = WorkloadListModel::summarize(specs, w.quantum);
    out[QStringLiteral("schedulerNote")] = WorkloadListModel::schedulerNote(w);

    // Composition, in a fixed kind order.
    const ProcessKind order[] = {ProcessKind::CPU_BOUND, ProcessKind::BALANCED, ProcessKind::INTERACTIVE};
    QVariantList composition;
    QStringList parts;
    for (ProcessKind k : order) {
        int n = 0;
        for (ProcessKind x : kinds) if (x == k) ++n;
        if (n == 0) continue;
        const QString label = QString::fromStdString(processKindToString(k));
        composition.push_back(QVariantMap{{QStringLiteral("kind"), label},
                                          {QStringLiteral("count"), n}});
        parts << QStringLiteral("%1 %2").arg(n).arg(label.toLower());
    }
    out[QStringLiteral("composition")] = composition;

    QString arrivals;
    switch (m_customSpec.arrival) {
        case ArrivalPattern::ALL_AT_ONCE: arrivals = QStringLiteral("all arriving at tick 0"); break;
        case ArrivalPattern::STAGGERED:
            arrivals = QStringLiteral("arriving one at a time, 0-%1 ticks apart").arg(m_customSpec.spacing * 2);
            break;
        case ArrivalPattern::CLUSTERED:
            arrivals = QStringLiteral("arriving in batches of 4, every %1 ticks").arg(m_customSpec.spacing);
            break;
    }
    const int n = static_cast<int>(w.processes.size());
    out[QStringLiteral("description")] =
        n == 0 ? QStringLiteral("No processes yet - add a group on the left.")
               : QStringLiteral("%1 process%2 (%3), %4.")
                     .arg(n)
                     .arg(n == 1 ? QString() : QStringLiteral("es"))
                     .arg(parts.join(QStringLiteral(", ")))
                     .arg(arrivals);
    out[QStringLiteral("name")] = QString::fromStdString(m_customSpec.name);

    QVariantList procs;
    for (size_t i = 0; i < w.processes.size(); ++i) {
        const auto& p = w.processes[i];
        procs.push_back(QVariantMap{
            {QStringLiteral("pid"), p.pid},
            {QStringLiteral("kind"), QString::fromStdString(processKindToString(kinds[i]))},
            {QStringLiteral("arrival"), p.arrivalTime},
            {QStringLiteral("burst"), p.burstTime},
            {QStringLiteral("priority"), p.basePriority},
        });
    }
    out[QStringLiteral("processes")] = procs;
    return out;
}

void ChronosBridge::setCustomField(const QString& field, const QVariant& value) {
    if (field == QStringLiteral("name")) {
        const QString name = value.toString().trimmed();
        m_customSpec.name = (name.isEmpty() ? QStringLiteral("Custom Workload") : name).toStdString();
    } else if (field == QStringLiteral("quantum")) {
        m_customSpec.quantum = std::clamp(value.toInt(), 1, 20);
    } else if (field == QStringLiteral("seed")) {
        m_customSpec.seed = static_cast<std::uint32_t>(std::max(0, value.toInt()));
    } else if (field == QStringLiteral("arrival")) {
        m_customSpec.arrival = arrivalFromKey(value.toString());
    } else if (field == QStringLiteral("spacing")) {
        m_customSpec.spacing = std::clamp(value.toInt(), 0, 30);
    } else {
        return;
    }
    emit customWorkloadChanged();
}

void ChronosBridge::setGroupField(int index, const QString& field, const QVariant& value) {
    if (index < 0 || index >= static_cast<int>(m_customSpec.groups.size())) return;
    ProcessGroup& g = m_customSpec.groups[static_cast<size_t>(index)];
    if (field == QStringLiteral("kind")) {
        g = defaultGroup(kindFromKey(value.toString()), g.count);
    } else if (field == QStringLiteral("count")) {
        // The total is capped, so a group can only grow into what is left.
        const int others = customProcessTotal() - g.count;
        g.count = std::clamp(value.toInt(), 0, std::max(0, kMaxCustomProcesses - others));
    } else if (field == QStringLiteral("burstMin")) {
        g.burstMin = std::clamp(value.toInt(), 1, 60);
        g.burstMax = std::max(g.burstMax, g.burstMin);
    } else if (field == QStringLiteral("burstMax")) {
        g.burstMax = std::clamp(value.toInt(), 1, 60);
        g.burstMin = std::min(g.burstMin, g.burstMax);
    } else if (field == QStringLiteral("priorityMin")) {
        g.priorityMin = std::clamp(value.toInt(), 1, 10);
        g.priorityMax = std::max(g.priorityMax, g.priorityMin);
    } else if (field == QStringLiteral("priorityMax")) {
        g.priorityMax = std::clamp(value.toInt(), 1, 10);
        g.priorityMin = std::min(g.priorityMin, g.priorityMax);
    } else {
        return;
    }
    emit customWorkloadChanged();
}

void ChronosBridge::addGroup(const QString& kind) {
    if (static_cast<int>(m_customSpec.groups.size()) >= kMaxCustomGroups) return;
    const int room = kMaxCustomProcesses - customProcessTotal();
    m_customSpec.groups.push_back(defaultGroup(kindFromKey(kind), std::clamp(room, 0, 3)));
    emit customWorkloadChanged();
}

void ChronosBridge::removeGroup(int index) {
    if (index < 0 || index >= static_cast<int>(m_customSpec.groups.size())) return;
    m_customSpec.groups.erase(m_customSpec.groups.begin() + index);
    emit customWorkloadChanged();
}

void ChronosBridge::rerollSeed() {
    // An LCG step rather than wall-clock randomness: rerolling is still
    // reproducible from the seed it lands on, which the editor displays.
    m_customSpec.seed = (m_customSpec.seed * 1103515245u + 12345u) % 100000u;
    emit customWorkloadChanged();
}

// --- Selection ---------------------------------------------------------------

QStringList ChronosBridge::algorithmKeys() const { return kAlgorithmKeys; }
QStringList ChronosBridge::algorithmLabels() const { return kAlgorithmLabels; }
QStringList ChronosBridge::algorithmDescriptions() const { return kAlgorithmDescriptions; }
int ChronosBridge::osSectionStart() const { return kOsSectionStart; }

QString ChronosBridge::algorithmLabel(const QString& key) const {
    const int i = kAlgorithmKeys.indexOf(key);
    return i >= 0 ? kAlgorithmLabels.at(i) : key;
}

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

void ChronosBridge::setCompareMode(bool on) {
    if (m_compareMode == on) return;
    m_compareMode = on;
    emit compareSelectionChanged();
}

void ChronosBridge::setCompareKeyA(const QString& key) {
    if (m_compareKeyA == key) return;
    m_compareKeyA = key;
    emit compareSelectionChanged();
}

void ChronosBridge::setCompareKeyB(const QString& key) {
    if (m_compareKeyB == key) return;
    m_compareKeyB = key;
    emit compareSelectionChanged();
}

void ChronosBridge::toggleCompareKey(const QString& key) {
    if (!kAlgorithmKeys.contains(key)) return;
    if (m_compareKeyA == key) {
        m_compareKeyA = m_compareKeyB;  // B moves up, so A is always filled first
        m_compareKeyB.clear();
    } else if (m_compareKeyB == key) {
        m_compareKeyB.clear();
    } else if (m_compareKeyA.isEmpty()) {
        m_compareKeyA = key;
    } else {
        m_compareKeyB = key;  // replaces any previous B
    }
    emit compareSelectionChanged();
}

// --- Runs ---------------------------------------------------------------------

Workload ChronosBridge::buildSelectedWorkload() const {
    Workload w = m_useCustomWorkload ? generateWorkload(m_customSpec)
                                     : loadWorkload(m_selectedWorkloadPath.toStdString());
    if (w.processes.empty()) throw std::runtime_error("the workload has no processes");
    return w;
}

ChronosBridge::Run ChronosBridge::makeRun(const std::string& key, const Workload& workload,
                                          const AarsParams& params) {
    Run run;
    run.key = key;
    run.workload = workload;
    run.aars = params;
    auto scheduler = makeScheduler(key, workload, params);
    // scheduler->name(), not algorithmDisplayName(): a tuned AARS run must
    // say so ("AARS (tuned)") everywhere its result is shown.
    run.result = ::runSimulation(workload, *scheduler, scheduler->name());

    std::map<int, int> priorityOf;
    for (const Process& p : workload.processes) priorityOf[p.pid] = p.basePriority;
    for (const auto& p : run.result.processStats) {
        ProcessMeta meta;
        meta.turnaroundTime = p.turnaroundTime;
        meta.waitingTimeFinal = p.waitingTime;
        meta.responseTime = p.responseTime;
        meta.completionTime = p.completionTime;
        // Read directly rather than back-derived: ProcessStat carries
        // arrivalTime/burstTime (PRD §5.3), and the old
        // `burst = turnaround - waiting` identity silently breaks the moment
        // any I/O wait time enters the model.
        meta.burstTime = p.burstTime;
        meta.arrivalTime = p.arrivalTime;
        meta.contextSwitches = p.contextSwitches;
        meta.nice = p.nice;
        meta.basePriority = priorityOf.count(p.pid) ? priorityOf[p.pid] : 5;
        meta.predictedClass = QString::fromStdString(processClassToString(p.predictedClass));
        run.meta[p.pid] = meta;
    }
    return run;
}

bool ChronosBridge::runSelectedSimulation() {
    m_errorMessage.clear();
    try {
        m_run = makeRun(m_selectedAlgorithm.toStdString(), buildSelectedWorkload(), m_aarsParams);
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

int ChronosBridge::runMaxTick(const Run& run) {
    int m = 0;
    for (const auto& g : run.result.gantt) m = std::max(m, g.end);
    for (const auto& p : run.result.processStats) m = std::max(m, p.completionTime);
    return m;
}

int ChronosBridge::maxTick() const { return runMaxTick(m_run); }
QString ChronosBridge::resultAlgorithmName() const { return QString::fromStdString(m_run.result.algorithm); }
QString ChronosBridge::resultWorkloadName() const { return QString::fromStdString(m_run.result.workloadName); }
int ChronosBridge::processCount() const { return static_cast<int>(m_run.result.processStats.size()); }

QString ChronosBridge::scoreColumnLabel() const {
    if (m_run.key == "aars") return QStringLiteral("SCORE");
    if (m_run.key == "mlfq") return QStringLiteral("QUEUE");
    if (m_run.key == "cfs") return QStringLiteral("VRUN");
    return QString();
}

QString ChronosBridge::priorityColumnLabel() const {
    return m_run.key == "cfs" ? QStringLiteral("NICE") : QStringLiteral("PRI");
}

QString ChronosBridge::processColor(int pid) const {
    const int n = kProcessShades.size();
    return kProcessShades.at(((pid % n) + n) % n);
}

int ChronosBridge::processSlot(int pid) const {
    const int n = kProcessShades.size();
    return ((pid % n) + n) % n;
}

// --- Per-tick derivations -------------------------------------------------------

int ChronosBridge::ticksRunUpTo(const Run& run, int pid, int tick) {
    int sum = 0;
    for (const auto& g : run.result.gantt) {
        if (g.pid != pid) continue;
        sum += std::max(0, std::min(g.end, tick) - g.start);
    }
    return sum;
}

const DecisionLog* ChronosBridge::lastDecisionAt(const Run& run, int tick) {
    const DecisionLog* found = nullptr;
    for (const auto& d : run.result.decisionLog) {
        if (d.tick <= tick) found = &d;
        else break;
    }
    return found;
}

const GanttEntry* ChronosBridge::runningSegmentAt(const Run& run, int tick) {
    for (const auto& g : run.result.gantt) {
        if (tick >= g.start && tick < g.end) return &g;
    }
    return nullptr;
}

// Mirrors the engine's own count: a switch is a dispatch to a different PID
// than the last one dispatched. Idle ticks log a decision with chosen == -1;
// those are not dispatches, so they neither count nor reset the comparison.
int ChronosBridge::switchesUpTo(const Run& run, int tick) {
    int switches = 0;
    int last = -1;
    for (const auto& d : run.result.decisionLog) {
        if (d.tick > tick) break;
        if (d.chosen == -1) continue;
        if (last != -1 && d.chosen != last) ++switches;
        last = d.chosen;
    }
    return switches;
}

int ChronosBridge::cpuUtilizationAt(int tick) const {
    if (tick <= 0) return 0;
    int busy = 0;
    for (const auto& g : m_run.result.gantt) {
        busy += std::max(0, std::min(g.end, tick) - std::min(g.start, tick));
    }
    return static_cast<int>(std::lround(100.0 * busy / tick));
}

int ChronosBridge::contextSwitchesAt(int tick) const { return switchesUpTo(m_run, tick); }

QVariantList ChronosBridge::segmentsOf(const Run& run) const {
    QVariantList out;
    for (const auto& g : run.result.gantt) {
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

QVariantList ChronosBridge::ganttSegments() const { return segmentsOf(m_run); }

QVariantList ChronosBridge::readyQueueAt(int tick) const {
    QVariantList out;
    const DecisionLog* decision = lastDecisionAt(m_run, tick);
    if (!decision) return out;

    const GanttEntry* runningSeg = runningSegmentAt(m_run, tick);
    const int runningPid = runningSeg ? runningSeg->pid : -1;
    const std::string& key = m_run.key;

    struct Row {
        int pid;
        double score;
        bool scored;   // false: arrived after the last decision, not yet scored
        int arrival;
        int burstRemaining;
        int wait;
        QString cls;
        bool isRunning;
    };
    std::vector<Row> scored, late;
    std::vector<int> seen;

    auto live = [&](int pid, int& remaining, int& wait) -> bool {
        auto it = m_run.meta.find(pid);
        if (it == m_run.meta.end()) return false;
        const ProcessMeta& meta = it->second;
        if (meta.arrivalTime > tick || meta.completionTime <= tick) return false;
        const int ran = ticksRunUpTo(m_run, pid, tick);
        remaining = meta.burstTime - ran;
        wait = std::max(0, tick - meta.arrivalTime - ran);
        return true;
    };

    for (const auto& c : decision->candidates) {
        int remaining = 0, wait = 0;
        seen.push_back(c.pid);
        if (!live(c.pid, remaining, wait)) continue;
        scored.push_back(Row{c.pid, c.score, true, m_run.meta.at(c.pid).arrivalTime, remaining, wait,
                             QString::fromStdString(c.predictedClass), c.pid == runningPid});
    }

    // Processes that arrived after the last decision. Under the non-preemptive
    // algorithms that decision can be many ticks old, and without these rows
    // the table would claim nobody new is waiting.
    for (const auto& [pid, meta] : m_run.meta) {
        if (std::find(seen.begin(), seen.end(), pid) != seen.end() || pid == runningPid) continue;
        int remaining = 0, wait = 0;
        if (!live(pid, remaining, wait)) continue;
        late.push_back(Row{pid, 0.0, false, meta.arrivalTime, remaining, wait,
                           QStringLiteral("UNKNOWN"), false});
    }

    // Each algorithm's own pick order, so the top row is who it would run next.
    // FCFS/SJF/RR/Priority/AARS log scores where higher = sooner (see each
    // scheduler); MLFQ logs the queue level and CFS the vruntime, lower = sooner.
    if (key == "mlfq" || key == "cfs") {
        std::stable_sort(scored.begin(), scored.end(), [&](const Row& a, const Row& b) {
            if (a.score != b.score) return a.score < b.score;
            return key == "cfs" ? a.pid < b.pid : false;  // MLFQ: keep FIFO order within a queue
        });
    } else {
        std::stable_sort(scored.begin(), scored.end(), [](const Row& a, const Row& b) {
            if (a.score != b.score) return a.score > b.score;
            return a.pid < b.pid;
        });
    }
    std::sort(late.begin(), late.end(), [](const Row& a, const Row& b) {
        if (a.arrival != b.arrival) return a.arrival < b.arrival;
        return a.pid < b.pid;
    });

    auto emitRow = [&](const Row& r) {
        const ProcessMeta& meta = m_run.meta.at(r.pid);
        QVariantMap m;
        m["pid"] = r.pid;
        m["priText"] = key == "cfs" ? signedInt(meta.nice) : QString::number(meta.basePriority);
        m["burstRemaining"] = r.burstRemaining;
        m["wait"] = r.wait;
        QString scoreText = QStringLiteral("—");
        if (r.scored) {
            if (key == "mlfq") scoreText = QStringLiteral("Q%1").arg(static_cast<int>(r.score));
            else scoreText = QString::number(r.score, 'f', 1);
        }
        m["scoreText"] = scoreText;
        m["scored"] = r.scored;
        // UNKNOWN reads as an error state to anyone who has not read the
        // classifier. It only ever means "this process has not run yet" —
        // PENDING says exactly that.
        m["cls"] = (r.cls == QStringLiteral("UNKNOWN")) ? QStringLiteral("PENDING") : r.cls;
        m["isRunning"] = r.isRunning;
        m["slot"] = processSlot(r.pid);
        m["color"] = processColor(r.pid);
        out.push_back(m);
    };
    for (const Row& r : scored) emitRow(r);
    for (const Row& r : late) emitRow(r);
    return out;
}

QVariantMap ChronosBridge::whyPanelAt(int tick) const { return whyPanelOf(m_run, tick); }

QVariantMap ChronosBridge::whyPanelOf(const Run& run, int tick) const {
    QVariantMap out;
    const DecisionLog* decision = lastDecisionAt(run, tick);
    if (!decision) {
        out["hasDecision"] = false;
        out["idle"] = false;
        return out;
    }
    // The CPU sat idle: the scheduler was asked and nothing was ready. That
    // is a state to show, not a process called "P-1".
    if (decision->chosen == -1) {
        out["hasDecision"] = false;
        out["idle"] = true;
        return out;
    }
    out["hasDecision"] = true;
    out["idle"] = false;
    out["pid"] = decision->chosen;
    out["color"] = processColor(decision->chosen);

    double score = 0;
    for (const auto& c : decision->candidates) {
        if (c.pid == decision->chosen) { score = c.score; break; }
    }
    out["score"] = score;

    QString status;
    if (run.key == "aars") status = QStringLiteral("DECISION SCORE %1").arg(score, 0, 'f', 1);
    else if (run.key == "mlfq") status = QStringLiteral("RUNS FROM Q%1").arg(static_cast<int>(score));
    else if (run.key == "cfs") status = QStringLiteral("VRUNTIME %1").arg(score, 0, 'f', 1);
    else status = QStringLiteral("DECIDED AT TICK %1").arg(decision->tick);
    out["status"] = status;

    QVariantList reasons;
    std::vector<std::pair<QString, double>> positives, negatives;
    for (const auto& tagStd : decision->reasonTags) {
        const QVariantMap reason = describeTag(QString::fromStdString(tagStd), *decision);
        if (reason.value("signed").toBool()) {
            const QString label = reason.value("label").toString();
            const double mag = reason.value("magnitude").toDouble();
            if (reason.value("positive").toBool()) positives.push_back({label, mag});
            else negatives.push_back({label, mag});
        }
        reasons.push_back(reason);
    }
    out["reasons"] = reasons;

    // The score-breakdown bar (EDRD §7.1) is AARS's formula receipt; other
    // algorithms have no additive score to break down.
    QVariantList segments;
    if (run.key == "aars") {
        double totalAbs = 0;
        for (const auto& p : positives) totalAbs += p.second;
        for (const auto& n : negatives) totalAbs += n.second;
        if (totalAbs <= 0) totalAbs = 1;
        for (const auto& p : positives) {
            segments.push_back(QVariantMap{{"label", p.first}, {"pct", (p.second / totalAbs) * 100.0},
                                           {"positive", true}});
        }
        for (const auto& n : negatives) {
            segments.push_back(QVariantMap{{"label", n.first}, {"pct", (n.second / totalAbs) * 100.0},
                                           {"positive", false}});
        }
    }
    out["scoreSegments"] = segments;
    return out;
}

QVariantMap ChronosBridge::agingAt(int tick) const {
    QVariantMap out;
    const std::string& key = m_run.key;

    // How each algorithm turns waiting into a better chance of running.
    bool hasBonus = false;
    QString title = QStringLiteral("WAITING");
    QString status;
    if (key == "aars") {
        const AarsParams& k = m_run.aars;
        hasBonus = k.agingDivisor > 0 && k.agingCap > 0;
        title = QStringLiteral("AGING");
        status = hasBonus ? QStringLiteral("BONUS = MIN(WAIT ÷ %1, %2)")
                                .arg(k.agingDivisor, 0, 'g', 3).arg(k.agingCap, 0, 'g', 3)
                          : QStringLiteral("AGING SWITCHED OFF IN THE TUNER");
    } else if (key == "priority") {
        hasBonus = true;
        title = QStringLiteral("AGING");
        status = QStringLiteral("+1 PRIORITY PER 5 TICKS WAITED");
    } else if (key == "mlfq") {
        const int s = resolveMlfq(m_run.workload.mlfq, m_run.workload.quantum).boostInterval;
        title = QStringLiteral("AGING");
        status = QStringLiteral("NO BONUS · BOOST TO Q0 EVERY %1 · NEXT @ %2").arg(s).arg((tick / s + 1) * s);
    } else if (key == "cfs") {
        status = QStringLiteral("NO AGING · LOWEST VRUNTIME RUNS NEXT");
    } else {
        status = QStringLiteral("NO AGING TERM IN %1").arg(resultAlgorithmName().toUpper());
    }

    const GanttEntry* runningSeg = runningSegmentAt(m_run, tick);
    const int runningPid = runningSeg ? runningSeg->pid : -1;

    struct Entry { int pid; int wait; double bonus; bool warn; };
    std::vector<Entry> entries;
    for (const auto& [pid, meta] : m_run.meta) {
        if (pid == runningPid || meta.arrivalTime > tick || meta.completionTime <= tick) continue;
        const int wait = std::max(0, tick - meta.arrivalTime - ticksRunUpTo(m_run, pid, tick));
        if (wait <= 0) continue;

        double bonus = 0.0;
        bool warn = false;
        if (key == "aars" && hasBonus) {
            bonus = std::min(wait / m_run.aars.agingDivisor, m_run.aars.agingCap);
            warn = bonus >= 0.8 * m_run.aars.agingCap;
        } else if (key == "priority") {
            bonus = wait / 5;
            warn = bonus >= 4;
        } else {
            warn = wait >= 30;  // no rescue mechanism: a long wait is the warning
        }
        if (hasBonus && bonus <= 0) continue;
        entries.push_back(Entry{pid, wait, bonus, warn});
    }
    std::sort(entries.begin(), entries.end(), [](const Entry& a, const Entry& b) {
        if (a.wait != b.wait) return a.wait > b.wait;
        return a.pid < b.pid;
    });

    QVariantList list;
    for (const Entry& e : entries) {
        list.push_back(QVariantMap{{"pid", e.pid}, {"waitSoFar", e.wait}, {"bonus", e.bonus},
                                   {"aboveThreshold", e.warn}});
    }
    out["title"] = title;
    out["status"] = status;
    out["hasBonus"] = hasBonus;
    out["entries"] = list;
    return out;
}

QVariantMap ChronosBridge::tickerRow(const Run& run, int tick, const ProcessStat& p) {
    auto it = run.meta.find(p.pid);
    if (it == run.meta.end()) return QVariantMap();
    const ProcessMeta& meta = it->second;

    const int ranSoFar = std::min(meta.burstTime, ticksRunUpTo(run, p.pid, tick));
    const bool done = tick >= meta.completionTime;
    const double pct = meta.burstTime > 0 ? (100.0 * ranSoFar / meta.burstTime) : 100.0;
    const GanttEntry* seg = runningSegmentAt(run, tick);
    const bool running = seg && seg->pid == p.pid;

    QVariantMap m2;
    m2["pid"] = p.pid;
    m2["progressPct"] = pct;
    m2["done"] = done;
    m2["arrived"] = tick >= meta.arrivalTime;
    // Everything below feeds the hover HUD (EDRD §5.10). Computed here
    // rather than in QML so the panel stays a view over derived data.
    m2["running"] = running;
    m2["ranSoFar"] = ranSoFar;
    m2["burstTime"] = meta.burstTime;
    m2["remaining"] = std::max(0, meta.burstTime - ranSoFar);
    m2["arrivalTime"] = meta.arrivalTime;
    m2["completionTime"] = meta.completionTime;
    m2["waitingTime"] = meta.waitingTimeFinal;
    m2["turnaroundTime"] = meta.turnaroundTime;
    m2["responseTime"] = meta.responseTime;
    m2["contextSwitches"] = meta.contextSwitches;
    m2["priority"] = meta.basePriority;
    m2["nice"] = signedInt(meta.nice);
    m2["weight"] = cfsWeight(meta.nice);
    // A process that has not run yet has not been classified yet, whatever
    // its final class turns out to be — showing that early would be reading
    // the end of the run. PENDING says so in a word a viewer can act on.
    m2["cls"] = (ranSoFar == 0 || meta.predictedClass == QStringLiteral("UNKNOWN"))
                    ? QStringLiteral("PENDING") : meta.predictedClass;
    m2["state"] = done ? QStringLiteral("DONE")
                       : (tick < meta.arrivalTime ? QStringLiteral("NOT ARRIVED")
                                                  : (running ? QStringLiteral("RUNNING")
                                                             : QStringLiteral("READY")));
    return m2;
}

QVariantList ChronosBridge::processTickerAt(int tick) const {
    QVariantList out;
    for (const auto& p : m_run.result.processStats) {
        QVariantMap row = tickerRow(m_run, tick, p);
        if (!row.isEmpty()) out.push_back(row);
    }
    return out;
}

QVariantMap ChronosBridge::processTickerRowAt(int tick, int index) const {
    const auto& stats = m_run.result.processStats;
    if (index < 0 || index >= static_cast<int>(stats.size())) return QVariantMap();
    return tickerRow(m_run, tick, stats[static_cast<size_t>(index)]);
}

// --- Compare ------------------------------------------------------------------

bool ChronosBridge::runComparison() {
    m_errorMessage.clear();
    try {
        if (m_compareKeyA.isEmpty() || m_compareKeyB.isEmpty()) {
            throw std::runtime_error("pick two algorithms to compare");
        }
        if (m_compareKeyA == m_compareKeyB) throw std::runtime_error("pick two different algorithms");

        // One workload, built once: both runs see exactly the same processes,
        // including a custom one (generation is seeded, but building it once
        // makes "the same processes" true by construction, not by argument).
        const Workload workload = buildSelectedWorkload();
        m_cmp[0] = makeRun(m_compareKeyA.toStdString(), workload, m_aarsParams);
        m_cmp[1] = makeRun(m_compareKeyB.toStdString(), workload, m_aarsParams);

        const Comparison c = compareRuns(m_cmp[0].result, m_cmp[1].result);
        auto fmt = [](double v, int dec) { return QString::number(v, 'f', dec); };

        QVariantList rows, betterA, betterB, tied;
        for (const MetricRow& r : c.rows) {
            const QString label = QString::fromStdString(r.spec.label);
            QString delta;
            if (r.winner != -1) {
                const double loserV = r.winner == 0 ? r.b : r.a;
                const double diff = std::abs(r.a - r.b);
                delta = QStringLiteral("%1 by %2")
                            .arg(r.winner == 0 ? QStringLiteral("A") : QStringLiteral("B"),
                                 fmt(diff, r.spec.decimals));
                if (std::abs(loserV) > 1e-9) {
                    delta += QStringLiteral(" (%1%)").arg(fmt(100.0 * diff / std::abs(loserV), 0));
                }
            }
            rows.push_back(QVariantMap{
                {"key", QString::fromStdString(r.spec.key)},
                {"label", label},
                {"unit", QString::fromStdString(r.spec.unit)},
                {"meaning", QString::fromStdString(r.spec.meaning)},
                {"lowerIsBetter", r.spec.lowerIsBetter},
                {"a", fmt(r.a, r.spec.decimals)},
                {"b", fmt(r.b, r.spec.decimals)},
                {"winner", r.winner},
                {"delta", delta},
            });
            if (r.winner == 0) betterA.push_back(label);
            else if (r.winner == 1) betterB.push_back(label);
            else tied.push_back(label);
        }
        m_comparison = QVariantMap{
            {"nameA", QString::fromStdString(c.nameA)},
            {"nameB", QString::fromStdString(c.nameB)},
            {"keyA", m_compareKeyA},
            {"keyB", m_compareKeyB},
            {"workload", QString::fromStdString(c.workloadName)},
            {"rows", rows},
            {"winsA", c.winsA},
            {"winsB", c.winsB},
            {"ties", c.ties},
            {"total", static_cast<int>(c.rows.size())},
            {"betterA", betterA},
            {"betterB", betterB},
            {"tied", tied},
        };
        m_hasComparison = true;
        emit comparisonChanged();
        return true;
    } catch (const std::exception& e) {
        m_errorMessage = QString::fromStdString(e.what());
        m_hasComparison = false;
        emit errorChanged();
        emit comparisonChanged();
        return false;
    }
}

int ChronosBridge::cmpMaxTick() const { return std::max(runMaxTick(m_cmp[0]), runMaxTick(m_cmp[1])); }
int ChronosBridge::cmpProcessCount() const { return static_cast<int>(m_cmp[0].result.processStats.size()); }
QString ChronosBridge::cmpWorkloadName() const { return QString::fromStdString(m_cmp[0].result.workloadName); }

QString ChronosBridge::cmpAlgorithmName(int side) const {
    if (side < 0 || side > 1) return QString();
    return QString::fromStdString(m_cmp[side].result.algorithm);
}

QVariantList ChronosBridge::cmpGanttSegments(int side) const {
    if (side < 0 || side > 1) return {};
    return segmentsOf(m_cmp[side]);
}

QVariantMap ChronosBridge::cmpTickerRowAt(int tick, int index) const {
    const auto& statsA = m_cmp[0].result.processStats;
    const auto& statsB = m_cmp[1].result.processStats;
    if (index < 0 || index >= static_cast<int>(statsA.size())) return QVariantMap();
    const ProcessStat& pa = statsA[static_cast<size_t>(index)];
    // Both runs saw the same processes and sort stats by pid, so the index
    // lines up; looked up by pid anyway so that is never an assumption.
    auto itB = std::find_if(statsB.begin(), statsB.end(), [&](const ProcessStat& s) { return s.pid == pa.pid; });
    if (itB == statsB.end()) return QVariantMap();

    const QVariantMap a = tickerRow(m_cmp[0], tick, pa);
    const QVariantMap b = tickerRow(m_cmp[1], tick, *itB);
    return QVariantMap{
        {"pid", pa.pid},
        {"arrived", a.value("arrived")},
        {"aPct", a.value("progressPct")},
        {"aDone", a.value("done")},
        {"aRunning", a.value("running")},
        {"aFinish", a.value("completionTime")},
        {"bPct", b.value("progressPct")},
        {"bDone", b.value("done")},
        {"bRunning", b.value("running")},
        {"bFinish", b.value("completionTime")},
    };
}

QVariantMap ChronosBridge::cmpWhyPanelAt(int side, int tick) const {
    if (side < 0 || side > 1) return QVariantMap();
    return whyPanelOf(m_cmp[side], tick);
}

int ChronosBridge::cmpDoneAt(int side, int tick) const {
    if (side < 0 || side > 1) return 0;
    int n = 0;
    for (const auto& p : m_cmp[side].result.processStats) {
        if (p.completionTime <= tick) ++n;
    }
    return n;
}

int ChronosBridge::cmpSwitchesAt(int side, int tick) const {
    if (side < 0 || side > 1) return 0;
    return switchesUpTo(m_cmp[side], tick);
}
