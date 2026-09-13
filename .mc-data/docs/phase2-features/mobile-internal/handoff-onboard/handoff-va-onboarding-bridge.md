# Tính Năng: Handoff & Onboarding Bridge

> **Dựa trên:** REQ-SALES-008 trong `phase1-business/departments/sales/sales.md` (Phần A, B.8)
> **Phân hệ:** Mobile nội bộ BCERP (SYS-MOBILE-INTERNAL)
> **Module:** Handoff & Onboarding Bridge (MOD-HANDOFF-ONBOARD)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `documents/quy-trinh-lam-viec/` (04 Deploy, 08 RACI/Gate/SLA, 09 Hằng số)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-HONB-001 |
| Module | MOD-HANDOFF-ONBOARD |
| Yêu cầu nghiệp vụ | REQ-SALES-008 — Handoff & Onboarding Bridge (HIGH, Phase2) |
| Người dùng liên quan | SALES_L2 (NVKD chủ deal — chính), SALES_L4 (TPKD/SM — ký Gate 2), SALES_L5 (GDKD — nhận cảnh báo capacity), SALES_L1, SALES_L3 (xem theo dõi); OPS_AM xuất hiện ở đầu bàn giao (xác nhận SLA 4h — chi tiết bản REQ-OPS-004) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase2 — kênh ký chính của Gate 2 trên mobile theo nguyên tắc multi-system của sales.md B.0) |
| Phụ thuộc | Cross-dependency REQ-OPS-004 — Handoff Bridge góc OPS tiếp nhận (bản counterpart cùng module); capacity check từ REQ-OPS-007 (MOD-CAPACITY-TIMESHEET); tự sinh dự án + checklist chặn Gate 2 thực thi tại SYS-CORE-BACKEND; soạn package trên SYS-BCERP-WEB |
| Ghi chú Expert (A7) | Sales.md Mục A7: chưa có đánh giá chính thức (chờ review); REQ-SALES-008 fan-out 3 systems — bản này là bản riêng SYS-MOBILE-INTERNAL, counterparts tại SYS-CORE-BACKEND và SYS-BCERP-WEB |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Trên mobile nội bộ (React Native, offline-capable), tính năng đưa cầu nối bàn giao Sales → OPS vào túi nhân sự kinh doanh đang di chuyển: SM (SALES_L4) ký Handoff Package tại Gate 2/QUALIFIED bằng MFA step-up mà không cần ngồi máy trạm, NVKD chủ deal theo dõi trạng thái ký 3 bên và đồng hồ SLA 4h của AM theo thời gian thực, và toàn bộ L1–L5 nhận cảnh báo push khi milestone Day 1/7/14/30 trượt mốc. Tính năng đảm bảo deal WON không bị kẹt ở khâu bàn giao vì người có quyền ký không có mặt tại văn phòng, đồng thời giữ nguyên ràng buộc "không ghi nhận = không tồn tại" — mọi ký/duyệt mobile đều đi qua approval engine của core với audit trail đầy đủ.

