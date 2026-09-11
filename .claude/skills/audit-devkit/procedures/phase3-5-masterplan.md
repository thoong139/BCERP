# Phase 3.5: Master Plan Validation

> **Đọc:** `procedures/_shared.md §Verdict Computation §2. Master Plan Verdict` trước khi execute.

**Điều kiện chạy:** `master-plan` ∈ `$STAGES[]`.

**Mục đích:** Kiểm tra tất cả thành phần từ Master Optimization Plan (3 lớp, 8 components) đã được triển khai đúng và backward compatible. Output: `$MASTER_PLAN_STATUS` object + `master_plan_verdict`.

---

## Display Header

```
Phase 3.5: Validating Master Plan components...
```

---

## Step 3.5.1: Schema Sync Validation

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.5.1a | Chạy `.claude/scripts/validate-schema-sync.sh --all` | Bash | Exit code |
| 3.5.1b | Parse stdout → đếm pass/fail count | — | Extracted |
| 3.5.1c | Ghi: `$MASTER_PLAN_STATUS.schema_sync = { total: N, passed: N, failed: N }` | — | Recorded |

**Nếu script không tồn tại** → `schema_sync = { status: "MISSING", note: "Schema sync script chưa triển khai (Lớp 1)" }`. Tiếp tục.

---

## Step 3.5.2: Layer Gate Reports

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.5.2a | Kiểm tra `docs/plans/layer1-gate-report.md` tồn tại | Glob | exists/NOT_FOUND |
| 3.5.2b | Kiểm tra `docs/plans/layer2-gate-report.md` tồn tại | Glob | exists/NOT_FOUND |
| 3.5.2c | Kiểm tra `docs/plans/layer3-gate-report.md` tồn tại | Glob | exists/NOT_FOUND |
| 3.5.2d | Nếu tồn tại → đọc verdict từ mỗi report (Grep "PASS" hoặc "FAIL") | Read + Grep | Verdicts extracted |
| 3.5.2e | Ghi: `$MASTER_PLAN_STATUS.gate_reports = { L1: verdict\|MISSING, L2: ..., L3: ... }` | — | Recorded |

> **Graceful MISSING (Sprint 3 polish):** Files `layer{1,2,3}-gate-report.md` có thể không tồn tại trong repos chưa setup Master Plan layered rollout. Logic ghi `MISSING` vào `$MASTER_PLAN_STATUS.gate_reports[Lx]` là **non-blocking** — KHÔNG tạo finding, KHÔNG fail Phase 3.5, KHÔNG ảnh hưởng Master Plan verdict. Dùng cho future rollout tracking; absent = "chưa triển khai layered gates" (acceptable state).

---

## Step 3.5.3: Component-by-Component Check (8 components)

> **Dedup note:** Nếu scan Wave 4 đã chạy (`$SESSION_DIR` có `findings-masterplan-*.json`), READ kết quả từ đó thay vì re-run checks. Chỉ chạy Bash/Grep checks cho components chưa có trong scan output. Điều này tránh duplicate effort giữa scan và orchestrator.

**Priority: READ scan Wave 4 results first → chỉ Grep/Glob cho components thiếu.**

Chạy **PARALLEL** — 8 checks đồng thời (READ hoặc Grep/Glob). Mỗi component có check cụ thể:

| # | Component | Check Method | OK khi | MISSING khi | BROKEN khi |
|---|-----------|--------------|--------|-------------|------------|
| 1 | **Hook 2-Tầng** | Grep `hook_detect_tier_mode` trong `.claude/hooks/_hook-utils.sh` | Function tồn tại | File hoặc function không tìm thấy | File tồn tại nhưng function syntax sai |
| 2 | **Baseline Metrics** | Glob `.mc-data/work/shared-metrics/baseline-*.json` | ≥1 file tồn tại | 0 files | JSON invalid |
| 3 | **Context Digest** | Grep `context_digest` trong `.claude/skills/schemas/checkpoint-schema.json` | Field tồn tại | File hoặc field không tìm thấy | Schema JSON invalid |
| 4 | **Digest Pipeline (6 templates)** | Glob `.claude/doc-framework/_digests/*.template.json` | 6 files tồn tại | <6 files (ghi N/6) | Files tồn tại nhưng JSON invalid |
| 5 | **A6-EXT** | Grep `A6-EXT` trong `.claude/doc-framework/phase5-implementation/tasks/**/*` | Pattern tìm thấy | Không tìm thấy | — |
| 6 | **A7-EXT** | Grep `A7-EXT` trong `.claude/doc-framework/phase5-implementation/tasks/**/*` | Pattern tìm thấy | Không tìm thấy | — |
| 7 | **Parallel (Phase 2.5)** | Grep `Phase 2.5` hoặc `--parallel` trong `.claude/skills/workflow/wf-implement-feature/SKILL.md` | Pattern tìm thấy | Không tìm thấy | — |
| 8 | **--features flag** | Grep `--features` trong `.claude/skills/workflow/wf-implement-feature/SKILL.md` | Pattern tìm thấy | Không tìm thấy | — |

