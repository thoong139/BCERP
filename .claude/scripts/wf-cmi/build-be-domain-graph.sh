#!/usr/bin/env bash
# build-be-domain-graph.sh — Build be-domain-graph.json (Discovery Plugin #11)
# Part of wf-cmi v2.0 Phase 2 (Stage 2.2 — BE plugin set, vertical slice be-domain)
#
# Usage: bash build-be-domain-graph.sh <SESSION_DIR> [SCOPE_ROOT]
#   SESSION_DIR  — Absolute path to session dir (mandatory)
#   SCOPE_ROOT   — Backend root to scan (default: apps/backend)
#
# Output: $SESSION_DIR/phase2-discovery/be-domain-graph.json
#
# DDD patterns detected (C# .NET 10):
#   aggregate_root       : class X : AggregateRoot<TId>
#   entity               : class X : Entity<TId>
#   value_object         : class X : ValueObject
#   domain_event         : class X : IDomainEvent | DomainEvent (loại trừ Handler)
#   domain_event_handler : class X : IDomainEventHandler<TEvent>
#   specification        : class X : Specification<T> | ISpecification<T>
#   repository_interface : interface IXxxRepository
#
# Skip conditions (write empty graph + exit 0):
#   - $SCOPE_ROOT directory does not exist (E137)
#   - No .cs files found under Domain/ or Modules/ subdirs
#
# Error codes:
#   E137 — Project KHÔNG có backend C# (skip gracefully)
#   E138 — Parser fail (>20% files unparseable → WARN)
#   E139 — Non-skipped but nodes=[] (downstream lane fallback Grep)
#
# Parser version: 1.0 (Grep + line-based class declaration parse)
# Upgrade path v2.1: Roslyn-based syntax tree analyzer (Microsoft.CodeAnalysis.CSharp)
#                    cho full type resolution + property type extraction.
#
# Git Bash for Windows note: KHÔNG dùng path bắt đầu bằng / cho payload — module names + type
#                            names KHÔNG có / nên không bị MSYS POSIX path conversion.

set -euo pipefail

SESSION_DIR="${1:?SESSION_DIR mandatory}"
SCOPE_ROOT="${2:-apps/backend}"

# Resolve template path relative to script location (works từ bất kỳ cwd nào)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$SCRIPT_DIR/../../skills/workflow/wf-cmi/templates/be-domain-graph.json"

# Fallback to env override (cho integration test)
[ -n "${MCV3_CMI_BE_DOMAIN_TPL:-}" ] && TPL="$MCV3_CMI_BE_DOMAIN_TPL"

TARGET="$SESSION_DIR/phase2-discovery/be-domain-graph.json"
TMP="$TARGET.tmp.$$"

mkdir -p "$(dirname "$TARGET")"

# ============================================================================
# Helper: log to stderr (stdout reserved cho payload if needed)
# ============================================================================
log() {
  echo "[be-domain-graph] $*" >&2
}

