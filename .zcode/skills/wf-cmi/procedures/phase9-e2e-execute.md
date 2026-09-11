# Phase 9 — E2E Execute & Verify (v3.0 NEW — opt-in)

> **Stage 4 implemented (2026-05-16)** — full 11 steps + 4 helper scripts (`scripts/wf-cmi-e2e/`) + engine port (`_e2e-runner.md` + `_screenshot-evidence.md`) + Browser Lock Pattern (`_shared.md §21`) + Playwright Retry (`_shared.md §22`).
>
> **Trigger:** Phase 8 POST-GATE PASS AND `--exec-scenarios` ON AND `scenarios-manifest.json` (CD41 Wave 3) exists AND Playwright MCP available
> **Mode:** SEQUENTIAL (1 scenario tại 1 thời điểm, browser-mcp.lock single per session)
> **Engine:** Lazy-load `procedures/_e2e-runner.md` + `procedures/_screenshot-evidence.md`
> **Auto-fix budget:** 3 retries/scenario (browser-fix only — source-fix defer Phase 10)
> **Time estimate:** 30s-2min/scenario × N. 20 scenarios ≈ 10-40 min.
> **Skip conditions:** `--exec-scenarios` không bật / CD41 không sinh scenario / Playwright MCP unavailable (E150)

---

## A. Header

| Field | Value |
|-------|-------|
| Phase | 9 |
| Tên | E2E Execute & Verify |
| Procedure file | `procedures/phase9-e2e-execute.md` (this file) |
| Errors range | E150-E179 (PRE-GATE/setup E150-E159, execute E160-E169, stability E170-E179) |
| Output subdir | `$SESSION_DIR/phase9-e2e-execute/` |
| Templates used | `templates/e2e-execution-report.md`, `templates/e2e-results.json`, `templates/lint-report.json`, `templates/lint-fixes.md`, `templates/stable-registry.json`, `templates/quarantine-report.json`, `templates/Phase9-report.md` |
| Concurrency | 1 (sequential — browser-mcp.lock single per session) |
| Cross-session safety | Protocol 22 R/W lock cho `playwright` resource (đọc cross-session, ghi local) |

---

## B. PRE-GATE (T1-T4)

### B.1 T1 — scenarios-manifest.json exists

```bash
MANIFEST_PATH="$SESSION_DIR/phase4-coverage/lanes/CD41-e2e-synth/scenarios-manifest.json"
if [ ! -f "$MANIFEST_PATH" ]; then
  # Distinguish 2 cases:
  # Case 1: profile=quick|standard → CD41 SKIP đúng spec → E150b INFO, SKIP Phase 9-10
  PROFILE=$(jq -r '.profile' "$SESSION_DIR/integrity-status.json")
  if [ "$PROFILE" = "quick" ] || [ "$PROFILE" = "standard" ]; then
    log_error "E150b" "phase9_pregate" "CD41 không sinh scenario (profile=$PROFILE) — SKIP Phase 9-10"
    write_phase9_report_skipped "E150b" "CD41 không active ở profile=$PROFILE"
    update_status_skip_phase9
    return 0
  fi
  # Case 2: deep/exhaustive nhưng CD41 fail → E155 BLOCK
  log_error "E155" "phase9_pregate" "scenarios-manifest.json missing (CD41 Wave 3 fail?)"
  ask_user_recovery "Re-run profile=deep|exhaustive" "Skip Phase 9-10" "Cancel"
  return 1
fi

# Validate manifest JSON + ≥1 scenario
SCENARIO_COUNT=$(jq '.scenarios | length' "$MANIFEST_PATH" 2>/dev/null || echo 0)
if [ "$SCENARIO_COUNT" -eq 0 ]; then
  log_error "E150b" "phase9_pregate" "scenarios-manifest empty (0 valid scenarios)"
  write_phase9_report_skipped "E150b" "CD41 sinh 0 scenarios"
  update_status_skip_phase9
  return 0
fi
```

### B.2 T2 — Playwright MCP available

```bash
# Smoke test: gọi browser_navigate với about:blank
PLAYWRIGHT_AVAILABLE=false
if command -v mcp__plugin_playwright_playwright__browser_navigate >/dev/null 2>&1; then
  # Trong runtime, Claude orchestrator gọi:
  # RESULT=$(mcp__plugin_playwright_playwright__browser_navigate url="about:blank" 2>&1)
  # Nếu return success → PLAYWRIGHT_AVAILABLE=true
  PLAYWRIGHT_AVAILABLE=true
fi

if [ "$PLAYWRIGHT_AVAILABLE" = "false" ]; then
  log_error "E150" "phase9_pregate" "Playwright MCP unavailable — SKIP Phase 9-10 graceful (CORE-033)"
  write_phase9_report_skipped "E150" "Playwright MCP not available — install MCP server hoặc bỏ --exec-scenarios"
  update_status_skip_phase9
  return 0  # Graceful — vẫn xuất integrity-report v3 ở Phase 8 với e2e_execution_summary=null
fi
```

### B.3 T3 — FE running (HTTP probe)

