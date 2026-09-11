# Phase 3: Phát hiện Circular Dependencies

> Traverse dependency graph (DFS), detect cycles, đề xuất solutions nếu có.

> **Shared context:** xem `_shared.md` — State Variables (`$DEP_MATRIX`, `$HAS_CYCLE`).

---

## PRE-GATE

`test -n "$DEP_MATRIX"`

## 📥 INPUT

- `$DEP_MATRIX` (in-memory từ Phase 2)

> Xử lý in-memory (DFS graph traversal) — không đọc/tạo file mới.

## 📤 OUTPUT

- `$HAS_CYCLE` (in-memory) — Boolean, "true" nếu phát hiện cycle
- `$DEP_MATRIX` (updated nếu cycle được resolve)

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 3.1 | Traverse graph (DFS) | Traversal complete |
| 3.2 | Detect cycles | Cycle check done |
| 3.3 | Nếu có cycle → đề xuất solutions, STOP đợi user | Solutions ready |

---

## Khi phát hiện circular dependency

```
Circular Dependency: Orders → Inventory → Procurement → Orders

Giải pháp:
1. Event-Driven: A publish event, C subscribe
2. Shared Entity: Tách entity chung ra SharedKernel
3. Interface Abstraction: A phụ thuộc interface, không implementation
```

Dừng và chờ user chọn giải pháp trước khi tiếp tục. Sau khi user chọn:

- **Event-Driven** → cập nhật `$DEP_MATRIX` để loại edge tạo cycle, set `$HAS_CYCLE = "false"`
- **Shared Entity** → user phải tách entity (manual) → re-run `/wf-plan-modules` từ đầu
- **Interface Abstraction** → cập nhật `$DEP_MATRIX` (A phụ thuộc interface trừu tượng), set `$HAS_CYCLE = "false"`

---

## POST-GATE

`test "$HAS_CYCLE" = "false"`

---

## Next

→ Checkpoint: position → `phase_4`
→ Read `procedures/phase4-topo.md`
