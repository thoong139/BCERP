#!/usr/bin/env bash
# analyze-risk-heatmap.sh — Phase 2 Spike #2A
# Output: risk-heatmap.json (schema risk-heatmap-v1)
#
# Signals per file:
#   1. git_churn_30d  — số commit touch file trong N ngày
#   2. loc            — wc -l (proxy size)
#   3. missing_req_id — grep "REQ-[A-Z]+-[0-9]+" (annotation coverage)
#   4. has_paired_test— check *.test.* / *.spec.* / __tests__/ sibling
#   5. complexity_hint— LOC tier (proxy cyclomatic)
#   6. domain         — path → payment/auth/financial/regulatory/api/ui/infrastructure/generic
#
# Risk score (0-100): churn(0-25) + missing_req(0-20) + no_test(0-20) + complexity(0-15) + domain(0-20)
# Tier: ≥80 CRITICAL, 60-79 HIGH, 30-59 MEDIUM, <30 LOW

set -uo pipefail

# ─── Args ─────────────────────────────────────────────────────────────────────
ROOT="${ROOT:-.}"
SCOPE="${SCOPE:-all}"
SCOPE_NAME="${SCOPE_NAME:-}"
WINDOW="${WINDOW:-30}"
OUTPUT="${OUTPUT:-./risk-heatmap.json}"
LIMIT="${LIMIT:-50}"
SESSION_ID="${SESSION_ID:-spike-$(date +%Y%m%d-%H%M%S)}"
QUICK="${QUICK:-0}"          # 1 = skip git churn (5x faster)
MAX_LOC="${MAX_LOC:-10000}"  # skip files > 10K LOC (likely generated)

START_TS=$(date +%s)
ROOT=$(cd "$ROOT" && pwd)
cd "$ROOT" || { echo "ROOT not accessible: $ROOT" >&2; exit 2; }

# ─── File enumeration ─────────────────────────────────────────────────────────
# Exclude dirs (common build/vendor)
EXCLUDE_DIRS=(node_modules .git dist build .next out coverage .nuxt .turbo .cache __pycache__ bin obj target vendor venv .venv .mc-data .claude/references)
EXCLUDE_REGEX=$(IFS='|'; echo "${EXCLUDE_DIRS[*]}" | sed 's/\./\\./g')

# Include extensions (source code only)
EXTS="ts|tsx|js|jsx|py|cs|java|go|rs|php|rb|vue|svelte|dart|kt|swift|sh|cshtml|razor"

# Build file list (chunked to avoid huge arg list)
TMP_LIST=$(mktemp)
trap 'rm -f "$TMP_LIST"' EXIT

if [ "$SCOPE" = "module" ] && [ -n "$SCOPE_NAME" ]; then
  SEARCH_PATH="$SCOPE_NAME"
else
  SEARCH_PATH="."
fi

# Enumerate files
find "$SEARCH_PATH" -type f 2>/dev/null \
  | grep -Ev "($EXCLUDE_REGEX)/" \
  | grep -E "\.($EXTS)$" \
  > "$TMP_LIST"

TOTAL_FILES=$(wc -l < "$TMP_LIST" | tr -d ' ')
echo "Enumerated $TOTAL_FILES source files (scope=$SCOPE, search=$SEARCH_PATH)" >&2

# ─── Per-file analysis ────────────────────────────────────────────────────────
TMP_DATA=$(mktemp)
trap 'rm -f "$TMP_LIST" "$TMP_DATA"' EXIT

