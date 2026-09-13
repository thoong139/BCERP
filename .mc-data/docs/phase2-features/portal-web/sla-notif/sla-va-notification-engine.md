# Tính Năng: SLA & Notification Engine — Bản Client Portal (SYS-PORTAL-WEB)

> **Dựa trên:** REQ-OPS-008 trong `phase1-business/departments/operations/operations.md` (Phần A + B.9 — BR-OPS-9.1 đến BR-OPS-9.3)
> **Phân hệ:** Client Portal (SYS-PORTAL-WEB)
> **Module:** SLA & Notification (MOD-SLA-NOTIF)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 5: CSKH & SLA)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/portal-web/sla-notif/[screen-group].md`, `phase5-implementation/tasks/portal-web/sla-notif/[feat]-impl.md`

> **Fan-out note:** REQ-OPS-008 xuất hiện ở 5 systems; file này là **bản riêng cho SYS-PORTAL-WEB** — Client Portal dành cho khách hàng: chỉ hiển thị dữ liệu read-only đã được chia sẻ, **tenant isolation tuyệt đối, không lộ dữ liệu nội bộ**. Counterparts: SLA engine — SYS-CORE-BACKEND; dashboard compliance — SYS-BCERP-WEB; push on-call — SYS-MOBILE-INTERNAL; bản rút gọn di động — SYS-MOBILE-PORTAL.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-PORTAL-SLANOT-001 |
| Module | MOD-SLA-NOTIF |
| Yêu cầu nghiệp vụ | REQ-OPS-008 (liên thông: REQ-BOD-006 — alert center BOD; REQ-OPS-009 — ticket & CSKH, nguồn event; REQ-OPS-010 — cấp tài khoản portal) |
| Người dùng liên quan | CUSTOMER (khách trên portal); OPS_AM, OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (vai nội bộ — thao tác trên counterpart WEB/M-INT) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | SLA engine của REQ-OPS-008 tại SYS-CORE-BACKEND (chạy trước — portal chỉ là lớp hiển thị read-only); queue hợp nhất & state machine ticket REQ-OPS-009 (nguồn event); cấp/kích hoạt tài khoản portal REQ-OPS-010 (điều kiện truy cập) |

> *CLIENT_ADMIN/CLIENT_USER là kiểu tài khoản phía tenant, gộp dưới vai registry CUSTOMER; mọi vai nội bộ chỉ dùng 18 vai registry — không có OPS_CX/FIN_COMPL (DI-006 đã chốt gỡ).*

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Mang phần SLA & Notification Engine của REQ-OPS-008 đến phía khách hàng trên Client Portal (web, responsive browser UI): khách thấy **minh bạch** tiến độ xử lý sự kiện/ticket của mình qua đồng hồ SLA song song (mốc GMT+7 của BC và giờ địa phương khách) và **nhận thông báo kịp thời** qua đa kênh (in-app, email, Zalo/Telegram tùy cấu hình) — chỉ event của tenant mình. SLA từ cam kết hợp đồng trừu tượng trở thành dữ liệu khách tự theo dõi, đồng thời tạo bằng chứng thông báo khi có sự cố.

**Phạm vi:**
- Bao gồm:
  - Hiển thị **read-only** đồng hồ SLA (target First Response/Resolution, % thời lượng đã dùng, trạng thái chạy/tạm dừng) cho ticket/sự kiện của tenant — nguồn sự thật là SLA clock của SYS-CORE-BACKEND, portal chỉ chiếu qua event bus.
  - **Notification center in-app** trên portal + đẩy đa kênh (email, Zalo/Telegram) theo cấu hình tenant, kèm trạng thái gửi/đọc.
  - Cho khách **khai báo lịch làm việc riêng** (khung giờ, ngày nghỉ, múi giờ) — clock mức High/Medium/Low của CORE tính theo lịch đó.
  - Nhận **lời nhắc khi ticket Pending (chờ khách)** và **thông báo breach** từ AM (template chuẩn: lý do, phương án khắc phục, ETA mới) với timestamp.
  - Enforce **tenant isolation tuyệt đối**: mọi truy vấn lọc theo tenant của người đăng nhập; không hiển thị dữ liệu tenant khác hay nội bộ BC.
- Không bao gồm:
  - Tính toán SLA clock, pause/resume, escalation, override/gia hạn — thuộc SYS-CORE-BACKEND (bản REQ-OPS-008 của CORE); dashboard compliance nội bộ — SYS-BCERP-WEB; push pre-alert/breach cho assignee/AM/CS TL và duyệt gia hạn di động — SYS-MOBILE-INTERNAL.
  - Alert center BOD — thuộc REQ-BOD-006 (MOD-DATAHUB-BI); portal chỉ liên thông event, không hiển thị chi tiết nội bộ.
  - Queue hợp nhất, state machine ticket, CSAT logic — thuộc REQ-OPS-009 (portal chỉ nhận event để thông báo).
  - Bản touchpoint rút gọn trên di động cho khách — thuộc SYS-MOBILE-PORTAL (counterpart).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (người dùng tenant) | Xem đồng hồ SLA của từng ticket/sự kiện của tenant mình, song song GMT+7 và giờ địa phương | Biết tiến độ xử lý so với cam kết hợp đồng, không phải hỏi lại AM |
| 2 | CUSTOMER (người dùng tenant) | Nhận thông báo qua in-app portal và email/Zalo/Telegram theo kênh tôi bật, chỉ event của tenant tôi | Được báo kịp thời, không nhận nhiễu từ khách khác của BC |
| 3 | CUSTOMER (CLIENT_ADMIN của tenant) | Khai báo lịch làm việc riêng của công ty (khung giờ, ngày nghỉ, múi giờ) | SLA các sự kiện High/Medium/Low tính theo lịch thực tế, không bị breach lúc công ty nghỉ |
| 4 | CUSTOMER (người dùng tenant) | Nhận lời nhắc rõ ràng khi ticket đang chờ phản hồi của tôi (Pending) | Trả lời đúng hạn, tránh ticket bị tự đóng "khách không phản hồi" |
| 5 | CUSTOMER (người dùng tenant) | Nhận thông báo breach từ AM đúng template (lý do, phương án khắc phục, ETA mới) trên portal và kênh đã cấu hình | Chủ động phối hợp xử lý, không phát hiện trễ qua khiếu nại |
| 6 | CUSTOMER (CLIENT_ADMIN của tenant) | Bật/tắt và xác thực kênh nhận thông báo mức tenant, chỉnh sở thích nhận ở mức cá nhân | Kiểm soát kênh liên lạc chính thức giữa BC và công ty tôi |
| 7 | OPS_AM | Xác nhận thông báo breach đã gửi tới khách (portal ghi timestamp gửi + đã đọc) | Chứng minh tuân thủ nghĩa vụ "thông báo khách trong 30 phút" — không thông báo là vi phạm riêng |

> *Touchpoint: các vai OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS, OPS_PLAN là nguồn phát event (giao việc, cập nhật ticket) nhưng thao tác trên SYS-BCERP-WEB/SYS-MOBILE-INTERNAL — không đăng nhập portal; story liên quan nằm ở file feature counterpart.*

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Nguồn quy tắc SLA gốc là BR-OPS-9.1 → 9.3 (operations.md B.9); dưới đây là phần áp dụng lên touchpoint portal.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-PN-001 | **Tenant isolation tuyệt đối:** mọi notification, đồng hồ SLA, lịch làm việc chỉ truy vấn theo `tenant_id` của người đăng nhập; không hiển thị event của tenant khác hay dữ liệu nội bộ BC (giá vốn, chi phí, dashboard compliance). Enforce ở tầng service của CORE trước khi trả dữ liệu cho portal. | API trả lỗi truy cập (không tiết lộ sự tồn tại dữ liệu tenant khác); security audit log bất biến; alert cho SYS_ADMIN |
| BR-PN-002 | **Đồng hồ SLA hiển thị read-only song song:** mốc tính duy nhất GMT+7 (nguồn sự thật CORE), portal hiển thị kèm giờ địa phương tenant (từ lịch/múi giờ khai báo). Không có thao tác nào từ portal sửa được clock, target hay trạng thái pause. | Mọi yêu cầu ghi lên đồng hồ bị chặn tầng API (403); dữ liệu chỉ refresh từ event bus CORE |
| BR-PN-003 | **Ma trận tier×priority là target hiển thị:** Tier E nhanh nhất — Tier A chậm nhất; riêng Critical chạy 24/7 (nguồn `sla-khach-hang.md` §2.1). Hợp đồng cam kết cao hơn → ghi đè theo profile khách; portal hiển thị target theo profile, gắn nhãn "theo hợp đồng". | Hiển thị sai target là lỗi P1; profile sai căn cứ hợp đồng bị chặn cấu hình |
| BR-PN-004 | **Trực Critical ngoài giờ:** ca trực Critical là **on-call xoay vòng, SLA phản hồi 4h ngoài giờ làm việc** (DI-005 đã chốt — thay desk 24/7); portal hiển thị cho khách cam kết "phản hồi tối đa 4 giờ ngoài giờ" cho sự kiện Critical, trong khi đồng hồ 24/7 vẫn chạy thật theo ma trận. | Cấm hiển thị "24/7 có người trực" — cam kết hiển thị khớp chế độ on-call đã chốt |
| BR-PN-005 | **Lịch làm việc khách:** lịch khai báo trên portal chỉ làm clock mức **High/Medium/Low** tính theo lịch đó; **Critical vẫn 24/7**. Thay đổi lịch có hiệu lực cho ticket phát sinh/clock chưa breach sau thời điểm lưu — **không hồi tố**; mọi thay đổi ghi audit log (ai, khi nào, cũ/mới). | Sửa lịch để "xóa" breach đã xảy ra bị chặn; portal cảnh báo "lịch mới áp dụng từ thời điểm lưu" |
| BR-PN-006 | **Pause & lời nhắc chờ khách:** khi ticket Pending, portal gửi lời nhắc theo nhịp CORE — Critical sau 4h rồi 12h; mức khác sau 24h rồi 48h LV. Sau lời nhắc thứ 2, tiếp tục 24h (Critical) / 24h LV (còn lại) không phản hồi → auto-Closed "khách không phản hồi", **không tính breach**, reopen trong 7 ngày. Blocked-3rd-party: pause kèm case ID platform, tối đa 5 ngày LV, quá hạn tự escalate AM. | Cấm gửi lời nhắc sai nhịp hay giấu trạng thái auto-Closed; reopen ngoài 7 ngày tạo ticket mới tham chiếu (REQ-OPS-009) |
| BR-PN-007 | **Thông báo breach cho khách:** chạm 100% SLA → trong **5 phút** báo đỏ AM + CS TL (nội bộ, M-INT/WEB); **AM thông báo khách trong 30 phút** theo template chuẩn (lý do, phương án khắc phục, ETA mới) — in-app trên portal + kênh tenant đã bật; portal ghi timestamp "đã thông báo"/"đã đọc". **Không thông báo là vi phạm riêng**, độc lập breach kỹ thuật. | Quá 30 phút → vi phạm riêng, đẩy dashboard OPS_PLAN + alert center (REQ-BOD-006); timestamp không sửa/xóa được |
| BR-PN-008 | **Notification đa kênh theo cấu hình:** in-app luôn bật, không tắt được; email/Zalo/Telegram chỉ hoạt động khi tenant bật **và kênh đã xác thực** (verify địa chỉ/token). Gửi thất bại → retry có backoff, rồi fallback in-app + email (nếu bật) + cảnh báo SYS_ADMIN. Mỗi notification ghi trạng thái: queued → sent → delivered → read (hoặc failed). | Kênh chưa verify không nhận thông báo; mất thông báo không có fallback là lỗi nghiệm thu |
| BR-PN-009 | **Chỉ event của tenant mình:** portal chỉ phát/hiển thị notification có `tenant_id` khớp người nhận; dedupe theo `dedupe_key` (khách + chủ đề + tài sản) chống trùng lặp. Sự kiện nghiêm trọng (khiếu nại khách Tier D/E, mất tiền, sai sót đối soát) đi vào **alert center BOD** (REQ-BOD-006) ở mảng nội bộ — portal khách chỉ nhận thông báo chính thức do AM/OPS phát. | Nhận thông báo của tenant khác là sự cố bảo mật P0: chặn ngay, audit log, incident report; trùng lặp bị dedupe |
| BR-PN-010 | **Mask dữ liệu nhạy cảm:** thông báo liên quan ví/đối soát hiển thị với nhãn trung tính (ví dụ "điều chỉnh đối soát") — không kèm giá vốn, margin hay số liệu nội bộ; chi tiết tài chính chỉ theo feature chia sẻ read-only của portal (REQ-OPS-010). | Giá vốn/dữ liệu nội bộ lọt vào notification là lỗi bảo mật P0 — chặn xuất bản, audit log |
| BR-PN-011 | **Override/gia hạn SLA** (CS TL lần 1 ≤50% target; OPS_PLAN lần 2; BOD miễn theo đợt) bắt buộc lý do + audit log bất biến ở mảng nội bộ. Portal chỉ hiển thị **ETA mới đã duyệt**; chi tiết override nội bộ không lộ cho khách. Chuỗi thẩm quyền theo BR-OPS-9.3 hiện hành — xác nhận RACI chính thức còn mở `[KXN-19]`, không tự quyết thay thế. | Portal lộ chi tiết override nội bộ là lỗi phân quyền; ETA hiển thị khác ETA duyệt là lỗi dữ liệu P1 |

---

## 4. Phân Quyền

> *Phạm vi bảng: touchpoint SYS-PORTAL-WEB. Vai nội bộ (OPS_*) thao tác trên counterpart WEB/M-INT nên hầu hết hành động portal là ❌ (ghi chú nơi làm việc thật). Chỉ dùng 18 vai registry; khách gộp dưới vai CUSTOMER (phân kiểu tài khoản CLIENT_ADMIN/CLIENT_USER phía tenant).*

| Hành động | CUSTOMER (CLIENT_ADMIN) | CUSTOMER (CLIENT_USER) | OPS_AM | OPS_PLAN | SYS_ADMIN | BOD_CEO |
|-----------|------------------------|------------------------|--------|----------|-----------|---------|
| Xem đồng hồ SLA & notification center của tenant mình | ✅ | ✅ | ❌ (xử lý trên WEB nội bộ) | ❌ (compliance trên WEB nội bộ) | ❌ (chỉ công cụ quản trị có audit) | ❌ (alert center nội bộ — REQ-BOD-006) |
| Khai báo/sửa lịch làm việc tenant (ảnh hưởng clock High/Medium/Low) | ✅ | ❌ | ❌ (hỗ trợ hướng dẫn) | ❌ | ✅ (hiệu chỉnh hộ có yêu cầu chính thức, có audit) | ❌ |
| Bật/xác thực kênh nhận thông báo mức tenant (email/Zalo/Telegram) | ✅ | ❌ | ❌ | ❌ | ✅ (cấu hình & verify) | ❌ |
| Chỉnh sở thích nhận thông báo cá nhân (loại event, kênh trong phạm vi tenant) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gửi thông báo breach/khắc phục tới khách (template 30 phút) | ❌ | ❌ | ✅ | ✅ (điều phối khi AM không khả dụng) | ❌ | ❌ |
| Xem trạng thái gửi/đọc (delivery/read receipt) của thông báo tới tenant mình | ❌ | ❌ | ✅ (tenant mình phụ trách) | ✅ (tổng hợp compliance) | ✅ (vận hành, có audit) | ❌ (qua báo cáo nội bộ) |
| Sửa/xóa thông báo đã phát hành | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Cấu hình loại event & template thông báo toàn hệ thống | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ (duyệt thay đổi template chuẩn) |

**Quy tắc xuyên bảng:**
- Mọi hành động ✅ đều ràng buộc thêm bởi BR-PN-001 (tenant isolation) — quyền ✅ chỉ có ý nghĩa trong phạm vi tenant của người dùng.
- Không có nút "xóa lịch sử thông báo": dữ liệu thông báo là bằng chứng tuân thủ SLA, chỉ đọc sau khi phát hành (audit log bất biến).
- Template thông báo chuẩn (gồm template breach 30 phút): SYS_ADMIN thay đổi kỹ thuật, BOD_CEO duyệt nội dung.

---

## 5. Trường Hợp Đặc Biệt

- **Tenant đa múi giờ/nhiều địa điểm:** lịch khai báo theo một múi giờ chính của tenant; đồng hồ song song GMT+7 + múi giờ tenant. Lịch khác theo địa điểm là nhu cầu mở — ghi nhận là hạn chế hiện tại, không tự sinh lịch nhiều lớp `[KXN-9]` (chưa chốt, không tự quyết).
- **Kênh Zalo/Telegram mất xác thực giữa chừng** (token hết hạn, webhook lỗi): kênh tạm ngừng, retry có backoff rồi fallback in-app + email (nếu bật); SYS_ADMIN và CLIENT_ADMIN được cảnh báo verify lại; kênh hiển thị "chưa xác thực".
- **Khách không phản hồi lời nhắc Pending:** sau đủ 2 lời nhắc + thời hạn (BR-PN-006), ticket auto-Closed "khách không phản hồi" — không tính breach cho BC; portal thông báo rõ và cho reopen 7 ngày giữ ngữ cảnh (REQ-OPS-009).
- **Tenant nhiều người dùng:** notification gửi tới người nhận liên quan ticket (người tạo, người mention, CLIENT_ADMIN nếu event nghiêm trọng) + theo sở thích cá nhân; dedupe theo `dedupe_key` tránh phát trùng.
- **Breach ngoài giờ khách:** Critical — đồng hồ 24/7 vẫn chạy, ca on-call xoay vòng (SLA 4h ngoài giờ — DI-005) bảo đảm phản hồi; thông báo breach vẫn trong 30 phút kể từ khi breach xác định; in-app/email bảo đảm khi Zalo/Telegram không ai đọc.
- **Hợp đồng cam kết cao hơn ma trận:** target hiển thị theo profile khách (ghi đè) gắn nhãn "theo hợp đồng"; gia hạn hợp đồng → cập nhật theo profile mới từ thời điểm hiệu lực, không hồi tố breach đã ghi.
- **Hành động nhạy cảm phía khách** (thêm user tenant, xuất dữ liệu, đổi mật khẩu, đổi cấu hình kênh nhận thông báo): yêu cầu lớp xác nhận bổ sung (re-auth/OTP), kèm audit log.
- **Vai nội bộ:** không dùng OPS_CX/FIN_COMPL (DI-006 — stakeholder đã gỡ); "CS TL" trong quy trình gốc map về OPS_AM (đầu mối SLA), điều phối là OPS_PLAN; BOD oversight qua REQ-BOD-006.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Thông báo (Notification) — vòng đời phía portal. Đồng hồ SLA hiển thị kèm trạng thái chiếu read-only từ CORE: `ON_TRACK` → `PRE_ALERT_80` → `BREACH_100` → `CUSTOMER_NOTIFIED` → `RESOLVED`; trạng thái do CORE sở hữu, portal không chuyển đổi.

**Sơ đồ trạng thái:**
```
[QUEUED] ──(dispatch)──► [SENT] ──(ack kênh)──► [DELIVERED] ──(mở/xem)──► [READ]
   │                        │
   │ (lỗi gửi, hết retry)   │ (retry có backoff)
   ▼                        ▼
