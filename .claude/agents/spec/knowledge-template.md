# Knowledge File Templates

> **Version:** 1.0.0 | **Last Updated:** 2026-03-15

Hướng dẫn tạo knowledge files cho domain experts trong DEVKIT.
Mỗi domain expert cần TỐI THIỂU 3 files core (K1-K3), thêm topic files (K4-K5) tùy độ phức tạp.

---

## Tổng quan Knowledge Types

| Type | File mẫu | Nội dung | Bắt buộc |
|------|----------|----------|----------|
| K1 | `personas.md` | Ai tồn tại trong domain | ✅ |
| K2 | `operations.md` | Quy trình vận hành | ✅ |
| K3 | `controls.md` | Kiểm soát & phân quyền | ✅ |
| K4 | `[methodology].md` | Phương pháp/framework | Tùy domain |
| K5 | `[topic].md` | Chủ đề chuyên sâu | Tùy domain |

---

## Nguyên tắc chung — Áp dụng cho MỌI knowledge file

### Header chuẩn (BẮT BUỘC)

```markdown
# [Domain] - [Topic Name]

> **Domain**: [Domain full name] / [Tên tiếng Việt]
> **Last Updated**: [YYYY-MM-DD]
> **Nguồn**: [Nguồn tham khảo — nếu có]
```

### Chỉ Facts — Không Behavior

```
✅ ĐÚNG (Domain Fact):
"Discount >15% cần Sales Director approve."
"Pipeline Coverage target: ≥3x remaining quota."
"MEDDPICC gồm 8 yếu tố: Metrics, Economic Buyer, ..."

❌ SAI (Behavior Guidance — thuộc Agent):
"Bạn LUÔN phải kiểm tra pipeline coverage."
"Silence là tool — sau câu hỏi khó, chờ."
"Không bao giờ trash competition."
```

### Nếu CẦN PHẢI có behavioral notes (edge case)

Đánh dấu rõ ràng trong section riêng ở cuối file:

```markdown
---

## Behavioral Notes

> ⚠️ Phần này là guidance cho agent, không phải domain fact.
> Xem xét chuyển vào agent definition nếu applicable cho mọi tình huống.

- [Guidance 1]
- [Guidance 2]
```

### Kích thước

- Target: 150-300 dòng/file
- Hard limit: 400 dòng/file
- Nếu vượt → tách theo sub-topic

---

## K1: Personas Template

```markdown
# [Domain] - User Personas

> **Domain**: [Domain] / [Tên tiếng Việt]
> **Last Updated**: [YYYY-MM-DD]

---

## Persona 1: [Role Name]

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | [Chức danh chính thức] |
| **Experience** | [Khoảng kinh nghiệm: 1-3 năm, 5-10 năm...] |
| **Report to** | [Cấp trên trực tiếp] |
| **Focus** | [2-3 từ mô tả trọng tâm] |

### Daily Tasks
1. [Task phổ biến nhất]
2. [Task phổ biến thứ 2]
3. [Task phổ biến thứ 3]
4. [Task phổ biến thứ 4]
5. [Task phổ biến thứ 5]

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| [Quyết định 1] | [Execute/Request/Recommend/Approve] | [Data cần thiết] |
| [Quyết định 2] | [Execute/Request/Recommend/Approve] | [Data cần thiết] |

### Pain Points
- [Vấn đề 1 — cụ thể, đo được nếu có thể]
- [Vấn đề 2]
- [Vấn đề 3]

### Must-have Features
- ✅ [Feature 1 — từ góc nhìn persona này]
- ✅ [Feature 2]
- ✅ [Feature 3]

---

<!-- Lặp lại cho 3-6 personas -->

## Quick Reference: Access Matrix

| Data/Function | [Persona 1] | [Persona 2] | [Persona 3] | [Persona 4] |
|---------------|:-----------:|:-----------:|:-----------:|:-----------:|
| [Data/Func 1] | ✅/❌/⚠ | ✅/❌/⚠ | ✅/❌/⚠ | ✅/❌/⚠ |

<!-- ✅ = Full access, ❌ = No access, ⚠ = Conditional (ghi chú điều kiện) -->
```

### Personas Checklist

