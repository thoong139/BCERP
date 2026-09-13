# Tính Năng: Handoff & Onboarding Bridge — Góc Tiếp Nhận OPS

> **Dựa trên:** REQ-OPS-004 trong `phase1-business/departments/operations/operations.md` (Phần A, B.3)
> **Phân hệ:** Mobile nội bộ BCERP (SYS-MOBILE-INTERNAL)
> **Module:** Handoff & Onboarding Bridge (MOD-HANDOFF-ONBOARD)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `documents/quy-trinh-lam-viec/` (04 Deploy, 08 RACI/Gate/SLA, 09 Hằng số)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-HONB-002 |
| Module | MOD-HANDOFF-ONBOARD |
| Yêu cầu nghiệp vụ | REQ-OPS-004 — Handoff & Onboarding Bridge (HIGH, Phase2) |
| Người dùng liên quan | OPS_AM (chính — tiếp nhận, xác nhận SLA 4h, phụ trách milestone), OPS_PLAN (TL — nhận escalate capacity/trượt mốc), OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (nhận task khởi động dự án); SALES_L4 (SM ký — đầu mút bán giao, chi tiết bản REQ-SALES-008); HR_L2 (đích escalate capacity) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase2 — mobile là kênh AM xác nhận handoff khi di chuyển theo operations.md A.3) |
| Phụ thuộc | Cross-dependency REQ-SALES-008 — Handoff Bridge góc Sales: nguồn Handoff Package 5 nhóm do Sales soạn và SM ký (bản counterpart FEAT-MBI-HONB-001 cùng module); capacity check từ REQ-OPS-007 (MOD-CAPACITY-TIMESHEET); khởi tạo TKQC theo demand nối REQ-OPS-001 (MOD-ADACCOUNT-CC); workflow gate + tự sinh dự án thực thi tại SYS-CORE-BACKEND |
| Ghi chú Expert (A7) | Operations.md Mục A7: chưa có đánh giá chính thức (chờ review); REQ-OPS-004 fan-out 3 systems — bản này là bản riêng SYS-MOBILE-INTERNAL, counterparts tại SYS-CORE-BACKEND và SYS-BCERP-WEB |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Trên mobile nội bộ (React Native, offline-capable), tính năng trang bị cho OPS_AM — vai có phạm vi di chuyển nhiều nhất trong lifecycle — khả năng tiếp nhận bàn giao và điều hành onboarding mà không bị treo vào máy trạm: xác nhận tiếp nhận Handoff Package trong SLA 4h ngay trên điện thoại với MFA step-up, nhận push từng mốc Day 1/7/14/30 kèm tiêu chí pass/fail, và bám sát deploy timeline D+0→D+5 (D+0 tiền vào + LOI/HĐ, checklist tài nguyên trước D+4, Planning trong ngày D+0, ONGOING D+5) ở bất kỳ đâu. Tính năng đồng thời phân phối task khởi động xuống team (CONT/DES/EDIT/ADS) qua push, bảo đảm đồng hồ onboarding chỉ bắt đầu khi AM xác nhận và mọi trượt mốc được escalate đúng chuỗi TL → cấp trên thay vì mất trong hội thoại Zalo.

**Phạm vi:**
- Bao gồm: màn hình tiếp nhận Handoff Package cho OPS_AM — nội dung 5 nhóm checklist (hợp đồng & phạm vi, tài sản QC & tracking, mục tiêu & baseline KPI, vận hành, điều kiện khởi động) hiển thị dạng đọc kèm trạng thái machine-state từ core; hành động xác nhận tiếp nhận hoặc từ chối (kèm lý do gắn mục checklist) với MFA step-up.
- Bao gồm: theo dõi đồng hồ SLA 4h của phiên ký 3 bên (từ timestamp SM ký) và nhận cảnh báo sắp hết hạn/quá hạn; khi quá hạn, core tự trả package về Sales và tạm dừng credit deal — mobile hiển thị kết quả.
- Bao gồm: milestone Day 1/7/14/30 dạng checklist có tiêu chí đạt cụ thể (đúng bảng pass/fail của operations.md B.3), push trượt mốc cho OPS_AM + OPS_PLAN, và màn escalate root cause (mốc Day 14 là gate — trượt phải có kế hoạch khắc phục owner + deadline trong 24h).
- Bao gồm: xác nhận capacity sau WON (cửa sổ 24h — điều kiện mở DEPLOY) và nhận escalate capacity check gắn Gate 2 theo chuỗi SLA 4h → TL (8h) → HR_L2; hiển thị trạng thái "xác nhận Capacity trống" đọc từ core.
- Bao gồm: theo dõi deploy timeline D+0→D+5 và nhận alert nghiệp vụ deploy: D+0 kích hoạt khi tiền vào + Accountant confirm + LOI/HĐ, cảnh báo HĐ chưa upload sau 3 ngày, checklist tài nguyên chưa đủ trước D+4 (D+5 tự lùi), biên bản 6 Communication Rules ký tại Kick-off D+3.
- Bao gồm: phân phối thông báo task khởi động (map TKQC vào registry, cấu hình tracking, tạo CLIENT_ADMIN đầu tiên) cho OPS_CONT/OPS_DES/OPS_EDIT/OPS_ADS qua push — phân công chi tiết và timesheet thuộc MOD-CAPACITY-TIMESHEET.
- Không bao gồm: soạn/sửa nội dung Handoff Package — thuộc Sales (web SYS-BCERP-WEB); OPS chỉ tiếp nhận và phản hồi thiếu sót.
- Không bao gồm: engine chặn Gate 2, SLA clock, tự sinh dự án, provisioning portal (tạo CLIENT_ADMIN, tenant) — thực thi tại service layer SYS-CORE-BACKEND; mobile chỉ gửi hành động và hiển thị machine-state.
- Không bao gồm: trải nghiệm portal phía khách (kích hoạt portal là phần khách thực hiện trên SYS-PORTAL-WEB — mốc Day 14 của bảng milestone) và các thao tác vận hành TKQC chi tiết — thuộc MOD-ADACCOUNT-CC.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-MOBILE-INTERNAL — mobile nội bộ React Native offline-capable cho staff cần di động (duyệt-on-the-go, xem dashboard): OPS_AM dùng mobile làm kênh xác nhận và cảnh báo khi không ngồi văn phòng; mọi hành động giá trị cao qua approval engine của core với MFA step-up. Khi offline, chỉ xem dữ liệu cached; hành động xác nhận cấm thực hiện không có kết nối.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Nhận push "Handoff chờ tiếp nhận" và xác nhận trong SLA 4h ngay trên điện thoại với MFA step-up | Đồng hồ onboarding bắt đầu đúng giờ dù tôi đang ở ngoài văn phòng |
| 2 | OPS_AM | Xem đủ nội dung 5 nhóm checklist trên mobile trước khi xác nhận | Tiếp nhận đúng phạm vi đã ký, không phát sinh việc ngoài package về sau |
| 3 | OPS_AM | Từ chối tiếp nhận kèm lý do gắn đúng mục checklist ngay trên mobile | Sales khắc phục đúng điểm thiếu, không tranh cãi bằng trích tin nhắn |
| 4 | OPS_AM | Nhận cảnh báo khi đồng hồ SLA 4h còn 1h hoặc đã quá hạn | Kịp xử lý trước khi core tự trả package về Sales và credit deal bị tạm dừng |
| 5 | OPS_AM | Nhận push từng mốc Day 1/7/14/30 kèm tiêu chí pass/fail và kết quả đánh giá | Biết ngay mốc nào trượt để chạy kế hoạch khắc phục theo deadline |
| 6 | OPS_PLAN (TL) | Nhận escalate khi capacity check gắn Gate 2 quá SLA 4h (chuỗi 4h → 8h → HR_L2) và khi mốc onboarding trượt | Điều phối người/kế hoạch khắc phục trước khi deal bị treo |
| 7 | OPS_CONT / OPS_DES / OPS_EDIT | Nhận push task khởi động Day 1 (audit naming/UTM, map TKQC vào registry) gắn dự án vừa tiếp nhận | Bắt tay việc đúng mốc không cần chờ AM nhắc trên chat |
| 8 | OPS_ADS | Xem trạng thái demand TKQC cần khởi tạo theo checklist nhóm 5 trên mobile | Chuẩn bị đăng ký/cấp phát TKQC đúng tiến độ mà không đụng vào registry trực tiếp từ mobile |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Đặc thù touchpoint mobile nội bộ: mọi rule được thực thi ở service layer SYS-CORE-BACKEND; mobile là kênh tiếp nhận/duyệt/cảnh báo và KHÔNG chứa logic nới lỏng gate. Nguồn: operations.md B.3 (BR-OPS-3.1/3.2), `documents/quy-trinh-lam-viec/04_Giai_doan_3_Trien_khai_Deploy.md` (KXN-5, KXN-10), `09_Phu_luc_Hang_so_Quy_trinh.md` §4 (KXN-11), operations.md B.1 (ranh giới nhận việc ngoài package).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | OPS chỉ tiếp nhận Handoff Package hoàn chỉnh: 5 nhóm checklist bắt buộc — **(1) Hợp đồng & phạm vi dịch vụ** (tier, SLA áp dụng, ngân sách), **(2) Tài sản QC & tracking** (TKQC + quyền truy cập, pixel/CAPI/UTM, creative assets, brand guideline), **(3) Mục tiêu & baseline KPI** (conversion/traffic/awareness), **(4) Vận hành** (POC khách, ngôn ngữ/múi giờ, lịch họp, lịch làm việc khách), **(5) Điều kiện khởi động** (capacity check, Brand Safety, demand TKQC cần khởi tạo). Gate 2 chỉ mở khi checklist **100%** — machine-state do core quyết định. | Package <100% không đến được luồng xác nhận của AM; nếu Sales cố đẩy, core từ chối ở tầng API — mobile hiển thị "chưa đủ điều kiện tiếp nhận" |
| BR-002 | Ký 3 bên: SM ký + hệ thống tự sinh dự án + OPS_AM xác nhận trong **SLA 4h**; từ lúc AM xác nhận, đồng hồ onboarding bắt đầu. Xác nhận/từ chối trên mobile bắt buộc MFA step-up (TOTP gắn device theo P0-02 §2.4) qua approval engine của core. | Quá SLA 4h: core tự trả package về Sales, credit deal tạm dừng; request thiếu MFA bị từ chối; mobile không có nhánh xác nhận riêng lệch core |
| BR-003 | AM từ chối tiếp nhận phải nhập lý do gắn đúng mục checklist — phản hồi thiếu sót có cấu trúc, không ghi tự do; Sales khắc phục theo package. **OPS không nhận việc ngoài package** — handoff miệng/chat không được công nhận; việc phát sinh Day 1–30 quay về SM khắc phục. | Yêu cầu "làm thêm việc ngoài package" bị AM từ chối hợp lệ; tranh chấp phạm vi giải theo bản ghi checklist, không theo hội thoại |
| BR-004 | Milestone Day 1/7/14/30 là checklist có tiêu chí đạt cụ thể do core đánh giá (bảng BR-OPS-3.2): Day 1 — 100% TKQC map đúng naming/owner/backup + khách đăng nhập portal lần đầu; Day 7 — tracking chạy (≥1 conversion test) + ≥80% portal user kích hoạt + 2FA 100%; Day 14 — **GATE kích hoạt portal thành công** (khách tự xem số dư/chi tiêu/ticket; ≥1 login/tuần từ ≥2 user); Day 30 — review 30 ngày đầu vs baseline gửi khách. Mobile push kết quả từng mốc cho OPS_AM + OPS_PLAN. | Mốc fail không được đánh "pass" tay trên mobile — trạng thái chỉ do core set; trượt gate Day 14 bắt buộc escalate root cause trong 24h kèm kế hoạch khắc phục có owner + deadline |
| BR-005 | Capacity check "xác nhận Capacity trống" gắn Gate 2 — SLA 4h; quá hạn escalate TL (OPS_PLAN) ở mốc 8h, rồi HR_L2; sau WON, OPS_AM xác nhận capacity trong **24h** là điều kiện mở DEPLOY; khởi tạo TKQC theo demand khách nối registry (MOD-ADACCOUNT-CC). Mobile chỉ hiển thị trạng thái và nhận escalate — không thao tác cấu hình capacity. | Quá chuỗi escalate mà chưa có người nhận việc: gate tiếp tục chặn, cảnh báo leo cấp; không ai được "xác nhận hộ" capacity trên mobile — hành động này chỉ tồn tại trên web theo bản CORE/WEB |
| BR-006 | 6 Communication Rules ký với khách tại Kick-off D+3: Rule 4 (Im lặng = Đồng ý 24h — không áp dụng budget/targeting) và Rule 6 (báo cáo 3 kênh Zalo + Email + Portal) có nguồn v2.3; **Rules 1/2/3/5 dùng bản dự thảo nội bộ đã duyệt 12/09 làm chuẩn tạm thời** — ghi chú chờ khách hàng xác nhận nội dung chính thức `[KXN-11]`. Biên bản ký (PDF) upload PMS + gửi email khách; từ chối ký → AD negotiate, D+5 tự lùi. | Thiếu biên bản 6 Rules: ONGOING D+5 không được kích hoạt; mobile hiển thị nhãn "dự thảo — chờ chuẩn hóa" cho Rules 1/2/3/5 để team không diễn giải thành chính sách chốt |
| BR-007 | Deploy timeline D+0→D+5 do core quản lý: **D+0** chỉ kích hoạt khi tiền vào tài khoản + Accountant confirm + LOI hoặc HĐ đã ký `[KXN-5 — đã chốt 12/09]`; HĐ đầy đủ chậm nhất 7 ngày sau D+0 (cảnh báo sau 3 ngày chưa upload); checklist tài nguyên (pixel, quyền ad account, fanpage/ad account) hoàn tất **trước D+4** — thiếu thì D+5 lùi; **Planning sơ bộ theo flow TT→ĐH→AD hoàn thành trong ngày D+0**; Kick-off nội bộ D+1/D+2 không lùi; **ONGOING bắt đầu D+5** `[KXN-10 — đã phê chuẩn 12/09]`. | D+0 chưa đủ điều kiện mà hệ thống hiện "đang triển khai" là lỗi nghiêm trọng — chỉ core set paymentConfirmedAt/dStartDate; mobile chỉ nhận alert HĐ trễ 3 ngày và checklist tài nguyên thiếu |
| BR-008 | Offline-capable chỉ cho đọc cached + soạn thảo ghi chú cục bộ; hành động xác nhận tiếp nhận/từ chối **cấm thực hiện offline**; draft cục bộ ghi nhãn "chưa đồng bộ" và không bao giờ tự nâng thành quyết định. | Bấm xác nhận khi mất mạng: nút vô hiệu ở tầng client và core vẫn từ chối request thiếu timestamp/MFA — không tồn tại cơ chế "xác nhận rồi đồng bộ sau" |
| BR-009 | Mọi sự kiện (xác nhận, từ chối, quá SLA, escalate, trượt mốc, alert deploy) ghi audit log bất biến ở core: ai, khi nào, package/milestone nào, từ thiết bị nào; push notification chỉ là kênh thông báo — không có giá trị chứng cứ thay thế bản ghi. | Mất audit log của một xác nhận làm phiên tiếp nhận vô hiệu phải ký lại; hai xác nhận trùng (web + mobile) là một bản ghi approval engine — không phát sinh mâu thuẫn |
| BR-010 | Phân phối task qua push phải gắn dự án đã sinh từ WON ("campaign/dự án không gắn hồ sơ = không tồn tại"); task hiển thị trên mobile là thông báo — việc gán chính thức, capacity check trước gán và timesheet thuộc MOD-CAPACITY-TIMESHEET; mobile không dùng cho nhập liệu hàng loạt. | Task push không có bản ghi dự án ở core không được hiển thị; nhận việc qua chat/miệng ngoài task hệ thống không được công nhận khi đối chiếu milestone |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI mobile nội bộ. Chỉ dùng 18 vai registry; SALES_L4 xuất hiện để phân định đầu mút bán giao (thao tác ký chi tiết thuộc bản REQ-SALES-008 — FEAT-MBI-HONB-001). Mobile không có vai nào ký hộ, xác nhận hộ hay cấu hình bypass.

