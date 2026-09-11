#!/usr/bin/env bash
# Migrate wf-verify-sync flat layout (v2) to sessions/ layout (v3)
# Usage: bash vs-migrate-flat-to-sessions.sh [--dry-run]
# Idempotent: re-run safe. verify-sync-history.md is NEVER migrated (stays top-level).
# Called from: session-init.md SI.2 (auto) OR manually as standalone migration tool.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

DRY_RUN=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

WORK_ROOT=".mc-data/work/wf-verify-sync"
LEGACY_BASE="$SESSIONS_DIR/_legacy-v2"

# Flat files to migrate (verify-sync-history.md stays at top-level — NOT in this list)
FLAT_CANDIDATES=(
  "verify-sync-status.json"
  "checkpoint.json"
  "ui-coverage-report.md"
  "ui-snapshot.json"
  "phase-summary.md"
)

# ---------------------------------------------------------------------------
# Collect flat files present in WORK_ROOT
# ---------------------------------------------------------------------------
FOUND=()
for f in "${FLAT_CANDIDATES[@]}"; do
  [[ -f "$WORK_ROOT/$f" ]] && FOUND+=("$f")
done

if [[ ${#FOUND[@]} -eq 0 ]]; then
  info "No flat layout files found in $WORK_ROOT — migration not needed."
  echo "{\"status\":\"skipped\",\"reason\":\"no_flat_files\",\"work_root\":\"$WORK_ROOT\"}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Check if sessions/ already exists
# ---------------------------------------------------------------------------
if [[ -d "$SESSIONS_DIR" ]]; then
  # sessions/ exists AND we still have flat files → archive anyway (log warning)
  warn "sessions/ already exists but flat files also present — archiving residual flat files."
fi

# ---------------------------------------------------------------------------
# Determine archive destination
# ---------------------------------------------------------------------------
TS=$(date +%s 2>/dev/null || python3 -c "import time; print(int(time.time()))")
LEGACY_DIR="$LEGACY_BASE/$TS"

# ---------------------------------------------------------------------------
# Dry-run report
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" == "true" ]]; then
  info "[DRY RUN] Would migrate ${#FOUND[@]} flat file(s) from $WORK_ROOT → $LEGACY_DIR"
  for f in "${FOUND[@]}"; do
    info "[DRY RUN]   $WORK_ROOT/$f → $LEGACY_DIR/$f"
  done
  info "[DRY RUN] verify-sync-history.md stays at $WORK_ROOT/ (not migrated)"
  echo "{\"status\":\"dry_run\",\"files_found\":${#FOUND[@]},\"destination\":\"$LEGACY_DIR\",\"files\":$(printf '%s\n' "${FOUND[@]}" | jq -Rc '[.]' | jq -cs 'add')}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Execute migration (F22: transactional with manifest + rollback)
# ---------------------------------------------------------------------------
mkdir -p "$LEGACY_DIR"

# Write manifest BEFORE any moves (F22)
MANIFEST_FILE="$LEGACY_DIR/.migration-manifest.json"
printf '%s\n' "${FOUND[@]}" | jq -Rc '[.]' | jq -cs '{files: add, timestamp: "'"$TS"'", status: "in_progress"}' > "$MANIFEST_FILE"

MIGRATED=()
ERRORS=()

# Phase 1: Execute all moves
for f in "${FOUND[@]}"; do
  SRC="$WORK_ROOT/$f"
  DST="$LEGACY_DIR/$f"
  if mv "$SRC" "$DST" 2>/dev/null; then
    MIGRATED+=("$f")
    info "Migrated: $SRC → $DST"
  else
    ERRORS+=("$f")
    warn "Failed to migrate: $SRC"
    break  # Stop on first error — prevent partial state
  fi
done

# Phase 2: Rollback on partial failure (F22)
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  warn "Migration failed with ${#ERRORS[@]} error(s). Rolling back ${#MIGRATED[@]} moved files..."
  ROLLBACK_OK=true
  for f in "${MIGRATED[@]}"; do
    SRC="$LEGACY_DIR/$f"
    DST="$WORK_ROOT/$f"
    if mv "$SRC" "$DST" 2>/dev/null; then
      info "Rolled back: $SRC → $DST"
    else
      warn "Failed to rollback: $SRC — file remains in $LEGACY_DIR"
      ROLLBACK_OK=false
    fi
  done
  # Update manifest with rollback status
  if [[ "$ROLLBACK_OK" == "true" ]]; then
    RESULT_STATUS="rolled_back"
  else
    RESULT_STATUS="rollback_partial"
  fi
  jq --arg status "$RESULT_STATUS" --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
     '.status = $status | .completed_at = $ts' "$MANIFEST_FILE" > "${MANIFEST_FILE}.tmp" && \
     mv "${MANIFEST_FILE}.tmp" "$MANIFEST_FILE"
else
  # ---------------------------------------------------------------------------
  # Phase 3: Success — ensure sessions/ + _index/ exist for new layout
  # ---------------------------------------------------------------------------
  ensure_dirs
  RESULT_STATUS="migrated"
  # Update manifest with success status
  jq --arg status "$RESULT_STATUS" --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
     '.status = $status | .completed_at = $ts' "$MANIFEST_FILE" > "${MANIFEST_FILE}.tmp" && \
     mv "${MANIFEST_FILE}.tmp" "$MANIFEST_FILE"
  info "Migration complete — ${#MIGRATED[@]} file(s) archived to $LEGACY_DIR"
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
MIGRATED_JSON=$(printf '%s\n' "${MIGRATED[@]}" | jq -Rc '[.]' | jq -cs 'add // []')
ERROR_JSON=$(printf '%s\n' "${ERRORS[@]+"${ERRORS[@]}"}" | jq -Rc '[.]' | jq -cs 'add // []')

echo "{\"status\":\"$RESULT_STATUS\",\"migrated\":$MIGRATED_JSON,\"errors\":$ERROR_JSON,\"destination\":\"$LEGACY_DIR\",\"manifest\":\"$MANIFEST_FILE\"}"
