#pragma once

#include <QAbstractListModel>
#include <QVector>
#include <QString>

// Backs the in-app workload file browser (WorkloadPicker.qml) — lists the
// *.json files under the workloads directory so the GUI never needs to open
// an OS file-explorer dialog.
//
// Beyond the bare file listing, each entry carries the statistics the picker's
// hover card shows. Every one of those numbers is *computed from the file*
// (PRD §5.2 shape) rather than authored alongside it — CLAUDE.md forbids
// hardcoded illustrative metrics, and a stat that can drift out of sync with
// the workload it describes is exactly that. The only authored field is the
// optional `description` string, which is editorial prose about what kind of
// load the preset represents, not a measurement.
class WorkloadListModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        ProcessCountRole,
        DescriptionRole,
        ProfileRole,       // derived label: INTERACTIVE / MIXED / CPU-BOUND
        QuantumRole,
        TotalBurstRole,
        AvgBurstRole,      // one decimal, as a preformatted string
        MinBurstRole,
        MaxBurstRole,
        ArrivalSpanRole,   // last arrival tick; 0 means "all at once"
        PriorityMinRole,
        PriorityMaxRole,
        LoadFactorRole,    // totalBurst / arrivalSpan, one decimal, as a string
    };

    explicit WorkloadListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void refresh();

private:
    struct Entry {
        QString displayName;
        QString path;
        QString description;
        QString profile;
        int processCount = 0;
        int quantum = 0;
        int totalBurst = 0;
        int minBurst = 0;
        int maxBurst = 0;
        int arrivalSpan = 0;
        int priorityMin = 0;
        int priorityMax = 0;
        double avgBurst = 0.0;
        double loadFactor = 0.0;
    };
    QVector<Entry> m_entries;
};
