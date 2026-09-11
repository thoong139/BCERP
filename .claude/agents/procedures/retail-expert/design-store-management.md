# Playbook: Design Store Management Module

> **Type**: Agent Skill Playbook
> **Agent**: retail-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi có store management module
> **Output**: Feature spec cho store management module (`.mc-data/docs/phase2-features/[sys]/store-management/`)

---

## Khi nào dùng playbook này

- Khi cần spec module quản lý cửa hàng và vận hành
- Khi cần thiết kế shift management, staff permissions, store-level inventory
- Khi thiết kế dashboard cho multi-store chain hoặc franchise

---

## Procedure

### Bước 1: Xác định scope store management

```
READ: .claude/references/team-expert/retail/operations.md → Section Store Operations

Hỏi hoặc suy luận từ context:
□ Số stores trong chuỗi (hiện tại và kế hoạch mở rộng)
□ Có franchise model không? Nếu có → cần royalty tracking
□ Ca làm việc: 1 ca / 2 ca / 3 ca? Có ca đêm không?
□ Inventory model: Perpetual (real-time) hay periodic count?
□ Reporting hierarchy: Store → Area → Region → HQ?
□ KPIs chính HQ muốn theo dõi per store là gì?
□ Có cần so sánh hiệu suất giữa các stores không?
```

### Bước 2: Thiết kế Store Configuration

```
READ: .claude/references/team-expert/retail/controls.md → Store Setup

STORE MASTER DATA:
- Store ID, tên, địa chỉ, phone, khu vực (region/district)
- Store type (flagship, regular, express, kiosk)
- Giờ mở cửa theo ngày (thứ 2-6, thứ 7, CN, ngày lễ)
- Timezone (quan trọng nếu chuỗi multi-region)
- Số terminals POS tối đa
- Diện tích, capacity (khách hàng cùng lúc)
- Manager phụ trách (liên kết với Staff)
- Franchise info (nếu có): franchisee_id, contract_start, contract_end, royalty_rate

STORE-SPECIFIC SETTINGS (override từ HQ):
- Accepted payment methods (một số stores có thể không có EDC)
- Max discount % cashier được phép (có thể khác nhau theo store tier)
- Return policy (ngày hoàn trả, có thể khác franchise vs company-owned)
- Promotions tự chạy local (ngoài promotions từ HQ)

TERMINAL MANAGEMENT:
- Danh sách terminal IDs per store
- Trạng thái terminal: Active / Inactive / Maintenance
- Gán cashier vào terminal
- License / hardware info
```

### Bước 3: Thiết kế Shift Management

```
READ: .claude/references/team-expert/retail/operations.md → Section Shift Management

SHIFT STRUCTURE:
- Shift types: Morning (6am-2pm), Afternoon (2pm-10pm), Night (10pm-6am), Full day
- Mỗi shift có: opening_time, closing_time, supervisor, cashiers list

SHIFT OPENING PROCEDURE:
[1] Supervisor xác thực danh tính (PIN / biometric)
[2] Nhập số tiền mặt đầu ca (opening float)
[3] Kiểm tra và kích hoạt terminals
[4] Confirm nhân sự có mặt
[5] Review notes từ ca trước (handover notes)
[6] Shift status: OPEN

SHIFT HANDOVER:
- Supervisor ghi handover notes (issues, outstanding tasks, VIP customers)
- Ca mới nhận bàn giao tiền mặt (optional: count together)
- Log: người bàn giao, người nhận, tiền mặt trao tay

SHIFT CLOSING PROCEDURE:
[1] Cashiers hoàn thành giao dịch cuối
[2] Cash count per terminal (xem design-pos-system.md → Bước 6)
[3] Supervisor tổng hợp cash reconciliation toàn ca
[4] Print shift summary report
[5] Lock terminals
[6] Shift status: CLOSED
[7] Sync data về HQ (nếu cần manual trigger)

SHIFT REPORT:
- Tổng giao dịch, tổng doanh thu
- Breakdown theo payment method
- Số lượng refund, giá trị refund
- Cash variance (over/short)
- Items sold (top 10)
- Nhân viên làm việc và giờ công
```

### Bước 4: Thiết kế Staff & Permissions

