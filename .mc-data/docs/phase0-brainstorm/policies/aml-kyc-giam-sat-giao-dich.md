# AML/KYC & Giám Sát Giao Dịch Bất Thường — BCERP

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Khách hàng / Tài chính / Tuân thủ (Compliance)
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** compliance-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md`
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design)

> **Bối cảnh rủi ro:** BC Agency trung gian quản lý 2.600+ tài khoản quảng cáo đa kênh quốc tế cho 1.000+ khách hàng. Rủi ro gốc của mô hình là **rửa tiền qua ví/tài khoản quảng cáo**: tiền nguồn không rõ được nạp vào TKQC, tiêu hao dưới dạng chi phí quảng cáo hoặc hoàn về tài khoản khác dưới vỏ bọc dịch vụ hợp pháp. Bộ Knockout K1–K5 hiện chỉ lọc rủi ro ở tầng lead — chính sách này bổ sung **rào cản định danh (KYC) trước cấp phát** và **giám sát tầng giao dịch** suốt vòng đời khách hàng.

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:**
  - Toàn bộ khách hàng pháp nhân thuê dịch vụ trung gian tài khoản quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex và nền tảng khác) của BC Agency.
  - Toàn bộ giao dịch nạp tiền vào TKQC, hoàn tiền, hoàn phí liên quan TKQC.
  - Mọi nhân sự Sales, Finance, Vận hành TKQC, FIN_L2 tiếp xúc khách hàng hoặc dòng tiền khách hàng.
- **Không áp dụng cho:** giao dịch chi phí nội bộ không gắn với khách hàng; khách chỉ mua dịch vụ không phát sinh dòng tiền nạp TKQC (SEO, thiết kế web/đồ họa) — vẫn áp dụng KYC định danh khách nhưng không thuộc monitoring tầng giao dịch TKQC.
- **Effective từ:** [Điền khi BOD phê duyệt].

---

## 2. Nội Dung Chính Sách

> **Lưu ý pháp lý:** Toàn bộ ngưỡng, mức và thời hạn trong chính sách này là **khởi điểm do nội bộ đề xuất — cần xác nhận với đơn vị tư vấn AML/luật sư** trước khi phê duyệt chính thức, bảo đảm tương thích Luật Phòng, chống rửa tiền và các văn bản hướng dẫn hiện hành.

### 2.1. KYC pháp nhân — điều kiện tiên quyết trước khi cấp phát TKQC

Hồ sơ định danh pháp nhân bắt buộc **hoàn tất** trước khi cấp bất kỳ TKQC nào:

| Thành phần | Yêu cầu |
|---|---|
| Giấy chứng nhận đăng ký doanh nghiệp (GPKD) | Còn hiệu lực; khách nước ngoài: giấy tờ đăng ký kinh doanh tương đương, hợp pháp hóa lãnh sự khi cần |
| Mã số thuế / mã số doanh nghiệp (MST) | Đối chiếu nguồn dữ liệu chính thức |
| Người đại diện theo pháp luật | Giấy tờ tùy thân (CCCD/hộ chiếu) + xác thực danh tính |
| Tài khoản ngân hàng nạp/hoàn tiền | **Trùng tên pháp nhân** đã đăng ký (khớp theo GPKD) |
| Người thụ hưởng cuối cùng (UBO) | Khai báo khi có sở hữu thụ hưởng từ 25% trở lên (ngưỡng khởi điểm) |

Chỉ khi KYC đạt trạng thái **Verified** mới được cấp phát TKQC. Hồ sơ thiếu/sai → chặn cấp phát, ghi lý do vào CRM.

### 2.2. Hoàn tiền — nguyên tắc "về đúng nguồn nạp"

- Mọi khoản hoàn tiền chỉ chi trả về **đúng tài khoản ngân hàng/ví nguồn nạp**, trùng tên pháp nhân đã KYC.
- Nghiêm cấm hoàn tiền sang tài khoản bên thứ ba hoặc tài khoản khác tên. **Yêu cầu đổi tài khoản beneficiary là dấu hiệu đỏ**: hệ thống chặn mặc định và mở cảnh báo theo 2.3–2.4.

### 2.3. Ngưỡng và quy tắc cảnh báo giao dịch bất thường

| # | Quy tắc | Ngưỡng khởi điểm | Mức cảnh báo |
|---|---------|------------------|--------------|
| T1 | Nạp vượt gấp nhiều lần mức bình thường | Đơn nạp ≥ 3× mức nạp bình quân 30 ngày gần nhất của khách | Vàng |
| T2 | Tách nhỏ nhiều giao dịch (structuring) | ≥ 3 giao dịch nạp trong 24 giờ, tổng ≥ 200 triệu VND hoặc tương đương ngoại tệ | Đỏ |
| T3 | Nguồn chuyển từ nước ngoài khu vực rủi ro cao | Chuyển từ quốc gia/vùng lãnh thổ trong danh sách rủi ro cao FATF hoặc do BOD cập nhật | Đỏ |
| T4 | Hoàn tiền yêu cầu đổi tài khoản beneficiary | Bất kỳ trường hợp nào | Đỏ — chặn mặc định |
| T5 | Vòng tiền nhanh | Nạp rồi yêu cầu hoàn trong 72 giờ, không có chi tiêu dịch vụ tương ứng | Vàng |
| T6 | Hoàn tiền vượt tỷ lệ bất thường | Hoàn ≥ 50% giá trị nạp trong kỳ đối soát | Vàng |

Ngưỡng trên là khởi điểm — cần xác nhận với đơn vị tư vấn AML/luật sư. Hệ thống phải cho phép cấu hình ngưỡng mà không sửa code.

### 2.4. Quy trình xử lý cảnh báo

1. **Điều tra nội bộ (24 giờ):** FIN_L2 xác minh (BOD là lớp oversight độc lập) hợp đồng, lịch sử nạp–chi tiêu, giấy tờ nguồn tiền. Người đề xuất/nhập giao dịch không được tự điều tra (tách bạch công vụ).
2. **Cảnh báo vàng:** vô hại → đóng, ghi lý do; có nghi vấn → nâng lên mức đỏ.
3. **Escalation BOD (mức đỏ):** BOD xem xét trong 24 giờ tiếp theo.
4. **Quyết định:** từ chối hoặc phê duyệt giao dịch **có ghi lý do bằng văn bản**, lưu vĩnh viễn vào hồ sơ. Nghi vấn rửa tiền được xác thực → xử lý nghĩa vụ báo cáo cơ quan chức năng theo quy định pháp luật (phối hợp luật sư/tư vấn AML).

### 2.5. Lưu trữ hồ sơ (retention)

- Hồ sơ KYC: lưu **tối thiểu 5 năm** kể từ khi kết thúc quan hệ khách hàng (thời hạn khởi điểm theo thông lệ AML — cần luật sư xác nhận).
- Hồ sơ giao dịch, cảnh báo, biên bản điều tra, quyết định duyệt/từ chối: tối thiểu 5 năm.
- Lưu tập trung trong BCERP, truy xuất được theo khách hàng / TKQC / giao dịch / cảnh báo.

### 2.6. Phối hợp Knockout K1–K5 (tầng lead) với monitoring tầng giao dịch

Knockout K1–K5 là tầng sàng lọc đầu vào (K2/K4 lọc dấu hiệu rủi ro lead trước khi vào CRM). Kết quả Knockout **không thay thế** KYC và **không miễn** giám sát giao dịch — hai tầng bổ trợ nhau:

| Kết quả tầng lead | Mức KYC | Mức monitoring giao dịch |
|---|---|---|
| Qua K1–K5, rủi ro thấp | KYC chuẩn (2.1) | Ngưỡng chuẩn (2.3) |
| Có dấu hiệu cảnh báo (K2/K4) | KYC nâng cao (EDD) | Ngưỡng siết (hạ 50%) + review 6 tháng |
| Khách nước ngoài / khu vực rủi ro cao | EDD + phê duyệt BOD | Ngưỡng siết + review 6 tháng |

---

## 3. Ngoại Lệ

- **Tài khoản ngân hàng không trùng tên pháp nhân:** chỉ chấp nhận khi là tài khoản pháp nhân cùng nhóm (công ty mẹ/công ty con) có văn bản chứng thực + phê duyệt BOD; ghi vào hợp đồng và cập nhật hồ sơ KYC.
- **Khách tập đoàn nhiều pháp nhân:** nạp tiền từ pháp nhân cùng nhóm — yêu cầu EDD; danh sách pháp nhân được phép liệt kê trắng trong hợp đồng.
- **Quan hệ lâu dài tại khu vực rủi ro cao:** không miễn trừ — vẫn áp dụng EDD và monitoring siết; chỉ BOD duyệt hợp đồng.
- **Không có ngoại lệ cho:** hoàn tiền đổi beneficiary; cấp phát TKQC khi chưa đủ KYC; tắt monitoring cho bất kỳ khách hàng nào.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|---|---|---|
| Cấp phát TKQC sau KYC chuẩn | Trưởng bộ phận Vận hành TKQC | 1 ngày làm việc |
| Cấp phát TKQC sau EDD (khách nước ngoài/rủi ro cao) | FIN_L2 + BOD | 3 ngày làm việc |
| Xử lý cảnh báo vàng | FIN_L2 | 24 giờ |
| Xử lý cảnh báo đỏ | FIN_L2 điều tra → BOD quyết định | 24 giờ + 24 giờ BOD |
| Hoàn tiền về đúng nguồn nạp | Finance (người soạn ≠ người duyệt) | 1 ngày làm việc |
| Yêu cầu hoàn tiền đổi beneficiary | Từ chối mặc định; chỉ BOD xem xét lại bằng văn bản | 3 ngày làm việc |
| Ngoại lệ tài khoản không trùng tên | BOD | 3 ngày làm việc |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Chặn cấp phát TKQC khi trạng thái KYC ≠ Verified | Validation | CRM / Quản lý TKQC | MUST |
| Tự động khớp tên chủ tài khoản ngân hàng với tên pháp nhân; lệch → chuyển rà thủ công | Validation | Finance / Đối soát | MUST |
| Gắn hoàn tiền bắt buộc với giao dịch nạp gốc, chỉ hoàn về đúng nguồn | Validation | Finance | MUST |
| Rule engine cảnh báo theo quy tắc T1–T6, ngưỡng cấu hình được | Business Rule | AML Monitoring | MUST |
| Chặn + cảnh báo đỏ ngay khi có yêu cầu hoàn tiền đổi beneficiary | Validation + Notification | Finance | MUST |
| Workflow điều tra cảnh báo: trạng thái, người xử lý, ghi lý do bắt buộc khi đóng/duyệt/từ chối | Workflow | FIN_L2 | MUST |
| Khóa mềm giao dịch nghi vấn (hold) đến khi có quyết định, cấm xử lý song song | Validation | Finance | SHOULD |
| Audit log bất biến mọi hành động KYC, nạp, hoàn, cảnh báo, quyết định | Audit Trail | Toàn hệ thống | MUST |
| Danh sách khu vực rủi ro cao (FATF) đồng bộ định kỳ vào rule engine | Data Integration | AML Monitoring | SHOULD |
| Nhắc review KYC định kỳ tự động (12 tháng chuẩn / 6 tháng rủi ro cao) | Notification | CRM | SHOULD |
| Báo cáo định kỳ: cảnh báo theo mức, SLA xử lý, tỷ lệ đóng/escalation | Reporting | FIN_L2 | SHOULD |
| Truy xuất lịch sử giao dịch + hồ sơ theo khách/TKQC trong ≥ 5 năm | Reporting | Finance / Lưu trữ | MUST |
| Đồng bộ kết quả Knockout K1–K5 từ tầng lead để định mức KYC/monitoring | Data Integration | CRM / Marketing | SHOULD |

**Cross-policy dependencies:**
- **Policy SoD (tách bạch công vụ)** — người đề xuất giao dịch ≠ người duyệt ≠ người điều tra; triển khai cùng lúc.
- **Policy Quản lý tài khoản quảng cáo** — trạng thái cấp phát TKQC phải đọc trạng thái KYC từ CRM.
- **Policy Tài chính & Đối soát** — luồng nạp/hoàn tiền, đối soát chi tiêu là dữ liệu nguồn cho monitoring.
- **Policy Sàng lọc lead (Knockout K1–K5)** — định mức KYC/monitoring phụ thuộc kết quả tầng lead.

---

## 6. Xác Nhận

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---------|---------|---------------------|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Nội dung chính sách | Đúng / Cần sửa | |
| Ngoại lệ | Đúng / Cần sửa | |
| Quy trình phê duyệt | Đúng / Cần sửa | |
| Yêu cầu hệ thống | Đúng / Cần sửa | |

**Người xác nhận:** [Tên] — BOD / Giám đốc BC Agency
**Ngày:** [Ngày/Tháng/Năm]

---

## Lịch Sử Phiên Bản

| Phiên bản | Ngày | Người cập nhật | Thay đổi |
|-----------|------|----------------|---------|
| 1.0 | 11/09/2026 | compliance-expert | Khởi tạo |
