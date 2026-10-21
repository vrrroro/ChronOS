import QtQuick
import QtQuick.Layouts
import ChronOS

// The CUSTOM WORKLOAD builder (added 2026-10-16, explicit user request): the
// left half of the workload picker in custom mode. A workload here is a list
// of process GROUPS — "4 × INTERACTIVE", "2 × CPU-BOUND" — each with its own
// burst and priority range, plus how they arrive.
//
// This is a pure editor over bridge.customSpec. Every edit goes to the bridge
// (which clamps it and regenerates), and the WorkloadCard on the right redraws
// from bridge.customSummary — so what the card describes is always exactly
// what RUN will simulate. Generation itself is engine code
// (engine/workload_gen.*), deterministic per seed.
Item {
    id: root

    readonly property var spec: bridge.customSpec
    readonly property var groups: spec.groups ? spec.groups : []
    readonly property bool canAdd: groups.length < spec.maxGroups && spec.total < spec.maxTotal

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        NeonScrollBar { id: editorBar; flickable: flick }

        ColumnLayout {
            id: col
            width: flick.width - Math.max(Theme.spaceSm, editorBar.gutter)
            spacing: Theme.spaceSm

            // Name + quantum ---------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                FieldLabel { text: "NAME" }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.sizeData + Theme.spaceXs * 2 + 2
                    color: Theme.bgInset
                    radius: Theme.radiusNone
                    border.width: Theme.borderThin
                    border.color: nameInput.activeFocus ? Theme.borderActive : Theme.borderMuted

                    TextInput {
                        id: nameInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceSm
                        anchors.rightMargin: Theme.spaceSm
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.spec.name
                        maximumLength: 32
                        color: Theme.textPrimary
                        selectionColor: Theme.textPrimary
                        selectedTextColor: Theme.textOnAccent
                        selectByMouse: true
                        clip: true
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.sizeData
                        onEditingFinished: {
                            bridge.setCustomField("name", text);
                            text = Qt.binding(() => root.spec.name);
                        }
                    }
                }

                FieldLabel { text: "QUANTUM"; Layout.leftMargin: Theme.spaceSm }
                TerminalStepper {
                    cells: 2
                    value: root.spec.quantum
                    minimum: 1; maximum: 20
                    onEdited: (v) => bridge.setCustomField("quantum", v)
                }
            }

            // Arrivals -----------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                FieldLabel { text: "ARRIVALS" }
                Repeater {
                    model: ["ALL AT ONCE", "STAGGERED", "CLUSTERED"]
                    delegate: TerminalButton {
                        required property string modelData
                        label: "[ " + modelData + " ]"
                        selected: root.spec.arrival === modelData
                        onClicked: bridge.setCustomField("arrival", modelData)
                    }
                }
                Item { Layout.fillWidth: true }
                FieldLabel {
                    visible: root.spec.arrival !== "ALL AT ONCE"
                    text: root.spec.arrival === "CLUSTERED" ? "EVERY" : "GAP ~"
                }
                TerminalStepper {
                    visible: root.spec.arrival !== "ALL AT ONCE"
                    cells: 2
                    value: root.spec.spacing
                    minimum: 0; maximum: 30
                    onEdited: (v) => bridge.setCustomField("spacing", v)
                }
            }

            // Seed -------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                FieldLabel { text: "SEED" }
                TerminalStepper {
                    cells: 5
                    value: root.spec.seed
                    minimum: 0; maximum: 99999
                    onEdited: (v) => bridge.setCustomField("seed", v)
                }
                TerminalButton {
                    label: "[ REROLL ]"
                    onClicked: bridge.rerollSeed()
                }
                Text {
                    Layout.fillWidth: true
                    text: "same seed + same groups = same workload"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    elide: Text.ElideRight
                }
            }

            Text {
                Layout.fillWidth: true
                text: "=".repeat(Math.max(8, Math.floor(col.width / Theme.charWidth(Theme.sizeMicro)) - 2))
                color: Theme.borderMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                FieldLabel { text: "PROCESS GROUPS" }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.spec.total + " / " + root.spec.maxTotal + " PROCESSES"
                    color: root.spec.total >= root.spec.maxTotal ? Theme.accentAmber
                                                                 : (root.spec.total === 0 ? Theme.accentError
                                                                                          : Theme.textPrimary)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.weight: Theme.weightBold
                    font.letterSpacing: Theme.trackMicro
                }
            }

            // Groups -----------------------------------------------------------
            // Modelled on the group *count*, not the groups array: every
            // edit hands back a fresh array, and binding to it would rebuild
            // every row on every keystroke — killing hold-to-repeat on the
            // steppers mid-press (the same trap AGENTS.md records for the
            // process ticker). Each row reads its own group by index.
            Repeater {
                model: root.groups.length

                delegate: Rectangle {
                    id: group
                    required property int index
                    readonly property var modelData: root.groups[index] || ({})

                    Layout.fillWidth: true
                    Layout.preferredHeight: groupCol.implicitHeight + Theme.spaceSm * 2
                    color: Theme.bgVoid
                    radius: Theme.radiusNone
                    border.width: Theme.borderThin
                    border.color: Theme.borderMuted

                    ColumnLayout {
                        id: groupCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spaceSm
                        spacing: Theme.spaceXs

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceSm

                            Text {
                                text: "#" + (group.index + 1)
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.sizeLabel
                                font.weight: Theme.weightBold
                            }
                            Repeater {
                                model: ["CPU-BOUND", "BALANCED", "INTERACTIVE"]
                                delegate: TerminalButton {
                                    required property string modelData
                                    label: modelData
                                    selected: group.modelData.kind === modelData
                                    onClicked: bridge.setGroupField(group.index, "kind", modelData)
                                }
                            }
                            Item { Layout.fillWidth: true }
                            FieldLabel { text: "×" }
                            TerminalStepper {
                                cells: 2
                                value: group.modelData.count
                                minimum: 0; maximum: root.spec.maxTotal
                                onEdited: (v) => bridge.setGroupField(group.index, "count", v)
                            }
                            TerminalButton {
                                label: "[ x ]"
                                onClicked: bridge.removeGroup(group.index)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceSm

                            FieldLabel { text: "BURST" }
                            TerminalStepper {
                                cells: 2
                                value: group.modelData.burstMin
                                minimum: 1; maximum: 60
                                onEdited: (v) => bridge.setGroupField(group.index, "burstMin", v)
                            }
                            FieldLabel { text: "–" }
                            TerminalStepper {
                                cells: 2
                                value: group.modelData.burstMax
                                minimum: 1; maximum: 60
                                onEdited: (v) => bridge.setGroupField(group.index, "burstMax", v)
                            }
                            FieldLabel { text: "TICKS" }
                            Item { Layout.fillWidth: true }
                            FieldLabel { text: "PRIORITY" }
                            TerminalStepper {
                                cells: 2
                                value: group.modelData.priorityMin
                                minimum: 1; maximum: 10
                                onEdited: (v) => bridge.setGroupField(group.index, "priorityMin", v)
                            }
                            FieldLabel { text: "–" }
                            TerminalStepper {
                                cells: 2
                                value: group.modelData.priorityMax
                                minimum: 1; maximum: 10
                                onEdited: (v) => bridge.setGroupField(group.index, "priorityMax", v)
                            }
                        }
                    }
                }
            }

            // Add a group ------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                FieldLabel { text: "ADD" }
                Repeater {
                    model: ["CPU-BOUND", "BALANCED", "INTERACTIVE"]
                    delegate: TerminalButton {
                        required property string modelData
                        label: "[ + " + modelData + " ]"
                        enabledButton: root.canAdd
                        onClicked: bridge.addGroup(modelData)
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Text {
                Layout.fillWidth: true
                text: "> type sets the starting ranges: CPU-BOUND long bursts / low priority, "
                      + "INTERACTIVE short bursts / high priority. Edit either range freely."
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                wrapMode: Text.WordWrap
            }
        }
    }

    component FieldLabel: Text {
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeMicro
        font.weight: Theme.weightBold
        font.letterSpacing: Theme.trackMicro
    }
}
