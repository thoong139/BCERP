# Sales Domain - Pipeline Analytics & Forecasting

> **Domain**: Sales / Quản trị Bán hàng
> **Last Updated**: 2026-03-15
> **Nguồn**: Tổng hợp từ sales-pipeline-analyst (agency-agents)

---

## 1. Pipeline Velocity — Compound Metric quan trọng nhất

Đo tốc độ revenue chảy qua funnel. Backbone của cả forecasting lẫn coaching.

### Công thức

```
Pipeline Velocity = (Qualified Opportunities × Average Deal Size × Win Rate) / Sales Cycle Length
```

### 4 Biến số chẩn đoán

| Biến | Ý nghĩa | Phân tích khi thay đổi |
|------|---------|------------------------|
| **Qualified Opportunities** | Volume đầu vào pipeline | Declining top-of-funnel → ảnh hưởng revenue 2-3 quarters sau. Early warning signal sớm nhất. |
| **Average Deal Size** | Giá trị deal trung bình | Tăng = targeting tốt hơn hoặc scope creep. Giảm = discounting pressure hoặc market shift. Segment kỹ — blended avg ẩn problems. |
| **Win Rate** | Tỷ lệ thắng | Track theo stage, rep, segment, deal size, thời gian. Stage-level win rates cho thấy deal chết ở đâu. |
| **Sales Cycle Length** | Thời gian average | Dài ra = competitive pressure, buyer committee mở rộng, hoặc qualification gap. |

---

## 2. Pipeline Coverage & Health

### Coverage Ratio — Đủ pipeline để hit số?

```
Pipeline Coverage = Open Weighted Pipeline / Remaining Quota
```

| Loại business | Target Coverage |
|---------------|----------------|
| Mature, predictable | 3x |
| Growth-stage / new market | 4-5x |
| New rep ramping | 5x+ (win rate thấp hơn) |

### Quality-Adjusted Coverage

Coverage đơn thuần chưa đủ. Quality-adjusted discount pipeline theo:
- **Deal health score** (qualification depth)
- **Stage age** (stale deals)
- **Engagement signals** (active vs inactive)

> $5M pipeline với 20 stale, poorly qualified deals < $2M pipeline với 8 active, well-qualified opportunities.

---

## 3. Deal Health Scoring

Stage và close date KHÔNG phải forecast methodology. Deal health scoring kết hợp nhiều signal categories:

### 3.1 Qualification Depth (MEDDPICC-based)

| Criteria | Green (2) | Yellow (1) | Red (0) |
|----------|-----------|------------|---------|
| Metrics | Quantified, validated | Identified, unvalidated | Unknown |
| Economic Buyer | Engaged, accessible | Identified, no access | Unknown |
| Decision Criteria | Known, favorable | Known, neutral | Unknown |
| Decision Process | Fully mapped | Partially mapped | Unknown |
| Paper Process | Started, timeline known | Identified, not started | Unknown |
| Implicated Pain | Quantified business outcome | Stated need, no cost | Unknown |
| Champion | Tested, active | Identified, untested | Unknown |
| Competition | Mapped, positioned | Known, unpositioned | Unknown |

**Deals có <5/8 fields populated = underqualified. Late-stage underqualified deals = nguồn chính forecast miss.**

### 3.2 Engagement Intensity

| Signal | Positive | Red Flag |
|--------|----------|----------|
| Meeting frequency | Regular cadence | >14 ngày không activity ở late-stage |
| Stakeholder breadth | Multi-threaded (3+) | Single-threaded deals >$50K |
| Content engagement | Proposal viewed, docs opened | Không open sau 7 ngày |
| Contact pattern | Buyer-initiated (strongest signal) | Chỉ seller-initiated |

### 3.3 Progression Velocity

- Track stage progression vs benchmark median
- **Stalled deals = dying deals**
- Deal ở cùng stage >1.5x median stage duration → cần intervention hoặc pipeline removal

### Composite Score

```
Qualification Score: [N]/16
Engagement Score: [N]/10
Velocity Score: [N]/10
─────────────────────
Composite Deal Health: [N]/36

Recommendation: [Advance / Intervene / Nurture / Disqualify]
```

---

## 4. Forecasting Methodology

### Vượt qua Stage-Weighted Probability

