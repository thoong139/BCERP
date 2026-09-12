# Tính Năng: Handoff & Onboarding Bridge

> **Dựa trên:** REQ-SALES-008 trong `phase1-business/departments/sales/sales.md` (Phần A)
> **Phân hệ:** Sales — Handoff & Onboarding Bridge (SYS-BCERP-WEB)
> **Module:** Handoff & Onboarding (MOD-HANDOFF-ONBOARD)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Fan-out:** REQ-SALES-008 có ở 3 hệ thống (SYS-CORE-BACKEND, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL). File này là **bản riêng cho SYS-BCERP-WEB** — web nội bộ responsive (Next.js): form/list/workflow UI, gọi API core, hiển thị đúng machine-state. Chặn Gate 2, SLA clock, tự sinh dự án enforce ở service layer SYS-CORE-BACKEND; ký/push trên SYS-MOBILE-INTERNAL. Counterpart: REQ-OPS-004 — góc tiếp nhận của OPS (`handoff-va-onboarding-bridge-ops-004.md`).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-HONB-001 |
| Module | MOD-HANDOFF-ONBOARD |
| Yêu cầu nghiệp vụ | REQ-SALES-008 (cross-dependency: REQ-OPS-004 — Sales bàn giao, OPS tiếp nhận) |
| Người dùng liên quan | SALES_L1, SALES_L2, SALES_L3, SALES_L4, SALES_L5 (hợp tác: OPS_AM) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | REQ-SALES-004 (Gate 2 — điểm ký Handoff); REQ-OPS-007 (capacity check); REQ-SALES-005 (WON — tự sinh dự án) |
| Ghi chú Expert (A7) | `sales.md` mục A7 đang chờ expert điền — chưa có điều chỉnh ảnh hưởng REQ-SALES-008 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép NVKD chủ deal (SALES_L1–L2) soạn và hoàn thiện **Handoff Package 5 nhóm checklist** trên web nội bộ, trình SM (SALES_L3) ký tại Gate 2/QUALIFIED, sau đó **theo dõi milestone onboarding Day 1/7/14/30** đến khi onboarding ổn định. Đây là cầu nối bàn giao có kiểm soát Sales → OPS: mọi nội dung bàn giao phải nằm trong package trên hệ thống — handoff miệng/chat không được công nhận (hard gate "Không ghi nhận = Không tồn tại", BR-SALES-000).

