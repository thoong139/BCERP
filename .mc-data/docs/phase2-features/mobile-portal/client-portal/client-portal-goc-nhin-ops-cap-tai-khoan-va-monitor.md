# Tính Năng: Client Portal góc nhìn ops — cấp tài khoản & monitor (Mobile BC Portal)

> **Dựa trên:** REQ-OPS-010 trong `phase1-business/departments/operations/operations.md` (Phần A — Mục REQ-OPS-010; Phần B — B.5, BR-OPS-5.1→5.5); cross-dependency REQ-FIN-017 trong `phase1-business/departments/finance/finance.md` (dữ liệu ví read-only cho Client Portal)
> **Phân hệ:** Mobile App — BC Portal (SYS-MOBILE-PORTAL)
> **Module:** Client Portal (MOD-CLIENT-PORTAL)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md` (B.5), `phase1-business/departments/finance/finance.md` (REQ-FIN-017, BR-FIN-603/605), `phase1-business/P1-02-business-workflow.md` (Luồng 1 — GATE Day 14; Luồng 2 — ví read-only; Luồng 3 — nghiệm thu; Luồng 5 — ticket/CSAT)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-portal/client-portal/*.md`, `phase5-implementation/tasks/mobile-portal/client-portal/feat-mpo-cport-001-impl.md`

> **Hướng dẫn ID:** REQ-OPS-010 fan-out ra 5 systems; file này là bản riêng cho touchpoint **SYS-MOBILE-PORTAL**, FEAT-ID lane: **FEAT-MPO-CPORT-001**. Counterparts: SYS-CORE-BACKEND (FEAT-CORE-CPORT-002 — provisioning, gate engine, tenant isolation; FEAT-CORE-CPORT-001 — ví read-only), SYS-BCERP-WEB (FEAT-ERP-CPORT-001 — AM cấp tài khoản + monitor), SYS-MOBILE-INTERNAL (push cho AM), SYS-PORTAL-WEB (FEAT-PORTAL-CPORT-001/002 — Portal Web đầy đủ). Mobile BC Portal là **touchpoint rút gọn** của Portal dành cho khách hàng: thông báo, phê duyệt nhẹ (phi tài chính), xem số dư/tiến độ — phần tài chính **read-only tuyệt đối**.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MPO-CPORT-001 |
| Module | MOD-CLIENT-PORTAL |
| Yêu cầu nghiệp vụ | [REQ-OPS-010 (chính — cấp tài khoản & monitor), REQ-FIN-017 (cross-dependency — ví read-only, dùng chung view với Portal Web)] |
| Người dùng liên quan | CUSTOMER (CLIENT_ADMIN, CLIENT_USER — nhóm duy nhất đăng nhập mobile portal); OPS_AM, OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS phối hợp phía nội bộ (WEB/M-INT), không có tài khoản trên mobile portal |
| Độ ưu tiên | Cao (HIGH — Bắt buộc) |
| Giai đoạn | Giai đoạn 3 (GĐ3) |
| Phụ thuộc | FEAT-MPO-WALLET-001 (màn ví read-only trên mobile — nội dung bắt buộc của tiêu chí "khách tự xem được số dư" ở gate Day 14); view ví lọc tenant theo REQ-FIN-017 do CORE cung cấp (FEAT-PORTAL-CPORT-001 dùng chung); counterpart CORE FEAT-CORE-CPORT-002 (provisioning, gate engine, tenant isolation); queue ticket hợp nhất REQ-OPS-009; push AM trên SYS-MOBILE-INTERNAL |
| Ghi chú Expert (A7) | Mục A7 trong `operations.md` đang chờ expert review chính thức — chưa có điều chỉnh A7 nào áp dụng cho REQ-OPS-010 tại thời điểm viết |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa touchpoint rút gọn của Client Portal lên điện thoại của khách: nhận invite, kích hoạt tài khoản với 2FA, sau đó hằng ngày mở app để xem số dư ví tham chiếu, chi tiêu daily, tiến độ nghiệm thu, nhận push và xử lý việc nhẹ (ticket, CSAT, confirm nghiệm thu, CLIENT_ADMIN quản lý portal user). Tính năng phục vụ trụ cột "minh bạch dữ liệu khách qua Client Portal multi-tenant" và gate Day 14 của onboarding — khách kích hoạt portal thành công là điều kiện nghiệm thu giai đoạn onboarding, và mobile là kênh đo adoption tự nhiên vì luôn bên người của khách.

