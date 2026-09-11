# 03 — Agent Standard (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC (CORE-037, CORE-029)
> **File spec canonical:** [`.claude/agents/spec/README.md`](../../.claude/agents/spec/README.md)
> **Mục đích:** Định nghĩa **cấu trúc bắt buộc** cho agent definition + knowledge files + procedures

---

## 1. Khái niệm — agent trong MCV3

**Agent ≠ Skill.**

| | Skill | Agent |
|---|-------|-------|
| User gọi | Trực tiếp qua `/command` | Không — skill spawn |
| Vai trò | Orchestrator (điều phối phase, gates, contracts) | Chuyên gia (analysis, design, code, review) |
| Vị trí | `.claude/skills/workflow/{skill}/SKILL.md` | `.claude/agents/{team}/{agent}.md` |
| Số lượng MCV3 | 43 skills | 62 agents (5 teams + orchestrator) |
| Cấu trúc | SKILL.md + procedures + templates | Agent file + knowledge files + procedures |

**Nguyên tắc:** Skill **spawn** agent qua `Agent` tool với `subagent_type` = tên file agent (không `.md`).

---

## 2. Năm đội + Orchestrator

| Đội | Vị trí | Số lượng | Vai trò |
|-----|--------|----------|---------|
| **Business** | `.claude/agents/business/` | 25 | BA + 24 domain experts (finance, healthcare, retail, logistics, ...) |
| **Engineering** | `.claude/agents/engineering/` | 14 | architect, developer, devops, security, embedded-engineer, ... |
| **Design** | `.claude/agents/design/` | 7 | UX/UI design |
| **Testing** | `.claude/agents/testing/` | 9 | QA, code review, performance, accessibility, ... |
| **Review** | `.claude/agents/review/` | 6 | DEVKIT self-quality (agent-auditor, skill-auditor, ...) |
| **Orchestrator** | `.claude/agents/orchestrator.md` | 1 | Điều phối giữa các đội |

Chi tiết tại [`../01-architecture/08-agents-catalog.md`](../01-architecture/08-agents-catalog.md).

---

## 3. Cấu trúc agent definition file

File: `.claude/agents/{team}/{agent-name}.md`

```markdown
---
name: {agent-name}
description: |
  {Mô tả 2-3 câu — khi nào dùng agent này}
  {Domain expertise, scope, không-được làm}

  Use khi: {triggers}
  Proactively invoke khi phát hiện keywords: {comma-separated}
tools: {comma-separated tool list, KHÔNG có Agent}
---

# {Agent Display Name}

> {1-line tagline}

## Vai trò

{Description chi tiết: domain, expertise, mục tiêu}

## Knowledge

Agent này truy cập knowledge files tại:
- `.claude/references/team-expert/{domain}/` ({N} files)
- `.claude/agents/procedures/{agent-name}/` (HOW chi tiết per task)

## Quy tắc

- {Rule 1 — KHÔNG được làm}
- {Rule 2 — Tuân thủ output schema từ skill caller}
- {Rule 3 — Domain-specific compliance}

## Output

- {Output format expected từ task}
- {Quality gates per output}
```

**Quy tắc:**
- Tên file = giá trị `subagent_type` (không `.md`)
- `description` PHẢI rõ về **trigger keywords** — Claude Code dùng để auto-route
- `tools` KHÔNG bao gồm `Agent` (chỉ skill được spawn agent, agent không spawn agent khác)
- Frontmatter `name` PHẢI khớp tên file

---

## 4. Knowledge files (`.claude/references/team-expert/`)

Mỗi agent business/engineering domain có folder knowledge tại `.claude/references/team-expert/{domain}/`.

```
.claude/references/team-expert/
├── finance/
│   ├── accounting-standards.md          # IFRS, GAAP, VAS
│   ├── erp-finance-modules.md           # AR, AP, GL, FA, CB
│   ├── tax-compliance-vietnam.md
│   └── ...
├── healthcare/
│   ├── emr-standards.md
│   ├── hl7-fhir.md
│   ├── bhyt-vietnam.md
│   └── ...
└── ... (29 domains)
```

**Quy tắc knowledge:**
- 1 file = 1 chủ đề chuyên sâu, ~200-800 dòng
- Tiếng Việt cho concepts/terminology địa phương, English cho international standards
- Format: định nghĩa → ví dụ → liên kết tài liệu chính thức
- KHÔNG duplicate code — knowledge là tham chiếu, không executable

---

## 5. Procedures files (`.claude/agents/procedures/`)

Mỗi agent có folder procedures cho task chi tiết:

```
.claude/agents/procedures/{agent-name}/
├── analyze-requirements.md
├── design-architecture.md
├── implement-feature.md
└── ...
```

**Quy tắc procedures:**
- 1 file = 1 task type (vd: "phân tích yêu cầu", "design API")
- Format step-by-step, có Inputs / Outputs / Quality gates
- Sử dụng khi skill cần agent thực thi task cụ thể

---

## 6. Agent Spawn Pattern (CORE-037) — 8 sections

Khi skill spawn agent, prompt PHẢI có 8 sections:

