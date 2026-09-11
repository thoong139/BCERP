#!/usr/bin/env bash
# build-fe-api-client-graph.sh — Build fe-api-client-graph.json (Discovery Plugin #8)
# Part of wf-cmi v2.0 Phase 2 (Stage 2.1 — FE plugin graphs)
#
# Usage: bash build-fe-api-client-graph.sh <SESSION_DIR> [SCOPE_ROOT]
#   SESSION_DIR  — Absolute path to session dir (mandatory)
#   SCOPE_ROOT   — Frontend root to scan (default: apps/erp-web)
#
# Output: $SESSION_DIR/phase2-discovery/fe-api-client-graph.json
#
# Skip conditions (write empty graph + exit 0):
#   - $SCOPE_ROOT directory does not exist
#   - No .ts/.tsx files found
#
# Detect patterns (Grep v1.0):
#   - React Query: useQuery, useMutation, useInfiniteQuery, useSuspenseQuery
#   - Refit interfaces: `interface I[A-Z][A-Za-z]*Api`
#   - Refit HTTP attributes: [Get("..."), [Post("..."), [Put("..."), [Delete("..."), [Patch("...")
#   - Raw fetch/axios: fetch(`...`), axios.{get,post,put,delete,patch}(`...`)
#
# Error codes:
#   E137 — Project KHÔNG có erp-web (skip gracefully)
#   E138 — Parser fail (>20% files unparseable → WARN)
#
# Parser version: 1.0 (Grep-based proof-of-pattern)
# Upgrade path v2.1: ts-morph for full Refit signature + RQ generic type extraction.

set -euo pipefail

SESSION_DIR="${1:?SESSION_DIR mandatory}"
SCOPE_ROOT="${2:-apps/erp-web}"

# Git Bash for Windows POSIX path conversion workaround:
# endpoint_path values starting with `/api/...` get auto-converted to Windows paths.
# Solution: prepend sentinel tag, strip inside jq.
PATH_TAG="EPv1:::"

# Resolve template path relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$SCRIPT_DIR/../../skills/workflow/wf-cmi/templates/fe-api-client-graph.json"
[ -n "${MCV3_CMI_FE_API_CLIENT_TPL:-}" ] && TPL="$MCV3_CMI_FE_API_CLIENT_TPL"

TARGET="$SESSION_DIR/phase2-discovery/fe-api-client-graph.json"
TMP="$TARGET.tmp.$$"

mkdir -p "$(dirname "$TARGET")"

log() { echo "[fe-api-client-graph] $*" >&2; }

die() {
  log "ERROR: $*"
  rm -f "$TMP" "$TARGET.nodes.tmp.$$" "$TARGET.edges.tmp.$$" "$TARGET.skipped.tmp.$$"
  exit 1
}

