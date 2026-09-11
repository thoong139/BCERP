#!/usr/bin/env bash
# build-be-cqrs-graph.sh — Build be-cqrs-graph.json (Discovery Plugin #13)
# Part of wf-cmi v2.0 Phase 2 (Stage 2.2 — BE plugin set, close 2 BE graphs)
#
# Usage: bash build-be-cqrs-graph.sh <SESSION_DIR> [SCOPE_ROOT]
#   SESSION_DIR  — Absolute path to session dir (mandatory)
#   SCOPE_ROOT   — Backend root to scan (default: apps/backend)
#
# Output: $SESSION_DIR/phase2-discovery/be-cqrs-graph.json
#
# MediatR / FluentValidation patterns detected (C# .NET 10):
#   command              : class/record X : IRequest<TResponse> hoặc : IRequest VÀ name *Command
#   query                : class/record X : IRequest<TResponse> VÀ name *Query
#   request_handler      : class X : IRequestHandler<TRequest, TResponse>
#   validator            : class X : AbstractValidator<TRequest> (FluentValidation)
#   pipeline_behavior    : class X<TReq, TResp> : IPipelineBehavior<TReq, TResp>
#   notification         : class X : INotification
#   notification_handler : class X : INotificationHandler<TNotification>
#
# Skip conditions (write empty graph + exit 0):
#   - $SCOPE_ROOT directory does not exist (E137)
#   - No .cs files under Application/ or Behaviors/
#
# Error codes:
#   E137 — Project KHÔNG có backend C# (skip gracefully)
#   E138 — Parser fail (>20% files unparseable → WARN)
#   E139 — Non-skipped but nodes=[] (downstream lane fallback Grep)
#
# Parser version: 1.0 (Python helper xử lý cả file → JSON Lines, bulk jq aggregate)
# Performance: Avoids O(n²) jq-append pattern by collecting all records into flat file first.
# Upgrade path v2.1: Roslyn-based syntax tree analyzer cho full namespace resolution

set -euo pipefail

SESSION_DIR="${1:?SESSION_DIR mandatory}"
SCOPE_ROOT="${2:-apps/backend}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$SCRIPT_DIR/../../skills/workflow/wf-cmi/templates/be-cqrs-graph.json"
[ -n "${MCV3_CMI_BE_CQRS_TPL:-}" ] && TPL="$MCV3_CMI_BE_CQRS_TPL"

TARGET="$SESSION_DIR/phase2-discovery/be-cqrs-graph.json"
TMP="$TARGET.tmp.$$"
mkdir -p "$(dirname "$TARGET")"

# Max file size: 512KB per CQRS file (these are normally small)
MAX_FILE_SIZE=524288

log() { echo "[be-cqrs-graph] $*" >&2; }
die() { log "ERROR: $*"; rm -f "$TMP" "$TARGET".*.tmp.$$ 2>/dev/null || true; exit 1; }