| Hành động | OPS_AM | OPS_PLAN (TL) | OPS_CONT / OPS_DES / OPS_EDIT | OPS_ADS | SALES_L4 (SM) | HR_L2 | SYS_ADMIN |
|-----------|--------|---------------|-------------------------------|---------|----------------|-------|-----------|
| Xem Handoff Package 5 nhóm (đọc) | ✅ | ✅ | ✅ (nhóm 2/4 liên quan task) | ✅ (nhóm 2/5) | ✅ | ❌ | ❌ |
| Xác nhận tiếp nhận (SLA 4h, MFA) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Từ chối tiếp nhận kèm lý do gắn checklist | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xem đồng hồ SLA ký 3 bên | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Nhận push trượt mốc Day 1/7/14/30 | ✅ | ✅ | ✅ (task của mình) | ✅ (task của mình) | ✅ (feedback chiều Sales) | ❌ | ❌ |
| Escalate root cause mốc Day 14 (kế hoạch khắc phục) | ✅ (soạn trên web, ghi nhận trên mobile) | ✅ (duyệt trên web) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Nhận escalate capacity (4h → 8h) | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ (đích cuối 8h+) | ❌ |
| Xác nhận capacity sau WON (24h) | ❌ (trên web — khỏi mobile) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Cấu hình capacity/định mức giờ | ❌ | ❌ (chỉ sử dụng) | ❌ | ❌ | ❌ | ❌ (đề xuất qua REQ-OPS-007 — BOD duyệt) | ❌ |
| Xem deploy timeline D+0→D+5 + alert | ✅ | ✅ | ✅ | ✅ | ✅ (view) | ❌ | ❌ |
| Xem audit log tiếp nhận | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |

