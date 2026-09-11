# Phase 4 Group F — Monitor + Collect & Validate (Step 4.7)

> **Entry condition:** Group E POST-GATE PASS (N agents dispatched + lanes transitioned `pending` → `in_progress`).
> **Exit condition:** All lanes terminal (completed/failed/skipped) + POST-GATE T1-T4 PASS.
> **Next:** [phase4-find-bugs/G-report-finalize.md](G-report-finalize.md) (Generate Phase 4 Report + Finalize).
>
> **Shared protocols cần thiết:**
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E009, E043, E046, E047, E048, E049
> - [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md) — POST-GATE T1-T4 standard

> **⚠ Lưu ý:** Group F = **2 logical sub-steps** sequential (Monitor + Validate). Monitor phải PASS trước khi gọi Validate.

## Input contract (env vars từ Group E)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$DIMS_ARRAY`, `$DIMS_COUNT` | Pipeline state |
| `$MCV3_POLL_INTERVAL` (optional, default 30) | Monitor poll interval (seconds) |
| `$MCV3_LANE_TIMEOUT` (optional, default 900) | Per-lane timeout (15 phút) |
| `$MCV3_CONTEXT_USAGE` (optional, default 0) | Hint for context budget tier check (CORE-038) |
| N spawned agents (async) | Group E |

## Output contract (env vars truyền sang Group G)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `$LANES_COMPLETED` | 4.7 monitor | Số lanes terminal completed |
| `$LANES_FAILED` | 4.7 monitor | Số lanes terminal failed |
| `$SIGNALS_TOTAL` | 4.7 validate | Tổng signals từ 3 stream × N lanes |
| `$INVALID_SIGNALS` | 4.7 validate | Số signals bị drop (E048) |
| `$INCONSISTENCIES` | 4.7 validate | Số data inconsistencies (E047 CLAIMED ≠ ACTUAL) |
| `$PROBE_FAILURES` | 4.7 validate | Số probe failures (từ probe-failures.log) |
| `$STOP_AFTER_PHASE4` | 4.7 monitor | true nếu context tier 80-90% |

---

## Step 4.7 — Monitor + Collect & Validate (gộp v10.6 — monitor-lanes.sh + validate-lane-outputs.sh)

**Mục đích:** Thực hiện **2 logical sub-steps** sequential:

1. **Monitor Loop** (`monitor-lanes.sh`): Poll mỗi 30s + lane timeout 15min (E046) + context budget CORE-038 (tier <65% OK / 65-80% prep / 80-90% checkpoint / >90% FORCE STOP E009). Exit khi tất cả lanes terminal.
2. **Collect & Validate** (`validate-lane-outputs.sh`): POST-GATE T1-T4 cho TẤT CẢ lanes:
   - **T1 File Existence** — lane-status, signals.json per stream, QD-report (E043: generate stub)
   - **T2 Structure Validation** — JSON shape, signals array
   - **T3 Content Depth** — signal required fields (E048: log invalid count)
   - **T4 Cross-Ref Count Matching** — CLAIMED vs ACTUAL (E047: emit inconsistencies array)

**Thực thi:**

