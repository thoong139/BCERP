#!/usr/bin/env bash
# legacy-scan-staleness.sh — Kiem tra staleness khi resume wf-legacy-scan
# Usage: bash .claude/scripts/legacy-scan-staleness.sh <project-path> <ledger-json>
#
# Input:  project directory, ledger.json
# Output: staleness report to stdout (JSON format)
#
# WHY deterministic: staleness la phep so sanh timestamp — khong can AI.
# Chay nhanh truoc khi quyet dinh co nen resume hay rescan.
#
# Recommendation logic:
#   <10%  stale → continue        (resume an toan)
#   10-30% stale → partial_rescan (re-process stale items only)
#   >30%  stale → full_rescan     (E013 warning, re-inventory toan bo)
#
# Phase G refactor (v5.0):
# - Source legacy-scan-common.sh for atomic_write_json + validate_json
# - Configurable head caps qua env vars
# - Output to stdout giữ nguyên (backward-compat với consumers đọc stdout)

# Shared library
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="legacy-scan-staleness"
# shellcheck source=./legacy-scan-common.sh
source "$SCRIPTS_DIR/legacy-scan-common.sh"

set -euo pipefail 2>/dev/null || set -e

PROJECT_PATH="${1:-.}"
LEDGER_JSON="${2:-.mc-data/work/legacy-scan/ledger.json}"

# Configurable caps (v5.0) — env vars override
STALENESS_MODIFIED_CAP="${LEGACY_SCAN_STALE_MODIFIED_CAP:-1000}"
STALENESS_NEW_CAP="${LEGACY_SCAN_STALE_NEW_CAP:-500}"

# ---------------------------------------------------------------------------
# Helpers (local overrides for v4.1 log format)
# ---------------------------------------------------------------------------

log()  { echo "[staleness] $*" >&2; }
warn() { echo "[staleness][WARN] $*" >&2; }

normalize_path() { echo "$1" | tr '\\' '/'; }

# Lay last_modified cua file theo epoch seconds
file_mtime_epoch() {
    local f="$1"
    # GNU stat (Linux, Git Bash)
    stat -c '%Y' "$f" 2>/dev/null && return
    # BSD/macOS stat
    stat -f '%m' "$f" 2>/dev/null && return
    echo "0"
}

# Chuyen ISO 8601 timestamp thanh epoch seconds
# Input: "2026-03-10T14:00:00Z" hoac "2026-03-10 14:00:00"
iso_to_epoch() {
    local ts="$1"
    # Normalize: bo Z suffix, thay T bang khoang trang
    ts="${ts%Z}"
    ts="${ts/T/ }"

    # date -d (GNU / Git Bash)
    if date -d "$ts" '+%s' 2>/dev/null; then
        return
    fi
    # date -j (BSD/macOS)
    if date -j -f '%Y-%m-%d %H:%M:%S' "$ts" '+%s' 2>/dev/null; then
        return
    fi
    # Fallback: tra ve 0 neu khong parse duoc
    warn "Cannot parse timestamp: $ts — treating as epoch 0"
    echo "0"
}

# Escape chuoi cho JSON
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    echo "$s"
}

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------

PROJECT_PATH="$(normalize_path "$PROJECT_PATH")"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "{\"error\":\"Project path does not exist: $PROJECT_PATH\"}" >&2
    exit 1
fi

if [ ! -f "$LEDGER_JSON" ]; then
    echo "{\"error\":\"Ledger file not found: $LEDGER_JSON\"}" >&2
    exit 1
fi

log "Checking staleness for: $PROJECT_PATH"
log "Ledger: $LEDGER_JSON"

# ---------------------------------------------------------------------------
# Doc ledger.json
# ---------------------------------------------------------------------------

# Lay last_full_scan timestamp
last_scan_ts="$(grep '"last_full_scan"' "$LEDGER_JSON" 2>/dev/null \
    | grep -oE '"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z?"' \
    | head -1 | tr -d '"' || echo "")"

if [ -z "$last_scan_ts" ]; then
    # Thu cac format khac
    last_scan_ts="$(grep '"last_full_scan"\|"scan_timestamp"' "$LEDGER_JSON" 2>/dev/null \
        | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9:]+' \
        | head -1 || echo "")"
fi

if [ -z "$last_scan_ts" ]; then
    warn "Cannot determine last_full_scan from ledger — treating all files as stale"
    last_scan_epoch=0
else
    last_scan_epoch="$(iso_to_epoch "$last_scan_ts")"
    log "Last full scan: $last_scan_ts (epoch: $last_scan_epoch)"
