# Playbook: Audit Existing Retail Systems

> **Type**: Agent Skill Playbook
> **Agent**: retail-expert
> **Triggered by**: /wf-legacy-scan khi có retail, POS hoặc store management system cũ
> **Output**: `.mc-data/docs/phase1-business/retail-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống POS / retail quản lý đang vận hành
- Khi cần đánh giá hệ thống retail hiện tại trước khi thiết kế lại
- Khi cần tìm gaps, migration risks và technical debt

---

## Procedure

### Bước 1: Inventory thu thập hệ thống hiện tại

```
Cần thu thập từ stakeholders hoặc codebase:

POS SYSTEM:
□ Tên/phiên bản phần mềm POS đang dùng (tự build hay mua off-the-shelf?)
□ Số terminals đang vận hành (tổng cộng toàn chuỗi)
□ Phiên bản OS trên terminal (Windows, Android, iOS, Linux)
□ Phần mềm POS có cloud hay on-premise?
□ Có module offline mode không? Hoạt động thế nào?

STORE TOOLS:
□ Hệ thống quản lý kho tại cửa hàng
□ Hệ thống chấm công, ca làm việc
□ Hệ thống báo cáo (Excel, BI tool, hay trong POS?)
□ Hệ thống loyalty/CRM (nếu có)

PAYMENT:
□ Payment methods đang support
□ EDC terminal brand/model
□ E-wallet integrations đang có
□ Có split payment không? Hoạt động thế nào?

INTEGRATIONS:
□ Hệ thống nào POS đang kết nối (ERP, ecommerce, accounting)?
□ Integration method (API, file export, manual)
□ Tần suất sync data

HARDWARE:
□ Barcode scanner brand/model
□ Receipt printer brand/model
□ Cash drawer model
□ Tuổi thọ trung bình hardware (bao giờ cần thay?)
```

### Bước 2: Transaction Data Quality Assessment

```
READ: .claude/references/team-expert/retail/operations.md → Section POS Workflow

Yêu cầu truy cập hoặc export dữ liệu giao dịch (sample 3 tháng gần nhất):

TRANSACTION COMPLETENESS:
□ % transactions có đủ trường bắt buộc (item, amount, payment method, cashier)
□ % transactions có customer ID (loyalty member identified)
□ % transactions có shift ID (gắn đúng ca làm việc)
□ Có giao dịch nào amount = 0 bất thường không?
□ Có giao dịch nào thiếu payment record không?

PAYMENT RECONCILIATION:
□ Tổng revenue POS có khớp với bank/payment gateway không?
□ % cash variance (over/short) trung bình mỗi ca
□ Số lần cash variance > 50k VND/tháng
□ Có giao dịch e-wallet chưa reconcile không?

VOID & REFUND PATTERNS:
□ Void rate (% giao dịch bị void) — bình thường < 2%
□ Refund rate — bình thường < 3%
□ Refunds không có authorization: có không?
□ Void sau closing: suspicious pattern?

OFFLINE TRANSACTION HANDLING:
□ Hệ thống có log offline transactions riêng không?
□ Sync rate: % offline transactions sync thành công vs thất bại
□ Có transactions bị mất khi offline không?
□ Thời gian offline trung bình mỗi store mỗi tuần
```

### Bước 3: Inventory Accuracy at Store Level

```
READ: .claude/references/team-expert/retail/operations.md → Section Inventory

□ Inventory model: Perpetual hay periodic?
□ Tần suất stock count (daily, weekly, monthly, quarterly)
□ Inventory accuracy rate: Actual count vs System quantity
   - Mức chấp nhận được: > 95% accuracy
   - < 90%: vấn đề nghiêm trọng

□ Shrinkage rate hiện tại (theft + damage + admin error)
   - Benchmark: 0.5-1.5% for general retail
   - > 2%: cần điều tra

□ Negative inventory: Có SKU nào có quantity < 0 trong system không?
□ Phantom inventory: Hàng hết thực tế nhưng system vẫn báo còn
□ Transfer accuracy: % transfers nhận đúng so với dispatch

