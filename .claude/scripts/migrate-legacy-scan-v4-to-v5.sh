#!/usr/bin/env bash
# migrate-legacy-scan-v4-to-v5.sh
# Chuyển đổi v4.1 ledger.json → v5.0 scan-state.json (one-time use).
#
# Sử dụng:
#   ./migrate-legacy-scan-v4-to-v5.sh [project-path]
#
# Ví dụ:
#   ./migrate-legacy-scan-v4-to-v5.sh /path/to/my-project
#   ./migrate-legacy-scan-v4-to-v5.sh          # dùng CWD
#
# Kết quả:
#   - Tạo session mới trong .mc-data/work/legacy-scan/sessions/<id>/scan-state.json
#   - Đặt symlink .mc-data/work/legacy-scan/sessions/latest → <id>
#   - Giữ nguyên ledger.json (không xoá)
#   - /wf-legacy-scan --status sẽ đọc đúng trạng thái v5.0 sau khi migrate

set -euo pipefail 2>/dev/null || set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPTS_DIR/legacy-scan-common.sh" ]]; then
  # shellcheck source=legacy-scan-common.sh
  source "$SCRIPTS_DIR/legacy-scan-common.sh"
else
  # Minimal fallback nếu shared lib không tìm được
  _log_info()  { echo "[INFO]  $*" >&2; }
  _log_warn()  { echo "[WARN]  $*" >&2; }
  _log_error() { echo "[ERROR] $*" >&2; }
  log_info()   { _log_info  "$@"; }
  log_warn()   { _log_warn  "$@"; }
  log_error()  { _log_error "$@"; }
  validate_json() {
    local file="$1"
    jq empty "$file" 2>/dev/null || { log_error "JSON invalid: $file"; return 1; }
  }
fi

# ─── Constants ───────────────────────────────────────────────────────────────

readonly MIGRATE_VERSION="1.0.0"
readonly SCRIPT_NAME="migrate-legacy-scan-v4-to-v5"

# ─── Arguments ───────────────────────────────────────────────────────────────

PROJECT_PATH="${1:-.}"
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
  log_error "Project path does not exist: ${1:-.}"
  exit 1
}

WORK_DIR="$PROJECT_PATH/.mc-data/work/legacy-scan"
LEDGER="$WORK_DIR/ledger.json"
SESSIONS_DIR="$WORK_DIR/sessions"

# ─── Preflight ────────────────────────────────────────────────────────────────

log_info "=== wf-legacy-scan v4.1 → v5.0 Migration Helper v$MIGRATE_VERSION ==="
log_info "Project:  $PROJECT_PATH"
log_info "Work dir: $WORK_DIR"

# Kiểm tra jq
if ! command -v jq &>/dev/null; then
  log_error "jq không tìm thấy. Cài: https://stedolan.github.io/jq/download/"
  exit 1
fi

# Kiểm tra ledger.json tồn tại và có nội dung
if [[ ! -s "$LEDGER" ]]; then
  log_error "Không tìm thấy ledger.json v4.1 tại: $LEDGER"
  log_error "Nếu dự án chưa từng chạy /wf-legacy-scan v4.1, không cần migrate."
  log_error "Nếu ledger.json đã bị xoá, bắt đầu fresh với: /wf-legacy-scan"
  exit 1
fi

# Validate ledger.json là JSON hợp lệ
if ! jq empty "$LEDGER" &>/dev/null; then
  log_error "ledger.json tại $LEDGER không phải JSON hợp lệ."
  log_error "Có thể bị corrupt. Xem xét chạy lại /wf-legacy-scan từ đầu."
  exit 1
fi

# Kiểm tra xem đã migrate chưa (sessions/ dir đã tồn tại)
if [[ -d "$SESSIONS_DIR" ]] && [[ -n "$(ls -A "$SESSIONS_DIR" 2>/dev/null)" ]]; then
  EXISTING_SESSIONS=$(ls "$SESSIONS_DIR" | grep -v '^latest$' | wc -l | tr -d ' ')
  if [[ "$EXISTING_SESSIONS" -gt 0 ]]; then
    log_warn "Đã có $EXISTING_SESSIONS session(s) v5.0 tại $SESSIONS_DIR"
    log_warn "Dự án có vẻ đã được migrate. Tiếp tục sẽ tạo thêm 1 session migrate mới."
    log_warn "Nhấn Ctrl+C để huỷ hoặc Enter để tiếp tục..."
    read -r || true
  fi
fi

# ─── Read v4.1 ledger ─────────────────────────────────────────────────────────

log_info "Đọc ledger.json v4.1..."

