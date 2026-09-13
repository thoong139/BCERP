# Screen Group: MPO-02 — Campaign theo dõi (mirror P2)

> **System:** Mobile App BC Portal (SYS-MOBILE-PORTAL)
> **Module:** `client-portal`
> **Tính năng:** FEAT-MPO-CAMP-001
> **Route:** `/campaigns`
> **Main UI-ID:** `UI-MPO-CAMP-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-mobile-portal.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-MPO-CAMP-001

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-MPO-CAMP-001` |
| Route | `/campaigns` |
| Loại | List + Detail (stack trong group) |
| FEAT-ID | FEAT-MPO-CAMP-001 |
| Người dùng | CUSTOMER (CLIENT_ADMIN / CLIENT_USER) |

**Checklist B0:** Workspace = Client Portal (mirror P2). Đối tượng = campaign + milestone/deliverable **đã share** (bản ghi share + `wbs_node_ref` hợp lệ — BR-MPO-CAMP-001). Stage = planned → in_flight → delivered → reported, render bằng ngôn ngữ client: *Chuẩn bị · Đang thực hiện · Đã bàn giao · Đã báo cáo* (Navigation §4.4). Quyết định của khách tại đây: **confirm nghiệm thu** (chỉ CLIENT_ADMIN, step-up) hoặc **yêu cầu chỉnh sửa** (comment bắt buộc) — 2 hành động ghi duy nhất (BR-MPO-CAMP-004). Cấm lộ: task nội bộ, người thực hiện, SLA duyệt creative, số vòng sửa, chuỗi escalate (BR-MPO-CAMP-002/005). Push "campaign cập nhật" deep-link thẳng vào detail.

---

## 1. TRANG CHÍNH

### 1.1. Layout

```
┌──────────────────────────────────────────────┐
│ Campaign            [Tìm theo tên campaign…] │
│ (Đang thực hiện ×) (Chuẩn bị ×) (Tất cả ×)   │ ← quick filter chips, tháo được
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ ▸ TikTok Mùa hội tụ        [Đang thực hiện]│ ← StatusBadge ngôn ngữ client
│ │ Mục tiêu: Conversion · Milestone 2/4     │ │ ← nhãn mục tiêu nguyên văn từ CORE
│ │ Chờ bạn: xác nhận nghiệm thu MS-02       │ │ ← WaitingOnIndicator phiên client
│ │ cập nhật 08:45 · nguồn api               │ │ ← freshness bắt buộc (BR-MPO-CAMP-008)
│ ├──────────────────────────────────────────┤ │
│ │ ▸ Facebook Khui hàng T9     [Đã báo cáo] │ │
│ └──────────────────────────────────────────┘ │
│              (pull-to-refresh; card 1 cột)   │
├──────────────────────────────────────────────┤
│  🏠      📣      🧾      🎧      👤         │
└──────────────────────────────────────────────┘
```

### 1.2. Components & quy tắc

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| Card campaign | touch ≥44px; badge ≤1 trạng thái chính | Chỉ campaign đã share; campaign nội bộ/không gắn WBS không tồn tại (BR-MPO-CAMP-011) |
| ProgressTracker | compact chip-line: current + tổng | "Milestone 2/4" — không lộ gate nội bộ |
| WaitingOnIndicator | phiên client "Đang chờ phản hồi từ bạn — xác nhận nghiệm thu MS-02, đã X ngày" | Nhắc ngày 2, escalate ngày 4 — app chỉ hiển thị "đang nhắc/đang escalate", KHÔNG tự "đạt" khi hết hạn (không "im lặng = đồng ý") |
| Freshness | `freshness` bắt buộc mỗi card | `manual` → nhãn nguồn + timestamp; thiếu → không render |

**States:** loading = skeleton card; empty = "Chưa có campaign được chia sẻ"; error = Thử lại; deep-link vào object đã thu hồi share → màn từ chối truy cập hợp lệ kèm giải thích (BR-MPO-CAMP-006). Offline: chỉ đọc cache gắn "cần làm mới" — cấm confirm/chỉnh sửa từ cache (BR-MPO-CAMP-007).

---

## 2. TABS

N/A — list → chi tiết là stack full-screen trong cùng group (consolidation §2.0.5), không tab.

