#!/usr/bin/env bash
# IMP-004 + IMP-005 acceptance test: Configurable thresholds + MAX_PAGES per profile
#
# Tests that wf-fix-probe-static-cta.sh:
#   1. With --profile quick (MAX_PAGES=10): scans 10 of 15 files → WARN truncation signal
#   2. With --profile standard (MAX_PAGES=30): scans all 15 → no truncation
#   3. With --threshold-overrides '{"max_pages":5}': scans 5 of 15 → WARN truncation
#
# Fixture: 15 TSX files (page1.tsx..page15.tsx) each with "Submit" CTA button
#
# PASS criteria:
#   - quick profile: truncation WARN signal present, severity=warn
#   - standard profile: no truncation WARN, CTA signals ≥1
#   - threshold-overrides max_pages=5: truncation WARN with total=15 in description
#
# USAGE: bash run.sh [--dry-run]

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

echo "[run.sh] IMP-004+005 — Configurable thresholds + MAX_PAGES fixture"
echo "[run.sh] FIXTURE_DIR=$FIXTURE_DIR"

# Locate probe script
PROBE_SCRIPT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-cta.sh" ]; then
  PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-cta.sh"
fi
for candidate in \
  "../../../../../.claude/scripts/wf-fix-probe-static-cta.sh" \
  "../../../../../../.claude/scripts/wf-fix-probe-static-cta.sh"; do
  if [ -z "$PROBE_SCRIPT" ] && [ -f "$FIXTURE_DIR/$candidate" ]; then
    PROBE_SCRIPT="$(cd "$FIXTURE_DIR/$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    break
  fi
done

if [ -z "$PROBE_SCRIPT" ] || [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-cta.sh" >&2; exit 1
fi
echo "[run.sh] PROBE_SCRIPT=$PROBE_SCRIPT"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[run.sh] --dry-run: preflight PASS"
  exit 0
fi

# Validate that profiles.json has thresholds (IMP-004)
REPO_ROOT_CHECK="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT_CHECK" ]; then
  PROFILES_JSON="$REPO_ROOT_CHECK/.claude/skills/workflow/_shared/profiles/profiles.json"
  if [ -f "$PROFILES_JSON" ]; then
    QUICK_MAX=$(jq -r '.profiles.quick.thresholds.max_pages // empty' "$PROFILES_JSON" 2>/dev/null || true)
    if [ -z "$QUICK_MAX" ]; then
      echo "  FAIL: profiles.json missing .profiles.quick.thresholds.max_pages (IMP-004 not applied)" >&2
      exit 1
    fi
    echo "[run.sh] profiles.json quick.thresholds.max_pages=$QUICK_MAX (IMP-004 ✓)"
  fi
fi

SESSION_DIR="$(mktemp -d -t imp005-fixture-XXXXXX)"
trap 'rm -rf "$SESSION_DIR"' EXIT

PASS=true

# ============================================================
# Test 1: quick profile → MAX_PAGES=10, fixture has 15 files → WARN
# ============================================================
echo ""
echo "[run.sh] Test 1: --profile quick (MAX_PAGES=10, fixture has 15 files)"
OUT1="$FIXTURE_DIR/.actual-quick.json"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-cta-keyword-scan" \
  --profile "quick" \
  --source-dir "$FIXTURE_DIR" \
  --locale "en" \
  > "$OUT1"

WARN_COUNT=$(jq '[.signals[] | select(.severity == "warn" and (.title | contains("MAX_PAGES")))] | length' "$OUT1")
echo "[run.sh]   truncation WARN signals: $WARN_COUNT"
jq -r '.signals[] | select(.severity == "warn") | "  [warn] " + .title' "$OUT1" 2>/dev/null || true

if [ "$WARN_COUNT" -lt 1 ]; then
  echo "  FAIL: expected ≥1 MAX_PAGES truncation WARN signal with quick profile" >&2; PASS=false
else
  echo "  PASS: truncation WARN emitted for quick profile"
fi

# ============================================================
# Test 2: standard profile → MAX_PAGES=30, 15 files → no truncation, has CTAs
# ============================================================
echo ""
echo "[run.sh] Test 2: --profile standard (MAX_PAGES=30, fixture has 15 files)"
OUT2="$FIXTURE_DIR/.actual-standard.json"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-cta-keyword-scan" \
  --profile "standard" \
  --source-dir "$FIXTURE_DIR" \
  --locale "en" \
  > "$OUT2"

WARN_COUNT2=$(jq '[.signals[] | select(.severity == "warn" and (.title | contains("MAX_PAGES")))] | length' "$OUT2")
CTA_COUNT2=$(jq '[.signals[] | select(.domain == "cta" and .severity == "info")] | length' "$OUT2")
echo "[run.sh]   truncation WARN: $WARN_COUNT2, CTA signals: $CTA_COUNT2"

if [ "$WARN_COUNT2" -gt 0 ]; then
  echo "  FAIL: unexpected truncation WARN with standard profile (30 ≥ 15 files)" >&2; PASS=false
else
  echo "  PASS: no truncation with standard profile"
fi
if [ "$CTA_COUNT2" -lt 1 ]; then
  echo "  FAIL: expected ≥1 CTA signal with standard profile" >&2; PASS=false
else
  echo "  PASS: CTA signals detected ($CTA_COUNT2)"
fi

# ============================================================
# Test 3: --threshold-overrides max_pages=5 → WARN, description has total=15
# ============================================================
echo ""
echo "[run.sh] Test 3: --threshold-overrides '{\"max_pages\":5}' (override to 5)"
OUT3="$FIXTURE_DIR/.actual-override.json"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-cta-keyword-scan" \
  --profile "standard" \
  --source-dir "$FIXTURE_DIR" \
  --locale "en" \
  --threshold-overrides '{"max_pages":5}' \
  > "$OUT3"

WARN_COUNT3=$(jq '[.signals[] | select(.severity == "warn" and (.title | contains("MAX_PAGES")))] | length' "$OUT3")
HAS_TOTAL=$(jq -r '[.signals[] | select(.severity == "warn") | .description] | any(contains("15"))' "$OUT3" 2>/dev/null || echo "false")
echo "[run.sh]   truncation WARN: $WARN_COUNT3, description mentions total=15: $HAS_TOTAL"

if [ "$WARN_COUNT3" -lt 1 ]; then
  echo "  FAIL: expected truncation WARN with max_pages=5 override" >&2; PASS=false
else
  echo "  PASS: truncation WARN with threshold-overrides"
fi
if [ "$HAS_TOTAL" != "true" ]; then
  echo "  FAIL: WARN signal description does not mention total file count 15" >&2; PASS=false
else
  echo "  PASS: WARN description mentions total=15"
fi

echo ""
if $PASS; then
  echo "  VERDICT: PASS — IMP-004+005 acceptance criteria met"
  exit 0
else
  echo "  VERDICT: FAIL — one or more checks failed"
  exit 1
fi
