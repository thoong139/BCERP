# Phase 1 Group E — ISG Fast-Path (Step 1.14)

> **Entry condition:** Group D POST-GATE PASS (`$SESSION_DIR` exists, lock+heartbeat active).
> **Exit condition:** `$DIMS_ARRAY` resolved (≥1 dimension).
> **Next:** [phase1-init/F-wave4.md](F-wave4.md) (Wave 4 Parallel State Init).
>
> **Shared protocols:** None.

## Input contract (env vars từ Group D)

| Variable | Description |
|----------|-------------|
| `$PROFILE` | quick / standard / deep / exhaustive |
| `$SCOPE` | all / module / system |
| `$DIMS_ARRAY` | (optional) Explicit --dims override |
| `$SESSION_DIR` | Session root |

## Output contract (env vars truyền sang Group F)

| Variable | Mô tả |
|----------|------|
| `$DIMS_ARRAY` | Space-separated list (e.g., `QD1 QD2 QD5 QD9 QD10`) |
| `$DIMS_COUNT` | Number of dims |

---

## Step 1.14 — Profile → Dimensions Resolution (delegated to script)

> **v10.12.0 fast-path:** Bash hardcoded lookup ~5ms thay vì Python ISG spawn ~200-500ms cold start.
>
> **Lý do bypass an toàn:** Phase 1 chưa có scan data → ISG analyze chỉ return profile defaults hardcoded trong `isg_recommender.PROFILE_DIMENSIONS`. REAL ISG recommendation chạy ở Phase 3 sau scan.
>
> **Escape hatch:** `MCV3_FIX_BUGS_FORCE_ISG=1` → force Python ISG (legacy/dev path).

```bash
if [ -n "$DIMS_ARRAY" ]; then
  # Explicit --dims → dùng trực tiếp
  echo "Using explicit dimensions: $DIMS_ARRAY"
else
  # Fast-path bash lookup
  DIMS_ARRAY=$(bash .claude/scripts/wf-fix-bugs/phase1-isg-fastpath.sh \
                 --profile="$PROFILE" \
                 --session-dir="$SESSION_DIR" \
                 --scope="$SCOPE")

  if [ -z "$DIMS_ARRAY" ]; then
    echo "E030: ISG resolve failed — final fallback standard"
    DIMS_ARRAY="QD1 QD2 QD5 QD9 QD10"
  fi
fi

DIMS_COUNT=$(echo "$DIMS_ARRAY" | wc -w)
echo "DIMS_ARRAY=$DIMS_ARRAY ($DIMS_COUNT dimensions)"
```

**Hardcoded defaults (đồng bộ với isg_recommender.PROFILE_DIMENSIONS):**

| Profile | Dimensions |
|---------|-----------|
| `quick` | QD1 QD5 |
| `standard` | QD1 QD2 QD5 QD9 QD10 |
| `deep` | QD1 QD2 QD5 QD6 QD3 QD9 QD10 QD11 |
| `exhaustive` | QD1 QD2 QD3 QD4 QD5 QD6 QD7 QD8 QD9 QD10 QD11 |

**On Failure:**

| Lỗi | Code | Hành động |
|------|------|-----------|
| Profile lạ + Python fallback fail | E030 | Final fallback standard defaults |
| DIMS_ARRAY empty sau fallback | E030 | STOP — không thể continue |

**Cross-ref:** `_shared/isg/` (Python ISG — chỉ chạy Phase 3 hoặc khi `MCV3_FIX_BUGS_FORCE_ISG=1`), `scripts/wf-fix-bugs/phase1-isg-fastpath.sh`.

---

## Group E POST-GATE Verify

```bash
test -n "$DIMS_ARRAY" && [ "$DIMS_COUNT" -gt 0 ] && \
  echo "Group E PASS" || echo "Group E FAIL"
```

## Next Group

→ Group F Wave 4 Parallel State Init — đọc [`phase1-init/F-wave4.md`](F-wave4.md)
