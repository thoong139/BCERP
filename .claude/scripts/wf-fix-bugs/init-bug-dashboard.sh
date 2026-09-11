#!/usr/bin/env bash
# =============================================================================
# init-bug-dashboard.sh — Phase 1 Step 1.22 Initialize Bug Dashboard
# =============================================================================
# Implements pattern from `procedures/_shared.md §19 Bug Dashboard Update Pattern`
# for `current-phase="init"`. Creates:
#   1. $SESSION_DIR/bug-dashboard.md  (rendered from template — Python CLI or inline fallback)
#   2. $SESSION_DIR/bug-dashboard.md.meta.json  (init-phase metadata, §19.1)
#
# Usage:
#   bash init-bug-dashboard.sh \
#     --session-dir=<path> --session-id=<id> \
#     --project-name=<name> --scope=<scope> --profile=<profile>
#
# Exit codes:
#   0 — Dashboard + meta created successfully
#   35 — E035: template missing OR generation failed (NON-BLOCKING per §19.4)
#
# Compatibility: Git Bash + WSL. Pure bash + jq + sed (+ optional Python).
# =============================================================================

set -eu

# ── Parse args ───────────────────────────────────────────────────────────────
SESSION_DIR=""
SESSION_ID=""
PROJECT_NAME=""
SCOPE=""
PROFILE=""

for arg in "$@"; do
  case "$arg" in
    --session-dir=*)  SESSION_DIR="${arg#*=}" ;;
    --session-id=*)   SESSION_ID="${arg#*=}" ;;
    --project-name=*) PROJECT_NAME="${arg#*=}" ;;
    --scope=*)        SCOPE="${arg#*=}" ;;
    --profile=*)      PROFILE="${arg#*=}" ;;
    *) echo "WARN: Unknown arg: $arg" >&2 ;;
  esac
done

# Required args
for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var}" ]; then
    echo "ERROR: --${var,,} required" >&2
    exit 35
  fi
done

# ── Paths (canonical per _shared.md §19.1) ───────────────────────────────────
TEMPLATE=".claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/bug-dashboard.md"
TARGET="$SESSION_DIR/bug-dashboard.md"
META="$SESSION_DIR/bug-dashboard.md.meta.json"

if [ ! -f "$TEMPLATE" ]; then
  echo "E035: bug-dashboard template not found: $TEMPLATE" >&2
  exit 35
fi

mkdir -p "$SESSION_DIR"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── 1. Generate bug-dashboard.md (Python CLI primary, sed fallback) ─────────
GENERATED=false
if command -v python >/dev/null 2>&1; then
  set +e
  python -m dashboard_generator \
    --template="$TEMPLATE" \
    --output="$TARGET" \
    --session-id="$SESSION_ID" \
    --project-name="$PROJECT_NAME" \
    --scope="$SCOPE" \
    --profile="$PROFILE" \
    --current-phase="init" 2>/dev/null
  PY_EXIT=$?
  set -e
  [ "$PY_EXIT" -eq 0 ] && [ -s "$TARGET" ] && GENERATED=true
fi

# Fallback: inline sed
# v10.11.0: init phase sets DASHBOARD_VERSION=1, LAST_WRITER=phase-1-init.
if [ "$GENERATED" = "false" ]; then
  sed \
    -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
    -e "s|\[PROJECT_NAME\]|$PROJECT_NAME|g" \
    -e "s|\[SCOPE\]|$SCOPE|g" \
    -e "s|\[PROFILE\]|$PROFILE|g" \
    -e "s|\[CURRENT_PHASE\]|init|g" \
    -e "s|\[CREATED_AT\]|$NOW|g" \
    -e "s|\[UPDATED_AT\]|$NOW|g" \
    -e "s|\[DASHBOARD_VERSION\]|1|g" \
    -e "s|\[LAST_WRITER\]|phase-1-init|g" \
    -e '/_template_notes/d' \
    -e '/_schema_notes/d' \
    "$TEMPLATE" > "$TARGET.tmp.$$" \
    && [ -s "$TARGET.tmp.$$" ] \
    && mv "$TARGET.tmp.$$" "$TARGET" \
    || { rm -f "$TARGET.tmp.$$"; echo "E035: dashboard inline generation failed" >&2; exit 35; }
fi

# ── 2. Generate meta JSON (init phase only) ──────────────────────────────────
jq -n \
  --arg id "$SESSION_ID" \
  --arg time "$NOW" \
  --arg profile "$PROFILE" \
  --arg scope "$SCOPE" \
  --arg name "$PROJECT_NAME" \
  '{
    session_id: $id,
    created_at: $time,
    project_name: $name,
    profile: $profile,
    scope: $scope,
    issues: [],
    summary: {total: 0, fixed: 0, open: 0}
  }' > "$META.tmp.$$" \
  && jq '.' "$META.tmp.$$" > /dev/null 2>&1 \
  && mv "$META.tmp.$$" "$META" \
  || { rm -f "$META.tmp.$$"; echo "E035: meta JSON build failed" >&2; exit 35; }

# ── VERIFY (POST-GATE T1-T2 per §19.2) ───────────────────────────────────────
test -s "$TARGET" || { echo "E035: dashboard empty after write" >&2; exit 35; }
grep -q "Bug Dashboard\|$SESSION_ID" "$TARGET" || echo "WARN: header marker missing in dashboard" >&2

exit 0
