# Tính Năng: SLA & Notification Engine

> **Dựa trên:** REQ-OPS-008 trong `phase1-business/departments/operations/operations.md` (Phần A — Mục REQ-OPS-008; Phần B.9 — BR-OPS-9.1→9.3)
> **Phân hệ:** BCERP Web nội bộ — Vận hành (SYS-BCERP-WEB)
> **Module:** SLA & Notification Engine (MOD-SLA-NOTIF)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 5), `phase0-brainstorm/policies/sla-khach-hang.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/sla-notif/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/sla-notif/slanot-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out chỉ định: `REQ-OPS-008` → `FEAT-ERP-SLANOT-001` — bản riêng cho touchpoint **SYS-BCERP-WEB** (Web nội bộ responsive Next.js cho nhân viên BC). Counterpart cùng REQ: SYS-CORE-BACKEND (SLA engine headless), SYS-MOBILE-INTERNAL (push, duyệt di động), SYS-PORTAL-WEB / SYS-MOBILE-PORTAL (khách).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-SLANOT-001 |
| Module | MOD-SLA-NOTIF |
| Yêu cầu nghiệp vụ | REQ-OPS-008 |
| Người dùng liên quan | OPS_AM, OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; BOD_CEO, BOD_CFO_CTO (alert center — REQ-BOD-006); SYS_ADMIN (cấu hình kênh); CUSTOMER (counterpart Portal/mobile-portal) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Không có FEAT chéo bắt buộc (cross-dependencies của lane rỗng); dữ liệu tham chiếu: tier profile khách, state machine ticket REQ-OPS-009, alert center REQ-BOD-006 |
| Ghi chú Expert (A7) | Mục A7 trong `operations.md` đang "Chờ đánh giá" — chưa có điều chỉnh cụ thể cho REQ-OPS-008; spec theo Phần A + BR-OPS-9.1–9.3, kèm quyết định đã chốt DI-005 (on-call xoay vòng SLA 4h ngoài giờ) và DI-006 (không có vai OPS_CX — trách nhiệm CX/CS về OPS_PLAN) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp trên BCERP Web nội bộ mặt bằng giám sát và thao tác để OPS bảo vệ SLA khách: hiển thị đồng hồ SLA theo ma trận tier × priority (mốc GMT+7), cảnh báo pre-alert 80% và breach 100%, escalation tự động, form override bắt buộc lý do, template thông báo khách và dashboard compliance FR/Res. WEB hiển thị **đúng trạng thái machine-state** của từng đồng hồ; toàn bộ logic tính giờ làm việc, múi giờ, pause/resume, escalation do SLA engine ở SYS-CORE-BACKEND thực thi — WEB chỉ gọi API core.

**Phạm vi:**
- Bao gồm: (1) Dashboard compliance FR/Res theo tier × priority cho OPS_AM/OPS_PLAN (lọc khách/nhóm/thời gian; breach, MTTR, breach lặp); (2) Trung tâm cảnh báo SLA — pre-alert vàng 80%, breach đỏ 100% gắn ticket/task kèm badge trạng thái clock; (3) Form override/gia hạn theo cấp (CS TL → OPS_PLAN → BOD), bắt buộc lý do, audit log bất biến; (4) Template thông báo khách sau breach (lý do, phương án khắc phục, ETA mới) và ghi nhận đã gửi trong 30 phút; (5) Cấu hình ma trận, tier profile ghi đè theo HĐ, lịch làm việc riêng của khách, kênh thông báo nội bộ (in-app, email, Zalo/Telegram tùy cấu hình); (6) Liên thông alert center BOD (REQ-BOD-006).
- Không bao gồm: engine tính giờ/pause/escalation (counterpart SYS-CORE-BACKEND); push và duyệt di động (counterpart SYS-MOBILE-INTERNAL); hiển thị đồng hồ và thông báo cho khách (counterpart SYS-PORTAL-WEB/SYS-MOBILE-PORTAL — khách chỉ nhận event của tenant mình); queue hợp nhất, state machine ticket, CSAT/detractor (REQ-OPS-009); tổng hợp SLA vào KPI nhân sự (REQ-HR-007).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Xem dashboard compliance FR/Res theo tier × priority, lọc theo khách/nhóm/thời gian | Bảo vệ SLA, phát hiện sớm breach lặp |
| 2 | OPS_AM | Nhận báo đỏ ≤5 phút khi chạm 100% SLA kèm template thông báo khách | Gửi thông báo trong 30 phút, tránh vi phạm riêng |
| 3 | OPS_CONT / OPS_DES / OPS_EDIT / OPS_ADS | Nhận cảnh báo vàng 80% qua in-app/email và thấy clock tự PAUSED khi Pending hoặc Blocked-3rd-party (có case ID) | Chủ động xử lý trước breach, không bị tính breach oan |
| 4 | OPS_PLAN | Theo dõi tổng quan breach, timeline escalation có timestamp; duyệt override/gia hạn với lý do bắt buộc | Điều phối chuỗi assignee → AM → CS TL → OPS_PLAN → BOD đúng SLA 30 phút/chặng |
| 5 | OPS_PLAN | Cấu hình ma trận và tier profile ghi đè theo hợp đồng | Áp động đúng cam kết HĐ cao hơn ma trận |
| 6 | BOD_CEO / BOD_CFO_CTO | Nhận breach đỏ vào alert center (REQ-BOD-006) kèm drill về nguồn | Giám sát rủi ro vận hành không phải hỏi từng AM |
| 7 | CUSTOMER (counterpart Portal) | Nhận thông báo và xem đồng hồ SLA của tenant mình, song song giờ địa phương | Minh bạch tiến độ, không thấy dữ liệu tenant khác |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer xử lý đúng trong code. Nguồn: `sla-khach-hang.md` §2.1 + BR-OPS-9.1/9.2/9.3. Enforce ở service layer CORE; WEB phản chiếu trạng thái và chặn thao tác vượt thẩm quyền trên UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Ma trận tier × priority (GMT+7):** áp động theo tier profile; A = thấp nhất, E = cao nhất; tính bằng giờ làm việc (riêng Critical 24/7); FR = First Response, Res = Resolution; 1 ngày LV = 8 giờ. Giá trị đầy đủ ở bảng dưới. | API từ chối priority ngoài enum; target hiển thị đúng ô (tier, priority) |
| BR-002 | **Ghi đè:** HĐ cam kết cao hơn ma trận → ghi đè theo profile khách; khách khai báo lịch làm việc riêng trên portal → clock High/Medium/Low theo lịch đó (mặc định giờ BC). | WEB gắn nhãn nguồn ("theo HĐ" / "theo lịch khách") |
| BR-003 | **SLA clock:** GMT+7 là mốc tính duy nhất; giờ làm việc BC T2–T6 9:00–18:00, nghỉ trưa 12:00–13:00 (8h LV/ngày); T7, CN, lễ VN không tính; **Critical chạy 24/7**; ngoài giờ Critical do ca trực on-call xoay vòng xử lý, **SLA 4h** (DI-005 đã chốt). | Clock sai ngày nghỉ/giờ trưa là bug dữ liệu; WEB hiển thị countdown giờ LV còn lại |
| BR-004 | **Pause tự động:** (a) Pending (chờ khách) — pause; nhắc Critical 4h/12h, mức khác 24h/48h LV; sau nhắc thứ 2 mà tiếp tục 24h (Critical) / 24h LV (còn lại) không phản hồi → auto-Closed "khách không phản hồi", **không tính breach**, được reopen trong 7 ngày; (b) Blocked-3rd-party — pause khi có case ID platform, tối đa 5 ngày LV, quá hạn tự escalate AM. | WEB không cho resume trái trạng thái; pause/resume ghi nguồn kích hoạt |
| BR-005 | **Pre-alert 80%:** cảnh báo vàng cho assignee + AM (in-app + email; thêm Zalo/Telegram tùy cấu hình); trong 80–100% assignee phải có hành động/cập nhật trên ticket. | Không có cập nhật → cảnh báo đánh dấu "chưa có hành động", nổi đầu danh sách TL/OPS_PLAN |
| BR-006 | **Breach 100%:** trong **5 phút** báo đỏ AM + CS TL, đẩy dashboard OPS_PLAN và alert center BOD; **AM thông báo khách trong 30 phút** theo template chuẩn (lý do, phương án khắc phục, ETA mới) — không thông báo là **vi phạm riêng, độc lập** breach kỹ thuật. | WEB đếm ngược 30 phút; quá hạn không có bản ghi "đã thông báo" → cờ vi phạm riêng trên dashboard |
| BR-007 | **Notification đa kênh:** in-app, email, Zalo/Telegram tùy cấu hình; breach đỏ đồng thời vào alert center BOD (WEB tổng hợp — đã/chưa xử lý, phân loại, drill nguồn; push di động do counterpart M-INT, ≤5 phút). | Kênh chưa cấu hình → fallback in-app + log delivery; mức đỏ không được im lặng hoàn toàn |
| BR-008 | **Escalation tự động:** chuỗi assignee → AM → CS TL → OPS_PLAN → BOD, mỗi chặng SLA 30 phút trong giờ trực, ghi timestamp; trigger bắt buộc: Critical quá First Response; ticket chạm 100% SLA; reopen ≥2 lần; Pending quá 3 ngày LV. | Quá 30 phút một chặng → tự đẩy chặng kế tiếp, đánh dấu trễ trên timeline |
| BR-009 | **Override bắt buộc lý do + audit log bất biến (ai, khi nào, giá trị cũ/mới):** gia hạn Resolution lần 1 ≤50% target trước breach — CS TL (1 lần/ticket, 15 phút trong giờ trực); override FR mọi mức + gia hạn lần 2 — OPS_PLAN (30 phút); miễn SLA theo đợt (platform outage toàn cục, force majeure) — BOD theo đề xuất OPS_PLAN (4h). | Thiếu lý do → nút submit khóa, API từ chối; log append-only, kể cả Super Admin không sửa/xóa |
| BR-010 | **Post-mortem:** ≥3 breach/khách/30 ngày hoặc ≥2 breach cùng root cause/90 ngày → post-mortem trong 5 ngày LV (CS TL review, OPS_PLAN phê duyệt); Tier D/E breach ảnh hưởng doanh thu → thêm buổi review với khách do AM chủ trì. | Đạt ngưỡng → tự sinh task post-mortem; quá hạn được coi là mở |
| BR-011 | **Đo chuẩn hóa:** FR = phản hồi đầu tiên **có nội dung xử lý** của nhân viên BC (auto-reply không tính); Res = chuyển Resolved kèm mô tả giải pháp; sự cố phụ thuộc nền tảng tính "đạt" khi đã escalate + có case ID + cập nhật 8 giờ — thời gian chờ platform không tính vào breach của BC. | Phản hồi chỉ là auto-reply → không ghi nhận là FR |
| BR-012 | **Tenant isolation:** khách chỉ nhận thông báo và xem đồng hồ event của tenant mình qua counterpart Portal/mobile-portal; WEB không render dữ liệu SLA chéo tenant cho user portal. | Truy vấn event tenant khác → API trả 403 + audit |

**Ma trận tier × priority (FR/Res, giờ làm việc; riêng Critical 24/7) — `sla-khach-hang.md` §2.1:**

| Tier | Critical | High | Medium | Low |
|---|---|---|---|---|
| E | 15 phút / 4 giờ | 30 phút / 8 giờ | 2 giờ / 1 ngày LV | 4 giờ / 2 ngày LV |
| D | 30 phút / 6 giờ | 1 giờ / 12 giờ | 3 giờ / 1,5 ngày LV | 8 giờ / 3 ngày LV |
| C | 1 giờ / 8 giờ | 2 giờ / 1 ngày LV | 4 giờ / 2 ngày LV | 8 giờ / 4 ngày LV |
| B | 2 giờ / 12 giờ | 4 giờ / 1,5 ngày LV | 8 giờ / 3 ngày LV | 1 ngày LV / 5 ngày LV |
| A | 4 giờ / 1 ngày LV | 8 giờ / 2 ngày LV | 1 ngày LV / 4 ngày LV | 2 ngày LV / 7 ngày LV |

> **Ánh xạ vai + giả định còn mở:** policy dùng "CS TL" nhưng registry 18 vai không có role CS riêng (DI-006: trách nhiệm CX/CS về OPS_PLAN) — thao tác cấp "CS TL" thực thi bằng quyền OPS_PLAN, chờ xác nhận khi chốt cơ cấu tổ chức. Danh sách đầy đủ cờ cảnh báo K6–K12 chưa tường minh `[KXN-20]` — chỉ cấu hình cờ đã xác nhận; Ma trận RACI chờ chốt `[KXN-19]` — chuỗi escalation BR-008 theo BR-OPS-9.3/9.4 hiện hành, rà lại khi KXN-19 chốt. Không tự quyết ngoài tài liệu.

---

## 4. Phân Quyền

> *Thực thi trên WEB nội bộ; quyền thật enforce ở tầng API CORE. Cột CUSTOMER chỉ tham chiếu — khách thao tác trên counterpart Portal, không đăng nhập WEB nội bộ.*

| Hành động | OPS_CONT/DES/EDIT/ADS | OPS_AM | OPS_PLAN | BOD_CEO/CFO_CTO | SYS_ADMIN | CUSTOMER (Portal) |
|-----------|----------------------|--------|----------|-----------------|-----------|-------------------|
| Xem đồng hồ SLA của ticket/task được gán | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ (tenant mình) |
| Cập nhật hành động/tiến độ khi 80–100% | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem dashboard compliance FR/Res | ❌ | ✅ | ✅ | ✅ (tổng quan) | ❌ | ❌ |
| Nhận pre-alert 80% / breach 100% | ✅ | ✅ | ✅ | ✅ (breach đỏ) | ❌ | ✅ (tenant mình) |
| Thông báo khách theo template sau breach | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ (nhận, không gửi) |
| Gia hạn lần 1 (≤50% — quyền "CS TL" ánh xạ DI-006) / override FR / gia hạn lần 2 | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Miễn SLA theo đợt (outage, force majeure) | ❌ | ❌ | ✅ (đề xuất) | ✅ (duyệt) | ❌ | ❌ |
| Xem audit log / alert center BOD | ❌ | ✅ (log của mình) | ✅ | ✅ (alert center) | ✅ (alert kỹ thuật, không tự đóng alert đỏ) | ❌ |
| Cấu hình ma trận, tier profile, lịch áp dụng, kênh thông báo | ❌ | ❌ | ✅ (ma trận/profile) | ✅ (phê duyệt đợt miễn) | ✅ (kênh, hệ thống) | ✅ (khai báo lịch của mình, phía Portal) |

Mọi override/miễn SLA bắt buộc trường lý do và audit log bất biến theo BR-009. CUSTOMER không có quyền ghi trên WEB nội bộ — toàn bộ tương tác nằm ở counterpart portal, bị chặn tenant isolation theo BR-012.

---

## 5. Trường Hợp Đặc Biệt

- **Khách không phản hồi sau 2 lần nhắc:** ticket Pending sau nhắc thứ 2 mà tiếp tục 24h (Critical) / 24h LV (mức khác) im lặng → auto-Closed "khách không phản hồi", không tính breach; được reopen trong 7 ngày giữ ngữ cảnh, quá 7 ngày tạo ticket mới tham chiếu.
- **Bị chặn bởi nền tảng:** chỉ được pause clock khi có case ID platform; tối đa 5 ngày LV, quá hạn tự escalate AM; platform outage toàn cục → BOD miễn SLA theo đợt (BR-009, đề xuất OPS_PLAN, quyết định trong 4h).
- **Hợp đồng cam kết khác ma trận:** tier profile ghi đè; WEB hiển thị song song giá trị ma trận chuẩn và giá trị áp dụng kèm nhãn nguồn (HĐ/ma trận/lịch khách) để tránh cấu hình mâu thuẫn.
- **Ngoài giờ với Critical:** không bố trí desk 24/7 — cảnh báo Critical ngoài giờ định tuyến tới ca trực on-call xoay vòng, SLA 4h (DI-005); WEB hiển thị "ca trực hiện tại" để AM biết đầu mối.
- **Nguy cơ ngập cảnh báo:** một đợt outage sinh đồng loạt breach → gộp alert theo nguồn, ưu tiên theo mức (nguyên tắc BR-BOD-006.2 liên thông); nhân viên vẫn thấy chi tiết từng ticket trong danh sách WEB.
- **Cờ cảnh báo chưa chốt:** các cờ K6–K12 chưa có danh sách đầy đủ `[KXN-20]` → chỉ bật tự động cờ đã xác nhận trong nguồn; cờ mới thêm sau khi chốt, không cấu hình tay theo cảm tính.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Đồng hồ SLA (SLA Clock) — gắn mỗi ticket/task; WEB hiển thị nguyên trạng (machine-state) trên badge, danh sách, dashboard.

**Sơ đồ trạng thái:**
```
[RUNNING] ──(80% target)──► [PRE_ALERT] ──(100%)──► [BREACHED]
    │  ▲                         │                       │
    │  └─(resume)─ [PAUSED] ◄─(pause: Pending / Blocked có case ID)
    │                            │ (gia hạn/override)
    ├─(Resolved đúng hạn)─► [MET]  ▼
    │                       [EXTENDED] ─(hết hạn chưa Resolved)─► [BREACHED]
    ├─(auto-Closed sau 2 nhắc)─► [AUTO_CLOSED]