**Phạm vi:**
- Bao gồm: màn hình Handoff Package rút gọn cho mobile — hiển thị % hoàn thành 5 nhóm checklist bắt buộc, từng mục thiếu kèm responsible + due date, để SM quyết định có ký được hay không ngay trên điện thoại.
- Bao gồm: hành động ký Handoff của SM trên mobile với MFA step-up (TOTP token gắn device theo P0-02 §2.4) — hành động đẩy request đến approval engine của core; mobile không tự phán quyết Gate 2.
- Bao gồm: theo dõi trạng thái ký 3 bên (NVKD soạn → SM ký → OPS_AM xác nhận trong SLA 4h) với đồng hồ SLA hiển thị từ core; push cảnh báo khi AM sắp quá hạn hoặc đã quá hạn.
- Bao gồm: nhận feedback thiếu sót onboarding Day 1–30 mà OPS trả về (kèm mục package liên quan) và theo dõi việc khắc phục; push alert milestone Day 1/7/14/30 trượt mốc.
- Bao gồm: cảnh báo capacity trống = 0 cho GDKD (SALES_L5) + OPS_PLAN trước khi SM ký Gate 2; hiển thị trạng thái xác nhận capacity 24h sau WON (điều kiện mở DEPLOY).
- Bao gồm: theo dõi deploy timeline rút gọn D+0→D+5 trên mobile (D+0 tiền vào + LOI/HĐ; checklist tài nguyên trước D+4; Planning trong ngày D+0; ONGOING D+5) dạng chỉ báo trạng thái đọc từ core.
- Không bao gồm: soạn và cập nhật nội dung Handoff Package (5 nhóm checklist) — làm trên web nội bộ SYS-BCERP-WEB; mobile chỉ hiển thị và ký (mobile không dùng cho nhập liệu hàng loạt theo sales.md B.0).
- Không bao gồm: enforcement chặn Gate 2 khi checklist <100%, sinh dự án khi WON, SLA clock, audit log — thực thi tại service layer SYS-CORE-BACKEND; checklist chặn Gate 2 là machine-state đọc từ core.
- Không bao gồm: góc tiếp nhận của OPS (tiếp nhận package, thực thi onboarding, milestone pass/fail) — thuộc bản REQ-OPS-004 (FEAT-MBI-HONB-002) cùng module; góc portal khách (kích hoạt portal Day 14) thuộc SYS-PORTAL-WEB.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-MOBILE-INTERNAL — mobile nội bộ React Native offline-capable dành cho staff cần di động (duyệt-on-the-go, xem dashboard): sales nhận push và ký trên mobile; mọi quyết định giá trị cao yêu cầu MFA step-up và vẫn được core thực thi, mobile chỉ là kênh tương tác. Khi offline, ứng dụng chỉ cho xem dữ liệu cached và soạn thảo ghi chú; hành động ký bị vô hiệu cho đến khi có kết nối.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L4 (SM) | Nhận push "Handoff chờ ký" và ký Handoff Package ngay trên điện thoại với MFA step-up dù đang công tác xa | Gate 2 không bị chậm vì tôi không ở văn phòng |
| 2 | SALES_L4 (SM) | Thấy ngay trên mobile checklist nào còn thiếu (<100%) kèm responsible + due date trước khi ký | Không ký vào package chưa đủ — tránh bị OPS_AM trả về mất thời gian |
| 3 | SALES_L2 (NVKD chủ deal) | Xem trạng thái ký 3 bên và đồng hồ SLA 4h của AM theo thời gian thực trên mobile | Chủ động liên hệ/hối đúng lúc thay vì chờ passive |
| 4 | SALES_L2 (NVKD chủ deal) | Nhận push khi OPS trả về feedback thiếu sót trong Day 1–30, kèm đúng mục package cần khắc phục | Khắc phục theo đúng phạm vi đã ký, không tranh cãi miệng |
| 5 | SALES_L2 (NVKD chủ deal) | Nhận cảnh báo milestone Day 1/7/14/30 trượt mốc trên mobile | Bán được tiếng nói với khách và OPS trước khi onboarding gián đoạn |
| 6 | SALES_L5 (GDKD) | Nhận cảnh báo capacity trống = 0 trước khi SM ký Gate 2 | Chặn việc ký deal không có người chạy trước khi xảy ra |
| 7 | SALES_L4 (SM) | Xem trạng thái capacity 24h sau WON (đã/ chưa xác nhận — điều kiện mở DEPLOY) | Biết deal đã sẵn sàng đi vào triển khai hay chưa |
| 8 | SALES_L1 / SALES_L3 | Xem (view-only) tiến độ handoff và milestone của deal nhóm mình phụ trách | Được cập nhật tình trạng bàn giao khi hỗ trợ chủ deal |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Đặc thù touchpoint mobile nội bộ: mọi business rule được thực thi ở service layer SYS-CORE-BACKEND; mobile là kênh ký/duyệt/cảnh báo và KHÔNG được chứa logic nới lỏng gate. Nguồn: sales.md B.8 (BR-SALES-801/802/803), `documents/quy-trinh-lam-viec/04_Giai_doan_3_Trien_khai_Deploy.md` (KXN-5, KXN-10), `09_Phu_luc_Hang_so_Quy_trinh.md` §4 (KXN-11), sales.md B.0 (nguyên tắc multi-system + MFA step-up).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Handoff Package gồm 5 nhóm checklist bắt buộc; **Gate 2 chỉ mở khi checklist 100%** — core chặn tầng API nếu <100%, mục thiếu nào hiển thị rõ thiếu gì kèm responsible + due date. Mobile hiển thị trạng thái machine-state đọc từ core, không tự tính % hay tự mở gate. | SM bấm ký khi <100%: request bị core từ chối kèm danh sách mục thiếu; UI mobile vô hiệu nút ký để trải nghiệm rõ ràng nhưng UI không phải lớp enforcement |
| BR-002 | Ký 3 bên theo trình tự cố định: NVKD chủ deal soạn (web) → SM ký (web hoặc mobile — mobile là kênh ký chính từ Phase2) → OPS_AM xác nhận trong **SLA 4h** từ lúc SM ký; AM từ chối hoặc quá hạn → package trả về SM khắc phục, **credit deal tạm dừng** cho đến khi handoff lại thành công. | Gọi API ký sai trình tự (ký nhảy cóc) bị từ chối; quá SLA 4h core tự trả về SM + tạm dừng credit, push thông báo cả 3 bên |
| BR-003 | Mọi ký/duyệt giá trị cao trên mobile bắt buộc MFA step-up (TOTP) với token gắn device theo P0-02 §2.4; hành động đi qua approval engine của core — mobile không có nhánh xác thực riêng, không có logic nghiệp vụ cục bộ. | Request thiếu MFA step-up bị core từ chối; phát hiện mobile cache/bypass token là lỗi P0 |
| BR-004 | Handoff ngoài package (miệng, chat Zalo, email riêng) **không được công nhận** — áp dụng nguyên tắc hard gate "không ghi nhận = không tồn tại" (BR-SALES-000); OPS không nhận việc ngoài package. | Khiếu nại dự trên thỏa thuận miệng bị hệ thống từ chối xử lý — chỉ bản ghi package + chữ ký trên hệ thống có giá trị |
| BR-005 | Milestone Day 1/7/14/30 được core theo dõi sau khi AM xác nhận tiếp nhận; mobile push cảnh báo trượt mốc cho NVKD chủ deal + SM. Trạng thái kích hoạt portal của khách hiển thị trong milestone (mốc Day 14) — **đọc từ core**, sales chỉ xem và không vận hành portal. | Trượt mốc không có alert là lỗi hệ thống; sales can thiệp trực tiếp vào portal hoặc tự đổi trạng thái portal là vượt ranh giới — chỉ được báo cáo qua feedback package |
| BR-006 | WON cập nhật trong 24h → core tự sinh dự án + OPS_AM xác nhận capacity trong 24h — là **điều kiện mở DEPLOY**; capacity trống = 0 → hệ thống cảnh báo GDKD (SALES_L5) + OPS_PLAN **trước khi** SM ký Gate 2 (tránh ký deal không người chạy). | Sinh dự án thủ công ngoài hệ thống không được công nhận; ký Gate 2 khi cảnh báo capacity đỏ đang bật vẫn được phép nhưng phải ghi nhận cảnh báo vào audit log của gate |
| BR-007 | 6 Communication Rules được ký với khách tại Kick-off D+3: Rule 4 (Im lặng = Đồng ý 24h, không áp dụng budget/targeting) và Rule 6 (báo cáo 3 kênh Zalo + Email + Portal) có nguồn v2.3; **Rules 1/2/3/5 dùng bản dự thảo nội bộ đã được chủ dự án duyệt 12/09 làm chuẩn tạm thời** — ghi chú chờ khách hàng xác nhận nội dung chính thức `[KXN-11]`, khi có bản chính thức sẽ thay thế (v1.2). | Kick-off D+3 thiếu biên bản ký 6 Rules: D+5 (ONGOING) lùi theo; mobile hiển thị trạng thái "dự thảo — chờ chuẩn hóa" cho Rules 1/2/3/5 để không ai nhầm là chính sách chốt |
| BR-008 | Deploy timeline D+0→D+5 đọc từ core: **D+0** kích hoạt khi tiền vào tài khoản + Accountant confirm + LOI hoặc HĐ đã ký `[KXN-5 — đã chốt 12/09]`; HĐ đầy đủ chậm nhất 7 ngày sau D+0, cảnh báo sau 3 ngày chưa upload; checklist tài nguyên hoàn tất **trước D+4**; Planning sơ bộ (flow TT→ĐH→AD) hoàn thành trong ngày D+0; **ONGOING bắt đầu D+5** `[KXN-10 — đã phê chuẩn 12/09]` và lùi nếu tài nguyên chưa đủ. | Chưa đủ tiền/LOI-HĐ mà timeline tự nhảy D+0 là lỗi: chỉ core được set timestamp D+0 (paymentConfirmedAt, dStartDate); mobile chỉ hiển thị + nhận alert HĐ trễ |
| BR-009 | Offline-capable chỉ áp cho đọc dữ liệu cached và soạn thảo ghi chú/nhận xét cục bộ; **hành động ký, duyệt, xác nhận cấm thực hiện offline** — nút hành động vô hiệu khi không có kết nối; draft cục bộ không bao giờ tự đẩy lên core như một chữ ký. | Draft offline ghi nhãn rõ "chưa đồng bộ"; cố đẩy hành động ký khi offline bị chặn ở tầng client + core vẫn từ chối request thiếu timestamp/MFA |
| BR-010 | Mọi sự kiện (ký, từ chối, quá SLA, trả về, cảnh báo capacity, push milestone) ghi audit log bất biến ở core: ai, khi nào, trên package/deal nào, từ thiết bị nào; push notification là kênh thông báo — không phải chứng cứ quyết định. | Mất audit log của bất kỳ chữ ký nào làm package vô hiệu bắt ký lại; tranh chấp ưu tiên chữ ký web vs mobile không phát sinh — cả hai là cùng một bản ghi approval engine |
| BR-011 | Thiếu sót phát sinh Day 1–30 quay về NVKD chủ deal (SM theo dõi) khắc phục theo đúng mục package — ranh giới Sales ↔ OPS: OPS không nhận việc ngoài package, sales không vận hành thay OPS; credit deal tạm dừng khi package bị trả về (gắn BR-002). | OPS nhận việc ngoài package là vi phạm ranh giới — phản ánh vào milestone fail; sales "làm hộ" vận hành cũng bị chặn vì không có quyền trên công cụ OPS |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI mobile nội bộ. Chỉ dùng 18 vai registry; OPS_AM xuất hiện để phân định đầu mút bàn giao (chi tiết thao tác thuộc bản REQ-OPS-004 — FEAT-MBI-HONB-002). Mobile không có vai nào được cấu hình bypass gate hay ký hộ người khác.

