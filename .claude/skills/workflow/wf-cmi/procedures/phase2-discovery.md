# Phase 2 — Discovery (6 Core + 4 FE Plugin + 3 BE Plugin Graphs, v2.0 Stage 2.2 COMPLETE)

> **Đầu vào:** `integrity-status.json` (Phase 1), code paths, CI tools, `$CI_CONTEXT`, `phase1-business/`, `phase2-features/`, `phase3-architecture/`
> **Đầu ra:** 6 core graphs `*.json` (entity/module/workflow/api/event/rbac) + 4 FE plugin graphs (`fe-component-graph.json`, `fe-api-client-graph.json`, `fe-permission-graph.json`, `fe-route-graph.json`) + 3 BE plugin graphs v2.0 Stage 2.2 (`be-domain-graph.json`, `be-db-schema-graph.json`, `be-cqrs-graph.json`) + `Phase2-report.md`
> **Auto-fix budget:** 3 retries
> **Time estimate (standard profile, EUREKA 17 modules):** 3-6 min (core) + 2-4 min (4 FE plugins) + 4-8 min (3 BE plugins)
> **Required:** ✅ (Always — discovery foundation). Plugin graphs OPTIONAL — skip gracefully nếu prerequisite không có.
>
> **v2.0 Stage 2.1 (4 FE plugins active):** `fe-component-graph` (CD11), `fe-api-client-graph` (CD13, CD38), `fe-permission-graph` (CD15, CD38), `fe-route-graph` (CD25, CD38).
> **v2.0 Stage 2.2 (3/3 BE plugins active — COMPLETE 2026-05-16):** `be-domain-graph` (CD16), `be-db-schema-graph` (CD17), `be-cqrs-graph` (CD18). Tất cả lanes BE có graph dependency đầy đủ — KHÔNG còn fallback Serena/Grep warning E133/E134/E135 nữa khi plugin available.

---

## §A Header

Phase 2 build 6 core dependency graphs + 1 plugin graph (v2.0 vertical slice) từ source code + docs:

| Graph | Mục đích | Primary CI tool | Fallback | Required |
|-------|---------|-----------------|----------|----------|
| `entity-graph.json` | Domain entities + FK relations | GitNexus `clusters` + Serena `find_symbol` | Glob `**/Domain/Entities/*.cs` | ✅ |
| `module-graph.json` | Module dependencies | GitNexus `query(key_concept)` | Grep `using.*Modules` | ✅ |
| `workflow-graph.json` | Business workflows + state transitions | GitNexus `query(workflow)` + Serena `get_symbols_overview` | Grep CQRS Command/Handler | ✅ |
| `api-graph.json` | API endpoints + request/response schemas | GitNexus `route_map()` | Grep `MapPost\|MapGet\|MapPut` | ✅ |
| `event-graph.json` | Events + producers/consumers | GitNexus `cypher` + Serena `find_refs` | Grep `IntegrationEvent\|DomainEvent` | ⚠ Skip nếu không có broker |
| `rbac-matrix.json` | Actors × Actions × Resources | Serena `find_symbol(Authorization)` | Grep `[Authorize]\|[RequirePermission]` | ✅ |
| **`fe-component-graph.json`** ★ v2.0 | FE component contracts + props + import edges | Grep `apps/erp-web/components/**/*.tsx` + AST props parse | Grep-based v1.0 (v2.1 → ts-morph) | ⚠ Skip nếu không có erp-web |
| **`fe-api-client-graph.json`** ★ v2.0 | FE→BE API consumption (RQ hooks, Refit, raw fetch/axios) | Grep `useQuery\|useMutation\|fetch\|axios` + Refit interfaces | Grep-based v1.0 (v2.1 → ts-morph) | ⚠ Skip nếu không có erp-web |
| **`fe-permission-graph.json`** ★ v2.0 | UI permission guards (PermissionGate/usePermission/Can/hasPermission/authorize) | Grep pattern matching | Grep-based v1.0 (v2.1 → ts-morph dynamic perm resolution) | ⚠ Skip nếu không có erp-web |
| **`fe-route-graph.json`** ★ v2.0 | Next.js App Router pages/layouts/middleware + dynamic/protected segments | Filesystem traversal `app/**/page.tsx,layout.tsx` | filesystem-based v1.0 (v2.1 → AST cho metadata exports) | ⚠ Skip nếu không có `apps/erp-web/app/` |
| **`be-domain-graph.json`** ★ v2.0 Stage 2.2 | C# DDD types: AggregateRoot, Entity, ValueObject, DomainEvent, DomainEventHandler, Specification, Repository interface + inheritance/raises_event/handles_event edges | Grep `:\s*AggregateRoot\|:\s*Entity<\|:\s*ValueObject\|:\s*I?DomainEvent` | Grep-based v1.0 (v2.1 → Roslyn syntax tree analyzer) | ⚠ Skip nếu không có `apps/backend/*/Domain/` hoặc `EventHandlers/` |
| **`be-db-schema-graph.json`** ★ v2.0 Stage 2.2 | EF Core DB schema cumulative state: tables, columns (sql_type/csharp_type/nullable/max_length), primary keys, indexes (with unique flag), foreign keys, on_delete behavior | Python parser DbContextModelSnapshot.cs primary, fallback Migrations/*.cs CreateTable+AddForeignKey+CreateIndex | Python parser v1.0 fluent API multi-line (v2.1 → `dotnet ef dbcontext info --json`) | ⚠ Skip nếu không có DbContextModelSnapshot.cs hoặc `**/Migrations/*.cs` |
| **`be-cqrs-graph.json`** ★ v2.0 Stage 2.2 | MediatR CQRS pipeline: commands, queries, handlers, validators (FluentValidation), pipeline behaviors, notifications, notification handlers + handles/validates/notifies edges + coverage indicators (requests_without_handler/validator) | Python parser scan `Application/**` + `Behaviors/**` `: IRequest\|: IRequestHandler\|: AbstractValidator\|: IPipelineBehavior\|: INotification` | Python parser v1.0 single-pass JSON Lines (v2.1 → Roslyn namespace resolution) | ⚠ Skip nếu không có `apps/backend/*/Application/` |

**Mode:** HYBRID — 6 core graph builders + 4 FE plugin builders + 3 BE plugin builders (be-domain + be-db-schema + be-cqrs) chạy parallel theo loại resource.

**Profile skip rules:**
- CD5 event graph: skip nếu `profile=quick` HOẶC project không có RabbitMQ/SignalR
- Plugin v2 FE graphs (fe-component, fe-api-client, fe-permission, fe-route): skip gracefully nếu prerequisite path không tồn tại (E137 WARN). KHÔNG block phase nếu skipped.
- Plugin v2 BE graphs:
  - **be-domain** (CD16): skip nếu không có `apps/backend/*/Domain/` subdirs (E137 WARN). Lane CD16 fallback Serena/Grep với E133 WARN.
  - **be-db-schema** (CD17): skip nếu không có DbContextModelSnapshot.cs hoặc `**/Migrations/*.cs` (E137 WARN). Lane CD17 fallback Grep với E134 WARN.
  - **be-cqrs** (CD18): skip nếu không có `apps/backend/*/Application/` (E137 WARN). Lane CD18 fallback Grep MediatR patterns với E135 WARN.
- Các core graph khác: luôn build (CD1-CD4, CD7 needed cho mọi profile)

**Shared sections cần load:**
- `_shared.md §1` (State Variables)
- `_shared.md §3` (Atomic Write)
- `_shared.md §12` (CI Detection)
- `_shared.md §15` (Agent Prompt — optional `architect` cho LLM-assisted parse)

---

## §B PRE-GATE (T1→T4 Forensic)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `test -f $SESSION_DIR/integrity-status.json` | bash | **E020** — Phase 1 state missing → re-run Phase 1 |
| T2 | `jq -e '.current_phase == 2'` integrity-status.json | jq | **E021** — state inconsistency → reset state |
| T3 | Code paths scannable: `find src apps -type f -name '*.cs' -o -name '*.ts' \| head -1` non-empty (OR Grep fallback OK) | composite | **E022** — code unreachable → ESCALATE permissions |
| T4 | Module list từ registry ⊆ folder structure | bash + jq | **E023** — module-code drift (CORE-013) → ESCALATE `/wf-legacy-scan` |

**PRE-GATE pseudocode:**

```bash
# T1
[ -f "$SESSION_DIR/integrity-status.json" ] || die "E020" "Phase 1 state missing"

# T2
[ "$(jq -r '.current_phase' "$SESSION_DIR/integrity-status.json")" = "2" ] \
  || die "E021" "current_phase != 2"

