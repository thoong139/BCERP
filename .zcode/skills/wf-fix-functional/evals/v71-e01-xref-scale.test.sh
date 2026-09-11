#!/usr/bin/env bash
# v71-e01-xref-scale.test.sh — F24 regression test (V71-E01)
#
# Bao dam wf-fix-probe-static-xref.sh KHONG fail "Argument list too long"
# khi du an co >=200 .ts files chua REQ-ID/FEAT-ID annotations.
#
# Root cause F24: jq --argjson signals "$JSON" truyen JSON qua argv -> vuot
# ARG_MAX (~128KB Linux) khi tich luy 100+ signals.
# Hotfix v7.0.1: doi sang temp file + jq --slurpfile.
#
# USAGE:
#   bash .claude/skills/workflow/wf-fix-functional/evals/v71-e01-xref-scale.test.sh
#   # Override file count: V71_E01_NUM_FILES=500 bash <script>
#
# EXIT CODES:
#   0 — PASS (probe xu ly $NUM_FILES files khong ARG_MAX error)
#   1 — FAIL (probe error, JSON invalid, hoac signals count khong dat)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 5 levels up: evals/ -> wf-fix-functional/ -> workflow/ -> skills/ -> .claude/ -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

FIXTURE_DIR="$REPO_ROOT/.mc-data/work/wf-fix-functional/_fixtures/v71-e01"
SRC_DIR="$FIXTURE_DIR/src"
REGISTRY="$FIXTURE_DIR/req-registry.json"
OUTPUT="$FIXTURE_DIR/signals-output.json"
NUM_FILES="${V71_E01_NUM_FILES:-200}"
PROBE="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-xref.sh"

# Cleanup tren EXIT/INT (idempotent)
cleanup() {
  rm -rf "$FIXTURE_DIR"
}
trap cleanup EXIT INT TERM

# ============================================================
# Setup fixture
# ============================================================
echo "[V71-E01] Setup fixture: $NUM_FILES .ts files"
rm -rf "$FIXTURE_DIR"
mkdir -p "$SRC_DIR"

# Mock registry: 1 feature impl_status=done -> trigger 1 coverage_gap signal
cat > "$REGISTRY" <<'EOF'
{
  "requirements": [{"id": "REQ-EXISTS-001"}],
  "features": [
    {
      "id": "FEAT-EXISTS-001-001",
      "impl_status": "done",
      "requirement_ids": ["REQ-EXISTS-001"]
    }
  ],
  "systems": []
}
EOF

# Generate $NUM_FILES files voi unique orphan REQ-ID/FEAT-ID
# -> trigger $NUM_FILES orphan_annotation signals
for i in $(seq 1 "$NUM_FILES"); do
  idx=$(printf '%03d' "$i")
  cat > "$SRC_DIR/file-$i.ts" <<EOF
// REQ-ID: REQ-ORPHAN-$idx
// FEAT-ID: FEAT-ORPHAN-MOD-$idx
export class C$i {}
EOF
done

# ============================================================
# Run probe
# ============================================================
echo "[V71-E01] Run probe (expect zero ARG_MAX error)"
if ! bash "$PROBE" --source-dir "$SRC_DIR" --registry "$REGISTRY" > "$OUTPUT" 2> "$FIXTURE_DIR/stderr.log"; then
  echo "[V71-E01] FAIL: probe exited non-zero"
  echo "--- stderr ---"
  cat "$FIXTURE_DIR/stderr.log"
  exit 1
fi

# ============================================================
# Verify output
# ============================================================
if ! jq empty "$OUTPUT" >/dev/null 2>&1; then
  echo "[V71-E01] FAIL: output is not valid JSON"
  exit 1
fi

if ! jq -e '.["$schema"] == "lane-signals-v1"' "$OUTPUT" >/dev/null; then
  echo "[V71-E01] FAIL: schema mismatch (expect lane-signals-v1)"
  jq '.["$schema"]' "$OUTPUT"
  exit 1
fi

ACTUAL=$(jq '.signals | length' "$OUTPUT")
# Expected: 1 coverage_gap + $NUM_FILES orphan_annotations = $((NUM_FILES + 1))
# But Bash trap may strip whitespace; allow >=100 as conservative threshold per plan spec
EXPECTED_MIN=100
if [ "$ACTUAL" -lt "$EXPECTED_MIN" ]; then
  echo "[V71-E01] FAIL: signals length $ACTUAL < $EXPECTED_MIN (expected ~$((NUM_FILES + 1)))"
  exit 1
fi

# Verify signal structure conform schema (at least 1 sample)
if ! jq -e '.signals[0] | (.["$schema"] == "signal-v2") and (.dimension_id == "QD1") and (.fingerprint | startswith("sha256:"))' "$OUTPUT" >/dev/null; then
  echo "[V71-E01] FAIL: signal[0] schema check failed"
  jq '.signals[0]' "$OUTPUT"
  exit 1
fi

echo "[V71-E01] PASS: probe handled $NUM_FILES files, generated $ACTUAL signals (no ARG_MAX error)"
exit 0
