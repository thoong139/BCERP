# Phase 0.5: Workload Gate (ADR-OPT-03)

> Kiểm tra conditional api-only skip trước, sau đó ước lượng workload dựa trên số UI modules × complexity,
> so sánh với threshold, quyết định có cần điều chỉnh scope không.
> Áp dụng cho **MỌI mode** (NEW + LEGACY) — chạy SAU Phase 0, TRƯỚC phase0.5-legacy-ui-analysis (LEGACY) hoặc phase1-design-system (NEW).

**PRE-GATE:**

```bash
# Phase 0 POST-GATE PASS
test -n "$REGISTRY_DATA"
test -n "$SESSION_DIR"
```

> **(CORE-026)** Append START entry vào `.mc-data/work/_trace/session-log.json` (xem `_shared.md §Execution Trace Protocol`).

**INPUT:** `$REGISTRY_DATA` (systems, modules, interface_type), `LEGACY_MODE` flag, `design-input-digest.json` từ wf-design

**OUTPUT:** `$SESSION_DIR/workload-report.md`

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.5.0 | **CONDITIONAL CHECK — api-only exit gate:** Đọc `interface_type` từ `req-registry.json`. IF `interface_type == "api-only"` → (a) Update `$SESSION_DIR/session-state.json`: `phases.P0_5.status = "skipped"`, `phases.P0_5.reason = "api-only interface"`, `phases.P0_5.skipped = true`. (b) Ghi `phase-summary.md`: "Skill skipped — project is api-only. Không có outputs UX." (c) Append SKIP entry vào `.mc-data/work/_trace/session-log.json`. (d) **EXIT toàn skill — return success với 0 canonical outputs.** KHÔNG spawn bất kỳ agent nào, KHÔNG tạo ux-input-digest.json canonical. | IF api-only → skill exit hoàn toàn trước estimate |
| 0.5.1 | **Partition Planning (ADR-OPT-03):** Import `_shared/partition/planner.py` → `plan_partitions(items=$UI_MODULES, group_key="module", max_per_partition=5)`. `$UI_MODULES` = modules có `has_ui == true` hoặc `interface_type` là `web`/`mobile`/`hybrid` (filter từ module feature specs + registry). Loại bỏ `$DEPRECATED_MODULES`. | Partitions generated |
| 0.5.2 | **Workload Estimation:** Import `_shared/partition/workload_gate.py` → `estimate_workload(partitions, est_minutes_per_item=4.0)`. Factor nhân: `×1.0` normal; `×1.5` nếu `$LEGACY_MODE = true`; `×1.5` nếu trung bình `>3 screen_groups/module` (dựa trên Navigation-*.md từ wf-design digest hoặc ước lượng từ features/module ratio). | WorkloadEstimate calculated |
| 0.5.3 | **Gate Check:** Import `_shared/partition/workload_gate.py` → `check_workload_gate(estimate, threshold_minutes=45)`. Tính `ratio = estimated_minutes / 45`. Phân loại: `dead_zone` (<0.8), `warn` (0.8–1.5), `block` (>1.5). | GateResult obtained |
| 0.5.4 | **User Decision (nếu cần):**<br>- `dead_zone` (<0.8): silent continue — không hỏi user.<br>- `warn` (0.8–1.5): AskUserQuestion: "Estimated {X} min for {N} UI modules ({P} partitions). Continue with full scope?" — ghi nhận lựa chọn.<br>- `block` (>1.5): Hiển thị Plan A/B/C menu:<br>&nbsp;&nbsp;**A. Narrow scope:** Chỉ thiết kế UX cho 1 system (`/wf-design-ux [system-name]`)<br>&nbsp;&nbsp;**B. Override + CDG-A02:** Tiếp tục với toàn bộ scope, trigger CDG-A02 (`_shared/cdg/cdg_handler.py`)<br>&nbsp;&nbsp;**C. Partition sequential:** Chạy từng partition một, mỗi lần 1 batch<br>→ Ghi nhận decision vào `$SESSION_DIR/session-state.json`. | User decision recorded |
| 0.5.5 | **Ghi workload-report.md:** READ template `../_shared/templates/workload-report.md` → POPULATE data → WRITE `$SESSION_DIR/workload-report.md` (Template Usage Rule CORE-031). | `test -s $SESSION_DIR/workload-report.md` |
| 0.5.6 | **Update session-state.json:** `phases.P0_5.status = "completed"`. Ghi `workload_estimate`, `gate_result`, `user_decision`. Set `next_action`: nếu `$LEGACY_MODE = true` → `"phase0.5-legacy-ui-analysis"`, else → `"phase1-design-system"`. | session-state.json updated |

