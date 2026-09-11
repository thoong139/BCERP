# Deferred Findings

> Template cho các phát hiện được hoãn lại từ skill trước sang skill sau.
> Producer: `/wf-define-features` (Phase 4) hoac `/wf-design` (Phase 4c)
> Consumer: `/wf-design` (Phase 0) hoac `/wf-plan-modules` (Phase 0)
>
> **Output paths theo producer skill:**
> - `/wf-define-features` → `.mc-data/work/wf-define-features/deferred-findings.md`
> - `/wf-design` → `.mc-data/work/wf-design/deferred-findings.md`
>
> Mỗi skill ghi vào thư mục riêng của mình. Consumer skills đọc từ đúng path của producer.

## Metadata

| Field | Value |
|-------|-------|
| **Producer Skill** | `/wf-define-features` hoặc `/wf-design` |
| **Created** | `<ISO date>` |
| **Total Findings** | `<N>` |
| **Blocking Count** | `<N>` |

## Mô tả

[Bối cảnh và lý do findings được defer — VD: "Cần input từ stakeholder trước khi quyết định hướng thiết kế"]

---

## Phát hiện

> Chi tiết các findings được hoãn. Mỗi finding có cấu trúc riêng bên dưới.

### DF-001: `<Finding Title>`

| Field | Value |
|-------|-------|
| **Severity** | `BLOCKING` / `HIGH` / `MEDIUM` / `LOW` |
| **Category** | `design_conflict` / `scope_creep` / `technical_debt` / `dependency_gap` / `integration_concern` / `performance_risk` |
| **Related IDs** | `FEAT-XXX-001`, `REQ-XXX-001` |
| **Description** | Mô tả phát hiện cụ thể |
| **Impact** | Ảnh hưởng đến downstream skill |
| **Suggested Action** | Đề xuất cách xử lý |
| **Resolution** | `<PENDING>` / `<Resolved: ...>` |

<!-- Lặp lại cho mỗi finding -->

---

## Khuyến nghị

| # | Khuyến nghị | Ưu tiên | Ghi chú |
|---|------------|---------|---------|
| 1 | [Đề xuất xử lý] | HIGH / MEDIUM / LOW | [Ghi chú thêm] |
| 2 | [Đề xuất xử lý] | [Ưu tiên] | [Ghi chú] |

---

## Trạng thái

> Tổng hợp trạng thái tất cả findings — tự động cập nhật khi findings được resolve.

| Trạng thái | Số lượng |
|-----------|---------|
| PENDING | [N] |
| Resolved | [N] |
| Escalated | [N] |

---

## Summary

| Severity | Count | Resolved |
|----------|-------|----------|
| BLOCKING | 0 | 0 |
| HIGH | 0 | 0 |
| MEDIUM | 0 | 0 |
| LOW | 0 | 0 |

## Consumer Notes

> Skill downstream (consumer) ghi notes khi doc file nay:
> - Vấn đề nào đã được giải quyết trong phase hiện tại
> - Vấn đề nào cần escalate tiếp
