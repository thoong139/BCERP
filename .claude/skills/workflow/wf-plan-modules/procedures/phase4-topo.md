# Phase 4: Topological Sorting

> Xếp modules thành layers theo thứ tự dependencies → output `$LAYERS` (in-memory).

> **Shared context:** xem `_shared.md` — State Variables (`$LAYERS`, `$ASSIGNED`, `$TOTAL`).

---

## PRE-GATE

`test "$HAS_CYCLE" = "false"`

## 📥 INPUT

- `$DEP_MATRIX` (in-memory từ Phase 2)
- `$MODULE_COUNT` (in-memory từ Phase 1)
- `$LEGACY_MODE`, `$LEGACY_GAP_CONTEXT` (LEGACY only)

## 📤 OUTPUT

- `$LAYERS` (in-memory) — Array layers với `{layer, phase, modules[], parallel, sprint}`
- `$ASSIGNED` / `$TOTAL` (in-memory) — Count modules assigned vs total

> Xử lý in-memory (topological sort) — output là `$LAYERS` (in-memory).

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 4.0 | **Scale warning (A6-M1)**: Nếu `$MODULE_COUNT > 100` → hiển thị "WARN: Topological sort với N modules có thể chậm (O(V²) worst case). Đang xử lý..." | Warning shown |
| 4.1 | Tìm Layer 0 (không phụ thuộc ai) — Kahn's algorithm O(V+E) | Layer 0 found |
| 4.2 | Tìm Layer 1+ (chỉ phụ thuộc layers trước). **Per-layer checkpoint (A6-M1 fix)**: sau mỗi layer assignment, persist `$LAYERS` ra `.mc-data/work/wf-plan-modules/topo-progress.json` theo Atomic Write Pattern. Nếu context break → Phase 4 resume đọc file này thay vì chạy lại từ đầu. | All layers found + checkpoint per layer |
| 4.3 | Gán phase names | Labels assigned |
| 4.4 | Verify tất cả modules đã được gán | `test $ASSIGNED = $TOTAL` |
| 4.4b | **Persist $LAYERS (CRITICAL — resume safety):** Atomic write `$LAYERS` vào `$SESSION_DIR/topo-layers.json` để survive context reset. `TMP=$(mktemp $SESSION_DIR/.topo.XXXXXX)` → `jq -n --argjson layers "$LAYERS_JSON" '{"layers":$layers,"total_layers":.layers\|length,"persisted_at":"<NOW>"}' > $TMP` → `mv $TMP $SESSION_DIR/topo-layers.json`. Nếu `$SESSION_DIR` chưa tồn tại → write vào `.mc-data/work/wf-plan-modules/topo-layers-fallback.json`. Mục đích: Phase 7, 7.5 có thể re-hydrate `$LAYERS` từ file này khi resume. | `test -s $SESSION_DIR/topo-layers.json` |
| 4.5 | Cleanup: xóa `topo-progress.json` (intermediate per-layer file — đã được merge vào `topo-layers.json` ở step 4.4b). **KHÔNG xóa `topo-layers.json`** — file này cần cho resume. | `topo-progress.json` removed |

---

## Layer Assignment

| Layer | Phase Name | Đặc điểm |
|-------|------------|----------|
| 0 | Foundation | Không phụ thuộc ai (Settings, SharedKernel) |
| 1 | Core | Chỉ phụ thuộc Layer 0 (CRM, HR, Catalog) |
| 2 | Business | Phụ thuộc Layer 0–1 (Orders, Payroll) |
| 3 | Operations | Phụ thuộc Layer 0–2 (Logistics, QC) |
| 4 | Intelligence | Đọc dữ liệu từ tất cả (Reports, BI) |

---

## $LAYERS Structure

```json
[
  {
    "layer": 0,
    "phase": "Foundation",
    "modules": ["MOD-AUTH", "MOD-SHARED"],
    "parallel": true,
    "sprint": "S01"
  },
  {
    "layer": 1,
    "phase": "Core",
    "modules": ["MOD-CRM", "MOD-HR"],
    "parallel": true,
    "sprint": "S02"
  }
]
```

---

## LEGACY_MODE — Sprint Priority Adjustment

Nếu `$LEGACY_MODE = true` AND `$LEGACY_GAP_CONTEXT` chứa priority info:
- Cân nhắc gap priority khi assign sprint:
  - HIGH priority gaps → sprint sớm
  - LOW priority gaps → sprint cuối
- Modules có nhiều `IMPLEMENT_NEW` features → cân nhắc tách sprint riêng

---

## POST-GATE

`test $ASSIGNED = $TOTAL`

---

## Next

→ Checkpoint: position → `phase_5` (mvp) / `phase_6` (impact) / `phase_7` (default)
→ Nếu `--mvp` flag → Read `procedures/phase5-mvp.md`
→ Else nếu `--impact=<module>` flag → Read `procedures/phase6-impact.md`
→ Else → Read `procedures/phase7-outputs.md`