**Phạm vi:**
- Bao gồm: nhận invite + kích hoạt + bật 2FA trên app cho CLIENT_ADMIN/CLIENT_USER; trạng thái kích hoạt/login ghi log realtime về CORE để WEB nội bộ theo dõi mốc Day 1/7/14/30.
- Bao gồm: màn tổng hợp rút gọn — số dư ví tham chiếu + chi tiêu daily (view read-only REQ-FIN-017, dùng chung FEAT-MPO-WALLET-001), tiến độ nghiệm thu theo milestone, lịch nạp (đã thực hiện + kế hoạch cam kết), kèm nhãn nguồn + timestamp độ trễ.
- Bao gồm: push + in-app (phản hồi ticket, nghiệm thu chờ confirm) với deep-link sau đăng nhập 2FA; ticket (tạo, theo dõi, CSAT); confirm nghiệm thu nhẹ; CLIENT_ADMIN tự quản portal user trong hạn mức với lớp OTP cho hành động nhạy cảm; đa ngôn ngữ/múi giờ; tenant switcher cho khách đa pháp nhân.
- Không bao gồm: mọi thao tác ghi dữ liệu tài chính (lệnh nạp, điều chỉnh ví, duyệt giải ngân) — chỉ tồn tại trên WEB nội bộ.
- Không bao gồm: provisioning/gate engine, tenant isolation hạ tầng — SYS-CORE-BACKEND; màn AM + dashboard adoption — SYS-BCERP-WEB; push tới AM — SYS-MOBILE-INTERNAL; queue hợp nhất ticket + SLA clock + CSAT engine — REQ-OPS-009 (mobile chỉ là điểm tiếp nhận); giám sát TikTok Shop/GMV — REQ-OPS-011 không có bản portal theo mặc định.

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint **SYS-MOBILE-PORTAL** là app di động dành riêng cho khách hàng — bản rút gọn của Portal Web, tối ưu cho "mở ra nhìn 30 giây" (số dư, thông báo, trạng thái ticket) và "xử lý việc nhẹ" (confirm, trả lời). Mọi dữ liệu là machine-state đọc từ CORE qua view đã lọc tenant; app không tự tính số và không hỗ trợ thao tác ghi khi offline.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (CLIENT_ADMIN) | Nhận invite, tự kích hoạt và bật 2FA ngay trên app trong ngày đầu onboarding | Hoàn thành mốc Day 1 không cần ngồi máy tính |
| 2 | CUSTOMER (CLIENT_USER) | Mở app là thấy số dư ví tham chiếu từng TKQC, chi tiêu daily và lịch nạp, kèm thời điểm cập nhật | Nắm tình trạng mỗi ngày, không phải hỏi AM |
| 3 | CUSTOMER (CLIENT_USER) | Nhận push khi ticket của tôi có phản hồi hoặc cần bổ sung thông tin | Phản hồi đúng nhịp, không để ticket chờ quá SLA |
| 4 | CUSTOMER (CLIENT_USER) | Confirm nghiệm thu milestone ngay trên điện thoại | Dự án không dừng vì tôi đang di chuyển |
| 5 | CUSTOMER (CLIENT_USER) | Tạo ticket/comment và trả CSAT sau khi ticket Closed trên app | Vấn đề vào queue hợp nhất có vết, không thất lạc |
| 6 | CUSTOMER (CLIENT_ADMIN) | Thêm/thu hồi portal user trong hạn mức, xác minh bằng OTP | Chủ động khi nhân sự khách vào/ra, không chờ BC |
| 7 | OPS_AM | Thấy trạng thái kích hoạt/login portal user phản ánh realtime về WEB nội bộ, nhận push trượt mốc qua M-INT | Theo dõi Day 7 (≥80% kích hoạt, 2FA 100%) và can thiệp trước gate Day 14 |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer xử lý đúng trong code. Enforcement chính ở service layer SYS-CORE-BACKEND; mobile portal chỉ hiển thị và tiếp nhận hành động hợp lệ. Nguồn: operations.md B.5 (BR-OPS-5.1→5.5), finance.md REQ-FIN-017 (BR-FIN-603/605), P1-02 Luồng 1/2/3/5.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Nội dung touchpoint rút gọn:** app chỉ hiển thị số dư ví read-only theo TKQC (REQ-FIN-017 — FEAT-MPO-WALLET-001), chi tiêu daily theo TK/campaign, tiến độ nghiệm thu theo milestone, ticket của chính khách, lịch nạp. | Hiển thị nhóm dữ liệu khác → payload vi phạm ranh giới tầng API; chặn + audit |
| BR-002 | **Ví read-only tuyệt đối** (REQ-FIN-017): app không có thao tác ghi nào vào dữ liệu tài chính; mọi thay đổi số dư chỉ do nội bộ theo policy ví trên WEB. | Nút ghi tài chính trên mobile portal là lỗi kiến trúc P0 — loại bỏ, không thêm "shortcut tiện lợi" |
| BR-003 | **Tenant isolation tuyệt đối:** RLS DB + filter `tenant_id` tầng API (2 lớp), Portal API Gateway riêng tách network zone, chỉ đọc view tổng hợp đã lọc; mỗi pháp nhân/nhãn hàng 1 tenant riêng; tenant switcher chỉ liệt kê tenant được gán. | Truy cập chéo tenant → 403 tầng service + log cảnh báo bảo mật |
| BR-004 | **Không lộ dữ liệu nội bộ:** giá vốn, chiết khấu, P&L, tỷ giá nội bộ, ghi chú nội bộ, health score/churn, PII nhân sự, KYC/UBO không có trong payload mobile (mask ở tầng API CORE — BR-FIN-603); mục điều chỉnh gắn giá vốn hiển thị mask "điều chỉnh đối soát". | Payload chứa trường nội bộ → sự cố rò rỉ dữ liệu đối ngoại; UI không tự ẩn thay backend |
| BR-005 | **Disclaimer độ trễ + timestamp bắt buộc:** số dư kèm nhãn "số dư tham chiếu; số chính thức theo đối soát cuối ngày", độ trễ 15 phút–24h tùy nền tảng; chi tiêu daily 3–24h (có thể điều chỉnh hồi tố theo timezone platform); tiến độ/ticket/lịch nạp realtime; số tranh chấp hiển thị "Đang đối soát" + số tham chiếu. | Thiếu freshness metadata → component không render; cấm hiện số không kèm thời điểm |
| BR-006 | **Gate Day 14 đo từ dữ liệu thực:** PASS khi khách tự xem được số dư + chi tiêu + ticket và có ≥1 login/tuần từ ≥2 user (tính từ activation/login của cả Portal Web lẫn mobile — cùng tenant, cùng đối tượng đo); trượt → escalate root cause lên CS TL trong 24h, kế hoạch khắc phục có owner + deadline; gate là điều kiện nghiệm thu onboarding. | Cấm chốt gate tay trái dữ liệu; trượt không escalate 24h → vi phạm SLA onboarding |
| BR-007 | **Milestone Day 1/7/14/30:** Day 1 — AM tạo CLIENT_ADMIN đầu tiên + gửi invite (WEB → CORE provisioning, khách kích hoạt trên portal/mobile); Day 7 — ≥80% kích hoạt, 2FA 100%; Day 14 — GATE (BR-006); Day 30 — review adoption; app chỉ phản ánh cho khách trạng thái tài khoản của chính user. | Thiếu dữ kiện mốc → tracking gate thiếu; không hiện ngưỡng/escalate nội bộ cho khách |
| BR-008 | **Portal user do CLIENT_ADMIN tự quản:** nội bộ/SYS_ADMIN không tạo hộ; thêm/thu hồi CLIENT_USER trong hạn mức hợp đồng (mặc định 2 CLIENT_ADMIN + 10 CLIENT_USER, mở rộng theo tier); cấp/thu hồi CLIENT_ADMIN do AM đề xuất + xác nhận danh tính POC trong 1 ngày làm việc; mobile là kênh CLIENT_ADMIN thực hiện, cùng quy tắc với web. | Tạo hộ/vượt hạn mức → chặn tầng service "Vượt hạn mức theo hợp đồng, liên hệ AM"; thu hồi CLIENT_ADMIN thiếu xác nhận POC → audit fail |
| BR-009 | **Bảo mật truy cập:** 2FA/OTP bắt buộc khi kích hoạt và đăng nhập; session timeout; khóa sau 5 lần sai mật khẩu; hành động nhạy cảm (thêm user, xuất dữ liệu, đổi mật khẩu) thêm một lớp OTP; push chỉ chứa tiêu đề loại sự kiện, không nhúng số liệu tài chính — nội dung mở qua deep-link sau 2FA. | Không 2FA → từ chối đăng nhập; sai 5 lần → khóa tự động, mở khóa sau xác minh danh tính |
| BR-010 | **Ticket vào queue hợp nhất** (REQ-OPS-009): CORE dedupe theo khách/tier, ngoài scope tự tách change request; AM nhận push M-INT; SLA tier×priority, đồng hồ song song giờ địa phương khách và GMT+7; khiếu nại nghiêm trọng (Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên) leo thang BOD trong 24h kèm hồ sơ, OPS_PLAN điều phối. | Ticket không vào queue hợp nhất → thất lạc SLA; khiếu nại quá 24h → escalate BOD trực tiếp |
| BR-011 | **Watermark + log download:** tệp tải từ app dán watermark tên user + thời điểm, ghi `portal_download_log` bất biến; khách phản đối số liệu → AM khởi tạo đối soát, app hiển thị "Đang đối soát" đến khi chốt. | Download thiếu watermark/log → chặn + fail audit; hiện số tranh chấp như số chính thức → cảnh báo FIN_L1 |
| BR-012 | **Dữ liệu degraded vẫn minh bạch** (DI-007): nguồn platform đang `manual` (chưa có quyền API developer) vẫn hiển thị kèm nhãn nguồn + timestamp — không có màn trắng do một nguồn trễ. | Ẩn toàn màn vì một nguồn lỗi → sai quy tắc minh bạch; hiển thị phần nguồn còn tốt |
| BR-013 | **Kênh CSAT** (REQ-OPS-009): sau ticket Closed, CSAT (1–5 + câu mở) hiển thị trên app/web, nhắc tối đa 1 lần sau 48h; hình thức gửi Client Survey mặc định (AM tay / hệ thống) chưa chốt — mobile chỉ là kênh hiển thị sẵn có [KXN-15]. | Tự chọn chính sách gửi survey → vi phạm nguyên tắc không tự quyết KXN; ghi assumption, chờ chốt |

