#!/usr/bin/env bash
# lint-scenario.sh — Lint CMI test-scenario .md theo 7 rules (Phase 9 G1.1)
# Usage: ./lint-scenario.sh <scenario-file> [--json]
#
# Schema-id (output): lint-report-v1 (sub-entry per scenario; aggregate ở caller)
# Compatible với templates/lint-report.json schema_id="lint-report-v1"
#
# 7 LINT RULES (xem templates/lint-report.json `lint_rules_applied`):
#   LINT-001 frontmatter_missing_field — 14 required fields per template
#   LINT-002 steps_table_malformed     — 5 cols: Bước|Hành động|Kết quả mong đợi|Kết quả thực tế|Pass/Fail
#   LINT-003 unknown_step_pattern      — Hành động phải match 5 patterns Click/Fill/Select/Wait/Navigate
#   LINT-004 expected_result_empty     — Kết quả mong đợi column không rỗng
#   LINT-005 actor_not_in_rbac         — (defer Phase 9 vì cần load rbac-matrix.json — Stage 4 chỉ WARN)
#   LINT-006 entry_url_unreachable     — (defer Phase 9 PRE-GATE T3 FE running check — Stage 4 SKIP)
#   LINT-007 cross_module_path_invalid — nếu cross_module=true, modules_involved phải có ≥2
#
# Exit codes: 0=PASS hoặc WARN-only, 1=FAIL (critical → BLOCK Phase 9)
set -euo pipefail

FILE="${1:-}"
JSON_OUTPUT="${2:-}"

[ -z "$FILE" ] && { echo "Usage: $0 <scenario-file> [--json]" >&2; exit 1; }
[ ! -f "$FILE" ] && { echo "File not found: $FILE" >&2; exit 1; }

# 14 frontmatter fields required theo test-scenario.template.md
REQUIRED_FRONTMATTER=(
  scenario_id generated_by lane_source profile session_id
  source_violation_id source_invariant_id source_dim severity
  scenario_type modules_involved cross_module confidence entry_url actor
)

ERRORS=()      # critical → BLOCK
WARNINGS=()    # WARN → continue
INFOS=()       # INFO → log only

HAS_CRITICAL=false
HAS_WARN=false

# ─── Extract frontmatter (giữa --- và ---) ───
FRONTMATTER=$(awk '/^---$/{f++;next} f==1{print} f==2{exit}' "$FILE" 2>/dev/null || echo "")

if [ -z "$FRONTMATTER" ]; then
  ERRORS+=("{\"severity\":\"critical\",\"code\":\"LINT-001\",\"line\":1,\"message\":\"Khong tim thay frontmatter YAML (--- ... ---)\",\"fix_hint\":\"Them frontmatter YAML o dau file theo test-scenario.template.md\"}")
  HAS_CRITICAL=true
fi

# ─── RULE LINT-001: frontmatter_missing_field ───
for field in "${REQUIRED_FRONTMATTER[@]}"; do
  # Check field present (kể cả value rỗng) — pattern: "^field:"
  if ! echo "$FRONTMATTER" | grep -qE "^${field}:"; then
    ERRORS+=("{\"severity\":\"critical\",\"code\":\"LINT-001\",\"line\":0,\"message\":\"Thieu field bat buoc '${field}' trong frontmatter\",\"fix_hint\":\"Them dong '${field}: <value>' vao frontmatter YAML\"}")
    HAS_CRITICAL=true
  fi
done

# ─── Extract specific frontmatter values cho cross-validation ───
CROSS_MODULE=$(echo "$FRONTMATTER" | grep -E "^cross_module:" | head -1 | awk '{print $2}' | tr -d '"' || echo "false")
MODULES_INVOLVED=$(echo "$FRONTMATTER" | grep -E "^modules_involved:" | head -1 | sed 's/^modules_involved:[[:space:]]*//' || echo "[]")
ACTOR=$(echo "$FRONTMATTER" | grep -E "^actor:" | head -1 | awk '{print $2}' | tr -d '"' || echo "")
ENTRY_URL=$(echo "$FRONTMATTER" | grep -E "^entry_url:" | head -1 | sed 's/^entry_url:[[:space:]]*//' | tr -d '"' || echo "")
SCENARIO_ID=$(echo "$FRONTMATTER" | grep -E "^scenario_id:" | head -1 | awk '{print $2}' | tr -d '"' || echo "UNKNOWN")

