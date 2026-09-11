# Playbook: Thiết kế Property Management System

> **Type**: Agent Procedure
> **Agent**: real-estate-expert
> **Triggered by**: /wf-design khi cần thiết kế property management, tòa nhà, cho thuê
> **Output**: `.mc-data/docs/phase3-architecture/real-estate/property-management.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design`
- Khi dự án có module quản lý tòa nhà, cho thuê, bảo trì, phí dịch vụ
- Khi thiết kế hệ thống sau giai đoạn bàn giao cho Property Manager và Tenant

---

## Procedure

### Bước 1: Đọc context và requirements

```
INPUT: Paths do skill cung cấp qua prompt
Ưu tiên đọc:
□ .mc-data/docs/phase1-business/real-estate-requirements.md (REQ-RE-PROP-*)
□ .mc-data/docs/_meta/req-registry.json (modules liên quan)
□ .mc-data/docs/phase2-features/ (feature specs nếu có)

Xác định scope:
□ Residential building (căn hộ cho thuê)
□ Commercial building (văn phòng, mặt bằng)
□ Mixed-use
□ Quy mô: số căn, số tòa nhà, số tenant
```

### Bước 2: Property & Unit Data Model

```
Thiết kế entities cốt lõi:

Property (Tòa nhà / Khu nhà):
  - id, name, address, type (residential/commercial/industrial)
  - total_units, total_floors, amenities[], building_specs
  - management_company, contact_info

Unit (Căn hộ / Mặt bằng):
  - id, property_id, floor, unit_number
  - area_sqm, unit_type (studio/1BR/2BR/3BR/penthouse/office)
  - status: available | occupied | maintenance | reserved
  - base_rent, service_fee_rate
  - features[] (furnishing, view, balcony)

Lease Agreement (Hợp đồng thuê):
  - id, unit_id, tenant_id
  - lease_start, lease_end, duration_months
  - monthly_rent, deposit_amount (thường 2-3 tháng)
  - payment_due_day (ngày thu mỗi tháng)
  - terms, renewal_option, termination_clause
  - signed_date, signed_by, documents[]
  - status: draft | active | expired | terminated

Tenant (Người thuê):
  - id, full_name, id_number (CCCD/Hộ chiếu)
  - phone, email, emergency_contact
  - unit_id (current), lease_id (active)
  - kyc_verified, kyc_documents[]
  - payment_history_score

Xác định relationships:
  Property 1:N Unit
  Unit 1:N LeaseAgreement (lịch sử)
  Unit 1:1 LeaseAgreement (active)
  LeaseAgreement N:1 Tenant
```

### Bước 3: Maintenance Request Workflow

```
Thiết kế state machine:
  Submitted → Assigned → In Progress → Completed → Verified → Closed
  Hoặc: Submitted → Rejected (nếu không hợp lệ)
  Hoặc: Completed → Reopened (nếu KH không satisfied)

Priority classification:
  - Emergency: Rủi ro an toàn (nước tràn, điện hỏng, cháy)    → SLA: < 2h
  - High: Ảnh hưởng sinh hoạt (điều hòa, nóng lạnh, khóa)    → SLA: < 24h
  - Normal: Không tiện nghi (bóng đèn, vòi nước nhỏ giọt)    → SLA: < 72h
  - Low: Cosmetic (sơn tường, cửa kẹt nhẹ)                   → SLA: < 7 ngày

MaintenanceRequest entity:
  - id, unit_id, tenant_id
  - category (plumbing/electrical/hvac/structural/other)
  - priority (emergency/high/normal/low)
  - description, photos[] (before)
  - status, assigned_to (staff_id hoặc vendor_id)
  - scheduled_at, completed_at
  - resolution_notes, completion_photos[]
  - cost, cost_category (tenant_liability / building_liability)
  - tenant_rating (sau khi close)

Notification triggers:
  - Tenant: Submitted (confirm) → Assigned (lịch hẹn) → Completed (verify request)
  - Staff/Vendor: Assigned notification → SLA warning (50%, 80%, 100% of SLA time)
  - Manager: SLA breach, Emergency requests, Cost > threshold
```

### Bước 4: Billing & Collection System

