#!/usr/bin/env bash
set -euo pipefail
# REQ-ID: MCV3-internal (IMP-008)
# wf-fix-probe-static-signal-validate.sh — Reusable signal schema validation
#
# Strengthens CORE-029 spot-check with:
#   1. description min 50 chars
#   2. evidence.file_path exists on disk (skip if "N/A")
#   3. severity in allowed set (from dim.json severity_rules)
#   4. confidence range [0.0, 1.0]
#   5. code_snippet required in evidence
#   6. sample_size = min(10, total * 0.1) instead of hardcode 3
#   7. --probe arg validates vs valid probe list from dimension.json
#
# USAGE:
#   source wf-fix-probe-static-signal-validate.sh
#   validate_signal_batch signals.json dim.json [--sample-n N]
#   probe_validate_arg "P-QD1-some-probe" dim.json
#
# EXIT CODES: 0 = all valid, 1 = validation errors found
#
# OUTPUT: Prints per-signal validation results. Returns 0 if all pass, 1 if any fail.


# Allowed severity values (canonical)
SIGNAL_VALID_SEVERITIES="critical high medium low warn info"

# ─── validate_signal_description ────────────────────────────────────────────
# Returns 0 if description >= min_len, 1 otherwise
validate_signal_description() {
  local description="$1"
  local min_len="${2:-50}"
  local actual_len
  actual_len=${#description}
  if [ "$actual_len" -lt "$min_len" ]; then
    echo "FAIL description too short: ${actual_len} chars (min ${min_len}): '${description}'"
    return 1
  fi
  return 0
}

# ─── validate_signal_file_path ───────────────────────────────────────────────
# Checks evidence.file_path exists on disk. Skips if "N/A" or empty.
validate_signal_file_path() {
  local file_path="$1"
  if [ -z "$file_path" ] || [ "$file_path" = "N/A" ] || [ "$file_path" = "null" ]; then
    return 0
  fi
  if [ ! -f "$file_path" ]; then
    echo "FAIL file_path not found on disk: '${file_path}'"
    return 1
  fi
  return 0
}

# ─── validate_signal_confidence ──────────────────────────────────────────────
# Checks confidence is a number in [0.0, 1.0]. Skips if empty or null.
validate_signal_confidence() {
  local confidence="$1"
  if [ -z "$confidence" ] || [ "$confidence" = "null" ]; then
    return 0
  fi
  # Use awk for float comparison
  local ok
  ok=$(awk -v c="$confidence" 'BEGIN {
    if (c+0 == c && c >= 0.0 && c <= 1.0) print "ok"
    else print "fail"
  }')
  if [ "$ok" != "ok" ]; then
    echo "FAIL confidence out of range [0.0,1.0]: ${confidence}"
    return 1
  fi
  return 0
}

# ─── validate_signal_code_snippet ────────────────────────────────────────────
# Checks evidence object has code_snippet field (non-empty).
validate_signal_code_snippet() {
  local evidence_json="$1"
  local snippet
  snippet=$(echo "$evidence_json" | jq -r '.code_snippet // ""' 2>/dev/null || echo "")
  if [ -z "$snippet" ] || [ "$snippet" = "null" ]; then
    echo "FAIL evidence missing code_snippet (required per IMP-008)"
    return 1
  fi
  return 0
}

# ─── validate_signal_severity ────────────────────────────────────────────────
# Checks severity is in the allowed set.
validate_signal_severity() {
  local severity="$1"
  local severity_lower
  severity_lower=$(echo "$severity" | tr '[:upper:]' '[:lower:]')
  local found=false
  for s in $SIGNAL_VALID_SEVERITIES; do
    if [ "$severity_lower" = "$s" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = "false" ]; then
    echo "FAIL invalid severity: '${severity}' (allowed: ${SIGNAL_VALID_SEVERITIES})"
    return 1
  fi
  return 0
}

# ─── calc_sample_size ─────────────────────────────────────────────────────────
# Computes sample size = min(10, max(1, floor(total * 0.1)))
calc_sample_size() {
  local total="$1"
  awk -v t="$total" 'BEGIN {
    s = int(t * 0.1)
    if (s < 1) s = 1
    if (s > 10) s = 10
    print s
  }'
}

