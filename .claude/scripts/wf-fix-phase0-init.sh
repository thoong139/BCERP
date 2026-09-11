#!/usr/bin/env bash
# wf-fix-phase0-init.sh — Phase 0 PRE-GATE validation + LEGACY_MODE detection
# Usage: bash .claude/scripts/wf-fix-phase0-init.sh
# Exports: LEGACY_MODE, DEPRECATED_MODULES
# Exit: 0=pass, 1=missing registry, 2=missing code, 3=common.sh not found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

COMMON_SH="$REPO_ROOT/.claude/scripts/wf-fix-common.sh"
if [ ! -f "$COMMON_SH" ]; then
  echo "ERROR: wf-fix-common.sh not found at $COMMON_SH" >&2
  exit 3
fi
source "$COMMON_SH"

# --- Forensic PRE-GATE validation (CORE-011, Protocol 10.4) ---

# Check registry exists + non-empty + has requirements
if ! test -s ".mc-data/docs/_meta/req-registry.json"; then
  echo "ERROR: req-registry.json not found or empty." >&2
  echo "Chạy /wf-brainstorm hoặc /existing-project trước." >&2
  exit 1
fi

if ! jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json >/dev/null 2>&1; then
  echo "ERROR: req-registry.json has no requirements." >&2
  echo "Chạy /wf-analyze-requirements trước." >&2
  exit 1
fi

# Check source code exists
if ! { test -d src || test -d apps; }; then
  echo "ERROR: No src/ or apps/ directory found." >&2
  echo "Chạy /wf-implement-feature trước." >&2
  exit 2
fi

# SOURCE_EXISTS: 1 if any source file found, 0 otherwise
# Chỉ truyền dir tồn tại vào find (tránh "find: 'X': No such file" → exit 1 dưới pipefail).
# -print -quit: find tự dừng ở match đầu (tránh SIGPIPE nếu pipe vào head).
SEARCH_ROOTS=()
[ -d src ] && SEARCH_ROOTS+=("src")
[ -d apps ] && SEARCH_ROOTS+=("apps")
SOURCE_EXISTS=$(find "${SEARCH_ROOTS[@]}" -maxdepth 4 -type f \
  \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
     -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.cs" \) \
  -print -quit 2>/dev/null | wc -l)

if [ "$SOURCE_EXISTS" -eq 0 ]; then
  echo "ERROR: No source code files found in src/ or apps/." >&2
  echo "Chạy /wf-implement-feature trước." >&2
  exit 2
fi

# --- LEGACY_MODE Detection (CORE-021) ---

LEGACY_MODE="false"
if test -f .mc-data/work/legacy-scan/project-context.md \
   && test "$(wc -c < .mc-data/work/legacy-scan/project-context.md 2>/dev/null || echo 0)" -gt 500; then
  LEGACY_MODE="true"
fi

# --- Legacy Decisions Bridge (CORE-022) ---

DEPRECATED_MODULES='[]'
if [ "$LEGACY_MODE" = "true" ]; then
  if test -f .mc-data/work/wf-brainstorm/legacy-decisions.json; then
    DEPRECATED_MODULES=$(jq -c '[.modules[]? | select(.action=="DEPRECATE") | .module_id]' \
      .mc-data/work/wf-brainstorm/legacy-decisions.json 2>/dev/null || echo '[]')
  else
    echo "WARNING: LEGACY_MODE=true nhưng legacy-decisions.json không tồn tại." >&2
    echo "Khuyến nghị: chạy /wf-brainstorm Phase 0.5 để tạo file." >&2
    echo "Tiếp tục với DEPRECATED_MODULES=[] (không enforce scope exclusion)." >&2
  fi
fi

# Export for downstream use
export LEGACY_MODE DEPRECATED_MODULES

echo "PRE-GATE validation passed."
echo "LEGACY_MODE=$LEGACY_MODE"
echo "DEPRECATED_MODULES=$DEPRECATED_MODULES"
