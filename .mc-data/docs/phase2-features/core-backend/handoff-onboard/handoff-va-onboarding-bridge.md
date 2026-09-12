# Tính Năng: Handoff & Onboarding Bridge

> **Dựa trên:** REQ-SALES-008 trong `phase1-business/departments/sales/sales.md` (Phần A)
> **Phân hệ:** Handoff & Onboarding (SYS-CORE-BACKEND)
> **Module:** MOD-HANDOFF-ONBOARD
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md` (B.8), `phase1-business/departments/operations/operations.md` (B.3), `phase1-business/P1-02-business-workflow.md` (Luồng 1 — B7–B8), `documents/quy-trinh-lam-viec/04_Giai_doan_3_Trien_khai_Deploy.md` (v1.1), `documents/quy-trinh-lam-viec/08_Ma_tran_RACI_Gate_SLA.md` (v1.1), `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1 §4)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/SYS-CORE-BACKEND/MOD-HANDOFF-ONBOARD/[screen-group].md`, `phase5-implementation/tasks/SYS-CORE-BACKEND/MOD-HANDOFF-ONBOARD/FEAT-CORE-HONB-001-impl.md`
>
> **ID:** FEAT-CORE-HONB-001 từ lane `core-backend--HANDOFF-ONBOARD`. REQ-SALES-008 fan-out 3 hệ thống — bản này là bản riêng cho SYS-CORE-BACKEND (headless API/domain service: mọi business rule enforce ở tầng service, không tin UI, audit log + tenant isolation); counterparts: SYS-BCERP-WEB (soạn package + dashboard milestone), SYS-MOBILE-INTERNAL (ký + push cảnh báo, Phase2). Bản góc OPS tiếp nhận bàn giao: FEAT-CORE-HONB-002 cùng module.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-HONB-001 |
| Module | MOD-HANDOFF-ONBOARD |
| Yêu cầu nghiệp vụ | REQ-SALES-008 (Handoff & Onboarding Bridge) · Phụ thuộc chéo: REQ-OPS-004 — Handoff Bridge: Sales bàn giao, OPS tiếp nhận (bản riêng OPS = FEAT-CORE-HONB-002) |
| Người dùng liên quan | SALES_L1 (NVKD hỗ trợ soạn), SALES_L2 (NVKD chủ deal — soạn package), SALES_L3 (SM — ký Gate 2), SALES_L4 (TPKD — theo dõi nhóm deal), SALES_L5 (GDKD — escalation, cảnh báo capacity), OPS_AM (xác nhận tiếp nhận SLA 4h — phối hợp DEPT-OPS) |
| Độ ưu tiên | Cao (HIGH) |
| Giai đoạn | Giai đoạn 2 (GĐ2 — capacity check phụ thuộc Capacity & Timesheet) |
| Phụ thuộc | FEAT-CORE-CRM-004 (Gate 1/Gate 2 — approval engine đọc trạng thái checklist từ feature này); FEAT-CORE-HONB-002 (bên tiếp nhận); module Capacity & Timesheet (capacity check khi WON); FEAT-CORE-CRM-002 (stage machine V6.0) |
| Ghi chú Expert (A7) | Chưa có điều chỉnh nào từ Expert Review được ghi nhận trong `sales.md` Mục A7 tại thời điểm lập spec (12/09/2026) — Phần B đã do sales-expert review 12/09/2026, BR-SALES-801/802/803 giữ nguyên |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng trên Core Backend domain service "cầu bàn giao" giữa Sales và Vận hành: quản lý **Handoff Package 5 nhóm checklist bắt buộc**, **chặn Gate 2 nếu checklist <100%**, điều phối **ký 3 bên** (NVKD chủ deal soạn → SM ký → AM xác nhận SLA 4h), **tự sinh dự án khi WON** kèm capacity check, theo dõi **milestone Day 1/7/14/30** và vận hành **Deploy timeline D+0→D+5** (KXN-10). Đây là điểm chuyển giao trách nhiệm có chữ ký — mọi hệ quả nghiệp vụ chỉ phát sinh từ bản ghi trên hệ thống, không từ xác nhận miệng/chat.

**Phạm vi:**
- Bao gồm: domain service quản lý Handoff Package 5 nhóm ở mức item (responsible + due date, validation tầng service); service chặn Gate 2 khi <100% (trả kèm danh sách mục thiếu); e-approval ký 3 bên với SLA AM 4h, AM từ chối → trả về SM kèm lý do + flag tạm dừng credit; WON tự sinh dự án trong 24h + AM xác nhận capacity (điều kiện mở DEPLOY), cảnh báo GDKD + OPS_PLAN khi capacity = 0 trước khi ký Gate 2; theo dõi milestone Day 1/7/14/30 (trạng thái kích hoạt portal đọc từ CORE — sales không vận hành portal); Deploy timeline D+0→D+5 (D+0: tiền vào + FIN_L1 confirm 4h + LOI/HĐ theo KXN-5; Planning TT→ĐH→AD trong ngày D+0; checklist tài nguyên trước D+4; Kick-off KH D+3 ký 6 Communication Rules — KXN-11; ONGOING D+5); audit log bất biến (WORM) + tenant isolation.
- Không bao gồm: approval engine tổng quát Gate 1/Gate 2 và khóa `qualifiedTier` (FEAT-CORE-CRM-004 — service này chỉ cấp dữ liệu checklist để engine đọc); màn hình WEB và app MOBILE (counterparts); thực thi onboarding góc OPS (FEAT-CORE-HONB-002 — bản này chỉ theo dõi milestone và nhận feedback); credit hoa hồng (REQ-SALES-009 — chỉ nhận flag tạm dừng); portal khách (MOD-CLIENT-PORTAL — chỉ đọc trạng thái kích hoạt).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-CORE-BACKEND: headless API/domain service — WEB nội bộ (responsive browser UI) và MOBILE nội bộ (React Native, Phase2) chỉ là kênh tương tác; mọi điều kiện, SLA và chữ ký enforce ở service layer; GW (adapter) chỉ nhận trạng thái hiển thị, degraded mode `manual` không hợp lệ hóa handoff.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L2 (NVKD chủ deal) | Soạn Handoff Package 5 nhóm từ template chuẩn, mỗi mục gắn responsible + due date | Bàn giao đúng chuẩn, không sai sót bằng trí nhớ |
| 2 | SALES_L2 | Thấy rõ mục nào còn thiếu (kèm responsible + due date) khi checklist <100% | Biết chính xác phải khắc phục gì trước khi trình Gate 2 |
| 3 | SALES_L3 (SM) | Hệ thống chặn trình/ký Gate 2 khi Package <100% hoặc capacity = 0 | Không ký bàn giao deal thiếu hồ sơ hoặc không có người chạy |
| 4 | SALES_L3 | Ký Gate 2 qua approval engine (khác chủ deal), hệ thống tự sinh dự án | Chuyển giao có chữ ký pháp-nội bộ, không tạo dự án tay |
| 5 | SALES_L2 | Nhận kết quả AM xác nhận trong SLA 4h; AM từ chối thì thấy lý do + biết credit tạm dừng | Khắc phục đúng điểm OPS phản hồi rồi bàn giao lại |
| 6 | SALES_L2 / SALES_L3 | Theo dõi milestone Day 1/7/14/30 (kèm trạng thái kích hoạt portal đọc từ CORE) | Biết khi nào onboarding ổn định, sales nhận feedback điểm chưa bàn giao xong |
| 7 | SALES_L5 (GDKD) | Nhận cảnh báo capacity = 0 trước khi ký Gate 2 và escalation khi SLA trễ | Chặn sớm deal "ký xong không ai chạy"; trượt hạn không âm thầm |
| 8 | SALES_L2 | Xem Deploy timeline D+0→D+5 của deal WON | Biết khách đã đến mốc nào sau bàn giao mà không phải hỏi qua OPS |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, enforce ở tầng service của Core Backend (không tin UI). Mọi truy vấn cách ly theo tenant, mọi chuyển trạng thái ghi audit log bất biến (WORM).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | **Hard gate "không ghi nhận = không tồn tại" (xuyên suốt):** Handoff Package, từng mục checklist, chữ ký 3 bên, milestone chỉ có hiệu lực khi là bản ghi trên hệ thống; handoff ngoài package (miệng/chat/Zalo) không được công nhận; thực thi chặn 2 tầng — UI vô hiệu + API từ chối request | API từ chối mọi request đánh dấu hoàn tất handoff không qua bản ghi; báo cáo handoff chỉ đếm bản ghi có audit log |
| BR-SALES-801 | **Handoff Package 5 nhóm bắt buộc (CORE):** 5 nhóm checklist theo chuẩn bàn giao — **(1) Hợp đồng & phạm vi dịch vụ** (tier, SLA áp dụng, ngân sách); **(2) Tài sản QC & tracking** (TKQC + quyền truy cập, pixel/CAPI/UTM, creative assets, brand guideline); **(3) Mục tiêu & baseline KPI** (conversion/traffic/awareness theo mục tiêu khách); **(4) Vận hành** (POC khách, ngôn ngữ/múi giờ, lịch họp, lịch làm việc khách); **(5) Điều kiện khởi động** (capacity check, Brand Safety, demand TKQC cần khởi tạo). Mỗi mục bắt buộc có responsible + due date; **chặn Gate 2 nếu tổng checklist <100%** — response API liệt kê rõ mục thiếu nào, responsible ai, due date nào; Gate 2 chỉ mở khi = 100% | Gate engine không nhận trạng thái mở khi percent <100; request "ghi đè bằng đặc cách" bị từ chối — chỉ có đường khắc phục đủ mục |
| BR-SALES-802 | **Ký 3 bên tại Gate 2 + SLA AM 4h:** NVKD chủ deal (SALES_L2) soạn và trình → SM (SALES_L3, ≠ chủ deal) ký Gate 2 → hệ thống tự sinh dự án → AM (OPS_AM) xác nhận tiếp nhận trong **SLA 4h làm việc**; AM từ chối → trả về SM khắc phục theo package, credit hoa hồng tạm dừng (flag sang credit engine — REQ-SALES-009) đến khi handoff lại thành công; ký qua approval engine của CORE, MOBILE (Phase2) chỉ là kênh với MFA step-up + token gắn device | Chữ ký SM trùng chủ deal bị từ chối; AM xác nhận quá 4h sinh escalation record tự động; không có đường "xác nhận hộ" ngoài approval engine |
| BR-SALES-803 | **Milestone Day 1/7/14/30:** sau khi AM xác nhận, service tạo 4 milestone với ngày đáo hạn tính từ timestamp xác nhận; tracking trạng thái + cảnh báo trượt mốc; **trạng thái kích hoạt portal của khách hiển thị trong milestone** — đọc từ CORE (service này chỉ đọc, sales không có action vận hành portal); thiếu sót phát sinh Day 1–30 quay về SM khắc phục theo package — OPS không nhận việc ngoài package | Milestone trượt sinh alert + record; không cho phép đóng milestone thiếu bằng chứng (bản ghi kèm link/biểu mẫu); sales không thấy nút thao tác portal nào trên bất kỳ kênh nào |
| BR-SALES-804 | **WON tự sinh dự án + capacity check 24h:** WON cập nhật trong 24h → service tự sinh dự án và phát yêu cầu AM xác nhận capacity — xác nhận capacity trong 24h là **điều kiện mở DEPLOY**; capacity trống = 0 → cảnh báo GDKD (SALES_L5) + OPS_PLAN **trước khi ký Gate 2** (tránh ký deal không người chạy); capacity check gắn Gate 2 có SLA 4h, quá hạn escalate TL rồi HR_L2 (8h) | Không thể mở stage DEPLOY khi thiếu xác nhận capacity; cảnh báo capacity = 0 ghi audit kèm người nhận; request mở DEPLOY thiếu bản ghi capacity bị từ chối |
| BR-SALES-805 | **D+0 — điều kiện kích hoạt duy nhất:** D+0 chỉ set khi đồng thời (a) tiền phase đầu vào TK công ty, (b) FIN_L1 (Accountant) confirm trong **4h làm việc** sau khi tiền vào, (c) **LOI hoặc HĐ đã ký 2 bên** (KXN-5 — đã chốt 12/09); HĐ đầy đủ chậm nhất **7 ngày sau D+0**; chưa upload HĐ sau 3 ngày từ D+0 → tự sinh cảnh báo (`hasContractWarning`) cho AM + AD | Thiếu bất kỳ điều kiện nào → `dStartDate` không được set, toàn bộ D+1/2/3/5 không tính; tiền vào nhưng thiếu số so với phase 1 → không trigger, báo AM clarify khách |
| BR-SALES-806 | **Planning TT→ĐH→AD trong ngày D+0:** ngay trong ngày tiền vào, service mở Planning Draft theo flow **TT** (tổng hợp brief + insight) → **ĐH** (chiến lược + thông điệp + audience) → **AD** (action plan kênh + lịch + budget); AM soạn chính, Planner review; hoàn thành trong ngày D+0 — không gia hạn; input Strategic Brief 16 sections `[KXN-7 — cấu trúc 16 sections chưa có nguồn, chờ khách hàng cung cấp template; thiếu thông tin → lên plan kèm assumption đánh dấu, confirm tại Kick-off D+3]` | Planning không hoàn thành trong D+0 → record trễ + escalate; task list Kick-off không generate khi chưa có Planning Draft |
| BR-SALES-807 | **Checklist tài nguyên hoàn tất trước D+4:** service auto-generate checklist thu thập tài nguyên theo service package (quyền Meta BM / Google Ads / TikTok Ads Manager — khách accept trong 1–3 ngày; pixel, creative assets); track từng item; thiếu tài nguyên → **D+5 lùi đến khi đủ**; track ad account/top-up hiện trên Task Module, chuyển CMS khi có `[KXN-9 — CMS Module đang ở trạng thái tương lai]`; khách chậm cấp quyền: nhắc hàng ngày → quá 3 ngày AM call → quá 5 ngày AD contact | ONGOING D+5 không mở khi checklist chưa đủ; record trễ gắn deadline khách để truy đòi |
| BR-SALES-808 | **Kick-off KH D+3 — Hard Gate 6 Communication Rules:** điều kiện done Kick-off khách (D+3, 1–2h, không gia hạn; trễ → D+5 lùi theo): **6 Communication Rules được KH ký** — Rules 1/2/3/5 hiện theo **bản dự thảo nội bộ đã duyệt 12/09, chờ khách xác nhận chính thức `[KXN-11]`** (Rule 1 đầu mối duy nhất AM; Rule 2 kênh lưu vết bắt buộc Email/Portal; Rule 3 budget & targeting luôn cần xác nhận rõ ràng, không áp im lặng = đồng ý; Rule 5 lịch báo cáo/họp cố định theo reporting frequency, đổi lịch báo trước 24h) + Rule 4 (im lặng = đồng ý 24h) và Rule 6 (báo cáo 3 kênh Zalo + Email + Portal) có nguồn v2.3; KH đã login portal ≥1 lần; KPI + reporting frequency confirm 2 chiều; biên bản upload | Đánh done khi thiếu điều kiện nào bị từ chối; KH từ chối ký → AM giải thích → AD negotiate → ghi exception có phê duyệt, D+5 lùi |
| BR-SALES-809 | **ONGOING D+5:** dự án chuyển ONGOING tại D+5 chỉ khi đủ tài nguyên (pixel hoạt động, quyền ad account); D+5 lùi tự động nếu D+3 trễ hoặc checklist tài nguyên chưa đủ; toàn bộ mốc D+0→D+5 là dữ kiện service tính từ `dStartDate`, không cho phép nhập tay ngày mốc | Đánh dấu ONGOING thiếu điều kiện bị từ chối ở tầng service; ngày mốc nhập tay bị chặn cứng, chỉ chấp nhận từ event gốc (confirm tiền, ký Rules, checklist done) |

---

## 4. Phân Quyền

| Hành động | SALES_L1 | SALES_L2 | SALES_L3 (SM) | SALES_L4 | SALES_L5 (GDKD) | OPS_AM | SYS_ADMIN |
|-----------|----------|----------|---------------|----------|------------------|--------|-----------|
| Xem package + milestone + trạng thái portal (deal được gán/theo dõi — read-only) | ✅ (deal mình) | ✅ (deal mình) | ✅ (nhóm) | ✅ (nhóm) | ✅ (toàn phòng) | ✅ (phần tiếp nhận) | ✅ |
| Soạn / sửa mục checklist (deal của mình) | ✅ (được phân công) | ✅ (chủ deal) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Trình package vào Gate 2 | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Ký Gate 2 | ❌ | ❌ (cấm tự duyệt deal mình) | ✅ (≠ chủ deal) | ❌ | ❌ | ❌ | ❌ |
| Xác nhận tiếp nhận SLA 4h / từ chối | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (qua FEAT-CORE-HONB-002) | ❌ |
| Cập nhật kết quả milestone Day 1/7/14/30 (bên thực thi) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Xử lý escalation (quá SLA, capacity = 0) | ❌ | ❌ | ✅ (khắc phục package) | ❌ | ✅ (điểm escalate cuối của Sales) | ❌ | ❌ |
| Cấu hình template checklist 5 nhóm + tham số SLA | ❌ | ❌ | ❌ | ❌ | ✅ (đề xuất theo policy) | ❌ | ✅ (thực thi cấu hình) |

> Phân quyền theo **mã vai registry 18 vai** (SALES_L1–L5, OPS_AM…); không dùng `OPS_CX`/`FIN_COMPL` (DI-006 đã chốt gỡ). Toàn bộ hành động đi qua API của CORE với kiểm tra role + tenant isolation; MOBILE (Phase2) chỉ thêm kênh ký/push với MFA step-up, không đổi logic phân quyền; WEB là kênh soạn/theo dõi chính.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **AM không xác nhận trong 4h:** service sinh escalation record tự động (kèm timestamps); deal không rơi vào trạng thái "quên duyệt" — trạng thái vẫn `AM_CONFIRMING` cho đến khi có người xử lý theo chuỗi escalate cấu hình.
- **SM vắng / chỉ có một SM trong tenant:** chữ ký Gate 2 không ủy thác hàng loạt; nếu SM duy nhất chính là chủ deal, escalate GDKD (SALES_L5) chỉ định/chỉ định người ký thay — không có cơ chế whitelist duyệt hộ.
- **Khách tái ký:** Initial Brief được rút gọn nhưng Gate 1/Gate 2 và Handoff Package 5 nhóm vẫn bắt buộc đủ 100% — không có cấu hình "bỏ checklist" cho bất kỳ phân khúc nào; package của kỳ tái ký tham chiếu package kỳ trước nhưng phải chấm lại.
- **Sửa package sau khi SM ký:** item bị khóa sau chữ ký; nếu cần sửa thì rút về `DRAFT` (bản ghi ký cũ giữ làm lịch sử), khắc phục rồi trình lại — không sửa "nặc danh" sau chữ ký.
- **WON nhưng tiền chưa vào:** sau WON chạy song song hai luồng COLLECTING ∥ WAIT_PAYMENT; D+0 chỉ set khi đủ cả 3 điều kiện BR-SALES-805 — không ai được "mở sớm" timeline vì lý do vận hành.
- **Tiền vào nhưng thiếu so với phase 1:** không trigger D+0; FIN_L1 báo AM, AM contact khách clarify; record chờ tiền đủ mới tính timeline.
- **KH từ chối ký 6 Communication Rules tại D+3:** AM giải thích từng rule → còn từ chối → AD negotiate → ghi exception có phê duyệt trên hệ thống (kèm lý do + người duyệt); D+5 tự động lùi theo D+3 trễ.
- **HĐ đầy đủ chưa ký sau D+0:** cảnh báo `hasContractWarning` sau 3 ngày cho AM + AD; HĐ đầy đủ chậm nhất 7 ngày sau D+0 (KXN-5) — LOI đã đủ điều kiện kích hoạt nhưng không thay thế HĐ đầy đủ.
- **Khách có nhiều người liên hệ:** nhóm (4) Vận hành ghi đúng **một POC** là đầu mối quyết định; các đầu mối khác lưu ở mức thông tin.
- **Thiếu sót phát hiện trong Day 1–30:** quay về SM khắc phục theo đúng mục package; OPS không nhận việc ngoài package; mọi thiếu sót ghi record để sales thấy điểm mình chưa bàn giao xong.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity: HandoffPackage — một instance cho mỗi deal (tạo từ thời điểm deal dự kiến chốt, bắt buộc hoàn tất trước Gate 2).*

**Entity:** HandoffPackage

**Sơ đồ trạng thái:**
```
[DRAFT] ──(trình SM · package 100% + capacity ≠ 0)──► [PENDING_SM_SIGN]
    ▲                                                        │ (SM ký ≠ chủ deal)
    │                                                        ▼
