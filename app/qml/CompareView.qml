import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.11 — the compare screen (added 2026-10-22, explicit user
// request). Two algorithms, the same processes, played side by side on one
// clock, each explaining its own decisions as it goes; once both have
// finished, [ VERDICT ] beside the scrub bar opens a popup saying which is
// better at what.
//
// Built entirely from the dashboard's own parts — GanttChart, TickBar,
// WhyPanel, PlaybackControls, StatTile, TerminalPane — so it moves and reads
// exactly like the screen it is a variant of. Both timelines share one
// maxTick, so their time axes line up tick for tick and a viewer can read
// down from A to B.
Item {
    id: root
    signal restartRequested()

    property int currentTick: 0
    property bool isPlaying: false
    property real speed: 1
    readonly property int maxTick: bridge.cmpMaxTick
    readonly property real ticksPerSecond: Theme.baseTicksPerSecond * speed
    readonly property bool finished: currentTick >= maxTick
    readonly property var cmp: bridge.comparison
    readonly property string nameA: cmp.nameA || ""
    readonly property string nameB: cmp.nameB || ""
    readonly property int processCount: bridge.cmpProcessCount
    property bool verdictOpen: false

    // The verdict describes finished runs; leaving the end closes it.
    onFinishedChanged: if (!finished) verdictOpen = false

    focus: true
    Component.onCompleted: root.forceActiveFocus()

    Rectangle { anchors.fill: parent; color: Theme.bgVoid }

    Timer {
        interval: Math.max(16, 1000 / root.ticksPerSecond)
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.currentTick >= root.maxTick) root.isPlaying = false;
            else root.currentTick += 1;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
        spacing: Theme.spaceSm

        // Top bar ------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceLg

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                // The dashboard title lockup (§3.1 place 2) — this screen is
                // the dashboard's comparison variant, not a fifth display use.
                PhosphorText {
                    Layout.fillWidth: false
                    Layout.fillHeight: false
                    text: "CHRONOS"
                    color: Theme.textPrimary
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.sizeH0
                    bloom: 1.0
                    flicker: true
                }

                Text {
                    Layout.fillWidth: true
                    text: "$ chronos --compare " + (root.cmp.keyA || "") + "," + (root.cmp.keyB || "")
                          + " --workload " + (bridge.useCustomWorkload ? "custom:" : "")
                          + bridge.cmpWorkloadName
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.letterSpacing: Theme.trackMicro
                    elide: Text.ElideRight
                }
            }

            // The same measure for both sides, so the same hue: these are
            // read against each other, which is exactly what §2.5's "three
            // hues for three measures" rule wants kept apart elsewhere.
            StatTile {
                label: "A DONE"
                value: bridge.cmpDoneAt(0, root.currentTick) + "/" + root.processCount
                cells: 5
            }
            StatTile {
                label: "B DONE"
                value: bridge.cmpDoneAt(1, root.currentTick) + "/" + root.processCount
                cells: 5
            }
            StatTile {
                label: "A SWITCHES"
                value: bridge.cmpSwitchesAt(0, root.currentTick)
                cells: 5
                accent: Theme.accentMagenta
            }
            StatTile {
                label: "B SWITCHES"
                value: bridge.cmpSwitchesAt(1, root.currentTick)
                cells: 5
                accent: Theme.accentMagenta
            }

            TerminalButton {
                label: "[ NEW RUN ]"
                hPadding: Theme.spaceMd
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.restartRequested()
            }
        }

        Text {
            Layout.fillWidth: true
            text: "=".repeat(Math.max(8, Math.floor(root.width / Theme.charWidth(Theme.sizeMicro))))
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            elide: Text.ElideRight
        }

        // Panels -------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spaceMd

            // Same explicit sizing as the dashboard's left column, for the
            // same reason (issue #15): a nested layout of zero-implicit-width
            // panes otherwise collapses to nothing.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 700
                Layout.minimumWidth: 460
                Layout.fillHeight: true
                spacing: Theme.spaceMd

                GanttChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 112
                    Layout.minimumHeight: 100
                    title: "A // " + root.nameA.toUpperCase()
                    segments: bridge.cmpGanttSegments(0)
                    currentTick: root.currentTick
                    maxTick: root.maxTick
                    ticksPerSecond: root.ticksPerSecond
                }

                GanttChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 112
                    Layout.minimumHeight: 100
                    title: "B // " + root.nameB.toUpperCase()
                    segments: bridge.cmpGanttSegments(1)
                    currentTick: root.currentTick
                    maxTick: root.maxTick
                    ticksPerSecond: root.ticksPerSecond
                }

                // Dual process ticker ------------------------------------------
                TerminalPane {
                    id: ticker
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 110
                    title: "PROCESS PROGRESS  A | B"

                    readonly property int pidCells: 4
                    readonly property int readoutCells: 6

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spaceXs

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.rightMargin: cmpBar.gutter
                            spacing: Theme.spaceSm
                            Item { Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * ticker.pidCells }
                            ColumnHead { text: "[A] " + root.nameA.toUpperCase() }
                            Item { Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * ticker.readoutCells }
                            ColumnHead { text: "[B] " + root.nameB.toUpperCase() }
                            Item { Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * ticker.readoutCells }
                        }

                        ListView {
                            id: cmpList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: Theme.spaceXs
                            boundsBehavior: Flickable.StopAtBounds

                            NeonScrollBar { id: cmpBar; flickable: cmpList }

                            // Bound to the stable process count, each row
                            // pulling its own data — the same delegate-churn
                            // fix ProcessTicker uses (AGENTS.md GUI rules), so
                            // the TickBars keep their state across ticks.
                            model: root.processCount

                            delegate: Item {
                                id: row
                                required property int index
                                readonly property var d: bridge.cmpTickerRowAt(root.currentTick, index)
                                readonly property bool valid: d.pid !== undefined
                                readonly property color hue: valid ? Theme.procShade(d.pid) : Theme.textDim

                                width: ListView.view.width - cmpBar.gutter
                                height: Theme.sizeData + Theme.spaceXs
                                opacity: d.arrived === true ? 1.0 : 0.3
                                Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.spaceSm

                                    Text {
                                        text: row.valid ? "P" + row.d.pid : ""
                                        color: row.hue
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.sizeData
                                        font.weight: row.d.aRunning || row.d.bRunning ? Theme.weightBold
                                                                                      : Theme.weightMedium
                                        Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * ticker.pidCells
                                    }

                                    TickBar {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Theme.sizeData
                                        fraction: (row.d.aPct || 0) / 100
                                        fillColor: row.hue
                                        active: row.d.aRunning === true
                                        pixelSize: Theme.sizeData
                                        stepBudget: Math.min(900, 650 / root.ticksPerSecond)
                                    }
                                    Readout {
                                        done: row.d.aDone === true
                                        running: row.d.aRunning === true
                                        pct: row.d.aPct || 0
                                        hue: row.hue
                                    }

                                    TickBar {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Theme.sizeData
                                        fraction: (row.d.bPct || 0) / 100
                                        fillColor: row.hue
                                        active: row.d.bRunning === true
                                        pixelSize: Theme.sizeData
                                        stepBudget: Math.min(900, 650 / root.ticksPerSecond)
                                    }
                                    Readout {
                                        done: row.d.bDone === true
                                        running: row.d.bRunning === true
                                        pct: row.d.bPct || 0
                                        hue: row.hue
                                    }
                                }
                            }
                        }
                    }
                }

                PlaybackControls {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 100
                    isPlaying: root.isPlaying
                    currentTick: root.currentTick
                    maxTick: root.maxTick
                    speed: root.speed
                    onPlayPauseRequested: root.togglePlay()
                    onStepForwardRequested: root.stepForward()
                    onStepBackRequested: root.stepBack()
                    onResetRequested: root.reset()
                    onScrubRequested: (tick) => { root.isPlaying = false; root.currentTick = tick; }
                    onSpeedRequested: (s) => { root.speed = s; }

                    // Skips to the end while the runs are still going; once
                    // both have finished it becomes the way into the verdict,
                    // lit in inverted video so the end of the run is
                    // unmistakable. Width reserved for the longer label.
                    scrubTrailing: TerminalButton {
                        id: verdictButton
                        label: root.finished ? "[ VERDICT ]" : "[ >>| END ]"
                        selected: root.finished && !root.verdictOpen
                        Layout.fillWidth: false
                        Layout.preferredWidth: Theme.charWidth(Theme.sizeLabel) * 13 + Theme.spaceSm * 2
                        Layout.preferredHeight: Theme.sizeData + Theme.spaceSm + 4
                        onClicked: root.finished ? root.toggleVerdict() : root.skipToEnd()
                    }
                }
            }

            // Each side explains its own latest decision, exactly as the
            // dashboard's why-panel does — the same component, fed per side.
            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 400
                Layout.minimumWidth: 400
                Layout.maximumWidth: 400
                Layout.fillHeight: true
                spacing: Theme.spaceMd

                WhyPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 1
                    title: "A // WHY  " + root.nameA.toUpperCase()
                    panelData: bridge.cmpWhyPanelAt(0, root.currentTick)
                }

                WhyPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 1
                    title: "B // WHY  " + root.nameB.toUpperCase()
                    panelData: bridge.cmpWhyPanelAt(1, root.currentTick)
                }
            }
        }
    }

    // Above everything but the scanlines (which Main.qml layers on top).
    VerdictPopup {
        id: verdict
        anchors.fill: parent
        z: 600
        comparison: root.cmp
        workloadName: bridge.cmpWorkloadName
        open: root.verdictOpen
        onMinimizeRequested: root.toggleVerdict()
    }

    function togglePlay() {
        // Pressing play at the end starts over rather than doing nothing.
        if (!isPlaying && currentTick >= maxTick) currentTick = 0;
        isPlaying = !isPlaying;
    }
    function stepForward() { isPlaying = false; currentTick = Math.min(maxTick, currentTick + 1); }
    function stepBack() { isPlaying = false; currentTick = Math.max(0, currentTick - 1); }
    function reset() { isPlaying = false; currentTick = 0; }
    function skipToEnd() { isPlaying = false; currentTick = maxTick; }

    // Docks the popup on the button before every open or minimize, so it
    // always grows out of — and shrinks back into — where the button is now.
    function toggleVerdict() {
        if (!finished) return;
        const c = verdictButton.mapToItem(root, verdictButton.width / 2, verdictButton.height / 2);
        verdict.dockX = c.x;
        verdict.dockY = c.y;
        verdictOpen = !verdictOpen;
    }

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Space: togglePlay(); event.accepted = true; break;
        case Qt.Key_Right: stepForward(); event.accepted = true; break;
        case Qt.Key_Left: stepBack(); event.accepted = true; break;
        case Qt.Key_R: reset(); event.accepted = true; break;
        case Qt.Key_E: skipToEnd(); event.accepted = true; break;
        case Qt.Key_V: toggleVerdict(); event.accepted = true; break;
        case Qt.Key_Escape:
            if (verdictOpen) toggleVerdict();
            else root.restartRequested();
            event.accepted = true;
            break;
        }
    }

    component ColumnHead: Text {
        Layout.fillWidth: true
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeMicro
        font.weight: Theme.weightBold
        font.letterSpacing: Theme.trackMicro
        elide: Text.ElideRight
    }

    // Percent while running, "[DONE]" once finished — the dashboard ticker's
    // readout, in the completed-work blue (§2.5). Six cells either way, so the
    // bars never resize as a process completes.
    component Readout: Text {
        property bool done: false
        property bool running: false
        property real pct: 0
        property color hue: Theme.textPrimary
        Layout.preferredWidth: Theme.charWidth(Theme.sizeData) * 6
        horizontalAlignment: Text.AlignRight
        text: done ? "[DONE]" : Math.round(pct) + "%"
        color: done ? Theme.accentBlue : (running ? hue : Theme.textSecondary)
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeData
        font.weight: done ? Theme.weightBold : Theme.weightRegular
        Behavior on color { ColorAnimation { duration: Theme.durationBase } }
    }
}
