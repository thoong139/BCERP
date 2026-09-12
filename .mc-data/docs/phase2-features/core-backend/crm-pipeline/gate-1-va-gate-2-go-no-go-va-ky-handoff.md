# Tính Năng: Gate 1 & Gate 2 — Go/No-Go và ký Handoff

> **Dựa trên:** REQ-SALES-004 trong `phase1-business/departments/sales/sales.md` (Phần A)
> **Phân hệ:** CRM & Lead Pipeline V6.0 (SYS-CORE-BACKEND)
> **Module:** MOD-CRM-PIPELINE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` (v1.1), `documents/quy-trinh-lam-viec/08_Ma_tran_RACI_Gate_SLA.md` (v1.1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/SYS-CORE-BACKEND/MOD-CRM-PIPELINE/[screen-group].md`, `phase5-implementation/tasks/SYS-CORE-BACKEND/MOD-CRM-PIPELINE/FEAT-CORE-CRM-004-impl.md`
>
> **ID:** FEAT-ID từ lane `core-backend--CRM-PIPELINE`. REQ-SALES-004 fan-out 3 hệ thống — bản này là bản riêng cho SYS-CORE-BACKEND (approval engine là nguồn sự thật); WEB là màn hình duyệt, MOBILE là kênh ký chính từ Phase2 (MFA step-up).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CRM-004 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-004 (Gate 1 & Gate 2 — Go/No-Go và ký Handoff) |
| Người dùng liên quan | SALES_L2 (chủ deal — chờ kết quả), SALES_L3 (SM — ký cả 2 gate), OPS_AM (xác nhận Gate 2 SLA 4h), SALES_L4, SALES_L5 (duyệt override knockout, escalation), BOD_CEO/BOD_CFO_CTO (escalation cuối), SYS_ADMIN (cấu hình SLA/escalation) |
| Độ ưu tiên | Cao (HIGH — MVP: engine + ký web; MOBILE là kênh ký chính từ Phase2) |
| Giai đoạn | Giai đoạn 1 (MVP — engine + web); kênh ký MOBILE nâng cấp Phase2 |
| Phụ thuộc | Không có phụ thuộc chéo module (cross-dependencies = không có). Trong module: tiêu thụ `qualifiedTier` từ FEAT-CORE-CRM-003 và stage machine từ FEAT-CORE-CRM-002; checklist Handoff Package chi tiết thuộc REQ-SALES-008 (lane HANDOFF-ONBOARD) |
| Ghi chú Expert (A7) | Chưa có điều chỉnh nào từ Expert Review được ghi nhận trong `sales.md` Mục A7 tại thời điểm lập spec (12/09/2026) — giữ nguyên nội dung Phần B do sales-expert review |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng approval engine cho 2 điểm quyết định có chữ ký của Pipeline V6.0 trên Core Backend: **Gate 1 (QUALIFIED)** — SM ký Go/No-Go trong SLA 1 ngày làm việc sau khi đủ điều kiện machine-checkable, đồng thời khóa `qualifiedTier`; **Gate 2 (LEAD — Decision Gate bàn giao Vận hành)** — SM ký khi Handoff Package 5 nhóm đủ 100% + điều kiện tiền "nạp trước 100% NSQC", AM xác nhận trong SLA 4h. Chữ ký gate là dữ kiện pháp-nội bộ: không ủy thác hàng loạt, cấm tự duyệt deal của mình, mọi chữ ký ghi audit log bất biến.

