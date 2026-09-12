# Tính Năng: AUTO SCORING K1–K12 & Tier A–E

> **Dựa trên:** REQ-SALES-003 trong `phase1-business/departments/sales/sales.md` (Phần A)
> **Phân hệ:** CRM & Lead Pipeline V6.0 (SYS-CORE-BACKEND)
> **Module:** MOD-CRM-PIPELINE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1), `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/SYS-CORE-BACKEND/MOD-CRM-PIPELINE/[screen-group].md`, `phase5-implementation/tasks/SYS-CORE-BACKEND/MOD-CRM-PIPELINE/FEAT-CORE-CRM-003-impl.md`
>
> **ID:** FEAT-ID từ lane `core-backend--CRM-PIPELINE`. REQ-SALES-003 fan-out 2 hệ thống — bản này là bản riêng cho SYS-CORE-BACKEND (scoring engine + khóa điểm); đối ứng SYS-BCERP-WEB là hiển thị điểm + hàng đợi review flag của SM.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CRM-003 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-003 (AUTO SCORING K1–K12 & Tier A–E) |
| Người dùng liên quan | Hệ thống (tự chấm), SALES_L2 (xem điểm, bổ sung dữ liệu), SALES_L3 (review flag, thẩm định borderline D, duyệt bypass Tier E), SALES_L4, SALES_L5 (escalation, duyệt override knockout), SYS_ADMIN (cấu hình tham số) |
| Độ ưu tiên | Cao (HIGH — MVP) |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | Không có phụ thuộc chéo module (cross-dependencies = không có). Trong module: tiêu thụ brief/lead từ FEAT-CORE-CRM-001/002; `qualifiedTier` là đầu vào bắt buộc của Gate 1 tại FEAT-CORE-CRM-004 |
| Ghi chú Expert (A7) | Chưa có điều chỉnh nào từ Expert Review được ghi nhận trong `sales.md` Mục A7 tại thời điểm lập spec (12/09/2026) — giữ nguyên nội dung Phần B do sales-expert review |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng scoring engine trên Core Backend: tự chấm lead theo bộ tiêu chí V6.0 — knockout K1–K5 (fail bất kỳ → AUTO LOST), cờ cảnh báo K6–K12 (flag SM review 4h) và điểm CQ 5 tiêu chí trọng số 30/25/20/15/10 — xếp lead vào 1 trong 5 tier A–E theo mô hình đã chốt (KXN-1). Engine chấm 2 lần theo KXN-2: `autoScore` sau brief sơ bộ 3 trường và TRƯỚC First Meeting; `qualifiedTier` chấm lại sau Full Brief 8 sections và khóa cứng sau khi SM ký Gate 1. Tier là biến điều phối toàn pipeline (bypass, template/SLA/vòng sửa proposal) — vì vậy điểm phải sinh từ dữ liệu, không ai sửa tay được.

