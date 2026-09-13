# Tính Năng: Ticket & CSKH — Bản Client Portal (SYS-PORTAL-WEB)

> **Dựa trên:** REQ-OPS-009 trong `phase1-business/departments/operations/operations.md` (Phần A + B.9 — BR-OPS-9.1 đến BR-OPS-9.5)
> **Phân hệ:** Client Portal (SYS-PORTAL-WEB)
> **Module:** Ticket & CSKH (MOD-TICKET-CSKH)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 5: CSKH & SLA)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/portal-web/ticket-cskh/[screen-group].md`, `phase5-implementation/tasks/portal-web/ticket-cskh/[feat]-impl.md`

> **Fan-out note:** REQ-OPS-009 xuất hiện ở 5 systems; file này là **bản riêng cho SYS-PORTAL-WEB** — Client Portal cho khách hàng: chỉ hiển thị dữ liệu read-only đã được chia sẻ, **tenant isolation tuyệt đối, không lộ dữ liệu nội bộ**. Counterparts: SYS-CORE-BACKEND (queue hợp nhất, state machine, CSAT engine); SYS-BCERP-WEB (assignee xử lý chính); SYS-MOBILE-INTERNAL (assignee nhận việc, push escalation); SYS-MOBILE-PORTAL (bản rút gọn di động cho khách).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-PORTAL-CSKH-001 |
| Module | MOD-TICKET-CSKH |
| Yêu cầu nghiệp vụ | REQ-OPS-009 (liên thông: REQ-OPS-008 — SLA clock là nguồn sự thật; REQ-OPS-010 — cấp tài khoản portal, watermark; REQ-BOD-006 — alert center BOD cho khiếu nại nghiêm trọng) |
| Người dùng liên quan | CUSTOMER (khách trên portal — phân kiểu tài khoản CLIENT_ADMIN/CLIENT_USER phía tenant); vai nội bộ OPS_AM, OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (xử lý trên counterpart WEB/M-INT, không đăng nhập portal) |
| Độ ưu tiên | Trung bình (MEDIUM — "Quan trọng" theo operations.md) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Không có cross-dependency chỉ định ở mức lane (theo lane prompt); phụ thuộc chức năng: queue hợp nhất + state machine + CSAT engine của REQ-OPS-009 tại SYS-CORE-BACKEND (làm trước), SLA clock REQ-OPS-008, cấp tài khoản portal REQ-OPS-010 (điều kiện truy cập) |
| Ghi chú Expert (A7) | Mục A7 của operations.md hiện "Chờ đánh giá" — chưa có điều chỉnh nào từ Expert Review được ghi nhận; sẽ bổ sung khi review hoàn tất |

> *CLIENT_ADMIN/CLIENT_USER là kiểu tài khoản phía tenant, gộp dưới vai registry CUSTOMER; mọi vai nội bộ chỉ dùng 18 vai registry — không có OPS_CX/FIN_COMPL (DI-006 đã chốt gỡ).*

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Mang Ticket & CSKH của REQ-OPS-009 đến phía khách trên Client Portal (web responsive, đa ngôn ngữ/đa múi giờ): khách tự **mở ticket** qua kênh chính thức, **theo dõi** trạng thái kèm đồng hồ SLA song song (GMT+7 của BC và giờ địa phương khách), **trao đổi hai chiều** với nhân viên phụ trách và **trả CSAT** sau xử lý. Yêu cầu đổ về queue hợp nhất của CORE theo tier khách, được đo SLA, escalate đúng chuỗi (AM → AD → BOD) và đóng vòng bằng đo hài lòng — khách tự phục vụ phần lớn nhu cầu thông tin mà không phải hỏi lại AM.

**Phạm vi:**
- Bao gồm:
  - **Tạo ticket trên portal**: form đủ trường bắt buộc (chủ đề, mô tả, nhóm vấn đề, tệp minh chứng), gửi vào queue hợp nhất của CORE — portal là một trong ba kênh chính thức (portal/email/Zalo).
  - **Theo dõi read-only**: trạng thái, lịch sử, đồng hồ SLA (target theo tier×priority, % thời lượng), ETA mới đã duyệt khi breach.
  - **Trao đổi hai chiều**: khách bổ sung thông tin khi ticket chờ mình (Pending), đưa ticket quay lại luồng xử lý.
  - **CSAT sau xử lý**: khảo sát tự động 1–5 + 1 câu mở sau Closed, nhắc tối đa 1 lần sau 48h.
  - **Reopen trong 7 ngày** giữ ngữ cảnh; quá hạn được hướng dẫn tạo ticket mới tham chiếu.
  - **Tenant isolation tuyệt đối**: khách chỉ thấy ticket/phản hồi/CSAT của tenant mình; cấm hiển thị ghi chú nội bộ, giá vốn, chiết khấu, P&L.
- Không bao gồm:
  - Queue hợp nhất, dedupe, state machine, CSAT engine, escalation engine — thuộc SYS-CORE-BACKEND; portal chỉ gửi yêu cầu và chiếu trạng thái.
  - Nơi assignee xử lý ticket — SYS-BCERP-WEB; nhận việc/push escalation di động — SYS-MOBILE-INTERNAL; bản rút gọn di động cho khách — SYS-MOBILE-PORTAL.
  - Cấp/thu hồi tài khoản portal — REQ-OPS-010; đối soát phản đối số liệu — REQ-FIN-004 (portal chỉ hiện nhãn "Đang đối soát"); dashboard compliance nội bộ — SYS-BCERP-WEB; alert center BOD — REQ-BOD-006.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (người dùng tenant) | Tạo ticket trực tuyến với chủ đề, mô tả, nhóm vấn đề, tệp minh chứng | Báo sự cố qua kênh chính thức có truy vết, không phụ thuộc tin nhắn rời rạc |
| 2 | CUSTOMER (người dùng tenant) | Thấy trạng thái ticket và đồng hồ SLA song song GMT+7 + giờ địa phương | Tự theo dõi tiến độ so với cam kết hợp đồng, không phải hỏi lại AM |
| 3 | CUSTOMER (người dùng tenant) | Bổ sung thông tin ngay trên ticket khi nó đang chờ tôi (Pending) | Ticket quay lại luồng xử lý sớm, không bị auto-đóng vì thiếu phản hồi |
| 4 | CUSTOMER (người dùng tenant) | Được cảnh báo khi yêu cầu trùng ticket đang mở của tenant | Tránh tạo trùng, theo dõi tập trung một ticket |
| 5 | CUSTOMER (người dùng tenant) | Trả CSAT 1–5 kèm nhận xét sau khi ticket đóng, được nhắc tối đa 1 lần | Phản ánh chất lượng dịch vụ đúng lúc, không bị làm phiền nhiều lần |
| 6 | CUSTOMER (CLIENT_ADMIN của tenant) | Mở lại ticket trong 7 ngày sau khi đóng, giữ nguyên ngữ cảnh; quá hạn thì tạo ticket mới tham chiếu | Không phải kể lại sự việc, vẫn giữ truy vết khi quá hạn reopen |
| 7 | CUSTOMER (người dùng tenant) | Khiếu nại nghiêm trọng (mất tiền, sai đối soát, đạo đức nhân viên) qua kênh chính thức và thấy trạng thái "đang xử lý cấp cao" | Tin khiếu nại tới cấp có thẩm quyền (BOD trong 24h) mà không cần biết chi tiết nội bộ |
| 8 | OPS_AM | Xem timestamp gửi/đọc thông báo trên portal (tại công cụ nội bộ) | Chứng minh tuân thủ nghĩa vụ thông báo breach 30 phút |
| 9 | OPS_PLAN | Theo dõi khiếu nại nghiêm trọng đã escalate (nội bộ trên WEB) và điều phối | Bảo đảm hồ sơ đủ trước mốc leo thang BOD 24h |

> *Touchpoint: OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS là assignee xử lý trên SYS-BCERP-WEB/SYS-MOBILE-INTERNAL — không đăng nhập portal (story nằm ở file counterpart). OPS_AM là đầu mối phía BC cho tenant; OPS_PLAN điều phối escalation.*

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Nguồn gốc là BR-OPS-9.1 → 9.5 (operations.md B.9) và REQ-OPS-009 Phần A; dưới đây là phần áp dụng lên touchpoint portal. Số liệu SLA đã chốt theo DI-005.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-PT-001 | **Tenant isolation tuyệt đối:** mọi ticket, phản hồi, tệp, CSAT chỉ truy vấn theo `tenant_id` người đăng nhập; cấm hiển thị dữ liệu tenant khác và dữ liệu nội bộ BC. Enforce ở service layer của CORE trước khi trả dữ liệu cho portal. | API trả lỗi không tiết lộ sự tồn tại dữ liệu; security audit log bất biến; alert SYS_ADMIN — lộ dữ liệu là sự cố P0 |
| BR-PT-002 | **Kênh chính thức hợp nhất:** ticket từ portal vào queue hợp nhất đa kênh (portal/email/Zalo) của CORE, xếp theo khách/tier. CORE dedupe theo (khách + chủ đề + tài sản): khi trùng trả về ticket hiện có — portal hiển thị "đã gộp vào ticket #…". | Tạo trùng bị chặn ở CORE; portal không tự gộp/tách, chỉ hiển thị kết quả dedupe |
| BR-PT-003 | **Ngoài scope tự tách change request:** CORE nhận diện nội dung ngoài hợp đồng → portal báo "đã tách thành change request — không tính SLA vận hành", kèm tham chiếu hai chiều. | Cấm tính SLA vận hành cho change request; cấm tách mà khách không được thông báo |
| BR-PT-004 | **SLA theo tier, hiển thị read-only:** target FR/Res theo ma trận tier×priority (E nhanh nhất — A chậm nhất; riêng Critical 24/7 — `sla-khach-hang.md` §2.1); HĐ cam kết cao hơn → ghi đè theo profile khách, nhãn "theo hợp đồng". Mốc tính duy nhất GMT+7 (nguồn sự thật CORE), portal hiển thị song song giờ địa phương tenant. Trực Critical ngoài giờ: on-call xoay vòng SLA 4h (DI-005 đã chốt). | Mọi thao tác ghi lên clock/target từ portal bị chặn tầng API (403); sai target hiển thị là lỗi P1 |
| BR-PT-005 | **State machine chuẩn:** New → Open → Pending → Resolved → Closed (sở hữu bởi CORE). **Reopen trong 7 ngày** giữ toàn bộ ngữ cảnh; quá 7 ngày chỉ tạo ticket mới tham chiếu. | Reopen ngoài hạn bị từ chối kèm hướng dẫn tạo ticket mới; chuyển trạng thái trái máy trạng thái bị CORE chặn |
| BR-PT-006 | **Pending chờ khách:** clock pause tự động; portal nhắc theo nhịp CORE — Critical 4h rồi 12h, mức khác 24h rồi 48h LV. Sau lời nhắc thứ 2, tiếp tục 24h (Critical) / 24h LV (còn lại) không phản hồi → auto-Closed "khách không phản hồi", **không tính breach**, vẫn reopen được 7 ngày. | Cấm giấu trạng thái auto-Closed; khách phải thấy rõ lý do đóng và nút reopen trong hạn |
| BR-PT-007 | **Escalation bắt buộc (CORE sở hữu):** trigger — Critical quá First Response; chạm 100% SLA; reopen ≥2 lần; Pending quá 3 ngày LV; khiếu nại từ CLIENT_ADMIN khách Tier D/E. Chuỗi nội bộ assignee → AM → CS TL → OPS_PLAN → BOD, mỗi chặng 30 phút trong giờ trực; path cấp cao bắt buộc **AM → AD (Account Director) → BOD**. AD có mã OPS_AD đã chốt (KXN-12) nhưng chưa vào registry 18 vai — quyền cấp AD tạm gán OPS_PLAN; xác nhận RACI còn mở `[KXN-19]`, không tự quyết. | Escalation không chạy khi trigger vi phạm là lỗi P1; portal chỉ hiển thị "đang xử lý cấp cao", không lộ chuỗi/chặng nội bộ |
| BR-PT-008 | **Breach 100%:** trong 5 phút báo đỏ AM + CS TL (nội bộ); **AM thông báo khách trong 30 phút** theo template chuẩn (lý do, phương án khắc phục, ETA mới) — trên ticket kèm timestamp "đã thông báo"/"đã đọc". Không thông báo là **vi phạm riêng**, độc lập breach kỹ thuật. | Quá 30 phút → vi phạm riêng đẩy dashboard OPS_PLAN + alert center (REQ-BOD-006); timestamp bất biến |
| BR-PT-009 | **CSAT sau xử lý:** khi Closed, CORE phát khảo sát — form **1–5 + 1 câu mở**; nhắc **tối đa 1 lần sau 48h**; một CSAT/ticket. **Detractor ≤2:** liên hệ lại trong **48h làm việc**, nội dung liên hệ + hành động khắc phục gắn ticket gốc (khách chỉ thấy "đã ghi nhận — đang liên hệ lại"). Tier CSAT <4,0 hai tháng liên tiếp → review dịch vụ do OPS_PLAN chủ trì (nội bộ). | Cấm nhắc lần 2; cấm cho khách thấy CSAT tenant khác hay phân tích nội bộ theo tier |
| BR-PT-010 | **Khiếu nại nghiêm trọng** (khách Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên): leo thang **BOD trong 24h kèm hồ sơ đầy đủ**, OPS_PLAN điều phối. Khách chỉ thấy "đang xử lý cấp cao"; mất tiền/sai đối soát liên thông REQ-FIN-004 (nhãn "Đang đối soát"). | Quá 24h thiếu hồ sơ ở BOD là vi phạm P1; portal không lộ phương án khắc phục nội bộ trước khi AM thông báo chính thức |
| BR-PT-011 | **Mask + watermark:** phản hồi cho khách không chứa giá vốn, chiết khấu, margin, ghi chú nội bộ; download tệp có watermark (REQ-OPS-010). **Hành động nhạy cảm** (đổi mật khẩu, thêm user tenant, xuất dữ liệu ticket) yêu cầu thêm lớp OTP kèm audit log. | Dữ liệu nội bộ lọt tới khách là lỗi bảo mật P0 — chặn xuất bản, audit log, incident report |
| BR-PT-012 | **Tệp đính kèm:** giới hạn định dạng/dung lượng theo cấu hình; lưu trong phạm vi tenant, không chia sẻ chéo tenant; khách chỉ xóa được tệp mình tải lên trước khi có phản hồi — sau đó chỉ đọc (bảo toàn truy vết). | Tệp vượt giới hạn bị từ chối kèm thông báo rõ; xóa tệp sau phản hồi bị chặn |

---

## 4. Phân Quyền

> *Phạm vi bảng: touchpoint SYS-PORTAL-WEB. Vai nội bộ (OPS_*) thao tác trên counterpart WEB/M-INT nên hầu hết hành động portal là ❌ (ghi chú nơi làm việc thật). Khách gộp dưới vai CUSTOMER (phân CLIENT_ADMIN/CLIENT_USER phía tenant).*

| Hành động | CUSTOMER (CLIENT_ADMIN) | CUSTOMER (CLIENT_USER) | OPS_AM | OPS_PLAN | SYS_ADMIN | BOD_CEO |
|-----------|------------------------|------------------------|--------|----------|-----------|---------|
| Xem danh sách/chi tiết ticket tenant mình (trạng thái, SLA, lịch sử) | ✅ | ✅ | ❌ (xử lý trên WEB nội bộ) | ❌ (monitor trên WEB nội bộ) | ❌ (chỉ công cụ quản trị có audit) | ❌ (alert center nội bộ) |
| Tạo ticket mới trên portal | ✅ | ✅ | ❌ (tạo hộ chỉ qua email/Zalo tại CORE) | ❌ | ❌ | ❌ |
| Phản hồi/bổ sung thông tin (Pending → quay lại xử lý) | ✅ | ✅ (ticket mình tạo hoặc được mention) | ❌ (phản hồi trên WEB/M-INT) | ❌ | ❌ | ❌ |
| Đính kèm tệp / tải tệp có watermark | ✅ | ✅ (tệp mình tải lên) | ❌ | ❌ | ❌ | ❌ |
| Trả CSAT sau khi ticket Closed | ✅ | ✅ (người theo dõi ticket) | ❌ | ❌ | ❌ | ❌ |
| Reopen trong 7 ngày giữ ngữ cảnh | ✅ | ✅ (người tạo ticket) | ✅ (hộ khách theo yêu cầu chính thức, có audit) | ❌ | ❌ | ❌ |
| Xác nhận khiếu nại nghiêm trọng / leo thang BOD 24h | ❌ (chỉ khai báo nội dung khi tạo — CORE nhận diện) | ❌ | ✅ (xác nhận hồ sơ trên WEB) | ✅ (điều phối — quyền cấp AD tạm gán, chờ OPS_AD `[KXN-12]` vào registry) | ❌ | ✅ (nhận hồ sơ leo thang — alert center nội bộ) |
| Gán/đổi assignee, chuyển Resolved, ghi chú nội bộ | ❌ | ❌ | ✅ (WEB nội bộ) | ✅ (điều phối lại khi escalation) | ❌ | ❌ |
| Xem ghi chú nội bộ, phân tích CSAT theo tier, dashboard compliance | ❌ | ❌ | ✅ (WEB nội bộ) | ✅ (WEB nội bộ) | ❌ | ✅ (báo cáo tổng hợp nội bộ) |
| Sửa/xóa ticket, phản hồi, CSAT đã ghi | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ hiệu chỉnh kỹ thuật có audit khi xử lý sự cố) | ❌ |

**Quy tắc xuyên bảng:**
- Mọi ✅ của khách ràng buộc thêm bởi BR-PT-001 — quyền chỉ có ý nghĩa trong phạm vi tenant; CLIENT_ADMIN tự quản user tenant theo REQ-OPS-010 (nội bộ không tạo hộ).
- Không có nút "xóa ticket/phản hồi/CSAT": dữ liệu là bằng chứng CSKH và đầu vào KPI nhân sự (REQ-HR-007), chỉ đọc sau khi ghi.
- Quyền "điều phối khiếu nại" gán OPS_PLAN theo DI-006 (không có OPS_CX); khi registry bổ sung OPS_AD thì chuyển quyền cấp AD tương ứng — qua quản trị vai, không sửa code.

---

## 5. Trường Hợp Đặc Biệt

- **Tenant nhiều người dùng cùng một ticket:** mọi user tenant đều thấy ticket của tenant; thông báo gửi người tạo + người được mention + CLIENT_ADMIN khi event nghiêm trọng; CSAT chỉ ghi một lần/ticket dù nhiều người thấy form.
- **Trùng lặp khi tạo:** CORE trả về ticket hiện có; portal hiển thị "đã gộp" kèm link; nội dung vừa nhập được lưu như phản hồi trên ticket gốc để không mất thông tin.
- **Yêu cầu ngoài scope:** CORE tách change request; portal hiển thị liên kết hai chiều, SLA vận hành ngừng tính từ thời điểm tách; khách thấy giải thích ngắn theo template.
- **Khách không phản hồi lời nhắc Pending:** sau đủ 2 lời nhắc + thời hạn → auto-Closed "khách không phản hồi", không tính breach; portal báo rõ lý do và cho reopen 7 ngày giữ ngữ cảnh.
- **Reopen hết hạn 7 ngày:** nút reopen ẩn; portal mở sẵn form tạo ticket mới với ngữ cảnh chính (khách, chủ đề, tham chiếu ticket cũ) điền sẵn — đi queue bình thường, không kế thừa SLA clock cũ.
- **Khiếu nại mất tiền/sai đối soát:** song song leo thang BOD 24h, AM khởi tạo đối soát REQ-FIN-004; portal hiển thị nhãn "Đang đối soát"; hai luồng tham chiếu chéo nhưng vận hành độc lập.
- **Breach ngoài giờ khách:** Critical chạy clock 24/7, ca on-call xoay vòng SLA 4h ngoài giờ (DI-005) bảo đảm phản hồi; thông báo breach vẫn trong 30 phút kể từ khi breach xác định; in-app + email là kênh bảo đảm khi Zalo/Telegram không ai đọc.
- **Hành động nhạy cảm phía khách** (đổi mật khẩu, thêm user tenant, xuất dữ liệu ticket, đổi cấu hình nhận thông báo): yêu cầu lớp OTP bổ sung kèm audit log (chống chiếm dụng tài khoản portal).
- **Ánh xạ vai ngoài registry:** "CS TL" ánh xạ về OPS_AM (đầu mối SLA phía tenant), điều phối là OPS_PLAN; AD = Account Director (mã OPS_AD — KXN-12 đã chốt, chưa vào registry); không dùng OPS_CX/FIN_COMPL (DI-006).
- **Khảo sát khách định kỳ khác (Client Survey)** không thuộc CSAT sau ticket — phạm vi/kênh gửi còn mở `[KXN-15]`, không tự quyết trong spec này; spec chỉ chốt CSAT tự động sau Closed theo REQ-OPS-009.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Ticket — vòng đời sở hữu bởi SYS-CORE-BACKEND (queue hợp nhất + state machine chuẩn REQ-OPS-009); portal gửi hành động của khách và chiếu trạng thái read-only kèm đồng hồ SLA.

**Sơ đồ trạng thái:**
```
        (khách tạo trên portal / email / Zalo — CORE dedupe)
                            │
                            ▼
