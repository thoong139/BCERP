# Phase 10 — E2E Resolution (v3.0 NEW — auto-run nếu Phase 9 có FAIL)

> **Stage 5 implemented (2026-05-16)** — full 6 steps + lazy-load engine `_failure-analyzer.md` + loop-back gap-suggestions APPEND + CDG E195 source-fix confirm.
>
> **Trigger:** Phase 9 POST-GATE PASS AND `e2e-results.json` có ≥1 FAIL entry
> **Mode:** HYBRID (analysis sequential per-issue + spawn agents Phase B PARALLEL max 3)
> **Engine:** Lazy-load `procedures/_failure-analyzer.md`
> **Auto-fix budget:** 3 retries/issue (Phase A x2 + Phase B x1 tổng)
> **Time estimate:** 30s-3min/FAIL issue × N. 5 FAIL ≈ 2-15 min.
> **Skip conditions:** Phase 9 0 FAIL → SKIP INFO / Phase 9 không chạy (E150 SKIP) → SKIP
> **Loop-back guard:** APPEND gap-suggestions CHỈ kind=`e2e_scenario_fix`. KHÔNG re-trigger CD41 → tránh infinite loop.

---

## A. Header

| Field | Value |
|-------|-------|
| Phase | 10 |
| Tên | E2E Resolution |
| Procedure file | `procedures/phase10-e2e-resolution.md` (this file) |
| Engine | `procedures/_failure-analyzer.md` (lazy-load) |
| Errors range | E180-E189 (Analysis), E190-E199 (Auto-fix), E195 (CDG) |
| Output subdir | `$SESSION_DIR/phase10-e2e-resolution/` |
| Templates used | `templates/resolution-report.md`, `templates/Phase10-report.md` |
| Updates | `$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json` (APPEND kind=`e2e_scenario_fix`) |
| Concurrency | Sequential per-issue analysis. Phase B agent spawn parallel max 3 (CORE-025). |
| Cross-session safety | Phase B file writes ghi qua agent — agent tự acquire writer lock per resource (Protocol 22) |

---

## B. PRE-GATE (T1-T3)

### B.1 T1 — e2e-results.json có ≥1 FAIL entry

```bash
pregate_t1_fail_entries() {
  local E2E_RESULTS="$SESSION_DIR/phase9-e2e-execute/e2e-results.json"

  if [ ! -f "$E2E_RESULTS" ]; then
    # Phase 9 SKIP hoặc fail → Phase 10 cũng SKIP
    log_error "INFO" "phase10_pregate" "e2e-results.json missing — Phase 9 SKIP/fail → SKIP Phase 10"
    write_phase10_report_skipped "INFO" "Phase 9 không chạy (no e2e-results.json)"
    return 0
  fi

  # Filter FAIL entries
  local FAIL_COUNT=$(jq '[.issues[] | select(.execution_status == "FAIL")] | length' "$E2E_RESULTS" 2>/dev/null || echo 0)

  if [ "$FAIL_COUNT" -eq 0 ]; then
    log_error "INFO" "phase10_pregate" "Phase 9 0 FAIL — SKIP Phase 10"
    write_phase10_report_skipped "INFO" "Phase 9 ALL PASS / AUTO_CORRECTED — không có FAIL"
    update_status_skip_phase10
    return 0
  fi

  FAIL_ISSUES_JSON=$(jq '[.issues[] | select(.execution_status == "FAIL")]' "$E2E_RESULTS")
  echo "Loaded $FAIL_COUNT FAIL issues from Phase 9"
  return 0
}
```

### B.2 T2 — failure-analyzer engine loadable

```bash
pregate_t2_engine_loadable() {
  local ENGINE="$(dirname "$0")/_failure-analyzer.md"

  if [ ! -f "$ENGINE" ]; then
    log_error "E001" "phase10_pregate" "Engine _failure-analyzer.md missing — installation broken"
    return 1
  fi

  # Smoke check: engine có 7-type classification section
  if ! grep -q "## C. Bước 2 — Phân Loại Failure Type" "$ENGINE"; then
    log_error "E001" "phase10_pregate" "Engine _failure-analyzer.md structure invalid"
    return 1
  fi

  return 0
}
```

### B.3 T3 — agents available (registry check)

```bash
pregate_t3_agents_available() {
  # Check 6 primary agents tồn tại trong .claude/agents/
  local REQUIRED_AGENTS=("qa-lead" "developer" "frontend-developer" "dba" "security" "architect")
  local MISSING=()

  for AGENT in "${REQUIRED_AGENTS[@]}"; do
    if ! find .claude/agents -name "${AGENT}.md" -type f 2>/dev/null | grep -q .; then
      MISSING+=("$AGENT")
    fi
  done

  if [ "${#MISSING[@]}" -gt 0 ]; then
    log_error "WARN" "phase10_pregate" "Missing agents: ${MISSING[*]} — Phase B sẽ degraded (skip missing types)"
    # Không block — graceful degradation, Phase B sẽ skip nếu agent missing
  fi

  return 0
}
```

