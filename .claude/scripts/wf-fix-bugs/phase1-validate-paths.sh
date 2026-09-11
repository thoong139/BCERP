#!/usr/bin/env bash
# =============================================================================
# phase1-validate-paths.sh — Phase 1 Step 1.9 Sub-Skill Path Validation
# =============================================================================
# Mục đích (v10.11.0 — Phase 1 optimization):
#   Validate 13 sub-skill SKILL.md paths với CACHING.
#   Paths hiếm khi thay đổi → cache 24h tránh 13 `test -f` syscalls mỗi lần chạy.
#
# Cache file: ~/.cache/mcv3-fix-bugs/skill-paths-{md5}.json
#   - Key: md5 của script path + danh sách sub-skills (đảm bảo cache invalidate
#          khi orchestrator được update)
#   - TTL: 24h (paths hầu như immutable trong 1 ngày)
#   - Atomic write (.tmp.$$ → mv)
#
# Trước (v10.10): 13 `test -f` mỗi lần chạy (~50-100ms tổng trên Windows)
# Sau  (v10.11): Cache hit ~10ms, cache miss ~100ms (chạy 1 lần/24h/sub-skills)
#
# Exit codes:
#   0 — Tất cả 13 paths tồn tại (PASS)
#   4 — E004: ≥1 path missing (STOP — installation issue)
#
# Output: JSON (stdout) — {"cached":true|false,"missing_count":0,"paths_ok":13}
#
# Compatibility: Git Bash + WSL + macOS/Linux. Pure bash + md5sum.
# =============================================================================

set -eu

# ── Sub-skills cần kiểm tra (canonical list — đồng bộ với phase1-init.md Step 1.9) ──
SUB_SKILLS=(
  "wf-fix-triage"
  "wf-fix-execute"
  "wf-fix-functional"
  "wf-fix-business"
  "wf-fix-security"
  "wf-fix-performance"
  "wf-fix-ux-a11y"
  "wf-fix-data"
  "wf-fix-compat"
  "wf-fix-observability"
  "wf-fix-runtime-health"
  "wf-fix-integration"
  "wf-fix-business-completeness"
)

# ── Cache setup ──────────────────────────────────────────────────────────────
CACHE_DIR="${MCV3_CACHE_DIR:-$HOME/.cache/mcv3-fix-bugs}"
mkdir -p "$CACHE_DIR" 2>/dev/null || CACHE_DIR="/tmp/mcv3-fix-bugs-cache-$$"
mkdir -p "$CACHE_DIR"

# Cache key: md5 của script path + sub-skill list (immutable per-version)
CACHE_KEY_INPUT="$0|${SUB_SKILLS[*]}"
if command -v md5sum >/dev/null 2>&1; then
  CACHE_KEY=$(echo -n "$CACHE_KEY_INPUT" | md5sum | cut -d' ' -f1)
elif command -v md5 >/dev/null 2>&1; then
  CACHE_KEY=$(echo -n "$CACHE_KEY_INPUT" | md5 -q)
else
  CACHE_KEY="default"   # Fallback: chỉ 1 cache slot
fi
CACHE_FILE="$CACHE_DIR/skill-paths-$CACHE_KEY.json"

CACHE_TTL_SEC="${MCV3_FIX_BUGS_PATH_CACHE_TTL:-86400}"   # 24h default

# ── Cache hit check ──────────────────────────────────────────────────────────
CACHED=false
if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
  # Portable age check (macOS/Linux/Git Bash)
  if command -v stat >/dev/null 2>&1; then
    AGE_SEC=$(( $(date +%s) - $(stat -c '%Y' "$CACHE_FILE" 2>/dev/null || stat -f '%m' "$CACHE_FILE" 2>/dev/null || echo 0) ))
  else
    AGE_SEC=999999
  fi
  if [ "$AGE_SEC" -lt "$CACHE_TTL_SEC" ]; then
    # Re-validate JSON (corruption check)
    if jq -e '.paths_ok and .missing_count' "$CACHE_FILE" >/dev/null 2>&1; then
      MISSING=$(jq -r '.missing_count' "$CACHE_FILE")
      if [ "$MISSING" -eq 0 ]; then
        CACHED=true
        # Output cached result + flag cached=true
        jq '. + {cached: true}' "$CACHE_FILE"
        exit 0
      fi
      # Cached fail result → re-validate (paths may have been fixed)
    fi
  fi
fi

# ── Cache miss → validate fresh ──────────────────────────────────────────────
MISSING_COUNT=0
MISSING_LIST=()
for slug in "${SUB_SKILLS[@]}"; do
  if [ ! -f ".claude/skills/workflow/$slug/SKILL.md" ]; then
    MISSING_COUNT=$((MISSING_COUNT + 1))
    MISSING_LIST+=("$slug")
  fi
done

# Orchestrator skills (triage + execute) đã có trong danh sách trên — không cần kiểm tra thêm

PATHS_OK=$((${#SUB_SKILLS[@]} - MISSING_COUNT))

# Build result JSON
RESULT=$(jq -n \
  --argjson ok "$PATHS_OK" \
  --argjson missing "$MISSING_COUNT" \
  --arg missing_list "$(IFS=,; echo "${MISSING_LIST[*]:-}")" \
  '{paths_ok: $ok, missing_count: $missing, missing_list: ($missing_list | split(",") | map(select(. != "")))}')

# Write cache (atomic) chỉ khi PASS — fail cases không cache để retry
if [ "$MISSING_COUNT" -eq 0 ]; then
  TMP="$CACHE_FILE.tmp.$$"
  echo "$RESULT" > "$TMP" && mv "$TMP" "$CACHE_FILE" || rm -f "$TMP"
fi

# Output (cached=false)
echo "$RESULT" | jq '. + {cached: false}'

# Exit code
[ "$MISSING_COUNT" -eq 0 ] && exit 0 || exit 4
