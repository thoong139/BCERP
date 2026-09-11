# Quality Excellence - Six Sigma Methodology

> **Domain**: Quality Excellence / Six Sigma & Statistical Process Control
> **Last Updated**: 2026-03-22
> **Nguồn**: ASQ Six Sigma Body of Knowledge, AIAG, Minitab documentation

---

## 1. DMAIC Methodology (Process Improvement)

DMAIC áp dụng khi cải thiện quy trình HIỆN CÓ đang có vấn đề (defects, variation, waste).

### D — Define

**Mục tiêu**: Xác định rõ vấn đề, phạm vi, và kỳ vọng của khách hàng.

| Deliverable | Mô tả |
|-------------|-------|
| Project Charter | Problem statement, goal statement, scope, team, timeline, financial benefit |
| SIPOC Diagram | Suppliers → Inputs → Process → Outputs → Customers (high-level map) |
| VOC Collection | Interviews, surveys, complaint data, benchmarking |
| CTQ Tree | VOC → Drivers → CTQ (Critical to Quality) requirements |

**Problem Statement format**: "Hiện tại [metric] là [baseline]. Mục tiêu là [target] vào [date], tạo ra [financial benefit]."

### M — Measure

**Mục tiêu**: Xác định baseline hiện tại và đảm bảo measurement system đáng tin cậy.

| Deliverable | Mô tả |
|-------------|-------|
| Process Map (detailed) | Value stream map hoặc swim-lane diagram |
| Data Collection Plan | What, where, who, how often, sample size |
| MSA / Gage R&R | Repeatability & Reproducibility study — %R&R < 10% acceptable, 10-30% marginal |
| Baseline Capability | Cp, Cpk, sigma level, DPMO của quy trình hiện tại |

### A — Analyze

**Mục tiêu**: Xác định nguyên nhân gốc của vấn đề.

| Tool | Ứng dụng |
|------|----------|
| Fishbone (Ishikawa) | Brainstorm causes theo 6M categories |
| 5 Whys | Drill down từ symptom → root cause (5 levels) |
| Pareto Chart | Xác định 20% causes gây ra 80% problems |
| Hypothesis Testing | T-test, ANOVA, Chi-square — confirm statistical significance |
| Correlation/Regression | X → Y relationships, predict output from inputs |
| Multi-Vari Chart | Visualize variation sources (within-part, part-to-part, time-to-time) |

### I — Improve

**Mục tiêu**: Phát triển và implement giải pháp cho root causes.

| Deliverable | Mô tả |
|-------------|-------|
| Solution Generation | Brainstorm, benchmarking, pilot options |
| Effort-Impact Matrix | 2×2 matrix: Quick wins (high impact, low effort) vs Major projects |
| Pilot Plan | Small-scale test: scope, duration, success criteria |
| Cost-Benefit Analysis | Investment vs. projected savings |
| Implementation Plan | Who, what, when, how — RACI chart |

### C — Control

**Mục tiêu**: Duy trì gains và transfer ownership về Process Owner.

| Deliverable | Mô tả |
|-------------|-------|
| Control Plan | What to monitor, frequency, method, reaction plan if out of control |
| SPC Charts | Real-time process monitoring with control limits |
| Updated SOPs | Procedures cập nhật với cải tiến mới |
| Response Plan | Nếu process vượt control limit → làm gì (step-by-step) |
| Project Handover | Transfer to Process Owner, 30/60/90 day check-in |

---

## 2. DMADV Methodology (Design for New Processes)

DMADV (Design for Six Sigma) áp dụng khi thiết kế quy trình hoặc sản phẩm MỚI.

| Phase | Key Activities | Output |
|-------|---------------|--------|
| **Define** | VOC, CTQ tree, project charter, business case | Approved charter, CTQs list |
| **Measure** | CTQ detailed requirements, benchmarking, target values | CTQ specifications, benchmarks |
| **Analyze** | Design alternatives, risk assessment, simulation | Preferred design concept |
| **Design** | Detailed design, prototype, DFMEA, pilot | Design documentation, FMEA |
| **Verify** | Pilot testing, capability verification, deployment plan | Verified design, deployment plan |

---

## 3. Process Capability

### Capability Indices

