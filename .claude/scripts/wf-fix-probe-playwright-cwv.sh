#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-playwright-cwv.sh — QD4 Core Web Vitals Probe (IMP-018)
#
# Measures CWV metrics via Lighthouse CI or pre-generated report.
# Three execution paths (priority order):
#   A. --cwv-report <file>   : Parse pre-generated Lighthouse/CWV JSON (CI/test mode)
#   B. @lhci/cli available   : Run Lighthouse against --url (requires Chrome)
#   C. Graceful degradation  : probe_status=cwv_unavailable
#
# CWV thresholds (Google):
#   LCP: good < 2.5s, needs-improvement 2.5-4.0s, poor > 4.0s
#   CLS: good < 0.1,  needs-improvement 0.1-0.25,  poor > 0.25
#   INP: good < 200ms, needs-improvement 200-500ms, poor > 500ms
#   FCP: good < 1.8s, needs-improvement 1.8-3.0s,  poor > 3.0s
#   TTFB: good < 800ms, poor > 1800ms
#
# Baseline mode: --baseline-dir <path> → saves first run; subsequent runs compare delta.
#
# OUTPUT: lane-signals-v1 JSON to stdout.
# USAGE:
#   bash wf-fix-probe-playwright-cwv.sh \
#     [--cwv-report <path/to/lhci-report.json>] \
#     [--url <http://localhost:3000>] \
#     [--baseline-dir <path>]
#
# EXIT CODES: 0 success, 1 error


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SH="$SCRIPT_DIR/wf-fix-common.sh"
[ -f "$COMMON_SH" ] || { echo "ERROR: wf-fix-common.sh not found: $COMMON_SH" >&2; exit 1; }
source "$COMMON_SH"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"

PROBE_ID="P-QD4-core-web-vitals"
DIMENSION="QD4"
CWV_REPORT_FILE=""
TARGET_URL=""
BASELINE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwv-report)   CWV_REPORT_FILE="$2"; shift 2 ;;
    --url)          TARGET_URL="$2"; shift 2 ;;
    --baseline-dir) BASELINE_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

_sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }
_fp() { printf '%s' "$1" | _sha256_fn | awk '{print "sha256:"$1}'; }

SIGNALS=()
CWV_SOURCE=""
CWV_JSON=""

# ============================================================
# PATH A: Pre-generated CWV report (CI / test mode)
# ============================================================
if [[ -n "$CWV_REPORT_FILE" ]] && [[ -f "$CWV_REPORT_FILE" ]]; then
  CWV_SOURCE="pre-generated"
  CWV_JSON=$(cat "$CWV_REPORT_FILE")

# ============================================================
# PATH B: @lhci/cli (when available + URL given)
# ============================================================
elif command -v npx >/dev/null 2>&1 && [[ -n "$TARGET_URL" ]]; then
  if npx --yes lhci --version >/dev/null 2>&1; then
    CWV_SOURCE="lhci"
    TMP_DIR=$(mktemp -d 2>/dev/null || echo "/tmp/lhci-$$")
    mkdir -p "$TMP_DIR"
    # Collect Lighthouse report in JSON format
    npx lhci collect \
      --url="$TARGET_URL" \
      --numberOfRuns=1 \
      --settings.output=json \
      --settings.outputPath="$TMP_DIR/lhci-result.json" \
      >/dev/null 2>&1 || true
    if [[ -f "$TMP_DIR/lhci-result.json" ]]; then
      CWV_JSON=$(cat "$TMP_DIR/lhci-result.json")
    else
      CWV_JSON='{}'
    fi
    rm -rf "$TMP_DIR"
  fi
fi

# ============================================================
# PATH C: Graceful degradation
# ============================================================
if [[ -z "$CWV_SOURCE" ]]; then
  jq -nc \
    --arg schema "lane-signals-v1" \
    --arg probe  "$PROBE_ID" \
    --arg dim    "$DIMENSION" \
    --arg status "cwv_unavailable" \
    '{
      "$schema":    $schema,
      probe_id:     $probe,
      dimension:    $dim,
      probe_status: $status,
      signal_count: 0,
      signals:      [],
      note: "Lighthouse CI not available. Provide --cwv-report <file> or install @lhci/cli."
    }'
  exit 0
fi

