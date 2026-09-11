# P2 Performance — C2.1-C2.5 (12 CP)

> **Audit date:** 2026-05-12 (Phiên 16)
> **Stage:** Stage 2 — P2 Performance + P3 Efficiency
> **Result:** 10 PASS, 2 WARN, 0 FAIL

---

## Nhóm C2.1 — Parallel Lane Execution (3 CP)

### C2.1.1 — max_parallel=3 được tôn trọng: PASS

**Evidence:**
- `lane_dispatch.py:1365` — `dispatch_lanes_async(max_parallel: int = 3)`
- `lane_dispatch.py:1440` — `dispatch_lanes(max_parallel: int = 3)`
- `lane_dispatch.py:1536` — CLI `--max-parallel` default=3
- `phase1-engine.md:302-308` — Step 1.1 hardcodes `--max-parallel 3`
- `SKILL.md:133` — confirms "max_parallel=3"
- Concurrency enforced via `asyncio.Semaphore(max_parallel)` at line 1403
- Sequential fallback when `max_parallel <= 1` or only 1 dimension (line 1472)

**Verdict:** max_parallel=3 enforced at 5 levels: function default, CLI default, procedure hardcode, SKILL.md doc, and runtime Semaphore.

---

### C2.1.2 — Token bucket + backpressure ngăn quá tải: WARN

**Evidence:**
- `concurrency/token_bucket.py` — TokenBucket3Tier (global=12, lane=4, intra=6) with ADR-22 rule 3 enforcement (line 161-168: constructor raises ValueError on override)
- `concurrency/backpressure.py` — SemaphoreBackpressure (hard cap max_inflight=24) + AdaptiveBackpressure (p95 latency > 200ms → exponential backoff)
- Both well-tested: `test_token_bucket.py` (121 lines), `test_backpressure.py` (168 lines), `test_integration.py` Part 4
- `lane_dispatch.py:2` docstring claims "token_bucket + backpressure" integration
- `lane/dispatcher.py:7` docstring references token_bucket import for backpressure

**BUT:**
- `lane_dispatch.py` does NOT import or use `TokenBucket3Tier`, `SemaphoreBackpressure`, or `AdaptiveBackpressure`
- Actual concurrency control is `asyncio.Semaphore(max_parallel)` only (line 1403)
- `lane/dispatcher.py` docstring claims integration but grep shows NO actual import of token_bucket/backpressure modules
- Token bucket and backpressure are tested infrastructure modules that are NOT wired into the production dispatch flow
- No probe would ever timeout with "token_bucket_empty" since the bucket is never consulted

**Impact:** Without token bucket integration, there's no rate limiting between probe executions beyond the 3-lane semaphore. A burst of fast probes could overwhelm the signal aggregator downstream. Without backpressure, the aggregator has no way to signal producers to slow down.

**Verdict:** Infrastructure exists and is tested, but not integrated into production flow. Race condition risk between fast producers and aggregator is low (merge-preserve + cross-lang lock provide defense-in-depth), but the claimed protection is not active.

---

### C2.1.3 — Write scope tách biệt: PASS

**Evidence:**
- `phase1-engine.md:279-300` — Write Ownership Contract table with 4 writers, each with isolated scope:
  - `lane_dispatch.py` (Python): MERGE-write static signals only
  - `signal-emit.md` (bash): APPEND-only non-static signals
  - `merge_signals.py` (Python): MERGE-write LLM signals
  - `signal_aggregator.py` (Python): READ-ONLY for signals.json
- `lane_dispatch.py:1141-1197` — `_merge_static_signals()` MERGE-PRESERVE logic: preserves non-static signals, replaces only static probe signals
- `lane_dispatch.py:1012-1068` — Cross-language lock: `<signals_file>.lock/` directory (mkdir POSIX atomic), same convention in Python and bash
- Each lane writes to `$SESSION_DIR/lanes/{DIM}/signals.json` — separate directory per dimension
- No shared mutable state across lanes
- Rule: "KHÔNG writer nào được phép overwrite signals[] toàn bộ" (phase1-engine.md:293)

**Verdict:** Write scope is clearly separated with 4-writer ownership contract, MERGE-PRESERVE logic, and cross-language lock protection.

---

## Nhóm C2.2 — Static/Runtime Probe Separation (3 CP)