**Phạm vi:**
- Bao gồm: soạn Handoff Package 5 nhóm checklist (mỗi mục có responsible + due date); hiển thị % hoàn thiện và chặn Gate 2 nếu <100% (chặn hiển thị ở WEB, enforce ở CORE); luồng ký 3 bên NVKD soạn → SM ký → OPS_AM xác nhận SLA 4h; dashboard milestone Day 1/7/14/30 kèm trạng thái kích hoạt portal của khách (đọc từ CORE); cảnh báo capacity trống = 0 cho GDKD (SALES_L5) + OPS_PLAN trước khi ký Gate 2; hiển thị deploy timeline D+0→D+5 và trạng thái 6 Communication Rules.
- Không bao gồm: engine chặn Gate 2, SLA clock, tự sinh dự án khi WON (SYS-CORE-BACKEND — WEB chỉ hiển thị và gọi API); push ký/cảnh báo trượt mốc (SYS-MOBILE-INTERNAL, từ Phase2); thực thi onboarding và vận hành chiến dịch (REQ-OPS-004); vận hành portal khách (REQ-OPS-010).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | NVKD chủ deal (SALES_L1–L2) | Soạn Handoff Package theo checklist 5 nhóm, gán responsible + due date từng mục | Bàn giao đầy đủ, không bỏ sót khi chuyển deal sang OPS |
| 2 | NVKD chủ deal (SALES_L1–L2) | Thấy % hoàn thiện checklist và mục còn thiếu (responsible + due date) trước khi trình Gate 2 | Biết chính xác phải bổ sung gì thay vì bị chặn mù |
| 3 | NVKD chủ deal (SALES_L1–L2) | Nhận cảnh báo khi capacity trống = 0 trước khi ký Gate 2 | Không ký deal không có người chạy; kịp escalate GDKD + OPS_PLAN |
| 4 | SM (SALES_L3) | Xem hồ sơ deal + checklist + capacity check trên một màn hình duyệt Gate 2 và ký Handoff | Quyết định Go/No-Go nhanh, đủ căn cứ, đúng SLA |
| 5 | SALES_L4/SALES_L5 (TPKD/GDKD) | Xem dashboard package chờ ký, bị trả về và cảnh báo capacity | Giám sát queue bàn giao, can thiệp khi deal ùn hoặc thiếu nguồn lực |
| 6 | NVKD chủ deal (SALES_L1–L2) | Theo dõi milestone Day 1/7/14/30, thấy rõ mốc pass/fail và lý do | Biết điểm chưa bàn giao xong để khắc phục, giữ chữ T khách |
| 7 | SM (SALES_L3) | Nhận danh sách thiếu sót Day 1–30 quay về từ OPS gắn đúng mục package | Xử lý gốc rễ theo đúng phạm vi package đã ký |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. WEB hiển thị đúng machine-state do CORE trả về; mọi hành động ghi gọi API core và nhận validate từ service layer.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-HONB-101 | Handoff Package gồm **đúng 5 nhóm checklist bắt buộc** theo chuẩn chốt tại Gate 2/QUALIFIED (KXN-4): (1) Hồ sơ KH — pháp nhân, đầu mối chính + dự phòng, full brief; (2) Tài chính — dự toán phí dịch vụ, NSQC ước tính, phương thức thanh toán; (3) Kỳ vọng & Scope — KPI không cam kết cứng, phạm vi kênh sơ bộ; (4) Nội bộ — phân bổ AM chính thức, xác nhận Capacity trống; (5) Pháp lý & Rủi ro — không vướng policy/tranh chấp. Mỗi mục có responsible + due date. | Không cho trình Gate 2; màn hình liệt kê đúng mục nào thiếu, nhóm nào, responsible là ai |
| BR-HONB-102 | Checklist phải đạt **100%** mới mở được Gate 2 — CORE tự đếm % và chặn; <100% chặn ở cả UI (vô hiệu nút) và API (từ chối request). | Deal dừng ở QUALIFIED, không chuyển tiếp đến khi đủ 100% |
| BR-HONB-103 | **Ký 3 bên tại Gate 2/QUALIFIED:** NVKD chủ deal soạn → SM (SALES_L3) ký Handoff → OPS_AM xác nhận tiếp nhận trong **SLA 4h làm việc**; từ lúc AM xác nhận, đồng hồ onboarding bắt đầu. Signature event ghi audit trail (thời gian, người ký, kênh). | Quá 4h → escalate tự động (hiển thị SLA đỏ trên WEB); AM từ chối → trả về SM khắc phục, credit hoa hồng tạm dừng đến khi handoff lại thành công |
| BR-HONB-104 | Handoff ngoài package (miệng/chat/Zalo) **không được công nhận** — mọi nội dung bàn giao phải là mục checklist trên hệ thống trước khi phát sinh hệ quả. | Tranh chấp "đã bàn giao" không có bản ghi trên package không được chấp nhận khi xử lý thiếu sót |
| BR-HONB-105 | Sau khi AM xác nhận, hệ thống theo dõi **milestone Day 1/7/14/30** dạng checkpoint có tiêu chí đạt; mốc **Day 14 là GATE "khách kích hoạt portal thành công"** — điều kiện nghiệm thu giai đoạn onboarding. WEB hiển thị trạng thái từng mốc + cảnh báo trượt. | Mốc fail → cảnh báo trượt với owner khắc phục; trượt GATE Day 14 → escalate root cause lên CS TL trong 24h, kế hoạch khắc phục có owner + deadline |
| BR-HONB-106 | WON → hệ thống tự sinh dự án + OPS_AM xác nhận capacity trong **24h** — điều kiện mở stage DEPLOY. **Capacity trống = 0 → cảnh báo GDKD (SALES_L5) + OPS_PLAN trước khi ký Gate 2** để tránh ký deal không người chạy. | Chưa có capacity xác nhận → không mở bước tiếp theo của deploy timeline; ký Gate 2 khi capacity = 0 phải có cảnh báo được ghi nhận |
| BR-HONB-107 | **6 Communication Rules được ký tại Kick-off khách hàng D+3** trong deploy timeline. Rules 1, 2, 3, 5 dùng **bản dự thảo nội bộ đã được chủ dự án duyệt làm chuẩn nội bộ (12/09)** — form ký gắn nhãn "dự thảo nội bộ — chờ khách hàng xác nhận chính thức" `[KXN-11]`; khi khách cung cấp bản chính thức sẽ thay thế ở quy trình v1.2 (đổi nội dung cấu hình, không đổi luồng). | Không hoàn tất Kick-off D+3 nếu thiếu chữ ký xác nhận 6 Rules của khách; khách từ chối ký → exception để AD negotiate |
| BR-HONB-108 | **Deploy timeline D+0→D+5** hiển thị theo machine-state: D+0 kích hoạt khi **tiền vào TK + Accountant (FIN_L1) confirm trong 4h làm việc + LOI hoặc HĐ đã ký** (KXN-5; HĐ đầy đủ chậm nhất 7 ngày sau D+0, quá 3 ngày chưa upload → cảnh báo `hasContractWarning`); Planning sơ bộ theo flow **TT→ĐH→AD hoàn thành trong ngày D+0**; checklist tài nguyên hoàn tất **trước D+4**; Kick-off nội bộ D+1/D+2 không lùi; **ONGOING bắt đầu D+5** (KXN-10 — Deploy tái dựng từ Lifecycle v2.3 đã phê chuẩn làm quy định chính thức). D+5 lùi nếu tài nguyên chưa sẵn sàng. | Thiếu tiền → không có D+0, timeline không khởi động; tiền vào nhưng thiếu (chưa đủ phase 1) → không trigger D+0 đến khi đủ; tài nguyên thiếu sau D+4 → hiển thị "D+5 lùi" với lý do |
| BR-HONB-109 | Trạng thái kích hoạt portal của khách (CLIENT_ADMIN, số user kích hoạt, ≥1 login/tuần) **hiển thị trong milestone, đọc từ CORE** — sales không vận hành portal từ WEB. | WEB không cấp nút thao tác portal cho vai Sales; dữ liệu portal read-only trong dashboard |
| BR-HONB-110 | Thiếu sót trong **Day 1–30** → hệ thống quay danh sách khắc phục về SM gắn đúng mục package; OPS không nhận việc ngoài package. | Thiếu sót ngoài phạm vi 5 nhóm phải mở exception có SM duyệt, không tự gán vào package đã ký |