fi

# Lay total_items tu ledger (de tinh percentage)
total_items_ledger="$(grep '"total_items"\|"total_source_files"\|"source_count"' "$LEDGER_JSON" 2>/dev/null \
    | grep -oE '[0-9]+' | head -1 || echo "0")"
[ -z "$total_items_ledger" ] || [ "$total_items_ledger" = "0" ] && total_items_ledger=1

# Tap hop cac path da co trong inventory (de detect new/deleted)
# Doc tu inventory_files array trong ledger neu co
inventory_paths_raw="$(grep -oE '"path"[[:space:]]*:[[:space:]]*"[^"]*"' "$LEDGER_JSON" 2>/dev/null \
    | grep -oE '"[^"]*"$' | tr -d '"' || echo "")"

# ---------------------------------------------------------------------------
# 1. Files modified sau last_full_scan
# ---------------------------------------------------------------------------

log "Finding modified files since last scan..."

EXCLUDE_DIRS=(
    "node_modules" ".git" "dist" "build" "__pycache__"
    "vendor" "bin" "obj" ".next" ".nuxt" "coverage"
    "venv" ".venv" "target" ".dart_tool"
    "esp-idf" ".pub-cache" ".flutter" "Pods" ".gradle"
)

# Xay dung array exclude (tranh eval — hang tren Windows Git Bash)
EXCLUDE_ARRAY=()
for d in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_ARRAY+=( "!" "-path" "*/$d/*" )
done

# find wrapper voi exclude
excluded_find() {
    find "$PROJECT_PATH" "${EXCLUDE_ARRAY[@]}" "$@" 2>/dev/null
}

stale_entries=""
stale_count=0

# Files modified sau last_scan_epoch
# find -newer dung file reference, nhung ta co epoch nen dung -newer voi temp file
# Tao temp file voi mtime = last_scan_epoch
TMP_REF="$(mktemp 2>/dev/null || echo "/tmp/legacy-scan-ref-$$")"
trap 'rm -f "$TMP_REF"' EXIT

# Set mtime cua temp file = last_scan_epoch
if [ "$last_scan_epoch" -gt 0 ]; then
    # touch -d voi epoch (GNU)
    if touch -d "@$last_scan_epoch" "$TMP_REF" 2>/dev/null; then
        use_newer=true
    # touch -t voi format YYYYMMDDhhmm.ss (POSIX)
    elif touch_time="$(date -d "@$last_scan_epoch" '+%Y%m%d%H%M.%S' 2>/dev/null)" \
         && touch -t "$touch_time" "$TMP_REF" 2>/dev/null; then
        use_newer=true
    # BSD/macOS: date -r epoch
    elif touch_time="$(date -r "$last_scan_epoch" '+%Y%m%d%H%M.%S' 2>/dev/null)" \
         && touch -t "$touch_time" "$TMP_REF" 2>/dev/null; then
        use_newer=true
    else
        warn "Cannot set temp file mtime — skipping modified-file check"
        use_newer=false
    fi
else
    # last_scan_epoch = 0: tat ca file deu co the stale, giai han de tranh qua lon
    use_newer=false
    warn "last_scan_epoch=0 — skipping modified check, all files treated as potentially new"
fi

