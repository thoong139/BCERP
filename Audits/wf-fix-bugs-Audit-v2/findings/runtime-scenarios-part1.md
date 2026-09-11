# Runtime Scenarios Part 1 — C.1 đến C.6

> **Task:** 4.1 — Analyze runtime scenarios C1-C6: classify each as "needs actual runtime" vs "can verify statically".
> **Date:** 2026-05-12 (Phiên 21)
> **Classification result:** ALL 6 scenarios CAN BE VERIFIED STATICALLY.

---

## Classification Summary

| Scenario | Description | Classification | Rationale |
|----------|-------------|----------------|-----------|
| C.1 | N=0 issues path (E005) | STATIC-VERIFIABLE | Full procedure traceable in phase1-engine.md + post-gate-completion.md |
| C.2 | Workload Gate Block | STATIC-VERIFIABLE | Full gate logic in workload-gate.md with all 6 options documented |
| C.3 | CQG-2 BLOCKED | STATIC-VERIFIABLE | Full gate logic in post-gate-completion.md step 2.5 |
| C.4 | Resume After Interruption | STATIC-VERIFIABLE | Full routing table in resume-routing.md |
| C.5 | Concurrent Lock | STATIC-VERIFIABLE | Lock mechanism fully documented in lock-management.md + session-dir.md |
| C.6 | Graceful Degradation | STATIC-VERIFIABLE | All fallback paths documented in procedures + ci-pre-gate.md |

**No scenario requires actual runtime execution.** Every scenario's logic, state transitions, error handling, and edge cases are fully described in procedure files and can be traced statically.

---

## C.1 — N=0 Issues Path (E005 Healthy Gate)

### Verification Method: Static trace of phase1-engine.md + post-gate-completion.md

### Trace

**Phase 1 Engine E005 Section** (`phase1-engine.md:704-729`):

```
Entry condition: total_issues == 0 AND NOT --dry-run

Step 1: Check probe_failures_count
  IF probe_failures_count > 0 AND ACCEPT_BROKEN != "1":
    → CDG-PROBE-FAILURE (Protocol 16)
    → status="paused", next_action="resume_with_decision"
    → STOP (block false-positive "healthy")
  ELSE:
    → status="completed", next_action="done"
    → phases 2-6 status="skipped"
    → SKIP Step 1.5 (workload gate), Step 2.5 (CDG handoff), Buoc 2, Buoc 3
    → goto POST-GATE
```

**POST-GATE Step 0 Early-Exit Guard** (`post-gate-completion.md:9-17`):

```
Guard condition: status == "completed" AND phases 2-6 status == "skipped"

  → SKIP steps 1-3 (TodoWrite/fix-status double-write/orchestrator-summary 
    phụ thuộc fix-report.md không tồn tại)
  → ONLY run step 4 (fix-impact.json with fix_summary.fixed=0)
  → step 5 (Completion Display) + step 6 (Trace COMPLETE)
```

### Assessment: PASS

**Strengths:**
- Two-layer defense: E005 blocks false-positive healthy (probe_failures_count > 0), then POST-GATE handles N=0 path gracefully
- CDG-PROBE-FAILURE with 3 user options (re-run, skip dim, accept-broken)
- Builds fix-impact.json correctly with fixed=0
- Clears all downstream phases (2-6 marked "skipped")

**Gap identified:**
- **OBS-C1-1: T5.5 conflict potential.** POST-GATE T5.5 (`phase1-engine.md:670-682`) checks if any selected dim has `probes_executed == 0` → blocks with CDG-DIM-ZERO-PROBES. On a truly healthy codebase (N=0), all dims would have signals.json with `signals: []` but T5.5 checks `lane-status.json.probes_executed` which should be > 0 for dims that ran. If probes ran and found nothing, this is fine. But if a dim was truly empty (no source files matching its scope), probes_executed could be 0 incorrectly triggering a block on an otherwise healthy codebase. **This is a design concern, not a bug** — the T5.5 check is on the POST-GATE path that only runs when `total_issues > 0`, so it wouldn't conflict with E005 which routes directly to POST-GATE WORKFLOW step 0 (bypassing T5.5). Verified: E005 routes to "POST-GATE workflow" at the orchestrator level, which starts at step 0 (EARLY-EXIT GUARD) rather than the normal POST-GATE sequence.

