# Client Portal: Minh Bạch Dữ Liệu, Bảo Mật Portal & CSAT/Khiếu Nại — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Khách hàng / Công nghệ & Bảo mật
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** customer-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `kiem-soat-vi-tkqc-giao-dich-tien.md`, `rbac-phan-loai-du-lieu-credentials.md`, `doi-soat-cong-no-doanh-thu-da-tien-te.md`
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), `sla-khach-hang.md` (SLA clock dùng state machine ticket)

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** mọi khách đã ký hợp đồng sử dụng Client Portal; toàn bộ dữ liệu hiển thị trên portal (số dư ví TKQC, chi tiêu hàng ngày, tiến độ nghiệm thu, ticket, lịch nạp); mọi nhân viên BC phát triển/vận hành portal.
- **Không áp dụng cho:** hệ thống nội bộ BC; lead chưa ký hợp đồng; API tích hợp phía platform QC (Meta, Google, TikTok...).
- **Effective từ:** *(chờ user xác nhận)*

---

## 2. Nội Dung Chính Sách

### 2.1. Ranh giới dữ liệu

Triết lý TÍN: khách tự xem số liệu vận hành của mình — minh bạch **không** đồng nghĩa lộ nội bộ kinh doanh.

**Khách THẤY:**

| Nhóm dữ liệu | Phạm vi |
|--------------|---------|
| Số dư ví TKQC | Theo từng tài khoản QC của khách |
| Chi tiêu thực tế hàng ngày | Từng TKQC/campaign |
| Tiến độ nghiệm thu task | Theo milestone/quy trình nghiệm thu |
| Ticket hỗ trợ | Chỉ ticket của chính khách |
| Lịch nạp | Lịch sử nạp đã thực hiện + kế hoạch nạp đã cam kết |

**Khách KHÔNG THẤY:** giá vốn và chiết khấu nội bộ từ platform; P&L và biên lợi nhuận; tỷ giá nội bộ dùng cho hoạch định (khách chỉ thấy tỷ giá đã ghi trên hóa đơn/ghi nhận theo hợp đồng); dữ liệu của khách khác (tenant isolation); ghi chú nội bộ của AM/đội vận hành; báo cáo nội bộ health score/churn.

### 2.2. Disclaimer độ trễ dữ liệu

Mỗi chỉ số hiển thị kèm nhãn nguồn + thời điểm cập nhật cuối + độ trễ dự kiến (realtime phụ thuộc API từng nền tảng):

| Chỉ số | Nguồn | Độ trễ hiển thị | Disclaimer bắt buộc |
|--------|-------|-----------------|---------------------|
| Số dư ví TKQC | API platform | 15 phút – 24h tùy nền tảng | "Số dư tham chiếu; số chính thức theo đối soát cuối ngày với platform" |
| Chi tiêu daily | API platform | 3 – 24h | "Số liệu platform có thể được điều chỉnh hồi tố theo timezone platform" |
| Tiến độ nghiệm thu | Hệ thống BC | Realtime | — |
| Ticket | Hệ thống BC | Realtime | — |
| Lịch nạp | Hệ thống BC | Realtime | — |

Cấm hiển thị số dư/chi tiêu mà không kèm timestamp cập nhật.

### 2.3. Roles phía khách

| Role | Quyền |
|------|-------|
| CLIENT_ADMIN | Quản lý user phía khách (tạo/khóa CLIENT_USER), xem toàn bộ dữ liệu khách mình, xuất báo cáo, nhận escalation khiếu nại |
| CLIENT_USER | Xem dữ liệu theo phạm vi được gán (TKQC/dự án), tạo và theo dõi ticket |

Số lượng user theo hợp đồng (mặc định: 2 CLIENT_ADMIN + 10 CLIENT_USER; mở rộng theo tier). CLIENT_ADMIN tự phục vụ quản lý user; danh tính POC quản trị do AM xác nhận.

### 2.4. Bảo mật portal

