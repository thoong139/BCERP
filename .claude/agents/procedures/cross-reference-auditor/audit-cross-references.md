# Playbook: Audit Cross-References

> **Type**: Agent Skill Playbook
> **Agent**: cross-reference-auditor
> **Triggered by**: Khi có naming changes hoặc file moves trong DEVKIT
> **Output**: Cross-Reference Audit Report với reference graph

---

## Khi nào dùng playbook này

- Sau khi rename agent, skill, hoặc template
- Sau khi di chuyển files sang location mới
- Khi review-orchestrator yêu cầu `--cross-ref` scope
- Khi workflow bị đứt nhưng không rõ nguyên nhân

---

## Procedure

### Bước 1: Build reference graph — Agents

```
Glob: .claude/agents/**/*.md (trừ procedures/)

Với mỗi agent file, extract:
  □ name field (frontmatter) → canonical name
  □ Knowledge paths (Knowledge Base References section)
  □ Skill Playbook paths (Skill Playbooks section)
  □ Coordination agents (Coordination table → agent names)
  □ Procedure directory: .claude/agents/procedures/[agent-name]/

Lưu: {agent_name: {knowledge: [], playbooks: [], coordination: [], procedures: []}}
```

### Bước 2: Build reference graph — Skills

```
Glob: .claude/skills/**/SKILL.md

Với mỗi SKILL.md, extract:
  □ Skill name (frontmatter)
  □ Agent references (subagent_type values)
  □ Template references (.claude/doc-framework/ paths)
  □ Skill-to-skill references (các skill được mention)
  □ Output paths

Lưu: {skill_name: {agents: [], templates: [], skills: [], outputs: []}}
```

### Bước 3: Build reference graph — CLAUDE.md và rules

```
READ: CLAUDE.md
  □ Extract: skill command listing (command column)
  □ Extract: agent team listings và counts
  □ Extract: workflow documentation

READ: .claude/rules/00-core.md
  □ Extract: canonical workflow (skill names và thứ tự)
  □ Extract: Cross-Skill Output Path Contract (§4b)

Lưu: {claude_md: {skills: [], agents: [], workflow: []}}
```

### Bước 4: Verify agent references

```
Với mỗi reference trong graph:

  Knowledge paths:
    Glob để verify file tồn tại
    → CRITICAL nếu missing

  Skill Playbook paths:
    Glob để verify procedure file tồn tại
    → CRITICAL nếu missing

  Coordination agents:
    Lookup trong agent name list
    → CRITICAL nếu agent không tồn tại

  Procedure directory:
    Glob .claude/agents/procedures/[name]/ để verify directory
    → MAJOR nếu missing directory
```

### Bước 5: Verify skill references

```
Với mỗi reference trong skill graph:

  Agent references (subagent_type):
    Lookup trong agent name list (từ Bước 1)
    → CRITICAL nếu agent không tồn tại

  Template paths:
    Glob để verify file tồn tại
    → CRITICAL nếu missing

  Skill-to-skill references:
    Lookup trong skill name list
    → MAJOR nếu skill không tồn tại hoặc deprecated
```

### Bước 6: Check deprecated/legacy names

```
Known deprecated names (tra rules/core.md + CLAUDE.md):

Deprecated skill names:
  /design → /wf-design
  /brainstorm → /wf-brainstorm
  /start-project → removed

Deprecated team path patterns:
  team-expert/ → references/team-expert/ (nếu applicable)

Scan tất cả .md files trong .claude/ cho deprecated patterns.
Flag MAJOR cho mỗi occurrence.
```

### Bước 7: Check naming consistency

```
Cùng 1 component phải dùng cùng tên ở mọi nơi:
  □ Agent "marketing-expert" → phải gọi là "marketing-expert" (không "marketing_expert" hay "MarketingExpert")
  □ Skill "wf-design" → phải gọi là "wf-design" (không "wf_design" hay "/design")

Scan CLAUDE.md counts: "18 agents (business)" → verify actual count = 18.

Flag MAJOR cho mỗi inconsistency.
```

### Bước 8: Check bidirectional consistency

```
Coordination references:
  Nếu Agent A có "Coordination → Agent B" → Agent B có biết Agent A không?
  (Agent B không nhất thiết phải reference Agent A, nhưng nếu bất đối xứng quá nhiều → flag MINOR)

CLAUDE.md listing:
  Số agents per team trong CLAUDE.md = số files thực tế?
  Skill commands trong CLAUDE.md = skills thực tế tồn tại?
```

### Bước 9: Output — Cross-Reference Audit Report

```
Format output:

# Cross-Reference Audit Report
**Scope**: [scope]
**Date**: [date]
**Components scanned**: [X agents] [Y skills] [Z templates]

## Summary
[A CRITICAL] [B MAJOR] [C MINOR]

## Broken References (CRITICAL)
| Component | Reference | Target | Status |
|-----------|-----------|--------|--------|
| agent-auditor | playbook: audit-agent-definition.md | .claude/agents/procedures/agent-auditor/audit-agent-definition.md | MISSING |

## Deprecated Names (MAJOR)
| File | Line | Deprecated Name | Current Name |
|------|------|----------------|--------------|

## Naming Inconsistencies (MAJOR)
[List]

## Bidirectional Gaps (MINOR)
[List]

## Reference Graph Summary
[Text summary of reference counts per component]
```

---

## Checklist trước khi submit

```
□ Đã build reference graph từ agents, skills, CLAUDE.md và rules
□ Đã verify TẤT CẢ paths bằng Glob — không trust text
□ Đã check deprecated names theo known legacy mappings
□ Đã check CLAUDE.md counts vs actual file counts
□ Đã check bidirectional coordination references
□ Report có reference graph summary đầy đủ
```
