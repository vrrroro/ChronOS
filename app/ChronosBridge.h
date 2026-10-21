#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <map>
#include <string>

#include "simulator.h"
#include "schedulers/aars.h"
#include "workload_gen.h"
#include "WorkloadListModel.h"

// Owns the current SimulationResult(s) in-process (no JSON round-trip for the
// GUI's interactive use — AGENTS.md's "in-process library link" decision).
// Every *At(tick) method is a pure function of (run, tick), ported 1:1 from
// the old web dashboard's derivation helpers (ticksRunUpTo/lastDecisionAt/
// runningSegmentAt/estimateAgingBonus/buildProcessMeta) so the tick-scrubbing
// math isn't reinvented, just moved to C++.
//
// Two kinds of run live here: the single run the Dashboard replays, and —
// since 2026-10-22 — a pair of runs over the same processes for the compare
// screen (cmp* methods, side 0 = A, side 1 = B).
class ChronosBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList algorithmKeys READ algorithmKeys CONSTANT)
    Q_PROPERTY(QStringList algorithmLabels READ algorithmLabels CONSTANT)
    Q_PROPERTY(QStringList algorithmDescriptions READ algorithmDescriptions CONSTANT)
    // Index of the first algorithm in the picker's second section (the real
    // operating-system schedulers, MLFQ and CFS). Everything before it is the
    // classic + adaptive set.
    Q_PROPERTY(int osSectionStart READ osSectionStart CONSTANT)
    // Per-algorithm "about" card: tagline, characteristics, strengths, weaknesses.
    Q_PROPERTY(QVariantList algorithmAbout READ algorithmAbout CONSTANT)
    // AARS's tunable weights (AarsParams) as a QVariantMap keyed by the
    // struct's field names. Edited via setAarsTuning()/resetAarsTuning().
    Q_PROPERTY(QVariantMap aarsTuning READ aarsTuning NOTIFY tuningChanged)
    Q_PROPERTY(bool aarsTuned READ aarsTuned NOTIFY tuningChanged)
    // Custom workload builder: the spec being edited, and everything the
    // workload card needs to describe what it generates (stats computed from
    // the generated processes, never authored).
    Q_PROPERTY(bool useCustomWorkload READ useCustomWorkload WRITE setUseCustomWorkload NOTIFY customWorkloadChanged)
    Q_PROPERTY(QVariantMap customSpec READ customSpec NOTIFY customWorkloadChanged)
    Q_PROPERTY(QVariantMap customSummary READ customSummary NOTIFY customWorkloadChanged)
    Q_PROPERTY(WorkloadListModel* workloadModel READ workloadModel CONSTANT)
    Q_PROPERTY(QString selectedAlgorithm READ selectedAlgorithm WRITE setSelectedAlgorithm NOTIFY selectedAlgorithmChanged)
    Q_PROPERTY(QString selectedWorkloadPath READ selectedWorkloadPath WRITE setSelectedWorkloadPath NOTIFY selectedWorkloadPathChanged)
    // Compare mode (2026-10-22): two algorithms, one workload.
    Q_PROPERTY(bool compareMode READ compareMode WRITE setCompareMode NOTIFY compareSelectionChanged)
    Q_PROPERTY(QString compareKeyA READ compareKeyA WRITE setCompareKeyA NOTIFY compareSelectionChanged)
    Q_PROPERTY(QString compareKeyB READ compareKeyB WRITE setCompareKeyB NOTIFY compareSelectionChanged)

    Q_PROPERTY(bool hasResult READ hasResult NOTIFY resultChanged)
    Q_PROPERTY(int maxTick READ maxTick NOTIFY resultChanged)
    Q_PROPERTY(QString resultKey READ resultKey NOTIFY resultChanged)
    Q_PROPERTY(QString resultAlgorithmName READ resultAlgorithmName NOTIFY resultChanged)
    Q_PROPERTY(QString resultWorkloadName READ resultWorkloadName NOTIFY resultChanged)
    Q_PROPERTY(bool isAars READ isAars NOTIFY resultChanged)
    Q_PROPERTY(int processCount READ processCount NOTIFY resultChanged)
    // Ready-queue column headers that depend on the algorithm: the SCORE
    // column is AARS's score, MLFQ's queue, CFS's vruntime, or absent; the
    // priority column shows nice under CFS, since that is what CFS weighs.
    Q_PROPERTY(QString scoreColumnLabel READ scoreColumnLabel NOTIFY resultChanged)
    Q_PROPERTY(QString priorityColumnLabel READ priorityColumnLabel NOTIFY resultChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)

    Q_PROPERTY(bool hasComparison READ hasComparison NOTIFY comparisonChanged)
    Q_PROPERTY(int cmpMaxTick READ cmpMaxTick NOTIFY comparisonChanged)
    Q_PROPERTY(int cmpProcessCount READ cmpProcessCount NOTIFY comparisonChanged)
    Q_PROPERTY(QString cmpWorkloadName READ cmpWorkloadName NOTIFY comparisonChanged)
    Q_PROPERTY(QVariantMap comparison READ comparison NOTIFY comparisonChanged)

