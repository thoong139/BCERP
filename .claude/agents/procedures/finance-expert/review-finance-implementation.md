# Playbook: Review Finance Module Implementation

> **Type**: Agent Procedure
> **Agent**: finance-expert
> **Triggered by**: /wf-implement-feature khi review code finance module
> **Output**: Finance implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của finance module
- Khi cần validate implementation từ domain accounting perspective
- Khi cần check compliance (VAS, audit trail, SoD, period controls)

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type:
□ General Ledger → check double-entry, period controls, CoA structure
□ Accounts Payable → check 3-way match, approval workflow, duplicate detection
□ Accounts Receivable → check aging, dunning, credit limit enforcement
□ Budget Management → check budget vs actual calculation, pre-commitment check
□ Tax → check VAT calculation, CIT, FCT logic
□ Treasury / Cash → check bank reconciliation, forecasting logic
```

### Bước 2: Load controls knowledge — LUÔN làm

```
READ: controls.md → Luôn load, bất kể module nào

Compliance checklist áp dụng cho mọi finance module:
□ Audit trail: Mọi create/edit/delete/approve đều được log đủ fields
□ SoD: Creator và Approver là 2 người khác nhau (enforced ở DB level)
□ Period lock: Không cho phép post vào closed period
□ Authorization: Approval threshold đúng theo controls.md Section 1
□ Data retention: Financial data có TTL 10 năm
□ Soft delete: Không hard-delete financial records — dùng void + reason
```

### Bước 3: Review theo module type

**General Ledger:**
```
□ Double-entry validation: sum(debit) == sum(credit) BEFORE save — không phải after
□ Unbalanced entry: System PHẢI reject, không phải warn
□ Account type validation: Debit/credit side đúng với normal balance?
□ Period check: entry_date nằm trong open period?
□ JE number: Auto-sequence, không được có gaps
□ Void flow: Tạo reversing entry, không delete gốc
□ Recurring entries: Có idempotency check (tránh duplicate)?
```

**Accounts Payable:**
```
□ 3-way match: Invoice ↔ PO ↔ GRN amount và quantity match
□ Tolerance: Có configurable tolerance threshold không? (±5% standard)
□ Duplicate check: Cùng vendor + invoice_number → block duplicate
□ SoD: Người tạo payment batch ≠ người approve payment
□ Payment scheduling: Có respect payment terms (Net 30, Net 60)?
□ FCT calculation: Nếu foreign vendor — có tính Foreign Contractor Tax?
□ Approval routing: Amount threshold trigger đúng approver level?
```

**Accounts Receivable:**
```
□ Credit limit: Check trước khi confirm sales order, không phải sau
□ Aging buckets: 0-30, 31-60, 61-90, 91-120, >120 days đúng công thức
□ DSO calculation: (Ending AR / Revenue) × Days — có sử dụng không?
□ Dunning sequence: Có respect opt-out và dispute status không?
□ Payment application: FIFO hay specific invoice matching?
□ Credit note: Có approval workflow cho credit note > threshold?
□ Write-off: Có provision calculation logic không (% aging bucket)?
```

**Budget Management:**
```
□ Available budget formula: Planned - Actual - Committed (PO)
□ Actual pull: Lấy từ GL transactions theo đúng period và account
□ Pre-commitment: Check trước khi save PO, không phải sau approve
□ Over-budget handling: Block hay warning — cấu hình được không?
□ Revision history: Mọi revision có audit trail với reason
□ Budget lock: Sau approve, không cho edit trực tiếp — phải revision request
```

### Bước 4: Kiểm tra Calculation Accuracy

```
Các phép tính tài chính cần verify:

Rounding rules:
□ Currency amounts: Round về 0 decimal (VND) hoặc 2 decimal (USD)
□ Percentage calculations: Làm tròn nhất quán (không mất precision giữa steps)
□ Tax calculation: VAT = base × 0.1 — có round trước hay sau khi cộng?

Currency handling:
□ Multi-currency: Có store cả original currency và VND equivalent?
□ Exchange rate: Rate ngày nào? Ai update? Có audit trail rate changes?
□ Realized/Unrealized FX: Có separate tracking không?

VAT logic (nếu applicable):
□ Input VAT: Đúng tài khoản 133 theo VAS
□ Output VAT: Đúng tài khoản 3331 theo VAS
□ VAT report: Bảng kê mua vào/bán ra đúng format Thông tư 78
```

### Bước 5: Kiểm tra Performance & Security

```
Performance:
□ Trial balance query: Có index trên account_code + period?
□ Aging report: Không chạy full-table scan — có partition by period?
□ Budget vs Actual: Có pre-aggregate hay tính real-time? (risk nếu lớn)
□ Month-end reports: Có background job hay block UI?

Security:
□ Financial data: Không expose raw amounts qua API cho non-finance roles
□ Salary data: Tách biệt hoàn toàn, chỉ HR + CFO
□ Bank account info: Masked trong UI (hiển thị ****1234)
□ Export: Có audit log khi export financial data?
```

### Bước 6: Output — Review Report

```markdown
# Finance Implementation Review: [Module Name]

## Compliance Status: ✅ PASS / ❌ FAIL / ⚠️ NEEDS ATTENTION

## Critical Issues (block go-live)
- [ ] [Issue]: [Location in code] → [Required fix]

## Important Issues (fix before next sprint)
- [ ] [Issue]: [Location] → [Recommendation]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

## Compliance Checklist
| Item | Status | Notes |
|------|--------|-------|
| Double-entry validation | OK/FAIL | |
| SoD enforcement | OK/FAIL | |
| Audit trail completeness | OK/FAIL | |
| Period lock | OK/FAIL | |
| Approval thresholds | OK/FAIL | |
| VAS CoA compliance | OK/FAIL | |

## Calculation Accuracy
[Kết quả check rounding, currency, tax]

## Sign-off
□ Accounting logic: OK / ISSUE
□ Compliance (VAS/audit): OK / ISSUE
□ SoD controls: OK / ISSUE
□ Data integrity: OK / ISSUE
□ Access controls: OK / ISSUE
```

---

## Checklist trước khi submit

```
□ controls.md đã được load và áp dụng
□ Double-entry validation đã verify (reject unbalanced, không chỉ warn)
□ SoD enforced ở code level (không chỉ UI)
□ Audit trail đủ fields: user_id, timestamp, old_value, new_value, reason
□ Period lock không cho bypass
□ Calculation accuracy đã test với edge cases (rounding, zero amounts)
□ Không có hard-delete financial records
□ Sensitive data (bank account, salary) được masked/protected
```
