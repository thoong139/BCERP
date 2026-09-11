<!--
  CANONICAL cho wf-fix-bugs Phase 4 orchestrator-rendered per-agent inline summary.
  Schema concise (33 dòng) — chỉ Static/Runtime/LLM signals counts + observations.
  Used by wf-fix-bugs/_contract.json line 73, written tại
  $SESSION_DIR/phase4-find-bugs/lanes/QD{n}-{name}/QD{n}-{name}-report.md.

  KHÔNG nhầm với _shared/lane/templates/lane-report.md — template kia là canonical
  cho 11 QD lane skills (full per-lane comprehensive report, schema lane-report-v1).

  Sprint 3 F07.007: document distinction (2 templates KHÔNG duplicate).
-->

# Báo cáo [DIM_ID]: [DIM_NAME] — wf-fix-bugs v10.10.0

> **Dimension:** [DIM_ID] — [DIM_NAME]
> **Session ID:** [SESSION_ID]
> **Agent:** [AGENT_ID]
> **Thời gian:** [STARTED_AT] → [COMPLETED_AT]

## Tổng quan

- **Tín hiệu static:** [SIGNALS_STATIC]
- **Tín hiệu runtime:** [SIGNALS_RUNTIME]
- **Tín hiệu LLM:** [SIGNALS_LLM]
- **Probe lỗi:** [PROBE_FAILURES]
- **Playwright dùng:** [PLAYWRIGHT_USED]

## Chi tiết tín hiệu

### Quét tĩnh (Static Scan)

[STATIC_SIGNALS_SECTION]

### Quét runtime (Runtime Scan)

[RUNTIME_SIGNALS_SECTION]

### Quét bằng LLM (LLM Scan)

[LLM_SIGNALS_SECTION]

## Nhận xét

[OBSERVATIONS]