---

## 4. Phân Quyền

> Touchpoint **SYS-MOBILE-PORTAL** — app dành riêng cho CUSTOMER; vai OPS nội bộ không có tài khoản (thao tác trên SYS-BCERP-WEB, nhận push trên SYS-MOBILE-INTERNAL). Quyền do RBAC của CORE kiểm tra tại Portal API Gateway; CLIENT_ADMIN/CLIENT_USER là phân cấp bên trong vai CUSTOMER theo hợp đồng.

| Hành động | CUSTOMER (CLIENT_ADMIN) | CUSTOMER (CLIENT_USER) | OPS_AM | OPS_PLAN | OPS_CONT/DES/EDIT/ADS |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Đăng nhập/kích hoạt tài khoản (2FA) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem số dư read-only + chi tiêu tenant mình | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem tiến độ nghiệm thu + lịch nạp | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem/trả lời ticket của tenant mình | ✅ | ✅ | ❌ | ❌ | ❌ |
| Tạo ticket/comment, trả CSAT | ✅ | ✅ | ❌ | ❌ | ❌ |
| Confirm nghiệm thu milestone (phê duyệt nhẹ) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Tạo/thu hồi portal user trong hạn mức (OTP) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Tải tệp có watermark | ✅ | ✅ | ❌ | ❌ | ❌ |
| Chuyển tenant (được gán nhiều tenant) | ✅ | ✅ (nếu được gán) | ❌ | ❌ | ❌ |
| Đề xuất/thu hồi CLIENT_ADMIN (xác nhận POC) | ❌ | ❌ | ✅ (WEB nội bộ — FEAT-ERP-CPORT-001) | ❌ | ❌ |
| Monitor adoption + gate Day 14 | ❌ | ❌ | ✅ (WEB nội bộ + push M-INT) | ✅ (oversight) | ❌ |
| Đăng nhập mobile portal bằng tài khoản nội bộ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Thấy dữ liệu tenant khác / dữ liệu nội bộ (giá vốn, margin, PII nhân sự) | ❌ | ❌ | ❌ | ❌ | ❌ |