write_skipped_graph() {
  local reason="$1"
  log "SKIP: $reason"
  cat > "$TMP" <<EOF
{
  "\$schema": "fe-api-client-graph-v1",
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
    "client_unit_count": 0,
    "scanned_file_count": 0,
    "skipped_files": [],
    "node_count": 0,
    "edge_count": 0,
    "modules_covered": [],
    "kinds_distribution": {"react_query_hook": 0, "refit_interface": 0, "raw_fetch": 0, "service_function": 0},
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

# Collect .ts and .tsx files (exclude node_modules, .next, dist, build)
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
# Step 2: Build nodes — scan for API client patterns
# ============================================================================
log "Scanning files for API client patterns..."

NODES_TMP="$TARGET.nodes.tmp.$$"
SKIPPED_FILES_TMP="$TARGET.skipped.tmp.$$"
echo "[]" > "$NODES_TMP"
echo "[]" > "$SKIPPED_FILES_TMP"

SCANNED_COUNT=0
PARSED_COUNT=0
SKIPPED_COUNT=0
RQ_COUNT=0
REFIT_COUNT=0
RAW_FETCH_COUNT=0
SERVICE_COUNT=0

while IFS= read -r f; do
  [ -z "$f" ] && continue
  SCANNED_COUNT=$((SCANNED_COUNT + 1))

  # Skip oversized files
  if [ ! -r "$f" ] || [ "$(wc -c < "$f" 2>/dev/null || echo 0)" -gt 512000 ]; then
    log "WARN: skip unreadable/oversized $f"
    SKIPPED_FILES_TMP_NEW=$(jq --arg p "$f" '. + [$p]' "$SKIPPED_FILES_TMP")
    echo "$SKIPPED_FILES_TMP_NEW" > "$SKIPPED_FILES_TMP"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  REL_PATH="${f#$SCOPE_ROOT/}"

  # Module inference: first path segment after scope_root
  MODULE=$(echo "$REL_PATH" | awk -F/ '{print $1}')

  # Fingerprint
  if command -v sha256sum > /dev/null 2>&1; then
    FILE_FP=$(sha256sum "$f" | cut -c1-12)
  elif command -v shasum > /dev/null 2>&1; then
    FILE_FP=$(shasum -a 256 "$f" | cut -c1-12)
  else
    FILE_FP="nohash"
  fi

  # ----------------------------------------------------------------
  # Pattern A: React Query hooks (useQuery, useMutation, etc.)
  # ----------------------------------------------------------------
  RQ_HITS=$(grep -nE 'use(Query|Mutation|InfiniteQuery|SuspenseQuery)[[:space:]]*[\(<]' "$f" 2>/dev/null || true)
  if [ -n "$RQ_HITS" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      LINE_NO=$(echo "$line" | cut -d: -f1)
      HOOK_NAME=$(echo "$line" | grep -oE 'use(Query|Mutation|InfiniteQuery|SuspenseQuery)' 2>/dev/null | head -1 || true)
      [ -z "$HOOK_NAME" ] && continue

      # Try to detect parent function name (within 5 lines before)
      PARENT_FN=$( (awk -v ln="$LINE_NO" 'NR <= ln && NR >= ln-5 && /^(export )?(const|function) +[A-Za-z_][A-Za-z0-9_]*/' "$f" 2>/dev/null \
                    | tail -1 \
                    | grep -oE '(const|function) +[A-Za-z_][A-Za-z0-9_]*' 2>/dev/null \
                    | awk '{print $2}') || echo "")
      NAME="${PARENT_FN:-$HOOK_NAME}"

      # Endpoint method: useQuery → GET, useMutation → infer from body (default POST)
      case "$HOOK_NAME" in
        useQuery|useInfiniteQuery|useSuspenseQuery) METHOD="GET" ;;
        useMutation) METHOD="POST" ;;  # default; v2.1 will parse mutationFn
        *) METHOD="null" ;;
      esac

      # Endpoint path: search for queryKey or url string in next 10 lines (heuristic)
      ENDPOINT_PATH=$( (awk -v ln="$LINE_NO" 'NR >= ln && NR <= ln+10' "$f" 2>/dev/null \
                       | grep -oE "['\"]/(api|v[0-9]+)/[A-Za-z0-9/_{}.-]+['\"]" 2>/dev/null \
                       | head -1 | tr -d "'\"") || true)
      [ -z "$ENDPOINT_PATH" ] && ENDPOINT_PATH="null"

      NODE=$(jq -n \
        --arg id "${REL_PATH}:${LINE_NO}:${NAME}" \
        --arg name "$NAME" \
        --arg kind "react_query_hook" \
        --arg module "$MODULE" \
        --arg fp "$f" \
        --argjson line "$LINE_NO" \
        --arg method "$METHOD" \
        --arg path "${PATH_TAG}${ENDPOINT_PATH}" \
        --arg fpr "$FILE_FP" \
        '{
          id: $id,
          name: $name,
          kind: $kind,
          module: $module,
          file_path: $fp,
          line: $line,
          endpoint_method: (if $method == "null" then null else $method end),
          endpoint_path: (if $path == "EPv1:::null" then null else ($path | sub("^EPv1:::"; "")) end),
          fingerprint: $fpr
        }')
      jq --argjson n "$NODE" '. + [$n]' "$NODES_TMP" > "$NODES_TMP.next"
      mv "$NODES_TMP.next" "$NODES_TMP"
      RQ_COUNT=$((RQ_COUNT + 1))
    done <<< "$RQ_HITS"
  fi

  # ----------------------------------------------------------------
  # Pattern B: Refit interfaces (interface IXxxApi)
  # ----------------------------------------------------------------
  REFIT_HITS=$(grep -nE 'interface +I[A-Z][A-Za-z0-9_]*Api' "$f" 2>/dev/null || true)
  if [ -n "$REFIT_HITS" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      LINE_NO=$(echo "$line" | cut -d: -f1)
      IFACE=$(echo "$line" | grep -oE 'I[A-Z][A-Za-z0-9_]*Api' 2>/dev/null | head -1 || true)
      [ -z "$IFACE" ] && continue

      # Try detect first Refit attribute method in subsequent 50 lines
      ATTR_LINE=$( (awk -v ln="$LINE_NO" 'NR > ln && NR <= ln+50' "$f" 2>/dev/null \
                    | grep -nE '\[(Get|Post|Put|Delete|Patch)\(' 2>/dev/null | head -1) || true)
      if [ -n "$ATTR_LINE" ]; then
        METHOD=$(echo "$ATTR_LINE" | grep -oE '(Get|Post|Put|Delete|Patch)' 2>/dev/null | head -1 | tr '[:lower:]' '[:upper:]' || true)
        ENDPOINT_PATH=$(echo "$ATTR_LINE" | grep -oE "['\"][^'\"]+['\"]" 2>/dev/null | head -1 | tr -d "'\"" || true)
        [ -z "$METHOD" ] && METHOD="null"
        [ -z "$ENDPOINT_PATH" ] && ENDPOINT_PATH="null"
      else
        METHOD="null"
        ENDPOINT_PATH="null"
      fi

      NODE=$(jq -n \
        --arg id "${REL_PATH}:${LINE_NO}:${IFACE}" \
        --arg name "$IFACE" \
        --arg kind "refit_interface" \
        --arg module "$MODULE" \
        --arg fp "$f" \
        --argjson line "$LINE_NO" \
        --arg method "$METHOD" \
        --arg path "${PATH_TAG}${ENDPOINT_PATH}" \
        --arg fpr "$FILE_FP" \
        '{
          id: $id,
          name: $name,
          kind: $kind,
          module: $module,
          file_path: $fp,
          line: $line,
          endpoint_method: (if $method == "null" then null else $method end),
          endpoint_path: (if $path == "EPv1:::null" then null else ($path | sub("^EPv1:::"; "")) end),
          fingerprint: $fpr
        }')
      jq --argjson n "$NODE" '. + [$n]' "$NODES_TMP" > "$NODES_TMP.next"
      mv "$NODES_TMP.next" "$NODES_TMP"
      REFIT_COUNT=$((REFIT_COUNT + 1))
    done <<< "$REFIT_HITS"
  fi

  # ----------------------------------------------------------------
  # Pattern C: Raw fetch / axios
  # ----------------------------------------------------------------
  RAW_HITS=$(grep -nE '(fetch|axios)(\.[a-z]+)?[[:space:]]*\([[:space:]]*[`'\''"]/(api|v[0-9])' "$f" 2>/dev/null || true)
  if [ -n "$RAW_HITS" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      LINE_NO=$(echo "$line" | cut -d: -f1)
      CALL=$(echo "$line" | grep -oE '(fetch|axios\.[a-z]+|axios)' 2>/dev/null | head -1 || true)
      [ -z "$CALL" ] && continue

      # Method detection
      case "$CALL" in
        axios.get)    METHOD="GET" ;;
        axios.post)   METHOD="POST" ;;
        axios.put)    METHOD="PUT" ;;
        axios.delete) METHOD="DELETE" ;;
        axios.patch)  METHOD="PATCH" ;;
        axios)        METHOD="null" ;;  # generic axios() — needs config parse
        fetch)        METHOD="GET" ;;   # default; v2.1 will parse options.method
        *)            METHOD="null" ;;
      esac

      ENDPOINT_PATH=$(echo "$line" | grep -oE "[\`'\"][^/]*(/api|/v[0-9]+)[A-Za-z0-9/_{}.\$\\\\\${}\\-]+" 2>/dev/null | head -1 | tr -d "\`'\"" || true)
      [ -z "$ENDPOINT_PATH" ] && ENDPOINT_PATH="null"

      NODE_NAME="${CALL}@${REL_PATH}:${LINE_NO}"

      NODE=$(jq -n \
        --arg id "${REL_PATH}:${LINE_NO}:${CALL}" \
        --arg name "$NODE_NAME" \
        --arg kind "raw_fetch" \
        --arg module "$MODULE" \
        --arg fp "$f" \
        --argjson line "$LINE_NO" \
        --arg method "$METHOD" \
        --arg path "${PATH_TAG}${ENDPOINT_PATH}" \
        --arg fpr "$FILE_FP" \
        '{
          id: $id,
          name: $name,
          kind: $kind,
          module: $module,
          file_path: $fp,
          line: $line,
          endpoint_method: (if $method == "null" then null else $method end),
          endpoint_path: (if $path == "EPv1:::null" then null else ($path | sub("^EPv1:::"; "")) end),
          fingerprint: $fpr
        }')
      jq --argjson n "$NODE" '. + [$n]' "$NODES_TMP" > "$NODES_TMP.next"
      mv "$NODES_TMP.next" "$NODES_TMP"
      RAW_FETCH_COUNT=$((RAW_FETCH_COUNT + 1))
    done <<< "$RAW_HITS"
  fi

  PARSED_COUNT=$((PARSED_COUNT + 1))