**Giả định chờ xác nhận (tag, không tự quyết):** `[KXN-19]` Ma trận RACI chưa được khách xác nhận — phân công trên màn hình Gate 2/SLA có thể điều chỉnh; `[KXN-7]` cấu trúc 16 sections Strategic Brief cho "full brief" nhóm (1) chưa chốt — form giữ cấu trúc mở; `[KXN-9]` track ad account/top-up trên checklist tài nguyên thuộc CMS "tương lai" — hiện chỉ track trạng thái request quyền; `[KXN-20]` danh sách cờ cảnh báo K6–K12 chưa chốt — hiển thị tập cờ đã có nguồn.

---

## 4. Phân Quyền

| Hành động | SALES_L1–L2 (NVKD) | SALES_L3 (SM) | SALES_L4 (TPKD) | SALES_L5 (GDKD) | SYS_ADMIN |
|-----------|--------------------|---------------|-----------------|-----------------|-----------|
| Xem package của mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem package nhóm/phòng/toàn bộ | ❌ | ✅ (nhóm) | ✅ (phòng) | ✅ (toàn bộ) | ✅ |
| Soạn/sửa package (deal mình) | ✅ | ❌ | ❌ | ❌ | ❌ (qua quy trình hỗ trợ có log) |
| Trình Gate 2 (submit checklist) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Ký Gate 2 — Handoff | ❌ | ✅ | ❌ | ❌ | ❌ |
| Sửa package sau khi bị trả về | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xem dashboard milestone Day 1/7/14/30 | ✅ (deal mình) | ✅ (nhóm) | ✅ | ✅ | ✅ |
| Xem trạng thái portal (read-only từ CORE) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xử lý thiếu sót Day 1–30 quay về | ✅ | ✅ (phân công lại) | ❌ | ❌ | ❌ |
| Cấu hình template checklist / SLA | ❌ | ❌ | ❌ | ❌ | ✅ (có phê duyệt) |

*OPS_AM không thao tác trên bản WEB này (xác nhận SLA 4h và thực thi onboarding thuộc bản REQ-OPS-004 và kênh SYS-MOBILE-INTERNAL); dữ liệu capacity đọc từ module Capacity & Timesheet (REQ-OPS-007).*

---

## 5. Trường Hợp Đặc Biệt

