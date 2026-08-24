import QtQuick
import QtQuick.Effects
import ChronOS

// EDRD.md §2.4a — phosphor persistence.
//
// Revised 2026-08-24b: the bloom is much dimmer than it was, and it flickers.
// The previous strength made display type look washed out — the halo competed
// with the glyphs instead of sitting behind them, which reads as a lighting
// effect applied *to* the type rather than as the type emitting light. A real
// phosphor tube is subtle and unsteady, so this is now a low-opacity halo with
// an irregular flicker on top.
//
// Structure: one Text, with `layer.enabled` so it doubles as a texture source,
// and a MultiEffect *behind* it drawing the blurred copy. The sharp glyphs are
// what you read; the blur is only light around them.
//
// The label is centered rather than anchor-filled, and the root takes its
// implicit size from the label. Anchor-filling the label instead makes its
// width depend on the root's, which depends on the label's — the resulting
// cycle resolves to a stale size and the item lands off-center inside a layout.
Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property alias horizontalAlignment: label.horizontalAlignment
    property alias verticalAlignment: label.verticalAlignment
    property alias wrapMode: label.wrapMode
    property alias elide: label.elide

    // Bloom strength. 1.0 is the resting UI value and is deliberately faint.
    property real bloom: 1.0
    property real blurRadius: 14

    // CRT flicker. Off by default — only display type carries it, because a
    // flicker on data a viewer is trying to read is an irritation, not an
    // effect (§6.10).
    property bool flicker: false

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    // Irregular on purpose. A sine or a plain loop reads as a pulse — a
    // deliberate animation — where a tube's unsteadiness is arrhythmic. The
    // uneven step durations and the two different dip depths are what make
    // this read as "slightly unstable" rather than "breathing".
    property real flickerLevel: 1.0
    SequentialAnimation on flickerLevel {
        running: root.flicker && root.visible
        loops: Animation.Infinite
        NumberAnimation { to: 1.0;  duration: 1700 }
        NumberAnimation { to: 0.82; duration: 70 }
        NumberAnimation { to: 1.0;  duration: 110 }
        NumberAnimation { to: 1.0;  duration: 900 }
        NumberAnimation { to: 0.90; duration: 50 }
        NumberAnimation { to: 1.0;  duration: 60 }
        NumberAnimation { to: 1.0;  duration: 2300 }
        NumberAnimation { to: 0.86; duration: 90 }
        NumberAnimation { to: 1.0;  duration: 140 }
    }

    MultiEffect {
        anchors.fill: label
        source: label
        blurEnabled: true
        blur: 1.0
        blurMax: root.blurRadius
        // 0.22 at bloom 1.0 — a suggestion of light, not a spotlight.
        opacity: Math.min(1.0, 0.22 * root.bloom * root.flickerLevel)
        Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.textPrimary
        font.family: Theme.fontMono
        font.pixelSize: Theme.sizeH1
        layer.enabled: true
        // The glyphs themselves dim very slightly with the flicker; without
        // this only the halo moves, which looks like the glow is detached from
        // the type rather than part of it.
        opacity: root.flicker ? 0.90 + 0.10 * root.flickerLevel : 1.0
    }
}
