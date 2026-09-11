---
name: wf-fix-ux-a11y
version: 2.0.0-alpha.s4
last_updated: 2026-04-28
description: |
  QD5 Accessibility & UX Lane — phat hien WCAG 2.2 AA violations + UX heuristic issues qua probes P-QD5-xxx (7 probes lazy-load).
  Bao gom axe-core, color contrast, keyboard navigation, ARIA, label consistency, responsive layout.

  TRIGGER: spawned boi /wf-fix-bugs orchestrator khi QD5 trong selected_dims VA interface_type != "api-only". KHONG goi truc tiep.

  v2.0 (S3-S4): chuan hoa schema, tach probes + pre-gate + post-gate ra procedures/ (lazy-load). Fix F8, F9, F10, F16.

argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive] [--base-url=URL]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-ux-a11y: QD5 Accessibility & UX Lane

> **Shared Library:** `_shared/lane/_shared.md`, `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD5 — Accessibility & UX |
| **Muc dich** | WCAG 2.2 AA conformance + UX Nielsen heuristics + content quality (microcopy, error states) |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator (skip nếu interface_type=api-only) |
| **Owner Agent** | `ux-researcher`, `accessibility-auditor` |
| **Prerequisites** | `$SESSION_DIR` da tao, source code có UI (interface_type != api-only) |
| **Duration** | 3-15 min tuy profile |
| **Probes** | 7 (lazy-load) |
| **Cache Policy** | Static probes (aria scan, label): opt-in. Runtime probes (axe, keyboard nav): skip cache. |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/{signals.json, lane-status.json, lane-report.md, phase-summary.md}` |

### Workflow Position

```
/wf-fix-bugs (orchestrator v9.x)
  → Spawn Lane QD5 (YOU ARE HERE) ─┐ CORE-025: parallel với other lanes
  → ... (other lanes parallel)    ─┘ Skip if interface_type=api-only
  → Signal Bus aggregate
  → Triage → Fix Execute → Verify → Report
```

Next step: Orchestrator tiếp tục Signal Aggregation sau lane complete.

## Probe Routing Table (Lazy-Load)

