# Procedure: Assess Software Project Risks

> **Type**: Agent Procedure
> **Agent**: enterprise-risk-expert
> **Triggered when**: Được yêu cầu đánh giá rủi ro của chính dự án phần mềm đang phát triển
> **Output**: Project Risk Register, mitigation plans, 90-day risk monitoring recommendations

---

## Khi nào dùng procedure này

Khi skill invoke `enterprise-risk-expert` để đánh giá **rủi ro của chính dự án phần mềm**
(project risks), không phải phân tích requirements cho một risk management module.

Dấu hiệu nhận biết:
- Skill yêu cầu "đánh giá rủi ro dự án", "project risk assessment", "risk review"
- Context: dự án đang trong giai đoạn planning hoặc đầu execution
- Không có từ khóa ERM module, GRC platform, risk register system

**QUAN TRỌNG — Phân biệt:**
- Procedure này: "Dự án này có rủi ro gì?" (project risks)
- `analyze-risk-requirements.md`: "Dự án này cần build ERM module như thế nào?" (product requirements)

---

## Procedure

### Bước 1: Đọc project context

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: .mc-data/docs/ — đọc phase0, phase1, phase2, phase3 nếu có

Collect:
□ Project scope: features, modules, integrations
□ Team: size, seniority, co-located vs remote, key roles
□ Timeline: target dates, milestones, buffer
□ Technology stack: new tech, legacy integrations, cloud vs on-premise
□ External dependencies: third-party vendors, APIs, regulatory approvals
□ Budget: fixed vs variable, contingency available?
□ Stakeholders: number, alignment level, decision-making clarity
```

### Bước 2: Risk identification per category

```
READ: .claude/references/team-expert/enterprise-risk/risk-assessment.md
→ Risk categories, identification methods, scoring methodology

Áp dụng risk universe cho software projects:

TECHNICAL RISKS:
□ Architecture debt: thiết kế có scalability issues không?
□ Technology choice: new/unproven tech trong team?
□ Integration complexity: số lượng external integrations
□ Performance baseline: chưa define rõ performance requirements
□ Security posture: OWASP coverage, dependency vulnerabilities
□ Test coverage: thiếu automated tests → manual regression bottleneck

RESOURCE RISKS:
□ Key person dependency: knowledge concentrated trong 1-2 người?
□ Team capacity: có buffer không? overtime sustainable không?
□ Skill gaps: team có đủ năng lực cho tech stack đã chọn?
□ Vendor dependency: outsourcing components với unclear SLAs

TIMELINE RISKS:
□ Scope creep: requirements still changing during implementation?
□ Dependency delays: third-party/external team blocks critical path?
□ Estimate accuracy: estimates based on uncertainty hoặc similar past work?
□ Integration testing time: thường bị underestimate

QUALITY RISKS:
□ Requirements clarity: acceptance criteria đã đủ rõ chưa?
□ Technical debt accumulation: cutover pressure → skip refactoring?
□ Performance regression: baseline metrics defined?
□ Accessibility/compliance gaps: WCAG, security standards coverage?

BUSINESS RISKS:
□ Requirement volatility: stakeholders có đồng thuận về scope không?
□ Stakeholder alignment: multiple competing priorities?
□ Budget overrun: scope changes without corresponding budget increase?
□ Market timing: delay có ảnh hưởng competitive position không?
□ User adoption: change management plan có không?
```

### Bước 3: Score mỗi rủi ro

```
READ: .claude/references/team-expert/enterprise-risk/risk-assessment.md
→ 5×5 matrix, likelihood scale, impact scale, velocity factor

