# Sub-Skill Invocation Patterns — wf-e2e-verify (Orchestrator)

> **Mục đích file:** `wf-e2e-verify` là **orchestrator** — KHÔNG spawn agent trực tiếp. Thay vào đó nó invoke 11 sub-skills `wf-e2e-*`. File này tài liệu hóa pattern invocation + context passing.

---

## 1. Sub-skill registry (11 sub-skills)

| F-step | Sub-skill | Mandatory? | Spawn condition |
|--------|-----------|------------|-----------------|
| F0 | (infra check, không sub-skill) | ✅ | Always entry |
| F0a | `wf-e2e-finding` | ✅ | Always (FIND only, không live test) |
| F0a' | `wf-e2e-credentials` | ⚪ | Khi feature cần auth credentials |
| F0b | `wf-e2e-seed-manifest` | ⚪ | Khi `--no-seed` không set |
| F1 | `wf-e2e-test` | ✅ | Always (live test, consume F0a output) |
| F2 | `wf-e2e-browser` | ✅ | Always (browser-driven test, screenshot) |
| F3 | `wf-e2e-unblock` | ⚪ | Khi F1 produces `block-test.json` |
| F4 | `wf-e2e-implement` | ⚪ | Khi F1 produces `implement-required.json` |
| F5 | `wf-e2e-retest` | ✅ | Always sau F2/F3/F4 |
| F6 | `wf-e2e-fix` | ⚪ | Khi F5 fail |
| F7 | `wf-e2e-scenario` | ✅ | Always cuối |
| F8 | `wf-e2e-demo` | ✅ | Always cuối cùng |

---

## 2. Invocation pattern (canonical)

Orchestrator KHÔNG dùng `Agent({...})` cho sub-skill. Sub-skill được invoke qua **Skill tool** hoặc qua **direct call SKILL.md**:

```python
# Pattern 1: Direct skill invocation (recommended)
# Orchestrator đọc sub-skill SKILL.md trực tiếp và execute trong main thread
Read(".claude/skills/workflow/wf-e2e-finding/SKILL.md")
# Execute steps in-process, passing $SESSION_DIR + $FEAT_ID

# Pattern 2: Spawn sub-skill via Agent tool (chỉ khi cần parallel + isolation)
Agent({
  "subagent_type": "general-purpose",
  "description": "Execute wf-e2e-finding F0a",
  "prompt": "..." # See §3 below
})
```

---

## 3. Sub-skill spawn template (8 sections)

Khi PHẢI spawn (parallel sub-skill, e.g. F1+F2 song song), dùng template:

```
# 1. ROLE DECLARATION
Bạn là **orchestrator runner** thực thi sub-skill `wf-e2e-{step}` cho parent
session `wf-e2e-verify` (F-step {Fx}).

# 2. TASK INSTRUCTION
Đọc file `.claude/skills/workflow/wf-e2e-{step}/SKILL.md` và thực thi đầy đủ.
KHÔNG được modify state của parent session ngoài output paths đã định.

KHÔNG được:
- Spawn sub-sub-skill (chỉ orchestrator chính được phép)
- Đọc/ghi files ngoài $SESSION_DIR/{Fx}/

# 3. SESSION CONTEXT (passed từ parent)
PARENT_SESSION_DIR: $SESSION_DIR              # .mc-data/work/wf-e2e-verify/sessions/{id}/
SUB_SKILL_OUTPUT_DIR: $SESSION_DIR/F{x}/     # Sub-skill ghi vào đây
FEAT_ID: $FEAT_ID                             # FEAT-CRM-CUST-001
PROFILE: $PROFILE                             # standard|deep|...
TIMESTAMP: $(date -Iseconds)

# 4. CI CONTEXT INJECTION
$CI_CONTEXT (preloaded by parent F0)

# 5. PLAYWRIGHT CONTEXT (relevant cho F1/F2/F5/F7/F8)
PLAYWRIGHT_MODE: $PLAYWRIGHT_MODE           # full|assisted|none
DEVICES: $DEVICES                             # desktop, mobile (nếu --mobile)
BASE_URL: $BASE_URL                           # http://localhost:3000

# 6. OUTPUT CONTRACT
| Path | Schema |
| $SESSION_DIR/F{x}/output1.json | f{x}-output-v1 |
| $SESSION_DIR/F{x}/F{x}-report.md | — (md, ≤15 dòng tiếng Việt) |
(chi tiết xem sub-skill _contract.json)

# 7. OWNERSHIP RULES
OWNER: $SESSION_DIR/F{x}/ (chỉ sub-skill ghi)
KHÔNG modify: e2e-status.json (orchestrator owns), .lock,
              outputs của F-step khác.

# 8. COMPLETION CRITERIA
✅ POST-GATE T1-T4 PASS cho mọi output
✅ F{x}-report.md viết tiếng Việt ≤15 dòng (CORE-028)
✅ Báo cáo:
   F{x}_STATUS=PASS|FAIL|DEGRADED
   F{x}_OUTPUTS=output1.json,F{x}-report.md
   F{x}_NEXT=F{y} | wait_for_user | done
```

