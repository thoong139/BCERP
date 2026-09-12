# Audit Log Bất Biến, Bảo Lưu Hồ Sơ, Backup/DR & Change Management — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** IT Governance / Tài chính / Vận hành hệ thống
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** sre (Site Reliability Engineering / IT Governance)
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md`
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), `rbac-phan-loai-du-lieu-credentials.md`, `quan-ly-cap-phat-tkqc-financial-hard-stop.md`, `doi-soat-cong-no-doanh-thu-da-tien-te.md`, `hop-dong-loi-nda-brand-safety.md`

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** toàn bộ audit log do BCERP sinh ra; mọi giao dịch tiền (nạp/rút ví QC, đổi tỷ giá, chiết khấu, điều chỉnh số dư), hợp đồng và thay đổi phân quyền; toàn bộ hoạt động backup/phục hồi và mọi thay đổi hệ thống (code, cấu hình, hạ tầng, phân quyền kỹ thuật) trên production.
- **Không áp dụng cho:** môi trường dev/test dùng dữ liệu đã ẩn danh (miễn WORM, nhưng cấm dùng dữ liệu production chứa T3/T4 chưa ẩn danh); log hệ điều hành/mạng ngoài BCERP.
- **Effective từ:** ngày BCERP go-live. Đây là policy **nền móng** — phải có từ thiết kế kiến trúc, không bổ sung được sau khi hệ thống đã chạy dữ liệu tiền.

---

## 2. Nội Dung Chính Sách

### 2.1. Immutable audit log — nguyên tắc nền móng

1. **Append-only:** log chỉ ghi thêm; không ai sửa hay xóa được — **kể cả Super Admin**. Ứng dụng kết nối DB bằng account chỉ có quyền INSERT/SELECT trên bảng log.
2. Mỗi bản ghi: **ai** (user, role), **khi nào** (timestamp), **làm gì**, trên đối tượng nào; với mọi thay đổi giá trị ghi **old value → new value + reason code** bắt buộc — thiếu reason code thì giao dịch không được submit.
3. **Hash-chain:** mỗi bản ghi chứa hash của bản ghi liền trước; job kiểm tra toàn vẹn chạy hàng ngày, đứt chuỗi → alert ngay cho CTO và BOD_CEO.
4. **Việc XEM audit log cũng bị log** (ai xem, xem gì, khi nào) — chống truy cập lén.
5. Không tồn tại interface xóa/sửa log ở mọi tầng (UI, API, DB, script vận hành).

### 2.2. Phạm vi bắt buộc ghi log

Bắt buộc ghi immutable log (MUST):

- **Mọi giao dịch tiền:** nạp/rút ví quảng cáo, đổi tỷ giá, chiết khấu, điều chỉnh số dư, thu/chi nội bộ.
- **Hợp đồng:** tạo, sửa, phê duyệt, đổi trạng thái, đính kèm/thay thế file.
- **Thay đổi phân quyền:** gán/thu hồi role, đổi level, đổi quyền truy cập vault credentials.
- Đăng nhập/đăng xuất, đăng nhập thất bại, truy cập dữ liệu Mật/Restricted (theo Policy RBAC).
- Mọi hành động Super Admin và thay đổi cấu hình hệ thống.

Sự kiện vận hành khác (cập nhật CRM, ghi chú nội bộ): SHOULD log.

### 2.3. Retention & WORM storage

| Loại dữ liệu | Bảo lưu tối thiểu | Căn cứ |
|--------------|-------------------|--------|
| Audit log sự kiện tiền & hợp đồng | **≥ 10 năm** | Luật Kế toán 2015 |
| Audit log hệ thống (đăng nhập, phân quyền, cấu hình, change log) | **≥ 7 năm** | Chính sách nội bộ, điều tra truy xuất |

- Log lưu trên **storage WORM** (Write Once Read Many): sau khi ghi, không đối tượng nào — kể cả Super Admin — ghi đè/xóa được trong thời hạn retention.
- Hết hạn retention, việc xóa/archive phải có phê duyệt; chính việc xóa cũng được ghi log.

### 2.4. Backup & DR

- Backup toàn bộ dữ liệu BCERP **hằng ngày**, **mã hóa AES-256**, lưu **tối thiểu 2 nơi tách biệt** (1 onsite + 1 offsite/cloud khác vùng).
- **Test phục hồi mỗi quý:** restore tập dữ liệu thực lên môi trường test, đối chiếu hash, lập biên bản ký tên. **Backup chưa từng test restore không tính là backup hợp lệ.**
- Mục tiêu: **RTO ≤ 4 giờ, RPO ≤ 15 phút.** Với giao dịch tiền, RPO ≤ 15 phút đòi hỏi replication gần thời gian thực cho luồng ghi — backup hằng ngày một mình không đủ.
- Backup thất bại alert trong 30 phút; sự cố mất dữ liệu hoặc drill thất bại phải post-mortem trong 5 ngày làm việc.

### 2.5. Change management

Mọi thay đổi production (code, cấu hình, phân quyền kỹ thuật, hạ tầng) theo quy trình:

1. **SYS_ADMIN đề xuất** change request: mô tả, phạm vi ảnh hưởng, các bước thực hiện.
2. **CTO phê duyệt**; change ảnh hưởng luồng tiền/hợp đồng/phân quyền cần xác nhận thêm của chủ nghiệp (FIN/SALES lead).
3. **Change window:** thực hiện ngoài giờ cao điểm, thông báo trước. Change khẩn được làm ngay nhưng bổ sung hồ sơ trong 24 giờ.
4. **Rollback plan bắt buộc** trước khi thực hiện; nếu không có rollback khả thi → tạo backup điểm thời gian ngay trước change.
5. **Post-review trong 3 ngày làm việc:** kết quả, sự cố phát sinh, bài học.
6. **Mọi change ghi log bất biến:** ai đề xuất, ai duyệt, khi nào, nội dung, kết quả.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Change khẩn P1** (ngừng dịch vụ, rò rỉ dữ liệu): CTO thực hiện ngay bằng quyền khẩn, hậu phê duyệt, bổ sung hồ sơ ≤ 24 giờ.
- **Yêu cầu pháp lý** (thanh tra, kiểm toán): thời hạn giữ chỉ được kéo dài, không bao giờ rút ngắn dưới mức tối thiểu.
- **Sửa dữ liệu nghiệp vụ** (nhập sai số dư): KHÔNG sửa bản ghi gốc — luôn ghi giao dịch điều chỉnh ngược (reversal) có reason code, giữ nguyên dấu vết cũ→mới.
- **Drill DR đột xuất không báo trước:** tối đa 1 lần/năm để đo RTO thực tế, báo BOD trước khi chạy.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Change thường (code/cấu hình không ảnh hưởng tiền) | CTO | ≤ 2 ngày làm việc |
| Change ảnh hưởng luồng tiền/hợp đồng/phân quyền | CTO + chủ nghiệp (FIN/SALES lead) | ≤ 3 ngày làm việc |
| Change khẩn P1 | CTO làm ngay, hậu phê duyệt | Bổ sung hồ sơ ≤ 24 giờ |
| Truy xuất/xuất audit log ngoài báo cáo chuẩn | BOD_CEO | ≤ 2 ngày làm việc |
| Kết quả test restore hàng quý | CTO ký biên bản, báo BOD_CEO | ≤ 5 ngày sau test |
| Xóa/archive log hết hạn retention | CTO đề xuất + BOD_CEO duyệt | Theo quý |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Audit log append-only ở tầng quyền DB (app account chỉ INSERT/SELECT) | Security/Architecture | Audit Core | MUST |
| Ghi old → new value + reason code bắt buộc cho mọi thay đổi tiền/hợp đồng/phân quyền | Audit Trail | Finance / Contract / Identity | MUST |
| Hash-chain + job kiểm tra toàn vẹn hàng ngày, alert khi đứt chuỗi | Security | Audit Core | MUST |
| Log việc xem audit log (meta-log) | Audit Trail | Audit Core | MUST |
| WORM storage: log tiền & hợp đồng ≥ 10 năm, log hệ thống ≥ 7 năm | Storage | Audit Storage | MUST |
| Backup hằng ngày mã hóa AES-256, 2 nơi lưu tách biệt | Ops | Backup | MUST |
| Replication gần thời gian thực cho giao dịch tiền (RPO ≤ 15 phút) | Architecture | Finance / Database | MUST |
| Runbook khôi phục đảm bảo RTO ≤ 4 giờ | Ops | DR | MUST |
| Test restore hàng quý có biên bản ký tên | Ops | Backup | MUST |
| Alert backup thất bại trong 30 phút | Notification | Backup | MUST |
| Workflow change: đề xuất → duyệt → window → rollback plan → post-review, ghi log toàn bộ | Workflow | Change Management | MUST |
| Chặn deploy/thay đổi production khi không có change record được duyệt | Validation | Change Management / CI-CD | MUST |
| Báo cáo retention định kỳ (log sắp hết hạn, dung lượng WORM) | Reporting | Audit Storage | SHOULD |
| Dashboard truy xuất audit log theo thời gian/đối tượng cho BOD | Reporting | Audit Core | NICE |

**Cross-policy dependencies:** Là **nền móng cho mọi policy tiền** — triển khai đồng loạt từ phase kiến trúc vì WORM/hash-chain không bổ sung sau được. Phụ thuộc chéo với **`rbac-phan-loai-du-lieu-credentials.md`** (log truy cập T3/T4, log phân quyền, log hành động Super Admin), `quan-ly-cap-phat-tkqc-financial-hard-stop.md` (log lệnh nạp/khớp tiền/cấp phát), `doi-soat-cong-no-doanh-thu-da-tien-te.md` (log đối soát), `hop-dong-loi-nda-brand-safety.md` (log vòng đời hợp đồng), `bao-ve-du-lieu-ca-nhan.md` (giới hạn dữ liệu cá nhân trong log).

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
