import QtQuick
import ChronOS

// The app's one scrollbar (added 2026-10-22, explicit user request): a thin
// vertical rail on the right edge of anything that scrolls. A faint wash of
// the phosphor green for the track and a solid green thumb — two flat
// rectangles, zero radius, no glow (EDRD §2.7 logged addition).
//
// It shows only while the content actually overflows. Drag the thumb, click
// the track to jump there, or use the wheel anywhere over the content.
//
// Usage — declare it inside the Flickable/ListView it drives; it lifts itself
// out of the scrolling content so it stays put while the content moves:
//
//     ListView {
//         id: list
//         delegate: Item { width: ListView.view.width - bar.gutter ... }
//         NeonScrollBar { id: bar; flickable: list }
//     }
//
// `gutter` is the width content should leave free on the right so the rail
// never sits on top of a right-aligned value. It is 0 when no bar is shown.
Item {
    id: root

    property Flickable flickable: null

    readonly property bool needed: flickable !== null
                                   && flickable.contentHeight > flickable.height + 1
    readonly property int gutter: needed ? width + Theme.spaceXs : 0
    readonly property bool lit: mouse.pressed || mouse.containsMouse

    width: 5
    visible: opacity > 0
    opacity: needed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    // Pin to the flickable itself rather than its contentItem, which is
    // where a child declared inside a Flickable lands — there it would
    // scroll away with the content.
    Component.onCompleted: if (flickable) parent = flickable
    x: flickable ? flickable.width - width : 0
    y: 0
    z: 100
    height: flickable ? flickable.height : 0

    // How far down the content is, and what fraction of it is on screen.
    // Clamped so overshoot at either end squeezes nothing out of the rail.
    readonly property real ratio: flickable ? Math.min(1, flickable.visibleArea.heightRatio) : 1
    readonly property real position: flickable
                                     ? Math.max(0, Math.min(1 - ratio, flickable.visibleArea.yPosition)) : 0

    Rectangle {
        id: track
        anchors.fill: parent
        color: Theme.textPrimary
        opacity: root.lit ? 0.28 : 0.17
        radius: Theme.radiusNone
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    }

    Rectangle {
        id: thumb
        width: parent.width
        height: Math.max(Theme.spaceMd, root.height * root.ratio)
        y: Math.min(root.height - height, root.height * root.position)
        color: Theme.textPrimary
        radius: Theme.radiusNone
        opacity: root.lit ? 1.0 : 0.7
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    }

    function scrollToThumbY(thumbY) {
        if (!flickable) return;
        const span = height - thumb.height;
        const r = span > 0 ? Math.max(0, Math.min(1, thumbY / span)) : 0;
        flickable.contentY = flickable.originY + r * (flickable.contentHeight - flickable.height);
    }

    MouseArea {
        id: mouse
        // A few pixels wider than the rail on the left, so a 5px target is
        // still easy to hit.
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceXs
        enabled: root.needed
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        // Where on the thumb it was grabbed: dragging keeps that point under
        // the pointer; a click on the track centres the thumb there instead.
        property real grab: 0

        onPressed: (m) => {
            const onThumb = m.y >= thumb.y && m.y <= thumb.y + thumb.height;
            grab = onThumb ? m.y - thumb.y : thumb.height / 2;
            root.scrollToThumbY(m.y - grab);
        }
        onPositionChanged: (m) => { if (pressed) root.scrollToThumbY(m.y - grab); }
        onWheel: (wheel) => {
            if (!root.flickable) return;
            const f = root.flickable;
            const maxY = f.originY + f.contentHeight - f.height;
            f.contentY = Math.max(f.originY, Math.min(maxY, f.contentY - wheel.angleDelta.y / 120 * 48));
        }
    }
}
