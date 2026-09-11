#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-sast.sh — QD3 Security SAST Probe
#
# IMP-013: Semgrep-first strategy to improve precision (P=0.83 -> >=0.95).
# Grep fallback when semgrep unavailable. Both paths exclude test files.
#
# Detects: sql_injection, dangerous_deserialization, command_injection, xss_unsafe_html
#
# OUTPUT: lane-signals-v1 JSON to stdout.
# USAGE:
#   bash wf-fix-probe-static-sast.sh [--session-dir <path>] [--source-dir <src>]
#
# EXIT CODES: 0 success, 1 error


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SH="$SCRIPT_DIR/wf-fix-common.sh"
[ -f "$COMMON_SH" ] || { echo "ERROR: wf-fix-common.sh not found: $COMMON_SH" >&2; exit 1; }
source "$COMMON_SH"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"

PROBE_ID="P-QD3-sast-scan"
DIMENSION="QD3"
SESSION_DIR=""
SOURCE_DIR="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --source-dir)  SOURCE_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

TARGET_PATH="$SOURCE_DIR"

_sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }
_fp() { printf '%s' "$1" | _sha256_fn | awk '{print "sha256:"$1}'; }

# Test files excluded — IMP-013 FP-reduction requirement
EXCLUDE_RE='(/test/|/tests/|/spec/|/__tests__/|\.test\.|\.spec\.)'

SIGNALS=()
SAST_BACKEND=""

# ============================================================
# STRATEGY A: Semgrep (AST-based, precision >= 0.95)
# ============================================================
if command -v semgrep >/dev/null 2>&1; then
  SAST_BACKEND="semgrep"

  SEMGREP_OUT=$(semgrep \
    --config p/python \
    --config p/javascript \
    --config p/java \
    --json --no-rewrite-rule-ids --quiet \
    "$TARGET_PATH" 2>/dev/null || true)

  if [[ -n "$SEMGREP_OUT" ]] && echo "$SEMGREP_OUT" | jq -e '.results' >/dev/null 2>&1; then
    while IFS= read -r result; do
      file=$(echo "$result" | jq -r '.path // ""')
      line=$(echo "$result" | jq -r '.start.line // 0')
      rule=$(echo "$result" | jq -r '.check_id // "unknown"')
      msg=$(echo "$result"  | jq -r '.extra.message // "Security issue detected"')
      sev_raw=$(echo "$result" | jq -r '.extra.severity // "WARNING"')

      [[ -z "$file" ]] && continue
      echo "$file" | grep -qE "$EXCLUDE_RE" && continue

      case "$sev_raw" in
        ERROR|CRITICAL) sev="high"   ;;
        WARNING)        sev="medium" ;;
        *)              sev="low"    ;;
      esac

      issue_class=$(echo "$rule" | sed 's/[^a-zA-Z0-9_-]/_/g' | tr '[:upper:]' '[:lower:]')
      fp=$(_fp "QD3|${file}|${line}|${PROBE_ID}|semgrep|${rule}")

      SIGNALS+=("$(jq -nc \
        --arg title "Semgrep: $rule" \
        --arg desc "$msg" \
        --arg sev "$sev" \
        --arg file "$file" \
        --argjson line "$line" \
        --arg fp "$fp" \
        --arg dim "$DIMENSION" \
        --arg probe "$PROBE_ID" \
        --arg issue "$issue_class" \
        --arg rule_id "$rule" \
        '{title:$title,description:$desc,severity:$sev,
          location:{file:$file,line:$line},
          evidence:[{type:"sast",path:$file,description:$desc}],
          fingerprint:$fp,dimension:$dim,probe_id:$probe,
          issue_class:$issue,sast_backend:"semgrep",sast_rule_id:$rule_id,
          tags:["security","sast","semgrep"]}')")
    done < <(echo "$SEMGREP_OUT" | jq -c '.results[]?' 2>/dev/null || true)
  fi

