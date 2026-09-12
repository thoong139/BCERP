# Tính Năng: Thu nhận lead đa kênh & chống trùng lặp (anti-duplicate)

> **Dựa trên:** REQ-SALES-001 trong `phase1-business/departments/sales/sales.md` (Phần A + Phần B — Sales Expert Review)
> **Phân hệ:** CRM & Lead Pipeline V6.0 (SYS-BCERP-WEB)
> **Module:** CRM Pipeline (MOD-CRM-PIPELINE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase1-business/P1-02-business-workflow.md`, `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1), `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/crm-pipeline/lead-intake.md`, `phase5-implementation/tasks/bcerp-web/crm-pipeline/feat-erp-crm-001-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-CRM-001 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-001 |
| Người dùng liên quan | SALES_L1 (Intern), SALES_L2 (NVKD/SE), SALES_L3 (TNKD), SALES_L4 (TPKD/SM — phân xử), SALES_L5 (GDKD — quyết khiếu nại) |
| Độ ưu tiên | Cao (HIGH — MVP) |
| Giai đoạn | Giai đoạn 1 |
| Phụ thuộc | Không có cross-dependency chặn; engine so khớp thực thi tại SYS-CORE-BACKEND (counterpart cùng REQ-ID) |
| Ghi chú Expert (A7) | Mục A7 của sales.md đang chờ điền; spec kế thừa kết quả Sales Expert Review Phần B (12/09/2026): anti-duplicate theo trọng số 4 trường định danh, phân xử 3 cấp có SLA, kỷ luật nguồn + chấm lại lead cũ ≤180 ngày đúng 1 lần |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng tiếp nhận lead từ 4 kênh (landing page qua webhook, Zalo OA, Fanpage/Messenger, referral/cold data nhập tay) vào stage `RAW_DATA` của pipeline V6.0 trong vòng vài phút, đồng thời chạy chống trùng lặp (anti-duplicate) theo trọng số 4 trường định danh để mọi lead chỉ có một chủ sở hữu hợp lệ. Đây là cổng vào của nguyên tắc sống còn "không ghi nhận = không tồn tại" (KXN-1 đã chốt): lead không nằm trên hệ thống thì không được vận hành và không được tính credit hoa hồng.

**Phạm vi:**
- Bao gồm: form nhập tay lead referral/cold data với trường bắt buộc tối thiểu (tên công ty, người liên hệ, email/SĐT, nguồn lead); hiển thị kết quả so khớp trùng/mới kèm người ghi trước và bằng chứng hoạt động (email/call/meeting log); hàng đợi phân xử lead trùng cho SM (SLA 24h) và GDKD (khiếu nại, SLA 3 ngày làm việc); lịch sử hoạt động lead; gắn nhãn nguồn + chiến dịch; trạng thái hàng đợi retry khi kênh webhook lỗi; SLA 24h tạo project.
- Không bao gồm: cấu hình kênh webhook lead (thuộc Settings & Integration Gateway — REQ-BOD-008, vai SYS_ADMIN); scoring engine K1–K12 và xếp tier (FEAT-ERP-CRM-003); pipeline board và chuyển stage (FEAT-ERP-CRM-002); tính credit cho lead thắng phân xử (REQ-SALES-009).

**Đặc thù touchpoint SYS-BCERP-WEB:**
Web nội bộ responsive (Next.js) cho nhân viên BC — kênh nhập tay duy nhất cho lead referral/cold data (mobile nội bộ chỉ nhận push lead mới, không nhập lead). Logic nghiệp vụ (chuẩn hóa, so khớp, khóa quyết định phân xử, audit log) thực thi ở service layer của SYS-CORE-BACKEND; web gọi API core, hiển thị đúng trạng thái machine-state (mới / trùng chắc chắn / trùng tiềm năng / đang tranh chấp / đã giải quyết), vô hiệu hóa nút khi chưa đủ trường bắt buộc, không xử lý xung đột ở tầng client.

**Fan-out:**
REQ-SALES-001 xuất hiện ở 2 systems — đây là bản riêng cho SYS-BCERP-WEB; counterpart: SYS-CORE-BACKEND (primary — matching engine, hàng đợi retry, audit log). Spec này chỉ mô tả phần giao diện và thao tác thuộc web nội bộ.

**Nguồn quy trình:** `documents/quy-trinh-lam-viec/` v1.1 — 11 KXN đã chốt (KXN-1, 2, 3, 4, 5, 8, 10, 11, 12, 13, 14); 11 khoản còn mở (6, 7, 9, 15–22) được ghi trong spec như assumption có tag `[KXN-n]` hoặc `[CẦN CHỐT SỐ]`, không tự quyết.

---

## 2. Luồng Người Dùng (User Stories)

Luồng điển hình: lead từ 3 kênh số (landing page, Zalo OA, Fanpage/Messenger) tự vào stage `RAW_DATA` với tag nguồn + chiến dịch; lead referral/cold do nhân viên kinh doanh nhập tay trên web nội bộ. Hệ thống chuẩn hóa 4 trường định danh rồi so khớp với các lead đang mở; kết quả so khớp quyết định lead đi thẳng vào pipeline hay bị flag vào hàng đợi phân xử.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L1 (Intern) | Nhập lead thô/cold data qua form tối thiểu 4 trường và được hệ thống báo ngay kết quả so khớp trùng/mới | Không tạo trùng và không mất thời gian nhập lead đã có người quản |
| 2 | SALES_L2 (NVKD/SE) | Xem lịch sử hoạt động đầy đủ của lead mình (email/call/meeting log) kèm bằng chứng ghi trước | Bảo vệ quyền sở hữu lead khi có tranh chấp và chuẩn bị Initial Brief đúng SLA 2h |
| 3 | SALES_L2 (NVKD/SE) | Được cảnh báo khi lead cũ (≤180 ngày) quay lại để tái sử dụng lịch sử scoring | Không phải chấm lại từ đầu và không khai thác lại thông tin khách từ zero |
| 4 | SALES_L3 (TNKD) | Theo dõi lead mới của nhóm và nhận đẩy thông báo khi lead được gán/bị flag trùng | Hỗ trợ thành viên xử lý kịp thời trước khi quá SLA tạo project 24h |
| 5 | SALES_L4 (TPKD/SM) | Có hàng đợi phân xử lead trùng với bằng chứng hai bên và SLA 24h | Quyết công bằng, có vết, đúng hạn — không bị kẹt tranh chấp làm tắc pipeline nhóm |
| 6 | SALES_L5 (GDKD) | Nhận đơn khiếu nại sau bước SM với đầy đủ audit log và quyết cuối trong SLA 3 ngày làm việc | Chấm dứt tranh chấp cấp cao và giữ niềm tin vào phân bổ lead của phòng |
| 7 | SALES_L4 (TPKD/SM) | Nhận cảnh báo khi một lead nằm ngoài hệ thống (webhook lỗi ở hàng đợi retry) để can thiệp | Không để lead "chết im" trong queue mà không ai biết |

---

## 3. Quy Tắc Nghiệp Vụ

Sáu nhóm quy tắc bắt buộc của lane (đã chốt tại quy-trinh v1.1) áp dụng cho tính năng này; nhóm trọng tâm là anti-duplicate và phân bổ lead. Developer phải xử lý đúng từng dòng trong bảng dưới; phần thực thi engine nằm ở SYS-CORE-BACKEND, web phản ánh đúng kết quả.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | Hard gate "không ghi nhận = không tồn tại" (KXN-1): mọi lead phải có bản ghi trên hệ thống trước khi phát sinh hệ quả (gán owner, scoring, credit); cấm giữ lead trên Zalo cá nhân/Sheets; pipeline V6.0 có 5 tier A–E do scoring quyết (chi tiết FEAT-ERP-CRM-003) | Chặn 2 tầng: UI vô hiệu hóa thao tác + API từ chối request; lead ngoài hệ thống không được gán owner, không vào pipeline |
| BR-SALES-101 | Anti-duplicate 4 kênh theo trọng số: chuẩn hóa SĐT (E.164), email (lowercase), domain website (bỏ www), MST rồi so khớp với lead đang mở. Khớp ≥2/4 trường → trùng chắc chắn (flag cứng); khớp 1 trường định danh mạnh (SĐT/email/MST) → trùng tiềm năng (flag review); chỉ khớp tên công ty fuzzy → nghi vấn `[CẦN CHỐT SỐ — ngưỡng fuzzy và bảng trọng số chốt khi thiết kế rule engine]` | Lead bị flag kèm người ghi trước + bằng chứng hoạt động — không chặn mù; cấm tự gộp/xóa lead trùng không qua phân xử |
| BR-SALES-102 | Phân xử tranh chấp 3 cấp: (1) người ghi trước có bằng chứng (email/call/meeting log) giữ lead; (2) hòa → SM (SALES_L4) phân xử SLA 24h; (3) khiếu nại → GDKD (SALES_L5) quyết cuối SLA 3 ngày làm việc; mọi quyết định ghi audit log bất biến | Quá SLA → escalate tự động cấp trên; quyết định không có audit log bị coi là vô hiệu |
| BR-SALES-103 | Kỷ luật nguồn: lead từ 3 kênh số tự gắn tag nguồn + chiến dịch và vào `RAW_DATA`; SLA nhận thông tin → 24h phải tạo project, không gia hạn; kênh webhook lỗi → hàng đợi retry, không mất lead, retry vượt ngưỡng `[CẦN CHỐT SỐ — số lần/tần suất]` → alert SYS_ADMIN + SM | Trễ 24h → cảnh báo rồi escalate cấp trên trực tiếp; lead trong retry queue hiển thị trạng thái rõ để không ai quên |
| BR-SALES-203 | Phân bổ lead theo quy tắc + escape hatch: lead kênh tự gán owner theo kênh chủ quản; lead tự do → SM gán trong SLA 4h giờ làm việc `[CẦN CHỐT SỐ — quy tắc round-robin chưa có chính sách ban hành; đề xuất 4h]` | Quá SLA gán → escalate; lead không owner quá hạn bị đưa lên hàng đợi SM |
| BR-SALES-301/302 | AUTO SCORING K1–K12 (K1–K5 knockout) chạy trước First Meeting, chấm lại `qualifiedTier` sau Full Brief (KXN-2); lead cũ quay lại ≤180 ngày giữ nguyên lịch sử scoring và được chấm lại đúng 1 lần với dữ liệu mới | Trùng tiềm năng chưa giải quyết không được đưa vào scoring; chấm lại lần 2 với lead cũ bị chặn ở tầng API |
| BR-SALES-401/402 | Gate 1 (SLA 1 ngày làm việc) / Gate 2 (Handoff Package 5 nhóm đủ 100%, AM xác nhận SLA 4h) — Go/No-Go; hệ quả CQ theo tier 30/25/20/15/10; proposal theo tier B/C = AM 8–12 trang ≤2 vòng, D/E = Planner 15–25 trang ≤4 vòng (KXN-8, chiều V6.0); rà soát tier theo quý; UPSELL theo quy-trinh v1.1 file 06 §8 | Lead chưa qua anti-duplicate không có dữ liệu đầu vào hợp lệ cho Gate 1; các ràng buộc này thuộc các FEAT kế tiếp (002–005) nhưng nhận đầu vào từ lead đã sạch trùng |

**Quy tắc bổ sung:** thứ tự ưu tiên khi trùng được hardcode theo BR-SALES-102 — cấm nhân viên tự thống nhất ngoài hệ thống rồi nhập kết quả; kết quả phân xử chốt ownership nhưng không xóa lịch sử bên kia (dữ liệu giữ nguyên để phục vụ audit và tính credit sau này).

---

## 4. Phân Quyền

Phân quyền tuân theo 18 vai registry (không dùng OPS_CX/FIN_COMPL). Nguyên tắc: ai cũng được nhập lead (cần lead là tài sản của phòng), nhưng quyền "giải quyết" trùng luôn nằm ở cấp quản lý theo 3 cấp phân xử — nhân viên không có nút gộp/xóa lead dưới mọi hình thức.

| Hành động | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4 (SM) | SALES_L5 (GDKD) | SYS_ADMIN |
|-----------|----------|----------|----------|---------------|-----------------|-----------|
| Xem lead của mình | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem tất cả lead phòng/toàn Sales | ❌ | ❌ | ✅ (nhóm) | ✅ (phòng) | ✅ (toàn Sales) | ❌ |
| Nhập lead tay (referral/cold) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem kết quả so khớp + bằng chứng | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Gán owner lead tự do (trong SLA 4h) | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Phân xử lead trùng (cấp SM, SLA 24h) | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Quyết khiếu nại (cấp GDKD, SLA 3 ngày) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Gộp/xóa lead trùng | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (chỉ qua ticket phân xử đã chốt + audit log) |
| Xem hàng đợi retry webhook | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |

**Lưu ý:** SM không được tự phân xử tranh chấp có mình là đương sự — khi SM là người ghi một trong hai lead trùng, hệ thống tự đẩy lên GDKD; SYS_ADMIN chỉ can thiệp dữ liệu sau khi có quyết định phân xử đã chốt, mọi thao tác ghi audit log bất biến.

---

## 5. Trường Hợp Đặc Biệt

Các tình huống ngoại lệ dưới đây bắt buộc phải xử lý tường minh trong thiết kế — đây là những điểm từng gây mất lead hoặc tranh chấp credit khi vận hành thủ công.

- **Lead trùng được hai người ghi gần như đồng thời:** so khớp theo thời điểm commit bản ghi; vì "hòa" nên đưa thẳng vào hàng đợi SM (SLA 24h) thay vì áp ưu tiên người ghi trước — người ghi sau vẫn thấy trạng thái "đang tranh chấp" để không tiếp tục khai thác.
- **Lead cũ quay lại trong ≤180 ngày:** giữ nguyên toàn bộ lịch sử scoring (autoScore, qualifiedTier, flags), cho phép chấm lại đúng 1 lần với dữ liệu mới; quá 180 ngày → coi như lead mới nhưng vẫn chạy anti-duplicate với lead đã LOST để cảnh báo "đã từng làm việc".
- **Webhook kênh lỗi (Zalo OA/Fanpage đổi API, landing page sự cố):** lead vào hàng đợi retry tại CORE, web hiển thị badge "chờ đồng bộ" kèm số lần retry; vượt ngưỡng `[CẦN CHỐT SỐ]` → alert SYS_ADMIN + SM; không yêu cầu nhập tay bù khi kênh có thể tự phục hồi (tránh sinh trùng khi retry thành công).
- **Thông tin quá ít không liên hệ được (chỉ tên + SĐT):** vẫn tạo project với thông tin có sẵn, ghi chú cần bổ sung; SE tìm thêm qua MXH — không chặn tạo lead vì thiếu email/website (4 trường tối thiểu, trong đó email/SĐT chọn một).
- **MST trùng nhưng là hai pháp nhân khác nhau:** khớp MST là "trùng tiềm năng" (1 trường mạnh) — SM review; nếu xác nhận khác thực thể, đánh dấu "không trùng có lý do" để máy không flag lại.
- **Khách do đối tác (Google/TikTok/Yandex) giới thiệu hoặc BOD-sponsored:** vẫn qua anti-duplicate bình thường; nhãn riêng chỉ ghi nhận nguồn referral, không quyền bypass scoring hay phân xử (khớp REQ-SALES-003).
- **Nhân viên nghỉ việc đang giữ lead:** chuyển toàn bộ lead/deal sang người khác có audit log, không xóa — lịch sử ghi trước vẫn bảo toàn cho tranh chấp tương lai.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lead (trạng thái anti-duplicate — tách khỏi stage pipeline, stage PMS do FEAT-ERP-CRM-002 quản).

**Sơ đồ trạng thái:**
```
[NEW] ──(so khớp: không trùng)──► [UNIQUE_ACTIVE]
   │
   ├─(khớp ≥2/4 trường)──► [DUPLICATE_HARD] ──(SM/GDKD phân xử)──► [DISPUTE_OPEN] ──► [RESOLVED]
   │
   ├─(khớp 1 trường mạnh)─► [DUPLICATE_POTENTIAL] ──(SM review)──► [RESOLVED | DISPUTE_OPEN]
   │
   └─(chỉ khớp tên fuzzy)─► [SUSPECTED] ──(người nhập xác nhận)──► [UNIQUE_ACTIVE | DUPLICATE_POTENTIAL]
                                    [DISPUTE_OPEN] ──(khiếu nại)──► [DISPUTE_FINAL_GDKD] ──► [RESOLVED_FINAL]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NEW` | Chạy so khớp tự động | `UNIQUE_ACTIVE` | Hệ thống | Không có trường nào khớp lead đang mở |
| `NEW` | Chạy so khớp tự động | `DUPLICATE_HARD` | Hệ thống | Khớp ≥2/4 trường định danh |
| `NEW` | Chạy so khớp tự động | `DUPLICATE_POTENTIAL` | Hệ thống | Khớp 1 trường mạnh (SĐT/email/MST) |
| `DUPLICATE_HARD` | Mở tranh chấp | `DISPUTE_OPEN` | SALES_L2+ (người ghi sau hoặc người ghi trước) | Ghi lý do + đính kèm bằng chứng |
| `DISPUTE_OPEN` | SM phân xử | `RESOLVED` | SALES_L4 (khác đương sự) | SLA 24h; chọn người thắng + lý do |
| `DISPUTE_OPEN` | Chuyển khiếu nại | `DISPUTE_FINAL_GDKD` | SALES_L5 | Có kết quả SM trước đó; SLA 3 ngày làm việc |
| `DISPUTE_FINAL_GDKD` | Quyết cuối | `RESOLVED_FINAL` | SALES_L5 | Lý do bằng văn bản + audit log |
| `DUPLICATE_POTENTIAL` | SM review xác nhận không trùng | `UNIQUE_ACTIVE` | SALES_L4 | Ghi lý do (VD: MST trùng nhưng khác pháp nhân) |

**Quy tắc:**
- `RESOLVED` và `RESOLVED_FINAL` là trạng thái kết thúc của tranh chấp — không quay lại; ownership chốt tại thời điểm này, không đổi trừ khi GDKD quyết qua kênh khiếu nại.
- Lead ở `DUPLICATE_HARD`/`DISPUTE_OPEN` không được chuyển stage pipeline, không đưa vào scoring, không gán owner mới — web vô hiệu hóa toàn bộ nút liên quan.
- Mọi chuyển trạng thái ghi audit log bất biến (ai, khi nào, căn cứ bằng chứng); cấm xóa trạng thái tranh chấp đã từng mở.

---

## 7. Tóm Tắt Entity (Quick Reference)

Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md` (SYS-CORE-BACKEND sở hữu, web chỉ gọi API).

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `leads` | `company_name`, `contact_name`, `email`, `phone_e164`, `website_domain`, `tax_code`, `source_channel`, `campaign_tag`, `dup_status`, `owner_id` | FK → `users.id` (owner) | Chuẩn hóa 4 trường định danh lúc lưu; soft delete |
| `duplicate_matches` | `lead_id`, `matched_lead_id`, `match_fields[]`, `match_weight`, `match_class` | FK → `leads` (cả 2 phía) | Log mọi lần so khớp, kể cả nghi vấn fuzzy |
| `lead_disputes` | `lead_id`, `claimant_id`, `evidence_refs[]`, `level` (SM/GDKD), `decision`, `decided_by`, `decided_at`, `reason` | FK → `leads`, `users` | Audit log bất biến; SLA clock 24h / 3 ngày |
| `lead_activity_log` | `lead_id`, `activity_type` (email/call/meeting/note), `actor_id`, `occurred_at`, `payload` | FK → `leads` | Là "bằng chứng hoạt động" cho BR-SALES-102 |
| `webhook_ingest_queue` | `channel`, `payload`, `retry_count`, `last_error`, `status` | FK → `leads` (sau khi ingest) | Không mất lead; alert vượt ngưỡng `[CẦN CHỐT SỐ]` |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo — chi tiết ở Phase 5. Mỗi scenario map về REQ-SALES-001 (Mục 2 của sales.md).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Lead kênh số tự vào pipeline | Kênh Zalo OA hoạt động bình thường | Khách để lại thông tin trên Zalo OA | Lead xuất hiện ở `RAW_DATA` trong vài phút, đúng tag nguồn + chiến dịch, SLA 24h tạo project bắt đầu chạy | [ ] |
| SC-002: So khớp trùng chắc chắn | Đã có lead đang mở với SĐT X | Nhập lead mới khớp SĐT X + domain website | Hệ thống flag `DUPLICATE_HARD`, hiển thị người ghi trước + bằng chứng, chặn gán owner | [ ] |
| SC-003: Phân xử 3 cấp đúng SLA | Hai lead bị flag trùng với bằng chứng ngang nhau | SM mở tranh chấp, quá 24h không quyết | Tự escalate lên GDKD, có audit log mốc quá hạn | [ ] |
| SC-004: Lead cũ quay lại ≤180 ngày | Lead A đã LOST 90 ngày trước với lịch sử scoring | A quay lại, được nhập lại | Hệ thống liên kết lịch sử cũ, cho phép chấm lại đúng 1 lần, chặn lần thứ 2 | [ ] |
| SC-005: Webhook lỗi không mất lead | Kênh Fanpage trả lỗi liên tục | Lead gửi vào trong thời gian lỗi | Lead nằm trong `webhook_ingest_queue` với retry tự động; sau khi kênh hồi phục, lead vào đúng `RAW_DATA` không trùng | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (fan-out SYS-CORE-BACKEND) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (form nhập lead, hàng đợi phân xử) | `phase4-ux/bcerp-web/crm-pipeline/lead-intake.md` |
| Nguồn quy trình chi tiết | `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1) |
| Hằng số quy trình (trọng số, SLA) | `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1) |
