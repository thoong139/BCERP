# QUY TRÌNH VÒNG ĐỜI DỰ ÁN MARKETING TỔNG THỂ (LIFECYCLE V6.0)
**Mã tài liệu:** `01_Quy_trinh_MKT_Tong_the.md`  
**Đơn vị áp dụng:** BC Agency (Khối Kinh doanh & Khối Vận hành Dự án)  
**Nguyên tắc vận hành cốt lõi:**  
- *Sales Phase:* Sales thực thi — Vận hành theo dõi (Observe).  
- *Operations & Deploy Phase:* Vận hành thực thi — Sales theo dõi (Observe).  
- *Cơ chế chặn cứng (Hard Gates):* Không nhảy bước; chỉ chuyển giai đoạn khi thỏa mãn 100% Entry/Done Criteria.

---

## GIAI ĐOẠN 1: SALES PHASE (TIẾP NHẬN & SÀNG LỌC LEAD)

### 1. RAW DATA (Khởi tạo Lead)
* **Mục tiêu:** Tiếp nhận thông tin thô từ mọi nguồn (Landing page, Zalo, Fanpage, Referral, Cold outreach, v.v.).
* **Hành vi hệ thống:** Tìm kiếm chống trùng lặp (Anti-duplicate) $\rightarrow$ Tạo Project Record mới trên PMS trong vòng 24h.
* **Quy tắc cứng:** "Không ghi nhận vào PMS = Không tồn tại".

### 2. INITIAL BRIEF SENT & RECEIVED (Test độ nghiêm túc)
* **Gửi Brief sơ bộ:** Gửi form khảo sát ngắn (Zalo ưu tiên) trong 24h.
* **Xác nhận hoàn tất:** Trong 2h làm việc, kiểm tra đủ 3 trường tối thiểu: *Ngân sách*, *Sản phẩm*, *Nhu cầu thật*. Đủ điều kiện $\rightarrow$ Kích hoạt `AUTO SCORING`.

### 3. AUTO SCORING (Chấm điểm & Xếp Tier tự động)
Hệ thống tự động quét Knockout Rules và chấm 5 tiêu chí:
* **Knockout Rules (K1 – K5 $\rightarrow$ AUTO LOST ngay):**
  * `K1`: SP vi phạm chính sách quảng cáo nền tảng.
  * `K2`: Yêu cầu cam kết KPI cứng ("không đạt ROAS không thanh toán").
  * `K3`: Tranh chấp/kiện tụng pháp lý công khai.
  * `K4`: Đòi ứng tiền chạy trước $\rightarrow$ Tư vấn quy trình, nếu không chấp nhận $\rightarrow$ LOST.
  * `K5`: Spy lấy quy trình, thiếu thiện chí cung cấp thông tin.
* **Cờ cảnh báo Quản lý (K6 – K12 $\rightarrow$ FLAG SM Review trong 4h):** Brand lớn, CEO yêu cầu gặp gấp, lịch sử nhảy $\ge 3$ agency/12 tháng, timeline gấp $<2$ tuần.
* **Trọng số chấm điểm CQ (Thang 1–5):**
  * Nhu cầu/KPI dựa trên data thực tế: 30%
  * Khả năng chi trả ngân sách: 25%
  * Thẩm quyền quyết định của người liên hệ: 20%
  * Nhu cầu nguồn lực (càng cần MKT tổng thể điểm càng cao): 15%
  * Tính pháp lý & sản phẩm: 10%
* **Xếp Tier sơ bộ:** `Tier A` ($<1.5$đ) $\rightarrow$ AUTO LOST; `Tier B/C` ($1.5 - 2.99$đ) $\rightarrow$ First Meeting bắt buộc; `Tier D/E` ($\ge 3.0$đ) $\rightarrow$ SM có quyền duyệt bypass First Meeting.

### 4. FIRST MEETING & FULL BRIEF RECEIVED
* **First Meeting (30–45p):** Lắng nghe nhu cầu ($\ge 70\%$ thời lượng để KH nói), xác định Decision Maker và kỳ vọng KPI. Tuyệt đối không trình bày chiến lược hay báo giá.
* **Full Brief (8 sections):** Hỗ trợ KH điền chi tiết: (1) Bối cảnh, (2) Sản phẩm/USP, (3) Giá/Chính sách, (4) Kênh phân phối, (5) Chân dung KH, (6) KPIs kỳ vọng, (7) Scope of Work, (8) Ngân sách & Timeline.

### 5. QUALIFIED (Decision Gate 1 — Cổng phê duyệt Go/No-Go)
* Sales Executive chấm lại điểm CQ lần 2 (`qualifiedTier`) dựa trên Full Brief.
* **Tiêu chuẩn Qualify:** Đã khai thác đủ thông tin + KH đồng ý Pitching + KH có thiện chí đàm phán ngân sách/KPI.
* **Thẩm quyền:** **Sales Manager (SM) bắt buộc ký duyệt Go/No-Go.** (SLA: 1 ngày làm việc).