---

## C. Steps Chi Tiết

### Step 10.1 — PRE-GATE check + load FAIL entries

```bash
step_10_1_init() {
  echo "[Phase 10] Step 10.1 — Init + PRE-GATE"

  # Create output subdir
  local OUT_DIR="$SESSION_DIR/phase10-e2e-resolution"
  mkdir -p "$OUT_DIR/spawn-logs"

  # PRE-GATE T1-T3
  pregate_t1_fail_entries || return 1
  pregate_t2_engine_loadable || return 1
  pregate_t3_agents_available

  # If PRE-GATE T1 SKIP (no FAIL) → exit success
  [ -z "${FAIL_ISSUES_JSON:-}" ] && return 0
  [ "$(echo "$FAIL_ISSUES_JSON" | jq 'length')" -eq 0 ] && return 0

  # Init accumulators
  RESOLUTION_ACCUMULATOR="| # | Scenario | Failure Type | Layer | Resolution Direction | Owner |
|---|----------|--------------|-------|----------------------|-------|"

  SPAWN_AGENT_LOG="[]"
  AUTO_CORRECTED_COUNT=0
  UNRESOLVED_COUNT=0
  MANUAL_TRIAGE_COUNT=0
  CDG_E195_TRIGGERED=false

  # Init timestamp
  PHASE10_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  PHASE10_START_EPOCH=$(date -u +%s)

  log_phase_event "phase10" "INFO" "{\"fail_count\":$(echo "$FAIL_ISSUES_JSON" | jq 'length'),\"phase10_start\":\"$PHASE10_START\"}"
}
```

### Step 10.2 — FOR each FAIL issue: classify + auto-fix

```bash
step_10_2_process_failures() {
  echo "[Phase 10] Step 10.2 — Process FAIL issues (engine: _failure-analyzer.md)"

  local IDX=0
  local FAIL_TOTAL=$(echo "$FAIL_ISSUES_JSON" | jq 'length')

  for ISSUE in $(echo "$FAIL_ISSUES_JSON" | jq -c '.[]'); do
    IDX=$((IDX + 1))
    local ISSUE_ID=$(echo "$ISSUE" | jq -r '.issue_id')
    local SCENARIO_ID=$(echo "$ISSUE" | jq -r '.scenario_id')
    local SCENARIO_NAME=$(echo "$ISSUE" | jq -r '.scenario_name // .scenario_id')
    local SCENARIO_FILE=$(echo "$ISSUE" | jq -r '.scenario_file')
    local STEP_ERROR=$(echo "$ISSUE" | jq -r '.failure_detail.error_message // ""')
    local SCREENSHOT_PATH=$(echo "$ISSUE" | jq -r '.evidence.screenshot_path // ""')

    # Load CMI context từ scenario frontmatter
    local SCENARIO_FRONTMATTER=$(extract_scenario_frontmatter "$SCENARIO_FILE")
    INVARIANT_ID=$(echo "$SCENARIO_FRONTMATTER" | jq -r '.source_invariant_id // ""')
    MODULES_INVOLVED=$(echo "$SCENARIO_FRONTMATTER" | jq -c '.modules_involved // []')
    SOURCE_DIM=$(echo "$SCENARIO_FRONTMATTER" | jq -r '.source_dim // ""')
    SEVERITY_INHERITED=$(echo "$SCENARIO_FRONTMATTER" | jq -r '.severity // "MEDIUM"')

    echo "  [$IDX/$FAIL_TOTAL] Processing $ISSUE_ID ($SCENARIO_NAME)"

    # === Bước 1: Collect evidence (engine _failure-analyzer.md §B) ===
    collect_failure_evidence "$ISSUE_ID"

    # === Bước 2: Classify 7-type (engine §C) ===
    classify_failure_type "$STEP_ERROR"
    echo "    → failure_type=$FAILURE_TYPE"

    # === Bước 3: Determine layer + owner (engine §D) ===
    case "$FAILURE_TYPE" in
      NETWORK_ERROR) AFFECTED_LAYER="backend"; SUGGESTED_OWNER="developer" ;;
      AUTH_FAILURE) AFFECTED_LAYER="backend"; SUGGESTED_OWNER="security" ;;
      DATA_MISSING) AFFECTED_LAYER="database"; SUGGESTED_OWNER="dba" ;;
      TEST_SELECTOR) AFFECTED_LAYER="test"; SUGGESTED_OWNER="qa-lead" ;;
      UI_BUG) AFFECTED_LAYER="frontend"; SUGGESTED_OWNER="frontend-developer" ;;
      BUSINESS_RULE) AFFECTED_LAYER="architecture"; SUGGESTED_OWNER="architect" ;;
      UNKNOWN) AFFECTED_LAYER="unknown"; SUGGESTED_OWNER="qa-lead" ;;
    esac

    # === Bước 4: Render resolution direction (engine §E) ===
    render_resolution_direction "$FAILURE_TYPE"  # outputs $RESOLUTION_DIRECTION

    # === Bước 5: Enrich e2e-results.json entry (engine §F) ===
    enrich_e2e_results_entry "$ISSUE_ID"

    # === Bước 6: Append resolution accumulator (engine §G) ===
    append_resolution_accumulator "$IDX" "$SCENARIO_NAME"

    # === Bước 7: Auto-Fix Attempt (engine §H) ===
    if [ "$FAILURE_TYPE" = "UNKNOWN" ]; then
      AUTO_FIX_RESULT=SKIP
      MANUAL_TRIAGE_COUNT=$((MANUAL_TRIAGE_COUNT + 1))
      log_error "E180" "phase10" "Issue $ISSUE_ID UNKNOWN — SKIP auto-fix"
    else
      attempt_auto_fix "$ISSUE_ID" "$FAILURE_TYPE"
    fi

    # === Step 10.3 inline: APPEND loop-back gap-suggestion ===
    append_loop_back_suggestion "$ISSUE_ID"
    local SUGG_ID=$?

    # Update issue counters
    case "$AUTO_FIX_RESULT" in
      PASS) AUTO_CORRECTED_COUNT=$((AUTO_CORRECTED_COUNT + 1)) ;;
      FAIL) UNRESOLVED_COUNT=$((UNRESOLVED_COUNT + 1)) ;;
      SKIP) MANUAL_TRIAGE_COUNT=$((MANUAL_TRIAGE_COUNT + 1)) ;;
    esac

    echo "    → AUTO_FIX_RESULT=$AUTO_FIX_RESULT (suggestion: $SUGG_ID)"
  done

  log_phase_event "phase10" "INFO" "{\"auto_corrected\":$AUTO_CORRECTED_COUNT,\"unresolved\":$UNRESOLVED_COUNT,\"manual_triage\":$MANUAL_TRIAGE_COUNT}"
}
```

