# wf-cmi v2 → v3 Migration Notes

> **Phiên bản v3.0.0** · **Ngày phát hành:** 2026-05-17 · **Khả năng tương thích ngược:** ✅ **100% ADD-ONLY** (zero breaking change)
>
> Hướng dẫn migration cho skill maintainers, consumer skill owners, CI/CD operators, và QA testers khi nâng cấp wf-cmi từ v2.0.0 (26 lanes Gói C++ Logistics) → v3.0.0 (26 + lane CD41 E2E Synth + Phase 9-10 E2E Execute/Resolution).

---

## 1. Tóm tắt thay đổi v2 → v3

| Aspect | v2.0 | v3.0 | Breaking? |
|--------|------|------|-----------|
| Số lanes active (deep profile) | 26 (CD1-7, CD9, CD11, CD13, CD15-18, CD23-26, CD28-31, CD37-40) | **27** (26 v2 + **CD41 NEW** Wave 3) | ✅ ADD-ONLY |
| Graphs Phase 2 | 13 (6 core + 7 plugin) | 13 (không đổi) | — |
| Pipeline phases | 8 (Init → Discovery → Invariant → Coverage Dispatch → Aggregate → Regression → GAP+CDG → Report) | 8 v2 + **2 v3 opt-in** (Phase 9 E2E Execute + Phase 10 E2E Resolution) | ✅ ADD-ONLY (opt-in `--exec-scenarios`) |
| Coverage matrix dims | 35 (26 active + 9 SKIPPED) | **36** (35 + CD41) | ⚠ Schema bump v2→v3 (backward-compat) |
| Cross-skill artifact | `integrity-impact-v2` | **`integrity-impact-v3`** với 2 v3 fields mới | ✅ Backward-compat (`readable_by=[v1,v2,v3]`) |
| Profile=deep duration (no --exec-scenarios) | ~55-90 min | ~55-90 min (không đổi — CD41 synth pure artifact, ~1-2 min) | ✅ Identical default |
| Profile=deep duration (với --exec-scenarios) | N/A | **~65-120 min** (+10-30 min cho Phase 9-10) | New feature opt-in |
| Cờ CLI mới | 0 | **7 cờ v3**: `--exec-scenarios`, `--scenarios-only`, `--show-browser`, `--mobile`, `--strict-evidence`, `--no-prompt`, `--auto-fix-source` | ✅ ADD-ONLY (default OFF) |
| CDG mới | 0 | **2 CDG v3**: E195 (source-fix confirm) + E195b (subset E2E execute confirm) | ✅ ADD-ONLY (silent default execute_must_only) |
| Error codes new range | E110-E149 | **E150-E199 v3** (Phase 9-10 + CD41 + E016b + E195/E195b) | Forward-compat |
| SKILL.md size | 487 dòng | **497 dòng** (≤500 HARD GATE) | ✅ CORE-032 preserved (sau Stage 7 refactor) |
| Procedure files | 29 | **35** (29 v2 + 6 v3: phase9-e2e-execute, phase10-e2e-resolution, _e2e-runner, _failure-analyzer, _screenshot-evidence, _error-quick-lookup, lanes/CD41) | ✅ ADD-ONLY |
| Output files (outputs.working[]) | 47 | **57** (47 v2 + 10 v3 Phase 9-10) | ✅ ADD-ONLY |
| Templates | 32 | **41** (32 v2 + 9 NEW v3 + 4 UPDATE) | ✅ ADD-ONLY + backward-compat UPDATE |
| Helper scripts | 1 (`wave-coordinator.sh`) | **8** (1 v2 + 7 v3: lint-scenario, detect-modified-scenarios, e2e-pre-flight-check, browser-lock + 3 test scripts + browser-unavailable-smoke) | ✅ ADD-ONLY |
| Eval test cases | 13 (5 v1 + 8 v2) | **18** (13 + **5 v3 TC-cmi-014→018**) | ✅ ADD-ONLY |
| Required SSOTs mới | 9 (v2) | 9 (không đổi — CD41 + Phase 9-10 dùng output của Phase 2-7) | ✅ Không yêu cầu populate mới |

---

