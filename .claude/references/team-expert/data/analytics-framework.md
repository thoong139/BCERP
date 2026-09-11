# Analytics Framework Reference

> Reference file cho data-expert agent
> Load file này khi cần hiểu về analytics trong domain Data

## Analytics Maturity Model

```
Level 5: PRESCRIPTIVE
    └── Optimization, simulation, decision support
    └── "What should we do?"

Level 4: PREDICTIVE
    └── Forecasting, ML models, predictive analytics
    └── "What will happen?"

Level 3: DIAGNOSTIC
    └── Drill-down, root cause, correlation analysis
    └── "Why did it happen?"

Level 2: DESCRIPTIVE
    └── Reports, dashboards, basic visualizations
    └── "What happened?"

Level 1: ADHOC
    └── Spreadsheets, manual reports
    └── Basic data access
```

---

## Business Question Framework

### Question Types

| Type | Question | Analysis Method |
|------|----------|-----------------|
| Status | What is current state? | KPI cards, gauges |
| Trend | How are we tracking? | Line charts, area charts |
| Comparison | How do things compare? | Bar charts, tables |
| Distribution | How is data spread? | Histograms, box plots |
| Composition | What makes up the whole? | Pie, stacked bar, treemap |
| Relationship | How do variables relate? | Scatter, bubble, heatmap |
| Ranking | What are top/bottom? | Sorted bars, tables |
| Geographic | Where is it happening? | Maps, choropleth |

### Question Template

```
Business Question: [What do we want to know?]
Decision: [What decision will this inform?]
Audience: [Who will use this insight?]
Frequency: [How often is this needed?]
Data: [What data is required?]
Success: [How will we know if answer is useful?]
```

---

## KPI Framework

### SMART KPI Criteria

| Element | Description | Check |
|---------|-------------|-------|
| Specific | Clear, well-defined | Is it unambiguous? |
| Measurable | Quantifiable | Can we measure it? |
| Achievable | Realistic target | Is it attainable? |
| Relevant | Aligned to goals | Does it matter? |
| Time-bound | Has deadline | What's the timeframe? |

### KPI Categories

| Category | Focus | Examples |
|----------|-------|----------|
| Financial | Money | Revenue, Profit, ROI, Cost |
| Customer | Satisfaction | NPS, CSAT, Retention, LTV |
| Process | Efficiency | Cycle time, Error rate, Throughput |
| People | Workforce | Engagement, Turnover, Productivity |
| Growth | Expansion | Market share, New customers |

### KPI Design Template

```
KPI Name: [Clear, descriptive name]
Definition: [How is it calculated?]
Formula: [Exact calculation]
Data Source: [Where does data come from?]
Frequency: [How often measured?]
Target: [What's the goal?]
Owner: [Who's responsible?]
Thresholds:
  - Green: [Excellent threshold]
  - Yellow: [Warning threshold]
  - Red: [Critical threshold]
```

---

## Metrics Hierarchy

### From Strategy to Operations

```
STRATEGIC (Executive)
    └── Revenue Growth, Market Share, ROI
        │
TACTICAL (Management)
    └── Sales by Region, Customer Acquisition Cost
        │
OPERATIONAL (Frontline)
    └── Daily Sales, Website Traffic, Support Tickets
```

### Leading vs Lagging Indicators

| Type | Description | Examples |
|------|-------------|----------|
| Leading | Predict future outcomes | Pipeline value, Website traffic |
| Lagging | Measure past performance | Revenue, Profit, Churn rate |

---

## Analytics Use Cases by Domain

### Sales Analytics

| Question | Metric | Visualization |
|----------|--------|---------------|
| How are sales trending? | Revenue over time | Line chart |
| Who are top performers? | Sales by rep | Bar chart |
| What's in the pipeline? | Pipeline by stage | Funnel |
| Where are deals stuck? | Stage duration | Bar chart |

### Marketing Analytics

| Question | Metric | Visualization |
|----------|--------|---------------|
| Which channels perform? | Conversion by channel | Bar chart |
| What's campaign ROI? | Cost per acquisition | Table |
| How's website traffic? | Visitors, page views | Line chart |
| Who's the audience? | Demographics | Pie charts |

### Finance Analytics

| Question | Metric | Visualization |
|----------|--------|---------------|
| What's our cash position? | Cash balance | KPI card |
| How's budget vs actual? | Variance | Waterfall |
| What are top expenses? | Expense categories | Treemap |
| How's AR aging? | Aging buckets | Stacked bar |

### Operations Analytics

| Question | Metric | Visualization |
|----------|--------|---------------|
| How efficient is production? | OEE | Gauge |
| What's inventory status? | Stock levels | Table |
| Where are bottlenecks? | Cycle times | Bar chart |
| How's quality? | Defect rate | Control chart |

---

## Data Requirements Checklist

### For Each Analytics Request

- [ ] Business question clearly defined
- [ ] Decision maker identified
- [ ] Required metrics defined
- [ ] Data sources identified
- [ ] Data quality assessed
- [ ] Refresh frequency determined
- [ ] Access/security requirements
- [ ] Visualization preferences
- [ ] Success criteria defined

---

## Common Analytics Patterns

### Cohort Analysis
Track behavior of groups over time
```
Sign-up Month │ Month 1 │ Month 2 │ Month 3 │
──────────────┼─────────┼─────────┼─────────┤
Jan 2024      │  100%   │   85%   │   72%   │
Feb 2024      │  100%   │   88%   │   75%   │
Mar 2024      │  100%   │   90%   │   78%   │
```

### Funnel Analysis
Track conversion through stages
```
Visitors    →  100,000
Product View →   45,000 (45%)
Add to Cart  →   15,000 (33%)
Checkout     →    8,000 (53%)
Purchase     →    5,000 (63%)
```

### Trend Analysis
Identify patterns over time
- Seasonality
- Growth rate
- Anomalies
- Cycles

### Segmentation
Group data for insights
- By demographics
- By behavior
- By value
- By geography