OPS_CONT/OPS_DES/OPS_EDIT/OPS_ADS có quyền đọc phần checklist liên quan nhiệm vụ sản xuất/ads và nhận push task — không có hành động quyết định trên luồng bàn giao. SYS_ADMIN không có quyền nghiệp vụ; mọi thao tác quản trị bị audit log. Hành động xác nhận capacity và cấu hình định mức cố ý không xuất hiện trên mobile: đây là các quyết định đòi hỏi bối cảnh đầy đủ trên web và dữ liệu nguồn sự thật của REQ-OPS-007 — đặt lên mobile sẽ tạo rủi ro xác nhận thiếu ngữ cảnh khi di chuyển.

---

## 5. Trường Hợp Đặc Biệt

- AM nghỉ phép/ngồi xe lâu giữa cửa sổ SLA 4h: hệ thống push cho OPS_PLAN (TL) như backup theo cấu hình AM Backup (định nghĩa tại Kick-off nội bộ D+1); xác nhận vẫn phải do người có vai OPS_AM thực hiện với MFA — TL không ký hộ bằng vai khác, không có cơ chế ủy quyền chữ ký trên mobile.
- Khách tái ký (renewal): được rút gọn Initial Brief nhưng **không bỏ Gate 1/Gate 2** — AM vẫn tiếp nhận package 5 nhóm đủ 100%; checklist nhóm 3 (baseline KPI) tận dụng dữ liệu kỳ trước nhưng vẫn phải ghi nhận rõ ràng, không kế thừa im lặng.
- Khách chưa có fanpage/ad account (theo tài liệu Deploy): AM hỗ trợ tạo mới theo hướng dẫn — checklist tài nguyên chưa đủ thì D+5 tự lùi; mobile hiển thị nguyên nhân lùi (thiếu pixel/quyền/fanpage) để cả Sales và khách thấy cùng một căn cứ.
- Tiền vào nhưng thiếu so với phase 1: Accountant báo AM ngay, chưa trigger D+0 cho đến khi đủ số; AM chủ động liên hệ khách qua mobile trong lúc di chuyển — nội dung đàm phán không thay thế được xác nhận của Accountant trên core.
- Mốc Day 14 trượt do lỗi phía khách (không login portal): gate vẫn tính là trượt — escalate root cause 24h, kế hoạch khắc phục phân định phần việc BC vs phần khách kích hoạt; trạng thái hiển thị minh bạch trên milestone để Sales dùng giải thích với khách.
- HĐ chưa ký sau 3 ngày từ D+0: PMS/core cảnh báo AM + AD (hasContractWarning); AM follow up ký HĐ — HĐ đầy đủ chậm nhất 7 ngày sau D+0 `[KXN-5]`; quá hạn 7 ngày leo cấp OPS_PLAN + Sales SM xử lý rủi ro pháp lý.
- Nhiều package đến cùng lúc (mùa cao điểm WON): hàng đợi tiếp nhận sắp theo deadline SLA còn lại; mobile hiển thị thứ tự khuyến nghị — AM vẫn phải tự xác nhận từng package, không có hành động "xác nhận hàng loạt" trên mobile.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Phiên tiếp nhận Handoff (gắn package + dự án) — machine-state do core quản lý; OPS_AM gửi hành động xác nhận/từ chối từ mobile, core thực thi chuyển trạng thái và chạy SLA clock.

