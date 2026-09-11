# Phase 6: Execute Fix — wf-fix-bugs v11.0.1 (Lazy-Load Router + Fix Iteration Loop)

> Procedure Phase 6 split thành 8 sub-files trong [`phase6-execute/`](phase6-execute/) — orchestrator đọc index này, sau đó load TỪNG GROUP file khi tới execution.
>
> **v11.0.1 orchestrator loop-back wiring (2026-05-17):** Wave 2 G2 fix iteration loop giờ có explicit ROUTING DECISION ở orchestrator level (xem §Orchestrator Execution Pattern bước 7b). Khi Step 6.5b loop check returns `next_action=spawn_execute_with_unsanctioned` → orchestrator quay lại Group D với context thu hẹp (LOOP_ITERATION + UNSANCTIONED_FOCUS). Max 3 iterations enforced bởi `.fix-iteration-count` file + `fix-iteration-loop.sh` decision tree.
> **v10.16.0 lazy-load:** Trước: 1 file 619 dòng (~6K tokens) load 1 lần. Sau: 90-dòng index + group files 50-160 dòng load on-demand. Per-group context ~500-1200 tokens.
> **v10.16.0 shared trace:** Step 6.7 migrate từ `finalize-phase6.sh` sang `phase-finalize.sh` (shared cho Phase 2-7).

## PRE-GATE (cho toàn bộ Phase 6)

```bash
test -s "$SESSION_DIR/fix-status.json"
jq -e '.phases.phase5.status == "completed"' "$SESSION_DIR/fix-status.json"
test -s "$SESSION_DIR/phase5-triage/fix-plan.md"
test -s "$SESSION_DIR/phase5-triage/issue-registry.json"
```

## Input / Output Contract

- **Input:** `phase5-triage/{issue-registry.json, fix-plan.md, bug-triage.md, cdg-tokens.json, fix-log.json}`, `fix-status.json`, `$CI_CONTEXT`, `$DRY_RUN`, `$PROFILE`, `$INTERFACE_TYPE`
- **Output (files):** xem [`phase6-execute/POST-GATE.md`](phase6-execute/POST-GATE.md) §T1-T5
- **In-memory state truyền sang Phase 7:** `$FIXED_COUNT`, `$DEFERRED_COUNT`, `$FAILED_COUNT`, `$FILES_CHANGED`

## Execution Flow (7 Groups, 7 Steps + v11 Fix Iteration Loop)

```
Group A: Setup Execute       (Step 6.1)        Sequential (PRE-GATE + CDG verify + TRACE START)
    ↓
Group B: Dry-Run Check       (Step 6.2)        BRANCHING (DRY_RUN=true → skip to F+G)
    ↓ (live)                                    ↓ (dry-run)
Group C: CI Impact + CDG     (Step 6.3)        INLINE Fast/Slow Path + AskUserQuestion
    ↓                                            ↓
Group D: Spawn Execute Agent (Step 6.4)        INLINE Agent({...}) call
    ↓ ◄──────────────┐                          ↓
                     │ (v11 loop-back)
Group E: Validate+Dashboard  (Step 6.5)        Sequential (script delegated)
    ↓                │                          ↓
    │ (Step 6.5b)    │
    │ fix-iteration-loop.sh decision:
    │ ├─→ continue_loop ─┘  (iter++, re-spawn execute với UNSANCTIONED_FOCUS=true)
    │ ├─→ escalate_cdg → 6.5c CDG E095 AskUserQuestion → user decides
    │ └─→ done → continue Group F
    ↓
Group F: Phase Report        (Step 6.6)  ←─────┘  (dry-run branch joins here)
    ↓
Group G: Finalize            (Step 6.7)        Sequential (phase-finalize.sh)
    ↓
POST-GATE T1-T5 Validation
    ↓
→ Phase 7
```

## Group Routing Table (lazy-load — đọc file khi tới group)

