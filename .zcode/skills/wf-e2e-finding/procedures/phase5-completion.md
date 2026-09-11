# F0a — Phase 5: COMPLETION

## Mục tiêu

Consolidate 8 findings vào finding-summary.md. Init 4 SSOT JSONs rỗng. POST-GATE toàn bộ output. Context budget check G4.

---

## 5.1 — Verify 8 finding files tồn tại

```bash
REQUIRED_FINDINGS=(
  "business-understanding.md"
  "business-rule-catalog.md"
  "state-machine.md"
  "cross-module-map.md"
  "db-mapping.md"
  "db-seed-data.md"
  "api-mapping.md"
  "ui-mapping.md"
)

MISSING_COUNT=0
for F in "${REQUIRED_FINDINGS[@]}"; do
  if [ ! -f "$FINDINGS_DIR/$F" ]; then
    log_error "E026" "phase5" "Thiếu finding file: $F"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
done

if [ "$MISSING_COUNT" -gt 0 ]; then
  echo "ERROR: $MISSING_COUNT finding files bị thiếu — không thể consolidate"
  exit 1
fi
```

---

## 5.2 — Generate finding-summary.md

Từ template `templates/finding-summary.template.md`. Đọc từng finding file và tóm tắt:

```
# Finding Summary — {FEAT-ID}: {Feature Name}

Generated: {date} | Session: {SESSION_ID} | Status: completed

## Trạng thái 8 Findings

| Finding | File | Size | Key Stats | Status |
|---------|------|------|-----------|--------|
| Business Understanding | business-understanding.md | {size} bytes | {N} actors, {N} flow steps | OK |
| Business Rule Catalog | business-rule-catalog.md | {size} bytes | {N} BRs | OK |
| State Machine | state-machine.md | {size} bytes | {N} states / N/A | OK |
| Cross-Module Map | cross-module-map.md | {size} bytes | {N} deps, {N} events | OK |
| DB Mapping | db-mapping.md | {size} bytes | {N} tables | OK |
| DB Seed Data | db-seed-data.md | {size} bytes | {N} INSERT records | OK |
| API Mapping | api-mapping.md | {size} bytes | {N} endpoints | OK |
| UI Mapping | ui-mapping.md | {size} bytes | {N} pages / N/A | OK |

## CDG-NEW-02 Warnings

{Danh sách cross-module deps chưa implement — hoặc "Không có warnings"}

## Sẵn sàng cho wf-e2e-test (F1)

F0a đã hoàn tất phân tích. wf-e2e-test (F1) có thể consume findings này làm context cho live-test:
- Consume: findings/*.md (8 files) + finding-summary.md
- SSOT JSONs được init rỗng, F1 sẽ APPEND khi test
```

Ghi atomic: `atomic_write_file "$FINDINGS_DIR/finding-summary.md" "$CONTENT"`.

---

## 5.3 — Init 4 SSOT JSONs rỗng

Init từ templates. Điền `session_id` + `feat_id` + `created_by: "wf-e2e-finding"`.

```bash
SKILL_DIR=".claude/skills/workflow"

# issues.json
jq --arg sid "$SESSION_ID" --arg fid "$FEAT_ID" '
  del(._template_notes) |
  .session_id = $sid | .feat_id = $fid | .signals = []
' "$SKILL_DIR/wf-e2e-verify/templates/issues.template.json" > "$SESSION_DIR/issues.json.tmp.$$"
jq '.' "$SESSION_DIR/issues.json.tmp.$$" > /dev/null && mv "$SESSION_DIR/issues.json.tmp.$$" "$SESSION_DIR/issues.json" || {
  log_error "E027" "phase5" "Init issues.json thất bại"
  rm -f "$SESSION_DIR/issues.json.tmp.$$"
}

# block-test.json
jq --arg sid "$SESSION_ID" --arg fid "$FEAT_ID" '
  del(._template_notes) |
  .session_id = $sid | .feat_id = $fid | .blocked_tests = []
' "$SKILL_DIR/wf-e2e-verify/templates/block-test.template.json" > "$SESSION_DIR/block-test.json.tmp.$$"
jq '.' "$SESSION_DIR/block-test.json.tmp.$$" > /dev/null && mv "$SESSION_DIR/block-test.json.tmp.$$" "$SESSION_DIR/block-test.json" || {
  log_error "E027" "phase5" "Init block-test.json thất bại"
  rm -f "$SESSION_DIR/block-test.json.tmp.$$"
}

# implement-required.json
jq --arg sid "$SESSION_ID" --arg fid "$FEAT_ID" '
  del(._template_notes) |
  .session_id = $sid | .feat_id = $fid | .entries = []
' "$SKILL_DIR/wf-e2e-test/templates/implement-required.template.json" > "$SESSION_DIR/implement-required.json.tmp.$$"
jq '.' "$SESSION_DIR/implement-required.json.tmp.$$" > /dev/null && mv "$SESSION_DIR/implement-required.json.tmp.$$" "$SESSION_DIR/implement-required.json" || {
  log_error "E027" "phase5" "Init implement-required.json thất bại"
  rm -f "$SESSION_DIR/implement-required.json.tmp.$$"
}

# manual.json
jq --arg sid "$SESSION_ID" --arg fid "$FEAT_ID" '
  del(._template_notes) |
  .session_id = $sid | .feat_id = $fid | .entries = []
' "$SKILL_DIR/wf-e2e-test/templates/manual.template.json" > "$SESSION_DIR/manual.json.tmp.$$"
jq '.' "$SESSION_DIR/manual.json.tmp.$$" > /dev/null && mv "$SESSION_DIR/manual.json.tmp.$$" "$SESSION_DIR/manual.json" || {
  log_error "E027" "phase5" "Init manual.json thất bại"
  rm -f "$SESSION_DIR/manual.json.tmp.$$"
}
```

