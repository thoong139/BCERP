# Phase Design: wf-design (legacy mode + gap analysis)

> Tạo Phase 3 architecture docs + rebuild registry hoàn chỉnh + gap analysis.
> `wf-design` legacy flow tự detect (CORE-021) và chạy gap analysis tích hợp,
> output: phase3-architecture/ + registry.design_status + gap-report.md +
> action-items.json + interface_type. Đây là phase CUỐI của cluster Buoc 0b →
> sau phase này pipeline_status = COMPLETE.

## PRE-GATE

- Phase Define-Features completed (`phase_0b_progress.define_features == "done"`)
- `jq -e '.features | length > 0' req-registry.json`
- Nếu `phase_0b_progress.design == "done"` → SKIP

## Skip Logic

```bash
DESIGN_DONE=$(jq -r '.phase_0b_progress.design // "pending"' .mc-data/work/existing-project/checkpoint.json)

if [[ "$DESIGN_DONE" == "done" ]] && test -d .mc-data/docs/phase3-architecture; then
  echo "⏭ Phase Design: Bỏ qua (đã hoàn thành từ run trước)"
  # Chuyển sang phase-annotate
fi
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| d.1 | Hiển thị: `▶ Phase Design (Buoc 0b.4): Architecture + registry build + gap analysis` | - | - |
| d.2 | Verify `.claude/skills/workflow/wf-design/SKILL.md` tồn tại | Read | File exists (else E004) |
| d.3 | Gọi `Skill("wf-design")` — sub-skill tự detect LEGACY_MODE và chạy gap analysis | Skill | Sub-skill POST-GATE pass |
| d.4 | Đọc `interface_type` từ registry sau khi sub-skill xong | Bash | Saved to checkpoint |

## POST-GATE

```bash
# 1. Phase 3 docs tồn tại
test -d .mc-data/docs/phase3-architecture

# 2. Registry valid + có requirements
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json
# Nếu fail → E012

# 3. Pipeline COMPLETE — gap analysis đã chạy
test -f .mc-data/work/legacy-scan/ledger.json \
  && jq -e '.pipeline_status == "COMPLETE"' .mc-data/work/legacy-scan/ledger.json
# Nếu fail → E005

# 4. Stakeholder review (G6) — KHÔNG block, chỉ WARNING
test -f .mc-data/docs/phase3-architecture/stakeholder-review.md \
  || echo "WARNING: stakeholder-review.md chưa tạo trong phase3-architecture/"

# 5. legacy-decisions.json (CORE-022) — KHÔNG block
test -f .mc-data/work/wf-brainstorm/legacy-decisions.json \
  || echo "WARNING: legacy-decisions.json không tồn tại — downstream sẽ graceful degradation"
```

## Status File Update

```bash
INTERFACE_TYPE=$(jq -r '.interface_type // "web+mobile"' .mc-data/docs/_meta/req-registry.json)

jq --arg it "$INTERFACE_TYPE" '
  .phase_0b_progress.design = "done"
  | .interface_type = $it
  | .current_step = "annotate"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

```
✅ Phase Design hoàn thành — cluster Buoc 0b kết thúc
  Phase 3 docs: created
  Registry: rebuild với requirements + features + systems + modules
  Gap analysis: completed (gap-report.md)
  interface_type: [web+mobile/api-only/...]
  pipeline_status: COMPLETE

→ Next: phase-annotate (conditional — Buoc 0c)
```

Hỏi user xác nhận tiếp tục.

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-design SKILL.md không tồn tại (STOP)
- **E005** — pipeline không COMPLETE sau sub-skill
- **E012** — Registry thiếu requirements sau sub-skill (rebuild fail)
- **E014** — sub-skill fail sau retry

Chi tiết: `_shared.md §Error Handling Reference`.
