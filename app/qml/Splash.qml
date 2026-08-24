import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §9 — the intro. Holds on the CHRONOS wordmark, then auto-plays a
// scroll-style reveal (the hero scrolls up and fades on its own timer, no user
// input required) into the algorithm picker.
//
// The wordmark is one of only four places Instrument Serif appears (§3.1). A
// high-contrast display serif over a phosphor terminal is the deliberate
// tension the whole design rests on, so it is set large and left unmodified
// — the face has no variable axes to push and needs none at this size.
Item {
    id: root
    signal finished()

    focus: true

    // StackView does not hand active focus to a replaced item on its own, so
    // without this the Keys handler below never fires and the skip is dead.
    Component.onCompleted: root.forceActiveFocus()

    Rectangle { anchors.fill: parent; color: Theme.bgVoid }

    // Anchored left *and* right rather than centred: a ColumnLayout given only
    // a centre anchor reports zero width until its children resolve, and a
    // zero-width item centres its own left edge on the middle of the window —
    // which puts everything inside it off to the right. Pinning both edges
    // gives the layout a definite width, so Layout.alignment can do its job.
    ColumnLayout {
        id: hero
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceLg

        PhosphorText {
            id: wordmark
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: false
            Layout.fillHeight: false
            text: "CHRONOS"
            color: Theme.textPrimary
            font.family: Theme.fontDisplay
            // Scaled to the window rather than fixed: at 112px the wordmark
            // is wider than a 1240px window can hold, and a display element
            // that clips is worse than one that shrinks.
            font.pixelSize: Math.min(Theme.sizeDisplay, root.width / 9.5)
            // Instrument Serif ships Regular and Italic only — no Black cut and
            // no variable axes, so weight/axis overrides here would silently
            // synthesise a fake bold. Its display sizes carry themselves.
            font.letterSpacing: 1
            bloom: 1.0
            blurRadius: 34
            flicker: true

            // The one place a slow bloom pulse is permitted (§2.4a) — the
            // operational dashboard's controls never pulse.
            SequentialAnimation on bloom {
                loops: Animation.Infinite
                NumberAnimation { from: 0.85; to: 1.15; duration: 1600; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.15; to: 0.85; duration: 1600; easing.type: Easing.InOutSine }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spaceSm

            Text {
                text: "> ADAPTIVE CPU SCHEDULING ENGINE"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeLabel
                font.weight: Theme.weightSemiBold
                font.letterSpacing: Theme.trackLabel
            }

            BlinkingCursor {
                Layout.alignment: Qt.AlignVCenter
                font.pixelSize: Theme.sizeLabel
                color: Theme.textSecondary
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceXl
        text: "[ PRESS ANY KEY TO SKIP ]"
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeMicro
        font.letterSpacing: Theme.trackMicro
        opacity: revealAnim.running ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: hero; property: "anchors.verticalCenterOffset"; to: -root.height * 0.65; duration: 900; easing.type: Easing.InCubic }
        NumberAnimation { target: hero; property: "opacity"; to: 0; duration: 650; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 900; easing.type: Easing.InOutCubic }
        onStopped: root.finished()
    }

    Timer {
        id: holdTimer
        interval: 2600
        running: true
        repeat: false
        onTriggered: revealAnim.start()
    }

    // Skip (§9.4). Cuts straight through rather than fast-forwarding the
    // reveal — someone pressing a key wants the app, not a quicker animation.
    function skip() {
        if (revealAnim.running) return;
        holdTimer.stop();
        root.finished();
    }

    Keys.onPressed: (event) => { root.skip(); event.accepted = true; }

    MouseArea {
        anchors.fill: parent
        onClicked: root.skip()
    }
}
