# Screen Group: SLA Policy Rules

Implements: FEAT-ERP-SLANOT-001

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `slanot`
> **Tính năng:** FEAT-ERP-SLANOT-001
> **Route:** `/ops/sla-policies`
> **Main UI-ID:** `UI-WEB-SLA-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Workspace | Ops Workspace (`/ops/sla-policies`) — S18 trong screen inventory, **config surface thưa (ít đổi)** sau consolidation: chỉ policy rules; Notification center cá nhân là global drawer (đã DROP ở §2.0.5, không nằm ở đây) |
| Đối tượng nghiệp vụ | SLA Policy Config — instance ma trận tier × priority GMT+7 per loại object (ticket, handoff, deliverable, approval…), effective-dated; escalation chain (bậc, thời gian, người nhận); tier profile ghi đè theo HĐ; kênh thông báo đa kênh; compliance history (read-only) |
| Vai trò chính | OPS_PLAN (owner cấu hình — soạn ma trận, tier profile, escalation); OPS_AM (xem + theo dõi compliance portfolio mình); OPS_AD (view) |
| Workflow stage | Không chạy theo state của business object — chạy theo **vòng đời phiên policy**: draft → submitted → approved → activated → superseded (REQ-BOD-009; `POLICY_NOT_APPROVED` 409 nếu kích hoạt khi chưa duyệt). Hiệu lực theo effective_date |
| A. Object đang xử lý | Bản cấu hình SLA đang xem/soạn: giá trị FR/Res từng ô (tier × priority × object_type), phiên nào đang hiệu lực, phiên draft nào chờ BOD duyệt, ai soạn |
| B. Primary actors | OPS_PLAN soạn + đề xuất phiên; BOD phê duyệt phiên (REQ-BOD-009, step-up MFA `policy_approval`); OPS_AM tiêu thụ compliance history |
| C. Related actors | SLA engine SYS-CORE-BACKEND (thực thi clock/pause/escalation — WEB chỉ phản chiếu); SYS_ADMIN (kênh hệ thống — routing API-CORE-045); OPS_CONT (thụ hưởng target tại S16); Alert Center S24 (breach đỏ); Client 360 S28 (tier nguồn) |
| D. Lifecycle | Phiên policy effective-dated; chỉnh sửa KHÔNG đè bản đang chạy — tạo phiên draft mới, BOD duyệt mới kích hoạt; phiên cũ chuyển superseded giữ audit (BR-009 append-only) |
| E. Cross-module | S16 Ticket Queue (timer đang chạy theo policy — link ra); S24 Alert Center (breach + routing); S28 Client 360 (khách có tier profile ghi đè); S27 Tham số (hệ số DI-004, lịch lễ VN); KPI REQ-HR-007 (chỉ liên kết) |
| F. Information needs | Ma trận hiện hành per object_type; phiên + ngày hiệu lực + người soạn; diff old/new khi có draft; escalation chain + trigger; kênh đã cấu hình; compliance breach/MTTR/breach lặp; log dispatch đa kênh |
| G. Decisions | Sửa target ô nào; tạo phiên hiệu lực từ ngày nào; bật kênh nào cho từng mức cảnh báo; khách nào cần ghi đè theo HĐ; breach lặp có cần rà policy không |
| H. Actions được phép | Xem policy (OPS/FIN); PUT draft phiên + tier profile (chỉ OPS_PLAN — BOD duyệt sau); routing kênh hệ thống (SYS_ADMIN → BOD_CFO_CTO duyệt); compliance + log: chỉ đọc |
| I. Exceptions | Phiên chờ duyệt chưa hiệu lực; `POLICY_NOT_APPROVED`; xung đột giá trị áp dụng (ma trận vs HĐ vs lịch khách — hiển thị song song + nhãn nguồn, BR-002); kênh chưa cấu hình → fallback in-app + log (BR-007); cờ K6–K12 chưa chốt `[KXN-20]` — chỉ bật cờ đã xác nhận |
| J. Cần chuyển màn hình? | Không — toàn bộ cấu hình + đọc lịch sử tại 1 surface; chỉ link out: ô timer → S16, breach → S24, khách ghi đè → S28, routing kênh → cấu hình của SYS_ADMIN |

---

## 1. TRANG CHÍNH

### 1.1. Layout — config surface: header phiên + tabs, thân T1 = ma trận (density comfortable — màn hình cấu hình)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Breadcrumb: Ops > SLA Policy Rules    Phiên hiện hành: pv-2026-09.3          │
│ SLA Policy Rules        Hiệu lực 01/09/2026 – nay · soạn bởi Nguyễn T (PLAN) │
│ ⚠ Phiên pv-2026-09.4 (hiệu lực 01/10/2026) đang chờ BOD phê duyệt [Xem diff] │
│ ────────────────────────────────────────────────────────────────────────────│
│ Tabs: [Ma trận & chính sách] [Compliance history]      [Lịch sử phiên ▾]     │
│ Loại object: (Ticket CSKH •)(Handoff)(Deliverable)(Approval — lệnh chi)      │
│ ── MA TRẬN TIER × PRIORITY — giờ làm việc GMT+7 (riêng Critical 24/7) ──────│
│ │        │ Critical · 24/7 │ High         │ Medium         │ Low           ││
│ │ Tier E │ 15 phút / 4 h  │ 30 phút / 8 h │ 2 h / 1 ngày  │ 4 h / 2 ngày  ││
│ │ Tier D │ 30 phút / 6 h  │ 1 h / 12 h    │ 3 h / 1,5 ngày│ 8 h / 3 ngày  ││
│ │ Tier A │ 4 h / 1 ngày   │ 8 h / 2 ngày  │ 1 ngày / 4 ngày│ 2 ngày / 7ng ││
│ │  (ô: FR / Res — click mở SidePanel -S1; thay đổi so phiên gốc tô vàng)    ││
│ ── ESCALATION CHAIN (BR-008, mỗi chặng 30 phút trong giờ trực) ─────────────│
│ assignee →(30′)→ OPS_AM →(30′)→ CS TL* →(30′)→ OPS_PLAN →(30′)→ BOD         │
│ *thực thi bằng quyền OPS_PLAN (DI-006) · trigger engine: Critical quá FR ·  │
│  chạm 100% · reopen ≥2 · Pending quá 3 ngày LV                [Chi tiết -S1]│
│ ── TIER PROFILE GHI ĐÈ THEO HĐ (BR-002) — 3 khách         [Tìm khách…    ]  │
│ │ Khách            │ Tier │ Ghi đè FR/Res │ Nguồn              │ HĐ liên quan│
│ │ Công ty ABC TNHH │ E    │ 10 phút / 3 h │ theo HĐ HD-2026-114│ → S28       │
│ 20/trang ▾  ‹ 1 ›                                                            │
└──────────────────────────────────────────────────────────────────────────────┘
```

