# Phase 5 — Aggregate (Signals → Coverage Matrix v2.0, 35 Dims)

> **Đầu vào:** `lanes/CD{N}-{name}/signals.json` × N (Phase 4, 7-26 active) + 6 graphs (Phase 2) + `business-invariants.json` (Phase 3) + `wave-status.json` (Phase 4 v2)
> **Đầu ra:** `coverage-matrix.json` (schema v2, 35 entries), `coverage-report.md`, `signals-aggregated.jsonl`, `Phase5-report.md`
> **Auto-fix budget:** 3 retries
> **Time estimate:** 2-4 min (v2 — handle 26 active + 9 SKIPPED)
> **Required:** ✅ (Coverage gate cho release)

---

## §A Header

Phase 5 aggregate signals từ N active lanes (7-26 tùy profile) → coverage matrix v2 (35 dim entries: 26 active Gói C++ + 9 SKIPPED markers). Apply threshold per profile, detect violations, trigger CDG E090 nếu coverage < threshold. Per-wave breakdown được compute thêm cho v2.

**Mode:** SEQUENTIAL (pure aggregation, no agent spawn).

**Output `coverage-matrix.json` v2 schema:**
- 35 dim entries: 26 active dispatched + 9 SKIPPED (CD8, CD10, CD12, CD14, CD19-22, CD27)
- CD32-CD36 KHÔNG present trong matrix v2 (skeleton v3-deferred)
- Per active dim: `coverage_pct, violations_count, severity_breakdown, modules_below_threshold, status, group, wave, owner_agents[]`
- Per SKIPPED dim: `status='SKIPPED', coverage_pct=null, reason, reactivate_in`
- Overall: `overall_status` (PASS/WARN/FAIL), `overall_pct`
- **NEW v2:** `wave_breakdown{wave1, wave2, wave3}` per-wave overall_pct

**Early exit (E005):** Coverage 100% + 0 violations → skip Phase 6-7, jump Phase 8 với status="healthy".

**Shared sections cần load:**
- `_shared.md §1, §3, §18 CDG token`

---

## §B PRE-GATE (T1→T4)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | Mọi active lane đã produce `signals.json` (status="completed") | bash loop | **E050** — Lane outputs missing → re-spawn missing lane (max 1) |
| T2 | `jq '.signals \| length >= 0'` mỗi `signals.json` (empty OK, malformed fail) | jq | **E051** — Signal schema invalid → skip invalid, log |
| T3 | `signals[].dim` ∈ {CD1..CD10} | jq | **E052** — Invalid dim → DROP signal, WARN |
| T4 | Fingerprint uniqueness across active lanes (post-dedup) | bash+sort | **E053** — Fingerprint collision → dedupe |

```bash
# T1
for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
  st=$(jq -r '.status' "$SESSION_DIR/phase4-coverage/lanes/$dim/lane-status.json")
  [ "$st" = "skipped" ] && continue

  [ -f "$SESSION_DIR/phase4-coverage/lanes/$dim/signals.json" ] \
    || die "E050" "Missing signals.json for lane $dim"
done

# T2/T3
for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
  jq -e '.signals | type == "array"' "$SESSION_DIR/phase4-coverage/lanes/$dim/signals.json" \
    >/dev/null || log_warn "E051" "Invalid signals.json for $dim"

  invalid_dim=$(jq --arg d "$dim" '[.signals[] | select(.dim != $d)] | length' \
                "$SESSION_DIR/phase4-coverage/lanes/$dim/signals.json")
  [ "$invalid_dim" -gt 0 ] && log_warn "E052" "$dim has $invalid_dim signals with wrong dim field"
done
```

---

## §C Steps

### Step 5.1 — Load all lane signals.json

```bash
ALL_SIGNALS=$(jq -s '[.[] | .signals[]?]' \
              "$SESSION_DIR/phase4-coverage/lanes"/*/signals.json 2>/dev/null)

TOTAL_SIGNALS=$(echo "$ALL_SIGNALS" | jq 'length')
log_phase_event "phase5" "INFO" "{\"total_signals\":$TOTAL_SIGNALS}"
```

### Step 5.2 — Compute coverage_pct per dim

