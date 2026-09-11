# Playbook: Validate Skill Compliance (Batch)

> **Type**: Agent Skill Playbook
> **Agent**: skill-auditor
> **Triggered by**: Batch compliance check cho nhiều skills
> **Output**: Skill Compliance Validation Report tổng hợp

---

## Khi nào dùng playbook này

- Khi review-orchestrator yêu cầu `--skills` scope
- Khi cần audit toàn bộ .claude/skills/ directory
- Khi cần kiểm tra compliance sau khi update workflow-skill.md template

---

## Procedure

### Bước 1: Load template và canonical workflow

```
READ: .claude/skills/workflow-skill.md
READ: .claude/rules/00-core.md → extract:
  □ Canonical workflow order (skill names và thứ tự)
  □ Cross-Skill Output Path Contract (§4b)
```

### Bước 2: Thu thập tất cả SKILL.md files

```
Glob: .claude/skills/**/SKILL.md

Lưu danh sách files.
Đừng hardcode — luôn Glob để phát hiện skills mới.
```

### Bước 3: Chạy script compliance audit

```
Bash: ./.claude/scripts/skill-compliance-audit.sh --all

Thu thập output.
Parse kết quả: PASS / FAIL per skill.
```

### Bước 4: Review script output

```
Với mỗi FAIL:
  □ Xác định violation cụ thể (missing section, broken ref, ...)
  □ Categorize severity:
    - CRITICAL: broken agent/template refs, missing quality gates
    - MAJOR: deprecated names, output path mismatch
    - MINOR: format issues, missing description

Với mỗi PASS:
  □ Xác nhận không có false positive
  □ Note version và last_updated
```

### Bước 5: Categorize violations

```
Nhóm violations theo loại để dễ batch fix:

Type 1 — Missing sections:
  [Skills thiếu PRE-GATE / EXECUTION / POST-GATE]

Type 2 — Broken agent references:
  [Skills có subagent_type không tồn tại]

Type 3 — Broken template references:
  [Skills có template path không tồn tại]

Type 4 — Deprecated skill names:
  [Skills dùng tên /design, /brainstorm, v.v.]

Type 5 — Output path mismatch:
  [Output paths không khớp Cross-Skill Contract §4b]

Type 6 — Workflow consistency:
  [Skill không khớp vị trí trong canonical workflow]
```

### Bước 6: Prioritize fixes

```
Thứ tự ưu tiên fix:
  1. CRITICAL: broken refs → fix ngay, break functionality
  2. MAJOR: deprecated names, output mismatches → fix in sprint
  3. MINOR: format → fix khi có capacity

Estimate effort cho từng fix batch.
```

### Bước 7: Output — Skill Compliance Validation Report

```
Format output:

# Skill Compliance Validation Report
**Scope**: All skills in .claude/skills/
**Total skills**: [N]
**Date**: [date]

## Summary
[X PASS] [Y FAIL]
[A CRITICAL] [B MAJOR] [C MINOR]

## Compliance Matrix
| Skill | PRE-GATE | EXECUTION | POST-GATE | Agent Refs | Template Refs | Overall |
|-------|----------|-----------|-----------|------------|---------------|---------|
| wf-brainstorm | PASS | PASS | PASS | PASS | PASS | PASS |

## Violations by Type
### Type 1 — Missing sections
[List]

### Type 2 — Broken agent references
[List]

[... các types khác]

## Recommended Fix Plan
Sprint 1 (CRITICAL): [list]
Sprint 2 (MAJOR): [list]
Backlog (MINOR): [list]
```

---

## Checklist trước khi submit

```
□ Đã Glob để lấy danh sách SKILL.md — không hardcode
□ Đã chạy skill-compliance-audit.sh nếu script khả dụng
□ Đã categorize violations theo type (để batch fix hiệu quả)
□ Đã verify output paths vs Cross-Skill Contract §4b
□ Report có compliance matrix đầy đủ per skill
```
