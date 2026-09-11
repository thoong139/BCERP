# Quality Excellence - Quality Metrics & KPIs

> **Domain**: Quality Excellence / Quality Metrics, KPIs & Cost of Quality
> **Last Updated**: 2026-03-22
> **Nguồn**: ASQ Quality Metrics, APQC benchmarks, Six Sigma Body of Knowledge

---

## 1. Defect Metrics

### Core Defect Calculations

| Metric | Formula | Notes |
|--------|---------|-------|
| **DPM** (Defects Per Million) | (Total Defects / Total Units) × 1,000,000 | Simple, doesn't account for complexity |
| **DPO** (Defects Per Opportunity) | Total Defects / (Total Units × Opportunities Per Unit) | Normalizes for complexity |
| **DPMO** | DPO × 1,000,000 | Standard Six Sigma metric |
| **FPY** (First Pass Yield) | Units passing first time / Total units started | Single process step |
| **RTY** (Rolled Throughput Yield) | FPY₁ × FPY₂ × ... × FPYₙ | Across entire process chain |

### FPY vs RTY Example

```
Process: 3 steps, each 95% FPY

FPY step 1 = 95%
FPY step 2 = 95%
FPY step 3 = 95%

RTY = 0.95 × 0.95 × 0.95 = 0.857 (85.7%)
→ 14.3% of units require rework somewhere — even though each step looks "fine"
```

### Sigma Level from DPMO

| DPMO | Sigma Level | Industry Context |
|------|-------------|-----------------|
| > 500,000 | < 1.5σ | Critical — immediate action |
| 308,538 | 2σ | Very poor |
| 66,807 | 3σ | Acceptable baseline |
| 6,210 | 4σ | Industry average (good) |
| 233 | 5σ | World class |
| 3.4 | 6σ | Six Sigma standard |

---

## 2. Process Performance Metrics

### Manufacturing Process

| Metric | Formula | World Class Target |
|--------|---------|-------------------|
| **OEE** (Overall Equipment Effectiveness) | Availability × Performance × Quality | ≥ 85% |
| Availability | (Planned time - Downtime) / Planned time | ≥ 90% |
| Performance | (Actual output / Theoretical output) | ≥ 95% |
| Quality Rate | Good units / Total units produced | ≥ 99.5% |
| **Cycle Time** | Total time to complete 1 unit | Minimize |
| **Throughput** | Units per time period | Maximize |
| **WIP** | Work-in-process inventory level | Minimize (lean) |

### Service/Software Process

| Metric | Formula | Target |
|--------|---------|--------|
| **Defect Escape Rate** | Defects found in production / Total defects | < 5% |
| **Defect Removal Efficiency** | Defects found before release / Total defects | > 95% |
| **Test Coverage** | Lines/branches tested / Total lines/branches | > 80% |
| **Mean Time to Resolution (MTTR)** | Total downtime / Number of incidents | Minimize |
| **Release Quality Rate** | Clean releases / Total releases | > 90% |

### Lead Time Reduction Targets (Lean Six Sigma)

| Process Type | Typical Improvement Target | Approach |
|-------------|--------------------------|----------|
| NCR cycle time | Reduce 30-50% | DMAIC |
| CAPA closure time | Reduce 25-40% | DMAIC |
| Internal audit cycle | Reduce 20-30% | Process simplification |
| Document approval | Reduce 50-70% | Digital workflow |

---

## 3. Cost of Quality (CoQ)

### Four CoQ Categories

**Prevention Costs** — Đầu tư để ngăn defect xảy ra:
- Quality planning and QMS development
- Training (quality-related)
- Process and product design review
- Supplier qualification and development
- FMEA, mistake-proofing (poka-yoke)
- Calibration planning
- Preventive maintenance

**Appraisal Costs** — Chi phí kiểm tra và đo lường:
- Incoming inspection
- In-process inspection and testing
- Final inspection and testing
- Product audits
- Calibration and measurement equipment
- Laboratory testing (external)

**Internal Failure Costs** — Lỗi phát hiện trước khi đến customer:
- Scrap (material + labor lost)
- Rework and repair
- Re-inspection after rework
- Failure analysis (internal)
- Downtime caused by defects
- Design changes due to quality issues