# T3 — code paths scannable
CODE_FILES=$(find . -path ./.mc-data -prune -o \
              \( -name '*.cs' -o -name '*.ts' -o -name '*.tsx' -o -name '*.py' \) \
              -type f -print 2>/dev/null | head -1)
[ -z "$CODE_FILES" ] && die "E022" "No source files scannable (check permissions)"

# T4 — module list cross-validation
REGISTRY_MODULES=$(jq -r '.modules[]?.name // empty' .mc-data/docs/_meta/req-registry.json 2>/dev/null)
FOLDER_MODULES=$(ls -d apps/backend/*.Modules.* 2>/dev/null | sed 's|.*Modules\.||' | tr '[:upper:]' '[:lower:]')
DRIFT=$(comm -23 <(echo "$REGISTRY_MODULES" | sort -u) <(echo "$FOLDER_MODULES" | sort -u))
[ -n "$DRIFT" ] && log_warn "E023" "Module-code drift: $DRIFT"
```

---

## §C Steps (Execution Detail)

### Step 2.1 — Load registry + phase docs (read-only)

```bash
REGISTRY_PATH=".mc-data/docs/_meta/req-registry.json"
ARCH_PATH=".mc-data/docs/phase3-architecture"
BUSINESS_PATH=".mc-data/docs/phase1-business"
FEATURES_PATH=".mc-data/docs/phase2-features"

REGISTRY_MODULES=$(jq -r '.modules // [] | map({name, department}) | tojson' "$REGISTRY_PATH")
REGISTRY_DEPTS=$(jq -r '.modules // [] | map(.department) | unique | tojson' "$REGISTRY_PATH")
export REGISTRY_MODULES REGISTRY_DEPTS

log_phase_event "phase2" "INFO" "{\"modules_count\":$(echo "$REGISTRY_MODULES" | jq 'length')}"
```

### Step 2.2 — Detect tech stack (CORE-014)

> Priority: `code_parse > config > doc_infer`.

```bash
TECH_STACK="{}"

# Backend
if find apps/backend -name '*.csproj' 2>/dev/null | head -1 >/dev/null; then
  TECH_STACK=$(echo "$TECH_STACK" | jq '.backend = {language:"C#", framework:".NET", version:"10"}')
fi

# Frontend
if [ -f apps/erp-web/package.json ]; then
  NEXT_VER=$(jq -r '.dependencies.next // .devDependencies.next // "unknown"' apps/erp-web/package.json)
  TECH_STACK=$(echo "$TECH_STACK" | jq --arg v "$NEXT_VER" '.frontend = {language:"TypeScript", framework:"Next.js", version:$v}')
fi

# Database
if grep -rqE '(Npgsql|"postgres":|PostgreSQL)' apps/backend 2>/dev/null; then
  TECH_STACK=$(echo "$TECH_STACK" | jq '.database = {engine:"PostgreSQL", version:"16"}')
fi

# Message broker
if grep -rqE 'RabbitMQ|MassTransit' apps/backend 2>/dev/null; then
  TECH_STACK=$(echo "$TECH_STACK" | jq '.broker = "RabbitMQ"')
  HAS_EVENT_INFRA=true
fi

# SignalR
if grep -rqE 'SignalR|Hub' apps/backend 2>/dev/null; then
  TECH_STACK=$(echo "$TECH_STACK" | jq '.realtime = "SignalR"')
  HAS_REALTIME=true
fi

export TECH_STACK HAS_EVENT_INFRA HAS_REALTIME
log_phase_event "phase2" "INFO" "{\"tech_stack\":$TECH_STACK}"
```

### Step 2.3 — Build `entity-graph.json` (Discovery #1)

```bash
TARGET="$SESSION_DIR/phase2-discovery/entity-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/entity-graph.json"

# 1. READ template + strip metadata
strip_template_metadata "$TPL" "$TARGET"

# 2. Build nodes (entities)
if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
  # Primary: GitNexus clusters
  ENTITIES=$(gitnexus clusters --category=entity 2>/dev/null | jq '[.[] | {id, name, module, type:"entity"}]')
elif [ "$SERENA_AVAILABLE" = "true" ]; then
  # Secondary: Serena find_symbol pattern
  ENTITIES=$(serena find_symbol --pattern='*/Domain/Entities/*' --include-body=false 2>/dev/null \
            | jq '[.[] | {id: .name_path, name: .name, module: (.relative_path | capture("Modules\\.(?<m>[A-Z]+)") | .m // "unknown"), type:"entity"}]')
else
  # Fallback: Glob + Grep
  ENTITIES=$(find apps/backend -path '*/Domain/Entities/*.cs' -type f 2>/dev/null \
            | jq -R 'capture("Eureka\\.Modules\\.(?<m>[A-Z]+)/Domain/Entities/(?<n>\\w+)\\.cs") | {id: (.m+"."+.n), name: .n, module: (.m | ascii_downcase), type:"entity"}' \
            | jq -s '.')
fi

# 3. Build edges (FK relations)
# Parse EF Core configurations + Domain navigation properties
if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
  EDGES=$(gitnexus query --cypher='MATCH (a:Entity)-[r:REFERENCES]->(b:Entity) RETURN a.name,b.name,r.type' 2>/dev/null \
         | jq '[.[] | {from: .a, to: .b, kind: .type}]')
else
  # Grep fallback: look for FK declarations in EF Core configurations
  EDGES=$(grep -rE 'HasOne|HasMany|WithOne|WithMany' apps/backend --include='*.cs' 2>/dev/null \
         | jq -R 'split(":")[1] | capture("HasOne<(?<t>\\w+)>") | {kind:"fk", to: .t}' \
         | jq -s '[.[] | select(.to != null)]')
fi

# 4. Populate template
jq --argjson nodes "$ENTITIES" --argjson edges "$EDGES" \
   --arg sid "$SESSION_ID" --arg ts "$(date -Iseconds)" \
   '. + {session_id: $sid, generated_at: $ts, nodes: $nodes, edges: $edges,
         audit_chain: {source: "code+ef_config", checksum: ""}}' \
   "$TARGET" > "$TARGET.tmp.$$"

# 5. Validate + atomic write
jq '.' "$TARGET.tmp.$$" >/dev/null && mv "$TARGET.tmp.$$" "$TARGET" \
  || { log_phase_fail "E024" "entity-graph build fail — fallback heuristic Grep"; }
```

### Step 2.4 — Build `module-graph.json` (Discovery #2)

```bash
TARGET="$SESSION_DIR/phase2-discovery/module-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/module-graph.json"
strip_template_metadata "$TPL" "$TARGET"

# Nodes: each module = 1 node
MODULE_NODES=$(echo "$REGISTRY_MODULES" | jq '[.[] | {id: .name, name: .name, department: .department, type: "module"}]')

# Edges: project references (apps/backend/*.csproj <ProjectReference>)
if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
  EDGES=$(gitnexus query --concept="module dependency" 2>/dev/null \
         | jq '[.[] | {from: .source_module, to: .target_module, kind: "depends_on"}]')
else
  EDGES=$(find apps/backend -name '*.csproj' -exec grep -l 'ProjectReference' {} \; \
         | while read csproj; do
             src_mod=$(echo "$csproj" | sed -E 's|.*Eureka\.Modules\.([A-Z]+).*|\1|' | tr '[:upper:]' '[:lower:]')
             grep -oE 'Eureka\.Modules\.[A-Z]+' "$csproj" 2>/dev/null \
               | sed -E 's|Eureka\.Modules\.([A-Z]+)|\1|' | tr '[:upper:]' '[:lower:]' \
               | grep -v "^$src_mod$" \
               | jq -nR --arg s "$src_mod" 'inputs | {from: $s, to: ., kind: "depends_on"}'
           done | jq -s '.')
fi

jq --argjson nodes "$MODULE_NODES" --argjson edges "$EDGES" \
   --arg sid "$SESSION_ID" --arg ts "$(date -Iseconds)" \
   '. + {session_id: $sid, generated_at: $ts, modules: $nodes, edges: $edges}' \
   "$TARGET" > "$TARGET.tmp.$$" && mv "$TARGET.tmp.$$" "$TARGET"
```

### Step 2.5 — Build `workflow-graph.json` (Discovery #3)

```bash
TARGET="$SESSION_DIR/phase2-discovery/workflow-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/workflow-graph.json"
strip_template_metadata "$TPL" "$TARGET"

# CQRS pattern: Commands/Queries/Handlers/State transitions
# Each Command = 1 node, transitions parsed từ state machine code
if [ "$SERENA_AVAILABLE" = "true" ]; then
  WORKFLOWS=$(serena find_symbol --pattern='*Command' --include-body=false 2>/dev/null \
             | jq '[.[] | {id: .name_path, name: .name, module: (.relative_path | capture("Modules\\.(?<m>[A-Z]+)") | .m // "unknown")}]')
else
  WORKFLOWS=$(grep -rE 'public (record|class) \w+Command' apps/backend --include='*.cs' 2>/dev/null \
             | jq -R 'capture("(?<m>Modules\\.[A-Z]+).*?(record|class) (?<n>\\w+Command)") | {id: .n, name: .n, module: .m}' \
             | jq -s '.')
fi

# Edges: workflow → handler → repository → DB
# Trace per Command name
EDGES="[]"
if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
  EDGES=$(gitnexus query --concept="workflow trace" 2>/dev/null \
         | jq '[.[] | {from: .command, to: .handler, kind: "handled_by"}]')
fi

jq --argjson nodes "$WORKFLOWS" --argjson edges "$EDGES" \
   --arg sid "$SESSION_ID" --arg ts "$(date -Iseconds)" \
   '. + {session_id: $sid, generated_at: $ts, workflows: $nodes, edges: $edges}' \
   "$TARGET" > "$TARGET.tmp.$$" && mv "$TARGET.tmp.$$" "$TARGET"

# If workflow_count < 1 → WARN E025 (no CQRS pattern detected, skip workflow graph)
WORKFLOW_COUNT=$(jq '.workflows | length' "$TARGET")
[ "$WORKFLOW_COUNT" -eq 0 ] && log_warn "E025" "No workflow pattern detected"
```

### Step 2.6 — Build `api-graph.json` (Discovery #4)

```bash
TARGET="$SESSION_DIR/phase2-discovery/api-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/api-graph.json"
strip_template_metadata "$TPL" "$TARGET"

# Endpoints — group by client routing
if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
  ENDPOINTS=$(gitnexus route_map 2>/dev/null \
             | jq '[.[] | {id: .path, method: .method, module: .module, client: (
                              if (.path | startswith("/api/v1/customer/mobile/")) then "mobile-customer"
                              elif (.path | test("/api/v1/(?:[^/]+/)?(staff/)?mobile/")) then "mobile-staff"
                              else "erp-web" end
                            ),
                            request_schema: .request_dto, response_schema: .response_dto,
                            auth_required: .auth_required, identity_check: .identity_check}]')
else
  # Fallback: Grep MapPost|MapGet|MapPut|MapDelete
  ENDPOINTS=$(grep -rnE 'app\.Map(Post|Get|Put|Delete)' apps/backend --include='*.cs' 2>/dev/null \
             | jq -R 'capture("(?<f>[^:]+):(?<l>\\d+).*Map(?<m>Post|Get|Put|Delete).*\"(?<p>[^\"]+)\"")
                       | {id: (.m + " " + .p), method: .m, path: .p, file: .f, line: (.l | tonumber)}' \
             | jq -s '.')
fi

jq --argjson eps "$ENDPOINTS" --arg sid "$SESSION_ID" --arg ts "$(date -Iseconds)" \
   '. + {session_id: $sid, generated_at: $ts, endpoints: $eps}' \
   "$TARGET" > "$TARGET.tmp.$$" && mv "$TARGET.tmp.$$" "$TARGET"
```

### Step 2.7 — Build `event-graph.json` (Discovery #5)

> SKIP nếu `profile=quick` HOẶC `$HAS_EVENT_INFRA != true`.

```bash
if [ "$PROFILE" = "quick" ] || [ "$HAS_EVENT_INFRA" != "true" ]; then
  log_phase_event "phase2" "SKIP" "{\"step\":\"event-graph\",\"reason\":\"profile=quick or no event infra\"}"
  # Create empty placeholder
  echo '{"$schema":"event-graph-v1","events":[],"edges":[],"skipped":true}' \
    > "$SESSION_DIR/phase2-discovery/event-graph.json"
else
  TARGET="$SESSION_DIR/phase2-discovery/event-graph.json"
  TPL=".claude/skills/workflow/wf-cmi/templates/event-graph.json"
  strip_template_metadata "$TPL" "$TARGET"

  # Events: IntegrationEvent + DomainEvent
  if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
    EVENTS=$(gitnexus cypher 'MATCH (e:Event) RETURN e.name, e.module' 2>/dev/null \
            | jq '[.[] | {id: ."e.name", name: ."e.name", module: ."e.module", kind: "event"}]')
  else
    EVENTS=$(grep -rnE 'class \w+(IntegrationEvent|DomainEvent)' apps/backend --include='*.cs' 2>/dev/null \
            | jq -R 'capture("(?<f>[^:]+).*class (?<n>\\w+(?:Integration|Domain)Event)")
                      | {id: .n, name: .n, file: .f, kind: "event"}' \
            | jq -s '.')
  fi

  # Producers + Consumers
  if [ "$SERENA_AVAILABLE" = "true" ]; then
    EDGES=$(echo "$EVENTS" | jq -r '.[].name' | while read ev; do
              serena find_references --symbol="$ev" 2>/dev/null \
                | jq --arg ev "$ev" '[.[] | {from: ., to: $ev, kind: (if (.kind == "Publish") then "publish" else "subscribe" end)}]'
            done | jq -s 'add // []')
  else
    EDGES="[]"
  fi

  jq --argjson evs "$EVENTS" --argjson eds "$EDGES" \
     --arg sid "$SESSION_ID" --arg ts "$(date -Iseconds)" \
     '. + {session_id: $sid, generated_at: $ts, events: $evs, edges: $eds}' \
     "$TARGET" > "$TARGET.tmp.$$" && mv "$TARGET.tmp.$$" "$TARGET"
fi
```

### Step 2.8 — Build `rbac-matrix.json` (Discovery #6)

```bash
TARGET="$SESSION_DIR/phase2-discovery/rbac-matrix.json"
TPL=".claude/skills/workflow/wf-cmi/templates/rbac-matrix.json"
strip_template_metadata "$TPL" "$TARGET"

# Permissions (90+ trong EUREKA: {module}.{resource}.{action})
if [ "$SERENA_AVAILABLE" = "true" ]; then
  PERMISSIONS=$(serena find_symbol --pattern='Permissions.*' --include-body=true 2>/dev/null \
               | jq '[.[] | .body | scan("\"([a-z]+\\.[a-z]+\\.[a-z]+)\"")[]]' \
               | jq 'add // [] | unique')
else
  PERMISSIONS=$(grep -rhoE '"[a-z]+\.[a-z]+\.[a-z]+"' apps/backend --include='*.cs' 2>/dev/null \
               | sort -u | jq -R . | jq -s 'unique')
fi

# Roles (UserSeeder.cs hoặc roles config)
ROLES=$(grep -rhE 'AddRoleAsync\(.*"(\w+)"' apps/backend --include='*.cs' 2>/dev/null \
       | sed -E 's/.*"([A-Z_]+)".*/\1/' | sort -u | jq -R . | jq -s 'unique')

# Endpoint × Permission mapping
if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
  ENDPOINT_PERMS=$(gitnexus query --concept="endpoint authorization" 2>/dev/null \
                  | jq '[.[] | {endpoint, required_permissions, identity_check}]')
else
  ENDPOINT_PERMS="[]"
fi

jq --argjson perms "$PERMISSIONS" --argjson roles "$ROLES" --argjson eps "$ENDPOINT_PERMS" \
   --arg sid "$SESSION_ID" --arg ts "$(date -Iseconds)" \
   '. + {session_id: $sid, generated_at: $ts, permissions: $perms, roles: $roles, endpoint_permissions: $eps}' \
   "$TARGET" > "$TARGET.tmp.$$" && mv "$TARGET.tmp.$$" "$TARGET"
```

### Step 2.8b — Build `fe-component-graph.json` (Discovery Plugin #7, v2.0 vertical slice)

> **Vertical slice proof-of-pattern.** Skip gracefully nếu `apps/erp-web/components/` không tồn tại (E137 WARN, không block phase).
> Lane CD11 (FE Component Contracts) consume graph này qua `graph_dependency` trong `_contract.json.lanes_defined[]`.

```bash
TARGET="$SESSION_DIR/phase2-discovery/fe-component-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/fe-component-graph.json"
BUILDER=".claude/scripts/wf-cmi/build-fe-component-graph.sh"
SCOPE_ROOT="apps/erp-web/components"

# Skip detection — Plugin graph KHÔNG block phase nếu skip
if [ ! -d "$SCOPE_ROOT" ]; then
  log_warn "E137" "Plugin graph skip: $SCOPE_ROOT not found (project lacks erp-web frontend)"
  echo '{"$schema":"fe-component-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"erp-web not present"}}' \
    > "$TARGET"
else
  # Delegate to builder script (1 file = 1 writer, CORE-037)
  export SESSION_ID SOURCE_METHOD="${SOURCE_METHOD:-grep_fallback}" CI_FRESHNESS
  if bash "$BUILDER" "$SESSION_DIR" "$SCOPE_ROOT" 2> "$SESSION_DIR/phase2-discovery/.fe-component-graph-stderr.log"; then
    NODE_COUNT=$(jq '.nodes | length' "$TARGET")
    EDGE_COUNT=$(jq '.edges | length' "$TARGET")
    log_phase_event "phase2" "INFO" "{\"step\":\"fe-component-graph\",\"nodes\":$NODE_COUNT,\"edges\":$EDGE_COUNT}"
  else
    log_warn "E138" "fe-component-graph builder failed — see .fe-component-graph-stderr.log (lane CD11 will fallback Grep with WARN E130)"
    echo '{"$schema":"fe-component-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"builder_failed"}}' \
      > "$TARGET"
  fi
fi

# Plugin graph is NEVER required-pass — POST-GATE T3 SKIPS it (chỉ check nếu non-skipped → mới validate ≥1 node)
```

**Upgrade path v2.1:** Replace Grep-based props parse với `ts-morph` (TypeScript Compiler API):
- Cài `npm install -g ts-morph`
- Script `build-fe-component-graph.ts` extract full prop types, generics, JSDoc.
- Bump `metadata.parser_version` từ `"1.0"` → `"2.0"`.
- CI fallback Grep vẫn giữ nguyên cho graceful degradation.

### Step 2.8c — Build `fe-api-client-graph.json` (Discovery Plugin #8, v2.0 Stage 2.1)

> **Lane consumers:** CD13 (FE↔BE Contract Sync), CD38 (UI Implementation Coverage). Skip gracefully nếu `apps/erp-web/` không tồn tại (E137 WARN, không block phase).

```bash
TARGET="$SESSION_DIR/phase2-discovery/fe-api-client-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/fe-api-client-graph.json"
BUILDER=".claude/scripts/wf-cmi/build-fe-api-client-graph.sh"
SCOPE_ROOT="apps/erp-web"

if [ ! -d "$SCOPE_ROOT" ]; then
  log_warn "E137" "Plugin graph skip: $SCOPE_ROOT not found (lane CD13/CD38 will fallback Grep with E130)"
  echo '{"$schema":"fe-api-client-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"erp-web not present"}}' \
    > "$TARGET"
else
  export SESSION_ID SOURCE_METHOD="${SOURCE_METHOD:-grep_fallback}" CI_FRESHNESS
  if bash "$BUILDER" "$SESSION_DIR" "$SCOPE_ROOT" 2> "$SESSION_DIR/phase2-discovery/.fe-api-client-graph-stderr.log"; then
    NODE_COUNT=$(jq '.nodes | length' "$TARGET")
    EDGE_COUNT=$(jq '.edges | length' "$TARGET")
    RQ_N=$(jq '.metadata.kinds_distribution.react_query_hook' "$TARGET")
    REFIT_N=$(jq '.metadata.kinds_distribution.refit_interface' "$TARGET")
    log_phase_event "phase2" "INFO" "{\"step\":\"fe-api-client-graph\",\"nodes\":$NODE_COUNT,\"edges\":$EDGE_COUNT,\"rq\":$RQ_N,\"refit\":$REFIT_N}"
  else
    log_warn "E138" "fe-api-client-graph builder failed — see stderr.log (lane CD13/CD38 will fallback Grep with WARN E130)"
    echo '{"$schema":"fe-api-client-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"builder_failed"}}' \
      > "$TARGET"
  fi
fi
```

**Parser v1.0 limitations:** mutationFn HTTP method default POST (chưa parse body), endpoint_path heuristic 10 lines below hook call, Refit attribute method/path từ first attr line. v2.1 upgrade qua ts-morph cho full Refit signature + RQ generic type extraction.

### Step 2.8d — Build `fe-permission-graph.json` (Discovery Plugin #9, v2.0 Stage 2.1)

> **Lane consumers:** CD15 (UI Permission Mirror), CD38 (UI Implementation Coverage). Cross-validate với `rbac-permission-catalog.json` SSOT — phát hiện UI gọi permission KHÔNG có trong backend.

```bash
TARGET="$SESSION_DIR/phase2-discovery/fe-permission-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/fe-permission-graph.json"
BUILDER=".claude/scripts/wf-cmi/build-fe-permission-graph.sh"
SCOPE_ROOT="apps/erp-web"

if [ ! -d "$SCOPE_ROOT" ]; then
  log_warn "E137" "Plugin graph skip: $SCOPE_ROOT not found (lane CD15/CD38 will fallback Grep with E131)"
  echo '{"$schema":"fe-permission-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"erp-web not present"}}' \
    > "$TARGET"
else
  export SESSION_ID SOURCE_METHOD="${SOURCE_METHOD:-grep_fallback}" CI_FRESHNESS
  if bash "$BUILDER" "$SESSION_DIR" "$SCOPE_ROOT" 2> "$SESSION_DIR/phase2-discovery/.fe-permission-graph-stderr.log"; then
    NODE_COUNT=$(jq '.nodes | length' "$TARGET")
    PERM_COUNT=$(jq '.metadata.unique_permissions_used' "$TARGET")
    log_phase_event "phase2" "INFO" "{\"step\":\"fe-permission-graph\",\"nodes\":$NODE_COUNT,\"unique_perms\":$PERM_COUNT}"
  else
    log_warn "E138" "fe-permission-graph builder failed — see stderr.log (lane CD15/CD38 will fallback Grep with WARN E131)"
    echo '{"$schema":"fe-permission-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"builder_failed"}}' \
      > "$TARGET"
  fi
fi
```

**Parser v1.0 limitations:** Dynamic permission expressions (`usePermission(varName)`) marked `dynamic_or_variable`. v2.1 upgrade qua ts-morph để resolve variable values qua scope analysis.

### Step 2.8e — Build `fe-route-graph.json` (Discovery Plugin #10, v2.0 Stage 2.1)

> **Lane consumers:** CD25 (UX Flow Continuity), CD38 (UI Implementation Coverage). Detect dynamic routes + protected route groups + middleware coverage.

```bash
TARGET="$SESSION_DIR/phase2-discovery/fe-route-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/fe-route-graph.json"
BUILDER=".claude/scripts/wf-cmi/build-fe-route-graph.sh"
SCOPE_ROOT="apps/erp-web/app"

if [ ! -d "$SCOPE_ROOT" ]; then
  log_warn "E137" "Plugin graph skip: $SCOPE_ROOT not found (lane CD25/CD38 will fallback Grep with E132)"
  echo '{"$schema":"fe-route-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"app router not present"}}' \
    > "$TARGET"
else
  export SESSION_ID SOURCE_METHOD="${SOURCE_METHOD:-glob_filesystem}" CI_FRESHNESS
  if bash "$BUILDER" "$SESSION_DIR" "$SCOPE_ROOT" 2> "$SESSION_DIR/phase2-discovery/.fe-route-graph-stderr.log"; then
    NODE_COUNT=$(jq '.nodes | length' "$TARGET")
    DYN_N=$(jq '.metadata.dynamic_route_count' "$TARGET")
    PROT_N=$(jq '.metadata.protected_route_count' "$TARGET")
    log_phase_event "phase2" "INFO" "{\"step\":\"fe-route-graph\",\"nodes\":$NODE_COUNT,\"dynamic\":$DYN_N,\"protected\":$PROT_N}"
  else
    log_warn "E138" "fe-route-graph builder failed — see stderr.log (lane CD25/CD38 will fallback Grep with WARN E132)"
    echo '{"$schema":"fe-route-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"builder_failed"}}' \
      > "$TARGET"
  fi
fi
```

**Parser v1.0 limitations:** Static filesystem-based (KHÔNG cần AST). KHÔNG parse `generateMetadata()` exports cho SEO/title coverage (v2.1). Middleware coverage chỉ detect file tồn tại — KHÔNG parse matcher config (v2.1).

> **Git Bash for Windows note:** 3 FE plugin builders dùng sentinel prefix (`ROUTEv1:::`, `EPv1:::`) hoặc JSON-encoding cho route_path / endpoint_path để bypass MSYS POSIX path conversion (e.g. `/dashboard` không bị convert thành `C:/Program Files/Git/dashboard`).

### Step 2.8f — Build `be-domain-graph.json` (Discovery Plugin #11, v2.0 Stage 2.2 vertical slice)

> **Lane consumers:** CD16 (Domain Logic Integrity). Cross-validate với `mdm-canonical-entities.json` SSOT (Stage 3) — phát hiện entity backend KHÔNG có trong MDM canonical list.
> **Builder dùng `--slurpfile`** thay vì `--argjson` cho nodes/edges để bypass argv size limit (EUREKA ~900+ DDD types ≈ 1.3MB JSON).

```bash
TARGET="$SESSION_DIR/phase2-discovery/be-domain-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/be-domain-graph.json"
BUILDER=".claude/scripts/wf-cmi/build-be-domain-graph.sh"
SCOPE_ROOT="apps/backend"

if [ ! -d "$SCOPE_ROOT" ]; then
  log_warn "E137" "Plugin graph skip: $SCOPE_ROOT not found (lane CD16 will fallback Serena/Grep with E133)"
  echo '{"$schema":"be-domain-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"backend not present"}}' \
    > "$TARGET"
else
  export SESSION_ID SOURCE_METHOD="${SOURCE_METHOD:-grep_fallback}" CI_FRESHNESS
  if bash "$BUILDER" "$SESSION_DIR" "$SCOPE_ROOT" 2> "$SESSION_DIR/phase2-discovery/.be-domain-graph-stderr.log"; then
    NODE_COUNT=$(jq '.nodes | length' "$TARGET")
    EDGE_COUNT=$(jq '.edges | length' "$TARGET")
    AGG_N=$(jq '.metadata.kinds_distribution.aggregate_root' "$TARGET")
    VO_N=$(jq '.metadata.kinds_distribution.value_object' "$TARGET")
    DEH_N=$(jq '.metadata.kinds_distribution.domain_event_handler' "$TARGET")
    log_phase_event "phase2" "INFO" "{\"step\":\"be-domain-graph\",\"nodes\":$NODE_COUNT,\"edges\":$EDGE_COUNT,\"aggregates\":$AGG_N,\"value_objects\":$VO_N,\"event_handlers\":$DEH_N}"
  else
    log_warn "E138" "be-domain-graph builder failed — see .be-domain-graph-stderr.log (lane CD16 will fallback Serena/Grep with WARN E133)"
    echo '{"$schema":"be-domain-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"builder_failed"}}' \
      > "$TARGET"
  fi
fi
```

**Parser v1.0 detection rules (C# .NET 10):**
- `aggregate_root` — `class X : AggregateRoot<TId>` hoặc `: IAggregateRoot`
- `entity` — `class X : Entity<TId>`
- `value_object` — `class X : ValueObject`
- `domain_event` — `class X : IDomainEvent` hoặc `: DomainEvent` (LOẠI TRỪ Handler)
- `domain_event_handler` — `class X : IDomainEventHandler<TEvent>` (extract event name từ generic → `handles_event` edge)
- `specification` — `class X : Specification<T>` hoặc `: ISpecification<T>`
- `repository_interface` — `interface IXxxRepository` (heuristic naming)

**Edges:**
- `inherits_from` — Per base type (deduped sau split bằng Python helper cho comma trong generic angle brackets)
- `handles_event` — DomainEventHandler<EventName> → `{MODULE}.{EventName}`
- `raises_event` — Aggregate's `RaiseDomainEvent(new XxxEvent(...))` hoặc `AddDomainEvent(...)` — attribute to LAST aggregate_root node trong file

**Parser v1.0 limitations:**
- Multi-base parsing dùng Python helper (`python3 -c`) để respect generic comma. Nếu môi trường thiếu Python3 → fallback nguyên chuỗi `BASE_TYPES_RAW` (1 base type, không split).
- `properties_count` heuristic Grep — đếm `public Type Prop { get; ... }` từ line khai báo class đến `^}` đầu tiên — có thể off cho nested class hoặc class >500 dòng.
- `raises_event` attribute tới LAST aggregate_root node trong file — nếu file có 2+ aggregates raising events sẽ misattribute. v2.1 Roslyn syntax tree fix chính xác.
- KHÔNG resolve generic type arguments (vd `AggregateRoot<Guid>` lưu nguyên — `to` của inherits_from chỉ là `AggregateRoot` sau strip).
- `domain_event_handler` chỉ detect `IDomainEventHandler<EventX>` đơn (KHÔNG handle multiple `, IDomainEventHandler<EventY>` trong cùng inheritance).

### Step 2.8g — Build `be-db-schema-graph.json` (Discovery Plugin #12, v2.0 Stage 2.2 COMPLETE)

> **Lane consumers:** CD17 (Persistence Consistency). Cross-validate với `mdm-canonical-entities.json` SSOT (Stage 3) — phát hiện table backend KHÔNG có trong MDM canonical list, FK on_delete behavior mismatch, unique constraint drift.
> **Strategy:** Primary source = DbContextModelSnapshot.cs (cumulative final schema state). Fallback = scan latest migration .cs (incremental CreateTable/AddForeignKey/CreateIndex).
> **Parser:** Python helper inline cho EF Core fluent API multi-line parsing (HasColumnType/HasMaxLength/IsRequired/HasIndex/HasOne span lines until `;`).

```bash
TARGET="$SESSION_DIR/phase2-discovery/be-db-schema-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/be-db-schema-graph.json"
BUILDER=".claude/scripts/wf-cmi/build-be-db-schema-graph.sh"
SCOPE_ROOT="apps/backend"

