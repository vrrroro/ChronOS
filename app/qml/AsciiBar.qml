import QtQuick
import ChronOS

// EDRD.md §2.7(7) — raw bar readout. Every quantity in the app is a character
// bar, never a smooth fill: `[||||||||······] 61%`.
//
// The cell count is derived from the item's own width and the monospace advance
// width, so the bar always lands on the character grid (§2.7(10)) instead of
// being a rectangle that happens to sit near it. This is the concrete reason
// §3.1 makes monospace mandatory for data.
Item {
    id: root

    // 0.0–1.0. Clamped rather than trusted: a tick past completionTime can push
    // a caller's ratio slightly over 1.0, and an over-filled bar is a rendering
    // bug that looks like a scheduling bug.
    property real fraction: 0
    property string glyph: "█"
    property string emptyGlyph: "·"
    property color fillColor: Theme.textPrimary
    property color emptyColor: Theme.borderMuted
    property bool showBrackets: true
    property int pixelSize: Theme.sizeData

    readonly property real clamped: Math.max(0, Math.min(1, fraction))
    readonly property int charW: Theme.charWidth(pixelSize)
    readonly property int cells: {
        const bracketCells = showBrackets ? 2 : 0;
        return Math.max(1, Math.floor(width / charW) - bracketCells);
    }
    readonly property int filled: Math.round(clamped * cells)

    implicitHeight: bar.implicitHeight

    Row {
        id: bar
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            visible: root.showBrackets
            text: "["
            color: root.emptyColor
            font.family: Theme.fontMono
            font.pixelSize: root.pixelSize
        }

        Text {
            text: root.glyph.repeat(root.filled)
            color: root.fillColor
            font.family: Theme.fontMono
            font.pixelSize: root.pixelSize
        }

        Text {
            text: root.emptyGlyph.repeat(Math.max(0, root.cells - root.filled))
            color: root.emptyColor
            font.family: Theme.fontMono
            font.pixelSize: root.pixelSize
        }

        Text {
            visible: root.showBrackets
            text: "]"
            color: root.emptyColor
            font.family: Theme.fontMono
            font.pixelSize: root.pixelSize
        }
    }
}
