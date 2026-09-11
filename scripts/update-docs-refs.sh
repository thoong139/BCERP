#!/usr/bin/env bash
# update-docs-refs.sh — Cập nhật references trong `.claude/**` và root files
# từ paths cũ trong `docs/` sang paths mới sau Wave 3 docs-restructure-v1.
#
# Mặc định CHỈ chạy dry-run, in diff preview.
# Dùng --apply để thực sự ghi.
#
# Quy ước:
#   - Chỉ thay những refs CHẮC CHẮN tuyệt đối (full path match).
#   - KHÔNG đụng nội dung trong `docs/99-archive/` (giữ lịch sử).
#   - KHÔNG đụng `.claude/worktrees/**` (legacy worktree).
#   - Verify mỗi rewrite bằng diff trước khi apply.
#
# Phụ thuộc: bash 4+, grep, sed (GNU sed). Trên macOS dùng `brew install gnu-sed`.

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# 1. CẤU HÌNH
# ─────────────────────────────────────────────────────────────────────────────

readonly SCRIPT_NAME="update-docs-refs.sh"
readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Thư mục/file được PHÉP sửa
readonly INCLUDE_PATHS=(
  ".claude/skills"
  ".claude/agents"
  ".claude/rules"
  ".claude/doc-framework"
  ".claude/references"
  ".claude/schemas"
  ".claude/scripts"
  "CLAUDE.md"
  "AGENTS.md"
  "CHANGELOG.md"
  "README.md"
)

# Thư mục bị LOẠI TRỪ tuyệt đối
readonly EXCLUDE_PATTERNS=(
  ".claude/worktrees"
  ".claude/hooks/.metrics"
  ".mc-data"
  ".git"
  "node_modules"
  "docs/99-archive"
)

# Mapping cũ → mới — phải khớp tuyệt đối (full relative path).
# Format: "OLD_PATH|NEW_PATH"
# Khi ref dùng dạng "docs/foo.md" hoặc "./docs/foo.md", script bắt cả 2.
readonly MAPPINGS=(
  # Overview migrations
  "docs/project-description.md|docs/00-overview/01-project-description.md"
  "docs/mcv3-development-priorities.md|docs/00-overview/02-positioning-priorities.md"

  # Architecture catalogs
  "docs/skills-reference.md|docs/01-architecture/07-skills-catalog.md"
  "docs/skills-dependency-graph.md|docs/01-architecture/09-dependencies-graph.md"

  # User guides
  "docs/devkit-workflow-overview.md|docs/06-user-guides/devkit-workflow-overview.md"
  "docs/huong-dan-su-dung.md|docs/06-user-guides/huong-dan-su-dung.md"

  # Reference / cheatsheets
  "docs/skill-anatomy-guide.md|docs/08-reference/skill-anatomy-quick.md"
  "docs/microtask-schema.md|docs/08-reference/microtask-schema.md"

  # Skill design — wf-fix-bugs
  "docs/design/skills/wf-fix-bugs/|docs/04-skill-design/wf-fix-bugs/"

  # Skill design — wf-legacy-scan
  "docs/design/skills/wf-legacy-scan/|docs/04-skill-design/wf-legacy-scan/"

  # Review standards
  "docs/skill-review-standards/|docs/05-review-standards/"

  # Per-skill manuals
  "docs/skills-manual/|docs/06-user-guides/per-skill/"

  # Runbooks
  "docs/runbooks/|docs/07-operations/runbooks/"

  # Release notes / migration guides
  "docs/wf-e2e-migration-guide.md|docs/07-operations/migrations/wf-e2e-migration-guide.md"
  "docs/wf-e2e-performance-baseline.md|docs/07-operations/release-notes/wf-e2e-performance-baseline.md"
  "docs/wf-e2e-pipeline-v8-guide.md|docs/07-operations/release-notes/wf-e2e-pipeline-v8-guide.md"
  "docs/wf-e2e-rollback-strategy.md|docs/07-operations/migrations/wf-e2e-rollback-strategy.md"
  "docs/wf-e2e-rollout-phases.md|docs/07-operations/migrations/wf-e2e-rollout-phases.md"
  "docs/wf-fix-bugs-v10.2.1-fixes.md|docs/07-operations/release-notes/wf-fix-bugs-v10.2.1-fixes.md"
  "docs/wf-fix-bugs-v7-migration-guide.md|docs/07-operations/migrations/wf-fix-bugs-v7-migration-guide.md"
  "docs/wf-fix-bugs-v9-guide.md|docs/07-operations/release-notes/wf-fix-bugs-v9-guide.md"
  "docs/wf-preflight-v3-guide.md|docs/07-operations/release-notes/wf-preflight-v3-guide.md"
  "docs/wf-legacy-scan-v5-guide.md|docs/07-operations/release-notes/wf-legacy-scan-v5-guide.md"
)

# ─────────────────────────────────────────────────────────────────────────────
# 2. UTILS
# ─────────────────────────────────────────────────────────────────────────────

