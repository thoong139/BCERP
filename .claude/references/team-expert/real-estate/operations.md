# Real Estate Operations

> Reference file cho real-estate-expert agent
> Load file này khi cần phân tích quy trình vận hành BĐS và KPIs

---

## 1. Development Project Lifecycle

### Giai đoạn 1 — Chuẩn bị (3-24 tháng)
- M&A đất (thương lượng, thẩm định, ký hợp đồng chuyển nhượng)
- Thẩm định pháp lý (quy hoạch, hồ sơ đất, tranh chấp, nghĩa vụ tài chính)
- Quy hoạch 1/500 (thiết kế tổng mặt bằng, xin phê duyệt Sở Quy hoạch)
- Xin giấy phép xây dựng (Sở Xây dựng)
- Đủ điều kiện mở bán: Bảo lãnh ngân hàng + 1/500 được duyệt + đủ pháp lý

### Giai đoạn 2 — Xây dựng (12-36 tháng)
- Thi công móng, thô, hoàn thiện theo tiến độ cam kết
- Nghiệm thu từng hạng mục (ban quản lý, giám sát, chủ đầu tư)
- Kiểm tra chất lượng theo tiêu chuẩn TCVN
- Kiểm tra PCCC, thang máy, hệ thống kỹ thuật trước bàn giao

### Giai đoạn 3 — Kinh doanh (song song xây dựng)
- Mở bán (giỏ hàng, booking) — xem chi tiết §2 Sales Process
- Ký Hợp đồng đặt cọc (Deposit Agreement)
- Ký Hợp đồng mua bán (SPA / HĐMB)
- Thu tiền theo lịch đợt thanh toán

### Giai đoạn 4 — Bàn giao (3-6 tháng)
- Nghiệm thu tổng thể toàn bộ dự án
- Bàn giao từng căn hộ (biên bản bàn giao, bàn giao chìa khóa)
- Đăng ký nhà ở cho KH (nộp hồ sơ Sở TN&MT)
- Cấp Giấy chứng nhận quyền sở hữu (sổ đỏ/sổ hồng)

### Giai đoạn 5 — Vận hành (vô hạn)
- Bàn giao quản lý tòa nhà cho BQL (Ban quản lý)
- Property management: phí dịch vụ, bảo trì, tiện ích
- Cho thuê lại (nếu căn hộ chuyển sang rental)
- Tái bán (thị trường thứ cấp)

---

## 2. Sales Process Flow

### Chi tiết từng bước giao dịch BĐS

```
Bước 1: Giỏ hàng mở bán
  → Developer công bố giỏ hàng (danh sách căn, giá, chính sách)
  → Broker đăng ký tham gia (xét duyệt, ký hợp đồng phân phối)

Bước 2: Broker check inventory real-time
  → Tra cứu căn còn trống (floor plan grid, filter theo giá/tầng/diện tích)
  → Xem thông tin chi tiết căn: diện tích, hướng, view, giá, phí

Bước 3: Hold/Lock căn (24-48h)
  → Broker đặt hold cho KH đang quan tâm
  → Hệ thống lock căn, bắt đầu đếm ngược
  → KH được 24-48h quyết định

Bước 4: Đặt cọc (10-30 triệu)
  → KH chuyển khoản đặt cọc vào tài khoản escrow
  → Ngân hàng confirm nhận tiền → System cập nhật trạng thái → Lock confirmed
  → Nếu hết 48h chưa có tiền → auto-release căn

Bước 5: Ký Hợp đồng Đặt cọc (Deposit Agreement)
  → Chuẩn bị hồ sơ KH (CCCD, hộ khẩu, hôn nhân)
  → Legal clearance: KYC + AML check
  → Ký Hợp đồng đặt cọc (có thể ký điện tử hoặc trực tiếp)

Bước 6: Ký Hợp đồng Mua bán (SPA)
  → Hoàn thiện hồ sơ pháp lý
  → Ký HĐMB tại văn phòng công chứng
  → Nộp thuế, phí công chứng

Bước 7: Thu tiền theo đợt (tiến độ thanh toán)
  → Hệ thống generate lịch đợt theo HĐMB
  → Reminder tự động 7 ngày và 1 ngày trước due date
  → KH thanh toán → Bank confirm → System ghi nhận
  → Lãi phạt nếu chậm (theo điều khoản HĐMB)

Bước 8: Bàn giao căn hộ
  → Developer hoàn thiện xây dựng, nghiệm thu
  → Thông báo bàn giao cho KH
  → KH kiểm tra căn, ký biên bản bàn giao
  → KH đóng đợt cuối (khoảng 5-10% còn lại trước sổ)

Bước 9: Cấp Giấy chứng nhận (sổ đỏ/sổ hồng)
  → Developer nộp hồ sơ tại Sở TN&MT
  → Theo dõi tiến độ (thường 3-12 tháng)
  → Nhận sổ, bàn giao cho KH
  → KH đóng đợt cuối cùng (nếu có đợt gắn với sổ)
```

### Lịch Thanh toán Điển hình (VN BĐS — Căn hộ chung cư)

| Đợt | Mốc | % GTCH | Ví dụ (căn 3 tỷ) |
|-----|-----|--------|------------------|
| Đặt cọc | Ký thỏa thuận đặt cọc | 5% | 150 triệu |
| Đợt 1 | Ký HĐMB | 20% | 600 triệu |
| Đợt 2 | Hoàn thành móng | 15% | 450 triệu |
| Đợt 3 | Hoàn thành kết cấu | 15% | 450 triệu |
| Đợt 4 | Hoàn thiện (trước bàn giao) | 20% | 600 triệu |
| Đợt 5 | Bàn giao căn hộ | 20% | 600 triệu |
| Đợt 6 | Nhận sổ đỏ | 5% | 150 triệu |