- **AM từ chối tiếp nhận:** package trả về SM/NVKD khắc phục theo đúng mục thiếu; credit hoa hồng deal tạm dừng đến khi handoff lại thành công; quá SLA 4h → escalate tự động (queue SM/L4/L5).
- **Capacity trống = 0:** chặn trình ký Gate 2 bằng cảnh báo cho GDKD (SALES_L5) + OPS_PLAN; chỉ ký được khi capacity đã xác nhận có người chạy.
- **Khách tái ký:** rút gọn Initial Brief nhưng **không bỏ Gate 1/Gate 2** — checklist vẫn phải 100%, form prefill từ deal trước.
- **Deal trả về từ Gate 2 tạm dừng credit hoa hồng:** trạng thái "tạm dừng — chờ handoff lại" hiển thị trên deal đến khi handoff lại thành công (REQ-SALES-009).
- **Khách chưa có fanpage/ad account hoặc chậm cấp quyền:** AM hỗ trợ tạo mới/hướng dẫn; nhắc hàng ngày qua Zalo → quá 3 ngày AM gọi → quá 5 ngày AD contact khách; D+5 lùi đến khi setup xong.
- **Tiền vào nhưng thiếu so với phase 1:** Accountant báo ngay, AM contact khách clarify; **chưa trigger D+0** đến khi đủ số — timeline giữ "chờ đủ tiền".
- **HĐ chưa ký sau D+0:** cảnh báo sau 3 ngày (`hasContractWarning`) cho AM + AD; HĐ đầy đủ chậm nhất 7 ngày sau D+0 (KXN-5); LOI đủ điều kiện kích hoạt D+0 nhưng HĐ phải hoàn tất sau.
- **Kick-off KH D+3 không book được lịch:** AM đề xuất 3 slot → vẫn không được → AD contact → D+5 tự động lùi; khách từ chối ký 6 Rules → AM giải thích → còn không → AD negotiate, ghi exception.
- **Nhân sự phụ trách nghỉ giữa Day 1–30:** chuyển giao responsible các mục còn thiếu/trượt mốc trong nhóm (SM duyệt), giữ trọn lịch sử bàn giao.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Handoff Package (bản ghi bàn giao của một deal)

**Sơ đồ trạng thái:**
```
[NOT_STARTED] ──(soạn)──► [PREPARING] ──(submit, 100%)──► [SUBMITTED]
                              ▲                              │ (SM ký)
                              │                              ▼
                         [RETURNED] ◄──(AM từ chối)── [PENDING_AM_CONFIRM] ──(AM xác nhận ≤4h)──► [ACCEPTED]
                                                                            │
                                                              (tự sinh dự án + capacity OK)
                                                                            ▼
                                                                   [ONBOARDING] ──(Day 30 pass)──► [STABILIZED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_STARTED` | Bắt đầu soạn | `PREPARING` | NVKD chủ deal (SALES_L1–L2) | Deal đạt Gate 1; template 5 nhóm đã khởi tạo |
| `PREPARING` | Submit | `SUBMITTED` | NVKD chủ deal | Checklist 100%; mỗi mục có responsible + due date; capacity check ≠ 0 |
| `SUBMITTED` | SM ký | `PENDING_AM_CONFIRM` | SM (SALES_L3) | Bắt đầu đếm SLA 4h cho AM |
| `SUBMITTED` / `PENDING_AM_CONFIRM` | SM thu hồi | `RETURNED` | SM (SALES_L3) | Nhập lý do |
| `PENDING_AM_CONFIRM` | AM xác nhận | `ACCEPTED` | OPS_AM (bản REQ-OPS-004/M-INT) | Trong SLA 4h làm việc; hệ thống tự sinh dự án |
| `PENDING_AM_CONFIRM` | AM từ chối | `RETURNED` | OPS_AM | Nhập lý do; credit hoa hồng tạm dừng |
| `RETURNED` | Khắc phục + submit lại | `SUBMITTED` | NVKD chủ deal | Checklist đủ 100%; lịch sử lần trả về giữ nguyên |
| `ACCEPTED` | Chuyển onboarding | `ONBOARDING` | Hệ thống | Capacity xác nhận trong 24h — điều kiện mở DEPLOY |
| `ONBOARDING` | Day 30 pass | `STABILIZED` | Hệ thống + OPS_AM xác nhận | Đủ 4 mốc Day 1/7/14/30 đạt; GATE Day 14 pass |

