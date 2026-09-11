# Engine — Screenshot Evidence (v3.0)

> **Stage 4 implemented (2026-05-16)** — port từ `wf-e2e-scenario/procedures/screenshot-evidence.md`, đổi paths sang wf-cmi session subdirectory.
>
> **Lazy-loaded by:** `procedures/phase9-e2e-execute.md` (Step 9.5 login + Step 9.6.e per scenario) + `procedures/_e2e-runner.md`
> **Source reference:** `.claude/skills/workflow/wf-e2e-scenario/procedures/screenshot-evidence.md`

---

## A. Mục đích

Quản lý screenshot evidence convention cho Phase 9 E2E execute:

1. **File naming convention** — nhất quán per scenario / step / cross-module
2. **Timing capture** — sau login, sau mỗi step, sau scenario, on FAIL
3. **Console + network capture** song song với screenshot
4. **`--strict-evidence` validation** — block partial nếu thiếu evidence
5. **Cleanup policy** — giữ PASS/FAIL/AUTO_CORRECTED, quarantine vào sub-dir

---

## B. File Naming Convention

```
$SESSION_DIR/phase9-e2e-execute/screenshots/
├── login-result.png                                  # Step 9.5 sau khi login
├── scenario-{NN}-{slug}.png                          # Final state per scenario (PASS hoặc FAIL)
├── scenario-{NN}-{slug}-step-{idx}.png               # Per-step (CHỈ on FAIL hoặc --strict-evidence)
├── scenario-{NN}-{slug}-upstream-{module}.png        # Cross-module upstream page
├── scenario-{NN}-{slug}-downstream-{module}.png      # Cross-module downstream page
├── scenario-{NN}-{slug}-failed.png                   # State khi exit FAIL (luôn capture nếu FAIL)
├── scenario-{NN}-{slug}-prefix-{tactic}.png          # Phase 10 pre-fix evidence
└── scenario-{NN}-{slug}-postfix-{tactic}.png         # Phase 10 post-fix evidence

$SESSION_DIR/phase9-e2e-execute/evidence/             # Parallel evidence (text/JSON)
├── scenario-{NN}-{slug}-console.log                  # Console messages dump
├── scenario-{NN}-{slug}-network.json                 # Network requests filtered (4xx/5xx)
└── scenario-{NN}-{slug}-dom.html                     # DOM snapshot (chỉ on FAIL)
```

### Tham số

| Var | Description | Example |
|-----|-------------|---------|
| `{NN}` | 2-digit scenario index (1-padded) | `01`, `02`, `12`, `99` |
| `{slug}` | kebab-case từ scenario heading | `tao-customer-must-fail`, `validation-duplicate-email` |
| `{module}` | Module name (lowercase) | `crm`, `orders`, `finance`, `tms` |
| `{idx}` | Step index (1-padded nếu ≥10 cho sort) | `1`, `2`, `12` |
| `{tactic}` | Phase 10 fix tactic name | `selector_fallback`, `re_login`, `page_reload`, `agent_fix_qa_lead` |

### Slug Generation

```bash
make_slug() {
  local SCENARIO_NAME="$1"
  echo "$SCENARIO_NAME" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9đêôơưăâáàảãạéèẻẽẹíìỉĩịóòỏõọúùủũụýỳỷỹỵ]/-/g' \
    | sed 's/[đêôơưăâáàảãạéèẻẽẹíìỉĩịóòỏõọúùủũụýỳỷỹỵ]/-/g' \
    | sed 's/--*/-/g' \
    | sed 's/^-\|-$//g' \
    | cut -c1-50  # Truncate 50 chars cho Windows path limit
}

# Example:
# "Tạo Customer với SalesOwner inactive" → "t-o-customer-v-i-salesowner-inactive" (truncated)
```

---

## C. Timing Capture Matrix

