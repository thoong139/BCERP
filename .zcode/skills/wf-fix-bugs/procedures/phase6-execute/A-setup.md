# Phase 6 Group A — Setup Execute (Step 6.1)

> **Entry condition:** SKILL.md route đến Phase 6 (đọc index `phase6-execute.md` trước → load file này).
> **Exit condition:** Step 6.1 PASS — Phase 5 verified, CDG tokens all accepted, fix-status.phase6 = in_progress, TRACE START appended.
> **Next:** [phase6-execute/B-dry-run.md](B-dry-run.md) (Dry-Run check + branching).
>
> **Shared protocols cần thiết:**
> - [`_shared/20-cdg-tokens.md`](../_shared/20-cdg-tokens.md) — Token aggregation (verify all accepted from 3 paths)

## Input contract (env vars có sẵn từ Phase 5)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR` | Session root từ Phase 1 |
| `$CI_CONTEXT`, `$DRY_RUN`, `$PROFILE`, `$INTERFACE_TYPE` | Pipeline state |
| `phase5-triage/{fix-plan.md, issue-registry.json, bug-triage.md, cdg-tokens.json, fix-log.json}` | Phase 5 outputs |

## Output contract (env vars truyền sang Group B)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `TOTAL_ISSUES` | 6.1 | Từ setup-execute.sh output |
| `fix-status.phase6 = in_progress` | 6.1 | Atomic update |
| TRACE START event appended | 6.1 | session-log.json events[-1].phase = "phase6" |

---

## Step 6.1 — Setup Execute (PRE-GATE + CDG verify + TRACE START)

**Mục đích:** Verify Phase 5 completed + tất cả CDG tokens accepted + fix-plan tồn tại, mark Phase 6 in_progress.

```bash
PHASE6_S1=$(bash .claude/scripts/wf-fix-bugs/setup-execute.sh) || RC=$?

if [ "${RC:-0}" -ne 0 ]; then
  case "$RC" in
    2) echo "E050: Phase 5 chưa completed";;
    5) echo "E055: CDG tokens có pending/rejected";;
    6) echo "E061: TOTAL_ISSUES = 0 logic error";;
    *) echo "E001/E003 unknown error: $RC";;
  esac
  exit "$RC"
fi

TOTAL_ISSUES=$(echo "$PHASE6_S1" | jq -r '.total_issues')
export TOTAL_ISSUES
```

Script thực hiện:
1. Verify `phase5.status == "completed"` (E050 nếu fail)
2. Verify `fix-plan.md`, `issue-registry.json`, `cdg-tokens.json` non-empty
3. Verify `total_issues > 0` (E061 logic error nếu = 0)
4. Verify tất cả CDG tokens `status == "accepted"` (E055 nếu pending) — **AGGREGATE từ cả 3 paths**: `phase1-init/cdg-tokens.json` (stub), `phase4-find-bugs/cdg-tokens.json` (E090/E090b browser CDG), `phase5-triage/cdg-tokens.json` (CDG-PRE-EXECUTE)
5. Atomic update `fix-status.phase6 = in_progress` + APPEND START event

**VERIFY:**

```bash
jq -e '.phases.phase6.status == "in_progress"' "$SESSION_DIR/fix-status.json"
jq -e '.events[-1].phase == "phase6" and .events[-1].event == "START"' "$SESSION_DIR/session-log.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E050 | Phase 5 chưa completed (exit 2) | Dừng — chạy Phase 5 trước |
| E055 | CDG tokens pending/rejected (exit 5) | Dừng — user resolve CDG ở Phase 5 |
| E061 | TOTAL_ISSUES = 0 (exit 6) | Dừng — lỗi logic, kiểm tra Phase 5 flow |
| E001 | Atomic write fail (exit 3) | Retry x1 → escalate |

**Cross-ref:** CORE-011, CORE-027 (CDG), CORE-034, CORE-035, CORE-002.

---

## Group A POST-GATE Verify

```bash
jq -e '.phases.phase6.status == "in_progress"' "$SESSION_DIR/fix-status.json" >/dev/null && \
test -n "$TOTAL_ISSUES" && test "$TOTAL_ISSUES" -gt 0 && \
jq -e '.events[-1].phase == "phase6" and .events[-1].event == "START"' \
  "$SESSION_DIR/session-log.json" >/dev/null && \
  echo "Group A PASS" || echo "Group A FAIL"
```

## Next Group

→ Group B Dry-Run check — đọc [`phase6-execute/B-dry-run.md`](B-dry-run.md)
