---
name: wf-fix-business
version: 2.2.0
last_updated: 2026-05-10
description: |
  QD2 Business Correctness Lane — phat hien bug nghiep vu qua probes P-QD2-xxx (5 probes lazy-load).
  QD2 la North Star dimension (09-design-decisions.md §1) — luon chay o profile standard+.

  TRIGGER: spawned boi /wf-fix-bugs orchestrator khi QD2 trong selected_dims. KHONG goi truc tiep.


argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-business: QD2 Business Correctness Lane

> **Shared Library:** `_shared/lane/_shared.md`, `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD2 — Business Correctness (North Star) |
| **Muc dich** | Phat hien bug nghiep vu: tinh toan sai, quy trinh skip buoc, hardcoded business value, compliance violation |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator |
| **Prerequisites** | `$SESSION_DIR` da tao, `req-registry.json` co departments[] |
| **Duration** | 5-30 min (agent probes ton token) |
| **Probes** | 6 (lazy-load) |
| **Cache Policy** | Static probes: opt-in cache. Agent probes: skip cache. |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/{signals.json, lane-status.json, lane-report.md}` |

### Workflow Position

```
/wf-fix-bugs (orchestrator v10.x)
  → Spawn Lane QD2 (YOU ARE HERE) ─┐ CORE-025: parallel với other lanes
  → ... (other lanes parallel)    ─┘
  → Signal Bus aggregate
  → Triage → Fix Execute → Verify → Report
```

Next step: Orchestrator tiếp tục Signal Aggregation sau lane complete.

## Probe Routing Table (Lazy-Load)

| Probe ID | Loai | quick | standard | deep | exhaustive | Procedure file |
|----------|------|:-----:|:--------:|:----:|:----------:|----------------|
| P-QD2-hardcoded-value-detect | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD2-hardcoded-value-detect.md` |
| P-QD2-calculation-check | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD2-calculation-check.md` |
| P-QD2-domain-expert-review | agent | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD2-domain-expert-review.md` |
| P-QD2-domain-fixture | runtime+fixture | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD2-domain-fixture.md` |
| P-QD2-business-analyst-review | agent | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD2-business-analyst-review.md` |
| P-QD2-business-rule-coverage | static | ❌ | ❌ | ❌ | ✅ | `procedures/probes/P-QD2-business-rule-coverage.md` |
| P-QD2-llm-analysis | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd2-business.md` |

