#!/usr/bin/env bash
# =============================================================================
# aggregate-and-spot-check.sh — Phase 5 Step 5.3 (gộp Aggregate + Spot-Check — v10.7)
# =============================================================================
# Gộp 2 logical sub-steps thành 1 atomic call:
#   5.3 Signal Aggregation — Python -m aggregate hoặc jq fallback merge + dedup by fingerprint
#   5.4 CORE-029 Spot-Check — sample 3 issues random validate required fields
#
# Required env vars:
#   SESSION_DIR
#
# Optional env vars:
#   AGGREGATE_TEMPLATE   (default: templates/phase5-triage/issue-registry.json)
#
# Exit codes:
#   0 — issue-registry.json valid + spot-check PASS hoặc WARN
#   1 — Required env var missing
#   2 — Aggregator fail cả Python lẫn jq fallback (E050)
#   3 — issue-registry.json empty / không có issues (E050)
#   4 — Spot-check WARN nhưng registry valid (continue allowed)
#
# Output JSON (stdout):
#   {
#     "total_issues": <int>,
#     "method": "python|jq_fallback",
#     "fingerprint_unique": <bool>,
#     "spot_check_warnings": <int>,
#     "samples_checked": <int>,
#     "status": "ok|warn"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

if [ -z "${SESSION_DIR:-}" ]; then
  echo "ERROR: Required env var \$SESSION_DIR is empty" >&2
  exit 1
fi

LANES_ROOT="$SESSION_DIR/phase4-find-bugs/lanes"
PHASE5_DIR="$SESSION_DIR/phase5-triage"
REGISTRY="$PHASE5_DIR/issue-registry.json"
TEMPLATE="${AGGREGATE_TEMPLATE:-templates/phase5-triage/issue-registry.json}"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$PHASE5_DIR"

# ── 5.3a: Aggregate — try Python first, fallback jq ──────────────────────────
METHOD="python"
AGG_OK=0

if command -v python >/dev/null 2>&1 && python -c "import aggregate" 2>/dev/null; then
  if python -m aggregate \
       --session-dir="$SESSION_DIR" \
       --output="$REGISTRY" \
       --template="$TEMPLATE" >/dev/null 2>&1; then
    AGG_OK=1
  fi
fi

