#!/usr/bin/env bash
# QD1 fixture runner — invoke wf-fix-probe-static-xref.sh, capture signals.
#
# USAGE:
#   bash run.sh [QD1]               # run probe + dump signals to .actual-signals.json
#   bash run.sh QD1 --dry-run       # validate setup only, không invoke probe
#
# Phase 3 scope:
#   Phiên 6 — live_detectable signals từ P-QD1-req-registry-xref trên positive/.
#   Phiên 7 — bổ sung 5 negative cases (FP-001..FP-005 reproduction targets).
#            scan-scope mở rộng: $FIXTURE_DIR (đệ quy positive/ + negative/).
#            Documented_gap signals (route-config-parse, deep-ui-traversal, …)
#            vẫn KHÔNG đo được vì 6/7 probe QD1 chưa có bash script độc lập.

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIM="${1:-QD1}"
DRY_RUN="${2:-}"

# ============================================================
# Step 0: Preflight
# ============================================================
echo "[run.sh] QD1 fixture — phase 3 (live probe = static-xref only)"
echo "[run.sh] FIXTURE_DIR=$FIXTURE_DIR"

REGISTRY="$FIXTURE_DIR/.mc-data/docs/_meta/req-registry.json"
# Phiên 7: scan toàn fixture root → đệ quy positive/ + negative/.
# Probe `find` với extension whitelist (.ts .tsx .js .jsx .py .java .cs .go .rs)
# nên .md/.json/.sh trong root tự động bị skip.
SOURCE_DIR="$FIXTURE_DIR"
EXPECTED="$FIXTURE_DIR/expected-signals.json"

# Validate fixture artifacts
for f in "$REGISTRY" "$EXPECTED"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: missing $f" >&2
    exit 1
  fi
done

if ! jq -e '.' "$REGISTRY" >/dev/null 2>&1; then
  echo "ERROR: invalid registry JSON" >&2
  exit 1
fi

if ! jq -e '.signals | length >= 10' "$EXPECTED" >/dev/null 2>&1; then
  echo "ERROR: expected-signals.json must have >= 10 signals" >&2
  exit 1
fi

# Locate probe script
PROBE_SCRIPT=""
for candidate in \
  "$FIXTURE_DIR/../../../../.claude/scripts/wf-fix-probe-static-xref.sh" \
  "$FIXTURE_DIR/../../../../../.claude/scripts/wf-fix-probe-static-xref.sh"; do
  if [ -f "$candidate" ]; then
    PROBE_SCRIPT="$(cd "$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    break
  fi
done

if [ -z "$PROBE_SCRIPT" ]; then
  REPO_ROOT="$(cd "$FIXTURE_DIR" && git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-xref.sh" ]; then
    PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-xref.sh"
  fi
fi

if [ -z "$PROBE_SCRIPT" ] || [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-xref.sh" >&2
  exit 1
fi

echo "[run.sh] PROBE_SCRIPT=$PROBE_SCRIPT"
echo "[run.sh] REGISTRY=$REGISTRY"
echo "[run.sh] SOURCE_DIR=$SOURCE_DIR"
echo "[run.sh] EXPECTED=$EXPECTED ($(jq '.signals | length' "$EXPECTED") expectations)"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[run.sh] --dry-run mode → exit 0 (preflight passed)"
  exit 0
fi

# ============================================================
# Step 1: Invoke probe
# ============================================================
SESSION_DIR="$(mktemp -d -t qd1-fixture-XXXXXX)"
ACTUAL_SIGNALS="$FIXTURE_DIR/.actual-signals.json"

trap 'rm -rf "$SESSION_DIR"' EXIT

echo "[run.sh] Invoking probe..."
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-req-registry-xref" \
  --profile "standard" \
  --source-dir "$SOURCE_DIR" \
  --registry "$REGISTRY" \
  > "$ACTUAL_SIGNALS"

# ============================================================
# Step 2: Validate output
# ============================================================
if ! jq -e '.signals' "$ACTUAL_SIGNALS" >/dev/null 2>&1; then
  echo "ERROR: probe output không có .signals key" >&2
  cat "$ACTUAL_SIGNALS" >&2
  exit 1
fi

ACTUAL_COUNT="$(jq '.signals | length' "$ACTUAL_SIGNALS")"
echo "[run.sh] Probe emitted $ACTUAL_COUNT signal(s) → $ACTUAL_SIGNALS"
echo "[run.sh] Signals breakdown:"
jq -r '.signals[] | "  - " + .severity + " | " + ((.registry_refs.feat_ids // .registry_refs.req_ids // []) | tostring) + " | " + (.title // "no-title")' "$ACTUAL_SIGNALS" 2>/dev/null || true

# ============================================================
# Step 3: Accuracy summary (Phiên 7)
# ============================================================
echo ""
echo "[run.sh] Phiên 7 accuracy: xem accuracy-report.md."
echo "[run.sh] Quick check — kỳ vọng signals KHÔNG thay đổi so với Phiên 6 (5 signals match)"
echo "[run.sh] vì negative cases dùng REQ/FEAT-IDs hợp lệ hoặc file extensions ngoài whitelist."

exit 0
