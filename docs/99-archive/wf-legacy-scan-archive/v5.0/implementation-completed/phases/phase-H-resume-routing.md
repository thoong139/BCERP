# Phase H — 4-Level Resume Router

> **Mục tiêu:** Implement Resume Router đọc scan-state.json và route đến đúng resumption point (4 levels).
> **Duration:** 1 ngày (v2.1 reduced — bỏ reverse-sync logic)
> **Dependencies:** Phase E (4-level checkpoint operational)
> **Tag:** `v5.0-phase-H`
> **Rollback:** Fall back to ledger.json v4.1 resume (phase-level).
> **Status:** ✅ COMPLETED 2026-04-22 (branch: `feat/wf-legacy-scan-v5.0-phase-h`)

---

## Prerequisites

- [x] Phase E tagged `v5.0-phase-E` (tech-complete — tag pending A.3)
- [x] 4-level checkpoint written correctly (10/10 crash injection tests pass)
- [x] Branch `feat/wf-legacy-scan-v5.0-phase-h`

---

## Tasks Overview

| ID | Task | Priority | Duration | Status |
|----|------|----------|----------|--------|
| H.1 | Resume Router logic trong SKILL.md | CRITICAL | 3-4 giờ | ✅ |
| H.2 | `--session=ID` flag cho specific session resume | MEDIUM | 1 giờ | ✅ |
| H.3 | `--status` update đọc scan-state.json | MEDIUM | 1 giờ | ✅ |
| H.4 | Resume test — 4 levels × 3 fixtures (Tier 1) | CRITICAL | 3-4 giờ | ✅ Tier 1 (Tier 2 E2E BLOCKED by A.3) |

---

## Task H.1 — Resume Router

**Duration:** 3-4 giờ

Implement routing logic theo [03 §2.2](../../03-architecture.md):

```python
# Pseudo-code (actual trong procedure file)
def resume_router():
    # 1. Find latest active session
    session_dir = find_latest_active_session()
    if not session_dir:
        return "no_resumable_session"
    
    # 2. Load scan-state
    state = json.loads((session_dir / "scan-state.json").read_text())
    
    # 3. Acquire lock (should be free after crash)
    acquire_lock(force_if_stale=True)
    
    # 4. Route per last_completed + layer status
    last = state["last_completed"]
    
    if last == "init":
        return "start_L1"
    elif last == "L1":
        return "start_L2_rerun_ips_a"
    elif last == "L2":
        return "start_L3"
    elif last == "L3":
        return "start_L4_rerun_ips_b_if_missing"
    elif last == "L4":
        l4_status = state["layers"]["L4"]["status"]
        if l4_status == "in_progress":
            bp = state["layers"]["L4"]["batch_progress"]
            if bp and "partial" in state["layers"]["L4"]:
                return f"resume_L4_batch_{bp['current']}_file_{bp.get('partial_file')}"
            return f"resume_L4_batch_{bp['current']}"
        elif l4_status == "completed":
            return "start_L5"
    elif last == "L5":
        # Similar pattern
        ...
    elif last == "L6":
        return "resume_L6_regenerate"
    elif last == "completed":
        return "session_already_completed"
```

### Acceptance Criteria

- [ ] Router reads all 4 checkpoint levels
- [ ] Returns correct resumption point per state
- [ ] Handles completed session (suggest --status)
- [ ] Handles no active session (suggest fresh start)
- [ ] Fall back to ledger.json v4.1 nếu scan-state.json missing

---

## Task H.2 — `--session=ID` Flag

**Duration:** 1 giờ

### Actions

Support `--session=<id>` để resume specific session:

```bash
/wf-legacy-scan --resume --session=2026-04-22T10-00-00
```

### Acceptance Criteria

- [ ] Flag parsed correctly
- [ ] Session exists check
- [ ] scan-state.json integrity verify (jq -e)
- [ ] Resume specific session works

---

## Task H.3 — `--status` Update

**Duration:** 1 giờ

Update `procedures/resume-status.md` để display status từ scan-state.json:

```
/wf-legacy-scan --status

📊 Trạng thái Scan
Session: 2026-04-22T10-00-00
Profile: standard
Status: in_progress

Layers:
  ✅ L1 Discovery      — completed (14s)
  ✅ L2 Assessment     — completed (8s)
  ✅ L3 Inventory      — completed (82s)
  🟡 L4 Classification — in_progress (batch 3/5)
  ⬜ L5 Extraction     — not_started
  ⬜ L6 Synthesis      — not_started

IPS:
  Recommended: deep (reasoning: 1,200 files + 2 domains)
  Domains: finance (0.85), logistics (0.72)

Resume: /wf-legacy-scan --resume (continues from L4 batch 4)
```

