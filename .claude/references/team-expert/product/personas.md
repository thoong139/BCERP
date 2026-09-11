# Product Management - User Personas

> **Domain**: Product Management / Quản lý Sản phẩm
> **Last Updated**: 2026-03-22

---

## Persona 1: Product Manager

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Product Manager |
| **Experience** | 3-7 năm (mix engineering/design/business) |
| **Report to** | Head of Product hoặc VP of Product |
| **Focus** | Roadmap ownership, cross-functional alignment, feature delivery |

### Daily Tasks

1. Review product analytics và user feedback mới nhất
2. Sync với engineering về sprint progress và blockers
3. Viết hoặc refine user stories và acceptance criteria
4. Tham dự daily standup với squad
5. Respond to stakeholder questions về roadmap và priorities

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Feature scope trong sprint hiện tại | Approve | Velocity, backlog depth, dependency map |
| Ưu tiên giữa bug fix và feature request | Approve | Bug severity, user impact count, SLA |
| Accept/reject design proposal từ UX | Approve | User research findings, business goals |
| Escalate scope change lên leadership | Recommend | Impact assessment, timeline delta |
| Release timing (minor releases) | Approve | Test coverage %, critical bug count |

### Pain Points

- Không có single source of truth cho requirements — thông tin nằm rải rác ở Slack, Jira, email
- Stakeholder alignment tốn quá nhiều thời gian do thiếu visibility vào roadmap
- Khó đo impact của từng feature sau launch (thiếu tracking chuẩn)
- Bị kéo vào detail implementation thay vì tập trung discovery
- Feature requests từ nhiều nguồn không có scoring nhất quán

### Must-have Features

- ✅ Roadmap board với timeline view và dependency visualization
- ✅ User story template với acceptance criteria fields chuẩn
- ✅ Feature status tracking từ Idea đến Launched
- ✅ Integration hai chiều với Jira và Confluence
- ✅ Analytics dashboard embedded cho từng feature (adoption rate, funnel)

---

## Persona 2: Product Owner

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Product Owner |
| **Experience** | 2-5 năm (thường từ nền tảng BA hoặc Scrum Master) |
| **Report to** | Product Manager hoặc Head of Product |
| **Focus** | Backlog hygiene, sprint planning, acceptance criteria, daily team collaboration |

### Daily Tasks

1. Grooming backlog: viết, refine, estimate user stories
2. Tham dự sprint ceremonies (planning, review, retro)
3. Trả lời câu hỏi kỹ thuật từ developers trong sprint
4. Verify completed stories theo acceptance criteria
5. Update story statuses và report impediments

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Story acceptance (done/not done) | Approve | Acceptance criteria checklist, test results |
| Story point estimate adjustment | Approve | Team capacity, complexity input từ dev |
| Thứ tự stories trong sprint backlog | Approve | Dependencies, business value scores |
| Chuyển story sang sprint tiếp theo | Approve | Current sprint load, blocker status |
| Flag unclear requirements lên PM | Recommend | Story ambiguity, missing criteria |

### Pain Points

- Acceptance criteria không rõ ràng dẫn đến rework cuối sprint
- Backlog lộn xộn, thiếu tagging nhất quán theo feature/module
- Không có cách dễ để track dependencies giữa stories
- Khó estimate effort khi thiếu technical breakdown từ engineering
- Sprint velocity bị distort bởi unplanned work (bugs, hotfixes)

### Must-have Features

- ✅ Backlog management với drag-and-drop prioritization
- ✅ User story template với AC fields bắt buộc
- ✅ Story dependency linking (blocks/blocked by)
- ✅ Sprint velocity chart và capacity planning view
- ✅ Acceptance criteria checklist với sign-off flow

---

## Persona 3: User Researcher

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | User Researcher / UX Researcher |
| **Experience** | 2-6 năm (nền tảng psychology, HCI, social science hoặc design) |
| **Report to** | Head of Design hoặc Head of Product |
| **Focus** | Qualitative research, usability testing, insight synthesis, research ops |

### Daily Tasks

1. Conduct hoặc moderate user interviews và usability sessions
2. Synthesize interview notes thành themes và findings
3. Collaborate với PM để frame research questions cho discovery
4. Document research findings trong shared repository
5. Review feedback từ support tickets và survey responses để identify patterns

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Research methodology phù hợp cho problem | Recommend | Problem type, timeline, sample availability |
| Recruit screener criteria cho participant selection | Approve | Target user segment, study objectives |
| Sample size cho qualitative study | Approve | Study type, saturation signal, timeline |
| Declare research finding as validated insight | Approve | Triangulated across ≥ 3 sources or participants |
| Escalate conflicting user data lên PM | Recommend | Contradictory data points, segment breakdown |

### Pain Points

- Research insights được documented nhưng không được actioned — "insight graveyard"
- Không có standard repository cho research findings — insights lặp lại qua nhiều projects
- Timeline discovery quá ngắn dẫn đến thin research (1-2 interviews thay vì 5+)
- Khó communicate nuance của qualitative data cho engineering/PM dùng quantitative mindset
- Participant recruitment tốn thời gian, thiếu maintained research panel

### Must-have Features

- ✅ Research repository với tagging theo user segment, feature, theme
- ✅ Interview guide template và note-taking structure chuẩn
- ✅ Insight card format: observation → pattern → implication
- ✅ Link từ research findings → product opportunities → backlog items
- ✅ Research participant panel management (consent, contact history, screener results)

