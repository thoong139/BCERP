# Playbook: Review Procurement Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: procurement-expert
> **Triggered by**: Post-implementation review — sau khi code procurement module đã được implement
> **Output**: Procurement implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của procurement module
- Khi cần validate implementation từ procurement domain perspective
- Khi cần check business logic correctness: approval routing, 3-way matching, SoD

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type và load context:

□ Vendor Management → check onboarding workflow, AVL logic, scorecard calculation
□ Purchase Requisition → check approval routing, budget check, SoD
□ RFQ / Quotation → check vendor selection, three-quotes rule, comparison matrix
□ Purchase Order → check PO state machine, sending mechanism, change order
□ Goods Receipt → check SoD enforcement, GRN linkage
□ Invoice / 3-way Matching → check tolerance logic, auto-approve/hold rules
□ Spend Reporting → check data accuracy, category rollup
□ Vendor Portal → check access control, tenant isolation

Đọc requirements liên quan:
□ Lấy REQ-IDs từ feature spec (ví dụ: REQ-PROC-PO-001, REQ-PROC-VND-001)
□ Đọc implementation task file tại .mc-data/docs/phase5-implementation/tasks/
□ Nắm rõ acceptance criteria của từng REQ
```

### Bước 2: Load controls knowledge

```
READ: controls.md → Luôn làm, bất kể module nào

Compliance checklist áp dụng cho mọi procurement module:
□ Approval threshold: Thresholds có đúng với định nghĩa không?
□ SoD: Có enforce Segregation of Duties bằng code không (role-check)?
□ Audit trail: Mọi state transition có log timestamp + actor + reason không?
□ Vendor validation: PO chỉ tạo được với Active/Preferred/Approved vendors?
□ Budget check: Có reserve budget khi PO approved không?
□ Anti-bribery: Conflict of interest declaration có được check không?
```

### Bước 3: Review theo module type

**Vendor Management:**
```
READ: controls.md → Vendor Onboarding Controls + Vendor Performance Scorecard

□ Onboarding state machine: Draft→Submitted→Under Review→Financial Check→Active
   → Không thể skip Financial Check step
□ Document completeness: Có validate required documents trước khi submit không?
□ Sanctions screening: Có trigger screening khi onboard không?
□ AVL enforcement: PO creation có check vendor status (block Suspended/Blacklisted)?
□ Scorecard calculation: Formula đúng không?
   OTD weight 30% + Quality 25% + Price 20% + Service 15% + Compliance 10% = 100%
□ Score bands: 85+ Preferred / 70-84 Approved / 55-69 Probation / <55 At Risk
□ Vendor Portal isolation: Vendor A không đọc được data của Vendor B
□ CoI declaration: Có expiry check? Hệ thống có alert khi quá hạn không?
□ Blacklist: Có prevent override? Có ghi lý do không?
```

**Purchase Requisition:**
```
READ: controls.md → Authorization Matrix + Approval Limits Detail

□ Approval routing logic:
   - Amount-based threshold đúng không? (so với controls.md)
   - Category-based routing có được apply thêm không?
   - Escalation khi approver không respond trong SLA?
   - Delegate mechanism có time-bound không?
□ Budget check timing: Check khi submit PR (không phải khi PO tạo)
□ SoD: Requester không thể approve PR của chính mình (role-based + user-based check)
□ Emergency PR: Có retroactive approval flow riêng không?
□ Sole-source PR: Có require additional justification + approvers không?
□ Split-order detection: Có detect khi user tạo nhiều PRs nhỏ cho cùng mục đích?
□ PR recall: Chỉ recall được khi chưa có ai approve (không thể recall mid-approval)
```

**RFQ / Quotation Process:**
```
READ: processes.md → RFQ Process + Approval Matrix

□ Three-quotes rule enforcement: Có cho phép tạo PO nếu < 3 quotes không?
   → Nếu < 3 vendors respond → cần force extension hoặc single-source waiver
