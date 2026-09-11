# Phase 5 FINAL: VERIFY_FINAL — Calculate Metrics

> Trang thai cuoi cua state machine Phase 5. Chi chay khi Decision Tree quyet dinh TERMINATE (PASS / WARN / FAIL).
> Step 5.20. Sau khi hoan thanh → chuyen `phase6-report.md`.

**PRE-GATE:** VERIFY_EVALUATE da quyet dinh TERMINATE (PASS/WARN/FAIL). Xem [`phase5-loop.md`](phase5-loop.md) §Decision Tree.

**INPUT:**
- `$SESSION_DIR/issue-registry.json` (final state — co regression + fixed entries)
- `$SESSION_DIR/fix-log.json` (cumulative entries tat ca iterations)
- `$SESSION_DIR/fix-status.json` (loop_state.current_iteration + iteration_history)

**OUTPUT:** Updated issue-registry.json (verify.verified=true per fixed issue), final metrics trong fix-status.json.

---

## Calculate Final Metrics (Step 5.20)

| Step | Action | Verify |
| ---- | ------ | ------ |
| 5.20 | **Calculate final metrics** (xem §Formulas ben duoi) + **Update issue-registry.json** + **BAT BUOC — Update fix-status.json** theo spec "Phase 5 POST-GATE" trong [`_shared.md`](_shared.md#fix-statusjson-update-contract) | Metrics calculated |

### Formulas

```bash
fix_success_rate = (
  jq '[.issues[] | select(.status=="fixed")] | length' issue-registry.json
  /
  jq '.total_issues' issue-registry.json
) * 100

regressions_count = jq '[.issues[] | select(.status=="regression")] | length' issue-registry.json

# Ripple regressions (ADR-22 rule 2) — phan biet voi normal regressions
ripple_regressions_count = jq '[.issues[] | select(.type=="ripple_regression")] | length' issue-registry.json

iterations_used = phases.phase_5.loop_state.current_iteration
```

### Update issue-registry.json

FOR moi issue WHERE `status == "fixed"`:
```
SET verify.verified = true
SET verify.iteration_verified = iteration  # iteration fix duoc verify (thuong la current_iteration)
```

### Registry impl_status downgrade (CDG-EXEC-02, CDG-03)

> **CORE-008 Exception (authorized):** CORE-008 cam _silent/automatic_ downgrade `done → non-done`.
> CDG-EXEC-02 la exception **duy nhat** cho phep downgrade TRONG Phase 5 rollback, BAT BUOC co user confirmation
> (Protocol 16). Neu user tu choi → GIU `impl_status = "done"`. KHONG bao gio bypass CDG.

Neu fix gay regression va phai rollback → PHAI check truoc khi downgrade `impl_status` trong `req-registry.json`:

```
FOR moi REQ-ID trong rollback scope:
  current_status = jq ".requirements[] | select(.req_id==\"$REQ\") | .impl_status" req-registry.json
  IF current_status == "done":
    # TRIGGER CDG-EXEC-02 (CDG-03 chuan cua Protocol 16)
    Hien thi:
      "⚠️ AI du dinh thay doi trang thai yeu cau '$REQ' tu 'done' sang 'in_progress'.
       Ly do: Fix gay regression, can rollback.
       Ban co dong y thay doi khong? (Co/Khong)"
    IF user "Co" → downgrade + LOG vao session-log.json
    IF user "Khong" → GIU NGUYEN status="done" + LOG warning "regression da detect nhung user tu choi downgrade"
  ELSE:
    Downgrade khong can CDG (khong vi pham CORE-008)
```

Xem [CORE-027 CDG](_shared.md#core-027-critical-decision-gate) cho mapping voi Protocol 16.

### Update fix-status.json (BAT BUOC)

Xem chi tiet trong [`_shared.md`](_shared.md#fix-statusjson-update-contract) §"Phase 5 POST-GATE":

```
phases.phase_5.status = "completed"
phases.phase_5.completed_at = NOW
phases.phase_5.iterations_run = final_iteration
phases.phase_5.fix_success_rate = X%
phases.phase_5.ripple_regressions_count = Y  # ADR-22 rule 2
phases.phase_5.ripple_verify.final_iteration = final_iteration  # already set in step 5.1b
phases.phase_5.loop_state.current_iteration = final_iteration  # persisted for resume
phases.phase_5.loop_state.state = "VERIFY_FINAL"
phases.phase_5.loop_state.iteration_history[-1].final_status = "PASS" | "WARN" | "FAIL"
phases.phase_5.override_granted = true / false
phases.phase_5.override_reason = "..." (neu granted)
progress_pct = 90
next_action = "phase_6_report"
```

---

## Scoring

```
fix_success_rate = (issues_fixed / issues_total) x 100%

PASS   ← fix_success_rate >= 80% VA khong con CRITICAL issues
WARN   ← fix_success_rate 50-79% HOAC con HIGH issues
FAIL   ← fix_success_rate < 50% HOAC con CRITICAL issues
```

**Status mapping (correlate voi Decision Tree):**

| Decision Tree Outcome | Final Status |
|-----------------------|-------------|
| Option (1) PASS | **PASS** |
| Option (2) iter 4, CRITICAL=0, HIGH=0 | PASS |
| Option (2) iter 4, CRITICAL=0, HIGH>0 | WARN |
| Option (2) iter 4, CRITICAL>0 | FAIL + E039 |
| Option (3) iter 3 + CRITICAL>0 | **FAIL** + E039 |
| Option (4) CDG NO | **WARN** |
| Option (4) CDG YES → iter 4 | Re-evaluate at iter 4 |

---

## POST-GATE

**Content validity:**
- Zero CRITICAL issues remaining (hoac user confirmed WARN)
- `fix_success_rate` calculated
- `issue-registry.json` `verify.verified = true` cho tat ca fixed issues
- **Verify Ripple attempted (ADR-22 rule 2):** `phases.phase_5.ripple_verify.attempted == true` HOAC `.skipped == true`
  (skipped chi duoc phep khi `flags.lpm_minimal == true`).

**fix-status.json updated theo spec "Phase 5 POST-GATE".**

**POST-GATE assertion (Protocol 10 — T3 Content):**
```bash
jq -e '.phases.phase_5.ripple_verify | (.attempted == true) or (.skipped == true and .reason == "lpm_minimal")' \
  $SESSION_DIR/fix-status.json \
  || { echo "POST-GATE FAIL: Verify Ripple chua chay (ADR-22 rule 2)"; exit 1; }
```

**Next:** [`phase6-report.md`](phase6-report.md) — Generate fix-report.md + fix-history.md + phase-summary.md.
