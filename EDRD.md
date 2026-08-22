# ChronOS — Engineering Design Requirements Document (EDRD)

**Visual & Interaction Design Spec for the Dashboard**

Author: Rohit
Draft date: August 22, 2026
Status: Draft v1 — companion to `PRD.md`, describes how the dashboard (Section 7 of the PRD) should actually look and behave
Scope: This document covers **only** the dashboard's visual design and interaction behavior. It does not repeat scheduling logic, data formats, or milestones — see `PRD.md` for those. Read `PRD.md` Section 7 first; this document is the detailed spec for building it.

> ✎ **EDIT ME:** Same convention as the PRD — every concrete value here (hex codes, pixel sizes, durations) is a real, implementable starting point, not a law. Change anything that looks wrong once you see it rendered.

---

## 1. Design Intent

### 1.1 One-sentence brief

A jet-black, neon-green terminal-style command center for watching a CPU scheduler think — dense enough to feel like a real OS tool, legible enough to read from a laptop during a live viva.

### 1.2 Reference points

- **Aesthetic inspiration:** classic terminal UIs (green/amber phosphor CRT monitors), modern "hacker dashboard" tools (htop, btop, k9s, Grafana dark themes), and the box-drawing mockups in the original project plan.
- **Not literal ASCII:** the original plan's `╔══╗` box-drawing mockups are the *information density and grouping* reference — how much is on screen at once, how panels are titled and separated — not a literal rendering target. Panels are built as real CSS-bordered boxes, not unicode box characters, so the layout stays clean and legible at different sizes instead of breaking like literal monospace ASCII art does.
- **Primary context:** a laptop screen (1366–1920px wide), shown live during a demo/viva. Not designed for mobile; reasonable behavior down to ~1280px is enough.

### 1.3 Design principles

1. **Legibility beats purity.** Jet black + a single neon green, taken literally everywhere, makes multi-process data hard to read. Green is the *identity* color (chrome, borders, primary text, headings); other neon colors are recruited specifically to distinguish processes.
2. **Every panel earns its position through information hierarchy**, not decoration. The CPU timeline and the "why this process" panel are the two panels a viewer's eye should land on first — everything else supports them.
3. **State is always visible.** A viewer glancing at the screen at any random moment should be able to tell, without explanation: what's running, what's waiting, and why the scheduler just did what it did.
4. **Motion explains, it doesn't decorate.** Every animation in Section 6 exists to make a state change easier to follow (a preemption, a score change, a new arrival) — never purely ornamental.

---

## 2. Color System

### 2.1 Base palette

| Token | Hex | Usage |
|---|---|---|
| `--bg-void` | `#000000` | True black — outermost page background |
| `--bg-panel` | `#0A0F0A` | Panel background (very slightly green-black, not pure black, so panels read as distinct surfaces against the void) |
| `--bg-panel-raised` | `#0F1A0F` | Hovered / active panel or row background |
| `--bg-inset` | `#050805` | Recessed areas — code/log blocks, the Gantt track background |
| `--border-default` | `#1A3D1A` | Default panel borders — dim green, visible but not loud |
| `--border-active` | `#39FF14` | Active/focused panel border, playhead line |
| `--text-primary` | `#39FF14` | Primary neon green — headings, key labels, primary data values |
| `--text-secondary` | `#8FE68F` | Secondary text — muted green, body copy, descriptions, table body text |
| `--text-dim` | `#3D5C3D` | Tertiary/disabled text — timestamps, placeholder, disabled controls |
| `--text-on-accent` | `#000000` | Text placed on top of a solid neon-colored surface (e.g. inside a filled button) |

`#39FF14` ("electric green" / classic terminal neon) is the signature color — used consistently for anything that represents "this is ChronOS chrome" as opposed to "this is process-specific data."

> ✎ **EDIT ME:** `#39FF14` is a strong, saturated neon green with good name recognition ("terminal green"). If it reads as too intense on your actual screen/projector, `#00FF41` (a slightly cooler, "Matrix"-leaning green) or `#4AF626` (marginally softer) are drop-in alternatives — swap the one token and everything downstream stays consistent.

### 2.2 Status colors (process state)

These map to the `State` enum in `PRD.md` Section 5.1 and must be used consistently everywhere a process's state is shown (ready queue table, Gantt chart border, status badges).

