# Screen Group: P3 — Billing / Invoices

> **System:** Client Portal Web (SYS-PORTAL-WEB)
> **Module:** `client-portal`
> **Tính năng:** FEAT-PORTAL-CPORT-002 + ARAP-001
> **Route:** `/portal/invoices`
> **Main UI-ID:** `UI-PWEB-INV-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-portal-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-PORTAL-CPORT-002, FEAT-ERP-ARAP-001

---

## Thông Tin Common

| Hạng mục | Giá trị |
|---|---|
| Workspace | Client Portal (external) — invoice là shared object (§2.0.4): nội bộ ở S10 tab AR, external ở P3, 2 trust boundary → 2 surfaces hợp lệ |
| Đối tượng nghiệp vụ | Invoice AR của tenant (read-view whitelist từ ARAP) + lịch thanh toán |
| Vai trò chính | CUSTOMER (bộ phận kế toán của khách) — CLIENT_ADMIN/CLIENT_USER như nhau |
| Workflow stage | AR `invoice→aging→dunning→paid` (nội bộ); client chỉ thấy *Chờ thanh toán · Đã thanh toán · Quá hạn* — aging buckets, dunning history, ghi chú nội bộ KHÔNG hiển thị |
| Cross-module | ARAP nội bộ (nguồn thật, FIN); P4 (tranh chấp invoice → ticket gắn `invoice_id`); watermark service + `portal_download_log` (BR-011) |
| Quyết định của client | "Có hóa đơn nào phải trả, đến hạn khi nào, tải chứng từ đối chiếu sổ" |
| Actions được phép | Xem list/detail, tải PDF (watermark + log), tạo ticket tranh chấp — KHÔNG có hành động ghi lên invoice |
| Exceptions | Tenant isolation (không bao giờ thấy invoice khách khác), stale freshness, watermark fail chặn tải, tranh chấp đang xử lý |

**Per-client scoping (bắt buộc):** `tenant_id` lấy từ token claim — UI không có bộ chọn khách, không có query param tenant; mỗi account chỉ từng thấy invoice của tổ chức mình dù cùng route.

---

## 1. TRANG CHÍNH

Pattern **W1 lột bỏ**: DataTable comfortable + MoneyDisplay, bỏ quick chips SLA/worklist nội bộ. Search + filter + sort + pagination server-side (20/50/100).

```
┌──────────────────────────────────────────────────────────────────┐
│ Hóa đơn & Thanh toán   [Tìm theo số hóa đơn]  [Trạng thái ▾] [↓ Ngày│
│ (Chờ thanh toán · 2×) (Quá hạn · 1×) (Đã thanh toán ×)           │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Số HĐ          Phát hành  Đến hạn   Số tiền        Trạng thái│ │
│ │ INV-2026-0114  05/09/26  20/09/26   45.000.000 ₫   Chờ thanh toán│
│ │ INV-2026-0107  28/08/26  12/09/26   38.500.000 ₫   Quá hạn ⚠ │ │
│ │ INV-2026-0098  15/08/26  30/08/26   52.300.000 ₫   Đã thanh toán│
│ │                                              [Xem PDF] mỗi hàng │
│ └──────────────────────────────────────────────────────────────┘ │
│ LỊCH THANH TOÁN SẮP TỚI                                          │
│ ⚠ 12/09 — INV-2026-0107 · 38.500.000 ₫ — đã quá hạn, vui lòng    │
│   thanh toán sớm hoặc liên hệ nhân viên phụ trách                │
│   20/09 — INV-2026-0114 · 45.000.000 ₫                           │
│ Trang 1/1 — 20/trang ▾                                           │
└──────────────────────────────────────────────────────────────────┘
```

- **Cột tiền** `MoneyDisplay` VND `tabular-nums` right-align; **StatusBadge** theo ngôn ngữ client (*Chờ thanh toán* pending · *Đã thanh toán* approved · *Quá hạn* overdue + icon) — không hiển thị mã machine, aging bucket 30/60/90 hay số lần nhắc nợ.
- **Khối lịch thanh toán:** tổng nợ hiện tại + các hạn tới theo thứ tự ngày; quá hạn = WarningIndicator banner *"đã quá hạn — cần bạn thanh toán / liên hệ nhân viên phụ trách"* (variant chờ client, icon ngoài, không nhấn nhá).
- Row action: [Xem PDF] → SidePanel 720px (§4). Không hiển thị chính sách thanh toán, điều khoản tín dụng hay chiết khấu nội bộ (BR-003 CPORT-002).
- **Trạng thái:** loading = skeleton 10 hàng; empty = EmptyState *"Chưa có hóa đơn nào"*; error = EmptyState + "Thử lại"; stale = nhãn "Cập nhật lúc {hh:mm}" (thiếu freshness metadata → không render số).
- Mobile <768px: bảng → card (số HĐ + tiền + badge + nút PDF, touch 44px); tablet giữ bảng.
- Bảo mật UI: `no-store`, không cache PDF ra localStorage; tải PDF luôn qua server (watermark), không render URL file trực tiếp.

---

## 2. TABS

N/A — một danh sách duy nhất với quick filter chips (tháo được từng chip) là đủ; trạng thái là thuộc tính lọc chứ không phải khối dữ liệu khác nhau, tách tab sẽ nhân bản bề mặt không cần thiết.

---

## 3. DIALOGS

**UI-PWEB-INV-001-D1 — Tranh chấp hóa đơn → ticket**: mở từ "Báo cáo sai lệch" trong SidePanel chi tiết. Form: chọn loại sai lệch (số tiền / thiếu nội dung / khác) + mô tả ≥10 ký tự → tạo ticket (API-PORTAL-029, `source=PORTAL`, gắn `invoice_id`). Hóa đơn đang tranh chấp hiển thị badge *"Đang được kiểm tra" + số tham chiếu ticket* cho đến khi chốt (BR-012), không tự đổi trạng thái thanh toán.

---

## 4. SHEETS

**UI-PWEB-INV-001-S1 — Chi tiết hóa đơn + PDF (SidePanel 720px)**: mở từ row [Xem PDF], desktop đẩy nội dung, mobile bottom sheet full-width. Header: số HĐ + StatusBadge; thân: thông tin theo whitelist (ngày phát hành, ngày đến hạn, dòng tiền dịch vụ, thuế, tổng tiền `MoneyDisplay`), phần PDF viewer nhúng + nút **Tải PDF** — file đi qua watermark service (watermark tên user + thời điểm, BR-011), mỗi lần tải ghi `portal_download_log`; watermark fail → 503 `WATERMARK_UNAVAILABLE` → thông báo *"Không tải được lúc này, vui lòng thử lại"* và chặn tải file không watermark. Footer: [Tải PDF] (primary) + [Báo cáo sai lệch] (mở D1). Esc đóng, focus trap.

---

## 5. VIEW MODES

N/A — P3 thuần read-only list + sheet; khách không tạo/sửa invoice. Điểm ghi duy nhất liên quan là ticket tranh chấp (D1 — thuộc luồng P4, chỉ gắn ref).

---

## 6. API ENDPOINTS

| Endpoint | Method | Dùng ở đâu | Tham số chính |
|---|---|---|---|
| API-PORTAL-031 `/invoices` | GET | List chính + khối lịch thanh toán | filter `status`, sort `issue_date`/`due_date`, `page/limit` (20/50/100 server-side) |
| API-PORTAL-032 `/invoices/:invoiceId` | GET | S1 (thông tin whitelist) | — |
| API-PORTAL-033 `/invoices/:invoiceId/file` | GET | S1 (viewer + tải PDF qua watermark) | — ; fail → 503 `WATERMARK_UNAVAILABLE` |
| API-PORTAL-029 `/tickets` | POST | D1 (tranh chấp, gắn `invoice_id`) | `category`, `context_refs`, `source=PORTAL` |
| API-PORTAL-034 `/exports` | POST [OTP] | "Xuất danh sách hóa đơn" (tuỳ chọn, scope `invoices`) | `scope=invoices`, `otp_proof` |
| API-PORTAL-035 `/exports/:exportId` | GET | Link tải bản xuất (expires 24h) | — |
| API-PORTAL-036 `/meta/freshness` | GET | Nhãn "Cập nhật lúc" (view_group invoices) | — |

`[NEEDS_REVIEW: bộ trường invoice chia sẻ + quy trình duyệt view — API-PORTAL-031/032 đang [NEEDS_REVIEW] ở Phụ lục A #19; UI whitelist dưới đây chỉ khớp đề xuất, chốt khi FIN duyệt view]`

---

## 7. UI-ID Registry

| UI-ID | Thành phần | Loại | Ghi chú |
|---|---|---|---|
| `UI-PWEB-INV-001` | Danh sách hóa đơn + lịch thanh toán | list | Route `/portal/invoices`, W1 lột bỏ, comfortable, MoneyDisplay |
| `UI-PWEB-INV-001-S1` | SidePanel chi tiết + PDF 720px / bottom sheet | sheet-720 | Watermark bắt buộc, log download, viewer nhúng |
| `UI-PWEB-INV-001-D1` | Dialog tranh chấp hóa đơn → ticket | form-dialog | POST API-PORTAL-029 gắn `invoice_id`; badge "Đang được kiểm tra" |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/` | Upstream |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../design-system.md` | Upstream |
| Navigation tổng quan | `../Navigation-portal-web.md` | Upstream |
