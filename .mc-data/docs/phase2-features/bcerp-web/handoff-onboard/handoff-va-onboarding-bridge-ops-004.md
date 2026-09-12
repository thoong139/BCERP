# Tính Năng: Handoff & Onboarding Bridge

> **Dựa trên:** REQ-OPS-004 trong `phase1-business/departments/operations/operations.md` (Phần A)
> **Phân hệ:** Vận hành — Handoff & Onboarding Bridge (SYS-BCERP-WEB)
> **Module:** Handoff & Onboarding (MOD-HANDOFF-ONBOARD)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Fan-out:** REQ-OPS-004 có ở 3 hệ thống (SYS-CORE-BACKEND, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL). File này là **bản riêng cho SYS-BCERP-WEB** — web nội bộ responsive (Next.js): form/list/workflow UI, gọi API core, hiển thị đúng machine-state. Workflow gate, tự sinh dự án, SLA clock, escalation enforce ở service layer SYS-CORE-BACKEND; AM xác nhận SLA 4h khi di chuyển và nhận push trượt mốc qua SYS-MOBILE-INTERNAL. Counterpart: REQ-SALES-008 — góc soạn package của Sales (`handoff-va-onboarding-bridge.md`), là **nguồn package đầu vào**.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-HONB-002 |
| Module | MOD-HANDOFF-ONBOARD |
| Yêu cầu nghiệp vụ | REQ-OPS-004 (cross-dependency: REQ-SALES-008 — nguồn package từ Sales) |
| Người dùng liên quan | OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (phối hợp SALES_L3) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | REQ-SALES-008 (package do Sales soạn — đầu vào bắt buộc); REQ-SALES-004 (Gate 2/QUALIFIED); REQ-OPS-007 (capacity check); REQ-OPS-010 (portal — mốc activation) |
| Ghi chú Expert (A7) | `operations.md` mục A7 đang chờ expert điền — chưa có điều chỉnh cho REQ-OPS-004 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép OPS (đầu mối OPS_AM) **tiếp nhận Handoff Package 5 nhóm checklist** do Sales bàn giao tại Gate 2/QUALIFIED qua ký 3 bên (SM ký + hệ thống tự sinh dự án + AM xác nhận SLA 4h), sau đó **thực thi và theo dõi onboarding theo milestone Day 1/7/14/30** checklist có tiêu chí đạt/fail, kèm cảnh báo trượt mốc và escalation. Đây là nửa "nhận bàn giao" của cầu nối Sales → OPS: từ lúc AM xác nhận, đồng hồ onboarding bắt đầu, trách nhiệm vận hành chuyển về OPS.