if [ ! -d "$SCOPE_ROOT" ]; then
  log_warn "E137" "Plugin graph skip: $SCOPE_ROOT not found (lane CD17 will fallback Grep with E134)"
  echo '{"$schema":"be-db-schema-graph-v1","tables":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"backend not present"}}' \
    > "$TARGET"
else
  export SESSION_ID SOURCE_METHOD="${SOURCE_METHOD:-ef_snapshot}" CI_FRESHNESS
  if bash "$BUILDER" "$SESSION_DIR" "$SCOPE_ROOT" 2> "$SESSION_DIR/phase2-discovery/.be-db-schema-graph-stderr.log"; then
    TBL_COUNT=$(jq '.metadata.table_count' "$TARGET")
    COL_COUNT=$(jq '.metadata.column_count' "$TARGET")
    FK_COUNT=$(jq '.metadata.fk_count' "$TARGET")
    IDX_COUNT=$(jq '.metadata.index_count' "$TARGET")
    log_phase_event "phase2" "INFO" "{\"step\":\"be-db-schema-graph\",\"tables\":$TBL_COUNT,\"columns\":$COL_COUNT,\"fks\":$FK_COUNT,\"indexes\":$IDX_COUNT}"
  else
    log_warn "E138" "be-db-schema-graph builder failed — see .be-db-schema-graph-stderr.log (lane CD17 will fallback Grep with WARN E134)"
    echo '{"$schema":"be-db-schema-graph-v1","tables":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"builder_failed"}}' \
      > "$TARGET"
  fi
