# Procedure: Audit Quality Management Posture

> **Type**: Agent Procedure
> **Agent**: quality-excellence-expert
> **Triggered when**: wf-legacy-scan — assess quality management maturity of existing organization/system
> **Output**: Quality Maturity Assessment, ISO 9001 gap matrix, top gaps prioritized, 90-day improvement roadmap

---

## Khi nào dùng procedure này

- Skill `wf-legacy-extract` hoặc `wf-analyze-requirements` (legacy flow) gọi quality-excellence-expert để assess quality posture
- User muốn biết "how mature is our quality management currently?"
- Dự án có existing quality system (QMS, ISO, etc.) cần gap analysis
- Chuẩn bị cho ISO 9001 certification — cần biết gaps trước audit

---

## Procedure

### Bước 1: Thu thập context từ existing system

Đọc documents từ paths mà wf-legacy-scan cung cấp. Tìm kiếm:

- Quality policy document (có không? Được approval chưa? Được communicate chưa?)
- Quality procedures / SOPs (có document control không?)
- NCR/CAPA records (có hệ thống không? Paper hay digital?)
- Internal audit program (có scheduled audits không? Records?)
- Management review records (có họp không? Minutes được giữ không?)
- Training records (có competence matrix không?)
- Customer complaint records

Nếu không có documents → note "Not Started" cho mọi clauses liên quan.

### Bước 2: ISO 9001 Clause-by-clause Assessment

READ `.claude/references/team-expert/quality-excellence/iso-9001.md`

Với mỗi clause từ 4 đến 10, đánh giá theo 4 levels:

| Level | Status | Definition |
|-------|--------|-----------|
| 0 | Not Started | Không có evidence, không có process |
| 1 | Partial | Có ý thức về requirement nhưng không consistent, không documented |
| 2 | Implemented | Documented và being followed, nhưng effectiveness chưa verified |
| 3 | Effective | Documented, implemented, measured, showing results |

**Gap Matrix Template:**

```
| Clause | Requirement Summary | Status | Evidence Found | Gap Description | Priority |
|--------|--------------------|----|---|---|---|
| 4.1 | Context of organization | [0/1/2/3] | [what found] | [what missing] | [H/M/L] |
| 4.2 | Interested parties | [0/1/2/3] | | | |
| 4.3 | QMS scope | [0/1/2/3] | | | |
| 4.4 | QMS processes | [0/1/2/3] | | | |
| 5.1 | Leadership commitment | [0/1/2/3] | | | |
| 5.2 | Quality Policy | [0/1/2/3] | | | |
| 5.3 | Roles & responsibilities | [0/1/2/3] | | | |
| 6.1 | Risks & opportunities | [0/1/2/3] | | | |
| 6.2 | Quality objectives | [0/1/2/3] | | | |
| 7.1 | Resources | [0/1/2/3] | | | |
| 7.2 | Competence | [0/1/2/3] | | | |
| 7.5 | Documented information | [0/1/2/3] | | | |
| 8.2 | Customer requirements | [0/1/2/3] | | | |
| 8.4 | External providers | [0/1/2/3] | | | |
| 8.7 | Nonconforming outputs | [0/1/2/3] | | | |
| 9.1 | Monitoring & measurement | [0/1/2/3] | | | |
| 9.2 | Internal audit | [0/1/2/3] | | | |
| 9.3 | Management review | [0/1/2/3] | | | |
| 10.2 | NCR & CAPA | [0/1/2/3] | | | |
| 10.3 | Continual improvement | [0/1/2/3] | | | |
```

### Bước 3: Assess operational quality processes

READ `.claude/references/team-expert/quality-excellence/operations.md`

Kiểm tra:
- NCR system: active và being used? Average closure time? Auto-escalation?
- CAPA system: triggered from multiple sources? RCA quality? Effectiveness verified?
- Audit program: running on schedule? Findings being closed? Repeat findings?
- Document control: version control? Approvals? Obsolete document removal?
- Operation calendar: weekly/monthly reviews happening?

Ghi nhận: breakdown khi nào — process exists but not followed? Or process không tồn tại?

### Bước 4: Assess KPI tracking và reporting

READ `.claude/references/team-expert/quality-excellence/quality-metrics.md`

Kiểm tra với KPI Master Table (Section 5):
- KPIs có được defined không?
- KPIs có được measured không? (Công thức đúng?)
- KPIs có được reported không? (To whom? Frequency?)
- Targets có được set và met không?
- CoQ: có tracking nào không? Hoặc completely unknown?

### Bước 5: Assess controls và quality gates

READ `.claude/references/team-expert/quality-excellence/controls.md`

Kiểm tra:
- Quality gate framework: có formal gates không? Sign-off authority defined?
- Disposition authority: who approves use-as-is? Is it being followed?
- Audit escalation: major NCs being escalated? Records?
- Access control: quality system access managed? Roles defined?

### Bước 6: Calculate Maturity Score và produce outputs

**Quality Maturity Level (QML):**

| Level | Score | Description |
|-------|-------|-------------|
| Level 1: Ad hoc | 0-1.0 avg | No defined processes; reactive only; no documentation |
| Level 2: Developing | 1.1-1.5 avg | Awareness exists; some processes; inconsistent execution |
| Level 3: Defined | 1.6-2.0 avg | Documented processes; most clauses implemented |
| Level 4: Managed | 2.1-2.5 avg | Measured and monitored; data-driven decisions |
| Level 5: Optimizing | 2.6-3.0 avg | Continuous improvement culture; benchmarked performance |

**Score calculation**: Average status across all assessed clauses.

**Produce:**

1. **ISO 9001 Gap Matrix** (full table from Bước 2)

2. **Quality Maturity Score**: QML Level + score + narrative

3. **Top 5 Priority Gaps** (highest-impact, lowest-maturity):
   ```
   Gap 1: [Clause X] — [Description]
   Why Priority: [Impact on quality outcomes, certification risk]
   Effort to Fix: [Low/Medium/High]
   ```

4. **90-Day Improvement Roadmap**:
   ```
   Month 1: [Quick wins — Status 0 → 1, basic infrastructure]
     - Week 1-2: [Specific action]
     - Week 3-4: [Specific action]
   Month 2: [Core implementation — Status 1 → 2]
     - ...
   Month 3: [Effectiveness & monitoring — Status 2 → 3]
     - ...
   ```

### Checklist trước khi submit

- [ ] Tất cả Clauses 4-10 đã assessed với evidence hoặc "no evidence found"
- [ ] Priority gaps top 5 có justification (tại sao ưu tiên)
- [ ] 90-day roadmap có specific actions, không chung chung
- [ ] Maturity level justified bằng evidence từ Bước 1
- [ ] Không nhầm lẫn với operational QC scope (day-to-day warehouse inspection)
- [ ] CoQ assessment included nếu bất kỳ financial data available