```
READ: .claude/references/team-expert/retail/controls.md → Staff Permissions

ROLE HIERARCHY PER STORE:
Store Manager > Shift Supervisor > Senior Cashier > Cashier > Stock Clerk

PERMISSION MATRIX:
| Action                        | Cashier | Senior | Supervisor | Manager |
|-------------------------------|---------|--------|-----------|---------|
| Tạo transaction               | ✅      | ✅     | ✅        | ✅      |
| Apply discount ≤ 5%           | ✅      | ✅     | ✅        | ✅      |
| Apply discount 5-20%          | ❌      | ✅     | ✅        | ✅      |
| Apply discount > 20%          | ❌      | ❌     | ✅        | ✅      |
| Void transaction              | ❌      | ✅     | ✅        | ✅      |
| Refund (with receipt)         | ❌      | ✅     | ✅        | ✅      |
| Refund (without receipt)      | ❌      | ❌     | ✅        | ✅      |
| Mở cash drawer manual         | ❌      | ❌     | ✅        | ✅      |
| Xem store report              | ❌      | ❌     | ✅        | ✅      |
| Chỉnh sửa giá                 | ❌      | ❌     | ❌        | ✅      |
| Xem daily revenue             | ❌      | ❌     | ✅        | ✅      |
| Cash reconciliation           | ❌      | ❌     | ✅        | ✅      |
| Transfer hàng tồn             | ❌      | ❌     | ✅        | ✅      |

STAFF MANAGEMENT PER STORE:
- Danh sách nhân viên assign vào store
- Schedule: ca làm việc của từng người
- Attendance log (check-in/out)
- Performance notes

SUPERVISOR OVERRIDE:
- Supervisor có thể approve actions của cấp dưới bằng PIN
- Mỗi override được log: supervisor_id, action, reason, timestamp
```

### Bước 5: Thiết kế Store-level Inventory Control

```
READ: .claude/references/team-expert/retail/operations.md → Section Inventory

RECEIVING GOODS (Nhận hàng):
[1] Nhận Purchase Order hoặc Transfer Order từ HQ/warehouse
[2] Kiểm đếm thực tế (actual vs ordered)
[3] Ghi nhận discrepancy (thiếu/hư hỏng)
[4] Confirm receipt → tăng tồn kho store
[5] In barcode nếu sản phẩm không có barcode sẵn
[6] Gửi discrepancy report về HQ

STOCK COUNT (Kiểm kho):
- Partial count: đếm một số danh mục (ngày thường)
- Full count: đếm toàn bộ (đầu tháng, cuối năm)
- Blind count: staff đếm trước, system so sánh sau (tránh bias)
- Variance report: Actual vs System → ghi nhận shrinkage
- Adjustment: Manager approve adjustment kèm lý do

TRANSFER BETWEEN STORES:
- Tạo Transfer Order: store nguồn → store đích
- Approve: Manager store nguồn + Manager store đích (hoặc HQ)
- Dispatch: deduct từ store nguồn
- Receive: store đích confirm nhận → tăng tồn kho
- Status tracking: Requested → Approved → Dispatched → Received

SHRINKAGE TRACKING:
- Theft (ghi nhận khi phát hiện)
- Damage (sản phẩm hư hỏng không bán được)
- Expiry (hết hạn sử dụng)
- Administrative error (nhập sai)
- Mỗi adjustment cần lý do + manager approval

REORDER ALERT:
- Mỗi SKU có reorder_point per store (có thể khác nhau)
- Alert khi tồn kho ≤ reorder_point
- Auto-generate Purchase Request gửi HQ (optional)
```

### Bước 6: Thiết kế Store-level KPIs và Reporting

```
READ: .claude/references/team-expert/retail/operations.md → Section KPIs

STORE-LEVEL DAILY KPIs:
| Metric | Công thức | Mục tiêu mẫu |
|--------|-----------|--------------|
| Daily Revenue | Σ giao dịch trong ngày | vs Target ngày |
| Transaction Count | Số giao dịch hoàn thành | Tracking only |
| Average Transaction Value (ATV) | Revenue / Transaction Count | > 200k VND |
| Conversion Rate | Customers paid / Customers entered | > 25% |
| Items per Transaction | Σ items / Σ transactions | > 2.5 |
| Cash Variance | Actual cash - Expected cash | < 5k VND |
| Return Rate | Refund amount / Sales amount | < 2% |
| Shrinkage Rate | Shrinkage value / Inventory value | < 0.5% |

STORE MANAGER DASHBOARD:
- Live: revenue hôm nay vs hôm qua vs target
- Live: số giao dịch hôm nay
- Live: tồn kho cảnh báo (items below reorder point)
- Live: trạng thái terminals
- Today vs Last Week vs Same Day Last Year

AREA MANAGER DASHBOARD (so sánh stores):
- Bảng xếp hạng stores theo revenue, ATV, conversion rate
- Heatmap: giờ cao điểm của từng store
- Underperforming stores (< 80% target) highlighted
- Staff performance per store
- Inventory health per store

FRANCHISE MANAGER DASHBOARD (nếu có franchise):
- Royalty earned (% doanh thu franchisee)
- Royalty payment status (đã thu / chưa thu)
- Brand compliance score per franchisee
- Top/bottom performing franchise locations
```

