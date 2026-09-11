# Phase 3 Group B — ISG + Partition (Step 3.3)

> **Entry condition:** Group A POST-GATE PASS (PRE-GATE + TRACE START done).
> **Exit condition:** `isg-result.json` + `workloads/W*/fix-workload.json` written.
> **Next:** [phase3-plan/C-workload-gate.md](C-workload-gate.md) (Workload Gate CDG-11 INLINE).
>
> **Shared protocols cần thiết:** None (script delegation only).

## Input contract (env vars từ Group A)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$DIMS_ARRAY`, `$PROFILE` | Pipeline state |
| `$INTERFACE_TYPE` | Phase 2 output |

## Output contract (env vars truyền sang Group C)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `REFINED_DIMS`, `REFINED_PROFILE` | 3.3 | Output từ ISG Recommender |
| `DIM_COUNT`, `WORKLOAD_COUNT`, `TOTAL_ESTIMATED` | 3.3 | Partition Planner metrics |
| `isg-result.json` written | 3.3 | `$SESSION_DIR/phase3-plan/isg-result.json` |
| `workloads/W*/fix-workload.json` × N written | 3.3 | Per-workload partition plans |

---

## Step 3.3 — ISG + Partition (delegated to plan-isg-partition.sh)

**Mục đích:** Thực hiện **2 logical sub-steps trong 1 atomic call**:

1. **ISG Recommender** (`python -m isg`): Refine `$DIMS_ARRAY` theo profile + interface_type. Fallback E030 → giữ dims hiện tại, profile=standard.
2. **Partition Planner** (`python -m partition`): Chia dims thành workloads. Fallback E032 → auto-generate 1-workload chứa tất cả dimensions.

```bash
mkdir -p "$SESSION_DIR/phase3-plan/workloads"
export SESSION_DIR DIMS_ARRAY PROFILE INTERFACE_TYPE

PHASE3_S1=$(bash .claude/scripts/wf-fix-bugs/plan-isg-partition.sh)

# Eval values vào orchestrator in-memory state
REFINED_DIMS=$(echo "$PHASE3_S1" | jq -r '.refined_dims')
REFINED_PROFILE=$(echo "$PHASE3_S1" | jq -r '.refined_profile')
DIM_COUNT=$(echo "$PHASE3_S1" | jq -r '.dim_count')
WORKLOAD_COUNT=$(echo "$PHASE3_S1" | jq -r '.workload_count')
TOTAL_ESTIMATED=$(echo "$PHASE3_S1" | jq -r '.total_estimated')
export REFINED_DIMS REFINED_PROFILE DIM_COUNT WORKLOAD_COUNT TOTAL_ESTIMATED
```

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase3-plan/isg-result.json"
test "$WORKLOAD_COUNT" -gt 0
test "$DIM_COUNT" -gt 0
for w in "$SESSION_DIR/phase3-plan/workloads/"W*/fix-workload.json; do
  jq -e '.dimensions and .estimated_issues' "$w"
done
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E030 | ISG Python module fail/wrong-signature | Script auto-fallback: giữ DIMS_ARRAY, profile=standard |
| E032 | Partition Python module fail | Script auto-fallback: 1-workload với tất cả dimensions |
| E001 | Script exit 1 (env var thiếu) | Re-export env vars + re-run |

**v10.10.0 fix:** Python CLI signatures align — `isg analyze` → `isg emit` (2-step chain), `partition --items-file --group-key` (prepare items JSON trước).

**Cross-ref:** CORE-031, CORE-034 (E030/E032 fallbacks), CORE-025 (workload độc lập).

---

## Group B POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase3-plan/isg-result.json" && \
test "$WORKLOAD_COUNT" -gt 0 && test "$DIM_COUNT" -gt 0 && \
test $(ls "$SESSION_DIR/phase3-plan/workloads/"W*/fix-workload.json 2>/dev/null | wc -l) -gt 0 && \
  echo "Group B PASS" || echo "Group B FAIL"
```

## Next Group

→ Group C Workload Gate CDG-11 — đọc [`phase3-plan/C-workload-gate.md`](C-workload-gate.md)
