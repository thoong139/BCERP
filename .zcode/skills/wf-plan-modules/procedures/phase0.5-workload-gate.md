# Phase 0.5: Workload Gate (ADR-OPT-03)

> Ước lượng workload dựa trên initial DAG preview → quyết định scale/skip/continue.
> Chạy SAU Phase 0 (init) và TRƯỚC Phase 1 (validate).

> **Shared context:** xem `_shared.md` — Session Isolation Protocol, _shared Module Imports.

---

## PRE-GATE

Phase 0 POST-GATE PASS — `$SESSION_DIR` đã được khởi tạo, `session-state.json` tồn tại.

---

## 📥 INPUT

| Source | Mô tả |
|--------|-------|
| `$REGISTRY_DATA` | modules[], features[], dependencies từ `req-registry.json` |
| Digests | `feature-briefs.json` + `design-input-digest.json` (nếu có) |
| `$LEGACY_MODE` | flag từ Phase 0 |

## 📤 OUTPUT

| File | Template |
|------|---------|
| `$SESSION_DIR/workload-report.md` | `_shared/templates/workload-report.md` |
| `$SESSION_DIR/session-state.json` (update) | `_shared/templates/session-state.json` |

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.5.1 | **DAG preview:** Đọc `modules[]` từ registry → đếm dependencies (không full topological sort). Import `_shared/partition/planner.py` → `plan_partitions(items=$ACTIVE_MODULES, group_key="topological_level", max_per_partition=5)` | Partitions generated |
| 0.5.2 | **Workload estimation:** Import `_shared/partition/workload_gate.py` → `estimate_workload(partitions, est_minutes_per_item=8.0)`. Apply factor: ×1.0 normal, ×1.5 nếu `$LEGACY_MODE=true` (cần Phase 1.5 code verification), ×2.0 nếu avg `dependencies_per_module > 3` | `WorkloadEstimate` calculated |
| 0.5.3 | **Gate check:** `check_workload_gate(estimate, threshold_minutes=45)`. Tính `ratio = estimated / 45` | `GateResult` obtained |
| 0.5.4 | **Gate decision theo ratio:** `< 0.8` (dead zone) → silent continue. `0.8–1.5` (warn zone) → hiển thị warning + `AskUserQuestion` (continue / narrow MVP scope `--mvp` / abort). `> 1.5` (block zone) → hiển thị Plan menu: (A) Narrow MVP scope (`--mvp`), (B) Override + CDG-A02 acknowledgement, (C) Partition theo topological level sequential. Ghi user decision vào `$SESSION_DIR/session-state.json`. | User decision recorded (hoặc auto-continue nếu dead zone) |
| 0.5.5 | **Template Usage Rule:** READ `_shared/templates/workload-report.md` → POPULATE (`session_id`, `estimated_minutes`, `ratio`, `gate_result`, `factor_applied`, `module_count`, `user_decision` nếu có) → WRITE `$SESSION_DIR/workload-report.md` | `test -s $SESSION_DIR/workload-report.md` |
| 0.5.6 | **Session state update:** Update `$SESSION_DIR/session-state.json`: `phases.P0_5.status = "completed"`, `phases.P0_5.gate_result`, `phases.P0_5.estimated_minutes`, `next_action = "phase1-validate"` | `session-state.json` updated |

---

## §Gate Decision Logic (Step 0.5.4 chi tiết)

```
ratio = estimated_minutes / 45

IF ratio < 0.8:
  # Silent continue — không cần user interaction
  $GATE_RESULT = "pass"

ELIF ratio <= 1.5:
  # Warn zone
  $GATE_RESULT = "warn"
  Hiển thị:
    ⚠️ [Workload Gate WARN] Ước lượng: [estimated_minutes] phút (ratio=[ratio:.2f]×)
    Threshold: 45 phút. Có thể mất nhiều thời gian hơn dự kiến.
  AskUserQuestion:
    (a) Tiếp tục (continue as-is)
    (b) Thu hẹp scope MVP (thêm --mvp flag)
    (c) Hủy bỏ

ELSE:
  # Block zone (ratio > 1.5)
  $GATE_RESULT = "block"
  Hiển thị:
    🚫 [Workload Gate BLOCK] Ước lượng: [estimated_minutes] phút (ratio=[ratio:.2f]×)
    Threshold: 45 phút × 1.5 = [67.5] phút. Cần điều chỉnh scope.
  Plan A/B/C menu:
    (A) [MVP scope] Chạy với --mvp flag — chỉ process modules trong MVP scope
    (B) [Override] Tiếp tục toàn bộ — tôi hiểu rủi ro context overflow (CDG-A02)
    (C) [Partition] Xử lý từng topological level sequential — chạy lại nhiều lần
```

---

## §Workload Factor Rules

| Condition | Factor | Lý do |
|-----------|--------|-------|
| `$LEGACY_MODE = false` | 1.0 | Standard path |
| `$LEGACY_MODE = true` | 1.5 | Phase 1.5 code verification thêm ~50% overhead |
| avg `dependencies_per_module > 3` | 2.0 | Cross-module dependencies phức tạp → nhiều ripple effect |
| Cả hai điều kiện LEGACY + high deps | 2.0 | Áp dụng max factor (không nhân chồng) |

> **Lưu ý:** Initial DAG preview (Phase 0.5) dùng module count trực tiếp từ registry làm `$ACTIVE_MODULES`. Full topological sort diễn ra ở Phase 4 — khi đó partitions được re-compute theo actual topological levels. Phase 0.5 chỉ cần estimate đủ chính xác để gate.

---

## POST-GATE

```bash
test -s "$SESSION_DIR/workload-report.md" \
  && jq -e '.phases.P0_5.status == "completed"' "$SESSION_DIR/session-state.json"
```

User đã acknowledge nếu `$GATE_RESULT` là `warn` hoặc `block`.

---

## Next

→ Checkpoint: `phases.P0_5.status = "completed"`, `next_action = "phase1-validate"`
→ Read `procedures/phase1-validate.md`
