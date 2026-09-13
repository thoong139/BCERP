# Screen Group: Ticket Queue + Ticket 360

Implements: FEAT-ERP-CSKH-001

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `cskh`
> **Tính năng:** FEAT-ERP-CSKH-001
> **Route:** `/ops/tickets`
> **Main UI-ID:** `UI-WEB-TICK-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| Workspace | Ops Workspace (`/ops/tickets`) — S16 trong screen inventory, worklist chính của OPS_CONT |
| Đối tượng nghiệp vụ | Ticket CSKH (queue hợp nhất đa kênh portal/email/Zalo) + SLA timer theo tier khách × priority + timeline escalation |
| Vai trò chính | OPS_CONT/OPS_DES/OPS_EDIT/OPS_ADS (assignee — nhận việc, phản hồi, resolve); OPS_AM (portfolio khách mình — gán việc, đề xuất cờ, detractor); OPS_PLAN (toàn bộ — điều phối, chốt cờ khiếu nại) |
| Workflow stage | open → assigned → in_progress → resolved → closed (API-ERP-060); UI render machine-state nguyên văn core trả về (`NEW/OPEN/PENDING/RESOLVED/CLOSED/REOPENED` — BR-001); escalation là lớp song song, KHÔNG đổi state ticket |
| A. Object đang xử lý | 1 ticket đang chờ hành động: SLA còn bao lâu, đang chờ ai (khách / platform / bậc escalation kế), bước tiếp theo hợp lệ theo machine-state |
| B. Primary actors | Assignee xử lý + phản hồi; OPS_AM gán việc và can thiệp trước breach; OPS_PLAN điều phối + đẩy khiếu nại BOD |
| C. Related actors | Khách (tạo/reopen/CSAT qua portal P4 — chỉ đọc kết quả tại đây); SLANOT (pre-alert 80% / breach / pause tự động); Alert Center S24 (breach đỏ ≤5 phút); FIN (đối soát REQ-FIN-004 khi khiếu nại phản đối số liệu); BOD_CEO (nhận hồ sơ khiếu nại 24h) |
| D. Lifecycle | SLA timer theo tier E (nhanh nhất) → A (chậm nhất) × priority — Critical 24/7; PENDING pause đồng hồ; auto-Closed "khách không phản hồi" sau 2 nhắc + 24h; reopen ≤7 ngày kể từ Closed |
| E. Cross-module | Khách → Client 360 (S28); campaign liên quan → S14; tier nguồn profile CRM; breach → Alert Center (S24) + KPI nhân sự (REQ-HR-007, chỉ liên kết); policy SLA cấu hình tại S18 |
| F. Information needs | Thread đa kênh + nhãn nguồn, SLA còn lại + pause history, chặng escalation hiện tại + timestamp từng chặng, CSAT + câu mở của khách, lý do Pending + case ID platform |
| G. Decisions | Nhận việc / gán cho ai; trả lời hay chuyển Pending (chờ ai); resolve với giải pháp gì; đẩy chặng escalation; gắn cờ khiếu nại + đẩy BOD |
| H. Actions được phép | Nhận việc, phản hồi + file, Pending (lý do + case ID), Resolve (mô tả giải pháp), Đóng, Reopen ≤7 ngày, Gán/chuyển assignee (OPS_AM/OPS_PLAN), Đẩy chặng (OPS_AM/OPS_PLAN), Cờ khiếu nại (đề xuất/chốt) |
| I. Exceptions | Pre-alert 80% vàng / breach 100% đỏ; thiếu dữ liệu SLA → "không xác định" + retry, KHÔNG ẩn ticket (BR-002); xung đột phiên `STATE_KHONG_CON_HOP_LE`; kênh degraded nhãn `manual`; detractor chặn đóng thiếu hành động khắc phục; khiếu nại trùng đối soát FIN |
| J. Cần chuyển màn hình? | Không — toàn bộ xử lý hằng ngày tại split view; chỉ jump-out sang Client 360 (S28), Campaign (S14), Alert Center (S24) |

---

## 1. TRANG CHÍNH

### 1.1. Layout — Pattern W2, split view 40/60 (chọn hàng không rời trang)

```
┌──────────────────────────────┬────────────────────────────────────────────────────────────┐
│ QUEUE — 40%                  │ TICKET 360 — 60%                                           │
│ Tìm nhanh [TK-24█___] [Bộ lọc▾]│ TK-2451 · Lỗi đo lường campaign Q3      [Client 360 →]    │
│ (Sắp vỡ·3×)(Đã vỡ·2×)(Của tôi·7×)│ Khách: Công ty ABC TNHH · Tier E (CRM) · Priority: High │
│ (Tier E×)(PENDING×)          │ Badge: IN_PROGRESS · Kênh: [PORTAL] · [→ CAMP-077 · S14]   │
│ ┌──────────────────────────┐ │ SLA: ⏱ còn 0h42m (vàng ≥80%) · Escalation: bậc 1 — AM     │
│ │TK-2451 ABC·E·High        │ │ Assignee: Lê Văn C (OPS_CONT) · [Gán lại]                  │
│ │ IN_PROGRESS ⚠80% · bậc AM│ ├────────────────────────────────────────────────────────────┤
│ │TK-2448 XYZ·E·Crit        │ │ Tabs: [Thread & phản hồi] [SLA & Escalation]               │
│ │ OPEN 🔴 ĐÃ VỠ [manual]   │ │       [CSAT & Khiếu nại] [Timeline]                        │
│ │TK-2430 LMN·D·Med         │ │  (nội dung tab — xem §2)                                   │
│ │ PENDING ⏸ chờ khách 3h   │ ├────────────────────────────────────────────────────────────┤
│ │ …                        │ │ ⚠ SLA đã vỡ 12 phút — SLANOT đã escalate AM; nếu 30 phút   │
│ │ 20/trang ▾  ‹ 1 2 … ›    │ │   nữa → CS TL. [Mở Alert Center]                           │
│ └──────────────────────────┘ │ Footer: [Nhận việc] [Trả lời] [Chuyển trạng thái ▾]        │
└──────────────────────────────┴────────────────────────────────────────────────────────────┘
```

- Breadcrumb: `Ops > Ticket Queue > [TK-2451]`. Deep-link `/ops/tickets?ticket=TK-2451` mở queue với pane đã chọn. Tablet ≤1279px: pane mở dạng overlay, Esc đóng, focus trả về hàng vừa mở.

### 1.2. Queue (40% trái — DataTable compact, row 32px)

- **R6:** Tìm nhanh (mã ticket / khách / chủ đề) + quick filter chips tháo được từng chip (Sắp vỡ · Đã vỡ · Của tôi · Tier E…A · Priority · PENDING) + Bộ lọc đầy đủ `status, tier, priority, assignee_id, sla_state` (đúng tham số API-ERP-058) + sort mặc định theo SLA còn lại tăng dần — breach tự nổi đầu queue (BR-002) + phân trang server-side 20/50/100 + bulk action: **Gán hàng loạt** (chỉ OPS_AM/OPS_PLAN).
- **Cột:** mã + chủ đề · khách + tier chip (tooltip "tier từ profile CRM — quyết định SLA") · priority · **SLA timer** (icon `clock-sla` + thời gian còn lại: vàng `--state-sla-warning` khi cờ `pre_alert_80`, đỏ `--state-sla-breach` khi `breach_flag` kèm icon chuông — tín hiệu do SLA engine trả về, WEB không tự tính %) · StatusBadge machine-state nguyên văn · assignee · chặng escalation hiện tại (chip AM/CS TL/OPS_PLAN/BOD) · nguồn kênh (chip PORTAL/EMAIL/ZALO; nhãn `manual` `--state-manual` cho kênh degraded kèm timestamp — vẫn tính SLA bình thường theo DI-007) · exception (WarningIndicator inline).
- **States:** loading = skeleton 10 hàng; empty = EmptyState "Không có ticket trong phạm vi của bạn" (ghi rõ phạm vi: portfolio / toàn bộ / ticket được gán); error = banner lỗi + retry — tuyệt đối không ẩn hàng; thiếu dữ liệu SLA → ô "không xác định" + nút retry (BR-002).
- **Keyboard:** ↑↓ di chuyển, Space chọn, Enter mở detail. Queue quá lớn (2.600+ TKQC): bộ lọc + phân trang bắt buộc, nhóm sắp vỡ/đã vỡ luôn nổi trên cùng.

### 1.3. Ticket 360 (60% phải)

| Khối | Nội dung |
|---|---|
| Trạng thái + progress | StatusBadge machine-state nguyên văn (`NEW/OPEN/PENDING/RESOLVED/CLOSED/REOPENED`) + priority + SLA timer lớn (còn lại / đã vỡ bao lâu) + bước escalation hiện tại; đang chờ ai qua WaitingOnIndicator khi PENDING ("chờ khách 3h" / "chờ platform — case PP-889, 5h", đồng hồ pause) |
| Ownership | Assignee avatar + tên + nút [Gán lại] chỉ khi có quyền (ẩn theo PEP, không disabled); assignment history xem tại T4 |
| Cross-module (summary/panel) | Khách → link Client 360 (S28); context campaign liên quan từ API-ERP-061 → link S14; liên kết đối soát "Đang đối soát" (REQ-FIN-004) khi có |
| Exceptions | WarningIndicator banner (chuyện gì — ai làm gì — hạn còn lại): sắp vỡ/breach + bậc đã escalate, countdown 24h khiếu nại BOD, detractor due 48h LV, xung đột phiên |

- **Footer sticky** — chỉ mở action hợp lệ theo machine-state (BR-003): `NEW` → chỉ [Nhận việc]; `OPEN` → [Chuyển Pending] / [Resolve]; `PENDING` → [Trả lại xử lý]; `RESOLVED` → [Đóng]; `CLOSED` ≤7 ngày → [Reopen], >7 ngày → [Tạo ticket mới tham chiếu] (D4, ticket gốc chỉ đọc vĩnh viễn). Menu hiển thị cả điều kiện không đạt kèm lý do để assignee biết phải làm gì trước.
- **States pane:** loading = skeleton khi đổi hàng; empty khi chưa chọn hàng ("Chọn 1 ticket để xem chi tiết"); error = giữ nội dung cũ + retry; xung đột phiên → toast "trạng thái đã đổi", tự re-fetch machine-state, giữ nguyên draft đang soạn (§ Trường hợp đặc biệt SC-009).

---

## 2. TABS (panel tabs trong Ticket 360 — header context giữ nguyên khi chuyển tab)

| Tab | UI-ID | Mục tiêu | Lazy-load |
|---|---|---|---|
| Thread & phản hồi | `UI-WEB-TICK-001-T1` | Toàn bộ hội thoại đa kênh + soạn phản hồi + ghi chú nội bộ | Không (mặc định) |
| SLA & Escalation | `UI-WEB-TICK-001-T2` | Đồng hồ SLA + chuỗi escalation có timestamp | Có |
| CSAT & Khiếu nại | `UI-WEB-TICK-001-T3` | Điểm CSAT khách + detractor task + luồng khiếu nại BOD | Có |
| Timeline hoạt động | `UI-WEB-TICK-001-T4` | Activity + audit trail bất biến | Có |

**Tab 1 — Thread & phản hồi (`-T1`):** feed hội thoại theo thời gian; mỗi entry: author (khách/BC/hệ thống) + nhãn kênh nguồn (portal/email/Zalo) + attachment + cờ `is_first_response` (timestamp First Response do API ghi chuẩn). Ticket dedupe từ nhiều kênh hiển thị danh sách nguồn trên ticket gốc; phản hồi BC được core đồng bộ mọi kênh tham chiếu. Kênh degraded gắn nhãn `manual` + timestamp. `internal_notes` chỉ hiển thị nhân sự nội bộ, không đồng bộ portal (BR-009). **Composer:** rich text + đính kèm file; draft lưu cục bộ trình duyệt, submit kèm `Idempotency-Key` — mất mạng không sinh trùng, không sai timestamp First Response. Hành động "Chuyển Pending — chờ khách" lấy ngữ cảnh từ tab này. Permissions: phản hồi theo Phân Quyền feature (assignee/OPS_AM/OPS_PLAN); customer KHÔNG có ở web nội bộ.

**Tab 2 — SLA & Escalation (`-T2`):** FR timer + Res timer theo tier×priority (chính sách gốc tại S18 `/ops/sla-policies` — link out); pause history (khoảng PENDING, lý do, case ID platform — chi tiết tại sheet `-S1`); timeline escalation 5 bậc assignee → AM → CS TL → OPS_PLAN → BOD, mỗi chặng SLA 30 phút trong giờ trực, timestamp bắt buộc; chặng thiếu timestamp → nhãn bất thường + cảnh báo OPS_PLAN (BR-005); spine cam kết tối thiểu AM → AD → BOD (AD/CS TL là chức danh thuộc vai OPS_AM — hiển thị chức danh, không tạo vai mới). 5 trigger tự động do core/SLANOT kích hoạt — WEB chỉ hiển thị; OPS_AM/OPS_PLAN thấy nút [Đẩy chặng]/[Nhắc chặng] theo quyền. Breach đã vào Alert Center → link "Mở tại Alert Center" (S24).

**Tab 3 — CSAT & Khiếu nại (`-T3`):** CsatResultView — điểm 1–5 + câu mở khách trả trên portal, WEB chỉ hiển thị (BR-007); không có phản hồi → hiển thị "không phản hồi" kèm tỷ lệ phản hồi của tier (tránh đọc sai điểm trung bình); CSAT chấm sau Closed không mở lại state — vòng khắc phục chạy trên task. DetractorTaskView (CSAT ≤2): task due 48h LV gắn ticket gốc — OPS_AM ghi `contact_note` + `remediation_action`, thiếu một trong hai core từ chối đóng `THIEU_HANH_DONG_KHAC_PHUC`. Khiếu nại (ComplaintDossierView): form `-D3` chỉ mở khi chọn ≥1/4 tiêu chí (khách Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên); hồ sơ = thread + timeline + evidence; hiển thị countdown 24h + trạng thái "đã đến BOD" + coordinator OPS_PLAN; khi trùng phản đối số liệu → hiển thị đồng thời liên kết "Đang đối soát" (REQ-FIN-004), AM không tự chốt số trước khi FIN đối trừ.

**Tab 4 — Timeline hoạt động (`-T4`):** ActivityFeed full từ API-ERP-061: tạo/transition/assign/escalation/CSAT — avatar actor + hành động + thời gian tuyệt đối dd/MM HH:mm; event hệ thống (SLANOT trigger, auto-Closed "khách không phản hồi", dedupe kênh) icon riêng; filter theo loại (khách/BC/hệ thống/escalation). Toàn bộ thao tác core ghi append-only + hash-chain (BR-010) — không tồn tại UI xóa/sửa log cho mọi vai.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Mở khi nào |
|---|--------|-------|-----------|
| 1 | Gán/chuyển assignee (đơn + bulk) | `UI-WEB-TICK-001-D1` | Header [Gán lại] / bulk bar queue |
| 2 | Chuyển trạng thái (Pending/Resolve/Đóng/Reopen) | `UI-WEB-TICK-001-D2` | Footer [Chuyển trạng thái ▾] |
| 3 | Gắn cờ khiếu nại nghiêm trọng + đẩy BOD | `UI-WEB-TICK-001-D3` | Tab T3 |
| 4 | Tạo ticket mới tham chiếu | `UI-WEB-TICK-001-D4` | Footer khi `CLOSED` quá 7 ngày |

- **`-D1`:** AssigneePicker lọc theo portfolio/scope của người gán (RBAC — OPS_AM trong portfolio mình, OPS_PLAN toàn bộ); ghi `assignment_history` qua API-ERP-059; gán ngoài portfolio → core từ chối `NGOAI_PORTFOLIO` (hiển thị nguyên văn). Bulk = 1 confirm cho N ticket, hàng lỗi báo riêng không chặn phần còn lại.
- **`-D2`:** field động theo trạng thái đích — Pending: lý do bắt buộc (chờ khách / chờ platform + case ID bắt buộc); Resolve: mô tả giải pháp bắt buộc. Thiếu → chặn submit `THIEU_MO_TA_GIAI_PHAP` / `THIEU_LY_DO` / `THIEU_CASE_ID`; sai transition → `INVALID_TRANSITION` + re-fetch. Gửi kèm phiên trạng thái (optimistic locking). Chuyển trạng thái qua API-ERP-060, đồng hồ SLA reset/adjust do core quyết.
- **`-D3`:** bước 1 chọn tiêu chí (≥1/4 mới mở bước 2); bước 2 upload hồ sơ bắt buộc trước khi [Đẩy BOD] — thiếu → `THIEU_HO_SO_KHIEU_NAI`; bước 3 confirm hiển thị countdown 24h. OPS_AM = đề xuất cờ; OPS_PLAN = chốt cờ + điều phối. `[NEEDS_REVIEW: thiếu endpoint complaint/escalation-push — xem §6]`.
- **`-D4`:** form nội bộ (khách, chủ đề, mô tả, kênh, priority) + tham chiếu ticket gốc bắt buộc; tạo qua API-ERP-057 (start SLA timer); ticket gốc chuyển chỉ đọc vĩnh viễn.

## 4. SHEETS

| # | Sheet | UI-ID | Nội dung | Mở khi nào |
|---|-------|-------|----------|-----------|
| 1 | Chi tiết đồng hồ SLA & pause | `UI-WEB-TICK-001-S1` | Target FR/Res theo tier×priority, thời điểm start/pause/resume từng khoảng, lý do pause + case ID, tổng thời gian không tính breach | Tab T2 — click vào timer |

Ưu tiên dạng sheet vì bằng chứng pause cần nằm cạnh quyết định Pending/Resolve ngay trong pane; footer sheet có link mở policy gốc tại S18.

## 5. VIEW MODES

| Mode | UI-ID | Nội dung | Ai thấy |
|---|---|---|---|
| View (mặc định) | `UI-WEB-TICK-001-M1` | Đọc queue + ticket theo scope; action theo vai | OPS_AM (portfolio), OPS_PLAN (toàn bộ), assignee (ticket được gán); BOD/SYS_ADMIN không có surface này |
| Soạn phản hồi | `UI-WEB-TICK-001-M2` | Composer inline trong T1 (rich text + file + internal note) | Assignee được gán, OPS_AM, OPS_PLAN |

Create ticket = dialog `-D4` (nội bộ, có tham chiếu); "đẩy chặng escalation" là action tại T2, không phải mode.

## 6. API ENDPOINTS

| # | Endpoint | Phương thức | Gắn với | Ghi chú |
|---|----------|------------|---------|---------|
| 1 | `/api/v1/erp/tickets` | GET (API-ERP-058) | Queue 40% | Filter `status,tier,priority,assignee_id,sla_state`; sort SLA còn lại; phân trang server-side 20/50/100; scope theo portfolio/permission |
| 2 | `/api/v1/erp/tickets/{id}/activity` | GET (API-ERP-061) | Tabs T1 (thread nguồn), T2 (escalation), T4 (timeline), context campaign/TKQC | Chuỗi escalation AM→AD→BOD kèm timestamp |
| 3 | `/api/v1/erp/tickets/{id}/assign` | POST (API-ERP-059) | Dialog `-D1`, bulk bar | Ghi `assignment_history`; từ chối `NGOAI_PORTFOLIO` |
| 4 | `/api/v1/erp/tickets/{id}/transitions` | POST (API-ERP-060) | Dialog `-D2`, footer [Nhận việc] | open→assigned→in_progress→resolved→closed; reset/adjust SLA timer do core; `Idempotency-Key` cho submit |
| 5 | `/api/v1/erp/tickets` | POST (API-ERP-057) | Dialog `-D4` | Tạo ticket mới tham chiếu; gắn tier khách + priority; start SLA timer |
| 6 | `/api/v1/erp/sla-timers` | GET (API-ERP-073) | SLA timer trong queue + header + sheet `-S1` | `object_type,object_id,sla_state` — nguồn tín hiệu pre-alert/breach/pause |
| 7 | `/core/audit/objects/:objectId/timeline` | GET (API-CORE-030) | Tab T4 — audit trail read-only | Append-only; không UI ghi đè |

`[NEEDS_REVIEW]` — api-contract chưa có endpoint cho: (1) **POST phản hồi/internal note** vào thread phía ERP (chỉ có API-PORTAL-030 `/tickets/:id/comments` phía khách — cần POST tương ứng nội bộ, ví dụ `POST /api/v1/erp/tickets/{id}/comments`); (2) **complaint dossier + đẩy BOD** (ComplaintDossierView — cần POST/PATCH `…/complaint`); (3) **GET CSAT result + detractor task** (CsatResultView/DetractorTaskView — khách submit qua portal/mobile, web cần endpoint đọc kết quả); (4) **đẩy/nhắc chặng escalation** (BR-005 — hiện chỉ có GET activity). Không bịa endpoint — UI thiết kế theo view model feature spec, chờ bổ sung contract. Ngoài ra: tên state API-ERP-060 (`assigned/in_progress`) khác badge machine-state feature spec (`NEW/PENDING/REOPENED`) — UI render nguyên văn giá trị core trả về, cần thống nhất bộ tên khi triển khai.

Dashboard SLA compliance FR/Res theo tier×priority + CSAT theo tier KHÔNG nằm ở đây — tại S18 `/ops/sla-policies` (tab compliance read-only) và mart `cs_sla` (API-CORE-036) cho BOD; web không tự tổng hợp số (BR-008).

## 7. UI-ID Registry

| UI-ID | Loại | Tên | Ghi chú |
|-------|------|-----|---------|
| `UI-WEB-TICK-001` | list + detail (split view W2) | Ticket Queue (40%) + Ticket 360 (60%) | Route `/ops/tickets`; Navigation S16, badge menu `{sla_ve}` |
| `UI-WEB-TICK-001-T1` | tab | Thread & phản hồi (đa kênh, composer, internal notes) | mặc định |
| `UI-WEB-TICK-001-T2` | tab | SLA & Escalation (timer, pause, 5 bậc 30 phút/chặng) | lazy |
| `UI-WEB-TICK-001-T3` | tab | CSAT & Khiếu nại (detractor 48h LV, hồ sơ BOD 24h) | lazy |
| `UI-WEB-TICK-001-T4` | tab | Timeline hoạt động + audit bất biến | lazy |
| `UI-WEB-TICK-001-D1` | dialog | Gán/chuyển assignee (đơn + bulk, portfolio scope) | API-ERP-059 |
| `UI-WEB-TICK-001-D2` | dialog | Chuyển trạng thái theo machine-state (field bắt buộc động) | API-ERP-060 |
| `UI-WEB-TICK-001-D3` | dialog | Cờ khiếu nại + hồ sơ + đẩy BOD (countdown 24h) | `[NEEDS_REVIEW]` endpoint |
| `UI-WEB-TICK-001-D4` | dialog | Tạo ticket mới tham chiếu (quá 7 ngày) | API-ERP-057 |
| `UI-WEB-TICK-001-S1` | sheet | Chi tiết đồng hồ SLA & pause history | từ tab T2 |
| `UI-WEB-TICK-001-M1` | mode | View (read theo scope) | mặc định |
| `UI-WEB-TICK-001-M2` | mode | Soạn phản hồi (composer T1) | assignee/AM/PLAN |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features` | Upstream |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |
