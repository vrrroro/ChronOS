import QtQuick
import ChronOS

// EDRD.md §2.7(8) — CRT scanlines. The front-most layer in the app; mounted
// once in Main.qml, never per-screen.
//
// Two properties here are load-bearing rather than stylistic:
//
//   * `enabled: false` — a full-window overlay that accepts input would make
//     every control underneath it inert. This must never become true.
//   * `opacity` ≤ 0.10 — §2.6 caps it here so the overlay cannot pull any text
//     below its measured AA contrast ratio. Raising it is a spec change.
//
// The pattern is a 1×4 RGBA PNG (three transparent rows, one opaque black row)
// embedded as a data URI and tiled by the scene graph. The obvious alternatives
// are both worse: a Repeater of 1px Rectangles allocates a node per scanline
// and re-runs on every resize, and a Canvas has to repaint the full window on
// each geometry change. Tiling one tiny texture costs a single batched draw.
Item {
    id: root
    enabled: false
    z: 9999

    Image {
        anchors.fill: parent
        fillMode: Image.Tile
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        opacity: 0.10
        smooth: false
        cache: true
        source: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAECAYAAABP2FU6AAAADElEQVR42mNgwAD/AQETAQD/fBGrAAAAAElFTkSuQmCC"
    }
}
