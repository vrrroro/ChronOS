# Changelog

All notable changes to the ChronOS project are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Add entries under `[Unreleased]` as you go; move it to a dated/versioned heading at each milestone (see `PRD.md` §9). Entries below `[0.4.0]` predate implementation and cover planning/documentation only.

---

## [Unreleased]

### Doc sync & first commit of the pivot (2026-08-25)

Everything below this entry — the architecture pivot, the Terminal CLI redesign,
and the 2026-08-24b revision — was build-verified but sitting uncommitted, and
four docs had fallen behind the code they describe. This entry closes both gaps.

#### Fixed
- `PRD.md` §5.1: `ProcessClass` enum was missing `BALANCED`. §5.3: `processStats[]`
  example was missing the four fields (`arrivalTime`, `burstTime`,
  `contextSwitches`, `class`) added 2026-08-24 for `ProcessHud`. §6.3: rewritten
  to describe the classifier as it actually behaves post-issue-#3 (one completed
  burst is enough; CPU consumed so far counts as evidence mid-burst; `BALANCED`
  fallback), not the pre-fix two-burst rule.
- `ARCHITECTURE.md` §3.4: behavior-analyzer section didn't explain *why*
  `updateClassifications` is called three times per tick (queue, running process,
  completion) — added the issue #3 root-cause note. §4.3: `processStats[]` row
  didn't mention the four widened fields. §5.1: QML module list was missing
  `ProcessHud`, `FluidBar`, `AsciiBar`, `TerminalPane`, `TerminalButton`,
  `PhosphorText`, `BlinkingCursor`, `ScanlineOverlay`, `TypewriterText`,
  `WorkloadCard`, and still listed the deleted `GlowFrame.qml`. §5.3: playback
  Timer snippet still showed the pre-2026-08-24b `2 ticks/sec` base rate instead
  of `Theme.baseTicksPerSecond = 0.6`.
- `README.md`: Quickstart's first `cmake` command had a literal `\n` two-character
  typo instead of a line break, so copy-pasting the block ran a broken command.
- `PROJECT_STATUS.md`: rewritten throughout — still said 2 of 4 workload presets
  (actual: 8 of 8), still named Fraunces (replaced by Instrument Serif
  2026-08-24b), still described issue #3 as an open retuning question (fixed,
  root cause was a classifier mechanism bug, not thresholds), still described
  the pivot/redesign as uncommitted.

#### Fixed
- `ProcessHud.qml:205` — the SWITCHES row's `value: root.entry.contextSwitches` assigned
  raw `undefined` to a `text: QString` binding while `entry` still held its default `({})`
  (i.e. at construction, before any hover), producing a QML warning on every launch that
  reached the Dashboard. Every sibling `HudRow` string-concatenates its value (`+ " ticks"`,
  `"tick " + ...`), which coerces `undefined` to the string `"undefined"` instead of leaving
  it as the JS value — this was the one row that didn't. Fixed by matching that pattern
  (`+ ""`). Found via a manual launch-and-hover pass after the build/smoke-test verification
  above didn't reach the Dashboard screen long enough to trigger it.
- Also verified, while chasing what first looked like a text/pane overflow bug in a
  screenshot of the algorithm picker: it wasn't one. `root.width` really is `1180`
  (matches the window), confirmed via a temporary `console.log`. The apparent clipping was
  this specific sandboxed environment's screenshot tooling — a DPI-unaware capture script
  reading a Per-Monitor-V2 DPI-aware window (`devicePixelRatio 1.5`) — not the app. Recorded
  here so it isn't re-investigated as a real bug next time a screenshot looks wrong in this
  environment; see `PROJECT_STATUS.md` §9 for the existing note this confirms.

#### Changed
- Closed GitHub issues #2, #3, #9–#20 to match reality: #2 (workload presets) and
  #3 (AARS classification) are fixed and verified; #9–#13 are historical
  postmortems of bugs already fixed in the code (kept open previously by design,
  pending an explicit user decision — now given). #14–#20 (Terminal CLI redesign
  tracking issues) were already closed. Genuinely open: #1, #4–#8.