**External Failure Costs** — Lỗi đến tay customer:
- Customer complaints handling
- Warranty repairs and replacements
- Returns and recalls
- Product liability, legal costs
- Customer concessions/discounts
- Lost sales due to reputation damage

### CoQ Tracking Template

| Category | Sub-category | Monthly Cost (VND) | % of Revenue |
|----------|-------------|---------------------|-------------|
| Prevention | Training | | |
| Prevention | Process design | | |
| Appraisal | Incoming inspection | | |
| Appraisal | Lab testing | | |
| Internal Failure | Scrap | | |
| Internal Failure | Rework | | |
| External Failure | Warranty | | |
| External Failure | Returns | | |
| **TOTAL CoQ** | | | |

### CoQ Benchmarks

| CoQ Level | % of Revenue | Classification |
|-----------|-------------|----------------|
| ≤ 5% | World class | Excellent (mature QMS) |
| 6-10% | Industry average good | Solid QMS |
| 11-15% | Industry average | Improvement needed |
| > 20% | Poor | Quality crisis — immediate action |

**1:10:100 Rule (prevention vs failure costs):**
- $1 spent in prevention = $10 saved in appraisal = $100 saved in failure costs

---

## 4. Customer Quality Metrics

| Metric | Formula | Target (General) |
|--------|---------|-----------------|
| **Customer Complaint Rate** | Complaints / (Total units or transactions) × 1,000 | < 3 per 1,000 |
| **Warranty Return Rate** | Returns / Units shipped × 100% | < 0.5% |
| **Customer DPPM** | Defects reported by customer / (Units shipped × 1,000,000) | < 500 DPPM |
| **CSAT (Quality-related)** | Quality satisfaction score from survey | > 4.0 / 5.0 |
| **Repeat Complaint Rate** | Same defect type recurring / All complaints | < 5% |

---

## 5. QMS KPI Dashboard

### KPI Master Table

| KPI | Formula | Green | Amber | Red | Frequency |
|-----|---------|-------|-------|-----|-----------|
| NCR Closure Rate on Time | Closed on time / Total NCR × 100% | ≥ 90% | 75-90% | < 75% | Monthly |
| CAPA Effectiveness Rate | CAPAs with no recurrence / Total closed × 100% | ≥ 95% | 85-95% | < 85% | Quarterly |
| Audit Completion Rate | Audits completed / Planned × 100% | ≥ 100% | 85-99% | < 85% | Quarterly |
| CAPA On-Time Closure | Closed by due date / Total CAPA × 100% | ≥ 90% | 75-90% | < 75% | Monthly |
| Quality Training Completion | Staff trained / Total staff × 100% | ≥ 95% | 80-95% | < 80% | Quarterly |
| Supplier Incoming Defect Rate | Defective lots / Total lots received × 100% | < 1% | 1-3% | > 3% | Monthly |
| Customer Quality Complaints | Count | 0 | 1-2 | ≥ 3 | Monthly |
| Internal Audit Major Findings | Count | 0 | 1-2 | ≥ 3 | Per audit |
| FMEA Review Completion | FMEA reviewed on schedule / Total FMEA | ≥ 100% | 80-99% | < 80% | Annually |
| Management Review Completion | Reviews held / Scheduled | 100% | — | < 100% | Annually |

### Dashboard Layout Recommendation

```
Row 1: Overall Quality Score | CoQ % Revenue | Sigma Level (process)
Row 2: NCR Open Count (aging chart) | CAPA Status (pie: open/pending/closed)
Row 3: Audit Findings by Clause (bar) | Customer Complaints Trend (line)
Row 4: Top 5 Defect Types (Pareto) | FMEA High-RPN Items (table)
```

### NCR Aging Thresholds

| Age | Classification | Action |
|-----|---------------|--------|
| 0-7 days | Normal | Track |
| 8-14 days | Attention | Reminder to owner |
| 15-30 days | Warning (amber) | Escalate to Quality Manager |
| > 30 days | Critical (red) | Escalate to Quality Director |

### CAPA Response Time Standards

| Severity | Initial Response | Root Cause Analysis | Action Plan Due | Closure Target |
|---------|-----------------|---------------------|-----------------|----------------|
| Critical | 24 hours | 48 hours | 5 business days | 30 days |
| Major | 3 business days | 7 business days | 14 business days | 60 days |
| Minor | 7 business days | 14 business days | 21 business days | 90 days |
