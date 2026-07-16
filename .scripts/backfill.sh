#!/bin/sh
# Usage: backfill.sh TODAY_URL HISTORICAL_URL [COUNT]
# Walks backward day-by-day from the oldest existing exchange/ date,
# fetching COUNT (default 60) additional historical days via fetch.sh.
# Stops early if a fetch fails (e.g. API exhausted / no data that far back).
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
FETCH_SH="$SCRIPT_DIR/fetch.sh"

usage() {
  echo "Usage: $0 TODAY_URL HISTORICAL_URL [COUNT]" >&2
}

die() {
  echo "$@" >&2
  exit 1
}

log() {
  echo "$@" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found in PATH"
}

# Find the oldest existing date under exchange/, echoes YYYY-MM-DD or nothing
find_oldest_date() {
  [ -d exchange ] || return 0

  y="$(ls exchange 2>/dev/null | sort | head -n1)"
  [ -n "$y" ] || return 0

  m="$(ls "exchange/$y" 2>/dev/null | sort | head -n1)"
  [ -n "$m" ] || return 0

  d_file="$(ls "exchange/$y/$m" 2>/dev/null | sort | head -n1)"
  [ -n "$d_file" ] || return 0

  d="$(basename "$d_file" .json)"
  printf "%s-%s-%s" "$y" "$m" "$d"
}

main() {
  TODAY_URL="${1:-}"
  HISTORICAL_URL="${2:-}"
  COUNT="${3:-60}"

  if [ -z "${TODAY_URL}" ] || [ -z "${HISTORICAL_URL}" ]; then
    usage
    exit 1
  fi

  require_cmd date
  require_cmd sort
  require_cmd basename
  [ -x "$FETCH_SH" ] || require_cmd sh

  oldest="$(find_oldest_date)"
  if [ -z "$oldest" ]; then
    log "No existing data found under exchange/. Nothing to backfill from."
    exit 0
  fi
  log "Oldest existing date: $oldest. Backfilling up to $COUNT day(s) before it."

  i=1
  fetched_any=0
  while [ "$i" -le "$COUNT" ]; do
    target_date="$(date -u -d "$oldest -$i day" +%Y-%m-%d)" || die "Failed to compute date $i day(s) before $oldest"

    log "Backfilling $target_date ..."
    if "$FETCH_SH" "$TODAY_URL" "$HISTORICAL_URL" "$target_date"; then
      fetched_any=1
    else
      log "Fetch failed for $target_date. Stopping backfill (likely no data further back or API exhausted)."
      break
    fi

    i=$((i + 1))
  done

  if [ "$fetched_any" -eq 1 ]; then
    log "Backfill complete."
  else
    log "Backfill made no progress."
  fi
}

main "$@"