## 2. Quyết định kiến trúc chính (chốt với user 2026-05-16)

### 2.1 Scope tích hợp: Full (toàn bộ 9 capability của wf-e2e-scenario)

**Quyết định:** Port toàn bộ 9 capability tinh túy từ `wf-e2e-scenario` vào `wf-cmi` v3, KHÔNG cắt bớt.

| # | Capability nguồn | File đích v3 |
|---|------------------|--------------|
| 1 | test-scenario template (14-field CMI metadata) | `wf-cmi/templates/test-scenario.template.md` |
| 2 | Scenario Runner Engine | `wf-cmi/procedures/_e2e-runner.md` |
| 3 | Step pattern recognition (5 patterns + tiếng Việt aliases) | `_e2e-runner.md` §Step Execution |
| 4 | Expected result verification (4 modes element/text/URL/network) | `_e2e-runner.md` §Expected Result |
| 5 | Screenshot evidence | `wf-cmi/procedures/_screenshot-evidence.md` |
| 6 | Failure analyzer 7-type | `wf-cmi/procedures/_failure-analyzer.md` |
| 7 | Quality gates G1.1-G1.5 (lint, 5x, stable-registry, quarantine) | `phase9-e2e-execute.md` + `scripts/wf-cmi-e2e/` |
| 8 | Cross-module scenarios | `_e2e-runner.md` §Cross-Module |
| 9 | Browser-mcp.lock concurrency | `_shared.md` §Browser Lock Pattern (UPDATE) |

**Rationale:**
- Tránh duplicate maintenance (1 nguồn truth thay vì 2)
- Kế thừa context dày từ wf-cmi Phase 2-3 (13 graphs + invariants) — CD41 sinh scenarios chính xác hơn `wf-e2e-finding` F0a output 8 file
- Loop-back từ Phase 10 vào gap-suggestions tự nhiên (cùng skill, cùng session) — wf-e2e-scenario phải cross-skill

**Tradeoff:** Lùi DEPRECATE 10 wf-e2e-* skills sang Stage 10 (sau v3.0 ship 2 sprint stable).

### 2.2 Mặc định execute Playwright? KHÔNG

**Quyết định:** Phase 9 (E2E Execute) chỉ chạy khi user explicit pass `--exec-scenarios`. CD41 synth (Phase 4 Wave 3) chạy mặc định với profile=deep|exhaustive nhưng KHÔNG execute Playwright.

**Rationale:**
- An toàn cho user v2.0 hiện tại — profile=deep tiếp tục ~55-90 min, không tăng thời gian
- CD41 synth pure artifact (~1-2 min) — đầu ra `scenarios-manifest.json` + `test-scenario-CMI-{NN}-{slug}.md × N`, KHÔNG yêu cầu Playwright runtime
- Phase 9 opt-in cho phép user kiểm soát chi phí Playwright (browser + token)

**Tradeoff:** User muốn full E2E phải explicit `--exec-scenarios`. Documented rõ trong user guide §3 "Quick Start".

### 2.3 Trigger auto-run: deep/exhaustive auto, quick/standard CDG

**Quyết định:**
- `--exec-scenarios` + `profile=deep|exhaustive` → auto chạy hết (không hỏi)
- `--exec-scenarios` + `profile=quick|standard` → CDG E195b AskUserQuestion 3 options:
  - **Execute all** (CD41 force-activate MUST+HIGH violations)
  - **Execute MUST-only** (CD41 subset chỉ MUST — **Recommended** default)
  - **Cancel** (SKIP Phase 9-10, vẫn xuất Phase 8 report v3 với `e2e_execution_summary=null`)
- `--no-prompt` (CI mode) → silent default = **Execute MUST-only** (balanced safety)

**Rationale:**
- Smart default theo profile — deep/exhaustive đã cam kết toàn diện, không cần hỏi thêm
- quick/standard prompt user vì có thể họ chỉ muốn synth scenarios để review, KHÔNG execute
- CI mode (--no-prompt) chọn MUST-only an toàn — KHÔNG over-execute trong pipeline tự động

**Tradeoff:** Thêm 1 prompt point cho user khi quick/standard + --exec-scenarios. UX acceptable vì đây là decision điểm hợp lý.