```bash
export SESSION_DIR DIMS_ARRAY
export MCV3_POLL_INTERVAL="${MCV3_POLL_INTERVAL:-30}"
export MCV3_LANE_TIMEOUT="${MCV3_LANE_TIMEOUT:-900}"
export MCV3_CONTEXT_USAGE="${MCV3_CONTEXT_USAGE:-0}"

# Sub-step 1: Monitor Loop
MONITOR_OUT=$(bash .claude/scripts/wf-fix-bugs/monitor-lanes.sh)
MONITOR_EXIT=$?

# Handle context budget exits (CORE-038)
case $MONITOR_EXIT in
  9)  echo "E009: Context >90% FORCE STOP — checkpoint saved, run --resume" >&2; exit 9 ;;
  8)  STOP_AFTER_PHASE4=true; echo "Context 80-90% — will stop after Phase 4 collect" >&2 ;;
  0)  ;;
  *)  echo "E046: Monitor unexpected exit $MONITOR_EXIT" >&2; exit 46 ;;
esac

LANES_COMPLETED=$(echo "$MONITOR_OUT" | jq -r '.completed')
LANES_FAILED=$(echo "$MONITOR_OUT" | jq -r '.failed')

# Sub-step 2: Collect & Validate T1-T4
VALIDATE_OUT=$(bash .claude/scripts/wf-fix-bugs/validate-lane-outputs.sh)
VALIDATE_EXIT=$?

SIGNALS_TOTAL=$(echo "$VALIDATE_OUT" | jq -r '.signals_total')
INVALID_SIGNALS=$(echo "$VALIDATE_OUT" | jq -r '.invalid_signals')
INCONSISTENCIES=$(echo "$VALIDATE_OUT" | jq -r '.data_inconsistencies | length')
PROBE_FAILURES=$(echo "$VALIDATE_OUT" | jq -r '.probe_failures_count')

case $VALIDATE_EXIT in
  7)  # E047 DATA INCONSISTENCY — auto-fix budget hết → escalate
      echo "E047: $INCONSISTENCIES data inconsistencies (CLAIMED ≠ ACTUAL)" >&2
      # AskUserQuestion "Re-run phase / Skip (risky) / Cancel"
      ;;
  4)  echo "WARN: Partial validation — stubs generated, invalid signals logged" >&2 ;;
  0)  ;;
esac

export LANES_COMPLETED LANES_FAILED SIGNALS_TOTAL INVALID_SIGNALS INCONSISTENCIES PROBE_FAILURES STOP_AFTER_PHASE4
```

**Quy tắc:**

- BẮT BUỘC chạy đủ 2 sub-steps tuần tự. Monitor phải PASS trước khi gọi Validate.
- POST-GATE T1-T4 KHÔNG được dừng ở T1 — phải đủ 4 tiers.
- Auto-fix budget: max 3 retries cho T1-T4 (CORE-034). Hết → ESCALATE AskUserQuestion.

**Context Budget Decision Tree (CORE-038):**

| Tier | Hành động |
|------|-----------|
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint (lưu state files) |
| 80-90% | Lưu checkpoint, STOP sau Phase 4 collect → hướng dẫn `--resume` Phase 5 |
| > 90% | FORCE STOP (E009) — checkpoint bắt buộc |

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E009 | Context >90% (monitor exit 9) | FORCE STOP — checkpoint + hướng dẫn `--resume` |
| E046 | Lane timeout >15 phút | Mark lane failed (script tự handle) |
| E043 | QD-report missing | Generate stub từ template (script tự handle) |
| E047 | DATA INCONSISTENCY (validate exit 7) | Retry fix x1 → ESCALATE AskUserQuestion |
| E048 | Signal thiếu required field | Drop signal, log warning (script tự handle) |
| E049 | Fingerprint collision | Keep first, skip duplicate |

**v10.6 note:** Trước v10.6 đây là **2 steps riêng biệt** (4.6 Monitor 95 dòng heredoc, 4.7 Collect & Validate 150 dòng 4 T-tiers heredoc). Gộp logical Step 4.7 với 2 script calls sequential.

**Cross-ref:** CORE-038 (Context Budget), CORE-034 (Error Codes + Auto-Fix Budget), CORE-012 (POST-GATE T1-T4), CORE-011 (Forensic).

---

## Group F POST-GATE Verify

```bash
# All lanes terminal + signals_total quantified
[ "$LANES_COMPLETED" -ge 0 ] && [ "$LANES_FAILED" -ge 0 ] \
  && [ "$((LANES_COMPLETED + LANES_FAILED))" -eq "$DIMS_COUNT" ] \
  && [ "$SIGNALS_TOTAL" -ge 0 ] \
  && echo "Group F PASS (completed=$LANES_COMPLETED, failed=$LANES_FAILED, signals=$SIGNALS_TOTAL)" \
  || echo "Group F FAIL"
```

## Next Group

→ Group G Report + Finalize — đọc [`phase4-find-bugs/G-report-finalize.md`](G-report-finalize.md)