[BREACHED] ─(Resolved trễ có mô tả giải pháp)─► [BREACHED_RESOLVED]
[PRE_ALERT / BREACHED] ─(BOD miễn theo đợt)─► [WAIVED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `RUNNING` | Đạt 80% thời lượng | `PRE_ALERT` | Hệ thống (engine) | Tự động; cảnh báo vàng assignee + AM (BR-005) |
| `RUNNING` / `PRE_ALERT` | Pause (Pending / Blocked-3rd-party) | `PAUSED` | Hệ thống | Pending: chu kỳ nhắc BR-004; Blocked: phải có case ID platform |
| `PAUSED` | Resume | `RUNNING` / `PRE_ALERT` | Hệ thống | Khách phản hồi / platform gỡ chặn; đếm tiếp từ mốc đã lưu |
| `PRE_ALERT` | Đạt 100% | `BREACHED` | Hệ thống | Báo đỏ AM + CS TL ≤5 phút, đẩy OPS_PLAN + alert center BOD (BR-006) |
| `PRE_ALERT` / `BREACHED` | Duyệt gia hạn/override | `EXTENDED` | CS TL (lần 1 ≤50%) / OPS_PLAN (lần 2 + FR) — quyền hệ thống: OPS_PLAN | Lý do bắt buộc + audit log bất biến (BR-009) |
| Bất kỳ chưa kết thúc | Resolved (đúng hạn / trễ) | `MET` / `BREACHED_RESOLVED` | Assignee | Nhập mô tả giải pháp (BR-011); bản trễ vẫn tính breach trong thống kê |
| `RUNNING` / `PAUSED` | Auto-Closed | `AUTO_CLOSED` | Hệ thống | Sau nhắc thứ 2 + 24h (Critical) / 24h LV không phản hồi; không tính breach; reopen ≤7 ngày |
| `BREACHED` | Miễn theo đợt | `WAIVED` | BOD (đề xuất OPS_PLAN) | Outage toàn cục / force majeure; quyết định trong 4h (BR-009) |

**Quy tắc:**
- `MET`, `BREACHED_RESOLVED`, `AUTO_CLOSED`, `WAIVED` là trạng thái kết thúc; reopen sau `AUTO_CLOSED` tạo vòng clock mới nhưng giữ ngữ cảnh và đếm reopen (reopen ≥2 lần là trigger escalation).
- Không quay về trạng thái trước; mọi chuyển trạng thái do engine CORE thực hiện và ghi timestamp — WEB chỉ phản chiếu và gửi lệnh hợp lệ.
- Mỗi lần vào `BREACHED` ghi vào bộ đếm post-mortem của khách (BR-010) và đẩy alert đỏ vào alert center BOD (BR-006).

---

## 7. Tóm Tắt Entity (Quick Reference)

Chi tiết DDL đầy đủ nằm tại `phase3-architecture/technical-specs/database-design.md`; bộ entity tối thiểu của tính năng: **SLA Policy Config** (`tier`, `priority`, `fr_target`, `res_target`, `is_247` — duy nhất theo cặp tier × priority), **Tier Profile** (`customer_id`, `sla_overrides`, `custom_work_calendar` — FK tới khách/tenant), **SLA Clock** (`ticket_id`, `state`, `elapsed_lv`, `paused_reason`, `case_id_platform` — FK tới ticket/task REQ-OPS-009), **SLA Alert** (`clock_id`, `level`, `channel`, `delivered_at`, `ack_by`), **Override/Waiver Log** (`type`, `old_target`, `new_target`, `reason`, `actor`, `at` — append-only bất biến), **Escalation Trace** (`stage`, `sent_at`, `handled_at`), **Post-Mortem Task** (`customer_id`, `breach_count`, `root_cause_group`, `due_date`). Bộ entity này là nguồn cho state machine mục 6 và rule BR-001→BR-012.

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5; dưới đây là phác thảo sơ bộ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Pre-alert 80% đúng người, đúng kênh | Ticket Tier E–High RUNNING, elapsed = 80% target | Clock đạt ngưỡng | Assignee + AM nhận cảnh báo vàng qua in-app + email đã cấu hình; badge chuyển `PRE_ALERT` | [ ] |
| SC-002: Pause khi chờ khách | Ticket chuyển sang Pending | AM set Pending | Clock `PAUSED`; nhắc theo chu kỳ BR-004; sau 2 nhắc + 24h im lặng → `AUTO_CLOSED` không tính breach | [ ] |
| SC-003: Breach 100% và thông báo khách | Ticket chạm 100% target | Hệ thống phát hiện breach | AM + CS TL nhận báo đỏ ≤5 phút; OPS_PLAN thấy trên dashboard; BOD thấy trong alert center; đếm ngược 30 phút bật trên ticket | [ ] |
| SC-004: Override có audit log | OPS_PLAN mở form gia hạn lần 2 | Submit thiếu lý do → từ chối; nhập lý do → duyệt | Target mới ghi kèm audit log bất biến (old/new, actor, timestamp) | [ ] |
| SC-005: Tenant isolation | Hai tenant A, B có event SLA riêng | Khách tenant A mở portal | Chỉ thấy event của tenant A; gọi API event tenant B → 403 + audit | [ ] |
| SC-006: Post-mortem tự sinh | Khách X đã có 3 breach trong 30 ngày | Breach thứ 3 ghi nhận | Task post-mortem tự sinh, due 5 ngày LV; CS TL review — OPS_PLAN phê duyệt | [ ] |

> **Liên kết:** mỗi scenario map về REQ-OPS-008 (Mục 2 — dashboard compliance, pre-alert/breach, escalation, override; BR-003–BR-010).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (clock state, alert feed, override) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp xuyên hệ thống (CORE engine, M-INT push, PORTAL đồng hồ, Zalo/Telegram) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (dashboard compliance, trung tâm cảnh báo, form override) | `phase4-ux/bcerp-web/sla-notif/[screen-group].md` |
| Bản counterpart (CORE-BACKEND, MOBILE-INTERNAL, PORTAL-WEB, MOBILE-PORTAL) | `phase2-features/<system>/sla-notif/` (các lane cùng REQ-OPS-008) |
| Nguồn policy | `phase0-brainstorm/policies/sla-khach-hang.md` §2.1; `operations.md` B.9 (BR-OPS-9.1–9.3) |
