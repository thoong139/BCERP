#!/usr/bin/env bash
# build-fe-route-graph.sh — Build fe-route-graph.json (Discovery Plugin #10)
# Part of wf-cmi v2.0 Phase 2 (Stage 2.1 — FE plugin graphs)
#
# Usage: bash build-fe-route-graph.sh <SESSION_DIR> [SCOPE_ROOT]
#   SESSION_DIR  — Absolute path to session dir (mandatory)
#   SCOPE_ROOT   — Next.js App Router root (default: apps/erp-web/app)
#
# Output: $SESSION_DIR/phase2-discovery/fe-route-graph.json
#
# Detect (filesystem v1.0):
#   - page.tsx / page.ts            → route segment
#   - layout.tsx / layout.ts        → wrapper
#   - middleware.ts                 → global middleware (only at scope_root parent)
#   - loading.tsx / error.tsx       → loading & error boundaries
#   - not-found.tsx / template.tsx  → 404 + template wrapper
#   - [param] segments              → dynamic params
#   - (group) segments              → route groups (don't appear in URL)
#   - (protected) group convention  → is_protected=true
#
# Error codes:
#   E137 — Project KHÔNG có App Router (skip gracefully)
#   E138 — Builder fail (>20% files unparseable → WARN)
#
# Parser version: 1.0 (filesystem-based — KHÔNG cần AST)
# Upgrade path v2.1: AST parse cho generateMetadata() exports + dynamic data fetching.

set -euo pipefail

SESSION_DIR="${1:?SESSION_DIR mandatory}"
SCOPE_ROOT="${2:-apps/erp-web/app}"

# Git Bash for Windows POSIX path conversion workaround:
# Route paths starting with `/` get auto-converted to Windows paths (e.g. /dashboard → C:/Program Files/Git/dashboard).
# Even JSON-encoded values like "/dashboard" inside quoted strings still get converted by MSYS heuristics.
# Solution: prepend a sentinel tag that doesn't trigger MSYS path conversion; strip it inside jq.
ROUTE_TAG="ROUTEv1:::"
strip_route_tag_filter='($r | sub("^ROUTEv1:::"; ""))'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$SCRIPT_DIR/../../skills/workflow/wf-cmi/templates/fe-route-graph.json"
[ -n "${MCV3_CMI_FE_ROUTE_TPL:-}" ] && TPL="$MCV3_CMI_FE_ROUTE_TPL"

TARGET="$SESSION_DIR/phase2-discovery/fe-route-graph.json"
TMP="$TARGET.tmp.$$"

mkdir -p "$(dirname "$TARGET")"

log() { echo "[fe-route-graph] $*" >&2; }

die() {
  log "ERROR: $*"
  rm -f "$TMP" "$TARGET.nodes.tmp.$$" "$TARGET.skipped.tmp.$$"
  exit 1
}

write_skipped_graph() {
  local reason="$1"
  log "SKIP: $reason"
  cat > "$TMP" <<EOF
{
  "\$schema": "fe-route-graph-v1",
  "session_id": "${SESSION_ID:-unknown}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scope": {"type": "system", "scope_root": "$SCOPE_ROOT", "client_apps": []},
  "nodes": [],
  "edges": [],
  "metadata": {
    "build_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "scope_root": "$SCOPE_ROOT",
    "source_method": "skipped",
    "ci_index_freshness": "${CI_FRESHNESS:-unknown}",
    "parser_version": "1.0",
    "scanned_file_count": 0,
    "skipped_files": [],
    "node_count": 0,
    "edge_count": 0,
    "modules_covered": [],
    "route_count_by_kind": {"page": 0, "layout": 0, "middleware": 0, "loading": 0, "error": 0, "not-found": 0, "template": 0},
    "dynamic_route_count": 0,
    "protected_route_count": 0,
    "skipped": true,
    "skip_reason": "$reason"
  }
}
EOF
  jq -e '.' "$TMP" > /dev/null || die "Skipped graph JSON invalid"
  mv "$TMP" "$TARGET"
  log "Wrote skipped graph to $TARGET"
  exit 0
}

# ============================================================================
# Skip detection
# ============================================================================
if [ ! -d "$SCOPE_ROOT" ]; then
  write_skipped_graph "scope_root not found: $SCOPE_ROOT (project lacks Next.js App Router)"
fi

# Discover route files (special filenames)
ROUTE_FILES=$(find "$SCOPE_ROOT" \
  -type d \( -name node_modules -o -name .next -o -name dist -o -name build -o -name .turbo \) -prune \
  -o -type f \( \
       -name 'page.tsx' -o -name 'page.ts' \
       -o -name 'layout.tsx' -o -name 'layout.ts' \
       -o -name 'loading.tsx' -o -name 'loading.ts' \
       -o -name 'error.tsx' -o -name 'error.ts' \
       -o -name 'not-found.tsx' -o -name 'not-found.ts' \
       -o -name 'template.tsx' -o -name 'template.ts' \
     \) -print 2>/dev/null || true)

