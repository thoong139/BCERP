# Tính Năng: Campaign & Deliverable Management (Mobile BC Portal)

> **Dựa trên:** REQ-OPS-006 trong `phase1-business/departments/operations/operations.md` (Phần A — Mục A3; Phần B.7 — BR-OPS-7.1…7.6)
> **Phân hệ:** Mobile BC Portal (SYS-MOBILE-PORTAL)
> **Module:** Campaign & Deliverable (MOD-CAMPAIGN-DELIVERABLE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (§3.3 — Luồng 3 Campaign Delivery), `work/wf-analyze-requirements/deferred-issues.md` (DI-005, DI-006, DI-007)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-portal/campaign-deliverable/*.md`, `phase5-implementation/tasks/mobile-portal/campaign-deliverable/feat-mpo-camp-001-impl.md`
>
> **Fan-out:** REQ-OPS-006 xuất hiện ở 6 systems (CORE, GW, WEB, M-INT, PORTAL, M-PORTAL) — đây là bản riêng cho SYS-MOBILE-PORTAL; counterparts: SYS-CORE-BACKEND (engine WBS, duyệt creative, change log, trạng thái nghiệm thu, share model), SYS-INTEGRATION-GW (chi tiêu theo campaign), SYS-BCERP-WEB (nơi OPS thao tác), SYS-MOBILE-INTERNAL (duyệt nội bộ trên di động), SYS-PORTAL-WEB (portal đầy đủ trên web). Mobile BC Portal là **touchpoint rút gọn của Portal**: thông báo, phê duyệt nhẹ, xem số dư/tiến độ — read-only phần tài chính; business rule enforce ở service layer CORE, mobile render machine-state và chỉ nhận thao tác ghi là phản hồi nghiệm thu.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MPO-CAMP-001 |
| Module | MOD-CAMPAIGN-DELIVERABLE |
| Yêu cầu nghiệp vụ | REQ-OPS-006 — Campaign & Deliverable Management (HIGH, GĐ2); fan-out 6 systems, bản này là riêng SYS-MOBILE-PORTAL |
| Người dùng liên quan | CUSTOMER (CLIENT_ADMIN, CLIENT_USER — người dùng chính của touchpoint); các vai nội bộ OPS_PLAN/OPS_AM/OPS_CONT/OPS_DES/OPS_EDIT/OPS_ADS chỉ tham gia gián tiếp qua counterparts WEB nội bộ/M-INT — không thao tác nghiệp vụ trên mobile portal |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Không có cross-dependency theo lane; về kỹ thuật mobile phụ thuộc dữ liệu cùng REQ-OPS-006 do counterpart phục vụ: share model + trạng thái nghiệm thu (SYS-CORE-BACKEND), tài khoản portal khách đã cấp và kích hoạt (REQ-OPS-010), nền tảng RBAC/SSO/MFA + tenant isolation xuyên hệ thống |
| Ghi chú Expert (A7) | `operations.md` Mục A7: expert review chưa diễn ra (bảng đánh giá đang chờ) — chưa có điều chỉnh A7 nào áp dụng tại thời điểm viết; business rules B.7 do marketing-expert viết call-2; các con số SLA duyệt creative, vòng sửa creative, hạn chờ confirm nghiệm thu đã chốt theo DI-005 (12/09/2026) và ghi đè mức draft `[CẦN CHỐT SỐ]` cũ trong BR-OPS-7.3/7.5 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng là bề mặt mobile rút gọn của Client Portal cho REQ-OPS-006: khách hàng theo dõi tiến độ campaign & deliverable theo milestone đã share, nhận thông báo đẩy đúng thời điểm (đề xuất nghiệm thu, nhắc ngày 2, escalate ngày 4) và thực hiện **phê duyệt nhẹ** — confirm nghiệm thu milestone hoặc gửi yêu cầu chỉnh sửa — ngay trên điện thoại. Tính năng hiện thực hóa cam kết minh bạch tiến độ trên kênh di động, đồng thời giữ nghiêm ranh giới dữ liệu: chỉ phần đã share trong tenant của mình, phần tài chính chỉ read-only kèm nhãn nguồn.

**Phạm vi:**
- Bao gồm:
  - Trang tiến độ rút gọn theo dự án/milestone đã share: danh sách deliverable, trạng thái tổng trong pipeline nội bộ (đang soạn → đang sản xuất → đã duyệt nội bộ → chờ nghiệm thu), mốc deadline đã cam kết, nhãn mục tiêu campaign theo mục tiêu khách (REQ-OPS-012: conversion/traffic/awareness).
  - Thông báo đẩy (push) + deep-link vào đúng milestone: đề xuất nghiệm thu, nhắc ngày 2, escalate ngày 4, phản hồi đã ghi nhận — nội dung sinh từ machine-state CORE, không tự soạn trạng thái.
  - Phê duyệt nhẹ trên mobile: CLIENT_ADMIN confirm nghiệm thu, hoặc khách gửi yêu cầu chỉnh sửa kèm comment bắt buộc (ý kiến đi qua AM xử lý ở counterpart WEB nội bộ).
  - Đồng hồ chờ confirm hiển thị song song hai mốc giờ (GMT+7 giờ làm việc BC và giờ địa phương khách) — chỉ render giá trị tính sẵn từ engine CORE.
  - Xem bằng chứng deliverable đã share ở mức di động (preview ảnh/tệp) kèm watermark + log truy cập; số chi tiêu tham chiếu theo milestone read-only kèm nhãn nguồn `api`/`manual` + timestamp (DI-007).
  - Tách bạch TikTok Shop khi campaign liên quan: GMV/settlement không phải dữ liệu mặc định trên mobile, chỉ tham chiếu theo cấu hình hợp đồng và tách khỏi doanh thu agency.
- Không bao gồm:
  - Engine WBS, editorial calendar, pipeline duyệt creative đa vai, change log bất biến, phân bậc duyệt hạn mức — thuộc SYS-CORE-BACKEND (thực thi) và SYS-BCERP-WEB (nơi OPS thao tác); mobile chỉ đọc view đã lọc.
  - Bật share, đề xuất/thu hồi nghiệm thu, duyệt vượt hạn mức ngân sách — thao tác OPS_AM/OPS_PLAN trên WEB nội bộ (FEAT-ERP-CAMP-001) hoặc M-INT; mobile portal không có nút share cho bất kỳ vai nào.
  - Bề mặt portal đầy đủ trên desktop (FEAT-PORTAL-CAMP-001, SYS-PORTAL-WEB) — mobile là kênh rút gọn bổ sung; khi luồng vượt quá "phê duyệt nhẹ" (hồ sơ lớn, comment dài) app điều hướng sang portal web.
  - Pull chi tiêu từ platform, degraded mode import manual — thuộc SYS-INTEGRATION-GW; dữ liệu ví/số dư TKQC — REQ-OPS-003 (counterpart riêng); ticket CSKH đầy đủ — REQ-OPS-009 (counterpart riêng); engine push nền tảng — REQ-OPS-008.

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-MOBILE-PORTAL phục vụ trực tiếp khách hàng trên di động; các vai OPS chỉ tương gián tiếp qua counterpart. Nguyên tắc xuyên suốt: mọi thứ khách thấy phải đi qua share model của CORE, mọi hành động ghi duy nhất của khách trên tính năng này là confirm nghiệm thu hoặc yêu cầu chỉnh sửa; phần tài chính chỉ đọc.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (CLIENT_USER) | Nhận thông báo đẩy khi có milestone mới được đề xuất nghiệm thu và bấm deep-link xem ngay | Phản hồi trong hạn mà không phải nhớ lịch email |
| 2 | CUSTOMER (CLIENT_USER) | Xem tiến độ deliverable dạng thẻ rút gọn theo từng milestone đã share, cập nhật realtime | Nắm tiến độ dự án trong 30 giây khi đang di chuyển |
| 3 | CUSTOMER (CLIENT_ADMIN) | Confirm nghiệm thu milestone trực tiếp trên mobile bằng một thao tác có xác nhận (2FA/biometric) | Đóng vòng nghiệm thu nhanh, có vết, không phụ thuộc máy tính |
| 4 | CUSTOMER (CLIENT_ADMIN) | Gửi yêu cầu chỉnh sửa kèm comment ngắn thay vì confirm khi chưa hài lòng | Ý kiến được ghi nhận có dấu vết và đi đúng kênh qua AM |
| 5 | CUSTOMER (CLIENT_USER) | Nhận lời nhắc đẩy vào ngày làm việc thứ 2 của vòng chờ confirm | Không bỏ lỡ hạn nghiệm thu 3 ngày làm việc chỉ vì quên |
| 6 | CUSTOMER (CLIENT_USER) | Thấy nhãn mục tiêu của từng campaign đã share (conversion/traffic/awareness) cạnh milestone | Đối chiếu deliverable với mục tiêu kinh doanh hai bên đã thống nhất |
| 7 | CUSTOMER (CLIENT_USER) | Xem số chi tiêu tham chiếu theo milestone kèm thời điểm cập nhật và nhãn nguồn, chỉ đọc | Theo dõi ngân sách mà vẫn hiểu đây là số tham chiếu có độ trễ |
| 8 | CUSTOMER (CLIENT_ADMIN) | Preview ảnh/tệp deliverable đã share trên mobile kèm watermark | Kiểm nhanh sản phẩm trước khi quyết nghiệm thu |
| 9 | OPS_AM (qua WEB nội bộ counterpart) | Nhận escalate ngày 4 khi khách chưa phản hồi và thấy khách đã đọc/nhận thông báo nào | Chủ động liên hệ khách đúng thời điểm trên đúng kênh |
| 10 | OPS_CONT/OPS_DES/OPS_EDIT (qua WEB nội bộ) | Chỉ thấy sản phẩm xuất hiện trên mobile khi đã Approved nội bộ và được AM share | Làm việc nội bộ không bị khách can thiệp trực tiếp vào task |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Các BR-OPS-7.x gốc được enforce chính ở SYS-CORE-BACKEND (service layer); bảng dưới ghi phần mobile portal phải cứng hoá ở app + Portal API Gateway, không chống lệnh backend bằng UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-MPO-CAMP-001 | **Tiến độ hiển thị theo WBS, chỉ phần đã share, tenant isolation:** mọi deliverable/milestone render trên mobile phải tham chiếu `wbs_node_ref` hợp lệ (deliverable không gắn WBS node không thể share — khớp "campaign không gắn dự án = không tồn tại", REQ-OPS-001) và có bản ghi share do OPS_AM bật; mọi request mang `tenant_id`, chỉ đọc trong tenant của mình | Dữ liệu chưa share không render ở bất kỳ màn hình nào, kể cả cache; truy vấn chéo tenant bị service layer từ chối + alert bảo mật — lỗi isolation là lỗi P0 |
| BR-MPO-CAMP-002 | **Pipeline nội bộ hiển thị ở mức tổng:** khách chỉ thấy trạng thái tổng của deliverable đã share (đang soạn → đang sản xuất → đã duyệt nội bộ → chờ nghiệm thu); không thấy task chi tiết, người thực hiện, comment duyệt, số vòng sửa; ý kiến khách luôn đi qua AM | Cố mở chi tiết nội bộ bị từ chối ở tầng API; app không render trường nội bộ kể cả khi response trả thừa — thiếu sót tầng API là lỗi bảo mật phải fix ở service layer |
| BR-MPO-CAMP-003 | **Nghiệm thu theo milestone với hạn chờ 3 ngày làm việc (DI-005):** milestone chỉ sẵn sàng nghiệm thu khi 100% WBS node thuộc milestone đã Approved nội bộ; AM đề xuất → khách confirm trên portal/mobile (tenant của mình, realtime); **nhắc khách ngày 2, escalate AD ngày 4, KHÔNG áp "im lặng = đồng ý"** — hết hạn milestone giữ trạng thái chờ/escalate, không tự coi là đạt; "AD" (Account Director) không có trong 18 vai registry nên hệ thống route escalate tới quản lý tuyến OPS_AM/OPS_PLAN theo ma trận RACI `[KXN-19]` | App chỉ nhắc và hiển thị escalate, không tự chuyển trạng thái; tự đạt khi hết hạn là vi phạm nghiệp vụ nghiêm trọng; nút confirm chỉ hoạt động khi bản ghi share còn hiệu lực và `tenant_id` khớp phiên |
| BR-MPO-CAMP-004 | **"Phê duyệt nhẹ" chỉ có 2 hành động ghi:** (1) confirm nghiệm thu — chỉ CLIENT_ADMIN, thao tác qua 2FA/biometric theo nền tảng portal; (2) yêu cầu chỉnh sửa kèm comment bắt buộc — CLIENT_ADMIN/CLIENT_USER; mọi endpoint ghi khác lên dữ liệu campaign/WBS không tồn tại trên mobile | Request ghi ngoài 2 hành động bị Portal API Gateway từ chối 403 + log truy cập bất thường; confirm từ CLIENT_USER không có giá trị đóng vòng nghiệm thu |
| BR-MPO-CAMP-005 | **Creative SLA theo tier là quy trình nội bộ, không lộ lên mobile:** SLA duyệt creative đã chốt (AM 2h, video dài 4h, trend gấp 1h; content self-QC + Lead review 4h; tối đa 3 vòng sửa/deliverable — vòng 4 escalate AM chốt phạm vi với khách qua AM; áp theo ma trận tier × priority của REQ-OPS-008, HĐ cam kết cao hơn thì ghi đè theo profile khách); mobile không hiển thị đồng hồ SLA duyệt nội bộ, chỉ hiển thị deadline/milestone đã cam kết khi share | Mobile phát hiện hiển thị mốc SLA nội bộ → chặn render, báo đối chiếu share model; khách không thể suy luận được áp lực duyệt nội bộ từ dữ liệu mobile |
| BR-MPO-CAMP-006 | **Thông báo đẩy khớp machine-state và phạm vi share:** push chỉ bắn cho sự kiện có bản ghi ở CORE (đề xuất nghiệm thu, nhắc ngày 2, escalate, phản hồi ghi nhận) và chỉ cho dữ liệu đã share trong tenant; deep-link phải trỏ đúng object; khi app mở lại, trạng thái hiển thị luôn resync với CORE — thông báo cũ không dùng làm nguồn sự thật | Không tạo được push từ dữ liệu chưa share; deep-link vào object đã thu hồi share → màn hình từ chối truy cập hợp lệ kèm giải thích; trạng thái app lệch CORE là bug chặn release |
| BR-MPO-CAMP-007 | **Phiên di động và chế độ offline read-only:** xác thực kế thừa nền tảng portal (SSO/MFA, phiên có hạn); mất mạng → chỉ đọc dữ liệu cache gắn nhãn rõ "cần làm mới" kèm timestamp cũ, **cấm confirm/yêu cầu chỉnh sửa từ cache** — mọi thao tác ghi chỉ thực thi khi online và có phản hồi từ CORE | Nút ghi vô hiệu ở chế độ offline; cố ghi khi offline được xếp hàng cục bộ và tự hủy khi phát hiện, kèm thông báo yêu cầu thao tác lại khi có mạng |
| BR-MPO-CAMP-008 | **Tài chính read-only tuyệt đối trên mobile:** số chi tiêu tham chiếu theo milestone chỉ hiển thị kèm nhãn nguồn `api`/`manual` (DI-007 — nền tảng chưa cấp quyền API vẫn chạy kênh manual) + timestamp cập nhật cuối + disclaimer độ trễ; không có bất kỳ thao tác ghi tài chính nào (không lệnh nạp, không điều chỉnh, không duyệt chi) | Component không render khi thiếu freshness metadata; số không nhãn nguồn không được hiển thị như số chính thức; endpoint ghi tài chính không tồn tại trên bề mặt này |
| BR-MPO-CAMP-009 | **Tách bạch GMV TikTok Shop khi liên quan:** khi campaign thuộc dịch vụ TikTok Shop, GMV/settlement là chỉ số tham chiếu thuộc về khách, không trộn vào tiến độ deliverable và không hạch toán vào doanh thu agency (doanh thu BC chỉ từ phí dịch vụ + phí ads thu hộ); mặc định mobile KHÔNG hiển thị GMV — chỉ bật khi có cấu hình theo hợp đồng, phạm vi hiển thị GMV cho khách là hạng mục chưa chốt (SO3-09 nhóm F, theo dõi tại `deferred-issues.md`) | Cấu hình mặc định không share GMV; mọi cố gắng render GMV ngoài cấu hình hợp đồng bị chặn ở tầng API — vi phạm red line kiểm soát tài chính, ghi audit + escalate BOD |
| BR-MPO-CAMP-010 | **Mục tiêu campaign theo mục tiêu khách (REQ-OPS-012):** campaign đã share hiển thị nhãn mục tiêu (conversion/traffic/awareness) và tiến độ theo milestone lấy nguyên văn từ dữ liệu CORE đã duyệt; mobile không phát sinh câu chữ cam kết KPI cứng ngoài hợp đồng — chỉ cam kết đầu vào | UI không cho phép soạn thêm nội dung cam kết; phát hiện chuỗi cam kết KPI sinh từ app là lỗi nội dung chặn release |
| BR-MPO-CAMP-011 | **Dự án nội bộ không tồn tại trên mobile portal:** Dự án Nội bộ (Internal Non-billable) và campaign của chính BC không có đường share ra portal/mobile; chỉ Dự án Khách hàng (Client Billable) thuộc tenant được share | Không tạo được bản ghi share cho project type nội bộ — validation theo project type ở CORE chặn trước; app không render object nào gắn project nội bộ |

---

## 4. Phân Quyền

> Touchpoint **SYS-MOBILE-PORTAL** (khách hàng, kênh rút gọn). Các vai OPS thao tác bật share/duyệt/đề xuất nghiệm thu trên WEB nội bộ và M-INT (counterparts cùng REQ-OPS-006) nên tại mobile portal chỉ có quyền "không" — ghi chú trong ngoặc để tránh hiểu nhầm mất quyền ở touchpoint khác. Chỉ dùng 18 vai registry + CUSTOMER.

| Hành động | CUSTOMER (CLIENT_ADMIN) | CUSTOMER (CLIENT_USER) | OPS_AM | OPS_PLAN | OPS_CONT/DES/EDIT/ADS | SYS_ADMIN |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|
| Xem tiến độ deliverable/milestone đã share của tenant mình (mobile) | ✅ | ✅ | ❌ (full trên WEB nội bộ) | ❌ (WEB nội bộ) | ❌ (WEB nội bộ) | ❌ (chỉ khi xử lý sự cố, có meta-log) |
| Thấy dữ liệu chưa share / tenant khác | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Confirm nghiệm thu milestone (phê duyệt nhẹ) | ✅ (2FA/biometric) | ❌ | ❌ (thao tác trên WEB/M-INT) | ❌ | ❌ | ❌ |
| Gửi yêu cầu chỉnh sửa kèm comment | ✅ | ✅ | ❌ (nhận xử lý ở WEB nội bộ) | ❌ | ❌ | ❌ |
| Nhận push/deep-link sự kiện nghiệm thu | ✅ | ✅ | ❌ (escalate nhận ở M-INT/WEB) | ❌ | ❌ | ❌ |
| Xem chi tiêu tham chiếu read-only | ✅ | ✅ | ❌ (mobile) | ❌ (mobile) | ❌ (mobile) | ❌ |
| Bật share / đề xuất nghiệm thu / thu hồi share | ❌ | ❌ | ✅ (WEB nội bộ) | ✅ (Planner khi AM vắng — có log) | ❌ | ❌ |
| Cấu hình mốc hạn nghiệm thu (3 ngày/nhắc ngày 2/escalate ngày 4) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (thực thi cấu hình, có duyệt) |
| Tra cứu MobileAccessLog khi điều tra rò rỉ | ❌ | ❌ | ✅ (khách mình) | ❌ | ❌ | ✅ (toàn bộ) |
| Sửa/xóa log truy cập, entry nghiệm thu đã ghi | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (append-only, chỉ đọc kỹ thuật) |

Quy tắc bổ sung: phân biệt CLIENT_ADMIN/CLIENT_USER kế thừa từ cấp tài khoản portal (REQ-OPS-010) — chỉ CLIENT_ADMIN có giá trị pháp lý của lần confirm nghiệm thu; CLIENT_USER xem, nhận thông báo và góp ý nhưng không đóng vòng nghiệm thu. Ma trận RACI (file 08) chưa được xác nhận chính thức `[KXN-19]` — khi chốt sẽ rà lại cột quyền và tuyến escalate mà không đổi cơ chế enforce ở service layer.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách không phản hồi quá hạn 3 ngày làm việc:** ngày 2 mobile đẩy lời nhắc trung lập, ngày 4 escalate tới quản lý tuyến (route OPS_AM/OPS_PLAN theo `[KXN-19]`); milestone giữ trạng thái chờ — không tự đạt, không tự hủy ("im lặng = đồng ý" bị cấm theo DI-005); AM liên hệ khách qua kênh chính thức và ghi nhận kết quả ở counterpart; mobile chỉ phản ánh trạng thái escalate.
- **Mất mạng/kết nối yếu lúc xem milestone:** app hiển thị dữ liệu cache gắn nhãn "cần làm mới — dữ liệu lúc [timestamp]"; mọi nút ghi (confirm/yêu cầu chỉnh sửa) vô hiệu tới khi resync thành công với CORE; không có cơ chế ghi xếp hàng offline — tránh hai nguồn sự thật cho một lần nghiệm thu.
- **Thông báo đẩy không đến được (tắt push, đổi thiết bị, hệ điều hành chặn):** mobile là kênh bổ sung, không phải điều kiện hiệu lực của vòng nghiệm thu — hạn 3 ngày vẫn chạy theo engine CORE; khi khách mở app, màn hình chính hiển thị hàng đợi milestone chờ phản hồi để bù push lỡ; AM vẫn nhận escalate đúng hạn ở counterpart.
- **Khách đa pháp nhân/nhãn hàng:** mỗi pháp nhân một tenant riêng; user khách chỉ thuộc một tenant tại một thời điểm; chuyển tenant là đăng nhập lại — app không gộp dữ liệu chéo tenant, kể cả trong thông báo đẩy.
- **User bị khóa/thu hồi share giữa phiên:** session vô hiệu ngay tại request kế tiếp; deep-link từ thông báo cũ vào object đã thu hồi share hiển thị màn "dữ liệu không còn chia sẻ" kèm hướng dẫn liên hệ AM; các lần confirm/comment đã ghi trước đó giữ nguyên tính hợp lệ kèm timestamp.
- **Khách có TikTok Shop trong campaign:** tiến độ deliverable dịch vụ hiển thị bình thường; GMV/settlement mặc định không xuất hiện trên mobile — chỉ bật theo cấu hình hợp đồng khi hạng mục phạm vi hiển thị GMV đã chốt (SO3-09 nhóm F); tuyệt đối không hiện GMV như một "deliverable" hay số doanh thu.
- **Hành vi bất thường trên thiết bị (tải hàng loạt evidence, thử deep-link chéo tenant, root/jailbreak):** rate limit + alert bảo mật; lặp lại → khóa phiên, escalate SYS_ADMIN; bộ cờ cảnh báo đi kèm dùng tạm tập cờ hiện có — danh sách đầy đủ cờ K6–K12 chưa chốt `[KXN-20]`, cấu trúc thiết kế mở rộng được.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** MilestoneAcceptanceShare — vòng nghiệm thu một milestone nhìn từ mobile (bản ghi share + trạng thái chờ khách phản hồi; trạng thái gốc 100% WBS Approved và các cờ nhắc/escalate tính ở CORE; mobile render và ghi đúng hai hành động được phép).

**Sơ đồ trạng thái:**
```
[NOT_SHARED] ──(OPS_AM share/đề xuất nghiệm thu — WEB nội bộ)──► [SHARED - CHỜ CONFIRM]
                                                                     │           │
                                           (khách CLIENT_ADMIN       │           │ (khách gửi yêu cầu
                                            confirm trên mobile/web) │           │  chỉnh sửa + comment)
                                                                     ▼           ▼
                                                               [CONFIRMED]  [CHANGES_REQUESTED]
                                                                                    │
                                                                                    │ (AM xử lý + share lại — WEB nội bộ)
                                                                                    ▼
                                                                           [SHARED - CHỜ CONFIRM]

  Trong [SHARED]: ngày 2 → push nhắc khách; ngày 4 → escalate (route OPS_AM/OPS_PLAN, [KXN-19])
  Hết 3 ngày LV không phản hồi → GIỮ NGUYÊN [SHARED] — KHÔNG tự chuyển CONFIRMED
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_SHARED` | Share/đề xuất nghiệm thu | `SHARED` | OPS_AM (Planner khi AM vắng — có log), qua WEB nội bộ | 100% WBS node thuộc milestone đã Approved nội bộ; ghi `shared_by`, `shared_at`, `deadline_at`; push sinh sau bản ghi share |
| `SHARED` | Khách confirm (phê duyệt nhẹ) | `CONFIRMED` | CUSTOMER (CLIENT_ADMIN của đúng tenant) | Online, phiên hợp lệ, 2FA/biometric; `tenant_id` khớp; timestamp ghi vết |
| `SHARED` | Khách gửi yêu cầu chỉnh sửa | `CHANGES_REQUESTED` | CUSTOMER (CLIENT_ADMIN/CLIENT_USER) | Comment bắt buộc; ý kiến chuyển AM xử lý ở counterpart |
| `CHANGES_REQUESTED` | Xử lý xong + share lại | `SHARED` | OPS_AM (qua WEB nội bộ) | Có bản ghi phản hồi xử lý; đồng hồ chờ reset theo cấu hình CORE |
| `SHARED` | Hết hạn không phản hồi | `SHARED` (giữ nguyên) | Hệ thống | Cờ reminder ngày 2, cờ escalation ngày 4 — không đổi trạng thái, không tự đạt |
| `SHARED` | Thu hồi share | `NOT_SHARED` | OPS_AM | Nhập lý do; ghi audit log bất biến; deep-link cũ vô hiệu |
| `CONFIRMED` | — | Kết thúc | — | Trạng thái kết thúc; thay đổi mới đi qua yêu cầu chỉnh sửa mới/ticket, không sửa lại |

**Quy tắc:**
- `CONFIRMED` là trạng thái kết thúc của một vòng nghiệm thu — không quay lại; yêu cầu sau confirm là luồng nghiệp vụ mới và giá trị pháp lý của lần confirm cũ được bảo toàn.
- Hết hạn chờ không bao giờ tự sinh `CONFIRMED` — "im lặng = đồng ý" bị cấm tuyệt đối (DI-005); chỉ có hai nguồn đóng vòng: confirm của khách hoặc kết quả liên hệ có bằng chứng do AM nhập ở counterpart.
- Mọi chuyển trạng thái và cả hai cờ nhắc/escalate ghi audit log bất biến (ai, khi nào, từ/đến trạng thái nào, kênh nào ghi — mobile/web) phục vụ đối chiếu khi có tranh chấp nghiệm thu.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`; trạng thái gốc của milestone/WBS/change log thuộc CORE, mobile chỉ đọc qua view đã lọc theo share model.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| MilestoneAcceptanceShare (view) | `milestone_id`, `wbs_node_ref`, `tenant_id`, `share_flag`, `status`, `shared_by`, `shared_at`, `deadline_at`, `reminder_flag`, `escalation_flag` | FK logic → Milestone/WBS (CORE) | Chỉ bản ghi `share_flag` bật mới render trên mobile |
| DeliverableProgressView (read model) | `deliverable_id`, `wbs_node_ref`, `summary_status`, `objective_label` (conversion/traffic/awareness), `committed_deadline` | Derived từ CORE | Chỉ chứa trạng thái tổng đã duyệt share; không chứa trường nội bộ |
| AcceptanceInteraction | `share_id`, `actor_type` (CUSTOMER/OPS_AM/SYSTEM), `actor_id`, `channel` (mobile/web/system), `action` (confirm/changes_requested/reminder/escalation/recall), `comment`, `occurred_at` | FK → MilestoneAcceptanceShare | Append-only, không sửa/xóa; `channel=mobile` đánh dấu phê duyệt nhẹ |
| PushEnvelope | `share_id`, `event_type` (proposed/reminder/escalation/ack), `deep_link`, `delivery_status`, `sent_at` | FK → MilestoneAcceptanceShare | Sinh từ machine-state CORE; không bắn cho dữ liệu chưa share |
| SpendReference (read-only) | `milestone_id`, `spend_value`, `currency`, `source_label` (`api`/`manual`), `freshness_at` | Derived từ GW feed qua CORE | Read-only tuyệt đối trên mobile; thiếu freshness metadata thì không render |
| MobileAccessLog | `tenant_id`, `user_id`, `device_id`, `object_type`, `object_id`, `action`, `occurred_at`, `source_ip` | FK logic → user portal | Bất biến; đầu vào điều tra rò rỉ; không vai nào sửa/xóa |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chỉ phần đã share hiển thị trên mobile | Khách đăng nhập app tenant mình, AM đã share 2/5 milestone | Khách mở trang tiến độ dự án | Chỉ 2 milestone đã share hiển thị; 3 milestone còn lại không tồn tại trên bất kỳ response hay cache nào | [ ] |
| SC-002: Tenant isolation chặn chéo tenant | Hai tenant A, B cùng có dự án active | User tenant A mở deep-link trỏ object của tenant B | Từ chối ở tầng service (không chỉ ẩn UI), hiển thị màn từ chối hợp lệ; lặp lại → khóa phiên + alert bảo mật | [ ] |
| SC-003: Confirm nghiệm thu trên mobile trong hạn | Milestone `SHARED`, 100% WBS Approved, CLIENT_ADMIN đăng nhập 2FA/biometric | CLIENT_ADMIN bấm confirm trên app | Trạng thái `CONFIRMED`, `channel=mobile` ghi vết, AM thấy cập nhật ở counterpart; CLIENT_USER không thấy nút confirm | [ ] |
| SC-004: Không tự đạt khi hết hạn | Milestone `SHARED` quá 3 ngày làm việc, khách không phản hồi | Engine CORE chạy đến ngày 2 rồi ngày 4 | Ngày 2 push nhắc khách, ngày 4 escalate (route OPS_AM/OPS_PLAN); milestone vẫn `SHARED` — không tự `CONFIRMED` | [ ] |
| SC-005: Offline không ghi được | App mất kết nối, dữ liệu cache hiển thị | CLIENT_ADMIN cố bấm confirm từ màn cache | Nút ghi vô hiệu; chỉ đọc được cache có nhãn "cần làm mới" kèm timestamp; có mạng lại phải thao tác lại | [ ] |
| SC-006: Push + deep-link khớp machine-state | AM đề xuất nghiệm thu milestone đã share | Hệ thống sinh sự kiện proposed | Push tới đúng user tenant với deep-link mở đúng milestone; object đã thu hồi share → deep-link hiển thị màn "dữ liệu không còn chia sẻ" | [ ] |
| SC-007: GMV không hiển thị mặc định | Khách có campaign TikTok Ads + TikTok Shop | Khách mở trang tiến độ milestone trên mobile | Không có chỉ số GMV/settlement nào hiển thị; chỉ render khi có cấu hình theo HĐ và hạng mục SO3-09 nhóm F đã chốt (kèm nhãn tham chiếu) | [ ] |
| SC-008: Chi tiêu tham chiếu read-only có nhãn nguồn | Nền tảng chưa cấp quyền API (degraded — DI-007) | Khách xem khối chi tiêu tham chiếu theo milestone | Số hiển thị kèm nhãn `manual` + timestamp + disclaimer độ trễ; không có bất kỳ thao tác ghi tài chính nào trên mobile | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-OPS-006 (Mục 2 — khách theo dõi tiến độ deliverable chỉ phần đã share, nghiệm thu theo milestone trên portal/mobile, tenant isolation, tách bạch GMV TikTok Shop, mục tiêu campaign theo mục tiêu khách REQ-OPS-012).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (share model CORE, push/deep-link, chi tiêu tham chiếu từ GW, resync trạng thái) |
| Màn hình UI | `phase4-ux/mobile-portal/campaign-deliverable/` |
| Bản fan-out counterpart | `phase2-features/core-backend/campaign-deliverable/` (FEAT-CORE-CAMP-001 — WBS, change log, share model, engine nhắc/escalate), `phase2-features/bcerp-web/campaign-deliverable/` (FEAT-ERP-CAMP-001 — nơi OPS thao tác), `phase2-features/integration-gw/campaign-deliverable/` (FEAT-GW-CAMP-001), `phase2-features/mobile-internal/campaign-deliverable/` (duyệt nội bộ di động), `phase2-features/portal-web/campaign-deliverable/campaign-va-deliverable-management.md` (FEAT-PORTAL-CAMP-001 — bề mặt portal đầy đủ) — REQ-OPS-006 xuất hiện ở 6 systems, bản này là riêng SYS-MOBILE-PORTAL |
| Tính năng liền kề trong lane mobile-portal | `phase2-features/mobile-portal/wallet-recon/` (REQ-OPS-003 — số dư ví read-only), `phase2-features/mobile-portal/sla-notif/` (REQ-OPS-008 — đồng hồ SLA phía khách), `phase2-features/mobile-portal/ticket-cskh/` (REQ-OPS-009 — ticket khách), `phase2-features/mobile-portal/client-portal/` (REQ-OPS-010 — cấp tài khoản portal) |
| Nguồn nghiệp vụ | REQ-OPS-001 (naming/UTM, campaign gắn dự án), REQ-OPS-008 (ma trận SLA tier, lịch làm việc khách), REQ-OPS-010 (cấp tài khoản portal), REQ-OPS-011 (tách bạch TikTok Shop GMV), REQ-OPS-012 (chiến lược theo mục tiêu khách), `work/wf-analyze-requirements/deferred-issues.md` (DI-005 — hạn nghiệm thu 3 ngày/nhắc ngày 2/escalate ngày 4, SLA creative, vòng sửa đã chốt; DI-006 — không có vai OPS_CX/AD trong registry; DI-007 — nhãn nguồn manual), `documents/quy-trinh-lam-viec/10_Danh_gia_Doi_chieu_Nguon_va_Khoan_Can_Xac_nhan.md` (KXN còn mở — `[KXN-19]` ma trận RACI, `[KXN-20]` cờ cảnh báo K6–K12) |
