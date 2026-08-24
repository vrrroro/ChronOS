# ChronOS — Engineering Design Requirements Document (EDRD)

**Visual & Interaction Design Spec for the Dashboard**

Author: Rohit
Draft date: August 22, 2026
Status: Draft v1 — companion to `PRD.md`, describes how the dashboard (Section 7 of the PRD) should actually look and behave
Scope: This document covers **only** the dashboard's visual design and interaction behavior. It does not repeat scheduling logic, data formats, or milestones — see `PRD.md` for those. Read `PRD.md` Section 7 first; this document is the detailed spec for building it.

> ✎ **EDIT ME:** Same convention as the PRD — every concrete value here (hex codes, pixel sizes, durations) is a real, implementable starting point, not a law. Change anything that looks wrong once you see it rendered.

> **Logged deviation — native app pivot (2026-08-23, explicit user request):** the dashboard is no longer a web page. It is a native Qt 6 / QML desktop app (`app/qml/`, see `ARCHITECTURE.md` §5 and `CLAUDE.md`); `dashboard/` has been deleted. Throughout this document, read "CSS" as "QML," "DOM element" as "QML Item," and "page" as "window" — the *intent* of every component spec is unchanged. Three structural changes ship with the pivot and are documented in place: the picker is now a **full-screen two-step flow**, not a footer zone (§5.7); a **process progress ticker** panel has been added (§5.8); tokens live in a **QML singleton**, not CSS custom properties (§8.1); and the intro is an **auto-playing reveal**, not a scroll-driven one (§9).

> **Logged deviation — Terminal CLI design system (2026-08-24, explicit user request):** the app adopts a single named visual system, **Terminal CLI**: jet black, phosphor green, zero radius, 1px ASCII-framed panes, faint CRT scanlines, a blinking block cursor, shell metaphors (`>`, `$`, `~`, `[OK]`, `--flags`), and raw `[||||||…]` character bars in place of smooth chart chrome. §1 (intent), §2.1 (palette), §2.3 (process identity), §2.4a (glow), §2.7 (new — surface language) and §3 (typography) are rewritten for it. Three consequences worth stating outright:
>
> 1. **Two bundled type families, split hard by role** (§3.1): a display serif in exactly four places, **JetBrains Mono** for everything else. Both live in `app/fonts/`. This supersedes both the mono-only spec this section originally carried and the later sans-serif system-stack override.
> 2. **`GlowFrame.qml`'s layered-border glow is deleted** (§2.4a). Stacked low-opacity thick borders read as visible concentric outlines rather than as light — the user rejected them as "tacky." They are replaced by a real blurred phosphor bloom (`QtQuick.Effects` `MultiEffect`, which the Qt 6.11 install this project builds against ships) plus inverted-video hover.
> 3. **Zero radius, 1px frames, ASCII chrome and character-bar readouts** are the surface language (§2.7), and the list of permitted effects is closed.

> **Logged deviation — palette, type and motion revision (2026-08-24b, explicit user request):** eight changes, all requested directly after seeing the previous build run. The Terminal CLI system above is unchanged in its structure; what changed is that it is no longer monochrome, no longer set in Fraunces, and no longer moves at the speed it did.
>
> 1. **Display face: Fraunces → Instrument Serif** (§3.1, §3.2). It ships Regular/Italic only, so `display` and `h0` grew rather than bolded.
> 2. **The bloom is much dimmer and now flickers** (§2.4a, §6.10). Halo opacity `0.5 → 0.22`, plus a shallow irregular CRT flicker on display type only.
> 3. **Gantt tick labels moved onto the segment boundaries** (§5.2), replacing the fixed every-fifth-tick ruler.
> 4. **`ProcessClass::UNKNOWN` is no longer the normal outcome** — an engine fix, not a design one, but it is what the `CLASS` column actually shows (`PRD.md` §6.3, issue #3).
> 5. **The why-panel owns cyan, the verdict owns magenta** (§2.5, §5.4) — the fix for "too much green in one page."
> 6. **Per-process identity is neon hue *and* glyph again** (§2.3), replacing the green brightness steps; Gantt PID labels are centered and drawn in the process's own hue.
> 7. **1× playback is 0.6 ticks/second** (§6), down from 2 — this is a teaching instrument and the why-panel has to be readable at default speed.
> 8. **Ticker bars fill as liquid** (§6.9, `FluidBar.qml`) — the one logged exception to §2.7(7)'s character-bar rule — and hovering one raises a **process HUD** (§5.10).
>
> Non-green color is therefore back in the system, deliberately and under rules: every hue owns exactly one role (§2.5), every role is redundantly encoded in a word, sign or glyph (§2.6), and the palette table in §2.1 is still closed.

> **Logged deviation — glyph removal, green-only frames, and playhead speed fix (2026-08-25, explicit user request):** five changes, all reported as concrete problems after using the running build. Point 1 directly reverses point 6 of the 24b list above.
>
> 1. **Per-process identity dropped the glyph channel** (§2.3) — hue alone now, no `█ ▓ ▒ ░ ║ ≡ · #` fill character per process anywhere (Gantt, ticker, ready queue, HUD). `Theme.procGlyph`/`procGlyphs` no longer exist.
> 2. **The ticker's `FluidBar` fill is now tiny segmented blocks**, not one continuous rectangle (§6.9) — still liquid via independently-eased segments and a sheen spanning the whole filled run, just visually divided into cells.
> 3. **Every pane border is green, always** (§2.4) — `WhyPanel`'s cyan and `AgingIndicator`'s amber accent borders are gone; role hues now govern only pane *content*, never the frame.
> 4. **The why-panel's chosen-process verdict is colored by that process's own hue**, not a fixed magenta (§2.3) — the same color it wears in the Gantt chart and ticker, so a process can be tracked by color across every panel.
> 5. **The Gantt playhead's move animation now scales its duration with the current playback speed** (§5.2), not the fixed 1× rate — at higher speed multipliers it previously fell further and further behind the actual tick instead of tracking it.

---

## 1. Design Intent

### 1.1 One-sentence brief

A jet-black phosphor terminal — ASCII-framed panes, a blinking block cursor, raw character-bar readouts — for watching a CPU scheduler think. It should read less like a dashboard *about* an operating system and more like a tool running *inside* one; dense enough to feel real, legible enough to read from a laptop during a live viva.

### 1.2 Reference points

- **Aesthetic inspiration:** a clean, usable ZSH/BASH shell on a green-phosphor CRT — and specifically the *tooling* that lives in one: `htop`, `btop`, `k9s`, `tmux` splits, `vim` status lines. Not "Matrix rain," which is the cliche version of this and is explicitly out of scope (§2.7).
- **ASCII, but structural:** the original plan's `╔══╗` mockups are closer to a literal target now than they were. Pane *frames* stay real 1px-bordered QML Items — they survive window resizing, and literal box-drawing art does not. But pane **title bars, dividers, bar fills and empty states are real characters**: `+--- READY QUEUE ---+`, `================`, `[||||||····]`, `> no process ready_`. The dividing rule: characters for anything that scales with *content*, borders for anything that scales with the *window*.
- **Primary context:** a laptop screen (1366–1920px wide), shown live during a demo/viva. Not designed for mobile; reasonable behavior down to ~1280px is enough.

### 1.3 Design principles

1. **Encode in words, brackets and signs before reaching for hue for anything that isn't per-process identity.** Every §2.5 *role* (warnings, deltas, the why-panel's reasoning) is redundantly encoded in a bracketed word or a sign, never carried by hue alone. Per-process identity (§2.3) is the one deliberate exception, as of 2026-08-25: it's hue-only, with no fallback encoding, traded for a quieter, simpler visual at explicit user request.
2. **Every panel earns its position through information hierarchy**, not decoration. The CPU timeline and the "why this process" panel are the two panels a viewer's eye should land on first — everything else supports them.
3. **State is always visible.** A viewer glancing at the screen at any random moment should be able to tell, without explanation: what's running, what's waiting, and why the scheduler just did what it did.
4. **Motion explains, it doesn't decorate.** Every animation in Section 6 exists to make a state change easier to follow (a preemption, a score change, a new arrival) — never purely ornamental.

