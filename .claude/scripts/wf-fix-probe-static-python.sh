#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-python.sh — Static probe: Python (FastAPI/Django) checks
#
# Phase B v8 — Stack-Aware Probe Registry. Phat hien:
#  - QD1: Endpoint handler thieu try/except (FastAPI APIRouter, Flask routes)
#  - QD1: async function thieu await trong body (defective concurrency)
#  - QD2: ORM N+1 patterns (sqlalchemy session.query().all() trong loop, Django .objects.filter() loop)
#  - QD2: Function thieu return type hint (loose typing)
#
# Probes:
#   P-QD1-python-endpoint-check  → FastAPI/Flask endpoint contract
#   P-QD2-python-orm-nplus1      → SQLAlchemy/Django ORM pattern audit
#
# OUTPUT: JSON stdout theo schema lane-signals-v1
# Cache policy: allowed (static analysis)
#
# USAGE:
#   bash wf-fix-probe-static-python.sh \
#     --session-dir <path> --lane <name> --probe <id> \
#     [--profile quick|standard|deep|exhaustive] [--source-dir src/]
#
# EXIT CODES: 0 success, 1 error


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE=""
PROBE_ID=""
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="src/"

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --probe) PROBE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

# Default lane if not provided
[ -z "$LANE" ] && case "$PROBE_ID" in
  P-QD1-*) LANE="wf-fix-functional" ;;
  P-QD2-*) LANE="wf-fix-business" ;;
  *)       LANE="wf-fix-functional" ;;
esac

# Determine dimension
case "$PROBE_ID" in
  P-QD1-*) DIMENSION="QD1" ;;
  P-QD2-*) DIMENSION="QD2" ;;
  *)       DIMENSION="QD1" ;;
esac

if [ ! -d "$SOURCE_DIR" ]; then
  jq -nc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" --arg dim "$DIMENSION" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: $dim, probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now,
      signals: [], skip_reason: "no_source_dir"}'
  exit 0
fi

EXCLUDE='(\.venv|venv|node_modules|\.git/|__pycache__|dist|build|/tests?/|/test_|_test\.py|fixtures)'

EMIT() {
  local title="$1" desc="$2" severity="$3" file="$4" line="$5" suggested_action="$6"
  local fp
  fp=$(echo -n "$DIMENSION|$file|$line|$PROBE_ID|$title" | _sha256 | awk '{print "sha256:"$1}')
  jq -nc \
    --arg t "$title" --arg d "$desc" --arg s "$severity" \
    --arg f "$file" --argjson l "$line" --arg fp "$fp" --arg pid "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" --arg lane "$LANE" --arg now "$(iso_now)" \
    --arg sa "$suggested_action" --arg dim "$DIMENSION" \
    '{
      "$schema": "signal-v2",
      dimension_id: $dim,
      probe_id: $pid,
      probe_version: $pver,
      severity: $s,
      fixability: "agent_fix",
      domain: "backend",
      title: $t,
      description: $d,
      location: { file: $f, line: $l, column: null, selector: null, url: null },
      evidence: { code_snippet: null, test_failure: null, screenshot: null,
                  related_signals: [], reproduction_steps: null },
      remediation: { suggested_action: $sa, test_recommendation: null,
                     references: [], estimated_effort_min: 5 },
      fingerprint: $fp,
      probe_metadata: { lane: $lane, generated_at: $now }
    }'
}

SIGNALS_FILE=$(mktemp)
trap 'rm -f "$SIGNALS_FILE"' EXIT

# ────────────────────────────────────────────────────────────
# P-QD1-python-endpoint-check: FastAPI/Flask endpoint contract
# ────────────────────────────────────────────────────────────
if [ "$PROBE_ID" = "P-QD1-python-endpoint-check" ]; then
  # Detect FastAPI router decorators without try/except in function body
  # Pattern: @router.{get,post,...} → next 30 lines should contain try: or except
  while IFS=: read -r file line _; do
    [ -z "$file" ] && continue
    file_rel="${file#$SOURCE_DIR}"
    # Look at function body — next 30 lines should have try/except
    body=$(awk -v start="$line" 'NR >= start && NR <= start+30 {print}' "$file" 2>/dev/null || echo "")
    if [ -n "$body" ] && ! echo "$body" | grep -qE '^\s*(try:|except |raise HTTPException|raise )'; then
      EMIT "Endpoint thieu error handling" \
        "Endpoint tai $file:$line khong co try/except hoac raise HTTPException de bao loi cho client. Loi sinh ra trong handler se thanh 500 generic." \
        "high" "$file_rel" "$line" \
        "Wrap business logic trong try/except hoac dung HTTPException de tra ve loi co structure." \
        >> "$SIGNALS_FILE"
    fi
  done < <(
    grep -rEn '^\s*@(router|app)\.(get|post|put|delete|patch)\(' "$SOURCE_DIR" \
      --include='*.py' 2>/dev/null \
      | grep -vE "$EXCLUDE" \
      | head -200
  )
fi

# ────────────────────────────────────────────────────────────
# P-QD2-python-orm-nplus1: SQLAlchemy / Django N+1 patterns
# ────────────────────────────────────────────────────────────
if [ "$PROBE_ID" = "P-QD2-python-orm-nplus1" ]; then
  # SQLAlchemy: session.query().all() inside for loop
  # Django: Model.objects.filter() inside for loop
  while IFS=: read -r file line _; do
    [ -z "$file" ] && continue
    file_rel="${file#$SOURCE_DIR}"
    EMIT "Python ORM truy van trong vong lap (N+1 risk)" \
      "Tai $file:$line phat hien query .objects.filter() hoac session.query() ben trong vong lap. Day la pattern N+1 dien hinh — moi iteration sinh 1 query rieng." \
      "medium" "$file_rel" "$line" \
      "Dung select_related() / prefetch_related() (Django) hoac options(joinedload(...)) (SQLAlchemy) de batch load tat ca records 1 query." \
      >> "$SIGNALS_FILE"
  done < <(
    grep -rEn '\.(objects\.filter|objects\.get|objects\.all|query\([^)]*\)\.all|query\([^)]*\)\.filter)' "$SOURCE_DIR" \
      --include='*.py' 2>/dev/null \
      | grep -vE "$EXCLUDE" \
      | head -100 \
      | while IFS= read -r match; do
          # Check if previous line(s) contains a `for ... in` loop
          file=$(echo "$match" | cut -d: -f1)
          line=$(echo "$match" | cut -d: -f2)
          if [ -n "$file" ] && [ -n "$line" ]; then
            prev=$((line - 5))
            [ $prev -lt 1 ] && prev=1
            context=$(awk -v s="$prev" -v e="$line" 'NR >= s && NR < e' "$file" 2>/dev/null || echo "")
            if echo "$context" | grep -qE '^\s*for\s+\w+\s+in'; then
              echo "$match"
            fi
          fi
        done
  )
fi

# ────────────────────────────────────────────────────────────
# Output
# ────────────────────────────────────────────────────────────
SIGNAL_COUNT=$(wc -l < "$SIGNALS_FILE" | tr -d ' ')

if [ "$SIGNAL_COUNT" -eq 0 ]; then
  jq -nc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" --arg dim "$DIMENSION" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: $dim, probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now, signals: []}'
else
  jq -sc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" --arg dim "$DIMENSION" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: $dim, probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now, signals: .}' \
    "$SIGNALS_FILE"
fi

exit 0