| Trigger | Capture file | Frequency |
|---------|-------------|-----------|
| Sau Step 9.5 login complete | `login-result.png` | 1 lần (entire Phase 9) |
| Sau mỗi scenario PASS | `scenario-{NN}-{slug}.png` (final state) | 1 lần per scenario PASS |
| Sau mỗi scenario FAIL | `scenario-{NN}-{slug}-failed.png` (state khi exit) | 1 lần per scenario FAIL |
| Mỗi step nếu `--strict-evidence` | `scenario-{NN}-{slug}-step-{idx}.png` | N lần per scenario |
| Mỗi step nếu step FAIL (default) | `scenario-{NN}-{slug}-step-{idx}.png` | Chỉ step failed |
| Cross-module: mỗi module page | `scenario-{NN}-{slug}-{direction}-{module}.png` | M lần per scenario (M = modules_visited.length) |
| Pre-fix Phase 10 (Phase A browser-fix) | `scenario-{NN}-{slug}-prefix-{tactic}.png` | 1 lần per tactic attempt |
| Post-fix Phase 10 | `scenario-{NN}-{slug}-postfix-{tactic}.png` | 1 lần per tactic success |

### Capture Function

```bash
capture_screenshot() {
  local SCREENSHOT_NAME="$1"  # filename (không có path prefix)
  local SCENARIOS_DIR="$SESSION_DIR/phase9-e2e-execute/screenshots"
  mkdir -p "$SCENARIOS_DIR"
  local FULL_PATH="$SCENARIOS_DIR/$SCREENSHOT_NAME"

  # Capture via Playwright MCP — full_page=true default
  # Trong runtime, Claude orchestrator gọi:
  # mcp__plugin_playwright_playwright__browser_take_screenshot \
  #     filename="$FULL_PATH" \
  #     fullPage=true \
  #     type=png

  # Verify file created với size hợp lệ
  if [ ! -f "$FULL_PATH" ]; then
    log_error "E170" "screenshot" "Screenshot file missing: $FULL_PATH"
    return 1
  fi

  SIZE=$(wc -c < "$FULL_PATH" 2>/dev/null || echo 0)
  if [ "$SIZE" -lt 100 ]; then
    log_error "E170" "screenshot" "Screenshot file too small ($SIZE bytes): $FULL_PATH"
    return 1
  fi

  return 0
}
```

---

## D. Console + Network Capture (Parallel)

Sau mỗi step (và đặc biệt khi FAIL), capture console + network song song với screenshot. Phase 10 sẽ consume làm evidence cho failure classification.

### D.1 Console Capture

```bash
capture_console() {
  local SCENARIO_ID="$1"
  local STEP_IDX="${2:-final}"  # 'final' nếu scenario-level, idx nếu step-level
  local EVIDENCE_DIR="$SESSION_DIR/phase9-e2e-execute/evidence"
  mkdir -p "$EVIDENCE_DIR"

  local CONSOLE_FILE="$EVIDENCE_DIR/${SCENARIO_ID}-console.log"

  # Trong runtime: Claude gọi
  # mcp__plugin_playwright_playwright__browser_console_messages
  # và pipe output vào file

  # Pseudocode (executor inject content vào file):
  # CONSOLE_MESSAGES=$(mcp__plugin_playwright_playwright__browser_console_messages)
  # echo "$CONSOLE_MESSAGES" | tail -50 > "$CONSOLE_FILE"

  echo "$CONSOLE_FILE"
}
```

### D.2 Network Capture

```bash
capture_network() {
  local SCENARIO_ID="$1"
  local FILTER="${2:-4xx|5xx}"  # filter HTTP status, default lỗi only
  local EVIDENCE_DIR="$SESSION_DIR/phase9-e2e-execute/evidence"
  mkdir -p "$EVIDENCE_DIR"

  local NETWORK_FILE="$EVIDENCE_DIR/${SCENARIO_ID}-network.json"

  # Trong runtime:
  # NETWORK=$(mcp__plugin_playwright_playwright__browser_network_requests)
  # echo "$NETWORK" | jq "[.[] | select(.status | tostring | test(\"$FILTER\"))]" > "$NETWORK_FILE"

  echo "$NETWORK_FILE"
}
```

