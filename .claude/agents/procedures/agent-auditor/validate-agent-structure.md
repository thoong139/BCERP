# Playbook: Validate Agent Structure (Batch)

> **Type**: Agent Skill Playbook
> **Agent**: agent-auditor
> **Triggered by**: Batch validation của nhiều agents
> **Output**: Agent Structure Validation Report tổng hợp

---

## Khi nào dùng playbook này

- Khi cần audit toàn bộ một team agents (ví dụ: toàn bộ engineering/)
- Khi review-orchestrator yêu cầu `--agents` scope
- Khi cần kiểm tra nhanh pattern compliance mà không cần deep audit từng agent

---

## Procedure

### Bước 1: Thu thập agent files trong scope

```
Glob pattern theo scope nhận được:
  Toàn bộ: .claude/agents/**/*.md (trừ thư mục procedures/)
  1 team: .claude/agents/[team]/*.md
  1 agent: .claude/agents/[team]/[agent].md

Lưu danh sách files để iterate.
Đừng hardcode — luôn Glob để phát hiện files mới.
```

### Bước 2: Load spec để làm reference

```
READ: .claude/agents/spec/agent-definition-template.md
Extract required sections list.
```

### Bước 3: Required sections checklist (từng agent)

Với mỗi agent file, chạy nhanh:

```
□ Frontmatter có mặt (--- ... ---)
□ Section "Vai trò" có mặt
□ Section "Expertise" có mặt (trừ orchestrators)
□ Section "Cognitive Framework" có mặt (trừ orchestrators)
□ Section "Workflow" hoặc "Phase Behavior" có mặt
□ Section "Phase Behavior" có mặt (table format)
□ Section "Skill Playbooks" có mặt (table format)
□ Section "Coordination" có mặt
□ Section "Constraints" có mặt

CRITICAL nếu thiếu bất kỳ section nào.
```

### Bước 4: Reference path validity

```
Với mỗi agent, extract và verify:
  1. Knowledge paths (Knowledge Base References section)
  2. Skill Playbook paths (Skill Playbooks section)
  3. Coordination agent names (Coordination table)

Batch verify bằng Glob:
  - Knowledge paths: Glob từng path
  - Procedure files: Glob .claude/agents/procedures/[agent-name]/*.md
  - Coordination agents: Glob .claude/agents/**/*.md → build name list

Flag CRITICAL cho mỗi broken reference.
```

### Bước 5: Consistent pattern check

```
So sánh từng agent với marketing-expert.md làm reference pattern:

□ Frontmatter format nhất quán?
□ Section header naming nhất quán ("## Vai trò" không phải "## Role")?
□ Phase Behavior dùng table format?
□ Skill Playbooks dùng table format?
□ Coordination dùng table format?
□ Constraints có 2 sub-sections (Bắt buộc + Không được)?
```

### Bước 6: Version number và procedure files

```
Với mỗi agent:
□ version field có mặt trong frontmatter và đúng SemVer?
□ last_updated có mặt và đúng format YYYY-MM-DD?
□ Thư mục .claude/agents/procedures/[agent-name]/ tồn tại?
□ Số procedure files khớp với số entries trong Skill Playbooks table?
```

### Bước 7: Output — Agent Structure Validation Report

```
Format output:

# Agent Structure Validation Report
**Scope**: [scope được validate]
**Total agents scanned**: [N]
**Date**: [date]

## Summary
[X PASS] [Y FAIL]
[A CRITICAL issues] [B MAJOR issues] [C MINOR issues]

## Per-Agent Results
| Agent | Sections | Paths | Pattern | Version | Status |
|-------|----------|-------|---------|---------|--------|
| [name] | PASS/FAIL | PASS/FAIL | PASS/FAIL | PASS/FAIL | [status] |

## Critical Issues
[List với agent name + finding + recommendation]

## Major Issues
[List]

## Agents Missing Procedure Directory
[List agents không có thư mục procedures/]
```

---

## Checklist trước khi submit

```
□ Đã Glob để lấy danh sách agent files — không hardcode
□ Đã verify tất cả reference paths bằng filesystem
□ Đã kiểm tra procedure directory tồn tại cho từng agent
□ Đã so sánh pattern với reference template
□ Report có đủ per-agent results và summary
```