Quy tắc bổ sung: tài khoản nội bộ BCERP bị Portal API Gateway từ chối — mobile portal chỉ nhận portal user của tenant, hai danh tính không trộn lẫn để không có đường nào cho nội bộ thao tác trên kênh đối ngoại. OPS_AM không thấy dữ liệu khách trên app — dữ liệu monitor thuộc dashboard WEB nội bộ.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Gate Day 14 trượt:** escalate root cause lên CS TL trong 24h, kế hoạch khắc phục có owner + deadline; app không hiển thị tín hiệu gate nội bộ nào cho khách — nếu nguyên nhân là khách chưa cài app/đăng nhập, AM hướng dẫn qua kênh chính thức.
- **Khách đa nhãn hàng/pháp nhân:** mỗi pháp nhân 1 tenant riêng với bộ portal user riêng; tenant switcher chỉ liệt kê tenant được gán; push tách theo tenant đang chọn, không hợp nhất chéo tenant.
- **CLIENT_ADMIN nghỉ việc/thu hồi giữa kỳ:** AM đề xuất + xác nhận POC trong 1 ngày làm việc; session và push token của user hết hiệu lực ngay; các user do CLIENT_ADMIN cũ quản vẫn hoạt động, cần thay thế trong hạn mức.
- **Mất thiết bị:** CLIENT_ADMIN hoặc xác minh qua POC đăng xuất từ xa toàn bộ session trên mọi thiết bị; đăng nhập lại bắt buộc 2FA từ đầu.
- **Invite hết hạn:** hiệu lực mặc định 7 ngày (chốt khi cấu hình); CLIENT_ADMIN (hoặc AM với CLIENT_ADMIN đầu tiên) gửi lại invite mới, token cũ vô hiệu; app hiển thị "Invite hết hạn" kèm hướng dẫn.
- **Quên mật khẩu/2FA:** đặt lại qua OTP gửi email đăng ký/POC, sau đó bắt buộc bật lại 2FA; toàn bộ flow làm được trên mobile.
- **Mất kết nối mạng:** màn chỉ đọc hiển thị cache kèm nhãn "dữ liệu tại [timestamp]"; mọi hành động ghi vô hiệu khi offline — mobile portal không có chế độ ghi offline để bảo đảm mọi thao tác khách có vết thời gian thực trên CORE.
- **Nguồn trễ/degraded (DI-007) và số tranh chấp:** hiển thị kèm nhãn nguồn + timestamp; số dư tranh chấp hiển thị "Đang đối soát" + số tham chiếu, không hiện như số chính thức.
- **Hình thức gửi Client Survey:** chính sách gửi mặc định (AM tay / hệ thống) chưa chốt [KXN-15] — app chỉ hiển thị CSAT cho ticket Closed theo cơ chế REQ-OPS-009, không tự thêm kênh gửi riêng.
- **Khách EU/US:** DPA phải ký trước khi kích hoạt — tenant chưa có cờ "DPA signed" không hoàn tất kích hoạt trên mobile (chặn tầng service, BR-FIN-605); yêu cầu DSAR xử lý theo quy trình riêng.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> Entity chính là **tài khoản portal user** (CLIENT_ADMIN/CLIENT_USER); trạng thái thực thi ở service layer CORE, mobile là nơi khách thực hiện hành động và thấy trạng thái của chính mình — cùng state machine với bản Portal Web để 5 counterparts nhất quán. Kèm trạng thái **gate Day 14 của tenant** do gate engine CORE tính từ dữ liệu thực.

