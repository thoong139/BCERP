# Healthcare - Controls & Access Management

> **Domain**: Healthcare / Y tế & Chăm sóc sức khỏe
> **Last Updated**: 2026-03-19

---

## 1. Approval Matrix

### Prescription Authority (by drug classification)

| Phân loại thuốc | Physician (MD) | Resident (dưới giám sát) | Nurse Practitioner | Pharmacist |
|-----------------|:--------------:|:------------------------:|:------------------:|:----------:|
| OTC (không kê đơn) | ✅ | ✅ | ✅ | ✅ (tư vấn) |
| Prescription-only (PO) | ✅ | ✅ (co-sign required) | ⚠ (một số loại) | ❌ |
| Controlled Substance – Schedule III/IV | ✅ | ❌ | ❌ | ❌ |
| Controlled Substance – Schedule I/II | ✅ (DEA registration required) | ❌ | ❌ | ❌ |
| Antibiotics (chống kháng thuốc) | ✅ (Antibiotic Stewardship review) | ✅ (co-sign) | ❌ | ❌ |
| Chemotherapy | ✅ (Oncologist specialist) | ❌ | ❌ | ✅ (kiểm tra liều) |

### Lab & Diagnostic Order Authority

| Loại xét nghiệm | Physician | Resident | Nurse Practitioner | Nurse |
|-----------------|:---------:|:--------:|:------------------:|:-----:|
| Routine labs (CBC, CMP) | ✅ | ✅ | ✅ | ❌ |
| Imaging (X-ray, CT, MRI) | ✅ | ✅ (co-sign) | ⚠ (X-ray only) | ❌ |
| Invasive procedures (biopsy, LP) | ✅ | ✅ (co-sign + consent) | ❌ | ❌ |
| Pathology / Autopsy | ✅ (Pathologist) | ❌ | ❌ | ❌ |
| Genetic testing | ✅ (with patient consent) | ❌ | ❌ | ❌ |

### Treatment Plan Approval

| Mức độ phức tạp | Attending Physician | Department Head | Specialist Consult | Ethics Committee |
|-----------------|:-------------------:|:---------------:|:------------------:|:----------------:|
| Standard protocol (guideline-based) | ✅ | ❌ required | ❌ required | ❌ |
| Off-protocol treatment | ✅ | ✅ | ⚠ (tùy specialty) | ❌ |
| Experimental / research treatment | ✅ | ✅ | ✅ | ✅ required |
| End-of-life care decisions | ✅ | ✅ | ⚠ | ✅ recommended |
| Surgical procedures (elective) | ✅ (Surgeon) | ❌ required | ❌ required | ❌ |
| High-risk surgery | ✅ (Surgeon) | ✅ | ✅ (Anesthesiology) | ❌ |

### Budget & Procurement Approval

| Giá trị | Department Head | Finance Manager | Director / CEO | Board |
|---------|:--------------:|:---------------:|:--------------:|:-----:|
| ≤10,000,000 VND | ✅ | ❌ required | ❌ required | ❌ |
| 10M–50,000,000 VND | ✅ (đề xuất) | ✅ | ❌ required | ❌ |
| 50M–500,000,000 VND | ✅ (đề xuất) | ✅ | ✅ | ❌ |
| >500,000,000 VND | ✅ (đề xuất) | ✅ | ✅ | ✅ |
| Capital equipment | ✅ (đề xuất) | ✅ | ✅ | ✅ (>5 tỷ VND) |

---

## 2. Access Control

### Clinical Record Access Matrix

| Dữ liệu | Nurse (assigned patients) | Physician (all patients) | Billing / Coder | Reception / Admin | Pharmacist |
|---------|:------------------------:|:------------------------:|:---------------:|:-----------------:|:----------:|
| Demographics (tên, DOB, địa chỉ) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Medical history & diagnoses | ✅ | ✅ | ✅ (for coding) | ❌ | ⚠ (relevant only) |
| Medication record (MAR) | ✅ | ✅ | ❌ | ❌ | ✅ |
| Lab & imaging results | ✅ | ✅ | ✅ (code only) | ❌ | ❌ |
| Psychiatry / mental health records | ❌ (separate consent) | ⚠ (treating only) | ❌ | ❌ | ❌ |
| HIV / communicable disease status | ❌ (separate consent) | ⚠ (treating only) | ❌ | ❌ | ❌ |
| Genetic test results | ❌ | ⚠ (ordering only) | ❌ | ❌ | ❌ |
| Financial / insurance data | ❌ | ❌ | ✅ | ✅ | ❌ |