**Phạm vi:**
- Bao gồm: màn hình tiếp nhận package 5 nhóm (góc nhận bàn giao: hợp đồng & phạm vi, tài sản QC & tracking, mục tiêu & baseline KPI, vận hành, điều kiện khởi động); e-approval ký 3 bên SLA 4h, escalation TL rồi HR_L2 (8h); xác nhận capacity gắn Gate 2; khởi tạo TKQC theo demand; checklist milestone Day 1/7/14/30 pass/fail; luồng deploy D+0→D+5 (Planning TT→ĐH→AD, Kick-off nội bộ D+1/D+2, Kick-off KH D+3 ký 6 Communication Rules, ONGOING D+5); quay thiếu sót Day 1–30 về SM Sales theo package.
- Không bao gồm: soạn package (Sales — REQ-SALES-008); engine gate/SLA/tự sinh dự án (SYS-CORE-BACKEND); bề mặt khách activation portal (REQ-OPS-010 — WEB chỉ theo dõi trạng thái); vận hành chiến dịch chi tiết và lệnh ví TKQC (REQ-OPS-001/003/006).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Nhận yêu cầu tiếp nhận package mới trên queue, xem đủ 5 nhóm checklist | Chỉ nhận việc trong phạm vi package đã chốt, không nhận handoff miệng/chat |
| 2 | OPS_AM | Xác nhận/từ chối tiếp nhận trong SLA 4h, có bộ đếm thời gian | Đồng hồ onboarding bắt đầu đúng mốc, không tranh chấp mốc bàn giao |
| 3 | OPS_AM | Đánh dấu mốc Day 1/7/14/30 đạt/chưa đạt theo tiêu chí có sẵn | Nghiệm thu onboarding có căn cứ khách quan |
| 4 | OPS_AM | Thấy trạng thái kích hoạt portal (CLIENT_ADMIN, % user kích hoạt, 2FA, login/tuần) trong mốc Day 1/7/14 | Bắt đúng GATE Day 14, escalate kịp khi khách chậm kích hoạt |
| 5 | OPS_PLAN | Xác nhận capacity trống gắn Gate 2 và nhận cảnh báo khi capacity = 0 | Không nhận dự án thiếu nguồn lực, cân đối đầu người trước D+0 |
| 6 | OPS_ADS | Nhận demand khởi tạo TKQC theo đúng scope sau khi dự án được sinh | Chuẩn bị tài nguyên trước D+4, tránh lùi ONGOING D+5 |
| 7 | OPS_CONT/OPS_DES/OPS_EDIT | Thấy plan chốt nội bộ D+1/D+2 và phân công phần việc sau Kick-off | Sản xuất đúng brief, đúng lịch ngay tuần đầu |
| 8 | Trưởng nhóm OPS (queue quản lý) | Nhận escalate khi AM quá SLA 4h (và HR_L2 ở 8h), và khi mốc trượt | Can thiệp sớm, phân bổ lại nguồn lực |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer xử lý đúng trong code. WEB hiển thị machine-state do CORE trả về; chặn/validate enforce ở service layer.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-HONB-201 | Tiếp nhận **Handoff Package 5 nhóm checklist** — Gate 2 chỉ mở khi checklist **100%** (<100% chặn, CORE đếm tự động). 5 nhóm góc nhận bàn giao (BR-OPS-3.1): **(1) Hợp đồng & phạm vi dịch vụ** (tier, SLA, ngân sách); **(2) Tài sản QC & tracking** (TKQC + quyền truy cập, pixel/CAPI/UTM, creative assets, brand guideline); **(3) Mục tiêu & baseline KPI** (conversion/traffic/awareness); **(4) Vận hành** (POC khách, ngôn ngữ/múi giờ, lịch họp, lịch làm việc khách); **(5) Điều kiện khởi động** (capacity check, Brand Safety, demand TKQC). | Package <100% không đến queue AM; nhận việc ngoài checklist không được ghi nhận là bàn giao |
| BR-HONB-202 | **Ký 3 bên:** SM (SALES_L3) ký + hệ thống tự sinh dự án + **OPS_AM xác nhận trong SLA 4h làm việc** — từ lúc AM xác nhận, đồng hồ onboarding bắt đầu. Signature event ghi audit trail. Quá SLA → **escalate TL, rồi HR_L2 ở mốc 8h**. | Quá 4h → SLA đỏ + escalate tự động; AM từ chối → trả về SM Sales khắc phục, credit hoa hồng tạm dừng đến khi handoff lại thành công |
| BR-HONB-203 | **Capacity check "xác nhận Capacity trống" gắn Gate 2** — SLA 4h; quá hạn escalate TL rồi HR_L2 (8h). WON → tự sinh dự án + AM xác nhận capacity **trước DEPLOY**; khởi tạo TKQC theo demand khách. | Không xác nhận capacity → không mở DEPLOY; demand TKQC không khớp scope → chặn khởi tạo, báo AM đối chiếu nhóm (5) |
| BR-HONB-204 | **Milestone onboarding Day 1/7/14/30** checklist pass/fail (BR-OPS-3.2) — Day 1: map 100% TKQC vào registry + audit naming/UTM/quyền, tạo CLIENT_ADMIN đầu tiên + gửi invite; Day 7: tracking chạy (≥1 conversion test), ≥80% portal user kích hoạt, 2FA 100%; Day 14: **GATE "khách kích hoạt portal thành công"** (khách tự xem số dư + chi tiêu + ticket; ≥1 login/tuần từ ≥2 user); Day 30: review số liệu 30 ngày đầu vs baseline + kế hoạch tối ưu. | Mốc fail → cảnh báo trượt kèm owner khắc phục; **trượt GATE Day 14 → escalate root cause lên CS TL trong 24h, kế hoạch khắc phục có owner + deadline**; GATE Day 14 là điều kiện nghiệm thu onboarding |
| BR-HONB-205 | **6 Communication Rules ký tại Kick-off KH D+3** (hard gate): Rule 1 — đầu mối duy nhất là AM; Rule 2 — kênh lưu vết bắt buộc (Email/Portal cho yêu cầu chính thức, Zalo chỉ vận hành thường ngày); Rule 3 — budget & targeting luôn cần xác nhận rõ của khách; Rule 4 — Im lặng = Đồng ý sau 24h (không áp budget/targeting); Rule 5 — lịch báo cáo & họp cố định theo reporting frequency, đổi lịch báo trước 24h; Rule 6 — báo cáo gửi cả 3 kênh Zalo + Email + Portal. Rules 1/2/3/5 dùng **bản dự thảo nội bộ đã được chủ dự án duyệt (12/09)** — form ký gắn nhãn "dự thảo nội bộ — chờ khách hàng xác nhận chính thức" `[KXN-11]`. | Không hoàn tất Kick-off D+3 khi thiếu chữ ký 6 Rules; khách từ chối → AM giải thích từng rule → còn không → AD negotiate, ghi exception |
| BR-HONB-206 | **Deploy timeline D+0→D+5** (KXN-10 — Deploy tái dựng từ v2.3 đã phê chuẩn): **D+0** kích hoạt khi **tiền vào TK + Accountant (FIN_L1) confirm trong 4h làm việc + LOI hoặc HĐ đã ký** (KXN-5; HĐ đầy đủ chậm nhất 7 ngày sau D+0, quá 3 ngày chưa upload → cảnh báo); **Planning sơ bộ theo flow TT→ĐH→AD hoàn thành trong ngày D+0** (AM soạn, Planner review); **checklist tài nguyên hoàn tất trước D+4**; Kick-off nội bộ D+1/D+2 không lùi; **ONGOING bắt đầu D+5** — lùi nếu tài nguyên chưa đủ. | Thiếu tiền → không có D+0; tiền thiếu so với phase 1 → chưa trigger D+0; tài nguyên thiếu sau D+4 → "D+5 lùi" + lý do; KH không book D+3 sau 3 slot → AD contact, D+5 tự lùi |
| BR-HONB-207 | **Thiếu sót Day 1–30 quay về SM Sales** khắc phục theo đúng mục package; OPS không nhận việc ngoài package — handoff miệng/chat không được công nhận. Thiếu sót gắn đúng `handoff_checklist_item` + due date. | Nhận việc ngoài package phải mở exception có SM duyệt; không ghi nhận qua Zalo/chat là hoàn thành |
| BR-HONB-208 | Khách tái ký rút gọn Initial Brief nhưng **không bỏ Gate 1/Gate 2** — tiếp nhận vẫn qua đủ ký 3 bên và checklist 100% (prefill từ deal trước). | Bỏ Gate 2 ở deal tái ký → API từ chối; chạy lại luồng đầy đủ |

