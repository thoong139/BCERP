#!/usr/bin/env bash
# build-fe-permission-graph.sh — Build fe-permission-graph.json (Discovery Plugin #9)
# Part of wf-cmi v2.0 Phase 2 (Stage 2.1 — FE plugin graphs)
#
# Usage: bash build-fe-permission-graph.sh <SESSION_DIR> [SCOPE_ROOT]
#   SESSION_DIR  — Absolute path to session dir (mandatory)
#   SCOPE_ROOT   — Frontend root to scan (default: apps/erp-web)
#
# Output: $SESSION_DIR/phase2-discovery/fe-permission-graph.json
#
# Detect patterns (Grep v1.0):
#   - <PermissionGate permission="...">  or  <PermissionGate permissions={["..."]}>
#   - usePermission("...") or usePermission(["..."])
#   - <Can permission="...">  or  <Can do="..." on="...">
#   - hasPermission("...") imperative calls
#   - Route middleware: requireAuth/withAuth/authorize HOCs
#
# Error codes:
#   E137 — Project KHÔNG có erp-web (skip gracefully)
#   E138 — Parser fail (>20% files unparseable → WARN)
#
# Parser version: 1.0 (Grep-based proof-of-pattern)
# Upgrade path v2.1: ts-morph to resolve dynamic permission expressions.

set -euo pipefail

SESSION_DIR="${1:?SESSION_DIR mandatory}"
SCOPE_ROOT="${2:-apps/erp-web}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$SCRIPT_DIR/../../skills/workflow/wf-cmi/templates/fe-permission-graph.json"
[ -n "${MCV3_CMI_FE_PERMISSION_TPL:-}" ] && TPL="$MCV3_CMI_FE_PERMISSION_TPL"

TARGET="$SESSION_DIR/phase2-discovery/fe-permission-graph.json"
TMP="$TARGET.tmp.$$"

mkdir -p "$(dirname "$TARGET")"

log() { echo "[fe-permission-graph] $*" >&2; }

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
  "\$schema": "fe-permission-graph-v1",
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
    "unique_permissions_used": 0,
    "guard_patterns_distribution": {"PermissionGate": 0, "usePermission": 0, "Can": 0, "hasPermission": 0, "authorize_middleware": 0, "unknown": 0},
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

TS_FILES=$(find "$SCOPE_ROOT" \
  -type d \( -name node_modules -o -name .next -o -name dist -o -name build -o -name .turbo \) -prune \
  -o -type f \( -name '*.ts' -o -name '*.tsx' \) -print 2>/dev/null || true)

if [ -z "$TS_FILES" ]; then
  write_skipped_graph "No .ts/.tsx files found under $SCOPE_ROOT"
fi

TS_COUNT=$(echo "$TS_FILES" | wc -l | tr -d ' ')
log "Found $TS_COUNT .ts/.tsx files under $SCOPE_ROOT"

# ============================================================================
# Step 1: Strip template metadata
# ============================================================================
if [ ! -f "$TPL" ]; then
  die "Template not found: $TPL"
fi

jq 'del(._template_notes)' "$TPL" > "$TMP" || die "Template strip failed"

# ============================================================================
# Step 2: Build nodes — scan for permission guard patterns
# ============================================================================
log "Scanning files for permission guard patterns..."

NODES_TMP="$TARGET.nodes.tmp.$$"
SKIPPED_FILES_TMP="$TARGET.skipped.tmp.$$"
echo "[]" > "$NODES_TMP"
echo "[]" > "$SKIPPED_FILES_TMP"

SCANNED_COUNT=0
SKIPPED_COUNT=0
PG_COUNT=0
UP_COUNT=0
CAN_COUNT=0
HP_COUNT=0
MW_COUNT=0
UNK_COUNT=0

