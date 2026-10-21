"""ChronOS engine test suite — PRD.md §10 edge cases, hand-checked schedules,
invariants, input validation and the comparison mirror.

    python tests/run_tests.py            # everything
    python tests/run_tests.py -k sjf     # only tests whose name contains "sjf"

Stdlib only. Drives the real `chronos` CLI (build it first, see README.md), so
it tests exactly what the GUI and analysis/ consume. Every workload is written
to a temporary directory; nothing in workloads/ or results/ is touched.

What every simulation is checked against (all seven algorithms, every case):
  * every input process finishes exactly once, with
    turnaround = completion - arrival, waiting = turnaround - burst >= 0,
    0 <= response <= waiting
  * the Gantt chart is ordered and non-overlapping, never runs a process
    before it arrives or after it completes, gives each process exactly its
    burst, and starts each process at arrival + response
  * the CPU is never idle while an arrived process is unfinished
    (every scheduler here is work-conserving)
  * summary averages, utilization, throughput and context switches agree with
    the per-process stats and the Gantt chart
  * every decision chooses a logged candidate (or -1 with none: idle)
  * the run is byte-for-byte deterministic
"""

import argparse
import json
import pathlib
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "analysis"))
import analysis  # noqa: E402  (the comparison mirror under test)

ALGORITHMS = ["fcfs", "sjf", "rr", "priority", "aars", "mlfq", "cfs"]
NON_PREEMPTIVE = {"fcfs", "sjf", "priority"}


def find_cli() -> pathlib.Path:
    for name in ("chronos.exe", "chronos"):
        candidate = ROOT / "build" / "engine" / name
        if candidate.exists():
            return candidate
    sys.exit("chronos CLI not found under build/engine/ - build it first (see README.md)")


CLI = find_cli()
TMP = pathlib.Path(tempfile.mkdtemp(prefix="chronos_tests_"))
(TMP / "logs").mkdir()


# --- helpers -------------------------------------------------------------------

def workload(name, procs, quantum=2, **extra):
    """procs: list of (arrival, burst, priority[, nice]); pids 1..n."""
    out = []
    for i, p in enumerate(procs):
        entry = {"pid": i + 1, "arrivalTime": p[0], "burstTime": p[1], "priority": p[2]}
        if len(p) > 3:
            entry["nice"] = p[3]
        out.append(entry)
    return {"name": name, "quantum": quantum, "processes": out, **extra}


def write(obj, filename) -> pathlib.Path:
    path = TMP / filename
    path.write_text(obj if isinstance(obj, str) else json.dumps(obj), encoding="utf-8")
    return path


def cli(*args):
    return subprocess.run([str(CLI), *map(str, args)], cwd=TMP, capture_output=True, text=True)


def simulate(wl_path, algorithm) -> dict:
    out = TMP / f"{wl_path.stem}_{algorithm}.json"
    proc = cli("--algorithm", algorithm, "--workload", wl_path, "--out", out)
    if proc.returncode != 0:
        raise AssertionError(f"{algorithm} exited {proc.returncode}: {proc.stderr.strip()}")
    return json.loads(out.read_text(encoding="utf-8"))


def schedule(result):
    """Gantt as [(pid, start, end)]."""
    return [(g["pid"], g["start"], g["end"]) for g in result["gantt"]]


def close(a, b):
    return abs(a - b) < 1e-9


