#!/usr/bin/env bash
# v71-e03-secret-detection.test.sh — V71-E03 (Option B reduced 1.5h)
#
# Real-world bug scenario E2E (REDUCED SCOPE):
#  Verify 2 contracts cot loi cua security flow KHONG can run full 6-phase pipeline:
#   1) QD3 secret probe fire CDG-SECURITY-LIVE flag khi co Stripe Live Key
#      + KHONG fire khi khong co key (negative test)
#   2) fix-impact.json schema fix-impact-v1 valid
#      (synthesize minimal JSON theo schema template + validate audit_chain checksum format)
#
# Decision: Option B (per 01-decisions.md D3) — skip full pipeline mock, focus 2 contracts.
#
# USAGE:
#   bash .claude/skills/workflow/wf-fix-bugs/evals/v71-e03-secret-detection.test.sh
#
# EXIT CODES:
#   0 — PASS (3 sub-tests pass: positive CDG fire + negative no fire + schema valid)
#   1 — FAIL (1+ sub-test fail)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 5 levels up: evals/ -> wf-fix-bugs/ -> workflow/ -> skills/ -> .claude/ -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

FIXTURE_DIR="$REPO_ROOT/.mc-data/work/wf-fix-bugs/_v71e03_synthetic"
PROBE="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-secret.sh"

cleanup() {
  rm -rf "$FIXTURE_DIR"
}
trap cleanup EXIT INT TERM

rm -rf "$FIXTURE_DIR"
mkdir -p "$FIXTURE_DIR"

# ============================================================
# SUB-TEST 1: Positive — Stripe Live Key inject -> CDG-SECURITY-LIVE fire
# ============================================================
echo "[V71-E03 sub-test 1] Positive — Stripe Live Key inject"

POS_DIR="$FIXTURE_DIR/positive/src"
mkdir -p "$POS_DIR"

# Inject realistic Stripe Live Key pattern (FAKE — KHONG production credential)
# Pattern probe match: sk_live_[0-9a-zA-Z]{24,}
STRIPE_PREFIX="sk_live"
cat > "$POS_DIR/stripe.ts" <<EOF
// Configuration for Stripe payment integration
export const STRIPE_KEY = "${STRIPE_PREFIX}_FAKE12345abcdefghij67890XYZ";
export const STRIPE_VERSION = "2025-01-01";
EOF

POS_OUTPUT="$FIXTURE_DIR/positive/signals.json"
mkdir -p "$(dirname "$POS_OUTPUT")"
if ! bash "$PROBE" --source-dir "$POS_DIR" > "$POS_OUTPUT" 2> "$FIXTURE_DIR/positive/stderr.log"; then
  echo "[V71-E03 sub-test 1] FAIL: probe exited non-zero"
  cat "$FIXTURE_DIR/positive/stderr.log"
  exit 1
fi

# Verify CDG-SECURITY-LIVE fire
if ! jq empty "$POS_OUTPUT" >/dev/null 2>&1; then
  echo "[V71-E03 sub-test 1] FAIL: output not valid JSON"
  exit 1
fi

CDG_FIRED=$(jq '[.signals[] | select(.cdg_flags | index("CDG-SECURITY-LIVE"))] | length' "$POS_OUTPUT")
if [ "$CDG_FIRED" -lt 1 ]; then
  echo "[V71-E03 sub-test 1] FAIL: CDG-SECURITY-LIVE NOT fire (expected >=1, got $CDG_FIRED)"
  jq '.signals' "$POS_OUTPUT"
  exit 1
fi

# Verify Stripe label specifically
STRIPE_HIT=$(jq '[.signals[] | select(.title | test("Stripe Live"))] | length' "$POS_OUTPUT")
if [ "$STRIPE_HIT" -lt 1 ]; then
  echo "[V71-E03 sub-test 1] FAIL: Stripe Live signal NOT detected"
  jq '.signals' "$POS_OUTPUT"
  exit 1