> Công thức (xem `docs/04-skill-design/wf-cmi/05-execution-profiles.md` §9.1):
>
> `coverage_pct = (universe_size - violations_count) / universe_size × 100`
>
> Universe size per dim:
> - CD1: số domain/module trong registry
> - CD2: số entity trong entity-graph
> - CD3: số workflow trong workflow-graph
> - CD4: số endpoint trong api-graph
> - CD5: số event trong event-graph
> - CD6: số (resource × action × role) combinations
> - CD7: số FK + unique + NOT NULL constraints expected
> - CD8: số critical path × (log + metric + trace)
> - CD9: số affected module × test type
> - CD10: số invariant + dependency cần doc

```bash
# v2.0: 35 dim entries trong matrix (26 active dispatched + 9 SKIPPED markers).
# Source of truth: _contract.json.lanes_defined[] (status='active' OR 'skipped').
ALL_DIMS_V2="CD1 CD2 CD3 CD4 CD5 CD6 CD7 CD8 CD9 CD10 CD11 CD12 CD13 CD14 CD15 CD16 CD17 CD18 CD19 CD20 CD21 CD22 CD23 CD24 CD25 CD26 CD27 CD28 CD29 CD30 CD31 CD37 CD38 CD39 CD40"
# Note: KHÔNG include CD32-CD36 (skeleton v3-deferred).
SKIPPED_DIMS_V2="CD8 CD10 CD12 CD14 CD19 CD20 CD21 CD22 CD27"

build_coverage_matrix() {
  local matrix='{
    "$schema": "coverage-matrix-v2",
    "session_id": "'"$SESSION_ID"'",
    "profile": "'"$PROFILE"'",
    "threshold_per_dim_pct": '"$(get_profile_threshold)"',
    "coverage_kind": "'"$([ -n "$SINCE_REF" ] && echo "partial" || echo "full")"'",
    "since_ref": "'"${SINCE_REF:-null}"'",
    "dimensions": {},
    "wave_breakdown": {}
  }'

  for dim in $ALL_DIMS_V2; do
    # Check if SKIPPED in v2.0 baseline (matrix marker, không dispatched trừ exhaustive)
    is_skipped_baseline=false
    for sd in $SKIPPED_DIMS_V2; do [ "$dim" = "$sd" ] && is_skipped_baseline=true; done

    # Check if lane active per current profile
    active=$(echo "$DIMS_ACTIVE" | jq --arg d "$dim" 'any(. == $d)')

    if [ "$active" = "false" ]; then
      # SKIPPED marker — coverage_pct=null
      reason=$([ "$is_skipped_baseline" = "true" ] && echo "v2.0 baseline SKIPPED (reactivate v2.1 hoặc exhaustive)" || echo "not active in profile $PROFILE")
      matrix=$(echo "$matrix" | jq --arg d "$dim" --arg n "$(get_dim_name $dim)" \
              --arg g "$(get_dim_group $dim)" --arg r "$reason" \
              '.dimensions[$d] = {name: $n, group: $g, wave: null, coverage_pct: null, status: "SKIPPED", reason: $r}')
      continue
    fi

    # Active lane — compute universe + violations
    UNIVERSE=$(compute_universe_size "$dim")
    VIOLATIONS=$(echo "$ALL_SIGNALS" | jq --arg d "$dim" '[.[] | select(.dim == $d)] | length')

    if [ "$UNIVERSE" -eq 0 ]; then
      COVERAGE_PCT=null
      STATUS="N/A"
      log_warn "E054" "Lane $dim universe size = 0 (no entities to measure)"
    else
      COVERAGE_PCT=$(awk -v u="$UNIVERSE" -v v="$VIOLATIONS" \
                    'BEGIN { printf "%.1f", (u - v) / u * 100 }')
      THRESHOLD=$(get_profile_threshold)
      if [ "$(awk -v c="$COVERAGE_PCT" -v t="$THRESHOLD" 'BEGIN {print (c >= t)}')" = "1" ]; then
        STATUS="PASS"
      else
        STATUS="FAIL_THRESHOLD"
      fi
    fi

    MUST_COUNT=$(echo "$ALL_SIGNALS" | jq --arg d "$dim" '[.[] | select(.dim == $d and .severity == "MUST")] | length')
    SHOULD_COUNT=$(echo "$ALL_SIGNALS" | jq --arg d "$dim" '[.[] | select(.dim == $d and .severity == "SHOULD")] | length')
    MAY_COUNT=$(echo "$ALL_SIGNALS" | jq --arg d "$dim" '[.[] | select(.dim == $d and .severity == "MAY")] | length')

    DIM_NAME_SLUG=$(get_dim_name_slug "$dim")  # vd "business-domain" cho CD1
    LANE_SUBDIR="${dim}-${DIM_NAME_SLUG}"

    matrix=$(echo "$matrix" | jq --arg d "$dim" --arg n "$(get_dim_name $dim)" \
            --arg g "$(get_dim_group $dim)" --arg w "$(get_dim_wave $dim)" \
            --argjson cp "$COVERAGE_PCT" --arg st "$STATUS" \
            --argjson vc "$VIOLATIONS" --argjson must "$MUST_COUNT" \
            --argjson should "$SHOULD_COUNT" --argjson may "$MAY_COUNT" \
            --arg lf "$SESSION_DIR/phase4-coverage/lanes/$LANE_SUBDIR/signals.json" \
            '.dimensions[$d] = {
                name: $n, group: $g, wave: ($w | tonumber? // null),
                coverage_pct: $cp, violations_count: $vc,
                severity_breakdown: {MUST: $must, SHOULD: $should, MAY: $may},
                modules_below_threshold: [], status: $st, signals_file: $lf
            }')
  done

  # Compute wave_breakdown (v2 NEW)
  for wave in 1 2 3; do
    wave_dims=$(jq --arg w "$wave" -r '[.dimensions | to_entries[] | select(.value.wave == ($w | tonumber)) | .value.coverage_pct] | map(select(. != null)) | if length == 0 then 0 else add / length end' <<< "$matrix")
    wave_count=$(jq --arg w "$wave" '[.dimensions | to_entries[] | select(.value.wave == ($w | tonumber))] | length' <<< "$matrix")
    matrix=$(jq --arg w "wave$wave" --argjson p "$wave_dims" --argjson c "$wave_count" \
             '.wave_breakdown[$w] = {overall_pct: $p, lane_count: $c}' <<< "$matrix")
  done

  echo "$matrix"
}

get_profile_threshold() {
  case "$PROFILE" in
    quick) echo 60 ;;
    standard) echo 80 ;;
    deep) echo 95 ;;
    exhaustive) echo 100 ;;
  esac
}

get_dim_name() {
  case "$1" in
    # Core (v1 carried)
    CD1) echo "Business domain coverage" ;; CD2) echo "Entity dependency" ;;
    CD3) echo "Workflow coverage" ;; CD4) echo "API contract" ;;
    CD5) echo "Event coverage" ;; CD6) echo "Permission/RBAC" ;;
    CD7) echo "Data integrity" ;; CD8) echo "Observability" ;;
    CD9) echo "Regression coverage" ;; CD10) echo "Documentation" ;;
    # Frontend (v2)
    CD11) echo "FE Component Contracts" ;; CD12) echo "FE State Integrity" ;;
    CD13) echo "FE↔BE Contract Sync" ;; CD14) echo "FE i18n Coverage" ;;
    CD15) echo "UI Permission Mirror" ;;
    # Backend (v2)
    CD16) echo "Domain Logic Integrity" ;; CD17) echo "Persistence Consistency" ;;
    CD18) echo "CQRS Pipeline Integrity" ;; CD19) echo "Distributed Transaction" ;;
    CD20) echo "Security Deep" ;; CD21) echo "Reliability" ;; CD22) echo "Config & Secret" ;;
    # UX (v2)
    CD23) echo "UX Design System Consistency" ;; CD24) echo "UX Display Format Consistency" ;;
    CD25) echo "UX Flow Continuity" ;; CD26) echo "UX Workflow Visibility" ;;
    CD27) echo "UX Microcopy" ;;
    # Logistics + Compliance (v2)
    CD28) echo "MDM Consistency ★★★" ;; CD29) echo "Audit Trail Completeness" ;;
    CD30) echo "Time & Numbering Integrity ★★★" ;; CD31) echo "Money & Tax Integrity ★★★" ;;
    CD37) echo "Regulatory Compliance Mapping ★★★" ;;
    # Implementation Additions (v2)
    CD38) echo "UI Implementation Coverage ★" ;; CD39) echo "Error UX & Recovery ★" ;;
    CD40) echo "Print & Export Consistency ★" ;;
  esac
}

get_dim_name_slug() {
  case "$1" in
    CD1) echo "business-domain" ;; CD2) echo "entity-dependency" ;;
    CD3) echo "workflow-coverage" ;; CD4) echo "api-contract" ;;
    CD5) echo "event-coverage" ;; CD6) echo "permission-rbac" ;;
    CD7) echo "data-integrity" ;; CD9) echo "regression-coverage" ;;
    CD11) echo "fe-component-contracts" ;; CD13) echo "fe-be-contract-sync" ;;
    CD15) echo "ui-permission-mirror" ;;
    CD16) echo "domain-logic-integrity" ;; CD17) echo "persistence-consistency" ;;
    CD18) echo "cqrs-pipeline-integrity" ;;
    CD23) echo "ux-design-system" ;; CD24) echo "ux-display-format" ;;
    CD25) echo "ux-flow-continuity" ;; CD26) echo "ux-workflow-visibility" ;;
    CD28) echo "mdm-consistency" ;; CD29) echo "audit-trail" ;;
    CD30) echo "time-numbering" ;; CD31) echo "money-tax" ;;
    CD37) echo "regulatory-compliance" ;;
    CD38) echo "ui-implementation-coverage" ;; CD39) echo "error-ux-recovery" ;;
    CD40) echo "print-export-consistency" ;;
    # SKIPPED dims không có subdir (KHÔNG dispatched)
    *) echo "skipped" ;;
  esac
}

get_dim_group() {
  case "$1" in
    CD1|CD2|CD3|CD4|CD5|CD6|CD7|CD8|CD9|CD10) echo "core" ;;
    CD11|CD12|CD13|CD14|CD15) echo "frontend" ;;
    CD16|CD17|CD18) echo "backend" ;;
    CD19|CD20|CD22) echo "security" ;;
    CD21) echo "ops" ;;
    CD23|CD24|CD25|CD26|CD27) echo "ux" ;;
    CD28|CD30|CD31) echo "logistics" ;;
    CD29|CD37) echo "compliance" ;;
    CD38|CD39|CD40) echo "implementation" ;;
  esac
}

get_dim_wave() {
  case "$1" in
    CD1|CD2|CD3|CD4|CD5|CD6|CD7|CD11|CD16|CD17) echo 1 ;;
    CD13|CD15|CD18|CD23|CD24|CD25|CD28|CD30|CD31|CD37) echo 2 ;;
    CD9|CD26|CD29|CD38|CD39|CD40) echo 3 ;;
    *) echo "null" ;;  # SKIPPED dims không có wave
  esac
}

compute_universe_size() {
  local dim="$1"
  case "$dim" in
    # Core (v1)
    CD1) jq '.modules | length' .mc-data/docs/_meta/req-registry.json ;;
    CD2) jq '.nodes | length' "$SESSION_DIR/phase2-discovery/entity-graph.json" ;;
    CD3) jq '.workflows | length' "$SESSION_DIR/phase2-discovery/workflow-graph.json" ;;
    CD4) jq '.endpoints | length' "$SESSION_DIR/phase2-discovery/api-graph.json" ;;
    CD5) jq '.events | length' "$SESSION_DIR/phase2-discovery/event-graph.json" ;;
    CD6) jq '.permissions | length' "$SESSION_DIR/phase2-discovery/rbac-matrix.json" ;;
    CD7) jq '[.edges[] | select(.kind == "fk")] | length' "$SESSION_DIR/phase2-discovery/entity-graph.json" ;;
    CD9) jq '.modules | length' "$SESSION_DIR/phase2-discovery/module-graph.json" ;;
    # Frontend (v2) — graph files chưa có ở v2.0 → fallback Glob count
    CD11) find apps/erp-web/components -name "*.tsx" 2>/dev/null | wc -l || echo 0 ;;
    CD13) jq '.endpoints | length' "$SESSION_DIR/phase2-discovery/api-graph.json" ;;  # FE clients should mirror BE endpoints
    CD15) jq '.permissions | length' "$SESSION_DIR/phase2-discovery/rbac-matrix.json" ;;
    # Backend (v2) — graph files chưa có ở v2.0 → fallback Grep count
    CD16) grep -rc "class.*Aggregate\|class.*ValueObject\|interface IDomainEvent" --include="*.cs" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}' ;;
    CD17) find . -name "*Migration*.cs" -path "*/Migrations/*" 2>/dev/null | wc -l || echo 0 ;;
    CD18) grep -rc "IRequest\|IRequestHandler\|IValidator\|IPipelineBehavior" --include="*.cs" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}' ;;
    # UX (v2) — SSOT-driven
    CD23) jq '[.design_tokens, .button_variants, .color_palette] | length' .mc-data/docs/_meta/ux-conventions.json 2>/dev/null || echo 1 ;;
    CD24) jq '[.date_formats, .number_formats, .currency_formats] | length' .mc-data/docs/_meta/ux-conventions.json 2>/dev/null || echo 1 ;;
    CD25) find apps/erp-web/app -name "page.tsx" 2>/dev/null | wc -l || echo 0 ;;
    CD26) jq '.workflows | length' .mc-data/docs/_meta/workflow-state-machines.json 2>/dev/null || jq '.workflows | length' "$SESSION_DIR/phase2-discovery/workflow-graph.json" ;;
    # Logistics + Compliance (v2)
    CD28) jq '.entities | length' .mc-data/docs/_meta/mdm-canonical-entities.json 2>/dev/null || echo 1 ;;
    CD29) jq '.critical_entities | length' .mc-data/docs/_meta/audit-critical-entities.json 2>/dev/null || echo 1 ;;
    CD30) echo 1 ;;  # Single universe — system-wide timezone + numbering rules
    CD31) echo 1 ;;  # Single universe — system-wide money + tax rules
    CD37) jq '.regulations | length' .mc-data/docs/_meta/compliance-mapping.json 2>/dev/null || echo 1 ;;
    # Implementation Additions (v2)
    CD38) jq '[.endpoint_classifications.user_facing.patterns[]] | length' .mc-data/docs/_meta/ui-interactivity-spec.json 2>/dev/null || jq '.endpoints | length' "$SESSION_DIR/phase2-discovery/api-graph.json" ;;
    CD39) jq '.error_codes | length' .mc-data/docs/_meta/error-code-catalog.json 2>/dev/null || echo 1 ;;
    CD40) jq '.templates | length' .mc-data/docs/_meta/print-export-templates.json 2>/dev/null || echo 1 ;;
    # SKIPPED dims return 0 (won't be reached since active=false filter triggers first)
    *) echo 0 ;;
  esac
}
```

