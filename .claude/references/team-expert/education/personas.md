# Education Domain - User Personas

> **Domain**: Giáo dục & Ed-tech
> **Last Updated**: 2026-04-13

---

## Persona 1: Student / Học viên

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Người học (K-12 / University / Corporate / Language Center) |
| **Focus** | Hoàn thành khóa học, đạt chứng chỉ, theo dõi tiến độ |

### Daily Tasks
1. Truy cập bài học (video, tài liệu, quiz)
2. Nộp bài tập, làm bài kiểm tra
3. Xem điểm và feedback từ giáo viên
4. Tham gia live session, đặt câu hỏi
5. Nhận thông báo lịch học, thay đổi lớp

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Đăng ký môn học / khóa học | Request | Course catalog, prerequisites |
| Chọn lịch học | Execute | Available slots |
| Yêu cầu hỗ trợ học thuật | Request | Progress data, grade history |

### Pain Points
- Phải check nhiều nơi cho các môn khác nhau
- Lịch học thay đổi real-time không được thông báo
- Điểm cập nhật chậm sau khi nộp bài
- Không biết mình đang ở mức nào so với chuẩn pass

### Must-have Features
- ✅ Single portal cho tất cả courses
- ✅ Real-time schedule & notifications
- ✅ Grade visibility và feedback
- ✅ Assignment submission + progress tracking

---

## Persona 2: Teacher / Giáo viên / Instructor

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Giáo viên / Giảng viên / Trainer |
| **Focus** | Tạo nội dung, đánh giá học sinh, quản lý lớp |

### Daily Tasks
1. Upload bài giảng, tài liệu, quiz
2. Chấm bài và nhập điểm
3. Điểm danh học sinh
4. Tương tác với học sinh qua Q&A, discussion
5. Theo dõi tiến độ học sinh, phát hiện học sinh đuối

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Nhập điểm | Execute | Grading rubric, submission |
| Kế hoạch giảng dạy | Execute | Curriculum, timetable |
| Học sinh nào cần hỗ trợ | Recommend | Attendance, quiz scores |

### Pain Points
- Chấm bài thủ công tốn nhiều thời gian
- Điểm danh bằng giấy, phải nhập lại vào máy
- Không có view tổng quan tiến độ cả lớp
- Upload tài liệu mỗi lần còn rắc rối

### Must-have Features
- ✅ Online gradebook với auto-grading (trắc nghiệm)
- ✅ Attendance app (QR / manual)
- ✅ Student progress view (class dashboard)
- ✅ Content upload với version control

---

## Persona 3: Parent / Phụ huynh

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Người giám hộ của học sinh K-12 |
| **Focus** | Visibility về tiến độ học tập, an toàn thông tin con |

### Daily Tasks
1. Kiểm tra điểm và điểm danh của con
2. Xem lịch học, thông báo từ trường
3. Nhận thông báo từ giáo viên
4. Đóng học phí online
5. Ký đơn, consent forms

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Đăng ký học thêm, học hè | Request | Course catalog, schedule |
| Phản hồi về giáo viên | Request | Satisfaction survey |
| Consent cho chia sẻ dữ liệu con | Approve | Data sharing agreement |

### Pain Points
- Không biết con có đi học không (attendance)
- Điểm chỉ biết khi họp phụ huynh (quý/kỳ)
- Thanh toán học phí phải đến trường trực tiếp
- Không có kênh liên lạc trực tiếp với giáo viên

### Must-have Features
- ✅ Parent portal (điểm, điểm danh, thông báo)
- ✅ Online payment với lịch thanh toán
- ✅ Messaging với giáo viên (moderated)
- ✅ Digital consent forms

---

## Persona 4: Academic Admin / Registrar / Quản lý Giáo vụ

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Quản lý hành chính học vụ, enrollment, timetabling |
| **Focus** | Xử lý enrollment, lên thời khóa biểu, quản lý hồ sơ |

### Daily Tasks
1. Xử lý đơn đăng ký, enrollment
2. Lên thời khóa biểu (room + teacher + class)
3. Quản lý phòng học, tránh conflict
4. Cấp bảng điểm, xác nhận tốt nghiệp
5. Xử lý trường hợp đặc biệt (bảo lưu, chuyển trường)

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Xếp lớp, phân công giáo viên | Execute | Teacher availability, room capacity |
| Xử lý bảo lưu / chuyển trường | Approve | Student record, policy |
| Cấp transcript chính thức | Execute | Grade records, clearance status |

### Pain Points
- Xếp thời khóa biểu thủ công mất nhiều ngày
- Conflict phòng học không biết real-time
- Xuất bảng điểm mất nhiều bước thủ công
- Không có automation cho enrollment alerts

### Must-have Features
- ✅ Timetabling engine (auto-schedule, conflict detection)
- ✅ Room booking management
- ✅ Enrollment management với waitlist
- ✅ Transcript generation (official + self-service)

---

## Persona 5: Corporate L&D Manager / Training Manager

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Quản lý đào tạo nội bộ của doanh nghiệp |
| **Focus** | Employee skill development, training compliance, ROI |

### Daily Tasks
1. Assign khóa học bắt buộc cho nhân viên
2. Track completion rate và certification status
3. Đo lường training effectiveness
4. Lên kế hoạch training calendar theo năm
5. Báo cáo compliance training cho management

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Training nào mandatory vs elective | Decide | Business needs, compliance requirements |
| Certifications nào cần track | Decide | Regulatory requirements |
| ROI of training programs | Recommend | Completion rate, performance data |

### Pain Points
- Không có visibility vào ai đã học gì
- Completion rate chỉ tính manual qua Excel
- Không link được training với performance review
- Reminder cho mandatory training phải gửi thủ công

### Must-have Features
- ✅ Training assignment engine (individual + group + role-based)
- ✅ Completion tracking dashboard với alerts
- ✅ Certification tracking với expiry reminders
- ✅ Integration với HRIS (employee data, performance)

---

## Quick Reference: Persona Access Matrix

| Data/Function | Student | Teacher | Parent | Academic Admin | L&D Manager |
|---------------|:-------:|:-------:|:------:|:--------------:|:-----------:|
| Own grades | ✅ View | ❌ | ✅ (child) | ✅ Full | ❌ |
| Class grades | ❌ | ✅ Enter | ❌ | ✅ Full | ⚠ Team only |
| Attendance | ✅ Own | ✅ Enter | ✅ (child) | ✅ Full | ⚠ Team only |
| Course content | ✅ View | ✅ Full | ❌ | ✅ View | ✅ View |
| Enrollment | ✅ Own | ❌ | ✅ (child) | ✅ Full | ✅ Assign |
| Timetable | ✅ View | ✅ View | ✅ View | ✅ Full | ✅ View |
| Reports | ❌ | ⚠ Class | ❌ | ✅ Full | ✅ Team |
