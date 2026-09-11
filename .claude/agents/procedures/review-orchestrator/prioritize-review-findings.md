# Playbook: Ưu tiên hóa Review Findings

> **Type**: Agent Skill Playbook
> **Agent**: review-orchestrator
> **Triggered by**: Sau khi nhận findings từ các auditors
> **Output**: Prioritized findings backlog với sprint plan và owner assignment

---

## Khi nào dùng playbook này

- Sau khi `orchestrate-devkit-review.md` hoàn thành và có raw findings
- Khi cần lập kế hoạch sprint để xử lý technical debt trong DEVKIT
- Khi có nhiều findings từ nhiều auditors cần được tổng hợp thành action items

---

## Procedure

### Bước 1: Thu thập raw findings

```
Nhận findings từ:
  - agent-auditor: findings về agent definitions
  - skill-auditor: findings về skill definitions
  - template-auditor: findings về doc-framework templates
  - cross-reference-auditor: findings về broken references
  - workflow-auditor: findings về workflow integrity

Consolidate thành 1 danh sách duy nhất.
```

### Bước 2: Categorize findings theo severity

```
CRITICAL — block workflow hoặc break functionality:
  □ Broken file paths (reference trỏ đến file không tồn tại)
  □ Missing required sections trong agent/skill definitions
  □ Broken handoff paths giữa skills
  □ Agent không tồn tại nhưng được reference

MAJOR — gây inconsistency, có thể dẫn đến lỗi:
  □ Deprecated skill/team names vẫn còn dùng
  □ README không khớp actual filesystem
  □ Orphan templates không ai sử dụng
  □ Agent thiếu coordination section (Island Agent)
  □ Workflow definition khác nhau giữa các sources

MINOR — style, suggestion, không ảnh hưởng functionality:
  □ Format không nhất quán
  □ Missing reciprocal coordination references
  □ Documentation gaps
  □ Agent size vượt guideline nhưng không critical
```

### Bước 3: Impact assessment

Với mỗi finding, đánh giá:

```
□ Files/components bị ảnh hưởng (số lượng)
□ User-facing impact: người dùng DEVKIT có bị ảnh hưởng không?
□ Fix effort: Easy (< 15 phút) / Medium (15-60 phút) / Hard (> 1 giờ)
□ Risk nếu không fix: Low / Medium / High
```

### Bước 4: Xác định dependencies giữa fixes

```
Một số fixes phải được thực hiện theo thứ tự nhất định:
  Ví dụ: sửa agent filename → sửa tất cả references đến agent đó

Map dependencies:
  Fix A phải hoàn thành TRƯỚC Fix B nếu:
  - Fix B phụ thuộc vào kết quả của Fix A
  - Fix A và Fix B cùng modify file → serialze để tránh conflict

Tạo dependency graph đơn giản (A → B → C).
```

### Bước 5: Sprint planning

```
Sprint 1 — Immediate (CRITICAL fixes):
  [List CRITICAL findings, ordered by dependency]

Sprint 2 — Next sprint (MAJOR fixes):
  [List MAJOR findings, Easy và Medium effort trước]

Backlog (MINOR fixes):
  [List MINOR findings, để cân nhắc khi có capacity]
```

### Bước 6: Owner assignment

```
Map mỗi finding đến agent phù hợp nhất để fix:
  Agent definition issues      → developer hoặc người update .claude/agents/
  Skill definition issues      → developer hoặc người update .claude/skills/
  Template issues              → developer hoặc người update .claude/doc-framework/
  Cross-reference issues       → developer (update paths/names)
  Workflow documentation       → developer (update rules/CLAUDE.md)
```

### Bước 7: Output — Prioritized Findings Backlog

```
Format output:

# Prioritized DEVKIT Findings Backlog
**Generated**: [date]
**Total**: [X CRITICAL] [Y MAJOR] [Z MINOR]

## Sprint 1 — Critical (Fix Immediately)
| ID | Finding | File | Effort | Owner |
|----|---------|------|--------|-------|
| C-001 | [mô tả] | [path] | [effort] | [owner] |

## Sprint 2 — Major (Next Sprint)
[Tương tự]

## Backlog — Minor
[Tương tự]

## Dependency Map
[A → B nếu A phải fix trước B]
```

---

## Checklist trước khi submit

```
□ Tất cả findings đã được categorize (không finding nào thiếu severity)
□ Impact assessment đã xong cho mọi CRITICAL và MAJOR
□ Dependencies đã được map rõ ràng
□ Sprint plan có thứ tự hợp lý (dependencies được tôn trọng)
□ Mỗi finding có owner được assign
□ MINOR findings không bị lẫn vào Sprint 1
```
