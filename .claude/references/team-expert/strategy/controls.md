# Strategy Governance Controls

> Reference file cho strategy-expert agent
> Load file này khi cần define delegation of authority, information classification, approval workflows

---

## 1. Delegation of Authority (DoA) Matrix

### Decision Authority by Level

| Quyết định | HĐQT | CEO | C-Suite | BU Head | Manager |
|------------|:----:|:---:|:-------:|:-------:|:-------:|
| Phê duyệt chiến lược 3-5 năm | ✅ | Propose | Input | Input | — |
| Phê duyệt kế hoạch năm | ✅ | Propose | Submit | Input | — |
| M&A > 20% assets hoặc > VND 100B | ✅ | Recommend | Input | — | — |
| M&A ≤ 20% assets và ≤ VND 100B | Inform | ✅ | Input | — | — |
| CAPEX > VND 50B | ✅ | Recommend | Submit | — | — |
| CAPEX VND 10B - 50B | — | ✅ | Recommend | Submit | — |
| CAPEX < VND 10B | — | — | ✅ (CFO) | Recommend | Submit |
| Bổ nhiệm CEO | ✅ | — | — | — | — |
| Bổ nhiệm C-Suite | ✅ | Recommend | — | — | — |
| Bổ nhiệm BU Head | — | ✅ | Recommend | — | — |
| Thay đổi cơ cấu tổ chức BU | — | ✅ | Recommend | Submit | — |
| Ký kết hợp đồng chiến lược > VND 50B | — | ✅ | — | — | — |
| Ký kết hợp đồng > VND 5B | — | — | ✅ (theo chức năng) | Recommend | — |
| Phê duyệt OKR Company | ✅ (endorse) | ✅ (set) | Propose | Input | — |
| Phê duyệt OKR BU | — | ✅ | Align | ✅ (propose) | — |
| Phê duyệt dividends | ✅ | Recommend | Input | — | — |

### Approval Thresholds — CAPEX

| Mức CAPEX | Approver 1 | Approver 2 | Timeline |
|-----------|-----------|-----------|----------|
| < VND 1B | BU Head | — | 3 ngày |
| VND 1B - 10B | BU Head | CFO | 5 ngày |
| VND 10B - 50B | CFO | CEO | 7 ngày |
| VND 50B - 200B | CEO | HĐQT | 15 ngày |
| > VND 200B | HĐQT | Đại hội cổ đông (nếu > 35% tài sản) | 30+ ngày |

---

## 2. Information Classification

### Phân cấp Bảo mật

| Cấp độ | Tên | Ai được truy cập | Ví dụ tài liệu |
|--------|-----|------------------|----------------|
| 4 | **Board Confidential** | HĐQT members only | M&A targets, CEO remuneration details, board deliberations, regulatory disputes |
| 3 | **C-Suite Confidential** | C-suite + authorized advisors | Competitive intelligence, M&A process docs, restructuring plans, undisclosed financials |
| 2 | **Management Restricted** | BU Heads + Function Heads | BU performance vs peers, budget details, HR individual data, strategic draft docs |
| 1 | **Company Internal** | All employees | Approved strategy docs, company KPI dashboards (aggregated), approved budgets |
| 0 | **Public** | External | Annual report, press releases, investor presentations |

### Information Handling Rules

| Cấp độ | Lưu trữ | Chia sẻ | In ấn | Xóa |
|--------|---------|---------|-------|-----|
| Board Confidential | Encrypted board portal only | Không forward email, không print | Board approval required | Auto-expire sau 90 ngày nếu không gia hạn |
| C-Suite Confidential | Encrypted drive, need-to-know | Internal only, no external without NDA | Limited, watermarked | CFO/CEO approval |
| Management Restricted | Company intranet, RBAC | Manager approval | OK with watermark | Line manager approval |
| Company Internal | Intranet, shared drives | All employees | OK | Standard policy |

---

## 3. Strategy Document Approval Workflow

### Annual Strategy Plan

```
Step 1: Strategy Manager drafts → inputs from BU Heads + market analysis
Step 2: C-suite review workshop (2-3 ngày, off-site)
Step 3: CEO finalizes và presents to HĐQT
Step 4: HĐQT thảo luận → phê duyệt hoặc yêu cầu revision
Step 5: Approved plan → cascaded xuống organization
Step 6: BU OKRs được set theo Approved plan
```

### Annual Budget

```
Step 1: CFO phát template → BU Heads submit BU budgets
Step 2: CFO consolidates → variance review
Step 3: CEO reviews consolidated budget → alignment meeting
Step 4: CEO submits to HĐQT
Step 5: HĐQT approves
Step 6: System activates budget controls
```

### OKR Cascade

```
CEO & C-suite: Set Company OKRs → HĐQT endorse
  → BU Head: Propose BU OKRs aligned with Company OKRs → CEO approve
    → Dept Head: Propose Dept OKRs aligned with BU OKRs → BU Head approve
      → Individual: Propose Individual OKRs → Manager approve
```

