#!/usr/bin/env bash
# =============================================================================
# generate-phase4-report.sh — Phase 4 Step 4.8 (CORE-028, v10.10)
# =============================================================================
# Implements Step 4.8 — Populate Phase4-report.md + phase4-summary.json từ
# aggregated data (lane-status.json, signals.json per stream, probe-failures.log).
#
# v10.10 (2026-05-16): bổ sung emit phase4-summary.json (schema phase4-summary-v1)
# để downstream phases (5/6/7) có cross-lane rollup machine-readable (severity
# breakdown, registry coverage, evidence index, audit chain). Phase4-report.md
# vẫn ≤15 dòng (CORE-028) cho non-specialist.
#
# Pattern (CORE-031): READ template → POPULATE placeholders → STRIP metadata →
# Atomic Write. Tiếng Việt (CORE-028). 1 file = 1 writer (CORE-025).
#
# Required env vars:
#   SESSION_DIR, SESSION_ID, DIMS_ARRAY
#
# Optional env vars (override defaults):
#   STATUS_PASS_FAIL        (default: PASS)
#   STARTED_AT, COMPLETED_AT (default: $NOW)
#   PLAYWRIGHT_SUMMARY      (default: "không có" hoặc đếm playwright_used)
#   PROFILE, SCOPE, INTERFACE_TYPE  (cho summary metadata)
#
# Exit codes:
#   0 — Phase4-report.md + phase4-summary.json written
#   1 — Required env var missing
#   2 — Template không tồn tại
#   3 — Atomic write fail
# =============================================================================

set -eu

for var in SESSION_DIR SESSION_ID DIMS_ARRAY; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

TPL_DIR=".claude/skills/workflow/wf-fix-bugs/templates/phase4-find-bugs"
TPL_MD="$TPL_DIR/Phase4-report.md"
TPL_SUMMARY="$TPL_DIR/phase4-summary.json"
TARGET_MD="$SESSION_DIR/phase4-find-bugs/Phase4-report.md"
TARGET_SUMMARY="$SESSION_DIR/phase4-find-bugs/phase4-summary.json"
LANES_ROOT="$SESSION_DIR/phase4-find-bugs/lanes"

[ -f "$TPL_MD" ] || { echo "ERROR: Template missing: $TPL_MD (CORE-031)" >&2; exit 2; }
[ -f "$TPL_SUMMARY" ] || { echo "ERROR: Template missing: $TPL_SUMMARY (CORE-031)" >&2; exit 2; }

mkdir -p "$(dirname "$TARGET_MD")"

# ── Aggregate metrics từ lane-status.json + signals.json ─────────────────────
LANES_TOTAL=0; LANES_COMPLETED=0
STATIC_TOTAL=0; RUNTIME_TOTAL=0; LLM_TOTAL=0
PW_USED_COUNT=0

# Per-dim arrays (parallel) — bash 3.x compatible (no associative arrays)
DIM_LIST=""
DIMENSIONS_JSON="[]"
EVIDENCE_JSON="[]"
SIGNALS_HASHES=""
LANESTATUS_HASHES=""

# Aggregated counters
SEV_CRIT=0; SEV_HIGH=0; SEV_MED=0; SEV_LOW=0; SEV_INFO=0
FIX_AUTO=0; FIX_AGENT=0; FIX_ESC=0; FIX_SKIP=0

# Temp files for accumulation (avoid bash assoc array compat issues)
TMP_PROBE_COUNTS="${TMPDIR:-/tmp}/p4-probe-$$.tsv"
TMP_DIM_COUNTS="${TMPDIR:-/tmp}/p4-dim-$$.tsv"
TMP_REQ_REFS="${TMPDIR:-/tmp}/p4-req-$$.tsv"
TMP_FEAT_REFS="${TMPDIR:-/tmp}/p4-feat-$$.tsv"
TMP_MOD_REFS="${TMPDIR:-/tmp}/p4-mod-$$.tsv"
TMP_TOP_FP="${TMPDIR:-/tmp}/p4-fp-$$.tsv"
: > "$TMP_PROBE_COUNTS"; : > "$TMP_DIM_COUNTS"
: > "$TMP_REQ_REFS"; : > "$TMP_FEAT_REFS"; : > "$TMP_MOD_REFS"
: > "$TMP_TOP_FP"
trap 'rm -f "$TMP_PROBE_COUNTS" "$TMP_DIM_COUNTS" "$TMP_REQ_REFS" "$TMP_FEAT_REFS" "$TMP_MOD_REFS" "$TMP_TOP_FP"' EXIT

