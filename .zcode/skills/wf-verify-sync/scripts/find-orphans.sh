#!/bin/bash
# Tìm code files không có REQ-ID reference
# Usage: ./find-orphans.sh [src_dir1] [src_dir2] ...
#   Mặc định scan cả src/ và apps/

ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Nếu có arguments → dùng chúng, không thì scan cả src + apps
if [ $# -gt 0 ]; then
    DIRS=("$@")
else
    DIRS=()
    [ -d "$ROOT_DIR/src" ] && DIRS+=("src")
    [ -d "$ROOT_DIR/apps" ] && DIRS+=("apps")
fi

if [ ${#DIRS[@]} -eq 0 ]; then
    echo "⚠️ Không tìm thấy src/ hoặc apps/ trong: $ROOT_DIR"
    exit 1
fi

echo "=== Orphan Code Finder ==="
echo "Scanning: ${DIRS[*]}"
echo ""

# Files to exclude (config, generated, types, index, minified/bundled)
# Phải khớp với Phase 3 SKILL.md: *.config.*, *.d.ts, index.ts, types.ts, *.test.*, *.spec.*, *.min.js, *.bundle.*
EXCLUDE_PATTERNS="\.config\.|\.d\.ts|\.test\.|\.spec\.|index\.ts|index\.js|types\.ts|types\.js|\.styles\.|constants\.ts|constants\.js|\.min\.js|\.bundle\."

# REQ-ID patterns — tất cả comment styles
# // REQ-ID:    → TypeScript / Go / Java / C++
# /* REQ-ID:    → Block comment
# # REQ-ID:     → Python / Ruby / Shell
# Description(" → C# attribute
REQ_PATTERNS="REQ-ID:|Description\(\"REQ-"

echo "📄 Files without REQ-ID:"
echo ""

TOTAL_COUNT=0

for DIR in "${DIRS[@]}"; do
    FULL_PATH="$ROOT_DIR/$DIR"
    if [ ! -d "$FULL_PATH" ]; then
        echo "  ⚠️ Directory not found: $FULL_PATH"
        continue
    fi

    ORPHANS=$(grep -rL "$REQ_PATTERNS" "$FULL_PATH" 2>/dev/null | \
        grep -E "\.(ts|tsx|js|jsx|py|java|cs|go|rs|rb)$" | \
        grep -vE "$EXCLUDE_PATTERNS" | \
        sort)

    if [ -z "$ORPHANS" ]; then
        continue
    fi

    while IFS= read -r file; do
        REL_PATH="${file#$ROOT_DIR/}"
        LINES=$(wc -l < "$file" 2>/dev/null || echo "?")

        # Categorize by location
        # Shared utility directories per SKILL.md Phase 6.1: utils/, shared/, common/, lib/
        # Use directory-boundary matching to avoid false positives (e.g., "communication" matching "common")
        if [[ "$REL_PATH" =~ (^|/)utility/|(^|/)util/|(^|/)helper/|(^|/)common/|(^|/)shared/|(^|/)lib/ ]]; then
            TYPE="utility"
            RISK="Low"
        elif [[ "$REL_PATH" =~ (^|/)middleware/|(^|/)guard/|(^|/)interceptor/ ]]; then
            TYPE="middleware"
            RISK="Medium"
        elif [[ "$REL_PATH" =~ (^|/)controller/|(^|/)service/|(^|/)repository/|(^|/)model/|(^|/)entity/ ]]; then
            TYPE="core"
            RISK="High"
        elif [[ "$REL_PATH" =~ (^|/)component/|(^|/)page/|(^|/)view/ ]]; then
            TYPE="ui"
            RISK="Medium"
        else
            TYPE="other"
            RISK="Low"
        fi

        printf "  %-50s %4s lines  [%-10s] Risk: %s\n" "$REL_PATH" "$LINES" "$TYPE" "$RISK"
        ((TOTAL_COUNT++))
    done <<< "$ORPHANS"
done

echo ""
if [ "$TOTAL_COUNT" -eq 0 ]; then
    echo "  ✅ No orphan files found!"
else
    echo "📊 Total: $TOTAL_COUNT orphan file(s)"
    echo ""
    echo "💡 Recommendations:"
    echo "  - Low risk: Consider adding REQ-ID or documenting purpose"
    echo "  - Medium risk: Review and link to appropriate requirement"
    echo "  - High risk: Must link to requirement before release"
fi
