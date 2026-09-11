# Evals Section Template

> Template cho Phase 4 khi `$EVAL_STATUS` populated (chỉ hiển thị khi user truyền `--evals`).

```markdown
### Skill Evals Status

| Mục | Giá trị |
|-----|---------|
| Eval Mode | $EVAL_MODE |
| Total Cases | $EVAL_TOTAL |
| Assertions | pass: $EVAL_PASS, fail: $EVAL_FAIL, skip: $EVAL_SKIP, error: $EVAL_ERROR |
| **Eval Verdict** | **$EVAL_VERDICT** |

| # | File | Path |
|---|------|------|
| 1 | eval-results.json | `docs/audit/work/eval-results.json` |
| 2 | eval-results.md | `docs/audit/reports/eval-results.md` |
```

## Placeholders

| Placeholder | Source (từ `$EVAL_STATUS`) |
|-------------|-----------|
| `$EVAL_MODE` | `.mode` ∈ {`stub`, `judge`, `auto`, `real`} |
| `$EVAL_TOTAL`, `$EVAL_PASS`, `$EVAL_FAIL`, `$EVAL_SKIP`, `$EVAL_ERROR` | `.total_cases`, `.pass`, `.fail`, `.skip`, `.error` |
| `$EVAL_VERDICT` | `.verdict` ∈ {`EVAL-CLEAN`, `EVAL-PARTIAL`, `EVAL-NEEDS-REVIEW`, `EVAL-NEEDS-FIX`, `ERROR`} |

## Khi nào render

- User truyền `--evals` flag
- `$EVAL_STATUS` populated sau Phase 3.6
- KHÔNG render khi không có `--evals`
