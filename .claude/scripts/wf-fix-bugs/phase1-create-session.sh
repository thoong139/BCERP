#!/usr/bin/env bash
# =============================================================================
# phase1-create-session.sh — Phase 1 Step 1.10 SESSION_ID + Directory Tree
# =============================================================================
# Mục đích (v10.14.0 — extracted from phase1-init.md):
#   POSIX-atomic SESSION_ID claim qua mkdir guard + tạo cây thư mục session.
#   Tiết kiệm ~40 dòng inline bash trong procedure file.
#
# Required env vars: SCOPE
# Optional env vars: NAME
#
# Output (stdout, eval-friendly):
#   SESSION_ID=YYYY-MM-DD-{scope}-{slug}-{NN}
#   SESSION_DIR=.mc-data/work/wf-fix-bugs/sessions/{SESSION_ID}
#
# Exit codes:
#   0 — Success
#   11 — Không claim được SESSION_ID (>99 sessions/ngày/scope) — E011
#   35 — Không tạo được subdirectory tree — E035
#
# Compatibility: POSIX-safe atomic mkdir, no brace expansion (works on Alpine).
# =============================================================================

set -eu

# ── Validate env vars ────────────────────────────────────────────────────────
if [ -z "${SCOPE:-}" ]; then
  echo "ERROR: \$SCOPE required" >&2
  exit 1
fi
NAME="${NAME:-}"

# ── Build SESSION_ID prefix ──────────────────────────────────────────────────
DATE_PREFIX=$(date +%Y-%m-%d)
SCOPE_SLUG=$(echo "$SCOPE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
NAME_SLUG=$(echo "${NAME:-session}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')

SESSIONS_ROOT=".mc-data/work/wf-fix-bugs/sessions"
mkdir -p "$SESSIONS_ROOT"

# ── Atomic SESSION_ID claim (POSIX-safe mkdir guard) ─────────────────────────
# Race-safe: nếu candidate_dir tồn tại → mkdir fail → tăng NN và retry.
# Max 99 sessions/ngày/scope.
SESSION_ID=""
SESSION_DIR=""
for nn_int in $(seq 1 99); do
  NN=$(printf "%02d" "$nn_int")
  candidate="${DATE_PREFIX}-${SCOPE_SLUG}-${NAME_SLUG}-${NN}"
  candidate_dir="$SESSIONS_ROOT/$candidate"
  # mkdir là POSIX-atomic: nếu tồn tại → exit non-zero
  if mkdir "$candidate_dir" 2>/dev/null; then
    SESSION_ID="$candidate"
    SESSION_DIR="$candidate_dir"
    break
  fi
done

if [ -z "$SESSION_ID" ]; then
  echo "E011: Không claim được SESSION_ID (>99 sessions/ngày/scope)" >&2
  exit 11
fi

# ── Create subdirectory tree (POSIX-safe, no brace expansion) ───────────────
# Brace expansion `phase{1-init,...}` là bash-specific, fail trên POSIX sh/Alpine
for subdir in phase1-init phase2-scan phase3-plan phase3-plan/workloads \
              phase4-find-bugs phase4-find-bugs/lanes \
              phase5-triage phase6-execute phase7-verify; do
  if ! mkdir -p "$SESSION_DIR/$subdir" 2>/dev/null; then
    echo "E035: Không tạo được $SESSION_DIR/$subdir" >&2
    exit 35
  fi
done

# ── Output env-style stdout ──────────────────────────────────────────────────
cat <<EOF
SESSION_ID=$SESSION_ID
SESSION_DIR=$SESSION_DIR
EOF

exit 0
