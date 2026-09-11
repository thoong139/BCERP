# Phase 5 Group G — Reports + Finalize (Steps 5.9 + 5.10)

> **Entry condition:** Group F POST-GATE PASS (safety-check.json written, no blockers OR CDG CONTINUE).
> **Exit condition:** 3 reports generated + `fix-status.phase5 = completed` + TRACE COMPLETE event appended.
> **Next:** [phase5-triage/POST-GATE.md](POST-GATE.md) (T1-T4 validation) → Phase 6.
>
> **Shared protocols cần thiết:**
> - [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md) — TRACE COMPLETE pattern (reference)
> - [`_shared/08-phase-summary.md`](../_shared/08-phase-summary.md) — Phase Summary format CORE-028

## Input contract (env vars từ Group F)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID` | Session identity |
| `$TOTAL_ISSUES`, `$TOTAL_SIGNALS`, `$BLOCKERS` | Counts cho reports |
| `phase5-triage/{bug-triage.md, fix-plan.md, safety-check.json, cdg-tokens.json}` | Source data |

## Output contract (env vars truyền sang POST-GATE)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `phase5-triage/coverage-report.md` | 5.9 | Metrics: dimensions, probes, severity distribution |
| `phase5-triage/coverage-report.json` | 5.9 | Machine-readable (schema coverage-report-v1) |
| `$SESSION_DIR/bug-dashboard.md` | 5.9 | Inline checklist by lane (matches v10.6) |
| `phase5-triage/Phase5-report.md` | 5.9 | CORE-028 tiếng Việt ≤15 dòng |
| `fix-status.phase5 = completed` | 5.10 | Atomic update (phase-finalize.sh) |
| TRACE COMPLETE event appended | 5.10 | session-log.json events[-1].phase = "phase5" |

---

## Step 5.9 — Generate Reports (Coverage + Dashboard + Phase5-report)

**Mục đích:** Generate 3 reports từ template (gộp 5.11+5.12+5.13 logic legacy).

```bash
PHASE5_S9=$(bash .claude/scripts/wf-fix-bugs/generate-phase5-reports.sh) || RC=$?

if [ "${RC:-0}" -ne 0 ]; then
  echo "ERROR: report generation fail (E051)" >&2
  exit "$RC"
fi

# Verify outputs
test -s "$SESSION_DIR/phase5-triage/coverage-report.md"
test -s "$SESSION_DIR/bug-dashboard.md"
test -s "$SESSION_DIR/phase5-triage/Phase5-report.md"
REPORT_LINES=$(wc -l < "$SESSION_DIR/phase5-triage/Phase5-report.md")
[ "$REPORT_LINES" -le 15 ] || echo "WARN: Phase5-report $REPORT_LINES dòng > 15"
```

### Step 5.9b — Derive Fix-Plan Counts (v11 / W1-T6)

**Mục đích:** Đếm CHÍNH XÁC expected counts từ `fix-plan.md` → ghi `fix-plan-counts.json` (schema `fix-plan-counts-v1`). Phase 7 CQG-1 đọc file này thay vì regex Markdown fragile.

**Rationale:** Trong v10.x, `cqg1-numeric.sh` dùng `grep | head -1` trên fix-plan.md không deterministic — pick wrong number → CQG-1 PASS giả. v11 strict mode yêu cầu fix-plan-counts.json.

```bash
SESSION_DIR="$SESSION_DIR" bash .claude/scripts/wf-fix-bugs/derive-fix-plan-counts.sh \
  > /dev/null 2>&1 || echo "WARN(v11): derive-fix-plan-counts.sh fail — Phase 7 sẽ auto-bootstrap" >&2

# Verify output
test -s "$SESSION_DIR/phase5-triage/fix-plan-counts.json" || \
  echo "WARN(v11): fix-plan-counts.json không sinh được — graceful fallback ở Phase 7" >&2
```

**On Failure:** Non-blocking (Phase 7 cqg1-numeric.sh có auto-bootstrap fallback). Chỉ log WARN.

**Cross-ref:** CORE-036 (Cross-Skill Artifact — produces_for phase7-verify), W1-T2 cqg1-numeric.sh strict mode.

Script tạo 3 reports từ template (CORE-031):
1. **coverage-report.md + coverage-report.json (v10.11.0)** — metrics: dimensions, probes, severity distribution. JSON schema `coverage-report-v1` cho Phase 7 + wf-prepare-deployment opt-in consumer.
2. **bug-dashboard.md** (tại `$SESSION_DIR/` root) — inline checklist by lane (matches v10.6 fallback), version counter bump v10.11.0.
3. **Phase5-report.md** (CORE-028 tiếng Việt ≤15 dòng) — populate từ template với severity + CDG + safety.

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E051 | Template missing (exit 2) | Fallback inline generation — WARN |
| E051 | Atomic write fail (exit 3) | Retry x1 |

**Cross-ref:** CORE-031 (Template Usage), CORE-028 (Phase Summary), CORE-009 (Schema).

---

## Step 5.10 — Finalize Phase 5 (delegated to phase-finalize.sh)

> **v10.17.0:** Inline `finalize-phase5.sh` được thay bằng shared `phase-finalize.sh` để consistency cross-phase. Combines TRACE COMPLETE + atomic fix-status update vào 1 script call.

**Mục đích:** Mark Phase 5 completed + APPEND COMPLETE event.

```bash
# Prepare extra fields cho phases.phase5
PHASE_EXTRA_FIELDS=$(jq -n \
  --argjson signals "${TOTAL_SIGNALS:-0}" \
  --argjson issues "${TOTAL_ISSUES:-0}" \
  --argjson blockers "${BLOCKERS:-0}" \
  '{signals_total: $signals, issues_total: $issues, safety_blockers: $blockers}')

# Delegate dual-write trace + fix-status update
SESSION_DIR="$SESSION_DIR" PHASE_NUM=5 \
  PHASE_EXTRA_FIELDS="$PHASE_EXTRA_FIELDS" \
  bash .claude/scripts/wf-fix-bugs/phase-finalize.sh
```

**VERIFY:**

```bash
# v10.10.0 fix: E005 healthy path (N=0 issues) là valid completion → bypass
# .issues_total > 0 check khi e005_healthy=true.
jq -e '.phases.phase5.status == "completed"' "$SESSION_DIR/fix-status.json"
jq -e '.phases.phase5.issues_total >= 0 or .phases.phase5.e005_healthy == true' \
  "$SESSION_DIR/fix-status.json"
jq -e '.events[-1].phase == "phase5" and .events[-1].event == "COMPLETE"' \
  "$SESSION_DIR/session-log.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E035 | Atomic write fail (exit 3) | Retry build tmp x1 |

**Cross-ref:** CORE-035 (Atomic Write), CORE-026 (Execution Trace), CORE-006 (Registry Safe-Write).

---

## Group G POST-GATE Verify

```bash
jq -e '.phases.phase5.status == "completed"' "$SESSION_DIR/fix-status.json" >/dev/null && \
jq -e '.events[-1].phase == "phase5" and .events[-1].event == "COMPLETE"' \
  "$SESSION_DIR/session-log.json" >/dev/null && \
test -s "$SESSION_DIR/phase5-triage/Phase5-report.md" && \
  echo "Group G PASS" || echo "Group G FAIL"
```

## Next: Phase 5 POST-GATE

→ Đọc [`phase5-triage/POST-GATE.md`](POST-GATE.md) để validate T1-T4 trước khi advance Phase 6.
