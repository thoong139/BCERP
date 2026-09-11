---
name: wf-fix-compat
version: 2.0.0-alpha.s4
last_updated: 2026-05-15
description: |
  QD7 Compatibility & Portability Lane — phat hien browser compat, responsive, i18n, env parity issues qua probes P-QD7-xxx (5 probes lazy-load).

  TRIGGER: spawned boi /wf-fix-bugs orchestrator khi QD7 trong selected_dims. KHONG goi truc tiep.

  v2.0 (S3-S4): chuan hoa schema, tach probes + pre-gate + post-gate ra procedures/ (lazy-load). Fix F8, F9, F10, F16.

argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive] [--use-cache] [--base-url=URL]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-compat: QD7 Compatibility & Portability Lane

> **Shared Library:** `_shared/lane/_shared.md`, `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD7 — Compatibility & Portability |
| **Muc dich** | Cross-browser (Chromium/Firefox/WebKit), responsive (4 breakpoints), i18n (locale/RTL/timezone), env parity dev/stage/prod |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator |
| **Owner Agent** | `frontend-developer`, `accessibility-reviewer` (RTL) |
| **Prerequisites** | `$SESSION_DIR` da tao, source code ton tai |
| **Duration** | 2-15 min tuy profile |
| **Probes** | 5 (lazy-load) |
| **Cache Policy** | Static probes (deprecated-api, polyfill, env): opt-in. Runtime (browser, breakpoint): skip cache. |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat/{signals.json, lane-status.json, lane-report.md, phase-summary.md}` |

### Browser Compat Matrix

| Browser | Min Version | Profile chạy |
|---------|-------------|--------------|
| Chromium | latest | quick+ (always) |
| Firefox | latest | standard+ |
| WebKit (Safari) | latest | deep+ |
| Edge | latest | exhaustive+ |

### Breakpoint Matrix

| Breakpoint | Width | Profile chạy |
|------------|-------|--------------|
| Mobile portrait | 360x640 | exhaustive |
| Mobile landscape / Tablet portrait | 768x1024 | exhaustive |
| Laptop | 1366x768 | exhaustive |
| Desktop wide | 1920x1080 | exhaustive |

### Workflow Position

```
/wf-fix-bugs (orchestrator v10.x)
  → Spawn Lane QD7 (YOU ARE HERE) ─┐ CORE-025: parallel với other lanes
  → ... (other lanes parallel)    ─┘ Skip browser probes if api-only
  → Signal Bus aggregate
  → Triage → Fix Execute → Verify → Report
```

Next step: Orchestrator tiếp tục Signal Aggregation sau lane complete.

## Probe Routing Table (Lazy-Load)

