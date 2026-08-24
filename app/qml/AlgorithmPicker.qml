import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.7, step 1 of the pre-dashboard flow. A full screen, not a footer
// control: in the native app the simulation must be chosen before there is
// anything to show, so the picker gets the whole window.
Item {
    id: root
    signal chosen()

    focus: true

    // StackView does not hand active focus to a replaced item on its own.
    Component.onCompleted: root.forceActiveFocus()

    Rectangle { anchors.fill: parent; color: Theme.bgVoid }

    ColumnLayout {
        // Width pinned by explicit x/width rather than a centre anchor — see
        // the note in Splash.qml for why a centre-anchored layout collapses.
        x: Math.max(Theme.spaceXl, (root.width - width) / 2)
        width: Math.min(860, root.width - Theme.spaceXl * 2)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceMd

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            TypewriterText {
                id: heading
                Layout.fillWidth: true
                fullText: "CHOOSE AN ALGORITHM"
                color: Theme.textPrimary
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.sizeH0
                bloomEnabled: true
                bloom: 0.9
                flicker: true
            }

            Text {
                Layout.fillWidth: true
                text: "chronos@aars:~$ chronos --algorithm <name>"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                font.letterSpacing: Theme.trackMicro
            }
        }

        // The five algorithms. Hover inverts the row and reveals its
        // description underneath — the same "explain the load" affordance the
        // workload picker uses, so the two steps behave identically.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            Repeater {
                model: bridge.algorithmLabels

                delegate: Rectangle {
                    id: row
                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: rowContent.implicitHeight + Theme.spaceSm * 2

                    readonly property bool lit: mouse.containsMouse
                    readonly property string algoKey: bridge.algorithmKeys[index]

                    color: lit ? Theme.textPrimary : Theme.bgVoid
                    radius: Theme.radiusNone
                    border.width: Theme.borderThin
                    border.color: lit ? Theme.textPrimary : Theme.borderMuted

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                    ColumnLayout {
                        id: rowContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spaceMd
                        anchors.rightMargin: Theme.spaceMd
                        spacing: Theme.spaceXs

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceSm

                            Text {
                                text: "> " + row.modelData.toUpperCase()
                                color: row.lit ? Theme.textOnAccent : Theme.textPrimary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.sizeH1
                                font.weight: Theme.weightBold
                                font.letterSpacing: Theme.trackH1
                                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "--algorithm " + row.algoKey
                                color: row.lit ? Theme.textOnAccent : Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.sizeMicro
                                font.letterSpacing: Theme.trackMicro
                                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: bridge.algorithmDescriptions[row.index]
                            color: row.lit ? Theme.textOnAccent : Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.sizeBody
                            lineHeight: 1.2
                            wrapMode: Text.WordWrap
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            bridge.selectedAlgorithm = row.algoKey;
                            root.chosen();
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spaceXs
            horizontalAlignment: Text.AlignHCenter
            text: "[1-5] SELECT   //   STEP 1 OF 2"
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            font.letterSpacing: Theme.trackMicro
        }
    }

    // Number keys pick an algorithm directly. A demo runs the same flow many
    // times, and reaching for the mouse on every rehearsal is friction.
    Keys.onPressed: (event) => {
        const n = event.key - Qt.Key_1;
        if (n >= 0 && n < bridge.algorithmKeys.length) {
            bridge.selectedAlgorithm = bridge.algorithmKeys[n];
            root.chosen();
            event.accepted = true;
        }
    }
}