# ─── RULE LINT-007: cross_module_path_invalid ───
if [ "$CROSS_MODULE" = "true" ]; then
  # Đếm modules trong array — count commas + 1 nếu không empty
  MODULE_COUNT=$(echo "$MODULES_INVOLVED" | tr -cd ',' | wc -c)
  MODULE_COUNT=$((MODULE_COUNT + 1))
  # Nếu MODULES_INVOLVED là "[]" hoặc empty thì count = 0
  if echo "$MODULES_INVOLVED" | grep -qE "^\[\s*\]$|^$"; then
    MODULE_COUNT=0
  fi
  if [ "$MODULE_COUNT" -lt 2 ]; then
    ERRORS+=("{\"severity\":\"critical\",\"code\":\"LINT-007\",\"line\":0,\"message\":\"cross_module=true nhung modules_involved chi co ${MODULE_COUNT} module(s) — phai >=2\",\"fix_hint\":\"Them module thu 2 vao modules_involved: [moduleA, moduleB, ...]\"}")
    HAS_CRITICAL=true
  fi
fi

# ─── RULE LINT-002: steps_table_malformed ───
# Tìm header table: | Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
TABLE_HEADER_LINE=$(grep -nE "^\|.*Bước.*Hành động.*Kết quả mong đợi.*Kết quả thực tế.*Pass/Fail.*\|" "$FILE" 2>/dev/null | head -1 || echo "")
if [ -z "$TABLE_HEADER_LINE" ]; then
  ERRORS+=("{\"severity\":\"critical\",\"code\":\"LINT-002\",\"line\":0,\"message\":\"Khong tim thay bang Buoc dung 5 cot (Buoc|Hanh dong|Ket qua mong doi|Ket qua thuc te|Pass/Fail)\",\"fix_hint\":\"Them bang theo test-scenario.template.md format\"}")
  HAS_CRITICAL=true
else
  TABLE_LINE_NUM=$(echo "$TABLE_HEADER_LINE" | cut -d: -f1)

  # Verify 5 cột (đếm pipe trong header)
  HEADER_TEXT=$(echo "$TABLE_HEADER_LINE" | cut -d: -f2-)
  PIPE_COUNT=$(echo "$HEADER_TEXT" | tr -cd '|' | wc -c)
  # 5 cột → 6 pipes (open|c1|c2|c3|c4|c5|close)
  if [ "$PIPE_COUNT" -ne 6 ]; then
    ERRORS+=("{\"severity\":\"critical\",\"code\":\"LINT-002\",\"line\":${TABLE_LINE_NUM},\"message\":\"Bang header co ${PIPE_COUNT} pipes (can 6 cho 5 cot)\",\"fix_hint\":\"Sua header bang: | Buoc | Hanh dong | Ket qua mong doi | Ket qua thuc te | Pass/Fail |\"}")
    HAS_CRITICAL=true
  fi
fi