### Step 5.3 — Apply threshold + compute overall status

```bash
MATRIX=$(build_coverage_matrix)

# Determine overall_pct (average of active dims)
OVERALL_PCT=$(echo "$MATRIX" | jq \
  '[.dimensions | to_entries[] | .value | select(.coverage_pct != null) | .coverage_pct] | add / length')

# Determine overall_status
BELOW_COUNT=$(echo "$MATRIX" | jq \
  '[.dimensions | to_entries[] | .value | select(.status == "FAIL_THRESHOLD")] | length')

if [ "$BELOW_COUNT" -eq 0 ]; then
  OVERALL_STATUS="PASS"
  # Check E005 healthy
  TOTAL_VIOLATIONS=$(echo "$MATRIX" | jq \
    '[.dimensions | to_entries[] | .value.violations_count // 0] | add')
  if [ "${TOTAL_VIOLATIONS:-0}" -eq 0 ] && [ "$(awk -v p="$OVERALL_PCT" 'BEGIN{print (p >= 100)}')" = "1" ]; then
    OVERALL_STATUS="HEALTHY"
    E005_HEALTHY=true
    log_phase_event "phase5" "INFO" "{\"E005\":\"healthy — skip Phase 6-7\"}"
  fi
elif [ "$BELOW_COUNT" -lt 3 ]; then
  OVERALL_STATUS="WARN"
else
  OVERALL_STATUS="FAIL"
fi

export OVERALL_STATUS OVERALL_PCT E005_HEALTHY
```

