# Template Usage Audit Prompts — DEVKIT Skills

> Tạo ngày: 2026-04-16 (cập nhật 2026-04-28 — thêm wf-scan-target)
> Mục đích: 29 prompts kiểm tra toàn diện Template Usage Rule (CORE-031) + thiết kế chung cho tất cả skills.
> Cách dùng: Copy từng PROMPT, paste vào Claude Code conversation để chạy audit.

---

## Phân nhóm Skills

| Nhóm | Skills | Số prompts |
|------|--------|-----------|
| A. Workflow skills (có templates) | wf-brainstorm → wf-legacy-extract + wf-scan-target (18 skills) | PROMPT 1-17, 17B |
| B. Audit skills (có templates) | audit-devkit-fix, audit-skill-output | PROMPT 18-19 |
| C. Skills không có templates | audit-agents, audit-devkit, audit-devkit-scan, audit-devkit-verify, status, ui-ux-pro-max | PROMPT 20-25 |
| D. Orchestrator workflows | new-project, existing-project, feature-addition | PROMPT 26-28 |

---

## Tình trạng xác minh — Templates

| # | Skill | Templates thực tế | Khớp Prompt? | Ghi chú |
|---|-------|-------------------|-------------|---------|
| 1 | wf-brainstorm | 2: brainstorm-status.json, project-intent-digest.json | SAI gốc → ĐÃ SỬA | Prompt gốc liệt kê `checkpoint.json` không tồn tại |
| 2 | wf-analyze-requirements | 5: checkpoint.json, analyze-status.json, department-digests.json, phase1-handoff.json, analyze-plan.md | OK | |
| 3 | wf-define-features | 5: checkpoint.json, define-features-status.json, feature-briefs.json, define-features-plan.md, ui-coverage-gaps.json | OK | |
| 4 | wf-design | 3: checkpoint.json, design-status.json, design-plan.md | OK | |
| 5 | wf-design-ux | 3: checkpoint.json, design-ux-status.json, design-ux-plan.md | OK | |
| 6 | wf-plan-modules | 3: checkpoint.json, planmod-status.json, planmod-plan.md | OK | |
| 7 | wf-implement-feature | 7: checkpoint.json, impl-status.json, impl-plan.md, impl-report.md, qa-review-report.md, decision-registry.json, existing-patterns.json | OK | |
| 8 | wf-preflight | 4: checkpoint.json, preflight-status.json, preflight-report.md, preflight-history.md | OK | |
| 9 | wf-verify-sync | 3: checkpoint.json, verify-sync-status.json, ui-coverage-report.md | OK | |
| 10 | wf-fix-bugs | 6: checkpoint.json, fix-status.json, fix-plan.md, fix-report.md, fix-history.md, bug-triage.md | OK | |
| 11 | wf-prepare-deployment | 3: checkpoint.json, prepare-deployment-status.json, prepare-deployment-plan.md | OK | |
| 12 | wf-annotate-code | 4: annotate-status.json, annotate-checkpoint.json, annotate-plan.md, annotation-report.md | OK | |
| 13 | wf-add-scope | 4: add-scope-plan.md, add-scope-status.json, feature-stub.md, scope-spec.json | OK | |
| 14 | wf-manage-change | 9: checkpoint.json, change-status.json, change-intake.json, affected-artifacts.json, impact-report.md, change-plan.md, change-analysis.md, change-report.md, index.json | OK | |
| 15 | wf-legacy-classify | 2: glossary.json, classify-plan.md | OK | |
| 16 | wf-legacy-extract | 4: extract-plan.md, extract-status.json, extract-checkpoint.json, extracted-module.json | OK | |
| 17 | wf-legacy-scan | 9: session-digest.md, assessment-report.json, error-ledger.json, legacy-scan-contract.json, legacy-pipeline-contract.json, legacy-scan-plan.md, legacy-scan-status.json, ledger.json, project-profile.json | OK | Thiếu trong 16 prompts gốc |
| 17B | wf-scan-target | 8: checkpoint.json, scan-status.json, target-map.json, module-map.md, feature-inventory.md, gap-report.md, phase-summary.md, scans-index-entry.json | OK | Mới thêm 2026-04-28 (v2.0.0) |
| 18 | audit-devkit-fix | 2: fix-log.template.json, fix-status.template.json | OK | Mới thêm |
| 19 | audit-skill-output | 3: checkpoint.json, audit-status.json, audit-report.md | OK | Mới thêm |
| 20 | audit-agents | 0 (không có templates/) | N/A | Audit thiết kế chung |
| 21 | audit-devkit | 0 (không có templates/) | N/A | Audit thiết kế chung |
| 22 | audit-devkit-scan | 0 (không có templates/) | N/A | Audit thiết kế chung |
| 23 | audit-devkit-verify | 0 (không có templates/) | N/A | Audit thiết kế chung |
| 24 | status | 0 (không có templates/) | N/A | Audit thiết kế chung |
| 25 | ui-ux-pro-max | 0 (không có templates/) | N/A | Audit thiết kế chung |
| 26 | new-project | 0 (không có templates/) | N/A | Audit orchestrator |
| 27 | existing-project | 0 (không có templates/) | N/A | Audit orchestrator |
| 28 | feature-addition | 0 (không có templates/) | N/A | Audit orchestrator |

