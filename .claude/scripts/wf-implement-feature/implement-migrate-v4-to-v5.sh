#!/usr/bin/env bash
# implement-migrate-v4-to-v5.sh — Migrate v4 flat layout → v5 system-grouped layout.
#
# v4 layout:
#   .mc-data/work/wf-implement-feature/{feature_slug}/sessions/{id}/...
#   .mc-data/work/wf-implement-feature/.locks/{feature_slug}.lock
#   .mc-data/work/wf-implement-feature/.cache/{module_slug}/...
#
# v5 layout:
#   .mc-data/work/wf-implement-feature/{system_slug}/{feature_slug}/sessions/{id}/...
#   .mc-data/work/wf-implement-feature/{system_slug}/{feature_slug}/current.txt
#   .mc-data/work/wf-implement-feature/.locks/{system_slug}/{feature_slug}.lock
#   .mc-data/work/wf-implement-feature/.cache/{system_slug}/{module_slug}/...
#   .mc-data/work/wf-implement-feature/_orphan/{feature_slug}/...   (no system match)
#   .mc-data/work/wf-implement-feature/.layout-version → "5"
#
# Behavior:
#   - Idempotent: chạy lần 2 = no-op (check .layout-version marker)
#   - Migration steps:
#     1. Per feature_slug at root → derive_system_slug từ registry
#     2. mkdir parent → mv flat dir vào parent
#     3. Migrate .locks: per lock file → derive system → move
#     4. Invalidate .cache (cheaper rebuild than complex cache migration)
#     5. Best-effort enrich .history/implementations-index.jsonl với field "system"
#     6. Write .layout-version = "5"
#   - Orphans: feature không tìm thấy system_id trong registry → moved to _orphan/
#   - Active locks safety: skip nếu lock file là active session (PID alive)
#
# Usage:
#   bash implement-migrate-v4-to-v5.sh [--dry-run] [--base-dir=<path>] [--registry=<path>]
#
# Args:
#   --dry-run        Print actions không thực hiện
#   --base-dir=...   Override $FEATURE_BASE_DIR
#   --registry=...   Override $REGISTRY_PATH
#   --force          Bỏ qua active lock check
#
# Exit codes:
#   0 = success (kể cả 0 features migrated)
#   1 = error (registry missing + có features cần migrate, hoặc IO error)
#   2 = aborted (active lock detected, --force chưa set)

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=implement-common.sh
source "$SCRIPTS_DIR/implement-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

DRY_RUN=false
FORCE=false
BASE_DIR="$FEATURE_BASE_DIR"
REGISTRY="$REGISTRY_PATH"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --force) FORCE=true ;;
    --base-dir=*) BASE_DIR="${arg#*=}" ;;
    --registry=*) REGISTRY="${arg#*=}" ;;
    *) log_warn "Unknown arg: $arg" ;;
  esac
done

# Local path bindings (constants từ common.sh là readonly — dùng local vars khi --base-dir override)
MIG_LOCKS_DIR="$BASE_DIR/.locks"
MIG_CACHE_DIR="$BASE_DIR/.cache"
MIG_HISTORY_DIR="$BASE_DIR/.history"

if [[ ! -d "$BASE_DIR" ]]; then
  log_info "Base dir không tồn tại — không có gì để migrate: $BASE_DIR"
  exit 0
fi

# ─── Idempotency check ───────────────────────────────────────

LAYOUT_MARKER="$BASE_DIR/.layout-version"
CURRENT_VERSION=""
if [[ -f "$LAYOUT_MARKER" ]]; then
  CURRENT_VERSION=$(cat "$LAYOUT_MARKER" 2>/dev/null | tr -d '\r\n' | head -c 4)
fi

if [[ "$CURRENT_VERSION" == "5" ]]; then
  log_info "Layout đã ở v5 — không cần migrate (no-op)"
  exit 0
fi

# ─── Detect candidates: top-level dirs là feature_slug v4 ────

# Feature slug ở v4 = subdir trực tiếp dưới $BASE_DIR (không bắt đầu bằng "."), chứa sessions/
# hoặc *.json/*.md flat (v3 chưa migrate).

CANDIDATES=()
ORPHANS=()

while IFS= read -r -d '' featdir; do
  fname=$(basename "$featdir")
  # Skip dotfiles, _orphan, hoặc subdir đã là system (chứa nested feature dirs)
  case "$fname" in
    .*|_orphan) continue ;;
  esac
  # Heuristic: v4 feature dir có ít nhất 1 dấu hiệu:
  # - sessions/ subdir
  # - flat *.json/*.md files
  # - current.txt (pointer file v4)
  # - archived/ subdir (sessions cũ đã archive)
  if [[ -d "$featdir/sessions" ]] \
     || [[ -d "$featdir/archived" ]] \
     || [[ -f "$featdir/current.txt" ]] \
     || compgen -G "$featdir/*.json" >/dev/null 2>&1 \
     || compgen -G "$featdir/*.md" >/dev/null 2>&1; then
    CANDIDATES+=("$fname")
  fi
