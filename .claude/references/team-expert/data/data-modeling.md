# Data Modeling Reference

> Reference file cho data-expert agent
> Load file này khi cần thiết kế data model trong domain Data

## Dimensional Modeling Concepts

### Fact Tables

| Type | Description | Grain Example |
|------|-------------|---------------|
| Transactional | One row per transaction | Each order line |
| Periodic Snapshot | One row per period | Daily inventory balance |
| Accumulating Snapshot | One row per process | Order fulfillment lifecycle |

**Fact Table Columns:**
- Foreign keys to dimensions
- Measures (numeric values)
- Degenerate dimensions (transaction IDs)

### Dimension Tables

| Type | Description | Examples |
|------|-------------|----------|
| Conformed | Shared across data marts | Date, Customer, Product |
| Junk | Small flags/indicators | Yes/No flags |
| Degenerate | No separate dimension | Transaction number |
| Role-Playing | Same dim used multiple ways | Order Date, Ship Date |
| Slowly Changing (SCD) | Tracks changes over time | Customer address |

### SCD Types

| Type | Description | When to Use |
|------|-------------|-------------|
| Type 0 | Never changes | Original value |
| Type 1 | Overwrite | Corrections, no history needed |
| Type 2 | Add new row | Full history tracking |
| Type 3 | Add new column | Current + previous |
| Type 4 | History table | Separate history |

---

## Star Schema

```
               ┌─────────────┐
               │   Product   │
               │  Dimension  │
               └──────┬──────┘
                      │
┌─────────────┐       │       ┌─────────────┐
│  Customer   │       │       │    Date     │
│  Dimension  │───────┼───────│  Dimension  │
└─────────────┘       │       └─────────────┘
                      │
               ┌──────┴──────┐
               │ Sales Fact  │
               │    Table    │
               └──────┬──────┘
                      │
┌─────────────┐       │       ┌─────────────┐
│    Store    │       │       │ Promotion   │
│  Dimension  │───────┼───────│  Dimension  │
└─────────────┘       │       └─────────────┘
                      │
               ┌──────┴──────┐
               │  Geography  │
               │  Dimension  │
               └─────────────┘
```

---

## Common Dimensions

### Date Dimension

| Column | Description | Example |
|--------|-------------|---------|
| date_key | Surrogate key | 20240315 |
| full_date | Actual date | 2024-03-15 |
| day_name | Day of week | Friday |
| day_of_week | 1-7 | 5 |
| day_of_month | 1-31 | 15 |
| week_of_year | 1-52 | 11 |
| month | 1-12 | 3 |
| month_name | Month name | March |
| quarter | Q1-Q4 | Q1 |
| year | Year | 2024 |
| fiscal_year | Fiscal year | FY2024 |
| is_weekend | Boolean | false |
| is_holiday | Boolean | false |

### Customer Dimension

| Column | Description | SCD Type |
|--------|-------------|----------|
| customer_key | Surrogate key | N/A |
| customer_id | Natural key | Type 0 |
| name | Full name | Type 1 |
| email | Email address | Type 1 |
| address | Current address | Type 2 |
| segment | Customer segment | Type 2 |
| signup_date | Registration date | Type 0 |

### Product Dimension

| Column | Description | SCD Type |
|--------|-------------|----------|
| product_key | Surrogate key | N/A |
| product_id | SKU | Type 0 |
| name | Product name | Type 1 |
| category | Product category | Type 2 |
| subcategory | Sub-category | Type 2 |
| brand | Brand name | Type 1 |
| status | Active/Inactive | Type 2 |

---

## Measure Types

### Additive Measures
Can be summed across all dimensions
- Revenue
- Quantity sold
- Cost

### Semi-Additive Measures
Can be summed across some dimensions
- Inventory balance (sum across products, not time)
- Account balance (sum across accounts, not time)

### Non-Additive Measures
Cannot be summed (must be averaged)
- Unit price
- Temperature
- Percentage

---

## Data Warehouse Architecture

### Kimball Approach (Bottom-Up)

```
┌─────────────────────────────────────────────┐
│           DATA PRESENTATION                  │
│   BI Tools │ Reports │ Dashboards │ ML      │
├─────────────────────────────────────────────┤
│           DATA MARTS                         │
│  Sales │ Marketing │ Finance │ Operations   │
├─────────────────────────────────────────────┤
│           DATA WAREHOUSE                     │
│        Conformed Dimensions                 │
├─────────────────────────────────────────────┤
│           ETL / STAGING                      │
│  Extract │ Transform │ Load                 │
├─────────────────────────────────────────────┤
│           SOURCE SYSTEMS                     │
│  ERP │ CRM │ Web │ External                │
└─────────────────────────────────────────────┘
```

### Data Vault Approach

| Component | Description |
|-----------|-------------|
| Hub | Business keys (Customer ID, Product ID) |
| Link | Relationships between hubs |
| Satellite | Descriptive attributes |

---

## ETL Design Patterns

### Full Load vs Incremental

| Pattern | When to Use | Complexity |
|---------|-------------|------------|
| Full Load | Small tables, one-time load | Low |
| Incremental | Large tables, frequent updates | Medium |
| CDC (Change Data Capture) | Real-time requirements | High |

### Data Quality Checks

| Check | Description | Action |
|-------|-------------|--------|
| Completeness | Missing values | Reject or default |
| Accuracy | Valid values | Reject |
| Consistency | Cross-reference match | Flag for review |
| Timeliness | Data freshness check | Alert if stale |
| Uniqueness | Duplicate detection | Deduplicate |

---

## Example: Sales Data Model

### Fact Sales

```sql
CREATE TABLE fact_sales (
    sales_key        BIGINT PRIMARY KEY,
    date_key         INT NOT NULL,
    customer_key     INT NOT NULL,
    product_key      INT NOT NULL,
    store_key        INT NOT NULL,
    promotion_key    INT NOT NULL,
    quantity         INT,
    unit_price       DECIMAL(10,2),
    extended_price   DECIMAL(12,2),
    discount_amount  DECIMAL(10,2),
    net_sales        DECIMAL(12,2),
    cost             DECIMAL(12,2),
    margin           DECIMAL(12,2)
);
```

### Dimension Relationships

```
fact_sales
    ├── dim_date (date_key)
    ├── dim_customer (customer_key)
    ├── dim_product (product_key)
    ├── dim_store (store_key)
    │       └── dim_geography (geography_key)
    └── dim_promotion (promotion_key)
```