### 2.4 Browser unavailable: SKIP graceful

**Quyết định:** Playwright MCP server không có → SKIP Phase 9-10 với E150 WARN, vẫn xuất `integrity-report.md` + `integrity-impact.json` v3 bình thường (`e2e_execution_summary=null`).

**Rationale:**
- Graceful degradation (CORE-033) — user vẫn nhận được integrity report v2 logic, không bị block
- Phase 8 v3 conditional render: E2E section chỉ xuất hiện nếu `PHASE_9_RAN=true` (POST-GATE T5)
- Consumer skills (v1/v2/v3 readers) đọc `integrity-impact.json` v3 với `e2e_execution_summary=null` graceful

**Tradeoff:** User mất feature E2E execute. Nhưng đây là decision phù hợp — không phải fault của wf-cmi, không nên block toàn bộ pipeline.

### 2.5 wf-e2e-scenario lifecycle: DEPRECATE sau v3.0 ship 2 sprint stable

**Quyết định:** Stage 10 (sau v3.0 ship 2 sprint stable trên EUREKA-2026):
- DEPRECATE 10 skills `wf-e2e-*` (scenario, finding, test, verify, batch, fix, implement, retest, unblock) + decide case-by-case 2 skills (browser, demo)
- GIỮ standalone `wf-e2e-credentials` (credential vault không thuộc CMI scope, opt-in)

**Rationale:**
- Tránh duplicate logic — sau khi v3.0 stable proven trên EUREKA, không cần maintain 2 stack E2E
- 2 sprint stable buffer cho user migration + bug fix discovery

**Tradeoff:** Backward-compat user dùng `wf-e2e-*` legacy phải migrate trong 2 sprint window.

---

## 3. Migration cho Consumer Skills

### 3.1 Detect $schema field v3

Consumer skills (wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment, wf-design, wf-add-scope) khi đọc `integrity-impact.json` PHẢI detect schema version:

```bash
# Cách v1 (path-based) — vẫn hoạt động với v3 artifact:
overall_pct=$(jq -r '.coverage_matrix_summary.overall_pct' integrity-impact.json)

# Cách v2 (schema-aware) — đã handle v1+v2:
schema=$(jq -r '.$schema' integrity-impact.json)
case "$schema" in
  integrity-impact-v1) echo "v1 artifact" ;;
  integrity-impact-v2)
    must_count=$(jq -r '.logistics_critical_signals_count.must_severity_count' integrity-impact.json)
    ;;
  integrity-impact-v3)
    echo "v3 artifact — v2 logic still works"
    # Có thể access v3 extras nếu muốn opt-in
    if [[ "$(jq -r '.e2e_execution_summary' integrity-impact.json)" != "null" ]]; then
      e2e_pass_rate=$(jq -r '.e2e_execution_summary.n_pass / .e2e_execution_summary.n_exec' \
                       integrity-impact.json)
      e2e_quarantine_count=$(jq -r '.e2e_execution_summary.n_quarantined' integrity-impact.json)
      echo "E2E pass rate: $e2e_pass_rate, quarantined: $e2e_quarantine_count"
    fi
    ;;
  *) echo "Unknown schema $schema, fallback v1 logic" ;;
esac
```

### 3.2 Recommended consumer actions (v3 extras)

| Consumer | v3 extra để consume | Logic mới |
|----------|--------------------|-----------|
| `wf-prepare-deployment` | `e2e_execution_summary.n_fail` + `n_quarantined` | BLOCK release nếu `n_fail > 0` HOẶC `n_quarantined > 2` |
| `wf-prepare-deployment` | `scenarios_artifacts[?(@.cross_module == true && @.execution_status == 'FAIL')]` | BLOCK release nếu cross-module scenario FAIL |
| `wf-fix-bugs` | `scenarios_artifacts[?(@.execution_status == 'AUTO_CORRECTED')]` | Priority verify regression (auto-fix có thể che dấu bug thật) |
| `wf-fix-bugs` | `e2e_execution_summary.top_failure_types[]` | Suggest dim QD tương ứng cho triage (UI_BUG → QD5, AUTH → QD3, NETWORK → QD8) |
| `wf-implement-feature` | `gap_artifacts_suggested[?(@.kind == 'e2e_scenario_fix')]` | Tạo regression test khi implement (loop-back từ Phase 10) |
| `wf-verify-sync` | `scenarios_artifacts[].source_violation_ids[]` | Sync REQ-ID coverage với scenario synthesized |
| `wf-design` | `e2e_execution_summary.n_synth` | Awareness: design phải cover cross-module scenarios CD41 đã synth |

