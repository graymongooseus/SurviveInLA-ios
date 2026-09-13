#!/bin/sh
set -eu
cd "$(dirname "$0")"
umask 077
mkdir -p backups
temporary=$(mktemp backups/.backup.XXXXXX)
trap 'rm -f "$temporary"' EXIT HUP INT TERM
docker compose exec -T api python backup.py > "$temporary"
target="backups/leaderboard-$(date -u +%Y%m%dT%H%M%SZ)-$$.sqlite3"
mv "$temporary" "$target"
printf '%s\n' "$target"
