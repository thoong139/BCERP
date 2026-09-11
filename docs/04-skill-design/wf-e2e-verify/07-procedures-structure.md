# 07 — Procedures Structure

> **Mục đích file:** Outline 7 procedure files của orchestrator — CORE-032 lazy-load. Logic spawn sub-skill nằm trong `orchestrate.md`.

---

## 1. Layout

```
.claude/skills/workflow/wf-e2e-verify/procedures/
├── _shared.md                  ← Cross-cutting concerns (NOT loaded standalone)
├── orchestrate.md              ← Main orchestration: spawn F1-F8 sequential
├── skip-rules.md               ← Conditional logic cho F3/F4/F6
├── legacy-flags.md             ← Detect + map legacy flags + WARN
├── resume-status.md            ← --resume + --status handlers
├── phase0-infra-check.md       ← F0 inline orchestration (infra validation)
└── phase1.5-seed-manifest.md   ← F0b inline orchestration (conditional seed)
```

**Quy tắc lazy-load (CORE-032):** Chỉ load khi tới phase tương ứng. SKILL.md routing table định nghĩa thứ tự.

---

## 2. `_shared.md` content (reference-only)

| Section | Mục đích |
|---------|---------|
| **§init** | Resolve session, create e2e-status.json từ template, acquire .lock, parse flags. Atomic write helpers (`atomic_write_status`, `atomic_append_jsonl`) |
| **§Spawn helpers** | `spawn_subskill()` function — wraps Agent tool spawn với 8-section prompt template (CORE-037) |
| **§SSOT helpers** | `ssot_append()`, `ssot_update()` — atomic jq operations cho 4 SSOT JSONs |
| **§Anti-loop counters** | `incr_anti_loop()`, `check_anti_loop_threshold()` — read/write `e2e-status.json.anti_loop` |
| **§POST-VERIFY** | `postverify_step()` — T1-T4 tiered checks per step |
| **§Error handling** | `escalate()`, `ledger_log()`, `record_error()` |
| **§CI detection** | Wrappers cho `ci-detect.sh`, `ci-freshness-check.sh`, `ci-inject-context.sh` |
| **§strip_metadata** | Helper xóa `_template_notes`, `_schema_notes` blocks |

---

## 3. `orchestrate.md` — Main flow

Spawn F1-F8 sequential theo flow trong [03-phase-routing.md](03-phase-routing.md) §2.

### Pseudo-code outline

```bash
# After F0 + F0a (mandatory):

for STEP in F0b F1 F2 F3 F4 F5 F6 F7 F8; do
  # 1. Check skip conditions (delegated to skip-rules.md)
  SKIP_REASON=$(check_skip "$STEP")
  if [ -n "$SKIP_REASON" ]; then
    update_step_status "$STEP" skipped "$SKIP_REASON"
    continue
  fi

  # 2. Pre-spawn: update e2e-status.json
  update_step_status "$STEP" running

  # 3. Spawn sub-skill via spawn_subskill() helper
  spawn_subskill "$STEP" "$SUB_SKILL_NAME" "$PASSES"

  # 4. POST-VERIFY
  if ! postverify_step "$STEP"; then
    retry_or_escalate "$STEP"
  fi

  # 5. Anti-loop check (F6 only)
  if [ "$STEP" = "F6" ]; then
    incr_anti_loop "f6_f5_loop_count"
    if check_anti_loop_threshold "f6_f5_loop_count" 3; then
      escalate "E004" "Anti-loop F6↔F5 max 3 vòng"
    fi
    # Loop back to F5
    continue
  fi

  # 6. Update step status
  update_step_status "$STEP" completed
done

# Finalize
finalize_orchestrator
```

---

## 4. `skip-rules.md` — Conditional logic

| Step | Skip rule | Decision source |
|------|-----------|----------------|
| F0b | `--no-seed` flag OR `seed-requirements.json` không tồn tại | flags + F0a output |
| F2 | `--skip=F2` flag | flags |
| F3 | `block-test.json` blocked count == 0 | jq query |
| F4 | `implement-required.json` pending count == 0 | jq query |
| F5 | KHÔNG SKIP (luôn run sau F4 hoặc khi có PENDING) | always |
| F6 | `issues.json` open count == 0 OR `f6_f5_loop_count >= 3` | jq + anti-loop |
| F7 | `--skip=F7` flag | flags |
| F8 | `--skip=F8` flag | flags |
| F0 / F0a | KHÔNG thể skip (mandatory) | error nếu user `--skip=F0` |

---