### 3.3 Backward-compat verify

```bash
# Test v1 reader có đọc được v3 artifact không
echo "=== v1 backward-compat check ==="
for field in coverage_matrix_summary violations regression_scope \
             gap_artifacts_suggested consumers_recommended_actions \
             summary audit_chain; do
  jq -e ".${field}" integrity-impact.json > /dev/null && \
    echo "✓ v1 field $field accessible" || \
    echo "✗ MISSING v1 field $field"
done

# Test v2 reader có đọc được v3 artifact không
echo "=== v2 backward-compat check ==="
for field in lanes_v2 wave_breakdown group_breakdown \
             logistics_critical_signals_count schema_version_compat; do
  jq -e ".${field}" integrity-impact.json > /dev/null && \
    echo "✓ v2 field $field accessible" || \
    echo "✗ MISSING v2 field $field"
done

# Verify v3 fields present (chỉ nếu --exec-scenarios bật)
echo "=== v3 fields check ==="
for field in e2e_execution_summary scenarios_artifacts schema_version_compat.readable_by; do
  jq -e ".${field}" integrity-impact.json > /dev/null && \
    echo "✓ v3 field $field accessible" || \
    echo "✗ MISSING v3 field $field"
done
```

Nếu tất cả PASS → consumer v1/v2/v3 logic hoạt động bình thường với v3 artifact.

---

## 4. Migration cho CI/CD Operators

### 4.1 Timeout adjustment

| CI mode | v2 timeout | v3 timeout đề xuất (no --exec-scenarios) | v3 timeout đề xuất (với --exec-scenarios) |
|---------|-------------|-------------|-------------|
| `--ci --profile=quick` | 15 min | 15 min (không đổi) | 25 min (+10 min subset Phase 9-10) |
| `--ci --profile=standard` | 60 min | 60 min (không đổi) | 75 min (+15 min subset Phase 9-10) |
| `--ci --profile=deep` | 120 min | 120 min (+CD41 ~2 min) | **150 min** (+30 min Phase 9-10 full) |
| `--ci --profile=exhaustive` | 300 min | 305 min (+CD41 ~5 min) | **360 min** (+60 min Phase 9-10 deep) |

### 4.2 GitHub Actions example v3

```yaml
name: WF-CMI v3 Release Gate
on:
  pull_request:
    branches: [main]

jobs:
  cmi-deep:
    runs-on: ubuntu-latest-large  # cần RAM ≥16GB cho 26 lanes parallel + Playwright
    timeout-minutes: 150  # v3 deep với --exec-scenarios ~120 min worst case
    steps:
      - uses: actions/checkout@v4

      - name: Populate SSOTs from secrets
        run: |
          # Copy 7 mandatory SSOTs (xem v2-migration-notes §4.1)
          cp ${{ secrets.SSOT_STORAGE }}/*.json .mc-data/docs/_meta/

      - name: Install Playwright (cho --exec-scenarios)
        run: npx playwright install --with-deps chromium

      - name: Start FE dev server (cho Phase 9 entry_url probe)
        run: |
          cd apps/erp-web && npm run dev &
          sleep 30  # warm up

      - name: Run wf-cmi v3 deep + E2E
        run: |
          /wf-cmi --ci --profile=deep --since=${{ github.event.pull_request.base.sha }} \
                  --exec-scenarios --no-prompt
          # --ci + --exec-scenarios auto-set --no-prompt=true (E100 WARN OK)
          # CDG E195b silent default = execute_must_only

      - name: Block release if MUST violations OR E2E FAIL
        run: |
          IMPACT=.mc-data/work/wf-cmi/sessions/*/phase8-report/integrity-impact.json
          must_count=$(jq -r '.logistics_critical_signals_count.must_severity_count' $IMPACT | head -1)
          e2e_fail=$(jq -r '.e2e_execution_summary.n_fail // 0' $IMPACT | head -1)
          e2e_quarantine=$(jq -r '.e2e_execution_summary.n_quarantined // 0' $IMPACT | head -1)
          if [ "$must_count" -gt 0 ] || [ "$e2e_fail" -gt 0 ] || [ "$e2e_quarantine" -gt 2 ]; then
            echo "BLOCK: MUST=$must_count, E2E_FAIL=$e2e_fail, QUARANTINE=$e2e_quarantine"
            exit 1
          fi
```

