import QtQuick
import QtQuick.Layouts
import ChronOS

// Stat tile (EDRD §5.1). Width-reserved from a character count so a counting
// number never shifts the tiles beside it (§3.2). Shared by the Dashboard and
// the compare screen (moved out of Dashboard.qml 2026-10-22).
ColumnLayout {
    property string label: ""
    property var value: ""
    property int cells: 4
    property color accent: Theme.textPrimary

    Layout.fillWidth: false
    spacing: 0

    Text {
        text: parent.label
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeMicro
        font.weight: Theme.weightSemiBold
        font.letterSpacing: Theme.trackMicro
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Theme.charWidth(Theme.sizeDataLg) * parent.cells
    }

    Text {
        text: parent.value
        color: parent.accent
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeDataLg
        font.weight: Theme.weightExtraBold
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Theme.charWidth(Theme.sizeDataLg) * parent.cells
    }
}