for dim in $DIMS_ARRAY; do
  LANES_TOTAL=$((LANES_TOTAL + 1))
  LANE_FILE="$LANES_ROOT/$dim/lane-status.json"

  DIM_STATUS="missing"; DIM_PW=false
  DIM_STATIC=0; DIM_RUNTIME=0; DIM_LLM=0
  DIM_PROBE_FAIL=0; DIM_DURATION=0
  DIM_STARTED=""; DIM_COMPLETED=""

  if [ -f "$LANE_FILE" ]; then
    DIM_STATUS=$(jq -r '.status // "pending"' "$LANE_FILE" 2>/dev/null || echo "missing")
    case "$DIM_STATUS" in
      completed|skipped) LANES_COMPLETED=$((LANES_COMPLETED + 1)) ;;
    esac
    DIM_PW=$(jq -r '.playwright_used // false' "$LANE_FILE" 2>/dev/null || echo false)
    [ "$DIM_PW" = "true" ] && PW_USED_COUNT=$((PW_USED_COUNT + 1))
    DIM_STATIC=$(jq -r '.signals_static // 0' "$LANE_FILE" 2>/dev/null || echo 0)
    DIM_RUNTIME=$(jq -r '.signals_runtime // 0' "$LANE_FILE" 2>/dev/null || echo 0)
    DIM_LLM=$(jq -r '.signals_llm // 0' "$LANE_FILE" 2>/dev/null || echo 0)
    DIM_PROBE_FAIL=$(jq -r '.probe_failures // 0' "$LANE_FILE" 2>/dev/null || echo 0)
    DIM_STARTED=$(jq -r '.started_at // ""' "$LANE_FILE" 2>/dev/null || echo "")
    DIM_COMPLETED=$(jq -r '.completed_at // ""' "$LANE_FILE" 2>/dev/null || echo "")

    # Duration computation (ISO-8601 → epoch diff)
    if [ -n "$DIM_STARTED" ] && [ -n "$DIM_COMPLETED" ]; then
      START_EPOCH=$(date -d "$DIM_STARTED" +%s 2>/dev/null || echo 0)
      END_EPOCH=$(date -d "$DIM_COMPLETED" +%s 2>/dev/null || echo 0)
      if [ "$START_EPOCH" -gt 0 ] && [ "$END_EPOCH" -gt 0 ]; then
        DIM_DURATION=$((END_EPOCH - START_EPOCH))
      fi
    fi

    # Hash lane-status content for audit chain
    LSHASH=$(sha256sum "$LANE_FILE" 2>/dev/null | awk '{print $1}')
    LANESTATUS_HASHES="${LANESTATUS_HASHES}${LSHASH}"
  fi

  STATIC_TOTAL=$((STATIC_TOTAL + DIM_STATIC))
  RUNTIME_TOTAL=$((RUNTIME_TOTAL + DIM_RUNTIME))
  LLM_TOTAL=$((LLM_TOTAL + DIM_LLM))

  # Per-dim signal breakdown (sev + fix + probe + registry refs + fingerprints)
  DIM_SEV_C=0; DIM_SEV_H=0; DIM_SEV_M=0; DIM_SEV_L=0; DIM_SEV_I=0
  DIM_FIX_A=0; DIM_FIX_AG=0; DIM_FIX_E=0; DIM_FIX_S=0
  DIM_EVID_COUNT=0

  for sub in static-scan runtime llm-scan; do
    f="$LANES_ROOT/$dim/$sub/signals.json"
    if [ -f "$f" ]; then
      # Hash signals.json for audit chain
      SHASH=$(sha256sum "$f" 2>/dev/null | awk '{print $1}')
      SIGNALS_HASHES="${SIGNALS_HASHES}${SHASH}"

      # Count per severity (in this signals file)
      DIM_SEV_C=$((DIM_SEV_C + $(jq '[(.signals // [])[] | select(.severity == "critical")] | length' "$f" 2>/dev/null || echo 0)))
      DIM_SEV_H=$((DIM_SEV_H + $(jq '[(.signals // [])[] | select(.severity == "high")] | length' "$f" 2>/dev/null || echo 0)))
      DIM_SEV_M=$((DIM_SEV_M + $(jq '[(.signals // [])[] | select(.severity == "medium")] | length' "$f" 2>/dev/null || echo 0)))
      DIM_SEV_L=$((DIM_SEV_L + $(jq '[(.signals // [])[] | select(.severity == "low")] | length' "$f" 2>/dev/null || echo 0)))
      DIM_SEV_I=$((DIM_SEV_I + $(jq '[(.signals // [])[] | select(.severity == "info")] | length' "$f" 2>/dev/null || echo 0)))

      # Count per fixability
      DIM_FIX_A=$((DIM_FIX_A + $(jq '[(.signals // [])[] | select(.fixability == "auto_fix")] | length' "$f" 2>/dev/null || echo 0)))
      DIM_FIX_AG=$((DIM_FIX_AG + $(jq '[(.signals // [])[] | select(.fixability == "agent_fix")] | length' "$f" 2>/dev/null || echo 0)))
      DIM_FIX_E=$((DIM_FIX_E + $(jq '[(.signals // [])[] | select(.fixability == "escalate")] | length' "$f" 2>/dev/null || echo 0)))
      DIM_FIX_S=$((DIM_FIX_S + $(jq '[(.signals // [])[] | select(.fixability == "skip")] | length' "$f" 2>/dev/null || echo 0)))

      # Per-probe counts → TSV (probe_id TAB count)
      jq -r '(.signals // [])[] | (.probe_id // "unknown")' "$f" 2>/dev/null >> "$TMP_PROBE_COUNTS" || true

      # Registry refs → TSV
      jq -r '(.signals // [])[] | .registry_refs.req_ids // [] | .[]' "$f" 2>/dev/null >> "$TMP_REQ_REFS" || true
      jq -r '(.signals // [])[] | .registry_refs.feat_ids // [] | .[]' "$f" 2>/dev/null >> "$TMP_FEAT_REFS" || true
      jq -r '(.signals // [])[] | .registry_refs.module_ids // [] | .[]' "$f" 2>/dev/null >> "$TMP_MOD_REFS" || true

      # Top fingerprints (with severity priority for sort)
      jq -r '(.signals // [])[] | "\(.severity)\t\(.fingerprint)\t\(.title // "")\t\(.location.file // "")"' "$f" 2>/dev/null >> "$TMP_TOP_FP" || true

      # Evidence index — collect from each signal
      EVID_ITEMS=$(jq -c --arg lane "$dim" '(.signals // [])[] | (.evidence // []) | .[] | {lane: $lane, type, path, description}' "$f" 2>/dev/null || true)
      if [ -n "$EVID_ITEMS" ]; then
        while IFS= read -r e; do
          [ -z "$e" ] && continue
          EVIDENCE_JSON=$(echo "$EVIDENCE_JSON" | jq --argjson item "$e" '. + [$item]')
          DIM_EVID_COUNT=$((DIM_EVID_COUNT + 1))
        done <<< "$EVID_ITEMS"
      fi
    fi
  done

  DIM_TOTAL=$((DIM_STATIC + DIM_RUNTIME + DIM_LLM))
  echo -e "$dim\t$DIM_TOTAL" >> "$TMP_DIM_COUNTS"

  SEV_CRIT=$((SEV_CRIT + DIM_SEV_C))
  SEV_HIGH=$((SEV_HIGH + DIM_SEV_H))
  SEV_MED=$((SEV_MED + DIM_SEV_M))
  SEV_LOW=$((SEV_LOW + DIM_SEV_L))
  SEV_INFO=$((SEV_INFO + DIM_SEV_I))

  FIX_AUTO=$((FIX_AUTO + DIM_FIX_A))
  FIX_AGENT=$((FIX_AGENT + DIM_FIX_AG))
  FIX_ESC=$((FIX_ESC + DIM_FIX_E))
  FIX_SKIP=$((FIX_SKIP + DIM_FIX_S))

  # Build dimension entry
  DIM_ENTRY=$(jq -n \
    --arg id "$dim" --arg st "$DIM_STATUS" --arg sa "$DIM_STARTED" --arg ca "$DIM_COMPLETED" \
    --argjson dur "$DIM_DURATION" --argjson pw "$DIM_PW" \
    --argjson s "$DIM_STATIC" --argjson r "$DIM_RUNTIME" --argjson l "$DIM_LLM" \
    --argjson pf "$DIM_PROBE_FAIL" --argjson ec "$DIM_EVID_COUNT" \
    --argjson sc "$DIM_SEV_C" --argjson sh "$DIM_SEV_H" --argjson sm "$DIM_SEV_M" --argjson sl "$DIM_SEV_L" --argjson si "$DIM_SEV_I" \
    --argjson fa "$DIM_FIX_A" --argjson fg "$DIM_FIX_AG" --argjson fe "$DIM_FIX_E" --argjson fs "$DIM_FIX_S" \
    '{
      dimension: $id,
      status: $st,
      started_at: $sa,
      completed_at: $ca,
      duration_seconds: $dur,
      playwright_used: $pw,
      signals: {static: $s, runtime: $r, llm: $l, total: ($s + $r + $l)},
      by_severity: {critical: $sc, high: $sh, medium: $sm, low: $sl, info: $si},
      by_fixability: {auto_fix: $fa, agent_fix: $fg, escalate: $fe, skip: $fs},
      probe_failures: $pf,
      evidence_count: $ec
    }')
  DIMENSIONS_JSON=$(echo "$DIMENSIONS_JSON" | jq --argjson d "$DIM_ENTRY" '. + [$d]')