□ Hệ thống có alert tồn kho thấp không? Ai nhận alert?
□ Reorder process: Thủ công hay semi-automatic?
□ Thời gian lead time từ order đến nhận hàng tại store
```

### Bước 4: Sales Reporting Gaps

```
READ: .claude/references/team-expert/retail/operations.md → Section KPIs

CURRENT REPORTING CAPABILITIES:
□ Có daily revenue report không? Gửi cho ai? Bằng cách nào?
□ Có multi-store comparison report không?
□ KPIs nào đang được track: doanh thu, ATV, conversion rate, items/transaction?
□ Có real-time dashboard không? Hay chỉ end-of-day report?
□ Tần suất HQ nhận data từ stores: real-time / hourly / daily?

REPORTING GAPS (so sánh với nhu cầu lý tưởng):
□ Conversion rate: Có đang track không? (cần traffic counter nếu không)
□ ATV trend: Có xem được trend theo thời gian không?
□ Store ranking: Có so sánh hiệu suất giữa stores không?
□ Hour-of-day breakdown: Biết giờ cao điểm mỗi store không?
□ Staff performance: Có track doanh số theo cashier không?
□ Promotion effectiveness: Có đo ROI của từng promotion không?

DATA TIMELINESS:
□ Khi CEO hỏi doanh thu hôm nay → mất bao lâu để có số?
□ Khi store có vấn đề → HQ biết sau bao lâu?
```

### Bước 5: Staff Management Process Assessment

```
READ: .claude/references/team-expert/retail/personas.md
READ: .claude/references/team-expert/retail/controls.md → Staff Controls

□ Hệ thống chấm công hiện tại: Thẻ chấm công, vân tay, app, hay sổ tay?
□ Lịch làm việc: Ai lên lịch? Dùng tool gì?
□ Overtime tracking: Có hệ thống không hay tính thủ công?
□ Supervisor override: Có log khi supervisor approve action của cấp dưới không?
□ Permission control: Hệ thống POS có phân quyền rõ ràng không?
□ Shared login: Có tình trạng cashiers dùng chung tài khoản không? (security risk)
□ Khi nhân viên nghỉ việc: Tài khoản có bị deactivate ngay không?
```

### Bước 6: Multi-store Visibility Assessment

```
□ HQ có view được tồn kho real-time của mỗi store không?
□ HQ có view được doanh thu real-time của mỗi store không?
□ Khi giá thay đổi ở HQ → store nhận update sau bao lâu?
□ Khi promotion mới → store áp dụng sau bao lâu?
□ Catalog sync: Sản phẩm mới từ HQ → store thấy sau bao lâu?
□ Có xảy ra tình trạng prices khác nhau giữa stores không?
□ Area Manager có tool nào để xem toàn bộ stores trong khu vực không?
□ Transfer giữa stores: Mất bao lâu và bao nhiêu paperwork?
```

### Bước 7: Payment Reconciliation Process

```
READ: .claude/references/team-expert/retail/controls.md → Cash Management

□ Quy trình reconcile tiền mặt: Thủ công hay có hỗ trợ system?
□ Cash variance được ghi nhận ở đâu? Ai review?
□ Card/e-wallet reconciliation: Đối soát với bank/gateway tần suất nào?
□ Có settlement delay issues không? (tiền về tài khoản trễ)
□ Refund reconciliation: Tiền hoàn có đúng về đúng chỗ không?
□ Khi có chênh lệch: Quy trình investigation mất bao lâu?
□ Loyalty points reconciliation: Points tích có khớp với điểm trong CRM không?
```

### Bước 8: Migration Risks Assessment

```
CRITICAL RISKS CẦN XÁC ĐỊNH:

IN-PROGRESS TRANSACTIONS:
□ Phương án xử lý giao dịch đang open khi cut-over sang hệ thống mới?
□ Có thể có cut-over trong giờ cao điểm không? (rủi ro cao)
□ Rollback plan nếu hệ thống mới có vấn đề trong ngày đầu?

