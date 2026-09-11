#!/usr/bin/env bash
# implement-migrate-v3-to-v4.sh — Migrate flat $FEATURE_SLUG/*.{json,md} → sessions/{date}-migrated/.
# Sprint 1 — Backward compat cho data v3.x.
#
# Behavior:
#   - Idempotent: chạy lần 2 không fail
#   - Move (KHÔNG xóa) flat files vào sessions/{YYYY-MM-DD}-migrated/
#   - Tạo current.txt pointer trỏ đến migrated session
#   - Skip nếu feature dir đã có sessions/ subdir (đã migrate trước đó)
#   - Skip non-feature dirs: .history, .cache, .locks (start with .)
#
# Usage:
#   bash implement-migrate-v3-to-v4.sh [--dry-run] [--base-dir=<path>]
#
# Args:
#   --dry-run       Print actions không thực hiện
#   --base-dir=...  Override $FEATURE_BASE_DIR (default: .mc-data/work/wf-implement-feature)
#
# Exit codes:
#   0 = success (kể cả 0 features migrated)
#   1 = error (e.g. permission denied)

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=implement-common.sh
source "$SCRIPTS_DIR/implement-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

DRY_RUN=false
BASE_DIR="$FEATURE_BASE_DIR"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --base-dir=*) BASE_DIR="${arg#*=}" ;;
    *) log_warn "Unknown arg: $arg" ;;
  esac
done

if [[ ! -d "$BASE_DIR" ]]; then
  log_info "No base dir to migrate: $BASE_DIR (nothing to do)"
  exit 0
fi

# Migrated session ID — fixed naming so re-runs idempotent
MIGRATED_SUFFIX="-migrated"
TODAY=$(date -u +%Y-%m-%d)
MIGRATED_SESSION="${TODAY}${MIGRATED_SUFFIX}"

MIGRATED_COUNT=0
SKIPPED_COUNT=0

for FEATURE_DIR in "$BASE_DIR"/*/; do
  # Skip if FEATURE_DIR is not a directory (no matches → glob unchanged)
  [[ -d "$FEATURE_DIR" ]] || continue

  FEATURE_NAME=$(basename "$FEATURE_DIR")

  # Skip non-feature dirs
  if [[ "$FEATURE_NAME" =~ ^\..+ ]]; then
    log_debug "Skip non-feature dir: $FEATURE_NAME"
    continue
  fi

  # Already migrated? (sessions/ exists)
  if [[ -d "$FEATURE_DIR/sessions" ]]; then
    log_debug "Already migrated: $FEATURE_NAME (has sessions/)"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  # Check has flat data
  HAS_FLAT_DATA=false
  for ext in json md; do
    if compgen -G "$FEATURE_DIR*.$ext" >/dev/null 2>&1; then
      HAS_FLAT_DATA=true
      break
    fi
  done

  if [[ "$HAS_FLAT_DATA" == "false" ]]; then
    log_debug "No flat data in $FEATURE_NAME — skip"
    continue
  fi

  TARGET_SESSION_DIR="$FEATURE_DIR/sessions/$MIGRATED_SESSION"
  POINTER_FILE="$FEATURE_DIR/current.txt"

  if $DRY_RUN; then
    log_info "[DRY-RUN] Would migrate: $FEATURE_NAME → sessions/$MIGRATED_SESSION/"
    log_info "[DRY-RUN]   Files:"
    for f in "$FEATURE_DIR"*.json "$FEATURE_DIR"*.md; do
      [[ -f "$f" ]] && log_info "[DRY-RUN]     $(basename "$f")"
    done
  else
    mkdir -p "$TARGET_SESSION_DIR"

    # Move flat files
    MOVED=0
    for f in "$FEATURE_DIR"*.json "$FEATURE_DIR"*.md; do
      [[ -f "$f" ]] || continue
      mv "$f" "$TARGET_SESSION_DIR/" || {
        log_error "Failed to move $f → $TARGET_SESSION_DIR/"
        continue
      }
      MOVED=$((MOVED + 1))
    done

    # Write pointer
    echo "sessions/$MIGRATED_SESSION" > "$POINTER_FILE"

    log_info "Migrated $FEATURE_NAME ($MOVED files) → sessions/$MIGRATED_SESSION/"
    MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
  fi
done

if $DRY_RUN; then
  log_info "[DRY-RUN] Done. Re-run without --dry-run to apply."
else
  log_info "Migration complete: $MIGRATED_COUNT features migrated, $SKIPPED_COUNT already migrated/skipped"
fi

exit 0
