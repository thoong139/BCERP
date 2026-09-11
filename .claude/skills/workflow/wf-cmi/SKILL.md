---
name: wf-cmi
version: 3.0.0-alpha
last_updated: 2026-05-16
description: >
  Cross-Module Integrity Orchestrator v3.0-alpha — 10-phase pipeline: Init → Discovery → Invariant Artifact → Coverage Dispatch (27 lanes, 3-WAVE PARALLEL — v3 thêm CD41 E2E Scenario Synthesizer ở Wave 3) → Aggregate → Regression Map → GAP + CDG → Report → [Phase 9 E2E Execute & Verify — opt-in] → [Phase 10 E2E Resolution — auto-run nếu Phase 9 có FAIL].
  v2.0 (26 lanes Gói C++ Logistics) giữ 100% backward-compat. v3.0 ADD-ONLY: lane CD41 (synth test-scenario.md từ workflow-graph + business-invariants) + Phase 9 (Playwright execute scenarios + lint + 5x flakiness + screenshot evidence) + Phase 10 (failure analyzer 7-type + 2-phase auto-fix + loop-back gap-suggestions kind="e2e_scenario_fix").
  Producer sidecar `business-invariants.json` (Engine #4 — KHÔNG bump registry) và cross-skill `integrity-impact.json` schema v3 (consumer phải read được v1+v2+v3) cho wf-verify-sync/wf-fix-bugs/wf-implement-feature/wf-prepare-deployment.
  BREAKING v1→v2: `--profile=deep` từ 10→26 lanes (~60→90 min). v2→v3 KHÔNG breaking — Phase 9-10 opt-in qua `--exec-scenarios`. Default behavior y hệt v2.0.
  Target chính: EUREKA-2026 ERP logistics Việt-Trung (17 modules .NET 10 + Next.js 16 + PostgreSQL 16). Mobile scope v2: chỉ scan `erp-web` (mobile/customer apps defer v2.1).

  TRIGGER: User gọi `/wf-cmi`, hoặc nhắc tới: cross-module integrity, business consistency, coverage matrix, business invariants, regression scope, system-wide integrity check, Gói C++ Logistics integrity, e2e scenario synth, runtime verify scenarios.

  KHÔNG trigger: /wf-fix-bugs (single-feature bug hunt), /wf-verify-sync (req-to-code), /wf-preflight (health snapshot), refactor lớn.

argument-hint: "[--scope=system|module=<id>|feat=<id>] [--profile=quick|standard|deep|exhaustive] [--dims=CD1,CD3,CD5,CD41] [--since=<git-ref>] [--from-fix-bugs] [--from-verify-sync] [--from-impl] [--auto-suggest] [--dry-run] [--ci] [--resume] [--status] [--session-id=<ID>] [--no-cache] [--show-graphs] [--exec-scenarios] [--scenarios-only] [--show-browser] [--mobile] [--strict-evidence] [--no-prompt] [--auto-fix-source]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, AskUserQuestion, Agent, mcp__serena__check_onboarding_performed, ListMcpResourcesTool, ReadMcpResourceTool, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_type, mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_select_option, mcp__plugin_playwright_playwright__browser_wait_for, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_console_messages, mcp__plugin_playwright_playwright__browser_network_requests, mcp__plugin_playwright_playwright__browser_close, mcp__plugin_playwright_playwright__browser_resize
---
# /wf-cmi: $ARGUMENTS

## Overview

| Mục | Nội dung |
| --- | -------- |
| **Mục đích** | Đảm bảo toàn vẹn liên module — build 6 graphs (entity/module/workflow/API/event/RBAC), suy luận business invariants, đo coverage **26 chiều Gói C++ Logistics** (v2.0: CD1-CD7, CD9, CD11-CD18, CD23-CD26, CD28-CD31, CD37-CD40), phát hiện GAP, đề xuất artifact bổ sung qua CDG |
| **Prerequisites** | `req-registry.json` non-empty, `phase3-architecture/*.md` tồn tại (≥Phase 3 Design done), code scannable. Một số lanes cần SSOT files tại `.mc-data/docs/_meta/` (CD28→mdm-canonical-entities, CD37→compliance-mapping, CD38→ui-interactivity-spec, CD39→error-code-catalog, CD40→print-export-templates) |
| **Input** | Registry + phase1-business/ + phase2-features/ + phase3-architecture/ + code + CI index (GitNexus/Serena) + 9 SSOT files (optional) + cross-skill artifacts |
| **Output** | `integrity-report.md` (tiếng Việt ≤50 dòng v2) + `coverage-matrix.json` (schema v2, 35 dims) + `business-invariants.json` (sidecar) + `regression-map.json` + `integrity-impact.json` (cross-skill, schema `integrity-impact-v2`, backward-compat consumer read v1+v2) |
| **Phases** | `1 → 2 → 3 → 4 (3-wave) → 5 → 6 → 7 → 8 → [9 → 10]` (Phase 9-10 opt-in qua `--exec-scenarios`) |
| **Duration** | Multi-session (resume qua `--resume`); v2 estimates: quick 5-10min / standard 15-30min / **deep 55-90min** (26 lanes) / exhaustive 120-180min (35 lanes). v3 thêm: Phase 9 ~30s-2min/scenario × N (10-40 min cho 20 scenarios), Phase 10 ~1-5 min/issue |
| **Migration v1→v2** | BREAKING: `--profile=deep` từ 10→26 lanes. Schema bumps integrity-status/coverage-matrix/integrity-impact v1→v2. Resume v1 session với v2 → E110 WARN. Xem `_contract.json.migration_notes` |
| **Migration v2→v3** | KHÔNG breaking. Phase 9-10 opt-in qua `--exec-scenarios`. integrity-impact bump v2→v3 (consumer phải read v1+v2+v3 — 2 field mới `e2e_execution_summary` + `scenarios_artifacts` = null/[] nếu `--exec-scenarios` không bật) |

### Lane Catalog Summary (v3.0)

> **Canonical:** `_contract.json §lanes_defined[]` (40 entries với owner_agents/wave/effort_days/profile_activation). Chi tiết breakdown + agent mapping: [`docs/04-skill-design/wf-cmi/01-vision-scope.md §Lane Catalog`](../../../../docs/04-skill-design/wf-cmi/01-vision-scope.md).

| Status | Count | Lanes | Profile |
| ------ | ----- | ----- | ------- |
| **Active v2.0** | 26 | CD1-CD7, CD9, CD11, CD13, CD15-CD18, CD23-CD26, CD28-CD31, CD37-CD40 | quick(7) / standard(13) / deep(26) / exhaustive(26+LLM) |
| **NEW v3.0** | 1 | **CD41 E2E Scenario Synthesizer** (W3, qa-lead + ux-researcher + business-analyst) | deep / exhaustive only |
| **SKIPPED v2** | 9 | CD8, CD10, CD12, CD14, CD19-22, CD27 | reactivate v2.1 hoặc exhaustive override |
| **Skeleton v3-deferred** | 5 | CD32-CD36 | W4 planned v3.x |

### Workflow Position

```
[Entry / sau Phase 3 Design] → /wf-cmi → /wf-verify-sync hoặc /wf-fix-bugs --from-cmi
                                  |
                            YOU ARE HERE
                                  |
                      8-Phase Pipeline (lazy-loaded procedures)
```

> **Relationship với existing skills:** xem [§Related Skills](#related-skills) bên dưới.

---

## Arguments

| Argument | Mô tả | Default |
| -------- | ----- | ------- |
| `--scope=<s>` | `system` / `module=<name>` / `feat=FEAT-<id>` | `system` |
| `--profile=<p>` | `quick` / `standard` / `deep` / `exhaustive` | `standard` |
| `--dims=<list>` | Subset lanes, vd `CD1,CD3,CD5` | (all active per profile) |
| `--since=<git-ref>` | Regression-aware mode — chỉ phân tích files đổi từ ref | — |
| `--from-fix-bugs` | Consume `fix-impact.json` từ wf-fix-bugs | — |
| `--from-verify-sync` | Consume `verify-sync-impact.json` | — |
| `--from-impl` | Consume `impl-status.json` từ wf-implement-feature | — |
| `--auto-suggest` | Phase 7 đề xuất artifact bổ sung qua CDG | — |
| `--dry-run` | Mô phỏng — KHÔNG ghi sidecar artifact, KHÔNG record CDG decisions | — |
| `--ci` | GitHub Action mode: read-only, post lên PR (mutually exclusive với `--auto-suggest`) | — |
| `--resume` | Resume session đang dở (đọc `integrity-status.json` → route next phase) | — |
| `--status` | In trạng thái session hiện tại → exit 0 | — |
| `--session-id=<ID>` | Manual session ID khi `--resume` ambiguous | (auto) |
| `--no-cache` | Bỏ qua scan cache + CI cache | — |
| `--show-graphs` | Phase 8 render Mermaid diagrams cho 6 graphs vào `integrity-report.md` | — |
| `--exec-scenarios` | **v3.0** Bật Phase 9 (Playwright execute scenarios CD41 sinh ra). BẮT BUỘC để runtime verify. | off |
| `--scenarios-only` | **v3.0** SKIP Phase 1-7, chỉ chạy Phase 9-10 trên session cũ. Yêu cầu `--session-id=<id>` | off |
| `--show-browser` | **v3.0** Phase 9 hiển thị browser (không headless) | headless |
| `--mobile` | **v3.0** Phase 9 viewport mobile 375x667 (iPhone SE) | desktop 1280x720 |
| `--strict-evidence` | **v3.0** Mọi step PHẢI có screenshot ≥1KB, thiếu → BLOCKED | off (≥80% scenarios) |
| `--no-prompt` | **v3.0** Bypass AskUserQuestion Phase 9 subset confirm (CI mode) | off |
| `--auto-fix-source` | **v3.0** Cho Phase 10 spawn agent sửa source code (CDG E195 confirm lần đầu) | off (chỉ browser-fix) |

> **Canonical input spec:** `_contract.json §inputs`. Chi tiết argument interactions + validation rules → [`docs/04-skill-design/wf-cmi/02-arguments.md`](../../../../docs/04-skill-design/wf-cmi/02-arguments.md).

---

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 9 (Task Planning), Protocol 10 (POST-GATE Schema),
> Protocol 16 (Critical Decision Gate), Protocol 19 (Template Usage Rule), Protocol 20 (Code Intelligence), Protocol 22 (Cross-session R/W lock).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Error Handling Canonical, CI Detection Pattern, R/W Lock Pattern, Agent Prompt Templates.

### Priority Ladder (BẮT BUỘC)

1. **Độ chính xác, tính nhất quán, tính đầy đủ, chất lượng kỹ thuật, bảo mật**
2. **Tốc độ xử lý và song song hóa** — CHỈ SAU KHI mục 1 được bảo vệ

- KHÔNG đánh đổi correctness, completeness, security để lấy tốc độ (CORE-023)
- Mọi output downstream PHẢI bám upstream docs + registry (CORE-024)
- Song song hóa CHỈ khi có owner rõ, write scope tách biệt, contract ổn định, re-verification (CORE-025)

### Template Usage Rule (CORE-031)

> **BẮT BUỘC:** Mọi file có Template PHẢI được tạo bằng pattern:
>
> 1. **READ** template file từ `templates/`
> 2. **POPULATE** — thay thế placeholders bằng giá trị thực tế, strip `_template_notes`/`_schema_notes`
> 3. **WRITE** output file đến destination path qua Atomic Write Pattern (`.tmp.$$` → validate → mv)
>
> **NẾU SKIP bước READ template → STOP skill.** Không viết output từ đầu khi template tồn tại.
>
> **Protocol:** `.claude/skills/protocols/19-template-usage.md`

### Execution Strategy

| Phase | Mode | Agent Count | Ghi chú |
| ----- | ---- | ----------- | ------- |
| 1 Init | SEQUENTIAL | 0 | Args → CI PRE-GATE → session init → lock + heartbeat + migration check (E110 v1→v2) |
| 2 Discovery | HYBRID | 0-6 | 6 graph builders chạy parallel theo loại resource (v2.0 vẫn 6 graphs core; v2.1 sẽ thêm 7 FE/BE graphs) |
| 3 Invariant Artifact | PARALLEL | 1-24 | Spawn domain experts theo `department` (max 10 concurrency CORE-025) |
| 4 Coverage Dispatch | **3-WAVE PARALLEL** | 7-26 | v2.0: Wave 1 (10 lanes graphs) → Wave 2 (10 cross-layer) → Wave 3 (6 final). Max 10 concurrent/wave. Per-wave gate check (≥3 fail → STOP E120-E122) |
| 5 Aggregate | SEQUENTIAL | 0 | Python helper aggregate signals → coverage matrix (35 dims = 26 active + 9 SKIPPED) |
| 6 Regression Map | SEQUENTIAL | 0 | GitNexus impact + git diff |
| 7 GAP + CDG | HYBRID | 0-3 | LLM suggestion gen + user CDG decisions |
| 8 Report | SEQUENTIAL | 0 | Cross-skill artifact write (**v3 schema** với E2E summary section nếu `--exec-scenarios`) + cleanup lock |
| **9 E2E Execute & Verify** (v3 opt-in) | SEQUENTIAL | 0 | Playwright runner — lint scenarios + 5x flakiness + execute each scenario steps + screenshot evidence (chỉ chạy khi `--exec-scenarios`) |
| **10 E2E Resolution** (v3 auto) | HYBRID | 0-3 | Failure analyzer 7-type + 2-phase auto-fix (browser → spawn agent source-fix nếu `--auto-fix-source`) + loop-back gap-suggestions kind=`e2e_scenario_fix` (chỉ chạy nếu Phase 9 có ≥1 FAIL) |

---

## CI PRE-GATE (Protocol 20 §20.8)

> CI tools auto-detect, không hỏi user. Lock held → fallback Grep/Glob.

| Step | Action | Verify |
| ---- | ------ | ------ |
| Na | **Load CI Capabilities:** `bash .claude/scripts/ci-detect.sh` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Graceful: lock held → fallback Grep/Glob. | CI flags set |
| Nb | **Index Freshness Check:** `bash .claude/scripts/ci-freshness-check.sh` → ok/light/strong/severe. Strong+ → WARN, fallback. | Freshness status set |
| Nc | **Agent Context Injection:** `bash .claude/scripts/ci-inject-context.sh` → `$CI_CONTEXT` for spawned agents. | CI context ready |

### CI-ROUTE: Orchestrator Stages

| Stage | CI Task | Primary Tool | Fallback |
| ----- | ------- | ------------ | -------- |
| Discovery | `entity_graph` | **GitNexus** `clusters` + **Serena** `find_symbol` | Glob `**/Domain/Entities/*.cs` |
| Discovery | `module_graph` | **GitNexus** `query({key_concept})` | Grep `using.*Modules` |
| Discovery | `api_graph` | **GitNexus** `route_map` | Grep `MapPost\|MapGet\|MapPut` |
| Discovery | `event_graph` | **GitNexus** `cypher` + **Serena** `find_refs` | Grep `IntegrationEvent\|DomainEvent` |
| Regression | `impact_analysis` | **GitNexus** `impact({changed_files})` | `git diff --name-only` |
| Regression | `change_detection` | **GitNexus** `detect_changes()` | `git diff --stat` |

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load qua các phase files riêng.
> Nguyên tắc bắt buộc: Read MỖI phase file CHỈ KHI tới phase tương ứng.

| # | Phase | Procedure File | Điều kiện | Mode |
| - | ----- | -------------- | --------- | ---- |
| **1** | Init + CI PRE-GATE | `procedures/phase1-init.md` | Always (entry) | SEQUENTIAL |
| **2** | Discovery (6 graphs) | `procedures/phase2-discovery.md` | Phase 1 POST-GATE pass | HYBRID |
| **3** | Invariant Artifact | `procedures/phase3-invariant-artifact.md` | Phase 2 POST-GATE pass | PARALLEL (max 10) |
| **4** | Coverage Dispatch (3-wave) | `procedures/phase4-coverage-dispatch.md` | Phase 3 POST-GATE pass | 3-WAVE PARALLEL (max 10/wave) |
| **5** | Aggregate | `procedures/phase5-aggregate.md` | Phase 4 POST-GATE pass | SEQUENTIAL |
| **6** | Regression Map | `procedures/phase6-regression.md` | Phase 5 POST-GATE pass (skip nếu `--profile=quick`) | SEQUENTIAL |
| **7** | GAP + CDG | `procedures/phase7-gap-cdg.md` | Phase 6 POST-GATE pass | HYBRID |
| **8** | Report | `procedures/phase8-report.md` | Phase 7 POST-GATE pass | SEQUENTIAL |
| **9** | E2E Execute & Verify (v3 opt-in) | `procedures/phase9-e2e-execute.md` | Phase 8 POST-GATE pass AND `--exec-scenarios` ON AND ≥1 scenario CD41 sinh ra AND Playwright MCP available | SEQUENTIAL |
| **10** | E2E Resolution (v3 auto) | `procedures/phase10-e2e-resolution.md` | Phase 9 POST-GATE pass AND ≥1 FAIL entry trong `e2e-results.json` | HYBRID |
| **—** | Resume/Status | `procedures/resume-status.md` | `--status` or `--resume` (cũng handle `--scenarios-only`) | Dispatch |

### Routing Flow

```
SKILL.md entry → Parse arguments + validate (E010-E016)
  ├── --status → Read procedures/resume-status.md §--status → STOP
  ├── --resume → Read procedures/resume-status.md §--resume → route to last checkpoint
  └── Fresh run → Read procedures/phase1-init.md → execute → return
       ↓
Read procedures/phase2-discovery.md → 6 graphs built → return
       ↓
Read procedures/phase3-invariant-artifact.md → 3-pass LLM infer → sidecar candidate → return
       ↓
Read procedures/phase4-coverage-dispatch.md → 26 lanes 3-WAVE PARALLEL (W1=10, W2=10, W3=6) → collect signals → return
       ↓
Read procedures/phase5-aggregate.md → coverage matrix + report → return
       ↓ (IF coverage < threshold → CDG E090 escalate)
Read procedures/phase6-regression.md → predicted impact + test plan → return
       ↓
Read procedures/phase7-gap-cdg.md → GAP detect + auto-suggest (nếu flag) + CDG decisions → return
       ↓
Read procedures/phase8-report.md → integrity-report + integrity-impact.json (cross-skill) → DONE
       ↓ (IF --exec-scenarios AND CD41 sinh ≥1 scenario AND Playwright available)
Read procedures/phase9-e2e-execute.md → lint + 5x flakiness + execute scenarios + screenshots → e2e-execution-report.md + e2e-results.json → return
       ↓ (IF ≥1 FAIL trong e2e-results.json)
Read procedures/phase10-e2e-resolution.md → failure analyzer 7-type + 2-phase auto-fix + loop-back gap-suggestions → resolution-report.md → return → re-run Phase 8 §Report Update v3 schema (E2E summary section)
       ↓
→ /wf-verify-sync --from-cmi  hoặc  /wf-fix-bugs --from-cmi  hoặc  /status
```

---

## Phase Summary (condensed — chi tiết trong procedure files)

> **Lazy-load:** Mỗi phase có procedure file riêng. SKILL.md chỉ giữ summary để routing nhanh. Chi tiết PRE/POST gates, error codes, agent prompts trong procedure files. Input/Output paths xem [§Output Files](#output-files) + `_contract.json §outputs.working[]`.

### Phase 1 — Init + CI PRE-GATE
SEQUENTIAL · 12-15 steps · CDG E090b/E091 · [`phase1-init.md`](procedures/phase1-init.md). Parse args + validate, CI PRE-GATE Na/Nb/Nc, PRE-GATE T1-T4, session init + R/W lock, profile→dims, init templates, POST-GATE T1-T4.

### Phase 2 — Discovery (6 graphs)
HYBRID · 10-12 steps · [`phase2-discovery.md`](procedures/phase2-discovery.md). PRE-GATE Phase 1, CI-ROUTE scan code paths, build 6 graphs PARALLEL (entity/module/workflow/API/event/RBAC), schema + cross-ref validation check, POST-GATE.

### Phase 3 — Invariant Artifact
PARALLEL (max 10) · 14-16 steps · CDG E036/E091 · [`phase3-invariant-artifact.md`](procedures/phase3-invariant-artifact.md). PRE-GATE Phase 2, spawn domain experts (24 max, route 10/batch), 3-pass LLM infer (pattern → heuristic → registry gap), conflict detection, sidecar draft, POST-GATE.

### Phase 4 — Coverage Dispatch (3-WAVE, 26 lanes Gói C++ Logistics)
3-WAVE PARALLEL (max 10/wave) · 15-18 steps · E040-E049 + E120-E122 wave errors · [`phase4-coverage-dispatch.md`](procedures/phase4-coverage-dispatch.md). PRE-GATE Phase 3, lane subdirs `CD{N}-{name}/`, render CORE-037 prompts. **Wave 1** (10 lanes graphs): CD1-CD7, CD11, CD16, CD17. **Wave 2** (10 cross-layer): CD13, CD15, CD18, CD23-CD25, CD28, CD30, CD31, CD37. **Wave 3** (6 final): CD9, CD26, CD29, CD38-CD40. Per-wave gate check (≥3 fail/timeout → STOP wave + E120-E122 ESCALATE). Monitor 30s polling (E041 timeout 3 min/lane), collect + validate per-lane T1-T4, POST-GATE. CD32-CD36 skeleton v3-deferred → SKIP với E149 WARN.

### Phase 5 — Aggregate (35 dims: 26 active + 9 SKIPPED markers)
SEQUENTIAL · 8-10 steps · CDG E090 threshold · [`phase5-aggregate.md`](procedures/phase5-aggregate.md). PRE-GATE Phase 4, count signals, aggregate + dedup, severity classification, build coverage matrix v2 (35 dim entries — 26 active dispatched + 9 SKIPPED CD8/CD10/CD12/CD14/CD19-22/CD27 với coverage_pct=null), threshold check per profile (quick≥60% / standard≥80% / **deep≥95%** / exhaustive=100%), POST-GATE T1-T4. CD32-CD36 KHÔNG present trong matrix v2.

### Phase 6 — Regression Map
SEQUENTIAL · 8-10 steps · E062 WARN · [`phase6-regression.md`](procedures/phase6-regression.md). PRE-GATE Phase 5 + `--since` valid, CI-ROUTE impact (GitNexus primary, git fallback), predictive scoring per module, test plan generation, POST-GATE T1-T4.

### Phase 7 — GAP + CDG
HYBRID · 10-12 steps · CDG E094/E095 · [`phase7-gap-cdg.md`](procedures/phase7-gap-cdg.md). PRE-GATE Phase 5+6, GAP detection per dim, `--auto-suggest` generate artifacts, CDG batch ACCEPT/REJECT/DEFER, sync accepted invariants → canonical sidecar APPEND, POST-GATE.

### Phase 8 — Report
SEQUENTIAL · 10-12 steps · [`phase8-report.md`](procedures/phase8-report.md). PRE-GATE all phases PASS, build `integrity-report.md` ≤30 dòng tiếng Việt (v3: thêm section E2E Execution Summary conditional `--exec-scenarios`), build `integrity-impact.json` (v3 schema, audit_chain), validate cross-skill paths, `--show-graphs` render Mermaid, release lock, POST-GATE T1-T4.

### Phase 9 — E2E Execute & Verify (v3 opt-in)
SEQUENTIAL · 11 steps (9.1-9.11) · E150-E179 · [`phase9-e2e-execute.md`](procedures/phase9-e2e-execute.md). PRE-GATE T1-T4 (scenarios-manifest exists / Playwright MCP available / FE running / browser-mcp.lock acquirable). Steps: lint scenarios (BLOCK fail) → 5x flakiness pre-flight (auto-quarantine ≤3/5) → login → FOR each scenario: navigate → execute steps (Click/Fill/Select/Wait/Navigate pattern) → snapshot verify → screenshot evidence → fill Pass/Fail vào test-scenario-CMI-{NN}.md → cross-module navigate xuyên modules theo workflow-graph → release lock → write `e2e-execution-report.md` + `e2e-results.json`. Auto-fix budget 3 retries/scenario (browser only, source defer Phase 10). POST-GATE T1-T4.

### Phase 10 — E2E Resolution (v3 auto)
HYBRID · 6 steps (10.1-10.6) · E180-E199 + CDG E195 · [`phase10-e2e-resolution.md`](procedures/phase10-e2e-resolution.md). PRE-GATE T1-T3 (e2e-results.json có ≥1 FAIL / failure-analyzer loadable / agents available). FOR each FAIL: collect evidence (console/network/DOM) → classify 7-type (NETWORK/AUTH/DATA_MISSING/SELECTOR/UI_BUG/BUSINESS_RULE/UNKNOWN) → determine layer+owner → 2-phase auto-fix (Phase A browser: retry/re-login/selector fallback / Phase B spawn agent source-fix nếu `--auto-fix-source` + CDG E195 confirm) → loop-back APPEND `gap-suggestions.json` kind=`e2e_scenario_fix` (KHÔNG re-trigger CD41 — avoid infinite loop) → write `resolution-report.md`. POST-GATE T1-T4.

---

## PRE-GATE / POST-GATE File Contract

> **Protocol:** CORE-012 (POST-GATE T1-T4: exists → structure → content depth → cross-reference).
> Phase 1 có thêm CI PRE-GATE (Protocol 20) chạy trước PRE-GATE validation.

| # | Transition | PRE-GATE (files must exist) | POST-GATE (T1-T4 validate) | Error |
| - | ---------- | --------------------------- | -------------------------- | ----- |
| **1→2** | Init → Discovery | `integrity-status.json`, `Phase1-report.md`, session dir + lock active | T1-T4: integrity-status.json structure valid, session-log writable, CI context set | E010-E019 |
| **2→3** | Discovery → Invariant | 6 graph files non-empty (`entity/module/workflow/api/event/rbac`), `Phase2-report.md` | T1-T4: 6 graphs schema valid + ≥1 node each + cross-graph refs consistent | E020-E029 |
| **3→4** | Invariant → Coverage | `business-invariants.json` (per-session draft), `Phase3-report.md` | T1-T4: sidecar candidate schema `business-invariants-v1` valid, ≥1 invariant per active domain, source_doc refs resolve | E030-E039 |
| **4→5** | Coverage → Aggregate | ≥1 lane `signals.json` per active dim (7-26 lanes tùy profile), `wave-status.json` per-wave update, all lane reports | T1-T4: signals schema `signals-v1` valid, per-wave counts match, no fingerprint collision, ≥3 fail/wave → E120-E122 | E040-E049, E120-E123 |
| **5→6** | Aggregate → Regression | `coverage-matrix.json` (schema v2, 35 dims), `coverage-report.md` (≤15 dòng), `Phase5-report.md` | T1-T4: matrix có đủ 35 dim entries (26 active + 9 SKIPPED), coverage_pct ∈ [0,100] hoặc null, threshold check per profile | E050-E059 |
| **6→7** | Regression → GAP | `regression-map.json` (hoặc SKIPPED nếu `quick`), `Phase6-report.md` | T1-T4: predictions có confidence ∈ [0,1], scanned_files khớp `--since` scope | E060-E069 |
| **7→8** | GAP → Report | `gap-report.md`, `gap-suggestions.json`, CDG decisions log đầy đủ | T1-T4: accepted suggestions có actionable target, sidecar APPEND success | E070-E079 |
| **8→DONE/9** | Report → (Phase 9 nếu `--exec-scenarios` AND CD41 sinh ≥1 scenario) | `integrity-report.md`, `integrity-impact.json` (schema v3), `Phase8-report.md` | T1-T4: artifact schema `integrity-impact-v3` valid + audit_chain checksum verify + paths khớp `_contract.json.produces_for{}` | E080-E089 |
| **8→9** | Report → E2E Execute (v3 opt-in) | `scenarios-manifest.json` từ CD41, Playwright MCP available, FE running, `browser-mcp.lock` acquirable | T1-T4: `e2e-execution-report.md`, `e2e-results.json`, `screenshots/` ≥1, all scenarios processed (PASS/FAIL/AUTO_CORRECTED/QUARANTINED) | E150-E179 |
| **9→10** | E2E Execute → Resolution (skip nếu 0 FAIL) | `e2e-results.json` có ≥1 FAIL entry | T1-T4: `resolution-report.md`, `gap-suggestions.json` APPEND `e2e_scenario_fix`, spawned agents logs | E180-E199 |
| **10→DONE** | Resolution → Complete | Phase 10 outputs + loop-back applied + Phase 8 re-write integrity-report v3 với E2E section | T1-T4: `integrity-impact.json` v3 có `e2e_execution_summary` + `scenarios_artifacts[]` non-null | E080-E089 |

### Gate Flow Diagram

```
Phase 1 Init ──[POST-GATE]──→ Phase 2 Discovery ──[POST-GATE]──→ Phase 3 Invariant ──[POST-GATE]──→
Phase 4 Coverage Dispatch ──[POST-GATE]──→ Phase 5 Aggregate ──[POST-GATE + threshold check]──→
Phase 6 Regression Map (skip nếu quick) ──→ Phase 7 GAP + CDG ──[POST-GATE + sidecar APPEND]──→
Phase 8 Report ──[POST-GATE + audit_chain]──→ DONE  (OR ↓ if --exec-scenarios)
       ↓
Phase 9 E2E Execute (v3) ──[POST-GATE + screenshots]──→ DONE  (OR ↓ if ≥1 FAIL)
       ↓
Phase 10 E2E Resolution (v3) ──[POST-GATE + loop-back gap-suggestions]──→ Phase 8 re-write v3 E2E section ──→ DONE
```

### Gate File Traceability

> Mỗi PRE-GATE T1 check đảm bảo output phase trước đã được tạo.
> Mỗi POST-GATE T1-T4 đảm bảo output phase hiện tại đạt chuẩn trước khi sang phase sau.
> Nếu POST-GATE fail → retry x1 verbose → vẫn fail → E001 escalate via AskUserQuestion.
> Nếu PRE-GATE fail → DỪNG, ghi error code tương ứng vào `error-ledger.json`.

---

## Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
| ---------- | ----------------- | ----------- |
| Template missing | Re-locate templates path, đọc lại từ git history | Không có history |
| POST-GATE T1-T4 fail | Retry phase x1 verbose (per-phase budget max 3) | Vẫn fail → E001 |
| Lane agent output invalid | Re-spawn x1 nhấn mạnh schema | Vẫn invalid → E040 |
| LLM timeout (Phase 3) | Retry x1 với scope thu hẹp | Domain expert thực sự không reachable |
| Cross-domain conflict (Phase 3) | CDG E091 dual-approval | User DEFER → log, không enforce |
| Coverage below threshold (Phase 5) | CDG E090 (accept gap / generate artifacts / cancel) | User cancel → exit FAIL |
| GitNexus impact unavailable (Phase 6) | Fallback git diff (downgrade predictive → diff-aware) | git cũng fail → E062 WARN |
| Context overflow | FORCE checkpoint, STOP (E009) | — |

---

## Error Handling

> **Canonical table:** Xem `procedures/_shared.md §Error Handling Canonical`. Bảng dưới là quick lookup.
> Đầy đủ E001-E109 detail + auto-fix strategy → [`docs/04-skill-design/wf-cmi/05-error-codes.md`](../../../../docs/04-skill-design/wf-cmi/05-error-codes.md).

### Namespace Convention

```
E001-E009   → Pipeline/session/lock (shared)
E010-E019   → Phase 1 Init (args, CI PRE-GATE, registry, lock)
E020-E029   → Phase 2 Discovery (6 graph builds)
E030-E039   → Phase 3 Invariant (LLM, domain expert, schema)
E040-E049   → Phase 4 Coverage Dispatch (lane spawn, signals)
E050-E059   → Phase 5 Aggregate (compute, matrix, threshold)
E060-E069   → Phase 6 Regression (impact, predict, test plan)
E070-E079   → Phase 7 GAP + CDG (suggestion, decision log)
E080-E089   → Phase 8 Report (artifact write, audit chain)
E090-E099   → CDG User-Facing Gates (coverage, conflict, compliance)
E100-E109   → Warnings (CI degrade, stale cache, low confidence)
E110-E112   → v2.0 Migration (E110 v1 session resume / E111 skeleton dim / E112 SKIPPED override)
E120-E123   → Phase 4 Wave gate (E120-E122 per-wave ≥3 fail STOP / E123 1-2 fail WARN)
E130-E135   → v2 lane-specific (CD11-CD18 FE/BE graph deps fail)
E140-E148   → v2 lane SSOT deps (CD28/CD30/CD31/CD37 logistics critical, CD38-CD40 ★ implementations)
E149        → v3.0 prep (CD32-CD36 skeleton WARN)
E150-E159   → v3 Phase 9 PRE-GATE / setup (Playwright unavailable, FE down, lock conflict, manifest invalid)
E160-E169   → v3 Phase 9 Execute (step fail, snapshot fail, timeout, navigate fail)
E170-E179   → v3 Phase 9 Stability (lint fail, flakiness check, quarantine, stable-registry)
E180-E189   → v3 Phase 10 Analysis (classify UNKNOWN, evidence partial)
E190-E199   → v3 Phase 10 Auto-fix (spawn agent fail, HMR timeout, post-fix verify fail)
E195        → v3 Phase 10 CDG user-facing (require `--auto-fix-source` confirm)
```

### Quick Lookup

> Bảng đầy đủ 30+ codes (E001-E199) extract sang [`procedures/_error-quick-lookup.md`](procedures/_error-quick-lookup.md) (CORE-038 context budget). Auto-fix strategy chi tiết: [`docs/04-skill-design/wf-cmi/05-error-codes.md`](../../../../docs/04-skill-design/wf-cmi/05-error-codes.md).

| Code group | Severity | Tóm tắt |
| ---------- | -------- | ------- |
| E001-E009 | critical | Pipeline/session/lock — POST-GATE fail, context budget, stale lock |
| E010-E019 | critical-high | Phase 1 Init — registry/architecture missing, args invalid, lock acquire fail |
| E020-E089 | medium-high | Phase 2-8 — graph build, invariant, lane spawn, aggregate, regression, GAP, report |
| E090-E099 | info | CDG user-facing gates — coverage breach, cross-domain conflict, dual-approval |
| E100-E109 | low | Warnings — CI degrade, stale cache, low confidence (LOG, continue) |
| E110-E148 | medium-high | v2.0 specifics — migration, wave gate, lane FE/BE deps, SSOT logistics critical |
| E149 | low | v3.0 prep — CD32-CD36 skeleton deferred |
| E150-E179 | info-high | v3 Phase 9 — Playwright unavailable, lint fail, flakiness, lock conflict, step execute |
| E180-E199 | medium-high | v3 Phase 10 — classify, spawn agent, HMR, post-fix verify |
| E195/E195b | info | v3 CDG user-facing — Phase 10 source-fix confirm / Phase 1 subset E2E execute confirm |

---

## Context & Checkpoint

| Context Usage | Hành động |
| ------------- | --------- |
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint (lưu state files) |
| 80-90% | Lưu checkpoint ngay, STOP sau phase hiện tại → hướng dẫn `--resume` |
| > 90% | FORCE STOP — checkpoint bắt buộc (E009) |

> Resume process chi tiết → `procedures/resume-status.md`. Stale lock auto-release sau 30 min (Protocol 22).

---

## Output Files

### Session-scoped outputs (tại `sessions/{SESSION_ID}/`)

> **Canonical:** `_contract.json §outputs.working[]` (32 file paths + templates). Bảng dưới là grouped summary.

| Group | Phase | Files | Templates |
| ----- | ----- | ----- | --------- |
| **SSOT state** | All | `integrity-status.json` (schema v2), `session-log.json`, `error-ledger.json`, `.lock` | `integrity-status.json` + `_common/session-log.json` + `_common/error-ledger.json` |
| **Phase 1 Init** | 1 | `phase1-init/Phase1-report.md` | `Phase1-report.md` |
| **Phase 2 Discovery (6 graphs)** | 2 | `phase2-discovery/{entity,module,workflow,api,event}-graph.json` + `rbac-matrix.json` + `Phase2-report.md` | `entity-graph.json`, `module-graph.json`, `workflow-graph.json`, `api-graph.json`, `event-graph.json`, `rbac-matrix.json`, `Phase2-report.md` |
| **Phase 3 Invariants** | 3 | `phase3-invariants/business-invariants.json` (draft) + `invariants-diff.json` + `Phase3-report.md` | `business-invariants.json` + `Phase3-report.md` |
| **Phase 4 Coverage (per-lane × N)** | 4 | `phase4-coverage/lanes/CD{N}-{name}/{signals.json, lane-status.json, CD{N}-{name}-report.md}` × 7-26 lanes + `Phase4-report.md` + `wave-status.json` (NEW v2) + `probe-failures.log` | `signals.json` + `lane-status.json` + `CD-report.md` + `Phase4-report.md` |
| **Phase 5 Aggregate** | 5 | `phase5-aggregate/coverage-matrix.json` (schema v2, 35 dims) + `coverage-report.md` + `signals-aggregated.jsonl` + `Phase5-report.md` | `coverage-matrix.json` + `coverage-report.md` + `Phase5-report.md` |
| **Phase 6 Regression** | 6 | `phase6-regression/regression-map.json` + `regression-report.md` + `Phase6-report.md` | `regression-map.json` + `regression-report.md` + `Phase6-report.md` |
| **Phase 7 GAP + CDG** | 7 | `phase7-gap-cdg/{gap-report.md, gap-suggestions.json, cdg-decisions.jsonl, Phase7-report.md}` | `gap-report.md` + `gap-suggestions.json` + `Phase7-report.md` |
| **Phase 8 Report** | 8 | `phase8-report/integrity-report.md` (≤55 dòng v3) + `integrity-impact.json` (schema v3, cross-skill) + `Phase8-report.md` | `integrity-report.md` + `integrity-impact.json` + `Phase8-report.md` |
| **Phase 9 E2E Execute (v3 opt-in)** | 9 | `phase9-e2e-execute/{e2e-execution-report.md, e2e-results.json, screenshots/, lint-report.json, lint-fixes.md, stable-registry.json, quarantine-report.json, Phase9-report.md}` | `e2e-execution-report.md` + `e2e-results.json` + `lint-report.json` + `lint-fixes.md` + `stable-registry.json` + `quarantine-report.json` + `Phase9-report.md` |
| **Phase 10 E2E Resolution (v3 auto)** | 10 | `phase10-e2e-resolution/{resolution-report.md, Phase10-report.md}` + UPDATE `phase7-gap-cdg/gap-suggestions.json` (APPEND `e2e_scenario_fix`) | `resolution-report.md` + `Phase10-report.md` |
| **CD41 scenarios (v3 NEW)** | 4 (Wave 3) | `phase4-coverage/lanes/CD41-e2e-synth/{scenarios/test-scenario-CMI-{NN}-{slug}.md × N, scenarios-manifest.json, signals.json, lane-status.json, CD41-e2e-synth-report.md}` | `test-scenario.template.md` + `scenarios-manifest.json` + `signals.json` + `lane-status.json` + `CD-report.md` |

### Canonical sidecar artifact (project-scoped — APPEND-only)

| # | File | Source phase | Update mode | Schema |
| - | ---- | ------------ | ----------- | ------ |
| 32 | `.mc-data/work/wf-cmi/business-invariants.json` | Phase 7 (sync sau CDG ACCEPT) | APPEND-only | `business-invariants-v1` |

### Index & Lock

| File | Path |
| ---- | ---- |
| Sessions index | `.mc-data/work/wf-cmi/_index/sessions.jsonl` (APPEND-only JSONL) |
| Session lock | `.mc-data/work/wf-cmi/sessions/{SESSION_ID}/.lock` + heartbeat daemon |
| Cross-session R/W lock | `.mc-data/work/wf-cmi/_locks/business-invariants.rwlock` (Protocol 22) |

> **CORE-031:** Mọi output path và template PHẢI khớp với `_contract.json §outputs.working[]`.
> Trước khi thêm/sửa output → cập nhật `_contract.json` trước, rồi mới code.

---

## Cross-Skill Contract (summary)

> **Canonical:** `_contract.json §cross_skill_contracts`. Bảng dưới là quick reference.
> Chi tiết schema + flag interactions → [`docs/04-skill-design/wf-cmi/04-file-contract.md`](../../../../docs/04-skill-design/wf-cmi/04-file-contract.md) §3.

### Produces for (downstream consumers)

| Consumer skill | Artifact | Schema | Flag |
| -------------- | -------- | ------ | ---- |
| `/wf-verify-sync` | `integrity-impact.json` | `integrity-impact-v3` | `--from-cmi` |
| `/wf-fix-bugs` | `integrity-impact.json` (seed Phase 1) | `integrity-impact-v3` | `--from-cmi` |
| `/wf-implement-feature` | `integrity-impact.json` (warn nếu touch invariant đang violate) | `integrity-impact-v3` | `--from-cmi` |
| `/wf-prepare-deployment` | `integrity-impact.json` (block release nếu coverage < deep threshold) | `integrity-impact-v3` | `--from-cmi` |
| `/wf-design` (NEW projects) | `business-invariants.json` (read-only) | `business-invariants-v1` | implicit |
| `/wf-add-scope` | `business-invariants.json` (validate module/feature mới) | `business-invariants-v1` | implicit |

### Consumes from (upstream producers)

| Producer skill | Artifact | Required |
| -------------- | -------- | -------- |
| `/wf-brainstorm` | `req-registry.json` | BẮT BUỘC (READ-ONLY) |
| `/wf-analyze-requirements` | `phase1-business/*.md` + `dept-digests.json` | BẮT BUỘC |
| `/wf-define-features` | `phase2-features/[sys]/[mod]/[feat].md` | BẮT BUỘC |
| `/wf-design` | `phase3-architecture/*.md` + `design-input-digest.json` | BẮT BUỘC |
| `/wf-implement-feature` | `impl-status.json` per FEAT | OPTIONAL (`--from-impl`) |
| `/wf-fix-bugs` | `fix-impact.json` | OPTIONAL (`--from-fix-bugs`) |
| `/wf-verify-sync` | `verify-sync-impact.json` | OPTIONAL (`--from-verify-sync`) |
| `/wf-e2e-finding` | `cross-module-gaps.md` per FEAT | OPTIONAL |

> **Registry write-role: `NONE`.** wf-cmi KHÔNG touch `req-registry.json` (ADR-cmi-002 Revised — sidecar artifact pattern). **Safe-Write Protocol: skill CHỈ READ registry, không update bất kỳ fields nào — không có fields được phép write.**

---

## Next Step

Sau khi pipeline hoàn thành (next: /wf-verify-sync hoặc /wf-fix-bugs với cờ `--from-cmi`):

```
→ /wf-verify-sync --from-cmi   (đồng bộ requirement-to-code với invariants mới)
→ /wf-fix-bugs --from-cmi      (seed bug hunt với MUST violations)
→ /wf-prepare-deployment       (block release nếu coverage < threshold)
→ /status                      (xem tổng quan dự án)
```

---

## Related Skills

| Skill | Quan hệ |
| ----- | ------- |
| `/wf-fix-integration` | Subset trong wf-fix-bugs lane QD10 — wf-cmi mở rộng thành system-wide |
| `/wf-fix-business-completeness` | Pattern 3-pass LLM inference được wf-cmi kế thừa |
| `/wf-e2e-finding` | Per-feature gap finding — bổ trợ chứ không thay thế |
| `/wf-verify-sync` | Downstream — `--from-cmi` re-verify req-to-code với invariants mới |
| `/wf-fix-bugs` | Downstream — `--from-cmi` seed Phase 1 với MUST violations |
| `/wf-implement-feature` | Downstream — `--from-cmi` warn khi touch invariant đang violate |
| `/wf-prepare-deployment` | Downstream — `--from-cmi` block release nếu coverage < deep threshold |
| `/wf-design` | Downstream (NEW projects) — read `business-invariants.json` để design module mới không vi phạm invariant cũ |
| `/wf-preflight` | Alternative khi cần health snapshot nhanh (không deep coverage) |

---

## References

| Group | Files |
| ----- | ----- |
| **Procedures (14 v3)** | `procedures/_shared.md` (cross-cutting + v3 Browser Lock + Playwright Retry) + `phase{1..8}-*.md` (per-phase lazy-load) + `phase9-e2e-execute.md` + `phase10-e2e-resolution.md` + `_e2e-runner.md` + `_failure-analyzer.md` + `_screenshot-evidence.md` + `lanes/CD{N}.md` (including `lanes/CD41.md`) + `resume-status.md` |
| **Templates (28)** | `integrity-status.json`, 6 graph JSONs (entity/module/workflow/api/event/rbac), `business-invariants.json`, per-lane (`signals.json`, `lane-status.json`, `CD-report.md`), `coverage-matrix.json`, `coverage-report.md`, `regression-map.json`, `gap-suggestions.json`, `integrity-report.md`, `integrity-impact.json`, `Phase{1..8}-report.md`, `_common/{session-log,error-ledger}.json` |
| **Structured** | `_contract.json` (v2.0, 526 dòng — inputs/outputs/lanes_defined×40/profile_activation/errors E001-E149/cross-skill contracts) · `evals/evals.json` (5+8 test cases v2) |
| **Design canon** | [`docs/04-skill-design/wf-cmi/`](../../../../docs/04-skill-design/wf-cmi/) — 14 files (vision, args, phase routing, file contract, error codes, templates list, procedures structure, ADRs, scenarios, evals, agent-prompt) |
| **v2.0 Migration** | `plans/wf-cmi/prompt-update.md` (session re-entry) · `progress-update.md` (9 stages tracking) · `ui-interactivity-spec.eureka-template.json` (CD38 SSOT template) |
| **Protocols** | `.claude/skills/protocols/` — 09 (Task Planning), 10 (POST-GATE Schema), 16 (CDG), 19 (Template Usage), 20 (Code Intelligence), 22 (R/W Lock) |

---

## Design Rationale

**Tại sao skill này tồn tại:**
1. **Toàn vẹn liên module = rủi ro lớn nhất của ERP đa module** — feature OK riêng lẻ nhưng cross-module crash silently. v2.0 đo 26 chiều (Gói C++ Logistics) thay vì chỉ 10 (v1).
2. **Business invariants là tri thức ẩn** — sales_owner phải active, tax_code unique, warehouse thuộc branch... wf-cmi infer + validate + enforce qua sidecar artifact (KHÔNG bump registry per ADR-cmi-002 Revised).
3. **Coverage matrix là release gate** — quick (60% hotfix) / standard (80% daily) / deep (95% pre-release, **v2 = 26 lanes**) / exhaustive (100% compliance audit). Threshold breach → CDG escalate.
4. **Multi-session + multi-user default cho team ERP** — Protocol 22 R/W lock + Git branch isolation cho team distributed.

**Design Principles (v2.0):**
1. **Lazy-load procedures (CORE-032)** — SKILL.md ≤500 dòng routing hub, logic trong 10 procedure files + 28 templates.
2. **CI-first (Protocol 20)** — GitNexus + Serena trước, graceful degradation Grep/Glob.
3. **Sidecar artifact (ADR-cmi-002 Revised)** — KHÔNG bump registry. APPEND-only via CDG ACCEPT.
4. **Lane isolation** — Mỗi CD{N} 1 owner + 1 file writer. **v2 thêm 3-WAVE dispatch** (max 10/wave, per-wave gate check).
5. **3-pass LLM inference (kế thừa QD11)** — Pattern → heuristic → registry gap. Confidence + CDG gate.
6. **Cross-skill artifact (CORE-036)** — `integrity-impact-v2` cho 4 consumers downstream. **v2 backward-compat: consumer phải read được v1 + v2**.
7. **CDG mặc định cho enforce action (CORE-027)** — APPEND invariant, cross-domain conflict, coverage breach, multi-user dual-approval đều qua AskUserQuestion.
8. **Session isolation (CORE-030/035)** — `sessions/{SESSION_ID}/` + `.lock` + heartbeat + atomic write `.tmp.$$ → validate → mv`.
9. **v2.0 specifics**: Breaking `--profile=deep` 10→26 lanes (E110 WARN khi resume v1 session). Mobile scope chỉ `erp-web` (mobile/customer defer v2.1). Skeleton CD32-CD36 cho v3 (Option B merge — không bump registry, không thêm SKILL.md complexity ở v2).