```
Monthly Invoice Generation:
  - Auto-generate vào ngày 25 hàng tháng cho tháng kế tiếp
  - Components:
    □ Management fee (phí quản lý): Fixed theo hợp đồng
    □ Electricity: Chỉ số đầu kỳ, cuối kỳ, đơn giá EVN theo bậc
    □ Water: Đồng hồ riêng hoặc chia đều (tùy hệ thống)
    □ Parking: Theo số lượng thẻ đăng ký
    □ Other services: Dịch vụ bổ sung (nếu có)
  - VAT calculation (nếu applicable)
  - Total amount, due date (thường ngày 10 tháng sau)

Payment Channels:
  - Bank transfer (QR code, tài khoản thụ hưởng)
  - VNPay / Momo / ZaloPay (nếu tích hợp)
  - Cash (có nhân viên thu trực tiếp)

Receipt Generation:
  - Auto khi payment confirmed (qua payment gateway)
  - Manual khi cash payment (nhập vào hệ thống)
  - PDF receipt gửi email + lưu vào tenant portal

Overdue Management:
  - D+3: Reminder email/SMS (thân thiện)
  - D+7: Reminder thứ 2 (tone nghiêm hơn)
  - D+15: Thông báo phạt lãi suất (nếu trong HĐ)
  - D+30: Legal notice, xem xét terminate nếu vi phạm nghiêm trọng

Utility Meter Reading:
  - Manual entry (nhân viên ghi số tháng)
  - Hoặc IoT smart meter integration (tự động)
  - Validation: số cuối kỳ ≥ số đầu kỳ, tăng không bất thường
```

### Bước 5: Occupancy Management

```
Availability Calendar:
  - Timeline view per unit (occupied, available, maintenance periods)
  - Gap detection: Khoảng trống giữa 2 lease
  - Lead time tracking: Bao lâu nữa unit trở thành available

Lease Renewal Tracking:
  - Alert 90 ngày trước expiry: Gửi renewal offer cho tenant
  - Alert 60 ngày: Follow-up nếu chưa có phản hồi
  - Alert 30 ngày: Escalate lên Manager
  - Decision: Renew (new price, new terms) hoặc Non-renewal notice

Vacancy Marketing Integration:
  - Khi unit confirm vacant: Push listing lên platforms (nếu tích hợp)
  - Sync availability và giá tham khảo thị trường
  - Track inquiries từ prospective tenants

Tenant Screening Workflow (cho tenant mới):
  - Application form: Thông tin cá nhân, employment, references
  - KYC verification: CCCD, hộ khẩu, income proof
  - Credit/rental history check (nếu có dịch vụ)
  - Manager approval → Offer letter → Lease signing

Move-in / Move-out Checklist:
  - Itemized checklist: Từng phòng, thiết bị, nội thất
  - Photo documentation (bắt buộc): Trước check-in, sau check-out
  - Damage assessment: So sánh check-in vs check-out
  - Deposit refund calculation: Tổng cọc - damages - outstanding fees
```

### Bước 6: Reporting & Analytics

```
Operations Dashboard (Property Manager):
  - Occupancy rate: Overall, per building, per floor, per unit type
  - Collection rate: Tháng hiện tại, year-to-date
  - Outstanding invoices: Aging analysis (0-7, 8-15, 16-30, >30 ngày)
  - Maintenance summary: Open requests by priority, SLA compliance rate
  - Lease expiry calendar: 30/60/90 ngày tới

Financial Reports:
  - Revenue per Available Unit (RevPAU): Doanh thu / Tổng số căn
  - Effective Occupancy Revenue: Thực thu / Tiềm năng tối đa
  - Maintenance cost analysis: Total, per unit, per category, vs budget
  - Service fee receivables: By tenant, by aging bucket

Tenant Reports:
  - Payment history: Tất cả invoices, payment dates, outstanding
  - Maintenance history: Tất cả requests, status, resolution time
  - Lease documents: HĐ, phụ lục, biên bản bàn giao (download)
```

---

## Output checklist

```
□ Entity diagram đầy đủ (Property, Unit, Lease, Tenant, Maintenance, Invoice)
□ Status machines cho Unit và MaintenanceRequest
□ SLA matrix rõ ràng (Emergency/High/Normal/Low)
□ Billing cycle và components xác định
□ Overdue management workflow
□ Notification triggers cho mọi key events
□ Occupancy management workflow (renewal, vacancy)
□ API endpoints cần thiết (list)
□ Integration requirements (payment gateway, utility, notification)
□ REQ-ID mapping: mỗi design decision trỏ về REQ-RE-PROP-*
```
