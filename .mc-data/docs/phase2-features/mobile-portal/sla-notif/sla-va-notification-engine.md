# Tính Năng: SLA & Notification Engine — Bản Mobile BC Portal (SYS-MOBILE-PORTAL)

> **Dựa trên:** REQ-OPS-008 trong `phase1-business/departments/operations/operations.md` (Phần A — Mục REQ-OPS-008; Phần B — Mục B.9, BR-OPS-9.1 đến BR-OPS-9.3)
> **Phân hệ:** Mobile App — BC Portal (SYS-MOBILE-PORTAL)
> **Module:** SLA & Notification (MOD-SLA-NOTIF)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 5: CSKH & SLA), `work/wf-analyze-requirements/deferred-issues.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-portal/sla-notif/[screen-group].md`, `phase5-implementation/tasks/mobile-portal/sla-notif/[feat]-impl.md`

> **Fan-out note:** REQ-OPS-008 xuất hiện ở 5 systems; file này là **bản riêng cho SYS-MOBILE-PORTAL** — Mobile BC Portal cho khách hàng là **touchpoint rút gọn của Portal** (thông báo, phê duyệt nhẹ, xem tiến độ; **read-only tuyệt đối phần tài chính**), **tenant isolation tuyệt đối — chỉ event của tenant mình**. Counterparts: SLA engine & dispatcher — SYS-CORE-BACKEND (`FEAT-CORE-SLANOT-001`); dashboard compliance — SYS-BCERP-WEB (`FEAT-ERP-SLANOT-001`); push on-call nội bộ — SYS-MOBILE-INTERNAL (`FEAT-MBI-SLANOT-001`); bản đầy đủ web cho khách — SYS-PORTAL-WEB (`FEAT-PORTAL-SLANOT-001`).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| ID tính năng | FEAT-MPO-SLANOT-001 |
| Module | MOD-SLA-NOTIF |
| Yêu cầu nghiệp vụ | REQ-OPS-008 (liên thông: REQ-BOD-006 — alert center BOD, luồng đẩy breach; REQ-OPS-009 — ticket & CSKH, nguồn event; REQ-OPS-010 — cấp tài khoản portal) |
| Người dùng liên quan | CUSTOMER (CLIENT_ADMIN, CLIENT_USER — người dùng tenant trên mobile portal); OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (vai nội bộ — nguồn phát event, thao tác trên counterpart WEB/M-INT, không đăng nhập mobile portal) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (theo REQ-OPS-008); phát hành theo gói hệ thống SYS-MOBILE-PORTAL |
| Phụ thuộc | SLA engine + notification dispatcher tại SYS-CORE-BACKEND — `FEAT-CORE-SLANOT-001` (chạy trước, mobile chỉ hiển thị/relay); notification feed, cấu hình kênh và lịch làm việc dùng chung SYS-PORTAL-WEB — `FEAT-PORTAL-SLANOT-001`; cấp tài khoản portal REQ-OPS-010; queue & state machine ticket REQ-OPS-009 |
| Ghi chú Expert (A7) | Operations.md Mục A7 chờ đánh giá chính thức; đối chiếu chéo REQ-OPS-008 đã thực hiện qua P1-02 Luồng 5 và B.9 — khớp REQ-BOD-006 (push khẩn ≤5 phút), REQ-OPS-009 (nguồn event), REQ-HR-007 (dữ liệu SLA cho KPI — ngoài scope touchpoint khách) |

> *CLIENT_ADMIN/CLIENT_USER là kiểu tài khoản phía tenant, gộp dưới vai registry CUSTOMER; vai nội bộ chỉ dùng 18 vai registry — không có OPS_CX/FIN_COMPL (DI-006 đã chốt gỡ); "CS TL" trong quy trình gốc map về OPS_AM (đầu mối SLA), điều phối là OPS_PLAN.*

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa phần SLA & Notification Engine của REQ-OPS-008 lên điện thoại khách hàng ở dạng rút gọn: khách **nhận push kịp thời** về tiến độ xử lý sự kiện/ticket của tenant mình (lời nhắc Pending, pre-alert 80%, breach, ETA mới) và **xem đồng hồ SLA rút gọn** song song mốc GMT+7 của BC với giờ địa phương khách — biến cam kết SLA trong hợp đồng thành dữ liệu minh bạch khách tự theo dõi. Touchpoint này là kênh "phê duyệt nhẹ": khách phản hồi nhanh lời nhắc ngay từ thông báo, còn mọi tính toán SLA và thao tác tài chính nằm ở hệ thống nội bộ — app chỉ quan sát và relay.

