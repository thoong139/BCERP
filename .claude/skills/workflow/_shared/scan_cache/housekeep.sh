#!/usr/bin/env bash
# housekeep.sh — Scheduled cleanup cho scan cache (ADR-19 TTL 14 ngay).
#
# Chay dinh ky (weekly) de prune cache entries cu hon 14 ngay,
# tranh cache swell + giu hit-rate on dinh.
#
# Su dung:
#   ./housekeep.sh                              # default: 14 days, cache o .mc-data/cache/wf-fix-bugs/probes/
#   ./housekeep.sh --cache-root=<dir>           # custom cache root
#   ./housekeep.sh --older-than=<days>          # override TTL
#
# CI cron (weekly):
#   0 2 * * 0  cd <repo> && .claude/skills/workflow/_shared/scan_cache/housekeep.sh
#
# Tham chieu: ADR-19 Scan Cache, ADR-22 rule 4.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Repo root = 6 levels up: _shared/scan_cache → _shared → workflow → skills → .claude → <repo>
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

CACHE_ROOT="$REPO_ROOT/.mc-data/cache/wf-fix-bugs/probes"
OLDER_THAN=14

for arg in "$@"; do
  case "$arg" in
    --cache-root=*) CACHE_ROOT="${arg#*=}" ;;
    --older-than=*) OLDER_THAN="${arg#*=}" ;;
    -h|--help)
      sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if [[ ! -d "$CACHE_ROOT" ]]; then
  echo "[INFO] Cache root chua ton tai — khong co gi de prune: $CACHE_ROOT"
  exit 0
fi

echo "[INFO] Prune cache entries older than $OLDER_THAN days in $CACHE_ROOT"
cd "$REPO_ROOT/.claude/skills/workflow"
# cache_store clear yeu cau format "<n>d" (vi du 14d) — khop voi CLI schema cua cache_store.py
python3 -m _shared.scan_cache.cache_store clear \
  --cache-root "$CACHE_ROOT" \
  --older-than "${OLDER_THAN}d"
