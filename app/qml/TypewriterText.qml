import QtQuick
import ChronOS

// EDRD.md §2.7(9) — typewriter reveal. Screen-level headings and the why-panel
// verdict type in character-by-character on first appearance.
//
// Strictly once per screen entry or per decision. Never on data that updates
// every tick — a value that re-types itself twice a second is unreadable, which
// is why §2.7 rules it out explicitly rather than leaving it to taste.
//
// `fullText` drives the animation; assigning it again restarts the reveal, so
// bind it to something that changes only when a *new* reveal is wanted.
Item {
    id: root

    property string fullText: ""
    property alias color: label.color
    property alias font: label.font
    property alias horizontalAlignment: label.horizontalAlignment
    property bool bloomEnabled: false
    property real bloom: 1.0
    property bool flicker: false
    property int charDuration: Theme.typeSpeed
    property bool running: timer.running

    implicitWidth: metrics.implicitWidth
    implicitHeight: metrics.implicitHeight

    // Reserves the final width up front so surrounding layout does not reflow
    // character by character as the reveal runs.
    Text {
        id: metrics
        visible: false
        text: root.fullText
        font: label.font
    }

    property int shown: 0

    onFullTextChanged: {
        shown = 0;
        timer.restart();
    }

    Timer {
        id: timer
        interval: root.charDuration
        repeat: true
        running: false
        onTriggered: {
            if (root.shown >= root.fullText.length) {
                stop();
            } else {
                root.shown += 1;
            }
        }
    }

    function finish() {
        timer.stop();
        shown = fullText.length;
    }

    PhosphorText {
        id: bloomLayer
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.bloomEnabled
        text: label.text
        color: label.color
        font: label.font
        horizontalAlignment: label.horizontalAlignment
        bloom: root.bloom
        flicker: root.flicker
    }

    Text {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.bloomEnabled
        text: root.fullText.substring(0, root.shown)
        color: Theme.textPrimary
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeH1
    }
}
