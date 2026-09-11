# Phase 1 — Wave 1: Agent Scans (5 batches PARALLEL)

> Spawn `agent-auditor` để scan agent definitions theo 5 batches song song. Business team tách 2 sub-batches (25 agents) để giữ ≤20 files/batch.

**PRE-GATE:** `$SESSION_DIR/audit-index.json` tồn tại + `components.agents[]` non-empty

**📤 OUTPUT:** 5 files `findings-agents-*.json` (template: `templates/findings.json`)

---

## Batch Plan

| Batch | Auditor | Scope | Max Files | Output |
|-------|---------|-------|-----------|--------|
| 1.1a | `agent-auditor` | `business/*.md` first half (alphabet, ~13) | ≤13 | `findings-agents-business-a.json` |
| 1.1b | `agent-auditor` | `business/*.md` second half (~12) | ≤12 | `findings-agents-business-b.json` |
| 1.1c | `agent-auditor` | `engineering/*.md` | ≤14 | `findings-agents-engineering.json` |
| 1.1d | `agent-auditor` | `design/*.md` + `testing/*.md` | ≤16 | `findings-agents-design-testing.json` |
| 1.1e | `agent-auditor` | `review/*.md` + `orchestrator.md` | ≤8 | `findings-agents-review.json` |

> **5 batches SPAWN PARALLEL:** 5 Agent tool calls trong CÙNG 1 message.

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1.1 | Đọc `audit-index.json` → lọc `components.agents[]` theo team. Business team: chia 2 halves theo alphabet (sort by `name`, slice midpoint). | Read | 5 lists ready |
| 1.1.2 | **Spawn 5 agent batches PARALLEL** — 5 Agent tool calls đồng thời. Mỗi prompt theo template `_shared.md` §Auditor Prompt Template. Criteria: A1-A6 (xem `_shared.md` §Agent Criteria). | Agent (×5) | 5 agents started |
| 1.1.3 | Thu thập 5 results, parse JSON array | - | All parsed |
| 1.1.4 | Nếu agent trả text thay vì JSON → fallback parse (E004) | Bash/Read | JSON extracted |
| 1.1.5 | Cho mỗi batch: WRAP results vào schema `audit-findings-v1` (xem `_shared.md` §Findings JSON Build Helper) → WRITE `$SESSION_DIR/findings-agents-[batch].json` | Read+Write | 5 files written |
| 1.1.6 | Validate mỗi file: `node -e "JSON.parse(...)"` pass | Bash | 5 OK |
| 1.1.7 | UPDATE `scan-status.json`: `phases.phase_1_scan.waves.wave_1_agents.completed_batches` += 5 batch IDs, `wave_1_agents.status = "completed"`, `metrics.agent_spawns += 5`, heartbeat update | Edit | status updated |

---

## Auditor Prompt — Skeleton cho `agent-auditor`

```
Bạn là agent-auditor. Audit các agent definition files sau:
[paths từ batch — ≤20 files]

Kiểm tra theo criteria A1-A6:
- A1: Frontmatter completeness (name, description, allowed-tools)
- A2: Knowledge sections đầy đủ
- A3: Procedures references hợp lệ (.claude/agents/procedures/[name]/)
- A4: Knowledge file references hợp lệ (.claude/references/team-expert/[domain]/)
- A5: Output format definition rõ ràng
- A6: Cross-references đến skills/agents khác hợp lệ

OUTPUT FORMAT: JSON array theo schema `audit-findings-v1` (xem prompt template).
component = "agent" cho mọi finding.
```

---

## Error Handling

- **E003 timeout:** Re-spawn batch 1 lần. Vẫn fail → skip batch + WARNING + ghi `pending_batches[]`
- **E004 text response:** Fallback parse → extract JSON từ markdown code block. Vẫn fail → MANUAL review
- **Agent context overflow:** Auto-split batch thành 2 sub-batches ≤10. Ghi `metrics.split_events += 1`. Cả 2 fail → PARTIAL report
- **>3 batches fail liên tiếp:** Circuit breaker (xem `_shared.md`) → PAUSE + hỏi user

**POST-GATE:**
- 5 files `findings-agents-*.json` tồn tại trong `$SESSION_DIR/`
- Mỗi file là JSON valid với `$schema: "audit-findings-v1"`
- `scan-status.json.phases.phase_1_scan.waves.wave_1_agents.status == "completed"`

---

## Cross-references

- Auditor prompt template: `_shared.md` §Auditor Prompt Template
- Criteria A1-A6: `_shared.md` §Agent Criteria
- Findings schema: `templates/findings.json`
- Next wave: `phase1-wave2-skills.md`
