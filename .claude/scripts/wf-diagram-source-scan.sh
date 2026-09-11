#!/usr/bin/env bash
# wf-diagram-source-scan.sh — Phase 2 source code analysis cho /wf-diagram
# Sprint 4 bash delegation
#
# Usage:
#   bash .claude/scripts/wf-diagram-source-scan.sh \
#        <source_path> <module_or_empty> <scope> <session_id> <output_file>
#
# Args:
#   source_path  — Root source code path (--source-path arg)
#   module       — Module name (empty string nếu scope=system-only)
#   scope        — full | module-only | system-only
#   session_id   — Session ID đã generate
#   output_file  — Path to analysis.json
#
# Output: analysis.json (schema analysis-v1, xem _shared.md)
# Behavior: best-effort scan với conservative heuristics. Section nào
#   không detect được → empty array. AI tầng trên có thể refine sau.
#
# Compliance:
#   - BHV-002: KHÔNG bịa entity/endpoint, mark `// TODO: cần xác nhận` khi mơ hồ
#   - CORE-024: output có căn cứ — chỉ đưa vào analysis.json những gì grep được

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="wf-diagram-source-scan"
# shellcheck source=./wf-diagram-common.sh
source "$SCRIPTS_DIR/wf-diagram-common.sh"

set -euo pipefail 2>/dev/null || set -e

# ─── Args ────────────────────────────────────────────────────

SOURCE_PATH="${1:?Usage: $0 <source_path> <module> <scope> <session_id> <output_file>}"
MODULE="${2:-}"
SCOPE="${3:-full}"
SESSION_ID="${4:?session_id required}"
OUTPUT_FILE="${5:?output_file required}"

if [[ ! -d "$SOURCE_PATH" ]]; then
  log_error "source_path không tồn tại: $SOURCE_PATH"
  exit 1
fi

log_info "Scanning source: $SOURCE_PATH (module=$MODULE, scope=$SCOPE)"

# Exclusion dirs — loại noise khỏi find/grep
readonly EXCLUDE_DIRS=(
  node_modules .git dist build .next .nuxt out coverage
  .cache .turbo vendor __pycache__ .venv venv .idea .vscode
  bin obj packages .gradle .mvn target tmp .mc-data .backup
)

# Build prune args cho find
build_prune_args() {
  local args=()
  local d
  for d in "${EXCLUDE_DIRS[@]}"; do
    args+=( -path "*/$d" -prune -o )
  done
  echo "${args[@]}"
}

# ─── 1. Detect modules ──────────────────────────────────────