```bash
FE_BASE_URL="${FE_BASE_URL:-http://localhost:3000}"  # default từ env hoặc app context
FE_RUNNING=false
if command -v curl >/dev/null 2>&1; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$FE_BASE_URL" 2>/dev/null || echo "000")
  [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ] && FE_RUNNING=true
fi

if [ "$FE_RUNNING" = "false" ]; then
  # Check execMode — nếu api-only thì SKIP T3
  EXEC_MODE=$(jq -r '.exec_mode // "browser"' "$MANIFEST_PATH")
  if [ "$EXEC_MODE" = "api-only" ]; then
    log_error "INFO" "phase9_pregate" "exec_mode=api-only — SKIP T3 FE check"
  else
    log_error "E154" "phase9_pregate" "FE not running ($FE_BASE_URL) — ESCALATE"
    ask_user_recovery "Start FE rồi --resume" "Switch to api-only" "Cancel"
    return 1
  fi
fi
```

### B.4 T4 — browser-mcp.lock acquirable

```bash
# Acquire qua scripts/wf-cmi-e2e/browser-lock.sh
bash .claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/browser-lock.sh acquire "$SESSION_DIR"
LOCK_EXIT=$?
if [ "$LOCK_EXIT" -ne 0 ]; then
  log_error "E153" "phase9_pregate" "browser-mcp.lock conflict — không acquire được sau 5 retries"
  ask_user_recovery "Retry sau 30s" "Force release lock" "Cancel"
  return 1
fi
LOCK_ACQUIRED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Cross-session reader lock cho 'playwright' resource (Protocol 22)
# bash .claude/scripts/wf-e2e-shared/global-rw-lock.sh acquire-read playwright wf-cmi:phase9
```

---

## C. Steps (11 Steps Chi Tiết)

### Step 9.1 — PRE-GATE T1-T4 + State Init

```bash
# Đã thực hiện ở §B
# Sau khi PRE-GATE PASS, init state files

mkdir -p "$SESSION_DIR/phase9-e2e-execute/screenshots"
mkdir -p "$SESSION_DIR/phase9-e2e-execute/evidence"

# Init e2e-results.json từ template (CORE-031 READ→POPULATE→WRITE)
E2E_RESULTS="$SESSION_DIR/phase9-e2e-execute/e2e-results.json"
cp .claude/skills/workflow/wf-cmi/templates/e2e-results.json "$E2E_RESULTS.tmp"
# Strip _template_notes (CORE-031)
jq 'del(._template_notes)' "$E2E_RESULTS.tmp" > "$E2E_RESULTS"
rm -f "$E2E_RESULTS.tmp"

# Populate session_id + timestamp
jq --arg sid "$SESSION_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg mode "${EXEC_MODE:-browser}" --arg vp "${VIEWPORT:-desktop}" \
   --arg manifest "$MANIFEST_PATH" \
   '.session_id = $sid
    | .generated_at = $ts
    | .exec_mode = $mode
    | .viewport = $vp
    | .audit_chain.source = $manifest
    | .environment.playwright_available = true
    | .environment.fe_base_url = env.FE_BASE_URL // "http://localhost:3000"
    | .environment.fe_running = '$FE_RUNNING'
    | .environment.strict_evidence = ('"${STRICT_EVIDENCE:-false}"' == "true")' \
   "$E2E_RESULTS" > "$E2E_RESULTS.tmp" && mv "$E2E_RESULTS.tmp" "$E2E_RESULTS"

PHASE9_START_TS=$(date -u +%s)
```

### Step 9.2 — Acquire browser-mcp.lock

```bash
# Đã acquire trong §B.4 PRE-GATE T4
# Cập nhật e2e-results.json
jq --arg ts "$LOCK_ACQUIRED_AT" '.environment.browser_mcp_lock_acquired_at = $ts' \
   "$E2E_RESULTS" > "$E2E_RESULTS.tmp" && mv "$E2E_RESULTS.tmp" "$E2E_RESULTS"

log_error "INFO" "phase9_step" "Step 9.2 PASS — browser-mcp.lock acquired at $LOCK_ACQUIRED_AT"
```

### Step 9.3 — Lint Scenarios

