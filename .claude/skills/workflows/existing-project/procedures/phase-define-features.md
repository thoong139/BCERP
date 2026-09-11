# Phase Define-Features: wf-define-features (legacy mode)

> Tạo Phase 2 feature specs với impl_status inheritance từ impl-status-snapshot.json.
> `wf-define-features` tự detect legacy mode (CORE-021) và seed impl_status từ snapshot
> (1 lần duy nhất theo CORE-022). Sản phẩm: phase2-features/[sys]/[mod]/[feat].md +
> registry.features[] (bao gồm features[].impl_status).

## PRE-GATE

- Phase Analyze-Req completed (`phase_0b_progress.analyze_requirements == "done"`)
- `jq -e '.requirements | length > 0' req-registry.json`
- Nếu `phase_0b_progress.define_features == "done"` → SKIP

## Skip Logic

```bash
DEFINE_DONE=$(jq -r '.phase_0b_progress.define_features // "pending"' .mc-data/work/existing-project/checkpoint.json)

if [[ "$DEFINE_DONE" == "done" ]] && test -d .mc-data/docs/phase2-features; then
  echo "⏭ Phase Define-Features: Bỏ qua (đã hoàn thành từ run trước)"
  # Chuyển sang phase-design
fi
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| df.1 | Hiển thị: `▶ Phase Define-Features (Buoc 0b.3): Feature specs + impl_status inheritance` | - | - |
| df.2 | Verify `.claude/skills/workflow/wf-define-features/SKILL.md` tồn tại | Read | File exists (else E004) |
| df.3 | Gọi `Skill("wf-define-features")` — sub-skill tự seed impl_status từ snapshot (CORE-022) | Skill | Sub-skill POST-GATE pass |

## POST-GATE

```bash
# 1. Phase 2 docs tồn tại (ít nhất 1 feature)
test -d .mc-data/docs/phase2-features \
  && test -n "$(find .mc-data/docs/phase2-features -name '*.md' -type f 2>/dev/null | head -1)"

# 2. Registry có features
jq -e '.features | length > 0' .mc-data/docs/_meta/req-registry.json
# Nếu fail → E012 (registry thiếu features)
```

## Status File Update

```bash
jq '
  .phase_0b_progress.define_features = "done"
  | .current_step = "design"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

```
✅ Phase Define-Features hoàn thành
  Phase 2 docs: created
  Features: [count] (with impl_status inherited)

→ Next: phase-design (Buoc 0b.4)
```

Hỏi user xác nhận tiếp tục.

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-define-features SKILL.md không tồn tại (STOP)
- **E012** — Registry thiếu features sau sub-skill chạy
- **E014** — sub-skill fail sau retry

Chi tiết: `_shared.md §Error Handling Reference`.
