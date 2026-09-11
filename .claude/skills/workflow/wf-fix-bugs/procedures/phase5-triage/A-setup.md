# Phase 5 Group A — Setup Triage (Step 5.1)

> **Entry condition:** SKILL.md route đến Phase 5 (đọc index `phase5-triage.md` trước → load file này).
> **Exit condition:** Step 5.1 PASS — Phase 4 verified, signals counted, fix-status.phase5 = in_progress, TRACE START appended. HOẶC E005 healthy (RC=5) → SKIP Groups B-G, jump Phase 7.
> **Next:** [phase5-triage/B-aggregate.md](B-aggregate.md) (Aggregate + Process Integrity) — nếu không E005.
> **Next (E005 healthy):** Phase 7 — `procedures/phase7-verify.md` (skip Phase 5+6).
>
> **Shared protocols cần thiết:**
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — Phase 5 error codes E050-E059, E005, E035, E040
> - [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md) — TRACE START pattern (reference)

## Input contract (env vars có sẵn từ Phase 4)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR` | Session root từ Phase 1 |
| `$DRY_RUN`, `$CI_CONTEXT`, `$PROFILE`, `$SCOPE`, `$LEGACY_MODE` | Pipeline state |
| `phase4-find-bugs/lanes/QD*/{static-scan,runtime,llm-scan}/signals.json` | Phase 4 outputs |

## Output contract (env vars truyền sang Group B hoặc Phase 7)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `TOTAL_SIGNALS` | 5.1 | Aggregated signal count từ tất cả lanes |
| `fix-status.phase5 = in_progress` | 5.1 | Atomic update (hoặc completed nếu E005) |
| `e005_healthy` flag | 5.1 | true nếu N=0 → orchestrator route Phase 7 |
| TRACE START event appended | 5.1 | session-log.json events[-1].phase = "phase5" |

---

## Step 5.1 — Setup Triage (PRE-GATE + E005 + TRACE START)

**Mục đích:** Verify Phase 4 completed, count signals từ tất cả lanes, route E005 healthy nếu N=0, mark Phase 5 in_progress.

```bash
PHASE5_S1=$(bash .claude/scripts/wf-fix-bugs/setup-triage.sh) || RC=$?

if [ "${RC:-0}" = "5" ]; then
  # E005 healthy path: N = 0 → jump Phase 7
  echo "✅ E005 HEALTHY: 0 signals → Phase 5+6 skipped, advance Phase 7"
  # Orchestrator: SKIP Groups B-G của Phase 5. Route trực tiếp procedures/phase7-verify.md
  exit 0
fi

TOTAL_SIGNALS=$(echo "$PHASE5_S1" | jq -r '.total_signals')
export TOTAL_SIGNALS
```

Script thực hiện:
1. Verify `phase4.status == "completed"` (E040 nếu fail)
2. Count signals từ tất cả lanes `phase4-find-bugs/lanes/QD*/[stream]/signals.json`
3. IF total=0 → atomic update `phase5.status=completed, e005_healthy=true` + `phase6.status=completed (reason: "skipped — N=0")` → exit 5
4. ELSE → atomic update `phase5.status=in_progress` + APPEND START event vào `session-log.json`

**VERIFY:**

```bash
jq -e '.phases.phase5.status == "in_progress" or .phases.phase5.e005_healthy == true' "$SESSION_DIR/fix-status.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E040 | Phase 4 chưa completed (exit 2) | Dừng — chạy Phase 4 trước |
| E035 | Atomic write fail (exit 3) | Retry x1, kiểm tra lock + quyền ghi |
| E005 | N=0 healthy (exit 5) | Jump Phase 7 (SKIP B-G) |

**Cross-ref:** CORE-011 (Forensic PRE-GATE), CORE-026 (Execution Trace), CORE-034, CORE-035.

---

## Group A POST-GATE Verify

```bash
# Healthy path đã exit 5 → orchestrator route Phase 7 (không check POST-GATE Group A)
# Normal path: phase5 in_progress + TOTAL_SIGNALS > 0
jq -e '.phases.phase5.status == "in_progress"' "$SESSION_DIR/fix-status.json" >/dev/null && \
test -n "$TOTAL_SIGNALS" && test "$TOTAL_SIGNALS" -gt 0 && \
jq -e '.events[-1].phase == "phase5" and .events[-1].event == "START"' \
  "$SESSION_DIR/session-log.json" >/dev/null && \
  echo "Group A PASS" || echo "Group A FAIL"
```

## Next Group

- **Normal path (N > 0):** → Group B Aggregate + PI — đọc [`phase5-triage/B-aggregate.md`](B-aggregate.md)
- **E005 healthy path (N = 0):** → Phase 7 — `procedures/phase7-verify.md` (skip B-G)
