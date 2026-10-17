#!/usr/bin/env python3
"""List the days missing from exchange/ between its oldest and newest file.

Usage: missing_days.py [EXCHANGE_DIR]   (default: exchange)
Prints one YYYY-MM-DD per line; exits 1 if any day is missing, 0 otherwise.
"""
import sys
from datetime import date, timedelta
from pathlib import Path


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "exchange")
    present = set()
    for f in root.glob("[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9].json"):
        present.add(date(int(f.parts[-3]), int(f.parts[-2]), int(f.stem)))
    if not present:
        sys.exit(f"No exchange files found under {root}")

    day, last = min(present), max(present)
    missing = []
    while day <= last:
        if day not in present:
            missing.append(day)
        day += timedelta(days=1)

    for d in missing:
        print(d)
    print(f"{len(present)} days present, {len(missing)} missing "
          f"({min(present)}..{last})", file=sys.stderr)
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