| State | Token | Hex | Notes |
|---|---|---|---|
| RUNNING | `--state-running` | `#39FF14` | Full-brightness primary green — the one process actually on the CPU should always be the brightest thing on screen |
| READY | `--state-ready` | `#8FE68F` | Muted green — waiting its turn, calm |
| WAITING (I/O) | `--state-waiting` | `#FFD23F` | Neon amber/yellow — distinct from green, signals "blocked," conventional traffic-light-adjacent meaning |
| TERMINATED | `--state-terminated` | `#3D5C3D` | Dimmed to near-background — done, no longer competing for attention |
| NEW (not yet arrived) | `--state-new` | `#1A3D1A` | Barely-there outline only — hasn't entered the system yet |

### 2.3 Per-process color palette (Gantt bars, ready-queue row accents, legend)

Because pure monochrome green can't distinguish 5–8 simultaneous processes, each process is assigned a color from a fixed neon palette, cycling if there are more processes than colors. This palette is deliberately *not* limited to green — green is reserved as the app's chrome/identity color, so process identity needs its own space to avoid ambiguity ("is this bar green because it's P3, or because it's RUNNING?").

| Slot | Name | Hex | Contrast note |
|---|---|---|---|
| 1 | Neon Green | `#39FF14` | Reserve for P1 or the currently-highlighted process only, since this hex is also the RUNNING-state color — see 2.4 rule below |
| 2 | Neon Cyan | `#0FF0FC` | |
| 3 | Neon Magenta | `#FF3EC9` | |
| 4 | Neon Amber | `#FFB300` | Distinct from the WAITING status amber (`#FFD23F`) — close enough to feel related, far enough apart to avoid literal confusion in a side-by-side legend |
| 5 | Neon Blue | `#3E9EFF` | |
| 6 | Neon Orange-Red | `#FF5C33` | |
| 7 | Neon Violet | `#B15CFF` | |
| 8 | Neon Lime-Yellow | `#D4FF3E` | |

Assignment rule: `processColor = palette[pid % palette.length]`, deterministic so a given PID always renders in the same color across the whole session (Gantt chart, ready queue, why-panel, comparison charts).

### 2.4 Resolving the green ambiguity

Slot 1 (`#39FF14`) is both the RUNNING-state color and a process palette color, which is a deliberate but risky overlap. Rule to keep it unambiguous:

- The **process palette** (2.3) is used for the Gantt chart bars and the ready-queue left-edge accent stripe — *identity*, at all times, regardless of state.
- The **status colors** (2.2) are used for text labels, status badges, and the outer glow/border treatment — *state*, layered on top of identity.
- A running P1 therefore looks like: a green-filled Gantt bar (identity) with a bright glowing border and a "RUNNING" badge in the same green (state) — the overlap reinforces rather than confuses, because they agree. A running P2 looks like a cyan-filled bar (identity) with a green glowing border and green "RUNNING" badge (state) — the contrast between bar fill and border/badge is what communicates "this is the one that's running," for *any* process color.

### 2.5 Semantic accent colors

| Purpose | Token | Hex |
|---|---|---|
| Aging bonus / positive score contribution | `--accent-positive` | `#39FF14` (primary green) |
| CPU burst penalty / negative score contribution | `--accent-negative` | `#FF3E5C` (neon red) |
| Warning (e.g. approaching starvation threshold) | `--accent-warning` | `#FFD23F` |
| Informational / neutral highlight | `--accent-info` | `#0FF0FC` |

### 2.6 Contrast & accessibility notes