---

## 2. Color System

### 2.1 Base palette (Terminal CLI, 2026-08-24; accent set added 2026-08-24b)

A phosphor-monitor palette. High contrast is non-negotiable. Note that `bgVoid` is `#0A0A0A` and **not** pure `#000000`: a hair above black, so the scanline overlay (§2.7) has something to darken against instead of clipping into nothing.

| Token | Hex | Usage |
|---|---|---|
| `bgVoid` | `#0A0A0A` | Window background — and also the background of every pane. Panes are defined by their **border**, never by a lighter fill. |
| `bgPanelRaised` | `#12180F` | The only lifted surface in the app: hovered/selected rows, active list items |
| `bgInset` | `#060806` | Recessed tracks — the Gantt lane behind the bars, the scrub track |
| `borderMuted` | `#1F521F` | Default 1px pane borders, dividers, grid lines. **Borders only, never text** (2.2:1 on `bgVoid`) |
| `borderActive` | `#33FF00` | Focused/active pane border, playhead, cursor |
| `textPrimary` | `#33FF00` | Phosphor green — headings, pane titles, key values, prompts, the RUNNING process |
| `textSecondary` | `#21A600` | Dimmed green — body copy, prose, table cell values (~5.9:1 on `bgVoid`) |
| `textDim` | `#1E8F10` | Tertiary — empty states, timestamps, disabled controls, status strips (~4.7:1; this is the **floor**) |
| `textOnAccent` | `#0A0A0A` | Text on a solid green fill — inverted video: filled buttons, RUNNING badges |
| `accentAmber` | `#FFB000` | Warnings, WAITING state, aging-threshold alerts |
| `accentError` | `#FF3333` | Errors, and negative score contributions. Always paired with `−` / `▼` |
| `accentCyan` | `#00E5FF` | The "why" channel — the scheduler's reasoning (§5.4) |
| `accentMagenta` | `#FF3EC9` | The chosen process — the single most important fact on screen |
| `accentBlue` | `#4D9FFF` | Structural / reference data: completed work, static facts |
| `accentPositive` | `#33FF00` | Positive score contributions. Always paired with `+` / `▲` |

**Green is the chrome color, not the only color** (revised 2026-08-24b, on explicit user feedback that a running dashboard was "too much green in one page"). Everything structural — borders, pane titles, prose, the shell prompt — stays green, and that is what still makes the app read as a terminal. What changed is that the *high-value* things no longer render in the same hue as the frame around them: a screen drawn in a single color gives a viewer no way to rank what matters, so the classic ANSI-terminal accent set now separates roles (§2.5) and tells processes apart (§2.3).

These are phosphor and ANSI hues — colors a real terminal already has — not arbitrary brand colors, which is why adding them does not cost the aesthetic. **The table is still closed.** No gradient fill on a surface, no tinted greys, no hue outside this table. If a component needs a color that isn't here, that is a spec question, not an implementation decision.

> ✎ **EDIT ME:** `#33FF00` is the Terminal CLI system's stated primary. If it reads as too acid on your actual projector, `#00FF41` (cooler, Matrix-leaning) and `#4AF626` (marginally softer) are drop-in swaps — change the one token in `Theme.qml` and every derived shade in §2.3 should be re-derived from it, not hand-picked.

### 2.2 Status colors (process state)

These map to the `State` enum in `PRD.md` Section 5.1 and must be used consistently everywhere a process's state is shown (ready queue table, Gantt chart border, status badges).

| State | Token | Hex | Notes |
|---|---|---|---|
| RUNNING | `stateRunning` | `#33FF00` | Full-brightness phosphor — the process actually on the CPU is always the brightest thing on screen, and the only row text carrying a bloom (§2.4a). Badge reads `[RUNNING]` |
| READY | `stateReady` | `#21A600` | Dimmed green — waiting its turn, calm. Badge reads `[READY]` |
| WAITING (I/O) | `accentAmber` | `#FFB000` | Terminal amber — the design system's one warm accent, signalling "blocked." Always paired with a `[WAIT]` badge so it is never hue-only |
| TERMINATED | `stateTerminated` | `#1F521F` | Dimmed to near-background — done, no longer competing for attention. Badge reads `[DONE]` |
| NEW (not yet arrived) | `stateNew` | `#12300F` | Barely-there outline only — hasn't entered the system yet |

### 2.3 Per-process identity (revised 2026-08-25 — neon hue only, one channel)

Each process is assigned a neon hue and **nothing else**. There is no per-process glyph or symbol any more.

This supersedes the 2026-08-24b hue-and-glyph scheme (below, for history) at explicit user request: the second channel added visual noise — a distinct fill character per process, repeated across every bar and segment — without being asked for, and the user wants every process rendered in the *same shape* everywhere (a plain `P<pid>` label, a solid/segmented fill) with color as the only differentiator. It also supersedes the glyph-plus-green-brightness rule of 2026-08-24, and the hue-only palette that preceded that (this is now the third and current stop on that history).

| Slot | Hue name | Hex |
|---|---|---|
| 0 | phosphor green | `#33FF00` |
| 1 | cyan | `#00E5FF` |
| 2 | magenta | `#FF3EC9` |
| 3 | amber | `#FFB000` |
| 4 | blue | `#4D9FFF` |
| 5 | orange | `#FF7A29` |
| 6 | violet | `#C77DFF` |
| 7 | lime | `#D4FF3E` |

Green leads the palette because it is the app's own color, and the remaining seven are spaced around the wheel so **adjacent PIDs never sit adjacent in hue** — P1 and P2 are the pair a viewer most often has to tell apart, so they are the pair placed furthest apart.

Assignment rule: `slot = pid % 8`, deterministic, so a given PID renders identically everywhere — Gantt segment, ready-queue row, ticker bar, process HUD, why-panel verdict.

Where the hue is used — always as the color of the `P<pid>` text itself, or of the fill it identifies, never as a separate swatch or symbol next to it:

- **Gantt segments (§5.2):** the segment border and the centered `P<id>` label are drawn in the process's hue. No fill glyph — the segment body is otherwise flat `bgVoid`.
- **Ticker bars (§5.8):** the segmented liquid fill (§6.9) is the process's hue; the `P<id>` label to its left is that same hue in every state (running, waiting, done) — not dimmed to a generic color when the process isn't currently running, so a viewer can track one process's color continuously across the run.
- **Ready-queue rows:** the `PID` column text itself is the process's hue.
- **Why-panel verdict (§5.4):** `"P<pid> RUNS NEXT"` is drawn in that process's hue, not a fixed accent — this is the same color the process wears everywhere else, so "which process is this" reads as one consistent color across the whole dashboard rather than a WhyPanel-only convention.

Two hues here (`#FFB000` amber, `#4D9FFF` blue) are also role colors in §2.5. That overlap is safe because identity always appears **attached to a process** — on its bar, its row, its label — and never on a standalone badge or a signed delta, which is where the role meaning lives. See §2.4.

