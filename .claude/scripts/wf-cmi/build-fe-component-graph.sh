#!/usr/bin/env bash
# build-fe-component-graph.sh — Build fe-component-graph.json (Discovery Plugin #7)
# Part of wf-cmi v2.0 Phase 2 (Stage 2 — Vertical Slice Proof-of-Pattern)
#
# Usage: bash build-fe-component-graph.sh <SESSION_DIR> [SCOPE_ROOT]
#   SESSION_DIR  — Absolute path to session dir (mandatory)
#   SCOPE_ROOT   — Frontend root to scan (default: apps/erp-web/components)
#
# Output: $SESSION_DIR/phase2-discovery/fe-component-graph.json
#
# Skip conditions (write empty graph + exit 0):
#   - $SCOPE_ROOT directory does not exist
#   - No .tsx files found
#
# Error codes:
#   E137 — Project KHÔNG có erp-web (skip gracefully)
#   E138 — Parser fail (>20% files unparseable → ESCALATE)
#
# Parser version: 1.0 (Grep-based proof-of-pattern)
# Upgrade path v2.1: ts-morph or @typescript-eslint/parser for full AST props extraction.

set -euo pipefail

SESSION_DIR="${1:?SESSION_DIR mandatory}"
SCOPE_ROOT="${2:-apps/erp-web/components}"

# Resolve template path relative to script location (works từ bất kỳ cwd nào)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$SCRIPT_DIR/../../skills/workflow/wf-cmi/templates/fe-component-graph.json"

# Fallback to env override (cho integration test)
[ -n "${MCV3_CMI_FE_COMPONENT_TPL:-}" ] && TPL="$MCV3_CMI_FE_COMPONENT_TPL"

TARGET="$SESSION_DIR/phase2-discovery/fe-component-graph.json"
TMP="$TARGET.tmp.$$"

mkdir -p "$(dirname "$TARGET")"

# ============================================================================
# Helper: log message to stderr (script output goes to stdout)
# ============================================================================
log() {
  echo "[fe-component-graph] $*" >&2
}

die() {
  log "ERROR: $*"
  rm -f "$TMP"
  exit 1
}