- **Header context giữ nguyên khi chuyển tab:** phiên hiện hành (mã + hiệu lực + người soạn) + banner phiên chờ duyệt. Deep-link `/ops/sla-policies?tab=compliance&object_type=ticket`.
- **Trạng thái trang:** loading = skeleton ma trận 5×4 + skeleton 5 dòng bảng ghi đè; empty (chưa có policy cho object_type — cấu hình mới) = EmptyState "Chưa có chính sách cho loại object này" + CTA [Đề xuất thay đổi] (chỉ hiện với OPS_PLAN); error = banner lỗi + retry, giữ phiên hiện hành đang render — không được hiện màn trống khiến người đọc tưởng chưa có policy.
- **Cross-module dạng link/panel:** khách ghi đè → Client 360 (S28); timer đang chạy → S16; breach → S24; routing kênh → cấu hình SYS_ADMIN (API-CORE-045). Không nhân bản dữ liệu.
- **Activity/timeline:** "Lịch sử phiên ▾" — danh sách phiên effective-dated (mã, hiệu lực từ–đến, người soạn, trạng thái draft/chờ duyệt/đang hiệu lực/superseded), click phiên → dialog so sánh `-D2`. Audit bất biến theo BR-009 — không có UI sửa/xóa.

### 1.2. Khối ma trận + bảng ghi đè (T1)