[NEW] ──(assignee nhận việc)──► [OPEN] ──(chuyển Resolved)──► [RESOLVED] ──(đóng vòng)──► [CLOSED]
                            │                                                    │
                            │ (chờ khách / chờ bên thứ 3)                        │ (reopen ≤7 ngày — giữ ngữ cảnh)
                            ▼                                                    ▼
                        [PENDING] ──(khách phản hồi trên portal)──► [OPEN]   [REOPENED → OPEN]
                            │
                            │ (hết 2 lời nhắc + thời hạn)
                            ▼
                   [CLOSED "khách không phản hồi"] ──(>7 ngày)──► [ticket mới tham chiếu]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| (chưa có) | Tạo ticket trên portal | `NEW` | CUSTOMER | Đủ trường bắt buộc; qua dedupe CORE (BR-PT-002) |
| `NEW` | Nhận việc | `OPEN` | Assignee OPS (WEB/M-INT — không portal) | Có assignee; bắt đầu đo First Response |
| `OPEN` | Chuyển Pending | `PENDING` | Assignee OPS | Lý do chờ khách hoặc blocked-3rd-party có case ID; clock pause |
| `PENDING` | Khách phản hồi trên portal | `OPEN` | CUSTOMER | Phản hồi ghi vào ticket; clock resume |
| `PENDING` | Hết 2 lời nhắc + hạn, không phản hồi | `CLOSED` (khách không phản hồi) | Hệ thống | Không tính breach; reopen trong 7 ngày (BR-PT-006) |
| `OPEN` | Chuyển Resolved | `RESOLVED` | Assignee OPS | Bắt buộc mô tả giải pháp (định nghĩa đo Res — BR-OPS-9.1) |
| `RESOLVED` | Đóng vòng xử lý | `CLOSED` | Assignee OPS / hệ thống | Kích hoạt CSAT tự động (BR-PT-009) |
| `CLOSED` | Reopen trong 7 ngày | `OPEN` (REOPENED) | CUSTOMER; OPS_AM (hộ khách, có audit) | Giữ toàn bộ ngữ cảnh; reopen ≥2 lần → escalation bắt buộc (BR-PT-007) |
| `CLOSED` | Tạo lại sau >7 ngày | Ticket `NEW` mới | CUSTOMER | Bắt buộc tham chiếu ticket cũ; không kế thừa SLA clock |

