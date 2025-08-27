#!/bin/sh

# Usage: fetch.sh TODAY_URL HISTORICAL_URL [YYYY-MM-DD]
set -eu

TODAY_URL="${1:-}"
HISTORICAL_URL="${2:-}"
INPUT_DATE="${3:-}"

if [ -z "${TODAY_URL}" ] || [ -z "${HISTORICAL_URL}" ]; then
  echo "Usage: $0 TODAY_URL HISTORICAL_URL [YYYY-MM-DD]" >&2
  exit 1
fi

# Determine current date in UTC and the effective date to use
if TODAY_UTC="$(date -u +%Y-%m-%d 2>/dev/null)"; then
  :
else
  TODAY_UTC="$(date -u +%Y-%m-%d)"
fi
DATE="${INPUT_DATE:-$TODAY_UTC}"

# Precompute target path from requested date and skip if already present
YEAR_DIR="$(echo "$DATE" | cut -d- -f1)"
MONTH_DIR="$(echo "$DATE" | cut -d- -f2)"
DAY_FILE="$(echo "$DATE" | cut -d- -f3)"
if [ -z "$YEAR_DIR" ] || [ -z "$MONTH_DIR" ] || [ -z "$DAY_FILE" ]; then
  echo "Invalid DATE format. Expected YYYY-MM-DD" >&2
  exit 1
fi
TARGET_PRE="exchange/$YEAR_DIR/$MONTH_DIR/$DAY_FILE.json"
if [ -f "$TARGET_PRE" ]; then
  echo "Data for $YEAR_DIR/$MONTH_DIR/$DAY_FILE already exists at $TARGET_PRE. Skipping fetch."
  exit 0
fi

# Choose the URL to fetch based on the date
if [ "$DATE" = "$TODAY_UTC" ]; then
  FETCH_URL="$TODAY_URL"
else
  # Build historical URL supporting {DATE} or %s placeholders; otherwise append date as query param
  if echo "$HISTORICAL_URL" | grep -q '{DATE}'; then
    FETCH_URL="$(printf "%s" "$HISTORICAL_URL" | sed "s/{DATE}/$DATE/g")"
  elif echo "$HISTORICAL_URL" | grep -q '%s'; then
    # shellcheck disable=SC2059
    FETCH_URL="$(printf "$HISTORICAL_URL" "$DATE")"
  else
    if echo "$HISTORICAL_URL" | grep -q '?'; then
      FETCH_URL="${HISTORICAL_URL}&date=${DATE}"
    else
      FETCH_URL="${HISTORICAL_URL}?date=${DATE}"
    fi
  fi
fi

# Fetch data from the chosen URL
if ! SOURCE_DATA="$(curl -fsSL "$FETCH_URL")"; then
  echo "Failed to fetch data from ${FETCH_URL}" >&2
  exit 1
fi

# Extract timestamp from response
TIMESTAMP="$(echo "${SOURCE_DATA}" | jq -r '.timestamp')"
if [ -z "$TIMESTAMP" ] || [ "$TIMESTAMP" = "null" ]; then
  echo "Missing timestamp in response" >&2
  exit 1
fi

# Compute date components from timestamp (UTC)
# Try GNU date (-d) first; fall back to BSD/macOS date (-r)
if YEAR="$(date -u -d "@$TIMESTAMP" +%Y 2>/dev/null)"; then
  MONTH="$(date -u -d "@$TIMESTAMP" +%m)"
  DAY="$(date -u -d "@$TIMESTAMP" +%d)"
else
  YEAR="$(date -u -r "$TIMESTAMP" +%Y)"
  MONTH="$(date -u -r "$TIMESTAMP" +%m)"
  DAY="$(date -u -r "$TIMESTAMP" +%d)"
fi

if [ -z "$YEAR" ] || [ -z "$MONTH" ] || [ -z "$DAY" ]; then
  echo "Missing YEAR or MONTH or DAY" >&2
  exit 1
fi

echo "Creating file for $YEAR/$MONTH/$DAY"

# Prepare target path
mkdir -p "$YEAR/$MONTH"
TARGET="exchange/$YEAR/$MONTH/$DAY.json"

# Transform the JSON to {from: <source>, to: {<CURRENCY>: rate, ...}}
TRANSFORMED_DATA="$(echo "${SOURCE_DATA}" | jq '(.source) as $src | {from: $src, to: (.quotes | with_entries(.key |= ltrimstr($src)))}')"

echo "$TRANSFORMED_DATA" > "$TARGET"
