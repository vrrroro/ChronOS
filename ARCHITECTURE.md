# ChronOS — Architecture

System design reference. Covers component responsibilities, module boundaries, data flow, and interaction contracts. For *why* these decisions were made, see `PRD.md` §2 and §4. For dashboard visuals, see `EDRD.md`. For build rules, see `CLAUDE.md`.

---

## 1. System overview

ChronOS is three independent subsystems connected only by files on disk — no subsystem calls another subsystem's code or holds a live connection to it.

```
┌──────────────────┐      results/*.json      ┌───────────────────┐
│   C++ Engine      │ ────────────────────────▶│  Web Dashboard      │
│  (simulation)     │                           │  (static HTML/JS)  │
└──────────────────┘                           └───────────────────┘
         │
         │ results/*.json (multiple runs)
         ▼
┌──────────────────┐
│  analysis.py      │────▶ comparison table (CSV/MD) + PNG charts
│  (Python)         │
└──────────────────┘
```

Why file-boundary, not live connection: see `PRD.md` §2.2. The practical consequence for implementation is that **the JSON schema (Section 4 below) is the only contract between subsystems** — as long as the engine writes valid JSON matching that schema, and the dashboard/analysis only read that schema, the three pieces can be built, run, and debugged completely independently.

---

## 2. Component map

| Component | Language | Responsibility | Does NOT do |
|---|---|---|---|
| `engine/` | C++17 | Run one simulation (one algorithm, one workload) tick-by-tick; produce one result JSON | Render anything; know about the dashboard; compare algorithms |
| `dashboard/` | HTML/CSS/JS | Load one result JSON; replay it visually with playback controls | Run simulations; talk to the engine process; write files |
| `analysis/` | Python | Load multiple result JSONs; compute comparison tables and charts | Run simulations; render live UI |
| `workloads/` | JSON (data) | Define process sets for the engine to consume | — |
| `results/` | JSON (generated) | Engine output, dashboard/analysis input | Never hand-edited, never committed with real data (gitignored) |
| `logs/` | text (generated) | Human-readable scheduler decision trace | Never hand-edited |

Each component is independently testable: the dashboard can be developed against a hand-written fake `results.json` before the engine exists (PRD Milestone 0); `analysis.py` can be developed against sample result files the same way.

---

## 3. Engine internals (`engine/`)

### 3.1 Module breakdown

```
engine/
├── process.h/.cpp            Process struct, State enum, ProcessClass enum
├── behavior_analyzer.h/.cpp   burst-history tracking + classification rules
├── schedulers/
│   ├── scheduler_base.h       common interface all schedulers implement
│   ├── fcfs.cpp
│   ├── sjf.cpp
│   ├── round_robin.cpp
│   ├── priority.cpp
│   ├── mlfq.cpp               (Milestone 3)
│   └── aars.cpp
├── simulator.h/.cpp           the tick loop, ready/waiting queues, JSON writer
└── main.cpp                   CLI entry point, argument parsing
```

### 3.2 Scheduler interface (the internal contract every algorithm implements)

Every scheduler — FCFS through AARS — implements the same shape, so `simulator.cpp` never needs to know which algorithm is active:

```cpp
class Scheduler {
public:
    virtual ~Scheduler() = default;

    // Called once per tick. Given the current ready queue and tick number,
    // return the PID to run next (or -1 if nothing is ready).
    virtual int selectNext(std::vector<Process>& readyQueue, int currentTick) = 0;

    // Called once per tick after selectNext, for schedulers with a
    // time-quantum concept (RR, MLFQ, AARS). Return ticks remaining
    // in the current process's slice, or -1 if not quantum-based.
    virtual int currentQuantum(const Process& running) const { return -1; }

    // For logging/dashboard: explain the selectNext decision just made.
    virtual DecisionLog explainLastDecision() const = 0;

    virtual std::string name() const = 0;
};
```

Rationale: `simulator.cpp` (Section 3.3) is written once, against this interface. Adding MLFQ later, or retuning AARS, never touches the simulator core — only the scheduler's own `.cpp` file. This is what makes the Milestone 1 → 3 split in the PRD safe: the simulator loop doesn't change when a new scheduler is added, so proving it correct once (against FCFS, the simplest case) proves the loop itself is trustworthy for every algorithm after.

### 3.3 The tick loop (`simulator.cpp`)

This is the heart of the engine — one function, run once per simulation:

