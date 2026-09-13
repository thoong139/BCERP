# Tính Năng: Ticket & CSKH — Bản Mobile Portal (SYS-MOBILE-PORTAL)

> **Dựa trên:** REQ-OPS-009 trong `phase1-business/departments/operations/operations.md` (Phần A + B.9 — BR-OPS-9.1 đến BR-OPS-9.5)
> **Phân hệ:** Mobile Portal — BC Portal cho khách hàng trên di động (SYS-MOBILE-PORTAL)
> **Module:** Ticket & CSKH (MOD-TICKET-CSKH)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 5: CSKH & SLA)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-portal/ticket-cskh/[screen-group].md`, `phase5-implementation/tasks/mobile-portal/ticket-cskh/[feat]-impl.md`

> **Fan-out note:** REQ-OPS-009 xuất hiện ở 5 systems; file này là **bản riêng cho SYS-MOBILE-PORTAL** — app di động cho khách hàng, **touchpoint rút gọn của Portal**: thông báo đẩy, thao tác nhẹ, theo dõi tiến độ; **read-only tuyệt đối phần tài chính**; tenant isolation tuyệt đối. Counterparts: SYS-CORE-BACKEND (queue hợp nhất, state machine, CSAT engine); SYS-BCERP-WEB (assignee xử lý chính); SYS-MOBILE-INTERNAL (assignee nhận việc, push escalation nội bộ); SYS-PORTAL-WEB (bản đầy đủ trên web cho khách).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MPO-CSKH-001 |
| Module | MOD-TICKET-CSKH |
| Yêu cầu nghiệp vụ | REQ-OPS-009 (liên thông: REQ-OPS-008 — SLA clock là nguồn sự thật; REQ-OPS-010 — cấp tài khoản portal, 2FA, watermark; REQ-BOD-006 — alert center khiếu nại nghiêm trọng) |
| Người dùng liên quan | CUSTOMER (khách trên app — phân kiểu tài khoản CLIENT_ADMIN/CLIENT_USER phía tenant); vai nội bộ OPS_AM, OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (xử lý trên counterpart WEB/M-INT, không đăng nhập app khách) |
| Độ ưu tiên | Trung bình (MEDIUM — "Quan trọng" theo operations.md) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Không có cross-dependency ở mức lane (theo lane prompt); phụ thuộc chức năng: queue hợp nhất + state machine + CSAT engine tại SYS-CORE-BACKEND (làm trước), SLA clock REQ-OPS-008, cấp tài khoản portal + 2FA REQ-OPS-010, hạ tầng push notification |
| Ghi chú Expert (A7) | Mục A7 của operations.md hiện "Chờ đánh giá" — chưa có điều chỉnh nào từ Expert Review được ghi nhận cho REQ-OPS-009; sẽ bổ sung khi review hoàn tất |

> *CLIENT_ADMIN/CLIENT_USER là kiểu tài khoản phía tenant, gộp dưới vai registry CUSTOMER; mọi vai nội bộ chỉ dùng 18 vai registry — không có OPS_CX/FIN_COMPL (DI-006 đã chốt gỡ).*

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa Ticket & CSKH của REQ-OPS-009 vào app di động dành cho khách hàng — **touchpoint rút gọn của BC Portal**: khách nhận **push notification** cho mọi chuyển động của ticket, **tạo ticket nhanh** kèm ảnh chụp màn hình, **theo dõi** trạng thái với đồng hồ SLA song song (GMT+7 và giờ địa phương khách), **trả CSAT** ngay trên điện thoại sau xử lý. Yêu cầu gửi từ app đổ về queue hợp nhất của CORE theo tier khách, được đo SLA và leo thang đúng path cấp cao **AM → AD → BOD** khi cần — khách luôn biết ticket đang ở đâu mà không phải hỏi lại AM.

**Phạm vi:**
- Bao gồm:
  - **Thông báo đẩy + in-app**: push khi ticket được nhận việc, có phản hồi mới, đổi trạng thái, breach — nội dung push tuân thủ mask, nguồn sự thật trạng thái luôn là CORE.
  - **Tạo ticket trên mobile**: form rút gọn đủ trường bắt buộc (chủ đề, mô tả, nhóm vấn đề, tệp minh chứng — ảnh camera/thư viện được nén), gửi vào queue hợp nhất đa kênh; app là một mặt của kênh chính thức "portal".
  - **Theo dõi read-only**: danh sách ticket tenant, trạng thái, lịch sử phản hồi cho khách, đồng hồ SLA (target theo tier×priority, % thời lượng, nhãn "theo hợp đồng" khi HĐ ghi đè), ETA mới sau breach.
  - **Trao đổi hai chiều nhẹ**: khách bổ sung thông tin (nhắn kèm ảnh) khi ticket đang chờ mình (Pending) để kéo ticket quay lại xử lý.
  - **CSAT sau xử lý**: thang 1–5 + 1 câu mở sau Closed, nhắc tối đa 1 lần sau 48h, trả lời một chạm.
  - **Reopen trong 7 ngày** giữ ngữ cảnh; quá hạn được hướng dẫn tạo ticket mới tham chiếu ngay trên app.
  - **Bảo vệ dữ liệu**: tenant isolation; không hiển thị ghi chú nội bộ, giá vốn, chiết khấu; tệp tải về có watermark; hành động nhạy cảm yêu cầu OTP.
- Không bao gồm:
  - Queue hợp nhất, dedupe, state machine, CSAT engine, SLA engine, escalation engine — thuộc SYS-CORE-BACKEND; app chỉ gửi hành động khách và chiếu trạng thái.
  - Nơi assignee xử lý — SYS-BCERP-WEB; nhận việc/push escalation cho nhân viên — SYS-MOBILE-INTERNAL; bản đầy đủ web cho khách (quản lý user tenant, lọc nâng cao, xuất dữ liệu) — SYS-PORTAL-WEB.
  - Chi tiết đối soát/khiếu nại tài chính — chỉ nhãn trạng thái ("Đang đối soát" — REQ-FIN-004), read-only tuyệt đối phần tài chính.
  - Cấp/thu hồi tài khoản portal — REQ-OPS-010; dashboard compliance nội bộ — SYS-BCERP-WEB; alert center BOD — REQ-BOD-006.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (người dùng tenant) | Nhận push khi ticket của tôi có cập nhật (nhận việc, phản hồi, đổi trạng thái, breach) | Phản ứng nhanh ngay trên điện thoại, không phải theo dõi email |
| 2 | CUSTOMER (người dùng tenant) | Tạo ticket nhanh kèm ảnh chụp màn hình từ điện thoại | Báo sự cố mọi lúc mọi nơi qua kênh chính thức có truy vết |
| 3 | CUSTOMER (người dùng tenant) | Thấy danh sách ticket và đồng hồ SLA song song GMT+7 + giờ địa phương | Tự theo dõi tiến độ so với cam kết, không phải hỏi lại AM |
| 4 | CUSTOMER (người dùng tenant) | Được cảnh báo khi yêu cầu nhập trùng ticket đang mở của tenant | Tránh tạo trùng, theo dõi tập trung một ticket |
| 5 | CUSTOMER (người dùng tenant) | Nhắn tin bổ sung kèm ảnh khi ticket đang chờ tôi (Pending) | Ticket quay lại luồng xử lý sớm, không bị auto-đóng vì thiếu phản hồi |
| 6 | CUSTOMER (người dùng tenant) | Trả CSAT 1–5 một chạm sau khi ticket đóng, được nhắc tối đa 1 lần | Phản ánh chất lượng dịch vụ đúng lúc mà không mất thời gian |
| 7 | CUSTOMER (CLIENT_ADMIN của tenant) | Mở lại ticket trong 7 ngày giữ ngữ cảnh; quá hạn thì tạo mới tham chiếu | Không phải kể lại sự việc, vẫn giữ truy vết khi quá hạn reopen |
| 8 | CUSTOMER (người dùng tenant) | Khiếu nại nghiêm trọng (mất tiền, sai đối soát, đạo đức nhân viên) qua app và thấy "đang xử lý cấp cao" | Tin khiếu nại tới cấp có thẩm quyền (BOD trong 24h) mà không cần biết chi tiết nội bộ |
| 9 | OPS_AM | Xem timestamp gửi/đọc thông báo trên app của khách (tại công cụ nội bộ) | Chứng minh tuân thủ nghĩa vụ thông báo breach trong 30 phút |
| 10 | OPS_PLAN | Theo dõi khiếu nại nghiêm trọng đã leo thang (nội bộ trên WEB) và điều phối hồ sơ | Bảo đảm hồ sơ đầy đủ trước mốc leo thang BOD 24h |

> *Touchpoint: OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS là assignee xử lý trên SYS-BCERP-WEB/SYS-MOBILE-INTERNAL — không đăng nhập app khách (story nằm ở file counterpart). OPS_AM là đầu mối phía BC cho tenant; OPS_PLAN điều phối escalation; BOD nhận hồ sơ qua alert center nội bộ (REQ-BOD-006).*

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Nguồn gốc là BR-OPS-9.1 → BR-OPS-9.5 (operations.md B.9) và REQ-OPS-009 Phần A; dưới đây là phần áp dụng lên touchpoint mobile portal. Số liệu SLA đã chốt theo DI-005.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-MP-001 | **Tenant isolation tuyệt đối:** mọi ticket, phản hồi, tệp, CSAT chỉ truy vấn theo `tenant_id` người đăng nhập; cấm hiển thị dữ liệu tenant khác và dữ liệu nội bộ BC. Enforce ở service layer của CORE — app không tự lọc. | API trả lỗi không tiết lộ sự tồn tại dữ liệu; security audit log bất biến; alert SYS_ADMIN — lộ dữ liệu là sự cố P0 |
| BR-MP-002 | **Kênh chính thức hợp nhất:** ticket từ app vào queue hợp nhất đa kênh (portal — gồm app + web, email, Zalo) của CORE, xếp theo khách/tier, kênh ghi `portal (mobile)`. CORE dedupe theo (khách + chủ đề + tài sản): khi trùng trả về ticket hiện có — app hiển thị "đã gộp vào ticket #…". | Tạo trùng bị chặn ở CORE; app không tự gộp/tách, chỉ hiển thị kết quả dedupe |
| BR-MP-003 | **Ngoài scope tự tách change request:** CORE nhận diện nội dung ngoài hợp đồng → app báo "đã tách thành change request — không tính SLA vận hành", kèm tham chiếu hai chiều. | Cấm tính SLA vận hành cho change request; cấm tách mà khách không được thông báo |
| BR-MP-004 | **SLA theo tier, hiển thị read-only:** target FR/Res theo ma trận tier×priority (E nhanh nhất — A chậm nhất; riêng Critical 24/7 — `sla-khach-hang.md` §2.1); HĐ cam kết cao hơn → ghi đè theo profile khách, nhãn "theo hợp đồng". Mốc tính duy nhất GMT+7 (nguồn sự thật CORE), app hiển thị song song giờ địa phương tenant. Trực Critical ngoài giờ: on-call xoay vòng SLA 4h (DI-005 đã chốt). | Mọi thao tác ghi lên clock/target từ app bị chặn tầng API (403); sai target hiển thị là lỗi P1 |
| BR-MP-005 | **State machine chuẩn:** New → Open → Pending → Resolved → Closed (sở hữu bởi CORE). **Reopen trong 7 ngày** giữ toàn bộ ngữ cảnh; quá 7 ngày chỉ tạo ticket mới tham chiếu. | Reopen ngoài hạn bị từ chối kèm hướng dẫn tạo ticket mới; chuyển trạng thái trái máy trạng thái bị CORE chặn |
| BR-MP-006 | **Pending chờ khách:** clock pause tự động; nhắc theo nhịp CORE — Critical 4h rồi 12h, mức khác 24h rồi 48h LV. Sau lời nhắc thứ 2, tiếp tục 24h (Critical) / 24h LV (còn lại) không phản hồi → auto-Closed "khách không phản hồi", **không tính breach**, vẫn reopen được trong 7 ngày. | Cấm giấu trạng thái auto-Closed; khách phải thấy rõ lý do đóng và nút reopen trong hạn trên app |
| BR-MP-007 | **Escalation bắt buộc (CORE sở hữu):** trigger — Critical quá First Response; chạm 100% SLA; reopen ≥2 lần; Pending quá 3 ngày LV; khiếu nại từ CLIENT_ADMIN khách Tier D/E. Chuỗi nội bộ assignee → AM → CS TL → OPS_PLAN → BOD, mỗi chặng 30 phút trong giờ trực; path cấp cao bắt buộc **AM → AD (Account Director) → BOD**. AD có mã OPS_AD đã chốt (KXN-12) nhưng chưa vào registry 18 vai — quyền cấp AD tạm gán OPS_PLAN; xác nhận RACI còn mở `[KXN-19]`, không tự quyết. | Escalation không chạy khi trigger vi phạm là lỗi P1; app chỉ hiển thị "đang xử lý cấp cao", không lộ chuỗi/chặng nội bộ |
| BR-MP-008 | **Breach 100%:** trong 5 phút báo đỏ AM + CS TL (nội bộ); **AM thông báo khách trong 30 phút** theo template chuẩn (lý do, phương án khắc phục, ETA mới) — trên ticket kèm timestamp "đã thông báo"/"đã đọc" do CORE ghi. Không thông báo là **vi phạm riêng**, độc lập breach kỹ thuật. | Quá 30 phút → vi phạm riêng đẩy dashboard OPS_PLAN + alert center (REQ-BOD-006); timestamp bất biến, không lấy từ thiết bị khách |
| BR-MP-009 | **CSAT sau xử lý:** khi Closed, CORE phát khảo sát thang **1–5 + 1 câu mở**; nhắc **tối đa 1 lần sau 48h**; một CSAT/ticket dù tenant nhiều người thấy form. **Detractor ≤2:** liên hệ lại trong **48h làm việc**, nội dung liên hệ + hành động khắc phục gắn ticket gốc (khách chỉ thấy "đã ghi nhận — đang liên hệ lại"). Tier CSAT <4,0 hai tháng liên tiếp → review dịch vụ do OPS_PLAN chủ trì (nội bộ). | Cấm nhắc lần 2; cấm cho khách thấy CSAT tenant khác hay phân tích nội bộ theo tier |
| BR-MP-010 | **Khiếu nại nghiêm trọng** (khách Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên): leo thang **BOD trong 24h kèm hồ sơ đầy đủ**, OPS_PLAN điều phối. App chỉ hiển thị "đang xử lý cấp cao"; mất tiền/sai đối soát gắn nhãn "Đang đối soát" (REQ-FIN-004) — chi tiết tài chính chỉ trên portal web (read-only phần tài chính). | Quá 24h thiếu hồ sơ ở BOD là vi phạm P1; app không lộ phương án khắc phục nội bộ trước khi AM thông báo chính thức |
| BR-MP-011 | **Mask + watermark + OTP:** nội dung và push cho khách không chứa giá vốn, chiết khấu, margin, ghi chú nội bộ; tệp tải về có watermark (REQ-OPS-010). **Hành động nhạy cảm** (đổi mật khẩu, quản lý user tenant, xuất dữ liệu ticket) yêu cầu thêm lớp OTP kèm audit log. | Dữ liệu nội bộ lọt tới khách là lỗi bảo mật P0 — chặn xuất bản, audit log, incident report |
| BR-MP-012 | **Thiết bị & thông báo:** push token đăng ký theo thiết bị sau đăng nhập 2FA (REQ-OPS-010); logout/thu hồi quyền → hủy token ngay; mất thiết bị → CLIENT_ADMIN đăng xuất thiết bị từ xa. Tắt quyền thông báo OS → app cảnh báo và hiển thị fallback in-app + email/Zalo; push không phải kênh chứng minh tuân thủ — timestamp lấy từ CORE. | Push tới thiết bị đã thu hồi là lỗi bảo mật P1; cảnh báo fallback phải hiện trước khi khách rời màn cài đặt |
| BR-MP-013 | **Gửi tin cậy:** mọi hành động gửi từ app (tạo ticket, phản hồi, CSAT) là idempotent — retry sau lỗi mạng không tạo bản ghi trùng; thất bại thì giữ bản nháp nội bộ app, không mất nội dung người dùng đã nhập. App không hứa offline-capable đầy đủ (khác M-INT) — chỉ gửi lại khi có mạng. | Gửi trùng do retry bị chặn theo idempotency key; mất nội dung nháp là lỗi UX P2 ghi nhận vào backlog |

---

## 4. Phân Quyền

> *Phạm vi bảng: touchpoint SYS-MOBILE-PORTAL (app khách). Vai nội bộ (OPS_*) thao tác trên counterpart WEB/M-INT nên hầu hết hành động trên app là ❌ (ghi chú nơi làm việc thật). Khách gộp dưới vai CUSTOMER (phân CLIENT_ADMIN/CLIENT_USER phía tenant).*

| Hành động | CUSTOMER (CLIENT_ADMIN) | CUSTOMER (CLIENT_USER) | OPS_AM | OPS_PLAN | SYS_ADMIN |
|-----------|------------------------|------------------------|--------|----------|-----------|
| Xem danh sách/chi tiết ticket tenant mình (trạng thái, SLA, lịch sử) | ✅ | ✅ | ❌ (xử lý trên WEB nội bộ) | ❌ (monitor trên WEB nội bộ) | ❌ (chỉ công cụ quản trị có audit) |
| Tạo ticket mới trên app kèm ảnh minh chứng | ✅ | ✅ | ❌ (tạo hộ chỉ qua email/Zalo tại CORE) | ❌ | ❌ |
| Nhận push event ticket | ✅ (thiết bị đã đăng ký) | ✅ (thiết bị đã đăng ký) | ❌ (push escalation nội bộ thuộc M-INT) | ❌ | ❌ |
| Đăng ký/hủy thiết bị push của mình; đăng xuất thiết bị từ xa khi mất thiết bị | ✅ (thiết bị của user tenant mình) | ✅ (chỉ thiết bị của mình) | ❌ | ❌ | ✅ (hỗ trợ kỹ thuật có audit) |
| Phản hồi/bổ sung thông tin (Pending → quay lại xử lý) | ✅ | ✅ (ticket mình tạo hoặc được mention) | ❌ (phản hồi trên WEB/M-INT) | ❌ | ❌ |
| Trả CSAT sau khi ticket Closed | ✅ | ✅ (người theo dõi ticket) | ❌ | ❌ | ❌ |
| Reopen trong 7 ngày giữ ngữ cảnh | ✅ | ✅ (người tạo ticket) | ✅ (hộ khách theo yêu cầu chính thức, có audit — trên WEB) | ❌ | ❌ |
| Xác nhận khiếu nại nghiêm trọng / leo thang BOD 24h | ❌ (chỉ khai báo nội dung khi tạo — CORE nhận diện) | ❌ | ✅ (xác nhận hồ sơ trên WEB) | ✅ (điều phối — quyền cấp AD tạm gán, chờ OPS_AD `[KXN-12]` vào registry) | ❌ |
| Gán/đổi assignee, chuyển Resolved, ghi chú nội bộ | ❌ | ❌ | ✅ (WEB nội bộ) | ✅ (điều phối lại khi escalation) | ❌ |
| Xem ghi chú nội bộ, phân tích CSAT theo tier, dashboard compliance | ❌ | ❌ | ✅ (WEB nội bộ) | ✅ (WEB nội bộ) | ❌ |
| Sửa/xóa ticket, phản hồi, CSAT đã ghi | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ hiệu chỉnh kỹ thuật có audit khi xử lý sự cố) |

**Quy tắc xuyên bảng:**
- Mọi ✅ của khách ràng buộc thêm bởi BR-MP-001 — quyền chỉ có ý nghĩa trong phạm vi tenant; CLIENT_ADMIN tự quản user tenant theo REQ-OPS-010 (nội bộ không tạo hộ).
- Không có nút "xóa ticket/phản hồi/CSAT" trên app: dữ liệu là bằng chứng CSKH và đầu vào KPI nhân sự (REQ-HR-007), chỉ đọc sau khi ghi.
- Quyền "điều phối khiếu nại" gán OPS_PLAN theo DI-006 (không có OPS_CX); khi registry bổ sung OPS_AD thì chuyển quyền cấp AD tương ứng — qua quản trị vai, không sửa code.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Tenant nhiều người dùng cùng một ticket:** mọi user tenant đều thấy ticket của tenant; push gửi người tạo + người được mention + CLIENT_ADMIN khi event nghiêm trọng; CSAT chỉ ghi một lần/ticket.
- **Trùng lặp khi tạo từ app:** CORE trả về ticket hiện có; app hiển thị "đã gộp" kèm link; nội dung và ảnh vừa nhập lưu như phản hồi trên ticket gốc để không mất thông tin.
- **Yêu cầu ngoài scope:** CORE tách change request; app hiển thị liên kết hai chiều, SLA vận hành ngừng tính từ thời điểm tách, khách thấy giải thích ngắn theo template.
- **Khách không phản hồi lời nhắc Pending:** sau đủ 2 lời nhắc + thời hạn → auto-Closed "khách không phản hồi", không tính breach; app báo rõ lý do và cho reopen 7 ngày giữ ngữ cảnh.
- **Reopen hết hạn 7 ngày:** nút reopen ẩn; app mở sẵn form tạo ticket mới với ngữ cảnh chính (khách, chủ đề, tham chiếu ticket cũ) điền sẵn — đi queue bình thường, không kế thừa SLA clock cũ.
- **Mất/thay thiết bị:** thiết bị cũ bị thu hồi push token; đăng nhập thiết bị mới phải qua 2FA theo REQ-OPS-010; CLIENT_ADMIN đăng xuất thiết bị từ xa cho user tenant mình khi có báo mất.
- **Push không đảm bảo nhận:** push chỉ là kênh tiện lợi — mọi trạng thái có nguồn sự thật từ CORE, mở app là đồng bộ lại; in-app + email/Zalo là kênh bảo đảm cho event nghiêm trọng (breach, khiếu nại) kể cả khi quyền thông báo OS bị tắt.
- **Mạng yếu/gửi thất bại:** idempotency key chặn tạo trùng khi retry; bản nháp (nội dung + ảnh) giữ trong app tới khi gửi thành công; người dùng thấy trạng thái gửi rõ ràng.
- **Khiếu nại mất tiền/sai đối soát:** song song leo thang BOD 24h, AM khởi tạo đối soát REQ-FIN-004; app chỉ hiển thị nhãn "Đang đối soát" — chi tiết tài chính trên portal web.
- **Ánh xạ vai ngoài registry:** "CS TL" ánh xạ về OPS_AM (đầu mối SLA phía tenant), điều phối là OPS_PLAN; AD = Account Director (mã OPS_AD — KXN-12 đã chốt, chưa vào registry); không dùng OPS_CX/FIN_COMPL (DI-006).
- **Khảo sát khách định kỳ khác (Client Survey)** không thuộc CSAT sau ticket — phạm vi/kênh gửi còn mở `[KXN-15]`, không tự quyết trong spec này; spec chỉ chốt CSAT tự động sau Closed theo REQ-OPS-009.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Ticket — vòng đời sở hữu bởi SYS-CORE-BACKEND (queue hợp nhất + state machine chuẩn REQ-OPS-009); app gửi hành động của khách qua API và chiếu trạng thái read-only kèm đồng hồ SLA và push.

**Sơ đồ trạng thái:**
```
        (khách tạo trên app / portal web / email / Zalo — CORE dedupe)
                            │
                            ▼