done

TOTAL_SIGNALS=$((STATIC_TOTAL + RUNTIME_TOTAL + LLM_TOTAL))

# Probe failures
PROBE_FAILURES_TOTAL=0
if [ -f "$SESSION_DIR/phase4-find-bugs/probe-failures.log" ]; then
  PROBE_FAILURES_TOTAL=$(wc -l < "$SESSION_DIR/phase4-find-bugs/probe-failures.log" 2>/dev/null | tr -d ' ')
  [ -z "$PROBE_FAILURES_TOTAL" ] && PROBE_FAILURES_TOTAL=0
fi

# Playwright summary
PLAYWRIGHT_SUMMARY="${PLAYWRIGHT_SUMMARY:-}"
if [ -z "$PLAYWRIGHT_SUMMARY" ]; then
  if [ "$PW_USED_COUNT" -gt 0 ]; then
    PLAYWRIGHT_SUMMARY="$PW_USED_COUNT lane đã dùng browser"
  else
    PLAYWRIGHT_SUMMARY="không có"
  fi
fi

# Status + timestamps
STATUS_PASS_FAIL="${STATUS_PASS_FAIL:-PASS}"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STARTED_AT="${STARTED_AT:-$NOW}"
COMPLETED_AT="${COMPLETED_AT:-$NOW}"

