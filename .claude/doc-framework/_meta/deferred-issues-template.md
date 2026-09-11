# Deferred Issues

> Template cho cac van de duoc hoan lai tu skill truoc sang skill sau.
> Producer: `/wf-analyze-requirements` (Phase 6d)
> Consumer: `/wf-define-features` (Phase 0 — input)
>
> **Output Path:** `.mc-data/work/wf-analyze-requirements/deferred-issues.md`
> **Producer:** `/wf-analyze-requirements` Phase 6d
> **Consumer:** `/wf-define-features` Phase 0 (input context)

## Metadata

| Field | Value |
|-------|-------|
| **Producer Skill** | `/wf-analyze-requirements` |
| **Created** | `<ISO date>` |
| **Total Issues** | `<N>` |
| **Blocking Count** | `<N>` |

## Vấn đề

> Danh sách các vấn đề được hoãn từ skill trước. Mỗi vấn đề có severity và category rõ ràng.

### Bối cảnh

[Nguyên nhân các issues được defer — VD: "Cần quyết định từ stakeholder về phạm vi module X"]

---

## Giải pháp đề xuất

| # | Vấn đề | Giải pháp đề xuất | Ưu tiên |
|---|--------|------------------|---------|
| 1 | DI-001: [Title] | [Giải pháp] | BLOCKING / HIGH / MEDIUM / LOW |
| 2 | DI-002: [Title] | [Giải pháp] | [Ưu tiên] |

---

## Issues

### DI-001: `<Issue Title>`

| Field | Value |
|-------|-------|
| **Severity** | `BLOCKING` / `HIGH` / `MEDIUM` / `LOW` |
| **Category** | `scope_ambiguity` / `conflicting_requirements` / `missing_info` / `stakeholder_decision` / `technical_feasibility` |
| **Related REQ-IDs** | `REQ-XXX-001`, `REQ-XXX-002` |
| **Description** | Mo ta van de cu the |
| **Impact** | Anh huong den gi neu khong giai quyet |
| **Suggested Action** | De xuat cach giai quyet |
| **Resolution** | `<PENDING>` / `<Resolved: ...>` |

<!-- Lap lai cho moi issue -->

---

## Summary

| Severity | Count | Resolved |
|----------|-------|----------|
| BLOCKING | 0 | 0 |
| HIGH | 0 | 0 |
| MEDIUM | 0 | 0 |
| LOW | 0 | 0 |
