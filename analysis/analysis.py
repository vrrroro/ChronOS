"""ChronOS comparison analysis (PRD.md §8.2, issue #1).

Reads result JSONs written by the chronos CLI and compares algorithms that ran
on the same workload. Three views:

    python analysis/analysis.py results/*.json
        Every algorithm on every workload, best value per metric marked.

    python analysis/analysis.py results/*.json --pair aars cfs
        Head to head, workload by workload: which of the two is better on each
        metric, and the overall tally - the same verdict the GUI's compare
        screen and `chronos --compare` give.

    python analysis/analysis.py results/*.json --versus aars mlfq cfs
        Where the first algorithm beats *every* other one listed, and where it
        loses to at least one. This is the honest answer to "where does AARS
        win?" (PRD §2.4): losses are listed as plainly as wins.

Writes analysis/output/report.md and comparison.csv. With --charts, also the
four PNG charts of PRD §8.2 (needs matplotlib; everything else is stdlib only).

Metric definitions mirror engine/comparison.cpp exactly - same keys, same
direction, same tie rule - so the numbers here and in the GUI never disagree.
Every value is computed from a result file; nothing is authored (AGENTS.md).
"""

import argparse
import csv
import json
import math
import pathlib
import sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "analysis" / "output"

# CLI key -> the "algorithm" name the engine writes into each result.
KEY_TO_NAME = {
    "fcfs": "FCFS",
    "sjf": "SJF",
    "rr": "Round Robin",
    "priority": "Priority",
    "aars": "AARS",
    "mlfq": "MLFQ (Windows)",
    "cfs": "CFS (Linux)",
}
ORDER = list(KEY_TO_NAME.values())

# (key, label, lowerIsBetter, decimals) - engine/comparison.cpp, same order.
METRICS = [
    ("avgWaitingTime", "AVG WAITING", True, 2),
    ("avgTurnaroundTime", "AVG TURNAROUND", True, 2),
    ("avgResponseTime", "AVG RESPONSE", True, 2),
    ("maxWaitingTime", "WORST WAITING", True, 0),
    ("avgSlowdown", "AVG SLOWDOWN", True, 2),
    ("contextSwitches", "CONTEXT SWITCHES", True, 0),
    ("fairness", "FAIRNESS (JAIN)", False, 3),
    ("cpuUtilization", "CPU UTILIZATION %", False, 1),
    ("throughput", "THROUGHPUT", False, 3),
]

# EDRD §7.2: one fixed color per algorithm, drawn from the §2.3 hue table.
ALGO_COLORS = {
    "FCFS": "#4D9FFF", "SJF": "#FFB000", "Round Robin": "#00E5FF", "Priority": "#C77DFF",
    "AARS": "#33FF00", "MLFQ (Windows)": "#FF3EC9", "CFS (Linux)": "#FF7A29",
}


def metrics_of(result: dict) -> dict:
    s = result["summary"]
    stats = result["processStats"]
    ratio, slowdown = [], []
    for p in stats:
        if p["burstTime"] > 0 and p["turnaroundTime"] > 0:
            ratio.append(p["burstTime"] / p["turnaroundTime"])
            slowdown.append(p["turnaroundTime"] / p["burstTime"])
    fairness = (sum(ratio) ** 2) / (len(ratio) * sum(x * x for x in ratio)) if ratio else 1.0
    return {
        "avgWaitingTime": s["avgWaitingTime"],
        "avgTurnaroundTime": s["avgTurnaroundTime"],
        "avgResponseTime": s["avgResponseTime"],
        "maxWaitingTime": max((p["waitingTime"] for p in stats), default=0),
        "avgSlowdown": sum(slowdown) / len(slowdown) if slowdown else 0.0,
        "contextSwitches": s["contextSwitches"],
        "fairness": fairness,
        "cpuUtilization": s["cpuUtilization"] * 100.0,
        "throughput": s["throughput"],
    }


def same(a: float, b: float) -> bool:
    # comparison.cpp: llround(a * 1e6) == llround(b * 1e6); all values >= 0.
    return math.floor(a * 1e6 + 0.5) == math.floor(b * 1e6 + 0.5)


def better(a: float, b: float, lower: bool) -> int:
    """1 if a is better, -1 if b is, 0 if tied."""
    if same(a, b):
        return 0
    return 1 if (a < b if lower else a > b) else -1


def resolve(name: str) -> str:
    return KEY_TO_NAME.get(name.lower(), name)


