#!/usr/bin/env bash
# Phase F F.4 smoke test — verify CLI flag parsing + incremental validation logic
# in phase0-detection.md procedure (extracted + standalone test).
#
# Usage:
#   bash .claude/scripts/legacy-scan-phase-f-flags-test.sh
#
# Exit codes:
#   0 — all cases pass
#   1 — one or more cases failed
#   2 — env missing

set -euo pipefail

command -v git >/dev/null 2>&1 || { echo "[ERR] git khong co trong PATH" >&2; exit 2; }

TMP=$(mktemp -d -t wf-legacy-scan-phase-f-flags-XXXXXX)
trap 'rm -rf "$TMP"' EXIT

fail=0
PASS() { echo "  [OK]   $1"; }
FAIL() { echo "  [FAIL] $1" >&2; fail=$((fail+1)); }

# Utility: simulate flag parsing voi args va tra ve exported vars (via subshell)
simulate_parse() {
  local args=("$@")
  bash -c '
    set -e
    USER_FLAG_RE_VISION=false
    BATCH_SIZE=100
    PROFILE_ARG=""
    SESSION_ID_OVERRIDE=""
    INCREMENTAL=false
    SINCE_REF=""
    NO_CACHE=false
    CACHE_PUBLISH=false
    STATUS_FLAG=false
    RESUME_FLAG=false
    PROJECT_PATH=""
    for arg in "$@"; do
      case "$arg" in
        --status)         STATUS_FLAG=true ;;
        --resume)         RESUME_FLAG=true ;;
        --re-vision)      USER_FLAG_RE_VISION=true ;;
        --batch-size=*)   BATCH_SIZE="${arg#--batch-size=}" ;;
        --profile=*)      PROFILE_ARG="${arg#--profile=}" ;;
        --session=*)      SESSION_ID_OVERRIDE="${arg#--session=}" ;;
        --incremental)    INCREMENTAL=true ;;
        --since=*)        SINCE_REF="${arg#--since=}" ;;
        --no-cache)       NO_CACHE=true ;;
        --cache-publish)  CACHE_PUBLISH=true ;;
        --*)              echo "WARN:$arg" >&2 ;;
        *)                [ -z "$PROJECT_PATH" ] && PROJECT_PATH="$arg" ;;
      esac
    done
    echo "PROJECT_PATH=$PROJECT_PATH"
    echo "INCREMENTAL=$INCREMENTAL"
    echo "SINCE_REF=$SINCE_REF"
    echo "NO_CACHE=$NO_CACHE"
    echo "CACHE_PUBLISH=$CACHE_PUBLISH"
    echo "PROFILE_ARG=$PROFILE_ARG"
    echo "BATCH_SIZE=$BATCH_SIZE"
  ' _ "${args[@]}"
}

# Utility: Simulate validation logic
simulate_validation() {
  local project_path="$1"
  local incremental="$2"
  local since_ref="$3"

  # Rule 1: --since requires --incremental
  if [ -n "$since_ref" ] && [ "$incremental" != "true" ]; then
    echo "E021"
    return 1
  fi

  # Rule 2: --since requires git repo
  if [ -n "$since_ref" ]; then
    if ! git -C "$project_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "E020"
      return 1
    fi
    # Rule 3: ref phải resolve được
    if ! git -C "$project_path" rev-parse --verify "$since_ref" >/dev/null 2>&1; then
      echo "E022"
      return 1
    fi
  fi

  echo "OK"
  return 0
}

# ---------------- Test Case 1: Basic parsing ----------------
echo "[Case 1] Basic argument parsing"
out=$(simulate_parse "/tmp/proj" "--incremental")
echo "$out" | grep -q "PROJECT_PATH=/tmp/proj" && PASS "PROJECT_PATH captured" || FAIL "PROJECT_PATH missed"
echo "$out" | grep -q "INCREMENTAL=true" && PASS "INCREMENTAL=true" || FAIL "INCREMENTAL not set"
echo "$out" | grep -q "SINCE_REF=$" && PASS "SINCE_REF empty" || FAIL "SINCE_REF unexpectedly set"