### D.3 DOM Snapshot (Chỉ on FAIL)

```bash
capture_dom() {
  local SCENARIO_ID="$1"
  local STEP_STATUS="$2"  # "PASS" | "FAIL" | "UNDETERMINED"

  # Chỉ capture DOM khi FAIL (tốn IO + disk)
  [ "$STEP_STATUS" != "FAIL" ] && return 0

  local EVIDENCE_DIR="$SESSION_DIR/phase9-e2e-execute/evidence"
  mkdir -p "$EVIDENCE_DIR"

  local DOM_FILE="$EVIDENCE_DIR/${SCENARIO_ID}-dom.html"

  # Trong runtime:
  # DOM=$(mcp__plugin_playwright_playwright__browser_snapshot)
  # echo "$DOM" > "$DOM_FILE"

  echo "$DOM_FILE"
}
```

---

## E. Strict Evidence Validation

`--strict-evidence` flag (default OFF) kiểm tra mỗi step PHẢI có screenshot + file ≥ 1KB.

### E.1 Logic

> Đầy đủ helper trong `procedures/_shared.md §22 check_strict_evidence()`.

```bash
# Trích summary:
check_strict_evidence() {
  local SCREENSHOT_PATH="$1"
  local STRICT="${STRICT_EVIDENCE:-false}"

  [ "$STRICT" != "true" ] && return 0  # Bypass nếu không bật

  if [ ! -f "$SCREENSHOT_PATH" ]; then
    log_error "E171" "evidence" "STRICT: Screenshot $SCREENSHOT_PATH missing — BLOCKED"
    return 1
  fi

  SIZE=$(wc -c < "$SCREENSHOT_PATH" 2>/dev/null || echo 0)
  if [ "$SIZE" -lt 1024 ]; then
    log_error "E171" "evidence" "STRICT: Screenshot $SCREENSHOT_PATH < 1KB ($SIZE bytes) — BLOCKED"
    return 1
  fi
  return 0
}
```

### E.2 Behavior Matrix

| `--strict-evidence` | Missing screenshot | File <1KB | Action |
|---------------------|---------------------|-----------|--------|
| OFF (default) | Mark scenario `evidence_complete=false`, continue | Same | WARN E171, partial mark |
| ON | E171 BLOCKED, mark scenario `execution_status=BLOCKED` | Same | Block scenario, continue Phase 9 với scenario kế tiếp |

### E.3 Aggregate Check (Step 9.11 POST-GATE T3)

```bash
# POST-GATE T3: screenshots/ ≥1 file (trừ khi 0 scenarios executed)
aggregate_evidence_check() {
  local SCREENSHOTS_DIR="$SESSION_DIR/phase9-e2e-execute/screenshots"
  local N_EXECUTED=$(jq '.summary.n_executed' "$E2E_RESULTS")

  if [ "$N_EXECUTED" -eq 0 ]; then
    # 0 scenarios — KHÔNG cần screenshots
    return 0
  fi

  local SHOT_COUNT=$(find "$SCREENSHOTS_DIR" -type f -name "*.png" 2>/dev/null | wc -l)
  if [ "$SHOT_COUNT" -eq 0 ]; then
    log_error "E171" "evidence" "POST-GATE T3 FAIL: 0 screenshots cho $N_EXECUTED scenarios"
    return 1
  fi

  # 80% coverage check (default mode)
  if [ "${STRICT_EVIDENCE:-false}" != "true" ]; then
    local PCT=$((SHOT_COUNT * 100 / N_EXECUTED))
    if [ "$PCT" -lt 80 ]; then
      log_error "E171" "evidence" "Screenshot coverage ${PCT}% < 80% (${SHOT_COUNT}/${N_EXECUTED})"
      return 1
    fi
  fi
  return 0
}
```

