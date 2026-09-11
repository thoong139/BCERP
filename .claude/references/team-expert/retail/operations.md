# Retail Operations Reference

> Reference file cho retail-expert agent
> Load file này khi cần hiểu về vận hành trong domain Retail

## Store Operations

### POS Transaction Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    POS TRANSACTION FLOW                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Scan Items]                                               │
│       │                                                     │
│       ▼                                                     │
│  [Apply Discounts/Promotions]                               │
│       │                                                     │
│       ▼                                                     │
│  [Subtotal & Tax]                                           │
│       │                                                     │
│       ▼                                                     │
│  [Select Payment Method]                                    │
│       │                                                     │
│       ├─────┬─────┬─────┬─────┐                            │
│       ▼     ▼     ▼     ▼     ▼                            │
│     Cash  Card  Mobile Gift Other                          │
│       │     │     │     │     │                            │
│       └─────┴─────┴─────┴─────┘                            │
│                 │                                           │
│                 ▼                                           │
│         [Payment Complete]                                  │
│                 │                                           │
│                 ▼                                           │
│           [Print Receipt]                                   │
│                 │                                           │
│                 ▼                                           │
│           [Update Inventory]                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Inventory Management

### Perpetual Inventory System

```
┌─────────────────────────────────────────────────────────────┐
│                  INVENTORY UPDATES                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Receiving]        →  +Stock                              │
│  [Sales]            →  -Stock                              │
│  [Returns]          →  +Stock                              │
│  [Transfers In]     →  +Stock                              │
│  [Transfers Out]    →  -Stock                              │
│  [Adjustments]      →  +/-Stock                            │
│  [Shrinkage]        →  -Stock                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Replenishment Process

```
[Stock Level Check]
        │
        ▼
[Below Reorder Point?]
        │
    YES │  NO → [Continue Monitoring]
        │
        ▼
[Calculate Order Quantity]
        │
        ▼
[Create Purchase Order]
        │
        ▼
[Receive Goods]
        │
        ▼
[Update Inventory]
```

### Stock Count Methods

| Method | Frequency | Accuracy | Effort |
|--------|-----------|----------|--------|
| Annual count | Yearly | Low | High |
| Cycle counting | Ongoing | High | Medium |
| Perpetual + spot check | Ongoing | Highest | Low |

---

## Omnichannel Operations

### Fulfillment Options

| Method | Description | System Support |
|--------|-------------|----------------|
| Buy online, pick up in store (BOPIS) | Order online, collect at store | Inventory visibility |
| Ship from store | Store fulfills online order | Order routing |
| Endless aisle | Order out-of-stock items in store | Catalog access |
| Reserve & try | Reserve item, try in store | Reservation system |
| Buy online, return in store | Return online orders at store | Return processing |

### Order Routing Logic

```
[Customer Order]
      │
      ▼
[Check Inventory]
      │
      ├── All locations have stock
      │         │
      │         ▼
      │   [Route by rules:]
      │   - Closest to customer
      │   - Lowest shipping cost
      │   - Best fulfillment rate
      │
      └── Limited availability
                │
                ▼
          [Split Order?]
                │
           YES  │  NO
                │  └── [Wait for full availability]
                ▼
          [Partial Ship]
```

---

## Cash Management

### Cash Register Reconciliation

| Step | Action | Tolerance |
|------|--------|-----------|
| 1 | Count physical cash | Exact |
| 2 | Compare to POS total | ± $5 |
| 3 | Record variance | Log all |
| 4 | Investigate if over tolerance | Document |

### Safe Management

| Activity | Frequency | Controls |
|----------|-----------|----------|
| Cash drop | When drawer > limit | Two-person verification |
| Safe count | Daily | Dual custody |
| Deposit preparation | Daily | Camera, log |
| Bank deposit | Daily | Vary timing/route |

---

## Staff Scheduling

### Scheduling Factors

| Factor | Impact |
|--------|--------|
| Historical traffic | Base staffing |
| Promotions/events | Additional staff |
| Seasonality | Adjusted levels |
| Staff availability | Constraints |
| Labor laws | Compliance |

### Labor Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Sales per labor hour | Sales / Labor hours | $100-200 |
| Labor % of sales | Labor cost / Sales | 10-15% |
| Conversion rate | Transactions / Traffic | 20-30% |

---

## Loss Prevention

### Shrinkage Sources

| Source | Typical % | Prevention |
|--------|-----------|------------|
| External theft | 35-40% | Security, training |
| Internal theft | 30-35% | Controls, audits |
| Administrative error | 15-20% | Training, systems |
| Vendor fraud | 5-10% | Receiving procedures |

### Loss Prevention Controls

| Control | Purpose |
|---------|---------|
| Exception reports | Identify unusual patterns |
| Blind receiving | Prevent collusion |
| Purchase approval | Control unauthorized buying |
| Return validation | Prevent fraudulent returns |
| Surveillance | Deterrence, evidence |

---

## Key Retail Metrics

### Sales Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Sales per sq ft | Sales / Selling area | $300-500 |
| Comparable store sales | This year / Last year - 1 | Positive |
| Average transaction | Sales / Transactions | Varies |
| Units per transaction | Units / Transactions | 2-4 |
| Conversion rate | Transactions / Traffic | 20-30% |

### Inventory Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Inventory turnover | COGS / Avg inventory | 4-8x/year |
| Sell-through rate | Units sold / Units received | >80% |
| Stock-to-sales ratio | Inventory / Monthly sales | 1.5-2.5 |
| Shrinkage rate | Lost inventory / Sales | <1.5% |
| GMROI | Gross margin / Avg inventory | >200% |

---

## Promotional Pricing

### Discount Types

| Type | Application | System Handling |
|------|-------------|-----------------|
| Percentage off | % discount | Applied to item/transaction |
| Dollar off | Fixed amount | Threshold-based |
| BOGO | Buy one, get one | Automatic trigger |
| Bundle pricing | Multi-item discount | Package setup |
| Loyalty discount | Member-only | Customer identification |

### Markdown Management

| Stage | Discount | Action |
|-------|----------|--------|
| Initial | 0% | Full price |
| First markdown | 20-30% | Slow movers |
| Second markdown | 40-50% | Aging inventory |
| Final clearance | 60-70%+ | Exit strategy |
