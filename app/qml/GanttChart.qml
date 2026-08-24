import QtQuick
import ChronOS

// EDRD.md §5.2 — the CPU timeline.
//
// Revised 2026-08-24b: the tick ruler is gone. It marked every fifth tick on a
// fixed grid, which told a viewer nothing they wanted to know — the question
// being asked of this chart is "when did P1 hand over?", and a 0/5/10/15 ruler
// answers that only by eye-balling a segment edge against the nearest gridline.
// Each segment now carries its own **start and end tick, directly above its own
// boundaries**, so the answer is read rather than estimated.
TerminalPane {
    id: root
    property int currentTick: 0
    property int maxTick: 1
    // The actual current playback rate, not the fixed 1x base rate — the
    // playhead's own move animation must scale with this or it falls further
    // and further behind the real tick as speed goes up (see the Behavior
    // below).
    property real ticksPerSecond: Theme.baseTicksPerSecond

    title: "CPU TIMELINE"
    active: true

    readonly property real pxPerTick: Math.max(4, flick.width / Math.max(1, maxTick))
    readonly property int labelSize: Theme.sizeMicro

    Rectangle {
        anchors.fill: parent
        color: Theme.bgInset
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: Math.max(width, root.maxTick * root.pxPerTick)
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: canvas
            width: flick.contentWidth
            height: flick.height

            readonly property int rulerH: root.labelSize + Theme.spaceXs

            Repeater {
                model: bridge.ganttSegments()

                delegate: Item {
                    id: seg
                    required property var modelData
                    required property int index

                    readonly property color hue: Theme.procShade(modelData.pid)
                    readonly property bool isCurrent: root.currentTick >= modelData.start
                                                      && root.currentTick < modelData.end
                    readonly property bool isPast: root.currentTick >= modelData.end

                    x: modelData.start * root.pxPerTick
                    y: canvas.rulerH
                    width: Math.max(1, (modelData.end - modelData.start) * root.pxPerTick)
                    height: canvas.height - canvas.rulerH

                    // Boundary tick labels -------------------------------------
                    // The start label sits on this segment's left edge. The end
                    // label is drawn only by the last segment, because every
                    // other segment's end is the next one's start and drawing
                    // both would double every number on the axis.
                    Text {
                        x: 0
                        y: -canvas.rulerH
                        text: seg.modelData.start
                        color: seg.isCurrent || seg.isPast ? seg.hue : Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: root.labelSize
                        Behavior on color { ColorAnimation { duration: Theme.durationBase } }
                    }

                    Text {
                        visible: seg.index === bridge.ganttSegments().length - 1
                        x: seg.width - implicitWidth
                        y: -canvas.rulerH
                        text: seg.modelData.end
                        color: seg.isPast ? seg.hue : Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: root.labelSize
                    }

                    // A hairline dropped from each label to its own boundary, so
                    // a number is unambiguously attached to an edge even when
                    // segments are only a few pixels wide.
                    Rectangle {
                        x: 0
                        y: -Theme.spaceXs
                        width: Theme.borderThin
                        height: Theme.spaceXs
                        color: Theme.borderMuted
                    }

                    // Body -----------------------------------------------------
                    Rectangle {
                        id: body
                        anchors.fill: parent
                        anchors.topMargin: Theme.spaceXs
                        anchors.bottomMargin: Theme.spaceXs
                        color: Theme.bgVoid
                        border.width: seg.isCurrent ? Theme.borderThick : Theme.borderThin
                        border.color: seg.isCurrent ? seg.hue
                                                    : (seg.isPast ? Qt.darker(seg.hue, 2.2)
                                                                  : Theme.borderMuted)
                        radius: Theme.radiusNone
                        clip: true

                        Behavior on border.color { ColorAnimation { duration: Theme.durationBase } }

                        // PID label only — no glyph fill (2026-08-25, explicit
                        // user request). Identity is carried by color alone:
                        // the process's hue, centered in its own segment.
                        Text {
                            anchors.centerIn: parent
                            visible: seg.width >= implicitWidth + Theme.spaceXs * 2
                            text: "P" + seg.modelData.pid
                            color: seg.hue
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.sizeData
                            font.weight: Theme.weightBold
                            opacity: seg.isCurrent || seg.isPast ? 1.0 : 0.5
                            Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
                        }
                    }
                }
            }

            // Playhead ---------------------------------------------------------
            Rectangle {
                x: root.currentTick * root.pxPerTick
                y: 0
                width: Theme.borderThin
                height: canvas.height
                color: Theme.borderActive

                // Eased toward each new tick rather than snapping instantly —
                // at the slower default rate (§6) a hard jump every step reads
                // as stuttering. But the ease must always finish comfortably
                // before the *next* tick arrives, or it never catches up: at
                // higher playback speeds the tick interval itself shrinks, so
                // the animation duration is capped at a fraction of the
                // current interval (1000 / root.ticksPerSecond), not the
                // fixed 1x base rate. This is what makes it visibly snap
                // faster as speed increases instead of lagging behind it.
                Behavior on x {
                    NumberAnimation {
                        duration: Math.min(Theme.durationFlow, 700 / root.ticksPerSecond)
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}
