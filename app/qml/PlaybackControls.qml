import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.6 — transport controls. Bracketed labels, inverted-video hover,
// a character-bar scrub track; nothing here glows or pulses (§2.4a: the
// operational UI's only continuous animation is the cursor).
TerminalPane {
    id: root
    property bool isPlaying: false
    property int currentTick: 0
    property int maxTick: 1
    property real speed: 1

    signal playPauseRequested()
    signal stepForwardRequested()
    signal stepBackRequested()
    signal resetRequested()
    signal scrubRequested(int tick)
    signal speedRequested(real s)

    implicitHeight: 90

    // Two rows rather than one: at the ~700px this column gets, a single strip
    // could not hold four transport buttons, four speed toggles, a scrub track
    // and a tick counter, and the layout silently squeezed the last speed
    // toggle off the end. Splitting also lets the scrub bar span the full
    // width, which is what a character bar wants anyway (§2.7(7)).
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.spaceSm
        anchors.bottomMargin: Theme.spaceSm
        spacing: Theme.spaceSm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            TerminalButton {
                label: "[ |< ]"
                Layout.fillWidth: false
                onClicked: root.stepBackRequested()
            }

            TerminalButton {
                label: root.isPlaying ? "[ || PAUSE ]" : "[ > PLAY ]"
                Layout.fillWidth: false
                // Reserve the wider of the two labels so the strip does not
                // shuffle sideways every time playback is toggled.
                Layout.preferredWidth: Theme.charWidth(Theme.sizeLabel) * 13 + Theme.spaceSm * 2
                selected: root.isPlaying
                onClicked: root.playPauseRequested()
            }

            TerminalButton {
                label: "[ >| ]"
                Layout.fillWidth: false
                onClicked: root.stepForwardRequested()
            }

            TerminalButton {
                label: "[ << RESET ]"
                Layout.fillWidth: false
                onClicked: root.resetRequested()
            }

            Item { Layout.fillWidth: true }

            Repeater {
                model: [0.5, 1, 2, 4]
                delegate: TerminalButton {
                    required property real modelData
                    label: "[" + (modelData < 1 ? String(modelData).replace("0.", ".") : modelData) + "x]"
                    Layout.fillWidth: false
                    selected: root.speed === modelData
                    onClicked: root.speedRequested(modelData)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.sizeData + Theme.spaceXs

                AsciiBar {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    fraction: root.maxTick > 0 ? root.currentTick / root.maxTick : 0
                    glyph: "|"
                    emptyGlyph: "·"
                    fillColor: Theme.textPrimary
                    emptyColor: Theme.borderMuted
                    pixelSize: Theme.sizeData
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function scrubAt(x) {
                        const pct = Math.max(0, Math.min(1, x / width));
                        root.scrubRequested(Math.round(pct * root.maxTick));
                    }
                    onPressed: (mouse) => scrubAt(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) scrubAt(mouse.x); }
                }
            }

            // Width-reserved from maxTick's digit count (§3.2) so the number
            // never shifts the scrub track as it counts up.
            Text {
                text: root.currentTick + " / " + root.maxTick
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeData
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.charWidth(Theme.sizeData)
                                       * (String(root.maxTick).length * 2 + 4)
            }
        }
    }
}
