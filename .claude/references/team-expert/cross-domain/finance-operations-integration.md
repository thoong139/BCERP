# Cross-Domain - Finance-Operations Integration

> **Domain**: Cross-Domain / Finance & Operations
> **Last Updated**: 2026-03-15
> **Nguồn**: Tổng hợp từ finance-expert và operations-expert agents — ERP integration best practices

---

## 1. Order-to-Cash (O2C) Process Flow

Toàn bộ vòng đời từ khi nhận đơn hàng đến khi thu được tiền.

```
Customer PO → Order Entry → Credit Check → Fulfillment → Shipping → Invoicing → Collection → Revenue Recognition
     │              │              │             │             │           │            │               │
  Sales CRM      ERP/OMS      Finance       Warehouse      Logistics    AR Module   AR Module      GL/Revenue
```

**Handoff quan trọng:**
- Operations → Finance: Proof of delivery (POD) là trigger để invoice
- Finance → Operations: Credit hold/release ảnh hưởng trực tiếp đến fulfillment

**Bottleneck phổ biến:**
- POD thiếu hoặc trễ → Invoice trễ → Cash trễ
- Credit check thủ công → Order hold kéo dài → Customer churn

---

## 2. Procure-to-Pay (P2P) Process Flow

Toàn bộ vòng đời từ khi nhận ra nhu cầu mua hàng đến khi thanh toán.

```
Requisition → Approval → PO Issued → Goods Received → Invoice Received → 3-Way Match → Payment → GL Posting
     │             │          │              │                │                │             │          │
  Requestor    Manager    Procurement     Warehouse          AP Clerk        AP System    Treasury    Finance
```

**3-Way Match:** PO quantity/price ↔ GRN quantity ↔ Supplier Invoice = điều kiện để thanh toán.

**Ngoại lệ cần xử lý:**
- Invoice amount vượt PO tolerance (thường ±5%) → Escalate
- GRN chưa có khi invoice đến → Invoice park, chờ GRN
- Hàng bị reject → Debit note cho supplier

---

## 3. Inventory Valuation Methods

| Phương pháp | Mô tả | Khi dùng | Tác động thuế |
|-------------|-------|----------|---------------|
| **FIFO** (First In, First Out) | Hàng nhập trước, xuất trước | COGS thấp khi giá tăng, inventory cao | COGS thấp → Profit cao → Thuế cao hơn |
| **LIFO** (Last In, First Out) | Hàng nhập sau, xuất trước | Phổ biến ở Mỹ (US GAAP); không được phép dưới IFRS | COGS cao → Profit thấp → Thuế thấp |
| **Weighted Average** | Giá bình quân gia quyền theo từng lần nhập | Hàng đồng nhất, nhiều lần nhập | COGS ổn định, ít biến động |
| **Specific Identification** | Theo dõi từng unit cụ thể | Hàng có giá trị cao, unique (xe, thiết bị) | Chính xác nhất nhưng phức tạp |

**Lưu ý:** Khi đổi phương pháp valuation, phải khai báo trong financial statements (IAS 8 / ASC 250).

---

## 4. Cost Accounting Integration Points

| Operations Event | Financial Impact | GL Account | Trigger |
|-----------------|-----------------|-----------|---------|
| Production completion | Increase Finished Goods Inventory | Dr. Finished Goods / Cr. WIP | Production Order close |
| Raw material issue | Decrease RM Inventory, increase WIP | Dr. WIP / Cr. Raw Materials | Goods Issue posting |
| Inventory adjustment (physical count) | Gain or loss on adjustment | Dr/Cr. Inventory Adjustment Expense | Cycle count reconciliation |
| Scrap & waste | COGS increase, inventory decrease | Dr. Scrap Expense / Cr. Inventory | Quality rejection posting |
| Customer returns | Inventory increase, revenue reversal | Dr. Inventory / Cr. Revenue (reversal) | RMA goods receipt |
| Intercompany transfer | Transfer pricing entry | Dr. Interco Receivable / Cr. Interco Payable | Intercompany GRN |

---

## 5. Three-Way Matching Process

```
       PO (Purchase Order)
       │  ├── Quantity: 100 units
       │  └── Price:    $50/unit → Total $5,000
       │
       ├── Match 1: GRN (Goods Receipt Note)
       │            Quantity received: 100 units ✓
       │
       └── Match 2: Supplier Invoice
                    Quantity billed: 100 units ✓
                    Amount billed: $5,000 ✓
                         │
                         ▼
                    APPROVED FOR PAYMENT ✓

Nếu bất kỳ match nào fail → Tạo Exception → Assign cho AP Clerk xử lý
```

**Tolerance rules phổ biến:**
- Quantity variance: ±2-3%
- Price variance: ±5% hoặc fixed amount (e.g. ±$100)
- Ngoài tolerance → Manual review bắt buộc

---

## 6. Budget vs Actual Variance Analysis

| Variance Type | Công thức | Khi nào điều tra |
|---------------|----------|-----------------|
| Volume Variance | (Actual Volume - Budget Volume) × Budget Price | >±10% hoặc >$10K |
| Price/Rate Variance | (Actual Price - Budget Price) × Actual Volume | >±5% hoặc >$5K |
| Mix Variance | (Actual Mix - Budget Mix) × Budget Margin | Khi product mix thay đổi đáng kể |
| Efficiency Variance | (Actual Hours - Standard Hours) × Standard Rate | >±8% trong sản xuất |

