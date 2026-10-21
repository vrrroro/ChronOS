import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.7, step 1 of the pre-dashboard flow. A full screen, not a footer
// control: in the native app the simulation must be chosen before there is
// anything to show, so the picker gets the whole window.
//
// Revised 2026-10-16 (explicit user request): an ABOUT card on the right
// (characteristics, strengths, weaknesses) in place of the one-line
// description under each row. The AARS row carries a [ TUNE ] control that
// opens the AARS tuner before the workload step.
//
// Revised 2026-10-22 (explicit user request): the two real operating-system
// schedulers — MLFQ (Windows) and CFS (Linux) — sit in their own section under
// the original five, and a COMPARE TWO mode picks an A and a B to run on the
// same processes side by side.
Item {
    id: root
    signal chosen()
    signal tuneRequested()

    focus: true

    readonly property var keys: bridge.algorithmKeys
    readonly property var labels: bridge.algorithmLabels
    readonly property bool compareMode: bridge.compareMode
    readonly property bool canCompare: bridge.compareKeyA.length > 0 && bridge.compareKeyB.length > 0

    // Which row the ABOUT card describes: the hovered one, and it stays on the
    // last one hovered rather than blanking as the pointer crosses a gap.
    property int shownIndex: Math.max(0, keys.indexOf(bridge.selectedAlgorithm))

    // StackView does not hand active focus to a replaced item on its own.
    Component.onCompleted: root.forceActiveFocus()

    function range(from, to) {
        const out = [];
        for (let i = from; i < to; ++i) out.push(i);
        return out;
    }

    function pick(index) {
        bridge.selectedAlgorithm = keys[index];
        root.chosen();
    }

    // A row click: run it, or — in compare mode — make it A or B.
    function activate(index) {
        root.shownIndex = index;
        if (root.compareMode) bridge.toggleCompareKey(keys[index]);
        else root.pick(index);
    }

    function proceed() {
        if (!root.compareMode) root.pick(root.shownIndex);
        else if (root.canCompare) root.chosen();
        else bridge.toggleCompareKey(keys[root.shownIndex]);
    }

    function tune(index) {
        if (!root.compareMode) bridge.selectedAlgorithm = keys[index];
        root.tuneRequested();
    }

    function quickCompare(a, b) {
        bridge.compareKeyA = a;
        bridge.compareKeyB = b;
    }

    Rectangle { anchors.fill: parent; color: Theme.bgVoid }

    RowLayout {
        x: Math.max(Theme.spaceXl, (root.width - width) / 2)
        y: Math.max(Theme.spaceLg, (root.height - height) / 2)
        width: Math.min(1080, root.width - Theme.spaceXl * 2)
        height: Math.min(600, root.height - Theme.spaceXl * 2 - Theme.spaceLg)
        spacing: Theme.spaceLg

        // Left: heading + rows ---------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 420
            spacing: Theme.spaceMd

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                TypewriterText {
                    Layout.fillWidth: true
                    fullText: root.compareMode ? "CHOOSE TWO ALGORITHMS" : "CHOOSE AN ALGORITHM"
                    color: Theme.textPrimary
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.sizeH0
                    bloomEnabled: true
                    bloom: 0.9
                    flicker: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.compareMode
                          ? "chronos@aars:~$ chronos --compare "
                            + (bridge.compareKeyA || "<a>") + "," + (bridge.compareKeyB || "<b>")
                          : "chronos@aars:~$ chronos --algorithm <name>"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.letterSpacing: Theme.trackMicro
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                TerminalButton {
                    label: "[ RUN ONE ]"
                    selected: !root.compareMode
                    onClicked: bridge.compareMode = false
                }
                TerminalButton {
                    label: "[ COMPARE TWO ]"
                    selected: root.compareMode
                    onClicked: bridge.compareMode = true
                }
                Item { Layout.fillWidth: true }
            }

            // The rows scroll only if the window is too short to hold them;
            // at the default size everything is visible at once.
            Flickable {
                id: rowsFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: rowsCol.implicitHeight
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                NeonScrollBar { id: rowsBar; flickable: rowsFlick }

                ColumnLayout {
                    id: rowsCol
                    width: rowsFlick.width - rowsBar.gutter
                    spacing: Theme.spaceSm

                    Repeater {
                        model: root.range(0, bridge.osSectionStart)
                        delegate: AlgoRow {}
                    }

                    SectionRule {
                        Layout.topMargin: Theme.spaceXs
                        label: "REAL-WORLD OS SCHEDULERS"
                    }

                    Repeater {
                        model: root.range(bridge.osSectionStart, root.keys.length)
                        delegate: AlgoRow {}
                    }
                }
            }

            // Run mode: keyboard hints. Compare mode: shortcuts + continue.
            Text {
                visible: !root.compareMode
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.sizeH1 + Theme.spaceMd
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "[1-7] SELECT   //   [↑↓] BROWSE   //   [T] TUNE AARS   //   [TAB] COMPARE"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                font.letterSpacing: Theme.trackMicro
                elide: Text.ElideRight
            }

            RowLayout {
                visible: root.compareMode
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                TerminalButton {
                    label: "[ AARS vs MLFQ ]"
                    selected: bridge.compareKeyA === "aars" && bridge.compareKeyB === "mlfq"
                    onClicked: root.quickCompare("aars", "mlfq")
                }
                TerminalButton {
                    label: "[ AARS vs CFS ]"
                    selected: bridge.compareKeyA === "aars" && bridge.compareKeyB === "cfs"
                    onClicked: root.quickCompare("aars", "cfs")
                }
                Item { Layout.fillWidth: true }
                TerminalButton {
                    label: "[ CONTINUE > ]"
                    hPadding: Theme.spaceMd
                    enabledButton: root.canCompare
                    onClicked: root.chosen()
                }
            }
        }

        // Right: the ABOUT card --------------------------------------------
        Item {
            Layout.preferredWidth: 400
            Layout.minimumWidth: 400
            Layout.maximumWidth: 400
            Layout.fillWidth: false
            Layout.fillHeight: true

            AlgorithmCard {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                algoKey: root.keys[root.shownIndex]
                algoLabel: root.labels[root.shownIndex]
                about: bridge.algorithmAbout[root.shownIndex]
            }
        }
    }

    // Number keys pick an algorithm directly. A demo runs the same flow many
    // times, and reaching for the mouse on every rehearsal is friction.
    Keys.onPressed: (event) => {
        const n = event.key - Qt.Key_1;
        if (n >= 0 && n < root.keys.length) {
            root.activate(n);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            const count = root.keys.length;
            root.shownIndex = (root.shownIndex + (event.key === Qt.Key_Down ? 1 : count - 1)) % count;
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.proceed();
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab) {
            bridge.compareMode = !bridge.compareMode;
            event.accepted = true;
        } else if (event.key === Qt.Key_T) {
            root.tune(root.keys.indexOf("aars"));
            event.accepted = true;
        }
    }

    // A divider in the same ASCII grammar as a pane title, at label size.
    component SectionRule: RowLayout {
        property string label: ""
        Layout.fillWidth: true
        spacing: Theme.spaceSm

        Text {
            text: "+--- " + parent.label
            color: Theme.textSecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeLabel
            font.weight: Theme.weightBold
            font.letterSpacing: Theme.trackLabel
        }
        Text {
            Layout.fillWidth: true
            text: "-".repeat(80)
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeLabel
            font.letterSpacing: Theme.trackLabel
            elide: Text.ElideNone
            clip: true
        }
    }

    // One algorithm. `modelData` is its index into bridge.algorithmKeys.
    component AlgoRow: Rectangle {
        id: row
        required property int modelData
        readonly property int algoIndex: modelData

        Layout.fillWidth: true
        Layout.preferredHeight: 40

        readonly property string algoKey: root.keys[algoIndex]
        readonly property bool lit: mouse.containsMouse && !tuneButton.lit
        readonly property bool tunable: algoKey === "aars"
        readonly property bool tuned: tunable && bridge.aarsTuned
        // Compare mode: which side, if any, this row has been picked for.
        readonly property string side: !root.compareMode ? ""
                                       : (bridge.compareKeyA === algoKey ? "A"
                                          : (bridge.compareKeyB === algoKey ? "B" : ""))

        color: lit ? Theme.textPrimary : (side !== "" ? Theme.bgPanelRaised : Theme.bgVoid)
        radius: Theme.radiusNone
        border.width: Theme.borderThin
        border.color: lit || side !== "" ? Theme.textPrimary
                                         : (root.shownIndex === algoIndex ? Theme.textSecondary : Theme.borderMuted)

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.shownIndex = row.algoIndex
            onClicked: root.activate(row.algoIndex)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spaceMd
            anchors.rightMargin: Theme.spaceSm
            spacing: Theme.spaceSm

            Text {
                text: (row.algoIndex + 1) + "  > " + root.labels[row.algoIndex].toUpperCase()
                color: row.lit ? Theme.textOnAccent : Theme.textPrimary
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeH1
                font.weight: Theme.weightBold
                font.letterSpacing: Theme.trackH1
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            // A tuned AARS says so on its own row, in the warning hue: those
            // weights are no longer the as-specified formula (AGENTS.md).
            Text {
                visible: row.tuned
                text: "[TUNED]"
                color: row.lit ? Theme.textOnAccent : Theme.accentAmber
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                font.weight: Theme.weightBold
                font.letterSpacing: Theme.trackMicro
            }

            Item { Layout.fillWidth: true }

            // Inverted-video badge (§2.4a) — the side is a word, not a hue.
            Rectangle {
                visible: row.side !== ""
                Layout.preferredWidth: sideLabel.implicitWidth + Theme.spaceSm * 2
                Layout.preferredHeight: sideLabel.implicitHeight + Theme.spaceXs
                color: row.lit ? Theme.textOnAccent : Theme.textPrimary
                radius: Theme.radiusNone
                Text {
                    id: sideLabel
                    anchors.centerIn: parent
                    text: "[" + row.side + "]"
                    color: row.lit ? Theme.textPrimary : Theme.textOnAccent
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeLabel
                    font.weight: Theme.weightBold
                }
            }

            Text {
                text: "--algorithm " + row.algoKey
                color: row.lit ? Theme.textOnAccent : Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                font.letterSpacing: Theme.trackMicro
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            TerminalButton {
                id: tuneButton
                visible: row.tunable
                label: "[ TUNE ]"
                Layout.fillWidth: false
                onClicked: root.tune(row.algoIndex)
                HoverHandler { onHoveredChanged: if (hovered) root.shownIndex = row.algoIndex }
            }
        }
    }
}