[NEW] ──(assignee nhận việc)──► [OPEN] ──(chuyển Resolved)──► [RESOLVED] ──(đóng vòng)──► [CLOSED]
                            │                                                    │
                            │ (chờ khách / chờ bên thứ 3)                        │ (reopen ≤7 ngày — giữ ngữ cảnh)
                            ▼                                                    ▼
                        [PENDING] ──(khách phản hồi trên app)──► [OPEN]      [REOPENED → OPEN]
                            │
                            │ (hết 2 lời nhắc + thời hạn)
                            ▼
                   [CLOSED "khách không phản hồi"] ──(>7 ngày)──► [ticket mới tham chiếu]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| (chưa có) | Tạo ticket trên app | `NEW` | CUSTOMER | Đủ trường bắt buộc; qua dedupe CORE (BR-MP-002); kênh ghi `portal (mobile)` |
| `NEW` | Nhận việc | `OPEN` | Assignee OPS (WEB/M-INT — không qua app) | Có assignee; bắt đầu đo First Response |
| `OPEN` | Chuyển Pending | `PENDING` | Assignee OPS | Lý do chờ khách hoặc blocked-3rd-party có case ID; clock pause |
| `PENDING` | Khách phản hồi trên app | `OPEN` | CUSTOMER | Phản hồi ghi vào ticket; clock resume |
| `PENDING` | Hết 2 lời nhắc + hạn, không phản hồi | `CLOSED` (khách không phản hồi) | Hệ thống | Không tính breach; reopen trong 7 ngày (BR-MP-006) |
| `OPEN` | Chuyển Resolved | `RESOLVED` | Assignee OPS | Bắt buộc mô tả giải pháp (định nghĩa đo Res — BR-OPS-9.1) |
| `RESOLVED` | Đóng vòng xử lý | `CLOSED` | Assignee OPS / hệ thống | Kích hoạt CSAT tự động (BR-MP-009) |
| `CLOSED` | Reopen trong 7 ngày | `OPEN` (REOPENED) | CUSTOMER; OPS_AM (hộ khách, có audit) | Giữ toàn bộ ngữ cảnh; reopen ≥2 lần → escalation bắt buộc (BR-MP-007) |
| `CLOSED` | Tạo lại sau >7 ngày | Ticket `NEW` mới | CUSTOMER | Bắt buộc tham chiếu ticket cũ; không kế thừa SLA clock |

