# Phase 5a: Cross-Validation (Auto-Correction Loop)

> Kiểm tra toàn diện: code nhất quán với feature design và requirements.
> Tự động lặp lại cho đến khi không còn lỗi — tối đa 3 iterations.
>
> **Protocol:** Xem `.claude/skills/protocols/` — Auto-Correction Loop Protocol
> **Protocol 8 (CQG-11):** REQ-ID match + test coverage ratio + architecture compliance
> **Protocol 12:** Decision Registry compliance check

**PRE-GATE:** Phase 4–5 PASSED (hoặc `--skip-review` đã set)

**📥 INPUT:** Feature design, source files, test files, `impl-status.json`

**📤 OUTPUT:** Fixed source/test files + `impl-report.md` (template: `templates/impl-report.md` — READ template → populate → WRITE)

---

## Validation Checks (mỗi iteration)

| Check | Action | Khi FAIL → Auto-Fix |
|-------|--------|----------------------|
| 5a.1 | Mỗi REQ-ID trong feature design → có `// REQ-ID:` trong source | Thêm REQ-ID comment |
| 5a.2 | Mỗi source file → có ít nhất 1 test file | Tạo test stub |
| 5a.3 | Tất cả tests pass | Re-run, fix obvious failures |
| 5a.4 | Không còn CRITICAL/HIGH issues | Re-apply fixes |
| 5a.5 | Source files không có TODO/FIXME placeholders | Điền implementation từ context |
| 5a.6 | `impl-status.json` consistent với actual files | Update status JSON |
| CQG-11.1 | **[CQG-11] REQ-ID Match:** Mỗi REQ-ID trong source PHẢI tồn tại trong registry và ngược lại | Thêm/sửa REQ-ID comment hoặc update registry |
| CQG-11.2 | **[CQG-11] Test Coverage Ratio:** `test_files / source_files >= 0.5` | Tạo test stub cho source files thiếu test |
| CQG-03 | **[CQG-03] Architecture Compliance:** API endpoints match `api-contract.md`, DB entities match `db-schema.md`, technology choices match architecture decisions | Log mismatch, escalate nếu sai kiến trúc |
| 5a.D | **[C2 Decision Registry] Compliance (Protocol 12.3):** Với mỗi file đã implement, check tất cả decisions có `applies_to` match. Nếu vi phạm → auto-fix obvious cases, escalate nếu không fix được | Auto-fix hoặc escalate |
| 5a.7 | IF có UI → spawn `evidence-collector` agent | Screenshot evidence |
| 5a.8 | IF performance-critical → spawn `performance-benchmarker` agent | Benchmark results |
| 5a.9 | Spawn `reality-checker` agent cho final integration check | Reality check PASS |

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 5a.0 | **[Template Rule]** READ `templates/impl-report.md` → xác định sections cần populate | Template loaded |
| 5a.10 | Populate template sections với validation results → WRITE/append vào `impl-report.md` (mỗi iteration) | Report updated |
| 5a.11 | Ghi tổng kết: iterations count, errors fixed, errors remaining | Summary logged |

---

## Iteration Loop

```
SET iteration = 1
WHILE iteration <= 3:
  Run all validation checks (5a.1 → 5a.D, 5a.7-9)
  Collect failures

  IF zero failures:
    → POST-GATE PASS → tiếp tục phase6-finalize.md

  ELSE:
    → Apply auto-fixes cho mỗi failure
    → Log iteration results vào impl-report.md
    → iteration += 1

IF iteration > 3 AND vẫn còn errors:
  → STOP — user acknowledged remaining errors
  → Log errors_remaining vào impl-report.md
```

---

## POST-GATE

Zero validation errors HOẶC user acknowledged remaining errors.

Cả 2 trường hợp đều được phép tiếp tục phase6-finalize.md — nhưng trong trường hợp user acknowledged, Phase 6 impl-report sẽ ghi rõ tình trạng outstanding issues.
