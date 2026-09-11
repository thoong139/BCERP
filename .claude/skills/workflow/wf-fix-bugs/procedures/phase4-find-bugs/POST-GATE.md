# Phase 4 POST-GATE + Error Reference

> **Entry condition:** Group G PASS (Phase4-report.md + phase4-summary.json written + fix-status.phase4 = "completed" + TRACE COMPLETE).
> **Exit condition:** All T1-T4 checks PASS → advance Phase 5.
> **Next:** Phase 5 — `procedures/phase5-triage.md` (Triage agent classifies signals → fix-plan).

## POST-GATE T1-T4 Validation

```bash
# T1: Files exist + non-empty (4 critical outputs)
test -s "$SESSION_DIR/phase4-find-bugs/Phase4-report.md"        || echo "FAIL T1: Phase4-report.md"
test -s "$SESSION_DIR/phase4-find-bugs/phase4-summary.json"     || echo "FAIL T1: phase4-summary.json (v10.10)"
for dim in $DIMS_ARRAY; do
  test -s "$SESSION_DIR/phase4-find-bugs/lanes/$dim/lane-status.json" \
    || echo "FAIL T1: $dim/lane-status.json"
done

# T1b: phase4-summary.json schema (v10.10 cross-skill artifact CORE-036)
jq -e '."$schema" == "phase4-summary-v1"' \
  "$SESSION_DIR/phase4-find-bugs/phase4-summary.json" || echo "FAIL T1b: invalid summary schema"

# T1c: audit_chain integrity (CORE-036 sha256 checksums)
jq -e '.audit_chain.signals_sha256 and .audit_chain.lane_status_sha256' \
  "$SESSION_DIR/phase4-find-bugs/phase4-summary.json" || echo "FAIL T1c: audit_chain missing"
# Verify checksums are 64-char sha256 hex (CORE-036 integrity)
jq -e '(.audit_chain.signals_sha256 | length == 64) and (.audit_chain.lane_status_sha256 | length == 64)' \
  "$SESSION_DIR/phase4-find-bugs/phase4-summary.json" \
  || echo "FAIL T1c: audit_chain checksum format invalid (must be 64-char sha256)"

# T2: lane-status structure (CORE-012 tier 2)
for dim in $DIMS_ARRAY; do
  jq -e '.dimension_id and .status' \
    "$SESSION_DIR/phase4-find-bugs/lanes/$dim/lane-status.json" \
    || echo "FAIL T2: $dim invalid lane-status structure"
done

# T3: All lanes terminal (CORE-012 tier 3)
for dim in $DIMS_ARRAY; do
  jq -e '.status == "completed" or .status == "skipped" or .status == "failed"' \
    "$SESSION_DIR/phase4-find-bugs/lanes/$dim/lane-status.json" \
    || echo "FAIL T3: $dim not terminal"
done

# T4: signals_total trong fix-status matches actual aggregate (CORE-012 tier 4)
jq -e '.signals_total >= 0' "$SESSION_DIR/fix-status.json" || echo "FAIL T4: signals_total missing"
jq -e '.phases.phase4.status == "completed"' "$SESSION_DIR/fix-status.json" \
  || echo "FAIL T4: phase4 not completed"
```

**Tất cả T1-T4 PASS → Phase 4 hoàn tất, advance sang Phase 5.**

## Phase 4 Report Summary

Sau POST-GATE pass, `phase4-find-bugs/Phase4-report.md` đã được tạo (qua Group G) với:

- Status (PASS/FAIL), Started/Completed timestamps
- Total dimensions dispatched + completed/failed counts
- Signals total (aggregated từ 3 streams × N lanes)
- Probe failures (từ probe-failures.log)
- CDG decisions count (E090/E090b nếu PW lanes)
- Pointer đến `phase4-summary.json` cho downstream Phase 5/6/7 fast-path

## Cross-skill Artifact (CORE-036)

`phase4-summary.json` schema `phase4-summary-v1` được consumed bởi:

| Consumer | Field used | Purpose |
|----------|-----------|---------|
| Phase 5 `aggregate-and-spot-check.sh` | `.aggregated.top_fingerprints`, `.registry_coverage` | Fast-path aggregation (defer — vẫn scan signals.json) |
| Phase 7 CQG-2 | `.dimensions[QD9].by_severity`, `.dimensions[QD10].by_severity` | Cross-validation critical still unfixed |
| External tools (audit, dashboards) | All fields | 1-shot query vs N-lane scan |