- **Ma trận 5×4** (tier A–E × priority Critical/High/Medium/Low), mỗi ô hiển thị `FR / Res` + badge `24/7` cho cột Critical (BR-003); ô có giá trị draft khác phiên đang chạy tô `--state-sla-warning` + tooltip "draft: 12 phút (hiện 15)". Click ô: OPS_PLAN → SidePanel `-S1` chế độ sửa; vai khác → `-S1` chế độ đọc.
- **Bảng tier profile ghi đè:** search theo tên khách + cột Khách · Tier · Ghi đè FR/Res · Nguồn (chip "theo HĐ" / "theo lịch khách" / "ma trận") · HĐ liên quan; sort theo tier/khách; phân trang server-side 20/50/100 (R6). Khách có lịch LV riêng → chip "lịch khách" — clock High/Medium/Low tính theo lịch đó (BR-002).

---

## 2. TABS

| Tab | UI-ID | Mục tiêu | Lazy-load | Quyền thấy |
|---|---|---|---|---|
| Ma trận & chính sách | `UI-WEB-SLA-001-T1` | Cấu hình target + escalation + kênh per object_type | Không (mặc định) | OPS (đọc) + FIN (đọc); sửa: OPS_PLAN |
| Compliance history | `UI-WEB-SLA-001-T2` | Đọc-only: timer thực tế, breach/MTTR/breach lặp, log dispatch | Có | OPS_AM/OPS_PLAN (đầy đủ); FIN (grid, scope); ẩn với OPS_CONT/DES/EDIT/ADS theo Phân Quyền feature |

**Tab 1 — Ma trận & chính sách (`-T1`):** mục tiêu = chỉnh policy an toàn mà không phá phiên đang chạy. Thông tin: ma trận theo object_type đang chọn, escalation chain + trigger bắt buộc (engine-enforced — chỉ xem, không đổi trigger), bảng ghi đè theo HĐ. Components: matrix grid (comfortable), chips object_type, bảng ghi đè, command bar [+ Đề xuất thay đổi] (chỉ OPS_PLAN — ẩn theo PEP, không disabled), [Lịch sử phiên ▾]. Actions: click ô/chain/row → SidePanel `-S1`; [Đề xuất thay đổi] → dialog `-D1`. States: đã nêu §1.1. Permissions: PUT qua luồng phê duyệt tham số REQ-BOD-009 — OPS_PLAN chỉ soạn draft, không tự kích hoạt; nút "Kích hoạt" KHÔNG tồn tại trên WEB cho OPS_PLAN. Quan hệ tab khác: số breach lặp trên T2 là căn cứ đề xuất sửa policy tại T1.

