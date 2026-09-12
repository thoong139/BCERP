# RBAC, Phân Loại Dữ Liệu & Quản Lý Truy Cập/Credentials — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** IT Governance / Bảo mật / Nhân sự / Tài chính
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** sre (Site Reliability Engineering / IT Governance)
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md`
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), `audit-log-bao-luu-backup-dr.md`, `bao-ve-du-lieu-ca-nhan.md`, `quan-ly-cap-phat-tkqc-financial-hard-stop.md`

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** toàn bộ nhân sự BC Agency (31–50 người) truy cập BCERP; toàn bộ dữ liệu hệ thống (khách hàng, tài chính, nhân sự, vận hành QC); toàn bộ credentials API của 7 nền tảng quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) BC trung gian quản lý.
- **Không áp dụng cho:** tài khoản mạng xã hội cá nhân không liên quan công việc; credentials của khách trên nền tảng khách tự sở hữu, tự vận hành (BC chỉ tư vấn).
- **Effective từ:** ngày phê duyệt của BOD; quyền hiện hữu rà soát theo kỳ quarterly access review đầu tiên.

---

## 2. Nội Dung Chính Sách

### 2.1. Phân loại dữ liệu 4 tier

Mọi trường dữ liệu BCERP phải gắn đúng 1 tier; tier quyết định ai được xem, ai được sửa, có bị log truy cập không.

| Tier | Tên | Ví dụ | Quy tắc truy cập |
|------|-----|-------|------------------|
| T1 | Công khai | Giá niêm yết dịch vụ, profile công ty, bài marketing | Không hạn chế |
| T2 | Nội bộ | Dữ liệu khách, pipeline sales, dự án, timesheet đã chốt | Mọi tài khoản BCERP, theo phạm vi role |
| T3 | Mật | Chi phí nền tảng, cost rate theo khách, biên lợi nhuận, hợp đồng, tài khoản/thẻ công ty | FIN_L2, BOD_CEO, BOD_CFO_CTO + role được chỉ định; đọc phải log |
| T4 | Restricted | **Lương, thưởng, hoa hồng cá nhân, cost rate theo nhân sự**, CCCD, tài khoản ngân hàng cá nhân | **Chỉ BOD_CEO và BOD_CFO_CTO**; mã hóa at-rest; đọc phải log |

Quy tắc bắt buộc:

1. **Lương và cost rate là T4 Restricted — chỉ CEO/CFO xem.** SYS_ADMIN không thấy giá trị, chỉ thấy dữ liệu đã mã hóa khi vận hành kỹ thuật.
2. T3/T4 mã hóa at-rest và in-transit; mọi lần đọc ghi audit log bất biến (Policy `audit-log-bao-luu-backup-dr.md`).
3. Cấm đưa T3/T4 ra ngoài hệ thống (email cá nhân, chat, USB, bảng tính); chỉ export qua chức năng có log + phê duyệt.

### 2.2. Mô hình RBAC: Role × Level

Quyền truy cập = f(Role, Level). Role xác định "làm được gì", Level xác định "trên phạm vi dữ liệu nào".

| Nhóm | Roles |
|------|-------|
| BOD | BOD_CEO, BOD_CFO_CTO |
| Nhân sự | HR_L1, HR_L2 |
| Tài chính | FIN_L1, FIN_L2 |
| Sales | SALES_L1 → SALES_L5 |
| Vận hành QC | OPS_QC_L1, OPS_QC_L2, OPS_QC_LEAD |
| Chăm sóc khách | CLIENT_SVC_L1, CLIENT_SVC_L2 |
| Kỹ thuật | SYS_ADMIN |

Level L1–L5: **L1** dữ liệu bản thân → **L2** team trực tiếp → **L3** cả phòng → **L4** toàn công ty (đọc) → **L5** toàn quyền phạm vi role + quyền phê duyệt.

1. Mỗi user gán ít nhất 1 role; mỗi cặp (user, role) gắn đúng 1 level.
2. Chỉ BOD_CEO phê duyệt tạo/sửa/gán role; SYS_ADMIN chỉ thực thi sau phê duyệt, không tự gán quyền kể cả cho chính mình.

### 2.3. Kiêm nhiệm & tách xung đột phê duyệt (SoD)

- Hỗ trợ **1 người – nhiều vai**: một user được gán đồng thời nhiều cặp (role, level).
- **SoD bắt buộc** — hệ thống chặn gán cặp role xung đột cho cùng 1 user trên cùng 1 luồng: người **ghi** timesheet không **tự duyệt**; người lập phiếu thu/chi không tự duyệt phiếu; người đề xuất đổi phân quyền không tự duyệt đề xuất; người soạn hợp đồng không phê duyệt hợp đồng đó.
- Vắng mặt: ủy quyền có thời hạn tối đa 14 ngày, tự hết hạn, ghi log, báo BOD_CEO.

### 2.4. Compensating control cho CFO kiêm CTO (concentration of risk)

CTO kiêm CFO và Super Admin — **điểm tập trung rủi ro duy nhất** của hệ thống. Không tách được người nên bắt buộc các compensating controls:

1. Mọi **giao dịch tiền vượt ngưỡng** (nạp/rút ví QC, điều chỉnh số dư) do BOD_CFO_CTO khởi tạo phải có **BOD_CEO phê duyệt** trước khi thực thi — chặn hard trong code, không có đường tắt.
2. **Quarterly access review**: mỗi quý BOD_CEO rà soát toàn bộ quyền của BOD_CFO_CTO (roles, phạm vi dữ liệu, credentials đang quản trị) và ký xác nhận.
3. Mọi hành động Super Admin ghi immutable audit log — kể cả Super Admin không xóa/sửa được log của chính mình.
4. Khi tổ chức cho phép, ưu tiên tách vai CFO khỏi CTO; trước đó các controls trên là bắt buộc.

### 2.5. Quản lý credentials API 7 nền tảng quảng cáo

Credentials API (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) là **tài sản tiền tệ** — mất credentials là mất quyền điều hành ngân sách quảng cáo của khách.

- Mọi API key, access token, app secret lưu trong **vault mã hóa**; cấm plaintext trong code, cấu hình, chat, email, bảng tính.
- Chỉ **CTO/Super Admin** quản trị vault (thêm/sửa/rotate/thu hồi); người khác dùng qua API BCERP, không nhìn thấy giá trị.
- **MFA bắt buộc** cho toàn bộ tài khoản quản trị trên cả 7 nền tảng và tài khoản Super Admin BCERP.
- **Rotate token định kỳ:** tối thiểu 90 ngày/lần với token dài hạn; rotate ngay khi nghi ngờ rò rỉ hoặc người liên quan nghỉ việc.
- **Thu hồi khi nghỉ việc trong 24 giờ** kể từ thời điểm hiệu lực; checklist offboarding phải có xác nhận CTO.
- **Log mọi lần gọi API** (ai, khi nào, tài khoản nào, hành động gì) — log bất biến.

### 2.6. Quarterly access review toàn hệ thống

- Mỗi quý CTO xuất báo cáo user × role × level × credentials gửi BOD_CEO review.
- BOD_CEO xác nhận hoặc yêu cầu thu hồi quyền không còn phù hợp vị trí. Quyền không được review 2 quý liên tiếp bị **tự động vô hiệu hóa** đến khi review xong.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Service account** (không gắn người): miễn MFA cá nhân nhưng key phạm vi tối thiểu, rotate 90 ngày, log toàn bộ, gắn 1 chủ sở hữu nhân sự.
- **Truy cập khẩn sự cố:** CTO được vào vùng T3/T4 xử lý incident; khai báo lý do trong 24 giờ, hệ thống alert BOD_CEO ngay.
- **Nhân sự thử việc:** level tối thiểu, không có bất kỳ quyền phê duyệt nào trước khi ký hợp đồng chính thức.
- **Freelancer/cộng tác viên:** tài khoản guest tối đa 90 ngày (gia hạn phải duyệt), chỉ CLIENT_SVC_L1, không truy cập T3/T4.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Gán/thay đổi role & level | BOD_CEO | ≤ 2 ngày làm việc |
| Gán cặp role xung đột SoD (có lý do chính đáng) | BOD_CEO + ghi lý do vào audit log | ≤ 5 ngày làm việc |
| Truy cập T4 ngoài phạm vi role (ngoài CEO/CFO mặc định) | BOD_CEO | ≤ 2 ngày làm việc |
| Quản trị vault; giao dịch tiền vượt ngưỡng do CTO khởi tạo | CTO quản trị vault; giao dịch vượt ngưỡng → BOD_CEO | Ngay; CEO ≤ 4 giờ (khẩn) |
| Ủy quyền phê duyệt khi vắng mặt | Người giữ quyền ủy quyền, báo BOD_CEO | ≤ 1 ngày làm việc |
| Quarterly access review | BOD_CEO ký xác nhận | 10 ngày đầu quý |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| MFA bắt buộc tài khoản quản trị; khóa tạm sau 5 lần sai liên tiếp | Validation | Auth/Identity | MUST |
| Enforce RBAC (role × level) ở tầng API, không chỉ ẩn UI | Validation | Toàn hệ thống | MUST |
| Gắn nhãn tier T1–T4 trên trường dữ liệu; chặn đọc/ghi sai tier | Validation | Data Model / All | MUST |
| Ẩn tuyệt đối T4 (lương, cost rate) với mọi role trừ CEO/CFO; mã hóa at-rest | Validation | HR / Finance | MUST |
| Chặn hard giao dịch tiền vượt ngưỡng của BOD_CFO_CTO khi chưa có BOD_CEO duyệt | Validation | Finance / Wallet | MUST |
| Chặn gán cặp role xung đột SoD cùng luồng; cảnh báo khi kiêm nhiều role | Validation | Identity Admin | MUST |
| Vault mã hóa credentials 7 nền tảng; không trả plaintext token về UI | Security | Integration/Vault | MUST |
| Log mọi lần gọi API nền tảng vào immutable audit log | Audit Trail | Integration/Vault | MUST |
| Offboarding: sự kiện nghỉ việc → tự revoke + task rotate credentials, hoàn tất ≤ 24h | Workflow | HR / Identity | MUST |
| Báo cáo quarterly access review tự động (user × role × level × credentials) | Reporting | Identity Admin | MUST |
| Cảnh báo token đến hạn rotate (T-7 ngày); tự vô hiệu quyền chưa review 2 quý | Notification | Vault / Identity | SHOULD |
| Ủy quyền phê duyệt có thời hạn, tự hết hạn | Workflow | Approval Engine | SHOULD |
| Session timeout + alert đăng nhập bất thường (thiết bị/vị trí mới) | Security | Auth | SHOULD |

**Cross-policy dependencies:** Phụ thuộc chặt **`audit-log-bao-luu-backup-dr.md`** — mọi sự kiện truy cập/phân quyền phải ghi vào immutable audit log, cần triển khai cùng lúc. Liên quan `bao-ve-du-lieu-ca-nhan.md` (T4 trùng dữ liệu cá nhân), `quan-ly-cap-phat-tkqc-financial-hard-stop.md` (thu hồi truy cập TKQC 24h, cấm chia sẻ login), `aml-kyc-giam-sat-giao-dich.md` (phân quyền phê duyệt giao dịch tiền).

---

## 6. Xác Nhận

> **📝 User xác nhận** — Chính sách này có phản ánh đúng thực tế doanh nghiệp không?

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
| 1.0 | 11/09/2026 | sre agent | Khởi tạo |
