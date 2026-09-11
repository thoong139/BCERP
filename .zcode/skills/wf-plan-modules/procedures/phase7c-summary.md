# Phase 7c: Phase Summary + Session Close (BẮT BUỘC — CORE-028, CORE-026)

> Tạo `phase-summary.md` cho user observability + ghi session log entry + finalize checkpoint.

> **Protocol:** Xem `.claude/skills/protocols/` — §14 Phase Summary, §15 Execution Trace.

---

## PRE-GATE

Phase 7b POST-GATE PASSED.

---

## 📤 OUTPUT

| File | Đường dẫn | Template |
|------|-----------|---------|
| Phase summary | `.mc-data/work/wf-plan-modules/phase-summary.md` | `.claude/doc-framework/_meta/phase-summary.template.md` |
| Session log entry | `.mc-data/work/_trace/session-log.json` (append) | `.claude/doc-framework/_meta/session-log.template.json` |
| Final checkpoint | `.mc-data/work/wf-plan-modules/checkpoint.json` (update) | `templates/checkpoint.json` |

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 7c.1 | **Phase Summary (CORE-028) + Atomic write:** READ template `.claude/doc-framework/_meta/phase-summary.template.md` → POPULATE với tóm tắt toàn bộ skill (modules analyzed, layers, sprints, findings, next step) → **Template strip**: xóa placeholder markers ({{...}}, <!-- template: ... -->) trước khi WRITE → `TMP=$(mktemp)` → WRITE `$TMP` → validate (T2 structure check) → `mv $TMP .mc-data/work/wf-plan-modules/phase-summary.md`. Viết bằng tiếng Việt, dễ hiểu cho non-specialist, ≤15 dòng content chính. Hiển thị nội dung trong conversation. | `test -s .mc-data/work/wf-plan-modules/phase-summary.md` |
| 7c.2 | **Session Log (CORE-026):** Append entry vào `.mc-data/work/_trace/session-log.json` (xem §Session Log Entry). Nếu skill bị fail → event = "FAIL" + error_details. | Entry appended |
| 7c.3 | **Final checkpoint + Atomic write:** READ `$SESSION_DIR/session-state.json` → update `position.current_phase = "completed"`, `phases.P7_c.status = "completed"` → `TMP=$(mktemp $SESSION_DIR/.ck.XXXXXX)` → WRITE `$TMP` → `mv $TMP $SESSION_DIR/session-state.json`. Cũng update `.mc-data/work/wf-plan-modules/checkpoint.json`: `position.current_phase = "completed"`. | Checkpoint updated |

---

## §Phase Summary Content (Step 7c.1 chi tiết)

Khi POPULATE template, include:

```markdown
# /wf-plan-modules — Tóm tắt phase

## Đã làm gì
- Phân tích dependency cho [N] modules
- Detect circular: [có/không có]
- Topological sort → [K] layers
- Tạo [S] sprint plans
- Tạo [F] task files (impl)
- Stakeholder review: [PASSED/CONDITIONAL_PASS]

## Kết quả chính
- **Implementation order:** Layer 0 → Layer K
- **Critical path:** [list modules trên critical path]
- **System Coverage:** [X]/[Y] systems planned ([percent]%)
- **Coverage Strategy:** [full/placeholders/thin_clients]

## Lưu ý
[List 0-3 điểm nóng nhất từ error_log + findings]

## Bước tiếp theo
Chạy `/wf-implement-feature [REQ-ID]` để bắt đầu implement.
Hoặc `/status` để xem dashboard tổng thể.
```

---

## §Session Log Entry (Step 7c.2 chi tiết)

```json
{
  "event": "COMPLETE",
  "skill": "wf-plan-modules",
  "timestamp": "2026-04-19T12:00:00Z",
  "duration_summary": "45 minutes",
  "modules_count": 13,
  "layers_count": 4,
  "sprints_count": 5,
  "features_with_tasks": 38,
  "findings_summary": {
    "critical": 0,
    "high": 0,
    "medium": 2,
    "low": 5
  },
  "coverage_strategy": "full",
  "legacy_mode": false
}
```

Nếu skill fail giữa chừng:

```json
{
  "event": "FAIL",
  "skill": "wf-plan-modules",
  "timestamp": "...",
  "phase_failed": "phase_7b",
  "error_code": "E011",
  "error_details": "Agent timeout sau 3 retries"
}
```

---

## POST-GATE (T1-T4 tiered per Protocol 10 + CORE-012)

