# Screen Group: MPO-03 — Hóa đơn (mirror P3)

> **System:** Mobile App BC Portal (SYS-MOBILE-PORTAL)
> **Module:** `client-portal`
> **Tính năng:** FEAT-MPO-CPORT-001 [NEEDS_REVIEW: feature invoice mobile không có riêng — dùng CPORT-001, xác nhận FEAT ở Phase 3 check 4.1 theo footnote [a] Navigation]
> **Route:** `/invoices`
> **Main UI-ID:** `UI-MPO-INV-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-mobile-portal.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-MPO-CPORT-001

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-MPO-INV-001` |
| Route | `/invoices` |
| Loại | List + Detail/PDF (stack trong group) |
| FEAT-ID | FEAT-MPO-CPORT-001 `[NEEDS_REVIEW: chưa có FEAT invoice riêng cho MPO — dùng read-model portal]` |
| Người dùng | CUSTOMER (CLIENT_ADMIN / CLIENT_USER) |

**Checklist B0:** Workspace = Client Portal (mirror P3). Đối tượng = invoice của tenant (read-model từ ARAP, whitelist trường đã duyệt). Stage render bằng ngôn ngữ client: *Chờ thanh toán · Đã thanh toán · Quá hạn* (Navigation §4.4). Khách làm 3 việc: xem hóa đơn mới (push "hóa đơn mới" deep-link vào detail), tải PDF chuyển tiếp (watermark + `portal_download_log` — BR-011), xem hạn thanh toán. Không có hành động ghi tài chính — thanh toán/dunning là nội bộ; đối chiếu sâu → CTA "Mở trên web".

---

## 1. TRANG CHÍNH

### 1.1. Layout

```
┌──────────────────────────────────────────────┐
│ Hóa đơn      [Tìm theo số hóa đơn…]          │
│ (Chờ thanh toán ×) (Quá hạn ×) (Tất cả ×)    │ ← quick filter chips
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ INV-2026-0912        [Chờ thanh toán]    │ │ ← StatusBadge ngôn ngữ client
│ │ 12.500.000 ₫ · hạn 20/09                 │ │ ← MoneyDisplay VND tabular-nums
│ │ phát hành 05/09 · HĐĐT                   │ │
│ ├──────────────────────────────────────────┤ │
│ │ INV-2026-0877            [Quá hạn]       │ │ ← --state-overdue + icon + chữ
│ │ 8.200.000 ₫ · quá hạn 3 ngày             │ │
│ └──────────────────────────────────────────┘ │
│   ← 1/3 →        Tổng: 26 hóa đơn            │ ← pagination server-side
├──────────────────────────────────────────────┤
│  🏠      📣      🧾      🎧      👤         │
└──────────────────────────────────────────────┘
```

### 1.2. Components & quy tắc

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| Card invoice | touch ≥44px | Số HĐ + trạng thái + số tiền + hạn; tap → M1 |
| MoneyDisplay | VND `1.234.567 ₫`, `tabular-nums`, right-align trong card | Cấm format thủ công; số chính xác trong tooltip nếu rút gọn |
| StatusBadge | Chờ thanh toán = pending · Đã thanh toán = approved · Quá hạn = overdue | Luôn màu + icon + chữ (không chỉ màu) |
| Pagination | `page/limit` server-side, 20/50/100 | Sort mặc định ngày phát hành giảm dần |

**States:** loading skeleton; empty = "Chưa có hóa đơn nào" (filter rỗng → "Không có hóa đơn ở trạng thái này"); error + Thử lại; offline → banner + nhãn timestamp. Badge trên tab icon = `{chờ thanh toán}`.

---

## 2. TABS

N/A — danh sách duy nhất, lọc bằng chips; chi tiết là view mode M1/M2 trong group.

---

## 3. DIALOGS

N/A — lỗi tải PDF (503 `WATERMARK_UNAVAILABLE`) hiển thị Toast lỗi không tự đóng kèm hướng dẫn thử lại; không dialog chặn nào trên luồng đọc.

---

## 4. SHEETS

### 4.1. Sheet: Bộ lọc nâng cao (`UI-MPO-INV-001-S1`)

Mở từ nút "Bộ lọc" khi chips chưa đủ: khoảng ngày phát hành, khoảng hạn thanh toán, trạng thái. Áp → đóng, chips tổng hợp hiển thị trên command bar; tháo từng chip được.

---

## 5. VIEW MODES

### 5.1. Mode: Chi tiết hóa đơn (`UI-MPO-INV-001-M1`)

Full-screen: header số HĐ + trạng thái + tổng tiền MoneyDisplay → khối thông tin whitelist (ngày phát hành, hạn thanh toán, HĐĐT, tham chiếu campaign nếu có) → hàng action: **Xem PDF** (mở M2) và **Tải PDF** (`download`, watermark tên user + thời điểm, log bất biến — BR-011) → CTA "Mở trên web" cho bảng đối chiếu chi tiết (data-heavy không parity, design-system §7).

### 5.2. Mode: Xem PDF (`UI-MPO-INV-001-M2`)

Viewer full-screen trong app: render PDF watermark; thanh trên có nút tải về + đóng. Không cache file vào localStorage/webview (`no-store`); tải xong → toast thành công + ghi `portal_download_log`.

---

## 6. API ENDPOINTS

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải danh sách | GET | `/api/v1/portal/invoices` | API-PORTAL-031 qua read path mpo-bff; `page/limit`, `status`, `search` — `[NEEDS_REVIEW: BFF chưa expose API-MPO riêng cho invoice — mobile tiêu thụ read-model PORTAL-WEB đã lọc tenant]` |
| Mở chi tiết | GET | `/api/v1/portal/invoices/:invoiceId` | API-PORTAL-032; whitelist trường đã duyệt |
| Xem/tải PDF | GET | `/api/v1/portal/invoices/:invoiceId/file` | API-PORTAL-033; watermark service → fail 503 chặn xuất |
| Pull-to-refresh | GET | các GET trên | ETag + `If-None-Match` |

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-MPO-INV-001` | Main | Danh sách hóa đơn + chips + pagination |
| `UI-MPO-INV-001-M1` | View Mode | Chi tiết hóa đơn + tải PDF watermark |
| `UI-MPO-INV-001-M2` | View Mode | Xem PDF full-screen |
| `UI-MPO-INV-001-S1` | Sheet | Bộ lọc nâng cao (ngày, hạn, trạng thái) |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/mobile-portal/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` | FEAT-MPO-CPORT-001 (BR-011 watermark) |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | §6.6 Invoice (SYS-PORTAL-WEB) + §7 Internal read path (MPO) |
| Design system | `../../design-system.md` | §4.12 MoneyDisplay, §7 bảng data-heavy |
| Navigation tổng quan | `../Navigation-mobile-portal.md` | §2 footnote [a], §4.3 push deep-link |