**Phạm vi:**
- Bao gồm:
  - Push notification + notification center in-app cho event SLA của tenant mình: lời nhắc Pending, pre-alert 80%, breach 100% kèm thông báo chính thức của AM (template chuẩn), ETA mới sau override, auto-Closed "khách không phản hồi".
  - Đồng hồ SLA rút gọn read-only trên màn chi tiết ticket: target First Response/Resolution theo ma trận tier×priority (hoặc cam kết hợp đồng nếu ghi đè), % thời lượng đã dùng, trạng thái chạy/tạm dừng — chiếu từ `sla_clock_view` đồng bộ event bus CORE, song song GMT+7 và giờ tenant.
  - Phản hồi nhanh (phê duyệt nhẹ): trả lời lời nhắc Pending, xác nhận tiếp nhận breach, yêu cầu reopen trong 7 ngày — đi vào queue hợp nhất REQ-OPS-009 như kênh portal chính thức.
  - Cấu hình nhận thông báo cá nhân, per-thiết bị: bật/tắt push, chọn loại event, giờ im lặng — trong phạm vi kênh tenant đã bật ở portal web.
  - Deep-link sang BC Portal Web cho cấu hình mức tenant: lịch làm việc, kênh email/Zalo/Telegram — giữ touchpoint rút gọn.
- Không bao gồm:
  - Tính SLA clock, pause/resume, escalation, override/gia hạn — thuộc SYS-CORE-BACKEND (`FEAT-CORE-SLANOT-001`); dashboard compliance — SYS-BCERP-WEB (`FEAT-ERP-SLANOT-001`).
  - Push pre-alert/breach cho assignee/AM, duyệt gia hạn, ca trực on-call nội bộ — thuộc SYS-MOBILE-INTERNAL (`FEAT-MBI-SLANOT-001`); mobile khách không thấy trạng thái escalation hay dữ liệu nội bộ BC.
  - Alert center BOD tổng hợp — thuộc REQ-BOD-006 (MOD-DATAHUB-BI); mobile portal chỉ là người nhận cuối của thông báo chính thức.
  - Queue hợp nhất, state machine ticket, CSAT logic — thuộc REQ-OPS-009 (mobile chỉ nhận event); mọi thao tác tài chính — mobile portal read-only tuyệt đối phần tài chính.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (CLIENT_USER) | Nhận push khi ticket của tenant tôi chạm mốc SLA quan trọng (80%, breach, ETA mới) | Biết ngay tiến độ xử lý, không phải gọi hỏi AM |
| 2 | CUSTOMER (CLIENT_USER) | Xem đồng hồ SLA rút gọn từng ticket, song song GMT+7 và giờ địa phương tôi | Tự đánh giá tiến độ so với cam kết hợp đồng |
| 3 | CUSTOMER (CLIENT_USER) | Trả lời nhanh lời nhắc "ticket đang chờ bạn" ngay từ thông báo | Ticket không bị auto-Closed chỉ vì tôi đang di chuyển |
| 4 | CUSTOMER (CLIENT_ADMIN) | Nhận bản sao thông báo breach các event nghiêm trọng tenant mình | Nắm tình hình toàn công ty không cần theo từng ticket |
| 5 | CUSTOMER (CLIENT_ADMIN) | Bật/tắt push per-thiết bị, chọn loại event, đặt giờ im lặng | Nhận đúng thông tin cần, không bị phiền đêm với sự kiện không khẩn |
| 6 | CUSTOMER (CLIENT_USER) | Yêu cầu reopen ticket vừa bị đóng ngay trên mobile trong 7 ngày | Xử lý tiếp sự cố chưa xong, giữ nguyên ngữ cảnh |
| 7 | CUSTOMER (CLIENT_ADMIN) | Deep-link sang BC Portal Web khai báo lịch làm việc, xác thực kênh Zalo/Telegram | SLA High/Medium/Low tính theo lịch thực tế của công ty |
| 8 | OPS_AM | Thấy timestamp gửi/đọc của thông báo breach tôi gửi (về phía nội bộ) | Chứng minh tuân thủ "thông báo khách trong 30 phút" khi tranh chấp |

