import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.5 — the waiting/aging indicator. Shows how much each waiting
// process has accumulated toward being rescued from starvation.
//
// Algorithm-aware since 2026-10-22: the bridge says how *this* algorithm turns
// waiting into a better chance of running — AARS's (possibly tuned) aging
// term, Priority's +1 per 5 ticks, MLFQ's periodic boost — or that it has no
// such mechanism at all (FCFS, SJF, RR, CFS), in which case the panel is titled
// WAITING and shows waits only. Previously it applied AARS's default formula
// to every algorithm, which was wrong for all of them but one.
TerminalPane {
    id: root
    // { title, status, hasBonus, entries: [{pid, waitSoFar, bonus, aboveThreshold}] }
    property var info: ({})

    readonly property var entries: info && info.entries ? info.entries : []
    readonly property bool hasBonus: info && info.hasBonus === true

    // Ticks of waiting the bar is scaled against. Purely a display scale for
    // the meter — nothing here feeds back into scheduling.
    readonly property int barScale: 30

    title: info && info.title ? info.title : "AGING"
    statusText: info && info.status ? info.status : ""

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spaceXs

        RowLayout {
            visible: root.entries.length === 0
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Text {
                text: root.hasBonus ? "> no aging bonus accruing" : "> nothing waiting"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeBody
            }
            BlinkingCursor { color: Theme.textDim; font.pixelSize: Theme.sizeBody }
            Item { Layout.fillWidth: true }
        }

        ListView {
            id: agingList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.entries
            spacing: Theme.spaceXs

            NeonScrollBar { id: agingBar; flickable: agingList }

            delegate: RowLayout {
                id: entry
                required property var modelData
                width: ListView.view.width - agingBar.gutter
                height: Theme.sizeData + Theme.spaceXs
                spacing: Theme.spaceSm

                readonly property bool warning: modelData.aboveThreshold

                Text {
                    text: "P" + entry.modelData.pid
                    color: Theme.procShade(entry.modelData.pid)
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

                // The bonus where the algorithm has one; otherwise the wait
                // itself, since that is all there is to report.
                Text {
                    text: root.hasBonus ? "+" + Number(entry.modelData.bonus).toFixed(1)
                                        : entry.modelData.waitSoFar + "t"
                    color: root.hasBonus ? Theme.accentPositive : Theme.textSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeData
                    font.weight: root.hasBonus ? Theme.weightBold : Theme.weightRegular
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * 6
                }
            }
        }
    }
}