# Helper to emit a node
emit_node() {
  local rel="$1" line="$2" name="$3" kind="$4" module="$5" file="$6" perm="$7" pattern="$8" fp="$9"
  local node
  node=$(jq -n \
    --arg id "${rel}:${line}:${name}:${perm}" \
    --arg name "$name" \
    --arg kind "$kind" \
    --arg module "$module" \
    --arg fp "$file" \
    --argjson line "$line" \
    --arg perm "$perm" \
    --arg pattern "$pattern" \
    --arg fpr "$fp" \
    '{
      id: $id,
      name: $name,
      kind: $kind,
      module: $module,
      file_path: $fp,
      line: $line,
      permission: $perm,
      guard_pattern: $pattern,
      fingerprint: $fpr
    }')
  jq --argjson n "$node" '. + [$n]' "$NODES_TMP" > "$NODES_TMP.next"
  mv "$NODES_TMP.next" "$NODES_TMP"
}

while IFS= read -r f; do
  [ -z "$f" ] && continue
  SCANNED_COUNT=$((SCANNED_COUNT + 1))

  if [ ! -r "$f" ] || [ "$(wc -c < "$f" 2>/dev/null || echo 0)" -gt 512000 ]; then
    log "WARN: skip unreadable/oversized $f"
    SKIPPED_FILES_TMP_NEW=$(jq --arg p "$f" '. + [$p]' "$SKIPPED_FILES_TMP")
    echo "$SKIPPED_FILES_TMP_NEW" > "$SKIPPED_FILES_TMP"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  REL_PATH="${f#$SCOPE_ROOT/}"
  MODULE=$(echo "$REL_PATH" | awk -F/ '{print $1}')
  FILE_BASENAME=$(basename "$f" | sed -E 's/\.(tsx?|ts)$//')

  if command -v sha256sum > /dev/null 2>&1; then
    FILE_FP=$(sha256sum "$f" | cut -c1-12)
  elif command -v shasum > /dev/null 2>&1; then
    FILE_FP=$(shasum -a 256 "$f" | cut -c1-12)
  else
    FILE_FP="nohash"
  fi

  # --------------------------------------------------------------
  # Pattern A: <PermissionGate permission="...">
  # --------------------------------------------------------------
  PG_HITS=$(grep -nE '<PermissionGate[[:space:]]+[^>]*permission' "$f" 2>/dev/null || true)
  if [ -n "$PG_HITS" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      LN=$(echo "$line" | cut -d: -f1)
      PERM=$(echo "$line" | grep -oE "permission=['\"][^'\"]+['\"]" 2>/dev/null | head -1 | sed -E "s/permission=['\"]//; s/['\"]$//" || true)
      [ -z "$PERM" ] && PERM="unknown"
      emit_node "$REL_PATH" "$LN" "$FILE_BASENAME" "component_render" "$MODULE" "$f" "$PERM" "PermissionGate" "$FILE_FP"
      PG_COUNT=$((PG_COUNT + 1))
    done <<< "$PG_HITS"
  fi

  # --------------------------------------------------------------
  # Pattern B: usePermission("...")
  # --------------------------------------------------------------
  UP_HITS=$(grep -nE 'usePermission[[:space:]]*\(' "$f" 2>/dev/null || true)
  if [ -n "$UP_HITS" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      LN=$(echo "$line" | cut -d: -f1)
      PERM=$(echo "$line" | grep -oE "usePermission[[:space:]]*\([[:space:]]*['\"][^'\"]+['\"]" 2>/dev/null | head -1 | grep -oE "['\"][^'\"]+['\"]" 2>/dev/null | tail -1 | tr -d "'\"" || true)
      [ -z "$PERM" ] && PERM="dynamic_or_variable"
      emit_node "$REL_PATH" "$LN" "$FILE_BASENAME" "hook_call" "$MODULE" "$f" "$PERM" "usePermission" "$FILE_FP"
      UP_COUNT=$((UP_COUNT + 1))
    done <<< "$UP_HITS"
  fi

  # --------------------------------------------------------------
  # Pattern C: <Can permission="..."> or <Can do="..." on="...">
  # --------------------------------------------------------------
  CAN_HITS=$(grep -nE '<Can[[:space:]]+[^>]*(permission|do)=' "$f" 2>/dev/null || true)
  if [ -n "$CAN_HITS" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      LN=$(echo "$line" | cut -d: -f1)
      # Try permission= attribute first, then do= / on= combo
      PERM=$(echo "$line" | grep -oE "permission=['\"][^'\"]+['\"]" 2>/dev/null | head -1 | sed -E "s/permission=['\"]//; s/['\"]$//" || true)
      if [ -z "$PERM" ]; then
        DO_ATTR=$(echo "$line" | grep -oE "do=['\"][^'\"]+['\"]" 2>/dev/null | head -1 | sed -E "s/do=['\"]//; s/['\"]$//" || true)
        ON_ATTR=$(echo "$line" | grep -oE "on=['\"][^'\"]+['\"]" 2>/dev/null | head -1 | sed -E "s/on=['\"]//; s/['\"]$//" || true)
        if [ -n "$DO_ATTR" ] && [ -n "$ON_ATTR" ]; then
          PERM="${ON_ATTR}.${DO_ATTR}"
        else
          PERM="${DO_ATTR:-unknown}"
        fi
      fi
      emit_node "$REL_PATH" "$LN" "$FILE_BASENAME" "component_render" "$MODULE" "$f" "$PERM" "Can" "$FILE_FP"
      CAN_COUNT=$((CAN_COUNT + 1))
    done <<< "$CAN_HITS"
  fi

  # --------------------------------------------------------------
  # Pattern D: hasPermission("...") imperative
  # --------------------------------------------------------------
  HP_HITS=$(grep -nE '\bhasPermission[[:space:]]*\([[:space:]]*['\''"]' "$f" 2>/dev/null || true)
  if [ -n "$HP_HITS" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      LN=$(echo "$line" | cut -d: -f1)
      PERM=$(echo "$line" | grep -oE "hasPermission[[:space:]]*\([[:space:]]*['\"][^'\"]+['\"]" 2>/dev/null | head -1 | grep -oE "['\"][^'\"]+['\"]" 2>/dev/null | tail -1 | tr -d "'\"" || true)
      [ -z "$PERM" ] && PERM="dynamic_or_variable"
      emit_node "$REL_PATH" "$LN" "$FILE_BASENAME" "imperative_check" "$MODULE" "$f" "$PERM" "hasPermission" "$FILE_FP"
      HP_COUNT=$((HP_COUNT + 1))
    done <<< "$HP_HITS"
  fi

  # --------------------------------------------------------------
  # Pattern E: middleware authorize/requireAuth (route guards)
  # --------------------------------------------------------------
  MW_HITS=$(grep -nE '\b(authorize|requireAuth|withAuth)[[:space:]]*\(' "$f" 2>/dev/null || true)
  if [ -n "$MW_HITS" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      LN=$(echo "$line" | cut -d: -f1)
      PERM=$(echo "$line" | grep -oE "['\"][a-z]+\.[a-z]+\.[a-z]+['\"]" 2>/dev/null | head -1 | tr -d "'\"" || true)
      [ -z "$PERM" ] && PERM="route_level_guard"
      emit_node "$REL_PATH" "$LN" "$FILE_BASENAME" "route_guard" "$MODULE" "$f" "$PERM" "authorize_middleware" "$FILE_FP"
      MW_COUNT=$((MW_COUNT + 1))
    done <<< "$MW_HITS"
  fi
done <<< "$TS_FILES"

NODE_COUNT=$(jq 'length' "$NODES_TMP")
log "Scanned $SCANNED_COUNT files, parsed $NODE_COUNT nodes (PG=$PG_COUNT, UP=$UP_COUNT, Can=$CAN_COUNT, HP=$HP_COUNT, MW=$MW_COUNT), skipped $SKIPPED_COUNT"

if [ "$TS_COUNT" -gt 0 ]; then
  FAIL_PCT=$(( SKIPPED_COUNT * 100 / TS_COUNT ))
  if [ "$FAIL_PCT" -gt 20 ]; then
    log "WARN E138: parser fail rate $FAIL_PCT% > 20% threshold"
  fi
fi

# ============================================================================
# Step 3: Build edges — ui_element → permission_required
# ============================================================================
log "Building edges from ui_element → permission..."

EDGES_JSON=$(jq '
  [.[]
   | select(.permission != "unknown" and .permission != "dynamic_or_variable" and .permission != "route_level_guard")
   | {
       from_element: .id,
       to_permission: .permission,
       kind: "guards",
       uncertain: false
     }
  ]' "$NODES_TMP")

EDGE_COUNT=$(echo "$EDGES_JSON" | jq 'length')
log "Built $EDGE_COUNT edges"

# ============================================================================
# Step 4: Compute distributions
# ============================================================================
MODULES_COVERED=$(jq '[.[].module] | unique' "$NODES_TMP")
UNIQUE_PERMS=$(jq '[.[].permission] | map(select(. != "unknown" and . != "dynamic_or_variable" and . != "route_level_guard")) | unique | length' "$NODES_TMP")
SKIPPED_JSON=$(cat "$SKIPPED_FILES_TMP")
NODES_JSON=$(cat "$NODES_TMP")

# ============================================================================
# Step 5: Populate target JSON
# ============================================================================
log "Populating target $TARGET"

jq \
  --arg sid "${SESSION_ID:-unknown}" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg src "${SOURCE_METHOD:-grep_fallback}" \
  --arg freshness "${CI_FRESHNESS:-unknown}" \
  --argjson nodes "$NODES_JSON" \
  --argjson edges "$EDGES_JSON" \
  --argjson skipped "$SKIPPED_JSON" \
  --argjson modules "$MODULES_COVERED" \
  --argjson scanned_count "$SCANNED_COUNT" \
  --argjson node_count "$NODE_COUNT" \
  --argjson edge_count "$EDGE_COUNT" \
  --argjson unique_perms "$UNIQUE_PERMS" \
  --argjson pg "$PG_COUNT" \
  --argjson up "$UP_COUNT" \
  --argjson can "$CAN_COUNT" \
  --argjson hp "$HP_COUNT" \
  --argjson mw "$MW_COUNT" \
  --argjson unk "$UNK_COUNT" \
  '. + {
    session_id: $sid,
    generated_at: $ts,
    nodes: $nodes,
    edges: $edges,
    metadata: (.metadata + {
      build_at: $ts,
      source_method: $src,
      ci_index_freshness: $freshness,
      scanned_file_count: $scanned_count,
      skipped_files: $skipped,
      node_count: $node_count,
      edge_count: $edge_count,
      modules_covered: $modules,
      unique_permissions_used: $unique_perms,
      guard_patterns_distribution: {
        PermissionGate: $pg,
        usePermission: $up,
        Can: $can,
        hasPermission: $hp,
        authorize_middleware: $mw,
        unknown: $unk
      }
    })
  }' "$TMP" > "$TMP.populated"
mv "$TMP.populated" "$TMP"

# ============================================================================
# Step 6: Validate + atomic write
# ============================================================================
jq -e '.["$schema"] == "fe-permission-graph-v1"' "$TMP" > /dev/null \
  || die "Schema validation failed"
jq -e '.nodes | type == "array"' "$TMP" > /dev/null \
  || die "nodes[] not array"
jq -e '.edges | type == "array"' "$TMP" > /dev/null \
  || die "edges[] not array"

mv "$TMP" "$TARGET"
rm -f "$NODES_TMP" "$SKIPPED_FILES_TMP"

log "DONE: $TARGET (nodes=$NODE_COUNT, edges=$EDGE_COUNT, perms=$UNIQUE_PERMS, modules=$(echo "$MODULES_COVERED" | jq 'length'))"