done <<< "$TS_FILES"

NODE_COUNT=$(jq 'length' "$NODES_TMP")
log "Scanned $SCANNED_COUNT files, parsed $NODE_COUNT nodes (RQ=$RQ_COUNT, Refit=$REFIT_COUNT, raw=$RAW_FETCH_COUNT), skipped $SKIPPED_COUNT"

# Parser fail threshold (E138)
if [ "$TS_COUNT" -gt 0 ]; then
  FAIL_PCT=$(( SKIPPED_COUNT * 100 / TS_COUNT ))
  if [ "$FAIL_PCT" -gt 20 ]; then
    log "WARN E138: parser fail rate $FAIL_PCT% > 20% threshold"
  fi
fi

# ============================================================================
# Step 3: Build edges — client → endpoint (1 edge per node with endpoint_path)
# ============================================================================
log "Building edges from client → endpoint mappings..."

EDGES_JSON=$(jq '
  [.[]
   | select(.endpoint_path != null)
   | {
       from_client: .id,
       to_endpoint: ((.endpoint_method // "ANY") + " " + .endpoint_path),
       kind: "calls",
       uncertain: (.endpoint_method == null)
     }
  ]' "$NODES_TMP")

EDGE_COUNT=$(echo "$EDGES_JSON" | jq 'length')
log "Built $EDGE_COUNT edges"

# ============================================================================
# Step 4: Compute modules_covered + kinds_distribution
# ============================================================================
MODULES_COVERED=$(jq '[.[].module] | unique' "$NODES_TMP")
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
  --argjson ts_count "$TS_COUNT" \
  --argjson scanned_count "$SCANNED_COUNT" \
  --argjson node_count "$NODE_COUNT" \
  --argjson edge_count "$EDGE_COUNT" \
  --argjson rq "$RQ_COUNT" \
  --argjson refit "$REFIT_COUNT" \
  --argjson raw "$RAW_FETCH_COUNT" \
  --argjson svc "$SERVICE_COUNT" \
  '. + {
    session_id: $sid,
    generated_at: $ts,
    nodes: $nodes,
    edges: $edges,
    metadata: (.metadata + {
      build_at: $ts,
      source_method: $src,
      ci_index_freshness: $freshness,
      client_unit_count: $node_count,
      scanned_file_count: $scanned_count,
      skipped_files: $skipped,
      node_count: $node_count,
      edge_count: $edge_count,
      modules_covered: $modules,
      kinds_distribution: {
        react_query_hook: $rq,
        refit_interface: $refit,
        raw_fetch: $raw,
        service_function: $svc
      }
    })
  }' "$TMP" > "$TMP.populated"
mv "$TMP.populated" "$TMP"

# ============================================================================
# Step 6: Validate + atomic write
# ============================================================================
jq -e '.["$schema"] == "fe-api-client-graph-v1"' "$TMP" > /dev/null \
  || die "Schema validation failed"
jq -e '.nodes | type == "array"' "$TMP" > /dev/null \
  || die "nodes[] not array"
jq -e '.edges | type == "array"' "$TMP" > /dev/null \
  || die "edges[] not array"

mv "$TMP" "$TARGET"
rm -f "$NODES_TMP" "$SKIPPED_FILES_TMP"

log "DONE: $TARGET (nodes=$NODE_COUNT, edges=$EDGE_COUNT, modules=$(echo "$MODULES_COVERED" | jq 'length'))"
