# Playbook: Review Operations Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: operations-expert
> **Triggered by**: /wf-implement-feature khi review code của operations/inventory module
> **Output**: Operations implementation review report từ domain perspective

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của Inventory, Supply Chain, hoặc Quality module
- Khi cần validate business logic từ operations domain perspective
- Khi cần check data integrity, costing accuracy, và concurrency handling

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type để biết checklist nào cần focus:
□ Inventory Management → check costing, negative stock, FIFO logic
□ Goods Receipt (GRN) → check PO matching, QC hold, cost layer creation
□ Goods Issue (GI) → check allocation, FIFO/FEFO selection, negative stock guard
□ Stock Adjustment → check authorization, audit trail, approval workflow
□ Cycle Count → check freeze logic, variance calculation, adjustment posting
□ Procurement / PO → check approval routing, 3-way matching, vendor logic
□ Supply Chain Visibility → check data freshness, KPI calculation accuracy
```

### Bước 2: Load controls knowledge

```
READ: controls.md — Bắt buộc, bất kể module nào

Compliance checklist áp dụng cho mọi operations module:
□ Authorization: Mọi write operation có kiểm tra user role không?
□ Audit trail: Mọi inventory transaction có được log với user + timestamp không?
□ No delete: Transactions có bị allow hard delete không? (phải void, không delete)
□ Approval gates: High-value adjustments có đi qua approval không?
□ Period control: Có chặn post vào closed period không?
```

### Bước 3: Review theo module type

**Inventory — Negative Stock Prevention:**
```
READ: controls.md → Section 2: Negative Stock Prevention

□ GI: Có check qty_available >= qty_requested trước khi post không?
□ Transfer: Có check source location có đủ qty không?
□ Allocation: Có reserve stock ngay khi tạo order không? (prevent double allocation)
□ Race condition: Nếu 2 pickers đồng thời pick cùng item → Xử lý thế nào?
  → Cần optimistic locking hoặc pessimistic locking trên inventory balance row
□ Override: Nếu có manager override → Có yêu cầu reason code không?
□ Override: Có log override với approver, timestamp, reason không?
```

**Inventory — Costing Calculation:**
```
READ: controls.md → Section 3: Valuation Method Controls

FIFO Mode:
□ GRN tạo cost layer mới: (receipt_date, qty, unit_cost) → đúng không?
□ GI depletes layers: OLDEST first → Code có sort layers by receipt_date ASC không?
□ Multi-layer depletion: GI qty > first layer qty → Có deplete sang layer tiếp theo không?
□ Blended cost: Khi deplete nhiều layers → cost = sum(qty_i × cost_i) / total_qty
□ Layer integrity: qty_remaining trên layers phải = qty_on_hand trong inventory balance
□ Validation: Có daily reconciliation job check không?

Average Cost Mode:
□ GRN recalculate avg: new_avg = (old_qty × old_avg + new_qty × new_cost) / (old_qty + new_qty)
□ Formula đúng không? Chia cho (old_qty + new_qty), KHÔNG phải (old_avg + new_cost) / 2
□ GI dùng avg cost tại thời điểm issue (không phải historical avg)
□ Khi avg cost thay đổi → Có revalue inventory value trên balance không?
```

**Inventory — FIFO/FEFO Lot Selection:**
```
□ Khi GI hoặc allocation: Hệ thống chọn lot nào?
□ FIFO: Lot có receipt_date sớm nhất → Kiểm tra ORDER BY receipt_date ASC
□ FEFO: Lot có expiry_date sớm nhất → Kiểm tra ORDER BY expiry_date ASC
□ Mixed: Nếu item có expiry → tự động dùng FEFO, không có expiry → dùng FIFO
□ Lot selection không bypass: Không cho phép picker chọn lot khác (trừ có permission)
□ Expiry alert: Khi chọn lot gần hết hạn → Warning nhưng vẫn cho phép?
□ Expired lot: Hệ thống có chặn issue từ expired lot không?
```

**Stock Adjustment:**
```
READ: controls.md → Section 1: Stock Authorization Matrix + Section 5

□ Variance %: Hệ thống có tự tính variance % = |adj_qty| / on_hand × 100 không?
□ Routing: ≤5% → auto-approve; 5-10% → Manager; >10% → Director → đúng không?
□ Value routing: Nếu value impact > 50M VND → Finance approval added → đúng không?
□ Write-off: Bắt buộc Finance approval → Code có enforce không?
□ Reason code: Adjustment có yêu cầu reason code không? (Damage / Counting error / Theft...)
□ Audit: Log đầy đủ: old_qty, new_qty, adj_qty, reason, created_by, approved_by, timestamp
□ Immutability: Đã posted adjustment có thể edit không? (Không được — phải tạo reverse)
```

**Goods Receipt (GRN):**
```
READ: controls.md → Quick Reference: Before GRN Posting
READ: operations.md → Process 1: Goods Receipt