# Đọc các fields cần thiết từ ledger.json v4.1
PIPELINE_STATUS=$(jq -r '.pipeline_status // "UNKNOWN"' "$LEDGER")
STRATEGY_ID=$(jq -r '.strategy.id // "S1"' "$LEDGER")
MATURITY_LEVEL=$(jq -r '.maturity.level // "UNKNOWN"' "$LEDGER")
STAGE_CLASSIFY=$(jq -r '.stages.classify.status // "unknown"' "$LEDGER")
STAGE_EXTRACT=$(jq -r '.stages.extract.status // "unknown"' "$LEDGER")
STAGE_ASSESS=$(jq -r '.stages.assessment.status // "unknown"' "$LEDGER")
STAGE_INVENTORY=$(jq -r '.stages.inventory.status // "unknown"' "$LEDGER")
STAGE_SYNTHESIZE=$(jq -r '.stages.synthesize.status // "unknown"' "$LEDGER")
PROJECT_NAME=$(jq -r '.project_name // "unknown"' "$LEDGER")
ERRORS=$(jq -c '.errors // []' "$LEDGER")

log_info "  pipeline_status: $PIPELINE_STATUS"
log_info "  strategy: $STRATEGY_ID"
log_info "  maturity: $MATURITY_LEVEL"
log_info "  project: $PROJECT_NAME"

# ─── Map v4.1 stages → v5.0 layers ───────────────────────────────────────────

# Helper: chuyển stage status (v4.1) → layer status (v5.0)
map_status() {
  local s="$1"
  case "$s" in
    completed|done)   echo "completed" ;;
    in_progress)      echo "in_progress" ;;
    skipped)          echo "skipped" ;;
    failed)           echo "failed" ;;
    *)                echo "pending" ;;
  esac
}

L1_STATUS="completed"                      # Detection luôn done nếu ledger tồn tại
L2_STATUS=$(map_status "$STAGE_ASSESS")    # Assessment → L2
L3_STATUS=$(map_status "$STAGE_INVENTORY") # Inventory → L3
L4_STATUS=$(map_status "$STAGE_CLASSIFY")  # Classify → L4
L5_STATUS=$(map_status "$STAGE_EXTRACT")   # Extract → L5
L6_STATUS=$(map_status "$STAGE_SYNTHESIZE") # Synthesize → L6

# Xác định last_completed layer
LAST_COMPLETED=""
for layer in L6 L5 L4 L3 L2 L1; do
  status_var="L${layer:1}_STATUS"
  if [[ "${!status_var}" == "completed" ]]; then
    LAST_COMPLETED="$layer"
    break
  fi
done

# Xác định v5.0 status (pipeline level)
if [[ "$PIPELINE_STATUS" == "COMPLETE" ]]; then
  SCAN_STATUS="completed"
  LAST_COMPLETED="L6"
elif [[ "$PIPELINE_STATUS" == "IN_PROGRESS" ]]; then
  SCAN_STATUS="in_progress"
else
  SCAN_STATUS="in_progress"
fi

# ─── Determine profile ────────────────────────────────────────────────────────

# v4.1 không có profile. Mặc định = "standard" (= v4.1 behaviour theo ADR-LS02).
PROFILE="standard"

# depth_map cho standard profile (= v4.1 default)
DEPTH_L4="standard"
DEPTH_L5="standard"
DEPTH_L6="full"

# ─── Create session ───────────────────────────────────────────────────────────

SESSION_ID="migrated-$(date -u +%Y-%m-%dT%H-%M-%SZ)"
SESSION_DIR="$SESSIONS_DIR/$SESSION_ID"

log_info "Tạo session v5.0: $SESSION_ID"
mkdir -p "$SESSION_DIR/layers/L4" "$SESSION_DIR/layers/L5"

# ─── Write scan-state.json ────────────────────────────────────────────────────

NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

