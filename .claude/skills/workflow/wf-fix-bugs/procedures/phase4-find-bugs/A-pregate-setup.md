# Phase 4 Group A — PRE-GATE + Init + Load PW Metadata (Steps 4.1+4.2)

> **Entry condition:** Phase 3 completed (`fix-status.phases.phase3.status == "completed"`).
> **Exit condition:** `fix-status.phases.phase4.status = "in_progress"` + `DIMS_ARRAY` + `PW_LANE_COUNT` populated.
> **Next:** [phase4-find-bugs/B-browser-cdg.md](B-browser-cdg.md) (Browser CDG) nếu `PW_LANE_COUNT > 0`, hoặc [phase4-find-bugs/C-create-lanes.md](C-create-lanes.md) nếu skip.
>
> **Shared protocols cần thiết:**
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E030, E035, E044, E001
> - [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md) — TRACE START pattern (via setup-lanes.sh)

## Input contract (env vars từ Phase 3)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR` | Session root từ Phase 1 |
| `$PROFILE`, `$SCOPE`, `$NAME` | Pipeline state |
| `phase3-plan/dimension-plan.json` | Routing table + `needs_playwright` per dim |
| `phase3-plan/work-plan.json` | Execution mode + Playwright config |

## Output contract (env vars truyền sang Group B/C)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `$DIMS_ARRAY` | 4.2 | Space-separated list `QD{n}-{kebab-name}` (vd: `QD1-functional QD3-security`) |
| `$DIMS_COUNT` | 4.2 | Số lượng dimensions |
| `$PW_LANE_COUNT` | 4.2 | Số lượng dims có `needs_playwright=true` |
| `$PW_DIMS` | 4.2 | Subset DIMS_ARRAY chỉ chứa PW dims (cho Group E reference) |
| `fix-status.phases.phase4.status` | 4.2 | `"in_progress"` |
| `session-log.json` | 4.2 | APPEND `{phase:4, event:"START"}` |

---

## Step 4.1 — PRE-GATE: Verify Phase 3 Complete

**Mục đích:** Forensic PRE-GATE (CORE-011) — Phase 3 completed + dimension-plan hợp lệ.

**Thực thi:**

```bash
test -s "$SESSION_DIR/phase3-plan/dimension-plan.json"
jq -e '.phases.phase3.status == "completed"' "$SESSION_DIR/fix-status.json"
jq -e '.dimensions | length > 0' "$SESSION_DIR/phase3-plan/dimension-plan.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E030 | dimension-plan.json missing/empty | Dừng — Phase 3 chưa completed |
| E030 | phase3.status ≠ "completed" | Dừng — chạy Phase 3 trước |
| E030 | dimensions array rỗng | Dừng — không có dim để dispatch |

**Cross-ref:** CORE-002 (No skip phases), CORE-011 (Forensic PRE-GATE), CORE-033 (CI-First), CORE-034 (Error codes).

---

## Step 4.2 — Init + Load PW Metadata (gộp v10.6 — setup-lanes.sh)

**Mục đích:** Thực hiện **2 logical sub-steps trong 1 atomic call** qua `scripts/wf-fix-bugs/setup-lanes.sh`:

1. **TRACE START**: Atomic update `fix-status.json` (`phase4.status = "in_progress"`) + APPEND START event
2. **Load Per-Dim PW Metadata**: Build `DIMS_ARRAY` (slug `QD{n}-{kebab-name}`) + đếm `PW_LANE_COUNT` từ `dimension-plan.json .dimensions[].needs_playwright`. Verify lock script tồn tại nếu PW_LANE_COUNT > 0.

**Thực thi:**

```bash
export SESSION_DIR PROFILE SCOPE

PHASE4_S1=$(bash .claude/scripts/wf-fix-bugs/setup-lanes.sh)

DIMS_ARRAY=$(echo "$PHASE4_S1" | jq -r '.dims_array')
DIMS_COUNT=$(echo "$PHASE4_S1" | jq -r '.dims_count')
PW_LANE_COUNT=$(echo "$PHASE4_S1" | jq -r '.pw_lane_count')
PW_DIMS=$(echo "$PHASE4_S1" | jq -r '.pw_dims')

echo "Phase 4 dispatch: $DIMS_COUNT total lanes, $PW_LANE_COUNT need Playwright"
export DIMS_ARRAY DIMS_COUNT PW_LANE_COUNT PW_DIMS
```

**Lưu ý bash word-splits:** Bash word-splits theo IFS (space). Tên dim chứa space ("Functional Correctness") được kebab-case trong script trước khi join → `for dim in $DIMS_ARRAY` an toàn. DIM_ID lấy lại bên trong loop: `DIM_ID="${dim%%-*}"`.

**VERIFY:**

```bash
jq -e '.phases.phase4.status == "in_progress"' "$SESSION_DIR/fix-status.json"
test "$DIMS_COUNT" -gt 0
echo "$PHASE4_S1" | jq -e '.status == "ok"'
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E030 | Script exit 2 (dimension-plan missing hoặc dim thiếu `needs_playwright`) | Re-run Phase 3 (chưa migrate v10.3+) |
| E035 | Script exit 3 (atomic write fail) | Retry x1 — kiểm tra lock + quyền ghi |
| E044 | `global-rw-lock.sh` missing (có PW lane) | Verify Protocol 22 infrastructure |
| E001 | Script exit 1 (env vars thiếu) | Re-export SESSION_DIR, PROFILE, SCOPE |

**v10.6 note:** Trước v10.6 đây là **2 steps riêng biệt** (4.2 TRACE START, 4.3 Load PW Metadata). Gộp 1 atomic call match pattern Phase 3 v10.5 (Step 3.3 ISG + Partition).

**Cross-ref:** CORE-026 (Execution Trace), CORE-035 (Atomic Write), [`_shared/18-playwright.md`](../_shared/18-playwright.md) (Playwright).

---

## Group A POST-GATE Verify

```bash
jq -e '.phases.phase4.status == "in_progress"' "$SESSION_DIR/fix-status.json" \
  && test -n "$DIMS_ARRAY" \
  && test "$DIMS_COUNT" -gt 0 \
  && echo "Group A PASS (DIMS=$DIMS_COUNT, PW=$PW_LANE_COUNT)" \
  || echo "Group A FAIL"
```

## Next Group

- **IF `PW_LANE_COUNT > 0`:** → Group B Browser CDG — đọc [`phase4-find-bugs/B-browser-cdg.md`](B-browser-cdg.md)
- **IF `PW_LANE_COUNT == 0`:** → SKIP Group B → Group C Create Lane Dirs — đọc [`phase4-find-bugs/C-create-lanes.md`](C-create-lanes.md)
