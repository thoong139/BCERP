# Phase 8 — Report (Final + Cross-Skill Artifact) — v3 mở rộng E2E

> **Đầu vào:** All Phase 1-7 outputs + (v3 conditional) Phase 9 e2e-results.json + Phase 10 resolution-report.md
> **Đầu ra:** `integrity-report.md` (tiếng Việt ≤55 dòng v2 base / ≤70 dòng v3 với E2E section), `integrity-impact.json` (cross-skill artifact schema `integrity-impact-v3`, backward-compat read v1+v2+v3), `Phase8-report.md`, session COMPLETED
> **Auto-fix budget:** 3 retries
> **Time estimate:** 45-60s (v2 base) / +10-15s (v3 nếu Phase 9-10 đã chạy)
> **Required:** ✅ (Pipeline completion + cross-skill handoff)
> **v3 trigger:** Nếu `integrity-status.json.phases_completed` chứa cả Phase 9 (và optional Phase 10) → re-write `integrity-report.md` với E2E section + populate `integrity-impact.json` 2 fields v3 (e2e_execution_summary + scenarios_artifacts). Nếu KHÔNG → behavior y v2 (e2e_execution_summary=null + scenarios_artifacts=[]).

---

## §A Header

Phase 8 build final user-facing report tiếng Việt + cross-skill artifact `integrity-impact.json` cho 4 downstream consumers (wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment).

**Mode:** SEQUENTIAL (no agent spawn — pure report generation + artifact write).

**Key outputs:**
- `integrity-report.md` — user-friendly, tiếng Việt, ≤55 dòng v2 base (44-48 typical) / ≤70 dòng v3 (max bound khi có E2E section đầy đủ), có Mermaid diagrams nếu `--show-graphs`. E2E section CHỈ render khi `e2e_execution_summary != null` (Phase 9 đã chạy).
- `integrity-impact.json` — schema `integrity-impact-v3` (BACKWARD-COMPAT: consumers read v1+v2+v3 via `$schema` field detect) + audit_chain.checksum + git_commit/branch + author cho traceability. **V3 thêm 2 TOP-LEVEL fields** (`e2e_execution_summary` object/null + `scenarios_artifacts[]` array). **V2 fields đầy đủ preserved**: `lanes_v2{active,skipped,skeleton}`, `wave_breakdown{wave_1,wave_2,wave_3}`, `group_breakdown{core,frontend,backend,ux,logistics,compliance,implementation,(+e2e_synth nếu CD41)}`, `logistics_critical_signals_count`, `schema_version_compat`.
- Session marked COMPLETED trong `_index/sessions.jsonl`

**Cross-skill handoff flag:** Downstream skills consume qua `--from-cmi`.

**Shared sections cần load:**
- `_shared.md §1, §3, §17 Author, §19 Audit Chain`

---

## §B PRE-GATE (T1→T4)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | All Phase 1-7 PASS (kể cả skipped với reason ghi rõ) | bash | **E080** — Pipeline incomplete → re-validate, ESCALATE |
| T2 | All template files exist (`integrity-report.md`, `integrity-impact.json`, `Phase8-report.md`) | bash | **E081** — Template missing → re-locate templates path |
| T3 | Coverage matrix consumer-ready (`coverage-matrix-v1` schema valid) | jq | **E082** — Matrix invalid for downstream → re-build matrix |
| T4 | Cross-skill artifact path writable (`$SESSION_DIR/phase8-report/` permissions OK) | bash | **E083** — Cannot write → retry x3, ESCALATE |

```bash
# T1 — All phases completed
PHASES_DONE=$(jq -r '.phases_completed | sort | tostring' "$SESSION_DIR/integrity-status.json")
# Acceptable: [1,2,3,4,5,6,7] OR with skipped (vd [1,2,3,4,5,7] if Phase 6 skipped)
EXPECTED='[1,2,3,4,5,6,7]'
SKIPPED_OK='[1,2,3,4,5,7]'  # Phase 6 skipped
HEALTHY_OK='[1,2,3,4,5]'    # E005 healthy — Phase 6,7 skipped

if [ "$PHASES_DONE" != "$EXPECTED" ] && [ "$PHASES_DONE" != "$SKIPPED_OK" ] && [ "$PHASES_DONE" != "$HEALTHY_OK" ]; then
  die "E080" "Pipeline incomplete: phases_completed=$PHASES_DONE"
fi

# T2 — templates
for tpl in "integrity-report.md" "integrity-impact.json" "Phase8-report.md"; do
  [ -f ".claude/skills/workflow/wf-cmi/templates/$tpl" ] || die "E081" "Template missing: $tpl"
done

# T3 — coverage matrix valid for downstream
jq -e '."$schema" == "coverage-matrix-v1" and (.dimensions | type == "object")' \
   "$SESSION_DIR/phase5-aggregate/coverage-matrix.json" >/dev/null \
  || die "E082" "Matrix schema invalid for downstream"

# T4 — write permission
touch "$SESSION_DIR/phase8-report/.writable_test" 2>/dev/null \
  && rm -f "$SESSION_DIR/phase8-report/.writable_test" \
  || die "E083" "Cannot write to phase8-report/"
```

---

## §C Steps

### Step 8.1 — Load all phase outputs (v3: include Phase 9-10 optional)

```bash
INTEGRITY_STATUS=$(cat "$SESSION_DIR/integrity-status.json")
COVERAGE_MATRIX=$(cat "$SESSION_DIR/phase5-aggregate/coverage-matrix.json")
INVARIANTS_DRAFT=$(cat "$SESSION_DIR/phase3-invariants/business-invariants.json")
SIGNALS_AGG=$(jq -s '.' "$SESSION_DIR/phase5-aggregate/signals-aggregated.jsonl")
REGRESSION_MAP=$(cat "$SESSION_DIR/phase6-regression/regression-map.json" 2>/dev/null || echo '{}')
GAP_SUGGESTIONS=$(cat "$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json" 2>/dev/null || echo '{"suggestions":[]}')

# ─────────────────────────────────────────────────────────────
# v3 NEW: Load Phase 9 + Phase 10 outputs nếu có (conditional)
# Decide PHASE_9_RAN / PHASE_10_RAN từ integrity-status.json
# ─────────────────────────────────────────────────────────────
PHASES_DONE_ARR=$(echo "$INTEGRITY_STATUS" | jq -r '.phases_completed // []')
PHASE_9_RAN=$(echo "$PHASES_DONE_ARR" | jq 'index(9) != null')
PHASE_10_RAN=$(echo "$PHASES_DONE_ARR" | jq 'index(10) != null')

E2E_RESULTS='null'
RESOLUTION_DATA='null'
SCENARIOS_MANIFEST='null'

if [ "$PHASE_9_RAN" = "true" ] && [ -f "$SESSION_DIR/phase9-e2e-execute/e2e-results.json" ]; then
  E2E_RESULTS=$(cat "$SESSION_DIR/phase9-e2e-execute/e2e-results.json")
  log_phase_event "phase8" "INFO" "{\"phase9_results_loaded\":true,\"scenarios_count\":$(echo "$E2E_RESULTS" | jq '.scenarios // [] | length')}"
fi

# Phase 10 chỉ có nếu Phase 9 có FAIL → load resolution-report.md text + scan e2e-results.json đã enrich
if [ "$PHASE_10_RAN" = "true" ]; then
  if [ -f "$SESSION_DIR/phase10-e2e-resolution/resolution-report.md" ]; then
    RESOLUTION_DATA='{"resolved":true}'
  fi
  # Phase 10 enrich e2e-results.json với failure_type → top_failure_types tính từ đây
fi

# Manifest từ CD41 lane (nếu profile=deep|exhaustive + --exec-scenarios)
MANIFEST_PATH="$SESSION_DIR/phase4-coverage/lanes/CD41-e2e-synth/scenarios-manifest.json"
if [ -f "$MANIFEST_PATH" ]; then
  SCENARIOS_MANIFEST=$(cat "$MANIFEST_PATH")
fi

export PHASE_9_RAN PHASE_10_RAN E2E_RESULTS RESOLUTION_DATA SCENARIOS_MANIFEST
```

### Step 8.2 — Compute final status (PASS/WARN/FAIL)

```bash
OVERALL_PCT=$(echo "$COVERAGE_MATRIX" | jq -r '.overall_pct')
OVERALL_STATUS=$(echo "$COVERAGE_MATRIX" | jq -r '.overall_status')

# Violations summary
TOTAL_VIOLATIONS=$(echo "$SIGNALS_AGG" | jq 'length')
MUST_VIOLATIONS=$(echo "$SIGNALS_AGG" | jq '[.[] | select(.severity == "MUST")] | length')

# Cross-domain conflict count
CONFLICTS=$(jq 'length' "$SESSION_DIR/phase3-invariants/conflicts.json" 2>/dev/null || echo 0)

# Determine final status
if [ "$OVERALL_STATUS" = "HEALTHY" ]; then
  FINAL_STATUS="HEALTHY"
elif [ "$MUST_VIOLATIONS" -gt 0 ] || [ "$OVERALL_STATUS" = "FAIL" ]; then
  FINAL_STATUS="FAIL"
elif [ "$OVERALL_STATUS" = "WARN" ] || [ "$CONFLICTS" -gt 0 ]; then
  FINAL_STATUS="WARN"
else
  FINAL_STATUS="PASS"
fi

export FINAL_STATUS OVERALL_PCT TOTAL_VIOLATIONS MUST_VIOLATIONS
log_phase_event "phase8" "INFO" "{\"final_status\":\"$FINAL_STATUS\",\"violations\":$TOTAL_VIOLATIONS}"
```

### Step 8.3 — Build `integrity-report.md` v2 (CORE-028 ≤50 dòng tiếng Việt, 7 grouped sections + top 10 severity-weighted)

