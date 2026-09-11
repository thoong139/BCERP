#!/usr/bin/env bash
# =============================================================================
# phase1-isg-fastpath.sh — Phase 1 Step 1.14 ISG Profile → Dimensions Fast-Path
# =============================================================================
# Mục đích (v10.11.0 — Phase 1 optimization):
#   Resolve DIMS_ARRAY từ PROFILE qua bash hardcoded lookup, bypass Python
#   spawn cho 4 profile chuẩn (quick/standard/deep/exhaustive).
#
#   Giá trị hardcoded ĐỒNG BỘ với `isg_recommender.py PROFILE_DIMENSIONS`:
#     quick      → QD1 QD5
#     standard   → QD1 QD2 QD5 QD9 QD10
#     deep       → QD1 QD2 QD5 QD6 QD3 QD9 QD10 QD11
#     exhaustive → toàn bộ 11 dims (QD1-QD11)
#
# Lý do bypass an toàn:
#   - Phase 1 chưa có scan data → ISG analyze chỉ return profile defaults
#   - REAL ISG recommendation chạy ở Phase 3 (sau khi có scan signals)
#   - Phase 1 chỉ cần "seed" dims để Phase 3 biết starting point
#
# Trước (v10.10): `python -m isg analyze` ~200-500ms (cold Python interpreter)
# Sau  (v10.11): bash lookup ~5ms (~50x nhanh hơn)
#
# Escape hatch:
#   MCV3_FIX_BUGS_FORCE_ISG=1 → force Python path (legacy behavior, dev/debug)
#
# CLI:
#   bash phase1-isg-fastpath.sh --profile=<p> [--session-dir=<dir>] [--scope=<s>]
#
# Exit codes:
#   0 — DIMS_ARRAY resolved (stdout = dims space-separated)
#   30 — E030: Unknown profile + Python fallback fail
#
# Output: DIMS_ARRAY trên stdout (1 dòng, space-separated)
#   vd: "QD1 QD2 QD5 QD9 QD10"
#
# Compatibility: Pure bash. Optional Python fallback nếu profile lạ.
# =============================================================================

set -eu

# ── Parse args ───────────────────────────────────────────────────────────────
PROFILE=""
SESSION_DIR=""
SCOPE=""

for arg in "$@"; do
  case "$arg" in
    --profile=*)     PROFILE="${arg#*=}" ;;
    --session-dir=*) SESSION_DIR="${arg#*=}" ;;
    --scope=*)       SCOPE="${arg#*=}" ;;
    *) ;;
  esac
done

if [ -z "$PROFILE" ]; then
  echo "ERROR: --profile required" >&2
  exit 30
fi

# ── Force Python path (escape hatch) ─────────────────────────────────────────
if [ "${MCV3_FIX_BUGS_FORCE_ISG:-0}" = "1" ]; then
  ISG_OUTPUT=$(python -m isg analyze \
    --session-dir="${SESSION_DIR:-/tmp}" \
    --profile="$PROFILE" \
    --scope="${SCOPE:-all}" 2>/dev/null) || {
      echo "E030: ISG analyze fail (forced Python path)" >&2
      exit 30
    }
  echo "$ISG_OUTPUT" | jq -r '.recommendations[]?.dim // empty' | tr '\n' ' ' | sed 's/ $//'
  exit 0
fi

# ── Fast-path: bash hardcoded lookup ─────────────────────────────────────────
case "$PROFILE" in
  quick)
    echo "QD1 QD5"
    ;;
  standard)
    echo "QD1 QD2 QD5 QD9 QD10"
    ;;
  deep)
    echo "QD1 QD2 QD5 QD6 QD3 QD9 QD10 QD11"
    ;;
  exhaustive)
    # Full 11 dims theo isg_recommender.DIMENSIONS
    echo "QD1 QD2 QD3 QD4 QD5 QD6 QD7 QD8 QD9 QD10 QD11"
    ;;
  *)
    # Unknown profile → fallback Python ISG (legacy support)
    if command -v python >/dev/null 2>&1; then
      ISG_OUTPUT=$(python -m isg analyze \
        --session-dir="${SESSION_DIR:-/tmp}" \
        --profile="$PROFILE" \
        --scope="${SCOPE:-all}" 2>/dev/null) || {
          # Final fallback: standard defaults
          echo "WARN: ISG analyze fail cho profile='$PROFILE' — fallback standard" >&2
          echo "QD1 QD2 QD5 QD9 QD10"
          exit 0
        }
      DIMS=$(echo "$ISG_OUTPUT" | jq -r '.recommendations[]?.dim // empty' | tr '\n' ' ' | sed 's/ $//')
      if [ -z "$DIMS" ]; then
        echo "QD1 QD2 QD5 QD9 QD10"   # standard fallback
      else
        echo "$DIMS"
      fi
    else
      echo "WARN: Unknown profile='$PROFILE', Python missing — fallback standard" >&2
      echo "QD1 QD2 QD5 QD9 QD10"
    fi
    ;;
esac