- **2FA/OTP bắt buộc** khi đăng nhập (authenticator app hoặc email OTP); thêm một lớp OTP cho hành động nhạy cảm: đổi mật khẩu, thêm user, xuất dữ liệu.
- **Tenant isolation:** cách ly dữ liệu tuyệt đối ở tầng dữ liệu (row-level theo tenant); mọi truy vấn bắt buộc điều kiện tenant_id — cấm chỉ ẩn ở tầng UI.
- **Session timeout:** tự đăng xuất sau 30 phút không hoạt động; khóa tài khoản sau 5 lần sai mật khẩu liên tiếp; password policy theo `rbac-phan-loai-du-lieu-credentials.md`.
- **Ví TKQC read-only:** portal phía khách không có bất kỳ thao tác ghi nào lên ví (nạp/rút/điều chỉnh) — mọi thay đổi số dư chỉ do nội bộ thực hiện theo `kiem-soat-vi-tkqc-giao-dich-tien.md`.
- **Watermark download:** mọi file xuất (PDF/xlsx) gắn watermark tên user + thời điểm; mọi download ghi log.

### 2.5. Audit log điều chỉnh số dư

- Mọi điều chỉnh số dư (bù/trừ đối soát, hoàn tiền, ghi nhận chi phí platform) ghi **audit log bất biến**: ai, khi nào, số dư trước/sau, lý do, chứng từ kèm theo. Không có thao tác sửa/xóa trực tiếp số dư — chỉ ghi điều chỉnh bù/trừ.
- Khách **xem được lịch sử điều chỉnh** của ví mình trên portal (loại điều chỉnh, thời điểm, số tiền); trường gắn giá vốn được mask thành "điều chỉnh đối soát".
- Cơ chế bất biến và lưu trữ theo `audit-log-bao-luu-backup-dr.md`.

### 2.6. Onboarding portal — milestone Day 1/7/14/30

| Mốc | Hành động | Tiêu chí đạt |
|-----|-----------|--------------|
| Day 1 | Tạo tài khoản CLIENT_ADMIN đầu tiên, gửi invite | Khách đăng nhập thành công lần đầu |
| Day 7 | Khách kích hoạt đủ user + bật 2FA; session training portal | ≥80% user kích hoạt; 2FA bật cho 100% user |
| Day 14 | **GATE: "Khách kích hoạt Client Portal thành công"** | Khách tự xem được số dư + chi tiêu + ticket; ≥1 login/tuần từ ≥2 user |
| Day 30 | Review adoption + thu feedback đầu tiên | Feedback ghi nhận; ticket đầu tiên qua portal (nếu phát sinh) |

Gate Day 14 không đạt: CS escalate root cause lên CS TL trong 24h, kế hoạch khắc phục có owner + deadline; gate là điều kiện nghiệm thu giai đoạn onboarding.

### 2.7. CSAT & khiếu nại

- **CSAT tự động** gửi sau khi ticket chuyển Closed (thang 1–5 + 1 câu mở); nhắc tối đa 1 lần nếu không phản hồi sau 48h.
- **Detractor (điểm ≤2):** CS/AM liên hệ lại trong **48 giờ làm việc**; ghi nhận nội dung cuộc gọi + hành động khắc phục gắn vào ticket gốc.
- **Khiếu nại nghiêm trọng** (khách Tier D/E, hoặc nội dung về mất tiền, sai sót đối soát, đạo đức nhân viên): leo thang **BOD trong 24 giờ** kèm hồ sơ đầy đủ; OPS_PLAN điều phối.
- CSAT theo dõi theo tháng/tier; một tier <4.0 hai tháng liên tiếp → review dịch vụ bắt buộc do OPS_PLAN chủ trì.

### 2.8. Vòng đời ticket (state machine) + escalation bắt buộc

Luồng: **New → Open → Pending → Resolved → Closed.**

