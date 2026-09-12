---
name: wf-fix-execute
version: 3.8.1
last_updated: 2026-09-12
description: |
  Execute + Report phase cho wf-fix-bugs. Sửa lỗi (Batch 1-3) + docs sync + verification loop + final report.
  Phase 3 (Fix): CRITICAL → HIGH (PARALLEL) → MEDIUM+LOW. Source-aware routing: static-scan → inline fix, runtime → agent fix, llm-scan → verify evidence trước fix.
  Phase 4 (Docs Sync): cập nhật feature specs khi behavior đổi.
  Phase 5 (Verify): State machine loop, max 3 iterations, loop-back + step verification (3.5) với retry.
  Phase 6 (Report): fix-report.md + fix-history.md + phase-summary.md. Dry-run: chạy đầy đủ (preview mode).

  CI-ROUTE BẮT BUỘC trong Phase 3 + CI PRE-GATE detection. QD11 enhancement signal filtering (escalate, KHÔNG fix). Process violation codes E027-E045.

  TRIGGER: spawned bởi /wf-fix-bugs (không gọi trực tiếp). Resume: /wf-fix-execute --resume

  Output: $SESSION_DIR/fix-log.json, fix-report.md, phase-summary.md, .mc-data/work/wf-fix-bugs/fix-history.md, updated $SESSION_DIR/issue-registry.json (final: verify results)

argument-hint: "[--resume] [--status]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__serena__replace_symbol_body, mcp__serena__insert_before_symbol, mcp__serena__insert_after_symbol, mcp__serena__replace_content, mcp__serena__rename_symbol, mcp__serena__safe_delete_symbol, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, mcp__plugin_gitnexus_gitnexus__rename, mcp__plugin_gitnexus_gitnexus__route_map, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-execute: Fix + Docs + Verify Phase (Orchestrator)

## Overview

| Muc | Noi dung |
|-----|----------|
| **Muc dich** | Sua loi theo triage plan, dong bo docs, verify ket qua, bao cao final |
| **Entry point** | Spawned boi wf-fix-bugs (khong goi truc tiep) hoac `--resume` |
| **Prerequisites** | `$SESSION_DIR/issue-registry.json` (sau triage), `fix-plan.md`, `fix-status.json` |
| **Duration** | 1-3 sessions tuy theo so luong issues + verify iterations |
| **Phases** | Phase 3 (Fix) → Phase 4 (Docs Sync) → Phase 5 (Verify Loop) → Phase 6 (Report) |
| **Output** | `fix-log.json`, updated `issue-registry.json`, `fix-report.md`, `phase-summary.md`, `fix-history.md` |

### Workflow Position

```
wf-fix-bugs (pure orchestrator)
  → Lane Dispatch (Phase 0-2: dimension scan + aggregation)
  → wf-fix-triage (Phase 2 Triage)
  → wf-fix-execute ← YOU ARE HERE
        Phase 3: Fix (Batch 1-3)
        Phase 4: Docs Sync + Stub Creation
        Phase 5: Verify Loop (max 3 iterations)
        Phase 6: Report
        ↓
  wf-fix-bugs POST-GATE → summary hien thi user
```

### Procedure Files (Lazy Loading)

Khi execute tung phase, doc file tuong ung trong `procedures/`:

