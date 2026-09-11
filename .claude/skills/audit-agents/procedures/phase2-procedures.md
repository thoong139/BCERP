# Phase 2: Procedure Audit (P0-P6 + PP1-6)

> Kiểm tra procedure files theo 6 tiêu chí (P0-P6) + 6 anti-patterns (PP-1 đến PP-6) theo spec Section 5.

## PRE-GATE

- Phase 0 completed (`$SPEC` loaded)
- `$PROCEDURE_FILES[]` không rỗng (nếu rỗng → skip phase, log WARNING)
- Scope ∈ {`procedures`, `full`}

## Steps

### 2.1 — Direct structural checks

| Step | Check | Tool | Output |
|------|-------|------|--------|
| 2.1.1 | TC-P0: Folder structure — glob `.claude/agents/procedures/*/` → folder name phải match agent name (không `.md`) | Glob + Bash | MAJOR findings khi mismatch |
| 2.1.2 | TC-P0: File naming — verify `[verb]-[topic].md` kebab-case | Grep regex | MAJOR |
| 2.1.3 | TC-P5: Kích thước — `wc -l` mỗi file, flag >200 dòng | Bash | MAJOR |
| 2.1.4 | TC-P5: Đếm procedures/agent — flag nếu >10 files trong 1 folder | Bash + count | MAJOR |

### 2.2 — Spawn `agent-auditor` (batching nếu >5 files)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.2.a | Chia `$PROCEDURE_FILES[]` thành batches 5 | — | — |
| 2.2.b | Spawn agent-auditor với prompt template (xem `_shared.md §Auditor Prompt Templates — Template Phase 2`) | Agent | JSON response |
| 2.2.c | Checks: P1 (metadata), P2 (triggers), P3 (steps), P4 (knowledge refs), P6 (anti-patterns) | — | — |
| 2.2.d | Parse JSON → append `$SESSION_DIR/findings-procedures.json` | Write | jq valid |

**PP-1 đến PP-6** (delegate cho sub-agent theo prompt; xem bảng chi tiết trong `_shared.md §Anti-pattern Tables`).

### 2.3 — Cross-check P4 knowledge refs (main thread)

| Step | Action | Tool | Output |
|------|-------|------|--------|
| 2.3.1 | Mỗi procedure file: Grep lines chứa "Read .claude/references/" → extract paths | Grep | List of refs |
| 2.3.2 | Glob từng path → verify file tồn tại | Glob | MAJOR finding nếu broken (code E003) |

## POST-GATE

- `findings-procedures.json` tồn tại và valid JSON array
- Tất cả procedure files trong scope đã được check
- Orphan procedures (PP-5) đã identify (deferred cho Phase 4 cross-ref)
- Append `phase2-procedures` vào `completed_phases[]`

## Routing sau Phase 2

Đọc `pending_phases[0]`:

| Next | Load |
|------|------|
| `phase3-knowledge` | `procedures/phase3-knowledge.md` |
| `phase4-crossref` | `procedures/phase4-crossref.md` |
| `phase5-report` | `procedures/phase5-report.md` |

## Errors liên quan

- **E003** — Knowledge path broken → Log MAJOR finding, continue
- **E006** — Sub-agent timeout → Retry ×3 → fallback direct check
- **E008** — Procedure không có agent tương ứng → Log MAJOR (orphan, nhưng xử lý chính thức ở Phase 4)

Chi tiết: `_shared.md §Error Handling Reference`.