- **New:** ticket được tạo (khách tạo trên portal hoặc hệ thống ghi nhận từ kênh chính thức). **Open:** nhân viên BC nhận xử lý — SLA clock chạy (`sla-khach-hang.md`). **Pending:** chờ khách/bên thứ 3 — clock pause. **Resolved:** có giải pháp — trigger CSAT; **reopen trong 7 ngày** quay lại Open giữ toàn bộ ngữ cảnh. **Closed:** tự động 7 ngày sau Resolved nếu không reopen, hoặc khi khách xác nhận; Closed không reopen trực tiếp — tạo ticket mới tham chiếu ticket cũ.
- **Trigger escalation bắt buộc:** Critical quá First Response; bất kỳ ticket chạm 100% SLA; reopen ≥2 lần; Pending quá 3 ngày LV; khiếu nại từ CLIENT_ADMIN của khách Tier D/E. Escalation đi theo chuỗi **assignee → AM → CS TL → OPS_PLAN → BOD**, mỗi chặng có SLA xử lý 30 phút trong giờ trực.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- Khách từ chối dùng portal (chỉ làm việc qua AM/email): ghi ngoại lệ vào profile; AM chịu trách nhiệm cung cấp báo cáo thay thế đúng cam kết — tính vào workload KPI AM.
- Khách yêu cầu ẩn bớt chỉ số (VD chi tiêu): cấu hình hiển thị theo hợp đồng, bắt buộc xác nhận văn bản của CLIENT_ADMIN.
- Số liệu đang tranh chấp đối soát với platform: hiển thị trạng thái "Đang đối soát" kèm số tham chiếu, không hiển thị số chưa chốt như số chính thức.
- Xuất dữ liệu phục vụ kiểm toán/pháp lý không watermark: chỉ BOD phê duyệt, log đầy đủ.
- Khách đa nhãn hàng yêu cầu tách tenant con: mỗi pháp nhân/nhãn hàng một tenant riêng, không chia sẻ dữ liệu chéo.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Cấp/thu hồi CLIENT_ADMIN | AM đề xuất + CS xác nhận danh tính POC | 1 ngày LV |
| Ngoại lệ hiển thị dữ liệu theo yêu cầu khách | OPS_PLAN | 2 ngày LV |
| Leo thang khiếu nại nghiêm trọng lên BOD | OPS_PLAN (khởi tạo) | ≤24 giờ |
| Xuất dữ liệu không watermark / mục đích pháp lý | BOD | 3 ngày LV |
| Điều chỉnh số dư ví | Theo `kiem-soat-vi-tkqc-giao-dich-tien.md` (kế toán xác nhận + phê duyệt theo ngưỡng) | Theo policy ví |
| Khóa ngay tài khoản khách có dấu hiệu xâm phạm | OPS_PLAN | Tức thì |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Tenant isolation row-level; mọi API/query bắt buộc điều kiện tenant_id | Security | Core/Portal | MUST |
| 2FA/OTP bắt buộc đăng nhập + OTP hành động nhạy cảm; session timeout 30 phút; lockout 5 lần sai | Security | Auth | MUST |
| Chặn tuyệt đối thao tác ghi lên ví từ phía khách (read-only) | Validation | Wallet/Portal | MUST |
| Mask giá vốn/chiết khấu/P&L/tỷ giá nội bộ ở tầng API, không chỉ tầng UI | Security | API | MUST |
| Audit log bất biến mọi điều chỉnh số dư; khách xem được lịch sử (mask giá vốn) | Audit Trail | Wallet | MUST |
| Nhãn nguồn + last-updated + disclaimer độ trễ trên từng chỉ số | UI | Portal | MUST |
| RBAC CLIENT_ADMIN/CLIENT_USER + giới hạn số user theo hợp đồng | Access Control | Portal | MUST |
| State machine New→Open→Pending→Resolved→Closed, reopen 7 ngày, chặn reopen sau Closed | Business Rule | Ticketing | MUST |
| CSAT survey tự động sau Closed + task liên hệ detractor trong 48h LV | Workflow | Ticketing/CS | MUST |
| Trigger escalation bắt buộc theo mục 2.8, chuỗi assignee→AM→CS TL→OPS_PLAN→BOD | Business Rule | Ticketing | MUST |
| Watermark + audit log mọi download | Audit Trail | Portal | SHOULD |
| Milestone onboarding Day 1/7/14/30 với gate Day 14 + cảnh báo trượt gate | Workflow | Onboarding | SHOULD |
| Cấu hình ẩn/hiện nhóm chỉ số theo hợp đồng từng khách | Configuration | Portal | SHOULD |

**Cross-policy dependencies:** `sla-khach-hang.md` (SLA clock dùng chung state machine ticket — bắt buộc cùng release); `kiem-soat-vi-tkqc-giao-dich-tien.md` (điều chỉnh số dư, SoD); `doi-soat-cong-no-doanh-thu-da-tien-te.md` (số dư chính thức sau đối soát, đa tiền tệ); `rbac-phan-loai-du-lieu-credentials.md` (phân loại dữ liệu, password/credential); `audit-log-bao-luu-backup-dr.md` (tính bất biến, lưu trữ); `bao-ve-du-lieu-ca-nhan.md` (PII user phía khách); `phan-loai-khach-hang-tier.md` (tier cho escalation khiếu nại).

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
| 1.0 | 11/09/2026 | customer-expert | Khởi tạo |