### T1 — Existence (non-empty files)
```bash
test -s .mc-data/work/wf-plan-modules/phase-summary.md \
  && test -s .mc-data/work/wf-plan-modules/checkpoint.json \
  && test -s .mc-data/work/_trace/session-log.json
```

### T2 — Structure (required sections)
```bash
grep -q "## Đã làm gì" .mc-data/work/wf-plan-modules/phase-summary.md \
  && grep -q "## Kết quả chính" .mc-data/work/wf-plan-modules/phase-summary.md \
  && grep -q "## Bước tiếp theo" .mc-data/work/wf-plan-modules/phase-summary.md
```

### T3 — Content depth (word count + section completeness)
```bash
# Tối thiểu 80 words tổng, 15 lines, mỗi section ≥ 20 words
WC=$(wc -w < .mc-data/work/wf-plan-modules/phase-summary.md)
LC=$(wc -l < .mc-data/work/wf-plan-modules/phase-summary.md)
[ "$WC" -ge 80 ] && [ "$LC" -ge 15 ]
```

### T4 — Cross-reference (checkpoint + registry consistency)
```bash
# T4.1: checkpoint hoàn tất
jq -e '.position.current_phase == "completed"' \
  .mc-data/work/wf-plan-modules/checkpoint.json >/dev/null

# T4.2: implementation_order trong registry non-empty + khớp modules_count trong summary
IMPL_COUNT=$(jq '.implementation_order | length' .mc-data/docs/_meta/req-registry.json)
[ "$IMPL_COUNT" -gt 0 ]

# T4.3: nếu có deprecated-snapshot.json (Phase 7.4 CDG accepted) → verify atomicity
if test -f .mc-data/work/wf-plan-modules/deprecated-snapshot.json; then
  jq -e '.features_snapshot | length >= 1' .mc-data/work/wf-plan-modules/deprecated-snapshot.json >/dev/null
fi
```

Nếu BẤT KỲ T1-T4 fail → ERROR E012 (POST-GATE violation) + auto-fix retry (max 3 lần theo Protocol 1).
Sau 3 lần fail → escalate user với diagnostic: chỉ rõ T nào fail, nội dung thực tế vs expected.

---

## §Early Exit FAIL Log (BẮT BUỘC — CORE-026)

Tất cả early exit (STOP trước Phase 7c) PHẢI emit FAIL entry vào session-log.json ngay tại điểm exit. Áp dụng cho mọi error code E001–E012 và user-initiated STOP (ví dụ: user chọn option (a) ở CDG, E002 re-run request).

Pattern emit FAIL khi early exit (copy-paste vào mỗi early-exit point):

```bash
# Emit FAIL session log (CORE-026) — chạy TRƯỚC khi STOP
SESSION_LOG=".mc-data/work/_trace/session-log.json"
if test -f "$SESSION_LOG"; then
  FAIL_ENTRY="{\"event\":\"FAIL\",\"skill\":\"wf-plan-modules\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"phase_failed\":\"$CURRENT_PHASE\",\"error_code\":\"$ERROR_CODE\",\"error_details\":\"$ERROR_MSG\"}"
  # Append vào array entries[]
  TMP=$(mktemp)
  jq --argjson entry "$FAIL_ENTRY" '.entries += [$entry]' "$SESSION_LOG" > "$TMP" && mv "$TMP" "$SESSION_LOG"
fi
```

**Checklist các early-exit points BẮT BUỘC có FAIL log:**
- Phase 0 PRE-GATE fail (E001/E004) — CURRENT_PHASE="phase_0"
- Phase 0.2c --resume không tìm thấy session — CURRENT_PHASE="phase_0"
- Phase 1 validation fail sau 3 retries (E009) — CURRENT_PHASE="phase_1"
- Phase 3 E002: user chọn "Shared Entity → re-run" — CURRENT_PHASE="phase_3"
- Phase 4 POST-GATE fail — CURRENT_PHASE="phase_4"
- Phase 7a E009: POST-GATE fail sau 3 retries — CURRENT_PHASE="phase_7a"
- Phase 7b E011: agent timeout sau retry, nếu abort — CURRENT_PHASE="phase_7b"
- Workload Gate block (Phase 0.5), user chọn abort — CURRENT_PHASE="phase_0.5"

---

## End of skill

Sau Phase 7c hoàn tất → return về SKILL.md → display Output Report cho user → STOP.