fi
```

**Parser v1.0 detection rules (EF Core 6+):**
- `table` — `modelBuilder.Entity("FQN", b => { ... b.ToTable("name"[, "schema"]); })` (snapshot) hoặc `migrationBuilder.CreateTable(name: "X", ...)` (migration)
- `column` — `b.Property<Type>("Name").HasColumnType(...).HasMaxLength(...).IsRequired()` (multi-line fluent API)
- `primary_key` — `b.HasKey("Id")` hoặc `b.HasKey("X", "Y")`
- `index` — `b.HasIndex("Col")[.IsUnique()][.HasFilter("...")]`
- `foreign_key` — `b.HasOne("FQN").WithMany(...).HasForeignKey("Id").OnDelete(DeleteBehavior.X)`

**Parser v1.0 limitations:**
- Single DbContext shared across modules → tables aggregate vào module `Infrastructure` thay vì từng module. v2.1 → parse `[Table]` attribute hoặc OnModelCreating namespace để phân tách module.
- FK extraction từ snapshot dùng `b.HasOne("FQN")` — nếu codebase dùng convention-based FK (shadow properties) sẽ bị miss. Fallback: migration AddForeignKey detection.
- Max file size 16MB (snapshots cho enterprise có thể 3-10MB). File vượt threshold → skip + WARN.
- KHÔNG parse `Owned types` (EF Core complex types) — chỉ detect như properties.

### Step 2.8h — Build `be-cqrs-graph.json` (Discovery Plugin #13, v2.0 Stage 2.2 COMPLETE)

> **Lane consumers:** CD18 (CQRS Pipeline Integrity). Cross-validate với api-graph.json — phát hiện API endpoint không có handler, command/query không có validator (FluentValidation), missing pipeline behaviors (Transaction/Logging/Authorization).
> **Parser:** Python single-pass per file → JSON Lines accumulator, bulk jq aggregate. Avoids O(n²) jq-append pattern khi xử lý 2000+ Application/ files.

```bash
TARGET="$SESSION_DIR/phase2-discovery/be-cqrs-graph.json"
TPL=".claude/skills/workflow/wf-cmi/templates/be-cqrs-graph.json"
BUILDER=".claude/scripts/wf-cmi/build-be-cqrs-graph.sh"
SCOPE_ROOT="apps/backend"

