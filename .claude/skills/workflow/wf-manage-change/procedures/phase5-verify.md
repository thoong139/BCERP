# Phase 5: Verify

> Full verification — đảm bảo không regression sau thay đổi.
> Invoke wf-preflight + wf-verify-sync với scope giới hạn bởi change.

> **Shared:** Xem `procedures/_shared.md` — Agent Prompt Templates (Phase 5), Fix Rules.

---

## PRE-GATE

- Phase 4 (4a + 4b + 4c) đã hoàn thành
- `$DRY_RUN == false`
- Tất cả changes đã được applied
- Registry validated (jq pass)

---

## INPUT

- Updated project files
- `$SESSION_DIR/affected-artifacts.json` — scope context cho sub-agents
- `$SESSION_DIR/change-status.json.phase4b.files_updated` — list files modified

---

## OUTPUT

- Verify results logged vào `change-status.json.phases.phase5`:
  - `preflight_result` (PASS/WARN/FAIL + issues)
  - `verify_sync_result` (sync_rate + mismatches)
  - `cross_validation_coverage` (%)

---

## Invoke Mechanism

Gọi `wf-preflight` và `wf-verify-sync` bằng `Agent` tool với `subagent_type` tương ứng.

**Agent prompt PHẢI include:**

1. Reference đến SKILL.md cần follow
2. Change context cụ thể (change_id, change_type, affected files)
3. Scope giới hạn

Agent sẽ đọc SKILL.md được reference và thực hiện các checks theo hướng dẫn đó.

**→ Full prompts trong `procedures/_shared.md` §Agent Prompt Templates (Phase 5).**

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5.1 | **Health check:** Invoke `wf-preflight` với change context (prompt từ `_shared.md`) — `subagent_type="qa-lead"` | Agent | PASS/WARN/FAIL |
| 5.2 | **Traceability check:** Invoke `wf-verify-sync` với scope của thay đổi (prompt từ `_shared.md`) — `subagent_type="integration-certifier"` | Agent | Sync rate |
| 5.3 | **Cross-Validation:** So sánh `$SESSION_DIR/affected-artifacts.json` (Phase 1 prediction) với actual changes (Phase 4 output) — xem §Cross-Validation Protocol | Read | Coverage >= 90% |
| 5.4 | **Auto-Correction:** Nếu cross-validation phát hiện gaps → log warning + hỏi user có muốn quay lại Phase 4 để fix | AskUserQuestion | Gaps resolved |
| 5.5 | **Regression spot-check:** Manual verify affected features vẫn hoạt động đúng theo docs (read code + compare với feature spec) | Read/Grep | No obvious issues |

---

## Cross-Validation Protocol (Step 5.3)

**So sánh 2 tập hợp:**

- **Predicted (Phase 1):** `affected-artifacts.json.docs_affected[] ∪ code_affected[] ∪ tests_affected[]`
- **Actual (Phase 4):** `change-status.json.phase4a.files_updated ∪ phase4b.files_updated ∪ phase4c.files_updated`

**[GAP-6 fix] Guard chia cho 0 — BẮT BUỘC kiểm tra trước khi tính:**

```
|predicted| = tổng số files trong predicted set

IF |predicted| == 0:
  IF $CHANGE_TYPE == "CLARIFY_REQ":
    → coverage = 100%
    → Log: "CLARIFY_REQ registry-only — không có artifacts được predicted, cross-validation skipped"
    → Tiếp tục không hỏi user
  ELSE:
    → coverage = 0% (bất thường — Phase 1 không xác định được artifacts)
    → WARNING: "Predicted set rỗng — Phase 1 không dự đoán được artifacts bị ảnh hưởng"
    → Hỏi user: "Phase 1 không xác định được files cần thay đổi. Bạn có muốn quay lại Phase 1 để re-analyze không?"
    → Nếu user đồng ý: reset current_phase = "phase1", route lại
    → Nếu user từ chối: log acceptable_discrepancy = true, tiếp tục Phase 6
  → STOP tính coverage formula, không chạy threshold logic bên dưới
ELSE:
  → coverage = |actual ∩ predicted| / |predicted| * 100
  → Tiếp tục với threshold logic
```

**Tính coverage (chỉ khi |predicted| > 0):**

```
coverage = |actual ∩ predicted| / |predicted| * 100
```

**Thresholds:**

| Coverage | Hành động |
|----------|-----------|
| ≥ 95% | Excellent — tiếp tục |
| 90-95% | OK — log warning cho files không khớp |
| 80-90% | Warning — hỏi user có muốn quay lại Phase 4 |
| < 80% | STOP — chạy Auto-Correction (Step 5.4) bắt buộc |

**Phân loại discrepancy:**

