# Checklist: Sub-Skill Migration (Phase D — v2.1 NEW)

> **Purpose:** Verify wf-legacy-classify + wf-legacy-extract migrate đọc+ghi scan-state.json trực tiếp, bỏ reverse-sync.
> **Apply to:** Phase D tasks D.1, D.2, D.3, D.8.
> **Reference:** ADR-LS04 (v2.1 revised), [../../04-data-model.md §1.3](../../04-data-model.md).

---

## Prerequisites

- [ ] `scan_state_reader.py` helper implement đầy đủ API (Task D.1)
- [ ] Unit tests pass for helper
- [ ] Orchestrator (wf-legacy-scan) write scan-state.json correctly (Phase B)

---

## wf-legacy-classify Migration

### SKILL.md Changes

- [ ] **Prerequisites section** đọc scan-state.json:
  - Before: "inventory/*.json + project-profile.json + ledger.json"
  - After: "scan-state.json trong active session + inventory/*.json"

- [ ] **Outputs section** update:
  - Keep: `classified/batch-*.json`, `classified/glossary.json`, `classify-naming-fixes.json`
  - Remove: direct ledger.json write
  - Add note: "scan-state.layers.L4 updated qua helper"

### Procedure Files

- [ ] `procedures/_shared.md` document helper functions (read_scan_state, update_batch_progress, etc.)
- [ ] `procedures/phase0-detection.md` (hoặc equivalent PRE-GATE file):
  - [ ] PRE-GATE check scan-state.json exists
  - [ ] Fallback: nếu no session → `init_or_load_session()` (helper migrate from ledger.json)
- [ ] Classification phase procedure:
  - [ ] Call `update_layer_status("L4", "in_progress")` at start
  - [ ] Per batch: `update_batch_progress("L4", {...})`
  - [ ] End: `update_layer_status("L4", "completed")`
  - [ ] Errors: `append_error("L4", {...})`

### `_contract.json` Updates

- [ ] Inputs:
  - Add `sessions/{id}/scan-state.json` (required)
- [ ] Outputs:
  - Remove `ledger.json` from writes
  - Keep classified/ outputs
- [ ] Registry scope unchanged (NONE)

### Behavioural Tests

- [ ] **Standalone run (fresh):**
  ```bash
  cd fixtures/small-en/
  rm -rf .mc-data/
  /wf-legacy-classify
  # Expect: error — no session + no ledger → suggest /wf-legacy-scan first
  ```

- [ ] **Standalone run (after v4.1 scan):**
  ```bash
  # Simulate v4.1 baseline
  cp -r fixtures/small-en.baseline-v4.1/ fixtures/small-en/.mc-data/work/legacy-scan
  /wf-legacy-classify --resume
  # Expect: helper auto-migrate ledger → scan-state → continue
  ls .mc-data/work/legacy-scan/sessions/  # new session created
  jq '.layers.L4.status' .mc-data/work/legacy-scan/sessions/*/scan-state.json
  # Expect: "completed"
  ```

- [ ] **Orchestrated run:**
  ```bash
  /wf-legacy-scan . --profile=standard
  # wf-legacy-classify delegate should work trong flow
  jq '.layers.L4.batch_progress' .mc-data/work/legacy-scan/sessions/*/scan-state.json
  ```

- [ ] **Ledger.json KHÔNG bị sub-skill ghi:**
  ```bash
  # During classify phase, ledger.json mtime should not change
  MTIME_BEFORE=$(stat -c %Y .mc-data/work/legacy-scan/ledger.json 2>/dev/null || echo 0)
  /wf-legacy-classify --resume  # in middle of pipeline
  MTIME_AFTER=$(stat -c %Y .mc-data/work/legacy-scan/ledger.json 2>/dev/null || echo 0)
  [ "$MTIME_BEFORE" = "$MTIME_AFTER" ] && echo "✓ ledger untouched" || echo "❌ ledger modified"
  ```

- [ ] **scan-state state machine enforced:**
  - Invalid transition raises ValueError
  - `completed` → `in_progress` rejected

---

## wf-legacy-extract Migration