| Probe ID | Loai | quick | standard | deep | exhaustive | Procedure file |
|----------|------|:-----:|:--------:|:----:|:----------:|----------------|
| P-QD5-ui-traversal-deep | runtime | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD5-ui-traversal-deep.md` |
| P-QD5-label-consistency | static+runtime | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD5-label-consistency.md` |
| P-QD5-accessibility-check | runtime+agent | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD5-accessibility-check.md` |
| P-QD5-color-contrast-audit | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD5-color-contrast-audit.md` |
| P-QD5-keyboard-nav-check | runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD5-keyboard-nav-check.md` |
| P-QD5-aria-attribute-scan | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD5-aria-attribute-scan.md` |
| P-QD5-responsive-layout | runtime | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD5-responsive-layout.md` |
| P-QD5-llm-analysis | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd5-ux-a11y.md` |

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools được auto-detect, không hỏi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → call `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Skip nếu non-git. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. Freshness level → caveat trong probe context nếu stale. | Freshness status set |
| 0.Nc | **CI Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select → inject vào probe execution context. IF no CI → exit 1 → continue với Grep/Glob (current behavior). | CI context ready |

### CI-ROUTE: Accessibility & UX Audit (Protocol 20 §20.5)

> **Khi `$GITNEXUS_AVAILABLE == "true"` hoặc `$SERENA_AVAILABLE == "true"`:** PHẢI dùng Serena để phân tích UI component structure. KHÔNG dùng Read thủ công khi CI tools available.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `symbol_overview` | **Serena** `get_symbols_overview` | Read file | Hiểu cấu trúc UI component, xác định ARIA roles |
| `find_references` | **Serena** `find_referencing_symbols` | Grep | Kiểm tra ARIA attributes, label usage xuyên suốt codebase |
| `understand_flow` | **GitNexus** `query("navigation, keyboard")` | Grep + Read | Trace keyboard navigation flows, focus management |

> **Freshness caveat:** Nếu index behind > 0 → kèm cảnh báo trong probe findings.

## Phase 1: PRE-GATE + SENSE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE forensic + check api-only skip + verify a11y tools | lane skill | `lane-status.json` (in_progress hoặc skipped) |
| 2 | Phase SENSE — chạy static probes (aria, label, contrast) | lane skill | `phase4-find-bugs/lanes/QD5-ux-a11y/raw/<probe>.json` |

## Phase 2: THINK + ACT + VERIFY

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 3 | Phase THINK — map findings → WCAG criterion | lane skill | (in-memory) |
| 4 | Phase ACT — chạy runtime probes (axe, keyboard, responsive, deep traversal) | lane skill | screenshots + signals |
| 5 | Phase VERIFY — validate signal-v2 + WCAG ref + selector required | lane skill | merged `signals.json` |
| 6 | POST-GATE T1-T4 + WCAG severity threshold check | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## Playwright Usage (QD5 — Accessibility & UX)

> Lane nay CAN Playwright de chay runtime probes (axe-core, keyboard nav, responsive layout, deep UI traversal). B6 (spawning) + Playwright context duoc inject boi orchestrator qua prompt `_shared.md §15`.
> Detailed: Playwright modes, sequential scheduling → `_shared.md §18`.

| Aspect | QD5 specifics |
|--------|---------------|
| **Scope** | Test toan bo pages co UI: registry + route config + feature specs. |
| **Browser** | Chromium headless. Visible neu `--show-browser`. |
| **Mobile** | Khong can (QD7 lo responsive check). Chi dung desktop viewport. |
| **Skip** | `interface_type=api-only` → lane skipped. |
| **What it checks** | axe-core WCAG violations, keyboard trap, focus order, ARIA roles, label consistency, color contrast, responsive layout (deep+). |
| **Evidence** | Screenshot + axe-core HTML report + focus-path trace duoc luu vao `evidence/`. |
| **Duration** | 3-15 min. Profile=quick: 2 probes runtime (traversal + label + a11y-check). |

## PRE-GATE

## Execution: Sense → Think → Act → Verify

Lane chạy probes theo profile-resolver. Atomic emit qua `_shared/lane/signal-emit.md`. Mỗi signal có `location.selector` (CSS selector) + WCAG criterion ref trong description.

## POST-GATE

**Procedure:** `procedures/post-gate.md` (T3 rules QD5: WCAG ref required, contrast ratio numeric, severity threshold cho keyboard trap, CSS selector required).

## Severity Rules (QD5)

| Điều kiện | Severity | WCAG ref |
|-----------|----------|----------|
| WCAG Level A violation trên primary user flow | CRITICAL | (per criterion) |
| Keyboard trap (focus không thoát) | HIGH | 2.1.2 No Keyboard Trap |
| Contrast text < 3:1 (huge text) | HIGH | 1.4.3 Contrast (Minimum) |
| Contrast text < 4.5:1 (regular text) | MEDIUM | 1.4.3 Contrast (Minimum) |
| Focus indicator không visible | HIGH | 2.4.7 Focus Visible |
| axe violation `critical/serious` | HIGH | (per axe-core mapping) |
| Touch target < 24x24px | MEDIUM | 2.5.8 Target Size (Min) |
| Missing alt text on informative image | MEDIUM | 1.1.1 Non-text Content |
| Missing aria-label on icon-only button | MEDIUM | 4.1.2 Name, Role, Value |
| axe violation `moderate` | MEDIUM | (per axe-core mapping) |
| Inconsistent label across pages | LOW | 3.2.4 Consistent Identification |
| Spacing/typography polish | LOW | (UX heuristic, non-WCAG) |
| WCAG AA passed (no issue) | INFO | — |

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| critical | escalate (cần audit accessibility-auditor) | accessibility-auditor |
| high | agent_fix | accessibility-auditor / frontend-developer / ui-designer |
| medium | agent_fix (add aria-label, fix contrast) | frontend-developer |
| low | batch fix hoặc skip | ui-designer |

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `static-scan/signals.json` | yes | `_shared/lane/templates/signals.json` | Static probe signals với WCAG refs + selectors (signal-v2). |
| `runtime/signals.json` | yes | `_shared/lane/templates/signals.json` | Runtime probe signals (signal-v2). |
| `llm-scan/signals.json` | yes (nếu `--llm-scan`) | `_shared/lane/templates/signals.json` | LLM probe signals (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker. |
| `QD5-ux-a11y-report.md` | yes | `_shared/lane/templates/lane-report.md` | Findings by WCAG criterion + severity. |
| `raw/` | optional | — | Per-probe raw outputs. |
| `evidence/` | optional | — | Screenshots, axe-core reports. |

> `phase-summary.md` không còn được tạo — orchestrator tổng hợp vào `Phase4-report.md`.

Next step: `/wf-fix-bugs` Signal Aggregation Phase 1 step 1.2.

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E041 | PRE-GATE FAIL | STOP — ghi lane-status.failed |
| E042 | interface_type=api-only → SKIP toàn bộ QD5 | Exit 0 với phase-summary giải thích |
| E043 | axe-core không cài | Fallback static aria scan only, log WARNING |
| E044 | Playwright không cài | Skip P-QD5-keyboard-nav-check + P-QD5-responsive-layout |
| E045 | Runtime probe — BASE_URL không có | Skip runtime probes, note "skipped_no_base_url" |
| E046 | POST-GATE T3 FAIL (selector missing) | Retry generate, max 2 lần → status=partial |
| E047 | Color contrast tool fail | Fallback manual rgb math, log WARNING |
| E048 | Agent timeout (P-QD5-accessibility-check ux-researcher) | Skip probe, emit 0 signals |

## Registry Safe-Write

Lane KHÔNG ghi `req-registry.json`. Role: NONE.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator |
| `/wf-fix-triage` | Downstream |
| `/wf-fix-execute` | Downstream |
| `/wf-fix-functional` | Sibling lane QD1 (parallel — UI overlap) |
| `/wf-fix-compat` | Sibling lane QD7 (parallel — responsive overlap) |
| `accessibility-auditor` agent | `.claude/agents/testing/accessibility-auditor.md` |
| `ux-researcher` agent | `.claude/agents/design/ux-researcher.md` |

## References

- Quality Dimensions: `docs/design/skills/wf-fix-bugs/02-quality-dimensions.md` §QD5
- WCAG 2.2: https://www.w3.org/TR/WCAG22/
- Core Rules: `.claude/rules/00-core.md` (CORE-006/007/011/012/023/025/026/028/030/031)
