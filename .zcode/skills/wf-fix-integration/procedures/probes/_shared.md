# Shared Probe Conventions — QD10 Cross-Module Integration

Loaded by all 9 probe spec files trong cung directory. Dinh nghia variables, signal emit pattern, CI-ROUTE reference, severity canonical table.

---

## Common Variables

```bash
LANE_NAME="wf-fix-integration"
DIMENSION="QD10"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD10-integration"
RAW_DIR="$LANE_DIR/raw"
SIGNALS_FILE="$LANE_DIR/signals.json"
REGISTRY_FILE=".mc-data/docs/_meta/req-registry.json"
CROSS_MODULE_MAP="$LANE_DIR/cross-module-map.json"

# QD9 coordination inputs (optional — set if QD9 ran first)
FLOW_UNRELIABLE="${FLOW_UNRELIABLE:-}"       # path to flow-unreliable.json
QD9_AUTH_SESSION="${QD9_AUTH_SESSION:-}"     # path to auth-session.json
QD9_DEV_SERVER_STATE="${QD9_DEV_SERVER_STATE:-}"  # path to dev-server-state.json
```

## Signal Types (QD10)

| signal_type | Severity default | Probe | Mo ta |
|-------------|-----------------|-------|-------|
| `orphan_reference` | CRITICAL | P-QD10-orphan-reference-runtime | Consumer refs non-existent provider row (FK violation) |
| `api_contract_breaking_change` | HIGH | P-QD10-api-contract-drift | Provider field removed/renamed (breaking) |
| `state_machine_illegal_transition` | HIGH | P-QD10-state-machine-correctness | Forbidden transition (spec-declared) co the thuc thi duoc trong code |
| `state_machine_missing_transition` | MEDIUM | P-QD10-state-machine-correctness | Valid transition trong spec nhung khong tim thay handler trong code |
| `business_flow_step_failed` | HIGH | P-QD10-business-flow-runtime | Step execution failed (HTTP non-2xx, assertion fail, wait_for timeout) |
| `business_flow_invariant_violated` | CRITICAL | P-QD10-business-flow-runtime | Global invariant violated after flow completes |
| `event_handler_missing` | HIGH | P-QD10-event-handler-coverage | No handler for declared event |
| `cross_module_ref_drift` | MEDIUM | P-QD10-cross-module-ref-static | Consumer code drifted from provider contract |
| `api_contract_type_mismatch` | MEDIUM | P-QD10-api-contract-drift | Type mismatch non-breaking |
| `cache_staleness_detected` | MEDIUM | P-QD10-cache-staleness-probe | Stale data > 5s on entity update |
| `entity_sync_response_shape_mismatch` | HIGH | P-QD10-multi-platform-entity-sync | HTTP status or root structure (array vs object) differs between ERP and MC platform |
| `entity_sync_field_mismatch` | MEDIUM | P-QD10-multi-platform-entity-sync | Field set or field type differs between ERP and MC platform API responses |
| `event_handler_partial` | MEDIUM | P-QD10-event-handler-coverage | Some event subtypes not handled |
| `deprecated_import` | MEDIUM | P-QD10-cross-module-ref-static | Consumer importing deprecated provider export |
| `optional_field_unused` | LOW | P-QD10-cross-module-ref-static | Consumer missing optional field now used by provider |
| `auth_matrix_missing_guard` | HIGH | P-QD10-auth-matrix-check | Action requires role restriction nhung khong co role guard trong code (OWASP Broken Access Control) |
| `auth_matrix_over_permissive` | MEDIUM | P-QD10-auth-matrix-check | Code cho phep role bi cam tuong minh trong authorization-matrix spec |

## Signal Emit Pattern (Cross-Module Static)

Theo `_shared/lane/signal-emit.md` — atomic JSON merge:

```bash
emit_signal_cross_module() {
  local probe_id="$1"
  local signal_type="$2"   # see signal_types above
  local severity="$3"      # critical | high | medium | low
  local title="$4"
  local description="$5"
  local provider_module="$6"
  local consumer_module="$7"
  local evidence_type="$8"  # schema_diff | import_path | query_result | field_diff | api_response_diff
  local evidence_content="$9"
  local file_path="${10:-null}"
  local line_range="${11:-null}"

  jq -n \
    --arg pid "$probe_id" \
    --arg st "$signal_type" \
    --arg sev "$severity" \
    --arg title "$title" \
    --arg desc "$description" \
    --arg provider "$provider_module" \
    --arg consumer "$consumer_module" \
    --arg ev_type "$evidence_type" \
    --arg ev_content "$evidence_content" \
    --argjson fp "${file_path:-null}" \
    --argjson lr "${line_range:-null}" \
    '{
      "$schema": "signal-v2",
      probe_id: $pid,
      dimension_id: "QD10",
      signal_type: $st,
      severity: $sev,
      title: $title,
      description: $desc,
      location: {
        provider_module: $provider,
        consumer_module: $consumer,
        file_path: $fp,
        line_range: $lr
      },
      evidence: [{
        type: $ev_type,
        content: $ev_content
      }],
      dedup_key: "\($pid):\($st):\($provider):\($consumer)"
    }' | jq --argjson existing "$(cat "$SIGNALS_FILE")" \
    '$existing + [.]' > "$SIGNALS_FILE.tmp" && mv "$SIGNALS_FILE.tmp" "$SIGNALS_FILE"
}
```