### Step 5.4 — Build coverage-matrix.json (Atomic Write)

```bash
TARGET="$SESSION_DIR/phase5-aggregate/coverage-matrix.json"
TPL=".claude/skills/workflow/wf-cmi/templates/coverage-matrix.json"
strip_template_metadata "$TPL" "$TARGET"

# Merge matrix + overall + audit chain
echo "$MATRIX" | jq --arg os "$OVERALL_STATUS" --argjson op "$OVERALL_PCT" \
  --arg src "$SESSION_DIR/phase4-coverage" \
  '. + {overall_status: $os, overall_pct: $op,
        audit_chain: {source: $src, checksum: ""}}' > "$TARGET.tmp.$$"

# Validate
jq '.' "$TARGET.tmp.$$" >/dev/null && mv "$TARGET.tmp.$$" "$TARGET" \
  || { log_phase_fail "E055" "Matrix template fill error"; }
```

### Step 5.5 — Build signals-aggregated.jsonl (deduplicate cross-lane)

```bash
SIG_AGG="$SESSION_DIR/phase5-aggregate/signals-aggregated.jsonl"
> "$SIG_AGG"  # Truncate

# Dedupe by fingerprint, pick higher severity if conflict
echo "$ALL_SIGNALS" | jq -c '
  group_by(.fingerprint) |
  map(
    sort_by(.severity | if . == "MUST" then 1 elif . == "SHOULD" then 2 elif . == "MAY" then 3 else 4 end) |
    .[0]
  ) | .[]' >> "$SIG_AGG"

# Verify line count
DEDUP_COUNT=$(wc -l < "$SIG_AGG")
log_phase_event "phase5" "INFO" "{\"signals_dedup\":$DEDUP_COUNT}"

# Workload estimator overflow check
[ "$DEDUP_COUNT" -gt 10000 ] && log_warn "E059" "Signal count >10K — truncate per-dim recommended"
```