- [ ] 3-6 personas (không quá nhiều)
- [ ] Mỗi persona CÓ: Profile, Daily Tasks, Key Decisions, Pain Points, Must-haves
- [ ] Authority Level dùng vocabulary chuẩn: Execute / Request / Recommend / Approve
- [ ] Access Matrix ở cuối file
- [ ] Pain Points cụ thể — không mơ hồ ("manual data entry" tốt hơn "khó khăn")

---

## K2: Operations Template

```markdown
# [Domain] - Operational Analysis Framework

> **Domain**: [Domain] / [Tên tiếng Việt]
> **Last Updated**: [YYYY-MM-DD]

---

## 1. Core Processes

### Process 1: [Tên quy trình]

<!-- ASCII diagram cho process flow chính -->
```
[Step 1] → [Step 2] → [Step 3] → [Step 4] → [Step 5]
    │           │           │           │           │
    ▼           ▼           ▼           ▼           ▼
 [Detail]   [Detail]   [Detail]   [Detail]   [Detail]
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| [Step 1] | [Role] | [Action] | [Check] |

### Process 2: [Tên quy trình]
<!-- Lặp lại format trên -->

---

## 2. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| [Task 1] | [Role] | [Thời gian] | [Vấn đề] |

### Weekly Tasks
<!-- Cùng format -->

### Monthly Tasks
<!-- Cùng format -->

### Quarterly Tasks
<!-- Cùng format -->

---

## 3. Decision Support Requirements

### Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| [Dashboard 1] | [Audience] | [Metrics] |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| [Report 1] | [Daily/Weekly/Monthly] | [Purpose] | [Audience] |

---

## 4. Integration Touchpoints

### Internal Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| [System 1] | [Direction] | [Purpose] |

### External Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| [System 1] | [Direction] | [Purpose] |

---

## 5. KPIs & Metrics

### [Category 1] Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| [Metric 1] | [Formula] | [Target cụ thể] |

### [Category 2] Metrics
<!-- Cùng format -->
```

### Operations Checklist

- [ ] Core processes có diagram (ASCII art)
- [ ] Mỗi process step có: Owner, Actions, Validation
- [ ] Task frequency analysis đủ 4 level: Daily/Weekly/Monthly/Quarterly
- [ ] Task frequency có: Pain Points (connection đến personas)
- [ ] KPIs có: Formula + Target cụ thể
- [ ] Integration touchpoints có: Direction + Purpose
- [ ] Tất cả là FACTS về vận hành — không có behavioral guidance

---

## K3: Controls Template

```markdown
# [Domain] - Controls & Access Management

> **Domain**: [Domain] / [Tên tiếng Việt]
> **Last Updated**: [YYYY-MM-DD]

---

## 1. Approval Matrix

### By [Dimension 1 — ví dụ: Amount, Percentage, Level]

| [Threshold] | [Role 1] | [Role 2] | [Role 3] | [Role 4] |
|-------------|:--------:|:--------:|:--------:|:--------:|
| [Level 1] | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ |

<!-- Thresholds PHẢI cụ thể: số tiền, %, level rõ ràng -->

---

## 2. Access Control

### [Function/Data] Access Matrix

| [Resource] | [Role 1] | [Role 2] | [Role 3] |
|------------|:--------:|:--------:|:--------:|
| [Resource 1] | ✅/❌/⚠ | ✅/❌/⚠ | ✅/❌/⚠ |

### Ownership Rules

| Scenario | Rule | Override Authority |
|----------|------|--------------------|
| [Scenario 1] | [Rule] | [Who can override] |

---

## 3. Workflow Controls

### [Workflow Name] Rules

| From | To | Criteria | Validation |
|------|----|----------|------------|
| [State 1] | [State 2] | [Entry criteria] | [System check] |

### Hygiene Controls

| Control | Frequency | Enforcement |
|---------|-----------|-------------|
| [Control 1] | [When] | [How] |

---

## 4. Audit Trail Requirements

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| [Event 1] | [Fields] | [Period] |

### Sensitive Data Access Log

| Data Accessed | Who Can Access | Purpose |
|---------------|----------------|---------|
| [Data 1] | [Roles] | [Why] |

---

## Quick Reference: Approval Checklist

### Before [Action 1]
- [ ] [Check item 1]
- [ ] [Check item 2]
- [ ] [Check item 3]
```

### Controls Checklist

- [ ] Approval matrices có thresholds CỤ THỂ (số tiền, %, level)
- [ ] Access matrix có role × resource mapping
- [ ] Ownership rules có override authority
- [ ] Workflow controls có state transition criteria
- [ ] Audit trail có: Events + Data captured + Retention period
- [ ] Tất cả là BUSINESS RULES — không phải agent constraints

---

## K4: Methodology Template

```markdown
# [Domain] - [Methodology/Framework Name]