### 4.3 Profile downgrade khi CI timeout

`--ci` mode tự động auto-downgrade nếu detect timeout sắp tới:

| Original profile + flags | Auto-downgrade khi `--ci` + timeout < threshold |
|---------------------------|-----------------------------------------------|
| `deep --exec-scenarios` | timeout < 90 min → drop `--exec-scenarios` (CDG E108 WARN), giữ deep 27 lanes |
| `exhaustive --exec-scenarios` | timeout < 180 min → drop `--exec-scenarios`, giữ exhaustive 36 lanes |
| `deep` (no --exec-scenarios) | timeout < 60 min → downgrade `standard` (CDG E108 WARN) |
| `exhaustive` | timeout < 120 min → ERROR E012 (chạy local) |

### 4.4 CI mode flag combinations

```bash
# v3 CI release gate (recommended)
/wf-cmi --ci --profile=deep --since=main --exec-scenarios
# Auto-set --no-prompt=true (E100 WARN)
# Phase 9-10 chạy với CDG E195b silent default = execute_must_only
# Phase 10 Phase B source-fix SKIP (cần --auto-fix-source explicit)

# v3 CI nightly (no E2E execute, chỉ synth)
/wf-cmi --ci --profile=deep
# CD41 synth chạy mặc định (deep), Phase 9-10 SKIP
# integrity-report.md có scenarios manifest, e2e_execution_summary=null

# v3 CI security gate (--auto-fix-source CI auto-confirmed)
/wf-cmi --ci --profile=deep --exec-scenarios --auto-fix-source
# --no-prompt + --auto-fix-source → CDG E195 auto-confirmed (E101 LOG warn)
# Phase 10 Phase B spawn agents
# RISK: agent có thể commit code unwanted → KHÔNG khuyến nghị cho release CI
```

---

## 5. Migration cho User CLI

### 5.1 Quy trình lần đầu chạy v3.0

```bash
# Step 1: Verify SKILL.md là v3.0
jq -r '.version' .claude/skills/workflow/wf-cmi/_contract.json
# Expected: 3.0.0

# Step 2: Run identical v2 (backward-compat verify)
/wf-cmi --profile=standard --scope=module=crm
# Expected: hoạt động identical v2 — quick/standard không trigger CD41 hay Phase 9-10

# Step 3: Try v3 feature CD41 synth (no execute)
/wf-cmi --profile=deep
# CD41 synth chạy ở Wave 3, sinh scenarios-manifest.json + test-scenario-CMI-*.md
# Phase 9-10 KHÔNG chạy (chưa pass --exec-scenarios)

# Step 4: Try full v3 E2E execute (requires Playwright)
/wf-cmi --profile=deep --exec-scenarios
# Phase 9 execute scenarios + Phase 10 resolution nếu có FAIL
# Browser unavailable → SKIP Phase 9-10 với E150 graceful, vẫn xuất integrity-report

# Step 5: Re-execute Phase 9-10 trên session đã có scenarios
/wf-cmi --scenarios-only --session-id=<previous-deep-session-id> --exec-scenarios
# Bypass Phase 1-8, chỉ chạy Phase 9-10 trên session DONE đã có manifest
```

### 5.2 Resume v2 session sau upgrade

Nếu có session v2 đang dở dang (interrupted) khi upgrade lên v3.0:

```bash
/wf-cmi --resume --session-id=<v2-session-id>
```