□ RFQ deadline: Sau deadline có close submissions tự động không?
□ Quote comparison matrix: Weighted score tính đúng không?
   Kiểm tra formula: (price_score × 0.4) + (leadtime_score × 0.25) + ...
□ Vendor selection audit: Nếu chọn không phải lowest score → có capture reason không?
□ Quote confidentiality: Vendor A không xem được quote của Vendor B
□ RFQ amendment: Nếu sửa RFQ sau khi gửi → có notify vendors không?
```

**Purchase Order:**
```
READ: controls.md → Authorization Matrix (PO thresholds) + Three-Way Matching

□ PO state machine integrity:
   - Không thể Sent nếu chưa qua Approved
   - Không thể Cancel nếu đã Fully Received
   - Không thể tạo GRN nếu PO chưa ở Sent/Acknowledged
□ PO sending: PDF generation đúng format? Bao gồm: PO number, vendor, items, terms
□ PO Acknowledgment timeout: Alert buyer nếu vendor không confirm trong 2 ngày
□ Change Order:
   - CO không thể tạo sau Fully Received state
   - CO tăng giá trị: Có trigger re-approval không?
   - CO version history: Có lưu đầy đủ không?
□ Budget reservation: Khi PO approved → budget reserved (không available cho PR khác)
□ PO closure: Auto-close khi 3-way matched? Partial received sau 30 ngày → alert?
```

**Goods Receipt Note:**
```
READ: controls.md → Segregation of Duties Matrix

□ SoD enforcement (critical):
   - GRN creator ≠ PO creator (enforce by code, không chỉ policy)
   - Warehouse role không thể tạo PO
   - GRN không tạo được nếu PO status không phải Sent/Acknowledged
□ Partial receipt: Có track cumulative received quantity không?
□ Quality inspection: Nếu có inspection step → GRN không Approved trước khi QC pass
□ Discrepancy: Damage/shortage có được capture và notify Procurement không?
□ GRN immutability: GRN đã submit không được edit (phải tạo correction GRN)
```

**Invoice & 3-Way Matching:**
```
READ: controls.md → Three-Way Matching Process + Tolerance Matrix

□ Matching logic:
   PO qty ≈ GRN qty ≈ Invoice qty (trong tolerance)
   PO price = Invoice price (trong tolerance)
□ Tolerance enforcement (check từng band):
   ≤ 2% qty variance → auto-approve
   ≤ 1% price variance → auto-approve
   2–5% qty / 1–5% price → hold, Finance review
   > 5% → full investigation; hold payment
□ Invoice without PO: Hard reject (không thể match, gửi lại vendor)
□ Duplicate invoice detection: Cùng vendor + cùng invoice number → block
□ Currency: Nếu PO ngoại tệ → có rate conversion tại thời điểm PO approved không?
□ Credit note handling: Có handle vendor credit note không?
□ Payment trigger: Sau khi 3-way matched → automatic trigger AP payment không?
```

### Bước 4: Anti-Bribery Controls Check

```
READ: controls.md → Vendor Onboarding Controls (CoI section)

□ Conflict of Interest declaration:
   - Vendor phải declare CoI khi onboard
   - Procurement staff phải declare CoI với vendors mình quản lý
   - Annual renewal: System nhắc trước 30 ngày hết hạn
   - Expired CoI: System alert nhưng không block (để human judgment)
□ Gift register:
   - Nếu có gift register feature: Entry có capture date, giver, estimated value không?
   - Report "gifts received from vendors" có không?
□ Vendor selection audit trail:
   - Khi chọn vendor không phải lowest quote → reason logged
   - Report "POs to vendors with active CoI declarations" có không?
□ Sole-source audit:
   - Mỗi sole-source PO có waiver document attached không?
   - Count sole-source per buyer per quarter → anomaly detection?
```

### Bước 5: Spend Visibility và Reporting

```
READ: processes.md → KPIs section