---

## Persona 4: Growth PM

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Growth Product Manager / Growth Lead |
| **Experience** | 3-7 năm (thường từ nền tảng analytics, growth marketing hoặc PM) |
| **Report to** | Head of Product hoặc Chief Growth Officer |
| **Focus** | Acquisition funnel, activation, retention, experimentation velocity, monetization |

### Daily Tasks

1. Review growth metrics dashboard: signup rate, activation rate, DAU/MAU
2. Analyze A/B experiment results và determine next iteration
3. Identify top-of-funnel drop-off points và prioritize experiments
4. Coordinate với marketing về landing page và onboarding experiments
5. Run growth team standup và unblock experiment deploys

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Launch new A/B experiment | Approve | Hypothesis, sample size calculation, rollout % |
| Declare experiment winner và ship | Approve | Statistical significance ≥ 95%, secondary metrics check |
| Prioritize growth backlog items | Approve | ICE score, funnel impact estimate |
| Change onboarding flow | Approve | Activation rate baseline, cohort retention impact |
| Invest in new growth channel | Recommend | CAC estimate, LTV projection, payback period |

### Pain Points

- Experiment velocity blocked bởi engineering capacity — growth team không có dedicated eng
- Khó isolate single variable do nhiều experiments chạy đồng thời trên cùng user segment
- Onboarding changes impact nhiều teams — alignment tốn thời gian hơn actual build
- Attribution không rõ ràng giữa marketing campaigns và product activation experiments
- Không có centralized experiment log → quyết định không được documented cho future reference

### Must-have Features

- ✅ Experiment registry: hypothesis, variants, results, decision per experiment
- ✅ Growth funnel visualization với step-by-step conversion rates
- ✅ Feature flag management tích hợp với experiment tracking
- ✅ Cohort analysis: activation, D7/D30/D90 retention per experiment group
- ✅ No-code experiment configuration cho landing pages và onboarding flows

---

## Persona 5: Product Operations Manager

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Product Operations Manager / Product Ops |
| **Experience** | 3-6 năm (nền tảng operations, program management hoặc product analytics) |
| **Report to** | Head of Product |
| **Focus** | PM tooling, process standardization, data enablement, cross-team coordination |

### Daily Tasks

1. Maintain và improve PM tools và templates (Jira, Productboard, Confluence)
2. Onboard new PMs vào product process và tooling
3. Monitor data quality cho product analytics events
4. Coordinate cross-team dependencies và milestone tracking
5. Compile product performance reports cho exec review

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Standardize new PM template hoặc process | Approve | PM team feedback, adoption rate of current templates |
| Tool procurement cho product team | Recommend | Tool evaluation matrix, budget estimate |
| Analytics tracking plan cho new feature | Approve | Feature spec, event taxonomy review |
| Deprecate outdated process hoặc template | Approve | Usage data, PM team sign-off |
| Escalate cross-team dependency conflict | Recommend | Dependency map, blocked items list |

### Pain Points

- Không có visibility vào tooling adoption — không biết PMs đang dùng templates hay không
- Analytics tracking plan thường được viết sau khi feature đã build — events bị miss
- Không có consistent meeting cadence template cho PM team — mỗi PM chạy reviews khác nhau
- Product performance reports phải assembly manually từ nhiều tools mỗi tuần
- New PM onboarding thiếu structured path — rely vào informal knowledge transfer

### Must-have Features

- ✅ PM playbook hub: templates, guides, process docs tập trung
- ✅ Analytics tracking plan integrated vào feature spec workflow (pre-build)
- ✅ Automated product performance report từ connected data sources
- ✅ Onboarding checklist cho new PMs với progress tracking
- ✅ Tooling adoption dashboard: template usage, process compliance per PM

---

## Quick Reference: Access Matrix

| Data / Function | Product Manager | Product Owner | User Researcher | Growth PM | Product Ops |
|-----------------|:---------------:|:-------------:|:---------------:|:---------:|:-----------:|
| Roadmap (view) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Roadmap (edit) | ✅ | ⚠ Sprint scope only | ❌ | ⚠ Growth items | ✅ |
| Backlog (full edit) | ✅ | ✅ | ❌ | ⚠ Growth backlog | ✅ |
| Feature spec (create PRD) | ✅ | ⚠ User stories only | ❌ | ✅ | ❌ |
| A/B experiment (launch) | ⚠ HoP approval | ❌ | ❌ | ✅ | ❌ |
| Analytics dashboards | ✅ | ⚠ Read only | ⚠ Research-scoped | ✅ | ✅ |
| Raw user event data | ⚠ With training | ❌ | ⚠ Anonymized | ✅ | ✅ |
| Research repository | ⚠ Read only | ⚠ Read only | ✅ | ⚠ Read only | ✅ |
| Pricing data | ⚠ Read only | ❌ | ❌ | ⚠ Experiment data | ⚠ Read only |
| Feature flag (production) | ⚠ Eng approval | ❌ | ❌ | ⚠ Eng approval | ❌ |
| Tooling / process admin | ❌ | ❌ | ❌ | ❌ | ✅ |
| Decision log (create) | ✅ | ⚠ Sprint level | ❌ | ✅ | ✅ |

<!-- ✅ = Full access, ❌ = No access, ⚠ = Conditional (ghi chú điều kiện) -->
