# Playbook: Audit Existing Procurement Systems

> **Type**: Agent Skill Playbook
> **Agent**: procurement-expert
> **Triggered by**: /wf-legacy-scan khi có procurement system cũ
> **Output**: `.mc-data/docs/phase1-business/procurement-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống Procurement / Purchasing
- Khi cần đánh giá current state trước khi redesign
- Khi cần tìm gaps, technical debt, migration risks

---

## Procedure

### Bước 1: Inventory công cụ và hệ thống hiện tại

```
Thu thập từ stakeholders hoặc codebase:

□ Procurement tools đang dùng:
   - ERP module (SAP MM / Oracle Procurement / Microsoft Dynamics?)
   - Standalone P2P tool (Coupa / Ariba / Jaggaer / Ivalua?)
   - Homegrown system?
   - Spreadsheets (Excel) cho phần nào?

□ Vendor management: Có vendor master database không? Ở đâu?
□ Contract management: Có contract repository không? Paper hay digital?
□ Spend data: Có spend reporting không? Source data từ đâu?
□ Approval routing: Manual email / workflow tool / ERP workflow?
□ Invoice processing: Manual / AP automation tool?
□ Integrations hiện có: Procurement kết nối với Finance, Inventory system nào?
```

### Bước 2: Vendor Master Data Quality Assessment

```
READ: processes.md → Vendor Onboarding (Process 3)
READ: controls.md → Vendor Onboarding Controls

Đánh giá chất lượng vendor master data:

□ Tổng số vendors trong hệ thống: _____
□ Số vendors có đủ thông tin (contact, bank, tax code): _____%
□ Số vendors ACTIVE vs INACTIVE (đã từng dùng): _____%
□ Duplicate vendors: Cùng công ty nhưng nhiều records?
   → Sample check: Tìm vendors có tên giống nhau
□ Vendor categorization: Có phân loại category không? Đầy đủ không?
□ Documents on file: Business cert, tax cert, bank letter đang lưu ở đâu?
□ Last verified: Khi nào verify lần cuối thông tin vendor?

Phát hiện rủi ro:
□ Vendors không có Tax ID → compliance risk
□ Vendors không có bank verification → fraud risk
□ Vendors không được verify trong >2 năm → stale data risk
□ Shell company risk: Vendor address trùng với nhân viên?
```

### Bước 3: Spend Analysis (by Category, Supplier, Department)

```
READ: processes.md → KPIs section

Thu thập spend data ít nhất 12 tháng gần nhất:

Phân tích theo Category:
□ Top 10 spend categories (theo giá trị)
□ Số suppliers per category (concentration risk)
□ % spend có contract vs. spot buy
□ % spend qua đúng quy trình vs. maverick spend

Phân tích theo Supplier:
□ Top 20 suppliers (% of total spend)
□ Single-source suppliers: Có bao nhiêu? Spend value?
□ Supplier chưa được đánh giá performance: Bao nhiêu %?
□ Suppliers có score thấp nhưng vẫn nhận PO: Bao nhiêu?

Phân tích theo Department:
□ Top departments spend
□ Departments có maverick spend cao nhất
□ PR-to-PO cycle time theo department
□ Departments thường xuyên dùng emergency procurement

Output format:
| Dimension | Current State | Benchmark | Gap | Priority |
|-----------|---------------|-----------|-----|----------|
| Contract coverage | ____% | >80% | ____% | High/Med/Low |
| Maverick spend | ____% | <5% | ____% | ... |
| Vendor on-time delivery | ____% | >95% | ____% | ... |
| PR-to-PO cycle time | ____ days | <3 days | ____ | ... |
```

### Bước 4: Contract Coverage Rate Assessment

```
READ: controls.md → Section 5 Vendor Performance Scorecard

Contract inventory:
□ Tổng số contracts đang active: _____
□ % spend under contract vs. total spend: _____%
□ Contracts hết hạn trong 3 tháng tới: _____ (high risk)
□ Contracts hết hạn trong 6 tháng tới: _____
□ Auto-renewal contracts không có review: Bao nhiêu?
□ Contracts không có clear SLA/KPI: Bao nhiêu?
□ Contracts chỉ có paper (chưa digitized): Bao nhiêu?

Contract management gaps:
□ Có renewal alert system không?
□ Có spend-vs-commitment tracking không? (actual spend vs. contract volume)
□ Có contract version control không?
□ Ai đang quản lý contracts? Có owner assigned không?
```

### Bước 5: Maverick Spend Analysis

```
Maverick spend = mua hàng ngoài quy trình (không có PR, không đúng vendor)

Cách đo:
1. Credit card / petty cash expenses có liên quan đến procurement
2. Invoices nhận được không có PO match
3. PO được tạo sau khi hàng đã nhận (retroactive PO)

Phân tích:
□ % maverick spend / total spend: _____%  (target < 5%)
□ Top departments có maverick spend: _____
□ Top categories bị maverick: _____
□ Giá trị trung bình maverick transaction: _____
□ Lý do phổ biến: Urgency / Không biết quy trình / Quy trình quá chậm?

