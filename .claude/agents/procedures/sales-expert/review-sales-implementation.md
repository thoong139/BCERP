# Playbook: Review Sales Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: sales-expert
> **Triggered by**: /wf-implement-feature khi review sales/CRM module code
> **Output**: Sales implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của sales modules
- Khi cần validate business logic từ domain perspective
- Khi cần check commission calculations và pipeline rules trước go-live

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type:
□ Pipeline Management → check stage transitions, territory access, stale alerts
□ Commission System → check calculation accuracy, clawback logic, audit trail
□ Quotation → check approval workflow, discount thresholds, versioning
□ Forecasting → check calculation methods, roll-up logic, accuracy tracking
□ Order Management → check order-to-cash flow, inventory check
□ Sales Analytics → check metric definitions, data freshness
```

### Bước 2: Load controls knowledge

```
READ: controls.md → Luôn làm, bất kể module nào

Compliance checklist áp dụng cho mọi sales module:
□ Territory access: Rep chỉ xem data trong territory của mình?
□ Audit trail: Mọi thay đổi pipeline/commission đều được log?
□ Approval gates: Discount/commission không thể bypass workflow?
□ Data separation: Một rep không xem commission/quota của rep khác?
□ PII handling: Customer data được bảo vệ đúng cách?
```

### Bước 3: Review theo module type

**Pipeline Management:**
```
□ Stage transitions: Chỉ cho phép forward/backward theo logic đã define?
□ Stage entry criteria enforcement: Có validate required fields không?
□ Territory filter: Query có đang lọc đúng theo territory không?
□ Stale deal detection: Cron job/trigger có fire đúng threshold không?
□ Win/Loss: Có capture reason bắt buộc khi close deal không?
□ Probability tự động theo stage hay rep có thể override?
□ Audit trail: Mọi stage change có log user + timestamp + lý do không?
□ Pipeline velocity: Công thức tính đúng không? (Deals × Win Rate × Avg Value / Cycle)
```

**Commission System:**
```
□ Calculation accuracy: Test với số liệu thực tế:
  → Flat rate: Deal 100M × 5% = 5M? ✓
  → Tiered: Tính lũy kế hay simple rate đổi?
  → Accelerator: Rate đổi tại đúng threshold không?
□ Quota attainment %: (Achieved / Quota) × 100 — đúng period không?
□ Clawback trigger: Có fire khi deal reverse/cancel trong lockout period không?
□ SPIF stacking: SPIF có được cộng thêm vào base commission đúng không?
□ Dispute workflow: State machine đúng không? (Pending → Review → Resolved)
□ Audit log: Commission record không thể edit sau khi confirmed?
□ Rounding: Làm tròn theo chuẩn kế toán (2 decimal, bank rounding)?
□ Export file: Format khớp với payroll system template không?
```

**Quotation:**
```
□ Approval threshold: Discount > X% → route đúng approver không?
□ Version control: Khi tạo version mới, version cũ có bị lock không?
□ Pricing accuracy: Unit price × quantity × (1 - discount%) đúng không?
□ Tax calculation: Thuế (VAT/GST) tính đúng theo loại sản phẩm/địa lý không?
□ Quote expiry: Hết hạn có auto-expire status không?
□ PDF generation: Số liệu trên PDF có khớp với database không?
□ Inventory check: Có real-time check stock khi quote không?
```

**Forecasting:**
```
READ: pipeline-analytics.md → Forecasting calculation

□ Weighted forecast: Σ(Amount × Stage Probability) — đúng deals trong period?
□ Commit forecast: Chỉ tính deals được rep flag "commit" không?
□ Roll-up: Manager forecast = sum of team? Hay có manager adjustment?
□ Period filter: Deals close trong quarter này, không bao gồm quarter khác?
□ Currency handling: Multi-currency có convert đúng về base currency không?
□ Historical accuracy tracking: Predicted vs actual có được persist không?
□ Real-time update: Khi deal thay đổi, forecast có tự update không?
```

### Bước 4: Performance Check

```
□ Pipeline list: Có pagination không? Load 1000+ deals không bị chậm?
□ Commission calculation: Batch job hay real-time? Có timeout risk không?
□ Territory query: Có index trên territory_id + rep_id không?
□ Forecast aggregation: Có cache không? Hay query raw mỗi lần?
□ Activity feed: Có lazy load / infinite scroll không?
□ Export: Lớn file (> 10k rows) có stream hay load vào memory hết không?
□ External API (CRM sync, email, calendar): Có retry logic + circuit breaker?
```

### Bước 5: Access Control Verification

```
□ Rep A không xem được opportunity của Rep B (khác territory)
□ Rep không xem commission của rep khác
□ Manager xem toàn bộ team nhưng không xem ngoài team
□ Admin role có xem tất cả + audit trail access
□ Commission dispute chỉ submitter + reviewer + manager xem được
□ Closed-won deal: Rep không thể edit amount sau close (chỉ admin)
□ API endpoints: Có enforce authorization check, không chỉ authentication?
```

### Bước 6: Integration Verification

```
Marketing → Sales:
□ Lead handoff: MQL từ marketing có create lead trong CRM đúng không?
□ UTM/source data có được preserve khi lead convert thành opportunity?

Sales → Finance:
□ Closed-won deal có trigger invoice creation không?
□ Deal amount = Invoice amount (không discrepancy)?
□ Commission export có mapping đúng GL account không?

Sales → HR/Payroll:
□ Commission payout file có đúng format payroll yêu cầu không?
□ Employee ID mapping giữa CRM và HR system đúng không?
```

### Bước 7: Output — Review Report

```markdown
# Sales Implementation Review: [Module Name]

## Overall Status: ✅ PASS / ❌ FAIL / ⚠️ NEEDS ATTENTION

## Critical Issues (block go-live)
- [ ] [Issue]: [Location in code] → [Required fix]

## Important Issues (fix before next sprint)
- [ ] [Issue]: [Location] → [Recommendation]

## Suggestions (nice-to-have improvements)
- [ ] [Suggestion]

## Business Logic Verification
[Table: Rule | Expected | Actual | Status]

## Access Control Results
[Table: Scenario | Expected | Actual | Status]

## Performance Results
[Table: Operation | Expected | Actual | Status]

## Commission Calculation Test Cases
[Table: Test case | Input | Expected output | Actual | Pass/Fail]

## Integration Verification
[Table: Integration point | Status | Notes]

## Sign-off
□ Pipeline business logic: OK / ISSUE
□ Commission calculations accurate: OK / ISSUE
□ Territory access control: OK / ISSUE
□ Audit trail complete: OK / ISSUE
□ Integration với Finance: OK / ISSUE
□ Performance requirements met: OK / ISSUE
```

---

## Checklist trước khi submit

```
□ Commission calculation đã test với ít nhất 3 test cases (flat/tiered/accelerator)
□ Territory access đã verify (rep A không xem được data rep B)
□ Audit trail đã confirm immutable (không thể edit sau confirm)
□ Approval workflow đã test với deal vượt discount threshold
□ Integration với Finance đã verify (closed-won → invoice)
□ Performance test với realistic data volume
□ Export file đã validate format với payroll system
```
