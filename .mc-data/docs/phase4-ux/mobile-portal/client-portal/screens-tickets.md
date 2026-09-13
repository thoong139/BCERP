# Screen Group: MPO-04 — Hỗ trợ / Ticket (mirror P4)

> **System:** Mobile App BC Portal (SYS-MOBILE-PORTAL)
> **Module:** `client-portal`
> **Tính năng:** FEAT-MPO-CSKH-001, SLANOT-001
> **Route:** `/tickets`
> **Main UI-ID:** `UI-MPO-TCKT-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-mobile-portal.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-MPO-CSKH-001, FEAT-MPO-SLANOT-001

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-MPO-TCKT-001` |
| Route | `/tickets` |
| Loại | List + Form 1 màn + Thread full-screen |
| FEAT-ID | FEAT-MPO-CSKH-001, FEAT-MPO-SLANOT-001 |
| Người dùng | CUSTOMER (CLIENT_ADMIN / CLIENT_USER) — ghi vào queue hợp nhất REQ-OPS-009 |

**Checklist B0:** Workspace = Client Portal (mirror P4). Đối tượng = ticket của tenant (state machine sở hữu bởi CORE — mobile không đổi state). Stage render client: *Đã tiếp nhận · Đang xử lý · Đã xử lý — chờ bạn xác nhận · Đã đóng*. Hành động được phép: tạo ticket, trả lời (comment chính thức), reopen ≤7 ngày, CSAT. Exceptions phải thấy rõ: Pending chờ khách (WaitingOn client + nhịp nhắc), auto-Closed "khách không phản hồi" (lý do + reopen), breach (thông báo theo template với timestamp "đã thông báo"), khiếu nại nghiêm trọng chỉ hiển thị "đang xử lý cấp cao" — cấm lộ chuỗi escalate nội bộ. Push "phản hồi ticket" deep-link thẳng vào thread.

---

## 1. TRANG CHÍNH

### 1.1. Layout

```
┌──────────────────────────────────────────────┐
│ Hỗ trợ        [Tìm theo mã/chủ đề…]  [+ Tạo] │
│ (Đang xử lý ×) (Chờ bạn ×) (Đã đóng ×)       │
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ #TCK-1042  Sai ngân sách campaign T9     │ │
│ │ [Đang xử lý] · cam kết phản hồi ≤4h ngoài│ │ ← SLA read-only, nhãn cam kết
│ │ giờ (Critical)                           │ │
│ │ Đang xử lý cấp cao · cập nhật 10:05      │ │ ← không lộ chuỗi escalate
│ ├──────────────────────────────────────────┤ │
│ │ #TCK-1038  Cần xuất báo cáo chi tiêu     │ │
│ │ [Đã xử lý — chờ bạn xác nhận]            │ │
│ │ ⏳ Đang chờ phản hồi từ bạn — 1 ngày     │ │ ← WaitingOnIndicator phiên client
│ └──────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│  🏠      📣      🧾      🎧      👤         │
└──────────────────────────────────────────────┘
```

### 1.2. Components & quy tắc

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| Card ticket | touch ≥44px | Mã + chủ đề + trạng thái client + cam kết SLA read-only (song song giờ tenant + GMT+7) |
| Load more | cursor server-side, 20/lần | Danh sách dài: không pagination page (mobile) — nút "Xem thêm" cuối danh sách |
| WaitingOnIndicator | "Đang chờ phản hồi từ bạn — đã X ngày" | Kèm nút trả lời nhanh; auto-Closed phải hiện rõ lý do "khách không phản hồi" + nút Mở lại |
| Badge tab icon | `{đang mở}` tối đa 9+ | Từ `meta.unread_count` |
| EmptyState | "Chưa có ticket nào — Tạo ticket" | Đúng 1 CTA chính |

**States:** loading skeleton; error + Thử lại; offline → composer khóa + banner "Cần kết nối mạng để gửi ticket", phần đọc hiển thị nhãn "dữ liệu cũ" (không phục vụ từ cache ngầm — bỏ offline-draft theo Navigation 4.5).

---

## 2. TABS

N/A — list → tạo (M1) → thread (M2) là stack full-screen trong group.

---

## 3. DIALOGS

N/A — CSAT dùng bottom sheet S2 ngay trên thread khi Closed; thông báo dùng Toast/banner.

---

## 4. SHEETS

### 4.1. Sheet: Phản hồi nhanh (`UI-MPO-TCKT-001-S1`)