```markdown
# 1. Role declaration
Bạn là [role] cho skill [skill-name].

# 2. Task instruction
Đọc file [SKILL.md hoặc procedure file path] và thực thi đầy đủ task [task name].

# 3. Session context
SESSION_DIR: [path]
PROFILE: [quick|standard|deep|exhaustive]
SCOPE: [scope]
NAME: [target name nếu có]

# 4. CI context injection (nếu CI available)
GitNexus available: [YES|NO]
Serena available: [YES|NO]
Index freshness: [ok|light|strong|severe]
[$CI_CONTEXT chi tiết]

# 5. Playwright context (nếu applicable)
Mode: [none|assisted|full]
Devices: [desktop, tablet, mobile]
Base URL: [http://localhost:3000]

# 6. Output contract
Path: [exact file path]
Schema: [schema reference từ _contract.json]
Template: [.claude/skills/.../templates/file.md]

# 7. Ownership rules
- Agent này CHỈ ghi [file path]
- KHÔNG đụng [list các file của agent khác]
- 1 file = 1 writer

# 8. Completion criteria
Khi hoàn tất, outputs PHẢI:
- Pass POST-GATE T1→T4
- File từ template, đã strip metadata (_template_notes)
- Trace được về REQ-ID/FEAT-ID upstream
```

Template chuẩn + ví dụ tại [`../03-design-patterns/05-agent-prompt-template.md`](../03-design-patterns/05-agent-prompt-template.md).

---

## 7. Spawn rules

```
Spawn với:
  - model = "opus" (Sonnet quota hết → fallback opus)
  - max concurrency = 10 agents (CORE-025)
  - 1 file = 1 writer

Trước khi spawn:
  - PRE-GATE pass cho phase hiện tại
  - CI context prepared (Na/Nb/Nc done)
  - Output paths định nghĩa trong _contract.json

Sau khi agent return:
  - Spot-check output (CORE-029) — validate schema, không silent merge
  - POST-GATE T1→T4 trên output files
```

---

## 8. Agent Output Spot-Check (CORE-029)

Skill spawning agent PHẢI kiểm tra output trước khi advance:

```
1. T1: File output tồn tại? (test -f)
2. T2: Schema valid? (jq '.' cho JSON, markdown structure cho .md)
3. T3: Content depth đủ? (≥X dòng, ≥Y keys, ...)
4. Cross-ref: REQ-ID/FEAT-ID khớp upstream registry?

NẾU FAIL → re-spawn agent với enhanced prompt (giải thích lỗi)
```

---

## 9. Checklist khi tạo agent mới

**Trước khi merge:**

- [ ] Tạo file `.claude/agents/{team}/{agent-name}.md` với frontmatter đầy đủ
- [ ] `description` có triggers + keywords rõ
- [ ] `tools` không bao gồm `Agent`
- [ ] Knowledge files (nếu có domain) tại `.claude/references/team-expert/{domain}/`
- [ ] Procedures files (nếu cần per-task) tại `.claude/agents/procedures/{agent-name}/`
- [ ] Cập nhật `01-architecture/08-agents-catalog.md`
- [ ] Test với 1 skill spawn agent này — pass POST-GATE
- [ ] Tạo `docs/04-skill-design/...` nếu là agent dành riêng cho skill nào đó (optional)
- [ ] Chạy `./.claude/scripts/audit-agents/...` (nếu có) — PASS

---

## 10. Anti-patterns — KHÔNG được làm

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Agent có `Agent` trong tools (spawn agent khác) | Chỉ skill được spawn agent |
| Tên file `business_analyst.md` (snake_case) | `business-analyst.md` (kebab-case) |
| Description mơ hồ "I help with business stuff" | Trigger keywords + use cases rõ ràng |
| Knowledge file >2000 dòng | Tách thành nhiều file theo chủ đề |
| Agent prompt thiếu section 7 (Ownership) | Đủ 8 sections (CORE-037) |
| 2 agents song song cùng ghi 1 output | 1 file = 1 writer |
| Spot-check bị bỏ qua → silent merge output xấu | CORE-029 spot-check trước advance |
| Agent tự update registry | Chỉ skill update registry (Safe-Write CORE-006) |

---

## 11. Khi nào tạo agent mới?

**TẠO mới khi:**
- Domain mới không có agent expert (vd: thêm domain "agriculture", "education")
- Vai trò mới không phù hợp đội hiện có (rare — đa số role đã có)
- Workflow cần agent specialized chưa tồn tại

**KHÔNG tạo mới khi:**
- Chỉ cần thêm knowledge — bổ sung file vào `team-expert/{domain}/` đủ
- Chỉ cần thêm task type — bổ sung procedure vào `agents/procedures/{agent}/`
- Agent có sẵn cover được — extend mô tả/knowledge

---

## 12. Đánh giá tuân thủ

Script `./.claude/scripts/audit-agents/...` (nếu có) kiểm tra:

- ✅ Frontmatter đầy đủ (`name`, `description`, `tools`)
- ✅ Tên file khớp `name` field
- ✅ Description có triggers
- ✅ Knowledge files có cấu trúc đúng
- ✅ Không có agent thuộc 2 đội cùng lúc

---

## 13. Liên kết

- **Spec canonical:** [`.claude/agents/spec/README.md`](../../.claude/agents/spec/README.md)
- **Agent template:** [`.claude/agents/spec/agent-definition-template.md`](../../.claude/agents/spec/agent-definition-template.md)
- **Knowledge template:** [`.claude/agents/spec/knowledge-template.md`](../../.claude/agents/spec/knowledge-template.md)
- **Agents catalog:** [`../01-architecture/08-agents-catalog.md`](../01-architecture/08-agents-catalog.md)
- **Agent prompt template (8 sections):** [`../03-design-patterns/05-agent-prompt-template.md`](../03-design-patterns/05-agent-prompt-template.md)
- **CORE rules liên quan:** CORE-025 (concurrency), CORE-029 (spot-check), CORE-037 (prompt template)