[RETURNED_TO_SM] ◄──(AM từ chối · lý do bắt buộc)── [SM_SIGNED] ──(tự sinh dự án)──► [AM_CONFIRMING]
    │                                                                                       │ (AM xác nhận ≤ 4h)
    └───────────────────────────────────────────────────────────────────────────────────────┼──► [ACCEPTED]
                                                                                            ▼
                                                                          [ONBOARDING_IN_PROGRESS] ──(Day 30 pass)──► [ONBOARDING_STABLE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Trình vào Gate 2 | `PENDING_SM_SIGN` | SALES_L2 (chủ deal) | Checklist 5 nhóm = 100%; capacity ≠ 0; thiếu → trả kèm danh sách mục thiếu (responsible + due date) |
| `PENDING_SM_SIGN` | SM ký Gate 2 | `SM_SIGNED` | SALES_L3 (≠ chủ deal) | E-approval có audit (thời gian, kênh; MOBILE: MFA + token device) |
| `SM_SIGNED` | Tự sinh dự án | `AM_CONFIRMING` | Hệ thống | Dự án sinh tự động trong 24h từ WON; yêu cầu capacity gửi OPS_AM |
| `AM_CONFIRMING` | AM xác nhận tiếp nhận | `ACCEPTED` | OPS_AM, SLA 4h làm việc | Quá 4h → escalation record tự động; xác nhận có audit |
| `AM_CONFIRMING` | AM từ chối | `RETURNED_TO_SM` | OPS_AM | Lý do bắt buộc; flag tạm dừng credit (REQ-SALES-009); khắc phục rồi trình lại từ `DRAFT` |
| `ACCEPTED` | Bắt đầu onboarding | `ONBOARDING_IN_PROGRESS` | Hệ thống | Tạo 4 milestone Day 1/7/14/30 tính từ timestamp xác nhận |
| `ONBOARDING_IN_PROGRESS` | Day 30 đạt | `ONBOARDING_STABLE` | OPS_AM (cập nhật) + hệ thống (đối chiếu) | 4/4 milestone pass có bằng chứng; thiếu sót còn mở → không cho đóng |
| `ONBOARDING_IN_PROGRESS` | Milestone trượt | Giữ trạng thái + alert | Hệ thống | Sinh cảnh báo trượt; feedback thiếu sót quay về SM |

**Quy tắc:**
- `RETURNED_TO_SM` khởi động lại chu trình từ `DRAFT` với bản ghi mới; bản ghi ký cũ giữ nguyên làm lịch sử, không sửa.
- `ONBOARDING_STABLE` là trạng thái kết thúc của bridge — sau đó dự án sống ở ONGOING (FEAT-CORE-HONB-002 góc OPS); milestone state là dữ kiện CORE, WEB/MOBILE chỉ hiển thị.
- Mọi chuyển trạng thái ghi audit log bất biến (ai, khi nào, từ/sang, căn cứ) và cách ly theo tenant; SLA tính giờ làm việc theo cấu hình tenant.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `handoff_package` | `deal_id`, `state`, `percent`, `submitted_at`, `accepted_at`, `version` | FK → `pipeline_deal.id` | 1 package/deal; version tăng mỗi lần trình lại |
| `handoff_package_item` | `package_id`, `group_no` (1–5), `name`, `responsible_id`, `due_date`, `status`, `evidence_ref` | FK → `handoff_package.id`, `users.id` | Định nghĩa 5 nhóm theo BR-SALES-801; khóa sau chữ ký SM |
| `handoff_signature` | `package_id`, `role` (NVKD/SM/AM), `signer_id`, `signed_at`, `channel`, `decision`, `reason` | FK → `handoff_package.id`, `users.id` | Ký 3 bên qua approval engine; audit WORM |
| `handoff_milestone` | `package_id`, `day_no` (1/7/14/30), `due_at`, `status`, `pass_criteria_snapshot`, `portal_activation_status` | FK → `handoff_package.id` | `portal_activation_status` đọc từ module portal — không ghi tay |
| `project` | `deal_id`, `code`, `created_from` (auto_won), `owner_am_id`, `backup_am_id` | FK → `pipeline_deal.id`, `users.id` | Tự sinh trong 24h sau WON; tham chiếu module dự án |
| `deploy_timeline_event` | `project_id`, `event_code` (D0_TRIGGER/PLANNING_DRAFT/KICKOFF_I1/I2/KICKOFF_CLIENT/ONGOING), `occurred_at`, `evidence_ref` | FK → `project.id` | D+0 set bởi event confirm tiền + LOI/HĐ; cấm nhập tay ngày mốc |
| `communication_rules_record` | `project_id`, `rules_version`, `signed_by_client_at`, `rules_payload`, `exception_note` | FK → `project.id` | Ký tại D+3; Rules 1/2/3/5 theo bản dự thảo nội bộ `[KXN-11]` — thay bản chính thức khi khách cung cấp |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Trình Gate 2 khi package 92% | Package còn thiếu 1 mục nhóm (2) Tài sản QC | SALES_L2 trình vào Gate 2 | API từ chối; response liệt kê mục thiếu + responsible + due date; không có chữ ký nào được thực hiện | [ ] |
| SC-002: Ký Gate 2 đủ điều kiện | Package 100%, capacity ≠ 0 | SM (≠ chủ deal) ký qua approval engine | `SM_SIGNED`; hệ thống tự sinh dự án; audit log ghi người ký + kênh + thời gian | [ ] |
| SC-003: Cấm tự duyệt deal của mình | SM đồng thời là chủ deal | SM thử ký Gate 2 | API từ chối "signer = owner"; escalate GDKD chỉ định người ký khác | [ ] |
| SC-004: AM xác nhận/từ chối trong SLA 4h | SM đã ký, package 100% | OPS_AM từ chối kèm lý do; hoặc để quá 4h | Từ chối → `RETURNED_TO_SM` + lý do + flag tạm dừng credit; quá 4h → escalation record tự động, không tự chuyển `ACCEPTED` | [ ] |
| SC-005: Capacity = 0 trước ký Gate 2 | Dự án khác chiếm hết capacity | Hệ thống kiểm tra trước khi mở Gate 2 | Chặn ký; cảnh báo GDKD + OPS_PLAN với audit; capacity check quá 4h escalate TL rồi HR_L2 (8h) | [ ] |
| SC-006: D+0 thiếu LOI/HĐ | Tiền đã vào, FIN_L1 confirm, chưa có LOI/HĐ | Hệ thống đánh giá điều kiện D+0 | `dStartDate` không set; timeline D+1→D+5 không tính; không thể đánh mốc tay | [ ] |
| SC-007: Kick-off D+3 thiếu chữ ký 6 Rules | KH đã login portal nhưng chưa ký 6 Rules | AM đánh done Kick-off KH | Service từ chối done; Hard Gate giữ nguyên; D+5 tự lùi khi D+3 trễ | [ ] |

> **Liên kết:** SC-001…SC-007 map về REQ-SALES-008 (package 5 nhóm chặn Gate 2, ký 3 bên SLA 4h, WON tự sinh dự án + capacity 24h, milestone Day 1/7/14/30, Deploy D+0→D+5).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) handoff_package, handoff_signature, deploy_timeline_event | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (HandoffPackageService, Gate2ChecklistService, DeployTimelineService) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (WEB soạn, MOBILE ký MFA, FIN confirm D+0, OPS tiếp nhận — FEAT-CORE-HONB-002, portal activation) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI soạn package + dashboard milestone (WEB — counterpart) và app ký (MOBILE — Phase2) | `phase4-ux/SYS-BCERP-WEB/MOD-HANDOFF-ONBOARD/[screen-group].md`, `phase4-ux/SYS-MOBILE-INTERNAL/MOD-HANDOFF-ONBOARD/[screen-group].md` |
| Nghiệp vụ gốc & business rules đầy đủ | `phase1-business/departments/sales/sales.md` (B.8), `phase1-business/departments/operations/operations.md` (B.3), `phase1-business/P1-02-business-workflow.md` (Luồng 1, B7–B8), `documents/quy-trinh-lam-viec/04_Giai_doan_3_Trien_khai_Deploy.md` (v1.1 — KXN-10 đã phê chuẩn), `documents/quy-trinh-lam-viec/08_Ma_tran_RACI_Gate_SLA.md` (v1.1 §2–§3 `[KXN-19 — ma trận RACI còn chờ chủ dự án xác nhận trước khi cấu hình Approval Module]`), `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1 §4) |
