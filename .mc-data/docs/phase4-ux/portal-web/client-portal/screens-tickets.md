# Screen Group: P4 — Ticket (client)

> **System:** Client Portal Web (SYS-PORTAL-WEB)
> **Module:** `client-portal`
> **Tính năng:** FEAT-PORTAL-CPORT-001 + CSKH-001
> **Route:** `/portal/tickets`
> **Main UI-ID:** `UI-PWEB-TCKT-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-portal-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-PORTAL-CPORT-001, FEAT-ERP-CSKH-001

---

## Thông Tin Common

| Hạng mục | Giá trị |
|---|---|
| Workspace | Client Portal (external) — ticket là shared object (§2.0.4): nội bộ S16, external P4, khác trust boundary → 2 surfaces hợp lệ |
| Đối tượng nghiệp vụ | Ticket của tenant (read-view + điểm ghi business DUY NHẤT của portal: tạo ticket + comment) |
| Vai trò chính | CUSTOMER (CLIENT_ADMIN, CLIENT_USER — mọi portal user đều tạo được) |
| Workflow stage | Machine `open→assigned→in_progress→resolved→closed` (thực thi ở CSKH nội bộ, portal không đổi state); **map ngôn ngữ client:** Đã tiếp nhận (open/assigned) · Đang xử lý (in_progress) · Đã xử lý — chờ bạn xác nhận (resolved) · Đã đóng (closed) |
| Cross-module | Queue hợp nhất REQ-OPS-009 (dedupe tầng ERP, `source=PORTAL`); P1/P2/P3 gửi context ref (`transaction_id`/`campaign_id`/`invoice_id`) |
| Quyết định của client | Mô tả vấn đề, bổ sung thông tin, xác nhận đã xử lý, đánh giá CSAT |
| Actions được phép | Tạo ticket, comment, reopen (trong 7 ngày từ Closed), CSAT — KHÔNG: assign, đổi trạng thái nội bộ, xem escalation |
| Exceptions | Ticket trùng → trả ticket hiện có (dedupe); khiếu nại nghiêm trọng ưu tiên 24h (không lộ cơ chế escalate); ghi chú nội bộ không vào payload; "chờ bạn" = portal đang chờ client |

**Ranh giới hiển thị:** không lộ SLA tier×priority thô, chuỗi escalation nội bộ (AM→AD→BOD), tên nhân sự xử lý (chỉ "đội ngũ BCERP"), assignee — client thấy *mốc phản hồi dự kiến* và trạng thái ngôn ngữ client.

---

## 1. TRANG CHÍNH

Pattern **W2 split view 40/60**: danh sách trái + thread phải; chọn hàng không rời trang. Mobile <768px: danh sách full → chạm = **full-screen thread** (nút ← quay lại).

```
┌───────────────────────┬────────────────────────────────────────┐
│ Hỗ trợ   [+ Tạo ticket]│ #TCK-1042  ● Đang xử lý               │
│ [Tìm] [Trạng thái ▾]   │ Phản hồi dự kiến: hôm nay trước 17:00 │
│ ┌────────────────────┐ │ ─────────────────────────────────────  │
│ │ ● #TCK-1042        │ │ Bạn 10:09 — Chi tiêu ngày 11/09 của   │
│ │ Chi tiêu 11/09 lệch│ │ TK ****4521 hiển thị khác sổ bên tôi… │
│ │ ● Đang xử lý  2h   │ │ ──                                    │
│ ├────────────────────┤ │ Đội ngũ BCERP 11:42 — Cảm ơn bạn,     │
│ │ ✔ #TCK-1035        │ │ chúng tôi đang kiểm tra và sẽ cập    │
│ │ INV-2026-0107      │ │ nhật trước 17:00 hôm nay.             │
│ │ ✔ Đã xử lý — chờ   │ │ ──                                    │
│ │ bạn xác nhận       │ │ ⏳ Đang chờ hệ thống đối soát — hoàn  │
│ ├────────────────────┤ │ tất dự kiến 15/09                     │
│ │ ● #TCK-1028        │ │ ─────────────────────────────────────  │
│ │ Đã đóng · 12/08    │ │ [Nhập phản hồi…                 Gửi]  │
│ └────────────────────┘ │ [Xác nhận đã xong] [Vẫn chưa xong]    │
│ Trang 1/2 · 20/trang ▾ │ (chỉ hiện khi trạng thái "Đã xử lý")  │
└───────────────────────┴────────────────────────────────────────┘
```

- **Danh sách 40%:** mỗi item = mã ticket + tiêu đề + StatusBadge client + dòng "chờ ai": *"Chúng tôi đang xử lý — hoàn tất dự kiến 15/09"* (chờ BC) hoặc *"Đang chờ phản hồi từ bạn — vui lòng trả lời trước 18/09"* (chờ client, icon ngoài). Search theo tiêu đề/mã + filter trạng thái (chips) + pagination server-side 20/50.
- **Thread 60%:** timeline hội thoại (bạn / đội ngũ BCERP), WaitingOnIndicator phiên client ở vị trí hiện tại, ô comment cuối trang. Trạng thái `resolved` → 2 nút [Xác nhận đã xong] / [Vẫn chưa xong (mở lại)]; `closed` → [Mở lại] trong 7 ngày + thẻ CSAT.
- **Trạng thái:** loading = skeleton 8 item + khung thread rỗng; empty = EmptyState *"Bạn chưa có yêu cầu hỗ trợ nào — [Tạo ticket]"*; error = EmptyState + "Thử lại"; comment gửi lỗi → giữ nội dung trong ô + toast lỗi (không tự đóng).
- Bảo mật UI: chỉ ticket của tenant (scoping từ token); `no-store`, không cache thread; draft comment chỉ lưu trong bộ nhớ phiên, không localStorage.

---

## 2. TABS

N/A — W2 split view đã kết hợp danh sách + chi tiết trên một surface; trạng thái là quick filter, không phải khối dữ liệu cần tab riêng.

---

## 3. DIALOGS

**UI-PWEB-TCKT-001-D1 — Tạo ticket** (quick action GHI duy nhất của portal, mở được từ mọi surface qua topnav): trường — chủ đề (category: Kỹ thuật chạy ads / Thanh toán – hóa đơn / Số liệu ví / Yêu cầu khác), tiêu đề, mô tả (bắt buộc, ≥10 ký tự), đính kèm context (tự điền khi mở từ P1 giao dịch / P2 milestone / P3 hóa đơn, hiển thị dạng chip tháo được). Chọn nhóm "Số liệu ví – mất tiền/khiếu nại" → dòng cam kết trung tính *"Các yêu cầu nghiêm trọng được ưu tiên xử lý trong vòng 24 giờ"* (không lộ cơ chế escalate BOD). Submit → API-PORTAL-029; **dedupe trùng** → toast *"Chúng tôi đã có yêu cầu tương tự đang được xử lý"* + link sang ticket hiện có (không tạo bản ghi mới). Chống double-submit: khóa nút khi processing.

**UI-PWEB-TCKT-001-D2 — Đánh giá CSAT** (ticket `closed`): 1–5 sao + 1 câu mở, một CSAT/ticket, không nhắc lại quá 1 lần/48h. Sau gửi → cảm ơn + đóng thẻ.

**UI-PWEB-TCKT-001-D3 — Mở lại ticket** (trong 7 ngày từ Closed): confirm + lý do bắt buộc (ghi vào comment/reopen). Quá 7 ngày → nút ẩn, thay bằng link "Tạo ticket mới kèm tham chiếu #TCK-…".

---

## 4. SHEETS

N/A — chi tiết ticket là view mode chính của surface (W2), không phải dữ liệu ngữ cảnh phụ; mobile dùng full-screen thread thay bottom sheet để giữ không gian đọc hội thoại.

---

## 5. VIEW MODES

**UI-PWEB-TCKT-001-M1 — Thread chi tiết**: desktop = 60% phải của split view (giữ danh sách, không rời trang); mobile = full-screen thread (breadcrumb `Hỗ trợ › #TCK-1042`, nút ← về danh sách). Nội dung: header (mã, tiêu đề, StatusBadge client + mốc phản hồi dự kiến), Timeline hội thoại (whitelist — ghi chú nội bộ và escalation không bao giờ xuất hiện vì payload đã lọc), ô comment (Enter gửi; gửi xong thêm entry "Bạn"), khối hành động theo trạng thái: `resolved` → [Xác nhận đã xong]/[Vẫn chưa xong]; `closed` ≤7 ngày → [Mở lại] + thẻ CSAT (D2). Việc resume/tạm dừng SLA nội bộ do CORE quyết — client không thấy timer nội bộ, chỉ thấy mốc hẹn.

