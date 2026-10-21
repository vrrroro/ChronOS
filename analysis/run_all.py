"""Run every algorithm against every workload preset with the chronos CLI.

    python analysis/run_all.py [--only aars,mlfq,cfs]

Writes results/<workload>_<algorithm>.json for analysis.py to read. Kept apart
from analysis.py on purpose (ARCHITECTURE.md §6.2): the engine stays
single-purpose, analysis.py stays a pure reader, and this is the loop between.
"""

import argparse
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALGORITHMS = ["fcfs", "sjf", "rr", "priority", "aars", "mlfq", "cfs"]


def find_cli() -> pathlib.Path:
    for name in ("chronos.exe", "chronos"):
        candidate = ROOT / "build" / "engine" / name
        if candidate.exists():
            return candidate
    sys.exit("chronos CLI not found under build/engine/ - build it first (see README.md)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", help="comma-separated algorithm keys (default: all seven)")
    args = parser.parse_args()

    algorithms = args.only.split(",") if args.only else ALGORITHMS
    unknown = [a for a in algorithms if a not in ALGORITHMS]
    if unknown:
        sys.exit(f"unknown algorithm(s): {', '.join(unknown)} (expected {'|'.join(ALGORITHMS)})")

    cli = find_cli()
    (ROOT / "results").mkdir(exist_ok=True)
    (ROOT / "logs").mkdir(exist_ok=True)

    failures = 0
    workloads = sorted((ROOT / "workloads").glob("*.json"))
    for workload in workloads:
        for algorithm in algorithms:
            out = ROOT / "results" / f"{workload.stem}_{algorithm}.json"
            proc = subprocess.run(
                [str(cli), "--algorithm", algorithm, "--workload", str(workload), "--out", str(out)],
                cwd=ROOT, capture_output=True, text=True,
            )
            if proc.returncode != 0:
                failures += 1
                print(f"FAIL {workload.stem}/{algorithm}: {proc.stderr.strip()}", file=sys.stderr)
    runs = len(workloads) * len(algorithms)
    print(f"{runs - failures}/{runs} runs written to results/")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
