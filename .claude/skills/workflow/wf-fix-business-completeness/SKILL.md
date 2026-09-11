---
name: wf-fix-business-completeness
version: 1.0.0
last_updated: 2026-05-12
description: |
  QD11 Business Completeness & Enhancement Lane — phat hien MISSING business logic qua 3-pass LLM analysis: cross-module pattern comparison, domain heuristic analysis, registry gap detection.

  TRIGGER: spawned boi /wf-fix-bugs orchestrator khi QD11 trong selected_dims. KHONG goi truc tiep.

argument-hint: "[--session-dir=PATH] [--profile=standard|deep|exhaustive]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, AskUserQuestion, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-business-completeness: QD11 Business Completeness & Enhancement Lane

> **Shared Library:** `_shared/lane/_shared.md`, `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD11 — Business Completeness & Enhancement |
| **Muc dich** | Phat hien MISSING business logic ma static probes khong the thay: cross-module pattern gaps (module A co feature X nhung module B cung domain lai thieu), domain-specific mandatory fields/rules chua implement, requirements registry co nhung code chua implement |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator |
| **Owner Agent** | `business-analyst`, domain experts, `architect` |
| **Prerequisites** | `$SESSION_DIR` da tao, `req-registry.json` co >=2 modules cung domain (cross_module_dependencies[]) |
| **Duration** | 5-30 min tuy profile + so luong module |
| **Probes** | 3 (100% LLM, 3-pass analysis) |
| **Cache Policy** | LLM probes — khong dung scan cache (moi run la fresh analysis) |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD11-business-completeness/{signals.json, lane-status.json, lane-report.md, enhancement-suggestions.json}` |

### Core Question

> "What BUSINESS logic is MISSING?" — not just "is existing logic correct?"

QD11 khac biet voi QD1-QD10 o cho: no khong tim BUG trong code hien tai, ma tim LOGIC CHUA CO. Vi du: module Sales co "export PDF" nhung module Invoice cung domain lai thieu → QD11 emit MISSING_FEATURE signal.

### Skip Conditions

| Condition | Reason |
|-----------|--------|
| `single_module` | Project chi co 1 module — khong the cross-reference |
| `api_only` | `interface_type=api-only` — khong co UI de so sanh entity forms/lists |
| `profile_quick` | Profile quick — skip LLM-heavy completeness analysis |

### Workflow Position

```
/wf-fix-bugs (orchestrator v9.1.x)
  → Spawn Lane QD11 (YOU ARE HERE) ─┐ CORE-025: parallel voi other lanes
  → ... (other lanes parallel)      ─┘
  → Signal Bus aggregate
  → Triage → CDG Gate (user ACCEPT/REJECT enhancement suggestions) → Execute → Report
```

Next step: Orchestrator tiep tuc Signal Aggregation. Enhancement suggestions (accepted) → wf-fix-execute implement.

## Probe Routing Table