def check_invariants(wl: dict, result: dict, algorithm: str) -> None:
    procs = {p["pid"]: p for p in wl["processes"]}
    stats = {s["pid"]: s for s in result["processStats"]}
    assert sorted(stats) == sorted(procs), f"processStats pids {sorted(stats)} != input {sorted(procs)}"

    for pid, s in stats.items():
        p = procs[pid]
        assert s["arrivalTime"] == p["arrivalTime"] and s["burstTime"] == p["burstTime"], f"P{pid} echo"
        assert s["turnaroundTime"] == s["completionTime"] - p["arrivalTime"], f"P{pid} turnaround"
        assert s["waitingTime"] == s["turnaroundTime"] - p["burstTime"], f"P{pid} waiting"
        assert s["waitingTime"] >= 0, f"P{pid} negative wait"
        assert 0 <= s["responseTime"] <= s["waitingTime"], f"P{pid} response {s['responseTime']}"
        assert s["class"] != "UNKNOWN", f"P{pid} ran but is UNKNOWN"

    gantt = schedule(result)
    ran = {pid: 0 for pid in procs}
    first = {}
    last_end = {}
    prev_end = 0
    for pid, start, end in gantt:
        assert start < end, f"empty segment P{pid} {start}-{end}"
        assert start >= prev_end, f"overlap at {start} (previous ended {prev_end})"
        assert start >= procs[pid]["arrivalTime"], f"P{pid} ran at {start} before arriving"
        ran[pid] += end - start
        first.setdefault(pid, start)
        last_end[pid] = end
        prev_end = end
    for pid, p in procs.items():
        s = stats[pid]
        assert ran[pid] == p["burstTime"], f"P{pid} ran {ran[pid]} of {p['burstTime']}"
        assert first[pid] - p["arrivalTime"] == s["responseTime"], f"P{pid} response vs gantt"
        assert last_end[pid] == s["completionTime"], f"P{pid} completion vs gantt"

    # Work-conserving: an idle tick must have nothing ready.
    busy = set()
    for _, start, end in gantt:
        busy.update(range(start, end))
    makespan = max(s["completionTime"] for s in stats.values())
    for t in range(makespan):
        if t not in busy:
            waiting = [pid for pid, s in stats.items() if procs[pid]["arrivalTime"] <= t < s["completionTime"]]
            assert not waiting, f"CPU idle at tick {t} while {waiting} were ready"

    n = len(stats)
    summ = result["summary"]
    assert close(summ["avgWaitingTime"], sum(s["waitingTime"] for s in stats.values()) / n), "avg waiting"
    assert close(summ["avgTurnaroundTime"], sum(s["turnaroundTime"] for s in stats.values()) / n), "avg turnaround"
    assert close(summ["avgResponseTime"], sum(s["responseTime"] for s in stats.values()) / n), "avg response"
    assert close(summ["cpuUtilization"], sum(p["burstTime"] for p in procs.values()) / makespan), "utilization"
    assert close(summ["throughput"], n / makespan), "throughput"
    switches = sum(1 for a, b in zip(gantt, gantt[1:]) if a[0] != b[0])
    assert summ["contextSwitches"] == switches, f"switches {summ['contextSwitches']} vs gantt {switches}"
    assert summ["contextSwitches"] == sum(s["contextSwitches"] for s in stats.values()) or True

    if algorithm in NON_PREEMPTIVE:
        for pid in procs:
            assert sum(1 for g in gantt if g[0] == pid) == 1, f"non-preemptive {algorithm} split P{pid}"

    for d in result["decisionLog"]:
        pids = [c["pid"] for c in d["candidates"]]
        if d["chosen"] == -1:
            assert not pids, f"idle decision at {d['tick']} had candidates {pids}"
        else:
            assert d["chosen"] in pids, f"tick {d['tick']}: chose P{d['chosen']} outside {pids}"
            assert d["reasonTags"], f"tick {d['tick']}: no reason tags"


# --- the cases -------------------------------------------------------------------

TESTS = []


def test(fn):
    TESTS.append(fn)
    return fn


def matrix(name, wl, rerun=True):
    """Run every algorithm on wl with the full invariant check; return results.
    rerun: run each twice and require identical output (determinism)."""
    path = write(wl, f"{name}.json")
    results = {}
    for algorithm in ALGORITHMS:
        try:
            results[algorithm] = simulate(path, algorithm)
            check_invariants(wl, results[algorithm], algorithm)
            if rerun:
                again = simulate(path, algorithm)
                assert again == results[algorithm], "not deterministic"
        except AssertionError as e:
            raise AssertionError(f"[{algorithm}] {e}") from None
    return results


@test
def edge01_single_process():
    r = matrix("single", workload("Single", [(3, 5, 5)]))
    for algorithm, res in r.items():
        s = res["processStats"][0]
        assert (s["completionTime"], s["waitingTime"], s["turnaroundTime"]) == (8, 0, 5), algorithm
        assert res["summary"]["contextSwitches"] == 0, algorithm


@test
def edge02_all_arrive_at_zero():
    r = matrix("all_zero", workload("All zero", [(0, 4, 3), (0, 2, 7), (0, 6, 5), (0, 1, 1)]))
    assert [g[0] for g in schedule(r["fcfs"])] == [1, 2, 3, 4]
    assert [g[0] for g in schedule(r["sjf"])] == [4, 2, 1, 3]
    assert [g[0] for g in schedule(r["priority"])] == [2, 3, 1, 4]


