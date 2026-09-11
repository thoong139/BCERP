# Playbook: Thiết kế Appointment Scheduling Module

> **Type**: Agent Skill Playbook
> **Agent**: healthcare-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi có module đặt lịch hẹn, booking, lịch khám
> **Output**: Feature spec + Data model cho Appointment Scheduling module

---

## Khi nào dùng playbook này

- Khi cần spec module "Đặt lịch hẹn" / "Appointment Scheduling" / "Booking"
- Khi thiết kế quản lý lịch bác sĩ, phòng khám, thiết bị
- Khi cần luồng check-in / check-out cho bệnh nhân
- Khi có yêu cầu nhắc hẹn (reminder), quản lý waitlist

---

## Procedure

### Bước 1: Xác định scope scheduling cần thiết kế

```
Hỏi hoặc suy luận từ context:
□ Loại resource cần schedule: Bác sĩ / Phòng khám / Thiết bị / Tất cả?
□ Kênh đặt lịch: Online portal / App di động / Kiosk / Điện thoại / Chuyển tuyến?
□ Loại lịch hẹn: Khám lần đầu / Tái khám / Xét nghiệm / Thủ thuật / Telemedicine?
□ BHYT: Có BN dùng thẻ BHYT không? → pre-authorization flow
□ Hàng chờ (Waitlist): Có cần quản lý hàng chờ khi slot đầy không?
□ Multi-location: Nhiều chi nhánh / phòng khám không?
□ Reminder: SMS / Email / Zalo OA / App push notification?
```

### Bước 2: Thiết kế Resource Calendar Model

```
READ: personas.md → Physician, Admin personas

Resource (đơn vị có thể đặt lịch):
  resource_id: UUID
  resource_type: enum (doctor / room / equipment)
  resource_name: string
  department_id: FK
  location_id: FK (facility/branch)
  is_active: boolean

Resource Schedule (ca làm việc cơ sở):
  schedule_id: UUID
  resource_id: FK
  effective_from: date
  effective_to: date (nullable — null = ongoing)
  schedule_pattern: JSONB {
    days_of_week: [0..6],   -- 0=Chủ nhật
    time_slots: [
      {start: "08:00", end: "12:00", slot_duration_minutes: 15},
      {start: "13:30", end: "17:00", slot_duration_minutes: 15}
    ]
  }
  max_concurrent_appointments: integer (default 1)

Schedule Override (ngày nghỉ / ngày đặc biệt):
  override_id: UUID
  resource_id: FK
  override_date: date
  override_type: enum (day_off / holiday / extended_hours / reduced_hours)
  modified_slots: JSONB (nullable — chỉ có khi extended/reduced)
  reason: string

Slot Generation Logic:
  → Generate slots tự động từ Schedule Pattern + Override
  → Slot = resource_id + start_time + end_time + status
  → Status: available / booked / blocked / no-show / cancelled
  → Tính sẵn sàng real-time: Query slot table thay vì tính lại từ pattern
```

### Bước 3: Thiết kế Appointment Types

```
Appointment Type (loại lịch hẹn):
  type_id: UUID
  type_name: string (ví dụ: "Khám lần đầu", "Tái khám", "Siêu âm thai")
  department_id: FK
  duration_minutes: integer (15 / 30 / 45 / 60)
  preparation_instructions: text (hướng dẫn chuẩn bị tiếng Việt)
  is_bhyt_eligible: boolean
  requires_referral: boolean (chuyển tuyến có cần giấy không)
  max_advance_booking_days: integer (đặt trước tối đa bao nhiêu ngày)
  min_advance_booking_hours: integer (phải đặt trước tối thiểu bao nhiêu giờ)
  cancellation_policy_hours: integer (hủy trước bao nhiêu giờ)
  color_code: string (hex — hiển thị trên calendar)

Appointment:
  appointment_id: UUID
  patient_id: FK → MPI
  resource_id: FK (thường là doctor)
  appointment_type_id: FK
  slot_id: FK
  scheduled_start: datetime
  scheduled_end: datetime
  location_id: FK
  appointment_status: enum (
    scheduled,        -- Đã đặt
    confirmed,        -- BN đã xác nhận
    checked_in,       -- Đã check-in tại cơ sở
    in_progress,      -- Đang khám
    completed,        -- Hoàn thành
    no_show,          -- BN không đến
    cancelled_by_patient,
    cancelled_by_facility
  )
  booking_channel: enum (portal / app / phone / kiosk / referral / walk_in)
  referral_document_url: string (nullable)
  bhyt_pre_auth_status: enum (not_required / pending / approved / rejected) (nullable)
  chief_complaint: text (BN mô tả lý do khám khi đặt)
  notes_for_staff: text
  encounter_id: FK (nullable — điền sau khi encounter được tạo)
  created_at, updated_at, cancelled_at, cancellation_reason
```

