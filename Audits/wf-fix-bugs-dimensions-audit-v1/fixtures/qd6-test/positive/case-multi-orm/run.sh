#!/usr/bin/env bash
# IMP-010 acceptance test — case-multi-orm/
#
# Tests:
#   1. ORM adapter detect() correctly identifies ORM types in each subdirectory
#   2. wf-fix-probe-static-orm.sh emits signals for each ORM stack
#   3. Minimum 4 ORMs detectable (EF Core, Prisma, TypeORM, SQLAlchemy)
#   4. Signal count >= 3 (at least 3 distinct ORM issues found)
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-multi-orm] IMP-010 acceptance test"
echo "[case-multi-orm] FIXTURE_DIR=$FIXTURE_DIR"

# Locate repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  # Walk up to find CLAUDE.md
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

if [ -z "$REPO_ROOT" ] || [ ! -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-orm.sh" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-orm.sh from $FIXTURE_DIR" >&2
  exit 1
fi

ORM_PROBE="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-orm.sh"
ADAPTER_DIR="$REPO_ROOT/.claude/skills/workflow/_shared/adapters"
SESSION_DIR="$(mktemp -d -t imp010-XXXXXX)"
trap 'rm -rf "$SESSION_DIR"' EXIT

echo "[case-multi-orm] Probe: $ORM_PROBE"
echo ""

# ============================================================
# Test 1: ORM adapter detect() per subdirectory
# ============================================================
echo "--- Test 1: ORM adapter detect() ---"
DETECTED_ORMS=0

for orm in ef-core prisma typeorm sqlalchemy hibernate; do
  subdir="$FIXTURE_DIR/$orm"
  [ -d "$subdir" ] || { echo "  SKIP: $orm subdir missing"; continue; }

  adapter_file="$ADAPTER_DIR/orm/${orm}.sh"
  if [ ! -f "$adapter_file" ]; then
    echo "  SKIP: adapter ${orm}.sh not found"
    continue
  fi

  if (source "$adapter_file" && detect "$subdir") >/dev/null 2>&1; then
    echo "  PASS: detect($orm) → matched for $subdir"
    DETECTED_ORMS=$((DETECTED_ORMS + 1))
  else
    echo "  FAIL: detect($orm) → no match for $subdir"
  fi
done

echo "  Detected ORMs: $DETECTED_ORMS / 5"
if [ "$DETECTED_ORMS" -lt 4 ]; then
  echo "  RESULT: FAIL — need >= 4 ORMs detectable (got $DETECTED_ORMS)"
  exit 1
fi

# ============================================================
# Test 2: wf-fix-probe-static-orm.sh emits signals for combined fixture
# ============================================================
echo ""
echo "--- Test 2: Probe signals across all ORM subdirs ---"
TOTAL_SIGNALS=0

for orm in ef-core prisma typeorm sqlalchemy hibernate; do
  subdir="$FIXTURE_DIR/$orm"
  [ -d "$subdir" ] || continue

  output=$(bash "$ORM_PROBE" \
    --session-dir "$SESSION_DIR" \
    --lane "wf-fix-data" \
    --probe "P-QD6-orm-model-sync" \
    --profile "standard" \
    --source-dir "$subdir" 2>/dev/null || echo '{"signals":[]}')

  count=$(echo "$output" | jq '.signals | length' 2>/dev/null || echo 0)
  echo "  $orm: $count signal(s)"

  if [ "$count" -gt 0 ]; then
    echo "$output" | jq -r '.signals[] | "    [" + .severity + "] " + .title' 2>/dev/null || true
  fi

  TOTAL_SIGNALS=$((TOTAL_SIGNALS + count))
done

echo ""
echo "  Total signals: $TOTAL_SIGNALS"
if [ "$TOTAL_SIGNALS" -lt 3 ]; then
  echo "  RESULT: FAIL — need >= 3 signals total (got $TOTAL_SIGNALS)"
  exit 1
fi

# ============================================================
# Test 3: Output is valid lane-signals-v1 JSON
# ============================================================
echo ""
echo "--- Test 3: Output schema validation ---"
SAMPLE=$(bash "$ORM_PROBE" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-data" \
  --probe "P-QD6-orm-model-sync" \
  --profile "standard" \
  --source-dir "$FIXTURE_DIR/ef-core" 2>/dev/null)

if echo "$SAMPLE" | jq -e '."$schema" == "lane-signals-v1" and (.signals | type) == "array"' >/dev/null 2>&1; then
  echo "  PASS: output is valid lane-signals-v1"
else
  echo "  FAIL: output is not valid lane-signals-v1"
  echo "$SAMPLE" | head -5
  exit 1
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  Detected ORMs: $DETECTED_ORMS / 5"
echo "  Total signals: $TOTAL_SIGNALS (>= 3)"
echo "  Schema: valid lane-signals-v1"
exit 0
