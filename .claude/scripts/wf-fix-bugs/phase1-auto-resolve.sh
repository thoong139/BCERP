#!/usr/bin/env bash
# =============================================================================
# phase1-auto-resolve.sh — Phase 1 Step 1.8 Auto-Resolve Quick Decisions
# =============================================================================
# Mục đích (v10.14.0 — extracted from phase1-init.md):
#   Auto-resolve E091 (scope warning), E092 (cost estimate), E093 (mobile device).
#   E090/E090b defer Phase 4 (xem phase1-init/B-wave1.md note).
#
# Required env vars: SCOPE, NAME, PROFILE, MOBILE_MODE, MOBILE_DEVICE
# Optional env vars: MODULE_COUNT (auto-compute nếu chưa set)
#
# Output (stdout, eval-friendly):
#   SCOPE=<possibly-narrowed>
#   ESTIMATED_MIN=<number>
#   MODULE_COUNT=<number>
#   AUTO_RESOLVE_NOTES=<multi-line string for Phase1-report.md>
#
# Exit codes:
#   0 — Auto-resolve OK (orchestrator continues)
#
# Compatibility: Pure bash + find.
# =============================================================================

set -u

# ── Validate required env vars ───────────────────────────────────────────────
for var in SCOPE PROFILE; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: \$$var required" >&2
    exit 1
  fi
done

NAME="${NAME:-}"
MOBILE_MODE="${MOBILE_MODE:-false}"
MOBILE_DEVICE="${MOBILE_DEVICE:-iPhone 14}"
NOTES=""

# ── E091: Scope auto-resolve ────────────────────────────────────────────────
if [ -z "${MODULE_COUNT:-}" ]; then
  MODULE_COUNT=$(find apps src -maxdepth 3 \( -name "module.json" -o -name "package.json" \) 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$SCOPE" = "all" ] && [ -z "$NAME" ]; then
  if [ "${MODULE_COUNT:-0}" -gt 20 ]; then
    NOTES="${NOTES}[WARN E091] Scope=all với $MODULE_COUNT modules — phạm vi rộng. Khuyến nghị --scope=module --name=<id>.\n"
    echo "[WARN E091] Scope=all với $MODULE_COUNT modules — phạm vi rộng, ước tính chạy lâu." >&2
    echo "[WARN E091] Khuyến nghị: dùng --scope=module --name=<id> để thu hẹp. Tiếp tục anyway..." >&2
  fi
elif [ -n "$NAME" ] && [ "$SCOPE" = "all" ]; then
  # User pass --name nhưng vẫn để scope=all → auto-narrow
  echo "[INFO E091] Auto-narrow scope=all → scope=module vì --name='$NAME' provided" >&2
  NOTES="${NOTES}[INFO E091] Auto-narrowed scope=all→scope=module (--name=$NAME provided).\n"
  SCOPE="module"
fi

# ── E092: Cost WARN log only ─────────────────────────────────────────────────
case "$PROFILE" in
  quick)      EXPECTED_MIN=5;   WARN_MIN=15  ;;
  standard)   EXPECTED_MIN=15;  WARN_MIN=45  ;;
  deep)       EXPECTED_MIN=45;  WARN_MIN=120 ;;
  exhaustive) EXPECTED_MIN=120; WARN_MIN=300 ;;
  *)          EXPECTED_MIN=15;  WARN_MIN=45  ;;  # fallback standard
esac

COST_MULTIPLIER=1
if [ "$SCOPE" = "all" ] && [ "${MODULE_COUNT:-0}" -gt 10 ]; then
  COST_MULTIPLIER=2
fi
ESTIMATED_MIN=$((EXPECTED_MIN * COST_MULTIPLIER))

if [ "$ESTIMATED_MIN" -gt "$WARN_MIN" ]; then
  NOTES="${NOTES}[WARN E092] Ước tính ${ESTIMATED_MIN}p (>$WARN_MIN ngưỡng cho profile=$PROFILE). Khuyến nghị --profile=quick hoặc --scope=module.\n"
  echo "[WARN E092] Ước tính ${ESTIMATED_MIN}p (>$WARN_MIN ngưỡng cho profile=$PROFILE)." >&2
  echo "[WARN E092] Khuyến nghị: --profile=quick hoặc --scope=module để giảm. Tiếp tục anyway..." >&2
fi

# ── E093: Mobile auto-default ────────────────────────────────────────────────
if [ "$MOBILE_MODE" = "true" ]; then
  echo "[INFO E093] Mobile mode active — device=$MOBILE_DEVICE (default iPhone 14)" >&2
  NOTES="${NOTES}[INFO E093] Mobile mode active — device=$MOBILE_DEVICE.\n"
fi

# ── Output env-style stdout ──────────────────────────────────────────────────
# Escape newlines in NOTES for env-safe single-line value
NOTES_ESCAPED=$(printf '%s' "$NOTES" | tr '\n' '|')

cat <<EOF
SCOPE=$SCOPE
ESTIMATED_MIN=$ESTIMATED_MIN
MODULE_COUNT=$MODULE_COUNT
AUTO_RESOLVE_NOTES='$NOTES_ESCAPED'
EOF

exit 0
