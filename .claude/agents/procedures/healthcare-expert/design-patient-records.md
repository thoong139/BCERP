# Playbook: Thiết kế Patient Records (EMR/EHR) Module

> **Type**: Agent Skill Playbook
> **Agent**: healthcare-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi có module EMR, EHR, hồ sơ bệnh án, quản lý bệnh nhân
> **Output**: Feature spec + Data model cho Patient Records module

---

## Khi nào dùng playbook này

- Khi cần spec module "Hồ sơ bệnh án điện tử" / "EMR" / "EHR" / "Patient Records"
- Khi thiết kế data model cho clinical documentation
- Khi cần xác định cấu trúc lưu trữ thông tin bệnh nhân
- Khi review/audit hệ thống EMR hiện có

---

## Procedure

### Bước 1: Xác định scope EMR cần thiết kế

```
Hỏi hoặc suy luận từ context:
□ Loại hình: Outpatient (ngoại trú) / Inpatient (nội trú) / Cả hai?
□ Chuyên khoa: Đa khoa / Chuyên khoa (Nhi, Tim mạch, Sản...)?
□ Clinical documentation depth: Cơ bản (SOAP notes) / Đầy đủ (clinical templates)?
□ Order management: Chỉ kê đơn / Có CPOE (lệnh xét nghiệm, chụp chiếu)?
□ Chuẩn mã hóa: ICD-10 bắt buộc? SNOMED CT? HL7 FHIR?
□ Tích hợp: Kết nối Lab, PACS, Pharmacy có không?
□ Quy định Thông tư 43/2013: Bắt buộc theo quy định VN?
```

### Bước 2: Thiết kế Master Patient Index (MPI)

```
READ: compliance.md → Access Control Requirements

MPI là backbone — quản lý identity duy nhất của từng bệnh nhân:

MPI Schema:
  patient_id: UUID (primary, hệ thống tự sinh)
  local_mrn: string (Medical Record Number, unique per facility)
  national_id_type: enum (CCCD / CMND / Passport / BHYT)
  national_id_number: string (mã hóa AES-256)
  full_name: string
  date_of_birth: date
  gender: enum (male / female / other)
  bhyt_card_number: string (nullable, mã hóa)
  bhyt_card_expiry: date
  phone: string (mã hóa)
  email: string (nullable, mã hóa)
  address: JSONB {province, district, ward, street}
  emergency_contact: JSONB {name, relationship, phone}
  created_at, updated_at, is_active

Duplicate Detection:
□ Fuzzy matching khi đăng ký: họ tên + ngày sinh + giới tính
□ Score-based: 100% = exact match (block), 80-99% = cảnh báo + confirm
□ Merge workflow: Admin merge 2 records → giữ cả 2 audit trail
□ Golden record: chọn record "chính" sau merge
```

### Bước 3: Thiết kế Medical Record Structure

```
READ: clinical-workflows.md → Patient Care Workflows

Cấu trúc hồ sơ theo Encounter (lượt khám):

Encounter (Lượt khám):
  encounter_id: UUID
  patient_id: FK → MPI
  encounter_type: enum (outpatient / inpatient / emergency / telemedicine)
  visit_date: datetime
  department: string
  attending_physician_id: FK → Staff
  encounter_status: enum (draft / in-progress / completed / cancelled)
  chief_complaint: text
  created_at, updated_at, finalized_at, finalized_by

Clinical Documentation (SOAP Notes):
  Subjective:
    chief_complaint: text
    history_of_present_illness: text
    review_of_systems: JSONB
    past_medical_history: JSONB
    medications_current: JSONB (tên thuốc, liều, tần suất)
    allergies: JSONB (chất gây dị ứng, phản ứng, mức độ)
    family_history: text
    social_history: text

  Objective:
    vital_signs: JSONB {height, weight, bmi, bp_systolic, bp_diastolic,
                         pulse, temperature, spo2, respiratory_rate}
    physical_exam: JSONB (theo hệ cơ quan)
    lab_results: FK → LabResult[]
    imaging_results: FK → ImagingResult[]

  Assessment:
    diagnoses: JSONB [{
      icd10_code: string,
      icd10_description: string,
      diagnosis_type: enum (primary / secondary / differential),
      certainty: enum (confirmed / probable / rule-out),
      onset_date: date
    }]

  Plan:
    treatment_plan: text
    orders: FK → Order[]
    patient_education: text
    follow_up: {interval: number, unit: enum, instructions: text}
```

### Bước 4: Thiết kế Prescription & Medication Management

