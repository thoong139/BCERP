# Insurance Control Requirements

> Reference file cho insurance-expert agent
> Load file này khi cần define authorization, controls, fraud detection, solvency

## 1. Underwriting Authority Matrix

| Role | Standard Risk | Rated Risk | Complex Risk / Special Terms |
|------|:------------:|:----------:|:-----------------------------:|
| Junior Underwriter | ≤ VND 500M sum insured | ❌ | ❌ |
| Senior Underwriter | ≤ VND 2B sum insured | ≤ VND 2B | ❌ |
| UW Manager | ≤ VND 10B sum insured | ≤ VND 10B | ✅ (apply exclusions) |
| CUO (Chief Underwriting Officer) | Unlimited | Unlimited | ✅ (special terms) |
| Reinsurer | N/A | N/A | Mandatory referral > retention limit |

### Retention Limits (Ví dụ điển hình)

| Line of Business | Typical Retention Limit |
|-----------------|------------------------|
| Motor | VND 500M per vehicle |
| Property | VND 5B per location |
| Life (death benefit) | VND 2B per life |
| Marine cargo | VND 1B per shipment |
| Liability | VND 3B per occurrence |

> ⚠️ Retention limits là configurable per product — phải implement dưới dạng parameter, không hardcode.

---

## 2. Claims Settlement Approval Matrix

| Role | Approve Settlement | Recommend Only | Deny Authority |
|------|:-----------------:|:--------------:|:--------------:|
| Claims Assistant | ≤ VND 10M | > VND 10M | ❌ |
| Claims Adjuster | ≤ VND 50M | > VND 50M | ❌ (cần Manager) |
| Senior Adjuster | ≤ VND 200M | > VND 200M | ✅ (với Manager review) |
| Claims Manager | ≤ VND 1B | > VND 1B | ✅ (minimum for denial) |
| CEO / Board | > VND 1B | — | ✅ |

### Quy tắc Dual Control (BẮT BUỘC)

```
RULE: Người tạo/điều tra claim ≠ Người phê duyệt settlement
RULE: Claims Adjuster không thể approve settlement cho claim của chính mình
RULE: Mọi settlement phải có ≥ 2 người ký (Adjuster + Supervisor minimum)
RULE: Denial requires Claims Manager sign-off minimum — không có exception
```

### Escalation Matrix

| Trigger | Escalation To |
|---------|---------------|
| Settlement amount vượt adjuster limit | Claims Manager |
| Fraud score > 70 | Senior Adjuster + Fraud Team |
| Coverage dispute (KH khiếu nại) | Claims Manager + Legal |
| Catastrophe event (≥ 10 claims cùng event) | CRO + Reinsurer notification |
| Media-sensitive case | CEO + PR team |

---

## 3. Fraud Detection Controls

### Rule-based Flags (Tự động)

| Rule | Điều kiện kích hoạt | Hành động |
|------|---------------------|-----------|
| **Velocity — Early Claim** | Claims filed within 30 days of policy inception | Flag → Mandatory investigation |
| **Frequency — Claimant** | Same claimant in > 3 claims/12 months | Flag → Senior Adjuster review |
| **Frequency — Provider** | Same doctor/repair shop in > 5 claims/month | Flag → Fraud Team review |
| **Blacklist Match** | Claimant/witness/provider khớp fraud registry | Block → Fraud Team mandatory |
| **Document Inconsistency** | Claim form vs supporting docs inconsistent | Flag → Investigation required |
| **Duplicate Claim** | Same event, same claimant, multiple submissions | Block immediately |
| **Round Number** | Settlement amount là số tròn đẹp (VD: exactly 50M) | Soft flag |

### ML-based Fraud Score

| Score Range | Interpretation | Hành động |
|-------------|----------------|-----------|
| 0-30 | Low risk | Proceed normally |
| 31-60 | Medium risk | Additional document review |
| 61-80 | High risk | Mandatory investigation |
| 81-100 | Very high risk | Full fraud investigation, payment hold |

### Industry Fraud Registry

- Chia sẻ giữa các công ty bảo hiểm (industry database)
- Match on: CCCD/Passport number, Vehicle plate, License plate, Doctor license number
- Contribution: Mỗi confirmed fraud case được submit vào registry

---

## 4. Solvency & Reserve Controls

### Reserve Types

| Reserve | Mô tả | Tính khi nào |
|---------|-------|--------------|
| **Unearned Premium Reserve (UPR)** | Phần phí chưa được hưởng (remaining coverage period) | Hàng ngày, tự động |
| **Outstanding Claims Reserve (OCR)** | Ước tính claims đã biết chưa settle | Set tại FNOL, review mỗi milestone |
| **IBNR** | Incurred But Not Reported — claims đã xảy ra chưa báo cáo | Actuarial calculation quarterly |
| **Premium Deficiency Reserve (PDR)** | Khi UPR không đủ cover future claims | Actuarial trigger |

### Cục Giám sát Bảo hiểm Reporting (Thông tư 67/2023)

