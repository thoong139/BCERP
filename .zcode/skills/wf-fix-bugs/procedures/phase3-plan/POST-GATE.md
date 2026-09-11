# Phase 3 POST-GATE + Error Reference

> **Entry condition:** Group F PASS (fix-status.phase3 = completed + TRACE COMPLETE).
> **Exit condition:** All T1-T4 checks PASS → advance Phase 4.
> **Next:** Phase 4 — `procedures/phase4-find-bugs.md`.

## POST-GATE T1-T4 Validation

```bash
# T1: Files exist + non-empty
test -s "$SESSION_DIR/phase3-plan/work-plan.json"        || echo "FAIL T1: work-plan.json"
test -s "$SESSION_DIR/phase3-plan/dimension-plan.json"   || echo "FAIL T1: dimension-plan.json"
test -s "$SESSION_DIR/phase3-plan/Phase3-report.md"      || echo "FAIL T1: Phase3-report.md"
test $(ls "$SESSION_DIR/phase3-plan/workloads/"W*/fix-workload.json 2>/dev/null | wc -l) -gt 0 \
  || echo "FAIL T1: workloads"

# T2: Cấu trúc đúng
jq -e '.execution_mode and (.dimensions_applied // .dimensions) and .playwright' \
  "$SESSION_DIR/phase3-plan/work-plan.json" || echo "FAIL T2 work-plan"
jq -e '.dimensions | length > 0' \
  "$SESSION_DIR/phase3-plan/dimension-plan.json" || echo "FAIL T2 dimension-plan"

# T3: Nội dung có chiều sâu
test $(jq '(.dimensions_applied // .dimensions) | length' "$SESSION_DIR/phase3-plan/work-plan.json") -gt 0
for w in "$SESSION_DIR/phase3-plan/workloads/"W*/fix-workload.json; do
  jq -e '.dimensions and .estimated_issues' "$w"
done

# T4: Cross-ref — dimension-plan.dimensions[].id ⊇ work-plan.(dimensions_applied|dimensions)
DP_DIMS=$(jq -r '.dimensions | map(.id) | sort | join(",")' "$SESSION_DIR/phase3-plan/dimension-plan.json")
WP_DIMS=$(jq -r '(.dimensions_applied // .dimensions) | sort | join(",")' "$SESSION_DIR/phase3-plan/work-plan.json")
test "$DP_DIMS" = "$WP_DIMS" \
  || echo "FAIL T4: dimension-plan ≠ work-plan dims (DP=[$DP_DIMS] vs WP=[$WP_DIMS])"
```

**Tất cả T1-T4 PASS → Phase 3 hoàn tất, advance sang Phase 4.**

## Phase 3 Report Summary

Sau POST-GATE pass, `phase3-plan/Phase3-report.md` đã được tạo (qua Group E) với:

- Status (PASS/FAIL), Started/Completed timestamps
- Workload metrics: total estimated, agent capacity, ratio
- CDG-11 decision: continue / ask_warn / ask_block (user response)
- Execution mode (inline / agent_dispatch) + agent count
- Playwright mode (none / headless / visible / mobile)
- Dimensions routed: count + list

## On Failure — Quick Reference

| Code | Lỗi | Auto-Fix | Max Retry | Escalate |
|------|-----|----------|-----------|----------|
| E001 | Disk/session error | Kiểm tra disk space | 1 | AskUserQuestion Retry/Cancel |
| E020 | Phase 2 chưa completed | — | 0 | Dừng, chạy Phase 2 |
| E021 | Phase 2 output missing | Re-run Phase 2 | 0 | Hướng dẫn user |
| E023 | interface_type invalid | Re-run Phase 2 Step 2.3 | 0 | Hướng dẫn fix |
| E030 | ISG fail | Script auto-fallback (giữ dims) | 0 | Continue |
| E032 | Partition fail | Script auto-fallback (1-workload) | 0 | Continue |
| E033 | Workload Gate abort (CDG-11) | Ghi paused → hướng dẫn `--resume` | 0 | User chọn lại |
| E034 | route-and-write.sh exit 1 (env thiếu) | Re-export env vars | 1 | Re-run phase |
| E035 | Template missing / report fail | Re-read template | 2 | Re-run phase |
| E036 | Atomic write fail | Retry Atomic Write | 2 | E001 escalate |
| E037 | Duplicate output_dir | Script auto-detect | 0 | Re-run ISG + routing |

**Auto-fix budget Phase 3:** Max 3 retries tổng (CORE-034). Reset khi POST-GATE PASS.

## Resume Logic

```
1. Đọc fix-status.json → kiểm tra phases.phase3.status
2. "completed" → Skip Phase 3, advance Phase 4
3. "paused" (E033 từ CDG-11):
   → Đọc workload-gate.json → hiển thị lý do
   → AskUserQuestion: "Resume cũ / Điều chỉnh dims/profile / Cancel"
   → Adjust → re-run từ Group B (Step 3.3) với tham số mới
4. "in_progress" hoặc không có status:
   → Stale lock check: > 30 min → auto-release
   → Re-run từ Group A (PRE-GATE detect trạng thái hiện tại)
```

## Next Phase

Phase 4 — `procedures/phase4-find-bugs.md`

> Phase 4 đọc `work-plan.json` (execution_mode, playwright config) + `dimension-plan.json` (routing table — `dimensions[].lane_skill`, `agent_type`, `probe_count`, `needs_playwright`) để dispatch lane agents.
