# Playbook: Design Commission & Incentive System

> **Type**: Agent Skill Playbook
> **Agent**: sales-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi có incentive/commission module
> **Output**: Feature spec cho commission & incentive module

---

## Khi nào dùng playbook này

- Khi cần spec module "Commission Management" hoặc "Quản lý Hoa hồng Bán hàng"
- Khi cần thiết kế commission plan types, quota, và payout logic
- Khi cần define integration với HR/Payroll

---

## Procedure

### Bước 1: Đọc requirements và xác định scope

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE1_DEPTS, PHASE2

Xác định từ requirements:
□ Commission plan types cần support (flat rate, tiered, accelerator)
□ Quota basis (Revenue, Units, Gross Margin, Mixed)
□ Payment periods (Monthly, Quarterly, Annual)
□ Số lượng commission plans khác nhau (per role, per region)
□ Có manager override commission không?
□ Clawback rules có không?
□ Dispute resolution process là gì?
```

### Bước 2: Thiết kế Commission Plan Types

```
READ: controls.md → Commission rules & thresholds

Plan Type 1 — Flat Rate:
□ Rate cố định (% revenue hoặc fixed amount per deal)
□ Dễ tính, transparent cho rep
□ Ví dụ: 5% trên mọi deal closed-won

Plan Type 2 — Tiered Commission:
□ Rate tăng theo achievement % vs quota
□ Ví dụ:
  0-50% quota  → 3% commission rate
  51-100% quota → 5% commission rate
  101%+ quota  → 7% commission rate
□ Cần logic: tính lũy kế hay chỉ rate mới nhất?
  → Lũy kế (waterfall): mỗi tier tính riêng phần revenue trong tier đó
  → Simple: toàn bộ revenue áp rate của tier đạt được

Plan Type 3 — Accelerator:
□ Base rate thông thường, rate tăng mạnh khi vượt quota
□ Ví dụ: 100-120% quota → 1.5× base rate; 120%+ → 2× base rate
□ Mục tiêu: incentivize overperformance

SPIFs & Bonuses:
□ SPIF (Sales Performance Incentive Fund): bonus thêm cho deal cụ thể
□ Product SPIF: Bonus khi sell specific product/SKU trong kỳ
□ New logo bonus: Bonus cho first-time customer
□ Có thể stack với commission chính không?
```

### Bước 3: Thiết kế Quota Management

```
Quota assignment:
□ Quota by period (monthly / quarterly / annual)
□ Quota by type (Revenue, Units, New Logo, Expansion)
□ Ai assign quota? Manager? Sales Ops? → Approval workflow?
□ Quota adjustment: Có cho phép mid-period adjustment không?
  → Nếu có: cần audit trail lý do điều chỉnh

Quota rollup:
□ Individual rep quota → Team quota → Region quota
□ Manager có quota riêng hay = sum of team?
□ Quota attainment %: Tính real-time hay cuối kỳ?

Ramp period (nhân viên mới):
□ Tháng 1-3: Quota là 50%, 75%, 100% của full quota
□ Commission rate có khác trong ramp không?
```

### Bước 4: Thiết kế Payment & Lockout Logic

```
Payment timing:
□ When does commission "earn"? → Khi deal closed-won, hay khi invoice paid?
□ "Booked" vs "Paid" commission: Có tách biệt không?
□ Partial payment: Commission trả theo tiến độ thanh toán không?

Lockout rules (prevent premature payment):
□ Lockout period: Commission không trả cho đến ngày X sau deal close
□ Customer must not churn within Y days (clawback trigger)
□ Invoice phải được collect trước khi trả commission?

Clawback policy:
□ Nếu customer cancel/churn trong 90 ngày → clawback 100% commission
□ Nếu cancel trong 90-180 ngày → clawback 50%
□ Clawback notification → rep nhận email + in-app alert
□ Clawback có thể appeal không? → Dispute workflow
```

### Bước 5: Thiết kế Dispute Resolution Workflow

```
States: Pending → Under Review → Resolved (Approved/Rejected) → Paid

Dispute process:
□ Rep submit dispute: Chỉ rõ REQ nào bị sai, kèm evidence
□ Sales Ops review: Xem xét trong X ngày làm việc
□ Manager approve/reject: Final decision
□ Payment adjustment: Nếu dispute thắng → adjust payment record
□ Audit trail: Toàn bộ dispute history không được xóa

Notification:
□ Notify rep khi dispute status thay đổi
□ Escalation nếu quá SLA không có response
```

### Bước 6: Integration với Payroll/HR

```
READ: controls.md → Payroll integration rules

Export requirements:
□ Commission statement per rep per period (PDF + CSV)
□ Payroll file format (matching HR system fields)
□ GL coding cho Finance (commission expense by cost center)
□ Tax withholding: Commission có bị withhold thuế khác không?

Sync frequency:
□ Real-time calculation (khi deal close → commission ngay)
□ Batch export vào cuối kỳ cho Payroll processing
□ Cutoff date: Deal close trước ngày nào được tính vào kỳ hiện tại?
```

### Bước 7: Feature Spec Output

```markdown
# Feature Spec: Commission & Incentive System

## Overview
[Mô tả module, scope]

## User Stories
[Theo personas: Sales Rep (xem commission), Sales Ops (calculate), Finance (export)]

## Functional Requirements
REQ-SALES-COMM-001: Commission plan CRUD (flat, tiered, accelerator)
REQ-SALES-COMM-002: Quota assignment và tracking per rep per period
REQ-SALES-COMM-003: Real-time commission calculation khi deal close
REQ-SALES-COMM-004: SPIF và bonus management
REQ-SALES-COMM-005: Clawback tracking và notification
REQ-SALES-COMM-006: Dispute resolution workflow
REQ-SALES-COMM-007: Commission statement export (PDF/CSV)
REQ-SALES-COMM-008: Payroll integration export file
REQ-SALES-COMM-009: Audit trail cho mọi commission changes

## Data Model
[ERD: CommissionPlan, Quota, CommissionEntry, SPIF, Dispute, PayoutRecord]

## Non-functional Requirements
- Commission calculation phải accurate đến 2 decimal places
- Audit trail immutable — không được phép xóa/edit records đã confirm
- Export file theo format payroll system hiện tại của doanh nghiệp
```

---

## Checklist trước khi submit

```
□ Commission plan types đã xác định (flat/tiered/accelerator)
□ Quota basis và assignment workflow đã rõ
□ Payment timing (booked vs paid) đã define
□ Clawback rules đã có (nếu applicable)
□ Dispute resolution workflow đã thiết kế
□ Payroll/HR integration format đã ghi nhận
□ Audit trail requirements đã noted
□ REQ-ID format: REQ-SALES-COMM-[NNN]
```
