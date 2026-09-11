# 01 — Kiến trúc 2 lớp MCV3

> **Mức độ ràng buộc:** Tham khảo (overview) — nắm vững trước khi đọc các tài liệu kiến trúc khác
> **Mục đích:** Mô tả 2 lớp chính của MCV3 (Skills + Agents) và 4 thành phần hỗ trợ (Hooks, Rules, References, Doc-framework) — cách chúng kết hợp khi user gọi 1 lệnh `/`

---

## 1. Tổng quan kiến trúc

MCV3 được tổ chức thành **2 lớp thực thi** + **4 thành phần hỗ trợ**:

```
┌─────────────────────────────────────────────────────────────────┐
│                          USER                                    │
│                  (gõ lệnh /wf-xxx hoặc /...)                    │
└──────────────────────────────┬──────────────────────────────────┘
                               │
              ┌────────────────▼─────────────────┐
              │      LỚP 1 — SKILLS (Lệnh)       │
              │  .claude/skills/workflow/        │
              │  43 wf-* skills + workflows/      │
              │  Skill = orchestration, không    │
              │  trực tiếp viết code             │
              └────────────────┬─────────────────┘
                               │ spawn (Agent tool)
              ┌────────────────▼─────────────────┐
              │      LỚP 2 — AGENTS (Thực thi)   │
              │  .claude/agents/                  │
              │  62 chuyên gia ảo (5 teams)      │
              │  Đọc/viết file, phân tích, code  │
              └────────────────┬─────────────────┘
                               │ ghi/đọc
              ┌────────────────▼─────────────────┐
              │      DỮ LIỆU DỰ ÁN               │
              │  .mc-data/docs/ + .mc-data/work/ │
              │  SSOT: req-registry.json         │
              └──────────────────────────────────┘

     Bao quanh là 4 thành phần hỗ trợ:
     ├─ Hooks (PreToolUse, PostToolUse, Stop)
     ├─ Rules (38 CORE + 4 BHV + 7 path-scoped)
     ├─ References (162 file domain knowledge)
     └─ Doc-framework (40 template + 20 schema)
```

**Tinh thần:**
- Skill = **đạo diễn** (orchestrator), KHÔNG trực tiếp đụng code
- Agent = **chuyên gia thực hiện** (executor), được spawn bởi skill
- 2 lớp tách biệt → mỗi lớp tự cải tiến mà không phá lớp kia

---

## 2. Lớp 1 — Skills

### 2.1. Skill là gì?

**Skill** là 1 đơn vị workflow đầy đủ (vd: `/wf-analyze-requirements`, `/wf-fix-bugs`). User gõ lệnh `/` → Claude Code load skill tương ứng → skill thực thi pipeline.

```
.claude/skills/workflow/{skill-name}/
├── SKILL.md                    ← Lean routing hub ≤500 dòng (CORE-032)
├── _contract.json              ← Schema "$schema": "skill-contract-v1"
├── procedures/                 ← Lazy-load execution logic
│   ├── _shared.md
│   ├── phase{N}-{name}.md      ← Chi tiết per phase
│   └── resume-status.md
├── templates/                  ← Output file templates
├── evals/                      ← Test cases ≥3
└── scripts/                    ← Bash/Python helpers
```