if [ ! -d "$SCOPE_ROOT" ]; then
  log_warn "E137" "Plugin graph skip: $SCOPE_ROOT not found (lane CD18 will fallback Grep with E135)"
  echo '{"$schema":"be-cqrs-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"backend not present"}}' \
    > "$TARGET"
else
  export SESSION_ID SOURCE_METHOD="${SOURCE_METHOD:-grep_fallback}" CI_FRESHNESS
  if bash "$BUILDER" "$SESSION_DIR" "$SCOPE_ROOT" 2> "$SESSION_DIR/phase2-discovery/.be-cqrs-graph-stderr.log"; then
    NODE_COUNT=$(jq '.nodes | length' "$TARGET")
    EDGE_COUNT=$(jq '.edges | length' "$TARGET")
    CMD_N=$(jq '.metadata.kinds_distribution.command' "$TARGET")
    QRY_N=$(jq '.metadata.kinds_distribution.query' "$TARGET")
    HDL_N=$(jq '.metadata.kinds_distribution.request_handler' "$TARGET")
    VAL_N=$(jq '.metadata.kinds_distribution.validator' "$TARGET")
    NOH=$(jq '.metadata.coverage_indicators.requests_without_handler' "$TARGET")
    NOV=$(jq '.metadata.coverage_indicators.requests_without_validator' "$TARGET")
    log_phase_event "phase2" "INFO" "{\"step\":\"be-cqrs-graph\",\"nodes\":$NODE_COUNT,\"edges\":$EDGE_COUNT,\"commands\":$CMD_N,\"queries\":$QRY_N,\"handlers\":$HDL_N,\"validators\":$VAL_N,\"reqs_no_handler\":$NOH,\"reqs_no_validator\":$NOV}"
  else
    log_warn "E138" "be-cqrs-graph builder failed — see .be-cqrs-graph-stderr.log (lane CD18 will fallback Grep with WARN E135)"
    echo '{"$schema":"be-cqrs-graph-v1","nodes":[],"edges":[],"metadata":{"skipped":true,"skip_reason":"builder_failed"}}' \
      > "$TARGET"
  fi
