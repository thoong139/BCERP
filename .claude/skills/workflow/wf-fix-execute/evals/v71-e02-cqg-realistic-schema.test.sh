#!/usr/bin/env bash
# v71-e02-cqg-realistic-schema.test.sh — F26 regression test (V71-E02)
#
# Bao dam wf-fix-cqg-verify.sh count ACTUAL_FIXED dung theo schema fix-log-v1
# (KHONG co field fix_status/status o entry level).
#
# Root cause F26: script doc entries[].fix_status hoac entries[].status — ca 2
# fields KHONG ton tai trong schema chinh thuc fix-log-v1 -> ACTUAL_FIXED luon = 0
# -> moi run thuc te fail POST-GATE E001.
#
# Hotfix v7.0.1 (Option A+B):
#  - Primary: count `length(entries)` (1-to-1 voi fixed issues per batch3 §3.4)
#  - Fallback: `[.issues[] | select(.fix_status=="fixed")] | length` tu registry
#    khi entries rong.
#
# 2 SUB-TESTS:
#  1) Realistic schema: entries non-empty -> count length
#  2) Fallback: entries empty -> count tu registry, deferred KHONG count
#
# USAGE:
#   bash .claude/skills/workflow/wf-fix-execute/evals/v71-e02-cqg-realistic-schema.test.sh
#
# EXIT CODES:
#   0 — PASS (ca 2 sub-tests pass)
#   1 — FAIL (1+ sub-test fail)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 5 levels up: evals/ -> wf-fix-execute/ -> workflow/ -> skills/ -> .claude/ -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

FIXTURE_DIR="$REPO_ROOT/.mc-data/work/wf-fix-execute/_fixtures/v71-e02"
CQG_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-cqg-verify.sh"

cleanup() {
  rm -rf "$FIXTURE_DIR"
}
trap cleanup EXIT INT TERM

# ============================================================
# SUB-TEST 1: Realistic schema (entries non-empty)
# ============================================================
echo "[V71-E02 sub-test 1] Realistic schema — entries non-empty, no fix_status field"

SUBDIR1="$FIXTURE_DIR/sub1"
rm -rf "$SUBDIR1" && mkdir -p "$SUBDIR1"

# fix-log.json: 2 entries theo schema fix-log-v1 (KHONG co fix_status field)
cat > "$SUBDIR1/fix-log.json" <<'EOF'
{
  "$schema": "fix-log-v1",
  "session_id": "v71-e02-sub1",
  "entries": [
    {
      "entry_id": "fix-001",
      "issue_id": "ISS-001",
      "batch": 1,
      "iteration": 1,
      "agent": "developer",
      "files_modified": ["src/foo.ts", "src/bar.ts"],
      "summary": "Fix compile error",
      "timestamp": "2026-04-28T00:00:00Z"
    },
    {
      "entry_id": "fix-002",
      "issue_id": "ISS-002",
      "batch": 1,
      "iteration": 1,
      "agent": "developer",
      "files_modified": ["src/baz.ts"],
      "summary": "Fix type error",
      "timestamp": "2026-04-28T00:00:01Z"
    }
  ]
}
EOF

# issue-registry.json: 2 issues fixed
cat > "$SUBDIR1/issue-registry.json" <<'EOF'
{
  "$schema": "issue-registry-v2",
  "session_id": "v71-e02-sub1",
  "issues": [
    {"issue_id": "ISS-001", "fix_status": "fixed", "severity": "critical"},
    {"issue_id": "ISS-002", "fix_status": "fixed", "severity": "high"}
  ]
}
EOF

# fix-report.md: claims match actual (Fixed=2, Files=3, Coverage=100%)
cat > "$SUBDIR1/fix-report.md" <<'EOF'
# Bug Fix Report

## Summary
- Fixed: 2 issues
- Files modified: 3
- Coverage: 100%
EOF

# Run CQG verify
if ! bash "$CQG_SCRIPT" --session-dir "$SUBDIR1" 2> "$SUBDIR1/stderr.log"; then
  echo "[V71-E02 sub-test 1] FAIL: CQG verify exited non-zero"
  cat "$SUBDIR1/stderr.log"
  exit 1
