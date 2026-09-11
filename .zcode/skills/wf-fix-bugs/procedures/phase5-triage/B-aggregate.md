# Phase 5 Group B — Aggregate + Process Integrity (Steps 5.2 + 5.3)

> **Entry condition:** Group A POST-GATE PASS (Phase 5 marked in_progress, N>0).
> **Exit condition:** `issue-registry.json` + `process-violations.json` written. Critical PI count exported cho Group C decision.
> **Next:** [phase5-triage/C-cdg-critical.md](C-cdg-critical.md) (evaluate violations → INLINE CDG nếu critical).
>
> **Shared protocols cần thiết:**
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E050, E051, E052
> - References: CORE-029 (Spot-Check), CORE-025 (Parallel Safety)

## Input contract (env vars từ Group A)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$TOTAL_SIGNALS` | Pipeline state |
| `phase4-find-bugs/lanes/QD*/[stream]/signals.json` | Source signals để aggregate |
| `phase3-plan/work-plan.json` | Reference cho PI4 dim completeness |

## Output contract (env vars truyền sang Group C)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `TOTAL_ISSUES` | 5.2 | Sau dedup từ aggregate-and-spot-check.sh |
| `METHOD`, `WARNINGS` | 5.2 | Aggregation method + spot-check warnings |
| `INTEGRITY_PASS` | 5.3 | true/false từ process-integrity-check.sh |
| `CRITICAL`, `HIGH`, `LOW` | 5.3 | Counts theo severity của violations |
| `phase5-triage/issue-registry.json` | 5.2 | Aggregated + deduped (schema issue-registry-v2) |
| `phase5-triage/process-violations.json` | 5.3 | PI1-PI5 results (schema process-violations-v1) |

---

## Step 5.2 — Aggregate & Spot-Check Signal Registry

**Mục đích:** Merge tất cả signals từ mọi lane, dedup by fingerprint, validate via CORE-029 spot-check (3 random samples).

```bash
PHASE5_S2=$(bash .claude/scripts/wf-fix-bugs/aggregate-and-spot-check.sh) || RC=$?
TOTAL_ISSUES=$(echo "$PHASE5_S2" | jq -r '.total_issues')
METHOD=$(echo "$PHASE5_S2" | jq -r '.method')
WARNINGS=$(echo "$PHASE5_S2" | jq -r '.spot_check_warnings')

# RC=4 chỉ là spot-check WARN — continue allowed
if [ "${RC:-0}" -gt 0 ] && [ "$RC" -ne 4 ]; then
  echo "ERROR: Aggregator fail (E050)" >&2
  exit "$RC"
fi
export TOTAL_ISSUES METHOD WARNINGS
```

Script ưu tiên Python CLI (`python -m aggregate`), fallback jq merge nếu Python không khả dụng. Dedup by fingerprint (keep first occurrence). Spot-check sample 3 issues random validate required fields (lane/probe_id/fingerprint).

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase5-triage/issue-registry.json"
jq -e '.issues and .total_issues > 0' "$SESSION_DIR/phase5-triage/issue-registry.json"
jq -e '(.issues | length) == ([.issues[].fingerprint] | unique | length)' \
  "$SESSION_DIR/phase5-triage/issue-registry.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E050 | Aggregator fail (exit 2/3) | Retry x1 → ESCALATE |
| E051 | Spot-check WARN (exit 4) | WARN, continue (không block — CORE-029 giám sát) |

---

## Step 5.3 — Process Integrity Check (PI1-PI5)

**Mục đích:** Audit toàn vẹn quy trình Phase 4 → 5 (Step completeness, empty result recording, signal overwrite, dimension completeness, cross-source consistency).

```bash
PHASE5_S3=$(bash .claude/scripts/wf-fix-bugs/process-integrity-check.sh) || RC=$?
INTEGRITY_PASS=$(echo "$PHASE5_S3" | jq -r '.integrity_pass')
CRITICAL=$(echo "$PHASE5_S3" | jq -r '.critical_count')
HIGH=$(echo "$PHASE5_S3" | jq -r '.high_count')
LOW=$(echo "$PHASE5_S3" | jq -r '.low_count')
export INTEGRITY_PASS CRITICAL HIGH LOW
# RC=4 = critical violations → orchestrator render CDG ở Group C
# RC=0 = pass hoặc high/low only (continue → Group C để check counts)
```

Script tạo `process-violations.json` từ template (CORE-031), 5 checks:
- **PI1** Step Completeness: `phase4.status == "completed"`
- **PI2** Empty Result Recording: tất cả dims có `lane-status.json`
- **PI3** Signal Overwrite Detection: mỗi stream chỉ 1 `signals.json` (CORE-025)
- **PI4** Dimension Execution Completeness: dim trong plan có lane directory
- **PI5** Cross-Source Consistency: static + runtime file overlap

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase5-triage/process-violations.json"
jq -e '.checks | length == 5' "$SESSION_DIR/phase5-triage/process-violations.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E052 | Critical violation (exit 4, PI1/PI3) | Group C CDG hard-stop |
| E052 | High violation only | WARN, continue Group D |
| E052 | Low violation only | Continue Group D |
| E050 | Atomic write fail (exit 3) | Retry x1 |

**Cross-ref:** CORE-029 (Spot-Check), CORE-009 (Schema), CORE-025 (Parallel Safety), CORE-034, CORE-035.

---

## Group B POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase5-triage/issue-registry.json" && \
test -s "$SESSION_DIR/phase5-triage/process-violations.json" && \
test -n "$TOTAL_ISSUES" && test "$TOTAL_ISSUES" -gt 0 && \
test -n "$CRITICAL" && test -n "$HIGH" && test -n "$LOW" && \
  echo "Group B PASS" || echo "Group B FAIL"
```

## Next Group

→ Group C CDG Critical Evaluation — đọc [`phase5-triage/C-cdg-critical.md`](C-cdg-critical.md)
