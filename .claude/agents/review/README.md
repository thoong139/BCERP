# Review Team

Đội ngũ agents chuyên rà soát và kiểm tra DEVKIT.

## Available Agents

| Agent                                              | Nhiệm vụ                             | Model  |
| -------------------------------------------------- | -------------------------------------- | ------ |
| [review-orchestrator](review-orchestrator.md)         | Điều phối quy trình review         | sonnet |
| [skill-auditor](skill-auditor.md)                     | Kiểm tra skill definitions            | sonnet |
| [agent-auditor](agent-auditor.md)                     | Kiểm tra agent definitions            | sonnet |
| [template-auditor](template-auditor.md)               | Kiểm tra templates                    | sonnet |
| [cross-reference-auditor](cross-reference-auditor.md) | Kiểm tra cross-component dependencies | sonnet |
| [workflow-auditor](workflow-auditor.md)               | Kiểm tra workflow integrity           | sonnet |

## Khi nào sử dụng

- Sau khi có thay đổi lớn trong DEVKIT
- Định kỳ (weekly/monthly) để đảm bảo consistency
- Trước khi release DEVKIT updates
- Khi debug issues liên quan đến skill/agent interactions

## Invocation

Invoke trực tiếp agent `review-orchestrator`:

```
Yêu cầu: "Review toàn bộ DEVKIT"                    → review-orchestrator (--full)
Yêu cầu: "Chỉ review skills"                        → review-orchestrator (--skills)
Yêu cầu: "Kiểm tra cross-references"                → review-orchestrator (--cross-ref)
Yêu cầu: "Review agents"                            → review-orchestrator (--agents)
```

## Review Workflow

```
┌─────────────────────────────────────────────────────┐
│               REVIEW ORCHESTRATOR                   │
└─────────────────────────────────────────────────────┘
                         │
     ┌───────────────────┴───────────────────┐
     ▼                                       ▼
┌─────────────┐                     ┌─────────────┐
│   skill     │                     │   agent     │
│  auditor    │                     │  auditor    │
└─────────────┘                     └─────────────┘
         │                                   │
         └───────────────────┬───────────────┘
                             ▼
                  ┌─────────────────────┐
                  │   template          │
                  │   auditor           │
                  └─────────────────────┘
                             │
                             ▼
                  ┌─────────────────────┐
                  │ cross-reference     │
                  │     auditor         │
                  └─────────────────────┘
                             │
                             ▼
                  ┌─────────────────────┐
                  │   workflow          │
                  │   auditor           │
                  └─────────────────────┘
```

## Issue Severity

| Level    | Icon | Meaning              | Response Time |
| -------- | ---- | -------------------- | ------------- |
| CRITICAL | 🔴   | Breaks functionality | Immediate     |
| HIGH     | 🟠   | Causes inconsistency | Same sprint   |
| MEDIUM   | 🟡   | Documentation wrong  | When possible |
| LOW      | 🟢   | Minor improvement    | Consider      |
| INFO     | ℹ️ | Informational        | Note          |

## Common Issues Detected

### Skill Issues

- Deprecated skill names (`/design-platform`, `/design-system`)
- Broken template references
- Missing required frontmatter

### Agent Issues

- Wrong team directory
- Missing reference files
- Outdated version/last_updated

### Cross-Reference Issues

- Broken skill references
- Deprecated team names (Team A/B)
- Missing template paths

### Workflow Issues

- Workflow inconsistency between files
- Missing handoff documentation
- Unclear input/output definitions

## Output

Review reports được lưu tại `.mc-data/reports/devkit-review-[YYYY-MM-DD].md`