□ Spend dashboard:
   - By category: Đúng không? Category rollup logic?
   - By supplier: Concentration calculation đúng không?
   - By department: Cost center allocation đúng không?
□ Maverick spend detection:
   - Logic detect maverick: Invoice without PO / Retroactive PO?
   - Report "maverick spend by department" có không?
□ Contract compliance:
   - % spend under contract có tính đúng không?
   - Alert khi spend vượt contract volume commitment?
□ KPI accuracy:
   - PR-to-PO cycle time: Tính từ PR created đến PO sent (không phải PO created)
   - Vendor OTD: Tính từ GRN date vs PO requested delivery date
   - Savings: Có track (budget estimate - actual cost) không?
```

### Bước 6: Performance Check

```
□ Large RFQ với nhiều vendors: RFQ gửi 50+ vendors có queue/async không?
□ Scorecard recalculation: Khi trigger toàn bộ vendors → có batch job không?
□ Spend report với 12 tháng data: Query có indexed trên created_date không?
□ PO PDF generation: Có cache không? Regenerate mỗi lần download là quá chậm
□ Vendor portal: Session isolation đúng không? Concurrent users?
□ 3-way matching batch: Processing time cho 10,000 invoices?
□ Notification emails: Bulk approval reminders có rate-limited không?
□ Budget check: Real-time check có gây lock contention không?
   → Consider optimistic locking hoặc reservation pattern
```

### Bước 7: Output — Review Report

```markdown
# Procurement Implementation Review: [Module Name]

## Compliance Status: PASS / FAIL / NEEDS ATTENTION

## Critical Issues (block go-live)
- [ ] [Issue]: [Location in code / feature] → [Required fix]
- Ví dụ: SoD không được enforce bằng code — Requester có thể approve PR của mình

## Important Issues (fix trước sprint tiếp)
- [ ] [Issue]: [Location] → [Recommendation]
- Ví dụ: Tolerance matrix hard-coded thay vì configurable

## Suggestions (nice-to-have)
- [ ] [Suggestion]
- Ví dụ: Gift register report chưa có filter by vendor

## Compliance Checklist
| Item | Status | Notes |
|------|--------|-------|
| Approval threshold logic | OK / ISSUE | |
| SoD enforcement (code-level) | OK / ISSUE | |
| Audit trail completeness | OK / ISSUE | |
| 3-way matching tolerance | OK / ISSUE | |
| Vendor portal isolation | OK / ISSUE | |
| Anti-bribery controls | OK / ISSUE | |
| Budget reservation timing | OK / ISSUE | |
| Sanctions screening | OK / ISSUE | |

## Business Logic Verification
| REQ-ID | Requirement | Implemented | Notes |
|--------|-------------|-------------|-------|
| REQ-PROC-PO-001 | PO approval routing | Yes/No/Partial | |
| REQ-PROC-VND-004 | Vendor scorecard auto-calc | Yes/No/Partial | |
| ... | | | |

## Performance Concerns
[List any performance issues found]

## Sign-off
□ Approval routing correctness: OK / ISSUE
□ SoD enforcement: OK / ISSUE
□ 3-way matching logic: OK / ISSUE
□ Anti-bribery controls: OK / ISSUE
□ Vendor access controls (portal isolation): OK / ISSUE
□ Spend reporting accuracy: OK / ISSUE
□ Audit trail completeness: OK / ISSUE
□ PO state machine integrity: OK / ISSUE
```

---

## Checklist trước khi submit

```
□ Đã review đúng module type (load đúng checklist)
□ Approval thresholds verified against controls.md
□ SoD enforcement checked at code level (không chỉ UI level)
□ 3-way matching tolerance matrix verified
□ Vendor portal tenant isolation verified
□ All REQ-IDs từ feature spec đã được check
□ Performance concerns đã được note (không để silent)
□ Critical issues clearly separated from suggestions
```
