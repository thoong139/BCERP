# Phase Annotate: wf-annotate-code (conditional)

> Inject REQ-ID/FEAT-ID vào existing code files — thiết lập traceability cho dự án legacy.
> SKIP nếu maturity == DOCS_ONLY (không có code) HOẶC không có annotation gaps HOẶC user skip.

## PRE-GATE

- Phase Design completed (`phase_0b_progress.design == "done"`)
- `pipeline_status == COMPLETE` trong ledger.json
- gap analysis đã chạy

## Skip Detection (kiểm tra theo thứ tự — STOP ngay khi gặp điều kiện skip)

```bash
MATURITY_LEVEL=$(jq -r '.maturity.level // "CODE_ONLY"' .mc-data/work/legacy-scan/ledger.json)
HAS_ANNOTATION_GAPS="false"

if test -f .mc-data/work/legacy-scan/gap-report.md; then
  if grep -qi "annotation" .mc-data/work/legacy-scan/gap-report.md; then
    HAS_ANNOTATION_GAPS="true"
  fi
fi
```

| Điều kiện | Action | Skip reason |
|-----------|--------|-------------|
| `MATURITY_LEVEL == "DOCS_ONLY"` | Hiển thị `⏭ Annotate Code: Bỏ qua (DOCS_ONLY — không có code để annotate)` → persist + skip | `docs-only` |
| `HAS_ANNOTATION_GAPS == "false"` | Hiển thị `⏭ Annotate Code: Bỏ qua (không có annotation gaps)` → persist + skip | `no-gaps` |
| Hỏi user: *"Có muốn inject REQ-ID vào code hiện có không? (yes/no)"* | Nếu `no` → `⏭ Annotate Code: Bỏ qua (user skip)` → persist + skip | `user-skip` |

## Persist skip decision (G2)

```bash
SKIP_REASON="docs-only"  # hoặc "no-gaps" | "user-skip"

jq --arg r "$SKIP_REASON" '
  .annotate_skip_reason = $r
  | .phases_skipped += ["annotate"]
  | .current_step = "phase4"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Steps (chỉ chạy khi KHÔNG skip)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| an.1 | Hiển thị: `▶ Phase Annotate: Inject REQ-ID vào existing code` | - | - |
| an.2 | Verify `.claude/skills/workflow/wf-annotate-code/SKILL.md` tồn tại | Read | File exists (else E004) |
| an.3 | Gọi `Skill("wf-annotate-code")` | Skill | Sub-skill POST-GATE pass |

## POST-GATE (chỉ khi không skip)

```bash
test -f .mc-data/work/legacy-scan/annotation-report.md
```

Nếu fail → E003 → retry sub-skill tối đa 3 lần.

## Status File Update (khi không skip)

```bash
jq '
  .annotate_skip_reason = null
  | .phases_completed += ["annotate"]
  | .current_step = "phase4"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

- **Skip:** `⏭ Phase Annotate bỏ qua (lý do: [skip_reason])` → phase4-ux
- **Done:** `✅ Phase Annotate hoàn thành — REQ-ID injected vào code` → hỏi user xác nhận → phase4-ux

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-annotate-code SKILL.md không tồn tại (STOP)
- **E014** — sub-skill fail sau retry

Chi tiết: `_shared.md §Error Handling Reference`.
