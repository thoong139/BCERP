# Tính Năng: Campaign & Deliverable Management (Client Portal)

> **Dựa trên:** REQ-OPS-006 trong `phase1-business/departments/operations/operations.md` (Phần A, Phần B.7 — BR-OPS-7.1…7.6)
> **Phân hệ:** Client Portal (SYS-PORTAL-WEB)
> **Module:** Campaign & Deliverable (MOD-CAMPAIGN-DELIVERABLE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (§3.3 — Luồng 3 Campaign Delivery), `work/wf-analyze-requirements/deferred-issues.md` (DI-005, DI-006, DI-007)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/portal-web/campaign-deliverable/*.md`, `phase5-implementation/tasks/portal-web/campaign-deliverable/feat-portal-camp-001-impl.md`

> **Fan-out:** REQ-OPS-006 xuất hiện ở 6 systems (CORE, GW, WEB, M-INT, PORTAL, M-PORTAL); file này là bản riêng cho **SYS-PORTAL-WEB** — counterparts: SYS-CORE-BACKEND (FEAT-CORE-CAMP-001), SYS-INTEGRATION-GW (FEAT-GW-CAMP-001), SYS-BCERP-WEB (FEAT-ERP-CAMP-001), SYS-MOBILE-INTERNAL, SYS-MOBILE-PORTAL.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-PORTAL-CAMP-001 |
| Module | MOD-CAMPAIGN-DELIVERABLE |
| Yêu cầu nghiệp vụ | REQ-OPS-006 — Campaign & Deliverable Management (HIGH, GĐ2); fan-out 6 systems, bản này là riêng SYS-PORTAL-WEB |
| Người dùng liên quan | CUSTOMER (CLIENT_ADMIN, CLIENT_USER); các vai nội bộ OPS_PLAN/OPS_AM/OPS_CONT/OPS_DES/OPS_EDIT/OPS_ADS chỉ xuất hiện qua counterparts (WEB nội bộ/M-INT) — không thao tác trực tiếp trên portal |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-CAMP-001 — WBS/change log engine, trạng thái nghiệm thu, share model, engine nhắc/escalate; FEAT-PORTAL-CPORT-002 — tài khoản portal khách đã cấp và kích hoạt; FEAT-PORTAL-RBAC-001 — SSO/MFA, RBAC, tenant isolation nền tảng |
| Ghi chú Expert (A7) | `operations.md` Mục A7: expert review chưa diễn ra (bảng đánh giá đang chờ) — chưa có điều chỉnh A7 nào áp dụng tại thời điểm viết; business rules B.7 do marketing-expert viết call-2; các con số SLA duyệt creative, vòng sửa creative, chờ confirm nghiệm thu đã chốt theo DI-005 (12/09/2026) và ghi đè mức draft `[CẦN CHỐT SỐ]` cũ trong BR-OPS-7.3/7.5 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng là bề mặt Client Portal của REQ-OPS-006: cho khách hàng tự theo dõi tiến độ campaign & deliverable theo WBS/milestone — chỉ ở phần dữ liệu đã được nội bộ chia sẻ có chủ đích — và tự confirm nghiệm thu theo milestone ngay trên portal, thay vì chờ email/điện thoại của AM. Tính năng hiện thực hóa cam kết minh bạch với khách (khách thấy tiến độ nghiệm thu theo milestone, realtime, chỉ tenant của mình) mà vẫn bảo vệ tuyệt đối dữ liệu nội bộ: pipeline duyệt creative, change log, capacity, chi phí và ghi chú nội bộ không bao giờ lộ qua portal.

**Phạm vi:**
- Bao gồm:
  - Trang tiến độ deliverable read-only theo dự án/milestone đã share: danh sách deliverable, trạng thái tổng của từng deliverable trong pipeline nội bộ (đang soạn → đang sản xuất → đã duyệt nội bộ), mốc deadline đã cam kết, mục tiêu campaign theo mục tiêu khách (REQ-OPS-012: conversion/traffic/awareness).
  - Màn hình nghiệm thu milestone: khách CLIENT_ADMIN confirm, hoặc khách để lại yêu cầu chỉnh sửa kèm comment (ý kiến đi qua AM); đồng hồ chờ confirm hiển thị song song giờ làm việc BC (GMT+7) và giờ địa phương khách.
  - Hiển thị trạng thái nhắc/escalate của vòng nghiệm thu: hệ thống nhắc khách ngày 2, escalate OPS_AM ngày 4 — portal phản ánh đúng trạng thái này cho cả khách và AM.
  - Tải bằng chứng deliverable đã share (file/asset) kèm watermark + log truy cập bất biến; link tạo ticket REQ-OPS-009 gắn đúng milestone.
- Không bao gồm:
  - Soạn WBS, editorial calendar, pipeline duyệt creative đa vai, change log bất biến, phân bậc duyệt hạn mức buyer/TL/AM — thuộc SYS-CORE-BACKEND (engine) và SYS-BCERP-WEB (nơi thao tác nội bộ); portal chỉ render kết quả đã share.
  - Bật share/đề xuất nghiệm thu: thao tác của OPS_AM thực hiện trên WEB nội bộ (counterpart FEAT-ERP-CAMP-001); portal không có nút share cho bất kỳ vai nào.
  - Đẩy thay đổi campaign xuống platform, pull chi tiêu — FEAT-GW-CAMP-001; portal chỉ hiển thị số chi tiêu tham chiếu theo milestone với nhãn nguồn + timestamp.
  - Dữ liệu ví/số dư/đối soát — FEAT-PORTAL-CPORT-001 (REQ-FIN-017); dashboard GMV TikTok Shop nội bộ — REQ-OPS-011; engine push notification — counterpart M-INT/M-PORTAL.

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-PORTAL-WEB phục vụ trực tiếp khách hàng; các vai OPS chỉ tương gián tiếp qua counterpart. Nguyên tắc xuyên suốt: mọi gì khách thấy đều phải đi qua share model của CORE — không có bề mặt nào cho dữ liệu chưa share, và mọi thao tác ghi duy nhất của khách trên tính năng này là confirm nghiệm thu, yêu cầu chỉnh sửa, tạo ticket.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (CLIENT_USER) | Xem tiến độ deliverable theo từng milestone đã share, cập nhật realtime | Tự nắm tiến độ dự án mà không phải hỏi AM mỗi lần |
| 2 | CUSTOMER (CLIENT_USER) | Thấy trạng thái tổng của từng deliverable (đang soạn, đang sản xuất, đã duyệt nội bộ, chờ nghiệm thu) | Hiểu deliverable đang ở đâu trong quy trình mà không thấy chi tiết task nội bộ |
| 3 | CUSTOMER (CLIENT_ADMIN) | Nhận đề xuất nghiệm thu milestone trên portal và confirm trực tiếp | Đóng vòng nghiệm thu nhanh, có vết, không phụ thuộc email |
| 4 | CUSTOMER (CLIENT_ADMIN) | Yêu cầu chỉnh sửa kèm comment thay vì confirm khi chưa hài lòng | Ý kiến được ghi nhận có dấu vết và đi đúng kênh qua AM xử lý |
| 5 | CUSTOMER (CLIENT_USER) | Xem mục tiêu của từng campaign đã share (conversion/traffic/awareness) gắn với milestone | Đối chiếu deliverable với mục tiêu kinh doanh hai bên đã thống nhất |
| 6 | CUSTOMER (CLIENT_USER) | Nhận lời nhắc trong portal khi vòng chờ confirm nghiệm thu tới ngày 2 | Không bỏ lỡ hạn nghiệm thu chỉ vì quên |
| 7 | CUSTOMER (CLIENT_ADMIN) | Tải bằng chứng deliverable đã share kèm watermark tên người tải + thời điểm | Lưu hồ sơ phía khách mà tài liệu vẫn truy vết được nguồn phát tán |
| 8 | CUSTOMER (CLIENT_USER) | Mở bản rút gọn Mobile BC Portal xem tiến độ và trạng thái nghiệm thu | Theo dõi dự án khi không ngồi máy tính |
| 9 | OPS_AM (qua WEB nội bộ counterpart) | Bật share/đề xuất nghiệm thu và nhận escalate ngày 4 khi khách chưa phản hồi | Chủ động liên hệ khách đúng thời điểm, không để milestone treo âm thầm |
| 10 | OPS_CONT/OPS_DES/OPS_EDIT (qua WEB nội bộ) | Sản phẩm chỉ xuất hiện trên portal khi đã Approved nội bộ và được AM share | Được làm việc nội bộ mà không bị khách can thiệp trực tiếp vào task |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Các BR-OPS-7.x gốc được enforce chính ở SYS-CORE-BACKEND (service layer); bảng dưới ghi phần portal phải cứng hoá ở bề mặt hiển thị + Portal API Gateway, không chống lệnh thay backend bằng UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-OPS-7.1-portal | **Tiến độ hiển thị theo WBS, chỉ phần đã share:** mọi deliverable/milestone render trên portal phải tham chiếu `wbs_node_ref` hợp lệ và có bản ghi share (`share_flag` bật bởi OPS_AM qua counterpart WEB); deliverable không gắn WBS node không thể share — khớp nguyên tắc "campaign không gắn dự án = không tồn tại" (REQ-OPS-001) | Dữ liệu chưa share hoặc thiếu tham chiếu WBS không render ở bất kỳ bề mặt portal nào; cố truy vấn qua API bị service layer từ chối + ghi log |
| BR-OPS-7.3-portal | **Pipeline creative nội bộ hiển thị ở mức tổng:** khách chỉ thấy trạng thái tổng của deliverable đã share (đang soạn → đang sản xuất → đã duyệt nội bộ → chờ nghiệm thu), không thấy chi tiết task, người thực hiện, comment duyệt nội bộ, số vòng sửa; ý kiến khách luôn đi qua AM, khách không can thiệp trực tiếp task nội bộ | Cố mở chi tiết task nội bộ bị từ chối ở tầng API; UI không render trường nội bộ kể cả khi API trả thừa — thiếu sót tầng API là lỗi bảo mật phải fix ở service layer |
| BR-OPS-7.3-portalb | **SLA creative theo tier là quy trình nội bộ:** AM duyệt creative 2h (video dài 4h, trend gấp 1h), content self-QC + Lead review 4h, tối đa 3 vòng sửa/deliverable — vòng 4 escalate AM chốt phạm vi với khách (chốt theo DI-005); khi HĐ khách cam kết cao hơn ma trận tier×priority của REQ-OPS-008 thì áp theo profile khách. Portal không chạy SLA nội bộ — chỉ nhận và hiển thị mốc deadline/milestone đã cam kết khi share | Portal không bao giờ hiển thị đồng hồ SLA duyệt nội bộ; nếu phát hiện hiển thị sai mốc nội bộ → chặn render, báo CORE đối chiếu share model |
| BR-OPS-7.5-portal | **Nghiệm thu theo milestone với hạn chờ chốt 3 ngày làm việc:** milestone chỉ sẵn sàng nghiệm thu khi 100% WBS node thuộc milestone đã Approved nội bộ; AM đề xuất nghiệm thu → khách confirm trên portal (tenant của mình, realtime). Vòng chờ confirm tối đa **3 ngày làm việc**: ngày 2 hệ thống nhắc khách, ngày 4 escalate OPS_AM (biên bản DI-005 ghi ký hiệu "AD" — registry không có vai AD chuyên trách nên quy về OPS_AM phụ trách khách). **KHÔNG áp "im lặng = đồng ý"** — hết hạn mà khách không phản hồi, milestone giữ nguyên trạng thái chờ, không tự coi là đạt | Hệ thống chỉ nhắc và escalate, không tự chuyển trạng thái — mọi hành vi tự đạt khi hết hạn là vi phạm nghiệp vụ nghiêm trọng; nút confirm chỉ hoạt động khi bản ghi share còn hiệu lực và `tenant_id` khớp phiên đăng nhập |
| BR-OPS-7.5-portalb | **Share model + tenant isolation tuyệt đối:** mọi truy vấn portal mang `tenant_id` và chỉ đọc qua view tổng hợp đã lọc (RLS + filter tầng API theo nền tảng chung FEAT-PORTAL-RBAC-001); khách đa pháp nhân là tenant riêng, không gộp dữ liệu chéo; không có endpoint portal nào cho dữ liệu tenant khác | Thiếu `tenant_id` bị từ chối ở tầng service; cố truy cập chéo tenant → khóa phiên + alert bảo mật; bản ghi share chỉ render cho đúng tenant của nó |
| BR-OPS-7.6-portal | **Dự án nội bộ không tồn tại trên portal:** Dự án Nội bộ (Internal Non-billable) và campaign của chính BC không có đường share ra portal; chỉ Dự án Khách hàng (Client Billable) thuộc tenant được share | Không tạo được bản ghi share cho project type nội bộ — validation theo project type ở CORE chặn trước; portal không render bất kỳ object nào gắn project nội bộ |
| BR-PORT-CAMP-011 | **Read-only trừ 3 hành động ghi:** trên tính năng này khách chỉ được (1) confirm nghiệm thu, (2) yêu cầu chỉnh sửa kèm comment bắt buộc, (3) tạo ticket REQ-OPS-009 gắn milestone; không có endpoint ghi nào khác lên dữ liệu campaign/WBS | Request ghi ngoài 3 hành động bị Portal API Gateway từ chối 403 + log truy cập bất thường |
| BR-PORT-CAMP-012 | **Tách bạch GMV TikTok Shop:** mặc định portal KHÔNG hiển thị GMV/settlement TikTok Shop (REQ-OPS-011 — GMV chỉ tham chiếu, không thuộc nhóm dữ liệu khách thấy mặc định); khi khách có shop và HĐ yêu cầu hiển thị → cấu hình riêng theo hợp đồng `[CẦN CHỐT SỐ: phạm vi chỉ số GMV hiển thị cho khách — SO3-09 nhóm F]`; GMV không trộn vào tiến độ deliverable, không hạch toán vào doanh thu agency | Cấu hình mặc định không share GMV; mọi cố gắng render GMV ngoài cấu hình hợp đồng bị chặn ở tầng API — red line kiểm soát tài chính, vi phạm ghi audit + escalate BOD |
| BR-PORT-CAMP-013 | **Mục tiêu campaign theo mục tiêu khách (REQ-OPS-012):** campaign đã share hiển thị nhãn mục tiêu (conversion/traffic/awareness) và tiến độ theo milestone; portal không hiển thị bất kỳ nội dung nào mang tính cam kết KPI cứng ngoài hợp đồng — chỉ cam kết đầu vào | UI không cho phép phát sinh câu chữ cam kết KPI; nội dung milestone/deliverable lấy nguyên văn từ dữ liệu CORE đã duyệt, không soạn thêm ở portal |
| BR-PORT-CAMP-014 | **Freshness + nhãn nguồn bắt buộc:** số chi tiêu tham chiếu theo milestone hiển thị kèm timestamp cập nhật cuối và nhãn nguồn `api`/`manual` (DI-007 — nền tảng chưa cấp quyền API vẫn chạy kênh manual); disclaimer độ trễ hiển thị cố định | Component không render khi thiếu freshness metadata; số không nhãn nguồn không được hiển thị như số chính thức |
| BR-PORT-CAMP-015 | **Watermark + log truy cập/download bất biến:** mọi file evidence tải về gắn watermark tên user + thời điểm; mọi hành động xem/confirm/ý kiến/tải ghi log append-only phục vụ điều tra rò rỉ; session hết hạn hoặc 2FA chưa bật → mọi hành động xem/xuất bị chặn | Không tạo được watermark → chặn xuất file; log thiếu bản ghi → fail audit toàn vẹn |
| BR-PORT-CAMP-016 | **Đồng hồ chờ confirm hiển thị hai mốc giờ:** ngày làm việc BC (GMT+7, T2–T6 9:00–18:00) và giờ địa phương khách; nếu khách khai báo lịch làm việc riêng theo REQ-OPS-008 thì đếm theo lịch đó; mốc đếm (3 ngày/nhắc ngày 2/escalate ngày 4) cấu hình ở CORE, portal chỉ render | Portal không tự tính lại hạn — hiển thị lệch so với engine CORE bị coi là bug chặn release; hiển thị hai mốc giờ song song bắt buộc cho khách đa quốc gia |

---

## 4. Phân Quyền

> Touchpoint **SYS-PORTAL-WEB** (khách hàng). Các vai OPS thao tác bật share/duyệt/đề xuất nghiệm thu trên WEB nội bộ (counterpart FEAT-ERP-CAMP-001) nên tại portal chỉ có quyền "không" — ghi chú trong ngoặc để tránh hiểu nhầm mất quyền ở touchpoint khác.

| Hành động | CUSTOMER (CLIENT_ADMIN) | CUSTOMER (CLIENT_USER) | OPS_AM | OPS_PLAN | OPS_CONT/DES/EDIT/ADS | SYS_ADMIN | BOD_CFO_CTO |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Xem tiến độ deliverable/milestone đã share của tenant mình | ✅ | ✅ | ❌ (full trên WEB nội bộ) | ❌ (WEB nội bộ) | ❌ (WEB nội bộ) | ❌ (chỉ khi xử lý sự cố, có meta-log) | ❌ (BI) |
| Thấy dữ liệu chưa share / tenant khác | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Confirm nghiệm thu milestone | ✅ (chính thức) | ❌ | ❌ (thao tác trên WEB nội bộ) | ❌ | ❌ | ❌ | ❌ |
| Yêu cầu chỉnh sửa kèm comment | ✅ | ✅ | ❌ (nhận xử lý ở WEB nội bộ) | ❌ | ❌ | ❌ | ❌ |
| Tạo ticket gắn milestone (REQ-OPS-009) | ✅ | ✅ | ❌ (portal) | ❌ | ❌ | ❌ | ❌ |
| Tải evidence có watermark | ✅ | ✅ | ❌ (portal) | ❌ | ❌ | ❌ | ❌ |
| Bật share / đề xuất nghiệm thu / thu hồi share | ❌ | ❌ | ✅ (WEB nội bộ) | ✅ (Planner khi AM vắng — có log) | ❌ | ❌ | ❌ |
| Cấu hình mốc hạn nghiệm thu (3 ngày/nhắc/escalate) | ❌ | ❌ | ❌ (đề xuất) | ❌ | ❌ | ✅ (thực thi) | ✅ (duyệt) |
| Tra cứu log truy cập portal khi điều tra rò rỉ | ❌ | ❌ | ✅ (khách mình) | ❌ | ❌ | ✅ (toàn bộ) | ✅ (tổng hợp) |

Quy tắc bổ sung: phân biệt CLIENT_ADMIN/CLIENT_USER kế thừa từ cấp tài khoản portal (FEAT-PORTAL-CPORT-002) — chỉ CLIENT_ADMIN có giá trị pháp lý của lần confirm nghiệm thu; CLIENT_USER xem và góp ý, ý kiến vẫn được ghi nhận đầy đủ nhưng không đóng vòng nghiệm thu. Ma trận RACI tham chiếu file 08 chưa được xác nhận chính thức `[KXN-19]` — khi chốt sẽ rà lại cột quyền mà không đổi cơ chế enforce.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách không phản hồi quá hạn 3 ngày làm việc:** ngày 2 portal hiển thị lời nhắc trung lập cho khách, ngày 4 escalate OPS_AM; milestone giữ trạng thái chờ — không tự đạt, không tự hủy; AM liên hệ khách qua kênh chính thức và ghi nhận kết quả; trường hợp kéo dài đưa vào weekly review khách. Số chờ draft "5 ngày LV" trong BR-OPS-7.5 đã bị ghi đè bởi DI-005 (3 ngày/nhắc ngày 2/escalate ngày 4).
- **Khách yêu cầu chỉnh sửa sau khi đã confirm:** milestone ở trạng thái CONFIRMED không cho rút confirm trên portal; yêu cầu mới của khách đi qua AM và xử lý như change request/ticket REQ-OPS-009 (yêu cầu ngoài scope tự tách change request) — giữ nguyên vẹn giá trị pháp lý của lần confirm cũ.
- **Khách đa pháp nhân/nhãn hàng:** mỗi pháp nhân một tenant riêng; bản ghi share gắn tenant, không có cơ chế gộp nhìn chéo; user khách chỉ thuộc một tenant tại một thời điểm.
- **Dữ liệu nền tảng đang degraded/manual (DI-007):** số liệu tham chiếu theo milestone hiển thị kèm nhãn `manual` + timestamp; không hiện số cũ như số mới, không che giấu việc nguồn đang tay.
- **Nghiệm thu milestone onboarding:** milestone onboarding bắt buộc gắn Gate Day 14 (BR-OPS-3.2/5.1) — portal hiển thị đúng mốc gắn gate, không cho share milestone onboarding thiếu tham chiếu gate.
- **Khách có TikTok Shop:** tiến độ deliverable dịch vụ hiển thị bình thường; GMV/settlement mặc định không xuất hiện — chỉ bật khi có cấu hình theo hợp đồng; tuyệt đối không hiện GMV như một "deliverable" hay số doanh thu.
- **User bị khóa/thu hồi giữa phiên:** session vô hiệu ngay tại request kế tiếp; lần confirm/ý kiến đã ghi trước đó giữ nguyên tính hợp lệ kèm timestamp.
- **Hành vi bất thường** (quét dữ liệu, tải hàng loạt, thử truy cập chéo tenant): rate limit + alert bảo mật; lặp lại → khóa phiên, escalate SYS_ADMIN. Bộ cờ cảnh báo đi kèm dùng tạm tập cờ hiện có — danh sách đầy đủ cờ K6–K12 chưa chốt `[KXN-20]`, cấu trúc cờ thiết kế mở rộng được.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** MilestoneAcceptanceShare — vòng nghiệm thu một milestone nhìn từ portal (bản ghi share + trạng thái chờ khách phản hồi; trạng thái gốc 100% WBS Approved nằm ở CORE).

**Sơ đồ trạng thái:**
```
[NOT_SHARED] ──(AM share/đề xuất nghiệm thu)──► [SHARED - CHỜ CONFIRM]
                                                    │           │
                              (khách CLIENT_ADMIN   │           │ (khách yêu cầu
                               confirm)             │           │  chỉnh sửa + comment)
                                                    ▼           ▼
                                              [CONFIRMED]  [CHANGES_REQUESTED]
                                                               │
                                                               │ (AM xử lý + share lại)
                                                               ▼
                                                      [SHARED - CHỜ CONFIRM]

  Trong [SHARED]: ngày 2 → nhắc khách (cờ reminder); ngày 4 → escalate OPS_AM (cờ escalation)
  Hết 3 ngày LV không phản hồi → GIỮ NGUYÊN [SHARED] — KHÔNG tự chuyển CONFIRMED
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_SHARED` | Share/đề xuất nghiệm thu | `SHARED` | OPS_AM (Planner khi AM vắng — có log), qua WEB nội bộ | 100% WBS node thuộc milestone đã Approved nội bộ; ghi `shared_by`, `shared_at`, `deadline_at` |
| `SHARED` | Khách confirm | `CONFIRMED` | CUSTOMER (CLIENT_ADMIN của đúng tenant) | Phiên hợp lệ, 2FA bật, `tenant_id` khớp; timestamp ghi vết |
| `SHARED` | Khách yêu cầu chỉnh sửa | `CHANGES_REQUESTED` | CUSTOMER (CLIENT_ADMIN/CLIENT_USER) | Comment bắt buộc; ý kiến chuyển AM xử lý ở counterpart |
| `CHANGES_REQUESTED` | Xử lý xong + share lại | `SHARED` | OPS_AM (qua WEB nội bộ) | Có bản ghi phản hồi xử lý; đồng hồ chờ reset theo cấu hình CORE |
| `SHARED` | Hết hạn không phản hồi | `SHARED` (giữ nguyên) | Hệ thống | Cờ reminder ngày 2, cờ escalation ngày 4 — không đổi trạng thái, không tự đạt |
| `SHARED` | Thu hồi share | `NOT_SHARED` | OPS_AM | Nhập lý do; ghi audit log bất biến |
| `CONFIRMED` | — | Kết thúc | — | Trạng thái kết thúc; thay đổi mới đi qua change request/ticket, không sửa lại |

**Quy tắc:**
- `CONFIRMED` là trạng thái kết thúc của một vòng nghiệm thu — không quay lại; yêu cầu sau confirm là luồng nghiệp vụ mới.
- Hết hạn chờ không bao giờ tự sinh `CONFIRMED` — "im lặng = đồng ý" bị cấm tuyệt đối (DI-005).
- Mọi chuyển trạng thái và cả hai cờ nhắc/escalate ghi audit log bất biến (ai, khi nào, từ/đến trạng thái nào) — phục vụ đối chiếu khi có tranh chấp nghiệm thu.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`; trạng thái gốc của milestone/WBS thuộc CORE, portal chỉ đọc qua view đã lọc.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| MilestoneAcceptanceShare | `milestone_id`, `wbs_node_ref`, `tenant_id`, `share_flag`, `status`, `shared_by`, `shared_at`, `deadline_at`, `reminder_flag`, `escalation_flag` | FK logic → Milestone/WBS (CORE) | Chỉ bản ghi `share_flag` bật mới render trên portal |
| AcceptanceInteraction | `share_id`, `actor_type` (CUSTOMER/OPS_AM/SYSTEM), `actor_id`, `action` (confirm/comment/reminder/escalation/recall), `comment`, `occurred_at` | FK → MilestoneAcceptanceShare | Append-only, không sửa/xóa |
| DeliverableEvidence | `deliverable_id`, `file_ref`, `shared`, `watermark_policy`, `uploaded_by` | FK → deliverable (CORE) | Download luôn qua watermark + log |
| PortalAccessLog | `tenant_id`, `user_id`, `object_type`, `object_id`, `action`, `occurred_at`, `source_ip` | FK logic → user portal | Bất biến; đầu vào điều tra rò rỉ |
| MilestoneView (read model) | `milestone_id`, `tenant_id`, `objective_label` (conversion/traffic/awareness), `deliverable_summary[]`, `spend_ref`, `source_label`, `freshness_at` | Derived từ CORE + GW feed | Chỉ chứa trường đã duyệt share; không chứa trường nội bộ |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chỉ phần đã share hiển thị | Khách đăng nhập portal tenant mình, AM đã share 2/5 milestone | Khách mở trang tiến độ dự án | Chỉ 2 milestone đã share hiển thị; 3 milestone còn lại không tồn tại trên bất kỳ response nào (không chỉ ẩn UI) | [ ] |
| SC-002: Tenant isolation chặn chéo tenant | Hai tenant A, B cùng có dự án active | User tenant A gọi API truy vấn object của tenant B | Từ chối ở tầng service (không phải chỉ ẩn menu), khóa phiên nếu lặp, ghi alert bảo mật | [ ] |
| SC-003: Confirm nghiệm thu trong hạn | Milestone `SHARED`, 100% WBS Approved, CLIENT_ADMIN đăng nhập 2FA | CLIENT_ADMIN bấm confirm | Trạng thái `CONFIRMED`, timestamp ghi vết, AM nhận cập nhật ở counterpart; CLIENT_USER không thấy nút confirm | [ ] |
| SC-004: Không tự đạt khi hết hạn | Milestone `SHARED` quá 3 ngày làm việc, khách không phản hồi | Engine CORE chạy đến ngày 2 rồi ngày 4 | Ngày 2 có nhắc khách, ngày 4 escalate OPS_AM; milestone vẫn `SHARED` — không tự chuyển `CONFIRMED` | [ ] |
| SC-005: Yêu cầu chỉnh sửa đi qua AM | Milestone `SHARED` | CLIENT_USER gửi yêu cầu chỉnh sửa kèm comment | Trạng thái `CHANGES_REQUESTED`, comment ghi vết, AM nhận xử lý ở WEB nội bộ, xử lý xong share lại thành `SHARED` | [ ] |
| SC-006: GMV không hiển thị mặc định | Khách có campaign TikTok Ads + TikTok Shop | Khách mở trang tiến độ milestone | Không có bất kỳ chỉ số GMV/settlement nào hiển thị; chỉ khi có cấu hình theo HĐ mới render (kèm nhãn tham chiếu) | [ ] |
| SC-007: Mục tiêu campaign hiển thị đúng | Campaign đã share có mục tiêu conversion theo REQ-OPS-012 | Khách xem chi tiết milestone | Nhãn mục tiêu hiển thị đúng dữ liệu CORE; không có câu chữ cam kết KPI cứng nào phát sinh từ portal | [ ] |
| SC-008: Tải evidence có watermark + log | Deliverable đã share kèm file evidence | CLIENT_ADMIN tải file | File nhận watermark tên user + thời điểm; PortalAccessLog ghi bản ghi download; session hết hạn → chặn tải | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-OPS-006 (Mục 2 — khách theo dõi tiến độ, nghiệm thu theo milestone trên portal, share model + tenant isolation, tách bạch GMV, mục tiêu theo mục tiêu khách).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/portal-web/campaign-deliverable/` |
| Bản fan-out counterpart | `phase2-features/core-backend/campaign-deliverable/` (FEAT-CORE-CAMP-001 — WBS, change log, share model, engine nhắc/escalate), `phase2-features/bcerp-web/campaign-deliverable/` (FEAT-ERP-CAMP-001 — nơi OPS thao tác), `phase2-features/integration-gw/campaign-deliverable/` (FEAT-GW-CAMP-001), `phase2-features/mobile-internal/campaign-deliverable/`, `phase2-features/mobile-portal/campaign-deliverable/` — REQ-OPS-006 xuất hiện ở 6 systems, bản này là riêng SYS-PORTAL-WEB |
| Tính năng liền kề trong lane portal | `phase2-features/portal-web/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` (FEAT-PORTAL-CPORT-002 — cấp tài khoản), `phase2-features/portal-web/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md` (FEAT-PORTAL-RBAC-001 — SSO/MFA/tenant isolation), `phase2-features/portal-web/ticket-cskh/` (ticket khách gắn milestone) |
| Nguồn nghiệp vụ | REQ-OPS-001 (naming/UTM, campaign gắn dự án), REQ-OPS-008 (ma trận SLA tier, lịch làm việc khách), REQ-OPS-011 (tách bạch TikTok Shop GMV), REQ-OPS-012 (chiến lược theo mục tiêu khách), `work/wf-analyze-requirements/deferred-issues.md` (DI-005 — hạn nghiệm thu/SLA creative/vòng sửa đã chốt; DI-006 — không có vai OPS_CX/AD; DI-007 — nhãn nguồn manual), `documents/quy-trinh-lam-viec/10_Danh_gia_Doi_chieu_Nguon_va_Khoan_Can_Xac_nhan.md` (KXN còn mở) |