### Helper: attempt_auto_fix (delegate to engine)

```bash
attempt_auto_fix() {
  local ISSUE_ID="$1"
  local FT="$2"

  AUTO_FIX_RESULT=FAIL
  P1_RESULT=SKIP
  P2_RESULT=SKIP
  P1_STRATEGY=""
  P2_AGENT=""
  P2_FILES_MODIFIED="[]"
  P2_FIX_DESCRIPTION=""

  # === Phase A: Browser-fix (default ON) ===
  case "$FT" in
    TEST_SELECTOR)
      local BTN_TEXT=$(echo "$STEP_ERROR" | sed -nE 's/.*"([^"]+)".*/\1/p' | head -1)
      [ -z "$BTN_TEXT" ] && BTN_TEXT="submit"
      phase_a_test_selector "$BTN_TEXT" ;;
    AUTH_FAILURE) phase_a_auth_failure ;;
    NETWORK_ERROR)
      # Check 5xx vs 4xx
      local IS_5XX=$(echo "$NETWORK_RAW" | jq 'any(.status >= 500 and .status < 600)' 2>/dev/null)
      if [ "$IS_5XX" = "true" ]; then
        phase_a_network_5xx
      else
        log_error "INFO" "phase10" "NETWORK_ERROR 4xx — SKIP Phase A, vào Phase B"
        P1_RESULT=SKIP
      fi ;;
    UI_BUG) phase_a_ui_bug ;;
    DATA_MISSING) phase_a_data_missing ;;
    BUSINESS_RULE)
      log_error "INFO" "phase10" "BUSINESS_RULE — SKIP Phase A (cần source-fix)"
      P1_RESULT=SKIP ;;
  esac

  # Append Phase A attempt log to e2e-results
  append_auto_fix_attempt "$ISSUE_ID" "A" "$P1_STRATEGY" "$P1_RESULT"

  if [ "$P1_RESULT" = "PASS" ]; then
    AUTO_FIX_RESULT=PASS
    return 0
  fi

  # === Phase B: Source-fix (chỉ nếu --auto-fix-source + CDG E195) ===
  if ! check_auto_fix_source_cdg; then
    # User reject hoặc --auto-fix-source OFF
    AUTO_FIX_RESULT=FAIL
    return 1
  fi

  CDG_E195_TRIGGERED=true

  # Get agents per failure type
  local AGENT_INFO=$(get_phase_b_agents "$FT" "$MODULES_INVOLVED")
  local PRIMARY=$(echo "$AGENT_INFO" | cut -d'|' -f1)
  local CO_AGENTS=$(echo "$AGENT_INFO" | cut -d'|' -f2)

  # Set allowed scope per failure type
  case "$FT" in
    TEST_SELECTOR) ALLOWED_SCOPE="$SCENARIO_FILE only"; LOCK_RESOURCE="scenarios" ;;
    AUTH_FAILURE) ALLOWED_SCOPE="apps/backend/**/Auth/** OR apps/backend/**/Middleware/**"; LOCK_RESOURCE="backend" ;;
    NETWORK_ERROR) ALLOWED_SCOPE="apps/backend/**/Controllers/** OR apps/backend/**/Services/**"; LOCK_RESOURCE="backend" ;;
    UI_BUG) ALLOWED_SCOPE="apps/erp-web/src/**"; LOCK_RESOURCE="frontend" ;;
    BUSINESS_RULE) ALLOWED_SCOPE="apps/backend/**/Application/** OR apps/backend/**/Domain/**"; LOCK_RESOURCE="backend" ;;
    DATA_MISSING) ALLOWED_SCOPE="apps/backend/**/Migrations/** OR apps/backend/**/Seed/**"; LOCK_RESOURCE="database" ;;
  esac

  # Spawn agent (engine §H.3.b)
  spawn_phase_b_agent "$PRIMARY" "$CO_AGENTS"

  # Append Phase B attempt log
  append_auto_fix_attempt "$ISSUE_ID" "B" "spawn_${PRIMARY}" "$P2_RESULT"

  # Append spawn log entry
  SPAWN_AGENT_LOG=$(echo "$SPAWN_AGENT_LOG" | jq \
    --arg id "$ISSUE_ID" \
    --arg agent "$PRIMARY" \
    --argjson co "$CO_AGENTS" \
    --arg result "$P2_RESULT" \
    --argjson files "$P2_FILES_MODIFIED" \
    --arg desc "$P2_FIX_DESCRIPTION" \
    --arg conf "${P2_CONFIDENCE:-low}" \
    '. + [{
      issue_id: $id,
      primary_agent: $agent,
      co_agents: $co,
      result: $result,
      files_modified: $files,
      fix_description: $desc,
      confidence_level: $conf,
      spawned_at: now | todateiso8601
    }]')

  if [ "$P2_RESULT" != "PASS" ]; then
    AUTO_FIX_RESULT=FAIL
    return 1
  fi

  # === Post-fix verify (engine §H.4) ===
  post_fix_verify
  return $?
}
```