scan_modules() {
  local out=""
  local prune_args
  prune_args=$(build_prune_args)

  # Folder-based: apps/*/, src/modules/*/, services/*/, packages/*/
  local found=()
  local d
  for pattern in "apps" "src/modules" "modules" "services" "packages" "src/services" "src/features" "features"; do
    if [[ -d "$SOURCE_PATH/$pattern" ]]; then
      while IFS= read -r d; do
        [[ -z "$d" ]] && continue
        local name
        name=$(basename "$d")
        # Skip common non-module folders
        case "$name" in
          shared|common|utils|helpers|types|core|lib|libs|public|assets) continue ;;
        esac
        local rel="${d#$SOURCE_PATH/}"
        found+=("{\"name\":\"$(json_escape "$name")\",\"path\":\"$(json_escape "$rel")\",\"type\":\"folder\"}")
      done < <(find "$SOURCE_PATH/$pattern" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    fi
  done

  # .NET: namespace Eureka.Modules.{Name}
  if [[ -d "$SOURCE_PATH" ]]; then
    while IFS= read -r ns; do
      [[ -z "$ns" ]] && continue
      local name="${ns##*.}"
      [[ -z "$name" ]] && continue
      found+=("{\"name\":\"$(json_escape "$name")\",\"path\":\"\",\"type\":\"namespace\"}")
    done < <(grep -rh --include="*.cs" -E '^namespace [A-Za-z][A-Za-z0-9_.]*' "$SOURCE_PATH" 2>/dev/null \
              | sed -E 's/namespace[[:space:]]+([A-Za-z][A-Za-z0-9_.]*).*/\1/' \
              | sort -u | head -100)
  fi

  if [[ ${#found[@]} -eq 0 ]]; then
    echo "[]"
  else
    echo "[$(IFS=,; echo "${found[*]}")]"
  fi
}

# ─── 2. Detect entities (DB schema) ─────────────────────────

scan_entities() {
  local found=()

  # Strategy 1: Prisma schema
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    while IFS= read -r model; do
      [[ -z "$model" ]] && continue
      found+=("{\"name\":\"$(json_escape "$model")\",\"source\":\"prisma\",\"file\":\"$(json_escape "${f#$SOURCE_PATH/}")\",\"columns\":[],\"fks\":[],\"_todo\":\"cần xác nhận columns + fks\"}")
    done < <(grep -E '^model [A-Z]' "$f" 2>/dev/null | awk '{print $2}')
  done < <(find "$SOURCE_PATH" -type f -name "schema.prisma" 2>/dev/null | head -20)

  # Strategy 2: TypeORM @Entity / Entity files
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local class_name
    class_name=$(grep -oE 'class [A-Z][A-Za-z0-9]+' "$f" 2>/dev/null | head -1 | awk '{print $2}')
    [[ -z "$class_name" ]] && continue
    found+=("{\"name\":\"$(json_escape "$class_name")\",\"source\":\"typeorm\",\"file\":\"$(json_escape "${f#$SOURCE_PATH/}")\",\"columns\":[],\"fks\":[],\"_todo\":\"cần parse @Column / @ManyToOne\"}")
  done < <(grep -rl --include="*.ts" -E '@Entity\(' "$SOURCE_PATH" 2>/dev/null | head -50)

  # Strategy 3: SQL migrations — CREATE TABLE
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    while IFS= read -r tbl; do
      [[ -z "$tbl" ]] && continue
      found+=("{\"name\":\"$(json_escape "$tbl")\",\"source\":\"sql\",\"file\":\"$(json_escape "${f#$SOURCE_PATH/}")\",\"columns\":[],\"fks\":[],\"_todo\":\"cần parse columns từ CREATE TABLE\"}")
    done < <(grep -iE 'CREATE TABLE' "$f" 2>/dev/null | sed -E 's/.*CREATE TABLE[[:space:]]+(IF NOT EXISTS[[:space:]]+)?["`]?([A-Za-z_][A-Za-z0-9_]*)["`]?.*/\2/i' | sort -u)
  done < <(find "$SOURCE_PATH" -type f \( -name "*.sql" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -100)

  # Strategy 4: .NET EF DbContext — DbSet<EntityName>
  while IFS= read -r ent; do
    [[ -z "$ent" ]] && continue
    found+=("{\"name\":\"$(json_escape "$ent")\",\"source\":\"ef-dbcontext\",\"file\":\"\",\"columns\":[],\"fks\":[],\"_todo\":\"cần parse properties từ EF model\"}")
  done < <(grep -rh --include="*.cs" -oE 'DbSet<[A-Z][A-Za-z0-9]+>' "$SOURCE_PATH" 2>/dev/null \
            | sed -E 's/DbSet<([A-Za-z0-9]+)>/\1/' | sort -u | head -100)

  if [[ ${#found[@]} -eq 0 ]]; then
    echo "[]"
  else
    echo "[$(IFS=,; echo "${found[*]}")]"
  fi
}

# ─── 3. Detect endpoints ────────────────────────────────────

scan_endpoints() {
  local found=()

  # Strategy 1: Express/Hono/Fastify — app.get/post/put/delete + router.*
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local file path method
    file=$(echo "$line" | cut -d: -f1)
    file="${file#$SOURCE_PATH/}"
    method=$(echo "$line" | grep -oE '\.(get|post|put|delete|patch)' | head -1 | tr -d '.' | tr '[:lower:]' '[:upper:]')
    path=$(echo "$line" | grep -oE "['\"\`]/[^'\"\`]+['\"\`]" | head -1 | tr -d "'\"\`")
    [[ -z "$path" || -z "$method" ]] && continue
    found+=("{\"method\":\"$method\",\"path\":\"$(json_escape "$path")\",\"handler\":\"\",\"file\":\"$(json_escape "$file")\",\"_todo\":\"cần xác nhận handler + services_called\"}")
  done < <(grep -rn --include="*.ts" --include="*.js" -E '\.(get|post|put|delete|patch)\(' "$SOURCE_PATH" 2>/dev/null | head -200)

  # Strategy 2: NestJS — @Get('/...'), @Post('/...')
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local file path method
    file=$(echo "$line" | cut -d: -f1)
    file="${file#$SOURCE_PATH/}"
    method=$(echo "$line" | grep -oE '@(Get|Post|Put|Delete|Patch)\(' | head -1 | tr -d '@(' | tr '[:lower:]' '[:upper:]')
    path=$(echo "$line" | grep -oE "@(Get|Post|Put|Delete|Patch)\(['\"][^'\"]*['\"]" | grep -oE "['\"][^'\"]*['\"]" | head -1 | tr -d "'\"")
    [[ -z "$method" ]] && continue
    [[ -z "$path" ]] && path="/"
    found+=("{\"method\":\"$method\",\"path\":\"$(json_escape "$path")\",\"handler\":\"\",\"file\":\"$(json_escape "$file")\",\"_todo\":\"cần xác nhận handler\"}")
  done < <(grep -rn --include="*.ts" -E '@(Get|Post|Put|Delete|Patch)\(' "$SOURCE_PATH" 2>/dev/null | head -200)

  # Strategy 3: .NET — [HttpGet], [HttpPost] + [Route("...")]
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local file method
    file=$(echo "$line" | cut -d: -f1)
    file="${file#$SOURCE_PATH/}"
    method=$(echo "$line" | grep -oE '\[Http(Get|Post|Put|Delete|Patch)' | head -1 | sed -E 's/\[Http(.*)/\1/' | tr '[:lower:]' '[:upper:]')
    [[ -z "$method" ]] && continue
    found+=("{\"method\":\"$method\",\"path\":\"\",\"handler\":\"\",\"file\":\"$(json_escape "$file")\",\"_todo\":\"cần parse [Route] attribute để có path\"}")
  done < <(grep -rn --include="*.cs" -E '\[Http(Get|Post|Put|Delete|Patch)' "$SOURCE_PATH" 2>/dev/null | head -200)

  # Strategy 3b: .NET Minimal API — group.MapGet("..."), app.MapPost("...")
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local file method path
    file=$(echo "$line" | cut -d: -f1)
    file="${file#$SOURCE_PATH/}"
    method=$(echo "$line" | grep -oE '\.(Map)(Get|Post|Put|Delete|Patch)\(' | head -1 | sed -E 's/\.Map([A-Za-z]+)\(/\1/' | tr '[:lower:]' '[:upper:]')
    path=$(echo "$line" | grep -oE '\.(Map)(Get|Post|Put|Delete|Patch)\("[^"]*"' | grep -oE '"[^"]*"' | head -1 | tr -d '"')
    [[ -z "$method" ]] && continue
    [[ -z "$path" ]] && path="/"
    found+=("{\"method\":\"$method\",\"path\":\"$(json_escape "$path")\",\"handler\":\"\",\"file\":\"$(json_escape "$file")\",\"_todo\":\"cần parse handler + services_called\"}")
  done < <(grep -rn --include="*.cs" -E '\.(Map)(Get|Post|Put|Delete|Patch)\(' "$SOURCE_PATH" 2>/dev/null | head -200)

  # Strategy 4: Spring — @GetMapping, @PostMapping
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local file method path
    file=$(echo "$line" | cut -d: -f1)
    file="${file#$SOURCE_PATH/}"
    method=$(echo "$line" | grep -oE '@(Get|Post|Put|Delete|Patch)Mapping' | head -1 | sed -E 's/@(.*)Mapping/\1/' | tr '[:lower:]' '[:upper:]')
    path=$(echo "$line" | grep -oE '"[^"]*"' | head -1 | tr -d '"')
    [[ -z "$method" ]] && continue
    [[ -z "$path" ]] && path="/"
    found+=("{\"method\":\"$method\",\"path\":\"$(json_escape "$path")\",\"handler\":\"\",\"file\":\"$(json_escape "$file")\",\"_todo\":\"cần parse class @RequestMapping prefix\"}")
  done < <(grep -rn --include="*.java" -E '@(Get|Post|Put|Delete|Patch)Mapping' "$SOURCE_PATH" 2>/dev/null | head -200)

  if [[ ${#found[@]} -eq 0 ]]; then
    echo "[]"
  else
    echo "[$(IFS=,; echo "${found[*]}")]"
  fi
}

# ─── 4. Detect actors (auth patterns) ───────────────────────

scan_actors() {
  local found=()

  # Strategy: grep role keywords và auth patterns
  local roles_seen=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local role
    role=$(echo "$line" | grep -oE "['\"][A-Za-z_][A-Za-z0-9_-]+['\"]" | head -1 | tr -d "'\"")
    [[ -z "$role" ]] && continue
    case "$role" in admin|Admin|user|User|guest|Guest|customer|Customer|staff|Staff|manager|Manager|owner|Owner) ;; *) continue ;; esac
    local seen=0
    for r in "${roles_seen[@]:-}"; do
      [[ "$r" == "$role" ]] && seen=1 && break
    done
    [[ $seen -eq 1 ]] && continue
    roles_seen+=("$role")
    found+=("{\"name\":\"$(json_escape "$role")\",\"role\":\"$(json_escape "$role")\",\"modules_used\":[],\"auth_pattern\":\"role-based\",\"_todo\":\"cần xác nhận modules_used + auth_pattern chi tiết\"}")
  done < <(grep -rh --include="*.ts" --include="*.js" --include="*.cs" --include="*.java" --include="*.py" \
            -E '(@Roles|hasRole|\[Authorize\(Roles|@PreAuthorize|require_role)' "$SOURCE_PATH" 2>/dev/null | head -200)

  # Detect anonymous/public access marker (not actor, but useful)
  if grep -rq --include="*.cs" '\[AllowAnonymous\]' "$SOURCE_PATH" 2>/dev/null; then
    found+=("{\"name\":\"Anonymous\",\"role\":\"anonymous\",\"modules_used\":[],\"auth_pattern\":\"@AllowAnonymous\",\"_todo\":\"public endpoints\"}")
  fi

  if [[ ${#found[@]} -eq 0 ]]; then
    echo "[]"
  else
    echo "[$(IFS=,; echo "${found[*]}")]"
  fi
}

# ─── 5. Detect state machines (enum *Status / type *State) ──

scan_state_machines() {
  local found=()
  local seen=()

  # TS/JS: enum XxxStatus { ... } | type XxxState = ...
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local entity
    entity=$(echo "$line" | grep -oE '(enum|type)[[:space:]]+[A-Z][A-Za-z]+' | awk '{print $2}' | head -1)
    [[ -z "$entity" ]] && continue
    [[ ! "$entity" =~ (Status|State|Stage|Phase)$ ]] && continue
    local already=0
    for s in "${seen[@]:-}"; do [[ "$s" == "$entity" ]] && already=1 && break; done
    [[ $already -eq 1 ]] && continue
    seen+=("$entity")
    found+=("{\"entity\":\"$(json_escape "$entity")\",\"states\":[],\"transitions\":[],\"_todo\":\"cần parse enum members\"}")
  done < <(grep -rhE --include="*.ts" --include="*.js" --include="*.cs" --include="*.java" \
            '(enum|type)[[:space:]]+[A-Z][A-Za-z]+(Status|State|Stage|Phase)' "$SOURCE_PATH" 2>/dev/null | head -100)

  if [[ ${#found[@]} -eq 0 ]]; then
    echo "[]"
  else
    echo "[$(IFS=,; echo "${found[*]}")]"
  fi
}

# ─── 6. Build analysis.json ─────────────────────────────────

log_info "Scanning modules..."
modules_json=$(scan_modules)
log_info "Scanning entities..."
entities_json=$(scan_entities)
log_info "Scanning endpoints..."
endpoints_json=$(scan_endpoints)
log_info "Scanning actors..."
actors_json=$(scan_actors)
log_info "Scanning state machines..."
state_machines_json=$(scan_state_machines)

# processes / scenarios / usecase_groups: để AI tầng trên derive từ endpoints + entities
# (vì cần hiểu business logic — bash heuristic dễ false positive).
processes_json="[]"
scenarios_json="[]"
usecase_groups_json="[]"

scanned_at=$(iso8601_now)

raw_json=$(cat <<EOF
{
  "\$schema": "analysis-v1",
  "session_id": "$(json_escape "$SESSION_ID")",
  "scanned_at": "$scanned_at",
  "source_path": "$(json_escape "$SOURCE_PATH")",
  "module": "$(json_escape "$MODULE")",
  "scope": "$(json_escape "$SCOPE")",
  "modules": $modules_json,
  "entities": $entities_json,
  "endpoints": $endpoints_json,
  "actors": $actors_json,
  "state_machines": $state_machines_json,
  "processes": $processes_json,
  "scenarios": $scenarios_json,
  "usecase_groups": $usecase_groups_json,
  "_meta": {
    "generator": "wf-diagram-source-scan.sh",
    "version": "1.0",
    "note": "Best-effort scan. AI tầng trên có thể refine entities.columns, endpoints.handler, usecase_groups."
  }
}
EOF
)

safe_write_json "$OUTPUT_FILE" "$raw_json"

# Summary line cho caller
modules_count=$(echo "$modules_json" | jq 'length' 2>/dev/null || echo "0")
entities_count=$(echo "$entities_json" | jq 'length' 2>/dev/null || echo "0")
endpoints_count=$(echo "$endpoints_json" | jq 'length' 2>/dev/null || echo "0")
actors_count=$(echo "$actors_json" | jq 'length' 2>/dev/null || echo "0")
sm_count=$(echo "$state_machines_json" | jq 'length' 2>/dev/null || echo "0")

log_info "Wrote analysis.json: modules=$modules_count entities=$entities_count endpoints=$endpoints_count actors=$actors_count state_machines=$sm_count"
echo "modules=$modules_count entities=$entities_count endpoints=$endpoints_count actors=$actors_count state_machines=$sm_count"
