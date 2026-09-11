# Playbook: Review Healthcare Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: healthcare-expert
> **Triggered by**: /wf-implement-feature khi review code của healthcare/medical module
> **Output**: Healthcare implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của EMR, scheduling, billing, pharmacy module
- Khi cần validate business logic từ góc nhìn lâm sàng và pháp lý y tế
- Khi cần check PHI/PII handling, audit trail, BHYT logic
- Khi cần verify patient safety controls (drug interaction, allergy)

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type và load checklist tương ứng:

□ EMR / Patient Records   → thực hiện Bước 2 + 3a
□ Appointment Scheduling  → thực hiện Bước 2 + 3b
□ Pharmacy / Prescription → thực hiện Bước 2 + 3c
□ BHYT / Billing          → thực hiện Bước 2 + 3d
□ Patient Portal          → thực hiện Bước 2 + 3e
□ Lab / Xét nghiệm        → thực hiện Bước 2 + 3f
□ Admin / Reporting       → thực hiện Bước 2 + 3g

Bước 2 luôn thực hiện, bất kể module nào.
```

### Bước 2: PHI/PII & Security Baseline (luôn làm)

```
READ: compliance.md → Security Controls + Audit Trail Requirements

Checklist áp dụng cho MỌI healthcare module:

PHI Handling:
□ PHI fields (tên + ngày sinh + số BHYT + chẩn đoán...) được mã hóa at-rest?
   → Tối thiểu AES-256 cho sensitive fields trong DB
□ TLS 1.3 (hoặc 1.2 minimum) cho tất cả API calls có PHI?
□ PHI có bị log vào application logs không?
   → KHÔNG được log tên BN, chẩn đoán, số BHYT dạng plaintext
□ PHI trong error messages / stack traces?
   → Nếu có → Critical issue
□ PHI trong query params (URL) không? → Dùng POST body thay vì GET params
□ File export (PDF, Excel): có watermark / access control không?

Access Control:
□ Mọi API endpoint có require authentication không? (không có endpoint public vô tình)
□ Authorization check: user chỉ truy cập data của BN mình được phép?
   → Doctor: chỉ BN được assign
   → Nurse: BN trong khoa/unit
   → Billing: financial data only, không có clinical details
□ Có kiểm tra role trên server-side không? (không chỉ hide UI)
□ Break-the-glass access có log reason không?

Audit Trail:
□ Tất cả READ operations trên patient data có được log không?
   → Lưu ý: đọc hồ sơ cũng phải log (không chỉ ghi)
□ Log entry có đủ: who, when, what patient, what action, IP?
□ Audit logs APPEND ONLY? Không có DELETE/UPDATE endpoint?
□ Audit logs table tách biệt khỏi operational DB không?
□ Có index trên (patient_id, performed_at) cho audit queries?

Consent:
□ Trước khi trả dữ liệu lâm sàng → đã check treatment consent chưa?
□ Emergency access → ghi lý do trong audit log?
```

### Bước 3a: EMR / Patient Records Review

```
Master Patient Index:
□ Duplicate detection có chạy khi tạo BN mới không?
   → Fuzzy match: họ tên + ngày sinh + giới tính
□ Race condition: concurrent registration của cùng 1 BN → có xử lý không?
□ MRN auto-generation: unique + không predictable?

Clinical Documentation:
□ SOAP notes: bác sĩ có thể finalize (lock) không?
□ Sau khi finalized: có cho sửa không? → Phải dùng Addendum, không edit trực tiếp
□ Digital signature: ký bằng cơ chế nào? (password confirm / PKI cert / OTP?)
□ ICD-10 lookup: dùng bản ICD-10-CM hay ICD-10 VN?
   → VN: ICD-10 của BYT VN (có cập nhật Nghị định 97/2023 không?)
□ Allergy list: có warning khi kê thuốc có trong allergy không? → Nếu không có → Critical

Drug Prescriptions:
□ Drug-drug interaction check: ở bước nào? (real-time khi gõ hay chỉ khi submit?)
□ Allergy cross-reference: so sánh với allergy class không chỉ tên thuốc cụ thể?
   → Penicillin allergy → cảnh báo cho toàn bộ beta-lactam group
□ BHYT thuốc: có check danh mục thuốc BHYT hiện hành không?
□ Kê đơn vượt số ngày BHYT quy định → có cảnh báo không?

Medical Record Integrity:
□ Có thể delete encounter không? → Phải soft-delete + audit
□ Lab results từ LIS: có validate format trước khi lưu không?
□ Vital signs: có range validation (BP 60-300 mmHg, Temp 30-45°C...)?
```

### Bước 3b: Appointment Scheduling Review

```
Slot & Booking:
□ Race condition: 2 BN đặt cùng 1 slot → có xử lý không?
   → Optimistic locking hoặc transaction với SELECT FOR UPDATE
□ Slot availability query: có dùng cached data không?
   → Nếu cache → TTL phải rất ngắn (<30s) hoặc invalidate khi booking