fi

# Verify cqg-verify.json
ACTUAL_FIXED_1=$(jq '.metrics[] | select(.metric == "issues_fixed_count") | .actual_value' "$SUBDIR1/cqg-verify.json")
PASSED_1=$(jq -r '.passed' "$SUBDIR1/cqg-verify.json")

if [ "$ACTUAL_FIXED_1" != "2" ]; then
  echo "[V71-E02 sub-test 1] FAIL: actual_fixed = $ACTUAL_FIXED_1 (expected 2)"
  jq '.metrics' "$SUBDIR1/cqg-verify.json"
  exit 1
fi

if [ "$PASSED_1" != "true" ]; then
  echo "[V71-E02 sub-test 1] FAIL: passed = $PASSED_1 (expected true)"
  jq '.mismatches' "$SUBDIR1/cqg-verify.json"
  exit 1
fi

echo "[V71-E02 sub-test 1] PASS — actual_fixed=2 from length(entries), passed=true"

# ============================================================
# SUB-TEST 2: Fallback (entries empty -> registry, deferred excluded)
# ============================================================
echo "[V71-E02 sub-test 2] Fallback — entries empty, count tu registry, deferred excluded"

SUBDIR2="$FIXTURE_DIR/sub2"
rm -rf "$SUBDIR2" && mkdir -p "$SUBDIR2"

# fix-log.json: entries rong
cat > "$SUBDIR2/fix-log.json" <<'EOF'
{
  "$schema": "fix-log-v1",
  "session_id": "v71-e02-sub2",
  "entries": []
}
EOF

# issue-registry.json: 2 fixed + 1 deferred -> actual_fixed phai = 2 (deferred excluded)
cat > "$SUBDIR2/issue-registry.json" <<'EOF'
{
  "$schema": "issue-registry-v2",
  "session_id": "v71-e02-sub2",
  "issues": [
    {"issue_id": "ISS-001", "fix_status": "fixed", "severity": "critical"},
    {"issue_id": "ISS-002", "fix_status": "fixed", "severity": "high"},
    {"issue_id": "ISS-003", "fix_status": "deferred", "severity": "medium"}
  ]
}
EOF

# fix-report.md: claims match (Fixed=2, Files=0, Coverage=66.67%)
# coverage = 2 fixed / 3 total = 66.67%
cat > "$SUBDIR2/fix-report.md" <<'EOF'
# Bug Fix Report

## Summary
- Fixed: 2 issues
- Files modified: 0
- Coverage: 66.67%
EOF

if ! bash "$CQG_SCRIPT" --session-dir "$SUBDIR2" 2> "$SUBDIR2/stderr.log"; then
  echo "[V71-E02 sub-test 2] FAIL: CQG verify exited non-zero"
  cat "$SUBDIR2/stderr.log"
  exit 1
fi

ACTUAL_FIXED_2=$(jq '.metrics[] | select(.metric == "issues_fixed_count") | .actual_value' "$SUBDIR2/cqg-verify.json")
PASSED_2=$(jq -r '.passed' "$SUBDIR2/cqg-verify.json")

# Boundary check: deferred KHONG duoc count
if [ "$ACTUAL_FIXED_2" != "2" ]; then
  echo "[V71-E02 sub-test 2] FAIL: actual_fixed = $ACTUAL_FIXED_2 (expected 2 — deferred MUST be excluded)"
  jq '.metrics' "$SUBDIR2/cqg-verify.json"
  exit 1
fi

if [ "$PASSED_2" != "true" ]; then
  echo "[V71-E02 sub-test 2] FAIL: passed = $PASSED_2 (expected true)"
  jq '.mismatches' "$SUBDIR2/cqg-verify.json"
  exit 1
fi

echo "[V71-E02 sub-test 2] PASS — actual_fixed=2 from registry fallback, deferred excluded, passed=true"

# ============================================================
# ALL SUB-TESTS PASS
# ============================================================
echo "[V71-E02] PASS: F26 regression verified — schema fix-log-v1 compliant + fallback path correct"
exit 0
