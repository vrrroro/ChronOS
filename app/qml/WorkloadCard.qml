import QtQuick
import QtQuick.Layouts
import ChronOS

// The hover card for the workload picker — explains what kind of load a preset
// puts on the scheduler before you commit to running it.
//
// Every number here is computed from the workload file by WorkloadListModel
// (see its header comment): AGENTS.md forbids hardcoded illustrative metrics,
// and a stat authored next to the data it describes is exactly that. The only
// authored string is `description`, which is editorial prose about the shape of
// the load, not a measurement.
//
// Styled as terminal window chrome (EDRD §2.7(8)) rather than a floating
// tooltip: a soft popover with a shadow would be the one rounded, lifted thing
// in an application that has neither.
TerminalPane {
    id: root

    property string workloadName: ""
    property string description: ""
    property string profile: ""
    property int processCount: 0
    property int quantum: 0
    property int totalBurst: 0
    property string avgBurst: "0.0"
    property int minBurst: 0
    property int maxBurst: 0
    property int arrivalSpan: 0
    property int priorityMin: 0
    property int priorityMax: 0
    property string loadFactor: "0.0"
    // How MLFQ and CFS will slice this workload, resolved by the engine
    // (WorkloadListModel::schedulerNote) — the per-workload facts those two
    // algorithms need beyond the processes themselves.
    property string schedulerNote: ""
    // Custom workloads only (2026-10-16): what the builder generated. Empty
    // for presets, and both sections below hide themselves when empty.
    property var composition: []
    property var processes: []
    property string statusOverride: ""

    title: workloadName.toUpperCase()
    statusText: statusOverride.length > 0 ? statusOverride
                                          : "--workload " + workloadName.toLowerCase().replace(/ /g, "_")
    active: true

    implicitWidth: 380
    implicitHeight: body.implicitHeight + Theme.sizeH1 + Theme.sizeMicro + Theme.spaceLg * 2 + Theme.spaceMd

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.spaceSm
        spacing: Theme.spaceMd

        // Profile badge + headline counts ---------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            Rectangle {
                Layout.preferredWidth: profileLabel.implicitWidth + Theme.spaceSm * 2
                Layout.preferredHeight: profileLabel.implicitHeight + Theme.spaceXs * 2
                Layout.fillWidth: false
                color: Theme.textPrimary
                radius: Theme.radiusNone

                Text {
                    id: profileLabel
                    anchors.centerIn: parent
                    text: "[" + root.profile + "]"
                    color: Theme.textOnAccent
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.weight: Theme.weightSemiBold
                    font.letterSpacing: Theme.trackMicro
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.processCount + " PROCESSES"
                color: Theme.textPrimary
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeLabel
                font.weight: Theme.weightBold
                font.letterSpacing: Theme.trackLabel
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.description
            color: Theme.textSecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeBody
            lineHeight: 1.4
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: "=".repeat(Math.max(8, Math.floor(root.width / Theme.charWidth(Theme.sizeMicro)) - 4))
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            elide: Text.ElideRight
        }

        // Composition (custom workloads) -----------------------------------
        // How many of each kind the builder made. Kind is categorical, like
        // the CLASS badge (EDRD §2.5 exemption), and always spelled out.
        ColumnLayout {
            visible: root.composition.length > 0
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            Repeater {
                model: root.composition
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.spaceSm
                    Text {
                        text: modelData.kind
                        color: Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.sizeMicro
                        font.letterSpacing: Theme.trackMicro
                        Layout.preferredWidth: Theme.charWidth(Theme.sizeMicro) * 13
                    }
                    AsciiBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.sizeMicro + 2
                        fraction: root.processCount > 0 ? modelData.count / root.processCount : 0
                        glyph: "|"
                        pixelSize: Theme.sizeMicro
                    }
                    Text {
                        text: modelData.count
                        color: Theme.textPrimary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.sizeMicro
                        font.weight: Theme.weightBold
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: Theme.charWidth(Theme.sizeMicro) * 3
                    }
                }
            }
        }

        // The generated processes as a skyline: one column per process, in
        // PID (= arrival) order, height proportional to its burst, in the hue
        // it will wear on the dashboard (§2.3) — so the run that follows is
        // recognisable before it starts.
        ColumnLayout {
            visible: root.processes.length > 0
            Layout.fillWidth: true
            spacing: 2

            Item {
                id: skyline
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                readonly property real colW: root.processes.length > 0
                                             ? width / root.processes.length : 0

                Repeater {
                    model: root.processes
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        x: index * skyline.colW
                        width: Math.max(1, skyline.colW - (skyline.colW > 4 ? 2 : 0))
                        height: Math.max(2, skyline.height * modelData.burst / Math.max(1, root.maxBurst))
                        anchors.bottom: parent.bottom
                        color: Theme.procShade(modelData.pid)
                        radius: Theme.radiusNone
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "P1 → P" + root.processes.length + "  //  height = burst  //  color = dashboard identity"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                elide: Text.ElideRight
            }
        }

        Text {
            visible: root.processes.length > 0
            Layout.fillWidth: true
            text: "=".repeat(Math.max(8, Math.floor(root.width / Theme.charWidth(Theme.sizeMicro)) - 4))
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            elide: Text.ElideRight
        }

        // Burst distribution ----------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            StatLine { label: "BURST AVG"; value: root.avgBurst + " ticks" }
            StatLine { label: "BURST RANGE"; value: root.minBurst + " – " + root.maxBurst + " ticks" }
            StatLine { label: "TOTAL WORK"; value: root.totalBurst + " ticks" }
            StatLine {
                label: "ARRIVALS"
                value: root.arrivalSpan === 0 ? "all at tick 0"
                                              : "tick 0 – " + root.arrivalSpan
            }
            StatLine { label: "PRIORITY"; value: root.priorityMin + " – " + root.priorityMax }
            StatLine {
                label: "SLICING"
                value: "RR " + root.quantum
                       + (root.schedulerNote.length > 0 ? " · " + root.schedulerNote : "")
            }
        }

        Text {
            Layout.fillWidth: true
            text: "=".repeat(Math.max(8, Math.floor(root.width / Theme.charWidth(Theme.sizeMicro)) - 4))
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            elide: Text.ElideRight
        }

        // Load factor ------------------------------------------------------
        // Work arriving per tick of the arrival window. Above 1.0 the CPU can
        // never catch up while arrivals continue, which is the single best
        // predictor of whether a preset will visibly queue.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "LOAD FACTOR"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.letterSpacing: Theme.trackMicro
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.loadFactor + "×"
                    color: Number(root.loadFactor) > 1.0 ? Theme.accentAmber : Theme.textPrimary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeLabel
                    font.weight: Theme.weightBold
                }
            }

            AsciiBar {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.sizeData + 2
                // Scaled against 3× so the common 0–3 range reads clearly;
                // anything past that pins full, which is the correct signal.
                fraction: Number(root.loadFactor) / 3.0
                glyph: "|"
                fillColor: Number(root.loadFactor) > 1.0 ? Theme.accentAmber : Theme.textPrimary
                pixelSize: Theme.sizeData
            }

            Text {
                Layout.fillWidth: true
                text: Number(root.loadFactor) > 1.0
                      ? "> work arrives faster than one CPU can clear it — expect a deep queue"
                      : "> the CPU keeps up with arrivals — expect idle gaps"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                wrapMode: Text.WordWrap
            }
        }
    }

    // Local row type for the stat table — two columns, label left, value right
    // aligned. Kept inline because it is meaningless outside this card.
    component StatLine: RowLayout {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true

        Text {
            text: parent.label
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            font.letterSpacing: Theme.trackMicro
        }
        // Takes the rest of the row and elides, so a long value never runs
        // into its label.
        Text {
            Layout.fillWidth: true
            text: parent.value
            color: Theme.textSecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
    }
}
