# Navigation: Executive Workspace — BCERP Web

> **System ID:** SYS-BCERP-WEB | **Workspace:** Executive (`/exec`) — DEPT-BOD
> **Ngày:** 13/09/2026 (R3 — workspace folder structure)
>
> READS: `../Navigation-bcerp-web.md`, `../../design-system.md`, `../../../phase2-features/bcerp-web/`, `../../../phase3-architecture/P3-01-architecture.md`
> USED BY: `datahub/screens-executive-bi.md`, `datahub/screens-alert-center.md`, `../Navigation-bcerp-web.md`

> Navigation cấp workspace — con của `Navigation-bcerp-web.md` (§1.0 Bảng A/B). Workspace Executive phục vụ **Ban Điều Hành (DEPT-BOD)**: BOD_CEO, BOD_CFO_CTO. Phân hệ: MOD-DATAHUB-BI = **15 FEAT** (+ oversight audit qua S25 — surface thuộc workspace Admin). Trang đích workspace = **S23 Executive BI**. Dashboard action-oriented: mọi số liệu click ra được worklist nguồn.

---

## 1. Sơ Đồ Menu (Menu Tree)

```
EXECUTIVE (/exec) — quick: Duyệt escalation · Drill-down về nguồn
│
├── Executive BI (tabs: P&L realtime · Phòng ban) → /exec/bi     → datahub/screens-executive-bi.md
└── Alert Center (escalation, role-scoped)         → /exec/alerts → datahub/screens-alert-center.md  [{escalation_timeout}]
```

- P&L realtime ràng buộc ≤5 phút (freshness hiển thị tại từng widget) — cùng bề mặt tiêu thụ BI nên là 2 tab.
- Alert Center là escalation inbox cross-module — worklist, không phải chart; manager (SALES_L2+, HR_L2, OPS_AM, FIN_L2) thấy scope của mình.

## 2. Danh Sách Screen Groups

| # | Screen Group | Route | File | UI-ID | Module |
|---|---|---|---|---|---|
| S23 | Executive BI (tabs: P&L realtime / Phòng ban) | `/exec/bi` | `datahub/screens-executive-bi.md` | `UI-WEB-BI-001` | MOD-DATAHUB-BI |
| S24 | Alert Center | `/exec/alerts` | `datahub/screens-alert-center.md` | `UI-WEB-ALERT-001` | MOD-DATAHUB-BI + MOD-SLA-NOTIF |

> S25 Audit Log Query (BOD oversight) dùng chung route `/admin/audit` với SYS_ADMIN — 1 surface 2 role views, thuộc workspace Admin: `../admin/Navigation-admin.md`.

## 3. Phân Quyền & Hiển Thị Menu

| Mục menu | Route | Roles thấy | Hành động theo permission | Badge | Điều kiện hiển thị |
|---|---|---|---|---|---|
| Executive BI | `/exec/bi` | BOD_CEO · BOD_CFO_CTO · FIN_L1/L2 (read) | Drill-down về worklist nguồn, export | — | Luôn |
| Alert Center | `/exec/alerts` | BOD · manager role-scoped (SALES_L2+, HR_L2, OPS_AM, FIN_L2) | Ack, escalate, jump object nguồn | `{escalation_timeout}` | Có escalation trong scope |

- Duyệt vượt ngưỡng (lệnh chi >200tr, escalation cuối) thực hiện tại S6 Finance theo quyền BOD — deep-link từ Alert Center.

## 4. UI Notes

### 4.1. Quick Actions

| Action | Mở gì | Ghi chú |
|---|---|---|
| Duyệt escalation | S24 → jump object nguồn (S6/S7/S16) | Không duyệt ngay trong alert — giữ ngữ cảnh đầy đủ |
| Drill-down về nguồn | S23 widget → worklist đã lọc | Mọi KPI click ra được |

### 4.2. Breadcrumb & Pattern

- Breadcrumb: `Executive > Executive BI > [Widget → worklist]`; Alert Center jump về object giữ nút "Về nguồn".
- Pattern: S23 = W4 dashboard grid (KPI row → widget 12 cột, spacious, max 1600px); S24 = khung trên W4 (KPI/SLA row) + thân W1 escalation inbox.
- Freshness ≤5 phút hiển thị tại widget; SYS_ADMIN deep-link backfill → `/settings` (workspace Settings).
- Icon workspace: `bar-chart-3` (Lucide).

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| Navigation tổng quan hệ thống (workspace map, §1.0) | `../Navigation-bcerp-web.md` |
| Thiết kế chi tiết màn hình | `datahub/screens-executive-bi.md`, `datahub/screens-alert-center.md` |
| Audit Log Query (BOD oversight) | `../admin/rbac/screens-audit-log.md` |
| Integration & Settings (backfill/replay) | `../settings/stgw/screens-integrations-settings.md` |
| API endpoints | `../../../phase3-architecture/technical-specs/api-contract.md` |
| Design system | `../../design-system.md` |
| REQ-IDs / FEAT | `../../../_meta/req-registry.json` |
