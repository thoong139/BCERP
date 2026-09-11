<!--
_template_notes:
  purpose: Index 9 file design canon + entry point cho contributor đọc.
  populate:
    - Đổi mọi `{skill-name}` thành tên skill (e.g., wf-my-new-skill)
    - Đổi `{Skill Display Name}` thành tên đẹp (e.g., "Fix Bugs Orchestrator")
    - Cập nhật version, date, owner trong header
    - Trong bảng "Files" §3: tick từng file đã viết, để [ ] cho file chưa có
    - Xóa toàn bộ block _template_notes (HTML comment này) trước commit
-->

# {Skill Display Name} — Design Canon

> **Skill:** `{skill-name}` (v{X.Y.Z})
> **Owner:** {role / team / GitHub handle}
> **Cập nhật lần cuối:** YYYY-MM-DD

---

## 1. Đọc theo persona

| Persona | Đọc trước |
|---------|-----------|
| **Skill author tạo skill mới** | 01-vision → **03-architecture** → 03-phase-routing → 04-file-contract → 07-procedures |
| **Skill author sửa skill** | 08-tradeoffs-adr → 03-architecture → file bị ảnh hưởng |
| **Reviewer review PR** | 09-evals → 04-file-contract → 03-architecture → file bị ảnh hưởng |
| **End-user gặp bug** | [`../../06-user-guides/per-skill/{skill-name}-*.md`](../../06-user-guides/per-skill/) |

---

## 2. Tóm tắt 1 dòng

`{skill-name}` — {1 câu mô tả: skill làm gì, cho ai}

**Trigger:** `/{skill-name} [args]` hoặc spawned bởi `{parent-skill}` ở phase Y
**Phase trong workflow:** Phase {N} ({tên phase})
**Đầu vào chính:** {file/state cần có trước}
**Đầu ra chính:** {file/state sinh ra}

---

## 3. Files (10)

| # | File | Mục đích | Optional sections | Trạng thái |
|---|------|----------|-------------------|-----------|
| 01 | [01-vision-principles.md](01-vision-principles.md) | Tại sao có skill, mục tiêu, scope | §7 Domain context (nếu chạm domain knowledge) | [ ] |
| 02 | [02-arguments.md](02-arguments.md) | Bảng arguments + defaults | §5 Profile detail (nếu có `--profile`) | [ ] |
| 03a | [03-architecture.md](03-architecture.md) | **Kiến trúc tổng quan** — components, data flow, state machine | §4 Parallelism (nếu có lane), §8 State machine (nếu có branching) | [ ] |
| 03b | [03-phase-routing.md](03-phase-routing.md) | Trình tự phases — phase routing map + flow diagram | §6 Regression-aware skipping (nếu có `--since`/`--incremental`) | [ ] |
| 04 | [04-file-contract.md](04-file-contract.md) | PRE-GATE/POST-GATE + cross-skill | §6 Business invariants (nếu chạm business rules) | [ ] |
| 05 | [05-error-codes.md](05-error-codes.md) | Namespace E0xx + auto-fix budget | — | [ ] |
| 06 | [06-templates-list.md](06-templates-list.md) | Templates output dùng | — | [ ] |
| 07 | [07-procedures-structure.md](07-procedures-structure.md) | `_shared.md` + `phase{N}-*.md` outline | — | [ ] |
| 08 | [08-tradeoffs-adr.md](08-tradeoffs-adr.md) | ADR cho các decisions trong skill | — | [ ] |
| 09 | [09-evals-test-cases.md](09-evals-test-cases.md) | Test cases ≥3 + eval criteria | — | [ ] |

> **Lưu ý 03-architecture vs 03-phase-routing:** Hai file bổ sung nhau, KHÔNG trùng lặp.
> - `03-architecture.md` tả **CẤU TRÚC** (cái gì có) — components, data flow, integration points.
> - `03-phase-routing.md` tả **TRÌNH TỰ** (chạy theo thứ tự nào) — phase map, profile dispatch, conditional skip.
> - Sort alphabet: `03-architecture` < `03-phase-routing` (do `a` < `p`) → architecture đứng trước trong `ls`.

**Optional sections:** chỉ điền khi skill thực sự chạm engine tương ứng (xem [`docs/01-architecture/10-mcv3-engines-overview.md`](../../01-architecture/10-mcv3-engines-overview.md) §3 — bảng "Định vị engine khi tạo skill mới"). Bỏ trống nếu không applicable, KHÔNG nhồi nội dung giả.

---

## 4. Liên kết

- Skill source: [`.claude/skills/workflow/{skill-name}/`](../../../.claude/skills/workflow/) (SKILL.md, procedures/, _contract.json, evals/)
- Review checklist: [`../../05-review-standards/{skill-name}.md`](../../05-review-standards/)
- User guide: [`../../06-user-guides/per-skill/`](../../06-user-guides/per-skill/) (nếu có)
- Standards áp dụng: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md)
- Patterns dùng: [`../../03-design-patterns/`](../../03-design-patterns/)
- 15 engines map (định vị engine ↔ design file): [`../../01-architecture/10-mcv3-engines-overview.md`](../../01-architecture/10-mcv3-engines-overview.md)
