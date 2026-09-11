# Phase 7 Group E — Generate 4 Reports (Step 7.5)

> **Entry condition:** Group D POST-GATE PASS (bug-dashboard.md finalized + TOTAL_ISSUES exported).
> **Exit condition:** 4 reports written + `fix-impact.json` audit_chain sha256 valid.
> **Next:** [phase7-verify/F-finalize.md](F-finalize.md) (Pipeline DONE + TRACE COMPLETE).
>
> **Shared protocols cần thiết:**
> - [`_shared/08-phase-summary.md`](../_shared/08-phase-summary.md) — Phase Summary format CORE-028
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E073, E074

## Input contract (env vars từ Group D)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID`, `$PROFILE`, `$SCOPE`, `$NAME` | Session identity |
| `$E005_HEALTHY`, `$DIMS_ARRAY`, `$MOBILE_MODE`, `$INTERFACE_TYPE` | Pipeline state |
| `$FIXED_COUNT`, `$DEFERRED_COUNT`, `$FAILED_COUNT`, `$TOTAL_ISSUES` | Counts |
| `$CQG1_PASS_FAIL`, `$CQG1_DEVIATION`, `$CQG2_PASS_FAIL`, `$CQG2_BROWSER`, `$CQG2_INTEGRATION` | Gate results |
| `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE` | CI context |
| `$STARTED_AT`, `$COMPLETED_AT` | Timestamps |

## Output contract (env vars truyền sang Group F)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `phase7-verify/orchestrator-summary.md` | 7.5 | CORE-028 tiếng Việt ≤40 dòng |
| `phase7-verify/fix-impact.json` | 7.5 | Cross-skill artifact CORE-036 (schema fix-impact-v1, audit_chain sha256) |
| `phase7-verify/phase-summary.md` | 7.5 | Accumulated 7-phase summaries |
| `phase7-verify/Phase7-report.md` | 7.5 | CORE-028 ≤15 dòng |
| `AUDIT_CHAIN` | 7.5 | Sha256 cho POST-GATE verification |

---

## Step 7.5 — Generate 4 Reports (orchestrator + fix-impact + phase-summary + Phase7-report)

**Mục đích:** Gộp 4 logical sub-steps (gộp 7.6+7.7+7.8+7.9 logic legacy):
1. **orchestrator-summary.md** — CORE-028 tiếng Việt ≤40 dòng
2. **fix-impact.json** — Cross-skill artifact CORE-036 (schema fix-impact-v1)
3. **phase-summary.md** — Accumulated 7-phase summaries
4. **Phase7-report.md** — CORE-028 ≤15 dòng

**v10.10.0 — Context Budget Check (CORE-038):** Step 7.5 generate 4 reports lớn — kiểm tra context trước khi populate.

```bash
. .claude/scripts/wf-fix-common.sh
_context_budget_check 7 "7.5" || rc=$?
case "${rc:-0}" in
  3) exit 9 ;;       # E009 FORCE STOP
  2) echo "WARN: Context 80-90% — finalize Phase 7 với reduced report depth" >&2 ;;
  1) echo "INFO: Context 65-80% — proceed với checkpoint sau Step 7.6" >&2 ;;
esac
```

**Thực thi (delegated script):**

```bash
export SESSION_ID PROFILE SCOPE NAME E005_HEALTHY DIMS_ARRAY
export FIXED_COUNT DEFERRED_COUNT FAILED_COUNT
export CQG1_PASS_FAIL CQG1_DEVIATION CQG2_PASS_FAIL CQG2_BROWSER CQG2_INTEGRATION
export GITNEXUS_AVAILABLE SERENA_AVAILABLE MOBILE_MODE INTERFACE_TYPE
export STARTED_AT COMPLETED_AT

PHASE7_S5=$(bash .claude/scripts/wf-fix-bugs/generate-phase7-reports.sh) || RC=$?

if [ "${RC:-0}" -ne 0 ]; then
  echo "ERROR: report generation fail (E074)" >&2
  exit "$RC"
fi

AUDIT_CHAIN=$(echo "$PHASE7_S5" | jq -r '.audit_chain')
export AUDIT_CHAIN
```

Script tạo 4 outputs từ templates (CORE-031):
- `orchestrator-summary.md`: populate Session ID + duration + project + scope + profile + metrics + dimensions summary + CI tools + Playwright + next steps
- `fix-impact.json`: schema `fix-impact-v1` + audit_chain.checksum = sha256(fix-status.json) (CORE-036). **v10.10.0 pre-finalize:** script này SET `fix-status.pipeline_status=DONE` TRƯỚC khi compute checksum để audit_chain phản ánh trạng thái FINAL.
- `phase-summary.md`: inline gộp head 8 dòng của Phase{1-7}-report.md
- `Phase7-report.md`: populate STATUS_PASS_FAIL + timestamps + CQG-1/CQG-2 results + pipeline status + duration + next action

**VERIFY:**

```bash
for f in orchestrator-summary.md fix-impact.json phase-summary.md Phase7-report.md; do
  test -s "$SESSION_DIR/phase7-verify/$f" || { echo "FAIL: $f missing" >&2; exit 1; }
done

# fix-impact.json: schema + audit_chain checksum 64-char (CORE-036)
jq -e '."$schema" == "fix-impact-v1"' "$SESSION_DIR/phase7-verify/fix-impact.json"
jq -e '.audit_chain.checksum | length == 64' "$SESSION_DIR/phase7-verify/fix-impact.json"

# Phase7-report ≤15 dòng
LINES=$(wc -l < "$SESSION_DIR/phase7-verify/Phase7-report.md")
[ "$LINES" -le 15 ]
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E073 | orchestrator-summary write fail | Retry x1 → `_phase7_trace_fail "E073"` → E001 |
| E074 | fix-impact.json schema/audit_chain fail | Retry x1 → escalate |
| E074 | phase-summary/Phase7-report write fail | Retry x1 → escalate |
| — | Critical template missing (exit 2) | Stop — escalate |

**Cross-ref:** CORE-028 (Phase Summary), CORE-031 (Template), CORE-036 (Cross-Skill Artifact), CORE-035, CORE-038 (Context Budget).

---

## Group E POST-GATE Verify

```bash
for f in orchestrator-summary.md fix-impact.json phase-summary.md Phase7-report.md; do
  test -s "$SESSION_DIR/phase7-verify/$f" || { echo "FAIL: $f missing"; exit 1; }
done
jq -e '."$schema" == "fix-impact-v1"' "$SESSION_DIR/phase7-verify/fix-impact.json" >/dev/null && \
jq -e '.audit_chain.checksum | length == 64' "$SESSION_DIR/phase7-verify/fix-impact.json" >/dev/null && \
  echo "Group E PASS" || echo "Group E FAIL"
```

## Next Group

→ Group F Finalize Pipeline — đọc [`phase7-verify/F-finalize.md`](F-finalize.md)
