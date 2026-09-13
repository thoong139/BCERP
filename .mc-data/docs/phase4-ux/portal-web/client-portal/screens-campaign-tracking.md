# Screen Group: P2 — Campaign theo dõi (client view)

> **System:** Client Portal Web (SYS-PORTAL-WEB)
> **Module:** `client-portal`
> **Tính năng:** FEAT-PORTAL-CPORT-001 + CAMP-002
> **Route:** `/portal/campaigns`
> **Main UI-ID:** `UI-PWEB-CAMP-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-portal-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-PORTAL-CPORT-001, FEAT-ERP-CAMP-002

---

## Thông Tin Common

| Hạng mục | Giá trị | Hạng mục | Giá trị |
|---|---|---|---|
| Workspace | Client Portal (external) | Workflow stage | CAMP `planned→in_flight→delivered→reported`; milestone nghiệm thu khung 3 ngày làm việc (nhắc ngày 2, escalate ngày 4 — nội bộ, không hiện cho khách) |
| Đối tượng nghiệp vụ | Campaign + deliverable **đã nghiệm thu** (read-view client-scoped) | Cross-module | CAMP nội bộ (S14 — nguồn thật); P4 (dispute → ticket gắn `campaign_id`); ví S1 (chi tiêu — xem riêng, không trộn) |
| Vai trò chính | CUSTOMER (CLIENT_ADMIN, CLIENT_USER) | Quyết định của client | Xác nhận nghiệm thu milestone `accepted`/`disputed` — KHÔNG "im lặng = đồng ý" |
| Vai liên quan (ẩn) | OPS_AM/OPS_CONT — hiển thị chung "đội ngũ BCERP" | Exceptions | Hết khung nghiệm thu (`MILESTONE_WINDOW_CLOSED`), milestone đang đối soát, nguồn stale |

**Bảo mật hiển thị (bắt buộc):** KHÔNG hiển thị chi phí/giá trị nội bộ, WBS nội bộ, issue nội bộ, assignee/tên nhân sự, ghi chú nội bộ, A/B variant nội bộ `[NEEDS_REVIEW: state chi tiết A/B — API-ERP-051/053]`. Machine state luôn map sang ngôn ngữ client.

---

## 1. TRANG CHÍNH

**List campaign** (mặc định) — bảng comfortable + quick filter chips; mobile render card 44px.

```
┌──────────────────────────────────────────────────────────────────┐
│ Campaign của tôi        [Tìm trong campaign của tôi] [Lọc ▾]     │
│ (Đang thực hiện · 3×) (Chờ bạn nghiệm thu · 1×) (Đã báo cáo ×)   │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Campaign            Thời gian        Trạng thái     Hành động│ │
│ │ Tiktok Summer 26    01/08–30/09      ● Đang thực hiện  Xem →  │ │
│ │                                      ⏳ 1 milestone chờ bạn      │ │
│ │ Brand Refresh Q3    15/06–15/08      ◐ Đã bàn giao     Xem →  │ │
│ │ Launch Checklist    01/07–31/07      ✔ Đã báo cáo      Xem →  │ │
│ └──────────────────────────────────────────────────────────────┘ │
│ Trang 1/2 — 20/trang ▾              (pagination server-side)     │
└──────────────────────────────────────────────────────────────────┘
```

- Cột: tên campaign, kỳ chạy, `StatusBadge` theo ngôn ngữ client, cột chú ý (milestone chờ khách — WaitingOnIndicator variant chờ client: *"Đang chờ phản hồi từ bạn — vui lòng trả lời trước 18/09"*). Sort theo kỳ chạy; filter `status` server-side; pagination 20/50.
- **Trạng thái:** loading = skeleton 10 hàng; empty = EmptyState *"Chưa có chiến dịch nào — chiến dịch xuất hiện tại đây sau khi bàn giao khởi động"*; error = EmptyState + "Thử lại"; stale = nhãn *"Cập nhật lúc {hh:mm}"* (freshness realtime theo BR-007 — thiếu metadata không render).

---

## 2. TABS

N/A — không có tab; các khối thông tin (tiến độ, deliverable, lịch sử) xếp dọc trong view chi tiết để cuộn một chiều, hợp mobile bottom sheet thói quen đọc của client.

---

## 3. DIALOGS

**UI-PWEB-CAMP-001-D1 — Xác nhận nghiệm thu milestone**: tóm tắt deliverable/milestone (tên, mô tả client-facing, ngày bàn giao, khung còn lại — *"còn 2 ngày làm việc"*), 2 nút: **Xác nhận đã nhận đúng** (primary → API-PORTAL-026 `accepted`) / **Có vướng mắc** (mở D2). Hết khung → 409 `MILESTONE_WINDOW_CLOSED`: dialog biến thành thông báo *"Khung xác nhận đã đóng — đội ngũ BCERP sẽ liên hệ bạn"* (escalate nội bộ REQ-OPS-006, không bắt client chịu lỗi im lặng).

**UI-PWEB-CAMP-001-D2 — Báo cáo vướng mắc (dispute)**: textarea mô tả (≥10 ký tự) + gửi → API-PORTAL-026 `disputed`; thành công → gợi ý mở dialog tạo ticket (P4) **kèm sẵn `campaign_id`/milestone ref**; milestone hiển thị *"Đang được kiểm tra lại"* kèm số tham chiếu cho đến khi chốt (BR-012 CPORT-002).

---

## 4. SHEETS

N/A — chi tiết deliverable đã nghiệm thu hiển thị inline trong view chi tiết; portal không có khối dữ liệu phụ cần drawer (khác P1/P3 vốn có đối tượng drill-down riêng).

---

## 5. VIEW MODES

**UI-PWEB-CAMP-001-M1 — View chi tiết campaign** (cùng surface, breadcrumb `Campaign của tôi › [Tên]`, không route riêng):

```
┌──────────────────────────────────────────────────────────────────┐
│ ← Campaign của tôi › TikTok Summer 26        ● Đang thực hiện    │
│ Kỳ chạy 01/08–30/09 · Cập nhật 13/09 08:32                       │
│                                                                  │
│ ○───●───○───○   Chuẩn bị · Đang thực hiện (hiện tại) ·           │
│                 Đã bàn giao · Đã báo cáo                         │
│ ⏳ Đang chờ phản hồi từ bạn — trả lời trước 18/09                │
│                                                                  │
│ DELIVERABLE / MILESTONE                                          │
│ ✔ Bộ nội dung video x8 — đã nghiệm thu 05/09                    │
│ ✔ Lịch đăng 4 tuần — đã nghiệm thu 08/09                        │
│ ● Báo cáo hiệu quả tuần 1 — chờ bạn xác nhận [Xác nhận] [Vướng mắc]│
│ ○ Báo cáo tổng kết — chưa đến hạn                                │
│                                                                  │
│ LỊCH SỬ TIẾN ĐỘ (Timeline full)                                  │
│ ● 12/09 — Bàn giao "Báo cáo tuần 1" — đội ngũ BCERP              │
│ ● 08/09 — Bạn xác nhận "Lịch đăng 4 tuần"                        │
│ ● 05/09 — Bạn xác nhận "Bộ nội dung video x8"                    │
└──────────────────────────────────────────────────────────────────┘
```

- **ProgressTracker stepper ngang** 4 mốc client: *Chuẩn bị · Đang thực hiện · Đã bàn giao · Đã báo cáo* (map từ `planned/in_flight/delivered/reported` — Navigation §4.5); node hiện tại primary + `aria-current`, mobile rút thành chip-line (current/tổng).
- **Khối deliverable:** chỉ liệt kê deliverable **đã nghiệm thu** + milestone đang chờ khách; deliverable nội bộ chưa bàn giao không hiện (chỉ tổng quát qua stepper). Milestone `disputed` hiển thị *"Đang được kiểm tra lại" + số tham chiếu*, không hiện như đã xong.
- **Timeline full:** mỗi entry — actor (khách = tên user; BC = "đội ngũ BCERP", không tên nhân sự), hành động, thời gian tuyệt đối dd/MM HH:mm. Không có activity nào → "Chưa có hoạt động".
- Mobile: stepper → chip-line, danh sách deliverable → card 44px, dialog D1/D2 → bottom sheet.
- Chỉ khách quyết định nghiệm thu; state machine nghiệm thu thực thi ở CAMP nội bộ — portal chỉ tiếp nhận (API-PORTAL-026 ghi nhận, không tự chuyển state).

---

## 6. API ENDPOINTS

| Endpoint | Method | Dùng ở đâu | Tham số chính |
|---|---|---|---|
| API-PORTAL-024 `/campaigns` | GET | List + chips filter | `status`, `page/limit` (mặc định 20, max 100) |
| API-PORTAL-025 `/campaigns/:campaignId` | GET | View chi tiết M1 | — (kèm milestones + khung nghiệm thu còn lại) |
| API-PORTAL-026 `/campaigns/:campaignId/milestones/:milestoneId/acceptance` | POST | D1/D2 | `{decision: "accepted"\|"disputed", note?}`; ngoài khung → 409 `MILESTONE_WINDOW_CLOSED` |
| API-PORTAL-029 `/tickets` | POST | D2 (tạo ticket kèm `campaign_id` sau dispute) | `category`, `context_refs`, `source=PORTAL` |
| API-PORTAL-036 `/meta/freshness` | GET | Nhãn "Cập nhật lúc" (view_group campaign) | — |

`[NEEDS_REVIEW: bộ trường hiển thị khách của API-PORTAL-024 — Phụ lục A #19; nếu whitelist không gắn trạng thái milestone theo client thì cần bổ sung trường read-model]`

---

## 7. UI-ID Registry

| UI-ID | Thành phần | Loại | Ghi chú |
|---|---|---|---|
| `UI-PWEB-CAMP-001` | Danh sách campaign + filter chips | list | Route `/portal/campaigns`, comfortable, pagination server-side |
| `UI-PWEB-CAMP-001-M1` | View chi tiết: stepper + deliverable đã nghiệm thu + Timeline | detail-view | Cùng surface, breadcrumb 2 cấp, không route riêng |
| `UI-PWEB-CAMP-001-D1` | Dialog xác nhận nghiệm thu milestone | confirm-dialog | POST API-PORTAL-026 `accepted` |
| `UI-PWEB-CAMP-001-D2` | Dialog dispute → ticket kèm ref | form-dialog | POST API-PORTAL-026 `disputed` → API-PORTAL-029 |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/` | Upstream |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../design-system.md` | Upstream |
| Navigation tổng quan | `../Navigation-portal-web.md` | Upstream |