die() {
  log "ERROR: $*"
  rm -f "$TMP" "$TARGET".*.tmp.$$ 2>/dev/null || true
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
  "\$schema": "be-domain-graph-v1",
  "session_id": "${SESSION_ID:-unknown}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scope": {"type": "system", "scope_root": "$SCOPE_ROOT", "module_pattern": "Eureka.Modules.*"},
  "nodes": [],
  "edges": [],
  "metadata": {
    "build_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "scope_root": "$SCOPE_ROOT",
    "source_method": "skipped",
    "ci_index_freshness": "${CI_FRESHNESS:-unknown}",
    "parser_version": "1.0",
    "cs_file_count": 0,
    "skipped_files": [],
    "node_count": 0,
    "edge_count": 0,
    "modules_covered": [],
    "kinds_distribution": {
      "aggregate_root": 0,
      "entity": 0,
      "value_object": 0,
      "domain_event": 0,
      "domain_event_handler": 0,
      "specification": 0,
      "repository_interface": 0
    },
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
  write_skipped_graph "scope_root not found: $SCOPE_ROOT (project lacks backend or scanning from wrong cwd)"
fi

# Find .cs files restricted to Domain/Entities/ValueObjects/Events/Handlers/Specifications/Repositories
# Cover both Modules/{Name}/Domain/* và Infrastructure/EventHandlers/*
CS_FILES=$(find "$SCOPE_ROOT" -type f -name '*.cs' \
           \( -path '*/Domain/*' -o -path '*/EventHandlers/*' -o -path '*/Application/Specifications/*' \) \
           2>/dev/null || true)

if [ -z "$CS_FILES" ]; then
  write_skipped_graph "No relevant .cs files found under $SCOPE_ROOT (no Domain/ or EventHandlers/)"
fi

CS_COUNT=$(echo "$CS_FILES" | wc -l | tr -d ' ')
log "Found $CS_COUNT .cs files under $SCOPE_ROOT (Domain/ + EventHandlers/)"

# ============================================================================
# Step 1: Strip template metadata + initialize target structure
# ============================================================================
if [ ! -f "$TPL" ]; then
  die "Template not found: $TPL"
fi

jq 'del(._template_notes)' "$TPL" > "$TMP" || die "Template strip failed"

# ============================================================================
# Step 2: Build nodes — 1 entry per DDD type declaration
# ============================================================================
log "Building nodes from .cs files (Grep DDD base types)..."

NODES_TMP="$TARGET.nodes.tmp.$$"
EDGES_TMP="$TARGET.edges.tmp.$$"
SKIPPED_FILES_TMP="$TARGET.skipped.tmp.$$"
echo "[]" > "$NODES_TMP"
echo "[]" > "$EDGES_TMP"
echo "[]" > "$SKIPPED_FILES_TMP"

PARSED_COUNT=0
SKIPPED_COUNT=0
EDGE_COUNT=0

# Counters per kind
declare -A KIND_COUNT
KIND_COUNT[aggregate_root]=0
KIND_COUNT[entity]=0
KIND_COUNT[value_object]=0
KIND_COUNT[domain_event]=0
KIND_COUNT[domain_event_handler]=0
KIND_COUNT[specification]=0
KIND_COUNT[repository_interface]=0

# Helper: classify base type → kind
classify_kind() {
  local base="$1"
  case "$base" in
    AggregateRoot*|IAggregateRoot*)             echo "aggregate_root" ;;
    Entity\<*)                                   echo "entity" ;;
    ValueObject*)                                echo "value_object" ;;
    IDomainEventHandler*)                        echo "domain_event_handler" ;;
    IDomainEvent*|DomainEvent*)                  echo "domain_event" ;;
    Specification*|ISpecification*)              echo "specification" ;;
    *Repository*)                                echo "repository_interface" ;;
    *)                                           echo "unknown" ;;
  esac
}

