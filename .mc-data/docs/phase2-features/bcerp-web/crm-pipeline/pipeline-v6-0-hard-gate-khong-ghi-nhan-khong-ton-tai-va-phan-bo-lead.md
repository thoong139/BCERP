# Tính Năng: Pipeline V6.0 — hard gate "không ghi nhận = không tồn tại" & phân bổ lead

> **Dựa trên:** REQ-SALES-002 trong `phase1-business/departments/sales/sales.md` (Phần A + Phần B — Sales Expert Review)
> **Phân hệ:** CRM & Lead Pipeline V6.0 (SYS-BCERP-WEB)
> **Module:** CRM Pipeline (MOD-CRM-PIPELINE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase1-business/P1-02-business-workflow.md`, `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1), `documents/quy-trinh-lam-viec/08_Ma_tran_RACI_Gate_SLA.md` (v1.1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/crm-pipeline/pipeline-board.md`, `phase5-implementation/tasks/bcerp-web/crm-pipeline/feat-erp-crm-002-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-CRM-002 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-002 |
| Người dùng liên quan | SALES_L1 (Intern), SALES_L2 (NVKD/SE), SALES_L3 (TNKD), SALES_L4 (TPKD/SM), SALES_L5 (GDKD) |
| Độ ưu tiên | Cao (HIGH — MVP) |
| Giai đoạn | Giai đoạn 1 |
| Phụ thuộc | Không có cross-dependency chặn; nhận lead đã qua anti-duplicate từ FEAT-ERP-CRM-001 (cùng module); stage machine thực thi tại SYS-CORE-BACKEND (counterpart cùng REQ-ID) |
| Ghi chú Expert (A7) | Mục A7 của sales.md đang chờ điền; spec kế thừa Sales Expert Review Phần B (12/09/2026): hard block 2 tầng UI + API, SLA clock từng gate kèm escalation, phân bổ lead theo quy tắc nguồn + SM gán trong SLA đề xuất 4h |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng cung cấp pipeline board — mặt làm việc hằng ngày của toàn bộ L1–L5 (L2 xem pipeline cá nhân, L3 nhóm, L4 phòng, L5 toàn Sales) — thể hiện đúng machine-state 10 stage V6.0 với điều kiện chuyển tiếp công khai, đồng thời thực thi hard gate "không ghi nhận = không tồn tại": cấm chuyển pha thiếu done criteria ở cả UI và API, mọi chuyển stage ghi audit log bất biến. Nguyên tắc này là điều kiện tiên quyết để hoa hồng không tranh chấp deal credit (BR-SALES-000).

**Phạm vi:**
- Bao gồm: pipeline board theo cá nhân/nhóm/phòng với 10 stage V6.0 (Raw Data → Initial Brief → AUTO SCORING → First Meeting → QUALIFIED → LEAD → EVALUATION → PROPOSAL → WON → DEPLOY) và chú giải điều kiện chuyển tiếp từng stage; nhập meeting notes; theo dõi SLA từng bước kèm cảnh báo + escalate quá hạn; kéo stage khi đủ điều kiện (done criteria machine-checkable); nhập Initial Brief 3 trường bắt buộc (Ngân sách, Sản phẩm/dịch vụ, Nhu cầu) trong SLA 2h; phân bổ lead mới (tự gán owner theo quy tắc nguồn/vùng hoặc SM gán trong SLA `[CẦN CHỐT SỐ — đề xuất 4h giờ làm việc]`); WON cập nhật trong 24h kèm tự sinh dự án + AM xác nhận capacity; escape hatch khách tái ký và deal hủy trước Gate 1.
- Không bao gồm: tiếp nhận và chống trùng lead (FEAT-ERP-CRM-001); tính toán điểm scoring và tier (FEAT-ERP-CRM-003 — web chỉ hiển thị kết quả); chữ ký Gate 1/Gate 2 và checklist Handoff (FEAT-ERP-CRM-004); luồng chuyển tier sang CS (FEAT-ERP-CRM-005); báo giá/hợp đồng (REQ-SALES-006/007).

**Đặc thù touchpoint SYS-BCERP-WEB:**
Web nội bộ responsive (Next.js) là touchpoint primary của REQ này (theo A0 sales.md). Nút kéo stage hiển thị điều kiện thiếu (checklist done criteria từng mục); khi thiếu điều kiện, nút vô hiệu hóa kèm lý do, và kể cả khi bị bypass ở client, API core vẫn từ chối request (chặn 2 tầng do CORE thực thi). Mobile nội bộ chỉ xem board + nhận cảnh báo SLA, không di chuyển stage trên di động. Hệ quả tier hiển thị trên board (CQ 30/25/20/15/10; proposal B/C = AM 8–12 trang ≤2 vòng, D/E = Planner 15–25 trang ≤4 vòng theo KXN-8) là dữ liệu đọc từ scoring, web không tự tính.

**Fan-out:**
REQ-SALES-002 xuất hiện ở 2 systems — đây là bản riêng cho SYS-BCERP-WEB; counterpart: SYS-CORE-BACKEND (stage machine, SLA clock, audit log, escalation engine). Spec này mô tả giao diện và thao tác thuộc web nội bộ.

**Nguồn quy trình:** `documents/quy-trinh-lam-viec/` v1.1 — trình tự PMS giữ theo v2.3 (RAW_DATA → BRIEF_SENT → FIRST_MEETING → BRIEF_RECEIVED → LEAD → QUALIFIED → ...), AUTO SCORING là bước hệ thống giữa BRIEF_SENT và FIRST_MEETING, không phải stage PMS riêng (KXN-2 đã chốt); 11 KXN còn mở (6, 7, 9, 15–22) ghi assumption có tag, không tự quyết.

---

## 2. Luồng Người Dùng (User Stories)

Sau khi lead đã sạch trùng và có owner (FEAT-ERP-CRM-001), nó đi qua chuỗi stage có SLA: Raw Data 24h tạo project → Initial Brief trong 2h với 3 trường bắt buộc → AUTO SCORING kích hoạt tự động → First Meeting trong 3 ngày làm việc (+2 ngày có lý do) → Brief Received đủ 8 mục trong 1 ngày → LEAD 1 ngày → QUALIFIED 1 ngày. Board phải cho người dùng nhìn thấy ngay deal nào đang trễ SLA để xử lý trước khi escalate.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L2 (NVKD/SE) | Nhìn pipeline cá nhân dạng board với từng stage, SLA còn lại và điều kiện chuyển tiếp | Biết deal nào cần hành động ngay hôm nay, không để deal chết vì quá hạn im lặng |
| 2 | SALES_L2 (NVKD/SE) | Kéo deal sang stage kế tiếp và nhận thông báo rõ mục done criteria còn thiếu | Không bỏ sót yêu cầu bắt buộc (notes, brief đủ 8 mục) và hiểu vì sao bị chặn |
| 3 | SALES_L2 (NVKD/SE) | Ghi meeting notes ngay sau First Meeting trên web | Meeting được công nhận (không notes = không công nhận) và BPVH có đầu vào soạn proposal |
| 4 | SALES_L3 (TNKD) | Xem pipeline nhóm và các cảnh báo SLA Initial Brief 2h quá hạn | Nhắc thành viên trước khi escalation tự động chạy tới cấp trên |
| 5 | SALES_L4 (TPKD/SM) | Gán owner cho lead tự do trong hàng đợi chờ gán và thấy SLA đếm ngược | Phân bổ công bằng, đúng hạn theo quy tắc + escape hatch, không bỏ sót lead |
| 6 | SALES_L4 (TPKD/SM) | Xem pipeline phòng với conversion rate từng stage và độ tuổi deal | Phát hiện điểm tắc phễu và điều chỉnh nhịp làm việc của phòng |
| 7 | SALES_L5 (GDKD) | Xem pipeline toàn Sales và báo cáo win rate theo tier | Điều chỉnh chỉ tiêu và trình BOD những điểm cần hiệu chỉnh chính sách (FEAT-ERP-CRM-005) |

---

## 3. Quy Tắc Nghiệp Vụ

Sáu nhóm quy tắc bắt buộc của lane áp dụng đầy đủ; nhóm trọng tâm là hard gate stage machine, SLA từng bước và phân bổ lead. Chặn 2 tầng là nguyên tắc xuyên suốt: UI vô hiệu hóa, API từ chối.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | Hard gate "không ghi nhận = không tồn tại" (KXN-1): mọi lead/deal/notes/chữ ký phải có bản ghi hệ thống trước khi phát sinh hệ quả; deal không có bản ghi trước Gate 2 không được vận hành và không được tính credit; 5 tier A–E (A <1.5 AUTO LOST → E ≥3.5 bypass) do scoring quyết | Chặn 2 tầng UI + API; xác nhận miệng của SM/GDKD không tạo giá trị pháp lý nội bộ |
| BR-SALES-201 | Stage machine 10 stage V6.0; hard block chuyển stage thiếu done criteria ở cả UI và API; audit log bất biến mọi chuyển stage; board hiển thị rõ điều kiện chuyển tiếp từng stage | Kéo stage thiếu điều kiện → nút vô hiệu + API trả lỗi liệt kê mục thiếu; mọi lần vượt rào bị log |
| BR-SALES-202 | Initial Brief SLA 2h từ Raw Data, đủ 3 trường bắt buộc Ngân sách / Sản phẩm-dịch vụ / Nhu cầu; quá hạn cảnh báo rồi escalate cấp trên trực tiếp; meeting notes bắt buộc trước QUALIFIED — không notes = meeting không được công nhận; WON cập nhật trong 24h → tự sinh dự án + AM xác nhận capacity (nối REQ-SALES-008) | Cảnh báo trên board, escalate tự động; stage QUALIFIED không mở khi chưa có notes; WON trễ 24h cảnh báo SM |
| BR-SALES-203 | Phân bổ lead: lead kênh tự gán owner theo quy tắc nguồn (kênh chủ quản); lead tự do → SM gán trong SLA 4h giờ làm việc `[CẦN CHỐT SỐ — SLA gán và quy tắc round-robin chưa có chính sách ban hành]`; tranh chấp nguồn giải theo FEAT-ERP-CRM-001 | Quá SLA → escalate GDKD; lead không owner hiển thị đỏ trên board phòng |
| BR-SALES-101/102/103 | Anti-duplicate 4 kênh và kỷ luật nguồn (FEAT-ERP-CRM-001): mọi lead trên board đều phải qua so khớp; SLA Raw Data 24h tạo project, Brief Sent 24h gửi form, First Meeting 3 ngày (+2 có lý do), Brief Received 1 ngày, LEAD 1 ngày, QUALIFIED 1 ngày | Lead chưa qua anti-duplicate không xuất hiện trên board chính thức; trễ SLA từng bước → alert rồi escalate |
| BR-SALES-301/302/303 | AUTO SCORING K1–K12 (K1–K5 knockout) chạy trước First Meeting (KXN-2); qualifiedTier chốt sau Full Brief 8 sections; CQ theo tier 30/25/20/15/10; tier D (3.0–3.49) borderline SM thẩm định SLA 4h quá hạn escalate GDKD | Stage không có tier hợp lệ không mở bước kế tiếp theo cấu hình; web chỉ hiển thị điểm + lý do, không sửa được |
| BR-SALES-401/402 | Gate 1 (SLA 1 ngày làm việc) / Gate 2 (Handoff Package 5 nhóm đủ 100% + SM ký + AM xác nhận SLA 4h; nạp trước 100% NSQC) — Go/No-Go; proposal theo tier B/C = AM 8–12 trang ≤2 vòng, D/E = Planner 15–25 trang ≤4 vòng (KXN-8); rà soát tier theo quý; UPSELL theo file 06 §8 | Stage WON không chuyển DEPLOY khi thiếu Gate 2; các chi tiết ký duyệt tại FEAT-ERP-CRM-004/005 |

**Quy tắc bổ sung:** SLA được +2 ngày cho First Meeting khi có lý do và lý do phải ghi vào PMS — web buộc nhập lý do trước khi hệ thống gia hạn; SLA clock tính theo giờ làm việc cấu hình ở CORE, web chỉ hiển thị.

---

## 4. Phân Quyền

Board là không gian chung nên quyền xem phân tầng theo cơ cấu (cá nhân → nhóm → phòng → toàn Sales); quyền thay đổi dữ liệu giới hạn ở owner và cấp quản lý; không ai — kể cả quản lý — được chuyển stage hộ mà không qua done criteria.

| Hành động | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4 (SM) | SALES_L5 (GDKD) | SYS_ADMIN |
|-----------|----------|----------|----------|---------------|-----------------|-----------|
| Xem pipeline của mình | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem pipeline nhóm/phòng/toàn Sales | ❌ | ❌ | ✅ (nhóm) | ✅ (phòng) | ✅ (toàn Sales) | ❌ |
| Nhập Initial Brief / meeting notes (deal của mình) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Kéo stage khi đủ done criteria (deal của mình) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Gán/đổi owner lead | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Chuyển stage deal của người khác | ❌ | ❌ | ❌ | ✅ (có audit log + lý do) | ✅ | ❌ |
| Cấu hình SLA/escalation ngưỡng | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (theo tham số GDKD trình BOD) |
| Xem audit log chuyển stage | ❌ | ❌ | ✅ (nhóm) | ✅ | ✅ | ✅ |

**Lưu ý:** nhân viên nghỉ việc → chuyển quản lead/deal có audit log, không xóa (khớp A6 sales.md); GDKD là vị trí quy hoạch tạm BOD kiêm nhiệm nên các quyền L5 thực thi theo mã vai, không theo người.

---

## 5. Trường Hợp Đặc Biệt

- **Khách tái ký (đã từng WON):** được rút gọn Initial Brief (tận dụng dữ liệu cũ) nhưng không được bỏ Gate 1/Gate 2 — hệ thống giữ nguyên 2 gate, chỉ nới SLA nhập brief; mọi rút gọn khác phải GDKD duyệt và ghi audit log.
- **Deal hủy trước Gate 1:** chỉ lưu hồ sơ (không xóa), gắn lý do hủy; không tính vào conversion rate của stage kế tiếp nhưng vẫn hiển thị trong lịch sử nhân viên.
- **First Meeting quá SLA vì khách bận:** SE được +2 ngày có lý do (ghi PMS); sau +2 ngày vẫn không gặp được với Tier B/C → thử lại 1 lần rồi LOST → nurturing list theo LOST Management (file 06 §6).
- **WON trễ cập nhật:** quá 24h không update → cảnh báo SM; hệ quả dây chuyền là đồng hồ D-day Deploy trễ — WON phải chốt bằng hành động trên web, không tính thông báo Zalo.
- **Capacity trống = 0 tại thời điểm sắp WON:** cảnh báo GDKD + OPS_PLAN trước khi ký Gate 2 (tránh ký deal không người chạy) — board hiển thị badge capacity đọc từ CORE.
- **Lead trùng phát hiện sau khi đã vào pipeline:** tạm khóa stage chuyển của lead mới cho đến khi phân xử xong (FEAT-ERP-CRM-001); lead cũ không bị ảnh hưởng.
- **Gia hạn SLA trái quy tắc:** hệ thống chỉ cho phép gia hạn tại các bước được quy định (First Meeting +2 ngày; Negotiation theo quy trình BPVH) — các bước "không gia hạn" không có nút gia hạn ở bất kỳ vai nào.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Deal/Lead trên pipeline (stage PMS — trình tự v2.3 được giữ; AUTO SCORING là bước hệ thống, không phải stage riêng — KXN-2).

**Sơ đồ trạng thái:**
```
[RAW_DATA] ──(24h tạo project, 3 trường đủ)──► [BRIEF_SENT] ──(AUTO SCORING kích hoạt)──► [FIRST_MEETING]
   FIRST_MEETING ──(Tier B/C: gặp bắt buộc | Tier D/E: SM duyệt bypass 4h)──► [BRIEF_RECEIVED]
   BRIEF_RECEIVED ──(đủ 8 mục, 1 ngày)──► [LEAD] ──(1 ngày, tier xếp xong)──► [QUALIFIED]
   QUALIFIED ──(Gate 1 Go + Gate 2 handoff)──► [EVALUATION] ──► [PROPOSAL] ──(WON 24h)──► [WON] ──► [DEPLOY]
   Bất kỳ stage trước QUALIFIED ──(không đạt/knockout/khách từ chối)──► [LOST]
   Trước Gate 1 ──(hủy)──► [ARCHIVED — chỉ lưu hồ sơ]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `RAW_DATA` | Hoàn tất Initial Brief | `BRIEF_SENT` | SALES_L2 chủ deal | SLA 2h; đủ 3 trường Ngân sách/Sản phẩm-dịch vụ/Nhu cầu; quá hạn escalate |
| `BRIEF_SENT` | Kích hoạt AUTO SCORING | `FIRST_MEETING` | Hệ thống (KXN-2) | Brief sơ bộ đủ 3 trường; điểm autoScore có giá trị |
| `FIRST_MEETING` | Ghi notes + duyệt bypass (D/E) | `BRIEF_RECEIVED` | SALES_L2 + SALES_L4 (bypass) | Notes bắt buộc; bypass SM duyệt 4h kèm lý do; B/C bị từ chối gặp → `LOST` |
| `BRIEF_RECEIVED` | Confirm brief đủ 8 mục | `LEAD` | SALES_L2 chủ deal | SLA 1 ngày; Full Brief 8 sections (KXN-3) |
| `LEAD` | Xếp tier xong | `QUALIFIED` | SALES_L2 (+ SM review) | SLA 1 ngày; qualifiedTier hợp lệ (không "Thiếu dữ liệu") |
| `QUALIFIED` | Gate 1 Go/No-Go + Gate 2 handoff | `EVALUATION` | SALES_L4 (SM ký) + OPS_AM (xác nhận) | Chi tiết tại FEAT-ERP-CRM-004; SLA Gate 1 = 1 ngày làm việc |
| `PROPOSAL` | KH đồng ý + HĐ/LOI ký | `WON` | OPS_AM (AM) + SM xác nhận | SLA 24h cập nhật; tự sinh dự án + AM xác nhận capacity |
| `WON` | Điều kiện deploy đủ | `DEPLOY` | OPS_AM | Gate 2 hoàn tất; nạp đủ 100% NSQC |
| Nhiều điểm | LOST | `LOST` | SALES_L2/L4 | Lý do đã ghi rõ trong 24h + nurturing plan |

**Quy tắc:**
- Không thể quay về stage trước (trừ LOST handling theo quy trình chung và deal trả về từ Gate 2 — khi đó credit tạm dừng đến handoff lại thành công).
- `DEPLOY` là trạng thái chuyển tiếp sang phân hệ Handoff/Onboarding; mọi chuyển stage có audit log bất biến (ai, khi nào, done criteria đã khớp gì).
- Stage machine thực thi tại CORE; web render trạng thái và tự vô hiệu hóa thao tác không hợp lệ.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `deals` (project PMS) | `stage`, `owner_id`, `team_id`, `source_channel`, `stage_entered_at`, `client_tier`, `qualified_tier` | FK → `users`, `teams`, `leads` | Stage machine là nguồn sự thật; audit mọi chuyển stage |
| `stage_transitions` | `deal_id`, `from_stage`, `to_stage`, `actor_id`, `criteria_snapshot`, `moved_at` | FK → `deals` | Bất biến (append-only); phục vụ báo cáo funnel |
| `initial_briefs` | `deal_id`, `budget`, `product_service`, `real_need`, `submitted_at`, `late_flag` | FK → `deals` | 3 trường bắt buộc; SLA 2h clock |
| `meeting_notes` | `deal_id`, `meeting_type`, `notes`, `attendees`, `created_at` | FK → `deals` | Không notes = meeting không công nhận |
| `lead_assignments` | `lead_id`, `assigned_to`, `assigned_by`, `rule` (auto/manual), `assigned_at` | FK → `leads`, `users` | Ghi rõ quy tắc gán để phục vụ phân tích fairness |
| `sla_clocks` | `deal_id`, `stage`, `deadline`, `escalation_level`, `escalated_to` | FK → `deals` | Giờ làm việc cấu hình; escalate tự động quá hạn |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo — chi tiết ở Phase 5. Mỗi scenario map về REQ-SALES-002.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Hard block chuyển stage | Deal ở `LEAD` chưa có qualifiedTier hợp lệ | SE kéo deal sang `QUALIFIED` | Nút vô hiệu kèm mục thiếu; gọi API trực tiếp bị từ chối; không có stage transition nào được ghi | [ ] |
| SC-002: SLA Initial Brief 2h | Lead vừa vào `RAW_DATA` 09:00 | 11:00 chưa nhập đủ 3 trường | Cảnh báo trên board; 11:30 escalate lên cấp trên trực tiếp, có log | [ ] |
| SC-003: Meeting notes bắt buộc | Deal Tier B đã họp First Meeting | Chưa ghi notes, thử chuyển sang `BRIEF_RECEIVED` | Bị chặn với thông báo "meeting chưa được công nhận — thiếu notes" | [ ] |
| SC-004: Phân bổ lead tự do | Lead tự do chưa owner trong hàng đợi | SM gán owner trong 4h giờ làm việc | Owner cập nhật, `lead_assignments` ghi rule=manual, SLA dừng đếm | [ ] |
| SC-005: WON đúng hạn tự sinh dự án | Deal đã qua Gate 2 | SE đánh dấu WON | Trong 24h: stage=WON, dự án tự sinh, AM nhận yêu cầu xác nhận capacity; quá 24h → cảnh báo SM | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (stage machine, SLA clock ở CORE) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (pipeline board, quản lý SLA) | `phase4-ux/bcerp-web/crm-pipeline/pipeline-board.md` |
| Nguồn quy trình chi tiết | `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1) |
| Ma trận RACI — Gate — SLA | `documents/quy-trinh-lam-viec/08_Ma_tran_RACI_Gate_SLA.md` (v1.1) |