## 5. `legacy-flags.md` — Backward-compat

| Detect logic | Action |
|--------------|--------|
| `$ARGUMENTS` contains `--parallel-safe` | Track WARN trong `legacy_flags_used[]`, no-op |
| `$ARGUMENTS` contains `--cross-module` | Track WARN, no-op |
| `$ARGUMENTS` contains `--playwright-mcp` | Track WARN, no-op |
| `$ARGUMENTS` contains `--phase=N` (N 0-6) | Track WARN, map sang `--from-step=F1` |
| `$ARGUMENTS` contains `--phase=7` | Track WARN, map sang `--from-step=F7` |
| `$ARGUMENTS` contains `--fix=<path>` | Track WARN, map sang `--from-step=F6` + standalone mode |
| `$ARGUMENTS` contains `--retest` | Track WARN, map sang `--from-step=F5` + standalone mode |
| `$ARGUMENTS` contains `--unblock-test` | Track WARN, map sang `--from-step=F3` + standalone mode |
| `$ARGUMENTS` contains `--no-playwright` (v7.1.0+) | Track WARN, IGNORE flag |

Output WARN messages format:
```
[WARN] --parallel-safe is DEPRECATED — always enabled. Tracked in legacy_flags_used.
[WARN] --no-playwright is DEPRECATED v7.1.0 — IGNORED. Use --skip=F2,F5,F7,F8 explicit if CI lacks browser.
```

---

## 6. `resume-status.md` — Resume + status handlers

### `--status` mode

```
1. Read e2e-status.json + 4 SSOT JSONs
2. Render dashboard:
   - 8-step pipeline table
   - SSOT counters (issues, block-test, implement-required, manual)
   - Anti-loop counter
   - Context %
   - Next action
3. STOP (no execution)
```

### `--resume` mode

```
1. Discover session: 
   - If --session=<id>: use that
   - Else: find latest matching $FEAT_ID
2. Stale check: lock age >30 min → auto-release
3. Read e2e-status.json:
   - Find first incomplete step (status != completed/skipped/failed)
   - Re-validate prereq outputs of earlier steps
4. Resume từ first incomplete step:
   - Sub-skill spawn idempotent (skip nếu đã done)
   - Continue from sub-step nếu sub-skill có internal checkpoint
5. Continue pipeline forward
```

---

## 7. `phase0-infra-check.md` — F0 inline orchestration

Lý do inline: F0 đơn giản, không cần Agent spawn complex.

```
Steps:
  0.1 Check backend health (curl -f $BACKEND_URL/health) → exit code
  0.2 Check frontend health
  0.3 Check Playwright MCP available
  0.4 Check DB connection (psql -c "SELECT 1" hoặc tương đương)
  0.5 Aggregate → infra-blockers.json
  0.6 IF blockers > 0 → STOP (E011-E014)
  0.7 IF blockers == 0 → proceed F0a
```

---

## 8. `phase1.5-seed-manifest.md` — F0b inline orchestration

Conditional: chỉ chạy khi `seed-requirements.json` tồn tại (F0a output) AND `!--no-seed`.

```
Steps:
  0b.1 Read seed-requirements.json
  0b.2 Spawn wf-e2e-seed-manifest sub-skill
  0b.3 POST-VERIFY seed manifest complete
  0b.4 IF fail → BLOCKED_SEED (E017/E018) → escalate
  0b.5 IF pass → proceed F1
```

---

## 9. SKILL.md routing → procedures (lazy-load contract)

`SKILL.md` (lean routing hub ~450 dòng) chứa bảng:

```markdown
## Phase Routing (CORE-032 lazy-load)

| Step | Procedure | Description |
|------|-----------|-------------|
| Init | procedures/_shared.md §init | Resolve session, create e2e-status.json |
| Legacy Flag Mapping | procedures/legacy-flags.md | Detect + map legacy flags |
| Main Orchestration | procedures/orchestrate.md | Spawn F1-F8 sequential |
| Skip Rules | procedures/skip-rules.md | Conditional logic |
| Resume/Status | procedures/resume-status.md | --resume + --status |
```

**Quy tắc:** SKILL.md KHÔNG chứa execution logic. Logic live trong procedure files.

---

## 10. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Pattern: [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md) — 8-section prompt cho sub-skill spawn
- Rules: CORE-032, CORE-035, CORE-037
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §3-4 (Orchestrator pattern)
- Source SKILL.md: [`.claude/skills/workflow/wf-e2e-verify/SKILL.md`](../../../.claude/skills/workflow/wf-e2e-verify/SKILL.md)
