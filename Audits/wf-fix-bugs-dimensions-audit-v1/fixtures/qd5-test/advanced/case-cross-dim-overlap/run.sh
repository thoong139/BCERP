#!/usr/bin/env bash
# IMP-012 acceptance test — case-cross-dim-overlap/
#
# Tests the dedup_signals() function in wf-fix-common.sh:
#   1. Two identical signals (same file, line, issue_class) → merged to 1
#   2. Merged signal has highest severity
#   3. Merged signal has dedup_sources listing both probe IDs
#   4. Non-duplicate signals remain unchanged
#   5. Signal count: 2 pairs → 2 merged + 1 unique = 3 total (not 5)
#
# VERDICT: PASS if deduplication reduces 5 signals to 3

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-cross-dim-overlap] IMP-012 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

COMMON_SH="$REPO_ROOT/.claude/scripts/wf-fix-common.sh"
if [ ! -f "$COMMON_SH" ]; then
  echo "FAIL: wf-fix-common.sh not found at $COMMON_SH" >&2
  exit 1
fi
source "$COMMON_SH"
echo "[case-cross-dim-overlap] Sourced: $COMMON_SH"

# ============================================================
# Build test signal set:
#   Signal A1: probe QD1, file=Button.tsx, line=42, issue=img_no_alt, HIGH
#   Signal A2: probe QD5, file=Button.tsx, line=42, issue=img_no_alt, MEDIUM (duplicate of A1)
#   Signal B1: probe QD1, file=Form.tsx, line=17, issue=input_no_label, MEDIUM
#   Signal B2: probe QD5, file=Form.tsx, line=17, issue=input_no_label, MEDIUM (duplicate of B1)
#   Signal C1: probe QD5, file=Nav.tsx, line=3, issue=href_anti_pattern, LOW (unique)
#
# Expected after dedup: 3 signals (A_merged HIGH, B_merged MEDIUM, C1 unchanged)
# ============================================================

SIGNALS=$(jq -nc '
[
  {
    "$schema": "signal-v2",
    "probe_id": "P-QD1-orphan-ui-detect",
    "severity": "high",
    "title": "Image missing alt text",
    "location": {"file": "Button.tsx", "line": 42},
    "evidence": [{"type": "code", "path": "Button.tsx", "description": "img without alt"}],
    "issue_class": "img_no_alt",
    "tags": ["ui", "a11y"]
  },
  {
    "$schema": "signal-v2",
    "probe_id": "P-QD5-img-alt-audit",
    "severity": "medium",
    "title": "Image missing alt text",
    "location": {"file": "Button.tsx", "line": 42},
    "evidence": [{"type": "code", "path": "Button.tsx", "description": "img without alt attr"}],
    "issue_class": "img_no_alt",
    "tags": ["a11y"]
  },
  {
    "$schema": "signal-v2",
    "probe_id": "P-QD1-static-xref",
    "severity": "medium",
    "title": "Input missing label",
    "location": {"file": "Form.tsx", "line": 17},
    "evidence": [{"type": "code", "path": "Form.tsx", "description": "input without label"}],
    "issue_class": "input_no_label",
    "tags": ["ui"]
  },
  {
    "$schema": "signal-v2",
    "probe_id": "P-QD5-input-label-audit",
    "severity": "medium",
    "title": "Input missing accessible label",
    "location": {"file": "Form.tsx", "line": 17},
    "evidence": [{"type": "code", "path": "Form.tsx", "description": "input no label"}],
    "issue_class": "input_no_label",
    "tags": ["a11y"]
  },
  {
    "$schema": "signal-v2",
    "probe_id": "P-QD5-img-alt-audit",
    "severity": "low",
    "title": "Anchor with javascript: href",
    "location": {"file": "Nav.tsx", "line": 3},
    "evidence": [{"type": "code", "path": "Nav.tsx", "description": "href=javascript:void(0)"}],
    "issue_class": "href_anti_pattern",
    "tags": ["a11y"]
  }
]
')

# ============================================================
# Test 1: Run dedup_signals
# ============================================================
echo ""
echo "--- Test 1: dedup_signals reduces 5 → 3 ---"
DEDUPED=$(dedup_signals "$SIGNALS")
ORIGINAL_COUNT=$(echo "$SIGNALS" | jq 'length')
DEDUPED_COUNT=$(echo "$DEDUPED" | jq 'length')

echo "  Original: $ORIGINAL_COUNT signals"
echo "  Deduped:  $DEDUPED_COUNT signals"

if [ "$DEDUPED_COUNT" -ne 3 ]; then
  echo "  FAIL: expected 3 signals after dedup, got $DEDUPED_COUNT"
  echo "$DEDUPED" | jq -r '.[] | "  [" + .severity + "] " + .issue_class + " @ " + .location.file + ":" + (.location.line | tostring)'
  exit 1
fi
echo "  PASS: $DEDUPED_COUNT signals after dedup"

# ============================================================
# Test 2: Merged signal has highest severity
# ============================================================
echo ""
echo "--- Test 2: Merged signal severity = highest ---"
img_sev=$(echo "$DEDUPED" | jq -r '[.[] | select(.issue_class == "img_no_alt")] | .[0].severity // ""')
if [ "$img_sev" = "high" ]; then
  echo "  PASS: img_no_alt severity = high (from QD1, beats QD5 medium)"
else
  echo "  FAIL: img_no_alt severity = $img_sev (expected: high)"
  exit 1
fi

# ============================================================
# Test 3: Merged signal has dedup_sources
# ============================================================
echo ""
echo "--- Test 3: Merged signal has dedup_sources ---"
sources=$(echo "$DEDUPED" | jq -r '[.[] | select(.issue_class == "img_no_alt")] | .[0].dedup_sources | length')
if [ "${sources:-0}" -ge 2 ]; then
  probes=$(echo "$DEDUPED" | jq -r '[.[] | select(.issue_class == "img_no_alt")] | .[0].dedup_sources | join(", ")')
  echo "  PASS: dedup_sources has $sources probes: $probes"
else
  echo "  FAIL: dedup_sources missing or < 2 entries (got: $sources)"
  exit 1
fi

# ============================================================
# Test 4: Unique signal unchanged
# ============================================================
echo ""
echo "--- Test 4: Unique signal (href_anti_pattern) unchanged ---"
unique_count=$(echo "$DEDUPED" | jq '[.[] | select(.issue_class == "href_anti_pattern")] | length')
unique_sev=$(echo "$DEDUPED" | jq -r '[.[] | select(.issue_class == "href_anti_pattern")] | .[0].severity // ""')
if [ "$unique_count" -eq 1 ] && [ "$unique_sev" = "low" ]; then
  echo "  PASS: href_anti_pattern: 1 signal, severity=low (unchanged)"
else
  echo "  FAIL: href_anti_pattern count=$unique_count severity=$unique_sev"
  exit 1
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  5 → $DEDUPED_COUNT signals (dedup: 2 pairs merged)"
echo "  Severity merge: HIGH wins over MEDIUM"
echo "  dedup_sources: probe attribution preserved"
echo "  Unique signals: unchanged"
exit 0