| Hành động | SALES_L2 (chủ deal) | SALES_L4 (SM) | SALES_L1 / SALES_L3 | SALES_L5 (GDKD) | OPS_AM | SYS_ADMIN |
|-----------|---------------------|---------------|---------------------|------------------|--------|-----------|
| Xem Handoff Package (checklist, % hoàn thành) | ✅ (deal của mình) | ✅ (nhóm mình) | ✅ (view-only deal nhóm) | ✅ (toàn phòng) | ✅ (package gửi mình) | ❌ |
| Soạn/sửa nội dung package | ❌ (trên web — khỏi mobile) | ❌ (trên web) | ❌ | ❌ | ❌ | ❌ |
| Ký Handoff (MFA step-up) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận tiếp nhận (SLA 4h) | ❌ | ❌ | ❌ | ❌ | ✅ (bản FEAT-MBI-HONB-002) | ❌ |
| Xem đồng hồ SLA ký 3 bên | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Nhận push cảnh báo milestone trễ | ✅ | ✅ | ✅ | ✅ | ❌ (kênh của OPS góc 002) | ❌ |
| Nhận cảnh báo capacity trống = 0 | ❌ (nhận qua SM) | ✅ | ❌ | ✅ | ✅ (OPS_PLAN nhận — bản 002) | ❌ |
| Xem trạng thái kích hoạt portal (Day 14) | ✅ (đọc từ core) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Vận hành portal / đổi trạng thái portal | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại trên mobile) |
| Xem deploy timeline D+0→D+5 | ✅ (view) | ✅ (view) | ✅ (view) | ✅ (view) | ✅ | ❌ |
| Xem audit log chữ ký | ✅ (deal của mình) | ✅ | ❌ | ✅ | ✅ | ❌ |