| Report | Frequency | Deadline | Submitted by |
|--------|-----------|----------|--------------|
| Premium & Claims Statistics | Quarterly | 30 ngày sau quarter end | Finance + Actuarial |
| Solvency Capital Requirement (SCR) | Quarterly | 45 ngày sau quarter end | Actuarial |
| Annual Actuarial Report | Annual | 90 ngày sau year end | Appointed Actuary |
| Large Claims Report | Ad-hoc | Within 10 days of event | Claims Manager |
| Reinsurance ceded statistics | Semi-annual | 30 ngày sau period end | Reinsurance Team |

### Solvency Control Rules

```
SCR Ratio = Eligible Capital / Solvency Capital Requirement
Minimum: SCR Ratio ≥ 100% (Thông tư 67/2023 requirement)
Alert threshold: SCR Ratio < 120% → Notify CRO
Action required: SCR Ratio < 110% → Remediation plan to Cục GS BH
```

---

## 5. Policy Controls

### Anti-Churning Controls

| Control | Mô tả | Trigger |
|---------|-------|---------|
| **Policy Replacement Detection** | Check nếu new policy replace existing policy cùng KH | Khi bind new policy |
| **Agent Self-Dealing Prevention** | Agent không thể là beneficiary/claimant trên policy của KH mình | System check at claim submission |
| **Pro-rata Refund Calculation** | KH-initiated cancel: short-rate (penalty). Company-initiated: pro-rata | At cancellation |

### Premium Lapse Controls

```
D-60: First renewal reminder (email/SMS)
D-30: Second renewal reminder + agent notification
D-7:  Final reminder + easy payment link
D-0:  Policy expiry / Renewal due date
D+1:  Grace period starts (30 days per Luật KDBH)
D+15: Second lapse warning
D+30: Policy lapsed, coverage ended
D+30 to D+730: Reinstatement window (with conditions)
```

### Endorsement Controls

| Endorsement Type | Requires Underwriting Review | Requires KH Consent |
|------------------|:----------------------------:|:-------------------:|
| Address change | ❌ | ✅ |
| Beneficiary change | ❌ | ✅ (với existing beneficiary consent nếu irrevocable) |
| Sum insured increase | ✅ | ✅ |
| Coverage extension | ✅ | ✅ |
| Premium payment method change | ❌ | ✅ |
| Named driver change (motor) | ✅ | ✅ |

---

## 6. Data Privacy Controls (Health Data)

### Nghị định 13/2023/NĐ-CP — Health Data as Sensitive Personal Data

| Yêu cầu | Implementation |
|---------|----------------|
| **Encryption at rest** | AES-256 minimum cho medical records |
| **Access logging** | Mọi access phải log: user ID, timestamp, purpose |
| **Consent** | Explicit consent recorded tại điểm thu thập |
| **Data minimization** | Chỉ collect fields cần thiết cho UW/Claims |
| **Retention** | Medical records: 10 năm |
| **Right to access** | Policyholder có quyền xem data của mình |
| **Third-party sharing** | Medical data chỉ share với reinsurer (on need-to-know, với DPA) |

### Role-based Access to Medical Data

| Role | Access Level |
|------|-------------|
| Sales Agent | ❌ Không có access |
| Underwriter | ✅ Chỉ record liên quan đến application đang xử lý |
| Claims Adjuster | ✅ Chỉ record liên quan đến claim đang xử lý |
| Actuary | ✅ Anonymized aggregate data only |
| IT Admin | ❌ Không được đọc content — chỉ infrastructure |
| Compliance Officer | ✅ Audit trail access (không đọc raw medical data) |

---

## 7. Audit Trail Requirements

### Insurance-specific Audit Events

| Event | Data to Capture | Retention |
|-------|-----------------|-----------|
| UW decision (accept/rate/decline) | User, timestamp, risk factors, score, decision, reason code | 10 years |
| Coverage exclusion applied | User, timestamp, exclusion type, reason, customer notified | 10 years |
| Claims coverage decision | Adjuster, supervisor, timestamp, coverage determination, reason | 10 years |
| Settlement approved | Approver chain, amount, timestamp, payment instructions | 10 years |
| Fraud flag raised/cleared | User, rule triggered, action taken | 10 years |
| Policy endorsement | Requester, approver, change details, effective date | 10 years |
| Reserve movement | Actuary/Adjuster, timestamp, old vs new amount, reason | 10 years |
| Reinsurer referral | User, risk details, reinsurer response, timestamp | 10 years |

---

## Quick Reference

### Approval Thresholds Summary

| Transaction | Role | Limit |
|-------------|------|-------|
| UW — Accept standard | Junior UW | ≤ 500M |
| UW — Accept rated | Senior UW | ≤ 2B |
| UW — Special terms | UW Manager | ≤ 10B |
| UW — Any amount | CUO | Unlimited |
| Claims — Settle | Claims Assistant | ≤ 10M |
| Claims — Settle | Adjuster | ≤ 50M |
| Claims — Settle | Senior Adjuster | ≤ 200M |
| Claims — Settle | Claims Manager | ≤ 1B |
| Claims — Settle | CEO | > 1B |
| Claims — Deny | Claims Manager | Minimum required |

### SoD Rules — Insurance

```
UW Creator ≠ UW Approver (for same application)
Claims Investigator ≠ Claims Approver (for same claim)
Agent ≠ Claims Beneficiary (for same policy)
Reserve Setter ≠ Reserve Approver (for IBNR)
```