**Quy tắc:**
- `CLOSED` là trạng thái kết thúc: không quay lại trực tiếp sau 7 ngày — chỉ tạo ticket mới tham chiếu; reopen trong hạn là ngoại lệ duy nhất và luôn giữ ngữ cảnh.
- Mọi chuyển trạng thái do CORE thực hiện và ghi audit log bất biến (ai, khi nào, từ trạng thái nào); app không tự chuyển trạng thái — chỉ gửi hành động khách qua API.
- Trạng thái hiển thị đồng bộ từ event bus CORE; mất kết nối → nhãn "dữ liệu chờ đồng bộ" + timestamp cập nhật cuối, không suy diễn từ cache thiết bị.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `ticket` (CORE, chiếu app) | `id`, `tenant_id`, `channel`, `subject`, `category`, `priority`, `tier_at_create`, `status`, `assignee_id`, `reopen_count`, `created_by_portal_user_id`, `dedupe_key` | FK → `tenants.id`, FK → `users.id` | Sở hữu bởi CORE; app chỉ đọc/ghi hành động khách |
| `ticket_message` | `id`, `ticket_id`, `author_type` (`customer`/`staff`), `author_id`, `body`, `visibility` (`customer`/`internal`), `created_at` | FK → `ticket.id` | `visibility=internal` tuyệt đối không trả qua API app (BR-MP-001/011) |
| `ticket_attachment` | `id`, `ticket_id`, `message_id`, `file_key`, `mime`, `size`, `uploaded_by`, `watermark_applied` | FK → `ticket.id`, FK → `ticket_message.id` | Ảnh từ app nén trước khi gửi; lưu trong phạm vi tenant; download có watermark |
| `csat_survey` | `id`, `ticket_id`, `tenant_id`, `score` (1–5), `comment`, `sent_at`, `reminded_at` (tối đa 1), `submitted_at`, `status` | FK → `ticket.id`, FK → `tenants.id` | Một CSAT/ticket; detractor ≤2 sinh follow-up gắn ticket gốc |
| `sla_clock_view` | `ticket_id`, `tenant_id`, `target_fr`, `target_res`, `target_source` (matrix/contract), `elapsed_pct`, `clock_state`, `pause_reason`, `last_synced_at` | FK → `ticket.id` | Projection read-only đồng bộ từ SLA engine REQ-OPS-008 (CORE) |
| `escalation_record` (chiếu app mức trạng thái) | `id`, `ticket_id`, `trigger_type`, `chain_step`, `started_at`, `due_at`, `resolved_at` | FK → `ticket.id` | Chi tiết chuỗi/chặng nội bộ không lộ cho khách — app chỉ thấy "đang xử lý cấp cao" |
| `mobile_device` (touchpoint) | `id`, `user_id`, `tenant_id`, `platform`, `push_token`, `status` (`active`/`revoked`), `registered_at`, `last_seen_at`, `revoked_at` | FK → `users.id`, FK → `tenants.id` | Đăng ký sau đăng nhập 2FA; thu hồi khi logout/mất thiết bị; không chứa dữ liệu ticket |

> Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`; ranh giới dữ liệu chéo module (SLA, đối soát, alert center) qua event bus, không join trực tiếp chéo tenant.

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5; dưới đây là phác thảo sơ bộ map về REQ-OPS-009 (Mục 2).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Khách tạo ticket từ app | CLIENT_USER đã kích hoạt portal và đăng nhập app qua 2FA (REQ-OPS-010) | Gửi form tạo ticket đủ trường bắt buộc kèm 1 ảnh | Ticket vào queue hợp nhất CORE với `channel=portal (mobile)`, xếp theo tier; khách thấy `NEW` + target SLA theo tier×priority song song GMT+7/giờ địa phương | [ ] |
| SC-002: Dedupe khi tạo trùng | Tenant có ticket đang mở cùng chủ đề + tài sản | Tạo ticket trùng nội dung từ app | CORE trả ticket hiện có; app hiển thị "đã gộp vào ticket #…"; nội dung và ảnh nhập lưu như phản hồi trên ticket gốc | [ ] |
| SC-003: Khách phản hồi kéo ticket khỏi Pending | Ticket đang `PENDING` chờ khách | Khách trả lời kèm ảnh trên app | Ticket về `OPEN`, clock resume; phản hồi ghi lịch sử với tác giả tenant | [ ] |
| SC-004: Auto-Closed chờ khách | Ticket Pending đã qua 2 lời nhắc + thời hạn (BR-MP-006) | Hết thời hạn phản hồi | Auto-Closed "khách không phản hồi", không tính breach; khách thấy lý do + nút reopen trong 7 ngày giữ ngữ cảnh | [ ] |
| SC-005: CSAT sau Closed + nhắc 1 lần | Ticket chuyển `CLOSED` | Khách chưa trả CSAT | Form 1–5 + câu mở xuất hiện trên app; sau 48h nhắc đúng 1 lần; trả lời thứ hai bị chặn; detractor ≤2 sinh follow-up 48h LV gắn ticket gốc | [ ] |
| SC-006: Khiếu nại nghiêm trọng leo thang | Khách Tier D tạo ticket từ app bị nhận diện khiếu nại nghiêm trọng (mất tiền) | CORE đánh dấu + tạo hồ sơ | Leo thang BOD trong 24h kèm hồ sơ; OPS_PLAN điều phối; khách chỉ thấy "đang xử lý cấp cao" + nhãn "Đang đối soát" | [ ] |
| SC-007: Tenant isolation + mask + OTP | User tenant A đăng nhập app; ticket có message `visibility=internal` | Gọi API của tenant B (đoán ID); tải tệp; xuất dữ liệu ticket | API chặn không tiết lộ sự tồn tại dữ liệu + security audit log; tệp tải về có watermark; xuất dữ liệu yêu cầu OTP kèm audit | [ ] |
| SC-008: Push theo thiết bị | Khách đăng nhập app trên 2 thiết bị, sau đó logout thiết bị A | Ticket có phản hồi mới | Push tới thiết bị B (đang active); thiết bị A đã thu hồi token, không nhận push; in-app vẫn đúng khi đăng nhập lại | [ ] |
| SC-009: Gửi tin cậy khi mạng yếu | App mất kết nối ngay khi bấm gửi tạo ticket | Mạng quay lại, app tự retry | Đúng 1 ticket được tạo (idempotency key); nội dung nháp không mất; không có bản ghi trùng | [ ] |

> **Liên kết:** SC-001→009 map về REQ-OPS-009 (Mục 2); SC-004, SC-005 tham chiếu thêm nhịp nhắc/pause của REQ-OPS-008 (BR-OPS-9.2); SC-006 liên thông REQ-BOD-006 và REQ-FIN-004; SC-007, SC-008 tham chiếu REQ-OPS-010 (2FA, watermark, thu hồi thiết bị).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (mobile-portal/ticket-cskh) |
| API Endpoints — tạo ticket, phản hồi, CSAT, theo dõi trạng thái read-only, đăng ký/thu hồi thiết bị push | `technical-specs/api-contract.md` (mobile-portal/ticket-cskh) |
| Tích hợp xuyên hệ thống — queue hợp nhất + state machine + CSAT engine (CORE), SLA clock REQ-OPS-008, hạ tầng push notification, đối soát REQ-FIN-004, alert center REQ-BOD-006 | `technical-specs/integration-map.md` |
| Màn hình UI — danh sách ticket, chi tiết ticket + đồng hồ SLA, form tạo nhanh, form CSAT, cài đặt thông báo | `phase4-ux/mobile-portal/ticket-cskh/ticket-va-cskh.md` |
| Bản counterpart — CORE (queue, state machine, CSAT engine), BCERP-WEB (assignee xử lý), MOBILE-INTERNAL (nhận việc/push escalation), PORTAL-WEB (bản đầy đủ web cho khách) | `phase2-features/{core-backend,bcerp-web,mobile-internal,portal-web}/ticket-cskh/` |
