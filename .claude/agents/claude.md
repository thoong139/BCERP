---
name: claude
version: 1.0.0
last_updated: 2026-05-16
description: |
  **Built-in default subagent_type** của Claude Code harness. KHÔNG phải custom agent file — đây là documentation placeholder cho audit tooling tracking.

  `subagent_type="claude"` là giá trị MẶC ĐỊNH khi orchestrator spawn sub-agent qua `Agent()` tool mà KHÔNG cần specialized domain expert. Agent này có toàn bộ MCP tools (GitNexus, Serena, Playwright, Context7) + Read/Write/Edit/Bash standard tools.

  Dùng cho: lane agents trong wf-fix-bugs Phase 4 (QD1-QD11), wf-fix-triage Phase 5 spawn, wf-fix-execute Phase 6 spawn — mọi nơi cần general-purpose claude assistant với full MCP access.
tools: '*'
model: opus
---

# Agent: claude (Built-In Default)

## Vai trò

Đây KHÔNG phải agent definition theo nghĩa thông thường — `claude` là **subagent_type mặc định** được Claude Code harness cung cấp built-in. Khi orchestrator gọi:

```text
Agent(subagent_type="claude", prompt=<...>)
```

Harness sẽ spawn một Claude instance với:
- **Toàn bộ MCP tools** (GitNexus, Serena, Playwright, Context7) — không bị giới hạn như domain agents
- **Standard tools** (Read, Write, Edit, Bash, Glob, Grep, TodoWrite, ...)
- **Model**: opus (mặc định) hoặc theo `model=` parameter

## Khi nào dùng `subagent_type="claude"`

| Use case | Lý do |
|----------|-------|
| Lane agents trong Phase 4 (QD1-QD11) | Cần MCP access đầy đủ + KHÔNG cần domain expertise narrow |
| wf-fix-triage agent (Phase 5) | Generic classifier + cần GitNexus/Serena cho impact analysis |
| wf-fix-execute agent (Phase 6) | Generic executor + cần đầy đủ file system + MCP tools |
| Test scenarios không match domain agent | Fallback khi không có specialized agent phù hợp |

## Khi nào KHÔNG dùng `claude`

Dùng **domain agent** cụ thể khi:

| Use case | Dùng agent thay thế |
|----------|---------------------|
| Phân tích nghiệp vụ y tế | `healthcare-expert` |
| Code review chuyên sâu | `code-reviewer` |
| Security audit | `security` |
| UX research | `ux-researcher` |
| Architecture design | `architect` |
| ... | Xem `.claude/agents/business/`, `engineering/`, `design/`, `testing/`, `review/` |

## File này tồn tại để:

1. **Audit tooling compliance**: `skill-compliance-audit.sh §10.3` check `subagent_type` references có file tương ứng trong `.claude/agents/`. Built-in `claude` cần placeholder doc để pass check.
2. **Documentation cho contributors**: Giải thích semantics của `subagent_type="claude"` vs domain agents.
3. **Onboarding**: Người mới đọc skill code thấy `subagent_type="claude"` có thể tra cứu document này.

## Không sửa file này

File này là **doc placeholder**. KHÔNG implement agent logic ở đây — `claude` agent là built-in của harness, không thể override qua MD file.

## Cross-reference

- `_shared.md §15` của wf-fix-bugs — Lane Agent Prompt template dùng `subagent_type="claude"` mặc định
- CORE-037 (Agent Prompt Templates) — 8-section template áp dụng cho mọi spawn
- CORE-025 (Parallelization) — max 10 concurrent agents (built-in harness limit)
