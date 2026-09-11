#!/usr/bin/env bash
# =============================================================================
# phase1-parse-flags.sh — Phase 1 Step 1.2 Parse CLI Flags
# =============================================================================
# Mục đích (v10.14.0 — extracted from phase1-init.md):
#   Parse $ARGUMENTS thành env-style stdout cho orchestrator eval.
#   Tiết kiệm ~60 dòng inline bash trong procedure file.
#
# Input: $ARGUMENTS env var (CLI arguments string)
#
# Output (stdout, eval-friendly):
#   PROFILE=standard
#   SCOPE=all
#   NAME=
#   DRY_RUN=false
#   LLM_SCAN=false
#   SHOW_BROWSER=false
#   NO_BROWSER=false
#   MOBILE_MODE=false
#   MOBILE_DEVICE=iPhone 14
#   DIMS_ARRAY=
#   URL=
#   CREDENTIALS=
#   SESSION_ID_FLAG=
#   RESUME_STRATEGY=prompt
#   HAS_STATUS=false
#   HAS_RESUME=false
#   HAS_MIGRATE=false
#
# Exit codes:
#   0 — Parse OK
#   2 — Invalid flag value (with WARN, still continues)
#
# Compatibility: Pure bash POSIX-safe (read -ra + array tokens).
# =============================================================================

set -u

# ── Defaults (env override allowed) ──────────────────────────────────────────
PROFILE="${MCV3_PROFILE:-standard}"
SCOPE="${MCV3_SCOPE:-all}"
NAME="${MCV3_NAME:-}"
DRY_RUN=false
LLM_SCAN=false
SHOW_BROWSER=false
NO_BROWSER=false
MOBILE_MODE=false
MOBILE_DEVICE="${MCV3_MOBILE_DEVICE:-iPhone 14}"
DIMS_ARRAY=""
URL="${MCV3_URL:-}"
CREDENTIALS="${MCV3_CREDENTIALS:-}"
SESSION_ID_FLAG=""
RESUME_STRATEGY="${MCV3_RESUME_STRATEGY:-prompt}"
HAS_STATUS=false
HAS_RESUME=false
HAS_MIGRATE=false

# ── Parse ARGUMENTS (POSIX-safe word split via read -ra) ─────────────────────
# v10.10.0 fix: dùng read -ra để chống word-split khi value chứa space
# (Windows paths có space)
read -ra _ARG_TOKENS <<< "${ARGUMENTS:-}"

for arg in "${_ARG_TOKENS[@]}"; do
  case "$arg" in
    --profile=*)     PROFILE="${arg#*=}" ;;
    --scope=*)       SCOPE="${arg#*=}" ;;
    --name=*)        NAME="${arg#*=}" ;;
    --dry-run)       DRY_RUN=true ;;
    --llm-scan)      LLM_SCAN=true ;;
    --show-browser)  SHOW_BROWSER=true ;;
    --no-browser)    NO_BROWSER=true ;;
    --mobile)        MOBILE_MODE=true; SHOW_BROWSER=true ;;  # mobile auto-set visible
    --device=*)      MOBILE_DEVICE="${arg#*=}" ;;
    --dims=*)        DIMS_ARRAY="${arg#*=}" ;;
    --url=*)         URL="${arg#*=}" ;;
    --credentials=*) CREDENTIALS="${arg#*=}" ;;
    --session=*)     SESSION_ID_FLAG="${arg#*=}" ;;
    --resume-strategy=*) RESUME_STRATEGY="${arg#*=}" ;;
    --status)        HAS_STATUS=true ;;
    --resume)        HAS_RESUME=true ;;
    --migrate)       HAS_MIGRATE=true ;;
  esac
done

# ── Validate enum: --resume-strategy ─────────────────────────────────────────
case "$RESUME_STRATEGY" in
  prompt|auto|force-fresh) ;;
  *) echo "WARN: Invalid --resume-strategy='$RESUME_STRATEGY' — fallback to 'prompt'" >&2
     RESUME_STRATEGY="prompt" ;;
esac

# ── Validate: --session only with --resume/--status ──────────────────────────
if [ -n "$SESSION_ID_FLAG" ] && [ "$HAS_RESUME" = "false" ] && [ "$HAS_STATUS" = "false" ]; then
  echo "WARN: --session=$SESSION_ID_FLAG bị bỏ qua khi không có --resume/--status" >&2
  SESSION_ID_FLAG=""
fi

# ── Validate: --show-browser + --no-browser conflict ─────────────────────────
if [ "$SHOW_BROWSER" = "true" ] && [ "$NO_BROWSER" = "true" ]; then
  echo "WARN: --show-browser + --no-browser xung đột — ưu tiên --no-browser" >&2
  SHOW_BROWSER=false
fi

# ── Validate enum: $PROFILE ──────────────────────────────────────────────────
case "$PROFILE" in
  quick|standard|deep|exhaustive) ;;
  *) echo "WARN: Invalid --profile='$PROFILE' — fallback to 'standard'" >&2
     PROFILE="standard" ;;
esac

# ── Output env-style stdout ──────────────────────────────────────────────────
cat <<EOF
PROFILE=$PROFILE
SCOPE=$SCOPE
NAME='$NAME'
DRY_RUN=$DRY_RUN
LLM_SCAN=$LLM_SCAN
SHOW_BROWSER=$SHOW_BROWSER
NO_BROWSER=$NO_BROWSER
MOBILE_MODE=$MOBILE_MODE
MOBILE_DEVICE='$MOBILE_DEVICE'
DIMS_ARRAY='$DIMS_ARRAY'
URL='$URL'
CREDENTIALS='$CREDENTIALS'
SESSION_ID_FLAG='$SESSION_ID_FLAG'
RESUME_STRATEGY=$RESUME_STRATEGY
HAS_STATUS=$HAS_STATUS
HAS_RESUME=$HAS_RESUME
HAS_MIGRATE=$HAS_MIGRATE
EOF

exit 0