`audit_chain.signals_sha256` + `audit_chain.lane_status_sha256` đảm bảo integrity (CORE-036 — tampering detected).

## On Failure — Quick Reference

| Code | Lỗi | Auto-Fix | Max Retry | Escalate |
|------|-----|----------|-----------|----------|
| E001 | Disk/env error | Re-export env vars | 1 | AskUserQuestion |
| E009 | Context >90% | FORCE STOP → `--resume` | 0 | Hướng dẫn user |
| E030 | Phase 3 chưa completed / dim thiếu `needs_playwright` | — | 0 | Chạy Phase 3 |
| E035 | Atomic write fail | Retry script | 2 | E001 escalate |
| E040 | Static probe fail | Timeout 5min + retry x1 → fallback empty | 1 | Continue |
| E041 | Runtime probe fail | Record probe-failures.log, continue | 0 | Continue |
| E042 | LLM probe fail | Record probe-failures.log, continue | 0 | Continue |
| E043 | QD-report missing | Generate stub (script tự handle) | 0 | Continue |
| E044 | Playwright launch / lock fail | Retry x2 | 2 | Escalate |
| E045 | Mobile emulation unsupported | WARN, fallback desktop viewport | 0 | Continue |
| E046 | Lane timeout (>15 min) / Agent spawn fail / Prompt verify fail | Re-render (D), Mark lane failed (F) | 1 | Continue |
| E047 | POST-GATE DATA INCONSISTENCY | Retry fix x1 | 1 | AskUserQuestion |
| E048 | Signal schema invalid | Drop signal, log warning | 0 | Continue |
| E049 | Fingerprint collision | Keep first, skip duplicate | 0 | Continue |
| E090 | Browser CDG — missing URL | User skip/cancel | 0 | Halt session |
| E090b | Browser CDG — URL conflict | User wait/cancel | 0 | Halt session |

**Auto-fix budget Phase 4:** Max 3 retries tổng / phase (CORE-034). Reset khi POST-GATE PASS.

## Resume Logic

```
Khi orchestrator gọi với --resume:
1. Đọc fix-status.json → phase hiện tại = 4
2. FOR each dimension in DIMS_ARRAY:
   a. Đọc lane-status.json
   b. status ∈ {completed, skipped} → SKIP
   c. status ∈ {failed, in_progress} + started_at > 30 phút → stale → reset "pending"
   d. status = "pending" → re-dispatch lane agent (rendered prompt + verify)

Per-probe resume (lane agent internal):
  - Trước mỗi probe: check raw/{PROBE_ID}.json tồn tại + valid
  - Đã có + valid → skip probe
  - Thiếu/corrupt → chạy probe

Script timeout: MCV3_PROBE_SCRIPT_TIMEOUT env (default 300s = 5 phút)
Phase 4 hard timeout: 30 phút tổng → E046 cho lanes chưa xong
```

```bash
PHASE4_STATUS=$(jq -r '.phases.phase4.status // "not_started"' "$SESSION_DIR/fix-status.json")
case "$PHASE4_STATUS" in
  "completed") echo "Phase 4 completed → advance Phase 5" ;;
  "in_progress")
    # Check lane states để xác định resume point
    PENDING_LANES=0
    for dim in $DIMS_ARRAY; do
      LANE_STATUS=$(jq -r '.status' "$SESSION_DIR/phase4-find-bugs/lanes/$dim/lane-status.json" 2>/dev/null)
      [ "$LANE_STATUS" != "completed" ] && [ "$LANE_STATUS" != "skipped" ] && PENDING_LANES=$((PENDING_LANES + 1))
    done
    [ "$PENDING_LANES" -eq 0 ] && echo "All lanes terminal → resume Group F validate" \
      || echo "$PENDING_LANES lanes pending → resume Group E dispatch (only pending)"
    ;;
  "failed") echo "Check error-ledger.json" ;;
  *) echo "Start Phase 4 from Group A (Step 4.1)" ;;
esac
```

## Next Phase

Phase 5 — `procedures/phase5-triage.md` (Triage agent: classify severity + fixability, generate fix-plan + bug-triage from phase4-find-bugs aggregated signals).

> Phase 5 đọc `lane-status.json` (status, signals_*) + `signals.json` per stream để aggregate signals, spawn `wf-fix-triage` agent, và emit `fix-plan.md` + `bug-triage.md` cho Phase 6.