# ── Build aggregated rollups (probe, dim, registry, top fingerprints) ────────
build_count_json() {
  # $1 = path to TSV (1 col: key per line)
  local f="$1"
  if [ ! -s "$f" ]; then
    echo "{}"
    return
  fi
  sort "$f" | uniq -c | awk '{printf "%s\t%s\n", $2, $1}' | \
    jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {(.[0]): (.[1] | tonumber)}) | add // {}'
}

BY_PROBE_JSON=$(build_count_json "$TMP_PROBE_COUNTS")
BY_DIM_JSON=$(awk '{printf "%s\t%s\n", $1, $2}' "$TMP_DIM_COUNTS" | \
  jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {(.[0]): (.[1] | tonumber)}) | add // {}')
REQ_JSON=$(build_count_json "$TMP_REQ_REFS")
FEAT_JSON=$(build_count_json "$TMP_FEAT_REFS")
MOD_JSON=$(build_count_json "$TMP_MOD_REFS")

# Top fingerprints — top 10 sorted by severity priority
TOP_FP_JSON="[]"
if [ -s "$TMP_TOP_FP" ]; then
  TOP_FP_JSON=$(awk -F'\t' '{
    prio = ($1 == "critical") ? 5 : ($1 == "high") ? 4 : ($1 == "medium") ? 3 : ($1 == "low") ? 2 : 1
    printf "%d\t%s\t%s\t%s\t%s\n", prio, $1, $2, $3, $4
  }' "$TMP_TOP_FP" | sort -rn -k1 | head -10 | \
    jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {severity: .[1], fingerprint: .[2], title: .[3], file: .[4]})')