```bash
SCENARIOS_DIR="$SESSION_DIR/phase4-coverage/lanes/CD41-e2e-synth/scenarios"
LINT_REPORT="$SESSION_DIR/phase9-e2e-execute/lint-report.json"
LINT_FIXES_MD="$SESSION_DIR/phase9-e2e-execute/lint-fixes.md"

# Init lint-report.json từ template
cp .claude/skills/workflow/wf-cmi/templates/lint-report.json "$LINT_REPORT.tmp"
jq 'del(._template_notes)' "$LINT_REPORT.tmp" > "$LINT_REPORT"
rm -f "$LINT_REPORT.tmp"

# Populate session_id + timestamp
jq --arg sid "$SESSION_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.session_id = $sid | .lint_run_at = $ts' \
   "$LINT_REPORT" > "$LINT_REPORT.tmp" && mv "$LINT_REPORT.tmp" "$LINT_REPORT"

# Lint từng scenario
HAS_CRITICAL=false
HAS_WARN=false
N_PASS=0; N_WARN=0; N_FAIL=0

for SCENARIO_FILE in "$SCENARIOS_DIR"/test-scenario-CMI-*.md; do
  [ -f "$SCENARIO_FILE" ] || continue

  LINT_RESULT=$(bash .claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/lint-scenario.sh "$SCENARIO_FILE" --json 2>/dev/null)
  STATUS=$(echo "$LINT_RESULT" | jq -r '.lint_status')

  case "$STATUS" in
    PASS) N_PASS=$((N_PASS + 1)) ;;
    WARN) N_WARN=$((N_WARN + 1)); HAS_WARN=true ;;
    FAIL) N_FAIL=$((N_FAIL + 1)); HAS_CRITICAL=true ;;
  esac

  # Append scenarios_linted[] entry
  jq --argjson entry "$LINT_RESULT" '.scenarios_linted += [$entry]' "$LINT_REPORT" \
    > "$LINT_REPORT.tmp" && mv "$LINT_REPORT.tmp" "$LINT_REPORT"
done

# Update summary
TOTAL=$((N_PASS + N_WARN + N_FAIL))
jq --argjson p "$N_PASS" --argjson w "$N_WARN" --argjson f "$N_FAIL" \
   --argjson hc "$HAS_CRITICAL" --argjson hw "$HAS_WARN" --argjson t "$TOTAL" \
   '.summary.n_total = $t
    | .summary.n_pass = $p
    | .summary.n_warn = $w
    | .summary.n_fail = $f
    | .summary.has_critical_errors = $hc
    | .summary.has_warnings = $hw' \
   "$LINT_REPORT" > "$LINT_REPORT.tmp" && mv "$LINT_REPORT.tmp" "$LINT_REPORT"

# BLOCK execute nếu has_critical
if [ "$HAS_CRITICAL" = "true" ]; then
  log_error "E151" "phase9_step" "Lint FAIL: $N_FAIL critical errors trong $TOTAL scenarios — BLOCK Phase 9"

  # Generate lint-fixes.md từ template
  cp .claude/skills/workflow/wf-cmi/templates/lint-fixes.md "$LINT_FIXES_MD"
  populate_lint_fixes_md "$LINT_REPORT" "$LINT_FIXES_MD"

  # AskUserQuestion
  ask_user_recovery "Fix scenarios + --resume" "Skip lint (--ignore-lint, risky)" "Cancel Phase 9"
  release_browser_lock
  return 1
fi

# Generate lint-fixes.md nếu has_warnings (informational, không block)
if [ "$HAS_WARN" = "true" ]; then
  cp .claude/skills/workflow/wf-cmi/templates/lint-fixes.md "$LINT_FIXES_MD"
  populate_lint_fixes_md "$LINT_REPORT" "$LINT_FIXES_MD"
fi
```

### Step 9.4 — Pre-flight 5x Stability Check

