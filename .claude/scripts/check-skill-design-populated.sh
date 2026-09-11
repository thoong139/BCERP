#!/bin/bash
# check-skill-design-populated.sh v1.0
# Validate that a skill design canon folder (docs/04-skill-design/{skill}/)
# has been fully populated from _template/ — no placeholders, no template metadata blocks left.
#
# Usage:
#   ./check-skill-design-populated.sh docs/04-skill-design/wf-my-new-skill/
#   ./check-skill-design-populated.sh --all     # check all design folders
#
# Exit codes:
#   0 = PASS (no issues)
#   1 = FAIL (placeholders or _template_notes still present)
#   2 = USAGE error

set -e 2>/dev/null || true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DESIGN_ROOT="$PROJECT_ROOT/docs/04-skill-design"

usage() {
    cat <<EOF
Usage: $0 <path-to-skill-design-folder> | --all

Examples:
  $0 docs/04-skill-design/wf-my-new-skill/
  $0 --all

Checks performed:
  1. _template_notes blocks completely removed
  2. {skill-name} placeholders replaced
  3. {Skill Display Name} placeholders replaced
  4. Each populated file has >50 non-trivial lines (not skeleton)
  5. README.md exists with file index ticked
  6. 00-master-checklist.md present (gating file)

EOF
    exit 2
}

# ---------- Validators ----------