# Also try middleware.ts (usually at parent of scope_root, e.g. apps/erp-web/middleware.ts)
PARENT_DIR=$(dirname "$SCOPE_ROOT")
MIDDLEWARE_FILE=""
if [ -f "$PARENT_DIR/middleware.ts" ]; then
  MIDDLEWARE_FILE="$PARENT_DIR/middleware.ts"
elif [ -f "$PARENT_DIR/middleware.tsx" ]; then
  MIDDLEWARE_FILE="$PARENT_DIR/middleware.tsx"
fi

if [ -z "$ROUTE_FILES" ] && [ -z "$MIDDLEWARE_FILE" ]; then
  write_skipped_graph "No App Router route files found under $SCOPE_ROOT (project may use Pages Router)"
fi

# Combine: route files + middleware
ALL_FILES="$ROUTE_FILES"
[ -n "$MIDDLEWARE_FILE" ] && ALL_FILES=$(printf '%s\n%s' "$ROUTE_FILES" "$MIDDLEWARE_FILE")
ALL_FILES=$(echo "$ALL_FILES" | grep -v '^$' || true)

TOTAL_COUNT=$(echo "$ALL_FILES" | wc -l | tr -d ' ')
log "Found $TOTAL_COUNT route/middleware files (scope_root=$SCOPE_ROOT, middleware=$MIDDLEWARE_FILE)"

# ============================================================================
# Step 1: Strip template metadata
# ============================================================================
if [ ! -f "$TPL" ]; then
  die "Template not found: $TPL"
fi

jq 'del(._template_notes)' "$TPL" > "$TMP" || die "Template strip failed"

# ============================================================================
# Step 2: Build nodes
# ============================================================================
log "Building route nodes..."

NODES_TMP="$TARGET.nodes.tmp.$$"
SKIPPED_FILES_TMP="$TARGET.skipped.tmp.$$"
echo "[]" > "$NODES_TMP"
echo "[]" > "$SKIPPED_FILES_TMP"

SCANNED_COUNT=0
SKIPPED_COUNT=0
PAGE_COUNT=0
LAYOUT_COUNT=0
MW_COUNT=0
LOADING_COUNT=0
ERROR_COUNT=0
NOTFOUND_COUNT=0
TEMPLATE_COUNT=0
DYNAMIC_COUNT=0
PROTECTED_COUNT=0

# Helper: derive route path from filesystem path
# - Strip scope_root prefix
# - Strip filename
# - Drop (group) segments (don't affect URL)
# - Keep [param] segments
derive_route_path() {
  local file="$1"
  local rel="${file#$SCOPE_ROOT/}"
  local dir
  dir=$(dirname "$rel")
  [ "$dir" = "." ] && dir=""

  # Drop (group) segments from URL
  local cleaned=""
  IFS='/' read -ra SEGMENTS <<< "$dir"
  for seg in "${SEGMENTS[@]}"; do
    [ -z "$seg" ] && continue
    case "$seg" in
      \(*\)) ;;  # route group — skip
      *) cleaned="${cleaned}/${seg}" ;;
    esac
  done

  [ -z "$cleaned" ] && cleaned="/"
  echo "$cleaned"
}

# Helper: extract dynamic params from path
extract_dynamic_params() {
  local route="$1"
  echo "$route" | grep -oE '\[[^]]+\]' | sed -E 's/^\[\.{0,3}//; s/\]$//' | jq -R . | jq -s '.'
}

# Helper: detect if path is inside (protected) group
is_protected_path() {
  local file="$1"
  if echo "$file" | grep -qE '/\(protected\)/'; then
    echo "true"
  else
    echo "false"
  fi
}

# Helper: derive module from first non-group, non-locale segment
derive_module() {
  local route="$1"
  local first=$(echo "$route" | sed -E 's|^/||' | cut -d/ -f1)
  # Skip locale-like segments (en|vi|cn|zh|fr|...)
  case "$first" in
    [a-z][a-z])
      # Two-letter locale, take second segment
      echo "$route" | sed -E 's|^/[a-z]+/||' | cut -d/ -f1
      ;;
    *) echo "$first" ;;
  esac
}

