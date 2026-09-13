# Screen Group: MPO-01 — Trang chủ (mirror P1)

> **System:** Mobile App BC Portal (SYS-MOBILE-PORTAL)
> **Module:** `client-portal`
> **Tính năng:** FEAT-MPO-CPORT-001, WALLET-001, SLANOT-001
> **Route:** `/home`
> **Main UI-ID:** `UI-MPO-HOME-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-mobile-portal.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-MPO-CPORT-001, FEAT-MPO-WALLET-001, FEAT-MPO-SLANOT-001

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-MPO-HOME-001` |
| Route | `/home` |
| Loại | Dashboard (glanceable, read-only) |
| FEAT-ID | FEAT-MPO-CPORT-001, FEAT-MPO-WALLET-001, FEAT-MPO-SLANOT-001 |
| Người dùng | CUSTOMER (CLIENT_ADMIN / CLIENT_USER) |

**Checklist B0:** Workspace = Client Portal (external trust boundary, mirror P1). Đối tượng = read-model tổng hợp của 1 tenant (ví, campaign, ticket, invoice). Vai chính = khách hàng; nội bộ BC không xuất hiện (chỉ "đội ngũ BCERP"). Stage = read-only toàn bộ — điểm "ghi" duy nhất là re-auth mở số dư (step-up, không đụng dữ liệu). Khách cần trả lời trong 30 giây: còn bao nhiêu tiền, việc tới đâu, có việc chờ mình không, phải trả gì sắp tới. Exceptions: account suspended, mất mạng, nguồn trễ `manual` + timestamp (DI-007), số tranh chấp "Đang đối soát". Không cần màn riêng — mọi drill-down là view trong group.

---

## 1. TRANG CHÍNH

### 1.1. Layout

```
┌──────────────────────────────────────────────┐
│ Xin chào, Nguyễn Văn A · Công ty ABC         │ ← avatar → /me
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ Số dư ví khả dụng (tham chiếu)  [👁 Mở]  │ │
│ │ ••••• ₫                                  │ │ ← masked; tap → sheet S1 re-auth
│ │ VND: •••• · USD: •••• · cập nhật 09:12   │ │ ← 2 sổ tách, KHÔNG cộng quy đổi
│ │ "Số dư tham chiếu; số chính thức theo    │ │ ← disclaimer độ trễ 15 phút–24h
│ │  đối soát cuối ngày"                     │ │
│ └──────────────────────────────────────────┘ │
│ ┌ Campaign đang chạy (2) ──────────────── → ┐│
│ │ ▸ TikTok Mùa hội tụ · Đang thực hiện     ││
│ │   Milestone 2/4 · cập nhật 08:45         ││
│ ├ Ticket đang mở (1) · 1 chờ phản hồi bạn → ┤│
│ ├ Hóa đơn chờ thanh toán (1)                ┤│
│ │   12.500.000 ₫ · hạn 20/09               ││
│ └──────────────────────────────────────────┘ │
│           (pull-to-refresh toàn màn)         │
├──────────────────────────────────────────────┤
│  🏠      📣      🧾      🎧      👤         │ ← tabbar 56px + safe-area
└──────────────────────────────────────────────┘
```

### 1.2. Components & quy tắc

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| MoneyDisplay | `bcportal-m-money`, VND `1.234.567 ₫`, `tabular-nums` | Mask render `••••• ₫` bằng thay ký tự DOM — CẤM `filter: blur()` (text vẫn đọc được) |
| PrivacyShield | overlay "Ứng dụng đã khóa" | Bật khi `visibilitychange → hidden`; số tiền cấm trong `document.title`, badge, push payload |
| Freshness | `freshness {last_updated, data_source, is_stale}` | Thiếu metadata → không render số (BR-005); `manual` → nhãn "Dữ liệu thủ công" |
| Card tóm tắt | touch ≥44px, padding 16px | Đếm + trạng thái 1 dòng; tap → drill-down trong group |

### 1.3. States

- **Loading:** skeleton card. **Empty:** EmptyState ("Chưa có campaign đang chạy"). **Error:** khối lỗi + Thử lại. **Offline:** banner "Cần kết nối mạng" + nhãn "dữ liệu tại [timestamp]".
- **Suspended:** full-page chặn "Tài khoản tạm khóa — liên hệ nhân viên phụ trách", cả 5 tab không render, push token thu hồi cùng phiên.
- **Reveal:** sau re-auth mở 60s → tự re-mask; app xuống background → re-mask + PrivacyShield ngay.