> *Touchpoint: OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS là nguồn phát event nhưng thao tác trên SYS-BCERP-WEB/SYS-MOBILE-INTERNAL — không đăng nhập mobile portal; story liên quan nằm ở file counterpart.*

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Nguồn gốc là BR-OPS-9.1 → 9.3 (operations.md B.9); dưới đây là phần áp dụng lên touchpoint mobile portal. Mọi rule enforce ở tầng service CORE trước khi trả dữ liệu về app — không tin client.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-MP-001 | **Tenant isolation tuyệt đối, chỉ event của tenant mình:** push, in-app notification, đồng hồ SLA chỉ phát/truy vấn theo `tenant_id` khớp người đăng nhập và thiết bị đã đăng ký; dữ liệu qua **view tổng hợp đã lọc tenant** dùng chung portal web (RLS DB + filter API), app không chạm DB nội bộ. Không hiển thị dữ liệu tenant khác, trạng thái escalation nội bộ, giá vốn hay số liệu tài chính BC. | Nhận thông báo tenant khác là sự cố bảo mật P0: chặn ở tầng service, audit log bất biến, incident report; API truy chéo bị từ chối không tiết lộ sự tồn tại dữ liệu |
| BR-MP-002 | **Đồng hồ SLA read-only, song song múi giờ:** mốc tính duy nhất **GMT+7** (nguồn sự thật CORE), app hiển thị kèm giờ địa phương tenant. Target theo **ma trận tier×priority** (`sla-khach-hang.md` §2.1 — E nhanh nhất, A chậm nhất; riêng Critical chạy 24/7); hợp đồng cam kết cao hơn → hiển thị theo profile khách gắn nhãn **"theo hợp đồng"**. App không tự tính giờ, không thao tác nào sửa được clock/target/pause. | Yêu cầu ghi lên đồng hồ bị chặn tầng API (403) + log bảo mật; hiển thị sai target hay tự tính % thời lượng là lỗi dữ liệu P1 |
| BR-MP-003 | **Trực Critical là on-call xoay vòng, SLA phản hồi 4h ngoài giờ** (DI-005 đã chốt — thay desk 24/7); app hiển thị cam kết **"phản hồi tối đa 4 giờ ngoài giờ làm việc"** cho sự kiện Critical, trong khi đồng hồ Critical vẫn chạy 24/7 mọi ngày theo ma trận. | Cấm hiển thị "24/7 có người trực" — cam kết hiển thị phải khớp chế độ on-call đã chốt (DI-005); sai cam kết là lỗi nội dung P1 |
| BR-MP-004 | **Lịch làm việc khách chỉ xem trên mobile, quản lý ở portal web:** app hiển thị lịch tenant đã khai báo và hiệu lực với clock mức **High/Medium/Low**; Critical vẫn 24/7 không phụ thuộc lịch. Sửa lịch deep-link sang portal web, chỉ CLIENT_ADMIN; hiệu lực cho ticket phát sinh sau thời điểm lưu — **không hồi tố**, ghi audit log (ai, khi nào, cũ/mới). | Sửa lịch để "xóa" breach đã xảy ra bị chặn; app không có nút ghi lịch; cảnh báo "áp dụng từ thời điểm lưu" bắt buộc hiển thị |
| BR-MP-005 | **Đa kênh theo cấu hình:** in-app luôn bật không tắt được; email/Zalo/Telegram chỉ hoạt động khi tenant bật **và kênh đã xác thực** (quản lý ở SYS-PORTAL-WEB — `FEAT-PORTAL-SLANOT-001`); mobile push per-device, mặc định bật khi đăng nhập, user tự tắt cho thiết bị mình. Phân phối push **≤5 phút từ lúc CORE phát hiện** (khớp tiêu chuẩn alert khẩn REQ-BOD-006); ghi trạng thái queued → sent → delivered → read (hoặc failed). | Kênh chưa verify không nhận thông báo; push quá 5 phút cho event khẩn là lỗi nghiệm thu; mất thông báo không có fallback in-app/email là lỗi |
| BR-MP-006 | **An toàn lock screen, mask và bảo mật mobile:** body push chỉ chứa loại event + mã ticket + mức — **không chứa** số dư, giá vốn, số tiền; nội dung đầy đủ chỉ mở trong app qua sinh trắc học/PIN; app ở background che nội dung; push token gắn `user_id` + `tenant_id`, thu hồi ngay khi user bị vô hiệu hóa, đăng xuất hay CLIENT_ADMIN thu hồi phiên từ portal web; deep-link kiểm tra phiên hợp lệ trước khi mở màn đích. Notification liên quan ví/đối soát dùng nhãn trung tính như portal web. | Push lộ dữ liệu nhạy cảm trên lock screen là lỗi bảo mật chặn release (P0); push tới thiết bị đã thu hồi là lỗi; screenshot app switcher lộ nội dung là lỗi nghiệm thu |
| BR-MP-007 | **Lời nhắc Pending đúng nhịp + phản hồi nhanh tính chính thức:** nhịp nhắc theo CORE — Critical sau 4h rồi 12h; mức khác sau 24h rồi 48h LV. Phản hồi nhanh từ push/in-app đi vào **queue hợp nhất REQ-OPS-009 như phản hồi chính thức của khách qua kênh portal** — CORE quyết resume clock. Sau lời nhắc thứ 2, tiếp tục 24h (Critical) / 24h LV (còn lại) không phản hồi → auto-Closed "khách không phản hồi", **không tính breach**, app cho **reopen trong 7 ngày** giữ ngữ cảnh; quá 7 ngày tạo ticket mới tham chiếu. | Cấm lời nhắc sai nhịp hay giấu trạng thái auto-Closed; quick reply không ghi vào ticket gốc là lỗi tích hợp; reopen ngoài 7 ngày bị chặn theo REQ-OPS-009 |
| BR-MP-008 | **Thông báo breach đúng nghĩa vụ 30 phút:** chạm 100% SLA → trong **5 phút** nội bộ báo đỏ OPS_AM đầu mối (M-INT/WEB) và đẩy alert center BOD theo REQ-BOD-006; **AM thông báo khách trong 30 phút** theo template chuẩn (lý do, phương án khắc phục, ETA mới) — in-app + push + kênh tenant đã bật; app ghi timestamp "đã thông báo"/"đã đọc". **Không thông báo là vi phạm riêng**, độc lập breach kỹ thuật; quá 30 phút đẩy dashboard OPS_PLAN + alert center. | Quá 30 phút → vi phạm riêng phát alert đỏ REQ-BOD-006; timestamp không sửa/xóa được — là bằng chứng tuân thủ |
| BR-MP-009 | **ETA mới sau override, chi tiết nội bộ không lộ:** override/gia hạn (OPS_AM gia hạn lần 1 ≤50% target; OPS_PLAN lần 2; BOD_CEO miễn theo đợt) bắt buộc lý do + audit log bất biến phía nội bộ; mobile khách chỉ nhận **ETA mới đã duyệt**, không thấy người gia hạn, lý do nội bộ hay số lần gia hạn. Chuỗi thẩm quyền theo BR-OPS-9.3 hiện hành — xác nhận RACI chính thức còn mở `[KXN-19]`, không tự quyết thay thế. | Mobile lộ chi tiết override nội bộ là lỗi phân quyền; ETA hiển thị khác ETA duyệt là lỗi dữ liệu P1 |
| BR-MP-010 | **Chống ngập + offline không suy diễn:** dedupe theo `dedupe_key` (khách + chủ đề + tài sản); nhiều event cùng nguồn (platform outage) được **bundle thành thông báo tóm tắt** có đếm số lượng — kế thừa nguyên tắc "gộp theo nguồn, không ngập người nhận" của REQ-BOD-006; giờ im lặng per-device chỉ áp mức Low/Medium, Critical/breach luôn xuyên qua. App cache offline gắn nhãn "dữ liệu cũ" + timestamp; push **không phải nguồn sự thật** — mở app luôn fetch từ CORE; mất event bus hiện nhãn "chờ đồng bộ". | Trùng lặp không dedupe, bundle làm mất Critical, hay giờ im lặng chặn breach là lỗi P1; hành động ghi (quick reply/reopen) trên cache bị chặn — bắt buộc có mạng và xác nhận server |