def load(paths) -> dict:
    """{workloadName: {algorithmName: metrics}}"""
    runs = defaultdict(dict)
    for path in paths:
        try:
            result = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
            runs[result["workloadName"]][result["algorithm"]] = metrics_of(result)
        except (OSError, KeyError, ValueError) as e:
            print(f"skipping {path}: {e}", file=sys.stderr)
    return runs


def fmt(value: float, decimals: int) -> str:
    return f"{value:.{decimals}f}"


def ordered(names):
    return sorted(names, key=lambda n: (ORDER.index(n) if n in ORDER else len(ORDER), n))


# --- Views ----------------------------------------------------------------------

def table_view(runs: dict) -> list:
    lines = ["# ChronOS comparison", "",
             "Every value computed from the result files. `*` marks the best value on that workload "
             "(several when tied).", ""]
    for workload in sorted(runs):
        algos = ordered(runs[workload])
        lines += [f"## {workload}", "", "| Metric | " + " | ".join(algos) + " |",
                  "|---|" + "---:|" * len(algos)]
        for key, label, lower, dec in METRICS:
            values = [runs[workload][a][key] for a in algos]
            best = min(values) if lower else max(values)
            cells = [fmt(v, dec) + (" *" if same(v, best) else "") for v in values]
            lines.append(f"| {label} | " + " | ".join(cells) + " |")
        lines.append("")
    return lines


def pair_view(runs: dict, a: str, b: str) -> list:
    lines = [f"# {a} vs {b}", ""]
    total_a = total_b = total_tie = 0
    for workload in sorted(runs):
        if a not in runs[workload] or b not in runs[workload]:
            continue
        ma, mb = runs[workload][a], runs[workload][b]
        wins_a = wins_b = ties = 0
        lines += [f"## {workload}", "", f"| Metric | {a} | {b} | Better |", "|---|---:|---:|---|"]
        for key, label, lower, dec in METRICS:
            verdict = better(ma[key], mb[key], lower)
            wins_a += verdict == 1
            wins_b += verdict == -1
            ties += verdict == 0
            winner = a if verdict == 1 else b if verdict == -1 else "tie"
            lines.append(f"| {label} | {fmt(ma[key], dec)} | {fmt(mb[key], dec)} | {winner} |")
        overall = a if wins_a > wins_b else b if wins_b > wins_a else "even"
        lines += ["", f"{a} {wins_a} - {b} {wins_b} - tied {ties}  ->  **{overall}**", ""]
        total_a, total_b, total_tie = total_a + wins_a, total_b + wins_b, total_tie + ties
    lines += [f"**All workloads:** {a} {total_a} - {b} {total_b} - tied {total_tie}", ""]
    return lines


def versus_view(runs: dict, focus: str, others: list) -> list:
    lines = [f"# Where {focus} beats {', '.join(others)}", "",
             f"A metric counts as a win only if {focus} is strictly better than every one of "
             f"{', '.join(others)} on that workload. Losses list every metric where at least one "
             "of them did better.", ""]
    win_count = defaultdict(int)
    workloads = [w for w in sorted(runs) if focus in runs[w] and all(o in runs[w] for o in others)]
    for workload in workloads:
        m = runs[workload]
        wins, losses = [], []
        for key, label, lower, dec in METRICS:
            verdicts = [better(m[focus][key], m[o][key], lower) for o in others]
            detail = ", ".join(f"{o} {fmt(m[o][key], dec)}" for o in others)
            line = f"{label}: {fmt(m[focus][key], dec)} vs {detail}"
            if all(v == 1 for v in verdicts):
                wins.append(line)
                win_count[label] += 1
            elif any(v == -1 for v in verdicts):
                beaten_by = [o for o, v in zip(others, verdicts) if v == -1]
                losses.append(f"{line}  (better: {', '.join(beaten_by)})")
        lines += [f"## {workload}", "", f"**{focus} beats all on {len(wins)}:**"]
        lines += [f"- {w}" for w in wins] or ["- nothing"]
        lines += ["", f"**{focus} loses to at least one on {len(losses)}:**"]
        lines += [f"- {l}" for l in losses] or ["- nothing"]
        lines.append("")
    lines += [f"## Summary over {len(workloads)} workloads", "",
              f"| Metric | Workloads where {focus} beats all |", "|---|---:|"]
    for _, label, _, _ in METRICS:
        lines.append(f"| {label} | {win_count[label]} / {len(workloads)} |")
    lines.append("")
    return lines


