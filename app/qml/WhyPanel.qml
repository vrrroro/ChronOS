import QtQuick
import QtQuick.Layouts
import ChronOS

// EDRD.md §5.4 — "why this process?", the highest-value panel in the app per
// the PRD, and the one place the terminal-window chrome genuinely earns its
// keep. Gets the most generous hierarchy of any pane.
//
// Revised 2026-08-24b: this pane owns the app's **cyan** channel, and the
// chosen process is called out in **magenta**. Previously the whole dashboard
// was a single green, so the panel a viewer is meant to read first had no way
// to announce itself — it looked exactly like the five panes around it. Hue is
// carrying hierarchy here, which is a job one color cannot do (§2.5).
//
// Every binding here goes through `d`, a guarded accessor with a defined
// default shape, rather than reading `panelData` directly. That matters: the
// old version gated every child on `root.panelData.hasDecision`, so a single
// malformed payload made *all* of them fail at once and the pane rendered as an
// empty box — indistinguishable from a layout bug (issue #16). With a default
// shape the same failure degrades to the placeholder instead.
TerminalPane {
    id: root
    property var panelData: ({})

    readonly property var d: {
        const p = panelData;
        if (!p || typeof p !== "object") return emptyShape;
        return {
            hasDecision: p.hasDecision === true,
            pid: p.pid !== undefined ? p.pid : -1,
            score: p.score !== undefined ? p.score : 0,
            reasons: p.reasons !== undefined ? p.reasons : [],
            scoreSegments: p.scoreSegments !== undefined ? p.scoreSegments : []
        };
    }
    readonly property var emptyShape: ({
        hasDecision: false, pid: -1, score: 0, reasons: [], scoreSegments: []
    })

    title: "WHY THIS PROCESS"
    active: d.hasDecision
    statusText: d.hasDecision
                ? "DECISION SCORE " + Number(d.score).toFixed(1)
                : "AWAITING FIRST DECISION"

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spaceSm

        // Empty state ------------------------------------------------------
        RowLayout {
            visible: !root.d.hasDecision
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Text {
                text: "> awaiting first scheduling decision"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeBody
            }
            BlinkingCursor { color: Theme.textDim; font.pixelSize: Theme.sizeBody }
            Item { Layout.fillWidth: true }
        }

        // Verdict — the fourth and last permitted use of Instrument Serif (§3.1).
        // Keyed on the pid so it re-types once per *decision*, never per tick.
        // Colored by the chosen process's own hue (Theme.procShade), the same
        // color that identifies it everywhere else (Gantt, ticker, ready
        // queue) — not a fixed accent — so "which process" reads as one
        // consistent color across the whole dashboard, not a separate WhyPanel-
        // only color.
        TypewriterText {
            visible: root.d.hasDecision
            Layout.fillWidth: true
            Layout.preferredHeight: root.d.hasDecision ? Theme.sizeH0 + Theme.spaceXs : 0
            fullText: root.d.hasDecision ? "P" + root.d.pid + " RUNS NEXT" : ""
            color: Theme.procShade(root.d.pid)
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.sizeH0
            bloomEnabled: true
            bloom: 1.0
            flicker: true
        }

        // Reasons ----------------------------------------------------------
        ListView {
            visible: root.d.hasDecision
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Without a floor this list is the only flexible child, so when the
            // pane is short it absorbs the whole shortfall and collapses to
            // zero — the reasons vanish while everything around them still
            // renders, which looks like the data is missing rather than the
            // space. Same failure family as issue #15.
            Layout.minimumHeight: 96
            clip: true
            spacing: Theme.spaceXs
            model: root.d.reasons

            delegate: RowLayout {
                required property var modelData
                width: ListView.view.width
                spacing: Theme.spaceSm

                Text {
                    text: "[OK]"
                    color: Theme.accentCyan
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeMicro
                    font.weight: Theme.weightSemiBold
                    Layout.preferredWidth: Theme.charWidth(Theme.sizeMicro) * 5
                    Layout.alignment: Qt.AlignTop
                }

                Text {
                    text: modelData.text
                    color: Theme.textSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeBody
                    lineHeight: 1.15
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // Sign and arrow travel with the color — green/red is the
                // hardest pairing for deuteranopia and this is the one place
                // the design leans on it (§2.6). The delta string from the
                // bridge already carries both.
                Text {
                    visible: !!modelData.delta
                    text: modelData.delta ? modelData.delta : ""
                    color: modelData.positive ? Theme.accentPositive : Theme.accentError
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeBody
                    font.weight: Theme.weightBold
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: Theme.charWidth(Theme.sizeBody) * 8
                }
            }
        }

        // Score breakdown (§7.1) -------------------------------------------
        Text {
            visible: root.d.hasDecision
            Layout.fillWidth: true
            text: "-".repeat(Math.max(8, Math.floor(root.width / Theme.charWidth(Theme.sizeMicro)) - 4))
            color: Theme.borderMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeMicro
            elide: Text.ElideRight
        }

        RowLayout {
            visible: root.d.hasDecision && root.d.scoreSegments.length > 0
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: root.d.scoreSegments
                delegate: Text {
                    required property var modelData
                    // Character bar, not a filled rectangle (§2.7(7)) — each
                    // contribution's sign picks its glyph run.
                    text: (modelData.positive ? "+" : "-")
                          .repeat(Math.max(1, Math.round(modelData.pct / 4)))
                    color: modelData.positive ? Theme.accentPositive : Theme.accentError
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.sizeData
                }
            }

            Item { Layout.fillWidth: true }
        }

    }
}
