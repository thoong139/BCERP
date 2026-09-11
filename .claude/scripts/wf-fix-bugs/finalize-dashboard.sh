#!/usr/bin/env bash
# =============================================================================
# finalize-dashboard.sh — Phase 7 Step 7.5/7.5b (Mobile Gate + Finalize Dashboard — v10.9)
# =============================================================================
# Gộp 2 logical sub-steps:
#   7.5 Mobile Gate — check mobile coverage (WARN only if MOBILE_MODE=true)
#   7.5b Finalize Bug Dashboard — re-generate dashboard với final status
#
# Required env vars:
#   SESSION_DIR, SESSION_ID
#
# Optional env vars:
#   E005_HEALTHY        (default: false)
#   MOBILE_MODE         (default: false)
#   PROFILE             (default: standard)
#   FIXED_COUNT, DEFERRED_COUNT, FAILED_COUNT (default: 0 hoặc auto-detect)
#
# Exit codes:
#   0 — Dashboard finalized
#   1 — Required env var missing
#   3 — Dashboard write fail (E073)
#
# Output JSON (stdout):
#   {
#     "mobile_gate": "active|skip",
#     "mobile_refs": <int>,
#     "mobile_warn": <bool>,
#     "dashboard_path": "<path>",
#     "total_issues": <int>,
#     "status": "ok"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

E005_HEALTHY="${E005_HEALTHY:-false}"
MOBILE_MODE="${MOBILE_MODE:-false}"
PROFILE="${PROFILE:-standard}"

DASHBOARD="$SESSION_DIR/bug-dashboard.md"
REGISTRY="$SESSION_DIR/phase5-triage/issue-registry.json"
FIX_REPORT="$SESSION_DIR/phase6-execute/fix-report.md"
PHASE4_REPORT="$SESSION_DIR/phase4-find-bugs/Phase4-report.md"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── 7.5 Mobile Gate ──────────────────────────────────────────────────────────
MOBILE_GATE="skip"
MOBILE_REFS=0
MOBILE_WARN=false

if [ "$MOBILE_MODE" = "true" ]; then
  MOBILE_GATE="active"
  if [ -s "$PHASE4_REPORT" ]; then
    MOBILE_REFS=$(grep -ciE 'mobile|device|viewport|responsive' "$PHASE4_REPORT" 2>/dev/null | head -1 | tr -d '\r')
    MOBILE_REFS=${MOBILE_REFS:-0}
  fi
  if [ "$MOBILE_REFS" -eq 0 ]; then
    MOBILE_WARN=true
    echo "WARN: E045 — no mobile coverage detected in Phase 4 report" >&2
  fi
fi

# ── 7.5b Finalize Dashboard ──────────────────────────────────────────────────
# Defaults nếu env không set
FIXED_COUNT="${FIXED_COUNT:-0}"
DEFERRED_COUNT="${DEFERRED_COUNT:-0}"
FAILED_COUNT="${FAILED_COUNT:-0}"
TOTAL_ISSUES=0

