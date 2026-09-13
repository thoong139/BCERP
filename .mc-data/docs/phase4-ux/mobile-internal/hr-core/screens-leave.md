# Screen Group: M4 — Nghỉ phép của tôi

> **System:** Mobile App BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** `hr-core`
> **Tính năng:** FEAT-ERP-HRCORE-003..004 (xem ghi chú registry)
> **Route:** `/m/leave`
> **Main UI-ID:** `UI-MBI-LEAVE-001/002`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-mobile-internal.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-ERP-HRCORE-004 (Nghỉ phép: số dư tự động & duyệt phân cấp — REQ-HR-004; mobile chỉ là điểm tạo đơn — BR-008) · FEAT-ERP-HRCORE-003 (công cập nhật theo loại nghỉ)

> `[NEEDS_REVIEW: REQ-HR-003/004/005 chưa có FEAT touchpoint MBI trong registry (api-contract §6.4) — endpoint MBI-022/023 thiết kế theo baseline actor ESS × MOBILE-INTERNAL]`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Workspace | Mobile ESS — mọi nhân viên, chỉ đơn + số dư của chính mình |
| Đối tượng nghiệp vụ | `LeaveRequest` (DRAFT → PENDING → PENDING_TL/PENDING_HR → APPROVED/REJECTED → CONSUMED) + số dư phép tự động 12 ngày/năm |
| Vai trò chính | Nhân viên lập đơn; người duyệt (TL 24h / HR_L2 48h) chỉ hiển thị "đang chờ ai" |
| Workflow stage | Tạo đơn đúng mức báo trước §8 → vào workflow duyệt REQ-HR-004 trên WEB/CORE — **mobile KHÔNG có nút duyệt (BR-008)** |
| Checklist A–J | A: đơn nghỉ/số dư · B: nhân viên · C: TL/HR_L2 (bên duyệt) · D: requested → balance_check → phân cấp → kết quả · E: HR-CORE, capacity giảm sau duyệt · F: "số dư còn bao nhiêu, đơn đang chờ ai" · G: chỉ quyết định gửi đơn · H: tạo đơn · I: thiếu mức báo trước, thiếu giấy khám, từ chối · J: cần — tạo đơn lúc không ngồi máy |

---

## 1. TRANG CHÍNH

```
┌──────────────────────────────────────────────┐
│ ← Nghỉ phép của tôi                     🔔   │
├──────────────────────────────────────────────┤
│ Số dư phép năm 2026: 8.5 / 12 ngày           │
│ (tự động — không nhập tay; cộng dồn chờ QĐ)  │
│ [ + Tạo đơn nghỉ / công tác ]                │
│                                              │
│ Đơn của tôi                                  │
│ ┌──────────────────────────────────────────┐ │
│ │ Phép năm · 18–19/09 · 2.0 ngày           │ │
│ │ [Chờ duyệt] Chờ TL Minh Đức · SLA 24h ·  │ │
│ │ đã chờ 5 giờ                             │ │
│ ├──────────────────────────────────────────┤ │
│ │ Ốm · 01–03/09 · 3 ngày · có giấy khám    │ │
│ │ [Đã duyệt] HR_L2 duyệt 01/09 16:20       │ │
│ ├──────────────────────────────────────────┤ │
│ │ Phép năm · 25/08 · 1 ngày                │ │
│ │ [Bị từ chối] Lý do: trùng chạy campaign  │ │
│ └──────────────────────────────────────────┘ │
│ ⓘ Mobile không có nút duyệt — duyệt thực     │
│   hiện trên WEB/CORE (BR-008).               │
└──────────────────────────────────────────────┘
```