| Phase | File | Muc dich |
|-------|------|----------|
| Shared | [`procedures/_shared.md`](procedures/_shared.md) | State vars, agent templates, fix-status contract, CDG, error codes |
| 3 Batch 1 | [`procedures/phase3-batch1.md`](procedures/phase3-batch1.md) | CRITICAL fix (sequential) |
| 3 Batch 2 | [`procedures/phase3-batch2.md`](procedures/phase3-batch2.md) | HIGH fix (PARALLEL: developer + security + domain expert) |
| 3 Batch 3 | [`procedures/phase3-batch3.md`](procedures/phase3-batch3.md) | MEDIUM/LOW + AGENT_FIX + fix-log flush |
| 4a | [`procedures/phase4a-docs-sync.md`](procedures/phase4a-docs-sync.md) | Cap nhat existing feature specs |
| 4b | [`procedures/phase4b-stubs.md`](procedures/phase4b-stubs.md) | Tao stub docs (--deep only, CDG) |
| 5 SCAN | [`procedures/phase5-scan.md`](procedures/phase5-scan.md) | VERIFY_INIT + VERIFY_SCAN + content quality + playwright + llm-regression-probe |
| 5 LOOP | [`procedures/phase5-loop.md`](procedures/phase5-loop.md) | VERIFY_EVALUATE + FIX + DOCS + RESCAN |
| 5 FINAL | [`procedures/phase5-final.md`](procedures/phase5-final.md) | VERIFY_FINAL metrics + override handling |
| 6 | [`procedures/phase6-report.md`](procedures/phase6-report.md) | fix-report.md + fix-history.md + phase-summary.md |

**Quy tac lazy loading:** Chi READ file procedure khi bat dau phase tuong ung, KHONG load toan bo upfront.

---

## Entry Point

**Khi duoc spawn boi wf-fix-bugs:**

wf-fix-bugs truyen context qua `$SESSION_DIR`. wf-fix-execute nhan:
- `$SESSION_DIR` = path den session directory (da co fix-status.json, issue-registry.json, fix-plan.md)

**Khi user dung `--resume`:**

wf-fix-execute tu tim latest session hoac dung scope de resolve.

---

## PRE-GATE

### CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8) — BẮT BUỘC

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools duoc auto-detect, khong hoi user (D7). Lock held → fallback Grep/Glob ngay (D8).
> wf-fix-execute nhan CI context tu orchestrator (wf-fix-bugs) NEU available; tu detect neu standalone `--resume`.

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** IF CI context passed from orchestrator → reuse flags. ELSE (standalone `--resume`): `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sanh HEAD vs index_commit. SEVERE (>20 behind) → warning: "Index stale — blast radius analysis may miss recent changes." | Freshness status set |
| 0.Nc | **Agent Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → append vao developer agent spawn instructions (Phase 3). IF no CI → exit 1 → continue Grep/Glob. CI context includes: CI-1 (impact before edit), CI-2 (references), CI-3 (detect_changes after fix). | CI context ready (hoac skipped) |

```
1. Nhan $SESSION_DIR tu caller
   IF --resume: scan .mc-data/work/wf-fix-bugs/ → tim session active
   IF --status: hien thi trang thai Phase 3-6 → STOP

2. READ $SESSION_DIR/fix-status.json → validate:
   - JSON valid: jq '.' fix-status.json
   - phases.phase_2.status == "completed" (triage da xong)
   - Detect $DRY_RUN_MODE = flags.dry_run

2a. **v6 Mode Detection:**
   $ENGINE_VERSION = jq -r '.engine_version // "v5"' fix-status.json
   IF $ENGINE_VERSION == "v6":
     $V6_MODE = true
     $DIMENSIONS_RESOLVED = jq -r '.dimensions_resolved // []' fix-status.json
   ELSE:
     $V6_MODE = false

3. READ $SESSION_DIR/issue-registry.json → validate:
   - Ton tai + valid JSON
   - issues co severity set (da qua triage Phase 2)
   - issues co `blast_radius` field (da duoc triage annotate — ADR-22 rule 2):
     jq -e '.issues | all(has("blast_radius"))' $SESSION_DIR/issue-registry.json
     → WARN neu thieu (dev se skip Verify Ripple severity bump), khong FAIL.
   - **v6 Mode:** Neu $V6_MODE == true → issue-registry.json co the la v2 schema
     voi them fields: dimensions_run[], engine_version, coverage{}, dedup_stats{}.

4. READ $SESSION_DIR/fix-plan.md → validate:
   - File ton tai + non-empty
   - Co batch plan (Batch 1, 2, 3)