**Quy tắc:**
- `CLOSED` là trạng thái kết thúc: không quay lại trực tiếp sau 7 ngày — chỉ tạo ticket mới tham chiếu; reopen trong hạn là ngoại lệ duy nhất và luôn giữ ngữ cảnh.
- Mọi chuyển trạng thái do CORE thực hiện và ghi audit log bất biến (ai, khi nào, từ trạng thái nào); portal không tự chuyển trạng thái — chỉ gửi hành động khách qua API.
- Trạng thái hiển thị đồng bộ từ event bus CORE; mất kết nối → nhãn "dữ liệu chờ đồng bộ" + timestamp cập nhật cuối, không suy diễn.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `ticket` (CORE, chiếu portal) | `id`, `tenant_id`, `channel`, `subject`, `category`, `priority`, `tier_at_create`, `status`, `assignee_id`, `reopen_count`, `created_by_portal_user_id`, `dedupe_key` | FK → `tenants.id`, FK → `users.id` | Sở hữu bởi CORE; portal chỉ đọc/ghi hành động khách |
| `ticket_message` | `id`, `ticket_id`, `author_type` (`customer`/`staff`), `author_id`, `body`, `visibility` (`customer`/`internal`), `created_at` | FK → `ticket.id` | `visibility=internal` tuyệt đối không trả qua API portal (BR-PT-001/011) |
| `ticket_attachment` | `id`, `ticket_id`, `message_id`, `file_key`, `mime`, `size`, `uploaded_by`, `watermark_applied` | FK → `ticket.id`, FK → `ticket_message.id` | Lưu trong phạm vi tenant; download có watermark (REQ-OPS-010) |
| `csat_survey` | `id`, `ticket_id`, `tenant_id`, `score` (1–5), `comment`, `sent_at`, `reminded_at` (tối đa 1), `submitted_at`, `status` | FK → `ticket.id`, FK → `tenants.id` | Một CSAT/ticket; detractor ≤2 sinh follow-up gắn ticket gốc |
| `sla_clock_view` | `ticket_id`, `tenant_id`, `target_fr`, `target_res`, `target_source` (matrix/contract), `elapsed_pct`, `clock_state`, `pause_reason`, `last_synced_at` | FK → `ticket.id` | Projection read-only đồng bộ từ SLA engine REQ-OPS-008 (CORE) |
| `escalation_record` (chiếu portal mức trạng thái) | `id`, `ticket_id`, `trigger_type`, `chain_step`, `started_at`, `due_at`, `resolved_at` | FK → `ticket.id` | Chi tiết chuỗi/chặng nội bộ không lộ cho khách — portal chỉ thấy "đang xử lý cấp cao" |

> Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`; ranh giới dữ liệu chéo module (SLA, đối soát, alert center) qua event bus, không join trực tiếp chéo tenant.

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5; dưới đây là phác thảo sơ bộ map về REQ-OPS-009 (Mục 2).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Khách tạo ticket qua portal | CLIENT_USER đã kích hoạt portal (REQ-OPS-010) | Gửi form tạo ticket đủ trường bắt buộc kèm 1 tệp | Ticket vào queue hợp nhất CORE với `channel=portal`, xếp theo tier; khách thấy `NEW` + target SLA theo tier×priority song song GMT+7/giờ địa phương | [ ] |
| SC-002: Dedupe khi tạo trùng | Tenant có ticket đang mở cùng chủ đề + tài sản | Tạo ticket trùng nội dung | CORE trả ticket hiện có; portal hiển thị "đã gộp vào ticket #…"; nội dung nhập lưu như phản hồi trên ticket gốc | [ ] |
| SC-003: Khách phản hồi kéo ticket khỏi Pending | Ticket đang `PENDING` chờ khách | Khách trả lời trên portal | Ticket về `OPEN`, clock resume; phản hồi ghi lịch sử với tác giả tenant | [ ] |
| SC-004: Auto-Closed chờ khách | Ticket Pending đã qua 2 lời nhắc + thời hạn (BR-PT-006) | Hết thời hạn phản hồi | Auto-Closed "khách không phản hồi", không tính breach; khách thấy lý do + nút reopen trong 7 ngày giữ ngữ cảnh | [ ] |
| SC-005: CSAT sau Closed + nhắc 1 lần | Ticket chuyển `CLOSED` | Khách chưa trả CSAT | Form 1–5 + câu mở xuất hiện; sau 48h nhắc đúng 1 lần; trả lời thứ hai bị chặn; detractor ≤2 sinh follow-up 48h LV gắn ticket gốc | [ ] |
| SC-006: Khiếu nại nghiêm trọng leo thang | Khách Tier D tạo ticket bị nhận diện khiếu nại nghiêm trọng (mất tiền) | CORE đánh dấu + tạo hồ sơ | Leo thang BOD trong 24h kèm hồ sơ; OPS_PLAN điều phối; khách chỉ thấy "đang xử lý cấp cao" + nhãn "Đang đối soát" | [ ] |
| SC-007: Tenant isolation | User tenant A đăng nhập | Gọi API ticket/message/CSAT của tenant B (đoán ID) | API chặn, không trả dữ liệu và không tiết lộ sự tồn tại; security audit log ghi nhận | [ ] |
| SC-008: Mask nội bộ + watermark | Ticket có message `visibility=internal` | Khách tải danh sách phản hồi và 1 tệp | Phản hồi nội bộ không xuất hiện trong API portal; tệp tải về có watermark | [ ] |

> **Liên kết:** SC-001→008 map về REQ-OPS-009 (Mục 2); SC-004, SC-005 tham chiếu thêm nhịp nhắc/pause của REQ-OPS-008 (BR-OPS-9.2); SC-006 liên thông REQ-BOD-006 và REQ-FIN-004.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (portal-web/ticket-cskh) |
| API Endpoints — tạo ticket, phản hồi, CSAT, theo dõi trạng thái read-only | `technical-specs/api-contract.md` (portal-web/ticket-cskh) |
| Tích hợp xuyên hệ thống — queue hợp nhất + state machine + CSAT engine (CORE), SLA clock REQ-OPS-008, đối soát REQ-FIN-004, alert center REQ-BOD-006 | `technical-specs/integration-map.md` |
| Màn hình UI — form tạo ticket, trang chi tiết ticket + đồng hồ SLA, form CSAT | `phase4-ux/portal-web/ticket-cskh/ticket-va-cskh.md` |
| Bản counterpart — CORE (queue, state machine, CSAT engine), BCERP-WEB (assignee xử lý), MOBILE-INTERNAL (nhận việc/push escalation), MOBILE-PORTAL (rút gọn cho khách) | `phase2-features/{core-backend,bcerp-web,mobile-internal,mobile-portal}/ticket-cskh/` |