**Tab 2 — Compliance history (`-T2`, read-only):** mục tiêu = OPS_AM/OPS_PLAN bảo vệ SLA bằng dữ liệu thực tế (user story 1 — dashboard compliance FR/Res theo tier × priority, lọc khách/nhóm/thời gian). Thông tin: (a) hàng KPI 4 ô — breach 30 ngày · MTTR · đang PRE_ALERT · đang BREACHED (nguồn mart `cs_sla` — API-CORE-036, OPS theo scope); (b) grid timer per object từ API-ERP-073: search object_id + quick filter chips tháo được (PRE_ALERT · BREACHED · PAUSED · Tier E · theo khách) + filter `object_type, sla_state` + sort mặc định SLA còn lại tăng dần (breach nổi đầu) + phân trang server-side 20/50/100; cột: object · khách + tier · priority · sla_state (StatusBadge nguyên văn machine-state: RUNNING/PRE_ALERT/BREACHED/PAUSED/EXTENDED/MET/BREACHED_RESOLVED/AUTO_CLOSED/WAIVED) · đã trôi/target (tabular-nums) · nguồn target áp dụng (ma trận/theo HĐ/theo lịch khách — nhãn bắt buộc BR-002) · cờ breach lặp (≥3 breach/khách/30 ngày — ngưỡng post-mortem BR-010) · row action [Mở ticket → S16]; (c) grid log dispatch từ API-ERP-074: thời điểm · object · mức (pre-alert/breach) · kênh (in-app/email/Zalo/Telegram/push) · trạng thái (delivered/retry/fallback in-app) · ack_by — kênh chưa cấu hình hiển thị "fallback in-app" (BR-007). Components: KPI row, 2 DataTable compact, WarningIndicator khi có khách chạm ngưỡng post-mortem. Actions: chỉ đọc + link out; không có ghi. States: loading skeleton; empty "Không có đồng hồ nào trong phạm vi" (ghi rõ scope); error retry — không ẩn hàng. Permissions: đúng bảng Phân Quyền feature — OPS_CONT/DES/EDIT/ADS không thấy tab; SYS_ADMIN không thấy (chỉ alert kỹ thuật); BOD xem tổng quan ở S23 Executive BI (link, không nhân bản). Quan hệ tab khác: dòng breach lặp → gợi ý [Đề xuất sửa policy] mở `-D1` tại T1 (chỉ OPS_PLAN thấy nút).

---

## 3. DIALOGS

| # | Dialog | UI-ID | Mở khi nào |
|---|--------|-------|-----------|
| 1 | Đề xuất phiên cấu hình mới (effective-dated) | `UI-WEB-SLA-001-D1` | CommandBar [+ Đề xuất thay đổi] / gợi ý từ breach lặp (T2) |
| 2 | So sánh phiên (diff) | `UI-WEB-SLA-001-D2` | Banner phiên chờ duyệt [Xem diff] / Lịch sử phiên ▾ |

- **`-D1`:** chọn ngày hiệu lực (mặc định đầu tháng kế) + **lý do bắt buộc** (thiếu → khóa submit, parity BR-009) + tóm tắt số ô sẽ đổi so phiên hiện hành; submit = PUT draft qua API-ERP-072 → vào luồng phê duyệt tham số REQ-BOD-009 (BOD duyệt, step-up MFA `policy_approval`). Toast thành công nêu rõ "đã gửi phê duyệt — chưa hiệu lực"; lỗi 409 `POLICY_NOT_APPROVED` hiển thị nguyên văn kèm giải thích.
- **`-D2`:** bảng diff 2 cột (giá trị cũ / mới) theo ô ma trận + escalation + kênh, đúng tinh thần audit `old_target/new_target` (BR-009); chỉ đọc, footer [Đóng]. Dùng được cho cả phiên chờ duyệt lẫn phiên lịch sử.

Khác N/A: không có dialog xóa — policy không xóa, chỉ superseded bằng phiên mới (append-only).

## 4. SHEETS

| # | Sheet | UI-ID | Nội dung | Mở khi nào |
|---|-------|-------|----------|-----------|
| 1 | Form cấu hình rule — SidePanel 480px | `UI-WEB-SLA-001-S1` | FR/Res + chế độ 24/7 + pre-alert % + escalation chain (bậc, thời gian, người nhận) + kênh theo mức + lý do thay đổi | Click ô ma trận / [Chi tiết] chain (T1) |
| 2 | Tier profile ghi đè của 1 khách — SidePanel 480px | `UI-WEB-SLA-001-S2` | Ghi đè FR/Res per priority + nhãn nguồn + lịch làm việc riêng + song song giá trị ma trận chuẩn | Click row bảng ghi đè (T1) |

