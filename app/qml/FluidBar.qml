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
// So this is a real fill, with three things layered to make it read as liquid
// rather than as a rectangle being resized:
//
//   1. A long, eased width transition, so the level *settles* into place.
//   2. A brighter meniscus at the leading edge — the visual weight sits where
//      the motion is, which is what makes a moving edge read as a surface.
//   3. A slow travelling sheen across the filled body, so a bar that is not
//      currently advancing still looks like a held liquid and not a solid bar.
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
    readonly property int charW: Theme.charWidth(pixelSize)

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

        // Empty channel — a dotted rule, so an unfilled bar still reads as a
        // measured track rather than as blank space.
        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: "·".repeat(Math.max(1, Math.ceil(channel.width / root.charW)))
            color: root.trackColor
            font.family: Theme.fontMono
            font.pixelSize: root.pixelSize
            opacity: 0.5
            clip: true
        }

        // The body of the liquid.
        Rectangle {
            id: body
            height: parent.height
            width: channel.width * root.clamped
            color: root.fillColor
            opacity: 0.85
            radius: Theme.radiusNone

            // The settle. Long and sine-eased: the level eases out of rest and
            // back into it, which is what separates "liquid finding its level"
            // from "a bar being set to a new width".
            Behavior on width {
                NumberAnimation {
                    duration: Theme.durationFlow
                    easing.type: Easing.InOutSine
                }
            }

            // Travelling sheen. Runs only while the process is actually being
            // served, so a paused or finished bar is visibly still — motion
            // here means "this is the one moving", not decoration.
            Rectangle {
                id: sheen
                width: Math.max(24, body.width * 0.28)
                height: parent.height
                visible: root.active && body.width > 4
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
                        to: body.width
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }
                    PauseAnimation { duration: 700 }
                }
            }
        }

        // Meniscus — a brighter band riding the leading edge. Without it the
        // fill's front is a hard cut, which reads as a rectangle no matter how
        // smoothly it moves.
        Rectangle {
            width: 2
            height: parent.height
            x: body.width - width
            visible: body.width > 2
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
