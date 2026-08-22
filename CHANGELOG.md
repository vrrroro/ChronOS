# Changelog

All notable changes to the ChronOS project are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This log currently covers planning/documentation only — no code has been written yet. Once implementation starts, add entries under a new `[Unreleased]` section as you go; move it to a dated/versioned heading at each milestone (see `PRD.md` §9).

---

## [Unreleased]

Post-Milestone-1 dashboard polish, done outside the formal milestone sequence on explicit request. All four items below are **deliberate, logged deviations** from `PRD.md`/`EDRD.md`'s original locked specs (no animation library, monospace-only, no scrolling) — each is documented at its source in `CLAUDE.md`'s Dashboard rules and the relevant `EDRD.md` section, not a silent drift. Milestone 2 work (`PRD.md` §9) has **not** started yet — see `PROJECT_STATUS.md` §4 and the [GitHub issues](https://github.com/vrrroro/ChronOS/issues) for that roadmap.

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
