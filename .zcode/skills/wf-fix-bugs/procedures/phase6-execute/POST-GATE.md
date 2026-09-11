# Phase 6 POST-GATE + Error Reference

> **Entry condition:** Group G PASS (fix-status.phase6 = completed + TRACE COMPLETE).
> **Exit condition:** All T1-T5 checks PASS → advance Phase 7.
> **Next:** Phase 7 — `procedures/phase7-verify.md`.

## POST-GATE T1-T5 Validation

```bash
# T1 — File existence (hoặc DRY_RUN preview)
test -s "$SESSION_DIR/phase6-execute/fix-report.md"             || echo "FAIL T1: fix-report.md"
test -s "$SESSION_DIR/phase6-execute/docs-sync-report.json"     || echo "FAIL T1: docs-sync-report.json"

# T2 — fix-report.md có section headers
grep -qE "^## " "$SESSION_DIR/phase6-execute/fix-report.md" || echo "FAIL T2: missing section headers"

# T3 — docs-sync-report.json valid JSON + .files_synced >= 0
jq -e '.files_synced >= 0' "$SESSION_DIR/phase6-execute/docs-sync-report.json" \
  || echo "FAIL T3: docs-sync-report invalid"

# T4 — fix-report.md có keyword fix-result
grep -qiE "fixed|resolved|repaired|dry|deferred|failed" "$SESSION_DIR/phase6-execute/fix-report.md" \
  || echo "FAIL T4: no fix-result keyword"

# T5 — Dashboard updated + fix-status.phase6 == completed
test -s "$SESSION_DIR/bug-dashboard.md"                              || echo "FAIL T5: bug-dashboard"
jq -e '.phases.phase6.status == "completed"' "$SESSION_DIR/fix-status.json" \
  || echo "FAIL T5: phase6 not completed"
```

**Tất cả T1-T5 PASS → Phase 6 hoàn tất, advance sang Phase 7.**

## Phase 6 Report Summary

Sau POST-GATE pass, `phase6-execute/Phase6-report.md` đã được tạo (qua Group F) với:

- Status (PASS/FAIL/DRY_RUN), Started/Completed timestamps
- DRY_RUN_OR_LIVE (live|dry-run), CI_IMPACT_DONE (có|không)
- Fixed/Deferred/Failed counts, Files changed
- DOCS_SYNCED count, FIX_REPORT_VALID + DOCS_SYNC_VALID indicators (✓/✗)

## On Failure — Quick Reference

| Code | Xử lý |
|------|-------|
| E001 | Atomic Write fail → Retry x1 → escalate AskUserQuestion |
| E050 | Phase 5 not done → Dừng, chạy Phase 5 trước |
| E055 | CDG tokens pending/rejected → Dừng, user resolve CDG ở Phase 5 |
| E060 | Execute agent spawn fail → Re-spawn x1 → escalate (Re-run/Skip/Cancel) |
| E061 | fix-report missing/broken/invalid → Re-generate → escalate |
| E062 | CI impact analysis fail → Fallback Grep, WARN, continue |
| E063 | Dry-run preview render fail → Retry x1 → Dừng |
| E064 | docs-sync-report invalid JSON → Re-read agent output → escalate |
| E065 | Dashboard update fail → Retry x1 → WARN (non-critical) |
| EDLG | Sub-skill incomplete → Re-spawn x1 → escalate |

**Auto-Fix Budget:** Max 3 retries tổng cho Phase 6 (CORE-034). Sau 3 lần → STOP, AskUserQuestion: "Re-run / Skip (risky) / Cancel".

## Resume Logic

| Trạng thái | Hành động |
|------------|-----------|
| `fix-status.phase6` không có | Bắt đầu từ Group A (Step 6.1) |
| `phase6.status = "completed"` | Skip → advance Phase 7 |
| `phase6.status = "in_progress"` | Check outputs hiện có → resume từ group tiếp theo |
| `phase6.status = "failed"` | Đọc error-ledger → quyết định re-run hoặc skip |
| `fix-report.md` tồn tại nhưng phase6 chưa complete | Resume từ Group E (validate + dashboard) |
| Stale lock (>30 min) | Auto-release → re-validate PRE-GATE → resume |
| `DRY_RUN=true` đã chạy trước | Skip — Phase 6 đã completed (dry_run) |

```bash
PHASE6_STATUS=$(jq -r '.phases.phase6.status // "not_started"' "$SESSION_DIR/fix-status.json")
case "$PHASE6_STATUS" in
  "completed") echo "Phase 6 completed → advance Phase 7" ;;
  "in_progress")
    if [ -s "$SESSION_DIR/phase6-execute/fix-report.md" ]; then
      echo "fix-report exists → resume Group G (Step 6.7)"
    else
      echo "No fix-report → re-spawn Group D-E (Steps 6.4-6.5)"
    fi ;;
  "failed") echo "Check error-ledger.json" ;;
  *) echo "Start Phase 6 from Group A (Step 6.1)" ;;
esac
```

## Next Phase

Phase 7 — `procedures/phase7-verify.md` (POST-GATE toàn pipeline, fix-impact.json cross-skill artifact, CQG verification).
