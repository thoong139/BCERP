# Playbook: Validate Path Integrity

> **Type**: Agent Skill Playbook
> **Agent**: cross-reference-auditor
> **Triggered by**: After adding new files or renaming
> **Output**: Path Integrity Validation Report với broken paths và fix suggestions

---

## Khi nào dùng playbook này

- Sau khi rename hoặc di chuyển file trong .claude/
- Sau khi thêm nhiều files mới và cần verify references đến chúng
- Khi cần quick path validation (nhanh hơn full cross-reference audit)

---

## Procedure

### Bước 1: Xác định scope scan

```
Nhận từ caller:
  - Danh sách files vừa thêm/đổi tên (nếu có)
  - Hoặc: scope toàn bộ .claude/ directory

Nếu scope cụ thể:
  → Chỉ scan files reference đến files đã thay đổi
  → Và scan chính files đó để verify references bên trong

Nếu scope toàn bộ:
  → Scan tất cả .md files trong .claude/
```

### Bước 2: Scan tất cả path references trong .md files

```
Glob: .claude/**/*.md

Với mỗi .md file, Grep để tìm path patterns:
  Pattern 1: .claude/agents/[path]
  Pattern 2: .claude/skills/[path]
  Pattern 3: .claude/doc-framework/[path]
  Pattern 4: .claude/references/[path]
  Pattern 5: .claude/rules/[path]
  Pattern 6: .claude/hooks/[path]
  Pattern 7: .mc-data/[path] (runtime paths — skip nếu không verify)

Lưu: {source_file: [referenced_paths]}
```

### Bước 3: Test từng path

```
Với mỗi referenced path:
  Glob để verify file/directory tồn tại

  Kết quả:
    EXISTS     → path hợp lệ
    NOT_FOUND  → broken path → flag theo severity

  Severity:
    CRITICAL: path trong agent/skill definition files
    MAJOR: path trong doc-framework templates
    MINOR: path trong documentation files (như CLAUDE.md mô tả)
```

### Bước 4: Suggest fixes cho broken paths

```
Với mỗi broken path, suggest fix:

Strategy 1 — Tìm file có tên tương tự:
  Glob với filename gần giống
  Nếu tìm thấy → suggest path mới

Strategy 2 — Check deprecated path patterns:
  .claude/references/team-expert/ (current) vs old paths
  .claude/skills/workflow/ (current) vs old structure

Strategy 3 — New vs old location:
  Nếu file vừa di chuyển → suggest new location

Format fix suggestion:
  "Thay '[old_path]' bằng '[suggested_new_path]'"
```

### Bước 5: Group broken paths theo source file

```
Nhóm broken paths theo file chứa reference.
Ưu tiên: file nào có nhiều broken paths nhất → fix file đó trước.

Tạo "fix manifest":
  {source_file: [{old_path, new_path}]}
```

### Bước 6: Check reverse — files không được reference

```
Glob: .claude/agents/procedures/**/*.md → procedure files

Với mỗi procedure file:
  Tìm trong Skill Playbooks tables xem có agent nào reference không
  Nếu không có agent reference → flag MINOR (orphan procedure)
```

### Bước 7: Output — Path Integrity Validation Report

```
Format output:

# Path Integrity Validation Report
**Files scanned**: [N]
**Path references found**: [M]
**Date**: [date]

## Summary
[X broken paths] ([A CRITICAL] [B MAJOR] [C MINOR])
[Y orphan files]

## Broken Paths
| Source File | Broken Path | Suggested Fix | Severity |
|-------------|-------------|---------------|----------|
| .claude/agents/review/agent-auditor.md | .claude/agents/procedures/agent-auditor/old-procedure.md | File không tồn tại — xóa reference | CRITICAL |

## Fix Manifest
### .claude/agents/[file].md
- Replace: `old/path.md` → `new/path.md`

## Orphan Procedure Files
[List procedure files không được agent nào reference]

## Stats
- Paths verified: [N]
- Paths OK: [M]
- Paths broken: [X]
```

---

## Checklist trước khi submit

```
□ Đã scan tất cả .md files trong scope
□ Đã test từng path bằng Glob — không dùng memory
□ Đã provide fix suggestions cho broken paths
□ Đã check orphan procedure files
□ Fix manifest đủ chi tiết để developer dùng trực tiếp
```
