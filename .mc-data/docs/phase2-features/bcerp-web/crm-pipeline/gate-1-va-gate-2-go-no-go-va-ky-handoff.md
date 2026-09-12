# Tính Năng: Gate 1 & Gate 2 — Go/No-Go và ký Handoff

> **Dựa trên:** REQ-SALES-004 trong `phase1-business/departments/sales/sales.md` (Phần A + Phần B — Sales Expert Review)
> **Phân hệ:** CRM & Lead Pipeline V6.0 (SYS-BCERP-WEB)
> **Module:** CRM Pipeline (MOD-CRM-PIPELINE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase1-business/P1-02-business-workflow.md`, `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1 §2.6, §3), `documents/quy-trinh-lam-viec/08_Ma_tran_RACI_Gate_SLA.md` (v1.1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/crm-pipeline/gate-approval.md`, `phase5-implementation/tasks/bcerp-web/crm-pipeline/feat-erp-crm-004-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-CRM-004 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-004 |
| Người dùng liên quan | SALES_L2 (NVKD/SE — chờ kết quả), SALES_L3 (TNKD), SALES_L4 (TPKD/SM — ký cả 2 gate), SALES_L5 (GDKD — escalate, override knockout), OPS_AM (xác nhận Gate 2 SLA 4h), SYS_ADMIN |
| Độ ưu tiên | Cao (HIGH — MVP) |
| Giai đoạn | Giai đoạn 1 (approval engine + ký trên web); kênh ký MOBILE là primary từ Phase2 |
| Phụ thuộc | Không có cross-dependency chặn; nội dung Handoff Package 5 nhóm thuộc REQ-SALES-008 (module Handoff-Onboarding — chỉ tham chiếu); approval engine thực thi tại SYS-CORE-BACKEND (counterpart cùng REQ-ID) |
| Ghi chú Expert (A7) | Mục A7 của sales.md đang chờ điền; spec kế thừa Sales Expert Review Phần B (12/09/2026): Gate 1/Gate 2 tách khỏi di chuyển stage vì là điểm quyết định có chữ ký; SM ≠ chủ deal; override knockout chỉ deal chiến lược do GDKD phê duyệt |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng thực thi hai điểm quyết định có chữ ký của pipeline: Gate 1 (QUALIFIED — Go/No-Go) với SLA 1 ngày làm việc và Gate 2 (bàn giao Sales → Vận hành) với Handoff Package 5 nhóm đủ 100% + SM ký + AM xác nhận trong SLA 4h, kèm điều kiện nạp trước 100% NSQC. Theo KXN-4 đã chốt, điểm bàn giao chính thức đặt tại QUALIFIED (trình tự v2.3) và Handoff Package 5 nhóm của V6.0 là checklist bắt buộc tại điểm này. Gate quyết định đội ngũ có đầu tư thời gian vào deal hay không và khóa `qualifiedTier` — là tầng kiểm soát chống rủi ro lớn nhất trước khi hợp đồng và vận hành phát sinh.

**Phạm vi:**
- Bao gồm: màn hình duyệt đầy đủ trên web (hồ sơ deal, qualifiedTier, checklist Handoff, lịch sử); e-approval chữ ký SM cho cả 2 gate; kiểm tra entry criteria machine-checkable của Gate 1 (Full Brief 8 sections đủ, NDA mutual signed gắn khách, qualifiedTier có giá trị không "Thiếu dữ liệu", meeting notes đã ghi — bắt buộc với B/C, bypass D/E phải có lý do SM); checklist Gate 2 (Handoff Package 5 nhóm đủ 100%, capacity check không bằng 0, xác nhận nạp đủ 100% NSQC); escalation tự động quá SLA (Gate 1: GDKD rồi BOD; Gate 2: quá 4h escalate); ghi nhận AM từ chối → trả về SM khắc phục; override knockout K1–K5 cho deal chiến lược với GDKD phê duyệt.
- Không bao gồm: nội dung chi tiết Handoff Package 5 nhóm và milestone Day 1/7/14/30 (REQ-SALES-008 — module Handoff-Onboarding); di chuyển stage pipeline thường ngày (FEAT-ERP-CRM-002); scoring/tier (FEAT-ERP-CRM-003); e-sign hợp đồng theo Luật GDTĐT (REQ-SALES-007).

**Đặc thù touchpoint SYS-BCERP-WEB:**
Web nội bộ responsive (Next.js) là kênh ký đầy đủ ngay từ MVP — hiển thị machine-state của từng gate (chờ entry criteria / chờ ký SM / đã ký / chờ AM xác nhận / quá SLA đã escalate / No-Go / bị trả về). Approval engine, SLA clock và audit log nằm ở SYS-CORE-BACKEND; web vô hiệu hóa nút ký khi thiếu entry criteria, buộc nhập lý do cho No-Go/bypass/override, và chặn SM ký deal do chính mình chốt (kiểm tra SM ≠ chủ deal hiển thị trước, xác thực lại ở API). SYS-MOBILE-INTERNAL (counterpart thứ hai) là kênh ký chính từ Phase2 với MFA step-up + token gắn device; trên web hiện tại, ký qua xác thực chuẩn của hệ thống.

**Fan-out:**
REQ-SALES-004 xuất hiện ở 3 systems — đây là bản riêng cho SYS-BCERP-WEB; counterparts: SYS-CORE-BACKEND (approval engine — primary engine) và SYS-MOBILE-INTERNAL (kênh ký di động từ Phase2). Spec này mô tả màn hình duyệt và thao tác ký thuộc web nội bộ.

**Nguồn quy trình:** `documents/quy-trinh-lam-viec/` v1.1 — ma trận RACI G2 (QUALIFIED Go/No-Go: SM ký, SLA 1 ngày làm việc) và G3 (bàn giao Sales → BPVH: SM ký → AM xác nhận tiếp nhận 4h làm việc); KXN-4 chốt vị trí bàn giao tại QUALIFIED; ma trận RACI chờ xác nhận chính thức `[KXN-19]`; 11 KXN còn mở (6, 7, 9, 15–22) ghi assumption có tag, không tự quyết.

---

## 2. Luồng Người Dùng (User Stories)

Chuỗi gate diễn ra ngay sau QUALIFIED: khi entry criteria đủ, hệ thống mở Gate 1 và bắt đầu đồng hồ 1 ngày làm việc; SM ký Go/No-Go rồi khóa qualifiedTier. Pass thì tiếp tục Gate 2 — SM ký duyệt bàn giao kèm Handoff Package 5 nhóm đủ 100%; AM xác nhận tiếp nhận trong 4h làm việc; nếu khách chưa nạp đủ 100% NSQC, hợp đồng ở trạng thái "chờ kích hoạt" và việc tạo chiến dịch bị block ở tầng máy.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L4 (TPKD/SM) | Thấy gộp trong màn duyệt: hồ sơ deal, qualifiedTier + lý do, checklist entry criteria từng mục đã/không đạt | Ký Go/No-Go trong 1 ngày làm việc dựa trên đầy đủ căn cứ, không phải mở 5 nơi tra cứu |
| 2 | SALES_L4 (TPKD/SM) | Bị chặn ký deal do chính mình chốt | Giữ nguyên tắc kiểm soát chéo — chữ ký gate phải độc lập với người bán |
| 3 | SALES_L2 (NVKD/SE) | Nhận kết quả Gate 1/No-Go kèm lý do rõ ràng ngay trên deal | Điều chỉnh hoặc dừng sớm, không chờ hỏi miệng; No-Go thì lưu hồ sơ dừng sạch sẽ |
| 4 | OPS_AM | Xem checklist Handoff 5 nhóm + capacity + tình trạng nạp NSQC và xác nhận/từ chối tiếp nhận trong 4h | Không nhận deal "không người chạy" hoặc thiếu hồ sơ — từ chối có căn cứ |
| 5 | SALES_L5 (GDKD) | Nhận escalate khi Gate 1 quá SLA 1 ngày hoặc SM muốn override knockout | Deal chiến lược có lối thoát có kiểm soát, không tắc vì SM vắng |
| 6 | SALES_L3 (TNKD) | Xem trạng thái gate của deal nhóm và mốc SLA còn lại | Nhắc kịp thời, tránh escalation chạy tới cấp trên vì quên ký |
| 7 | SALES_L2 (NVKD/SE) | Theo dõi tình trạng "chờ kích hoạt" khi khách chưa nạp đủ 100% NSQC | Biết chính xác deal nào sắp deploy được để báo khách đúng tiến độ |

---

## 3. Quy Tắc Nghiệp Vụ

Sáu nhóm quy tắc bắt buộc của lane áp dụng đầy đủ; nhóm trọng tâm là Gate 1/Gate 2 Go/No-Go, SLA ký và điều kiện nạp trước 100% NSQC. Chữ ký gate không ủy thác hàng loạt; mọi chữ ký, escalation, override đều ghi audit log bất biến ở CORE.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | Hard gate "không ghi nhận = không tồn tại" (KXN-1): chữ ký gate phải có bản ghi hệ thống trước khi phát sinh hệ quả (chuyển stage, vận hành, credit); pipeline 5 tier A–E (A <1.5 AUTO LOST → E ≥3.5 bypass) là đầu vào của Gate 1 | Deal không có bản ghi trước Gate 2 không được vận hành và không được tính credit — kể cả SM/GDKD xác nhận miệng |
| BR-SALES-401 | Gate 1 — QUALIFIED Go/No-Go: entry machine-checkable gồm Full Brief 8 sections đủ (KXN-3), NDA mutual signed gắn khách (REQ-SALES-007), qualifiedTier có giá trị (không "Thiếu dữ liệu" — KXN-2: chấm sau Full Brief), meeting notes đã ghi (B/C bắt buộc; bypass D/E lý do SM); SM ký trong SLA 1 ngày làm việc → khóa qualifiedTier; SM ≠ NVKD chủ deal; quá SLA escalate GDKD rồi BOD; No-Go → dừng, lưu hồ sơ | Thiếu bất kỳ entry → nút ký vô hiệu + API từ chối; ký hộ/ký deal của mình bị chặn ở API; quá SLA có log mốc escalate |
| BR-SALES-402 | Gate 2 — bàn giao Sales → Vận hành tại QUALIFIED pass (KXN-4): Handoff Package 5 nhóm đủ 100% (REQ-SALES-008); capacity check không bằng 0; SM ký → AM xác nhận trong SLA 4h làm việc; điều kiện tiền: chưa xác nhận nạp đủ 100% NSQC → hợp đồng "chờ kích hoạt", block tạo chiến dịch ở tầng máy (Financial Hard Stop); AM từ chối → trả về SM khắc phục, credit hoa hồng tạm dừng (REQ-SALES-009); SLA tính giờ làm việc cấu hình | Thiếu checklist item → gate không mở, hiển thị responsible + due date của mục thiếu; tạo chiến dịch khi chưa nạp đủ bị block máy |
| BR-SALES-302/401-exception | Override knockout K1–K5: chỉ deal chiến lược được chỉ định, lý do bằng văn bản + GDKD phê duyệt lại, log bất biến | Không có lối override khác; override không GDKD duyệt bị từ chối ở API |
| BR-SALES-303/604 | qualifiedTier là đầu vào bắt buộc của Gate 1 (map A <1.5 AUTO LOST → E ≥3.5 bypass; borderline D SM thẩm định 4h); hệ quả tier: proposal B/C = AM 8–12 trang ≤2 vòng, D/E = Planner 15–25 trang ≤4 vòng (KXN-8); CQ 30/25/20/15/10; rà soát tier theo quý | Gate 1 không thể mở khi tier ở trạng thái "Thiếu dữ liệu"; sau ký, tier khóa — chấm lại bị chặn |
| BR-SALES-203/102 | Anti-duplicate 4 kênh và phân bổ lead + escape hatch (FEAT-ERP-CRM-001) là điều kiện dữ liệu sạch cho gate; chữ ký trên MOBILE (Phase2) dùng token gắn device theo NFR P0-02 §2.4, ký không ủy thác hàng loạt | Deal chưa qua phân xử trùng không mở gate; chữ ký hàng loạt bị hệ thống từ chối |

**Quy tắc bổ sung:** AM xác nhận Gate 2 trong 4h là SLA "không gia hạn"; deal trả về từ Gate 2 tạm dừng credit đến khi handoff lại thành công (nối REQ-SALES-009); khách tái ký không được bỏ Gate 1/Gate 2 (escape hatch chỉ rút gọn Initial Brief).

---

## 4. Phân Quyền

Gate là quyền lực có chữ ký nên ma trận rất chặt: chỉ SM ký, chỉ AM xác nhận tiếp nhận, chỉ GDKD duyệt override; quyền xem mở rộng cho nhóm để minh bạch tiến trình.

| Hành động | SALES_L2 | SALES_L3 | SALES_L4 (SM) | SALES_L5 (GDKD) | OPS_AM | SYS_ADMIN |
|-----------|----------|----------|---------------|-----------------|--------|-----------|
| Xem trạng thái gate deal (của mình/nhóm) | ✅ | ✅ (nhóm) | ✅ | ✅ | ✅ (deal được bàn giao) | ❌ |
| Ký Gate 1 Go/No-Go | ❌ | ❌ | ✅ (SM ≠ chủ deal) | ❌ | ❌ | ❌ |
| Ký Gate 2 (duyệt bàn giao) | ❌ | ❌ | ✅ (SM ≠ chủ deal) | ❌ | ❌ | ❌ |
| Xác nhận tiếp nhận Gate 2 (SLA 4h) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Từ chối Gate 2 (trả về SM) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Override knockout K1–K5 (phê duyệt) | ❌ | ❌ | Đề xuất + lý do bằng văn bản | ✅ (duyệt lại) | ❌ | ❌ |
| Xem audit log chữ ký/escalation | ❌ | ✅ (nhóm) | ✅ | ✅ | ✅ (deal liên quan) | ✅ |
| Sửa/xóa chữ ký đã ghi | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — log bất biến) |