**Giả định chờ xác nhận (tag, không tự quyết):** `[KXN-19]` Ma trận RACI chưa được khách xác nhận — vai gác mốc D+0→D+5 có thể điều chỉnh; `[KXN-9]` track ad account/top-up trên checklist tài nguyên thuộc CMS "tương lai" — hiện chỉ track request quyền; `[KXN-20]` cờ cảnh báo K6–K12 chưa chốt — hiển thị tập cờ đã có nguồn; `[KXN-6]`/`[KXN-7]` tiêu chí Evaluation và 16 sections Strategic Brief làm baseline nhóm (3) chưa chốt — form giữ cấu trúc mở.

---

## 4. Phân Quyền

| Hành động | OPS_AM | OPS_PLAN | OPS_CONT / OPS_DES / OPS_EDIT | OPS_ADS | SYS_ADMIN |
|-----------|--------|----------|-------------------------------|---------|-----------|
| Xem queue package | ✅ | ✅ | ❌ | ❌ | ✅ |
| Xem package dự án mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xác nhận/từ chối tiếp nhận (chặng AM) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận capacity trống (gắn Gate 2) | ❌ | ✅ | ❌ | ❌ | ❌ |
| Đánh giá mốc Day 1/7/14/30 | ✅ | ❌ (xem) | ❌ (hạng mục phụ trách) | ❌ (hạng mục phụ trách) | ❌ |
| Cập nhật checklist tài nguyên / khởi tạo TKQC | ✅ (duyệt) | ❌ | ❌ | ✅ | ❌ |
| Ghi nhận thiếu sót Day 1–30 quay về SM | ✅ | ✅ | ✅ (đề xuất) | ✅ (đề xuất) | ❌ |
| Xem timeline D+0→D+5 và 6 Rules | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xử lý escalate SLA 4h/8h | ❌ | ✅ (TL/plan) | ❌ | ❌ | ✅ (có log) |
| Cấu hình tiêu chí mốc / template | ❌ | ❌ | ❌ | ❌ | ✅ (có phê duyệt) |

