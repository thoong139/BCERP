# Tính Năng: Pipeline V6.0 — hard gate "không ghi nhận = không tồn tại" & phân bổ lead

> **Dựa trên:** REQ-SALES-002 trong `phase1-business/departments/sales/sales.md` (Phần A)
> **Phân hệ:** CRM & Lead Pipeline V6.0 (SYS-CORE-BACKEND)
> **Module:** MOD-CRM-PIPELINE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1), `documents/quy-trinh-lam-viec/08_Ma_tran_RACI_Gate_SLA.md` (v1.1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/SYS-CORE-BACKEND/MOD-CRM-PIPELINE/[screen-group].md`, `phase5-implementation/tasks/SYS-CORE-BACKEND/MOD-CRM-PIPELINE/FEAT-CORE-CRM-002-impl.md`
>
> **ID:** FEAT-ID từ lane `core-backend--CRM-PIPELINE`. REQ-SALES-002 fan-out 2 hệ thống — bản này là bản riêng cho SYS-CORE-BACKEND (stage machine + hard block tầng API); đối ứng SYS-BCERP-WEB là pipeline board trải nghiệm hằng ngày.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CRM-002 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-002 (Pipeline V6.0 — hard gate & phân bổ lead) |
| Người dùng liên quan | SALES_L1, SALES_L2 (pipeline cá nhân), SALES_L3 (nhóm — gán owner, nhận alert SLA), SALES_L4 (phòng), SALES_L5 (toàn Sales), SYS_ADMIN (cấu hình SLA) |
| Độ ưu tiên | Cao (HIGH — MVP) |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | Không có phụ thuộc chéo module (cross-dependencies = không có). Trong module: tiêu thụ bản ghi lead từ FEAT-CORE-CRM-001; cung cấp stage machine + SLA clock cho FEAT-CORE-CRM-003/004 |
| Ghi chú Expert (A7) | Chưa có điều chỉnh nào từ Expert Review được ghi nhận trong `sales.md` Mục A7 tại thời điểm lập spec (12/09/2026) — giữ nguyên nội dung Phần B do sales-expert review |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng stage machine và SLA engine của Pipeline V6.0 trên Core Backend: quản lý chuyển stage theo trình tự quy-trinh v1.1 (RAW_DATA → BRIEF_SENT → FIRST_MEETING (+BYPASS) → BRIEF_RECEIVED → LEAD → QUALIFIED → bàn giao BPVH → EVALUATION → … → WON → DEPLOY), **hard block mọi chuyển stage thiếu done criteria ở cả UI và API**, chạy SLA clock từng stage/gate với escalation tự động, và phân bổ lead mới theo quy tắc nguồn có escape hatch — hiện thân kỹ thuật của nguyên tắc "không ghi nhận = không tồn tại", điều kiện tiên quyết để hoa hồng không tranh chấp deal credit.

**Phạm vi:**
- Bao gồm: stage machine domain service (done criteria machine-checkable từng stage, block 2 tầng); SLA clock + escalation tự động lên cấp trên trực tiếp (RAW DATA 24h, BRIEF SENT 24h, FIRST MEETING 3 ngày làm việc (+2 có lý do), BYPASS 4h, BRIEF RECEIVED 1 ngày, LEAD 1 ngày, QUALIFIED 1 ngày, AM xác nhận bàn giao 4h); kiểm tra Initial Brief 2h làm việc đủ 3 trường bắt buộc (Ngân sách, Sản phẩm/dịch vụ, Nhu cầu thật) để kích hoạt AUTO SCORING; meeting notes bắt buộc trước QUALIFIED; auto-assign engine + luồng gán tay SM; audit log bất biến mọi chuyển stage; WON trong 24h → tự sinh dự án + AM xác nhận capacity.
- Không bao gồm: logic scoring/tier (FEAT-CORE-CRM-003); approval engine ký Gate 1/Gate 2 (FEAT-CORE-CRM-004 — tính năng này chỉ cung cấp điều kiện stage); pipeline board WEB (counterpart); Handoff Package chi tiết + milestone onboarding (REQ-SALES-008); cấu hình kênh webhook (SYS-INTEGRATION-GW).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-CORE-BACKEND: stories mô tả hành vi headless API/domain service; client chỉ là bề mặt — mọi ràng buộc enforce ở service layer.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L2 | Gọi API chuyển stage và bị từ chối ngay nếu done criteria chưa đủ, kèm lý do thiếu mục nào | Pipeline phản ánh đúng thực tế — không tự lừa mình bằng stage ảo |
| 2 | SALES_L1 | Hệ thống tự kiểm tra Initial Brief đủ 3 trường trong 2h làm việc để kích hoạt AUTO SCORING | Lead không kẹt đầu phễu; scoring bắt đầu sớm theo KXN-2 |
| 3 | SALES_L3 (SM) | Nhận alert + escalation tự động khi lead trong nhóm quá SLA stage | Can thiệp trước khi lead chết im; escalate lên cấp trên trực tiếp không cần ai nhớ |
| 4 | Hệ thống (auto-assign) | Tự gán owner lead kênh số theo quy tắc nguồn (kênh chủ quản) ngay khi tạo | Lead mới có người phụ trách tức thì |
| 5 | SALES_L3 (SM) | Gán tay owner lead tự do trong 4h giờ làm việc, đổi owner khi nhân sự nghỉ — có lý do + audit log | Kiểm soát phân bổ có escape hatch nhưng không tùy tiện |
| 6 | SALES_L2 | Ghi meeting notes; hệ thống chặn sang QUALIFIED khi chưa có notes | "Không notes = meeting không được công nhận" |
| 7 | SALES_L5 (GDKD) | Xem pipeline funnel theo stage (conversion, tuổi deal, deal kẹt SLA) qua API báo cáo tuần | Quản trị phễu bằng dữ liệu thực — "không ghi nhận = không tồn tại" áp cả cấp quản lý |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, enforce ở tầng service của Core Backend (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | **Hard gate "không ghi nhận = không tồn tại":** mọi chuyển stage, meeting notes, split credit, chữ ký gate, kết quả thẩm định phải có bản ghi trên hệ thống trước khi phát sinh hệ quả. Deal không có bản ghi trước Gate 2: không được vận hành và không tính credit — kể cả khi SM/GDKD xác nhận miệng; áp dụng cả với cấp quản lý | API từ chối request tham chiếu deal không có bản ghi; báo cáo không đếm dữ liệu ngoài pipeline |
| BR-SALES-201 | **Stage machine 10 stage V6.0:** trình tự RAW_DATA → BRIEF_SENT → (AUTO SCORING — bước hệ thống giữa BRIEF_SENT và FIRST_MEETING, không phải stage riêng theo KXN-2) → FIRST_MEETING → BRIEF_RECEIVED → LEAD → QUALIFIED → bàn giao BPVH (EVALUATION → … → WON → DEPLOY); **hard block chuyển stage thiếu done criteria ở cả UI và API**; done criteria machine-checkable theo file 02 §2; audit log bất biến mọi chuyển stage | API trả lỗi kèm danh mục điều kiện chưa đạt; UI vô hiệu nút; chuyển trái phép không thể xảy ra ở tầng service |
| BR-SALES-202 | **SLA Initial Brief:** gửi form trong 24h từ RAW_DATA (không gia hạn, trễ → SM nhận alert); khi KH submit, kiểm tra trong **2h làm việc** đủ 3 trường (Ngân sách, Sản phẩm/dịch vụ, Nhu cầu thật) để kích hoạt AUTO SCORING; quá hạn cảnh báo rồi escalate cấp trên trực tiếp | SLA breach tự sinh alert + escalation record; stage không tiến khi 3 trường thiếu |
| BR-CRM-002-03 | **Meeting notes bắt buộc trước QUALIFIED:** không notes = meeting không được công nhận; stage machine từ chối chuyển FIRST_MEETING/BYPASS → BRIEF_RECEIVED khi chưa lưu notes | API block chuyển stage; cảnh báo trên board (WEB) và API response |
| BR-CRM-002-04 | **Phân bổ lead theo quy tắc + escape hatch:** lead kênh số tự gán theo quy tắc nguồn (kênh chủ quản); lead tự do → SM gán trong 4h giờ làm việc `[CẦN CHỐT SỐ — SLA gán và quy tắc round-robin chưa có chính sách ban hành; đề xuất gán trong 4h giờ làm việc]`; tranh chấp nguồn giải theo anti-duplicate (FEAT-CORE-CRM-001); escape hatch: SM/GDKD đổi owner kèm lý do, audit log bất biến, không xóa lịch sử phân bổ | Lead không owner quá SLA vào hàng đợi cảnh báo SM → escalate GDKD; đổi owner thiếu lý do bị API từ chối |
| BR-CRM-002-05 | **SLA clock từng stage + escalation tự động:** RAW DATA 24h tạo project · BRIEF SENT 24h · FIRST MEETING 3 ngày làm việc, +2 ngày có lý do ghi PMS · BYPASS 4h · BRIEF RECEIVED 1 ngày · LEAD 1 ngày · QUALIFIED 1 ngày · AM xác nhận bàn giao 4h làm việc; escalation tự động lên cấp trên trực tiếp; SLA tính giờ làm việc cấu hình theo tenant | Breach tự sinh escalation record; stage quá hạn không tự hủy — chỉ chuyển khi đủ điều kiện hoặc LOST có lý do |
| BR-CRM-002-06 | **WON trong 24h:** WON cập nhật trong 24h → tự sinh dự án + AM xác nhận capacity trong 24h (nối REQ-SALES-008); capacity trống = 0 → cảnh báo GDKD + OPS_PLAN trước khi ký Gate 2 | WON quá hạn breach SLA; DEPLOY không mở khi chưa có xác nhận capacity |
| BR-CRM-002-07 | **Ngoại lệ trình tự có kiểm soát:** khách tái ký được rút gọn Initial Brief nhưng **không bỏ Gate 1/Gate 2**; deal hủy trước Gate 1 chỉ lưu hồ sơ (không xóa); AUTO SCORING trước First Meeting (KXN-2); 5 tier A–E, A <1.5 AUTO LOST → E ≥3.5 bypass (KXN-1) | Cấu hình rút gọn chỉ áp lead có flag tái ký hợp lệ; gate engine vẫn chặn thiếu 2 gate; hủy deal sinh hồ sơ read-only |
| BR-CRM-002-08 | **Bối cảnh tier/Gate (downstream — enforce tại FEAT-CORE-CRM-003/004):** Gate 1 SLA 1 ngày làm việc / Gate 2 nạp trước 100% NSQC + AM xác nhận SLA 4h; trọng số CQ theo tier 30/25/20/15/10; `qualifiedTier` hợp lệ là điều kiện chuyển QUALIFIED | Stage machine không tự tính điểm — chỉ đọc kết quả scoring; chuyển thiếu `qualifiedTier` bị từ chối |
| BR-CRM-002-09 | **Định mức downstream theo KXN-8 (chiều V6.0):** proposal B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng — tham số đọc từ tier service gắn stage PROPOSAL phía BPVH; rà soát tier theo quý (BR-SALES-503) và UPSELL theo quy-trinh v1.1 file 06 §8 tiêu thụ dữ liệu stage/SLA do engine ghi — engine phải cung cấp đủ dữ liệu lịch sử stage | Cấm hardcode nhãn/định mức tier trong stage machine; báo cáo rà quý thiếu dữ liệu lịch sử là lỗi engine |

---

## 4. Phân Quyền

| Hành động | SALES_L1/L2 | SALES_L3 (SM) | SALES_L4 (TPKD) | SALES_L5 (GDKD) | SYS_ADMIN |
|-----------|-------------|----------------|------------------|------------------|-----------|
| Xem pipeline của mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem pipeline nhóm/phòng/toàn Sales | ❌ | ✅ (nhóm) | ✅ (phòng) | ✅ (toàn Sales) | ✅ |
| Chuyển stage (đủ done criteria) | ✅ (deal của mình) | ✅ | ✅ | ✅ | ❌ |
| Gán/đổi owner lead tự do | ❌ | ✅ (SLA 4h `[CẦN CHỐT SỐ]`) | ✅ (phòng) | ✅ | ❌ |
| Gia hạn SLA FIRST MEETING (+2 ngày, ghi lý do PMS) | ✅ (đề xuất) | ✅ (phê duyệt) | ❌ | ✅ | ❌ |
| Đánh dấu WON / hủy deal trước Gate 1 | ✅ (WON của mình) | ✅ (xác nhận) | ✅ | ✅ | ❌ |
| Cấu hình ngưỡng SLA / escalation | ❌ | ❌ | ❌ | ✅ (đề xuất trình BOD) | ✅ (thực thi) |
| Vô hiệu hard gate / chuyển stage thiếu điều kiện | ❌ | ❌ | ❌ | ❌ (chỉ exception có phê duyệt + log) | ❌ |

> Không có hành động "bypass hard gate" cho bất kỳ vai nào — kể cả BOD kiêm nhiệm GDKD; ngoại lệ duy nhất là luồng exception có phê duyệt văn bản + audit log bất biến. Trên MOBILE sales chỉ xem board + nhận cảnh báo SLA, không di chuyển stage trên di động (WEB là kênh thao tác chính, CORE là nơi enforce).

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách tái ký:** rút gọn Initial Brief nhưng Gate 1/Gate 2 vẫn bắt buộc đủ — cấm "đường tốt" cho khách quen.
- **Deal hủy trước Gate 1:** không xóa — lưu hồ sơ với lý do, gắn phân loại LOST (4 nhóm A/B/C/D `[KXN-17 — định nghĩa còn mở, dùng enum đề xuất file 09 §8]`) và re-contact date trong 24h.
- **Người phụ trách nghỉ việc:** chuyển quản lead/deal có audit log; SLA clock dừng trong thời gian chờ SM gán lại (tối đa 4h giờ làm việc `[CẦN CHỐT SỐ]`) rồi chạy tiếp.
- **Gia hạn FIRST MEETING:** +2 ngày nếu có lý do, lý do ghi PMS trước khi SLA hết hạn; quá +2 ngày chạy escalation bình thường.
- **KH không phản hồi sau gửi form:** ngày 2 nhắc Zalo → ngày 3 gọi điện → ngày 4 escalate SM — hệ thống chạy nhắc theo lịch.
- **Chuyển stage đồng thời hai người:** stage machine idempotent + optimistic lock; hai request cùng deal chỉ một thắng, request kia nhận lỗi xung đột rõ ràng.
- **AUTO SCORING "Thiếu dữ liệu":** stage giữ nguyên cho tới khi đủ dữ liệu (FEAT-CORE-CRM-003) — không có cơ chế "bỏ qua chấm"; pipeline view và SLA clock cách ly theo tenant.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity: Lead/Deal pipeline. Bảng mô tả nửa Sales (bàn giao tại QUALIFIED theo KXN-4, Handoff Package 5 nhóm là checklist bắt buộc); các stage phía BPVH (EVALUATION → … → WON → DEPLOY) dùng cùng engine, quản lý bởi module PROPOSAL-PLANNING/HANDOFF-ONBOARD.*

**Entity:** Deal pipeline (PMS Project) — nửa Sales

**Sơ đồ trạng thái:**
```
[RAW_DATA] ──(24h)──► [BRIEF_SENT] ──(kiểm 3 trường trong 2h)──► «AUTO SCORING»
     │ (quá hạn → alert SM → escalate)                                 │
     ▼                                                           [FIRST_MEETING] ──(SM duyệt 4h · Tier D/E)──► [BYPASS]
[escalation GDKD]                                                     │  └─(KH từ chối gặp)─► [LOST + nurturing]
                                                                      ▼ (notes + Full Brief 8 sections)
                                            [BRIEF_RECEIVED] ──(1 ngày)──► [LEAD] ──(Gate 1 · FEAT-004)──► [QUALIFIED]
                                                                                                │ pass → [BÀN GIAO BPVH]
                                                                                                │ fail → [LOST]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `RAW_DATA` | Gửi form brief | `BRIEF_SENT` | SE (L1/L2) | Trong 24h; KH confirm nhận; trễ → alert SM |
| `BRIEF_SENT` | KH submit + đủ 3 trường | Kích hoạt AUTO SCORING (bước hệ thống) | Hệ thống | Trong 2h làm việc từ submit; thiếu → giữ stage, nhắc bổ sung |
| `BRIEF_SENT` → (tier sơ bộ có) | Lên lịch First Meeting | `FIRST_MEETING` | SE | Trong 3 ngày làm việc sau submit; B/C bắt buộc gặp; kết quả ghi ngay sau buổi gặp |
| `FIRST_MEETING` | SM duyệt bypass (Tier D/E) | `BYPASS` → `BRIEF_RECEIVED` | SALES_L3 (SM duy nhất), 4h làm việc | Lý do nhãn lớn ghi PMS; từ chối → phải tổ chức First Meeting |
| `FIRST_MEETING`/`BYPASS` | Lưu meeting notes + brief | `BRIEF_RECEIVED` | SE | Full Brief đủ 8 sections (KXN-3); 8 mục v2.3 là checklist tối thiểu; không notes = meeting không công nhận |
| `BRIEF_RECEIVED` | Xác nhận cơ hội + `qualifiedTier` | `LEAD` | SE (SM review nếu cần) | Trong 1 ngày làm việc; tier theo scoring engine (FEAT-CORE-CRM-003) |
| `LEAD` | Gate 1 — SM ký Go/No-Go | `QUALIFIED` | SALES_L3 (SM ≠ chủ deal), SLA 1 ngày làm việc | Full Brief đủ; NDA mutual signed; `qualifiedTier` hợp lệ (FEAT-CORE-CRM-004) |
| `LEAD` | Fail tiêu chí / KH không đủ | `LOST` | SE/SM | Lý do + `lostStage` + phân loại `[KXN-17]` + re-contact date trong 24h |
| `QUALIFIED` (pass) | Bàn giao BPVH | `EVALUATION` | SM ký → AM xác nhận 4h làm việc | Handoff Package 5 nhóm đủ 100% (KXN-4); SE chuyển observe mode |
| Bất kỳ (trước Gate 1) | Hủy deal | `LOST` (chỉ lưu hồ sơ) | SE/SM | Lý do bắt buộc; bản ghi read-only; không xóa |

**Quy tắc:**
- Không quay về trạng thái trước (one-way); sai sót dữ liệu xử lý bằng bản ghi hiệu chỉnh có audit, không rollback stage.
- `LOST` và `BÀN GIAO BPVH` là điểm kết thúc nửa Sales; từ `LOST` chỉ có nhánh nurturing/re-contact (file 06 §6).
- Mọi chuyển stage ghi audit log bất biến (actor, thời điểm, điều kiện đạt); SLA breach sinh escalation tự động theo chuỗi SE → SM → GDKD → BOD.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `pipeline_deal` | `lead_id`, `stage`, `stage_entered_at`, `owner_id`, `tenant_id`, `is_recurring_client`, `won_at`, `project_id` | FK → `lead.id`, `users.id`, `project.id` | Stage chỉ đổi qua StageMachineService; optimistic lock |
| `stage_transition_log` | `deal_id`, `from_stage`, `to_stage`, `criteria_snapshot`, `actor_id`, `at` | FK → `pipeline_deal.id` | WORM; chụp done criteria tại thời điểm chuyển |
| `stage_sla_config` | `stage`, `sla_value`, `unit`, `escalation_path`, `tenant_id`, `effective_from` | FK → tenant | Version hóa effective-dated, không sửa quá khứ |
| `sla_breach` | `deal_id`, `stage`, `breached_at`, `escalated_to`, `resolved_at` | FK → `pipeline_deal.id` | Sinh tự động bởi SLA clock |
| `meeting_note` | `deal_id`, `occurred_at`, `author_id`, `content` | FK → `pipeline_deal.id` | Bắt buộc tồn tại trước `QUALIFIED` |
| `brief_record` | `deal_id`, `level` (sơ bộ 3 trường / Full Brief 8 sections), `sections_json`, `completed_at` | FK → `pipeline_deal.id` | KXN-3: 2 cấp form |
| `lead_assignment` | `lead_id`, `assigned_to`, `assigned_by`, `rule`, `reason`, `at` | FK → `lead.id`, `users.id` ×2 | Lịch sử phân bổ không xóa — escape hatch phải có `reason` |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Block chuyển stage thiếu điều kiện | Deal ở `FIRST_MEETING` chưa có notes | SE gọi API chuyển `BRIEF_RECEIVED` | API từ chối kèm điều kiện thiếu; UI vô hiệu nút; không tạo bản ghi chuyển | [ ] |
| SC-002: SLA Initial Brief 2h | KH submit lúc 10:00 | 12:00 chưa ai kiểm tra 3 trường | Tự cảnh báo SE → escalate SM; lead giữ `BRIEF_SENT` | [ ] |
| SC-003: Auto-assign lead kênh số | Quy tắc nguồn đã cấu hình | Lead Zalo OA được tiếp nhận | Owner tự gán theo kênh chủ quản; `lead_assignment` ghi rule `auto-by-source` + audit | [ ] |
| SC-004: Gán tay quá SLA 4h `[CẦN CHỐT SỐ]` | Lead tự do chưa owner | 4h giờ làm việc trôi qua | Vào hàng đợi cảnh báo SM; tiếp tục quá hạn → escalate GDKD | [ ] |
| SC-005: Tái ký rút gọn nhưng không bỏ gate | Khách cũ tái ký (`is_recurring_client`) | SE chạy lại pipeline | Initial Brief rút gọn; Gate 1/Gate 2 vẫn bắt buộc; thiếu 1 → không mở | [ ] |
| SC-006: WON 24h tự sinh dự án | Deal chốt, SM xác nhận WON | WON cập nhật | Tự sinh dự án + đẩy AM xác nhận capacity trong 24h; capacity = 0 → cảnh báo GDKD + OPS_PLAN | [ ] |
| SC-007: Hủy deal trước Gate 1 | Deal đang `LEAD` | SE hủy deal | Chuyển `LOST` kèm lý do, read-only; phân loại LOST + re-contact date trong 24h | [ ] |

> **Liên kết:** SC-001…SC-007 map về REQ-SALES-002 (hard block 2 tầng, SLA từng stage + escalation, phân bổ auto + escape hatch, WON 24h, tái ký rút gọn).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) pipeline_deal, stage_transition_log, SLA config | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (StageMachineService, SLA clock, auto-assign engine) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (WEB board, MOBILE push, GW lead feed) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI pipeline board (kênh WEB — counterpart) | `phase4-ux/SYS-BCERP-WEB/MOD-CRM-PIPELINE/[screen-group].md` |
| Nghiệp vụ gốc & business rules đầy đủ | `phase1-business/departments/sales/sales.md` (B.2), `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` §1–§4, `08_Ma_tran_RACI_Gate_SLA.md` §3 `[KXN-19 — ma trận RACI còn chờ xác nhận]` |
| Tính năng nối tiếp trong module | FEAT-CORE-CRM-003 (scoring), FEAT-CORE-CRM-004 (Gate 1/Gate 2) |