- First commit of everything in the working tree as of 2026-08-25: the
  architecture pivot (`app/`, `chronos_core` split, deleted `dashboard/`), all
  eight workload presets, the Terminal CLI redesign, and the 2026-08-24b
  revision. Re-verified clean immediately before committing: fresh build, all
  40 engine runs, zero-warning GUI launch.

### Palette, type & motion revision (2026-08-24b) — "too much green," plus the UNKNOWN-class fix

Eight changes, all requested directly after watching the previous build run, plus
one engine bug the fourth of them exposed. The Terminal CLI system (below) is
unchanged in its *structure* — zero radius, 1px ASCII-framed panes, scanlines,
shell copy. What changed is that it is no longer monochrome, no longer set in
Fraunces, and no longer moves at the speed it did.

Verified: clean configure + build from scratch, all **40 engine runs**
(8 workloads × 5 algorithms) pass, GUI launches with **zero QML warnings** on
stderr.

#### Added
- **`FluidBar.qml`** (`EDRD.md` §6.9) — the process ticker's progress bars now
  fill as liquid rather than in whole-glyph steps. Three layers, all load-bearing:
  a 900ms `OutCubic` width transition so the level *settles*; a brighter meniscus
  at the leading edge so a moving edge reads as a surface; and a slow travelling
  sheen across the filled body, running only while that process holds the CPU, so
  a bar that is not advancing still reads as held liquid rather than as a solid
  block. Unfilled remainder is a dotted `·` rule so a 0% bar still reads as a
  measured track.
- **`ProcessHud.qml`** (`EDRD.md` §5.10) — hovering a ticker row raises a floating
  HUD explaining that process: identity, live state badge, `CLASS` **with a
  plain-language sentence saying what that class means for this process**, CPU
  done / arrived / finished, and — only once the process is finished — waited,
  turnaround, first response, context switches. Cost figures are withheld while
  running because a partial total invites being read as a final one.
  It is terminal chrome (zero radius, 1px border in the process's hue, ASCII
  rules), not a soft tooltip, and it is positioned **clear of the ticker** — over
  the ticker it would cover the bars it explains and steal the pointer from the
  hovered row, flickering itself away as the viewer moved toward it.
- **CRT flicker** on display type (`EDRD.md` §6.10) — a shallow, deliberately
  *irregular* modulation of the bloom. Uneven holds (1.7s / 0.9s / 2.3s) and two
  dip depths, because a sine or an even loop reads as a pulse where a real tube's
  unsteadiness is arrhythmic. The glyphs dim ~10% with it, not just the halo,
  otherwise the glow looks detached from the type.
- **Four accent tokens** — `accentCyan` `#00E5FF`, `accentMagenta` `#FF3EC9`,
  `accentBlue` `#4D9FFF`, `accentPositive` `#33FF00` (`EDRD.md` §2.1/§2.5).
- **`Theme.baseTicksPerSecond`** and **`Theme.durationFlow`** — playback rate and
  liquid-fill duration are now tokens; nothing hardcodes a tick interval.
