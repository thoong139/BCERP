# Phase 2: Registry Integrity Check (PARALLEL với Phase 3)

> **Protocol:** Xem `.claude/skills/protocols/`
> **Shared:** Xem `procedures/_shared.md` — Severity Mapping, Scoring Formulas

Kiểm tra tính toàn vẹn của `req-registry.json` — cấu trúc, ID format, cross-references.

---

## PRE-GATE

Registry loaded + valid JSON (từ Phase 1). `$TARGET_*` variables đã set.

> **Lưu ý:** Xử lý in-memory. Không tạo file mới — chỉ tích lũy `$REGISTRY_ISSUES`.

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 2.1 | Validate required fields: `project`, `systems`, `modules`, `requirements`, `features`, `id_format` | All fields present |
| 2.2 | Validate ID formats theo `registry.id_format`: REQ-[DEPT]-[NNN], FEAT-[SYS]-[MOD]-[NNN], MOD-[SYS]-[MOD], etc. | All IDs valid format |
| 2.3 | Check cross-references: `system.depends_on[]` → valid system IDs trong `registry.systems` | No dangling refs |
| 2.4 | Check no duplicate IDs trong `requirements[]`, `features[]`, `modules[]` | No duplicates |
| 2.5 | Validate `impl_status` values: chỉ `not_started`, `in_progress`, `done`, `skipped` (CORE-010) | Status values valid |
| 2.6 | Validate `design_status`, `ux_design_status`: chỉ `pending`, `in_progress`, `done` | Values valid |
| 2.7 | Filter issues theo target scope (nếu scope hẹp, chỉ report issues liên quan) | Issues scoped |
| 2.8 | Tính `registry_score` theo công thức (xem `_shared.md` §Scoring Formulas) | Score calculated |

---

## Severity Mapping

| Issue | Severity |
|-------|---------|
| JSON invalid / missing required fields | CRITICAL |
| Duplicate IDs | CRITICAL |
| Invalid ID format | HIGH |
| Dangling cross-reference | HIGH |
| Invalid status value | MEDIUM |

> Xem `_shared.md` §Severity Mapping để đầy đủ context.

---

## Scoring

```
registry_score = max(0, 100 - (CRITICAL×30 + HIGH×15 + MEDIUM×5))
```

> Xem `_shared.md` §Scoring Formulas — registry_score — ví dụ số học đầy đủ.

---

## POST-GATE

```
test -n "$REGISTRY_ISSUES"   # Phải set (dù 0 issues)
```

- `$REGISTRY_ISSUES` = array (có thể rỗng `[]` nếu không có issue)
- `$SCORES.registry_score` ∈ [0, 100]
- Status file `preflight-status.json`: `phases.phase_2.status = "completed"`

---

## Output → Next Phase

- `$REGISTRY_ISSUES` (in-memory) — đọc bởi Phase 5b, 6, 7
- `$SCORES.registry_score` — đọc bởi Phase 7

**Parallel Note:** Phase 2 chạy ĐỒNG THỜI với Phase 3 (Docs Completeness). Cả 2 đều READ-ONLY trên `$TARGET_*` + registry → không conflict.
