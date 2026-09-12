# Quản Lý & Cấp Phát TKQC + Financial Hard Stop — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Paid Media / Tài chính / Vận hành
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** paid-media-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md`
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), `kiem-soat-vi-tkqc-giao-dich-tien.md`, `tiktok-shop-du-lieu-gmv-tham-dinh.md`

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** toàn bộ tài khoản quảng cáo (TKQC) trên mọi platform BC Agency trung gian vận hành (Meta, Google, TikTok, Bing, X, Pinterest, Yandex), thuộc mọi khách hàng; mọi media buyer, team lead (TL), account manager (AM), kế toán viên (FIN_L1) và quản trị hệ thống.
- **Không áp dụng cho:** TKQC nội bộ đào tạo/demo trong pool "Internal-Sandbox" (không gắn khách, không tiêu ngân sách khách); TKQC do khách tự sở hữu và tự vận hành (BC chỉ tư vấn, không nạp tiền).
- **Effective từ:** ngày BCERP go-live; các TK đang vận hành được map ngược vào vòng đời trong vòng 30 ngày.

---

## 2. Nội Dung Chính Sách

### 2.1. Financial Hard Stop — nguyên tắc bất di bất dịch

1. TKQC chỉ được **cấp phát/bật chi tiêu** sau khi Kế toán viên FIN_L1 xác nhận trạng thái **"Đã khớp tiền"** trên hệ thống cho lệnh nạp tương ứng — nghĩa là tiền của khách đã về tài khoản BC và khớp số với lệnh nạp.
2. Hard Stop được thực thi **trong code**: workflow engine chặn action "Cấp phát" khi trạng thái khớp tiền ≠ "Đã khớp tiền". **Không có nút override, không có vai trò nào được bypass — kể cả Giám đốc.**
3. **Không chấp nhận "chờ duyệt"**: các lý do "khách hứa chuyển", "đang chuyển", "sếp đã OK" không có giá trị mở khoá. Mọi yêu cầu mở khoá thủ công bị hệ thống từ chối và ghi audit log bất biến.
4. Nếu xác nhận khớp tiền bị phát hiện sai → FIN_L1 thu hồi xác nhận → hệ thống tự động chuyển TK về "Tạm dừng chi tiêu", khóa lệnh nạp mới và bắn alert cho TL.

### 2.2. Vòng đời TKQC (5 trạng thái)

**Khởi tạo → Khớp tiền → Cấp phát → Vận hành → Thu hồi/Đóng.**

| Trạng thái | Điều kiện chuyển vào | Ai thực hiện | Hệ thống thực thi |
|-----------|---------------------|--------------|-------------------|
| Khởi tạo | Có demand/booking từ khách | Buyer tạo yêu cầu | Sinh mã TK theo naming, trạng thái "chưa hoạt động", gắn project |
| Khớp tiền | Tiền nạp đã về và khớp lệnh | FIN_L1 xác nhận | Ghi timestamp + căn cứ (sao kê/lệnh), mở điều kiện hard stop |
| Cấp phát | Trạng thái "Đã khớp tiền" | Buyer nhận ownership | Gán owner + backup, nối platform ID, cho phép bật campaign |
| Vận hành | TK đang chi tiêu | Owner điều hành | Theo dõi ngân sách, số dư, cảnh báo theo policy ví TKQC |
| Thu hồi/Đóng | Hết HĐ, die account, khách chấm dứt | TL duyệt | Thu hồi access, snapshot evidence, archive dữ liệu |

Mọi chuyển trạng thái đều ghi audit log bất biến: ai, khi nào, từ trạng thái nào sang trạng thái nào, căn cứ gì.

### 2.3. Ownership & phân quyền

- Mỗi TKQC có đúng **1 owner** (media buyer chịu trách nhiệm chi tiêu) + đúng **1 backup** được chỉ định danh nghĩa. Cấm "đồng sở hữu", cấm quá 2 người có quyền edit.
- **Cấm chia sẻ login**: mỗi cá nhân dùng tài khoản riêng trên BCERP và platform; cấm dùng chung email/mật khẩu/2FA. Vi phạm → thu hồi quyền ngay + kỷ luật.
- Bốn mức quyền: **edit** (owner + backup), **view-only** (TL, AM, FIN xem số liệu), **billing** (FIN_L1/kế toán — thao tác tài chính, không sửa ngân sách chiến dịch), **admin** (quản trị hệ thống — không có quyền chỉnh chi tiêu).
- **Thu hồi truy cập trong 24 giờ** kể từ thời điểm nhân sự nghỉ việc, chuyển dự án hoặc bị thay owner. Sự kiện từ HR → hệ thống tự revoke và sinh task bàn giao cho backup.

### 2.4. Naming & UTM Convention bắt buộc

- Chuẩn naming cho TK/campaign/adset/ad: `[ClientCode]-[Platform]-[Objective]-[Market]-[YYMM]` (ví dụ: `FMCG01-META-CONV-VN-2609`).
- Mọi campaign **bắt buộc gắn Project trên BCERP trước khi bật**. **Campaign không gắn dự án = không tồn tại**: hệ thống tự phát hiện và pause, tạo task gắn dự án trong 4h làm việc; không được phép report hoặc hạch toán chi tiêu về khách cho đến khi gắn xong.
- UTM (`utm_source`, `utm_medium`, `utm_campaign`) sinh tự động từ naming — cấm sửa tay để đảm bảo dữ liệu attribution nhất quán.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Client-owned TK** (khách tự cấp quyền partner cho BC): vẫn áp dụng naming + gắn project; hard stop áp dụng ở mức đo lường, BC không thực hiện lệnh nạp.
- **TK Internal-Sandbox**: không gắn khách, ngân sách thật ≤ mức TL duyệt, rà soát theo quý.
- **TK platform bắt buộc BC đứng tên** (ví dụ TikTok Agency Account): ownership vẫn 1 owner + 1 backup; văn bản ủy trách nhiệm do Giám đốc ký.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Cấp phát TK sau khớp tiền | Tự động — hard stop mở khi FIN_L1 xác nhận | Tức thì |
| Đổi owner/backup của TK | TL Paid Media | 1 ngày làm việc |
| Đóng/thu hồi TK kết thúc HĐ | TL + FIN_L1 xác nhận hết dư nợ | 2 ngày làm việc |
| Đóng TK do die account | TL theo SLA policy ví TKQC | Theo SLA policy ví |
| Ngoại lệ naming (khách yêu cầu chuẩn riêng) | TL duyệt, ghi lý do vào change log | 1 ngày làm việc |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Chặn cấp phát khi trạng thái khớp tiền ≠ "Đã khớp tiền" — hard stop trong code, không route override | Validation | Quản lý TKQC | MUST |
| Audit log bất biến mọi chuyển trạng thái vòng đời và mọi xác nhận/thu hồi khớp tiền | Audit Trail | Quản lý TKQC | MUST |
| Bắt buộc gắn Project trước khi bật campaign; tự động pause campaign không gắn dự án | Validation + Automation | Quản lý TKQC / Dự án | MUST |
| Validator naming convention + sinh UTM tự động, chặn sửa tay | Validation | Quản lý TKQC | MUST |
| RBAC 4 mức (edit/view-only/billing/admin); giới hạn tối đa 2 user edit mỗi TK | Authorization | Quản lý TKQC / IAM | MUST |
| Tự động thu hồi access trong 24h khi nhận sự kiện nghỉ việc/chuyển dự án từ HR | Automation | IAM / Nhân sự | MUST |
| Cảnh báo TK thiếu owner/backup, owner sắp nghỉ, campaign chưa gắn project quá 4h | Notification | Quản lý TKQC | SHOULD |

**Cross-policy dependencies:** phụ thuộc `kiem-soat-vi-tkqc-giao-dich-tien.md` — xác nhận "đã khớp tiền" của FIN_L1 là input của hard stop, SoD 4 vai định nghĩa tại đó; chia sẻ chuẩn naming/UTM với `tiktok-shop-du-lieu-gmv-tham-dinh.md`; hạ tầng audit log bất biến dùng chung 3 policy.

---

## 6. Xác Nhận

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---------|---------|---------------------|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Nội dung chính sách | Đúng / Cần sửa | |
| Ngoại lệ | Đúng / Cần sửa | |
| Quy trình phê duyệt | Đúng / Cần sửa | |
| Yêu cầu hệ thống | Đúng / Cần sửa | |

**Người xác nhận:** [Tên] — [Vai trò]
**Ngày:** [Ngày/Tháng/Năm]

---

## Lịch Sử Phiên Bản

| Phiên bản | Ngày | Người cập nhật | Thay đổi |
|-----------|------|----------------|---------|
| 1.0 | 11/09/2026 | paid-media-expert | Khởi tạo |