```bash
TPL=".claude/skills/workflow/wf-cmi/templates/integrity-report.md"
REPORT="$SESSION_DIR/phase8-report/integrity-report.md"
mkdir -p "$SESSION_DIR/phase8-report"

# ─────────────────────────────────────────────────────────────
# 8.3.1 — Per-group computation (Core/FE/BE/UX/Logistics/Compliance/Implementation)
# Lane → group mapping (v2.0 Gói C++ Logistics, 26 active)
# ─────────────────────────────────────────────────────────────
# Group definitions (canonical, đồng bộ với group_breakdown trong integrity-impact.json template)
declare -A GROUP_LANES=(
  [core]="CD1 CD2 CD3 CD4 CD5 CD6 CD7 CD9"
  [frontend]="CD11 CD13 CD15"
  [backend]="CD16 CD17 CD18"
  [ux]="CD23 CD24 CD25 CD26"
  [logistics]="CD28 CD30 CD31"
  [compliance]="CD29 CD37"
  [implementation]="CD38 CD39 CD40"
)

# Helper: compute group avg coverage_pct + status + violations count
compute_group_metrics() {
  local group="$1"
  local lanes="${GROUP_LANES[$group]}"
  local sum_pct=0 count=0 violations_count=0
  local worst_status="PASS"  # demote priority: PASS < WARN < FAIL
  for dim in $lanes; do
    local entry pct st
    entry=$(echo "$COVERAGE_MATRIX" | jq -r --arg d "$dim" '.dimensions[$d] // empty')
    [ -z "$entry" ] || [ "$entry" = "null" ] && continue
    pct=$(echo "$entry" | jq -r '.coverage_pct // 0')
    st=$(echo "$entry" | jq -r '.status // "PENDING"')
    # Skip SKIPPED dims khi compute avg (chúng có coverage_pct=null)
    [ "$st" = "SKIPPED" ] && continue
    sum_pct=$(awk -v a="$sum_pct" -v b="$pct" 'BEGIN{printf "%.4f", a+b}')
    count=$((count + 1))
    # Count violations từ signals-aggregated for this dim
    local dim_violations
    dim_violations=$(echo "$SIGNALS_AGG" | jq --arg d "$dim" '[.[] | select(.dim == $d)] | length')
    violations_count=$((violations_count + dim_violations))
    # Update worst status (priority: FAIL_THRESHOLD/FAIL > WARN > PASS)
    case "$st" in
      FAIL_THRESHOLD|FAIL) worst_status="FAIL" ;;
      WARN) [ "$worst_status" != "FAIL" ] && worst_status="WARN" ;;
    esac
  done
  local avg_pct=0
  [ "$count" -gt 0 ] && avg_pct=$(awk -v s="$sum_pct" -v c="$count" 'BEGIN{printf "%.1f", s/c}')
  # Export results via stdout: AVG_PCT|STATUS|VIOLATIONS_COUNT|LANE_COUNT
  echo "${avg_pct}|${worst_status}|${violations_count}|${count}"
}

# Compute 7 groups
for g in core frontend backend ux logistics compliance implementation; do
  result=$(compute_group_metrics "$g")
  IFS='|' read -r avg_pct status viol_count lane_count <<< "$result"
  declare "${g^^}_AVG_PCT=$avg_pct"
  declare "${g^^}_STATUS=$status"
  declare "${g^^}_VIOLATIONS=$viol_count"
done

# Status → icon
status_icon() {
  case "$1" in
    PASS|HEALTHY) echo "✅" ;;
    WARN) echo "⚠" ;;
    FAIL|FAIL_THRESHOLD) echo "❌" ;;
    *) echo "⏸" ;;
  esac
}

CORE_STATUS_ICON=$(status_icon "$CORE_STATUS")
FE_STATUS_ICON=$(status_icon "$FRONTEND_STATUS")
BE_STATUS_ICON=$(status_icon "$BACKEND_STATUS")
UX_STATUS_ICON=$(status_icon "$UX_STATUS")
LOGISTICS_STATUS_ICON=$(status_icon "$LOGISTICS_STATUS")
COMPLIANCE_STATUS_ICON=$(status_icon "$COMPLIANCE_STATUS")
IMPL_STATUS_ICON=$(status_icon "$IMPLEMENTATION_STATUS")

# ─────────────────────────────────────────────────────────────
# 8.3.2 — Wave summary (W1/W2/W3 từ wave-status.json)
# ─────────────────────────────────────────────────────────────
WAVE_STATUS_FILE="$SESSION_DIR/phase4-coverage/wave-status.json"
if [ -f "$WAVE_STATUS_FILE" ]; then
  for w in 1 2 3; do
    wave_data=$(jq -r ".wave_${w}" "$WAVE_STATUS_FILE")
    pass=$(echo "$wave_data" | jq -r '.pass_count // 0')
    fail=$(echo "$wave_data" | jq -r '.fail_count // 0')
    tout=$(echo "$wave_data" | jq -r '.timeout_count // 0')
    lanes_active=$(echo "$wave_data" | jq -r '.lanes_active // [] | join(",")')
    started=$(echo "$wave_data" | jq -r '.started_at // ""')
    completed=$(echo "$wave_data" | jq -r '.completed_at // ""')
    duration="—"
    if [ -n "$started" ] && [ -n "$completed" ] && [ "$started" != "null" ] && [ "$completed" != "null" ]; then
      duration=$(awk -v s="$started" -v e="$completed" 'BEGIN{
        cmd_s="date -d \"" s "\" +%s"; cmd_s | getline ts; close(cmd_s);
        cmd_e="date -d \"" e "\" +%s"; cmd_e | getline te; close(cmd_e);
        diff=te-ts; printf "%dm%ds", int(diff/60), diff%60
      }')
    fi
    declare "W${w}_LANES_LIST=${lanes_active:--}"
    declare "W${w}_PASS=$pass"
    declare "W${w}_FAIL=$((fail + tout))"
    declare "W${w}_DURATION=$duration"
  done
else
  # Fallback nếu wave-status.json không tồn tại (vd quick profile chỉ W1)
  for w in 1 2 3; do
    declare "W${w}_LANES_LIST=—"
    declare "W${w}_PASS=0"
    declare "W${w}_FAIL=0"
    declare "W${w}_DURATION=—"
  done
fi

# ─────────────────────────────────────────────────────────────
# 8.3.3 — Top 10 violations severity-weighted (MUST=4, HIGH=3, MEDIUM=2, LOW=1)
# ─────────────────────────────────────────────────────────────
TOP_N=10
TOP_VIOLATIONS_LIST=$(echo "$SIGNALS_AGG" | jq -r --argjson n "$TOP_N" '
  def sev_weight: if . == "MUST" then 4 elif . == "HIGH" then 3 elif . == "MEDIUM" then 2 elif . == "LOW" then 1 else 0 end;
  if length == 0 then
    "_Không phát hiện vi phạm._"
  else
    [.[] | {
      dim: .dim,
      rule_id: (.rule_id // "—"),
      severity: (.severity // "LOW"),
      sev_w: ((.severity // "LOW") | sev_weight),
      message: (.message // "—"),
      affected_modules: (.affected_modules // [] | join(", ")),
      first_file: ((.evidence // [{}])[0].file // ""),
      first_line: ((.evidence // [{}])[0].line // 0)
    }]
    | sort_by(-.sev_w, .dim, .rule_id)
    | .[:$n]
    | to_entries
    | map(
        "\(.key + 1). **\(.value.rule_id)** (\(.value.severity)) — \(.value.dim) — \(if .value.affected_modules == "" then "—" else .value.affected_modules end) — " +
        (if .value.first_file == "" then "_no file_" else "[`\(.value.first_file)`](\(.value.first_file)" + (if .value.first_line > 0 then "#L\(.value.first_line)" else "" end) + ")" end)
      )
    | join("\n")
  end
')

ACTUAL_TOP_COUNT=$(echo "$SIGNALS_AGG" | jq --argjson n "$TOP_N" 'if length == 0 then 0 else (if length < $n then length else $n end) end')

# ─────────────────────────────────────────────────────────────
# 8.3.4 — Suggestions breakdown (4 kinds: test_case, invariant, api_contract, ssot)
# ─────────────────────────────────────────────────────────────
N_TOTAL=$(echo "$GAP_SUGGESTIONS" | jq -r '.suggestions // [] | length')
N1=$(echo "$GAP_SUGGESTIONS" | jq -r '[.suggestions[]? | select(.kind == "test_case" or .kind == "test")] | length')
N2=$(echo "$GAP_SUGGESTIONS" | jq -r '[.suggestions[]? | select(.kind == "invariant" or .kind == "invariant_rule")] | length')
N3=$(echo "$GAP_SUGGESTIONS" | jq -r '[.suggestions[]? | select(.kind == "api_contract" or .kind == "contract")] | length')
N4=$(echo "$GAP_SUGGESTIONS" | jq -r '[.suggestions[]? | select(.kind == "ssot" or .kind == "ssot_entry")] | length')

# ─────────────────────────────────────────────────────────────
# 8.3.5 — Regression scope summary
# ─────────────────────────────────────────────────────────────
N_FILES="0"
N_MODULES="0"
SINCE_REF="${SINCE_REF:-—}"
if [ -f "$SESSION_DIR/phase6-regression/regression-map.json" ] && \
   jq -e '.skipped != true' "$SESSION_DIR/phase6-regression/regression-map.json" >/dev/null 2>&1; then
  N_FILES=$(jq '.changed_files | length' "$SESSION_DIR/phase6-regression/regression-map.json")
  N_MODULES=$(jq '.predicted_impact.affected_modules | length' "$SESSION_DIR/phase6-regression/regression-map.json")
  SINCE_REF=$(jq -r '.since_ref // "—"' "$SESSION_DIR/phase6-regression/regression-map.json")
fi

# ─────────────────────────────────────────────────────────────
# 8.3.6 — Recommendations (theo Priority Order CORE-023)
# Tính concrete actions cho 4 consumers
# ─────────────────────────────────────────────────────────────
LOGISTICS_COMPLIANCE_VIOL=$((LOGISTICS_VIOLATIONS + COMPLIANCE_VIOLATIONS))
if [ "$LOGISTICS_COMPLIANCE_VIOL" -gt 0 ]; then
  ACTION_LOGISTICS_COMPLIANCE="$LOGISTICS_COMPLIANCE_VIOL vi phạm logistics/compliance — fix trước release (CD28/CD30/CD31/CD37)"
else
  ACTION_LOGISTICS_COMPLIANCE="Không có vi phạm logistics/compliance — pass"
fi

ACTION_FOR_VERIFY_SYNC="Re-validate impl_status với $TOTAL_VIOLATIONS violations + regression $N_MODULES module"
ACTION_FOR_FIX_BUGS="Seed Phase 1 với $MUST_VIOLATIONS MUST violations"
ACTION_FOR_IMPLEMENT_FEATURE="Warn khi touch modules trong violations[].affected_modules"

# ─────────────────────────────────────────────────────────────
# 8.3.6b — v3 NEW: Compute E2E summary aggregates + extra suggestion breakdown
# (chỉ dùng nếu PHASE_9_RAN=true; nếu không thì E2E_SECTION="" + N_E2E_FIX=0)
# ─────────────────────────────────────────────────────────────
N_E2E_FIX=$(echo "$GAP_SUGGESTIONS" | jq -r '[.suggestions[]? | select(.kind == "e2e_scenario_fix")] | length')
ACTION_FOR_E2E="Không sử dụng — chạy `/wf-cmi --exec-scenarios --profile=deep` để bật runtime verify Playwright"

E2E_SECTION_BLOCK=""
E2E_TOP_FAILURE_TYPES="—"
N_SYNTH=0; N_EXEC=0; N_PASS=0; N_AUTO_CORRECTED=0; N_FAIL=0
N_QUARANTINED=0; N_CROSS_MODULE=0; PHASE9_DURATION_MS=0; PHASE10_DURATION_MS=0
N_LOOP_BACK="$N_E2E_FIX"

if [ "$PHASE_9_RAN" = "true" ] && [ "$E2E_RESULTS" != "null" ]; then
  # 1. Aggregate từ e2e-results.json summary block
  N_EXEC=$(echo "$E2E_RESULTS" | jq -r '.summary.n_executed // 0')
  N_PASS=$(echo "$E2E_RESULTS" | jq -r '.summary.n_pass // 0')
  N_AUTO_CORRECTED=$(echo "$E2E_RESULTS" | jq -r '.summary.n_auto_corrected // 0')
  N_FAIL=$(echo "$E2E_RESULTS" | jq -r '.summary.n_fail // 0')
  N_QUARANTINED=$(echo "$E2E_RESULTS" | jq -r '.summary.n_quarantined // 0')
  N_CROSS_MODULE=$(echo "$E2E_RESULTS" | jq -r '.summary.n_cross_module // 0')
  PHASE9_DURATION_MS=$(echo "$E2E_RESULTS" | jq -r '.summary.phase9_duration_ms // 0')

  # 2. N_SYNTH từ scenarios-manifest.json (canonical), fallback từ e2e-results n_total
  if [ "$SCENARIOS_MANIFEST" != "null" ]; then
    N_SYNTH=$(echo "$SCENARIOS_MANIFEST" | jq -r '.total_valid // .total_synthesized // 0')
  else
    N_SYNTH=$(echo "$E2E_RESULTS" | jq -r '.summary.n_total // 0')
  fi

  # 3. Top failure types từ enriched e2e-results (Phase 10 enrich .scenarios[].failure_type)
  E2E_TOP_FAILURE_TYPES=$(echo "$E2E_RESULTS" | jq -r '
    [.scenarios[]? | select(.failure_type != null and .failure_type != "") | .failure_type]
    | reduce .[] as $t ({}; .[$t] = (.[$t] // 0) + 1)
    | to_entries | sort_by(-.value) | .[:3] | map(.key) | join(", ")
    // "—"')
  [ -z "$E2E_TOP_FAILURE_TYPES" ] && E2E_TOP_FAILURE_TYPES="—"

  # 4. Phase 10 duration nếu chạy (parse từ Phase10-report.md hoặc integrity-status.phase10_summary)
  if [ "$PHASE_10_RAN" = "true" ]; then
    PHASE10_DURATION_MS=$(echo "$INTEGRITY_STATUS" | jq -r '
      (.phase10_summary // {}) as $p10 |
      if $p10.completed_at and $p10.triggered_at then
        ((($p10.completed_at | fromdateiso8601) - ($p10.triggered_at | fromdateiso8601)) * 1000 | floor)
      else 0 end' 2>/dev/null || echo 0)
  fi

  # 5. Build E2E_SECTION_BLOCK (≤15 dòng — render trong section "3.5. E2E Execution Summary")
  PHASE9_DURATION_HUMAN=$(awk -v ms="$PHASE9_DURATION_MS" 'BEGIN{s=ms/1000; m=int(s/60); s=s-m*60; printf "%dm%02ds", m, s}')
  PHASE10_DURATION_HUMAN=$(awk -v ms="$PHASE10_DURATION_MS" 'BEGIN{s=ms/1000; m=int(s/60); s=s-m*60; printf "%dm%02ds", m, s}')

  E2E_SECTION_BLOCK=$(cat <<EOF
## 3.5. E2E Execution Summary (Playwright runtime verify)

| Metric | Value |
|--------|-------|
| Scenarios sinh (CD41) | ${N_SYNTH} |
| Scenarios executed | ${N_EXEC} |
| PASS | ${N_PASS} |
| Auto-corrected | ${N_AUTO_CORRECTED} |
| FAIL | ${N_FAIL} |
| Quarantined | ${N_QUARANTINED} |
| Cross-module | ${N_CROSS_MODULE}/${N_EXEC} |
| Thời gian (P9+P10) | ${PHASE9_DURATION_HUMAN} + ${PHASE10_DURATION_HUMAN} |
| Loop-back gap-suggestions | +${N_LOOP_BACK} |

**Top 3 failure types:** ${E2E_TOP_FAILURE_TYPES}
**Evidence:** [phase9-e2e-execute/screenshots/](../phase9-e2e-execute/screenshots/) · **Resolution:** [phase10-e2e-resolution/resolution-report.md](../phase10-e2e-resolution/resolution-report.md)
EOF
)

  # 6. Update Khuyến nghị action cho E2E (consumer hint)
  if [ "$N_FAIL" -gt 0 ]; then
    ACTION_FOR_E2E="$N_FAIL scenarios FAIL — xem resolution-report.md trước khi release"
  elif [ "$N_AUTO_CORRECTED" -gt 0 ]; then
    ACTION_FOR_E2E="$N_AUTO_CORRECTED scenarios auto-corrected — verify regression test"
  elif [ "$N_QUARANTINED" -gt 0 ]; then
    ACTION_FOR_E2E="$N_QUARANTINED scenarios flaky quarantined — review trước khi re-enable"
  else
    ACTION_FOR_E2E="ALL ${N_EXEC} scenarios PASS — runtime verify OK"
  fi
fi

export E2E_SECTION_BLOCK N_SYNTH N_EXEC N_PASS N_AUTO_CORRECTED N_FAIL \
       N_QUARANTINED N_CROSS_MODULE PHASE9_DURATION_MS PHASE10_DURATION_MS \
       N_LOOP_BACK E2E_TOP_FAILURE_TYPES ACTION_FOR_E2E N_E2E_FIX

# ─────────────────────────────────────────────────────────────
# 8.3.7 — Populate template (single sed pass cho scalar placeholders)
# ─────────────────────────────────────────────────────────────
MODULES_LIST=$(echo "${SCOPE_MODULES:-—}" | sed 's/|/, /g')
THRESHOLD=$(echo "$COVERAGE_MATRIX" | jq -r '.threshold_overall_pct // 80')
DURATION_TOTAL="${DURATION_TOTAL:-—}"

sed -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
    -e "s|\[SCOPE_TYPE\]|$SCOPE_TYPE|g" \
    -e "s|\[MODULES\]|$MODULES_LIST|g" \
    -e "s|\[PROFILE\]|$PROFILE|g" \
    -e "s|\[THRESHOLD\]|$THRESHOLD|g" \
    -e "s|\[DURATION\]|$DURATION_TOTAL|g" \
    -e "s|\[STATUS_PASS_WARN_FAIL\]|$FINAL_STATUS|g" \
    -e "s|\[OVERALL_PCT\]|$(printf "%.1f" "$OVERALL_PCT")|g" \
    -e "s|\[CORE_AVG_PCT\]|${CORE_AVG_PCT:-0}|g" \
    -e "s|\[CORE_STATUS\]|${CORE_STATUS_ICON} ${CORE_STATUS}|g" \
    -e "s|\[CORE_VIOLATIONS\]|${CORE_VIOLATIONS:-0}|g" \
    -e "s|\[FE_AVG_PCT\]|${FRONTEND_AVG_PCT:-0}|g" \
    -e "s|\[FE_STATUS\]|${FE_STATUS_ICON} ${FRONTEND_STATUS}|g" \
    -e "s|\[FE_VIOLATIONS\]|${FRONTEND_VIOLATIONS:-0}|g" \
    -e "s|\[BE_AVG_PCT\]|${BACKEND_AVG_PCT:-0}|g" \
    -e "s|\[BE_STATUS\]|${BE_STATUS_ICON} ${BACKEND_STATUS}|g" \
    -e "s|\[BE_VIOLATIONS\]|${BACKEND_VIOLATIONS:-0}|g" \
    -e "s|\[UX_AVG_PCT\]|${UX_AVG_PCT:-0}|g" \
    -e "s|\[UX_STATUS\]|${UX_STATUS_ICON} ${UX_STATUS}|g" \
    -e "s|\[UX_VIOLATIONS\]|${UX_VIOLATIONS:-0}|g" \
    -e "s|\[LOGISTICS_AVG_PCT\]|${LOGISTICS_AVG_PCT:-0}|g" \
    -e "s|\[LOGISTICS_STATUS\]|${LOGISTICS_STATUS_ICON} ${LOGISTICS_STATUS}|g" \
    -e "s|\[LOGISTICS_VIOLATIONS\]|${LOGISTICS_VIOLATIONS:-0}|g" \
    -e "s|\[COMPLIANCE_AVG_PCT\]|${COMPLIANCE_AVG_PCT:-0}|g" \
    -e "s|\[COMPLIANCE_STATUS\]|${COMPLIANCE_STATUS_ICON} ${COMPLIANCE_STATUS}|g" \
    -e "s|\[COMPLIANCE_VIOLATIONS\]|${COMPLIANCE_VIOLATIONS:-0}|g" \
    -e "s|\[IMPL_AVG_PCT\]|${IMPLEMENTATION_AVG_PCT:-0}|g" \
    -e "s|\[IMPL_STATUS\]|${IMPL_STATUS_ICON} ${IMPLEMENTATION_STATUS}|g" \
    -e "s|\[IMPL_VIOLATIONS\]|${IMPLEMENTATION_VIOLATIONS:-0}|g" \
    -e "s|\[W1_LANES_LIST\]|$W1_LANES_LIST|g" \
    -e "s|\[W1_PASS\]|$W1_PASS|g" \
    -e "s|\[W1_FAIL\]|$W1_FAIL|g" \
    -e "s|\[W1_DURATION\]|$W1_DURATION|g" \
    -e "s|\[W2_LANES_LIST\]|$W2_LANES_LIST|g" \
    -e "s|\[W2_PASS\]|$W2_PASS|g" \
    -e "s|\[W2_FAIL\]|$W2_FAIL|g" \
    -e "s|\[W2_DURATION\]|$W2_DURATION|g" \
    -e "s|\[W3_LANES_LIST\]|$W3_LANES_LIST|g" \
    -e "s|\[W3_PASS\]|$W3_PASS|g" \
    -e "s|\[W3_FAIL\]|$W3_FAIL|g" \
    -e "s|\[W3_DURATION\]|$W3_DURATION|g" \
    -e "s|\[TOP_N\]|$ACTUAL_TOP_COUNT|g" \
    -e "s|\[N_TOTAL\]|$N_TOTAL|g" \
    -e "s|\[N1\]|$N1|g" \
    -e "s|\[N2\]|$N2|g" \
    -e "s|\[N3\]|$N3|g" \
    -e "s|\[N4\]|$N4|g" \
    -e "s|\[N_FILES\]|$N_FILES|g" \
    -e "s|\[SINCE_REF\]|$SINCE_REF|g" \
    -e "s|\[N_MODULES\]|$N_MODULES|g" \
    -e "s|\[ACTION_LOGISTICS_COMPLIANCE\]|$ACTION_LOGISTICS_COMPLIANCE|g" \
    -e "s|\[ACTION_FOR_VERIFY_SYNC\]|$ACTION_FOR_VERIFY_SYNC|g" \
    -e "s|\[ACTION_FOR_FIX_BUGS\]|$ACTION_FOR_FIX_BUGS|g" \
    -e "s|\[ACTION_FOR_IMPLEMENT_FEATURE\]|$ACTION_FOR_IMPLEMENT_FEATURE|g" \
    -e "s|\[ACTION_FOR_E2E\]|$ACTION_FOR_E2E|g" \
    -e "s|\[N_E2E_FIX\]|${N_E2E_FIX:-0}|g" \
    "$TPL" > "$REPORT.tmp.$$"

# Strip template metadata HTML comment block (delete_before_write)
# v3: chỉ strip block đầu (_schema_notes header) — KHÔNG strip block cuối E2E_SECTION TEMPLATE
# vì cần giữ section template reference (tránh false-strip). Block cuối ở dòng 65-85 sau placeholder
# [E2E_SECTION] — sẽ replace tự nhiên qua awk insert nên không bị render lại trong output cuối.
awk 'BEGIN{skip=0} /^<!--$/{skip=1; next} /^-->$/{skip=0; next} !skip{print}' \
  "$REPORT.tmp.$$" > "$REPORT.tmp2.$$"

# Insert multi-line [TOP_VIOLATIONS_LIST] block via awk (preserves newlines)
awk -v vio="$TOP_VIOLATIONS_LIST" \
    '/\[TOP_VIOLATIONS_LIST\]/{print vio; next} {print}' \
    "$REPORT.tmp2.$$" > "$REPORT.tmp3.$$"

# v3 NEW: Insert multi-line [E2E_SECTION] block via awk (preserves newlines)
# Nếu PHASE_9_RAN=false → E2E_SECTION_BLOCK="" → placeholder bị replace bằng chuỗi rỗng (section bỏ qua)
awk -v sec="$E2E_SECTION_BLOCK" \
    '/\[E2E_SECTION\]/{print sec; next} {print}' \
    "$REPORT.tmp3.$$" > "$REPORT.tmp4.$$"

# Atomic write
mv "$REPORT.tmp4.$$" "$REPORT"
rm -f "$REPORT.tmp.$$" "$REPORT.tmp2.$$" "$REPORT.tmp3.$$"

# Verify ≤55 v2 / ≤70 dòng v3 max bound (E084)
REPORT_LINES=$(wc -l < "$REPORT")
MAX_BOUND=55
[ "$PHASE_9_RAN" = "true" ] && MAX_BOUND=70
[ "$REPORT_LINES" -le "$MAX_BOUND" ] || log_warn "E084" "integrity-report.md >$MAX_BOUND dòng max bound v3 ($REPORT_LINES) — truncating"

# Verify 0 leftover placeholders (CORE-031 strict check)
LEFTOVER=$(grep -cE '\[[A-Z_]+\]' "$REPORT" 2>/dev/null || echo 0)
if [ "$LEFTOVER" -gt 0 ]; then
  log_warn "E084" "integrity-report.md có $LEFTOVER placeholder chưa populate — check sed coverage"
fi
```