# ─── validate_signal_batch ────────────────────────────────────────────────────
# Validates a batch of signals from a JSON file.
# Usage: validate_signal_batch signals_file [--sample-n N]
# signals_file: JSON with .signals[] array
# --sample-n N: check N random signals (default: dynamic via calc_sample_size)
validate_signal_batch() {
  local signals_file="$1"
  shift
  local sample_n=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --sample-n) sample_n="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ ! -f "$signals_file" ]; then
    echo "FAIL signals file not found: $signals_file"
    return 1
  fi

  local total
  total=$(jq '.signals | length' "$signals_file" 2>/dev/null || echo "0")

  if [ "$total" -eq 0 ]; then
    echo "INFO no signals to validate in $signals_file"
    return 0
  fi

  if [ -z "$sample_n" ]; then
    sample_n=$(calc_sample_size "$total")
  fi

  local errors=0
  local checked=0

  # Sample indices: 0, floor(total/sample_n), ..., up to sample_n items
  local step=1
  if [ "$total" -gt "$sample_n" ]; then
    step=$(( total / sample_n ))
  fi

  local idx=0
  while [ "$idx" -lt "$total" ] && [ "$checked" -lt "$sample_n" ]; do
    local signal
    signal=$(jq ".signals[$idx]" "$signals_file" 2>/dev/null || echo "{}")

    local sig_id
    sig_id=$(echo "$signal" | jq -r '.signal_id // .id // "unknown"')
    local prefix="Signal[$idx] id=$sig_id"

    # Check description
    local desc
    desc=$(echo "$signal" | jq -r '.description // ""')
    if ! out=$(validate_signal_description "$desc" 2>&1); then
      echo "$prefix: $out"
      errors=$((errors+1))
    fi

    # Check severity
    local sev
    sev=$(echo "$signal" | jq -r '.suggested_severity // .severity // ""')
    if [ -n "$sev" ] && [ "$sev" != "null" ]; then
      if ! out=$(validate_signal_severity "$sev" 2>&1); then
        echo "$prefix: $out"
        errors=$((errors+1))
      fi
    fi

    # Check confidence
    local conf
    conf=$(echo "$signal" | jq -r '.confidence // "null"')
    if ! out=$(validate_signal_confidence "$conf" 2>&1); then
      echo "$prefix: $out"
      errors=$((errors+1))
    fi

    # Check evidence.file_path
    local fpath
    fpath=$(echo "$signal" | jq -r '.target.file_path // .evidence.file_path // "N/A"')
    if ! out=$(validate_signal_file_path "$fpath" 2>&1); then
      echo "$prefix: $out"
      errors=$((errors+1))
    fi

    # Check evidence.code_snippet
    local evidence_json
    evidence_json=$(echo "$signal" | jq '.evidence // {}')
    if ! out=$(validate_signal_code_snippet "$evidence_json" 2>&1); then
      echo "$prefix: $out"
      errors=$((errors+1))
    fi

    idx=$(( idx + step ))
    checked=$(( checked + 1 ))
  done

  echo "INFO validated $checked/$total signals (sample_n=$sample_n, errors=$errors)"
  [ "$errors" -eq 0 ] && return 0 || return 1
}

# ─── probe_validate_arg ───────────────────────────────────────────────────────
# Validates --probe argument against valid probe IDs in dimension.json
# Usage: probe_validate_arg "P-QD1-some-probe" dim_json_path
probe_validate_arg() {
  local probe_arg="$1"
  local dim_json="$2"

  if [ -z "$probe_arg" ] || [ "$probe_arg" = "null" ] || [ "$probe_arg" = "ALL" ]; then
    return 0
  fi

  if [ ! -f "$dim_json" ]; then
    echo "WARN dim.json not found: $dim_json — skipping probe validation"
    return 0
  fi

  local found=false
  while IFS= read -r p; do
    # Strip carriage return (CRLF safety for Windows)
    p="${p%$'\r'}"
    [ -z "$p" ] && continue
    if [ "$probe_arg" = "$p" ]; then
      found=true
      break
    fi
  done < <(jq -r '.probes[].id' "$dim_json" 2>/dev/null || true)

  if [ "$found" = "false" ] && ! jq -e '.probes | length > 0' "$dim_json" > /dev/null 2>&1; then
    echo "WARN no probes found in $dim_json — skipping probe validation"
    return 0
  fi

  if [ "$found" = "false" ]; then
    echo "FAIL unknown --probe argument: '${probe_arg}'"
    echo "     Check valid probe IDs in: $dim_json"
    return 1
  fi
  return 0
}

# ─── main: standalone invocation ─────────────────────────────────────────────
# Usage: wf-fix-probe-static-signal-validate.sh validate <signals.json> [--sample-n N]
#        wf-fix-probe-static-signal-validate.sh probe-check <probe-id> <dim.json>
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  CMD="${1:-validate}"
  shift 2>/dev/null || true

  case "$CMD" in
    validate)
      validate_signal_batch "$@"
      ;;
    probe-check)
      probe_validate_arg "$1" "${2:-}"
      ;;
    *)
      echo "Usage: $0 validate <signals.json> [--sample-n N]"
      echo "       $0 probe-check <probe-id> <dim.json>"
      exit 1
      ;;
  esac
fi