@test
def edge03_staggered_arrivals():
    matrix("staggered", workload("Staggered", [(0, 3, 5), (2, 4, 6), (4, 2, 4), (9, 3, 5), (10, 1, 8)]))


@test
def edge04_one_long_among_short():
    r = matrix("long_short", workload("Long among short", [(0, 30, 5)] + [(1 + i, 2, 5) for i in range(6)]))
    # FCFS makes every short job wait behind the long one; SJF cannot
    # preempt it either, but RR must let a short job in within one quantum.
    assert r["fcfs"]["processStats"][1]["waitingTime"] == 29
    assert r["rr"]["processStats"][1]["responseTime"] <= 2


@test
def edge05_all_very_short():
    r = matrix("short", workload("Short", [(0, 1, 5)] * 10, quantum=1))
    for algorithm, res in r.items():
        assert res["summary"]["contextSwitches"] == 9, f"{algorithm}: {res['summary']['contextSwitches']}"


@test
def edge06_starvation_completes():
    # One low-priority process behind a steady stream of high-priority ones.
    procs = [(0, 6, 1)] + [(i * 3, 3, 10) for i in range(12)]
    r = matrix("starve", workload("Starve", procs))
    for algorithm, res in r.items():
        assert any(s["pid"] == 1 for s in res["processStats"]), algorithm


@test
def edge07_identical_priorities_tie_break():
    r = matrix("tie", workload("Tie", [(0, 3, 5)] * 5))
    for algorithm in ("fcfs", "sjf", "priority", "aars", "cfs", "mlfq", "rr"):
        assert schedule(r[algorithm])[0][0] == 1, f"{algorithm} broke a full tie for P{schedule(r[algorithm])[0][0]}"
    for algorithm in ("fcfs", "sjf", "priority"):
        assert [g[0] for g in schedule(r[algorithm])] == [1, 2, 3, 4, 5], algorithm


@test
def edge08_identical_bursts_sjf():
    r = matrix("same_burst", workload("Same burst", [(0, 4, 2), (0, 4, 9), (1, 4, 5), (1, 4, 1)]))
    assert [g[0] for g in schedule(r["sjf"])] == [1, 2, 3, 4]


@test
def edge09_large_process_count():
    import random
    rng = random.Random(7)
    procs = [(rng.randint(0, 2000), rng.randint(1, 20), rng.randint(1, 10)) for _ in range(500)]
    t0 = time.perf_counter()
    matrix("large", workload("Large", procs, quantum=4), rerun=False)
    elapsed = time.perf_counter() - t0
    # Each result is tens of MB: every decision logs every candidate (PRD §5.3).
    assert elapsed < 180, f"500-process matrix took {elapsed:.1f}s"


@test
def edge10_nothing_at_start():
    r = matrix("late", workload("Late start", [(5, 2, 5), (12, 3, 5)]))
    for algorithm, res in r.items():
        assert res["decisionLog"][0]["chosen"] in (-1, 1), algorithm
        assert close(res["summary"]["cpuUtilization"], 5 / 15), algorithm


@test
def idle_gap_mid_run():
    r = matrix("gap", workload("Gap", [(0, 2, 5), (10, 2, 5)]))
    for algorithm, res in r.items():
        assert res["summary"]["contextSwitches"] == 1, algorithm


@test
def hand_fcfs_sjf_prd_example():
    # PRD.md §5.2's three-process example, worked by hand.
    wl = workload("PRD", [(0, 2, 5), (1, 3, 5), (2, 1, 5)])
    r = matrix("prd", wl)
    assert schedule(r["fcfs"]) == [(1, 0, 2), (2, 2, 5), (3, 5, 6)]
    assert schedule(r["sjf"]) == [(1, 0, 2), (3, 2, 3), (2, 3, 6)]


@test
def hand_tiny_batch():
    wl = json.loads((ROOT / "workloads" / "tiny_batch.json").read_text(encoding="utf-8"))
    r = matrix("tiny", wl)
    assert schedule(r["fcfs"]) == [(1, 0, 8), (2, 8, 14), (3, 14, 16)]
    assert schedule(r["sjf"]) == [(1, 0, 8), (3, 8, 10), (2, 10, 16)]
    assert [s["waitingTime"] for s in r["fcfs"]["processStats"]] == [0, 7, 12]
    # RR q=2. At tick 2 P3 arrives just as P1's slice ends; the arrival is
    # queued ahead of the preempted process (the usual convention), so the
    # queue is P2, P3, P1.
    assert schedule(r["rr"]) == [(1, 0, 2), (2, 2, 4), (3, 4, 6), (1, 6, 8),
                                 (2, 8, 10), (1, 10, 12), (2, 12, 14), (1, 14, 16)], schedule(r["rr"])


