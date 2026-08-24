import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.5 — the waiting/aging indicator. Shows how much each waiting
// process has accumulated toward being rescued from starvation.
TerminalPane {
    id: root
    property var entries: []

    // Ticks of waiting the bar is scaled against. Purely a display scale for
    // the meter — the actual aging bonus comes from the engine, and nothing
    // here feeds back into scheduling.
    readonly property int barScale: 30

    title: "AGING"
    accentColor: Theme.accentAmber

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spaceXs

        RowLayout {
            visible: root.entries.length === 0
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Text {
                text: "> no aging bonus accruing"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeBody
            }
            BlinkingCursor { color: Theme.textDim; font.pixelSize: Theme.sizeBody }
            Item { Layout.fillWidth: true }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.entries
            spacing: Theme.spaceXs

            delegate: RowLayout {
                id: entry
                required property var modelData
                width: ListView.view.width
                height: Theme.sizeData + Theme.spaceXs
                spacing: Theme.spaceSm

                readonly property bool warning: modelData.aboveThreshold

                Text {
                    text: Theme.procGlyph(entry.modelData.pid)
                    color: Theme.procShade(entry.modelData.pid)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeData
                    Layout.preferredWidth: Theme.charWidth(Theme.sizeData)
                }

                Text {
                    text: "P" + entry.modelData.pid
                    color: Theme.textSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeData
                    Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * 4
                }

                AsciiBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.sizeData
                    fraction: entry.modelData.waitSoFar / root.barScale
                    glyph: "|"
                    fillColor: entry.warning ? Theme.accentAmber : Theme.textSecondary
                    pixelSize: Theme.sizeData
                }

                // Amber never carries meaning alone (§2.6) — the badge is what
                // a viewer who cannot separate the hues reads instead.
                Text {
                    visible: entry.warning
                    text: "[WARN]"
                    color: Theme.accentAmber
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.weight: Theme.weightSemiBold
                    Layout.preferredWidth: visible ? Theme.charWidth(Theme.sizeMicro) * 7 : 0
                }

                Text {
                    text: "+" + Number(entry.modelData.bonus).toFixed(1)
                    color: Theme.accentPositive
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeData
                    font.weight: Theme.weightBold
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * 6
                }
            }
        }
    }
}
