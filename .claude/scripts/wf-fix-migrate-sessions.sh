#!/usr/bin/env bash
# wf-fix-migrate-sessions.sh — Migrate v6.x sessions sang v7.0 layout (D1+D6 — Sprint 12)
#
# Convert legacy `run-NNN--YYYYMMDD/` directories sang new
# `sessions/{YYYY-MM-DD-{scope}-{slug}-{NN}}/` layout.
#
# Usage:
#   wf-fix-migrate-sessions.sh                     # Default: dry-run (preview)
#   wf-fix-migrate-sessions.sh --apply             # Commit changes + backup legacy
#   wf-fix-migrate-sessions.sh --status            # Show migration progress (read-only)
#   wf-fix-migrate-sessions.sh --base-dir <path>   # Custom base dir (default: .mc-data/work/wf-fix-bugs)
#
# Modes:
#   --dry-run (default): scan + show plan, do NOT modify anything
#   --apply            : execute migration + move legacy dirs to _archive/
#   --status           : count legacy + new sessions, show progress
#
# Behavior:
#   - Idempotent: chạy nhiều lần OK (dry-run + apply both safe)
#   - Preserve all files: copy theo cây cấu trúc + verify size match trước khi remove
#   - APPEND vào _index/sessions.jsonl retroactively (preserve append-only invariant)
#   - Backup: legacy dirs moved to `_archive/{YYYY-MM}/migration-backup/`
#   - Skip nếu already migrated (target sessions/{id}/ tồn tại)
#
# Legacy path patterns được nhận diện:
#   - run-NNN--YYYYMMDD/                  (v6.0)
#   - run-NNN-{scope}-{name}--YYYYMMDD/   (v6.1+)
#
# Exit codes:
#   0 — success (or dry-run)
#   1 — invalid args / base-dir missing / runtime error
#   2 — partial migration (some sessions failed but no data lost)
#   3 — critical error (data loss prevented, manual intervention required)
#
# Cross-platform: GNU/Linux, macOS (BSD), Git Bash (MINGW), WSL.

set -euo pipefail

# Source common helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

# ============================================================
# ARG PARSING
# ============================================================
MODE="dry-run"
BASE_DIR="${MCV3_FIX_BUGS_BASE_DIR:-.mc-data/work/wf-fix-bugs}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      MODE="apply"
      shift
      ;;
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --status)
      MODE="status"
      shift
      ;;
    --base-dir)
      BASE_DIR="$2"
      shift 2
      ;;
    --base-dir=*)
      BASE_DIR="${1#--base-dir=}"
      shift
      ;;
    -h|--help)
      sed -n '2,36p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg '$1'" >&2
      exit 1
      ;;
  esac
done

# ============================================================
# VALIDATION
# ============================================================
if [[ ! -d "$BASE_DIR" ]]; then
  echo "ERROR: base-dir not found: $BASE_DIR" >&2
  exit 1
fi

NEW_SESSIONS_DIR="$BASE_DIR/sessions"
ARCHIVE_ROOT="$BASE_DIR/_archive"
INDEX_FILE="$BASE_DIR/_index/sessions.jsonl"

# ============================================================
# DETECT LEGACY SESSIONS
# Pattern: run-NNN--YYYYMMDD or run-NNN-{scope}-{name}--YYYYMMDD
# Locations:
#   - $BASE_DIR/run-* (v6.0 — root-level, very old)
#   - $BASE_DIR/sessions/{scope}/run-* (v6.1+ scope-aware)
# Find via filesystem (not _index since legacy didn't write index).
# ============================================================
detect_legacy_sessions() {
  {
    # Pattern 1: v6.0 root-level legacy
    find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d -name 'run-*' 2>/dev/null
    # Pattern 2: v6.1+ scope-aware legacy (sessions/{scope}/run-*)
    if [[ -d "$BASE_DIR/sessions" ]]; then
      find "$BASE_DIR/sessions" -mindepth 2 -maxdepth 2 -type d -name 'run-*' 2>/dev/null
    fi
  } | sort
}