### Step 8.4 — Build `integrity-impact.json` v3 (cross-skill artifact, schema v3 backward-compat read v1+v2+v3)

```bash
TARGET="$SESSION_DIR/phase8-report/integrity-impact.json"
TPL=".claude/skills/workflow/wf-cmi/templates/integrity-impact.json"
strip_template_metadata "$TPL" "$TARGET"

# ─────────────────────────────────────────────────────────────
# 8.4.1 — coverage_matrix_summary (v1 field, preserved cho backward-compat)
# ─────────────────────────────────────────────────────────────
COVERAGE_SUMMARY=$(jq -n --argjson op "$OVERALL_PCT" --arg os "$OVERALL_STATUS" \
                   --argjson m "$COVERAGE_MATRIX" --arg pr "$PROFILE" \
                   '{
                      overall_pct: $op,
                      below_threshold_dims: ([$m.dimensions | to_entries[] |
                                              select(.value.status == "FAIL_THRESHOLD") | .key]),
                      status: $os,
                      threshold_per_dim_pct: 80,
                      threshold_overall_pct_per_profile: {quick: 60, standard: 80, deep: 95, exhaustive: 100}
                    }')

# ─────────────────────────────────────────────────────────────
# 8.4.2 — violations array — top 10 severity-weighted (v2 expand từ v1 chỉ MUST)
# ─────────────────────────────────────────────────────────────
VIOLATIONS_ARR=$(echo "$SIGNALS_AGG" | jq --arg sd "$SESSION_DIR" '
  def sev_weight: if . == "MUST" then 4 elif . == "HIGH" then 3 elif . == "MEDIUM" then 2 elif . == "LOW" then 1 else 0 end;
  [.[] | {
    id: ("CMI-V-" + ((.fingerprint // "00000000") | .[0:8])),
    dim: .dim,
    invariant_id: (.rule_id // null),
    severity: (.severity // "LOW"),
    sev_w: ((.severity // "LOW") | sev_weight),
    rule: (.message // ""),
    affected_modules: (.affected_modules // []),
    affected_files: ((.evidence // []) | map(.file // "")),
    suggested_fix_ref: ($sd + "/phase7-gap-cdg/suggestions/" + (.rule_id // "unknown") + "-fix.md")
  }]
  | sort_by(-.sev_w, .dim, .invariant_id)
  | map(del(.sev_w))
')

# ─────────────────────────────────────────────────────────────
# 8.4.3 — lanes_v2 (v2 field, v3 thêm CD41 vào active nếu deep|exhaustive + --exec-scenarios)
# Canonical lane sets từ _contract.json.lanes_defined
# ─────────────────────────────────────────────────────────────
# Active v2 = 26 CDs (CD1-CD7, CD9, CD11, CD13, CD15-CD18, CD23-CD26, CD28-CD31, CD37-CD40)
# v3: CD41 thêm vào active nếu profile=deep|exhaustive (CD41 lane đã dispatch ở Wave 3)
LANES_ACTIVE_V2='["CD1","CD2","CD3","CD4","CD5","CD6","CD7","CD9","CD11","CD13","CD15","CD16","CD17","CD18","CD23","CD24","CD25","CD26","CD28","CD29","CD30","CD31","CD37","CD38","CD39","CD40"]'
LANES_SKIPPED_V2='["CD8","CD10","CD12","CD14","CD19","CD20","CD21","CD22","CD27"]'
LANES_SKELETON_V2='["CD32","CD33","CD34","CD35","CD36"]'

# Filter active lanes theo profile (chỉ count lanes thực sự được dispatch)
ACTUAL_DISPATCHED=$(echo "$COVERAGE_MATRIX" | jq -c '
  [.dimensions | to_entries[] | select(.value.status != "SKIPPED" and .value.status != "PENDING") | .key]
')

LANES_V2=$(jq -n --argjson active "$LANES_ACTIVE_V2" --argjson skipped "$LANES_SKIPPED_V2" \
              --argjson skeleton "$LANES_SKELETON_V2" --argjson dispatched "$ACTUAL_DISPATCHED" \
  '{
     active: $dispatched,
     skipped: $skipped,
     skeleton: $skeleton,
     total_active_count: ($dispatched | length),
     total_skipped_count: ($skipped | length),
     total_skeleton_count: ($skeleton | length)
   }')

# ─────────────────────────────────────────────────────────────
# 8.4.4 — wave_breakdown (NEW v2, từ wave-status.json)
# ─────────────────────────────────────────────────────────────
WAVE_BREAKDOWN='{}'
if [ -f "$SESSION_DIR/phase4-coverage/wave-status.json" ]; then
  WAVE_BREAKDOWN=$(jq '{
    wave_1: {
      lane_count: (.wave_1.lane_count // 0),
      pass_count: (.wave_1.pass_count // 0),
      fail_count: (.wave_1.fail_count // 0),
      timeout_count: (.wave_1.timeout_count // 0),
      skip_count: (.wave_1.skip_count // 0),
      overall_pct: ((.wave_1.pass_count // 0) * 100 / (if (.wave_1.lane_count // 0) == 0 then 1 else (.wave_1.lane_count // 0) end) | . * 10 | floor / 10),
      gate_status: (.wave_1.gate_status // "PENDING"),
      description: "Wave 1 — Graphs (10 lanes max: CD1-CD7, CD11, CD16, CD17)"
    },
    wave_2: {
      lane_count: (.wave_2.lane_count // 0),
      pass_count: (.wave_2.pass_count // 0),
      fail_count: (.wave_2.fail_count // 0),
      timeout_count: (.wave_2.timeout_count // 0),
      skip_count: (.wave_2.skip_count // 0),
      overall_pct: ((.wave_2.pass_count // 0) * 100 / (if (.wave_2.lane_count // 0) == 0 then 1 else (.wave_2.lane_count // 0) end) | . * 10 | floor / 10),
      gate_status: (.wave_2.gate_status // "PENDING"),
      description: "Wave 2 — Cross-layer (10 lanes max: CD13, CD15, CD18, CD23-CD25, CD28, CD30, CD31, CD37)"
    },
    wave_3: {
      lane_count: (.wave_3.lane_count // 0),
      pass_count: (.wave_3.pass_count // 0),
      fail_count: (.wave_3.fail_count // 0),
      timeout_count: (.wave_3.timeout_count // 0),
      skip_count: (.wave_3.skip_count // 0),
      overall_pct: ((.wave_3.pass_count // 0) * 100 / (if (.wave_3.lane_count // 0) == 0 then 1 else (.wave_3.lane_count // 0) end) | . * 10 | floor / 10),
      gate_status: (.wave_3.gate_status // "PENDING"),
      description: "Wave 3 — Final cross-ref (6 lanes: CD9, CD26, CD29, CD38, CD39, CD40)"
    }
  }' "$SESSION_DIR/phase4-coverage/wave-status.json")
fi

# ─────────────────────────────────────────────────────────────
# 8.4.5 — group_breakdown (NEW v2, từ Step 8.3 computed values)
# ─────────────────────────────────────────────────────────────
GROUP_BREAKDOWN=$(jq -n \
  --argjson core_pct "${CORE_AVG_PCT:-0}" --arg core_st "$CORE_STATUS" --argjson core_v "${CORE_VIOLATIONS:-0}" \
  --argjson fe_pct "${FRONTEND_AVG_PCT:-0}" --arg fe_st "$FRONTEND_STATUS" --argjson fe_v "${FRONTEND_VIOLATIONS:-0}" \
  --argjson be_pct "${BACKEND_AVG_PCT:-0}" --arg be_st "$BACKEND_STATUS" --argjson be_v "${BACKEND_VIOLATIONS:-0}" \
  --argjson ux_pct "${UX_AVG_PCT:-0}" --arg ux_st "$UX_STATUS" --argjson ux_v "${UX_VIOLATIONS:-0}" \
  --argjson log_pct "${LOGISTICS_AVG_PCT:-0}" --arg log_st "$LOGISTICS_STATUS" --argjson log_v "${LOGISTICS_VIOLATIONS:-0}" \
  --argjson com_pct "${COMPLIANCE_AVG_PCT:-0}" --arg com_st "$COMPLIANCE_STATUS" --argjson com_v "${COMPLIANCE_VIOLATIONS:-0}" \
  --argjson imp_pct "${IMPLEMENTATION_AVG_PCT:-0}" --arg imp_st "$IMPLEMENTATION_STATUS" --argjson imp_v "${IMPLEMENTATION_VIOLATIONS:-0}" \
  '{
     core: {lane_ids: ["CD1","CD2","CD3","CD4","CD5","CD6","CD7","CD9"], lane_count: 8, avg_coverage_pct: $core_pct, status: $core_st, violations_count: $core_v},
     frontend: {lane_ids: ["CD11","CD13","CD15"], lane_count: 3, avg_coverage_pct: $fe_pct, status: $fe_st, violations_count: $fe_v},
     backend: {lane_ids: ["CD16","CD17","CD18"], lane_count: 3, avg_coverage_pct: $be_pct, status: $be_st, violations_count: $be_v},
     ux: {lane_ids: ["CD23","CD24","CD25","CD26"], lane_count: 4, avg_coverage_pct: $ux_pct, status: $ux_st, violations_count: $ux_v},
     logistics: {lane_ids: ["CD28","CD30","CD31"], lane_count: 3, avg_coverage_pct: $log_pct, status: $log_st, violations_count: $log_v, critical: true, marker: "★★★"},
     compliance: {lane_ids: ["CD29","CD37"], lane_count: 2, avg_coverage_pct: $com_pct, status: $com_st, violations_count: $com_v, critical: true, marker: "★★★"},
     implementation: {lane_ids: ["CD38","CD39","CD40"], lane_count: 3, avg_coverage_pct: $imp_pct, status: $imp_st, violations_count: $imp_v, marker: "★"}
   }')

# ─────────────────────────────────────────────────────────────
# 8.4.6 — logistics_critical_signals_count (NEW v2)
# Aggregate signals từ 7 logistics-critical lanes
# ─────────────────────────────────────────────────────────────
LOGISTICS_CRITICAL_LANES="CD28 CD30 CD31 CD37 CD38 CD39 CD40"
LCS_BY_LANE_JSON='{}'
LCS_TOTAL=0
LCS_MUST=0
for dim in $LOGISTICS_CRITICAL_LANES; do
  count=$(echo "$SIGNALS_AGG" | jq --arg d "$dim" '[.[] | select(.dim == $d)] | length')
  must_count=$(echo "$SIGNALS_AGG" | jq --arg d "$dim" '[.[] | select(.dim == $d and .severity == "MUST")] | length')
  LCS_BY_LANE_JSON=$(echo "$LCS_BY_LANE_JSON" | jq --arg k "$dim" --argjson v "$count" '. + {($k): $v}')
  LCS_TOTAL=$((LCS_TOTAL + count))
  LCS_MUST=$((LCS_MUST + must_count))
done

LOGISTICS_CRITICAL=$(jq -n --argjson total "$LCS_TOTAL" --argjson must "$LCS_MUST" \
                            --argjson by_lane "$LCS_BY_LANE_JSON" \
  '{
     total: $total,
     by_lane: $by_lane,
     must_severity_count: $must,
     note: "Aggregate signals từ 7 logistics-critical lanes (CD28/CD30/CD31/CD37/CD38/CD39/CD40). wf-prepare-deployment dùng must_severity_count > 0 để BLOCK release."
   }')

# ─────────────────────────────────────────────────────────────
# 8.4.6b — v3 NEW: e2e_execution_summary + scenarios_artifacts populate
# 2 fields v3 — null/[] default nếu Phase 9 KHÔNG chạy (preserve backward-compat)
# ─────────────────────────────────────────────────────────────
E2E_EXEC_SUMMARY='null'
SCENARIOS_ARTIFACTS='[]'

if [ "$PHASE_9_RAN" = "true" ] && [ "$E2E_RESULTS" != "null" ]; then
  # 1. e2e_execution_summary object — từ Step 8.3.6b computed vars
  TOP_FAIL_TYPES_JSON=$(echo "$E2E_RESULTS" | jq '
    [.scenarios[]? | select(.failure_type != null and .failure_type != "") | .failure_type]
    | reduce .[] as $t ({}; .[$t] = (.[$t] // 0) + 1)
    | to_entries | sort_by(-.value) | .[:3] | map(.key)')

  E2E_EXEC_SUMMARY=$(jq -n \
    --argjson synth "${N_SYNTH:-0}" \
    --argjson exec "${N_EXEC:-0}" \
    --argjson pass "${N_PASS:-0}" \
    --argjson autoc "${N_AUTO_CORRECTED:-0}" \
    --argjson fail "${N_FAIL:-0}" \
    --argjson quar "${N_QUARANTINED:-0}" \
    --argjson xmod "${N_CROSS_MODULE:-0}" \
    --argjson p9ms "${PHASE9_DURATION_MS:-0}" \
    --argjson p10ms "${PHASE10_DURATION_MS:-0}" \
    --argjson lb "${N_LOOP_BACK:-0}" \
    --argjson tft "$TOP_FAIL_TYPES_JSON" \
    '{
       exec_enabled: true,
       scenarios_synthesized: $synth,
       scenarios_executed: $exec,
       pass_count: $pass,
       auto_corrected_count: $autoc,
       fail_count: $fail,
       quarantined_count: $quar,
       cross_module_count: $xmod,
       phase9_duration_ms: $p9ms,
       phase10_duration_ms: $p10ms,
       loop_back_suggestions_count: $lb,
       top_failure_types: $tft
     }')

  # 2. scenarios_artifacts[] — 1 entry per scenario trong e2e-results.json scenarios[]
  #    Inherit metadata từ manifest entry tương ứng + execution_status + screenshot_paths + resolution_path
  SCENARIOS_ARTIFACTS=$(echo "$E2E_RESULTS" | jq --argjson manifest "${SCENARIOS_MANIFEST:-null}" '
    def manifest_entry($sid):
      if $manifest == null then null
      else ($manifest.scenarios // [] | map(select(.scenario_id == $sid)) | .[0] // null)
      end;

    [.scenarios[]? | . as $s | {
      scenario_id: $s.scenario_id,
      scenario_file: ($s.scenario_file // ""),
      feat_id_inferred: (manifest_entry($s.scenario_id) | (.feat_id // .feat_id_inferred // null)),
      modules_involved: ($s.modules_visited // (manifest_entry($s.scenario_id) | (.modules_involved // [])) // []),
      cross_module: ($s.cross_module // false),
      source_violation_ids: (if ($s.source_violation_id // "") == "" then [] else [$s.source_violation_id] end),
      source_invariant_id: ($s.source_invariant_id // null),
      source_dim: ($s.source_dim // (manifest_entry($s.scenario_id) | (.source_dim // null))),
      severity: ($s.severity // (manifest_entry($s.scenario_id) | (.severity // "LOW"))),
      execution_status: ($s.execution_status // "NOT_EXECUTED"),
      screenshot_paths: (
        [$s.evidence.screenshot_path // empty]
        | map(select(. != null and . != ""))
      ),
      resolution_path: ($s.phase10_resolution_ref // null)
    }]')

  log_phase_event "phase8" "INFO" "{\"v3_fields_populated\":true,\"scenarios_count\":$(echo "$SCENARIOS_ARTIFACTS" | jq 'length'),\"fail_count\":${N_FAIL:-0}}"
fi

# ─────────────────────────────────────────────────────────────
# 8.4.7 — schema_version_compat (v3 bump: readable_by mở rộng [v1, v2, v3])
# ─────────────────────────────────────────────────────────────
SCHEMA_COMPAT='{
  "current": "integrity-impact-v3",
  "readable_by": ["integrity-impact-v1", "integrity-impact-v2", "integrity-impact-v3"],
  "v1_compat_note": "All v1 fields preserved — v1 readers ignore lanes_v2/wave_breakdown/group_breakdown/logistics_critical_signals_count/e2e_execution_summary/scenarios_artifacts. Consumer detect via $schema field.",
  "v2_compat_note": "All v2 fields preserved — v2 readers ignore e2e_execution_summary/scenarios_artifacts. Consumer detect via $schema field.",
  "v3_new_fields": ["e2e_execution_summary", "scenarios_artifacts"],
  "v3_compat_note": "v3 fields are nullable. When --exec-scenarios=off: e2e_execution_summary=null + scenarios_artifacts=[]. Consumer downstream can safely consume v3 artifact với v1/v2 reader logic — KHÔNG break."
}'

# ─────────────────────────────────────────────────────────────
# 8.4.8 — regression_scope (v1 field, preserved)
# ─────────────────────────────────────────────────────────────
REGRESSION_SCOPE='{"changed_files_count":0,"predicted_affected_modules":[],"test_plan_count":0,"mode":null,"since_ref":null}'
if [ -f "$SESSION_DIR/phase6-regression/regression-map.json" ] && \
   jq -e '.skipped != true' "$SESSION_DIR/phase6-regression/regression-map.json" >/dev/null 2>&1; then
  REGRESSION_SCOPE=$(jq '{
    changed_files_count: (.changed_files | length),
    predicted_affected_modules: (.predicted_impact.affected_modules | map(.module)),
    test_plan_count: (.predicted_impact.test_plan | length),
    mode: (.mode // null),
    since_ref: (.since_ref // null)
  }' "$SESSION_DIR/phase6-regression/regression-map.json")
fi

# ─────────────────────────────────────────────────────────────
# 8.4.9 — gap_artifacts_suggested (v1 field, preserved)
# ─────────────────────────────────────────────────────────────
GAP_ARTIFACTS=$(echo "$GAP_SUGGESTIONS" | jq '[.suggestions[]? | {
                  kind: .kind, id: .id,
                  path: (.target_path // .path // null),
                  status: (.final_status // "pending_user_accept"),
                  target: (.target_path // .target // null),
                  reason: (.reason // null)
                }]')

# ─────────────────────────────────────────────────────────────
# 8.4.10 — consumers_recommended_actions (v1 + v2 hints)
# v2 logic: prepare-deployment xem logistics_critical_signals_count + wave gate
# ─────────────────────────────────────────────────────────────
DEPLOY_BLOCK_REASON=""
if [ "$LCS_MUST" -gt 0 ]; then
  DEPLOY_BLOCK_REASON="BLOCK release: $LCS_MUST MUST violations trong logistics-critical lanes"
elif [ "$MUST_VIOLATIONS" -gt 0 ]; then
  DEPLOY_BLOCK_REASON="BLOCK release: $MUST_VIOLATIONS MUST violations toàn hệ"
elif [ "$(awk -v a="$OVERALL_PCT" -v b="95" 'BEGIN{print (a<b)?1:0}')" = "1" ] && [ "$PROFILE" = "deep" ]; then
  DEPLOY_BLOCK_REASON="Coverage $OVERALL_PCT% < deep threshold 95% — KHÔNG recommend release"
else
  DEPLOY_BLOCK_REASON="Coverage $OVERALL_PCT% acceptable cho profile $PROFILE"
fi

CONSUMERS_ACTIONS=$(jq -n --arg fs "$FINAL_STATUS" --argjson mv "$MUST_VIOLATIONS" \
                    --argjson tv "$TOTAL_VIOLATIONS" --argjson lcs_m "$LCS_MUST" \
                    --arg op "$OVERALL_PCT" --arg pr "$PROFILE" --arg deploy "$DEPLOY_BLOCK_REASON" \
  '{
     "wf-verify-sync": ("Re-run --from-cmi để validate impl_status vs " + ($tv | tostring) + " violations + regression. (v1 reader: chỉ đọc violations[] + regression_scope)"),
     "wf-fix-bugs": (if $mv > 0 then ("Seed Phase 1 với " + ($mv | tostring) + " MUST violations — ưu tiên " + ($lcs_m | tostring) + " logistics-critical MUST") else "Healthy — no seed required" end),
     "wf-implement-feature": ("Warn nếu touch entities/modules trong violations[].affected_modules (" + ($mv | tostring) + " MUST violations). Check group_breakdown để biết nhóm nào cần chú ý."),
     "wf-prepare-deployment": $deploy
   }')

# ─────────────────────────────────────────────────────────────
# 8.4.11 — summary (v1 field, expanded với severity breakdown v2)
# ─────────────────────────────────────────────────────────────
HIGH_VIOLATIONS=$(echo "$SIGNALS_AGG" | jq '[.[] | select(.severity == "HIGH")] | length')
MEDIUM_VIOLATIONS=$(echo "$SIGNALS_AGG" | jq '[.[] | select(.severity == "MEDIUM")] | length')
LOW_VIOLATIONS=$(echo "$SIGNALS_AGG" | jq '[.[] | select(.severity == "LOW")] | length')
SUGG_TOTAL=$(echo "$GAP_SUGGESTIONS" | jq '.suggestions // [] | length')
SUGG_ACCEPTED=$(echo "$GAP_SUGGESTIONS" | jq '[.suggestions[]? | select(.final_status == "accepted")] | length')
SUGG_REJECTED=$(echo "$GAP_SUGGESTIONS" | jq '[.suggestions[]? | select(.final_status == "rejected")] | length')
MODULES_WITH_ISSUES=$(echo "$SIGNALS_AGG" | jq '[.[].affected_modules // [] | .[]] | unique')

SUMMARY=$(jq -n --argjson tv "$TOTAL_VIOLATIONS" --argjson mv "$MUST_VIOLATIONS" \
                --argjson hv "$HIGH_VIOLATIONS" --argjson medv "$MEDIUM_VIOLATIONS" --argjson lv "$LOW_VIOLATIONS" \
                --argjson st "$SUGG_TOTAL" --argjson sa "$SUGG_ACCEPTED" --argjson sr "$SUGG_REJECTED" \
                --argjson mwi "$MODULES_WITH_ISSUES" \
  '{
     violations_count: $tv,
     must_violations_count: $mv,
     high_violations_count: $hv,
     medium_violations_count: $medv,
     low_violations_count: $lv,
     suggestions_count: $st,
     accepted_suggestions_count: $sa,
     rejected_suggestions_count: $sr,
     modules_with_issues: $mwi
   }')

# ─────────────────────────────────────────────────────────────
# 8.4.12 — audit_chain (v1 field, preserved)
# ─────────────────────────────────────────────────────────────
get_git_commit_info  # set $GIT_COMMIT, $GIT_BRANCH
SOURCE_FILE="$SESSION_DIR/integrity-status.json"
CHECKSUM=$(compute_audit_chain_checksum "$SOURCE_FILE")

SCANNED_FILES_JSON='[]'
if [ -f "$SESSION_DIR/phase6-regression/regression-map.json" ] && \
   jq -e '.changed_files' "$SESSION_DIR/phase6-regression/regression-map.json" >/dev/null 2>&1; then
  SCANNED_FILES_JSON=$(jq '.changed_files' "$SESSION_DIR/phase6-regression/regression-map.json")
fi

SKIPPED_PHASES='[]'
case "$PHASES_DONE" in
  '[1,2,3,4,5,7]')   SKIPPED_PHASES='[{"phase": 6, "reason": "profile=quick OR no --since"}]' ;;
  '[1,2,3,4,5]')     SKIPPED_PHASES='[{"phase": 6, "reason": "E005 healthy"}, {"phase": 7, "reason": "E005 healthy"}]' ;;
esac

# ─────────────────────────────────────────────────────────────
# 8.4.13 — Final populate (single jq merge) — v3 schema bump
# Strict ordering preserved: $schema + skill + version + identifying fields trước,
# các breakdown v2 + violations + (v3) e2e_execution_summary/scenarios_artifacts + audit_chain sau
# ─────────────────────────────────────────────────────────────
jq --argjson cs "$COVERAGE_SUMMARY" \
   --argjson v "$VIOLATIONS_ARR" \
   --argjson lv2 "$LANES_V2" \
   --argjson wb "$WAVE_BREAKDOWN" \
   --argjson gb "$GROUP_BREAKDOWN" \
   --argjson lc "$LOGISTICS_CRITICAL" \
   --argjson sc "$SCHEMA_COMPAT" \
   --argjson rs "$REGRESSION_SCOPE" \
   --argjson ga "$GAP_ARTIFACTS" \
   --argjson ca "$CONSUMERS_ACTIONS" \
   --argjson sum "$SUMMARY" \
   --argjson e2es "$E2E_EXEC_SUMMARY" \
   --argjson sa "$SCENARIOS_ARTIFACTS" \
   --arg sid "$SESSION_ID" --arg pr "$PROFILE" --arg st "$SCOPE_TYPE" \
   --arg ts "$(date -Iseconds)" --arg fs "$FINAL_STATUS" \
   --arg ck "$CHECKSUM" --arg sf "$SOURCE_FILE" \
   --arg gc "$GIT_COMMIT" --arg gb "$GIT_BRANCH" \
   --arg ae "$AUTHOR_EMAIL" --arg an "$AUTHOR_NAME" \
   --argjson scf "$SCANNED_FILES_JSON" --argjson sp "$SKIPPED_PHASES" \
   --arg sr "${SINCE_REF:-}" \
   '. + {
      "$schema": "integrity-impact-v3",
      skill: "wf-cmi",
      skill_version: "3.0.0",
      session_id: $sid,
      generated_at: $ts,
      scope: {type: $st, modules: ((.scope.modules // []))},
      profile: $pr,
      final_status: $fs,
      schema_version_compat: $sc,
      lanes_v2: $lv2,
      wave_breakdown: $wb,
      group_breakdown: $gb,
      logistics_critical_signals_count: $lc,
      coverage_matrix_summary: $cs,
      violations: $v,
      regression_scope: $rs,
      gap_artifacts_suggested: $ga,
      consumers_recommended_actions: $ca,
      summary: $sum,
      e2e_execution_summary: $e2es,
      scenarios_artifacts: $sa,
      audit_chain: {
        source: $sf,
        checksum: $ck,
        git_commit: $gc,
        git_branch: $gb,
        author: {email: $ae, name: $an},
        scanned_files: $scf,
        since_ref: (if $sr == "" then null else $sr end),
        skipped_phases: $sp
      }
    }
    # v3: Cleanup template reference objects (_e2e_execution_summary_template, _scenarios_artifacts_template_entry)
    | del(._e2e_execution_summary_template, ._scenarios_artifacts_template_entry)
    ' "$TARGET" > "$TARGET.tmp.$$" && mv "$TARGET.tmp.$$" "$TARGET"

# Validate JSON + schema + v3 required fields (backward-compat: v2 fields preserved)
jq '.' "$TARGET" >/dev/null || die "E083" "integrity-impact.json invalid JSON"
jq -e '."$schema" == "integrity-impact-v3" and
       .skill_version == "3.0.0" and
       .lanes_v2.active != null and
       .wave_breakdown.wave_1 != null and
       .group_breakdown.logistics.critical == true and
       .logistics_critical_signals_count.total != null and
       (.schema_version_compat.readable_by | index("integrity-impact-v1")) != null and
       (.schema_version_compat.readable_by | index("integrity-impact-v2")) != null and
       (.schema_version_compat.readable_by | index("integrity-impact-v3")) != null and
       (has("e2e_execution_summary")) and
       (has("scenarios_artifacts")) and
       (.scenarios_artifacts | type == "array")' "$TARGET" >/dev/null \
  || die "E083" "integrity-impact.json v3 schema validation fail (missing v3 required fields or readable_by không đủ v1+v2+v3)"

# v3 conditional check: e2e_execution_summary null hoặc object đầy đủ
jq -e '.e2e_execution_summary == null or
       (.e2e_execution_summary | (has("exec_enabled") and has("scenarios_executed") and has("pass_count") and has("fail_count")))' "$TARGET" >/dev/null \
  || die "E083" "integrity-impact.json v3 e2e_execution_summary structure invalid"

# Validate audit_chain checksum
jq -e '.audit_chain.checksum != "" and .audit_chain.source != null' "$TARGET" >/dev/null \
  || { log_warn "E085" "audit_chain.checksum compute fail"; }
```

