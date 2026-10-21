import QtQuick
import QtQuick.Layouts
import ChronOS

// The compare screen's verdict (EDRD §5.11, revised 2026-10-22 at explicit
// user request): a popup, opened from [ VERDICT ] beside the scrub bar once
// both runs have finished. Top to bottom it answers the question in the order
// a viewer asks it — who won, the metric-by-metric scoreboard, and what each
// side is better at. A loss is listed as plainly as a win (PRD §2.4).
//
// [ _ MINIMIZE ] (or Esc, or a click outside) shrinks it back into the
// button it came from, so the rest of the screen can be read; the button
// brings it back. It never covers the screen while playback is still running:
// the compare view closes it the moment the playhead leaves the end.
//
// Fill this whole screen with it: the window centres itself, and `dockX` /
// `dockY` (the button's centre, in this item's coordinates) is where it
// shrinks to and grows from.
Item {
    id: root

    property var comparison: ({})
    property string workloadName: ""
    property bool open: false
    property real dockX: width / 2
    property real dockY: height
    signal minimizeRequested()

    readonly property int winsA: comparison.winsA || 0
    readonly property int winsB: comparison.winsB || 0
    readonly property int ties: comparison.ties || 0
    readonly property int total: comparison.total || 0
    readonly property string nameA: comparison.nameA || "A"
    readonly property string nameB: comparison.nameB || "B"
    readonly property string headline: winsA > winsB ? "[A] " + nameA.toUpperCase() + " WINS"
                                     : winsB > winsA ? "[B] " + nameB.toUpperCase() + " WINS"
                                                     : "EVEN — NEITHER WINS MORE METRICS"

    visible: window.opacity > 0.01

    onOpenChanged: if (open) scoreboard.reveal()

    // The screen behind stays readable but steps back; a click on it is the
    // same as minimizing. Plain void at partial opacity — no blur, no tint.
    Rectangle {
        anchors.fill: parent
        color: Theme.bgVoid
        opacity: root.open ? 0.82 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            acceptedButtons: Qt.AllButtons
            onClicked: root.minimizeRequested()
            onWheel: (wheel) => { wheel.accepted = true; }
        }
    }

    Rectangle {
        id: window
        width: Math.min(root.width - Theme.spaceXl * 2, 900)
        // As tall as its content, capped by the screen (the scoreboard
        // then scrolls).
        height: Math.min(root.height - Theme.spaceXl * 2,
                         titleBar.height + content.implicitHeight + Theme.spaceMd * 2)
        color: Theme.bgVoid
        radius: Theme.radiusNone
        border.width: Theme.borderThin
        border.color: Theme.textPrimary

        // Grows out of the button and shrinks back into it.
        x: root.open ? (root.width - width) / 2 : root.dockX - width / 2
        y: root.open ? (root.height - height) / 2 : root.dockY - height / 2
        scale: root.open ? 1 : 0.05
        opacity: root.open ? 1 : 0
        Behavior on x { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

        // Swallow clicks so they never reach the scrim underneath.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        // Title bar — inverted, the §2.7(3) treatment for a title that needs
        // more emphasis than the dashed rule: this is the one pane on screen.
        Rectangle {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.sizeH1 + Theme.spaceSm * 2 + Theme.spaceXs
            color: Theme.textPrimary
            radius: Theme.radiusNone

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceMd
                anchors.right: minimize.left
                anchors.rightMargin: Theme.spaceMd
                anchors.verticalCenter: parent.verticalCenter
                text: "VERDICT  //  " + root.workloadName.toUpperCase()
                color: Theme.textOnAccent
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeH1
                font.weight: Theme.weightBold
                font.letterSpacing: Theme.trackH1
                elide: Text.ElideRight
            }

            TerminalButton {
                id: minimize
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceXs
                anchors.verticalCenter: parent.verticalCenter
                label: "[ _ MINIMIZE ]"
                onClicked: root.minimizeRequested()
            }
        }

        ColumnLayout {
            id: content
            anchors.top: titleBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spaceMd
            spacing: Theme.spaceSm

            // Who won. Mono, not the display serif: §3.1 allows Instrument
            // Serif in four places and this is not one of them. Typed in once
            // per opening (§2.7(9)) — a verdict line, not tick data.
            TypewriterText {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.sizeH1 + 6 + Theme.spaceSm
                fullText: root.open ? root.headline : ""
                color: Theme.textPrimary
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeH1 + 6
                font.weight: Theme.weightExtraBold
                bloomEnabled: true
            }

            Text {
                Layout.fillWidth: true
                text: "[A] " + root.winsA + "  ·  [B] " + root.winsB + "  ·  TIED " + root.ties
                      + "   (of " + root.total + " metrics, same processes)"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                font.letterSpacing: Theme.trackMicro
                elide: Text.ElideRight
            }

            Scoreboard {
                id: scoreboard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: implicitHeight
                Layout.minimumHeight: 160
                comparison: root.comparison
            }

            // Which one is better at what — the finding, not the tally.
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                spacing: Theme.spaceLg

                Better {
                    sideLabel: "A"
                    name: root.nameA
                    items: root.comparison.betterA || []
                }
                Better {
                    sideLabel: "B"
                    name: root.nameB
                    items: root.comparison.betterB || []
                }
            }
        }
    }

    // "<name> IS BETTER AT n" and the metrics, wrapped. The +/− sign carries
    // the meaning (§2.6); an empty list is said in words.
    component Better: ColumnLayout {
        id: better
        property string sideLabel: "A"
        property string name: ""
        property var items: []
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm
            Text {
                text: better.items.length > 0 ? "+" : "−"
                color: better.items.length > 0 ? Theme.accentPositive : Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeBody
                font.weight: Theme.weightBold
            }
            Text {
                Layout.fillWidth: true
                text: "[" + better.sideLabel + "] " + better.name.toUpperCase()
                      + " IS BETTER AT " + better.items.length
                color: Theme.textPrimary
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeLabel
                font.weight: Theme.weightBold
                font.letterSpacing: Theme.trackLabel
                elide: Text.ElideRight
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.charWidth(Theme.sizeBody) + Theme.spaceSm
            // Non-breaking spaces inside each metric name, so a line only
            // ever breaks between metrics ("worst waiting", never "worst /
            // waiting").
            text: better.items.length > 0
                  ? better.items.map(m => m.toLowerCase().replace(/ /g, " ")).join("  ·  ")
                  : "no metric"
            color: better.items.length > 0 ? Theme.textSecondary : Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            lineHeight: 1.2
            wrapMode: Text.WordWrap
        }
    }
}