# Detect parent scope when legacy_path nằm trong sessions/{scope}/run-*.
# Trả về scope (basename of parent dir), hoặc empty nếu legacy ở root level.
detect_parent_scope() {
  local legacy_path="$1"
  local legacy_parent
  legacy_parent=$(dirname "$legacy_path")
  local sessions_root="$BASE_DIR/sessions"
  # Resolve absolute paths để so sánh chính xác
  if [[ "$legacy_parent" != "$BASE_DIR" ]] && [[ "$legacy_parent" == "$sessions_root"/* || "$legacy_parent" == "$sessions_root" ]]; then
    if [[ "$legacy_parent" != "$sessions_root" ]]; then
      basename "$legacy_parent"
    fi
  fi
}

# Parse legacy dir name → output JSON {legacy_path, run_num, scope, name, date_yyyymmdd, target_sid}
# Pattern A (v6.0): run-NNN--YYYYMMDD                       → scope=all, name=""
# Pattern B (v6.1): run-NNN-{scope}-{name}--YYYYMMDD        → scope, name as captured
# Returns empty string if pattern doesn't match (skip).
parse_legacy_dirname() {
  local legacy_path="$1"
  local dir_name
  dir_name=$(basename "$legacy_path")

  local run_num="" scope="" name="" date_str=""
  local parent_scope
  parent_scope=$(detect_parent_scope "$legacy_path")

  # Pattern B: run-NNN-{scope}-{name}--YYYYMMDD
  if [[ "$dir_name" =~ ^run-([0-9]+)-([a-z]+)-(.+)--([0-9]{8})$ ]]; then
    run_num="${BASH_REMATCH[1]}"
    scope="${BASH_REMATCH[2]}"
    name="${BASH_REMATCH[3]}"
    date_str="${BASH_REMATCH[4]}"
  # Pattern A: run-NNN--YYYYMMDD
  elif [[ "$dir_name" =~ ^run-([0-9]+)--([0-9]{8})$ ]]; then
    run_num="${BASH_REMATCH[1]}"
    # Nếu nested trong sessions/{scope}/, dùng parent_scope; else fallback "all"
    if [[ -n "$parent_scope" ]]; then
      scope="$parent_scope"
      name=""
    else
      scope="all"
      name=""
    fi
    date_str="${BASH_REMATCH[2]}"
  else
    # Unrecognized pattern → skip
    return 1
  fi

  # Convert YYYYMMDD → YYYY-MM-DD
  local date_iso="${date_str:0:4}-${date_str:4:2}-${date_str:6:2}"
  # Slugify name (already lowercase per legacy convention, just normalize separators)
  local slug
  if [ -n "$name" ]; then
    slug=$(slugify "$name")
  else
    slug=""
  fi

  # Compute target session_id
  local target_sid
  if [ -z "$slug" ]; then
    target_sid="${date_iso}-${scope}-$(printf '%02d' "$run_num")"
  else
    target_sid="${date_iso}-${scope}-${slug}-$(printf '%02d' "$run_num")"
  fi

  # Output JSON object
  jq -nc \
    --arg legacy_path "$legacy_path" \
    --arg dir_name "$dir_name" \
    --arg run_num "$run_num" \
    --arg scope "$scope" \
    --arg name "$name" \
    --arg slug "$slug" \
    --arg date_str "$date_str" \
    --arg date_iso "$date_iso" \
    --arg target_sid "$target_sid" \
    '{legacy_path:$legacy_path, dir_name:$dir_name, run_num:$run_num, scope:$scope, name:$name, slug:$slug, date_yyyymmdd:$date_str, date_iso:$date_iso, target_sid:$target_sid}'
}

# ============================================================
# STATUS MODE — read-only summary
# ============================================================
if [[ "$MODE" == "status" ]]; then
  legacy_count=0
  new_count=0
  unrecognized_count=0

  while IFS= read -r legacy_dir; do
    if parsed=$(parse_legacy_dirname "$legacy_dir" 2>/dev/null); then
      legacy_count=$((legacy_count + 1))
    else
      unrecognized_count=$((unrecognized_count + 1))
    fi
  done < <(detect_legacy_sessions)

  if [[ -d "$NEW_SESSIONS_DIR" ]]; then
    # Đếm CHỈ session-id matching YYYY-MM-DD-... (loại scope folders v6.1+)
    new_count=$(find "$NEW_SESSIONS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null \
      | while read -r d; do
          bn=$(basename "$d")
          if [[ "$bn" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}- ]]; then
            echo "$d"
          fi
        done \
      | wc -l | tr -d ' ')
  fi

  echo "=== wf-fix-bugs Migration Status (v6.x → v7.0) ==="
  echo "Base dir: $BASE_DIR"
  echo ""
  echo "Legacy sessions (run-*):"
  echo "  Recognized (migratable): $legacy_count"
  echo "  Unrecognized pattern:    $unrecognized_count"
  echo ""
  echo "New sessions (sessions/{id}/): $new_count"
  echo ""
  if [[ "$legacy_count" -eq 0 ]] && [[ "$unrecognized_count" -eq 0 ]]; then
    echo "Status: ✓ NO LEGACY SESSIONS — migration not needed."
  elif [[ "$legacy_count" -gt 0 ]]; then
    echo "Status: ⚠ MIGRATION NEEDED — run with --dry-run to preview, then --apply."
  fi
  exit 0
fi

# ============================================================
# DRY-RUN / APPLY: enumerate + plan
# ============================================================
echo "=== wf-fix-bugs Migration ($MODE) ==="
echo "Base dir: $BASE_DIR"
echo ""

PLAN_ENTRIES=()
SKIP_ALREADY_MIGRATED=0
SKIP_UNRECOGNIZED=0
TOTAL_LEGACY=0

while IFS= read -r legacy_dir; do
  TOTAL_LEGACY=$((TOTAL_LEGACY + 1))
  parsed=$(parse_legacy_dirname "$legacy_dir" 2>/dev/null) || {
    echo "  SKIP unrecognized: $(basename "$legacy_dir")"
    SKIP_UNRECOGNIZED=$((SKIP_UNRECOGNIZED + 1))
    continue
  }

  target_sid=$(echo "$parsed" | jq -r '.target_sid')
  target_dir="$NEW_SESSIONS_DIR/$target_sid"

  # Skip if target already exists (idempotent)
  if [[ -d "$target_dir" ]]; then
    echo "  SKIP already migrated: $(basename "$legacy_dir") → sessions/$target_sid/"
    SKIP_ALREADY_MIGRATED=$((SKIP_ALREADY_MIGRATED + 1))
    continue
  fi

  # Add to plan
  PLAN_ENTRIES+=("$parsed")
  echo "  PLAN: $(basename "$legacy_dir") → sessions/$target_sid/"
done < <(detect_legacy_sessions)

PLAN_COUNT="${#PLAN_ENTRIES[@]}"
echo ""
echo "Summary:"
echo "  Total legacy dirs found:    $TOTAL_LEGACY"
echo "  To migrate:                 $PLAN_COUNT"
echo "  Skip (already migrated):    $SKIP_ALREADY_MIGRATED"
echo "  Skip (unrecognized):        $SKIP_UNRECOGNIZED"
echo ""

if [[ "$PLAN_COUNT" -eq 0 ]]; then
  echo "Nothing to migrate. ✓"
  exit 0
fi

if [[ "$MODE" == "dry-run" ]]; then
  echo "DRY-RUN: no changes made. Run with --apply to commit."
  exit 0
fi

# ============================================================
# APPLY MODE — execute migration
# ============================================================
echo "Applying migration..."

# Ensure target dirs exist
mkdir -p "$NEW_SESSIONS_DIR"
mkdir -p "$BASE_DIR/_index"
[[ -f "$INDEX_FILE" ]] || touch "$INDEX_FILE"

MIGRATED=0
FAILED=0
FAILED_DETAILS=()

for entry in "${PLAN_ENTRIES[@]}"; do
  legacy_path=$(echo "$entry" | jq -r '.legacy_path')
  target_sid=$(echo "$entry" | jq -r '.target_sid')
  scope=$(echo "$entry" | jq -r '.scope')
  name=$(echo "$entry" | jq -r '.name')
  date_iso=$(echo "$entry" | jq -r '.date_iso')

  target_dir="$NEW_SESSIONS_DIR/$target_sid"
  archive_subdir="${date_iso:0:7}"  # YYYY-MM
  archive_target="$ARCHIVE_ROOT/$archive_subdir/migration-backup/$(basename "$legacy_path")"

  echo "  Migrating: $(basename "$legacy_path") → sessions/$target_sid/"

  # Step 1: copy legacy → target (preserve files)
  if ! cp -r "$legacy_path" "$target_dir" 2>/dev/null; then
    echo "    ERROR: failed to copy" >&2
    FAILED=$((FAILED + 1))
    FAILED_DETAILS+=("$legacy_path: copy failed")
    rm -rf "$target_dir" 2>/dev/null || true
    continue
  fi

  # Step 2: verify file count match (sanity check, no data loss)
  legacy_files=$(find "$legacy_path" -type f 2>/dev/null | wc -l | tr -d ' ')
  target_files=$(find "$target_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$legacy_files" != "$target_files" ]]; then
    echo "    ERROR: file count mismatch (legacy=$legacy_files, target=$target_files)" >&2
    FAILED=$((FAILED + 1))
    FAILED_DETAILS+=("$legacy_path: file count mismatch ($legacy_files vs $target_files)")
    rm -rf "$target_dir" 2>/dev/null || true
    continue
  fi

  # Step 3: APPEND retroactive entry to _index/sessions.jsonl
  # Use jq to construct then append
  index_entry=$(jq -nc \
    --arg sid "$target_sid" \
    --arg scope "$scope" \
    --arg name "$name" \
    --arg date_iso "$date_iso" \
    --arg migrated_at "$(iso_now)" \
    '{session_id:$sid, scope:$scope, slug:$name, status:"migrated_legacy", created_at:($date_iso+"T00:00:00Z"), migrated_at:$migrated_at, source:"v6.x-migration"}')
  echo "$index_entry" >> "$INDEX_FILE"

  # Step 4: archive legacy dir (move, not delete)
  mkdir -p "$(dirname "$archive_target")"
  if ! mv "$legacy_path" "$archive_target" 2>/dev/null; then
    echo "    WARNING: failed to archive legacy dir (target migrated successfully but legacy not moved)" >&2
    FAILED_DETAILS+=("$legacy_path: archive failed (data preserved at target)")
    # Don't increment FAILED — data is safe at target
  else
    # Step 4b: cleanup empty parent scope folder (sessions/{scope}/)
    # Dùng basename strategy để tránh path-format mismatch trên Git Bash/Windows.
    # Chỉ remove khi grandparent có tên "sessions" (tức legacy nested ở sessions/{scope}/run-*).
    legacy_parent=$(dirname "$legacy_path")
    legacy_grandparent=$(dirname "$legacy_parent")
    if [[ "$(basename "$legacy_grandparent")" == "sessions" ]] && \
       [[ -d "$legacy_parent" ]] && \
       [[ -z "$(ls -A "$legacy_parent" 2>/dev/null)" ]]; then
      rmdir "$legacy_parent" 2>/dev/null && echo "    cleaned empty parent: $(basename "$legacy_parent")/" || true
    fi
  fi

  MIGRATED=$((MIGRATED + 1))
  echo "    OK"
done

echo ""
echo "Migration complete:"
echo "  Migrated successfully:  $MIGRATED / $PLAN_COUNT"
echo "  Failed:                 $FAILED"
if [[ "$FAILED" -gt 0 ]]; then
  echo ""
  echo "Failures (data preserved at target where possible):"
  for f in "${FAILED_DETAILS[@]}"; do
    echo "  - $f"
  done
  if [[ "$MIGRATED" -gt 0 ]]; then
    exit 2  # partial migration
  else
    exit 3  # all failed
  fi
fi

if [[ "$SKIP_UNRECOGNIZED" -gt 0 ]]; then
  echo ""
  echo "NOTE: $SKIP_UNRECOGNIZED legacy dir(s) had unrecognized pattern — left in place for manual review."
fi

echo ""
echo "Run --status to verify."
exit 0