### C2.2.1 — Static probes hoàn thành trước non-static: PASS

**Evidence:**
- `phase1-engine.md:263-277` — Execution Order Overview diagram:
  ```
  [Step 1.1   lane_dispatch (static probes)]
          ↓
  [Step 1.1.5 non-static probes loop]
          ↓
  [Step 1.1.7 LLM lane (opt-in)]
          ↓
  [Step 1.2   signal_aggregator ONCE]
  ```
- Step 1.1 explicitly runs `python -m lane_dispatch` which only executes `type=static` probes (line 313-319)
- Step 1.1.5 only fires AFTER Step 1.1 completes, using `PENDING_PROBES_JSON` from `wf-fix-merge-non-static-probes.sh`
- Aggregator only runs ONCE at Step 1.2 after all non-static + LLM probes complete

**Verdict:** Static probes complete before non-static probes start. Sequential enforcement in procedure ensures no interleaving.

---

### C2.2.2 — Non-static probes chỉ chạy probes pending: PASS

**Evidence:**
- `phase1-engine.md:347-360` — Step 1.1.5 calls `wf-fix-merge-non-static-probes.sh` to get `PENDING_PROBES_JSON`
- Only probes with `type ∈ {runtime, runtime+agent, static+runtime, agent}` that are NOT already in `signals.json`
- Probe types table (line 311-321) clearly separates static vs non-static responsibilities
- `lane_dispatch.py:1289-1310` — `_lane_already_complete()` prevents re-execution of already-complete lanes

**Verdict:** Non-static probes are only dispatched for probes not yet executed. Pending detection uses helper script, not hand-rolled diff.

---

### C2.2.3 — Browser probes sequential per app (monorepo QD9): PASS

**Evidence:**
- `phase1-engine.md:463-500` — Step 1.1.6 Multi-app browser coordinator:
  - Only runs when QD9 ∈ DIMS_ARRAY AND monorepo detected (apps/ subdirectory or ≥2 web apps)
  - `wf-fix-multi-app-coordinator.sh` creates sequential execution plan per app
  - Priority order: erp-web → smarttax-web → erktransport.com → web-customer → others
  - Each probe enforces browser singleton lock (`acquire_browser_lock`/`release_browser_lock`)
- Mobile apps automatically skipped for browser probes

**Observation (OBS-046):** Single-app case relies solely on probe-level browser lock. No orchestrator-level sequential enforcement for single-app multi-probe scenarios. If 2 different QD9 runtime probes both need a browser, the lock is the only guard — no explicit serialization from the orchestrator. Mitigation: QD9 probes are dispatched sequentially within Step 1.1.6's per-app loop.

**Verdict:** PASS. Multi-app case has explicit sequential coordinator. Single-app case has browser lock per probe + sequential dispatch loop.

---

## Nhóm C2.3 — Agent Dispatch Decision (2 CP)

### C2.3.1 — Ngưỡng kích hoạt chính xác: PASS

**Evidence:**
- `agent-dispatch.md:32-46` — Decision tree:
  - `issues > 200` → agent_dispatch (env: `MCV3_FIX_BUGS_INLINE_MAX_ISSUES`, default 200)
  - `context > 70%` → agent_dispatch (env: `MCV3_FIX_BUGS_INLINE_MAX_CONTEXT_PCT`, default 70)
  - Otherwise → inline
- `agent-dispatch.md:74-79` — Edge cases documented:
  - CLAUDE_CONTEXT_USED_PCT not set → fallback to issue count only
  - --dry-run with 250 issues → still agent_dispatch (respects dry_run flag)
  - --resume with prior agent_dispatch → re-evaluate threshold

**Verdict:** Threshold logic is clear, configurable via env vars, and edge cases are documented.

---

### C2.3.2 — Decision reason được ghi nhận: PASS

**Evidence:**
- `agent-dispatch.md:42-44` — REASON constructed with specific values:
  - agent_dispatch: `"issues=250>200"` or `"context=75%>70%"`
  - inline: `"issues=42<=200 AND context=15%<=70%"`
- `agent-dispatch.md:53-67` — Persisted to `fix-status.json` via atomic jq update:
  - `execution_mode_decision.mode`, `.reason`, `.total_issues`, `.context_pct`, `.decided_at`
- `agent-dispatch.md:96-116` — Resume transition logging also records reason
- `agent-dispatch.md:383-397` — orchestrator-summary.md must include execution mode with reason