### Step 5.6 — Build coverage-report.md (CORE-028 ≤15 dòng tiếng Việt)

```bash
TPL=".claude/skills/workflow/wf-cmi/templates/coverage-report.md"
REPORT="$SESSION_DIR/phase5-aggregate/coverage-report.md"

# Build per-dim table content — v2.0 loop 35 dims, group by group
DIM_TABLE=""
LAST_GROUP=""
for dim in $ALL_DIMS_V2; do
  ENTRY=$(echo "$MATRIX" | jq -r --arg d "$dim" '.dimensions[$d]')
  GROUP=$(echo "$ENTRY" | jq -r '.group')
  NAME=$(echo "$ENTRY" | jq -r '.name')
  PCT=$(echo "$ENTRY" | jq -r '.coverage_pct // "—"')
  ST=$(echo "$ENTRY" | jq -r '.status')
  ICON=$(case "$ST" in PASS) echo "✅";; FAIL_THRESHOLD) echo "❌";; SKIPPED) echo "⏭";; HEALTHY) echo "💚";; *) echo "⚠";; esac)
  # Group header transitions
  if [ "$GROUP" != "$LAST_GROUP" ]; then
    DIM_TABLE="${DIM_TABLE}\n**[${GROUP}]**\n"
    LAST_GROUP="$GROUP"
  fi
  DIM_TABLE="${DIM_TABLE}- ${ICON} ${dim} ${NAME}: ${PCT}% (${ST})\n"
done

# Populate via sed
sed -e "s|\[OVERALL_STATUS\]|$OVERALL_STATUS|g" \
    -e "s|\[OVERALL_PCT\]|$(printf "%.1f" $OVERALL_PCT)|g" \
    -e "s|\[THRESHOLD\]|$(get_profile_threshold)|g" \
    -e "s|\[BELOW_COUNT\]|$BELOW_COUNT|g" \
    -e "s|\[TOTAL_SIGNALS\]|$DEDUP_COUNT|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    "$TPL" > "$REPORT.tmp"

# Insert dim table
awk -v table="$DIM_TABLE" '/\[DIM_TABLE\]/{print table; next} {print}' "$REPORT.tmp" > "$REPORT"
rm -f "$REPORT.tmp"

# Verify ≤20 dòng (E056) — v2 relaxed cho 26 active dims grouped
[ "$(wc -l < "$REPORT")" -le 20 ] || log_warn "E056" "coverage-report.md >20 dòng — truncating"
```