### Bước 4: Thiết kế Booking Channels

```
READ: clinical-workflows.md → Outpatient Visit Workflow

1. Patient Self-Service (Portal / App):
   □ Search bác sĩ theo: chuyên khoa / tên / địa điểm / rating
   □ Hiển thị slot trống real-time theo tuần/tháng
   □ Chọn slot → Điền chief complaint → Xác nhận → OTP hoặc login
   □ Xác nhận qua SMS/Email trong vòng 2 phút
   □ Giới hạn: tối đa 3 lịch active cùng lúc (chống spam booking)
   □ BHYT: thêm bước nhập/quét thẻ BHYT + check hạn thẻ

2. Lễ tân Đặt Thay (Phone / Walk-in):
   □ Staff search BN trong MPI (hoặc tạo mới nhanh)
   □ Staff chọn slot thay mặt BN
   □ Ghi chú lý do (phone booking / walk-in)
   □ Gửi confirmation cho BN qua SMS

3. Kiosk Check-in:
   □ BN quét CCCD / thẻ BHYT / QR code (từ app)
   □ Hệ thống confirm appointment + in số thứ tự
   □ Cập nhật status → checked_in
   □ Hiển thị: phòng chờ, bác sĩ, số thứ tự

4. Chuyển Tuyến (Referral):
   □ Bác sĩ tạo referral → chọn cơ sở nhận
   □ Gửi referral + tóm tắt bệnh án (FHIR Bundle)
   □ Cơ sở nhận xác nhận slot → thông báo BN
   □ BHYT referral: ghi nhận số chuyển tuyến

5. Telemedicine:
   □ Booking flow tương tự online
   □ Slot type = telemedicine
   □ Link video call tự động sinh → gửi qua email/SMS trước 15 phút
   □ Fallback: nếu BN không kết nối được → chuyển sang phone call
```

### Bước 5: Thiết kế Waitlist Management

```
Waitlist Entry:
  waitlist_id: UUID
  patient_id: FK
  resource_id: FK (bác sĩ muốn gặp)
  appointment_type_id: FK
  preferred_date_from: date
  preferred_date_to: date
  preferred_time_of_day: enum (morning / afternoon / any)
  waitlist_status: enum (waiting / offered / accepted / declined / expired)
  priority: integer (1=cao nhất, tính theo: thời gian chờ + urgent flag)
  urgent_flag: boolean (bác sĩ mark urgent)
  added_at: timestamp
  notified_at: timestamp (nullable)
  offer_expires_at: timestamp (nullable — BN có X giờ để confirm)

Auto-notification Flow:
  Khi slot mở (do cancellation hoặc schedule change):
  1. Query waitlist theo resource_id + appointment_type_id
  2. Sort by priority + added_at
  3. Gửi SMS/notification cho BN #1: "Có slot trống ngày X lúc Y. Xác nhận trong 2 giờ."
  4. Nếu không phản hồi trong 2 giờ → Offer cho BN #2
  5. Nếu decline → Offer cho BN #2 ngay
  6. Mark waitlist_status tương ứng
```

### Bước 6: Thiết kế Reminder Notifications

```
Reminder Schedule:
  reminder_id: UUID
  appointment_id: FK
  reminder_type: enum (D-3 / D-1 / H-2 / custom)
  channel: enum (sms / email / zalo_oa / push)
  scheduled_at: datetime
  sent_at: datetime (nullable)
  delivery_status: enum (pending / sent / failed / bounced)
  content_template: string (tham chiếu template ID)
  failure_reason: string (nullable)

Reminder Logic:
□ D-3 (3 ngày trước): SMS + Email — "Nhắc lịch khám ngày X với BS Y"
□ D-1 (1 ngày trước): SMS + Push — "Ngày mai bạn có lịch khám lúc HH:MM"
□ H-2 (2 giờ trước): SMS — "Còn 2 giờ đến lịch khám của bạn"
□ Cho phép BN opt-out reminder trong hồ sơ cá nhân
□ Telemedicine: thêm link video call vào reminder H-2
□ BHYT: nhắc BN mang theo thẻ BHYT + giấy tờ tùy thân

SMS Content (tiếng Việt, <160 ký tự):
  "Nhắc lịch: {ngày} lúc {giờ} khám với BS {tên_bs}
   tại {phòng_khám}. Hủy: {link}. ĐT: {hotline}"
```