domain_of() {
  local path="$1"
  local lower="${path,,}"  # bash 4+ lowercase
  case "$lower" in
    *payment*|*checkout*|*billing*|*invoice*|*refund*|*pricing*) echo "payment" ;;
    *auth*|*login*|*logout*|*session*|*password*|*permission*|*role*|*rbac*|*oauth*|*jwt*) echo "auth" ;;
    *financial*|*finance*|*accounting*|*ledger*|*money*|*currency*|*tax*|*commission*) echo "financial" ;;
    *compliance*|*regulatory*|*audit*|*gdpr*|*pci*) echo "regulatory" ;;
    *api/*|*controller*|*route*|*endpoint*|*handler*|*resolver*) echo "api" ;;
    *ui/*|*component*|*page*|*view*|*screen*|*widget*) echo "ui" ;;
    *infra*|*config*|*middleware*|*migration*|*seed*) echo "infrastructure" ;;
    *) echo "generic" ;;
  esac
}

has_paired_test() {
  local path="$1"
  local dir base name
  dir=$(dirname "$path")
  base=$(basename "$path")
  name="${base%.*}"
  # check siblings + __tests__/ sub-dir + ../__tests__/
  if ls "$dir/${name}".test.* "$dir/${name}".spec.* "$dir/__tests__/${name}".* "$dir/../__tests__/${name}".* 2>/dev/null | grep -q .; then
    echo "true"
  else
    echo "false"
  fi
}

ANALYZED=0
SKIPPED=0
> "$TMP_DATA"

while IFS= read -r file; do
  # Strip leading ./
  file="${file#./}"

  # Skip if too large
  LOC=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
  [ -z "$LOC" ] && { SKIPPED=$((SKIPPED+1)); continue; }
  if [ "$LOC" -gt "$MAX_LOC" ]; then SKIPPED=$((SKIPPED+1)); continue; fi

  # Git churn (slowest signal)
  if [ "$QUICK" = "1" ]; then
    CHURN=0
  else
    CHURN=$(git log --since="${WINDOW}.days.ago" --pretty=format: --name-only -- "$file" 2>/dev/null | grep -c '.' 2>/dev/null | tr -d ' \n')
    CHURN=${CHURN:-0}
    [ "$CHURN" = "" ] && CHURN=0
  fi

  # REQ-ID
  if grep -qE "REQ-[A-Z0-9_-]+" "$file" 2>/dev/null; then
    MISSING_REQ="false"
  else
    MISSING_REQ="true"
  fi

  # Paired test
  HAS_TEST=$(has_paired_test "$file")

  # Complexity hint (proxy: LOC)
  if [ "$LOC" -gt 500 ]; then COMPLEXITY="high"
  elif [ "$LOC" -gt 200 ]; then COMPLEXITY="medium"
  else COMPLEXITY="low"
  fi

  # Domain
  DOMAIN=$(domain_of "$file")

  # Score calculation
  # churn_score: min(CHURN * 25 / 30, 25)
  CHURN_SCORE=$(( CHURN * 25 / 30 ))
  [ "$CHURN_SCORE" -gt 25 ] && CHURN_SCORE=25

  if [ "$MISSING_REQ" = "true" ]; then MISSING_REQ_SCORE=20; else MISSING_REQ_SCORE=0; fi
  if [ "$HAS_TEST" = "false" ]; then NO_TEST_SCORE=20; else NO_TEST_SCORE=0; fi

  case "$COMPLEXITY" in
    high) COMPLEXITY_SCORE=15 ;;
    medium) COMPLEXITY_SCORE=10 ;;
    low) COMPLEXITY_SCORE=0 ;;
  esac

  case "$DOMAIN" in
    payment|auth|financial) DOMAIN_SCORE=20 ;;
    regulatory) DOMAIN_SCORE=15 ;;
    api) DOMAIN_SCORE=10 ;;
    ui|infrastructure) DOMAIN_SCORE=5 ;;
    *) DOMAIN_SCORE=0 ;;
  esac

  TOTAL=$(( CHURN_SCORE + MISSING_REQ_SCORE + NO_TEST_SCORE + COMPLEXITY_SCORE + DOMAIN_SCORE ))
  [ "$TOTAL" -gt 100 ] && TOTAL=100

  if [ "$TOTAL" -ge 80 ]; then TIER="CRITICAL"
  elif [ "$TOTAL" -ge 60 ]; then TIER="HIGH"
  elif [ "$TOTAL" -ge 30 ]; then TIER="MEDIUM"
  else TIER="LOW"
  fi

  # Module = top-level dir under apps/ or src/, fallback first segment
  MODULE=$(echo "$file" | awk -F/ '{
    if ($1=="apps" || $1=="src") print $1"/"$2;
    else print $1;
  }')

  # JSON line per file (parse later)
  printf '%s\t%d\t%s\t%d\t%s\t%s\t%s\t%s\t%s\n' \
    "$file" "$TOTAL" "$TIER" "$LOC" "$CHURN" "$MISSING_REQ" "$HAS_TEST" "$COMPLEXITY" "$DOMAIN|$MODULE" \
    >> "$TMP_DATA"

  ANALYZED=$((ANALYZED+1))
  # Progress every 200 files
  if [ $((ANALYZED % 200)) -eq 0 ]; then echo "  progress: analyzed $ANALYZED/$TOTAL_FILES" >&2; fi
done < "$TMP_LIST"

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

echo "Analyzed $ANALYZED files ($SKIPPED skipped) in ${DURATION}s" >&2

# ─── Aggregate + Output JSON via jq ───────────────────────────────────────────
mkdir -p "$(dirname "$OUTPUT")"

# Build files array (top LIMIT by risk_score)
FILES_JSON=$(sort -k2,2 -nr "$TMP_DATA" | head -n "$LIMIT" | awk -F'\t' '
  BEGIN { printf "[" }
  NR>1 { printf "," }
  {
    split($9, parts, "|"); domain=parts[1]; mod=parts[2];
    printf "{\"path\":\"%s\",\"risk_score\":%d,\"risk_tier\":\"%s\",\"signals\":{\"git_churn_30d\":%d,\"loc\":%d,\"missing_req_id\":%s,\"has_paired_test\":%s,\"complexity_hint\":\"%s\",\"domain\":\"%s\"}}",
           $1, $2, $3, $5, $4, $6, $7, $8, domain
  }
  END { printf "]" }
')

# Build modules aggregate
MODULES_JSON=$(awk -F'\t' '
  {
    split($9, p, "|"); domain=p[1]; mod=p[2];
    mod_count[mod]++;
    mod_score[mod]+=$2;
    if ($2 >= 60) mod_risk[mod]++;
    mod_churn[mod]+=$5;
    if ($6=="false") mod_with_req[mod]++;
    if ($7=="true") mod_with_test[mod]++;
    mod_domain[mod"|"domain]++;
  }
  END {
    printf "["; first=1;
    for (m in mod_count) {
      if (!first) printf ","; first=0;
      avg = mod_score[m] / mod_count[m];
      req_pct = (mod_with_req[m]+0) * 100 / mod_count[m];
      test_pct = (mod_with_test[m]+0) * 100 / mod_count[m];
      avg_churn = mod_churn[m] / mod_count[m];
      # dominant domain
      best=""; bestc=0;
      for (k in mod_domain) {
        split(k, kp, "|");
        if (kp[1]==m && mod_domain[k]>bestc) { bestc=mod_domain[k]; best=kp[2]; }
      }
      printf "{\"module\":\"%s\",\"score\":%d,\"files_at_risk\":%d,\"total_files\":%d,\"dominant_domain\":\"%s\",\"top_signals\":{\"avg_churn\":%.2f,\"req_id_coverage_pct\":%.1f,\"test_coverage_pct\":%.1f}}",
        m, int(avg+0.5), (mod_risk[m]+0), mod_count[m], best, avg_churn, req_pct, test_pct;
    }
    printf "]";
  }
' "$TMP_DATA" | jq 'sort_by(-.score)')

# Summary
CRITICAL=$(awk -F'\t' '$3=="CRITICAL"' "$TMP_DATA" | wc -l | tr -d ' ')
HIGH=$(awk -F'\t' '$3=="HIGH"' "$TMP_DATA" | wc -l | tr -d ' ')
MEDIUM=$(awk -F'\t' '$3=="MEDIUM"' "$TMP_DATA" | wc -l | tr -d ' ')
LOW=$(awk -F'\t' '$3=="LOW"' "$TMP_DATA" | wc -l | tr -d ' ')
MISSING_REQ_PCT=$(awk -F'\t' 'BEGIN{c=0;t=0} {t++; if ($6=="true") c++} END{if(t>0) printf "%.1f", c*100/t; else print 0}' "$TMP_DATA")
MISSING_TEST_PCT=$(awk -F'\t' 'BEGIN{c=0;t=0} {t++; if ($7=="false") c++} END{if(t>0) printf "%.1f", c*100/t; else print 0}' "$TMP_DATA")
AVG_SCORE=$(awk -F'\t' 'BEGIN{s=0;n=0} {n++; s+=$2} END{if(n>0) printf "%.2f", s/n; else print 0}' "$TMP_DATA")

# Final JSON
jq -n \
  --arg sid "$SESSION_ID" \
  --arg gen "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg scope "$SCOPE" \
  --arg sname "$SCOPE_NAME" \
  --argjson window "$WINDOW" \
  --argjson files "$FILES_JSON" \
  --argjson modules "$MODULES_JSON" \
  --argjson total "$ANALYZED" \
  --argjson crit "$CRITICAL" --argjson hi "$HIGH" --argjson med "$MEDIUM" --argjson lo "$LOW" \
  --arg mreq "$MISSING_REQ_PCT" --arg mtest "$MISSING_TEST_PCT" --arg avg "$AVG_SCORE" \
  --argjson dur "$DURATION" \
  '{
    "$schema": "risk-heatmap-v1",
    session_id: $sid,
    generated_at: $gen,
    scope: $scope,
    scope_name: (if $sname=="" then null else $sname end),
    analysis_window_days: $window,
    files: $files,
    modules: $modules,
    summary: {
      total_files_analyzed: $total,
      critical_count: $crit,
      high_count: $hi,
      medium_count: $med,
      low_count: $lo,
      missing_req_id_pct: ($mreq|tonumber),
      missing_tests_pct: ($mtest|tonumber),
      avg_risk_score: ($avg|tonumber),
      duration_seconds: $dur
    }
  }' > "$OUTPUT"

echo "✓ Written: $OUTPUT" >&2
echo "  Files: $ANALYZED | CRITICAL=$CRITICAL HIGH=$HIGH MEDIUM=$MEDIUM LOW=$LOW | Duration: ${DURATION}s" >&2