> **History — 2026-08-24b's two-channel version (superseded):** each process briefly also carried an ASCII fill glyph (`█ ▓ ▒ ░ ║ ≡ · #`, one per slot) alongside its hue, reasoned as an accessibility fallback for greyscale/projector/deuteranopia viewing. Removed 2026-08-25 at explicit user request. If that accessibility concern needs revisiting later, don't just re-add the old glyph table by default — ask first, since removing it was a deliberate simplification, not an oversight.

### 2.4 Identity vs. state

Identity (§2.3 — hue) and state (§2.2 — color) are two separate channels and must stay separate:

- **Identity** drives a process's bar fill, segment border, and PID label. Constant for the whole run, regardless of what the process is doing.
- **State** drives bracketed badges, status text and pane borders — `textPrimary` for RUNNING, `accentAmber` for WAITING, `borderMuted` for TERMINATED. Badges are always **bracketed words** (`[RUNNING]`, `[WAIT]`, `[DONE]`), never hue alone.
- A running P3 therefore reads as: a segmented bar filling in amber `#FFB000` with its `P3` label in that same amber (identity), inside a pane whose border has snapped to `borderActive` green, with a `[RUNNING]` badge in `textPrimary` (state).
- **State never borrows an identity hue, and identity never borrows a state hue.** This is what keeps the reintroduced palette from turning ambiguous: P3's amber bar is not a WAITING signal, because a WAITING signal is a bracketed `[WAIT]` badge and a bar is not a badge. Intensity, not hue, is how a bar shows state — the running process's fill is at full strength and every other bar is dimmed (§6.9).
- **Pane borders never carry a role hue either (revised 2026-08-25, explicit user request).** Every `TerminalPane` border is green — `borderActive` when that pane is active/engaged, `borderMuted` otherwise — full stop, regardless of what role-colored content lives inside it. `WhyPanel` (cyan) and `AgingIndicator` (amber) previously claimed their own accent border under §2.5's role system; that's gone. The role hue still governs *content* inside the pane — the chosen-process verdict, warning badges, reason deltas — just never the frame around it.

### 2.4a Phosphor glow (2026-08-24, replaces the layered-border glow; dimmed + flicker added 2026-08-24b)

**Deleted:** `GlowFrame.qml`'s original approach of stacking two or three low-opacity, thick-bordered rectangles behind a crisp border. At any real size you can see exactly where each ring begins and ends, so it reads as a set of concentric outlines rather than as emitted light. That is the "tacky" the user called out, and tuning the opacities does not fix it — the technique itself is the problem.

**Replacement — phosphor persistence, by exactly two mechanisms:**

1. **Text bloom.** Display text carries a soft halo: a `MultiEffect` (`QtQuick.Effects`) with `blurEnabled: true` over a copy of the text, composited *under* the crisp glyphs so glyph edges stay sharp. Implemented once in `PhosphorText.qml`; nothing else rolls its own.

   **Strength, revised 2026-08-24b: much dimmer.** The halo runs at `0.22 × bloom` opacity, down from `0.5`. At the old strength the glow competed with the glyphs instead of sitting behind them, so display type read as washed out — as a lighting effect applied *to* the type rather than as type that emits light. Dimmer is not a compromise here; it is what makes it read as phosphor at all. Applied to display type and to `textPrimary` at `h1` and larger. Never applied to `textSecondary`/`textDim` body copy — blooming small dim text only makes it muddy.

2. **Inverted video.** Interactive elements do not glow harder on hover; they **invert**. Background fills with `textPrimary`, label flips to `textOnAccent`, border holds. This is how a real terminal shows selection: instant, unmistakable, and free of blur passes.

**CRT flicker** (added 2026-08-24b) rides on top of mechanism 1 and is not a third mechanism — it modulates the bloom's opacity, it does not draw anything. A phosphor tube is subtle *and unsteady*; a perfectly stable halo is the tell that it is a filter. Spec in §6.10; carried only by display type.

Hard rules:

- **No drop shadows anywhere.** Not on panes, not on buttons, not on overlays.
- **No border-halo glow on containers.** Panes are 1px lines. A pane signals "active" by switching `borderMuted` → `borderActive`, not by growing an aura.
- Any bloom must show **no visible edge or banding**. If you can see where the blur stops, it is wrong.
- **Bloom is faint by default.** If the halo is the first thing you notice about a piece of text, it is too strong. The splash wordmark (§9) is the one place it runs hot, and even there it runs hot by having a wider blur radius, not a higher opacity.
- The continuous animations in the app are the **cursor blink** (§2.7), the **CRT flicker on display type** (§6.10), the **splash bloom pulse** (§9) and the **liquid fill on the running process's bar** (§6.9). Operational dashboard controls never pulse.

### 2.5 Semantic accent colors (rewritten 2026-08-24b — each hue owns one role)

| Purpose | Token | Hex | Where it appears |
|---|---|---|---|
| Aging bonus / positive score contribution | `accentPositive` | `#33FF00` | Score deltas — always with `+` / `▲` |
| CPU burst penalty / negative score contribution | `accentError` | `#FF3333` | Score deltas — always with `−` / `▼` |
| Warning (approaching starvation threshold), WAITING state | `accentAmber` | `#FFB000` | Aging meters, `[WAIT]` badges |
| **The scheduler's reasoning** | `accentCyan` | `#00E5FF` | Why-panel pane border, `✓` reason markers, the why-panel's own chrome |
| **The chosen process** | `accentMagenta` | `#FF3EC9` | The why-panel verdict line (`P3 RUNS NEXT`), the winning candidate |
| Structural / reference data | `accentBlue` | `#4D9FFF` | `[DONE]` readouts, completed work, static facts in the process HUD |

**The rule that makes this readable rather than merely colorful: one hue, one role, everywhere.** Cyan is never used for a warning; magenta is never used for a completed process. A viewer learns six associations once and they hold on every screen.

The two most important roles get the two hues furthest from the app's green chrome, on purpose. The why-panel is the highest-value panel in the product (PRD §7.4) and used to be green-on-green inside a green frame, which is precisely why the whole dashboard read as undifferentiated. Cyan gives the reasoning its own channel, and magenta reserves the loudest color in the system for the single fact the panel exists to deliver.

`textSecondary` green remains the neutral/informational tone. Green is still what the app is made of — these accents mark the exceptions.

**Two hue uses are categorical, not role-based, and are exempt from the one-hue-one-role rule:** per-process identity (§2.3), and the `CLASS` badge in the ready-queue table and process HUD (`[CPU_BOUND]` magenta, `[IO_BOUND]` cyan, `[INTERACTIVE]` amber, `[BALANCED]`/`[PENDING]` dim). Both are exempt for the same reason: they are always **attached to a specific process and always spelled out in words**, so the hue is a fast lookup rather than the carrier of the meaning. A magenta `[CPU_BOUND]` badge cannot be misread as "this is the chosen process," because the chosen process is announced by a magenta *verdict line* in the why-panel, and the badge says `CPU_BOUND` on it. Standalone signals — deltas, warnings, state — never work this way and always keep their one role.

### 2.6 Contrast & accessibility notes

