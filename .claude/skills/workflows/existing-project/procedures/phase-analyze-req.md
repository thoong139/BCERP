# Phase Analyze-Req: wf-analyze-requirements (legacy mode)

> Tạo Phase 1 docs với BA + domain experts + naming normalization. `wf-analyze-requirements`
> tự detect legacy mode (CORE-021) và inject context. Sản phẩm: phase1-business/ docs +
> registry.requirements/systems/modules/departments + interface_type.

## PRE-GATE

- Phase Brainstorm completed (`phase_0b_progress.brainstorm == "done"`)
- `test -d .mc-data/docs/phase0-brainstorm`
- Nếu `phase_0b_progress.analyze_requirements == "done"` → SKIP

## Skip Logic

```bash
ANALYZE_DONE=$(jq -r '.phase_0b_progress.analyze_requirements // "pending"' .mc-data/work/existing-project/checkpoint.json)

if [[ "$ANALYZE_DONE" == "done" ]] && test -d .mc-data/docs/phase1-business; then
  echo "⏭ Phase Analyze-Req: Bỏ qua (đã hoàn thành từ run trước)"
  # Chuyển sang phase-define-features
fi
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| ar.1 | Hiển thị: `▶ Phase Analyze-Req (Buoc 0b.2): BA + domain experts + naming normalization` | - | - |
| ar.2 | Verify `.claude/skills/workflow/wf-analyze-requirements/SKILL.md` tồn tại | Read | File exists (else E004) |
| ar.3 | Gọi `Skill("wf-analyze-requirements")` — sub-skill tự detect LEGACY_MODE | Skill | Sub-skill POST-GATE pass |

## POST-GATE

```bash
# 1. Phase 1 docs tồn tại
test -d .mc-data/docs/phase1-business

# 2. Registry có requirements (sub-skill tạo)
test -f .mc-data/docs/_meta/req-registry.json \
  && jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json
# Nếu fail → E012 (registry tồn tại nhưng thiếu data)
```

## Status File Update

```bash
jq '
  .phase_0b_progress.analyze_requirements = "done"
  | .current_step = "define-features"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

```
✅ Phase Analyze-Req hoàn thành
  Phase 1 docs: created
  Requirements: [count]

→ Next: phase-define-features (Buoc 0b.3)
```

Hỏi user xác nhận tiếp tục.

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-analyze-requirements SKILL.md không tồn tại (STOP)
- **E012** — Registry thiếu requirements sau sub-skill chạy
- **E014** — sub-skill fail sau retry

Chi tiết: `_shared.md §Error Handling Reference`.
