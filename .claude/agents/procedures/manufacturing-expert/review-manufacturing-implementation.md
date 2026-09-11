# Playbook: Review Manufacturing Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: manufacturing-expert
> **Triggered by**: /wf-implement-feature khi review code của manufacturing module
> **Output**: Manufacturing implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của production planning, BOM, WO, QC, OEE modules
- Khi cần validate implementation từ manufacturing business logic perspective
- Khi cần check tính đúng đắn của MRP calculations, BOM explosion, OEE metrics
- Khi cần check work order state machine integrity và inventory impact

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type để load đúng checklist:
□ Production Planning / MRP → check net requirements, WO generation, shortage logic
□ BOM Management → check version control, explosion, scrap factors
□ Work Order Management → check state machine, material reservation, goods receipt
□ Shop Floor Control (MES) → check real-time logging, operation tracking
□ Quality Control → check inspection gates, NCR flow, lot hold
□ OEE Tracking → check formula, downtime categorization
□ Maintenance (CMMS) → check PM schedule, breakdown WO, spare parts
```

### Bước 2: Load controls knowledge

```
READ: controls.md → BẮT BUỘC cho mọi module

Compliance checklist áp dụng cho toàn bộ manufacturing:
□ Authorization: Approval levels đúng theo authorization matrix không?
   (xem controls.md Section 1 — từng action có đúng role không?)
□ Audit trail: Mọi transaction có ghi user_id, timestamp, before/after không?
   (controls.md Section 7 — retention periods)
□ Lot traceability: Mọi material movement có gắn lot_id không?
□ FIFO enforcement: System có force FIFO cho items có expiry không?
   (controls.md Section 4)
□ Negative inventory: System có prevent negative stock không?
□ QC hold: Material trong QC hold có bị block khỏi production picking không?
```

### Bước 3: Review theo module type

**Production Planning / MRP:**

```
READ: processes.md → Section 1: Production Planning & Scheduling

□ Net requirements formula đúng không?
  Công thức phải là: Net = Gross - OnHand(available) - OnOrder + SafetyStock
  Không được: Net = Gross - Total inventory (bao gồm cả QC Hold)
  Kiểm tra: OnHand có exclude các lots đang Hold không?

□ MRP action codes đủ không?
  (new/expedite/defer/cancel/no_action) — thiếu code → Planner không biết phải làm gì

□ Lot sizing đúng với cấu hình per item không?
  (lot_for_lot / fixed_qty / min_max) — phải respect min_order_qty và max_order_qty

□ Lead time có tính cả calendar (working days only) không? Hay đang dùng calendar days?

□ Shortage detection: có check shortage TRƯỚC KHI release WO không?
  WO không được release nếu material bị shortage chưa resolved

□ MRP run có phải background job không? Không được block main thread

□ Race condition: Nếu 2 MRPs chạy đồng thời → có lock mechanism không?
```

**BOM Management:**

```
READ: processes.md → Section 3: BOM Management

□ Single active version enforcement:
  Khi activate version mới → version cũ có tự động chuyển obsolete không?
  Không được có 2 versions active cùng lúc.

□ Effectivity date lookup đúng không?
  Query phải là: WHERE effective_from <= planned_date AND (effective_to IS NULL OR effective_to >= planned_date)
  Không được: chỉ lấy version mới nhất mà không check date

□ Phantom item handling:
  Phantom sub-assembly không được tạo WO con
  Phantom components phải explode thẳng xuống level dưới trong same parent WO

□ Scrap factor calculation đúng không?
  Planned qty = required_qty × (1 + scrap_pct / 100)
  Không được: planned qty = required_qty + scrap_pct (sai unit)

□ Circular reference check: BOM A chứa B chứa A → phải detect và block

□ BOM explosion performance:
  Đệ quy phải có depth limit (ví dụ max 15 levels)
  Không được: unlimited recursion (stack overflow với complex BOMs)

□ BOM locked sau khi WO closed: Không cho edit BOM đã gắn với closed WOs
```

**Work Order Management:**

```
READ: processes.md → Section 2: Shop Floor Control
READ: controls.md → Section 3: Production Workflow — Approval Levels

□ State machine transitions đúng không?
  Chỉ cho phép transitions hợp lệ:
  Draft → Released (cần approval), Released → In Progress, In Progress → Completed
  Không được: jump từ Draft → Completed

□ Material reservation khi Release:
  - Reserve đúng quantity (planned qty, không phải required qty)
  - Reserve từ đúng location
  - FIFO enforcement cho lotted items (controls.md Section 4)
  - Alert nếu stock không đủ sau reservation

□ Goods receipt khi Complete:
  - Tự động tạo inventory transaction: +qty vào FG location
  - Actual cost posting (actual material + labor + overhead)
  - WO variance = actual vs planned (phải ghi lại)

□ Cancel WO đang In Progress:
  - Phải unrelease reservations
  - Return WIP materials về kho (nếu chưa dùng)
  - Ghi lý do cancel + approver (controls.md: cần Plant Manager)

□ WO number uniqueness: Format WO-YYYY-NNNNN, không được duplicate

□ WO có link đúng đến BOM version tại thời điểm tạo WO không?
  Không được: WO lấy BOM "current active" — phải snapshot tại thời điểm release
```

**Quality Control:**

```
READ: controls.md → Section 2: Quality Control Gates
READ: controls.md → Section 6: Non-Conformance Handling

