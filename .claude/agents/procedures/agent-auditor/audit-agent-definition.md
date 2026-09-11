# Playbook: Audit Agent Definition

> **Type**: Agent Skill Playbook
> **Agent**: agent-auditor
> **Triggered by**: Khi review agent file mới hoặc changed agent
> **Output**: Agent Audit Report với findings và recommendations

---

## Khi nào dùng playbook này

- Khi có agent definition mới cần review trước khi merge
- Khi agent đã thay đổi và cần kiểm tra compliance
- Khi review-orchestrator yêu cầu audit 1 agent cụ thể

---

## Procedure

### Bước 1: Load spec

```
READ: .claude/agents/spec/README.md
READ: .claude/agents/spec/agent-definition-template.md

Nắm rõ:
  □ 9 sections bắt buộc (A1-A9)
  □ Giới hạn dòng từng section và tổng thể
  □ Agents đặc biệt: orchestrator skip A3/A4/A6, review agents skip A6
  □ Tiêu chí anti-patterns (AP-1 đến AP-7)
```

### Bước 2: Đọc agent file

```
READ: [agent file path]

Extract:
  □ Frontmatter (name, version, description, tools, model, permissionMode)
  □ Danh sách sections có trong file
  □ Tổng số dòng
  □ Số dòng từng section
  □ Tên file (để so sánh với frontmatter name)
```

### Bước 3: Validate Checklist A1-A9

Kiểm tra lần lượt từng section:

```
A1 — Frontmatter:
  □ name khớp filename (không có .md)
  □ version đúng SemVer (X.Y.Z)
  □ description có mô tả rõ vai trò + khi invoke
  □ tools là danh sách hợp lệ
  □ model: haiku / sonnet / opus
  □ permissionMode: plan / acceptEdits / auto

A2 — Identity (Vai trò):
  □ Section "Vai trò" có mặt
  □ Không generic: không chỉ "Chuyên gia về X" mà có perspective đặc trưng
  □ ≤ 10 dòng

A3 — Expertise (skip nếu là orchestrator):
  □ Section "Expertise" có mặt
  □ Mỗi item là bullet point cụ thể
  □ ≤ 15 dòng

A4 — Cognitive Framework (skip nếu là orchestrator):
  □ Section "Cognitive Framework" có mặt
  □ Có 2-3 góc nhìn / lăng kính đặc trưng
  □ ≤ 20 dòng

A5 — Workflow:
  □ Section "Workflow" hoặc "Phase Behavior" có mặt
  □ Có bước cụ thể (không chỉ mô tả chung)
  □ ≤ 60 dòng

A6 — Knowledge References (skip nếu review agent):
  □ Section "Knowledge Base References" hoặc "Knowledge Routing" có mặt
  □ Mỗi path có thể verify trên filesystem
  □ Không load toàn bộ knowledge — chỉ khi cần

A7 — Phase Behavior:
  □ Section "Phase Behavior" có mặt (table: Phase → Task → Playbook)
  □ Liệt kê phases agent tham gia
  □ Mỗi phase có playbook tương ứng

A8 — Skill Playbooks:
  □ Section "Skill Playbooks" có mặt (table: Task type → Procedure path)
  □ Mỗi procedure path trỏ đến file trong .claude/agents/procedures/[agent-name]/
  □ Verify paths tồn tại trên filesystem

A9 — Coordination:
  □ Section "Coordination" có mặt
  □ Table có ít nhất 1 agent được reference
  □ Agents được reference thực sự tồn tại

A10 — Constraints:
  □ Section "Constraints" có mặt
  □ Có cả "Bắt buộc" và "Không được"
```

### Bước 4: Scan anti-patterns

```
AP-1 Knowledge Dump: Có section nào > 30 dòng với tables/data chi tiết?
  → Data nên ở knowledge files, không ở agent definition

AP-2 Workflow trống: Workflow chỉ có mô tả chung, không có bước cụ thể?
  → Phải có numbered steps

AP-5 Island Agent: Không có Coordination section hoặc không reference agent nào?
  → Mọi agent cần biết khi nào gọi ai

AP-7 Vague Identity: Vai trò chỉ "Chuyên gia về X" không có perspective riêng?
  → Cần góc nhìn đặc trưng (lăng kính, ưu tiên cụ thể)
```

### Bước 5: Verify file paths

```
Với mỗi path reference trong agent:
  □ Knowledge references: Glob để verify file tồn tại
  □ Skill Playbooks paths: Glob để verify procedure file tồn tại
  □ Coordination agent names: Glob agents/ để verify agent tồn tại

Flag CRITICAL nếu bất kỳ path nào không tồn tại.
```

### Bước 6: Output — Agent Audit Report

```
Format output:

# Agent Audit Report: [agent-name]
**File**: [path]
**Version**: [version]
**Date**: [date]

## Summary
[PASS / FAIL] — [X issues: A CRITICAL, B MAJOR, C MINOR]

## Checklist Results
| Check | Status | Note |
|-------|--------|------|
| A1 Frontmatter | PASS/FAIL | [detail] |
| A2 Identity | PASS/FAIL | [detail] |
...

## Findings
| ID | Severity | Finding | Recommendation |
|----|----------|---------|----------------|
| F-001 | CRITICAL | [mô tả] | [đề xuất fix] |

## Anti-Pattern Scan
[Kết quả AP-1, AP-2, AP-5, AP-7]
```

---

## Checklist trước khi submit

```
□ Đã đọc spec (README.md + template) trước khi audit
□ Đã kiểm tra agents đặc biệt (orchestrator/review) và skip đúng checks
□ Đã verify TẤT CẢ file paths bằng Glob
□ Đã scan 4 anti-patterns chính
□ Mọi finding có severity label và recommendation
```