**Special:** profile=quick → SKIP toàn bộ QD2 (early exit trong PRE-GATE — xem `procedures/pre-gate.md` Step 8).

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools được auto-detect, không hỏi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → call `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Skip nếu non-git. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. Freshness level → caveat trong probe context nếu stale. | Freshness status set |
| 0.Nc | **CI Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select → inject vào probe execution context. IF no CI → exit 1 → continue với Grep/Glob (current behavior). | CI context ready |

### CI-ROUTE: Business Rule Validation (Protocol 20 §20.5)

> **Khi `$GITNEXUS_AVAILABLE == "true"` hoặc `$SERENA_AVAILABLE == "true"`:** PHẢI dùng GitNexus + Serena để trace business flows. KHÔNG dùng Grep/Read thủ công khi CI tools available.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `understand_flow` | **GitNexus** `query("{business_process}")` | Grep + Read | Trace business process flows liên quan đến domain rules |
| `find_references` | **Serena** `find_referencing_symbols` | Grep | Kiểm tra business rule value được reference ở đâu |
| `find_by_annotation` | **Both** — GitNexus cypher + Serena find_refs | Grep REQ-ID | Trace REQ-ID → code cho domain rules |

> **Freshness caveat:** Nếu index behind > 0 → kèm cảnh báo trong probe findings.

## Phase 1: PRE-GATE + SENSE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE forensic + check quick-skip + resolve profile | lane skill | `lane-status.json` (in_progress hoặc skipped) |
| 2 | Phase SENSE — chạy static probes (hardcoded-value, calculation-check) | lane skill | `phase4-find-bugs/lanes/QD2-business/raw/<probe>.json` |

## Phase 2: THINK + ACT + VERIFY

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 3 | Phase THINK — map departments → domain agents + reference files | lane skill | (in-memory) |
| 4 | Phase ACT — chạy agent probes (domain-expert-review, business-analyst-review) | lane skill | agent_output evidence + signals |
| 5 | Phase VERIFY — validate signal-v2 + agent output schema (CORE-029) | lane skill | merged `signals.json` |
| 6 | POST-GATE T1-T4 + render lane-report + phase-summary | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## PRE-GATE

**Procedure:** `procedures/pre-gate.md` (lane-specific). Tóm tắt: 7 steps chuẩn + Step 8 quick-skip + Step 9 verify domain agents available + Step 10 resolve probe list QD2.

## Execution: Sense → Think → Act → Verify

Lane chạy probes theo profile-resolver. Agent probes spawn `business/[domain]-expert` hoặc `business-analyst` qua Agent tool, output JSON theo schema CORE-029. Atomic emit qua `_shared/lane/signal-emit.md`.

### Agent Output Schema (CORE-029)

Domain expert agents PHẢI return JSON array:

```json
[{
  "type": "calculation_error|flow_missing_step|compliance_violation|hardcoded_value|ambiguous_logic|business_rule_uncovered",
  "description": ">= 50 ký tự",
  "file_path": "src/...",
  "line_range": [42, 58],
  "severity": "critical|high|medium|low",
  "evidence": "Đoạn code hoặc spec reference",
  "domain": "finance|hr|logistics|..."
}]
```

## POST-GATE

**Procedure:** `procedures/post-gate.md` (T3 rules QD2: agent output validation, hardcoded code evidence, reference rule cross-check).

## Severity Rules (QD2)

| Điều kiện | Severity |
|-----------|----------|
| Tính toán sai dẫn đến sai số tiền/quyết định | CRITICAL |
| Quy trình skip bước compliance (audit trail) | CRITICAL |
| Hard-coded tax/interest rate trong production code | CRITICAL |
| Hard-coded fee/commission trong service logic | HIGH |
| Hard-coded threshold nên là config | MEDIUM |
| Ambiguous logic (agent low confidence) | LOW + flag "needs_SME" |

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| critical | escalate (calculation/compliance — không auto-fix) | business-analyst + domain expert |
| high | agent_fix | business/[domain]-expert |
| medium | auto_fix (move hardcoded → config) | developer |
| low | skip hoặc agent_fix | business-analyst |

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD2-business/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `static-scan/signals.json` | yes | `_shared/lane/templates/signals.json` | Static probe signals (signal-v2). |
| `runtime/signals.json` | yes | `_shared/lane/templates/signals.json` | Runtime/agent probe signals (signal-v2). |
| `llm-scan/signals.json` | yes (neu `--llm-scan`) | `_shared/lane/templates/signals.json` | LLM probe signals (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker (lane-status-v1). |
| `QD2-business-report.md` | yes | `_shared/lane/templates/lane-report.md` | Findings by department + severity. |
| `raw/` | optional | — | Per-probe raw outputs. |
| `evidence/` | optional | — | Screenshots, traces. |

> `phase-summary.md` khong con duoc tao — orchestrator tong hop vao `Phase4-report.md`.

Next step: `/wf-fix-bugs` Signal Aggregation Phase 1 step 1.2.

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E041 | PRE-GATE FAIL (SESSION_DIR/registry/departments[] empty) | STOP — ghi lane-status.failed |
| E042 | Agent timeout (domain-expert-review) | Retry 1 lần → fail → skip probe, note "agent_timeout" |
| E043 | Agent output invalid (CORE-029 schema fail) | Drop findings, log WARNING, note trong lane-report |
| E044 | Domain không có agent (.claude/agents/business/[dept]-expert.md) | Skip department, note "no_domain_agent:{dept}" |
| E045 | POST-GATE T3 FAIL (agent signals thiếu domain/evidence) | Retry generate, max 2 lần → status=partial |
| E046 | Profile=quick → SKIP toàn bộ QD2 | Exit 0 với phase-summary giải thích lý do |

## Registry Safe-Write

Lane KHÔNG ghi `req-registry.json`. Role: NONE. Chỉ đọc departments[] để map domain agents.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator |
| `/wf-fix-triage` | Downstream |
| `/wf-fix-execute` | Downstream |
| `/wf-fix-functional` | Sibling lane QD1 (parallel) |
| `/wf-fix-security` | Sibling lane QD3 (parallel) |
| 25 domain agents | `.claude/agents/business/{domain}-expert.md` (spawn cho P-QD2-domain-expert-review) |

## References

- Quality Dimensions: `docs/design/skills/wf-fix-bugs/02-quality-dimensions.md` §QD2
- Design Decisions: `docs/design/skills/wf-fix-bugs/09-design-decisions.md` §1 North Star
- Domain References: `.claude/references/team-expert/[domain]/`
- Core Rules: `.claude/rules/00-core.md` (CORE-006/007/011/012/023/025/026/028/029/030/031)
