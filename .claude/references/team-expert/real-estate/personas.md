# Real Estate User Personas

> Reference file cho real-estate-expert agent
> Load file này khi cần hiểu về users trong domain Bất động sản

## Danh sách Personas

### 1. Chủ đầu tư / Developer

**Profile:**
- Chức danh: Developer / Chủ đầu tư / Giám đốc Dự án
- Kinh nghiệm: Senior level (10+ năm)
- Technical skill: Low-Medium — cần dashboard trực quan, không thích detail
- Tần suất sử dụng hệ thống: Daily review, weekly deep dive

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Review tỷ lệ hấp thụ theo dự án | 1 lần/ngày | 15 phút | High |
| Theo dõi tiến độ thu tiền đợt | 1 lần/ngày | 20 phút | High |
| Báo cáo tiến độ xây dựng | 2 lần/tuần | 30 phút | High |
| Review pháp lý (giấy phép, sổ đỏ) | 1 lần/tuần | 1 giờ | High |
| Phê duyệt chính sách giá/chiết khấu | Ad-hoc | 20 phút/item | Critical |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Mở bán đợt mới | Tỷ lệ hấp thụ đợt hiện tại, thị trường | Doanh thu, inventory | Yes - absorption dashboard |
| Điều chỉnh giá bán | Absorption rate, cạnh tranh, cost | Revenue forecast | Yes - price simulation |
| Chính sách chiết khấu đặc biệt | Tốc độ bán, cash flow | Commission impact | Yes - approval workflow |
| Timeline bàn giao | Tiến độ xây dựng | Legal liability, KH satisfaction | Yes - milestone tracking |

**Pain Points:**
1. **No real-time absorption view**: Không biết còn bao nhiêu căn, bán được bao nhiêu real-time
2. **Multi-source reports**: Báo cáo từ nhiều sàn không đồng nhất, phải manual reconcile
3. **Collection manual reconciliation**: Không biết KH nào chưa đóng đợt, lý do tại sao
4. **Legal status blind spot**: Không track được tiến độ pháp lý từng căn (công chứng, sổ)

**Must-have Features:**
- Real-time sales dashboard (absorption rate, giỏ hàng còn, đã bán)
- Tiến độ thu tiền theo đợt với aging analysis
- Integration với ngân hàng bảo lãnh (bank guarantee status)
- Legal milestone tracker per căn hộ

---

### 2. Nhân viên Kinh doanh BĐS / Broker

**Profile:**
- Chức danh: Sales Agent / Môi giới BĐS / Broker
- Kinh nghiệm: Entry to Mid level (1-7 năm)
- Technical skill: Medium — dùng điện thoại là chính, cần mobile-friendly
- Tần suất sử dụng hệ thống: Daily (on-site và off-site)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Check inventory còn trống | 10-20 lần/ngày | 2 phút/lần | High |
| Tư vấn và demo căn cho KH | 3-8 KH/ngày | 30-60 phút/KH | High |
| Đặt hold/booking cho KH | 2-5 lần/ngày | 10 phút/booking | High |
| Theo dõi trạng thái deal | 1 lần/ngày | 20 phút | High |
| Check hoa hồng cá nhân | 1 lần/tuần | 10 phút | Medium |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Sản phẩm nào phù hợp KH | Budget KH, nhu cầu, inventory | Close rate | Yes - search/filter inventory |
| Mức giá negotiate được | Policy đợt mở bán, discount matrix | Commission, revenue | Yes - discount rules display |
| Khi nào push close | KH signal, inventory urgency | Lost deal vs rush | Yes - hold timer countdown |
| Nên hold thêm hay release | Hold expiry, KH interest | Inventory utilization | Yes - hold management |

**Pain Points:**
1. **Inventory blind**: Không biết căn nào còn trống real-time — phải gọi điện văn phòng
2. **Double booking**: Hai broker cùng book một căn, gây conflict và mất KH
3. **Hold/release thủ công**: Giữ chỗ qua Zalo/điện thoại, dễ nhầm, dễ mất
4. **Hoa hồng tính chậm**: Không biết hoa hồng được tính thế nào, bao giờ nhận

**Must-have Features:**
- Real-time inventory grid (floor plan view, màu sắc theo status)
- Instant booking/hold với countdown timer
- Commission tracker cá nhân (real-time, minh bạch)
- Mobile app với offline capability khi show nhà

---

### 3. Khách hàng Mua / Người thuê

**Profile:**
- Chức danh: End-buyer / Tenant / Người mua / Người thuê
- Kinh nghiệm: Không có background BĐS chuyên sâu
- Technical skill: Medium — dùng smartphone thành thạo
- Tần suất sử dụng hệ thống: Sporadic — cao điểm lúc đang giao dịch

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Tra cứu thông tin căn hộ | Nhiều lần/ngày (giai đoạn tìm kiếm) | 15-30 phút | High |
| Theo dõi tiến độ thanh toán | 1-2 lần/tháng | 10 phút | High |
| Kiểm tra tài liệu pháp lý | Ad-hoc | 20-30 phút | High |
| Nhận thông báo bàn giao | Ad-hoc (event-based) | 5 phút | Critical |
| Gửi yêu cầu bảo trì | Ad-hoc (sau bàn giao) | 10 phút | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Chọn căn nào | Giá, view, diện tích, tầng | Tài chính dài hạn | Yes - compare units tool |
| Chọn kế hoạch thanh toán | Cash flow cá nhân | Gánh nặng tài chính | Yes - installment simulator |
| Có nên thuê dịch vụ bổ sung | Chi phí vs tiện ích | Trải nghiệm sống | Yes - service catalog |

