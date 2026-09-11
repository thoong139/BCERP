#!/usr/bin/env bash
# implement-postgate.sh — POST-GATE T1→T4 validation cho Phase 6.
# Sprint 1 bash delegation — port từ phase6-finalize.md §POST-GATE.
#
# Usage:
#   bash implement-postgate.sh --session-dir=$SESSION_DIR --req-ids=REQ-X,REQ-Y
#
# Args:
#   --session-dir=<path>  Session dir chứa impl-report.md + phase-summary.md + impl-status.json (required)
#   --req-ids=<csv>       Comma-separated REQ-IDs in scope (required)
#   --registry=<path>     Registry path (default: .mc-data/docs/_meta/req-registry.json)
#   --strict              Treat WARN as FAIL (default: WARN không fail)
#
# Output (stdout): JSON
#   {
#     "passed": true|false,
#     "T1": true|false,
#     "T2": true|false,
#     "T3": true|false,
#     "T4": true|false,
#     "failures": ["T1: phase-summary.md missing", ...],
#     "warnings": ["T4.2: no REQ-ID comment in any file"],
#     "details": {
#       "T1_files_checked": [...],
#       "T2_sections_found": {...},
#       "T3_word_counts": {...},
#       "T4_req_ids_done": [...]
#     }
#   }
#
# Exit codes:
#   0 = passed (all T1-T4 pass)
#   1 = failed (one or more T fail)
#   2 = invalid args

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=implement-common.sh
source "$SCRIPTS_DIR/implement-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

SESSION_DIR=""
REQ_IDS=""
REGISTRY=".mc-data/docs/_meta/req-registry.json"
STRICT=false

for arg in "$@"; do
  case "$arg" in
    --session-dir=*) SESSION_DIR="${arg#*=}" ;;
    --req-ids=*)     REQ_IDS="${arg#*=}" ;;
    --registry=*)    REGISTRY="${arg#*=}" ;;
    --strict)        STRICT=true ;;
    *) log_warn "Unknown arg: $arg" ;;
  esac
done

[[ -z "$SESSION_DIR" ]] && { log_error "--session-dir required"; exit 2; }
[[ -z "$REQ_IDS" ]] && { log_error "--req-ids required"; exit 2; }

REPORT="$SESSION_DIR/impl-report.md"
SUMMARY="$SESSION_DIR/phase-summary.md"
STATUS="$SESSION_DIR/impl-status.json"

FAILURES=()
WARNINGS=()
T1_PASS=true
T2_PASS=true
T3_PASS=true
T4_PASS=true

# ─── T1: Existence + non-empty ───────────────────────────────

T1_FILES=("$REGISTRY" "$REPORT" "$SUMMARY" "$STATUS")
T1_FILES_JSON='[]'
T1_FILES_TMP=()
for f in "${T1_FILES[@]}"; do
  T1_FILES_TMP+=("$f")
  if [[ ! -s "$f" ]]; then
    FAILURES+=("T1: missing or empty file: $f")
    T1_PASS=false
  fi
done
if has_jq; then
  T1_FILES_JSON=$(printf '%s\n' "${T1_FILES_TMP[@]}" | jq -R . | jq -s .)
fi

# ─── T2: Structure (required sections) ────────────────────────

T2_DETAILS='{}'
if [[ -s "$REPORT" ]]; then
  for sec in "## Quality Metrics" "## Requirements Coverage"; do
    if ! grep -q "$sec" "$REPORT"; then
      FAILURES+=("T2: missing section '$sec' in impl-report.md")
      T2_PASS=false
    fi
  done
fi
if [[ -s "$SUMMARY" ]]; then
  for sec in "## Đã làm gì" "## Kết quả chính"; do
    if ! grep -q "$sec" "$SUMMARY"; then
      FAILURES+=("T2: missing section '$sec' in phase-summary.md")
      T2_PASS=false
    fi
  done
fi

# ─── T3: Content depth ────────────────────────────────────────

T3_DETAILS='{}'
SUMMARY_WORDS=0
REPORT_WORDS=0
if [[ -s "$SUMMARY" ]]; then
  SUMMARY_WORDS=$(wc -w < "$SUMMARY" | tr -d ' ')
  if (( SUMMARY_WORDS < 50 )); then
    FAILURES+=("T3: phase-summary.md word count $SUMMARY_WORDS < 50")
    T3_PASS=false
  fi
fi
if [[ -s "$REPORT" ]]; then
  REPORT_WORDS=$(wc -w < "$REPORT" | tr -d ' ')
  if (( REPORT_WORDS < 100 )); then
    FAILURES+=("T3: impl-report.md word count $REPORT_WORDS < 100")
    T3_PASS=false
  fi
fi

# ─── T4: Cross-reference ───────────────────────────────────────

T4_REQ_DONE=()
T4_REQ_NOT_DONE=()

