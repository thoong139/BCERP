# Reports — Audit & Improvement Deliverables

> **Vai trò:** Catalog các báo cáo định kỳ + báo cáo tổng kết của plan.
> **Liên quan:**
> - [11-stages-and-gates.md](../11-stages-and-gates.md) — Khi nào sinh từng report
> - [13-definition-of-done.md](../13-definition-of-done.md) — DoD cho Sprint reports + Final report + Improvement report
> - [progress.md](../progress.md) — §"Sprint reports" hiển thị status canonical

## Status legend

- ⬜ Chưa bắt đầu
- 🟡 Đang viết
- ✅ Đã hoàn thành (theo DoD)

## Reports kỳ vọng

| # | Report | Path | Sinh tại stage | Status | DoD reference |
|---|---|---|---|:-:|---|
| 1 | Sprint 1 — QD1 hoàn thiện + QD3 | `sprint-1-report.md` | Stage 1 (sau QD1+QD3) | ⬜ | [13-DoD §Sprint 1](../13-definition-of-done.md) |
| 2 | Sprint 2 — QD6 + QD2 | `sprint-2-report.md` | Stage 1 (sau QD6+QD2) | ⬜ | [13-DoD §Sprint 2](../13-definition-of-done.md) |
| 3 | Sprint 3 — QD4 + QD5 + QD7 | `sprint-3-report.md` | Stage 1 (sau QD4+QD5+QD7) | ⬜ | [13-DoD §Sprint 3](../13-definition-of-done.md) |
| 4 | Sprint 4 — Stage 2 Consolidation | `sprint-4-report.md` | Stage 2 (Roadmap lock) | ⬜ | [13-DoD §Sprint 4](../13-definition-of-done.md) |
| 5 | Final report — G2 sign-off | `final-report.md` | Stage 2 G2 | ⬜ | [13-DoD §Sprint 4](../13-definition-of-done.md) |
| 6 | Improvement report — Stage 4 re-audit | `improvement-report.md` | Stage 4 | ⬜ | [11-Stages §Stage 4](../11-stages-and-gates.md) |

## Cấu trúc nội dung kỳ vọng (sprint reports)

Mỗi sprint report cần có 5 sections:
1. **Findings count summary** (FP/FN/EC/IMP per dim covered)
2. **Highlights** — top 3-5 phát hiện đáng chú ý (file:line evidence)
3. **Blockers** — vấn đề gặp phải + resolution (KHÔNG để trống)
4. **Decisions made** — quyết định mới đã ghi vào [12-decisions-log.md](../12-decisions-log.md)
5. **Next sprint plan adjustments** — nếu có

## Cấu trúc nội dung kỳ vọng (final-report.md)

- Roadmap final state (số IMP verified vs dropped)
- Cross-cutting themes consolidated (≥7)
- Stakeholder review minutes
- Sprint allocation cho Stage 3
- Risk + dependency map giữa IMPs

## Cấu trúc nội dung kỳ vọng (improvement-report.md)

- Pre/post comparison table (Precision, Recall, F1 per probe)
- Regression baseline updated cho `wf-fix-{dim}/evals/evals.json`
- IMPs implemented vs deferred
- Lessons learned + recommendations cho audit kỳ tiếp
