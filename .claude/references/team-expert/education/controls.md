# Education Domain - Controls & Compliance

> **Domain**: Giáo dục & Ed-tech
> **Last Updated**: 2026-04-13

---

## 1. Grade Entry Authority

### Phân quyền chỉnh sửa điểm

| Bước | Actor | Hành động | Điều kiện |
|------|-------|-----------|-----------|
| Entry | Teacher | Nhập điểm vào system | Trong grade window |
| Review | Department Head | Xem xét, flag outliers | Trước khi publish |
| Approval | Academic Director | Final approval, publish | Sau review |
| Lock | System | Tự động khóa sau publish | — |
| Unlock | Academic Director only | Mở lock khi có appeal | Trong appeal window |

### Outlier Detection
- Class average > 9.0 hoặc < 4.0 → auto-flag cho Department Head
- Grade change sau khi nhập lần đầu → audit log bắt buộc

---

## 2. Academic Integrity Controls

### Online Exam Security
| Control | Mô tả |
|---------|-------|
| Browser lockdown | Ngăn mở tab khác trong khi thi |
| Time limit | Đếm ngược, auto-submit khi hết giờ |
| Question randomization | Mỗi student nhận bộ câu hỏi khác thứ tự |
| Answer shuffling | Thứ tự đáp án khác nhau |
| Tab-switch detection | Cảnh báo khi rời khỏi cửa sổ thi |
| Webcam proctoring | Tùy chọn — cho kỳ thi quan trọng |

### Plagiarism Detection
| Control | Áp dụng |
|---------|---------|
| Cross-student comparison | So sánh bài nộp giữa các học sinh trong cùng lớp |
| Turnitin integration | Kiểm tra online sources (nếu subscribed) |
| Similarity threshold | > 30% → flag cho instructor review |

### Retake Policy
- Mặc định: tối đa 1 lần retake per course (configurable)
- Retake fee: áp dụng cho exam formal (trường chính thức)
- Grade taken: max(original, retake) hoặc average (configurable)

---

## 3. Data Privacy for Minors (Học sinh < 18 tuổi)

### Nghị định 13/2023/NĐ-CP — Children's Personal Data

| Quy tắc | Mô tả |
|---------|-------|
| Parental consent | Mọi xử lý dữ liệu trẻ em cần consent phụ huynh |
| Photo/video | Không dùng ảnh học sinh cho marketing mà không có consent |
| Third-party sharing | Học sinh data không chia sẻ với đối tác/quảng cáo |
| Parent access | Phụ huynh có quyền xem toàn bộ data của con < 18 |
| Data breach | Phải thông báo phụ huynh trong 72h nếu có breach |

### Data Retention
| Loại dữ liệu | Thời hạn lưu |
|-------------|-------------|
| Student academic records | 20 năm sau khi tốt nghiệp |
| Attendance records | 5 năm |
| Financial records | 10 năm (theo Luật Kế toán) |
| Exam papers | 1 năm sau khi điểm publish |

---

## 4. Attendance Override Authority

| Tình huống | Người có quyền | Giới hạn |
|------------|----------------|---------|
| Vắng có phép (y tế, gia đình) | Teacher | Tối đa 20% buổi học |
| Vắng > 20% có phép | Department Head | Không giới hạn nếu có lý do hợp lệ |
| Attendance threshold override | Academic Director | Trường hợp đặc biệt |

### Ngưỡng điểm danh bắt buộc (VN Higher Education)
- Tối thiểu 70% buổi học → mới được dự thi (Thông tư 08/2021/TT-BGDĐT)
- Alert tự động khi học sinh còn 2 buổi vắng trước ngưỡng

---

## 5. Financial Aid & Scholarship Controls

| Bước | Mô tả |
|------|-------|
| Application | Committee review → Recommendation → Approval |
| Disbursement | Direct to school account (không chuyển thẳng cho học sinh) |
| Conditions | GPA threshold maintained → auto-review if GPA drops |
| Refund policy | 100% trước ngày học, 50% trong tuần đầu, 0% sau 1 tuần |

---

## 6. Access Control Matrix (Role-Based)

| Function | Student | Teacher | Parent | Academic Admin | Academic Director |
|----------|:-------:|:-------:|:------:|:--------------:|:-----------------:|
| View own grades | ✅ | ❌ | ✅ (child) | ✅ | ✅ |
| Enter grades | ❌ | ✅ | ❌ | ❌ | ❌ |
| Approve/publish grades | ❌ | ❌ | ❌ | ❌ | ✅ |
| Unlock grades | ❌ | ❌ | ❌ | ❌ | ✅ |
| View all student data | ❌ | ⚠ Own class | ⚠ Own child | ✅ | ✅ |
| Generate transcript | ❌ | ❌ | ⚠ Request | ✅ | ✅ |
| Override attendance | ❌ | ✅ (≤20%) | ❌ | ❌ | ✅ |
| Manage enrollment | ❌ | ❌ | ⚠ Own child | ✅ | ✅ |

---

## 7. Compliance Requirements (VN)

### Trường chính thức (K-12, ĐH, CĐ)
| Yêu cầu | Nguồn |
|---------|-------|
| Báo cáo số lượng học sinh định kỳ | Thông tư Bộ GD&ĐT |
| Lưu bảng điểm vĩnh viễn (phổ thông) | Quy chế Bộ GD&ĐT |
| Điểm danh ≥ 70% để dự thi | Thông tư 08/2021/TT-BGDĐT |
| Data privacy cho học sinh < 18 | Nghị định 13/2023/NĐ-CP |
| Luật Giáo dục 43/2019 | Giấy phép hoạt động, chương trình khung |

### Trung tâm đào tạo (language center, skills center)
| Yêu cầu | Nguồn |
|---------|-------|
| Giấy phép hoạt động dạy nghề | Luật Giáo dục nghề nghiệp 74/2014 |
| Hợp đồng đào tạo bắt buộc | Luật Bảo vệ người tiêu dùng |
| Cam kết chất lượng (nếu quảng cáo) | Luật Quảng cáo |
