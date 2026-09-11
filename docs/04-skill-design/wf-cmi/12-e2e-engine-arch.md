# wf-cmi v3.0 — E2E Engine Architecture Deep-Dive

> **Phiên bản:** v3.0.0 · **Ngày:** 2026-05-17 · **Đối tượng:** Skill maintainers, architects, advanced users
>
> Tài liệu kỹ thuật chi tiết về kiến trúc 3 module mới v3.0: **lane CD41 "E2E Scenario Synthesizer"** (Phase 4 Wave 3) + **Phase 9 "E2E Execute & Verify"** + **Phase 10 "E2E Resolution"**.

---

## Mục lục

1. [Tổng quan kiến trúc v3.0](#1-tổng-quan-kiến-trúc-v30)
2. [Lane CD41 — E2E Scenario Synthesizer](#2-lane-cd41--e2e-scenario-synthesizer)
3. [Phase 9 — E2E Execute & Verify](#3-phase-9--e2e-execute--verify)
4. [Phase 10 — E2E Resolution](#4-phase-10--e2e-resolution)
5. [Failure Analyzer Engine (7-type)](#5-failure-analyzer-engine-7-type)
6. [Stable Registry — Cross-Session Flakiness Elimination](#6-stable-registry--cross-session-flakiness-elimination)
7. [Browser Lock Pattern & Multi-Session Safety](#7-browser-lock-pattern--multi-session-safety)
8. [Loop-Back từ Phase 10 vào Phase 7 (gap-suggestions)](#8-loop-back-từ-phase-10-vào-phase-7-gap-suggestions)
9. [Schema v3 Backward-Compat Strategy](#9-schema-v3-backward-compat-strategy)
10. [Cross-References Procedures](#10-cross-references-procedures)

---

## 1. Tổng quan kiến trúc v3.0

### 1.1 ADD-ONLY thuần túy

```
┌─────────────────────────────────────────────────────────────────┐
│                    wf-cmi v3.0 Pipeline                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Phase 1 Init          ─────────────► v2 identical               │
│  Phase 2 Discovery     ─────────────► v2 identical (13 graphs)   │
│  Phase 3 Invariant     ─────────────► v2 identical (3-pass LLM)  │
│  Phase 4 Coverage      ─────────────► v2 identical               │
│   ├─ Wave 1 (10 lanes graphs-only)   v2 identical                │
│   ├─ Wave 2 (10 lanes cross-layer)   v2 identical                │
│   └─ Wave 3 (6 v2 + 1 v3 = 7)        ★ ADD CD41 ★                │
│                                                                  │
│  Phase 5 Aggregate     ─────────────► v2 identical (35→36 dims)  │
│  Phase 6 Regression    ─────────────► v2 identical               │
│  Phase 7 GAP+CDG       ─────────────► v2 identical               │
│   └─ Step 7.11 v3 NEW loop-back từ Phase 10                      │
│  Phase 8 Report v3     ─────────────► E2E Summary conditional    │
│   └─ integrity-impact.json schema v3 (backward-compat v1+v2)     │
│                                                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  ━━━ V3 OPT-IN (chỉ chạy khi --exec-scenarios) ━━━              │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                                  │
│  Phase 9 E2E Execute   ───★ NEW v3 ★───► Playwright orchestration│
│   ├─ 11 steps                                                    │
│   ├─ G1.1-G1.5 quality gates                                     │
│   └─ engine: _e2e-runner.md + _screenshot-evidence.md            │
│                                                                  │
│  Phase 10 Resolution   ───★ NEW v3 ★───► auto-run nếu FAIL       │
│   ├─ 6 steps                                                     │
│   ├─ engine: _failure-analyzer.md (7-type)                       │
│   ├─ Phase A browser-fix (5 strategies)                          │
│   ├─ Phase B source-fix (--auto-fix-source + CDG E195)           │
│   └─ loop-back gap-suggestions kind='e2e_scenario_fix'           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Routing decision tree

```
START
  │
  ├─ profile = quick → 7 lanes Wave 1 only (5-10 min)
  │   └─ --exec-scenarios? → CDG E195b prompt → Execute MUST-only default
  │
  ├─ profile = standard → 13 lanes W1+2+3 subset (15-30 min)
  │   └─ --exec-scenarios? → CDG E195b prompt → Execute MUST-only default
  │
  ├─ profile = deep → 27 lanes (26 v2 + CD41) (55-90 min)
  │   └─ --exec-scenarios? → auto-run hết Phase 9-10 (no prompt)
  │
  └─ profile = exhaustive → 36 lanes (35 v2 + CD41) (120-180 min)
      └─ --exec-scenarios? → auto-run hết Phase 9-10 (no prompt)

--scenarios-only PATH (bypass Phase 1-8):
  REQUIRES --session-id pointing to DONE session với scenarios-manifest non-empty
  ├─ Phase 9 → Phase 10 → Phase 8 re-write (1 loop-back giới hạn)
```

### 1.3 Files thêm v3 (tóm tắt)

| Loại | v2 | v3 | Δ |
|------|-----|-----|---|
| Phase procedures | 8 | 10 (8 v2 + Phase 9-10) | +2 |
| Engine procedures | 0 | 3 (_e2e-runner, _failure-analyzer, _screenshot-evidence) | +3 |
| Reference procedures | 1 (_shared) | 2 (+_error-quick-lookup) | +1 |
| Lane procedures | 18 | 19 (+CD41) | +1 |
| Total procedures | 29 | 35 | +6 |
| Templates | 32 | 41 (32 + 9 new) | +9 |
| Helper scripts | 1 | 8 (1 + 7 new) | +7 |
| Output files (outputs.working[]) | 47 | 57 | +10 |
| Error codes | E001-E149 | E001-E199 | +50 codes range |

---

## 2. Lane CD41 — E2E Scenario Synthesizer

### 2.1 Mục đích

Sinh ra `test-scenario.md` từ violations Phase 5 (MUST/HIGH severity) bằng cách walk workflow-graph + invariants, KHÔNG yêu cầu Playwright runtime. Output là pure artifact (markdown + JSON manifest) — consume bởi Phase 9 nếu user pass `--exec-scenarios`.

### 2.2 Vị trí trong pipeline

- **Phase 4 Wave 3** (sau Wave 1 graphs-only + Wave 2 cross-layer)
- Cùng wave với CD9 Regression / CD26 UX Workflow Visibility / CD29 Audit Trail / CD38 UI Coverage / CD39 Error UX / CD40 Print & Export
- Profile activation: **deep | exhaustive only** (KHÔNG hoạt động quick/standard trừ khi `--exec-scenarios` + CDG E195b user chọn `execute_all`)

### 2.3 Owner agents (3 co-owners)

| Agent | Role |
|-------|------|
| `qa-lead` | CD41 owner — đảm bảo test scenario quality, lint compliance |
| `ux-researcher` | Co-owner cho UX scenarios — UI/UX patterns, journey continuity |
| `business-analyst` | Co-owner cho business scenarios — workflow correctness, cross-module logic |

Agent spawn theo 8-section CORE-037 prompt (xem `docs/04-skill-design/wf-cmi/agent-prompt.md` §31).

### 2.4 Filter dims (8 dims)

CD41 chỉ sinh scenarios từ violations thuộc:

| Dim | Lane | Lý do |
|-----|------|-------|
| CD9 | Regression coverage | Diff-aware scenarios cho changed code |
| CD11 | FE Component Contracts | Component props mismatch → render scenario |
| CD13 | FE↔BE Contract Sync | API call mismatch → E2E request scenario |
| CD15 | UI Permission Mirror | Permission gate fail → auth scenario |
| CD23 | UX Design System | Design token drift → visual regression |
| CD24 | UX Display Format | Format inconsistency → display verify |
| CD25 | UX Flow Continuity | Broken journey → step-by-step flow |
| CD26 | UX Workflow Visibility | Missing status indicator → visibility verify |
| CD38 | UI Implementation Coverage | Missing CRUD UI → coverage scenario |
| CD39 | Error UX & Recovery | Error boundary missing → error scenario |

Severity filter: **MUST + HIGH** only (MEDIUM/LOW skipped trừ khi exhaustive profile).

### 2.5 Confidence scoring

Mỗi scenario tính confidence (0.0-1.0) dựa:

| Yếu tố | Weight |
|--------|--------|
| Walk workflow-graph success (đủ flow path) | 0.3 |
| Source violation severity = MUST | 0.25 |
| Cross-module = true | 0.2 (ưu tiên cross-module) |
| Invariant rule rõ ràng | 0.15 |
| Modules involved count ≥ 2 | 0.1 |

Threshold:
- confidence ≥ 0.7 → include trong manifest
- confidence 0.5-0.7 → include, mark `flag="low_confidence_warn"`
- confidence < 0.5 → SKIP (signal `SKIPPED_LOW_CONFIDENCE`)

### 2.6 Output

```
phase4-coverage/lanes/CD41-e2e-synth/
├── scenarios-manifest.json (schema: scenarios-manifest-v1)
│   {
│     "session_id": "...",
│     "lane": "CD41",
│     "mode": "synth-only",
│     "total_synthesized": 15,
│     "total_valid": 12,
│     "total_skipped_low_confidence": 3,
│     "total_cross_module": 5,
│     "scenarios": [ ... per-scenario metadata ... ],
│     "metadata": {
│       "filter_dims": ["CD9","CD11",...],
│       "filter_severities": ["MUST","HIGH"],
│       "max_scenarios_cap": 50
│     }
│   }
│
├── scenarios/
│   ├── test-scenario-CMI-01-create-invoice-cross-module.md
│   ├── test-scenario-CMI-02-customer-permission-deny.md
│   └── ...
│
├── signals.json
│   - 3 kinds: E2E_SCENARIO_SYNTHESIZED, SKIPPED_LOW_CONFIDENCE, CROSS_MODULE_DETECTED
│
├── lane-status.json
└── CD41-report.md
```

### 2.7 Per-scenario template (frontmatter 14 fields)

```yaml
---
scenario_id: CMI-01-create-invoice-cross-module
generated_by: wf-cmi v3.0 CD41
session_id: 2026-05-17-system-deep-01
source_violation_id: VIO-CD13-invoice-api-mismatch-001
source_invariant_id: INV-cross-Finance-Logistics-002
source_dim: CD13
severity: MUST
scenario_type: cross-module
modules_involved:
  - finance
  - logistics
cross_module: true
confidence: 0.92
entry_url: /finance/invoices/new
actor: finance-clerk
mode: headless
---

## Scenario: Tạo Invoice cross-module với Logistics BOL

### Bước thực hiện

| Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|------|-----------|------------------|-----------------|-----------|
| 1 | Điều hướng /finance/invoices/new | Form hiển thị có fields BOL ref | | |
| 2 | Nhập "BOL-2026-001" vào field "BOL Reference" | Auto-suggest dropdown hiển thị | | |
| 3 | Chọn BOL từ dropdown | Auto-fill customer + amount từ logistics | | |
| 4 | Click "Tạo Invoice" | Invoice tạo thành công + redirect /finance/invoices/{id} | | |
| 5 | Click vào BOL reference trong invoice | Điều hướng sang /logistics/bol/{id} | | |
```

### 2.8 CD41 link với Phase 9

- Nếu user pass `--exec-scenarios` → Phase 9 PRE-GATE T1 consume `scenarios-manifest.json` (manifest non-empty check)
- Nếu manifest rỗng (e.g., 0 violations sinh ra) → Phase 9 SKIP với E150b WARN
- Nếu CD41 không chạy (profile=quick) + `--exec-scenarios` → CDG E195b prompt user

---

## 3. Phase 9 — E2E Execute & Verify

### 3.1 Mục đích

Orchestrate Playwright execute scenarios CD41 đã sinh ra, lint + 5x flakiness check, sinh evidence (screenshots/console/network), emit `e2e-results.json` cho Phase 10 consume.

### 3.2 Trigger condition

```
IF --exec-scenarios = true
AND (scenarios-manifest.json exists AND non-empty)
AND Playwright MCP available (browser-mcp.lock acquirable)
AND FE running (entry_url probe successful)
THEN run Phase 9
ELSE SKIP với E150 (Playwright down) / E150b (manifest empty) / E151 (FE not running)
```

### 3.3 11 Steps tổng quan

| Step | Tên | Mô tả ngắn |
|------|-----|------------|
| 9.1 | Init | Tạo phase9-e2e-execute/ subdir + init e2e-results.json (schema e2e-results-v1) |
| 9.2 | Acquire lock | `browser-lock.sh acquire` với TTL 30 min, max 5 retries × 10s |
| 9.3 | Lint loop | FOR each scenario: `lint-scenario.sh` (7 LINT rules) → output lint-report.json |
| 9.4 | Pre-flight 5x | FOR each scenario: detect-modified + stable-registry hit check + nếu MISS → 5x stability execute (deterministic levels stable/flaky_warn/flaky_quarantine/blocked) |
| 9.5 | Login optional | Nếu scenario actor != "anonymous" → Playwright login flow (sử dụng wf-e2e-credentials) |
| 9.6 | FOR each scenario | DELEGATE to `_e2e-runner.md` engine (Step Pattern Recognition + Expected Result Verification + Cross-Module walk) |
| 9.7 | Cross-module aggregate | Collect cross-module scenarios kết quả → reference_id_consistency + data_consistency + saga_compensation check |
| 9.8 | Release lock | `browser-lock.sh release` |
| 9.9 | Write exec-report.md | Render e2e-execution-report.md (6 sections, awk multi-line block insert) |
| 9.10 | Update status + audit_chain | Atomic update integrity-status.json + audit_chain.checksum sha256(e2e-results.json) |
| 9.11 | POST-GATE T1-T4 | T1 e2e-results exists + non-empty / T2 schema e2e-results-v1 / T3 evidence coverage ≥ threshold (80% default / 100% --strict-evidence) / T4 cross-module aggregate OK |

### 3.4 Quality Gates G1.1-G1.5

| Gate | Tên | Mô tả |
|------|-----|-------|
| G1.1 | Lint script | 7 LINT rules CMI-specific (LINT-001 frontmatter / LINT-002 steps_table_malformed / LINT-003 unknown_step_pattern / LINT-004 expected_result_empty / LINT-005 actor_not_in_rbac / LINT-006 entry_url_unreachable / LINT-007 cross_module_path_invalid). Critical errors → BLOCK Phase 9 (E151) |
| G1.2 | 5x stability | Deterministic stub stages, 4 levels: stable (5/5 PASS) / flaky_warn (4/5) / flaky_quarantine (≤3/5) / blocked. Quarantine → quarantine-report.json APPEND |
| G1.3 | Stable-registry hit | sha256(scenario .md content) hit + verified_at + TTL ≤ 30d → SKIP 5x. Cross-session shared registry |
| G1.4 | Quarantine override | Scenario flaky 3 lần liên tiếp → CDG E090 user decide: Quarantine permanent / Retry x1 more / Skip |
| G1.5 | Cross-module aggregate | Cross-module scenarios kết quả → check reference_id_consistency + data_consistency + saga_compensation. Mismatch → mark e2e-results entry `cross_module_validation_failed=true` |

### 3.5 Step Pattern Recognition (5 patterns + tiếng Việt aliases)

Engine `_e2e-runner.md` §C.3 — `classify_step_pattern()` bash function:

| Pattern | Vietnamese alias | Playwright tool |
|---------|------------------|-----------------|
| Click | nhấp, nhấn, click | `browser_click` |
| Fill | nhập, điền, fill | `browser_type` |
| Select | chọn, select | `browser_select_option` |
| Wait | chờ, đợi, wait | `browser_wait_for` |
| Navigate | điều hướng, mở, navigate | `browser_navigate` |

Step KHÔNG match 5 patterns → mark `unknown_step_pattern` (LINT-003 critical) → BLOCK.

### 3.6 Expected Result Verification (4 modes)

Engine `_e2e-runner.md` §E — `verify_expected_result()` function:

| Mode | Auto-detect | Tool |
|------|-------------|------|
| Element existence | "hiển thị", "có", "displays" | `browser_snapshot` + grep selector |
| Text content | "chứa", "contains", "shows text" | `browser_snapshot` + text match |
| URL change | "redirect", "điều hướng tới /" | `browser_evaluate` + window.location |
| Network response | "API trả về", "status 200" | `browser_network_requests` filter |

Indeterminate → UNDETERMINED fallback (E161) → mark scenario `verification_undetermined=true`.

### 3.7 Evidence Capture

Engine `_screenshot-evidence.md`:

| Trigger | Capture | Frequency |
|---------|---------|-----------|
| Scenario start | screenshot + DOM snapshot | 1 per scenario |
| Per step | screenshot | 1 per step |
| Network 4xx/5xx | screenshot + console + network log | event-driven |
| Console error | console capture | event-driven |
| Scenario end | screenshot + DOM final + network full log | 1 per scenario |
| FAIL | screenshot + DOM diff + network trace + timing | event-driven |
| Quarantine | full bundle (DOM/network/console/screenshots/timing) | 1 per quarantine |
| Cross-module step transition | screenshot + URL log | per transition |

File naming convention: `screenshots/scenario-{NN}-{slug}-{idx}-{tactic}.png` (max 50-char Windows path).

Cleanup: 30-day retention default, quarantine subdir move (KHÔNG xóa quarantine evidence).

### 3.8 Output

```
phase9-e2e-execute/
├── e2e-execution-report.md (user-facing, 6 sections)
├── e2e-results.json (schema: e2e-results-v1, structured per-scenario)
├── lint-report.json (schema: lint-report-v1)
├── lint-fixes.md (user-facing nếu lint FAIL/WARN)
├── stable-registry.json (schema: stable-registry-v1, TTL 30d cross-session)
├── quarantine-report.json (schema: quarantine-report-v1)
├── screenshots/
│   └── scenario-{NN}-{slug}-{idx}-{tactic}.png × N
└── Phase9-report.md (CORE-028 ≤15 dòng tiếng Việt)
```

---

## 4. Phase 10 — E2E Resolution

### 4.1 Mục đích

Phân loại failures từ Phase 9 (7-type), auto-fix qua 2-phase (browser-fix → source-fix nếu opt-in), enrich `e2e-results.json`, sinh `resolution-report.md`, loop-back vào `gap-suggestions.json` Phase 7.

### 4.2 Trigger condition

```
IF Phase 9 ran (status = completed)
AND e2e-results.json có ≥ 1 entry với execution_status = "FAIL"
THEN run Phase 10
ELSE SKIP (all PASS hoặc Phase 9 skipped)
```

### 4.3 6 Steps tổng quan

| Step | Tên | Mô tả ngắn |
|------|-----|------------|
| 10.1 | Init | Tạo phase10-e2e-resolution/ subdir + create accumulators (RESOLUTION_ACCUMULATOR, SPAWN_AGENT_LOG, counters) |
| 10.2 | FOR each FAIL | Orchestrate engine §B-J (delegate to `_failure-analyzer.md`) — 7-type classify + 2-phase auto-fix + enrich |
| 10.3 | Loop-back APPEND | engine §J function — APPEND `kind="e2e_scenario_fix"` vào `phase7-gap-cdg/gap-suggestions.json` (anti-loop guard) |
| 10.4 | Write resolution-report.md | Template strip + awk multi-block insert (FAILURE_TYPE_BREAKDOWN + RESOLUTION_TABLE + CDG_LOG + SPAWN_AGENT_LOG) |
| 10.5 | Update integrity-status | Atomic update `.phases_completed += [10]` + `.next_action="Phase 8 re-write"` (trigger Phase 8 Step 8.3.6b + Step 8.4.6b populate v3 fields) |
| 10.6 | POST-GATE T1-T4 | T1 resolution-report non-empty / T2 every FAIL có resolution entry / T3 gap-suggestions schema intact / T4 Phase10-report.md ≤15 dòng |

### 4.4 Auto-fix Decision Matrix

| Failure type | Phase A (browser-fix) | Phase B (source-fix) |
|---------------|----------------------|----------------------|
| AUTH | Re-login via wf-e2e-credentials | security agent (token refresh / role permission edit) |
| NETWORK | Retry 5xx (max 3 retries) | developer agent (BE endpoint fix / proxy config) |
| DATA_MISSING | Seed UI inject OR navigate to seed flow | dba agent (DB seed missing data) |
| TEST_SELECTOR | 3 selector variants (CSS / XPath / role-based) | qa-lead agent (scenario .md edit selector) |
| UI_BUG | Page reload + retry | frontend-developer agent (component fix) |
| BUSINESS_RULE | (SKIP Phase A — no browser-fix possible) | business-analyst + domain expert agent (logic fix) |
| UNKNOWN | (SKIP Phase A) | (SKIP Phase B — escalate to user) |

### 4.5 Phase A — Browser Fix (default, runs cho 5 types)

5 strategies (engine `_failure-analyzer.md` §H.2):

1. **TEST_SELECTOR variants:** Try CSS → XPath → role-based selectors sequentially
2. **AUTH re-login:** Trigger Playwright login flow via wf-e2e-credentials (max 1 retry)
3. **NETWORK 5xx retry:** Wait 2s exponential backoff + retry navigation (max 3 retries)
4. **UI_BUG reload:** `browser_navigate(current_url)` + retry scenario
5. **DATA_MISSING seed/UI:** Try inject via UI form OR navigate to seed URL

Post Phase A:
- Success → mark `execution_status="AUTO_CORRECTED"` + atomic update test-scenario.md với "Tested by Phase A"
- Fail → proceed to Phase B nếu `--auto-fix-source`, else mark `UNRESOLVED`

### 4.6 Phase B — Source Fix (OPT-IN `--auto-fix-source` + CDG E195)

**Trigger:**
- User pass `--auto-fix-source` flag
- CDG E195 AskUserQuestion (lần đầu trong session) — Confirm / Reject / Skip-this-time
- CI mode (`--no-prompt`) → auto-confirmed với E101 LOG warn

**Agent spawn (max concurrency 3):**

| Failure type | Spawn agent | 8-section prompt template (CORE-037) |
|--------------|-------------|--------------------------------------|
| AUTH | security | Role + Task + Session + CI + Playwright + Output (auth code fix) + Ownership + Completion |
| NETWORK | developer | Role + Task + Session + CI + Output (BE endpoint fix) + Ownership + Completion |
| DATA_MISSING | dba | Role + Task + Session + CI + Output (DB seed) + Ownership + Completion |
| TEST_SELECTOR | qa-lead | Role + Task + Session + CI + Playwright + Output (scenario.md edit) + Ownership + Completion |
| UI_BUG | frontend-developer | Role + Task + Session + CI + Playwright + Output (component fix) + Ownership + Completion |
| BUSINESS_RULE | business-analyst + domain expert (logistics/finance/compliance) | Role + Task + Session + Output (logic + spec fix) + Ownership + Completion |

Co-spawn function `infer_domain_expert()` route theo `modules_involved`:
- finance modules → `finance-expert`
- logistics modules → `logistics-expert`
- compliance flags → `compliance-expert`
- hr modules → `hr-expert`
- sales modules → `sales-expert`

**Post Phase B:**
- Agent returns `{success: true, files_modified: [...], confidence_level: 0.x}`
- Orchestrator wait for HMR (frontend dev server hot reload) ≤ 5s
- Reload page + re-execute scenario via `_e2e-runner.md`
- Re-pass → mark `execution_status="PASS_PHASE_B"`
- Re-fail → mark `UNRESOLVED` + escalate to user qua resolution-report

Cannot fix (agent returns `cannot_fix=true`) → mark `ESCALATE_USER` + skip scenario.

### 4.7 Resolution entry 4 variants

| Variant | execution_status | Phase A outcome | Phase B outcome |
|---------|------------------|------------------|------------------|
| 1 | AUTO_CORRECTED | success | (skipped — no need) |
| 2 | PASS_PHASE_B | fail | success |
| 3 | UNRESOLVED | fail | fail OR cannot_fix |
| 4 | SKIP_UNKNOWN | (no Phase A) | (no Phase B) — failure_type=UNKNOWN escalate user |

### 4.8 Output

```
phase10-e2e-resolution/
├── resolution-report.md (user-facing, 6 sections)
│   - Tổng quan
│   - Failure classification matrix (7-type)
│   - Per-failure resolution (4 variants)
│   - Auto-fix outcomes (Phase A success / Phase B success / UNRESOLVED / SKIP)
│   - Loop-back suggestions (số e2e_scenario_fix APPEND)
│   - Phase Summary
└── Phase10-report.md (CORE-028 ≤15 dòng tiếng Việt)
```

---

## 5. Failure Analyzer Engine (7-type)

### 5.1 7-type Priority Order

Engine `_failure-analyzer.md` §C — `classify_failure_type()` với priority override:

```
Priority 1: AUTH (401/403 status code OR "unauthorized"/"forbidden" message)
Priority 2: NETWORK (5xx status code OR "timeout"/"connection refused")
Priority 3: DATA_MISSING (DOM text "không tìm thấy"/"not found" KHI API 200)
Priority 4: TEST_SELECTOR (element_not_found OR ElementNotFoundError)
Priority 5: UI_BUG (TypeError OR ReferenceError trong console)
Priority 6: BUSINESS_RULE (validation message OR "rule violated")
Priority 7: UNKNOWN (no matching signal)

PRIORITY OVERRIDE:
- AUTH (P1) override NETWORK (P2) khi cả 2 trigger với 401/403 (auth fail xảy ra TRƯỚC network 5xx)
- DATA_MISSING (P3) chỉ match khi API 200 OK (vì API 404 đã match NETWORK P2 trước)
```

### 5.2 Layer + Owner mapping

| Failure type | Layer | Owner agent | Co-spawn (Phase B) |
|--------------|-------|-------------|---------------------|
| AUTH | Auth Service | security | — |
| NETWORK | API Gateway / BE | developer | (architect nếu cross-module) |
| DATA_MISSING | Database / Seed | dba | (data-engineer nếu schema issue) |
| TEST_SELECTOR | Test Scenario | qa-lead | — |
| UI_BUG | Frontend Component | frontend-developer | — |
| BUSINESS_RULE | Business Logic | business-analyst | domain expert (logistics/finance/compliance) |
| UNKNOWN | (escalate) | — | — |

### 5.3 Evidence collection (Bước 1)

Engine §B `collect_evidence(scenario_id)`:

1. **CONSOLE:** `browser_console_messages` filter errors + warnings
2. **NETWORK:** `browser_network_requests` filter 4xx/5xx + slow (>3s)
3. **DOM:** `browser_snapshot` text content + selector tree

Partial evidence → E181 WARN, continue with available data.

### 5.4 Resolution direction templates per type

Engine §E — 7 templates với CMI context enrichment:

```
TEMPLATE_AUTH:
  Direction: Token refresh, role permission edit, session timeout config
  CMI context: source_violation_id, modules_involved (auth scope)

TEMPLATE_NETWORK:
  Direction: BE endpoint health, retry policy, circuit breaker, proxy config
  CMI context: invariant_id (API contract), modules_involved (cross-module call)

TEMPLATE_DATA_MISSING:
  Direction: DB seed, migration check, reference data load order
  CMI context: source_dim (CD7/CD17), modules_involved (data ownership)

... (4 more templates)
```

### 5.5 Confidence computation (loop-back)

Engine §J `append_loop_back_suggestion()`:

| Outcome | Confidence | Bucket |
|---------|------------|--------|
| Phase A PASS | 0.95 | high |
| Phase B PASS | 0.85 | high |
| Phase A+B FAIL | 0.30 | low |
| SKIP_UNKNOWN | 0.50 | medium (default) |

Confidence bucket dùng cho Phase 7 Step 7.11 organize gap suggestions vào high/medium/low sections.

---

## 6. Stable Registry — Cross-Session Flakiness Elimination

### 6.1 Mục đích

Cache scenarios đã PASS stable (5/5 pre-flight) cross-session với TTL 30 ngày để skip 5x flakiness check ở lần chạy tiếp theo. Tiết kiệm ~5-10 phút per scenario stable.

### 6.2 Schema

```json
{
  "$schema": "stable-registry-v1",
  "_template_notes": { ... },
  "registry_owner": "wf-cmi v3.0",
  "ttl_days": 30,
  "scenarios": [
    {
      "scenario_id": "CMI-01-create-invoice-cross-module",
      "scenario_file_hash": "sha256:abcdef1234567890...",
      "verified_at": "2026-05-10T08:30:00Z",
      "expires_at": "2026-06-09T08:30:00Z",
      "pre_flight_pass_rate": 1.0,
      "session_origin": "2026-05-10-system-deep-01"
    }
  ]
}
```

### 6.3 Hit check logic (Step 9.4)

```bash
# Per scenario:
SCENARIO_HASH=$(sha256sum scenarios/test-scenario-CMI-{NN}-{slug}.md | cut -d' ' -f1)

# Check registry
REGISTRY_HIT=$(jq -r --arg h "$SCENARIO_HASH" \
  '.scenarios[] | select(.scenario_file_hash == "sha256:" + $h)' \
  stable-registry.json)

if [[ -n "$REGISTRY_HIT" ]]; then
  # Check TTL
  EXPIRES_AT=$(echo "$REGISTRY_HIT" | jq -r '.expires_at')
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  if [[ "$NOW" < "$EXPIRES_AT" ]]; then
    # HIT — skip 5x flakiness
    echo "stable-registry HIT for $SCENARIO_HASH (verified $verified_at)"
    EXECUTE_5X=false
  fi
fi

if [[ "$EXECUTE_5X" != "false" ]]; then
  # MISS — run 5x via e2e-pre-flight-check.sh
  bash e2e-pre-flight-check.sh "$scenario_id"
fi
```

### 6.4 APPEND logic (sau scenario PASS stable)

Khi scenario PASS pre-flight (5/5) hoặc PASS Phase 9 execute lần đầu:

```bash
NEW_ENTRY=$(jq -n \
  --arg sid "$scenario_id" \
  --arg hash "sha256:$SCENARIO_HASH" \
  --arg verified "$NOW" \
  --arg expires "$(date -u -d '+30 days' +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg origin "$SESSION_ID" \
  '{scenario_id: $sid, scenario_file_hash: $hash, verified_at: $verified, expires_at: $expires, pre_flight_pass_rate: 1.0, session_origin: $origin}')

# Atomic APPEND
jq --argjson new "$NEW_ENTRY" '.scenarios += [$new]' stable-registry.json > tmp.json
mv tmp.json stable-registry.json
```

### 6.5 Cross-session safety

Registry location: `.mc-data/work/wf-cmi/_index/stable-registry.json` (shared cross-session, NOT per-session).

Concurrency: Atomic write với Protocol 22 R/W lock. Multiple sessions APPEND song song safe.

---

## 7. Browser Lock Pattern & Multi-Session Safety

### 7.1 Per-session browser-mcp.lock

File: `$SESSION_DIR/phase9-e2e-execute/.lock-browser-mcp`

```bash
# acquire (Step 9.2)
bash scripts/wf-cmi-e2e/browser-lock.sh acquire \
  --session-dir="$SESSION_DIR" \
  --pid=$$ \
  --max-retries=5 \
  --retry-interval=10

# release (Step 9.8)
bash scripts/wf-cmi-e2e/browser-lock.sh release \
  --session-dir="$SESSION_DIR" \
  --pid=$$
```

TTL: 30 min stale auto-release + reclaim (E153 stale_lock auto-release log).

### 7.2 Cross-session R/W lock (Protocol 22)

File: `.mc-data/work/_locks/playwright.lock` (system-wide)

- **Read locks:** N readers đồng thời cho Phase 2 Discovery / Phase 5 Aggregate (read-only access codebase)
- **Write locks:** Exclusive cho Phase 9 (Playwright execute) — chỉ 1 session Phase 9 cùng lúc trên cùng máy

```bash
# Phase 9 acquire WRITE lock
bash .claude/scripts/wf-e2e-shared/global-rw-lock.sh acquire \
  --type=write \
  --resource=playwright \
  --session-id="$SESSION_ID"
```

### 7.3 Concurrency limits

| Scope | Limit |
|-------|-------|
| Per-session Phase 9 | 1 browser-mcp instance |
| Cross-session Phase 9 | 1 (write lock Protocol 22) |
| Per-session Phase 10 Phase B agents | max 3 concurrent (context budget) |
| Cross-session Phase 10 | Multiple OK (no Playwright contention) |
| Total wf-cmi sessions cùng máy | 5 quick/standard, 2 deep/exhaustive |

---

## 8. Loop-Back từ Phase 10 vào Phase 7 (gap-suggestions)

### 8.1 Schema KHÔNG bump (chỉ thêm value cho enum kind)

`templates/gap-suggestions.json` schema `gap-suggestions-v1` (KHÔNG bump v2):

- Thêm value `e2e_scenario_fix` vào enum `kind` (cùng với test_case / invariant_rule / contract_check / sidecar_append / business_rule)
- Thêm field `metadata.kind_breakdown.e2e_scenario_fix: 0` (default)
- Thêm field `metadata.e2e_loop_back_summary` (4 sub-fields: loop_back_count + high/medium/low buckets)
- Thêm field `v3_loop_back_guard` documenting 4 anti-loop rules

### 8.2 Anti-loop guard (4 rules)

```
RULE 1: APPEND CHỈ kind="e2e_scenario_fix" — KHÔNG APPEND kind khác từ Phase 10
RULE 2: KHÔNG re-trigger CD41 từ loop-back — Phase 10 KHÔNG ghi signal cho Phase 4
RULE 3: Schema vẫn gap-suggestions-v1 — KHÔNG bump schema (consumers v1/v2 compatible)
RULE 4: Per-session synth 1 lần — Phase 10 loop-back chỉ APPEND 1 lần per session, KHÔNG re-spawn
```

### 8.3 Phase 7 Step 7.11 v3 NEW (consume loop-back)

```bash
# After Step 7.10:
LOOPBACK_COUNT=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix")] | length' \
  gap-suggestions.json)

if [[ "$LOOPBACK_COUNT" -gt 0 ]]; then
  # Bucket theo confidence
  HIGH=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix" and .confidence >= 0.85)] | length' gap-suggestions.json)
  MEDIUM=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix" and .confidence > 0.30 and .confidence < 0.85)] | length' gap-suggestions.json)
  LOW=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix" and .confidence <= 0.30)] | length' gap-suggestions.json)

  # APPEND E2E_LOOPBACK_SECTION vào gap-report.md
  cat >> gap-report.md <<EOF

## E2E Loop-Back Suggestions (v3.0)

Phase 10 đã đề xuất $LOOPBACK_COUNT scenarios cần fix/regression:
- High confidence (≥0.85): $HIGH
- Medium confidence (0.30-0.85): $MEDIUM
- Low confidence (≤0.30): $LOW

EOF
fi
```

### 8.4 Phase 8 consume loop-back count

Phase 8 Step 8.3.6b:
- `N_E2E_FIX` count `e2e_scenario_fix` từ gap-suggestions
- Render vào integrity-report.md Section 4 breakdown: "[N_E2E_FIX] e2e_scenario_fix (v3 loop-back từ Phase 10)"

---

## 9. Schema v3 Backward-Compat Strategy

### 9.1 integrity-impact.json schema v3

Bump `$schema` field: `integrity-impact-v2` → `integrity-impact-v3`

**2 v3 fields mới (TOP-LEVEL):**

```json
{
  "$schema": "integrity-impact-v3",
  "skill_version": "3.0.0",

  // ... ALL v1 fields preserved (coverage_matrix_summary, violations, regression_scope, gap_artifacts_suggested, consumers_recommended_actions, summary, audit_chain) ...

  // ... ALL v2 fields preserved (lanes_v2, wave_breakdown, group_breakdown, logistics_critical_signals_count, schema_version_compat) ...

  // NEW v3 fields:
  "e2e_execution_summary": {
    "exec_enabled": true,
    "n_synth": 15,
    "n_exec": 12,
    "n_pass": 9,
    "n_auto_corrected": 2,
    "n_fail": 1,
    "n_quarantined": 0,
    "n_cross_module": 4,
    "duration_ms": 1234567,
    "n_loop_back": 1,
    "top_failure_types": ["UI_BUG", "TEST_SELECTOR"]
  },

  "scenarios_artifacts": [
    {
      "scenario_id": "CMI-01-create-invoice",
      "scenario_file": "scenarios/test-scenario-CMI-01-create-invoice.md",
      "feat_id_inferred": "FEAT-FIN-INV-001",
      "modules_involved": ["finance", "logistics"],
      "cross_module": true,
      "source_violation_ids": ["VIO-CD13-001"],
      "source_invariant_id": "INV-cross-FL-002",
      "source_dim": "CD13",
      "severity": "MUST",
      "execution_status": "PASS",
      "screenshot_paths": ["screenshots/scenario-01-..."],
      "resolution_path": null
    }
  ],

  "schema_version_compat": {
    "current": "integrity-impact-v3",
    "readable_by": ["integrity-impact-v1", "integrity-impact-v2", "integrity-impact-v3"],
    "v1_compat_note": "v1 readers access via path-based jq, ignore v2/v3 fields gracefully",
    "v2_compat_note": "v2 readers ignore v3 e2e_execution_summary + scenarios_artifacts gracefully",
    "v3_new_fields": ["e2e_execution_summary", "scenarios_artifacts"],
    "v3_compat_note": "If --exec-scenarios=off, e2e_execution_summary=null + scenarios_artifacts=[] (nullable behavior)"
  }
}
```

### 9.2 coverage-matrix.json schema v3

Bump `$schema`: `coverage-matrix-v2` → `coverage-matrix-v3`

- Add CD41 dim entry (group="e2e_synth", wave=3, owner_agents=[qa-lead, ux-researcher, business-analyst])
- `wave_breakdown.wave_3.lane_count_planned`: 6 → 7 (giữ `lane_count_planned_v2: 6` cho backward-compat)
- Total dims: 35 → 36

### 9.3 integrity-status.json v3 fields (OPTIONAL)

Thêm 2 OPTIONAL objects (v1/v2 readers ignore graceful, no schema break):

```json
{
  "v3_flags": {
    "exec_scenarios": false,
    "scenarios_only": false,
    "show_browser": false,
    "mobile": false,
    "strict_evidence": false,
    "no_prompt": false,
    "auto_fix_source": false
  },
  "v3_cdg": {
    "e195b_decision": "not_triggered",
    "cd41_force_activate": false,
    "cd41_filter_severity": "MUST,HIGH"
  }
}
```

### 9.4 gap-suggestions.json (KHÔNG bump schema)

- Schema vẫn `gap-suggestions-v1`
- Chỉ thêm value `e2e_scenario_fix` vào enum `kind`
- Backward-compat: consumers v1 đọc OK (ignore unknown kind value)

---

## 10. Cross-References Procedures

| Procedure file | Vai trò |
|----------------|---------|
| [`SKILL.md`](../../../.claude/skills/workflow/wf-cmi/SKILL.md) | Lean routing hub ≤500 dòng (CORE-032) |
| [`_contract.json`](../../../.claude/skills/workflow/wf-cmi/_contract.json) | Skill contract v3.0.0, 35 procedures, 57 outputs, 36 lanes |
| [`procedures/_shared.md`](../../../.claude/skills/workflow/wf-cmi/procedures/_shared.md) | Cross-cutting: state vars, atomic write, error handling, CI detection, Browser Lock Pattern §21, Playwright Retry Pattern §22 |
| [`procedures/_e2e-runner.md`](../../../.claude/skills/workflow/wf-cmi/procedures/_e2e-runner.md) | Engine 547 dòng — Step Pattern Recognition + Expected Result Verification + Cross-Module |
| [`procedures/_failure-analyzer.md`](../../../.claude/skills/workflow/wf-cmi/procedures/_failure-analyzer.md) | Engine 995 dòng — 7-type classify + 2-phase auto-fix + loop-back |
| [`procedures/_screenshot-evidence.md`](../../../.claude/skills/workflow/wf-cmi/procedures/_screenshot-evidence.md) | Engine 341 dòng — file naming + timing capture + strict evidence + cleanup |
| [`procedures/_error-quick-lookup.md`](../../../.claude/skills/workflow/wf-cmi/procedures/_error-quick-lookup.md) | Reference 97 dòng — full E001-E199 error codes lookup |
| [`procedures/phase1-init.md`](../../../.claude/skills/workflow/wf-cmi/procedures/phase1-init.md) | Phase 1 Init 800 dòng — parse 7 v3 args + Step 1.14b CDG E195b + Step 1.21 --scenarios-only route bypass |
| [`procedures/phase4-coverage-dispatch.md`](../../../.claude/skills/workflow/wf-cmi/procedures/phase4-coverage-dispatch.md) | Phase 4 Wave 3 dispatch — CD41 thêm vào Wave 3 lanes (deep/exhaustive) |
| [`procedures/phase7-gap-cdg.md`](../../../.claude/skills/workflow/wf-cmi/procedures/phase7-gap-cdg.md) | Phase 7 GAP+CDG 532 dòng — Step 7.11 v3 NEW loop-back consume |
| [`procedures/phase8-report.md`](../../../.claude/skills/workflow/wf-cmi/procedures/phase8-report.md) | Phase 8 Report 1227 dòng — Step 8.3.6b E2E aggregates + Step 8.4.6b populate v3 fields |
| [`procedures/phase9-e2e-execute.md`](../../../.claude/skills/workflow/wf-cmi/procedures/phase9-e2e-execute.md) | Phase 9 Execute 737 dòng — 11 steps + G1.1-G1.5 quality gates |
| [`procedures/phase10-e2e-resolution.md`](../../../.claude/skills/workflow/wf-cmi/procedures/phase10-e2e-resolution.md) | Phase 10 Resolution 685 dòng — 6 steps + CDG E195 + helper attempt_auto_fix |
| [`procedures/resume-status.md`](../../../.claude/skills/workflow/wf-cmi/procedures/resume-status.md) | Resume+Status handler 659 dòng — Phase 9-10 conditional render + --scenarios-only routing |
| [`procedures/lanes/CD41.md`](../../../.claude/skills/workflow/wf-cmi/procedures/lanes/CD41.md) | CD41 lane 814 dòng — 8 synth steps (filter → walk → render → manifest → signals → report) |

### Helper scripts

| Script | Vai trò |
|--------|---------|
| [`scripts/wf-cmi-e2e/lint-scenario.sh`](../../../.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/lint-scenario.sh) | 7 LINT rules CMI-specific (G1.1) |
| [`scripts/wf-cmi-e2e/detect-modified-scenarios.sh`](../../../.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/detect-modified-scenarios.sh) | git-diff scenarios mới/modified since baseline |
| [`scripts/wf-cmi-e2e/e2e-pre-flight-check.sh`](../../../.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/e2e-pre-flight-check.sh) | 5x stability deterministic stub (G1.2) |
| [`scripts/wf-cmi-e2e/browser-lock.sh`](../../../.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/browser-lock.sh) | Per-session browser-mcp.lock (acquire/release/status) |
| [`scripts/wf-cmi-e2e/test-stage7-smoke.sh`](../../../.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/test-stage7-smoke.sh) | Smoke test 7 scenarios §7.2 + AskUserQuestion CDG E195b |
| [`scripts/wf-cmi-e2e/test-failure-classify.sh`](../../../.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/test-failure-classify.sh) | 7-type classification test (Stage 5) |
| [`scripts/wf-cmi-e2e/test-auto-fix-phase-a-b.sh`](../../../.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/test-auto-fix-phase-a-b.sh) | Phase A + Phase B mock test (Stage 5) |
| [`scripts/wf-cmi-e2e/test-loopback-append.sh`](../../../.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/test-loopback-append.sh) | Loop-back gap-suggestions APPEND test (Stage 5) |
| [`scripts/wf-cmi-e2e/test-browser-unavailable-smoke.sh`](../../../.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/test-browser-unavailable-smoke.sh) | 5 scenarios browser unavailable graceful (Stage 8) |

### Liên kết khác

- CHANGELOG v3.0.0: [`CHANGELOG.md`](../../../CHANGELOG.md#wf-cmi-v300--2026-05-17)
- v3 migration notes: [`docs/04-skill-design/wf-cmi/v3-migration-notes.md`](v3-migration-notes.md)
- v3 user guide: [`docs/06-user-guides/per-skill/wf-cmi-v3-guide.md`](../../06-user-guides/per-skill/wf-cmi-v3-guide.md)
- Integration plan (Spec): [`plans/wf-cmi/v3.0-e2e-integration-plan.md`](../../../plans/wf-cmi/v3.0-e2e-integration-plan.md)
- Progress tracker: [`plans/wf-cmi/progress-scenario.md`](../../../plans/wf-cmi/progress-scenario.md)
- Agent prompt template CD41: [`docs/04-skill-design/wf-cmi/agent-prompt.md`](agent-prompt.md) §31

---

**END 12-e2e-engine-arch.md**