[FAILED] ◄───────────── [RETRYING] ──(fallback in-app/email)──► [SENT]
   │
   └──(hết hạn sự kiện, ví dụ ticket đã Closed trước khi gửi)──► [EXPIRED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `QUEUED` | Dispatch theo nhịp kênh | `SENT` | Hệ thống | Kênh đã verify; `tenant_id` khớp người nhận (BR-PN-009) |
| `SENT` | Retry khi kênh lỗi | `RETRYING` | Hệ thống | Retry có backoff, không vượt số lần cấu hình |
| `RETRYING` | Gửi lại thành công | `SENT` | Hệ thống | Ghi số lần thử + mã lỗi các lần trước |
| `RETRYING` | Hết retry → fallback | `FAILED` | Hệ thống | Fallback in-app + email (nếu bật); cảnh báo SYS_ADMIN + CLIENT_ADMIN |
| `SENT`/`DELIVERED` | Người nhận mở notification | `READ` | Người nhận tenant | Ghi timestamp đọc — không sửa được |
| `QUEUED` | Sự kiện gốc đã kết thúc (ticket Closed/thay thế) | `EXPIRED` | Hệ thống | Ghi lý do hết hạn; không gửi ra kênh ngoài |

**Quy tắc:**
- `READ` và `FAILED`/`EXPIRED` là trạng thái kết thúc — không quay lại; mọi chuyển trạng thái ghi audit log bất biến.
- Không ai (kể cả SYS_ADMIN) sửa/xóa notification đã phát hành — chỉ phát notification bổ sung/khắc phục.
- Trạng thái SLA hiển thị (`PRE_ALERT_80`, `BREACH_100`, …) mirror từ CORE — mất kết nối event bus thì portal hiện nhãn "dữ liệu chờ đồng bộ" + timestamp cập nhật cuối, không tự suy diễn.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `notification` | `id`, `tenant_id`, `recipient_user_id`, `event_type`, `event_ref`, `dedupe_key`, `channel`, `status`, `sent_at`, `read_at`, `payload_masked` | FK → `tenants.id`, FK → `users.id`, `event_ref` → ticket/điều chỉnh ví/CSAT | Bất biến sau phát hành; chỉ thêm, không sửa/xóa |
| `tenant_notification_channel` | `tenant_id`, `channel_type` (`in_app`/`email`/`zalo`/`telegram`), `endpoint`, `verify_token`, `verified_at`, `enabled` | FK → `tenants.id` | `in_app` luôn bật; kênh ngoài phải có `verified_at` |
| `tenant_working_calendar` | `tenant_id`, `timezone`, `day_of_week`, `open_time`, `close_time`, `holidays[]`, `effective_from` | FK → `tenants.id` | CORE đọc qua service tính clock High/Medium/Low; không hồi tố (BR-PN-005) |
| `sla_clock_view` | `ticket_id`, `tenant_id`, `target_fr`, `target_res`, `target_source` (matrix/contract), `elapsed_pct`, `clock_state`, `pause_reason`, `last_synced_at` | FK → `ticket.id`, FK → `tenants.id` | Projection read-only đồng bộ từ event bus của SYS-CORE-BACKEND |
| `tenant_user_notification_preference` | `user_id`, `event_type`, `channel_opt_in`, `updated_at` | FK → `users.id` | Trong phạm vi kênh tenant đã bật; mặc định theo cấu hình tenant |

> Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`; ranh giới dữ liệu chéo module (ticket, ví) qua event bus, không join trực tiếp chéo tenant.

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5; dưới đây là phác thảo sơ bộ map về REQ-OPS-008 (Mục 2).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đồng hồ song song theo tier | Khách Tier E, ticket Critical đang chạy | Mở trang chi tiết ticket trên portal | Target FR 15 phút / Res 4 giờ, chú thích "Critical 24/7", song song GMT+7 và giờ địa phương tenant; chỉ đọc | [ ] |
| SC-002: Lịch làm việc khách ảnh hưởng clock | Tenant khai báo lịch T2–T6 8:30–17:30 (GMT+8) | Tạo ticket mức High sau thời điểm lưu lịch | CORE tính clock theo lịch mới cho ticket phát sinh sau đó; Critical vẫn 24/7; portal cảnh báo "áp dụng từ thời điểm lưu" | [ ] |
| SC-003: Thông báo breach trong 30 phút | Ticket của tenant chạm 100% SLA | Breach được xác nhận | Khách nhận in-app + kênh đã bật với lý do/phương án/ETA mới; portal ghi timestamp "đã thông báo"/"đã đọc"; quá 30 phút → vi phạm riêng đẩy OPS_PLAN + alert center | [ ] |
| SC-004: Tenant isolation | User tenant A đang đăng nhập | Gọi API notification/clock của tenant B (đoán ID) | API chặn, không trả dữ liệu và không tiết lộ sự tồn tại; security audit log ghi nhận | [ ] |
| SC-005: Auto-Closed chờ khách | Ticket Pending đã qua 2 lời nhắc + thời hạn | Hết thời hạn phản hồi theo BR-PN-006 | Auto-Closed "khách không phản hồi", khách nhận thông báo, không tính breach; reopen trong 7 ngày giữ ngữ cảnh | [ ] |
| SC-006: Fallback kênh lỗi | Zalo channel của tenant mất xác thực | Notification được phát | Retry → fallback in-app + email; trạng thái kênh "chưa xác thực"; SYS_ADMIN và CLIENT_ADMIN nhận cảnh báo verify lại | [ ] |

> **Liên kết:** SC-001/002/003/004/005 → REQ-OPS-008; SC-005 (khía cạnh reopen) và queue/ticket tham chiếu REQ-OPS-009.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (portal-web/sla-notif) |
| API Endpoints — notification center, cấu hình kênh, đồng hồ read-only | `technical-specs/api-contract.md` (portal-web/sla-notif) |
| Tích hợp xuyên hệ thống — event bus từ CORE SLA engine, alert center REQ-BOD-006, event ticket REQ-OPS-009 | `technical-specs/integration-map.md` |
| Màn hình UI — notification center, đồng hồ SLA, cấu hình lịch/kênh | `phase4-ux/portal-web/sla-notif/notification-center.md` |
| Bản counterpart — CORE (SLA engine), BCERP-WEB (dashboard compliance), MOBILE-INTERNAL (push on-call), MOBILE-PORTAL (rút gọn) | `phase2-features/{core-backend,bcerp-web,mobile-internal,mobile-portal}/sla-notif/` |
