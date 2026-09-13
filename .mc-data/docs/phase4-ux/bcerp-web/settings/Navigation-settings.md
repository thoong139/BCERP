# Navigation: Settings Workspace — BCERP Web

> **System ID:** SYS-BCERP-WEB | **Workspace:** Settings (`/settings`) — quản trị đặc thù (không thuộc phòng ban nghiệp vụ)
> **Ngày:** 13/09/2026 (R2 tách workspace · R3 — workspace folder structure)
>
> READS: `../Navigation-bcerp-web.md`, `../../design-system.md`, `../../../phase2-features/bcerp-web/settings-gw/`, `../../../phase3-architecture/P3-01-architecture.md`
> USED BY: `stgw/screens-integrations-settings.md`, `../Navigation-bcerp-web.md`

> Navigation cấp workspace — con của `Navigation-bcerp-web.md` (§1.0 Bảng A/B). Workspace **Settings** là workspace quản trị đặc thù cho **cấu hình tích hợp, credentials vault, tham số & chính sách hệ thống** — tách khỏi Platform Admin tại R2 (13/09) vì vòng đời cấu hình ≠ tác vụ quản trị hằng ngày. Vai: SYS_ADMIN (vận hành) · BOD_CFO_CTO (CTO duyệt + thao tác vault) · BOD_CEO (chính sách ngưỡng-tier-SLA). Phân hệ: MOD-SETTINGS-GW = **6 FEAT**. Trang đích workspace = **S27 Integration & Settings**. Preferences cá nhân (density…) nằm ở menu user topbar — KHÔNG thuộc workspace này.

---

## 1. Sơ Đồ Menu (Menu Tree)

```
SETTINGS (/settings) — quick: Cấu hình connection · Nạp credential · Ban hành tham số
│
└── Integration & Settings (tabs: Connections · Credentials · Tham số & Chính sách)
    → /settings → stgw/screens-integrations-settings.md  [{connection_degraded} {credential_sap_het}]
```

- 1 surface 3 tab — Connections (T1) · Credentials Vault (T2) · Tham số & Chính sách (T3); chi tiết qua SidePanel, không tách page.
- Vault CẤM tuyệt đối trên mobile (BR-BOD-008.2 — app ẩn tính năng).

## 2. Danh Sách Screen Groups

| # | Screen Group | Route | File | UI-ID | Module |
|---|---|---|---|---|---|
| S27 | Integration & Settings (tabs: Connections / Credentials / Tham số & Chính sách) | `/settings` | `stgw/screens-integrations-settings.md` | `UI-WEB-STGW-001` | MOD-SETTINGS-GW |

> Feed nền cho 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) + VAS kế toán vendor-agnostic (DI-004). 2 kênh nhập manual thuộc S7 Wallet — tại đây chỉ hiển thị trạng thái và điều phối backfill.

## 3. Phân Quyền & Hiển Thị Menu

| Mục menu | Route | Roles thấy | Hành động theo permission | Badge | Điều kiện hiển thị |
|---|---|---|---|---|---|
| Integration & Settings | `/settings` | SYS_ADMIN · BOD_CFO_CTO (duyệt credential/chính sách kỹ thuật) · BOD_CEO (chính sách ngưỡng-tier-SLA) · FIN_L1/L2 (đọc trạng thái sync — read-only [NR]) | Cấu hình, nạp credential (duyệt CTO + MFA), transitions, degraded, revoke, ban hành tham số | `{connection_degraded}` `{credential_sap_het}` | Permission STGW |

- T2 Credentials Vault: CHỈ BOD_CFO_CTO thấy (PEP ẩn) — SYS_ADMIN không thấy plaintext, không tự gán kể cả cho mình.
- SoD: SYS_ADMIN soạn theo change đã CTO duyệt → thực thi có log; MFA step-up (API-CORE-003) trước mọi thao tác vault.

[NEEDS_REVIEW] FEAT-ERP-STGW-002 §4 cấp FIN_L1/L2 quyền xem trạng thái sync + freshness + nhãn nguồn (read-only T1) — đề nghị bổ sung vào ma trận vai (xem chi tiết tại `stgw/screens-integrations-settings.md`).

## 4. UI Notes

### 4.1. Quick Actions

| Action | Mở gì | Ghi chú |
|---|---|---|
| Cấu hình connection | S27-T1 + D1 (profile mới) | Vendor-agnostic theo DI-004 |
| Nạp credential | S27-T2 + D2 — MFA step-up | Chỉ CTO; mask-only |
| Ban hành tham số | S27-T3 + D5 — version effective-dated | Không hồi tố |

### 4.2. Breadcrumb & Pattern

- Breadcrumb: `Settings > Integration & Settings > [Connection: Meta Ads]`.
- Pattern: Registry/admin — bảng standard + SidePanel 480px, comfortable; form cấu hình container 960px.
- Machine-state do GW trả về nguyên văn (WEB không có nút "tắt degraded" ngoài chuỗi backfill); trạng thái tiền trong Backfilling là trung gian bắt buộc.
- Cảnh báo: credential T-7 vàng, quá hạn đỏ + escalate BOD_CEO (qua Alert Center); deep-link backfill từ S23/S24 vào `/settings?tab=connections`.
- Icon workspace: `settings` (Lucide — nhận từ Platform Admin tại R2).

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| Navigation tổng quan hệ thống (workspace map, §1.0) | `../Navigation-bcerp-web.md` |
| Thiết kế chi tiết màn hình | `stgw/screens-integrations-settings.md` |
| RBAC Admin (MFA TOTP nền vault) | `../admin/rbac/screens-rbac-admin.md` |
| Ví & Đối soát (2 kênh nhập manual FIN) | `../finance/wallet/screens-wallet-recon.md` |
| API endpoints | `../../../phase3-architecture/technical-specs/api-contract.md` |
| Design system | `../../design-system.md` |
| REQ-IDs / FEAT | `../../../_meta/req-registry.json` |
