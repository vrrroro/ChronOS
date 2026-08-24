import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5 — the operational dashboard: top bar, Gantt timeline, process
// ticker, ready queue, why-panel, aging indicator, playback controls.
Item {
    id: root
    signal restartRequested()

    property int currentTick: 0
    property bool isPlaying: false
    property real speed: 1
    readonly property int maxTick: bridge.maxTick
    // Ticks per second. The base rate lives in Theme (§6) and is deliberately
    // slow: this is a teaching instrument, and at the old 2/s the why-panel
    // changed faster than anyone could read it. The multipliers are there for
    // whoever wants to skim.
    readonly property real ticksPerSecond: Theme.baseTicksPerSecond * speed

    focus: true

    // StackView does not hand active focus to a replaced item on its own.
    Component.onCompleted: root.forceActiveFocus()

    Rectangle { anchors.fill: parent; color: Theme.bgVoid }

    Timer {
        interval: Math.max(16, 1000 / root.ticksPerSecond)
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.currentTick >= root.maxTick) {
                root.isPlaying = false;
            } else {
                root.currentTick += 1;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
        spacing: Theme.spaceSm

        // Top bar (§5.1) ---------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceLg

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                // One of only four places Instrument Serif appears (§3.1).
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
                    text: "$ chronos --algorithm " + bridge.selectedAlgorithm
                          + " --workload " + bridge.resultWorkloadName
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.letterSpacing: Theme.trackMicro
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Three different measures, so three different hues — read as a
            // row of identical green numbers they invite being compared with
            // each other, which is meaningless (§2.5).
            StatTile {
                label: "CPU"
                value: bridge.cpuUtilizationAt(root.currentTick) + "%"
                cells: 5
                accent: Theme.textPrimary
            }
            StatTile {
                label: "PROCESSES"
                value: bridge.processCount
                cells: 4
                accent: Theme.accentBlue
            }
            StatTile {
                label: "SWITCHES"
                value: bridge.contextSwitchesAt(root.currentTick)
                cells: 4
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

        // Panel grid -------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spaceMd

            // A nested layout inside a layout has Layout.fillWidth defaulting
            // to TRUE, and space between filling items is distributed in
            // proportion to their *preferred* sizes. This column's children are
            // all zero-implicit-width panes, so without an explicit preferred
            // and minimum width its preference is 0 and the right column's 380
            // takes everything — which is exactly how this column collapsed to
            // nothing (issue #15). Both columns state their sizing explicitly.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 700
                Layout.minimumWidth: 460
                Layout.fillHeight: true
                spacing: Theme.spaceMd

                GanttChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 128
                    Layout.minimumHeight: 110
                    currentTick: root.currentTick
                    maxTick: root.maxTick
                    ticksPerSecond: root.ticksPerSecond
                }

                ProcessTicker {
                    id: ticker
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 140
                    currentTick: root.currentTick
                    onHovered: (entry, windowY) => root.showHud(entry, windowY)
                    onUnhovered: root.hideHud()
                }

                PlaybackControls {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 90
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
                }
            }

            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 400
                Layout.minimumWidth: 400
                Layout.maximumWidth: 400
                Layout.fillHeight: true
                spacing: Theme.spaceMd

                ReadyQueueTable {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 168
                    rows: bridge.readyQueueAt(root.currentTick)
                    isAars: bridge.isAars
                }

                WhyPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 250
                    panelData: bridge.whyPanelAt(root.currentTick)
                }

                AgingIndicator {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 112
                    entries: bridge.agingListAt(root.currentTick)
                }
            }
        }
    }

    // Floating process HUD (§5.10). Hosted here rather than inside the ticker
    // so it can overhang the pane's edges — clipped to the ticker it would be
    // unusable on the first and last rows.
    ProcessHud {
        id: hud
        visible: opacity > 0
        opacity: 0
        z: 500
        // Sits clear of the ticker entirely, overlapping the right-hand column
        // instead. Anywhere over the ticker would cover the very bars it
        // describes — including the row under the cursor — and would also
        // steal the pointer from that row's HoverHandler, so the HUD would
        // flicker itself away as soon as you moved toward it.
        x: Math.min(root.width - width - Theme.spaceMd, root.width * 0.60)
        y: Math.max(Theme.spaceMd,
                    Math.min(root.height - height - Theme.spaceMd, hudAnchorY - height / 2))
        property real hudAnchorY: 0

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        Behavior on y { NumberAnimation { duration: Theme.durationBase; easing.type: Easing.OutCubic } }
    }

    function showHud(entry, windowY) {
        hud.entry = entry;
        hud.hudAnchorY = windowY;
        hud.opacity = 1;
    }
    function hideHud() { hud.opacity = 0; }

    // Transport, also on the keyboard — a demo runs this flow repeatedly and
    // reaching for the mouse on every step is friction.
    function togglePlay() { isPlaying = !isPlaying; }
    function stepForward() { isPlaying = false; currentTick = Math.min(maxTick, currentTick + 1); }
    function stepBack() { isPlaying = false; currentTick = Math.max(0, currentTick - 1); }
    function reset() { isPlaying = false; currentTick = 0; }

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Space: togglePlay(); event.accepted = true; break;
        case Qt.Key_Right: stepForward(); event.accepted = true; break;
        case Qt.Key_Left: stepBack(); event.accepted = true; break;
        case Qt.Key_R: reset(); event.accepted = true; break;
        case Qt.Key_Escape: root.restartRequested(); event.accepted = true; break;
        }
    }

    // Stat tile (§5.1). Width-reserved from a character count so a counting
    // number never shifts the tiles beside it (§3.2).
    component StatTile: ColumnLayout {
        property string label: ""
        property var value: ""
        property int cells: 4
        property color accent: Theme.textPrimary

        Layout.fillWidth: false
        spacing: 0

        Text {
            text: parent.label
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            font.weight: Theme.weightSemiBold
            font.letterSpacing: Theme.trackMicro
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: Theme.charWidth(Theme.sizeDataLg) * parent.cells
        }

        Text {
            text: parent.value
            color: parent.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeDataLg
            font.weight: Theme.weightExtraBold
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: Theme.charWidth(Theme.sizeDataLg) * parent.cells
        }
    }
}
