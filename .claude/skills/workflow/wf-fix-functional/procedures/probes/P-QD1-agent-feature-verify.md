# P-QD1-agent-feature-verify — Agent Feature Verification

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD1-agent-feature-verify |
| **Loai** | agent |
| **Profile** | deep, exhaustive |
| **Muc dich** | Agent doc feature spec + runtime evidence → verify happy path |
| **Cache** | skip (agent probe) |

## SENSE

1. Doc danh sach features voi `impl_status=done` tu `req-registry.json`
2. Loc features trong scope cua run (theo $SESSION_DIR fix-status.json)
3. Cho moi feature, doc spec tu `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md`

## THINK

1. Xac dinh features can verify:
   - Features co runtime evidence (tu P-QD1-api-smoke hoac P-QD1-deep-ui-traversal) → skip (da verify)
   - Features khong co runtime evidence → can agent verify
2. Build review prompt cho tung feature

## ACT

Pre-execution: Trace execution flows via code intelligence (IMP-015):
```
# Use GitNexus to map feature execution before spawning agent
IF gitnexus available:
  FEATURE_FLOWS = gitnexus_query(query="{feat-id} feature implementation")
  # gitnexus_context returns callers, callees, execution flows per symbol
```

Spawn `general-purpose` agent:

> **Template:** `wf-fix-bugs/procedures/_shared.md §16 Sub-Probe Template` (8 CORE-037 sections bắt buộc — Role, Task, Session Context, CI Context, Playwright Context, Output Contract, Ownership, Completion). Render qua substitution table §16.2 trước khi gọi Agent tool.

```
Agent(name="feature-verify-{feat-id}", subagent_type="general-purpose", model="opus",
  prompt="Verify feature {feat-id} functional correctness.
          Read: .mc-data/docs/phase2-features/{sys}/{mod}/{feat}.md
          Read: source code trong src/ hoac apps/ cho feature nay.
          Check: happy path co duoc implement dung theo spec khong?

          IMPORTANT — Citation requirements (IMP-015):
          - Use Serena find_symbol(name='{feature_service_or_handler}') to locate the implementation.
          - Use Serena find_referencing_symbols() to check all callers.
          - Use GitNexus gitnexus_query(query='{feat-id}') to get execution flow trace.
          - Every finding MUST cite exact file:line (format: 'src/path/file.ts:42').
          - Evidence must include code_snippet (not just description).
          - Reference GitNexus execution path in evidence if applicable.

          Output: JSON array [{type, description, file_path, line_range, severity, evidence, citation}]
          where citation = {gitnexus_flow: string, serena_symbol: string, serena_file_line: string}")
```

Convert agent findings thanh Signals:
- `evidence.code_snippet` hoac `evidence.spec_ref` (REQUIRED — IMP-008 enforcement)
- `evidence.citation` tu agent output (GitNexus + Serena file:line)
- `suggested_severity` tu agent output

## VERIFY

1. CORE-029 spot-check agent output: moi finding co `type`, `description` non-empty
2. Kiem tra moi Signal co evidence
