# E-commerce - Operational Analysis Framework

> **Domain**: E-commerce / Thương mại điện tử
> **Last Updated**: 2026-03-19

---

## 1. Core Processes

### Process 1: Product Catalog Management

```
Create → Review → Publish → Update → Archive
   │         │         │         │         │
   ▼         ▼         ▼         ▼         ▼
Draft     QA Check  Go Live   Maintain  Deactivate
Content   Images    SEO       Pricing   Stock=0
Attrs     Attrs     Index     Variants  or EOL
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Create | Content Manager | Assign SKU, generate slug | Required fields check |
| Review | Category Manager | Verify taxonomy, images, attributes | Completeness score ≥80% |
| Publish | Content Manager | Index search, push to CDN | Price set, stock allocated |
| Update | Content/Ops | Sync variants, reprice, re-index | No orphaned variants |
| Archive | Ops Manager | Remove from listing, keep order history | Zero active inventory |

### Process 2: Order Fulfillment

```
Order Placed → Payment Verified → Pick & Pack → Shipped → Delivered → Closed
      │               │               │             │           │         │
      ▼               ▼               ▼             ▼           ▼         ▼
   Allocate       Confirm at      Generate       Update      Confirm    Release
   Inventory      Gateway         Pick List      Tracking    POD        Loyalty
```

| Step | Owner | System Actions | SLA |
|------|-------|----------------|-----|
| Order Placed | System | Reserve inventory (atomic decrement) | Instant |
| Payment Verified | Payment Gateway | Webhook callback, update order status | <2 min |
| Pick & Pack | Warehouse | Generate picklist, print label | <4 hours (standard) |
| Shipped | Carrier | Push tracking number to customer | Within 24h of order |
| Delivered | Carrier / Customer | Capture POD, trigger review request | Per carrier SLA |
| Closed | System | Release any holds, update CLV | T+7 days post-delivery |

### Process 3: Inventory Management

```
Reorder Point → Purchase Order → Receive GRN → QC → Put-away → Available
      │               │               │          │       │           │
      ▼               ▼               ▼          ▼       ▼           ▼
   Alert Ops      Send to         Count &     Pass/  Update WMS  Sync to
   Manager        Supplier        Verify      Fail   Location    Storefront
```

| Step | Owner | Validation |
|------|-------|------------|
| Reorder Point | System alert → Ops Manager | Stock level ≤ reorder threshold |
| Purchase Order | Procurement / Ops | PO matches supplier agreement |
| Receive GRN | Warehouse | Quantity matches PO ±2% tolerance |
| QC | Warehouse / QA | No damage, correct spec |
| Put-away | Warehouse | WMS location assigned |
| Available | System | Storefront inventory count updated atomically |

### Process 4: Returns & Refunds

```
Return Request → Approve/Reject → Pickup/Drop-off → Inspect → Refund/Replace
       │               │                 │              │            │
       ▼               ▼                 ▼              ▼            ▼
   Log Reason      Policy Check      Reverse         Grade      Process to
   + Photo         (window,          Logistics       Condition   Payment GW
   Evidence        category)                         A/B/C/D    or Restock
