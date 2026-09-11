# Phase 4: Cross-Reference Audit (X1-X6)

> Kiểm tra tính nhất quán giữa agents ↔ procedures ↔ knowledge.
> Phase này cần kết quả của Phase 1, 2, 3 (hoặc subset theo scope).

## PRE-GATE

- Ít nhất 1 trong 3 phases (1/2/3) đã completed
- `$SESSION_DIR/findings-*.json` tồn tại cho phases đã chạy
- Với scope `single`: chỉ cần Phase 1 done (focused mode)

## Steps

### 4.1 — TC-X1: Agent ↔ Knowledge mapping

| Step | Action | Tool | Output |
|------|--------|------|--------|
| 4.1.1 | Với mỗi business agent, Grep section `## Knowledge References` trong agent file → extract routing paths | Grep | `$AGENT_ROUTING{}` mapping |
| 4.1.2 | Verify mỗi path tồn tại: Glob | Glob | MAJOR finding nếu broken (X1.2) |
| 4.1.3 | Orphan knowledge: set difference giữa `$KNOWLEDGE_FILES[]` và tất cả paths trong `$AGENT_ROUTING` | Bash diff | MAJOR finding per orphan (X1.3, KP-4) |

### 4.2 — TC-X2: Agent → Agent references

| Step | Action | Tool | Output |
|------|--------|------|--------|
| 4.2.1 | Grep `## Coordination` section trong mỗi agent, extract agent names referenced | Grep | `$AGENT_REFS{}` |
| 4.2.2 | Verify mỗi referenced agent tồn tại trong `$AGENT_FILES[]` | Set check | MAJOR finding nếu broken |

### 4.3 — TC-X3: CLAUDE.md consistency

| Step | Action | Tool | Output |
|------|--------|------|--------|
| 4.3.1 | Read `CLAUDE.md` → extract numbers trong section agent counts | Read + Grep | Counts declared |
| 4.3.2 | So sánh với `len($AGENT_FILES[])`, `len($PROCEDURE_FILES[])`, `len($KNOWLEDGE_DIRS[])` | — | MAJOR finding nếu mismatch (E007) |

### 4.4 — TC-X4: Agent → Procedure mapping

| Step | Action | Tool | Output |
|------|--------|------|--------|
| 4.4.1 | Với mỗi agent có folder `.claude/agents/procedures/[name]/`, verify agent file có reference (trong Workflow hoặc Skill Playbooks) | Grep | CRITICAL finding nếu agent có procedures mà không reference |

### 4.5 — TC-X5: Procedure → Knowledge refs

| Step | Action | Tool | Output |
|------|--------|------|--------|
| 4.5.1 | Cross-check kết quả Phase 2 step 2.3 (đã extract & verify paths) | — | Đã có findings, chỉ dedup |

### 4.6 — TC-X6: Orphan procedures

| Step | Action | Tool | Output |
|------|--------|------|--------|
| 4.6.1 | Set difference: procedure folder names - agent file basenames với references | Bash diff | MAJOR finding per orphan |

### 4.7 — Write findings

Append tất cả X1-X6 findings vào `$SESSION_DIR/findings-crossref.json` (array, atomic write).

## Focused mode (scope = `single`)

Khi scope=`single` và `$TARGET_AGENT` != null:
- Skip X1.3 (orphan knowledge — full scan không áp dụng)
- Skip X3 (CLAUDE.md counts — không affected by 1 agent)
- X1.1, X1.2, X2, X4: chỉ check cho `$TARGET_AGENT`
- X6: chỉ check procedures thuộc `$TARGET_AGENT`

## POST-GATE

- `findings-crossref.json` tồn tại và valid JSON
- X1-X6 checks complete cho scope
- All orphans + broken paths reported
- Append `phase4-crossref` vào `completed_phases[]`

## Routing sau Phase 4

Luôn đi tới `phase5-report`:

```
Read procedures/phase5-report.md
```

## Errors liên quan

- **E003** — Knowledge path broken → Log CRITICAL finding
- **E007** — CLAUDE.md counts mismatch → Log MAJOR finding
- **E008** — Orphan procedure → Log MAJOR finding

Chi tiết: `_shared.md §Error Handling Reference`.
