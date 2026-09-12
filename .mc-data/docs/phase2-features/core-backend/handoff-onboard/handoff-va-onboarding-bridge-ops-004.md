# Tính Năng: Handoff & Onboarding Bridge

> **Dựa trên:** REQ-OPS-004 trong `phase1-business/departments/operations/operations.md` (Phần A)
> **Phân hệ:** Handoff & Onboarding (SYS-CORE-BACKEND)
> **Module:** MOD-HANDOFF-ONBOARD
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md` (B.3), `phase1-business/departments/sales/sales.md` (B.8), `phase1-business/P1-02-business-workflow.md` (Luồng 1 — B7–B8), `documents/quy-trinh-lam-viec/04_Giai_doan_3_Trien_khai_Deploy.md` (v1.1), `documents/quy-trinh-lam-viec/08_Ma_tran_RACI_Gate_SLA.md` (v1.1), `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1 §4)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/SYS-CORE-BACKEND/MOD-HANDOFF-ONBOARD/[screen-group].md`, `phase5-implementation/tasks/SYS-CORE-BACKEND/MOD-HANDOFF-ONBOARD/FEAT-CORE-HONB-002-impl.md`
>
> **ID:** FEAT-CORE-HONB-002 từ lane `core-backend--HANDOFF-ONBOARD`. REQ-OPS-004 fan-out 3 hệ thống — bản này là bản riêng cho SYS-CORE-BACKEND (headless API/domain service: mọi business rule enforce ở tầng service, không tin UI, audit log + tenant isolation); counterparts: SYS-BCERP-WEB (checklist + e-approval), SYS-MOBILE-INTERNAL (AM xác nhận SLA 4h + push trượt mốc khi di chuyển). Bản góc Sales bàn giao: FEAT-CORE-HONB-001 cùng module.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-HONB-002 |
| Module | MOD-HANDOFF-ONBOARD |
| Yêu cầu nghiệp vụ | REQ-OPS-004 (Handoff & Onboarding Bridge) · Phụ thuộc chéo: REQ-SALES-008 — Handoff Bridge: nguồn package từ Sales (bản riêng Sales = FEAT-CORE-HONB-001) |
| Người dùng liên quan | OPS_AM (chính — tiếp nhận handoff, thực thi onboarding), OPS_PLAN (capacity + planning), OPS_CONT, OPS_DES, OPS_EDIT (nhận task auto-generate từ checklist), OPS_ADS (khởi tạo TKQC theo demand), SYS_ADMIN (cấu hình) |
| Độ ưu tiên | Cao (Bắt buộc — HIGH) |
| Giai đoạn | Giai đoạn 2 (GĐ2) |
| Phụ thuộc | FEAT-CORE-HONB-001 (nguồn Handoff Package từ Sales — service này tiếp nhận trên cùng entity); FEAT-CORE-CRM-004 (Gate 2 — engine mở gate khi package 100%); module Capacity & Timesheet (capacity check gắn Gate 2); module Ad Account Command Center (khởi tạo TKQC theo demand) |
| Ghi chú Expert (A7) | Chưa có điều chỉnh nào từ Expert Review được ghi nhận trong `operations.md` Mục A7 tại thời điểm lập spec (12/09/2026) — bảng A7 đang ở trạng thái "chờ đánh giá"; Phần B.3 đã do paid-media-expert viết (Call 1/2), BR-OPS-3.1/3.2 giữ nguyên |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng trên Core Backend nửa "tiếp nhận" của cầu bàn giao Sales → Vận hành: OPS_AM tiếp nhận **Handoff Package 5 nhóm checklist** (Gate 2 chỉ mở khi checklist 100%), xác nhận tiếp nhận trong **SLA 4h** — từ lúc AM xác nhận, đồng hồ onboarding bắt đầu; hệ thống **tự sinh dự án**, AM xác nhận capacity trước DEPLOY và khởi tạo TKQC theo demand khách; thực thi **milestone onboarding Day 1/7/14/30 dạng checklist có tiêu chí đạt/trượt** và chạy **Deploy timeline D+0→D+5** đã phê chuẩn chính thức (KXN-10). Feature này bảo đảm OPS không bao giờ tiếp "đồ thiếu" mà không có bản ghi, và mọi thiếu sót Day 1–30 có đường quay về đúng chủ thể chịu khắc phục (SM Sales) thay vì bị nuốt vào vận hành.

**Phạm vi:**
- Bao gồm: service tiếp nhận package 5 nhóm với e-approval AM (SLA 4h làm việc, quá hạn escalate tự động); tự sinh dự án sau chữ ký; capacity check "xác nhận Capacity trống" gắn Gate 2 (SLA 4h → escalate TL rồi HR_L2 8h); demand khởi tạo TKQC đẩy sang registry TKQC (module Ad Account Command Center); thực thi Deploy timeline góc OPS — checklist tài nguyên (COLLECTING) hoàn tất trước D+4, Kick-off KH D+3 tạo portal account + Hard Gate ký 6 Communication Rules (KXN-11: Rules 1/2/3/5 theo bản dự thảo nội bộ đã duyệt, chờ khách xác nhận chính thức), ONGOING D+5 khi đủ tài nguyên; milestone Day 1/7/14/30 với tiêu chí pass/fail máy đối chiếu được (BR-OPS-3.2), cảnh báo trượt mốc, Day 14 là GATE kích hoạt portal; toàn bộ hành động ghi audit log bất biến và cách ly theo tenant.
- Không bao gồm: soạn package và bên ký SM (FEAT-CORE-HONB-001 góc Sales); approval engine tổng quát Gate 1/Gate 2 (FEAT-CORE-CRM-004); vòng đời TKQC chi tiết — cấp phát/thu hồi (module Ad Account Command Center); portal khách và màn hình activation của khách (MOD-CLIENT-PORTAL — service này chỉ đọc trạng thái); vận hành chiến dịch ONGOING chi tiết (module Proposal & Planning / Campaign); credit hoa hồng (REQ-SALES-009).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-CORE-BACKEND: đây là headless API/domain service — WEB nội bộ (responsive browser UI) là mặt làm việc checklist + e-approval, MOBILE nội bộ (React Native offline-capable, Phase2) là kênh AM xác nhận khi di chuyển; mọi điều kiện pass/fail và SLA enforce ở service layer, thiết bị offline chỉ được đồng bộ lại, không được hợp lệ hóa ngoại tuyến.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Nhận yêu cầu xác nhận tiếp nhận ngay khi SM ký Gate 2, thấy đủ 5 nhóm checklist trước khi xác nhận | Tiếp nhận có kiểm soát — không nhận package thiếu mà không để lại dấu vết |
| 2 | OPS_AM | Xác nhận/từ chối trong SLA 4h (kể cả từ MOBILE khi di chuyển); từ chối phải ghi lý do từng thiếu sót | Đồng hồ onboarding chỉ chạy khi tôi thực sự sẵn sàng nhận |
| 3 | OPS_AM | Được hệ thống tự sinh dự án sau chữ ký, milestone Day 1/7/14/30 tự tạo với tiêu chí pass/fail rõ | Không mất công dựng thủ công và không tranh cãi "thế nào là xong mốc" |
| 4 | OPS_PLAN | Nhận cảnh báo capacity = 0 trước khi ký Gate 2 và yêu cầu "xác nhận Capacity trống" SLA 4h (quá hạn escalate TL rồi HR_L2 8h) | Kịp bố trí đầu người trước khi deal bị ký với capacity trống |
| 5 | OPS_ADS | Nhận demand khởi tạo TKQC từ mục (5) Điều kiện khởi động của package | Bật TK đúng chuẩn ngay từ Day 1, không chờ hỏi lỏm Sales |
| 6 | OPS_CONT / OPS_DES / OPS_EDIT | Nhận task auto-generate theo service package + objective ngay từ Planning D+0 | Biết việc của mình từ D+0–D+1 thay vì nghe truyền khẩu |
| 7 | OPS_AM | Đánh kết quả milestone theo tiêu chí pass/fail có bằng chứng; hệ thống tự escalate khi trượt mốc (Day 14 trượt → escalate CS TL trong 24h) | Trượt mốc được xử lý có owner + deadline, không âm thầm trôi |
| 8 | OPS_AM | Ghi thiếu sót Day 1–30 và đẩy feedback về SM Sales theo đúng mục package | OPS không nhận việc ngoài package — ranh giới trách nhiệm giữ được |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, enforce ở tầng service của Core Backend (không tin UI). Mọi truy vấn cách ly theo tenant, mọi chuyển trạng thái ghi audit log bất biến (WORM).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-OPS-000 | **Hard gate "không ghi nhận = không tồn tại" (xuyên suốt):** việc tiếp nhận, xác nhận capacity, đánh pass/fail milestone chỉ có hiệu lực khi là bản ghi trên hệ thống qua API của CORE; xác nhận miệng/Zalo không tạo hiệu lực — Zalo chỉ là kênh nhắc | Request hợp lệ hóa ngoài hệ thống bị từ chối; báo cáo SLA onboarding chỉ đếm bản ghi có audit |
| BR-OPS-3.1 | **Tiếp nhận Handoff Package 5 nhóm (ký 3 bên):** 5 nhóm bắt buộc — **(1) Hợp đồng & phạm vi dịch vụ** (tier, SLA áp dụng, ngân sách); **(2) Tài sản QC & tracking** (TKQC + quyền truy cập, pixel/CAPI/UTM, creative assets, brand guideline); **(3) Mục tiêu & baseline KPI** (theo mục tiêu khách: conversion/traffic/awareness); **(4) Vận hành** (POC khách, ngôn ngữ/múi giờ, lịch họp, lịch làm việc khách); **(5) Điều kiện khởi động** (capacity check, Brand Safety, demand TKQC cần khởi tạo); Gate 2 chỉ mở khi checklist **100%** (<100% chặn ở service); ký 3 bên: SM ký + hệ thống tự sinh dự án + AM xác nhận trong **SLA 4h** — từ lúc AM xác nhận, đồng hồ onboarding bắt đầu; khách tái ký được rút gọn Initial Brief nhưng **không bỏ Gate 1/Gate 2** | AM không thể xác nhận package <100% ở bất kỳ kênh nào; thiếu mục hiển thị rõ thiếu gì + responsible + due date; không có đường bỏ gate cho phân khúc nào |
| BR-OPS-3.2 | **Milestone Day 1/7/14/30 — checklist có tiêu chí pass/fail (máy đối chiếu được):** **Day 1** pass khi 100% TKQC map đúng naming/owner/backup, danh sách sai lệch có owner khắc phục, khách đăng nhập portal lần đầu (tạo CLIENT_ADMIN đầu tiên + gửi invite); fail khi có TK không map được hoặc naming sai chưa có hành động. **Day 7** pass khi tracking xác nhận chạy (≥1 conversion test), ≥80% portal user kích hoạt, 2FA 100%; fail khi tracking chưa chạy hoặc 2FA <100%. **Day 14 — GATE kích hoạt portal:** pass khi khách tự xem được số dư + chi tiêu + ticket, ≥1 login/tuần từ ≥2 user; fail → escalate root cause lên CS TL trong 24h, kế hoạch khắc phục có owner + deadline — gate là điều kiện nghiệm thu giai đoạn onboarding. **Day 30** pass khi báo cáo review 30 ngày đầu vs baseline gửi khách + feedback ghi nhận; fail khi không có review hoặc baseline chưa chốt | Milestone không thể đánh pass thiếu bằng chứng (bản ghi/link đính kèm); trượt mốc sinh alert + escalation record tự động; Day 14 fail bắt buộc sinh kế hoạch khắc phục có owner + deadline trước khi được đánh lại |
| BR-OPS-3.3 | **Capacity check gắn Gate 2:** yêu cầu "xác nhận Capacity trống" SLA 4h; capacity trống = 0 → cảnh báo GDKD (SALES_L5) + OPS_PLAN trước khi ký Gate 2; quá hạn escalate TL rồi **HR_L2 (8h)** cân đối đầu người; kết quả capacity là điều kiện bắt buộc mở DEPLOY | Không xác nhận capacity → không mở DEPLOY; cảnh báo capacity = 0 ghi audit kèm người nhận; escalate chain không xóa được |
| BR-OPS-3.4 | **Khởi tạo TKQC theo demand:** mục (5) của package chứa demand TKQC cần khởi tạo — service đẩy demand sang registry TKQC (module Ad Account Command Center) với naming/owner/backup bắt buộc theo chuẩn registry; campaign không gắn dự án bị pause và cấm report chi tiêu về khách tới khi gắn xong | Demand thiếu platform/khách bị từ chối ở tầng service; TK khởi tạo ngoài registry không được gắn dự án handoff |
| BR-OPS-3.5 | **Deploy timeline D+0→D+5 góc OPS (KXN-10 — Deploy v2.3 phê chuẩn chính thức):** sau WON chạy song song **COLLECTING** (AM chủ trì, SE hỗ trợ; OPS theo dõi checklist tài nguyên — xong trước **D+4**, thiếu → D+5 lùi) ∥ **WAIT_PAYMENT** (FIN_L1 check sao kê hàng ngày); **D+0** kích hoạt khi tiền vào TK + FIN_L1 confirm trong 4h làm việc + LOI/HĐ đã ký (KXN-5) — HĐ đầy đủ chậm nhất 7 ngày sau D+0, cảnh báo sau 3 ngày; **Planning TT→ĐH→AD** trong ngày D+0 (AM soạn, Planner review) → task list auto-generate theo service package + objective cho OPS_CONT/OPS_DES/OPS_EDIT; **Kick-off nội bộ D+1/D+2** không lùi (tại D+1 define `backup_am_id`); **Kick-off KH D+3** Hard Gate ký 6 Communication Rules `[KXN-11 — Rules 1/2/3/5 theo bản dự thảo nội bộ đã duyệt 12/09, chờ khách hàng xác nhận chính thức; Rule 4 im lặng = đồng ý 24h và Rule 6 báo cáo 3 kênh có nguồn v2.3]` + KH login portal ≥1 lần + KPI/reporting frequency confirm 2 chiều + biên bản upload; **ONGOING D+5** chỉ khi đủ tài nguyên (pixel, quyền ad account) | Đánh done bất kỳ mốc nào thiếu điều kiện bị từ chối ở tầng service; D+5 lùi tự động theo D+3 trễ hoặc checklist tài nguyên thiếu; ngày mốc cấm nhập tay — chỉ set từ event gốc |
| BR-OPS-3.6 | **Ranh giới trách nhiệm Day 1–30:** thiếu sót phát hiện trong onboarding quay về SM Sales khắc phục **theo đúng mục package**; OPS không nhận việc ngoài package (handoff miệng/chat không được công nhận); service ghi record thiếu sót kèm mục package tương ứng và đẩy feedback về Sales | Đóng thiếu sót mà không có bản khắc phục của SM bị từ chối; thiếu sót ngoài scope package phải mở exception có phê duyệt, không nuốt vào việc OPS |
| BR-OPS-3.7 | **AM inactive + offline sync:** AM không phản hồi >4h giờ làm việc → alert AD; MOBILE offline-capable chỉ cho phép soạn nháp ngoại tuyến, mọi xác nhận/chữ ký phải sync về approval engine CORE với audit (thời gian sync ≠ thời gian hành động — ghi rõ cả hai) | Xác nhận tạo ngoại tuyến không hợp lệ cho tới khi sync qua CORE; thiết bị không đăng ký token bị từ chối + alert bảo mật |

---

## 4. Phân Quyền

| Hành động | OPS_PLAN | OPS_AM | OPS_CONT | OPS_DES | OPS_EDIT | OPS_ADS | SYS_ADMIN |
|-----------|----------|--------|----------|---------|----------|---------|-----------|
| Xem package + milestone của dự án phụ trách | ✅ | ✅ | ✅ (task của mình) | ✅ (task của mình) | ✅ (task của mình) | ✅ (demand TKQC) | ✅ |
| Xác nhận tiếp nhận SLA 4h / từ chối kèm lý do | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận Capacity trống (SLA 4h) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Đánh kết quả milestone Day 1/7/14/30 (kèm bằng chứng) | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ (phần map TK/ngày 1) | ❌ |
| Ghi thiếu sót + đẩy feedback về SM Sales | ✅ | ✅ | ✅ (phát hiện tại task) | ✅ (phát hiện tại task) | ✅ (phát hiện tại task) | ✅ | ❌ |
| Nhận / cập nhật task auto-generate từ checklist | ❌ (review planning) | ✅ (giao) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Tạo demand khởi tạo TKQC từ mục (5) | ✅ (đề xuất) | ✅ (duyệt demand) | ❌ | ❌ | ❌ | ✅ (thực thi đăng ký) | ❌ |
| Xử lý escalation trượt mốc (Day 14 gate, quá SLA) | ✅ (kế hoạch bố trí) | ✅ (thực thi khắc phục) | ❌ | ❌ | ❌ | ❌ | ✅ (hỗ trợ kỹ thuật) |
| Cấu hình tham số SLA/milestone/escalation | ✅ (đề xuất theo policy) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (thực thi cấu hình) |

> Phân quyền theo **mã vai registry 18 vai** (OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS…); **không dùng `OPS_CX`/`FIN_COMPL`** (DI-006 đã chốt gỡ — trách nhiệm CX gán OPS_PLAN). SM (SALES_L3) và GDKD chỉ xuất hiện với vai bên nhận feedback/escalation — không có action trực tiếp trên service này. Toàn bộ hành động đi qua API CORE với kiểm tra role + tenant isolation; WEB là mặt làm việc chính, MOBILE (Phase2) là kênh xác nhận khi di chuyển với MFA step-up, không đổi logic phân quyền.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **KH chưa có fanpage/ad account:** AM hỗ trợ tạo mới, hướng dẫn từng bước → D+5 lùi đến khi setup xong; checklist tài nguyên ghi nhận item "tạo mới" với deadline khách cung cấp.
- **KH chậm cấp quyền ad account:** nhắc hàng ngày qua kênh thường ngày → quá 3 ngày AM call trực tiếp → quá 5 ngày AD contact KH; toàn bộ nhắc ghi record để truy đòi, D+5 lùi theo.
- **KH không book được lịch Kick-off D+3:** AM đề xuất 3 slot → vẫn không được → AD contact → D+5 tự động lùi; record lịch hẹn lưu trên event module.
- **KH từ chối ký 6 Communication Rules tại D+3:** AM giải thích từng rule → còn từ chối → AD negotiate → **ghi exception có phê duyệt trên hệ thống** (lý do + người duyệt); Hard Gate không được bỏ qua — chỉ được "ghi nhận ngoại lệ có kiểm soát".
- **Tiền vào nhưng thiếu so với phase 1:** FIN_L1 báo AM ngay; AM contact khách clarify; chưa trigger D+0 cho đến khi đủ số — không "bắt đầu trước rồi đối trừ sau".
- **Day 14 gate trượt (khách không dùng portal):** escalate root cause lên CS TL trong 24h; kế hoạch khắc phục bắt buộc có owner + deadline; gate là điều kiện nghiệm thu giai đoạn onboarding — không đánh pass lại thiếu bằng chứng; lưu ý khách không dùng portal làm Health Score điều chỉnh trọng số (Portal 10% + Communication 30%) nhưng không miễn gate.
- **Thiếu sót thuộc scope chưa có trong package:** không nuốt vào việc OPS — mở exception có phê duyệt và đàm phán bổ sung package (phiên bản mới), tránh kỷ luật "miệng nói là làm".
- **AM nghỉ việc/lengthy vắng giữa onboarding:** `backup_am_id` (định nghĩa tại Kick-off nội bộ D+1) tự nhận tiếp; milestone giữ nguyên deadline; AM inactive >4h giờ làm việc → alert AD.
- **Offline MOBILE (đi công tác, mất mạng):** chỉ soạn nháp ngoại tuyến; khi sync về CORE ghi rõ cả hai timestamp (hành động và sync); xác nhận chưa sync không được tính cho SLA 4h.
- **Dự án parent/con (gói nhiều dịch vụ):** package con kế thừa nhóm (1) Hợp đồng từ parent nhưng nhóm (2)–(5) phải chấm lại đầy đủ theo scope con — không kế tiếp trạng thái pass từ project khác.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính: DeployProject — vòng đời triển khai góc OPS từ sau WON đến ONGOING. Entity HandoffPackage (DRAFT → … → ACCEPTED) dùng chung với FEAT-CORE-HONB-001; ở đây bắt đầu từ `AM_CONFIRMING`.*

**Entity:** DeployProject

**Sơ đồ trạng thái:**
```
[WON] ──► [COLLECTING] ∥ [WAIT_PAYMENT] ──(tiền vào + FIN confirm 4h + LOI/HĐ · KXN-5)──► [D0_TRIGGER]
                 │ (thiếu tài nguyên)                                                        │
                 │                                                                           ▼
                 │                                                              [PLANNING_DRAFT] (trong ngày D+0 · TT→ĐH→AD)
                 │                                                                           │
                 │                        ┌── [KICKOFF_INTERNAL_1] (D+1) ── [KICKOFF_INTERNAL_2] (D+2) ──┐
                 │                        ▼                                                              ▼
                 │                        └──────────────────────────────────────────► [KICKOFF_CLIENT] (D+3 · Hard Gate 6 Rules)
                 │                                                                           │ (đủ tài nguyên + Rules đã ký)
                 └── thiếu → giữ COLLECTING, D+5 lùi ──────────────────────────────────────► [ONGOING] (D+5)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `COLLECTING` ∥ `WAIT_PAYMENT` | Tài nguyên đủ + tiền vào confirm | `D0_TRIGGER` | Hệ thống (event FIN_L1) | Tiền vào TK + FIN_L1 confirm 4h làm việc + LOI/HĐ đã ký (KXN-5); thiếu tiền → không có D+0 |