# ============================================================================
# Helper: write empty/skipped graph
# ============================================================================
write_skipped_graph() {
  local reason="$1"
  log "SKIP: $reason"
  cat > "$TMP" <<EOF
{
  "\$schema": "fe-component-graph-v1",
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
    "tsx_file_count": 0,
    "skipped_files": [],
    "node_count": 0,
    "edge_count": 0,
    "modules_covered": [],
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
  write_skipped_graph "scope_root not found: $SCOPE_ROOT (project lacks erp-web frontend or scanning from wrong cwd)"
fi

TSX_FILES=$(find "$SCOPE_ROOT" -type f -name '*.tsx' 2>/dev/null || true)
if [ -z "$TSX_FILES" ]; then
  write_skipped_graph "No .tsx files found under $SCOPE_ROOT"
fi

TSX_COUNT=$(echo "$TSX_FILES" | wc -l | tr -d ' ')
log "Found $TSX_COUNT .tsx files under $SCOPE_ROOT"

# ============================================================================
# Step 1: Strip template metadata + initialize target structure
# ============================================================================
if [ ! -f "$TPL" ]; then
  die "Template not found: $TPL"
fi

jq 'del(._template_notes)' "$TPL" > "$TMP" || die "Template strip failed"

# ============================================================================
# Step 2: Build nodes — 1 entry per .tsx component file
# ============================================================================
log "Building nodes from .tsx files..."

NODES_TMP="$TARGET.nodes.tmp.$$"
SKIPPED_FILES_TMP="$TARGET.skipped.tmp.$$"
echo "[]" > "$NODES_TMP"
echo "[]" > "$SKIPPED_FILES_TMP"

PARSED_COUNT=0
SKIPPED_COUNT=0

while IFS= read -r tsx_file; do
  [ -z "$tsx_file" ] && continue

  # Component name = basename without .tsx
  COMPONENT_NAME=$(basename "$tsx_file" .tsx)

  # Module inference: extract first path segment after $SCOPE_ROOT
  REL_PATH="${tsx_file#$SCOPE_ROOT/}"
  MODULE=$(echo "$REL_PATH" | awk -F/ '{print $1}')

  # Read file content (max 200KB to avoid blowup)
  if [ ! -r "$tsx_file" ] || [ "$(wc -c < "$tsx_file" 2>/dev/null || echo 0)" -gt 204800 ]; then
    log "WARN: skip unreadable/oversized $tsx_file"
    SKIPPED_FILES_TMP_NEW=$(jq --arg f "$tsx_file" '. + [$f]' "$SKIPPED_FILES_TMP")
    echo "$SKIPPED_FILES_TMP_NEW" > "$SKIPPED_FILES_TMP"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  # Extract default export (Grep proof-of-pattern — AST upgrade in v2.1)
  DEFAULT_EXPORT=$( (grep -oE '^export default (function|const|class)? *([A-Za-z_][A-Za-z0-9_]*)' "$tsx_file" 2>/dev/null || true) \
                   | head -1 | sed -E 's/^export default (function|const|class)? *//')
  [ -z "$DEFAULT_EXPORT" ] && DEFAULT_EXPORT="null"

  # Extract named exports
  NAMED_EXPORTS_RAW=$( (grep -oE '^export (const|function|class|interface|type) +[A-Za-z_][A-Za-z0-9_]*' "$tsx_file" 2>/dev/null || true) \
                       | sed -E 's/^export (const|function|class|interface|type) +//')
  if [ -z "$NAMED_EXPORTS_RAW" ]; then
    NAMED_EXPORTS="[]"
  else
    NAMED_EXPORTS=$(echo "$NAMED_EXPORTS_RAW" | jq -R . | jq -s 'unique' 2>/dev/null || echo "[]")
  fi

  # Extract props (proof-of-pattern: find interface PropsName / type PropsName)
  # Limit to first 50 lines of props block
  PROPS_LINES=$( (awk '/^(interface|type) [A-Za-z]+Props/,/^[}]/' "$tsx_file" 2>/dev/null || true) \
                | head -50 \
                | (grep -oE '^[[:space:]]+[a-z_][A-Za-z0-9_]*(\?)?: *[^;]+' || true) \
                | sed -E 's/^[[:space:]]+//')
  if [ -z "$PROPS_LINES" ]; then
    PROPS="[]"
  else
    PROPS=$(echo "$PROPS_LINES" \
            | awk -F: '{
                gsub(/^ +| +$/, "", $1);
                gsub(/^ +| +$/, "", $2);
                required = ($1 !~ /\?$/) ? "true" : "false";
                gsub(/\?$/, "", $1);
                printf "{\"name\":\"%s\",\"type\":\"%s\",\"required\":%s,\"default_value\":null,\"jsdoc_description\":null}\n", $1, $2, required;
              }' \
            | jq -s 'unique_by(.name)' 2>/dev/null || echo "[]")
  fi
  [ -z "$PROPS" ] && PROPS="[]"

  # Compute fingerprint (sha256 of file content, 12-char prefix)
  if command -v sha256sum > /dev/null 2>&1; then
    FINGERPRINT=$(sha256sum "$tsx_file" | cut -c1-12)
  elif command -v shasum > /dev/null 2>&1; then
    FINGERPRINT=$(shasum -a 256 "$tsx_file" | cut -c1-12)
  else
    FINGERPRINT="nohash"
  fi

  # Build node JSON
  NODE=$(jq -n \
    --arg id "$REL_PATH" \
    --arg name "$COMPONENT_NAME" \
    --arg module "$MODULE" \
    --arg fp "$tsx_file" \
    --arg de "$DEFAULT_EXPORT" \
    --argjson ne "$NAMED_EXPORTS" \
    --argjson props "$PROPS" \
    --arg fpr "$FINGERPRINT" \
    '{
      id: $id,
      name: $name,
      module: $module,
      file_path: $fp,
      props: $props,
      default_export: (if $de == "null" then null else $de end),
      named_exports: $ne,
      fingerprint: $fpr
    }')

  # Append to nodes array (atomic)
  jq --argjson n "$NODE" '. + [$n]' "$NODES_TMP" > "$NODES_TMP.next"
  mv "$NODES_TMP.next" "$NODES_TMP"

  PARSED_COUNT=$((PARSED_COUNT + 1))
done <<< "$TSX_FILES"

log "Parsed $PARSED_COUNT nodes, skipped $SKIPPED_COUNT files"

# Parser fail threshold check (E138)
if [ "$TSX_COUNT" -gt 0 ]; then
  FAIL_PCT=$(( SKIPPED_COUNT * 100 / TSX_COUNT ))
  if [ "$FAIL_PCT" -gt 20 ]; then
    log "WARN E138: parser fail rate $FAIL_PCT% > 20% threshold"
  fi
fi

# ============================================================================
# Step 3: Build edges — internal component imports
# ============================================================================
log "Building edges from internal imports..."

EDGES_TMP="$TARGET.edges.tmp.$$"
echo "[]" > "$EDGES_TMP"

while IFS= read -r tsx_file; do
  [ -z "$tsx_file" ] && continue

  FROM_REL_PATH="${tsx_file#$SCOPE_ROOT/}"
  FROM_DIR=$(dirname "$tsx_file")

  # Extract import statements (relative imports starting with . or @/)
  # grep no-match exits 1 → || true để không kill script (set -e)
  IMPORT_LINES=$(grep -oE '^import .+ from ['"'"'"][\./@][^'"'"'"]+[\'"'"'"]' "$tsx_file" 2>/dev/null || true)
  [ -z "$IMPORT_LINES" ] && continue

  echo "$IMPORT_LINES" \
    | while read -r import_line; do
        [ -z "$import_line" ] && continue
        # Extract import target
        TARGET_PATH=$(echo "$import_line" | grep -oE '[\'"'"'"][^\'"'"'"]+[\'"'"'"]$' | tr -d "'\"")

        # Skip external (node_modules) imports — only @/ aliased or relative
        case "$TARGET_PATH" in
          @/*|./*|../*) ;;  # internal
          *) continue ;;     # external — skip
        esac

        # Determine import kind
        if echo "$import_line" | grep -qE '^import [A-Za-z_]'; then
          IMPORT_KIND="default"
        elif echo "$import_line" | grep -qE '^import \{'; then
          IMPORT_KIND="named"
        elif echo "$import_line" | grep -qE '^import \* as'; then
          IMPORT_KIND="namespace"
        else
          IMPORT_KIND="unknown"
        fi

        # Normalize target (strip @/ alias to root)
        case "$TARGET_PATH" in
          @/*) TO_REL="${TARGET_PATH#@/}" ;;
          *)   TO_REL=$(realpath -m --relative-to="$SCOPE_ROOT" "$FROM_DIR/$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH") ;;
        esac

        EDGE=$(jq -n \
          --arg from "$FROM_REL_PATH" \
          --arg to "$TO_REL" \
          --arg kind "$IMPORT_KIND" \
          --argjson internal true \
          '{from_component: $from, to_component: $to, import_kind: $kind, is_internal: $internal}')

        jq --argjson e "$EDGE" '. + [$e]' "$EDGES_TMP" > "$EDGES_TMP.next"
        mv "$EDGES_TMP.next" "$EDGES_TMP"
      done
done <<< "$TSX_FILES"

EDGE_COUNT=$(jq 'length' "$EDGES_TMP")
log "Built $EDGE_COUNT edges"

# ============================================================================
# Step 4: Compute modules_covered
# ============================================================================
MODULES_COVERED=$(jq '[.[].module] | unique' "$NODES_TMP")

# ============================================================================
# Step 5: Populate target JSON
# ============================================================================
log "Populating target $TARGET"

NODES_JSON=$(cat "$NODES_TMP")
EDGES_JSON=$(cat "$EDGES_TMP")
SKIPPED_JSON=$(cat "$SKIPPED_FILES_TMP")

jq \
  --arg sid "${SESSION_ID:-unknown}" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg src "${SOURCE_METHOD:-grep_fallback}" \
  --arg freshness "${CI_FRESHNESS:-unknown}" \
  --argjson nodes "$NODES_JSON" \
  --argjson edges "$EDGES_JSON" \
  --argjson skipped "$SKIPPED_JSON" \
  --argjson modules "$MODULES_COVERED" \
  --argjson tsx_count "$TSX_COUNT" \
  --argjson node_count "$PARSED_COUNT" \
  --argjson edge_count "$EDGE_COUNT" \
  '. + {
    session_id: $sid,
    generated_at: $ts,
    nodes: $nodes,
    edges: $edges,
    metadata: (.metadata + {
      build_at: $ts,
      source_method: $src,
      ci_index_freshness: $freshness,
      tsx_file_count: $tsx_count,
      skipped_files: $skipped,
      node_count: $node_count,
      edge_count: $edge_count,
      modules_covered: $modules
    })
  }' "$TMP" > "$TMP.populated"
mv "$TMP.populated" "$TMP"

# ============================================================================
# Step 6: Validate + atomic write
# ============================================================================
jq -e '.["$schema"] == "fe-component-graph-v1"' "$TMP" > /dev/null \
  || die "Schema validation failed"
jq -e '.nodes | type == "array"' "$TMP" > /dev/null \
  || die "nodes[] not array"
jq -e '.edges | type == "array"' "$TMP" > /dev/null \
  || die "edges[] not array"

mv "$TMP" "$TARGET"
rm -f "$NODES_TMP" "$EDGES_TMP" "$SKIPPED_FILES_TMP"

log "DONE: $TARGET (nodes=$PARSED_COUNT, edges=$EDGE_COUNT, modules=$(echo "$MODULES_COVERED" | jq 'length'))"
