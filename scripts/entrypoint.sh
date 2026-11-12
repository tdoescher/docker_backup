#!/bin/sh
set -eu

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

export -p > /etc/backup.env

SCHEDULE="${CRON_SCHEDULE:-0 3 * * *}"

echo "$SCHEDULE sh /usr/local/bin/backup > /proc/1/fd/1 2>&1" > /etc/crontabs/root
echo "Backup schedule: $SCHEDULE"

exec crond -f -l 8
