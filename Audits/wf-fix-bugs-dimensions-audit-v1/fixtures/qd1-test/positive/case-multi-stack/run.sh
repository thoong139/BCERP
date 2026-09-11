#!/usr/bin/env bash
# IMP-001 acceptance test: Multi-stack route detection
#
# Tests that wf-fix-probe-static-route.sh detects routes from:
#   - ASP.NET Core (C# - dotnet-controller.cs)
#   - Spring Boot (Java - spring-controller.java)
#   - FastAPI (Python - fastapi-routes.py)
#   - Express/NestJS (TypeScript - express-routes.ts)
#
# PASS criteria:
#   - ≥1 route signal emitted per stack (≥4 total)
#   - All stacks have framework field matching expected value
#   - No fatal probe error
#
# USAGE: bash run.sh [--dry-run]

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

echo "[run.sh] IMP-001 — Multi-stack route detection fixture"
echo "[run.sh] FIXTURE_DIR=$FIXTURE_DIR"

# Locate probe script
PROBE_SCRIPT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-route.sh" ]; then
  PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-route.sh"
fi
for candidate in \
  "../../../../../.claude/scripts/wf-fix-probe-static-route.sh" \
  "../../../../../../.claude/scripts/wf-fix-probe-static-route.sh"; do
  if [ -z "$PROBE_SCRIPT" ] && [ -f "$FIXTURE_DIR/$candidate" ]; then
    PROBE_SCRIPT="$(cd "$FIXTURE_DIR/$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    break
  fi
done

if [ -z "$PROBE_SCRIPT" ] || [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-route.sh" >&2; exit 1
fi
echo "[run.sh] PROBE_SCRIPT=$PROBE_SCRIPT"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[run.sh] --dry-run: preflight PASS"
  exit 0
fi

# ============================================================
SESSION_DIR="$(mktemp -d -t imp001-fixture-XXXXXX)"
ACTUAL="$FIXTURE_DIR/.actual-signals.json"
trap 'rm -rf "$SESSION_DIR"' EXIT

echo "[run.sh] Running probe on fixture dir..."
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-route-config-parse" \
  --profile "standard" \
  --source-dir "$FIXTURE_DIR" \
  > "$ACTUAL"

# ============================================================
TOTAL=$(jq '.signals | length' "$ACTUAL")
echo "[run.sh] Total signals: $TOTAL"
echo "[run.sh] Signal breakdown:"
jq -r '.signals[] | "  [" + .severity + "] " + .title' "$ACTUAL" 2>/dev/null || true

# Per-stack counts — check description field (immune to MSYS path conversion)
# description contains "(framework: aspnet)", "(framework: spring-boot)", etc.
DOTNET_COUNT=$(jq '[.signals[] | select(.description | contains("framework: aspnet"))] | length' "$ACTUAL")
SPRING_COUNT=$(jq '[.signals[] | select(.description | contains("framework: spring-boot"))] | length' "$ACTUAL")
FASTAPI_COUNT=$(jq '[.signals[] | select(.description | contains("framework: fastapi"))] | length' "$ACTUAL")
EXPRESS_COUNT=$(jq '[.signals[] | select((.description | contains("framework: express")) or (.description | contains("framework: nestjs")))] | length' "$ACTUAL")

echo ""
echo "[run.sh] Stack coverage:"
echo "  .NET / ASP.NET Core: $DOTNET_COUNT signal(s)"
echo "  Spring Boot (Java):  $SPRING_COUNT signal(s)"
echo "  FastAPI (Python):    $FASTAPI_COUNT signal(s)"
echo "  Express/NestJS:      $EXPRESS_COUNT signal(s)"

# ============================================================
PASS=true
if [ "$DOTNET_COUNT" -lt 1 ]; then
  echo "  FAIL: .NET routes not detected (expected >= 1)" >&2; PASS=false
fi
if [ "$SPRING_COUNT" -lt 1 ]; then
  echo "  FAIL: Spring Boot routes not detected (expected >= 1)" >&2; PASS=false
fi
if [ "$FASTAPI_COUNT" -lt 1 ]; then
  echo "  FAIL: FastAPI routes not detected (expected >= 1)" >&2; PASS=false
fi
if [ "$EXPRESS_COUNT" -lt 1 ]; then
  echo "  FAIL: Express/NestJS routes not detected (expected >= 1)" >&2; PASS=false
fi
if [ "$TOTAL" -lt 4 ]; then
  echo "  FAIL: total signals $TOTAL < 4" >&2; PASS=false
fi

echo ""
if $PASS; then
  echo "  VERDICT: PASS — all 4 stacks detected (IMP-001 acceptance criteria met)"
  exit 0
else
  echo "  VERDICT: FAIL — one or more stacks not detected"
  exit 1
fi
