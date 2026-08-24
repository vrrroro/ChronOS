# ChronOS — Project Status

**Last updated:** 2026-08-25
**Current phase:** Terminal CLI redesign + 2026-08-24b palette/motion revision complete and **build/run-verified**; committing today
**Current milestone:** Milestone 2 (Comparison & polish) — the workload-preset half is done; `analysis/analysis.py` (issue #1) is the one substantial thing left

> This file is a living snapshot, updated as work happens — it shows where the project stands *right now*. For the full history of changes, see `CHANGELOG.md`. For what's planned, see `PRD.md` §9 (milestones).

---

## 1. At a glance

| | |
|---|---|
| Time elapsed | Milestone 0 + 1 of 4–6 weeks, plus three out-of-sequence pivots (native app → Terminal CLI redesign → 2026-08-24b palette/motion revision) |
| Milestone | Milestone 1 (MVP) complete; Milestone 2 part-done (8/8 workload presets shipped; `analysis.py` outstanding) |
| Engine | Working — FCFS, SJF, RR, Priority, AARS. `chronos_core` shared lib + slim CLI. All 40 engine runs (8 workloads × 5 algorithms) pass. AARS mostly-`UNKNOWN` classification bug (issue #3) is fixed — see Algorithm rules in `CLAUDE.md`. |
| GUI | Native Qt 6/QML app (`app/`, target `chronos_app`) on the **Terminal CLI** visual system, revised 2026-08-24b then 2026-08-25: green is chrome only and is the *only* pane-border color (no per-pane accent), five ANSI hues each own exactly one app-wide content role (`EDRD.md` §2.5), per-process identity is hue-only (`§2.3`, no glyph channel as of 2026-08-25), bundled JetBrains Mono + Instrument Serif, segmented liquid `FluidBar` process ticker, hover `ProcessHud`, slowed default playback (0.6 ticks/sec) with a Gantt playhead that scales with actual speed. Builds clean, launches with **zero QML warnings on stderr**. |
| Analysis | Not started (Milestone 2 scope, [issue #1](https://github.com/vrrroro/ChronOS/issues/1)) — the only substantial thing left before the project is demo-complete |
| Blockers | None — build-verified, launch-verified, stderr-clean |
| Docs | Fully synced as of 2026-08-25 — `PRD.md`, `EDRD.md`, `ARCHITECTURE.md`, `CLAUDE.md`, `README.md`, `CHANGELOG.md`, this file |
| Roadmap tracking | [GitHub Issues](https://github.com/vrrroro/ChronOS/issues) — #1, #4–#8 genuinely open (M2/M3/M4); #2, #3, #9–#20 closed |

---

## 2. What's done

- [x] Project scoped and de-risked for a solo 4–6 week beginner build (`PRD.md`)
- [x] Dashboard visual/interaction design specified (`EDRD.md`)
- [x] System architecture, module boundaries, and data contracts specified (`ARCHITECTURE.md`)
- [x] AI-assisted build rules and constraints documented (`CLAUDE.md`)
- [x] Change history established (`CHANGELOG.md`)
- [x] Milestone 0 (Setup): toolchain, folder scaffold, `Process`/`State`/`ProcessClass`, fake `results.json`, dashboard skeleton rendering it
- [x] Milestone 1 (MVP): simulator core, all 5 schedulers (FCFS/SJF/RR/Priority/AARS), full dashboard, initial workload presets — see `CHANGELOG.md` `[0.4.0]` for details
- [x] ~~Post-M1 dashboard polish~~ (GSAP animations, scroll-driven intro, Apple-style font) — superseded by the pivot below; `dashboard/` no longer exists. History kept in `CHANGELOG.md`.
- [x] **Architecture pivot (2026-08-23):** web dashboard replaced with a native Qt 6/QML desktop app. `chronos_core` static lib split out of `engine/`, shared by CLI and GUI. `app/` — in-process engine link (`ChronosBridge`), in-app workload browser (no OS dialog), full screen flow. CLI regression-verified byte-identical to pre-pivot baseline.
- [x] **Terminal CLI redesign (2026-08-24):** jet black + phosphor green, zero radius, ASCII-framed panes, CRT scanlines. Shared QML primitives replace ad-hoc chrome. Workload library grown 2 → 8 presets, 3–20 processes each, shaped to separate the five algorithms. Fixed the collapsed dashboard column (#15) and the blank why-panel (#16).
- [x] **2026-08-24b palette/type/motion revision** (the running dashboard was "too much green in one page"): green demoted from only-color to chrome-only; five ANSI hues (cyan/magenta/blue/amber/red) each own exactly one app-wide role (`EDRD.md` §2.5), every role redundantly encoded so nothing is carried by hue alone; per-process identity reverted to hue+glyph after a one-day green-brightness-step experiment proved unreadable; `GlowFrame.qml` deleted (concentric-outline technique rejected) in favor of real `MultiEffect` bloom + inverted-video hover, halo halved to 0.22 opacity with arrhythmic flicker; Fraunces replaced by Instrument Serif (Regular+Italic only, display-only, four places); Gantt fixed ruler replaced with per-segment boundary labels; default playback slowed 2 → 0.6 ticks/sec; new `FluidBar` liquid ticker fill and `ProcessHud` hover explainer added.
- [x] **AARS classification fix (2026-08-24, issue #3):** one completed burst is now enough to classify, and CPU consumed so far counts as CPU-bound evidence mid-burst; added `BALANCED` as a fifth `ProcessClass` value. `UNKNOWN` now means exactly "has not run yet" (relabeled `PENDING` in the GUI) instead of silently meaning that for nearly every process in nearly every run.
- [x] All 8 workload presets shipped ([issue #2](https://github.com/vrrroro/ChronOS/issues/2), closed): `tiny_batch`, `cpu_heavy`, `interactive`, `starvation`, `mixed`, `io_bound`, `burst_arrivals`, `long_tail` — see the table in `README.md`.
- [x] 20 GitHub issues filed across the project's history; #2, #3, #9–#20 now closed, #1/#4–#8 genuinely open — https://github.com/vrrroro/ChronOS/issues
- [x] **2026-08-25 (doc sync commit):** full doc sync (`PRD.md` §5.1/§5.3/§6.3, `ARCHITECTURE.md` §3.4/§4.3/§5.1/§5.3, `README.md`, this file) to match the 2026-08-24b revision; build, 40-run engine smoke test, and GUI stderr check all re-verified clean before committing. Also fixed a real QML warning found during that verification (`ProcessHud.qml`'s SWITCHES row assigning raw `undefined` to a QString binding at construction).
- [x] **2026-08-25 (GUI polish pass, explicit user request):** per-process identity dropped its glyph channel entirely — hue alone now (`EDRD.md` §2.3), no more `█ ▓ ▒ ░ ║ ≡ · #` fill characters anywhere; `FluidBar`'s liquid fill is now tiny segmented blocks that each ease independently rather than one continuous rectangle (`§6.9`); every pane border reverted to green-only, removing `WhyPanel`'s cyan and `AgingIndicator`'s amber accent borders (`§2.4`); the why-panel's chosen-process verdict is colored by that process's own hue instead of a fixed magenta; and the Gantt playhead's move animation now scales its duration with the actual current playback speed instead of the fixed 1× rate, fixing visible lag at 2×/4×.

## 3. What's in progress

Nothing — the pivot, the redesign, and the 2026-08-24b revision are all build-verified and now committed. Next work is genuinely new, not cleanup: `analysis/analysis.py` (issue #1).

## 4. What's next (Milestone 2 — Comparison & polish, `PRD.md` §9)

Tracked as GitHub issues (linked) — this list mirrors them, but the issues are the source of truth if the two ever drift:

- [ ] [#1](https://github.com/vrrroro/ChronOS/issues/1) `analysis/analysis.py`: read multiple result JSONs, build comparison table, generate the 4 charts from PRD §8.2. `analysis/` is currently an empty directory. Read `processStats[]`'s widened fields (`arrivalTime`, `burstTime`, `contextSwitches`, `class`) directly rather than recomputing them from workload files.

Milestone 3 ([#4](https://github.com/vrrroro/ChronOS/issues/4) MLFQ, [#5](https://github.com/vrrroro/ChronOS/issues/5) AARS arrival-triggered preemption) and Milestone 4 ([#6](https://github.com/vrrroro/ChronOS/issues/6) stretch goal, [#7](https://github.com/vrrroro/ChronOS/issues/7) edge-case tests, [#8](https://github.com/vrrroro/ChronOS/issues/8) presentation prep) come after.

---

## 5. Milestone tracker

| Milestone | Target | Status | Notes |
|---|---|---|---|
| 0 — Setup | Week 1 (~2–3 days) | Done | |
| 1 — MVP (FCFS, SJF, RR, Priority, AARS + dashboard) | End of week 3 | Done | |
| 2 — Comparison & polish | End of week 4 | In progress | Workload presets (8/8) and GUI polish done; `analysis.py` (#1) outstanding |
| 3 — MLFQ + depth | End of week 5 (if time allows) | Not started | |
| 4 — Stretch goals + presentation prep | Week 6 (optional) | Not started | |

## 6. Component status

| Component | Status | Notes |
|---|---|---|
| `engine/process.h/.cpp` | Done | |
| `engine/behavior_analyzer.*` | Done | Revised 2026-08-24 (issue #3) — see `CLAUDE.md` Algorithm rules |
| `engine/schedulers/fcfs.cpp` | Done | |
| `engine/schedulers/sjf.cpp` | Done | |
| `engine/schedulers/round_robin.cpp` | Done | |
| `engine/schedulers/priority.cpp` | Done | fixed-interval aging, +1 per 5 ticks waited |
| `engine/schedulers/aars.cpp` | Done | full §6.1–6.4 formula, honest weights, not hand-tuned to flatter results |
| `engine/schedulers/mlfq.cpp` | Not started (Milestone 3) | |
| `engine/simulator.*` | Done | |
| `engine/workload_io.*`, `engine/scheduler_factory.*` | Done | pulled out of `main.cpp` so CLI + GUI share identical code |
| `chronos_core` (CMake static lib target) | Done | |
| ~~`dashboard/`~~ | **Deleted** | replaced by `app/` |
| `app/ChronosBridge.*`, `app/WorkloadListModel.*` | Done | in-process engine link + per-tick derived data |
| `app/qml/*` (Theme, Splash, AlgorithmPicker, WorkloadPicker, Dashboard + panels, ProcessHud, FluidBar) | Done | build-verified, zero QML warnings on stderr; `GlowFrame.qml` deleted 2026-08-24b, replaced by `PhosphorText`/`MultiEffect` bloom |
| `analysis/analysis.py` | Not started (Milestone 2 — [#1](https://github.com/vrrroro/ChronOS/issues/1)) | unaffected by the pivots — still reads CLI-written JSON |
| `workloads/*.json` presets | 8 of 8 done | `tiny_batch`, `cpu_heavy`, `interactive`, `starvation`, `mixed`, `io_bound`, `burst_arrivals`, `long_tail` |
| `CMakeLists.txt` | Done | needs `-G "MinGW Makefiles" -DCMAKE_PREFIX_PATH="C:/msys64/ucrt64"` on this machine (Qt6 added) — see `CLAUDE.md` Commands |

---

## 7. Open questions / decisions pending

Carried from `PRD.md` §14 — revisit once real data exists:

- [x] ~~Do the AARS weight thresholds actually separate workloads well?~~ Resolved 2026-08-24 (issue #3) — the near-universal `UNKNOWN` result was a classifier mechanism bug (only classifying the ready queue, requiring 2 completed bursts), not a threshold-tuning problem. Fixed; thresholds themselves are unchanged and still retunable later if real data calls for it.
- [ ] Is the 4–6 week estimate holding once Milestone 0/1 actual time-spent is known?
- [ ] Which single stretch goal (`PRD.md` §6.5), if any, is worth pursuing in Milestone 4?

## 8. Blockers

None currently.

## 9. Known risks being watched

See `PRD.md` §13 for full list. Top of mind right now:

- MLFQ complexity, if/when Milestone 3 is reached
- **This machine's antivirus (ESET) heuristically flags freshly-linked `chronos.exe` as a false positive** (`Trojan.Win64/PSW.Agent_AGen.DL`) and deletes it seconds after a build — confirmed unrelated to actual file content (a trivial hello-world binary built the same way was unaffected) and unrelated to the code itself. Not a security concern in the project, but worth knowing about if a rebuild ever produces a 0-byte or missing `chronos.exe` — see `CLAUDE.md` Commands for the detail.
- Real on-screen visual QA of `chronos_app` on an actual (non-sandboxed) machine is still worth doing before treating the GUI as fully verified end-to-end — automated capture in this dev environment has been unreliable in the past (traced to a since-fixed DPI-awareness issue, #12); stderr-clean launches and direct QML property inspection are the verification used so far.

---

## How to update this file

After finishing a milestone task or hitting a blocker: move the item from §4 to §2, update §5/§6 status columns, bump "Last updated," and add the corresponding entry to `CHANGELOG.md` under `[Unreleased]`. Keep this file short and current — it's a status snapshot, not a log; history belongs in `CHANGELOG.md`.
