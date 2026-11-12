#!/bin/sh
set -eu
umask 077

if [ -f /etc/backup.env ]; then
  . /etc/backup.env
fi

PROJECT="${PROJECT:-}"
WANTED="${STOP_SERVICES:-}"
SERVICES=""

EXCL=""
for p in ${EXCLUDES:-}; do
  EXCL="$EXCL --exclude=$p"
done

log() {
  echo "[$(date '+%F %T')] $*"
}
push() {
  if [ -n "${PUSH_URL:-}" ]; then
    curl -fsS -o /dev/null --retry 10 --retry-delay 3 --retry-all-errors --connect-timeout 1 \
      "$PUSH_URL?status=$1&msg=$2" || log "Push to Kuma failed"
  fi
}
finish() {
  rc=$?
  if [ -n "$SERVICES" ]; then
    log "Starting services: $SERVICES"
    if ! docker compose -p "$PROJECT" start $SERVICES; then
      rc=1
    fi
  fi
  if [ "$rc" -eq 0 ]; then
    log "Backup finished"; push up Archived
  else
    log "Backup ERROR"; push down Error
  fi
}

if [ -n "$WANTED" ] && [ -z "$PROJECT" ]; then
  log "PROJECT required to stop services"
  exit 1
fi

trap finish EXIT
trap 'exit 1' HUP INT TERM

if [ -n "$WANTED" ]; then
  RUNNING=$(docker compose -p "$PROJECT" ps --services --status running)
  TO_STOP=""
  for s in $WANTED; do
    if printf '%s\n' "$RUNNING" | grep -qx "$s"; then
      TO_STOP="$TO_STOP $s"
    else
      log "Service $s not running, skipping"
    fi
  done
  if [ -n "$TO_STOP" ]; then
    SERVICES="$TO_STOP"
    log "Stopping services: $SERVICES"
    docker compose -p "$PROJECT" stop $SERVICES
  fi
fi

for dir in /volumes/*/; do
  name=$(basename "$dir")
  file="/backup/${PROJECT:+${PROJECT}_}$name.tgz"
  log "Backing up $name"
  tar czf "$file" $EXCL -C "$dir" .
  if [ -n "${BACKUP_OWNER:-}" ]; then
    chown "$BACKUP_OWNER" "$file"
  fi
done
