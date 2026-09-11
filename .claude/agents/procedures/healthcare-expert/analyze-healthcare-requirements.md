# Playbook: Phân tích Healthcare Requirements

> **Type**: Agent Skill Playbook
> **Agent**: healthcare-expert
> **Triggered by**: /wf-analyze-requirements khi có module liên quan đến healthcare, hospital, clinic, EMR, patient management
> **Output**: `.mc-data/docs/phase1-business/healthcare-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: bệnh viện, phòng khám, EMR/EHR, quản lý bệnh nhân, telemedicine, xét nghiệm, dược phẩm
- Khi cần xác định healthcare requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại hình cơ sở y tế: Clinic (phòng khám) / Hospital (bệnh viện) / Telemedicine / Lab / Pharmacy
□ Quy mô: Phòng khám đơn lẻ / Chuỗi phòng khám / Bệnh viện đa khoa / Chuyên khoa
□ Thị trường: Việt Nam / Quốc tế / Cả hai (ảnh hưởng regulatory framework)
□ Đã có hệ thống cũ chưa? HIS, EMR, phần mềm kế toán y tế?
□ Tích hợp bắt buộc: BHYT, HIS quốc gia, kết quả xét nghiệm?
□ Interface type: Web HIS / Mobile app cho bệnh nhân / Kiosk check-in / Tất cả?
```

### Bước 2: Xác định scope healthcare modules cần có

Dựa trên loại hình cơ sở y tế, map ra modules:

| Loại hình | Modules thường cần |
|-----------|-------------------|
| Phòng khám đơn giản | Đặt lịch, Tiếp nhận BN, Khám bệnh, Kê đơn, Thu phí |
| Phòng khám chuyên khoa | Trên + Hồ sơ EMR, Kết quả xét nghiệm, Tái khám |
| Bệnh viện đa khoa | Trên + Nhập viện/Xuất viện, Quản lý giường, Phẫu thuật, BHYT |
| Chuỗi phòng khám | Trên + Multi-site, Chuyển viện nội bộ, Dashboard tổng hợp |
| Telemedicine | Booking online, Video call, E-prescription, Digital records |
| Phòng lab | Tiếp nhận mẫu, Kết quả, Báo cáo, Tích hợp HIS |
| Nhà thuốc | Kê đơn điện tử, Quản lý kho thuốc, BHYT dược |

Sau khi xác định scope → load knowledge file tương ứng:

```
Personas → READ: personas.md
Clinical workflows → READ: clinical-workflows.md
Compliance/BHYT/HIPAA → READ: compliance.md
```

### Bước 3: Map personas bị ảnh hưởng

```
READ: personas.md

Xác định ai sẽ dùng hệ thống:
□ Bác sĩ (Doctor/Physician) → cần EMR, kê đơn, tra kết quả nhanh
□ Điều dưỡng/Y tá (Nurse) → cần MAR, theo dõi sinh hiệu, chăm sóc
□ Bệnh nhân (Patient) → cần đặt lịch, xem kết quả, giao tiếp với BS
□ Lễ tân/Tiếp nhận (Admin/Registration) → cần quản lý lịch hẹn, tiếp nhận
□ Kỹ thuật viên xét nghiệm (Lab Tech) → cần quản lý mẫu, nhập kết quả
□ Dược sĩ (Pharmacist) → cần xem đơn thuốc, kiểm tra tương tác thuốc
□ Kế toán/BHYT (Billing) → cần thanh toán, lập hóa đơn, quyết toán BHYT
□ Quản lý (Administrator) → cần dashboard, báo cáo vận hành

Với mỗi persona: ghi pain points cụ thể + must-have features
```

### Bước 4: Xác định regulatory framework

```
READ: compliance.md

Xác định khung pháp lý áp dụng:

VN (Bắt buộc):
□ Luật Khám bệnh, chữa bệnh 2009 (sửa đổi 2023)
□ Thông tư 46/2018/TT-BYT — Quy chế bệnh viện
□ Thông tư 43/2013/TT-BYT — Hồ sơ bệnh án điện tử (EMR)
□ Nghị định 117/2020/ND-CP — Xử phạt vi phạm hành chính y tế
□ Nghị định 13/2023/ND-CP — Bảo vệ dữ liệu cá nhân (áp dụng PHI)
□ Quy định BHYT: Luật BHYT, danh mục thuốc, danh mục kỹ thuật

International (nếu áp dụng):
□ HIPAA (US) — Privacy Rule + Security Rule + Breach Notification
□ HL7 FHIR R4 — Chuẩn trao đổi dữ liệu y tế
□ ICD-10-CM — Mã bệnh chẩn đoán
□ SNOMED CT — Thuật ngữ lâm sàng chuẩn quốc tế

Xác định mức độ tuân thủ cần thiết → đưa vào requirements
```