write_skipped_graph() {
  local reason="$1"
  log "SKIP: $reason"
  cat > "$TMP" <<EOF
{
  "\$schema": "be-cqrs-graph-v1",
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
      "command": 0,
      "query": 0,
      "request_handler": 0,
      "validator": 0,
      "pipeline_behavior": 0,
      "notification": 0,
      "notification_handler": 0
    },
    "coverage_indicators": {
      "requests_without_handler": 0,
      "requests_without_validator": 0,
      "handlers_without_request": 0
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
  write_skipped_graph "scope_root not found: $SCOPE_ROOT"
fi

CS_FILES=$(find "$SCOPE_ROOT" -type f -name '*.cs' \
           \( -path '*/Application/*' -o -path '*/Behaviors/*' -o -path '*/PipelineBehaviors/*' \) \
           ! -path '*/bin/*' ! -path '*/obj/*' \
           2>/dev/null || true)

if [ -z "$CS_FILES" ]; then
  write_skipped_graph "No .cs files found under Application/ or Behaviors/ in $SCOPE_ROOT"
fi

CS_COUNT=$(echo "$CS_FILES" | grep -c '^' 2>/dev/null || echo 0)
log "Found $CS_COUNT .cs files under $SCOPE_ROOT (Application/ + Behaviors/)"

# ============================================================================
# Template strip
# ============================================================================
[ -f "$TPL" ] || die "Template not found: $TPL"
jq 'del(._template_notes)' "$TPL" > "$TMP" || die "Template strip failed"

# ============================================================================
# Python parser — 1 invocation per file → all class decls processed at once
# Outputs JSON Lines to stdout:
#   {"kind": "command|query|request_handler|...", "name": ..., "module": ..., "line": ..., "request_type": ..., "response_type": ..., "validates_for": ..., "file_path": ..., "fingerprint": ...}
# ============================================================================
PARSER_PY=$(cat <<'PYEOF'
import sys, re, json, hashlib

file_path = sys.argv[1]
module = sys.argv[2]

try:
    with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
except Exception:
    sys.exit(1)

# Compute fingerprint
fingerprint = hashlib.sha256(content.encode('utf-8', errors='replace')).hexdigest()[:12]

# Find class/record/interface declarations with base types
# Pattern: optional modifiers + class|record|interface + Name + optional generic + ':' + BaseTypes
decl_re = re.compile(
    r'^[ \t]*(?:(?:public|internal|private|protected|sealed|abstract|static|partial)\s+)*'
    r'(class|record|interface)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]+>)?\s*:\s*([^\{]+?)(?:\{|where|$)',
    re.MULTILINE
)

def split_bases(s):
    """Split comma-separated bases respecting generic <>"""
    parts, depth, buf = [], 0, ''
    for ch in s:
        if ch == '<':
            depth += 1; buf += ch
        elif ch == '>':
            depth -= 1; buf += ch
        elif ch == ',' and depth == 0:
            if buf.strip(): parts.append(buf.strip())
            buf = ''
        else:
            buf += ch
    if buf.strip(): parts.append(buf.strip())
    return parts

def extract_generic_args(base):
    """Return (first, second) args. base = 'IRequestHandler<X, Y>'"""
    m = re.match(r'\w+<(.+)>$', base.strip())
    if not m:
        return ('', '')
    inner = m.group(1)
    parts, depth, buf = [], 0, ''
    for ch in inner:
        if ch == '<':
            depth += 1; buf += ch
        elif ch == '>':
            depth -= 1; buf += ch
        elif ch == ',' and depth == 0:
            parts.append(buf.strip()); buf = ''
        else:
            buf += ch
    if buf.strip(): parts.append(buf.strip())
    first = parts[0] if len(parts) > 0 else ''
    second = parts[1] if len(parts) > 1 else ''
    return (first, second)

def classify(base, name):
    """Return CQRS kind based on base type + type name."""
    if base.startswith('IRequestHandler'):
        return 'request_handler'
    if base.startswith('INotificationHandler'):
        return 'notification_handler'
    if base.startswith('IPipelineBehavior'):
        return 'pipeline_behavior'
    if base.startswith('AbstractValidator'):
        return 'validator'
    if base.startswith('INotification'):
        return 'notification'
    if base.startswith('IRequest'):
        # Distinguish command vs query by name suffix/prefix
        if name.endswith('Command') or name.endswith('CommandRequest'):
            return 'command'
        if name.endswith('Query') or name.endswith('QueryRequest'):
            return 'query'
        if re.match(r'^(Get|List|Find|Search|Check)', name):
            return 'query'
        return 'command'
    return None

for m in decl_re.finditer(content):
    type_kw = m.group(1)
    type_name = m.group(2)
    bases_str = m.group(3).strip()
    # Remove trailing 'where' clauses and whitespace
    bases_str = re.sub(r'where\s+\S.*', '', bases_str).strip()
    if not bases_str:
        continue

    bases = split_bases(bases_str)
    if not bases:
        continue

    line_no = content[:m.start()].count('\n') + 1

    # Classify by FIRST CQRS-relevant base
    primary_kind = None
    primary_base = None
    for b in bases:
        k = classify(b, type_name)
        if k is not None:
            primary_kind = k
            primary_base = b
            break

    if not primary_kind:
        continue

    # Extract generic args
    first_arg, second_arg = ('', '')
    if '<' in primary_base:
        first_arg, second_arg = extract_generic_args(primary_base)

    request_type = ''
    response_type = ''
    validates_for = ''

    if primary_kind == 'request_handler':
        request_type = first_arg
        response_type = second_arg
    elif primary_kind == 'validator':
        request_type = first_arg
        validates_for = first_arg
    elif primary_kind == 'pipeline_behavior':
        request_type = first_arg
        response_type = second_arg
    elif primary_kind == 'notification_handler':
        request_type = first_arg
    elif primary_kind in ('command', 'query'):
        response_type = first_arg

    record = {
        "kind": primary_kind,
        "name": type_name,
        "module": module,
        "line": line_no,
        "request_type": request_type or None,
        "response_type": response_type or None,
        "validates_for": validates_for or None,
        "file_path": file_path,
        "fingerprint": fingerprint
    }
    print(json.dumps(record))
PYEOF
)

# ============================================================================
# Helpers
# ============================================================================
extract_module() {
  local fp="$1"
  if [[ "$fp" =~ Eureka\.Modules\.([A-Za-z]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$fp" =~ Eureka\.Migration ]]; then
    echo "Migration"
  elif [[ "$fp" =~ Eureka\.Infrastructure ]]; then
    echo "Infrastructure"
  else
    echo "unknown"
  fi
}

# ============================================================================
# Initialize tmp accumulator file
# ============================================================================
PARSER_OUT_TMP="$TARGET.parserout.tmp.$$"
SKIPPED_FILES_TMP="$TARGET.skipped.tmp.$$"
> "$PARSER_OUT_TMP"
echo "[]" > "$SKIPPED_FILES_TMP"

PARSED_FILES=0
SKIPPED_COUNT=0

# ============================================================================
# Main loop: 1 Python invocation per file → JSON Lines to PARSER_OUT_TMP
# ============================================================================
log "Parsing $CS_COUNT .cs files (Python single-pass per file)..."

while IFS= read -r cs_file; do
  [ -z "$cs_file" ] && continue

  FILE_SIZE=$(wc -c < "$cs_file" 2>/dev/null || echo 0)
  if [ ! -r "$cs_file" ] || [ "$FILE_SIZE" -gt "$MAX_FILE_SIZE" ]; then
    SKIPPED_FILES_NEW=$(jq --arg f "$cs_file" '. + [$f]' "$SKIPPED_FILES_TMP")
    echo "$SKIPPED_FILES_NEW" > "$SKIPPED_FILES_TMP"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  MODULE=$(extract_module "$cs_file")

  if python3 -c "$PARSER_PY" "$cs_file" "$MODULE" >> "$PARSER_OUT_TMP" 2>>"$TARGET.parser-err.log"; then
    PARSED_FILES=$((PARSED_FILES + 1))
  else
    SKIPPED_FILES_NEW=$(jq --arg f "$cs_file" '. + [$f]' "$SKIPPED_FILES_TMP")
    echo "$SKIPPED_FILES_NEW" > "$SKIPPED_FILES_TMP"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  fi

done <<< "$CS_FILES"

RECORD_COUNT=$(wc -l < "$PARSER_OUT_TMP" 2>/dev/null || echo 0)
log "Parsed $PARSED_FILES file(s) → $RECORD_COUNT CQRS records; skipped $SKIPPED_COUNT files"

# Parser fail threshold (E138)
if [ "$CS_COUNT" -gt 0 ]; then
  FAIL_PCT=$(( SKIPPED_COUNT * 100 / CS_COUNT ))
  if [ "$FAIL_PCT" -gt 20 ]; then
    log "WARN E138: parser skip rate $FAIL_PCT% > 20% threshold"
  fi
fi

# ============================================================================
# Bulk JQ aggregation: build nodes + edges + counts in one pass
# ============================================================================
NODES_TMP="$TARGET.nodes.tmp.$$"
EDGES_TMP="$TARGET.edges.tmp.$$"

if [ -s "$PARSER_OUT_TMP" ]; then
  # Build nodes: each parsed record → node with id = module.name
  jq -s '
    [.[] | {
      id: (.module + "." + .name),
      name: .name,
      kind: .kind,
      module: .module,
      file_path: .file_path,
      line: .line,
      request_type: .request_type,
      response_type: .response_type,
      validates_for: .validates_for,
      fingerprint: .fingerprint
    }]
  ' "$PARSER_OUT_TMP" > "$NODES_TMP"

  # Build edges
  # handles: request_handler → request (via request_type)
  # validates: validator → request (via validates_for)
  # notifies: notification_handler → notification (via request_type field)
  jq -s '
    [
      (.[] | select(.kind == "request_handler" and (.request_type != null and .request_type != "")) | {
        from: (.module + "." + .name),
        to: (.module + "." + .request_type),
        kind: "handles",
        file: .file_path
      }),
      (.[] | select(.kind == "validator" and (.validates_for != null and .validates_for != "")) | {
        from: (.module + "." + .name),
        to: (.module + "." + .validates_for),
        kind: "validates",
        file: .file_path
      }),
      (.[] | select(.kind == "notification_handler" and (.request_type != null and .request_type != "")) | {
        from: (.module + "." + .name),
        to: (.module + "." + .request_type),
        kind: "notifies",
        file: .file_path
      })
    ]
  ' "$PARSER_OUT_TMP" > "$EDGES_TMP"
else
  echo "[]" > "$NODES_TMP"
  echo "[]" > "$EDGES_TMP"
fi

PARSED_COUNT=$(jq 'length' "$NODES_TMP")
EDGE_COUNT=$(jq 'length' "$EDGES_TMP")

# Kinds distribution
KINDS_DIST=$(jq '
  group_by(.kind) | map({(.[0].kind): length}) | add // {} |
  {
    command: (.command // 0),
    query: (.query // 0),
    request_handler: (.request_handler // 0),
    validator: (.validator // 0),
    pipeline_behavior: (.pipeline_behavior // 0),
    notification: (.notification // 0),
    notification_handler: (.notification_handler // 0)
  }
' "$NODES_TMP")

# Modules covered (small array, --argjson OK qua process substitution)
MODULES_COVERED=$(jq -c '[.[].module] | unique' "$NODES_TMP")

# Coverage indicators — compute trong 1 jq pass từ NODES_TMP (tránh argv limit cho 1000+ IDs)
COVERAGE_INDICATORS=$(jq '
  . as $nodes
  | (
      [$nodes[] | select(.kind == "command" or .kind == "query") | .id]
    ) as $req_ids
  | (
      [$nodes[] | select(.kind == "request_handler" and .request_type != null and .request_type != "") | (.module + "." + .request_type)] | unique
    ) as $handler_targets
  | (
      [$nodes[] | select(.kind == "validator" and .validates_for != null and .validates_for != "") | (.module + "." + .validates_for)] | unique
    ) as $validator_targets
  | {
      requests_without_handler: ($req_ids - $handler_targets | length),
      requests_without_validator: ($req_ids - $validator_targets | length),
      handlers_without_request: ($handler_targets - $req_ids | length)
    }
' "$NODES_TMP")

log "Aggregated: $PARSED_COUNT nodes, $EDGE_COUNT edges, kinds=$(echo "$KINDS_DIST" | jq -c .), coverage=$(echo "$COVERAGE_INDICATORS" | jq -c .)"

# ============================================================================
# Populate target JSON
# ============================================================================
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
  --argjson coverage "$COVERAGE_INDICATORS" \
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
      kinds_distribution: $kinds,
      coverage_indicators: $coverage
    })
  }' "$TMP" > "$TMP.populated"
mv "$TMP.populated" "$TMP"

# ============================================================================
# Validate + atomic write
# ============================================================================
jq -e '.["$schema"] == "be-cqrs-graph-v1"' "$TMP" > /dev/null \
  || die "Schema validation failed"
jq -e '.nodes | type == "array"' "$TMP" > /dev/null \
  || die "nodes[] not array"
jq -e '.edges | type == "array"' "$TMP" > /dev/null \
  || die "edges[] not array"

mv "$TMP" "$TARGET"
rm -f "$NODES_TMP" "$EDGES_TMP" "$PARSER_OUT_TMP" "$SKIPPED_FILES_TMP"

log "DONE: $TARGET (nodes=$PARSED_COUNT, edges=$EDGE_COUNT, modules=$(echo "$MODULES_COVERED" | jq 'length'), coverage=$(echo "$COVERAGE_INDICATORS" | jq -c .))"
