# ChronOS

Adaptive CPU scheduling simulator that dynamically adjusts process priority and time quantum based on runtime behavior, with a native replay GUI and performance comparison against FCFS, SJF, Round Robin, Priority, and two real operating-system schedulers: textbook **MLFQ** (shown as "MLFQ (Windows)") and Linux's **CFS** ("CFS (Linux)").

**Status (2026-10-22): Milestones 0–2 complete; Milestone 3's MLFQ done, plus CFS.** Seven algorithms, a side-by-side compare screen in the GUI, `chronos --compare`, and `analysis/analysis.py`. Earlier history: **Milestone 1 (MVP) complete, plus two out-of-sequence pivots.** Engine and all 5 required schedulers are built and verified, unchanged. The original web dashboard was replaced with a native Qt 6/QML desktop app (2026-08-23), which was then redesigned onto the **Terminal CLI** visual system (2026-08-24) — both at explicit request, both logged. The workload library also grew from 2 presets to 8. See [`PROJECT_STATUS.md`](PROJECT_STATUS.md) for the live snapshot, [`CHANGELOG.md`](CHANGELOG.md) for history, and the [GitHub Issues](https://github.com/vrrroro/ChronOS/issues) for what's left (Milestones 2–4).

## Quickstart

```bash
# Configure + build (from repo root)
# On Windows/MSYS2, pass the generator + Qt6 prefix explicitly — see AGENTS.md's
# Commands section for why the bare command picks the wrong generator on that
# toolchain, and where Qt6 needs to be installed from.
PATH="/c/msys64/ucrt64/bin:$PATH" \
  cmake -S . -B build -G "MinGW Makefiles" -DCMAKE_PREFIX_PATH="C:/msys64/ucrt64"
PATH="/c/msys64/ucrt64/bin:$PATH" cmake --build build

# Run a simulation via the CLI (produces results/<name>.json + logs/scheduler.log)
./build/engine/chronos --algorithm aars --workload workloads/mixed.json --out results/mixed_aars.json

# Or launch the native GUI directly — pick the algorithm and workload in-app,
# no separate terminal step, no file to open (needs Qt6 DLLs on PATH — see AGENTS.md).
# [ COMPARE TWO ] on the first screen runs two algorithms on the same processes side by side.
PATH="/c/msys64/ucrt64/bin:$PATH" ./build/app/chronos_app.exe

# Two algorithms on the same workload, metric by metric
./build/engine/chronos --compare aars,mlfq --workload workloads/mixed.json

# Every algorithm on every preset, then the comparison report
python analysis/run_all.py
python analysis/analysis.py results/*.json --versus aars mlfq cfs

# Engine test suite: PRD §10 edge cases, hand-checked schedules, input
# validation, and the C++/Python comparison cross-check (stdlib only)
python tests/run_tests.py            # add --quick to skip the 500-process case
```

Workload presets live in `workloads/` — eight of them, from 3 to 20 processes; see the table below. `--algorithm` accepts `fcfs`, `sjf`, `rr`, `priority`, `aars`, `mlfq`, or `cfs`. MLFQ and CFS derive their parameters from the workload's `quantum` (MLFQ queues `q/2q/4q`, boost every `10q`; CFS minimum slice `q`); a workload may override them with optional `"mlfq"` / `"cfs"` blocks, and a process may carry a `"nice"` value (otherwise derived from its priority) — see `PRD.md` §5.2 and §6.6–6.7.

## AARS against the OS schedulers

Run with untuned AARS and textbook/kernel-default MLFQ and CFS (`PRD.md` §6.6–6.7), over the eight presets. These are measured results, not targets — regenerate them with the commands above.