---

# NHÓM A: Workflow Skills (có templates)

---

## PROMPT 1: wf-brainstorm

> **GHI CHÚ:** Prompt gốc liệt kê `checkpoint.json` nhưng file này KHÔNG tồn tại. Đã sửa.

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-brainstorm xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-brainstorm\templates (brainstorm-status.json, project-intent-digest.json) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 2: wf-analyze-requirements

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-analyze-requirements xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-analyze-requirements\templates (checkpoint.json, analyze-status.json, department-digests.json, phase1-handoff.json, analyze-plan.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 3: wf-define-features

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-define-features xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-define-features\templates (checkpoint.json, define-features-status.json, feature-briefs.json, define-features-plan.md, ui-coverage-gaps.json) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 4: wf-design

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-design xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-design\templates (checkpoint.json, design-status.json, design-plan.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ? Cross-check với _contract.json xem tất cả templates đã được map đúng vào outputs chưa.
```

---

## PROMPT 5: wf-design-ux

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-design-ux xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-design-ux\templates (checkpoint.json, design-ux-status.json, design-ux-plan.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 6: wf-plan-modules

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-plan-modules xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-plan-modules\templates (checkpoint.json, planmod-status.json, planmod-plan.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 7: wf-implement-feature

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-implement-feature xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-implement-feature\templates (checkpoint.json, impl-status.json, impl-plan.md, impl-report.md, qa-review-report.md, decision-registry.json, existing-patterns.json) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 8: wf-preflight

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-preflight xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-preflight\templates (checkpoint.json, preflight-status.json, preflight-report.md, preflight-history.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 9: wf-verify-sync

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-verify-sync xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-verify-sync\templates (checkpoint.json, verify-sync-status.json, ui-coverage-report.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 10: wf-fix-bugs

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-fix-bugs xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-fix-bugs\templates (checkpoint.json, fix-status.json, fix-plan.md, fix-report.md, fix-history.md, bug-triage.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 11: wf-prepare-deployment

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-prepare-deployment xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-prepare-deployment\templates (checkpoint.json, prepare-deployment-status.json, prepare-deployment-plan.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 12: wf-annotate-code

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-annotate-code xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-annotate-code\templates (annotate-status.json, annotate-checkpoint.json, annotate-plan.md, annotation-report.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 13: wf-add-scope

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-add-scope xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-add-scope\templates (add-scope-plan.md, add-scope-status.json, feature-stub.md, scope-spec.json) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 14: wf-manage-change

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-manage-change xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-manage-change\templates (checkpoint.json, change-status.json, change-intake.json, affected-artifacts.json, impact-report.md, change-plan.md, change-analysis.md, change-report.md, index.json) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 15: wf-legacy-classify

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-legacy-classify xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-legacy-classify\templates (glossary.json, classify-plan.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 16: wf-legacy-extract

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-legacy-extract xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-legacy-extract\templates (extract-plan.md, extract-status.json, extract-checkpoint.json, extracted-module.json) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ?
```

---

## PROMPT 17: wf-legacy-scan

> **GHI CHÚ:** Skill này có 9 templates nhưng bị thiếu trong 16 prompts gốc.

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-legacy-scan xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-legacy-scan\templates (session-digest.md, assessment-report.json, error-ledger.json, legacy-scan-contract.json, legacy-pipeline-contract.json, legacy-scan-plan.md, legacy-scan-status.json, ledger.json, project-profile.json) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ? Cross-check với _contract.json xem tất cả templates đã được map đúng vào outputs chưa.
```

---

## PROMPT 17B: wf-scan-target

> **GHI CHÚ:** Skill mới thêm 2026-04-28 (v2.0.0) — standalone, không thuộc main pipeline.

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflow\wf-scan-target xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\workflow\wf-scan-target\templates (checkpoint.json, scan-status.json, target-map.json, module-map.md, feature-inventory.md, gap-report.md, phase-summary.md, scans-index-entry.json) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ? Cross-check với _contract.json xem tất cả templates đã được map đúng vào outputs chưa.
```

---

# NHÓM B: Audit Skills (có templates)

---

## PROMPT 18: audit-devkit-fix

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\audit-devkit-fix xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\audit-devkit-fix\templates (fix-log.template.json, fix-status.template.json) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ? Cross-check với _contract.json xem tất cả templates đã được map đúng vào outputs chưa.
```

---

## PROMPT 19: audit-skill-output

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\audit-skill-output xem đã được thiết kế đúng chưa ? Các file trong Z:\Working\MCV3\.claude\skills\audit-skill-output\templates (checkpoint.json, audit-status.json, audit-report.md) có được sử dụng khi skill làm việc không ? Template Usage Rule (READ template → POPULATE → WRITE) có được enforce trong SKILL.md steps chưa ? Cross-check với _contract.json xem tất cả templates đã được map đúng vào outputs chưa.
```

---

# NHÓM C: Skills không có templates (audit thiết kế chung)

> Các skills này không có `templates/` directory. Prompt tập trung vào _contract.json, SKILL.md design, evals/ và protocols/ references.

---

## PROMPT 20: audit-agents

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\audit-agents xem đã được thiết kế đúng chưa ? Skill này không có templates/ directory — tập trung kiểm tra: (1) _contract.json có schema hợp lệ và fields đầy đủ không, (2) SKILL.md có flow rõ ràng với PRE-GATE → EXECUTION → POST-GATE không, (3) SKILL.md có tham chiếu protocols/ không, (4) evals/evals.json có ít nhất 3 test cases không ?
```

---

## PROMPT 21: audit-devkit

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\audit-devkit xem đã được thiết kế đúng chưa ? Skill này là meta-audit orchestrator — kiểm tra: (1) _contract.json có schema hợp lệ không, (2) SKILL.md có flow rõ ràng gọi đúng sub-skills (audit-devkit-scan → audit-devkit-verify → audit-devkit-fix) không, (3) evals/evals.json có ít nhất 3 test cases không, (4) Có tham chiếu protocols/ không ?
```

---

## PROMPT 22: audit-devkit-scan

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\audit-devkit-scan xem đã được thiết kế đúng chưa ? Skill này không có templates/ directory — tập trung kiểm tra: (1) _contract.json có schema hợp lệ và fields đầy đủ không, (2) SKILL.md có flow rõ ràng với PRE-GATE → EXECUTION → POST-GATE không, (3) SKILL.md có tham chiếu protocols/ không, (4) evals/evals.json có ít nhất 3 test cases không ?
```

---

## PROMPT 23: audit-devkit-verify

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\audit-devkit-verify xem đã được thiết kế đúng chưa ? Skill này không có templates/ directory — tập trung kiểm tra: (1) _contract.json có schema hợp lệ và fields đầy đủ không, (2) SKILL.md có flow rõ ràng với PRE-GATE → EXECUTION → POST-GATE không, (3) SKILL.md có tham chiếu protocols/ không, (4) evals/evals.json có ít nhất 3 test cases không ?
```

---

## PROMPT 24: status

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\status xem đã được thiết kế đúng chưa ? Skill này không có templates/ directory — tập trung kiểm tra: (1) _contract.json có schema hợp lệ và fields đầy đủ không, (2) SKILL.md có flow rõ ràng không, (3) Có đọc đúng req-registry.json và phase docs để báo cáo tiến độ không, (4) Output format có đủ thông tin cho user hiểu trạng thái dự án không ?
```

---

## PROMPT 25: ui-ux-pro-max

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\ui-ux-pro-max xem đã được thiết kế đúng chưa ? Skill này là standalone (không trong workflow/) và không có templates/ directory — kiểm tra: (1) _contract.json có schema hợp lệ không, (2) SKILL.md có flow rõ ràng không, (3) Có tham chiếu đúng design agents (ux-designer, ui-designer, ux-architect) không, (4) Output có đủ chất lượng professional UI/UX design system không ?
```

---

# NHÓM D: Orchestrator Workflows

> 3 orchestrator skills không có `templates/` — chúng điều phối workflow skills. Prompt tập trung vào orchestration logic, _contract.json, và integration giữa các wf-* skills.

---

## PROMPT 26: new-project

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflows\new-project xem đã được thiết kế đúng chưa ? Đây là orchestrator cho dự án mới — kiểm tra: (1) _contract.json có schema hợp lệ không, (2) SKILL.md có flow gọi đúng thứ tự wf-* skills (wf-brainstorm → wf-analyze-requirements → ... → wf-prepare-deployment) không, (3) Có cơ chế resume/recovery khi dừng giữa chừng không, (4) Có truyền context đúng giữa các phases không, (5) Có enforce CORE-002 (không skip phases) không ?
```

---

## PROMPT 27: existing-project

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflows\existing-project xem đã được thiết kế đúng chưa ? Đây là orchestrator cho dự án có sẵn — kiểm tra: (1) _contract.json có schema hợp lệ không, (2) SKILL.md có flow gọi đúng thứ tự legacy pipeline (wf-legacy-scan → wf-legacy-classify → wf-legacy-extract → wf-brainstorm → ...) không, (3) Có truyền đúng project-context.md và legacy-decisions.json giữa các phases không, (4) Có cơ chế resume/recovery không, (5) Có enforce CORE-021 (LEGACY_MODE detection) không ?
```

---

## PROMPT 28: feature-addition

```
Tôi muốn kiểm tra toàn diện skill Z:\Working\MCV3\.claude\skills\workflows\feature-addition xem đã được thiết kế đúng chưa ? Đây là orchestrator cho thêm features (Phase 3+) — kiểm tra: (1) _contract.json có schema hợp lệ không, (2) SKILL.md có flow đúng cho feature addition (wf-add-scope → wf-define-features → wf-design → wf-design-ux → wf-plan-modules → wf-implement-feature) không, (3) Có đọc đúng req-registry.json để xác định vị trí phase hiện tại không, (4) Có đảm bảo không skip phases không, (5) Có cơ chế resume/recovery không ?
```