### Board Resolution Process

```
1. Motion tabled in meeting agenda (T-10 ngày)
2. Pre-meeting: Members review supporting documents
3. Meeting: Discussion → Motion called to vote
4. Quorum check (per charter: typically >50% members)
5. Vote: Simple majority (or supermajority for major decisions)
6. Minutes recorded: who voted what, reasons
7. Resolution signed by Chairman
8. Execution by management
```

---

## 4. M&A Information Control Protocols

### Deal Team Authorization

```
Deal code (nom de guerre) assigned by CEO at deal initiation.
Deal team (need-to-know basis):
  - CEO (always)
  - CFO (always)
  - Strategy Lead
  - Legal Counsel (internal + external)
  - M&A Advisor / Investment Bank (NDA required)

Expansion of deal team requires CEO approval.
Board informed only at Stage 4 (Valuation) or earlier if regulatory required.
```

### Clean Room Procedures

```
Situation: Competitive data sharing during DD
Protocol:
  - Separate VDR folder for sensitive competitive data
  - Clean room team: separate from operations team
  - No competitive intelligence flows back to operations
  - Clean room supervisor approves data access requests
```

### Insider Trading Controls

| Event | Control |
|-------|---------|
| Deal team member awareness | Blackout period activated (no trading company shares) |
| Board notification | All board members enter blackout |
| Public announcement | Blackout lifted 24h post-announcement |
| Deal failure / abandonment | CEO certifies no material information remains |

---

## 5. Executive Dashboard Access Controls

### Role-Based Data Filtering

| Role | Company Data | All BU Data | Own BU Only | M&A Data | Remuneration Data |
|------|:------------:|:-----------:|:-----------:|:--------:|:-----------------:|
| CEO | ✅ | ✅ | ✅ | ✅ (deal role) | ✅ (blinded for peers) |
| CFO | ✅ | ✅ | ✅ | ✅ (deal role) | ✅ (for compensation modeling) |
| Board Director | ✅ (summary) | ✅ (summary) | — | ✅ (Stage 4+) | ✅ (approved in committee) |
| BU Head | ✅ (aggregate) | Benchmarked (blinded) | ✅ (full) | ❌ | ❌ |
| Strategy Manager | ✅ | ✅ (OKR only) | ✅ | ❌ | ❌ |
| Function Head | ✅ (own function) | ❌ | ❌ | ❌ | ❌ |

> **Nguyên tắc**: Filtering xảy ra ở data layer (server-side) — KHÔNG chỉ ẩn UI element.

### Session & Security Controls

| Control | Specification |
|---------|---------------|
| Session timeout | 30 phút inactive |
| Board portal | Encrypted in transit + at rest, remote wipe, no print/download for Level 4 |
| MFA | Bắt buộc cho CEO, CFO, Board members |
| Audit logging | Mọi access, export, action được logged |
| Failed login lockout | 5 lần fail → lockout 30 phút → notify IT |

---

## 6. Audit Trail Requirements

### Events Bắt buộc Log

| Event | Data Capture | Retention |
|-------|-------------|-----------|
| Board document access | User, timestamp, document ID, action (view/download) | 10 năm |
| Resolution voting | Voter, vote, timestamp, rationale | Vĩnh viễn |
| OKR updates | User, timestamp, old value, new value | 7 năm |
| Strategy document approval | Approvers, timestamps, comments | 10 năm |
| DoA approval | Approver, item, amount, decision, timestamp | 10 năm |
| M&A data room access | User, file, timestamp | 10 năm sau deal close |
| Dashboard export | User, data scope, timestamp, format | 5 năm |

### Data Retention (Theo Luật VN)

| Loại tài liệu | Thời gian lưu |
|---------------|---------------|
| Biên bản họp HĐQT / Nghị quyết | 10 năm |
| Tài liệu chiến lược đã phê duyệt | 7 năm |
| Tài liệu M&A (deals completed) | 10 năm sau closing |
| OKR records | 7 năm |
| Board pack documents | 10 năm |
| Executive dashboard exports | 5 năm |

---

## Quick Reference

### DoA Summary

| Threshold | Approver |
|-----------|----------|
| M&A > VND 100B | HĐQT |
| M&A ≤ VND 100B | CEO |
| CAPEX > VND 50B | HĐQT |
| CAPEX VND 10-50B | CEO |
| CAPEX < VND 10B | CFO |
| Strategy Plan | HĐQT |
| Annual Budget | HĐQT |
| OKR Company | CEO + HĐQT endorse |

### Information Classification Quick Check

```
Hỏi: "Nếu thông tin này bị leak ra ngoài, tác hại là gì?"
  → Catastrophic (regulatory, M&A deal break, criminal liability) → Board Confidential
  → Severe (competitive disadvantage, key talent risk) → C-Suite Confidential
  → Moderate (internal morale, budget perception) → Management Restricted
  → Minor (operational disruption) → Company Internal
  → None → Public
```
