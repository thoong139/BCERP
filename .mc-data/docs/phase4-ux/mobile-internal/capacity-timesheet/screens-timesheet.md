# Screen Group: M3 — Timesheet của tôi

> **System:** Mobile App BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** `capacity-timesheet`
> **Tính năng:** FEAT-MBI-CAPTS-001
> **Route:** `/m/timesheet`
> **Main UI-ID:** `UI-MBI-TS-001/002`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-mobile-internal.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-MBI-CAPTS-001 (ghi nhanh offline-first, nhãn billable, theo dõi duyệt 48h — BR-001, BR-002, BR-004, BR-010, BR-012; duyệt phía WEB: FEAT-ERP-CAPTS-002)

---

## Thông Tin Chung

| Trường                  | Giá trị                                                                                                                                                                                                                                                                                                                                                                                              |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Workspace                 | Mobile ESS — nhân viên có giờ dự án (OPS chủ yếu), chỉ timesheet của chính mình                                                                                                                                                                                                                                                                                                           |
| Đối tượng nghiệp vụ | `timesheet_entry`: QUEUED_OFFLINE (client-only) → LOGGED → SUBMITTED → APPROVED/REJECTED (+CORRECTION_PENDING); `capacity_week` đọc băng màu                                                                                                                                                                                                                                                |
| Vai trò chính           | Nhân viên ghi nhanh cuối ngày + chốt tuần; người duyệt (TL 48h ∥ chân HR theo REQ-HR-009) hiển thị "đang chờ ai"                                                                                                                                                                                                                                                                        |
| Workflow stage            | Ghi hằng ngày (trước 12:00 hôm sau) → chốt tuần trước 12:00 thứ Hai → duyệt 48h (quá 72h escalate Manager) → giờ APPROVED mới vào P&L (BR-004)                                                                                                                                                                                                                                       |
| Checklist A–J            | A: dòng giờ dự án · B: nhân viên ghi, TL duyệt · C: HR duyệt song song (WEB) · D: như state machine · E: CAPTS web + capacity CORE · F: "tuần này ghi đủ chưa, chờ ai duyệt" · G: ghi/submit/correction · H: tạo dòng, chốt tuần, tạo correction · I: thiếu nhãn, sync bị từ chối, tuần khóa, chậm 3 ngày · J: cần — kênh ghi nhanh ngoài giờ hành chính |

---

## 1. TRANG CHÍNH

```
┌──────────────────────────────────────────────┐
│ ← Timesheet       Tuần 37 (07–13/09) ▾   🔔  │
├──────────────────────────────────────────────┤
│ [Banner: Mất kết nối — dữ liệu nháp trên máy]│ ← chỉ khi offline
│ Tổng tuần 32.5h · Billable 24h · Chờ duyệt   │
│ Trạng thái: Đã chốt T2 09:05 — chờ TL        │
│   Chờ Minh Đức duyệt · SLA 48h còn 31h       │
│ [ + Ghi nhanh cuối ngày ]   (nút chính 44px) │
│ ┌──────────────────────────────────────────┐ │
│ │ T7 12/09 · Khách ABC · 4.0h              │ │
│ │ [Client Billable]                     ●  │ │ chip synced
│ ├──────────────────────────────────────────┤ │
│ │ T6 11/09 · Vận hành nội bộ · 2.5h        │ │
│ │ [Internal Non-billable] ⏳ Chưa đồng bộ  │ │ chip pending
│ ├──────────────────────────────────────────┤ │
│ │ T5 10/09 · Khách ABC · 3.0h              │ │
│ │ [Client Billable] ✖ Từ chối sync: tuần   │ │ chip failed
│ │ đã khóa — tạo ở tuần sau kèm ghi chú     │ │
│ └──────────────────────────────────────────┘ │
│ ⓘ Quá 12:00 thứ Hai chưa chốt sẽ bị nhắc     │
│   (chậm 3 ngày → cảnh báo TL).               │
└──────────────────────────────────────────────┘
```