```bash
STABLE_REGISTRY="$SESSION_DIR/phase9-e2e-execute/stable-registry.json"
QUARANTINE_REPORT="$SESSION_DIR/phase9-e2e-execute/quarantine-report.json"

# Init stable-registry.json (READ-OR-INIT)
if [ ! -f "$STABLE_REGISTRY" ]; then
  cp .claude/skills/workflow/wf-cmi/templates/stable-registry.json "$STABLE_REGISTRY.tmp"
  jq 'del(._template_notes)' "$STABLE_REGISTRY.tmp" > "$STABLE_REGISTRY"
  rm -f "$STABLE_REGISTRY.tmp"
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.generated_at = $ts' \
     "$STABLE_REGISTRY" > "$STABLE_REGISTRY.tmp" && mv "$STABLE_REGISTRY.tmp" "$STABLE_REGISTRY"
fi

# Init quarantine-report.json
cp .claude/skills/workflow/wf-cmi/templates/quarantine-report.json "$QUARANTINE_REPORT.tmp"
jq 'del(._template_notes)' "$QUARANTINE_REPORT.tmp" > "$QUARANTINE_REPORT"
rm -f "$QUARANTINE_REPORT.tmp"
jq --arg sid "$SESSION_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.session_id = $sid | .generated_at = $ts' \
   "$QUARANTINE_REPORT" > "$QUARANTINE_REPORT.tmp" && mv "$QUARANTINE_REPORT.tmp" "$QUARANTINE_REPORT"

# Detect modified scenarios kể từ baseline
SINCE_REF="${SINCE_REF:-HEAD~1}"
DETECT_OUTPUT=$(bash .claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/detect-modified-scenarios.sh \
  "$SCENARIOS_DIR" --since="$SINCE_REF" 2>/dev/null || echo "")
CHANGED_COUNT=$(echo "$DETECT_OUTPUT" | grep -E "^CHANGED_SCENARIOS:" | head -1 | cut -d: -f2)
CHANGED_FILES=$(echo "$DETECT_OUTPUT" | grep -v "^ALL_SCENARIOS:\|^CHANGED_SCENARIOS:")

REGISTRY_HIT_COUNT=0
N_STABLE=0; N_QUARANTINED=0; N_FLAKY_WARN=0

# Run 5x pre-flight cho CHANGED scenarios (stable ones reuse registry)
for SCENARIO_FILE in "$SCENARIOS_DIR"/test-scenario-CMI-*.md; do
  [ -f "$SCENARIO_FILE" ] || continue
  BASENAME=$(basename "$SCENARIO_FILE")

  # Check if scenario in CHANGED list
  IS_CHANGED=false
  echo "$CHANGED_FILES" | grep -q "$BASENAME" && IS_CHANGED=true

  if [ "$IS_CHANGED" = "false" ]; then
    # Skip 5x — check stable-registry hit
    PREFLIGHT_RESULT=$(bash .claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/e2e-pre-flight-check.sh \
      "$SCENARIO_FILE" --runs=0 --registry="$STABLE_REGISTRY" 2>/dev/null)
    HIT=$(echo "$PREFLIGHT_RESULT" | jq -r '.registry_hit')
    if [ "$HIT" = "true" ]; then
      REGISTRY_HIT_COUNT=$((REGISTRY_HIT_COUNT + 1))
      N_STABLE=$((N_STABLE + 1))
      continue
    fi
    # Cache miss → force 5x
    IS_CHANGED=true
  fi

  if [ "$IS_CHANGED" = "true" ]; then
    PREFLIGHT_RESULT=$(bash .claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/e2e-pre-flight-check.sh \
      "$SCENARIO_FILE" --runs=5 2>/dev/null)
    STABILITY=$(echo "$PREFLIGHT_RESULT" | jq -r '.stability')

    case "$STABILITY" in
      stable)
        N_STABLE=$((N_STABLE + 1))
        # Append vào stable-registry với TTL 30 ngày
        SCENARIO_HASH=$(sha256sum "$SCENARIO_FILE" 2>/dev/null | awk '{print $1}')
        EXPIRES_AT=$(date -u -d "+30 days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
                     || date -u -v +30d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
        SCENARIO_ID=$(awk '/^---$/{f++;next} f==1 && /^scenario_id:/{print $2; exit}' "$SCENARIO_FILE" | tr -d '"')

        jq --arg sid "$SCENARIO_ID" --arg sf "$SCENARIO_FILE" --arg hash "$SCENARIO_HASH" \
           --arg verified "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg expires "$EXPIRES_AT" \
           --arg sess "$SESSION_ID" \
           '.scenarios += [{
              "scenario_id": $sid,
              "scenario_file": $sf,
              "scenario_file_hash": $hash,
              "verified_at": $verified,
              "expires_at": $expires,
              "pre_flight_runs": 1,
              "pre_flight_pass_rate": "5/5",
              "verified_by_session": $sess
            }] | .metadata.total_entries += 1 | .metadata.active_entries += 1' \
           "$STABLE_REGISTRY" > "$STABLE_REGISTRY.tmp" && mv "$STABLE_REGISTRY.tmp" "$STABLE_REGISTRY"
        ;;
      flaky_warn)
        N_FLAKY_WARN=$((N_FLAKY_WARN + 1))
        log_error "E152" "phase9_preflight" "Scenario flaky_warn: $BASENAME (4/5) — WARN continue"
        ;;
      flaky_quarantine)
        N_QUARANTINED=$((N_QUARANTINED + 1))
        log_error "E152" "phase9_preflight" "Scenario quarantined: $BASENAME (≤3/5) — SKIP"

        # APPEND vào quarantine-report.json
        SCENARIO_ID=$(awk '/^---$/{f++;next} f==1 && /^scenario_id:/{print $2; exit}' "$SCENARIO_FILE" | tr -d '"')
        RUNS=$(echo "$PREFLIGHT_RESULT" | jq -r '.runs')
        PASS=$(echo "$PREFLIGHT_RESULT" | jq -r '.pass')
        FAIL=$(echo "$PREFLIGHT_RESULT" | jq -r '.fail')

        jq --arg sid "$SCENARIO_ID" --arg sf "$SCENARIO_FILE" \
           --arg qts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
           --argjson runs "$RUNS" --argjson pass "$PASS" --argjson fail "$FAIL" \
           '.quarantined_scenarios += [{
              "scenario_id": $sid,
              "scenario_file": $sf,
              "quarantined_at": $qts,
              "reason": "flaky",
              "fail_stats": {"runs": $runs, "pass": $pass, "fail": $fail, "flaky": true},
              "status": "quarantined",
              "experts_assigned": ["qa-lead", "frontend-developer"],
              "auto_fix_dispatched": false
            }] | .metadata.total_quarantined += 1 | .metadata.by_reason.flaky += 1' \
           "$QUARANTINE_REPORT" > "$QUARANTINE_REPORT.tmp" && mv "$QUARANTINE_REPORT.tmp" "$QUARANTINE_REPORT"
        ;;
    esac
  fi
done

log_error "INFO" "phase9_preflight" "Pre-flight done: $N_STABLE stable, $N_FLAKY_WARN warn, $N_QUARANTINED quarantined (registry hit: $REGISTRY_HIT_COUNT)"
```

### Step 9.5 — Login (Optional)

```bash
# Check nếu manifest có scenario nào yêu cầu auth
NEEDS_LOGIN=$(jq -r '[.scenarios[]? | select(.actor != null and .actor != "")] | length > 0' "$MANIFEST_PATH")

if [ "$NEEDS_LOGIN" = "true" ]; then
  # Query credential vault qua wf-e2e-credentials (cross-skill produces_for contract v3)
  # Trong runtime, Claude orchestrator gọi wf-e2e-credentials.get_credential(actor=...)
  LOGIN_ACTOR=$(jq -r '.scenarios[0].actor' "$MANIFEST_PATH")
  # Pseudocode: CREDENTIAL=$(query_credential_vault "$LOGIN_ACTOR")
  # Real: Claude tools spawn wf-e2e-credentials skill hoặc đọc encrypted vault

  # Navigate to login URL
  # mcp__plugin_playwright_playwright__browser_navigate url="$FE_BASE_URL/login"
  # mcp__plugin_playwright_playwright__browser_type element="email field" ref="input[name=email]" text="$EMAIL"
  # mcp__plugin_playwright_playwright__browser_type element="password field" ref="input[name=password]" text="$PASSWORD"
  # mcp__plugin_playwright_playwright__browser_click element="login button" ref="button[type=submit]"
  # mcp__plugin_playwright_playwright__browser_wait_for text="Dashboard"

  # Capture login screenshot
  LOGIN_SHOT="$SESSION_DIR/phase9-e2e-execute/screenshots/login-result.png"
  # mcp__plugin_playwright_playwright__browser_take_screenshot filename="$LOGIN_SHOT" fullPage=true

  # Update e2e-results.json
  jq --arg actor "$LOGIN_ACTOR" '.environment.login_actor = $actor' \
     "$E2E_RESULTS" > "$E2E_RESULTS.tmp" && mv "$E2E_RESULTS.tmp" "$E2E_RESULTS"

  log_error "INFO" "phase9_step" "Step 9.5 PASS — login as $LOGIN_ACTOR"
fi
```