> **Domain**: [Domain] / [Tên tiếng Việt]
> **Last Updated**: [YYYY-MM-DD]
> **Nguồn**: [Nguồn gốc — tác giả, tổ chức]

---

## 1. Overview

[1-3 câu: Framework này là gì, solve problem gì, khi nào áp dụng]

---

## 2. Components

### [Component 1]

| Thuộc tính | Mô tả |
|------------|--------|
| [Attr 1] | [Value] |

### [Component 2]
<!-- Cùng format -->

---

## 3. Application Guide

| Tình huống | Cách áp dụng |
|------------|--------------|
| [Situation 1] | [How to apply] |

<!-- Đây là "khi nào dùng framework này" — domain fact, không phải agent behavior -->

---

## 4. Templates

### [Template Name]

```
[Template content — agent có thể copy-paste khi cần]
```

---

## Quick Reference

| [Dimension] | [Option 1] | [Option 2] | [Option 3] |
|-------------|------------|------------|------------|
| [Row 1] | [Value] | [Value] | [Value] |
```

### Methodology Checklist

- [ ] Mô tả framework như kiến thức KHÁCH QUAN
- [ ] KHÔNG chứa "bạn nên..." hay "luôn luôn..."
- [ ] Có templates agent copy-paste được
- [ ] "Khi nào dùng" = domain fact (situation → framework), không phải command
- [ ] Có nguồn tham khảo

---

## K5: Domain-Specific Topic Template

```markdown
# [Domain] - [Topic Name]

> **Domain**: [Domain] / [Tên tiếng Việt]
> **Last Updated**: [YYYY-MM-DD]
> **Nguồn**: [Nguồn — nếu có]

---

## 1. [Section chính 1]

[Nội dung domain-specific]

---

## 2. [Section chính 2]

[Nội dung domain-specific]

---

## Quick Reference: [Summary Table]

| [Dimension] | [Column 1] | [Column 2] |
|-------------|------------|------------|
```

---

## Ví dụ: Knowledge files cho domain "Sales"

| File | Type | Nội dung chính | Dòng |
|------|------|---------------|------|
| `personas.md` | K1 | 5 personas: Rep, Inside Sales, Manager, Director, Ops | ~230 |
| `operations.md` | K2 | 4 core processes, task frequency, KPIs, integrations | ~270 |
| `controls.md` | K3 | Discount matrix, territory rules, quote controls, audit trail | ~215 |
| `methodology.md` | K4 | MEDDPICC, SPIN, Gap Selling, Sandler, Challenger | ~190 |
| `pipeline-analytics.md` | K5 | Pipeline velocity, coverage, deal health scoring, forecasting | ~200 |
| `pre-sales.md` | K5 | Technical discovery, demo engineering, POC, competitive positioning | ~215 |
| `outbound.md` | K5 | Signal-based selling, ICP, sequences, cold email | ~180 |
| `account-management.md` | K5 | NRR, land-expand, QBR, stakeholder mapping, churn prevention | ~240 |

**Tổng: 8 files, ~1,740 dòng** — load on-demand, không phình context window.

---

## Quy trình tạo Knowledge cho domain mới

### Bước 1: Research domain
```
Thu thập thông tin về domain:
- Personas: ai làm việc trong domain này?
- Processes: quy trình chính là gì?
- Controls: ai approve gì? access rules?
- Industry standards/frameworks?
```

### Bước 2: Tạo 3 files core
```
1. personas.md — 3-6 personas với đầy đủ profile
2. operations.md — core processes + task frequency + KPIs
3. controls.md — approval matrices + access control + audit trail
```

### Bước 3: Đánh giá cần topic files không
```
Hỏi: Domain này có methodology/framework riêng cần reference chi tiết?
Hỏi: Có sub-topic nào phức tạp cần file riêng?
Nếu có → tạo thêm K4, K5 files
```

### Bước 4: Review
```
Chạy Knowledge Checklist (xem README.md mục 9.2)
Đảm bảo:
- Chỉ FACTS, không behavior
- Mỗi file ≤400 dòng
- Có templates/examples cụ thể
- Mọi file có agent pointer
```
