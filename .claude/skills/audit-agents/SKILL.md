---
name: audit-agents
version: 3.1.0
last_updated: 2026-09-12
description: |
  Kiểm tra agents, procedures, và references tuân thủ Agent & Knowledge Construction Specification.
  Audit toàn bộ agent definitions, procedure files, knowledge files, và cross-references.

  v3.0.0 — Refactor lớn: tách monolithic SKILL.md (475 dòng) thành 6 phase files + 1 _shared.md
  (lazy loading per-phase). Giảm context load ~75% khi execute từng phase. Bổ sung session
  isolation (`.mc-data/work/audit-agents/[session-id]/`) + resume support (status.json).
  Backup: procedures/flow-legacy.md.bak.

  TRIGGER khi:
  - Thêm agent mới hoặc sửa agent hiện tại
  - Thêm/sửa knowledge files trong references/team-expert/
  - Thêm/sửa procedure files trong agents/procedures/
  - Cần verify tính nhất quán giữa agents ↔ procedures ↔ knowledge
  - Keywords: "audit agents", "kiểm tra agents", "agent compliance"

  KHÔNG trigger khi:
  - Audit skills → dùng skill-compliance-audit.sh
  - Audit templates → dùng /review-orchestrator

argument-hint: "[agent-name | --all | --references | --procedures | --full] [--resume]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Agent, TodoWrite
---

# /audit-agents: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Audit tuân thủ Agent, Knowledge & Procedure Construction Specification |
| **Prerequisites** | `.claude/agents/spec/README.md` (spec), `.claude/agents/` (targets) |
| **Duration** | Moderate (multi-phase, hỗ trợ resume qua checkpoint) |
| **Phases** | 0 → 1 → 2 → 3 → 4 → 5 (routing theo scope) |
| **Input** | `.claude/agents/**`, `.claude/agents/procedures/**`, `.claude/references/team-expert/**` |
| **Output** | `docs/audit/reports/agent-audit-[YYYY-MM-DD].md` + `.mc-data/work/audit-agents/[session-id]/audit-result.json` |

### Workflow Position

```
/review-orchestrator → /audit-agents → Fix findings → Re-audit
                            |
                       YOU ARE HERE
```

> Skill bổ trợ — dùng độc lập hoặc trong /review-orchestrator.
> Chỉ AUDIT và BÁO CÁO, không tự động fix.

---

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `agent-name` | Tên agent cụ thể (không `.md`) — scope `single` | — |
| `--all` | Audit tất cả agents (chỉ Phase 1) — scope `agents` | — |
| `--references` | Chỉ audit knowledge files (Phase 3) — scope `references` | — |
| `--procedures` | Chỉ audit procedure files (Phase 2) — scope `procedures` | — |
| `--full` | Agents + procedures + knowledge + cross-reference — scope `full` | **Mặc định** |
| `--resume` | Resume từ checkpoint (`status.json`) của session gần nhất | — |

> Không có argument → default scope = `full`.

---

## Protocols

> **Shared protocols (repo-wide):** `.claude/skills/protocols/`
> - **Protocol 1** (Accuracy Assurance): Structural checks trước khi accept findings
> - **Protocol 7** (Parallel Execution): Max 5 agents đồng thời, dependency analysis trước grouping
> - **Protocol 8** (Content Quality Gate): Validate output quality dimensions
> - **Protocol 10** (Schema Validation): T1→T4 tiered checks cho POST-GATE
>
> **Skill-internal shared:** `procedures/_shared.md` — State Variables, Anti-pattern Tables (AP-1 to AP-7, PP-1 to PP-6, KP-1 to KP-7), Fix Rules, Auditor Prompt Templates, Schemas, Checkpoint, Error Handling, Verdict Computation.

### Priority Ladder (BẮT BUỘC)

1. **Độ chính xác, chất lượng, tính nhất quán**
2. **Tốc độ và song song hóa** — chỉ sau khi mục 1 được bảo vệ

```
QUY TẮC:
- Mọi phase có PRE-GATE/POST-GATE để bảo vệ accuracy
- Findings phải có căn cứ từ spec, không suy diễn
- Parallel chỉ khi agent batches độc lập, không share write scope
```

### Execution Strategy