---

## 4. Per-sub-skill specifics

### F0a — wf-e2e-finding

| Field | Value |
|-------|-------|
| Mandatory | ✅ |
| Spawn? | KHÔNG (in-process) — chỉ FIND, không IO heavy |
| Output | 8 finding files (business-rules, db-schema, api-contracts, ui-flows, cross-module-gaps, seed-requirements, test-scenarios, edge-cases) + 4 SSOT JSONs |
| Context budget | ~10-15% |

### F1 — wf-e2e-test

| Field | Value |
|-------|-------|
| Mandatory | ✅ |
| Spawn? | Có thể (in-process default, spawn nếu deep profile) |
| Consumes | F0a outputs (8 finding files) |
| Output | `findings/`, `outputs/{test-scenario,user-guide}.md` skeleton, `issues.json`, `block-test.json`, `implement-required.json`, `manual.json` |
| Context budget | ~20% |

### F2 — wf-e2e-browser

| Field | Value |
|-------|-------|
| Mandatory | ✅ |
| Spawn? | KHÔNG (browser session phải sequential) |
| Playwright | BẮT BUỘC mode=full (degrade nếu `--no-playwright`) |
| Output | screenshots, browser-test-report.md, network-trace.json |
| Context budget | ~15% (heavy browser interaction) |

### F3-F6 — Conditional fix loop

Spawn theo flag/condition. F4 có thể spawn `wf-implement-feature` nested (CDG required).

### F7 — wf-e2e-scenario, F8 — wf-e2e-demo

In-process, populate test scenarios + demo từ aggregated outputs.

---

## 5. Anti-patterns (orchestrator)

❌ **Spawn sub-skill PARALLEL khi không an toàn** — F1 và F2 có shared resources (browser session, Playwright context). Phải sequential.
❌ **Sub-skill modify e2e-status.json** — chỉ orchestrator được ghi, sub-skill chỉ ghi `F{x}/F{x}-report.md`.
❌ **Bỏ qua F0a trước F1** — F1 consume F0a output, skip → E0xx fail.
❌ **Skip F2 vì --no-playwright** — phải DEGRADE mode (status="degraded"), KHÔNG skip (vi phạm v8.0.0 spec).
❌ **Spawn sub-sub-skill** — sub-skill không được spawn skill khác (loop risk).

---

## 6. Liên kết

- Architecture: [`03-architecture.md`](03-architecture.md) — orchestration flow F0-F8
- Contract: [`04-contracts-data-model.md`](04-contracts-data-model.md) — `orchestrates[]` chi tiết
- Sub-skills source: [`../../../.claude/skills/workflow/wf-e2e-*/`](../../../.claude/skills/workflow/)
- Pattern: [`../../03-design-patterns/04-parallel-lane-dispatch.md`](../../03-design-patterns/04-parallel-lane-dispatch.md)
- Canonical agent template: [`../_template/agent-prompt.md`](../_template/agent-prompt.md)