### 1.4. Phân Quyền

CLIENT_ADMIN = CLIENT_USER trên tab này (chỉ đọc); hành động thiếu quyền ẩn hoàn toàn. Dữ liệu lọc `tenant_id` 2 lớp (RLS + filter API); tenant switcher chỉ liệt kê tenant được gán.

---

## 2. TABS

N/A — điều hướng cấp app là bottom tab bar 5 mục; trong group chỉ có drill-down (view mode M1), không tab con.

---

## 3. DIALOGS

N/A — lỗi dùng Toast/banner; tương tác nhạy cảm (re-auth) dùng bottom sheet S1 để giữ ngữ cảnh card ví.

---

## 4. SHEETS

### 4.1. Sheet: Re-auth mở số dư (`UI-MPO-HOME-001-S1`)

Bottom sheet full-width `bcportal-m-sheet-auth`: giải thích "Vì sao cần xác thực" + nhập OTP (hoặc sinh trắc học/PIN thiết bị đã đăng ký) + nút Xác nhận. Thành công → reveal + chip đếm ngược "Ẩn sau 60s". Sai/hết hạn → lỗi field-level, không đóng sheet, gửi lại được (limit `/mpo/auth/*` 10 req/phút). Hủy → đóng, giữ mask.

---

## 5. VIEW MODES

### 5.1. Mode: Ví chi tiết (`UI-MPO-HOME-001-M1`)

Full-screen stack (`chevron-left` về /home): số dư theo từng TKQC, VND/USD tách sổ không gộp (BR-001 WALLET); chi tiêu daily theo TK/campaign kèm disclaimer hồi tố; giao dịch whitelist — dòng điều chỉnh hiển thị "Điều chỉnh đối soát" (giá vốn không có trong payload); trạng thái đối soát mức khách: Đã đối soát / Đang đối soát; lệnh `PENDING`/`STEP1_APPROVED` ở khối "chờ xử lý", không cộng vào khả dụng. CTA "Mở trên web" → sổ phụ PDF watermark (`API-MPO-022`). KHÔNG có nút ghi tài chính nào (BR-002 — lỗi P0 nếu thêm "shortcut tiện").

---

## 6. API ENDPOINTS

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải card ví | GET | `/api/v1/mpo/wallet/summary` | API-MPO-019; bắt buộc `freshness` |
| Mở Ví chi tiết | GET | `/api/v1/mpo/wallet/spend` | API-MPO-020; daily spend per TKQC |
| Giao dịch ví | GET | `/api/v1/mpo/wallet/transactions` | API-MPO-021; whitelist + mask |
| Sổ phụ (CTA web) | GET | `/api/v1/mpo/wallet/statement-link` | API-MPO-022; CLIENT_ADMIN |
| Tóm tắt campaign | GET | `/api/v1/mpo/campaigns` | API-MPO-023; `limit=3`, đang chạy |
| Tóm tắt ticket | GET | `/api/v1/mpo/tickets` | API-MPO-027; `meta.unread_count` |
| Hóa đơn gần nhất | GET | `/api/v1/portal/invoices` | API-PORTAL-031 qua read path mpo-bff; `limit=1&sort=issue_date:desc` — `[NEEDS_REVIEW: BFF chưa expose API-MPO riêng cho invoice]` |
| Re-auth step-up | POST | `/api/v1/mpo/auth/otp` + `/api/v1/mpo/auth/otp/verify` | API-MPO-003/004 |
| Pull-to-refresh | GET | các GET trên | ETag + `If-None-Match` |

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-MPO-HOME-001` | Main | Trang chủ — greeting + card ví masked + 3 khối tóm tắt |
| `UI-MPO-HOME-001-S1` | Sheet | Re-auth mở số dư (OTP/biometric, re-mask 60s) |
| `UI-MPO-HOME-001-M1` | View Mode | Ví chi tiết — balances per TKQC + spend daily + giao dịch |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/mobile-portal/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` | FEAT-MPO-WALLET-001 |
| Tính năng portal | `../../../phase2-features/mobile-portal/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` | FEAT-MPO-CPORT-001 |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | SYS-MOBILE-PORTAL |
| Design system | `../../design-system.md` | §7 mobile, §4.12 MoneyDisplay |
| Navigation tổng quan | `../Navigation-mobile-portal.md` | §4.2 bảo mật, §4.3 push deep-link |