| `D0_TRIGGER` | Soạn Planning Draft | `PLANNING_DRAFT` | OPS_AM (soạn) + OPS_PLAN (review) | Hoàn thành trong ngày D+0 theo flow TT→ĐH→AD; task list auto-generate |
| `PLANNING_DRAFT` | Kick-off nội bộ 1 | `KICKOFF_INTERNAL_1` | OPS_AM chủ trì | Ngày D+1; không lùi — vắng phải gửi feedback trước; define `backup_am_id` |
| `KICKOFF_INTERNAL_1` | Kick-off nội bộ 2 | `KICKOFF_INTERNAL_2` | OPS_AM + toàn bộ BPVH | Ngày D+2; plan chốt + phân công presenter |
| `KICKOFF_INTERNAL_2` | Kick-off KH | `KICKOFF_CLIENT` | OPS_AM (R/A) | Ngày D+3, 1–2h, không gia hạn; KH login portal ≥1 lần; KPI + reporting frequency confirm 2 chiều |
| `KICKOFF_CLIENT` | KH ký 6 Rules → mở ONGOING | `ONGOING` | Hệ thống đối chiếu điều kiện | 6 Communication Rules ký `[KXN-11]` + biên bản upload + đủ tài nguyên (pixel, quyền ad account); thiếu → D+5 lùi |
| Bất kỳ trước `ONGOING` | Thiếu tài nguyên / D+3 trễ | Giữ trạng thái + lùi `ongoing_date` | Hệ thống | Record lý do lùi + deadline khách; không nhập tay ngày mốc |