**Phạm vi:**
- Bao gồm: scoring domain service (rule engine knockout + flag + weighted CQ); lịch chấm 2 lần; map tier theo ngưỡng 1.5/2.0/3.0/3.5; AUTO LOST tự động cho Tier A; luồng bypass First Meeting Tier D/E (SM duyệt duy nhất, SLA 4h); thẩm định borderline Tier D (SM SLA 4h, quá hạn escalate GDKD); trạng thái "Thiếu dữ liệu" chặn chấm; khóa `qualifiedTier` sau Gate 1; chấm lại đúng 1 lần cho lead cũ quay lại ≤180 ngày; audit log mọi chấm/chấm lại/bypass/thẩm định.
- Không bao gồm: form thu thập dữ liệu chấm + hiển thị điểm trên WEB (counterpart); stage machine + SLA clock tổng (FEAT-CORE-CRM-002); chữ ký Go/No-Go Gate 1 (FEAT-CORE-CRM-004); EVALUATION weighted scoring phía BPVH `[KXN-6 — tiêu chí còn mở]` thuộc PROPOSAL-PLANNING; danh mục K6–K12 đầy đủ `[KXN-20 — còn mở]`.

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-CORE-BACKEND: scoring là service tự động — stories mô tả tương tác qua API; mọi kết quả enforce + ghi log ở service layer.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Hệ thống (scoring engine) | Tự chạy AUTO SCORING ngay khi brief sơ bộ đủ 3 trường — trước First Meeting | Theo KXN-2: tier sơ bộ có trước buổi gặp, lọc spy và AUTO LOST sớm |
| 2 | Hệ thống (scoring engine) | Tự đánh AUTO LOST khi fail knockout K1–K5 | Không tốn công sales cho khách vi phạm policy/đòi KPI cứng/đòi ứng tiền |
| 3 | SALES_L2 | Xem điểm CQ + lý do từng tiêu chí qua API và được gợi ý trường dữ liệu còn thiếu | Bổ sung đúng dữ liệu để được chấm lại công bằng — không đoán điểm mù |
| 4 | SALES_L3 (SM) | Nhận hàng đợi flag K6–K12 và thẩm định trong 4h; borderline Tier D cũng vào hàng đợi 4h, quá hạn tự escalate GDKD | Lead đặc biệt (brand lớn, timeline gấp) được người có thẩm quyền quyết nhanh, có lý do ghi lại |
| 5 | SALES_L3 (SM) | Bổ sung dữ liệu rồi yêu cầu chấm lại thay vì sửa điểm; duyệt bypass First Meeting cho Tier D/E nhãn lớn trong 4h làm việc | Niềm tin vào tier: điểm sinh từ dữ liệu; bypass có kiểm soát tránh lạm dụng |
| 6 | SALES_L5 (GDKD) | Duyệt override knockout K1–K5 cho deal chiến lược được chỉ định, lý do bằng văn bản | Van khẩn cấp có kiểm soát cho deal lớn ngoài khung, log bất biến để rà soát |
| 7 | SYS_ADMIN | Cấu hình ngưỡng tier, trọng số CQ, danh mục knockout/flag dưới dạng tham số version hóa | Policy đổi không phải sửa code; nhãn tier (thang nghịch trực giác A = tệ nhất, E = tốt nhất) chú giải từ config, không hardcode |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, enforce ở tầng service của Core Backend (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | **Hard gate "không ghi nhận = không tồn tại":** mọi lần chấm, kết quả thẩm định, bypass, override phải có bản ghi trên hệ thống trước khi phát sinh hệ quả (LOST, bypass, Gate 1) | API không nhận kết quả chấm/bypass ngoài hệ thống; báo cáo scoring chỉ đếm bản ghi có audit |
| BR-SALES-301 | **Chấm 2 lần theo KXN-2:** `autoScore` tại Initial Brief (sau brief sơ bộ 3 trường, TRƯỚC First Meeting — quyết bypass First Meeting); `qualifiedTier` chấm lại sau Full Brief 8 sections (tier vận hành); **khóa `qualifiedTier` sau khi SM ký Gate 1**; lead cũ quay lại ≤180 ngày giữ lịch sử scoring, chấm lại đúng 1 lần | API từ chối chấm lần 3 trong cùng chu kỳ; đổi điểm sau khóa bị chặn cứng, chỉ mở bằng luồng exception có duyệt |
| BR-SALES-302 | **Knockout K1–K5 tuyệt đối → AUTO LOST (V6.0, file 09 §2.2):** K1 sản phẩm vi phạm chính sách quảng cáo nền tảng; K2 đòi cam kết KPI cứng ("không đạt ROAS không thanh toán"); K3 tranh chấp/kiện tụng pháp lý công khai; K4 đòi ứng tiền chạy trước (tư vấn quy trình, không chấp nhận → LOST); K5 spy lấy quy trình, thiếu thiện chí cung cấp thông tin. **K6–K12 là cờ cảnh báo cộng/trừ điểm (không chặn) → FLAG SM Review 4h** — brand lớn, CEO gặp gấp, nhảy ≥3 agency/12 tháng, timeline gấp <2 tuần… (danh sách đầy đủ `[KXN-20 — còn mở]`, engine phải cho cấu hình bổ sung). Ghi nhận thêm: `sales.md` B.3 đề xuất knockout AML (FATF/chế tài/UBO) nối BR-FIN-403/404 `[CẦN CHỐT SỐ — chờ policy Lead Scoring chốt trước khi code]` — assumption có tag, chưa đưa vào engine | Fail knockout → AUTO LOST tự động kèm tiêu chí + lý do; flag tạo task SM SLA 4h; thiếu định nghĩa tiêu chí → lỗi cấu hình, không chấm âm thầm |
| BR-SALES-303 | **Map tier A–E (KXN-1 — thang nghịch trực giác, A = tệ nhất, E = tốt nhất):** điểm CQ thang 1.0–5.0 từ 5 tiêu chí trọng số 30/25/20/15/10 (Nhu cầu/KPI data 30% · ngân sách 25% · thẩm quyền 20% · nguồn lực 15% · pháp lý & sản phẩm 10%); **A <1.5 → AUTO LOST** (trừ tư vấn theo K4); **B 1.5–1.99, C 2.0–2.99 → First Meeting bắt buộc**; **D 3.0–3.49 borderline → SM thẩm định SLA 4h**, quá hạn escalate GDKD, kết quả kèm lý do; **E ≥3.5 → SM được duyệt bypass**. Thiếu dữ liệu ≥2/5 tiêu chí CQ → chặn chấm, trạng thái "Thiếu dữ liệu", cấm đoán điểm thủ công. **Cấm hardcode nhãn tier trong code** — nhãn + hệ quả load từ cấu hình | Chấm sai ngưỡng là lỗi nghiêm trọng; response trả tier kèm chú giải nghĩa; request thiếu dữ liệu không sinh tier |
| BR-CRM-003-04 | **SM không sửa điểm trực tiếp:** chỉ bổ sung dữ liệu rồi cho chấm lại; khách do đối tác (Google/TikTok/Yandex) giới thiệu không được bypass scoring; khách BOD-sponsored gắn nhãn riêng nhưng vẫn chấm `qualifiedTier`; mọi chấm/chấm lại/bypass/thẩm định ghi audit log bất biến | Không tồn tại endpoint sửa điểm; bypass không qua SM duyệt không thể sinh trạng thái `BYPASS` |
| BR-CRM-003-05 | **Bypass có kiểm soát:** chỉ Tier D/E và chỉ SM duyệt (duy nhất), SLA phản hồi 4h làm việc, lý do ghi PMS; Approved → flow nhảy thẳng BRIEF_RECEIVED; Rejected → phải tổ chức First Meeting; SM review pattern bypass hàng tháng | Bypass Tier B/C bị từ chối; quá 4h escalate; bypass thiếu lý do không commit được |
| BR-CRM-003-06 | **Override knockout có kiểm soát:** chỉ deal chiến lược được chỉ định; lý do bằng văn bản; GDKD (SALES_L5) phê duyệt lại; log bất biến; lead gắn nhãn "override" suốt vòng đời để rà quý | Override không văn bản/không GDKD bị chặn; danh sách override xuất hiện bắt buộc trong báo cáo rà quý |
| BR-CRM-003-07 | **Hệ quả tier downstream (KXN-8, chiều V6.0 — context FEAT-004/005):** proposal B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng; Gate 1 SLA 1 ngày / Gate 2 nạp trước 100% NSQC + AM 4h; trọng số CQ 30/25/20/15/10; rà soát tier theo quý (BR-SALES-503) đọc kết quả chấm có snapshot phiên tham số — tham số version hóa effective-dated, GDKD trình BOD khi hiệu chỉnh | Module khác không được tự đoán tier từ điểm — phải đọc qua tier service; chấm không snapshot tham số là lỗi dữ liệu |

---

## 4. Phân Quyền

| Hành động | SALES_L2 | SALES_L3 (SM) | SALES_L4 (TPKD) | SALES_L5 (GDKD) | SYS_ADMIN |
|-----------|----------|----------------|------------------|------------------|-----------|
| Xem điểm + lý do từng tiêu chí | ✅ (deal mình) | ✅ | ✅ | ✅ | ✅ |
| Xem hàng đợi flag K6–K12 / borderline D | ❌ | ✅ | ❌ | ✅ (giám sát) | ❌ |
| Bổ sung dữ liệu / yêu cầu chấm lại | ✅ | ✅ | ✅ | ✅ | ❌ |
| Sửa điểm trực tiếp | ❌ | ❌ | ❌ | ❌ | ❌ |
| Thẩm định borderline Tier D (SLA 4h) | ❌ | ✅ | ❌ | ✅ (escalation) | ❌ |
| Duyệt bypass First Meeting (Tier D/E, 4h) | ❌ (xin phép + lý do) | ✅ (duy nhất) | ❌ | ❌ | ❌ |
| Duyệt override knockout K1–K5 | ❌ | ❌ (đề xuất) | ❌ | ✅ | ❌ |
| Cấu hình ngưỡng/trọng số/danh mục tiêu chí | ❌ | ❌ | ❌ | ✅ (đề xuất trình BOD) | ✅ (thực thi, version hóa) |
| Xem audit log scoring | ❌ (của mình) | ✅ (nhóm) | ✅ (phòng) | ✅ | ✅ |

> Thang tier nghịch trực giác bắt buộc chú giải ở mọi bề mặt trả kết quả (API trả kèm `tier_meaning` từ cấu hình). SALES_L5 tạm BOD kiêm nhiệm — duyệt theo mã vai. Không dùng `OPS_CX`/`FIN_COMPL` (DI-006).

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Lead "Thiếu dữ liệu" kéo dài:** không có deadline chấm riêng nhưng stage machine vẫn chạy SLA stage — lead kẹt quá hạn escalate bình thường; engine hiển thị rõ trường thiếu.
- **Khách BOD-sponsored:** gắn nhãn `sponsored_by_bod`, vẫn chấm `qualifiedTier` đầy đủ (phục vụ template proposal, SLA, vòng sửa); không có luồng "không cần chấm".
- **Khách đối tác giới thiệu:** tag `partner_referral` không mang ưu tiên scoring — vẫn qua knockout + CQ như lead thường; cấm bypass vì uy tín người giới thiệu.
- **Tier A nhưng có cơ sở tư vấn theo K4:** AUTO LOST, ngoại lệ duy nhất là luồng tư vấn quy trình nạp trước (K4) — chuyển luồng có ghi lý do, không quay lại pipeline bán hàng.
- **Lead cũ quay lại ≤180 ngày:** lịch sử scoring cũ read-only, chấm lại đúng 1 lần; kết quả mới ghi tiếp chuỗi lịch sử — so sánh được delta.
- **SM quá hạn thẩm định Tier D (4h):** tự escalate GDKD; GDKD quyết thay SM kèm lý do; cả hai bước trong audit log.
- **Tham số đổi giữa lúc chấm:** snapshot phiên tham số gắn từng kết quả chấm; báo cáo rà quý đối chiếu đúng phiên đã dùng.
- **Danh mục K6–K12 chưa đầy đủ `[KXN-20]`:** engine theo pattern "điều kiện cấu hình được" — khi có danh sách đầy đủ, SYS_ADMIN thêm flag không phải phát hành bản mới.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity: Kết quả scoring — lớp trạng thái chấm điểm phủ lên pipeline stage (FEAT-CORE-CRM-002).*

**Entity:** ScoringResult (bản ghi chấm điểm lead)

**Sơ đồ trạng thái:**
```
[NOT_SCORED] ──(brief 3 trường đủ)──► [SCORING] ──(knockout fail)──► [AUTO_LOST]
                                          │
                                          ├─(thiếu ≥2/5 CQ)─► [MISSING_DATA] ──(bổ sung)──► [SCORING]
                                          │
                                          ├─(autoScore — trước First Meeting)─► [TIERED_PRELIM] ──(SM duyệt 4h — D/E)──► [BYPASS_APPROVED/REJECTED]
                                          │
                                          └─(sau Full Brief 8 sections)─► [QUALIFIED_TIER_SET] ──(SM ký Gate 1)──► [LOCKED]
                                                                              │ (chấm lại đúng 1 lần — lead quay lại ≤180 ngày)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_SCORED` | Nhận brief sơ bộ đủ 3 trường | `SCORING` | Hệ thống | Trigger từ stage machine (KXN-2 — trước First Meeting) |
| `SCORING` | Fail knockout K1–K5 | `AUTO_LOST` | Hệ thống | Ghi tiêu chí fail + lý do; ngoại lệ tư vấn K4 ghi luồng riêng |
| `SCORING` | Thiếu ≥2/5 tiêu chí CQ | `MISSING_DATA` | Hệ thống | Response kèm danh sách trường thiếu; cấm đoán thủ công |
| `MISSING_DATA` | Bổ sung đủ dữ liệu | `SCORING` (chạy lại) | SALES_L2 / hệ thống | Dữ liệu mới ghi audit; không ai nhập điểm thay |
| `SCORING` | autoScore hoàn tất | `TIERED_PRELIM` (A/B/C/D/E) | Hệ thống | Snapshot phiên tham số gắn kết quả |
| `TIERED_PRELIM` (D/E) | SM duyệt bypass / thẩm định D | `BYPASS_APPROVED`/`BYPASS_REJECTED` / `QUALIFIED_TIER_SET` | SALES_L3 (SM duy nhất), SLA 4h làm việc | Lý do ghi PMS; Approved → nhảy BRIEF_RECEIVED; quá hạn escalate GDKD |
| Sau Full Brief | Chấm `qualifiedTier` | `QUALIFIED_TIER_SET` | Hệ thống | Full Brief 8 sections đủ (KXN-3); tier vận hành cho Gate 1 |
| `QUALIFIED_TIER_SET` | SM ký Gate 1 | `LOCKED` | SALES_L3 (≠ chủ deal) qua approval engine | Khóa cứng — mở chỉ qua exception GDKD + log (FEAT-CORE-CRM-004) |
| `AUTO_LOST`/`LOCKED` | — | Kết thúc (trừ luồng exception có duyệt) | — | LOST theo luồng LOST Management; LOCKED mở bằng exception GDKD + log bất biến |

**Quy tắc:**
- Không quay về `NOT_SCORED`; chấm lại chỉ đúng 1 lần giữa hai lần chấm quy định và chỉ cho lead quay lại ≤180 ngày.
- `LOCKED` là kết thúc của kết quả chấm — mở khóa phải qua exception GDKD phê duyệt + audit log bất biến.
- Mọi chuyển trạng thái ghi actor, thời điểm, phiên tham số; tenant isolation trên toàn bộ truy vấn.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `scoring_result` | `lead_id`, `round` (autoScore/qualifiedTier/re-score), `cq_score` (1.0–5.0), `tier` (A–E), `status`, `param_set_version`, `scored_at` | FK → `lead.id` | Lịch sử chấm không xóa; `qualifiedTier` khóa sau Gate 1 |
| `scoring_criterion_result` | `result_id`, `criterion_code` (K1–K12/CQ1–CQ5), `outcome`, `weight`, `reason` | FK → `scoring_result.id` | Lý do từng tiêu chí cho WEB hiển thị |
| `scoring_param_set` | `version`, `effective_from`, `tier_thresholds` (1.5/2.0/3.0/3.5), `cq_weights` (30/25/20/15/10), `knockout_rules`, `flag_rules` | FK → tenant | Version hóa effective-dated; GDKD đề xuất — BOD duyệt |
| `bypass_decision` | `lead_id`, `tier`, `requested_by`, `decided_by`, `decision`, `reason`, `decided_at`, `sla_breached` | FK → `lead.id`, `users.id` ×2 | Field PMS: `firstMeetingBypass`/`firstMeetingBypassById` |
| `knockout_override` | `lead_id`, `rule_code`, `justification_doc_ref`, `approved_by` (GDKD), `approved_at` | FK → `lead.id`, `users.id` | Chỉ deal chiến lược; log bất biến; nhãn override suốt vòng đời |
| `review_task` | `lead_id`, `type` (flag/borderline), `assignee_id`, `due_at` (+4h), `escalated_to`, `result` | FK → `lead.id`, `users.id` | Hàng đợi review SM; escalate GDKD khi quá hạn |
| `scoring_audit_log` | `entity`, `entity_id`, `actor`, `action` (score/re-score/bypass/arbitrate/override/lock), `param_snapshot`, `at` | Polymorphic | WORM; bắt buộc mọi action |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: AUTO SCORING trước First Meeting | Lead vừa có brief sơ bộ đủ 3 trường | Hệ thống kích hoạt scoring | `autoScore` hoàn tất trước khi First Meeting lên lịch; tier sơ bộ điều chỉnh luồng gặp/bypass theo KXN-2 | [ ] |
| SC-002: Knockout → AUTO LOST | Lead fail K2 (đòi cam kết KPI cứng) | Engine xử lý | Lead chuyển `AUTO_LOST` kèm tiêu chí + lý do; không thể lên First Meeting; audit log đầy đủ | [ ] |
| SC-003: Thiếu dữ liệu chặn chấm | Lead thiếu ngân sách + thẩm quyền (2/5) | Sales yêu cầu chấm | Trạng thái "Thiếu dữ liệu" + danh sách trường thiếu; không sinh tier; không nhập điểm tay được | [ ] |
| SC-004: Borderline Tier D thẩm định 4h | `qualifiedTier` = 3.2 (Tier D) | SM thẩm định | Kết quả kèm lý do trong 4h; quá 4h tự escalate GDKD; cả hai bước ghi audit | [ ] |
| SC-005: Bypass Tier E có kiểm soát | Tier E nhãn lớn không muốn gặp từng agency | SE xin bypass, SM duyệt | SM phản hồi trong 4h; Approved → nhảy BRIEF_RECEIVED; Rejected → phải First Meeting; lý do ghi PMS | [ ] |
| SC-006: SM không sửa được điểm + khóa sau Gate 1 | SM muốn nâng điểm; sau đó Gate 1 được ký | SM gọi API ghi điểm; sau ký gọi chấm lại | Không tồn tại endpoint sửa điểm; sau Gate 1 mọi request đổi tier bị từ chối — chỉ exception GDKD + log bất biến | [ ] |
| SC-007: Đối tác giới thiệu không bypass | Lead `partner_referral` Tier E | Sales đề xuất bỏ scoring | API từ chối — scoring chạy đầy đủ; BOD-sponsored gắn nhãn nhưng vẫn chấm `qualifiedTier` | [ ] |

> **Liên kết:** SC-001…SC-007 map về REQ-SALES-003 (chấm 2 lần, knockout/flag, tier map nghịch trực giác, borderline 4h, thiếu dữ liệu, cấm sửa điểm).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) scoring_result, scoring_param_set, bypass/override | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (ScoringService, review queue, bypass/override approval) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (WEB hiển thị, Gate 1 đọc qualifiedTier) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI điểm + hàng đợi review (kênh WEB — counterpart) | `phase4-ux/SYS-BCERP-WEB/MOD-CRM-PIPELINE/[screen-group].md` |
| Nghiệp vụ gốc & business rules đầy đủ | `phase1-business/departments/sales/sales.md` (B.3), `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` §2.2b, `09_Phu_luc_Hang_so_Quy_trinh.md` §1–§2 |
| Tính năng nối tiếp trong module | FEAT-CORE-CRM-002 (stage machine), FEAT-CORE-CRM-004 (Gate 1/Gate 2), FEAT-CORE-CRM-005 (rà quý tham số) |