fi
```

**Parser v1.0 detection rules (MediatR + FluentValidation):**
- `command` / `query` — `class/record X : IRequest<TResponse>` (classified theo name suffix `*Command`/`*Query` hoặc prefix `Get*`/`List*`/`Find*`/`Search*`/`Check*`)
- `request_handler` — `class X : IRequestHandler<TReq, TResp>` (request_type + response_type từ generic args)
- `validator` — `class X : AbstractValidator<TReq>` (validates_for = TReq)
- `pipeline_behavior` — `class X<TReq, TResp> : IPipelineBehavior<TReq, TResp>`
- `notification` — `class X : INotification`
- `notification_handler` — `class X : INotificationHandler<TNotif>`

**Coverage indicators (lane CD18 early warning):**
- `requests_without_handler`: số commands/queries KHÔNG match handler.request_type → orphan request
- `requests_without_validator`: số commands/queries KHÔNG match validator.validates_for → missing input validation
- `handlers_without_request`: số handler.request_type KHÔNG match command/query id → handler có thể target cross-module request (lane CD18 cần cross-module link)

**Parser v1.0 limitations:**
- Module attribution heuristic — handler/validator module = file_path module, NHƯNG request có thể ở module khác. v2.1 → Roslyn full namespace resolution để link đúng cross-module.
- `command` vs `query` heuristic dùng name suffix/prefix — nếu naming KHÔNG follow convention (vd `ProcessOrder` không có Command/Query suffix) → default `command`.
- KHÔNG detect partial class (`partial class XHandler` split across files) — đếm trùng nếu cùng class trong nhiều files.
- KHÔNG resolve generic constraints (`where T : IRequest<X>`) — chỉ extract direct generic args.

> **Performance note:** be-cqrs-graph với EUREKA 17 modules / 2336 .cs files ≈ 5-6 phút (Python single-pass per file). be-db-schema-graph với 2 snapshots ≈ 30 giây. Tổng BE plugin time ≈ 6-7 phút.

---

### Step 2.9 — Cross-validate graphs consistency

> Đảm bảo: module nodes ∈ entity-graph + module-graph + api-graph khớp registry.

```bash
ENTITY_MODULES=$(jq -r '[.nodes[].module] | unique' "$SESSION_DIR/phase2-discovery/entity-graph.json")
MODULE_GRAPH=$(jq -r '[.modules[].id] | unique' "$SESSION_DIR/phase2-discovery/module-graph.json")
API_MODULES=$(jq -r '[.endpoints[].module] | unique' "$SESSION_DIR/phase2-discovery/api-graph.json")

# Check intersection
INCONSISTENT=$(jq -n --argjson e "$ENTITY_MODULES" --argjson m "$MODULE_GRAPH" --argjson a "$API_MODULES" \
   '($e - $m) + ($a - $m) | unique')

if [ "$(echo "$INCONSISTENT" | jq 'length')" -gt 0 ]; then
  log_warn "E029" "Cross-graph inconsistency: $INCONSISTENT"
fi
```

### Step 2.10 — Write Phase2-report.md (CORE-028)

```bash
TPL=".claude/skills/workflow/wf-cmi/templates/Phase2-report.md"
REPORT="$SESSION_DIR/phase2-discovery/Phase2-report.md"

ENTITY_COUNT=$(jq '.nodes | length' "$SESSION_DIR/phase2-discovery/entity-graph.json")
MODULE_COUNT=$(jq '.modules | length' "$SESSION_DIR/phase2-discovery/module-graph.json")
WORKFLOW_COUNT=$(jq '.workflows | length' "$SESSION_DIR/phase2-discovery/workflow-graph.json")
API_COUNT=$(jq '.endpoints | length' "$SESSION_DIR/phase2-discovery/api-graph.json")
EVENT_COUNT=$(jq '.events | length' "$SESSION_DIR/phase2-discovery/event-graph.json")
PERM_COUNT=$(jq '.permissions | length' "$SESSION_DIR/phase2-discovery/rbac-matrix.json")

# v2.0 plugin graphs (default 0 + SKIPPED nếu missing). Helper:
read_plugin_count() {
  jq '.nodes | length' "$1" 2>/dev/null || echo "0"
}
read_plugin_skipped() {
  jq -r '.metadata.skipped // false' "$1" 2>/dev/null || echo "true"
}
status_label() {
  [ "$1" = "true" ] && echo "SKIPPED" || echo "OK"
}

FE_COMPONENT_COUNT=$(read_plugin_count   "$SESSION_DIR/phase2-discovery/fe-component-graph.json")
FE_COMPONENT_STATUS=$(status_label "$(read_plugin_skipped "$SESSION_DIR/phase2-discovery/fe-component-graph.json")")
FE_API_CLIENT_COUNT=$(read_plugin_count  "$SESSION_DIR/phase2-discovery/fe-api-client-graph.json")
FE_API_CLIENT_STATUS=$(status_label "$(read_plugin_skipped "$SESSION_DIR/phase2-discovery/fe-api-client-graph.json")")
FE_PERMISSION_COUNT=$(read_plugin_count  "$SESSION_DIR/phase2-discovery/fe-permission-graph.json")
FE_PERMISSION_STATUS=$(status_label "$(read_plugin_skipped "$SESSION_DIR/phase2-discovery/fe-permission-graph.json")")
FE_ROUTE_COUNT=$(read_plugin_count       "$SESSION_DIR/phase2-discovery/fe-route-graph.json")
FE_ROUTE_STATUS=$(status_label "$(read_plugin_skipped "$SESSION_DIR/phase2-discovery/fe-route-graph.json")")

# v2.0 Stage 2.2 BE plugin (be-domain)
BE_DOMAIN_COUNT=$(read_plugin_count "$SESSION_DIR/phase2-discovery/be-domain-graph.json")
BE_DOMAIN_STATUS=$(status_label "$(read_plugin_skipped "$SESSION_DIR/phase2-discovery/be-domain-graph.json")")
BE_DOMAIN_AGG=$(jq '.metadata.kinds_distribution.aggregate_root // 0' "$SESSION_DIR/phase2-discovery/be-domain-graph.json" 2>/dev/null || echo "0")
BE_DOMAIN_ENT=$(jq '.metadata.kinds_distribution.entity // 0' "$SESSION_DIR/phase2-discovery/be-domain-graph.json" 2>/dev/null || echo "0")
BE_DOMAIN_VO=$(jq '.metadata.kinds_distribution.value_object // 0' "$SESSION_DIR/phase2-discovery/be-domain-graph.json" 2>/dev/null || echo "0")
BE_DOMAIN_EVT=$(jq '.metadata.kinds_distribution.domain_event // 0' "$SESSION_DIR/phase2-discovery/be-domain-graph.json" 2>/dev/null || echo "0")
BE_DOMAIN_DEH=$(jq '.metadata.kinds_distribution.domain_event_handler // 0' "$SESSION_DIR/phase2-discovery/be-domain-graph.json" 2>/dev/null || echo "0")