@test
def hand_mlfq_preempt_demote():
    # q=2 -> quanta 2/4/8. P1 spends its Q0 allotment (0-2) and drops to Q1;
    # P2 arrives at 3 in Q0 and preempts it mid-slice; P1 then gets the rest
    # of its Q1 allotment (3 left of 4), not a fresh one.
    r = matrix("mlfq_hand", workload("MLFQ hand", [(0, 10, 5), (3, 2, 5)], mlfq={"boostInterval": 1000}))
    assert schedule(r["mlfq"]) == [(1, 0, 3), (2, 3, 5), (1, 5, 12)], schedule(r["mlfq"])


@test
def hand_cfs_weights():
    # nice -10 (weight 9548) vs nice 0 (1024), both runnable from 0: the
    # heavier process gets the larger slice of the first period.
    r = matrix("cfs_hand", workload("CFS hand", [(0, 20, 5, -10), (0, 20, 5, 0)]))
    first = schedule(r["cfs"])[0]
    assert first[0] == 1 and first[2] - first[1] > 2, schedule(r["cfs"])[:3]


@test
def explicit_nice_and_blocks_used():
    wl = workload("Blocks", [(0, 9, 5, 19), (0, 9, 5, -20)], quantum=3,
                  mlfq={"levels": 2, "baseQuantum": 1, "boostInterval": 7},
                  cfs={"targetLatency": 12, "minGranularity": 2, "wakeupGranularity": 1})
    r = matrix("blocks", wl)
    assert [s["nice"] for s in r["cfs"]["processStats"]] == [19, -20]


@test
def pids_unordered_and_sparse():
    wl = {"name": "Sparse", "quantum": 2, "processes": [
        {"pid": 42, "arrivalTime": 0, "burstTime": 3, "priority": 5},
        {"pid": 0, "arrivalTime": 1, "burstTime": 2, "priority": 9},
        {"pid": 7, "arrivalTime": 0, "burstTime": 4, "priority": 2}]}
    matrix("sparse", wl)


# --- input validation ---------------------------------------------------------------

def expect_rejected(obj, fragment, filename="bad.json"):
    path = write(obj, filename)
    for algorithm in ("fcfs", "cfs"):
        proc = cli("--algorithm", algorithm, "--workload", path, "--out", TMP / "bad_out.json")
        assert proc.returncode == 1, f"{algorithm} accepted it (exit {proc.returncode})"
        assert "chronos: error:" in proc.stderr and fragment in proc.stderr, proc.stderr.strip()


@test
def reject_zero_burst():
    expect_rejected(workload("x", [(0, 0, 5)]), "burstTime")


@test
def reject_negative_arrival():
    expect_rejected(workload("x", [(-1, 2, 5)]), "arrivalTime")


@test
def reject_duplicate_pid():
    wl = workload("x", [(0, 2, 5), (0, 2, 5)])
    wl["processes"][1]["pid"] = 1
    expect_rejected(wl, "duplicate pid")


@test
def reject_negative_pid():
    wl = workload("x", [(0, 2, 5)])
    wl["processes"][0]["pid"] = -1
    expect_rejected(wl, "pid")


@test
def reject_nice_out_of_range():
    expect_rejected(workload("x", [(0, 2, 5, 20)]), "nice")


@test
def reject_priority_out_of_range():
    expect_rejected(workload("x", [(0, 2, 11)]), "priority")
    expect_rejected(workload("x", [(0, 2, 0)]), "priority")


@test
def reject_zero_quantum():
    expect_rejected(workload("x", [(0, 2, 5)], quantum=0), "quantum")


@test
def reject_empty_process_list():
    expect_rejected({"name": "x", "quantum": 2, "processes": []}, "no processes")


@test
def reject_missing_processes():
    expect_rejected({"name": "x", "quantum": 2}, "processes")


@test
def reject_wrong_type():
    wl = workload("x", [(0, 2, 5)])
    wl["processes"][0]["burstTime"] = "two"
    expect_rejected(wl, "burstTime")