### Bước 5: Data sensitivity & privacy analysis

```
Phân loại dữ liệu theo độ nhạy cảm:

PHI — Protected Health Information (bảo vệ tối đa):
□ Tên + ngày sinh + địa chỉ kết hợp với thông tin y tế
□ Hồ sơ bệnh án, chẩn đoán, thuốc đang dùng
□ Kết quả xét nghiệm, hình ảnh y tế (PACS)
□ Thông tin HIV, tâm thần, sinh sản (cần bảo vệ đặc biệt)

PII — Personally Identifiable Information (bảo vệ cao):
□ CCCD/CMND, Số BHYT, Mã số thuế
□ Số điện thoại, email
□ Thông tin thanh toán

Operational Data (bảo vệ tiêu chuẩn):
□ Lịch hẹn (không kèm clinical data)
□ Thống kê tổng hợp, báo cáo aggregate
□ Dữ liệu tài chính (không gắn với patient record)

Với mỗi loại dữ liệu → xác định:
□ Ai được truy cập?
□ Mã hóa bắt buộc ở đâu? (at-rest, in-transit)
□ Lưu trữ tối thiểu bao lâu? (medical records: 10 năm)
□ Audit trail cần ghi những gì?
```

### Bước 6: Xác định integration points

```
BHYT Integration (Bảo hiểm Y tế):
□ Kết nối Cổng thông tin BHYT (baohiemxahoi.gov.vn)
□ Tra cứu thẻ BHYT real-time
□ Lập hồ sơ khám chữa bệnh BHYT (XML format)
□ Quyết toán chi phí khám chữa bệnh theo quý
□ Danh mục thuốc, vật tư, kỹ thuật được BHYT thanh toán

Lab/Xét nghiệm Integration:
□ Gửi yêu cầu xét nghiệm từ EMR → LIS (Laboratory Information System)
□ Nhận kết quả tự động từ LIS → EMR
□ Alert kết quả bất thường/nguy hiểm cho bác sĩ

PACS/Imaging:
□ Tích hợp với hệ thống PACS để xem phim X-quang, CT, MRI
□ Liên kết lệnh chụp từ EMR với kết quả DICOM

Pharmacy Integration:
□ Gửi đơn thuốc điện tử → hệ thống nhà thuốc
□ Kiểm tra tồn kho thuốc real-time
□ Drug interaction check

External Healthcare Network:
□ Chuyển viện: gửi tóm tắt bệnh án HL7 FHIR
□ Kết nối với HIS quốc gia (nếu bắt buộc)
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-HLTH-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần — impact lâm sàng/vận hành/pháp lý]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Compliance**: [Quy định liên quan nếu có]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format cho từng module:**

```
REQ-HLTH-EMR-001   → Electronic Medical Records / Hồ sơ bệnh án điện tử
REQ-HLTH-SCH-001   → Scheduling / Đặt lịch hẹn
REQ-HLTH-ADT-001   → Admission-Discharge-Transfer / Nhập-Xuất-Chuyển viện
REQ-HLTH-LAB-001   → Laboratory / Xét nghiệm
REQ-HLTH-PHR-001   → Pharmacy / Dược phẩm, kê đơn
REQ-HLTH-BIL-001   → Billing / Thanh toán, BHYT
REQ-HLTH-PAT-001   → Patient Portal / Cổng bệnh nhân
REQ-HLTH-RPT-001   → Reporting / Báo cáo thống kê
REQ-HLTH-SEC-001   → Security / Bảo mật, quyền truy cập, audit
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/healthcare-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope healthcare của dự án)
2. Loại hình cơ sở y tế và quy mô
3. Healthcare Modules cần build (list theo priority)
4. Personas bị ảnh hưởng (bảng tóm tắt)
5. Regulatory Framework áp dụng
6. Data Classification & Privacy requirements
7. Integration requirements (BHYT, Lab, PACS, Pharmacy)
8. Requirements theo module (có REQ-ID)
9. Open questions cần confirm với stakeholders (đặc biệt về BHYT, pháp lý)
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-HLTH-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng (lâm sàng/vận hành/pháp lý)
□ PHI/PII requirements đã covered (encryption, access control, audit)
□ Compliance requirements đã identified (BHYT, Thông tư 43, HIPAA nếu áp dụng)
□ Integration với BHYT đã noted nếu bệnh viện/phòng khám có BHYT
□ Emergency access / Break-the-glass workflow đã xem xét
□ Audit trail requirements đã included
□ Open questions về regulatory compliance được list ra
```