### Step 9.6 — FOR Each Scenario Execute

```bash
# Lazy-load _e2e-runner.md engine
# (Claude orchestrator reads engine procedure file một lần, sau đó dispatch per scenario)

SCENARIO_IDX=0
for SCENARIO_FILE in "$SCENARIOS_DIR"/test-scenario-CMI-*.md; do
  [ -f "$SCENARIO_FILE" ] || continue
  SCENARIO_IDX=$((SCENARIO_IDX + 1))
  BASENAME=$(basename "$SCENARIO_FILE")
  SCENARIO_ID=$(awk '/^---$/{f++;next} f==1 && /^scenario_id:/{print $2; exit}' "$SCENARIO_FILE" | tr -d '"')

  # Skip nếu quarantined
  IS_QUARANTINED=$(jq -r --arg sid "$SCENARIO_ID" \
    '[.quarantined_scenarios[]? | select(.scenario_id == $sid)] | length > 0' "$QUARANTINE_REPORT")
  if [ "$IS_QUARANTINED" = "true" ]; then
    log_error "INFO" "phase9_step" "Skip quarantined: $BASENAME"
    # APPEND NOT_EXECUTED entry
    append_not_executed_entry "$SCENARIO_ID" "$SCENARIO_FILE" "QUARANTINED"
    continue
  fi

  # Update current_scenario_idx + sub_state
  jq --argjson idx "$SCENARIO_IDX" --arg sid "$SCENARIO_ID" \
     '.summary.current_scenario_idx = $idx | .summary.current_scenario_id = $sid | .summary.sub_state = "executing"' \
     "$E2E_RESULTS" > "$E2E_RESULTS.tmp" && mv "$E2E_RESULTS.tmp" "$E2E_RESULTS"

  log_error "INFO" "phase9_step" "Step 9.6 [$SCENARIO_IDX] executing $BASENAME"

  # DELEGATE to _e2e-runner.md engine (Claude orchestrator dispatch)
  # Engine sẽ:
  #   1. Parse SCENARIO_FILE frontmatter + steps table
  #   2. Navigate to entry_url (smart retry)
  #   3. FOR each step: dispatch Playwright tool → snapshot → verify expected
  #   4. Capture final screenshot (qua _screenshot-evidence.md)
  #   5. Fill Pass/Fail vào SCENARIO_FILE (atomic write)
  #   6. APPEND scenario entry vào e2e-results.json với execution_status
  #
  # Cross-module: nếu cross_module=true, engine sử dụng §D Cross-Module flow

  # Mock execution (runtime: Claude dispatch engine actions)
  # ENGINE_OUTPUT=$(dispatch_e2e_runner "$SCENARIO_FILE" "$SCENARIO_IDX" "$E2E_RESULTS")

  # update_results_summary cho counters
done

# Cuối loop: clear sub_state
jq '.summary.sub_state = "all_scenarios_processed" | del(.summary.current_scenario_idx, .summary.current_scenario_id)' \
   "$E2E_RESULTS" > "$E2E_RESULTS.tmp" && mv "$E2E_RESULTS.tmp" "$E2E_RESULTS"
```

### Step 9.7 — Cross-Module Verification (Aggregate)

```bash
# Cross-module scenarios đã được execute trong Step 9.6 (engine handle inline)
# Step 9.7 aggregate cross-module specific stats vào e2e-results.json

N_CROSS_MODULE=$(jq '[.scenarios[]? | select(.cross_module == true)] | length' "$E2E_RESULTS")
N_CROSS_MODULE_PASS=$(jq '[.scenarios[]? | select(.cross_module == true and .execution_status == "PASS")] | length' "$E2E_RESULTS")

log_error "INFO" "phase9_step" "Step 9.7 cross-module: $N_CROSS_MODULE_PASS/$N_CROSS_MODULE PASS"

# Aggregate reference_id_consistency + data_consistency stats
CONSISTENCY_PASS=$(jq '[.scenarios[]? | select(.cross_module == true and .reference_id_consistency.consistent == true)] | length' "$E2E_RESULTS")
jq --argjson cm "$N_CROSS_MODULE" --argjson cp "$CONSISTENCY_PASS" \
   '.summary.cross_module_consistency_check = {"checked": $cm, "consistent": $cp}' \
   "$E2E_RESULTS" > "$E2E_RESULTS.tmp" && mv "$E2E_RESULTS.tmp" "$E2E_RESULTS"
```

### Step 9.8 — Release browser-mcp.lock

```bash
bash .claude/skills/workflow/wf-cmi/scripts/wf-cmi-e2e/browser-lock.sh release "$SESSION_DIR"
LOCK_RELEASED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Release cross-session reader lock (Protocol 22)
# bash .claude/scripts/wf-e2e-shared/global-rw-lock.sh release-read playwright wf-cmi:phase9

jq --arg ts "$LOCK_RELEASED_AT" '.environment.browser_mcp_lock_released_at = $ts' \
   "$E2E_RESULTS" > "$E2E_RESULTS.tmp" && mv "$E2E_RESULTS.tmp" "$E2E_RESULTS"

log_error "INFO" "phase9_step" "Step 9.8 PASS — browser-mcp.lock released at $LOCK_RELEASED_AT"
```