**Entity:** Tài khoản portal user

**Sơ đồ trạng thái:**
```
[INVITED] ──(kích hoạt + bật 2FA trên app/web)──► [ACTIVE] ──(sai mật khẩu/OTP 5 lần)──► [LOCKED]
    │                                                │  ▲                                │
    │ (invite hết hạn)                               │  └───(mở khóa sau xác minh)───────┘
    ▼                                                │
[EXPIRED]                                            └──(thu hồi / offboard)──► [DISABLED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `INVITED` | Kích hoạt + bật 2FA | `ACTIVE` | Chính user được invite | Invite hợp lệ; xác minh OTP; bật 2FA; tenant đã có cờ DPA (khách EU/US) |
| `INVITED` | Hết hạn invite | `EXPIRED` | Hệ thống | Quá thời hạn hiệu lực (mặc định 7 ngày — chốt khi cấu hình) |
| `EXPIRED` | Gửi lại invite | `INVITED` (token mới) | CLIENT_ADMIN (user của mình) / OPS_AM (CLIENT_ADMIN đầu tiên) | Token cũ vô hiệu; còn hạn mức |
| `ACTIVE` | Sai mật khẩu/OTP 5 lần | `LOCKED` | Hệ thống | Khóa tự động trên mọi thiết bị, revoke push token |
| `LOCKED` | Mở khóa sau xác minh | `ACTIVE` | CLIENT_ADMIN / xác minh qua POC | Xác minh danh tính + đặt lại mật khẩu + bật lại 2FA |
| `ACTIVE` | Thu hồi / offboard | `DISABLED` | CLIENT_ADMIN (user của mình); OPS_AM đề xuất thu hồi CLIENT_ADMIN sau xác nhận POC | Session + push token thu hồi ngay (BR-FIN-603) |

**Entity:** Gate Day 14 của tenant (gate engine CORE)

```
[ON_TRACK] ──(đủ tiêu chí)──► [GATE_PASSED]
    │
    └──(Day 14 chưa đủ tiêu chí)──► [GATE_MISSED] ──(khắc phục xong, đo lại)──► [GATE_PASSED]