Mở từ push banner/quick reply trên card "chờ bạn": textarea 1–3 dòng + Gửi → ghi vào thread như phản hồi chính thức qua kênh portal (CORE quyết resume clock — BR-MP-007). Idempotency-Key; lỗi mạng → giữ nội dung đã nhập, không mất draft (BR-MP-013).

### 4.2. Sheet: Đánh giá CSAT (`UI-MPO-TCKT-001-S2`)

Khi ticket Closed: 1–5 sao + 1 câu mở; một CSAT/ticket dù nhiều người tenant thấy form; nhắc tối đa 1 lần sau 48h; gửi xong → biểu tượng ẩn, detractor ≤2 chỉ hiển thị "đã ghi nhận — đang liên hệ lại".

---

## 5. VIEW MODES

### 5.1. Mode: Tạo ticket — 1 màn (`UI-MPO-TCKT-001-M1`)

Form 1 cột, body ≥16px: Chủ đề (bắt buộc) · Mô tả (bắt buộc, ≥10 ký tự) · Phân loại (select) · Gắn ngữ cảnh (tùy chọn: campaign/invoice/transaction ref) · Đính kèm. Nút Gửi khóa khi trống; Idempotency-Key chống trùng khi retry. Kết quả đặc biệt hiển thị thẳng: trùng → "Đã gộp vào ticket #…" (dedupe CORE — BR-MP-002); ngoài scope → "Đã tách thành change request — không tính SLA vận hành" (BR-MP-003); khiếu nại nghiêm trọng → "Đã tiếp nhận — đang xử lý cấp cao".

### 5.2. Mode: Thread ticket (`UI-MPO-TCKT-001-M2`)

Full-screen: header mã + trạng thái + cam kết SLA read-only → timeline hội thoại: khách (phải) vs "đội ngũ BCERP" (trái, KHÔNG tên nhân sự); ghi chú nội bộ không bao giờ vào payload; sự kiện hệ thống: "BCERP đã thông báo xử lý trễ — xem phương án, ETA mới (đã đọc 10:32)" → composer trả lời (S1 cho quick reply; nút mở composer đầy đủ) → footer trạng thái: chờ bạn (nút trả lời), Đã đóng trong 7 ngày (nút Mở lại giữ ngữ cảnh), quá 7 ngày (nút Tạo ticket mới tham chiếu), Closed chưa CSAT (mở S2).

---

## 6. API ENDPOINTS

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải danh sách | GET | `/api/v1/mpo/tickets` | API-MPO-027; `page/limit`, `status`, `search`; `meta.unread_count` |
| Mở thread | GET | `/api/v1/mpo/tickets/:id` | API-MPO-028; timeline whitelist — không lộ escalation nội bộ |
| Tạo ticket | POST | `/api/v1/mpo/tickets` | API-MPO-029; Idempotency-Key; `source=portal(mobile)`; dedupe CORE |
| Trả lời | POST | `/api/v1/mpo/tickets/:id/comments` | API-MPO-030; phản hồi chính thức |
| Mở lại | POST | `/api/v1/mpo/tickets/:id/reopen` | API-MPO-031; chỉ trong 7 ngày kể từ Closed |
| Gửi CSAT | POST | `/api/v1/mpo/tickets/:id/csat` | API-MPO-032; 1–5 + câu mở, 1 lần/ticket |

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-MPO-TCKT-001` | Main | Danh sách ticket + chips + nút Tạo |
| `UI-MPO-TCKT-001-M1` | View Mode | Tạo ticket — 1 màn hình |
| `UI-MPO-TCKT-001-M2` | View Mode | Thread full-screen + composer |
| `UI-MPO-TCKT-001-S1` | Sheet | Phản hồi nhanh (quick reply) |
| `UI-MPO-TCKT-001-S2` | Sheet | Đánh giá CSAT sau đóng |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/mobile-portal/ticket-cskh/ticket-va-cskh.md` | FEAT-MPO-CSKH-001 |
| Tính năng thông báo | `../../../phase2-features/mobile-portal/sla-notif/sla-va-notification-engine.md` | FEAT-MPO-SLANOT-001 |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | §6.5 Ticket & CSAT |
| Design system | `../../design-system.md` | §4.11 WaitingOnIndicator, §7 mobile |
| Navigation tổng quan | `../Navigation-mobile-portal.md` | §4.3 push deep-link, §4.4 map trạng thái |