public:
    explicit ChronosBridge(QObject* parent = nullptr);

    QStringList algorithmKeys() const;
    QStringList algorithmLabels() const;
    QStringList algorithmDescriptions() const;
    int osSectionStart() const;
    QVariantList algorithmAbout() const;

    QVariantMap aarsTuning() const { return paramsToMap(m_aarsParams); }
    bool aarsTuned() const { return m_aarsParams != AarsParams{}; }
    Q_INVOKABLE void setAarsTuning(const QString& field, const QVariant& value);
    Q_INVOKABLE void resetAarsTuning();

    bool useCustomWorkload() const { return m_useCustomWorkload; }
    void setUseCustomWorkload(bool on);
    QVariantMap customSpec() const;
    QVariantMap customSummary() const;
    // field: name | quantum | seed | arrival | spacing
    Q_INVOKABLE void setCustomField(const QString& field, const QVariant& value);
    // field: count | burstMin | burstMax | priorityMin | priorityMax | kind
    // (changing kind resets that group's ranges to the kind's defaults)
    Q_INVOKABLE void setGroupField(int index, const QString& field, const QVariant& value);
    Q_INVOKABLE void addGroup(const QString& kind);
    Q_INVOKABLE void removeGroup(int index);
    Q_INVOKABLE void rerollSeed();
    WorkloadListModel* workloadModel() const { return m_workloadModel; }

    QString selectedAlgorithm() const { return m_selectedAlgorithm; }
    void setSelectedAlgorithm(const QString& algo);
    QString selectedWorkloadPath() const { return m_selectedWorkloadPath; }
    void setSelectedWorkloadPath(const QString& path);

    bool compareMode() const { return m_compareMode; }
    void setCompareMode(bool on);
    QString compareKeyA() const { return m_compareKeyA; }
    void setCompareKeyA(const QString& key);
    QString compareKeyB() const { return m_compareKeyB; }
    void setCompareKeyB(const QString& key);
    // Picker helper: assigns `key` to A, then B; picking a chosen key again
    // releases it.
    Q_INVOKABLE void toggleCompareKey(const QString& key);
    Q_INVOKABLE QString algorithmLabel(const QString& key) const;

    bool hasResult() const { return m_hasResult; }
    int maxTick() const;
    QString resultKey() const { return QString::fromStdString(m_run.key); }
    QString resultAlgorithmName() const;
    QString resultWorkloadName() const;
    bool isAars() const { return m_run.key == "aars"; }
    int processCount() const;
    QString scoreColumnLabel() const;
    QString priorityColumnLabel() const;
    QString errorMessage() const { return m_errorMessage; }

    // Named to avoid colliding with the free function runSimulation() from simulator.h.
    Q_INVOKABLE bool runSelectedSimulation();

    Q_INVOKABLE QVariantList ganttSegments() const;
    Q_INVOKABLE QVariantList readyQueueAt(int tick) const;
    Q_INVOKABLE QVariantMap whyPanelAt(int tick) const;
    // { title, status, hasBonus, entries: [{pid, waitSoFar, bonus, aboveThreshold}] }
    Q_INVOKABLE QVariantMap agingAt(int tick) const;
    Q_INVOKABLE QVariantList processTickerAt(int tick) const;
    // Same per-process row as processTickerAt(), but for one process at a
    // fixed vector index into the run's processStats. Exists so ProcessTicker's
    // ListView can bind its model to the stable process *count* (Q_PROPERTY
    // processCount, unchanging for the run) and have each delegate pull its
    // own row by index, instead of rebinding model to a fresh QVariantList
    // every tick — the latter has no stable identity for QML to diff against,
    // so ListView tears down and recreates every delegate every tick, which
    // kills every animation running on them.
    Q_INVOKABLE QVariantMap processTickerRowAt(int tick, int index) const;
    Q_INVOKABLE int cpuUtilizationAt(int tick) const;
    Q_INVOKABLE int contextSwitchesAt(int tick) const;
    Q_INVOKABLE QString processColor(int pid) const;
    Q_INVOKABLE int processSlot(int pid) const;

    // --- Compare (side 0 = A, side 1 = B) ---------------------------------
    Q_INVOKABLE bool runComparison();
    bool hasComparison() const { return m_hasComparison; }
    int cmpMaxTick() const;
    int cmpProcessCount() const;
    QString cmpWorkloadName() const;
    QVariantMap comparison() const { return m_comparison; }
    Q_INVOKABLE QString cmpAlgorithmName(int side) const;
    Q_INVOKABLE QVariantList cmpGanttSegments(int side) const;
    // { pid, arrived, aPct, aDone, aRunning, aFinish, bPct, bDone, bRunning, bFinish }
    Q_INVOKABLE QVariantMap cmpTickerRowAt(int tick, int index) const;
    // The dashboard's why-panel payload for one side of the comparison.
    Q_INVOKABLE QVariantMap cmpWhyPanelAt(int side, int tick) const;
    Q_INVOKABLE int cmpDoneAt(int side, int tick) const;
    Q_INVOKABLE int cmpSwitchesAt(int side, int tick) const;