*Ranh giới: Sales xem dashboard milestone phía Sales theo REQ-SALES-008 — không thao tác tiếp nhận; trách nhiệm CX Head gán về OPS_PLAN theo quyết định stakeholder 12/09 (không dùng OPS_CX); portal khách thuộc REQ-OPS-010.*

---

## 5. Trường Hợp Đặc Biệt

- **AM quá SLA 4h không xác nhận:** escalate TL; quá 8h → HR_L2 cân đối đầu người; xác nhận muộn vẫn ghi audit trail.
- **Package bị AM từ chối:** trả về SM Sales khắc phục đúng mục thiếu; credit hoa hồng deal tạm dừng đến khi handoff lại thành công; lần tiếp nhận lại tạo vòng ký mới, giữ lịch sử.
- **Khách chưa có fanpage/ad account:** AM hỗ trợ tạo mới, hướng dẫn → D+5 lùi đến khi setup xong.
- **KH chậm cấp quyền tài nguyên:** nhắc hàng ngày qua Zalo → quá 3 ngày AM gọi → quá 5 ngày AD contact KH; item thiếu ghi deadline cho KH.
- **Khách từ chối ký 6 Communication Rules tại D+3:** AM giải thích từng rule → không được → AD negotiate → ghi exception; D+5 lùi theo nếu trễ.
- **Tiền vào thiếu so với phase 1:** Accountant (FIN_L1) báo AM ngay → AM contact khách clarify → chưa trigger D+0 đến khi đủ số.
- **Trượt GATE Day 14:** escalate root cause lên CS TL trong 24h, kế hoạch khắc phục có owner + deadline; không nghiệm thu khi gate chưa pass.
- **Nhóm content/design/edit thiếu resource sau D+1:** AM escalate AD ngay → thuê thêm / thu hẹp scope / lùi timeline — quyết định ghi nhận trên dự án.
- **Nhân sự OPS phụ trách nghỉ giữa Day 1–30:** chuyển giao hạng mục checklist + mốc còn mở trong nhóm (OPS_PLAN duyệt), giữ lịch sử đánh giá.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Onboarding của dự án (tiếp nhận package → ONGOING ổn định)