---

## C.2 — Workload Gate Block (ratio > 1.5)

### Verification Method: Static trace of workload-gate.md

### Trace

**Workload Gate Logic** (`workload-gate.md:15-26`):

```
Step 1.5.1: Read fix-workload.json
Step 1.5.2: Calculate ratio = total_estimated_sec / gate_threshold_sec
Step 1.5.2a: CI Density Factor (when GitNexus available)
  - size_factor: 1.0 (≤5000 symbols) / 1.3 (5000-10000 + density>3) / 1.5 (>10000)
  - coupling_factor: 1.2 (density > 5.0) / 1.0 (else)
  - CI_DENSITY_FACTOR = size_factor * coupling_factor (capped 2.0)
  - adjusted_ratio = ratio * CI_DENSITY_FACTOR
Step 1.5.3: Classify → dead_zone (<0.8), warn (0.8-1.5), block (>1.5)

BLOCK path (Step 1.5.6):
  6 options:
    1. Thu hẹp scope → abort, suggest re-run
    2. Hạ profile → re-run Phase 1 with lower profile
    3. Giảm dim list → re-run with --skip
    4. Override CDG-11 → workload_override=true, auto-add CDG-11
    5. Partition theo kế hoạch → pick partition plan, re-run subset
    0. Hủy → E024

Resume handling:
  - "aborted" → re-render Plan A/B menu
  - "override" → skip menu, goto Buoc 2 (CDG-11 already added)
  - "passed" → goto Buoc 2
```

### Assessment: PASS

**Strengths:**
- 3-tier classification (dead_zone/warn/block) with clear ratio thresholds
- CI Density Factor adjusts for codebase complexity (size + coupling) with safety cap at 2.0
- 6 options in block prompt cover all user intents
- CDG-11 defense-in-depth: override re-confirmed at Step 2.5
- Resume correctly handles all workload_gate states (aborted/override/passed)

**Gaps identified:**
- **OBS-C2-1: CI Density Factor only when GitNexus available.** If GitNexus is absent (common for new projects), the density factor is skipped entirely. A fallback heuristic based on file count or directory size could serve as a proxy. Current behavior is still correct (zero regression) but may under-estimate workload on large codebases without GitNexus.
- **OBS-C2-2: ratio calculation depends on workload estimator accuracy.** The estimator was found to be missing QD9/QD10/QD11 in PROBES_PER_DIM (finding C2.5.1 from Stage 2). This means the ratio may be underestimated, causing a block scenario to appear as warn or dead_zone. The gate itself is correct — the input data may be incomplete.

---

## C.3 — CQG-2 BLOCKED (Browser + Integration Gate)

### Verification Method: Static trace of post-gate-completion.md step 2.5

### Trace

**CQG-2 Gate Logic** (`post-gate-completion.md:47-174`):

```
Step 2.5 — CQG-2: Browser + Integration Gate (HARD-ENFORCE, v9.0.3 W3.4)

Pre-checks:
  1. QD9 selected but signals.json missing → BLOCK (probe failure)
  2. QD10 selected but signals.json missing → BLOCK (probe failure)

Check 1: QD9 signals.json
  - Count signals with signal_type ∈ {runtime_console_error, runtime_uncaught_exception}
  - If count > 0 → BLOCK

Check 2: QD10 signals.json
  - Count signals with severity ∈ {HIGH, CRITICAL}
  - If count > 0 → BLOCK

If BLOCKED:
  - Render blocking signals list
  - Anti-loop guard: cqg2_reject_cycle >= 2 → E001 (force fail)
  - Interactive: AskUserQuestion CDG (Protocol 16)
  - Headless default: reject (P1 Correctness)

On REJECT:
  - Create cqg2-regression-entries.json (QD9 errors + QD10 HIGH/CRITICAL)
  - Increment cqg2_reject_cycle
  - Set next_action = "phase3_regression_fix"
  - Set phase_6 status = "blocked_cqg2"
  - Exit 2 (E002)

On ACCEPT:
  - Write cdg-tokens.json with cqg2_override entry
  - Proceed POST-GATE
```

