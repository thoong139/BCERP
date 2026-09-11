# Phase 4: Final Merge & Report

> Merge scan findings + verify findings, dedup cross-source, compute verdict, generate report.
> Phase cuối cùng — áp dụng cho **MỌI SCOPE** (kể cả partial scopes vẫn chạy merge để tính verdict + report).

## PRE-GATE

- Phase 0 POST-GATE pass
- Findings files cho scope đã chọn đều tồn tại và valid:
  - `$SCOPE = crossref` → 4 `findings-crossref-*.json`
  - `$SCOPE = workflow` → `findings-workflow.json`
  - `$SCOPE = consistency` → `findings-consistency.json`
  - `$SCOPE = master-plan` → `findings-masterplan-verify.json`
  - `$SCOPE = skill` → `findings-crossref-$FOCUSED_SKILL.json` + `findings-workflow.json` + `findings-consistency.json`
  - `$SCOPE = all` → tất cả findings files

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.1 | Đọc `$SCAN_DIR/audit-scan-result.json` (scan findings) — CHỈ nếu `$SCOPE = all` | Read | loaded or skipped |
| 4.2 | Đọc các `findings-crossref-*.json` (theo scope) | Read | loaded |
| 4.3 | Đọc `findings-workflow.json` (nếu chạy Phase 2) | Read | loaded |
| 4.4 | Đọc `findings-consistency.json` (nếu chạy Phase 3) | Read | loaded |
| 4.4b | Đọc `findings-masterplan-verify.json` (nếu chạy Phase 3.5) | Read | loaded (or empty if skipped) |
| 4.5 | Merge tất cả findings arrays thành 1 list | - | merged |
| 4.6 | **Tier 3 cross-source dedup**: So sánh scan findings vs verify findings. Cùng `file` + cùng `issue` (text similarity >70%) → giữ finding từ verify (chi tiết hơn cross-ref evidence). Populate `dedup_log[]` với `source: "scan"` hoặc `source: "verify"` | - | deduped |
| 4.7 | Final severity classification: sort `CRITICAL` → `MAJOR` → `MINOR` | - | sorted |
| 4.8 | Compute `verdict_pre_fix` theo bảng trong `_shared.md §Verdict Computation` | - | verdict determined |
| 4.9 | Tính summary counts (from_scan, from_crossref, from_workflow, from_consistency, from_master_plan, deduped, final_total, critical, major, minor, auto_fixable, manual) | - | summary computed |
| 4.10 | Write `$VERIFY_DIR/audit-verified-result.json` (schema `audit-verified-result-v1` — xem `_shared.md §Schemas`) | Write | File created |
| 4.11 | Validate: `jq '.' audit-verified-result.json` | Bash | exit code 0 |
| 4.12 | Generate report: `.mc-data/work/audit-devkit-verify/reports/devkit-audit-[date].md` (template xem bên dưới) | Write | File created |
| 4.13 | Hiển thị summary + verdict cho user | Output | Displayed |
| 4.14 | Hướng dẫn: "Chạy `/audit-devkit-fix` để auto-fix [N] issues" | Output | Displayed |
| 4.15 | Update `verify-status.json`: `status: "completed"`, `completed_at: "<ISO timestamp>"` | Write | Updated |

## Scope-Specific Behavior

| Scope | Merge behavior |
|-------|---------------|
| `crossref` | Chỉ merge 4 crossref findings (không scan findings). Verdict tính trên crossref only |
| `workflow` | Chỉ merge workflow findings. Verdict tính trên workflow only |
| `consistency` | Chỉ merge consistency findings. Verdict tính trên consistency only |
| `master-plan` | Chỉ merge masterplan findings. Verdict tính trên masterplan only |
| `skill` | Merge focused-crossref + workflow + consistency (target skill only). Verdict tính trên combined |
| `all` | Full merge (scan + crossref × 4 + workflow + consistency + masterplan) với dedup cross-source |

## Report Template