# v10.11.0: bump dashboard version counter (CORE-025 concurrent-write detect)
PRIOR_VER=$(grep -oE 'bug-dashboard-version: *[0-9]+' "$DASHBOARD" 2>/dev/null | grep -oE '[0-9]+' | head -1)
NEXT_VER=$((${PRIOR_VER:-0} + 1))
NOW_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ "$E005_HEALTHY" = "true" ]; then
  # Healthy path: 0 issues
  {
    cat <<DH_HEALTHY
<!-- bug-dashboard-version: $NEXT_VER -->
<!-- last-writer: phase-7-finalize -->
<!-- last-updated: $NOW_TS -->

# Bug Dashboard — Tổng Kết Cuối Cùng

**Session:** $SESSION_ID
**Ngày hoàn thành:** $(date +%Y-%m-%d)
**Profile:** $PROFILE
**Version:** $NEXT_VER

## ✅ Hệ thống HEALTHY — không phát hiện lỗi

Pipeline đã chạy đầy đủ và không tìm thấy vấn đề nào qua các chiều kiểm tra.

| Chỉ số | Giá trị |
|--------|---------|
| Tổng issues phát hiện | 0 |
| Đã sửa | 0 |
| Hoãn | 0 |
| Thất bại | 0 |

## Hướng Dẫn Tiếp Theo

- Chạy \`/status\` để xem tổng quan dự án
- Hệ thống đã sẵn sàng cho deploy
DH_HEALTHY
  } > "$DASHBOARD" 2>/dev/null || { echo "ERROR: dashboard write fail (E073)" >&2; exit 3; }
else
  # Normal path: load metrics
  if [ -s "$REGISTRY" ]; then
    TOTAL_ISSUES=$(jq '.total_issues // (.issues | length) // 0' "$REGISTRY" 2>/dev/null || echo 0)
  fi

  # Override counts từ fix-report nếu env chưa set
  if [ "$FIXED_COUNT" = "0" ] && [ -s "$FIX_REPORT" ]; then
    FIXED_COUNT=$(grep -ciE '✅|FIXED|đã sửa|fixed[: ]*[0-9]+' "$FIX_REPORT" 2>/dev/null | head -1 | tr -d '\r')
    FIXED_COUNT=${FIXED_COUNT:-0}
  fi
  if [ "$DEFERRED_COUNT" = "0" ] && [ -s "$FIX_REPORT" ]; then
    DEFERRED_COUNT=$(grep -ciE '⏸|DEFERRED|hoãn' "$FIX_REPORT" 2>/dev/null | head -1 | tr -d '\r')
    DEFERRED_COUNT=${DEFERRED_COUNT:-0}
  fi
  if [ "$FAILED_COUNT" = "0" ] && [ -s "$FIX_REPORT" ]; then
    FAILED_COUNT=$(grep -ciE '❌|FAILED|thất bại' "$FIX_REPORT" 2>/dev/null | head -1 | tr -d '\r')
    FAILED_COUNT=${FAILED_COUNT:-0}
  fi

  {
    cat <<DH_FINAL
<!-- bug-dashboard-version: $NEXT_VER -->
<!-- last-writer: phase-7-finalize -->
<!-- last-updated: $NOW_TS -->

# Bug Dashboard — Tổng Kết Cuối Cùng

**Session:** $SESSION_ID
**Ngày hoàn thành:** $(date +%Y-%m-%d)
**Profile:** $PROFILE
**Version:** $NEXT_VER

## Tổng Quan

| Chỉ số | Giá trị |
|--------|---------|
| Tổng issues phát hiện | $TOTAL_ISSUES |
| Đã sửa | $FIXED_COUNT |
| Hoãn | $DEFERRED_COUNT |
| Thất bại | $FAILED_COUNT |

DH_FINAL

    if [ "$DEFERRED_COUNT" -gt 0 ] 2>/dev/null || [ "$FAILED_COUNT" -gt 0 ] 2>/dev/null; then
      cat <<DH_UNRESOLVED
## Các Mục Chưa Xử Lý

Xem chi tiết trong \`$SESSION_DIR/phase6-execute/fix-report.md\`

DH_UNRESOLVED
    fi

    cat <<DH_TAIL
## Hướng Dẫn Tiếp Theo

- Chạy \`/wf-verify-sync\` để đồng bộ requirement-to-code
- Chạy \`/status\` để xem tổng quan dự án
- Review changes với \`git diff\`

> Dashboard finalized tại Phase 7.
DH_TAIL
  } > "$DASHBOARD" 2>/dev/null || { echo "ERROR: dashboard write fail (E073)" >&2; exit 3; }
fi

# ── Emit summary JSON ────────────────────────────────────────────────────────
jq -n \
  --arg mg "$MOBILE_GATE" \
  --argjson mr "$MOBILE_REFS" \
  --argjson mw "$MOBILE_WARN" \
  --arg dp "$DASHBOARD" \
  --argjson ti "$TOTAL_ISSUES" \
  '{
    mobile_gate: $mg,
    mobile_refs: $mr,
    mobile_warn: $mw,
    dashboard_path: $dp,
    total_issues: $ti,
    status: "ok"
  }'

exit 0
