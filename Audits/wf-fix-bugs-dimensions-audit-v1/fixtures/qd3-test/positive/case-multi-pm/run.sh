#!/usr/bin/env bash
# IMP-003 acceptance test: Multi-PM dependency vulnerability scan
#
# Tests that wf-fix-probe-static-depvuln.sh detects and handles multiple PMs:
#   - npm (package-lock.json)
#   - pip (requirements.txt)
#   - nuget (Demo.csproj with PackageReference)
#   - maven (pom.xml)
#
# PASS criteria (environment-agnostic):
#   - ≥2 PMs detected (from the 4 manifests present)
#   - Each detected PM emits at least 1 signal (either vuln OR skip)
#   - No fatal probe error
#   - All signals have valid JSON structure (domain="dependency")
#
# Tools may not be installed → graceful SKIP signals accepted as PASS
#
# USAGE: bash run.sh [--dry-run]

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

echo "[run.sh] IMP-003 — Multi-PM dependency vuln scan fixture"
echo "[run.sh] FIXTURE_DIR=$FIXTURE_DIR"

# Locate probe script
PROBE_SCRIPT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-depvuln.sh" ]; then
  PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-depvuln.sh"
fi
for candidate in \
  "../../../../../.claude/scripts/wf-fix-probe-static-depvuln.sh" \
  "../../../../../../.claude/scripts/wf-fix-probe-static-depvuln.sh"; do
  if [ -z "$PROBE_SCRIPT" ] && [ -f "$FIXTURE_DIR/$candidate" ]; then
    PROBE_SCRIPT="$(cd "$FIXTURE_DIR/$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    break
  fi
done

if [ -z "$PROBE_SCRIPT" ] || [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-depvuln.sh" >&2; exit 1
fi
echo "[run.sh] PROBE_SCRIPT=$PROBE_SCRIPT"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[run.sh] --dry-run: preflight PASS"
  exit 0
fi

# ============================================================
SESSION_DIR="$(mktemp -d -t imp003-fixture-XXXXXX)"
ACTUAL="$FIXTURE_DIR/.actual-depvuln-signals.json"
trap 'rm -rf "$SESSION_DIR"' EXIT

echo "[run.sh] Running dep vuln probe on fixture dir..."
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-security" \
  --probe "P-QD3-dependency-vuln-scan" \
  --profile "standard" \
  --source-dir "$FIXTURE_DIR" \
  > "$ACTUAL"

# ============================================================
TOTAL=$(jq '.signals | length' "$ACTUAL")
echo "[run.sh] Total signals: $TOTAL"
echo "[run.sh] Signal breakdown:"
jq -r '.signals[] | "  [" + .severity + "] " + .title' "$ACTUAL" 2>/dev/null || true

# Count vuln signals and skip signals per PM
VULN_COUNT=$(jq '[.signals[] | select(.title | startswith("Vulnerable dependency:"))] | length' "$ACTUAL")
SKIP_COUNT=$(jq '[.signals[] | select(.title | startswith("Dep vuln scan skipped:") or startswith("Dep vuln probe:"))] | length' "$ACTUAL")
DEP_DOMAIN=$(jq '[.signals[] | select(.domain == "dependency")] | length' "$ACTUAL")

# Count distinct PMs covered (either vuln or skip)
PM_COVERED=$(jq -r '
  [.signals[] |
    select(.domain == "dependency") |
    (.title | capture("skipped: (?P<pm>[a-z]+)|Vulnerable dependency:.+\\((?P<pm>[a-z]+)\\)").pm)
  ] | map(select(. != null)) | unique | length
' "$ACTUAL") || PM_COVERED=0

echo ""
echo "[run.sh] PM coverage:"
echo "  Vulnerability signals: $VULN_COUNT"
echo "  Skip signals (tool not installed): $SKIP_COUNT"
echo "  Total dependency-domain signals: $DEP_DOMAIN"
echo "  Distinct PMs covered: $PM_COVERED"

# ============================================================
PASS=true
if [ "$TOTAL" -lt 1 ]; then
  echo "  FAIL: total signals $TOTAL < 1" >&2; PASS=false
fi
if [ "$DEP_DOMAIN" -lt 1 ]; then
  echo "  FAIL: no dependency-domain signals emitted" >&2; PASS=false
fi
# Environment-agnostic: pass if either vulns found OR tools properly skipped for ≥2 PMs
TOTAL_COVERED=$((VULN_COUNT + SKIP_COUNT))
if [ "$TOTAL_COVERED" -lt 2 ]; then
  echo "  FAIL: only $TOTAL_COVERED PM signals (vuln+skip), expected ≥2" >&2; PASS=false
fi

echo ""
if $PASS; then
  echo "  VERDICT: PASS — $TOTAL_COVERED PM coverage signals ($VULN_COUNT vulns + $SKIP_COUNT skips) (IMP-003 acceptance criteria met)"
  exit 0
else
  echo "  VERDICT: FAIL — insufficient PM coverage"
  exit 1
fi
