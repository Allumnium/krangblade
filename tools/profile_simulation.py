#!/usr/bin/env python3
"""Run comparable, non-gating headless Warbound simulation profiles.

Uses the existing tests/fleet_benchmark.gd metrics. It reports real execution
statistics without asserting an FPS/tick-time budget (hardware differs).
"""
import argparse
import datetime as dt
import itertools
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PHASES = ("Combat / repair", "Other movement", "Formations / orders",
          "Economy", "Civilian logistics", "AI / routing setup")


def options(value, cast, allowed=None):
    result = [cast(item.strip()) for item in value.split(",")]
    if not result or any(item == "" for item in result):
        raise ValueError("Empty benchmark option")
    if allowed is not None and any(item not in allowed for item in result):
        raise ValueError(f"Invalid benchmark values: {result}")
    return result


def run(godot, seed, scenario, ships, speed, ticks, timeout):
    cmd = [godot, "--headless", "--path", str(ROOT),
           "--script", "res://tests/fleet_benchmark.gd", "--",
           f"--seed={seed}", f"--scenario={scenario}", f"--ships={ships}",
           f"--speed={speed}", f"--ticks={ticks}"]
    completed = subprocess.run(cmd, cwd=ROOT, capture_output=True,
                               text=True, errors="replace", timeout=timeout,
                               check=False)
    output = completed.stdout + "\n" + completed.stderr
    results = [json.loads(line[len("FLEET_BENCH "):])
               for line in output.splitlines()
               if line.startswith("FLEET_BENCH ")]
    if (completed.returncode or len(results) != 1 or
            "SCRIPT ERROR:" in output or "Assertion failed" in output):
        raise RuntimeError(f"Benchmark failed: {cmd}\n{output[-6000:]}")
    result = results[0]
    for key, expected in (("scenario", scenario), ("initial_ships", ships),
                          ("speed", speed), ("seed", seed), ("ticks", ticks)):
        if result.get(key) != expected:
            raise RuntimeError(f"Unexpected {key}: {result.get(key)!r} != {expected!r}")
    if float(result["tick_ms"]["p50_ms"]) <= 0:
        raise RuntimeError("Benchmark returned nonpositive frame duration")
    result["estimated_simulated_substeps_per_second"] = round(
        1000.0 * speed / float(result["tick_ms"]["p50_ms"]), 2)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--ships", default="500,1000")
    parser.add_argument("--scenarios", default="battle,logistics")
    parser.add_argument("--speeds", default="1,5")
    parser.add_argument("--seeds", default="827")
    parser.add_argument("--ticks", type=int, default=100)
    parser.add_argument("--timeout", type=int, default=180, help="Seconds per case")
    parser.add_argument("--output", type=Path, help="Write raw benchmark JSON here")
    args = parser.parse_args()
    try:
        ships = options(args.ships, int)
        scenarios = options(args.scenarios, str,
                            {"battle", "logistics", "swarm", "dispersed", "peaceful_mixed"})
        speeds = options(args.speeds, int, {1, 5})
        seeds = options(args.seeds, int)
        if min(ships) < 1 or args.ticks < 1 or args.timeout < 1:
            raise ValueError("Ship counts, ticks and timeout must be positive")
    except ValueError as exc:
        parser.error(str(exc))
    reports = []
    print("scenario       ships seed speed  p50-ms  p95-ms  "
          "combat-p50  move-p50  sim-steps/s", flush=True)
    for scenario, size, seed, speed in itertools.product(
            scenarios, ships, seeds, speeds):
        try:
            record = run(args.godot, seed, scenario, size, speed,
                         args.ticks, args.timeout)
        except (OSError, subprocess.TimeoutExpired, ValueError, KeyError,
                RuntimeError) as exc:
            print(f"FAIL {scenario}/{size}/{seed}/{speed}: {exc}", file=sys.stderr)
            return 1
        reports.append(record)
        phases = record.get("phases_ms", {})
        combat = float(phases.get(PHASES[0], {}).get("p50_ms", 0.0))
        movement = float(phases.get(PHASES[1], {}).get("p50_ms", 0.0))
        print(f"{scenario:<14} {size:>5} {seed:>4} {speed:>5} "
              f"{float(record['tick_ms']['p50_ms']):>8.2f} "
              f"{float(record['tick_ms']['p95_ms']):>8.2f} "
              f"{combat:>11.2f} {movement:>9.2f} "
              f"{record['estimated_simulated_substeps_per_second']:>12.2f}",
              flush=True)
    if args.output:
        report = {"created_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                  "purpose": "informational headless CPU simulation baseline",
                  "cases": reports}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n",
                               encoding="utf-8")
        print(f"Wrote {len(reports)} cases to {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
