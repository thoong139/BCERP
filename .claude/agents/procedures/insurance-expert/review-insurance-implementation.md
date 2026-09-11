# Playbook: Review Insurance Implementation

> **Type**: Agent Procedure
> **Agent**: insurance-expert
> **Triggered by**: /wf-implement-feature review pass cho insurance modules
> **Output**: Review report (inline hoặc file tùy skill cung cấp)

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-implement-feature` hoặc `/wf-fix-bugs` khi cần review insurance module
- Khi cần verify implementation tuân thủ: Regulatory requirements, underwriting controls, claims controls, data privacy

---

## Procedure

### Bước 1: Đọc Context

```
INPUT: File hoặc module cần review (paths do skill cung cấp)
READ: .mc-data/docs/phase1-business/insurance-requirements.md → relevant REQ-IDs
READ: .mc-data/docs/phase3-architecture/insurance/ → design specs

Xác định:
□ Module đang review: POLICY | UW | CLAIMS | REINSURANCE | DISTRIBUTION | ACTUARIAL
□ REQ-IDs liên quan (từ registry hoặc inline code comments)
□ Line of business: Life / Non-life / Health
```

### Bước 2: Thực hiện Review theo Checklist

---

## Checklist 1: Regulatory Compliance (BẮT BUỘC — Phải PASS hết)

```
Luật KDBH 08/2022:
□ Policy document chứa đầy đủ required fields:
  - Policy number
  - Tên và địa chỉ công ty bảo hiểm
  - Tên và địa chỉ bên mua bảo hiểm, người được bảo hiểm
  - Đối tượng bảo hiểm, phạm vi bảo hiểm
  - Số tiền bảo hiểm / giới hạn trách nhiệm
  - Phí bảo hiểm, phương thức thanh toán phí
  - Thời hạn bảo hiểm, thời điểm có hiệu lực
  - Quyền và nghĩa vụ các bên
□ Grace period 30 ngày enforced cho non-payment (không thể config xuống dưới)
□ Reinstatement window configurable (mặc định 2 năm cho life)
□ Từ chối bảo hiểm: Có notification bằng văn bản + lý do cụ thể

Thông tư 67/2023 (Solvency):
□ Solvency metrics có thể tính và xuất báo cáo được
□ Cục GS Bảo hiểm report format khớp với template chính thức
□ IBNR reserve có thể export data cho actuarial calculation
□ Premium statistics report đúng format quarterly submission

RESULT: [ ] PASS  [ ] FAIL — List issues:
```

---

## Checklist 2: Underwriting Controls

```
UW Authority Matrix:
□ System enforce UW authority limits (cannot approve above own limit)
□ Junior UW không thể approve > VND 500M sum insured
□ Reinsurance referral triggered tự động khi sum insured > retention limit
□ Retention limit configurable per product (không hardcode)

UW Decision Audit Trail:
□ Mọi UW decision được lưu: User, timestamp, risk factors, score, decision, reason code
□ Applied exclusions được lưu: Exclusion type, reason, customer notification date
□ Decline letters: Stored, timestamped, includes regulatory right-to-appeal notice

Pre-existing Conditions (Life/Health):
□ Pre-existing conditions collected và stored tại application
□ Exclusions applied correctly reference the pre-existing condition
□ Exclusion áp dụng đúng giai đoạn (exclusion period vs permanent exclusion)

Reinsurer Referral:
□ Referral workflow có status tracking (sent, responded, terms)
□ Reinsurer response stored và traceable
□ Bordereau report generation works correctly

RESULT: [ ] PASS  [ ] FAIL — List issues:
```

---

## Checklist 3: Claims Controls

```
Dual Control:
□ Người tạo/điều tra claim ≠ Người phê duyệt settlement (system enforced, không chỉ guideline)
□ Adjuster không thể approve settlement trên chính claim mình đang handle
□ Claims Assistant ≤ 10M, Adjuster ≤ 50M, Senior ≤ 200M, Manager ≤ 1B (enforced)

Coverage Denial:
□ Any denial requires Claims Manager sign-off (minimum) — system blocks if missing
□ Denial letter generated với: reason code, coverage clause cited, appeal rights
□ Denial notification gửi qua registered channel (không chỉ internal note)

