# Screen Group: My Pipeline (worklist lead/deal)

Implements: FEAT-ERP-CRM-001, FEAT-ERP-CRM-002, FEAT-ERP-CRM-003, FEAT-ERP-CRM-004, FEAT-ERP-CRM-005

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `crm`
> **Tính năng:** FEAT-ERP-CRM-001..005
> **Route:** `/sales/pipeline`
> **Main UI-ID:** `UI-WEB-LEAD-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Common

| Trường | Giá trị |
|--------|--------|
| Workspace | Sales Workspace (`/sales/*`) — trang đích của workspace (worklist chính) |
| Đối tượng nghiệp vụ | Lead + Deal trên pipeline V6.0 (machine-state thực thi ở SYS-CORE-BACKEND) |
| Vai trò chính | SALES_L1 (mine) · SALES_L2/L3 (cá nhân + nhóm) · SALES_L4 (phòng, gán owner) · SALES_L5 (toàn Sales) |
| Workflow stage | new → dedup_check → assigned → scored → gate1 → qualified → gate2 → handed_to_cs (+ rejected / recycled) — ánh xạ 10 stage PMS V6.0 (Raw Data → … → DEPLOY) tại §1.4 |
| A. Object đang xử lý | Lead/deal đang chờ hành động: nhập brief, ghi notes, chờ scoring, chờ ký Gate, chờ gán owner |
| B. Primary actors | SALES_L1–L3 thao tác deal của mình; L4/L5 giám sát + phân bổ |
| C. Related actors | OPS_AM (xác nhận Gate 2 — xem tại S4), GDKD (escalate), FIN (hard stop khớp tiền — hiển thị trạng thái read-only) |
| D. Lifecycle | 10 stage V6.0 + LOST/ARCHIVED; tier A–E do scoring quyết, khóa sau Gate 1 |
| E. Cross-module | Gate 2 → Handoff Bridge (S4); WON → tier chuyển CS (S28); quote → Deal Desk (S3); khách → Client 360 |
| F. Information needs | Stage hiện tại + SLA còn lại, tier/điểm CQ, gate status, owner, dấu hiệu trùng, đang chờ ai |
| G. Decisions | Chọn lead cần xử lý tiếp theo; gán lại owner; mở Lead 360 để advance/reject gate |
| H. Actions được phép | Ghi nhận lead, gán/reassign owner (theo quyền), mở pane Lead 360, recycle/hủy trước Gate 1 |
| I. Exceptions | SLA vỡ (Initial Brief 2h, First Meeting 3 ngày, Gate 1 một ngày làm việc, gán owner 4h), lead chưa có owner, lead đang tranh chấp trùng, WON trễ 24h |
| J. Cần chuyển màn hình? | Không — mọi quyết địnhadvance/reject gate thực hiện ngay trong pane Lead 360 (split view W2 40/60), không rời worklist |

---

## 1. TRANG CHÍNH

### 1.1. Layout — Pattern W2 split view (master-detail 40/60)

```
┌──────┬───────────────────────────────────────────────────────────────────────────────┐
│ Nav  │ Topbar: tìm kiếm toàn cục · bell (drawer) · user                              │
│ rail ├───────────────────────────────────────────────────────────────────────────────┤
│ 60px │ Sales > My Pipeline                    [+ Ghi nhận lead]  [Nhập file ▾]       │
│      ├───────────────────────────────────────────────────────────────────────────────┤
│      │ CommandBar: [Lưu view ▾] [Nhóm theo stage ▾]      [Tìm nhanh… ] [Bộ lọc ▾]   │
│      │ Chips: (Của tôi · 23) (Chờ gate · 4) (SLA vỡ · 2 ×) (Tier D–E ×) (Không owner·1)│
│      ├──────────────────────────────────────┬────────────────────────────────────────┤
│      │ DANH SÁCH LEAD/DEAL — 40% (compact)  │ LEAD 360 — 60% (pane S2, lazy-load)    │
│      │ ☐ LD-1041 Cty ABC   QUALIFIED D  ⚠   │ ┌ Header: Cty ABC · Tier D · QUALIFIED │
│      │ ☑ LD-1039 Cty XYZ   BRIEF    C       │ │ WaitingOn: chờ SM ký Gate 1 · 6h     │
│      │ ☑ LD-1036 Cty LMN   GATE1    E  ⏱    │ │ Tabs: Tổng quan|Scoring|Gate|Timeline│
│      │ ☐ LD-1029 Cty PQR   NEW      —  🔒dup│ │ [Advance ▾] [Gate Go/No-Go]          │
│      │ …  row 32px, SLA vỡ tự nhảy đầu      │ └ (chi tiết tại screens-lead-360.md)   │
│      ├──────────────────────────────────────┴────────────────────────────────────────┤
│      │ Bulk bar (khi chọn ≥1): [Đã chọn 2]  [Gán lại chủ sở hữu]  [Bỏ chọn]         │
│      │ Pagination 20/50/100 — server-side · Tổng 128 lead · Đã lọc từ 340            │
└──────┴───────────────────────────────────────────────────────────────────────────────┘
```

Chọn hàng ở danh sách trái **không rời trang** — pane phải load Lead 360 (UI-WEB-LEAD-002, lazy-load theo `:id`). Tablet ≤1279px: split view → master full, pane mở như panel overlay. Mobile <768px: chỉ xem danh sách dạng card + nhận cảnh báo SLA, không advance stage (đúng spec FEAT-ERP-CRM-002). **A11y:** F6 luân chuyển focus master ↔ pane; hàng có `aria-controls` trỏ pane Lead 360; ô Owner trống quá SLA hiển thị text "Chưa gán · quá SLA {duration}" — không chỉ nền màu.

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| DataTable (compact, bulk-selection, saved-views) | row 32px, header 36px sticky, server-side | Keyboard ↑↓/Space/Enter; sort theo click header |
| Quick filter chips | tháo được từng chip, đếm theo scope | Chip "SLA vỡ" màu `--state-sla-breach`, tự nhảy đầu danh sách |
| CommandBar | page-level, nút chính tối đa 1 | Action thiếu quyền bị ẩn (PEP), không disabled |
| Split view | `minmax(360px, 40%) 1fr` | Pane phải = S2 Lead 360, giữ context khi chuyển hàng |
| Bulk bar | trượt lên khi chọn ≥1 hàng | Chỉ hiện action user có quyền |
| Pagination | 20/50/100, server-side | Tổng + số bản ghi đã lọc hiển thị cạnh |
| WaitingOnIndicator (chip trong row) | avatar + duration, màu theo SLA | "chờ SM ký Gate 1 · 6h" — bắt buộc mọi row đang chờ |
| StatusBadge | 1 badge/hàng (stage); phụ đưa tooltip | Tier là chip riêng cột cạnh |

### 1.3. Cột hiển thị

| Cột | Trường | Định dạng | Sort | Ghi chú |
|-----|--------|----------|------|---------|
| Mã lead | `leads.id` (mã nghiệp vụ) | Text mono | — | Không hiển thị UUID nội bộ |
| Khách hàng | `company_name` + `contact_name` | Text, 2 dòng | — | Link mở Client 360 (S28) nếu đã là khách |
| Stage | `leads.status` | StatusBadge (10 token) | Có | Nhóm theo stage qua view option §1.5 |
| Tier | `qualified_tier` (A–E) | Chip + tooltip chú giải | Có (kèm score) | Tooltip: "A <1.5 AUTO LOST … E ≥3.5 tốt nhất" — thang nghịch trực giác, render từ cấu hình |
| Điểm CQ | `cq_score` | Number `tabular-nums` | Có | "—" khi `INSUFFICIENT_DATA`/chưa chấm |
| SLA / Đang chờ | `sla_clocks` | WaitingOnIndicator chip | — | ≥50% → sla-warning; vỡ → sla-breach + icon chuông |
| Gate | `gate_approvals.state` | Badge | — | Chưa mở / Chờ ký SM / Đã Go / No-Go / Chờ AM / Bị trả về |
| Nguồn | `source_channel` | Badge nhỏ | — | landing/zalo/fb/referral/cold |
| Owner | `owner_id` | Avatar + tên | — | Trống + nền đỏ nhạt khi quá SLA gán 4h |
| Cảnh báo | dedup/late_flag | Icon warning inline | — | 🔒 trùng đang tranh chấp; ⚠ WON trễ 24h |

Badge trạng thái chính theo token design-system: `Nháp` (draft), `Chờ duyệt` (chờ gate/gán), `Đã duyệt` (Go/handed), `Bị từ chối` (No-Go/rejected), `SLA vỡ` (breach). Cấm tự chế tint ngoài 10 token.

### 1.4. Quick filters + ánh xạ stage

**Quick filter chips (mặc định):** `Của tôi` · `Nhóm tôi` (L3+) · `Chờ gate` · `SLA vỡ` · `Không owner` · `Đang tranh chấp trùng` · `Tier D–E`. Chip theo phạm vi dữ liệu được phép — L1 chỉ thấy "Của tôi".

**Bộ lọc đầy đủ** (khớp API-ERP-003): `status` (stage), `tier` (A–E), `owner_id`, `channel`, `search` (tên khách/người liên hệ). Sort: `createdAt` / `score`.

**Ánh xạ stage hiển thị ↔ machine-state API** (10 stage PMS V6.0 gộp theo cụm xử lý):

| Cụm stage trên UI | Stage PMS V6.0 | `status` API | Điều kiện chuyển tiếp (chú giải board) |
|---|---|---|---|
| Tiếp nhận | Raw Data → Initial Brief | `new` → `dedup_check` → `assigned` | SLA 24h tạo project; brief 3 trường trong 2h; chưa qua dedup không vào board chính thức |
| Scoring | AUTO SCORING (bước hệ thống) | `scored` | Máy chấm K1–K12; knock-out → AUTO LOST; thiếu ≥2/5 CQ → Thiếu dữ liệu |
| First Meeting | First Meeting → Brief Received | (transition trong `scored`) | 3 ngày làm việc (+2 có lý do ghi PMS); notes bắt buộc trước QUALIFIED |
| Qualify | LEAD → QUALIFIED | `gate1` (mở khi đủ entry) | Full Brief 8 mục 1 ngày; tier hợp lệ |
| Gate & ký | Gate 1 → Gate 2 | `gate1_go/no_go` → `qualified` → `gate2_signed_handoff` | SM ký Gate 1 SLA 1 ngày; Handoff 5 nhóm 100% + AM xác nhận 4h |
| Bàn giao | EVALUATION → PROPOSAL → WON → DEPLOY | `handed_to_cs` | WON cập nhật 24h; chưa nạp 100% NSQC → "chờ kích hoạt" |

> `[NEEDS_REVIEW]` Từ vựng 10 stage PMS V6.0 (FEAT-ERP-CRM-002 §6) và enum `status` của API-ERP-006 chưa 1-1 (AUTO SCORING là bước hệ thống, không phải stage) — bảng ánh xạ trên do UX đề xuất, cần CORE chốt enum cuối khi implement.

### 1.5. View options & states

- **Nhóm theo stage** (mặc định: tắt) — gộp header theo cụm stage kèm count + conversion rate từng stage (L4/L5); chọn "Danh sách phẳng" để sort thuần.
- **Scope switch** `Của tôi / Nhóm tôi / Tất cả (phạm vi)` — hiển thị theo data-scope RBAC: L3 thấy nhóm, L4 phòng, L5 toàn Sales.
- **Loading:** skeleton 10 hàng bảng + skeleton pane phải; **Empty:** EmptyState "Không có lead nào khớp bộ lọc" + CTA "Ghi nhận lead" (nếu có quyền) / "Xóa bộ lọc"; **Error:** hàng lỗi + retry, pane phải giữ nội dung cũ kèm banner lỗi.

### 1.6. Phân quyền (trên surface này)

| Thành phần | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4 (SM) | SALES_L5 (GDKD) |
|---|---|---|---|---|---|
| Xem pipeline | mine | mine | mine + nhóm | phòng | toàn Sales |
| Nút "Ghi nhận lead" / "Nhập file" | ✅ | ✅ | ✅ | ✅ | ✅ |
| Chọn hàng + bulk reassign | ❌ (ẩn) | ✅ (lead scope mình) | ✅ (nhóm) | ✅ | ✅ |
| Gán owner lead tự do (hàng đợi SLA 4h) | ❌ | ❌ | ❌ | ✅ | ✅ |
| Advance stage / Gate action | trong pane S2 — Gate 1: L2; Gate 2: L3 (ẩn với L1) | | | | |
| SYS_ADMIN | ❌ không thấy workspace Sales (đúng ma trận FEAT-ERP-CRM-002) |

> `[NEEDS_REVIEW]` Phân quyền gán owner lệch nguồn: API-ERP-007 khai `SALES_L2+`, ma trận FEAT-ERP-CRM-002/001 §4 chỉ L4/L5 được gán/đổi owner; Navigation quy "reassign: L2+". Thiết kế theo mức Navigation (reassign trong scope = L2+; gán lead tự do = SM/GDKD) — chốt lại với P3 khi triển khai. Tương tự gate: API-ERP-008 + Navigation quy Gate 1 = SALES_L2, Gate 2 = SALES_L3, trong khi FEAT-ERP-CRM-004 §4 giao SM (L4) ký cả 2 gate.

---

## 2. TABS

N/A — S1 là worklist đơn bề mặt: phân nhóm thông tin xử lý bằng quick filter chips + view option "Nhóm theo stage"; mọi chi tiết lead nằm trong pane Lead 360 (S2) bên phải. Tabs sẽ trùng lặp cơ chế filter và làm mất ngữ cảnh split view.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Ghi nhận lead | `UI-WEB-LEAD-001-D1` | Form | Nút "+ Ghi nhận lead" |
| 2 | Gán lại chủ sở hữu (đơn + bulk) | `UI-WEB-LEAD-001-D2` | Form + Confirm | Bulk bar / row action "Reassign" |
| 3 | Hủy deal trước Gate 1 | `UI-WEB-LEAD-001-D3` | Confirm + lý do | Row action "Lưu hồ sơ hủy" (deal trước Gate 1) |

### 3.1. Dialog "Ghi nhận lead" (`-D1`)

- **Fields:** Nguồn (`channel`: referral/web/fb/tiktok/event — select), Tên công ty*, Người liên hệ*, Email/SĐT (chọn một, bắt buộc), Ghi chú nguồn. Nút tạo vô hiệu khi thiếu trường bắt buộc (khớp API-ERP-001).
- **Kết quả:** 201 → toast "Đã tạo lead, đang so khớp trùng" + lead xuất hiện ở đầu danh sách stage Raw Data. Trùng → 409 `LEAD_DUPLICATE`: dialog chuyển sang khối cảnh báo "Trùng chắc chắn/tiềm năng với [lead cũ]" + link người ghi trước; lead mới ở trạng thái khóa chuyển stage đến khi phân xử (chi tiết tại S2 sheet so sánh).
- **"Nhập file"** mở variant import (API-ERP-002): từng dòng chạy anti-duplicate, dòng hợp lệ vẫn nhận, báo lỗi theo dòng.

### 3.2. Dialog "Gán lại chủ sở hữu" (`-D2`)

- AssigneePicker lọc theo dept/role trong data-scope người gán; hiển thị quy tắc gán (auto theo kênh chủ quản / manual); bulk = 1 confirm cho N lead, từng lead ghi `assignment_history` riêng (API-ERP-007 gọi theo từng id, hàng lỗi hiển thị riêng, không chặn hàng còn lại).
- Nhân viên nghỉ việc: filter "chuyển quản từ…" — chuyển toàn bộ lead/deal có audit log, không xóa (A6 sales.md).

### 3.3. Dialog "Hủy deal trước Gate 1" (`-D3`)

- Xác nhận + lý do bắt buộc (≥10 ký tự) → `recycled`/lưu hồ sơ, không xóa; không tính vào conversion rate stage kế tiếp nhưng vẫn nằm trong lịch sử nhân viên. Nút nằm trong "⋯" của row, chỉ hiện cho deal trước Gate 1.

---

## 4. SHEETS

N/A — contextual info của lead đã có chỗ đứng đúng: pane Lead 360 (60% phải) là bề mặt chi tiết mặc định theo pattern W2; mở thêm sheet/drawer sẽ che mất danh sách mà không thêm ngữ cảnh. Riêng bằng chứng anti-duplicate (so sánh 2 lead trùng) là sheet của S2 (`UI-WEB-LEAD-002-S1`), mở từ pane khi chọn hàng có cảnh báo trùng.

---

## 5. VIEW MODES

| Mode | UI-ID | Nội dung | Ai thấy |
|---|---|---|---|
| Xem — Của tôi (mặc định) | `UI-WEB-LEAD-001-M1` | Worklist lead/deal mình sở hữu, mọi stage | L1–L5 |
| Xem — Nhóm/Phòng/Toàn Sales | `UI-WEB-LEAD-001-M2` | Cùng surface, mở rộng data-scope + thêm conversion rate từng stage khi "Nhóm theo stage" | L3 (nhóm) · L4 (phòng) · L5 (toàn Sales) |
| Xem — Hàng đợi chờ gán | `UI-WEB-LEAD-001-M3` | Filterpreserved "Không owner" + SLA gán 4h đếm ngược; hành động gán owner | SM (L4) / GDKD (L5) |

Create = Dialog `-D1` (không trang riêng); Edit brief/notes/advance = mode của pane S2. Không có mode Approve riêng — quyết định gate thực hiện tại pane S2 với đúng vai.

---

## 6. API ENDPOINTS

| # | Endpoint | Phương thức | Gắn với | Tham số chính |
|---|----------|------------|---------|---------------|
| 1 | `/api/v1/erp/leads` | GET (API-ERP-003) | DataTable chính (server-side) | filter `status, tier, owner_id, channel, search`; sort `createdAt/score`; `page, page_size` 20/50/100 |
| 2 | `/api/v1/erp/leads` | POST (API-ERP-001) | Dialog `-D1` Ghi nhận lead | body `channel, company_name, contact_name, phone, email, source_note?`; 201 trả `status=dedup_check`, `duplicate_of?`; 409 `LEAD_DUPLICATE` |
| 3 | `/api/v1/erp/leads/bulk-import` | POST (API-ERP-002) | Dialog "Nhập file" | per-row anti-duplicate; lỗi theo dòng |
| 4 | `/api/v1/erp/leads/{id}` | GET (API-ERP-004) | Pane S2 lazy-load khi chọn hàng | — (score K1–K12, tier, gate history, owner) |
| 5 | `/api/v1/erp/leads/{id}/assign` | POST (API-ERP-007) | Dialog `-D2` (gọi per-lead cho bulk) | body assignee + rule; ghi `assignment_history` |
| 6 | `/api/v1/erp/leads/{id}/transitions` | POST (API-ERP-006) | Row/pane action advance + `-D3` | state machine new→…→handed_to_cs; rejected; recycled; thiếu điều kiện → 4xx liệt kê mục thiếu |
| 7 | `/api/v1/erp/leads/{id}/gate-decision` | POST (API-ERP-008) | Nút Gate trong pane S2 | `{ "gate": 1\|2, "decision": "go\|no_go", "note" }` — Gate 1: SALES_L2; Gate 2: SALES_L3 |

Không có endpoint riêng cho "conversion rate từng stage" và "đếm quick chips" — tính từ kết quả GET list (aggregations client-side trên trang hiện tại, không gợi ý là số toàn cục) `[NEEDS_REVIEW: thiếu endpoint thống kê funnel/đếm theo filter nếu cần số chính xác toàn phạm vi]`.

---

## 7. UI-ID Registry

| UI-ID | Loại | Tên | Ghi chú |
|-------|------|-----|---------|
| `UI-WEB-LEAD-001` | list (worklist + split view) | My Pipeline — trang chính | Route `/sales/pipeline`; pattern W2 40/60 |
| `UI-WEB-LEAD-001-D1` | dialog | Ghi nhận lead (tạo + dedup) | API-ERP-001/002 |
| `UI-WEB-LEAD-001-D2` | dialog | Gán lại chủ sở hữu (đơn + bulk) | API-ERP-007 |
| `UI-WEB-LEAD-001-D3` | dialog | Hủy deal trước Gate 1 (lưu hồ sơ + lý do) | API-ERP-006 (recycled) |
| `UI-WEB-LEAD-001-M1` | mode | Xem "Của tôi" | mặc định |
| `UI-WEB-LEAD-001-M2` | mode | Xem Nhóm/Phòng/Toàn Sales | theo data-scope |
| `UI-WEB-LEAD-001-M3` | mode | Hàng đợi chờ gán owner | SM/GDKD |
| (ref) `UI-WEB-LEAD-002` | reference | Lead 360 — pane phải của S1, KHÔNG đăng ký lại tại đây | Chủ sở hữu ID: `screens-lead-360.md` |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features` | Upstream |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |
