import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.10 — the floating process HUD.
//
// Hovering a row in the process ticker explains that process in one glance:
// what it is, where it is, and what it cost. The ticker bar shows *how far
// along* a process is and nothing else, so a viewer watching a finished run has
// no way to ask "what actually happened to P7?" without reading four panels.
//
// It is a floating overlay rather than a docked panel because it belongs to the
// row under the cursor, and because the dashboard has no room to spare. Styled
// as terminal chrome, not as a soft tooltip (§2.7).
Rectangle {
    id: root

    property var entry: ({})
    readonly property color hue: entry.pid !== undefined
                                 ? Theme.procShade(entry.pid) : Theme.textPrimary

    color: Theme.bgVoid
    radius: Theme.radiusNone
    border.width: Theme.borderThin
    border.color: hue

    implicitWidth: 268
    implicitHeight: body.implicitHeight + Theme.spaceSm * 2

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceXs

        // Header: identity + live state ------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            Text {
                text: Theme.procGlyph(root.entry.pid !== undefined ? root.entry.pid : 0)
                color: root.hue
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeLabel
            }
            Text {
                text: "P" + (root.entry.pid !== undefined ? root.entry.pid : "?")
                color: root.hue
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeLabel
                font.weight: Theme.weightBold
                font.letterSpacing: Theme.trackLabel
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "[" + (root.entry.state !== undefined ? root.entry.state : "") + "]"
                color: {
                    switch (root.entry.state) {
                    case "RUNNING": return Theme.textPrimary;
                    case "DONE": return Theme.accentBlue;
                    case "NOT ARRIVED": return Theme.textDim;
                    default: return Theme.textSecondary;
                    }
                }
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                font.weight: Theme.weightSemiBold
            }
        }

        Text {
            Layout.fillWidth: true
            text: "-".repeat(30)
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            elide: Text.ElideRight
        }

        // What kind of process the analyzer decided this is ------------------
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "CLASS"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                font.letterSpacing: Theme.trackMicro
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.entry.cls !== undefined ? root.entry.cls : ""
                color: {
                    switch (root.entry.cls) {
                    case "CPU_BOUND": return Theme.accentMagenta;
                    case "IO_BOUND": return Theme.accentCyan;
                    case "INTERACTIVE": return Theme.accentAmber;
                    case "PENDING": return Theme.textDim;
                    default: return Theme.textSecondary;
                    }
                }
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeMicro
                font.weight: Theme.weightSemiBold
            }
        }

        // One plain sentence. The label above is a category; this says what
        // the category *means for this process*, which is the part a viewer
        // cannot infer from a word in a column.
        Text {
            Layout.fillWidth: true
            text: {
                switch (root.entry.cls) {
                case "CPU_BOUND":
                    return "> long CPU runs — holds the processor and pushes others back";
                case "IO_BOUND":
                    return "> short runs, gives up the CPU early and often";
                case "INTERACTIVE":
                    return "> short runs, gets served quickly — latency is what matters";
                case "BALANCED":
                    return "> neither notably short nor long — no special handling";
                case "PENDING":
                    return "> has not run yet, so there is nothing to classify from";
                default:
                    return "";
                }
            }
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            lineHeight: 1.2
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: "-".repeat(30)
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            elide: Text.ElideRight
        }

        HudRow { label: "CPU DONE"; value: root.entry.ranSoFar + " / " + root.entry.burstTime + " ticks" }
        HudRow { label: "ARRIVED";  value: "tick " + root.entry.arrivalTime }
        HudRow {
            label: "FINISHED"
            value: root.entry.done ? "tick " + root.entry.completionTime : "—"
            accent: root.entry.done ? Theme.accentBlue : Theme.textSecondary
        }

        // Cost figures only make sense once the process is finished; showing a
        // running total mid-flight invites reading a partial number as final.
        Text {
            Layout.fillWidth: true
            visible: root.entry.done === true
            text: "-".repeat(30)
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            elide: Text.ElideRight
        }
        HudRow {
            visible: root.entry.done === true
            label: "WAITED"
            value: root.entry.waitingTime + " ticks"
            accent: Theme.accentAmber
        }
        HudRow {
            visible: root.entry.done === true
            label: "TURNAROUND"
            value: root.entry.turnaroundTime + " ticks"
        }
        HudRow {
            visible: root.entry.done === true
            label: "1ST RESPONSE"
            value: root.entry.responseTime + " ticks"
        }
        HudRow {
            visible: root.entry.done === true
            label: "SWITCHES"
            value: root.entry.contextSwitches + ""
        }
    }

    component HudRow: RowLayout {
        property string label: ""
        property var value: ""
        property color accent: Theme.textSecondary
        Layout.fillWidth: true

        Text {
            text: parent.label
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            font.letterSpacing: Theme.trackMicro
        }
        Item { Layout.fillWidth: true }
        Text {
            text: parent.value
            color: parent.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
        }
    }
}
