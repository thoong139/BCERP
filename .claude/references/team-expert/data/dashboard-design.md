# Dashboard Design Reference

> Reference file cho data-expert agent
> Load file này khi cần thiết kế dashboard trong domain Data

## Dashboard Design Principles

### Core Principles

| Principle | Description |
|-----------|-------------|
| Purpose-driven | Clear business objective |
| User-centric | Designed for specific audience |
| Scanability | Key info visible at a glance |
| Context | Comparisons, trends, targets |
| Actionable | Drives decisions |

### The 5-Second Rule
Users should understand the main message within 5 seconds.

---

## Dashboard Layout Patterns

### Executive Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│  HEADER: Title │ Filters │ Time Period │ Refresh           │
├───────────────┬───────────────┬───────────────┬─────────────┤
│   KPI Card    │   KPI Card    │   KPI Card    │  KPI Card   │
│   Revenue     │   Profit      │   Customers   │  NPS        │
├───────────────┴───────────────┴───────────────┴─────────────┤
│                                                              │
│              MAIN TREND CHART (Revenue over time)            │
│                                                              │
├────────────────────────────┬─────────────────────────────────┤
│    TOP 10 SEGMENT CHART    │    REGIONAL MAP / CHART         │
│    (Horizontal bar)        │    (Map or bar)                 │
├────────────────────────────┼─────────────────────────────────┤
│    CATEGORY BREAKDOWN      │    ALERTS / EXCEPTIONS          │
│    (Donut or treemap)      │    (Table with highlights)      │
└────────────────────────────┴─────────────────────────────────┘
```

### Operational Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│  HEADER: Title │ Auto-refresh │ Status indicator            │
├───────────────┬───────────────┬───────────────┬─────────────┤
│   GAUGE 1     │   GAUGE 2     │   GAUGE 3     │  GAUGE 4    │
│   (Current)   │   (Current)   │   (Current)   │  (Current)  │
├───────────────┴───────────────┴───────────────┴─────────────┤
│  REAL-TIME ACTIVITY FEED / TRANSACTION LIST                 │
├─────────────────────────────────────────────────────────────┤
│  TREND SPARKLINES (Multiple small trend charts)             │
├────────────────────────────┬────────────────────────────────┤
│    ALERTS / EXCEPTIONS     │    QUEUE STATUS                │
│    (Highlighted items)     │    (Stacked bar)               │
└────────────────────────────┴────────────────────────────────┘
```

### Analytical Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│  HEADER: Title │ Extensive Filters │ Export                │
├─────────────────────────────────────────────────────────────┤
│  KEY METRICS WITH COMPARISONS (vs target, vs last period)  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│              PRIMARY ANALYSIS CHART (Interactive)            │
│              (Supports drill-down, zoom, hover details)      │
│                                                              │
├────────────────────────────┬────────────────────────────────┤
│    SECONDARY ANALYSIS      │    CROSS-TAB / PIVOT           │
│    (Different dimension)    │    (Detailed breakdown)        │
├────────────────────────────┴────────────────────────────────┤
│  DETAILED DATA TABLE (Sortable, filterable, exportable)     │
└─────────────────────────────────────────────────────────────┘
```

---

## Chart Selection Guide

### By Data Relationship

| Relationship | Best Charts | Example |
|--------------|-------------|---------|
| Comparison | Bar, Column, Table | Sales by region |
| Trend | Line, Area, Sparkline | Revenue over time |
| Part-to-whole | Pie, Donut, Treemap | Budget allocation |
| Distribution | Histogram, Box plot | Customer age groups |
| Correlation | Scatter, Bubble | Price vs quantity |
| Geographic | Map, Choropleth | Sales by country |
| Ranking | Sorted bar, Table | Top products |
| Deviation | Waterfall, Diverging bar | Budget variance |

### By Data Type

| Data Type | Recommended | Avoid |
|-----------|-------------|-------|
| Categorical | Bar, Column | Pie (>5 categories) |
| Time series | Line, Area | Scatter |
| Numerical range | Histogram | Pie |
| Geographic | Map | 3D charts |

---

## Color Guidelines

### Color Usage

| Purpose | Color Approach |
|---------|----------------|
| Sequential | Light to dark of same hue |
| Diverging | Two hues meeting in middle |
| Categorical | Distinct colors, colorblind-safe |
| Highlight | One accent color for emphasis |
| Alert | Red (bad), Yellow (warning), Green (good) |

### Color Accessibility

- Use colorblind-safe palettes
- Don't rely on color alone (use patterns, labels)
- Ensure sufficient contrast
- Test with grayscale

---

## KPI Card Design

### Standard KPI Card

```
┌─────────────────────────┐
│      KPI NAME           │
│      $1,234,567         │  ← Primary value (large)
│   ▲ +12.3% vs LM        │  ← Comparison (smaller)
│   Target: $1,100,000    │  ← Target/Context
│   ████████░░ 89%        │  ← Progress (optional)
└─────────────────────────┘
```

### Sparkline KPI Card

```
┌─────────────────────────┐
│ Revenue       $1.2M ▲5% │
│ ╱╲╱╲╱╲╱╲╱╲╱╲           │  ← Mini trend
└─────────────────────────┘
```

---

## Interactivity Guidelines

### Essential Interactions

| Interaction | Purpose |
|-------------|---------|
| Filter | Focus on specific data |
| Drill-down | See more detail |
| Hover tooltip | Show exact values |
| Sort | Rank by importance |
| Export | Take data offline |

### Progressive Disclosure

1. **Level 1**: Summary KPIs
2. **Level 2**: Trend charts
3. **Level 3**: Detailed tables
4. **Level 4**: Raw data export

---

## Dashboard Types by Audience

### Executive (C-Suite)
- High-level KPIs
- Trend indicators
- Exception alerts
- Strategic metrics
- Update: Daily/Weekly

### Manager
- Team/department metrics
- Comparison to targets
- Drill-down capability
- Actionable insights
- Update: Daily

### Analyst
- Full data access
- Advanced filtering
- Multiple views
- Export capability
- Update: Real-time/Hourly

### Operational
- Real-time metrics
- Status indicators
- Alert thresholds
- Queue monitoring
- Update: Real-time

---

## Common Dashboard Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Too many charts | Overwhelming | Focus on key metrics |
| 3D effects | Distorts data | Use 2D |
| Too many colors | Confusing | Limit to 5-7 colors |
| No context | Meaning unclear | Add comparisons |
| Fixed time only | No trends | Add historical data |
| Cluttered layout | Hard to scan | Use white space |
| No hierarchy | Everything equal | Size by importance |

---

## Dashboard Checklist

### Before Launch

- [ ] Clear business objective defined
- [ ] Target audience identified
- [ ] Key metrics selected (not too many)
- [ ] Appropriate charts chosen
- [ ] Color scheme accessible
- [ ] Mobile/responsive tested
- [ ] Performance acceptable (<5s load)
- [ ] Data accuracy verified
- [ ] User acceptance tested
- [ ] Documentation provided
