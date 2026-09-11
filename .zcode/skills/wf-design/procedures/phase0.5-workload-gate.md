# Phase 0.5: Workload Gate (ADR-OPT-03)

> Ước lượng thời gian thực thi dựa trên số systems, phân vùng theo group_key="system",
> và hỏi user nếu workload vượt ngưỡng. Ngăn chặn session quá tải context trước khi spawn agents.

**PRE-GATE:** Phase 0 POST-GATE PASS

```bash
test -n "$REGISTRY_DATA"
test -n "$ACTIVE_SYSTEMS"    # set bởi Phase 0 (loại bỏ $DEPRECATED_MODULES)
test -s $SESSION_DIR/session-state.json
```

**INPUT:**
- `$REGISTRY_DATA` (systems, modules, features counts)
- `$LEGACY_MODE` flag
- `$ACTIVE_SYSTEMS` — systems còn lại sau loại DEPRECATED
- `architecture_style` — detect từ `project-context.md` nếu LEGACY (tìm keyword: microservices, event-driven)
- Template `_shared/templates/workload-report.md` (workload report output)

**OUTPUT:**
- `$SESSION_DIR/workload-report.md` — bản ghi ước lượng + decision
- `$WORKLOAD_ESTIMATE` — số phút ước tính
- `$GATE_RESULT` — `dead_zone` | `warn` | `block`

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.5.1 | **Partition Planning:** Import `_shared/partition` → `plan_partitions(items=$ACTIVE_SYSTEMS, group_key="system", max_per_partition=3)`. Ghi kết quả vào in-memory `$PARTITIONS`. | Partitions generated, `len($PARTITIONS) >= 1` |
| 0.5.2 | **Workload Estimation:** Import `_shared/partition` → `estimate_workload(partitions=$PARTITIONS, est_minutes_per_item=15.0)`. Áp factor: ×1.0 normal, ×1.5 nếu `$LEGACY_MODE = true`, ×2.0 nếu `architecture_style IN (microservices, event-driven)`. Lưu `$WORKLOAD_ESTIMATE = estimate.total_minutes`. | `$WORKLOAD_ESTIMATE` là số dương |
| 0.5.3 | **Gate Check:** `check_workload_gate(estimate=$WORKLOAD_ESTIMATE, threshold_minutes=45)`. Tính `ratio = $WORKLOAD_ESTIMATE / 45`. Lưu `$GATE_RESULT`. | `$GATE_RESULT` ∈ {dead_zone, warn, block} |
| 0.5.4 | **User Decision:** Xử lý theo `$GATE_RESULT`:<br>- `dead_zone` (ratio < 0.8): → silent continue, không hỏi user<br>- `warn` (0.8 ≤ ratio ≤ 1.5): → AskUserQuestion: "Ước lượng **{X} phút** cho {N} systems ({list}). Tiếp tục? [Có / Chỉ system đầu / Huỷ]"<br>- `block` (ratio > 1.5): → Hiển thị menu:<br>  A. Thu hẹp về 1 system (chọn hệ thống ưu tiên)<br>  B. Override + CDG-A02 (tiếp tục toàn bộ — yêu cầu xác nhận rủi ro)<br>  C. Partition tuần tự (chạy lần lượt từng system, mỗi lần 1 session)<br>  → DỪNG chờ user chọn | User decision recorded (hoặc dead_zone — tự động) |
| 0.5.5 | **Write Workload Report:** ĐỌC template `_shared/templates/workload-report.md` → POPULATE `systems_count`, `partitions_count`, `est_minutes_per_item`, `workload_factor`, `total_estimated_minutes`, `gate_result`, `user_decision`, `active_systems` → GHI `$SESSION_DIR/workload-report.md` | `test -s $SESSION_DIR/workload-report.md` |
| 0.5.6 | **Update session-state.json:** ĐỌC `$SESSION_DIR/session-state.json` → SET `phases.P0_5.status = "completed"`, `phases.P0_5.gate_result = $GATE_RESULT`, `phases.P0_5.est_minutes = $WORKLOAD_ESTIMATE`, `next_action = "phase1-architecture"` → GHI atomic | `jq '.phases.P0_5.status' session-state.json → "completed"` |

---

## Partition Config đặc thù wf-design

| Tham số | Giá trị | Lý do |
|---------|---------|-------|
| `group_key` | `"system"` | System là đơn vị thiết kế lớn nhất trong wf-design |
| `max_per_partition` | `3` | System-lane nặng — mỗi system sinh 4-5 agents (architect + API + DB + infra + optional conditional); giảm concurrency tránh saturation |
| `est_minutes_per_item` | `15.0` | Cao nhất trong 4 skills — reflect đúng: architect + api-contract + database-design + infra-spec + integration-map ≈ 4-5 agents/system |
| `threshold_minutes` | `45` | 3 systems × 15 min = 45 min = ngưỡng warn |
| Factor normal | `1.0` | Dự án mới, không có legacy overhead |
| Factor LEGACY | `1.5` | LEGACY_MODE: thêm gap analysis + LEGACY injection overhead |
| Factor multi-tier | `2.0` | architecture_style ∈ (microservices, event-driven) → integration-map phức tạp hơn |

---

## Architecture Style Detection (LEGACY_MODE only)

```
IF $LEGACY_MODE = true:
  Đọc .mc-data/work/legacy-scan/project-context.md
  Tìm keywords: "microservices", "event-driven", "event sourcing", "CQRS", "service mesh"
  Tìm trong: project-context.md, req-registry.json (nếu có notes/tags)
  IF keyword found → architecture_style = "microservices" hoặc "event-driven"
  ELSE → architecture_style = "standard"
ELSE:
  architecture_style = "standard"  (new project — không có legacy code để detect)
```

---

## POST-GATE

```bash
# Workload report tồn tại
test -s $SESSION_DIR/workload-report.md

# session-state.json updated
jq -e '.phases.P0_5.status == "completed"' $SESSION_DIR/session-state.json

# User đã acknowledged nếu WARN/BLOCK
# (implicit — nếu user huỷ tại 0.5.4 thì skill đã STOP, không bao giờ đến POST-GATE này)
```

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E017 | `$ACTIVE_SYSTEMS` rỗng (tất cả systems bị DEPRECATE) | STOP: "Tất cả systems đều được đánh dấu DEPRECATE. Kiểm tra lại legacy-decisions.json." |
| E018 | User chọn "Huỷ" tại warn/block gate | Lưu checkpoint, STOP với hướng dẫn resume khi sẵn sàng |
| E019 | `workload-report.md` template không tồn tại | Fallback: tạo report inline (không dùng template), tiếp tục |

---

## Next Phase

→ Read `procedures/phase1-architecture.md` — Architecture Overview (Lane Dispatch)
