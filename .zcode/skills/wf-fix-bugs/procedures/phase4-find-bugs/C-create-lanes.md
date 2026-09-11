# Phase 4 Group C — Create Lane Directories (Step 4.4)

> **Entry condition:** Group A POST-GATE PASS + (Group B POST-GATE PASS OR `PW_LANE_COUNT == 0`).
> **Exit condition:** N × 5 subdirs created + N × `lane-status.json` populated từ template.
> **Next:** [phase4-find-bugs/D-render-verify.md](D-render-verify.md) (Render Lane Prompts + Verify).
>
> **Shared protocols cần thiết:**
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E035 (atomic write fail)

## Input contract (env vars từ Group A/B)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID` | Pipeline state |
| `$DIMS_ARRAY` | Refined sau Group B (browser dims có thể đã loại) |

## Output contract (env vars truyền sang Group D)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `phase4-find-bugs/lanes/QD{n}-{slug}/` | 4.4 | 5 subdirs/lane: `raw/`, `evidence/`, `static-scan/`, `runtime/`, `llm-scan/` |
| `phase4-find-bugs/lanes/QD{n}-{slug}/lane-status.json` | 4.4 | Từ template `templates/phase4-find-bugs/lane-status.json` với `.status="pending"` |
| `$LANES_CREATED` | 4.4 | Số lượng lanes created thành công |
| `$TOTAL_DIMS` | 4.4 | Số lượng dimensions trong DIMS_ARRAY |

---

## Step 4.4 — Create Lane Directories (create-lane-dirs.sh)

**Mục đích:** Tạo cấu trúc 5 subdirectories + populate `lane-status.json` từ template (CORE-031) cho MỖI dim trong `$DIMS_ARRAY` (đã được refine bởi Group B nếu user skip browser lanes).

**Signal Directory Structure (anti-overwrite per lane):**

```
lanes/QD9-runtime-health/
├── raw/                          ← Per-probe raw outputs + resume checkpoint
├── evidence/                     ← Screenshots, HAR, console logs (Playwright)
├── static-scan/signals.json      ← writer: static probes
├── runtime/signals.json          ← writer: runtime probes (Playwright)
├── llm-scan/signals.json         ← writer: LLM probes
├── lane-status.json              ← lane-state-v1 (init từ template)
└── QD9-runtime-health-report.md  ← từ template QD-report.md (lane agent sẽ tạo)
```

**Thực thi:**

```bash
export SESSION_DIR SESSION_ID DIMS_ARRAY

PHASE4_S4=$(bash .claude/scripts/wf-fix-bugs/create-lane-dirs.sh)

LANES_CREATED=$(echo "$PHASE4_S4" | jq -r '.lanes_created')
TOTAL_DIMS=$(echo "$PHASE4_S4" | jq -r '.total_dims')

echo "$PHASE4_S4" | jq -e '.status == "ok"' \
  || { echo "WARN: $LANES_CREATED/$TOTAL_DIMS lanes created (status: $(echo "$PHASE4_S4" | jq -r '.status'))" >&2; }

export LANES_CREATED TOTAL_DIMS
```

**VERIFY:**

```bash
# Verify per-lane: 5 subdirs + lane-status.json với .status="pending"
for dim in $DIMS_ARRAY; do
  for subdir in raw evidence static-scan runtime llm-scan; do
    test -d "$SESSION_DIR/phase4-find-bugs/lanes/$dim/$subdir" \
      || { echo "FAIL: missing $dim/$subdir"; exit 1; }
  done
  test -s "$SESSION_DIR/phase4-find-bugs/lanes/$dim/lane-status.json" \
    || { echo "FAIL: missing $dim/lane-status.json"; exit 1; }
  jq -e '.status == "pending"' "$SESSION_DIR/phase4-find-bugs/lanes/$dim/lane-status.json" \
    || { echo "FAIL: $dim/lane-status.json not pending"; exit 1; }
done
echo "All $LANES_CREATED/$TOTAL_DIMS lane directories ready"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E035 | Template `lane-status.json` không tồn tại (script exit 2) | Verify `templates/phase4-find-bugs/lane-status.json` |
| E035 | mkdir/write fail (script exit 3) | Retry x1 — kiểm tra disk + quyền |
| E001 | Env vars thiếu (script exit 1) | Re-export SESSION_DIR, SESSION_ID, DIMS_ARRAY |

**Cross-ref:** CORE-031 (Template Usage Rule), CORE-035 (Atomic Write).

---

## Group C POST-GATE Verify

```bash
[ "$LANES_CREATED" = "$TOTAL_DIMS" ] && [ "$LANES_CREATED" -gt 0 ] \
  && echo "Group C PASS ($LANES_CREATED/$TOTAL_DIMS lanes)" \
  || echo "Group C FAIL ($LANES_CREATED/$TOTAL_DIMS lanes — check error-ledger)"
```

## Next Group

→ Group D Render + Verify Lane Prompts — đọc [`phase4-find-bugs/D-render-verify.md`](D-render-verify.md)