- **`-S1` (form cấu hình — đúng ràng buộc R: form qua SidePanel 480px, KHÔNG page riêng):** header = object_type · tier × priority · badge phiên nguồn; thân: FR target (đơn vị phút cho Critical, giờ/ngày LV cho mức khác — chọn theo enum, giá trị ngoài enum bị API từ chối BR-001), Res target, chế độ tính (Critical mặc định khoá 24/7 — BR-003), pre-alert threshold (mặc định 80% — BR-005), escalation chain builder: 5 bậc mặc định assignee → OPS_AM → "CS TL"* → OPS_PLAN → BOD, mỗi bậc thời gian (mặc định 30 phút trong giờ trực) + người nhận (combobox theo vai; nhãn * "thực thi bằng quyền OPS_PLAN — DI-006"); trigger bắt buộc hiển thị read-only (Critical quá FR · chạm 100% · reopen ≥2 · Pending quá 3 ngày LV); kênh thông báo per mức: pre-alert = in-app + email + (Zalo/Telegram tùy cấu hình); breach = in-app + email + Alert Center BOD **bắt buộc, không tắt được** (BR-007 — mức đỏ không được im lặng hoàn toàn). Footer sticky: [Lưu draft phiên] (PUT API-ERP-072) + lý do thay đổi bắt buộc; Esc đóng, focus trap, trả focus về ô vừa mở. Chế độ đọc với vai không có quyền PUT — mọi control disabled + chú thích "chỉ OPS_PLAN soạn — BOD phê duyệt".
- **`-S2`:** hiển thị song song giá trị ma trận chuẩn vs giá trị áp dụng kèm nhãn nguồn (tránh cấu hình mâu thuẫn — đúng Trường hợp đặc biệt feature spec); OPS_PLAN sửa được (ghi đè + lịch LV), vai khác chỉ đọc. `[NEEDS_REVIEW: thiếu endpoint tier profile / lịch làm việc khách — xem §6]`.

Ưu tiên SidePanel vì cấu hình cần thấy song song ma trận nền (context quyết định) — mở dialog lớn sẽ che mất ô đang so.

## 5. VIEW MODES

| Mode | UI-ID | Nội dung | Ai thấy |
|---|---|---|---|
| View (mặc định) | `UI-WEB-SLA-001-M1` | Đọc ma trận + chain + ghi đè + compliance theo quyền; mọi control ghi ẩn theo PEP | OPS (đọc), FIN (đọc), OPS_AM/OPS_PLAN đầy đủ T2 |
| Edit — soạn draft qua SidePanel | `UI-WEB-SLA-001-M2` | `-S1`/`-S2` chuyển chế độ sửa; lưu = draft phiên mới, không đè phiên chạy | Chỉ OPS_PLAN (ma trận/profile); SYS_ADMIN riêng cho routing kênh hệ thống |

Create phiên = dialog `-D1`; không có mode Approve trên surface này — phê duyệt thuộc BOD qua luồng tham số REQ-BOD-009 (không nhân bản vào đây).

## 6. API ENDPOINTS

| # | Endpoint | Phương thức | Gắn với | Ghi chú |
|---|----------|------------|---------|---------|
| 1 | `/api/v1/erp/sla-policies[/{id}]` | GET (API-ERP-072) | T1: ma trận + phiên effective-dated + lịch sử phiên; `-S2` giá trị chuẩn | Permission GET: OPS/FIN; instance ma trận tier×priority GMT+7, effective-dated |
| 2 | `/api/v1/erp/sla-policies[/{id}]` | PUT (API-ERP-072) | `-S1`, `-S2` (Lưu draft), `-D1` (đề xuất phiên) | Cấu hình qua phê duyệt tham số REQ-BOD-009 (BOD duyệt + step-up MFA `policy_approval`); 409 `POLICY_NOT_APPROVED` nếu kích hoạt khi chưa duyệt |
| 3 | `/api/v1/erp/sla-timers` | GET (API-ERP-073) | T2: grid timer | Filter `object_type, object_id, sla_state`; scope theo permission; machine-state nguyên văn |
| 4 | `/api/v1/erp/notifications` | GET (API-ERP-074) | T2: log dispatch đa kênh | Idempotent + retry; kênh ngoài in-app `[NEEDS_REVIEW: P3-01 Phụ lục A #3 — flag có sẵn upstream]` |
| 5 | `/core/bi/marts/cs_sla` | GET (API-CORE-036) | T2: hàng KPI breach/MTTR/breach lặp + cờ post-mortem | Mart ops — OPS theo scope, PDP check; WEB không tự tổng hợp |
| 6 | `/core/alerts/routing` | GET/PUT (API-CORE-045) | `-S1` khối kênh (routing mức → kênh + người nhận, hiển thị; PUT chỉ SYS_ADMIN — nút ẩn với vai khác) | SYS_ADMIN soạn → BOD_CFO_CTO duyệt; dispatch ủy quyền MOD-SLA-NOTIF (on-call DI-005) |

