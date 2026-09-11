# Phase 6 Group B — Dry-Run Check (Step 6.2)

> **Entry condition:** Group A POST-GATE PASS (Phase 6 marked in_progress).
> **Exit condition:** Branching decision: `$DRY_RUN=true` → skip to Group F+G (END) / `$DRY_RUN=false` → continue Group C.
> **Next (live mode):** [phase6-execute/C-impact-cdg.md](C-impact-cdg.md) (CI Impact + CDG).
> **Next (dry-run):** [phase6-execute/F-report.md](F-report.md) → [phase6-execute/G-finalize.md](G-finalize.md) (skip C, D, E).
>
> **Shared protocols cần thiết:** None.

## Input contract (env vars từ Group A)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$DRY_RUN` | Pipeline state |
| `$TOTAL_ISSUES` | Từ Group A |

## Output contract (env vars truyền sang Group C hoặc F)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `fix-status.phase6 = completed (dry_run)` | 6.2 | Set ONLY nếu DRY_RUN=true (script exit 5) |
| `phase6-execute/fix-report.md` (DRY RUN preview) | 6.2 | Tạo ONLY nếu DRY_RUN=true |
| Branching: continue or END | 6.2 | Orchestrator route theo exit code |

---

## Step 6.2 — Check Dry-Run Mode

**Mục đích:** Nếu `$DRY_RUN=true` → render preview + STOP pipeline. Nếu `$DRY_RUN=false` → continue Group C.

```bash
PHASE6_S3=$(bash .claude/scripts/wf-fix-bugs/dry-run-preview.sh) || RC=$?

if [ "${RC:-0}" -eq 5 ]; then
  # E_DRY_RUN_DONE: preview rendered + fix-status updated → SKIP to Group F+G
  echo "✅ DRY RUN complete — preview tại $SESSION_DIR/phase6-execute/fix-report.md"
  echo "Run lại không có --dry-run để execute thật."
  # Orchestrator: skip Groups C, D, E. Đọc trực tiếp F-report.md → G-finalize.md
  export DRY_RUN_DONE=true
fi
# RC=0 = live mode → tiếp tục Group C
```

Script ghi preview với issues table + estimated impact + atomic update `fix-status.phase6 = completed (dry_run)` nếu DRY_RUN=true.

**VERIFY:**

```bash
if [ "$DRY_RUN" = "true" ]; then
  test -s "$SESSION_DIR/phase6-execute/fix-report.md"
  grep -q "DRY RUN" "$SESSION_DIR/phase6-execute/fix-report.md"
  jq -e '.phases.phase6.status == "completed" and .phases.phase6.reason == "dry_run"' \
    "$SESSION_DIR/fix-status.json"
fi
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E063 | Preview write fail (exit 3) | Retry x1 → escalate |
| E001 | Atomic write fix-status fail (exit 3) | Retry x1 → escalate |

**Cross-ref:** CORE-035, CORE-028.

---

## Group B POST-GATE Verify

```bash
# Branching gate — verify đúng route
if [ "$DRY_RUN" = "true" ]; then
  test -s "$SESSION_DIR/phase6-execute/fix-report.md" && \
  grep -q "DRY RUN" "$SESSION_DIR/phase6-execute/fix-report.md" && \
    echo "Group B PASS (DRY_RUN — skip to Group F+G)" || echo "Group B FAIL"
else
  echo "Group B PASS (live mode — continue Group C)"
fi
```

## Next Group

- **Live mode (DRY_RUN=false):** → Group C CI Impact + CDG — đọc [`phase6-execute/C-impact-cdg.md`](C-impact-cdg.md)
- **Dry-run mode (DRY_RUN=true):** → Group F Phase Report — đọc [`phase6-execute/F-report.md`](F-report.md) (skip C, D, E)