**Lưu ý:** SM vắng → không có ủy quyền hàng loạt; escalation tự động GDKD rồi BOD là cơ chế duy nhất thay thế; OPS_AM chỉ tương tác với gate deal được bàn giao, không duyệt gate của deal chưa tới điểm bàn giao.

---

## 5. Trường Hợp Đặc Biệt

- **SM là NVKD chủ deal (xung đột ký):** hệ thống chặn ở cả UI và API; không có hình thức "ký thay có thông báo" — deal phải chuyển SM khác hoặc GDKD chỉ định người ký thay có audit log.
- **Gate 2 bị AM từ chối:** deal trả về SM khắc phục theo đúng các mục checklist fail; credit hoa hồng của deal tạm dừng đến khi handoff lại thành công; số lần trả về không giới hạn nhưng mọi vòng đều log — GDKD xem báo cáo để can thiệp nếu lặp lại bất thường.
- **Capacity trống = 0 ngay trước ký Gate 2:** cảnh báo GDKD + OPS_PLAN trước khi ký (tránh ký deal không người chạy); ký vẫn có thể diễn ra nếu GDKD chấp nhận rủi ro bằng văn bản — cảnh báo không phải cấm, nhưng phải log.
- **Khách nạp NSQC chậm sau Gate 2:** hợp đồng ở "chờ kích hoạt" vô thời hạn chờ tiền; block tạo chiến dịch là rào máy — không ai được bật chiến dịch thủ công; AM nhắc khách theo nhịp 5 ngày/14 ngày (theo quy trình WON).
- **Override knockout K1–K5:** chỉ deal chiến lược được chỉ định trước; SM đề xuất lý do bằng văn bản → GDKD phê duyệt lại → hệ thống chấm lại scoring với knockout được ghi đè có đánh dấu; log bất biến phục vụ post-mortem.
- **Tier E bypass First Meeting:** bypass chỉ miễn First Meeting — không miễn Gate 1/Gate 2; lý do bypass của SM phải tồn tại trước khi entry criteria Gate 1 được đánh "đạt" cho trường hợp B/C-required-notes.
- **NDA hết hạn giữa chừng trước Gate 1:** entry criteria kiểm tra NDA mutual signed còn hiệu lực tại thời điểm ký — nếu hết hạn, checklist quay về "chưa đạt" và gate đóng lại cho đến khi NDA gia hạn (nối REQ-SALES-007).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Gate approval của deal (`gate_approvals` — 2 instance/deal: gate1, gate2).

