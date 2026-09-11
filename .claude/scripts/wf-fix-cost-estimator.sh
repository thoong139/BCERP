#!/usr/bin/env bash
# wf-fix-cost-estimator.sh — Estimate LLM cost trước khi spawn probe lanes (W5.4)
#
# Usage:
#   bash .claude/scripts/wf-fix-cost-estimator.sh \
#     [--dims=QD1,QD2,...|all] \
#     [--profile=quick|standard|deep|exhaustive] \
#     [--llm-scan] \
#     [--threshold=5.0] \
#     [--output=path.json]
#
# Output (stdout + optional --output file):
#   JSON { estimate_usd, breakdown[], over_threshold, threshold_usd }
#
# Exit codes:
#   0 = success (estimate computed, even if over_threshold)
#   1 = argument error
#   2 = dependency missing (jq)
#
# Cost model (W5.4 spec):
#   Static probe:  ~5K tokens  × $3/M  = $0.015 → stored as 2 cents (conservative)
#   Runtime probe: ~50K tokens × $3/M  = $0.150 → 15 cents
#   Agent probe:   ~100K tok   × $15/M = $1.500 → 150 cents
#   LLM scan inv:  avg ($0.50+$1.50)/2 = $1.00  → 100 cents per applicable dim
#
# Reuses: wf-fix-common.sh (atomic_write_json, json_escape)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

# ============================================================
# DEFAULTS
# ============================================================
DIMS_ARG="all"
PROFILE="standard"
LLM_SCAN=false
THRESHOLD_CENTS=500   # $5.00 in integer cents
OUTPUT_PATH=""

# ============================================================
# ARG PARSE
# ============================================================
for arg in "$@"; do
  case "$arg" in
    --dims=*)
      DIMS_ARG="${arg#--dims=}"
      ;;
    --profile=*)
      PROFILE="${arg#--profile=}"
      ;;
    --llm-scan)
      LLM_SCAN=true
      ;;
    --threshold=*)
      thresh_raw="${arg#--threshold=}"
      # Convert float to cents via awk (no bc dependency)
      THRESHOLD_CENTS=$(awk "BEGIN{printf \"%d\", ${thresh_raw} * 100}")
      ;;
    --output=*)
      OUTPUT_PATH="${arg#--output=}"
      ;;
    --help|-h)
      echo "Usage: $0 [--dims=QD1,...|all] [--profile=quick|standard|deep|exhaustive] [--llm-scan] [--threshold=FLOAT] [--output=path.json]"
      echo ""
      echo "Ước tính chi phí LLM trước khi spawn probe lanes."
      echo "Output: JSON {estimate_usd, breakdown[], over_threshold, threshold_usd}"
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# ============================================================
# VALIDATE PROFILE
# ============================================================
case "$PROFILE" in
  quick|standard|deep|exhaustive)
    ;;
  *)
    echo "ERROR: --profile phải là một trong: quick standard deep exhaustive (nhận: $PROFILE)" >&2
    exit 1
    ;;
esac

# ============================================================
# DEPENDENCY CHECK
# ============================================================
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq là bắt buộc nhưng không tìm thấy trong PATH" >&2
  exit 2
fi

# ============================================================
# PROBE COST MODEL (cents — dùng integer để tránh float bash)
# ============================================================
readonly COST_STATIC_C=2    # $0.020 (slightly above $0.015 spec — conservative)
readonly COST_RUNTIME_C=15  # $0.150
readonly COST_AGENT_C=150   # $1.500
readonly COST_LLM_SCAN_C=100 # $1.000 (avg of $0.50-$1.50)

