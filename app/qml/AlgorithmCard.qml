import QtQuick
import QtQuick.Layouts
import ChronOS

// The algorithm picker's ABOUT card (added 2026-10-16, explicit user request):
// what an algorithm is like to run — how it picks, whether it preempts, what it
// needs to know — and where it is strong and where it is weak.
//
// The prose comes from ChronosBridge::algorithmAbout() and contains no numbers
// on purpose: AGENTS.md forbids illustrative metrics, and how well an
// algorithm does is something to find out by running it, not to be told.
//
// Strengths and weaknesses borrow the delta roles of EDRD §2.5 (green +,
// red −), and each line carries its sign as a glyph, so the split never rests
// on hue alone.
TerminalPane {
    id: root

    property string algoKey: ""
    property string algoLabel: ""
    property var about: ({})

    readonly property var traits: about && about.traits ? about.traits : []
    readonly property var strengths: about && about.strengths ? about.strengths : []
    readonly property var weaknesses: about && about.weaknesses ? about.weaknesses : []

    title: "ABOUT: " + algoLabel.toUpperCase()
    statusText: "--algorithm " + algoKey
    active: true

    implicitWidth: 400
    implicitHeight: body.implicitHeight + Theme.sizeH1 + Theme.sizeMicro + Theme.spaceLg * 2 + Theme.spaceMd

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.spaceSm
        spacing: Theme.spaceXs

        Text {
            Layout.fillWidth: true
            text: root.about && root.about.tagline ? root.about.tagline : ""
            color: Theme.textPrimary
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeBody
            lineHeight: 1.3
            wrapMode: Text.WordWrap
        }

        Divider {}

        SectionLabel { text: "CHARACTERISTICS"; Layout.topMargin: Theme.spaceXs }

        Repeater {
            model: root.traits
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.spaceSm
                Text {
                    text: modelData.label
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.letterSpacing: Theme.trackMicro
                }
                // Fills the rest of the row and elides, so a long value can
                // never run over its label.
                Text {
                    Layout.fillWidth: true
                    text: modelData.value
                    color: Theme.textSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }
        }

        Divider {}

        SectionLabel { text: "STRENGTHS"; Layout.topMargin: Theme.spaceXs }
        Repeater {
            model: root.strengths
            delegate: SignedLine {
                required property string modelData
                sign: "+"
                signColor: Theme.accentPositive
                line: modelData
            }
        }

        SectionLabel { text: "WEAKNESSES"; Layout.topMargin: Theme.spaceXs }
        Repeater {
            model: root.weaknesses
            delegate: SignedLine {
                required property string modelData
                sign: "−"
                signColor: Theme.accentError
                line: modelData
            }
        }
    }

    component Divider: Text {
        Layout.fillWidth: true
        text: "=".repeat(Math.max(8, Math.floor(root.width / Theme.charWidth(Theme.sizeMicro)) - 4))
        color: Theme.borderMuted
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeMicro
        elide: Text.ElideRight
    }

    component SectionLabel: Text {
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeMicro
        font.weight: Theme.weightBold
        font.letterSpacing: Theme.trackMicro
    }

    component SignedLine: RowLayout {
        property string sign: "+"
        property color signColor: Theme.accentPositive
        property string line: ""
        Layout.fillWidth: true
        spacing: Theme.spaceSm

        Text {
            Layout.alignment: Qt.AlignTop
            text: parent.sign
            color: parent.signColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeBody
            font.weight: Theme.weightBold
        }
        Text {
            Layout.fillWidth: true
            text: parent.line
            color: Theme.textSecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }
    }
}