```
function runSimulation(workload, scheduler):
    tick = 0
    readyQueue = []
    waitingQueue = []      # processes doing I/O (if modeled)
    newQueue = sorted(workload.processes by arrivalTime)
    completed = []
    ganttLog = []
    decisionLog = []
    runningProcess = null
    quantumRemaining = 0

    while completed.size < workload.processes.size:
        # 1. Admit newly-arrived processes
        move all processes from newQueue with arrivalTime == tick into readyQueue
        set their state = READY

        # 2. Update waiting stats for everyone still in readyQueue
        for p in readyQueue: p.waitingTime += 1

        # 3. Ask the behavior analyzer to (re)classify anyone whose burst history changed
        behaviorAnalyzer.updateClassifications(readyQueue)

        # 4. Scheduling decision
        if runningProcess == null or quantumRemaining == 0 or scheduler.shouldPreempt(...):
            nextPid = scheduler.selectNext(readyQueue, tick)
            if nextPid != runningProcess.pid:
                record context switch
                if runningProcess != null: push runningProcess back to readyQueue (state = READY)
                runningProcess = remove nextPid from readyQueue
                runningProcess.state = RUNNING
                if runningProcess.responseTime == -1: runningProcess.responseTime = tick - runningProcess.arrivalTime
            quantumRemaining = scheduler.currentQuantum(runningProcess)
            decisionLog.append(scheduler.explainLastDecision())

        # 5. Execute one tick
        if runningProcess != null:
            extend or append ganttLog segment for runningProcess at this tick
            runningProcess.remainingTime -= 1
            quantumRemaining -= 1

            # 6. Check completion
            if runningProcess.remainingTime == 0:
                runningProcess.completionTime = tick + 1
                runningProcess.turnaroundTime = runningProcess.completionTime - runningProcess.arrivalTime
                runningProcess.state = TERMINATED
                completed.append(runningProcess)
                behaviorAnalyzer.recordCompletedBurst(runningProcess)
                runningProcess = null

        tick += 1

    return buildResultJson(ganttLog, decisionLog, completed, summaryStats)
```

Key invariants this loop must preserve (verify these first when debugging any scheduler):

