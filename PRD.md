# ChronOS — Adaptive CPU Scheduling Engine

**Product Requirements Document**

Author: Rohit
Draft date: August 22, 2026
Status: Draft v1 — for personal editing before build, intended to be dropped into a repo as `PRD.md` and used as project context for Claude Code

> ✎ **EDIT ME:** This whole document is yours to change. Every number (weeks, thresholds, weights) is a starting guess, not a rule. Places you'll most likely want to tweak are marked like this throughout.

---

## 1. Overview & Purpose

ChronOS is a CPU scheduling simulator you build yourself: it implements several classic operating-system scheduling algorithms (FCFS, SJF, Round Robin, Priority, and later MLFQ) plus one algorithm you design yourself — **AARS (Adaptive Aging & Response Scheduler)**. AARS watches how simulated processes actually behave (long bursts vs. short bursts, how long they've waited, how "interactive" they look) and adjusts its scheduling decisions at runtime instead of following one fixed rule.

This is explicitly a learning project, not a research paper. The goal stated up front — and the one this document is built around — is:

> **Project goal (in your own words)**
> - Build an application that performs CPU scheduling and implements a custom adaptive algorithm.
> - AARS does not need to beat the classic algorithms overall.
> - AARS only needs to perform better on some specific metric, under some specific workload — enough to show you understood the design trade-offs well enough to bend them on purpose.

Everything downstream in this document — scope, architecture, milestones — is chosen to protect that goal without letting the project balloon into something a solo beginner can't finish in the available time.

### 1.1 Who this is for

You: a beginner who has done small projects in both C++ and web dev before, but has never combined the two into something this size, and has never built a simulator or a scheduling algorithm before. This document assumes you'll be learning several new concepts as you go (structs/classes for simulation state, JSON as a data interchange format, basic charting in JS) and is written to teach, not just to specify.

### 1.2 Time budget

**4–6 weeks, solo, alongside other coursework.** This is the single most important constraint in this document — every scope decision below traces back to it.

---

## 2. Key Scope Decisions (and why)

These are the decisions that turn your original plan — which reads like a small team's semester project — into something one beginner can finish in 4–6 weeks. Each one trades some ambition for a much higher chance of actually having a working, demoable project.

### 2.1 Pure simulation, not real threads

Your original plan called for actual pthreads, mutexes, and semaphores driving real OS-level context switches. That is a legitimate and interesting feature — but it is also, on its own, close to a full project's worth of debugging (race conditions are notoriously hard to get right and even harder to demo reliably).

**Decision:** ChronOS models time as a loop over discrete integer "ticks" (think of it as simulated milliseconds). Each tick, the simulator updates process states, asks the scheduler which process should run, and advances that process's remaining burst time by one tick. No real OS threads are involved anywhere in the core engine.

This does not cost you any of the conceptual OS content — process states, PCBs, ready queues, preemption, context-switch counting, aging, priority — all of that is fully expressed in a pure simulation. It only removes the specific implementation technique of using real threads.

> ✎ **EDIT ME:** Real pthreads/mutexes are listed as an optional stretch goal in Section 6.5 if you finish early and want to add it — but it is not required for a complete project.

### 2.2 Simulate-then-replay dashboard, not a live backend

Your original plan implied a live dashboard: the C++ backend running the simulation while a frontend displays it updating in real time, which usually means standing up a local HTTP or WebSocket server and keeping backend and frontend in sync tick-by-tick. That's a whole extra subsystem (networking, serialization, connection handling) layered on top of the scheduler itself, and debugging "is the bug in my scheduler or in my socket code" is a genuinely miserable beginner experience.

**Decision:** the C++ simulator runs the entire simulation for a given workload instantly, start to finish, producing every tick and every scheduling decision in memory. The dashboard then replays it, with play, pause, step-forward, step-back, and a speed slider. This part of the decision still holds exactly as written — **what changed (2026-08-23 pivot, see edit-note below) is the dashboard itself**: it is now a native Qt/QML desktop app that links the simulator in-process (no JSON round-trip for interactive use, no server, still nothing to keep alive during a demo), not a web page loading a JSON file. The original "no live backend" reasoning is exactly why this was safe to do — there was never a network/socket boundary to begin with, just a file boundary, and swapping a file-read for an in-process function call doesn't reintroduce the live-backend complexity this section was written to avoid. The CLI still writes the JSON file described below, for `analysis.py`.

> **Logged deviation (2026-08-23):** the "web dashboard" throughout this document (originally: static HTML/CSS/JS, opened in a browser, loading a JSON file) was replaced with a native Qt 6 / QML desktop application per explicit user request — a polished animated executable was wanted, not something opened in a browser. See `CLAUDE.md`'s "Architecture pivot" note and `ARCHITECTURE.md` §5 for the current GUI architecture. Every other reference to "the dashboard" in this document below should be read as "the native GUI" — the panel *contents* (Gantt chart, ready queue, why-panel, aging indicator, playback controls) are unchanged from the original spec, plus one new panel (per-process progress ticker, `EDRD.md` §5.8) that wasn't in the original spec.

This still looks and feels completely "live" to anyone watching your demo — arguably it looks better, because you can pause on the exact interesting moment (an aging boost, a preemption) and explain it. And re-running a different workload is just: pick it from the in-app list and press RUN — no separate terminal step at all now, an improvement over the original file-refresh flow.

> **Why this is the right trade for you specifically**
> - You've done small C++ and small web projects, but never networking/sockets. This removes the one subsystem neither of your existing skills covers.
> - It also happens to be more robust for a live demo in front of a professor — nothing to crash if the projector Wi-Fi is flaky.

### 2.3 MLFQ moved out of the MVP milestone

Multilevel Feedback Queue is the most complex of the "classic" algorithms — it needs multiple queues, rules for demoting a process to a lower-priority queue when it uses its whole quantum, rules for promoting it back up (aging, or a full priority-boost reset), and a different quantum per queue. Implemented well, it is roughly as much work as FCFS + SJF + Round Robin + Priority combined.

**Decision:** MLFQ is not part of the true MVP. The MVP milestone ships FCFS, SJF, Round Robin, Priority, and AARS — five algorithms — working end-to-end through the full pipeline (simulate → JSON → dashboard → comparison table). MLFQ is added in Milestone 3, once that pipeline is proven and there is nothing left to debug except the algorithm itself.

This means your first "it works" moment happens roughly a week earlier than it would if MLFQ were required up front, which matters a lot for morale and for de-risking the rest of the timeline.

### 2.4 AARS: honest results over guaranteed wins

You explicitly said AARS doesn't need to be better overall — it needs to help you understand the design trade-offs, and ideally win on at least one metric under at least one workload. That is exactly the standard this document holds AARS to. You are not going to pre-decide what AARS's numbers will be and then tune the formula until reality matches; you are going to implement the formula honestly, run the experiments, and report whatever comes out — including places where AARS loses, and an explanation of why (e.g. "AARS has more context switches than FCFS because it's actively trying to be responsive, which is the trade-off it's designed to make").

This is, incidentally, also what makes a stronger project: professors have seen a hundred projects that claim "my algorithm is better at everything" and privately don't believe any of them. A project that says "my algorithm loses on X because of Y, but wins on Z because of W" reads as more rigorous, not less.

---

## 3. Goals and Non-Goals

### 3.1 Goals

1. Implement a discrete-event CPU scheduling simulator in C++ modeling PCBs, process states, ready/waiting queues, and context switching.
2. Implement five classic scheduling algorithms correctly and verifiably: FCFS, SJF (non-preemptive), Round Robin, Priority (with aging), and — once the pipeline is proven — MLFQ.
3. Design and implement your own adaptive algorithm, AARS, with a documented scoring formula, and be able to explain every term in it.
4. Produce a JSON execution log (Gantt-chart data + per-tick scheduler decisions + reasons) for any run.
5. Build a native desktop GUI (originally planned as a web dashboard — see §2.2's logged deviation) that replays that data: CPU timeline / Gantt chart, ready queue table, a live "why did the scheduler pick this process" explanation panel, summary stats, and a per-process progress ticker.
6. Run the same workload through all algorithms and produce a comparison table + at least 3 charts (avg waiting time, avg turnaround time, avg response time, at minimum) using Python + Matplotlib.
7. Provide at least 3 predefined workload presets (e.g. CPU-heavy, interactive/I-O heavy, starvation stress test) that produce visibly different scheduler behavior.
8. Be able to explain, in a viva/demo setting, every OS concept the project touches: process states, PCB, ready queue, preemption, time quantum, context switching, aging/starvation, priority inversion avoidance.

### 3.2 Non-goals (explicitly out of scope for this project)

Cutting these isn't a failure — they're the difference between a semester-long team capstone and a solo 4–6 week course project. Naming them explicitly means you never accidentally scope-creep back into them, and it gives you a ready-made "Future Work" slide.

- Real OS-level threads/pthreads/mutexes/semaphores driving the core scheduler (optional stretch goal only, Section 6.5).
- A live streaming backend (WebSocket/HTTP server driving the frontend in real time).
- Machine-learning-based workload classification (rule-based thresholds are sufficient and are what the plan itself recommends).
- Multi-core or NUMA-aware scheduling.
- Benchmark runs at 5,000–10,000 processes as a required feature (nice stretch goal, not required — Section 6.5).
- Real Linux scheduler integration / kernel-level anything.
- Persistent database, user accounts, multi-user anything — this is a single-user local tool.
- Mobile/responsive layout, cross-browser anything (the GUI is a native desktop app, not a web page — see §2.2's logged deviation) — target laptop screens only.

---

## 4. System Architecture

Three independent pieces that talk to each other only through files. This is deliberate: each piece can be built, tested, and debugged in isolation, and a bug in one can't silently corrupt another through some shared live connection.

### 4.1 High-level flow

> **Pipeline**
> 1. You pick a workload (predefined preset or custom process list) via a config file or a simple CLI prompt.
> 2. The C++ simulator engine runs the full simulation for the chosen algorithm, tick by tick, in memory.
> 3. The simulator writes one result JSON file: full Gantt data, every process's final stats (waiting/turnaround/response time), and a per-decision log (what the scheduler chose and why).
> 4. The native GUI (Qt/QML desktop app — see §2.2's logged deviation) links the simulator in-process and renders the replay: timeline, ready queue, explanation panel, stats, process ticker. (The CLI binary still writes a JSON result file too, for step 5/`analysis.py`.)
> 5. For comparisons, a small runner script executes all algorithms against the same workload back-to-back and writes one combined results file; `analysis.py` reads it and produces the comparison table + charts.

### 4.2 Folder structure

Simplified from your original plan, but the same spirit:

**Updated 2026-08-23** — reflects the architecture pivot (§2.2): `dashboard/` was replaced with `app/` (native Qt/QML GUI), and `engine/` gained `chronos_core` library-split files shared by the CLI and the GUI.

```
ChronOS/
├── engine/                  (C++ core)
│   ├── process.h/.cpp        Process struct + state enum
│   ├── behavior_analyzer.h/.cpp   burst/I-O classification
│   ├── workload_io.h/.cpp    loadWorkload() — shared by CLI + GUI
│   ├── scheduler_factory.h/.cpp  makeScheduler()/algorithmDisplayName() — shared
│   ├── schedulers/
│   │   ├── fcfs.cpp
│   │   ├── sjf.cpp
│   │   ├── round_robin.cpp
│   │   ├── priority.cpp
│   │   ├── mlfq.cpp          (Milestone 3)
│   │   └── aars.cpp          your algorithm
│   ├── simulator.h/.cpp      the tick loop + JSON writer
│   └── main.cpp              CLI entry point (not part of chronos_core)
├── app/                      (native Qt6/QML GUI — replaces dashboard/)
│   ├── ChronosBridge.h/.cpp   in-process engine link + per-tick derived data
│   ├── WorkloadListModel.h/.cpp  in-app workload file browser
│   ├── main.cpp
│   ├── fonts/                 bundled JetBrains Mono + Instrument Serif + OFL licenses
│   └── qml/                   Theme.qml, Splash.qml, AlgorithmPicker.qml, WorkloadPicker.qml,
│                               Dashboard.qml + panel components (ARCHITECTURE.md §5.1 has the full list)
├── analysis/
│   └── analysis.py           comparison table + Matplotlib charts
├── workloads/
│   ├── tiny_batch.json
│   ├── cpu_heavy.json
│   ├── interactive.json
│   ├── starvation.json
│   ├── mixed.json
│   ├── io_bound.json
│   ├── burst_arrivals.json
│   └── long_tail.json
├── results/                  generated JSON output lands here (gitignored) — CLI only
├── README.md
└── CMakeLists.txt
```

### 4.3 Tech stack (updated 2026-08-23)

| Layer | Technology | Why |
|---|---|---|
| Simulation engine | C++17, standard library only | No external C++ deps to install/debug. STL containers (vector, queue, priority_queue) cover everything you need. |
| Build system | CMake | Same as your original plan — standard for C++, worth learning. |
| JSON output | nlohmann/json (single header) | Avoids hand-writing JSON serialization by string concatenation, which is a common source of silent bugs. Still used by the CLI path. |
| GUI | Qt 6 / QML (Qt Quick), native desktop app | **Changed from the original plain-HTML/CSS/JS plan** — explicit user request for a polished native executable instead of a browser page. See §2.2's logged deviation. |
| Charting (GUI) | Custom QML (Gantt/score-bar), no charting library | Same reasoning as the original Chart.js-was-never-needed finding — still holds natively. |
| Analysis | Python 3 + Matplotlib + pandas | As in your original plan — good for static comparison charts across algorithms. |
| Version control | Git + GitHub | As in your original plan. |

Dropped from your original list: a live socket/API layer, and any requirement for a separate frontend build pipeline. The GUI toolkit itself changed post-MVP (see above); everything else you listed is kept.

---

## 5. Data Model

### 5.1 Process struct

Slightly expanded from your draft to support behavior tracking, which AARS needs:

```cpp
struct Process {
    int pid;
    int arrivalTime;
    int burstTime;          // total CPU time needed
    int remainingTime;
    int basePriority;       // 1 (low) .. 10 (high), your convention
    int waitingTime = 0;
    int turnaroundTime = 0;
    int responseTime = -1;  // -1 until first scheduled
    int startTime = -1;
    int completionTime = -1;
    int contextSwitches = 0;

    // behavior tracking (used by AARS + behavior analyzer)
    std::vector<int> burstHistory;   // completed burst lengths so far
    int ioEvents = 0;                // count of times it voluntarily gave up CPU early
    ProcessClass predictedClass = ProcessClass::UNKNOWN; // CPU_BOUND / IO_BOUND / INTERACTIVE / BALANCED
};

enum class State { NEW, READY, RUNNING, WAITING, TERMINATED };
enum class ProcessClass { UNKNOWN, CPU_BOUND, IO_BOUND, INTERACTIVE, BALANCED };
```

> ✎ **Revised 2026-08-24 (issue #3):** `BALANCED` was added as a fifth value — it means "has run, but didn't clear either the CPU-bound or short-burst tests." Before it existed, that case fell through to `UNKNOWN`, which made "no opinion yet" and "ran and was unremarkable" the same word. `UNKNOWN` now means exactly one thing: **has not run yet.** The GUI relabels it `PENDING` for that reason. See §6.3 for the full classification rule as implemented.

### 5.2 Workload input format (JSON)

Each workload preset is just a JSON array — easy to hand-author, easy to generate programmatically for the starvation test:

```json
{
  "name": "Interactive Workload",
  "quantum": 4,
  "processes": [
    { "pid": 1, "arrivalTime": 0, "burstTime": 2, "priority": 5 },
    { "pid": 2, "arrivalTime": 1, "burstTime": 3, "priority": 5 },
    { "pid": 3, "arrivalTime": 2, "burstTime": 1, "priority": 5 }
  ]
}
```

### 5.3 Result output format (JSON) — the dashboard's only input

```json
{
  "algorithm": "AARS",
  "workloadName": "Interactive Workload",
  "gantt": [
    { "pid": 2, "start": 0, "end": 4, "reason": "Highest score: interactive burst detected" }
  ],
  "decisionLog": [
    { "tick": 0, "chosen": 2, "candidates": [
        { "pid": 1, "score": 8.4, "priority": 5, "burstRemaining": 6, "class": "UNKNOWN" },
        { "pid": 2, "score": 12.1, "priority": 7, "burstRemaining": 3, "class": "INTERACTIVE" }
      ], "reasonTags": ["short_burst", "aging_bonus:0"] }
  ],
  "processStats": [
    { "pid": 1, "arrivalTime": 0, "burstTime": 8, "waitingTime": 6, "turnaroundTime": 9,
      "responseTime": 3, "completionTime": 11, "contextSwitches": 2, "class": "CPU_BOUND" }
  ],
  "summary": {
    "avgWaitingTime": 5.2, "avgTurnaroundTime": 8.1, "avgResponseTime": 3.0,
    "contextSwitches": 7, "cpuUtilization": 0.94, "throughput": 0.36
  }
}
```

This one format is the entire contract between the C++ engine and the dashboard/analysis layer. Get this right early and the rest of the project decouples cleanly — you can work on the dashboard with a hand-written fake JSON file before the engine even runs, and vice versa.

> ✎ **Integration-time addition (Milestone 1):** each `decisionLog[].candidates[]` entry also carries `priority` (the process's `basePriority`), `burstRemaining` (its `remainingTime` at that tick), and `class` (its `predictedClass` as a string) — the original two-field `{pid, score}` shape had nowhere for the dashboard's ready-queue table (EDRD.md §5.3, PRIORITY/BURST/CLASS columns) to source those from, since the JSON has no other per-tick process snapshot. Every scheduler populates all three fields, not just AARS. For AARS specifically, `reasonTags` always includes all five PRD §6.1 formula terms as `"name:±value"` (`base_priority`, `aging_bonus`, `io_bonus`, `response_bonus`, `cpu_burst_penalty`), even when a term is 0 — the why-panel's score-breakdown bar (EDRD §7.1) renders a fixed 5-segment bar and needs every term present on every decision, not only the ones currently contributing.
>
> ✎ **Widened 2026-08-24:** `processStats[]` gained four fields, additively — `arrivalTime`, `burstTime`, `contextSwitches`, `class` (the process's final `predictedClass` as a string, §6.3). The native GUI's process HUD (EDRD.md §5.10) needs to describe a finished process on hover without re-reading the workload file alongside the result, and these are exactly the fields `ChronosBridge` (the GUI's engine binding — see ARCHITECTURE.md §5.1) can't otherwise reconstruct from `waitingTime`/`turnaroundTime`/`responseTime`/`completionTime` alone. `analysis.py` (issue #1) should read these fields rather than recompute them from the workload.

---

## 6. Your Algorithm: AARS (Adaptive Aging & Response Scheduler)

### 6.1 Scoring formula

> **Score(process, currentTick) =**
> Base Priority
> \+ Aging Bonus(waitingTime)
> \+ I/O Bonus(predictedClass)
> \+ Response Bonus(isInteractive)
> − CPU Burst Penalty(avgBurstLength)

The highest-scoring READY process is scheduled next. Ties broken by lowest PID (deterministic, easy to test).

### 6.2 Term-by-term definitions (starting values — tune these)

| Term | Formula (starting point) | Intuition |
|---|---|---|
| Aging Bonus | `min(waitingTime / 2, 10)` | Grows the longer a process waits, capped so it can't dominate forever. This alone prevents starvation. |
| I/O Bonus | `+4` if `predictedClass == IO_BOUND`; `+2` if `INTERACTIVE`; `+0` if `CPU_BOUND`/`UNKNOWN` | Rewards processes that historically give the CPU back quickly. |
| Response Bonus | `+3` if `responseTime == -1` (never run yet) | Gives a one-time boost to brand-new processes so response time stays low — this is what "interactive feel" usually means in scheduling. |
| CPU Burst Penalty | `min(avgBurstHistory / 5, 8)` | The longer a process's recent bursts have been, the more it's penalized — this is what pushes CPU-bound processes down. |

> ✎ **EDIT ME:** These weights (÷2, cap 10, +4, +3, ÷5, cap 8) are placeholders sized to be roughly the same magnitude as your 1–10 base priority, so no single term totally dominates. You will very likely need to adjust them once you see real numbers — that tuning process is itself a legitimate part of your "research contribution" and worth writing up ("I started with X, observed Y, changed to Z because...").

### 6.3 Behavior classification (rule-based, no ML needed)

After each burst completes, append it to that process's `burstHistory` (keep last 5). Recompute, per process, on every dispatch and at completion (not only when a burst finishes — see the "revised" note below for why):

- `consumed = burstTime - remainingTime` — CPU already held so far, including mid-burst.
- `avgBurst = mean(burstHistory)` if any bursts have completed, else `consumed`.
- `cpuEvidence = max(avgBurst, consumed)` — the strongest signal available, whether or not the current burst has finished.
- `CPU_BOUND` if `cpuEvidence > 15` ticks.
- Else, if no burst has completed yet: `UNKNOWN` (still mid-first-burst, not yet long enough to call CPU-bound, and too early to trust the short-burst tests below).
- Else if `avgBurst < 4` ticks AND `ioEvents > 0`: `IO_BOUND`.
- Else if `avgBurst < 4` ticks AND `responseTime` was low (`<= kLowResponseTicks`, currently 2): `INTERACTIVE`.
- Else: `BALANCED` — ran, completed at least one burst, but didn't clear either the CPU-bound or short-burst tests.

`UNKNOWN` means exactly one thing: **has not run yet** (`burstHistory` empty and `consumed <= 0`). The GUI relabels it `PENDING`. `IO_BOUND` is currently unreachable in practice — nothing in the engine increments `ioEvents` (no I/O model yet, §2.1) — and that's expected, not a bug; don't loosen the condition to make the label appear.

> ✎ **Revised 2026-08-24 (issue #3 — "mostly UNKNOWN on both Milestone-1 presets"):** the original rule (above, superseded) required **two completed bursts** before committing to any label. Under the three non-preemptive algorithms a process runs exactly once and terminates, so it never accumulated a second burst, and nearly every row in the UI read `UNKNOWN` for the entire run — the classifier was effectively dead outside RR/AARS. Two changes fixed it: one completed burst is now enough, and CPU consumed *so far* (mid-burst) counts as CPU-bound evidence, so the label is useful exactly when it matters most — while a long process is still running — rather than only after it finishes. The thresholds themselves (15 ticks, 4 ticks, window of 5, `kLowResponseTicks = 2`) are unchanged from the original guesses; they live as named constants in `engine/behavior_analyzer.cpp` and remain retunable, but any change is a logged decision, not silent drift.

### 6.4 Dynamic time quantum (used only when AARS preempts on a quantum boundary, similar to Round Robin)

| Classification | Quantum |
|---|---|
| CPU-bound | 8 ticks |
| Unknown / moderate | 5 ticks |
| Interactive | 3 ticks |
| I/O-bound | 2 ticks |

### 6.5 Optional stretch goals (only if MVP + Milestone 2/3 finish with time to spare)

- **Real pthreads:** reimplement the simulator's tick loop using actual threads + mutexes for the ready queue, purely as a "look, I can also do it the hard way" bonus section — keep the JSON-producing simulation as the primary/graded path so a threading bug can't take down your whole demo.
- **Large-scale benchmark mode:** run 1,000–5,000 synthetic processes and report how each algorithm's runtime and metrics scale, as a short appendix rather than a core feature.
- **A simple fairness index** (e.g. Jain's fairness index over CPU-time-received vs. CPU-time-needed) — cheap to add once you already have per-process stats, and it strengthens the comparison section.

---

## 7. Dashboard Specification

**Updated 2026-08-23:** this was originally written as a static HTML page; it's now a native Qt/QML desktop app (`app/`, see §2.2's logged deviation and `ARCHITECTURE.md` §5). The panels below are unchanged in content/intent — every panel is still driven by a single `currentTick` value that a play/pause/step control advances, it's just a QML property (`Dashboard.qml`) instead of a JS variable in `app.js`, and the source data is an in-memory `SimulationResult` (via `ChronosBridge`) instead of a loaded JSON file. One panel not listed below was added post-pivot: a per-process progress ticker — see `EDRD.md` §5.8.

### 7.1 Top bar

- Title: "ChronOS — Adaptive CPU Scheduling Engine"
- Algorithm name + workload name (from the loaded JSON)
- Three stat tiles: CPU Utilization %, Total Processes, Context Switches (computed live up to `currentTick`)

### 7.2 CPU timeline / Gantt chart

- Horizontal bar showing which PID ran during which tick range, colored per-process, built from the `gantt` array
- A vertical playhead marker showing `currentTick`

### 7.3 Ready queue table

- Columns: PID, Priority, Burst remaining, Waiting time, Score (AARS runs only), Classification
- Sorted by score/priority descending, so the top row is always "who'd get picked next"

### 7.4 "Why this process?" explanation panel

This is the single highest-value feature for a demo — it turns AARS from a black box into something a viewer can follow. Pull straight from the `reasonTags` and `candidates` fields already in your JSON:

> **Example panel content**
> WHY P2?
> ✓ Highest adaptive score (12.1 vs next-best 8.4)
> ✓ Waiting time: 8 ticks → aging bonus +4
> ✓ Classified INTERACTIVE → response bonus +3
> ✓ Dynamic quantum: 3 ticks

### 7.5 Waiting/aging indicator

- Small list of any READY processes whose waiting time crossed a visible aging threshold, e.g. "P6 waiting 21 ticks → aging bonus +7"

### 7.6 Playback controls

- Play / Pause, Step forward, Step back, speed slider (ticks per second), a scrub bar / slider to jump to any tick directly

### 7.7 Workload + algorithm picker (MVP requirement from your own spec)

**Superseded by the pivot (2026-08-23):** this section originally described a form + a manual "run the binary yourself, then reload the page" flow, with a Milestone-4 stretch goal of adding a local server so a "Run" button could invoke the binary directly. That entire stretch goal is now simply how the app works by default: `app/qml/AlgorithmPicker.qml` and `WorkloadPicker.qml` are full-screen picker steps (not a form at the top of the dashboard), workload choice is an in-app file browser (never a native OS file dialog), and RUN calls `ChronosBridge::runSelectedSimulation()` in-process — no server, no manual file reload, no terminal step at all. See `ARCHITECTURE.md` §5.4.

---

## 8. Metrics & Comparison

### 8.1 Per-run metrics (every algorithm reports these)

| Metric | Formula |
|---|---|
| Waiting time | `turnaroundTime − burstTime` |
| Turnaround time | `completionTime − arrivalTime` |
| Response time | `startTime − arrivalTime` (first time scheduled) |
| CPU utilization | `(total ticks CPU was busy) / (total simulation ticks)` |
| Context switches | count of process changes on the CPU |
| Throughput | `processes completed / total simulation ticks` |

### 8.2 Comparison outputs (`analysis.py`)

- One markdown/CSV table: algorithm × metric, for a chosen workload
- Bar chart: avg waiting time by algorithm
- Bar chart: avg response time by algorithm
- Bar chart: context switches by algorithm
- Grouped bar chart: all algorithms across all 3–4 workload presets (this is the chart that actually proves "adaptive behavior changes with workload," which is your core claim)

Everything under Section 8 should be generated from data, not written by hand — hardcoding example numbers (as your original plan's illustrative table did) is fine for this PRD, but your actual submitted report must only contain numbers your own code produced.

---

## 9. Milestones & Timeline (4–6 weeks)

Each milestone ends with something you can actually run and show — not just code that compiles. If week 6 has to be cut for any reason, milestones 1–2 alone are still a complete, presentable project.

### Milestone 0 — Setup (2–3 days)

- Install toolchain: g++, cmake, python3, matplotlib/pandas, git.
- Scaffold folder structure (Section 4.2), init git repo, first commit.
- Write the Process struct and State enum (Section 5.1). No scheduling logic yet.
- Hand-write one fake `results.json` (Section 5.3) and get the dashboard skeleton (Section 7) rendering it — proves the JSON contract and the dashboard shell both work before any real algorithm exists.

### Milestone 1 — MVP (target: end of week 3)

**Definition of done:** you can pick an algorithm and a workload, run the simulator, and see a correct, readable visualization with real TAT/waiting/response numbers.

1. Simulator core: the tick loop, ready queue, process state transitions, JSON writer (Section 4.1, 4.3).
2. FCFS implemented and verified by hand against a worked example (use the P1/P2/P3 example from your own notes as a unit test).
3. SJF (non-preemptive) implemented and verified the same way.
4. Round Robin implemented with configurable quantum, context-switch counting verified.
5. Priority scheduling implemented, with basic aging (fixed +1 per N ticks waited, not yet the full AARS formula).
6. AARS v1: the scoring formula (Section 6) implemented and producing per-tick decision logs with reasons.
7. Dashboard fully functional against real (not fake) JSON: timeline, ready queue table, why-panel, playback controls, algorithm/workload picker.
8. At least 2 workload presets (e.g. CPU-heavy, interactive) exist and produce visibly different Gantt charts.

### Milestone 2 — Comparison & polish (target: end of week 4)

1. `analysis.py`: reads multiple result JSONs, builds the comparison table, generates the 4 charts from Section 8.2.
2. Remaining workload presets: mixed, starvation stress test.
3. Tune AARS weights (Section 6.2) against real data from your presets; write down what you changed and why — this becomes your "research contribution" narrative.
4. Basic logging (Section 11) if not already done as part of the decision log.

### Milestone 3 — MLFQ + depth (target: end of week 5, if time allows)

1. Implement MLFQ: at minimum 3 queues, demotion on quantum exhaustion, promotion via periodic full priority-boost (simplest correct version — don't over-engineer the promotion rule).
2. Add MLFQ to the comparison table and charts.
3. Preemption support in AARS if not already present in v1 (a new arrival with a much higher score can preempt the running process — track it as a context switch).

### Milestone 4 — Stretch goals + presentation prep (week 6, optional)

1. Pick at most one item from Section 6.5 (real threads, large-scale benchmark, or fairness index) — not all three.
2. Edge-case tests from Section 10.
3. Build the presentation deck (Section 12).
4. Full run-through demo, timed, at least once before the real presentation.

> ✎ **EDIT ME:** If you're closer to 4 weeks than 6, the safe cut order is: Milestone 4 entirely, then push MLFQ (Milestone 3) to "future work" rather than implementing it rushed. A polished 5-algorithm comparison beats a buggy 6-algorithm one.

---

## 10. Testing & Edge Cases

Before considering any milestone "done," run these against every implemented algorithm. Keep expected outputs for the simple ones (Test 1–3) written down so you can catch regressions.

| # | Case | What it catches |
|---|---|---|
| 1 | Single process only | Off-by-one errors in completion/turnaround time |
| 2 | All processes arrive at tick 0 | Ready-queue ordering logic with no arrival-time tie-breaking bugs |
| 3 | Staggered arrival times | Correct handling of NEW → READY transitions mid-simulation |
| 4 | One very long burst among short ones | Whether short jobs get starved behind it (esp. FCFS vs AARS contrast) |
| 5 | All very short bursts | Context-switch overhead counting |
| 6 | Starvation stress preset (1 low-priority + many high) | Aging actually kicks in and the low-priority process eventually completes |
| 7 | Identical priorities across all processes | Tie-breaking rule is deterministic, doesn't crash or loop |
| 8 | Identical burst times | SJF tie-breaking |
| 9 | Larger process count (200–500) | Performance sanity check without needing full 5,000-process benchmark mode |
| 10 | Empty/no processes at simulation start (all arrive later) | Idle-CPU handling, utilization % doesn't divide by zero |

---

## 11. Logging

You already need a decision log for the "why this process?" dashboard panel (Section 5.3) — this section just says: reuse it as your debug/demo log too instead of building a second logging mechanism.

- Every scheduling decision appends one entry with: tick, chosen PID, all candidate scores, and the winning reason tags.
- Write this to `logs/scheduler.log` as human-readable text AND embed the structured version in the result JSON's `decisionLog` array — one source of truth, two views.
- This single log is what you'll screen-share/quote from during your viva when asked "why did it do that at tick 14?"

---

## 12. Presentation Outline

Your original 10-slide structure is solid and needs no real changes — keeping it here so this document is self-contained:

1. **Problem** — traditional scheduling algorithms are static.
2. **Existing algorithms** — FCFS, SJF, RR, Priority, (MLFQ if built).
3. **Your solution** — ChronOS / AARS, one sentence each.
4. **Architecture** — Process → Behavior Analyzer → Adaptive Scheduler → CPU (Section 4.1 diagram).
5. **Algorithm** — the scoring formula (Section 6.1), explain each term in plain language.
6. **Live demonstration** — run 2 contrasting workloads through the dashboard.
7. **Comparison** — table + charts (Section 8).
8. **Results** — be specific about where AARS wins and where it doesn't, and why.
9. **Limitations** — be honest: pure simulation not real threads, rule-based not ML classification, tuned weights not formally optimized.
10. **Future work** — Section 6.5 stretch goals + real Linux integration + ML classification, as ideas rather than promises.

---

## 13. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Underestimating MLFQ complexity | Already deferred to Milestone 3 (Section 2.3); safe to cut entirely if week 5 arrives and it isn't started. |
| AARS formula never separates classes cleanly on your synthetic data | Section 6.3 thresholds are explicitly marked as starting guesses — budget real time in Milestone 2 to look at actual burst distributions and retune. |
| Getting stuck on C++/JSON plumbing | nlohmann/json (single header, well documented) instead of hand-rolled serialization; the fake-JSON-first approach in Milestone 0 decouples dashboard work from engine bugs. |
| Running out of time before a full 6 algorithms | Milestones are ordered so that stopping after Milestone 2 still yields a complete, presentable 5-algorithm project. |
| Dashboard becoming a bigger time sink than the scheduler itself | Was: no framework, no build step, Chart.js via script tag. Now (post-pivot, §2.2): `chronos_core` being a shared library means GUI work never risks the scheduler logic itself — a GUI bug can't corrupt engine correctness, and the engine's own CLI regression-tested independently of any GUI changes. |
| Losing track of what to say in the viva | The decision log (Section 11) is designed to be your answer key — you can point at real logged numbers instead of guessing. |

---

## 14. Open Questions for You

A few things only you can decide as you go — revisit these once Milestone 1 is running and you have real numbers in front of you:

- Do the AARS weight thresholds in Section 6.2/6.3 actually separate your workloads well, or do they need retuning?
- Is 4–6 weeks still realistic once Milestone 0/1 actual time-spent is known — worth a quick re-check at the end of week 2?
- Which single Section 6.5 stretch goal (if any) is most worth your remaining time, given what impressed you most once the MVP is running?
