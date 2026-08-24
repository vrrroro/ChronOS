# CLAUDE.md — ChronOS

Project: ChronOS — Adaptive CPU Scheduling Engine (AARS algorithm). Full spec: `PRD.md`. Visual/UX spec: `EDRD.md`. Read both before writing code. This file is operating rules only — do not duplicate spec content here; if it's not here, it's in those two files.

## State of play (2026-08-25 — read this first)

The app **builds clean and runs**: all 40 engine runs (8 workloads × 5 algorithms) pass, and the GUI launches with zero QML warnings on stderr. Milestones 0 and 1 are complete; Milestone 2 is partly done.

**All docs are synced** as of 2026-08-25 (`PRD.md` §5.1/§5.3/§6.3, `ARCHITECTURE.md` §3.4/§4.3/§5.1/§5.3, `README.md`, `PROJECT_STATUS.md`, this file, all re-checked against the 2026-08-24b revision and against actual code/build behavior) and everything above has been committed. GitHub issues #2, #3, #9–#20 are closed to match; #1, #4–#8 remain genuinely open — see `PROJECT_STATUS.md` §1/§4 for what's next.

**Next substantial piece of work:** `analysis/analysis.py` (issue #1). `analysis/` is currently an empty directory, and this is the last thing standing between the project and demo-complete.

## Architecture pivot (2026-08-23, explicit user request — logged, not silent drift)

The original web dashboard (plain HTML/CSS/JS + vendored GSAP, described in the sections below as history) was scrapped and replaced with a **native Qt 6 / QML desktop application** (`app/`, target `chronos_app`). The user wanted a polished animated executable, not something opened in a browser. `dashboard/` has been deleted. See `PRD.md`/`ARCHITECTURE.md`/`EDRD.md` for the updated specs — this pivot is documented there, not just here. GitHub issues [#9](https://github.com/vrrroro/ChronOS/issues/9)–[#13](https://github.com/vrrroro/ChronOS/issues/13) track bugs found and fixed while building it out.

## Stack (do not substitute)

- Simulation engine: C++17, STL only. No Boost, no external C++ libs except `nlohmann/json` (single header). Built as a static library, `chronos_core`, shared by both the CLI and the GUI.
- Build: CMake.
- CLI (`chronos`): unchanged — still writes `results/<name>.json`, still used by `analysis/`.
- GUI (`chronos_app`): Qt 6 / QML (Qt Quick). Links `chronos_core` directly and calls the scheduler in-process (no JSON round-trip for interactive use — see Architecture contract below). No other GUI toolkit, no Electron, no web view.
- Analysis: Python 3 + matplotlib + pandas. Unchanged.
- No database. No backend server, live socket, or REST API.

## Architecture contract

- `chronos_core` (STATIC library, `engine/*.cpp` minus `main.cpp` + `engine/schedulers/*.cpp`) is the single source of truth for scheduling logic, shared by `chronos` (CLI) and `chronos_app` (GUI). Never duplicate scheduler/workload-loading logic between them — `engine/workload_io.*` and `engine/scheduler_factory.*` exist specifically so both consumers call the exact same code.
- The GUI links the engine **in-process** (`ChronosBridge` calls `loadWorkload()` + `makeScheduler()` + `runSimulation()` directly) — this is a deliberate, logged deviation from the original file-boundary-only contract, made for the native app specifically. The CLI still writes real JSON files (`PRD.md` §5.2/§5.3 schema, unchanged) for `analysis/` to consume — that file-boundary path still exists, just isn't used by the interactive GUI.
- `PRD.md` §5.2 and §5.3 are still the JSON schemas for the CLI/analysis path. Do not change field names/shapes without updating the PRD and every consumer (CLI writer, analysis.py reader) in the same change.
- **`processStats` was widened on 2026-08-24 and `PRD.md` §5.3 has not caught up yet.** Four fields were added — `arrivalTime`, `burstTime`, `contextSwitches`, `class` — additively, with no existing field changed. The process HUD (`EDRD.md` §5.10) needs to describe a finished process without re-reading the workload file alongside the result. Two consequences: **update `PRD.md` §5.3 to match**, and when building `analysis.py`, *read* these fields rather than recomputing them from the workload.
- Process struct fields, State enum, ProcessClass enum: exactly as in `PRD.md` §5.1. Don't rename or restructure without updating the PRD.

## Algorithm rules

- Implement algorithms in this order only, matching PRD milestones: FCFS → SJF (non-preemptive) → Round Robin → Priority (+ aging) → AARS. MLFQ is Milestone 3 — do not build it before the other five work end-to-end.
- AARS formula and term weights: `PRD.md` §6.1–6.4. Weights there are starting values, not fixed — but any change to them must be a deliberate, logged decision (write it down, don't silently retune).
- Never hand-tune AARS weights or thresholds specifically to make comparison numbers look better before reporting results. Run first, report what comes out, including losses. (PRD §2.4 — this is a hard project requirement, not a style preference.)
- Every scheduling decision must be logged with candidate scores and reason tags (PRD §5.3 `decisionLog`, §11) — do not implement a scheduler that picks a process without recording why.
- **`ProcessClass` has five values, not four:** `UNKNOWN`, `CPU_BOUND`, `IO_BOUND`, `INTERACTIVE`, `BALANCED`. `BALANCED` was added 2026-08-24 (issue #3) and means "ran, but unremarkable." Before it existed, everything that failed the CPU-bound and short-burst tests fell through to `UNKNOWN`, which made "the analyzer has no opinion" and "the analyzer never got to speak" the same word — and left almost every process in almost every run labelled `UNKNOWN`.
- **`UNKNOWN` now means exactly one thing: "has not run yet."** The GUI relabels it `PENDING` for that reason. If you ever see `UNKNOWN` on a process that has consumed CPU, that is a bug, not a classification.
- **Classify the running process, not just the ready queue.** The running process is held *outside* `readyQueue` while dispatched, so classifying only the queue means the one process actually accumulating evidence is the one never being looked at. `simulator.cpp` classifies the queue, the running process, and once more at completion. Don't undo that.
- **`IO_BOUND` is currently unreachable, and that is expected.** It requires `Process::ioEvents > 0`, and nothing in the engine ever increments `ioEvents` — there is no I/O model yet (PRD §2.1). The branch is correct and stays. Do not "fix" it by loosening the condition to make the label appear; the honest state is that it cannot fire until I/O bursts exist. (The `io_bound` workload preset is named for its *burst shape*, not because it emits I/O events.)
- Classification thresholds live in `behavior_analyzer.cpp` as named constants. Changing them is a logged decision, same rule as AARS weights.

## GUI rules (app/ — Qt/QML native dashboard)

- Follow `EDRD.md` exactly for color tokens, spacing, typography, component layout, and interaction/motion specs. Color tokens live in `app/qml/Theme.qml` (a `pragma Singleton` QML type — must be registered via `QT_QML_SINGLETON_TYPE` in CMakeLists.txt, see Architecture note in that file; a silent registration failure makes every `Theme.*` binding resolve to `undefined` with no hard error, only console warnings — check `qmlimportscanner`/runtime stderr if colors ever look wrong).
- **The visual system is "Terminal CLI" (set 2026-08-24, explicit user request — supersedes the earlier navy pivot, which is reverted).** Jet black `#0A0A0A` + phosphor green `#33FF00`, `radius: 0` everywhere, 1px pane borders, ASCII title bars and character-bar readouts, faint CRT scanlines, a blinking `█` cursor, shell metaphors in all copy. Full spec: `EDRD.md` §2.1 (palette), §2.3 (process identity), §2.4a (glow), §2.7 (surface language, **closed list — do not invent effects**), §3 (type). If a color, effect, or radius is not in §2, it does not go in.
- **Green is the chrome color, not the only color (revised 2026-08-24b, explicit user request — the running dashboard was "too much green in one page").** Structure stays green — borders, pane titles, prose, the shell prompt — and that is what still makes it read as a terminal. High-value things do not: `EDRD.md` §2.5 gives each ANSI hue exactly one role app-wide (**cyan = the scheduler's reasoning / the why-panel**, **magenta = the chosen process**, **blue = completed & reference data**, amber = warnings/WAITING, red = negative deltas, green = positive deltas). One hue, one role, everywhere — cyan is never a warning, magenta is never a finished process. Two uses are *categorical* rather than role-based and are exempt: per-process identity (§2.3) and the `CLASS` badge; both are always attached to a process and always spelled out in words. **Every role stays redundantly encoded** in a word, a sign or a glyph — nothing in this app is carried by hue alone.
- **Per-process identity is neon hue alone, indexed `pid % 8`** (`EDRD.md` §2.3). This reverted the green-brightness-step scheme of 2026-08-24 after one day: eight steps of one hue are steps a viewer has to *compare* rather than *recognize*, and the middle four were not separable at ticker size. **Revised again 2026-08-25 (explicit user request):** the glyph channel (a per-process ASCII fill character, `Theme.procGlyph`) that briefly rode alongside hue is gone — every process now renders identically in shape everywhere (a plain `"P<pid>"` label, a solid/segmented fill) and color is the only differentiator. `Theme.procGlyph`/`procGlyphs` no longer exist; `Theme.procShade(pid)` is the only per-process accessor. Never index `procShades` by hand.
- **Typography: two bundled families, split hard by role** (`EDRD.md` §3.1). **JetBrains Mono** is the default for everything — labels, prose, tables, PIDs, tick counters, bar fills. **Instrument Serif** is display-only and appears in exactly four places (splash wordmark, dashboard title, picker screen headings, why-panel verdict); it never touches a number, table, button, or line of prose, because it has no tabular figures. Both live in `app/fonts/` with their OFL files — keep those, redistribution condition. Register every `.ttf` with `QFontDatabase::addApplicationFont` in `app/main.cpp` *before* `QQmlApplicationEngine` is constructed, then `QGuiApplication::setFont` to JetBrains Mono. No QML file hardcodes a family string — use `Theme.fontMono` / `Theme.fontDisplay`.
- **Instrument Serif ships Regular and Italic only — no Black cut, no variable axes** (it replaced Fraunces on 2026-08-24b at explicit user request). So never set a weight or a `font.variableAxes` value on display type: Qt will silently synthesise a fake bold, and on a high-contrast serif that smears exactly the thin strokes that make it a display face. `display` and `h0` were raised (112→128px, 32→38px) to carry presence by size instead, because weight is not available to spend.
- **`GlowFrame.qml`'s layered-border glow is dead** — stacked low-opacity thick-bordered rectangles read as visible concentric outlines, not as light, and the user rejected them as tacky. Tuning the opacities does not fix it; the technique is the problem. Glow is now exactly two mechanisms (`EDRD.md` §2.4a): a real blurred **text bloom** via `MultiEffect` (`QtQuick.Effects` — the Qt 6.11 install here ships it, so the old "no MultiEffect dependency" constraint no longer applies), and **inverted video** on hover (fill goes `textPrimary`, label goes `textOnAccent`). No drop shadows anywhere. No glow halo on containers — an active pane switches its border color, it does not grow an aura.
- **The bloom is faint — `0.22` halo opacity, halved on 2026-08-24b at explicit user request — and it flickers** (`EDRD.md` §6.10). At the old `0.5` the halo competed with the glyphs instead of sitting behind them, so display type read washed out. **If the halo is the first thing you notice about a piece of text, it is too strong.** The splash runs hot via a wider blur radius, never via more opacity. The flicker is a shallow, deliberately *irregular* modulation of that same opacity (uneven holds, two dip depths) — a sine or an even loop reads as a pulse, where a real tube is arrhythmic. It is not a third glow mechanism; it animates a property that already exists. **Display type only** — never on tables, counters, prose, or any tick-updating value, the same boundary §2.7(9) draws for the typewriter reveal.
- Shared visual primitives live in `app/qml/` and are the **only** sanctioned way to build chrome: `TerminalPane.qml` (1px frame + ASCII title bar), `TerminalButton.qml` (bracketed label + inverted-video hover), `AsciiBar.qml` (character-bar readout), `BlinkingCursor.qml`, `PhosphorText.qml` (bloom + flicker), `ScanlineOverlay.qml`, `TypewriterText.qml`, `FluidBar.qml` (liquid progress fill), `ProcessHud.qml` (floating process explainer), `WorkloadCard.qml`. Reuse them; do not hand-roll a second version of any of them in a screen file.
- **`FluidBar.qml` is the one sanctioned exception to §2.7(7)'s "every quantity is a character bar" rule, and it is scoped to the process ticker only** (`EDRD.md` §6.9, logged deviation). Character bars stay everywhere else — scrub track, aging meters, score breakdown, workload load factor — because those are read as *values*. The ticker bars are read as *motion*, and a glyph bar can only move in whole-cell steps, which is the opposite of the fluid feel the user asked for. **Revised 2026-08-25 (explicit user request):** the fill body is now tiny segmented blocks (pitch ~6px + 2px gap, computed from available width) rather than one continuous rectangle, but each segment eases its own width in independently and a single travelling sheen still sweeps across the whole filled span regardless of the segment grid — that's what keeps a wall of small blocks reading as liquid rather than as a discrete LED meter. Its layers (per-segment eased fill, brighter leading meniscus on the true filled edge, travelling sheen while running) are all load-bearing; dropping any one leaves it reading as static blocks. Everything else about it stays Terminal CLI: zero radius, flat color, no gradient, no rounded cap, ASCII brackets at both ends. No per-process glyph anywhere in it — color (`fillColor`) is the only identity signal. **Do not extend `FluidBar` to other panels** without asking — the exception is the ticker.
- **Every pane border is green, always — no per-pane `accentColor` override** (revised 2026-08-25, explicit user request). `WhyPanel` and `AgingIndicator` previously claimed cyan/amber accent borders under the one-hue-one-role system; both are back to `TerminalPane`'s default green border/title. The hue-per-role system (line above, cyan=why/magenta=chosen/etc.) still governs *content* inside a pane — the "P1 RUNS NEXT" verdict, reason deltas, warning badges — just never the pane's own outline or title-bar text. If a pane ever needs to stand out, that has to happen inside it, not on its frame.
- **The chosen-process verdict text in `WhyPanel` (`"P<pid> RUNS NEXT"`) is colored `Theme.procShade(pid)`, not a fixed accent** (revised 2026-08-25, explicit user request, superseding the fixed-magenta call above) — same rule for the PID in every other panel. A process's color must be the same everywhere it appears (Gantt, ticker, ready queue, why-panel) so it can be tracked by color across panels; a fixed accent for "the chosen one" defeats that.
- **The Gantt playhead's move animation must scale its duration with the actual current playback rate (`Theme.baseTicksPerSecond * speed`), not the fixed 1x base rate** (fixed 2026-08-25 — `GanttChart.qml` takes a `ticksPerSecond` property, wired from `Dashboard.root.ticksPerSecond`). At higher speed multipliers the tick interval shrinks, so an animation duration computed from the fixed base rate no longer finishes before the next tick retargets it, and the playhead visibly falls behind and never catches up. The duration is capped at a fraction of the *current* interval so it always finishes in time — eased, not instant, but never lagging.
- **Do not put `anchors.*` on a direct child of `Column`/`Row`/`Grid`** — these QML positioners ignore/conflict with child anchors, producing unpredictable positioning (this exact bug shipped once — see issue #10). Use `ColumnLayout`/`RowLayout` + `Layout.alignment` instead whenever a child needs to be centered/aligned within a vertical or horizontal stack.
- Any custom component meant to be placed inside a `Layout` (`ColumnLayout`/`RowLayout`/`GridLayout`) needs either a real `implicitWidth`/`implicitHeight` or explicit `Layout.fillWidth: false`/`Layout.fillHeight: false` at each use site — an `Item`-based component with only anchored children reports `0x0` implicit size, which some layouts interpret as "no preference, fill available space" and stretch far past any `Layout.preferredWidth`/`Height` also set (issue #11).
- Intro sequence: `Splash.qml` holds on the glowing CHRONOS wordmark, then **auto-plays** a scroll-style reveal (the hero scrolls up and fades away on its own timer — no user scroll input required) into the algorithm picker. This replaced an earlier ink-drip concept per explicit user request; do not reintroduce a "drip" animation without asking first.
- Screen flow is fixed: Splash → algorithm picker → in-app workload picker (custom `ListView` over `WorkloadListModel`, **never** an OS file-explorer dialog) → Dashboard. Don't add a native file dialog anywhere in this flow.
- Dashboard panels mirror the old EDRD spec (Gantt timeline w/ playhead, ready-queue table, why-panel, aging indicator, playback controls) **plus** a new `ProcessTicker.qml` panel — one horizontal progress bar per process, stacked vertically, filling tick-by-tick until that process's `completionTime`. This is the one new panel not in the original spec; keep it, it was explicitly requested.
- **Playback at 1× is `Theme.baseTicksPerSecond` = 0.6 ticks/second — deliberately slow, lowered from 2 on explicit user request.** This is a teaching instrument: its whole value is that a viewer can follow *why* each decision happened, and at two decisions a second the why-panel changed faster than its own verdict line could be read. The 0.5×/1×/2×/4× multipliers mean a slow default costs a skimmer exactly one click. **Do not speed this back up because it feels sluggish to develop against** — use the 4× button. Nothing may hardcode a tick interval; read the token.
- **Gantt tick labels belong on the segment boundaries, not on a fixed ruler** (`EDRD.md` §5.2). Each segment prints its own start tick above its own left edge; only the last segment also prints an end tick, because every other segment's end is the next one's start. The old every-fifth-tick ruler (`0 5 10 15`) was removed at explicit user request: the question this chart answers is "when did P1 hand over?", and a fixed grid answers it only by making the viewer eyeball a segment edge against a gridline. Do not reintroduce a fixed ruler.
- **A floating overlay must not cover, or steal the pointer from, the thing it describes.** `ProcessHud` (`EDRD.md` §5.10) is positioned clear of the ticker, over the right-hand column, for exactly this reason — placed over the ticker it hides the bars it explains *and* takes the pointer from the hovered row's `HoverHandler`, so it flickers itself away as the viewer moves toward it. This bit once; keep the HUD out of the panel it reads from.
- All per-tick derived data (ready queue, why-panel, aging list, process ticker, CPU utilization, context switches) is computed in C++ (`app/ChronosBridge.cpp`), ported 1:1 from the old `dashboard/app.js`'s pure derivation helpers before that file was deleted. If you need to check the original derivation logic's intent, check `ChronosBridge.cpp`'s comments referencing it — `dashboard/app.js` no longer exists.
- On Windows, the app must declare DPI awareness at process startup (`SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)` in `app/main.cpp`, before `QGuiApplication` is constructed) — without it, Windows silently virtualizes/rescales the window bitmap for an "unaware" process, independent of anything Qt does internally (issue #12). Don't remove this call.

## What NOT to do

- Do not add real OS threads/pthreads/mutexes/semaphores to the core simulator. That's an optional stretch goal (PRD §6.5) — only build it if explicitly asked, and keep it isolated from the primary JSON-producing simulation path so a threading bug can't break the main deliverable.
- Do not add machine learning / trained models for workload classification. Behavior classification is rule-based thresholds only (PRD §6.3).
- Do not build multi-core, NUMA-aware, or multi-user/auth features. Single local user, single CPU, single simulation at a time.
- Do not add a persistent database.
- Do not build MLFQ before Milestones 0-2 are complete and working.
- Do not add icon libraries — inline SVG/unicode glyphs only. No second GUI toolkit, no web view, no Electron — see Stack above.
- Do not hardcode example/illustrative metrics anywhere in code, docs, or generated reports. All numbers in `results/`, comparison tables, and charts must come from actual simulation runs.
- Do not silently change the JSON schema, folder structure (PRD §4.2), or CMake target layout without flagging the change.
- Do not reintroduce a native OS file dialog anywhere in the GUI flow, or an ink-drip splash animation, without asking first (both were explicitly replaced per user request).
- Do not reintroduce rounded corners, drop shadows, gradients on surfaces, container glow halos, or any color outside `EDRD.md` §2.1's table. `EDRD.md` §2.7 is a closed list of permitted effects — additions to it are a spec change, not an implementation choice.
- Do not add Matrix rain, glitch-shatter, fake boot-log filler text, or typewriter animation on tick-updating data (`EDRD.md` §2.7, explicitly out of scope).
- Do not use Instrument Serif for numbers, tables, buttons, or prose — it has no tabular figures and every live value would jitter as digits change. Do not set a weight or a variable axis on it either (see GUI rules — it has neither, and Qt will fake a bold).
- Do not substitute a different font family for either bundled font, or add a third one.
- Do not reintroduce a monochrome/green-only palette, a fixed Gantt tick ruler, or a faster default playback rate — all three were changed on 2026-08-24b at explicit user request, and reverting any of them undoes something the user asked for by name.
- Do not reintroduce a per-process glyph/symbol channel (§2.3 is hue-only as of 2026-08-25) or resurrect `Theme.procGlyph` — removed at explicit user request specifically to get rid of it.
- Do not loosen a classification threshold to make `IO_BOUND` appear. It is unreachable because the engine has no I/O model, which is the honest state — see Algorithm rules.

## Working in parallel (multiple agents)

The Terminal CLI redesign was partitioned across GitHub issues **#14–#20** and has now **landed** — all six work issues are closed, and #20 holds the record of how the work was split. Nothing there is open work any more.

If a future change is split across agents again, the rules that made that partition hold are worth reusing:

- **One agent per issue, and touch only the files that issue owns.** If your change seems to need a file you do not own, say so on the tracking issue rather than editing it — a two-line edit to a file someone else is rewriting costs more to untangle than it saves.
- **The token layer blocks everything visual.** `Theme.qml` plus the shared primitives have to exist before any screen can be restyled against them.
- **`app/ChronosBridge.cpp` is shared, so own it at function level.** Surgical edits only — no reformatting or reordering of code you are not changing.
- **Never edit `EDRD.md` §2 or §3 to match your code.** The spec leads and the code follows. If the spec is wrong or impossible, get it changed there first — a silently re-specced token defeats the point of having one source of truth.
- **Build *and run* before handing off.** A QML type error does not fail the CMake build; it fails at runtime with a console warning. See the stderr note under Commands.
- Issues **#9–#13 are historical postmortems** of bugs already fixed, kept as a record. Not open work. Closed 2026-08-25 at explicit user request (previously left open by design — see git history of this file if that choice ever needs re-examining).
- Issue **#3 (AARS mostly-UNKNOWN classification) is fixed** as of 2026-08-24 and was closed 2026-08-25. See Algorithm rules for what the fix was.
- Genuinely open work: **#1** (`analysis.py` — the big one), **#4** (MLFQ), **#5** (arrival-triggered AARS preemption), **#6** (pick a Milestone 4 stretch goal), **#7** (edge-case coverage, PRD §10), **#8** (presentation deck + timed rehearsal).

## Testing

- Before marking any scheduler "done," run it against all 10 edge cases in `PRD.md` §10.
- Verify FCFS and SJF by hand against the worked P1/P2/P3 example in PRD §9 (Milestone 1) before trusting any other algorithm's output.
- Unit-test tie-breaking (lowest PID wins) for every algorithm that can have score/priority/burst ties.
- After any `chronos_core`/CLI refactor, byte-diff `chronos` CLI output against a pre-change baseline for all five algorithms × all workload presets before trusting the change — this caught nothing regressing during the `chronos_core` library split.
- **The smoke test for any engine change is the full matrix: 8 workloads × 5 algorithms = 40 runs, all exiting 0.** Loop `workloads/*.json` against `fcfs sjf priority rr aars`. This is fast and catches most breakage immediately.
- **The smoke test for any GUI change is launching it and reading stderr** — a QML type error does not fail the CMake build, it fails at runtime as a console warning, and a silent binding failure renders as a blank panel. Zero warnings is the current baseline; anything on stderr is a regression. See the stderr redirection note under Commands, and issues #15/#16 for what this looks like when missed.

## Commands

```bash
# Configure + build (from repo root)
# On this machine, bare `cmake -S . -B build` picks NMake (needs MSVC) as its
# default generator even though the toolchain is MSYS2/UCRT64 g++ — pass the
# generator explicitly. Qt6 is installed via MSYS2 pacman (mingw-w64-ucrt-x86_64-qt6-base
# + -qt6-declarative) into the same ucrt64 prefix, so CMAKE_PREFIX_PATH must point there too.
# ucrt64/bin must be on PATH for *configure and build*, not only to run:
# qmlimportscanner and rcc are Qt binaries that need the Qt DLLs themselves,
# and without them CMake fails with
#   "Failed to scan target chronos_app for QML imports: Exit code 0xc0000139"
# (STATUS_ENTRYPOINT_NOT_FOUND), which never names the real cause.
PATH="/c/msys64/ucrt64/bin:$PATH" \
  cmake -S . -B build -G "MinGW Makefiles" -DCMAKE_PREFIX_PATH="C:/msys64/ucrt64"
PATH="/c/msys64/ucrt64/bin:$PATH" cmake --build build

# If linking fails with "cannot open output file ... Permission denied", a
# previous chronos_app.exe is still running and holding the file open:
#   powershell -Command "Get-Process chronos_app -EA SilentlyContinue | Stop-Process -Force"

# Run simulator (produces results/<name>.json)
./build/engine/chronos --algorithm <fcfs|sjf|rr|priority|aars> --workload workloads/<name>.json --out results/<name>.json

# Run the native GUI — needs C:\msys64\ucrt64\bin on PATH so Windows can find
# the Qt6*.dll / mingw runtime DLLs (not needed if that's already on PATH).
PATH="/c/msys64/ucrt64/bin:$PATH" ./build/app/chronos_app.exe

# The GUI is a windowed (non-console) binary, so qWarning and console.log do
# NOT reach a pipe — piping it looks like the app printed nothing. To read QML
# warnings, redirect both streams to files from PowerShell:
#   Start-Process chronos_app.exe -NoNewWindow -PassThru `
#     -RedirectStandardOutput out.txt -RedirectStandardError err.txt
# QML binding errors and failed font loads land in err.txt. This is the only
# way to see them, and a silent binding failure renders as a blank panel.

# Run the full engine matrix — the standard smoke test (40 runs, all must exit 0)
for w in workloads/*.json; do n=$(basename $w .json); \
  for a in fcfs sjf priority rr aars; do \
    ./build/engine/chronos --algorithm $a --workload $w --out results/${n}_${a}.json || echo "FAIL $n/$a"; \
  done; done

# Run comparison analysis (Milestone 2 — analysis/ is EMPTY, analysis.py not yet built; issue #1)
python3 analysis/analysis.py results/*.json

# Format C++ (if clang-format config exists)
clang-format -i engine/**/*.cpp engine/**/*.h
```

**Antivirus note:** on this machine, ESET has flagged the freshly-linked `chronos.exe` as a heuristic false positive (`Trojan.Win64/PSW.Agent_AGen.DL`) and deleted it seconds after a build, independent of file contents (a trivial hello-world binary built the same way in the same folder was unaffected). If a build produces a 0-byte or vanishing `chronos.exe`, this is almost certainly why — check `C:\ProgramData\ESET\ESET Security\Logs\virlog.dat`. Pausing/disabling real-time protection for the build is a one-time workaround; don't treat it as a real security issue in the code.

## File layout

Follow `PRD.md` §4.2 (updated) exactly. `engine/` (core + CLI), `app/` (Qt/QML GUI — `app/*.{h,cpp}` for the C++ bridge/models, `app/qml/*.qml` for screens/components), `analysis/`, `workloads/`. `results/` and `logs/` are generated output — gitignored, never hand-edited. `dashboard/` no longer exists.

## Git

Commit only when asked. No `--no-verify`, no force-push, no amending existing commits unless explicitly requested.
