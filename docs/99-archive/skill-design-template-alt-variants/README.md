# Skill Design Template — Variant Files (Archived)

> **Status:** ARCHIVED (2026-05-16) — di chuyển từ `docs/04-skill-design/_template/` khi nâng template lên v3.2.
> **Lý do archive:** Không thuộc bảng "Files (10)" trong `_template/README.md`. Là di sản từ schema v3.0 (wf-fix-bugs).
> **Không xóa:** Vẫn hữu ích làm reference khi cần tạo lane/orchestrator skill variants.

---

## Files trong folder này

| File | Khi nào tham khảo |
|------|-------------------|
| `02-quality-dimensions.alt.md` | Khi tạo **lane/probe skill** (vd: `wf-fix-functional`, `wf-fix-security`) — thay thế `02-arguments.md` |
| `05-execution-profiles.alt.md` | Khi tạo skill có `--profile=quick\|standard\|deep\|exhaustive` — bổ sung cho `05-error-codes.md` |
| `08-user-scenarios.alt.md` | Khi tạo **orchestrator skill** (spawn ≥3 lanes) — bổ sung cho `08-tradeoffs-adr.md` |

---

## Cách dùng

Nếu skill mới thuộc loại trên:

1. Copy `docs/04-skill-design/_template/` thành `docs/04-skill-design/{skill-name}/` như bình thường.
2. Copy file `.alt.md` tương ứng từ folder này về skill folder, đổi tên (bỏ `.alt`):
   ```bash
   cp docs/99-archive/skill-design-template-alt-variants/02-quality-dimensions.alt.md \
      docs/04-skill-design/{skill-name}/02-quality-dimensions.md
   ```
3. Đối với lane skill: **xóa** `02-arguments.md` mặc định (vì đã được thay bằng `02-quality-dimensions.md`).
4. Populate nội dung theo `_template_notes:` block trong file, sau đó xóa block notes.
5. Update `docs/04-skill-design/README.md` §3 — note variant đã chọn.

---

## Decision tree (từ `_template/00-master-checklist.md`)

| Loại skill | Phases | Spawn agents? | Cần thêm file nào từ folder này? |
|---|---|---|---|
| **Quick** | 1-2 | ❌ | Không |
| **Standard** | 3-5 | Có thể | Không (dùng `_template/` đầy đủ) |
| **Lane/Probe** | 1-2 | Spawn từ orchestrator | `02-quality-dimensions.alt.md` + `05-execution-profiles.alt.md` |
| **Orchestrator** | 5-7 | ≥3 lanes | `08-user-scenarios.alt.md` |

---

## Liên kết

- Active template: [`../../04-skill-design/_template/`](../../04-skill-design/_template/) (v3.2 — 10 file standard)
- Catalog hiện trạng: [`../../04-skill-design/README.md`](../../04-skill-design/README.md)
- Skill standard: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md)
