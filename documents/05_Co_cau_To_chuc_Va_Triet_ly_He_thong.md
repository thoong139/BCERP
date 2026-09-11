# TÀI LIỆU CƠ CẤU TỔ CHỨC & TRIẾT LÝ THIẾT KẾ HỆ THỐNG ERP
**Mã tài liệu:** `05_Co_cau_To_chuc_Va_Triet_ly_He_thong.md`  
**Đơn vị áp dụng:** BC Agency (Brand Companion Agency)  
**Mục đích:** Chuẩn hóa dữ liệu cơ sở cho phân hệ RBAC (Role-Based Access Control), quản trị nguồn lực (Capacity), tính chi phí nhân công (Cost per Hour) và thiết lập quy chuẩn hành vi hệ thống.

---

## PHẦN 1: CƠ CẤU TỔ CHỨC & MA TRẬN PHÂN QUYỀN (ORGANIZATIONAL HIERARCHY)

### 1. Ban Điều Hành (Board of Directors - BOD)
* **CEO (Tổng Giám đốc) – Bùi Thị An:** Toàn quyền quản trị chiến lược, phê duyệt chính sách công ty, truy cập toàn bộ P&L và cảnh báo rủi ro vận hành.
* **CFO kiêm CTO – Hoàng Nam:** 
  * *Tài chính (CFO):* Quản lý dòng tiền, phê duyệt hạn mức tín dụng TKQC, thẩm định biên lợi nhuận (Profitability), thiết lập quy chuẩn kế toán nội bộ.
  * *Công nghệ (CTO):* Quản trị kiến trúc hệ thống dữ liệu ERP, bảo mật thông tin, phê duyệt tích hợp API và quyền hạn tối cao (Super Admin).
* **CMO (Giám đốc Tiếp thị):** *(Vị trí quy hoạch - Tạm thời BOD kiêm nhiệm)*.
* **COO / GDKD (Giám đốc Vận hành / Giám đốc Kinh doanh):** *(Vị trí quy hoạch)*.

---

### 2. Khối Hỗ Trợ Vận Hành & Tài Chính (Back Office)

#### A. Phòng Hành chính Nhân sự (HR Department)
* `HR_L1` - **NVHR (Nhân viên Nhân sự):** Quản lý hồ sơ nhân sự, dữ liệu chấm công, theo dõi hợp đồng lao động, nhập liệu KPI cơ bản.
* `HR_L2` - **TPHR (Trưởng phòng Nhân sự):** Phê duyệt đánh giá KPI toàn công ty, quản trị hạn ngạch nhân sự (Headcount), xét duyệt đề xuất tăng lương/thưởng trình BOD.

#### B. Phòng Tài chính - Kế toán (Finance & Accounting)
* `FIN_L1` - **Kế toán viên:** 
  * Đối soát lệnh nạp/rút tiền tài khoản quảng cáo (Top-up/Refund).
  * Kiểm tra chứng từ, ủy nhiệm chi, rà soát Timesheet và chi phí trực tiếp của từng dự án.
* `FIN_L2` - **Kế toán trưởng:** 
  * Phê duyệt lệnh chi và giải ngân.
  * Chốt số liệu đối soát doanh thu, công nợ nền tảng (Meta/Google/TikTok).
  * Lập báo cáo tài chính nội bộ định kỳ gửi CFO/BOD.

---

### 3. Phòng Kinh Doanh (Sales Department)
Áp dụng thang bậc 5 cấp (L1 - L5) phục vụ phân bổ chỉ tiêu doanh số và tính hoa hồng (Commission):
* `SALES_L1` - **Intern Sales:** Thực tập sinh kinh doanh, hỗ trợ tìm kiếm data khách hàng.
* `SALES_L2` - **NVKD (Sales Executive):** Chuyên viên kinh doanh trực tiếp tư vấn, chốt hợp đồng MKT và dịch vụ Cho thuê TKQC.
* `SALES_L3` - **TNKD (Trưởng nhóm Kinh doanh - Team Leader):** Quản lý nhóm kinh doanh, chịu trách nhiệm KPI nhóm, hỗ trợ xử lý deal lớn.
* `SALES_L4` - **TPKD (Trưởng phòng Kinh doanh):** Quản lý toàn bộ chỉ tiêu doanh số phòng Sales, xây dựng chính sách bán hàng.
* `SALES_L5` - **GDKD (Giám đốc Kinh doanh):** *(Vị trí quy hoạch - Tạm thời báo cáo trực tiếp BOD)*.

---

### 4. Phòng Vận Hành Dự Án & Marketing Nội Bộ (Operations & Internal Brand)
* **Cơ chế đặc thù:** Đảm nhiệm song song hai luồng dự án: **Dự án Khách hàng (Client Projects)** và **Dự án Nội bộ (BC Agency Projects)**.
* **Quản lý phòng:** Vị trí **Strategic Planner Team Leader** kiêm nhiệm Quyền Trưởng phòng Vận hành, chịu trách nhiệm điều phối nguồn lực chung và tiến độ thực thi.
* **Khung năng lực 5 cấp bậc:**
  * `L1`: Intern (Thực tập sinh)
  * `L2`: Junior (Chuyên viên sơ cấp)
  * `L3`: Executive (Chuyên viên)
  * `L4`: Senior (Chuyên viên cao cấp)
  * `L5`: Team Leader (Trưởng nhóm chuyên môn)

