# Playbook: Audit Healthcare Systems Hiện Có

> **Type**: Agent Skill Playbook
> **Agent**: healthcare-expert
> **Triggered by**: /wf-legacy-scan khi phát hiện hệ thống hospital/clinic/HIS/EMR cũ
> **Output**: `.mc-data/docs/phase1-business/healthcare-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống y tế (HIS, EMR, phần mềm phòng khám)
- Khi cần đánh giá current state trước khi thiết kế hệ thống mới
- Khi cần tìm gaps về compliance, data quality, integration
- Khi cần đánh giá rủi ro migration dữ liệu bệnh nhân

---

## Procedure

### Bước 1: Inventory hệ thống hiện có

```
READ: personas.md → Admin persona để hiểu ai vận hành hệ thống

Thu thập thông tin từ stakeholders hoặc codebase:

Hệ thống chính (core systems):
□ HIS (Hospital Information System): Tên phần mềm? Vendor? Version? Năm triển khai?
□ EMR/EHR: Tách biệt hay tích hợp trong HIS? Paper records hay digital?
□ LIS (Laboratory Information System): Có riêng không? Kết nối HIS?
□ RIS/PACS (Radiology): Có hệ thống hình ảnh không? Loại nào?
□ Pharmacy System: Quản lý dược có tách biệt không?
□ Billing/Kế toán: Phần mềm kế toán y tế đang dùng?
□ BHYT Module: Đang kết nối cổng BHYT theo cách nào?

Hạ tầng:
□ Server: On-premise / Cloud / Hybrid?
□ Database: SQL Server / MySQL / Oracle / Khác?
□ Backup: Có không? Tần suất? Có test restore chưa?
□ Network: Có phân vùng bảo mật (VLAN y tế riêng)?
□ Uptime: Có SLA không? Downtime lịch sử?

Tích hợp hiện tại:
□ Các module đang connect với nhau qua cơ chế nào? (Direct DB / API / HL7 v2 / File)
□ Thiết bị y tế nào đang đổ dữ liệu vào hệ thống? (máy xét nghiệm, monitor...)
□ Cổng BHYT: kết nối online hay upload file định kỳ?
```

### Bước 2: Data Quality Assessment — Patient Records

```
READ: compliance.md → Access Control + Audit Trail Requirements

Đánh giá chất lượng hồ sơ bệnh nhân:

Completeness (đầy đủ):
□ Tỷ lệ hồ sơ có đủ: họ tên + ngày sinh + giới tính + số điện thoại? (target: >95%)
□ Tỷ lệ hồ sơ có CCCD / số BHYT? (quan trọng cho BHYT quyết toán)
□ Tỷ lệ hồ sơ thiếu địa chỉ? (cần cho liên hệ và phân tích dịch tễ)
□ Tỷ lệ encounter không có chẩn đoán ICD-10? (ảnh hưởng BHYT và reporting)

Accuracy (chính xác):
□ Phát hiện duplicate patients: chạy fuzzy match theo họ tên + ngày sinh
  → Tỷ lệ dup ước tính? (>5% là nghiêm trọng)
□ Ngày sinh có nhiều record 01/01/YYYY (default fill) không?
□ Số BHYT format có hợp lệ không? (15 ký tự, đúng tỉnh/loại đối tượng)
□ Thuốc kê trong đơn có còn trong danh mục BHYT hiện hành không?

Consistency (nhất quán):
□ ICD-10 codes đang dùng: phiên bản nào? Có code lỗi thời không?
□ Tên thuốc: generic name hay thương hiệu? Có chuẩn hóa không?
□ Đơn vị đo lường sinh hiệu: VN chuẩn (mmHg, °C, kg)?

Timeliness (kịp thời):
□ Hồ sơ bệnh án có finalize trong ngày khám không? (yêu cầu Thông tư 43)
□ Kết quả xét nghiệm được nhập vào trong bao lâu sau khi có kết quả?
□ Có backlog hồ sơ chưa được số hóa từ paper records?
```

### Bước 3: Compliance Gap Analysis

```
READ: compliance.md → Regulatory Framework, Audit Trail

Vietnam Compliance Gaps:
□ Thông tư 43/2013/TT-BYT — Hồ sơ bệnh án điện tử:
   - Hồ sơ có chữ ký điện tử của bác sĩ không?
   - Có audit trail cho mọi thay đổi hồ sơ không?
   - Hồ sơ có bị sửa sau khi ký không? (vi phạm nghiêm trọng)
   - Lưu trữ tối thiểu 10 năm — có đảm bảo không?