---

## Lưu ý Đặc Thù

- **Step 0.5.0 là conditional exit gate duy nhất** trong toàn skill — KHÔNG check api-only ở Phase 0 nữa (Phase 0 UI Guard vẫn giữ nhưng Step 0.5.0 là exit point chính thức).
- **Skill return success khi api-only** — downstream (`wf-plan-modules`) KHÔNG nhận error, tự handle thiếu `ux-input-digest.json` theo `00-core.md §4b` IF branch.
- **Session vẫn tạo khi api-only** — audit trail, cleanup policy (giữ 5 sessions) vẫn áp dụng.
- **`$SKILL_SKIPPED` flag** được set bởi Step 0.5.0, đọc bởi exit handler để skip Phase 1-7.
- Template Strip: không cần cho workload-report.md (không phải digest — chỉ báo cáo nội bộ).
- Atomic Write cho session-state.json theo `_shared/_shared.md §2`.
- CDG-A02 chỉ trigger khi user chọn Option B (override block gate).
- Dedup key cho screen-lane: `screen_id` (SCREEN-ID) — reuse cross-module KHÔNG phải conflict.
- `$WORKLOAD_ESTIMATE` và `$GATE_RESULT` set tại đây → Phase 1, 3, 4 sử dụng.

---

**POST-GATE:**

```bash
# T1: workload-report.md tồn tại, non-empty (CHỈ khi interface_type != api-only)
test -s $SESSION_DIR/workload-report.md
# T2: session-state.json có status (skipped hoặc completed)
jq -e '.phases.P0_5.status' $SESSION_DIR/session-state.json > /dev/null
# T3: Nếu gate = warn/block: user acknowledged
jq -e '.user_decision' $SESSION_DIR/session-state.json > /dev/null
```

> **(Protocol 6.6)** Nếu `$LARGE_PROJECT = true`: **SAVE CHECKPOINT** (dual write: session-state.json + checkpoint.json).

**Status update:** `session-state.json` → `phases.P0_5.status = "completed"` (hoặc `"skipped"` nếu api-only), `completed_at = <ISO timestamp>`.

---

### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| partition/planner import fail | Log WARNING, dùng fallback single-partition estimate |
| User chọn Option C (partition sequential) | Ghi `partition_sequential: true` vào session-state.json → Phase 3 dispatch theo batch 1 lần |
| CDG-A02 reject (user không confirm override) | STOP — hướng dẫn user narrow scope với `/wf-design-ux [system-name]` |
| api-only detected | Exit success, phase-summary.md ghi lý do, KHÔNG coi là failure |

---

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: `phase_id=phase-0.5-workload`, `status`, `items_processed=N UI modules estimated`, `key_findings=gate_result`, `next_action`
3. WRITE: `$SESSION_DIR/phase-summary.md`

> **(CORE-026)** Append COMPLETE (hoặc SKIP nếu api-only) entry vào `.mc-data/work/_trace/session-log.json`.

**Next phase:**
- Nếu `interface_type == "api-only"` → **EXIT skill** (return success)
- Nếu `$LEGACY_MODE = true` → `phase0.5-legacy-ui-analysis.md`
- Nếu không → `phase1-design-system.md`