**Quy tắc:**
- Kick-off nội bộ D+1/D+2 **không được lùi** — mọi ngoại lệ phải có record feedback trước qua hệ thống.
- `ONGOING` là trạng thái bàn giao sang module vận hành (Proposal & Planning / Campaign) — state machine này đóng khi vào ONGOING; milestone Day 1/7/14/30 tiếp tục chạy độc lập với entity `onboarding_milestone`.
- Mọi chuyển trạng thái ghi audit log bất biến (ai, khi nào, từ/sang, căn cứ — event gốc như confirm tiền/ký Rules được tham chiếu bằng `evidence_ref`); tenant isolation toàn bộ; SLA tính giờ làm việc theo cấu hình tenant.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `handoff_package` | `deal_id`, `state`, `percent`, `accepted_at` | FK → `pipeline_deal.id` | Dùng chung với FEAT-CORE-HONB-001 — service này chỉ ghi ở giai đoạn tiếp nhận (`AM_CONFIRMING` → `ACCEPTED`) |
| `onboarding_milestone` | `project_id`, `day_no` (1/7/14/30), `due_at`, `status`, `pass_criteria_snapshot`, `evidence_ref`, `failed_reason`, `remediation_owner_id`, `remediation_deadline` | FK → `project.id`, `users.id` | Tiêu chí pass/fail snapshot theo BR-OPS-3.2; Day 14 fail bắt buộc có owner + deadline |
| `project` | `deal_id`, `code`, `owner_am_id`, `backup_am_id`, `stage` | FK → `pipeline_deal.id`, `users.id` | Tự sinh sau SM ký; stage theo state machine DeployProject |
| `deploy_stage_event` | `project_id`, `stage_code` (COLLECTING/WAIT_PAYMENT/D0_TRIGGER/PLANNING_DRAFT/KICKOFF_I1/KICKOFF_I2/KICKOFF_CLIENT/ONGOING), `occurred_at`, `evidence_ref` | FK → `project.id` | `dStartDate`/`paymentConfirmedAt`/`hasContractWarning` lưu ở project — cấm nhập tay ngày mốc |
| `resource_checklist_item` | `project_id`, `name`, `source` (service_package), `status`, `requested_at`, `received_at`, `deadline_client` | FK → `project.id` | Auto-generate theo service package; track ad account/top-up trên Task Module hiện tại `[KXN-9 — CMS tương lai]` |
| `capacity_check_request` | `project_id`, `requested_by`, `due_at`, `result` (trống khả dụng/giá trị), `escalation_level` (TL/HR_L2), `confirmed_at` | FK → `project.id`, `users.id` | SLA 4h → escalate TL → HR_L2 8h; điều kiện mở DEPLOY |
| `adaccount_demand` | `project_id`, `platform`, `client_code`, `objective`, `status` | FK → `project.id` | Đẩy sang registry TKQC (module Ad Account Command Center); naming/owner/backup bắt buộc |
| `communication_rules_record` | `project_id`, `rules_version`, `signed_by_client_at`, `rules_payload`, `exception_note` | FK → `project.id` | Ký tại D+3; Rules 1/2/3/5 theo bản dự thảo nội bộ `[KXN-11]` — thay bản chính thức khi khách cung cấp |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: AM xác nhận package 100% trong SLA | SM đã ký Gate 2, checklist 100% | OPS_AM xác nhận trong 4h làm việc | `ACCEPTED`; đồng hồ onboarding bắt đầu; 4 milestone Day 1/7/14/30 tự tạo; audit ghi người ký + kênh | [ ] |
| SC-002: AM từ chối kèm lý do | Package có thiếu sót AM phát hiện | OPS_AM từ chối với lý do từng mục | `RETURNED_TO_SM`; feedback về SM theo mục package; trình lại chỉ sau khi khắc phục | [ ] |
| SC-003: Chặn xác nhận khi package <100% | Checklist 96% | OPS_AM thử xác nhận tiếp nhận | Service từ chối ở tầng API (mọi kênh); hiển thị thiếu mục + responsible + due date | [ ] |
| SC-004: Capacity = 0 trước Gate 2 | Tất cả đầu người đã đầy | Hệ thống chạy capacity check | Cảnh báo GDKD + OPS_PLAN; không ký Gate 2 được; quá SLA 4h escalate TL rồi HR_L2 8h | [ ] |
| SC-005: Day 1 fail — TK không map được | Có 2 TKQC naming sai, chưa có hành động khắc phục | AM đánh milestone Day 1 | Chỉ được đánh fail (kèm owner khắc phục); đánh pass bị service chặn đối chiếu tiêu chí | [ ] |
| SC-006: Day 14 gate trượt → escalate | Đến hạn Day 14, chưa đạt ≥1 login/tuần từ ≥2 user | SLA clock hết hạn | Milestone fail tự động; escalation CS TL trong 24h; bắt buộc kế hoạch khắc phục có owner + deadline | [ ] |
| SC-007: D+3 thiếu chữ ký 6 Rules | KH login portal rồi nhưng chưa ký Rules | Thử đánh done Kick-off KH và mở ONGOING | Service từ chối; Hard Gate giữ; `ongoing_date` tự lùi theo D+3 trễ | [ ] |
| SC-008: Tiền vào thiếu so với phase 1 | KH chuyển khoản 60% phase 1 | FIN_L1 xác nhận số nhận được | Không trigger D+0; record chờ đủ số; timeline chưa bắt đầu | [ ] |
| SC-009: Offline MOBILE sync muộn | AM xác nhận tiếp nhận khi mất mạng | Device sync về CORE sau 3h | Xác nhận chỉ hợp lệ sau sync; audit ghi cả hai timestamp; SLA 4h đối chiếu theo thời điểm sync | [ ] |
| SC-010: Demand TKQC đẩy sang registry | Package mục (5) có demand 3 TK Meta | Service đẩy demand | 3 bản ghi demand sang registry TKQC với naming/owner/backup; thiếu trường nào bị từ chối ngay | [ ] |