---

## 3. DIALOGS

N/A — hai hành động ghi dùng bottom sheet S1/S2 ngay trong ngữ cảnh milestone.

---

## 4. SHEETS

### 4.1. Sheet: Xác nhận nghiệm thu (`UI-MPO-CAMP-001-S1`)

Tóm tắt milestone (tên, deliverable đã nghiệm thu, khung 3 ngày còn lại) + xác minh sinh trắc học/2FA. Nút chính: **Tôi xác nhận nghiệm thu** (chỉ CLIENT_ADMIN — CLIENT_USER không thấy nút, chỉ thấy ghi chú "liên hệ quản trị của bạn"). Processing: spinner + khóa nút chống double-submit; Idempotency-Key. Sau confirm → milestone chuyển "Đã bàn giao", timeline thêm dòng có dấu vết.

### 4.2. Sheet: Yêu cầu chỉnh sửa (`UI-MPO-CAMP-001-S2`)

CLIENT_ADMIN/CLIENT_USER. Textarea comment **bắt buộc** (≥10 ký tự) + nút Gửi. Server ghi nhận → trạng thái quay lại "Đang thực hiện" phía khách, timeline hiển thị "Bạn đã yêu cầu chỉnh sửa".

---

## 5. VIEW MODES

### 5.1. Mode: Chi tiết campaign (`UI-MPO-CAMP-001-M1`)

Full-screen (`chevron-left`): header tên + nhãn mục tiêu + trạng thái client → **stepper** ngang rút gọn (Chuẩn bị · Đang thực hiện · Đã bàn giao · Đã báo cáo; node hiện tại tô primary, node có hành động chờ khách kèm WaitingOn) → **timeline** chỉ gồm deliverable **đã nghiệm thu** + sự kiện khách thấy được (bàn giao, xác nhận, báo cáo; thời gian tuyệt đối dd/MM HH:mm, song song giờ tenant + GMT+7) → danh sách milestone: đã đạt (đậm) / chờ bạn (nút mở S1/S2) / đang làm (chỉ trạng thái tổng pipeline: đang soạn → đang sản xuất → đã duyệt nội bộ → chờ nghiệm thu). Chi tiêu tham chiếu (nếu share) kèm nhãn `api`/`manual` + timestamp — không ghi tài chính.

---

## 6. API ENDPOINTS

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải danh sách | GET | `/api/v1/mpo/campaigns` | API-MPO-023; `page/limit`, `status`, `search`; chỉ bản ghi share hợp lệ |
| Mở chi tiết | GET | `/api/v1/mpo/campaigns/:id` | API-MPO-024; milestones + khung nghiệm thu còn lại |
| Xác nhận nghiệm thu | POST | `/api/v1/mpo/campaigns/:id/milestones/:mid/confirm` | API-MPO-025; CLIENT_ADMIN + step-up; Idempotency-Key; ngoài khung → 409 `MILESTONE_WINDOW_CLOSED` |
| Yêu cầu chỉnh sửa | POST | `/api/v1/mpo/campaigns/:id/milestones/:mid/revision` | API-MPO-026; comment bắt buộc |
| Pull-to-refresh | GET | các GET trên | ETag; trạng thái luôn resync với CORE, push không phải nguồn sự thật |

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-MPO-CAMP-001` | Main | Danh sách campaign đã share + filter chips |
| `UI-MPO-CAMP-001-M1` | View Mode | Chi tiết campaign — stepper + timeline + milestones |
| `UI-MPO-CAMP-001-S1` | Sheet | Xác nhận nghiệm thu (CLIENT_ADMIN, step-up) |
| `UI-MPO-CAMP-001-S2` | Sheet | Yêu cầu chỉnh sửa (comment bắt buộc) |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/mobile-portal/campaign-deliverable/campaign-va-deliverable-management.md` | FEAT-MPO-CAMP-001 |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | §6.4 Campaign & Confirm |
| Design system | `../../design-system.md` | §4.7 ProgressTracker, §4.11 WaitingOnIndicator |
| Navigation tổng quan | `../Navigation-mobile-portal.md` | §4.3 push deep-link, §4.4 map trạng thái |
