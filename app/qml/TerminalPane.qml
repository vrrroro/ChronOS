import QtQuick
import ChronOS

// EDRD.md §2.7(2,3) — the standard container. A 1px border on bgVoid with an
// ASCII title bar; no fill step, no shadow, no radius.
//
// The pane is defined by its *border*, not by a lighter background — that is
// why there is no `bgPanel` token any more. An active pane switches its border
// color (§2.4a); it never grows a glow halo.
//
// Title bars are real characters (`+--- READY QUEUE ---------+`) with the dash
// run computed from the available width, per §1.2's rule: characters for
// anything that scales with content, borders for anything that scales with the
// window.
Rectangle {
    id: root

    property string title: ""
    property string statusText: ""
    property bool active: false

    // Panes that carry a distinct role can claim a hue (EDRD §2.5) — the
    // why-panel is cyan, for instance. Defaults to the app's green, so a pane
    // that says nothing looks exactly as it always did.
    property color accentColor: Theme.textPrimary
    default property alias content: contentArea.data

    color: Theme.bgVoid
    radius: Theme.radiusNone
    border.width: Theme.borderThin
    border.color: active ? accentColor : Theme.borderMuted

    Behavior on border.color { ColorAnimation { duration: Theme.durationBase } }

    // Measured, not estimated. Theme.charWidth() approximates the advance as
    // 0.6em, which is right for JetBrains Mono on its own but ignores the
    // letter-spacing the title carries (§3.2) — and underestimating by ~1.5px
    // per cell puts several extra dashes on the line, which then run straight
    // through the pane's right border.
    TextMetrics {
        id: titleMetrics
        font: titleText.font
        text: "-"
    }

    // Header ---------------------------------------------------------------
    Item {
        id: header
        visible: root.title.length > 0
        height: visible ? Theme.sizeH1 + Theme.spaceSm * 2 : 0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.borderThin

        Text {
            id: titleText
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter
            // The trailing dashes fill whatever room is left after the label,
            // so the frame reads as one continuous ASCII rule at any width.
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceSm
            text: {
                const label = "+--- " + root.title + " ";
                const cell = titleMetrics.advanceWidth > 0 ? titleMetrics.advanceWidth : 10;
                const avail = Math.max(0, width);
                const cells = Math.floor(avail / cell);
                const fill = Math.max(3, cells - label.length - 1);
                return label + "-".repeat(fill) + "+";
            }
            horizontalAlignment: Text.AlignLeft
            color: root.active ? root.accentColor : Theme.textSecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeH1
            font.weight: Theme.weightBold
            font.letterSpacing: Theme.trackH1
            elide: Text.ElideRight

            Behavior on color { ColorAnimation { duration: Theme.durationBase } }
        }
    }

    // Body -----------------------------------------------------------------
    Item {
        id: contentArea
        anchors.top: header.visible ? header.bottom : parent.top
        anchors.bottom: statusStrip.visible ? statusStrip.top : parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spaceSm + Theme.borderThin
        anchors.rightMargin: Theme.spaceSm + Theme.borderThin
        anchors.topMargin: header.visible ? 0 : Theme.spaceSm
        anchors.bottomMargin: Theme.spaceSm
        clip: true
    }

    // Status strip ---------------------------------------------------------
    Item {
        id: statusStrip
        visible: root.statusText.length > 0
        height: visible ? Theme.sizeMicro + Theme.spaceSm * 2 : 0
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.borderThin

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.borderThin
            color: Theme.borderMuted
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceSm
            text: root.statusText
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            font.letterSpacing: Theme.trackMicro
            elide: Text.ElideMiddle
        }
    }
}
