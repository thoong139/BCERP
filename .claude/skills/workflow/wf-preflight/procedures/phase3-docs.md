# Phase 3: Document Completeness Check (PARALLEL với Phase 2)

> **Protocol:** Xem `.claude/skills/protocols/`
> **Shared:** Xem `procedures/_shared.md` — State Variables, Scoring Formulas

Kiểm tra tất cả docs yêu cầu cho scope đã được tạo và không rỗng.

---

## PRE-GATE

```
test -d ".mc-data/docs"
```

`$TARGET_SYSTEMS`, `$TARGET_FEATURES` (từ Phase 1) đã set.

> **Lưu ý:** Output là `$DOC_ISSUES` (in-memory). Không tạo file.

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 3.1 | Check Phase 0 docs (nếu scope = all): `P0-01-brainstorm.md`, `P0-02-systems-users.md` | Files exist + non-empty |
| 3.2 | Check Phase 1 docs cho scope: `P1-01-project-overview.md`, dept docs trong scope | Files exist + non-empty |
| 3.3 | Check Phase 2 docs: `phase2-features/[sys]/[mod]/[feat].md` cho từng `$TARGET_FEATURES` **có `impl_status != "skipped"`** | Feature docs exist (skipped features excluded) |
| 3.4 | Check Phase 3 docs (nếu có code): `P3-01-architecture.md`, `api-contract.md`, `database-design.md` | Arch docs exist |
| 3.5 | Check Phase 4 docs (chỉ nếu `$INTERFACE_TYPE != "api-only"`): navigation files cho target systems | UX docs exist (skip hoàn toàn nếu api-only) |
| 3.6 | Check Phase 5 docs: `tasks/[sys]/[mod]/[feat]-impl.md` cho từng `$TARGET_FEATURES` **có `impl_status != "skipped"`** | Impl plans exist (skipped features excluded) |
| 3.7 | Check stakeholder-review.md cho các phases đã hoàn thành (phase0_completed, etc.) | Reviews present |
| 3.8 | Tính `docs_score` theo công thức (xem `_shared.md` §Scoring Formulas) — denominator chỉ đếm docs của non-skipped features | Score calculated |

---

## Doc Requirement Matrix

| Phase | Required Docs | Scope áp dụng | Blocking? |
|-------|--------------|---------------|-----------|
| Phase 0 | `P0-01-brainstorm.md`, `P0-02-systems-users.md` | all | YES |
| Phase 1 | `P1-01-project-overview.md`, dept docs | all, system | NO (warn) |
| Phase 2 | `phase2-features/[sys]/[mod]/[feat].md` per feature | all, system, module, feature | YES |
| Phase 3 | `P3-01-architecture.md`, API contract, DB design | all, system | YES nếu có code |
| Phase 4 | Navigation-[sys].md per UI system | all, system (UI only) | NO (warn) |
| Phase 5 | `tasks/[sys]/[mod]/[feat]-impl.md` per feature | all, system, module, feature | YES nếu có code |

---

## Scoring

```
docs_score = (existing_required_docs / total_required_docs) × 100

Ví dụ:
  10/10 docs present → 100
  7/10 docs present  → 70
  3/10 docs present  → 30
```

> Xem `_shared.md` §Scoring Formulas — docs_score — đầy đủ.

---

## POST-GATE

```
test -n "$DOC_ISSUES"   # Phải set (dù 0 missing)
```

- `$DOC_ISSUES` = array (có thể rỗng `[]`)
- `$SCORES.docs_score` ∈ [0, 100]
- Status file `preflight-status.json`: `phases.phase_3.status = "completed"`

---

## Output → Next Phase

- `$DOC_ISSUES` (in-memory) — đọc bởi Phase 5b, 7
- `$SCORES.docs_score` — đọc bởi Phase 7

**Parallel Note:** Phase 3 chạy ĐỒNG THỜI với Phase 2. Cả 2 READ-ONLY trên registry + docs → không conflict.

**Next:** Sau khi Group A (Phases 2+3) hoàn thành → chạy Parallel Group B = Phase 4 (Code Sync) + Phase 5 (Quality).