**Variance Reporting Template:**

```
Variance Report: [Period]
┌─────────────┬────────┬────────┬────────┬────────────────────────────┐
│ Cost Center │ Budget │ Actual │ Var $  │ Root Cause                 │
├─────────────┼────────┼────────┼────────┼────────────────────────────┤
│ Production  │ 500K   │ 540K   │ +40K U │ Overtime do machine outage │
│ Logistics   │ 120K   │ 108K   │ -12K F │ Lower fuel cost            │
│ Procurement │ 300K   │ 310K   │ +10K U │ Supplier price increase     │
└─────────────┴────────┴────────┴────────┴────────────────────────────┘
U = Unfavorable (thực tế > budget), F = Favorable (thực tế < budget)
```

---

## 7. Month-End Close Checklist (Operations → Finance Handoff)

**Tuần cuối tháng (Day -3 đến Day 0):**

| Hành động | Owner | Deadline |
|-----------|-------|----------|
| Confirm tất cả GRN đã post | Warehouse | Day -2 |
| Submit production completion reports | Plant Manager | Day -1 |
| Finalize inventory count discrepancies | Inventory Control | Day -1 |
| Confirm all shipments invoiced | Logistics | Day 0 |
| Submit overtime/labor hours | Operations | Day 0 |

**Đầu tháng sau (Day 1 đến Day 5):**

| Hành động | Owner | Deadline |
|-----------|-------|----------|
| Post inventory valuation | Finance | Day 1 |
| Calculate production variances | Cost Accounting | Day 2 |
| Accrue unbilled vendor invoices | AP | Day 2 |
| Reconcile intercompany balances | Finance | Day 3 |
| Post depreciation | Finance | Day 3 |
| Finalize P&L | Finance | Day 5 |

---

## 8. Revenue Recognition (ASC 606 / IFRS 15 Basics)

**5-Step Model:**

```
Step 1: Xác định hợp đồng với khách hàng
Step 2: Xác định các Performance Obligations (PO) trong hợp đồng
Step 3: Xác định Transaction Price (tổng giá trị hợp đồng)
Step 4: Allocate Transaction Price cho từng PO
Step 5: Recognize Revenue khi (hoặc trong quá trình) PO được thực hiện
```

**Ví dụ thực tế — SaaS bundle:**

| Performance Obligation | Allocated Price | Khi Recognize |
|------------------------|----------------|---------------|
| Software license | $8,000 | Khi license được giao (Point in time) |
| Implementation service | $4,000 | Rải đều 3 tháng triển khai (Over time) |
| 12-month support | $3,000 | Rải đều 12 tháng (Over time) |
| **Total Contract** | **$15,000** | |

---

## 9. Working Capital Optimization

| Metric | Công thức | Mục tiêu | Đòn bẩy |
|--------|----------|----------|---------|
| **Inventory Turnover** | COGS / Average Inventory | Cao → tốt (hàng không tồn kho) | Just-in-time, demand forecasting |
| **DSO (Days Sales Outstanding)** | (AR / Revenue) × 365 | Thấp → tốt (thu tiền nhanh) | Early payment discount, AR automation |
| **DPO (Days Payable Outstanding)** | (AP / COGS) × 365 | Cao → tốt (giữ tiền lâu hơn) | Negotiate payment terms với supplier |
| **Cash Conversion Cycle** | Inventory Days + DSO - DPO | Thấp/âm → tốt | Cả 3 đòn bẩy trên |

```
Cash Conversion Cycle = Inventory Days + DSO - DPO

Ví dụ:
  Inventory Days:  45 ngày
  DSO:             30 ngày
  DPO:             60 ngày
  ─────────────────────────
  CCC = 45 + 30 - 60 = 15 ngày

Amazon CCC thường âm → Khách hàng trả trước, Amazon trả supplier sau.
```

---

## 10. Intercompany Transaction Handling

Khi nhiều entities trong cùng tập đoàn giao dịch với nhau:

| Bước | Hành động | System |
|------|-----------|--------|
| 1 | Entity A bán hàng cho Entity B theo transfer price | ERP Entity A |
| 2 | Entity A ghi nhận Interco Revenue, Entity B ghi nhận Interco Cost | GL cả hai |
| 3 | Reconcile Interco AR (A) = Interco AP (B) hàng tháng | Consolidation tool |
| 4 | Eliminate Interco transactions khi consolidate | Consolidation |

**Lưu ý tuân thủ:** Transfer pricing phải theo arm's length principle (OECD guidelines) — dùng giá thị trường hợp lý để tránh rủi ro thuế.

---

## Quick Reference: Finance-Operations Friction Points

| Friction Point | Triệu chứng | Giải pháp |
|----------------|-------------|-----------|
| PO-Invoice mismatch | Invoice bị hold lâu, vendor khiếu nại | Tăng tolerance bands, cải thiện PO accuracy |
| GRN trễ | Invoice cần accrual lớn cuối tháng | Real-time GRN posting từ mobile/scanner |
| Inventory valuation sai | Gross margin biến động bất thường | Cycle count thường xuyên, lock down period |
| Production cost overrun | Variance report luôn Unfavorable | Standard cost review hàng quý |
| Cash flow bất ngờ | Treasury bị caught off guard | Rolling 13-week cash forecast từ AR+AP data |
