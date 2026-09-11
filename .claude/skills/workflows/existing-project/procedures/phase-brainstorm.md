# Phase Brainstorm: wf-brainstorm (legacy mode)

> Tạo Phase 0 docs từ extracted data của legacy-scan. `wf-brainstorm` tự detect
> legacy mode (CORE-021: project-context.md > 500 bytes) và inject context từ
> `extracted/`. Output: phase0-brainstorm/ docs + `legacy-decisions.json` (CORE-022).

## PRE-GATE

- Phase Scan completed (`"scan"` trong `phases_completed[]` HOẶC `legacy_pipeline_done == true`)
- `test -f .mc-data/work/legacy-scan/project-context.md && test $(wc -c < ...) -gt 500`
- Nếu `$LEGACY_PIPELINE_DONE == true` AND `$STATUS_FILE.phase_0b_progress.brainstorm == "done"` → SKIP

## Skip Logic

```bash
BRAINSTORM_DONE=$(jq -r '.phase_0b_progress.brainstorm // "pending"' .mc-data/work/existing-project/checkpoint.json)

if [[ "$BRAINSTORM_DONE" == "done" ]] && test -d .mc-data/docs/phase0-brainstorm; then
  echo "⏭ Phase Brainstorm: Bỏ qua (đã hoàn thành từ run trước)"
  # Chuyển sang phase-analyze-req
fi
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| b.1 | Hiển thị: `▶ Phase Brainstorm (Buoc 0b.1): Phase 0 docs từ extracted data` | - | - |
| b.2 | Verify `.claude/skills/workflow/wf-brainstorm/SKILL.md` tồn tại | Read | File exists (else E004) |
| b.3 | Gọi `Skill("wf-brainstorm")` — sub-skill tự detect LEGACY_MODE qua CORE-021 | Skill | Sub-skill POST-GATE pass |

## POST-GATE

```bash
# 1. Phase 0 docs tồn tại
test -d .mc-data/docs/phase0-brainstorm \
  && test -f .mc-data/docs/phase0-brainstorm/P0-01-project-overview.md

# 2. legacy-decisions.json (CORE-022 — REQUIRED cho downstream legacy enforcement)
test -f .mc-data/work/wf-brainstorm/legacy-decisions.json
# Nếu fail → WARNING (không block — graceful degradation theo CORE-022)
```

## Status File Update

```bash
# Đọc deprecated_modules từ legacy-decisions.json (CORE-022)
DEPRECATED_MODULES="[]"
if test -f .mc-data/work/wf-brainstorm/legacy-decisions.json; then
  DEPRECATED_MODULES=$(jq -c '[.modules[] | select(.action=="DEPRECATE") | .id]' \
    .mc-data/work/wf-brainstorm/legacy-decisions.json)
fi

jq --argjson dm "$DEPRECATED_MODULES" '
  .deprecated_modules = $dm
  | .phase_0b_progress.brainstorm = "done"
  | .current_step = "analyze-req"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

```
✅ Phase Brainstorm hoàn thành
  Phase 0 docs: created
  legacy-decisions.json: [created/missing]
  Deprecated modules: [count]

→ Next: phase-analyze-req (Buoc 0b.2)
```

Hỏi user xác nhận tiếp tục.

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-brainstorm SKILL.md không tồn tại (STOP)
- **E014** — sub-skill fail sau retry

Chi tiết: `_shared.md §Error Handling Reference`.