- `#39FF14` on `#000000` has a contrast ratio well above WCAG AAA (>15:1) — safe for body text at any size.
- `#3D5C3D` (`--text-dim`) on `#000000` is roughly 4.5:1 — meets AA for normal text but is intentionally the *floor*; do not go dimmer for anything a viewer needs to read, only for genuinely de-emphasized chrome (grid lines, disabled states).
- Do not place `--text-secondary` (`#8FE68F`) directly on a filled neon accent background (e.g. inside a magenta Gantt bar) — use `--text-on-accent` (`#000000`) for any text that sits on top of a solid saturated color block.
- Colorblind consideration: green/red is the hardest pairing for the most common form of color blindness (deuteranopia). Because `--accent-positive`/`--accent-negative` (green/red score deltas in Section 7.4's why-panel) rely on this pairing, **always pair the color with a `+`/`−` sign and an icon (▲/▼)**, never color alone — this is already reflected in the component spec below.

---

## 3. Typography

### 3.1 Font stack

**Monospace throughout** — fits the terminal identity and, practically, this UI is mostly tabular/numeric data (ticks, scores, PIDs) where monospace alignment genuinely helps readability rather than just looking cool.

```css
--font-mono: 'JetBrains Mono', 'Fira Code', 'SF Mono', 'Cascadia Code', Consolas, 'Courier New', monospace;
```

- **JetBrains Mono** (free, open-source, via Google Fonts or self-hosted) is the primary choice — excellent legibility at small sizes, distinct glyphs for `0`/`O` and `1`/`l`/`I`, which matters a lot when you're staring at PIDs and tick numbers.
- **Fira Code** is a good fallback with similar qualities if JetBrains Mono is unavailable.
- No secondary sans-serif — keeping one font family everywhere is simpler to implement and reinforces the terminal feel. Longer prose (the why-panel's explanation lines) still uses the mono font but at a slightly larger size/line-height for readability (see 3.2).

> ✎ **EDIT ME:** If, once built, long text (why-panel reasons, tooltips) feels harder to read in monospace than you'd like, the fallback is to add one sans-serif (e.g. Inter) *only* for prose sentences, keeping mono for all numbers/labels/code. Treat this as a one-line CSS variable change, not a redesign.

### 3.2 Type scale

| Token | Size | Line height | Weight | Usage |
|---|---|---|---|---|
| `--text-display` | 28px | 1.2 | 700 | Dashboard title ("CHRONOS") |
| `--text-h1` | 20px | 1.3 | 700 | Panel titles ("CPU TIMELINE", "READY QUEUE") |
| `--text-h2` | 15px | 1.4 | 600 | Sub-section labels within a panel |
| `--text-body` | 14px | 1.6 | 400 | Why-panel explanation lines, descriptive text |
| `--text-data` | 14px | 1.4 | 500 | Table cell values, stat tile numbers |
| `--text-data-lg` | 22px | 1.2 | 700 | Stat tile hero numbers (CPU %, context switch count) |
| `--text-label` | 11px | 1.3 | 600, uppercase, letter-spacing 0.05em | Column headers, small caps labels |
| `--text-mono-code` | 13px | 1.5 | 400 | Raw log lines, JSON snippets if shown in-app |

### 3.3 Letter-spacing & case conventions

- Panel titles and column headers: UPPERCASE with `letter-spacing: 0.05em` — reinforces the "system readout" feel (consistent with the ASCII mockup's `RUNNING`, `READY QUEUE` style headers).
- Body/explanation text: normal sentence case — uppercase prose is harder to read and the why-panel explanations are meant to be genuinely read, not just glanced at.
- Process IDs always rendered as `P1`, `P2`, etc. (no lowercase `p1`), consistent with the PRD's own convention.

---

## 4. Layout & Spacing

### 4.1 Grid structure

Single-page dashboard, no scrolling required at 1440×900 or larger (scrolling acceptable below that). Three-zone vertical layout:

```
┌─────────────────────────────────────────────────────────┐
│  ZONE A — Top bar (fixed height, ~72px)                  │
├─────────────────────────────────────────────────────────┤
│  ZONE B — Main grid (flexible height, fills remaining)    │
│  ┌───────────────────────────┬─────────────────────────┐ │
│  │ Left column (~62% width)   │ Right column (~38%)      │ │
│  │  - CPU Timeline / Gantt    │  - Ready Queue table      │ │
│  │  - Playback controls       │  - Why-this-process panel │ │
│  │                             │  - Waiting/aging list     │ │
│  └───────────────────────────┴─────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│  ZONE C — Footer / algorithm & workload picker (~56px)    │
└─────────────────────────────────────────────────────────┘
```

- Left column carries the primary narrative (what's happening on the CPU, over time).
- Right column carries the explanation and supporting detail (what's queued, why the current decision was made).
- This matches how a viewer's attention should move: look at the timeline first, then ask "why," then look right for the answer.

### 4.2 Spacing scale

8px base unit, consistent throughout:

| Token | Value | Usage |
|---|---|---|
| `--space-1` | 4px | Tight internal spacing (icon-to-label gaps) |
| `--space-2` | 8px | Base unit — default gap between related elements |
| `--space-3` | 16px | Padding inside panels, gap between table rows |
| `--space-4` | 24px | Gap between panels |
| `--space-5` | 32px | Zone-level margins (top bar to main grid, etc.) |

### 4.3 Panel anatomy

Every panel (CPU Timeline, Ready Queue, Why-Panel, Waiting List) shares one visual pattern:

```
┌─ panel ──────────────────────────────────┐
│ [ICON] PANEL TITLE           [status dot]│  ← header: --bg-panel, 1px --border-default bottom
│───────────────────────────────────────────│
│                                            │
│   panel content, --bg-panel background     │
│                                            │
└────────────────────────────────────────────┘
   1px --border-default border, 4px border-radius, --space-3 internal padding
```

- Border-radius: **4px** everywhere (small, deliberately not fully rounded — sharp-ish corners suit the terminal aesthetic better than soft SaaS-style rounding).
- Panel header includes an optional small icon (can be a simple unicode glyph or inline SVG — ▸, ▪, ⏱ etc. — nothing decorative/skeuomorphic) and, where relevant, a live status dot (pulsing green = simulation active, static dim = idle/paused).
- No drop shadows. Depth is communicated through the `--bg-panel` vs `--bg-void` contrast and the `--border-default` outline, not shadows — shadows read as a "light source," which conflicts with an emissive/glowing terminal aesthetic (see Section 5 for how glow is used instead).

---

## 5. Component Specifications

### 5.1 Top bar (Zone A)

- Left: "CHRONOS" wordmark in `--text-display`, `--text-primary`, with a subtle text-shadow glow (`text-shadow: 0 0 8px rgba(57,255,20,0.5)`) — the one place a glow effect is used on text, reserved for the wordmark so it doesn't get overused.
- Directly below/beside the wordmark: "Adaptive CPU Scheduling Engine" in `--text-secondary`, `--text-h2`, no glow.
- Right side: three **stat tiles** in a row —
  - `CPU` — `--text-data-lg` percentage, small horizontal bar beneath it filled proportionally in `--state-running` green.
  - `PROCESSES` — count, `--text-data-lg`.
  - `CONTEXT SWITCHES` — count, `--text-data-lg`.
  - Each tile: label in `--text-label` above the number, `--space-2` gap, tiles separated by a 1px `--border-default` vertical divider.
- Far right: a small live status pill — "● SIMULATION LOADED" in `--state-ready` when a result JSON is loaded and idle, "● PLAYING" in `--state-running` with the pulse animation (6.5) while playback is active.

### 5.2 CPU Timeline / Gantt chart

- Track background: `--bg-inset`, full width of the left column, fixed height (~120px), horizontally scrollable if the simulation is longer than the panel width (with a visible thin scrollbar styled in `--border-active`).
- Each Gantt segment: filled rectangle in that process's palette color (2.3) at ~85% opacity, 1px border in the same color at full opacity, rounded 2px corners, PID label centered inside if the segment is wide enough (≥32px), otherwise label omitted and only visible on hover (6.3).
- **Playhead:** a 2px vertical line in `--border-active` (bright green) spanning the full track height, with a small triangle/flag at the top, positioned at `currentTick`. This is the single most important visual anchor in the whole dashboard — it must always be crisp and immediately findable.
- Tick ruler beneath the track: small tick marks + numbers every N ticks (adaptive to zoom level), `--text-dim`.
- Idle/gap ticks (CPU not running anything): rendered as a faint diagonal-hatch pattern in `--bg-inset`/`--border-default`, not just empty space — makes CPU idle time visually obvious rather than ambiguous with "not yet rendered."

### 5.3 Ready queue table

- Column headers: `--text-label` style (uppercase, letter-spaced), sticky if the table scrolls.
- Columns, in order: `PID`, `PRIORITY`, `BURST`, `WAIT`, `SCORE` (AARS runs only — column hidden entirely for non-adaptive algorithms rather than shown empty), `CLASS`.
- Each row: left edge carries a 3px vertical accent stripe in that process's palette color (2.3) — lets you visually track a process moving up/down the sorted list without reading the PID every time.
- `CLASS` column renders as a small pill badge (not plain text) — background `--bg-panel-raised`, text in the relevant tone (e.g. CPU-bound in a cooler/dimmer tone, interactive in a brighter one) — exact wording "CPU-BOUND" / "IO-BOUND" / "INTERACTIVE" / "UNKNOWN".
- Row for the currently-RUNNING process (if it briefly appears here during a transition) gets the full `--state-running` treatment (glow border) rather than the normal row style.
- Sort order (score/priority descending) is enforced by the data, not user-sortable in the MVP — keep the table simple and let the score itself be the story.

### 5.4 "Why this process?" panel

The highest-value panel per the PRD — gets the most generous spacing and the clearest hierarchy.

- Header: `WHY {PID}?` in `--text-h1`, the PID rendered in that process's palette color inline (e.g. "WHY **P2**?" with P2 colored cyan).
- Body: a vertical list of reason lines, each prefixed with a ✓ glyph in `--accent-positive` green, `--text-body` size.
- Any line carrying a numeric delta (e.g. "Waiting time: 8 ticks → aging bonus **+4**") renders that delta in `--accent-positive` with a leading `+` and a small ▲, or `--accent-negative` with `−` and ▼ for penalties — per the colorblind rule in 2.6, the sign and arrow are never dropped even though the color already implies it.
- Footer of the panel: the final computed score, larger (`--text-data-lg`), with a one-line breakdown shown as a compact horizontal stacked bar (each term's contribution as a proportional colored segment: green for positive terms, red for the penalty) — a lightweight visual "receipt" of the formula from PRD Section 6.1.
- Empty state (no process currently selected/running, e.g. at tick 0 before anything is scheduled): centered muted text, "Awaiting first scheduling decision…" in `--text-dim`, no ✓ list.

### 5.5 Waiting/aging indicator

- Compact list, one line per process currently accumulating a notable aging bonus: `P6   21 ticks waiting   →   +7 aging`.
- Uses `--state-waiting` amber for the process label if it's in true I/O WAITING state, or `--text-secondary` green-family if it's READY-but-aging (waiting for CPU, not I/O) — these are different situations and should look different.
- A process that crosses a "getting close to starvation" threshold (configurable, e.g. aging bonus ≥ 8) gets a `--accent-warning` amber left-border flash (see 6.6) the moment it crosses — a deliberate, noticeable one-time cue, not a persistent alarm state.

### 5.6 Playback controls

- Horizontal control bar beneath the Gantt chart: `[⏮ Step Back] [▶ Play / ⏸ Pause] [⏭ Step Forward] [🔁 Reset]` then a speed control, then a scrub bar.
- Buttons: `--bg-panel-raised` background, `--border-default` border, `--text-primary` icon/label, no fill by default. The Play/Pause button (primary action) is the one exception — filled solid `--text-primary` background with `--text-on-accent` (black) icon, so it's unambiguous which button is "the main one."
- Speed control: a small set of discrete steps (0.5×, 1×, 2×, 4×) as a segmented control rather than a free slider — simpler to implement and to reason about than continuous speed.
- Scrub bar: full width, track in `--bg-inset`, filled portion up to `currentTick` in `--border-active` green, draggable thumb as a small circle — mirrors the Gantt chart's own playhead position so the two stay visually in sync.

### 5.7 Algorithm & workload picker (Zone C, footer)

- Two dropdowns (`ALGORITHM`, `WORKLOAD`) styled as flat selects with `--border-default` borders, `--bg-panel` background, opening a `--bg-panel-raised` menu on click.
- A `RUN` button, same filled-primary treatment as Play/Pause, sits to the right of the dropdowns.
- This zone is deliberately the *least* visually loud part of the screen — it's a control surface you use once per run, not something to watch during playback, so it doesn't compete with the Gantt chart / why-panel for attention.

---

## 6. Interaction & Motion Specification

General motion principle: **fast and purposeful.** Nothing in this dashboard should feel "designed" in the sense of lingering, springy, delightful micro-interactions — it should feel like a responsive system tool. Default easing and duration unless stated otherwise:

```css
--transition-fast: 100ms ease-out;
--transition-base: 180ms ease-out;
--transition-slow: 300ms ease-out;
```

### 6.1 Playhead movement (Gantt chart)

- During playback, the playhead line's `left` position updates every tick. At normal speed (1×) this should read as smooth continuous motion, not discrete jumps — animate position changes with `--transition-fast` linear (not ease-out, so consecutive tick-to-tick moves don't visibly stutter-decelerate).
- On manual scrub or step-forward/back, the jump is instant (no transition) — a dragged scrub bar that "eases" toward your cursor position feels laggy and wrong.

### 6.2 Process transition (RUNNING hand-off)

When the scheduler switches which process is running (a context switch):

1. The previously-running Gantt segment's glow border fades out over `--transition-base`.
2. The newly-running segment's glow border fades in over `--transition-base`, slightly overlapping the fade-out (~50ms stagger) so there's never a moment with zero glow.
3. The ready-queue row for the newly-running process gets a one-time brief background flash (`--bg-panel-raised` → transparent over `--transition-slow`) to draw the eye to where it came from.
4. The why-panel content cross-fades (opacity only, `--transition-base`) to the new process's explanation — do not slide/translate the panel, since reading position should stay stable.

### 6.3 Gantt segment hover

- Hovering any Gantt segment (including narrow ones with no visible label): background lightens slightly (opacity 85%→100%), a tooltip appears above the segment showing `PID · start–end ticks · duration · reason` (the `reason` field from the JSON), `--transition-fast`.
- Hovering also highlights that same PID's row in the ready-queue table (if present) with the `--bg-panel-raised` treatment — cross-panel hover linking, `--transition-fast`.

### 6.4 Button states

| State | Treatment |
|---|---|
| Default | As specified per-component in Section 5 |
| Hover | Border brightens to `--border-active`; for filled buttons, background brightens ~10% |
| Active (pressed) | Scale `0.97`, `--transition-fast` — a small tactile "click" cue |
| Focus (keyboard) | 2px outline in `--border-active`, offset 2px — never remove focus outlines, this is a tool that may reasonably be operated by keyboard during a demo |
| Disabled | Opacity 40%, `--text-dim` text, no hover/active response, cursor `not-allowed` |

### 6.5 Live status pulse (top bar status pill, Section 5.1)

- While playing: the status dot uses a slow pulse — `opacity` animating `1 → 0.4 → 1` over a 1.6s ease-in-out infinite loop. Slow and subtle; this runs continuously during a demo and must never feel distracting or strobe-like.
- While paused/idle: static, no animation.

### 6.6 Aging warning flash (Section 5.5)

- One-time, not looping: the affected row's left border flashes `--accent-warning` amber at full opacity, then fades back to its resting border color over 1.2s (`ease-out`), triggered exactly once at the moment the process crosses the warning threshold — not re-triggered every tick it remains above threshold.

### 6.7 Panel load-in

- On initial page load / new JSON loaded: panels fade + rise in slightly (`opacity 0→1`, `translateY(8px)→0`) over `--transition-slow`, staggered ~40ms per panel in reading order (top bar → Gantt → ready queue → why-panel → footer). A single, restrained "the system is booting up" moment — not repeated on every playback action, only on genuine load.

### 6.8 Empty / loading states

- Before any JSON is loaded: the main grid shows a centered placeholder panel — "No simulation loaded. Choose an algorithm and workload below, then press RUN." in `--text-dim`, with a faint animated scan-line effect across the panel background (a horizontal 2px `--border-default` line sweeping top-to-bottom on a 3s loop) as the one purely-decorative flourish in the whole spec — justified because it's the one moment the screen would otherwise be dead empty.
- While the C++ binary is presumed running (if wired to the optional local-server stretch goal from PRD 7.7): a simple indeterminate progress bar in `--text-primary`, not a spinner — fits the horizontal/linear language of the rest of the UI (Gantt track, scrub bar) better than a circular spinner would.

---

## 7. Data Visualization Details (beyond the Gantt chart)

### 7.1 Score breakdown bar (why-panel footer, Section 5.4)

A single horizontal stacked bar, height ~20px, showing the AARS formula visually:

```
[ Base Priority ][ Aging ][ I/O Bonus ][ Response ][ Penalty ]
   dim green       green     green        green        red
```

- Segment widths proportional to each term's absolute contribution to the final score.
- The penalty segment (only negative term) is visually separated from the four positive segments by a 2px gap and rendered right-aligned in `--accent-negative`, making it unambiguous that it subtracts rather than adds.

### 7.2 Comparison charts (feeds from `analysis.py`, PRD Section 8.2)

These are generated as static images by Matplotlib, not live in the dashboard — but should follow the same palette for visual consistency between "live dashboard" and "final report" so a viewer doesn't experience a jarring style switch mid-presentation.

- Matplotlib figure background: `#000000`, axes background: `#0A0F0A`.
- Bar colors: one bar per **algorithm** (not per process) — use a fixed, separate 6-color subset of the neon palette (2.3) mapped to algorithm names (FCFS, SJF, RR, Priority, MLFQ, AARS), consistent across every comparison chart so "AARS is always cyan" (for example) throughout the whole report.
- Text/labels/axis: `--text-primary` green, gridlines: `--border-default`, using the same JetBrains Mono font family (Matplotlib can load `.ttf` files directly) so charts visually match the dashboard.
- `AARS`'s bar/line should NOT be artificially emphasized (no bold outline, no different chart type) — per PRD Section 2.4, results must be reported honestly including where AARS loses, and the chart styling should not editorialize.

> ✎ **EDIT ME:** A ready-made matplotlib style file (`chronos.mplstyle`) implementing this section is a natural first artifact to build once you're in `analysis/` — worth generating early so every chart you produce during Milestone 2 is consistent without re-styling each one by hand.

---

## 8. Implementation Notes

### 8.1 CSS custom properties

All tokens in Sections 2–4 should be declared once as CSS custom properties on `:root` in `style.css`, not hardcoded per-component — this is what makes the "swap one hex code" edit-me notes throughout this document actually cheap to act on.

```css
:root {
  /* Base */
  --bg-void: #000000;
  --bg-panel: #0A0F0A;
  --bg-panel-raised: #0F1A0F;
  --bg-inset: #050805;
  --border-default: #1A3D1A;
  --border-active: #39FF14;
  --text-primary: #39FF14;
  --text-secondary: #8FE68F;
  --text-dim: #3D5C3D;
  --text-on-accent: #000000;

  /* Status */
  --state-running: #39FF14;
  --state-ready: #8FE68F;
  --state-waiting: #FFD23F;
  --state-terminated: #3D5C3D;
  --state-new: #1A3D1A;

  /* Semantic accents */
  --accent-positive: #39FF14;
  --accent-negative: #FF3E5C;
  --accent-warning: #FFD23F;
  --accent-info: #0FF0FC;

  /* Process palette */
  --proc-1: #39FF14;
  --proc-2: #0FF0FC;
  --proc-3: #FF3EC9;
  --proc-4: #FFB300;
  --proc-5: #3E9EFF;
  --proc-6: #FF5C33;
  --proc-7: #B15CFF;
  --proc-8: #D4FF3E;

  /* Motion */
  --transition-fast: 100ms ease-out;
  --transition-base: 180ms ease-out;
  --transition-slow: 300ms ease-out;

  /* Font */
  --font-mono: 'JetBrains Mono', 'Fira Code', 'SF Mono', 'Cascadia Code', Consolas, 'Courier New', monospace;
}
```

### 8.2 Suggested build order (pairs with PRD Milestone 1)

1. Get `:root` tokens + base page background/typography in place first — even an unstyled dashboard should already "feel" like ChronOS.
2. Top bar + stat tiles (simplest components, immediate visual payoff).
3. Static (non-animated) Gantt chart against the fake JSON from PRD Milestone 0 — get the layout and colors right before adding the playhead/animation.
4. Ready queue table.
5. Why-panel (static first, then wire up the cross-fade from Section 6.2 once panel transitions exist).
6. Playback controls + playhead animation last — this is the part that depends on everything else already rendering correctly.

### 8.3 What this document deliberately does not specify

Consistent with the PRD's own non-goals: no responsive/mobile breakpoints beyond "don't break above 1280px," no dark/light theme toggle (jet-black is the only theme), no icon library dependency (use inline SVG or unicode glyphs to avoid adding a font-icon build dependency), no animation library dependency (everything in Section 6 is achievable with plain CSS transitions/keyframes).
