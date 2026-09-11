#!/usr/bin/env bash
# build-fixture.sh — build synthetic benchmark project từ template/
#
# Usage:
#   build-fixture.sh                    # Build vào ./output/
#   build-fixture.sh --target <path>    # Build vào custom path
#   build-fixture.sh --help
#
# Behavior:
#   1. Verify template/ tồn tại
#   2. Copy template/ → target
#   3. Init git in target + initial commit (cho wf-fix-bugs detect_changes)
#   4. Print summary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"
TARGET_DIR="$SCRIPT_DIR/output"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,11p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

# Verify template
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "ERROR: template directory not found: $TEMPLATE_DIR" >&2
  exit 1
fi

# Block destructive overwrites unless explicit
if [ -d "$TARGET_DIR" ]; then
  echo "ERROR: target already exists: $TARGET_DIR" >&2
  echo "       Run reset-fixture.sh để xóa + re-build." >&2
  exit 1
fi

echo "[build-fixture] Copying template → $TARGET_DIR ..."
mkdir -p "$TARGET_DIR"
cp -R "$TEMPLATE_DIR/." "$TARGET_DIR/"

echo "[build-fixture] Init git repo ..."
(
  cd "$TARGET_DIR"
  git init -q
  git add -A
  git -c user.email="bench@mcv3.local" -c user.name="MCV3 Benchmark" \
      commit -q -m "Initial benchmark fixture commit (15 bugs injected)"
)

# Verify counts (unique BUG IDs)
EXPECTED_BUGS=$(grep -hoE "BUG-[A-Z]+[0-9]+" "$TEMPLATE_DIR"/src/**/*.ts 2>/dev/null | sort -u | wc -l)
SOURCE_BUGS=$(grep -hoE "BUG-[A-Z]+[0-9]+" "$TARGET_DIR"/src/**/*.ts 2>/dev/null | sort -u | wc -l)

cat <<EOF

[build-fixture] DONE
================================================================
Target path     : $TARGET_DIR
Source files    : $(find "$TARGET_DIR/src/" -name "*.ts" | wc -l)
Unique BUG IDs  : $SOURCE_BUGS (expected: $EXPECTED_BUGS from template)
Modules         : sales, crm, finance
================================================================

Next steps:
  1. cd $TARGET_DIR
  2. Run /wf-fix-bugs --profile=exhaustive --scope=all --no-browser
  3. Verify: jq '.issues | length' .mc-data/work/wf-fix-bugs/sessions/*/phase5-triage/issue-registry.json
  4. After benchmark: cd back và run reset-fixture.sh để start fresh

EOF