**Sơ đồ trạng thái:**
```
Gate 1: [ENTRY_PENDING] ──(đủ entry criteria)──► [AWAITING_SM] ──(SM ký, SLA 1 ngày)──► [GO | NO_GO]
             AWAITING_SM ──(quá SLA)──► [ESCALATED_GDKD] ──► [ESCALATED_BOD] ──► [GO | NO_GO]
Gate 2: [CHECKLIST_PENDING] ──(package 5 nhóm 100% + capacity ≠ 0)──► [AWAITING_SM_SIGN]
             AWAITING_SM_SIGN ──(SM ký)──► [AWAITING_AM_CONFIRM] (4h) ──(AM xác nhận)──► [HANDOFF_CONFIRMED]
             AWAITING_AM_CONFIRM ──(AM từ chối)──► [RETURNED_TO_SM] ──(khắc phục)──► CHECKLIST_PENDING
             HANDOFF_CONFIRMED ──(chưa nạp 100% NSQC)──► [AWAITING_DEPOSIT] ──(nạp đủ)──► [ACTIVATION_READY]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ENTRY_PENDING` | Hệ thống kiểm entry | `AWAITING_SM` | Hệ thống | Full Brief 8 sections; NDA signed; qualifiedTier hợp lệ; meeting notes (B/C) |