# ============================================================
# PROBE ROUTING TABLE
# probe_counts DIM PROFILE → echo "STATIC RUNTIME AGENT"
# Source: probe routing tables trong SKILL.md của từng QD lane (QD1-QD10).
# Authored 2026-05-10 theo kết quả W1.3-W1.9, W1.5a-d, W2.1-W2.6, W3.1-W3.7,
# W4.1-W4.7, W5.1-W5.3.
# ============================================================
probe_counts() {
  local dim="$1"
  local prof="$2"
  # Output format: "STATIC RUNTIME AGENT"
  case "${dim}:${prof}" in
    # QD1 Functional Correctness (7 probes total)
    QD1:quick)       echo "1 1 0" ;;   # req-registry-xref + infra-preflight
    QD1:standard)    echo "2 2 0" ;;   # + route-config-parse + api-smoke
    QD1:deep)        echo "3 3 1" ;;   # + orphan-ui-detect + deep-ui-traversal + agent-feature-verify
    QD1:exhaustive)  echo "3 3 1" ;;

    # QD2 Business Correctness (6 probes; skip quick)
    QD2:quick)       echo "0 0 0" ;;   # skip — PRE-GATE early exit
    QD2:standard)    echo "2 0 1" ;;   # calculation-check + contract-check + domain-expert
    QD2:deep)        echo "2 1 2" ;;   # + business-rule-runtime (fixture) + boundary-mode (2nd agent)
    QD2:exhaustive)  echo "3 1 2" ;;   # + business-rule-coverage (annotations)

    # QD3 Security & Privacy (7 probes)
    QD3:quick)       echo "1 0 0" ;;   # sast-lite
    QD3:standard)    echo "3 2 0" ;;   # + secrets + privacy-static + auth-fuzz + rate-limit
    QD3:deep)        echo "4 3 1" ;;   # + injection-check + pentest-agent
    QD3:exhaustive)  echo "4 3 1" ;;

    # QD4 Performance & Efficiency (6 probes)
    QD4:quick)       echo "1 0 0" ;;   # bundle-size-static
    QD4:standard)    echo "1 3 0" ;;   # + api-latency + cwv + memory-profile
    QD4:deep)        echo "1 4 0" ;;   # + db-query-perf
    QD4:exhaustive)  echo "1 4 0" ;;

    # QD5 UX & Accessibility (7 probes)
    QD5:quick)       echo "2 1 0" ;;   # contrast-static + a11y-static + ui-traversal-light
    QD5:standard)    echo "3 2 1" ;;   # + keyboard-nav + screen-reader-agent
    QD5:deep)        echo "3 3 1" ;;   # + deep-a11y-traversal
    QD5:exhaustive)  echo "3 3 1" ;;

    # QD6 Data Integrity & Resilience (6 probes)
    QD6:quick)       echo "2 0 0" ;;   # schema-drift + migration-safety
    QD6:standard)    echo "4 1 0" ;;   # + constraint-violation + nullability + orphan-ref
    QD6:deep)        echo "5 1 0" ;;   # + backup-restore-static
    QD6:exhaustive)  echo "5 1 0" ;;

    # QD7 Compatibility (5 probes)
    QD7:quick)       echo "2 0 0" ;;   # deprecated-api + browser-compat-static
    QD7:standard)    echo "3 2 0" ;;   # + i18n-static + responsive-runtime + api-version-check
    QD7:deep)        echo "3 2 0" ;;
    QD7:exhaustive)  echo "3 2 0" ;;

    # QD8 Observability & Reliability (7 probes; mostly static)
    QD8:quick)       echo "2 0 0" ;;   # retry-check + timeout-check
    QD8:standard)    echo "4 1 0" ;;   # + log-coverage + metrics + health-check
    QD8:deep)        echo "6 1 0" ;;   # + trace-propagation + alert-rule
    QD8:exhaustive)  echo "7 1 0" ;;   # + circuit-breaker-exhaustive

    # QD9 Runtime Health (7 probes; skip quick — requires browser)
    QD9:quick)       echo "0 0 0" ;;   # skip — no browser execution
    QD9:standard)    echo "0 3 0" ;;   # dev-server-bootstrap + console-network-monitor + auth-aware-smoke
    QD9:deep)        echo "0 6 0" ;;   # + feature-checklist-smoke + interactive-smoke + spa-route-coverage
    QD9:exhaustive)  echo "1 6 0" ;;   # + form-validation-smoke (static analysis pass)

    # QD10 Cross-Module Integration (9 probes; skip quick)
    QD10:quick)      echo "0 0 0" ;;   # skip — only standard+
    QD10:standard)   echo "3 0 0" ;;   # cross-module-ref-static + api-contract-drift + event-handler-coverage
    QD10:deep)       echo "3 2 0" ;;   # + orphan-reference-runtime + multi-platform-entity-sync
    QD10:exhaustive) echo "5 2 1" ;;   # + state-machine-correctness + business-flow-runtime + domain-expert-boundary

    # Fallback cho dims không xác định
    *)
      echo "0 0 0"
      ;;
  esac
}

