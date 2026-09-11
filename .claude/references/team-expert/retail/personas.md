# Retail User Personas

> Reference file cho retail-expert agent
> Load file này khi cần hiểu về users trong domain Retail

## Danh sách Personas

### 1. Store Manager

**Profile:**
- Chức danh: Store Manager / Quản lý Cửa hàng
- Kinh nghiệm: Mid to Senior level
- Technical skill: Medium
- Tần suất sử dụng hệ thống: Daily (full day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Open/close store | 2x/day | 30 min each | Critical |
| Review sales | Daily | 30 min | High |
| Manage staff schedule | Daily | 30 min | High |
| Handle escalations | As needed | Variable | High |
| Inventory checks | Daily | 1 hour | High |
| Cash reconciliation | 2x/day | 30 min | Critical |

**Key Decisions:**
| Decision | Based On | System Support |
|----------|----------|----------------|
| Staff scheduling | Traffic forecast | Scheduling tool |
| Stock replenishment | Sales, stock levels | Reorder alerts |
| Price adjustments | Competition, margin | Price book |

**Pain Points:**
1. **Multiple systems**: POS, inventory, scheduling separate
2. **Manual reporting**: Compile data manually
3. **Staff no-shows**: Last-minute schedule changes
4. **Stock visibility**: Don't know other store inventory

---

### 2. Cashier / Sales Associate

**Profile:**
- Chức danh: Cashier / Sales Associate
- Kinh nghiệm: Entry level
- Technical skill: Low to Medium
- Tần suất sử dụng hệ thống: Every transaction

**Daily Tasks:**
| Task | Frequency | Time Spent |
|------|-----------|------------|
| Process transactions | 50-200/day | 2-5 min each |
| Handle returns | 5-10/day | 5-10 min each |
| Customer service | Ongoing | Continuous |
| Stock shelves | As needed | 1-2 hours |
| Clean/organize | Daily | 30 min |

**Key Information Needed:**
- Product prices
- Promotions/discounts
- Customer loyalty info
- Inventory location
- Return policy

**Pain Points:**
1. **Slow POS**: System lag during checkout
2. **Complex discounts**: Hard to apply promotions
3. **Payment issues**: Card declines, system errors
4. **Customer questions**: Can't find product info

---

### 3. District/Regional Manager

**Profile:**
- Chức danh: District Manager / Area Manager
- Kinh nghiệm: Senior level
- Technical skill: Medium to High
- Tần suất sử dụng hệ thống: Daily (4-6 hours)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Review store performance | Daily | 1-2 hours | Critical |
| Visit stores | 2-3/week | Half day each | High |
| Conduct training | Weekly | 2-4 hours | Medium |
| Handle escalations | As needed | Variable | High |
| Strategic planning | Weekly | 2-3 hours | High |

**Key Decisions:**
| Decision | Based On | System Support |
|----------|----------|----------------|
| Store staffing levels | Sales volume | Analytics |
| Inventory allocation | Sell-through rates | Allocation tool |
| Performance actions | KPIs | Scorecards |

**Pain Points:**
1. **Data lag**: Reports not real-time
2. **Store comparison**: Hard to compare performance
3. **Visit documentation**: Manual notes
4. **Communication**: Info not reaching stores

---

### 4. Inventory Planner

**Profile:**
- Chức danh: Inventory Planner / Merchandise Planner
- Kinh nghiệm: Mid to Senior level
- Technical skill: High
- Tần suất sử dụng hệ thống: Daily (full day)

**Daily Tasks:**
| Task | Frequency | Time Spent |
|------|-----------|------------|
| Review stock levels | Daily | 1 hour |
| Create purchase orders | Multiple/week | 2-3 hours |
| Analyze sell-through | Daily | 1 hour |
| Manage transfers | Daily | 1 hour |
| Forecast demand | Weekly | 2-3 hours |

**Key Decisions:**
| Decision | Based On | System Support |
|----------|----------|----------------|
| Reorder quantities | Sales velocity, lead time | Reorder calculator |
| Transfer between stores | Stock imbalances | Transfer suggestions |
| Markdown timing | Aging inventory | Markdown optimization |

---

### 5. Customer (Shopper)

**Profile:**
- Độ tuổi: All ages
- Technical skill: Varies
- Channel: In-store, online, app

**Shopping Behavior:**
| Phase | Actions | System Touchpoints |
|-------|---------|-------------------|
| Discovery | Browse, search | Signage, displays |
| Selection | Compare, try | Product info, fitting room |
| Purchase | Checkout | POS, payment |
| Post-purchase | Returns, service | Customer service |

**Pain Points:**
1. **Out of stock**: Item not available
2. **Long checkout**: Queues too long
3. **Price confusion**: Different prices online/in-store
4. **Returns process**: Complicated returns
5. **Staff availability**: Can't find help

---

## Store Operations Flow

### Opening Procedures

```
[Arrive 30 min before]
        │
        ▼
[Alarm/Security check]
        │
        ▼
[System boot-up]
        │
        ▼
[Count cash drawer]
        │
        ▼
[Review daily plan]
        │
        ▼
[Brief staff]
        │
        ▼
[Unlock doors]
```

### Closing Procedures

```
[Lock doors at close]
        │
        ▼
[Process remaining customers]
        │
        ▼
[Count cash drawers]
        │
        ▼
[Reconcile POS]
        │
        ▼
[Prepare deposit]
        │
        ▼
[Secure premises]
        │
        ▼
[System closeout]
```

---

## Quick Reference

| Persona | Primary Focus | Key Metric |
|---------|---------------|------------|
| Store Manager | Store performance | Sales, shrinkage |
| Cashier | Fast checkout | Transaction speed |
| District Manager | Multi-store | Comparable sales |
| Inventory Planner | Stock optimization | Turn rate, sell-through |
| Customer | Shopping experience | Satisfaction, NPS |