> Psychiatry, HIV, và Genetic data được bảo vệ bởi separate consent requirement theo HIPAA và Decree 13/2023/NĐ-CP.

### Pharmacy System Access

| Chức năng | Pharmacist | Pharmacy Tech | Physician | Nurse |
|-----------|:----------:|:-------------:|:---------:|:-----:|
| Xem đơn thuốc | ✅ | ✅ | ✅ (own orders) | ✅ |
| Verify / approve đơn thuốc | ✅ | ❌ | ❌ | ❌ |
| Dispense thuốc | ✅ | ✅ (under supervision) | ❌ | ❌ |
| Override drug interaction alert | ✅ (with reason) | ❌ | ✅ (with reason, logged) | ❌ |
| Quản lý formulary | ✅ (Pharmacy Committee) | ❌ | ❌ | ❌ |
| Kiểm kê / adjust inventory | ✅ | ✅ (supervised) | ❌ | ❌ |
| Truy cập Controlled Substance log | ✅ | ✅ (read-only) | ❌ | ❌ |

### Billing & Insurance Access

| Chức năng | Medical Coder | Billing Specialist | Finance Manager | Reception |
|-----------|:-------------:|:-----------------:|:---------------:|:---------:|
| Xem clinical notes (for coding) | ✅ | ❌ | ❌ | ❌ |
| Assign ICD-10 / CPT codes | ✅ | ❌ | ❌ | ❌ |
| Submit insurance claims | ❌ | ✅ | ✅ | ❌ |
| Adjust patient bill | ❌ | ✅ (≤2M VND) | ✅ | ❌ |
| Write-off bad debt | ❌ | ❌ | ✅ (≤10M) | ❌ |
| Truy cập insurance contract rates | ❌ | ✅ | ✅ | ❌ |

### Break-the-Glass Emergency Access

| Điều kiện | Ai kích hoạt | Validation | Hậu kiểm |
|-----------|:------------:|------------|----------|
| Medical emergency, bệnh nhân không tỉnh | Any treating clinician | Reason required + timestamp | Compliance review trong 24h |
| System downtime affecting care | Department Head | Approve downtime mode | IT + Compliance review |
| Legal / subpoena request | Admin / Legal | Legal authorization document | Legal + Privacy Officer sign-off |

---

## 3. Workflow Controls

### Patient Flow States

| Từ trạng thái | Đến trạng thái | Điều kiện | Người thực hiện |
|---------------|----------------|-----------|-----------------|
| Scheduled | Checked-in | Patient arrives, ID verified | Reception |
| Checked-in | Triaged | Nurse assessment complete | Nurse |
| Triaged | In Consultation | Physician available | System / Nurse |
| In Consultation | Discharged (Outpatient) | Visit documentation complete, orders finalized | Physician |
| In Consultation | Admitted (Inpatient) | Admission order placed | Physician |
| Admitted | Transferred | Transfer order signed | Physician |
| Admitted | Discharged (Inpatient) | Discharge order + summary + medication reconciliation | Physician |
| Any | No-show | Patient does not arrive by appointment + buffer time | System auto |

### Prescription States

```
Ordered → Verified → Ready → Dispensed → Administered → Documented
    │          │         │         │            │              │
    ▼          ▼         ▼         ▼            ▼              ▼
  CPOE      Drug-drug  Filled   Patient      5 Rights       MAR
  entry     Allergy    by       counseled    verified       timestamp
            check      pharma                               + nurse ID
```

| Từ trạng thái | Đến trạng thái | Điều kiện |
|---------------|----------------|-----------|
| Ordered | Verified | Pharmacist drug review complete |
| Ordered | On Hold | Drug interaction flagged, pending physician clarification |
| On Hold | Verified | Physician reviewed and confirmed with reason |
| Verified | Ready | Dispensed by pharmacy |
| Ready | Dispensed | Patient / nurse receives medication |
| Dispensed | Administered | Nurse records 5 Rights, updates MAR |
| Dispensed | Refused | Patient declines — documented with reason |
| Any | Discontinued | Physician cancels order — reason required |

### Insurance Claim States

| Từ trạng thái | Đến trạng thái | Điều kiện |
|---------------|----------------|-----------|
| Draft | Submitted | Codes assigned, claim generated |
| Submitted | Accepted | Payer acknowledges receipt |
| Accepted | Approved | Payer adjudicates — full or partial |
| Accepted | Denied | Payer rejects — reason code required |
| Denied | Appealed | Billing files appeal within window (30–60 days) |
| Appealed | Approved | Appeal accepted by payer |
| Appealed | Write-off | Appeal denied, Finance Manager approves write-off |