SALES_L1 (Intern) và SALES_L3 (TNKD) chỉ có quyền đọc để phối hợp — không có hành động ký nào. SYS_ADMIN không có quyền nghiệp vụ trên package; vai admin chỉ phục vụ vận hành hệ thống và mọi thao tác quản trị bị audit log. Không vai nào trong bảng có quyền tắt gate 100% hay ký thay người khác — hành động này không tồn tại trên mobile để code không có nhánh kiểm tra tương ứng.

---

## 5. Trường Hợp Đặc Biệt

- SM bận họp/đi đường dài, package chờ ký quá 1 ngày làm việc: hệ thống escalate lên SALES_L5 (GDKD) theo SLA gate của core; GDKD không ký hộ SM — chỉ được thúc thông qua phân công hoặc mời SM xử lý; ký thay người không tồn tại trên mọi kênh.
- AM xác nhận trễ quá SLA 4h nhưng vẫn xác nhận sau đó: core ghi nhận violation SLA vào audit log, package vẫn tiếp nhận; credit deal tạm dừng trong khoảng trả về (nếu có) và được khôi phục khi handoff lại thành công — mobile hiển thị trạng thái "đã tiếp nhận (quá SLA)" minh bạch cả hai phía.
- Deal bị trả về từ Gate 2 nhiều lần: mỗi vòng trả về tạo phiên package mới kèm lịch sử; credit tạm dừng suốt thời gian chưa handoff lại thành công (theo BR-SALES-904) — mobile hiển thị badge "credit đang tạm dừng" để SM nắm rõ hệ quả.
- Khách tái ký (renewal): được rút gọn Initial Brief nhưng **không bỏ Gate 1/Gate 2** — checklist 5 nhóm vẫn phải 100% trước khi SM ký; mobile đánh dấu deal renewal để lộ trình ký hiển thị rút gọn đúng phạm vi.
- Mất kết nối giữa lúc mở màn ký: app mobile giữ màn hình ở chế độ đọc cached, nút ký vô hiệu kèm thông báo "cần kết nối + MFA"; không có cơ chế "ký rồi đồng bộ sau" cho bất kỳ hành động giá trị cao nào.
- Device bị mất/thay: token TOTP gắn device theo P0-02 §2.4 — SM đăng ký lại device phải qua quy trình re-bind có xác thực; mọi ký từ device chưa bind bị core từ chối.
- Tiền đã vào nhưng chưa đủ cho phase 1 (theo tài liệu Deploy): Accountant chưa confirm → D+0 chưa kích hoạt, timeline mobile hiển thị "chờ đủ số" — không push nhầm D+0 cho sales.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Handoff Package (gắn deal) — machine-state do core quản lý qua approval engine; mobile gửi hành động hợp lệ (ký, ghi nhận feedback) và hiển thị trạng thái. Đồng hồ SLA 4h chạy ở core từ timestamp SM ký.

