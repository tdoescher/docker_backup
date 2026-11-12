FROM docker:cli

RUN apk add --no-cache tar curl tzdata

COPY scripts/backup.sh /usr/local/bin/backup
COPY scripts/entrypoint.sh /entrypoint

RUN chmod +x /usr/local/bin/backup /entrypoint && mkdir -p /volumes /backup

ENTRYPOINT ["/entrypoint"]