# ============================================================
# Extract metrics from CWV JSON
# ============================================================
_extract_metric() {
  local field="$1" default="${2:-0}"
  # Support both lhci format (.audits["metric"].numericValue) and flat format (.lcp etc.)
  local val
  val=$(echo "$CWV_JSON" | jq -r \
    --arg field "$field" \
    '(.audits[$field].numericValue // .[$field] // .metrics[$field] // '"$default"') // '"$default" 2>/dev/null || echo "$default")
  echo "$val"
}

LCP=$(_extract_metric "largest-contentful-paint" 0)
CLS=$(_extract_metric "cumulative-layout-shift" 0)
INP=$(_extract_metric "interaction-to-next-paint" 0)
FCP=$(_extract_metric "first-contentful-paint" 0)
TTFB=$(_extract_metric "server-response-time" 0)

# Fallback: try flat field names (pre-generated test format)
[[ "$LCP" == "0" ]] && LCP=$(echo "$CWV_JSON" | jq -r '.lcp // 0' 2>/dev/null || echo 0)
[[ "$CLS" == "0" ]] && CLS=$(echo "$CWV_JSON" | jq -r '.cls // 0' 2>/dev/null || echo 0)
[[ "$INP" == "0" ]] && INP=$(echo "$CWV_JSON" | jq -r '.inp // 0' 2>/dev/null || echo 0)
[[ "$FCP" == "0" ]] && FCP=$(echo "$CWV_JSON" | jq -r '.fcp // 0' 2>/dev/null || echo 0)
[[ "$TTFB" == "0" ]] && TTFB=$(echo "$CWV_JSON" | jq -r '.ttfb // 0' 2>/dev/null || echo 0)

URL_OR_FILE="${TARGET_URL:-${CWV_REPORT_FILE:-unknown}}"

_cwv_severity_lcp() {
  local ms="$1"
  if awk "BEGIN{exit !($ms > 4000)}"; then echo "critical"
  elif awk "BEGIN{exit !($ms > 2500)}"; then echo "high"
  elif awk "BEGIN{exit !($ms > 1800)}"; then echo "medium"
  else echo "info"; fi
}
_cwv_severity_cls() {
  local v="$1"
  if awk "BEGIN{exit !($v > 0.25)}"; then echo "critical"
  elif awk "BEGIN{exit !($v > 0.1)}"; then echo "high"
  elif awk "BEGIN{exit !($v > 0.05)}"; then echo "medium"
  else echo "info"; fi
}
_cwv_severity_inp() {
  local ms="$1"
  if awk "BEGIN{exit !($ms > 500)}"; then echo "critical"
  elif awk "BEGIN{exit !($ms > 200)}"; then echo "high"
  elif awk "BEGIN{exit !($ms > 100)}"; then echo "medium"
  else echo "info"; fi
}
_cwv_severity_fcp() {
  local ms="$1"
  if awk "BEGIN{exit !($ms > 3000)}"; then echo "high"
  elif awk "BEGIN{exit !($ms > 1800)}"; then echo "medium"
  else echo "info"; fi
}

# ============================================================
# Baseline mode: load previous run for delta comparison
# ============================================================
BASELINE_LCP=0 BASELINE_CLS=0 BASELINE_INP=0 BASELINE_FCP=0
BASELINE_FILE=""
if [[ -n "$BASELINE_DIR" ]]; then
  BASELINE_FILE="${BASELINE_DIR}/cwv-baseline.json"
  if [[ -f "$BASELINE_FILE" ]]; then
    BASELINE_LCP=$(jq -r '.lcp // 0' "$BASELINE_FILE" 2>/dev/null || echo 0)
    BASELINE_CLS=$(jq -r '.cls // 0' "$BASELINE_FILE" 2>/dev/null || echo 0)
    BASELINE_INP=$(jq -r '.inp // 0' "$BASELINE_FILE" 2>/dev/null || echo 0)
    BASELINE_FCP=$(jq -r '.fcp // 0' "$BASELINE_FILE" 2>/dev/null || echo 0)
  fi
  # Save current run as new baseline
  mkdir -p "$BASELINE_DIR"
  jq -nc \
    --argjson lcp "$LCP" --argjson cls "$CLS" \
    --argjson inp "$INP" --argjson fcp "$FCP" --argjson ttfb "$TTFB" \
    --arg src "$CWV_SOURCE" --arg url "$URL_OR_FILE" \
    '{ lcp: $lcp, cls: $cls, inp: $inp, fcp: $fcp, ttfb: $ttfb,
       source: $src, url: $url,
       saved_at: (now | todate) }' > "$BASELINE_FILE" 2>/dev/null || true