> **Liên kết:** SC-001…SC-010 map về REQ-OPS-004 (tiếp nhận package 5 nhóm + ký 3 bên SLA 4h, milestone Day 1/7/14/30, WON tự sinh dự án + capacity trước DEPLOY, khởi tạo TKQC theo demand).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) onboarding_milestone, deploy_stage_event, capacity_check_request | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (HandoffReceivingService, OnboardingMilestoneService, DeployTimelineService, AdAccountDemandService) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (Sales — FEAT-CORE-HONB-001, FIN confirm D+0, HR_L2 capacity, registry TKQC, portal activation, GW degraded `manual`) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI checklist + e-approval (WEB — counterpart) và app AM xác nhận (MOBILE — Phase2) | `phase4-ux/SYS-BCERP-WEB/MOD-HANDOFF-ONBOARD/[screen-group].md`, `phase4-ux/SYS-MOBILE-INTERNAL/MOD-HANDOFF-ONBOARD/[screen-group].md` |
| Nghiệp vụ gốc & business rules đầy đủ | `phase1-business/departments/operations/operations.md` (B.3), `phase1-business/departments/sales/sales.md` (B.8), `phase1-business/P1-02-business-workflow.md` (Luồng 1, B7–B8), `documents/quy-trinh-lam-viec/04_Giai_doan_3_Trien_khai_Deploy.md` (v1.1 — KXN-10 đã phê chuẩn), `documents/quy-trinh-lam-viec/08_Ma_tran_RACI_Gate_SLA.md` (v1.1 §2–§3 `[KXN-19 — ma trận RACI còn chờ chủ dự án xác nhận trước khi cấu hình Approval Module]`), `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1 §4) |