- `#33FF00` on `#0A0A0A` is ~14.6:1 — well above WCAG AAA, safe at any size. The Terminal CLI system's claim that "bright green on black exceeds AA" holds for `textPrimary` and `textSecondary`. It does **not** hold for `borderMuted`, see below.
- `#1E8F10` (`textDim`) on `#0A0A0A` is ~4.7:1 — meets AA, and is the deliberate **floor** for readable text. Empty-state copy (`> no process ready_`) counts as readable and uses `textDim`, never anything dimmer.
- `#1F521F` (`borderMuted`) is ~2.2:1 and is **not a text color**. The Terminal CLI reference system lists it as `muted` for "borders/inactive text"; we take the borders half and reject the text half. Inactive and disabled *text* uses `textDim`.
- Any text sitting on a filled green surface (an inverted-video button, a RUNNING badge, a filled Gantt segment) uses `textOnAccent` (`#0A0A0A`). Never green-on-green.
- The scanline overlay (§2.7) is capped at 0.10 alpha precisely so it cannot push any ratio below AA. Do not raise it.
- Every §2.5 role hue and §2.3 identity hue clears AA on `#0A0A0A` (computed, not estimated): lime `#D4FF3E` 17.1:1, green `#33FF00` 14.6:1, cyan `#00E5FF` 12.9:1, amber `#FFB000` 10.8:1, orange `#FF7A29` 7.6:1, violet `#C77DFF` 7.4:1, blue `#4D9FFF` 7.3:1, magenta `#FF3EC9` 6.4:1, red `#FF3333` 5.4:1. Magenta and red are the two nearest the `textDim` floor of 4.7:1 — neither is used below `data` size, and neither is ever the *only* carrier of its meaning.
- Colorblind consideration: green/red is the hardest pairing for deuteranopia, and this system leans on it for score deltas. **Always pair the color with a `+`/`−` sign and a `▲`/`▼`**, never hue alone. Per-process identity (§2.3) is hue-only as of 2026-08-25 and has no fallback channel for a deuteranopic viewer or a greyscale render — that tradeoff was made explicitly, at the user's request, in exchange for a simpler, quieter visual (see §2.3's history note). Every §2.5 *role*, unlike identity, is still redundantly encoded: `[DONE]` is a word, not just blue; a `✓` marks a reason, not just cyan.

---

### 2.7 Surface language: Terminal CLI (new, 2026-08-24)

These treatments *are* the aesthetic — not optional decoration, and not a licence to invent more. The list is closed.

1. **Zero radius, everywhere.** `radius: 0` on every pane, button, badge, bar, track and inset. There are no rounded corners in this application. (Replaces the `radius: 4` currently on every component.)
2. **1px frames.** A pane is a 1px `borderMuted` line on `bgVoid` — no fill step, no shadow. Solid for structural panes; `dashed` is available for secondary or inactive groupings. An active pane switches its border to `borderActive`.
3. **ASCII title bars.** Every pane is titled like a shell pane: `+--- READY QUEUE ---------------+`, dashes filling the available width. Where a title needs more emphasis, invert it instead: a solid `textPrimary` bar with a `textOnAccent` label.
4. **The cursor is the heartbeat.** A `█` block cursor blinks at ~530ms on the splash prompt, on empty states, on the currently-RUNNING row, and in any focused input. It is the only continuous animation in the operational UI.
5. **Shell metaphors in copy.** Prompts (`>`, `$`, `chronos@aars:~$`), flags (`--algorithm fcfs`), status codes (`[OK]`, `[WAIT]`, `[ERR]`, `[DONE]`, `[RUNNING]`). Empty states read like shell output: `> no process ready_`. Button labels are bracketed: `[ RUN ]`, `[ ▶ PLAY ]`, `[ ↺ RESET ]`.
6. **ASCII separators.** `--------` between related rows, `========` between sections, `//` for inline breaks — repeated characters sized to their container, not `Rectangle` hairlines.
7. **Raw bar readouts.** Quantities read as character bars, never as smooth fills: `[||||||||······] 61%`. Score-breakdown bars, aging meters, the workload-card load factor and the scrub track all use plain `|`/`·` fill characters (not a per-process glyph — §2.3 identity is hue-only). No gradients, no rounded caps.

   **Logged deviation (2026-08-24b, revised 2026-08-25) — the process ticker's progress bars are not character bars.** Everything above is read as a *value*; the ticker bars (§5.8) are read as *motion* — the entire point of that panel is watching work drain away. A glyph bar can only move in whole-cell steps, so at one tick per cell it is a row of characters switching on and off, which is the opposite of the fluid feel the user asked for. `FluidBar.qml` therefore fills via tiny segmented blocks that each ease their own width independently (§6.9) while keeping every other Terminal CLI property: zero radius, flat color, 1px frame, no gradient, no rounded cap. Gantt segments (§5.2) have no fill glyph at all as of 2026-08-25 — just a hue-colored border and centered `P<id>` label on flat `bgVoid`.
8. **CRT scanlines.** A fixed, full-window horizontal line pattern (~3–4px period, **≤ 0.10 alpha**) as the front-most layer, above everything. Must be `enabled: false` so it can never swallow a click.
9. **Typewriter reveal.** Screen-level headings and the why-panel's verdict line type in character-by-character on first appearance (~18ms/char, skippable on click or keypress). Once per screen entry only — never on data that updates every tick, which would be unreadable.
10. **Strict character grid.** Columns align to the mono advance width. Anything tabular is laid out in fixed character-count columns rather than by measuring proportional text.

**Z-order, back to front:** void → pane borders and fills → pane content → text bloom → scanline overlay.

**Explicitly out of scope:** Matrix rain, glitch-shatter effects, fake "boot log" filler text, typing of content the user did not trigger, and any third visual-effects mechanism beyond the two in §2.4a.

---

## 3. Typography

### 3.1 Font stack (rewritten 2026-08-24b — Instrument Serif display + JetBrains Mono everything else)

Two families, both bundled in `app/fonts/`, split hard by role. No third family, no system-font fallback chain, and no hardcoded family string anywhere outside `Theme.qml`.

**JetBrains Mono — the default, and the answer unless a rule below says otherwise.**

Pane titles, labels, buttons, prose, PIDs, tick counters, table data, badges, bar fills, status strips, empty states, and every chart label `analysis/` renders. The Terminal CLI system's "monospace supremacy" is taken seriously here, and it is load-bearing rather than stylistic: §2.7's character bars, ASCII title bars and fixed-column tables only line up because the advance width is constant. JetBrains Mono specifically, because its disambiguated `0`/`O` and `1`/`l`/`I` matter directly when a viewer is reading PIDs and tick numbers off a projector.

**Instrument Serif — display type only, in exactly four places:**

1. The splash CHRONOS wordmark (§9)
2. The dashboard title lockup (§5.1)
3. Screen-level headings on the algorithm and workload pickers (§5.7)
4. The why-panel's one-line verdict, e.g. `P3 RUNS NEXT` (§5.4)

**This replaces Fraunces (2026-08-24b, explicit user request.)** Instrument Serif is a high-contrast display serif with tight spacing and tall, narrow proportions — closer to a Didone editorial headline than to Fraunces' soft, wonky character. Over a strict phosphor terminal it reads as the printed word set against machine output, which is the same tension the design has always rested on, drawn sharper: crisp modulated strokes next to a fixed-width grid.

Two practical consequences of the swap, both already handled in code:

- **It ships Regular and Italic only** — no Black cut and no variable axes. So the display tokens do not request weight 900 or drive `WONK`/`SOFT`/`opsz`; setting either would silently synthesise a fake bold, which on a high-contrast serif smears exactly the thin strokes that make it a display face. It carries itself at display size instead, which is why §3.2 raises `display` and `h0` rather than bolding them.
- **Four places still means four.** Instrument Serif never touches a number, a table, a button or a line of prose — it has no tabular figures, and its proportional digits would visibly jitter on every tick.