# ---------------- Test Case 2: All incremental flags ----------------
echo "[Case 2] --incremental --since=HEAD~5 --no-cache --cache-publish"
out=$(simulate_parse "--incremental" "--since=HEAD~5" "--no-cache" "--cache-publish" "/tmp/proj")
echo "$out" | grep -q "INCREMENTAL=true" && PASS "INCREMENTAL" || FAIL "INCREMENTAL"
echo "$out" | grep -q "SINCE_REF=HEAD~5" && PASS "SINCE_REF=HEAD~5" || FAIL "SINCE_REF"
echo "$out" | grep -q "NO_CACHE=true" && PASS "NO_CACHE" || FAIL "NO_CACHE"
echo "$out" | grep -q "CACHE_PUBLISH=true" && PASS "CACHE_PUBLISH" || FAIL "CACHE_PUBLISH"

# ---------------- Test Case 3: --since without --incremental → E021 ----------------
echo "[Case 3] --since=HEAD~1 without --incremental → E021"
result=$(simulate_validation "$TMP" "false" "HEAD~1" 2>/dev/null || true)
[ "$result" = "E021" ] && PASS "E021 triggered" || FAIL "Expected E021, got: $result"

# ---------------- Test Case 4: --since in non-git dir → E020 ----------------
echo "[Case 4] --since in non-git directory → E020"
NONGIT="$TMP/nongit"
mkdir -p "$NONGIT"
result=$(simulate_validation "$NONGIT" "true" "HEAD~1" 2>/dev/null || true)
[ "$result" = "E020" ] && PASS "E020 triggered" || FAIL "Expected E020, got: $result"

# ---------------- Test Case 5: --incremental in git repo voi valid ref → OK ----------------
echo "[Case 5] --incremental --since=HEAD in git repo → OK"
GITDIR="$TMP/gitrepo"
mkdir -p "$GITDIR"
(
  cd "$GITDIR"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "x" > a.txt
  git add a.txt
  git commit -q -m "init"
)
result=$(simulate_validation "$GITDIR" "true" "HEAD" 2>/dev/null || true)
[ "$result" = "OK" ] && PASS "Validation passed" || FAIL "Expected OK, got: $result"

# ---------------- Test Case 6: --since=invalid-ref → E022 ----------------
echo "[Case 6] --since=nonexistent-ref → E022"
result=$(simulate_validation "$GITDIR" "true" "this-ref-does-not-exist" 2>/dev/null || true)
[ "$result" = "E022" ] && PASS "E022 triggered" || FAIL "Expected E022, got: $result"

# ---------------- Test Case 7: --incremental alone standalone → OK ----------------
echo "[Case 7] --incremental standalone (no --since) → OK (mtime mode)"
result=$(simulate_validation "$TMP" "true" "" 2>/dev/null || true)
[ "$result" = "OK" ] && PASS "Standalone incremental OK" || FAIL "Expected OK, got: $result"

# ---------------- Test Case 8: Python end-to-end — detect_changes ----------------
echo "[Case 8] Python detect_changes end-to-end — git mode"
PY=$(command -v python3 || command -v python)
[ -z "$PY" ] && { echo "[SKIP] python unavailable"; } || {
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  SHARED="$REPO_ROOT/.claude/skills/workflow/_shared"
  if command -v cygpath >/dev/null 2>&1; then
    SHARED_PY=$(cygpath -w "$SHARED")
    GITDIR_PY=$(cygpath -w "$GITDIR")
  else
    SHARED_PY="$SHARED"
    GITDIR_PY="$GITDIR"
  fi
  # Modify a.txt + add b.txt
  (cd "$GITDIR" && echo "y" >> a.txt && echo "z" > b.txt && git add -A && git commit -q -m "update")
  out=$("$PY" - <<PY
import sys
sys.path.insert(0, r"$SHARED_PY")
from ips.incremental import detect_changes, classify_delta
cs = detect_changes(r"$GITDIR_PY", since_ref="HEAD~1")
print(f"method={cs.method}")
print(f"modified_count={len(cs.modified)}")
print(f"new_count={len(cs.new)}")
plan = classify_delta(cs)
print(f"auto_upgrade={plan.auto_upgrade_to_full}")
PY
  )
  echo "$out" | grep -q "method=git_diff" && PASS "git_diff mode picked" || FAIL "method not git_diff: $out"
  echo "$out" | grep -q "modified_count=1" && PASS "1 modified file" || FAIL "modified_count wrong"
  echo "$out" | grep -q "new_count=1" && PASS "1 new file" || FAIL "new_count wrong"
}

echo ""
if [ "$fail" -eq 0 ]; then
  echo "Phase F F.4 flag-parsing smoke test PASSED."
  exit 0
else
  echo "Phase F F.4 flag-parsing smoke test FAILED — $fail issue(s)." >&2
  exit 1
fi