**Quy tắc:**
- Không quay về trạng thái trước, trừ luồng `RETURNED → SUBMITTED` — mọi lần quay về ghi audit log với lý do.
- `STABILIZED` là trạng thái kết thúc; thiếu sót sau Day 30 xử lý qua ticket, không mở lại package đã chốt.
- Chuyển trạng thái do CORE thực thi; WEB gửi intent và render machine-state, không lưu state cục bộ.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `handoff_package` | `deal_id`, `status`, `completion_pct`, `sm_signed_at`, `am_confirmed_at`, `am_sla_deadline` | FK → `deals.id` | Machine-state do CORE quản; audit log bất biến |
| `handoff_checklist_item` | `package_id`, `group_no` (1–5), `name`, `responsible_id`, `due_date`, `status` | FK → `handoff_package.id` | Đúng 5 nhóm bắt buộc; % hoàn thiện tính từ đây |
| `onboarding_milestone` | `package_id`, `day_no` (1/7/14/30), `criteria_json`, `status`, `owner_fix` | FK → `handoff_package.id` | Day 14 là GATE portal; cảnh báo trượt theo mốc |
| `communication_rules_acceptance` | `project_id`, `rules_version`, `signed_by_client_at`, `is_draft_internal` | FK → dự án sinh từ package | `[KXN-11]` Rules 1/2/3/5 gắn nhãn dự thảo nội bộ |
| `deploy_timeline_event` | `project_id`, `event` (D0/PLANNING/KICKOFF_INT_1/2/KICKOFF_CLIENT/ONGOING), `planned_day`, `actual_at` | FK → `projects.id` | D+0 cần tiền + LOI/HĐ (KXN-5); ONGOING D+5 (KXN-10) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ; chi tiết điền ở Phase 5. Mỗi scenario map về REQ-SALES-008.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn Gate 2 khi checklist thiếu | Package 4/5 nhóm, nhóm (5) còn 2 mục trống | NVKD nhấn trình Gate 2 | Nút vô hiệu ở UI; API từ chối; liệt kê đúng 2 mục thiếu + responsible + due date | [ ] |
| SC-002: Ký 3 bên đúng SLA | Checklist 100%, SM đã ký | AM xác nhận trong 4h làm việc | Package `ACCEPTED`; tự sinh dự án; đồng hồ onboarding bắt đầu; audit trail ghi đủ 3 chữ ký | [ ] |
| SC-003: AM từ chối — credit tạm dừng | Package ở `PENDING_AM_CONFIRM` | AM từ chối với lý do | Trạng thái về `RETURNED`; deal hiển thị "credit tạm dừng — chờ handoff lại"; package về queue NVKD | [ ] |
| SC-004: Cảnh báo capacity trống | Capacity khả dụng = 0 | NVKD mở màn hình chuẩn bị Gate 2 | Cảnh báo gửi GDKD + OPS_PLAN; chặn submit đến khi capacity được xác nhận | [ ] |
| SC-005: Milestone Day 14 GATE trượt | 0 user portal kích hoạt đến Day 14 | Mốc Day 14 được đánh giá | Mốc FAIL; escalate root cause lên CS TL trong 24h; kế hoạch khắc phục có owner + deadline | [ ] |
| SC-006: Form ký 6 Rules đúng nguồn | Tới bước Kick-off D+3 | Mở form ký 6 Communication Rules | Rules 1/2/3/5 gắn nhãn "dự thảo nội bộ — chờ khách xác nhận" `[KXN-11]`; không hoàn tất nếu thiếu chữ ký khách | [ ] |
| SC-007: Timeline D+0 chưa kích hoạt | Tiền chưa vào hoặc thiếu LOI/HĐ | Xem deploy timeline | D+1→D+5 hiển thị "chờ D+0"; thiếu LOI/HĐ dù có tiền → giữ chờ, cảnh báo pháp lý | [ ] |
| SC-008: Sales không vận hành portal | NVKD mở dashboard milestone | Xem khu vực trạng thái portal | Chỉ read-only (CLIENT_ADMIN, % user kích hoạt, login/tuần) đọc từ CORE; không có nút thao tác | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (chặn Gate 2, SLA clock, tự sinh dự án — enforce tại SYS-CORE-BACKEND) |
| Màn hình UI | `phase4-ux/bcerp-web/handoff-onboard/[screen-group].md` |
| Bản cùng REQ góc OPS | `phase2-features/bcerp-web/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md` |
| Nguồn quy trình | `documents/quy-trinh-lam-viec/` v1.1 (file 02 — Handoff/Gate 2; file 04 — Deploy D+0→D+5; file 08 — RACI/Gate/SLA; file 09 — hằng số & 6 Rules; file 10 §4 — khoản [KXN] còn mở) |