done < <(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  log_info "Không có feature directories ở dạng v4 — đánh dấu layout = v5"
  if ! $DRY_RUN; then
    echo "5" > "$LAYOUT_MARKER"
  fi
  exit 0
fi

log_info "Tìm thấy ${#CANDIDATES[@]} feature directories cần migrate"

# ─── Active lock safety check ────────────────────────────────

if ! $FORCE && [[ -d "$MIG_LOCKS_DIR" ]]; then
  ACTIVE_LOCKS=()
  for lockfile in "$MIG_LOCKS_DIR"/*.lock; do
    [[ -f "$lockfile" ]] || continue
    if has_jq; then
      lock_pid=$(jq -r '.pid // empty' "$lockfile" 2>/dev/null)
      lock_host=$(jq -r '.host // empty' "$lockfile" 2>/dev/null)
      current_host=$(hostname 2>/dev/null || echo "${HOSTNAME:-unknown}")
      if [[ -n "$lock_pid" && "$lock_host" == "$current_host" ]] && kill -0 "$lock_pid" 2>/dev/null; then
        ACTIVE_LOCKS+=("$(basename "$lockfile")")
      fi
    fi
  done

  if [[ ${#ACTIVE_LOCKS[@]} -gt 0 ]]; then
    log_error "Phát hiện ${#ACTIVE_LOCKS[@]} active lock(s):"
    for l in "${ACTIVE_LOCKS[@]}"; do
      log_error "  - $l"
    done
    log_error "Đang có session implement đang chạy. Đợi xong rồi chạy lại,"
    log_error "hoặc dùng --force (cẩn thận: sẽ migrate cả khi đang chạy)."
    exit 2
  fi
fi

# ─── Registry availability check ─────────────────────────────

if [[ ! -f "$REGISTRY" ]]; then
  log_warn "Registry không tồn tại: $REGISTRY"
  log_warn "Tất cả features sẽ vào _orphan/ vì không có nguồn để derive system_slug"
fi

# ─── Build slug→system map (1 jq call thay vì N²) ────────────

declare -A SLUG_TO_SYSTEM
declare -A FEATID_TO_SYSTEM
declare -A SYSTEM_ID_TO_SLUG

if [[ -f "$REGISTRY" ]] && has_jq; then
  log_debug "Building registry lookup maps..."
  # systems: id → slug
  while IFS=$'\t' read -r sid sslug; do
    [[ -z "$sid" ]] && continue
    [[ -z "$sslug" || "$sslug" == "null" ]] && sslug=$(echo "$sid" | sed -E 's/^SYS-//I' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    SYSTEM_ID_TO_SLUG["$sid"]="$sslug"
  done < <(jq -r '.systems[]? | [.id, (.slug // "")] | @tsv' "$REGISTRY" 2>/dev/null)

  # features: by FEAT-ID + by normalized name
  while IFS=$'\t' read -r fid fname fsysid; do
    [[ -z "$fsysid" || "$fsysid" == "null" ]] && continue
    sys_slug_resolved="${SYSTEM_ID_TO_SLUG[$fsysid]:-}"
    [[ -z "$sys_slug_resolved" ]] && sys_slug_resolved=$(echo "$fsysid" | sed -E 's/^SYS-//I' | tr '[:upper:]' '[:lower:]' | tr '_' '-')

    [[ -n "$fid" ]] && FEATID_TO_SYSTEM["$fid"]="$sys_slug_resolved"
    if [[ -n "$fname" ]]; then
      norm=$(normalize_slug "$fname")
      [[ -n "$norm" ]] && SLUG_TO_SYSTEM["$norm"]="$sys_slug_resolved"
    fi
  done < <(jq -r '.features[]? | [.id, .name, .system_id] | @tsv' "$REGISTRY" 2>/dev/null)

  log_debug "Registry maps built: ${#FEATID_TO_SYSTEM[@]} FEAT-IDs, ${#SLUG_TO_SYSTEM[@]} slugs, ${#SYSTEM_ID_TO_SLUG[@]} systems"
fi

# Lookup function dùng map (O(1))
lookup_system_slug() {
  local input="$1"
  # FEAT-ID match
  if [[ "$input" =~ ^FEAT-[A-Z0-9-]+$ ]]; then
    [[ -n "${FEATID_TO_SYSTEM[$input]:-}" ]] && { echo "${FEATID_TO_SYSTEM[$input]}"; return 0; }
  fi
  # Slug match
  [[ -n "${SLUG_TO_SYSTEM[$input]:-}" ]] && { echo "${SLUG_TO_SYSTEM[$input]}"; return 0; }
  echo "$UNKNOWN_SYSTEM_SLUG"
}

# ─── Migration: feature directories ──────────────────────────

MIGRATED_COUNT=0
ORPHAN_COUNT=0

for slug in "${CANDIDATES[@]}"; do
  src="$BASE_DIR/$slug"
  sys_slug=$(lookup_system_slug "$slug")

  if [[ "$sys_slug" == "$UNKNOWN_SYSTEM_SLUG" || -z "$sys_slug" ]]; then
    target_parent="$BASE_DIR/_orphan"
    ORPHANS+=("$slug")
  else
    target_parent="$BASE_DIR/$sys_slug"
  fi
  target="$target_parent/$slug"

  if [[ -d "$target" ]]; then
    log_warn "Target đã tồn tại, skip: $target"
    continue
  fi

  if $DRY_RUN; then
    log_info "[DRY-RUN] mv $src → $target"
  else
    mkdir -p "$target_parent"
    if mv "$src" "$target"; then
      log_info "Migrated: $slug → $(basename "$target_parent")/$slug"
      MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
      [[ "$target_parent" == "$BASE_DIR/_orphan" ]] && ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    else
      log_error "Failed to mv $src → $target"
    fi
  fi
done

# ─── Migration: locks (.locks/{slug}.lock → .locks/{system}/{slug}.lock) ─

if [[ -d "$MIG_LOCKS_DIR" ]]; then
  LOCKS_MIGRATED=0
  for lockfile in "$MIG_LOCKS_DIR"/*.lock; do
    [[ -f "$lockfile" ]] || continue
    lock_basename=$(basename "$lockfile" .lock)
    sys_slug=$(lookup_system_slug "$lock_basename")
    [[ -z "$sys_slug" || "$sys_slug" == "$UNKNOWN_SYSTEM_SLUG" ]] && sys_slug="_orphan"

    target_lock="$MIG_LOCKS_DIR/$sys_slug/$lock_basename.lock"
    if [[ -f "$target_lock" ]]; then
      log_warn "Lock target tồn tại, skip: $target_lock"
      continue
    fi

    if $DRY_RUN; then
      log_info "[DRY-RUN] mv $lockfile → $target_lock"
    else
      mkdir -p "$(dirname "$target_lock")"
      mv "$lockfile" "$target_lock" && LOCKS_MIGRATED=$((LOCKS_MIGRATED + 1))
    fi
  done
  [[ $LOCKS_MIGRATED -gt 0 ]] && log_info "Migrated $LOCKS_MIGRATED lock files"
fi

# ─── Migration: cache (invalidate — re-build sẽ tự động sau scan tiếp theo) ─

if [[ -d "$MIG_CACHE_DIR" ]]; then
  # Đếm files trong cache
  CACHE_FILE_COUNT=$(find "$MIG_CACHE_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$CACHE_FILE_COUNT" -gt 0 ]]; then
    if $DRY_RUN; then
      log_info "[DRY-RUN] Invalidate cache: rm -rf $MIG_CACHE_DIR ($CACHE_FILE_COUNT files)"
    else
      rm -rf "$MIG_CACHE_DIR"
      log_info "Invalidated pattern cache ($CACHE_FILE_COUNT files) — sẽ tự rebuild ở scan tiếp theo"
    fi
  fi
fi

# ─── Enrich .history/implementations-index.jsonl với field system ────

HISTORY_FILE="$MIG_HISTORY_DIR/implementations-index.jsonl"
if [[ -f "$HISTORY_FILE" ]] && has_jq; then
  if $DRY_RUN; then
    LINES=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
    log_info "[DRY-RUN] Enrich $LINES history entries với field 'system'"
  else
    TMP=$(mktemp)
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      slug=$(echo "$line" | jq -r '.feature_slug // empty' 2>/dev/null)
      if [[ -n "$slug" ]]; then
        sys=$(lookup_system_slug "$slug")
        echo "$line" | jq -c --arg sys "$sys" '. + {system: $sys}' 2>/dev/null >> "$TMP" || echo "$line" >> "$TMP"
      else
        echo "$line" >> "$TMP"
      fi
    done < "$HISTORY_FILE"
    mv "$TMP" "$HISTORY_FILE"
    log_info "Enriched history index với field 'system'"
  fi
fi

# ─── Write layout marker ─────────────────────────────────────

if ! $DRY_RUN; then
  echo "5" > "$LAYOUT_MARKER"
fi

# ─── Summary ─────────────────────────────────────────────────

if $DRY_RUN; then
  log_info "[DRY-RUN] Done. Re-run without --dry-run to apply."
  log_info "Sẽ migrate: ${#CANDIDATES[@]} features (${#ORPHANS[@]} orphans)"
else
  log_info "Migration v4 → v5 complete."
  log_info "  Features migrated: $MIGRATED_COUNT (orphans: $ORPHAN_COUNT)"
  if [[ $ORPHAN_COUNT -gt 0 ]]; then
    log_warn "  Orphan features (không tìm thấy system trong registry):"
    for o in "${ORPHANS[@]}"; do
      log_warn "    - $o → _orphan/$o"
    done
    log_warn "  Để fix: thêm feature vào registry hoặc move thủ công vào correct system folder"
  fi
fi

exit 0