| Group | File path | Steps | Lines | Khi đọc |
|-------|-----------|-------|-------|---------|
| **A** | [`phase6-execute/A-setup.md`](phase6-execute/A-setup.md) | 6.1 | ~70 | Ngay sau khi vào Phase 6 (PRE-GATE PASS) |
| **B** | [`phase6-execute/B-dry-run.md`](phase6-execute/B-dry-run.md) | 6.2 | ~55 | Sau Group A POST-GATE PASS |
| **C** | [`phase6-execute/C-impact-cdg.md`](phase6-execute/C-impact-cdg.md) | 6.3 | ~140 | Sau Group B POST-GATE PASS (LIVE mode only) |
| **D** | [`phase6-execute/D-spawn-execute.md`](phase6-execute/D-spawn-execute.md) | 6.4 | ~100 | Sau Group C POST-GATE PASS |
| **E** | [`phase6-execute/E-validate-dashboard.md`](phase6-execute/E-validate-dashboard.md) | 6.5 | ~90 | Sau Group D POST-GATE PASS |
| **F** | [`phase6-execute/F-report.md`](phase6-execute/F-report.md) | 6.6 | ~55 | Sau Group E POST-GATE PASS (hoặc trực tiếp từ B nếu DRY_RUN) |
| **G** | [`phase6-execute/G-finalize.md`](phase6-execute/G-finalize.md) | 6.7 | ~70 | Sau Group F POST-GATE PASS |
| **POST-GATE** | [`phase6-execute/POST-GATE.md`](phase6-execute/POST-GATE.md) | T1-T5 + error ref | ~80 | Cuối Phase 6, trước khi advance Phase 7 |

**Total nếu load tất cả: ~660 dòng (≈ cũ 619 dòng).** Incremental loading: chỉ ~500-1200 tokens per group tại một thời điểm.

## Shared Protocols (lazy-load per use-site)

Mỗi group file declare TỪNG shared protocol cần dùng ở header — orchestrator chỉ load khi vào group đó. Tham khảo nhanh:

| Shared file | Dùng bởi Group |
|-------------|----------------|
| [_shared/20-cdg-tokens.md](_shared/20-cdg-tokens.md) | A (Step 6.1 verify all accepted) |
| [_shared/16-critical-decision-gate.md](_shared/16-critical-decision-gate.md) | C (Step 6.3 CDG HIGH/CRITICAL) |
| [_shared/12-ci-detection.md](_shared/12-ci-detection.md) | C (Step 6.3 CI-ROUTE), D (Step 6.4 CI context) |
| [_shared/15-agent-prompts.md](_shared/15-agent-prompts.md) | D (Step 6.4 Execute Agent prompt) |
| [_shared/07-execution-trace.md](_shared/07-execution-trace.md) | G (reference for finalize pattern) |

**KHÔNG đọc toàn bộ `_shared/` folder.**

## Orchestrator Execution Pattern (v11.0.1 — Fix Iteration Loop wired)

```
1. Đọc phase6-execute.md (file này, ~120 dòng)
2. Verify PRE-GATE
3. Đọc phase6-execute/A-setup.md → execute Step 6.1 → Group A POST-GATE
4. Đọc phase6-execute/B-dry-run.md → execute Step 6.2
   ├─ IF DRY_RUN=true: skip to Group F (phase6-execute/F-report.md) → G
   └─ IF DRY_RUN=false: continue
5. Đọc phase6-execute/C-impact-cdg.md → execute Step 6.3 (INLINE CDG) → Group C POST-GATE
6. Đọc phase6-execute/D-spawn-execute.md → execute Step 6.4 (INLINE Agent spawn) → Group D POST-GATE
   ★ v11: nếu đây là loop iteration N > 0 → INJECT context vars vào agent prompt:
     - LOOP_ITERATION=$CURRENT_ITER
     - UNSANCTIONED_FOCUS=true (chỉ fix items trong unsanctioned-defers.json)
     - PRIOR_ITERATIONS_SUMMARY (concat from fix-iterations.json[].agent_decisions)
7. Đọc phase6-execute/E-validate-dashboard.md → execute Step 6.5 → Group E POST-GATE
   ★ v11 (Step 6.5b — sau verify-execute-outputs.sh PASS):
     a. Run: bash verify-defer-reasons.sh → unsanctioned-defers.json
     b. Run: LOOP_DECISION=$(bash fix-iteration-loop.sh)
     c. Extract: DECISION + NEXT_ACTION + CURRENT_ITER + UNSANCT_COUNT
     d. Route theo NEXT_ACTION:
        ┌─ "spawn_execute_with_unsanctioned" → GOTO Step 6.4 (Group D) với
        │  LOOP_ITERATION=$CURRENT_ITER + UNSANCTIONED_FOCUS=true. Max 3 lần.
        │  Sau loop-back: re-run Step 6.5 (verify-execute-outputs + verify-defer-reasons
        │  + fix-iteration-loop). Continue cho đến khi decision != continue_loop.
        ├─ "ask_user_question" → execute Step 6.5c INLINE CDG E095 AskUserQuestion
        │  3 options (Force-fix / Accept / Spawn cross-scope). Update cdg-tokens.json
        │  + fix-iterations.json.cdg_token. Route theo user_choice:
        │  · "Force-fix" → +1 iteration ngoài budget (set MCV3_FIX_LOOP_MAX_ITER+1),
        │    GOTO Step 6.4 với EXPERT_OVERRIDE=true
        │  · "Accept" → continue Group F (advance to Phase 7)
        │  · "Spawn cross-scope" → Wave 3 G4 will handle, hiện tại continue Group F
        │    với note trong fix-blockers.md
        └─ "finalize_phase6" hoặc "finalize_phase6_legacy" → continue Group F
8. Đọc phase6-execute/F-report.md → execute Step 6.6 → Group F POST-GATE
9. Đọc phase6-execute/G-finalize.md → execute Step 6.7 → Group G POST-GATE
10. Đọc phase6-execute/POST-GATE.md → validate T1-T5 → advance Phase 7
```