- **AARS beats both MLFQ and CFS** on average waiting, average turnaround and context switches on **Mixed Workload**, **Long-Tail Load** and **Clustered Arrivals**; on worst-case waiting on Mixed; and on average response and fairness on **CPU-Heavy Batch**.
- **AARS loses** to MLFQ on every metric on **Starvation Stress Test** and on all but context switches on **Tiny Batch**, and on average response on most mixed loads — MLFQ's top queue plus preemption gets new arrivals onto the CPU faster than AARS, which never preempts on arrival (issue #5). CFS beats AARS on fairness on most presets, which is what CFS is built for.
- On **Interactive Session** and **I/O-Bound Burst** the load is too light to separate them — most metrics tie.

## A note on "logged deviations"

Several things in the GUI don't match `PRD.md`/`EDRD.md`'s *original* spec literally — most significantly, the entire dashboard is now a native Qt/QML desktop app instead of a web page (explicit request, 2026-08-23), with the **Terminal CLI** visual system (jet black + phosphor green, zero radius, ASCII-framed panes, CRT scanlines — `EDRD.md` §2.7) and an auto-playing reveal intro (instead of a scroll-driven web intro). These are **documented, not silent**: each has a "Logged deviation" note at its source in `AGENTS.md` and the relevant `PRD.md`/`EDRD.md` section, explaining what changed and why. If the running app looks different from what a doc's base sections describe, check those notes before assuming either the code or the doc is wrong — they're reconciled on purpose.

## Repo layout

```
engine/       C++17 simulation core (chronos_core lib) + CLI (FCFS/SJF/RR/Priority/AARS/MLFQ/CFS)
app/          native Qt 6/QML desktop GUI (chronos_app) — replaces the old web dashboard
analysis/     run_all.py (every algorithm × workload) + analysis.py (tables, head-to-head, charts)
tests/        run_tests.py — engine test suite (edge cases, invariants, validation)
workloads/    input JSON presets
results/      generated CLI output (gitignored)
logs/         generated scheduler decision logs (gitignored)
```

Full folder-structure rationale: `PRD.md` §4.2 / `ARCHITECTURE.md` §1–2.

## Workload presets

Eight presets, spanning **3 to 20 processes**, deliberately shaped so the five
algorithms behave visibly differently on them rather than all producing similar
Gantt charts. Every figure below is computed from the file itself:

| File | Name | Procs | Profile | Burst range | Avg | Total | Arrivals | Quantum | Load |
|---|---|--:|---|---|--:|--:|---|--:|--:|
| `burst_arrivals.json` | Clustered Arrivals | 16 | MIXED | 3-8 | 4.7 | 75 | 0-41 | 3 | 1.8× |
| `cpu_heavy.json` | CPU-Heavy Batch | 5 | CPU-BOUND | 16-25 | 20.2 | 101 | 0-5 | 8 | 20.2× |
| `interactive.json` | Interactive Session | 8 | INTERACTIVE | 1-3 | 2.1 | 17 | 0-12 | 3 | 1.4× |
| `io_bound.json` | I/O-Bound Burst | 14 | INTERACTIVE | 1-2 | 1.5 | 21 | 0-13 | 2 | 1.6× |
| `long_tail.json` | Long-Tail Load | 20 | MIXED | 1-40 | 8.6 | 172 | 0-19 | 5 | 9.1× |
| `mixed.json` | Mixed Workload | 12 | MIXED | 1-20 | 8.9 | 107 | 0-17 | 4 | 6.3× |
| `starvation.json` | Starvation Stress Test | 10 | MIXED | 2-30 | 5.6 | 56 | 0-18 | 4 | 3.1× |
| `tiny_batch.json` | Tiny Batch | 3 | MIXED | 2-8 | 5.3 | 16 | 0-2 | 2 | 8.0× |

`Load` is total burst ÷ arrival span — work arriving per tick of the arrival
window. Above 1.0 the CPU cannot keep up while arrivals continue, so the run
will visibly queue; below it, expect idle gaps. The workload picker shows all of
this on a hover card before you commit to a run.

`Profile` is a coarse three-bucket label on mean burst length, computed in
`WorkloadListModel`. It is *not* the engine's per-process `ProcessClass`
classifier (`PRD.md` §6.3), which classifies a single process from its observed
behavior mid-run.
