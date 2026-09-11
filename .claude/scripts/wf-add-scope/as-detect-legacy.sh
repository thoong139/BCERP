#!/usr/bin/env bash
# Detect LEGACY_MODE + deprecated modules (CORE-021, CORE-022)
# Usage: bash as-detect-legacy.sh
# Output: JSON {legacy_mode, deprecated_modules[], project_context_exists}
set -euo pipefail

LEGACY_FILE=".mc-data/work/legacy-scan/project-context.md"
DECISIONS_FILE=".mc-data/work/wf-brainstorm/legacy-decisions.json"

# LEGACY_MODE detection (CORE-021): file exists + size > 500 bytes
LEGACY=false
PROJECT_CONTEXT_EXISTS=false
if [[ -f "$LEGACY_FILE" ]]; then
  PROJECT_CONTEXT_EXISTS=true
  SIZE=$(wc -c < "$LEGACY_FILE" | tr -d ' ')
  if [[ "$SIZE" -gt 500 ]]; then
    LEGACY=true
  fi
fi

# Legacy decisions — deprecated modules (CORE-022)
DEPRECATED="[]"
if [[ "$LEGACY" == "true" && -f "$DECISIONS_FILE" ]]; then
  DEPRECATED=$(jq '.deprecated_modules // []' "$DECISIONS_FILE" 2>/dev/null || echo "[]")
fi

echo "{\"legacy_mode\":$LEGACY,\"deprecated_modules\":$DEPRECATED,\"project_context_exists\":$PROJECT_CONTEXT_EXISTS}"