Cho mỗi risk được identify:
□ Likelihood: 1 (Rare) → 5 (Almost Certain)
□ Impact: 1 (Insignificant) → 5 (Catastrophic) — đánh giá theo project timeline/budget/quality
□ Score = Likelihood × Impact
□ Rating: Low(1-6) / Medium(7-12) / High(13-19) / Critical(20-25)
□ Velocity: Rapid (có thể xảy ra ngay) / Moderate / Slow
□ Early warning indicators: dấu hiệu nào cho thấy risk đang materialize?
```

### Bước 4: Xác định treatment cho top risks

```
READ: .claude/references/team-expert/enterprise-risk/controls.md
→ Risk treatment options (Avoid/Reduce/Transfer/Accept), SMART action plans

Với mỗi High/Critical risk:
□ Treatment option: Avoid / Reduce / Transfer / Accept
□ Specific action: không vague — phải actionable và measurable
□ Owner: đích danh tên người, không phải "team"
□ Deadline: ngày cụ thể
□ Success indicator: làm sao biết risk đã được mitigate?
□ Residual risk: sau treatment, risk score còn bao nhiêu?

Với Medium risks:
□ Monitor strategy: check-in frequency, escalation trigger
□ Contingency plan: nếu risk materializes, phản ứng thế nào?

Với Low risks:
□ Accept và monitor — không cần action plan
□ Note trong risk register để periodic review
```

### Bước 5: Output — Project Risk Register

**Format:**
```markdown
## PROJECT RISK REGISTER — [Project Name]
Prepared: [Date] | Review cycle: Bi-weekly | Owner: [Project Manager / CRO / who?]

### Summary
- Total risks identified: [N]
- Critical: [N] | High: [N] | Medium: [N] | Low: [N]
- Top concern: [1 sentence về risk category hoặc specific risk]

### Risk Register Table

| ID | Risk Description | Category | L | I | Score | Rating | Velocity | Owner | Treatment | Deadline | Residual |
|----|-----------------|----------|---|---|-------|--------|---------|-------|-----------|----------|---------|
| PR-001 | [Risk] | Technical | 3 | 4 | 12 | Medium | Moderate | [Name] | Reduce: [action] | DD/MM | 6 |

(L = Likelihood, I = Impact)

### Detailed Treatment Plans (High/Critical only)

#### PR-XXX: [Risk name]
**Description**: [Full description of the risk]
**Root cause**: [Why might this happen?]
**Early warning signs**: [Observable signals that this risk is materializing]
**Treatment**: Reduce
**Actions**:
- [ ] [Specific action 1] — Owner: [Name] — Due: [Date]
- [ ] [Specific action 2] — Owner: [Name] — Due: [Date]
**Contingency**: If risk materializes → [specific response plan]
**Residual risk**: [Score after treatment]
```

### Bước 6: Output — 90-Day Risk Monitoring Plan

```
READ: .claude/references/team-expert/enterprise-risk/controls.md → 90-day action plan template
READ: .claude/references/team-expert/enterprise-risk/operations.md → risk monitoring cadence

Structure:
□ Weekly check-ins: Critical và High risks với Rapid velocity
□ Bi-weekly check-ins: High risks với Moderate velocity
□ Monthly check-ins: Medium risks
□ Escalation triggers: specific thresholds khi phải escalate lên Steering Committee

Ghi rõ:
□ Ai review (Project Manager? CRO?)
□ Forum nào (weekly standup? risk steering?)
□ Format: brief status update hay full reassessment?
```

---

## Checklist trước khi submit

```
□ Mỗi risk có đủ: ID, description, category, likelihood, impact, score, rating, velocity
□ Mỗi risk có Risk Owner được assign (đích danh, không phải "team")
□ Treatment được xác định cho mọi High/Critical risks
□ Action plans theo SMART format (Specific, Measurable, Achievable, Relevant, Time-bound)
□ Early warning indicators được define cho Critical risks
□ Contingency plans có cho Critical risks
□ 90-day monitoring schedule được specify
□ Phân biệt rõ: rủi ro DỰ ÁN (này) vs rủi ro trong SẢN PHẨM (nếu sản phẩm là risk management system)
□ Top 3 risks được highlight trong executive summary
```