HISTORICAL DATA:
□ Cần migrate bao nhiêu lịch sử giao dịch? (số năm)
□ Data format có chuẩn không hay nhiều inconsistencies?
□ Có data cleaning cần thiết trước khi migrate không?

LOYALTY POINTS:
□ Tổng điểm loyalty hiện tại của customers là bao nhiêu?
□ Điểm có expiry không? Có điểm sắp hết hạn không?
□ Migration plan: Cần đảm bảo không mất điểm của khách
□ Có điểm nào đang trong trạng thái pending/disputed không?

MASTER DATA:
□ Product catalog: Bao nhiêu SKU? Chất lượng data (tên, mô tả, giá) ra sao?
□ Customer database: Số lượng, chất lượng (duplicate, thiếu field)?
□ Supplier data: Đầy đủ không?
□ Staff/user accounts: Danh sách cần migrate không?

HARDWARE COMPATIBILITY:
□ Hardware hiện tại có tương thích với system mới không?
□ Hardware nào cần thay thế? Chi phí ước tính?
□ Timeline thay hardware có ảnh hưởng go-live không?

STAFF TRAINING:
□ Số staff cần đào tạo: Cashiers, Store Managers, Area Managers, IT
□ Training timeline: Tối thiểu bao lâu?
□ Có thể vừa train vừa vận hành song song không?
□ Champions tại mỗi store (người dùng thành thạo nhất) là ai?
```

### Bước 9: Output — As-Is Analysis Report

```
Ghi vào: .mc-data/docs/phase1-business/retail-as-is-analysis.md

Cấu trúc:

# Retail System As-Is Analysis

## Executive Summary
[3-5 dòng: Overall health, điểm mạnh, gaps nghiêm trọng nhất, migration risks cao nhất]

## Current System Inventory
### POS System
[Table: Component | Tool/Version | Status | Issues]

### Store Tools
[Table: Tool | Purpose | Coverage | Issues]

### Hardware Fleet
[Table: Hardware Type | Brand/Model | Count | Age | Replace Needed?]

## Data Quality Assessment
### Transaction Data
[Table: Metric | Current State | Acceptable Level | Gap | Severity]

### Inventory Accuracy
[Finding + evidence + impact]

## Gap Analysis

### Critical Gaps (block go-live hoặc gây rủi ro nghiêm trọng)
- [Gap]: [Business Impact] → [Recommendation]

### Important Gaps (ảnh hưởng đáng kể đến hiệu quả)
- [Gap]: [Business Impact] → [Recommendation]

### Nice-to-have Improvements
- [Improvement]: [Expected Benefit]

## Migration Risks

### Risk Matrix
[Table: Risk | Likelihood | Impact | Mitigation Plan]

### Critical Migration Items
1. In-progress transactions: [Plan]
2. Loyalty points: [Plan - số lượng, approach]
3. Historical data: [Plan - scope, cleaning needed]
4. Hardware compatibility: [Plan - replacement list]
5. Staff training: [Plan - timeline, champions]

## Recommendations

### Quick Wins (thực hiện ngay trước khi build mới)
1. [Action] — Effort: Low, Risk Reduction: High

### Build Requirements (input cho wf-analyze-requirements)
[Danh sách requirements phát sinh từ audit - có REQ-ID]

### Go-live Strategy
[Recommended cut-over approach: Big bang / Phased by store / Parallel run]
```

---

## Checklist trước khi submit

```
□ Tất cả hệ thống POS và tools hiện tại đã được inventory
□ Transaction data quality đã được assess (bao gồm offline transactions)
□ Inventory accuracy rate đã có số liệu cụ thể
□ Payment reconciliation process đã được map
□ Multi-store visibility gaps đã identified
□ Migration risks đã đầy đủ (in-progress transactions, loyalty points, data)
□ Hardware compatibility check đã thực hiện
□ Staff training requirements đã noted
□ Go-live strategy recommendation đã có
□ Output ghi vào .mc-data/docs/phase1-business/retail-as-is-analysis.md
```
