import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.7, step 2 of the pre-dashboard flow. The in-app workload browser —
// a ListView over WorkloadListModel, never an OS file dialog (hard constraint
// in AGENTS.md: a native file sheet breaks both the aesthetic and §1.1's "runs
// inside an OS, not on top of one" framing).
//
// Hovering a row opens a WorkloadCard explaining what kind of load that preset
// puts on the scheduler, so the choice is informed rather than a guess from a
// filename.
Item {
    id: root
    signal runRequested()
    signal backRequested()
    // Starts on the last workload run, so a repeat run is one keypress.
    property string selectedPath: bridge.selectedWorkloadPath
    // Custom mode (2026-10-16): the list is swapped for the workload builder,
    // and the card on the right describes what the builder will generate.
    readonly property bool customMode: bridge.useCustomWorkload
    readonly property bool canRun: customMode ? bridge.customSpec.total > 0
                                              : selectedPath.length > 0

    focus: true

    // StackView does not hand active focus to a replaced item on its own.
    Component.onCompleted: root.forceActiveFocus()

    Rectangle { anchors.fill: parent; color: Theme.bgVoid }

    RowLayout {
        x: Math.max(Theme.spaceXl, (root.width - width) / 2)
        y: Math.max(Theme.spaceLg, (root.height - height) / 2)
        width: Math.min(1080, root.width - Theme.spaceXl * 2)
        height: Math.min(600, root.height - Theme.spaceXl * 2 - Theme.spaceLg)
        spacing: Theme.spaceLg

        // Left: heading + list --------------------------------------------
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
                    fullText: root.customMode ? "BUILD A WORKLOAD" : "CHOOSE A WORKLOAD"
                    color: Theme.textPrimary
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.sizeH0
                    bloomEnabled: true
                    bloom: 0.9
                    flicker: true
                }

                Text {
                    Layout.fillWidth: true
                    text: "chronos@aars:~$ chronos "
                          + (bridge.compareMode ? "--compare " + bridge.compareKeyA + "," + bridge.compareKeyB
                                                : "--algorithm " + bridge.selectedAlgorithm)
                          + (root.customMode ? " --workload custom:" + bridge.customSpec.name
                                             : " --workload <file>")
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
                    label: "[ PRESETS ]"
                    selected: !root.customMode
                    onClicked: bridge.useCustomWorkload = false
                }
                TerminalButton {
                    label: "[ + CUSTOM ]"
                    selected: root.customMode
                    onClicked: bridge.useCustomWorkload = true
                }
                Item { Layout.fillWidth: true }
            }

            TerminalPane {
                visible: root.customMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "CUSTOM WORKLOAD"
                statusText: bridge.customSpec.total > 0
                            ? "READY: " + bridge.customSpec.total + " PROCESSES  //  PRESS RUN"
                            : "ADD AT LEAST ONE PROCESS TO RUN"
                active: bridge.customSpec.total > 0

                CustomWorkloadEditor { anchors.fill: parent }
            }

            TerminalPane {
                visible: !root.customMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "WORKLOADS"
                statusText: root.selectedPath.length > 0
                            ? "SELECTED: " + root.selectedPath
                            : "NO SELECTION — HOVER A ROW FOR DETAIL"
                active: root.selectedPath.length > 0

                ListView {
                    id: listView
                    anchors.fill: parent
                    clip: true
                    model: bridge.workloadModel
                    currentIndex: -1
                    spacing: 0

                    NeonScrollBar { id: listBar; flickable: listView }

                    delegate: Rectangle {
                        id: row
                        required property string name
                        required property string path
                        required property string description
                        required property string profile
                        required property int processCount
                        required property int quantum
                        required property int totalBurst
                        required property string avgBurst
                        required property int minBurst
                        required property int maxBurst
                        required property int arrivalSpan
                        required property int priorityMin
                        required property int priorityMax
                        required property string loadFactor
                        required property string schedulerNote
                        required property int index

                        width: ListView.view.width - listBar.gutter
                        height: 40
                        color: mouse.containsMouse ? Theme.bgPanelRaised : "transparent"
                        radius: Theme.radiusNone

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        readonly property bool isSelected: root.selectedPath === path

                        // Selection stripe (§5.3 row treatment).
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 2
                            color: row.isSelected ? Theme.textPrimary : "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spaceMd
                            anchors.rightMargin: Theme.spaceSm
                            spacing: Theme.spaceSm

                            Text {
                                text: row.isSelected ? ">" : " "
                                color: Theme.textPrimary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.sizeData
                                font.weight: Theme.weightBold
                                Layout.preferredWidth: Theme.charWidth(Theme.sizeData)
                            }

                            Text {
                                text: row.name
                                color: row.isSelected || mouse.containsMouse
                                       ? Theme.textPrimary : Theme.textSecondary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.sizeData
                                font.weight: row.isSelected ? Theme.weightBold : Theme.weightMedium
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Fixed-width numeric cell (§3.2) so the count
                            // never shifts the columns around it.
                            Text {
                                text: row.processCount + "p"
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.sizeMicro
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: Theme.charWidth(Theme.sizeMicro) * 4
                            }

                            Text {
                                text: "[" + row.profile + "]"
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.sizeMicro
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: Theme.charWidth(Theme.sizeMicro) * 14
                            }
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: root.showCard(row)
                            onClicked: {
                                root.selectedPath = row.path;
                                bridge.selectedWorkloadPath = row.path;
                                bridge.useCustomWorkload = false;
                                listView.currentIndex = row.index;
                            }
                            onDoubleClicked: {
                                root.selectedPath = row.path;
                                bridge.selectedWorkloadPath = row.path;
                                bridge.useCustomWorkload = false;
                                root.runRequested();
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

                Item { Layout.fillWidth: true }

                // A failed run (unreadable file, invalid workload) says why
                // here, as shell output, instead of silently staying put.
                Text {
                    Layout.maximumWidth: 360
                    elide: Text.ElideRight
                    text: bridge.errorMessage.length > 0 ? "[ERR] " + bridge.errorMessage
                          : (root.customMode ? "THE CARD DESCRIBES EXACTLY WHAT WILL RUN"
                                             : "DOUBLE-CLICK A ROW TO RUN IT")
                    color: bridge.errorMessage.length > 0 ? Theme.accentError : Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.letterSpacing: Theme.trackMicro
                }

                TerminalButton {
                    // Compare mode runs both chosen algorithms on this one
                    // workload and opens the side-by-side screen instead.
                    label: bridge.compareMode ? "[ COMPARE > ]" : "[ RUN > ]"
                    hPadding: Theme.spaceMd
                    enabledButton: root.canRun
                    onClicked: root.runRequested()
                }
            }
        }

        // Right: the hover card -------------------------------------------
        Item {
            Layout.preferredWidth: 380
            Layout.minimumWidth: 380
            Layout.maximumWidth: 380
            Layout.fillWidth: false
            Layout.fillHeight: true

            // Custom mode: always shown, redrawn live from what the builder
            // generates — every edit on the left updates it.
            WorkloadCard {
                id: customCard
                readonly property var sum: bridge.customSummary
                visible: root.customMode
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                workloadName: sum.name || "Custom Workload"
                statusOverride: "--workload custom  //  seed " + bridge.customSpec.seed
                description: sum.description || ""
                profile: sum.profile || "EMPTY"
                processCount: sum.processCount || 0
                quantum: sum.quantum || 0
                totalBurst: sum.totalBurst || 0
                avgBurst: sum.avgBurst || "0.0"
                minBurst: sum.minBurst || 0
                maxBurst: sum.maxBurst || 0
                arrivalSpan: sum.arrivalSpan || 0
                priorityMin: sum.priorityMin || 0
                priorityMax: sum.priorityMax || 0
                loadFactor: sum.loadFactor || "0.0"
                schedulerNote: sum.schedulerNote || ""
                composition: sum.composition || []
                processes: sum.processes || []
            }

            WorkloadCard {
                id: card
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: !root.customMode && opacity > 0
                opacity: 0

                Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
            }

            // Resting state, before anything has been hovered. Shell output
            // rather than a blank panel — an empty right column reads as a
            // rendering bug (which is exactly what issue #16 turned out to be).
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Theme.spaceLg
                spacing: Theme.spaceSm
                visible: !root.customMode && card.opacity === 0

                RowLayout {
                    spacing: Theme.spaceXs
                    Text {
                        text: "> hover a workload for detail"
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.sizeBody
                    }
                    BlinkingCursor { color: Theme.textDim; font.pixelSize: Theme.sizeBody }
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceSm
        text: (bridge.compareMode ? "[ENTER] COMPARE   //" : "[ENTER] RUN   //") + "   [↑↓] SELECT   //   [TAB] PRESETS / CUSTOM   //   [ESC] BACK   //   STEP 2 OF 2"
        // The custom card is tall enough to reach this line; the RUN row
        // already carries the hint in custom mode.
        visible: !root.customMode
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeMicro
        font.letterSpacing: Theme.trackMicro
    }

    // Keyboard selection (↑/↓), so the whole flow runs without a mouse —
    // the algorithm step already works that way.
    function selectIndex(i) {
        if (listView.count === 0) return;
        listView.currentIndex = Math.max(0, Math.min(listView.count - 1, i));
        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
        const item = listView.currentItem;
        if (!item) return;
        root.selectedPath = item.path;
        bridge.selectedWorkloadPath = item.path;
        root.showCard(item);
    }

    function showCard(row) {
        card.workloadName = row.name;
        card.description = row.description;
        card.profile = row.profile;
        card.processCount = row.processCount;
        card.quantum = row.quantum;
        card.totalBurst = row.totalBurst;
        card.avgBurst = row.avgBurst;
        card.minBurst = row.minBurst;
        card.maxBurst = row.maxBurst;
        card.arrivalSpan = row.arrivalSpan;
        card.priorityMin = row.priorityMin;
        card.priorityMax = row.priorityMax;
        card.loadFactor = row.loadFactor;
        card.schedulerNote = row.schedulerNote;
        card.opacity = 1;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.canRun) root.runRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.backRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab) {
            bridge.useCustomWorkload = !bridge.useCustomWorkload;
            event.accepted = true;
        } else if (!root.customMode && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
            root.selectIndex(listView.currentIndex + (event.key === Qt.Key_Down ? 1 : -1));
            event.accepted = true;
        }
    }
}