| Condition | Mode |
|-----------|------|
| Audit nhiều agents (≥3) ở Phase 1 | **PARALLEL batching** — chia batches 5 agents, spawn `agent-auditor` sub-agents |
| Audit 1 agent (scope=single) | **SEQUENTIAL** — direct checks |
| Phase 2 (procedures) | **PARALLEL** nếu ≥5 files, **SEQUENTIAL** nếu ít hơn |
| Phase 3 (knowledge) | **PARALLEL** per-domain |
| Phase 4 (cross-reference) | **SEQUENTIAL** — cần kết quả từ Phase 1/2/3 |
| Phase 5 (report) | **SEQUENTIAL** — merge + write |

---

## Phase 0: Init (BẮT BUỘC — entry point)

> Phase này **LUÔN chạy đầu tiên** để parse arguments, tạo session, load spec.

```
STEP 1: IF $ARGUMENTS chứa "--resume"
          THEN jump tới phase0-init.md "Resume handler" → read status.json → jump pending_phases[0]
        ELSE continue

STEP 2: Read procedures/phase0-init.md → execute Phase 0 → return với $SCOPE, $SESSION_ID, pending_phases[]
```

### Phase 0 Step Summary

| Step | Action | Verify |
|------|--------|--------|
| 1 | `--resume` handler: đọc `status.json` session gần nhất → jump `pending_phases[0]` | File hợp lệ; corrupt → E010 |
| 2 | Parse `$ARGUMENTS` → `$SCOPE` (full/agents/procedures/references/single) + target | Scope hợp lệ |
| 3 | Lazy-load `procedures/phase0-init.md`: load spec, init session dir + status.json | Session OK; spec thiếu → E001 |

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps.
> Toàn bộ logic chi tiết được lazy-load qua các phase files riêng.
> Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase | Procedure file | Điều kiện chạy | Mục đích |
|-------|---------------|----------------|----------|
| **0** | `procedures/phase0-init.md` | Always (entry) | Load spec, parse scope, init session |
| **1** | `procedures/phase1-agents.md` | `$SCOPE ∈ {full, agents, single}` | Audit agent files (A1-A10 + AP-1 đến AP-7), batching 5 |
| **2** | `procedures/phase2-procedures.md` | `$SCOPE ∈ {full, procedures}` | Audit procedure files (P0-P6 + PP-1 đến PP-6) |
| **3** | `procedures/phase3-knowledge.md` | `$SCOPE ∈ {full, references}` | Audit knowledge files (K0-K3 + KG + KP-1 đến KP-7) |
| **4** | `procedures/phase4-crossref.md` | `$SCOPE ∈ {full, single}` | Cross-reference (X1-X6) |
| **5** | `procedures/phase5-report.md` | Always (cho mọi scope) | Merge findings, generate report |

### Routing Flows

**`--full` (default):**
```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → DONE
```

**`--all` / `--agents`:**
```
Phase 0 → Phase 1 → Phase 5 → DONE
```

**`--procedures`:**
```
Phase 0 → Phase 2 → Phase 5 → DONE
```

**`--references`:**
```
Phase 0 → Phase 3 → Phase 5 → DONE
```

**`<agent-name>` (single agent):**
```
Phase 0 → Phase 1 → Phase 4 (focused) → Phase 5 → DONE
```

