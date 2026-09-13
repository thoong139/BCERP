# Screen Group: M2 — Chấm công

> **System:** Mobile App BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** `hr-core`
> **Tính năng:** FEAT-MBI-CAPTS-001 (HRCORE-002)
> **Route:** `/m/attendance`
> **Main UI-ID:** `UI-MBI-ATT-001/002`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-mobile-internal.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-MBI-CAPTS-001 (chấm công mobile — BR-007, BR-012) · FEAT-ERP-HRCORE-003 (Chấm công & overtime — REQ-HR-003; Navigation quy về HRCORE-002)

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Workspace | Mobile ESS — mọi nhân viên (đặc biệt field staff), chỉ công của chính mình |
| Đối tượng nghiệp vụ | `attendance_record` — check-in/out + lịch chấm cá nhân, đối chiếu nguồn vân tay (REQ-HR-003) |
| Vai trò chính | Nhân viên check-in/out; điều chỉnh công KHÔNG thực hiện trên mobile (luồng REQ-HR-003 ở WEB/CORE) |
| Workflow stage | Ghi nhận hằng ngày; cờ trễ do server gắn khi lệch khung giờ §8; lệch hai nguồn → luồng điều chỉnh có duyệt |
| Checklist A–J | A: bản ghi công ngày · B: nhân viên · C: HR_L1 (đối soát) · D: ghi → đối chiếu → điều chỉnh (ngoài mobile) · E: HR-CORE · F: "tôi đã chấm chưa, tuần nay ra sao" · G: chỉ quyết định chấm · H: check-in/out · I: offline, ngoài khung, quên chấm · J: cần — tác vụ 5 giây/ngày |

---

## 1. TRANG CHÍNH

```
┌──────────────────────────────────────────────┐
│ Chấm công                               🔔   │
├──────────────────────────────────────────────┤
│ Thứ Hai 14/09/2026 · 08:02 (giờ VN)          │
│ ┌──────────────────────────────────────────┐ │
│ │      [ action-checkin  CHECK-IN ]        │ │  nút ~64px
│ │  Đã check-in 08:02 — khung sáng 08:30    │ │  trạng thái hiện tại
│ └──────────────────────────────────────────┘ │
│ ⚠ Mất kết nối — nút chấm tạm tắt: timestamp  │  ← chỉ khi offline
│   phải do server ghi. Có mạng rồi thử lại.   │
│                                              │
│ Lịch chấm của tôi · Tuần 37      [Tuần ▾]    │
│ ┌──────────────────────────────────────────┐ │
│ │ T2 14/09 · 08:02 → 17:31   Đúng giờ      │ │
│ │ T1 13/09 · 08:47 → 17:30   Muộn 17′ ⚠    │ │
│ │ T6 11/09 · 08:30 → 17:32   Đúng giờ      │ │
│ └──────────────────────────────────────────┘ │
│ ⓘ Quên chấm: 2 lần đầu/tháng có xác nhận     │
│   HCNS vẫn tính công — lần 3 không tính (§8).│
│   Đề nghị điều chỉnh tại WEB (Mở trên web).  │
└──────────────────────────────────────────────┘
```

