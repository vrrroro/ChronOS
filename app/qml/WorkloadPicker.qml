import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.7, step 2 of the pre-dashboard flow. The in-app workload browser —
// a ListView over WorkloadListModel, never an OS file dialog (hard constraint
// in CLAUDE.md: a native file sheet breaks both the aesthetic and §1.1's "runs
// inside an OS, not on top of one" framing).
//
// Hovering a row opens a WorkloadCard explaining what kind of load that preset
// puts on the scheduler, so the choice is informed rather than a guess from a
// filename.
Item {
    id: root
    signal runRequested()
    signal backRequested()
    property string selectedPath: ""

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
                    fullText: "CHOOSE A WORKLOAD"
                    color: Theme.textPrimary
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.sizeH0
                    bloomEnabled: true
                    bloom: 0.9
                    flicker: true
                }

                Text {
                    Layout.fillWidth: true
                    text: "chronos@aars:~$ chronos --algorithm "
                          + bridge.selectedAlgorithm + " --workload <file>"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.letterSpacing: Theme.trackMicro
                    elide: Text.ElideRight
                }
            }

            TerminalPane {
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
                        required property int index

                        width: ListView.view.width
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
                                listView.currentIndex = row.index;
                            }
                            onDoubleClicked: {
                                root.selectedPath = row.path;
                                bridge.selectedWorkloadPath = row.path;
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

                Text {
                    text: "DOUBLE-CLICK A ROW TO RUN IT"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.letterSpacing: Theme.trackMicro
                }

                TerminalButton {
                    label: "[ RUN > ]"
                    hPadding: Theme.spaceMd
                    enabledButton: root.selectedPath.length > 0
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

            WorkloadCard {
                id: card
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: opacity > 0
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
                visible: card.opacity === 0

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
        text: "[ENTER] RUN   //   [ESC] BACK   //   STEP 2 OF 2"
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeMicro
        font.letterSpacing: Theme.trackMicro
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
        card.opacity = 1;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.selectedPath.length > 0) root.runRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.backRequested();
            event.accepted = true;
        }
    }
}