### Step 9.9 — Write e2e-execution-report.md

```bash
EXEC_REPORT="$SESSION_DIR/phase9-e2e-execute/e2e-execution-report.md"

# Copy template + strip _schema_notes
cp .claude/skills/workflow/wf-cmi/templates/e2e-execution-report.md "$EXEC_REPORT.tmp"
sed -i '/^<!--$/,/^-->$/d' "$EXEC_REPORT.tmp"
mv "$EXEC_REPORT.tmp" "$EXEC_REPORT"

# Populate placeholders
N_TOTAL=$(jq '.scenarios | length' "$MANIFEST_PATH")
N_EXECUTED=$(jq '.summary.n_executed' "$E2E_RESULTS")
N_PASS=$(jq '.summary.n_pass' "$E2E_RESULTS")
N_FAIL=$(jq '.summary.n_fail' "$E2E_RESULTS")
N_AUTO_CORRECTED=$(jq '.summary.n_auto_corrected' "$E2E_RESULTS")
N_QUARANTINED=$(jq '.summary.n_quarantined' "$E2E_RESULTS")
N_CROSS_MODULE=$(jq '.summary.n_cross_module' "$E2E_RESULTS")
PCT_PASS=0
[ "$N_EXECUTED" -gt 0 ] && PCT_PASS=$((N_PASS * 100 / N_EXECUTED))
PHASE9_DURATION=$(( $(date -u +%s) - PHASE9_START_TS ))

# Build [PER_SCENARIO_BLOCKS], [CROSS_MODULE_BLOCKS], [QUARANTINED_BLOCKS]
PER_SCENARIO_BLOCKS=$(build_per_scenario_blocks "$E2E_RESULTS")
CROSS_MODULE_BLOCKS=$(build_cross_module_blocks "$E2E_RESULTS")
QUARANTINED_BLOCKS=$(build_quarantined_blocks "$QUARANTINE_REPORT")

# sed-based substitution (multi-line awk cho blocks)
sed -i.bak \
  -e "s|\\[SESSION_ID\\]|$SESSION_ID|g" \
  -e "s|\\[PROFILE\\]|$PROFILE|g" \
  -e "s|\\[N_TOTAL_SYNTHESIZED\\]|$N_TOTAL|g" \
  -e "s|\\[N_EXECUTED\\]|$N_EXECUTED|g" \
  -e "s|\\[N_PASS\\]|$N_PASS|g" \
  -e "s|\\[PCT_PASS\\]|$PCT_PASS|g" \
  -e "s|\\[N_AUTO_CORRECTED\\]|$N_AUTO_CORRECTED|g" \
  -e "s|\\[N_FAIL\\]|$N_FAIL|g" \
  -e "s|\\[N_QUARANTINED\\]|$N_QUARANTINED|g" \
  -e "s|\\[N_CROSS_MODULE\\]|$N_CROSS_MODULE|g" \
  -e "s|\\[PHASE9_DURATION\\]|${PHASE9_DURATION}s|g" \
  "$EXEC_REPORT"

# Insert blocks (awk cho multi-line)
awk -v per="$PER_SCENARIO_BLOCKS" -v cross="$CROSS_MODULE_BLOCKS" -v quar="$QUARANTINED_BLOCKS" '
  /\[PER_SCENARIO_BLOCKS\]/ { print per; next }
  /\[CROSS_MODULE_BLOCKS\]/ { print cross; next }
  /\[QUARANTINED_BLOCKS\]/ { print quar; next }
  { print }
' "$EXEC_REPORT" > "$EXEC_REPORT.tmp" && mv "$EXEC_REPORT.tmp" "$EXEC_REPORT"

rm -f "${EXEC_REPORT}.bak"

log_error "INFO" "phase9_step" "Step 9.9 PASS — e2e-execution-report.md written"
```

### Step 9.10 — Update integrity-status.json

```bash
# Aggregate evidence check
aggregate_evidence_check
EVIDENCE_OK=$?

# Compute audit_chain checksum cho e2e-results.json
ARTIFACT_CHECKSUM=$(sha256sum "$E2E_RESULTS" | awk '{print "sha256:" $1}')
jq --arg ck "$ARTIFACT_CHECKSUM" --arg dur "$PHASE9_DURATION" \
   '.audit_chain.checksum = $ck | .summary.phase9_duration_ms = ($dur | tonumber * 1000)' \
   "$E2E_RESULTS" > "$E2E_RESULTS.tmp" && mv "$E2E_RESULTS.tmp" "$E2E_RESULTS"

# Update integrity-status.json (atomic)
INTEGRITY_STATUS="$SESSION_DIR/integrity-status.json"
NEXT_PHASE=8
[ "$N_FAIL" -gt 0 ] && NEXT_PHASE=10  # Phase 10 nếu có FAIL

jq --argjson next "$NEXT_PHASE" \
   '.phases_completed += [9] | .current_phase = $next' \
   "$INTEGRITY_STATUS" > "$INTEGRITY_STATUS.tmp" && mv "$INTEGRITY_STATUS.tmp" "$INTEGRITY_STATUS"

log_error "INFO" "phase9_step" "Step 9.10 PASS — integrity-status updated, next_phase=$NEXT_PHASE"
```

### Step 9.11 — POST-GATE T1-T4