while IFS= read -r f; do
  [ -z "$f" ] && continue
  SCANNED_COUNT=$((SCANNED_COUNT + 1))

  if [ ! -r "$f" ]; then
    log "WARN: skip unreadable $f"
    SKIPPED_FILES_TMP_NEW=$(jq --arg p "$f" '. + [$p]' "$SKIPPED_FILES_TMP")
    echo "$SKIPPED_FILES_TMP_NEW" > "$SKIPPED_FILES_TMP"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  BASENAME=$(basename "$f")
  KIND=""
  case "$BASENAME" in
    page.tsx|page.ts) KIND="page" ;;
    layout.tsx|layout.ts) KIND="layout" ;;
    loading.tsx|loading.ts) KIND="loading" ;;
    error.tsx|error.ts) KIND="error" ;;
    not-found.tsx|not-found.ts) KIND="not-found" ;;
    template.tsx|template.ts) KIND="template" ;;
    middleware.ts|middleware.tsx) KIND="middleware" ;;
    *) continue ;;
  esac

  # Special handling for middleware (lives outside scope_root)
  if [ "$KIND" = "middleware" ]; then
    REL_PATH="${f#$PARENT_DIR/}"
    ROUTE_PATH="*"   # middleware applies to all routes by default
    MODULE="middleware"
    IS_DYNAMIC="false"
    DYN_PARAMS="[]"
    IS_PROTECTED="false"
  else
    REL_PATH="${f#$SCOPE_ROOT/}"
    ROUTE_PATH=$(derive_route_path "$f")
    MODULE=$(derive_module "$ROUTE_PATH")
    [ -z "$MODULE" ] && MODULE="root"

    if echo "$ROUTE_PATH" | grep -qE '\['; then
      IS_DYNAMIC="true"
      DYN_PARAMS=$(extract_dynamic_params "$ROUTE_PATH")
      DYNAMIC_COUNT=$((DYNAMIC_COUNT + 1))
    else
      IS_DYNAMIC="false"
      DYN_PARAMS="[]"
    fi

    IS_PROTECTED=$(is_protected_path "$f")
    [ "$IS_PROTECTED" = "true" ] && PROTECTED_COUNT=$((PROTECTED_COUNT + 1))
  fi

  # Component name = parent dir name (Pascal-ish) or 'Root' if at scope root
  PARENT_NAME=$(basename "$(dirname "$f")")
  case "$PARENT_NAME" in
    app|"") COMPONENT_NAME="Root${KIND^}" ;;
    *) COMPONENT_NAME="${PARENT_NAME}${KIND^}" ;;
  esac

  if command -v sha256sum > /dev/null 2>&1; then
    FILE_FP=$(sha256sum "$f" | cut -c1-12)
  elif command -v shasum > /dev/null 2>&1; then
    FILE_FP=$(shasum -a 256 "$f" | cut -c1-12)
  else
    FILE_FP="nohash"
  fi

  # Per-kind counter
  case "$KIND" in
    page) PAGE_COUNT=$((PAGE_COUNT + 1)) ;;
    layout) LAYOUT_COUNT=$((LAYOUT_COUNT + 1)) ;;
    middleware) MW_COUNT=$((MW_COUNT + 1)) ;;
    loading) LOADING_COUNT=$((LOADING_COUNT + 1)) ;;
    error) ERROR_COUNT=$((ERROR_COUNT + 1)) ;;
    not-found) NOTFOUND_COUNT=$((NOTFOUND_COUNT + 1)) ;;
    template) TEMPLATE_COUNT=$((TEMPLATE_COUNT + 1)) ;;
  esac

  # Tag route path with sentinel prefix to bypass Git Bash MSYS path conversion
  ROUTE_TAGGED="${ROUTE_TAG}${ROUTE_PATH}"

  NODE=$(jq -n \
    --arg id "$REL_PATH" \
    --arg name "$COMPONENT_NAME" \
    --arg kind "$KIND" \
    --arg r "$ROUTE_TAGGED" \
    --arg module "$MODULE" \
    --arg fp "$f" \
    --arg is_dyn "$IS_DYNAMIC" \
    --argjson params "$DYN_PARAMS" \
    --arg is_prot "$IS_PROTECTED" \
    --arg fpr "$FILE_FP" \
    '{
      id: $id,
      name: $name,
      kind: $kind,
      route_path: ($r | sub("^ROUTEv1:::"; "")),
      module: $module,
      file_path: $fp,
      is_dynamic: ($is_dyn == "true"),
      dynamic_params: $params,
      is_protected: ($is_prot == "true"),
      fingerprint: $fpr
    }')
  jq --argjson n "$NODE" '. + [$n]' "$NODES_TMP" > "$NODES_TMP.next"
  mv "$NODES_TMP.next" "$NODES_TMP"
done <<< "$ALL_FILES"

NODE_COUNT=$(jq 'length' "$NODES_TMP")
log "Built $NODE_COUNT nodes (page=$PAGE_COUNT, layout=$LAYOUT_COUNT, mw=$MW_COUNT, loading=$LOADING_COUNT, error=$ERROR_COUNT, 404=$NOTFOUND_COUNT, template=$TEMPLATE_COUNT, dynamic=$DYNAMIC_COUNT, protected=$PROTECTED_COUNT)"

