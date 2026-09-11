# Phase 6: Impact Analysis (chỉ khi `--impact=<module>`)

> Conditional phase — phân tích impact khi thay đổi 1 module cụ thể.
> **Chỉ chạy khi user truyền `--impact=<module>` flag** → `$IMPACT_MODULE` set.

> **Shared context:** xem `_shared.md` — State Variables (`$DEP_MATRIX`, `$IMPACT_MODULE`, `$IMPACT_REPORT`).

---

## PRE-GATE

`test -n "$IMPACT_MODULE"`

Nếu PRE-GATE fail → SKIP toàn bộ Phase 6, jump tới Phase 7.

## 📥 INPUT

- `$DEP_MATRIX` (in-memory từ Phase 2)
- `$IMPACT_MODULE` (in-memory từ Phase 0 arg parsing)
- Registry (modules list)

## 📤 OUTPUT

- `$IMPACT_REPORT` (in-memory) — Impact analysis report với Direct/Indirect/No Impact categories

> Phase điều kiện — xử lý in-memory, không tạo file riêng.

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 6.1 | Validate module tồn tại trong registry | Module found |
| 6.2 | Tìm direct + indirect dependencies (forward + backward) | All deps listed |
| 6.3 | Phân loại impact level | Categories assigned |

---

## Impact Categories

- **Direct** — gọi trực tiếp API/Entity → bắt buộc test
- **Indirect** — phụ thuộc gián tiếp → có thể ảnh hưởng
- **No Impact** — không có dependency path → an toàn

---

## $IMPACT_REPORT Structure

```
🔍 Impact Analysis: [$IMPACT_MODULE]
────────────────────────────────────────
Direct Impact ([N] modules):
  - MOD-XXX (gọi API getInventory)
  - MOD-YYY (tham chiếu Entity Order)

Indirect Impact ([M] modules):
  - MOD-ZZZ (phụ thuộc MOD-XXX)

No Impact:
  - [N modules còn lại]

Test Strategy:
  - Direct modules: BẮT BUỘC test
  - Indirect modules: smoke test
```

---

## POST-GATE

`test -n "$IMPACT_REPORT"`

---

## Next

→ Checkpoint: position → `phase_7`
→ Read `procedures/phase7-outputs.md`
