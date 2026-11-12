#!/bin/sh
set -eu
umask 077

if [ -f /etc/backup.env ]; then
  . /etc/backup.env
fi

PREFIX="${PREFIX:-}"

EXCL=""
for p in ${EXCLUDES:-}; do
  EXCL="$EXCL --exclude=$p"
done

CONTAINERS=""
for c in ${STOP_CONTAINERS:-}; do
  CONTAINERS="$CONTAINERS ${PREFIX:+$PREFIX-}$c"
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
  if [ -n "$CONTAINERS" ]; then
    if ! docker start $CONTAINERS; then
      rc=1
    fi
  fi
  if [ "$rc" -eq 0 ]; then
    log "Backup finished"; push up Archived
  else
    log "Backup ERROR"; push down Error
  fi
}

trap finish EXIT
trap 'exit 1' HUP INT TERM

if [ -n "$CONTAINERS" ]; then
  docker stop $CONTAINERS
fi

for dir in /volumes/*/; do
  name=$(basename "$dir")
  file="/backup/${PREFIX:+${PREFIX}_}$name.tgz"
  log "Backing up $name"
  tar czf "$file" $EXCL -C "$dir" .
  if [ -n "${BACKUP_OWNER:-}" ]; then
    chown "$BACKUP_OWNER" "$file"
  fi
done
