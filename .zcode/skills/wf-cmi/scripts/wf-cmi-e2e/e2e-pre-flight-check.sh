#!/usr/bin/env bash
# e2e-pre-flight-check.sh — 5x stability check cho 1 scenario (Phase 9 §G1.3)
# Usage:
#   ./e2e-pre-flight-check.sh <scenario-file> [--runs=5] [--registry=<path>]
#
# WHY: Scenario flaky (PASS/FAIL inconsistent giữa runs) làm nhiễu evidence của Phase 9 thật.
# 5x pre-flight: scenario phải PASS 5/5 lần để được mark stable.
#   5/5 PASS → mark stable, add vào stable-registry.json TTL 30 ngày
#   4/5 PASS → WARN, continue execute Phase 9 (chấp nhận risk)
#   ≤3/5 PASS → E152 auto-quarantine, SKIP scenario (ghi vào quarantine-report.json)
#
# Stage 4 implementation NOTE:
# - Stub này LOG plan và stub-return PASS (5/5) cho tất cả scenarios
# - Lý do: 5x stability cần Playwright MCP runtime execution per scenario —
#   chỉ implement trong Step 9.4 caller (procedure file) khi browser-mcp.lock đã acquired.
# - Stub giúp Stage 4 testable: caller gọi script với --runs=0 để skip thật, --runs=5 để mark stable
#
# Output (stdout JSON):
#   {"scenario_file":"<path>","runs":5,"pass":5,"fail":0,"stability":"stable","flaky":false}
#
# Exit codes: 0=stable hoặc warn, 1=quarantine (≤3/5)
set -euo pipefail

SCENARIO_FILE="${1:-}"
RUNS=5
REGISTRY_PATH=""

[ -z "$SCENARIO_FILE" ] && { echo "Usage: $0 <scenario-file> [--runs=5] [--registry=<path>]" >&2; exit 1; }
[ ! -f "$SCENARIO_FILE" ] && { echo "File not found: $SCENARIO_FILE" >&2; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --runs=*) RUNS="${arg#--runs=}" ;;
    --registry=*) REGISTRY_PATH="${arg#--registry=}" ;;
  esac
done

# Validate RUNS
if ! [[ "$RUNS" =~ ^[0-9]+$ ]] || [ "$RUNS" -lt 1 ] || [ "$RUNS" -gt 10 ]; then
  echo "Invalid --runs (must be 1-10): $RUNS" >&2
  exit 1
fi

# ─── Check stable-registry hit (skip 5x nếu hash khớp TTL <30d) ───
if [ -n "$REGISTRY_PATH" ] && [ -f "$REGISTRY_PATH" ]; then
  # Compute hash của scenario
  if command -v sha256sum >/dev/null 2>&1; then
    SCENARIO_HASH=$(sha256sum "$SCENARIO_FILE" 2>/dev/null | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    SCENARIO_HASH=$(shasum -a 256 "$SCENARIO_FILE" 2>/dev/null | awk '{print $1}')
  else
    SCENARIO_HASH=""
  fi

  if [ -n "$SCENARIO_HASH" ] && command -v jq >/dev/null 2>&1; then
    # Search registry cho hash + check TTL
    REGISTRY_HIT=$(jq -r --arg hash "$SCENARIO_HASH" --arg now "$(date -u +%s)" '
      .scenarios[]?
      | select(.scenario_file_hash == $hash)
      | select((.expires_at | fromdateiso8601 // 0) > ($now | tonumber))
      | .scenario_id
    ' "$REGISTRY_PATH" 2>/dev/null | head -1)

    if [ -n "$REGISTRY_HIT" ]; then
      # Cache hit — skip 5x check, return stable
      printf '{"scenario_file":"%s","runs":0,"pass":0,"fail":0,"stability":"stable","flaky":false,"registry_hit":true,"registry_scenario_id":"%s"}\n' \
        "$SCENARIO_FILE" "$REGISTRY_HIT"
      exit 0
    fi
  fi
fi

# ─── Stage 4 STUB: simulate 5x runs ───
# REAL implementation Step 9.4 caller logic:
#   FOR i in 1..RUNS:
#     - Acquire browser-mcp.lock (already held by Phase 9 main)
#     - Login (cached session if available)
#     - playwright_retry(navigate_to_entry_url, max=3)
#     - Execute Step 1 only (smoke smoke test) hoặc full scenario tùy strict mode
#     - Record PASS/FAIL
#   Compute stability:
#     5/5 → stable
#     4/5 → flaky_warn
#     ≤3/5 → flaky_quarantine
#
# Stub: trả về 5/5 PASS để testing (caller mock với --runs=0 hoặc env STUB_PASS_RATE)
STUB_PASS_RATE="${STUB_PASS_RATE:-100}"  # percent — default 100% (5/5)

PASS=0
FAIL=0
# Deterministic stub:
#   STUB_PASS_RATE >= 100   → all PASS
#   STUB_PASS_RATE <= 0     → all FAIL
#   STUB_PASS_RATE in 1-99  → ceil(RUNS * STUB_PASS_RATE / 100) PASS, rest FAIL
#   STUB_FORCE_PASS=<N>     → exactly N PASS, RUNS-N FAIL (overrides STUB_PASS_RATE)
if [ -n "${STUB_FORCE_PASS:-}" ]; then
  PASS="$STUB_FORCE_PASS"
  [ "$PASS" -gt "$RUNS" ] && PASS="$RUNS"
  FAIL=$((RUNS - PASS))
elif [ "$STUB_PASS_RATE" -ge 100 ]; then
  PASS="$RUNS"
elif [ "$STUB_PASS_RATE" -le 0 ]; then
  FAIL="$RUNS"
else
  # Pro-rated split: ceil(RUNS * STUB_PASS_RATE / 100)
  PASS=$(( (RUNS * STUB_PASS_RATE + 99) / 100 ))
  [ "$PASS" -gt "$RUNS" ] && PASS="$RUNS"
  FAIL=$((RUNS - PASS))
fi

# Classify stability
if [ "$PASS" -eq "$RUNS" ]; then
  STABILITY="stable"
  FLAKY=false
  EXIT_CODE=0
elif [ "$PASS" -ge $((RUNS - 1)) ]; then
  STABILITY="flaky_warn"
  FLAKY=true
  EXIT_CODE=0  # WARN — continue
else
  STABILITY="flaky_quarantine"
  FLAKY=true
  EXIT_CODE=1  # E152 quarantine
fi

printf '{"scenario_file":"%s","runs":%d,"pass":%d,"fail":%d,"stability":"%s","flaky":%s,"registry_hit":false}\n' \
  "$SCENARIO_FILE" "$RUNS" "$PASS" "$FAIL" "$STABILITY" "$FLAKY"

exit "$EXIT_CODE"