# Helper: extract module short name from file path
# apps/backend/Eureka.Modules.CRM/Domain/... → CRM
# apps/backend/Eureka.Infrastructure/EventHandlers/CRM/... → CRM (inner dir hint)
# apps/backend/Eureka.Infrastructure/Integrations/Common/... → Infrastructure
extract_module() {
  local fp="$1"
  if [[ "$fp" =~ Eureka\.Modules\.([A-Za-z]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$fp" =~ Eureka\.Infrastructure/EventHandlers/([A-Za-z]+)/ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$fp" =~ Eureka\.Infrastructure ]]; then
    echo "Infrastructure"
  else
    echo "unknown"
  fi
}

while IFS= read -r cs_file; do
  [ -z "$cs_file" ] && continue

  # Read file content (max 500KB to avoid blowup)
  if [ ! -r "$cs_file" ] || [ "$(wc -c < "$cs_file" 2>/dev/null || echo 0)" -gt 512000 ]; then
    log "WARN: skip unreadable/oversized $cs_file"
    SKIPPED_FILES_TMP_NEW=$(jq --arg f "$cs_file" '. + [$f]' "$SKIPPED_FILES_TMP")
    echo "$SKIPPED_FILES_TMP_NEW" > "$SKIPPED_FILES_TMP"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  MODULE=$(extract_module "$cs_file")

  # Compute fingerprint (sha256 of file content, 12-char prefix)
  if command -v sha256sum > /dev/null 2>&1; then
    FINGERPRINT=$(sha256sum "$cs_file" | cut -c1-12)
  elif command -v shasum > /dev/null 2>&1; then
    FINGERPRINT=$(shasum -a 256 "$cs_file" | cut -c1-12)
  else
    FINGERPRINT="nohash"
  fi

  # ----- Pattern 1: class X : BaseType[<...>] -----
  # Capture lines matching: optional modifiers + class|interface + Name + ':' + BaseTypes
  # We use grep -n to get line numbers
  CLASS_DECLS=$(grep -nE '^\s*(public\s+|internal\s+|private\s+|protected\s+|sealed\s+|abstract\s+|static\s+|partial\s+|\s)*\b(class|interface|record)\s+[A-Za-z_][A-Za-z0-9_]*\s*(<[^>]+>)?\s*:\s*[A-Za-z_]' "$cs_file" 2>/dev/null || true)

  if [ -z "$CLASS_DECLS" ]; then
    continue
  fi

  while IFS= read -r decl_line; do
    [ -z "$decl_line" ] && continue
    LINE_NUM=$(echo "$decl_line" | awk -F: '{print $1}')
    DECL_BODY=$(echo "$decl_line" | sed -E 's/^[0-9]+://')

    # Extract class/interface/record name
    TYPE_NAME=$(echo "$DECL_BODY" | sed -nE 's/.*\b(class|interface|record)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(<[^>]+>)?\s*:.*/\2/p')
    [ -z "$TYPE_NAME" ] && continue

    # Extract base types list after ':' (split by ',' for multi-inheritance)
    # Only take everything after first ':' (not the parsing of generic <>)
    BASE_TYPES_RAW=$(echo "$DECL_BODY" | sed -E 's/^[^:]*:\s*//' | sed -E 's/\s*\{.*$//' | sed -E 's/where\s+.*$//')

    # Split by comma but respect generic angle brackets
    # Simple approach: replace commas inside <> với placeholder, split, restore
    BASE_TYPES_NORMALIZED=$(echo "$BASE_TYPES_RAW" | python3 -c '
import sys, re
line = sys.stdin.read().strip()
out, depth, buf = [], 0, ""
for ch in line:
    if ch == "<":
        depth += 1; buf += ch
    elif ch == ">":
        depth -= 1; buf += ch
    elif ch == "," and depth == 0:
        if buf.strip(): out.append(buf.strip())
        buf = ""
    else:
        buf += ch
if buf.strip(): out.append(buf.strip())
print("\n".join(out))
' 2>/dev/null || echo "$BASE_TYPES_RAW")

    if [ -z "$BASE_TYPES_NORMALIZED" ]; then
      continue
    fi

    # Determine primary kind based on FIRST DDD-relevant base
    PRIMARY_KIND="unknown"
    BASE_ARRAY="[]"
    while IFS= read -r base; do
      [ -z "$base" ] && continue
      KIND_CANDIDATE=$(classify_kind "$base")
      if [ "$PRIMARY_KIND" = "unknown" ] && [ "$KIND_CANDIDATE" != "unknown" ]; then
        PRIMARY_KIND="$KIND_CANDIDATE"
      fi
      BASE_ARRAY=$(echo "$BASE_ARRAY" | jq --arg b "$base" '. + [$b]')
    done <<< "$BASE_TYPES_NORMALIZED"

    # Skip nếu không match DDD pattern nào
    if [ "$PRIMARY_KIND" = "unknown" ]; then
      continue
    fi

    KIND_COUNT[$PRIMARY_KIND]=$(( ${KIND_COUNT[$PRIMARY_KIND]} + 1 ))

    # Heuristic property count: lines matching `public XYZ Property { get; ... }`
    # Search trong vùng từ LINE_NUM đến hết file hoặc tới `^}` đầu tiên (đóng class)
    PROPERTIES_COUNT=$(awk -v start="$LINE_NUM" 'NR >= start && /^[[:space:]]*public\s+[A-Za-z_<>?,. ]+\s+[A-Za-z_][A-Za-z0-9_]*\s*\{/ {count++} /^}/ && NR > start {if (NR > start) exit} END {print count+0}' "$cs_file" 2>/dev/null || echo 0)

    # Build node ID — module + type name
    NODE_ID="${MODULE}.${TYPE_NAME}"

    # Build node JSON
    NODE=$(jq -n \
      --arg id "$NODE_ID" \
      --arg name "$TYPE_NAME" \
      --arg kind "$PRIMARY_KIND" \
      --arg module "$MODULE" \
      --arg fp "$cs_file" \
      --argjson line "$LINE_NUM" \
      --argjson bases "$BASE_ARRAY" \
      --argjson props "$PROPERTIES_COUNT" \
      --arg fpr "$FINGERPRINT" \
      '{
        id: $id,
        name: $name,
        kind: $kind,
        module: $module,
        file_path: $fp,
        line: $line,
        base_types: $bases,
        properties_count: $props,
        fingerprint: $fpr
      }')

    # Append to nodes array (atomic)
    jq --argjson n "$NODE" '. + [$n]' "$NODES_TMP" > "$NODES_TMP.next"
    mv "$NODES_TMP.next" "$NODES_TMP"

    PARSED_COUNT=$((PARSED_COUNT + 1))

    # ----- Edge: inherits_from -----
    # Per base type → 1 edge
    while IFS= read -r base; do
      [ -z "$base" ] && continue
      # Strip generic args để có "to" gọn (vd AggregateRoot<Guid> → AggregateRoot)
      BASE_NAME=$(echo "$base" | sed -E 's/<.*//')

      # Determine edge kind
      EDGE_KIND="inherits_from"
      case "$base" in
        IDomainEventHandler\<*)
          # Extract event name from generic — handles_event edge
          EVENT_NAME=$(echo "$base" | sed -nE 's/.*IDomainEventHandler<([A-Za-z_][A-Za-z0-9_]*)>.*/\1/p')
          if [ -n "$EVENT_NAME" ]; then
            EDGE=$(jq -n \
              --arg from "$NODE_ID" \
              --arg to "${MODULE}.${EVENT_NAME}" \
              --arg kind "handles_event" \
              --arg file "$cs_file" \
              '{from: $from, to: $to, kind: $kind, file: $file}')
            jq --argjson e "$EDGE" '. + [$e]' "$EDGES_TMP" > "$EDGES_TMP.next"
            mv "$EDGES_TMP.next" "$EDGES_TMP"
            EDGE_COUNT=$((EDGE_COUNT + 1))
          fi
          ;;
      esac

      # Default: inherits_from edge
      EDGE=$(jq -n \
        --arg from "$NODE_ID" \
        --arg to "$BASE_NAME" \
        --arg kind "$EDGE_KIND" \
        --arg file "$cs_file" \
        '{from: $from, to: $to, kind: $kind, file: $file}')
      jq --argjson e "$EDGE" '. + [$e]' "$EDGES_TMP" > "$EDGES_TMP.next"
      mv "$EDGES_TMP.next" "$EDGES_TMP"
      EDGE_COUNT=$((EDGE_COUNT + 1))
    done <<< "$BASE_TYPES_NORMALIZED"
  done <<< "$CLASS_DECLS"

  # ----- Pattern 2: RaiseDomainEvent / AddDomainEvent inside class body -----
  # Detect raises_event edges: AggregateRoot.RaiseDomainEvent(new XxxEvent(...))
  # Heuristic: search trong toàn file, attribute event to LAST aggregate_root node id parsed in this file
  LAST_AGG_NODE=$(jq -r --arg fp "$cs_file" '[.[] | select(.file_path == $fp and .kind == "aggregate_root")] | last | .id // empty' "$NODES_TMP")
  if [ -n "$LAST_AGG_NODE" ]; then
    RAISES=$(grep -oE '(RaiseDomainEvent|AddDomainEvent)\s*\(\s*new\s+[A-Za-z_][A-Za-z0-9_]*' "$cs_file" 2>/dev/null \
             | sed -nE 's/.*new\s+([A-Za-z_][A-Za-z0-9_]*).*/\1/p' \
             | sort -u || true)
    while IFS= read -r ev_name; do
      [ -z "$ev_name" ] && continue
      EDGE=$(jq -n \
        --arg from "$LAST_AGG_NODE" \
        --arg to "${MODULE}.${ev_name}" \
        --arg kind "raises_event" \
        --arg file "$cs_file" \
        '{from: $from, to: $to, kind: $kind, file: $file}')
      jq --argjson e "$EDGE" '. + [$e]' "$EDGES_TMP" > "$EDGES_TMP.next"
      mv "$EDGES_TMP.next" "$EDGES_TMP"
      EDGE_COUNT=$((EDGE_COUNT + 1))
    done <<< "$RAISES"
  fi

done <<< "$CS_FILES"

log "Parsed $PARSED_COUNT nodes, $EDGE_COUNT edges, skipped $SKIPPED_COUNT files"

# Parser fail threshold check (E138)
if [ "$CS_COUNT" -gt 0 ]; then
  FAIL_PCT=$(( SKIPPED_COUNT * 100 / CS_COUNT ))
  if [ "$FAIL_PCT" -gt 20 ]; then
    log "WARN E138: parser skip rate $FAIL_PCT% > 20% threshold"
  fi
fi

# ============================================================================
# Step 3: Compute modules_covered + kinds_distribution
# ============================================================================
MODULES_COVERED=$(jq '[.[].module] | unique' "$NODES_TMP")

KINDS_DIST=$(jq -n \
  --argjson ar "${KIND_COUNT[aggregate_root]}" \
  --argjson e "${KIND_COUNT[entity]}" \
  --argjson vo "${KIND_COUNT[value_object]}" \
  --argjson de "${KIND_COUNT[domain_event]}" \
  --argjson deh "${KIND_COUNT[domain_event_handler]}" \
  --argjson sp "${KIND_COUNT[specification]}" \
  --argjson ri "${KIND_COUNT[repository_interface]}" \
  '{
    aggregate_root: $ar,
    entity: $e,
    value_object: $vo,
    domain_event: $de,
    domain_event_handler: $deh,
    specification: $sp,
    repository_interface: $ri
  }')

# ============================================================================
# Step 4: Populate target JSON
# ============================================================================
# CRITICAL: Use --slurpfile cho nodes/edges (có thể >1MB cho EUREKA ~900+ types)
#           --argjson truyền qua command line → "Argument list too long" khi data lớn.
#           --slurpfile reads từ file → bypass argv limit; wraps trong array → unwrap qua [0].
log "Populating target $TARGET"

SKIPPED_JSON=$(cat "$SKIPPED_FILES_TMP")

jq \
  --arg sid "${SESSION_ID:-unknown}" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg src "${SOURCE_METHOD:-grep_fallback}" \
  --arg freshness "${CI_FRESHNESS:-unknown}" \
  --slurpfile nodes "$NODES_TMP" \
  --slurpfile edges "$EDGES_TMP" \
  --argjson skipped "$SKIPPED_JSON" \
  --argjson modules "$MODULES_COVERED" \
  --argjson cs_count "$CS_COUNT" \
  --argjson node_count "$PARSED_COUNT" \
  --argjson edge_count "$EDGE_COUNT" \
  --argjson kinds "$KINDS_DIST" \
  '. + {
    session_id: $sid,
    generated_at: $ts,
    nodes: $nodes[0],
    edges: $edges[0],
    metadata: (.metadata + {
      build_at: $ts,
      source_method: $src,
      ci_index_freshness: $freshness,
      cs_file_count: $cs_count,
      skipped_files: $skipped,
      node_count: $node_count,
      edge_count: $edge_count,
      modules_covered: $modules,
      kinds_distribution: $kinds
    })
  }' "$TMP" > "$TMP.populated"
mv "$TMP.populated" "$TMP"

# ============================================================================
# Step 5: Validate + atomic write
# ============================================================================
jq -e '.["$schema"] == "be-domain-graph-v1"' "$TMP" > /dev/null \
  || die "Schema validation failed"
jq -e '.nodes | type == "array"' "$TMP" > /dev/null \
  || die "nodes[] not array"
jq -e '.edges | type == "array"' "$TMP" > /dev/null \
  || die "edges[] not array"

mv "$TMP" "$TARGET"
rm -f "$NODES_TMP" "$EDGES_TMP" "$SKIPPED_FILES_TMP"

log "DONE: $TARGET (nodes=$PARSED_COUNT, edges=$EDGE_COUNT, modules=$(echo "$MODULES_COVERED" | jq 'length'), kinds=$(echo "$KINDS_DIST" | jq -c .))"
