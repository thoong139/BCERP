# Navigation: Finance Workspace — BCERP Web

> **System ID:** SYS-BCERP-WEB | **Workspace:** Finance (`/finance`) — DEPT-FINANCE
> **Ngày:** 13/09/2026 (R3 — workspace folder structure)
>
> READS: `../Navigation-bcerp-web.md`, `../../design-system.md`, `../../../phase2-features/bcerp-web/`, `../../../phase3-architecture/P3-01-architecture.md`
> USED BY: `wallet/screens-*.md`, `arap/screens-ar-ap.md`, `../Navigation-bcerp-web.md`

> Navigation cấp workspace — con của `Navigation-bcerp-web.md` (§1.0 Bảng A/B). Workspace Finance phục vụ **Phòng Tài chính - Kế toán (DEPT-FINANCE)**: FIN_L1/L2 (+CFO/CEO escalation). Phân hệ: MOD-WALLET-RECON (24 FEAT) · MOD-ARAP-PAYMENT (18) = **42 FEAT**. Trang đích workspace = **S6 Approval Inbox**. Bề mặt tiền giữ hộ — mọi đường xử lý tiền không animation, MFA step-up sau duyệt/khóa kỳ.

---

## 1. Sơ Đồ Menu (Menu Tree)

```
FINANCE (/finance) — quick: Khớp tiền · Duyệt lệnh (A/R) · Khóa kỳ · Phát hành HĐĐT
│
├── Approval Inbox (mọi lệnh chờ FIN)        → /finance/approvals  → wallet/screens-approval-inbox.md  [{pending_approvals}]
├── Ví & Đối soát (hard stop khớp tiền)      → /finance/wallet     → wallet/screens-wallet-recon.md    [{mismatch} {hardstop_cho_khop}]
└── Công nợ & Giải ngân (tabs: AR · AP-Giải ngân · HĐĐT) → /finance/ar-ap → arap/screens-ar-ap.md     [{aging_qua_han}]
```

- S6 là worklist tài chính duy nhất (dual approval, lệnh chi ngưỡng, điều chỉnh ví, hoàn tiền) — keyboard-first (A/R/↑↓/Enter, Space bulk).
- S7 giữ hard stop "khớp tiền TKQC" — hành động khớp tiền NẰM Ở ĐÂY; Ops chỉ thấy trạng thái read-only tại S9 (`../ops/adacc/screens-tkqc-registry.md`).

## 2. Danh Sách Screen Groups

| # | Screen Group | Route | File | UI-ID | Module |
|---|---|---|---|---|---|
| S6 | Approval Inbox (FIN) | `/finance/approvals` | `wallet/screens-approval-inbox.md` | `UI-WEB-APPR-001` | MOD-WALLET-RECON + MOD-ARAP-PAYMENT |
| S7 | Ví & Đối soát | `/finance/wallet` | `wallet/screens-wallet-recon.md` | `UI-WEB-WALLET-001` | MOD-WALLET-RECON |
| S10 | Công nợ & Giải ngân (tabs: AR / AP-Giải ngân / HĐĐT) | `/finance/ar-ap` | `arap/screens-ar-ap.md` | `UI-WEB-ARAP-001` | MOD-ARAP-PAYMENT |

> S12 (lệnh chi riêng) đã MERGE thành tab của S10; S8 (Hard Stop Panel) đã DROP → action trong S7 + trạng thái trong S9 (xem consolidation Navigation gốc §2).

## 3. Phân Quyền & Hiển Thị Menu

| Mục menu | Route | Roles thấy | Hành động theo permission | Badge | Điều kiện hiển thị |
|---|---|---|---|---|---|
| Approval Inbox | `/finance/approvals` | FIN_L1/L2 · BOD_CFO_CTO (CFO) · BOD_CEO (lệnh chi >200tr) | Approve/reject (A/R), delegate; dual approval khóa slot 2 đến khi đủ slot 1 | `{pending_approvals}` | Luôn |
| Ví & Đối soát | `/finance/wallet` | FIN_L1/L2 | Đối trừ 3 số, điều chỉnh (dual), khóa kỳ (L2), khớp tiền TKQC (FIN_L1) | `{mismatch}` `{hardstop_cho_khop}` | Luôn; OPS không thấy menu — chỉ nhận banner cảnh báo trong Ops |
| Công nợ & Giải ngân | `/finance/ar-ap` | FIN_L1/L2 | Duyệt theo ngưỡng 5/50/200tr + SoD 4 vai; HĐĐT; dunning | `{aging_qua_han}` | Luôn |

- Phiên duyệt tiền: FIN_L1 khởi tạo/đối trừ; FIN_L2 khóa kỳ; ngưỡng lệnh chi 5/50/200tr → L2 → CFO → CEO (state machine theo P3-01, không suy diễn UI).

## 4. UI Notes

### 4.1. Quick Actions

| Action | Mở gì | Ghi chú |
|---|---|---|
| Khớp tiền | S7-T4 (khớp tiền TKQC — gỡ hard stop) | Sau MFA step-up |
| Duyệt lệnh (A/R) | S6 — focus ApprovalCard kế | `A` duyệt / `R` từ chối (lý do ≥10 ký tự) |
| Khóa kỳ | S7 — confirm dual approval | FIN_L2 |
| Phát hành HĐĐT | S10 tab HĐĐT (TT78) | — |

### 4.2. Breadcrumb & Pattern

- Breadcrumb: `Finance > Approval Inbox > [Lệnh chi #mã]` · `Finance > Ví & Đối soát > [Sổ phụ #kỳ]`.
- Pattern: S6 = W1 worklist keyboard-first (compact); S7 = W1 variant chuẩn + dải đối trừ 3 số; S10 = W1 theo tab AR/AP/HĐĐT.
- MoneyDisplay mọi cột tiền; trạng thái tiền (mismatch, hard stop) = WarningIndicator banner + queue entry, không chỉ badge.
- Deep-link 2 chiều S7 ↔ S9 (trạng thái khớp tiền); Client 360 từ invoice aging (`../sales/crm/screens-client-360.md`).
- Icon workspace: `wallet` (Lucide).

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| Navigation tổng quan hệ thống (workspace map, §1.0) | `../Navigation-bcerp-web.md` |
| Thiết kế chi tiết màn hình | `wallet/screens-approval-inbox.md`, `wallet/screens-wallet-recon.md`, `arap/screens-ar-ap.md` |
| TKQC Registry (trạng thái khớp tiền, thư mục Ops) | `../ops/adacc/screens-tkqc-registry.md` |
| API endpoints | `../../../phase3-architecture/technical-specs/api-contract.md` |
| Design system | `../../design-system.md` |
| REQ-IDs / FEAT | `../../../_meta/req-registry.json` |
