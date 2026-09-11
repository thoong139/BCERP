# Procedure: Design Six Sigma Process Improvement Initiative

> **Type**: Agent Procedure
> **Agent**: quality-excellence-expert
> **Triggered when**: Yêu cầu phân tích và cải tiến quy trình cụ thể (DMAIC approach)
> **Output**: DMAIC project charter, current state analysis, root cause analysis, improvement recommendations, control plan

---

## Khi nào dùng procedure này

- User/skill yêu cầu phân tích một quy trình cụ thể đang có vấn đề
- Dự án có module "Process Improvement", "Continuous Improvement", "Six Sigma"
- Keyword: "giảm defect", "cải tiến quy trình", "DMAIC", "root cause", "process improvement"
- Onboard project: hiện có Six Sigma program cần được digitized

---

## Procedure

### Bước 1: Define — Tạo Project Charter

Đọc problem statement từ user hoặc từ project context.

Tạo Project Charter:

```
Project Charter Template:
  Project Name      : [Tên mô tả vấn đề]
  Business Case     : Tại sao dự án này quan trọng? (cost, quality, customer impact)
  Problem Statement : "[Metric] hiện tại là [baseline value]. Gây ra [impact] cho [customer/business]."
  Goal Statement    : "Giảm [metric] từ [current] xuống [target] vào [date], tiết kiệm [financial benefit]."
  Scope             : In-scope: [process steps included]. Out-of-scope: [explicitly excluded]
  Project Team      : Champion: [name], BB/GB: [name], Team: [names, departments]
  Timeline          : Define: [date], Measure: [date], Analyze: [date], Improve: [date], Control: [date]
  Financial Benefit : [Estimated savings — hard or soft]
```

### Bước 2: Define — SIPOC và VOC

READ `.claude/references/team-expert/quality-excellence/six-sigma.md`

Từ SIPOC Template (Section 5), tạo SIPOC cho quy trình:

```
SIPOC:
  Suppliers  : [Ai/gì cung cấp inputs?]
  Inputs     : [Raw materials, information, resources vào quy trình]
  Process    : [5-7 high-level steps — KHÔNG quá chi tiết ở Define phase]
  Outputs    : [Sản phẩm/kết quả của quy trình]
  Customers  : [Ai nhận outputs? Internal + External]
```

Từ VOC Collection Methods (Section 5), xác định VOC sources hiện có:
- Customer complaints: themes nào nổi bật?
- Survey/feedback data: satisfaction drivers?
- Internal data: which defect types most frequent?

Chuyển VOC → CTQ Tree: Mỗi VOC → driver → CTQ requirement đo được.

### Bước 3: Measure — Data Collection Plan

READ `.claude/references/team-expert/quality-excellence/six-sigma.md` (Section 1 — Measure)

Tạo Data Collection Plan:

```
Data Collection Plan:
  | What to Measure | Where | Who Collects | How (instrument) | Frequency | Sample Size | Format |
  |-----------------|-------|-------------|-----------------|-----------|-------------|--------|
  | [CTQ metric]    | [location] | [role] | [method] | [daily/weekly] | [n=?] | [form/system] |
```

Xác định Measurement System Analysis (MSA) needs:
- Nếu measurement là subjective (visual inspection) → Gage R&R required
- Nếu measurement là automated/instrumental → calibration verification

Baseline capability:
- Collect data → calculate Cp, Cpk, sigma level, DPMO
- Từ Sigma Level Conversion Table (Section 3): classify current state

### Bước 4: Analyze — Root Cause Analysis

Với data đã có (hoặc representative data từ problem description):

**Step A: Fishbone Diagram**

READ `.claude/references/team-expert/quality-excellence/six-sigma.md` (6M categories)

Tạo Fishbone cho primary failure mode:
```
Fishbone — [Primary failure mode]:
  Man        : [Potential causes related to people]
  Machine    : [Equipment, tooling]
  Method     : [Process, procedure, SOP gaps]
  Material   : [Input quality, specification]
  Measurement: [Measurement error, sampling error]
  Mother Nature: [Environment factors]
```

**Step B: Pareto Analysis**

Nếu có multiple failure modes/defect types:
- List và rank by frequency
- Calculate cumulative percentage
- Identify top 20% causes → 80% problems
- Output: prioritized list of root causes to address

**Step C: 5 Whys cho top root causes**

```
5 Whys — [Root cause from Pareto]:
  Why 1: [Symptom] → Because: [cause 1]
  Why 2: [Cause 1] → Because: [cause 2]
  Why 3: [Cause 2] → Because: [cause 3]
  Why 4: [Cause 3] → Because: [cause 4]
  Why 5: [Cause 4] → Because: [ROOT CAUSE]
```

### Bước 5: PFMEA cho top failure modes

READ `.claude/references/team-expert/quality-excellence/fmea.md`

Với top 3-5 failure modes từ Pareto analysis:
- Nếu PFMEA chưa có → suggest creating PFMEA cho these modes
- Assign S, O, D scores dựa trên available data
- Identify high-RPN items (≥ 100) → these are improvement priorities

### Bước 6: Improve — Solutions và Pilot Recommendation

Tạo Effort-Impact Matrix:

```
Solution Evaluation Matrix:
  | Solution | Impact on CTQ | Implementation Effort | Risk | Recommendation |
  |----------|--------------|----------------------|------|----------------|
  | [Option A] | High | Low | Low | Quick Win — implement first |
  | [Option B] | High | High | Med | Major project — plan separately |
  | [Option C] | Low | Low | Low | Fill-in — do if bandwidth allows |
  | [Option D] | Low | High | High | Don't do — poor ROI |
```

Pilot Recommendation:
- Scope: which process steps, which product/service line
- Duration: minimum to see statistically significant results
- Success criteria: target metric value in pilot
- Measurement plan during pilot

### Bước 7: Control — Control Plan và Handover

READ `.claude/references/team-expert/quality-excellence/six-sigma.md` (Section 1 — Control)

Tạo Control Plan template:

```
Control Plan:
  | Process Step | What to Control (CTQ) | Control Method | Frequency | Sample Size | Reaction Plan |
  |-------------|----------------------|----------------|-----------|-------------|---------------|
  | [Step]      | [CTQ parameter]      | [SPC/visual/WI]| [frequency]| [n=?]      | [If OOC: do X]|
```

Xác định SPC chart type phù hợp:
- Variables data + subgroups → X-bar & R chart
- Individual measurements → I-MR chart
- Attribute (pass/fail) → p-chart hoặc np-chart

Handover checklist:
- [ ] Updated SOP phản ánh improvements
- [ ] Process Owner trained on control plan
- [ ] SPC charts set up với control limits
- [ ] Response plan documented
- [ ] 30/60/90 day check-in scheduled

### Checklist trước khi submit

- [ ] Project Charter có baseline metric và measurable goal
- [ ] SIPOC scope rõ ràng (in vs out)
- [ ] Data Collection Plan có sample size justification
- [ ] Root cause analysis đến level 4-5 (không dừng ở symptom)
- [ ] Solutions ranked by effort-impact (không recommend tất cả)
- [ ] Control Plan có reaction plan (nếu out-of-control, làm gì?)
- [ ] Financial benefit estimate included