# T4.1: Registry valid + all REQ-IDs status="done"
if [[ -s "$REGISTRY" ]] && has_jq; then
  if ! jq empty "$REGISTRY" 2>/dev/null; then
    FAILURES+=("T4.1: registry not valid JSON")
    T4_PASS=false
  else
    IFS=',' read -ra REQ_ARR <<< "$REQ_IDS"
    for rid in "${REQ_ARR[@]}"; do
      rid="${rid// /}"
      [[ -z "$rid" ]] && continue
      status=$(jq -r --arg id "$rid" '.requirements[] | select(.req_id==$id) | .impl_status' "$REGISTRY" 2>/dev/null)
      if [[ "$status" == "done" ]]; then
        T4_REQ_DONE+=("$rid")
      else
        T4_REQ_NOT_DONE+=("$rid:${status:-NOT_FOUND}")
        FAILURES+=("T4.1: REQ-ID $rid impl_status='${status:-NOT_FOUND}' (expected 'done')")
        T4_PASS=false
      fi
    done
  fi
fi

# T4.2: REQ-ID comment in at least 1 created/modified file (warning only)
if [[ -s "$STATUS" ]] && has_jq; then
  FILES_CHANGED=$(jq -r '(.files_created // [])[], (.files_modified // [])[]' "$STATUS" 2>/dev/null | head -20)
  if [[ -n "$FILES_CHANGED" ]]; then
    FOUND_REQ_COMMENT=0
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      [[ -f "$f" ]] && grep -qE "REQ-ID:[[:space:]]*(REQ-[A-Z0-9]+(-[A-Z0-9]+)*-[0-9]+)" "$f" 2>/dev/null && {
        FOUND_REQ_COMMENT=1
        break
      }
    done <<< "$FILES_CHANGED"
    if [[ "$FOUND_REQ_COMMENT" -eq 0 ]]; then
      WARNINGS+=("T4.2: no REQ-ID comment found in any created/modified file (CORE-003)")
      $STRICT && T4_PASS=false && FAILURES+=("T4.2 [strict]: no REQ-ID comment in code")
    fi
  fi
fi

# ─── Build details JSON ──────────────────────────────────────

if has_jq; then
  # grep -c returns count + non-zero exit when 0 matches → wrap với `|| true` để tránh
  # `set -o pipefail` kill script. Wrapping với `_count_sections` keeps the count
  # value even when grep exits 1 (no matches found).
  _count_sections() {
    local file="$1"
    local pattern="$2"
    local n
    [[ ! -s "$file" ]] && { echo 0; return 0; }
    n=$(grep -cE "$pattern" "$file" 2>/dev/null) || true
    echo "${n:-0}"
  }
  REPORT_SECTIONS=$(_count_sections "$REPORT" '^## Quality Metrics$|^## Requirements Coverage$')
  SUMMARY_SECTIONS=$(_count_sections "$SUMMARY" '^## Đã làm gì$|^## Kết quả chính$')

  T2_DETAILS=$(jq -nc \
    --argjson rs "$REPORT_SECTIONS" \
    --argjson ss "$SUMMARY_SECTIONS" \
    '{report_sections: $rs, summary_sections: $ss}')

  T3_DETAILS=$(jq -nc \
    --argjson sw "$SUMMARY_WORDS" \
    --argjson rw "$REPORT_WORDS" \
    '{summary_words: $sw, report_words: $rw}')
fi

# ─── Compute passed + emit JSON ──────────────────────────────

OVERALL=true
$T1_PASS || OVERALL=false
$T2_PASS || OVERALL=false
$T3_PASS || OVERALL=false
$T4_PASS || OVERALL=false

if has_jq; then
  FAIL_JSON='[]'
  if (( ${#FAILURES[@]} > 0 )); then
    FAIL_JSON=$(printf '%s\n' "${FAILURES[@]}" | jq -R . | jq -s .)
  fi
  WARN_JSON='[]'
  if (( ${#WARNINGS[@]} > 0 )); then
    WARN_JSON=$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)
  fi
  REQ_DONE_JSON='[]'
  if (( ${#T4_REQ_DONE[@]} > 0 )); then
    REQ_DONE_JSON=$(printf '%s\n' "${T4_REQ_DONE[@]}" | jq -R . | jq -s .)
  fi

  RESULT=$(jq -nc \
    --argjson passed "$($OVERALL && echo true || echo false)" \
    --argjson t1 "$($T1_PASS && echo true || echo false)" \
    --argjson t2 "$($T2_PASS && echo true || echo false)" \
    --argjson t3 "$($T3_PASS && echo true || echo false)" \
    --argjson t4 "$($T4_PASS && echo true || echo false)" \
    --argjson failures "$FAIL_JSON" \
    --argjson warnings "$WARN_JSON" \
    --argjson t1_files "$T1_FILES_JSON" \
    --argjson t2_details "$T2_DETAILS" \
    --argjson t3_details "$T3_DETAILS" \
    --argjson req_done "$REQ_DONE_JSON" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      passed: $passed,
      T1: $t1, T2: $t2, T3: $t3, T4: $t4,
      failures: $failures,
      warnings: $warnings,
      details: {
        T1_files_checked: $t1_files,
        T2: $t2_details,
        T3: $t3_details,
        T4_req_ids_done: $req_done
      },
      checked_at: $ts
    }')
  echo "$RESULT" | jq '.'
else
  echo "{\"passed\":$($OVERALL && echo true || echo false),\"T1\":$($T1_PASS && echo true || echo false),\"T2\":$($T2_PASS && echo true || echo false),\"T3\":$($T3_PASS && echo true || echo false),\"T4\":$($T4_PASS && echo true || echo false)}"
fi

$OVERALL && exit 0 || exit 1
