#!/bin/sh
# Healthcheck: output exists, looks like XMLTV, and is not older than two refresh cycles.
set -u
: "${OUTPUT_FILE:=/data/xmltv.xml}"
: "${SLEEP_TIME:=21600}"

[ -s "$OUTPUT_FILE" ] || { echo "missing: $OUTPUT_FILE"; exit 1; }
head -c 200 "$OUTPUT_FILE" | grep -q "<tv " || { echo "not XMLTV: $OUTPUT_FILE"; exit 1; }

MAX_AGE=$(( SLEEP_TIME * 2 + 1800 ))
NOW=$(date +%s)
MTIME=$(date -r "$OUTPUT_FILE" +%s 2>/dev/null || stat -c %Y "$OUTPUT_FILE")
AGE=$(( NOW - MTIME ))
[ "$AGE" -gt "$MAX_AGE" ] && { echo "stale: ${AGE}s (limit ${MAX_AGE}s)"; exit 1; }
echo "ok: ${AGE}s old"
exit 0