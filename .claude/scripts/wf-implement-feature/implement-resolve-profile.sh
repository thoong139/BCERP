#!/usr/bin/env bash
# implement-resolve-profile.sh — Resolve profile cho wf-implement-feature.
# Sprint 2 — Adaptive Profile (G4 fix).
#
# Usage:
#   bash implement-resolve-profile.sh [--scope-files-count=N] [--profile-override=<name>]
#
# Args:
#   --scope-files-count=N        Số files trong scope (từ task A2.4 hoặc đếm)
#   --profile-override=<name>    User chỉ định: quick|standard|deep|exhaustive (override auto)
#   --json                       Output JSON thay vì plain stdout
#
# Output (stdout):
#   - Plain mode: tên profile (1 từ): quick|standard|deep|exhaustive
#   - JSON mode (--json): {"profile":"...", "source":"override|auto", "scope_files_count":N, "rule_applied":"..."}
#
# stderr: thông báo recommendation (info)
#
# Resolution rules (auto):
#   ≤ 5 files     → quick
#   6-30 files    → standard
#   31-100 files  → deep
#   > 100 files   → exhaustive
#
# Override precedence:
#   1. --profile-override (CLI flag) → use directly
#   2. Auto resolve theo scope_files_count
#
# Exit codes:
#   0 = profile resolved
#   1 = invalid profile override (not in 4 allowed values)
#   2 = invalid scope_files_count (negative)

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=implement-common.sh
source "$SCRIPTS_DIR/implement-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

SCOPE_FILES_COUNT=0
PROFILE_OVERRIDE=""
JSON_OUTPUT="false"

for arg in "$@"; do
  case "$arg" in
    --scope-files-count=*) SCOPE_FILES_COUNT="${arg#*=}" ;;
    --profile-override=*)  PROFILE_OVERRIDE="${arg#*=}" ;;
    --json)                JSON_OUTPUT="true" ;;
    *) log_warn "Unknown arg: $arg" ;;
  esac
done

# ─── Validate scope_files_count ─────────────────────────────

if ! [[ "$SCOPE_FILES_COUNT" =~ ^-?[0-9]+$ ]]; then
  log_error "Invalid --scope-files-count: '$SCOPE_FILES_COUNT' (must be integer)"
  exit 2
fi
if (( SCOPE_FILES_COUNT < 0 )); then
  log_error "Invalid --scope-files-count: $SCOPE_FILES_COUNT (must be >= 0)"
  exit 2
fi

# ─── Allowed profiles ───────────────────────────────────────

readonly ALLOWED_PROFILES="quick standard deep exhaustive"

is_allowed_profile() {
  local p="$1"
  case " $ALLOWED_PROFILES " in
    *" $p "*) return 0 ;;
    *)        return 1 ;;
  esac
}

# ─── Resolve ────────────────────────────────────────────────

PROFILE=""
SOURCE=""
RULE_APPLIED=""

if [[ -n "$PROFILE_OVERRIDE" ]]; then
  if ! is_allowed_profile "$PROFILE_OVERRIDE"; then
    log_error "Invalid --profile-override: '$PROFILE_OVERRIDE' (allowed: $ALLOWED_PROFILES)"
    exit 1
  fi
  PROFILE="$PROFILE_OVERRIDE"
  SOURCE="override"
  RULE_APPLIED="user_override"
  log_info "Profile = $PROFILE (user override, ignoring scope_files_count=$SCOPE_FILES_COUNT)"
else
  if   (( SCOPE_FILES_COUNT <= 5 )); then
    PROFILE="quick"
    RULE_APPLIED="auto_le_5_files"
  elif (( SCOPE_FILES_COUNT <= 30 )); then
    PROFILE="standard"
    RULE_APPLIED="auto_6_to_30_files"
  elif (( SCOPE_FILES_COUNT <= 100 )); then
    PROFILE="deep"
    RULE_APPLIED="auto_31_to_100_files"
  else
    PROFILE="exhaustive"
    RULE_APPLIED="auto_gt_100_files"
  fi
  SOURCE="auto"
  log_info "No --profile specified. Auto-recommended: $PROFILE ($SCOPE_FILES_COUNT files, rule=$RULE_APPLIED)"
fi

# ─── Output ─────────────────────────────────────────────────

if [[ "$JSON_OUTPUT" == "true" ]]; then
  if has_jq; then
    jq -nc \
      --arg profile "$PROFILE" \
      --arg source "$SOURCE" \
      --arg rule "$RULE_APPLIED" \
      --argjson count "$SCOPE_FILES_COUNT" \
      '{profile:$profile, source:$source, scope_files_count:$count, rule_applied:$rule}'
  else
    # Fallback: hand-built JSON khi jq không có
    printf '{"profile":"%s","source":"%s","scope_files_count":%d,"rule_applied":"%s"}\n' \
      "$PROFILE" "$SOURCE" "$SCOPE_FILES_COUNT" "$RULE_APPLIED"
  fi
else
  echo "$PROFILE"
fi

exit 0