Pipeline v3.0 sẽ:
1. Detect session schema=v2 → hoàn tất Phase 1-8 với v2 logic (KHÔNG retroactive add CD41 hoặc Phase 9-10)
2. Phase 8 sẽ xuất `integrity-impact.json` v3 schema với `e2e_execution_summary=null` (v2 session không có E2E artifacts)
3. v1/v2/v3 consumers đọc OK

### 5.3 Profile mapping (v2 → v3)

| v2 command | v3 equivalent | Note |
|-------------|----------------|------|
| `/wf-cmi --profile=quick` | `/wf-cmi --profile=quick` | Identical — 7 lanes Wave 1 |
| `/wf-cmi --profile=standard` | `/wf-cmi --profile=standard` | Identical — 13 lanes W1+2+3 subset |
| `/wf-cmi --profile=deep` | `/wf-cmi --profile=deep` | **27 lanes** (26 v2 + CD41 synth), +1-2 min thời gian |
| `/wf-cmi --profile=exhaustive` | `/wf-cmi --profile=exhaustive` | **36 lanes** (35 v2 + CD41 + LLM enhance) |
| (v2 không có) | `/wf-cmi --profile=deep --exec-scenarios` | NEW — full v3 E2E execute (~65-120 min) |
| (v2 không có) | `/wf-cmi --scenarios-only --session-id=<id> --exec-scenarios` | NEW — re-execute E2E trên session DONE |

### 5.4 Args mutual exclusion v3 (8 combinations cần biết)

| Combination | Behavior | Error/Warn code |
|-------------|----------|------------------|
| `--scenarios-only` thiếu `--session-id` | STOP | E016b high |
| `--scenarios-only` + `--resume` | STOP (mutex) | E016b high |
| `--strict-evidence` không có `--exec-scenarios` | WARN, ignore flag | E101 |
| `--show-browser` không có `--exec-scenarios` | WARN, ignore flag | E101 |
| `--mobile` không có `--exec-scenarios` | WARN, ignore flag | E101 |
| `--no-prompt` + `--auto-fix-source` | WARN + LOG (CDG E195 auto-confirmed) | E101 |
| `--auto-fix-source` không có `--exec-scenarios` | WARN, no-op | E101 |
| `--ci` + `--exec-scenarios` không có `--no-prompt` | WARN + auto-set `--no-prompt=true` | E100 |

---

## 6. Migration cho QA / Stakeholder (E2E Scenarios)

### 6.1 Review scenarios CD41 sinh ra

Sau khi pipeline chạy `/wf-cmi --profile=deep`, mở:

```bash
# Manifest tổng quan
cat .mc-data/work/wf-cmi/sessions/*/phase4-coverage/lanes/CD41-e2e-synth/scenarios-manifest.json
# Xem: total_synthesized, total_valid, total_skipped_low_confidence, total_cross_module

# Per-scenario detail
ls .mc-data/work/wf-cmi/sessions/*/phase4-coverage/lanes/CD41-e2e-synth/scenarios/
# Tên format: test-scenario-CMI-{NN}-{slug}.md (vd: test-scenario-CMI-01-create-invoice-cross-module.md)
```

Mỗi scenario có frontmatter YAML 14 fields CMI metadata:
- `scenario_id`, `generated_by`, `session_id`, `source_violation_id`, `source_invariant_id`, `source_dim`
- `severity` (MUST|HIGH), `scenario_type` (cross-module|module|UI|business)
- `modules_involved[]`, `cross_module` (bool), `confidence` (0.0-1.0)
- `entry_url`, `actor`, `mode` (default headless)

Body có bảng 5 cột: **Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail**.

### 6.2 Decide execute scenarios không?

- **YES, execute now:** `/wf-cmi --scenarios-only --session-id=<id> --exec-scenarios`
- **YES, execute với headed browser (debugging):** `/wf-cmi --scenarios-only --session-id=<id> --exec-scenarios --show-browser`
- **YES, mobile testing:** `/wf-cmi --scenarios-only --session-id=<id> --exec-scenarios --mobile`
- **NO, chỉ review manual:** Đọc file `test-scenario-CMI-*.md` trong scenarios/ subdirectory

### 6.3 Đọc resolution report sau Phase 10