- **UI-MBI-LEAVE-001 — Số dư + đơn của tôi** (`/m/leave`): khối số dư đọc từ LeaveBalance của core tại thời điểm đọc (không cache vĩnh viễn, không nhập tay); list đơn dạng card, mỗi card 1 StatusBadge + **WaitingOnIndicator "đang chờ ai"** (avatar + tên người duyệt + SLA còn lại, màu neutral → `--state-sla-warning` ≥50% → `--state-sla-breach`). Kết quả duyệt/từ chối từ WEB/CORE đến qua push (`mobile://leave`). Pull-to-refresh; lọc theo trạng thái server-side.
- **UI-MBI-LEAVE-002 — Tạo đơn 1 màn hình** (`/m/leave/new`, không wizard): loại nghỉ (Select) · từ–đến (date picker, kèm chọn buổi cho nghỉ ½ ngày) · lý do (textarea). Số ngày làm việc tính theo ngày làm việc không tính T7/CN/lễ.
- **Cảnh báo ngay khi soạn (field-level WarningIndicator):** đơn thiếu mức thông báo trước §8 (½ ngày báo trước ½ ngày; 1–dưới 3 ngày ≥1 ngày; ≥3 ngày ≥4 ngày; công tác trước 2 tiếng) → cảnh báo vàng "Nghỉ X ngày cần báo trước Y — đơn sẽ vào luồng retro kèm lý do". Ốm ≥3 ngày: field đính kèm giấy khám bắt buộc xuất hiện theo loại nghỉ. Nghỉ hết phép: chỉ mở luồng bất khả kháng có chứng minh (HR_L2 duyệt).
- **Trạng thái:** loading skeleton; empty đơn = "Chưa có đơn nào" + CTA tạo; error = retry; offline → form vẫn điền được, nút chuyển "Lưu và gửi khi có mạng" (đơn vào hàng đợi, balance check chạy khi sync — số dư chưa trừ đến khi duyệt).

---

## 2. TABS

N/A — 1 list + 1 form push lên stack; số dư là khối trong list, không tách tab.

---

## 3. DIALOGS

N/A — cảnh báo mức báo trước/giấy khám là field-level; xác nhận gửi dùng toast thành công kèm trạng thái sync.

---

## 4. SHEETS

**UI-MBI-LEAVE-002-S — Chi tiết đơn bị từ chối** (bottom sheet từ card `REJECTED`): hiện người duyệt, thời điểm, lý do bắt buộc từ chối, CTA "Tạo đơn mới" (đơn cũ giữ `REJECTED` làm lịch sử, không sửa).

---

## 5. VIEW MODES

- **Create:** UI-MBI-LEAVE-002 (mode duy nhất ghi dữ liệu).
- **Read:** danh sách + chi tiết đơn chỉ đọc; không có Edit/Approve trên mobile (duyệt ở WEB/CORE theo phân cấp REQ-HR-004).

---

## 6. API ENDPOINTS

| Endpoint | Method | Dùng cho | Ghi chú |
|----------|--------|----------|---------|
| `/api/v1/mbi/ess/leave-requests` (API-MBI-022) | POST | Tạo đơn | Offline **allowed (ess)**; balance check do HR-CORE thực khi nhận/replay; Idempotency-Key + client_timestamp |
| `/api/v1/mbi/ess/leave-requests` (API-MBI-023) | GET | Danh sách đơn + trạng thái phân cấp duyệt L1→L2 | Không cache client; pagination server-side |
| `/api/v1/erp/ess/me` (API-ERP-066) | GET | Số dư phép hiện hành (LeaveBalance của core) | `[NEEDS_REVIEW: MBI chưa có GET leave-balance riêng]` |
| `/api/v1/mbi/ess/sync` (API-MBI-021) | POST | Replay đơn tạo khi offline | Trả per-item accepted/rejected + lý do |

---

## 7. UI-ID Registry

| UI-ID | Tên | Loại | Mô tả |
|-------|-----|------|-------|
| UI-MBI-LEAVE-001 | Số dư + đơn của tôi | list | Số dư tự động, card đơn + WaitingOnIndicator, không nút duyệt (BR-008) |
| UI-MBI-LEAVE-002 | Tạo đơn nghỉ/công tác | form | 1 màn: loại · từ–đến · lý do; cảnh báo mức báo trước §8 |
| UI-MBI-LEAVE-002-S | Sheet chi tiết từ chối | sheet | Người duyệt + lý do + CTA tạo đơn mới |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/bcerp-web/hr-core/nghi-phep-so-du-tu-dong-va-duyet-phan-cap.md` | Upstream (REQ-HR-004) |
| Tính năng mobile | `../../../phase2-features/mobile-internal/capacity-timesheet/capacity-va-timesheet.md` | Upstream (BR-008 tạo đơn từ mobile) |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../design-system.md` | Upstream |
| Navigation tổng quan | `../Navigation-mobile-internal.md` | Upstream |