**`--resume`:**
```
Read status.json → jump tới pending_phases[0] → tiếp tục bình thường
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, Steps, POST-GATE, Errors riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting concerns (prompts, schemas, anti-patterns).

---

## Session & Checkpoint

### Working directory

```
.mc-data/work/audit-agents/[session-id]/
├── status.json                   # Checkpoint + resume state
├── findings-agents.json          # Phase 1 output (per-batch append)
├── findings-procedures.json      # Phase 2 output
├── findings-knowledge.json       # Phase 3 output
├── findings-crossref.json        # Phase 4 output
└── audit-result.json             # Phase 5 merged output
```

### Resume support

- Mỗi phase hoàn thành → append vào `status.json.completed_phases[]`
- Phase 1 batching → checkpoint sau mỗi batch (`phase1_state.completed_batches`)
- Context >80% → FORCE STOP + checkpoint
- `--resume` đọc `status.json` và tiếp tục từ `pending_phases[0]`

Chi tiết: `procedures/_shared.md §Checkpoint & Resume`.

---

## Output Files

| File | Path | Created by | Required |
|------|------|------------|----------|
| status.json | `$SESSION_DIR` | Phase 0, updated per phase | Always |
| findings-agents.json | `$SESSION_DIR` | Phase 1 | Khi scope bao gồm agents |
| findings-procedures.json | `$SESSION_DIR` | Phase 2 | Khi scope bao gồm procedures |
| findings-knowledge.json | `$SESSION_DIR` | Phase 3 | Khi scope bao gồm references |
| findings-crossref.json | `$SESSION_DIR` | Phase 4 | Khi scope=full hoặc single |
| audit-result.json | `$SESSION_DIR` | Phase 5 | Always |
| agent-audit-[date].md | `docs/audit/reports/` | Phase 5 | Always |

> `docs/audit/reports/` (KHÔNG `.mc-data/` — đây là DEVKIT self-audit, không phải project workspace).

---

## Agents Spawned

| Phase | Agent | Purpose |
|-------|-------|---------|
| 1 | `agent-auditor` | Audit agent files (batching 5) |
| 2 | `agent-auditor` | Audit procedure files (batching 5) |
| 3 | `agent-auditor` | Audit knowledge files (per-domain) |
| 4 | — | Cross-reference (Grep/Glob only) |
| 5 | — | Merge + report (Read/Write only) |

---

## Error Handling

Chi tiết đầy đủ (E001-E012): `procedures/_shared.md §Error Handling Reference`.

Tóm tắt:

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001/E002 | Spec/agent files không tồn tại | STOP — verify path |
| E003 | Knowledge path broken | Log CRITICAL finding, continue |
| E004 | Agent file corrupt | Log CRITICAL finding, skip agent |
| E005 | Glob timeout | Retry với narrower scope |
| E006 | Sub-agent timeout | Retry ×3, fallback direct check |
| E007 | CLAUDE.md counts mismatch | Log MAJOR finding |
| E008 | Procedure orphan (không có agent) | Log MAJOR finding, continue |
| E009 | Knowledge domain không map 1:1 | Log MINOR finding, continue |
| E010 | status.json corrupt khi resume | STOP, chạy lại từ đầu |
| E011 | Agent trả text thay JSON | Fallback parse → fail → log raw + MANUAL |
| E012 | Batch fail > 3 lần | Log MAJOR, tiếp tục batch kế |

---

## Related Skills

| Skill | Relation |
|-------|----------|
| `/review-orchestrator` | Parent orchestrator (optional) |
| `/status` | Xem tiến độ dự án (complementary) |
| `skill-compliance-audit.sh` | Audit skills thay vì agents (sibling) |
| `/audit-devkit --full` | Audit toàn diện hơn (skills + templates + workflow) |

> **Next:** audit xong → fix findings theo report, rồi re-audit; hoặc chạy `/audit-devkit --full` cho phạm vi rộng hơn.

---

## Lưu ý quan trọng

1. **Không sửa code** — skill này chỉ AUDIT và BÁO CÁO, không tự động fix
2. **Heading variants** — Chấp nhận variants hợp lý (ví dụ: "Cognitive Framework" = "Dual Perspective Framework")
3. **Đếm dòng** — Không đếm blank lines và `---` separators
4. **Knowledge structure** — Một số domains dùng tên file khác (`processes.md` thay vì `operations.md`) — chấp nhận nếu nội dung phù hợp
5. **Behavioral language** — Scan cho: "bạn nên", "bạn phải", "luôn luôn", "không bao giờ", "PHẢI", "CẤM", "LUÔN"
6. **Tiếng Việt có dấu** — Report PHẢI dùng tiếng Việt có dấu đầy đủ (Ngày, Tổng, Phạm vi, Đề xuất...)
7. **Procedure auditing** — Mọi procedure files trong `.claude/agents/procedures/` đều phải được kiểm tra khi scope `--full` hoặc `--procedures`

---

## Examples

### Example 1: Full audit (default)

```
/audit-agents

Phase 0: scope=full, session=20260419-110000 → PASS
Phase 1: 62 agents / 13 batches → agent-auditor parallel → 22 findings
Phase 2: 24 procedures / 5 batches → 8 findings
Phase 3: 29 domains → 14 findings
Phase 4: cross-ref X1-X6 → 5 findings
Phase 5: merge 49 findings → compliance 87% → verdict GOOD
DONE. Report: docs/audit/reports/agent-audit-2026-04-19.md
```

### Example 2: Single agent

```
/audit-agents sales-expert

Phase 0: scope=single, target=sales-expert → PASS
Phase 1: Audit sales-expert → 2 findings
Phase 4 (focused): X1 knowledge routing + X2 coordination → 1 finding
Phase 5: 3 findings → compliance 97% → verdict EXCELLENT
DONE.
```

### Example 3: Resume

```
/audit-agents --resume

Phase 0: Read status.json → session 20260419-110000, completed: phase0-init, phase1-agents
Resume từ pending_phases[0] = phase2-procedures
... tiếp tục bình thường
```