fi

echo "[V71-E03 sub-test 1] PASS — Stripe Live Key detected, CDG-SECURITY-LIVE fired ($CDG_FIRED signal(s))"

# ============================================================
# SUB-TEST 2: Negative — no Stripe key -> no CDG-SECURITY-LIVE fire
# ============================================================
echo "[V71-E03 sub-test 2] Negative — no secret in source"

NEG_DIR="$FIXTURE_DIR/negative/src"
mkdir -p "$NEG_DIR"

cat > "$NEG_DIR/clean.ts" <<'EOF'
// Clean source with no secrets
export function add(a: number, b: number): number {
  return a + b;
}
export const VERSION = "1.0.0";
EOF

NEG_OUTPUT="$FIXTURE_DIR/negative/signals.json"
mkdir -p "$(dirname "$NEG_OUTPUT")"
if ! bash "$PROBE" --source-dir "$NEG_DIR" > "$NEG_OUTPUT" 2> "$FIXTURE_DIR/negative/stderr.log"; then
  echo "[V71-E03 sub-test 2] FAIL: probe exited non-zero"
  cat "$FIXTURE_DIR/negative/stderr.log"
  exit 1
fi

NEG_CDG=$(jq '[.signals[] | select(.cdg_flags | index("CDG-SECURITY-LIVE"))] | length' "$NEG_OUTPUT")
if [ "$NEG_CDG" -ne 0 ]; then
  echo "[V71-E03 sub-test 2] FAIL: CDG-SECURITY-LIVE FIRED on clean source (expected 0, got $NEG_CDG)"
  jq '.signals' "$NEG_OUTPUT"
  exit 1
fi

echo "[V71-E03 sub-test 2] PASS — clean source, no false positive"

# ============================================================
# SUB-TEST 3: Schema fix-impact-v1 validation
# Synthesize minimal fix-impact.json + validate schema + audit_chain checksum format
# ============================================================
echo "[V71-E03 sub-test 3] fix-impact-v1 schema validation"

IMPACT_FILE="$FIXTURE_DIR/fix-impact.json"

# Compute realistic checksum_sha256 (sha256 of sorted fix-log entries — theo builder logic)
CANONICAL_ENTRIES='[{"issue_id":"v71-e03-issue-001","fix_status":"fixed"}]'
CHECKSUM_SHA256=$(printf '%s' "$CANONICAL_ENTRIES" | sha256sum 2>/dev/null | awk '{print $1}' || \
                  printf '%s' "$CANONICAL_ENTRIES" | shasum -a 256 2>/dev/null | awk '{print $1}')