```bash
# T1: e2e-execution-report.md exists + non-empty
[ -f "$EXEC_REPORT" ] && [ -s "$EXEC_REPORT" ] || { log_error "E001" "phase9_postgate" "T1 FAIL"; return 1; }

# T2: e2e-results.json valid JSON, $schema=e2e-results-v1
jq -e '.["$schema"] == "e2e-results-v1"' "$E2E_RESULTS" >/dev/null \
  || { log_error "E001" "phase9_postgate" "T2 FAIL schema"; return 1; }

# T3: screenshots/ ≥1 file (trừ khi 0 executed)
[ "$EVIDENCE_OK" -eq 0 ] || { log_error "E171" "phase9_postgate" "T3 FAIL evidence"; return 1; }

# T4: scenarios-manifest.json updated với execution_status per scenario
# (CD41 sinh scenarios-manifest, Phase 9 chỉ READ — không update manifest)
# T4 = verify nhất quán scenarios[] giữa manifest và results
M_COUNT=$(jq '.scenarios | length' "$MANIFEST_PATH")
R_COUNT=$(jq '.scenarios | length' "$E2E_RESULTS")
if [ "$R_COUNT" -lt "$M_COUNT" ]; then
  log_error "E001" "phase9_postgate" "T4 FAIL: results has $R_COUNT scenarios, manifest has $M_COUNT"
  return 1
fi

# Write Phase9-report.md
write_phase9_report_pass

log_error "INFO" "phase9_postgate" "POST-GATE 4/4 PASS"
```

---

## D. POST-GATE (T1-T4) Summary

```
T1: e2e-execution-report.md exists + non-empty (≥500 bytes)
T2: e2e-results.json valid JSON, $schema=e2e-results-v1, all scenarios có execution_status
T3: screenshots/ ≥1 file (trừ khi 0 scenarios executed) — strict mode 100%, default ≥80%
T4: scenarios-manifest scenarios count match e2e-results scenarios count (đảm bảo not_executed entries vẫn được track)
```

Fail handling: T1-T4 fail → log E001 → AUTO-FIX retry x1 → nếu vẫn fail ESCALATE AskUserQuestion.

---

## E. Phase Report

Render `Phase9-report.md` theo template `templates/Phase9-report.md` (CORE-028, tiếng Việt, ≤15 dòng).

```bash
write_phase9_report_pass() {
  local REPORT="$SESSION_DIR/phase9-e2e-execute/Phase9-report.md"
  cp .claude/skills/workflow/wf-cmi/templates/Phase9-report.md "$REPORT"
  # Strip _schema_notes
  sed -i '/^<!--$/,/^-->$/d' "$REPORT"

  N_SCREENSHOTS=$(find "$SESSION_DIR/phase9-e2e-execute/screenshots" -type f -name "*.png" 2>/dev/null | wc -l)
  STATUS="PASS"
  [ "$N_FAIL" -gt 0 ] && STATUS="PARTIAL_FAIL"

  STARTED_AT=$(jq -r '.generated_at' "$E2E_RESULTS")
  COMPLETED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  DURATION_SEC="$PHASE9_DURATION"

  sed -i \
    -e "s|\\[STATUS_PASS_FAIL_SKIPPED\\]|$STATUS|g" \
    -e "s|\\[STARTED_AT\\]|$STARTED_AT|g" \
    -e "s|\\[COMPLETED_AT\\]|$COMPLETED_AT|g" \
    -e "s|\\[DURATION_SEC\\]|$DURATION_SEC|g" \
    -e "s|\\[MODE_BROWSER_API_ONLY\\]|${EXEC_MODE:-browser}|g" \
    -e "s|\\[VIEWPORT_DESKTOP_MOBILE\\]|${VIEWPORT:-desktop}|g" \
    -e "s|\\[N_SCENARIOS\\]|$N_TOTAL|g" \
    -e "s|\\[N_STABLE\\]|$N_STABLE|g" \
    -e "s|\\[N_TOTAL\\]|$N_TOTAL|g" \
    -e "s|\\[N_QUARANTINED\\]|$N_QUARANTINED|g" \
    -e "s|\\[N_EXECUTED\\]|$N_EXECUTED|g" \
    -e "s|\\[N_PASS\\]|$N_PASS|g" \
    -e "s|\\[N_AUTO_CORRECTED\\]|$N_AUTO_CORRECTED|g" \
    -e "s|\\[N_FAIL\\]|$N_FAIL|g" \
    -e "s|\\[N_CROSS_MODULE\\]|$N_CROSS_MODULE|g" \
    -e "s|\\[N_SCREENSHOTS\\]|$N_SCREENSHOTS|g" \
    -e "s|\\[N_REGISTRY_HIT\\]|$REGISTRY_HIT_COUNT|g" \
    "$REPORT"

  # Conditional next step
  if [ "$N_FAIL" -gt 0 ]; then
    NEXT_TEXT="Phase 10 — E2E Resolution (auto-trigger phân loại 7-type + 2-phase auto-fix)."
  else
    NEXT_TEXT="Phase 8 — Report (build integrity-report.md với section E2E Summary)."
  fi
  sed -i -E "s|\\[IF N_FAIL > 0\\][^.]+\\.|$NEXT_TEXT|g; s|\\[IF N_FAIL = 0\\][^.]+\\.||g" "$REPORT"

  # Cleanup FAIL/SKIPPED conditional block
  sed -i '/\[NẾU FAIL\/SKIPPED/,$d' "$REPORT"
}

write_phase9_report_skipped() {
  local ERROR_CODE="$1"
  local REASON="$2"
  local REPORT="$SESSION_DIR/phase9-e2e-execute/Phase9-report.md"
  mkdir -p "$(dirname "$REPORT")"
  cat > "$REPORT" <<EOF
## Phase 9: E2E Execute & Verify — SKIPPED

Thời gian: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Lý do: ${REASON}
Error code: ${ERROR_CODE}

**Đã làm:** Bỏ qua Phase 9 do điều kiện không đủ (xem error code).
**Kết quả:** Không execute scenarios. e2e_execution_summary trong integrity-impact-v3 sẽ = null.
**Tiếp theo:** Phase 8 — Report (xuất integrity-report.md bình thường, không có section E2E Summary).
EOF
}
```

