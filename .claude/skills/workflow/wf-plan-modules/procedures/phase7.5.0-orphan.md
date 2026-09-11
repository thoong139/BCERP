# Phase 7.5.0: Orphan System Placeholders (CONDITIONAL)

> CHỈ chạy khi `$COVERAGE_STRATEGY == "placeholders"` (từ Phase 1.7).
> Tạo `_NO-FEATURES.md` placeholder cho mỗi orphan system để tránh "silent skip".

> **Shared context:** xem `_shared.md` — State Variables (`$SYSTEM_COVERAGE_MAP`, `$COVERAGE_STRATEGY`).

---

## PRE-GATE

```
$COVERAGE_STRATEGY == "placeholders" AND len(orphan_systems) > 0
```

Nếu PRE-GATE fail → SKIP toàn bộ Phase 7.5.0, jump tới Phase 7.5.

---

## 📥 INPUT

- `$SYSTEM_COVERAGE_MAP` (in-memory từ Phase 1.7)
- Template: `templates/orphan-no-features.md.tpl`

## 📤 OUTPUT

| File | Đường dẫn | Template |
|------|-----------|---------|
| Orphan system placeholder | `.mc-data/docs/phase5-implementation/tasks/[sys-slug]/_NO-FEATURES.md` | `templates/orphan-no-features.md.tpl` |

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 7.5.0.1 | FOR mỗi orphan system: tính `sys-slug` từ `system.id` (lowercase, bỏ prefix `SYS-`, kebab-case) | Slug computed |
| 7.5.0.2 | `mkdir -p .mc-data/docs/phase5-implementation/tasks/[sys-slug]/` | Directory exists |
| 7.5.0.3 | **Template Usage Rule:** READ `templates/orphan-no-features.md.tpl` → POPULATE placeholders ([System Name], [system.id], [system.description], [YYYY-MM-DD]) → WRITE `.mc-data/docs/phase5-implementation/tasks/[sys-slug]/_NO-FEATURES.md` | `test -s _NO-FEATURES.md` |

---

## Slug Computation Examples

| System ID | Slug |
|-----------|------|
| `SYS-ERP-WEB` | `erp-web` |
| `SYS-MOBILE-STAFF` | `mobile-staff` |
| `SYS-BACKEND` | `backend` |

Algorithm:
```bash
sys_slug=$(echo "$SYS_ID" | sed 's/^SYS-//' | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
```

---

## Template Placeholders

Khi POPULATE template, replace:

| Placeholder | Value |
|-------------|-------|
| `[System Name]` | `system.name` từ registry |
| `[system.id]` | `system.id` (giữ nguyên prefix SYS-) |
| `[system.description]` | `system.description` từ registry |
| `[YYYY-MM-DD]` | Ngày hôm nay (format ISO) |

---

## POST-GATE

- Mỗi orphan system trong `$SYSTEM_COVERAGE_MAP` có file `_NO-FEATURES.md`
- File non-empty (`test -s`)

---

## Next

→ Checkpoint: position → `phase_7.5`
→ Read `procedures/phase7.5-tasks.md`
