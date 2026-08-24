import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.3 — the ready queue. Columns are sized in *characters* (§3.2)
// rather than pixels, so values never shift their neighbours as digits change.
// The SCORE column appears only for AARS runs.
TerminalPane {
    id: root
    property var rows: []
    property bool isAars: false

    title: "READY QUEUE"

    readonly property int cw: Theme.charWidth(Theme.sizeData)

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spaceXs

        // Column headers ---------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            HeaderCell { text: "PID"; cells: 4 }
            HeaderCell { text: "PRI"; cells: 4 }
            HeaderCell { text: "REM"; cells: 4 }
            HeaderCell { text: "WAIT"; cells: 5 }
            HeaderCell { text: "SCORE"; cells: 6; visible: root.isAars }
            Text {
                text: "CLASS"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeLabel
                font.weight: Theme.weightSemiBold
                font.letterSpacing: Theme.trackLabel
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
        }

        Text {
            Layout.fillWidth: true
            text: "-".repeat(Math.max(8, Math.floor(root.width / Theme.charWidth(Theme.sizeMicro)) - 4))
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            elide: Text.ElideRight
        }

        // Empty state — shell output, not a blank pane (§2.7(5)).
        RowLayout {
            visible: root.rows.length === 0
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Text {
                text: "> no process ready"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeBody
            }
            BlinkingCursor { color: Theme.textDim; font.pixelSize: Theme.sizeBody }
            Item { Layout.fillWidth: true }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.rows
            spacing: 0

            delegate: Rectangle {
                id: rowItem
                required property var modelData
                width: ListView.view.width
                height: Theme.sizeData + Theme.spaceSm
                color: modelData.isRunning ? Theme.bgPanelRaised : "transparent"
                radius: Theme.radiusNone

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spaceSm

                    DataCell {
                        text: "P" + rowItem.modelData.pid
                        cells: 4
                        highlight: rowItem.modelData.isRunning
                        // The PID carries the process's hue so a row can be
                        // matched to its Gantt bar and ticker row by color
                        // rather than by counting positions.
                        overrideColor: Theme.procShade(rowItem.modelData.pid)
                    }
                    DataCell { text: rowItem.modelData.priority; cells: 4 }
                    DataCell { text: rowItem.modelData.burstRemaining; cells: 4 }
                    DataCell { text: rowItem.modelData.wait; cells: 5 }
                    DataCell {
                        text: Number(rowItem.modelData.score).toFixed(1)
                        cells: 6
                        visible: root.isAars
                        // The number the scheduler actually decides on. Cyan
                        // ties it to the why-panel, which explains it.
                        overrideColor: Theme.accentCyan
                    }

                    Text {
                        text: "[" + rowItem.modelData.cls + "]"
                        color: {
                            switch (rowItem.modelData.cls) {
                            case "CPU_BOUND": return Theme.accentMagenta;
                            case "IO_BOUND": return Theme.accentCyan;
                            case "INTERACTIVE": return Theme.accentAmber;
                            default: return Theme.textDim;
                            }
                        }
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.sizeMicro
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // The RUNNING row is the only one that gets a cursor
                    // (§2.7(4)) — it marks where the CPU actually is.
                    BlinkingCursor {
                        visible: rowItem.modelData.isRunning
                        font.pixelSize: Theme.sizeData
                        Layout.preferredWidth: visible ? root.cw : 0
                    }
                }
            }
        }
    }

    component HeaderCell: Text {
        property int cells: 4
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeLabel
        font.weight: Theme.weightSemiBold
        font.letterSpacing: Theme.trackLabel
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * cells
        Layout.fillWidth: false
    }

    component DataCell: Text {
        property int cells: 4
        property bool highlight: false
        property color overrideColor: "transparent"
        color: overrideColor.a > 0 ? overrideColor
                                   : (highlight ? Theme.textPrimary : Theme.textSecondary)
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeData
        font.weight: highlight ? Theme.weightBold : Theme.weightMedium
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * cells
        Layout.fillWidth: false
    }
}