**Sơ đồ trạng thái:**
```
[PACKAGE_GỬI_TỚI] ──(AM xác nhận + MFA ≤4h)──► [TIẾP_NHẬN — đồng hồ onboarding bắt đầu]
        │                                              │
        │ (quá SLA 4h / AM từ chối kèm lý do)          │ (milestone Day1/7/14/30 đánh giá)
        ▼                                              ▼
   [TRẢ_VỀ_SALES] ◄──────────────────────► [ONBOARDING ĐANG CHẠY → GATE Day14 → HOÀN_TẤT Day30]
        │                                              │
        └──(Sales khắc phục, resubmit)──► [PACKAGE_GỬI_TỚI]    (trượt gate → ESCALATED_24H → kế hoạch khắc phục)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PACKAGE_GỬI_TỚI` | Xác nhận tiếp nhận | `TIẾP_NHẬN` | OPS_AM (MFA, web hoặc mobile) | Trong SLA 4h từ timestamp SM ký; core tự sinh dự án đồng thời |
| `PACKAGE_GỬI_TỚI` | Từ chối tiếp nhận | `TRẢ_VỀ_SALES` | OPS_AM | Lý do bắt buộc gắn đúng mục checklist; credit deal tạm dừng |
| `PACKAGE_GỬI_TỚI` | SLA timeout 4h | `TRẢ_VỀ_SALES` | Hệ thống | Core tự trả về + push 3 bên có timestamp; credit deal tạm dừng |
| `TRẢ_VỀ_SALES` | Khắc phục + resubmit | `PACKAGE_GỬI_TỚI` | Sales (bản FEAT-MBI-HONB-001) | Checklist đủ 100% lại; phiên mới, lịch sử giữ nguyên |
| `TIẾP_NHẬN` | Đánh giá milestone | `ONBOARDING ĐANG CHẠY` | Hệ thống (theo mốc Day1/7) | Tiêu chí pass/fail bảng BR-004; fail → cảnh báo + hành động khắc phục có owner |
| `ONBOARDING ĐANG CHẠY` | Qua gate Day 14 | `GATE_PORTAL` → pass/fail | Hệ thống | Pass: khách tự xem số dư/chi tiêu/ticket + ≥1 login/tuần từ ≥2 user; fail: `ESCALATED_24H` — kế hoạch khắc phục owner + deadline |
| `GATE_PORTAL` (pass) | Hoàn thành Day 30 | `HOÀN_TẤT_ONBOARDING` | Hệ thống | Báo cáo review 30 ngày gửi khách + feedback ghi nhận + baseline đã chốt |
| `HOÀN_TẤT_ONBOARDING` | Chuyển ONGOING | `ONGOING` (D+5) | Hệ thống | Đủ điều kiện deploy BR-007: D+0 đã kích hoạt, tài nguyên đủ, 6 Rules đã ký |

