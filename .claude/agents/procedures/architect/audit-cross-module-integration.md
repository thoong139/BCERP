# Procedure: Audit Cross-Module Integration

> **Owner agent:** `architect`
> **Use case:** Khi `architect` được spawn từ `/wf-fix-bugs` lane QD10
> (Cross-Module Integration) hoặc khi review boundary giữa các module trước go-live.

## Khi nào dùng

- QD10 lane probes: cross-module-ref-static, api-contract-drift, event-handler-coverage,
  state-machine-correctness, business-flow-runtime, multi-platform-entity-sync,
  cache-staleness, orphan-reference-runtime, auth-matrix-check
- Pre-deployment review cho microservices boundary
- Post-incident: integration bug (event lost, state desync, cache stale)

## Đầu vào

- `$SESSION_DIR/scope.json`
- `req-registry.json` — `cross_module_dependencies[]`, `entities[]`
- Source code: `src/`, `apps/`
- API specs: OpenAPI/Swagger files, GraphQL schemas
- Event specs: nếu có message queue (Kafka topic schemas, AMQP exchanges)
- Module dependency graph (qua GitNexus `gitnexus_query` hoặc Serena `find_referencing_symbols`)

## Đầu ra

JSON array signals theo schema CORE-029, với evidence từ multi-module trace.

## Quy trình audit

### Bước 1 — Map module boundaries

Sử dụng GitNexus query / Serena symbols để xác định:
1. **Module list:** mỗi `apps/*/`, `services/*/`, hoặc package theo monorepo convention
2. **Public API surface:** exported symbols, route handlers, message handlers, hooks
3. **Cross-module imports:** symbols trong module A reference module B (Serena `find_referencing_symbols`)

### Bước 2 — Pattern checks

#### API Contract Drift
- Provider service exposes endpoint nhưng consumer không update sau breaking change
  → CRITICAL nếu payment/auth, HIGH nếu other
- OpenAPI spec không match implementation (response shape khác) → HIGH
- Versioning convention không nhất quán (`/v1/`, `/api/v2/` mixed) → MEDIUM

#### Event Handler Coverage
- Producer emit event nhưng KHÔNG có consumer (orphan event) → HIGH
- Consumer expect event mà producer không emit (dangling listener) → HIGH
- Event payload schema không document → MEDIUM
- Idempotency key thiếu cho event consumer (re-delivery risk) → HIGH

#### State Machine Correctness
- Transition không reachable (orphan state) → MEDIUM
- Cycle detected (state A → B → A vô tận) → HIGH
- Terminal state có transition out → HIGH (logic error)
- Multiple transitions cùng condition (non-deterministic) → HIGH

#### Cross-Module Reference Drift
- Module A import symbol từ B nhưng B đã rename/remove → CRITICAL (build break risk)
- Circular import (A → B → A) → HIGH (architecture smell)
- Module reference qua deep relative path (`../../../`) → MEDIUM (refactor candidate)

#### Multi-Platform Entity Sync
- Entity tồn tại ở DB nhưng không có model frontend → MEDIUM
- Entity field renamed ở DB nhưng frontend type chưa update → HIGH
- Mobile + web mismatch field name cho cùng entity → HIGH (sync bug)

#### Cache Staleness
- Write-through cache không invalidate sau update → CRITICAL
- TTL không set → MEDIUM (memory leak risk)
- Multi-region cache không có invalidation broadcast → HIGH

#### Orphan Reference Runtime
- Foreign key reference table đã drop → CRITICAL
- Soft-deleted entity vẫn được reference từ active entity → HIGH
- Background job reference deprecated entity → MEDIUM

#### Auth Matrix Violation
- Endpoint thiếu auth middleware → CRITICAL
- Role-based access không enforce ở service layer (chỉ ở controller) → HIGH
- Tenant isolation rule không enforce trong query (cross-tenant data leak) → CRITICAL

#### Business Flow Runtime
- Multi-step business flow không có saga/orchestration → HIGH (no rollback)
- Step có side effect không idempotent (retry risk) → HIGH
- Compensating transaction thiếu → CRITICAL cho payment

### Bước 3 — Boundary Mode (cross-domain pairs)

Khi `cross_module_dependencies[]` có pair `{moduleA: "finance", moduleB: "logistics"}`:
- Spawn 2 domain experts đồng thời (per `_shared/lane/03-reuse-ci-parallelism.md §7.2`)
- Cross-merge findings: nếu cả hai expert flag cùng pattern → severity bump

### Bước 4 — Severity rules

| Tình huống | Severity |
|---|---|
| Tenant isolation broken (cross-tenant data leak) | CRITICAL |
| Payment compensating transaction missing | CRITICAL |
| Cache invalidation missing on write-through | CRITICAL |
| FK reference dropped table | CRITICAL |
| API breaking change without consumer update | CRITICAL (payment) / HIGH (other) |
| Event orphan (producer no consumer) | HIGH |
| State machine cycle | HIGH |
| Mobile/web entity field mismatch | HIGH |

## CDG flag

QD10 findings trong payment / auth / order:
- `cdg_flags: ["CDG-INTEGRATION-RISK"]` để orchestrator escalate.

## Anti-patterns to ignore

- KHÔNG flag cross-module import nếu là shared/common package (intentional dependency)
- KHÔNG flag event orphan trong dev-only events (test fixtures, debug)
- KHÔNG flag missing saga nếu business flow không multi-step (single API call)

## Output validation (CORE-029)

- Mỗi signal phải có `affected_modules` (≥ 2 modules)
- Evidence phải show snippet từ MỖI module liên quan
- `description` ≥ 50 ký tự, mô tả integration impact
