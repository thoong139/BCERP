# Phase 5 Group C — Evaluate Violations + CDG Critical (Step 5.4)

> **Entry condition:** Group B POST-GATE PASS (process-violations.json written với CRITICAL/HIGH/LOW counts).
> **Exit condition:** Decision recorded — CONTINUE (counts evaluated) hoặc ABORT (CDG REJECT → pipeline stop).
> **Next:** [phase5-triage/D-spawn-triage.md](D-spawn-triage.md) (Spawn triage agent) — nếu CONTINUE.
>
> **Shared protocols cần thiết:**
> - [`_shared/16-critical-decision-gate.md`](../_shared/16-critical-decision-gate.md) — CDG render pattern + anti-loop guard
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E052

> **⚠ GIỮ INLINE — KHÔNG extract sang script:** CDG render qua AskUserQuestion (CORE-027). User interaction phải INLINE.

## Input contract (env vars từ Group B)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR` | Session root |
| `$CRITICAL`, `$HIGH`, `$LOW` | Counts từ process-violations.json |
| `phase5-triage/process-violations.json` | PI1-PI5 detailed results |

## Output contract (env vars truyền sang Group D)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| Decision recorded | 5.4 | CONTINUE → pipeline tiếp tục Group D / ABORT → stop |
| `phase5-triage/cdg-tokens.json` | 5.4 (nếu critical) | APPEND CDG-PROCESS-INTEGRITY token (init nếu chưa có) |
| `error-ledger.json` | 5.4 (nếu ABORT) | APPEND E052 entry (anti-loop guard) |

---

## Step 5.4 — Evaluate Violations: Severity + CDG Render

**Mục đích:** Đánh giá severity của process violations và render CDG nếu critical.

**Điều kiện:** Step 5.3 PASS hoặc WARN.

**Thực thi (INLINE):**

1. Đọc counts từ env vars (đã có ở Group B Step 5.3):

   ```bash
   echo "Process Integrity: CRITICAL=$CRITICAL, HIGH=$HIGH, LOW=$LOW"
   ```

2. **IF `$CRITICAL > 0`** → E052 hard-stop + CDG render INLINE:

   ```
   AskUserQuestion: "Phát hiện process integrity violations (${CRITICAL} critical, ${HIGH} high).
                     Tiếp tục dù có violations?"
   Options: CONTINUE (chấp nhận risk) / ABORT (dừng pipeline)
   ```

   IF ABORT → **APPEND error-ledger.json** (v10.10.0 fix: anti-loop guard — không append → R9.5 budget reset vô tận):

   ```bash
   {
     jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '{phase:"phase5", error_code:"E052", message:"CDG ABORT — process integrity violations", timestamp:$ts, retry_count:1}'
   } >> "$SESSION_DIR/error-ledger.json" 2>/dev/null || true
   ```

   → update `fix-status.phase5 = failed` → exit. R9.5 sẽ count E052 entries; ≥3 → escalate.

3. **IF `$HIGH > 0` (critical = 0)** → E052 warning + auto-continue (ghi log, không CDG).
4. **IF `$LOW` only / zero** → auto-continue (không CDG).

**VERIFY:**

```bash
# Nếu critical: CDG decision đã ghi vào cdg-tokens.json (init nếu chưa có)
# Nếu không critical: không có cdg-tokens.json change ở Group C
if [ "$CRITICAL" -gt 0 ]; then
  test -s "$SESSION_DIR/phase5-triage/cdg-tokens.json" || \
    echo "WARN: cdg-tokens.json chưa init — Group E sẽ init"
fi
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E052 | CONTINUE selected (critical>0) | Continue Group D với warning logged |
| E052 | ABORT selected (critical>0) | Stop pipeline — update fix-status phase5=failed |

**Cross-ref:** CORE-027 (CDG), CORE-034 (Anti-loop budget E052), Protocol 16 (CDG canonical).

---

## Group C POST-GATE Verify

```bash
# Branching gate — verify đúng route
if [ "$CRITICAL" -gt 0 ]; then
  # CDG đã decision rồi (nếu pipeline còn chạy = CONTINUE)
  echo "Group C PASS (CDG CONTINUE for $CRITICAL critical violations)"
else
  # Auto-continue path
  echo "Group C PASS (no CDG needed, critical=0)"
fi
```

## Next Group

→ Group D Spawn Triage Agent — đọc [`phase5-triage/D-spawn-triage.md`](D-spawn-triage.md)
