# Playbook: Audit Existing Finance Systems

> **Type**: Agent Procedure
> **Agent**: finance-expert
> **Triggered by**: /wf-legacy-scan khi project có hệ thống tài chính hiện có
> **Output**: `.mc-data/docs/phase1-business/finance-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có phần mềm kế toán hoặc ERP Finance
- Khi cần đánh giá tình trạng hệ thống tài chính trước khi thiết kế lại
- Khi cần tìm gaps, data quality issues, và migration risks

---

## Procedure

### Bước 1: Inventory hệ thống tài chính hiện có

```
Cần thu thập từ stakeholders hoặc codebase:

□ Phần mềm đang dùng (MISA, Fast, SAP, Oracle, custom, Excel)
□ Modules đang active: GL / AP / AR / Budget / Tax / Treasury
□ Số năm dữ liệu đã có trong hệ thống
□ Số lượng giao dịch trung bình/tháng
□ Số lượng users đang dùng, phân theo role
□ Integrations hiện tại (ngân hàng, hệ thống ERP khác, thuế)
□ Vấn đề chính đang gặp phải với hệ thống cũ
```

### Bước 2: Đánh giá Data Quality

```
READ: operations.md → Section 6: Operational Metrics (KPIs)

Kiểm tra chất lượng dữ liệu:

Chart of Accounts:
□ Có theo đúng VAS structure (1xx, 2xx, 3xx...)?
□ Có tài khoản orphan (không còn dùng, chưa close)?
□ Có duplicate accounts với mục đích trùng nhau?

Transaction History:
□ Tỷ lệ balanced entries (Debit = Credit)?
□ Có unposted entries tồn đọng không?
□ Có inter-period entries chưa được xử lý?

Vendor/Customer Master:
□ Duplicate vendors/customers?
□ Vendor bank accounts có đủ, chính xác?
□ Customer credit limits có được cập nhật?

Bank Reconciliation:
□ Kỳ cuối reconciliation là khi nào?
□ Còn outstanding items tồn đọng bao lâu?
```

### Bước 3: Đánh giá Compliance Gaps

```
READ: controls.md → Section 6: Compliance Requirements

Gaps phổ biến cần check:

VAS Compliance:
□ Chart of Accounts có đúng Circular 200/2014 không?
□ Báo cáo VAT tháng/quý có đủ format không?
□ Có track FCT cho foreign payments không?

Audit Trail:
□ Hệ thống cũ có ghi lại who/when/what cho mọi transaction?
□ Retention: Dữ liệu có giữ đủ 10 năm theo quy định?
□ Có thể void/reverse entries mà không để lại trace không?

Controls:
□ Có SoD enforcement (creator ≠ approver)?
□ Có period lock sau khi close không?
□ Approval workflow có documented và enforced?
```

### Bước 4: Đánh giá Processes Hiện Tại

```
READ: operations.md → Section 2: Typical Finance Processes

Với mỗi process, phỏng vấn / quan sát:

AP Process:
□ Thời gian xử lý 1 invoice hiện tại (benchmark: 30 min)
□ Tỷ lệ first-pass match (benchmark: >80%)
□ Có OCR/scan hay vẫn nhập tay?

AR Process:
□ DSO (Days Sales Outstanding) hiện tại bao nhiêu ngày?
□ Tỷ lệ dunning automation vs manual?
□ Có customer portal để self-service không?

Month-End Close:
□ Hiện đóng sổ mất bao nhiêu ngày?
□ Checklist close có formalized chưa?
□ Bottlenecks chính trong quá trình close là gì?
```

### Bước 5: Xác định Migration Risks

```
Data Migration Risks:
□ Số lượng records cần migrate (invoices, JEs, customers, vendors)
□ Data format issues (dates, amounts, currencies)
□ Historical data completeness (có thiếu period nào không?)
□ Foreign keys integrity (invoices có matching POs/GRNs không?)

Process Migration Risks:
□ Customizations trong hệ thống cũ cần replicate
□ Reports dùng hàng ngày cần reimplemented
□ Integrations cần reconnect (bank, tax, other systems)

Risk Rating:
| Item | Risk Level | Effort | Mitigation |
|------|------------|--------|------------|
| Data migration | High/Med/Low | High/Med/Low | [Plan] |
```

### Bước 6: Output — Finance As-Is Analysis

```markdown
# Finance System Audit Report

## Executive Summary
[3-5 dòng: tình trạng tổng thể, điểm mạnh, gaps nghiêm trọng]

## Current State

### Systems Inventory
[Table: System | Modules | Status | Issues]

### Process Assessment
[Table: Process | Current Performance | Benchmark | Gap]

## Data Quality Issues

### Critical Issues (block migration)
- [Issue]: [Affected data] → [Fix required before migration]

### Important Issues (fix in parallel)
- [Issue]: [Impact] → [Recommendation]

## Compliance Gaps
[Table: Requirement | Current Status | Gap | Priority]

## Migration Risks
[Table: Risk | Level | Impact | Mitigation]

## Recommendations

### Quick Wins (< 1 tháng)
1. [Action]: [Expected improvement]

### Medium Term (1-3 tháng)
1. [Action]: [Expected improvement]

### Long Term (requires system change)
1. [Action]: [Expected improvement]
```

---

## Checklist trước khi submit

```
□ Tất cả modules hiện tại đã được inventory
□ Data quality issues có severity rating
□ Compliance gaps theo VAS đã check
□ SoD violations (nếu có) đã documented
□ Migration risks có effort estimate
□ Recommendations được prioritize theo impact/effort
□ Open questions cần confirm với Finance team
```