- **UI-MBI-TS-001 — Tuần của tôi + trạng thái duyệt 48h** (`/m/timesheet`): chọn tuần theo mốc giờ VN (không theo múi giờ thiết bị); header hiển thị tổng giờ + tách **nhãn billable** + tổng đang chờ duyệt (BR-004 — không hiển thị số nào coi giờ chưa duyệt là đã duyệt); WaitingOnIndicator "đang chờ ai" với SLA 48h đếm ngược, quá 72h chip chuyển `--state-sla-breach` kèm "đã escalate Manager". Mỗi dòng card: ngày · dự án/task · giờ (`tabular-nums`) · badge nhãn billable khóa theo project type (REQ-OPS-006) · **chip sync 4 mức** (`synced` im lặng · `syncing` · `pending` vàng · `failed` đỏ + lý do).
- **UI-MBI-TS-002 — Ghi nhanh cuối ngày** (`/m/timesheet/new`, 1 màn hình): dự án/task (Select, danh sách tải cùng bộ form offline) · **nhãn Client Billable / Internal Non-billable bắt buộc chọn trước khi lưu** (BR-001 — thiếu nhãn nút Lưu vô hiệu; nhân sự tuần đầu khóa nhãn Internal mặc định) · ngày (date) · giờ (bàn phím số) · ghi chú. Offline: lưu vào hàng đợi cục bộ kèm `created_at_device` + Idempotency-Key; sync chạy nền khi có mạng — server tái validation (nhãn, tuần mở, trần 48h, cặp project type × nhãn), từ chối một phần không mất bản ghi (BR-012).
- **Quyền sửa:** KHÔNG có sửa nhãn/giờ sau khi ghi (BR-002) — dòng đã sync chỉ có nút "Tạo correction" (lý do bắt buộc, bản gốc bất biến, TL xác nhận 24h). Tuần đã khóa (quá 12:00 T2) không nhận dòng mới — phải tạo ở tuần sau kèm ghi chú.
- **Trạng thái:** loading = skeleton header + 5 card; empty = "Tuần này chưa có giờ — ghi ngay"; error = retry; pull-to-refresh.

---

## 2. TABS

N/A — 1 list tuần + 1 form; việc nhóm/chờ tôi duyệt thuộc M6 `[NEEDS_REVIEW]`, không thiết kế trong lane này.

---

## 3. DIALOGS

N/A — chốt tuần và submit dùng nút trên list với toast xác nhận; không cần modal.

---

## 4. SHEETS

**UI-MBI-TS-001-S — Tạo correction** (bottom sheet từ dòng `LOGGED/SUBMITTED/APPROVED`): hiện giá trị gốc (bất biến), field giá trị đúng + lý do ≥ bắt buộc; gửi về hàng đợi `CORRECTION_PENDING` chờ TL xác nhận 24h — chip trạng thái trên dòng gốc. `[NEEDS_REVIEW: api-contract §6.4 chưa có endpoint MBI cho timesheet_correction — FEAT-MBI-CAPTS-001 có entity nhưng thiếu endpoint]`

---

## 5. VIEW MODES

- **Create:** UI-MBI-TS-002 (ghi nhanh) — cũng dùng để nạp dòng từ draft local.
- **Read:** UI-MBI-TS-001 danh sách tuần + trạng thái duyệt.
- **Edit:** không tồn tại sau khi ghi — thay bằng correction (sheet).

---

## 6. API ENDPOINTS

| Endpoint                                     | Method | Dùng cho                                                       | Ghi chú                                                           |
| -------------------------------------------- | ------ | --------------------------------------------------------------- | ------------------------------------------------------------------ |
| `/api/v1/mbi/ess/timesheets` (API-MBI-024) | POST   | Nhập/lưu draft + submit dòng timesheet                       | Offline**allowed (ess)**; Idempotency-Key + client_timestamp |
| `/api/v1/mbi/ess/timesheets` (API-MBI-025) | GET    | Tuần của tôi: dòng giờ, nhãn, trạng thái duyệt OPS∥HR | Filter`week_key` server-side; không cache client                |
| `/api/v1/mbi/ess/sync` (API-MBI-021)       | POST   | Batch replay outbox khi online                                  | Per-item accepted/rejected + lý do; limit 30 req/phút            |
| correction tạo/từ mobile                   | —     | Sheet UI-MBI-TS-001-S                                           | `[NEEDS_REVIEW: thiếu endpoint MBI cho timesheet_correction]`   |

---

## 7. UI-ID Registry

| UI-ID           | Tên                                  | Loại | Mô tả                                                                         |
| --------------- | ------------------------------------- | ----- | ------------------------------------------------------------------------------- |
| UI-MBI-TS-001   | Tuần của tôi + trạng thái duyệt | list  | Tổng tuần, nhãn billable, WaitingOn 48h, chip sync                           |
| UI-MBI-TS-002   | Ghi nhanh cuối ngày                 | form  | 1 màn: dự án · nhãn bắt buộc · ngày · giờ · ghi chú; offline draft |
| UI-MBI-TS-001-S | Sheet tạo correction                 | sheet | Giá trị gốc bất biến + lý do, chờ TL xác nhận 24h                      |

---

## Tài Liệu Liên Quan

| Nội dung               | File                                                                                     | Ghi chú                              |
| ----------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------- |
| Tính năng nghiệp vụ | `../../../phase2-features/mobile-internal/capacity-timesheet/capacity-va-timesheet.md` | Upstream (BR-001..012, state machine) |
| Tính năng WEB         | `../../../phase2-features/bcerp-web/capacity-timesheet/`                               | Upstream (nhập chi tiết, duyệt)    |
| API chi tiết           | `../../../phase3-architecture/technical-specs/api-contract.md`                         | Upstream                              |
| Design system           | `../../design-system.md`                                                               | Upstream                              |
| Navigation tổng quan   | `../Navigation-mobile-internal.md`                                                     | Upstream                              |
