---
name: wf-fix-runtime-health
version: 1.1.0
last_updated: 2026-05-14
description: |
  QD9 Runtime Health Verification Lane — phat hien loi xay ra tren browser runtime: console errors, network failures, uncaught exceptions, auth flow broken, SPA routes unreachable, interactive CTAs khong hoat dong, form validation thieu.

  TRIGGER: spawned boi /wf-fix-bugs orchestrator khi QD9 trong selected_dims. KHONG goi truc tiep.
  SKIP: interface_type=api-only hoac --no-browser flag set.

argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive] [--base-url=URL] [--credentials=email:password|cookie:NAME=VALUE] [--login-url=URL] [--no-browser]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-runtime-health: QD9 Runtime Health Verification Lane

> **Shared Library:** `_shared/lane/_shared.md`, `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD9 — Runtime Health Verification |
| **Muc dich** | Phat hien loi xay ra khi chay tren browser: console errors, network failures, uncaught exceptions, broken auth flows, SPA routes unreachable, CTAs khong hoat dong, form validation thieu |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator |
| **Owner Agent** | `qa-lead`, `frontend-developer` |
| **Prerequisites** | `$SESSION_DIR` da tao, source code + `$BASE_URL` hop le; SKIP neu `interface_type=api-only` hoac `--no-browser` |
| **Duration** | 3-15 min tuy profile (quick=skip) |
| **Probes** | 7 (lazy-load; 3 core Wave 1, 4 deep Wave 1.5) |
| **Cache Policy** | skip (luon runtime — khong cache browser state) |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/{signals.json, lane-status.json, lane-report.md, phase-summary.md}` |

### Workflow Position

```
/wf-fix-bugs (orchestrator v9.x)
  → Spawn Lane QD9 (YOU ARE HERE) ─┐ CORE-025: parallel voi QD7, QD8 (Wave 3 batch)
  → ... (other lanes parallel)    ─┘
  → QD9 signals → Signal Bus aggregate
  → QD10 co the doc QD9 flow_unreliable[] de skip broken flows
  → Triage → Fix Execute → Verify → Report
```

Next step: Orchestrator tiep tuc Signal Aggregation. Console errors / network failures → wf-fix-triage phan loai.

## Probe Routing Table (Lazy-Load) — v10.2

| Probe ID | Loai | quick | standard | deep | exhaustive | Procedure file |
|----------|------|:-----:|:--------:|:----:|:----------:|----------------|
| P-QD9-dev-server-bootstrap | runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD9-dev-server-bootstrap.md` |
| P-QD9-console-network-monitor | runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD9-console-network-monitor.md` |
| P-QD9-auth-aware-smoke | runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD9-auth-aware-smoke.md` |
| P-QD9-interactive-smoke | runtime | ❌ | ✅ **v10.2** | ✅ | ✅ | `procedures/probes/P-QD9-interactive-smoke.md` |
| P-QD9-spa-route-coverage | runtime | ❌ | ✅ **v10.2** | ✅ | ✅ | `procedures/probes/P-QD9-spa-route-coverage.md` |
| P-QD9-disabled-cta-check | runtime | ❌ | ✅ **v10.2 NEW** | ✅ | ✅ | `procedures/probes/P-QD9-disabled-cta-check.md` |
| P-QD9-feature-checklist-smoke | runtime | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD9-feature-checklist-smoke.md` |
| P-QD9-llm-analysis | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd9-runtime-health.md` |
| P-QD9-form-validation-smoke | runtime | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD9-form-validation-smoke.md` |

> **quick profile:** Lane bi SKIP hoan toan — khong co browser execution trong quick. Ghi lane-status.json = "skipped" + ly do.
> **v10.2 changes:** Promote 3 probes vao `standard` profile de bat UI bugs (sidebar/popup/sheet/disabled-CTA). Cap MAX_ROUTES theo profile (10/20/50). Reduce destructive skip-list (bo cancel/reset).

### Per-profile caps (v10.2)