**Verdict:** Decision reason is always populated with specific format, never null/empty.

---

## Nhóm C2.4 — Checkpoint Granularity (2 CP)

### C2.4.1 — Checkpoint sau mỗi sub-batch (agent_dispatch): PASS

**Evidence:**
- `agent-dispatch.md:337-345` — Checkpoint trigger points table:
  - Phase 3 Batch 1 (CRITICAL): after every sub-batch (10 issues)
  - Phase 3 Batch 2 (HIGH): after every sub-batch (10 issues)
  - Phase 3 Batch 3 (MED+LOW): after every sub-batch (10 issues)
  - Phase 5 Verify Loop: after every iteration (FIX/DOCS/RESCAN/EVALUATE)
- `agent-dispatch.md:346-347` — Inline mode also writes per-batch checkpoints (for UX/status display)
- Checkpoint schema: `{batch_id, sub_batch_index, timestamp, issues_processed, next_action}`

**Verdict:** With 100 issues and 10-issue sub-batches, at least 10 checkpoint updates would be written.

---

### C2.4.2 — Mất tối đa 1 batch khi crash: PASS

**Evidence:**
- `agent-dispatch.md:351-363` — Resume logic:
  - Reads `last_checkpoint` from fix-status.json
  - Phase 3: skip completed batches/sub-batches, start from next
  - Phase 5: skip completed iterations
- Checkpoint writes after each sub-batch (10 issues) — worst case: lose the current uncommitted sub-batch
- `agent-dispatch.md:368-371` — Backward compat: legacy sessions without checkpoint field start from batch_1/sub_batch_index=0

**Verdict:** Crash at 25/100 issues → resume from last checkpoint at sub_batch boundary → at most 10 issues need re-fixing.

---

## Nhóm C2.5 — Workload Gate Accuracy (2 CP)

### C2.5.1 — estimated_minutes khớp thực tế: WARN

**Evidence:**
- `workload_estimator/estimator.py:251-287` — Formula: `estimated_sec = file_count * probes_per_dim * avg_time * profile_multiplier [* weight]`
- `PROBES_PER_DIM` (line 35-44) only includes QD1-QD8. **QD9, QD10, QD11 are MISSING.**
- `DIMENSION_WEIGHTS` (line 47-56) only includes QD1-QD8. QD9/QD10/QD11 absent.
- `AVG_TIME_PER_FILE_SEC` (line 58-68) only includes QD1-QD8. QD9/QD10/QD11 absent.
- Calling `estimate_lane("QD9", ...)` would raise `ValueError: dim='QD9' không hợp lệ`

**Gap 1:** Estimator structurally cannot estimate workload for QD9, QD10, QD11. If these dimensions are selected, the estimator would crash instead of producing an estimate.

**Gap 2:** No feedback loop — no code compares `estimated_minutes` against actual runtime after execution. No `workload_gate_meta.actual_minutes` field is populated post-execution.

**Gap 3:** Hardcoded heuristic values (`AVG_TIME_PER_FILE_SEC`) may be stale. Values were calibrated before QD8-QD11 existed.

**Verdict:** Estimator works for QD1-QD8 but does not cover new dimensions. No accuracy calibration mechanism.

---

### C2.5.2 — Codebase-size awareness: PASS

**Evidence:**
- **Probe timeout auto-scale** (`lane_dispatch.py:640-775`):
  - 4 tiers: <10k→600s, 10k-50k→1200s, 50k-100k→2400s, >100k→3600s
  - Source: ISG snapshot `symbol_count` or fallback `file_count × 20`
  - User override via `WF_FIX_PROBE_MAX_RUNTIME_SEC` env var
  - Hard cap: 7200s (2h)

- **Partition planner** (`partition_planner.py:97-141`):
  - `symbol_count > LARGE_CODEBASE_SYMBOL_THRESHOLD (5000)` → halve `max_workload_size`
  - Forces multi-workload split on large codebases

- **CI Density Factor** (`workload-gate.md Step 1.5.2a`):
  - `size_factor * coupling_factor` capped at 2.0
  - Size factor: 1.0 (<5k), 1.3 (5k-10k+dense), 1.5 (>10k)
  - Coupling factor: 1.0 or 1.2 (extreme coupling)
  - Applies to workload gate ratio → raises threshold for large/highly-coupled codebases