## Signal Emit Pattern (Runtime — DB/API)

```bash
emit_signal_runtime_integration() {
  local probe_id="$1"
  local signal_type="$2"
  local severity="$3"
  local title="$4"
  local description="$5"
  local evidence_type="$6"  # query_result | api_response_diff
  local evidence_content="$7"
  local context_json="${8:-{}}"  # additional context (table, endpoint, etc.)

  jq -n \
    --arg pid "$probe_id" \
    --arg st "$signal_type" \
    --arg sev "$severity" \
    --arg title "$title" \
    --arg desc "$description" \
    --arg ev_type "$evidence_type" \
    --arg ev_content "$evidence_content" \
    --argjson ctx "$context_json" \
    '{
      "$schema": "signal-v2",
      probe_id: $pid,
      dimension_id: "QD10",
      signal_type: $st,
      severity: $sev,
      title: $title,
      description: $desc,
      location: $ctx,
      evidence: [{
        type: $ev_type,
        content: $ev_content
      }],
      dedup_key: "\($pid):\($st):\($ctx | tostring | .[0:50])"
    }' | jq --argjson existing "$(cat "$SIGNALS_FILE")" \
    '$existing + [.]' > "$SIGNALS_FILE.tmp" && mv "$SIGNALS_FILE.tmp" "$SIGNALS_FILE"
}
```

## Cross-Module Pair Iteration

```bash
iterate_module_pairs() {
  local registry_file="$1"
  local max_pairs="${2:-10}"
  local pair_filter="${PAIR_FILTER:-}"

  if [ -n "$pair_filter" ]; then
    # Filter specific pair
    jq -r --arg a "${PAIR_FILTER%-*}" --arg b "${PAIR_FILTER#*-}" \
      '.cross_module_dependencies[] |
       select((.consumer_module == $a and .provider_module == $b) or
              (.consumer_module == $b and .provider_module == $a)) |
       [.consumer_module, .provider_module, .entity, .binding_type] | @tsv' \
      "$registry_file"
  else
    # All pairs, limit MAX_PAIRS
    jq -r --argjson max "$max_pairs" \
      '[.cross_module_dependencies[] | [.consumer_module, .provider_module, .entity, .binding_type]] |
       .[:$max][] | @tsv' \
      "$registry_file"
  fi
}
```

## CI-ROUTE Convention

Tham khao `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §3.3 (CI-ROUTE matrix QD10):

| Task | Primary | Fallback |
|------|---------|----------|
| Find consumer references | **Serena** `find_referencing_symbols(provider_entity)` | Grep import paths |
| Blast radius analysis | **GitNexus** `impact(provider_symbol, upstream)` | Manual grep |
| Locate provider DTOs | **Serena** `find_symbol(dto_name)` | Glob OpenAPI files |
| Find event subscribers | **GitNexus** `query("event:event-name")` | Grep `on('event')` |
| Trace state transitions | **GitNexus** `query("state, transition, status")` | Grep switch/if |
| Find state enum | **Serena** `find_symbol(state_enum_name)` | Grep |

## Sampling Policy

Per `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §6.3:

- `P-QD10-cross-module-ref-static`: Pairs > 30 → priority queue (CRITICAL pairs first)
- `P-QD10-orphan-reference-runtime`: Tables > 1000 rows → sample 1000
- `P-QD10-business-flow-runtime`: Always full (no sampling — flows quan trong)

```bash
# Document sampling trong probe output
emit_sampling_note() {
  local probe_id="$1"
  local total="$2"
  local sampled="$3"
  echo "SAMPLING: probe=$probe_id total=$total sampled=$sampled rate=$(echo "scale=2; $sampled * 100 / $total" | bc)%" >&2
}
```

## Dedup Hints

Per signal type, dedup key pattern:
- `cross_module_ref_drift`: `probe_id:signal_type:provider:consumer` (1 per consumer-provider pair per field)
- `api_contract_breaking_change`: `probe_id:signal_type:provider:field_name`
- `event_handler_missing`: `probe_id:signal_type:event_name:consumer`
- `orphan_reference`: `probe_id:signal_type:table:row_id` (không dedup — moi orphan la rieng biet)

## Profile-Resolver (Parallel Class)

| Probe | Class | Profile |
|-------|-------|---------|
| P-QD10-cross-module-ref-static | static | standard+ |
| P-QD10-api-contract-drift | static | standard+ |
| P-QD10-event-handler-coverage | static | standard+ |
| P-QD10-orphan-reference-runtime | runtime | deep+ |
| P-QD10-multi-platform-entity-sync | runtime | deep+ |
| P-QD10-cache-staleness-probe | runtime | exhaustive (opt-in --test-cache-sync) |
| P-QD10-state-machine-correctness | static | exhaustive |
| P-QD10-business-flow-runtime | runtime | exhaustive |
| P-QD10-auth-matrix-check | static | exhaustive |

Static probes (class=static) co the chay PARALLEL max 3. Runtime probes = sequential.
