#!/usr/bin/env python3
"""Parse every tracked GDScript after importing the project."""
import argparse
from pathlib import Path
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot executable or path")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    paths = subprocess.check_output(
        ["git", "ls-files", "-z", "--", "*.gd"], cwd=root
    ).decode("utf-8").split("\0")
    scripts = sorted(path for path in paths if path)
    if not scripts:
        print("No tracked GDScript files found.", file=sys.stderr)
        return 1
    failed = []
    for path in scripts:
        print(f"Checking {path}", flush=True)
        try:
            result = subprocess.run(
                [args.godot, "--headless", "--path", str(root),
                 "--check-only", "--script", f"res://{path}"],
                cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, errors="replace", timeout=90, check=False,
            )
        except FileNotFoundError:
            print(f"Godot executable not found: {args.godot}", file=sys.stderr)
            return 1
        except subprocess.TimeoutExpired:
            print(f"Parser timed out: {path}", file=sys.stderr)
            failed.append(path)
            continue
        print(result.stdout, end="", flush=True)
        if result.returncode != 0 or any(
            marker in result.stdout for marker in
            ("SCRIPT ERROR:", "Parse Error:", "Failed to load script")
        ):
            failed.append(path)
    print(f"Checked {len(scripts)} scripts; {len(failed)} failed.")
    if failed:
        print("\n".join(failed), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