- **`ProcessClass::BALANCED`** (`engine/process.h`) — see Fixed.
- **Four fields on `processStats`** in the result JSON: `arrivalTime`,
  `burstTime`, `contextSwitches`, `class`. Purely additive; no existing field
  changed shape. The process HUD needs to describe a finished process without
  re-reading the workload file alongside the result. **`PRD.md` §5.3 has not been
  updated yet — it must be, and `analysis.py` (#1) should read these rather than
  recompute them.**

#### Changed
- **Display face: Fraunces → Instrument Serif** (`EDRD.md` §3.1/§3.2, explicit
  user request). It ships Regular and Italic only — no Black cut, no variable
  axes — so the display tokens no longer request weight 900 or drive
  `WONK`/`SOFT`/`opsz`; either would silently synthesise a fake bold, which on a
  high-contrast serif smears exactly the thin strokes that make it a display
  face. `display` 112→128px and `h0` 32→38px instead: matching the old presence
  meant more size, because weight was not available to spend. Fraunces' four
  `.ttf`s and `OFL-Fraunces.txt` are deleted; `OFL-InstrumentSerif.txt` added.
- **The bloom is much dimmer, at `0.22` halo opacity, down from `0.5`**
  (`EDRD.md` §2.4a). At the old strength the halo competed with the glyphs
  instead of sitting behind them, so display type read as washed out — as a
  lighting effect applied *to* the type rather than as type emitting light. The
  splash still runs hot, but by a wider blur radius rather than more opacity.
- **Per-process identity is neon hue *and* glyph again** (`EDRD.md` §2.3),
  replacing the green brightness steps introduced the day before. Eight steps of
  one hue are eight steps a viewer has to *compare* rather than *recognize*, and
  at ticker size the middle four were not reliably separable at all. The glyph
  channel is **kept**, not replaced — that is what still carries the encoding
  under greyscale, a washed-out projector, or deuteranopia. Hues are spaced
  around the wheel so adjacent PIDs never sit adjacent in hue.
- **The why-panel owns cyan; the verdict owns magenta** (`EDRD.md` §2.5/§5.4) —
  the direct fix for "too much green in one page." The highest-value panel in the
  product used to be green, inside a green frame, beside green panels, so the one
  thing a viewer most needed to find looked like everything around it. Each hue
  now owns exactly one role app-wide, and every role stays redundantly encoded in
  a word, sign or glyph, so nothing is carried by hue alone.
- **Gantt tick labels moved onto the segment boundaries** (`EDRD.md` §5.2). The
  fixed every-fifth-tick ruler (`0 5 10 15`) answered a question nobody asks —
  the question this chart exists to answer is "when did P1 hand over?", and a
  fixed grid answers it only by making the viewer eyeball a segment edge against
  the nearest gridline. Each segment now prints its own start tick above its own
  left edge with a hairline dropping to the boundary; only the last segment also
  prints an end tick, since every other segment's end is the next one's start.
  Labels brighten to their process's hue as the playhead passes, so the axis
  fills in as the run proceeds.
- **Gantt PID labels are centered and drawn in the process's own hue**, on a
  `bgVoid` ground. They previously sat on a filled swatch in `textOnAccent`,
  which read as a separate object stuck onto the bar rather than as the bar's
  own label.
- **1× playback is 0.6 ticks/second, down from 2** (`EDRD.md` §6). This is a
  teaching instrument: its value is that a viewer can follow *why* each decision
  happened, and at two decisions a second the why-panel changed faster than its
  own verdict line could be read. The 0.5×/1×/2×/4× multipliers mean a slow
  default costs a skimmer one click.
- **The playhead now eases between ticks** (`InOutSine`, capped at
  `durationFlow`) instead of a 90ms linear snap. At the slower rate a hard jump
  followed by a long pause reads as stuttering rather than as tracking.
- `[DONE]` readouts render in `accentBlue`; stat tiles split across
  `textPrimary` / `accentBlue` / `accentMagenta` so three unrelated numbers in a
  row stop inviting comparison with each other.
- `CLASS` badges are colored per class (`[CPU_BOUND]` magenta, `[IO_BOUND]` cyan,
  `[INTERACTIVE]` amber, `[BALANCED]`/`[PENDING]` dim) — a *categorical* use of
  hue, exempt from one-hue-one-role because it is always attached to a process
  and always spelled out in words (`EDRD.md` §2.5).

#### Fixed
- **`ProcessClass` was `UNKNOWN` for almost every process in almost every run**
  (#3 — the user asked what the "unknown" at the end of each process meant, which
  is the right question: it meant nothing, and it should not have been there).
  Three separate causes, all fixed:
  1. **Classification required two completed bursts.** Under the three
     non-preemptive algorithms a process runs exactly once and then terminates,
     so it never accumulated a second sample and stayed `UNKNOWN` for the whole
     run — the classifier was effectively dead outside RR and AARS. One completed
     burst is now enough: a process that has run 22 ticks to completion is
     CPU-bound on any reading, and demanding a second sample only withholds a
     conclusion the evidence already supports.
  2. **The running process was never classified.** `updateClassifications()` was
     called on `readyQueue` only, and the running process is held *outside* that
     queue while dispatched — so the one process actually accumulating evidence
     was the one never being looked at, and it re-entered READY still labelled
     `UNKNOWN`. It is now classified too, and reclassified once more at
     completion, when the full burst history exists.
  3. **There was no label for "ran, but unremarkable."** Anything that failed the
     CPU-bound and short-burst tests fell through to `UNKNOWN`, so "the analyzer
     has no opinion" and "the analyzer never got to speak" were the same word.
     Added `ProcessClass::BALANCED` for the former. `UNKNOWN` now means only
     "has not run yet", and the UI relabels it **`PENDING`** to say so plainly.
  - Result across all 40 runs: **zero `UNKNOWN`** in final stats —
    303 `BALANCED`, 88 `INTERACTIVE`, 69 `CPU_BOUND`.
  - **Known limitation, deliberately not papered over:** `IO_BOUND` is currently
    unreachable. It requires `Process::ioEvents > 0`, and nothing in the engine
    ever increments `ioEvents` — the simulator has no I/O model yet (`PRD.md`
    §2.1). The branch is correct and stays; it simply cannot fire until I/O
    bursts exist. The `io_bound` workload preset is named for its *burst shape*,
    not for emitting I/O events.
- Stale `Fraunces` / `WONK`-axis comments in `Splash.qml`, `Dashboard.qml`,
  `WhyPanel.qml` and `CMakeLists.txt`.

#### Deferred — open at the end of this session
- `analysis/` is still **empty**; `analysis.py` (#1) is unbuilt and is the last
  substantial piece before the project is demo-complete.
- **`PRD.md` §5.3 does not yet document the four new `processStats` fields.**
- `ARCHITECTURE.md`, `PRD.md`, `README.md` and `PROJECT_STATUS.md` were **not**
  updated for this revision (`CLAUDE.md` and this file were). `EDRD.md` **was**
  fully updated.
- Nothing is committed: `app/`, the six newer workload presets,
  `engine/scheduler_factory.*` and `engine/workload_io.*` are all still
  untracked.
- Issues #9–#13 are postmortems of bugs already fixed and still read as open on
  the board.

---

### Terminal CLI redesign (2026-08-24) — second visual pivot, plus workload library

Explicit user request, on two counts: the glow border read as "tacky," and the
dashboard rendered with its left column collapsed so nothing was visible. Both
were fixed as part of adopting a single named visual system. Partitioned across
GitHub issues #14–#20 so the work could run in parallel; all now closed.

#### Added
- **Terminal CLI visual system** (`EDRD.md` §2.1/§2.3/§2.4a/§2.7): jet black
  `#0A0A0A` + phosphor green `#33FF00`, zero corner radius everywhere, 1px pane
  borders with ASCII title bars (`+--- READY QUEUE ---+`), CRT scanlines, a
  blinking block cursor, shell metaphors in all copy, and `[||||····]` character
  bars in place of every smooth filled bar. §2.7 is a **closed list** of
  permitted effects.
- **Six shared QML primitives** — `TerminalPane`, `TerminalButton`, `AsciiBar`,
  `BlinkingCursor`, `PhosphorText`, `ScanlineOverlay` — plus `TypewriterText`.
  These are now the only sanctioned way to build chrome.
- **Bundled typography** (`app/fonts/`, both SIL OFL): **JetBrains Mono** for
  everything, **Fraunces** for display type in exactly four places (splash
  wordmark, dashboard title, picker headings, why-panel verdict). Registered in
  `app/main.cpp` before the QML engine is constructed, compiled in as Qt
  resources so an installed build behaves like a source-tree run.
- **Six new workload presets**, taking the library from 2 to 8 and spanning
  **3 to 20 processes**: `tiny_batch` (3), `io_bound` (14), `burst_arrivals`
  (16), `long_tail` (20), plus `mixed` (12) and `starvation` (10), which were
  issue #2's Milestone-2 scope. Each is hand-shaped to make the five algorithms
  diverge rather than all producing similar Gantt charts.
- **Workload detail card** (`WorkloadCard.qml`, `EDRD.md` §5.9): hovering a row
  in the workload picker opens a terminal-chrome card explaining what kind of
  load that preset puts on the scheduler — profile badge, process count, burst
  distribution, arrival window, priority range, quantum, and a **load factor**
  bar (total burst ÷ arrival span) that turns amber above 1.0. Every number is
  computed from the workload file by `WorkloadListModel`; only the prose
  `description` field is authored.
- Per-algorithm descriptions on the algorithm picker, revealed on hover.
- Keyboard control throughout: `1`-`5` pick an algorithm, `Enter`/`Esc` run and
  go back, `Space`/`arrows`/`R` drive playback, any key skips the splash.

#### Changed
- **Per-process identity is no longer hue-based** (`EDRD.md` §2.3). The eight
  neon hues are replaced by an ASCII fill glyph plus a green brightness step,
  indexed `pid % 8`. Monochrome is the point of the system, and a fill character
  survives greyscale, a projector, and deuteranopia in a way hue does not. The
  bridge now hands QML a slot index rather than a color.
- The navy pivot of 2026-08-23 is **reverted**; `bgPanel` and `glowColor` are
  deleted rather than remapped, so stale references fail loudly.
- Why-panel's top reason line shortened — it was the widest string in the panel
  and wrapped, pushing the last score term out of view.
- Playback controls split into two rows so the scrub bar spans full width.
- Window sized 1180×730 for a 1280×800 logical desktop, which is the smallest
  display this has to run on.

#### Removed
- **`GlowFrame.qml`**. Stacking low-opacity thick-bordered rectangles renders as
  a set of visible concentric outlines rather than as light — tuning the
  opacities does not fix it, because the layering itself is what you see.
  Replaced by two mechanisms only (`EDRD.md` §2.4a): a real blurred text bloom
  via `MultiEffect` (`QtQuick.Effects`, which the Qt 6.11 install here ships —
  the old "no MultiEffect dependency" constraint predated confirming that), and
  inverted-video hover. No drop shadows anywhere; no glow halo on containers.

#### Fixed
- **Dashboard left column collapsed to zero width** (#15), hiding the Gantt
  chart, process ticker and playback controls entirely. A nested layout inside a
  layout has `Layout.fillWidth` defaulting to **true**, and free space is
  distributed in proportion to *preferred* sizes — so a column whose children
  are all zero-implicit-width panes has a preference of 0 and is given none of
  it. Both columns now state their sizing explicitly.
- **Why-panel rendered completely empty** (#16), not even its placeholder. Every
  child was gated on `panelData.hasDecision`, so one malformed payload made all
  of them fail together. It now reads through a guarded accessor with a defined
  default shape, degrading to the placeholder instead of to a blank box.
- Font resource paths, tick-ruler labels spilling past the pane edge, ASCII
  title-bar dashes overrunning their border (the cell-width estimate ignored
  letter-spacing; now measured with `TextMetrics`), and transport glyphs falling
  back to the Windows emoji font mid-terminal.
- `CMakeLists.txt` now declares Qt policy `QTP0004`, so configure is warning-free.


### Architecture pivot (2026-08-23) — web dashboard replaced with native Qt/QML app

Explicit user request: a polished native executable instead of a browser page. **This supersedes the "Post-Milestone-1 dashboard polish" entries below** — `dashboard/` (including the vendored GSAP work) has been deleted; the GSAP/scroll-intro/font-override history is kept below for the record, but none of it exists in the codebase anymore.

#### Added
- `chronos_core` (CMake `STATIC` library): all engine logic except `main.cpp`, so the CLI and the new GUI share identical scheduling code. New `engine/workload_io.*` and `engine/scheduler_factory.*` pulled out of `main.cpp` specifically so both consumers call the same functions.
- `app/` — native Qt 6/QML desktop GUI (`chronos_app` target): `ChronosBridge` (in-process engine link + per-tick derived data, ported from the deleted `dashboard/app.js`'s derivation helpers), `WorkloadListModel` (in-app workload file browser, no OS file dialog), and QML screens `Splash` → `AlgorithmPicker` → `WorkloadPicker` → `Dashboard` (Gantt/ready-queue/why-panel/aging-indicator/playback-controls, same content as the old EDRD spec) plus a new `ProcessTicker` panel (one progress bar per process, not in the original spec).
- `GlowFrame.qml` — reusable layered neon-green glow border, used on all interactive buttons and the intro wordmark.
- Auto-playing scroll-reveal intro (`Splash.qml`) — holds on the glowing wordmark, then automatically scrolls it up and away on a timer (no user scroll/click needed). Replaced an ink-drip concept explored briefly during the same session, which itself replaced the old GSAP-ScrollTrigger web intro.
- Dark muted-navy visual direction (`Theme.qml`) — neon green pulled back from base chrome color to a glowing accent, per explicit request. See `EDRD.md` §2 for updated tokens.
- 5 GitHub issues ([#9](https://github.com/vrrroro/ChronOS/issues/9)–[#13](https://github.com/vrrroro/ChronOS/issues/13)) filed for bugs found and fixed while building the GUI out (see Fixed, below).

#### Fixed
- `Theme.qml`'s `pragma Singleton` wasn't auto-registered by `qt_add_qml_module` in this Qt 6.11 setup — every `Theme.*` binding silently resolved to `undefined`, rendering the whole UI in Qt Quick's default white/black look. Fixed via explicit `QT_QML_SINGLETON_TYPE` CMake source property. (#9)
- `AlgorithmPicker`/`WorkloadPicker`/`Splash` originally anchored children directly inside a plain `Column`, which Qt Quick positioners don't support (ignores/conflicts with child anchors) — produced unpredictable, badly-offset layouts. Switched to `ColumnLayout` + `Layout.alignment`. (#10)
- `GlowFrame` had no implicit size, so inside a `ColumnLayout` it defaulted to filling all available space regardless of `Layout.preferredWidth`/`Height` set on it — buttons rendered far larger than specified. Gave it a real implicit size and set `Layout.fillWidth/fillHeight: false` at every use site. (#11)
- `chronos_app`'s generated manifest declared no DPI awareness, so Windows silently virtualized/rescaled the window bitmap for an "unaware" process. Fixed via `SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)` at the top of `main()`. (#12)
- `WhyPanel.qml`'s `data` property collided with `Item`'s own built-in default `data` property — renamed to `panelData`. (#13)

#### Verification note
The `chronos_core` refactor was byte-diffed against a pre-refactor baseline across all 5 algorithms × 2 workload presets — CLI output is unchanged.

---

### Post-Milestone-1 dashboard polish (superseded — see pivot above, kept for history)

Done outside the formal milestone sequence on explicit request, before the architecture pivot above replaced the web dashboard entirely. All four items below were **deliberate, logged deviations** from `PRD.md`/`EDRD.md`'s original locked specs (no animation library, monospace-only, no scrolling) at the time — none of this code exists anymore.

### Added
- GSAP (core, vendored locally at `dashboard/vendor/gsap.min.js`, no CDN) for 4 scoped enhancements: panel load-in stagger (replacing the old fixed-delay CSS `@keyframes`), stat-tile count-up/down, subtle Gantt/button hover lift, and smooth playhead motion during playback (instant jump on manual scrub/step, per EDRD §6.1 — the CSS transition this replaced never actually enforced that distinction).
- CRT-boot intro splash: "CHRONOS" flickers in, brief hold, scanline sweep reveals the dashboard. Initial version used a fixed overlay + timeline; superseded by the scroll-driven version below.
- Scroll-driven intro rework: the hero is now a real in-flow section pinned via GSAP ScrollTrigger (vendored at `dashboard/vendor/ScrollTrigger.min.js`) for one viewport-height of scroll — the wordmark still flickers in on load, then real scroll position scrubs it out into the dashboard. This is the one place in the app that scrolls; the dashboard itself is unchanged and still needs none once reached (EDRD §4.1 exception).
- Site-wide Apple-style font: `--font-mono` renamed to `--font-primary`, repointed to `-apple-system, BlinkMacSystemFont, 'Segoe UI', ...` (resolves to San Francisco on macOS/iOS via the OS's own font — SF Pro itself isn't licensable to embed). Applied everywhere, not just prose text.
- 8 GitHub issues filed for the remaining roadmap (Milestones 2–4), organized under 3 GitHub milestones matching `PRD.md` §9 — see the repo's Issues tab.

### Fixed
- Intro skip button was scrolling to `hero.offsetHeight` alone, which undercounts once ScrollTrigger's `pin: true` inserts spacer space for the pinned scroll range — landed the viewport in a dead zone between "hero faded out" and "dashboard not yet scrolled into view." Now targets the ScrollTrigger's own resolved `end` position.

---

## [0.4.0] — 2026-08-22 — Milestone 1 (MVP)

### Added
- Milestone 0 (Setup): folder scaffold (`engine/`, `engine/schedulers/`, `dashboard/`, `analysis/`, `workloads/`, `results/`, `logs/`), vendored `nlohmann/json` single header, root `CMakeLists.txt`, git repo initialized, CMake toolchain installed.
- Milestone 1 (MVP): full simulator core (`engine/simulator.{h,cpp}` — tick loop, JSON writer, `logs/scheduler.log` writer), CLI (`engine/main.cpp`), and all 5 required schedulers — FCFS, SJF, Round Robin, Priority (fixed-interval aging), AARS (full §6.1–6.4 scoring formula, dynamic quantum, behavior classification).
- Full dashboard (`dashboard/index.html`/`style.css`/`app.js`) per `EDRD.md`: CPU timeline/Gantt with playhead, ready queue table, why-panel with score-breakdown bar, waiting/aging indicator, playback controls, algorithm/workload picker.
- 2 workload presets (`cpu_heavy.json`, `interactive.json`) producing visibly different Gantt shapes.

### Changed
- `PRD.md` §5.3: extended `decisionLog[].candidates[]` from `{pid, score}` to also carry `priority`, `burstRemaining`, `class` — the ready-queue table (EDRD §5.3) needed a per-tick source for those columns that the original schema had nowhere to carry. All 5 schedulers populate it, not just AARS.

### Fixed
- Structural bug in `ARCHITECTURE.md` §3.3's pseudocode: `selectNext` was called before the just-preempted process was pushed back into `readyQueue`, making it impossible for a quantum-based scheduler to ever reselect the same process when it's the only one ready. `simulator.cpp` pushes back first, then selects.
- Context-switch undercounting: switches were only being counted on mid-slice preemption, not when one process completes and a different one starts next.
- Burst-history recording: recording a raw quantum-truncated slice on every preemption capped every recorded burst at AARS's own quantum table (max 8 ticks), making the `CPU_BOUND` classification threshold (avgBurst>15, PRD §6.3) mathematically unreachable regardless of a process's actual CPU appetite. Burst length is now accumulated across same-PID quantum reselections and only recorded as a completed burst when a process is genuinely displaced by a different process, or completes.

### Known limitation (carried to Milestone 2, per `PRD.md` §14)
- With the fix above, the classification mechanism is verified correct (confirmed via a scratch sustained-contention scenario), but both required Milestone-1 presets (`cpu_heavy`, `interactive`) still mostly classify `UNKNOWN` in practice: `UNKNOWN` is the PRD §6.3 catch-all whenever avgBurst falls between the IO/interactive threshold (4) and the CPU-bound threshold (15), and AARS's own quantum table (2–8 ticks) tends to produce recorded bursts that land in exactly that middle zone. This is a threshold-vs-quantum interaction, not a bug — real data for retuning §6.2/6.3 thresholds is exactly what Milestone 2 (`PRD.md` §9, item 3) is for. Tracked as [GitHub issue #3](https://github.com/vrrroro/ChronOS/issues/3).

---

## [0.3.0] — 2026-08-22 — Architecture documentation

### Added
- `ARCHITECTURE.md`: system design reference — component map, module breakdown for `engine/`/`dashboard/`/`analysis/`, the shared `Scheduler` interface all algorithms implement, tick-loop pseudocode with correctness invariants, full data-contract ownership tables (who writes/reads each JSON field), dashboard state model, and extension points for future work (MLFQ, real threads, live-server stretch goal).

---

## [0.2.1] — 2026-08-22 — Operating rules for Claude Code

### Added
- `CLAUDE.md`: terse operating instructions for AI-assisted implementation — locked stack (C++17/STL only, CMake, plain HTML/CSS/JS, no frameworks, no live backend), architecture/JSON-contract rules, algorithm build order, explicit "what NOT to do" list (no real threads unless asked, no ML classification, no responsive/mobile design, no hardcoded example metrics, no MLFQ before Milestones 0–2), testing requirements, and starter build/run commands.

### Notes
- Commands section flagged as unverified placeholders pending real `main.cpp` CLI argument parsing.

---

## [0.2.0] — 2026-08-22 — Project renamed

### Changed
- Project name changed from **ChronosOS** to **ChronOS** across all existing documents (`PRD.md`, `EDRD.md`), including the wordmark spec in the dashboard top bar and the repo folder-structure code block.

---

## [0.1.1] — 2026-08-22 — Design specification

### Added
- `EDRD.md` (Engineering Design Requirements Document): dashboard visual and interaction spec.
  - Jet-black / neon-green terminal aesthetic, chosen after clarifying questions on style, layout fidelity, target screen, and color approach.
  - Full color system: base palette, process-state colors, an 8-slot neon per-process palette (distinct from the green "chrome" color to avoid identity/state ambiguity), semantic accent colors, and a contrast/colorblind-accessibility note (score deltas always pair color with `+`/`−` and an arrow, never color alone).
  - Typography: monospace-only stack (JetBrains Mono primary), full type scale.
  - Layout: three-zone grid, panel anatomy, 8px spacing scale.
  - Per-component specs for every dashboard panel (top bar, CPU timeline/Gantt, ready queue, why-this-process panel, aging indicator, playback controls, algorithm/workload picker).
  - Detailed interaction/motion spec: playhead movement, context-switch transitions, hover states, button states, status pulse, aging warning flash, panel load-in, empty/loading states.
  - Matplotlib chart styling notes so static comparison charts visually match the live dashboard.
  - Ready-to-use CSS custom-property block implementing every token in the document.

---

## [0.1.0] — 2026-08-22 — Initial PRD

### Added
- `PRD.md` (Product Requirements Document), created from the user's original expansive project plan (originally named ChronosOS), scoped down to a solo, 4–6-week, beginner-feasible project via a clarifying-question pass covering timeline, C++/web skill level, threading requirements, and dashboard interactivity.
- Key scope decisions, each documented with rationale:
  - Pure tick-based simulation instead of real OS threads/pthreads for the core engine (real threads demoted to an optional stretch goal).
  - Simulate-then-replay dashboard (engine writes one JSON log; dashboard replays it) instead of a live streaming backend — removes an entire networking/sockets subsystem neither of the user's existing skill areas covered.
  - MLFQ moved out of the MVP milestone into Milestone 3, since it is roughly as complex as the other four classic algorithms combined.
  - AARS algorithm held to an "honest results" standard — not required to beat other algorithms overall, only to win on some metric under some workload, with losses reported and explained rather than tuned away.
- Full goals/non-goals list, system architecture (three file-boundary-connected subsystems), data model (`Process` struct, workload JSON schema, result JSON schema), the AARS scoring formula (`Score = Base Priority + Aging Bonus + I/O Bonus + Response Bonus − CPU Burst Penalty`) with starting-point weights and rule-based behavior-classification thresholds, dashboard functional spec, metrics/comparison spec, a week-by-week milestone plan (Setup → MVP → Comparison & polish → MLFQ + depth → Stretch/presentation), a 10-case edge-case test matrix, logging spec, presentation outline, and a risks/mitigations table.
- Every placeholder numeric value (weights, thresholds, timeframes) marked with an "✎ EDIT ME" note distinguishing starting guesses from fixed requirements.
- Delivered first as a formatted `.docx` (via the docx skill), then re-authored as clean Markdown (`ChronosOS_PRD.md`) for repo/Claude Code use, since the original pandoc conversion lost code-block formatting.

### Fixed
- Docx generation bug: C++/JSON code samples initially collapsed onto single lines (violated the docx skill's "never use `\n` in one run" rule) — fixed by introducing a `codeBlock()` helper that splits multi-line text into separate paragraph elements, then re-verified by rendering to PDF and visually inspecting the affected pages.

---

## Notes on versioning

Pre-1.0 versions here track documentation milestones, not semantic API versioning — there is no code to version yet. Once Milestone 0 (`PRD.md` §9) begins, switch to tracking actual implementation changes (features, fixes, refactors) per the Keep a Changelog categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`. Bump to `1.0.0` when Milestone 1 (MVP) is complete and demoable end-to-end.
