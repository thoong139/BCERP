#!/usr/bin/env bash
# wf-fix-validate-gate.sh — T1-T4 schema validation chung cho QD lane outputs
#
# Thay the inline jq queries lap di lap lai trong cac SKILL.md POST-GATE.
# Cung 1 lieu, 4 schemas: signal-v2, lane-status-v1, lane-report-v1, signals.json wrapper.
#
# USAGE:
#   bash wf-fix-validate-gate.sh --type=signal --file=<path>
#   bash wf-fix-validate-gate.sh --type=lane-status --file=<path>
#   bash wf-fix-validate-gate.sh --type=signals-wrapper --file=<path>  # array container
#   bash wf-fix-validate-gate.sh --type=lane-report --file=<path>      # markdown
#
# OUTPUT (stdout): JSON {"pass": true|false, "tier_results": {...}, "errors": [...]}
# EXIT CODES: 0 all pass, 1 any tier fail
#
# T1 (Existence): file exists, non-empty
# T2 (Structure): required top-level keys/sections present
# T3 (Content): values valid (enums, types, min depth)
# T4 (Cross-ref): IDs/refs khop voi expected sets (optional, requires --xref)
#
# Author: S5 wf-fix-bugs v7.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

TYPE=""
FILE=""
XREF=""
EXPECTED_DIM=""

while [ $# -gt 0 ]; do
  case "$1" in
    --type=*) TYPE="${1#*=}"; shift ;;
    --type) TYPE="$2"; shift 2 ;;
    --file=*) FILE="${1#*=}"; shift ;;
    --file) FILE="$2"; shift 2 ;;
    --xref=*) XREF="${1#*=}"; shift ;;
    --xref) XREF="$2"; shift 2 ;;
    --dimension=*) EXPECTED_DIM="${1#*=}"; shift ;;
    --dimension) EXPECTED_DIM="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

[ -z "$TYPE" ] && { echo "ERROR: --type required" >&2; exit 1; }
[ -z "$FILE" ] && { echo "ERROR: --file required" >&2; exit 1; }

PASS=true
ERRORS_JSON='[]'
T1=true; T2=true; T3=true; T4=true

add_error() {
  local tier="$1" msg="$2"
  ERRORS_JSON=$(jq -c --arg tier "$tier" --arg msg "$msg" '. + [{tier:$tier, message:$msg}]' <<< "$ERRORS_JSON")
  PASS=false
}

# ============================================================
# T1: Existence
# ============================================================
if [ ! -e "$FILE" ]; then
  T1=false; add_error "T1" "file_not_found: $FILE"
elif [ ! -s "$FILE" ]; then
  T1=false; add_error "T1" "file_empty: $FILE"
fi