---

## F. Cleanup Policy

Sau Phase 10 DONE (hoặc Phase 9 DONE nếu Phase 10 SKIP):

### F.1 Retention Rules

```
GIỮ NGUYÊN (cho evidence + audit):
- Tất cả PASS scenarios: final screenshot only
- TẤT CẢ FAIL scenarios: final + per-step + on-fail screenshots
- TẤT CẢ AUTO_CORRECTED: pre-fix + post-fix evidence (Phase 10 §Phase A/B)
- TẤT CẢ cross-module screenshots
- Console + network evidence (text files, nhỏ)
- DOM snapshots (chỉ FAIL, nhỏ)

MOVE TO QUARANTINE:
- QUARANTINED scenarios: move screenshots sang
  .mc-data/work/wf-cmi/quarantine/{scenario_id}/screenshots/
  (lý do: tránh nhiễu integrity-report evidence section)

DELETE (sau retention period):
- Stale session ≥30 ngày: cleanup screenshots
  (giữ scenarios .md files cho reference + audit)
- Run-of-the-mill PASS screenshots ≥90 ngày: cleanup
  (giữ summary count trong e2e-results.json)
```

### F.2 Cleanup Script

```bash
cleanup_phase9_screenshots() {
  local SESSION_DIR="$1"
  local QUARANTINE_DIR=".mc-data/work/wf-cmi/quarantine"
  mkdir -p "$QUARANTINE_DIR"

  # 1. Move quarantined scenarios
  local QUARANTINE_REPORT="$SESSION_DIR/phase9-e2e-execute/quarantine-report.json"
  if [ -f "$QUARANTINE_REPORT" ]; then
    jq -r '.quarantined_scenarios[].scenario_id' "$QUARANTINE_REPORT" 2>/dev/null \
    | while IFS= read -r QID; do
      [ -z "$QID" ] && continue
      mkdir -p "$QUARANTINE_DIR/$QID/screenshots"
      find "$SESSION_DIR/phase9-e2e-execute/screenshots" \
           -name "scenario-*${QID}*.png" -exec mv {} "$QUARANTINE_DIR/$QID/screenshots/" \;
    done
  fi

  # 2. Stale cleanup (≥30 ngày)
  find "$SESSION_DIR/phase9-e2e-execute/screenshots" -type f -name "*.png" \
       -mtime +30 -delete 2>/dev/null || true

  return 0
}
```

---

## G. Error Handling

| Error | Action |
|-------|--------|
| E170 Screenshot fail (Playwright not respond) | Log warning, scenario marked partial — KHÔNG block |
| E170 Disk full | Capture skipped, scenario marked `evidence_complete=false`, continue execution |
| E170 File path too long (Windows) | Truncate slug to 50 chars (xem §B.3 make_slug) |
| E171 STRICT violation | BLOCKED scenario (nếu `--strict-evidence`), partial otherwise |
| E170 PNG corruption (<100 bytes) | Re-capture x1, nếu lại fail → mark `evidence_complete=false` |

---

## H. Cross-References

| Reference | Purpose |
|-----------|---------|
| `procedures/phase9-e2e-execute.md` | Consumer (Step 9.5 login screenshot, Step 9.6.e per scenario) |
| `procedures/_e2e-runner.md` | Consumer (per-step + final screenshot capture) |
| `procedures/_failure-analyzer.md` | Consumer (Phase 10 reads evidence paths from e2e-results.json) |
| `procedures/_shared.md §22 check_strict_evidence()` | STRICT validation helper |
| `templates/e2e-results.json` | Schema `e2e-results-v1` evidence{} block |
| **Source** `.claude/skills/workflow/wf-e2e-scenario/procedures/screenshot-evidence.md` | Port reference (Stage 10 sẽ DEPRECATE) |

---

> **Stage 4 implemented (2026-05-16)** — screenshot evidence convention sẵn sàng cho Phase 9 + Phase 10 dispatch.