| Probe ID | Type | quick | standard | deep | exhaustive | Prompt file |
|----------|------|:-----:|:--------:|:----:|:----------:|-------------|
| P-QD11-cross-module-comparison | llm | ❌ | ✅ | ✅ | ✅ | `prompts/llm-probe-qd11-cross-module.md` |
| P-QD11-domain-heuristic | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd11-domain-heuristic.md` |
| P-QD11-registry-gap | llm | ❌ | ✅ | ✅ | ✅ | `prompts/llm-probe-qd11-registry-gap.md` |

## Phase 1: PRE-GATE + Discovery

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE: check skip conditions (single_module, api_only, profile_quick) | lane skill | `lane-status.json` (in_progress hoac skipped) |
| 2 | Load domain references + cross-module dependencies | lane skill | context ready |
| 3 | Resolve probe list via profile_resolver.py | lane skill | selected probes |

## Phase 2: 3-Pass LLM Execution + POST-GATE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | Pass 1 — Cross-Module Pattern Comparison | agent (business-analyst) | signals (MISSING_FIELD, MISSING_FEATURE, TYPE_MISMATCH, VALIDATION_GAP) |
| 2 | Pass 2 — Domain Heuristic Analysis | agent (domain expert) | signals (MISSING_DOMAIN_FIELD, MISSING_COMPLIANCE_CHECK, MISSING_AUDIT_TRAIL, MISSING_BUSINESS_RULE) |
| 3 | Pass 3 — Registry Gap Detection | agent (business-analyst) | signals (UNIMPLEMENTED_REQ, ORPHAN_REQ_ID, GAP_REQ_TO_FEAT) |
| 4 | Signal validation + dedup | lane skill | validated `signals.json` |
| 5 | POST-GATE T1-T4 + CDG gate + enhancement-suggestions.json | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## PRE-GATE

1. **Check skip conditions:**
   - Count modules in registry → if 1 → skip with reason "single_module"
   - Check `interface_type` = `api-only` → skip with reason "api_only"
   - Check `profile` = `quick` → skip with reason "profile_quick"
2. **Load domain references:** Read `.claude/references/team-expert/` matching registry departments
3. **Load cross-module dependencies:** Extract `cross_module_dependencies[]` from `req-registry.json`
4. **Resolve probe list:** Use `profile_resolver.py` with `dimension.json` exit_criteria
5. Initialize `lane-status.json` (in_progress)

## Execution: 3-Pass LLM Analysis

### Pass 1: Cross-Module Pattern Comparison (HIGH confidence)

So sanh entity forms, lists, workflows giua cac module cung domain. Emit signals khi 1 module THIEU features/fields/validations ma module khac CO.

**Agent:** `business-analyst` (hoac domain expert neu chi 1 domain)
**Prompt:** `prompts/llm-probe-qd11-cross-module.md`
**Signals:** MISSING_FIELD (MEDIUM), MISSING_FEATURE (HIGH), TYPE_MISMATCH (MEDIUM), VALIDATION_GAP (LOW)

### Pass 2: Domain Heuristic Analysis (MEDIUM confidence)

Tham chieu domain rules tu `.claude/references/team-expert/[domain]/` de kiem tra codebase co thieu mandatory fields, compliance checks, hoac business rules dac thu domain khong.

**Agent:** Domain expert (resolve tu registry.departments[])
**Prompt:** `prompts/llm-probe-qd11-domain-heuristic.md`
**Signals:** MISSING_DOMAIN_FIELD (MEDIUM), MISSING_COMPLIANCE_CHECK (HIGH), MISSING_AUDIT_TRAIL (MEDIUM), MISSING_BUSINESS_RULE (HIGH)

### Pass 3: Registry Gap Detection (HIGHEST confidence)

Cross-reference `req-registry.json` requirements vs code implementation. Phat hien requirements co trong registry nhung khong co code, FEAT-ID khong map toi file nao, REQ-ID da mark "done" nhung code khong co annotation.

**Agent:** `business-analyst`
**Prompt:** `prompts/llm-probe-qd11-registry-gap.md`
**Signals:** UNIMPLEMENTED_REQ (HIGH), ORPHAN_REQ_ID (MEDIUM), GAP_REQ_TO_FEAT (MEDIUM)

## POST-GATE

T1: File existence → `signals.json`, `enhancement-suggestions.json`
T2: Schema validation → `lane-signals-v1`, `enhancement-suggestions-v1`
T3: Content depth → each signal co evidence + suggestion
T4: Cross-reference → signals reference valid REQ-ID/FEAT-ID tu registry

### CDG Gate (Critical Decision Gate)

Sau POST-GATE, chi HIGH enhancement suggestion duoc trinh bay cho user qua CDG gate. MEDIUM/LOW signals duoc auto-accept (khong can CDG):
- User ACCEPT → suggestion dua vao `enhancement-suggestions.json` de downstream implement
- User REJECT → suggestion bi loai bo (ghi ly do reject)

KHONG auto-implement enhancement suggestions — day la BUSINESS decision, khong phai ky thuat.

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| HIGH | CDG gate — user ACCEPT/REJECT enhancement suggestion | business-analyst + domain expert |
| MEDIUM | auto-accept — khong can CDG gate | business-analyst |
| LOW | auto-accept — khong can CDG gate | business-analyst |

## Severity Rules (QD11)

| Condition | Severity | CDG Flag |
|-----------|----------|----------|
| Feature ton tai trong module A nhung thieu trong module B cung domain | HIGH | CDG-ENHANCEMENT |
| Requirement trong registry, impl_status=not_started, nhung lien quan den scope | HIGH | — |
| Requirement trong registry, impl_status=done, nhung khong tim thay annotation trong code | MEDIUM | — |
| Field ton tai trong reference module nhung thieu trong target | MEDIUM | CDG-ENHANCEMENT |
| Requirement khong co FEAT-ID mapping | MEDIUM | — |
| Cung field name nhung khac type giua cac module | MEDIUM | — |
| Reference module co validation nhung target khong co | LOW | — |

## Enhancement Suggestions Lifecycle

```
Pass 1-3 → signals.json (raw signals)
         → CDG Gate (user ACCEPT/REJECT)
         → enhancement-suggestions.json (accepted only)
         → wf-fix-execute (implement accepted suggestions)