Files (both SIL OFL — `OFL-InstrumentSerif.txt` and `OFL-JetBrainsMono.txt` stay in the folder; that is a redistribution condition, not clutter):

| File | Use |
|---|---|
| `JetBrainsMono-Regular/Medium/SemiBold/Bold/ExtraBold.ttf` | Every UI weight |
| `JetBrainsMono-Variable.ttf` | Available if a weight needs interpolating; the statics are preferred |
| `InstrumentSerif-Regular.ttf` | All four display placements |
| `InstrumentSerif-Italic.ttf` | Bundled and registered; not currently used by any component |

Loading: register every file with `QFontDatabase::addApplicationFont` in `app/main.cpp` **before** `QQmlApplicationEngine` is constructed, then `QGuiApplication::setFont` to JetBrains Mono, so mono is what anything unstyled inherits by default. `Theme.qml` exposes `fontMono` and `fontDisplay` plus the role weights in §3.2.

### 3.2 Type scale (strict, grid-snapped; display sizes revised 2026-08-24b)

Sizes snap to a 4px baseline and line heights are whole multiples of it, so rows stack on a character grid instead of drifting.

| Token | Family | Size | Line height | Weight | Treatment | Usage |
|---|---|---|---|---|---|---|
| `display` | Instrument Serif | 128px | 128 | 400 Regular | uppercase, tracking `+1px`, wide bloom + flicker | Splash wordmark |
| `h0` | Instrument Serif | 38px | 44 | 400 Regular | uppercase, bloom + flicker | Dashboard title, picker screen headings, why-panel verdict |
| `h1` | JetBrains Mono | 16px | 24 | 700 Bold | UPPERCASE, tracking `0.10em`, bloom | Pane title bars |
| `h2` | JetBrains Mono | 14px | 20 | 600 SemiBold | UPPERCASE, tracking `0.06em` | Sub-labels inside a pane |
| `body` | JetBrains Mono | 14px | 24 | 400 Regular | sentence case | Why-panel explanation lines, descriptions |
| `data` | JetBrains Mono | 14px | 20 | 500 Medium | fixed character-count column | Table cell values |
| `dataLg` | JetBrains Mono | 28px | 32 | 800 ExtraBold | width-reserved | Stat hero numbers (CPU %, switches) |
| `label` | JetBrains Mono | 12px | 16 | 600 SemiBold | UPPERCASE, tracking `0.12em` | Column headers, button labels, badges |
| `micro` | JetBrains Mono | 11px | 16 | 400 Regular | UPPERCASE, tracking `0.12em` | Status strips, pane chrome, timestamps |

`display` and `h0` grew (112→128, 32→38) in the 2026-08-24b swap. Instrument Serif is a narrower, lighter face than Fraunces Black, so matching the old presence meant more size rather than more weight — and weight was not available to spend (§3.1). The splash still clamps to `min(sizeDisplay, width / 9.5)`: a display element that clips is worse than one that shrinks.

Because everything tabular is monospaced, numeric columns are sized in **characters**, not pixels: measure one `0` advance at `data` size and multiply. A `WAIT` column that can reach four digits is four characters wide plus padding — it never reflows, and no number ever shifts its neighbours.

### 3.3 Letter-spacing & case conventions

- Pane titles and column headers: UPPERCASE with the tracking given in §3.2, wrapped in ASCII chrome (`+--- READY QUEUE ---+`) per §2.7.
- Button labels: UPPERCASE and bracketed — `[ RUN ]`, `[ ▶ PLAY ]`. The brackets are characters in the label string, not a drawn border.
- Status codes are bracketed and uppercase: `[OK]`, `[WAIT]`, `[ERR]`, `[DONE]`, `[RUNNING]`.
- Body/explanation text: normal sentence case — uppercase prose is harder to read and the why-panel explanations are meant to be genuinely read, not just glanced at.
- Process IDs always rendered as `P1`, `P2`, etc. (no lowercase `p1`), consistent with the PRD's own convention.

---

## 4. Layout & Spacing

### 4.1 Grid structure

Single-page dashboard, no scrolling required at 1440×900 or larger (scrolling acceptable below that). Three-zone vertical layout:

> ✎ **Logged deviation (post-Milestone-1, explicit request):** an intro splash section now precedes this three-zone layout — see the new §9 below. It's the one place in the app that scrolls (real, user-driven scroll, not just "acceptable below 1440×900" — required at any size). The three-zone dashboard itself, once reached, is unchanged: still fits without scrolling exactly as this section originally specified.

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

### 5.2 CPU Timeline / Gantt chart (rewritten 2026-08-24b — per-segment boundary labels)

- Track background: `bgInset`, full width of the left column, horizontally scrollable if the run is longer than the panel width.
- **Each segment** is a zero-radius 1px-framed block on flat `bgVoid`, bordered in the process's §2.3 hue, with the `P<id>` label **centered** in that same hue. **No fill glyph as of 2026-08-25** (explicit user request) — the segment body carries no texture at all, just the border and the centered label; color alone identifies the process. The label is drawn whenever the segment is wide enough to hold it plus padding, and omitted otherwise — never clipped.
- **Segment state is intensity, not hue** (§2.4): the segment under the playhead takes a 2px border and a brighter fill; already-elapsed segments take a darkened border; not-yet-reached segments sit at `borderMuted` with a dimmed label.

**Tick labels sit on the segment boundaries, not on a fixed ruler** (revised 2026-08-24b, on explicit user feedback). The old design drew a ruler underneath marking every fifth tick — `0 5 10 15` on a fixed grid. That answers a question nobody asks. The question this chart exists to answer is *"when did P1 hand over?"*, and a fixed grid answers it only by making the viewer eyeball a segment edge against the nearest gridline.

So each segment now carries **its own start tick, directly above its own left edge**, with a hairline dropping to the boundary it labels so the number is unambiguously attached to an edge even when segments are only a few pixels wide. The final segment additionally draws its end tick, right-aligned. Every other segment's end *is* the next segment's start, so drawing both would print every number on the axis twice.

**The playhead's move animation scales its duration with the current playback rate, not the fixed 1x rate** (fixed 2026-08-25). At higher speed multipliers the tick interval shrinks; an animation duration computed from the fixed 1x base rate no longer finishes before the next tick retargets it, so the playhead visibly falls behind and never catches up — it "moves slow and doesn't snap," in the terms it was reported in. `GanttChart.qml` takes a `ticksPerSecond` property (the *current* rate, `Theme.baseTicksPerSecond * speed`) and caps the animation duration at a fraction of the current tick interval, so it always finishes before the next tick — eased, never instant, but never lagging either.

A boundary label brightens to its process's hue once the playhead has reached it, so the axis fills in as the run proceeds and a viewer can read the elapsed schedule off the chart directly: `0` … P1 … `3` … P2 … `9`.

- **Playhead:** a vertical line in `borderActive` spanning the full track height at `currentTick`. The single most important visual anchor in the dashboard — always crisp, always findable. Motion spec in §6.1.
- Idle/gap ticks (CPU running nothing) are simply absent from the segment list, leaving the `bgInset` track visible — an explicit gap in a filled row reads as idle without needing a hatch pattern.

### 5.3 Ready queue table