---

## 4. Phân Quyền

> *Phạm vi bảng: touchpoint SYS-MOBILE-PORTAL. Vai nội bộ (OPS_*) thao tác trên counterpart WEB/M-INT nên hầu hết hành động là ❌ (ghi chú nơi làm việc thật). Chỉ dùng 18 vai registry; khách gộp dưới vai CUSTOMER (CLIENT_ADMIN/CLIENT_USER phía tenant).*

| Hành động | CUSTOMER (CLIENT_ADMIN) | CUSTOMER (CLIENT_USER) | OPS_AM | OPS_PLAN | SYS_ADMIN | BOD_CEO |
|-----------|------------------------|------------------------|--------|----------|-----------|---------|
| Nhận push + xem notification center tenant mình | ✅ | ✅ | ❌ (push nội bộ qua M-INT — `FEAT-MBI-SLANOT-001`) | ❌ | ❌ (chỉ công cụ có audit) | ❌ (alert center nội bộ — REQ-BOD-006) |
| Xem đồng hồ SLA rút gọn ticket tenant mình | ✅ | ✅ | ❌ (xử lý trên WEB nội bộ) | ❌ (compliance trên WEB) | ❌ | ❌ |
| Quick reply lời nhắc Pending / xác nhận tiếp nhận breach / yêu cầu reopen 7 ngày | ✅ | ✅ | ❌ (nhận qua queue REQ-OPS-009) | ❌ | ❌ | ❌ |
| Bật/tắt push per-thiết bị, loại event, giờ im lặng (cá nhân mình) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xem lịch làm việc tenant đã khai báo | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Khai báo/sửa lịch làm việc, bật/xác thực kênh tenant (email/Zalo/Telegram) | ❌ (deep-link portal web) | ❌ | ❌ | ❌ | ✅ (trên portal web, có audit) | ❌ |
| Gửi thông báo breach tới khách (template 30 phút) | ❌ | ❌ | ✅ (từ WEB/M-INT nội bộ) | ✅ (điều phối khi AM không khả dụng — WEB) | ❌ | ❌ |
| Xem trạng thái gửi/đọc (receipt) | ❌ | ❌ | ✅ (tenant mình phụ trách — WEB) | ✅ (tổng hợp compliance — WEB) | ✅ (vận hành, có audit) | ❌ (qua báo cáo nội bộ) |
| Sửa/xóa thông báo đã phát hành | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Cấu hình loại event & template toàn hệ thống | ❌ | ❌ | ❌ | ❌ | ✅ (kỹ thuật — WEB nội bộ) | ✅ (duyệt nội dung — WEB nội bộ) |
| Thu hồi phiên/thiết bị user tenant khi mất thiết bị | ✅ (user dưới quyền — portal web) | ❌ | ❌ (hỗ trợ qua REQ-OPS-010) | ❌ | ✅ (hạ tầng, có audit) | ❌ |