- **Predicted but not changed:** File được dự đoán nhưng không bị thay đổi → có thể predict quá rộng hoặc user giảm scope
- **Changed but not predicted:** File bị thay đổi nhưng không trong prediction → có thể collateral change hoặc predict thiếu

---

## Auto-Correction Loop (Step 5.4)

Nếu cross-validation fail:

```
AskUserQuestion:
  "Cross-validation phát hiện [N] file(s) discrepancy:
   - Predicted but not changed: [list]
   - Changed but not predicted: [list]

   Bạn muốn làm gì?"

  Options:
    - "Quay lại Phase 4b fix"     → reset current_phase = "phase4b", quay lại
    - "OK, chấp nhận discrepancy"  → log acceptable, tiếp tục Phase 6
    - "Abort — chạy verify-sync lại"   → chỉ re-run Step 5.2
```

Max 2 lần auto-correction loop. Nếu vẫn fail → escalate.

---

## Regression Spot-Check (Step 5.5)

Cho từng feature trong `affected-artifacts.json.registry_changes.features[]`:

1. Đọc feature spec tại `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md`
2. Tìm code implementing feature đó (grep REQ-ID/FEAT-ID)
3. Verify code behavior khớp với spec (manual review, không run code)
4. Flag issues vào `change-status.json.phase5.regression_issues[]`

---

## Sub-skill Invocation Details

### wf-preflight (Step 5.1)

Sau khi agent return, parse result:

```
preflight_result = {
  "status": "PASS" | "WARN" | "FAIL",
  "issues": [...],
  "categories": {...}
}
```

**[GAP-4 fix] Parse Fallback — BẮT BUỘC:**
```
TRY parse response → extract preflight_result
IF parse fail (response không có structure kỳ vọng, plain text, hoặc missing fields):
  → WARNING: "Agent response không parseable — đặt trạng thái WARN mặc định"
  → Set preflight_result = {
      "status": "WARN",
      "issues": ["Agent response unparseable — cần review thủ công trước khi deploy"],
      "categories": {},
      "parse_error": true
    }
  → Log entry trong change-status.json.error_log[]: {phase: "phase5", code: "E_PARSE", agent: "wf-preflight"}
  → KHÔNG block Phase 6 — tiếp tục với preflight_result.status = "WARN"
```

- `PASS` → tiếp tục
- `WARN` (bao gồm parse_error=true) → log warnings, hỏi user tiếp tục hay fix
- `FAIL` → STOP, hướng dẫn user chạy `/wf-preflight --fix` hoặc `/wf-fix-bugs`

### wf-verify-sync (Step 5.2)

```
verify_sync_result = {
  "sync_rate": 0.95,
  "mismatches": [...],
  "baseline_sync_rate": 0.95
}
```

**[GAP-4 fix] Parse Fallback cho wf-verify-sync:**
```
TRY parse response → extract verify_sync_result
IF parse fail:
  → Set verify_sync_result = {
      "sync_rate": null,
      "mismatches": [],
      "baseline_sync_rate": null,
      "parse_error": true,
      "note": "Agent response unparseable — sync rate không xác định được"
    }
  → Log entry trong error_log[]
  → Tiếp tục (không block)
```

Quy tắc: **Sync rate sau thay đổi KHÔNG được giảm** so với baseline (trước thay đổi). Nếu giảm → WARNING, hỏi user fix.
Nếu `sync_rate == null` (parse error) → skip comparison, log WARNING, tiếp tục.

---

## POST-GATE

- `change-status.json.phase5.preflight_result.status ∈ ["PASS", "WARN"]` (không phải FAIL)
- `change-status.json.phase5.verify_sync_result` — KHÔNG có hard threshold trên sync_rate:
  - Nếu `sync_rate` là số và `baseline_sync_rate` là số → log comparison (info only, không block)
  - Nếu `sync_rate == null` (parse error) → pass với WARNING (graceful degradation)
  - Sync rate comparison là INFORMATIONAL — KHÔNG block POST-GATE
- `change-status.json.phase5.cross_validation_coverage >= 80%` (hoặc đã accept discrepancy)
- Nếu fail POST-GATE → quay lại Phase 4 để fix (user decide)

**Note on baseline sync rate:** Baseline được capture tự động từ wf-verify-sync agent response
(`baseline_sync_rate` field). Nếu agent không trả về baseline → null → skip comparison (graceful).
KHÔNG cần capture baseline trước thay đổi vì wf-verify-sync tự tính internally.

**Verification (mc-postgate-check.sh):**
```bash
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/change-status.json --type=json
# → {"pass":true} required. Nếu fail → auto-fix re-generate → retry tối đa 3 lần.
```

**Sau khi PASS:** Update `change-status.json.phases.phase5.status = "completed"` → tiếp tục `procedures/phase6-report.md`.
