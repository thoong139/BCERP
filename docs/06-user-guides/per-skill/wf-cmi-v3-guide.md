# Hướng dẫn Sử dụng wf-cmi v3.0 (E2E Scenario Engine)

> **Phiên bản:** v3.0.0 · **Ngày:** 2026-05-17 · **Ngôn ngữ:** Tiếng Việt
>
> Hướng dẫn dành cho người dùng (không chuyên kỹ thuật) muốn dùng `/wf-cmi` v3.0 với feature **E2E Scenario Engine** mới — tự động sinh và execute end-to-end test scenarios cho hệ thống ERP đa module (target chính: EUREKA-2026 logistics Việt-Trung).
>
> **Đọc trước:** Nếu bạn mới làm quen, đọc [`wf-cmi-v2-guide.md`](wf-cmi-v2-guide.md) trước để hiểu v2 base (26 lanes Gói C++ Logistics). Tài liệu này tập trung vào **những gì MỚI trong v3.0**.

---

## Mục lục

1. [v3.0 có gì mới so với v2.0?](#1-v30-có-gì-mới-so-với-v20)
2. [Khi nào dùng tính năng v3 E2E](#2-khi-nào-dùng-tính-năng-v3-e2e)
3. [Bắt đầu nhanh (Quick Start v3)](#3-bắt-đầu-nhanh-quick-start-v3)
4. [7 Cờ mới chi tiết](#4-7-cờ-mới-chi-tiết)
5. [CD41 — Lane "E2E Scenario Synthesizer"](#5-cd41--lane-e2e-scenario-synthesizer)
6. [Phase 9 — E2E Execute & Verify](#6-phase-9--e2e-execute--verify)
7. [Phase 10 — E2E Resolution](#7-phase-10--e2e-resolution)
8. [Critical Decision Gate (CDG) v3](#8-critical-decision-gate-cdg-v3)
9. [Output Files v3](#9-output-files-v3)
10. [Browser Unavailable Graceful](#10-browser-unavailable-graceful)
11. [`--scenarios-only` Re-Execute Flow](#11---scenarios-only-re-execute-flow)
12. [Use Cases thực tế](#12-use-cases-thực-tế)
13. [Troubleshooting v3](#13-troubleshooting-v3)
14. [Migration từ v2.0](#14-migration-từ-v20)
15. [FAQ v3](#15-faq-v3)

---

## 1. v3.0 có gì mới so với v2.0?

| Aspect | v2.0 | v3.0 |
|--------|------|------|
| **Số lanes (deep profile)** | 26 | **27** (26 + CD41 E2E Synth) |
| **Phases** | 8 (Init → Discovery → ... → Report) | 8 v2 + **2 v3 opt-in** (Phase 9 + Phase 10) |
| **Tự sinh test scenarios?** | KHÔNG | **CÓ** — CD41 sinh `test-scenario.md` từ violations + workflow-graph (profile=deep\|exhaustive) |
| **Tự execute Playwright?** | KHÔNG | **CÓ (opt-in)** — pass `--exec-scenarios` để bật Phase 9 |
| **Tự fix browser bugs?** | KHÔNG | **CÓ (Phase 10 Phase A)** — 5 strategies auto browser-fix |
| **Tự fix source code?** | KHÔNG | **CÓ (opt-in `--auto-fix-source`)** — Phase 10 Phase B spawn agent + CDG E195 confirm |
| **Cờ CLI mới** | 0 | **7 cờ v3** |
| **Output cross-skill artifact** | `integrity-impact-v2` | `integrity-impact-v3` (backward-compat 100% — v1/v2 readers vẫn OK) |
| **Backward-compat default behavior** | — | ✅ 100% — chạy `/wf-cmi --profile=deep` (không cờ v3) hoạt động identical v2 |

### Tóm tắt: bạn cần biết gì?

- ✅ Nếu bạn đang dùng v2.0 và **KHÔNG cần feature E2E**: không cần học gì mới. v3.0 hoạt động identical v2.0.
- ⭐ Nếu bạn muốn **tự sinh test scenarios** từ phân tích integrity: dùng `--profile=deep` (CD41 chạy tự động ở Wave 3).
- 🚀 Nếu bạn muốn **execute Playwright tests**: thêm `--exec-scenarios` (cần Playwright MCP + FE server running).
- 🔧 Nếu bạn muốn **auto-fix code** khi test fail: thêm `--auto-fix-source` (CDG E195 confirm, có risk — KHÔNG khuyến nghị cho CI release).

---

## 2. Khi nào dùng tính năng v3 E2E

### Nên dùng tính năng v3 khi:

- ✅ **Cần regression test cross-module** sau merge nhánh lớn (E2E scenarios với multi-module flow)
- ✅ **Pre-release verification** — auto execute tất cả MUST/HIGH scenarios trước khi deploy
- ✅ **Phát hiện UI bugs ẩn** — Playwright execute scenarios + capture evidence (screenshots/console/network)
- ✅ **CI nightly E2E** — `--ci --profile=deep --exec-scenarios` chạy tự động hàng đêm
- ✅ **Đã có session DONE muốn execute Playwright** — `--scenarios-only --session-id=<id>` skip Phase 1-8

### KHÔNG cần dùng tính năng v3 khi:

- ❌ Chỉ cần integrity report v2 (no E2E) — `/wf-cmi --profile=deep` (không pass `--exec-scenarios`) đủ
- ❌ Profile=quick/standard — CD41 không chạy mặc định, Phase 9-10 không trigger
- ❌ Project không có Playwright MCP server — sẽ SKIP graceful (E150 WARN)
- ❌ Project mobile-only (chỉ React Native, không Web) — Phase 9 sẽ FAIL probe FE entry_url

---

## 3. Bắt đầu nhanh (Quick Start v3)

### Path 1: Chỉ synth scenarios (không execute)

```bash
# Step 1: Verify v3.0 installed
jq -r '.version' .claude/skills/workflow/wf-cmi/_contract.json
# Expected: 3.0.0

# Step 2: Run deep profile — CD41 tự động chạy ở Wave 3
/wf-cmi --profile=deep
# Sau ~55-90 min, sẽ có scenarios manifest
```

Đọc kết quả:
```bash
# Manifest tổng quan
cat .mc-data/work/wf-cmi/sessions/*/phase4-coverage/lanes/CD41-e2e-synth/scenarios-manifest.json | jq '.total_synthesized, .total_valid, .total_cross_module'

# Per-scenario detail
ls .mc-data/work/wf-cmi/sessions/*/phase4-coverage/lanes/CD41-e2e-synth/scenarios/
```

### Path 2: Synth + execute Playwright

```bash
# Prerequisite: Playwright MCP server running + FE dev server running
# Check Playwright:
which npx && npx playwright --version

# Check FE running:
curl http://localhost:3000  # hoặc entry URL của dự án

# Step 1: Run full v3 pipeline
/wf-cmi --profile=deep --exec-scenarios
# Sau ~65-120 min, sẽ có Phase 9-10 outputs
```

Đọc kết quả:
```bash
# E2E execution report (Phase 9)
cat .mc-data/work/wf-cmi/sessions/*/phase9-e2e-execute/e2e-execution-report.md

# Resolution report (Phase 10, nếu có FAIL)
cat .mc-data/work/wf-cmi/sessions/*/phase10-e2e-resolution/resolution-report.md

# Updated integrity report v3 (có E2E section)
cat .mc-data/work/wf-cmi/sessions/*/phase8-report/integrity-report.md
```

### Path 3: Re-execute Playwright trên session đã có scenarios

```bash
# Bước trước: Đã chạy /wf-cmi --profile=deep và có scenarios-manifest
# Bây giờ muốn execute Playwright mà KHÔNG chạy lại Phase 1-8

/wf-cmi --scenarios-only --session-id=2026-05-17-system-deep-01 --exec-scenarios
```

---

## 4. 7 Cờ mới chi tiết

| Cờ | Default | Mô tả | Ví dụ |
|----|---------|-------|-------|
| `--exec-scenarios` | OFF | Bật Phase 9 E2E execute. Không bật thì chỉ synth scenarios (CD41), không execute Playwright. | `/wf-cmi --profile=deep --exec-scenarios` |
| `--scenarios-only` | OFF | Bypass Phase 1-8. Chỉ chạy Phase 9-10 trên session DONE đã có scenarios-manifest. Cần `--session-id`. | `/wf-cmi --scenarios-only --session-id=2026-05-17-XX --exec-scenarios` |
| `--show-browser` | OFF | Playwright headed mode (visible browser, không headless). Hữu ích khi debug. Yêu cầu `--exec-scenarios`. | `/wf-cmi --profile=deep --exec-scenarios --show-browser` |
| `--mobile` | OFF | Mobile device emulation (Playwright emulate iPhone/Android). Yêu cầu `--exec-scenarios`. | `/wf-cmi --profile=deep --exec-scenarios --mobile` |
| `--strict-evidence` | OFF (80%) | Bật 100% evidence coverage requirement (mặc định 80%). Mọi step phải có screenshot/console/network. Yêu cầu `--exec-scenarios`. | `/wf-cmi --profile=deep --exec-scenarios --strict-evidence` |
| `--no-prompt` | OFF | Bypass tất cả CDG AskUserQuestion (CI mode). CDG E195b silent default = `execute_must_only`. | `/wf-cmi --ci --profile=deep --exec-scenarios --no-prompt` |
| `--auto-fix-source` | OFF | Bật Phase 10 Phase B source-fix (spawn agents edit code). **CẦN CDG E195 confirm mỗi session**. ⚠ Risk: agent có thể commit code unwanted. | `/wf-cmi --profile=deep --exec-scenarios --auto-fix-source` |

### Khuyến nghị an toàn

| Tình huống | Cờ khuyến nghị |
|------------|-----------------|
| **Lần đầu thử v3.0** | `--profile=deep` (chỉ synth, không execute) |
| **Pre-PR review** | `--profile=standard --exec-scenarios` (subset, hỏi CDG E195b) |
| **Pre-release verify** | `--profile=deep --exec-scenarios` (auto run hết, no source-fix) |
| **CI nightly** | `--ci --profile=deep --exec-scenarios --no-prompt` (auto MUST-only) |
| **Debug failing scenario** | `--scenarios-only --session-id=<id> --exec-scenarios --show-browser` |
| **Mobile testing** | `--profile=deep --exec-scenarios --mobile` |
| **High-stakes deploy** | `--profile=exhaustive --exec-scenarios --strict-evidence` |
| **CI release gate** | `--ci --profile=deep --exec-scenarios --no-prompt` (KHÔNG khuyến nghị `--auto-fix-source` trong CI release) |

---

## 5. CD41 — Lane "E2E Scenario Synthesizer"

### CD41 là gì?

Lane mới ở Wave 3 (Phase 4 Coverage Dispatch), tự động sinh ra `test-scenario.md` từ:
- **Violations Phase 5** (MUST/HIGH severity)
- **Workflow-graph Phase 2** (walking flow paths)
- **Business invariants Phase 3** (LLM-derived rules)

Output là pure artifact (KHÔNG execute Playwright) — sẵn sàng cho Phase 9 nếu user pass `--exec-scenarios`.

### Khi nào CD41 chạy?

- ✅ `--profile=deep` (auto chạy ở Wave 3)
- ✅ `--profile=exhaustive` (auto chạy ở Wave 3)
- ❌ `--profile=quick` (KHÔNG chạy)
- ❌ `--profile=standard` (KHÔNG chạy)
- ⚠ `--profile=quick|standard + --exec-scenarios` → CDG E195b prompt user

### Filter dims (10 dims sinh scenarios)

CD41 chỉ sinh scenarios từ violations thuộc các dims:
- **CD9** Regression (cho diff-aware testing)
- **CD11** FE Component Contracts
- **CD13** FE↔BE Contract Sync
- **CD15** UI Permission Mirror
- **CD23** UX Design System
- **CD24** UX Display Format
- **CD25** UX Flow Continuity
- **CD26** UX Workflow Visibility
- **CD38** UI Implementation Coverage
- **CD39** Error UX & Recovery

Severity filter: **MUST + HIGH only**.

### Output

```
phase4-coverage/lanes/CD41-e2e-synth/
├── scenarios-manifest.json  (tổng quan, schema scenarios-manifest-v1)
├── scenarios/
│   ├── test-scenario-CMI-01-create-invoice-cross-module.md
│   ├── test-scenario-CMI-02-customer-permission-deny.md
│   └── ... (N scenarios)
├── signals.json  (3 kinds: SYNTHESIZED + SKIPPED_LOW_CONFIDENCE + CROSS_MODULE_DETECTED)
├── lane-status.json
└── CD41-report.md
```

Mỗi scenario có **frontmatter YAML 14 fields** + bảng 5 cột (Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail). Người không chuyên có thể đọc + execute manual nếu cần.

---

## 6. Phase 9 — E2E Execute & Verify

### Phase 9 chạy khi nào?

Bốn điều kiện đồng thời:
1. `--exec-scenarios` flag được pass
2. CD41 đã sinh ra `scenarios-manifest.json` non-empty
3. Playwright MCP server available (browser-mcp.lock acquirable)
4. FE dev server running (probe entry_url succeeded)

Thiếu 1 trong 4 → SKIP Phase 9 graceful (E150 / E150b / E151).

### Phase 9 làm gì?

| Step | Mô tả ngắn |
|------|------------|
| 9.1 Init | Tạo phase9-e2e-execute/ subdir + init e2e-results.json |
| 9.2 Acquire lock | `browser-lock.sh acquire` TTL 30 min |
| 9.3 Lint loop | 7 LINT rules per scenario (LINT-001 to LINT-007) — critical errors BLOCK Phase 9 |
| 9.4 Pre-flight 5x | Stability check 4 levels (stable / flaky_warn / flaky_quarantine / blocked). Stable-registry hit → skip 5x |
| 9.5 Login optional | Playwright login flow nếu scenario actor != "anonymous" |
| 9.6 Execute scenarios | Per-scenario engine — Step Pattern Recognition + Expected Result Verification + Cross-Module walk |
| 9.7 Cross-module aggregate | Check reference_id_consistency + data_consistency + saga_compensation |
| 9.8 Release lock | `browser-lock.sh release` |
| 9.9 Write exec-report | Render e2e-execution-report.md 6 sections |
| 9.10 Update status | Atomic update integrity-status + audit_chain.checksum |
| 9.11 POST-GATE | T1-T4 validation |

### Đọc Phase 9 report

```bash
cat .mc-data/work/wf-cmi/sessions/*/phase9-e2e-execute/e2e-execution-report.md
```

6 sections:
1. **Tổng quan** — Total scenarios + Pass/Auto_corrected/Fail/Quarantined breakdown
2. **Setup environment** — Playwright version + FE URL + login info
3. **Per scenario detail** — Mỗi scenario có status + duration + evidence link
4. **Cross-module** — Cross-module scenarios kết quả + reference consistency check
5. **Quarantined** — Scenarios flaky bị quarantine (cần manual review)
6. **Phase Summary** — Tiếng Việt ≤15 dòng

### Status meaning

| Status | Ý nghĩa |
|--------|----------|
| `PASS` | Scenario chạy thành công lần đầu |
| `AUTO_CORRECTED` | Scenario fail nhưng Phase 10 Phase A đã browser-fix thành công |
| `PASS_PHASE_B` | Scenario fail Phase A, nhưng Phase B source-fix thành công (chỉ khi `--auto-fix-source`) |
| `FAIL` | Scenario fail và không auto-fix được — cần manual review |
| `QUARANTINED` | Scenario flaky 5x execute fail ≥2/5 — mark quarantine cho QA review |
| `BLOCKED` | Pre-flight fail (entry_url unreachable, login fail) |
| `NOT_EXECUTED` | Lint critical error → BLOCK trước khi execute |

---

## 7. Phase 10 — E2E Resolution

### Phase 10 chạy khi nào?

Tự động trigger nếu Phase 9 có ≥1 scenario với `execution_status="FAIL"`. KHÔNG chạy nếu all PASS hoặc Phase 9 skipped.

### Phase 10 làm gì?

7-type failure classification + 2-phase auto-fix + loop-back:

**Bước 1: Phân loại failure 7-type** (priority order):
1. AUTH (401/403)
2. NETWORK (5xx, timeout)
3. DATA_MISSING (DOM "không tìm thấy" + API 200)
4. TEST_SELECTOR (element_not_found)
5. UI_BUG (TypeError, ReferenceError trong console)
6. BUSINESS_RULE (validation message)
7. UNKNOWN (no matching signal)

**Bước 2: Phase A — Browser Fix (default, runs cho 5 types)**:
- TEST_SELECTOR: thử 3 selector variants (CSS / XPath / role)
- AUTH: re-login via wf-e2e-credentials
- NETWORK: retry 5xx exponential backoff (max 3)
- UI_BUG: page reload + retry
- DATA_MISSING: seed inject UI

Success → `AUTO_CORRECTED`. Fail → proceed Phase B nếu `--auto-fix-source`.

**Bước 3: Phase B — Source Fix (OPT-IN `--auto-fix-source`)**:
- CDG E195 AskUserQuestion (lần đầu trong session) — Confirm / Reject / Skip
- Spawn agent theo failure type (qa-lead / security / developer / frontend-developer / dba / business-analyst)
- Max concurrency 3 agents song song
- HMR wait 5s + reload page + re-execute scenario
- Success → `PASS_PHASE_B`. Fail → `UNRESOLVED`.

**Bước 4: Loop-back gap-suggestions**:
- APPEND `kind="e2e_scenario_fix"` vào `phase7-gap-cdg/gap-suggestions.json`
- Confidence buckets: high (≥0.85) / medium (0.30-0.85) / low (≤0.30)
- Anti-loop guard: KHÔNG re-trigger CD41, per-session 1 lần

### Đọc Phase 10 report

```bash
cat .mc-data/work/wf-cmi/sessions/*/phase10-e2e-resolution/resolution-report.md
```

6 sections: Tổng quan + Failure classification matrix + Per-failure resolution + Auto-fix outcomes + Loop-back suggestions + Phase Summary.

---

## 8. Critical Decision Gate (CDG) v3

### 2 CDG mới v3

| Code | Tình huống | Options |
|------|-------------|---------|
| **E195** | `--auto-fix-source` lần đầu trong session — confirm spawn agent edit code | Confirm / Reject / Skip-this-time |
| **E195b** | `--exec-scenarios` + profile=quick\|standard — confirm subset execute | Execute all (CD41 force MUST+HIGH) / Execute MUST-only (Recommended) / Cancel |

### CI mode `--no-prompt` default

| CDG | `--no-prompt` silent default |
|-----|------------------------------|
| E195 | Auto-confirmed với E101 LOG warn (KHÔNG khuyến nghị cho release CI) |
| E195b | `execute_must_only` (balanced safety) |

### CDG flow ví dụ

```bash
# Interactive (default):
$ /wf-cmi --profile=quick --exec-scenarios
> CDG E195b: --exec-scenarios + profile=quick
> Bạn muốn execute scenarios nào?
>   [1] Execute all (CD41 force MUST + HIGH violations)
>   [2] Execute MUST-only (Recommended)  ← default
>   [3] Cancel (SKIP Phase 9-10)
> Chọn (1/2/3): 2
> [E195b decision: execute_must_only persisted]

# CI (silent default):
$ /wf-cmi --ci --profile=quick --exec-scenarios --no-prompt
> CDG E195b silent default = execute_must_only
> [E195b decision: execute_must_only auto]
```

---

## 9. Output Files v3

### Pipeline directory structure v3

```
.mc-data/work/wf-cmi/sessions/{SESSION_ID}/
├── integrity-status.json           # SSOT pipeline state (v3 fields: v3_flags{} + v3_cdg{})
├── session-log.json                # Execution trace
├── error-ledger.json
├── phase1-init/
├── phase2-discovery/                # 13 graphs
├── phase3-invariant/
├── phase4-coverage/
│   ├── wave-status.json
│   ├── lanes/CD11/ ... lanes/CD40/  # 26 v2 lanes
│   └── lanes/CD41-e2e-synth/       # ★ NEW v3 ★
│       ├── scenarios-manifest.json
│       ├── scenarios/
│       │   └── test-scenario-CMI-{NN}-{slug}.md × N
│       ├── signals.json
│       ├── lane-status.json
│       └── CD41-report.md
├── phase5-aggregate/
├── phase6-regression/
├── phase7-gap-cdg/
│   ├── gap-suggestions.json         # v3 thêm kind=e2e_scenario_fix entries
│   └── gap-report.md                # v3 thêm E2E Loop-Back Suggestions section
├── phase8-report/
│   ├── integrity-report.md          # ≤55 v2 / ≤70 v3 max bound (E2E section conditional)
│   └── integrity-impact.json        # Schema integrity-impact-v3 (backward-compat v1+v2+v3)
│
├── phase9-e2e-execute/              # ★ NEW v3 ★ (chỉ nếu --exec-scenarios)
│   ├── e2e-execution-report.md
│   ├── e2e-results.json             # Schema e2e-results-v1
│   ├── lint-report.json             # Schema lint-report-v1
│   ├── lint-fixes.md                # Nếu lint FAIL/WARN
│   ├── stable-registry.json         # Schema stable-registry-v1, TTL 30d cross-session
│   ├── quarantine-report.json       # Schema quarantine-report-v1
│   ├── screenshots/
│   │   └── scenario-{NN}-{slug}-{idx}-{tactic}.png × N
│   └── Phase9-report.md
│
└── phase10-e2e-resolution/          # ★ NEW v3 ★ (chỉ nếu Phase 9 có FAIL)
    ├── resolution-report.md
    └── Phase10-report.md
```

### Đọc file gì trước?

| Mục đích | File |
|----------|------|
| **Tổng quan v3** | `phase8-report/integrity-report.md` (xem section 3.5 E2E nếu có) |
| **Review scenarios CD41 sinh ra** | `phase4-coverage/lanes/CD41-e2e-synth/scenarios-manifest.json` |
| **E2E execute kết quả** | `phase9-e2e-execute/e2e-execution-report.md` |
| **E2E failures auto-fix** | `phase10-e2e-resolution/resolution-report.md` |
| **Cross-skill artifact v3** | `phase8-report/integrity-impact.json` |
| **Screenshots evidence** | `phase9-e2e-execute/screenshots/` |
| **Quarantine review** | `phase9-e2e-execute/quarantine-report.json` |
| **Loop-back gap suggestions** | `phase7-gap-cdg/gap-suggestions.json` (filter kind=e2e_scenario_fix) |

---

## 10. Browser Unavailable Graceful

### Khi nào Phase 9-10 SKIP?

| Tình huống | Code | Action |
|------------|------|--------|
| Playwright MCP server không chạy | **E150** WARN | SKIP Phase 9-10, vẫn xuất integrity-report v3 với `e2e_execution_summary=null` |
| `--exec-scenarios=false` (default) | (silent skip by design) | KHÔNG chạy Phase 9-10, integrity-report KHÔNG có E2E section |
| scenarios-manifest.json empty (CD41 không sinh được scenarios) | **E150b** WARN | SKIP Phase 9-10, manifest sẽ ghi reason |
| FE dev server KHÔNG running (entry_url probe fail) | **E151** ERROR | SKIP Phase 9-10 với explicit error |
| browser-mcp.lock không acquire được sau 5 retries × 10s | **E152** ERROR | SKIP Phase 9-10 |

### Cách verify Playwright available

```bash
# Method 1: Check MCP server
ls ~/.claude/mcp-config.json | xargs cat | jq '.servers[] | select(.name == "playwright")'

# Method 2: Test với scenario đơn giản
/wf-cmi --profile=quick --exec-scenarios --dry-run
# --dry-run sẽ chỉ check prerequisites, không thực sự execute
```

---

## 11. `--scenarios-only` Re-Execute Flow

### Use cases hợp lệ

1. **Re-execute sau fix lỗi:**
   - Đã chạy `/wf-cmi --profile=deep --exec-scenarios`
   - Phase 9 có 2 scenarios FAIL với TEST_SELECTOR
   - Bạn manually fix selector trong scenarios/.md
   - Re-execute chỉ Phase 9-10: `/wf-cmi --scenarios-only --session-id=<id> --exec-scenarios`

2. **Chạy lại E2E sau update FE/BE:**
   - Session DONE từ tuần trước có scenarios-manifest
   - FE đã merge nhiều thay đổi
   - Re-execute để verify regression: `/wf-cmi --scenarios-only --session-id=<id> --exec-scenarios`

3. **Chạy Playwright lần đầu trên session cũ:**
   - Session v2 chạy với `/wf-cmi --profile=deep` (không có Phase 9-10)
   - Sau upgrade v3, muốn execute Playwright: `/wf-cmi --scenarios-only --session-id=<v2-id> --exec-scenarios`
   - Pipeline detect session v2 → run CD41 first (nếu chưa có manifest) → run Phase 9-10

### Pre-conditions (4 checks)

`--scenarios-only` route bypass yêu cầu:
1. Target `--session-id` exists với `integrity-status.json` valid
2. `pipeline_status` ∈ {DONE, failed_phase_9_or_10}
3. Phase 8 output `integrity-impact.json` exists
4. `scenarios-manifest.json` non-empty (`total_valid > 0`)

Thiếu 1 trong 4 → STOP với E016b high.

### Args mutex

- `--scenarios-only` requires `--session-id` (without → E016b STOP)
- `--scenarios-only` + `--resume` mutex (cannot both) → E016b STOP
- `--scenarios-only` SKIP stale check (user explicit re-execute)

---

## 12. Use Cases thực tế

### Use Case 1: Pre-release verify (EUREKA-2026)

```bash
# Trước khi merge release branch vào main:
/wf-cmi --profile=deep --since=main --exec-scenarios

# Expected:
# - 27 lanes Wave 1-2-3 + CD41 synth ~80 min
# - Phase 9 execute ~30 min (nếu ~15 scenarios)
# - Phase 10 auto-fix ~10 min (nếu có FAIL)
# - Total ~120 min

# Verify pass:
must_count=$(jq -r '.logistics_critical_signals_count.must_severity_count' \
  .mc-data/work/wf-cmi/sessions/*/phase8-report/integrity-impact.json | head -1)
e2e_fail=$(jq -r '.e2e_execution_summary.n_fail // 0' \
  .mc-data/work/wf-cmi/sessions/*/phase8-report/integrity-impact.json | head -1)
echo "MUST: $must_count, E2E FAIL: $e2e_fail"
# Acceptable: cả 2 = 0
```

### Use Case 2: Debugging single failing scenario

```bash
# Đã có session DONE, 1 scenario FAIL
# Re-execute với headed browser để xem visually

SESSION_ID=$(ls -t .mc-data/work/wf-cmi/sessions/ | head -1)

/wf-cmi --scenarios-only --session-id=$SESSION_ID --exec-scenarios --show-browser

# Browser sẽ pop-up — bạn thấy mỗi step Playwright thực hiện
# Screenshots tự động capture mỗi step
```

### Use Case 3: Mobile E2E testing

```bash
# Test mobile responsiveness (Playwright emulate iPhone 13 default)
/wf-cmi --profile=deep --exec-scenarios --mobile

# scenarios CD41 sinh ra sẽ execute với viewport mobile
# Screenshots sẽ là mobile size
```

### Use Case 4: CI nightly E2E

```yaml
# .github/workflows/wf-cmi-nightly.yml
name: WF-CMI v3 Nightly E2E
on:
  schedule:
    - cron: '0 2 * * *'  # 2am daily

jobs:
  e2e-deep:
    runs-on: ubuntu-latest-large
    timeout-minutes: 150
    steps:
      - uses: actions/checkout@v4
      - run: npx playwright install --with-deps chromium
      - run: |
          cd apps/erp-web && npm run dev &
          sleep 30
      - run: |
          /wf-cmi --ci --profile=deep --exec-scenarios --no-prompt
      - name: Upload artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: wf-cmi-nightly-report
          path: .mc-data/work/wf-cmi/sessions/*/phase8-report/
```

### Use Case 5: Auto-fix source code (high risk, dev only)

```bash
# CHỈ DÙNG TRONG LOCAL DEV — KHÔNG dùng trong CI release gate
/wf-cmi --profile=deep --exec-scenarios --auto-fix-source

# CDG E195 prompt user confirm
# Phase 10 Phase B spawn agents — agent có thể commit code
# Sau khi agent fix, scenarios re-execute để verify

# Sau khi DONE, review git diff trước commit
git diff --stat
git diff
```

---

## 13. Troubleshooting v3

### "E150: Playwright MCP server unavailable"

Playwright MCP server không chạy. Fix:

```bash
# Check MCP config
cat ~/.claude/mcp-config.json | jq '.servers[] | select(.name == "playwright")'

# Restart Claude với MCP server config
```

Workaround: bỏ `--exec-scenarios`, dùng manual:
```bash
# CD41 sinh scenarios (synth-only)
/wf-cmi --profile=deep
# Sau đó manual execute trong browser bằng cách đọc test-scenario-CMI-*.md
```

### "E150b: scenarios-manifest empty"

CD41 không sinh được scenarios. Lý do:
- Phase 5 không có violations MUST/HIGH thuộc filter dims (CD9/CD11/CD13/CD15/CD23-26/CD38/CD39)
- Profile=quick/standard (CD41 skip — cần deep/exhaustive)

Fix: Tăng profile hoặc check coverage-matrix.json xem dims có signals không.

### "E151: FE dev server not running"

Phase 9 probe `entry_url` failed. Fix:

```bash
# Start FE dev server trước khi run wf-cmi
cd apps/erp-web && npm run dev &
sleep 30  # warm up

# Verify
curl http://localhost:3000

# Re-run
/wf-cmi --scenarios-only --session-id=<id> --exec-scenarios
```

### "E152: browser-mcp.lock timeout"

Có session khác đang dùng Playwright. Wait hoặc force release:

```bash
# Check existing lock
cat $SESSION_DIR/phase9-e2e-execute/.lock-browser-mcp 2>/dev/null

# Lock age > 30 min → tự auto-release (E153 stale_lock log)
# Lock age < 30 min → wait hoặc kill session khác
```

### "E195 CDG prompt liên tục"

Pass `--no-prompt` (CI mode):
```bash
/wf-cmi --ci --profile=deep --exec-scenarios --no-prompt
```

Hoặc accept default `execute_must_only` để skip prompt 1 lần per session.

### "Phase 10 Phase B agent spawn fail"

Check:
- `--auto-fix-source` đã pass chưa
- Agent name trong `.claude/agents/` có file tương ứng không
- Context budget chưa quá 90% (CORE-038)

```bash
# Verify agents
ls .claude/agents/engineering/security.md
ls .claude/agents/engineering/developer.md
ls .claude/agents/testing/qa-lead.md
```

### "v3 fields null trong integrity-impact.json"

Mặc định nếu `--exec-scenarios=false` → `e2e_execution_summary=null` + `scenarios_artifacts=[]`. Đây là behavior đúng.

Để có populated v3 fields → pass `--exec-scenarios` và đảm bảo Phase 9 chạy thành công.

### "Consumer skill v1/v2 fail đọc v3 artifact"

KHÔNG xảy ra theo design — v3 artifact `readable_by=[v1,v2,v3]`. Nếu xảy ra → bug, mở issue.

Verify backward-compat:
```bash
# v1 fields phải accessible
jq -e '.coverage_matrix_summary, .violations, .regression_scope, .summary, .audit_chain' \
  integrity-impact.json
```

---

## 14. Migration từ v2.0

### Backward-compat 100%

✅ **Pipeline 8 phase + cách trigger `/wf-cmi` + output directory structure không thay đổi**
✅ **`--profile=deep` (không cờ v3) hoạt động identical v2 — 26 lanes + CD41 (synth-only ~1-2 min)**
✅ **Cross-skill artifact `integrity-impact.json` v3 backward-compat read v1+v2 — consumer skills KHÔNG cần update**

### Opt-in v3 features

⭐ **CD41 synth chạy ở Wave 3** mặc định với `--profile=deep|exhaustive` (~1-2 min overhead acceptable)
⭐ **Phase 9-10** chỉ chạy khi explicit pass `--exec-scenarios`
⭐ **Source-fix** chỉ chạy khi explicit pass `--auto-fix-source` + CDG E195 confirm

### Breaking changes

**KHÔNG có.** v3.0 là **ADD-ONLY** thuần túy.

### Chi tiết migration

Xem [`docs/04-skill-design/wf-cmi/v3-migration-notes.md`](../../04-skill-design/wf-cmi/v3-migration-notes.md)

---

## 15. FAQ v3

**Q: Tôi cần Playwright knowledge để dùng v3?**
A: KHÔNG bắt buộc. CD41 tự sinh scenarios + Phase 9 tự execute. Bạn chỉ cần đọc resolution-report.md tiếng Việt nếu có FAIL.

**Q: Phase 9-10 có thay thế wf-fix-bugs không?**
A: KHÔNG. wf-fix-bugs là general-purpose multi-dimensional bug fixing. Phase 10 v3 chỉ auto-fix E2E test failures (7-type cụ thể). Workflow khuyến nghị: wf-cmi v3 → phát hiện E2E issues → loop-back vào gap-suggestions → wf-fix-bugs để fix.

**Q: Auto-fix source code có an toàn không?**
A: Có risk. Agent có thể commit code unwanted. CHỈ DÙNG TRONG LOCAL DEV với git review. KHÔNG dùng trong CI release gate. CDG E195 mỗi session để user confirm.

**Q: Mất bao nhiêu tiền token cho v3 deep + --exec-scenarios?**
A: Ước tính:
- v3 deep (no --exec-scenarios): ~$2.50 (same as v2)
- v3 deep + --exec-scenarios: **~$5.00** (+$2.50 cho Phase 9-10)
- v3 deep + --exec-scenarios + --auto-fix-source: **~$8.00** (+$3.00 cho Phase B agent spawns)

**Q: Có thể chỉ chạy CD41 (skip Phase 9-10) không?**
A: Có. Pass `--profile=deep` mặc định — CD41 chạy ở Wave 3, Phase 9-10 KHÔNG chạy (chưa pass `--exec-scenarios`). Sau đó review scenarios manual nếu muốn.

**Q: scenarios-manifest.json có deterministic không?**
A: Phần lớn deterministic — cùng input (violations + workflow-graph) sinh cùng scenarios. Nhưng confidence scoring có thể vary nhẹ giữa runs (LLM call cho enrichment).

**Q: Có thể chỉ test 1 module không?**
A: Có. Combine `--scope=module=<name>` với `--exec-scenarios`. CD41 sẽ sinh scenarios chỉ cho violations trong module đó.

```bash
/wf-cmi --profile=deep --scope=module=finance --exec-scenarios
```

**Q: Stable-registry là gì?**
A: Cache cross-session lưu scenarios đã PASS stable (5/5 pre-flight). TTL 30 ngày. Lần chạy tiếp theo, scenarios cùng nội dung (sha256 hash) sẽ SKIP 5x flakiness check → tiết kiệm ~5-10 min per scenario.

**Q: --strict-evidence khác gì default 80%?**
A: Default 80% — chỉ ≥80% steps có screenshot/console/network capture là PASS. `--strict-evidence` yêu cầu 100% — mọi step phải có evidence đầy đủ. Khuyến nghị cho high-stakes release gate.

**Q: Mobile testing thật sự test mobile app không?**
A: KHÔNG — `--mobile` emulate viewport mobile (iPhone 13 default Playwright) cho responsive web testing. Để test mobile native app, cần riêng tool khác (Appium, Detox).

**Q: Loop-back vào gap-suggestions có làm tăng pipeline không?**
A: KHÔNG — loop-back chỉ APPEND `kind="e2e_scenario_fix"` vào gap-suggestions hiện tại, KHÔNG re-trigger CD41 hoặc Phase 4 (anti-loop guard 4 rules). Phase 8 tự động consume v3 fields populate integrity-report E2E section.

---

## Liên kết

- Skills catalog: [`docs/01-architecture/07-skills-catalog.md`](../../01-architecture/07-skills-catalog.md)
- Execution profiles canon: [`docs/04-skill-design/wf-cmi/05-execution-profiles.md`](../../04-skill-design/wf-cmi/05-execution-profiles.md)
- Migration notes v2→v3: [`docs/04-skill-design/wf-cmi/v3-migration-notes.md`](../../04-skill-design/wf-cmi/v3-migration-notes.md)
- Architecture deep-dive: [`docs/04-skill-design/wf-cmi/12-e2e-engine-arch.md`](../../04-skill-design/wf-cmi/12-e2e-engine-arch.md)
- User guide v2 (reference): [`docs/06-user-guides/per-skill/wf-cmi-v2-guide.md`](wf-cmi-v2-guide.md)
- SKILL.md: [`.claude/skills/workflow/wf-cmi/SKILL.md`](../../../.claude/skills/workflow/wf-cmi/SKILL.md)
- _contract.json: [`.claude/skills/workflow/wf-cmi/_contract.json`](../../../.claude/skills/workflow/wf-cmi/_contract.json)
- CHANGELOG v3.0.0: [`CHANGELOG.md`](../../../CHANGELOG.md#wf-cmi-v300--2026-05-17)