```

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD11-business-completeness/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `llm-scan/signals.json` | yes | `_shared/lane/templates/signals.json` | LLM probe signals với enhancement evidence (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker. |
| `QD11-business-completeness-report.md` | yes | `_shared/lane/templates/lane-report.md` | Findings by severity + enhancement gaps. |
| `raw/` | optional | — | Per-probe raw outputs. |
| `enhancement-suggestions.json` | yes | (inline) | Accepted enhancement suggestions sau CDG gate. |

> `phase-summary.md` không còn được tạo — orchestrator tổng hợp vào `Phase4-report.md`.
> QD11 chỉ có LLM probes (100% agent), nên chỉ có `llm-scan/`.

Next step: `/wf-fix-bugs` Signal Aggregation → CDG Gate → Triage → Execute accepted enhancement suggestions.

## Error Handling

| Code | Tinh huong | Xu ly |
|------|-----------|-------|
| E111 | PRE-GATE FAIL (single module) | STOP — ghi lane-status.skipped, reason=single_module |
| E112 | PRE-GATE FAIL (api-only) | STOP — ghi lane-status.skipped, reason=api_only |
| E113 | PRE-GATE FAIL (profile=quick) | STOP — ghi lane-status.skipped, reason=profile_quick |
| E114 | Agent timeout (business-analyst) | Skip probe, emit 0 signals |
| E115 | POST-GATE T3 FAIL (thieu enhancement-suggestions.json) | STOP — return failed |
| E116 | No cross_module_dependencies in registry | Skip Pass 1, continue Pass 2+3 |
| E117 | No domain references found | Skip Pass 2, continue Pass 1+3 |
| E118 | req-registry.json empty/missing | Skip Pass 3, continue Pass 1+2 |

## Registry Safe-Write

Lane KHONG ghi `req-registry.json`. Role: NONE.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator |
| `/wf-fix-triage` | Downstream — CDG-ENHANCEMENT signals escalate to user decision |
| `/wf-fix-execute` | Downstream — implement accepted enhancement suggestions |
| `/wf-fix-business` | Sibling lane QD2 (parallel — overlap business rules) |
| `/wf-fix-integration` | Sibling lane QD10 (parallel — overlap cross-module) |
| `business-analyst` agent | `.claude/agents/business/business-analyst.md` |
| `architect` agent | `.claude/agents/engineering/architect.md` |

## References

- Quality Dimensions: QD11 — Business Completeness & Enhancement
- Core Rules: `.claude/rules/00-core.md` (CORE-004, CORE-006/007/011/012/023/025/026/027/028/030/031)
- Registry Safe-Write Protocol: `.claude/skills/protocols/05-registry-safe-write.md`
- CDG Protocol: `.claude/skills/protocols/16-critical-decision-gate.md`
- Domain References: `.claude/references/team-expert/`
