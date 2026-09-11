# Phase 7 Group C — CQG-2: Browser + Integration Gate (Step 7.3)

> **Entry condition:** Group B POST-GATE PASS (CQG-1 PASS hoặc N/A) với `E005_HEALTHY=false`.
> **Exit condition:** CQG-2 PASS hoặc CDG ACCEPT (skip evidence). REJECT 2 lần → `_phase7_trace_fail "E071"` → E001 escalate.
> **Next:** [phase7-verify/D-mobile-dashboard.md](D-mobile-dashboard.md) (Mobile Gate + Dashboard finalize).
>
> **Shared protocols cần thiết:**
> - [`_shared/16-critical-decision-gate.md`](../_shared/16-critical-decision-gate.md) — CDG REJECT pattern + anti-loop
> - [`_shared/06-on-failure.md`](../_shared/06-on-failure.md) — `_phase7_trace_fail` standard
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E071

> **⚠ GIỮ INLINE — KHÔNG extract sang script:** CDG REJECT qua AskUserQuestion (CORE-027). User-facing decision phải INLINE. Structured fix-log check (v10.10.0) chống false PASS từ grep-keyword fragility.

## Input contract (env vars từ Group B)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$DIMS_ARRAY`, `$E005_HEALTHY` | Pipeline state |
| `phase4-find-bugs/lanes/QD9-*` / `QD10-*` | Browser + Integration lane status |
| `phase5-triage/fix-log.json` | Structured per-dim fixed count (v10.10.0 fix) |
| `phase5-triage/issue-registry.json` | Reference cho cross-validation |

## Output contract (env vars truyền sang Group D)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `CQG2_PASS_FAIL` | 7.3 | PASS / FAIL / N/A |
| `CQG2_BROWSER` | 7.3 | "status=X, signals=N, fixed=M" |
| `CQG2_INTEGRATION` | 7.3 | Tương tự cho QD10 |

---

## Step 7.3 — CQG-2: Browser + Integration Gate (INLINE)

**Mục đích:** Verify QD9 (browser) + QD10 (integration) signals đã được cover trong fix-report.

**Điều kiện:** Step 7.2 PASS. Nếu `E005_HEALTHY=true` → **SKIP**.

**Thực thi (INLINE):**

