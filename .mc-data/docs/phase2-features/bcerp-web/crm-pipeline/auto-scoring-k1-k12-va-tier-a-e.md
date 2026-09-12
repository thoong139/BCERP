# Tính Năng: AUTO SCORING K1–K12 & Tier A–E

> **Dựa trên:** REQ-SALES-003 trong `phase1-business/departments/sales/sales.md` (Phần A + Phần B — Sales Expert Review)
> **Phân hệ:** CRM & Lead Pipeline V6.0 (SYS-BCERP-WEB)
> **Module:** CRM Pipeline (MOD-CRM-PIPELINE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase1-business/P1-02-business-workflow.md`, `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1 §2.2b), `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1 §1–§2)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/crm-pipeline/scoring-review.md`, `phase5-implementation/tasks/bcerp-web/crm-pipeline/feat-erp-crm-003-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-CRM-003 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-003 |
| Người dùng liên quan | SALES_L1 (Intern), SALES_L2 (NVKD/SE — xem điểm, bổ sung dữ liệu), SALES_L3 (TNKD), SALES_L4 (TPKD/SM — review flag, thẩm định borderline, duyệt bypass), SALES_L5 (GDKD — escalate thẩm định) |
| Độ ưu tiên | Cao (HIGH — MVP) |
| Giai đoạn | Giai đoạn 1 |
| Phụ thuộc | Không có cross-dependency chặn; nhận dữ liệu lead từ FEAT-ERP-CRM-001/002 (cùng module); scoring engine thực thi tại SYS-CORE-BACKEND (counterpart cùng REQ-ID) |
| Ghi chú Expert (A7) | Mục A7 của sales.md đang chờ điền; spec kế thừa Sales Expert Review Phần B (12/09/2026): chấm 2 lần tách biệt sơ bộ/chốt, knockout K1–K5 tuyệt đối, cấm sửa điểm tay — chỉ chấm lại sau bổ sung dữ liệu |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng hiển thị kết quả AUTO SCORING — hệ thống tự chấm điểm khách theo 12 tiêu chí (K1–K12) và xếp 5 tier A–E — trên web nội bộ để sales biết xử lý lead thế nào ngay sau brief sơ bộ, trước khi tổ chức First Meeting (KXN-2 đã chốt). Điểm tier là "mệnh giá" của lead: quyết định có bị AUTO LOST hay không, có phải gặp bắt buộc không, ai soạn proposal bao nhiêu trang, bao nhiêu vòng sửa (B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng — KXN-8, chiều V6.0), do đó màn hình phải trình bày điểm, lý do từng tiêu chí và hệ quả tier một cách minh bạch, không để nhãn tier gây hiểu nhầm.

**Phạm vi:**
- Bao gồm: màn hình hiển thị autoScore (chấm lần 1 tại Initial Brief) và qualifiedTier (chấm lần 2 sau Full Brief 8 sections) kèm lý do từng tiêu chí K1–K12; hàng đợi review scoring flag của SM (K6–K12 → FLAG SM Review trong 4h); route borderline Tier D (3.0–3.49) vào hàng đợi thẩm định SM SLA 4h, quá hạn escalate GDKD; trạng thái "Thiếu dữ liệu" khi thiếu ≥2/5 tiêu chí CQ; luồng bổ sung dữ liệu → chấm lại (không sửa điểm tay); chú giải nghĩa từng tier A–E; ghi nhận nhãn đặc biệt (đối tác giới thiệu, BOD-sponsored).
- Không bao gồm: tính toán điểm và map tier (scoring engine + khóa qualifiedTier sau Gate 1 thuộc SYS-CORE-BACKEND — counterpart cùng REQ-ID); quyết định bypass và ký Gate 1 (FEAT-ERP-CRM-004); chuyển tier sang CS sau WON (FEAT-ERP-CRM-005); bộ tiêu chí Evaluation phía BPVH (thuộc OPS — `[KXN-6]` còn mở).

**Đặc thù touchpoint SYS-BCERP-WEB:**
Web nội bộ responsive (Next.js) là nơi sales đọc kết quả và phản hồi: hiển thị đúng trạng thái machine-state của mỗi lead (chưa chấm / đã chấm sơ bộ / thiếu dữ liệu / flag chờ SM review / borderline chờ thẩm định / AUTO LOST / tier đã khóa), cung cấp form bổ sung dữ liệu để kích hoạt chấm lại, và vô hiệu hóa mọi nút "sửa điểm". Ngưỡng 1.5/2.0/3.0/3.5 và trọng số CQ 30/25/20/15/10 là tham số version hóa effective-dated ở CORE — web không hardcode nhãn tier trong code, luôn render từ cấu hình để khi BOD hiệu chỉnh (qua GDKD — FEAT-ERP-CRM-005) giao diện tự cập nhật.

**Fan-out:**
REQ-SALES-003 xuất hiện ở 2 systems — đây là bản riêng cho SYS-BCERP-WEB; counterpart: SYS-CORE-BACKEND (primary — scoring engine, chấm 2 lần, khóa điểm, audit log mọi lần chấm). Spec này mô tả phần hiển thị, review flag và luồng dữ liệu thuộc web nội bộ.

**Nguồn quy trình:** `documents/quy-trinh-lam-viec/` v1.1 — KXN-1 (5 tier A–E) và KXN-2 (scoring trước First Meeting) đã chốt; danh sách đầy đủ cờ K6–K12 chưa được liệt kê tường minh trong nguồn `[KXN-20]`; 11 KXN còn mở (6, 7, 9, 15–22) ghi assumption có tag, không tự quyết.

---

## 2. Luồng Người Dùng (User Stories)

Thời điểm chấm điểm đã chốt: AUTO SCORING chạy ngay sau brief sơ bộ đủ 3 trường (trước First Meeting) để quyết định bypass; sau Full Brief 8 sections, SE chấm lại `qualifiedTier` làm tier vận hành chính thức. Người dùng không bao giờ "chấm" theo nghĩa nhập điểm — họ cung cấp dữ liệu, máy chấm; người quản lý thẩm định flag, không đụng vào con số.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L2 (NVKD/SE) | Thấy ngay sau khi gửi brief sơ bộ: điểm CQ, tier sơ bộ và lý do từng tiêu chí K1–K12 | Biết trước lead có đáng tổ chức First Meeting, có thuộc trường hợp bypass không |
| 2 | SALES_L2 (NVKD/SE) | Được chỉ rõ "Thiếu dữ liệu" ở tiêu chí nào khi máy từ chối chấm | Bổ sung đúng mục còn thiếu thay vì đoán mò, tránh chấm lại nhiều lần |
| 3 | SALES_L4 (TPKD/SM) | Có hàng đợi flag K6–K12 (brand lớn, CEO gặp gấp, nhảy ≥3 agency/12 tháng, timeline gấp <2 tuần...) để review trong 4h | Can thiệp sớm với lead rủi ro cao, không bỏ sót tín hiệu cảnh báo |
| 4 | SALES_L4 (TPKD/SM) | Thẩm định lead borderline Tier D (3.0–3.49) với đầy đủ hồ sơ và cho kết quả kèm lý do | Quyết có tiếp nhận nhãn lớn hay không trong SLA 4h, có căn cứ lưu vết |
| 5 | SALES_L4 (TPKD/SM) | Xin bypass First Meeting cho Tier E (≥3.5) ngay trên màn hình scoring | Tiết kiệm thời gian cho nhãn lớn đấu thầu nhiều agency (quyết ký Gate nằm ở FEAT-ERP-CRM-004) |
| 6 | SALES_L1 (Intern) | Xem chú giải nghĩa từng tier A–E (A = tệ nhất, E = tốt nhất) ở mọi nơi tier xuất hiện | Không hiểu ngược tier khi nhập lead hoặc nuôi dưỡng (thang nghịch trực giác) |
| 7 | SALES_L5 (GDKD) | Nhận escalate borderline quá SLA 4h và quyết định cuối kèm lý do | Lead nhãn lớn không bị treo trong hàng đợi khi SM vắng |

---

## 3. Quy Tắc Nghiệp Vụ

Sáu nhóm quy tắc bắt buộc của lane áp dụng đầy đủ; nhóm trọng tâm là scoring 2 lần, knockout/flag và map tier. Engine nằm ở CORE; mọi giá trị hiển thị trên web phải đọc từ API scoring, không tính lại phía client.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | Hard gate "không ghi nhận = không tồn tại" (KXN-1): mọi lần chấm/chấm lại/bypass/thẩm định phải có bản ghi + audit log bất biến; pipeline 5 tier A–E (A <1.5 AUTO LOST → E ≥3.5 bypass) là chuẩn chính thức | Kết quả scoring không có bản ghi bị coi là vô hiệu; web hiển thị trạng thái inconsistent sẽ bị chặn deploy (structural check) |
| BR-SALES-301 | Chấm 2 lần: autoScore tại Initial Brief (quyết bypass First Meeting); qualifiedTier sau Full Brief 8 sections (tier vận hành — KXN-2); khóa qualifiedTier sau khi SM ký Gate 1 | qualifiedTier đã khóa không nhận chấm lại; UI hiển thị trạng thái "đã khóa" |
| BR-SALES-302 | K1–K5 knockout tuyệt đối — fail bất kỳ → AUTO LOST: K1 sản phẩm vi phạm chính sách quảng cáo nền tảng; K2 đòi cam kết KPI cứng; K3 tranh chấp/kiện tụng pháp lý công khai; K4 đòi ứng tiền chạy trước (chỉ nhánh tư vấn quy trình được giữ); K5 spy quy trình, thiếu thiện chí cung cấp thông tin (nguồn 09 §2.2 v1.1 — đề xuất bổ sung knockout AML/FATF/UBO còn `[CẦN CHỐT SỐ]`, không tự quyết). K6–K12 là flag cộng/trừ điểm cảnh báo (không chặn) → FLAG SM Review 4h; danh sách đầy đủ K6–K12 `[KXN-20]` còn mở | AUTO LOST lập tức với lý do; ghi đè tay kết quả knockout bị chặn ở API |
| BR-SALES-303 | Điểm CQ: 5 tiêu chí trọng số 30/25/20/15/10, thang 1–5 → tổng 1.0–5.0; thiếu dữ liệu ≥2/5 tiêu chí → chặn chấm, trạng thái "Thiếu dữ liệu", cấm đoán điểm thủ công. Map tier: A <1.5 AUTO LOST (trừ tư vấn theo K4); B 1.5–1.99 và C 2.0–2.99 First Meeting bắt buộc; D 3.0–3.49 borderline — SM thẩm định SLA 4h, quá hạn escalate GDKD; E ≥3.5 SM được duyệt bypass | Máy từ chối xuất tier khi thiếu dữ liệu; web vô hiệu hóa thao tác tiếp theo của lead ở trạng thái này |
| BR-SALES-604/603 | Hệ quả tier (KXN-8, chiều V6.0): proposal B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng; CQ theo tier 30/25/20/15/10; Gate 1 SLA 1 ngày / Gate 2 nạp trước 100% NSQC SLA 4h — Go/No-Go; rà soát tier theo quý | Tier sai sẽ lan sang template proposal, SLA, vòng sửa — web phải hiển thị hệ quả đọc từ cấu hình, không suy diễn |
| BR-SALES-501/502/503 | Anti-duplicate 4 kênh và phân bổ lead (FEAT-ERP-CRM-001) là điều kiện đầu vào; rà soát quý: GDKD rà win rate + độ lệch CQ vs thực tế; hiệu chỉnh ngưỡng/trọng số phải GDKD trình BOD, tham số version hóa effective-dated; UPSELL theo file 06 §8 | Scoring dùng tham số version tại thời điểm chấm; đổi tham số không hồi áp cho lead đã chấm |

**Quy tắc bổ sung:** SM không sửa điểm trực tiếp — chỉ bổ sung dữ liệu rồi cho chấm lại; khách do đối tác (Google/TikTok/Yandex) giới thiệu không được bypass scoring; khách BOD-sponsored gắn nhãn riêng nhưng vẫn chấm qualifiedTier; thang tier nghịch trực giác (A = tệ nhất, E = tốt nhất) — UI phải chú giải rõ nghĩa từng tier và cấm hardcode nhãn tier trong code.

---

## 4. Phân Quyền

Nguyên tắc quyền lực tách khỏi con số: máy chấm, người thẩm định, GDKD hiệu chỉnh chính sách qua BOD. Không vai nào trong 18 vai registry có quyền nhập điểm trực tiếp.

| Hành động | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4 (SM) | SALES_L5 (GDKD) | SYS_ADMIN |
|-----------|----------|----------|----------|---------------|-----------------|-----------|
| Xem điểm + lý do (lead của mình) | ✅ (chú giải tier) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Bổ sung dữ liệu → kích hoạt chấm lại | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xem hàng đợi flag K6–K12 nhóm | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| Review flag (SLA 4h) | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Thẩm định borderline Tier D (SLA 4h) | ❌ | ❌ | ❌ | ✅ | ✅ (escalate quá hạn) | ❌ |
| Duyệt bypass First Meeting Tier E | ❌ | ❌ | ❌ | ✅ (duy nhất SM) | ❌ | ❌ |
| Sửa điểm chấm trực tiếp | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — kể cả SYS_ADMIN) |
| Cấu hình ngưỡng/trọng số scoring | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (triển khai tham số do GDKD trình BOD duyệt, version hóa) |

**Lưu ý:** SM không được thẩm định/bypass deal do chính mình chốt hoặc có xung đột; kết quả thẩm định bắt buộc kèm lý do — nút lưu vô hiệu khi ô lý do trống.

---

## 5. Trường Hợp Đặc Biệt

- **Tier A nhưng thuộc nhánh tư vấn (K4):** khách đòi ứng tiền chạy trước bị AUTO LOST theo knockout, trừ trường hợp chỉ cần tư vấn quy trình — web hiển thị nhánh "tư vấn" riêng để SE chọn đúng hướng xử lý thay vì kết thúc lead nhầm.
- **Đề xuất knockout AML/FATF (chưa chốt):** sales.md đề xuất thêm K5-variant "FATF high-risk / chế tài quốc tế / UBO không xác thực được" nối BR-FIN-403/404 — đang `[CẦN CHỐT SỐ]` chờ policy Lead Scoring; thiết kế rule engine phải cho phép thêm/bớt knockout bằng cấu hình, không chôn cứng danh sách K1–K5 trong code.
- **Danh sách K6–K12 chưa đầy đủ `[KXN-20]`:** nguồn chỉ ví dụ 4 cờ (brand lớn, CEO gặp gấp, nhảy ≥3 agency/12 tháng, timeline gấp <2 tuần); rule engine phải hỗ trợ mở rộng cờ bằng cấu hình khi khách hàng chốt danh sách, không yêu cầu đổi code.
- **Lead borderline D treo do SM vắng:** sau 4h tự escalate GDKD; GDKD vắng (vai quy hoạch, BOD kiêm nhiệm) → phép kiêm nhiệm bảo đảm có người quyết theo mã vai.
- **Chấm lại nhiều lần do dữ liệu chán:** mỗi lần bổ sung dữ liệu chỉ kích hoạt đúng 1 lần chấm lại có audit log; với lead cũ ≤180 ngày tổng số lần chấm lại giới hạn đúng 1 lần (BR-SALES-103) — web phải hiển thị quỹ chấm lại còn lại.
- **Khách BOD-sponsored:** gắn nhãn riêng (label) hiển thị trên hồ sơ nhưng tier vẫn chấm bình thường — nhãn không thay được qualifiedTier vì Gate 1 cần tier hợp lệ.
- **Xung đột dữ liệu giữa brief sơ bộ và Full Brief:** qualifiedTier (chấm sau) ghi đè autoScore (chấm trước) làm tier vận hành; autoScore giữ lại làm lịch sử quyết bypass — web hiển thị cả hai với nhãn rõ "sơ bộ" / "chốt".

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Bản ghi scoring của lead (`scoring_records` — tách khỏi stage pipeline).

**Sơ đồ trạng thái:**
```
[NOT_SCORED] ──(brief sơ bộ đủ 3 trường)──► [SCORING_L1]
   SCORING_L1 ──(knockout K1–K5 fail)──► [AUTO_LOST]
   SCORING_L1 ──(thiếu ≥2/5 CQ)──► [INSUFFICIENT_DATA] ──(bổ sung dữ liệu)──► SCORING_L1
   SCORING_L1 ──(flag K6–K12)──► [FLAGGED_SM_REVIEW] (4h) ──► SCORING_L1
   SCORING_L1 ──(chấm xong)──► [AUTO_SCORED] (tier sơ bộ A–E)
   AUTO_SCORED ──(Full Brief 8 sections)──► [SCORING_L2] ──(chấm xong)──► [QUALIFIED_TIER_SET]
   AUTO_SCORED tier D ──(SM thẩm định 4h)──► [QUALIFIED_TIER_SET | escalate GDKD]
   QUALIFIED_TIER_SET ──(SM ký Gate 1)──► [TIER_LOCKED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_SCORED` | Kích hoạt AUTO SCORING | `SCORING_L1` | Hệ thống | Brief sơ bộ đủ 3 trường (KXN-2) |
| `SCORING_L1` | Knockout fail | `AUTO_LOST` | Hệ thống | Lý do knockout ghi rõ (K1–K5); trừ nhánh tư vấn K4 |
| `SCORING_L1` | Thiếu dữ liệu | `INSUFFICIENT_DATA` | Hệ thống | Thiếu ≥2/5 tiêu chí CQ; cấm đoán điểm |
| `INSUFFICIENT_DATA` | Bổ sung dữ liệu + chấm lại | `SCORING_L1` | SALES_L2 (lead của mình) | Dữ liệu mới qua validation |
| `SCORING_L1` | Flag K6–K12 | `FLAGGED_SM_REVIEW` | Hệ thống | SLA SM review 4h |
| `SCORING_L1` | Chấm xong lần 1 | `AUTO_SCORED` | Hệ thống | Map tier theo ngưỡng 1.5/2.0/3.0/3.5 |
| `AUTO_SCORED` (D) | SM thẩm định | `QUALIFIED_TIER_SET` | SALES_L4 | SLA 4h; kèm lý do; quá hạn → GDKD |
| `AUTO_SCORED` | Nhận Full Brief + chấm lại | `QUALIFIED_TIER_SET` | Hệ thống | Full Brief 8 sections đủ (KXN-3) |
| `QUALIFIED_TIER_SET` | SM ký Gate 1 | `TIER_LOCKED` | SALES_L4 | Xem FEAT-ERP-CRM-004; khóa vĩnh viễn |

**Quy tắc:** `AUTO_LOST` và `TIER_LOCKED` là trạng thái kết thúc của scoring; `INSUFFICIENT_DATA`/`FLAGGED_SM_REVIEW` có SLA clock — quá hạn tự escalate; mọi chuyển trạng thái ghi audit log (hệ thống ghi nguồn: engine hay thẩm định của ai).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `scoring_records` | `lead_id`, `attempt_no`, `score_type` (autoScore/qualifiedTier), `cq_score`, `tier`, `state`, `scored_at`, `param_version_id` | FK → `leads`, `scoring_param_versions` | Append-only; chấm lại = record mới |
| `scoring_criteria_results` | `scoring_record_id`, `criterion_code` (K1–K12), `result`, `reason`, `data_refs[]` | FK → `scoring_records` | Lý do từng tiêu chí — nguồn hiển thị web |
| `scoring_param_versions` | `version`, `thresholds` (1.5/2.0/3.0/3.5), `cq_weights` (30/25/20/15/10), `knockouts[]`, `effective_from`, `approved_by` | — | Effective-dated; GDKD trình BOD duyệt |
| `scoring_review_queue` | `lead_id`, `queue_type` (flag/borderline), `assigned_to`, `sla_deadline`, `outcome`, `outcome_reason` | FK → `leads`, `users` | SLA 4h; quá hạn escalate GDKD |
| `lead_special_labels` | `lead_id`, `label` (partner-referral/bod-sponsored), `set_by` | FK → `leads` | Nhãn không thay thế qualifiedTier |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo — chi tiết ở Phase 5. Mỗi scenario map về REQ-SALES-003.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Knockout → AUTO LOST | Brief sơ bộ ghi nhận khách đòi cam kết KPI cứng (K2) | Máy chạy AUTO SCORING lần 1 | Trạng thái `AUTO_LOST` với lý do K2, không mở First Meeting, có audit log | [ ] |
| SC-002: Thiếu dữ liệu chặn chấm | Chỉ có 3/5 tiêu chí CQ đủ dữ liệu | Hệ thống chấm | Trạng thái `INSUFFICIENT_DATA`, không xuất tier, UI chỉ rõ 2 tiêu chí thiếu | [ ] |
| SC-003: Borderline D đúng SLA | Lead chấm được 3.2 (Tier D) | SM thẩm định trong 4h và quyết nhận | `QUALIFIED_TIER_SET` kèm lý do SM; nếu quá 4h → escalate GDKD tự động | [ ] |
| SC-004: Cấm sửa điểm tay | SM mở hồ sơ lead đã chấm | Tìm chức năng sửa điểm | Không tồn tại điểm nhập tay; chỉ có "bổ sung dữ liệu → chấm lại" với audit log | [ ] |
| SC-005: Chú giải tier nghịch trực giác | Lead mới mở màn hình scoring lần đầu | Xem tier E | Tooltip/chú giải hiển thị "E ≥3.5 — tốt nhất, SM được duyệt bypass" — nhãn render từ cấu hình, không hardcode | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (scoring engine ở CORE) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (hiển thị điểm, hàng đợi review) | `phase4-ux/bcerp-web/crm-pipeline/scoring-review.md` |
| Nguồn quy trình chi tiết | `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1 §2.2b) |
| Hằng số (tier, knockout, trọng số CQ) | `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1 §1–§2) |