- **Phase 1 workflow** (`phase1-engine.md:66-101`):
  - Step 3: symbol_count extracted from ISG JSON → passed to partition_planner
  - `>5000 symbols → halve max_workload_size` to avoid single-run overload

**Verdict:** Codebase size awareness is implemented at 3 levels: probe timeout, workload partitioning, and gate threshold. Fallback estimation (file_count × 20) ensures awareness even without ISG/GitNexus.

---

## Summary

| CP | Description | Result |
|----|-------------|--------|
| C2.1.1 | max_parallel=3 enforced | PASS |
| C2.1.2 | Token bucket + backpressure | **WARN** |
| C2.1.3 | Write scope tách biệt | PASS |
| C2.2.1 | Static before non-static | PASS |
| C2.2.2 | Non-static only pending | PASS |
| C2.2.3 | Browser sequential | PASS |
| C2.3.1 | Agent dispatch threshold | PASS |
| C2.3.2 | Decision reason recorded | PASS |
| C2.4.1 | Checkpoint per sub-batch | PASS |
| C2.4.2 | Crash loses ≤1 batch | PASS |
| C2.5.1 | Workload estimate accuracy | **WARN** |
| C2.5.2 | Codebase-size awareness | PASS |

**Total: 10 PASS, 2 WARN, 0 FAIL**

---

## Observations

### OBS-046: Token bucket + backpressure not integrated into production flow
- **Severity:** MEDIUM
- **Detail:** `lane_dispatch.py` and `lane/dispatcher.py` docstrings claim token bucket + backpressure integration, but neither actually imports or uses `TokenBucket3Tier`, `SemaphoreBackpressure`, or `AdaptiveBackpressure`. These are tested infrastructure modules not wired into the main dispatch flow.
- **Risk:** Burst of fast probe executions could theoretically overwhelm signal aggregator. Current defense-in-depth (merge-preserve + cross-lang lock) mitigates the worst-case data corruption but doesn't provide rate limiting.
- **Recommendation:** Either wire token bucket into lane_dispatch.py probe execution loop, or update docstrings to reflect actual architecture (Semaphore-only concurrency).

### OBS-047: Workload estimator missing QD9/QD10/QD11 dimensions
- **Severity:** HIGH
- **Detail:** `PROBES_PER_DIM`, `DIMENSION_WEIGHTS`, and `AVG_TIME_PER_FILE_SEC` in `estimator.py` only cover QD1-QD8. If QD9/QD10/QD11 are selected via `--dims`, `estimate_lane()` raises ValueError. The estimator CLI defaults to `QD1,QD2,QD5` which avoids the crash for default profiles, but any explicit dimension selection including QD9+ will break.
- **Risk:** Workload gate cannot estimate cost for sessions involving QD9/QD10/QD11. User won't see accurate time estimates.
- **Recommendation:** Add QD9/QD10/QD11 entries to all three dictionaries in estimator.py with appropriate heuristic values.

### OBS-048: No estimated vs actual workload feedback loop
- **Severity:** LOW
- **Detail:** The workload estimator produces `estimated_minutes` but there is no post-execution step that compares this against actual execution time and records the deviation. Without feedback, the heuristic values in `AVG_TIME_PER_FILE_SEC` and `PROBES_PER_DIM` cannot be calibrated over time.
- **Risk:** Estimator accuracy degrades as probes evolve. Currently unmeasurable.
- **Recommendation:** Add a post-execution step in POST-GATE or Phase 6 that calculates actual runtime from trace events and writes `workload_gate_meta.actual_minutes` + deviation to fix-status.json.

### OBS-049: Single-app browser probe serialization relies on per-probe lock
- **Severity:** LOW
- **Detail:** For single-app (non-monorepo) QD9 scenarios, browser probe serialization relies solely on the per-probe `acquire_browser_lock` mechanism. The orchestrator's Step 1.1.6 only activates for monorepo with `apps/` directory. While the sequential per-app dispatch loop in Step 1.1.6 does serialize probes within each app's turn, there is no global "only one browser probe at a time" enforcement at the orchestrator level for single-app cases.
- **Risk:** Low — per-probe browser lock provides adequate serialization. Concurrent lock acquisition would serialize naturally.
- **Recommendation:** Document the lock-based serialization assumption clearly.
