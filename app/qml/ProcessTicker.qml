import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.8 — per-process progress. The Gantt chart answers "who had the CPU
// when," which is hard to read as *progress*; this answers "how close is each
// process to finishing," which is the question an audience actually asks while
// watching a scheduler run.
//
// Bars are `TickBar` rather than character bars (§6.9, logged deviation from
// §2.7(7)) — these are read as motion, not as values. Since 2026-10-16 that
// motion is a watch-like tick, segment by segment, not a liquid flow. Hovering a row raises a
// `ProcessHud` (§5.10) explaining that process.
TerminalPane {
    id: root
    property int currentTick: 0
    // Live playback rate, so each bar's ticking finishes well inside one tick
    // interval at every speed (same reason GanttChart takes it).
    property real ticksPerSecond: Theme.baseTicksPerSecond

    // Emitted so the Dashboard can position the HUD in window coordinates —
    // a floating overlay clipped inside this pane would be useless on the rows
    // near its edges. It carries the row *index*, not a snapshot of the row:
    // the HUD re-reads that row every tick, so it stays live while playback
    // runs under a stationary pointer.
    signal hovered(int index, real windowY)
    signal unhovered()

    title: "PROCESS PROGRESS"

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: Theme.spaceXs
        // Bound to the process *count* (Q_PROPERTY, stable for the whole run)
        // rather than to bridge.processTickerAt(currentTick) directly. That
        // call returns a brand-new QVariantList every tick, which QML can't
        // diff against the previous one — ListView would tear down and
        // recreate every delegate every tick, which meant every Behavior
        // animation on them (the bar segments especially) never actually
        // ran: each freshly-created item just snaps straight to its target
        // value instead of easing into it, which is what "glitching" was.
        // Binding to the stable count keeps delegates alive across ticks;
        // each one pulls its own row's live data by index below.
        model: bridge.processCount

        NeonScrollBar { id: tickerBar; flickable: list }

        delegate: Rectangle {
            id: row
            required property int index
            readonly property var modelData: bridge.processTickerRowAt(root.currentTick, index)
            width: ListView.view.width - tickerBar.gutter
            height: Theme.sizeData + Theme.spaceXs

            readonly property color hue: Theme.procShade(modelData.pid)
            readonly property bool isRunning: modelData.running === true

            color: hover.hovered ? Theme.bgPanelRaised : "transparent"
            radius: Theme.radiusNone
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            // Processes that have not arrived yet stay dim rather than hidden,
            // so the whole cast of the workload is visible from tick 0 and
            // switches on as each one arrives.
            opacity: modelData.arrived ? 1.0 : 0.3
            Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spaceSm

                // No glyph — the process's own hue is the only identity
                // channel now (2026-08-25, explicit user request), and it
                // stays that color in every state so a viewer can track "which
                // one is P3" continuously rather than losing it whenever that
                // row isn't the one currently running.
                Text {
                    text: "P" + row.modelData.pid
                    color: row.hue
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeData
                    font.weight: row.isRunning ? Theme.weightBold : Theme.weightMedium
                    Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * 4
                }

                TickBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.sizeData
                    fraction: row.modelData.progressPct / 100
                    fillColor: row.hue
                    active: row.isRunning
                    pixelSize: Theme.sizeData
                    stepBudget: Math.min(900, 650 / root.ticksPerSecond)
                }

                // Width-reserved (§3.2): "100%" and "[DONE]" are both six cells,
                // so the bar never resizes as a process completes.
                Text {
                    text: row.modelData.done ? "[DONE]" : Math.round(row.modelData.progressPct) + "%"
                    color: row.modelData.done ? Theme.accentBlue
                                              : (row.isRunning ? row.hue : Theme.textSecondary)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeData
                    font.weight: row.modelData.done ? Theme.weightBold : Theme.weightRegular
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * 6
                    Behavior on color { ColorAnimation { duration: Theme.durationBase } }
                }
            }

            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (hovered) {
                        const p = row.mapToItem(null, 0, row.height / 2);
                        root.hovered(row.index, p.y);
                    } else {
                        root.unhovered();
                    }
                }
            }
        }
    }
}
