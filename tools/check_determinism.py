#!/usr/bin/env python3
"""Check deterministic Warbound simulation replay across separate Godot processes.

Run after importing and parsing the project:
    python3 tools/check_determinism.py [--godot path/to/godot]
This checks repeatability, not equivalence between two different game versions.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CASES = (
    ("ai_match", 827, 600, 200),
    ("battle", 827, 100, 50),
)


def replay(godot: str, scenario: str, seed: int, ticks: int, every: int) -> list[dict]:
    command = [
        godot, "--headless", "--path", str(ROOT),
        "--script", "res://tests/determinism_probe.gd", "--",
        f"--scenario={scenario}", f"--seed={seed}",
        f"--ticks={ticks}", f"--every={every}",
    ]
    completed = subprocess.run(
        command, cwd=ROOT, text=True, capture_output=True,
        timeout=150, check=False,
    )
    output = completed.stdout + "\n" + completed.stderr
    checkpoints = []
    for line in output.splitlines():
        if line.startswith("DETERMINISM "):
            checkpoints.append(json.loads(line[len("DETERMINISM "):]))
    expected = list(range(every, ticks + 1, every))
    if expected[-1] != ticks:
        expected.append(ticks)
    actual = [int(item["tick"]) for item in checkpoints]
    if (completed.returncode != 0 or actual != expected
            or "SCRIPT ERROR:" in output or "Assertion failed" in output):
        raise RuntimeError(
            f"{scenario}: process={completed.returncode}, checkpoints={actual}, "
            f"expected={expected}\n{output[-8000:]}"
        )
    return checkpoints


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    for scenario, seed, ticks, every in CASES:
        try:
            first = replay(args.godot, scenario, seed, ticks, every)
            second = replay(args.godot, scenario, seed, ticks, every)
        except (OSError, subprocess.TimeoutExpired, ValueError, KeyError, RuntimeError) as error:
            print(f"FAIL: deterministic replay {scenario}: {error}", file=sys.stderr)
            return 1
        if first != second:
            for before, after in zip(first, second):
                if before != after:
                    print(
                        f"FAIL: {scenario} tick {before['tick']} differs "
                        f"between independent executions",
                        file=sys.stderr,
                    )
                    print(json.dumps({"first": before, "second": after}), file=sys.stderr)
                    break
            return 1
        print(f"PASS: {scenario} seed={seed}: {len(first)} matching checkpoints", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