```
READ: clinical-workflows.md → Medication Administration

Kê đơn điện tử (E-Prescription):
  prescription_id: UUID
  encounter_id: FK
  prescribed_by: FK → Staff (physician)
  prescribed_at: datetime
  prescription_status: enum (draft / active / dispensed / cancelled)

  prescription_items: [
    {
      drug_name: string,
      drug_code: string (mã thuốc quốc gia),
      generic_name: string,
      dosage: string (ví dụ: "500mg"),
      route: enum (oral / injection / topical / inhalation / other),
      frequency: string (ví dụ: "2 lần/ngày"),
      duration_days: integer,
      quantity: integer,
      unit: string,
      instructions: text (hướng dẫn cách dùng tiếng Việt),
      is_bhyt_covered: boolean,
      bhyt_coverage_ratio: decimal (0-100%)
    }
  ]

Drug Safety Checks (tự động khi kê đơn):
□ Allergy check: so sánh với allergy list của BN — BLOCK nếu có contraindication
□ Drug-drug interaction: kiểm tra tương tác với thuốc đang dùng — WARNING level
□ Drug-disease interaction: kiểm tra với diagnoses hiện tại
□ Dose range check: cảnh báo nếu liều ngoài range an toàn
□ Duplicate therapy: cảnh báo nếu cùng hoạt chất đã có trong đơn
```

### Bước 5: Thiết kế HL7 FHIR Compliance

```
Resources FHIR R4 cần implement:

Core Resources:
□ Patient        → Thông tin bệnh nhân (MPI)
□ Practitioner   → Thông tin bác sĩ, điều dưỡng
□ Organization   → Cơ sở y tế, khoa/phòng
□ Encounter      → Lượt khám/nhập viện
□ Condition      → Chẩn đoán (ICD-10)
□ MedicationRequest → Đơn thuốc
□ Observation    → Kết quả xét nghiệm, sinh hiệu
□ DiagnosticReport → Kết quả xét nghiệm tổng hợp
□ AllergyIntolerance → Dị ứng

API Format:
□ RESTful FHIR API: GET /fhir/Patient/{id}
□ Content-Type: application/fhir+json
□ Bundle: gom nhiều resources vào 1 response
□ Search: _id, _lastUpdated, patient, date (standard params)

Data Exchange Use Cases:
□ Xuất bệnh án khi chuyển viện → Bundle FHIR
□ Nhận kết quả lab từ LIS → DiagnosticReport FHIR
□ Gửi đơn thuốc đến nhà thuốc → MedicationRequest FHIR
```

### Bước 6: Thiết kế Consent Management

```
READ: compliance.md → Consent Management

Consent Types:
  consent_id: UUID
  patient_id: FK
  consent_type: enum (
    treatment,          -- Đồng ý điều trị
    data_sharing,       -- Chia sẻ thông tin với bên thứ 3
    research,           -- Tham gia nghiên cứu
    emergency_contact,  -- Liên hệ người thân trong khẩn cấp
    marketing          -- Nhận thông tin từ cơ sở y tế
  )
  consent_status: enum (granted / refused / withdrawn)
  granted_at: datetime
  expires_at: datetime (nullable)
  obtained_by: FK → Staff
  method: enum (paper / electronic / verbal-witnessed)
  document_url: string (link file consent đã ký, nếu có)
  witness_id: FK → Staff (nullable)

Rules:
□ KHÔNG truy cập hồ sơ BN nếu không có treatment consent
□ KHÔNG gửi dữ liệu cho bên thứ 3 nếu không có data_sharing consent
□ Withdrawal: khi BN rút consent → không xóa lịch sử, chỉ block future access
□ Emergency override: ghi nhận và audit khi truy cập không có consent (break-the-glass)
```

### Bước 7: Thiết kế Audit Trail

```
READ: compliance.md → Audit Trail Requirements

Mọi thao tác với hồ sơ bệnh án phải được ghi log:

audit_log table:
  log_id: UUID
  event_type: enum (READ / CREATE / UPDATE / DELETE / EXPORT / PRINT / LOGIN / LOGOUT)
  patient_id: UUID (nullable — vì có log không gắn với patient)
  resource_type: string (Encounter, Prescription, LabResult...)
  resource_id: UUID
  performed_by: FK → Staff (hoặc Patient nếu Patient Portal)
  performed_at: timestamp (UTC)
  ip_address: string (mã hóa)
  user_agent: string
  session_id: string
  old_value: JSONB (chỉ UPDATE events — giá trị trước khi sửa)
  new_value: JSONB (chỉ UPDATE events — giá trị mới)
  reason: string (nullable — bắt buộc cho break-the-glass access)
  is_emergency_access: boolean

Rules:
□ Audit log là APPEND ONLY — KHÔNG được DELETE hoặc UPDATE
□ Retention: tối thiểu 10 năm (theo Luật Khám chữa bệnh VN)
□ Index trên: patient_id + performed_at (query thường xuyên)
□ Separate table / database từ operational data (tránh bị xóa theo cascade)
□ Alert tự động: truy cập bulk (>50 records/5 phút) → notify Security
```

