#!/bin/sh
# Usage: backfill-year.sh TODAY_URL HISTORICAL_URL YEAR
# Fetches every missing day of YEAR, month by month, via fetch.sh (works on macOS,
# unlike backfill.sh which needs GNU date). Existing days are skipped, so a rerun
# resumes after a failure; fetch.sh exits on the first failed day (quota, no data).
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

[ "$#" -eq 3 ] || { echo "Usage: $0 TODAY_URL HISTORICAL_URL YEAR" >&2; exit 1; }
case "$3" in ????) ;; *) echo "YEAR must be 4 digits" >&2; exit 1 ;; esac

for m in 12 11 10 09 08 07 06 05 04 03 02 01; do
  # months after the current one are rejected by fetch.sh as future; skip them
  [ "$3-$m" \> "$(date -u +%Y-%m)" ] && continue
  echo "== $3-$m" >&2
  sh "$SCRIPT_DIR/fetch.sh" "$1" "$2" "$3-$m"
done