- **UI-MBI-ATT-001 — nút Check-in/Check-out full-width ~64px**: một nút duy nhất đổi nhãn theo trạng thái hiện tại ("Đã check-in 08:02" nằm ngay phía trên nút — Navigation §4.5). **Timestamp server-authoritative**: giờ hiển thị sau khi server xác nhận; khi offline nút chuyển disabled kèm lý do — không ghi giờ cục bộ cho chấm công (khác timesheet). Request mang `client_timestamp` + `gps?` + Idempotency-Key, server là trọng tài chống chấm hộ. Check-in ngoài khung §8 (sáng 08:30–12:00, chiều 13:00–17:30) vẫn được ghi nhận, server gắn cờ trễ để áp chế tài — app chỉ hiển thị nhãn "Muộn" từ dữ liệu trả về, không tự kết luận.
- **UI-MBI-ATT-002 — Lịch chấm của tôi** (route `/m/attendance/history`, push lên stack): list card theo ngày, mỗi card 1 StatusBadge trạng thái chính, pull-to-refresh, chọn tuần server-side. Bản ghi nguồn vân tay hoặc điều chỉnh bởi HR hiển thị nguồn + nhãn "đã điều chỉnh" — mobile chỉ đọc, không ghi đè công.
- **Trạng thái:** loading = skeleton nút + 5 card; empty = "Chưa có bản ghi trong tuần"; error = nút retry; offline → nút disabled + banner lý do, lịch hiển thị cache kèm mốc thời điểm đọc.
- **Sai sót/quên chấm:** mobile không tự sửa công — CTA "Mở trên web" dẫn luồng điều chỉnh REQ-HR-003 (người khác duyệt, bản gốc bất biến).

---

## 2. TABS

N/A — 1 màn hình + 1 route con lịch sử; không phân tab.

---

## 3. DIALOGS

N/A — check-in là 1 chạm, không xác nhận thêm (tác vụ 5 giây); kết quả = toast từ server ("Đã ghi nhận 08:02").

---

## 4. SHEETS

**UI-MBI-ATT-001-S — Chi tiết bản ghi chưa đồng bộ** (bottom sheet, mở từ chip `failed` trên card lịch): hiển thị 1 trong 4 mức sync bắt buộc (`synced` im lặng · `syncing` spinner · `pending` "Chưa đồng bộ — sẽ gửi khi có mạng" · `failed` "Đồng bộ bị từ chối: [lý do] — cần hành động"), nút "Thử đồng bộ lại" (chỉ online). Bản ghi không bao giờ bị xóa (BR-012 — append-only).

---

## 5. VIEW MODES

N/A — 1 mode thao tác (check-in/out) + 1 mode đọc (lịch). Không có tạo/sửa trên mobile.

---

## 6. API ENDPOINTS

| Endpoint | Method | Dùng cho | Ghi chú |
|----------|--------|----------|---------|
| `/api/v1/mbi/ess/attendance` (API-MBI-019) | POST | Check-in/out; body `{action, client_timestamp, gps?}` + Idempotency-Key | Contract cho phép offline (ess) nhưng UI chặn offline theo Navigation §4.5 — server-authoritative |
| `/api/v1/mbi/ess/attendance/today` (API-MBI-020) | GET | Trạng thái hôm nay, quyết định nhãn nút | Không cache client |
| `/api/v1/erp/ess/me` (API-ERP-066) | GET | Lịch chấm của tôi (kênh ESS dùng chung WEB, proxy qua BFF) | `[NEEDS_REVIEW: MBI chưa có GET lịch sử attendance riêng — API-MBI-020 chỉ trả hôm nay]` |
| `/api/v1/mbi/ess/sync` (API-MBI-021) | POST | Replay outbox khi có mạng (bản ghi chờ nếu có) | Trả per-item accepted/rejected + lý do |

---

## 7. UI-ID Registry

| UI-ID | Tên | Loại | Mô tả |
|-------|-----|------|-------|
| UI-MBI-ATT-001 | Check-in/out | form | Nút ~64px server-authoritative + trạng thái hiện tại |
| UI-MBI-ATT-002 | Lịch chấm của tôi | list | Card theo ngày/tuần, chip sync, pull-to-refresh |
| UI-MBI-ATT-001-S | Sheet bản ghi chưa đồng bộ | sheet | Lý do từ chối sync + retry |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/mobile-internal/capacity-timesheet/capacity-va-timesheet.md` | Upstream (BR-007, BR-012) |
| Tính năng chấm công WEB | `../../../phase2-features/bcerp-web/hr-core/cham-cong-va-overtime.md` | Upstream (REQ-HR-003) |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../design-system.md` | Upstream |
| Navigation tổng quan | `../Navigation-mobile-internal.md` | Upstream |