□ Booking limit per patient: có kiểm tra không? (chống spam booking)

BHYT:
□ Thẻ BHYT: verify còn hạn tại thời điểm đặt lịch không?
□ Đúng tuyến điều trị không? (đúng nơi đăng ký ban đầu)
□ Thủ thuật cần pre-auth: có block checkout nếu chưa có BHYT approval không?

Reminder:
□ SMS content: có PHI nhạy cảm không? (tên bác sĩ OK, chẩn đoán thì KHÔNG)
□ Opt-out: BN từ chối nhận reminder → hệ thống có respect không?
□ Reminder job: có idempotent không? (chạy lại không gửi 2 lần)

No-show:
□ Auto-mark no-show: có trigger sau đúng thời gian không?
□ Có ảnh hưởng BHYT claim không? (BHYT không chi trả cho lần no-show)
```

### Bước 3c: Pharmacy / Prescription Review

```
Drug Safety Critical Checks:
□ Allergy gate BLOCK (không chỉ warn) khi thuốc contraindicated?
   → Known contraindication = BLOCK dispensing, yêu cầu override với lý do
□ Pharmacist override: có log reason không?
□ Drug class check: có mapping hoạt chất → drug class để check allergy đúng không?
□ Interaction check database: đang dùng nguồn nào? Có cập nhật không?
□ Pediatric dosing: có kiểm tra liều theo cân nặng/tuổi không?
□ Pregnancy/Lactation flags: có không nếu system scope là sản khoa?

Dispensing:
□ 5 Rights check: right patient / right drug / right dose / right route / right time?
□ Barcode/QR verification tại điểm cấp phát?
□ Partial dispense: khi thuốc thiếu → ghi nhận và xử lý thế nào?

BHYT Pharmacy:
□ Tính đúng % BHYT chi trả theo danh mục?
□ Xuất XML BHYT cho quyết toán: đúng format BYT quy định?
□ Thuốc ngoài danh mục BHYT: cảnh báo trước khi kê?
```

### Bước 3d: BHYT / Billing Review

```
BHYT Calculation:
□ Công thức tính phần BHYT chi trả theo đúng quy định:
   → Đúng tuyến: BHYT chi trả X%
   → Trái tuyến: BHYT chi trả Y%
   → Vượt trần kỹ thuật: có xử lý không?
□ Danh mục kỹ thuật, thuốc, vật tư: cập nhật đúng phiên bản hiện hành?
□ Số ngày điều trị: tính đúng không? (inpatient: ngày vào + ngày ra)
□ Co-payment: tính đúng phần BN tự trả không?
□ Trường hợp đặc biệt: hộ nghèo, trẻ <6 tuổi, thương binh → tỷ lệ đúng?

XML BHYT Submission:
□ File XML đúng schema BYT quy định (cập nhật mới nhất)?
□ Mã cơ sở y tế, mã chuyên khoa: đúng danh mục BHXH?
□ Có validate XML trước khi submit không? (tránh reject do format)
□ Lỗi từ BHYT portal: có parse và hiển thị rõ ràng cho billing staff không?
□ Idempotency: submit lại file đã submit → có duplicate claim không?

Revenue Protection:
□ Tất cả dịch vụ đã cung cấp có được charge không? (missing charges)
□ Có reconcile giữa clinical orders và billing charges không?
□ Có audit cho charges được adjust/waived không?
```

### Bước 3e: Patient Portal Review

```
Authentication & Identity:
□ Xác thực bằng gì? OTP SMS đủ không? Có 2FA không?
□ Account recovery: có thể chiếm tài khoản của người khác không?
□ Session timeout: có không? Timeout sau bao lâu?

Data Access:
□ BN chỉ thấy data của chính mình?
□ Minor (trẻ em): parent/guardian có quyền truy cập không? Đến bao nhiêu tuổi?
□ Proxy access: có cho phép người thân đại diện không? Cơ chế authorization?
□ Results display: kết quả bất thường có được flag rõ ràng?
   → Critical values: hiển thị "Cần liên hệ bác sĩ ngay" không?

PHI Exposure:
□ API chỉ trả đủ data cần thiết? (không leak fields thừa)
□ Search/autocomplete không expose PHI của người khác?
□ Download records (PDF): có tracking ai download không?

Communication:
□ Secure messaging (nếu có): có E2E encryption không?
□ Notification content: có PHI nhạy cảm trong push notification / email subject không?
   → Email subject: "Kết quả xét nghiệm của bạn" OK
   → "Kết quả HIV của bạn" → KHÔNG OK trong subject line
```

### Bước 3f: Laboratory Review

```
Specimen Tracking:
□ 2-identifier verification khi thu mẫu? (ID BN + ngày sinh, không chỉ tên)
□ Chain of custody: có log từng bước (collect → transport → receive → analyze)?
□ Mẫu lạc/mất: có detection và alert không?

