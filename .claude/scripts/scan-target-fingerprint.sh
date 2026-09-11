#!/usr/bin/env bash
# scan-target-fingerprint.sh — Compute composite fingerprint cho wf-scan-target
# Sprint 4 bash delegation — Q6 composite design
# v2.0.1 — BUG-003 fix: thêm fingerprint mode (strict|loose) để control git_dirty inclusion
#
# Usage:
#   bash .claude/scripts/scan-target-fingerprint.sh <target> <tech_csv> <depth> [mode]
#
# Args:
#   target    - path/URL của target
#   tech_csv  - tech stacks CSV (sorted, dedup)
#   depth     - shallow|deep
#   mode      - strict (default) | loose
#               strict: include git_dirty signal (cache invalidate khi có uncommitted changes)
#               loose:  KHÔNG include git_dirty (cache stable trên dev project chưa
#                       gitignore .mc-data/, mỗi scan tạo session files mới sẽ KHÔNG
#                       toggle fingerprint). Trade-off: cache có thể stale nếu source
#                       thực sự có uncommitted changes.
#
# Output: 64-char sha256 hex string to stdout
#
# Composite components (Q6 decision):
#   - target absolute path (normalized — Unix forward slashes)
#   - tech_stack joined sorted (CSV)
#   - scan_depth (shallow|deep)
#   - git rev-parse HEAD (nếu trong git repo, else "no-git")
#   - git status uncommitted count (dirty signal — empty/dirty) — CHỈ trong strict mode
#   - manifest mtimes (package.json, *.csproj, pom.xml, go.mod, ...)
#
# Lý do composite: detect tất cả thay đổi có thể ảnh hưởng scan output:
#   commit mới → git_head khác
#   uncommitted changes → git_dirty = "dirty" (strict mode only)
#   dependency thay đổi → manifest mtime khác
#   target khác máy → path khác

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="scan-target-fingerprint"
# shellcheck source=./scan-target-common.sh
source "$SCRIPTS_DIR/scan-target-common.sh"

set -euo pipefail 2>/dev/null || set -e

# ─── Args ────────────────────────────────────────────────────

TARGET="${1:?Usage: $0 <target> <tech_csv> <depth> [mode]}"
TECH_CSV="${2:-}"
DEPTH="${3:-deep}"
MODE="${4:-strict}"

# Validate mode
case "$MODE" in
  strict|loose) ;;
  *)
    log_error "Invalid mode: '$MODE'. Valid: strict | loose"
    exit 2
    ;;
esac

# ─── Compute composite fingerprint ──────────────────────────

# 1) Target absolute path (normalized — Unix forward slashes)
target_abs=""
if [[ -d "$TARGET" ]]; then
  target_abs=$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")
elif [[ -f "$TARGET" ]]; then
  target_dir=$(dirname "$TARGET")
  target_basename=$(basename "$TARGET")
  target_abs=$(cd "$target_dir" 2>/dev/null && echo "$(pwd)/$target_basename" || echo "$TARGET")
else
  # URL hoặc swagger-spec hoặc non-existent path — keep as-is
  target_abs="$TARGET"
fi
target_abs=$(normalize_path "$target_abs")

# 2) Git signals (nếu trong git repo)
git_head="no-git"
git_dirty="empty"
if [[ -d "$TARGET" ]]; then
  if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
    git_head=$(git -C "$TARGET" rev-parse HEAD 2>/dev/null || echo "no-head")
    # Q6 — git_dirty signal: nếu có uncommitted changes → fingerprint khác
    # v2.0.1 BUG-003 fix: chỉ check trong strict mode. loose mode skip để cache
    # stable trên dev project chưa gitignore .mc-data/.
    if [[ "$MODE" == "strict" ]]; then
      if [[ -n "$(git -C "$TARGET" status --porcelain 2>/dev/null)" ]]; then
        git_dirty="dirty"
      fi
    else
      git_dirty="loose-skip"
    fi
  fi
fi

# 3) Manifest mtimes (5-20 files max — fast)
manifest_mtimes=""
if [[ -d "$TARGET" ]]; then
  # find với maxdepth 3 — đủ cho monorepo workspace structure
  # stat -c "%Y %n" Linux/Git Bash; macOS dùng -f "%m %N"
  if stat -c '%Y' "$TARGET" >/dev/null 2>&1; then
    # GNU stat (Linux + Git Bash for Windows)
    manifest_mtimes=$(find "$TARGET" -maxdepth 3 \
      \( -name "package.json" \
         -o -name "*.csproj" \
         -o -name "*.sln" \
         -o -name "pom.xml" \
         -o -name "go.mod" \
         -o -name "requirements.txt" \
         -o -name "pyproject.toml" \
         -o -name "Cargo.toml" \
         -o -name "composer.json" \
         -o -name "Gemfile" \) \
      -not -path "*/node_modules/*" \
      -not -path "*/vendor/*" \
      -not -path "*/bin/*" \
      -not -path "*/obj/*" \
      -exec stat -c "%Y %n" {} \; 2>/dev/null \
      | sort)
  else
    # BSD stat (macOS)
    manifest_mtimes=$(find "$TARGET" -maxdepth 3 \
      \( -name "package.json" \
         -o -name "*.csproj" \
         -o -name "*.sln" \
         -o -name "pom.xml" \
         -o -name "go.mod" \
         -o -name "requirements.txt" \
         -o -name "pyproject.toml" \
         -o -name "Cargo.toml" \
         -o -name "composer.json" \
         -o -name "Gemfile" \) \
      -not -path "*/node_modules/*" \
      -not -path "*/vendor/*" \
      -not -path "*/bin/*" \
      -not -path "*/obj/*" \
      -exec stat -f "%m %N" {} \; 2>/dev/null \
      | sort)
  fi

  # Hash manifest_mtimes for compactness (raw can be large)
  if [[ -n "$manifest_mtimes" ]]; then
    if command -v sha256sum &>/dev/null; then
      manifest_mtimes=$(echo "$manifest_mtimes" | sha256sum | cut -d' ' -f1)
    elif command -v shasum &>/dev/null; then
      manifest_mtimes=$(echo "$manifest_mtimes" | shasum -a 256 | cut -d' ' -f1)
    fi
  fi
fi

# 4) Compose composite input
input="path:${target_abs}
tech:${TECH_CSV}
depth:${DEPTH}
git_head:${git_head}
git_dirty:${git_dirty}
manifests:${manifest_mtimes}"

# 5) Hash to sha256
if command -v sha256sum &>/dev/null; then
  echo -n "$input" | sha256sum | cut -d' ' -f1
elif command -v shasum &>/dev/null; then
  echo -n "$input" | shasum -a 256 | cut -d' ' -f1
else
  log_error "No SHA256 tool available (need sha256sum or shasum)"
  exit 2
fi
