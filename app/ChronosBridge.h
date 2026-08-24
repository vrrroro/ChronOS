#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <map>

#include "simulator.h"
#include "WorkloadListModel.h"

// Owns the current SimulationResult in-process (no JSON round-trip for the
// GUI's interactive use — CLAUDE.md's "in-process library link" decision).
// Every *At(tick) method is a pure function of (m_result, tick), ported 1:1
// from dashboard/app.js's derivation helpers (ticksRunUpTo/lastDecisionAt/
// runningSegmentAt/estimateAgingBonus/processColor/buildProcessMeta) so the
// dashboard's tick-scrubbing math isn't reinvented, just moved to C++.
class ChronosBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList algorithmKeys READ algorithmKeys CONSTANT)
    Q_PROPERTY(QStringList algorithmLabels READ algorithmLabels CONSTANT)
    Q_PROPERTY(QStringList algorithmDescriptions READ algorithmDescriptions CONSTANT)
    Q_PROPERTY(WorkloadListModel* workloadModel READ workloadModel CONSTANT)
    Q_PROPERTY(QString selectedAlgorithm READ selectedAlgorithm WRITE setSelectedAlgorithm NOTIFY selectedAlgorithmChanged)
    Q_PROPERTY(QString selectedWorkloadPath READ selectedWorkloadPath WRITE setSelectedWorkloadPath NOTIFY selectedWorkloadPathChanged)
    Q_PROPERTY(bool hasResult READ hasResult NOTIFY resultChanged)
    Q_PROPERTY(int maxTick READ maxTick NOTIFY resultChanged)
    Q_PROPERTY(QString resultAlgorithmName READ resultAlgorithmName NOTIFY resultChanged)
    Q_PROPERTY(QString resultWorkloadName READ resultWorkloadName NOTIFY resultChanged)
    Q_PROPERTY(bool isAars READ isAars NOTIFY resultChanged)
    Q_PROPERTY(int processCount READ processCount NOTIFY resultChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)

public:
    explicit ChronosBridge(QObject* parent = nullptr);

    QStringList algorithmKeys() const;
    QStringList algorithmLabels() const;
    QStringList algorithmDescriptions() const;
    WorkloadListModel* workloadModel() const { return m_workloadModel; }

    QString selectedAlgorithm() const { return m_selectedAlgorithm; }
    void setSelectedAlgorithm(const QString& algo);
    QString selectedWorkloadPath() const { return m_selectedWorkloadPath; }
    void setSelectedWorkloadPath(const QString& path);

    bool hasResult() const { return m_hasResult; }
    int maxTick() const;
    QString resultAlgorithmName() const;
    QString resultWorkloadName() const;
    bool isAars() const;
    int processCount() const;
    QString errorMessage() const { return m_errorMessage; }

    // Named to avoid colliding with the free function runSimulation() from simulator.h.
    Q_INVOKABLE bool runSelectedSimulation();

    Q_INVOKABLE QVariantList ganttSegments() const;
    Q_INVOKABLE QVariantList readyQueueAt(int tick) const;
    Q_INVOKABLE QVariantMap whyPanelAt(int tick) const;
    Q_INVOKABLE QVariantList agingListAt(int tick) const;
    Q_INVOKABLE QVariantList processTickerAt(int tick) const;
    Q_INVOKABLE int cpuUtilizationAt(int tick) const;
    Q_INVOKABLE int contextSwitchesAt(int tick) const;
    Q_INVOKABLE QString processColor(int pid) const;
    Q_INVOKABLE int processSlot(int pid) const;

signals:
    void selectedAlgorithmChanged();
    void selectedWorkloadPathChanged();
    void resultChanged();
    void errorChanged();

private:
    struct ProcessMeta {
        int arrivalTime = 0;
        int burstTime = 0;
        int waitingTimeFinal = 0;
        int turnaroundTime = 0;
        int responseTime = 0;
        int completionTime = 0;
        int contextSwitches = 0;
        QString predictedClass;
    };

    int ticksRunUpTo(int pid, int tick) const;
    const DecisionLog* lastDecisionAt(int tick) const;
    const GanttEntry* runningSegmentAt(int tick) const;
    void rebuildMeta();

    WorkloadListModel* m_workloadModel;
    QString m_selectedAlgorithm;
    QString m_selectedWorkloadPath;
    QString m_errorMessage;
    bool m_hasResult = false;
    SimulationResult m_result;
    std::map<int, ProcessMeta> m_meta;
};