**QUY TẮC LAZY-LOAD:**
- KHÔNG đọc trước tất cả group files — chỉ load khi tới group đó
- Mỗi group file có "Next Group" pointer ở cuối → orchestrator route theo
- DRY_RUN branching: orchestrator skip Groups C, D, E nếu Step 6.2 exit 5

**QUY TẮC LOOP SAFETY (v11):**
- **Max iterations**: 3 (env `MCV3_FIX_LOOP_MAX_ITER` override). EXPERT_OVERRIDE thêm +1 (tổng max 4).
- **No-progress guard**: nếu sau 1 iteration mà `fix-execution-result.json aggregated.fixed_total` KHÔNG tăng → force `decision=escalate_cdg` (tránh infinite spin trên items không fixable).
- **Disable hatch**: `MCV3_FIX_LOOP_DISABLE=true` → skip toàn bộ loop (behavior v10.x).
- **Re-entrant E-validate**: Step 6.5 idempotent — chạy lại không corrupt state. fix-iterations.json APPEND-only entries.

## Orchestrator Role Boundary

| Orchestrator **LÀM** | Orchestrator **KHÔNG LÀM** |
|----------------------|----------------------------|
| Đọc fix-plan + verify CDG tokens (qua `setup-execute.sh`) | Sửa code trực tiếp |
| Run CI impact analysis INLINE (6.3) | Viết fix-report.md (việc của execute agent) |
| Spawn `wf-fix-execute` INLINE Agent({...}) | Sửa docs/registry (việc của execute agent) |
| Validate POST-GATE T1-T5 (qua `verify-execute-outputs.sh`) | Ghi đè output execute agent |
| Update bug-dashboard (qua `verify-execute-outputs.sh`) | Commit/push code (CORE-027 SAFETY-FENCE) |
| Viết Phase6-report.md (qua `generate-phase6-report.sh`) | Bắt đầu Phase 7 khi POST-GATE chưa pass |

**Quy tắc:** Code modification nằm trong execute agent. Orchestrator là người điều phối + cổng kiểm soát.

## Agent Dispatch Safety (CORE-025)

| Aspect | Value |
|--------|-------|
| Agent | `wf-fix-execute` (subagent_type="claude", model="opus") |
| Concurrency | 1 (sequential — chỉ 1 execute agent) |
| Writer scope | `$SESSION_DIR/phase6-execute/fix-report.md`, `docs-sync-report.json` |
| Prompt template | [`_shared/15-agent-prompts.md` — Execute Agent (Phase 6)](_shared/15-agent-prompts.md#execute-agent-prompt-phase-6) (8 sections CORE-037) |
| CI context | Inject từ Phase 1 PRE-GATE Step Nc |
| Re-spawn on fail | Max 1 lần (E060), budget tổng 3 retries/phase (CORE-034) |

## Helper Scripts (v10.16.0)

| Script | Group | Lines |
|--------|-------|-------|
| `setup-execute.sh` | A (Step 6.1) | ~120 |
| `dry-run-preview.sh` | B (Step 6.2) | ~90 |
| `verify-execute-outputs.sh` | E (Step 6.5) | ~150 |
| `generate-phase6-report.sh` | F (Step 6.6) | ~80 |
| `phase-finalize.sh` (shared) | G (Step 6.7) | ~110 |

**Versioning:** v10.16.0 (2026-05-16) — Lazy-load split (619 dòng monolithic → 90-dòng index + 8 group files). Step 6.7 migrate từ `finalize-phase6.sh` (still exists for backward-compat) sang shared `phase-finalize.sh`.
