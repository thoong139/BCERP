# Playbook: Validate Template Structure

> **Type**: Agent Skill Playbook
> **Agent**: template-auditor
> **Triggered by**: Khi review 1 template file cụ thể
> **Output**: Template Structure Report với findings

---

## Khi nào dùng playbook này

- Khi có template mới cần review trước khi dùng trong skill
- Khi template được cập nhật và cần kiểm tra vẫn đúng structure
- Khi skill báo lỗi về template → cần deep-inspect template

---

## Procedure

### Bước 1: Đọc template file

```
READ: [template file path]

Extract:
  □ Title/heading (dòng đầu tiên)
  □ Purpose description (đoạn mô tả mục đích template)
  □ Sections và headings
  □ Tất cả placeholders (pattern [UPPERCASE] hoặc {{ name }})
  □ Instructions/guidance sections
  □ Example outputs nếu có
  □ Versioning/metadata nếu có
```

### Bước 2: Validate required elements

```
□ Title rõ ràng và mô tả đúng mục đích template?
□ Purpose description có mặt (người dùng biết khi nào dùng template này)?
□ Có placeholders được định nghĩa (template không blank)?
□ Có instructions hướng dẫn điền template?
□ Có ví dụ output hoặc guidance về expected content?
```

### Bước 3: Validate placeholder consistency

```
Inventory tất cả placeholders trong template.

Kiểm tra format:
  □ Dùng format nào: [PLACEHOLDER] hay {{ placeholder }} hay _placeholder_?
  □ Tất cả placeholders trong template dùng CÙNG 1 format?
  □ Tên placeholder có mô tả rõ content cần điền?

Flag MAJOR nếu có mixed formats trong cùng 1 template.

Kiểm tra completeness:
  □ Mỗi placeholder có label/description rõ không?
  □ Placeholder nào là bắt buộc vs optional?
  □ Có placeholder bị orphan (định nghĩa nhưng không dùng trong template)?
```

### Bước 4: Validate frontmatter (nếu có)

```
Nếu template có YAML frontmatter (--- ... ---):
  □ Fields hợp lệ
  □ Có description field?
  □ Có version field?
  □ Có phase field để biết template thuộc phase nào?
```

### Bước 5: Check example outputs

```
□ Template có section "Example" hoặc "Ví dụ" không?
□ Ví dụ đủ cụ thể để người dùng hiểu expected output?
□ Ví dụ không lỗi thời (không reference deprecated features)?
```

### Bước 6: Check versioning

```
□ Template có version number không?
□ Template có last_updated date không?
□ Nếu template là phiên bản mới của template cũ → có migration note không?
```

### Bước 7: Consistency với templates cùng phase

```
Glob tất cả templates trong cùng phase directory.

So sánh template đang review với các templates cùng phase:
  □ Cùng placeholder format?
  □ Cùng section structure (nếu applicable)?
  □ Cùng naming conventions?

Flag MINOR nếu khác biệt mà không có lý do rõ.
```

### Bước 8: Output — Template Structure Report

```
Format output:

# Template Structure Report: [template-name]
**File**: [path]
**Phase**: [phase]
**Date**: [date]

## Summary
[PASS / FAIL] — [X issues: A CRITICAL, B MAJOR, C MINOR]

## Structure Checklist
| Check | Status | Note |
|-------|--------|------|
| Title present | PASS/FAIL | |
| Purpose description | PASS/FAIL | |
| Placeholders defined | PASS/FAIL | |
| Instructions present | PASS/FAIL | |
| Example output | PASS/FAIL | |
| Placeholder format consistent | PASS/FAIL | [format used] |
| Versioning | PASS/FAIL | |

## Placeholder Inventory
| Placeholder | Format | Required | Description Clear |
|-------------|--------|----------|------------------|
| [PROJECT_NAME] | [] | Yes | Yes |

## Findings
| ID | Severity | Finding | Recommendation |
|----|----------|---------|----------------|

## Consistency with Phase Templates
[So sánh với templates cùng phase]
```

---

## Checklist trước khi submit

```
□ Đã đọc toàn bộ template file
□ Đã inventory tất cả placeholders
□ Đã kiểm tra placeholder format consistency
□ Đã so sánh với templates cùng phase
□ Mọi finding có severity và recommendation
```
