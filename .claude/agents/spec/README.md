# Agent, Knowledge & Procedures Construction Specification

> **Version:** 2.0.0 | **Last Updated:** 2026-03-16
> **Áp dụng cho:** Toàn bộ agents trong DEVKIT MCV3

Tài liệu chuẩn hóa việc xây dựng Agent, bộ Kiến thức (Knowledge) và Thủ tục (Procedures) đi kèm.
Mục tiêu: mọi agent đều có chất lượng đồng đều, ranh giới rõ ràng giữa
"cách agent tư duy & hành động", "sự thật domain mà agent tham khảo",
và "quy trình từng bước cho từng loại task cụ thể".

---

## Mục lục

1. [Nguyên tắc nền tảng](#1-nguyên-tắc-nền-tảng)
2. [Phép thử phân loại (Litmus Test)](#2-phép-thử-phân-loại-litmus-test)
3. [Tiêu chí cho Agent Definition](#3-tiêu-chí-cho-agent-definition)
4. [Tiêu chí cho Knowledge Files](#4-tiêu-chí-cho-knowledge-files)
5. [Tiêu chí cho Agent Procedures](#5-tiêu-chí-cho-agent-procedures)
6. [Ranh giới Agent vs Knowledge vs Procedures — Bảng phân định](#6-ranh-giới-agent-vs-knowledge-vs-procedures--bảng-phân-định)
7. [Cấu trúc thư mục](#7-cấu-trúc-thư-mục)
8. [Quy trình tạo Agent mới](#8-quy-trình-tạo-agent-mới)
9. [Anti-Patterns — Lỗi thường gặp](#9-anti-patterns--lỗi-thường-gặp)
10. [Checklist đánh giá](#10-checklist-đánh-giá)
11. [Ví dụ tham chiếu](#11-ví-dụ-tham-chiếu)

---

## 1. Nguyên tắc nền tảng

### 1.1 Ba khái niệm cốt lõi

```
AGENT = WHO + HOW (tổng quát)
  Tôi là ai, tôi tư duy thế nào, tôi hành động theo quy trình nào,
  tôi biết giới hạn của mình ở đâu, tôi phối hợp với ai.
  → Luôn được load vào context khi agent được invoke.

KNOWLEDGE = WHAT
  Thế giới thực vận hành ra sao — personas, processes, controls,
  metrics, templates, benchmarks, standards — domain facts.
  → Load on-demand khi agent cần tra cứu domain facts.

PROCEDURES = HOW (cụ thể cho từng task type)
  Agent thực hiện task X theo trình tự bước nào, cần đọc file nào,
  output trông như thế nào — procedure cho 1 loại task cụ thể.
  → Load on-demand khi agent nhận task thuộc loại đó.
```

### 1.2 Separation of Concerns

| Nguyên tắc | Mô tả |
|------------|--------|
| **Agent không chứa data** | Agent không liệt kê chi tiết domain facts — chỉ pointer đến knowledge files |
| **Knowledge không chứa behavior** | Knowledge không hướng dẫn agent cách hành xử — chỉ cung cấp facts |
| **Agent có thể thay được** | Nếu thay agent khác (cùng domain), knowledge files vẫn dùng được |
| **Knowledge có thể share** | Nhiều agents khác nhau có thể đọc cùng knowledge file |

### 1.3 Tối ưu cho Context Window

Agent file nên ngắn gọn (150-250 dòng) vì:
- Agent file LUÔN được load vào context khi agent được invoke
- Knowledge files chỉ được load ON-DEMAND khi agent cần
- Agent file dài = lãng phí context window = giảm chất lượng output

---

## 2. Phép thử phân loại (Litmus Test)

Khi không chắc nội dung thuộc Agent hay Knowledge, áp dụng 3 phép thử:

### Phép thử 1: Thay chuyên gia

> "Nếu thay agent này bằng một chuyên gia khác cùng domain
> (ví dụ: thay sales-expert A bằng sales-expert B),
> nội dung này có thay đổi không?"

- **Thay đổi** → Agent (gắn với cách agent cụ thể này vận hành)
- **Không thay đổi** → Knowledge (sự thật domain, ai cũng cần biết)

### Phép thử 2: Tần suất thay đổi

> "Nội dung này thay đổi vì domain thay đổi,
> hay vì cách làm việc thay đổi?"

- **Domain thay đổi** (luật mới, quy trình mới) → Knowledge
- **Cách làm việc thay đổi** (workflow mới, perspective mới) → Agent

### Phép thử 3: Câu hỏi trả lời

> "Nội dung này trả lời câu hỏi nào?"

| Câu hỏi | Thuộc về |
|----------|----------|
| "Tôi là ai?" | Agent — Identity |
| "Tôi nhìn vấn đề từ góc nào?" | Agent — Cognitive Framework |
| "Khi nhận bất kỳ task nào, tôi làm gì trước?" | Agent — Workflow (tổng quát) |
| "Tôi tìm thông tin ở đâu?" | Agent — Knowledge Routing |
| "Tôi phối hợp với ai?" | Agent — Coordination |
| "Tôi KHÔNG ĐƯỢC làm gì?" | Agent — Constraints |
| "Khi làm task X cụ thể, tôi thực hiện từng bước nào?" | **Procedures** — Task Procedure |
| "Task X cần đọc knowledge files nào?" | **Procedures** — Knowledge Routing per task |
| "Output của task X trông thế nào?" | **Procedures** — Output Contract per task |
| "Ai tồn tại trong domain này?" | Knowledge — Personas |
| "Quy trình thực tế diễn ra thế nào?" | Knowledge — Processes |
| "Ai được phép làm gì?" | Knowledge — Controls |
| "Đo lường bằng chỉ số nào?" | Knowledge — Metrics |
| "Industry standard là gì?" | Knowledge — Standards |

---

## 3. Tiêu chí cho Agent Definition

File agent nằm tại `.claude/agents/[team]/[agent-name].md`

### 3.1 Các thành phần BẮT BUỘC

#### A1. Frontmatter — Metadata

```yaml
---
name: [agent-name]           # Kebab-case, match filename
version: [x.x.x]             # SemVer
last_updated: [YYYY-MM-DD]
description: |
  [Mô tả 1-2 dòng vai trò]
  Proactively invoke khi phát hiện keywords: [keyword1], [keyword2], ...
tools: [Read, Write, Grep, Glob]   # Tools agent được dùng
model: [sonnet|opus|haiku]         # Model mặc định
---
```

**Quy tắc:**
- `name` phải khớp với filename (bỏ `.md`)
- `description` phải có "Proactively invoke khi..." để orchestrator biết khi nào gọi
- `tools`: cấp đầy đủ tools để agent làm việc hiệu quả nhất — bao gồm Read, Write, Edit, Glob, Grep, Bash, Agent, TodoWrite, WebFetch, WebSearch, GitNexus MCP, Serena MCP, Playwright MCP, Context7 MCP, và MCP Resources
- `model` chọn theo complexity: sonnet cho phân tích, opus cho sáng tạo/phức tạp

#### A2. Identity — Vai trò (3-5 dòng)

```markdown
## Vai trò

[Câu mô tả ngắn gọn: Tôi là ai, chuyên môn cốt lõi, giá trị mang lại]
```

**Quy tắc:**
- Tối đa 5 dòng
- Nêu rõ GÓC NHÌN đặc trưng (không chỉ "biết về X" mà "phân tích X từ góc Y")
- Không lặp lại description trong frontmatter

#### A3. Expertise — Phạm vi chuyên môn (summary)

```markdown
## Expertise

- **[Lĩnh vực 1]**: [Mô tả ngắn 5-10 từ]
- **[Lĩnh vực 2]**: [Mô tả ngắn 5-10 từ]
...
```

**Quy tắc:**
- Liệt kê 5-10 lĩnh vực chuyên môn — chỉ MỨC SUMMARY
- Mỗi lĩnh vực = 1 dòng, không giải thích chi tiết
- Chi tiết từng lĩnh vực nằm trong Knowledge files
- Mục đích: agent tự biết phạm vi của mình để decide khi nào applicable

#### A4. Cognitive Framework — Cách tư duy

```markdown
## Cognitive Framework

[Mô tả CÁCH agent tiếp cận vấn đề — perspectives, lenses, mental models]
```

**Quy tắc:**
- Đây là phần QUAN TRỌNG NHẤT — phân biệt agent này với agent khác cùng domain
- Trả lời: "Khi nhìn một yêu cầu, tôi phân tích từ những góc độ nào?"
- Ví dụ: Dual Perspective (Operational + Control), Risk-First Thinking, User-Centric Analysis
- KHÔNG liệt kê domain facts — chỉ mô tả CÁCH TƯ DUY

#### A5. Workflow — Quy trình hành động

```markdown
## Workflow

### Bước 1: [Tên bước]
[Mô tả hành động + điều kiện + input/output]

### Bước 2: [Tên bước]
...
```

**Quy tắc:**
- Mỗi bước: 1 hành động rõ ràng, có input và output
- Mỗi bước có READ instruction: khi nào đọc knowledge file nào
- Có fallback path khi thiếu input
- Bước cuối PHẢI có output format/location
- Tối đa 5-7 bước — nếu nhiều hơn thì tách thành sub-workflow

#### A6. Knowledge Routing — Bảng pointer

```markdown
## Knowledge References

| Khi cần | Đọc file |
|---------|----------|
| [Tình huống cụ thể] | `[đường dẫn file]` |
...
```

**Quy tắc:**
- Mỗi knowledge file có 1 dòng pointer
- Cột "Khi cần" phải mô tả TÌNH HUỐNG cụ thể, không phải tên file
- Đường dẫn PHẢI chính xác, có thể verify bằng file system
- Không có knowledge file nào bị "mồ côi" (có file nhưng không có pointer)

#### A7. Coordination Rules — Phối hợp

```markdown
## Coordination

| Khi phát hiện | Huy động |
|---------------|----------|
| [Dấu hiệu cross-domain] | [agent-name] |
...
```

**Quy tắc:**
- Dòng đầu tiên LUÔN là reference: `> Chi tiết: .claude/references/agent-coordination.md`
- Giữ 3-5 coordination rules CỤ THỂ NHẤT cho agent này
- Danh sách đầy đủ coordination nằm trong `agent-coordination.md` (SSOT)
- Chỉ liệt kê agents mà agent này THỰC SỰ cần phối hợp (không exhaustive)
- Dấu hiệu phải đủ cụ thể để agent nhận biết tự động

#### A8. Constraints — Guardrails

```markdown
## Constraints

### Bắt buộc
- ✅ [Điều PHẢI làm]

### Không được
- ❌ [Điều KHÔNG ĐƯỢC làm]
```

**Quy tắc:**
- Bắt buộc: 3-6 rules — những gì PHẢI tuân thủ
- Không được: 3-6 rules — những gì bị CẤM
- Mỗi constraint phải ACTIONABLE (agent có thể check được)
- Không trùng với domain controls (domain controls nằm trong Knowledge)
- Đây là guardrails cho HÀNH VI agent, không phải business rules

#### A9. Output Contract — Format output (NẾU CẦN)

```markdown
## Output Contract

[Mô tả format output: REQ-ID pattern, file location, template reference]
```

**Quy tắc:**
- Chỉ cần nếu agent tạo output có format đặc thù
- REQ-ID pattern: `REQ-[DEPT]-[MODULE]-[NUMBER]`
- Output location: path hoặc cách xác định path

### 3.2 Thành phần TÙY CHỌN

| Thành phần | Khi nào cần | Ghi chú |
|------------|-------------|---------|
| Quick Start Example | Agent mới, phức tạp | Ví dụ end-to-end 5-7 dòng |
| Communication Style | Agent tương tác trực tiếp user | Tone, detail level |
| Advanced Capabilities | Agent có khả năng nâng cao | Emerging areas, experimental |
| Standards table | Agent có standards riêng (VAS, IFRS...) | Summary only, detail → Knowledge |

### 3.3 Giới hạn kích thước

| Metric | Target | Hard Limit |
|--------|--------|------------|
| Tổng số dòng | 120-180 | 250 |
| Phần Expertise | 8-12 dòng | 15 |
| Phần Workflow | 30-50 dòng | 60 |
| Phần Constraints | 8-14 dòng | 20 |

---

## 4. Tiêu chí cho Knowledge Files

Files nằm tại `.claude/references/team-expert/[domain]/[topic].md`

### 4.1 Các loại Knowledge File

Mỗi domain expert NÊN có các loại knowledge file sau:

#### K1. Personas — Ai tồn tại trong domain

```markdown
# [Domain] - User Personas

## Persona N: [Tên role]

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| Role | [Chức danh] |
| Experience | [Kinh nghiệm] |
| Report to | [Cấp trên] |
| Focus | [Trọng tâm công việc] |

### Daily Tasks
[Danh sách công việc hàng ngày]

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|

### Pain Points
[Danh sách vấn đề gặp phải]

### Must-have Features
[Danh sách tính năng cần thiết]
```

**Quy tắc:**
- Mỗi persona CÓ profile, tasks, decisions, pain points, must-haves
- 3-6 personas mỗi domain (không quá nhiều)
- Có Access Matrix ở cuối file (ai access gì)
- Đây là FACTS về người dùng — không có hướng dẫn agent

#### K2. Operations — Quy trình vận hành

```markdown
# [Domain] - Operational Analysis Framework

## Core Processes
[Process flows với diagrams]

## Task Frequency Analysis
[Daily / Weekly / Monthly / Quarterly tasks]

## Decision Support Requirements
[Dashboards, Reports cần thiết]

## Integration Touchpoints
[Internal + External integrations]

## KPIs & Metrics
[Formulas, targets, benchmarks]
```

**Quy tắc:**
- Mô tả quy trình THỰC TẾ (as-is), không phải quy trình lý tưởng
- Có diagram (ASCII art) cho process flows chính
- Task frequency analysis có: task, owner, time spent, pain points
- KPIs có formula + target + benchmark
- Đây là FACTS về vận hành — không có hướng dẫn agent

#### K3. Controls — Kiểm soát & phân quyền

```markdown
# [Domain] - Controls & Access Management

## Approval Matrices
[Ai approve gì, theo threshold nào]

## Access Control
[Ai access data/function nào]

## Audit Trail Requirements
[Events cần log, retention period]

## Integration Controls
[Data flow controls, validation rules]
```

**Quy tắc:**
- Approval matrices CÓ thresholds cụ thể (số tiền, %, level)
- Access control CÓ role × data/function matrix
- Audit trail CÓ events + data captured + retention
- Đây là BUSINESS RULES — không phải agent constraints

#### K4. Methodology / Frameworks — Phương pháp chuyên môn

```markdown
# [Domain] - [Framework Name]

## Framework Overview
[Mô tả framework, khi nào áp dụng]

## Components
[Chi tiết từng thành phần]

## Templates
[Mẫu áp dụng]

## Quick Reference
[Bảng tra cứu nhanh]
```

**Quy tắc:**
- Mô tả FRAMEWORK như kiến thức khách quan
- KHÔNG chứa hướng dẫn kiểu "bạn nên..." hay "luôn luôn..."
- Có templates để agent copy-paste khi cần
- Phần "khi nào dùng" → là domain fact (framework X phù hợp tình huống Y)

#### K5. Domain-Specific Topics — Chủ đề chuyên sâu

Ngoài 4 loại core trên, mỗi domain có thể có thêm:

| Domain | Ví dụ topic files |
|--------|-------------------|
| Sales | pipeline-analytics, pre-sales, outbound, account-management |
| Finance | tax-regulations, consolidation, treasury |
| Healthcare | clinical-workflows, compliance, drug-management |
| Logistics | customs-regulations, incoterms, hs-codes |

**Quy tắc:**
- Mỗi file cover 1 topic rõ ràng, không trộn lẫn
- File name = topic name (kebab-case)
- Có header với domain, last_updated, nguồn (nếu có)

### 4.2 Quy tắc chung cho Knowledge Files

#### Nội dung thuần Facts — Không Behavior

```
✅ ĐÚNG (Fact):
"Pipeline Coverage = Open Weighted Pipeline / Remaining Quota. Target: ≥3x."

❌ SAI (Behavior lẫn vào):
"Bạn LUÔN phải kiểm tra pipeline coverage trước khi forecast."
"Silence là tool — sau câu hỏi khó, chờ."
```

Khi cần behavior guidance trong context domain cụ thể, tách thành section riêng
đánh dấu rõ ràng:

```markdown
## Behavioral Notes cho Agent

> ⚠️ Phần này là guidance cho agent, không phải domain fact.
> Xem xét chuyển vào agent definition nếu applicable cho mọi tình huống.

- [Guidance 1]
- [Guidance 2]
```

#### Header chuẩn

```markdown
# [Domain] - [Topic Name]

> **Domain**: [Domain full name] / [Tên tiếng Việt]
> **Last Updated**: [YYYY-MM-DD]
> **Nguồn**: [Nguồn tham khảo nếu có]
```

#### Kích thước

| Metric | Target | Hard Limit |
|--------|--------|------------|
| Mỗi file | 150-300 dòng | 400 |
| Tổng knowledge cho 1 domain | 4-8 files | 12 |

Nếu file vượt 400 dòng → tách thành 2+ files theo sub-topic.

---

## 5. Tiêu chí cho Agent Procedures

File procedure nằm tại `.claude/agents/procedures/[agent-name]/[verb]-[topic].md`

### 5.1 Định nghĩa

Agent Procedure là **Workflow chi tiết cho một loại task cụ thể**, được tách ra khỏi agent file để giữ agent file gọn.

```
Agent file (HOW tổng quát):
  "Khi nhận task, xác định loại task → chọn procedure → follow"

Procedure file (HOW cụ thể):
  "Để làm task X: Bước 1... Bước 2... Cần đọc file A, B... Output là C..."
```

**Phân biệt với Knowledge:**
- Knowledge = "Thế giới vận hành thế nào" (facts, không đổi theo agent)
- Procedure = "Agent làm task X theo trình tự nào" (behavior, gắn với agent)

### 5.2 Khi nào tạo Procedure file

Tạo procedure file khi task có ít nhất 2 trong 3 dấu hiệu:

| Dấu hiệu | Ví dụ |
|----------|-------|
| Task có ≥ 5 bước riêng biệt | Analyze requirements, Design module, Review code |
| Task cần load knowledge files khác nhau tùy context | Lead scoring cần lead-management.md + controls.md |
| Task có output format đặc thù | Feature spec có REQ-IDs, Data model, API list |

Không cần procedure file khi task đơn giản, chỉ 2-3 bước, không có branching.

### 5.3 Cấu trúc file Procedure

```markdown
# Procedure: [Tên task cụ thể]

> **Type**: Agent Procedure
> **Agent**: [agent-name]
> **Triggered when**: [Điều kiện nào thì dùng procedure này]
> **Output**: [Produce gì, lưu ở đâu]

## Khi nào dùng procedure này
[Điều kiện cụ thể, ví dụ module nào, phase nào]

## Procedure

### Bước 1: [Tên bước]
[Hành động + điều kiện + READ instruction nếu cần]

### Bước 2: ...

## Checklist trước khi submit
[Danh sách kiểm tra cuối]
```

### 5.4 Naming Convention

| Element | Convention | Ví dụ |
|---------|-----------|-------|
| Folder | Agent name (không có .md) | `marketing-expert/` |
| File | `[verb]-[topic].md` (kebab-case) | `analyze-requirements.md` |
| Verb | Động từ hành động | `analyze`, `design`, `audit`, `review` |

### 5.5 Giới hạn kích thước

| Metric | Target | Hard Limit |
|--------|--------|------------|
| Mỗi file | 100-150 dòng | 200 |
| Số procedures per agent | 3-7 | 10 |

### 5.6 Quy tắc nội dung

```
✅ ĐÚNG (Procedure):
"Bước 1: Đọc task prompt → xác định module cần thiết kế"
"Bước 3: READ lead-management.md → lấy scoring criteria"
"Bước 5: Viết spec với format: REQ-MKT-LEAD-[NNN]"

❌ SAI — Procedure chứa domain facts:
"Lead Score = Demographic + Behavioral - Decay (công thức đầy đủ...)"
→ Đây là KNOWLEDGE, không phải Procedure. Để trong knowledge file,
   Procedure chỉ ghi: "READ lead-management.md → scoring criteria"

❌ SAI — Procedure quá chung chung:
"Làm tốt task này" / "Phân tích kỹ càng"
→ Procedure phải có bước CỤ THỂ, có thể follow từng bước
```

### 5.7 Procedure Behavioral Enrichment (BẮT BUỘC)

Mọi procedure file PHẢI có 2 thành phần bổ sung theo Behavioral Principles (`.claude/rules/00-behavioral.md`):

#### P1. Success Criteria per bước

Mỗi bước procedure phải xác định "DONE khi nào":

```markdown
### Bước N: [Tên bước]

**Success Criteria:**
□ [Tiêu chí xác định bước này hoàn thành — verify được]
□ [Tiêu chí 2 — cụ thể, không dùng fuzzy terms]

[Hành động cụ thể]
```

**Quy tắc:**
- Success criteria phải OBJECTIVE (có thể verify bằng tool hoặc review)
- Không dùng fuzzy terms ("tốt", "đầy đủ", "chất lượng") — dùng metrics cụ thể
- Mỗi bước có 1-3 criteria
- BHV-004 (Goal-Driven Execution): Xác định "DONE khi nào" TRƯỚC khi bắt đầu

#### P2. Assumption Gate

Trước bước quan trọng (design, implement, architecture decision), thêm:

```markdown
### Bước N: [Tên bước]

**Assumption Gate — DỪNG và hỏi nếu: (BHV-001)**
- [Tình huống ambiguous 1]
- [Tình huống ambiguous 2]

[Hành động cụ thể]
```

**Quy tắc:**
- Assumption Gate chỉ cần ở steps có quyết định quan trọng (không phải mọi bước)
- Reference BHV-001 (Hỏi trước khi giả định)
- Nếu context đã rõ từ upstream docs → skip gate, ghi "Context đã rõ: [source]"
- Gate là behavioral guard, không thay thế PRE-GATE structural checks (CORE-011)

---

## 6. Ranh giới Agent vs Knowledge vs Procedures — Bảng phân định

### 6.1 Bảng phân loại nội dung

| Nội dung | Agent | Knowledge | Procedures | Lý do |
|----------|:-----:|:---------:|:----------:|-------|
| Vai trò, identity | ✅ | | | Gắn với agent cụ thể |
| Danh sách expertise (summary) | ✅ | | | Agent cần biết phạm vi mình |
| Chi tiết từng expertise area | | ✅ | | Domain facts, load on-demand |
| Cách tư duy (perspectives, lenses) | ✅ | | | Mỗi agent tư duy khác nhau |
| Workflow tổng quát (4-5 bước) | ✅ | | | Cách agent hành động mặc định |
| Workflow chi tiết cho task cụ thể | | | ✅ | Tách ra để giữ agent file gọn |
| Quy trình domain thực tế | | ✅ | | Tồn tại bất kể agent nào |
| Knowledge routing (tổng quát) | ✅ | | | Agent cần biết tìm info ở đâu |
| Knowledge routing (per task) | | | ✅ | Routing cụ thể cho task đó |
| Output format (per task type) | | | ✅ | Gắn với procedure cụ thể |
| Coordination rules | ✅ | | | Agent-to-agent interaction |
| Agent constraints (guardrails) | ✅ | | | Behavioral rules |
| Business rules & controls | | ✅ | | Domain rules, bất kể agent |
| Personas chi tiết | | ✅ | | Facts về người dùng |
| KPI formulas & targets | | ✅ | | Domain facts |
| Templates (domain-specific) | | ✅ | | Reusable artifacts |
| Behavioral principles | ✅ | | | Hướng dẫn hành vi |
| Standards chi tiết | | ✅ | | Domain reference |

### 6.2 Ví dụ cụ thể với Marketing domain

| Nội dung cụ thể | Thuộc về | File |
|------------------|----------|------|
| "Tôi nhìn qua Acquisition / Conversion / Retention lens" | Agent | marketing-expert.md |
| "Lead Score = Demographic + Behavioral - Decay" | Knowledge | lead-management.md |
| "Khi nhận task phân tích requirements → đọc playbook X" | Agent | marketing-expert.md (routing) |
| "Bước 1: Đọc project context. Bước 2: Load personas..." | Procedures | analyze-requirements.md |
| "MQL threshold thường là 75-100 điểm" | Knowledge | lead-management.md |
| "KHÔNG gửi email không có consent" | Agent | marketing-expert.md (constraint) |

### 6.3 Xử lý ranh giới mờ

Một số nội dung vừa là domain wisdom vừa là behavioral guidance:

```
"60/40 rule: Buyer nói ≥60% thời gian"
  → Domain fact: Đây là best practice được công nhận trong sales methodology
  → NHƯNG cũng có tính behavioral

QUYẾT ĐỊNH: Giữ trong Knowledge (methodology.md) vì:
1. Đây là industry-recognized principle, không phải invention của agent
2. Nhiều agents có thể cần biết (marketing-expert khi hỗ trợ sales enablement)
3. Agent KHÔNG cần nhớ chi tiết này liên tục — chỉ load khi cần

NHƯNG: Nếu nó critical cho mọi tình huống agent gặp → duplicate 1 dòng summary
vào Agent constraints: "✅ Ưu tiên lắng nghe: buyer phải nói ≥60% trong mọi interaction"
```

**Quy tắc xử lý ranh giới mờ:**

1. **Mặc định → Knowledge** (nếu là industry wisdom / best practice)
2. **Promote lên Agent constraint** nếu: (a) critical cho mọi tình huống, VÀ (b) vi phạm sẽ gây hại
3. **Tách vào Procedures** nếu: là behavior nhưng chỉ áp dụng cho 1 loại task cụ thể
4. Khi promote: viết 1 dòng SUMMARY trong Agent, giữ chi tiết trong Knowledge/Procedures
5. KHÔNG duplicate toàn bộ nội dung

---

## 7. Cấu trúc thư mục

### 7.1 Agent files

```
.claude/agents/
├── [team]/
│   ├── [agent-name].md          # Agent definition
│   └── ...
└── procedures/                  # Agent Procedures (HOW cụ thể per task)
    └── [agent-name]/
        ├── [verb]-[topic].md    # Procedure file
        └── ...
```

Teams: `business/`, `engineering/`, `design/`, `testing/`, `review/`

### 7.2 Knowledge files

```
.claude/references/team-expert/
├── [domain]/
│   ├── personas.md              # K1: Ai tồn tại
│   ├── operations.md            # K2: Quy trình vận hành
│   ├── controls.md              # K3: Kiểm soát & phân quyền
│   ├── [methodology].md         # K4: Framework/methodology
│   └── [topic].md               # K5: Chủ đề chuyên sâu
```

### 7.3 Mapping Agent → Knowledge → Procedures

| Agent | Knowledge folder | Procedures folder |
|-------|-----------------|-------------------|
| `business/marketing-expert.md` | `references/team-expert/marketing/` | `agents/procedures/marketing-expert/` |
| `business/sales-expert.md` | `references/team-expert/sales/` | `agents/procedures/sales-expert/` (nếu có) |
| `business/finance-expert.md` | `references/team-expert/finance/` | `agents/procedures/finance-expert/` (nếu có) |

**Quy tắc:**
- 1 business expert agent = 1 knowledge domain folder + 1 procedures folder (nếu cần)
- Procedures folder chỉ tạo khi agent có ≥ 2 procedure files
- Folder name = agent name (không có `.md`)
- Không bắt buộc mọi agent đều có procedures folder
  (utility agents như `developer`, `devops` thường không cần)

---

## 8. Quy trình tạo Agent mới

### Bước 1: Xác định scope

```
Trả lời 5 câu hỏi:
1. Agent thuộc team nào? (business / engineering / design / testing / review)
2. Domain/specialty cụ thể là gì?
3. Agent có CẦN knowledge riêng không? (business experts: có; utility agents: không)
4. Agent có CẦN procedures không? (task phức tạp, nhiều loại task: có; utility agents: không)
5. Agent phối hợp với agents nào?
```

### Bước 2: Tạo Knowledge files TRƯỚC

```
Nếu cần knowledge:
1. Tạo folder: .claude/references/team-expert/[domain]/
2. Tạo personas.md (K1) — ai tồn tại
3. Tạo operations.md (K2) — quy trình vận hành
4. Tạo controls.md (K3) — kiểm soát & phân quyền
5. Tạo thêm topic files (K4, K5) nếu domain phức tạp
6. Review: mỗi file chỉ chứa FACTS, không chứa behavior
```

**Tại sao Knowledge trước?**
- Buộc phải nghiên cứu domain TRƯỚC khi viết agent
- Tránh viết agent "tưởng tượng" không có kiến thức backing

### Bước 2b: Tạo Procedure files (nếu cần)

```
Nếu agent có task types phức tạp (≥5 bước, có branching):
1. Liệt kê các task types agent sẽ thực hiện
2. Với mỗi task type có ≥5 bước: tạo procedure file riêng
3. Tạo folder: .claude/agents/procedures/[agent-name]/
4. Tạo [verb]-[topic].md theo cấu trúc mục 5.3
5. Review: chứa behavior (steps), không chứa domain facts
```

**Tại sao Procedures sau Knowledge?**
- Procedure files cần READ instruction đến knowledge files cụ thể
- Phải biết knowledge files tồn tại trước khi viết procedure

### Bước 3: Tạo Agent definition

```
1. Copy template: .claude/agents/spec/agent-definition-template.md
2. Đặt tại: .claude/agents/[team]/[agent-name].md
3. Điền từng phần theo tiêu chí mục 3
4. Workflow: 4-5 bước tổng quát, trỏ đến procedures (nếu có)
5. Knowledge routing: pointer đến files đã tạo ở Bước 2
6. Skill Playbooks: pointer đến procedures ở Bước 2b (nếu có)
7. Review: mỗi phần không vượt giới hạn kích thước
```

### Bước 4: Đăng ký

```
1. Update .claude/agents/README.md — thêm agent vào bảng
2. Update .claude/agents/orchestrator.md — thêm routing rules
3. Update CLAUDE.md — nếu agent thuộc team mới
```

### Bước 5: Validate

```
Chạy checklist đánh giá (mục 10)
```

---

## 9. Anti-Patterns — Lỗi thường gặp

### 9.1 Agent Anti-Patterns

| # | Anti-Pattern | Vấn đề | Khắc phục |
|---|-------------|---------|-----------|
| AP-1 | **Knowledge Dump** — Agent chứa chi tiết domain | Phình context window, info outdated | Chuyển sang Knowledge files |
| AP-2 | **Workflow trống** — Agent không có workflow rõ ràng | Agent không biết phải làm gì | Viết 5-7 bước cụ thể |
| AP-3 | **No Routing** — Agent không pointer đến knowledge | Agent không biết tìm info ở đâu | Thêm Knowledge Routing table |
| AP-4 | **Constraint thiếu** — Không có constraints | Agent có thể làm sai mà không biết | Thêm 3-6 PHẢI + 3-6 CẤM |
| AP-5 | **Island Agent** — Không coordination rules | Agent không biết phối hợp với ai | Thêm Coordination table |
| AP-6 | **Redundant Standards** — Copy bảng Standards chi tiết | Trùng lặp với knowledge | Giữ summary, detail → Knowledge |
| AP-7 | **Vague Identity** — "Chuyên gia về X" mà không nói perspective | Không phân biệt với agent khác | Thêm Cognitive Framework rõ ràng |

### 9.2 Knowledge Anti-Patterns

| # | Anti-Pattern | Vấn đề | Khắc phục |
|---|-------------|---------|-----------|
| KP-1 | **Behavior Leak** — "Bạn nên...", "Luôn luôn..." | Knowledge chỉ đạo agent | Tách behavior → Agent constraints |
| KP-2 | **Stale Data** — Không có last_updated | Không biết data còn đúng không | Thêm header với last_updated |
| KP-3 | **Monolith File** — 1 file > 400 dòng | Khó maintain, load chậm | Tách theo sub-topic |
| KP-4 | **Orphan File** — Knowledge file không agent nào pointer | File bị lãng quên, outdated | Đảm bảo mọi file có ≥1 agent routing |
| KP-5 | **Missing Personas** — Domain không có personas file | Agent không biết thiết kế cho ai | Tạo personas.md với ≥3 personas |
| KP-6 | **Abstract Facts** — Chỉ lý thuyết, không template | Agent không biết apply thế nào | Thêm templates, examples cụ thể |
| KP-7 | **Mixed Topics** — 1 file chứa nhiều topics không liên quan | Khó tìm, khó maintain | Tách thành files riêng theo topic |

### 9.3 Procedure Anti-Patterns

| # | Anti-Pattern | Vấn đề | Khắc phục |
|---|-------------|---------|-----------|
| PP-1 | **Fact Dump** — Procedure chứa domain facts thay vì READ instruction | Trùng lặp với knowledge, outdated | Thay bằng "READ [file].md → lấy [thứ cần]" |
| PP-2 | **God Procedure** — 1 procedure file cho mọi task types | Quá dài, không focused | Tách thành files riêng theo task type |
| PP-3 | **Missing Trigger** — Không có "Khi nào dùng" | Agent không biết khi nào gọi | Thêm trigger conditions rõ ràng |
| PP-4 | **Vague Steps** — Bước không actionable ("phân tích kỹ", "làm tốt") | Agent không biết làm gì | Mỗi bước = 1 hành động cụ thể + input/output |
| PP-5 | **Orphan Procedure** — Agent file không pointer đến procedure | Procedure bị bỏ qua | Đảm bảo có Skill Playbooks table trong agent |
| PP-6 | **Wrong Location** — Procedure để trong references/ thay vì agents/procedures/ | Vi phạm separation of concerns | Move về `agents/procedures/[agent-name]/` |

---

## 10. Checklist đánh giá

### 10.1 Agent Checklist

```
AGENT: [agent-name]
DATE: [YYYY-MM-DD]
REVIEWER: [name]

FRONTMATTER
[ ] name khớp filename
[ ] version đúng SemVer
[ ] description có "Proactively invoke khi..."
[ ] tools chỉ liệt kê tools cần thiết
[ ] model phù hợp complexity

IDENTITY (A2)
[ ] ≤5 dòng
[ ] Nêu rõ góc nhìn đặc trưng
[ ] Không lặp frontmatter description

EXPERTISE (A3)
[ ] 5-10 items, mỗi item ≤1 dòng
[ ] Chỉ summary, không chi tiết
[ ] Cover phạm vi agent cần operate

COGNITIVE FRAMEWORK (A4)
[ ] Có perspective/lens rõ ràng
[ ] Phân biệt được với agent khác cùng domain
[ ] Không chứa domain facts

WORKFLOW (A5)
[ ] 5-7 bước, mỗi bước có input/output
[ ] Mỗi bước có READ instruction khi cần
[ ] Có fallback path
[ ] Bước cuối có output format/location
[ ] ≤60 dòng

KNOWLEDGE ROUTING (A6)
[ ] Mỗi knowledge file có 1 pointer
[ ] Cột "Khi cần" mô tả tình huống, không phải tên file
[ ] Đường dẫn chính xác (file tồn tại)
[ ] Không có knowledge file orphan

COORDINATION (A7)
[ ] Liệt kê agents thực sự cần phối hợp
[ ] Dấu hiệu trigger đủ cụ thể

CONSTRAINTS (A8)
[ ] 3-6 rules BẮT BUỘC
[ ] 3-6 rules CẤM
[ ] Mỗi constraint actionable
[ ] Không trùng với business rules trong Knowledge

KÍCH THƯỚC
[ ] Tổng ≤250 dòng
[ ] Không có section nào vượt hard limit

KHÔNG CÓ ANTI-PATTERNS
[ ] Không Knowledge Dump (AP-1)
[ ] Không Workflow trống (AP-2)
[ ] Không Island Agent (AP-5)
[ ] Không Vague Identity (AP-7)
```

### 10.2 Knowledge Checklist

```
DOMAIN: [domain-name]
DATE: [YYYY-MM-DD]
REVIEWER: [name]

CẤU TRÚC
[ ] Có personas.md (K1)
[ ] Có operations.md (K2)
[ ] Có controls.md (K3)
[ ] Có methodology/topic files nếu cần (K4, K5)
[ ] Mỗi file ≤400 dòng

HEADER
[ ] Mỗi file có domain, last_updated
[ ] Nguồn tham khảo nếu applicable

NỘI DUNG
[ ] Chỉ chứa FACTS — không có behavioral guidance
[ ] Personas có: profile, tasks, decisions, pain points, must-haves
[ ] Operations có: process flows, task frequency, KPIs
[ ] Controls có: approval matrices, access matrix, audit trail
[ ] Có templates/examples cụ thể (không chỉ lý thuyết)

KHÔNG CÓ ANTI-PATTERNS
[ ] Không Behavior Leak (KP-1)
[ ] Không Monolith File (KP-3)
[ ] Không Orphan File (KP-4)
[ ] Không Missing Personas (KP-5)
[ ] Không Mixed Topics (KP-7)

ROUTING
[ ] Mọi file đều có ≥1 agent pointer đến
[ ] Đường dẫn trong agent routing khớp đường dẫn thực tế
```

### 10.3 Procedure Checklist

```
AGENT: [agent-name]
DATE: [YYYY-MM-DD]

CẤU TRÚC
[ ] File đặt tại: .claude/agents/procedures/[agent-name]/[verb]-[topic].md
[ ] Header có: Type, Agent, Triggered when, Output
[ ] Có section "Khi nào dùng procedure này"
[ ] Mỗi bước có hành động cụ thể (không vague)
[ ] File ≤200 dòng

NỘI DUNG
[ ] Chứa behavior (steps) — không chứa domain facts
[ ] READ instructions trỏ đúng đến knowledge files tồn tại
[ ] Có checklist hoặc output format ở cuối

ROUTING
[ ] Agent file có pointer đến procedure này trong Skill Playbooks table
[ ] Trigger condition đủ rõ để agent biết khi nào gọi

KHÔNG CÓ ANTI-PATTERNS
[ ] Không Fact Dump (PP-1)
[ ] Không God Procedure (PP-2)
[ ] Không Vague Steps (PP-4)
[ ] Không Orphan Procedure (PP-5)
```

---

## 11. Ví dụ tham chiếu

### 11.1 Agent tốt: marketing-expert (v4.0.0)

Xem [agent-definition-template.md](agent-definition-template.md) cho template chuẩn.

**Điểm tốt hiện tại:**
- Identity rõ ràng
- Dual Perspective Framework (Cognitive Framework) — phân biệt rõ
- Workflow 5 bước, có fallback
- Knowledge routing đầy đủ
- Coordination rules cụ thể
- Constraints actionable

**Điểm cần cải thiện:**
- Standards & Frameworks table → nên bỏ (đã có trong methodology.md)
- Expertise section → có thể gọn hơn (vài mục quá chi tiết)

### 11.2 Knowledge tốt: sales/controls.md

**Điểm tốt:**
- Approval matrices có thresholds cụ thể (%, VND)
- Access control matrix rõ ràng (role × data)
- Audit trail đầy đủ (events + retention)
- Không có behavioral guidance

### 11.3 Knowledge cần sửa: sales/methodology.md

**Vấn đề:** Chứa behavioral guidance lẫn với domain facts

```markdown
# Trong methodology.md hiện tại:

## Nguyên tắc Discovery
- 60/40 rule: Buyer nói ≥60% thời gian. Nếu bạn nói >40% → đang pitch...
- Silence là tool: Sau câu hỏi khó, chờ...
- Qualify out nhanh: Deal không có real pain... → không phải deal.

→ "60/40 rule" là domain fact (keep)
→ "Silence là tool" là behavioral guidance (move hoặc mark)
→ "Qualify out nhanh" — hỗn hợp: principle = fact, "→ không phải deal" = judgment
```

**Khắc phục:** Giữ principles là facts, đánh dấu behavioral notes rõ ràng, hoặc chuyển phần behavior vào agent.

---

### 10.4 Special Agent Types — Ngoại lệ kiểm tra

Một số agent types có cấu trúc đặc biệt và KHÔNG áp dụng đầy đủ checklist A1-A9.

#### Orchestrator Agent (`orchestrator.md`)

| Criterion | Áp dụng? | Lý do ngoại lệ |
|-----------|----------|----------------|
| A1 Frontmatter | ✅ | Bắt buộc |
| A2 Identity | ✅ | Bắt buộc |
| A3 Expertise | ✅ | Bắt buộc (danh sách coordination capabilities) |
| A4 Cognitive Framework | ✅ | Bắt buộc |
| A5 Workflow | ✅ | Bắt buộc |
| A6 Knowledge Routing | ❌ **Skip** | Orchestrator không có domain knowledge riêng — consumes path-registry.md và agent-coordination.md như external references, không phải domain knowledge |
| A7 Coordination | ✅ | Bắt buộc |
| A8 Constraints | ✅ | Bắt buộc |
| A9 Size ≤250 | ✅ | Bắt buộc |

#### Review Agents (`review/` — agent-auditor, skill-auditor, template-auditor, cross-reference-auditor, workflow-auditor, review-orchestrator)

| Criterion | Áp dụng? | Lý do ngoại lệ |
|-----------|----------|----------------|
| A1-A5, A7-A9 | ✅ | Bắt buộc |
| A6 Knowledge Routing | ❌ **Skip** | Review agents kiểm tra DEVKIT structure — không cần external domain knowledge. Spec và templates được đọc trực tiếp tại audit time, không cần pre-declared routing |

---

## Changelog

### v2.0.0 (2026-03-16)
- Thêm khái niệm thứ 3: **Agent Procedures** (HOW cụ thể per task)
- Section 5 mới: Tiêu chí cho Agent Procedures (cấu trúc, naming, giới hạn)
- Cập nhật Section 1.1: mô hình 3 khái niệm (Agent + Knowledge + Procedures)
- Cập nhật Litmus Test: thêm Procedure entries vào Phép thử 3
- Cập nhật Ranh giới bảng: thêm cột Procedures
- Cập nhật Directory Structure: thêm `agents/procedures/[agent-name]/`
- Cập nhật Creation Workflow: thêm Bước 2b cho Procedures
- Thêm 6 Procedure Anti-Patterns (PP-1 đến PP-6)
- Thêm Procedure Checklist (10.3)
- Reference implementation: `marketing-expert` với procedures tại `agents/procedures/marketing-expert/`

### v1.0.0 (2026-03-15)
- Tạo bộ tiêu chí chính thức ban đầu
- 3 phép thử phân loại
- 9 tiêu chí Agent (A1-A9)
- 5 loại Knowledge (K1-K5)
- 7 Agent anti-patterns, 7 Knowledge anti-patterns
- Checklist đánh giá đầy đủ