check_template_notes() {
    local file="$1"
    # Check ONLY for _template_notes inside HTML comment block (<!-- ... -->)
    # Skip false positives inside code blocks (```yaml ... ```)
    if awk '
        /^<!--/ { in_html_comment=1; in_code_block=0; next }
        /^-->/ { in_html_comment=0; next }
        /^```/ { in_code_block = !in_code_block; next }
        in_html_comment && !in_code_block && /^_template_notes:/ { found=1; exit }
        END { exit !found }
    ' "$file" 2>/dev/null; then
        echo -e "${RED}  ✗ Còn _template_notes block (HTML comment chưa xóa)${NC}"
        return 1
    fi
    return 0
}

check_placeholders() {
    local file="$1"
    local issues=0
    # {skill-name} placeholder
    if grep -qE '\{skill-name\}' "$file" 2>/dev/null; then
        local count
        count=$(grep -cE '\{skill-name\}' "$file" 2>/dev/null) || count=0
        echo -e "${RED}  ✗ Còn ${count} {skill-name} placeholder${NC}"
        issues=$((issues + 1))
    fi
    # {Skill Display Name}
    if grep -qE '\{Skill Display Name\}' "$file" 2>/dev/null; then
        echo -e "${RED}  ✗ Còn {Skill Display Name} placeholder${NC}"
        issues=$((issues + 1))
    fi
    # {X.Y.Z} version
    if grep -qE '\{X\.Y\.Z\}' "$file" 2>/dev/null; then
        echo -e "${RED}  ✗ Còn {X.Y.Z} version placeholder${NC}"
        issues=$((issues + 1))
    fi
    # YYYY-MM-DD literal (allow only in examples)
    if grep -qE '^>.*YYYY-MM-DD' "$file" 2>/dev/null; then
        echo -e "${YELLOW}  ! Còn YYYY-MM-DD trong header — verify đã đổi date thật${NC}"
    fi
    return $issues
}

check_min_lines() {
    local file="$1"
    local min="${2:-50}"
    local lines
    # Đếm dòng non-comment, non-empty
    lines=$(grep -cvE '^\s*$|^\s*<!--|^\s*-->' "$file" 2>/dev/null) || lines=0
    if [[ "$lines" -lt "$min" ]]; then
        echo -e "${YELLOW}  ! Chỉ ${lines} dòng nội dung (yêu cầu ≥${min}) — có thể skeleton${NC}"
        return 1
    fi
    return 0
}

check_readme_index_ticked() {
    local readme="$1"
    if [[ ! -f "$readme" ]]; then
        echo -e "${RED}  ✗ README.md không tồn tại${NC}"
        return 1
    fi
    # Đếm số `[ ]` (chưa tick) trong bảng files
    local unticked
    unticked=$(grep -cE '\| \[ \] \|' "$readme" 2>/dev/null) || unticked=0
    if [[ "$unticked" -gt 0 ]]; then
        echo -e "${YELLOW}  ! ${unticked} file chưa tick trong README index${NC}"
        return 1
    fi
    return 0
}

# ---------- Main check function ----------

check_folder() {
    local folder="$1"
    local folder_name
    folder_name=$(basename "$folder")

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE}Checking: ${folder_name}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"

    if [[ ! -d "$folder" ]]; then
        echo -e "${RED}✗ Folder không tồn tại: $folder${NC}"
        return 1
    fi

    local total_issues=0
    local files_checked=0

    # Required files (from _template/ v3.2 — 2026-05-16: added 03-architecture)
    local required_files=(
        "README.md"
        "00-master-checklist.md"
        "01-vision-principles.md"
        "03-architecture.md"
        "03-phase-routing.md"
        "04-file-contract.md"
        "05-error-codes.md"
        "06-templates-list.md"
        "07-procedures-structure.md"
        "08-tradeoffs-adr.md"
        "09-evals-test-cases.md"
    )
    # Either 02-arguments.md or 02-quality-dimensions.md (variant)
    local optional_either=(
        "02-arguments.md"
        "02-quality-dimensions.md"
    )

    # Check required
    for f in "${required_files[@]}"; do
        local path="$folder/$f"
        if [[ ! -f "$path" ]]; then
            echo -e "${RED}✗ MISSING required file: $f${NC}"
            total_issues=$((total_issues + 1))
            continue
        fi
        echo -e "${BLUE}→ $f${NC}"
        files_checked=$((files_checked + 1))

        # README.md là index ngắn → threshold 30; các file khác ≥50
        local min_lines=50
        if [[ "$f" == "README.md" ]]; then
            min_lines=30
        fi

        check_template_notes "$path" || total_issues=$((total_issues + 1))
        check_placeholders "$path" || total_issues=$((total_issues + $?))
        check_min_lines "$path" "$min_lines" || total_issues=$((total_issues + 1))
    done

    # Check 02-* either variant
    local has_02=0
    for f in "${optional_either[@]}"; do
        if [[ -f "$folder/$f" ]]; then
            echo -e "${BLUE}→ $f (variant 02)${NC}"
            check_template_notes "$folder/$f" || total_issues=$((total_issues + 1))
            check_placeholders "$folder/$f" || total_issues=$((total_issues + $?))
            check_min_lines "$folder/$f" 50 || total_issues=$((total_issues + 1))
            has_02=1
        fi
    done
    if [[ "$has_02" -eq 0 ]]; then
        echo -e "${RED}✗ MISSING: cần 02-arguments.md HOẶC 02-quality-dimensions.md${NC}"
        total_issues=$((total_issues + 1))
    fi

    # Check README index ticked
    echo -e "${BLUE}→ README.md index ticking${NC}"
    check_readme_index_ticked "$folder/README.md" || total_issues=$((total_issues + 1))

    # Summary
    echo ""
    if [[ "$total_issues" -eq 0 ]]; then
        echo -e "${GREEN}✓ PASS — ${folder_name} (${files_checked} files OK)${NC}"
        return 0
    else
        echo -e "${RED}✗ FAIL — ${folder_name}: ${total_issues} issues${NC}"
        return 1
    fi
}

# ---------- Entry ----------

if [[ $# -lt 1 ]]; then
    usage
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
fi

if [[ "$1" == "--all" ]]; then
    echo -e "${BLUE}Scanning all design canon folders in ${DESIGN_ROOT}${NC}"
    overall=0
    for folder in "$DESIGN_ROOT"/*/; do
        folder_name=$(basename "$folder")
        # Skip _template directory
        if [[ "$folder_name" == "_template" ]]; then
            continue
        fi
        check_folder "$folder" || overall=$((overall + 1))
    done
    echo ""
    if [[ "$overall" -eq 0 ]]; then
        echo -e "${GREEN}═══ ALL DESIGN FOLDERS PASS ═══${NC}"
        exit 0
    else
        echo -e "${RED}═══ ${overall} folders FAIL ═══${NC}"
        exit 1
    fi
else
    target="$1"
    # Normalize path
    if [[ ! -d "$target" ]]; then
        # Try relative to project root
        target="$PROJECT_ROOT/$1"
    fi
    if [[ ! -d "$target" ]]; then
        echo -e "${RED}✗ Folder không tồn tại: $1${NC}"
        exit 2
    fi
    check_folder "$target"
    exit $?
fi
