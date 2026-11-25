#!/bin/sh
# zap2xml-js entrypoint - runs jef/zap2xml (MIT) in a loop, atomically, with Unraid conventions.
set -u

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*"; }

: "${OUTPUT_FILE:=/data/xmltv.xml}"
: "${LINEUP_ID:=USA-lineupId-DEFAULT}"
: "${POSTAL_CODE:=30309}"
: "${COUNTRY:=USA}"
: "${TIMESPAN:=6}"
: "${PREF:=}"
: "${USER_AGENT:=}"
: "${SLEEP_TIME:=21600}"
: "${RUN_ONCE:=false}"
: "${PUID:=99}"
: "${PGID:=100}"
: "${UMASK:=022}"
umask "$UMASK"

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

if [ "$(id -u)" = "0" ]; then
  chown -R "$PUID:$PGID" "$OUTPUT_DIR" 2>/dev/null || true
  RUNAS="su-exec $PUID:$PGID"
else
  RUNAS=""
fi

FINAL="$OUTPUT_FILE"          # where the guide belongs
TMP="$OUTPUT_DIR/.xmltv.tmp"  # what the grabber writes (upstream prefers the env var over argv)

write_status() {
  _ok=$1; _next=$2; _bytes=0
  [ -f "$FINAL" ] && _bytes=$(wc -c < "$FINAL" | tr -d ' ')
  cat > "$OUTPUT_DIR/status.json.tmp" <<EOF
{"state":"$_ok","last_run":"$(date -u '+%Y-%m-%dT%H:%M:%SZ')","last_run_epoch":$(date +%s),"output":"$FINAL","bytes":$_bytes,"next_run_in_seconds":$_next,"hours_per_run":$TIMESPAN}
EOF
  mv -f "$OUTPUT_DIR/status.json.tmp" "$OUTPUT_DIR/status.json"
}

while :; do
  START=$(date +%s)
  write_status running 0
  log "Starting grab (lineup=$LINEUP_ID, postal=$POSTAL_CODE, ${TIMESPAN}h)"

  ARGS="--lineupId=$LINEUP_ID --postalCode=$POSTAL_CODE --country=$COUNTRY --timespan=$TIMESPAN"
  [ -n "$PREF" ] && ARGS="$ARGS --pref=$PREF"
  [ -n "$USER_AGENT" ] && ARGS="$ARGS --userAgent=$USER_AGENT"

  # upstream reads OUTPUT_FILE from the environment before argv, so point it at the temp file
  # shellcheck disable=SC2086
  env OUTPUT_FILE="$TMP" $RUNAS node /app/dist/index.js $ARGS
  RC=$?

  if [ "$RC" -eq 0 ] && [ -s "$TMP" ] && head -c 200 "$TMP" | grep -q "<tv "; then
    mv -f "$TMP" "$FINAL"
    CH=$(grep -c '<channel id=' "$FINAL" 2>/dev/null || echo 0)
    PG=$(grep -c '<programme ' "$FINAL" 2>/dev/null || echo 0)
    log "Guide ready: $CH channels, $PG programmes, $(du -h "$FINAL" | cut -f1) in $(( $(date +%s) - START ))s"
    STATE=ok
  else
    rm -f "$TMP"
    log "ERROR: grab produced no usable guide (exit $RC) - previous file left untouched"
    STATE=error
  fi

  ELAPSED=$(( $(date +%s) - START ))
  if [ "$RUN_ONCE" = "true" ]; then
    write_status "$STATE" 0
    log "RUN_ONCE=true - exiting"
    [ "$STATE" = "ok" ] && exit 0 || exit 1
  fi
  NEXT=$(( SLEEP_TIME - ELAPSED ))
  [ "$NEXT" -lt 60 ] && NEXT=60
  write_status "$STATE" "$NEXT"
  log "Next run in ${NEXT}s"
  sleep "$NEXT"
done