c_red()   { printf "\033[31m%s\033[0m" "$*"; }
c_green() { printf "\033[32m%s\033[0m" "$*"; }
c_yellow(){ printf "\033[33m%s\033[0m" "$*"; }
c_cyan()  { printf "\033[36m%s\033[0m" "$*"; }
c_bold()  { printf "\033[1m%s\033[0m" "$*"; }

log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[$(c_yellow WARN)]  $*"; }
log_error() { echo "[$(c_red ERROR)] $*" >&2; }
log_ok()    { echo "[$(c_green OK)]    $*"; }

die() { log_error "$*"; exit 1; }

usage() {
  cat <<EOF
$SCRIPT_NAME — Update docs/ refs trong .claude/** sau Wave 3 docs-restructure-v1

Usage:
  $SCRIPT_NAME [--apply] [--filter <pattern>] [--verbose] [--mapping-only]
  $SCRIPT_NAME --help

Options:
  --apply           Thực sự ghi thay đổi (mặc định: dry-run, in diff preview)
  --filter PATTERN  Chỉ xử lý files match PATTERN (substring trong path)
  --verbose         In thêm chi tiết per-file
  --mapping-only    Chỉ in mapping table rồi exit
  --help            In help này

Examples:
  $SCRIPT_NAME                              # Dry-run toàn bộ
  $SCRIPT_NAME --filter wf-fix-bugs         # Dry-run chỉ files khớp 'wf-fix-bugs'
  $SCRIPT_NAME --apply                      # Thực sự apply
  $SCRIPT_NAME --apply --filter SKILL.md    # Apply chỉ với SKILL.md files

Quy tắc an toàn:
  1. Mặc định dry-run, không ghi
  2. Bỏ qua: .git, .mc-data, node_modules, docs/99-archive, .claude/worktrees
  3. Mỗi rewrite có diff preview trước khi apply
  4. Backup tự động qua git (giả định đã commit trước khi chạy --apply)
EOF
}

# Kiểm tra path có bị loại trừ không
is_excluded() {
  local path="$1"
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if [[ "$path" == *"$pattern"* ]]; then
      return 0
    fi
  done
  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. PARSE ARGS
# ─────────────────────────────────────────────────────────────────────────────

APPLY=0
FILTER=""
VERBOSE=0
MAPPING_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --filter) FILTER="${2:-}"; shift 2 ;;
    --verbose|-v) VERBOSE=1; shift ;;
    --mapping-only) MAPPING_ONLY=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1 (try --help)" ;;
  esac
done

cd "$REPO_ROOT" || die "Cannot cd to $REPO_ROOT"

# ─────────────────────────────────────────────────────────────────────────────
# 4. PRINT MAPPING TABLE
# ─────────────────────────────────────────────────────────────────────────────

print_mapping_table() {
  echo
  c_bold "=== MAPPING TABLE (${#MAPPINGS[@]} entries) ==="
  echo
  printf "%-55s  %s\n" "OLD PATH" "NEW PATH"
  printf '%.0s─' {1..120}; echo
  for entry in "${MAPPINGS[@]}"; do
    local old="${entry%%|*}"
    local new="${entry##*|}"
    printf "%-55s  %s\n" "$old" "$new"
  done
  echo
}

if [[ $MAPPING_ONLY -eq 1 ]]; then
  print_mapping_table
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. BUILD FILE LIST
# ─────────────────────────────────────────────────────────────────────────────

log_info "Building file list từ ${#INCLUDE_PATHS[@]} include paths..."

FILES_TO_SCAN=()
for include in "${INCLUDE_PATHS[@]}"; do
  if [[ -f "$include" ]]; then
    FILES_TO_SCAN+=("$include")
  elif [[ -d "$include" ]]; then
    # Tìm tất cả files text trong include path
    while IFS= read -r -d '' f; do
      if ! is_excluded "$f"; then
        FILES_TO_SCAN+=("$f")
      fi
    done < <(find "$include" -type f \( -name '*.md' -o -name '*.json' -o -name '*.py' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' -o -name '*.txt' \) -print0 2>/dev/null)
  fi
done

log_info "Tìm thấy ${#FILES_TO_SCAN[@]} files để scan"

# ─────────────────────────────────────────────────────────────────────────────
# 6. SCAN & REPLACE
# ─────────────────────────────────────────────────────────────────────────────

TOTAL_FILES_CHANGED=0
TOTAL_REPLACEMENTS=0
declare -a CHANGED_FILES

# Build sed command list từ MAPPINGS
build_sed_args() {
  local -a args=()
  for entry in "${MAPPINGS[@]}"; do
    local old="${entry%%|*}"
    local new="${entry##*|}"
    # Escape sed special chars trong old/new (slash, ampersand)
    local old_esc new_esc
    old_esc="$(printf '%s' "$old" | sed 's:[\\/&]:\\&:g')"
    new_esc="$(printf '%s' "$new" | sed 's:[\\/&]:\\&:g')"
    args+=("-e" "s|${old_esc}|${new_esc}|g")
  done
  printf '%s\n' "${args[@]}"
}

# Lấy danh sách sed args 1 lần (cache)
mapfile -t SED_ARGS < <(build_sed_args)

# Check file có chứa ref nào trong MAPPINGS không
file_has_old_ref() {
  local file="$1"
  for entry in "${MAPPINGS[@]}"; do
    local old="${entry%%|*}"
    if grep -qF "$old" "$file" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

# Đếm số dòng có old ref trong file
count_old_refs_in_file() {
  local file="$1"
  local total=0
  for entry in "${MAPPINGS[@]}"; do
    local old="${entry%%|*}"
    local n
    n="$(grep -cF "$old" "$file" 2>/dev/null || echo 0)"
    n="${n//[^0-9]/}"
    n="${n:-0}"
    total=$((total + n))
  done
  echo "$total"
}

# In preview các dòng match cho file
print_match_preview() {
  local file="$1"
  echo
  echo "─── $(c_cyan "$file") ───"
  for entry in "${MAPPINGS[@]}"; do
    local old="${entry%%|*}"
    local new="${entry##*|}"
    # Print mỗi line match với context: dòng cũ → dòng mới
    grep -nF "$old" "$file" 2>/dev/null | while IFS= read -r line; do
      local lineno="${line%%:*}"
      local content="${line#*:}"
      # Strip CR cuối line (Windows files)
      content="${content%$'\r'}"
      printf "  L%-4s %s%s\n" "$lineno" "$(c_red '- ')" "$content"
      # Tạo new content tương ứng (single line sed)
      local new_content
      new_content="$(printf '%s' "$content" | sed "s|${old//|/\\|}|${new//|/\\|}|g")"
      printf "  L%-4s %s%s\n" "$lineno" "$(c_green '+ ')" "$new_content"
    done
  done
}

# Xử lý 1 file
process_file() {
  local file="$1"

  # Apply filter
  if [[ -n "$FILTER" && "$file" != *"$FILTER"* ]]; then
    return 0
  fi

  # Skip nếu không chứa old refs
  if ! file_has_old_ref "$file"; then
    return 0
  fi

  # Đếm refs trong file (xấp xỉ replacements)
  local refs_count
  refs_count="$(count_old_refs_in_file "$file")"
  if [[ "$refs_count" -eq 0 ]]; then
    return 0
  fi

  TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + refs_count))
  TOTAL_FILES_CHANGED=$((TOTAL_FILES_CHANGED + 1))
  CHANGED_FILES+=("$file")

  # In preview nếu dry-run hoặc verbose
  if [[ $VERBOSE -eq 1 || $APPLY -eq 0 ]]; then
    print_match_preview "$file"
  fi

  # Apply nếu --apply
  if [[ $APPLY -eq 1 ]]; then
    # Tạo tmp file, sed → validate cmp → atomic move
    local tmp="${file}.tmp.$$"
    sed "${SED_ARGS[@]}" "$file" > "$tmp" 2>/dev/null || {
      log_warn "sed failed cho: $file"
      rm -f "$tmp"
      return 1
    }
    # Verify tmp khác bản gốc
    if cmp -s "$file" "$tmp"; then
      rm -f "$tmp"
      log_warn "Không có thay đổi thực sự cho: $file (skip)"
      return 0
    fi
    mv "$tmp" "$file" || {
      log_error "Không thể ghi: $file"
      rm -f "$tmp"
      return 1
    }
    log_ok "Đã ghi $refs_count refs trong: $file"
  fi
}

# Main loop
log_info "Scanning ${#FILES_TO_SCAN[@]} files..."
for f in "${FILES_TO_SCAN[@]}"; do
  process_file "$f" || log_warn "Bỏ qua $f do lỗi"
done

# ─────────────────────────────────────────────────────────────────────────────
# 7. SUMMARY
# ─────────────────────────────────────────────────────────────────────────────

echo
c_bold "=== SUMMARY ==="
echo
echo "Files scan:            ${#FILES_TO_SCAN[@]}"
echo "Files có refs cũ:      $TOTAL_FILES_CHANGED"
echo "Ước lượng replacements: $TOTAL_REPLACEMENTS"
echo
if [[ $TOTAL_FILES_CHANGED -gt 0 && $APPLY -eq 0 ]]; then
  echo "$(c_yellow "[DRY-RUN]") Để thực sự áp dụng: $0 --apply"
  echo
  echo "Files sẽ thay đổi ($TOTAL_FILES_CHANGED):"
  for f in "${CHANGED_FILES[@]}"; do
    echo "  - $f"
  done
elif [[ $TOTAL_FILES_CHANGED -gt 0 && $APPLY -eq 1 ]]; then
  log_ok "Hoàn tất: $TOTAL_FILES_CHANGED files đã update"
  echo
  echo "Verify bằng:"
  echo "  git status"
  echo "  git diff --stat"
else
  log_ok "Không có files nào cần update"
fi

exit 0