### Step 5.7 — Check threshold violations → CDG E090 escalate

> Nếu bất kỳ dim < threshold per profile → AskUserQuestion.

```
IF $BELOW_COUNT > 0 AND $CI_MODE != true:
  AskUserQuestion:
    "Coverage $OVERALL_PCT% < threshold $(get_profile_threshold)% — $BELOW_COUNT dim(s) below.
     Options:
       1. Accept gap (continue Phase 6-7, report only)
       2. Generate artifacts (jump Phase 7 với --auto-suggest)
       3. Cancel (exit FAIL)"
    Default: ABORT (option 3)

  Save: CDG_E090_DECISION="accept|generate|cancel"
  Append to cdg-tokens.json (via append_cdg_token helper)

ELSE IF $CI_MODE = true:
  Auto-route: --ci mode = "accept" (read-only report only)
```

### Step 5.8 — Write Phase5-report.md (CORE-028)

```bash
TPL=".claude/skills/workflow/wf-cmi/templates/Phase5-report.md"
REPORT="$SESSION_DIR/phase5-aggregate/Phase5-report.md"

CDG_NOTE=""
[ "${CDG_E090_DECISION:-}" = "accept" ] && CDG_NOTE="- CDG E090: User chấp nhận gap, tiếp tục Phase 6"
[ "${CDG_E090_DECISION:-}" = "generate" ] && CDG_NOTE="- CDG E090: Generate artifacts trong Phase 7"

sed -e "s|\[OVERALL_STATUS\]|$OVERALL_STATUS|g" \
    -e "s|\[OVERALL_PCT\]|$(printf "%.1f" $OVERALL_PCT)|g" \
    -e "s|\[BELOW_COUNT\]|$BELOW_COUNT|g" \
    -e "s|\[TOTAL_SIGNALS\]|$DEDUP_COUNT|g" \
    -e "s|\[CDG_NOTE\]|$CDG_NOTE|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    -e "s|\[STATUS\]|$([ "$OVERALL_STATUS" = "FAIL" ] && echo FAIL || echo PASS)|g" \
    "$TPL" > "$REPORT"
```