- Column headers: `--text-label` style (uppercase, letter-spaced), sticky if the table scrolls.
- Columns, in order: `PID`, `PRIORITY`, `BURST`, `WAIT`, `SCORE` (AARS runs only — column hidden entirely for non-adaptive algorithms rather than shown empty), `CLASS`.
- Each row: left edge carries a 3px vertical accent stripe in that process's palette color (2.3) — lets you visually track a process moving up/down the sorted list without reading the PID every time.
- `CLASS` column renders as a small pill badge (not plain text) — background `--bg-panel-raised`, text in the relevant tone (e.g. CPU-bound in a cooler/dimmer tone, interactive in a brighter one) — exact wording "CPU-BOUND" / "IO-BOUND" / "INTERACTIVE" / "UNKNOWN".
- Row for the currently-RUNNING process (if it briefly appears here during a transition) gets the full `--state-running` treatment (glow border) rather than the normal row style.
- Sort order (score/priority descending) is enforced by the data, not user-sortable in the MVP — keep the table simple and let the score itself be the story.

### 5.4 "Why this process?" panel

The highest-value panel per the PRD — gets the most generous spacing and the clearest hierarchy.

**The why-panel owns the cyan channel** (§2.5, added 2026-08-24b). Its pane border, ASCII title bar and `✓` reason markers are all `accentCyan`, and its verdict line is `accentMagenta`. This is the highest-value panel in the product (PRD §7.4) and it used to be rendered in green, inside a green frame, next to green panels — so the one thing a viewer most needed to find looked exactly like everything around it. Cyan gives the reasoning its own channel; magenta reserves the loudest color in the system for the single fact the panel exists to deliver.

- Header: `WHY {PID}?` in `h1`, the PID rendered in that process's §2.3 hue inline.
- Verdict: one line, `h0` in Instrument Serif, `accentMagenta`, typed in per §2.7(9) once per *decision* (keyed on the PID) — never once per tick.
- Body: a vertical list of reason lines, each prefixed with a ✓ glyph in `accentCyan`, `body` size.
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

### 5.7 Algorithm & workload picker (rewritten 2026-08-23 — full-screen steps, not a footer zone)

The pickers are no longer a footer control strip inside the dashboard. In the native app they are two **full-screen steps** that run before the dashboard exists, in a fixed flow:

`Splash` → `AlgorithmPicker` → `WorkloadPicker` → `Dashboard`

- **Step 1 — algorithm.** A screen-level heading (`h0`, Instrument Serif, typewriter reveal per §2.7) reading `CHOOSE AN ALGORITHM`, above one full-width row per algorithm. Each row is a 1px-framed pane; hover inverts it (§2.4a), click commits and advances.
- **Step 2 — workload.** Same heading treatment, `CHOOSE A WORKLOAD`, above an **in-app list of workload files** — a `ListView` over `WorkloadListModel`, styled exactly like the ready-queue rows (§5.3): left stripe in the selection color, name plus process count, `bgPanelRaised` on the current item. A `[ RUN ]` button sits below, disabled (`textDim`, dashed border) until a workload is selected.
- **Never an OS file dialog.** The workload list is a native in-app browser by deliberate choice. A `QFileDialog`/native file-explorer sheet anywhere in this flow breaks both the aesthetic and the "runs inside an OS, not on top of one" framing of §1.1. This is a hard constraint, restated in `CLAUDE.md`.
- **Why full-screen rather than a footer.** The original footer-zone design assumed a web page where the dashboard was always present. In the native app the simulation must be chosen *before* there is anything to show, so the picker gets the whole window; and giving it the whole window means the demo opens on something composed rather than on an empty dashboard waiting for input.
- The dashboard consequently has **no picker zone**. Its former Zone C is now the playback control strip alone (§5.6).

### 5.8 Process progress ticker (new panel, 2026-08-23 — not in the original spec)

Added at explicit request; the one panel here with no ancestor in the original web spec.

- One row per process, stacked vertically, each row a horizontal progress bar that fills tick by tick and reaches 100% exactly at that process's `completionTime`.
- Row anatomy: `P<id>` label · the bar · a right-aligned readout. No identity glyph (§2.3 is hue-only as of 2026-08-25).
- **The bar is a `FluidBar`, not a character bar** — the one logged exception to §2.7(7), because this panel is read as motion rather than as a value. Fill color is the process's §2.3 hue; motion spec in §6.9.
- **The `P<id>` label is drawn in the process's own hue in every state** (revised 2026-08-25, explicit user request) — running, waiting, or done — not dimmed to `textSecondary` when it isn't the currently-running row. A viewer tracking "which one is P3" needs that color to stay put across the whole run, not just while P3 happens to be on the CPU. `font.weight` still goes bold while running, so the currently-owning row is still distinguishable — just not by losing its color when it isn't.
- Processes that have not yet arrived render at reduced opacity, so a viewer can see the whole cast of the workload from tick 0 and watch them switch on as they arrive.
- Completed processes show `[DONE]` in `accentBlue` (§2.5, structural/reference) in place of the percentage.
- **Hovering a row** raises the process HUD (§5.10) and lifts the row to `bgPanelRaised`.
- The readout column is width-reserved per §3.2 so the percentage never shifts the bar.
- Purpose: the Gantt chart (§5.2) answers "who had the CPU when," which is hard to read as *progress*. The ticker answers "how close is each process to finishing," which is the question an audience actually asks while watching a scheduler run.

### 5.9 Workload detail card (new, 2026-08-24)

Hovering a row in the workload picker (§5.7) opens a `WorkloadCard` beside the
list, explaining what kind of load that preset puts on the scheduler before you
commit to running it. Choosing a workload from a filename alone is guesswork,
and the presets exist precisely because they stress the algorithms differently.

- **Not a floating tooltip.** It is a `TerminalPane` with full window chrome —
  ASCII title bar, bottom status strip showing the `--workload <name>` flag. A
  soft popover with a drop shadow would be the one rounded, lifted, animated
  thing in an application that has none of those (§2.7).
- **Contents, in order:** an inverted `[PROFILE]` badge and the process count;
  the prose description; burst statistics (average, range, total work); the
  arrival window; the priority range; the Round-Robin quantum.
- **Load factor** closes the card: total burst ÷ arrival span, as a character
  bar (§2.7(7)) with a one-line reading. Above 1.0 it switches to `accentAmber`
  — work is arriving faster than one CPU can clear it, so the preset will
  visibly queue. This is the single most useful number for predicting what the
  run will look like, which is why it gets its own block rather than a table row.
- **Every number is computed from the workload file** by `WorkloadListModel`,
  never authored alongside it. `CLAUDE.md` forbids hardcoded illustrative
  metrics, and a statistic written next to the data it describes is exactly
  that — it can drift silently. The only authored field is `description`, which
  is editorial prose about the shape of the load, not a measurement.
- The resting state, before anything is hovered, is shell output
  (`> hover a workload for detail_`) rather than an empty column — a blank pane
  reads as a rendering bug, which is what issue #16 actually turned out to be.

**Profile labels** (`INTERACTIVE` / `MIXED` / `CPU-BOUND`) are a coarse
three-bucket rule on mean burst length, computed in `WorkloadListModel`. They
are deliberately **not** the engine's `ProcessClass` classifier (`PRD.md` §6.3):
that one classifies a single process from observed behavior mid-run, this one
summarizes a whole file before anything has run. Keeping them separate stops a
UI tweak from looking like a change to scheduling logic.

### 5.10 Process HUD (new, 2026-08-24b)

Hovering any row in the process ticker (§5.8) raises a floating HUD explaining
that process: what it is, where it is, and what it cost. Added at explicit
request, primarily for the moment *after* a run finishes — at that point every
ticker bar is full and identical, and a viewer who wants to ask "what actually
happened to P7?" otherwise has to reconstruct it from four panels.