Fraud Controls:
□ Fraud scoring chạy tự động trên mọi claim (không optional)
□ Score > threshold → payment hold enforced automatically
□ Fraud flag cleared only by authorized role (Fraud Team / Senior Adjuster)

Reserve Tracking:
□ Mỗi reserve change có ReserveMovement record: who, when, why, old/new amount
□ Reserve released only after payment confirmed (không release trước)
□ IBNR reserve data export đầy đủ fields cho actuarial model

Subrogation:
□ Subrogation potential flagged automatically (khi event has third-party)
□ Legal team notification workflow tồn tại

RESULT: [ ] PASS  [ ] FAIL — List issues:
```

---

## Checklist 4: Health Data Privacy (Áp dụng nếu có Life/Health module)

```
Nghị định 13/2023/NĐ-CP:
□ Medical records encrypted at rest (AES-256 minimum)
□ Mọi access đến medical data được log: user ID, timestamp, purpose
□ Consent recorded tại điểm thu thập (với datetime, consent version)
□ Medical data không accessible từ sales/agent roles (role check at API level)
□ IT Admin không thể đọc raw medical content (encryption + role separation)
□ Actuarial access: Anonymized/aggregate only (no individual PII)

Data Sharing:
□ Medical data chỉ shared với reinsurer khi có Data Processing Agreement (DPA)
□ Sharing log: Which data, shared with whom, when, purpose

Retention:
□ Medical records: Retained 10 năm (per regulation)
□ Deletion workflow: Không xóa trước 10 năm, xóa đúng quy trình sau đó

RESULT: [ ] PASS / N/A  [ ] FAIL — List issues:
```

---

## Checklist 5: Financial Accuracy

```
Premium Calculation:
□ Spot check 10 policies ngẫu nhiên: Tính lại premium bằng tay từ rating manual
  → Variance acceptable? (< 1% rounding tolerance)
□ Premium breakdown (base + surcharges + discounts) hiển thị cho user
□ Pro-rata refund tính đúng khi company-initiated cancellation
□ Short-rate refund tính đúng khi policyholder-initiated cancellation

Reserve Accounting:
□ Unearned Premium Reserve (UPR) cập nhật đúng khi policy cancel/lapse
□ Claims reserve (OCR) released chính xác sau settlement paid
□ Premium installment schedule khớp với payment_frequency setting

Commission:
□ Agent commission calculated correctly per commission schedule
□ Commission chargeback (clawback) khi policy lapse trong period
□ Commission statement export đúng cho agent

RESULT: [ ] PASS  [ ] FAIL — List issues:
```

---

## Bước 3: Tổng hợp và Output

```
Rating:
  ALL 5 checklists PASS → APPROVED
  Checklist 1 hoặc 3 FAIL → BLOCKED (regulatory/safety — phải fix trước deploy)
  Checklist 2, 4, 5 FAIL → NEEDS_WORK (fix trước next release)

Report format:
  ## Insurance Implementation Review — [Module Name]
  **Date**: [date]
  **Reviewer**: insurance-expert
  **REQ-IDs covered**: [list]

  ### Overall: [APPROVED | NEEDS_WORK | BLOCKED]

  ### Checklist Results
  | Checklist | Result | Issues |
  |-----------|--------|--------|
  | 1. Regulatory Compliance | [PASS/FAIL] | [count] issues |
  | 2. Underwriting Controls | [PASS/FAIL] | [count] issues |
  | 3. Claims Controls | [PASS/FAIL] | [count] issues |
  | 4. Health Data Privacy | [PASS/N/A/FAIL] | [count] issues |
  | 5. Financial Accuracy | [PASS/FAIL] | [count] issues |

  ### Issues Found (nếu có)
  [Chi tiết từng issue: Checklist, mô tả, severity, recommended fix]

  ### Recommended Actions
  [Danh sách actions cần thực hiện trước khi APPROVED]
```

---

## Quick Reference — Critical Rules

```
NEVER deploy với:
  ❌ Grace period < 30 ngày (Luật KDBH violation)
  ❌ Claims denial không có Claims Manager approval
  ❌ Settlement không có dual control
  ❌ Medical data không encrypt
  ❌ UW authority limit bypass

Must verify before approve:
  ✅ Premium calculation khớp rating manual (spot check)
  ✅ Fraud scoring chạy tự động trên mọi claim
  ✅ Reserve movement có full audit trail
  ✅ Cục GS BH report format verified vs official template
```