# v2.0 Stage 2.2 BE plugin (be-db-schema) — uses .tables length thay vì .nodes
read_plugin_table_count() {
  jq '.tables | length' "$1" 2>/dev/null || echo "0"
}
BE_DB_SCHEMA_COUNT=$(read_plugin_table_count "$SESSION_DIR/phase2-discovery/be-db-schema-graph.json")
BE_DB_SCHEMA_STATUS=$(status_label "$(read_plugin_skipped "$SESSION_DIR/phase2-discovery/be-db-schema-graph.json")")
BE_DB_SCHEMA_COL=$(jq '.metadata.column_count // 0' "$SESSION_DIR/phase2-discovery/be-db-schema-graph.json" 2>/dev/null || echo "0")
BE_DB_SCHEMA_FK=$(jq '.metadata.fk_count // 0' "$SESSION_DIR/phase2-discovery/be-db-schema-graph.json" 2>/dev/null || echo "0")
BE_DB_SCHEMA_IDX=$(jq '.metadata.index_count // 0' "$SESSION_DIR/phase2-discovery/be-db-schema-graph.json" 2>/dev/null || echo "0")

# v2.0 Stage 2.2 BE plugin (be-cqrs)
BE_CQRS_COUNT=$(read_plugin_count "$SESSION_DIR/phase2-discovery/be-cqrs-graph.json")
BE_CQRS_STATUS=$(status_label "$(read_plugin_skipped "$SESSION_DIR/phase2-discovery/be-cqrs-graph.json")")
BE_CQRS_CMD=$(jq '.metadata.kinds_distribution.command // 0' "$SESSION_DIR/phase2-discovery/be-cqrs-graph.json" 2>/dev/null || echo "0")
BE_CQRS_QRY=$(jq '.metadata.kinds_distribution.query // 0' "$SESSION_DIR/phase2-discovery/be-cqrs-graph.json" 2>/dev/null || echo "0")
BE_CQRS_HDL=$(jq '.metadata.kinds_distribution.request_handler // 0' "$SESSION_DIR/phase2-discovery/be-cqrs-graph.json" 2>/dev/null || echo "0")
BE_CQRS_VAL=$(jq '.metadata.kinds_distribution.validator // 0' "$SESSION_DIR/phase2-discovery/be-cqrs-graph.json" 2>/dev/null || echo "0")
BE_CQRS_NOH=$(jq '.metadata.coverage_indicators.requests_without_handler // 0' "$SESSION_DIR/phase2-discovery/be-cqrs-graph.json" 2>/dev/null || echo "0")
BE_CQRS_NOV=$(jq '.metadata.coverage_indicators.requests_without_validator // 0' "$SESSION_DIR/phase2-discovery/be-cqrs-graph.json" 2>/dev/null || echo "0")

sed -e "s|\[ENTITY_COUNT\]|$ENTITY_COUNT|g" \
    -e "s|\[MODULE_COUNT\]|$MODULE_COUNT|g" \
    -e "s|\[WORKFLOW_COUNT\]|$WORKFLOW_COUNT|g" \
    -e "s|\[API_COUNT\]|$API_COUNT|g" \
    -e "s|\[EVENT_COUNT\]|$EVENT_COUNT|g" \
    -e "s|\[PERM_COUNT\]|$PERM_COUNT|g" \
    -e "s|\[FE_COMPONENT_COUNT\]|$FE_COMPONENT_COUNT|g" \
    -e "s|\[FE_COMPONENT_STATUS\]|$FE_COMPONENT_STATUS|g" \
    -e "s|\[FE_API_CLIENT_COUNT\]|$FE_API_CLIENT_COUNT|g" \
    -e "s|\[FE_API_CLIENT_STATUS\]|$FE_API_CLIENT_STATUS|g" \
    -e "s|\[FE_PERMISSION_COUNT\]|$FE_PERMISSION_COUNT|g" \
    -e "s|\[FE_PERMISSION_STATUS\]|$FE_PERMISSION_STATUS|g" \
    -e "s|\[FE_ROUTE_COUNT\]|$FE_ROUTE_COUNT|g" \
    -e "s|\[FE_ROUTE_STATUS\]|$FE_ROUTE_STATUS|g" \
    -e "s|\[BE_DOMAIN_COUNT\]|$BE_DOMAIN_COUNT|g" \
    -e "s|\[BE_DOMAIN_STATUS\]|$BE_DOMAIN_STATUS|g" \
    -e "s|\[BE_DOMAIN_AGG\]|$BE_DOMAIN_AGG|g" \
    -e "s|\[BE_DOMAIN_ENT\]|$BE_DOMAIN_ENT|g" \
    -e "s|\[BE_DOMAIN_VO\]|$BE_DOMAIN_VO|g" \
    -e "s|\[BE_DOMAIN_EVT\]|$BE_DOMAIN_EVT|g" \
    -e "s|\[BE_DOMAIN_DEH\]|$BE_DOMAIN_DEH|g" \
    -e "s|\[BE_DB_SCHEMA_COUNT\]|$BE_DB_SCHEMA_COUNT|g" \
    -e "s|\[BE_DB_SCHEMA_STATUS\]|$BE_DB_SCHEMA_STATUS|g" \
    -e "s|\[BE_DB_SCHEMA_COL\]|$BE_DB_SCHEMA_COL|g" \
    -e "s|\[BE_DB_SCHEMA_FK\]|$BE_DB_SCHEMA_FK|g" \
    -e "s|\[BE_DB_SCHEMA_IDX\]|$BE_DB_SCHEMA_IDX|g" \
    -e "s|\[BE_CQRS_COUNT\]|$BE_CQRS_COUNT|g" \
    -e "s|\[BE_CQRS_STATUS\]|$BE_CQRS_STATUS|g" \
    -e "s|\[BE_CQRS_CMD\]|$BE_CQRS_CMD|g" \
    -e "s|\[BE_CQRS_QRY\]|$BE_CQRS_QRY|g" \
    -e "s|\[BE_CQRS_HDL\]|$BE_CQRS_HDL|g" \
    -e "s|\[BE_CQRS_VAL\]|$BE_CQRS_VAL|g" \
    -e "s|\[BE_CQRS_NOH\]|$BE_CQRS_NOH|g" \
    -e "s|\[BE_CQRS_NOV\]|$BE_CQRS_NOV|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    -e "s|\[STATUS\]|PASS|g" \
    "$TPL" > "$REPORT"