---

## §D POST-GATE (T1→T4 + Auto-Fix)

| Tier | Check | Auto-fix (max 3) |
|------|-------|------------------|
| T1 | `coverage-matrix.json` + `coverage-report.md` + `signals-aggregated.jsonl` exist | Re-aggregate |
| T2 | **Matrix v2 có đủ 35 dim entries** (26 active dispatched + 9 SKIPPED markers). CD32-CD36 KHÔNG present. | Re-build từ template |
| T3 | Mỗi dim có `coverage_pct` ∈ [0, 100] hoặc null (SKIPPED). Mỗi dim có `group` + `wave` fields (v2 NEW) | Re-compute |
| T4 | `coverage-report.md` ≤20 dòng tiếng Việt (CORE-028 relaxed v2 cho 26 dims grouped) + `wave_breakdown` có 3 entries (wave1/2/3) | Re-format, truncate, rebuild_matrix |

```bash
post_gate_phase5() {
  local target="$SESSION_DIR/phase5-aggregate/coverage-matrix.json"
  local retry=0
  while [ "$retry" -lt 3 ]; do
    # T1
    [ -f "$target" ] && [ -f "$SESSION_DIR/phase5-aggregate/coverage-report.md" ] \
                     && [ -f "$SESSION_DIR/phase5-aggregate/signals-aggregated.jsonl" ] \
      || { reaggregate; retry=$((retry+1)); continue; }

    # T2 — v2.0: 35 dim entries (26 active + 9 SKIPPED). CD32-CD36 KHÔNG present.
    DIMS_IN_MATRIX=$(jq '.dimensions | keys | length' "$target")
    [ "$DIMS_IN_MATRIX" -eq 35 ] || { log_warn "E055" "Matrix dims=$DIMS_IN_MATRIX expected 35"; rebuild_matrix; retry=$((retry+1)); continue; }
    # Verify CD32-CD36 NOT present (v2 skeleton check)
    SKELETON_IN_MATRIX=$(jq '[.dimensions | keys[] | select(test("^CD3[2-6]$"))] | length' "$target")
    [ "$SKELETON_IN_MATRIX" -eq 0 ] || { log_warn "E055" "Matrix contains skeleton v3-deferred dims — rebuild"; rebuild_matrix; retry=$((retry+1)); continue; }

    # T3
    invalid_pct=$(jq '[.dimensions | to_entries[] | .value.coverage_pct |
                      select(. != null and (. < 0 or . > 100))] | length' "$target")
    [ "$invalid_pct" -gt 0 ] && { recompute_pct; retry=$((retry+1)); continue; }

    # T4 — v2 relaxed: coverage-report.md ≤20 dòng (CORE-028 cho 26 active dims grouped),
    # wave_breakdown phải có 3 entries (wave1/2/3)
    REPORT_LINES=$(wc -l < "$SESSION_DIR/phase5-aggregate/coverage-report.md")
    [ "$REPORT_LINES" -le 20 ] || { reformat_report; retry=$((retry+1)); continue; }
    WB_COUNT=$(jq '.wave_breakdown | keys | length' "$target")
    [ "$WB_COUNT" -eq 3 ] || { log_warn "E055" "wave_breakdown=$WB_COUNT expected 3"; rebuild_matrix; retry=$((retry+1)); continue; }

    return 0
  done
  die "E001" "Phase 5 POST-GATE fail after 3 retries"
}
```

