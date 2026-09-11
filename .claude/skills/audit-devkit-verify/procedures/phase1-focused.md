# Phase 1.F: Focused Cross-Reference (`--skill=<name>` mode) [v2.0]

> Khi `$SCOPE == "skill"`: skip full passes A-D, chạy focused crossref cho 1 skill cụ thể.
> Bao gồm: `_contract.json` cross-ref, output path alignment (00-core.md §4b), downstream/upstream skill references.

## PRE-GATE

- Phase 0 POST-GATE pass
- `$FOCUSED_SKILL` được set (từ `--skill=<name>`)
- Target skill tồn tại trong `$INDEX`

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.F.1 | Xác định target skill path: Glob `.claude/skills/**/$FOCUSED_SKILL/SKILL.md` → nếu không tìm thấy → STOP: "Skill $FOCUSED_SKILL không tồn tại" | Glob | path found |
| 1.F.2 | Đọc target `SKILL.md` + `_contract.json` | Read | Content loaded |
| 1.F.3 | Đọc `.claude/rules/00-core.md` §4b — extract rows liên quan đến target skill (producer hoặc consumer) | Read + Grep | Relevant rows extracted |
| 1.F.4 | Từ `_contract.json.cross_skill_contracts`: identify downstream skills (`produces_for`) + upstream skills (`consumes_from`) | Read | Lists created |
| 1.F.5 | Spawn 1 `cross-reference-auditor` với focused prompt (xem `_shared.md §Template focused crossref`) | Agent | Agent started |
| 1.F.6 | Agent kiểm tra 6 tiêu chí (xem bên dưới) | Agent | Checked |
| 1.F.7 | Thu thập kết quả, parse JSON | Read | findings parsed |
| 1.F.8 | Write `$VERIFY_DIR/findings-crossref-$FOCUSED_SKILL.json` (schema `audit-findings-v1`) | Write | File created |

## Checks (6 tiêu chí)

1. `_contract.json.produces_for` paths = `SKILL.md` output paths (EXACT match)
2. `_contract.json.consumes_from` paths = `SKILL.md` input paths (EXACT match)
3. Output paths trong `SKILL.md` xuất hiện trong 00-core.md §4b
4. Template references trong `SKILL.md` tồn tại trên disk
5. Downstream skill PRE-GATE references target skill outputs
6. Upstream skill POST-GATE produces files target skill expects

## Finding format (focused mode có thêm category/criterion_group)

```jsonc
{
  "id": "F-XRF-[NNN]",
  "severity": "CRITICAL|MAJOR|MINOR",
  "category": "functional|structural",
  "criterion_group": "contract|crossref|path-alignment",
  "file": "[path]",
  "line": 42,
  "criterion": "[criterion ID]",
  "issue": "[mô tả]",
  "fix_type": "AUTO|MANUAL",
  "fix_proposal": "[đề xuất]",
  "evidence": "[bằng chứng]"
}
```

## POST-GATE

- `$VERIFY_DIR/findings-crossref-$FOCUSED_SKILL.json` tồn tại
- JSON valid, schema `audit-findings-v1`
- Update `verify-status.json`: mark `phase1-focused-crossref` completed

## Routing sau Phase 1.F

Chuyển sang `phase2-workflow.md` — nhưng chỉ check workflow handoffs cho target skill + downstream/upstream. Skip Phase 3.5 (không chạy master-plan trong scope focused).

## Errors liên quan

- Skill không tồn tại → STOP với message rõ ràng
- **E006** — Agent timeout → re-spawn 1 lần

Chi tiết: `_shared.md §Error Handling Reference`.