4a. **Verify Ripple input (ADR-22 rule 2):** check `$SESSION_DIR/impact-graph.json`:
   jq -e '."$schema" == "impact-graph.v1"' $SESSION_DIR/impact-graph.json
   → PASS: Phase 5 se chay Verify Ripple (step 5.1b).
   → FAIL: log warning. Neu `flags.lpm_minimal == true` → skip Ripple gracefully;
     else → Phase 5 se FAIL tai step 5.1b (E_RIPPLE_NO_GRAPH).

5. Load execution context tu fix-status.json:
   - $TARGET_DIRS, $TARGET_SCOPE (scope boundaries)
   - $ARCH_DIGEST (architecture digest neu co)
   - $LARGE_PROJECT + LPM settings
   - $RUN_TESTS flag

5a. **v9.2.0 Context Injection (BAT BUOC):** Load 4 context types tu v9.2.0. Bash chi tiet trong [`procedures/_shared.md`](procedures/_shared.md#v920-source-aware-fix-protocol).

   | # | Context | Source File | Action neu trigger |
   |---|---------|-------------|--------------------|
   | a | **Process Violation Awareness** | `$SESSION_DIR/process-violations.json` | `PV_CRITICAL > 0` → DUNG, render CDG (E029): "Phase 1 co process violation CRITICAL. Tiep tuc execute?". User accept → ghi `process_violation_impact` vao fix-log metadata. |
   | b | **Source Distribution** | `$SESSION_DIR/issue-registry.json` (count by `source`) | Load `SOURCE_STATIC`, `SOURCE_RUNTIME`, `SOURCE_LLM` counts → source-aware fix routing per `_shared.md §Source → Fix Mode Routing`. |
   | c | **QD11 Enhancement Filtering** | `$SESSION_DIR/issue-registry.json` (`dimension_id == "QD11"`) | `QD11_FIXABLE_COUNT > 0` → bump fixability thanh "escalate" (E044). QD11 signals KHONG DUOC FIX — day vao escalations.json. |
   | d | **CDG Token Loading** | `$SESSION_DIR/cdg-tokens.json` | `CDG_REJECT_COUNT > 0` → respect reject tokens: KHONG thuc hien hanh dong bi reject. |

6. **Mode routing:**
   IF $DRY_RUN_MODE == true → SKIP Phase 3-5 → jump to Phase 6 (Report, preview mode)
   ELSE → continue Phase 3 → 4 → 5 → 6

7. **Task Planning (Protocol 9):** Init `TodoWrite` voi items ≥ so phase se chay:
   - Dry-run: ["Phase 6: Report (preview)"]
   - Fresh: ["Phase 3: Fix (Batch 1-3)", "Phase 4: Docs Sync", "Phase 5: Verify Loop", "Phase 6: Report"]
   - Resume: chua completed items + items tu current phase tro di

8. **Execution Trace START** (CORE-026, best-effort): APPEND entry vao `.mc-data/work/_trace/session-log.json`:
   `{ skill: "wf-fix-execute", phase: "phase_3" (hoac "phase_6" neu dry-run), event: "START", timestamp, run_sequence }`
   Xem [`procedures/_shared.md`](procedures/_shared.md#execution-trace-protocol).
```

**FAIL ung xu:**
- issue-registry.json khong ton tai → "issue-registry.json khong tim thay. Chay /wf-fix-bugs truoc."
- Triage chua xong → "Triage chua complete. Chay /wf-fix-bugs --resume."
- Khong co issues AUTO_FIX/AGENT_FIX trong fresh run → "Khong co issues de fix. Phase 6 Report se hien thi summary."

> Chi tiet state variables: xem [`procedures/_shared.md`](procedures/_shared.md#state-variables-glossary).

---

## Phase 3: Fix — Sua Loi (per batch)

> **BAT BUOC:** Truoc khi execute, READ [`procedures/_shared.md`](procedures/_shared.md) section "fix-status.json Update Contract" va "Developer Selection Protocol" va **"v9.2.0 Source-Aware Fix Protocol"**.

**PRE-GATE:** PRE-GATE passed. Update fix-status.json: `phases.phase_3.status="in_progress"`, `phases.phase_3.started_at=NOW`.

### v9.2.0 Pre-Fix Checks (BAT BUOC — truoc khi vao Batch 1)

1. **QD11 Filter:** FOR each issue in issue-registry.json WHERE `dimension_id == "QD11"`:
   - SET `fixability = "escalate"` (neu chua phai)
   - SKIP fix (E044 neu attempt fix)
   - Them vao escalations.json

2. **Source Distribution Report:** Log source counts vao fix-log metadata:
   ```bash
   jq --argjson s "$SOURCE_STATIC" --argjson r "$SOURCE_RUNTIME" --argjson l "$SOURCE_LLM" \
      '.metadata.source_distribution = {static_scan: $s, runtime: $r, llm_scan: $l}' \
      "$SESSION_DIR/fix-log.json"
   ```

3. **Process Violation Impact:** Neu `$PV_COUNT > 0` → ghi `process_violation_impact` vao fix-log metadata.

### Execution Sequence

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | Batch 1 (CRITICAL, Sequential) — READ [`procedures/phase3-batch1.md`](procedures/phase3-batch1.md) | Read + Edit | fix-log entries CRITICAL appended |
| 3.2 | Batch 2 (HIGH, PARALLEL dev+sec+domain) — READ [`procedures/phase3-batch2.md`](procedures/phase3-batch2.md) | Agent + Edit | fix-log entries HIGH appended |
| 3.3 | Batch 3 (MEDIUM+LOW+AGENT_FIX, Mixed) — READ [`procedures/phase3-batch3.md`](procedures/phase3-batch3.md) | Edit + Agent | fix-log entries MEDIUM/LOW appended |

**POST-GATE:** All batches completed. `jq '.entries | length > 0' fix-log.json`. `phases.phase_3.status="completed"`, `progress_pct=65`.

**v6 Mode — fix-log.json dimension field:** Neu $V6_MODE == true → moi fix-log entry them field `"dimension"` (VD: "QD1", "QD3") de track dimension-level fix metrics.

**v9.2.0 — fix-log.json source field:** Moi fix-log entry PHAI include `"source"` field (static-scan|runtime|llm-scan) de track source-level fix metrics.

**Context digest:** Sau moi batch checkpoint, MERGE `context_digest` vao `checkpoint.json` (ADDITIVE). Xem [`procedures/_shared.md`](procedures/_shared.md#context-digest-generation).

### Step Verification (Phase 3→4 Transition, v9.2.0)

Sau POST-GATE pass, goi step verification truoc khi chuyen sang Phase 4:

```bash
bash .claude/scripts/wf-fix-step-verify.sh --step=phase3_execute --session-dir="$SESSION_DIR"
RC=$?
if [ $RC -ne 0 ]; then
  # Retry (max 3 lan): Direct retry → Reduced scope → Manual fallback
  RETRY_COUNT=0
  while [ $RETRY_COUNT -lt 3 ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    bash .claude/scripts/wf-fix-step-verify.sh --step=phase3_execute --session-dir="$SESSION_DIR" && break
  done
  if [ $RETRY_COUNT -ge 3 ]; then
    bash .claude/scripts/wf-fix-record-process-violation.sh \
      --violation-id="PV-STEP-FAIL-phase3" --step="phase3_execute" \
      --retries=3 --session-dir="$SESSION_DIR"
    echo "[step-verify] E028 — Step Verification Fail phase3_execute" >&2
  fi
fi
```

---

## Phase 4: Docs Sync + Stub Creation

**PRE-GATE:** Phase 3 completed.

### Sub-Phases

| Phase | Condition | Procedure |
|-------|-----------|-----------|
| 4a | Always (neu co behavior changes) | READ [`procedures/phase4a-docs-sync.md`](procedures/phase4a-docs-sync.md) |
| 4b | CHI khi `flags.deep == true` | READ [`procedures/phase4b-stubs.md`](procedures/phase4b-stubs.md) |

**POST-GATE:** `jq '.' req-registry.json` PASS. Docs consistent voi code. `phases.phase_4.status="completed"`, `progress_pct=80`.

### Phase 4a Hook — Docs Sync Cross-Reference (S8, soft warn)

Sau khi Phase 4a complete (feature specs synced), chay docs-crossref check de detect bidirectional gaps.

```bash
bash .claude/scripts/wf-fix-docs-crossref.sh --session-dir "$SESSION_DIR" || true
```

- Output: `$SESSION_DIR/docs-sync-report.json` (schema `docs-sync-report-v1`).
- Status: `passed` | `warning` | `skipped` (skipped neu khong phai git repo).
- Mismatches[]: 2 type — `missing_git_diff` (fix-log claim update doc nhung git khong thay change) hoac `orphan_git_change` (git diff change feature spec nhung khong co fix-log entry).
- **KHONG block POST-GATE** — soft warning only. Mismatches log ra stderr + ghi vao docs-sync-report.json cho `wf-verify-sync` consume (S9 cross-skill consumer).
- Backward compat: graceful exit 0 khi git unavailable hoac fix-log empty.

---

## Phase 5: Verify — Xac nhan (STATE MACHINE LOOP)

**PRE-GATE:** Phase 3 + Phase 4 completed.

### State Machine Overview

```
VERIFY_INIT → VERIFY_SCAN → VERIFY_EVALUATE
                                   │
                    ┌──────────────┼──────────────┬────────────────┐
                    ▼              ▼              ▼                ▼
            VERIFY_FINAL    VERIFY_FIX →   VERIFY_FINAL      VERIFY_FINAL
               (PASS)          ↓              (FAIL:           (WARN:
                          VERIFY_DOCS      iter>=3 AND       iter>=3 AND
                               ↓          CRITICAL>0         HIGH>0 AND
                          VERIFY_RESCAN       E039)           !override)
                               ↓
                        VERIFY_EVALUATE
                               ↑
                   iteration < MAX_ITERATIONS (3)
                               │
                   OR (iteration == 3 AND HIGH>0 AND override_granted)
                               │  (iteration cap = 4, absolute max)
                               └─ no more CDG after iter 4
```

### Execution Sequence

| State Group | Procedure |
|-------------|-----------|
| INIT + SCAN + Content Quality + Playwright | READ [`procedures/phase5-scan.md`](procedures/phase5-scan.md) |
| EVALUATE + FIX + DOCS + RESCAN (loop) | READ [`procedures/phase5-loop.md`](procedures/phase5-loop.md) |
| FINAL (calculate metrics + override handling) | READ [`procedures/phase5-final.md`](procedures/phase5-final.md) |

**MAX_ITERATIONS = 3.** Sau iteration 3 con HIGH issues → CORE-027 CDG. Iteration 4 (neu override granted) la ABSOLUTE MAX.

**Loop-back rules:** APPEND-only cho fix-log.json, UPDATE (khong overwrite) cho issue-registry.json. Chi tiet: [`procedures/phase5-loop.md`](procedures/phase5-loop.md) §Loop-back Internal Protocol.

**v6 Mode — Verify Ripple:** Neu $V6_MODE == true → doc `$SESSION_DIR/impact-graph.json` cho ripple verification. Verify Ripple check depth=1, strength >= 0.5 (ADR-18). Neu impact-graph.json khong ton tai → WARN + skip ripple check (khong FAIL).

**POST-GATE:** Zero CRITICAL remaining (hoac user confirmed WARN). `fix_success_rate` calculated. `issue-registry.json` verify.verified=true cho tat ca fixed issues. `phases.phase_5.status="completed"`, `progress_pct=90`.

---

## Phase 6: Report — Bao cao ket qua

**PRE-GATE:**
- Fresh run: Phase 5 completed
- Dry-run: Phase 2 completed (Phase 3-5 da SKIP)

**Procedure:** READ [`procedures/phase6-report.md`](procedures/phase6-report.md)

**OUTPUT:**
- `$SESSION_DIR/fix-report.md` (tu template `templates/fix-report.md`)
- `.mc-data/work/wf-fix-bugs/fix-history.md` (tu template `templates/fix-history.md`, APPEND-ONLY cross-run)
- `$SESSION_DIR/phase-summary.md` (inline template, tieng Viet cho non-specialist)
- **v6 Mode:** Neu $V6_MODE == true → bao gom reference den `$SESSION_DIR/coverage-report.md` trong fix-report.md section "Dimension Coverage"

**POST-GATE:**
```bash
test -s $SESSION_DIR/fix-report.md \
  && test -s .mc-data/work/wf-fix-bugs/fix-history.md \
  && test -s $SESSION_DIR/phase-summary.md \
  && grep "Bug Fix Report" $SESSION_DIR/fix-report.md > /dev/null
```

### Phase 6 Pre-POST-GATE Hook — CQG Numeric Metric Verification (S8, hard-enforce)

Truoc khi POST-GATE pass, chay CQG verify de chan fantasy claims trong fix-report.md.

```bash
bash .claude/scripts/wf-fix-cqg-verify.sh --session-dir "$SESSION_DIR"
CQG_RC=$?
```

- Output: `$SESSION_DIR/cqg-verify.json` (schema `wf-fix-cqg-verify-v1`).
- 3 metrics: `issues_fixed_count`, `files_modified_count`, `coverage_pct`.
- Tolerance: ±5% mac dinh, configurable qua env `MCV3_FIX_CQG_TOLERANCE_PCT` hoac arg `--tolerance-pct N`.
- **HARD ENFORCE** — `CQG_RC=3` (mismatch >5%) → POST-GATE FAIL voi error code **E001 (CQG_NUMERIC_MISMATCH)**.
- Decision: nếu E001 → KHONG advance phase_6.status, render CDG (Protocol 16) hoi user `accept|reject|modify`. Reject → quay lai Phase 6 sua fix-report.md. Accept (override) → log decision vao cdg-tokens, advance.
- `CQG_RC=0` → continue normal POST-GATE.
- `CQG_RC=1` (script error) → log + escalate.

**Update fix-status.json theo spec "Phase 6 POST-GATE"** trong [`procedures/_shared.md`](procedures/_shared.md#fix-statusjson-update-contract).

---

## POST-GATE: Execute Complete (end of skill)

```
1. VALIDATE:
   - Fresh run: fix-log.json has entries, issue-registry.json verify.verified=true cho fixed issues
   - All runs: fix-report.md + fix-history.md + phase-summary.md exist
2. UPDATE $SESSION_DIR/fix-status.json:
   status = "completed"
   progress_pct = 100
   active_skill = "wf-fix-bugs"
   next_action = "done"
   timestamps.last_updated = NOW
   timestamps.completed_at = NOW
3. **Execution Trace COMPLETE** (CORE-026, best-effort): APPEND entry vao `.mc-data/work/_trace/session-log.json`:
   `{ skill: "wf-fix-execute", phase: "phase_6", event: "COMPLETE", timestamp, agents_invoked[], files_created[], files_modified[], warnings[], decisions[] }`
4. Hien thi summary inline. Returning to wf-fix-bugs orchestrator.
```

**FAIL event (neu POST-GATE Phase 3-6 fail sau 3 retries):**
APPEND entry: `{ skill: "wf-fix-execute", phase: "[phase dung]", event: "FAIL", timestamp, errors[] }`. Xem [`procedures/_shared.md`](procedures/_shared.md#execution-trace-protocol).

---

## Resume Logic (--resume)

```
1. Scan hoac resolve $SESSION_DIR
2. READ $SESSION_DIR/fix-status.json
3. VALIDATE phases.phase_2.status == "completed" AND phases.phase_6.status != "completed"
4. READ $SESSION_DIR/checkpoint.json → load resume point:
   - current_phase (phase_3 / phase_4 / phase_5)
   - current_batch (batch_1 / batch_2 / batch_3)
   - verify_loop_state (neu phase_5): state, current_iteration
5. READ $SESSION_DIR/issue-registry.json (reload trang thai hien tai)
6. READ $SESSION_DIR/fix-log.json (reload fix log)
7. IF current_phase == "phase_5" AND fix-status.json co loop_state:
   # v7.0 SSOT: fix-status.json la nguon duy nhat cho current_iteration.
   # Checkpoint chi giu state/override/history (KHONG giu current_iteration — deprecated v7.0).
   iteration = fix-status.phases.phase_5.loop_state.current_iteration  # khong co → 0
   state = fix-status.phases.phase_5.loop_state.state
          OR checkpoint.verify_loop_state.state                          # fallback chi cho state
          OR "VERIFY_INIT"
   override_granted = fix-status.phases.phase_5.override_granted          # false default
   # Backward compat: neu checkpoint legacy van co verify_loop_state.current_iteration → IGNORE.
   Continue tu state machine position → READ procedures/phase5-{scan,loop,final}.md theo state
8. IF current_phase == "phase_3":
   Skip completed batches (batch_1/2 completed → start tu batch_3)
9. Hien thi resume summary cho user xac nhan
```

---

## Output Files

| # | File | Duong dan | Phase | Template |
|---|------|-----------|-------|----------|
| 1 | Fix log | `$SESSION_DIR/fix-log.json` | 3 | `../wf-fix-bugs/templates/phase5-triage/fix-log.json` (canonical schema fix-log-v2, Sprint 3 XF-03) |
| 2 | Issue registry (updated) | `$SESSION_DIR/issue-registry.json` | 3, 5 | UPDATE (da tao boi wf-fix-bugs orchestrator) |
| 3 | Updated feature specs | `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md` | 4a | — (edit existing) |
| 4 | Updated registry | `.mc-data/docs/_meta/req-registry.json` | 4a | — (safe-write: chi `impl_status`) |
| 5 | Stub feature specs (--deep) | `.mc-data/docs/phase2-features/[sys]/[mod]/[slug].md` | 4b | — (stub only, status: stub) |
| 6 | Stub UX docs (--deep) | `.mc-data/docs/phase4-ux/[sys]/[mod]/screens-[slug].md` | 4b | — (stub only, status: stub) |
| 7 | Stub flow docs (--deep) | `.mc-data/docs/phase2-features/[sys]/[mod]/flow-[slug].md` | 4b | — (stub only, status: stub) |
| 8 | E2E results | `$SESSION_DIR/e2e-results.json` | 5 | `templates/e2e-results.json` |
| 9 | Fix report | `$SESSION_DIR/fix-report.md` | 6 | `templates/fix-report.md` |
| 10 | Fix history (cross-run) | `.mc-data/work/wf-fix-bugs/fix-history.md` | 6 | `templates/fix-history.md` (APPEND-ONLY) |
| 11 | Phase summary | `$SESSION_DIR/phase-summary.md` | 6 | Inline template (CORE-028) |
| 12 | Execution trace (CORE-026) | `.mc-data/work/_trace/session-log.json` | PG, 6 | `doc-framework/_meta/session-log.template.json` (APPEND-ONLY) |

---

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/`

- **Accuracy Assurance** (moi phase): POST-GATE Enforcement + Fix Rules + Error Tracking
- **Auto-Correction Loop** (Phase 5): max 3 iterations
- **Registry Safe-Write** (Phase 4a): CHI update `impl_status` per REQ-ID — **KHONG downgrade "done"**
- **Parallel Execution** (Protocol 7): Batch 2 HIGH — developer + security PARALLEL, sub-batch khi > 15 issues
- **Content Quality Gate** (Protocol 8): Phase 5 — verify fix-report metrics khop voi thuc te
- **Template Usage** (Protocol 19 / CORE-031): READ template → POPULATE → WRITE cho fix-log.json

> Chi tiet per-phase: xem cac file trong `procedures/` (lazy load).

---

## Registry Update (Safe-Write)

- **Fields duoc phep update:** `impl_status` (per REQ-ID, safe-update only)
- **Safe-update rule:** KHONG downgrade tu "done" → gia tri khac
- **Rollback:** Neu fix gay regression → revert `impl_status` ve gia tri truoc fix
- **Atomic write:** Single write cho toan bo JSON
- **Read-before-write:** Luon doc registry fresh ngay truoc khi ghi

> Chi tiet: [`procedures/_shared.md`](procedures/_shared.md#registry-safe-write).

---

## Error Handling

> Chi tiet error codes: [`procedures/_shared.md`](procedures/_shared.md#error-codes).

| Code | Tinh huong | Xu ly |
|------|------------|-------|
| E005 | Developer agent fix gay regression | Rollback fix → escalate voi context |
| E006 | Tests fail sau fix | Retry fix (max 3 lan), neu van fail → escalate |
| E007 | Feature spec khong tim thay cho behavior change | Log WARNING, tiep tuc |
| E008 | Registry JSON invalid sau update | Retry x3, rollback neu van fail |
| E013 | Playwright navigate that bai | LOG warning, skip gracefully |
| E017 | Auth required khi playwright verify | Apply 4-giai-doan auto-login |
| E039 | CRITICAL issues remain sau iter 3 (hoac 4 neu override) | LOG error, mark status=FAIL, bao gom trong fix-report.md section "Unfixed Critical Issues" |
| E040 | Loop fix gay regression moi | LOG warning, them vao issue-registry.json. Max 5 regressions → ESCALATE |
| E041 | CQG numeric metrics mismatch trong fix-report.md sau 3 retries | POST-GATE FAIL E001 (CQG_NUMERIC_MISMATCH). Render CDG (Protocol 16) hoi user accept|reject|modify. Reject → quay lai Phase 6 sua fix-report. KHONG advance cho den khi mismatch duoc resolve. |
| E027 | Workload Missing — khong tim thay fix-workload.json | Ghi process violation, dung auto-generated workload, CDG render |
| E028 | Step Verification Fail — execute step chua hoan thanh sau 3 retries | CDG render: skip/abort/manual-fix |
| E029 | Process Violation critical — Phase 1 scan khong day du | CDG render: tiep tuc execute hay re-run Phase 1 |
| E044 | QD11 Fix Attempt — attempt fix QD11 enhancement signal | Block fix, set fixability="escalate", log violation |
| E045 | LLM Fix Without Verification — LLM-scan signal fixed without evidence re-verify | Block fix, require evidence re-verification truoc khi proceed |

---

## Related Skills

| Skill | Quan he |
|-------|---------|
| `/wf-fix-bugs` | **Parent orchestrator** — chay Lane Dispatch (Phase 0-2), tao fix-status.json + issue-registry.json, spawn wf-fix-execute |
| `/wf-fix-triage` | **Sibling** — enrich issue-registry.json + tao fix-plan.md |
| `/wf-verify-sync` | Nhan fix-report.md + issue-registry.json sau Execute complete |
| `/wf-define-features` | Nhan stub feature specs (Phase 4b --deep, conditional) |
| `/wf-design-ux` | Nhan stub UX docs (Phase 4b --deep, conditional) |

**Next:** `/wf-fix-bugs` orchestrator ket thuc sau khi wf-fix-execute complete. User chay `/wf-verify-sync` de xac nhan registry dong bo.