- **It is terminal chrome, not a soft tooltip** (§2.7): zero radius, 1px border
  in the process's §2.3 hue, `bgVoid` ground, ASCII `-----` rules between
  blocks, no drop shadow. The border hue is how you confirm the HUD belongs to
  the row you are pointing at.
- **Contents, in order:** `P<id>` + the live bracketed state
  badge; the `CLASS` label with **a plain-language sentence saying what that
  class means for this process** — a category word in a column is exactly the
  kind of thing a viewer cannot decode on its own; then `CPU DONE` (ticks run /
  total), `ARRIVED`, and `FINISHED`.
- **Cost figures appear only once the process is finished** — `WAITED`,
  `TURNAROUND`, `1ST RESPONSE`, `SWITCHES`. A running total shown mid-flight
  invites reading a partial number as a final one, which is worse than not
  showing it.
- **It is positioned clear of the ticker**, overlapping the right-hand column
  instead of the panel it describes. A HUD floating over the ticker would cover
  the very bars it explains — including the row under the cursor — and would
  also steal the pointer from that row's hover handler, so it would flicker
  itself away the moment the viewer moved toward it.
- It slides vertically to track the hovered row (`durationBase`, `OutCubic`) and
  fades in over `durationFast`. Clamped to the window so a row near the top or
  bottom edge never pushes it off-screen.

---

## 6. Interaction & Motion Specification

General motion principle: **fast and purposeful.** Nothing in this dashboard should feel "designed" in the sense of lingering, springy, delightful micro-interactions — it should feel like a responsive system tool. Default easing and duration unless stated otherwise:

```css
--transition-fast: 100ms ease-out;
--transition-base: 180ms ease-out;
--transition-slow: 300ms ease-out;
```

That principle governs **UI response** — a hover, a border change, a panel swap. It does not govern **playback rate**, which is a separate decision and moves the other way.

**Playback rate (revised 2026-08-24b): 1× is 0.6 ticks per second.** Deliberately slow, and slower than the 2 ticks/second it ran at before, on explicit user feedback that the simulation was too fast to follow. This is a teaching instrument: the value of the dashboard is that a viewer can watch the why-panel and understand *why* each decision happened, and at two decisions a second the panel changed faster than its own verdict line could be read. The speed multipliers (0.5× / 1× / 2× / 4×, §5.6) exist for anyone who wants to skim, so making the default slow costs a skimmer one click and buys every other viewer the ability to follow along. Held in `Theme.baseTicksPerSecond`; nothing else hardcodes a tick interval.

### 6.1 Playhead movement (Gantt chart)

- During playback the playhead animates between tick positions over a full tick interval with `InOutSine` easing, capped at `durationFlow`. At the pre-2026-08-24b rate this was a near-instant linear move; at 0.6 ticks/second a hard 90ms jump followed by a long pause reads as stuttering rather than as tracking, so the playhead now travels continuously between ticks and arrives exactly as the next one lands.
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

### 6.9 Liquid fill — the process ticker bars (new 2026-08-24b, segmented 2026-08-25)

Added at explicit request: the progress bars should move "as if it's like a smooth liquid." This is the reason the ticker bars are a `FluidBar` rather than a character bar (§2.7(7), logged deviation) — a glyph bar advances in whole-cell steps, and at roughly one tick per cell that is a row of characters switching on and off, which is the opposite of flow.

**Revised 2026-08-25 (explicit user request):** the fill body is now tiny segmented blocks — a row of small cells (pitch ~6px + 2px gap, computed from the available width so wider bars get more, finer segments) — rather than one continuous rectangle. A segmented meter reads more like instrumentation, which is what was asked for. It stays liquid, not digital, because of what each layer does:

1. **Each segment eases its own width in independently** (`durationFlow` = 900ms, `InOutSine`). A segment's fill fraction is `clamp(overallFraction × segmentCount − index, 0, 1)` — fully lit segments before the boundary, a *partially*-filled segment straddling it, and unlit segments after. Because every segment eases on its own, segments visibly fill one after another rather than all snapping lit/unlit together — that per-segment lag is what keeps a wall of tiny blocks from reading as a discrete LED meter.
2. **A brighter meniscus rides the true leading edge** — the actual filled length (`channelWidth × fraction`), not a segment boundary. Visual weight sits where the motion is, which is what makes the front read as a *surface* rather than as blocks stacking up.
3. **A single travelling sheen sweeps across the entire filled span**, independent of the segment grid underneath, running only while that process holds the CPU. This is what keeps the segmented body reading as *one* liquid surface rather than a row of separate cells — without it, a paused bar would read as static blocks; with it, filled segments together still read as held liquid. It stops when the process stops, so the sheen also doubles as a live "this one is running" signal.

The unfilled remainder of each segment is its own faint track tint, not blank space, so a bar at 0% still reads as a measured row of cells. ASCII `[` `]` brackets are kept at both ends: the fill is segmented, but it still sits inside the terminal's grammar.