**Pain Points:**
1. **Tiến độ bàn giao mù mờ**: Không biết nhà xây đến đâu, bao giờ nhận
2. **Phải gọi điện hỏi**: Muốn biết bất cứ điều gì đều phải liên hệ broker/chủ đầu tư
3. **Giấy tờ phức tạp**: Không hiểu quy trình pháp lý, ai làm gì, bao giờ xong
4. **Thanh toán nhầm đợt**: Không có lịch rõ ràng, dễ đóng thiếu hoặc chậm

**Must-have Features:**
- Customer portal: tiến độ xây dựng, lịch thanh toán, tài liệu pháp lý, thông báo bàn giao
- Digital document repository (HĐMB, biên lai, sổ đỏ scan)
- Maintenance request portal (sau khi nhận nhà)
- Push notification cho các mốc quan trọng

---

### 4. Property Manager / Quản lý Tòa nhà

**Profile:**
- Chức danh: Property Manager / Trưởng BQL Tòa nhà / Quản lý Vận hành
- Kinh nghiệm: Mid to Senior level (5-10 năm)
- Technical skill: Medium — thoải mái với phần mềm, cần desktop + mobile
- Tần suất sử dụng hệ thống: Daily (full day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Xử lý yêu cầu bảo trì | 5-20 requests/ngày | 10-30 phút/request | High |
| Thu phí quản lý hàng tháng | Tập trung đầu tháng | 2-4 giờ/ngày | High |
| Coordinate với vendors/kỹ thuật | 3-10 lần/ngày | 15 phút/lần | High |
| Check occupancy và hợp đồng sắp hết | 1 lần/ngày | 20 phút | High |
| Báo cáo cho Ban quản trị | 1 lần/tuần | 1 giờ | Medium |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Ưu tiên bảo trì nào trước | Severity, safety impact, tenant complaint | Tenant satisfaction, cost | Yes - priority queue + SLA |
| Vendor nào dùng | Price, quality history, availability | Cost, quality | Yes - vendor performance tracking |
| Escalate vấn đề gì | Complexity, cost threshold | Resolution time | Yes - escalation workflow |
| Có cho gia hạn hợp đồng | Tenant history, market rate | Vacancy rate, revenue | Yes - renewal alerts |

**Pain Points:**
1. **Yêu cầu bảo trì qua điện thoại**: Không track được, dễ mất, không có lịch sử
2. **Thu phí thủ công**: Gõ Excel, nhắc nhở qua điện thoại, không scalable
3. **Vendor quản lý rời rạc**: Không biết vendor nào đang xử lý gì, chất lượng thế nào
4. **Occupancy blind**: Không có dashboard tổng, phải mở từng file để check

**Must-have Features:**
- Maintenance request portal với SLA tracking và photo evidence
- Auto-billing hàng tháng (phí dịch vụ, điện, nước, đỗ xe)
- Vendor management với performance history
- Occupancy dashboard + lease renewal alerts

---

### 5. Pháp chế / Legal Officer BĐS

**Profile:**
- Chức danh: Legal Officer / Pháp chế BĐS / Chuyên viên Pháp lý
- Kinh nghiệm: Mid to Senior level (5-10 năm luật BĐS)
- Technical skill: Medium — thoải mái với word processor, cần desktop
- Tần suất sử dụng hệ thống: Daily (6-8 hours/day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Kiểm tra pháp lý hồ sơ KH | 5-15 hồ sơ/ngày | 20-30 phút/hồ sơ | High |
| Chuẩn bị và review HĐMB | 3-10 HĐ/ngày | 30-60 phút/HĐ | High |
| Track tiến độ công chứng/sang tên | 1 lần/ngày | 30 phút | High |
| Phối hợp với VP công chứng | 3-5 lần/ngày | 15 phút/lần | High |
| Báo cáo tiến độ pháp lý sổ đỏ | 1 lần/tuần | 1 giờ | Medium |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Hồ sơ đủ điều kiện ký HĐMB chưa | Checklist pháp lý, AML check | Legal risk, transaction proceed | Yes - legal checklist per KH |
| Công chứng viên nào | Availability, location, cost | Turnaround time | Yes - notary scheduler |
| Escalate vướng mắc pháp lý | Complexity, risk level | Timeline, developer liability | Yes - issue tracker |

**Pain Points:**
1. **Hồ sơ giấy tờ phân tán**: KH gửi qua email, Zalo, trực tiếp — không có nơi tập trung
2. **Không biết KH đang ở bước nào**: Phải hỏi từng người trong team
3. **Thủ tục sang tên chậm**: Sở địa chính chậm, không có visibility tiến độ
4. **Template HĐ manual**: Điền tay vào template Word, dễ sai, tốn thời gian

**Must-have Features:**
- Legal checklist per khách hàng (dynamic, có tick đủ điều kiện mới cho tiếp)
- Document repository với version control và access log
- Workflow tracking: Đặt cọc → HĐMB → Công chứng → Bàn giao → Nộp sổ → Nhận sổ
- Template generation (merge fields từ unit/KH data vào HĐMB template)

---

## Quick Reference

| Persona | Primary Focus | Key Metric |
|---------|---------------|------------|
| Chủ đầu tư / Developer | Tỷ lệ hấp thụ, thu tiền đợt | Absorption rate, Collection rate |
| Broker / Sales Agent | Booking, commission | Close rate, Commission earned |
| Khách hàng / Buyer | Thông tin minh bạch | Satisfaction, on-time payment |
| Property Manager | Vận hành tòa nhà | Occupancy rate, Maintenance SLA |
| Legal Officer | Pháp lý đúng hạn | Legal completion rate |
