# Navigation: Platform Admin Workspace — BCERP Web

> **System ID:** SYS-BCERP-WEB | **Workspace:** Platform Admin (`/admin`) — quản trị đặc thù (không thuộc phòng ban nghiệp vụ)
> **Ngày:** 13/09/2026 (R3 — workspace folder structure)
>
> READS: `../Navigation-bcerp-web.md`, `../../design-system.md`, `../../../phase2-features/bcerp-web/`, `../../../phase3-architecture/P3-01-architecture.md`
> USED BY: `rbac/screens-rbac-admin.md`, `rbac/screens-audit-log.md`, `../Navigation-bcerp-web.md`

> Navigation cấp workspace — con của `Navigation-bcerp-web.md` (§1.0 Bảng A/B). Workspace **Platform Admin** là workspace quản trị đặc thù cho **quản trị truy cập & giám sát toàn hệ thống**: SYS_ADMIN (+BOD oversight). Phân hệ: MOD-RBAC-AUDIT = **18 FEAT**. Trang đích workspace = **S26 RBAC Admin**. Từ R2 (13/09) workspace này không còn chứa Settings — cấu hình tích hợp/tham số chuyển sang workspace Settings riêng (`../settings/Navigation-settings.md`).

---

## 1. Sơ Đồ Menu (Menu Tree)

```
PLATFORM ADMIN (/admin) — quick: Grant/revoke role · Mở access review · Tra cứu audit trail
│
├── RBAC Admin                               → /admin/rbac → rbac/screens-rbac-admin.md  [{access_review_due}]
└── Audit Log Query (BOD oversight dùng chung route) → /admin/audit → rbac/screens-audit-log.md
```

## 2. Danh Sách Screen Groups

| # | Screen Group | Route | File | UI-ID | Module |
|---|---|---|---|---|---|
| S26 | RBAC Admin | `/admin/rbac` | `rbac/screens-rbac-admin.md` | `UI-WEB-RBAC-001` | MOD-RBAC-AUDIT |
| S25 | Audit Log Query | `/admin/audit` | `rbac/screens-audit-log.md` | `UI-WEB-AUDIT-001` | MOD-RBAC-AUDIT |

> S25 = 1 surface 2 role views: SYS_ADMIN (vận hành query) · BOD_CEO/CFO_CTO (oversight đọc toàn hệ thống) — scope filter theo permission, không nhân bản.

## 3. Phân Quyền & Hiển Thị Menu

| Mục menu | Route | Roles thấy | Hành động theo permission | Badge | Điều kiện hiển thị |
|---|---|---|---|---|---|
| RBAC Admin | `/admin/rbac` | SYS_ADMIN | Grant/revoke, quarterly access review campaign, SSO/MFA config | `{access_review_due}` | Luôn |
| Audit Log Query | `/admin/audit` | SYS_ADMIN (vận hành) · BOD_CEO/CFO_CTO (oversight) | Filter, export, trail per object | — | 1 route, 2 role-view scope filter |

- 19 role toàn hệ thống quản trị tại S26; một user một role; action thiếu quyền bị ẩn (PEP).
- Audit log WORM append-only hash-chain — bắt buộc query window; trail per object jump từ mọi surface.

## 4. UI Notes

### 4.1. Quick Actions

| Action | Mở gì | Ghi chú |
|---|---|---|
| Grant/revoke role | S26 — user detail SidePanel | Mọi thay đổi ghi audit |
| Mở access review | S26 — review campaign Q | Badge đếm ngày còn lại |
| Tra cứu audit trail | S25 — filter theo object/actor/thời gian | Window bắt buộc |

### 4.2. Breadcrumb & Pattern

- Breadcrumb: `Platform Admin > RBAC Admin > [User #mã]` · `Platform Admin > Audit Log > [Object #mã]`.
- Pattern: Registry/admin — bảng standard + edit qua SidePanel 480px, comfortable.
- MFA TOTP nền cho phiên console vault (bước step-up nằm tại Settings); audit thao tác RBAC ghi hash-chain.
- Icon workspace: `shield-check` (Lucide — từ R2; trước đó `settings`, icon này đã chuyển cho workspace Settings).

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| Navigation tổng quan hệ thống (workspace map, §1.0) | `../Navigation-bcerp-web.md` |
| Thiết kế chi tiết màn hình | `rbac/screens-rbac-admin.md`, `rbac/screens-audit-log.md` |
| Settings & Integration Gateway (workspace riêng) | `../settings/stgw/screens-integrations-settings.md` |
| API endpoints | `../../../phase3-architecture/technical-specs/api-contract.md` |
| Design system | `../../design-system.md` |
| REQ-IDs / FEAT | `../../../_meta/req-registry.json` |