| `AWAITING_SM` | SM ký Go | `GO` | SALES_L4 (≠ chủ deal) | SLA 1 ngày làm việc; khóa qualifiedTier |
| `AWAITING_SM` | SM ký No-Go | `NO_GO` | SALES_L4 | Bắt buộc nhập lý do; lưu hồ sơ dừng |
| `AWAITING_SM` | Quá SLA | `ESCALATED_GDKD` → `ESCALATED_BOD` | Hệ thống | Escalate tự động + log mốc |
| `CHECKLIST_PENDING` | Checklist đạt 100% | `AWAITING_SM_SIGN` | Hệ thống | 5 nhóm đủ; capacity ≠ 0 (hoặc GDKD chấp nhận rủi ro) |
| `AWAITING_SM_SIGN` | SM ký duyệt bàn giao | `AWAITING_AM_CONFIRM` | SALES_L4 | Log chữ ký (ai, khi nào) |
| `AWAITING_AM_CONFIRM` | AM xác nhận tiếp nhận | `HANDOFF_CONFIRMED` | OPS_AM | SLA 4h làm việc; quá hạn escalate |
| `AWAITING_AM_CONFIRM` | AM từ chối | `RETURNED_TO_SM` | OPS_AM | Lý do theo mục checklist fail; credit tạm dừng |
| `HANDOFF_CONFIRMED` | Xác nhận nạp đủ 100% NSQC | `ACTIVATION_READY` | FIN/Hệ thống | Đối soát nạp; mở quyền tạo chiến dịch |

