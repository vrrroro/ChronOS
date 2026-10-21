import QtQuick
import ChronOS

// EDRD.md §6.9 — the process-ticker fill. Replaces FluidBar (2026-10-16,
// explicit user request): progress no longer flows like liquid, it TICKS —
// like the second hand of an analog watch.
//
// Mechanics:
//   1. The bar is a row of tiny segments, and each segment is either lit or
//      not. Nothing eases: a segment snaps on, the way a second hand snaps to
//      its next mark.
//   2. When progress advances, the newly-earned segments light ONE AT A TIME,
//      in sequence, at a steady cadence — tick, tick, tick — and then the bar
//      rests until the next simulation tick. The cadence is scaled so a whole
//      tick's worth of segments always finishes inside `stepBudget` ms (set
//      from the live playback rate), so at 4× it is a fast run of ticks and at
//      1× it is a slow, countable one, but it never lags behind the playhead.
//   3. The leading segment is drawn in a brighter tint of the process's hue
//      (the "color bar leading it") and flashes on every step, so the eye
//      reads each individual tick rather than a growing block.
//   4. Going backwards (step back, scrub, reset) snaps immediately: a watch
//      does not tick in reverse.
//
// Still Terminal CLI throughout — zero radius, flat color, no gradient, ASCII
// brackets at both ends — and still identity by `fillColor` alone (§2.3): no
// per-process glyph.
Item {
    id: root

    property real fraction: 0
    property color fillColor: Theme.textPrimary
    property color trackColor: Theme.borderMuted
    property bool showBrackets: true
    property bool active: false        // the running process: full-strength fill
    property int pixelSize: Theme.sizeData
    property int stepBudget: 600       // ms that one advance may take, at most

    readonly property real clamped: Math.max(0, Math.min(1, fraction))

    // Segment pitch: small enough to read as tiny marks on a dial, large
    // enough that a single tick is visible at a glance.
    readonly property real segmentPitch: 6
    readonly property real segmentGap: 2

    implicitHeight: pixelSize + 2

    Text {
        id: openBracket
        visible: root.showBrackets
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "["
        color: root.trackColor
        font.family: Theme.fontMono
        font.pixelSize: root.pixelSize
    }

    Text {
        id: closeBracket
        visible: root.showBrackets
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "]"
        color: root.trackColor
        font.family: Theme.fontMono
        font.pixelSize: root.pixelSize
    }

    Item {
        id: channel
        anchors.left: root.showBrackets ? openBracket.right : parent.left
        anchors.right: root.showBrackets ? closeBracket.left : parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.pixelSize - 2
        clip: true

        readonly property int segmentCount: Math.max(10,
            Math.floor(width / (root.segmentPitch + root.segmentGap)))
        readonly property real segmentW:
            (width - (segmentCount - 1) * root.segmentGap) / Math.max(1, segmentCount)

        // Where the bar should be, and where it has ticked to so far.
        readonly property int target: Math.round(root.clamped * segmentCount)
        property int shown: 0
        property bool primed: false

        readonly property color headColor: Qt.lighter(root.fillColor, 1.55)
        readonly property real bodyOpacity: root.active ? 1.0 : 0.75

        function advance() {
            if (!primed || target < shown) {
                // First layout, or going backwards: no ticking, just be there.
                stepper.stop();
                shown = target;
                return;
            }
            if (target > shown) {
                stepper.interval = Math.max(16, Math.min(110, Math.floor(root.stepBudget / (target - shown))));
                if (!stepper.running) stepper.start();
            }
        }

        onTargetChanged: advance()
        // A resize changes what "one segment" means; re-seat rather than
        // ticking through a recount.
        onSegmentCountChanged: { stepper.stop(); shown = target; }
        Component.onCompleted: { shown = target; primed = true; }

        Timer {
            id: stepper
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (channel.shown < channel.target) {
                    channel.shown += 1;
                    flash.restart();
                }
                if (channel.shown >= channel.target) stop();
            }
        }

        Row {
            anchors.fill: parent
            spacing: root.segmentGap

            Repeater {
                model: channel.segmentCount

                delegate: Rectangle {
                    required property int index
                    readonly property bool lit: index < channel.shown
                    readonly property bool isHead: lit && index === channel.shown - 1
                                                   && channel.shown < channel.segmentCount

                    width: channel.segmentW
                    height: channel.height
                    radius: Theme.radiusNone
                    color: !lit ? root.trackColor : (isHead ? channel.headColor : root.fillColor)
                    opacity: !lit ? 0.35 : (isHead ? 1.0 : channel.bodyOpacity)
                }
            }
        }

        // The tick itself: a brief flash on the segment that just lit, so each
        // step is an event the eye registers, not a block quietly growing.
        Rectangle {
            id: headFlash
            width: channel.segmentW
            height: channel.height
            x: Math.max(0, channel.shown - 1) * (channel.segmentW + root.segmentGap)
            visible: channel.shown > 0
            // A further-lightened tint of the process's own hue rather than
            // white: §2.1's palette is closed, and every color in this bar is
            // derived from fillColor.
            color: Qt.lighter(root.fillColor, 1.9)
            opacity: 0
            radius: Theme.radiusNone

            SequentialAnimation {
                id: flash
                PropertyAction { target: headFlash; property: "opacity"; value: 0.7 }
                NumberAnimation {
                    target: headFlash; property: "opacity"; to: 0
                    duration: Math.max(60, Math.min(180, stepper.interval * 2))
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