**Quy tắc xuyên bảng:**
- Mọi ✅ ràng buộc thêm bởi BR-MP-001 — quyền chỉ có ý nghĩa trong phạm vi tenant của người dùng; cấu hình mức tenant đặt ở portal web để giữ mobile rút gọn.
- Không có nút "xóa lịch sử thông báo": dữ liệu thông báo là bằng chứng tuân thủ SLA, chỉ đọc sau phát hành (audit log bất biến); template chuẩn (gồm template breach 30 phút) do SYS_ADMIN thay đổi kỹ thuật, BOD_CEO duyệt nội dung.
- Vai nội bộ không dùng OPS_CX/FIN_COMPL (DI-006 — stakeholder đã gỡ).

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Một user nhiều thiết bị:** mỗi thiết bị có push token và cấu hình riêng; tắt/thu hồi một thiết bị không ảnh hưởng thiết bị khác; mất máy — CLIENT_ADMIN thu hồi phiên từ portal web (REQ-OPS-010).
- **Push không tới được** (mất mạng, token hết hạn, OS chặn background): thông báo vẫn nằm trong notification center đánh dấu "chưa đọc"; nguồn sự thật là trạng thái trên server khi fetch — không suy diễn SLA từ việc nhận/không nhận push; fallback email bảo đảm.
- **Nhiều event đồng loạt cùng nguồn:** bundle tóm tắt + deep-link danh sách; event Critical vẫn đẩy riêng; tránh "spam" khiến khách tắt hẳn push.
- **Breach ngoài giờ khách:** đồng hồ Critical chạy 24/7; ca on-call xoay vòng SLA 4h ngoài giờ (DI-005) bảo đảm phản hồi; thông báo breach vẫn trong 30 phút kể từ khi breach xác định; in-app/email bảo đảm khi Zalo/Telegram không ai đọc.
- **Hợp đồng cam kết cao hơn ma trận:** target hiển thị theo profile khách gắn nhãn "theo hợp đồng"; gia hạn hợp đồng cập nhật từ thời điểm hiệu lực, không hồi tố breach đã ghi.
- **Kênh Zalo/Telegram mất xác thực giữa chừng:** kênh tạm ngừng, retry có backoff rồi fallback in-app + email; CLIENT_ADMIN được cảnh báo verify lại qua portal web; mobile hiển thị kênh "chưa xác thực".
- **Giả định chờ xác nhận (không tự quyết):** danh mục cờ cảnh báo mở rộng K6–K12 chưa chốt `[KXN-20]` — chốt xong bổ sung loại event push, không đổi kiến trúc; ranh giới scope "hiện tại — tương lai" (CMS/TMS/AI Agent có phát notification kênh khách hay không) `[KXN-9]`; chuỗi thẩm quyền override chờ RACI chính thức `[KXN-19]`. Các KXN còn mở khác (6, 7, 15–18, 21, 22) thuộc proposal/HR/CRM, không ảnh hưởng spec này.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Thông báo (Notification) — vòng đời phía mobile portal, dùng chung mô hình với SYS-PORTAL-WEB (`FEAT-PORTAL-SLANOT-001`) để hai touchpoint khách nhất quán. Đồng hồ SLA hiển thị kèm trạng thái chiếu read-only từ CORE: `ON_TRACK` → `PRE_ALERT_80` → `BREACH_100` → `CUSTOMER_NOTIFIED` → `RESOLVED`; trạng thái do CORE sở hữu, mobile không chuyển đổi.

