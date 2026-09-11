#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-go.sh — Static probe: Go-specific checks
#
# Phase B v8 — Stack-Aware Probe Registry. Phat hien:
#  - QD1: error wrapping thieu fmt.Errorf("...: %w", err) — mat error chain
#  - QD3: SQL injection via raw string concat (db.Query(fmt.Sprintf(...)))
#
# Probes:
#   P-QD1-go-error-wrap-check  → Go error wrapping pattern
#   P-QD3-go-sql-injection     → Go SQL injection via concat
#
# OUTPUT: JSON stdout theo schema lane-signals-v1
# Cache policy: allowed (static analysis)


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE=""
PROBE_ID=""
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="."

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --probe) PROBE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

[ -z "$LANE" ] && case "$PROBE_ID" in
  P-QD1-*) LANE="wf-fix-functional" ;;
  P-QD3-*) LANE="wf-fix-security" ;;
  *)       LANE="wf-fix-functional" ;;
esac

case "$PROBE_ID" in
  P-QD1-*) DIMENSION="QD1" ;;
  P-QD3-*) DIMENSION="QD3" ;;
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

EXCLUDE='(vendor/|\.git/|/test/|_test\.go$|fixtures/|generated/|\.pb\.go$)'

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
# P-QD1-go-error-wrap-check: error wrapping
# ────────────────────────────────────────────────────────────
if [ "$PROBE_ID" = "P-QD1-go-error-wrap-check" ]; then
  # Detect: return ..., err — without wrapping context
  # Pattern: `return nil, err` or `return err` (if err is local var)
  while IFS=: read -r file line _; do
    [ -z "$file" ] && continue
    file_rel="${file#$SOURCE_DIR}"
    EMIT "Go error tra ve khong duoc wrap" \
      "Tai $file:$line tra ve raw error khong co context — kho debug khi error chain qua nhieu layers." \
      "medium" "$file_rel" "$line" \
      "Dung fmt.Errorf(\"context: %w\", err) de wrap voi context. Caller dung errors.Is/errors.As de unwrap." \
      >> "$SIGNALS_FILE"
  done < <(
    # Match `return ..., err` or `return err` standalone
    grep -rEn '^\s*return\s+(.*,\s+)?err\s*$' "$SOURCE_DIR" \
      --include='*.go' 2>/dev/null \
      | grep -vE "$EXCLUDE" \
      | head -100
  )
fi

# ────────────────────────────────────────────────────────────
# P-QD3-go-sql-injection: SQL injection via fmt.Sprintf
# ────────────────────────────────────────────────────────────
if [ "$PROBE_ID" = "P-QD3-go-sql-injection" ]; then
  # Pattern: db.Query(fmt.Sprintf(...)), db.Exec(fmt.Sprintf(...))
  while IFS=: read -r file line _; do
    [ -z "$file" ] && continue
    file_rel="${file#$SOURCE_DIR}"
    EMIT "Go SQL Injection qua fmt.Sprintf" \
      "Tai $file:$line dung fmt.Sprintf de build SQL query — neu input chua escape, attacker co the inject SQL." \
      "critical" "$file_rel" "$line" \
      "Dung parameterized query: db.Query(\"SELECT ... WHERE x = \$1\", value). KHONG bao gio dung Sprintf cho SQL." \
      >> "$SIGNALS_FILE"
  done < <(
    grep -rEn '\.(Query|Exec|QueryRow|QueryContext|ExecContext)\(\s*fmt\.Sprintf\(' "$SOURCE_DIR" \
      --include='*.go' 2>/dev/null \
      | grep -vE "$EXCLUDE" \
      | head -50
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
