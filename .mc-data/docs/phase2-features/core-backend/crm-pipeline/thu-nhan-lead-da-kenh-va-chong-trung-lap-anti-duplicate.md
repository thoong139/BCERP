# Tính Năng: Thu nhận lead đa kênh & chống trùng lặp (anti-duplicate)

> **Dựa trên:** REQ-SALES-001 trong `phase1-business/departments/sales/sales.md` (Phần A)
> **Phân hệ:** CRM & Lead Pipeline V6.0 (SYS-CORE-BACKEND)
> **Module:** MOD-CRM-PIPELINE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1), `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/SYS-CORE-BACKEND/MOD-CRM-PIPELINE/[screen-group].md`, `phase5-implementation/tasks/SYS-CORE-BACKEND/MOD-CRM-PIPELINE/FEAT-CORE-CRM-001-impl.md`
>
> **ID:** FEAT-ID từ lane `core-backend--CRM-PIPELINE`, tương ứng `FEAT-[SYS]-[MOD]-[NNN]` theo quy tắc tạo ID. REQ-SALES-001 fan-out 2 hệ thống — bản này là bản riêng cho SYS-CORE-BACKEND; đối ứng SYS-BCERP-WEB là bản counterpart cùng REQ.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CRM-001 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-001 (Thu nhận lead đa kênh & chống trùng lặp — anti-duplicate) |
| Người dùng liên quan | SALES_L1 (nhập lead thô/cold data), SALES_L2 (referral, lead kênh số), SALES_L3 (SM — phân xử lead trùng), SALES_L4, SALES_L5 (GDKD — quyết khiếu nại), SYS_ADMIN (vận hành retry) |
| Độ ưu tiên | Cao (HIGH — MVP) |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | Không có phụ thuộc chéo module (cross-dependencies = không có). Là tính năng đầu chuỗi của module: FEAT-CORE-CRM-002/003 tiêu thụ bản ghi lead do tính năng này tạo |
| Ghi chú Expert (A7) | Chưa có điều chỉnh nào từ Expert Review được ghi nhận trong `sales.md` Mục A7 tại thời điểm lập spec (12/09/2026) — giữ nguyên nội dung Phần B do sales-expert review |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng lead-intake engine trên BCERP Core Backend (headless API/domain service): tiếp nhận lead từ 4 nhóm nguồn (landing page/webhook, Zalo OA, Fanpage/Messenger, referral/cold nhập tay), chuẩn hóa định danh, so khớp anti-duplicate với lead đang mở, gắn nhãn nguồn và đưa lead vào `RAW_DATA` của Pipeline V6.0 trong vài phút. Tính năng hiện thực nguyên tắc sống còn của Sales — **mọi lead phải nằm trên hệ thống** — và là nguồn sự thật để phân xử deal credit về sau (nối REQ-SALES-009).