```

| Return Grade | Condition | Disposition |
|--------------|-----------|-------------|
| A | Unopened, original packaging | Restock as new |
| B | Opened, all parts present | Restock as refurbished |
| C | Used, minor damage | Sell via outlet / discount |
| D | Damaged, unusable | Scrap or vendor claim |

---

## 2. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Process and verify new orders | Ops Manager | 1-2 hours | Manual exceptions on failed payments |
| Monitor inventory alerts | Ops Manager | 30 min | Multi-warehouse sync lag |
| Respond to CS escalations | CS Lead | 1-2 hours | Scattered order data across systems |
| Update price changes (promo) | Category Manager | 30 min | No bulk pricing tool |
| Review failed payment retries | Finance / Ops | 30 min | Gateway timeout ambiguity |
| Check shipping carrier status | Ops | 30 min | Late delivery spike on peak days |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Catalog hygiene (dead links, missing images) | Content Manager | 2-3 hours | No automated audit |
| Promotion planning and setup | Marketing / Category | 2 hours | Coupon rule conflicts |
| Carrier performance review | Ops Manager | 1 hour | Data in multiple dashboards |
| Inventory replenishment forecast | Ops / Procurement | 2 hours | Manual spreadsheet |
| Return trend analysis | Ops / CS | 1 hour | No consolidated return dashboard |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Vendor / supplier negotiation prep | Procurement / Ops | 4 hours | Historical sell-through data hard to pull |
| GMV and conversion rate reporting | Data / Ops | 3 hours | Multi-channel attribution gaps |
| Platform fee reconciliation | Finance | 2 hours | Gateway fee reports delayed |
| Catalog SEO audit | Content Manager | 3 hours | Manual keyword tracking |
| E-invoice batch verification | Finance | 2 hours | Invoice issuance gaps |

### Quarterly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Seasonal catalog planning | Category / Marketing | 1 week | Long lead times for photography |
| Platform optimization review | Ops Manager | 4 hours | A/B test data not centralized |
| Inventory write-off and clearance | Finance / Ops | 4 hours | Manual aging report |
| Tax / VAT compliance review | Finance | 3 hours | Mixed VAT rates (8%/10%) |

---

## 3. Decision Support Requirements

### Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Operations Overview | Ops Manager | Orders/hour, fulfillment backlog, inventory alerts |
| Sales Performance | Category Manager, Director | GMV, conversion rate, AOV, revenue by category |
| Inventory Health | Ops / Warehouse | Stock level, turnover, dead stock, reorder queue |
| Customer Experience | CS Lead, Marketing | Cart abandonment rate, return rate, NPS, CSAT |
| Payment Health | Finance | Payment success rate, chargeback rate, gateway uptime |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Order fulfillment summary | Daily | Operations tracking | Ops Manager |
| Inventory position | Daily | Reorder decisions | Ops / Procurement |
| Revenue & GMV | Weekly | Business performance | Director |
| Return analysis | Weekly | Product quality signals | Ops / Category |
| Promotion effectiveness | Post-campaign | ROI measurement | Marketing / Finance |
| E-invoice compliance | Monthly | Nghị định 123/2020 audit | Finance / Legal |

---

## 4. Integration Touchpoints

### Internal Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **OMS → WMS** | Order → Warehouse | Trigger pick & pack workflow |
| **WMS → Storefront** | Stock level → Product page | Real-time inventory display |
| **Payment Gateway → OMS** | Webhook → Order status | Confirm/cancel orders |
| **ERP / Finance** | Order → Revenue recognition | VAT calculation, e-invoice |
| **CRM** | Order history → Customer profile | Loyalty, CLV tracking |

### External Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **VNPay / MoMo / ZaloPay** | Bidirectional | Payment processing, refunds |
| **Giao Hang Nhanh / GHTK / Viettel Post** | Bidirectional | Shipping, tracking, POD |
| **MISA / VIETTEL eInvoice** | Outbound | Hóa đơn điện tử (Nghị định 123/2020) |
| **Google Shopping / Meta Catalog** | Outbound | Product feed for ads |
| **Shopee / Lazada / Tiki** | Bidirectional | Multi-channel listing sync |

---

## 5. KPIs & Metrics

### Conversion Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Conversion Rate | Orders / Sessions × 100 | 2–3% |
| Add-to-Cart Rate | Cart additions / Product views × 100 | 8–12% |
| Cart Abandonment Rate | Abandoned carts / Initiated carts × 100 | <70% |
| Checkout Completion Rate | Orders / Checkout initiations × 100 | >70% |
| Average Order Value (AOV) | Revenue / Orders | Varies by category |

### Fulfillment Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| On-time Fulfillment Rate | Shipped on time / Total orders × 100 | >95% |
| Order Accuracy Rate | Correct orders / Total orders × 100 | >99% |
| Return Rate | Returns / Orders shipped × 100 | <10% |
| Refund Processing Time | Avg days from request to credit | <3 business days |

### Inventory Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Inventory Turnover | COGS / Avg inventory value | 4–8× per year |
| Stockout Rate | SKUs out of stock / Total active SKUs × 100 | <2% |
| Dead Stock Rate | Units unsold >90 days / Total units × 100 | <5% |
| Fill Rate | Lines shipped complete / Lines ordered × 100 | >98% |

### Customer & Revenue Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Customer Lifetime Value (CLV) | AOV × Purchase frequency × Retention period | Varies |
| Repeat Purchase Rate | Returning buyers / Total buyers × 100 | >30% |
| Revenue per Visit | Revenue / Sessions | Varies |
| Payment Success Rate | Successful payments / Payment attempts × 100 | >95% |
| PDP Load Time (LCP) | Core Web Vital, largest contentful paint | <2.5s |

---

## Quick Reference: Operation Signals by Priority

| Signal | Threshold | Action |
|--------|-----------|--------|
| Payment success rate drop | <90% | Escalate to gateway & tech team immediately |
| Stockout on top-20 SKUs | Any | Trigger emergency reorder |
| Cart abandonment spike | >80% single day | Check checkout errors, payment gateway |
| Return rate spike by category | >15% | Trigger product quality review |
| Order fulfillment backlog | >200 orders aged >6h | Add warehouse shift or escalate |