fi

# CDG decisions (E090/E090b) — read from cdg-tokens.json if exists
CDG_JSON="[]"
CDG_FILE="$SESSION_DIR/phase4-find-bugs/cdg-tokens.json"
if [ -f "$CDG_FILE" ]; then
  CDG_JSON=$(jq '[(.tokens // [])[] | {code: (.code // ""), decision: (.decision // ""), timestamp: (.timestamp // ""), context: (.context // {})}]' "$CDG_FILE" 2>/dev/null || echo "[]")
fi

# Audit chain hashes (concat → sha256)
SIG_HASH=$(echo -n "$SIGNALS_HASHES" | sha256sum 2>/dev/null | awk '{print $1}')
LS_HASH=$(echo -n "$LANESTATUS_HASHES" | sha256sum 2>/dev/null | awk '{print $1}')

# Duration phase overall
PHASE_DUR=0
if [ -n "$STARTED_AT" ] && [ -n "$COMPLETED_AT" ]; then
  PS=$(date -d "$STARTED_AT" +%s 2>/dev/null || echo 0)
  PE=$(date -d "$COMPLETED_AT" +%s 2>/dev/null || echo 0)
  [ "$PS" -gt 0 ] && [ "$PE" -gt 0 ] && PHASE_DUR=$((PE - PS))
fi

PROFILE="${PROFILE:-standard}"
SCOPE="${SCOPE:-all}"
INTERFACE_TYPE="${INTERFACE_TYPE:-unknown}"