**Phạm vi:**
- Bao gồm: domain service `LeadIntakeService` (API webhook 3 kênh số + API tạo lead thủ công do WEB gọi); chuẩn hóa định danh (SĐT E.164, email lowercase, domain bỏ `www`, MST); matching engine theo trọng số 4 trường; gắn tag nguồn + chiến dịch; gán SE tiếp nhận; hàng đợi retry khi webhook lỗi; bằng chứng hoạt động (email/call/meeting log) phục vụ phân xử; audit log bất biến + tenant isolation.
- Không bao gồm: form nhập tay/pipeline board trên WEB (counterpart SYS-BCERP-WEB); cấu hình kênh webhook thuộc SYS-INTEGRATION-GW (REQ-BOD-008 — nhu cầu Sales bắt đầu từ khi lead đã đổ về CORE); AUTO SCORING và xếp tier (FEAT-CORE-CRM-003); stage machine + phân bổ lead chính thức (FEAT-CORE-CRM-002); LOST management/nurturing (quy-trinh v1.1 file 06 §6).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-CORE-BACKEND: mọi story diễn ra qua headless API/domain service — WEB chỉ là client, CORE là nơi enforce business rule (không tin UI), mọi kết quả ghi audit log và cách ly theo tenant.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L1 | Gọi API tạo lead thô (chỉ tên + SĐT), hệ thống tự ghi nguồn `cold outreach` và tạo project ở `RAW_DATA` trong SLA 24h | Không bỏ sót lead đầu phễu — mọi KH bắt đầu từ đây |
| 2 | SALES_L2 | Khi nhập lead referral, hệ thống tự so khớp email/SĐT/website/MST và báo "trùng chắc chắn / tiềm năng / nghi vấn" kèm người ghi trước | Không tự ý vào trùng lead người khác, tránh tranh chấp credit về sau |
| 3 | Hệ thống (webhook consumer) | Tự tiếp nhận lead landing page/Zalo OA/Fanpage-Messenger trong vài phút, tag đúng nguồn + chiến dịch vào `RAW_DATA` | Kênh số không phụ thuộc nhập tay; cấm giữ lead trên Zalo cá nhân/Sheets |
| 4 | SALES_L3 (SM) | Nhận hàng đợi phân xử lead trùng (2 bên hòa bằng chứng) và quyết trong SLA 24h | Giải tranh chấp nguồn nhất quán, có audit log, không gộp/xóa tùy tiện |
| 5 | SALES_L5 (GDKD) | Nhận đơn khiếu nại kết quả phân xử, quyết cuối SLA 3 ngày làm việc, ghi audit log bất biến | Có cơ chế phản háng cuối khi phân xử SM chưa thuyết phục |
| 6 | SYS_ADMIN | Nhận alert khi hàng đợi retry vượt ngưỡng, xem trạng thái từng kênh tiếp nhận | Can thiệp trước khi lead kênh số rơi vĩnh viễn — không mất lead là ràng buộc tuyệt đối |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, enforce ở tầng service của Core Backend (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | **Hard gate "không ghi nhận = không tồn tại" (Pipeline V6.0):** mọi lead phải có bản ghi trên hệ thống trước khi phát sinh hệ quả (chuyển stage, vận hành, hoa hồng); lead chỉ tồn tại trên Zalo cá nhân/Sheets không được công nhận; mọi ngoại lệ phải có phê duyệt + audit log bất biến | API từ chối mọi nghiệp vụ downstream đối với lead không có bản ghi; báo cáo pipeline không đếm lead ngoài hệ thống |
| BR-SALES-101 | **Anti-duplicate 4 kênh theo trọng số:** chuẩn hóa rồi so khớp với lead đang mở theo SĐT (E.164), email (lowercase), domain website (bỏ `www`), MST. Khớp ≥2/4 trường → **trùng chắc chắn** (flag cứng); khớp 1 trường định danh mạnh (SĐT/email/MST) → **trùng tiềm năng** (flag review); chỉ khớp tên công ty (fuzzy) → **nghi vấn** `[CẦN CHỐT SỐ — ngưỡng fuzzy + bảng trọng số chốt khi thiết kế rule engine]`. Lead trùng bị flag kèm người ghi trước + bằng chứng hoạt động — **không chặn mù** | Lead vẫn được ghi nhận nhưng ở trạng thái flag review; cấm tự động từ chối khi chưa qua so khớp |
| BR-SALES-102 | **Tranh chấp nguồn 3 bậc:** (1) người ghi trước có bằng chứng (email/call/meeting log) giữ lead; (2) hòa → SM phân xử SLA 24h; (3) khiếu nại → GDKD quyết cuối SLA 3 ngày làm việc; **cấm tự gộp/xóa lead trùng không qua phân xử** | API chặn merge/delete lead đang tranh chấp; quyết định gán người thắng phải ghi audit log kèm bằng chứng |
| BR-SALES-103 | **Kỷ luật nguồn + vòng đời lead cũ:** cấm giữ lead ngoài hệ thống; lead cũ quay lại ≤180 ngày giữ nguyên lịch sử scoring, được chấm lại đúng 1 lần với dữ liệu mới (nối FEAT-CORE-CRM-003) | API từ chối chấm lại lần thứ 2 trong cùng chu kỳ quay lại |
| BR-CRM-001-04 | **Tiếp nhận đa kênh có bảo chứng:** lead webhook vào `RAW_DATA` trong vài phút, tự gắn tag nguồn + chiến dịch; kênh webhook lỗi → hàng đợi retry, **không mất lead**; vượt ngưỡng retry `[CẦN CHỐT SỐ — số lần/tần suất chưa có chính sách; đề xuất 5 lần backoff luỹ thừa]` → alert SYS_ADMIN + SM. Gán SE tại RAW_DATA: kênh số auto theo quy tắc nguồn, lead tự do SM gán trong 4h giờ làm việc `[CẦN CHỐT SỐ — round-robin chưa ban hành; engine chính tại FEAT-CORE-CRM-002]`; hard gate RAW DATA = đã tạo project + đã ghi nguồn + đã assign SE | Payload lỗi lưu nguyên trạng vào retry queue, không drop silently; lead thiếu owner quá SLA vào hàng đợi cảnh báo SM → escalate |
| BR-CRM-001-05 | **Bối cảnh pipeline V6.0 (downstream — enforce tại FEAT-CORE-CRM-002/003/004):** 5 tier A–E, A <1.5 AUTO LOST → E ≥3.5 SM được bypass First Meeting (KXN-1); AUTO SCORING K1–K12 (K1–K5 knockout) chạy TRƯỚC First Meeting, `qualifiedTier` chốt sau Full Brief (KXN-2); Gate 1 SLA 1 ngày làm việc / Gate 2 nạp trước 100% NSQC + AM xác nhận SLA 4h, trọng số CQ theo tier 30/25/20/15/10; proposal theo tier: B/C = AM 8–12 trang ≤2 vòng, D/E = Planner 15–25 trang ≤4 vòng (KXN-8, chiều V6.0); rà soát tier theo quý (BR-SALES-503) và UPSELL theo quy-trinh v1.1 file 06 §8 tiêu thụ dữ liệu intake — intake chỉ bảo đảm dữ liệu nguồn sạch cho các chu trình này | Lead thiếu trường định danh tối thiểu không kích hoạt luồng scoring; hệ quả tier/gate không áp cho lead chưa qua intake chuẩn hóa |

---

## 4. Phân Quyền

| Hành động | SALES_L1 | SALES_L2 | SALES_L3 (SM) | SALES_L4/L5 | SYS_ADMIN |
|-----------|----------|----------|---------------|-------------|-----------|
| Xem lead của mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem lead nhóm/phòng/toàn Sales | ❌ | ❌ | ✅ (nhóm) | ✅ (phòng/toàn Sales) | ✅ |
| Tạo lead thủ công (API referral/cold) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem kết quả so khớp + bằng chứng hoạt động | ✅ (lead của mình) | ✅ (lead của mình) | ✅ | ✅ | ✅ |
| Phân xử lead trùng (SLA 24h) | ❌ | ❌ | ✅ | ✅ | ❌ |
| Khiếu nại / quyết cuối (SLA 3 ngày) | ❌ (gửi đơn) | ❌ (gửi đơn) | ❌ | ✅ (GDKD quyết) | ❌ |
| Merge/gộp lead qua phân xử | ❌ | ❌ | ✅ | ✅ | ❌ |
| Xóa lead | ❌ | ❌ | ❌ | ❌ (chỉ qua luồng LOST có lý do + audit) | ❌ |
| Vận hành hàng đợi retry webhook | ❌ | ❌ | ❌ | ❌ | ✅ |

> Phân xử/duyệt đi qua approval service của CORE (nguồn sự thật duy nhất). SALES_L5 là vị trí quy hoạch, tạm BOD kiêm nhiệm — hệ thống duyệt theo mã vai `SALES_L5`, không theo người. Không tồn tại vai `OPS_CX`/`FIN_COMPL` (DI-006 bị stakeholder từ chối).

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Thông tin quá ít:** lead chỉ có tên + SĐT — SE tìm thêm qua MXH nhưng vẫn tạo project với info có sẵn; hard gate RAW DATA chỉ yêu cầu thông tin cơ bản + nguồn + owner, không chặn lead nghèo dữ liệu.
- **Hai sales nhập cùng lúc một khách (race):** matching chạy trước commit; nếu cả hai qua gần đồng thời, bản ghi sau vào trạng thái tranh chấp theo BR-SALES-102 — hệ thống idempotent theo cặp (tenant, định danh chuẩn hóa).
- **Lead cũ quay lại ≤180 ngày:** không tạo lead mới thuần — nối lịch sử scoring cũ, chấm lại đúng 1 lần; quá 180 ngày xử lý như lead mới.
- **Khách đối tác (Google/TikTok/Yandex) giới thiệu:** tag `partner_referral` riêng nhưng **không được bypass** anti-duplicate hay scoring.
- **Biến thể định danh:** SĐT khác format (+84), email hoa thường, website có/không `www` — so khớp trên bản chuẩn hóa, không so raw string; MST là trường mạnh nhất khi có.
- **Webhook lỗi kéo dài:** payload lưu nguyên trạng theo thứ tự nhận, có dead-letter kèm nguyên nhân; chỉ SYS_ADMIN nạp lại sau khi sửa kết nối — không tự discard.
- **Nhân viên nghỉ việc:** lead được chuyển quản lý có audit log, không xóa (không để mất pipeline).
- **Khách BOD-sponsored:** gắn nhãn riêng để theo dõi nhưng intake áp đầy đủ anti-duplicate và luồng chuẩn — không có cửa riêng nhập ngoài hệ thống kể cả với cấp quản lý.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity: Lead ở bước tiếp nhận. Stage pipeline đầy đủ V6.0 (RAW_DATA → … → QUALIFIED → bàn giao) thuộc FEAT-CORE-CRM-002; ở đây mô tả lớp trạng thái intake/anti-duplicate phủ lên điểm vào `RAW_DATA`.*

**Entity:** Lead (bản ghi tiếp nhận khách hàng tiềm năng)

**Sơ đồ trạng thái:**
```
[PENDING_INTAKE] ──(webhook OK / tạo tay OK)──► [RAW_DATA] ──(matching engine)──► [CLEAN_NEW] ──(assign SE)──► sang stage machine (FEAT-002)
     ▲                                                                                        │
     │ (webhook lỗi → retry queue)                                                            ▼
[RETRY_QUEUE] ──(vượt ngưỡng)──► [DEAD_LETTER + alert]                    [DUP_CONFIRMED] [DUP_POTENTIAL] [DUP_SUSPECT]
                                                                                 │ (BR-SALES-102: SM 24h / GDKD 3 ngày)
                                                                                 ▼
                                                              [MERGED_INTO_LEAD] hoặc [CONFIRMED_NEW]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING_INTAKE` | Webhook/tạo tay thành công | `RAW_DATA` | Hệ thống / SALES_L1, L2 | Đủ trường tối thiểu (tên công ty, người liên hệ, email/SĐT, nguồn lead); tag nguồn đã gắn |
| `PENDING_INTAKE` | Webhook lỗi | `RETRY_QUEUE` | Hệ thống | Payload lưu nguyên trạng, theo thứ tự nhận |
| `RETRY_QUEUE` | Retry thành công / vượt ngưỡng | `RAW_DATA` / `DEAD_LETTER` | Hệ thống | Retry ghi số lần; dead-letter alert SYS_ADMIN + SM, chỉ SYS_ADMIN nạp lại |
| `RAW_DATA` | Matching engine chạy | `CLEAN_NEW` / `DUP_CONFIRMED` / `DUP_POTENTIAL` / `DUP_SUSPECT` | Hệ thống | ≥2/4 trường → confirmed; 1 trường mạnh → potential; fuzzy tên → suspect |
| `DUP_CONFIRMED` / `DUP_POTENTIAL` | Phân xử (BR-SALES-102) | `MERGED_INTO_LEAD` hoặc `CONFIRMED_NEW` | SALES_L3 (SM); khiếu nại → SALES_L5, SLA 24h / 3 ngày làm việc | Kèm bằng chứng + lý do, audit log bất biến |
| `MERGED_INTO_LEAD` | — | Kết thúc (bản ghi lưu vĩnh viễn, không xóa) | — | Giữ liên kết tới lead chính làm bằng chứng deal credit |
| `CONFIRMED_NEW` | Assign SE | Chuyển stage machine pipeline (FEAT-CORE-CRM-002) | SM hoặc auto-assign | Hard gate RAW DATA đạt |

**Quy tắc:**
- Không trạng thái nào cho phép xóa vật lý — mọi "loại" là trạng thái kết thúc kèm lý do (nối LOST Management, 4 nhóm A/B/C/D `[KXN-17 — định nghĩa chi tiết còn mở, dùng enum đề xuất file 09 §8]`).
- `MERGED_INTO_LEAD`/`REJECTED_DUPLICATE` là trạng thái kết thúc của bản ghi trùng — giữ vĩnh viễn làm bằng chứng phân xử.
- Mọi chuyển trạng thái ghi audit log bất biến (actor, thời điểm, lý do); tenant isolation bắt buộc trên toàn bộ truy vấn.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `lead` | `company_name`, `contact_name`, `email_std`, `phone_e164`, `website_domain`, `tax_code`, `source_channel`, `campaign_tag`, `stage`, `owner_id`, `dup_state`, `tenant_id` | FK → `users.id` (owner) | Cấm soft delete; chuẩn hóa tại service layer trước khi lưu |
| `lead_source_event` | `lead_id`, `channel`, `campaign`, `received_at`, `raw_payload_ref` | FK → `lead.id` | Bằng chứng nguồn cho phân xử |
| `duplicate_match` | `lead_id`, `matched_lead_id`, `matched_fields`, `match_score`, `match_class` | FK → `lead.id` ×2 | Sinh bởi matching engine, feed hàng đợi review |
| `duplicate_dispute` | `match_id`, `claimant_id`, `respondent_id`, `evidence_refs`, `arbitration_level`, `decision`, `decided_at` | FK → `duplicate_match.id` | SLA 24h (SM) / 3 ngày làm việc (GDKD); audit bất biến |
| `webhook_retry_queue` | `channel`, `payload_ref`, `retry_count`, `next_retry_at`, `status`, `error` | Liên kết lỏng `lead_id` | Dead-letter chỉ SYS_ADMIN thao tác |
| `lead_activity_log` | `lead_id`, `type` (email/call/meeting), `actor_id`, `occurred_at` | FK → `lead.id` | Bằng chứng "người ghi trước có bằng chứng" |
| `audit_log` | `entity`, `entity_id`, `actor_id`, `action`, `before/after`, `at` | Polymorphic | WORM — bắt buộc mọi chuyển trạng thái |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2, chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-SALES-001.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Webhook lead landing page | Kênh webhook hoạt động | Landing page đẩy lead mới qua API | Lead xuất hiện ở `RAW_DATA` trong vài phút, tag nguồn + chiến dịch đúng, audit log đầy đủ | [ ] |
| SC-002: Trùng chắc chắn | Lead mở của sales A khớp ≥2/4 trường | Sales B tạo lead cùng khách | Flag "trùng chắc chắn" + người ghi trước + bằng chứng; không chặn mù, chuyển `DUP_CONFIRMED` chờ phân xử | [ ] |
| SC-003: Phân xử 3 bậc | Hai sales cùng claim, hòa bằng chứng | SM ra quyết; khiếu nại nộp lên GDKD | Quyết SM SLA 24h có audit; khiếu nại GDKD quyết cuối SLA 3 ngày làm việc; merge không qua phân xử bị chặn | [ ] |
| SC-004: Webhook lỗi không mất lead | Kênh Zalo OA lỗi | Payload đến khi kênh lỗi | Lead vào `RETRY_QUEUE`, retry tự động; vượt ngưỡng `[CẦN CHỐT SỐ]` → alert SYS_ADMIN + SM; không payload nào bị discard | [ ] |
| SC-005: Lead cũ quay lại ≤180 ngày | Lead LOST có lịch sử scoring | Lead quay lại | Giữ lịch sử scoring cũ, chấm lại đúng 1 lần; lần chấm thứ 2 bị API từ chối | [ ] |
| SC-006: Cấm gộp/xóa tùy tiện | Lead đang tranh chấp | Nhân sự gọi API merge/delete trực tiếp | API từ chối; chỉ merge qua quyết định phân xử có audit log | [ ] |

> **Liên kết:** SC-001…SC-006 map về REQ-SALES-001 (tiếp nhận đa kênh, anti-duplicate không chặn mù, tranh chấp 3 bậc, retry không mất lead, vòng đời lead cũ).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) lead, duplicate_match, dispute, retry queue | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (LeadIntakeService, webhook consumer, arbitration) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (GW webhook, WEB form, MOBILE push) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI kênh WEB (counterpart) | `phase4-ux/SYS-BCERP-WEB/MOD-CRM-PIPELINE/[screen-group].md` |
| Nghiệp vụ gốc & business rules đầy đủ | `phase1-business/departments/sales/sales.md` (B.1), `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` §2.1 |
| Tính năng nối tiếp trong module | FEAT-CORE-CRM-002 (stage machine), FEAT-CORE-CRM-003 (scoring) |
