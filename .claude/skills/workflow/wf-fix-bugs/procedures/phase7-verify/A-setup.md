# Phase 7 Group A — Setup Verify (Step 7.1)

> **Entry condition:** SKILL.md route đến Phase 7 (đọc index `phase7-verify.md` trước → load file này).
> **Exit condition:** Step 7.1 PASS — Phase 5/6 verified, E005 detected, phase7-verify/ created, TRACE START appended.
> **Next:** [phase7-verify/B-cqg1.md](B-cqg1.md) (CQG-1 Numeric) nếu E005=false.
> **Next (E005 healthy):** [phase7-verify/D-mobile-dashboard.md](D-mobile-dashboard.md) (skip B + C — không có fixes để verify).
>
> **Shared protocols cần thiết:**
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — Phase 7 codes E060/E070-E075, E001
> - [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md) — TRACE START pattern (reference)

## Input contract (env vars có sẵn từ Phase 5/6)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR` | Session root từ Phase 1 |
| `$DIMS_ARRAY`, `$MOBILE_MODE`, `$PROFILE` | Pipeline state |
| `fix-status.json` | SSOT pipeline state, E005 flag |
| `phase5-triage/{fix-plan.md, issue-registry.json, Phase5-report.md}` | Phase 5 outputs |
| `phase6-execute/fix-report.md` | Phase 6 output (non-E005 only) |

## Output contract (env vars truyền sang Group B hoặc D)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `E005_HEALTHY` | 7.1 | true/false từ setup-verify.sh — orchestrator route theo |
| `ROUTE` | 7.1 | "normal" hoặc "e005_skip" |
| `fix-status.phase7 = in_progress` | 7.1 | Atomic update |
| TRACE START event appended | 7.1 | session-log.json events[-1].phase = "phase7" |
| `phase7-verify/` directory | 7.1 | Created (nếu chưa có) |

---

## Step 7.1 — Setup Verify (PRE-GATE + E005 detect + TRACE START)

**Mục đích:** Verify Phase 5/6 completed, detect E005 healthy path, mark Phase 7 in_progress.

```bash
PHASE7_S1=$(bash .claude/scripts/wf-fix-bugs/setup-verify.sh) || RC=$?

if [ "${RC:-0}" -ne 0 ]; then
  case "$RC" in
    2) echo "E001: Phase 5 chưa completed";;
    4) echo "E001: Inconsistent state (E005 flag invalid)";;
    6) echo "E060: fix-report/issue-registry missing";;
    *) echo "E075 unknown: $RC";;
  esac
  exit "$RC"
fi

E005_HEALTHY=$(echo "$PHASE7_S1" | jq -r '.e005_healthy')
ROUTE=$(echo "$PHASE7_S1" | jq -r '.route')
export E005_HEALTHY ROUTE
```

Script:
1. Verify `phase5.status == "completed"` (E001 nếu fail)
2. Detect `phase5.e005_healthy` flag → route normal vs e005_skip
3. Forensic content check: E005=false → fix-report + issue-registry non-empty; E005=true → Phase5-report tồn tại
4. Atomic update `phase7 = in_progress` + APPEND START event
5. Tạo `phase7-verify/` directory

**VERIFY:**

```bash
jq -e '.phases.phase7.status == "in_progress"' "$SESSION_DIR/fix-status.json"
test -d "$SESSION_DIR/phase7-verify"
jq -e '.events[-1].phase == "phase7" and .events[-1].event == "START"' \
  "$SESSION_DIR/session-log.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E001 | Phase 5 chưa completed (exit 2) | Dừng — chạy Phase 5 trước |
| E001 | Inconsistent state E005 (exit 4) | Dừng — kiểm tra Phase 5 |
| E060 | fix-report/issue-registry missing (exit 6) | Dừng — Phase 6 chưa đầy đủ |
| E075 | Atomic write fail (exit 3) | Retry x1 |

**Cross-ref:** CORE-011 (Forensic PRE-GATE), CORE-002, CORE-026, CORE-035, E005 (Healthy Path).

---

## Group A POST-GATE Verify

```bash
jq -e '.phases.phase7.status == "in_progress"' "$SESSION_DIR/fix-status.json" >/dev/null && \
test -d "$SESSION_DIR/phase7-verify" && \
test -n "$E005_HEALTHY" && \
jq -e '.events[-1].phase == "phase7" and .events[-1].event == "START"' \
  "$SESSION_DIR/session-log.json" >/dev/null && \
  echo "Group A PASS (E005_HEALTHY=$E005_HEALTHY)" || echo "Group A FAIL"
```

## Next Group

- **Normal path (E005_HEALTHY=false):** → Group B CQG-1 Numeric — đọc [`phase7-verify/B-cqg1.md`](B-cqg1.md)
- **E005 healthy path (E005_HEALTHY=true):** → Group D Mobile + Dashboard — đọc [`phase7-verify/D-mobile-dashboard.md`](D-mobile-dashboard.md) (skip B + C — không có fixes để verify)
