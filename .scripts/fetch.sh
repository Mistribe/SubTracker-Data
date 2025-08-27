#!/bin/sh
# Usage: fetch.sh TODAY_URL HISTORICAL_URL [YYYY-MM-DD]
set -eu

usage() {
  echo "Usage: $0 TODAY_URL HISTORICAL_URL [YYYY-MM-DD]" >&2
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

  # Validate DATE format
  case "$DATE" in
    ????-??-??) : ;;
    *) die "Invalid DATE format. Expected YYYY-MM-DD" ;;
  esac

  # Precompute target path from requested date and skip if already present
  YEAR_DIR="$(echo "$DATE" | cut -d- -f1)"
  MONTH_DIR="$(echo "$DATE" | cut -d- -f2)"
  DAY_FILE="$(echo "$DATE" | cut -d- -f3)"
  TARGET_PRE="exchange/$YEAR_DIR/$MONTH_DIR/$DAY_FILE.json"
  if [ -f "$TARGET_PRE" ]; then
    log "Data for $YEAR_DIR/$MONTH_DIR/$DAY_FILE already exists at $TARGET_PRE. Skipping fetch."
    exit 0
  fi

  # Choose the URL to fetch based on the date
  if [ "$DATE" = "$TODAY_UTC" ]; then
    FETCH_URL="$TODAY_URL"
  else
    FETCH_URL="$(build_historical_url "$HISTORICAL_URL" "$DATE")"
  fi

  # Fetch data from the chosen URL
  if ! SOURCE_DATA="$(fetch_json "$FETCH_URL")"; then
    die "Failed to fetch data from ${FETCH_URL}"
  fi

  # Extract timestamp from response
  TIMESTAMP="$(echo "${SOURCE_DATA}" | jq -r '.timestamp')"
  [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" != "null" ] || die "Missing timestamp in response"

  # Compute date components from timestamp (UTC)
  set -- $(ts_to_ymd "$TIMESTAMP")
  YEAR="$1"
  MONTH="$2"
  DAY="$3"

  log "Creating file for $YEAR/$MONTH/$DAY"

  # Prepare target path
  mkdir -p "exchange/$YEAR/$MONTH"
  TARGET="exchange/$YEAR/$MONTH/$DAY.json"

  # Transform and write
  echo "${SOURCE_DATA}" | transform_quotes > "$TARGET"
}

main "$@"
