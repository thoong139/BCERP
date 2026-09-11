# Playbook: Audit Skill Definition

> **Type**: Agent Skill Playbook
> **Agent**: skill-auditor
> **Triggered by**: Khi review SKILL.md file mới hoặc changed
> **Output**: Skill Audit Report với findings và recommendations

---

## Khi nào dùng playbook này

- Khi có SKILL.md mới cần review trước khi merge
- Khi skill đã thay đổi và cần kiểm tra compliance
- Khi review-orchestrator yêu cầu audit 1 skill cụ thể

---

## Procedure

### Bước 1: Load template chuẩn

```
READ: .claude/skills/workflow-skill.md

Nắm rõ:
  □ Frontmatter required fields
  □ Quality Gate Protocol: PRE-GATE → EXECUTION → POST-GATE
  □ Phase structure
  □ Output paths format
  □ Agent invocation format
```

### Bước 2: Đọc skill file

```
READ: [SKILL.md path]

Extract:
  □ Frontmatter (name, version, description, invocation)
  □ Danh sách phases
  □ Quality gates (PRE-GATE, POST-GATE)
  □ Output paths
  □ Agent references (subagent_type values)
  □ Template paths referenced
  □ Skill-to-skill references
```

### Bước 3: Validate structure

```
Frontmatter:
  □ name field có mặt
  □ version đúng SemVer
  □ description mô tả mục đích skill
  □ invocation ghi rõ command (ví dụ: /wf-analyze-requirements)

Quality Gate Protocol:
  □ PRE-GATE section có mặt (điều kiện để bắt đầu)
  □ EXECUTION section có mặt (các phases thực hiện)
  □ POST-GATE section có mặt (điều kiện để kết thúc)

Phase structure:
  □ Mỗi phase có tên và mô tả rõ
  □ Mỗi phase có output artifact được định nghĩa
  □ Phases theo thứ tự logic

Error handling:
  □ Có xử lý trường hợp pre-conditions chưa met?
  □ Có fallback khi agent fails?
```

### Bước 4: Validate output paths

```
Với mỗi output path được định nghĩa trong skill:
  □ Path format đúng (.mc-data/docs/... hoặc .mc-data/work/...)
  □ Path khớp Cross-Skill Output Path Contract (rules/core.md §4b)?

READ: .claude/rules/00-core.md → extract §4b contract table
Verify mỗi output path trong skill khớp contract.

Flag CRITICAL nếu output path không khớp contract.
```

### Bước 5: Validate agent references

```
Extract tất cả subagent_type values từ skill.

Với mỗi subagent_type:
  Glob .claude/agents/**/*.md → tìm file có name: [subagent_type]
  Nếu không tồn tại → CRITICAL finding

Kiểm tra deprecated agent names:
  □ Không dùng tên cũ đã đổi
  □ subagent_type khớp actual filename (không extension)
```

### Bước 6: Validate template references

```
Extract tất cả template paths từ skill (thường dạng .claude/doc-framework/...).

Với mỗi template path:
  Glob để verify file tồn tại
  Nếu không tồn tại → CRITICAL finding
```

### Bước 7: Check deprecated skill names

```
Known deprecated names (cần flag nếu xuất hiện trong skill):
  /design          → /wf-design
  /brainstorm      → /wf-brainstorm
  /start-project   → đã bị remove
  /analyze-req     → /wf-analyze-requirements

Grep trong skill file cho deprecated patterns.
Flag MAJOR cho mỗi deprecated name.
```

### Bước 8: Output — Skill Audit Report

```
Format output:

# Skill Audit Report: [skill-name]
**File**: [path]
**Version**: [version]
**Date**: [date]

## Summary
[PASS / FAIL] — [X issues: A CRITICAL, B MAJOR, C MINOR]

## Structure Checklist
| Check | Status | Note |
|-------|--------|------|
| Frontmatter complete | PASS/FAIL | [detail] |
| PRE-GATE present | PASS/FAIL | |
| EXECUTION phases | PASS/FAIL | |
| POST-GATE present | PASS/FAIL | |
| Output paths valid | PASS/FAIL | |
| Agent refs valid | PASS/FAIL | |
| Template refs valid | PASS/FAIL | |
| No deprecated names | PASS/FAIL | |

## Findings
| ID | Severity | Finding | Recommendation |
|----|----------|---------|----------------|
| F-001 | CRITICAL | [mô tả] | [đề xuất fix] |
```

---

## Checklist trước khi submit

```
□ Đã đọc workflow-skill.md template trước khi audit
□ Đã verify tất cả output paths vs Cross-Skill Output Path Contract
□ Đã Glob verify tất cả agent references
□ Đã Glob verify tất cả template paths
□ Đã scan deprecated skill names
□ Mọi finding có severity label và recommendation
```