`[NEEDS_REVIEW]` — api-contract chưa có endpoint cho: (1) **POST riêng tạo instance policy** — contract chỉ khai GET/PUT `[/{id}]`; thiết kế hiểu PUT collection-level = tạo phiên draft (upsert), cần xác nhận khi triển khai; (2) **transition kích hoạt phiên sla-policies ERP** (draft→approved→activated) — chỉ thấy `/core/policies/:id/transitions` (API-CORE-021) phía policy engine; mã lỗi `POLICY_NOT_APPROVED` gợi ý luồng kích hoạt tồn tại nhưng chưa khai path; (3) **tier profile ghi đè theo HĐ + lịch làm việc riêng của khách** (entity §7 feature spec — `customer_id, sla_overrides, custom_work_calendar`) — không có endpoint nào trong contract; (4) **danh sách post-mortem task** (BR-010 — tự sinh khi ≥3 breach/khách/30 ngày) — không có endpoint đọc; hiện chỉ gắn cờ breach lặp từ mart `cs_sla`. Không bịa endpoint — UI thiết kế theo view model feature spec, chờ bổ sung contract.

Timer/đồng hồ chạy realtime của từng ticket KHÔNG cấu hình tại đây — nằm ở S16 Ticket Queue (API-ERP-073 feeding S16); màn này chỉ cấu hình + đọc lịch sử. Notification center cá nhân là global drawer (bell), không nằm trong surface này (quyết định consolidation §2.0.5).

## 7. UI-ID Registry

| UI-ID | Loại | Tên | Ghi chú |
|-------|------|-----|---------|
| `UI-WEB-SLA-001` | screen (config surface) | SLA Policy Rules | Route `/ops/sla-policies`; Navigation S18; Permission SLANOT; OPS_AM/OPS_PLAN (owner) · OPS_AD |
| `UI-WEB-SLA-001-T1` | tab | Ma trận & chính sách (5×4 + escalation chain + ghi đè HĐ) | mặc định; sửa: OPS_PLAN |
| `UI-WEB-SLA-001-T2` | tab | Compliance history (KPI + grid timer + log dispatch) — read-only | lazy; ẩn với OPS_CONT/DES/EDIT/ADS; BOD → S23 |
| `UI-WEB-SLA-001-D1` | dialog | Đề xuất phiên cấu hình mới (effective date + lý do bắt buộc) | PUT API-ERP-072 → REQ-BOD-009 |
| `UI-WEB-SLA-001-D2` | dialog | So sánh phiên (diff old/new — BR-009) | banner chờ duyệt / lịch sử phiên |
| `UI-WEB-SLA-001-S1` | sheet (SidePanel 480px) | Form cấu hình rule: FR/Res + 24/7 + pre-alert + escalation chain + kênh | click ô ma trận; PUT API-ERP-072 |
| `UI-WEB-SLA-001-S2` | sheet (SidePanel 480px) | Tier profile ghi đè + lịch làm việc khách (song song giá trị chuẩn) | `[NEEDS_REVIEW]` endpoint |
| `UI-WEB-SLA-001-M1` | mode | View (đọc theo quyền) | mặc định |
| `UI-WEB-SLA-001-M2` | mode | Edit — soạn draft qua SidePanel | chỉ OPS_PLAN (routing kênh: SYS_ADMIN) |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/sla-notif/sla-va-notification-engine.md` | Upstream — REQ-OPS-008, BR-001→BR-012 |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream — §6.6 COMP-ERP-006 |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream — S18 |
