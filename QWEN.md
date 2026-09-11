# QWEN.md

Ngữ cảnh dự án MCV3 cho Qwen Code và các AI assistants tương đương.

---

## Dự Án

**MCV3** là DEVKIT — framework hỗ trợ người không chuyên xây dựng phần mềm trên nền tảng AI coding (Claude Code, Qwen Code...). Biến ý tưởng mơ hồ thành phần mềm hoàn chỉnh qua đội ngũ 63 AI agents chuyên biệt.

**Invariant không được vi phạm:**
- `.claude/` là read-only trong runtime dự án. Mọi runtime data ghi vào `.mc-data/`.
- Chất lượng, độ chính xác, tính đầy đủ luôn đứng trước tốc độ.
- Tài liệu phase sau phải có căn cứ từ tài liệu phase trước và từ `req-registry.json`.
- KHÔNG skip workflow phases. Chưa có output phase trước → KHÔNG chạy phase sau.

---

## Kiến Trúc

### Hai lớp

**Skills** (`.claude/skills/workflow/`): 26 skills `wf-*` — lệnh `/wf-*` user gọi. Mỗi skill chạy PRE-GATE → EXECUTION → POST-GATE, ghi output vào `.mc-data/`.

**Agents** (`.claude/agents/`): Skills spawn agents để phân tích, thiết kế, implement. Agent tên file (không `.md`) = `subagent_type`.

| Đội | Số lượng | Vai trò |
|-----|---------|---------|
| Business | 25 | BA + 24 domain experts (finance, healthcare, logistics...) |
| Engineering | 14 | architect, developer, devops, security, dba, sre... |
| Design | 7 | ux-researcher, ux-designer, ux-architect, ui-designer... |
| Testing | 9 | qa-lead, code-reviewer, performance-benchmarker... |
| Review | 7 | DEVKIT self-quality agents |
| Orchestrator | 1 | Điều phối chính |
| Meta | 4 | final-verify, sprint1/2/3-review |

### Data Flow
```
User → Skill (/wf-*) → Agents → Output vào .mc-data/docs/phase[N]/
                              ↓
                   req-registry.json (SSOT duy nhất)
```

---

## Workflow

### Standard Path (dự án mới)
```
/wf-brainstorm → /wf-analyze-requirements → /wf-define-features →
/wf-design → /wf-design-ux (UI only) → /wf-plan-modules →
/wf-implement-feature → /wf-preflight → /wf-verify-sync → /wf-prepare-deployment
                                ↑
                /wf-fix-bugs (bất kỳ lúc sau khi có code)
```

### Existing Path (codebase hiện có)
```
/wf-legacy-scan → /wf-legacy-classify → /wf-legacy-extract →
/wf-brainstorm* → /wf-analyze-requirements* → /wf-define-features* → /wf-design* →
/wf-annotate-code (nếu cần) → /wf-design-ux* → /wf-plan-modules → ...
```
`*` = detect LEGACY_MODE qua `project-context.md` > 500 bytes.

### Skills Quan Trọng

| Lệnh | Mục đích |
|------|---------|
| `/wf-fix-bugs [--profile=quick\|standard\|deep\|exhaustive]` | 7 dimension lanes: functional, business, security, performance, UX/a11y, data, compat |
| `/wf-preflight` | Health check → PASS/WARN/FAIL |
| `/wf-verify-sync` | REQ-to-code traceability |
| `/wf-manage-change` | Xử lý thay đổi tính năng |
| `/wf-add-scope` | Thêm modules/features (append-only) |
| `/wf-annotate-code` | Inject REQ-ID vào existing code |
| `/new-project` / `/existing-project` / `/feature-addition` | Meta-workflows |
| `/status` | Tiến độ dự án |
| `/audit-devkit` | Self-audit MCV3 |

---

## Single Source of Truth

`req-registry.json` tại `.mc-data/docs/_meta/req-registry.json` là SSOT duy nhất.

```
QUY TẮC:
- ĐỌC registry trước khi thiết kế/code
- Mỗi skill CHỈ update đúng fields được phân công
- impl_status chỉ có 4 giá trị: not_started | in_progress | done | skipped
- KHÔNG downgrade impl_status từ "done" → giá trị khác
```

### REQ-ID trong code
```typescript
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-CUST-001
export class CustomerService { ... }
```
Format: `REQ-[DEPT]-[NNN]` hoặc `REQ-[SYSTEM]-[MODULE]-[NNN]`

---

## Cấu Trúc

```
.claude/
├── agents/              # Agent definitions + procedures + spec
├── skills/
│   ├── workflow/        # 26 wf-* skills
│   ├── workflows/       # 3 orchestrator meta-workflows
│   ├── protocols/       # 20 protocol files (shared quality gates)
│   └── workflow-skill.md  # Template skill mới (v3.0)
├── hooks/               # 11 validation hooks
├── rules/               # 8 rules (00-core → 07-project)
├── references/          # Domain knowledge (29 domains)
├── doc-framework/       # Document templates Phase 0-6
└── scripts/             # Audit + validation scripts

.mc-data/                # Runtime artifacts (gitignored)
├── docs/_meta/req-registry.json  # ★ SSOT
└── docs/phase0-phase6/          # Output tài liệu 7 phases
```

---

## Validation

Trên Windows, dùng PowerShell wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/skill-compliance-audit.sh <skill-name | --all>
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/validate-schema-sync.sh <skill-name | --all>
```

Đây là framework, không có build/test truyền thống.

---

## Phân Lớp Thay Đổi

| Loại thay đổi | Vị trí |
|---------------|--------|
| Workflow logic | `.claude/skills/workflow/[skill]/SKILL.md` |
| Agent behavior | `.claude/agents/[team]/[agent].md` + `procedures/` |
| Validation rule | `.claude/hooks/` hoặc `.claude/rules/` |
| Output template | `.claude/doc-framework/` |
| Shared protocol | `.claude/skills/protocols/` |

Khi sửa skill: giữ nguyên output paths, gate markers, error codes và contract với `.mc-data/` trừ khi đổi workflow.

---

## Ngôn Ngữ

| Loại | Ngôn ngữ |
|------|---------|
| Tài liệu, comments | Tiếng Việt có dấu |
| File names, variables, functions | English hoặc tiếng Việt không dấu |
