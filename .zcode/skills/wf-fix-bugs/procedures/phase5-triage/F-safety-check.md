# Phase 5 Group F — Safety Check CORE-020 (Step 5.8)

> **Entry condition:** Group E POST-GATE PASS (CDG-PRE-EXECUTE token = accepted).
> **Exit condition:** `safety-check.json` written. Blockers handled qua CDG (CONTINUE/ABORT) nếu có.
> **Next:** [phase5-triage/G-reports-finalize.md](G-reports-finalize.md) (Generate Reports + Finalize).
>
> **Shared protocols cần thiết:**
> - [`_shared/16-critical-decision-gate.md`](../_shared/16-critical-decision-gate.md) — CDG render pattern
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E055

> **⚠ GIỮ INLINE — KHÔNG extract sang script (CDG part):** CDG render qua AskUserQuestion cho blockers (CORE-027).

## Input contract (env vars từ Group E)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$LEGACY_MODE` | Pipeline state |
| `phase5-triage/fix-plan.md` | Source cho collision + xref check |
| `.mc-data/work/legacy-scan/legacy-decisions.json` | LEGACY_MODE deprecated check |

## Output contract (env vars truyền sang Group G)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `phase5-triage/safety-check.json` | 5.8 | Schema safety-check-v1 (4 checks + blockers array) |
| `BLOCKERS` | 5.8 | Count blockers (CDG render nếu >0) |

---

## Step 5.8 — Safety Check (CORE-020)

**Mục đích:** Pre-execution safety: collision detection, xref validation, uncommitted changes, deprecated modules (LEGACY_MODE).

**Thực thi (script delegation + INLINE CDG):**

```bash
export LEGACY_MODE  # default: false
PHASE5_S8=$(bash .claude/scripts/wf-fix-bugs/safety-check.sh) || RC=$?
BLOCKERS=$(echo "$PHASE5_S8" | jq -r '.blockers_count')
export BLOCKERS

if [ "${RC:-0}" -eq 5 ]; then
  # E055: blockers detected → CDG render INLINE (orchestrator gọi AskUserQuestion)
  AskUserQuestion: "Phát hiện $BLOCKERS blocker(s) (deprecated modules).
                    Tiếp tục dù có blockers?"
  Options: CONTINUE (chấp nhận risk) / ABORT (dừng pipeline)
  # IF ABORT → update fix-status phase5=failed, exit
  # IF CONTINUE → log decision vào error-ledger (anti-loop guard) + continue Group G
fi
```

4 safety checks:
- **Collision** — fix-plan files có conflict với code hiện tại (CORE-020 Safety Gate)
- **Xref** — REQ-IDs trong fix-plan có trong registry
- **Uncommitted** — git diff phát hiện dirty tree (WARN only)
- **Deprecated** — LEGACY_MODE: fix-plan reference deprecated modules (BLOCKER) — CORE-022

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase5-triage/safety-check.json"
jq -e '.all_pass != null and (.blockers | type == "array")' \
  "$SESSION_DIR/phase5-triage/safety-check.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E055 | Blockers detected (exit 5) | CDG render INLINE — CONTINUE/ABORT |
| E055 | REJECT 2 lần | ESCALATE |
| E035 | Atomic write fail (exit 3) | Retry x1 |

**Cross-ref:** CORE-020 (Pre-Implementation Safety), CORE-022 (Legacy Decisions), CORE-027 (CDG), CORE-034.

---

## Group F POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase5-triage/safety-check.json" && \
jq -e '.all_pass != null and (.blockers | type == "array")' \
  "$SESSION_DIR/phase5-triage/safety-check.json" >/dev/null && \
  echo "Group F PASS" || echo "Group F FAIL"
```

## Next Group

→ Group G Reports + Finalize — đọc [`phase5-triage/G-reports-finalize.md`](G-reports-finalize.md)
