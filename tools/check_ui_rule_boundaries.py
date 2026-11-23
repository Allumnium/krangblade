#!/usr/bin/env python3
"""Reject calls from the match presentation controller to private simulation helpers."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
source = root / "scripts" / "match.gd"
violations = []
for lineno, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
    if re.search(r"\bECONOMY\._[A-Za-z][A-Za-z0-9_]*\s*\(", line):
        violations.append(f"{source.relative_to(root)}:{lineno}: {line.strip()}")
if violations:
    print("Use public EconomyRules query methods from client presentation:\n" + "\n".join(violations), file=sys.stderr)
    sys.exit(1)
print("PASS: match.gd uses public EconomyRules queries")