**Lý do tách `SKILL.md` ≤500 dòng:** Khi user gọi `/wf-fix-bugs`, Claude chỉ load `SKILL.md`. Logic chi tiết per phase load on-demand → giảm 70%+ context. Xem [`../02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md).

### 2.2. Phân loại Skills

| Loại | Folder | Count | Vai trò |
|------|--------|-------|---------|
| **Workflow skills** | `workflow/` | 43 wf-* | Mỗi phase / mỗi tác vụ |
| **Orchestrator workflows** | `workflows/` | 3 | `new-project`, `existing-project`, `feature-addition` — gọi chuỗi skills |
| **Standalone** | `workflow/` | 2 | `wf-scan-target`, `wf-diagram` — không thuộc main pipeline |
| **Utility** | `workflow/_shared/` | — | Python package, KHÔNG phải skill (utilities) |
| **Status tracking** | `workflow/status/` | 1 | `/status` — đọc tiến độ |

### 2.3. 7 phases chính

```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
Brainstorm  Business   Features  Architecture  UX     Implementation  Deployment
```

Mỗi phase có ≥1 skill phụ trách. Chi tiết tại [`02-workflow-model.md`](02-workflow-model.md) và [`07-skills-catalog.md`](07-skills-catalog.md).

### 2.4. Phân loại theo function

| Nhóm | Skills | Mục đích |
|------|--------|----------|
| Main pipeline | wf-brainstorm → wf-prepare-deployment | 7 phases chính |
| Fix Bugs | wf-fix-bugs + 11 lane skills (QD1-QD11) | Đa-dimension bug detection |
| E2E Testing | 9 wf-e2e-* skills | Live test cycle |
| Legacy | wf-legacy-scan, wf-legacy-classify, wf-legacy-extract, wf-annotate-code | Dự án có sẵn |
| Change Mgmt | wf-add-scope, wf-manage-change | Bổ sung/sửa đổi |
| Quality Gates | wf-preflight, wf-verify-sync | Health check + sync |
| Standalone | wf-scan-target, wf-diagram | Tool độc lập |

---

## 3. Lớp 2 — Agents

### 3.1. Agent là gì?

**Agent** là 1 chuyên gia ảo có domain knowledge + procedures cụ thể. Skill spawn agent qua `Agent` tool:

```python
Agent(
  description="...",
  subagent_type="business-analyst",  # tên file agent (không .md)
  prompt="""Bạn là BA cho {skill}...
  [8 sections theo CORE-037]"""
)
```

```
.claude/agents/{category}/{agent-name}.md
                          └─ tên file = subagent_type
```

### 3.2. 5 teams + orchestrator

| Team | Folder | Count | Vai trò |
|------|--------|-------|---------|
| **Business** | `business/` | 25 | BA + 24 domain experts (healthcare, finance, education, ...) |
| **Engineering** | `engineering/` | 14 | architect, developer, devops, security, dba, sre, ai-engineer, frontend, mobile, embedded-engineer, ... |
| **Design** | `design/` | 7 | ui-designer, ux-designer, ux-architect, ux-researcher, brand-guardian, ... |
| **Testing** | `testing/` | 9 | qa-lead, code-reviewer, api-tester, performance-benchmarker, model-qa, ... |
| **Review** | `review/` | 7 | DEVKIT self-quality: agent-auditor, skill-auditor, ... |
| **Orchestrator** | `orchestrator.md` | 1 | Điều phối giữa các team |

**Tổng:** ~62 agents (số chính xác có thể chênh do README, _shared files).

### 3.3. Agent definition structure

Mỗi agent file có:

```markdown
---
name: {agent-name}
description: {khi nào dùng + proactive triggers}
tools: [danh sách tools agent được phép dùng]
---

# {Agent Name}

## Role
{Mô tả role}

## Knowledge
- {reference} → `.claude/references/team-expert/{domain}/`
- {procedure} → `.claude/agents/procedures/{agent-name}/`

## When to use
{triggers + proactive invoke conditions}

## When NOT to use
{ranh giới rõ ràng vs agent khác}
```

Chi tiết tại [`../02-standards/03-agent-standard.md`](../02-standards/03-agent-standard.md).

### 3.4. Knowledge & Procedures (Lớp 2.5)

Agent KHÔNG chứa hết knowledge — tách thành:

| Loại | Vị trí | Mục đích |
|------|--------|----------|
| **Domain knowledge** | `.claude/references/team-expert/{domain}/` | 162 file kiến thức nghiệp vụ per domain (29 domains) |
| **Agent procedures** | `.claude/agents/procedures/{agent-name}/` | 61 thư mục — HOW chi tiết per task |

Khi agent được spawn → đọc skill SKILL.md → reference tới procedures khi cần. Pattern giống lazy-load của skills.

---

## 4. Thành phần hỗ trợ

### 4.1. Hooks (`.claude/hooks/`)

Hooks là **shell scripts** chạy tự động khi Claude Code phát sự kiện. KHÔNG phải skill, KHÔNG phải agent — là **gác cổng tự động**.

| Hook | Trigger | Mục đích |
|------|---------|----------|
| `session-init.sh` | SessionStart | Khởi tạo session context |
| `privacy-block.sh` | PreToolUse (Read) | Chặn đọc `.env`, secrets |
| `scout-block.sh` | PreToolUse (Glob) | Chặn scan ngoài scope |
| `pre-bash-safety.sh` | PreToolUse (Bash) | Chặn lệnh nguy hiểm (`rm -rf /`) |
| `validate-requirement-sync.sh` | PreToolUse (Write/Edit) | Cảnh báo nếu code thiếu REQ-ID |
| `validate-critical-decision.sh` | PreToolUse (Write/Edit) | WARNING cho hành động CDG |
| `update-sync-status.sh` | PostToolUse (Write/Edit) | Update sync tracking |
| `validate-contract-sync.sh` | PostToolUse (Write/Edit) | Validate với registry |
| `validate-ui-component.sh` | PostToolUse (Write/Edit) | UI quality checks |
| `validate-naming-convention.sh` | PostToolUse (Write/Edit) | kebab-case enforcement |
| `stop-session-verify.sh` | Stop | Verify sync trước khi kết thúc |

Chi tiết tại [`05-hooks-and-gates.md`](05-hooks-and-gates.md).

### 4.2. Rules (`.claude/rules/`)

Rules là **constraint mặc định** auto-load theo path scope.

| Rule | Scope auto-load | Mô tả |
|------|-----------------|-------|
| `00-behavioral` | Mọi conversation | 4 BHV principles (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution) |
| `00-core` | Mọi conversation | 38 CORE rules (CORE-001 → CORE-038) |
| `01-coding` | `**/*.{ts,tsx,js,jsx,py,java,cs,go,rs}` | Coding standards |
| `02-api` | `**/*.controller.ts`, `**/api/**` | API conventions |
| `03-security` | Same as 01-coding | Security rules (OWASP) |
| `04-i18n` | `**/*.{tsx,jsx,vue,svelte}` | i18n / i18n keys |
| `05-database` | `**/*.{repository,migration,schema,entity,model}.ts`, `**/*.sql` | DB conventions |
| `06-domain` | Mọi conversation | Domain expert routing |
| `07-project` | Mọi conversation | MCV3 project-specific |

Rules **KHÔNG** chạy code — chúng là context auto-inject vào Claude. Skill/agent phải tự tuân thủ.

### 4.3. References (`.claude/references/`)

Domain knowledge cho 29 domains. Mỗi domain có 3-10 file:

```
.claude/references/team-expert/
├── healthcare/
│   ├── hl7-fhir.md
│   ├── emr-standards.md
│   └── ...
├── finance/
│   ├── accounting-vas.md
│   ├── tax-vietnam.md
│   └── ...
├── ecommerce/
├── logistics/
├── ... (29 domains, 162 files)
```

Agents tham chiếu reference khi cần kiến thức chuyên ngành.

### 4.4. Doc-framework (`.claude/doc-framework/`)

40 template + 20 schema cho output documentation. Mọi skill PHẢI tạo output từ template (CORE-031):

```
.claude/doc-framework/
├── phase0-brainstorm/          ← Templates cho Phase 0
├── phase1-business/
├── phase2-features/
├── phase3-architecture/
├── phase4-ux/
├── phase5-implementation/
├── phase6-deployment/
├── _meta/                       ← Meta templates (req-registry, digests)
├── _digests/                    ← Cross-phase digest templates
└── schemas/                     ← JSON schemas
```

Skill flow: **READ template → POPULATE → WRITE** (Protocol 19).

---

## 5. Luồng end-to-end khi user gọi `/`

```
1. USER: /wf-analyze-requirements
   ↓
2. Claude Code:
   - Match command → load `.claude/skills/workflow/wf-analyze-requirements/SKILL.md`
   - Trigger SessionStart hook → session-init.sh
   - Auto-load rules: 00-behavioral + 00-core + 06-domain + 07-project
   ↓
3. SKILL.md (≤500 dòng):
   - Read arguments
   - Route đến Phase 1 → load `procedures/phase1-init.md`
   ↓
4. Phase Procedure:
   - PRE-GATE check (T1→T4)
   - Spawn agents qua `Agent` tool:
     - subagent_type="business-analyst" → đọc `.claude/agents/business/business-analyst.md`
     - subagent_type="finance-expert"   → đọc `.claude/agents/business/finance-expert.md`
   ↓
5. Agents (parallel):
   - Đọc references domain
   - Đọc registry (SSOT)
   - Read project files
   - Write outputs từ templates (Doc-framework)
   - Trigger PostToolUse hooks: validate-contract-sync, update-sync-status
   ↓
6. SKILL POST-GATE (T1→T4):
   - File exists? JSON valid? Content non-empty? Cross-ref đúng?
   - Update fix-status.json / phase state
   ↓
7. Phase report (CORE-028):
   - Tiếng Việt, ≤15 dòng, cho người không chuyên
   ↓
8. Return to USER:
   - Output files trong .mc-data/docs/phase1-business/
   - Phase report inline
```

---

## 6. Tách trách nhiệm rõ ràng

| Câu hỏi | Lớp/Thành phần phụ trách |
|---------|--------------------------|
| "Khi user gõ `/wf-xxx` thì làm gì?" | Skill |
| "Phân tích nghiệp vụ healthcare cụ thể?" | Agent (business team) + References |
| "Chặn lệnh `rm -rf /`?" | Hook (`pre-bash-safety.sh`) |
| "Buộc REQ-ID trong code?" | Rule (`01-coding.md`) + Hook (`validate-requirement-sync.sh`) |
| "Format output file kế hoạch sprint?" | Doc-framework (template) |
| "Lưu state khi user `--resume`?" | Skill procedures (`resume-status.md`) + `.mc-data/work/` |

---

## 7. Quy tắc thiết kế 2-lớp

### 7.1. Skill KHÔNG đụng code trực tiếp

**❌ ANTI-PATTERN:**
```
SKILL.md viết: "Tôi sẽ analyze code trong src/auth.ts..."
→ Skill làm thay agent — sai kiến trúc
```

**✅ ĐÚNG:**
```
SKILL.md: spawn agent code-reviewer → agent đọc src/auth.ts → ghi finding
```

### 7.2. Agent KHÔNG bypass skill orchestration

**❌ ANTI-PATTERN:**
```
Agent code-reviewer tự gọi agent security-audit
→ Agent gọi agent — bypass skill control
```

**✅ ĐÚNG:**
```
Skill spawn agent code-reviewer + agent security-audit song song → aggregate kết quả
```

### 7.3. Hook KHÔNG thay thế Skill validation

**❌ ANTI-PATTERN:**
```
Hook `validate-contract-sync.sh` chạy full POST-GATE T1→T4
→ Hook quá nặng, làm chậm mọi Write
```

**✅ ĐÚNG:**
```
Hook chỉ check spot violation (kebab-case, REQ-ID present)
Full POST-GATE chạy trong skill phase end
```

### 7.4. Rule KHÔNG override Skill logic

```
Rule cung cấp CONSTRAINT (vd: "REQ-ID phải có")
Skill phải tự CHECK constraint trong PRE-GATE/POST-GATE
Rule không tự enforce — chỉ là context cho Claude
```

---

## 8. Mở rộng 2-lớp

### 8.1. Thêm Skill mới

1. Copy template `.claude/skills/workflow-skill.md`
2. Tạo `workflow/{new-skill}/SKILL.md`
3. Tuân thủ [02-standards/02-skill-standard.md](../02-standards/02-skill-standard.md)
4. Định nghĩa `_contract.json` + `evals/` + `templates/`
5. Update `01-architecture/07-skills-catalog.md`

### 8.2. Thêm Agent mới

1. Đọc spec `.claude/agents/spec/README.md`
2. Tạo Knowledge files TRƯỚC: `.claude/agents/spec/knowledge-template.md`
3. Đặt agent trong `agents/{category}/{name}.md`
4. Thêm domain knowledge `references/team-expert/{domain}/`
5. Update `01-architecture/08-agents-catalog.md`

### 8.3. Thêm Hook mới

1. Tạo `.claude/hooks/{name}.sh`
2. Đăng ký event trong `.claude/settings.json` (`PreToolUse`/`PostToolUse`/`Stop`)
3. Test: simulate event → verify behavior
4. Update `05-hooks-and-gates.md`

---

## 9. Anti-patterns chéo-lớp

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Skill đọc full code file rồi tự phân tích | Spawn agent (giảm context skill) |
| Agent tự ghi vào registry mà không thông qua skill | Skill là PRIMARY/SAFE-UPDATE owner |
| Hook chạy logic quá nặng (full validation) | Hook chỉ spot-check; Skill chạy POST-GATE đầy đủ |
| Rule mâu thuẫn với Skill behavior | Rule là constraint; Skill phải tuân thủ |
| Reference dùng làm executable code | Reference chỉ là knowledge text |
| Doc-framework template viết bằng tiếng Anh cho user-facing | Vietnamese cho content user đọc |

---

## 10. Liên kết

- **Workflow model:** [`02-workflow-model.md`](02-workflow-model.md) — 7 phases + 3 paths
- **Data model:** [`03-data-model.md`](03-data-model.md) — `.mc-data/` structure + SSOT
- **Hooks & Gates:** [`05-hooks-and-gates.md`](05-hooks-and-gates.md) — 11 hooks + 3 gates
- **Skills catalog:** [`07-skills-catalog.md`](07-skills-catalog.md) — 43 skills inventory
- **Agents catalog:** [`08-agents-catalog.md`](08-agents-catalog.md) — 62 agents inventory
- **Skill standard:** [`../02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md)
- **Agent standard:** [`../02-standards/03-agent-standard.md`](../02-standards/03-agent-standard.md)
- **Source rules:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md), [`.claude/rules/00-behavioral.md`](../../.claude/rules/00-behavioral.md)
