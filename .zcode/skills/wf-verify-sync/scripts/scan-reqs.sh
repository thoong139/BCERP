#!/bin/bash
# Scan all REQ-IDs in codebase — đối chiếu docs vs code
# Usage: ./scan-reqs.sh [scope] [name]
#   scope: all | system | module
#   name: system/module name (e.g., erp, finance)

SCOPE=${1:-all}
NAME=${2:-}
ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
REGISTRY="$ROOT_DIR/.mc-data/docs/_meta/req-registry.json"

echo "=== REQ-ID Scanner ==="
echo "Scope: $SCOPE${NAME:+ ($NAME)}"
echo ""

# REQ-ID pattern — cả standard và extended format
REQ_PATTERN="REQ-[A-Z]+-([A-Z]+-)?[0-9]+"

# ──────────────────────────────────────────────
# Helper: build scope filter từ registry JSON (yêu cầu jq)
# ──────────────────────────────────────────────
build_scope_filter() {
    local registry="$1" scope="$2" name="$3"
    if ! command -v jq &>/dev/null; then
        echo "⚠️ jq không có sẵn — scope filter sẽ dùng text grep (kém chính xác hơn)" >&2
        echo ""
        return
    fi
    if [ "$scope" = "system" ] && [ -n "$name" ]; then
        # Tìm tất cả module_ids thuộc system, rồi lấy requirements của các modules đó
        jq -r --arg sys "$name" '
          .modules[]
          | select(.system_id == $sys)
          | .id
        ' "$registry" 2>/dev/null | while read -r mod_id; do
            jq -r --arg mod "$mod_id" '
              .requirements[]
              | select(.module_id == $mod)
              | .id
            ' "$registry" 2>/dev/null
        done | sort -u
    elif [ "$scope" = "module" ] && [ -n "$name" ]; then
        # Lấy trực tiếp requirements của module
        jq -r --arg mod "$name" '
          .requirements[]
          | select(.module_id == $mod)
          | .id
        ' "$registry" 2>/dev/null | sort -u
    fi
}

# ──────────────────────────────────────────────
# 1. Scan REQ-IDs từ SSOT (req-registry.json)
# ──────────────────────────────────────────────
echo "📋 REQ-IDs từ req-registry.json (SSOT):"
if [ -f "$REGISTRY" ]; then
    if [ "$SCOPE" = "module" ] && [ -n "$NAME" ]; then
        SCOPE_IDS=$(build_scope_filter "$REGISTRY" "module" "$NAME")
        if [ -n "$SCOPE_IDS" ]; then
            REGISTRY_IDS="$SCOPE_IDS"
        else
            # Fallback: grep-based (ít chính xác, dùng khi không có jq)
            REGISTRY_IDS=$(grep -oE "$REQ_PATTERN" "$REGISTRY" | grep -iE "${NAME/MOD-/}" | sort -u)
        fi
    elif [ "$SCOPE" = "system" ] && [ -n "$NAME" ]; then
        SCOPE_IDS=$(build_scope_filter "$REGISTRY" "system" "$NAME")
        if [ -n "$SCOPE_IDS" ]; then
            REGISTRY_IDS="$SCOPE_IDS"
        else
            # Fallback: grep-based (ít chính xác, dùng khi không có jq)
            REGISTRY_IDS=$(grep -oE "$REQ_PATTERN" "$REGISTRY" | grep -iE "${NAME/SYS-/}" | sort -u)
        fi
    else
        REGISTRY_IDS=$(grep -oE "$REQ_PATTERN" "$REGISTRY" | sort -u)
    fi

    if [ -n "$REGISTRY_IDS" ]; then
        echo "$REGISTRY_IDS" | while read -r id; do echo "  $id"; done
    else
        echo "  (không tìm thấy REQ-IDs)"
    fi
    REGISTRY_COUNT=$(echo "$REGISTRY_IDS" | grep -c . 2>/dev/null || echo 0)
    echo "  → Total: $REGISTRY_COUNT"