**Sơ đồ trạng thái:**
```
[WAIT_HANDOFF] ──(SM ký)──► [PENDING_AM_CONFIRM — SLA 4h] ──(AM xác nhận)──► [ONBOARDING]
                                │                                            │
                                │ (quá 4h → TL → HR_L2 8h)                  │ (D+0 → D+1/2 → D+3 → D+5)
                                ▼                                            ▼
                          [ESCALATED] ──(xử lý xong)──► [PENDING_AM_CONFIRM]  [DEPLOY D+0→D+5] ──(đủ tài nguyên)──► [ONGOING]
                                │                                            │
                                │ (AM từ chối)                     (Day 1/7/14/30 pass)
                                ▼                                            ▼
                        [RETURNED_TO_SALES]                        [ONBOARDING_STABLE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `WAIT_HANDOFF` | SM ký Handoff | `PENDING_AM_CONFIRM` | SM (SALES_L3) | Checklist 5 nhóm = 100% |
| `PENDING_AM_CONFIRM` | AM xác nhận | `ONBOARDING` | OPS_AM | Trong SLA 4h làm việc; tự sinh dự án |
| `PENDING_AM_CONFIRM` | AM từ chối | `RETURNED_TO_SALES` | OPS_AM | Lý do gắn đúng mục checklist; credit tạm dừng |
| `PENDING_AM_CONFIRM` | Quá SLA | `ESCALATED` | Hệ thống | 4h: escalate TL; 8h: escalate HR_L2 |
| `ESCALATED` | Xử lý xong | `PENDING_AM_CONFIRM` | TL / HR_L2 | Ghi nhận quyết định cân đối/phân bổ |
| `ONBOARDING` | D+0 kích hoạt | `DEPLOY D+0→D+5` | Hệ thống (FIN_L1 gác) | Tiền vào + FIN_L1 confirm ≤4h + LOI/HĐ ký (KXN-5); Planning TT→ĐH→AD trong ngày D+0 |
| `DEPLOY D+0→D+5` | Hoàn tất Kick-off D+3 | `DEPLOY D+0→D+5` (D+3 pass) | OPS_AM | 6 Rules khách đã ký `[KXN-11]`; khách login portal ≥1 lần |
| `DEPLOY D+0→D+5` | Vào ONGOING | `ONGOING` | Hệ thống + AM + Media | Đủ tài nguyên (pixel, quyền ad account) trước D+4; thiếu → D+5 lùi |
| `ONGOING` | Day 30 pass | `ONBOARDING_STABLE` | OPS_AM xác nhận | Đủ 4 mốc pass; GATE Day 14 pass |

**Quy tắc:**
- `ONGOING`/`ONBOARDING_STABLE` là trạng thái đích; D+5 chỉ lùi khi tài nguyên chưa đủ — ngày lùi và lý do ghi trên timeline.
- `RETURNED_TO_SALES` không kết thúc entity: vòng tiếp nhận lại bắt đầu từ `WAIT_HANDOFF` sau khi Sales submit lại; vòng cũ giữ làm lịch sử.
- Chuyển trạng thái do CORE thực thi, ghi audit log; WEB render machine-state, không lưu state cục bộ.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `handoff_package` | `deal_id`, `project_id`, `status`, `sm_signed_at`, `am_confirmed_at`, `am_sla_deadline`, `escalation_level` | FK → `deals.id`, `projects.id` | Dùng chung với REQ-SALES-008; CORE quản machine-state |
| `handoff_checklist_item` | `package_id`, `group_no` (1–5), `name`, `responsible_id`, `due_date`, `status`, `defect_return_id` | FK → `handoff_package.id` | 5 nhóm theo BR-OPS-3.1; thiếu sót Day 1–30 gắn về đây |
| `onboarding_milestone` | `project_id`, `day_no` (1/7/14/30), `criteria_json`, `status`, `evidence_url`, `owner_fix`, `fix_deadline` | FK → `projects.id` | Day 14 = GATE portal; fail → escalate CS TL 24h |
| `deploy_timeline_event` | `project_id`, `event` (D0/PLANNING/KICKOFF_INT_1/2/KICKOFF_CLIENT/ONGOING), `planned_day`, `actual_at`, `delay_reason` | FK → `projects.id` | D+0 cần tiền + LOI/HĐ (KXN-5); ONGOING D+5 (KXN-10) |
| `communication_rules_acceptance` | `project_id`, `rules_version`, `signed_by_client_at`, `is_draft_internal` | FK → `projects.id` | Hard gate D+3; Rules 1/2/3/5 gắn nhãn dự thảo `[KXN-11]` |
| `resource_readiness_item` | `project_id`, `item` (pixel/quyền BM/Google/TikTok...), `requested_at`, `received_at`, `state` | FK → `projects.id` | Đích: đủ trước D+4; `[KXN-9]` track ad account thuộc CMS tương lai |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ; chi tiết ở Phase 5; map REQ-OPS-004.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-101: Tiếp nhận đúng SLA 4h | Package 100% đã SM ký | AM xác nhận trong 4h làm việc | `ONBOARDING`; tự sinh dự án; đồng hồ onboarding bắt đầu từ timestamp xác nhận | [ ] |
| SC-102: Escalate quá SLA | AM chưa xác nhận sau 4h | Hệ thống chạy escalation | SLA đỏ + escalate TL; quá 8h escalate HR_L2; audit trail đủ mốc | [ ] |
| SC-103: Từ chối tiếp nhận | Package nhóm (2) thiếu quyền truy cập | AM từ chối có lý do | `RETURNED_TO_SALES` gắn đúng mục thiếu; credit deal tạm dừng; lịch sử giữ nguyên | [ ] |
| SC-104: Mốc Day 1 pass/fail | Dự án vừa được sinh | AM đánh giá Day 1 | 100% TK map đúng naming/owner/backup + CLIENT_ADMIN tạo → PASS; TK không map được → FAIL kèm owner khắc phục | [ ] |
| SC-105: GATE Day 14 trượt | Chưa đạt ≥1 login/tuần từ ≥2 user | Mốc Day 14 đánh giá FAIL | Escalate root cause lên CS TL trong 24h; kế hoạch khắc phục có owner + deadline; không nghiệm thu | [ ] |
| SC-106: Kick-off D+3 thiếu chữ ký Rules | Khách chưa ký đủ 6 Rules | AM cố hoàn tất mốc | Bị chặn; Rules 1/2/3/5 nhãn "dự thảo nội bộ" `[KXN-11]`; exception qua AD negotiate | [ ] |
| SC-107: D+0 chưa kích hoạt thiếu LOI/HĐ | Tiền đã vào, FIN_L1 confirm, chưa có LOI/HĐ | Xem timeline | D+0 không kích hoạt; cảnh báo pháp lý; HĐ chậm 3 ngày → cảnh báo `hasContractWarning` | [ ] |
| SC-108: D+5 lùi do thiếu tài nguyên | Còn pixel chưa lắp sau D+4 | Hệ thống đánh giá mốc D+5 | "ONGOING lùi" kèm lý do; timeline ghi ngày lùi; mốc sau tính lại | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (gate, tự sinh dự án, SLA clock — enforce tại SYS-CORE-BACKEND; push di động qua SYS-MOBILE-INTERNAL) |
| Màn hình UI | `phase4-ux/bcerp-web/handoff-onboard/[screen-group].md` |
| Bản góc Sales | `phase2-features/bcerp-web/handoff-onboard/handoff-va-onboarding-bridge.md` |
| Nguồn quy trình | `documents/quy-trinh-lam-viec/` v1.1 (file 02 — Handoff/Gate 2 KXN-4; file 04 — Deploy D+0→D+5; file 08 — RACI/SLA; file 09 — 6 Rules §4; file 10 §4 — khoản [KXN] còn mở) |
