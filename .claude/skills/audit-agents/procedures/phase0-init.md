# Phase 0: Init — Load Spec, Parse Scope, Init Session

> Load spec criteria, parse arguments, create session directory và status.json.
> Phase này **LUÔN chạy** cho mọi scope (entry point).

## PRE-GATE (Protocol 10.4 — Forensic Validation)

- T1: `test -f .claude/agents/spec/README.md`
- T2: `test -s .claude/agents/spec/README.md`
- T3: File contains heading "Agent" và "Knowledge"
- T4: File contains section "Tiêu chí" hoặc "Checklist"

Nếu PRE-GATE fail → E001, STOP.

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | Parse `$ARGUMENTS` → xác định `$SCOPE`. Mapping: `--all` → `full`; `--references` → `references`; `--procedures` → `procedures`; `<agent-name>` → `single`; không có arg → `full` (default) | — | `$SCOPE` set |
| 0.2 | Nếu có `--resume` → đọc `_shared.md §Checkpoint & Resume`, jump tới pending phase đầu tiên. Nếu không → tiếp tục step 0.3 | Read | Resume handled hoặc fall through |
| 0.3 | Generate `$SESSION_ID = date +%Y%m%d-%H%M%S`, `$REPORT_DATE = date +%Y-%m-%d` | Bash | Variables set |
| 0.4 | Tạo `$SESSION_DIR = .mc-data/work/audit-agents/$SESSION_ID/` | Bash `mkdir -p` | `test -d $SESSION_DIR` |
| 0.5 | Read `.claude/agents/spec/README.md` → lưu vào `$SPEC` (chỉ section "Tiêu chí" và "Anti-patterns") | Read | Spec loaded |
| 0.6 | Read `.claude/agents/spec/agent-definition-template.md` → `$AGENT_TEMPLATE` | Read | Template loaded |
| 0.7 | Read `.claude/agents/spec/knowledge-template.md` → `$KNOWLEDGE_TEMPLATE` (chỉ cần nếu scope ∈ {references, full}) | Read | Template loaded hoặc skip |
| 0.8 | Glob `$AGENT_FILES[]` theo scope. Full/agents: `.claude/agents/**/*.md` (exclude `procedures/`, `spec/`, `README.md`). Single: chỉ 1 file | Glob | List có ≥1 file |
| 0.9 | Glob `$PROCEDURE_FILES[] = .claude/agents/procedures/**/*.md` (chỉ nếu scope ∈ {procedures, full}) | Glob | List |
| 0.10 | Glob `$KNOWLEDGE_DIRS[] = .claude/references/team-expert/*/` và `$KNOWLEDGE_FILES[] = .claude/references/team-expert/**/*.md` (chỉ nếu scope ∈ {references, full}) | Glob | Lists |
| 0.11 | Tạo `$SESSION_DIR/status.json` với initial state (xem schema trong `_shared.md §Schemas`). `completed_at: null`, `completed_phases: ["phase0-init"]`, `pending_phases` theo scope (xem Routing Map dưới) | Write | `test -f $SESSION_DIR/status.json` |

## POST-GATE

- `$SESSION_DIR` tồn tại
- `status.json` valid JSON (`jq '.' $SESSION_DIR/status.json` exit 0)
- `$SCOPE` đúng 1 trong 5 giá trị hợp lệ
- `$AGENT_FILES[]` không rỗng (trừ khi scope=`references` hoặc `procedures`)
- Append `phase0-init` vào `completed_phases[]`

## Routing Map (output của Phase 0)

| scope | pending_phases (theo thứ tự) |
|-------|------------------------------|
| `full` | `phase1-agents`, `phase2-procedures`, `phase3-knowledge`, `phase4-crossref`, `phase5-report` |
| `agents` | `phase1-agents`, `phase5-report` |
| `procedures` | `phase2-procedures`, `phase5-report` |
| `references` | `phase3-knowledge`, `phase5-report` |
| `single` | `phase1-agents`, `phase4-crossref` (focused), `phase5-report` |

## Next Phase

Đọc `pending_phases[0]` → load procedure file tương ứng:

```
IF pending_phases[0] == "phase1-agents" → Read procedures/phase1-agents.md
IF pending_phases[0] == "phase2-procedures" → Read procedures/phase2-procedures.md
IF pending_phases[0] == "phase3-knowledge" → Read procedures/phase3-knowledge.md
```

## Errors liên quan

- **E001** — Spec file không tồn tại → STOP
- **E002** — Không tìm thấy agent files (scope yêu cầu) → STOP
- **E010** — status.json corrupt khi resume → STOP, yêu cầu chạy lại từ đầu

Chi tiết: `_shared.md §Error Handling Reference`.
