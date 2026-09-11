# Phase E — 4-Level Checkpoint + Concurrency Controller + Scan Cache

> **Mục tiêu:** Resilience + scale features theo ADR-LS11, LS12 (+ timeout v2.1), LS10.
> **Duration:** 3-4 ngày
> **Dependencies:** Phase D (sub-skills migrated, agents upgraded)
> **Tag:** `v5.0-phase-E`
> **Parallelizable:** With F, G (write scope separate)
> **Rollback:** Disable controller + checkpoint → fall back to phase-level (v4.1).

---

## Prerequisites

- [ ] Phase D tagged `v5.0-phase-D` (golden test passed)
- [ ] Branch `feat/wf-legacy-scan-v5.0-phase-e` created
- [ ] Write scope agreed with F, G teams nếu parallel

---

## Tasks Overview

| ID | Task | Priority | Duration | Status |
|----|------|----------|----------|--------|
| E.1 | 4-Level Checkpoint — L0 phase, L1 layer, L2 batch/module, L3 intra-batch | CRITICAL | 4-5 giờ | ✅ |
| E.2 | Checkpoint write throttle (5s min interval) | HIGH | 1-2 giờ | ✅ |
| E.3 | Concurrency Controller 3-tier token bucket | CRITICAL | 4-5 giờ | ✅ |
| E.4 | Per-agent timeout (300s/600s) với watchdog | HIGH | 3-4 giờ | ✅ |
| E.5 | Scan Cache content-addressable fingerprint | HIGH | 4-5 giờ | ✅ |
| E.6 | Scan Cache 2-tier (session + project opt-in) | HIGH | 3-4 giờ | ✅ |
| E.7 | Cache invalidation rules + `--no-cache` flag | MEDIUM | 2-3 giờ | ✅ |
| E.8 | Crash injection test (verify ≤1 unit lost) | CRITICAL | 3-4 giờ | ✅ (Tier 1 10/10 · Tier 2 E2E blocked by A.3) |

---

## Task E.1 — 4-Level Checkpoint

**Priority:** CRITICAL · **Duration:** 4-5 giờ

### Actions

Implement 4 levels theo [04 §1.1 + ADR-LS11](../../04-data-model.md):

- **L0 Phase:** scan-state.last_completed (transition mỗi phase boundary)
- **L1 Layer:** scan-state.layers.<L>.status (in_progress/completed)
- **L2 Batch/Module:** batch_progress / module_progress
- **L3 Intra-batch:** layers/L*/partial.json

Implement tại:
- Orchestrator SKILL.md (L0, L1 transitions)
- Sub-skill procedures (L2 batch/module update)
- Sub-skill core logic (L3 per file/feature)

### Acceptance Criteria

- [ ] All 4 levels persist to disk atomic
- [ ] Resume Router reads all 4 levels (Phase H sẽ implement router chi tiết)
- [ ] Kill -9 injection test: crash at arbitrary point → ≤ 1 unit lost

---

## Task E.2 — Write Throttle (5s)

**Duration:** 1-2 giờ

### Actions

Thêm throttle logic vào `scan_state_reader.py`:

```python
_LAST_WRITE_TIME: dict[str, float] = {}  # per session_id
_WRITE_THROTTLE_SEC = 5.0

def _atomic_write(session_id, state):
    now = time.time()
    last = _LAST_WRITE_TIME.get(session_id, 0)
    if now - last < _WRITE_THROTTLE_SEC:
        # Queue update (defer via async or next call triggers flush)
        _pending_updates[session_id] = state
        return
    # ... actual atomic write ...
    _LAST_WRITE_TIME[session_id] = now
```

### Acceptance Criteria

- [ ] Max 1 write per 5 seconds per session
- [ ] No write lost (pending updates flushed on next call or process exit)
- [ ] Unit test: 10 rapid calls → ≤ 3 writes

---

## Task E.3 — Concurrency Controller

**Priority:** CRITICAL · **Duration:** 4-5 giờ

### Actions

Implement token bucket trong `_shared/ips/concurrency_controller.py`:

```python
class ConcurrencyController:
    def __init__(self, global_max=8, per_layer_max=3, per_probe_max=4, reserved=2):
        self.global_tokens = global_max - reserved
        self.per_layer = {L: per_layer_max for L in ["L4", "L5"]}
        self.per_probe = {}
        self._lock = threading.Lock()
    
    def acquire(self, layer: str, probe_id: str, timeout_sec: float = 60) -> bool:
        """Acquire token for spawn. Returns False nếu timeout."""
    
    def release(self, layer: str, probe_id: str) -> None:
        """Release token after agent complete/fail."""
    
    def status(self) -> dict:
        """Current token usage for monitoring."""
```

### Acceptance Criteria

- [ ] Token bucket 3-tier works
- [ ] Global cap = 8, per_layer = 3, per_probe = 4
- [ ] Reserved 2 for synthesis
- [ ] Acquire timeout → False (no deadlock)
- [ ] Release idempotent
- [ ] Unit tests: parallel spawn respects caps

---

## Task E.4 — Per-Agent Timeout + Watchdog

**Duration:** 3-4 giờ

### Actions

Implement watchdog pattern:

```python
def spawn_with_timeout(agent_type, prompt, depth, timeout_sec=None):
    if timeout_sec is None:
        timeout_sec = 600 if depth == "deep" else 300
    
    start_time = time.time()
    agent_handle = spawn_agent(agent_type, prompt)
    
    # Watchdog check every 30s
    while not agent_handle.done():
        elapsed = time.time() - start_time
        if elapsed > timeout_sec:
            agent_handle.abort()
            log_warn(f"Agent {agent_type} timeout after {elapsed}s")
            return retry_simplified(agent_type, prompt, depth, attempt=2)
        time.sleep(30)
    
    return agent_handle.result()
```

### Acceptance Criteria

- [ ] Timeout 300s default, 600s deep/exhaustive L5
- [ ] Env var override works (`LEGACY_SCAN_AGENT_TIMEOUT_SEC`)
- [ ] Abort + retry simplified works (max 2 retries)
- [ ] After retries fail → skip module + WARN + continue

---

## Task E.5-E.7 — Scan Cache

**Duration:** 4-5 giờ + 3-4 giờ + 2-3 giờ

### Actions

Implement `_shared/ips/scan_cache.py`:

- Fingerprint: SHA256(probe_id || version || input_hash || dep_closure_hash || config_hash)
- 2-tier: session cache (ephemeral) + project cache (opt-in git)
- Invalidation rules: file hash change, probe version bump, TTL expire, `--no-cache`, `--invalidate-cache=pattern`
- Privacy scope check (no secrets cached)

### Acceptance Criteria

- [ ] Cache entry schema matches [04 §7.1](../../04-data-model.md)
- [ ] Session cache auto-created, gitignored
- [ ] Project cache opt-in via `--cache-publish`
- [ ] Invalidation rules work
- [ ] Privacy: secrets (password|token|api_key) never cached
- [ ] Re-scan with 20% changes: ≥ 50% cache hit (baseline target — tune Phase I)

---

## Task E.8 — Crash Injection Test

**Priority:** CRITICAL · **Duration:** 3-4 giờ

### Actions

Test crash at each checkpoint level:

```bash
# Test 1: Crash mid L4 batch 3/5
/wf-legacy-scan fixtures/medium-vn/ --profile=standard &
PID=$!
sleep 120  # mid-way through L4
kill -9 $PID

# Resume
/wf-legacy-scan fixtures/medium-vn/ --resume
# Verify: continues from batch 4 (not batch 3 or 1)

# Test 2: Crash mid L5 module 3/8
# Test 3: Crash mid L5 module 3 feature 5/12

# Verify session log shows resume from correct unit
```

### Acceptance Criteria

- [ ] L0 phase resume works
- [ ] L1 layer resume works  
- [ ] L2 batch/module resume works
- [ ] L3 intra-batch resume works
- [ ] **Mất ≤ 1 unit (1 file / 1 feature / 1 batch)** cho mỗi crash point

---

## Exit Criteria

- [ ] All 8 tasks ✅
- [ ] Crash injection test PASS
- [ ] Concurrency caps respected (parallel spawn test)
- [ ] Cache hit ≥ 50% (baseline, tune Phase I)
- [ ] `v5.0-phase-E` tag pushed

## Next Phase

→ [phase-F-impact-incremental.md](phase-F-impact-incremental.md)