| Mã vai trò | Chức danh chuyên môn | Mô tả trách nhiệm chính trên ERP |
| :--- | :--- | :--- |
| `OPS_PLAN` | **Strategic Planner** | Lên chiến lược tổng thể dự án, phân bổ ngân sách, duyệt đề xuất concept; kiêm điều phối chung (`L5`). |
| `OPS_AM` | **Account Manager** | Đầu mối giao tiếp khách hàng, quản lý tiến độ hợp đồng, nghiệm thu kết quả, bảo vệ SLA. |
| `OPS_CONT` | **Content Creator** | Sản xuất kế hoạch nội dung, bài viết, kịch bản video, thông điệp truyền thông. |
| `OPS_DES` | **Designer kiêm Photography** | Thiết kế key visual, ấn phẩm 2D/3D, chụp ảnh tư liệu và sản phẩm. |
| `OPS_EDIT` | **Editor kiêm Cameraman** | Quay dựng video ngắn, TVC, hậu kỳ âm thanh và kỹ xảo hình ảnh. |
| `OPS_ADS` | **Ads Specialist (Media Buyer)** | Triển khai, theo dõi, tối ưu chiến dịch quảng cáo đa kênh (Facebook, Google, TikTok). |

---

## PHẦN 2: TRIẾT LÝ THIẾT KẾ PHẦN MỀM (SYSTEM DESIGN PHILOSOPHY)

Chuyển hóa Tầm nhìn, Sứ mệnh và Giá trị cốt lõi của BC Agency thành quy chuẩn vận hành logic của ERP:

### 1. Triết lý "TÍN" & "Lan tỏa niềm tin" $\rightarrow$ Minh bạch dữ liệu & Nhật ký kiểm toán bất biến
* **Cơ chế Client Portal:** Cung cấp giao diện truy cập minh bạch cho khách hàng tự theo dõi: số dư ví TKQC, chi tiêu thực tế hàng ngày và tiến độ nghiệm thu task MKT theo thời gian thực.
* **Immutable Audit Log:** Mọi hành vi liên quan đến tiền bạc (nạp ví, đổi tỷ giá, chiết khấu, điều chỉnh số dư TKQC) và hợp đồng đều phải được ghi lại vĩnh viễn trong nhật ký hệ thống, không thể chỉnh sửa hay xóa bỏ.

### 2. Triết lý "TÂM" & "Vì sự lớn mạnh của thương hiệu" $\rightarrow$ Kiểm soát rủi ro chủ động & Chặn cứng sai sót
* **Financial Hard Stop:** Chặn hoàn toàn việc khởi tạo hoặc cấp phát tài khoản quảng cáo mới nếu chưa có xác nhận "Đã khớp tiền" từ Kế toán viên (`FIN_L1`). Nghiêm cấm cấp phát dựa trên trạng thái chờ duyệt.
* **Cảnh báo sớm ngưỡng an toàn:** Hệ thống tự động gửi thông báo đỏ khi số dư tài khoản quảng cáo của khách chạm ngưỡng tối thiểu (ngăn chặn đứt đoạn chiến dịch) hoặc khi tài khoản có dấu hiệu bất thường (die tài khoản).
* **Cảnh báo SLA Breach:** Tự động báo động đỏ tới Team Leader và Account Manager khi có task bị quá hạn (Overdue) hoặc phản hồi khách hàng chậm trễ so với cam kết hợp đồng.

### 3. Triết lý "TRÍ" & "Tích hợp công nghệ" $\rightarrow$ Tự động hóa triệt để & Quản trị dựa trên dữ liệu
* **Tự động đối soát chi tiêu:** Kết nối trực tiếp API của các nền tảng (Meta Graph API, Google Ads API, TikTok Business API) để tự động kéo số liệu chi tiêu hàng giờ, loại bỏ hoàn toàn việc đối soát thủ công bằng ảnh chụp màn hình.
* **Tự động hóa P&L theo thời gian thực:** Lợi nhuận ròng của từng dự án được tính toán tự động dựa trên:
  $$\text{Lợi nhuận ròng} = \text{Doanh thu dịch vụ} - (\sum \text{Giờ làm việc} \times \text{Chi phí nhân công theo Level} + \text{Chi phí Outsource} + \text{Chi phí Tools})$$

### 4. Triết lý "NHÂN" $\rightarrow$ Cân bằng tải nhân sự & Đánh giá công bằng dựa trên kết quả
* **Capacity Management (Kiểm soát quá tải):** Trực quan hóa khối lượng công việc của từng nhân sự từ L1 - L5. Hệ thống cảnh báo khi một nhân sự bị gán vượt quá 100% định mức giờ làm việc/tuần, bảo vệ nhân sự khỏi tình trạng quá tải (burnout).
* **Chấm KPI dựa trên số liệu thực:** KPI nhân sự không phụ thuộc vào cảm tính, được hệ thống tổng hợp tự động từ 3 trụ cột:
  * Tỷ lệ hoàn thành công việc đúng hạn (On-time Delivery Rate).
  * Khối lượng công việc đầu ra đạt chuẩn (Output Volume).
  * Mức độ hoàn thành cam kết mục tiêu của dự án (Project Target / SLA Delivery).

### 5. Triết lý "Dự án kép" (Client vs Internal) $\rightarrow$ Tách bạch nguồn lực & Định giá vốn chuẩn xác
* **Phân loại Timesheet bắt buộc:** Mọi giờ làm việc của nhân sự phòng Vận hành bắt buộc phải gắn nhãn:
  * `Client Billable`: Tính trực tiếp vào chi phí giá vốn (COGS) của dự án khách hàng tương ứng.
  * `Internal Non-billable`: Tính vào chi phí vận hành/marketing nội bộ của công ty.
* **Bảo toàn dữ liệu tài chính:** Ngăn chặn việc nhân sự làm dự án nội bộ nhưng tính giờ vào dự án khách hàng (làm sai lệch báo cáo lợi nhuận dự án) hoặc ngược lại.