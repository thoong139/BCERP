# Navigation: Sales Workspace — BCERP Web

> **System ID:** SYS-BCERP-WEB | **Workspace:** Sales (`/sales`) — DEPT-SALES
> **Ngày:** 13/09/2026 (R3 — workspace folder structure)
>
> READS: `../Navigation-bcerp-web.md`, `../../design-system.md`, `../../../phase2-features/bcerp-web/`, `../../../phase3-architecture/P3-01-architecture.md`
> USED BY: `crm/screens-*.md`, `qdd/screens-deal-desk.md`, `comm/screens-commission.md`, `../Navigation-bcerp-web.md`

> Navigation cấp workspace — con của `Navigation-bcerp-web.md` (§1.0 Bảng A/B). Workspace Sales phục vụ **Phòng Kinh Doanh (DEPT-SALES)**: SALES_L1–L3 (+L4/L5 [NEEDS_REVIEW #8]). Phân hệ: MOD-CRM-PIPELINE (11 FEAT) · MOD-QUOTATION-DEALDESK (6) · MOD-COMMISSION-QUOTA (3) = **20 FEAT sở hữu** + MOD-HANDOFF-ONBOARD (6, shared với Ops). Trang đích workspace = **S1 My Pipeline**.

---

## 1. Sơ Đồ Menu (Menu Tree)

```
SALES (/sales) — quick: Ghi nhận lead · Tạo quote · Submit handoff
│
├── My Pipeline (worklist lead/deal)         → /sales/pipeline            → crm/screens-pipeline.md         [{leads_moi} {deals_cho_gate}]
│   └── Lead 360 (detail pane của S1)        → /sales/pipeline/leads/:id  → crm/screens-lead-360.md
├── Deal Desk (quote + duyệt + e-sign)       → /sales/deal-desk           → qdd/screens-deal-desk.md        [{quotes_cho_duyet}]
├── Commission (mine / team)                 → /sales/commission          → comm/screens-commission.md
├── Handoff Bridge (shared Ops — menu entry) → /ops/handoff               → ../ops/honb/screens-handoff-bridge.md [{handoff_cho_ack}]
└── Client 360 (shared hub — KHÔNG mục menu, mở từ link) → /sales/clients/:id → crm/screens-client-360.md
```

- Quick action "Submit handoff" nhảy thẳng `/ops/handoff` (surface shared, 2 role views — file spec nằm thư mục Ops).
- Client 360 (S28) là hub mở từ mọi surface có khách hàng — không xuất hiện trong nav rail.

## 2. Danh Sách Screen Groups

| # | Screen Group | Route | File | UI-ID | Module |
|---|---|---|---|---|---|
| S1 | My Pipeline (worklist lead/deal) | `/sales/pipeline` | `crm/screens-pipeline.md` | `UI-WEB-LEAD-001` | MOD-CRM-PIPELINE |
| S2 | Lead 360 (detail pane của S1) | `/sales/pipeline/leads/:id` | `crm/screens-lead-360.md` | `UI-WEB-LEAD-002` | MOD-CRM-PIPELINE |
| S3 | Deal Desk (quote + duyệt + e-sign) | `/sales/deal-desk` | `qdd/screens-deal-desk.md` | `UI-WEB-DEAL-001` | MOD-QUOTATION-DEALDESK |
| S5 | Commission (mine / team) | `/sales/commission` | `comm/screens-commission.md` | `UI-WEB-COMM-001` | MOD-COMMISSION-QUOTA |
| S28 | Client 360 (shared surface) | `/sales/clients/:id` | `crm/screens-client-360.md` | `UI-WEB-CLIENT-001` | MOD-CRM-PIPELINE (link MOD-CLIENT-PORTAL) |
| S4 | Handoff Bridge (shared Sales↔Ops) | `/ops/handoff` | `../ops/honb/screens-handoff-bridge.md` | `UI-WEB-HONB-001` | MOD-HANDOFF-ONBOARD |

> S2 là master-detail pane của S1 (không page rời). S4 đứng về Ops về mặt thư mục/surface nhưng có menu entry tại Sales — nút Submit hiển thị theo role SALES.

## 3. Phân Quyền & Hiển Thị Menu

| Mục menu | Route | Roles thấy | Hành động theo permission | Badge | Điều kiện hiển thị |
|---|---|---|---|---|---|
| My Pipeline | `/sales/pipeline` | SALES_L1 (mine) · L2/L3 (team) | Advance/reject gate: L2/L3; reassign: L2+ | `{leads_moi}` `{deals_cho_gate}` | Luôn |
| Lead 360 | `/sales/pipeline/leads/:id` | như S1 | Gate action ẩn nếu không phải L2/L3 | — | Pane của S1 |
| Deal Desk | `/sales/deal-desk` | SALES_L1–L3 | Duyệt chiết khấu theo định mức; vượt định mức → GM [NR: tạm SALES_L3]; e-sign | `{quotes_cho_duyet}` | Luôn |
| Commission | `/sales/commission` | SALES_L1 (mine) · L2/L3 (team+quota) · FIN_L1/L2 (read, kiểm chứng) | Read + drill-down deal nguồn | `{clawback}` khi có | Luôn |
| Handoff Bridge | `/ops/handoff` | SALES_L1–L3 + toàn bộ OPS | Nút Submit (SALES) / Ký nhận (OPS_AM) theo role | `{handoff_cho_ack}` (SALES) | Menu entry ở cả Sales + Ops |

[NEEDS_REVIEW #8] SALES_L4/L5: menu ẩn toàn phần chờ BOD chốt; khi bật → thấy S1–S5, S28 theo matrix Navigation gốc §3.

## 4. UI Notes

### 4.1. Quick Actions

| Action | Mở gì | Ghi chú |
|---|---|---|
| Ghi nhận lead | Dialog tạo lead (S1 context) | `Ctrl+N` context-aware |
| Tạo quote | Deal Desk mode Create (S3) | — |
| Submit handoff | `/ops/handoff` (S4) | Chỉ khi deal đã ký |

### 4.2. Breadcrumb & Pattern

- Breadcrumb: `Sales > My Pipeline > [Lead #mã]` · `Sales > Deal Desk > [Quote #mã]` — object luôn hiển thị mã nghiệp vụ.
- Pattern chính: W2 split view 40/60 (S1 + Lead 360 pane); W3 content + panel phải 360px (S3, S28 — WaitingOn + ProgressTracker + Timeline).
- WaitingOn bắt buộc: chờ GM duyệt chiết khấu (S3) · chờ OPS ký nhận handoff (S4) · chờ FIN thu tiền → commission (S5).
- Icon workspace: `target` (Lucide) — nav rail active state.

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| Navigation tổng quan hệ thống (workspace map, §1.0) | `../Navigation-bcerp-web.md` |
| Thiết kế chi tiết màn hình | `crm/screens-*.md`, `qdd/screens-deal-desk.md`, `comm/screens-commission.md` |
| Handoff Bridge (surface shared, thư mục Ops) | `../ops/honb/screens-handoff-bridge.md` |
| API endpoints | `../../../phase3-architecture/technical-specs/api-contract.md` |
| Design system | `../../design-system.md` |
| REQ-IDs / FEAT | `../../../_meta/req-registry.json` |