### Bước 7: Thiết kế Franchise Fee Calculation (nếu có)

```
Chỉ thực hiện nếu mô hình có franchise.

FRANCHISE TYPES:
- Royalty-based: Franchisee đóng % doanh thu hàng tháng
- Fixed fee: Phí cố định hàng tháng
- Hybrid: Fixed + % doanh số vượt threshold

ROYALTY CALCULATION:
- Kỳ tính: Monthly (tháng dương lịch)
- Base: Net Sales (sau refund, không bao gồm VAT)
- Rate: configurable per franchisee contract
- Formula: Royalty = Net Sales × Royalty Rate
- Minimum: nếu doanh số thấp vẫn phải đóng tối thiểu

ROYALTY BILLING:
- Generate invoice cuối mỗi tháng
- Deadline thanh toán: thường 10-15 ngày sau invoice
- Penalty nếu trễ hạn: % tháng
- Dispute process: franchisee raise dispute → review → adjust

BRAND COMPLIANCE:
- Franchisee phải tuân thủ: giá, khuyến mãi, layout, đồng phục
- Audit định kỳ (mystery shopping)
- Score: 0-100, minimum threshold để gia hạn hợp đồng
```

### Bước 8: Feature Spec Output

```markdown
# Feature Spec: Store Management

## Overview
[Mô tả module quản lý cửa hàng]

## User Stories
- As a Store Manager, I want to see real-time store KPIs so that I can act quickly on issues
- As an Area Manager, I want to compare store performance so that I can identify underperformers
- As a Shift Supervisor, I want clear opening/closing procedures so that cash is always accounted for

## Functional Requirements
REQ-RETAIL-STORE-001: Store configuration và master data management
REQ-RETAIL-STORE-002: Shift management (open, handover, close)
REQ-RETAIL-STORE-003: Staff permissions matrix và supervisor override
REQ-RETAIL-STORE-004: Attendance và schedule management
REQ-RETAIL-INV-001: Goods receiving workflow
REQ-RETAIL-INV-002: Stock count (partial và full, blind count)
REQ-RETAIL-INV-003: Transfer between stores
REQ-RETAIL-INV-004: Shrinkage tracking và adjustment
REQ-RETAIL-INV-005: Reorder point alerts
REQ-RETAIL-RPT-001: Store manager daily dashboard
REQ-RETAIL-RPT-002: Area manager multi-store comparison dashboard
REQ-RETAIL-CHAIN-001: Multi-store visibility (tồn kho, doanh thu, hiệu suất)
REQ-RETAIL-FRAN-001: Franchise royalty calculation và billing (nếu có)
REQ-RETAIL-FRAN-002: Brand compliance tracking (nếu có)

## Data Model
[ERD: Store, Terminal, Staff, Shift, ShiftCashRecord, StockMovement, TransferOrder, FranchiseContract]

## Non-functional Requirements
- Dashboard refresh: ≤ 30s lag từ transaction thực tế
- Stock count: Support đếm concurrent nhiều staff (conflict-free)
- Multi-store query: Area dashboard load < 5s cho 100 stores
- Audit trail: Mọi inventory adjustment có log đầy đủ
```

---

## Checklist trước khi submit

```
□ Store configuration đủ fields (kể cả timezone cho multi-region)
□ Shift opening/closing procedure chi tiết
□ Permission matrix đầy đủ cho mọi sensitive actions
□ Supervisor override logging đã được design
□ Inventory receiving, count, transfer workflows đã spec
□ Shrinkage tracking và approval workflow đã có
□ KPIs đã define với công thức rõ ràng
□ Area Manager multi-store dashboard đã spec
□ Franchise royalty calculation đã spec (nếu franchise model)
□ REQ-ID đúng format REQ-RETAIL-STORE/INV/RPT/CHAIN/FRAN-[NNN]
□ Audit trail requirements đã included cho mọi critical actions
```