```bash
if [ "$E005_HEALTHY" = "true" ]; then
  echo "CQG-2 SKIP (E005)"
  CQG2_PASS_FAIL="N/A"
  CQG2_BROWSER="N/A"
  CQG2_INTEGRATION="N/A"
else
  # Check QD9 + QD10 active trong DIMS_ARRAY
  CQG2_PASS=true
  CQG2_BROWSER="N/A"; CQG2_INTEGRATION="N/A"
  LANES_ROOT="$SESSION_DIR/phase4-find-bugs/lanes"

  # v10.10.0 fix: replace fragile grep-keyword check với structured check qua
  # fix-log.json/issue-registry.json (count fixed issues PER DIMENSION) — chống
  # false PASS khi fix-report có chứa "runtime"/"integration" nhưng không thực
  # sự fix issue thuộc dim.
  FIX_LOG="$SESSION_DIR/phase5-triage/fix-log.json"
  ISS_REG="$SESSION_DIR/phase5-triage/issue-registry.json"

  # Đếm fixed issues per dim từ fix-log (status = success)
  _count_fixed_for_dim() {
    local dim="$1"
    if [ -s "$FIX_LOG" ]; then
      jq --arg d "$dim" '[.entries[]? | select(.action == "fix_attempt" and .status == "success" and (.dimension // "") == $d)] | length' "$FIX_LOG" 2>/dev/null || echo 0
    else
      echo 0
    fi
  }

  if echo "$DIMS_ARRAY" | grep -q "QD9"; then
    QD9_DIR=$(ls -d "$LANES_ROOT/QD9-"* 2>/dev/null | head -1)
    [ -z "$QD9_DIR" ] && QD9_DIR="$LANES_ROOT/QD9-MISSING"
    QD9_STATUS=$(jq -r '.status' "$QD9_DIR/lane-status.json" 2>/dev/null || echo "missing")
    QD9_SIGS=$(jq '(.signals // []) | length' "$QD9_DIR/runtime/signals.json" 2>/dev/null || echo 0)
    QD9_FIXED=$(_count_fixed_for_dim "QD9")
    CQG2_BROWSER="status=$QD9_STATUS, signals=$QD9_SIGS, fixed=$QD9_FIXED"

    # FAIL nếu: lane chưa completed, hoặc có signals nhưng 0 fixed issue cho QD9
    if [ "$QD9_STATUS" != "completed" ] || { [ "$QD9_SIGS" -gt 0 ] && [ "$QD9_FIXED" -eq 0 ]; }; then
      CQG2_PASS=false
    fi
  fi

  if echo "$DIMS_ARRAY" | grep -q "QD10"; then
    QD10_DIR=$(ls -d "$LANES_ROOT/QD10-"* 2>/dev/null | head -1)
    [ -z "$QD10_DIR" ] && QD10_DIR="$LANES_ROOT/QD10-MISSING"
    QD10_STATUS=$(jq -r '.status' "$QD10_DIR/lane-status.json" 2>/dev/null || echo "missing")
    QD10_SIGS=$(jq '(.signals // []) | length' "$QD10_DIR/static-scan/signals.json" 2>/dev/null || echo 0)
    QD10_FIXED=$(_count_fixed_for_dim "QD10")
    CQG2_INTEGRATION="status=$QD10_STATUS, signals=$QD10_SIGS, fixed=$QD10_FIXED"

    if [ "$QD10_STATUS" != "completed" ] || { [ "$QD10_SIGS" -gt 0 ] && [ "$QD10_FIXED" -eq 0 ]; }; then
      CQG2_PASS=false
    fi
  fi

  CQG2_PASS_FAIL=$([ "$CQG2_PASS" = "true" ] && echo "PASS" || echo "FAIL")

  if [ "$CQG2_PASS_FAIL" = "FAIL" ]; then
    # CDG render INLINE (orchestrator gọi AskUserQuestion trực tiếp — user interaction)
    AskUserQuestion: "CQG-2 FAIL — QD9/QD10 evidence chưa đủ:
                      Browser: $CQG2_BROWSER
                      Integration: $CQG2_INTEGRATION
                      Tiếp tục?"
    Options: ACCEPT (skip evidence) / REJECT (re-spawn execute)
    # REJECT 2 lần → _phase7_trace_fail "E071" → E001 escalate
  fi
fi
export CQG2_PASS_FAIL CQG2_BROWSER CQG2_INTEGRATION
```

**VERIFY:**

```bash
[ "$CQG2_PASS_FAIL" = "PASS" ] || [ "$CQG2_PASS_FAIL" = "N/A" ] || [ "$CDG_ACCEPTED" = "true" ]
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E071 | QD9/QD10 lane-status missing | Re-read Phase 4 outputs → retry x1 |
| E071 | Signals không cover trong fix-report | CDG render — ACCEPT/REJECT |
| E071 | REJECT 2 lần | `_phase7_trace_fail "E071"` → E001 escalate |
| — | QD9/QD10 không active | Auto PASS |
| — | E005_HEALTHY=true | SKIP |

**Cross-ref:** CORE-027 (CDG), CORE-034 (Anti-loop), `_shared/06-on-failure.md` (`_phase7_trace_fail`).

---

## Group C POST-GATE Verify

```bash
test -n "$CQG2_PASS_FAIL" && \
{ [ "$CQG2_PASS_FAIL" = "PASS" ] || [ "$CQG2_PASS_FAIL" = "N/A" ] || [ "${CDG_ACCEPTED:-false}" = "true" ]; } && \
  echo "Group C PASS (CQG2=$CQG2_PASS_FAIL)" || echo "Group C FAIL"
```

## Next Group

→ Group D Mobile + Dashboard finalize — đọc [`phase7-verify/D-mobile-dashboard.md`](D-mobile-dashboard.md)