**Output format per component:**
```json
{
  "id": 1,
  "name": "Hook 2-Tầng",
  "status": "OK | MISSING | BROKEN",
  "evidence": "[path + grep/glob result]"
}
```

Lưu vào `$MASTER_PLAN_STATUS.components[]`.

---

## Step 3.5.4: Backward Compatibility Check

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.5.4a | Đếm tổng workflow skills: `Glob .claude/skills/workflow/*/SKILL.md` → `$TOTAL_SKILLS`. Đếm có `_contract.json` JSON-valid: `Glob .claude/skills/workflow/*/_contract.json` → mỗi file `jq -e '.' <file> >/dev/null 2>&1` → `$VALID_CONTRACTS` | Glob + Bash | `$VALID_CONTRACTS/$TOTAL_SKILLS` valid |
| 3.5.4b | Verify `--parallel` default = OFF (không phá flow cũ) | Grep | Default OFF |
| 3.5.4c | Verify `--features` là optional (không phá single-feature flow) | Grep | Optional confirmed |
| 3.5.4d | Ghi: `$MASTER_PLAN_STATUS.backward_compat = { contracts: "$VALID_CONTRACTS/$TOTAL_SKILLS", contracts_ratio: <0.0-1.0>, parallel_default: "OFF"\|"ON", features_optional: true\|false }` | — | Recorded |

> **Quy tắc verdict cho contracts:** `contracts_ratio = $VALID_CONTRACTS / $TOTAL_SKILLS`. Verdict component PASS khi `contracts_ratio == 1.0`. WARNING khi `≥ 0.95`. FAIL khi `< 0.95`. Số skills KHÔNG hardcode — phụ thuộc state thực tế của repo.

---

## Step 3.5.5: Tổng hợp kết quả Master Plan

| Step | Action | Verify |
|------|--------|--------|
| 3.5.5a | Đếm components theo status: `OK_count`, `MISSING_count`, `BROKEN_count` | Counts |
| 3.5.5b | Tính Master Plan verdict theo bảng §2 trong `_shared.md`: | Verdict computed |
| | — Tất cả 8 components OK + schema 15/15 pass → **`MP-CLEAN`** | |
| | — ≥6 components OK, 0 BROKEN → **`MP-ACCEPTABLE`** | |
| | — Bất kỳ BROKEN → **`MP-NEEDS-ATTENTION`** | |
| | — ≥3 MISSING → **`MP-INCOMPLETE`** | |
| 3.5.5c | Lưu: `$MASTER_PLAN_STATUS.verdict = <computed>` | Recorded |
| 3.5.5d | Hiển thị tóm tắt cho user: `"Master Plan: [OK_count]/8 components OK — Verdict: $verdict"` | Displayed |

---

## POST-GATE

| Check | Required |
|-------|----------|
| `$MASTER_PLAN_STATUS` object populated với đủ 4 sections: schema_sync, gate_reports, components, backward_compat | ✓ |
| `$MASTER_PLAN_STATUS.verdict` ∈ {`MP-CLEAN`, `MP-ACCEPTABLE`, `MP-NEEDS-ATTENTION`, `MP-INCOMPLETE`} | ✓ |

---

## Errors

| Code | Tình huống | Action |
|------|------------|--------|
| E009 | `validate-schema-sync.sh` không tồn tại | WARNING: "Schema sync script chưa triển khai", schema_sync = MISSING |
| — | Script chạy nhưng có failures | Ghi nhận số fail, tiếp tục các components khác |
| — | Gate report không tồn tại | Component = MISSING (không phải error — có thể chưa chạy gate verification) |
| — | Grep command fail runtime | WARNING: "Check [component] fail" + component status = BROKEN với lý do |