| Probe ID | Loai | quick | standard | deep | exhaustive | Procedure file |
|----------|------|:-----:|:--------:|:----:|:----------:|----------------|
| P-QD7-deprecated-api-usage | static | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD7-deprecated-api-usage.md` |
| P-QD7-api-version-compat | static+runtime | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD7-api-version-compat.md` |
| P-QD7-browser-compat-check | static+runtime | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD7-browser-compat-check.md` |
| P-QD7-polyfill-coverage | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD7-polyfill-coverage.md` |
| P-QD7-llm-analysis | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd7-compatibility.md` |
| P-QD7-device-breakpoint-test | runtime | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD7-device-breakpoint-test.md` |

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools được auto-detect, không hỏi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → call `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Skip nếu non-git. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. Freshness level → caveat trong probe context nếu stale. | Freshness status set |
| 0.Nc | **CI Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select → inject vào probe execution context. IF no CI → exit 1 → continue với Grep/Glob (current behavior). | CI context ready |

### CI-ROUTE: Compatibility Discovery (Protocol 20 §20.5)

> **Khi `$GITNEXUS_AVAILABLE == "true"` hoặc `$SERENA_AVAILABLE == "true"`:** PHẢI dùng Serena để trace deprecated API usage. KHÔNG dùng Grep/Read thủ công khi CI tools available.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `find_references` | **Serena** `find_referencing_symbols` | Grep | Tìm deprecated API usage, polyfill dependencies |
| `symbol_overview` | **Serena** `get_symbols_overview` | Read file | Kiểm tra browser-specific code paths, fallback structures |
| `understand_flow` | **GitNexus** `query("{feature}_compat")` | Grep + Read | Trace browser-specific execution flows, env-dependent paths |

> **Freshness caveat:** Nếu index behind > 0 → kèm cảnh báo trong probe findings.

## Phase 1: PRE-GATE + SENSE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE forensic + check api-only + verify Playwright + resolve profile | lane skill | `lane-status.json` (in_progress) |
| 2 | Phase SENSE — chạy static probes (deprecated, polyfill, env-parity) | lane skill | `phase4-find-bugs/lanes/QD7-compat/raw/<probe>.json` |

## Phase 2: THINK + ACT + VERIFY

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 3 | Phase THINK — diff browser compat matrix vs targets | lane skill | (in-memory) |
| 4 | Phase ACT — chạy runtime probes (multi-browser, breakpoints, i18n fallback) | lane skill | screenshots + signals |
| 5 | Phase VERIFY — validate browser identifier + viewport in signals | lane skill | merged `signals.json` |
| 6 | POST-GATE T1-T4 + browser matrix coverage check | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## Playwright Usage (QD7 — Compatibility & Portability)

> Lane nay CAN Playwright de chay runtime probes (multi-browser, breakpoint test). B6 (spawning) + Playwright context duoc inject boi orchestrator qua prompt `_shared.md §15`.
> Detailed: Playwright modes, mobile devices, sequential scheduling → `_shared.md §18`.

| Aspect | QD7 specifics |
|--------|---------------|
| **Scope** | Test toan bo pages co responsive-critical UI: registry + route config. |
| **Browser** | Chromium (mac dinh). Firefox + WebKit neu deep+. Edge neu exhaustive. |
| **Mobile** | 4 breakpoints: 360x640, 768x1024, 1366x768, 1920x1080 (neu deep+). Trung voi `--responsive` flag. |
| **Skip** | `interface_type=api-only` → chi chay static probes, skip browser. |
| **What it checks** | Cross-browser layout broken, viewport CLS, deprecated API polyfill gaps, i18n locale/RTL, env parity. |
| **Evidence** | Screenshot per browser+breakpoint combo + browser console log vao `evidence/`. |
| **Duration** | 2-15 min. Profile=quick: chi Chromium static probes, khong runtime browser. |

## PRE-GATE

**Procedure:** `procedures/pre-gate.md`. Tóm tắt: 7 steps chuẩn + Step 8 detect interface_type (api-only) + Step 9 verify Playwright + Step 10 verify env files + Step 11 verify --base-url + Step 12 resolve probe list QD7.

## Execution: Sense → Think → Act → Verify

Lane chạy probes theo profile-resolver. Atomic emit qua `_shared/lane/signal-emit.md`. Mỗi runtime signal có browser identifier + viewport dimension trong description hoặc evidence.

## POST-GATE

**Procedure:** `procedures/post-gate.md` (T3 rules QD7: browser/viewport identifier required, mobile-layout severity threshold, env file path required, deep+ matrix coverage ≥2 browsers).

## Severity Rules (QD7)

| Điều kiện | Severity |
|-----------|----------|
| Layout vỡ trên mobile (CLS > 0.25) | HIGH |
| Firefox/WebKit feature crash hoặc không chạy | HIGH |
| Required env var missing trong .env.production | HIGH |
| Deprecated API removed in next major version (within 6 months) | HIGH |
| Optional env var missing | MEDIUM |
| Hard-coded locale / date format / currency | MEDIUM |
| Deprecated API still working (no immediate removal) | MEDIUM |
| Polyfill missing for legacy browser support (IE11) | MEDIUM (if support needed) hoặc LOW (modern apps) |
| Inconsistent breakpoint behavior minor | LOW |
| All browsers passed | INFO |

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| critical | escalate (rare for QD7 — usually mobile crash blocks release) | frontend-developer |
| high | agent_fix (browser-specific polyfill / responsive CSS / env var) | frontend-developer / devops |
| medium | agent_fix (config update, locale extraction) | developer |
| low | batch fix hoặc skip | frontend-developer |

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD7-compat/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `static-scan/signals.json` | yes | `_shared/lane/templates/signals.json` | Static probe signals với browser/viewport info (signal-v2). |
| `runtime/signals.json` | yes | `_shared/lane/templates/signals.json` | Runtime probe signals (signal-v2). |
| `llm-scan/signals.json` | yes (nếu `--llm-scan`) | `_shared/lane/templates/signals.json` | LLM probe signals (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker. |
| `QD7-compat-report.md` | yes | `_shared/lane/templates/lane-report.md` | Browser compat matrix + findings. |
| `raw/` | optional | — | Per-probe raw outputs. |
| `evidence/` | optional | — | Screenshots, browser logs. |

> `phase-summary.md` không còn được tạo — orchestrator tổng hợp vào `Phase4-report.md`.

Next step: `/wf-fix-bugs` Signal Aggregation Phase 1 step 1.2.

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E041 | PRE-GATE FAIL | STOP — ghi lane-status.failed |
| E042 | interface_type=api-only → skip browser probes | Run static-only (deprecated, env), note "api_only_partial" |
| E043 | Playwright không cài | Fallback static check, skip runtime browser probes |
| E044 | Runtime probe — BASE_URL không có | Skip browser/breakpoint probes, note "skipped_no_base_url" |
| E045 | .env files không có | Skip env parity check, note "no_env_files" |
| E046 | POST-GATE T3 FAIL (browser identifier missing) | Retry generate, max 2 lần → status=partial |
| E047 | BrowserStack/SauceLabs not configured (exhaustive) | Fallback local Playwright, log degraded coverage |
| E048 | Deprecated API check tool fail | Fallback grep known patterns, log WARNING |

## Registry Safe-Write

Lane KHÔNG ghi `req-registry.json`. Role: NONE.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator |
| `/wf-fix-triage` | Downstream |
| `/wf-fix-execute` | Downstream |
| `/wf-fix-ux-a11y` | Sibling lane QD5 (parallel — responsive overlap) |
| `/wf-fix-functional` | Sibling lane QD1 (parallel) |
| `frontend-developer` agent | `.claude/agents/engineering/frontend-developer.md` |
| `accessibility-reviewer` agent | `.claude/agents/testing/accessibility-auditor.md` (RTL focus) |

## References

- Quality Dimensions: `docs/design/skills/wf-fix-bugs/02-quality-dimensions.md` §QD7
- Architecture: `docs/design/skills/wf-fix-bugs/03-architecture.md`
- MDN Browser Compat: https://developer.mozilla.org/en-US/docs/Web/API
- Core Rules: `.claude/rules/00-core.md` (CORE-006/007/011/012/023/025/026/028/030/031)