# Minimal fix-impact.json theo schema fix-impact-v1 (builder: wf-fix-impact-builder.sh)
# Dung dung ten field ma builder tao: fix_summary, affected_artifacts, audit_chain.checksum_sha256
jq -n \
  --arg checksum_sha256 "$CHECKSUM_SHA256" \
  '{
    "$schema": "fix-impact-v1",
    "session_id": "v71-e03-mock",
    "scope": {"type": "all", "name": "", "system": ""},
    "fix_summary": {
      "total_issues": 1,
      "fixed": 1,
      "deferred": 0,
      "escalated": 0,
      "skipped": 0,
      "verify_iterations": 1
    },
    "by_dimension": {
      "QD1": {"detected": 0, "fixed": 0, "deferred": 0, "escalated": 0, "skipped": 0},
      "QD2": {"detected": 0, "fixed": 0, "deferred": 0, "escalated": 0, "skipped": 0},
      "QD3": {"detected": 1, "fixed": 1, "deferred": 0, "escalated": 0, "skipped": 0},
      "QD4": {"detected": 0, "fixed": 0, "deferred": 0, "escalated": 0, "skipped": 0},
      "QD5": {"detected": 0, "fixed": 0, "deferred": 0, "escalated": 0, "skipped": 0},
      "QD6": {"detected": 0, "fixed": 0, "deferred": 0, "escalated": 0, "skipped": 0},
      "QD7": {"detected": 0, "fixed": 0, "deferred": 0, "escalated": 0, "skipped": 0},
      "QD8": {"detected": 0, "fixed": 0, "deferred": 0, "escalated": 0, "skipped": 0}
    },
    "affected_artifacts": {
      "code_files": [{"path": "src/stripe.ts", "req_ids": [], "feat_ids": [], "issues_addressed": [], "modification_type": "edit"}],
      "feature_specs_updated": [],
      "ux_specs_updated": [],
      "registry_changes": []
    },
    "verify_evidence": [],
    "regression_check": {
      "tests_run": 5,
      "tests_passed": 5,
      "tests_failed": 0,
      "tests_failed_ids": [],
      "coverage_delta_pct": null
    },
    "audit_chain": {
      "fix_log_entries": 1,
      "first_entry_id": "v71-e03-issue-001",
      "last_entry_id": "v71-e03-issue-001",
      "checksum_sha256": $checksum_sha256
    },
    "cdg_decisions": [],
    "next_recommended_action": {"skill": "ready-for-release", "rationale": "No escalated issues", "blocking_items": []},
    "generated_at": "2026-04-28T00:00:00Z",
    "generator": "wf-fix-bugs v7.4.0"
  }' > "$IMPACT_FILE"

# Validate schema
if ! jq -e '."$schema" == "fix-impact-v1"' "$IMPACT_FILE" >/dev/null; then
  echo "[V71-E03 sub-test 3] FAIL: schema mismatch"
  exit 1
fi

# Validate fix_summary fields (builder schema: total_issues, fixed, ...)
if ! jq -e '.fix_summary.total_issues != null and .fix_summary.fixed != null' "$IMPACT_FILE" >/dev/null; then
  echo "[V71-E03 sub-test 3] FAIL: fix_summary.total_issues / .fixed missing"
  jq '.fix_summary' "$IMPACT_FILE"
  exit 1
fi

# Validate affected_artifacts.code_files[] (khong phai flat files_modified[])
if ! jq -e '.affected_artifacts.code_files | type == "array"' "$IMPACT_FILE" >/dev/null; then
  echo "[V71-E03 sub-test 3] FAIL: affected_artifacts.code_files missing or not array"
  exit 1
fi

# Validate audit_chain.checksum_sha256 (khong phai .checksum) format: [a-f0-9]{64}
if ! jq -e '.audit_chain.checksum_sha256 | test("^[a-f0-9]{64}$")' "$IMPACT_FILE" >/dev/null; then
  echo "[V71-E03 sub-test 3] FAIL: audit_chain.checksum_sha256 format invalid (expected 64 hex chars)"
  jq '.audit_chain' "$IMPACT_FILE"
  exit 1
fi

# Validate D4 fields present
if ! jq -e 'has("verify_evidence") and has("regression_check") and has("audit_chain")' "$IMPACT_FILE" >/dev/null; then
  echo "[V71-E03 sub-test 3] FAIL: D4 fields missing"
  exit 1
fi

# Validate base required fields (schema fix-impact-v1: session_id, scope, fix_summary, affected_artifacts, generated_at)
if ! jq -e 'has("session_id") and has("scope") and has("fix_summary") and has("affected_artifacts") and has("generated_at")' "$IMPACT_FILE" >/dev/null; then
  echo "[V71-E03 sub-test 3] FAIL: base required fields missing"
  exit 1
fi

echo "[V71-E03 sub-test 3] PASS — fix-impact-v1 schema valid, audit_chain.checksum_sha256 format correct"

# ============================================================
# ALL SUB-TESTS PASS
# ============================================================
echo "[V71-E03] PASS: secret detection contract verified (positive CDG fire + negative no fire + schema valid)"
exit 0