### Bước 8: Feature Spec Output

```markdown
# Feature Spec: Patient Records (EMR) Module

## Overview
[Mô tả module — loại hình, scope, chuẩn áp dụng]

## User Stories
- Là Bác sĩ, tôi muốn xem toàn bộ lịch sử khám của BN trong 1 màn hình
  để không cần hỏi lại thông tin đã có từ lần trước.
- Là Điều dưỡng, tôi muốn nhập sinh hiệu nhanh trên tablet
  để không mất thời gian quay về trạm y tá.
- Là Bệnh nhân, tôi muốn xem kết quả xét nghiệm ngay khi có
  thay vì chờ gặp bác sĩ.

## Functional Requirements

### REQ-HLTH-EMR-001: Master Patient Index với duplicate detection
**Mô tả**: Hệ thống quản lý danh tính bệnh nhân, phát hiện trùng lặp khi đăng ký mới
**Persona**: Lễ tân/Admin
**Business Value**: Tránh tạo nhiều hồ sơ cho 1 bệnh nhân — ảnh hưởng đến tính toàn vẹn lâm sàng
**Acceptance Criteria**:
- [ ] Fuzzy matching khi đăng ký mới (họ tên + ngày sinh + giới tính)
- [ ] Score >= 80% → cảnh báo, yêu cầu xác nhận trước khi tạo mới
- [ ] Merge flow cho admin khi xác nhận trùng lặp
- [ ] MRN tự sinh, unique per facility
**Compliance**: Thông tư 43/2013 — mã hồ sơ bệnh án
**Priority**: Must-have

### REQ-HLTH-EMR-002: SOAP Notes với ICD-10 coding
**Mô tả**: Bác sĩ ghi chép Subjective/Objective/Assessment/Plan theo cấu trúc chuẩn,
gán mã ICD-10 cho chẩn đoán
**Persona**: Bác sĩ
**Business Value**: Chuẩn hóa tài liệu lâm sàng, đáp ứng yêu cầu BHYT và Thông tư 43
**Acceptance Criteria**:
- [ ] Form SOAP có validation bắt buộc chief_complaint + ít nhất 1 diagnosis
- [ ] ICD-10 search: gõ mã hoặc từ khóa tiếng Việt/Anh → suggest top 10
- [ ] Auto-save draft mỗi 30 giây
- [ ] Finalize/Lock: sau khi ký bằng digital signature — KHÔNG thể sửa, chỉ Addendum
**Compliance**: Thông tư 43/2013, yêu cầu BHYT
**Priority**: Must-have

### REQ-HLTH-EMR-003: Kê đơn điện tử với drug safety checks
[... format tương tự]

### REQ-HLTH-EMR-004: Allergy management
[...]

### REQ-HLTH-EMR-005: HL7 FHIR export
[...]

### REQ-HLTH-EMR-006: Consent management
[...]

### REQ-HLTH-EMR-007: Audit trail đầy đủ
[...]

## Data Model
[ERD hoặc field definitions — dựa trên Bước 2-4 ở trên]

## API Endpoints
GET  /api/patients/{id}                  -- Thông tin bệnh nhân
GET  /api/patients/{id}/encounters       -- Lịch sử khám
POST /api/encounters                     -- Tạo lượt khám mới
PUT  /api/encounters/{id}/finalize       -- Ký/khóa hồ sơ
GET  /fhir/Patient/{id}                  -- FHIR Patient resource

## Non-functional Requirements
- Performance: Mở hồ sơ bệnh nhân (5 năm lịch sử) < 2 giây
- Concurrency: 100 bác sĩ cùng lúc, 0 data collision
- Availability: 99.9% uptime (downtime max 8.7 giờ/năm)
- Data retention: 10 năm sau lần khám cuối
- Encryption: PHI mã hóa AES-256 at-rest, TLS 1.3 in-transit
```

---

## Checklist trước khi submit

```
□ MPI có duplicate detection logic
□ Mọi PHI field được mark là cần mã hóa
□ Drug safety checks (allergy + interaction) đã included
□ Audit trail cho tất cả READ/WRITE operations
□ Consent gates đã được thiết kế
□ FHIR compliance scope đã xác định
□ Finalize/Lock workflow đáp ứng Thông tư 43 (KHÔNG sửa sau khi ký)
□ Emergency access (break-the-glass) workflow có trong spec
□ BHYT requirements (ICD-10, danh mục thuốc BHYT) đã covered
```