```

**Quy tắc:**
- `DISABLED` là trạng thái kết thúc — không chuyển tiếp; tạo user mới chỉ khi còn hạn mức (suất DISABLED được giải phóng).
- Không tồn tại `ACTIVE` mà chưa bật 2FA — điều kiện sang `ACTIVE` bao gồm bắt buộc 2FA (khớp mốc Day 7).
- Gate Day 14 là trạng thái của tenant, tính từ dữ liệu activation/login thực của cả Portal Web và mobile; không ai chốt gate tay, và trạng thái gate nội bộ không hiển thị trên app khách.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính — chi tiết DDL đầy đủ tại `database-design.md`; mobile portal tiêu thụ qua Portal API Gateway, không owns dữ liệu.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `portal_user` | `id`, `tenant_id`, `email`, `role` (CLIENT_ADMIN/CLIENT_USER), `status`, `two_fa_enabled`, `last_login_ts`, `locale`, `timezone` | FK → `tenant.id` | Chỉ CUSTOMER có portal user; state machine tại CORE |
| `portal_invite` | `id`, `portal_user_id`, `token`, `expires_at`, `invited_by`, `status` | FK → `portal_user.id` | Token một-lần; hết hạn → `EXPIRED` |
| `tenant` | `id`, `legal_name`, `contract_no`, `admin_quota` (2), `user_quota` (10), `tier`, `dpa_signed` | 1 tenant — nhiều portal user | Mỗi pháp nhân/nhãn hàng 1 tenant; quota mở rộng theo tier |
| `onboarding_gate_log` | `tenant_id`, `milestone_day` (1/7/14/30), `criteria`, `result`, `checked_at` | FK → `tenant.id` | Gate Day 14 tính từ dữ liệu thực, không chốt tay; không lộ cho khách |
| `portal_access_log` | `user_id`, `tenant_id`, `action`, `resource`, `device_id`, `ts`, `ip` | FK → `portal_user.id` | Append-only, hash-chain; nguồn liệu adoption cho monitor |
| `portal_download_log` | `user_id`, `tenant_id`, `resource`, `watermark_text`, `ts` | FK → `portal_user.id` | Mọi download mobile/web có watermark + log |
| `push_notification` | `id`, `tenant_id`, `user_id`, `type`, `deep_link`, `sent_ts`, `read_at` | FK → `portal_user.id` | Chỉ tiêu đề loại sự kiện, không nhúng số liệu tài chính |
| `mobile_session` | `id`, `user_id`, `device_id`, `push_token`, `started_at`, `expires_at`, `revoked_at` | FK → `portal_user.id` | Session timeout; đăng xuất từ xa thu hồi toàn bộ |
| `ticket` (tham chiếu REQ-OPS-009) | `id`, `tenant_id`, `source` (portal/mobile-portal/zalo/email), `status`, `assignee`, `sla_clock` | FK → `tenant.id` | Mobile là điểm tạo; queue hợp nhất + state machine ở CORE |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — test được. Chi tiết hóa ở Phase 5; dưới đây là phác thảo map về REQ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Kích hoạt trên mobile | CLIENT_ADMIN nhận invite Day 1 | Mở link invite, xác minh OTP, bật 2FA | `ACTIVE` phản ánh về CORE realtime; không bật 2FA không vào được app | [ ] |
| SC-002: Số dư kèm disclaimer | User ACTIVE, view ví lọc tenant sẵn (FEAT-MPO-WALLET-001) | Mở màn tổng hợp số dư | Hiển thị theo TKQC + nhãn "số dư tham chiếu" + timestamp; thiếu freshness metadata → không render | [ ] |
| SC-003: Mask giá vốn | Lịch sử ví có điều chỉnh gắn giá vốn | Xem chi tiết giao dịch | Hiện "điều chỉnh đối soát"; không có trường giá vốn trong payload (kiểm tra tầng API) | [ ] |
| SC-004: Gate Day 14 đạt | Tenant có ≥2 user ACTIVE dùng cả web + mobile | Gate engine đo tại Day 14 | PASS khi khách tự xem được số dư + chi tiêu + ticket và ≥1 login/tuần từ ≥2 user; log gate không sửa tay được | [ ] |
| SC-005: Gate Day 14 trượt | Tenant chưa đạt tiêu chí gate | Hệ thống đánh giá gate | Escalate CS TL 24h, kế hoạch khắc phục có owner + deadline; app không hiện tín hiệu gate nào | [ ] |
| SC-006: Tenant isolation | Tenant A, B cùng dùng app | User A gọi API dữ liệu tenant B | 403 tầng service + log cảnh báo; tenant switcher không liệt kê tenant B | [ ] |
| SC-007: Push an toàn | User DISABLED còn push token cũ | Sự kiện phản hồi ticket phát sinh | Không push tới token đã revoke; push chỉ tiêu đề loại sự kiện, nội dung mở sau 2FA | [ ] |
| SC-008: OTP hành động nhạy cảm | CLIENT_ADMIN đã đăng nhập | Thêm user / xuất dữ liệu / đổi mật khẩu | Bắt buộc lớp OTP thứ hai; thiếu OTP → từ chối + log | [ ] |
| SC-009: Khóa sau 5 lần sai | User ACTIVE nhập sai mật khẩu liên tiếp | Sai lần thứ 5 | `LOCKED` trên mọi thiết bị; mở khóa cần xác minh danh tính qua POC/email | [ ] |
| SC-010: Nội bộ không đăng nhập được | Tài khoản OPS nội bộ (BCERP) | Thử đăng nhập mobile portal | Từ chối ở Portal API Gateway + log; app chỉ nhận portal user của tenant | [ ] |
| SC-011: Nghiệm thu từ mobile | Milestone WBS 100% Approved chờ khách confirm | CLIENT_USER confirm trên app | Xác nhận ghi realtime về CORE; đồng hồ song song giờ địa phương khách + GMT+7; quá hạn nhắc/escalate theo REQ-OPS-008/009 | [ ] |
| SC-012: Hạn mức user | Quota 2 CLIENT_ADMIN + 10 CLIENT_USER | CLIENT_ADMIN tạo user thứ 11 trên app | Chặn "Vượt hạn mức theo hợp đồng, liên hệ AM"; không tăng quota từ app | [ ] |

> **Liên kết:** SC-001/004/005 → REQ-OPS-010 (BR-OPS-5.1/3.2 — gate Day 14); SC-002/003 → REQ-FIN-017 (ví read-only, mask, disclaimer); SC-006/009/010 → REQ-OPS-010 (BR-OPS-5.2) + REQ-FIN-017; SC-007/008 → REQ-OPS-010 (BR-OPS-5.5); SC-011 → REQ-OPS-010 (nghiệm thu Portal/M-PORTAL — P1-02 Luồng 3); SC-012 → REQ-OPS-010 (số user theo hợp đồng).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/mobile-portal/client-portal/cap-tai-khoan-kich-hoat-monitor.md` |
| Bản counterparts (CORE, WEB, M-INT, PORTAL) | `phase2-features/core-backend/client-portal/` (FEAT-CORE-CPORT-001/002), `phase2-features/bcerp-web/client-portal/` (FEAT-ERP-CPORT-001), `phase2-features/mobile-internal/client-portal/`, `phase2-features/portal-web/client-portal/` (FEAT-PORTAL-CPORT-001/002) — fan-out REQ-OPS-010 |
| Ví read-only trên mobile (nội dung hiển thị) | `phase2-features/mobile-portal/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` (FEAT-MPO-WALLET-001) |
| Nguồn nghiệp vụ | `operations.md` (REQ-OPS-010; B.5 — BR-OPS-5.1→5.5; BR-OPS-3.2 — tiêu chí gate), `finance.md` (REQ-FIN-017, BR-FIN-603/605), `P1-02-business-workflow.md` (Luồng 1, 2, 3, 5) |
| Policy tham chiếu | `client-portal-minh-bach-bao-mat.md`, `sla-khach-hang.md`, `bao-ve-du-lieu-ca-nhan.md` |
