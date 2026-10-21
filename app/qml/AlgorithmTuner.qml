import QtQuick
import QtQuick.Layouts
import ChronOS

// AARS tuner (added 2026-10-16, explicit user request), reached from the
// [ TUNE ] control on the algorithm picker's AARS row. Every PRD §6.1 score
// term and every §6.4 quantum is editable; the right column shows the live
// formula those values make.
//
// Any change from the defaults is flagged [TUNED] here, on the picker, and in
// the run's name ("AARS (tuned)"), so tuned numbers are never mistaken for the
// honest as-specified formula's (AGENTS.md Algorithm rules).
Item {
    id: root
    signal continueRequested()
    signal backRequested()

    focus: true
    Component.onCompleted: root.forceActiveFocus()

    readonly property var t: bridge.aarsTuning

    function set(field, value) { bridge.setAarsTuning(field, value); }
    function fmt(v) { return Number(v).toFixed(1).replace(/\.0$/, ""); }

    readonly property var terms: [
        { field: "priorityWeight", label: "PRIORITY WEIGHT", unit: "× base priority (1–10)",
          step: 0.5, min: -5, max: 5, dec: 1 },
        { field: "agingDivisor", label: "AGING DIVISOR", unit: "aging = wait ÷ this · 0 = off",
          step: 0.5, min: 0, max: 20, dec: 1 },
        { field: "agingCap", label: "AGING CAP", unit: "aging never exceeds this",
          step: 1, min: 0, max: 1000, dec: 0 },
        { field: "ioBoundBonus", label: "I/O-BOUND BONUS", unit: "if classified IO_BOUND",
          step: 0.5, min: -10, max: 20, dec: 1 },
        { field: "interactiveBonus", label: "INTERACTIVE BONUS", unit: "if classified INTERACTIVE",
          step: 0.5, min: -10, max: 20, dec: 1 },
        { field: "responseBonus", label: "RESPONSE BONUS", unit: "until a process first runs",
          step: 0.5, min: -10, max: 20, dec: 1 },
        { field: "burstPenaltyDivisor", label: "BURST PENALTY DIVISOR", unit: "penalty = avg burst ÷ this · 0 = off",
          step: 0.5, min: 0, max: 20, dec: 1 },
        { field: "burstPenaltyCap", label: "BURST PENALTY CAP", unit: "penalty never exceeds this",
          step: 1, min: 0, max: 50, dec: 0 },
    ]

    readonly property var classQuanta: [
        { field: "quantumCpuBound", label: "CPU_BOUND" },
        { field: "quantumBalanced", label: "BALANCED / PENDING" },
        { field: "quantumInteractive", label: "INTERACTIVE" },
        { field: "quantumIoBound", label: "IO_BOUND" },
    ]

    Rectangle { anchors.fill: parent; color: Theme.bgVoid }

    RowLayout {
        x: Math.max(Theme.spaceXl, (root.width - width) / 2)
        y: Math.max(Theme.spaceLg, (root.height - height) / 2)
        width: Math.min(1080, root.width - Theme.spaceXl * 2)
        height: Math.min(620, root.height - Theme.spaceXl * 2)
        spacing: Theme.spaceLg

        // Left: the weights ------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 460
            spacing: Theme.spaceMd

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                TypewriterText {
                    Layout.fillWidth: true
                    fullText: "TUNE AARS"
                    color: Theme.textPrimary
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.sizeH0
                    bloomEnabled: true
                    bloom: 0.9
                    flicker: true
                }

                Text {
                    Layout.fillWidth: true
                    text: "chronos@aars:~$ chronos --algorithm aars --tune"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.letterSpacing: Theme.trackMicro
                }
            }

            TerminalPane {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "WEIGHTS"
                statusText: "CLICK A VALUE TO TYPE  //  HOLD [-] [+]  //  WHEEL"

                Flickable {
                    id: flick
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: weightCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    NeonScrollBar { id: weightBar; flickable: flick }

                    ColumnLayout {
                        id: weightCol
                        width: flick.width - Math.max(Theme.spaceSm, weightBar.gutter)
                        spacing: Theme.spaceXs

                        SectionLabel { text: "SCORE TERMS  (highest score runs next · ties → lowest PID)" }

                        Repeater {
                            model: root.terms
                            delegate: ParamRow {
                                required property var modelData
                                label: modelData.label
                                unit: modelData.unit
                                value: Number(root.t[modelData.field])
                                step: modelData.step
                                minimum: modelData.min
                                maximum: modelData.max
                                decimals: modelData.dec
                                onEdited: (v) => root.set(modelData.field, v)
                            }
                        }

                        SectionLabel { text: "TIME QUANTUM  (by class, PRD §6.4)"; Layout.topMargin: Theme.spaceSm }

                        Repeater {
                            model: root.classQuanta
                            delegate: ParamRow {
                                required property var modelData
                                label: modelData.label
                                unit: "ticks per slice for this class"
                                value: Number(root.t[modelData.field])
                                step: 1; minimum: 1; maximum: 30; decimals: 0
                                onEdited: (v) => root.set(modelData.field, v)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                TerminalButton {
                    label: "[ < BACK ]"
                    hPadding: Theme.spaceMd
                    onClicked: root.backRequested()
                }
                TerminalButton {
                    label: "[ RESET TO PRD DEFAULTS ]"
                    hPadding: Theme.spaceMd
                    enabledButton: bridge.aarsTuned
                    onClicked: bridge.resetAarsTuning()
                }
                Item { Layout.fillWidth: true }
                TerminalButton {
                    label: "[ CONTINUE > ]"
                    hPadding: Theme.spaceMd
                    onClicked: root.continueRequested()
                }
            }
        }

        // Right: the formula -----------------------------------------------
        ColumnLayout {
            Layout.preferredWidth: 400
            Layout.minimumWidth: 400
            Layout.maximumWidth: 400
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: Theme.spaceMd

            TerminalPane {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: formula.implicitHeight + Theme.sizeH1 + Theme.sizeMicro + Theme.spaceLg * 2 + Theme.spaceMd
                title: "FORMULA"
                statusText: bridge.aarsTuned ? "AARS (tuned)" : "AARS · PRD §6.1"
                active: true

                // Cyan is the scheduler's-reasoning hue (EDRD §2.5) — this is
                // that reasoning, before it runs. A term switched off drops to
                // dim, so the live formula reads at a glance.
                ColumnLayout {
                    id: formula
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spaceSm
                    spacing: 2

                    FormulaLine { text: "SCORE ="; on: true }
                    FormulaLine { text: "  " + root.fmt(root.t.priorityWeight) + " × PRIORITY"; on: root.t.priorityWeight !== 0 }
                    FormulaLine {
                        text: "+ min(WAIT ÷ " + root.fmt(root.t.agingDivisor) + ", " + root.fmt(root.t.agingCap) + ")"
                        on: root.t.agingDivisor > 0 && root.t.agingCap > 0
                    }
                    FormulaLine {
                        text: "+ " + root.fmt(root.t.ioBoundBonus) + " if IO_BOUND · "
                              + root.fmt(root.t.interactiveBonus) + " if INTERACTIVE"
                        on: root.t.ioBoundBonus !== 0 || root.t.interactiveBonus !== 0
                    }
                    FormulaLine { text: "+ " + root.fmt(root.t.responseBonus) + " until first run"; on: root.t.responseBonus !== 0 }
                    FormulaLine {
                        text: "− min(AVG BURST ÷ " + root.fmt(root.t.burstPenaltyDivisor) + ", " + root.fmt(root.t.burstPenaltyCap) + ")"
                        on: root.t.burstPenaltyDivisor > 0 && root.t.burstPenaltyCap > 0
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spaceSm
                        text: "QUANTUM  CPU " + root.t.quantumCpuBound + " · BAL " + root.t.quantumBalanced
                              + " · INT " + root.t.quantumInteractive + " · IO " + root.t.quantumIoBound
                        color: Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.sizeMicro
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        visible: bridge.aarsTuned
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spaceSm
                        text: "[TUNED] not the as-specified PRD formula — this run will be named \"AARS (tuned)\""
                        color: Theme.accentAmber
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.sizeMicro
                        font.weight: Theme.weightBold
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "> change one weight at a time and re-run the same workload to see what that term does"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceSm
        text: "[ENTER] CONTINUE   //   [ESC] BACK"
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeMicro
        font.letterSpacing: Theme.trackMicro
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.continueRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.backRequested();
            event.accepted = true;
        }
    }

    component SectionLabel: Text {
        Layout.fillWidth: true
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeMicro
        font.weight: Theme.weightBold
        font.letterSpacing: Theme.trackMicro
        elide: Text.ElideRight
    }

    component FormulaLine: Text {
        property bool on: true
        Layout.fillWidth: true
        color: on ? Theme.accentCyan : Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeData
        elide: Text.ElideRight
    }

    // One weight: name and meaning on the left, the stepper on the right.
    component ParamRow: RowLayout {
        id: param
        property string label: ""
        property string unit: ""
        property alias value: stepper.value
        property alias step: stepper.step
        property alias minimum: stepper.minimum
        property alias maximum: stepper.maximum
        property alias decimals: stepper.decimals
        signal edited(real v)

        Layout.fillWidth: true
        spacing: Theme.spaceSm

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: param.label
                color: Theme.textPrimary
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeLabel
                font.weight: Theme.weightSemiBold
                font.letterSpacing: Theme.trackLabel
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: param.unit
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                elide: Text.ElideRight
            }
        }

        TerminalStepper {
            id: stepper
            cells: 5
            Layout.fillWidth: false
            onEdited: (v) => param.edited(v)
        }
    }
}