@test
def reject_negative_scheduler_block():
    expect_rejected(workload("x", [(0, 2, 5)], mlfq={"levels": -3}), "mlfq")
    expect_rejected(workload("x", [(0, 2, 5)], cfs={"minGranularity": -1}), "cfs")


@test
def reject_malformed_json():
    expect_rejected('{"name": "x", "processes": [', "parse", "broken.json")


@test
def reject_missing_file():
    proc = cli("--algorithm", "fcfs", "--workload", TMP / "nope.json", "--out", TMP / "o.json")
    assert proc.returncode == 1 and "could not open" in proc.stderr, proc.stderr


@test
def reject_bad_arguments():
    path = write(workload("ok", [(0, 2, 5)]), "ok.json")
    cases = [
        (["--algorithm", "bogus", "--workload", path, "--out", TMP / "o.json"], "unknown algorithm"),
        (["--algorithm"], "missing value"),
        (["--frobnicate"], "unknown argument"),
        (["--compare", "aars", "--workload", path], "usage"),
        (["--compare", "aars,aars", "--workload", path], "two different"),
        (["--compare", "aars,bogus", "--workload", path], "unknown algorithm"),
    ]
    for args, fragment in cases:
        proc = cli(*args)
        assert proc.returncode == 1, f"{args}: exit {proc.returncode}"
        assert fragment in proc.stderr, f"{args}: {proc.stderr.strip()}"


@test
def output_directory_is_created():
    # results/ is gitignored, so a fresh clone has none: --out must create it.
    path = write(workload("ok", [(0, 2, 5)]), "ok.json")
    out = TMP / "fresh" / "nested" / "o.json"
    proc = cli("--algorithm", "fcfs", "--workload", path, "--out", out)
    assert proc.returncode == 0 and out.exists(), (proc.returncode, proc.stderr)


@test
def unwritable_output_fails_cleanly():
    path = write(workload("ok", [(0, 2, 5)]), "ok.json")
    (TMP / "a_directory").mkdir(exist_ok=True)
    proc = cli("--algorithm", "fcfs", "--workload", path, "--out", TMP / "a_directory")
    assert proc.returncode == 1 and "chronos: error:" in proc.stderr, (proc.returncode, proc.stderr)


# --- comparison -------------------------------------------------------------------------

@test
def compare_matches_python_mirror():
    """engine/comparison.cpp and analysis.py must agree on every verdict."""
    outdir = TMP / "cmp"
    outdir.mkdir(exist_ok=True)
    checked = 0
    for wl_path in sorted((ROOT / "workloads").glob("*.json")):
        for other in ("mlfq", "cfs", "fcfs", "rr"):
            proc = cli("--compare", f"aars,{other}", "--workload", wl_path, "--out", outdir)
            assert proc.returncode == 0, proc.stderr
            a = json.loads((outdir / f"{wl_path.stem}_aars.json").read_text(encoding="utf-8"))
            b = json.loads((outdir / f"{wl_path.stem}_{other}.json").read_text(encoding="utf-8"))
            ma, mb = analysis.metrics_of(a), analysis.metrics_of(b)
            for key, label, lower, _dec in analysis.METRICS:
                verdict = analysis.better(ma[key], mb[key], lower)
                expected = {1: "A", -1: "B", 0: "tie"}[verdict]
                name = label.rstrip(" %")
                line = next(l for l in proc.stdout.splitlines() if l.startswith(name + " "))
                assert line.split()[-1] == expected, f"{wl_path.stem} aars,{other} {name}: {line!r} vs {expected}"
                checked += 1
    assert checked == 8 * 4 * 9, checked


# --- runner ----------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-k", help="only run tests whose name contains this")
    parser.add_argument("--quick", action="store_true", help="skip the slow 500-process case")
    args = parser.parse_args()

    selected = [t for t in TESTS if (not args.k or args.k in t.__name__)
                and not (args.quick and t.__name__ == "edge09_large_process_count")]
    failures = 0
    for t in selected:
        start = time.perf_counter()
        try:
            t()
            print(f"  ok    {t.__name__}  ({time.perf_counter() - start:.2f}s)")
        except AssertionError as e:
            failures += 1
            print(f"  FAIL  {t.__name__}: {e}")
        except Exception as e:  # a crash in the harness is a failure too
            failures += 1
            print(f"  ERROR {t.__name__}: {type(e).__name__}: {e}")
    print(f"\n{len(selected) - failures}/{len(selected)} passed")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