**Quy tắc:**
- Đồng hồ onboarding chỉ bắt đầu ở `TIẾP_NHẬN` — mọi mốc Day 1/7/14/30 tính từ thời điểm AM xác nhận, không tính từ WON hay từ ngày ký HĐ.
- `ONGOING` là trạng thái đích của onboarding và chỉ core đặt được: thiếu bất kỳ điều kiện BR-007 (tiền/LOI-HĐ, tài nguyên, 6 Rules) thì D+5 lùi — không có nút "vẫn chạy" trên mobile.
- `TRẢ_VỀ_SALES` không xóa phiên — mỗi vòng trả về tăng bộ đếm hiển thị cho OPS_PLAN và GDKD để rà chất lượng bàn giao lặp lại.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| HandoffPackage | `id`, `deal_id`, `project_id`, `version`, `status`, `sm_signed_at`, `am_confirmed_at`, `sla_deadline_at`, `return_count` | FK → Deal, Project | `project_id` do core sinh khi ký 3 bên hoàn tất; DDL chi tiết tại `database-design.md` |
| HandoffChecklistItem | `package_id`, `group` (1–5), `title`, `responsible_id`, `due_date`, `is_done` | FK → `handoff_package.id` | Nội dung 5 nhóm theo BR-OPS-3.1; tiêu điểm đọc của OPS là nhóm 2/4/5 |
| OnboardingMilestone | `package_id`, `milestone` (DAY1/DAY7/DAY14/DAY30), `criteria_json`, `status` (PASS/FAIL/PENDING/ESCALATED), `evaluated_at`, `plan_ref` | FK → `handoff_package.id` | Tiêu chí pass/fail cụ thể theo BR-OPS-3.2; Day 14 là gate |
| CapacityConfirmation | `project_id`, `confirmed_by`, `confirmed_at` (≤24h sau WON), `check_result`, `escalation_chain_ref` | FK → Project | Chuỗi 4h → TL 8h → HR_L2; xác nhận thực hiện trên web, mobile hiển thị trạng thái |
| CommunicationRulesConsent | `package_id`, `rules_version`, `signed_at`, `customer_signer`, `document_ref`, `draft_flags` (Rules 1/2/3/5) | FK → `handoff_package.id` | Ký tại Kick-off D+3 `[KXN-11]`; `draft_flags` đánh dấu rule còn bản dự thảo |
| DeployTimelineEvent | `project_id`, `event` (COLLECTING/D0/D0_PLANNING/D1/D2/D3_KICKOFF/PRE_D4/D5_ONGOING), `status`, `occurred_at`, `alert_ref` | FK → Project | D+0 set khi đủ tiền + LOI/HĐ `[KXN-5]`; D+5 lùi nếu tài nguyên thiếu `[KXN-10]` |
| MobileApprovalAction | `action_id`, `entity_ref`, `actor_id`, `device_id`, `mfa_token_id`, `requested_at`, `core_response` | FK → entity đích | Mọi xác nhận/từ chối trên mobile ghi 1 dòng; cấm tồn tại khi offline |
| PushNotification | `id`, `recipient_id`, `type` (HANDOFF_PENDING/SLA_WARN/MILESTONE_LATE/CAPACITY_ESCALATE/DEPLOY_ALERT), `payload_ref`, `sent_at`, `read_at` | FK → User | Kênh thông báo một chiều — không phải chứng cứ quyết định |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: AM xác nhận trong SLA 4h trên mobile | Package 100%, SM đã ký, còn 3h SLA | OPS_AM xác nhận với MFA trên mobile | Approval engine ghi bản xác nhận (channel=MOBILE, mfa_verified=true); đồng hồ onboarding bắt đầu; dự án đã sinh ở core | [ ] |
| SC-002: Quá SLA 4h tự trả về | Package chờ tiếp nhận quá 4h không action | Core chạy SLA clock | Trạng thái TRẢ_VỀ_SALES, credit tạm dừng, push 3 bên kèm timestamp; AM không thể xác nhận muộn trên phiên cũ | [ ] |
| SC-003: Từ chối gắn đúng mục checklist | Nhóm 2 thiếu quyền truy cập pixel | OPS_AM từ chối trên mobile | Lý do bắt buộc chọn gắn mục checklist; Sales nhận phản hồi có cấu trúc; không chấp nhận lý do tự do | [ ] |
| SC-004: Trượt mốc Day 7 push đúng người | 1 tiêu chí Day 7 fail (2FA <100%) | Core đánh giá milestone | Push MILESTONE_LATE tới OPS_AM + OPS_PLAN kèm tiêu chí fail và owner khắc phục | [ ] |
| SC-005: Gate Day 14 trượt escalate 24h | Khách chưa login portal đủ tiêu chí | Core đánh giá gate Day 14 | Trạng thái ESCALATED_24H; bắt buộc kế hoạch khắc phục có owner + deadline trước khi milestone mở tiếp | [ ] |
| SC-006: Escalate capacity theo chuỗi SLA | Capacity check gắn Gate 2 quá 4h chưa có người nhận | Core chạy chuỗi escalate | 8h → push OPS_PLAN; quá 8h → HR_L2; không có hành động "xác nhận hộ" trên mobile | [ ] |
| SC-007: D+5 lùi khi thiếu tài nguyên | Checklist tài nguyên trước D+4 còn thiếu quyền ad account | Core đánh giá điều kiện ONGOING | D+5 hiển thị "lùi — thiếu tài nguyên" kèm nguyên nhân; không có nút ép chạy trên mobile | [ ] |
| SC-008: Offline không xác nhận được | Mobile mất mạng, có ghi chú draft | Người dùng bấm xác nhận tiếp nhận | Nút vô hiệu kèm thông báo cần kết nối + MFA; draft lưu cục bộ nhãn "chưa đồng bộ", không tạo bản ghi | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-OPS-004 (Mục 2 — tiếp nhận package ký 3 bên SLA 4h, milestone Day 1/7/14/30 có tiêu chí, WON + capacity trước DEPLOY, capacity check gắn Gate 2 escalate TL/HR_L2).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/mobile-internal/handoff-onboard/handoff-ops.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/handoff-onboard/` (workflow gate, tự sinh dự án, SLA clock, milestone engine) và `phase2-features/bcerp-web/handoff-onboard/` (checklist + e-approval ký 3 bên, dashboard milestone) — REQ-OPS-004 xuất hiện ở 3 systems, bản này là bản SYS-MOBILE-INTERNAL |
| Bản góc Sales cùng touchpoint | `phase2-features/mobile-internal/handoff-onboard/handoff-va-onboarding-bridge.md` (FEAT-MBI-HONB-001 — REQ-SALES-008) |
| Nguồn domain | `documents/quy-trinh-lam-viec/04_Giai_doan_3_Trien_khai_Deploy.md` (Deploy D+0→D+5, COLLECTING, Kick-off, KXN-5, KXN-10), `08_Ma_tran_RACI_Gate_SLA.md` (G3 bàn giao, SLA AM 4h) `[KXN-19 — ma trận RACI chờ khách xác nhận, dùng làm tham chiếu]`, `09_Phu_luc_Hang_so_Quy_trinh.md` §4 (6 Communication Rules, KXN-11) |
