#include "WorkloadListModel.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <algorithm>
#include <limits>

#ifndef CHRONOS_WORKLOADS_DIR
#define CHRONOS_WORKLOADS_DIR "workloads"
#endif

namespace {

// Rule-based, three-bucket label for the picker's hover card, from the mean
// burst length. Deliberately coarse and deliberately *not* the engine's
// ProcessClass classifier (PRD §6.3) — that one classifies a single process
// from its observed behavior mid-run, this one summarizes a whole file before
// anything has run. Keeping them separate stops a UI tweak from looking like
// a change to scheduling logic.
QString profileFor(double avgBurst) {
    if (avgBurst <= 4.0) return QStringLiteral("INTERACTIVE");
    if (avgBurst <= 12.0) return QStringLiteral("MIXED");
    return QStringLiteral("CPU-BOUND");
}

QString oneDecimal(double v) {
    return QString::number(v, 'f', 1);
}

}  // namespace

WorkloadListModel::WorkloadListModel(QObject* parent) : QAbstractListModel(parent) {
    refresh();
}

void WorkloadListModel::refresh() {
    beginResetModel();
    m_entries.clear();

    QDir dir(QString::fromUtf8(CHRONOS_WORKLOADS_DIR));
    if (!dir.exists()) dir = QDir(QStringLiteral("workloads"));

    const QStringList files = dir.entryList({QStringLiteral("*.json")}, QDir::Files, QDir::Name);
    for (const QString& file : files) {
        Entry e;
        e.path = dir.filePath(file);
        e.displayName = QFileInfo(file).completeBaseName();

        QFile f(e.path);
        if (!f.open(QIODevice::ReadOnly)) continue;

        const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        if (!doc.isObject()) continue;
        const QJsonObject obj = doc.object();

        if (obj.contains(QStringLiteral("name"))) {
            e.displayName = obj.value(QStringLiteral("name")).toString();
        }
        e.description = obj.value(QStringLiteral("description")).toString();
        e.quantum = obj.value(QStringLiteral("quantum")).toInt(0);

        const QJsonArray procs = obj.value(QStringLiteral("processes")).toArray();
        e.processCount = procs.size();

        int minBurst = std::numeric_limits<int>::max();
        int maxBurst = 0;
        int minPriority = std::numeric_limits<int>::max();
        int maxPriority = 0;
        int lastArrival = 0;

        for (const QJsonValue& v : procs) {
            const QJsonObject p = v.toObject();
            const int burst = p.value(QStringLiteral("burstTime")).toInt(0);
            const int arrival = p.value(QStringLiteral("arrivalTime")).toInt(0);
            const int priority = p.value(QStringLiteral("priority")).toInt(5);

            e.totalBurst += burst;
            minBurst = std::min(minBurst, burst);
            maxBurst = std::max(maxBurst, burst);
            minPriority = std::min(minPriority, priority);
            maxPriority = std::max(maxPriority, priority);
            lastArrival = std::max(lastArrival, arrival);
        }

        if (e.processCount > 0) {
            e.minBurst = minBurst;
            e.maxBurst = maxBurst;
            e.priorityMin = minPriority;
            e.priorityMax = maxPriority;
            e.arrivalSpan = lastArrival;
            e.avgBurst = static_cast<double>(e.totalBurst) / e.processCount;
            // Work arriving per tick of arrival window. Above 1.0 the CPU can
            // never catch up while arrivals are still coming in, which is the
            // single most useful number for predicting whether a preset will
            // show queueing at all — so it is worth surfacing even though it
            // takes a sentence to explain.
            e.loadFactor = e.arrivalSpan > 0
                               ? static_cast<double>(e.totalBurst) / e.arrivalSpan
                               : static_cast<double>(e.totalBurst);
            e.profile = profileFor(e.avgBurst);
        }

        m_entries.push_back(e);
    }

    endResetModel();
}

int WorkloadListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return m_entries.size();
}

QVariant WorkloadListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size()) return {};
    const Entry& e = m_entries.at(index.row());
    switch (role) {
        case NameRole: return e.displayName;
        case PathRole: return e.path;
        case ProcessCountRole: return e.processCount;
        case DescriptionRole: return e.description;
        case ProfileRole: return e.profile;
        case QuantumRole: return e.quantum;
        case TotalBurstRole: return e.totalBurst;
        case AvgBurstRole: return oneDecimal(e.avgBurst);
        case MinBurstRole: return e.minBurst;
        case MaxBurstRole: return e.maxBurst;
        case ArrivalSpanRole: return e.arrivalSpan;
        case PriorityMinRole: return e.priorityMin;
        case PriorityMaxRole: return e.priorityMax;
        case LoadFactorRole: return oneDecimal(e.loadFactor);
        default: return {};
    }
}

QHash<int, QByteArray> WorkloadListModel::roleNames() const {
    return {
        {NameRole, "name"},
        {PathRole, "path"},
        {ProcessCountRole, "processCount"},
        {DescriptionRole, "description"},
        {ProfileRole, "profile"},
        {QuantumRole, "quantum"},
        {TotalBurstRole, "totalBurst"},
        {AvgBurstRole, "avgBurst"},
        {MinBurstRole, "minBurst"},
        {MaxBurstRole, "maxBurst"},
        {ArrivalSpanRole, "arrivalSpan"},
        {PriorityMinRole, "priorityMin"},
        {PriorityMaxRole, "priorityMax"},
        {LoadFactorRole, "loadFactor"},
    };
}