| Setting | quick | **standard** | deep | exhaustive |
|---------|-------|--------------|------|------------|
| `MAX_ROUTES` (interactive-smoke, spa-route-coverage) | — | **10** | 25 | 50 |
| `BUTTONS_PER_ROUTE` (interactive-smoke) | — | **8** | 20 | 30 |
| `MAX_SIGNALS` per probe | — | **50** | 100 | 200 |

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools duoc auto-detect, khong hoi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → call `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Skip neu non-git. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sanh HEAD vs index_commit. Freshness level → caveat trong probe context neu stale. | Freshness status set |
| 0.Nc | **CI Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select → inject vao probe execution context. | CI context ready |

### CI-ROUTE: Browser Runtime Discovery (Protocol 20 §20.5)

> **Khi `$GITNEXUS_AVAILABLE == "true"` hoac `$SERENA_AVAILABLE == "true"`:** PHAI dung GitNexus + Serena de trace navigation + locate login/auth handlers. KHONG dung Grep/Read thu cong khi CI tools available.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `find_auth_handlers` | **Serena** `find_symbol("login", "auth", "signin")` | Grep | Locate login form + auth handlers |
| `trace_navigation_flows` | **GitNexus** `query("navigation, route, link")` | `<a href>` traversal | Trace navigation flow tu homepage |
| `map_console_error_source` | **Serena** `find_symbol` theo stack trace file:line | Grep file:line | Khi console error co stack, map toi source |
| `find_router_config` | **Serena** `find_symbol("Routes", "createBrowserRouter", "pages/")` | Glob pages dir | Locate SPA router config |
| `trace_feature_route` | **GitNexus** `query("{feature_name}")` | Grep REQ-ID | Trace feature tu REQ-ID → UI route |
| `find_validators` | **Serena** `find_symbol` Zod/Yup/Joi schemas | Grep | Locate form validation rules |

## Phase 1: PRE-GATE + SENSE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE forensic + detect interface_type + resolve profile + verify BASE_URL | lane skill | `lane-status.json` (in_progress) |
| 2 | Phase SENSE — bootstrap dev server + inject listeners + traverse routes | lane skill | `phase4-find-bugs/lanes/QD9-runtime-health/raw/<probe>.jsonl` |

## Phase 2: THINK + ACT + VERIFY

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 3 | Phase THINK — phan tich console errors + network failures + auth issues | lane skill | (in-memory) |
| 4 | Phase ACT — chay deep probes neu profile=deep+ | lane skill | dom snapshots + screenshots + signals |
| 5 | Phase VERIFY — validate evidence + emit signals | lane skill | merged `signals.json` |
| 6 | POST-GATE T1-T4 + browser evidence check | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## Playwright Usage (QD9 — Runtime Health)

> Lane nay CAN Playwright de chay runtime probes tren browser that. B6 (spawning) + Playwright context duoc inject boi orchestrator qua prompt `_shared.md §15`.
> Detailed: Playwright modes, mobile devices, execution flow, evidence capture → `_shared.md §18`.

| Aspect | QD9 specifics |
|--------|---------------|
| **Scope** | Test toan bo URL: tu registry, route config, feature specs. Khong chi homepage. |
| **Browser** | Chromium headless (mac dinh). Visible neu `--show-browser`. |
| **Mobile** | iPhone 14, Pixel 7, iPad Pro (neu `--mobile`). |
| **Skip** | `interface_type=api-only` hoac `--no-browser` → lane skipped. |
| **What it checks** | Console errors, network failures (4xx/5xx), uncaught exceptions, auth flow broken, SPA routes unreachable, CTA non-reactive, form validation missing. |
| **Evidence** | Screenshot, console log panel, network HAR trace đuoc luu vao `evidence/` per page. |
| **Duration** | 3-15 min per scope size. Profile=quick → lane full skipped. |

## PRE-GATE

**Procedure:** `procedures/pre-gate.md`. Tom tat: 7 steps chuan + Step 8 detect interface_type (skip neu api-only) + Step 9 detect --no-browser flag (skip neu set) + Step 10 verify BASE_URL (dung detect-base-url.sh) + Step 11 resolve probe list QD9.

## Execution: Sense → Think → Act → Verify

Lane chay probes SEQUENTIAL (static probes truoc, runtime probes sau — chung 1 session browser instance). Static phase (CI-ROUTE) co the run truoc khi launch browser. Atomic emit qua `_shared/lane/signal-emit.md`. Session-isolated browser qua `playwright-session.js` (port + user-data-dir riêng).

## POST-GATE

**Procedure:** `procedures/post-gate.md` (T3 rules QD9: browser evidence required cho runtime signals, console-error severity check, network-failure evidence required).

## Severity Rules (QD9)

| Dieu kien | Severity | CDG Flag |
|-----------|----------|----------|
| Uncaught JavaScript exception (pageerror) | CRITICAL | — |
| Dev server khong start sau 30s | HIGH | — |
| Auth login fail 2 lan lien tiep | HIGH | — |
| Network 5xx khi navigate route (server error) | HIGH | — |
| Feature impl_status=done nhung UI route broken | HIGH | — |
| Console.error() khi load trang | MEDIUM | — |
| Network 4xx tren non-auth route (missing resource) | MEDIUM | — |
| SPA route dinh nghia trong router nhung khong navigate duoc | MEDIUM | — |
| Primary CTA khong co phan ung sau click (no state change, no nav) | MEDIUM | — |
| Form gui khong co validation error khi nhap sai | MEDIUM | — |
| Network 4xx tren auth route (expected, skip) | LOW | — |

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| critical | agent_fix (uncaught exception co file:line → fix) | frontend-developer |
| high | agent_fix | frontend-developer / qa-lead |
| medium | agent_fix hoac batch | frontend-developer |
| low | batch fix hoac skip | developer |

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `runtime/signals.json` | yes | `_shared/lane/templates/signals.json` | Lane signals với browser evidence (signal-v2). |
| `llm-scan/signals.json` | yes (nếu `--llm-scan`) | `_shared/lane/templates/signals.json` | LLM probe signals (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker. |
| `QD9-runtime-health-report.md` | yes | `_shared/lane/templates/lane-report.md` | Findings by severity + browser verification summary. |
| `raw/` | optional | — | Per-probe raw outputs (JSONL). |
| `evidence/` | optional | — | Screenshots, console logs, network traces. |

> `phase-summary.md` không còn được tạo — orchestrator tổng hợp vào `Phase4-report.md`.
> QD9 không có static probes (100% runtime), nên không có `static-scan/`.

**Cross-lane coordination:**
- Ghi `$LANE_OUTPUT_BASE/dev-server-state.json` — QD10 có thể đọc để reuse dev server session
- Ghi `$LANE_OUTPUT_BASE/flow-unreliable.json` — QD10 P-QD10-business-flow-runtime đọc để skip broken flows
- Ghi `$LANE_OUTPUT_BASE/auth-session.json` — QD10 có thể reuse session cookie/token

Next step: `/wf-fix-bugs` Signal Aggregation Phase 1 step 1.2.

## Error Handling

| Code | Tinh huong | Xu ly |
|------|-----------|-------|
| E091 | PRE-GATE FAIL | STOP — ghi lane-status.failed |
| E092 | interface_type=api-only (khong co UI) | SKIP lane — ghi lane-status.skipped + ly do |
| E093 | --no-browser flag set | SKIP lane — ghi lane-status.skipped + ly do |
| E094 | BASE_URL khong detect duoc | Emit signal HIGH "app_unreachable" + ghi lane-status.skipped |
| E095 | Dev server bootstrap fail (timeout 30s) | Emit signal HIGH "dev_server_bootstrap_fail" + skip remaining probes |
| E096 | Browser unavailable (playwright-session.js launch fail) | STOP probe, retry 3 lan, fallback toi tiep theo |
| E097 | Auth login fail (2 lan lien tiep) | Emit signal HIGH "auth_login_failed" + skip auth-dependent probes |
| E098 | POST-GATE T3 FAIL (thieu browser evidence) | STOP — return failed (compliance violation) |

## Registry Safe-Write

Lane KHONG ghi `req-registry.json`. Role: NONE.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator |
| `/wf-fix-triage` | Downstream — classify runtime errors |
| `/wf-fix-execute` | Downstream — fix browser bugs |
| `/wf-fix-functional` | Sibling lane QD1 (parallel — reuse navigation/form logic) |
| `/wf-fix-ux-a11y` | Sibling lane QD5 (parallel — overlap console listeners) |
| `/wf-fix-integration` | Sibling lane QD10 (downstream — reads QD9 flow-unreliable.json) |
| `qa-lead` agent | `.claude/agents/testing/qa-lead.md` |
| `frontend-developer` agent | `.claude/agents/engineering/frontend-developer.md` |

## References

- Reuse map: `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §2.2 (per-probe reuse), §3.2 (CI-ROUTE)
- Parallelism: `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §4.3 (probe class: all QD9 probes = runtime → sequential)
- Playwright MCP docs: `.claude/skills/protocols/20-code-intelligence.md`
- Core Rules: `.claude/rules/00-core.md` (CORE-006/007/011/012/023/025/026/027/028/030/031)