# ─── RULE LINT-003: unknown_step_pattern + LINT-004: expected_result_empty ───
# Parse từng data row của table (skip header + separator row)
if [ -n "$TABLE_HEADER_LINE" ]; then
  # Lấy các dòng table data: bắt đầu từ line sau separator (---|---|...)
  TABLE_START_LINE=$((TABLE_LINE_NUM + 2))  # +1 header, +1 separator

  STEP_IDX=0
  while IFS= read -r line; do
    # Skip empty rows hoặc non-table rows
    [ -z "$line" ] && continue
    [[ "$line" != "|"* ]] && continue
    [[ "$line" == "|--"* ]] && continue
    [[ "$line" == "|:-"* ]] && continue

    STEP_IDX=$((STEP_IDX + 1))
    # Parse columns
    BUOC=$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    HANH_DONG=$(echo "$line" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    KQ_MONG_DOI=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip nếu Bước không phải số (vd. placeholder hoặc empty)
    [ -z "$BUOC" ] && continue

    CURRENT_LINE=$((TABLE_START_LINE + STEP_IDX - 1))

    # LINT-003: Hành động phải match 1 trong 5 patterns (Click/Fill/Select/Wait/Navigate, case-insensitive)
    if [ -n "$HANH_DONG" ] && [ "$HANH_DONG" != "..." ] && [ "$HANH_DONG" != "{ACTION}" ]; then
      if ! echo "$HANH_DONG" | grep -qiE "^(click|fill|select|wait|navigate|nhấp|nhập|chọn|chờ|điều hướng|di chuyển|nhấn|gõ)"; then
        WARNINGS+=("{\"severity\":\"warning\",\"code\":\"LINT-003\",\"line\":${CURRENT_LINE},\"message\":\"Buoc ${BUOC}: Hanh dong '${HANH_DONG}' khong match 5 patterns (Click/Fill/Select/Wait/Navigate)\",\"fix_hint\":\"Doi action thanh: Click <selector>, Fill <field> = <value>, Select <option> from <dropdown>, Wait <selector>, hoac Navigate to <URL>\"}")
        HAS_WARN=true
      fi
    fi

    # LINT-004: Kết quả mong đợi không rỗng
    if [ -z "$KQ_MONG_DOI" ] || [ "$KQ_MONG_DOI" = "..." ] || [ "$KQ_MONG_DOI" = "{EXPECTED}" ]; then
      ERRORS+=("{\"severity\":\"critical\",\"code\":\"LINT-004\",\"line\":${CURRENT_LINE},\"message\":\"Buoc ${BUOC}: Ket qua mong doi rong\",\"fix_hint\":\"Them assertion: Element <selector> visible | Text '<text>' appears | URL = <pattern> | Network <method> <url> = <status>\"}")
      HAS_CRITICAL=true
    fi

    # Limit parse: max 50 steps (đề phòng file lỗi)
    [ "$STEP_IDX" -ge 50 ] && break
  done < <(tail -n +"$TABLE_START_LINE" "$FILE" 2>/dev/null)
fi

# ─── RULE LINT-005: actor_not_in_rbac (deferred — Stage 4 chỉ check non-empty) ───
if [ -z "$ACTOR" ]; then
  WARNINGS+=("{\"severity\":\"warning\",\"code\":\"LINT-005\",\"line\":0,\"message\":\"Field 'actor' rong — khong xac dinh duoc user role cho login\",\"fix_hint\":\"Them actor: <role-name> tu rbac-matrix.json (vd: admin, sales_rep, finance_manager)\"}")
  HAS_WARN=true
fi

# ─── RULE LINT-006: entry_url_unreachable (defer Phase 9 PRE-GATE T3 — Stage 4 chỉ check format) ───
if [ -z "$ENTRY_URL" ] || [ "$ENTRY_URL" = "{ENTRY_URL}" ]; then
  WARNINGS+=("{\"severity\":\"warning\",\"code\":\"LINT-006\",\"line\":0,\"message\":\"Field 'entry_url' rong hoac chua populate\",\"fix_hint\":\"Set entry_url thanh URL relative (vd: /crm/customers) hoac absolute. api-only mode set entry_url=null\"}")
  HAS_WARN=true
fi

# ─── Build output ───
ERRORS_JSON="["
if [ "${#ERRORS[@]}" -gt 0 ]; then
  ERRORS_JSON+=$(printf '%s,' "${ERRORS[@]}")
  ERRORS_JSON="${ERRORS_JSON%,}"
fi
ERRORS_JSON+="]"

WARNINGS_JSON="["
if [ "${#WARNINGS[@]}" -gt 0 ]; then
  WARNINGS_JSON+=$(printf '%s,' "${WARNINGS[@]}")
  WARNINGS_JSON="${WARNINGS_JSON%,}"
fi
WARNINGS_JSON+="]"

# Determine lint_status
if $HAS_CRITICAL; then
  LINT_STATUS="FAIL"
elif $HAS_WARN; then
  LINT_STATUS="WARN"
else
  LINT_STATUS="PASS"
fi

# Combined errors array cho schema lint-report-v1 (errors[] với severity nested)
ALL_ENTRIES="["
[ "${#ERRORS[@]}" -gt 0 ] && ALL_ENTRIES+=$(printf '%s,' "${ERRORS[@]}")
[ "${#WARNINGS[@]}" -gt 0 ] && ALL_ENTRIES+=$(printf '%s,' "${WARNINGS[@]}")
ALL_ENTRIES="${ALL_ENTRIES%,}"
ALL_ENTRIES+="]"

if [ "${JSON_OUTPUT:-}" = "--json" ]; then
  # Output per-scenario entry compatible với scenarios_linted[] item schema
  printf '{"scenario_id":"%s","scenario_file":"%s","lint_status":"%s","errors":%s,"has_critical":%s,"has_warnings":%s}\n' \
    "$SCENARIO_ID" "$FILE" "$LINT_STATUS" "$ALL_ENTRIES" \
    "$([ "$HAS_CRITICAL" = "true" ] && echo "true" || echo "false")" \
    "$([ "$HAS_WARN" = "true" ] && echo "true" || echo "false")"
else
  case "$LINT_STATUS" in
    PASS)
      echo "LINT PASS: $FILE (0 errors, 0 warnings)"
      ;;
    WARN)
      echo "LINT WARN: $FILE (${#ERRORS[@]} critical, ${#WARNINGS[@]} warnings)"
      for w in "${WARNINGS[@]}"; do
        code=$(echo "$w" | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
        message=$(echo "$w" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        echo "  [WARN ${code}] ${message}"
      done
      ;;
    FAIL)
      echo "LINT FAIL: $FILE (${#ERRORS[@]} critical, ${#WARNINGS[@]} warnings)"
      for e in "${ERRORS[@]}"; do
        code=$(echo "$e" | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
        lineno=$(echo "$e" | grep -o '"line":[0-9]*' | cut -d: -f2)
        message=$(echo "$e" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        echo "  [CRITICAL ${code}] Line ${lineno}: ${message}"
      done
      echo ""
      echo "Fix critical errors va chay lai lint truoc khi Phase 9 execute (E151 BLOCK)."
      ;;
  esac
fi

# Exit code: FAIL=1 (block), PASS+WARN=0 (continue)
[ "$LINT_STATUS" = "FAIL" ] && exit 1 || exit 0