- A process's `waitingTime` only increments while it sits in `readyQueue`, never while `RUNNING` or `TERMINATED`.
- `responseTime` is set exactly once, the first time a process is ever scheduled.
- Every tick the CPU is busy produces exactly one Gantt entry (or extends the previous one if it's the same PID — don't emit one JSON object per tick, coalesce consecutive same-PID ticks into a single `{start, end}` range).
- A context switch is counted only when the running PID actually changes, not on every scheduling decision (re-selecting the same process that's already running is not a switch).

### 3.4 Behavior analyzer (`behavior_analyzer.h/.cpp`)

Stateless with respect to the simulator loop — it only reads/writes fields already on the `Process` struct (`burstHistory`, `ioEvents`, `predictedClass`). Two entry points:

- `recordCompletedBurst(Process&)` — called when a process finishes a burst (either completes entirely or is preempted); appends the burst length to `burstHistory` (capped at last 5, per PRD §6.3).
- `updateClassifications(vector<Process>&)` — called once per tick before scheduling; recomputes `predictedClass` for any process whose `burstHistory` changed since last check, using the threshold rules in `PRD.md` §6.3.

Only `aars.cpp` reads `predictedClass` and `avgBurstHistory` — FCFS/SJF/RR/Priority ignore behavior analysis entirely, so the analyzer can be developed and unit-tested independently of any scheduler.

### 3.5 AARS-specific internals (`aars.cpp`)

`AARSScheduler::selectNext` computes `Score(p, tick)` for every process in `readyQueue` per the formula in `PRD.md` §6.1, using the analyzer's `predictedClass`/`avgBurstHistory` and the process's own `waitingTime`/`responseTime` fields — no additional state beyond what's already on `Process`. `currentQuantum` looks up the table in `PRD.md` §6.4 keyed on `predictedClass`. `explainLastDecision` must return every candidate's score and the winning process's reason tags (see Section 4.3 below) — this is not optional instrumentation, it's required by the JSON schema and by the dashboard's why-panel.

### 3.6 JSON I/O

- Input: one workload JSON (`PRD.md` §5.2) parsed with `nlohmann/json` at startup.
- Output: one result JSON (`PRD.md` §5.3) written once, at the end of `runSimulation`, via `nlohmann/json`'s object-building API — never hand-built with string concatenation (a common source of subtly invalid JSON).
- The engine is single-purpose per invocation: one algorithm, one workload, one output file. Running "all algorithms against one workload" (for comparison) is a shell-level loop calling the binary multiple times (Section 6.2), not a feature inside the engine itself.

---

## 4. Data contracts (the schemas everything else depends on)

These are reproduced from `PRD.md` §5 because they are the single most important interface boundary in the system — any change here must be made in both documents at once, plus every reader (dashboard, analysis.py).

### 4.1 Process struct (in-memory, engine only — not serialized directly)

See `PRD.md` §5.1 for the full struct. Key point for architecture: this struct is engine-internal state. It is never serialized as-is; the result JSON's `processStats` array (4.3 below) is a deliberately reduced projection of it, and `gantt`/`decisionLog` extract only the fields each needs.

### 4.2 Workload JSON (engine input)

See `PRD.md` §5.2. Consumed only by the engine (`main.cpp` reads the `--workload` path). Dashboard and analysis never read workload files directly — they only ever see engine *output*.

### 4.3 Result JSON (engine output → dashboard + analysis input)

See `PRD.md` §5.3 for the full shape. Field-by-field ownership:

| Field | Written by | Read by |
|---|---|---|
| `algorithm`, `workloadName` | engine (from CLI args / workload file) | dashboard (top bar), analysis (grouping key) |
| `gantt[]` | `simulator.cpp` tick loop | dashboard (Gantt chart, EDRD §5.2) |
| `decisionLog[]` | `scheduler.explainLastDecision()` each tick | dashboard (why-panel, EDRD §5.4) |
| `processStats[]` | computed at completion, per process | dashboard (ready queue history), analysis (per-process detail if needed) |
| `summary` | computed once, at end of `runSimulation` | dashboard (top-bar stat tiles), analysis (comparison table/charts — this is the primary field analysis.py consumes) |

`analysis.py`'s main job is: read N result JSONs' `summary` blocks, one per algorithm (same `workloadName`), and produce the comparison table + charts in `PRD.md` §8.2. It does not need `gantt` or `decisionLog` at all — those exist purely for the dashboard.

---

## 5. Dashboard internals (`dashboard/`)

### 5.1 Module breakdown

```
dashboard/
├── index.html      structure only — panel containers, no inline logic
├── style.css       all EDRD.md tokens + component styles
├── app.js          state, rendering, playback control
└── vendor/
    ├── gsap.min.js            GSAP core (logged deviation — EDRD.md §8.3)
    └── ScrollTrigger.min.js   GSAP plugin, intro splash only (EDRD.md §9)
```

No build step, no bundler — `app.js` is loaded directly via `<script src="app.js">`. Chart.js was never actually adopted: nothing in the Milestone-1 dashboard needs it (the Gantt chart and why-panel's score-breakdown bar are custom CSS/DOM per EDRD.md §5.2/§5.4, not Chart.js charts) — that call was made during Milestone 1 build-out and is worth a heads-up before reaching for it in Milestone 2's `analysis.py` charts, which are matplotlib-rendered images anyway, not a dashboard concern. GSAP (core + ScrollTrigger) *was* adopted, post-Milestone-1, as a logged exception — vendored locally per the same offline-demo-safety principle this paragraph already argued for Chart.js.

### 5.2 `app.js` state model

One global state object, single source of truth:

```js
const state = {
  resultData: null,      // the parsed result JSON, immutable once loaded
  currentTick: 0,         // the only thing that changes during playback
  isPlaying: false,
  speed: 1,                // 0.5 | 1 | 2 | 4
};
```

Every panel is a pure function of `state`: `render(state)` re-derives what's on screen from `resultData` + `currentTick`. There is no panel-local state and no direct DOM mutation from anywhere except the render functions — this keeps "what does the screen show at tick N" fully deterministic and easy to debug (you can jump `currentTick` to any value, call `render(state)`, and get a correct frame, which is exactly what the scrub bar and step controls need).

```
render(state):
    renderTopBar(state)          # EDRD §5.1 — stat tiles up to currentTick
    renderGanttChart(state)      # EDRD §5.2 — playhead position + segments up to currentTick
    renderReadyQueue(state)      # EDRD §5.3 — derived: which processes are READY at currentTick
    renderWhyPanel(state)        # EDRD §5.4 — decisionLog entry at/before currentTick
    renderAgingList(state)       # EDRD §5.5
```

`renderReadyQueue` and `renderWhyPanel` derive their content by scanning `resultData.decisionLog`/`gantt` for the entry covering `currentTick` — there is no separate "ready queue over time" array in the JSON; the dashboard reconstructs state-at-a-tick from the logs it already has. This is a deliberate simplification: it means the JSON schema doesn't need a full per-tick process-state dump, only the two logs already specified in Section 4.3.

### 5.3 Playback loop

```
function play():
    state.isPlaying = true
    intervalId = setInterval(() => {
        state.currentTick += 1
        if state.currentTick >= maxTick(state.resultData): pause()
        render(state)
    }, 1000 / (baseTicksPerSecond * state.speed))

function pause(): state.isPlaying = false; clearInterval(intervalId)
function stepForward(): pause(); state.currentTick += 1; render(state)
function stepBack(): pause(); state.currentTick = max(0, state.currentTick - 1); render(state)
function scrubTo(tick): pause(); state.currentTick = tick; render(state)
```

Interaction/animation details (transition timing, playhead motion, cross-fades) are specified in `EDRD.md` §6 — this section only covers the control-flow structure, not the visual treatment.

### 5.4 Loading a result file

MVP mechanism (per `PRD.md` §7.7): a file picker or hardcoded `fetch('results/latest.json')` — you run the engine binary yourself, it writes to `results/`, you refresh the page or re-select the file. No live connection to the engine process. The optional Milestone-4 "Run button calls the binary" stretch goal would add a minimal local HTTP server as a fourth component — out of scope unless explicitly built (see `CLAUDE.md`).

---

## 6. Analysis internals (`analysis/analysis.py`)

### 6.1 Responsibilities

1. Load a set of result JSONs (one per algorithm, same workload).
2. Extract each one's `summary` block into a pandas DataFrame (`algorithm` as index, metrics as columns).
3. Write a comparison table (CSV + Markdown).
4. Render the charts specified in `PRD.md` §8.2 using matplotlib, styled per `EDRD.md` §7.2 (dark background, neon palette, JetBrains Mono).

### 6.2 How comparisons actually get generated

`analysis.py` does not invoke the C++ engine itself — a separate small script/shell loop (e.g. `scripts/run_all.sh` or a `runner.py`) is responsible for calling the engine binary once per algorithm against one workload, collecting the output paths, and handing them to `analysis.py`:

```
for algo in fcfs sjf rr priority mlfq aars:
    ./build/engine/chronos --algorithm $algo --workload workloads/mixed.json --out results/mixed_$algo.json

python3 analysis/analysis.py results/mixed_*.json
```

Keeping the "run everything" orchestration outside both the engine (which stays single-purpose) and `analysis.py` (which stays a pure reader) is what lets each piece be tested in isolation — you can hand `analysis.py` three hand-crafted fake result JSONs and verify the chart/table logic without ever invoking the C++ binary.

---

## 7. Cross-cutting: the decision log as shared infrastructure

The `decisionLog` (defined once, in Section 4.3) is deliberately reused for three different consumers instead of building three separate logging mechanisms (per `PRD.md` §11):

1. **The dashboard's why-panel** reads it live, per-tick, from the loaded JSON.
2. **`logs/scheduler.log`** is a human-readable text rendering of the same entries, written by the engine alongside the JSON, for terminal debugging and for quoting from during a viva.
3. **Regression testing** — the edge-case tests in `PRD.md` §10 can assert against specific `decisionLog` entries (e.g. "at tick 14, P1 should be chosen with reason tag `aging_bonus`") rather than only checking final summary stats, which makes test failures much easier to diagnose.

Building this once, correctly, in the engine (Section 3.5) pays for itself across all three uses — it is the single highest-leverage piece of infrastructure in the whole system, and worth getting right before moving past Milestone 1.

---

## 8. Build & run topology

```
CMakeLists.txt          → builds engine/ into a single binary: build/engine/chronos
dashboard/               → no build step; open index.html directly or serve statically
analysis/                → run directly with `python3 analysis/analysis.py <files>`
```

No component depends on another component's build output at compile time. The only coupling is the JSON files in `results/` at runtime. See `CLAUDE.md` for exact commands.

---

## 9. Extension points (where future work plugs in, without restructuring)

| Future addition | Where it plugs in | What it must NOT touch |
|---|---|---|
| MLFQ (Milestone 3) | New `schedulers/mlfq.cpp` implementing the `Scheduler` interface (§3.2) | `simulator.cpp`, JSON schema |
| Real pthreads (stretch, PRD §6.5) | A parallel `simulator_threaded.cpp`, separate binary target | The primary JSON-producing `simulator.cpp` path — must stay isolated so a threading bug can't break the main deliverable (per `CLAUDE.md`) |
| Local server for a live "Run" button (stretch, PRD §7.7) | New small component, e.g. `server/` (Python `http.server` or similar) | Engine internals, dashboard's file-based load path (should remain a fallback) |
| Fairness index (stretch, PRD §6.5) | New field in `summary` (§4.3), computed at end of `runSimulation` from existing `processStats` | Nothing — purely additive to the schema |
| Large-scale benchmark mode (stretch) | New CLI flag / mode in `main.cpp` that generates a synthetic workload in-memory instead of reading one | `Scheduler` interface, JSON schema |

Every extension point above is additive to the existing module boundaries — none require restructuring the three-subsystem split in Section 1. If a future idea *would* require restructuring that split, that's a signal to slow down and re-check it against `PRD.md` §2 before building it.