```bash
cat .mc-data/work/wf-cmi/sessions/*/phase10-e2e-resolution/resolution-report.md
```

6 sections:
1. **Tổng quan** — Total FAIL + Phase A/B outcomes
2. **Failure classification matrix** — 7-type breakdown (AUTH/NETWORK/DATA_MISSING/TEST_SELECTOR/UI_BUG/BUSINESS_RULE/UNKNOWN)
3. **Per-failure resolution** — Mỗi FAIL có Phase A attempt + Phase B (nếu --auto-fix-source) + outcome
4. **Auto-fix outcomes** — AUTO_CORRECTED (Phase A success) / PASS_PHASE_B (source fix) / UNRESOLVED / SKIP
5. **Loop-back suggestions** — Số `e2e_scenario_fix` đã APPEND vào gap-suggestions
6. **Phase Summary** — Tiếng Việt ≤15 dòng

---

## 7. Known limitations v3.0

| Aspect | Limitation | Workaround | Plan |
|--------|------------|------------|------|
| CD41 synth filter dims fixed | Chỉ dims CD9/CD11/CD13/CD15/CD23-26/CD38/CD39 sinh scenarios | Manual edit `procedures/lanes/CD41.md` §C.2 nếu cần thêm | v3.1 — config-driven filter từ `_contract.json` |
| Phase 9 single Playwright MCP session | Browser-mcp.lock per-session (max 1 Phase 9 cùng lúc) | Multi-session parallel safe nhưng Phase 9 sequential (Protocol 22) | v3.1 — pool browser-mcp instances |
| Phase 10 Phase B max concurrency 3 agents | Hạn chế để tránh context budget overflow | Chấp nhận tradeoff (CORE-038) | v3.1 — adaptive concurrency dựa context budget |
| Stable-registry TTL 30 ngày fixed | Không config được per-session | TTL default consistent — wf-e2e-scenario cùng config | v3.1 — config-driven TTL |
| Failure analyzer 7-type fixed | Mở rộng cần edit `_failure-analyzer.md` §C | Đủ cover 95% common failures | v3.1 — plugin failure type system |
| 5x flakiness deterministic stub trong test | Chưa test real 5x Playwright execute | Stage 4 stub testable, Stage 10 EUREKA real test sẽ verify | Stage 10 |
| Loop-back gap-suggestions max 1 iteration | Anti-loop guard không cho re-trigger CD41 cùng session | Safe — tránh infinite loop | Acceptable design |

---

## 8. v3.1 Roadmap (preview, không commit)

| Feature | Lý do | Effort |
|---------|-------|--------|
| Config-driven CD41 filter dims | User custom dim selection | 2 ngày |
| Pool browser-mcp instances | Phase 9 parallel multi-session | 4-5 ngày |
| Adaptive Phase 10 Phase B concurrency | Auto-scale theo context budget | 3 ngày |
| Plugin failure type system | Mở rộng 7-type → 10+ với custom heuristics | 5-7 ngày |
| LLM-based failure root cause analysis | Phase 10 thêm Pass C: LLM enhance failure analyzer | 4-5 ngày |
| Real EUREKA-2026 Stage 10 integration | Smoke test full pipeline real Playwright | 5-7 ngày |
| wf-e2e-* DEPRECATE migration | Migration 10 skills sang wf-cmi v3 | 3-5 ngày |

---

## 9. Liên kết