if [ "$AGG_OK" -eq 0 ]; then
  METHOD="jq_fallback"
  TMP="$REGISTRY.tmp.$$"
  # Collect tất cả signals từ mọi lane → flatten → dedup by fingerprint (keep first)
  if find "$LANES_ROOT/" -name "signals.json" -print0 2>/dev/null \
       | xargs -0 jq -s --arg ts "$NOW" '
           {
             "$schema": "issue-registry-v1",
             "generated_at": $ts,
             "issues": [.[] | (.signals // [])[]] | unique_by(.fingerprint),
             "total_issues": 0
           }' > "$TMP" 2>/dev/null \
     && jq '.total_issues = (.issues | length)' "$TMP" > "$REGISTRY" 2>/dev/null \
     && rm -f "$TMP"; then
    AGG_OK=1
  else
    rm -f "$TMP"
  fi
fi

if [ "$AGG_OK" -eq 0 ]; then
  echo "ERROR: Aggregator fail cả Python lẫn jq fallback (E050)" >&2
  exit 2
fi

# ── Validate registry không rỗng ─────────────────────────────────────────────
if [ ! -s "$REGISTRY" ]; then
  echo "ERROR: issue-registry.json empty (E050)" >&2
  exit 3
fi

TOTAL=$(jq '.total_issues // 0' "$REGISTRY" 2>/dev/null || echo 0)
if [ "$TOTAL" -eq 0 ]; then
  echo "ERROR: issue-registry.json không có issues (E050)" >&2
  exit 3
fi

# Verify fingerprint uniqueness (correct jq syntax)
if jq -e '(.issues | length) == ([.issues[].fingerprint] | unique | length)' "$REGISTRY" >/dev/null 2>&1; then
  FP_UNIQUE="true"
else
  FP_UNIQUE="false"
fi

# ── v10.11: Fast-path enrichment từ phase4-summary.json (orphan output đã được consume) ──
# Phase 4 đã tính sẵn aggregated.total_signals + dimensions[] — không cần re-count
PHASE4_SUMMARY="$SESSION_DIR/phase4-find-bugs/phase4-summary.json"
ENRICH_SOURCE="none"
if [ -s "$PHASE4_SUMMARY" ] && jq -e '.aggregated.total_signals' "$PHASE4_SUMMARY" >/dev/null 2>&1; then
  TOTAL_SIGNALS_RAW=$(jq '.aggregated.total_signals // 0' "$PHASE4_SUMMARY" 2>/dev/null || echo 0)
  DIMS_COVERED=$(jq -c '[.dimensions[]? | (.dimension_id // .id // "?")] | unique' "$PHASE4_SUMMARY" 2>/dev/null || echo '[]')
  DEDUP_COUNT=$((TOTAL_SIGNALS_RAW - TOTAL))
  [ "$DEDUP_COUNT" -lt 0 ] && DEDUP_COUNT=0

  # Atomic update registry với enriched fields
  ENRICH_TMP="$REGISTRY.tmp.enrich.$$"
  if jq \
      --argjson tsr "$TOTAL_SIGNALS_RAW" \
      --argjson dc "$DIMS_COVERED" \
      --argjson dm "$DEDUP_COUNT" \
      '. + {
        total_signals_raw: $tsr,
        dimensions_covered: $dc,
        dedup_merge_count: $dm
      }' "$REGISTRY" > "$ENRICH_TMP" 2>/dev/null \
     && jq '.' "$ENRICH_TMP" >/dev/null 2>&1 \
     && mv "$ENRICH_TMP" "$REGISTRY"; then
    ENRICH_SOURCE="phase4_summary"
  else
    rm -f "$ENRICH_TMP"
    # Non-fatal — registry vẫn valid (chỉ thiếu fields enrich)
  fi
fi

# ── 5.4: Spot-Check (CORE-029) — sample 3 random issues ──────────────────────
WARNINGS=0
SAMPLES=0

if [ "$TOTAL" -ge 3 ]; then
  SAMPLES=3
  IDX1=$((RANDOM % TOTAL))
  IDX2=$(((IDX1 + 1 + (RANDOM % (TOTAL - 1))) % TOTAL))
  IDX3=$(((IDX2 + 1 + (RANDOM % (TOTAL - 1))) % TOTAL))
  for i in "$IDX1" "$IDX2" "$IDX3"; do
    if ! jq -e --argjson i "$i" '.issues[$i] | (.dimension_id // .lane) and (.probe_id // .probe) and .fingerprint' \
         "$REGISTRY" >/dev/null 2>&1; then
      echo "WARN: spot-check issue index=$i thiếu required fields" >&2
      WARNINGS=$((WARNINGS + 1))
    fi
  done
else
  SAMPLES=$TOTAL
  # Sample tất cả
  for i in $(seq 0 $((TOTAL - 1))); do
    if ! jq -e --argjson i "$i" '.issues[$i] | (.dimension_id // .lane) and (.probe_id // .probe) and .fingerprint' \
         "$REGISTRY" >/dev/null 2>&1; then
      WARNINGS=$((WARNINGS + 1))
    fi
  done
fi

# Status determination
STATUS="ok"
EXIT_CODE=0
if [ "$WARNINGS" -gt 0 ]; then
  STATUS="warn"
  EXIT_CODE=4
fi

# ── Emit aggregated JSON ─────────────────────────────────────────────────────
jq -n \
  --argjson ti "$TOTAL" \
  --arg m "$METHOD" \
  --argjson fu "$FP_UNIQUE" \
  --argjson w "$WARNINGS" \
  --argjson s "$SAMPLES" \
  --arg st "$STATUS" \
  --arg es "${ENRICH_SOURCE:-none}" \
  '{
    total_issues: $ti,
    method: $m,
    fingerprint_unique: $fu,
    spot_check_warnings: $w,
    samples_checked: $s,
    enrich_source: $es,
    status: $st
  }'

exit "$EXIT_CODE"