### Step 10.3 — Loop-back gap-suggestions APPEND (inline trong Step 10.2 per-issue)

> **Đã thực hiện inline trong Step 10.2** sau khi mỗi issue resolved (function `append_loop_back_suggestion` từ engine §J).
>
> **Guard:** APPEND CHỈ kind=`e2e_scenario_fix`. Schema vẫn `gap-suggestions-v1`. KHÔNG re-trigger CD41 → per-session synth chỉ 1 lần.
>
> **Cross-reference:** `procedures/phase7-gap-cdg.md §C Step 7.11` — loop-back consumer-side (đọc + apply suggestions ở Phase 7 next session).

### Step 10.4 — Write resolution-report.md

```bash
step_10_4_write_report() {
  echo "[Phase 10] Step 10.4 — Write resolution-report.md"

  local TPL=".claude/skills/workflow/wf-cmi/templates/resolution-report.md"
  local OUT="$SESSION_DIR/phase10-e2e-resolution/resolution-report.md"

  if [ ! -f "$TPL" ]; then
    log_error "E001" "phase10" "Template resolution-report.md missing"
    return 1
  fi

  # Strip template metadata + populate placeholders
  local PHASE10_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local DURATION_MS=$((($(date -u +%s) - PHASE10_START_EPOCH) * 1000))

  # Build per-failure-type breakdown
  local FT_BREAKDOWN=""
  for FT in NETWORK_ERROR AUTH_FAILURE DATA_MISSING TEST_SELECTOR UI_BUG BUSINESS_RULE UNKNOWN; do
    local CNT=$(jq --arg ft "$FT" '[.issues[] | select(.failure_type == $ft)] | length' "$SESSION_DIR/phase9-e2e-execute/e2e-results.json" 2>/dev/null || echo 0)
    [ "$CNT" -gt 0 ] && FT_BREAKDOWN="${FT_BREAKDOWN}- ${FT}: ${CNT}
"
  done

  # CDG decision log
  local CDG_LOG="- E195 source-fix: ${CDG_E195_TRIGGERED}"
  [ "$CDG_E195_TRIGGERED" = "true" ] && CDG_LOG="${CDG_LOG} (user ${USER_CDG_E195_DECISION:-N/A})"

  # Spawn agent log render
  local SPAWN_LOG_MD=""
  if [ "$(echo "$SPAWN_AGENT_LOG" | jq 'length')" -gt 0 ]; then
    SPAWN_LOG_MD=$(echo "$SPAWN_AGENT_LOG" | jq -r '.[] |
      "- **\(.issue_id)** → `\(.primary_agent)`" +
      (if .co_agents | length > 0 then " + co: \(.co_agents | join(", "))" else "" end) +
      " → \(.result)" +
      (if .files_modified | length > 0 then "\n  - Files: \(.files_modified | join(", "))" else "" end) +
      (if .fix_description != "" then "\n  - Fix: \(.fix_description)" else "" end)')
  else
    SPAWN_LOG_MD="(Không có agent spawn — Phase B không trigger)"
  fi

  # Populate template
  sed \
    -e "s|{{SESSION_ID}}|${SESSION_ID}|g" \
    -e "s|{{PHASE10_START}}|${PHASE10_START}|g" \
    -e "s|{{PHASE10_END}}|${PHASE10_END}|g" \
    -e "s|{{DURATION_MS}}|${DURATION_MS}|g" \
    -e "s|{{FAIL_COUNT}}|$(echo "$FAIL_ISSUES_JSON" | jq 'length')|g" \
    -e "s|{{AUTO_CORRECTED_COUNT}}|${AUTO_CORRECTED_COUNT}|g" \
    -e "s|{{UNRESOLVED_COUNT}}|${UNRESOLVED_COUNT}|g" \
    -e "s|{{MANUAL_TRIAGE_COUNT}}|${MANUAL_TRIAGE_COUNT}|g" \
    -e "s|{{CDG_E195_DECISION}}|${USER_CDG_E195_DECISION:-not-triggered}|g" \
    "$TPL" > "$OUT.tmp"

  # Strip _schema_notes HTML comments (CORE-031)
  sed -e '/<!-- _schema_notes/,/-->/d' "$OUT.tmp" > "$OUT"
  rm -f "$OUT.tmp"

  # Insert dynamic blocks via awk
  awk -v acc="$RESOLUTION_ACCUMULATOR" \
      -v ft_bd="$FT_BREAKDOWN" \
      -v cdg="$CDG_LOG" \
      -v spawn_log="$SPAWN_LOG_MD" '
    /\[FAILURE_TYPE_BREAKDOWN\]/ { gsub(/\[FAILURE_TYPE_BREAKDOWN\]/, ft_bd) }
    /\[RESOLUTION_TABLE\]/ { gsub(/\[RESOLUTION_TABLE\]/, acc) }
    /\[CDG_LOG\]/ { gsub(/\[CDG_LOG\]/, cdg) }
    /\[SPAWN_AGENT_LOG\]/ { gsub(/\[SPAWN_AGENT_LOG\]/, spawn_log) }
    { print }
  ' "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"

  # Validate non-empty
  if [ ! -s "$OUT" ]; then
    log_error "E001" "phase10" "resolution-report.md empty sau render"
    return 1
  fi

  echo "  → $OUT ($(wc -l < "$OUT") dòng)"
}
```

