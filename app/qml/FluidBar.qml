import QtQuick
import ChronOS

// EDRD.md §6.9 — the liquid fill.
//
// A logged deviation from §2.7(7), which says every quantity is a character
// bar. Character bars stay everywhere else (the scrub track, the aging meters,
// the score breakdown) because they are read as *values*. The process-progress
// bars are read as *motion* — the whole point is watching work drain away — and
// a glyph bar can only ever move in whole-cell steps, so at one tick per cell
// it stutters instead of flowing.
//
// Revised 2026-08-25 (explicit user request): the fill is now tiny segmented
// blocks rather than one continuous rectangle — a segmented meter reads more
// like instrumentation than a single resizing bar — but it stays liquid, not
// digital, because of what each segment does:
//
//   1. Every segment eases its own width in independently (long, sine-eased),
//      so segments visibly *fill* one after another rather than all snapping
//      lit/unlit at once — that per-segment lag is what keeps a wall of tiny
//      blocks from reading as a discrete LED meter.
//   2. A single travelling sheen still sweeps across the *entire* filled span
//      (spanning however many segments are lit), independent of the segment
//      grid underneath, so the surface still reads as one continuous liquid
//      even though its body is visually divided into cells.
//   3. A brighter meniscus rides the true leading edge (the filled length
//      itself, not a segment boundary), so the front is never a hard cut.
//
// No per-process glyph or symbol anywhere in this component (explicit user
// request, 2026-08-25) — the only thing that identifies a process is
// `fillColor`, supplied by the caller as `Theme.procShade(pid)`.
//
// The ASCII brackets are kept so it still sits in the terminal's grammar.
Item {
    id: root

    property real fraction: 0
    property color fillColor: Theme.textPrimary
    property color trackColor: Theme.borderMuted
    property bool showBrackets: true
    property bool active: false        // drives the sheen; off when idle/done
    property int pixelSize: Theme.sizeData

    readonly property real clamped: Math.max(0, Math.min(1, fraction))

    // Segment pitch (cell + gap) in px — small enough to read as "tiny
    // segments," large enough that a wide bar doesn't end up with hairline
    // cells no eased width transition could ever show.
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

        // The true (unsegmented) filled length — drives the sheen and the
        // meniscus, both of which read as one continuous liquid surface
        // regardless of the segment grid underneath.
        readonly property real filledLength: width * root.clamped

        // Tiny segmented blocks. Each one is its own little liquid cell: unlit
        // segments show only the empty track, a segment inside the filled span
        // eases its own fill in, and the segment straddling the boundary shows
        // a partial fill — so progress still reads continuously, one small
        // block filling into the next, rather than jumping cell to cell.
        Row {
            id: segRow
            anchors.fill: parent
            spacing: root.segmentGap

            Repeater {
                model: channel.segmentCount

                delegate: Item {
                    id: cell
                    required property int index
                    width: channel.segmentW
                    height: channel.height

                    readonly property real segFraction: Math.max(0, Math.min(1,
                        root.clamped * channel.segmentCount - index))

                    // Empty track for this cell.
                    Rectangle {
                        anchors.fill: parent
                        color: root.trackColor
                        opacity: 0.35
                        radius: Theme.radiusNone
                    }

                    // This cell's own liquid fill — eases independently, which
                    // is what makes segments fill in sequence rather than all
                    // snapping together.
                    Rectangle {
                        id: cellFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * cell.segFraction
                        color: root.fillColor
                        opacity: 0.9
                        radius: Theme.radiusNone

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durationFlow
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }
        }

        // Travelling sheen, spanning the whole filled length across however
        // many segments are lit — this is what keeps the segmented body
        // reading as one liquid surface rather than a row of separate cells.
        // Runs only while the process is actually being served.
        Item {
            id: filledSpan
            x: 0
            width: channel.filledLength
            height: parent.height
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durationFlow
                    easing.type: Easing.InOutSine
                }
            }

            Rectangle {
                id: sheen
                width: Math.max(24, filledSpan.width * 0.28)
                height: parent.height
                visible: root.active && filledSpan.width > 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.28) }
                    GradientStop { position: 1.0; color: "transparent" }
                }

                SequentialAnimation on x {
                    running: sheen.visible
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -sheen.width
                        to: filledSpan.width
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }
                    PauseAnimation { duration: 700 }
                }
            }
        }

        // Meniscus — a brighter band riding the true leading edge. Without it
        // the fill's front is a hard cut, which reads as blocks stacking up
        // rather than a surface advancing.
        Rectangle {
            width: 2
            height: parent.height
            x: channel.filledLength - width
            visible: channel.filledLength > 2
            color: Qt.lighter(root.fillColor, 1.6)
            opacity: root.active ? 1.0 : 0.6

            Behavior on x {
                NumberAnimation {
                    duration: Theme.durationFlow
                    easing.type: Easing.InOutSine
                }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
        }
    }
}
