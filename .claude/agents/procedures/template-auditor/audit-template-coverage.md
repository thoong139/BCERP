# Playbook: Audit Template Coverage

> **Type**: Agent Skill Playbook
> **Agent**: template-auditor
> **Triggered by**: Khi review doc-framework templates tổng thể
> **Output**: Template Coverage Audit Report với usage map

---

## Khi nào dùng playbook này

- Khi review-orchestrator yêu cầu `--templates` scope
- Khi thêm skill mới và cần kiểm tra template gap
- Khi refactor doc-framework và cần biết template nào đang được dùng

---

## Procedure

### Bước 1: Inventory templates thực tế

```
Glob: .claude/doc-framework/**/*.md

Tạo danh sách đầy đủ tất cả template files.
Phân nhóm theo phase:
  phase0-brainstorm/
  phase1-business/
  phase2-features/
  phase3-architecture/
  phase4-ux/
  phase5-implementation/
  phase6-deployment/
  _meta/ (nếu có)
```

### Bước 2: Đọc README để xem templates đã documented

```
READ: .claude/doc-framework/README.md

Extract:
  □ Danh sách templates được liệt kê trong README
  □ Mô tả từng template
  □ Paths được ghi trong README
```

### Bước 3: Inventory skills sử dụng templates

```
Glob: .claude/skills/**/SKILL.md

Với mỗi SKILL.md:
  Grep: tìm pattern .claude/doc-framework/ để extract template references
  Lưu: {skill_name: [template_paths]}
```

### Bước 4: Xây dựng coverage matrix

```
Tạo matrix: template → [skills sử dụng]

Với mỗi template file:
  Tìm trong danh sách {skill: template_paths} xem có skill nào reference không

Kết quả 3 loại:
  COVERED: template được ít nhất 1 skill reference
  ORPHAN:  template không được skill nào reference (MAJOR issue)
  MISSING: skill reference template không tồn tại (CRITICAL issue)
```

### Bước 5: Validate template structure

Với mỗi template file:

```
□ Có title/purpose description ở đầu file?
□ Có placeholders không? Format: [PLACEHOLDER_NAME] hoặc {{ placeholder }}?
□ Placeholder format nhất quán trong cùng template?
□ Có instructions/guidance cho người điền template?
□ Có ví dụ output (example) không?
```

### Bước 6: Check README accuracy

```
So sánh:
  Templates trong README listing ↔ Templates thực tế trên filesystem

Tìm:
  □ Templates có trong README nhưng không tồn tại trên disk (stale docs)
  □ Templates tồn tại trên disk nhưng không có trong README (undocumented)
  □ Descriptions trong README có khớp template content không?
```

### Bước 7: Detect duplicates

```
Scan templates có mục đích tương tự:
  □ Tên gần giống nhau?
  □ Structure/content tương đồng?

Flag MAJOR cho templates duplicate — cần merge hoặc tạo rõ sự khác biệt.
```

### Bước 8: Output — Template Coverage Audit Report

```
Format output:

# Template Coverage Audit Report
**Templates scanned**: [N]
**Skills scanned**: [M]
**Date**: [date]

## Summary
[X CRITICAL] [Y MAJOR] [Z MINOR]

## Coverage Matrix
| Template | Skills Using | Status |
|----------|-------------|--------|
| phase1-business/requirements.md | wf-analyze-requirements | COVERED |
| phase2-features/feature-spec.md | wf-define-features | COVERED |
| phase3-old-template.md | (none) | ORPHAN |

## Critical Issues — Missing Templates
[Skills reference templates không tồn tại]

## Major Issues — Orphan Templates
[Templates không ai dùng]

## Major Issues — README Mismatches
[Danh sách mismatches]

## Minor Issues — Structure Problems
[Templates thiếu instructions, inconsistent placeholders]
```

---

## Checklist trước khi submit

```
□ Đã Glob để lấy tất cả template files thực tế
□ Đã Grep tất cả SKILL.md để xây dựng usage map
□ Đã so sánh README vs actual filesystem
□ Đã check placeholder format consistency trong từng template
□ Coverage matrix đầy đủ: mỗi template được phân loại
```
