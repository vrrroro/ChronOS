import QtQuick
import ChronOS

// EDRD.md §2.4a — phosphor persistence, mechanism 2 of 2: inverted video.
//
// Interactive elements do not glow harder on hover; they invert. Background
// fills with textPrimary, label flips to textOnAccent, border holds. That is
// how a real terminal shows selection — instant, unmistakable, and free of
// blur passes. Labels carry their own brackets (`[ RUN ]`) as characters in
// the string, per §3.3; the brackets are never a drawn border.
Rectangle {
    id: root

    property string label: ""
    property bool enabledButton: true
    property bool selected: false
    signal clicked()

    readonly property bool lit: selected || (mouse.containsMouse && enabledButton)

    // Padding is deliberately tight: the bracketed label is itself the
    // affordance (§2.7(5)), so wide padding buys nothing and costs layout room
    // on strips that carry many controls.
    property int hPadding: Theme.spaceSm

    implicitWidth: text.implicitWidth + hPadding * 2
    implicitHeight: text.implicitHeight + Theme.spaceSm * 2

    radius: Theme.radiusNone
    color: lit ? Theme.textPrimary : Theme.bgVoid
    border.width: enabledButton ? Theme.borderThin : 0
    border.color: lit ? Theme.textPrimary : Theme.borderMuted

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

    // A disabled control reads as disabled through dim text and a dashed
    // border (§5.7), not through opacity — fading the whole item would also
    // fade the border, which is already at its contrast floor. The solid
    // border above is hidden while this draws, so the two never double up.
    Canvas {
        id: dashedBorder
        visible: !root.enabledButton
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = Theme.borderMuted;
            ctx.lineWidth = Theme.borderThin;
            ctx.setLineDash([4, 3]);
            ctx.strokeRect(0.5, 0.5, width - 1, height - 1);
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Text {
        id: text
        anchors.centerIn: parent
        text: root.label
        color: !root.enabledButton ? Theme.textDim
                                   : (root.lit ? Theme.textOnAccent : Theme.textPrimary)
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeLabel
        font.weight: Theme.weightSemiBold
        font.letterSpacing: Theme.trackLabel

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabledButton
        cursorShape: root.enabledButton ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