**Phạm vi:**
- Bao gồm: gate domain service — điều kiện entry machine-checkable (Full Brief 8 sections, NDA mutual signed gắn khách, `qualifiedTier` hợp lệ, meeting notes đủ, Handoff Package 5 nhóm 100%, capacity check ≠ 0); e-approval chữ ký SM với ràng buộc SM ≠ chủ deal; SLA clock Gate 1 (1 ngày làm việc) và Gate 2 (AM xác nhận 4h) + escalation tự động (GDKD → BOD); chưa nạp đủ 100% NSQC → hợp đồng "chờ kích hoạt", block tạo chiến dịch ở tầng máy (Financial Hard Stop — bắt tay DEPT-FIN); AM từ chối Gate 2 → trả về SM khắc phục, credit tạm dừng; override knockout K1–K5 cho deal chiến lược (GDKD duyệt, log bất biến); chữ ký MOBILE (Phase2) với MFA step-up + token gắn device theo NFR P0-02 §2.4.
- Không bao gồm: soạn Handoff Package + milestone Day 1/7/14/30 (REQ-SALES-008 — gate chỉ đọc checklist status); màn hình duyệt WEB và app MOBILE (counterparts); scoring (FEAT-CORE-CRM-003); hợp đồng/e-sign đầy đủ (REQ-SALES-007); credit hoa hồng chi tiết (REQ-SALES-009 — GĐ3).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-CORE-BACKEND: approval engine là nguồn sự thật — WEB/MOBILE chỉ là kênh; mọi điều kiện và chữ ký enforce ở service layer.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L3 (SM) | Hệ thống chỉ mở Gate 1 khi đủ điều kiện machine-checkable (Full Brief 8 sections, NDA signed, `qualifiedTier` hợp lệ, meeting notes — B/C bắt buộc gặp, bypass D/E phải có lý do) | Quyết Go/No-Go trên bộ hồ sơ đầy đủ, không ký theo niềm tin |
| 2 | SALES_L3 (SM) | Ký Go/No-Go qua API trong SLA 1 ngày làm việc; hệ thống tự khóa `qualifiedTier` sau chữ ký | Chốt tier vận hành một lần — không ai chỉnh lại sau quyết định |
| 3 | SALES_L2 (chủ deal) | Nhận thông báo kết quả Gate 1 và không thể tự ký deal của mình | Chống xung đột lợi ích |
| 4 | OPS_AM | Nhận yêu cầu xác nhận Gate 2 sau khi SM ký và xác nhận trong SLA 4h | Vận hành chủ động tiếp nhận với package đủ 100%, không tiếp "đồ thiếu" |
| 5 | SALES_L3 (SM) | Hệ thống chặn ký Gate 2 khi Package 5 nhóm <100% hoặc capacity = 0 | Không ký bàn giao deal không người chạy / thiếu hồ sơ |
| 6 | Hệ thống (financial hard stop) | Giữ hợp đồng "chờ kích hoạt" và block tạo chiến dịch khi chưa xác nhận nạp đủ 100% NSQC | Tiền giữ hộ phải về đủ trước khi đốt ngân sách |
| 7 | SALES_L5 (GDKD) | Duyệt override knockout K1–K5 với lý do bằng văn bản; nhận escalation khi gate quá SLA | Van khẩn cấp có kiểm soát; quá hạn không âm thầm |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, enforce ở tầng service của Core Backend (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | **Hard gate "không ghi nhận = không tồn tại":** chữ ký gate chỉ có giá trị khi là bản ghi e-approval trên hệ thống; xác nhận miệng/Zalo không tạo hiệu lực; mọi chữ ký ghi audit log bất biến (thời gian, kênh, device với MOBILE) | Gate không mở khi thiếu bản ghi e-approval; báo cáo gate pass rate chỉ đếm chữ ký có audit |
| BR-SALES-401 | **Gate 1 — QUALIFIED, Go/No-Go (SM ký, SLA 1 ngày làm việc):** entry machine-checkable: Full Brief 8 sections đủ (KXN-3); NDA mutual signed gắn khách (block từ REQ-SALES-007 — sales không được trigger nhận Full Brief khi chưa NDA); `qualifiedTier` có giá trị (không "Thiếu dữ liệu"); meeting notes đã ghi — bắt buộc với B/C, bypass D/E phải có lý do SM. **SM ký phải khác NVKD chủ deal — cấm tự duyệt deal của mình.** Done: ký Go/No-Go → khóa `qualifiedTier` | API không mở gate thiếu entry nào; chữ ký của chính chủ deal bị từ chối; sau chữ ký mọi request đổi tier bị chặn cứng |
| BR-SALES-402 | **Gate 2 — LEAD, ký Handoff (SM ký + AM xác nhận, SLA 4h làm việc):** entry: Handoff Package 5 nhóm đủ 100% (Hồ sơ KH · Tài chính · Kỳ vọng & Scope · Nội bộ — phân bổ AM + Capacity trống · Pháp lý & Rủi ro — chi tiết REQ-SALES-008); capacity check ≠ 0 (trống = 0 → cảnh báo GDKD + OPS_PLAN trước khi ký). Done: SM ký → AM xác nhận trong 4h. **Điều kiện tiền: chưa nạp đủ 100% NSQC → hợp đồng "chờ kích hoạt", block tạo chiến dịch ở tầng máy (Financial Hard Stop)** | Gate 2 không mở khi package <100% hoặc capacity = 0; "chờ kích hoạt" chặn mọi API tạo chiến dịch; AM quá 4h → escalate tự động |
| BR-CRM-004-03 | **Escalation tự động quá SLA:** Gate 1 quá 1 ngày làm việc → escalate GDKD rồi BOD + log; Gate 2 quá 4h → escalate tự động; SLA tính giờ làm việc cấu hình theo tenant; escalation record không xóa được | Breach sinh escalation record + alert; deal không rơi vào "quên duyệt"; chuỗi SE → SM → GDKD → BOD theo cấu hình |
| BR-CRM-004-04 | **Chữ ký không ủy thác hàng loạt:** không cơ chế ủy quyền số lượng/whitelist duyệt hộ; mỗi gate là một quyết định riêng; MOBILE (Phase2 — kênh ký chính) ký qua MFA step-up + token gắn device theo NFR P0-02 §2.4; MOBILE không dùng nhập liệu hàng loạt | Request ủy quyền hàng loạt bị từ chối; chữ ký từ device chưa đăng ký token bị từ chối; chữ ký mobile vẫn chạy approval engine CORE — CORE là nguồn sự thật |
| BR-CRM-004-05 | **Override knockout có kiểm soát:** chỉ deal chiến lược được chỉ định; lý do bằng văn bản; GDKD (SALES_L5) phê duyệt lại; log bất biến; lead gắn nhãn override suốt vòng đời để rà quý | Override không văn bản/không GDKD bị chặn; danh sách override xuất hiện bắt buộc trong báo cáo rà quý (FEAT-CORE-CRM-005) |
| BR-CRM-004-06 | **AM từ chối Gate 2:** deal trả về SM khắc phục theo package; credit hoa hồng tạm dừng đến khi handoff lại thành công (nối REQ-SALES-009); handoff ngoài package (miệng/chat) không được công nhận | Trạng thái deal quay về "cần khắc phục" kèm lý do AM; credit engine nhận flag tạm dừng; không đánh dấu handoff thành công ngoài checklist |
| BR-CRM-004-07 | **Bối cảnh tier (thượng nguồn — đọc từ FEAT-CORE-CRM-003):** 5 tier A–E theo KXN-1 (A <1.5 AUTO LOST → E ≥3.5 bypass — nhưng Gate 1/Gate 2 vẫn bắt buộc đủ, kể cả khách tái ký); AUTO SCORING trước First Meeting, `qualifiedTier` chốt sau Full Brief (KXN-2); trọng số CQ theo tier 30/25/20/15/10 | Gate engine không tự suy tier — chỉ đọc `qualifiedTier` hợp lệ; lead không có kết quả chấm không qua Gate 1 |
| BR-CRM-004-08 | **Định mức downstream theo KXN-8 (chiều V6.0):** proposal B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng — tier sau Gate 1 quyết template/SLA/vòng sửa cho PROPOSAL; gate engine phát tier đã khóa cho module downstream; rà soát tier theo quý (BR-SALES-503) và UPSELL theo quy-trinh v1.1 file 06 §8 tiêu thụ dữ liệu gate pass rate/SLA compliance/override log do engine ghi | Module downstream đọc tier từ engine (đã khóa), không đọc điểm thô; cấm hardcode nhãn tier |

---

## 4. Phân Quyền

| Hành động | SALES_L2 (chủ deal) | SALES_L3 (SM) | SALES_L4 (TPKD) | SALES_L5 (GDKD) | OPS_AM | SYS_ADMIN |
|-----------|---------------------|----------------|------------------|------------------|--------|-----------|
| Xem hồ sơ deal + trạng thái gate (deal của mình) | ✅ | ✅ | ✅ | ✅ | ✅ (phần handoff) | ✅ |
| Nộp deal vào Gate 1 | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Ký Gate 1 (Go/No-Go) | ❌ (cấm tự duyệt deal mình) | ✅ (≠ chủ deal) | ❌ | ❌ (chỉ nhận escalation) | ❌ | ❌ |
| Ký Gate 2 (Handoff) | ❌ | ✅ | ❌ | ❌ (chỉ nhận escalation) | ❌ | ❌ |
| Xác nhận Gate 2 (SLA 4h) / từ chối | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Đề xuất / duyệt override knockout | ✅ (deal mình, kèm văn bản) | ✅ (đề xuất) | ❌ | ✅ (duyệt) | ❌ | ❌ |
| Xử lý escalation gate quá SLA | ❌ | ❌ | ❌ | ✅ (BOD ở bậc cuối) | ❌ | ❌ |
| Cấu hình SLA gate/escalation chain | ❌ | ❌ | ❌ | ✅ (đề xuất trình BOD) | ❌ | ✅ (thực thi) |

> Chữ ký theo **mã vai** (SM = `SALES_L3`, GDKD = `SALES_L5`) không theo người — hỗ trợ vai kiêm nhiệm GDKD tạm do BOD đảm nhận. MOBILE là kênh ký chính từ Phase2 nhưng không đổi logic phân quyền — chỉ thêm MFA step-up + token gắn device. Không dùng `OPS_CX`/`FIN_COMPL` (DI-006).

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **SM vắng mặt dài hạn:** gate không tự mở — escalation chain chạy theo SLA (1 ngày / 4h) rồi đẩy GDKD; không có "duyệt hộ cấu hình sẵn".
- **SM đồng thời là chủ deal (nhóm nhỏ):** hệ thống chặn chữ ký, bắt buộc người ký `SALES_L3` khác chủ deal; nếu chỉ có một SM trong tenant, escalation đẩy GDKD ký thay.
- **Deal chiến lược cần override knockout:** chỉ qua văn bản + GDKD duyệt; lead gắn nhãn override, xuất hiện bắt buộc trong báo cáo rà quý; đối tác giới thiệu không được ưu tiên override.
- **Khách tái ký:** Initial Brief rút gọn nhưng Gate 1/Gate 2 vẫn bắt buộc — không nhận cấu hình "bỏ gate" cho bất kỳ phân khúc nào.
- **AM từ chối Gate 2:** lý do bắt buộc; deal trả về SM khắc phục; credit tạm dừng (flag sang credit engine — REQ-SALES-009); ký lại chỉ sau khi khắc phục + package đủ.
- **Nạp NSQC đủ sau Gate 2:** hợp đồng "chờ kích hoạt" → FIN xác nhận nạp đủ 100% → block tạo chiến dịch tự nhả; trước đó mọi API tạo chiến dịch bị chặn tầng máy.
- **Capacity thay đổi giữa lúc ký / chữ ký MOBILE (Phase2):** capacity check chạy lại ngay trước khi mở Gate 2 — nếu về 0 sau khi SM ký nhưng trước AM xác nhận, cảnh báo GDKD + OPS_PLAN; device chưa đăng ký token hoặc thiếu MFA step-up → chữ ký từ chối, thử vượt hạn ghi audit + alert bảo mật.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity: GateApproval — hai instance: Gate 1 tại stage QUALIFIED, Gate 2 tại stage LEAD (Decision Gate bàn giao Vận hành theo KXN-4).*

**Entity:** GateApproval

**Sơ đồ trạng thái:**
```
[BLOCKED] ──(đủ entry)──► [PENDING_SIGN] ──(SM ký · Gate 1 SLA 1 ngày / Gate 2 SLA AM 4h)──► [SIGNED]
     ▲                        │ (quá SLA → escalate GDKD rồi BOD)                 │ (chỉ Gate 2)
[ENTRY_FAILED]            [ESCALATED] ──(ký)──► [SIGNED]                      [AM_CONFIRMING]
                                                                 │ (AM OK)      │ (AM từ chối)
                                                                 ▼              ▼
                                                            [GATE_PASSED]  [RETURNED_TO_SM]
                                                                 │ (Gate 1: khóa qualifiedTier · Gate 2 + đủ nạp 100% NSQC)
                                                                 ▼
                                                            [DEAL_PROCEED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `BLOCKED` | Kiểm tra entry conditions | `ENTRY_FAILED` / `PENDING_SIGN` | Hệ thống | Gate 1: Full Brief đủ + NDA signed + `qualifiedTier` hợp lệ + meeting notes; Gate 2: Package 5 nhóm = 100% + capacity ≠ 0 |
| `ENTRY_FAILED` | Bổ sung điều kiện | `BLOCKED` (kiểm lại) | SALES_L2 (chủ deal) | Bản ghi điều kiện thiếu trả kèm lý do từng mục |
| `PENDING_SIGN` | SM ký Go/No-Go (Gate 1) | `SIGNED` | SALES_L3 (≠ chủ deal), SLA 1 ngày làm việc | E-approval có audit (thời gian, kênh; MOBILE: MFA + token device) |
| `PENDING_SIGN` | Quá SLA | `ESCALATED` | Hệ thống | Gate 1 → GDKD rồi BOD + log; Gate 2 → escalate tự động |
| `SIGNED` (Gate 1) | Khóa tier | `GATE_PASSED` | Hệ thống | `qualifiedTier` → `LOCKED` (FEAT-CORE-CRM-003) |
| `SIGNED` (Gate 2) | Chuyển AM xác nhận | `AM_CONFIRMING` | Hệ thống | Đồng thời kiểm nạp 100% NSQC — thiếu → hợp đồng "chờ kích hoạt" |
| `AM_CONFIRMING` | AM xác nhận tiếp nhận | `GATE_PASSED` | OPS_AM, SLA 4h giờ làm việc | Package 100%; quá 4h escalate |
| `AM_CONFIRMING` | AM từ chối | `RETURNED_TO_SM` | OPS_AM | Lý do bắt buộc; credit tạm dừng; khắc phục rồi nộp lại từ `BLOCKED` |
| `EXPIRED_NO_GO` / No-Go | Dừng deal | Kết thúc — lưu hồ sơ | SALES_L3/GDKD (theo bậc ký) | Lý do No-Go ghi rõ; hồ sơ read-only |

**Quy tắc:**
- Không quay về trạng thái trước: `RETURNED_TO_SM` khởi động lại chu trình từ `BLOCKED` (bản ghi cũ giữ làm lịch sử), không sửa bản ghi ký cũ.
- `GATE_PASSED` Gate 1 và Gate 2 (kèm nạp đủ 100% NSQC) là điều kiện bắt buộc của stage kế tiếp — stage machine (FEAT-CORE-CRM-002) đọc trạng thái gate, không tự suy.
- Mọi chuyển trạng thái ghi audit log bất biến WORM; chữ ký gắn mã vai; tenant isolation toàn bộ truy vấn.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `gate_approval` | `deal_id`, `gate_no` (1/2), `state`, `signer_id`, `signed_at`, `channel` (web/mobile), `sla_due_at`, `decision` | FK → `pipeline_deal.id`, `users.id` | Signer theo mã vai ≠ chủ deal; MOBILE lưu device token ref |
| `gate_entry_check` | `approval_id`, `condition_code`, `passed`, `detail` (full_brief_8, nda_signed, qualified_tier, meeting_notes, package_5_groups, capacity, nsqc_100) | FK → `gate_approval.id` | Mỗi lần mở gate chụp snapshot kết quả check |
| `handoff_package_status` | `deal_id`, `group_no` (1–5), `item_count`, `completed_count`, `percent` | FK → `pipeline_deal.id` | Đọc từ REQ-SALES-008; gate chỉ đọc không ghi |
| `gate_escalation` | `approval_id`, `level` (GDKD/BOD), `triggered_at`, `resolved_at`, `resolver_id` | FK → `gate_approval.id`, `users.id` | Sinh tự động bởi SLA clock; không xóa |
| `activation_hold` | `contract_id`, `reason` (nsqc_below_100), `released_at`, `released_by_evidence` | FK → hợp đồng (REQ-SALES-007) | Financial Hard Stop — block API tạo chiến dịch |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Gate 1 thiếu entry condition | Deal chưa có NDA mutual signed | SM mở Gate 1 | `ENTRY_FAILED` kèm mục thiếu; không thể ký; sales không được trigger nhận Full Brief khi chưa NDA | [ ] |
| SC-002: Ký Gate 1 khóa qualifiedTier | Gate 1 đủ điều kiện, Tier C | SM (≠ chủ deal) ký Go/No-Go trong 1 ngày làm việc | `qualifiedTier` → `LOCKED`; request đổi tier sau đó bị từ chối; audit log ghi chữ ký | [ ] |
| SC-003: Cấm tự duyệt deal của mình | SM đồng thời là chủ deal | SM thử ký Gate 1 | API từ chối "signer = owner"; escalation GDKD đề xuất người ký khác | [ ] |
| SC-004: Gate 2 chặn package <100% | Package đạt 92% | SM thử ký Gate 2 | Gate không mở; hiển thị thiếu mục + responsible + due date; capacity = 0 cũng chặn + cảnh báo GDKD + OPS_PLAN | [ ] |
| SC-005: AM xác nhận Gate 2 SLA 4h | SM đã ký, package 100% | AM xác nhận / để quá 4h | `GATE_PASSED` khi xác nhận đúng hạn; quá 4h → escalate tự động + log | [ ] |
| SC-006: Chưa nạp đủ 100% NSQC | Gate 2 pass nhưng FIN chưa xác nhận nạp đủ | Cố ý tạo chiến dịch | Hợp đồng "chờ kích hoạt"; API tạo chiến dịch bị block tầng máy; nhả block khi FIN xác nhận đủ nạp | [ ] |
| SC-007: AM từ chối Gate 2 | Package có thiếu sót AM phát hiện | AM từ chối với lý do | Deal trả về SM khắc phục; credit nhận flag tạm dừng; ký lại chỉ sau khi khắc phục | [ ] |
| SC-008: Override knockout + ký mobile | Deal chiến lược fail K2; SM nhận push MOBILE | GDKD duyệt override; SM ký trên MOBILE | Override chỉ qua khi có văn bản + GDKD duyệt, log bất biến; chữ ký mobile hợp lệ qua engine CORE với MFA + token device; thiếu MFA → từ chối + alert | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-SALES-004 (Gate 1 SLA 1 ngày, Gate 2 SLA 4h + nạp 100%, cấm tự duyệt, override knockout, escalate tự động).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) gate_approval, gate_entry_check, activation_hold | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (GateApprovalService, e-approval, escalation, activation hold) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (WEB duyệt, MOBILE ký MFA, FIN hard stop, REQ-SALES-008/009) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI duyệt (WEB) và app ký (MOBILE — counterparts) | `phase4-ux/SYS-BCERP-WEB/MOD-CRM-PIPELINE/[screen-group].md`, `phase4-ux/SYS-MOBILE-INTERNAL/...` |
| Nghiệp vụ gốc & business rules đầy đủ | `phase1-business/departments/sales/sales.md` (B.4), `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` §2.5–§2.6 + §3, `08_Ma_tran_RACI_Gate_SLA.md` §2 `[KXN-19 — ma trận RACI còn chờ xác nhận]` |