### Hygiene Controls

| Control | Frequency | Enforcement |
|---------|-----------|-------------|
| Drug alert overrides not followed up | Daily | Pharmacy Manager review |
| Prescriptions by non-authorized staff | Per transaction | System block + alert to Chief Medical Officer |
| Clinical notes overdue >24h post-encounter | Daily | Alert → Physician + Department Head |
| Controlled substance discrepancy | Per shift | Mandatory dual-count, Pharmacy Manager sign-off |
| Expired medications in stock | Daily | System alert → Pharmacist |
| Claims approaching appeal deadline | Daily | Alert → Billing Team |
| Accounts receivable >90 days | Weekly | Escalation → Finance Manager |

---

## 4. Audit Trail Requirements

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Patient record accessed | user_id, patient_id, record_type, timestamp, purpose | 6 năm (HIPAA minimum) |
| Break-the-glass access | user_id, patient_id, reason, timestamp, supervisor_notified | 6 năm |
| Clinical note created / amended | user_id, encounter_id, old_value (nếu amended), new_value, timestamp | 10 năm sau last encounter |
| Prescription ordered | prescriber_id, patient_id, drug, dose, route, frequency, timestamp | 10 năm |
| Drug interaction alert override | user_id, drug_pair, override_reason, timestamp | 6 năm |
| Controlled substance dispensed | pharmacist_id, patient_id, drug, quantity, lot#, witness_id, timestamp | 10 năm |
| Diagnosis code assigned | coder_id, encounter_id, ICD-10 code, CPT code, timestamp | 7 năm |
| Insurance claim submitted / denied | billing_id, claim_id, payer, amount, decision_code, timestamp | 7 năm |
| Patient consent obtained / revoked | user_id, patient_id, consent_type, method, timestamp | Duration + 6 năm |
| Staff credentials accessed / updated | admin_id, staff_id, action, timestamp | Thời gian làm việc + 10 năm |
| System login failure | user_id, timestamp, IP, failure_count | 3 năm |

### Sensitive Data Access Log

| Dữ liệu nhạy cảm | Ai được truy cập | Mục đích ghi log |
|-------------------|:----------------:|-----------------|
| Psychiatry records | Treating psychiatrist + direct care team | Separate consent compliance |
| HIV status | Treating physician only | Separate consent compliance |
| Genetic data | Ordering physician only | Separate consent compliance |
| Controlled substance dispense log | Pharmacist + Pharmacy Manager | DEA / regulatory compliance |
| Minor patient records | Treating team + legal guardian | Legal guardian access rights |

### Data Retention Schedule

| Loại hồ sơ | Thời gian lưu trữ | Cơ sở pháp lý |
|------------|:-----------------:|---------------|
| Hồ sơ bệnh án người lớn | 10 năm sau lần khám cuối | Decree 117/2020/NĐ-CP |
| Hồ sơ bệnh án trẻ em | Đến 18 tuổi + 10 năm | Decree 117/2020/NĐ-CP |
| Audit logs (truy cập hệ thống) | 6 năm | HIPAA Security Rule |
| Phiếu đồng ý (consent forms) | Thời gian quan hệ + 6 năm | HIPAA Privacy Rule |
| Hóa đơn và chứng từ tài chính | 10 năm | Luật Kế toán Việt Nam |
| Controlled substance records | 10 năm | DEA regulations |

---

## Quick Reference: Approval Checklist

### Trước khi kê đơn Controlled Substance
- [ ] Prescriber có đăng ký DEA / license phù hợp
- [ ] Patient identity verified (2 identifiers)
- [ ] Drug–drug và drug–allergy check complete
- [ ] Prescription documented trong CPOE (không chấp nhận verbal order cho Schedule II)
- [ ] Pharmacist counter-sign cho Schedule I/II

### Trước khi thực hiện phẫu thuật
- [ ] Informed consent signed bởi patient / legal guardian
- [ ] Surgical site marking hoàn tất
- [ ] Pre-operative checklist complete (WHO Surgical Safety Checklist)
- [ ] Anesthesiology clearance
- [ ] Blood type và cross-match sẵn sàng (nếu applicable)

### Trước khi discharge bệnh nhân
- [ ] Discharge order ký bởi Attending Physician
- [ ] Discharge summary hoàn chỉnh (diagnoses, procedures, medications at discharge)
- [ ] Medication reconciliation complete
- [ ] Follow-up appointment scheduled
- [ ] Patient education documented (có xác nhận của bệnh nhân)
