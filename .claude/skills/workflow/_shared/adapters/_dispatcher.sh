#!/usr/bin/env bash
# Dispatcher entry point — Adapter Framework cho wf-fix-bugs probes.
# Built in IMP-000 Stage 0 (plan wf-fix-bugs-dimensions-audit-v1).
#
# Usage:
#   _dispatcher.sh --list-adapters
#   _dispatcher.sh --detect <project_path>
#   _dispatcher.sh --help
#
# Exit codes:
#   0  Success
#   1  Bad usage
#   2  Project path không tồn tại
#   3  Không có adapter match (chỉ với --detect)
#
# Convention: KHÔNG ghi registry (NONE role per CORE-006).
# Output JSON Lines hoặc plain adapter IDs (1 dòng / adapter).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CATEGORIES=(stack package-manager orm)

print_help() {
    cat <<'EOF'
Adapter Framework Dispatcher (IMP-000 skeleton)

Commands:
  --list-adapters              Liệt kê tất cả adapters đã đăng ký
  --detect <project_path>      Detect adapters applicable cho project
  --help                       In help này

Adapter contract (mỗi file <category>/<name>.sh):
  detect <path>   Trả 0 nếu applicable, 1 nếu không
  scan <path>     Emit JSON Lines findings, exit 0 success

Categories: stack/, package-manager/, orm/
Total expected: 5 stack + 5 PM + 6 ORM = 16 adapters
EOF
}

list_adapters() {
    local count=0
    for category in "${CATEGORIES[@]}"; do
        local cat_dir="$SCRIPT_DIR/$category"
        if [[ ! -d "$cat_dir" ]]; then
            continue
        fi
        # Sắp xếp ổn định để smoke test deterministic
        while IFS= read -r -d '' file; do
            local base
            base="$(basename "$file" .sh)"
            echo "$category/$base"
            count=$((count + 1))
        done < <(find "$cat_dir" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
    done
    if [[ $count -eq 0 ]]; then
        echo "[dispatcher] WARNING: không tìm thấy adapter nào trong $SCRIPT_DIR" >&2
        return 1
    fi
    return 0
}

detect_adapters() {
    local project_path="$1"
    if [[ ! -e "$project_path" ]]; then
        echo "[dispatcher] ERROR: project path không tồn tại: $project_path" >&2
        return 2
    fi
    local matched=0
    for category in "${CATEGORIES[@]}"; do
        local cat_dir="$SCRIPT_DIR/$category"
        if [[ ! -d "$cat_dir" ]]; then
            continue
        fi
        while IFS= read -r -d '' file; do
            local base
            base="$(basename "$file" .sh)"
            # Source adapter trong subshell để cô lập biến + function
            if (
                # shellcheck disable=SC1090
                source "$file" && detect "$project_path"
            ) >/dev/null 2>&1; then
                echo "$category/$base"
                matched=$((matched + 1))
            fi
        done < <(find "$cat_dir" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
    done
    if [[ $matched -eq 0 ]]; then
        return 3
    fi
    return 0
}

main() {
    if [[ $# -lt 1 ]]; then
        print_help
        return 1
    fi
    case "$1" in
        --help|-h)
            print_help
            return 0
            ;;
        --list-adapters)
            list_adapters
            ;;
        --detect)
            if [[ $# -lt 2 ]]; then
                echo "[dispatcher] ERROR: --detect cần <project_path>" >&2
                return 1
            fi
            detect_adapters "$2"
            ;;
        *)
            echo "[dispatcher] ERROR: flag không hỗ trợ: $1" >&2
            print_help
            return 1
            ;;
    esac
}

main "$@"