signals:
    void selectedAlgorithmChanged();
    void selectedWorkloadPathChanged();
    void resultChanged();
    void errorChanged();
    void tuningChanged();
    void customWorkloadChanged();
    void compareSelectionChanged();
    void comparisonChanged();

private:
    struct ProcessMeta {
        int arrivalTime = 0;
        int burstTime = 0;
        int basePriority = 5;
        int nice = 0;
        int waitingTimeFinal = 0;
        int turnaroundTime = 0;
        int responseTime = 0;
        int completionTime = 0;
        int contextSwitches = 0;
        QString predictedClass;
    };

    // One simulated run and the per-process facts derived from it.
    struct Run {
        std::string key;
        SimulationResult result;
        std::map<int, ProcessMeta> meta;
        Workload workload;  // the processes and scheduler blocks it ran with
        AarsParams aars;    // the weights it ran with (for the aging panel)
    };

    static int ticksRunUpTo(const Run& run, int pid, int tick);
    static const DecisionLog* lastDecisionAt(const Run& run, int tick);
    static const GanttEntry* runningSegmentAt(const Run& run, int tick);
    static int switchesUpTo(const Run& run, int tick);
    static int runMaxTick(const Run& run);
    static Run makeRun(const std::string& key, const Workload& workload, const AarsParams& params);
    QVariantList segmentsOf(const Run& run) const;
    QVariantMap whyPanelOf(const Run& run, int tick) const;
    static QVariantMap tickerRow(const Run& run, int tick, const ProcessStat& p);
    Workload buildSelectedWorkload() const;
    static QVariantMap paramsToMap(const AarsParams& p);
    int customProcessTotal() const;

    WorkloadListModel* m_workloadModel;
    QString m_selectedAlgorithm;
    QString m_selectedWorkloadPath;
    QString m_errorMessage;
    bool m_hasResult = false;
    AarsParams m_aarsParams;
    bool m_useCustomWorkload = false;
    WorkloadSpec m_customSpec;
    Run m_run;

    bool m_compareMode = false;
    QString m_compareKeyA;
    QString m_compareKeyB;
    bool m_hasComparison = false;
    Run m_cmp[2];
    QVariantMap m_comparison;
};
