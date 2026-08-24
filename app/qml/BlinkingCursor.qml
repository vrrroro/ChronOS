import QtQuick
import ChronOS

// EDRD.md §2.7(4) — the cursor is the heartbeat of the interface, and the only
// continuous animation permitted in the operational UI (§2.4a: dashboard
// controls never pulse). Appears on the splash prompt, empty states, the
// currently-RUNNING row, and any focused input.
//
// The blink is a hard on/off at ~530ms, not a fade. A real terminal cursor
// switches instantly, and easing it turns a system signal into decoration.
Text {
    id: root

    property bool blinking: true

    text: "█"
    color: Theme.textPrimary
    font.family: Theme.fontMono
    font.pixelSize: Theme.sizeBody

    opacity: blinking ? 1.0 : 1.0

    SequentialAnimation on opacity {
        running: root.blinking && root.visible
        loops: Animation.Infinite
        PropertyAnimation { to: 1.0; duration: 0 }
        PauseAnimation { duration: Theme.cursorBlink }
        PropertyAnimation { to: 0.0; duration: 0 }
        PauseAnimation { duration: Theme.cursorBlink }
    }
}
