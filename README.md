# ChronOS

Adaptive CPU scheduling simulator that dynamically adjusts process priority and time quantum based on runtime behavior, with a replay dashboard and (from Milestone 2 on) performance comparison against FCFS, SJF, Round Robin, Priority, and — once Milestone 3 lands — MLFQ.

**Status: Milestone 1 (MVP) complete.** Engine, all 5 required schedulers, and the full dashboard are built, verified, and pushed. See [`PROJECT_STATUS.md`](PROJECT_STATUS.md) for the live snapshot, [`CHANGELOG.md`](CHANGELOG.md) for history, and the [GitHub Issues](https://github.com/vrrroro/ChronOS/issues) for what's left (Milestones 2–4).


## Quickstart

```bash
# Configure + build (from repo root)
# On Windows/MSYS2, pass the generator explicitly — see CLAUDE.md's Commands
# section for why the bare command picks the wrong one on that toolchain.
cmake -S . -B build -G "MinGW Makefiles"   # or just `cmake -S . -B build` elsewhere
cmake --build build

# Run a simulation (produces results/<name>.json + logs/scheduler.log)
./build/engine/chronos --algorithm aars --workload workloads/interactive.json --out results/interactive_aars.json

# Open the dashboard — no server needed, just open the file
open dashboard/index.html    # or double-click / drag into a browser
```

In the dashboard, use the file picker (footer `RUN` button, or drag-drop) to load a `results/*.json` file and replay it — Gantt timeline, ready queue, the "why this process?" panel, playback controls.

Workload presets live in `workloads/` (`cpu_heavy.json`, `interactive.json` so far — `mixed`/`starvation` are Milestone 2, [issue #2](https://github.com/vrrroro/ChronOS/issues/2)). `--algorithm` accepts `fcfs`, `sjf`, `rr`, `priority`, or `aars`.

## A note on "logged deviations"

Several things in the built dashboard don't match `PRD.md`/`EDRD.md`'s original spec literally — GSAP animations, a scroll-driven intro splash, and a site-wide Apple-style font, all added post-Milestone-1 on explicit request. These are **documented, not silent**: each one has a "Logged deviation" note at its source in `CLAUDE.md` and the relevant `EDRD.md` section, explaining what changed and why. If the running dashboard looks different from what `EDRD.md`'s base sections describe, check those notes before assuming either the code or the doc is wrong — they're reconciled on purpose.

## Repo layout

```
engine/       C++17 simulation core + schedulers (FCFS/SJF/RR/Priority/AARS)
dashboard/    static HTML/CSS/JS replay UI, no build step, no server
analysis/     Python comparison tables + charts (Milestone 2, not started)
workloads/    input JSON presets
results/      generated engine output (gitignored)
logs/         generated scheduler decision logs (gitignored)
```

Full folder-structure rationale: `PRD.md` §4.2 / `ARCHITECTURE.md` §1.
