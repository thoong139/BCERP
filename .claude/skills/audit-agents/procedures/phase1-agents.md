# Phase 1: Agent Definition Audit (A1-A10 + AP1-7)

> Kiểm tra mỗi agent file theo 10 tiêu chí (A1-A10) + 7 anti-patterns (AP-1 đến AP-7).
> Chia batches 5 agents → spawn `agent-auditor` parallel.

## PRE-GATE

- Phase 0 completed (`phase0-init` trong `completed_phases[]`)
- `$SPEC` và `$AGENT_TEMPLATE` đã load
- `$AGENT_FILES[]` không rỗng

## Steps

### 1.1 — Chuẩn bị batches

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1.1 | Chia `$AGENT_FILES[]` thành batches size 5 → tính `total_batches = ceil(len / 5)` | — | Batch size ≤5 |
| 1.1.2 | Cập nhật `status.json.phase1_state` với `total_agents`, `batch_size: 5`, `total_batches`, `completed_batches: 0`, `current_batch_index: 0` | Write | status valid |
| 1.1.3 | Nếu resume: đọc `completed_batches` → skip những batches đã xong | Read | Resume index set |

### 1.2 — Execute batches (parallel trong batch group)

Mỗi batch thực hiện theo pattern sau:

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.2.a | Spawn `agent-auditor` sub-agent với prompt template (xem `_shared.md §Auditor Prompt Templates — Template chung Phase 1`) | Agent | Sub-agent returned JSON |
| 1.2.b | Prompt input: batch files list + relevant `$SPEC` section + `$AGENT_TEMPLATE` excerpt | — | — |
| 1.2.c | Parse JSON response → array of Finding objects | — | Valid JSON |
| 1.2.d | Append findings vào `$SESSION_DIR/findings-agents.json` (array, atomic write) | Write | jq valid |
| 1.2.e | Cập nhật `status.json.phase1_state.completed_batches += 1`, `current_batch_index += 1` | Write | Checkpoint saved |

**Song song hóa (BẮT BUỘC khi ≥3 agents):**
- Theo Protocol 7 (max 5 agents đồng thời), chạy các batches trong cùng batch-group song song.
- Mỗi Agent tool call là độc lập — KHÔNG share write scope (mỗi call produce findings → merge sau).
- Ví dụ: 62 agents = 13 batches → chạy 3-4 rounds parallel (5 batches/round).

**Fallback khi sub-agent fail:**
- Retry ×3 (theo `_shared.md §Fix Rules`)
- Nếu vẫn fail → fallback: main agent tự Read từng file, check A1-A10 theo checklist, append findings inline
- Log E006/E011 vào `status.json.errors[]`

### 1.3 — Direct checks (main thread, không cần sub-agent)

Một số checks dễ chạy trực tiếp (song song với batches):

| Step | Check | Tool | Output |
|------|-------|------|--------|
| 1.3.1 | A9 kích thước: `wc -l` cho mỗi agent file → flag files >250 (exempt orchestrator: >400) | Bash | MAJOR findings nếu vượt |
| 1.3.2 | A1.1 name khớp filename: Grep `name:` trong frontmatter, so với basename | Grep | CRITICAL findings nếu mismatch |
| 1.3.3 | A1.3 last_updated format: Grep regex `last_updated: \d{4}-\d{2}-\d{2}` | Grep | MAJOR findings nếu sai format |
| 1.3.4 | AP-7 Vague Identity: Grep "Chuyên gia về" không kèm perspective keywords | Grep | MAJOR findings |

### Exemptions (xem `_shared.md §Criteria Detail Tables — Exemptions`)

| Agent | Skip checks |
|-------|-------------|
| `orchestrator.md` | A3, A4, A6; A9 soft limit 400 |
| `review/*.md` | A6 |
| Engineering utility (không references) | A6 |
| `README.md` | All |

## POST-GATE

- `findings-agents.json` tồn tại và valid JSON array
- `status.json.phase1_state.completed_batches == total_batches`
- Mọi agents trong scope đã được check (không miss batch)
- Append `phase1-agents` vào `completed_phases[]`
- Remove `phase1-agents` khỏi `pending_phases[]`

## Routing sau Phase 1

Đọc `pending_phases[0]`:

| Next | Load |
|------|------|
| `phase2-procedures` | `procedures/phase2-procedures.md` |
| `phase3-knowledge` | `procedures/phase3-knowledge.md` |
| `phase4-crossref` | `procedures/phase4-crossref.md` |
| `phase5-report` | `procedures/phase5-report.md` |

## Errors liên quan

- **E004** — Agent file corrupt (no frontmatter) → Log CRITICAL finding, skip agent
- **E006** — Sub-agent timeout → Retry ×3 → fallback direct check
- **E011** — Agent trả text thay JSON → Fallback parse, nếu fail log MANUAL
- **E012** — Batch fail >3 lần → Log MAJOR, tiếp tục batch kế tiếp

Chi tiết: `_shared.md §Error Handling Reference`.