**No per-process glyph or symbol anywhere in this component** (§2.3 is hue-only as of 2026-08-25) — `fillColor` (the process's `Theme.procShade(pid)`) is the only thing that identifies which process a bar belongs to.

Everything else about the bar stays Terminal CLI — zero radius, flat color, no gradient, no rounded cap.

### 6.10 CRT flicker (new, 2026-08-24b)

The bloom's opacity is modulated by a slow, **irregular** flicker. This is part of §2.4a mechanism 1, not a new mechanism — it animates a property that already exists and draws nothing.

- **Irregular on purpose.** A sine wave or an even loop reads as a pulse — as a deliberate animation. A tube's unsteadiness is arrhythmic, so the sequence uses uneven step durations (1.7s / 0.9s / 2.3s holds) and two different dip depths (0.82, 0.90, 0.86). The result reads as "slightly unstable," not as "breathing."
- **Shallow.** Dips are 10–18% of bloom opacity, and the bloom itself is only 0.22 at rest. The effect should be noticeable only if you are looking for it.
- **The glyphs dim very slightly with it** (a 10% swing), not only the halo. If the halo flickers alone the glow looks detached from the type, like a filter over it rather than light coming from it.
- **Display type only.** The splash wordmark, the dashboard title, picker headings and the why-panel verdict. Never on tables, counters, prose or any tick-updating value — a flicker on data a viewer is trying to read is an irritation, not an effect. This is the same boundary §2.7(9) draws for the typewriter reveal, for the same reason.

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
- Bar colors: one bar per **algorithm** (not per process) — a fixed 6-color mapping drawn from the §2.3 hue table (FCFS, SJF, RR, Priority, MLFQ, AARS), consistent across every comparison chart so an algorithm keeps one color throughout the whole report. Reuse the §2.3 hexes rather than inventing chart colors, so the static report and the live dashboard read as one system.
- Text/labels/axis: `--text-primary` green, gridlines: `--border-default`, using the same JetBrains Mono font family (Matplotlib can load `.ttf` files directly) so charts visually match the dashboard.
- `AARS`'s bar/line should NOT be artificially emphasized (no bold outline, no different chart type) — per PRD Section 2.4, results must be reported honestly including where AARS loses, and the chart styling should not editorialize.

> ✎ **EDIT ME:** A ready-made matplotlib style file (`chronos.mplstyle`) implementing this section is a natural first artifact to build once you're in `analysis/` — worth generating early so every chart you produce during Milestone 2 is consistent without re-styling each one by hand.

---

## 8. Implementation Notes

### 8.1 Design tokens (rewritten 2026-08-23 for QML, retokenized 2026-08-24 for Terminal CLI)

All tokens in Sections 2–4 are declared **once**, in `app/qml/Theme.qml`, and referenced as `Theme.<token>` everywhere else. Never hardcode a hex, a font family, a spacing value or a duration in a component — that is what makes the "swap one value" EDIT ME notes throughout this document cheap to act on.

`Theme.qml` is a `pragma Singleton` QML type. It **must** be registered via `QT_QML_SINGLETON_TYPE` in `CMakeLists.txt`; if that registration silently fails, every `Theme.*` binding in the app resolves to `undefined` with no hard error — only console warnings. If colors ever come out wrong across the whole app at once, check that first (see issue #9).

```qml
pragma Singleton
import QtQuick

QtObject {
    // Base — EDRD §2.1
    readonly property color bgVoid:        "#0A0A0A"
    readonly property color bgPanelRaised: "#12180F"
    readonly property color bgInset:       "#060806"
    readonly property color borderMuted:   "#1F521F"
    readonly property color borderActive:  "#33FF00"
    readonly property color textPrimary:   "#33FF00"
    readonly property color textSecondary: "#21A600"
    readonly property color textDim:       "#1E8F10"
    readonly property color textOnAccent:  "#0A0A0A"
    readonly property color accentAmber:   "#FFB000"
    readonly property color accentError:   "#FF3333"
    readonly property color accentCyan:    "#00E5FF"
    readonly property color accentMagenta: "#FF3EC9"
    readonly property color accentBlue:    "#4D9FFF"
    readonly property color accentPositive:"#33FF00"

    // Status — §2.2
    readonly property color stateRunning:    "#33FF00"
    readonly property color stateReady:      "#21A600"
    readonly property color stateWaiting:    "#FFB000"
    readonly property color stateTerminated: "#1F521F"
    readonly property color stateNew:        "#12300F"

    // Process identity — §2.3 (index with pid % 8; hue only as of 2026-08-25)
    readonly property var procShades: ["#33FF00", "#00E5FF", "#FF3EC9", "#FFB000",
                                       "#4D9FFF", "#FF7A29", "#C77DFF", "#D4FF3E"]

    // Type — §3.1/§3.2
    readonly property string fontMono:    "JetBrains Mono"
    readonly property string fontDisplay: "Instrument Serif"
    // sizes/weights/line-heights per §3.2; radius is 0 everywhere per §2.7

    // Spacing — §4.2, and motion — §6
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 16
    readonly property int spaceLg: 24
    readonly property int durationFast: 100
    readonly property int durationBase: 180
    readonly property int durationSlow: 300
    readonly property int durationFlow: 900          // liquid fill — §6.9
    readonly property real baseTicksPerSecond: 0.6   // playback at 1× — §6
}
```

Two tokens that no longer exist, deliberately: `bgPanel` (panes share `bgVoid` and are defined by their border — §2.7) and `GlowFrame`'s layered-glow properties (§2.4a). Anything still referencing either is pre-2026-08-24 code and needs updating, not re-adding the token.

`procShades` keeps its name and its `pid % 8` indexing across the 2026-08-24b revision even though it now holds hues rather than green steps — the indexing convention and every call site are unchanged, so renaming it would have been churn for its own sake.

### 8.2 Suggested build order (pairs with PRD Milestone 1)

1. Get `:root` tokens + base page background/typography in place first — even an unstyled dashboard should already "feel" like ChronOS.
2. Top bar + stat tiles (simplest components, immediate visual payoff).
3. Static (non-animated) Gantt chart against the fake JSON from PRD Milestone 0 — get the layout and colors right before adding the playhead/animation.
4. Ready queue table.
5. Why-panel (static first, then wire up the cross-fade from Section 6.2 once panel transitions exist).
6. Playback controls + playhead animation last — this is the part that depends on everything else already rendering correctly.

### 8.3 What this document deliberately does not specify

Consistent with the PRD's own non-goals: no responsive/mobile breakpoints beyond "don't break above 1280px," no dark/light theme toggle (jet-black is the only theme), no icon library dependency (use inline SVG or unicode glyphs to avoid adding a font-icon build dependency).

> ✎ **Logged deviation (post-Milestone-1):** the "no animation library dependency" rule above was deliberately overridden, on explicit request, for 4 specific enhancements: panel load-in stagger, stat-tile number counters, Gantt/button hover micro-interactions, and playhead motion. GSAP is vendored locally (no CDN, per the offline-demo-safety note in `ARCHITECTURE.md` §5.1). Every other panel/interaction in Section 6 is still plain CSS, and any GSAP timing must stay within this section's "fast and purposeful" principle — `power1`/`power2` easings only, no bounce/elastic/overshoot (those read as sloppy on dense informational UI, not as polish). See `CLAUDE.md`'s Dashboard rules for the enforcement note.

---

## 9. Intro splash (rewritten 2026-08-23 — native app, auto-playing reveal)

Not part of the original spec — added on explicit request after Milestone 1, and rewritten for the native app. Documented here so this file still describes the app as it actually is. It is the one screen where lingering, atmospheric motion is appropriate; §6's "fast and purposeful, nothing lingering" governs everywhere else.

### 9.1 Structure

`Splash.qml`, the `StackView`'s `initialItem`, full-window on `bgVoid`. Contains, centered: the CHRONOS wordmark (`display`, Instrument Serif Regular at 128px, wide phosphor bloom and CRT flicker per §2.4a/§6.10), the subtitle line `ADAPTIVE CPU SCHEDULING ENGINE` (`label`, `textSecondary`), and a blinking `█` cursor (§2.7) beneath it. The scanline overlay (§2.7) is present here as everywhere.

### 9.2 Sequence

1. **Hold.** The wordmark blooms up and holds for ~2.6s while the cursor blinks. No user input is required or accepted beyond skip.
2. **Auto-play reveal.** On its own timer, the hero **scrolls up and fades away** — a scroll-style reveal that plays itself, handing off to the algorithm picker beneath it. Roughly 900ms, `Easing.InCubic` on the vertical move, opacity trailing slightly ahead of it.
3. **Hand-off.** The `finished()` signal replaces the splash with `AlgorithmPicker` through the `StackView`'s standard transition.

### 9.3 What is gone from the old spec, and why

- **No real scroll input.** The web version used GSAP ScrollTrigger with `pin: true` and `scrub`. There is no page to scroll in a native window, and requiring a scroll gesture to get past a splash screen is a bad first interaction in a desktop app. The reveal auto-plays instead — same visual language, no input needed.
- **No ink-drip animation.** An intermediate concept between the two; replaced at explicit request. Do not reintroduce a "drip" without asking first (restated in `CLAUDE.md`).
- **No CRT power-on flicker.** The old one-shot opacity-stutter *entrance* is dropped: with real scanlines present full-time (§2.7), a hard flicker on arrival reads as a rendering glitch rather than as an effect. This is not the same thing as §6.10's continuous flicker, which is a shallow, always-on modulation of the bloom rather than a one-time entrance stunt, and which the wordmark does carry.

### 9.4 Skip + accessibility

Click or any keypress skips straight to the algorithm picker. Under `prefers-reduced-motion` (or its Qt equivalent), the reveal is not animated — the splash holds briefly and cuts.

### 9.5 Why this doesn't undermine §4.1's "no scrolling" principle

§4.1's no-scroll rule is about the *operational* dashboard — the surface a viewer watches during a live demo, where losing track of a panel is a real cost. The intro is a one-time, skippable entry sequence, and in the native app it involves no actual scrolling at all. Once past it, the dashboard is exactly as specified: everything on one screen.