### 6. LEAD (Decision Gate 2 — Bàn giao sang Vận hành)
* Điền Handoff Package gồm 5 nhóm checklist:
  1. *Hồ sơ KH:* Pháp nhân, đầu mối liên hệ chính + dự phòng, full brief.
  2. *Tài chính:* Dự toán phí DV, NSQC ước tính, phương thức thanh toán.
  3. *Kỳ vọng & Scope:* KPI mục tiêu (không cam kết cứng), phạm vi kênh sơ bộ.
  4. *Nội bộ:* Phân bổ Account Manager (AM) chính thức, xác nhận Capacity trống.
  5. *Pháp lý & Rủi ro:* Xác nhận không vướng policy hay tranh chấp.
* SM ký duyệt bàn giao $\rightarrow$ AM xác nhận tiếp nhận $\rightarrow$ Khép lại Sales Phase. (SLA: 4h làm việc).

---

## GIAI ĐOẠN 2: OPERATIONS & PROPOSAL PHASE (ĐÁNH GIÁ & ĐỀ XUẤT)

### 1. EVALUATION (Vận hành thẩm định năng lực)
* **Brand Safety Hard Stop (Kiểm tra 7 tiêu chí):** Pháp lý SP, chính sách quảng cáo nền tảng, Luật Quảng cáo VN, claim y tế/công dụng, tranh chấp nhãn hiệu, không làm fake review, không xung đột lợi ích với client hiện tại. *Fail 1 tiêu chí $\rightarrow$ Từ chối ngay (LOST chủ động).*
* **Weighted Scoring (Thang 5 điểm — Pass $\ge 3.5$):**
  * KPI Feasibility (20%) + Resource Capacity (15%) + Client Collaboration (15%) + Service Fit (10%) + Track Record (10%) + Tech Readiness (10%) + Creative Assets (10%) + Timeline (5%) + Profitability (5%).
  * *Borderline (3.0 – 3.49):* AM Lead (Tier A/B/C) hoặc Account Director (Tier D/E) thẩm định trong 4h.

### 2. INTERNAL QUICK MEETING & SECOND MEETING
* **Quick Meeting (15–30p nội bộ):** Sales bàn giao trực tiếp sắc thái KH cho AM và Planner; thống nhất vai trò trước khi gặp KH.
* **Second Meeting (Gặp gỡ chuyên sâu):** AM chủ trì tiếp quản quan hệ, Sales chuyển sang Observe.
* **5 Output bắt buộc:** (1) Meeting notes chi tiết, (2) Giải quyết các điều kiện tồn đọng từ Evaluation, (3) Xác nhận rõ ràng IN/OUT of scope, (4) Re-align KPI giai đoạn (tháng 1 là testing, tháng 3 là tối ưu), (5) Thống nhất quy trình làm việc và đầu mối duy nhất là AM.

### 3. PROPOSAL & REHEARSAL
* **Soạn Proposal nội bộ:**
  * *Tier B/C:* AM tự soạn (8–12 trang), tập trung vào kế hoạch thực thi và ngân sách.
  * *Tier D/E:* Planner chủ trì soạn (15–25 trang), phân tích sâu thị trường, persona, creative framework, media mix và case study.
  * *Tier E Big Corp:* Bổ sung hồ sơ nhân sự (Team Bios), bảo mật dữ liệu, quy trình Brand Safety và rà soát điều khoản hợp đồng.
* **Rehearsal (Pitching thử nội bộ):** AM + Planner + Creative Lead phản biện, rà soát slide KPI (quy đổi sang giá trị doanh thu), duyệt giá với Quản lý và chuẩn bị kịch bản xử lý từ chối (Q&A Script).
* **Gửi & Review Proposal:** Gửi file v1.0 qua link Google Drive. Giới hạn số lần chỉnh sửa: Tier B/C $\le 2$ vòng; Tier D/E $\le 4$ vòng.

### 4. PITCHING $\rightarrow$ QUOTATION $\rightarrow$ NEGOTIATION $\rightarrow$ WON
* **Pitching (60–90p):** AM dẫn dắt trình bày, thuyết phục KH dựa trên bài toán kinh doanh.
* **Quotation (Báo giá chính thức):** Accountant tính giá theo định mức; Quản lý duyệt biên lợi nhuận (Gross Margin) $\rightarrow$ AM gửi báo giá chính thức trong vòng 2 ngày.
* **Negotiation:** Đàm phán điều khoản, chính sách thanh toán và chốt tần suất báo cáo (Reporting Frequency: Daily / Weekly / Monthly).
* **WON Deal:** Ký HĐ/LOI. Cập nhật trạng thái WON trên PMS trong 24h $\rightarrow$ Thiết lập nhóm dự án $\rightarrow$ Chuyển sang giai đoạn Triển khai.

---

## GIAI ĐOẠN 3: DEPLOY PHASE (ONBOARDING & CHUẨN BỊ TRIỂN KHAI)