# LLM scan áp dụng cho 3 content-heavy dims (QD1=features, QD2=business, QD3=security)
is_llm_scan_dim() {
  case "$1" in
    QD1|QD2|QD3) return 0 ;;
    *)           return 1 ;;
  esac
}

# ============================================================
# XÂY DỰNG DANH SÁCH DIM
# ============================================================
ALL_DIMS="QD1 QD2 QD3 QD4 QD5 QD6 QD7 QD8 QD9 QD10"

if [[ "$DIMS_ARG" == "all" ]]; then
  DIMS_LIST="$ALL_DIMS"
else
  # Thay dấu phẩy bằng khoảng trắng
  DIMS_LIST="${DIMS_ARG//,/ }"
fi

# ============================================================
# TÍNH TOÁN CHI PHÍ
# ============================================================
total_cents=0
breakdown_json="[]"

for dim in $DIMS_LIST; do
  # Đọc probe counts (cross-platform: dùng awk thay <<< để tránh lỗi Git Bash)
  counts="$(probe_counts "$dim" "$PROFILE")"
  st=$(echo "$counts" | awk '{print $1}')
  rt=$(echo "$counts" | awk '{print $2}')
  ag=$(echo "$counts" | awk '{print $3}')

  # LLM scan add-on: 1 invocation per applicable dim khi --llm-scan
  ll=0
  if [[ "$LLM_SCAN" == "true" ]] && is_llm_scan_dim "$dim"; then
    ll=1
  fi

  dim_cents=$(( st * COST_STATIC_C + rt * COST_RUNTIME_C + ag * COST_AGENT_C + ll * COST_LLM_SCAN_C ))
  total_cents=$(( total_cents + dim_cents ))

  # Build JSON entry cho dim này
  entry=$(jq -nc \
    --arg  dim  "$dim" \
    --arg  prof "$PROFILE" \
    --argjson st "$st" \
    --argjson rt "$rt" \
    --argjson ag "$ag" \
    --argjson ll "$ll" \
    --argjson cst "$dim_cents" \
    '{
      dim: $dim,
      profile: $prof,
      static_probes: $st,
      runtime_probes: $rt,
      agent_probes: $ag,
      llm_scan_invocations: $ll,
      cost_cents: $cst
    }')

  breakdown_json=$(printf '%s' "$breakdown_json" | jq ". + [$entry]")
done

# Chuyển đổi cents → USD qua awk (không cần bc)
estimate_usd=$(awk "BEGIN{printf \"%.4f\", $total_cents/100.0}")
threshold_usd=$(awk "BEGIN{printf \"%.2f\", $THRESHOLD_CENTS/100.0}")

# So sánh integer cents (tránh float comparison trong bash)
over_threshold="false"
if [[ "$total_cents" -gt "$THRESHOLD_CENTS" ]]; then
  over_threshold="true"
fi

# ============================================================
# KẾT QUẢ JSON
# ============================================================
result_json=$(jq -nc \
  --argjson est "$(awk "BEGIN{print $total_cents/100.0}")" \
  --argjson bd  "$breakdown_json" \
  --argjson ov  "$over_threshold" \
  --argjson thr "$(awk "BEGIN{print $THRESHOLD_CENTS/100.0}")" \
  '{
    estimate_usd:   $est,
    breakdown:      $bd,
    over_threshold: $ov,
    threshold_usd:  $thr
  }')

printf '%s\n' "$result_json"

# Ghi ra file nếu --output được chỉ định
if [[ -n "$OUTPUT_PATH" ]]; then
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  atomic_write_json "$OUTPUT_PATH" "$result_json"
fi
