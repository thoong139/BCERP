# Phase 6 Group F — Phase Report (Step 6.6)

> **Entry condition (live mode):** Group E POST-GATE PASS (counts extracted, dashboard updated).
> **Entry condition (dry-run mode):** Group B exit 5 (skip C, D, E — preview đã có ở fix-report.md).
> **Exit condition:** `Phase6-report.md` tiếng Việt ≤15 dòng written.
> **Next:** [phase6-execute/G-finalize.md](G-finalize.md) (Finalize state).
>
> **Shared protocols cần thiết:** None (script delegation only).

## Input contract (env vars từ Group E hoặc B/dry-run)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID` | Session identity |
| `$FIXED_COUNT`, `$DEFERRED_COUNT`, `$FAILED_COUNT`, `$FILES_CHANGED` | Live mode: từ Group E. Dry-run: empty/0 |
| `$DRY_RUN` | Pipeline state — script tự detect và render khác |

## Output contract (env vars truyền sang Group G)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `phase6-execute/Phase6-report.md` | 6.6 | Tiếng Việt ≤15 dòng (CORE-028) |

---

## Step 6.6 — Generate Phase6-report.md (CORE-028)

**Mục đích:** Tạo báo cáo tiếng Việt ≤15 dòng tổng kết Phase 6. Script tự branch live vs dry-run.

```bash
export SESSION_ID FIXED_COUNT DEFERRED_COUNT FAILED_COUNT FILES_CHANGED DRY_RUN
PHASE6_S8=$(bash .claude/scripts/wf-fix-bugs/generate-phase6-report.sh) || RC=$?

if [ "${RC:-0}" -ne 0 ]; then
  echo "ERROR: Phase6-report.md generation fail (E035)" >&2
  exit "$RC"
fi
```

Script populate template `templates/phase6-execute/Phase6-report.md` (CORE-031 READ → POPULATE → STRIP `_template_notes` → WRITE) với:
- Status (PASS/FAIL/DRY_RUN), Started/Completed timestamps
- DRY_RUN_OR_LIVE (live|dry-run), CI_IMPACT_DONE (có|không)
- Fixed/Deferred/Failed counts, Files changed
- DOCS_SYNCED count, FIX_REPORT_VALID + DOCS_SYNC_VALID indicators (✓/✗)

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase6-execute/Phase6-report.md"
REPORT_LINES=$(wc -l < "$SESSION_DIR/phase6-execute/Phase6-report.md")
[ "$REPORT_LINES" -le 15 ]
grep -qE "PASS|FAIL|DRY" "$SESSION_DIR/phase6-execute/Phase6-report.md"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E035 | Template missing (exit 2) | Tạo ad-hoc từ fix-report.md |
| E001 | Write fail (exit 3) | Retry x1 → escalate |

**Cross-ref:** CORE-028, CORE-031, CORE-035.

---

## Group F POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase6-execute/Phase6-report.md" && \
REPORT_LINES=$(wc -l < "$SESSION_DIR/phase6-execute/Phase6-report.md") && \
[ "$REPORT_LINES" -le 15 ] && \
grep -qE "PASS|FAIL|DRY" "$SESSION_DIR/phase6-execute/Phase6-report.md" && \
  echo "Group F PASS" || echo "Group F FAIL"
```

## Next Group

→ Group G Finalize — đọc [`phase6-execute/G-finalize.md`](G-finalize.md)
