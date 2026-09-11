# 08 — Reference

> **Mục đích:** Tài liệu **tra cứu nhanh** (cheatsheets, schemas, quick-lookups) — bám sát ground truth `.claude/skills/`, `.claude/rules/`, `_contract.json`.
> **Khác với `02-standards/`:** Reference tóm tắt + tra cứu; Standards diễn giải đầy đủ + ràng buộc bắt buộc.

---

## 1. Cheatsheets

| File | Mục đích | Khi nào dùng |
|------|----------|--------------|
| [`skill-anatomy-quick.md`](skill-anatomy-quick.md) | Tóm tắt 1-trang giải phẫu skill (≤500 dòng SKILL.md, procedures/, templates/, ...) | Quick lookup khi review/sửa skill |
| [`microtask-schema.md`](microtask-schema.md) | Schema cho microtask object (used in `wf-plan-modules` outputs) | Khi viết/parse task files |

---

## 2. Liên kết tới ground truth

| Khi cần tra cứu | Source canonical |
|----------------|------------------|
| 38 CORE rules + 4 BHV principles | [`../02-standards/01-core-rules-index.md`](../02-standards/01-core-rules-index.md) |
| Skill anatomy đầy đủ | [`../02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md) |
| Error code registry E001-E999 | [`../02-standards/08-error-code-registry.md`](../02-standards/08-error-code-registry.md) |
| Output path contract `.mc-data/` | [`../02-standards/11-output-path-contract.md`](../02-standards/11-output-path-contract.md) |
| Skill catalog (43 skills) | [`../01-architecture/07-skills-catalog.md`](../01-architecture/07-skills-catalog.md) |
| Protocol overview (22 protocols) | [`../01-architecture/06-protocols-overview.md`](../01-architecture/06-protocols-overview.md) |
| Glossary thuật ngữ | [`../00-overview/03-glossary.md`](../00-overview/03-glossary.md) |

---

## 3. Khi tạo cheatsheet mới

| Đặc điểm | Nên / Không nên |
|---------|-----------------|
| Độ dài | ≤200 dòng, ưu tiên bảng + bullet, ít prose |
| Nội dung | Chỉ tóm tắt — KHÔNG diễn giải đầy đủ |
| Liên kết | LUÔN trỏ tới canonical source ở cuối |
| Cập nhật | Khi canonical source thay đổi, cheatsheet phải cập nhật theo (hoặc xóa nếu drift) |

**Anti-pattern:** Cheatsheet trở thành "secondary source of truth" — gây drift với canonical. Phải luôn trỏ về source.

---

## 4. Liên kết

- **Standards (canonical):** [`../02-standards/`](../02-standards/)
- **Architecture:** [`../01-architecture/`](../01-architecture/)
- **Glossary:** [`../00-overview/03-glossary.md`](../00-overview/03-glossary.md)
