#!/bin/sh
# Usage: fetch.sh TODAY_URL HISTORICAL_URL [YYYY-MM or YYYY-MM-DD]
set -eu

usage() {
  echo "Usage: $0 TODAY_URL HISTORICAL_URL [YYYY-MM or YYYY-MM-DD]" >&2
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

today_utc() {
  date -u +%Y-%m-%d
}

# Build historical URL supporting {DATE} or %s placeholders; otherwise append date as query param
build_historical_url() {
  base="$1"
  date_in="$2"
  case "$base" in
    *"{DATE}"*)
      printf "%s" "$base" | sed "s/{DATE}/$date_in/g"
      ;;
    *"%s"*)
      # shellcheck disable=SC2059
      printf "$base" "$date_in"
      ;;
    *\?*)
      printf "%s&date=%s" "$base" "$date_in"
      ;;
    *)
      printf "%s?date=%s" "$base" "$date_in"
      ;;
  esac
}

# Convert UNIX timestamp to YYYY MM DD (UTC). Tries GNU date first, then BSD/macOS.
ts_to_ymd() {
  ts="$1"
  if y="$(date -u -d "@$ts" +%Y 2>/dev/null)"; then
    m="$(date -u -d "@$ts" +%m)"
    d="$(date -u -d "@$ts" +%d)"
  else
    y="$(date -u -r "$ts" +%Y)"
    m="$(date -u -r "$ts" +%m)"
    d="$(date -u -r "$ts" +%d)"
  fi
  [ -n "$y" ] && [ -n "$m" ] && [ -n "$d" ] || die "Missing YEAR or MONTH or DAY"
  printf "%s %s %s" "$y" "$m" "$d"
}

fetch_json() {
  url="$1"
  curl -fsSL "$url" || return 1
}

# Transform the JSON to {from: <source>, to: {<CURRENCY>: rate, ...}}
transform_quotes() {
  jq '(.source) as $src | {from: $src, to: (.quotes | with_entries(.key |= ltrimstr($src)))}'
}

# Leap year check
is_leap() {
  y="$1"
  if [ $((y % 400)) -eq 0 ] || { [ $((y % 4)) -eq 0 ] && [ $((y % 100)) -ne 0 ]; }; then
    return 0
  fi
  return 1
}

# Days in month (1-12), echoes 28..31
days_in_month() {
  y="$1"
  m="$2"
  case "$m" in
    01|03|05|07|08|10|12) echo 31 ;;
    04|06|09|11) echo 30 ;;
    02)
      if is_leap "$y"; then echo 29; else echo 28; fi
      ;;
    *)
      die "Invalid month '$m'"
      ;;
  esac
}

# Process one YYYY-MM-DD date: skip existing, choose URL, fetch, transform, and write
process_date() {
  date_in="$1"
  yreq="$(echo "$date_in" | cut -d- -f1)"
  mreq="$(echo "$date_in" | cut -d- -f2)"
  dreq="$(echo "$date_in" | cut -d- -f3)"
  target_pre="exchange/$yreq/$mreq/$dreq.json"

  if [ -f "$target_pre" ]; then
    log "Data for $yreq/$mreq/$dreq already exists at $target_pre. Skipping fetch."
    return 0
  fi

  if [ "$date_in" = "$TODAY_UTC" ]; then
    fetch_url="$TODAY_URL"
  else
    fetch_url="$(build_historical_url "$HISTORICAL_URL" "$date_in")"
  fi

  if ! source_data="$(fetch_json "$fetch_url")"; then
    die "Failed to fetch data from ${fetch_url}"
  fi

  timestamp="$(echo "${source_data}" | jq -r '.timestamp')"
  [ -n "$timestamp" ] && [ "$timestamp" != "null" ] || die "Missing timestamp in response"

  set -- $(ts_to_ymd "$timestamp")
  y="$1"
  m="$2"
  d="$3"

  log "Creating file for $y/$m/$d"

  mkdir -p "exchange/$y/$m"
  target="exchange/$y/$m/$d.json"

  echo "${source_data}" | transform_quotes > "$target"
}

main() {
  TODAY_URL="${1:-}"
  HISTORICAL_URL="${2:-}"
  INPUT_DATE="${3:-}"

  if [ -z "${TODAY_URL}" ] || [ -z "${HISTORICAL_URL}" ]; then
    usage
    exit 1
  fi

  # Verify required tools exist early
  require_cmd curl
  require_cmd jq
  require_cmd date
  require_cmd sed
  require_cmd cut
  require_cmd mkdir

  # Determine current date in UTC and the effective date to use
  TODAY_UTC="$(today_utc)"
  DATE="${INPUT_DATE:-$TODAY_UTC}"

  # Validate DATE format (YYYY-MM or YYYY-MM-DD)
  case "$DATE" in
    ????-??-??) MODE="day" ;;
    ????-??) MODE="month" ;;
    *) die "Invalid DATE format. Expected YYYY-MM or YYYY-MM-DD" ;;
  esac

  if [ "$MODE" = "day" ]; then
    # Reject future date
    if [ "$DATE" \> "$TODAY_UTC" ]; then
      die "Requested date '$DATE' is in the future (today is $TODAY_UTC)"
    fi
    process_date "$DATE"
    exit 0
  fi

  # Month mode
  Y="$(echo "$DATE" | cut -d- -f1)"
  M="$(echo "$DATE" | cut -d- -f2)"

  # Reject future month
  TY="$(echo "$TODAY_UTC" | cut -d- -f1)"
  TM="$(echo "$TODAY_UTC" | cut -d- -f2)"
  if [ "$Y-$M" \> "$TY-$TM" ]; then
    die "Requested month '$Y-$M' is in the future (current month is $TY-$TM)"
  fi

  # Determine last day to fetch (truncate to today if current month)
  if [ "$Y" = "$TY" ] && [ "$M" = "$TM" ]; then
    last="$(echo "$TODAY_UTC" | cut -d- -f3)"
  else
    last="$(days_in_month "$Y" "$M")"
  fi

  i=1
  while [ "$i" -le "$last" ]; do
    D="$(printf "%02d" "$i")"
    # Skip if already present; otherwise process the specific day
    TARGET_PRE="exchange/$Y/$M/$D.json"
    if [ -f "$TARGET_PRE" ]; then
      log "Data for $Y/$M/$D already exists at $TARGET_PRE. Skipping fetch."
    else
      process_date "$Y-$M-$D"
    fi
    i=$((i + 1))
  done
}

main "$@"