### Step 10.5 — Update integrity-status.json (atomic)

```bash
step_10_5_update_status() {
  echo "[Phase 10] Step 10.5 — Update integrity-status.json"

  local STATUS="$SESSION_DIR/integrity-status.json"
  local TMP="${STATUS}.tmp.$$"

  jq \
    --arg phase10_end "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson fail_count "$(echo "$FAIL_ISSUES_JSON" | jq 'length')" \
    --argjson auto_corrected "$AUTO_CORRECTED_COUNT" \
    --argjson unresolved "$UNRESOLVED_COUNT" \
    --argjson manual_triage "$MANUAL_TRIAGE_COUNT" \
    --arg cdg_e195 "${USER_CDG_E195_DECISION:-not-triggered}" \
    '.phases_completed += [10] |
     .current_phase = 8 |
     .phase10_summary = {
       triggered_at: now | todateiso8601,
       completed_at: $phase10_end,
       fail_input_count: $fail_count,
       auto_corrected_count: $auto_corrected,
       unresolved_count: $unresolved,
       manual_triage_count: $manual_triage,
       cdg_e195_decision: $cdg_e195
     } |
     .next_action = "re-write Phase 8 integrity-report v3 với E2E section + integrity-impact v3 populate e2e_execution_summary + scenarios_artifacts"' \
    "$STATUS" > "$TMP"

  if jq -e '.' "$TMP" >/dev/null 2>&1; then
    mv "$TMP" "$STATUS"
  else
    rm -f "$TMP"
    log_error "E001" "phase10" "integrity-status.json atomic write fail"
    return 1
  fi
}
```

