# Navigation: Ops Workspace — BCERP Web

> **System ID:** SYS-BCERP-WEB | **Workspace:** Ops (`/ops`) — DEPT-OPS
> **Ngày:** 13/09/2026 (R3 — workspace folder structure)
>
> READS: `../Navigation-bcerp-web.md`, `../../design-system.md`, `../../../phase2-features/bcerp-web/`, `../../../phase3-architecture/P3-01-architecture.md`
> USED BY: `honb/screens-handoff-bridge.md`, `adacc/screens-tkqc-registry.md`, `propln/screens-proposal-stagegate.md`, `camp/screens-campaigns.md`, `capts/screens-capacity-timesheet.md`, `cskh/screens-tickets.md`, `tiktok/screens-tiktok-monitor.md`, `slanot/screens-sla-policies.md`, `cport/screens-portal-accounts.md`, `../Navigation-bcerp-web.md`

> Navigation cấp workspace — con của `Navigation-bcerp-web.md` (§1.0 Bảng A/B). Workspace Ops phục vụ **Phòng Vận Hành Dự Án & Marketing Nội Bộ (DEPT-OPS)**: OPS_PLAN/AM/CONT/AD (+DES/EDIT/ADS [NEEDS_REVIEW #8]) — workspace lớn nhất với 9 surfaces. Phân hệ sở hữu: MOD-ADACCOUNT-CC (8 FEAT) · MOD-PROPOSAL-PLANNING (3) · MOD-CAMPAIGN-DELIVERABLE (10) · MOD-CAPACITY-TIMESHEET (5, duyệt ∥ HR) · MOD-TICKET-CSKH (5) · MOD-TIKTOK-SHOP (4) · MOD-SLA-NOTIF (5) · MOD-CLIENT-PORTAL (7) = **47 FEAT** + MOD-HANDOFF-ONBOARD (6, shared với Sales). Trang đích workspace = **S4 Handoff Bridge**.

---

## 1. Sơ Đồ Menu (Menu Tree)

```
OPS (/ops) — quick: Ký nhận handoff · Cấp phát TKQC (chỉ khi đã khớp tiền) · Lập campaign · Assign ticket
│
├── Handoff Bridge (shared Sales↔Ops)        → /ops/handoff         → honb/screens-handoff-bridge.md      [{handoff_cho_ky}]
├── TKQC Registry (shared — FIN read-only)   → /ops/ad-accounts      → adacc/screens-tkqc-registry.md      [{tkqc_cho_cap_phat}]
├── Proposal Stage-Gate Workspace            → /ops/proposals        → propln/screens-proposal-stagegate.md
├── Campaign & Deliverable                   → /ops/campaigns        → camp/screens-campaigns.md           [{deliverable_overdue}]
├── Capacity & Timesheet (duyệt ∥ HR)        → /ops/capacity         → capts/screens-capacity-timesheet.md [{timesheet_cho_duyet}] ¹
├── Ticket Queue (+ Ticket 360)              → /ops/tickets          → cskh/screens-tickets.md             [{sla_ve}]
├── TikTok Shop Monitor                      → /ops/tiktok-shop      → tiktok/screens-tiktok-monitor.md    [{tiktok_anomaly}]
├── SLA Policy Rules                         → /ops/sla-policies     → slanot/screens-sla-policies.md
└── Portal Accounts (client)                 → /ops/portal-accounts  → cport/screens-portal-accounts.md
```

¹ S15 thuộc cả Ops và HR — 1 route `/ops/capacity`, menu entry hiển thị ở cả 2 workspace với role view khác nhau (permission filter), file spec + menu HR xem `../hr/Navigation-hr.md`.

- Quick action "Cấp phát TKQC" chỉ render khi hard stop đã gỡ (đã khớp tiền tại S7 Finance) — ẩn, không disabled.
- SALES chỉ thấy S4 trong Ops; FIN chỉ thấy S9 (read) — theo permission.

## 2. Danh Sách Screen Groups

| # | Screen Group | Route | File | UI-ID | Module |
|---|---|---|---|---|---|
| S4 | Handoff Bridge (shared) | `/ops/handoff` | `honb/screens-handoff-bridge.md` | `UI-WEB-HONB-001` | MOD-HANDOFF-ONBOARD |
| S9 | TKQC Registry (Ad Account CC) | `/ops/ad-accounts` | `adacc/screens-tkqc-registry.md` | `UI-WEB-ADACC-001` | MOD-ADACCOUNT-CC |
| S13 | Proposal Stage-Gate Workspace | `/ops/proposals` | `propln/screens-proposal-stagegate.md` | `UI-WEB-PROPLN-001` | MOD-PROPOSAL-PLANNING |
| S14 | Campaign & Deliverable | `/ops/campaigns` | `camp/screens-campaigns.md` | `UI-WEB-CAMP-001` | MOD-CAMPAIGN-DELIVERABLE |
| S15 | Capacity & Timesheet (duyệt ∥ HR) | `/ops/capacity` | `capts/screens-capacity-timesheet.md` | `UI-WEB-CAPTS-001` | MOD-CAPACITY-TIMESHEET |
| S16 | Ticket Queue + Ticket 360 | `/ops/tickets` | `cskh/screens-tickets.md` | `UI-WEB-TICK-001` | MOD-TICKET-CSKH |
| S17 | TikTok Shop Monitor (+ tab Gate-Workflow T2) | `/ops/tiktok-shop` | `tiktok/screens-tiktok-monitor.md` | `UI-WEB-TTSHOP-001` | MOD-TIKTOK-SHOP |
| S18 | SLA Policy Rules | `/ops/sla-policies` | `slanot/screens-sla-policies.md` | `UI-WEB-SLA-001` | MOD-SLA-NOTIF |
| S19 | Portal Accounts (client) | `/ops/portal-accounts` | `cport/screens-portal-accounts.md` | `UI-WEB-PORTAL-001` | MOD-CLIENT-PORTAL |

> S17 tab T2 (Gate-Workflow TikTok Shop) thêm sau F-D-01 — vai ký Gate 2 [NEEDS_REVIEW #8]. Client-facing portal (P1–P4) thuộc hệ portal riêng, không nằm đây — S19 chỉ quản trị account nội bộ.

## 3. Phân Quyền & Hiển Thị Menu

| Mục menu | Route | Roles thấy | Hành động theo permission | Badge | Điều kiện hiển thị |
|---|---|---|---|---|---|
| Handoff Bridge | `/ops/handoff` | SALES_L1–L3 + toàn bộ OPS | Nút Submit (SALES) / Ký nhận (OPS_AM) theo role | `{handoff_cho_ky}` (OPS) | Menu entry ở cả Sales + Ops |
| TKQC Registry | `/ops/ad-accounts` | OPS_AM (thao tác) · OPS khác (view) · FIN_L1/L2 (read-only) | KYC, yêu cầu cấp phát — nút ẩn khi chưa khớp tiền | `{tkqc_cho_cap_phat}` | Luôn |
| Proposal Stage-Gate | `/ops/proposals` | OPS_PLAN (soạn+duyệt) · OPS_AD/AM (view) · DES/EDIT/ADS contribute [NR] | Advance/duyệt gate | `{gate_cho_duyet}` | Permission PROPLN |
| Campaign & Deliverable | `/ops/campaigns` | OPS_AM (lập) · OPS_CONT (thực hiện) · DES/EDIT/ADS [NR] | Update deliverable, nghiệm thu (window 3 ngày), báo cáo | `{deliverable_overdue}` | Permission CAMP |
| Capacity & Timesheet | `/ops/capacity` | OPS_AM + HR_L1/L2 (1 queue, permission filter) | Duyệt/từ chối theo vai | `{timesheet_cho_duyet}` | Menu ở cả Ops + HR |
| Ticket Queue | `/ops/tickets` | OPS_CONT (xử lý) · OPS_AD/AM (view, reassign) | Assign, resolve, escalate | `{sla_ve}` | Permission CSKH |
| TikTok Shop Monitor | `/ops/tiktok-shop` | Toàn bộ vai OPS | Ack alert, drill-down; Gate workflow tab T2 [NR #8] | `{tiktok_anomaly}` | Permission TIKTOK |
| SLA Policy Rules | `/ops/sla-policies` | OPS_AM/OPS_PLAN (owner) · OPS_AD | CRUD rules | — | Permission SLANOT |
| Portal Accounts | `/ops/portal-accounts` | OPS_AM | Cấp/khóa, reset | — | Permission CPORT |

[NEEDS_REVIEW #8] OPS_DES/EDIT/ADS: menu ẩn toàn phần chờ BOD chốt; khi bật → S14 (contribute), S15 (view), S16 (view), S9 (đường OPS_ADS — xem F-C-04 tại `adacc/screens-tkqc-registry.md`).

## 4. UI Notes

### 4.1. Quick Actions

| Action | Mở gì | Ghi chú |
|---|---|---|
| Ký nhận handoff | S4 — queue chờ ký | Ack 2 phía + sinh onboarding tasks |
| Cấp phát TKQC | S9 — chỉ khi hard stop đã gỡ | Deep-link trạng thái khớp tiền từ S7 |
| Lập campaign | S14 — campaign 360 mode Create | — |
| Assign ticket | S16 — AssigneePicker lọc data-scope RBAC | SLA tier context |

### 4.2. Breadcrumb & Pattern

- Breadcrumb: `Ops > TKQC Registry > [Ad Account #mã]` · `Ops > Campaign & Deliverable > [Campaign #mã]`.
- Pattern: S4/S16/S15 = W2 split view 40/60; S14 campaign 360 = W3 + panel phải; S9 = W1 standard; S13 = chế độ làm việc soạn + gate riêng.
- WaitingOn bắt buộc: chờ hard stop FIN (S9) · chờ SALES submit handoff (S4) · deliverable chờ nghiệm thu (S14) · SLA timer (S16).
- Banner cảnh báo ví (số dư < 3 ngày chi) hiển thị góc Ops — OPS không vào được S7.
- Icon workspace: `workflow` (Lucide).

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| Navigation tổng quan hệ thống (workspace map, §1.0) | `../Navigation-bcerp-web.md` |
| Thiết kế chi tiết màn hình | `honb/`, `adacc/`, `propln/`, `camp/`, `capts/`, `cskh/`, `tiktok/`, `slanot/`, `cport/` — `screens-*.md` |
| Ví & Đối soát (hành động khớp tiền, thư mục Finance) | `../finance/wallet/screens-wallet-recon.md` |
| HR view của S15 | `../hr/Navigation-hr.md` |
| API endpoints | `../../../phase3-architecture/technical-specs/api-contract.md` |
| Design system | `../../design-system.md` |
| REQ-IDs / FEAT | `../../../_meta/req-registry.json` |