### Assessment: PASS

**Strengths:**
- Dual pre-check handles probe failure (missing signals.json) separately from content-based blocking
- Specific signal_type filtering (runtime_console_error, runtime_uncaught_exception) avoids false positives from other QD9 signals
- Anti-loop guard (max 2 reject cycles) prevents infinite rejection loops
- Headless default is REJECT — correct for P1 Correctness (shouldn't auto-accept console errors)
- Regression entries properly structured with issue_id, source, dimension, signal_type
- Resume path correctly routes "phase3_regression_fix" to Buoc 3 with cqg2-regression-entries.json

**Gaps identified:**
- **OBS-C3-1: QD10 pre-check uses signals.json existence, but the content check uses severity HIGH/CRITICAL.** If QD10 signals.json exists but is empty (signals: []), the pre-check passes and the content check returns 0 — gate passes. But if QD10 probes failed silently (signals.json exists with empty array from template init), the gate would not catch this. The T5/T5.5 checks at POST-GATE should catch probe failures, but T5.5 specifically checks probes_executed in lane-status.json. If lane-status.json shows probes_executed > 0 with 0 signals found, this is legitimate (no issues found). **No bug — defense-in-depth via T5/T5.5.**

---

## C.4 — Resume After Interruption

### Verification Method: Static trace of resume-routing.md + session-dir.md §5

### Trace

**Resume Flow** (`resume-routing.md:27-101`):

```
Step 1: Resolve SESSION_DIR via _index/sessions.jsonl
  - Case A: --session=<id> explicit
  - Case B: auto-pick latest in_progress matching scope+name
  - Case C: legacy run-NNN--YYYYMMDD/ → fallback (display only)

Step 2: Validate fix-status.json exists → E011 if missing

Step 3: Lock-aware acquire (BẮT BUỘC)
  - acquire_lock → fresh lock held → STOP (E_RESUME_LOCK_HELD)
  - acquire_lock → stale → WARN + takeover

Step 4: Route by fix-status.status:

  STATUS == "in_progress":
    next_action mapping:
      "workload_gate"           → Step 1.5
      "cdg_pending"             → Step 2.5
      "phase_2_triage"          → Buoc 2
      "safety_check_pending"    → Step 2.6
      "phase_3_execute"         → Buoc 3
      "phase3_regression_fix"   → Buoc 3 (with cqg2-regression-entries.json)
      null                      → E_RESUME_CORRUPT → STOP

    ANTI-LOOP: cdg_reject_counts[cdg_id] >= 2 → force ESCALATE

  STATUS == "paused":
    next_action mapping:
      "workload_gate"           → re-render Plan A/B menu
      "cdg_pending"             → re-prompt CDG
      "safety_check_pending"    → re-render Safety Check CDG
      "phase_2_triage"          → re-prompt re-plan after E025
      "phase_3_execute"         → re-prompt continue Buoc 3

  STATUS == "completed":
    → Show completion message
    → Cross-skill suggest if fix-impact.json exists

  STATUS other → STOP with recovery message
```

### Assessment: PASS

**Strengths:**
- 3-status routing covers all possible session states
- All 6 next_action values mapped to correct steps
- Lock-aware resume prevents concurrent modification
- Stale lock takeover with cross-host warning
- Anti-loop guard prevents infinite CDG reject cycles
- Cross-skill suggest (S9 wired) for completed sessions
- Clear error codes for all failure modes (E011, E024, E025, E_RESUME_CORRUPT, E_RESUME_LOCK_HELD)
- Backward-compat: legacy v6.x paths detected with migration guidance

**Gaps identified:**
- **OBS-C4-1: cdg_pending routing in "paused" state re-prompts ALL CDGs.** The procedure says "re-prompt CDG chưa có token" but doesn't specify how to determine which CDGs have tokens vs which don't. The cdg-tokens.json file should be consulted to filter already-decided CDGs. This is implicitly handled but could be more explicit.
- **OBS-C4-2: Cross-resume mode switching.** From Stage 1 findings (C1.6.5), resume re-evaluates the agent dispatch threshold. The procedure at `agent-dispatch.md §1.5` handles this. Not a gap in resume-routing.md itself, but a dependency on correct threshold re-evaluation.

---

## C.5 — Concurrent Lock (POSIX Atomic + Heartbeat)

### Verification Method: Static trace of lock-management.md + session-dir.md §2

### Trace

**Lock Acquire** (`lock-management.md:30-42`):

```
1. mkdir <session_dir>/.lock.acquiring   ← POSIX atomic guard
   └─ fail → wait 1s → retry 1 lần → still fail → ERROR exit 1
2. Exclusive write right in critical section
3. Check .lock:
   ├─ exists + age < 60min → ERROR (active lock)
   ├─ exists + age >= 60min → WARNING + takeover
   └─ not exists → fresh acquire
4. atomic_write_json .lock <metadata>
5. rmdir .lock.acquiring
```

**Heartbeat** (`lock-management.md:53-71`):
- Daemon loop: while .lock exists → heartbeat_lock (update ISO timestamp) → sleep 30s
- PID stored in .heartbeat.pid
- Auto-exit when .lock removed
- Prevents false stale detection on long-running phases (>60 min)

**Release** (`lock-management.md:77-88`):
- release_lock: rm .lock (idempotent)
- Trap EXIT/INT/TERM → release
- Crash (kill -9) → trap doesn't run → .lock remains → stale after 60min → takeover on resume

**Cross-language lock** (`lock-management.md:141-174`):
- Signals lock: `<signals_file>.lock/` directory (mkdir POSIX atomic)
- Bash: acquire_signals_lock / release_signals_lock
- Python: _signals_lock_acquire / _signals_lock_release
- Same path → mutual exclusion cross-language
- Timeout: 30s, Stale: 5min (short-lived, no heartbeat needed)

**Concurrent Session Creation** (`session-dir.md:40-93`):
- F21 fix: combined gen+mkdir+lock+retry loop
- Max 5 attempts, sleep 50ms between retries
- Race scenario: 2 processes both gen SID-01 → A acquires lock → B fails → retry → gen SID-02

### Assessment: PASS

**Strengths:**
- POSIX mkdir guard ensures atomic single-winner (no race window like file-based check-then-write)
- Heartbeat daemon prevents false stale detection on long-running phases
- Stale takeover with cross-host warning (WARN but not block)
- Cross-language lock (Python ↔ Bash) uses same directory-based mechanism
- F21 retry loop handles concurrent session creation race
- Trap cleanup ensures lock release on normal exit
- Kill -9 safe: stale lock remains but takeover works after 60min
- Configurable thresholds via env vars (MCV3_LOCK_STALE_MINUTES, MCV3_HEARTBEAT_INTERVAL_SEC)

**Gaps identified:**
- **OBS-C5-1: Signals lock fallback is best-effort.** From `lock-management.md:157`: "Lock failure (timeout) → log WARNING, fallback non-locked write (best-effort, A1 merge defense vẫn preserve non-static)." If signals lock fails, the write proceeds without lock. The A1 merge defense (read-modify-write in critical section) still preserves non-static signals, but there's a theoretical race window. **This is a conscious design choice (availability over strict consistency for signals)**, not a bug.
- **OBS-C5-2: Heartbeat daemon reliability.** If the heartbeat daemon crashes silently (kill -9 to the daemon process but not the main process), the lock mtime would stop updating and the session could be falsely detected as stale after 60 minutes. The main process has no health check on the heartbeat daemon. This is unlikely but theoretically possible.

---

## C.6 — Graceful Degradation (Missing Tools)

### Verification Method: Static trace of ci-pre-gate.md + phase1-engine.md + SKILL.md

### Trace

**GitNexus Absent** (`ci-pre-gate.md:118`):
```
ci-detect.sh fail → WARNING → continue without CI
Fallback: Grep/Glob for all symbol search and impact analysis
```

**Serena Absent** (`ci-pre-gate.md:118` — same mechanism):
```
ci-detect.sh → no Serena MCP → WARNING → continue
Fallback: Grep for find_definition, find_references
```

**Playwright Absent (QD9)** (from `phase1-engine.md` + SKILL.md):
```
QD9 probes check Playwright MCP availability
→ skip with skip_reason: "playwright_unavailable"
→ lane-status.json records skip
→ orchestrator-summary.md shows QD9 skipped info
Note: No auto-detection at PRE-GATE — relies on flags/profiles
  (--no-browser flag, profile-based dim selection)
  This was flagged as WARN C1.8.1 in Stage 1 findings.
```

**Registry Absent** (from C1.8.4 Stage 1 findings):
```
Forensic PRE-GATE checks req-registry.json existence + content
→ Absent → STOP with clear message
→ Does NOT continue with empty registry (prevents false positives)
```

**Source Directory Absent** (from C1.8.5 Stage 1 findings):
```
--scope specifies non-existent directory
→ STOP early with clear message
→ Does NOT run and emit empty signals silently
```

**Non-git project** (`ci-pre-gate.md:121`):
```
ci-detect.sh exit 1 → skip all CI steps
→ Grep/Glob fallback for all analysis
```

### Assessment: PASS

**Strengths:**
- CI tools (GitNexus/Serena): zero-regression fallback to Grep/Glob
- Registry: hard STOP (correct — no data to analyze = no meaningful results)
- Source dir: hard STOP (correct — no code to scan)
- Non-git project: graceful skip of CI, continue with Grep
- All fallback paths documented with clear messages

**Gaps identified (from prior findings):**
- **C1.8.1 WARN (Stage 1):** Playwright has no auto-detection at PRE-GATE. Unlike GitNexus/Serena which use ci-detect.sh, Playwright availability is only determined at probe execution time. No MCP availability check exists at PRE-GATE to proactively skip QD9.
- **OBS-C6-1: Graceful degradation messages could be more actionable.** The current messages (e.g., "WARNING: GitNexus not available, falling back to Grep") are technically correct but don't tell the user what they're missing. A brief impact summary (e.g., "Impact analysis limited to file-level; cross-file blast radius not computed") would improve user understanding.

---

## Overall Assessment

| Scenario | Static Verification | Result | Notes |
|----------|---------------------|--------|-------|
| C.1 — N=0 issues path | FULL | PASS | Two-layer defense: E005 + POST-GATE step 0 |
| C.2 — Workload Gate Block | FULL | PASS | 6 options, CDG-11 defense-in-depth, CI Density Factor |
| C.3 — CQG-2 BLOCKED | FULL | PASS | Anti-loop, headless reject default, regression entries |
| C.4 — Resume After Interruption | FULL | PASS | 3-status routing, lock-aware, anti-loop guard |
| C.5 — Concurrent Lock | FULL | PASS | POSIX mkdir, heartbeat, cross-language, F21 retry |
| C.6 — Graceful Degradation | FULL | PASS | CI→Grep fallback, hard STOP for registry/source, QD9 skip |

**All 6 scenarios verified statically.** 0 NEEDS_RT. 6/6 PASS.

**Observations:** 8 (OBS-C1-1, OBS-C2-1, OBS-C2-2, OBS-C3-1, OBS-C4-1, OBS-C4-2, OBS-C5-1, OBS-C5-2, OBS-C6-1)

**Recommendation:** Proceed to Task 4.2 (C.7-C.12 analysis) without waiting for runtime environment setup. C.1-C.6 are fully verifiable from procedure documentation.