### Step 10.6 — POST-GATE T1-T4

```bash
step_10_6_post_gate() {
  echo "[Phase 10] Step 10.6 — POST-GATE T1-T4"

  local OUT_DIR="$SESSION_DIR/phase10-e2e-resolution"

  # T1: resolution-report.md exists + non-empty
  if [ ! -s "$OUT_DIR/resolution-report.md" ]; then
    log_error "E001" "phase10_postgate" "T1 fail: resolution-report.md missing/empty"
    return 1
  fi

  # T2: Mỗi FAIL issue có resolution entry trong e2e-results.json
  local FAIL_INPUT=$(echo "$FAIL_ISSUES_JSON" | jq 'length')
  local RESOLVED_COUNT=$(jq '[.issues[] | select(.failure_type != null)] | length' "$SESSION_DIR/phase9-e2e-execute/e2e-results.json" 2>/dev/null || echo 0)

  if [ "$RESOLVED_COUNT" -lt "$FAIL_INPUT" ]; then
    log_error "E001" "phase10_postgate" "T2 fail: $RESOLVED_COUNT/$FAIL_INPUT issues có resolution entry"
    return 1
  fi

  # T3: gap-suggestions.json valid JSON + schema vẫn gap-suggestions-v1 + có kind=e2e_scenario_fix entries
  local GAP_SUGG="$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json"
  if [ -f "$GAP_SUGG" ]; then
    if ! jq -e '."$schema" == "gap-suggestions-v1"' "$GAP_SUGG" >/dev/null 2>&1; then
      log_error "E001" "phase10_postgate" "T3 fail: gap-suggestions.json schema bị thay đổi"
      return 1
    fi

    local E2E_SUGG_COUNT=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix")] | length' "$GAP_SUGG")
    echo "  → T3 PASS: $E2E_SUGG_COUNT e2e_scenario_fix suggestions appended"
  else
    log_error "WARN" "phase10_postgate" "T3: gap-suggestions.json không tồn tại (Phase 7 chưa chạy?) — skip APPEND"
  fi

  # T4: Phase10-report.md exists + ≤15 dòng
  if [ ! -f "$OUT_DIR/Phase10-report.md" ]; then
    log_error "E001" "phase10_postgate" "T4 fail: Phase10-report.md missing"
    return 1
  fi

  local LINES=$(wc -l < "$OUT_DIR/Phase10-report.md")
  if [ "$LINES" -gt 15 ]; then
    log_error "WARN" "phase10_postgate" "T4 warn: Phase10-report.md > 15 dòng ($LINES)"
  fi

  echo "  → POST-GATE T1-T4 PASS"
  return 0
}
```

---

## D. Phase Report Render (CORE-028)

```bash
write_phase10_report() {
  local TPL=".claude/skills/workflow/wf-cmi/templates/Phase10-report.md"
  local OUT="$SESSION_DIR/phase10-e2e-resolution/Phase10-report.md"

  local STATUS="PASS"
  [ "$UNRESOLVED_COUNT" -gt 0 ] && STATUS="PASS (với ${UNRESOLVED_COUNT} unresolved)"

  local NEXT_STEP="Phase 8 re-write integrity-report v3 với E2E Summary section"

  # Loop-back count
  local LOOPBACK_COUNT=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix")] | length' "$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json" 2>/dev/null || echo 0)

  sed \
    -e "s|{{STATUS}}|${STATUS}|g" \
    -e "s|{{TIMESTAMP}}|$(date -u +%Y-%m-%dT%H:%M:%SZ)|g" \
    -e "s|{{FAIL_INPUT_COUNT}}|$(echo "$FAIL_ISSUES_JSON" | jq 'length' 2>/dev/null || echo 0)|g" \
    -e "s|{{AUTO_CORRECTED_COUNT}}|${AUTO_CORRECTED_COUNT:-0}|g" \
    -e "s|{{UNRESOLVED_COUNT}}|${UNRESOLVED_COUNT:-0}|g" \
    -e "s|{{MANUAL_TRIAGE_COUNT}}|${MANUAL_TRIAGE_COUNT:-0}|g" \
    -e "s|{{LOOPBACK_COUNT}}|${LOOPBACK_COUNT}|g" \
    -e "s|{{CDG_E195}}|${USER_CDG_E195_DECISION:-not-triggered}|g" \
    -e "s|{{NEXT_STEP}}|${NEXT_STEP}|g" \
    "$TPL" > "$OUT.tmp"

  # Strip _schema_notes HTML comments
  sed -e '/<!-- _schema_notes/,/-->/d' "$OUT.tmp" > "$OUT"
  rm -f "$OUT.tmp"
}

write_phase10_report_skipped() {
  local SKIP_CODE="$1"
  local SKIP_REASON="$2"

  cat > "$SESSION_DIR/phase10-e2e-resolution/Phase10-report.md" <<EOF
## Phase 10: E2E Resolution — SKIPPED ($SKIP_CODE)
Thời gian: $(date -u +%Y-%m-%dT%H:%M:%SZ)

**Đã làm:** Kiểm tra PRE-GATE, phát hiện điều kiện SKIP.

**Kết quả:** SKIPPED — $SKIP_REASON

**Tiếp theo:** Phase 8 re-write integrity-report v3 với e2e_execution_summary=null (Phase 10 không chạy).
EOF
}

update_status_skip_phase10() {
  local STATUS="$SESSION_DIR/integrity-status.json"
  jq '.phase10_skipped = true | .next_action = "Phase 8 re-write skip"' "$STATUS" > "${STATUS}.tmp.$$" && mv "${STATUS}.tmp.$$" "$STATUS"
}
```