Root cause analysis:
- Quy trình quá phức tạp → đơn giản hóa PR wizard
- Approval quá chậm → rút ngắn SLA, mobile approval
- Catalog thiếu items thường dùng → mở rộng catalog
- Thiếu awareness → training + policy enforcement
```

### Bước 6: Process Compliance Gaps

```
READ: controls.md → Segregation of Duties Matrix + Three-Way Matching

Compliance check hiện tại:

SoD (Segregation of Duties):
□ Requester có approve PR của chính mình không? → SoD violation
□ Procurement có tạo GRN không? → SoD violation
□ Finance/AP có approve PO không? → SoD violation
□ Có system-enforced SoD hay chỉ rely on manual process?

Approval workflow:
□ Có bypass approval không? (PO được tạo mà không qua approval)
□ Approval trail đầy đủ không? (ai approve, khi nào, trên thiết bị nào)
□ Email approval có được lưu vào hệ thống không?
□ Retroactive approval có bị control không?

3-Way Matching:
□ Hệ thống hiện tại có 3-way matching tự động không?
□ Nếu không: Invoice match với PO được làm thủ công → rủi ro fraud
□ Tolerance thresholds có được define và enforce không?

Anti-bribery / Ethical:
□ Có conflict of interest declaration process không?
□ Có gift/entertainment register không?
□ Có phải report quà tặng từ vendors không?
```

### Bước 7: Integration Health Assessment

```
Kiểm tra integration hiện tại:

Finance / AP integration:
□ Budget check real-time hay batch (end of day)?
□ Khi PO tạo → budget bị reserve ngay không? Hay chỉ khi PO approved?
□ 3-way matching → có tự động trigger payment không?
□ Exchange rate cho PO ngoại tệ: Lấy rate lúc nào? Có reconciliation không?

Inventory / Warehouse integration:
□ GRN có tự động update inventory không?
□ Reorder point có tự động tạo PR không?
□ Có sync item master giữa inventory và procurement không?

Vendor Portal / EDI:
□ Vendors có thể nhận PO điện tử không?
□ Vendors có thể submit invoice điện tử không?
□ EDI setup với vendors nào? Tỷ lệ PO qua EDI?

Data quality issues:
□ Duplicate PO numbers (nếu nhiều hệ thống)?
□ Vendor codes không sync giữa procurement và AP?
□ Item codes khác nhau giữa procurement và inventory?
```

### Bước 8: Migration Risks

```
Open POs tại thời điểm migration:
□ Số PO đang mở (Sent, Acknowledged, Partially Received): _____
□ Giá trị tổng open POs: _____
□ PO cũ nhất: _____ (nếu > 1 năm → likely obsolete, cần review)
□ PO với partial GRN: Cần migrate GRN balance

Vendor contracts migration:
□ Số contracts cần digitize từ paper: _____
□ Contracts với auto-renewal cần set alert: _____
□ Contracts có pricing tables (tiered pricing): Format phức tạp

Historical data migration:
□ Cần migrate mấy năm historical PO data? (compliance requirement)
□ Vendor master: Có cần clean up duplicates trước migrate không?
□ Spend data: Format hiện tại có thể extract không? (Excel, ERP export)

Technical risks:
□ Customizations trong ERP hiện tại: Có logic phức tạp nào?
□ Integration dependencies: Migrate procurement → impact gì cho Finance/Inventory?
□ User training: Số users cần train, timeline?
□ Parallel run period: Cần chạy song song bao lâu?
```

### Bước 9: Output — Procurement As-Is Analysis Report

```markdown
# Procurement As-Is Analysis

## Executive Summary
[3-5 dòng: overall maturity, biggest strengths, critical gaps]

## Current Tool Inventory
| Tool/System | Purpose | Status | Issues |
|-------------|---------|--------|--------|

## Vendor Master Data Quality
[Findings + quantified gaps]

## Spend Analysis
| Dimension | Current | Target | Gap |
|-----------|---------|--------|-----|
| Contract coverage | | >80% | |
| Maverick spend | | <5% | |
| Vendor on-time delivery | | >95% | |
| PR-to-PO cycle time | | <3 days | |

## Compliance Gaps
### Critical (Phải fix trước go-live)
- [Gap + impact + recommendation]

### Important (Fix trong sprint đầu)
- [Gap + impact + recommendation]

## Process Bottlenecks
[Top 3 bottlenecks ảnh hưởng đến PR-to-PO speed]

## Integration Issues
[Table: Integration | Status | Data quality | Fix required]

## Migration Risks & Mitigation
| Risk | Severity | Mitigation |
|------|---------|-----------|

## Recommended Migration Approach
[Phased migration plan, parallel run period, cutover criteria]

## Quick Wins (< 1 tháng)
1. [Highest impact, easiest fix]
2. ...
```

---

## Checklist trước khi submit

```
□ Vendor master data quality đã được quantify (số % đầy đủ)
□ Maverick spend % đã tính (nếu data available)
□ Contract coverage rate đã tính
□ SoD violations đã được identify (nếu có)
□ Open PO count tại thời điểm audit đã ghi rõ
□ Migration risks đã list đủ (open POs, contracts, historical data)
□ Recommendations có priority order (Critical / Important / Nice-to-have)
□ Quick wins đã identify (giúp project team thấy value sớm)
```