# Skip remaining tiers if T1 failed
if [ "$T1" = "true" ]; then
case "$TYPE" in
  # ============================================================
  # signal-v2 — single signal object
  # ============================================================
  signal)
    if ! jq -e '.' "$FILE" >/dev/null 2>&1; then
      T2=false; add_error "T2" "invalid_json"
    else
      # Required fields
      for f in '$schema' id dimension_id probe_id severity fixability title fingerprint detected_at; do
        val=$(jq -r ".[\"$f\"] // empty" "$FILE")
        [ -z "$val" ] && { T2=false; add_error "T2" "missing_field:$f"; }
      done
      # Enum validation (T3)
      sev=$(jq -r '.severity // empty' "$FILE")
      case "$sev" in
        critical|high|medium|low|info) ;;
        *) T3=false; add_error "T3" "invalid_severity:$sev" ;;
      esac
      fix=$(jq -r '.fixability // empty' "$FILE")
      case "$fix" in
        auto_fix|agent_fix|escalate|skip) ;;
        *) T3=false; add_error "T3" "invalid_fixability:$fix" ;;
      esac
      # Dimension match
      if [ -n "$EXPECTED_DIM" ]; then
        actual_dim=$(jq -r '.dimension_id // empty' "$FILE")
        [ "$actual_dim" != "$EXPECTED_DIM" ] && \
          { T4=false; add_error "T4" "dimension_mismatch:expected=$EXPECTED_DIM,actual=$actual_dim"; }
      fi
    fi
    ;;

  # ============================================================
  # signals-wrapper — JSON wrapper with .signals array
  # 2 modes:
  #   - "signals-wrapper" (default) → emitted signals (id required, dedup'd)
  #   - "signals-wrapper-raw" → raw probe output (id KHONG yeu cau, assign khi emit)
  # ============================================================
  signals-wrapper|signals-wrapper-raw)
    if ! jq -e '.' "$FILE" >/dev/null 2>&1; then
      T2=false; add_error "T2" "invalid_json"
    else
      for f in '$schema' lane dimension generated_at signals; do
        if ! jq -e ".[\"$f\"]" "$FILE" >/dev/null 2>&1; then
          T2=false; add_error "T2" "missing_field:$f"
        fi
      done
      schema=$(jq -r '."$schema" // empty' "$FILE")
      [ "$schema" != "lane-signals-v1" ] && { T3=false; add_error "T3" "invalid_schema:$schema"; }

      # Each signal must have required fields
      sig_count=$(jq '.signals | length' "$FILE" 2>/dev/null || echo 0)
      if [ "$sig_count" -gt 0 ]; then
        if [ "$TYPE" = "signals-wrapper-raw" ]; then
          # Raw mode — id KHONG yeu cau (assign khi emit)
          invalid=$(jq -c '.signals | map(select(
            (."$schema" // "") != "signal-v2"
            or (.dimension_id // "") == ""
            or (.severity // "") == ""
            or (.fingerprint // "") == ""
            or (.probe_id // "") == ""
          )) | length' "$FILE")
        else
          # Emitted mode — id required
          invalid=$(jq -c '.signals | map(select(
            (."$schema" // "") != "signal-v2"
            or (.id // "") == ""
            or (.dimension_id // "") == ""
            or (.severity // "") == ""
            or (.fingerprint // "") == ""
          )) | length' "$FILE")
        fi
        [ "$invalid" -gt 0 ] && { T3=false; add_error "T3" "invalid_signals_count:$invalid"; }
      fi

      # Dimension match
      if [ -n "$EXPECTED_DIM" ]; then
        actual_dim=$(jq -r '.dimension // empty' "$FILE")
        [ "$actual_dim" != "$EXPECTED_DIM" ] && \
          { T4=false; add_error "T4" "dimension_mismatch:expected=$EXPECTED_DIM,actual=$actual_dim"; }
      fi
    fi
    ;;

  # ============================================================
  # lane-status-v1
  # ============================================================
  lane-status)
    if ! jq -e '.' "$FILE" >/dev/null 2>&1; then
      T2=false; add_error "T2" "invalid_json"
    else
      for f in '$schema' lane dimension session_id profile status started_at probes totals; do
        if ! jq -e ".[\"$f\"]" "$FILE" >/dev/null 2>&1; then
          T2=false; add_error "T2" "missing_field:$f"
        fi
      done
      schema=$(jq -r '."$schema" // empty' "$FILE")
      [ "$schema" != "lane-status-v1" ] && { T3=false; add_error "T3" "invalid_schema:$schema"; }

      status=$(jq -r '.status // empty' "$FILE")
      case "$status" in
        pending|in_progress|completed|partial|failed) ;;
        *) T3=false; add_error "T3" "invalid_status:$status" ;;
      esac

      profile=$(jq -r '.profile // empty' "$FILE")
      case "$profile" in
        quick|standard|deep|exhaustive) ;;
        *) T3=false; add_error "T3" "invalid_profile:$profile" ;;
      esac

      # Totals consistency: signals_emitted = sum(signals_by_severity)
      total=$(jq '.totals.signals_emitted // 0' "$FILE")
      sum=$(jq '[.totals.signals_by_severity[]?] | add // 0' "$FILE")
      [ "$total" != "$sum" ] && { T3=false; add_error "T3" "totals_mismatch:emitted=$total,sum=$sum"; }
    fi
    ;;

  # ============================================================
  # lane-report-v1 (Markdown — T2 = required headings)
  # ============================================================
  lane-report)
    # Required H2 sections per lane-report-v1 template
    REQ_HEADINGS=("## Tom tat" "## Phat hien" "## Ket qua" "## Ket luan")
    for heading in "${REQ_HEADINGS[@]}"; do
      if ! grep -qF "$heading" "$FILE"; then
        T2=false; add_error "T2" "missing_section:$heading"
      fi
    done
    # T3 content depth: file > 200 chars
    size=$(wc -c < "$FILE")
    [ "$size" -lt 200 ] && { T3=false; add_error "T3" "content_too_short:$size"; }
    ;;

  *)
    add_error "T1" "unknown_type:$TYPE"
    ;;
esac
fi

# ============================================================
# Output
# ============================================================
RESULT=$(jq -nc \
  --arg type "$TYPE" --arg file "$FILE" \
  --argjson pass "$PASS" \
  --argjson t1 "$T1" --argjson t2 "$T2" --argjson t3 "$T3" --argjson t4 "$T4" \
  --argjson errors "$ERRORS_JSON" \
  '{
    type: $type, file: $file, pass: $pass,
    tier_results: {T1_existence: $t1, T2_structure: $t2, T3_content: $t3, T4_xref: $t4},
    errors: $errors
  }')

echo "$RESULT"

if [ "$PASS" = "true" ]; then
  exit 0
else
  exit 1
fi
