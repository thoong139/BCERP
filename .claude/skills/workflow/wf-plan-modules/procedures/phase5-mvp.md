# Phase 5: MVP Scope (chỉ khi `--mvp`)

> Conditional phase — xác định MVP scope với minimal modules cần thiết cho core flow.
> **Chỉ chạy khi `$HAS_MVP_FLAG = "true"`** (user truyền `--mvp` flag).

> **Shared context:** xem `_shared.md` — State Variables (`$LAYERS`, `$MVP_SCOPE`, `$MVP_SIZE`).

---

## PRE-GATE

`test "$HAS_MVP_FLAG" = "true"`

Nếu PRE-GATE fail → SKIP toàn bộ Phase 5, jump tới Phase 6 hoặc Phase 7.

## 📥 INPUT

- `$DEP_MATRIX` (in-memory từ Phase 2)
- `$LAYERS` (in-memory từ Phase 4)
- Registry features có priority=high hoặc user-specified core modules

## 📤 OUTPUT

- `$MVP_SCOPE` (in-memory) — Array module IDs trong MVP scope
- `$MVP_SIZE` (in-memory) — Số modules trong MVP

> Phase điều kiện — xử lý in-memory, không tạo file riêng.

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 5.1 | Xác định core business flow (từ user input hoặc registry features có priority=high) | Core flow identified |
| 5.2 | Trace dependencies ngược (backward) — từ core modules trace tất cả modules required | Required modules listed |
| 5.3 | Loại bỏ "nice to have" modules | MVP list finalized |

---

## MVP Determination Logic

```
core_modules = identify_from_user_or_priority()
required_set = []

FUNCTION trace_deps(module):
  IF module IN required_set: RETURN
  required_set ++= [module]
  FOR dep IN $DEP_MATRIX[module]:
    trace_deps(dep)

FOR each core_module IN core_modules:
  trace_deps(core_module)

$MVP_SCOPE = required_set
$MVP_SIZE = len(required_set)
```

---

## MVP Output

Hiển thị cho user:

```
🎯 MVP Scope Analysis
────────────────────────────────
Core flow: [user-specified or high-priority modules]
MVP modules ([$MVP_SIZE] total):
  Layer 0: [module list]
  Layer 1: [module list]
  ...

Excluded ("nice to have"): [module list]
```

---

## POST-GATE

`test $MVP_SIZE -gt 0`

---

## Next

→ Checkpoint: position → `phase_6` (impact) / `phase_7` (default)
→ Nếu `--impact=<module>` flag → Read `procedures/phase6-impact.md`
→ Else → Read `procedures/phase7-outputs.md`