# ============================================================================
# Step 3: Build edges — route hierarchy
# ============================================================================
log "Building edges from route hierarchy..."

# Strategy:
# - For each page/layout/loading/error/template route, parent = directly enclosing layout
# - Middleware → wraps all matched routes (1 generic edge per protected route)
EDGES_JSON=$(jq '
  # Compute parent of each route_path (drop last segment, fall back to "/")
  def parent_route(p):
    if p == "/" then null
    elif (p | split("/") | length) <= 2 then "/"
    else (p | split("/") | .[:-1] | join("/"))
    end;

  # Layout route paths (set lookup via any/contains)
  ([.[] | select(.kind == "layout") | .route_path]) as $layout_routes
  |
  (
    # child_of edges: parent path → child path
    [.[]
     | select(.kind != "middleware")
     | . as $cur
     | parent_route($cur.route_path) as $par
     | select($par != null)
     | {from_route: $par, to_route: $cur.route_path, kind: "child_of"}
    ]
    +
    # wrapped_by edges: page/loading/error wrapped by enclosing layout at same path
    [.[]
     | select(.kind == "page" or .kind == "loading" or .kind == "error")
     | . as $cur
     | select($layout_routes | index($cur.route_path) != null)
     | {from_route: $cur.route_path, to_route: $cur.route_path, kind: "wrapped_by"}
    ]
  )
  | unique
' "$NODES_TMP")

EDGE_COUNT=$(echo "$EDGES_JSON" | jq 'length')
log "Built $EDGE_COUNT edges"

# ============================================================================
# Step 4: Modules covered
# ============================================================================
MODULES_COVERED=$(jq '[.[].module] | map(select(. != "middleware")) | unique' "$NODES_TMP")
SKIPPED_JSON=$(cat "$SKIPPED_FILES_TMP")
NODES_JSON=$(cat "$NODES_TMP")

# ============================================================================
# Step 5: Populate target JSON
# ============================================================================
log "Populating target $TARGET"

jq \
  --arg sid "${SESSION_ID:-unknown}" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg src "${SOURCE_METHOD:-glob_filesystem}" \
  --arg freshness "${CI_FRESHNESS:-unknown}" \
  --argjson nodes "$NODES_JSON" \
  --argjson edges "$EDGES_JSON" \
  --argjson skipped "$SKIPPED_JSON" \
  --argjson modules "$MODULES_COVERED" \
  --argjson scanned "$SCANNED_COUNT" \
  --argjson node_count "$NODE_COUNT" \
  --argjson edge_count "$EDGE_COUNT" \
  --argjson page "$PAGE_COUNT" \
  --argjson layout "$LAYOUT_COUNT" \
  --argjson middleware "$MW_COUNT" \
  --argjson loading "$LOADING_COUNT" \
  --argjson err "$ERROR_COUNT" \
  --argjson notfound "$NOTFOUND_COUNT" \
  --argjson template "$TEMPLATE_COUNT" \
  --argjson dyn "$DYNAMIC_COUNT" \
  --argjson prot "$PROTECTED_COUNT" \
  '. + {
    session_id: $sid,
    generated_at: $ts,
    nodes: $nodes,
    edges: $edges,
    metadata: (.metadata + {
      build_at: $ts,
      source_method: $src,
      ci_index_freshness: $freshness,
      scanned_file_count: $scanned,
      skipped_files: $skipped,
      node_count: $node_count,
      edge_count: $edge_count,
      modules_covered: $modules,
      route_count_by_kind: {
        page: $page,
        layout: $layout,
        middleware: $middleware,
        loading: $loading,
        error: $err,
        "not-found": $notfound,
        template: $template
      },
      dynamic_route_count: $dyn,
      protected_route_count: $prot
    })
  }' "$TMP" > "$TMP.populated"
mv "$TMP.populated" "$TMP"

# ============================================================================
# Step 6: Validate + atomic write
# ============================================================================
jq -e '.["$schema"] == "fe-route-graph-v1"' "$TMP" > /dev/null \
  || die "Schema validation failed"
jq -e '.nodes | type == "array"' "$TMP" > /dev/null \
  || die "nodes[] not array"
jq -e '.edges | type == "array"' "$TMP" > /dev/null \
  || die "edges[] not array"

mv "$TMP" "$TARGET"
rm -f "$NODES_TMP" "$SKIPPED_FILES_TMP"

log "DONE: $TARGET (nodes=$NODE_COUNT, edges=$EDGE_COUNT, modules=$(echo "$MODULES_COVERED" | jq 'length'))"