□ BHYT Integration:
   - Đang kết nối theo chuẩn XML của BHXH VN không?
   - Tỷ lệ claim rejected trong 3 tháng gần nhất? (target: <5%)
   - Có track được lý do reject để cải thiện?
   - Danh mục thuốc/vật tư/kỹ thuật đang cập nhật tần suất nào?

□ Nghị định 13/2023 — Dữ liệu cá nhân:
   - PHI có được mã hóa at-rest không?
   - Có consent management cho việc thu thập data không?
   - Có quy trình xử lý khi data breach?

International Standards (nếu áp dụng):
□ HIPAA: Chỉ áp dụng nếu có bệnh nhân người Mỹ hoặc partner US
□ HL7 FHIR: Hệ thống có expose FHIR API không?
□ ICD-10-CM vs ICD-10 VN: Đang dùng bản nào?

Access Control Audit:
□ Role-based access control có đúng không?
   → Bác sĩ chỉ thấy BN được assign cho mình?
   → Billing chỉ thấy financial data?
□ Có shared login / generic accounts không? (vi phạm audit trail)
□ Inactive accounts có được disable không?
□ Password policy đang áp dụng?
□ MFA có không? (khuyến nghị cho clinical staff)
```

### Bước 4: Integration Health Check

```
READ: clinical-workflows.md → Laboratory Workflow

Kiểm tra từng integration point:

HIS ↔ LIS (Laboratory):
□ Kết nối hai chiều hay một chiều? (Lý tưởng: HIS gửi order, LIS trả kết quả)
□ Độ trễ từ khi có kết quả đến khi BS thấy trong HIS? (target: <5 phút)
□ Critical values có alert ngay cho BS không? (xem clinical-workflows.md)
□ Có xảy ra mất mẫu / order không khớp không?

HIS ↔ Pharmacy:
□ Đơn thuốc từ HIS có tự động sang hệ thống dược không?
□ Có kiểm tra tồn kho thuốc real-time không?
□ Drug interaction check đang ở bước nào? (kê đơn hay chỉ khi cấp phát?)

HIS ↔ PACS (Imaging):
□ Order chụp chiếu từ HIS tự động tạo worklist trong PACS không?
□ Bác sĩ xem phim DICOM trong HIS hay phải mở phần mềm khác?
□ Report radiology tự động về HIS hay nhập tay?

HIS ↔ Thiết bị y tế:
□ Thiết bị nào đang kết nối tự động? (monitor, máy đo sinh hiệu...)
□ Thiết bị nào vẫn đang nhập tay? → Rủi ro sai sót

External:
□ BHYT portal: upload file hay realtime API? Tần suất sync?
□ Báo cáo Bộ Y tế: manual hay automated?
```

### Bước 5: Patient Data Migration Risk Assessment

```
Đánh giá rủi ro khi migrate sang hệ thống mới:

Volume Assessment:
□ Số lượng patient records: _____ records
□ Số lượng encounters/visits: _____ records
□ Số lượng lab results: _____ records
□ Khoảng thời gian dữ liệu: Từ năm _____ đến nay
□ Dung lượng PACS/imaging: _____ TB (nếu có)

Data Format Analysis:
□ Database schema có được document không? Hay phải reverse engineer?
□ Có custom fields / workaround không? (thường gặp ở HIS cũ)
□ Text encoding: UTF-8 hay dùng encoding khác cho tiếng Việt?
□ Date formats: Có nhất quán (YYYY-MM-DD) hay mixed?
□ Có blob/binary data (scanned documents) không? Xử lý thế nào?

De-identification Requirements:
□ Dữ liệu nào được phép dùng cho testing/dev? → Phải de-identify PHI
□ De-identification method: HIPAA Safe Harbor (18 identifiers) hay Expert Determination?
□ Giả mạo dữ liệu: synthetic data generation hay scrambling?

Migration Strategy:
□ Big bang (cutover 1 lần) vs Phased migration (theo module/theo time)
□ Parallel run: Chạy 2 hệ thống song song bao lâu?
□ Historical data: Migrate toàn bộ hay chỉ N năm gần nhất?
□ Validation plan: Audit sample sau migration (5-10% records)
□ Rollback plan: Nếu phát sinh vấn đề sau go-live?