# ── Build phase4-summary.json từ template (CORE-031) ─────────────────────────
SUMMARY_TMP="$TARGET_SUMMARY.tmp.$$"
if jq \
    --arg sid "$SESSION_ID" --arg st "$STATUS_PASS_FAIL" \
    --arg sa "$STARTED_AT" --arg ca "$COMPLETED_AT" --argjson dur "$PHASE_DUR" \
    --arg pf "$PROFILE" --arg sc "$SCOPE" --arg it "$INTERFACE_TYPE" \
    --argjson pwc "$PW_USED_COUNT" \
    --argjson dims "$DIMENSIONS_JSON" \
    --argjson ts "$TOTAL_SIGNALS" \
    --argjson bs "{\"static\": $STATIC_TOTAL, \"runtime\": $RUNTIME_TOTAL, \"llm\": $LLM_TOTAL}" \
    --argjson bsv "{\"critical\": $SEV_CRIT, \"high\": $SEV_HIGH, \"medium\": $SEV_MED, \"low\": $SEV_LOW, \"info\": $SEV_INFO}" \
    --argjson bfx "{\"auto_fix\": $FIX_AUTO, \"agent_fix\": $FIX_AGENT, \"escalate\": $FIX_ESC, \"skip\": $FIX_SKIP}" \
    --argjson bd "$BY_DIM_JSON" --argjson bp "$BY_PROBE_JSON" \
    --argjson tfp "$TOP_FP_JSON" --argjson pft "$PROBE_FAILURES_TOTAL" \
    --argjson rq "$REQ_JSON" --argjson ft "$FEAT_JSON" --argjson mo "$MOD_JSON" \
    --argjson cdg "$CDG_JSON" --argjson ev "$EVIDENCE_JSON" \
    --arg sh "$SIG_HASH" --arg lh "$LS_HASH" \
    'del(._template_notes, ._schema_notes)
     | .session_id = $sid | .status = $st
     | .started_at = $sa | .completed_at = $ca | .duration_seconds = $dur
     | .profile = $pf | .scope = $sc | .interface_type = $it
     | .playwright_used_count = $pwc
     | .dimensions = $dims
     | .aggregated.total_signals = $ts
     | .aggregated.by_source = $bs
     | .aggregated.by_severity = $bsv
     | .aggregated.by_fixability = $bfx
     | .aggregated.by_dimension = $bd
     | .aggregated.by_probe = $bp
     | .aggregated.top_fingerprints = $tfp
     | .aggregated.probe_failures_total = $pft
     | .registry_coverage.req_ids = $rq
     | .registry_coverage.feat_ids = $ft
     | .registry_coverage.module_ids = $mo
     | .cdg_decisions = $cdg
     | .evidence_index = $ev
     | .audit_chain.signals_sha256 = $sh
     | .audit_chain.lane_status_sha256 = $lh' \
    "$TPL_SUMMARY" > "$SUMMARY_TMP" \
    && [ -s "$SUMMARY_TMP" ] \
    && jq '.' "$SUMMARY_TMP" >/dev/null 2>&1; then
  mv "$SUMMARY_TMP" "$TARGET_SUMMARY"
else
  rm -f "$SUMMARY_TMP"
  echo "ERROR: phase4-summary.json generation fail" >&2
  exit 3
fi

# ── Populate Phase4-report.md template via sed → atomic write ────────────────
MD_TMP="$TARGET_MD.tmp.$$"
SUMMARY_REL="phase4-summary.json"
if sed \
    -e "s|\[STATUS_PASS_FAIL\]|$STATUS_PASS_FAIL|g" \
    -e "s|\[STARTED_AT\]|$STARTED_AT|g" \
    -e "s|\[COMPLETED_AT\]|$COMPLETED_AT|g" \
    -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
    -e "s|\[LANES_TOTAL\]|$LANES_TOTAL|g" \
    -e "s|\[LANES_COMPLETED\]|$LANES_COMPLETED|g" \
    -e "s|\[TOTAL_SIGNALS\]|$TOTAL_SIGNALS|g" \
    -e "s|\[STATIC_TOTAL\]|$STATIC_TOTAL|g" \
    -e "s|\[RUNTIME_TOTAL\]|$RUNTIME_TOTAL|g" \
    -e "s|\[LLM_TOTAL\]|$LLM_TOTAL|g" \
    -e "s|\[PROBE_FAILURES_TOTAL\]|$PROBE_FAILURES_TOTAL|g" \
    -e "s|\[PLAYWRIGHT_SUMMARY\]|$PLAYWRIGHT_SUMMARY|g" \
    -e "s|\[SEV_CRIT\]|$SEV_CRIT|g" \
    -e "s|\[SEV_HIGH\]|$SEV_HIGH|g" \
    -e "s|\[SUMMARY_PATH\]|$SUMMARY_REL|g" \
    -e '/_template_notes/d' -e '/_schema_notes/d' \
    "$TPL_MD" > "$MD_TMP" \
    && [ -s "$MD_TMP" ]; then
  mv "$MD_TMP" "$TARGET_MD"
  echo "ok"
  exit 0
else
  rm -f "$MD_TMP"
  echo "ERROR: Phase4-report.md generation fail" >&2
  exit 3
fi