**Sơ đồ trạng thái:**
```
[QUEUED] ──(dispatch push/in-app)──► [SENT] ──(ack kênh)──► [DELIVERED] ──(mở/xem)──► [READ]
   │                                     │
   │ (lỗi gửi, hết retry)                │ (retry có backoff)
   ▼                                     ▼
[FAILED] ◄───────────────────────── [RETRYING] ──(fallback in-app/email)──► [SENT]
   │
   └──(hết hạn — ticket đã Closed/thay thế trước khi gửi)──► [EXPIRED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `QUEUED` | Dispatch theo kênh (push thiết bị opt-in, in-app) | `SENT` | Hệ thống | Kênh đã verify; `tenant_id` khớp người nhận (BR-MP-001); ≤5 phút với event khẩn |
| `SENT` | Kênh báo lỗi gửi | `RETRYING` | Hệ thống | Retry có backoff, không vượt số lần cấu hình |
| `RETRYING` | Gửi lại thành công | `SENT` | Hệ thống | Ghi số lần thử + mã lỗi các lần trước |
| `RETRYING` | Hết retry → fallback | `FAILED` | Hệ thống | Fallback in-app + email (nếu bật); cảnh báo SYS_ADMIN + CLIENT_ADMIN (qua portal web) |
| `SENT`/`DELIVERED` | Người nhận mở thông báo/app | `READ` | Người nhận tenant | Ghi timestamp đọc — không sửa được |
| `QUEUED` | Sự kiện gốc đã kết thúc (ticket Closed/thay thế) | `EXPIRED` | Hệ thống | Ghi lý do hết hạn; không đẩy ra kênh ngoài |

**Quy tắc:**
- `READ` và `FAILED`/`EXPIRED` là trạng thái kết thúc — không quay lại; mọi chuyển trạng thái ghi audit log bất biến ở CORE.
- Không ai (kể cả SYS_ADMIN) sửa/xóa notification đã phát hành — chỉ phát notification bổ sung/khắc phục; dữ liệu là bằng chứng nghĩa vụ thông báo 30 phút.
- Trạng thái SLA hiển thị (`PRE_ALERT_80`, `BREACH_100`, …) là mirror từ CORE — mất kết nối event bus hiện nhãn "dữ liệu chờ đồng bộ" + timestamp cập nhật cuối, không tự suy diễn (BR-MP-010).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `notification` | `id`, `tenant_id`, `recipient_user_id`, `event_type`, `event_ref`, `dedupe_key`, `bundle_id`, `channel`, `status`, `sent_at`, `read_at`, `payload_masked` | FK → `tenants.id`, FK → `users.id`, `event_ref` → ticket/event | Bất biến sau phát hành; dùng chung PORTAL-WEB và M-PORTAL; `bundle_id` gom event cùng nguồn (BR-MP-010) |
| `mobile_device` | `user_id`, `tenant_id`, `push_token`, `platform`, `push_opt_in`, `dnd_window`, `last_seen`, `revoked_at` | FK → `CLIENT_USER.id`, `tenant_id` | Per-device token + cấu hình; thu hồi khi đăng xuất/user bị vô hiệu hóa/mất thiết bị (BR-MP-006) |
| `tenant_notification_channel` | `tenant_id`, `channel_type` (`in_app`/`email`/`zalo`/`telegram`), `endpoint`, `verify_token`, `verified_at`, `enabled` | FK → `tenants.id` | Quản lý ở SYS-PORTAL-WEB; mobile chỉ đọc — `in_app` luôn bật |
| `sla_clock_view` | `ticket_id`, `tenant_id`, `target_fr`, `target_res`, `target_source` (matrix/contract), `elapsed_pct`, `clock_state`, `pause_reason`, `last_synced_at` | FK → `ticket.id`, FK → `tenants.id` | Projection read-only từ event bus CORE; song song GMT+7 + giờ tenant (BR-MP-002) |
| `tenant_user_notification_preference` | `user_id`, `event_type`, `channel_opt_in`, `updated_at` | FK → `users.id` | Sở thích cá nhân trong phạm vi kênh tenant đã bật |
| `tenant_working_calendar` | `tenant_id`, `timezone`, `day_of_week`, `open_time`, `close_time`, `holidays[]`, `effective_from` | FK → `tenants.id` | Mobile chỉ đọc; sửa ở portal web (CLIENT_ADMIN); không hồi tố (BR-MP-004) |

> Chi tiết DDL tại `technical-specs/database-design.md`; ranh giới dữ liệu chéo module (ticket, ví) qua event bus, không join trực tiếp chéo tenant; mobile chỉ tiêu thụ view đã lọc tenant.

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5; dưới đây là phác thảo sơ bộ map về REQ-OPS-008 (Mục 2).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Push breach ≤5 phút, an toàn lock screen | Ticket Critical của tenant chạm 100% SLA | CORE xác nhận breach, AM gửi thông báo | Push tới thiết bị opt-in ≤5 phút từ lúc phát hiện; body chỉ loại event + mã ticket + mức, không số dư/số tiền; nội dung đầy đủ mở trong app qua sinh trắc học/PIN | [ ] |
| SC-002: Đồng hồ rút gọn theo tier + cam kết on-call | Khách Tier E, ticket Critical, hợp đồng cam kết cao hơn ma trận | Mở màn chi tiết ticket trên app | Target theo profile gắn nhãn "theo hợp đồng", chú thích "Critical 24/7 — phản hồi tối đa 4 giờ ngoài giờ" (DI-005); song song GMT+7 và giờ tenant; chỉ đọc | [ ] |
| SC-003: Quick reply resume clock | Ticket Pending, khách nhận lời nhắc nhịp 2 | Khách trả lời nhanh từ thông báo | Phản hồi ghi vào ticket gốc qua queue hợp nhất (REQ-OPS-009) như phản hồi chính thức; CORE resume clock; trạng thái cập nhật khi fetch lại | [ ] |
| SC-004: Tenant isolation | User tenant A đăng nhập trên app | Gọi API notification/clock của tenant B (đoán ID) | API chặn, không trả dữ liệu, không tiết lộ sự tồn tại; security audit log ghi nhận | [ ] |
| SC-005: Auto-Closed sau 2 lời nhắc + reopen | Ticket Pending đã qua 2 lời nhắc + thời hạn | Hết thời hạn phản hồi | Auto-Closed "khách không phản hồi", khách nhận thông báo rõ, không tính breach; app cho reopen trong 7 ngày giữ ngữ cảnh | [ ] |
| SC-006: Thu hồi thiết bị mất | CLIENT_USER báo mất điện thoại | CLIENT_ADMIN thu hồi phiên thiết bị từ portal web | Push token revoked ngay; thiết bị đó không nhận push; thiết bị khác cùng user hoạt động bình thường | [ ] |
| SC-007: Bundle + offline cache | 12 event cùng nguồn trong giờ im lặng; sau đó app mất mạng 3 giờ | Dispatcher phát; khách mở app offline | Event gộp 1 bundle có đếm + deep-link danh sách, Critical xuyên qua; cache có nhãn "dữ liệu cũ" + timestamp, không cho ghi trên cache | [ ] |

> **Liên kết:** SC-001/002/004/005/007 → REQ-OPS-008 (M-PORTAL); SC-003/005 (queue/reopen) → REQ-OPS-008 + REQ-OPS-009; SC-001 (tiêu chuẩn ≤5 phút) → REQ-BOD-006 (liên thông).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (mobile-portal/sla-notif — `notification`, `mobile_device`, view `sla_clock_view`, RLS tenant) |
| API Endpoints — notification feed mobile, push registration, quick reply, đồng hồ read-only | `technical-specs/api-contract.md` (mobile-portal/sla-notif) |
| Tích hợp xuyên hệ thống — event bus CORE SLA engine, push pipeline ≤5 phút, alert center REQ-BOD-006, event ticket REQ-OPS-009 | `technical-specs/integration-map.md` |
| Màn hình UI — notification center, đồng hồ SLA rút gọn, cấu hình push per-device | `phase4-ux/mobile-portal/sla-notif/notification-center.md` |
| Bản counterpart — CORE (`FEAT-CORE-SLANOT-001`), BCERP-WEB (`FEAT-ERP-SLANOT-001`), MOBILE-INTERNAL (`FEAT-MBI-SLANOT-001`), PORTAL-WEB (`FEAT-PORTAL-SLANOT-001`) | `phase2-features/{core-backend,bcerp-web,mobile-internal,portal-web}/sla-notif/` |
| Nguồn nghiệp vụ | `phase1-business/departments/operations/operations.md` (B.9), `phase1-business/P1-02-business-workflow.md` (Luồng 5), policy `sla-khach-hang.md` §2.1 |