---

## 6. API ENDPOINTS

| Endpoint | Method | Dùng ở đâu | Tham số chính |
|---|---|---|---|
| API-PORTAL-027 `/tickets` | GET | Danh sách 40% + badge nav `{đang mở}` | filter `status`, search, `page/limit` (server-side) |
| API-PORTAL-028 `/tickets/:ticketId` | GET | Thread M1 (timeline whitelist — ghi chú nội bộ không vào payload) | — |
| API-PORTAL-029 `/tickets` | POST | D1 tạo ticket | `category`, `title`, `description`, `context_refs`, `source=PORTAL`; dedupe tầng ERP |
| API-PORTAL-030 `/tickets/:ticketId/comments` | POST | Ô comment M1 | `{body}`; không đổi state ticket |
| API-PORTAL-036 `/meta/freshness` | GET | Nhãn "Cập nhật lúc" (ticket realtime) | — |

`[NEEDS_REVIEW: portal-web thiếu endpoint reopen + CSAT — chỉ có bản mobile API-MPO-031 /mpo/tickets/:id/reopen và API-MPO-032 /mpo/tickets/:id/csat; cần bổ sung API-PORTAL tương đương (hoặc dùng chung service) cho [Xác nhận đã xong]/[Mở lại]/[CSAT] ở M1, D2, D3]`

---

## 7. UI-ID Registry

| UI-ID | Thành phần | Loại | Ghi chú |
|---|---|---|---|
| `UI-PWEB-TCKT-001` | Split view danh sách ticket 40% + thread 60% | list | Route `/portal/tickets`, W2; mobile full-screen thread |
| `UI-PWEB-TCKT-001-M1` | Thread chi tiết (timeline + comment + hành động theo trạng thái) | detail-view | API-PORTAL-028/030; map ngôn ngữ client 4 mức |
| `UI-PWEB-TCKT-001-D1` | Dialog tạo ticket + dedupe | form-dialog | POST API-PORTAL-029; context chip từ P1/P2/P3 |
| `UI-PWEB-TCKT-001-D2` | Dialog CSAT (1–5 + câu mở) | form-dialog | `[NEEDS_REVIEW]` endpoint CSAT web |
| `UI-PWEB-TCKT-001-D3` | Dialog mở lại ticket (7 ngày) | confirm-dialog | `[NEEDS_REVIEW]` endpoint reopen web |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/` | Upstream |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../design-system.md` | Upstream |
| Navigation tổng quan | `../Navigation-portal-web.md` | Upstream |