Critical Values:
□ Danh sách critical values có được cấu hình không?
□ Khi có critical value: alert ngay cho bác sĩ phụ trách trong bao lâu? (target: <5 phút)
□ Alert acknowledged: bác sĩ phải xác nhận đã nhận alert?
□ Nếu không ack trong X phút: escalate cho ai?

Result Reporting:
□ Kết quả về HIS: auto-push hay BN/BS phải refresh?
□ Phê duyệt kết quả: Lab director ký duyệt trước khi release?
□ Kết quả bất thường: flag rõ ràng (H/L/Critical) không?
□ Reference ranges: có phân theo tuổi/giới tính không?
   → Hemoglobin ranges khác nhau cho nam/nữ/trẻ em
□ Delta check: thay đổi đột ngột so với lần trước → có alert không?
```

### Bước 3g: Admin / Reporting Review

```
Access Control:
□ Admin có thể xem clinical data của BN không? → Phải là aggregate only
□ Export reports: có PHI trong export không? → De-identify nếu cho external
□ Custom reports: user có thể viết query tùy ý không? → SQL injection + PHI risk

Data Integrity:
□ Aggregation: tính đúng không? (average LOS, readmission rate...)
□ Denominator: có nhất quán không? (cùng 1 metric, cùng cách tính)
□ Date range filter: timezone xử lý đúng không? (VN: UTC+7)

BHYT Reporting:
□ Báo cáo quyết toán: sum đúng với XML đã submit không?
□ Có audit trail cho các chỉnh sửa trong báo cáo không?
```

### Bước 4: Performance & Concurrency Check

```
□ Concurrent ward access: 50 điều dưỡng cùng update MAR → có lock conflict không?
□ EMR load time: hồ sơ BN với 5 năm lịch sử < 2 giây?
□ BHYT XML generation: xử lý 500 BN/ngày → batch hay sync?
□ Audit log writes: có block main transaction không? → Phải async
□ Search BN: full-text search với 100,000 records → có index không?
□ Lab result ingestion: nhận batch kết quả từ máy phân tích → queue/batch?
□ Reminder job: chạy lại không gửi duplicate SMS?
□ Report queries: có timeout không? (tránh lock DB với complex queries)
```

### Bước 5: Output — Review Report

```markdown
# Healthcare Implementation Review: [Module Name]

## Compliance Status: PASS / FAIL / NEEDS ATTENTION

## Patient Safety Issues (Chặn go-live — fix ngay)
- [ ] [Issue]: [Vị trí trong code] → [Tác động lâm sàng] → [Fix bắt buộc]

Ví dụ:
- [ ] Drug allergy check không block khi contraindicated — chỉ warning:
      Vị trí: PrescriptionService.savePrescription() line 142
      Rủi ro: Bác sĩ có thể bỏ qua, BN bị phản ứng dị ứng nghiêm trọng
      Fix: Thay warning → hard block, yêu cầu override có reason + supervisor confirm

## PHI/Security Issues (Chặn go-live — fix ngay)
- [ ] [Issue]: [Vị trí] → [PHI bị expose như thế nào] → [Fix]

## Compliance Issues (Fix trước production)
- [ ] [Issue]: [Quy định vi phạm] → [Fix]

## Business Logic Issues (Fix trong sprint tiếp theo)
- [ ] [Issue]: [Mô tả] → [Đề xuất]

## Suggestions (Nice-to-have)
- [ ] [Gợi ý cải thiện]

## Compliance Checklist

| Hạng mục | Trạng thái | Ghi chú |
|----------|-----------|--------|
| PHI mã hóa at-rest | OK / ISSUE | |
| TLS in-transit | OK / ISSUE | |
| PHI không leak vào logs | OK / ISSUE | |
| Audit trail READ+WRITE | OK / ISSUE | |
| Role-based access control | OK / ISSUE | |
| Consent check trước data access | OK / ISSUE | |
| Drug allergy check | OK / ISSUE | N/A nếu không có pharmacy |
| BHYT calculation accuracy | OK / ISSUE | N/A nếu không có billing |
| Thông tư 43 — lock sau ký | OK / ISSUE | N/A nếu không có EMR |

## Performance Concerns
[List performance issues nếu có]

## Sign-off
□ Patient safety controls: OK / ISSUE
□ PHI handling: OK / ISSUE
□ Audit trail: OK / ISSUE
□ BHYT/Compliance logic: OK / ISSUE
□ Business logic: OK / ISSUE
```

---

## Checklist trước khi submit

```
□ Drug allergy check đã review (nếu có pharmacy/prescription)
□ PHI không có trong logs hoặc error messages
□ Audit trail có READ operations (không chỉ WRITE)
□ BHYT calculation đã verify với ít nhất 2-3 test cases
□ Break-the-glass access có log reason
□ Critical lab values có alert đến bác sĩ (nếu có lab module)
□ Patient safety issues được đánh dấu rõ ràng là "Chặn go-live"
□ Issues được phân loại theo mức độ nghiêm trọng
```