---

## 3. Property Management Cycle

### Vòng đời Hợp đồng Thuê

```
Ký hợp đồng thuê (Lease Agreement)
  → Thời hạn: 1-3 năm (residential), 3-5 năm (commercial)
  → Điều khoản: tiền thuê, cọc (2-3 tháng), tăng giá, termination

Check-in & Handover
  → Inventory checklist (đồ đạc, thiết bị, trạng thái)
  → Ảnh toàn bộ căn trước khi vào
  → Bàn giao chìa khóa, thẻ từ, remote

Vận hành hàng tháng
  → Auto-billing: Phí quản lý + Điện + Nước + Đỗ xe (xuất hóa đơn ngày 25)
  → Reminder thanh toán: D-3, D+1, D+7
  → Maintenance requests: xử lý theo SLA (xem §3.2)

Thanh tra định kỳ
  → Quarterly inspection: kiểm tra trạng thái căn, thiết bị
  → Báo cáo tình trạng, lên kế hoạch bảo trì phòng ngừa

Gia hạn / Không gia hạn
  → Alert 90 ngày trước hết hạn: offer gia hạn
  → Negotiation: giá mới, điều khoản cập nhật
  → Nếu không gia hạn: thông báo check-out 30-60 ngày trước

Check-out
  → Move-out inspection: so sánh với check-in
  → Xử lý damages (trừ vào cọc nếu cần)
  → Hoàn trả cọc (trong 7-14 ngày sau check-out)
  → Cập nhật unit status → Available
```

### Maintenance Request Workflow

```
Bước 1: Tenant gửi request (portal/app/hotline)
  → Mô tả vấn đề, upload ảnh, chọn location (phòng/khu vực)

Bước 2: Phân loại & Ưu tiên
  → Emergency (nước tràn, điện hỏng): < 2h response
  → High (điều hòa hỏng, thang máy): < 24h
  → Normal (bóng đèn, tivi): < 72h
  → Low (cosmetic issues): < 7 ngày

Bước 3: Assignment
  → Kỹ thuật nội bộ hoặc vendor bên ngoài
  → Confirm lịch hẹn với tenant

Bước 4: Execution & Documentation
  → Kỹ thuật cập nhật progress (in-progress)
  → Ảnh before/after khi hoàn thành
  → Ghi nhận vật tư sử dụng, chi phí

Bước 5: Close & Verification
  → Tenant confirm đã xử lý xong (portal)
  → Nếu không satisfied → escalate
  → Close request, ghi nhận vào lịch sử unit

Status: Submitted → Assigned → In Progress → Completed → Verified → Closed
```

---

## 4. Broker Commission Structure (Thị trường VN)

### Cơ cấu Hoa hồng

| Kênh | Tỷ lệ | Điều kiện nhận | Ghi chú |
|------|-------|----------------|---------|
| Developer → Sàn phân phối | 1.5-3% GTCH | KH ký HĐMB + đóng 30-50% | Tùy dự án, đợt mở bán |
| Sàn phân phối → Broker | 60-80% của tỷ lệ trên | Theo thỏa thuận sàn | Thường 70/30 hoặc 80/20 |
| Clawback period | 30-60 ngày từ ký HĐMB | Nếu KH hủy → hoàn lại | Broker phải trả lại |

### Quy trình Phê duyệt và Thanh toán

```
1. Hợp đồng ký xong + Deposit cleared
2. KD team tính commission (theo policy bảng hoa hồng đợt)
3. Kế toán verify (số liệu, điều kiện đủ để tính)
4. Giám đốc approve (dual control)
5. Chuyển khoản cho sàn/broker
6. Phát statement cho broker (tự xem online)
```

---

## 5. KPIs Ngành BĐS

### Developer KPIs

| KPI | Công thức | Target | Cảnh báo |
|-----|-----------|--------|----------|
| Absorption Rate | Số căn đã bán / Tổng giỏ hàng × 100% | > 70% sau 6 tháng mở bán | < 50% |
| Collection Rate | Số tiền thu đúng hạn / Tổng phải thu × 100% | > 90% | < 80% |
| Legal Completion Rate | Hồ sơ sổ đỏ hoàn thành đúng hẹn / Tổng × 100% | > 85% | < 70% |
| Construction Progress | % hoàn thành vs kế hoạch | Đúng tiến độ ±5% | Chậm > 10% |

### Property Management KPIs

| KPI | Công thức | Target | Cảnh báo |
|-----|-----------|--------|----------|
| Occupancy Rate | Số căn đang cho thuê / Tổng căn × 100% | > 90% | < 80% |
| Maintenance Response Time | Thời gian từ submit đến xử lý xong (theo category) | Emergency <2h, Normal <72h | Vượt SLA > 20% requests |
| Collection Rate (PM) | Phí thu đúng hạn / Tổng phải thu × 100% | > 95% | < 88% |
| Tenant Retention Rate | Số hợp đồng gia hạn / Tổng hết hạn × 100% | > 70% | < 60% |
| RevPAU | Doanh thu tháng / Tổng số căn | Benchmark thị trường | Giảm 10% vs cùng kỳ |
