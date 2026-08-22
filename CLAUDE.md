# CLAUDE.md — ChronOS

Project: ChronOS — Adaptive CPU Scheduling Engine (AARS algorithm). Full spec: `PRD.md`. Visual/UX spec: `EDRD.md`. Read both before writing code. This file is operating rules only — do not duplicate spec content here; if it's not here, it's in those two files.

## Stack (do not substitute)

- Simulation engine: C++17, STL only. No Boost, no external C++ libs except `nlohmann/json` (single header).
- Build: CMake.
- Dashboard: plain HTML/CSS/JS. No React/Vue/Svelte/any framework. No build step (no webpack/vite/npm bundling for the dashboard itself).
- Charting in dashboard: Chart.js via `<script>` tag only.
- Analysis: Python 3 + matplotlib + pandas.
- No database. No backend server, live socket, or REST API anywhere in the MVP/Milestone 1-2 scope (see PRD 2.2).

## Architecture contract

- Three subsystems, file-boundary only: C++ engine → JSON → dashboard/analysis. Never wire the engine to the dashboard over a live connection unless explicitly building the Milestone-4 stretch goal (PRD 7.7 edit-note) — ask before doing this.
- `PRD.md` §5.2 and §5.3 are the JSON schemas. Do not change field names/shapes without updating both the PRD and every consumer (engine writer, dashboard reader, analysis.py reader) in the same change.
- Process struct fields, State enum, ProcessClass enum: exactly as in `PRD.md` §5.1. Don't rename or restructure without updating the PRD.

## Algorithm rules

- Implement algorithms in this order only, matching PRD milestones: FCFS → SJF (non-preemptive) → Round Robin → Priority (+ aging) → AARS. MLFQ is Milestone 3 — do not build it before the other five work end-to-end.
- AARS formula and term weights: `PRD.md` §6.1–6.4. Weights there are starting values, not fixed — but any change to them must be a deliberate, logged decision (write it down, don't silently retune).
- Never hand-tune AARS weights or thresholds specifically to make comparison numbers look better before reporting results. Run first, report what comes out, including losses. (PRD §2.4 — this is a hard project requirement, not a style preference.)
- Every scheduling decision must be logged with candidate scores and reason tags (PRD §5.3 `decisionLog`, §11) — do not implement a scheduler that picks a process without recording why.

## Dashboard rules

- Follow `EDRD.md` exactly for color tokens, spacing, typography, component layout, and interaction/motion specs. Do not invent new colors, fonts, spacing values, or animation patterns — use the CSS custom properties in EDRD §8.1 as-is.
- Jet black + neon green terminal aesthetic is fixed. No light theme, no theme toggle, no alternate color schemes.
- Monospace font stack only (EDRD §3.1). No secondary sans-serif font unless the user explicitly asks for the fallback described in the EDRD §3.1 edit-note.
- Dashboard replays a static JSON file (play/pause/step/scrub). It does not stream live from a running process.

## What NOT to do

- Do not add real OS threads/pthreads/mutexes/semaphores to the core simulator. That's an optional stretch goal (PRD §6.5) — only build it if explicitly asked, and keep it isolated from the primary JSON-producing simulation path so a threading bug can't break the main deliverable.
- Do not add machine learning / trained models for workload classification. Behavior classification is rule-based thresholds only (PRD §6.3).
- Do not build multi-core, NUMA-aware, or multi-user/auth features. Single local user, single CPU, single simulation at a time.
- Do not add a persistent database.
- Do not build MLFQ before Milestones 0-2 are complete and working.
- Do not make the dashboard responsive/mobile-first. Target laptop screens ≥1280px only (EDRD §1.2, §8.3).
- Do not add animation/icon libraries. Plain CSS transitions/keyframes and inline SVG/unicode glyphs only (EDRD §8.3).
- Do not hardcode example/illustrative metrics anywhere in code, docs, or generated reports. All numbers in `results/`, comparison tables, and charts must come from actual simulation runs.
- Do not silently change the JSON schema, folder structure (PRD §4.2), or CMake target layout without flagging the change.
- Do not skip the fake-JSON-first step in Milestone 0 — build/verify the dashboard against a hand-written sample `results.json` before wiring it to the real engine output.

## Testing

- Before marking any scheduler "done," run it against all 10 edge cases in `PRD.md` §10.
- Verify FCFS and SJF by hand against the worked P1/P2/P3 example in PRD §9 (Milestone 1) before trusting any other algorithm's output.
- Unit-test tie-breaking (lowest PID wins) for every algorithm that can have score/priority/burst ties.

## Commands

```bash
# Configure + build (from repo root)
cmake -S . -B build
cmake --build build

# Run simulator (produces results/<name>.json)
./build/engine/chronos --algorithm <fcfs|sjf|rr|priority|mlfq|aars> --workload workloads/<name>.json --out results/<name>.json

# Open dashboard (static, no server)
open dashboard/index.html    # or just double-click / drag into browser

# Run comparison analysis
python3 analysis/analysis.py results/*.json

# Format C++ (if clang-format config exists)
clang-format -i engine/**/*.cpp engine/**/*.h
```

> ✎ Adjust binary name/CLI flags above once `main.cpp`'s actual argument parsing is written — this is a starting convention, not yet verified against real code.

## File layout

Follow `PRD.md` §4.2 exactly. New files go in the matching subfolder (`engine/schedulers/`, `dashboard/`, `analysis/`, `workloads/`). `results/` and `logs/` are generated output — gitignored, never hand-edited.

## Git

Commit only when asked. No `--no-verify`, no force-push, no amending existing commits unless explicitly requested.