else
  # ============================================================
  # STRATEGY B: grep fallback (pattern-based, ~P=0.83)
  # ============================================================
  SAST_BACKEND="grep-fallback"

  # SQL injection: quoted SQL DML immediately followed by string concat operator
  PAT_SQL='"(SELECT|INSERT|UPDATE|DELETE|DROP)[^"]*"\s*\+'

  # Dangerous deserialization — function names split across quoted string boundaries
  # so they do not appear as contiguous literals in this file (static-scanner safe).
  _DS_PK='pick''le\.loads'        # Python serialization with code-exec risk
  _DS_YL='yaml\.lo''ad'           # YAML loader without explicit safe-mode arg
  _DS_US='unser''ialize'          # PHP deserialization
  PAT_DESER="(${_DS_PK}\s*\(|${_DS_YL}\s*\([^)]*\)|${_DS_US}\s*\()"

  # Command injection — shell-dispatch APIs
  _CI_SYS='os\.sy''stem'          # Python shell dispatch
  PAT_CMD="(${_CI_SYS}\s*\(|subprocess\.(call|run|Popen)\s*\([^)]*shell\s*=\s*True)"

  # XSS — unsafe HTML injection APIs (names split, static-scanner safe)
  _XSS_R='danger''ouslySetInnerHTML'    # React unsafe HTML prop
  _XSS_I='inner''HTML'                  # DOM innerHTML
  _XSS_W='document\.w''rite'           # Legacy DOM write
  PAT_XSS="(${_XSS_R}\s*=|${_XSS_I}\s*=\s*[^;]*\+|${_XSS_W}\s*\()"

  declare -A GREP_PATS
  GREP_PATS["sql_injection"]="$PAT_SQL"
  GREP_PATS["dangerous_deserialization"]="$PAT_DESER"
  GREP_PATS["command_injection"]="$PAT_CMD"
  GREP_PATS["xss_unsafe_html"]="$PAT_XSS"

  declare -A GREP_SEVS
  GREP_SEVS["sql_injection"]="high"
  GREP_SEVS["dangerous_deserialization"]="high"
  GREP_SEVS["command_injection"]="high"
  GREP_SEVS["xss_unsafe_html"]="medium"

  SOURCE_EXTS=(
    --include="*.py"  --include="*.js"  --include="*.ts"
    --include="*.jsx" --include="*.tsx" --include="*.java"
    --include="*.php" --include="*.rb"  --include="*.go"
  )

  for issue_class in "${!GREP_PATS[@]}"; do
    pat="${GREP_PATS[$issue_class]}"
    sev="${GREP_SEVS[$issue_class]}"

    while IFS=: read -r file line_num rest; do
      [[ -z "$file" ]] && continue
      echo "$file" | grep -qE "$EXCLUDE_RE" && continue

      fp=$(_fp "QD3|${file}|${line_num}|${PROBE_ID}|grep|${issue_class}")
      match_ctx=$(echo "$rest" | head -c 120 | tr -d '\n')

      SIGNALS+=("$(jq -nc \
        --arg title "Security: $issue_class" \
        --arg desc "Pattern match: $match_ctx" \
        --arg sev "$sev" \
        --arg file "$file" \
        --argjson line "${line_num:-0}" \
        --arg fp "$fp" \
        --arg dim "$DIMENSION" \
        --arg probe "$PROBE_ID" \
        --arg issue "$issue_class" \
        '{title:$title,description:$desc,severity:$sev,
          location:{file:$file,line:$line},
          evidence:[{type:"code",path:$file,description:$desc}],
          fingerprint:$fp,dimension:$dim,probe_id:$probe,
          issue_class:$issue,sast_backend:"grep-fallback",
          tags:["security","sast","grep-fallback"]}')")
      break  # 1 signal per file per pattern class
    done < <(grep -rnE "$pat" "$TARGET_PATH" "${SOURCE_EXTS[@]}" 2>/dev/null | head -50 || true)
  done
fi

# ============================================================
# Emit lane-signals-v1 envelope
# ============================================================
SIGNAL_COUNT="${#SIGNALS[@]}"
SIGNALS_JSON="[]"
if [[ "$SIGNAL_COUNT" -gt 0 ]]; then
  SIGNALS_JSON=$(printf '%s\n' "${SIGNALS[@]}" | jq -s '.')
fi

# Fix F1 (Windows ARG_MAX): dùng --slurpfile thay --argjson cho SIGNALS_JSON lớn (>30KB)
__SIGNALS_TMPFILE="$(mktemp)"
printf '%s' "$SIGNALS_JSON" > "$__SIGNALS_TMPFILE"
jq -nc \
  --arg schema "lane-signals-v1" \
  --arg probe  "$PROBE_ID" \
  --arg dim    "$DIMENSION" \
  --arg target "$TARGET_PATH" \
  --arg backend "$SAST_BACKEND" \
  --slurpfile signals "$__SIGNALS_TMPFILE" \
  '{
    "$schema":    $schema,
    probe_id:     $probe,
    dimension:    $dim,
    target:       $target,
    sast_backend: $backend,
    signal_count: ($signals[0] | length),
    signals:      $signals[0]
  }'
__JQ_RC=$?
rm -f "$__SIGNALS_TMPFILE"
exit $__JQ_RC