□ PO link: Nếu GRN linked to PO → Có validate PO exists và status = Approved không?
□ Over-receipt: Qty nhận > Qty PO → Có alert hoặc block không?
□ QC hold: item.requires_qc = true → GRN status phải = "QC Hold", không tự động post
□ QC flow: QC Inspector pass → Status transition → Warehouse approve → Post
□ Cost layer: Sau khi post → Có tạo cost layer đúng không? (FIFO mode)
□ Avg cost update: Sau khi post → Có recalculate average cost không? (Average mode)
□ Duplicate GRN: Có prevent post cùng 1 GRN 2 lần không? (idempotency check)
□ Lot creation: Nếu item.track_lot = true → Lot record được tạo khi GRN post không?
```

**3-Way Matching (PO / GRN / Invoice):**
```
□ Matching logic: Invoice qty ≤ GRN qty (không match vượt qty đã nhận)
□ Price tolerance: |Invoice price - PO price| / PO price ≤ tolerance% (configurable)
□ Full match result: Auto-approve → forward Finance → đúng không?
□ Partial match: Hold + highlight lines có discrepancy → Không auto-approve
□ Duplicate invoice: Cùng invoice number từ cùng vendor → Có chặn không?
□ Credit note: Deduct từ matched amount, không tạo negative invoice
```

**Cycle Count:**
```
READ: operations.md → Process 3: Stock Taking
READ: controls.md → Section 6: Physical Count Audit

□ Freeze scope: Khi count đang diễn ra → Có block transactions cho items/locations trong scope?
□ Blind count: Counter không nhìn thấy system qty (tránh bias)
□ Variance calc: system_qty - counted_qty → Có dấu đúng không? (dương = system nhiều hơn)
□ Investigation threshold: Variance vượt tolerance → Yêu cầu recount trước khi post adj
□ Adjustment approval: Sau count → Adjustment phải qua approval matrix như stock adj thường
□ Audit trail: Ghi lại: counter, count_qty, system_qty, variance, investigation_notes, approver
```

### Bước 4: Concurrency và Performance Check

```
□ Simultaneous picks: Khi 2 pickers cùng pick cùng item + location cùng lúc:
  → Có optimistic locking (version field + check on update) không?
  → Hoặc pessimistic locking (SELECT FOR UPDATE / row-level lock)?
  → Nếu conflict → User 2 nhận thông báo gì? Retry logic?

□ GRN posting performance: Nếu GRN có 100+ lines → Bulk insert vs loop insert?
  → Loop với individual INSERT = N+1 problem → Phải batch

□ Inventory balance query: Với 100k+ SKUs, query on-hand không dùng full scan
  → Indexes: (item_id, location_id), (item_id, lot_id)

□ ROP calculation job: Nếu chạy cho toàn bộ items → Background job, không block UI
  → Có async processing / queue không?

□ Cost recalculation: Average cost recalc sau mỗi GRN → Phải lock item row
  → Prevent concurrent GRNs cho cùng item gây race condition trên avg cost
```

### Bước 5: Access Control Check

```
READ: personas.md → Quick Reference: Operations Persona Access Matrix

□ Warehouse staff: Có thể adjust stock của location khác không? (Phải chặn)
□ Inventory Clerk: Có thể approve adjustment >5% không? (Phải chặn)
□ View-only roles: Finance có thể post inventory transactions không? (Phải chặn)
□ Vendor Portal: Vendor có thể xem POs của vendor khác không? (Phải chặn — row-level security)
□ QC Inspector: Có thể pass/fail inspection items ngoài scope không? (Phải chặn)
□ API endpoints: Có auth check không? POST /api/inventory/adjustments cần role gating
```

### Bước 6: Output — Review Report

```markdown
# Operations Implementation Review: [Module Name]

## Domain Compliance: ✅ PASS / ❌ FAIL / ⚠ NEEDS ATTENTION

## Critical Issues (chặn go-live)
- [ ] [Issue]: [Location in code] → [Required fix]
  Lý do critical: [Business/financial impact nếu không fix]

## Important Issues (fix trước sprint kế tiếp)
- [ ] [Issue]: [Location] → [Recommendation]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

## Compliance Checklist
| Item | Status | Notes |
|------|--------|-------|
| Negative stock prevention | ✅ / ❌ | |
| FIFO/FEFO lot selection | ✅ / ❌ | |
| Costing calculation accuracy | ✅ / ❌ | |
| Adjustment authorization matrix | ✅ / ❌ | |
| Audit trail completeness | ✅ / ❌ | |
| No hard-delete on transactions | ✅ / ❌ | |
| Period close protection | ✅ / ❌ | |
| Access control per role | ✅ / ❌ | |

## Concurrency Concerns
[List any race conditions found + severity]

## Performance Concerns
[List N+1 queries, missing indexes, missing async processing]

## Sign-off
□ Inventory transaction integrity: OK / ISSUE
□ Costing accuracy: OK / ISSUE
□ Authorization controls: OK / ISSUE
□ Concurrency handling: OK / ISSUE
□ Audit trail: OK / ISSUE
```

---

## Checklist trước khi submit

```
□ Negative stock guard đã được verify (bao gồm concurrent access)
□ FIFO lot selection ORDER BY đã được kiểm tra
□ Costing formula đã được verify (đặc biệt average cost recalc)
□ Authorization matrix đã khớp với controls.md thresholds
□ 3-way matching logic đã được kiểm tra (nếu in scope)
□ Audit trail đầy đủ: mọi post-able transaction có full log
□ Hard-delete transactions không được phép
□ Concurrency issues đã được identified và flagged
```