Rủi ro PHI trong Migration:
□ Kênh truyền data: encrypted (TLS/SSH)?
□ Staging environment: có PHI không? → Phải de-identify hoặc có access control
□ Logging migration: có log PHI vào file log không?
□ Vendor access: vendor migration team có ký NDA + xử lý PHI đúng cách?
```

### Bước 6: Output — Healthcare As-Is Analysis Report

```markdown
# Healthcare System As-Is Analysis

## Executive Summary
[3-5 dòng: tình trạng tổng thể, điểm mạnh, gaps nghiêm trọng nhất]

## 1. Current System Inventory

### HIS / Core System
| Hệ thống | Vendor/Platform | Version | Năm triển khai | Trạng thái |
|-----------|----------------|---------|----------------|-----------|
| HIS chính | ... | ... | ... | Active |
| EMR | ... | ... | ... | ... |
| LIS | ... | ... | ... | ... |
| PACS | ... | ... | ... | ... |
| Pharmacy | ... | ... | ... | ... |
| Billing | ... | ... | ... | ... |

### Integration Map
[Sơ đồ hoặc bảng: Hệ thống A → Hệ thống B, Cơ chế, Tình trạng]

## 2. Data Quality Assessment

| Chỉ số | Hiện tại | Target | Gap |
|--------|----------|--------|-----|
| Hồ sơ đầy đủ thông tin cơ bản | ...% | >95% | ... |
| Duplicate patient rate | ...% | <1% | ... |
| ICD-10 coverage trên encounters | ...% | >98% | ... |
| BHYT claim acceptance rate | ...% | >95% | ... |
| Hồ sơ có chữ ký điện tử | ...% | 100% | ... |

## 3. Compliance Gap Analysis

### Critical Gaps (vi phạm pháp lý — phải fix)
- [ ] [Gap]: [Mô tả vi phạm] → [Quy định tham chiếu] → [Hành động đề xuất]

### High Priority Gaps (rủi ro vận hành)
- [ ] [Gap]: [Mô tả] → [Rủi ro] → [Đề xuất]

### Medium Priority Gaps
- [ ] [Gap]: [Mô tả] → [Đề xuất]

## 4. Integration Health

| Integration | Tình trạng | Vấn đề | Priority |
|-------------|-----------|--------|---------|
| HIS ↔ LIS | Hoạt động / Lỗi / Không có | ... | ... |
| HIS ↔ PACS | ... | ... | ... |
| HIS ↔ BHYT | ... | ... | ... |
| HIS ↔ Pharmacy | ... | ... | ... |

## 5. Migration Risk Assessment

### Data Volume
| Loại data | Số lượng | Dung lượng | Độ phức tạp |
|-----------|---------|-----------|------------|
| Patient records | ... | ... | ... |
| Encounters | ... | ... | ... |
| Lab results | ... | ... | ... |

### Migration Risks
| Rủi ro | Mức độ | Xác suất | Biện pháp giảm thiểu |
|--------|--------|---------|----------------------|
| Mất PHI trong migration | Critical | Thấp | Encryption + audit log migration |
| Data mapping lỗi | High | Trung bình | Validation sample 10% sau migrate |
| Downtime kéo dài | High | Thấp | Phased migration + parallel run |
| Duplicate patients sau merge | Medium | Cao | Chạy dedup trước migration |

## 6. Recommendations

### Quick Wins (< 1 tháng, không cần hệ thống mới)
1. [Recommendation] — Effort: Thấp, Impact: Cao

### Short-term (1-3 tháng)
1. [Recommendation]

### Long-term (cần hệ thống mới)
1. [Recommendation]

## 7. Questions for Stakeholders
□ [Question về quy định BHYT cụ thể của cơ sở]
□ [Question về kế hoạch migration timeline]
□ [Question về yêu cầu parallel run]
```

---

## Checklist trước khi submit

```
□ Đã inventory đủ tất cả hệ thống hiện có (không bỏ sót HIS nào)
□ Duplicate patient rate đã được ước tính (quan trọng cho migration)
□ Compliance gaps phân loại theo mức độ (Critical / High / Medium)
□ BHYT rejection rate đã thu thập (nếu có)
□ PHI de-identification plan đã nêu trong migration risks
□ Không log PHI thực vào báo cáo — dùng aggregate statistics
□ Recommendations có phân loại timeline rõ ràng
□ Open questions cho stakeholders về legal/BHYT đã list
```
