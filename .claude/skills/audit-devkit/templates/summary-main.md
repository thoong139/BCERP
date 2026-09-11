# Summary Main Template

> Template cho Phase 4 main summary. Placeholders: `$PIPELINE_STAGES`, `$SCOPE`, `$FIX_MODE`, `$COMPONENT_COUNT`, `$FINDING_TOTAL`, `$CRIT_FUNC_N`, `$CRIT_STRUCT_N`, `$MAJ_N`, `$MIN_N`, `$FIX_APPLIED`, `$FIX_ATTEMPTED`, `$MANUAL_N`, `$VERDICT_BEFORE`, `$VERDICT_AFTER`, `$SESSION_ID`.

```markdown
## /audit-devkit Pipeline Hoàn Tất!

| Mục | Giá trị |
|-----|---------|
| Pipeline | $PIPELINE_STAGES |
| Scope | $SCOPE |
| Session | $SESSION_ID |
| Fix mode | $FIX_MODE |
| Components scanned | $COMPONENT_COUNT |
| Total findings | $FINDING_TOTAL (CRITICAL-func: $CRIT_FUNC_N, CRITICAL-struct: $CRIT_STRUCT_N, MAJOR: $MAJ_N, MINOR: $MIN_N) |
| Auto-fixed | $FIX_APPLIED / $FIX_ATTEMPTED attempted |
| Manual required | $MANUAL_N |
| **Verdict** | **$VERDICT_BEFORE** → **$VERDICT_AFTER** |

### Output Files

> Mỗi sub-skill output vào directory riêng với session-id. Session path prefix: `.mc-data/work/audit-devkit-{scan,verify,fix}/$SESSION_ID/`.

| # | File | Path |
|---|------|------|
| 1 | audit-index.json | `.mc-data/work/audit-devkit-scan/$SESSION_ID/` |
| 2 | audit-scan-result.json | `.mc-data/work/audit-devkit-scan/$SESSION_ID/` |
| 3 | audit-verified-result.json | `.mc-data/work/audit-devkit-verify/$SESSION_ID/` |
| 4 | fix-log.json | `.mc-data/work/audit-devkit-fix/$SESSION_ID/` |
| 5 | devkit-audit-[date].md | `.mc-data/work/audit-devkit-verify/reports/` |
| 6 | devkit-audit-fix-[date].md | `.mc-data/work/audit-devkit-fix/reports/` |
```

## Conditional Sections

| Mode | Template modifications |
|------|----------------------|
| `--no-fix` | Xóa dòng "Auto-fixed" + chỉ hiển thị 1 verdict (pre-fix). Thêm: "Để auto-fix, chạy `/audit-devkit --fix-only`" |
| `--scan-only` | Chỉ hiển thị `Components scanned` + `Total findings`, không có verdict, không có "Auto-fixed" |
| `--quick` | Như `--scan-only`, thêm note "Structural scan only — lightweight mode" |
| `--master-plan` | Skip toàn bộ main table. Chỉ render section Master Plan (xem `summary-masterplan-section.md`) |
| `--fix-only` | Hiển thị "Verdict (before fix) → Verdict (after fix)" + fix counts. Skip "Components scanned" |
| `--evals` | Append evals section (xem `summary-evals-section.md`) sau main table |