fi

# ============================================================
# Build signals
# ============================================================
_add_metric_signal() {
  local metric_name="$1" metric_val="$2" sev="$3" unit="$4" desc="$5"
  [[ "$sev" == "info" ]] && return  # skip info-level metrics

  local fp
  fp=$(_fp "QD4|${PROBE_ID}|${metric_name}|${URL_OR_FILE}")

  SIGNALS+=("$(jq -nc \
    --arg name    "$metric_name" \
    --arg val     "$metric_val" \
    --arg sev     "$sev" \
    --arg unit    "$unit" \
    --arg desc    "$desc" \
    --arg url     "$URL_OR_FILE" \
    --arg fp      "$fp" \
    --arg dim     "$DIMENSION" \
    --arg probe   "$PROBE_ID" \
    --arg src     "$CWV_SOURCE" \
    '{
      title:       ($name + ": " + $val + $unit + " — " + $sev),
      description: $desc,
      severity:    $sev,
      location:    {file: $url, line: null},
      evidence:    [{type: "metric", path: $url,
                     description: ($name + "=" + $val + $unit), cwv_source: $src}],
      fingerprint: $fp,
      dimension:   $dim,
      probe_id:    $probe,
      issue_class: ("cwv_" + ($name | ascii_downcase | gsub("-";"_"))),
      cwv_source:  $src,
      tags:        ["cwv","performance","web-vitals"]
    }')")
}

if awk "BEGIN{exit !($LCP > 0)}"; then
  lcp_s=$(awk "BEGIN{printf \"%.2f\", $LCP/1000}")
  sev=$(_cwv_severity_lcp "$LCP")
  _add_metric_signal "LCP" "$lcp_s" "$sev" "s" \
    "Largest Contentful Paint = ${lcp_s}s. Google good threshold: <2.5s, poor: >4.0s."
fi

if awk "BEGIN{exit !($CLS > 0)}"; then
  cls_str=$(awk "BEGIN{printf \"%.3f\", $CLS}")
  sev=$(_cwv_severity_cls "$CLS")
  _add_metric_signal "CLS" "$cls_str" "$sev" "" \
    "Cumulative Layout Shift = ${cls_str}. Google good threshold: <0.1, poor: >0.25."
fi

if awk "BEGIN{exit !($INP > 0)}"; then
  sev=$(_cwv_severity_inp "$INP")
  _add_metric_signal "INP" "$INP" "$sev" "ms" \
    "Interaction to Next Paint = ${INP}ms. Google good threshold: <200ms, poor: >500ms."
fi

if awk "BEGIN{exit !($FCP > 0)}"; then
  fcp_s=$(awk "BEGIN{printf \"%.2f\", $FCP/1000}")
  sev=$(_cwv_severity_fcp "$FCP")
  _add_metric_signal "FCP" "$fcp_s" "$sev" "s" \
    "First Contentful Paint = ${fcp_s}s. Google good threshold: <1.8s, poor: >3.0s."
fi

# ============================================================
# Emit lane-signals-v1 envelope
# ============================================================
SIGNAL_COUNT="${#SIGNALS[@]}"
SIGNALS_JSON="[]"
if [[ "$SIGNAL_COUNT" -gt 0 ]]; then
  SIGNALS_JSON=$(printf '%s\n' "${SIGNALS[@]}" | jq -s '.')
fi

BASELINE_LOADED="false"
[[ -n "$BASELINE_FILE" && -f "$BASELINE_FILE" && "$BASELINE_LCP" != "0" ]] && BASELINE_LOADED="true"

jq -nc \
  --arg schema  "lane-signals-v1" \
  --arg probe   "$PROBE_ID" \
  --arg dim     "$DIMENSION" \
  --arg src     "$CWV_SOURCE" \
  --arg url     "$URL_OR_FILE" \
  --argjson lcp "$LCP" --argjson cls "$CLS" \
  --argjson inp "$INP" --argjson fcp "$FCP" \
  --arg baseline "$BASELINE_LOADED" \
  --argjson signals "$SIGNALS_JSON" \
  '{
    "$schema":      $schema,
    probe_id:       $probe,
    dimension:      $dim,
    cwv_source:     $src,
    url:            $url,
    metrics:        {lcp_ms: $lcp, cls: $cls, inp_ms: $inp, fcp_ms: $fcp},
    baseline_loaded: ($baseline == "true"),
    signal_count:   ($signals | length),
    signals:        $signals
  }'