def write_csv(runs: dict) -> None:
    with open(OUTPUT / "comparison.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["workload", "algorithm"] + [k for k, *_ in METRICS])
        for workload in sorted(runs):
            for algo in ordered(runs[workload]):
                w.writerow([workload, algo] + [runs[workload][algo][k] for k, *_ in METRICS])


def write_charts(runs: dict) -> None:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        from matplotlib import font_manager
    except ImportError:
        print("--charts needs matplotlib (pip install matplotlib); tables were still written", file=sys.stderr)
        return

    # EDRD §7.2: the dashboard's palette and type, so report and app match.
    font = ROOT / "app" / "fonts" / "JetBrainsMono-Regular.ttf"
    family = "monospace"
    if font.exists():
        font_manager.fontManager.addfont(str(font))
        family = font_manager.FontProperties(fname=str(font)).get_name()
    plt.rcParams.update({
        "figure.facecolor": "#000000", "axes.facecolor": "#0A0F0A", "savefig.facecolor": "#000000",
        "text.color": "#33FF00", "axes.labelcolor": "#33FF00", "axes.edgecolor": "#1F521F",
        "xtick.color": "#33FF00", "ytick.color": "#33FF00", "grid.color": "#1F521F",
        "font.family": family, "font.size": 9,
    })

    workloads = sorted(runs)
    algos = ordered({a for w in workloads for a in runs[w]})

    def grouped(key: str, label: str, filename: str) -> None:
        fig, ax = plt.subplots(figsize=(max(8, len(workloads) * 1.4), 4.5))
        width = 0.8 / max(1, len(algos))
        for i, algo in enumerate(algos):
            xs = [j + i * width for j, w in enumerate(workloads) if algo in runs[w]]
            ys = [runs[w][algo][key] for w in workloads if algo in runs[w]]
            ax.bar(xs, ys, width, label=algo, color=ALGO_COLORS.get(algo, "#21A600"))
        ax.set_xticks([j + width * (len(algos) - 1) / 2 for j in range(len(workloads))])
        ax.set_xticklabels(workloads, rotation=20, ha="right")
        ax.set_ylabel(label)
        ax.grid(axis="y", linewidth=0.5)
        ax.set_axisbelow(True)
        ax.legend(fontsize=7, ncol=4, frameon=False)
        fig.tight_layout()
        fig.savefig(OUTPUT / filename, dpi=150)
        plt.close(fig)

    # PRD §8.2's charts. Each is already the "all algorithms across all
    # workloads" grouped view, which is the one that shows behavior changing
    # with workload; turnaround is added as the fourth.
    grouped("avgWaitingTime", "avg waiting (ticks)", "avg_waiting.png")
    grouped("avgResponseTime", "avg response (ticks)", "avg_response.png")
    grouped("contextSwitches", "context switches", "context_switches.png")
    grouped("avgTurnaroundTime", "avg turnaround (ticks)", "avg_turnaround.png")
    print(f"charts written to {OUTPUT.relative_to(ROOT)}/")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("results", nargs="+", help="result JSON files from the chronos CLI")
    parser.add_argument("--pair", nargs=2, metavar=("A", "B"), help="head to head (keys or names)")
    parser.add_argument("--versus", nargs="+", metavar="ALGO",
                        help="first algorithm against all the others listed")
    parser.add_argument("--charts", action="store_true", help="also write PNG charts (needs matplotlib)")
    args = parser.parse_args()

    runs = load(args.results)
    if not runs:
        sys.exit("no readable result files")

    if args.pair:
        lines = pair_view(runs, resolve(args.pair[0]), resolve(args.pair[1]))
    elif args.versus:
        if len(args.versus) < 2:
            sys.exit("--versus needs the focus algorithm and at least one other")
        lines = versus_view(runs, resolve(args.versus[0]), [resolve(v) for v in args.versus[1:]])
    else:
        lines = table_view(runs)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = "\n".join(lines)
    (OUTPUT / "report.md").write_text(report, encoding="utf-8")
    write_csv(runs)
    print(report)
    print(f"[written: {(OUTPUT / 'report.md').relative_to(ROOT)}, {(OUTPUT / 'comparison.csv').relative_to(ROOT)}]")
    if args.charts:
        write_charts(runs)


if __name__ == "__main__":
    main()