**Sơ đồ trạng thái:**
```
[SOẠN_THẢO (web)] ──(submit đủ 100%)──► [CHỜ_SM_KÝ] ──(SM ký + MFA)──► [CHỜ_AM_XÁC_NHẬN (SLA 4h)]
                                             ▲                              │        │
                                             │ (khắc phục + resubmit)       │        │ (AM xác nhận ≤4h)
                                             │                              │        ▼
                                         [TRẢ_VỀ_SM] ◄──(AM từ chối / quá 4h)┘   [HANDOFF_HOÀN_TẤT]
                                             │                                        │
                                             │                                        │ (WON ≤24h + capacity ✅)
                                             ▼                                        ▼
                                     (credit deal tạm dừng)                  [DỰ ÁN SINH → DEPLOY MỞ]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `SOẠN_THẢO` | Submit package | `CHỜ_SM_KÝ` | SALES_L2 chủ deal (web) | Checklist 5 nhóm đạt 100% — core chặn nếu thiếu |
| `CHỜ_SM_KÝ` | SM ký | `CHỜ_AM_XÁC_NHẬN` | SALES_L4 (MFA step-up, web hoặc mobile) | Không có cảnh báo capacity chặn chưa được xem xét; core set timestamp bắt đầu SLA 4h |
| `CHỜ_SM_KÝ` | GDKD thúc/escalate | `CHỜ_SM_KÝ` (không đổi) | SALES_L5 | Chỉ ghi log thúc — không đổi trạng thái, không ký hộ |
| `CHỜ_AM_XÁC_NHẬN` | AM xác nhận | `HANDOFF_HOÀN_TẤT` | OPS_AM (bản FEAT-MBI-HONB-002) | Trong SLA 4h từ timestamp SM ký |
| `CHỜ_AM_XÁC_NHẬN` | AM từ chối hoặc quá 4h | `TRẢ_VỀ_SM` | OPS_AM / hệ thống (SLA timeout) | AM từ chối phải nhập lý do gắn mục package; quá hạn core tự trả về |
| `TRẢ_VỀ_SM` | Khắc phục + resubmit | `CHỜ_SM_KÝ` | SALES_L2 chủ deal (web) | Các mục thiếu đã bổ sung đủ 100%; credit deal tạm dừng trong suốt trạng thái này |
| `HANDOFF_HOÀN_TẤT` | WON xác nhận + capacity OK | `DỰ ÁN SINH → DEPLOY MỞ` | Hệ thống + OPS_AM xác nhận capacity 24h | WON cập nhật ≤24h; capacity xác nhận ≤24h — điều kiện mở DEPLOY (timeline D+0 riêng theo BR-008) |

**Quy tắc:**
- Không thể quay về trạng thái trước tùy tiện: `HANDOFF_HOÀN_TẤT` chỉ quay lại luồng khắc phục qua cơ chế feedback thiếu sót Day 1–30 (tạo ghi nhận gắn package, không đè lịch sử).
- `TRẢ_VỀ_SM` không hủy package — là trạng thái sửa chữa có đếm số vòng; số vòng trả về hiển thị trên mobile để GDKD rà chất lượng soạn package.
- Trạng thái `HANDOFF_HOÀN_TẤT` là điều kiện cần (không đủ) để mở DEPLOY: còn phải thỏa WON ≤24h + capacity xác nhận + D+0 kích hoạt theo BR-008.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| HandoffPackage | `id`, `deal_id`, `version`, `status`, `submitted_at`, `sm_signed_at`, `am_confirmed_at`, `return_count` | FK → Deal | Chi tiết DDL tại `database-design.md`; version hóa mỗi vòng trả về |
| HandoffChecklistItem | `package_id`, `group` (1–5), `title`, `responsible_id`, `due_date`, `is_done`, `evidence_ref` | FK → `handoff_package.id` | 5 nhóm bắt buộc; đủ 100% mới submit được |
| GateSignature | `package_id`, `role` (NVKD/SM/AM), `signed_by`, `signed_at`, `channel` (WEB/MOBILE), `device_id`, `mfa_verified` | FK → `handoff_package.id` | Ghi channel để thống kê kênh ký; MFA bắt buộc trên MOBILE |
| OnboardingMilestone | `package_id`, `milestone` (DAY1/DAY7/DAY14/DAY30), `criteria`, `status` (PASS/FAIL/PENDING), `due_at`, `feedback_ref` | FK → `handoff_package.id` | Trạng thái portal activation gắn mốc Day 14 — đọc từ core |
| CommunicationRulesConsent | `package_id`, `rules_version`, `signed_at`, `customer_signer`, `document_ref` | FK → `handoff_package.id` | Ký tại Kick-off D+3; Rules 1/2/3/5 theo bản dự thảo đã duyệt `[KXN-11]` |
| DeployTimelineEvent | `project_id`, `event` (D0/PRE_D4/D0_PLANNING/D3_KICKOFF/D5_ONGOING), `status`, `occurred_at`, `alert_ref` | FK → Project | D+0 do core set khi đủ tiền + LOI/HĐ `[KXN-5]`; ONGOING D+5 `[KXN-10]` |
| MobileApprovalAction | `action_id`, `entity_ref`, `actor_id`, `device_id`, `mfa_token_id`, `requested_at`, `core_response` | FK → entity đích | Mọi hành động ký/duyệt mobile ghi 1 dòng; cấm tồn tại khi offline |
| PushNotification | `id`, `recipient_id`, `type` (SLA_WARN/MILESTONE_LATE/CAPACITY_RED/RETURN), `payload_ref`, `sent_at`, `read_at` | FK → User | Kênh thông báo, không phải chứng cứ quyết định |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn ký khi checklist thiếu | Package 4,5/5 nhóm hoàn thành | SM mở màn ký trên mobile | Nút ký vô hiệu; danh sách mục thiếu kèm responsible + due date; gọi thẳng API vẫn bị core từ chối | [ ] |
| SC-002: Ký mobile với MFA step-up | Package 100%, SM online bằng device đã bind | SM ký trên mobile với TOTP | Approval engine core ghi GateSignature (channel=MOBILE, mfa_verified=true); SLA 4h bắt đầu chạy; push tới OPS_AM | [ ] |
| SC-003: Quá SLA 4h tự trả về | Package ở CHỜ_AM_XÁC_NHẬN quá 4h không có action | Core chạy SLA clock | Trạng thái chuyển TRẢ_VỀ_SM, credit deal tạm dừng, push thông báo SM + NVKD + AM có timestamp | [ ] |
| SC-004: Cảnh báo capacity đỏ trước Gate 2 | Capacity trống = 0 cho demand của deal | SM sắp ký Gate 2 | Push cảnh báo tới GDKD + OPS_PLAN; cảnh báo ghi vào audit log của gate khi SM vẫn ký | [ ] |
| SC-005: Milestone trượt mốc push | Mốc Day 7 sắp quá hạn, 1 tiêu chí fail | Core đánh giá milestone | Push MILESTONE_LATE tới NVKD + SM kèm tiêu chí fail và owner khắc phục | [ ] |
| SC-006: Offline không ký được | Mobile mất mạng, có draft ghi chú | Người dùng bấm ký | Nút ký vô hiệu kèm thông báo cần kết nối + MFA; draft chỉ lưu cục bộ, không tạo chữ ký | [ ] |
| SC-007: Trạng thái portal chỉ đọc | Deal qua mốc Day 14, khách đã kích hoạt portal | Sales xem milestone trên mobile | Hiển thị trạng thái portal đọc từ core; không tồn tại nút thao tác portal nào trên mobile | [ ] |
| SC-008: Timeline D+0 không tự nhảy | Tiền đã vào nhưng Accountant chưa confirm / chưa có LOI-HĐ | Sales xem deploy timeline | D+0 hiển thị "chưa kích hoạt — chờ đủ điều kiện"; không có push D+0 nào phát ra | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-SALES-008 (Mục 2 — package 5 nhóm chặn Gate 2, ký 3 bên SLA 4h, milestone Day 1/7/14/30, WON tự sinh dự án + capacity 24h).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/mobile-internal/handoff-onboard/handoff-sales.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/handoff-onboard/` (gate engine, checklist chặn Gate 2, SLA clock, tự sinh dự án) và `phase2-features/bcerp-web/handoff-onboard/` (soạn package, dashboard milestone) — REQ-SALES-008 xuất hiện ở 3 systems, bản này là bản SYS-MOBILE-INTERNAL |
| Bản góc OPS cùng touchpoint | `phase2-features/mobile-internal/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md` (FEAT-MBI-HONB-002 — REQ-OPS-004) |
| Nguồn domain | `documents/quy-trinh-lam-viec/04_Giai_doan_3_Trien_khai_Deploy.md` (Deploy D+0→D+5, KXN-5, KXN-10), `08_Ma_tran_RACI_Gate_SLA.md` (G3, SLA AM 4h) `[KXN-19 — ma trận RACI chờ khách xác nhận, dùng làm tham chiếu]`, `09_Phu_luc_Hang_so_Quy_trinh.md` §4 (6 Communication Rules, KXN-11) |
