pragma Singleton
import QtQuick

// The single source of truth for every color, size, weight, spacing value and
// duration in the app — EDRD.md §8.1. Nothing else hardcodes any of these.
//
// Visual system: "Terminal CLI" (EDRD.md §2). Jet black surfaces, zero radius,
// 1px pane borders, ASCII chrome.
//
// Palette revision 2026-08-24b: green is still the app's chrome color, but it
// is no longer the *only* color. A screen rendered entirely in one hue gives a
// viewer no way to rank what matters, so the classic terminal accent set —
// amber, red, cyan, magenta, blue — is now used to separate roles (EDRD §2.5)
// and to tell processes apart (§2.3). These are phosphor/ANSI-terminal hues,
// not arbitrary brand colors: the aesthetic is intact, the information is not
// flattened.
QtObject {
    // --- Base surfaces (EDRD §2.1) ---------------------------------------
    // bgVoid is #0A0A0A and not #000000 on purpose: the scanline overlay
    // darkens against it, and against true black there is nothing to darken.
    readonly property color bgVoid: "#0A0A0A"
    readonly property color bgPanelRaised: "#12180F"
    readonly property color bgInset: "#060806"

    // borderMuted is a *border* color only — 2.2:1 on bgVoid, far below AA.
    // Inactive and disabled text uses textDim, never this.
    readonly property color borderMuted: "#1F521F"
    readonly property color borderActive: "#33FF00"

    readonly property color textPrimary: "#33FF00"    // ~14.6:1 on bgVoid
    readonly property color textSecondary: "#21A600"  // ~5.9:1
    readonly property color textDim: "#1E8F10"        // ~4.7:1 — the floor
    readonly property color textOnAccent: "#0A0A0A"

    // --- Accent set (EDRD §2.5) ------------------------------------------
    // Terminal/ANSI hues. Each owns a *role*; none is decorative, and none is
    // used for two unrelated things.
    readonly property color accentAmber: "#FFB000"    // warnings, WAITING, aging
    readonly property color accentError: "#FF3333"    // errors, negative deltas
    readonly property color accentCyan: "#00E5FF"     // the "why" channel — the
                                                      // scheduler's reasoning
    readonly property color accentMagenta: "#FF3EC9"  // the chosen process, the
                                                      // single most important
                                                      // fact on the screen
    readonly property color accentBlue: "#4D9FFF"     // structural/reference data
    readonly property color accentPositive: "#33FF00" // positive deltas

    // --- Process state (EDRD §2.2) ---------------------------------------
    readonly property color stateRunning: "#33FF00"
    readonly property color stateReady: "#21A600"
    readonly property color stateWaiting: "#FFB000"
    readonly property color stateTerminated: "#1F521F"
    readonly property color stateNew: "#12300F"

    // --- Per-process identity (EDRD §2.3) --------------------------------
    // Two channels, indexed pid % 8: a neon hue *and* an ASCII fill glyph.
    //
    // The hue does the work at a glance. The glyph is what keeps the encoding
    // honest — it survives greyscale, a washed-out projector, and deuteranopia,
    // which is exactly what a hue-only palette cannot promise. Keeping both is
    // why this can be colorful without becoming unreadable.
    //
    // Green leads the palette because it is the app's own color, and the
    // remaining seven are spaced around the wheel so adjacent PIDs never sit
    // adjacent in hue.
    readonly property var procGlyphs: ["█", "▓", "▒", "░",
                                       "║", "≡", "·", "#"]
    readonly property var procShades: ["#33FF00", "#00E5FF", "#FF3EC9", "#FFB000",
                                       "#4D9FFF", "#FF7A29", "#C77DFF", "#D4FF3E"]

    function procGlyph(pid) { return procGlyphs[((pid % 8) + 8) % 8]; }
    function procShade(pid) { return procShades[((pid % 8) + 8) % 8]; }

    // --- Type (EDRD §3.1/§3.2) -------------------------------------------
    // JetBrains Mono is the default for everything. Instrument Serif is
    // display-only and appears in exactly four places: the splash wordmark, the
    // dashboard title, the picker screen headings, and the why-panel verdict.
    // It has no tabular figures, so it never touches a number.
    readonly property string fontMono: "JetBrains Mono"
    readonly property string fontDisplay: "Instrument Serif"

    readonly property int sizeDisplay: 128
    readonly property int sizeH0: 38
    readonly property int sizeH1: 16
    readonly property int sizeH2: 14
    readonly property int sizeBody: 14
    readonly property int sizeData: 14
    readonly property int sizeDataLg: 28
    readonly property int sizeLabel: 12
    readonly property int sizeMicro: 11

    readonly property int weightRegular: Font.Normal      // 400
    readonly property int weightMedium: Font.Medium       // 500
    readonly property int weightSemiBold: Font.DemiBold   // 600
    readonly property int weightBold: Font.Bold           // 700
    readonly property int weightExtraBold: Font.ExtraBold // 800
    readonly property int weightBlack: Font.Black         // 900

    // Tracking, in px at the size each is paired with (§3.2).
    readonly property real trackH1: 1.6
    readonly property real trackLabel: 1.4
    readonly property real trackMicro: 1.3

    // --- Geometry (EDRD §2.7) --------------------------------------------
    // Radius is 0 everywhere. Named so call sites read as a deliberate choice
    // rather than an omission.
    readonly property int radiusNone: 0
    readonly property int borderThin: 1
    readonly property int borderThick: 2

    // --- Spacing (EDRD §4.2) ---------------------------------------------
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 16
    readonly property int spaceLg: 24
    readonly property int spaceXl: 40

    // --- Motion (EDRD §6) ------------------------------------------------
    readonly property int durationFast: 100
    readonly property int durationBase: 180
    readonly property int durationSlow: 300
    readonly property int cursorBlink: 530
    readonly property int typeSpeed: 18   // ms per character, §2.7 typewriter

    // Playback: ticks per second at 1×. Deliberately slow — this is a teaching
    // instrument, and the whole point is to watch a viewer follow *why* each
    // decision happened. At the old 2/s the why-panel changed faster than it
    // could be read; the speed multipliers exist for anyone who wants to skim.
    readonly property real baseTicksPerSecond: 0.6

    // Progress-bar fill. Long and eased so the bar reads as liquid settling
    // rather than as a value snapping to a new position (§6.9).
    readonly property int durationFlow: 900

    // --- Derived helpers --------------------------------------------------
    // Width of one monospace character cell at a given size. Every tabular
    // column in the app is sized in characters via this rather than in pixels
    // (§3.2), which is what keeps numbers from shifting their neighbours.
    function charWidth(pixelSize) {
        return Math.ceil(pixelSize * 0.6);
    }
}
