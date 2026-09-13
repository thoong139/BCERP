# Screen Group: P1 — Portal Home

> **System:** Client Portal Web (SYS-PORTAL-WEB)
> **Module:** `client-portal`
> **Tính năng:** FEAT-PORTAL-CPORT-001
> **Route:** `/portal`
> **Main UI-ID:** `UI-PWEB-HOME-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-portal-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-PORTAL-CPORT-001

---

## Thông Tin Common

| Hạng mục | Giá trị |
|---|---|
| Workspace | Client Portal (external, trust boundary riêng — không thuộc 7 workspace nội bộ của BCERP Web) |
| Đối tượng nghiệp vụ | Tổng quan tenant: ví TKQC (read-view), campaign, ticket, invoice — tất cả read-only |
| Vai trò chính | CUSTOMER (CLIENT_ADMIN, CLIENT_USER) — không phân vai UI, mọi account active thấy như nhau |
| Workflow stage | Đọc liên tục, không lifecycle riêng; giám sát tiền giai đoạn active (Luồng 2 — B10) |
| Cross-module | WALLET/CAMP/CSKH/ARAP qua read-model đã mask tầng API (CORE REQ-FIN-017) |
| Quyết định của client | "Còn bao nhiêu tiền, việc đang tới đâu, có hóa đơn phải trả không" |
| Actions được phép | Drill-down ví (read), xuất dữ liệu watermark (OTP), tạo ticket, nhảy P2/P3/P4 |
| Exceptions | Chậm nạp trung tính `[KXN-22]`, nguồn trễ `is_stale`, session hết hạn, account suspended |

---

## 1. TRANG CHÍNH

Pattern **W4 rút gọn read-only**: 4 summary card, không KPI delta, không widget hành động nội bộ. Top nav 56px (4 mục + tên tenant), container 1200px, density comfortable, mobile <768px bottom nav + card.

```
┌──────────────────────────────────────────────────────────────────┐
│ BC Portal   [🏠 Trang chủ] [📣 Campaign] [🧾 Hóa đơn] [🎧 Hỗ trợ] │
│                                                  Công ty ABC ▾ ⏻ │
├──────────────────────────────────────────────────────────────────┤
│ Chào bạn — cập nhật lúc 08:32 · [Xem trạng thái dữ liệu]         │
│                                                                  │
│ ┌─ 💰 Số dư ví ─────────┐ ┌─ 📣 Campaign đang chạy ─┐            │
│ │ 128.450.000 ₫  👁      │ │ 3 đang thực hiện        │            │
│ │ 4 TKQC · VND           │ │ 1 chờ bạn nghiệm thu →  │            │
│ │ [Chi tiết ví →]        │ │ [Xem tất cả →]          │            │
│ │ ⓘ Số liệu đã đối soát  │ └─────────────────────────┘            │
│ │ · cập nhật 07:45       │ ┌─ 🎧 Ticket đang mở ────┐            │
│ └────────────────────────│ │ 2 đang xử lý · 1 chờ    │            │
│ ┌─ 🧾 Hóa đơn mới ───────┤ │ phản hồi từ bạn         │            │
│ │ INV-2026-0114          │ │ [Xem hỗ trợ →]          │            │
│ │ 45.000.000 ₫           │ └─────────────────────────┘            │
│ │ Đến hạn 20/09 [PDF]    │                                        │
│ │ [Tất cả hóa đơn →]     │  [+ Tạo ticket]  (quick action GHI)    │
│ └────────────────────────┘                                        │
│ ⚠ Ví sắp đạt ngưỡng theo lịch nạp cam kết — [xem lịch nạp]        │
└──────────────────────────────────────────────────────────────────┘
```

- **Card Số dư ví** (read-only): tổng dư `MoneyDisplay` per-currency theo lệnh nạp (không quy đổi — BR-009), kèm nhãn *"Số liệu đã đối soát"* + freshness timestamp; nút mắt 👁 ẩn/hiện. Click "Chi tiết ví" → SidePanel (§4), không page riêng. Không có nút nạp/rút/điều chỉnh — read-only tuyệt đối (BR-001).
- **Card Campaign**: đếm đang chạy theo ngôn ngữ client (*Chuẩn bị · Đang thực hiện · Đã bàn giao · Đã báo cáo*); nếu có milestone chờ khách nghiệm thu → link nổi tới P2.
- **Card Ticket**: đếm đang mở + "chờ phản hồi từ bạn" (WaitingOnIndicator variant chờ client — icon ngoài, không nhấn nhá).
- **Card Invoice mới**: invoice gần nhất + trạng thái client (*Chờ thanh toán · Đã thanh toán · Quá hạn*) + ngày đến hạn; link P3.
- **WarningIndicator banner** (dismissible cho warning vận hành): cảnh báo chậm nạp dùng văn bản trung tính "Ví sắp đạt ngưỡng theo lịch nạp cam kết" — không cảnh báo PAUSE cứng trước khi chốt mốc 15/30 ngày `[KXN-22]`.
- **Freshness meta bắt buộc** (BR-007): mỗi card render số chỉ khi response có `meta.freshness`; thiếu → hiển thị "Đang cập nhật số liệu" (LoadingSkeleton), không render số cũ.
- **Trạng thái:** loading = skeleton 4 card; empty (tenant mới chưa có dữ liệu) = EmptyState "Chưa có dữ liệu — dữ liệu xuất hiện sau khi chiến dịch đầu tiên khởi chạy"; error = EmptyState kèm "Thử lại" + link "Báo cáo sự cố" (API-PORTAL-037); nguồn stale = badge "Dữ liệu cập nhật lúc {hh:mm}" vàng, không hiện số cũ như số mới.
- **Bảo mật UI:** mọi API `no-store`, cấm localStorage dữ liệu nhạy cảm, vô hiệu bfcache; idle 30 phút → modal đếm ngược 2 phút (§3); suspended → full-page chặn "Tài khoản tạm khóa — vui lòng liên hệ nhân viên phụ trách", menu không render.

---

## 2. TABS

N/A — Portal tối giản: W4 rút gọn, mọi chi tiết là drill-down trong cùng surface; 4 luồng đã chia sẵn qua top nav (P2/P3/P4). Không thêm tab nào ngoài Navigation §2.0.5.

---

## 3. DIALOGS

**UI-PWEB-HOME-001-D1 — Xác minh OTP khi xuất dữ liệu** (BR-008): mở từ "Xuất dữ liệu ví" trong SidePanel ví. Nội dung: phạm vi xuất (scope balances/transactions/deposits), nút "Gửi mã" → nhập OTP → xác nhận. Thiếu/hết hạn OTP → `OTP_REQUIRED`/`OTP_INVALID`, không đóng form. Xuất thành công → toast link tải (hết hạn 24h); watermark fail → 503 `WATERMARK_UNAVAILABLE`, chặn xuất.

**UI-PWEB-HOME-001-D2 — Cảnh báo session hết hạn**: modal đếm ngược 2 phút trước idle timeout 30 phút; "Tiếp tục phiên" (refresh token API-PORTAL-007) / "Đăng xuất". Hết giờ → về màn đăng nhập, đăng nhập lại quay đúng `/portal` (không redirect đột ngột).

---

## 4. SHEETS

**UI-PWEB-HOME-001-S1 — Ví chi tiết (drill-down)**: SidePanel phải 480px desktop (đẩy nội dung, không overlay), mobile <768px bottom sheet full-width. Nội dung: (a) số dư theo từng TKQC — tên TK mask `****1234` (bấm hiện đủ → yêu cầu re-auth/2FA), `MoneyDisplay` per-currency + freshness từng nhóm; (b) chi tiêu daily theo TK/campaign kèm disclaimer "platform có thể điều chỉnh hồi tố theo timezone"; (c) lịch nạp — đã thực hiện + kế hoạch cam kết (realtime); (d) giao dịch gần đây: `DISPUTED` hiển thị *"Đang đối soát" + số tham chiếu* (BR-007), `ADJUSTED` hiển thị *"Điều chỉnh đối soát"* — không hiện như số chính thức. Footer: [Xuất dữ liệu] (mở D1) + [Tạo ticket phản đối số liệu] (sang P4, gắn `transaction_id`). Esc đóng, focus trap.

---

## 5. VIEW MODES

N/A — P1 thuần read-only dashboard; không Create/Edit/Review/Approve. Hai thao tác ghi của portal (tạo ticket, tải PDF) thuộc P4/P3 — quick action "Tạo ticket" mở dialog của P4, không nhân bản form.

---

## 6. API ENDPOINTS

Base `/api/v1/portal/` — Bearer JWT audience `portal`, `tenant_id` từ claim (client không truyền), mọi read response bắt buộc `meta.freshness` (thiếu → không render).

| Endpoint | Method | Dùng ở đâu | Tham số chính |
|---|---|---|---|
| API-PORTAL-018 `/accounts/tenant` | GET | Tên tenant trên topnav | — |
| API-PORTAL-019 `/wallet/adaccounts/balances` | GET | Card số dư + S1 | per-currency, không fx |
| API-PORTAL-020 `/wallet/spend-daily` | GET | S1 (chi tiêu daily) | `adaccount_id`, `campaign_id`, date range |
| API-PORTAL-021 `/wallet/transactions` | GET | S1 (giao dịch gần đây) | `page/limit`, filter `type`, `recon_status` |
| API-PORTAL-022 `/wallet/deposits` | GET | S1 (lịch nạp), banner ngưỡng | — |
| API-PORTAL-023 `/wallet/alerts` | GET | Banner cảnh báo trung tính `[KXN-22]` | — |
| API-PORTAL-024 `/campaigns` | GET | Card campaign (`status=in_flight` etc.) | filter `status`, `page/limit` |
| API-PORTAL-027 `/tickets` | GET | Card ticket (đếm đang mở + chờ client) | filter `status`, `page/limit` |
| API-PORTAL-031 `/invoices` | GET | Card invoice mới | filter `status`, sort `-issue_date` |
| API-PORTAL-036 `/meta/freshness` | GET | "Xem trạng thái dữ liệu", badge stale | view_group |
| API-PORTAL-034 `/exports` | POST [OTP] | Xuất ví qua D1 | `scope`, `otp_proof` |
| API-PORTAL-035 `/exports/:exportId` | GET | Link tải job xuất | — |
| API-PORTAL-037 `/incidents` | POST | Link "Báo cáo sự cố" khi error | mô tả + resource |

`[NEEDS_REVIEW: thiếu endpoint đếm tổng hợp cho 4 card — hiện dùng filter/status của list endpoint; đề xuất endpoint summary /portal/summary để 1 request render home]`

---

## 7. UI-ID Registry

| UI-ID | Thành phần | Loại | Ghi chú |
|---|---|---|---|
| `UI-PWEB-HOME-001` | Trang chủ 4 summary card | dashboard | Route `/portal`, W4 rút gọn read-only |
| `UI-PWEB-HOME-001-S1` | SidePanel Ví chi tiết 480px / bottom sheet mobile | sheet-480 | Read-only; mask ****1234 + re-auth; disputed label |
| `UI-PWEB-HOME-001-D1` | Dialog OTP xuất dữ liệu | form-dialog | POST API-PORTAL-034 [OTP] |
| `UI-PWEB-HOME-001-D2` | Modal session hết hạn (đếm ngược 2 phút) | confirm-dialog | API-PORTAL-007 refresh / 008 logout |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/` | Upstream |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../design-system.md` | Upstream |
| Navigation tổng quan | `../Navigation-portal-web.md` | Upstream |