---

## E. CDG E195 — Source-Fix Confirm (chi tiết AskUserQuestion)

> **Trigger:** Lần đầu trong session khi `--auto-fix-source` ON + có ≥1 FAIL issue cần Phase B.
> **Implementation:** Engine `_failure-analyzer.md §H.3.a` — `check_auto_fix_source_cdg()`.

**Runtime AskUserQuestion:**

```
{
  "question": "Phase 10 sắp spawn agent sửa source code cho [N] issues thuộc các failure_type: [list_types]. Tiếp tục?",
  "header": "Source fix",
  "options": [
    {
      "label": "Confirm spawn agents (Recommended cho test envs)",
      "description": "Spawn agents (qa-lead/developer/security/dba/frontend-developer + domain experts) sửa source files. Files modified sẽ được commit vào branch hiện tại."
    },
    {
      "label": "Reject - chỉ browser-fix",
      "description": "Chỉ Phase A (browser-fix). Phase B SKIP. Issues UNRESOLVED sẽ append vào gap-suggestions confidence=0.30 cho manual review."
    },
    {
      "label": "Skip Phase 10 hoàn toàn",
      "description": "Bỏ qua cả Phase 10. Log FAIL issues vào resolution-report mà không fix. Integrity-report sẽ show e2e_execution_summary.unresolved_count cao."
    }
  ],
  "multiSelect": false
}
```

**Persist decision:** `append_cdg_token "phase10-e2e-resolution" "E195-AutoFixSource-Confirm" "$DECISION"` (Protocol §18).

**Anti-loop:** Max 1 trigger / session. Subsequent issues trong cùng session sẽ tự áp dụng decision đã chọn (cached trong `cdg-tokens.json`).

---

## F. Error Codes (E180-E199 — xem `_contract.json §errors_canonical`)

| Code | Severity | Tình huống | Auto-fix strategy |
|------|----------|-----------|-------------------|
| E180 | medium | Classify UNKNOWN | Log, set failure_type=UNKNOWN, SKIP auto-fix, manual triage prompt |
| E181 | low | Evidence partial | Tiếp tục với partial data, set evidence_partial=true |
| E190 | high | Spawn agent fail (timeout >5min) | Retry x1, ESCALATE nếu vẫn fail |
| E191 | medium | HMR reload timeout (30s) | Manual page reload, re-run scenario |
| E192 | medium | Post-fix verify FAIL | Mark UNRESOLVED, append gap-suggestions confidence=0.30 |
| E195 | info | CDG source-fix confirm | AskUserQuestion (xem §E) |

---

## G. Cross-References

| Reference | Purpose |
|-----------|---------|
| `procedures/_failure-analyzer.md` | Engine — 7-type classify + 2-phase auto-fix + loop-back schema |
| `procedures/_shared.md §22` | Smart retry pattern (Phase A browser-fix) |
| `procedures/_shared.md §14` | R/W lock (DATA_MISSING Phase A acquire writer lock database) |
| `procedures/_shared.md §15` | Agent Prompt Templates (Phase B spawn template) |
| `procedures/_shared.md §18` | CDG token persist (E195 confirm) |
| `procedures/phase9-e2e-execute.md` | Producer of e2e-results.json + screenshots |
| `procedures/phase7-gap-cdg.md §C Step 7.11` | Loop-back consumer — đọc + apply gap-suggestions kind=e2e_scenario_fix next session |
| `procedures/phase8-report.md` | Re-write target sau Phase 10 — populate v3 fields (e2e_execution_summary + scenarios_artifacts) |
| `templates/resolution-report.md` | Step 10.4 render target |
| `templates/Phase10-report.md` | Phase Report render target (CORE-028 ≤15 dòng) |
| `templates/e2e-results.json` | Schema `e2e-results-v1` — enrich target |
| `templates/gap-suggestions.json` | Schema `gap-suggestions-v1` — APPEND target |
| `_contract.json §errors_canonical E180-E199` | Error code definitions |
| `_contract.json §internal_phases[10]` | Phase 10 metadata + auto_fix_budget + loop_back_guard |

