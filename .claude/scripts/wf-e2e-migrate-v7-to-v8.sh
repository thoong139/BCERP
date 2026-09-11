#!/usr/bin/env bash
# wf-e2e-migrate-v7-to-v8.sh — Migrate v7 sessions → v8 schema compat
# Usage: ./wf-e2e-migrate-v7-to-v8.sh [--dry-run]
set -euo pipefail

DRY_RUN="${1:-}"
SESSIONS_DIR=".mc-data/work/wf-e2e-verify/sessions"

[ ! -d "$SESSIONS_DIR" ] && echo "No sessions dir found: $SESSIONS_DIR" && exit 0

count=0
for session_dir in "$SESSIONS_DIR"/*/; do
  status_file="$session_dir/e2e-status.json"
  [ ! -f "$status_file" ] && continue

  # Check if v7 (no f0_infra field)
  if ! jq -e '.f0_infra' "$status_file" > /dev/null 2>&1; then
    count=$((count + 1))
    echo "v7 session detected: $session_dir"

    if [ "$DRY_RUN" != "--dry-run" ]; then
      # Add v8 fields with legacy status
      jq '. + {
        "f0_infra": {"status": "legacy_skipped", "note": "v7 session migrated"},
        "f0a_finding": {"status": "legacy_skipped", "note": "v7 session migrated"},
        "f0b_seed": {"status": "legacy_skipped", "note": "v7 session migrated"},
        "f6_f5_loops": {
          "critical": {"count": 0, "cap": 5},
          "high": {"count": 0, "cap": 4},
          "medium": {"count": 0, "cap": 3},
          "low": {"count": 0, "cap": 2},
          "high_from_f7_used": false
        },
        "_schema_version": "v8.0.0",
        "_migrated_from": "v7.0.0",
        "_migrated_at": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
      }' "$status_file" > "$status_file.v8tmp" && mv "$status_file.v8tmp" "$status_file"
      echo "  → Migrated: $session_dir"
    fi
  fi
done

echo ""
echo "Found $count v7 sessions."
[ "$DRY_RUN" = "--dry-run" ] && echo "(dry-run: no changes made)"