| Method | Mô tả | Độ chính xác |
|--------|--------|--------------|
| **Stage-Weighted (CRM)** | Probability theo stage (Lead=10%, Proposal=50%...) | Thấp — probability CRM gán thường cao hơn thực tế |
| **Historical Conversion** | % deals ở mỗi stage thực sự closed, theo segment | Trung bình — base rate chính xác hơn |
| **Velocity-Adjusted** | Adjust probability theo tốc độ so với average | Tốt — deals nhanh hơn → probability cao hơn |
| **Engagement-Adjusted** | Multi-threaded, active deals close 2-3x rate so với single-threaded | Tốt — engagement là leading indicator |
| **Pattern Match** | So sánh profile deal hiện tại với historical won/lost | Tốt nhất — loại bỏ bias optimism |

### Forecast Categories

| Category | Confidence | Mô tả |
|----------|------------|-------|
| **Commit** | >90% | Deals có signed contracts hoặc verbal + evidence đủ |
| **Best Case** | >60% | Commit + high-velocity qualified deals |
| **Upside** | <60% | Best Case + early-stage high-potential |

### Output: Probability-weighted với confidence intervals

```
Commit:    $[X] (>90% confidence)
Best Case: $[X] (>60% confidence)
Upside:    $[X] (<60% confidence)

Risk Factors:
- [Risk cụ thể + quantified impact: "$X at risk if [condition]"]

Data Quality Caveat:
- [Deals chưa update >30 ngày: X deals, $Y value]
```

---

## 5. Leading vs Lagging Indicators

| Indicator Type | Metrics | Hành động |
|----------------|---------|-----------|
| **Leading** (act on these) | Activity volume, pipeline creation velocity, engagement signals | Predict problems 2-3 quarters trước |
| **Pipeline** (middle layer) | Coverage ratio, stage conversion, deal velocity | Diagnose hiện tại |
| **Lagging** (confirm only) | Revenue, win rate, cycle length | Confirm trends đã xảy ra |

> Diagnose tại earliest available signal. Đừng đợi lagging indicators confirm problem.

---

## 6. Stage Conversion Funnel Template

```
| Stage          | Deals In | Converted | Lost | Conversion Rate | Avg Days | Benchmark |
|----------------|----------|-----------|------|-----------------|----------|-----------|
| Discovery      | [N]      | [N]       | [N]  | [X]%            | [N]      | [N]       |
| Qualification  | [N]      | [N]       | [N]  | [X]%            | [N]      | [N]       |
| Evaluation     | [N]      | [N]       | [N]  | [X]%            | [N]      | [N]       |
| Proposal       | [N]      | [N]       | [N]  | [X]%            | [N]      | [N]       |
| Negotiation    | [N]      | [N]       | [N]  | [X]%            | [N]      | [N]       |
```

---

## 7. Pipeline Review Questions — Deal Inspection

| Câu hỏi | Chẩn đoán |
|----------|-----------|
| "Có gì thay đổi từ tuần trước?" | Momentum hay stall |
| "Lần cuối nói chuyện với Economic Buyer khi nào?" | Access hay assumption |
| "Champion nói gì về next steps?" | Coaching hay silence |
| "Buyer đang evaluate ai nữa?" | Competitive awareness hay blind spot |
| "Nếu họ không làm gì, chuyện gì xảy ra?" | Urgency hay convenience |
| "Paper process đã bắt đầu chưa?" | Timeline reality |
| "Event cụ thể nào driving timeline?" | Compelling event hay artificial deadline |

---

## 8. Intervention Recommendations

| Tình trạng deal | Recommended Action |
|-----------------|-------------------|
| Stalled >1.5x median, engagement low | Disqualify hoặc nurture |
| Single-threaded, >$50K | Multi-thread ngay — identify 2+ contacts |
| Late-stage, MEDDPICC <5/8 | Qualification blitz — fill gaps trong 14 ngày |
| No activity >14 ngày (late-stage) | Exec sponsor intervention |
| Coverage <2x cho quarter | Pipeline generation sprint |
| Win rate declining ở specific stage | Systemic process review |

---

## Quick Reference: Metrics Summary

| Category | Metric | Formula | Target |
|----------|--------|---------|--------|
| Velocity | Pipeline Velocity | Opps × Deal Size × Win Rate / Cycle | Track trend |
| Coverage | Pipeline Coverage | Weighted Pipeline / Remaining Quota | ≥3x |
| Quality | Deal Health Score | Qualification + Engagement + Velocity | ≥24/36 cho commit |
| Forecast | Forecast Accuracy | 1 - \|Actual - Forecast\| / Actual | >90% |
| Hygiene | Stale Pipeline % | Deals no activity >30d / Total | <10% |