- CHANGELOG v3.0.0: [`CHANGELOG.md`](../../../CHANGELOG.md#wf-cmi-v300--2026-05-17)
- v2 migration notes (reference): [`docs/04-skill-design/wf-cmi/v2-migration-notes.md`](v2-migration-notes.md)
- E2E engine architecture deep-dive: [`docs/04-skill-design/wf-cmi/12-e2e-engine-arch.md`](12-e2e-engine-arch.md)
- User guide v3: [`docs/06-user-guides/per-skill/wf-cmi-v3-guide.md`](../../06-user-guides/per-skill/wf-cmi-v3-guide.md)
- Execution profiles canon: [`docs/04-skill-design/wf-cmi/05-execution-profiles.md`](05-execution-profiles.md)
- Architecture canon: [`docs/04-skill-design/wf-cmi/03-architecture.md`](03-architecture.md)
- Tradeoffs ADR: [`docs/04-skill-design/wf-cmi/08-tradeoffs-adr.md`](08-tradeoffs-adr.md)
- SKILL.md: [`.claude/skills/workflow/wf-cmi/SKILL.md`](../../../.claude/skills/workflow/wf-cmi/SKILL.md)
- _contract.json: [`.claude/skills/workflow/wf-cmi/_contract.json`](../../../.claude/skills/workflow/wf-cmi/_contract.json)
- CD41 lane procedure: [`.claude/skills/workflow/wf-cmi/procedures/lanes/CD41.md`](../../../.claude/skills/workflow/wf-cmi/procedures/lanes/CD41.md)
- Phase 9 procedure: [`.claude/skills/workflow/wf-cmi/procedures/phase9-e2e-execute.md`](../../../.claude/skills/workflow/wf-cmi/procedures/phase9-e2e-execute.md)
- Phase 10 procedure: [`.claude/skills/workflow/wf-cmi/procedures/phase10-e2e-resolution.md`](../../../.claude/skills/workflow/wf-cmi/procedures/phase10-e2e-resolution.md)
- E2E runner engine: [`.claude/skills/workflow/wf-cmi/procedures/_e2e-runner.md`](../../../.claude/skills/workflow/wf-cmi/procedures/_e2e-runner.md)
- Failure analyzer engine: [`.claude/skills/workflow/wf-cmi/procedures/_failure-analyzer.md`](../../../.claude/skills/workflow/wf-cmi/procedures/_failure-analyzer.md)
- Screenshot evidence: [`.claude/skills/workflow/wf-cmi/procedures/_screenshot-evidence.md`](../../../.claude/skills/workflow/wf-cmi/procedures/_screenshot-evidence.md)
- Error quick lookup: [`.claude/skills/workflow/wf-cmi/procedures/_error-quick-lookup.md`](../../../.claude/skills/workflow/wf-cmi/procedures/_error-quick-lookup.md)
- Helper scripts: [`.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/`](../../../.claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/)
- Progress tracker: [`plans/wf-cmi/progress-scenario.md`](../../../plans/wf-cmi/progress-scenario.md)
- Integration plan (Spec): [`plans/wf-cmi/v3.0-e2e-integration-plan.md`](../../../plans/wf-cmi/v3.0-e2e-integration-plan.md)

---

## 10. Hỗ trợ

Vấn đề khi migrate v2 → v3? Check:

1. **Backward-compat issue:** Run `jq '.$schema' integrity-impact.json` — phải là `integrity-impact-v3`, `readable_by` chứa `["v1","v2","v3"]`. Nếu thiếu → bug, mở issue.
2. **Phase 9 KHÔNG chạy mặc dù pass `--exec-scenarios`:** Check `Phase9-report.md`. Nếu STATUS=SKIPPED với reason "Playwright MCP DOWN" hoặc "FE not running" → fix prerequisite. Reason "manifest empty" → check CD41 đã chạy chưa (profile=deep|exhaustive required).
3. **Phase 10 spawn agent FAIL:** Check `--auto-fix-source` đã pass chưa. Check `agent-name` trong `resolution-report.md` §3 Per-failure. Check `.claude/agents/` có file tương ứng không.
4. **CI mode `--ci --exec-scenarios` timeout:** Tăng timeout từ 120 min → 150 min (deep) hoặc 180 min (exhaustive). Hoặc drop `--exec-scenarios` để chỉ run v2 logic.
5. **CDG E195b prompt liên tục:** Pass `--no-prompt` (CI mode) hoặc chọn `Execute MUST-only` (Recommended) để skip prompt 1 lần per session.
6. Troubleshooting section trong [user guide v3](../../06-user-guides/per-skill/wf-cmi-v3-guide.md#13-troubleshooting)
7. Error code reference (v3): [`procedures/_error-quick-lookup.md`](../../../.claude/skills/workflow/wf-cmi/procedures/_error-quick-lookup.md)
8. Open issue tại repo MCV3 với label `wf-cmi-v3-migration`