```markdown
## /audit-devkit-verify Hoàn tất!

| Mục | Giá trị |
|-----|---------|
| Scan findings (input) | [from_scan] |
| Cross-ref findings | [from_crossref] |
| Workflow findings | [from_workflow] |
| Consistency findings | [from_consistency] |
| Master Plan findings | [from_master_plan] *(0 nếu not deployed)* |
| Deduped | [deduped] |
| **Final total** | **[final_total]** (CRITICAL: [n], MAJOR: [n], MINOR: [n]) |
| Auto-fixable | [auto_fixable] |
| Manual required | [manual] |
| **Verdict** | **[verdict_pre_fix]** |

### Breakdown by Source

| Source | Findings | CRITICAL | MAJOR | MINOR |
|--------|----------|----------|-------|-------|
| Scan (component audit) | [n] | [n] | [n] | [n] |
| Cross-ref: agents↔skills | [n] | [n] | [n] | [n] |
| Cross-ref: skills↔templates | [n] | [n] | [n] | [n] |
| Cross-ref: docs | [n] | [n] | [n] | [n] |
| Cross-ref: hooks | [n] | [n] | [n] | [n] |
| Workflow integrity | [n] | [n] | [n] | [n] |
| Bidirectional consistency | [n] | [n] | [n] | [n] |
| **Master Plan components** | [n] | [n] | [n] | [n] |

### Master Plan Components Status *(section chỉ hiện nếu Phase 3.5 chạy)*

| Check | Status | Findings |
|-------|--------|----------|
| V1: Hook 2-Tầng Integrity | OK / ISSUES / SKIPPED | [n] |
| V2: Checkpoint Schema Consistency | OK / ISSUES / SKIPPED | [n] |
| V3: Digest Pipeline Integrity | OK / ISSUES / SKIPPED | [n] |
| V4: A6-EXT ↔ A7-EXT Consistency | OK / ISSUES / SKIPPED | [n] |
| V5: Parallel Execution Safety | OK / ISSUES / SKIPPED | [n] |
| V6: Backward Compatibility | OK / ISSUES / SKIPPED | [n] |

### Output Files

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | findings-crossref-agents-skills.json | $VERIFY_DIR | Cross-ref: agents ↔ skills |
| 2 | findings-crossref-skills-templates.json | $VERIFY_DIR | Cross-ref: skills ↔ templates |
| 3 | findings-crossref-docs.json | $VERIFY_DIR | Cross-ref: CLAUDE.md, rules |
| 4 | findings-crossref-hooks.json | $VERIFY_DIR | Cross-ref: hooks ↔ skills ↔ rules |
| 5 | findings-workflow.json | $VERIFY_DIR | Workflow integrity |
| 6 | findings-consistency.json | $VERIFY_DIR | Bidirectional consistency |
| 7 | findings-masterplan-verify.json | $VERIFY_DIR | Master Plan cross-checks (V1-V6) |
| 8 | audit-verified-result.json | $VERIFY_DIR | Final merged + verified results |
| 9 | devkit-audit-[date].md | $VERIFY_DIR/../reports/ | Human-readable report |

Next: `/audit-devkit-fix` để auto-fix [auto_fixable] issues
```

## POST-GATE

- `$VERIFY_DIR/audit-verified-result.json` tồn tại, JSON valid
- `.mc-data/work/audit-devkit-verify/reports/devkit-audit-[date].md` tồn tại
- `summary.final_total` = length of `findings[]`
- `verdict_pre_fix` computed correctly
- `verify-status.json.status = "completed"` + `completed_at` set

## Quy tắc BẮT BUỘC — verify-status.json completion

- Phase 4 step 4.15 **PHẢI** set `status: "completed"` + `completed_at: "<ISO timestamp>"` — KHÔNG bao giờ để "in_progress" sau khi Phase 4 hoàn thành
- Nếu `$SCOPE = "skill"` → **PHẢI** set `focused_skill: "<name>"` + `scope: "skill"` — KHÔNG dùng các giá trị scope khác như "focused" hay "skill-focused"
- `completed_phases[]` **PHẢI** reflect chính xác phases đã chạy — không thêm phases ngoài scope
- Với partial scope, `pending_phases[]` = `[]` khi Phase 4 hoàn thành (không list phases không chạy)

## Errors liên quan

- **E009** — Dedup conflict → giữ severity cao hơn. Cùng severity → giữ evidence cụ thể hơn
- **E010** — Write fail → retry 3 lần, escalate
- **E013** — scope=partial ghi sai completed_phases → fix: chỉ list phases thuộc scope

Chi tiết: `_shared.md §Error Handling Reference`.
