# Phase 7 Group B — CQG-1: Numeric Metric Verification (Step 7.2)

> **Entry condition:** Group A POST-GATE PASS với `E005_HEALTHY=false` (live mode).
> **Exit condition:** CQG-1 PASS (deviation ≤ 5%) hoặc CDG ACCEPT (sau retry budget) → continue Group C.
> **Next:** [phase7-verify/C-cqg2-cdg.md](C-cqg2-cdg.md) (CQG-2 Browser + Integration với INLINE CDG REJECT).
>
> **Shared protocols cần thiết:**
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E070, E001
> - [`_shared/06-on-failure.md`](../_shared/06-on-failure.md) — `_phase7_trace_fail` pattern (reference)

## Input contract (env vars từ Group A)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$E005_HEALTHY` | Pipeline state |
| `phase5-triage/fix-plan.md` | Expected metrics (fixed/deferred/failed counts) |
| `phase6-execute/fix-report.md` | Actual metrics |
| `phase6-execute/fix-execution-result.json` (v10.11 schema v2) | Structured fast-path (ưu tiên) |

## Output contract (env vars truyền sang Group C)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `CQG1_PASS_FAIL` | 7.2 | PASS / FAIL / N/A (nếu E005 SKIP) |
| `CQG1_DEVIATION` | 7.2 | Deviation pct (worst-case 3 metrics) |

---

## Step 7.2 — CQG-1: Numeric Metric Verification

**Mục đích:** So sánh số liệu expected (fix-plan.md) vs actual (fix-report.md). Fail nếu mismatch > 5%.

**Điều kiện:** Step 7.1 PASS. Nếu `E005_HEALTHY=true` → **SKIP** (không có fixes để verify → orchestrator route trực tiếp Group D).

```bash
PHASE7_S2=$(bash .claude/scripts/wf-fix-bugs/cqg1-numeric.sh) || RC=$?

if [ "${RC:-0}" -eq 5 ]; then
  echo "CQG-1 SKIP (E005 healthy path)"
  CQG1_PASS_FAIL="N/A"
  CQG1_DEVIATION="0"
elif [ "${RC:-0}" -eq 4 ]; then
  echo "CQG-1 FAIL — auto-fix retry (max 3 — CORE-034)"
  # Auto-fix: re-read fix-plan + fix-report, re-calculate
  # Budget hết → _phase7_trace_fail "E070" → escalate
  CQG1_PASS_FAIL="FAIL"
else
  CQG1_PASS_FAIL="PASS"
fi
CQG1_DEVIATION=$(echo "$PHASE7_S2" | jq -r '.deviation_pct')
export CQG1_PASS_FAIL CQG1_DEVIATION
```

Script extract metrics (multi-format regex) + tính deviation:
- expected từ `fix-plan.md`: `fixed_count`, `deferred_count`, `failed_count`
- actual từ `fix-report.md`: tương tự
- **v10.11 fast-path:** ưu tiên đọc `fix-execution-result.json` structured (schema v2), fallback regex Markdown nếu missing
- Worst-case deviation (max of 3) so với threshold (default 5%)

**VERIFY:**

```bash
PASS=$(echo "$PHASE7_S2" | jq -r '.pass')
[ "$PASS" = "true" ] || [ "$E005_HEALTHY" = "true" ]
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E070 | Mismatch > 5% (exit 4) | Retry x3 → budget hết → `_phase7_trace_fail "E070"` → E001 escalate |
| — | E005_HEALTHY=true (exit 5) | SKIP — không cần verify |

**Cross-ref:** CORE-034 (Auto-Fix Budget), CORE-011 (Forensic), CORE-036 (fix-execution-result-v2 fast-path).

---

## Group B POST-GATE Verify

```bash
test -n "$CQG1_PASS_FAIL" && \
{ [ "$CQG1_PASS_FAIL" = "PASS" ] || [ "$CQG1_PASS_FAIL" = "N/A" ]; } && \
  echo "Group B PASS (CQG1=$CQG1_PASS_FAIL, deviation=$CQG1_DEVIATION%)" || echo "Group B FAIL"
```

## Next Group

→ Group C CQG-2 Browser + Integration (INLINE CDG REJECT) — đọc [`phase7-verify/C-cqg2-cdg.md`](C-cqg2-cdg.md)