if [ "$use_newer" = "true" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        rel="${f#$PROJECT_PATH/}"
        rel="$(normalize_path "$rel")"
        mtime="$(file_mtime_epoch "$f")"
        escaped_path="$(json_escape "$rel")"
        stale_entries="$stale_entries{\"path\":\"$escaped_path\",\"reason\":\"modified\",\"last_modified\":$mtime},"
        stale_count=$((stale_count + 1))
    done < <(excluded_find -type f -newer "$TMP_REF" | head -"$STALENESS_MODIFIED_CAP")
fi

# ---------------------------------------------------------------------------
# 2. New files (khong co trong inventory)
# ---------------------------------------------------------------------------

log "Finding new files not in inventory..."

if [ -n "$inventory_paths_raw" ]; then
    SOURCE_EXTS="ts tsx js jsx mjs cjs py cs java go rs rb php swift kt dart vue"
    EXT_ARGS=()
    first=true
    for ext in $SOURCE_EXTS; do
        if [ "$first" = "true" ]; then
            EXT_ARGS+=( "-name" "*.$ext" )
            first=false
        else
            EXT_ARGS+=( "-o" "-name" "*.$ext" )
        fi
    done

    while IFS= read -r f; do
        [ -f "$f" ] || continue
        rel="${f#$PROJECT_PATH/}"
        rel="$(normalize_path "$rel")"

        # Kiem tra co trong inventory khong
        if ! echo "$inventory_paths_raw" | grep -qF "$rel" 2>/dev/null; then
            # Chi them neu chua duoc danh dau la modified
            if ! echo "$stale_entries" | grep -qF "\"$rel\"" 2>/dev/null; then
                mtime="$(file_mtime_epoch "$f")"
                escaped_path="$(json_escape "$rel")"
                stale_entries="$stale_entries{\"path\":\"$escaped_path\",\"reason\":\"new\",\"last_modified\":$mtime},"
                stale_count=$((stale_count + 1))
            fi
        fi
    done < <(excluded_find -type f \( "${EXT_ARGS[@]}" \) | head -"$STALENESS_NEW_CAP")
fi

# ---------------------------------------------------------------------------
# 3. Deleted files (co trong inventory nhung khong con tren disk)
# ---------------------------------------------------------------------------

log "Checking for deleted files..."

if [ -n "$inventory_paths_raw" ]; then
    while IFS= read -r inv_path; do
        [ -z "$inv_path" ] && continue
        full_path="$PROJECT_PATH/$inv_path"
        if [ ! -f "$full_path" ]; then
            escaped_path="$(json_escape "$inv_path")"
            stale_entries="$stale_entries{\"path\":\"$escaped_path\",\"reason\":\"deleted\",\"last_modified\":0},"
            stale_count=$((stale_count + 1))
        fi
    done <<< "$inventory_paths_raw"
fi

# ---------------------------------------------------------------------------
# 4. Tinh stale percentage va recommendation
# ---------------------------------------------------------------------------

log "Calculating stale percentage..."

# Dem tong so files hien tai tren disk (source files)
current_total=$(excluded_find -type f \
    \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
       -o -name '*.py' -o -name '*.cs' -o -name '*.java' -o -name '*.go' \
       -o -name '*.rs' -o -name '*.rb' -o -name '*.php' -o -name '*.dart' \) \
    | wc -l)

# Denominator: max(current_total, total_items_ledger) de tranh chia cho 0
denominator="$current_total"
[ "$total_items_ledger" -gt "$denominator" ] && denominator="$total_items_ledger"
[ "$denominator" -eq 0 ] && denominator=1

# stale_percentage: integer (rounded down)
stale_percentage=$(( (stale_count * 100) / denominator ))

# Recommendation logic
if [ "$stale_percentage" -lt 10 ]; then
    recommendation="continue"
    recommendation_reason="Du lieu con fresh ($stale_percentage% stale). An toan de resume."
elif [ "$stale_percentage" -le 30 ]; then
    recommendation="partial_rescan"
    recommendation_reason="$stale_percentage% files thay doi. Nen re-process cac stale items truoc khi resume."
else
    recommendation="full_rescan"
    recommendation_reason="E013: $stale_percentage% files thay doi vuot nguong 30%. Nen chay lai Stage 0-1 hoan toan."
fi

log "Stale: $stale_count/$denominator ($stale_percentage%) → $recommendation"

# ---------------------------------------------------------------------------
# 5. Output JSON report
# ---------------------------------------------------------------------------

scan_check_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"
escaped_reason="$(json_escape "$recommendation_reason")"
escaped_last_scan="$(json_escape "$last_scan_ts")"

# Build JSON into variable, validate bằng jq, rồi emit stdout.
# v5.0: staleness output đi vào stdout (consumers pipe qua jq) — giữ signature cũ.
_staleness_json="$(cat <<EOF
{
  "check_timestamp": "$scan_check_ts",
  "last_full_scan": "$escaped_last_scan",
  "project_path": "$(json_escape "$PROJECT_PATH")",
  "total_current_files": $current_total,
  "total_ledger_items": $total_items_ledger,
  "stale_count": $stale_count,
  "stale_percentage": $stale_percentage,
  "recommendation": "$recommendation",
  "recommendation_reason": "$escaped_reason",
  "stale_items": [${stale_entries%,}]
}
EOF
)"

# POST-WRITE VALIDATION (best-effort — không fail nếu jq vắng)
if has_jq && ! echo "$_staleness_json" | jq empty 2>/dev/null; then
    warn "staleness output JSON invalid — consumers may fail"
    log "Invalid JSON preview: $(echo "$_staleness_json" | head -c200)"
fi

printf '%s\n' "$_staleness_json"
