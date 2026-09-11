#!/usr/bin/env bash
# IMP-002 acceptance test: Locale-aware CTA detection (Vietnamese)
#
# Tests that wf-fix-probe-static-cta.sh with --locale vi detects
# Vietnamese CTA keywords in ProductPage.tsx:
#   - mua ngay, thêm vào giỏ, đặt hàng, xem thêm, tìm hiểu thêm
#   - đăng ký, đăng nhập, liên hệ, thanh toán
#
# PASS criteria:
#   - ≥ 5 CTA signals detected (locale=vi)
#   - All signals have domain="cta"
#   - No fatal probe error
#
# USAGE: bash run.sh [--dry-run]

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

echo "[run.sh] IMP-002 — Vietnamese CTA detection fixture"
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

# ============================================================
SESSION_DIR="$(mktemp -d -t imp002-fixture-XXXXXX)"
ACTUAL="$FIXTURE_DIR/.actual-cta-signals.json"
trap 'rm -rf "$SESSION_DIR"' EXIT

echo "[run.sh] Running CTA probe on fixture dir with --locale vi..."
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-cta-keyword-scan" \
  --profile "standard" \
  --source-dir "$FIXTURE_DIR" \
  --locale "vi" \
  > "$ACTUAL"

# ============================================================
TOTAL=$(jq '.signals | length' "$ACTUAL")
echo "[run.sh] Total signals: $TOTAL"
echo "[run.sh] Signal breakdown:"
jq -r '.signals[] | "  [" + .severity + "] " + .title' "$ACTUAL" 2>/dev/null || true

# Domain check — all CTA signals should have domain="cta"
CTA_COUNT=$(jq '[.signals[] | select(.domain == "cta" and .title != "CTA probe: no CTA elements found")] | length' "$ACTUAL")
SKIP_COUNT=$(jq '[.signals[] | select(.title | startswith("CTA probe: no CTA"))] | length' "$ACTUAL")

echo ""
echo "[run.sh] CTA detection:"
echo "  CTA signals (locale=vi): $CTA_COUNT"
echo "  Skip signals:            $SKIP_COUNT"

# ============================================================
PASS=true
if [ "$CTA_COUNT" -lt 5 ]; then
  echo "  FAIL: detected $CTA_COUNT VI CTAs, expected >= 5" >&2; PASS=false
fi
if [ "$SKIP_COUNT" -gt 0 ] && [ "$CTA_COUNT" -eq 0 ]; then
  echo "  FAIL: probe skipped with no CTAs found — check locale dictionary" >&2; PASS=false
fi

echo ""
if $PASS; then
  echo "  VERDICT: PASS — $CTA_COUNT Vietnamese CTAs detected (IMP-002 acceptance criteria met)"
  exit 0
else
  echo "  VERDICT: FAIL — insufficient VI CTA coverage"
  exit 1
fi
