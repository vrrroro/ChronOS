import QtQuick
import QtQuick.Layouts
import ChronOS

// The compare screen's metric table (EDRD §5.11, added 2026-10-22): every
// metric from engine/comparison.cpp for run A and run B, and which is better.
//
// Lives inside the verdict popup, which only opens once both runs have
// finished — so there is no pending state here any more. Each time the popup
// opens, the rows reveal in reading order (the one-time fade-and-rise of §6.7,
// not a per-tick animation); call reveal() to play it.
TerminalPane {
    id: root

    property var comparison: ({})

    readonly property var rows: comparison && comparison.rows ? comparison.rows : []
    property string hoveredMeaning: ""

    // Winner badge and value emphasis are words and weight, never hue alone.
    readonly property int valueCells: 8
    readonly property int winCells: 4

    signal revealRequested()
    function reveal() { revealRequested(); }

    title: "SCOREBOARD"
    active: true
    statusText: "A = " + (comparison.nameA || "") + "  //  B = " + (comparison.nameB || "")

    // True when both metrics that cannot differ between work-conserving
    // schedulers did, as expected, tie — worth one line of explanation.
    readonly property bool utilTied: {
        for (let i = 0; i < rows.length; ++i) {
            if ((rows[i].key === "cpuUtilization" || rows[i].key === "throughput") && rows[i].winner !== -1)
                return false;
        }
        return rows.length > 0;
    }

    // Sized to its rows, so the popup holding it has no dead space: title bar
    // + body + status strip, as TerminalPane lays them out.
    implicitHeight: Theme.sizeH1 + Theme.spaceSm * 2 + body.implicitHeight + Theme.spaceSm
                    + Theme.sizeMicro + Theme.spaceSm * 2 + Theme.borderThin * 2

    ColumnLayout {
        id: body
        anchors.fill: parent
        spacing: Theme.spaceXs

        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: rowsBar.gutter
            spacing: Theme.spaceSm
            Header { text: "METRIC"; Layout.fillWidth: true; horizontalAlignment: Text.AlignLeft }
            Header { text: "A"; Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * root.valueCells }
            Header { text: "B"; Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * root.valueCells }
            Header { text: "WIN"; Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * root.winCells }
        }

        Text {
            Layout.fillWidth: true
            text: "-".repeat(Math.max(8, Math.floor(root.width / Theme.charWidth(Theme.sizeMicro)) - 4))
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            elide: Text.ElideRight
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: contentHeight
            Layout.minimumHeight: 60
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows

            NeonScrollBar { id: rowsBar; flickable: list }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                width: ListView.view.width - rowsBar.gutter
                height: Theme.sizeData + Theme.spaceXs + 2
                color: hover.hovered ? Theme.bgPanelRaised : "transparent"
                radius: Theme.radiusNone
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                readonly property int winner: modelData.winner
                // Units short enough to sit in the cell; the rest are ticks
                // or plain counts, which the hover line spells out.
                readonly property string suffix: modelData.unit === "%" || modelData.unit === "x"
                                                 ? modelData.unit : ""
                property real reveal: 1

                // Staggered by row, once per reveal().
                SequentialAnimation {
                    id: revealAnim
                    PropertyAction { target: row; property: "reveal"; value: 0 }
                    PauseAnimation { duration: 120 + row.index * 40 }
                    NumberAnimation {
                        target: row; property: "reveal"; to: 1
                        duration: Theme.durationSlow; easing.type: Easing.OutCubic
                    }
                }
                Connections {
                    target: root
                    function onRevealRequested() { revealAnim.restart(); }
                }

                HoverHandler {
                    id: hover
                    onHoveredChanged: {
                        if (hovered) root.hoveredMeaning = row.modelData.label.toLowerCase() + ": "
                                                          + row.modelData.meaning;
                        else if (root.hoveredMeaning.indexOf(row.modelData.label.toLowerCase()) === 0)
                            root.hoveredMeaning = "";
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spaceSm

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.label
                        color: Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.sizeMicro
                        font.letterSpacing: Theme.trackMicro
                        elide: Text.ElideRight
                    }

                    Value { value: row.modelData.a + row.suffix; wins: row.winner === 0; reveal: row.reveal }
                    Value { value: row.modelData.b + row.suffix; wins: row.winner === 1; reveal: row.reveal }

                    // Winner as an inverted-video badge — the same [A]/[B]
                    // the algorithm picker uses — or TIE in dim.
                    Item {
                        Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * root.winCells
                        Layout.preferredHeight: Theme.sizeData + 2
                        opacity: row.reveal

                        Rectangle {
                            visible: row.winner !== -1
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: badge.implicitWidth + Theme.spaceXs * 2
                            height: badge.implicitHeight
                            color: Theme.textPrimary
                            radius: Theme.radiusNone
                            Text {
                                id: badge
                                anchors.centerIn: parent
                                text: row.winner === 0 ? "[A]" : "[B]"
                                color: Theme.textOnAccent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.sizeMicro
                                font.weight: Theme.weightBold
                            }
                        }
                        Text {
                            visible: row.winner === -1
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TIE"
                            color: Theme.textDim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.sizeMicro
                            font.weight: Theme.weightBold
                        }
                    }
                }

            }
        }

        // What the hovered metric measures, or why two of them always tie.
        // Fixed height so the table above never jumps.
        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.sizeMicro * 2 + Theme.spaceXs * 2
            verticalAlignment: Text.AlignTop
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: root.hoveredMeaning.length > 0 ? "> " + root.hoveredMeaning
                  : (root.utilTied
                     ? "> cpu utilization + throughput tie: every scheduler here keeps the cpu busy whenever work is waiting"
                     : "> hover a metric for what it measures")
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
        }
    }

    // One value cell: the better side bold primary, the other plain secondary.
    component Value: Text {
        property string value: ""
        property bool wins: false
        property real reveal: 1
        Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * root.valueCells
        horizontalAlignment: Text.AlignRight
        text: value
        color: wins ? Theme.textPrimary : Theme.textSecondary
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeData
        font.weight: wins ? Theme.weightBold : Theme.weightRegular
        opacity: reveal
        transform: Translate { y: 6 * (1 - reveal) }
    }

    component Header: Text {
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeLabel
        font.weight: Theme.weightSemiBold
        font.letterSpacing: Theme.trackLabel
        horizontalAlignment: Text.AlignRight
    }
}