### Step 8.5 — Render Mermaid diagrams (nếu `--show-graphs`)

> Optional — chỉ render khi user explicit request via `--show-graphs`.

```bash
if [ "$SHOW_GRAPHS" = "true" ]; then
  # Append Mermaid blocks vào integrity-report.md
  REPORT="$SESSION_DIR/phase8-report/integrity-report.md"

  # Helper: render small Mermaid graph from JSON
  render_mermaid_graph() {
    local graph_file="$1"
    local graph_name="$2"
    echo ""
    echo "### $graph_name"
    echo '```mermaid'
    echo "graph LR"
    jq -r '(.nodes // .modules // .endpoints // .events // .workflows // .permissions // [])[]
            | "  \(.id // .name) --> ..."' "$graph_file" 2>/dev/null | head -20
    # ... edges (limit 20 to keep diagram readable)
    echo '```'
  }

  echo "" >> "$REPORT"
  echo "## 6 Graphs (rendered nếu --show-graphs)" >> "$REPORT"
  for g in entity-graph module-graph workflow-graph api-graph event-graph rbac-matrix; do
    f="$SESSION_DIR/phase2-discovery/${g}.json"
    [ -f "$f" ] && render_mermaid_graph "$f" "$g" >> "$REPORT" \
                || log_warn "E088" "Mermaid render fail for $g"
  done