### Acceptance Criteria

- [ ] Status đọc từ scan-state.json (không ledger.json)
- [ ] Hiển thị đủ 6 layers + status + progress
- [ ] Hiển thị IPS info
- [ ] Hiển thị resume command nếu applicable

---

## Task H.4 — Resume Test (CRITICAL)

**Priority:** CRITICAL · **Duration:** 3-4 giờ

### Actions

Test resume ở 4 levels × 3 fixtures = 12 test cases:

```bash
# Test matrix
for fixture in small-en medium-vn large-mixed; do
  for crash_point in L0_mid_L3 L1_mid_L4 L2_mid_L4_batch_3 L3_mid_L5_module_3_feat_5; do
    test_resume $fixture $crash_point
  done
done

test_resume() {
  local fixture=$1
  local crash=$2
  
  # 1. Start scan
  /wf-legacy-scan fixtures/$fixture/ --profile=standard &
  PID=$!
  
  # 2. Inject crash at specified point
  wait_until_crash_point $crash
  kill -9 $PID
  
  # 3. Resume
  /wf-legacy-scan fixtures/$fixture/ --resume
  
  # 4. Verify resumed from correct point
  verify_resume_point $crash
}
```

### Acceptance Criteria

- [ ] 12 test cases PASS
- [ ] Resume correctness: continues từ đúng point ±1 unit
- [ ] Lock released properly after crash
- [ ] session-log.json shows resume event

---

## Exit Criteria

- [x] All 4 tasks ✅
- [x] 12 resume test cases PASS (Tier 1 — 4 levels × 3 scenarios trong `test_crash_resume_flow.py`)
- [x] `--status` + `--session` flags work
- [x] IPS suite regression clean: 410/410 PASS (up from 397 — +13 Phase H tests)
- [x] 36 resume_router unit tests cover all 16 action_types + schema validation + CLI
- [x] `legacy-scan-phase-h-smoke.sh` PASS (23/23 checks)
- [x] `resume-status.md` v5.0 rewrite — Python router invocation + 16-case routing switch
- [x] Tier 2 E2E BLOCKED by A.3 fixtures (documented deviation — defer to Phase I)
- [x] `v5.0-phase-H` tag (pushed on branch)

## Artifacts

- `.claude/skills/workflow/_shared/ips/resume_router.py` — 604 dòng (CLI + routing + schema validation)
- `.claude/skills/workflow/_shared/ips/tests/test_resume_router.py` — 36 tests (routing table + schema + enrichment + CLI)
- `.claude/skills/workflow/_shared/ips/tests/test_crash_resume_flow.py` — 13 tests (4 levels × 3 scenarios + summary)
- `.claude/skills/workflow/wf-legacy-scan/procedures/resume-status.md` — v5.0 rewrite (Python router invocation)
- `.claude/scripts/legacy-scan-phase-h-smoke.sh` — 23-check smoke test suite
- `.claude/skills/workflow/_shared/ips/__init__.py` — version bump `5.0.0-phase-F` → `5.0.0-phase-H`

## Deviations từ Design

1. **Tier 2 E2E BLOCKED (same gate as D.9 + E.8 Tier 2).** Phase-H plan requires
   "12 test cases = 4 crash points × 3 fixtures" với actual `/wf-legacy-scan`
   invocation on small-en/medium-vn/large-mixed. Fixtures blocked by A.3 (user
   populate pending). Tier 1 delivers equivalent structural coverage (4 levels ×
   3 scenarios = 12 parameterized cases via `multiprocessing` + `os._exit(9)`).
   Tier 2 script design documented trong `legacy-scan-phase-h-smoke.sh` footer.
2. **Router implemented as Python module, not inline bash.** Original phase-H
   pseudocode suggested bash inline logic. Moved to `_shared/ips/resume_router.py`
   để (a) share state machine awareness với Phase E `scan_state_reader`, (b) unit
   testable, (c) return structured JSON cho bash switch instead of bash-embedded
   Python strings. bash caller invoke via `python -m ips.resume_router`.
3. **Status-aware routing enhancement.** Original routing table keyed only on
   `last_completed`. Enhanced để check layer `status` first — khi `last_completed=L3`
   nhưng `L4.status=in_progress` (crash mid-L4 scenario), Router correctly
   routes `resume_L4_batch` thay vì `start_L4_rerun_ips_b_if_missing`. Covered
   bởi 3 L1 crash scenarios + 3 L3 crash scenarios.

## Next Phase

→ [phase-I-integration-testing.md](phase-I-integration-testing.md)