---

## 5.4 — POST-GATE toàn bộ (CORE-012)

```bash
# T1: Tất cả 13 files tồn tại (8 findings + finding-summary + 4 SSOT JSONs)
ALL_FILES=(
  "$FINDINGS_DIR/business-understanding.md"
  "$FINDINGS_DIR/business-rule-catalog.md"
  "$FINDINGS_DIR/state-machine.md"
  "$FINDINGS_DIR/cross-module-map.md"
  "$FINDINGS_DIR/db-mapping.md"
  "$FINDINGS_DIR/db-seed-data.md"
  "$FINDINGS_DIR/api-mapping.md"
  "$FINDINGS_DIR/ui-mapping.md"
  "$FINDINGS_DIR/finding-summary.md"
  "$SESSION_DIR/issues.json"
  "$SESSION_DIR/block-test.json"
  "$SESSION_DIR/implement-required.json"
  "$SESSION_DIR/manual.json"
)
for F in "${ALL_FILES[@]}"; do
  test -f "$F" || { log_error "E026" "phase5-postgate" "T1 FAIL: $F không tồn tại"; POSTGATE_FAIL=true; }
done

# T2: Mỗi finding file > 500 bytes
for F in "${REQUIRED_FINDINGS[@]}"; do
  SIZE=$(wc -c < "$FINDINGS_DIR/$F")
  [ "$SIZE" -gt 500 ] || { log_error "E026" "phase5-postgate" "T2 FAIL: $F size=$SIZE (< 500)"; POSTGATE_FAIL=true; }
done

# T3: 4 SSOT JSONs valid JSON
for J in issues.json block-test.json implement-required.json manual.json; do
  jq '.' "$SESSION_DIR/$J" > /dev/null || { log_error "E027" "phase5-postgate" "T3 FAIL: $J invalid JSON"; POSTGATE_FAIL=true; }
done

# T4: finding-summary.md tham chiếu tất cả 8 findings
for F in "${REQUIRED_FINDINGS[@]}"; do
  grep -q "$F" "$FINDINGS_DIR/finding-summary.md" || {
    log_error "E026" "phase5-postgate" "T4 FAIL: finding-summary không tham chiếu $F"
    POSTGATE_FAIL=true
  }
done

if [ "${POSTGATE_FAIL:-false}" = "true" ]; then
  echo "ERROR: POST-GATE Phase 5 FAIL — xem error-ledger.json"
  exit 1
fi
```

---

## 5.5 — Context Budget Check G4

```bash
check_context_budget  # Kiểm tra ngưỡng 50%/65%/80%

# Nếu context > 50%: mandatory checkpoint + suggest --resume cho F1
if [ "${CONTEXT_ESTIMATE_PCT:-0}" -ge 50 ]; then
  echo ""
  echo "=========================================="
  echo "F0a hoàn tất. Context hiện tại: ${CONTEXT_ESTIMATE_PCT}%"
  echo "Khuyến nghị: /clear + /wf-e2e-test $FEAT_ID --session=$SESSION_ID"
  echo "để giải phóng context trước khi chạy F1 live-test."
  echo "=========================================="
fi
```

---

## 5.6 — Cập nhật status.json + finalize

```bash
update_phase_status "p5_completion" "done"
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  .overall_status = "completed" |
  .current_phase = 5 |
  .next_action = "DONE — consume bằng wf-e2e-test F1" |
  .last_updated = $now
' "$STATUS" > "${STATUS}.tmp.$$"
mv "${STATUS}.tmp.$$" "$STATUS"

log_event "COMPLETE" "phase5" "F0a completed — 8 findings + finding-summary + 4 SSOT JSONs"
log_event "COMPLETE" "f0a" "wf-e2e-finding session $SESSION_ID DONE"

# Thông báo hoàn tất
echo ""
echo "F0a wf-e2e-finding hoàn tất."
echo "Session: $SESSION_ID"
echo "Findings: $FINDINGS_DIR (8 files + finding-summary.md)"
echo "SSOT JSONs: issues.json, block-test.json, implement-required.json, manual.json (rỗng, sẵn sàng cho F1)"
echo ""
echo "Tiếp theo: /wf-e2e-test $FEAT_ID --session=$SESSION_ID"
```