**Quy tắc:** `GO`, `NO_GO`, `HANDOFF_CONFIRMED` là điểm kết thúc của từng gate — không sửa chữ ký sau khi ghi; `RETURNED_TO_SM` là vòng lặp có kiểm soát (mỗi vòng một record mới); trạng thái "chờ kích hoạt" block tạo chiến dịch ở tầng máy cho đến khi tiền đủ.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `gate_approvals` | `deal_id`, `gate_no` (1/2), `state`, `entry_check_snapshot`, `signed_by`, `signed_at`, `sla_deadline`, `escalation_level` | FK → `deals` | 2 instance/deal; entry criteria snapshot machine-checkable |
| `gate_signatures` | `approval_id`, `signer_id`, `role_at_signing`, `signed_at`, `channel` (web/mobile), `mfa_token_ref` | FK → `gate_approvals`, `users` | Bất biến; mobile ký (Phase2) gắn device token |
| `handoff_checklist_items` | `deal_id`, `group_no` (1–5), `item`, `responsible_id`, `due_date`, `done` | FK → `deals` | Nội dung chi tiết tại REQ-SALES-008; chặn Gate 2 khi <100% |
| `gate_escalations` | `approval_id`, `from_role`, `to_role`, `escalated_at`, `reason` | FK → `gate_approvals` | Tự động quá SLA; log mốc GDKD → BOD |
| `activation_conditions` | `deal_id`, `deposit_required_percent` (100), `deposit_confirmed_at`, `activated_at` | FK → `deals` | Nối Financial Hard Stop; block chiến dịch khi chưa đủ |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo — chi tiết ở Phase 5. Mỗi scenario map về REQ-SALES-004.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Entry criteria chặn Gate 1 | Deal thiếu meeting notes (Tier B) | SM mở màn hình duyệt | Nút ký vô hiệu, checklist chỉ rõ mục "meeting notes: chưa đạt"; API từ chối ký | [ ] |
| SC-002: SM ≠ chủ deal | SE A là chủ deal | A (được thăng vai SM) tự ký Gate 1 | Chặn ở API với lỗi xung đột vai; không có chữ ký nào được ghi | [ ] |
| SC-003: Escalate quá SLA Gate 1 | Gate 1 mở, SM không ký sau 1 ngày làm việc | Hết deadline | Tự escalate GDKD (rồi BOD), log mốc; GDKD thấy deal trong hàng đợi escalate | [ ] |
| SC-004: Gate 2 thiếu checklist | Handoff Package 97% (thiếu 1 mục nhóm 3) | SM thử ký bàn giao | Bị chặn; hiển thị mục thiếu + responsible + due date | [ ] |
| SC-005: AM từ chối → trả về | AM xác nhận Gate 2, phát hiện hồ sơ thiếu | AM chọn từ chối kèm lý do | Deal về `RETURNED_TO_SM`, credit tạm dừng, SM thấy danh sách mục phải khắc phục | [ ] |
| SC-006: Chưa nạp đủ NSQC | Gate 2 confirmed, chưa xác nhận nạp 100% NSQC | Cố tạo chiến dịch | Block ở tầng máy; trạng thái hợp đồng "chờ kích hoạt" hiển thị rõ | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (approval engine, fan-out MOBILE-INTERNAL) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (màn duyệt gate, checklist Handoff) | `phase4-ux/bcerp-web/crm-pipeline/gate-approval.md` |
| Nguồn quy trình chi tiết | `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1 §2.6, §3) |
| Ma trận RACI — Gate — SLA (`[KXN-19]` chờ xác nhận) | `documents/quy-trinh-lam-viec/08_Ma_tran_RACI_Gate_SLA.md` (v1.1) |
