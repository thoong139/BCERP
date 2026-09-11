# Phase 0.5: Workload Gate (ADR-OPT-03)

> Ước lượng workload dựa trên số modules × complexity, so sánh với threshold, quyết định có cần điều chỉnh scope không.
> Áp dụng cho **MỌI mode** (NEW + LEGACY) — chạy SAU Phase 0, TRƯỚC phase0.5-legacy-impl-seed (LEGACY) hoặc phase1-scope-mapping (NEW).

**PRE-GATE:**

```bash
# Phase 0 POST-GATE PASS
test -n "$REGISTRY_DATA"
test -n "$SESSION_DIR"
```

> **(CORE-026)** Append START entry vào `.mc-data/work/_trace/session-log.json` (xem `_shared.md §Execution Trace Protocol`).

**INPUT:** `$REGISTRY_DATA` (modules, features count estimate từ requirements, LEGACY_MODE flag)

**OUTPUT:** `$SESSION_DIR/workload-report.md`

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.5.1 | **Partition Planning (ADR-OPT-03):** Import `_shared/partition/planner.py` → `plan_partitions(items=$ACTIVE_MODULES, group_key="module", max_per_partition=5)`. `$ACTIVE_MODULES` = modules trong registry trừ `$DEPRECATED_MODULES`. | Partitions generated |
| 0.5.2 | **Workload Estimation:** Import `_shared/partition/workload_gate.py` → `estimate_workload(partitions, est_minutes_per_item=5.0)`. Factor nhân: `×1.0` normal; `×1.5` nếu `$LEGACY_MODE = true`; `×2.0` nếu trung bình `>3 features/module` (dựa trên `requirements.length / modules.length` ratio từ registry). | WorkloadEstimate calculated |
| 0.5.3 | **Gate Check:** `check_workload_gate(estimate, threshold_minutes=45)`. Tính `ratio = estimated_minutes / 45`. Phân loại: `dead_zone` (<0.8), `warn` (0.8–1.5), `block` (>1.5). | GateResult obtained |
| 0.5.4 | **User Decision (nếu cần):**<br>- `dead_zone` (<0.8): silent continue — không hỏi user. Ghi `user_decision = "auto_continue"` vào session-state.json.<br>- `warn` (0.8–1.5): **Dừng và hiển thị cho user:** "Ước lượng khoảng {X} phút cho {N} modules ({P} partitions). Tiếp tục với toàn bộ scope? (Y/N)". Chờ phản hồi. Nếu user đồng ý → `user_decision = "continue"`. Nếu user từ chối → **SAVE CHECKPOINT** → gợi ý: "Dùng `--scope=<system-name>` để xử lý từng system" → STOP.<br>- `block` (>1.5): Hiển thị Plan A/B/C menu:<br>&nbsp;&nbsp;**A. Thu hẹp scope:** Chỉ chạy 1 system (`--scope=<system-name>`)<br>&nbsp;&nbsp;**B. Tiếp tục toàn bộ scope (xác nhận rõ):** Trigger CDG-A02 (`_shared/cdg/cdg_handler.py`) — cần user confirm<br>&nbsp;&nbsp;**C. Sequential từng batch:** Chạy từng partition một<br>→ Ghi nhận decision vào session-state.json. | User decision recorded |
| 0.5.5 | **Ghi workload-report.md:** READ template `_shared/templates/workload-report.md` → POPULATE data → WRITE `$SESSION_DIR/workload-report.md` (Template Usage Rule CORE-031). | `test -s $SESSION_DIR/workload-report.md` |
| 0.5.6 | **Update session-state.json:** `phases.P0_5.status = "completed"`. Ghi `workload_estimate`, `gate_result`, `user_decision`. Set `next_action`: nếu `$LEGACY_MODE = true` → `"phase0.5-legacy-impl-seed"`, else → `"phase1-scope-mapping"`. | session-state.json updated |

## Lưu ý Kỹ Thuật

- Template Strip: không cần cho workload-report.md (không phải digest — chỉ báo cáo nội bộ).
- Atomic Write cho session-state.json (`_shared/_shared.md §2`).
- CDG-A02 chỉ trigger khi user chọn Option B (override block gate) — không block execution khi warn.
- `$WORKLOAD_ESTIMATE` và `$GATE_RESULT` được set trong bước này để Phase 1, 2, 3 sử dụng.

**POST-GATE:**

```bash
# T1: workload-report.md tồn tại, non-empty
test -s $SESSION_DIR/workload-report.md
# T2: session-state.json có gate_result
jq -e '.workload_estimate' $SESSION_DIR/session-state.json > /dev/null
# T3: User decision đã được ghi (dead_zone: "auto_continue", warn/block: "continue"/"plan_a"/"plan_b"/"plan_c")
# dead_zone PASS mà không cần hỏi user — user_decision = "auto_continue" luôn tồn tại
jq -e '.user_decision != null' $SESSION_DIR/session-state.json > /dev/null
```

> **(Protocol 6.6)** Nếu `$LARGE_PROJECT = true`: **SAVE CHECKPOINT** (dual write: session-state.json + checkpoint.json).

**Status update:** `session-state.json` → `phases.P0_5.status = "completed"`, `completed_at = <ISO timestamp>`.

### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| partition/planner import fail | Log WARNING, dùng fallback single-partition estimate (tự tính: modules_count × 5.0 phút) |
| User từ chối ở warn zone | **SAVE CHECKPOINT** với `gate_result="warn_rejected"` → STOP — gợi ý dùng `--scope=<system>` |
| User chọn Plan A (narrow scope) | Ghi `user_decision="plan_a"`, `narrow_scope=<system>` vào session-state.json → STOP — hướng dẫn user chạy lại `/wf-define-features --scope=<system>` |
| User chọn Plan C (partition sequential) | Ghi `partition_sequential: true`, `user_decision="plan_c"` vào session-state.json → Phase 1 dispatch theo batch 1 lần |
| CDG-A02 reject (user không confirm override) | **SAVE CHECKPOINT** với `gate_result="block_rejected"` → STOP — hướng dẫn user narrow scope với `--scope=<system>` hoặc chọn Plan C |

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id=`phase-0.5-workload`, status, items_processed=N modules estimated, key_findings=gate_result, next_action
3. WRITE: `$SESSION_DIR/phase-summary.md`

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json`.

**Next phase:**
- Nếu `$LEGACY_MODE = true` → `phase0.5-legacy-impl-seed.md`
- Nếu không → `phase1-scope-mapping.md`