Same pattern as classify. Specific checks:

### SKILL.md Changes

- [ ] Prerequisites: scan-state.json + classified/*.json
- [ ] Outputs: extracted/{module}.json + module-code-mapping.json + dedup-report.json; NO direct ledger write

### Procedure Files

- [ ] Use `update_module_progress("L5", module, "completed")` instead of batch
- [ ] Use `get_domain_expert_for_module(module)` helper for spawn decision (threshold 0.6)

### Behavioural Tests

- [ ] **Standalone run after classify:**
  ```bash
  # Setup: run scan + classify complete
  /wf-legacy-scan fixtures/medium-vn/ --profile=standard
  # Kill mid-extract
  # Resume
  /wf-legacy-extract --resume
  # Expect: helper load active session, continue from L5 module N+1
  ```

- [ ] **L5 agent routing via helper:**
  ```bash
  # Check logs trong session-log.json
  jq '.events[] | select(.event == "agent_spawn")' \
     .mc-data/work/legacy-scan/sessions/*/events.jsonl
  # Expect: "agent_type" = "business-analyst" + optional "<domain>-expert"
  ```

- [ ] **CORE-029 spot-check integrated:**
  ```bash
  # Check POST-GATE logs for spot-check verdict
  grep "spot_check" .mc-data/work/legacy-scan/sessions/*/error-ledger.json
  # If spot-check fail → auto-fix or escalate logged
  ```

---

## Helper API Coverage Check

`scan_state_reader.py` must implement all API used by sub-skills:

- [ ] `read_scan_state(session_id=None)` — used by PRE-GATE
- [ ] `read_depth_map(session_id=None)` — used for profile-aware behaviour
- [ ] `read_ips_phase_a(session_id=None)` — domain hints
- [ ] `read_ips_phase_b(session_id=None)` — module routing
- [ ] `get_domain_expert_for_module(module)` — L5 agent selection (threshold 0.6)
- [ ] `update_layer_status(layer, status, session_id=None)` — state transitions
- [ ] `update_batch_progress(layer, progress)` — L4 progress
- [ ] `update_module_progress(layer, module, status)` — L5 progress
- [ ] `append_error(layer, error)` — error tracking
- [ ] `append_layer_output(layer, output_path)` — track outputs
- [ ] `init_or_load_session(project_path)` — standalone fallback

---

## Concurrent Access Safety

- [ ] **File-lock honored:** concurrent sub-skill invocations → 2nd waits or refuses
  ```bash
  /wf-legacy-classify --resume &
  PID1=$!
  sleep 2
  /wf-legacy-classify --resume
  # Expect: 2nd exits with lock busy message
  wait $PID1
  ```

- [ ] **Atomic writes:** no partial writes observable
  ```bash
  # During heavy write, state always valid
  while /wf-legacy-classify --resume; do
    # In another terminal, continuously read
    while true; do
      jq empty .mc-data/work/legacy-scan/sessions/*/scan-state.json 2>/dev/null \
        || echo "CORRUPT at $(date)"
      sleep 0.1
    done &
    break
  done
  ```
  Expect: no CORRUPT messages

---

## Rollback Plan

Nếu migration fail at Phase D:

1. **Revert sub-skill procedures:**
   ```bash
   git checkout main -- .claude/skills/workflow/wf-legacy-classify/
   git checkout main -- .claude/skills/workflow/wf-legacy-extract/
   ```

2. **Re-enable reverse-sync** (emergency):
   - Restore orchestrator logic đọc ledger.json mtime → merge về scan-state
   - Accept short-term debt
   - Create follow-up issue for proper v2.1 migration

3. **Escalate to Owner** nếu không resolve trong 1 ngày.

---

## Acceptance Criteria (Phase D Exit)

- [ ] Sub-skills migrated: KHÔNG write ledger.json
- [ ] Helper API coverage 100% for sub-skill needs
- [ ] Standalone run works (fallback init)
- [ ] Orchestrated run works (use existing session)
- [ ] Concurrent access safe (file-lock + atomic)
- [ ] Backward-compat golden test PASS (checklist: backward-compat-lock.md)