**On PASS:**
1. Append `session-log.json` event `COMPLETE` Phase 5
2. Update `integrity-status.json`:
   - `.phases_completed += [5]`
   - `.overall_status = "$OVERALL_STATUS"`
   - `.total_signals = $DEDUP_COUNT`

**Route next:**
- IF `$E005_HEALTHY = true` → jump Phase 8 (skip Phase 6-7)
- ELSE IF `$PROFILE = quick` OR `$SINCE_REF` empty → skip Phase 6, route Phase 7
- ELSE → route Phase 6

---

## §E Phase Report Template (CORE-028)

```markdown
## Phase 5: Tổng hợp coverage matrix — PASS
Thời gian: 2026-05-15T14:50:10+07:00

**Đã làm:**
- Tổng hợp 142 signals từ 8 lanes Phase 4
- Loại trùng lặp + sắp xếp theo độ nghiêm trọng

**Kết quả:**
- Coverage tổng: 82.5% (threshold standard ≥80%)
- Dim đạt ngưỡng: 7/8 | Dim dưới ngưỡng: 1 (CD3 Workflow 75%)
- Signals MUST: 24 | SHOULD: 71 | MAY: 47
- [CDG_NOTE]

**Tiếp theo:**
- Phase 6 — Phân tích regression scope (1-3 phút)
```

---

## §F Error Code Quick Reference (Phase 5 namespace E050-E059)

| Code | Severity | Description | Auto-fix |
|------|---------|-------------|----------|
| E050 | high | Lane outputs missing | Re-spawn missing lane (max 1) |
| E051 | high | Signal schema invalid | Skip invalid, log |
| E052 | medium | Invalid dim value | DROP signal, WARN |
| E053 | low | Fingerprint collision cross-lane | Dedupe |
| E054 | medium | Coverage compute fail (division by zero) | Mark dim N/A |
| E055 | medium | Matrix template fill error | Re-build từ template |
| E056 | medium | coverage-report.md >20 dòng (v2 relaxed cho 26 dims grouped) | Re-format, truncate |
| E057 | low | Lane SKIPPED nhưng aggregate cố compute | Mark dim SKIPPED |
| E058 | medium | Cross-lane signal aggregation conflict | Pick higher severity, log |
| E059 | low | Workload estimator overflow (>10K signals) | Truncate per dim, WARN |
| E090 | medium | CDG Coverage below threshold | AskUser: accept/generate/cancel |
| E005 | info | 0 violations + 100% — healthy | Early-exit, skip Phase 6-7 |

---

## §G Cross-References

| Reference | Section |
|-----------|---------|
| `_shared.md` | §1, §3, §18 CDG Token |
| `docs/04-skill-design/wf-cmi/04-file-contract.md` | §4.3 coverage-matrix-v1 schema |
| `docs/04-skill-design/wf-cmi/05-execution-profiles.md` | §9.1 coverage formula + thresholds |
| `templates/coverage-matrix.json`, `coverage-report.md` | Output templates |
| `_contract.json §outputs.working[]` | Phase 5 paths |

---

## §H Next

Phase 5 PASS →
- `$E005_HEALTHY=true` → jump Phase 8 (skip 6-7)
- ELSE `$PROFILE=quick OR $SINCE_REF empty` → skip Phase 6, route Phase 7
- ELSE → Read `procedures/phase6-regression.md` để build regression map.