[ "$(wc -l < "$REPORT")" -le 22 ] || log_warn "E087" "Phase2-report.md >22 dòng (v2 relaxed cho 7 plugins)"
```

---

## §D POST-GATE (T1→T4 + Auto-Fix)

| Tier | Check | Auto-fix retry (max 3) |
|------|-------|------------------------|
| T1 | 6 core graph files + 4 FE plugin graph files + 3 BE plugin graph files (be-domain + be-db-schema + be-cqrs) exist (plugin có thể là skipped placeholder) | Re-run individual graph build (Step 2.3-2.8h) |
| T2 | Mỗi graph có schema valid (`$schema`, `nodes[]` hoặc `modules[]/workflows[]/endpoints[]/events[]/permissions[]/tables[]`). Plugin graph với `metadata.skipped=true` PASS T2 dù arrays empty. | Re-build từ template |
| T3 | Mỗi **core** graph có ≥1 node (entity ≥1, module ≥1, api ≥1, rbac perms ≥1; workflow/event có thể empty với WARN). 4 FE plugin graphs + 3 BE plugin graphs ≥1 node CHỈ KHI `metadata.skipped=false`. fe-route-graph có thể có nodes=0 nhưng dynamic_route_count=0 (project mới chưa có route). be-domain/be-cqrs có thể nodes=0 nếu project không follow DDD/MediatR patterns. be-db-schema check `tables` array thay vì `nodes`. | Re-scan với CI fallback Grep |
| T4 | Cross-graph consistency: module-graph nodes appear trong entity-graph (≥80% overlap). Plugin graphs KHÔNG include trong cross-validate v2.0. | Re-aggregate |

**POST-GATE pseudocode:**

```bash
post_gate_phase2() {
  local core_files=("entity-graph.json" "module-graph.json" "workflow-graph.json"
                    "api-graph.json" "event-graph.json" "rbac-matrix.json")
  # v2.0 Stage 2.1 FE plugin graphs + Stage 2.2 BE plugin graphs (all 3: be-domain + be-db-schema + be-cqrs)
  # All plugins optional — POST-GATE T3 SKIPS nếu metadata.skipped=true
  local plugin_files=("fe-component-graph.json" "fe-api-client-graph.json"
                      "fe-permission-graph.json" "fe-route-graph.json"
                      "be-domain-graph.json" "be-db-schema-graph.json"
                      "be-cqrs-graph.json")
  local all_files=("${core_files[@]}" "${plugin_files[@]}")
  local retry=0

  while [ "$retry" -lt 3 ]; do
    local all_pass=true

    # T1: existence (core + plugin both required to exist; plugin có thể là skipped placeholder)
    for f in "${all_files[@]}"; do
      [ -f "$SESSION_DIR/phase2-discovery/$f" ] || { all_pass=false; break; }
    done
    [ "$all_pass" = "false" ] && { rebuild_missing_graphs; retry=$((retry+1)); continue; }

    # T2: schema valid (loose check — has $schema field). Plugin với skipped=true vẫn PASS T2.
    for f in "${all_files[@]}"; do
      jq -e '."$schema"' "$SESSION_DIR/phase2-discovery/$f" >/dev/null \
        || { all_pass=false; break; }
    done
    [ "$all_pass" = "false" ] && { rebuild_from_templates; retry=$((retry+1)); continue; }

    # T3: required core graphs non-empty
    local entity_n=$(jq '.nodes | length' "$SESSION_DIR/phase2-discovery/entity-graph.json")
    local module_n=$(jq '.modules | length' "$SESSION_DIR/phase2-discovery/module-graph.json")
    local api_n=$(jq '.endpoints | length' "$SESSION_DIR/phase2-discovery/api-graph.json")
    if [ "$entity_n" -lt 1 ] || [ "$module_n" -lt 1 ] || [ "$api_n" -lt 1 ]; then
      log_warn "E031" "Core graph empty — entity=$entity_n, module=$module_n, api=$api_n"
      retry=$((retry+1)); continue
    fi

    # T3b (v2.0): plugin graphs validate CHỈ KHI không skip
    # be-db-schema-graph dùng .tables thay vì .nodes — handle riêng
    for f in "${plugin_files[@]}"; do
      local skipped=$(jq -r '.metadata.skipped // false' "$SESSION_DIR/phase2-discovery/$f")
      if [ "$skipped" != "true" ]; then
        if [ "$f" = "be-db-schema-graph.json" ]; then
          local item_n=$(jq '.tables | length' "$SESSION_DIR/phase2-discovery/$f")
        else
          local item_n=$(jq '.nodes | length' "$SESSION_DIR/phase2-discovery/$f")
        fi
        if [ "$item_n" -lt 1 ]; then
          log_warn "E139" "Plugin graph $f non-skipped but empty — fallback expected"
          # KHÔNG retry — plugin graph fail không block phase, downstream lane sẽ Grep fallback
        fi
      fi
    done

    # T4: cross-graph consistency (CORE graphs only — plugin v2 KHÔNG include)
    cross_validate_graphs || { retry=$((retry+1)); continue; }

    return 0
  done
  die "E001" "Phase 2 POST-GATE fail after 3 retries"
}
```

**On POST-GATE PASS:**
1. Append `session-log.json` event `COMPLETE` Phase 2
2. Update `integrity-status.json`:
   - `.phases_completed += [2]`
   - `.current_phase = 3`
   - `.next_action = "phase3-invariant-artifact"`
3. Update TodoWrite: Phase 2 = completed, Phase 3 = in_progress
4. Reset `$RETRY_COUNT[phase2] = 0`

---

## §E Phase Report Template (CORE-028)

Output: `$SESSION_DIR/phase2-discovery/Phase2-report.md` (từ `templates/Phase2-report.md`).

**Sample rendered (tiếng Việt, ≤15 dòng):**

```markdown
## Phase 2: Quét bản đồ phụ thuộc — PASS
Thời gian: 2026-05-15T14:34:20+07:00

**Đã làm:**
- Quét code và dựng 6 bản đồ kết nối các module
- Sử dụng GitNexus + Serena để phân tích chính xác

**Kết quả:**
- Entity (thực thể nghiệp vụ): 142
- Module (gói chức năng): 17
- Workflow (luồng nghiệp vụ): 89
- API endpoint: 312 (erp-web/mobile-customer/mobile-staff)
- Event (sự kiện nội bộ): 47
- Quyền (permission): 94

**Tiếp theo:**
- Phase 3 — Suy luận quy tắc nghiệp vụ liên module (2-5 phút)
```

---

## §F Error Code Quick Reference (Phase 2 namespace E020-E029, v2.0 plugin E137-E139)

| Code | Severity | Description | Auto-fix |
|------|---------|-------------|----------|
| E020 | high | Phase 1 state missing | Re-run Phase 1 |
| E021 | high | State inconsistency | Reset state |
| E022 | high | Code unreachable | ESCALATE permissions |
| E023 | high | Module-code drift | ESCALATE `/wf-legacy-scan` |
| E024 | medium | Entity graph build fail (parser error) | Retry x2, fallback Grep |
| E025 | medium | Workflow graph build fail (no CQRS) | Skip workflow graph, WARN |
| E026 | medium | API graph build fail (endpoint pattern) | Try alternative parsers |
| E027 | medium | Event graph build fail (no broker) | Skip event graph, WARN |
| E028 | medium | RBAC matrix build fail | Try alternative auth patterns |
| E029 | low | Graph empty (≥1 graph có 0 nodes) | WARN, mark dim N/A |
| **E137** v2.0 | low | Plugin graph skip: prerequisite path không tồn tại (vd `apps/erp-web/components/`, `apps/erp-web/app/`, `apps/backend/`) | WARN, write empty skipped graph, KHÔNG block phase |
| **E138** v2.0 | medium | Plugin graph builder script failed (parser exception, >20% file fail) | WARN, write empty skipped graph, downstream lane fallback Grep với E130-E135 |
| **E139** v2.0 | low | Plugin graph non-skipped nhưng nodes=[] (fallback Grep returned no matches) | WARN, downstream lane sẽ Grep fallback |

**Lane-side error codes (E130-E135) khi plugin graph skip:**

| Code | Lane affected | Plugin graph dep | Fallback |
|------|---------------|------------------|----------|
| E130 | CD11, CD13, CD38 | fe-component-graph, fe-api-client-graph | Grep components/hooks trực tiếp |
| E131 | CD15, CD38 | fe-permission-graph | Grep RBAC patterns trực tiếp |
| E132 | CD25, CD38 | fe-route-graph | Glob app/ filesystem trực tiếp |
| **E133 v2.2** | CD16 | be-domain-graph (Stage 2.2 — IMPLEMENTED) | Serena `find_symbol` DDD patterns (graceful) |
| **E134 v2.2** | CD17 | be-db-schema-graph (Stage 2.2 — IMPLEMENTED) | Grep EF Migrations / DbContextModelSnapshot (graceful) |
| **E135 v2.2** | CD18 | be-cqrs-graph (Stage 2.2 — IMPLEMENTED) | Grep MediatR IRequest/IRequestHandler/AbstractValidator patterns (graceful) |

---

## §G Cross-References

| Reference | Section |
|-----------|---------|
| `_shared.md` | §3 Atomic Write, §12 CI Detection |
| `docs/04-skill-design/wf-cmi/03-phase-routing.md` | §1 Phase 2 routing |
| `docs/04-skill-design/wf-cmi/04-file-contract.md` | §1.2 PRE-GATE, §2.2 POST-GATE |
| `templates/entity-graph.json`, `module-graph.json`, `workflow-graph.json`, `api-graph.json`, `event-graph.json`, `rbac-matrix.json` | 6 core graph templates |
| `templates/fe-component-graph.json`, `fe-api-client-graph.json`, `fe-permission-graph.json`, `fe-route-graph.json` | 4 FE plugin templates (v2.0 Stage 2.1) |
| `templates/be-domain-graph.json`, `be-db-schema-graph.json`, `be-cqrs-graph.json` | 3 BE plugin templates (v2.0 Stage 2.2 COMPLETE) |
| `_contract.json §outputs.working[]` | 6 core + 7 plugin graph paths + schemas |
| `.claude/scripts/wf-cmi/build-{fe-component,fe-api-client,fe-permission,fe-route,be-domain,be-db-schema,be-cqrs}-graph.sh` | 7 plugin builder scripts |

---

## §H Next

Phase 2 PASS → Read `procedures/phase3-invariant-artifact.md` để 3-pass LLM infer business invariants từ 6 graphs.