□ IQC gate: Hàng nhận về có mandatory inspection check không?
  Hàng không qua IQC không được nhập kho regular (phải vào Quarantine)

□ IPQC checkpoints: Operation có mandatory QC check có bị blocked không nếu chưa pass?
  Operator không được log "operation complete" trước khi QC Inspector approve

□ QC Hold logic:
  - QA Manager (và chỉ QA Manager) mới được set HOLD và release HOLD (controls.md)
  - Lots trong HOLD không được pick cho WOs (hard block, không phải warning)
  - Alert tự động khi lot đang bị hold mà có WO cần dùng

□ NCR creation: Khi inspection fail → NCR phải được tạo tự động hoặc prompt Inspector
  NCR thiếu: defect escaped vào production → compliance issue

□ Inspection sample size: Có implement AQL sampling tables không?
  Không được: hardcode sample size = 5 cho mọi lot size

□ QC result immutability: Inspection record đã submit không được xóa/sửa
  (chỉ được add amendment với reason)

□ Corrective action tracking: NCR có deadline và escalation nếu quá hạn không?
```

**OEE Tracking:**

```
READ: processes.md → Key Metrics: OEE

□ OEE formula đúng không?
  OEE = Availability × Performance × Quality
  Availability = Run Time / Planned Production Time
  Performance = (Ideal Cycle Time × Total Count) / Run Time
  Quality = Good Count / Total Count
  Không được: OEE = Good Output / Total Planned Output (không phải formula chuẩn)

□ Downtime categorization:
  Phải phân loại: breakdown / changeover / setup / planned_maintenance / unplanned
  Không được: chỉ track tổng downtime mà không phân loại

□ Planned Production Time:
  Có trừ planned breaks (lunch, shift change) không?
  Có xét shift schedule đúng work center không?

□ OEE real-time vs historical:
  Real-time OEE cập nhật mỗi bao lâu? (thường 5-15 phút)
  Historical OEE: daily/weekly/monthly aggregation đúng không?

□ Equipment downtime logging: Phải có start_time, end_time, reason_code, reported_by
  Không được: chỉ log duration mà không có timestamps

□ Benchmark comparison: Có alert khi OEE dưới threshold không? (ví dụ < 65% = critical)
```

### Bước 4: Performance Check

```
□ MRP run: Background job, có timeout handling không?
  MRP timeout → phải rollback planned orders (partial MRP = nguy hiểm)

□ BOM explosion: Đệ quy có được optimize không?
  Memoization cho repeated sub-assemblies trong large BOMs
  Batch explosion: N items cùng lúc dùng bulk query, không N individual queries

□ WO listing với filters: Có pagination không? Không được return 10.000 WOs cùng lúc

□ Production schedule board: Gantt data có được pre-computed không?
  Không được: compute Gantt real-time cho 500+ WOs trên mỗi request

□ OEE queries: Có index trên (machine_id, timestamp) không?
  OEE reports thường query lớn theo time range

□ Inventory transactions: Write-heavy, có optimistic locking để tránh double-deduct không?
  (quan trọng: negative inventory thường do race condition)

□ Quality inspection submit: Idempotent không? (double-click → 2 inspection records)
```

### Bước 5: Output — Review Report

```markdown
# Manufacturing Implementation Review: [Module Name]

## Status Tổng Quan: ✅ PASS / ❌ FAIL / ⚠️ CẦN ATTENTION

## Critical Issues (block go-live)
- [ ] [Issue]: [File/Function] → [Yêu cầu sửa cụ thể]
  → WHY: [Giải thích tại sao đây là blocker — safety/compliance/data integrity]

## Important Issues (sửa trong sprint tiếp theo)
- [ ] [Issue]: [Location] → [Recommendation]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

## Manufacturing Business Logic Checklist
| Hạng mục | Status | Notes |
|----------|--------|-------|
| Authorization matrix đúng | OK / FAIL | |
| Audit trail đầy đủ | OK / FAIL | |
| Lot traceability | OK / FAIL | |
| FIFO enforcement | OK / FAIL | |
| Negative inventory prevention | OK / FAIL | |
| QC hold blocks production | OK / FAIL | |
| [Module-specific checks] | | |

## Calculation Accuracy
| Calculation | Expected | Actual in Code | Status |
|-------------|----------|----------------|--------|
| Net requirements | Gross - OnHand - OnOrder + SS | [code logic] | |
| OEE formula | A × P × Q | [code logic] | |
| Scrap factor | qty × (1 + scrap%) | [code logic] | |

## Performance Concerns
[List các query hoặc operation có thể gây chậm ở production scale]

## Sign-off
□ Business logic đúng: OK / ISSUE
□ Controls compliance: OK / ISSUE
□ Data integrity: OK / ISSUE
□ Error handling: OK / ISSUE
□ Performance: OK / ISSUE
```

---

## Checklist trước khi submit

```
□ Đã load controls.md trước khi review bất kỳ module nào
□ Authorization matrix đã được verify theo controls.md Section 1
□ Audit trail retention periods đã check theo controls.md Section 7
□ MRP formula đã verify nếu review Planning module
□ OEE formula đã verify nếu review OEE module
□ Scrap factor calculation đã verify nếu review BOM/WO
□ FIFO và negative inventory prevention đã check
□ QC Hold → production block đã verify
□ Performance concerns đã noted với context (data volume, query pattern)
□ Critical issues có WHY rõ ràng (safety/compliance/data integrity)
```