else
    echo "  ⚠️ req-registry.json không tồn tại: $REGISTRY"
    echo "  → Chạy /wf-analyze-requirements trước"
    REGISTRY_COUNT=0
fi
echo ""

# ──────────────────────────────────────────────
# 2. Scan REQ-IDs từ docs (features, departments)
# ──────────────────────────────────────────────
echo "📄 REQ-IDs trong .mc-data/docs/:"
DOCS_DIR="$ROOT_DIR/.mc-data/docs"
if [ -d "$DOCS_DIR" ]; then
    if [ "$SCOPE" = "module" ] && [ -n "$NAME" ]; then
        grep -rhE "$REQ_PATTERN" "$DOCS_DIR" 2>/dev/null | \
            grep -iE "$NAME" | grep -oE "$REQ_PATTERN" | sort | uniq -c | sort -rn
    elif [ "$SCOPE" = "system" ] && [ -n "$NAME" ]; then
        grep -rhE "$REQ_PATTERN" "$DOCS_DIR" 2>/dev/null | \
            grep -iE "$NAME" | grep -oE "$REQ_PATTERN" | sort | uniq -c | sort -rn
    else
        grep -rhE "$REQ_PATTERN" "$DOCS_DIR" 2>/dev/null | \
            grep -oE "$REQ_PATTERN" | sort | uniq -c | sort -rn
    fi
else
    echo "  ⚠️ Thư mục docs không tồn tại: $DOCS_DIR"
fi
echo ""

# ──────────────────────────────────────────────
# 3. Scan REQ-IDs trong code (src/ + apps/)
# ──────────────────────────────────────────────
CODE_PATTERN="// REQ-ID:|/\* REQ-ID:|# REQ-ID:|Description\(\"REQ-"

scan_code_dir() {
    local dir="$1"
    local label="$2"
    echo "💻 REQ-IDs trong $label:"
    if [ -d "$dir" ]; then
        if [ "$SCOPE" = "module" ] && [ -n "$NAME" ]; then
            grep -rhE "$CODE_PATTERN" "$dir" 2>/dev/null | \
                grep -iE "$NAME" | grep -oE "$REQ_PATTERN" | sort | uniq -c | sort -rn
        else
            grep -rhE "$CODE_PATTERN" "$dir" 2>/dev/null | \
                grep -oE "$REQ_PATTERN" | sort | uniq -c | sort -rn
        fi
    else
        echo "  ⚠️ Thư mục không tồn tại: $dir"
    fi
    echo ""
}

scan_code_dir "$ROOT_DIR/src" "src/"
scan_code_dir "$ROOT_DIR/apps" "apps/"

# ──────────────────────────────────────────────
# 4. Summary — deduplicated counts
# ──────────────────────────────────────────────
echo "📊 Summary:"

# Unique REQ-IDs từ docs (bao gồm registry)
DOCS_UNIQUE=$(grep -rhE "$REQ_PATTERN" "$ROOT_DIR/.mc-data/docs/" 2>/dev/null | \
    grep -oE "$REQ_PATTERN" | sort -u | wc -l)

# Unique REQ-IDs từ code (src + apps, deduplicated)
CODE_UNIQUE=$( {
    grep -rhE "$CODE_PATTERN" "$ROOT_DIR/src/" 2>/dev/null;
    grep -rhE "$CODE_PATTERN" "$ROOT_DIR/apps/" 2>/dev/null;
} | grep -oE "$REQ_PATTERN" | sort -u | wc -l)

echo "  Unique REQ-IDs in docs: $DOCS_UNIQUE"
echo "  Unique REQ-IDs in code: $CODE_UNIQUE"

if [ "$DOCS_UNIQUE" -gt 0 ]; then
    SYNC_RATE=$((CODE_UNIQUE * 100 / DOCS_UNIQUE))
    echo "  Sync Rate: ${SYNC_RATE}%"
else
    echo "  Sync Rate: N/A (no REQ-IDs in docs)"
fi
