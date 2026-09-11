# Phase 5 Group E — Validate + CDG Pre-Execute Handoff (Steps 5.6 + 5.7)

> **Entry condition:** Group D POST-GATE PASS (triage agent outputs written).
> **Exit condition:** POST-GATE T1-T4 PASS + CDG-PRE-EXECUTE token APPENDED với decision ACCEPT.
> **Next:** [phase5-triage/F-safety-check.md](F-safety-check.md) (Safety check + INLINE CDG nếu blockers).
>
> **Shared protocols cần thiết:**
> - [`_shared/20-cdg-tokens.md`](../_shared/20-cdg-tokens.md) — CDG-PRE-EXECUTE token schema cdg-tokens-v1
> - [`_shared/16-critical-decision-gate.md`](../_shared/16-critical-decision-gate.md) — CDG render + anti-loop (REJECT 2 lần)

> **⚠ GIỮ INLINE — KHÔNG extract sang script (Step 5.7):** CDG render qua AskUserQuestion (CORE-027). User decision phải INLINE.

## Input contract (env vars từ Group D)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$PROFILE` | Pipeline state |
| `phase5-triage/{bug-triage.md, fix-plan.md, fix-log.json, issue-registry.json}` | Triage outputs |

## Output contract (env vars truyền sang Group F)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `TOTAL_FAILS` | 5.6 | Sau validate-triage-outputs.sh (T1-T4 fails) |
| `phase5-triage/cdg-tokens.json` | 5.7 | APPEND CDG-PRE-EXECUTE token (decision recorded) |
| `CRITICAL_COUNT`, `HIGH_COUNT`, `TOTAL` | 5.7 | Counts cho CDG render |

---

## Step 5.6 — POST-GATE Validation for Triage Outputs

**Mục đích:** Validate triage agent outputs qua tiered T1-T4 (CORE-012).

```bash
PHASE5_S6=$(bash .claude/scripts/wf-fix-bugs/validate-triage-outputs.sh) || RC=$?
TOTAL_FAILS=$(echo "$PHASE5_S6" | jq -r '.total_fails')

if [ "${RC:-0}" -ne 0 ]; then
  echo "POST-GATE FAIL: $TOTAL_FAILS failure(s) — re-spawn triage agent x1 (E053)"
  # Auto-fix: re-spawn Group D (Step 5.5) với extra context
  # Sau retry x1 vẫn fail → ESCALATE E054
fi
export TOTAL_FAILS
```

T1-T4 checks:
- **T1** File Existence: bug-triage.md, fix-plan.md, fix-log.json, issue-registry.json
- **T2** Structure: JSON shape + markdown headers
- **T3** Content Depth: bug-triage ≥10 dòng, fix-plan ≥15 dòng
- **T4** Cross-Reference: registry count consistency

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E053 | T1-T3 fail | Re-populate template / re-spawn Group D x1 |
| E053 | T4 fail | WARN — không block (discrepancy acceptable) |
| E054 | Budget hết (3 retries) | ESCALATE: re-run / skip / cancel |

---

## Step 5.7 — CDG Pre-Execute Handoff (INLINE)

**Mục đích:** Render kế hoạch sửa lỗi và yêu cầu user ACCEPT/REJECT trước Phase 6.

**Thực thi (INLINE):**

1. Tổng hợp summary:
   ```bash
   # v10.10.0 fix: đọc từ issue-registry.json (structured) thay vì grep -c trên
   # bug-triage.md. Trước v10.10.0, grep -c đếm số DÒNG chứa "critical" thay vì
   # số ISSUES có severity=critical → số liệu sai nếu 1 dòng tóm tắt "3 critical".
   CRITICAL_COUNT=$(jq '[.issues[]? | select((.severity // "" | ascii_upcase) == "CRITICAL")] | length' "$SESSION_DIR/phase5-triage/issue-registry.json" 2>/dev/null || echo 0)
   HIGH_COUNT=$(jq '[.issues[]? | select((.severity // "" | ascii_upcase) == "HIGH")] | length' "$SESSION_DIR/phase5-triage/issue-registry.json" 2>/dev/null || echo 0)
   TOTAL=$(jq '.total_issues' "$SESSION_DIR/phase5-triage/issue-registry.json")
   export CRITICAL_COUNT HIGH_COUNT TOTAL
   ```

2. AskUserQuestion (INLINE — orchestrator gọi tool trực tiếp):
   ```
   "Kế hoạch sửa lỗi đã sẵn sàng.

   Tổng: $TOTAL issues
   Critical: $CRITICAL_COUNT | High: $HIGH_COUNT | Medium/Low: còn lại

   Tiếp tục thực thi Phase 6 (Execute)?"
   Options: ACCEPT / REJECT (sửa plan) / CANCEL
   ```

3. APPEND token vào `cdg-tokens.json` (giữ schema cdg-tokens-v1):

   ```bash
   STATUS_VAL=$([ "$DECISION" = "ACCEPT" ] && echo "accepted" || echo "rejected")
   jq --arg gate "CDG-PRE-EXECUTE" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg decision "$DECISION" --arg status "$STATUS_VAL" \
      --argjson issues_total "$TOTAL" --arg profile "$PROFILE" \
      '.tokens += [{gate: $gate, timestamp: $ts, decision: $decision, status: $status, issues_total: $issues_total, profile: $profile}]' \
      "$SESSION_DIR/phase5-triage/cdg-tokens.json" > "$SESSION_DIR/phase5-triage/cdg-tokens.json.tmp.$$" \
      && jq '.' "$SESSION_DIR/phase5-triage/cdg-tokens.json.tmp.$$" > /dev/null \
      && mv "$SESSION_DIR/phase5-triage/cdg-tokens.json.tmp.$$" "$SESSION_DIR/phase5-triage/cdg-tokens.json"
   ```

4. Anti-loop: REJECT 2 lần → E054 ESCALATE.

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase5-triage/cdg-tokens.json"
jq -e '(.tokens | length) > 0 and (.tokens[-1].gate == "CDG-PRE-EXECUTE")' \
  "$SESSION_DIR/phase5-triage/cdg-tokens.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E054 | REJECT 1-2 lần | Cho phép sửa fix-plan — re-run triage hoặc chỉnh tay |
| E054 | REJECT lần 3 | ESCALATE: re-run / skip / cancel |
| E054 | CANCEL | Dừng pipeline — update fix-status phase5=failed |

**Cross-ref:** CORE-027 (CDG), CORE-012 (POST-GATE T1-T4), CORE-034 (Anti-loop), Protocol 16 (CDG canonical).

---

## Group E POST-GATE Verify

```bash
test "$TOTAL_FAILS" -eq 0 && \
test -s "$SESSION_DIR/phase5-triage/cdg-tokens.json" && \
jq -e '.tokens[-1].gate == "CDG-PRE-EXECUTE" and .tokens[-1].status == "accepted"' \
  "$SESSION_DIR/phase5-triage/cdg-tokens.json" >/dev/null && \
  echo "Group E PASS" || echo "Group E FAIL"
```

## Next Group

→ Group F Safety Check — đọc [`phase5-triage/F-safety-check.md`](F-safety-check.md)
