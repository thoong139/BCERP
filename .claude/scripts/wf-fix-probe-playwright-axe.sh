#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-playwright-axe.sh — QD5 Accessibility Probe (axe-core)
#
# IMP-016: Structural a11y analysis via axe-core.
# Three execution paths (priority order):
#   A. --axe-report <file>  : parse pre-generated axe JSON (CI/test mode)
#   B. npx @axe-core/cli    : run against --url or --html when CLI available
#   C. graceful-degradation : emit probe_status=axe_unavailable, signal_count=0
#
# axe violation impact → signal severity mapping:
#   critical → critical
#   serious  → high
#   moderate → medium
#   minor    → low
#
# OUTPUT: lane-signals-v1 JSON to stdout.
# USAGE:
#   bash wf-fix-probe-playwright-axe.sh \
#     [--session-dir <path>] \
#     [--url <http://...>] \
#     [--html <path/to/file.html>] \
#     [--axe-report <path/to/axe-output.json>]
#
# EXIT CODES: 0 success, 1 error


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SH="$SCRIPT_DIR/wf-fix-common.sh"
[ -f "$COMMON_SH" ] || { echo "ERROR: wf-fix-common.sh not found: $COMMON_SH" >&2; exit 1; }
source "$COMMON_SH"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"

PROBE_ID="P-QD5-accessibility-axe"
DIMENSION="QD5"
SESSION_DIR=""
TARGET_URL=""
TARGET_HTML=""
AXE_REPORT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --url)         TARGET_URL="$2"; shift 2 ;;
    --html)        TARGET_HTML="$2"; shift 2 ;;
    --axe-report)  AXE_REPORT_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

_sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }
_fp() { printf '%s' "$1" | _sha256_fn | awk '{print "sha256:"$1}'; }

_impact_to_severity() {
  case "$1" in
    critical) echo "critical" ;;
    serious)  echo "high"     ;;
    moderate) echo "medium"   ;;
    minor)    echo "low"      ;;
    *)        echo "low"      ;;
  esac
}

SIGNALS=()
AXE_SOURCE=""
AXE_JSON=""

# ============================================================
# PATH A: Pre-generated axe report (CI / test mode)
# ============================================================
if [[ -n "$AXE_REPORT_FILE" ]] && [[ -f "$AXE_REPORT_FILE" ]]; then
  AXE_SOURCE="pre-generated"
  AXE_JSON=$(cat "$AXE_REPORT_FILE")

# ============================================================
# PATH B: npx @axe-core/cli (when available + target given)
# ============================================================
elif (command -v npx >/dev/null 2>&1) && [[ -n "$TARGET_URL" || -n "$TARGET_HTML" ]]; then
  TARGET="${TARGET_URL:-file://${TARGET_HTML}}"
  AXE_SOURCE="axe-cli"
  # --reporter json writes violations JSON to stdout
  AXE_JSON=$(npx --yes "@axe-core/cli" --reporter json "$TARGET" 2>/dev/null || echo '{"violations":[]}')

# ============================================================
# PATH C: Graceful degradation — neither report nor CLI
# ============================================================
else
  jq -nc \
    --arg schema "lane-signals-v1" \
    --arg probe  "$PROBE_ID" \
    --arg dim    "$DIMENSION" \
    --arg status "axe_unavailable" \
    '{
      "$schema":     $schema,
      probe_id:      $probe,
      dimension:     $dim,
      probe_status:  $status,
      signal_count:  0,
      signals:       [],
      note: "axe-core not available. Provide --axe-report <file> or install @axe-core/cli via npm."
    }'
  exit 0
fi

# ============================================================
# Parse axe violations → signals
# ============================================================
if [[ -z "$AXE_JSON" ]] || ! echo "$AXE_JSON" | jq -e '.violations' >/dev/null 2>&1; then
  AXE_JSON='{"violations":[]}'
fi

while IFS= read -r violation; do
  rule_id=$(echo "$violation" | jq -r '.id // "unknown"')
  impact=$(echo "$violation" | jq -r '.impact // "minor"')
  desc=$(echo "$violation" | jq -r '.description // ""')
  tags=$(echo "$violation" | jq -c '[.tags // []][] ')
  sev=$(_impact_to_severity "$impact")

  while IFS= read -r node; do
    html_snippet=$(echo "$node" | jq -r '.html // ""' | head -c 200)
    target=$(echo "$node" | jq -r '.target[0] // "unknown"')
    summary=$(echo "$node" | jq -r '.failureSummary // ""' | head -c 300)

    fp=$(_fp "QD5|${AXE_REPORT_FILE:-${TARGET_URL:-${TARGET_HTML}}}|${rule_id}|${target}|${PROBE_ID}")

    SIGNALS+=("$(jq -nc \
      --arg rule    "$rule_id" \
      --arg desc    "$desc" \
      --arg sev     "$sev" \
      --arg impact  "$impact" \
      --arg target  "$target" \
      --arg html    "$html_snippet" \
      --arg summary "$summary" \
      --arg fp      "$fp" \
      --arg dim     "$DIMENSION" \
      --arg probe   "$PROBE_ID" \
      --arg src     "$AXE_SOURCE" \
      '{
        title:       ("axe: " + $rule + " on " + $target),
        description: ($desc + " — " + $summary),
        severity:    $sev,
        axe_impact:  $impact,
        location:    {file: $target, line: null},
        evidence:    [{type: "html", path: $target, description: $html}],
        fingerprint: $fp,
        dimension:   $dim,
        probe_id:    $probe,
        issue_class: $rule,
        axe_source:  $src,
        tags:        ["a11y","wcag","axe"]
      }')")
  done < <(echo "$violation" | jq -c '.nodes[]?' 2>/dev/null || true)
done < <(echo "$AXE_JSON" | jq -c '.violations[]?' 2>/dev/null || true)

# ============================================================
# Emit lane-signals-v1 envelope
# ============================================================
SIGNAL_COUNT="${#SIGNALS[@]}"
SIGNALS_JSON="[]"
if [[ "$SIGNAL_COUNT" -gt 0 ]]; then
  SIGNALS_JSON=$(printf '%s\n' "${SIGNALS[@]}" | jq -s '.')
fi

jq -nc \
  --arg schema "lane-signals-v1" \
  --arg probe  "$PROBE_ID" \
  --arg dim    "$DIMENSION" \
  --arg src    "$AXE_SOURCE" \
  --argjson signals "$SIGNALS_JSON" \
  '{
    "$schema":    $schema,
    probe_id:     $probe,
    dimension:    $dim,
    axe_source:   $src,
    signal_count: ($signals | length),
    signals:      $signals
  }'