| Index | Formula | Measures |
|-------|---------|---------|
| **Cp** | (USL - LSL) / (6σ) | Potential capability — spread only, assumes centered |
| **Cpk** | min[(USL-μ)/(3σ), (μ-LSL)/(3σ)] | Actual capability — spread + centering |
| **Pp** | (USL - LSL) / (6s) | Performance index using overall std dev |
| **Ppk** | min[(USL-X̄)/(3s), (X̄-LSL)/(3s)] | Performance — long-term data |

### Sigma Level Conversion Table

| Sigma Level | Cpk | DPMO | Defect % | Classification |
|-------------|-----|------|----------|----------------|
| 1σ | 0.33 | 691,462 | 69.1% | Very poor |
| 2σ | 0.67 | 308,538 | 30.9% | Poor |
| 3σ | 1.00 | 66,807 | 6.7% | Baseline acceptable |
| 4σ | 1.33 | 6,210 | 0.62% | Industry average |
| 5σ | 1.67 | 233 | 0.023% | World class target |
| 6σ | 2.00 | 3.4 | 0.00034% | Six Sigma (với 1.5σ shift) |

**Thresholds thực tế:**
- Cpk ≥ 1.33 (4σ): Minimum acceptable cho production
- Cpk ≥ 1.67 (5σ): World class — target cho critical parameters
- Cpk < 1.00: Process không capable — improvement required

---

## 4. Statistical Process Control (SPC) Charts

### Variable Charts (dữ liệu đo được)

| Chart | Khi dùng | Subgroup size |
|-------|----------|---------------|
| **X-bar & R** | Subgroup mean + range | n = 2-10 |
| **X-bar & S** | Subgroup mean + std dev | n > 10 |
| **I-MR (Individual-Moving Range)** | Individual measurements, slow processes | n = 1 |

### Attribute Charts (dữ liệu đếm)

| Chart | Khi dùng | Subgroup |
|-------|----------|---------|
| **p-chart** | Proportion defective, variable subgroup size | Variable n |
| **np-chart** | Number defective, constant subgroup size | Constant n |
| **c-chart** | Count of defects per unit, constant area | Constant area |
| **u-chart** | Count of defects per unit, variable area | Variable area |

### Western Electric Control Rules (Nelson Rules)

| Rule | Signal |
|------|--------|
| Rule 1 | 1 point > 3σ from CL (beyond control limits) |
| Rule 2 | 9 consecutive points same side of CL |
| Rule 3 | 6 consecutive points trending (increasing/decreasing) |
| Rule 4 | 14 alternating points up/down |
| Rule 5 | 2 of 3 points > 2σ same side of CL |
| Rule 6 | 4 of 5 points > 1σ same side of CL |

---

## 5. Key Tools Quick Reference

### VOC Collection Methods

| Method | Best for | Limitation |
|--------|----------|------------|
| Customer interviews (structured) | Deep insight, qualitative | Time-intensive, small n |
| Surveys (quantitative) | Large n, statistically significant | Surface level |
| Complaint/return analysis | Real problems, already occurred | Reactive, lagging |
| Observation (Gemba) | Tacit knowledge, process reality | Observer effect |
| Benchmarking | Industry best practice | May not apply to context |

### CTQ Tree Structure

```
VOC (verbatim)
  └── Driver 1 (needs category)
        ├── CTQ 1.1: [measurable spec]
        └── CTQ 1.2: [measurable spec]
  └── Driver 2
        └── CTQ 2.1: [measurable spec]
```

### SIPOC Template

| Suppliers | Inputs | Process | Outputs | Customers |
|-----------|--------|---------|---------|-----------|
| Who provides inputs? | What goes in? | High-level steps (5-7) | What comes out? | Who receives? |

### Fishbone Categories (6M)

| Category | Examples |
|----------|---------|
| **Man** | Training, skills, fatigue, human error |
| **Machine** | Equipment condition, calibration, tooling |
| **Method** | SOP, work instruction, process sequence |
| **Material** | Incoming quality, specification, supplier |
| **Measurement** | Gage accuracy, measurement method, sampling |
| **Mother Nature** | Temperature, humidity, environment |

### Pareto Analysis Steps

1. List all failure modes/defect types
2. Count frequency of each
3. Sort descending
4. Calculate cumulative %
5. Plot bar chart + cumulative line
6. Identify top 20% causes → 80% of problems
