---
status: ARCHIVED
archived_at: 2026-05-16
archived_by: Eureka (ERK Transport) + Claude Code
replaced_by: docs/04-skill-design/wf-fix-bugs/ (Design v2.0)
preserve_for: ADR history v5.1 → v6.1 transition
---

# Archive Note — wf-fix-bugs Design v1.0

## Vì sao archive

Bộ 10 file design v1.0 (2026-04-20 → 2026-04-22) mô tả kiến trúc của `wf-fix-bugs` ở giai đoạn implementation **v6.1.0** — 3 sub-skills (`wf-fix-discover/triage/execute`) + Signal Bus + Shared Services + 7 Quality Dimensions (QD1-QD7).

Skill đã trải qua nhiều đợt overhaul lớn từ v6.1.0 → **v10.18.0** (2026-05-16, ngày archive):

| Đợt | Thay đổi cốt lõi |
|-----|-------------------|
| **v7.0 (2026-04-29)** | Pure orchestrator + session isolation + CDG gates + 10 lane skills v7+. ADR-style overhaul `plans/wf-fix-bugs-v7-overhaul.md`. |
| **v8.x (2026-05-09 → 2026-05-10)** | Signals.json overwrite fix + QD8 Observability lane + schema unify. |
| **v9.x (2026-05-10)** | QD9 Runtime Health (Playwright) + QD10 Cross-Module Integration + dispatch drift patch. |
| **v9.1 (2026-05-10)** | QD11 Business Completeness — 3-pass LLM analysis. |
| **v10.0 (2026-05-13)** | **Đại tu kiến trúc:** 7-phase pipeline (Init→Scan→Plan→Find Bugs→Triage→Execute→Verify), lazy-load procedures (CORE-032), CI PRE-GATE (CORE-033), namespaced error codes (CORE-034), session subdirectories (CORE-035), cross-skill artifact contract (CORE-036), 8-section agent prompt templates (CORE-037), context budget management (CORE-038). 32 templates + Playwright 3 modes. |
| **v10.3 → v10.18 (2026-05-16)** | Optimization waves T1-T10 — parallel waves, shared trace scripts, lazy-load split per phase. Pipeline ≤6K tokens/phase. |

Design v1.0 KHÔNG còn mô tả đúng skill thực tế. Bộ docs **v2.0** ở `docs/04-skill-design/wf-fix-bugs/` mô tả v10.18.0.

## Giá trị giữ lại

Bộ v1.0 vẫn quan trọng vì:

1. **ADR-01 → ADR-24** — quyết định gốc về Dimension-based axis, Signal Bus utility, Issue schema v2, default profile shift (QD1+QD2+QD5), Safety Defaults non-negotiable. Các quyết định này vẫn được tôn trọng trong v10.18.0.
2. **North Star** (09-design-decisions.md §1) — vẫn là kim chỉ nam: "đảm bảo không có lỗi logic, nghiệp vụ, UI hoạt động 100%".
3. **Q14-Q23 lockings** — operational decisions về ISG, Workload Gate, 4-level checkpoint, Scan Cache… còn áp dụng (đã thực thi trong v10.x).
4. **12 bug categories → 7 QD mapping** (02-quality-dimensions.md §"Map Nhanh") — cơ sở để v9.1 mở rộng thêm QD8-QD11.
5. **Migration roadmap v5 → v6** (06-migration-plan.md) — historical reference cho ai cần hiểu vì sao bỏ `wf-fix-discover/`.

## Tham chiếu

- Design v2.0 (canonical): `docs/04-skill-design/wf-fix-bugs/README.md`
- Skill thực tế: `.claude/skills/workflow/wf-fix-bugs/SKILL.md` (v10.18.0)
- Skill contract: `.claude/skills/workflow/wf-fix-bugs/_contract.json` (v10.18.0)
- Lịch sử triển khai: `plans/wf-fix-bugs-v7-overhaul/`, `plans/wf-fix-bugs-v9*/`, `plans/wf-fix-bugs-v10-redesign/`

> Đọc design v2.0 trước. Chỉ đọc bộ này khi cần tham chiếu quyết định gốc hoặc context evolution.