jq -n \
  --arg sid    "$SESSION_ID" \
  --arg now    "$NOW_ISO" \
  --arg path   "$PROJECT_PATH" \
  --arg prof   "$PROFILE" \
  --arg strat  "$STRATEGY_ID" \
  --arg matl   "$MATURITY_LEVEL" \
  --arg l1     "$L1_STATUS" \
  --arg l2     "$L2_STATUS" \
  --arg l3     "$L3_STATUS" \
  --arg l4     "$L4_STATUS" \
  --arg l4d    "$DEPTH_L4" \
  --arg l5     "$L5_STATUS" \
  --arg l5d    "$DEPTH_L5" \
  --arg l6     "$L6_STATUS" \
  --arg l6d    "$DEPTH_L6" \
  --arg scst   "$SCAN_STATUS" \
  --arg lc     "$LAST_COMPLETED" \
  --argjson err "$ERRORS" \
  '{
    "$schema": "scan-state-v1",
    "session": {
      "id": $sid,
      "created": $now,
      "project_path": $path,
      "profile": $prof,
      "strategy": $strat,
      "maturity_level": $matl,
      "migrated_from": "v4.1-ledger.json"
    },
    "depth_map": {
      "L1": "full",
      "L2": "full",
      "L3": "full",
      "L4": $l4d,
      "L5": $l5d,
      "L6": $l6d
    },
    "synthesis_mode": "full",
    "layers": {
      "L1": { "status": $l1 },
      "L2": { "status": $l2 },
      "L3": { "status": $l3 },
      "L4": { "status": $l4, "depth": $l4d },
      "L5": { "status": $l5, "depth": $l5d },
      "L6": { "status": $l6 }
    },
    "status": $scst,
    "last_completed": $lc,
    "error_log": $err,
    "resume_hint": "Migrated from v4.1 ledger.json via migrate-legacy-scan-v4-to-v5.sh"
  }' > "$SESSION_DIR/scan-state.json"

validate_json "$SESSION_DIR/scan-state.json" || {
  log_error "scan-state.json không hợp lệ sau khi tạo!"
  exit 1
}

# ─── Write sessions/latest symlink (hoặc marker file) ────────────────────────

LATEST_LINK="$SESSIONS_DIR/latest"

# Trên Windows Git Bash, symlink có thể không hoạt động — dùng marker file thay
if ln -sfn "$SESSION_ID" "$LATEST_LINK" 2>/dev/null; then
  log_info "Symlink: sessions/latest → $SESSION_ID"
else
  # Fallback: ghi SESSION_ID vào file text
  echo "$SESSION_ID" > "$LATEST_LINK.txt"
  log_info "Marker: sessions/latest.txt = $SESSION_ID (symlink không hỗ trợ trên platform này)"
fi

# ─── Write migration report ───────────────────────────────────────────────────

REPORT_FILE="$WORK_DIR/migration-report.md"

cat > "$REPORT_FILE" <<EOF
# wf-legacy-scan Migration Report

**Thực hiện:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Script:** migrate-legacy-scan-v4-to-v5.sh v$MIGRATE_VERSION
**Dự án:** $PROJECT_PATH

## Kết quả

| Item | Giá trị |
|------|---------|
| Session ID tạo mới | \`$SESSION_ID\` |
| Nguồn | \`$LEDGER\` |
| Pipeline status v4.1 | $PIPELINE_STATUS |
| Scan status v5.0 | $SCAN_STATUS |
| Last completed layer | $LAST_COMPLETED |
| Profile áp dụng | $PROFILE (default — v4.1 behaviour) |

## Layer Mapping

| v4.1 Stage | → | v5.0 Layer | Status |
|------------|---|------------|--------|
| (detection) | → | L1 | $L1_STATUS |
| assessment | → | L2 | $L2_STATUS |
| inventory | → | L3 | $L3_STATUS |
| classify | → | L4 | $L4_STATUS |
| extract | → | L5 | $L5_STATUS |
| synthesize | → | L6 | $L6_STATUS |

## File được tạo

- \`$SESSION_DIR/scan-state.json\` ✅

## Bước tiếp theo

Kiểm tra trạng thái:
\`\`\`
/wf-legacy-scan --status
\`\`\`

Nếu pipeline COMPLETE → tiếp tục với \`/wf-brainstorm\`.
Nếu pipeline IN_PROGRESS → resume với \`/wf-legacy-scan --resume\`.

## Lưu ý

- \`ledger.json\` gốc KHÔNG bị xoá (backward-compat).
- \`scan-state.json\` là canonical cho v5.0+.
- Chạy lại migrate tạo thêm session mới — session cũ vẫn còn.
EOF

log_info "Migration report: $REPORT_FILE"

# ─── Verify ──────────────────────────────────────────────────────────────────

log_info ""
log_info "=== Kết quả Migration ==="
log_info "Session ID: $SESSION_ID"
log_info "scan-state.json: $SESSION_DIR/scan-state.json"
log_info "Status: $SCAN_STATUS (last: $LAST_COMPLETED)"
log_info ""

# Summary cho user
jq '{
  session_id: .session.id,
  status: .status,
  last_completed: .last_completed,
  profile: .session.profile,
  strategy: .session.strategy
}' "$SESSION_DIR/scan-state.json"

log_info ""
log_info "✅ Migration hoàn tất!"
log_info "Kiểm tra: /wf-legacy-scan --status"

exit 0