fi
```

### Step 8.6 — CI mode output (nếu `--ci`)

> Post comment lên PR qua GitHub API.

```bash
if [ "$CI_MODE" = "true" ] && [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_REPOSITORY" ]; then
  # Generate compact JSON for PR comment
  PR_COMMENT_JSON=$(jq -c '{
    status: .final_status, coverage: .coverage_matrix_summary.overall_pct,
    violations: (.violations | length),
    regression_modules: (.regression_scope.predicted_affected_modules | length),
    recommendation: .consumers_recommended_actions["wf-prepare-deployment"]
  }' "$SESSION_DIR/phase8-report/integrity-impact.json")

  # Post via curl (use GitHub Actions native API)
  PR_NUMBER="${GITHUB_REF_NAME:-}"  # GHA sets PR# in GITHUB_REF
  if [ -n "$PR_NUMBER" ]; then
    BODY=$(jq -nc --arg c "## wf-cmi Integrity Check\n\`\`\`json\n$PR_COMMENT_JSON\n\`\`\`" \
           '{body: $c}')
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         -X POST "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" \
         -d "$BODY" >/dev/null \
      || log_warn "E089" "CI PR comment post fail"
  fi
fi
```

### Step 8.7 — Mark session COMPLETED trong `_index/sessions.jsonl`

```bash
INDEX=".mc-data/work/wf-cmi/_index/sessions.jsonl"

# APPEND completion event (vs overwrite — preserve history)
jq -nc --arg sid "$SESSION_ID" --arg st "completed" --arg ts "$(date -Iseconds)" \
       --arg fs "$FINAL_STATUS" \
   '{session_id: $sid, event: "completed", completed_at: $ts, final_status: $fs}' \
   >> "$INDEX"
```

### Step 8.8 — Write Phase8-report.md (CORE-028)

```bash
TPL=".claude/skills/workflow/wf-cmi/templates/Phase8-report.md"
REPORT="$SESSION_DIR/phase8-report/Phase8-report.md"

sed -e "s|\[FINAL_STATUS\]|$FINAL_STATUS|g" \
    -e "s|\[OVERALL_PCT\]|$(printf "%.1f" $OVERALL_PCT)|g" \
    -e "s|\[TOTAL_VIOLATIONS\]|$TOTAL_VIOLATIONS|g" \
    -e "s|\[AUTHOR_NAME\]|$AUTHOR_NAME|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    -e "s|\[INTEGRITY_REPORT_PATH\]|$SESSION_DIR/phase8-report/integrity-report.md|g" \
    -e "s|\[INTEGRITY_IMPACT_PATH\]|$SESSION_DIR/phase8-report/integrity-impact.json|g" \
    -e "s|\[STATUS\]|PASS|g" \
    "$TPL" > "$REPORT"
```

### Step 8.9 — Update integrity-status.json (final)

```bash
TARGET="$SESSION_DIR/integrity-status.json"
jq --arg fs "$FINAL_STATUS" --arg ts "$(date -Iseconds)" \
   '.phases_completed += [8] |
    .current_phase = 8 |
    .pipeline_status = "DONE" |
    .next_action = "completed" |
    .final_status = $fs |
    .completed_at = $ts |
    .lock_heartbeat_at = $ts' \
   "$TARGET" > "$TARGET.tmp.$$" && mv "$TARGET.tmp.$$" "$TARGET"
```

### Step 8.10 — Execution Trace COMPLETE (CORE-026)

```bash
log_phase_event "phase8" "COMPLETE" "{\"final_status\":\"$FINAL_STATUS\",\"duration_total_ms\":$TOTAL_DURATION_MS}"
```

### Step 8.11 — Release lock + cleanup heartbeat

> Trap đã đăng ký ở Phase 1 (`trap cleanup EXIT INT TERM`).

```bash
# Explicit cleanup (trap sẽ fire khi script exit)
release_write_lock business-invariants 2>/dev/null  # nếu còn giữ
release_read_lock business-invariants "$READER_ID" 2>/dev/null

cleanup  # release session lock + kill heartbeat daemon

log_phase_event "phase8" "INFO" "{\"session_finalized\":true}"
```

---

## §D POST-GATE (T1→T4 + Auto-Fix) — v3 check schema integrity-impact-v3

| Tier | Check | Auto-fix (max 3) |
|------|-------|------------------|
| T1 | `integrity-report.md` + `integrity-impact.json` + `Phase8-report.md` exist | Re-write |
| T2 | `integrity-impact.json` v3: `$schema = integrity-impact-v3`, `skill_version = "3.0.0"`, `audit_chain.{source,checksum,git_commit,author}`, **v2 fields preserved** (`lanes_v2.active`, `wave_breakdown.wave_1`, `group_breakdown.logistics.critical`, `logistics_critical_signals_count.total`), **v3 readable_by** (`schema_version_compat.readable_by` chứa cả `"integrity-impact-v1"` + `"integrity-impact-v2"` + `"integrity-impact-v3"`), **v3 NEW fields** (`e2e_execution_summary` (object hoặc null) + `scenarios_artifacts[]` (array)) | Re-build từ template |
| T3 | `integrity-report.md` ≤55 dòng v2 base (Phase 9 không chạy) / ≤70 dòng v3 max bound (Phase 9 đã chạy với E2E section đầy đủ) + 0 leftover placeholders | Re-format, truncate, re-populate placeholders |
| T4 | Cross-skill artifact paths khớp `_contract.json.produces_for{}` (4 consumers: wf-verify-sync/wf-fix-bugs/wf-implement-feature/wf-prepare-deployment) | Re-validate paths |
| T5 (v3 NEW) | E2E section conditional render: nếu `PHASE_9_RAN=true` → integrity-report.md PHẢI có dòng "## 3.5. E2E Execution Summary"; nếu `PHASE_9_RAN=false` → KHÔNG có section này | Re-render E2E_SECTION block |

```bash
post_gate_phase8() {
  local target="$SESSION_DIR/phase8-report/integrity-impact.json"
  local report="$SESSION_DIR/phase8-report/integrity-report.md"
  local retry=0
  while [ "$retry" -lt 3 ]; do
    # T1
    [ -f "$target" ] && [ -f "$report" ] && [ -f "$SESSION_DIR/phase8-report/Phase8-report.md" ] \
      || { rewrite_outputs; retry=$((retry+1)); continue; }

    # T2 — schema v3 + audit_chain + v2 fields preserved + v3 fields present + readable_by v1+v2+v3
    jq -e '."$schema" == "integrity-impact-v3" and
           .skill_version == "3.0.0" and
           .audit_chain.source != null and
           .audit_chain.checksum != null and .audit_chain.checksum != "" and
           .audit_chain.git_commit != null and
           .audit_chain.author.email != null and
           .lanes_v2.active != null and
           .wave_breakdown.wave_1 != null and
           .group_breakdown.logistics.critical == true and
           .logistics_critical_signals_count.total != null and
           (.schema_version_compat.readable_by | index("integrity-impact-v1")) != null and
           (.schema_version_compat.readable_by | index("integrity-impact-v2")) != null and
           (.schema_version_compat.readable_by | index("integrity-impact-v3")) != null and
           has("e2e_execution_summary") and
           has("scenarios_artifacts") and
           (.scenarios_artifacts | type == "array")' "$target" >/dev/null \
      || { rebuild_from_template; retry=$((retry+1)); continue; }

    # T3 — report ≤55 dòng v2 base / ≤70 dòng v3 max bound + 0 leftover placeholders
    REPORT_LINES=$(wc -l < "$report")
    MAX_LINES=55
    [ "$PHASE_9_RAN" = "true" ] && MAX_LINES=70
    if [ "$REPORT_LINES" -gt "$MAX_LINES" ]; then
      head -"$MAX_LINES" "$report" > "$report.tmp" && mv "$report.tmp" "$report"
      log_warn "E084" "Truncated integrity-report.md to $MAX_LINES dòng v3 max bound"
    fi
    LEFTOVER=$(grep -cE '\[[A-Z_]+\]' "$report" 2>/dev/null || echo 0)
    if [ "$LEFTOVER" -gt 0 ]; then
      log_warn "E084" "integrity-report.md có $LEFTOVER placeholder chưa populate"
      retry=$((retry+1))
      rewrite_outputs
      continue
    fi

    # T4 — cross-skill paths khớp produces_for{}
    EXPECTED_PATH="$SESSION_DIR/phase8-report/integrity-impact.json"
    [ -f "$EXPECTED_PATH" ] || { log_warn "E086" "Cross-skill path mismatch"; retry=$((retry+1)); continue; }

    # T5 (v3 NEW) — E2E section conditional render
    if [ "$PHASE_9_RAN" = "true" ]; then
      if ! grep -q "^## 3.5\. E2E Execution Summary" "$report"; then
        log_warn "E084" "T5 fail: PHASE_9_RAN=true nhưng integrity-report.md KHÔNG có E2E Execution Summary section"
        retry=$((retry+1))
        rewrite_outputs
        continue
      fi
    else
      if grep -q "^## 3.5\. E2E Execution Summary" "$report"; then
        log_warn "E084" "T5 fail: PHASE_9_RAN=false nhưng integrity-report.md có E2E section (phải bỏ qua)"
        retry=$((retry+1))
        rewrite_outputs
        continue
      fi
    fi

    return 0
  done
  die "E001" "Phase 8 POST-GATE fail after 3 retries"
}
```

**On PASS:**
1. TodoWrite: Phase 8 = completed (ALL DONE)
2. Final user message:
   ```
   ✅ wf-cmi pipeline DONE — session $SESSION_ID
   📋 Report: $SESSION_DIR/phase8-report/integrity-report.md
   🔗 Cross-skill: $SESSION_DIR/phase8-report/integrity-impact.json
   
   Next step:
   - /wf-verify-sync --from-cmi
   - /wf-fix-bugs --from-cmi (nếu $MUST_VIOLATIONS > 0)
   - /wf-prepare-deployment --from-cmi
   - /status
   ```

---

## §E Phase Report Template (CORE-028) — v3 mention E2E section conditional

```markdown
## Phase 8: Báo cáo cuối + Cross-skill artifact v3 — PASS
Thời gian: 2026-05-17T14:55:05+07:00

**Đã làm:**
- Tổng hợp 7 phase outputs (+ v3: Phase 9-10 nếu --exec-scenarios) → báo cáo cuối tiếng Việt
- Sinh artifact cross-skill `integrity-impact.json` schema v3 (chain audit hash, git commit, branch, e2e_execution_summary, scenarios_artifacts)

**Kết quả:**
- Trạng thái cuối: WARN (coverage 82.5%, 3 vi phạm MUST, 2 E2E FAIL nếu --exec-scenarios)
- Báo cáo: [INTEGRITY_REPORT_PATH] (v3 có section E2E nếu Phase 9 chạy)
- Artifact downstream: [INTEGRITY_IMPACT_PATH] (schema v3 backward-compat v1+v2+v3)

**Tiếp theo:**
- /wf-fix-bugs --from-cmi (fix 3 MUST violations + 2 E2E FAIL)
- /wf-verify-sync --from-cmi (re-verify req-to-code)
- /wf-prepare-deployment --from-cmi (block nếu logistics-critical MUST hoặc e2e_execution_summary.fail_count > 0)
```

---

## §F Error Code Quick Reference (Phase 8 namespace E080-E089)

| Code | Severity | Description | Auto-fix |
|------|---------|-------------|----------|
| E080 | high | Pipeline incomplete (Phase 1-7 chưa PASS hết) | Re-validate, ESCALATE |
| E081 | high | Template file missing | Re-locate, ESCALATE |
| E082 | high | Matrix schema invalid for downstream | Re-build matrix |
| E083 | high | Cannot write integrity-impact.json HOẶC v3 schema fields thiếu | Retry x3, ESCALATE. v3 check: lanes_v2.active, wave_breakdown, group_breakdown, logistics_critical_signals_count, schema_version_compat.readable_by=[v1,v2,v3], has(e2e_execution_summary), has(scenarios_artifacts), skill_version="3.0.0" |
| E084 | medium | integrity-report.md >55 dòng v2 / >70 dòng v3 max bound HOẶC leftover placeholders HOẶC E2E section conditional render fail (T5) | Re-format, truncate, re-populate sed coverage, re-render E2E_SECTION block |
| E085 | medium | audit_chain.checksum compute fail | Retry x1 |
| E086 | medium | Cross-skill artifact path mismatch contract | Re-validate paths |
| E087 | low | Phase{N}-report.md >15 dòng | Re-format |
| E088 | medium | --show-graphs Mermaid render fail | Skip diagrams, WARN |
| E089 | low | CI mode JSON output unparsable | Re-format JSON |

---

## §G Cross-References

| Reference | Section |
|-----------|---------|
| `_shared.md` | §1, §3, §17 Author, §19 Audit Chain |
| `docs/04-skill-design/wf-cmi/04-file-contract.md` | §3 Cross-skill contract, §4.5 integrity-impact-v3 schema (v3 bump 2026-05-17) |
| `templates/integrity-report.md` (v3 grouped 7-8 sections, ≤55 dòng v2 / ≤70 dòng v3), `integrity-impact.json` (v3 schema) | Templates |
| `_contract.json §cross_skill_contracts.produces_for{}` | Consumer flag map (4 skills via --from-cmi) |
| `templates/wave-status.json` | Wave-coordinator output, source cho `wave_breakdown` |
| `templates/coverage-matrix.json` (v3, 36 dims) | Source cho `group_breakdown` per-dim coverage |
| `procedures/phase9-e2e-execute.md` (v3 NEW) | Source `e2e-results.json` cho Step 8.1 load + Step 8.4.6b populate |
| `procedures/phase10-e2e-resolution.md` (v3 NEW) | Source `resolution-report.md` + enrich `e2e-results.json` với failure_type cho top_failure_types |
| `templates/e2e-results.json` (schema `e2e-results-v1`) | Consumer-side input cho Step 8.4.6b scenarios_artifacts populate |
| `procedures/lanes/CD41.md` | Source `scenarios-manifest.json` cho Step 8.1 load + Step 8.4.6b feat_id_inferred + modules_involved |

---

## §H Next

Phase 8 PASS → Pipeline DONE.

**Downstream consumers:**
- `/wf-verify-sync --from-cmi` → re-verify req-to-code với invariants mới
- `/wf-fix-bugs --from-cmi` → seed Phase 1 với MUST violations
- `/wf-implement-feature --from-cmi` → warn khi touch invariant violate
- `/wf-prepare-deployment --from-cmi` → block release nếu coverage < deep threshold
- `/status` → tổng quan dự án