### Bước 7: Thiết kế No-show Tracking & Check-in/Check-out Workflow

```
Check-in Workflow:
  Trigger: BN đến cơ sở y tế
  1. Xác minh identity: CCCD / QR code / BHYT / Tra tên
  2. Confirm appointment còn valid (không cancelled)
  3. Collect missing demographics (nếu có)
  4. BHYT: verify thẻ còn hạn, đúng tuyến điều trị
  5. Update appointment_status = checked_in
  6. Assign queue number (số thứ tự)
  7. In phiếu (optional) hoặc thông báo qua app

Check-out Workflow:
  Trigger: Encounter hoàn thành
  1. Clinician finalize encounter notes
  2. System auto: appointment_status = completed
  3. Generate billing summary
  4. BHYT: tính phần BHYT chi trả vs BN tự trả
  5. Prompt tạo lịch tái khám nếu follow-up được chỉ định
  6. Gửi summary + đơn thuốc qua app/email (nếu BN consent)

No-show Handling:
□ Auto-mark no-show: 30 phút sau scheduled_start nếu không check-in
□ First no-show: gửi SMS hỏi lý do + offer reschedule
□ Second no-show (30 ngày): flag trong hồ sơ, staff gọi điện
□ Third no-show: notify bác sĩ phụ trách để xem xét
□ No-show rate: metric theo dõi trong dashboard admin

BHYT Pre-authorization:
□ Áp dụng cho: thủ thuật, phẫu thuật, nhập viện có kế hoạch
□ Gửi request đến BHYT portal trước ngày hẹn
□ Nhận mã xác nhận → lưu vào appointment record
□ Nếu chưa có auth → cảnh báo staff khi check-in
```

### Bước 8: Feature Spec Output

```markdown
# Feature Spec: Appointment Scheduling Module

## Overview
[Mô tả module — channels, resource types, workflow chính]

## User Stories
- Là Bệnh nhân, tôi muốn đặt lịch khám online bất cứ lúc nào
  để không cần gọi điện trong giờ hành chính.
- Là Lễ tân, tôi muốn xem lịch tất cả bác sĩ trong ngày trên 1 màn hình
  để sắp xếp nhanh khi có BN walk-in.
- Là Bác sĩ, tôi muốn tự block lịch khi tham dự hội nghị
  mà không cần nhờ lễ tân.

## Functional Requirements

### REQ-HLTH-SCH-001: Resource Calendar với slot generation
[...format chuẩn]

### REQ-HLTH-SCH-002: Multi-channel booking (portal + kiosk + phone)
[...]

### REQ-HLTH-SCH-003: Automated reminders (SMS/Email)
[...]

### REQ-HLTH-SCH-004: Waitlist với auto-notification
[...]

### REQ-HLTH-SCH-005: Check-in / Check-out workflow
[...]

### REQ-HLTH-SCH-006: No-show tracking và reporting
[...]

### REQ-HLTH-SCH-007: BHYT pre-authorization integration
[...]

## Data Model
[Xem Bước 2-3 ở trên]

## API Endpoints
GET  /api/resources/{id}/availability?date={date}   -- Slot trống
POST /api/appointments                               -- Tạo lịch hẹn
PUT  /api/appointments/{id}/checkin                  -- Check-in
POST /api/waitlist                                   -- Vào hàng chờ
GET  /api/appointments?patient={id}                  -- Lịch của BN

## Non-functional Requirements
- Slot query: < 500ms (real-time availability)
- Concurrent booking: xử lý race condition (optimistic locking trên slot)
- Reminder delivery: 99% SMS trong 5 phút trước scheduled_at
- Availability: 99.9% uptime — BN cần đặt lịch 24/7
```

---

## Checklist trước khi submit

```
□ Race condition cho concurrent booking đã được thiết kế (optimistic/pessimistic lock)
□ BHYT pre-authorization flow đã included (nếu có BHYT)
□ Waitlist auto-offer có expiry time (BN không phản hồi → next BN)
□ No-show tracking + escalation path đã xác định
□ Reminder opt-out tôn trọng consent của BN
□ Kiosk check-in verify identity trước khi update status
□ Emergency walk-in: có luồng xử lý BN không có lịch hẹn
□ Telemedicine: link video call auto-generate + fallback
□ Calendar override cho ngày nghỉ lễ VN (Tết, 30/4, 2/9...)
```