---

## H. Helper Functions Reference

| Function | Defined In | Purpose |
|----------|-----------|---------|
| `collect_failure_evidence()` | `_failure-analyzer.md §B` | Capture console/network/DOM |
| `classify_failure_type()` | `_failure-analyzer.md §C` | 7-type priority classification |
| `render_resolution_direction()` | `_failure-analyzer.md §E` | Template per failure_type |
| `enrich_e2e_results_entry()` | `_failure-analyzer.md §F` | Atomic write enrich e2e-results.json |
| `append_resolution_accumulator()` | `_failure-analyzer.md §G` | Add row to `$RESOLUTION_ACCUMULATOR` |
| `check_auto_fix_source_cdg()` | `_failure-analyzer.md §H.3.a` | CDG E195 confirm gate |
| `spawn_phase_b_agent()` | `_failure-analyzer.md §H.3.b` | Spawn agent với 8-section prompt |
| `get_phase_b_agents()` | `_failure-analyzer.md §H.3.c` | Agent mapping per failure_type |
| `post_fix_verify()` | `_failure-analyzer.md §H.4` | Wait HMR + re-execute scenario |
| `append_loop_back_suggestion()` | `_failure-analyzer.md §J` | APPEND gap-suggestions kind=e2e_scenario_fix |
| `phase_a_test_selector()` | `_failure-analyzer.md §H.2.a` | Try 3 selector variants |
| `phase_a_auth_failure()` | `_failure-analyzer.md §H.2.b` | Re-login |
| `phase_a_network_5xx()` | `_failure-analyzer.md §H.2.c` | Wait 3s retry |
| `phase_a_ui_bug()` | `_failure-analyzer.md §H.2.d` | Page reload |
| `phase_a_data_missing()` | `_failure-analyzer.md §H.2.e` | Seed apply hoặc UI create |
| `re_execute_full_scenario()` | `_e2e-runner.md §F` | Re-run scenario từ đầu |
| `append_cdg_token()` | `_shared.md §18` | Persist CDG decision |
| `extract_scenario_frontmatter()` | `_e2e-runner.md` | Parse YAML frontmatter |
| `log_phase_event()` | `_shared.md §7` | Execution trace (CORE-026) |
| `log_error()` | `_shared.md §4` | Append error-ledger.json |

---

## I. Lưu ý Implementation

1. **Runtime executor là Claude orchestrator** — phase10-e2e-resolution.md là pseudocode + bash logic; thực tế Phase 10 chạy bởi Claude (đọc procedure + dispatch tools Playwright MCP + Agent spawn). Không phải bash script độc lập.
2. **Browser-mcp.lock VẪN held từ Phase 9** — Phase 10 inherit lock, KHÔNG re-acquire. Release lock ở cuối Phase 10 nếu Phase 9 chưa release.
3. **Agent spawn parallel max 3** (CORE-025) — nếu có >3 FAIL issues cần Phase B, batch theo nhóm 3.
4. **CDG E195 chỉ trigger 1 lần / session** — cached qua `cdg-tokens.json`. Subsequent issues áp dụng decision đã chọn.
5. **Loop-back guard** — APPEND gap-suggestions CHỈ kind=`e2e_scenario_fix`. KHÔNG re-trigger CD41 (per-session synth chỉ 1 lần ở Phase 4 Wave 3).
6. **Schema gap-suggestions-v1 KHÔNG bump** — value `e2e_scenario_fix` là enum mới cho field `kind` (open enum).
7. **Post-Phase-10 → Phase 8 re-write** — integrity-status `.next_action` set "Phase 8 re-write" để Claude orchestrator biết cần re-run Phase 8 Step 8.3-8.4 populate v3 fields.

---

> **Stage 5 implemented** — Phase 10 Resolution Engine đầy đủ 6 steps + lazy-load `_failure-analyzer.md` + 2-phase auto-fix budget + CDG E195 + loop-back gap-suggestions APPEND với guard tránh re-trigger CD41 → integration với Phase 8 re-write ở Stage 6.