---

## F. Error Codes (E150-E179)

| Code | Severity | Tình huống | Auto-fix strategy |
|------|----------|-----------|-------------------|
| E150 | info | Playwright MCP unavailable | SKIP Phase 9-10, integrity-report v3 vẫn xuất với e2e_execution_summary=null |
| E150b | info | CD41 không sinh scenario (profile=quick/standard, 0 MUST/HIGH) | SKIP với INFO log |
| E151 | high | Lint FAIL | BLOCK, ghi lint-fixes.md, AskUserQuestion fix/ignore/cancel |
| E152 | medium | Scenario flaky (≤3/5 pre-flight) | Auto-quarantine, SKIP scenario, continue |
| E153 | high | browser-mcp.lock conflict ≥30 min | Auto-release stale, retry x1 |
| E154 | high | FE not running | ESCALATE — user start FE hoặc switch api-only |
| E155 | high | scenarios-manifest.json invalid/empty | BLOCK, hướng dẫn re-run profile=deep |
| E160 | medium | Scenario step execute fail | Smart retry per failure type (`_shared.md §22`) |
| E161 | medium | browser_snapshot fail | Skip snapshot verify, mark UNDETERMINED |
| E162 | medium | Navigate fail | Retry x3 với re-login |
| E170 | low | Stable-registry corruption hoặc screenshot fail | Re-init registry, WARN |
| E171 | low | --strict-evidence violation | Partial mark (off) / BLOCK (on) |

---

## G. Cross-References

| Reference | Purpose |
|-----------|---------|
| `procedures/_shared.md §21` | Browser Lock Pattern (acquire/release/stale auto-release) |
| `procedures/_shared.md §22` | Playwright Retry Pattern (smart retry by failure type + strict evidence) |
| `procedures/_e2e-runner.md` | Engine — step pattern recognition + expected result verification + cross-module walk |
| `procedures/_screenshot-evidence.md` | Screenshot convention + console/network capture + cleanup |
| `procedures/lanes/CD41.md` | Producer (sinh scenarios-manifest + scenarios cho Phase 9 consume) |
| `procedures/phase10-e2e-resolution.md` | Consumer (Phase 10 đọc e2e-results.json FAIL entries) |
| `procedures/phase8-report.md` | Consumer (Phase 8 aggregate e2e_execution_summary vào integrity-impact-v3) |
| `scripts/wf-cmi-e2e/lint-scenario.sh` | Lint G1.1 (7 rules CMI-specific) |
| `scripts/wf-cmi-e2e/detect-modified-scenarios.sh` | Detect changed since baseline (G1.3 optimization) |
| `scripts/wf-cmi-e2e/e2e-pre-flight-check.sh` | 5x stability check (G1.3) |
| `scripts/wf-cmi-e2e/browser-lock.sh` | Lock acquire/release helper |
| `_contract.json §errors_canonical E150-E199` | Error code definitions |
| `templates/e2e-execution-report.md` | User-facing report template |
| `templates/e2e-results.json` | Schema `e2e-results-v1` |
| `templates/Phase9-report.md` | CORE-028 ≤15 dòng phase report |

---

## H. Helper Functions Reference

| Function | Defined in | Purpose |
|----------|-----------|---------|
| `acquire_browser_lock` / `release_browser_lock` | `_shared.md §21` | Browser lock lifecycle |
| `execute_with_smart_retry` / `classify_failure` | `_shared.md §22` | Smart retry per failure type |
| `check_strict_evidence` | `_shared.md §22` | STRICT mode validation |
| `dispatch_step` / `verify_expected_result` | `_e2e-runner.md §C/E` | Step execute + assertion |
| `capture_screenshot` / `capture_console` / `capture_network` | `_screenshot-evidence.md §C/D` | Evidence capture |
| `populate_lint_fixes_md` | Inline §C Step 9.3 | Render lint-fixes.md từ lint-report.json |
| `build_per_scenario_blocks` / `build_cross_module_blocks` / `build_quarantined_blocks` | Inline §C Step 9.9 | awk multi-line block render |
| `write_phase9_report_pass` / `write_phase9_report_skipped` | Inline §E | Phase report render |
| `append_not_executed_entry` | Inline §C Step 9.6 | NOT_EXECUTED entry cho QUARANTINED |
| `update_status_skip_phase9` | Inline §B PRE-GATE | Skip routing to Phase 8 |
| `ask_user_recovery` | `_shared.md §15` agent prompt | AskUserQuestion với 3 options |
| `log_error` | `_shared.md §4-6` | Append error-ledger.json |

---

> **Stage 4 implemented (2026-05-16)** — full 11 steps + helper script integration sẵn sàng.
> Stage 5 sẽ implement Phase 10 Resolution consume e2e-results.json FAIL entries từ phase 9.
