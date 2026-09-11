# P-QD10-api-contract-drift — Phat hien API Contract Drift giua Provider Spec va Consumer DTOs

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD10-api-contract-drift |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Phat hien drift giua provider API contract (OpenAPI/GraphQL/AsyncAPI spec) va consumer DTOs (TypeScript interfaces, C# classes, Pydantic models). Kiem tra fields, types, required-ness, nullability. Emit signal cho moi drift. |
| **Cache** | allowed (static per spec + DTO file state) |
| **Error codes** | E100 (registry corrupt — QD10 base), E106 (API schema parse fail — openapi/graphql malformed) |
| **Migrates from** | (new in v9) |

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| Schema diff algorithm (2-source field extraction + per-field compare) | `QD6 P-QD6-schema-drift-detect.md` | `THINK:113-143` | Extract fields tu 2 nguon (provider spec vs consumer DTO) → per-field compare (existence, type, required-ness, nullability). Severity mapping pattern tuong tu: field missing=HIGH, type mismatch=MEDIUM. |
| Tech stack detection order + fallback | `QD6 P-QD6-schema-drift-detect.md` | `THINK:113-123` | Prisma/TypeORM/EF Core detection order. W2.3 tuong tu nhung detect: openapi.yaml/swagger.json/\*.graphql/asyncapi.yaml (provider stack) + \*.dto.ts/\*.interface.ts/Pydantic (consumer stack). |
| API spec file glob patterns | `QD7 P-QD7-api-version-compat.md` | `SENSE:B1:43-52` | Doc API specs tu phase3-architecture; glob pattern `api-*.md`, `swagger*`, `openapi*` — reuse tim spec files. |
| Combined grep import path analysis | `QD7 wf-fix-probe-static-deprecated.sh` | `:147-217` | Single combined regex scan cho consumer DTO file discovery — khong O(N) per-DTO greps. |
| iterate_module_pairs() + sampling policy | `procedures/probes/_shared.md` (QD10) | `:139-191` | Pairs > 30 → priority queue CRITICAL first; sampling field trong probe output. Reuse filter `--pair` filter. |
| emit_signal_cross_module() + dedup_key | `procedures/probes/_shared.md` (QD10) | `:42-92` | Signal emit function voi provider/consumer context; dedup_key pattern. |
| CI detect load pattern | `QD9 P-QD9-spa-route-coverage.md` | `PRE-GATE:step 5` | `source <(bash ci-detect.sh ...)` pattern + `SERENA_AVAILABLE/GITNEXUS_AVAILABLE` vars. |

**Diff so voi QD6 schema-drift-detect:**
- QD6: compare ORM model vs migration SQL files (DB layer)
- W2.3: compare API spec (OpenAPI/GraphQL/AsyncAPI) vs consumer DTO code (application layer)
- CI-ROUTE PRIMARY: Serena `find_symbol(ProviderDTO)` thay vi manual parse — locate exact DTO definitions
- Signals mang context `provider_module + consumer_module + endpoint` (khong chi table/column)
- Cross-probe dedup: W2.3 `api_contract_breaking_change` co the overlap voi W2.2 `cross_module_ref_drift` khi cung provider field bi drift

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Locate provider DTO/type definitions | **Serena** `find_symbol({name_path_pattern: "ProviderResponseDto", include_body: true})` | Glob `*.dto.ts`, `*.type.ts` + grep | Extract provider field list tu TypeScript types |
| Locate consumer DTO matching endpoint | **Serena** `find_symbol({name_path_pattern: "ConsumerDto", include_body: true})` | Grep `interface.*Request\|Response` trong consumer path | Find consumer-side request/response types |
| Cross-ref endpoint usage tu consumer | **GitNexus** `query("api endpoint")` | Grep `fetch(`, `axios.get(`, `HttpClient.get(` patterns | Xac dinh consumer goi endpoint nao cua provider |
| Find referencing consumers of provider type | **Serena** `find_referencing_symbols({name_path: "ProviderDto"})` | Grep `import.*ProviderDto` | Detect all consumer files dang dung provider type |

**Khi CI unavailable:**
```bash
if [[ "$SERENA_AVAILABLE" != "true" ]]; then
  echo "WARN: Serena unavailable — fallback to bash helper grep via wf-fix-probe-contract-drift.sh" >&2
fi
if [[ "$GITNEXUS_AVAILABLE" != "true" ]]; then
  echo "WARN: GitNexus unavailable — skip api endpoint cross-ref analysis" >&2
fi
```

---

## PRE-GATE

```
1. IF profile=quick:
     SKIP probe (QD10 quick=skip — probe khong duoc goi)

2. Kiem tra cross_module_dependencies[] ton tai voi binding_type=api:
     COUNT=$(jq '[.cross_module_dependencies // [] | .[] | select(.binding_type == "api")] | length' "$REGISTRY_FILE")
     IF COUNT == 0:
       SKIP probe, ghi note "skipped_no_api_binding_dependencies"
       emit WARN: "QD10 api-contract-drift requires cross_module_dependencies[] with binding_type=api. Add entries via wf-detect-cross-module-deps.sh (W2.6)."
       → exit 0 (khong phai error, chi skip)

3. Load CI availability (REUSE: QD9 P-QD9-spa-route-coverage.md PRE-GATE step 5):
     source <(bash .claude/scripts/ci-detect.sh --project-root "$PROJECT_ROOT" 2>/dev/null) || true
     GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
     SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"

4. Detect PROJECT_ROOT + SOURCE_DIR:
     PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
     SOURCE_DIR="${SOURCE_DIR:-src}"
     IF [ ! -d "$SOURCE_DIR" ]; then SOURCE_DIR="apps"; fi
     IF [ ! -d "$SOURCE_DIR" ]; then SOURCE_DIR="."; LOG "WARN: source_dir_fallback=." >&2; fi

5. Detect spec files (provider):
     # Bash helper se detect — PRE-GATE chi kiem tra co the co spec files khong
     SPEC_COUNT=$(bash .claude/scripts/wf-fix-probe-contract-drift.sh \
       --source-dir "$SOURCE_DIR" --detect-only 2>/dev/null | jq '.spec_files_found' || echo 0)
     IF SPEC_COUNT == 0:
       LOG "INFO: No OpenAPI/GraphQL/AsyncAPI spec files found in $SOURCE_DIR — will attempt consumer DTO-only analysis" >&2
       # Khong SKIP — co the consumer co spec embedded trong code annotations

6. IF --pair set: validate format MODULE_A-MODULE_B
     IF echo "$PAIR_FILTER" | grep -qvE '^[A-Z0-9_-]+-[A-Z0-9_-]+$':
       ERROR "invalid --pair format, expected MODULE_A-MODULE_B (e.g. CRM-QUOTATION)" → exit 1

7. Ensure RAW_DIR + LANE_DIR exist:
     mkdir -p "$RAW_DIR" "$LANE_DIR"
```

---

## SENSE

### S1: Load API-binding Cross-Module Pairs

```bash
# Doc pairs tu registry co binding_type=api (REUSE _shared.md:139-160 iterate_module_pairs)
ALL_PAIRS_COUNT=$(jq '[.cross_module_dependencies // [] | .[] | select(.binding_type == "api")] | length' "$REGISTRY_FILE")

# Sampling: Pairs > 30 → priority queue CRITICAL pairs (REUSE _shared.md:176-191)
if [ "$ALL_PAIRS_COUNT" -gt 30 ]; then
  emit_sampling_note "P-QD10-api-contract-drift" "$ALL_PAIRS_COUNT" 30

  PAIRS_TSV=$(jq -r '
    [.cross_module_dependencies[] |
      select(.binding_type == "api") |
      {
        consumer: .consumer_module,
        provider: .provider_module,
        entity: .entity,
        binding_type: .binding_type,
        priority: (if (.required_fields // [] | length) > 3 then 2
                   elif (.required_fields // [] | length) > 0 then 1
                   else 0 end)
      }
    ] | sort_by(-.priority) | .[:30] |
    .[] | [.consumer, .provider, .entity, .binding_type] | @tsv
  ' "$REGISTRY_FILE")
else
  # Ap dung --pair filter neu co
  if [ -n "${PAIR_FILTER:-}" ]; then
    PAIRS_TSV=$(jq -r --arg pair "$PAIR_FILTER" '
      .cross_module_dependencies[] |
      select(.binding_type == "api") |
      select((.consumer_module + "-" + .provider_module) == $pair or (.provider_module + "-" + .consumer_module) == $pair) |
      [.consumer_module, .provider_module, .entity, .binding_type] | @tsv
    ' "$REGISTRY_FILE")
  else
    PAIRS_TSV=$(jq -r '
      .cross_module_dependencies[] |
      select(.binding_type == "api") |
      [.consumer_module, .provider_module, .entity, .binding_type] | @tsv
    ' "$REGISTRY_FILE")
  fi
fi

PAIRS_COUNT=$(echo "$PAIRS_TSV" | grep -c . || echo 0)
LOG "INFO: Loaded $ALL_PAIRS_COUNT api-binding pairs total, analyzing $PAIRS_COUNT" >&2
```

### S2: Detect Provider Spec Files (OpenAPI/GraphQL/AsyncAPI)

```bash
# Chay bash helper de detect spec files va extract provider fields
# REUSE: QD6 schema-drift-detect.md THINK:113-123 (stack detection order)
declare -A PROVIDER_SPEC_FILES
declare -A PROVIDER_SPEC_TYPE    # openapi | graphql | asyncapi

while IFS=$'\t' read -r consumer_module provider_module entity binding_type; do
  [ -z "$consumer_module" ] && continue

  PROVIDER_KEY="${provider_module}:${entity}"
  [ -n "${PROVIDER_SPEC_FILES[$PROVIDER_KEY]+x}" ] && continue  # Already resolved

  # Normalize provider module → directory hint
  PROVIDER_HINT=$(echo "$provider_module" | sed 's/MOD-//' | tr '[:upper:]' '[:lower:]')

  # Chay bash helper detect
  SPEC_JSON=$(bash .claude/scripts/wf-fix-probe-contract-drift.sh \
    --source-dir "$SOURCE_DIR" \
    --provider-hint "$PROVIDER_HINT" \
    --entity "$entity" \
    --detect-spec \
    2>/dev/null || echo '{}')

  SPEC_FILE=$(echo "$SPEC_JSON" | jq -r '.spec_file // ""')
  SPEC_TYPE=$(echo "$SPEC_JSON" | jq -r '.spec_type // "unknown"')

  PROVIDER_SPEC_FILES["$PROVIDER_KEY"]="${SPEC_FILE:-}"
  PROVIDER_SPEC_TYPE["$PROVIDER_KEY"]="${SPEC_TYPE:-unknown}"

  if [ -n "$SPEC_FILE" ]; then
    LOG "INFO: Provider spec for $provider_module/$entity: $SPEC_FILE (type=$SPEC_TYPE)" >&2
  else
    LOG "WARN: No spec file found for provider $provider_module/$entity — will use CI-ROUTE fallback" >&2
  fi

done <<< "$PAIRS_TSV"
```

### S3: Locate Consumer DTOs (CI-ROUTE PRIMARY: Serena)

```bash
# Cho moi pair: locate consumer DTO definitions
declare -A CONSUMER_DTO_FILES

while IFS=$'\t' read -r consumer_module provider_module entity binding_type; do
  [ -z "$consumer_module" ] && continue

  CONSUMER_KEY="${consumer_module}:${provider_module}:${entity}"
  [ -n "${CONSUMER_DTO_FILES[$CONSUMER_KEY]+x}" ] && continue

  CONSUMER_HINT=$(echo "$consumer_module" | sed 's/MOD-//' | tr '[:upper:]' '[:lower:]')

  if [[ "$SERENA_AVAILABLE" == "true" ]]; then
    # CI-ROUTE PRIMARY: Serena find_symbol → locate consumer DTO matching entity name
    # (Pseudocode — orchestrator agent thuc hien via Serena MCP):
    # DTO_DEF = serena_find_symbol({name_path_pattern: entity + "Dto|Request|Response", include_body: true})
    # CONSUMER_DTO_FILES[$CONSUMER_KEY] = DTO_DEF.relative_path
    LOG "INFO: Using Serena find_symbol($entity + Dto/Request/Response) for consumer DTO" >&2
    CONSUMER_DTO_FILES["$CONSUMER_KEY"]="serena"
  else
    # Fallback: grep consumer dirs for DTO/interface definitions (REUSE QD7 combined grep approach)
    DTO_FILE=$(bash .claude/scripts/wf-fix-probe-contract-drift.sh \
      --source-dir "$SOURCE_DIR" \
      --consumer-hint "$CONSUMER_HINT" \
      --entity "$entity" \
      --detect-consumer-dto \
      2>/dev/null | jq -r '.dto_file // ""' || echo "")
    CONSUMER_DTO_FILES["$CONSUMER_KEY"]="${DTO_FILE:-}"
    if [ -n "$DTO_FILE" ]; then
      LOG "INFO: Consumer DTO for $consumer_module/$entity found via grep: $DTO_FILE" >&2
    else
      LOG "WARN: Consumer DTO for $consumer_module/$entity not found — field comparison will be limited" >&2
    fi
  fi

done <<< "$PAIRS_TSV"
```

### S4: Optional GitNexus API Endpoint Cross-ref

```bash
# GitNexus query("api endpoint") — xac dinh endpoint map consumer → provider
# (Pseudocode — orchestrator agent thuc hien khi GITNEXUS_AVAILABLE)
if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # ENDPOINT_MAP = gitnexus_query({query: "api endpoint"})
  # Use to confirm which provider endpoints consumer actually calls
  LOG "INFO: GitNexus available — API endpoint cross-ref enabled (via orchestrator agent)" >&2
else
  LOG "WARN: GitNexus unavailable — skip API endpoint cross-ref; relying on spec+DTO comparison" >&2
fi
```

---

## THINK

```bash
# Xay dung diff plan per pair
# REUSE: QD6 P-QD6-schema-drift-detect.md THINK:113-143 (field comparison logic)
SIGNAL_COUNT=0
MAX_SIGNALS=100
PAIRS_ANALYZED=0
PAIRS_CLEAN=0
PAIRS_DRIFT=0
DIFF_METHOD="static_files"  # default

while IFS=$'\t' read -r consumer_module provider_module entity binding_type; do
  [ -z "$consumer_module" ] && continue

  PAIR_KEY="${consumer_module}-${provider_module}-${entity}"
  PROVIDER_KEY="${provider_module}:${entity}"
  CONSUMER_KEY="${consumer_module}:${provider_module}:${entity}"

  # Xac dinh diff method
  SPEC_FILE="${PROVIDER_SPEC_FILES[$PROVIDER_KEY]:-}"
  DTO_FILE="${CONSUMER_DTO_FILES[$CONSUMER_KEY]:-}"

  if [ -n "$SPEC_FILE" ] && [ -n "$DTO_FILE" ]; then
    DIFF_METHOD="spec_vs_dto"
  elif [ -n "$SPEC_FILE" ] && [[ "$SERENA_AVAILABLE" == "true" ]]; then
    DIFF_METHOD="spec_vs_serena"
  elif [[ "$SERENA_AVAILABLE" == "true" ]]; then
    DIFF_METHOD="serena_vs_serena"
  else
    DIFF_METHOD="grep_only"
    LOG "INFO: THINK: pair $PAIR_KEY → diff_method=grep_only (limited coverage)" >&2
  fi

  # Plan checks:
  # 1. field_existence_check — provider fields ton tai trong consumer?
  # 2. type_compatibility_check — type matching?
  # 3. required_ness_check — required fields duoc declare dung?
  # 4. nullability_check — deep+ only

  CHECKS="field_existence_check,type_compatibility_check,required_ness_check"
  [[ "${PROFILE:-standard}" == "deep" || "${PROFILE:-standard}" == "exhaustive" ]] && \
    CHECKS="$CHECKS,nullability_check"

  LOG "INFO: THINK: pair $PAIR_KEY → diff_method=$DIFF_METHOD checks=$CHECKS" >&2

done <<< "$PAIRS_TSV"
```

---

## ACT

### A1: Per-Pair API Contract Drift Analysis

```bash
# REUSE QD6 P-QD6-schema-drift-detect.md THINK schema diff algorithm
# Adapted: compare provider spec fields vs consumer DTO fields

while IFS=$'\t' read -r consumer_module provider_module entity binding_type; do
  [ -z "$consumer_module" ] && continue

  PAIR_KEY="${consumer_module}-${provider_module}-${entity}"
  PAIRS_ANALYZED=$((PAIRS_ANALYZED + 1))
  HAS_SIGNAL=false

  LOG "INFO: Analyzing API contract pair: $consumer_module → $provider_module ($entity)" >&2

  PROVIDER_HINT=$(echo "$provider_module" | sed 's/MOD-//' | tr '[:upper:]' '[:lower:]')
  CONSUMER_HINT=$(echo "$consumer_module" | sed 's/MOD-//' | tr '[:upper:]' '[:lower:]')
  PROVIDER_KEY="${provider_module}:${entity}"
  CONSUMER_KEY="${consumer_module}:${provider_module}:${entity}"
  SPEC_FILE="${PROVIDER_SPEC_FILES[$PROVIDER_KEY]:-}"
  SPEC_TYPE="${PROVIDER_SPEC_TYPE[$PROVIDER_KEY]:-unknown}"

  # A1.1: Chay bash helper de extract va diff fields
  DIFF_JSON=$(bash .claude/scripts/wf-fix-probe-contract-drift.sh \
    --source-dir "$SOURCE_DIR" \
    --provider-hint "$PROVIDER_HINT" \
    --consumer-hint "$CONSUMER_HINT" \
    --entity "$entity" \
    --spec-file "${SPEC_FILE:-}" \
    --spec-type "${SPEC_TYPE:-unknown}" \
    --profile "${PROFILE:-standard}" \
    --output-file "$RAW_DIR/${PAIR_KEY}-contract-diff.json" \
    2>/dev/null || echo '{"error": "bash_helper_failed", "diffs": []}')

  # A1.2: Process diff results → emit signals
  # REUSE QD6 severity mapping: field missing=HIGH, type mismatch=MEDIUM

  # A1.2a: Breaking changes — field removed/renamed in provider spec (consumer will break)
  BREAKING=$(echo "$DIFF_JSON" | jq -r '.diffs[] | select(.drift_type == "field_removed_from_spec" or .drift_type == "required_field_added_in_spec") | [.field_name, .drift_type, .provider_value, .consumer_value] | @tsv' 2>/dev/null || echo "")

  if [ -n "$BREAKING" ]; then
    while IFS=$'\t' read -r field_name drift_type provider_value consumer_value; do
      [ -z "$field_name" ] && continue
      [ "$SIGNAL_COUNT" -ge "$MAX_SIGNALS" ] && break

      TITLE="API contract breaking change: ${consumer_module}→${provider_module}.${entity}.${field_name}"
      DESCRIPTION=""
      if [[ "$drift_type" == "field_removed_from_spec" ]]; then
        DESCRIPTION="Provider '${provider_module}' da xoa field '${field_name}' khoi spec cua entity '${entity}', nhung consumer '${consumer_module}' van co DTO field nay. Consumer se gap loi khi truong du lieu bi xoa."
      else
        DESCRIPTION="Provider '${provider_module}' da them required field '${field_name}' vao entity '${entity}', nhung consumer '${consumer_module}' chua co field nay trong DTO. Consumer se bi loi validation khi gui request thieu field bat buoc."
      fi

      # REUSE emit_signal_cross_module tu _shared.md:42-92
      emit_signal_cross_module \
        "P-QD10-api-contract-drift" \
        "api_contract_breaking_change" \
        "high" \
        "$TITLE" \
        "$DESCRIPTION" \
        "$provider_module" \
        "$consumer_module" \
        "field_diff" \
        "drift_type=${drift_type} field=${field_name} spec_value=${provider_value} dto_value=${consumer_value}"

      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      HAS_SIGNAL=true
      LOG "INFO: Signal api_contract_breaking_change: $pair_key.$field_name ($drift_type)" >&2
    done <<< "$BREAKING"
  fi

  # A1.2b: Type mismatches — type changed in potentially non-breaking way
  TYPE_MISMATCHES=$(echo "$DIFF_JSON" | jq -r '.diffs[] | select(.drift_type == "type_mismatch") | [.field_name, .provider_type, .consumer_type] | @tsv' 2>/dev/null || echo "")

  if [ -n "$TYPE_MISMATCHES" ]; then
    while IFS=$'\t' read -r field_name provider_type consumer_type; do
      [ -z "$field_name" ] && continue
      [ "$SIGNAL_COUNT" -ge "$MAX_SIGNALS" ] && break

      # REUSE emit_signal_cross_module tu _shared.md:42-92
      emit_signal_cross_module \
        "P-QD10-api-contract-drift" \
        "api_contract_type_mismatch" \
        "medium" \
        "API contract type mismatch: ${consumer_module}→${provider_module}.${entity}.${field_name}" \
        "Field '${field_name}' cua entity '${entity}' co type khac nhau: provider spec khai bao '${provider_type}' nhung consumer DTO dung '${consumer_type}'. Co the chuyen doi tu dong nhung cung co the gay runtime error." \
        "$provider_module" \
        "$consumer_module" \
        "type_diff" \
        "field=${field_name} provider_type=${provider_type} consumer_type=${consumer_type}"

      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      HAS_SIGNAL=true
      LOG "INFO: Signal api_contract_type_mismatch: $pair_key.$field_name ($provider_type vs $consumer_type)" >&2
    done <<< "$TYPE_MISMATCHES"
  fi

  # Track outcome
  if $HAS_SIGNAL; then
    PAIRS_DRIFT=$((PAIRS_DRIFT + 1))
  else
    PAIRS_CLEAN=$((PAIRS_CLEAN + 1))
  fi

done <<< "$PAIRS_TSV"
```

### A2: Write Contract Diff Summary (Coordination Output)

```bash
jq -n \
  --arg probe_id "P-QD10-api-contract-drift" \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson pairs_analyzed "$PAIRS_ANALYZED" \
  --argjson pairs_clean "$PAIRS_CLEAN" \
  --argjson pairs_drift "$PAIRS_DRIFT" \
  --argjson signals "$SIGNAL_COUNT" \
  --argjson serena "$([[ "$SERENA_AVAILABLE" == "true" ]] && echo "true" || echo "false")" \
  --argjson gitnexus "$([[ "$GITNEXUS_AVAILABLE" == "true" ]] && echo "true" || echo "false")" \
  --arg method "$DIFF_METHOD" \
  '{
    probe_id: $probe_id,
    generated_at: $now,
    pairs_analyzed: $pairs_analyzed,
    pairs_clean: $pairs_clean,
    pairs_drift: $pairs_drift,
    signals_emitted: $signals,
    ci_route: {serena: $serena, gitnexus: $gitnexus, diff_method: $method}
  }' > "$RAW_DIR/P-QD10-api-contract-drift-summary.json" 2>/dev/null || \
  LOG "WARN: summary.json write failed — khong block" >&2

LOG "INFO: API contract drift probe complete (pairs=$PAIRS_ANALYZED, drift=$PAIRS_DRIFT, signals=$SIGNAL_COUNT)" >&2
```

---

## VERIFY

```
1. Kiem tra moi signal co dimension_id == "QD10" va probe_id == "P-QD10-api-contract-drift"
2. Kiem tra moi signal co signal_type trong ["api_contract_breaking_change", "api_contract_type_mismatch"]
3. Kiem tra moi signal co evidence[] non-empty voi content >= 10 chars
4. Kiem tra dedup_key format: "P-QD10-api-contract-drift:{signal_type}:{provider}:{consumer}"
5. Kiem tra severity mapping:
   - api_contract_breaking_change → high
   - api_contract_type_mismatch → medium
6. Kiem tra SIGNAL_COUNT <= MAX_SIGNALS (100) hoac co WARNING "max_signals_reached"
7. Kiem tra summary JSON ton tai trong RAW_DIR

Ghi summary:
  cat > "$RAW_DIR/P-QD10-api-contract-drift-summary.json" << EOF
  {
    "probe_id": "P-QD10-api-contract-drift",
    "profile": "${PROFILE:-standard}",
    "pairs_analyzed": $PAIRS_ANALYZED,
    "pairs_clean": $PAIRS_CLEAN,
    "pairs_drift": $PAIRS_DRIFT,
    "signals_emitted": $SIGNAL_COUNT,
    "ci_route": {
      "serena_used": $([[ "$SERENA_AVAILABLE" == "true" ]] && echo "true" || echo "false"),
      "gitnexus_used": $([[ "$GITNEXUS_AVAILABLE" == "true" ]] && echo "true" || echo "false"),
      "diff_method": "$DIFF_METHOD"
    },
    "sampling": {
      "rate": $(echo "scale=0; $PAIRS_ANALYZED * 100 / ($ALL_PAIRS_COUNT == 0 ? 1 : $ALL_PAIRS_COUNT)" | bc),
      "total": $ALL_PAIRS_COUNT,
      "sampled": $PAIRS_ANALYZED
    }
  }
  EOF
```

---

## Severity Rules

| Dieu kien | Severity | Ly do |
|-----------|----------|-------|
| Provider da xoa field ma consumer dang dung (field_removed_from_spec) | **HIGH** | Breaking change — consumer bi loi runtime khi field khong con trong response |
| Provider them required field ma consumer chua co trong DTO (required_field_added_in_spec) | **HIGH** | Breaking change — consumer se bi validation error khi gui request thieu field bat buoc |
| Field type khac nhau giua provider spec va consumer DTO (type_mismatch) | **MEDIUM** | Co the chuyen doi tu dong (string→number) nhung cung co the loi; can developer review |
| Provider spec khong tim thay, chi co consumer DTO | **LOW** | Informational — spec co the nam trong annotation hoac chua duoc document; can review thu cong |

> **Rationale severity HIGH cho breaking_change (khac QD6 column_missing=HIGH):**
> API contract breaking change anh huong truc tiep den runtime — consumer bi loi 4xx/5xx hoac data corruption. Nghiem trong hon QD6 nullability_mismatch (MEDIUM) vi API response la real-time contract, khong co migration period.

> **Rationale severity MEDIUM cho type_mismatch (khac QD6 type_mismatch=HIGH):**
> API type mismatch co the duoc JSON coerce tu dong (string→number khi truong co the chuyen doi). QD6 DB type mismatch=HIGH vi DB insert se fail hard. API type mismatch co the soft-fail — severity MEDIUM de giam noise.

---

## Dedup Hints

| Signal Type | Dedup Key Pattern |
|-------------|------------------|
| `api_contract_breaking_change` | `P-QD10-api-contract-drift:api_contract_breaking_change:{provider_module}:{consumer_module}` |
| `api_contract_type_mismatch` | `P-QD10-api-contract-drift:api_contract_type_mismatch:{provider_module}:{consumer_module}` |

Cross-probe dedup: `api_contract_breaking_change` tu W2.3 co the overlap voi `cross_module_ref_drift` tu W2.2 khi cung provider field bi xoa/doi ten. Aggregator dedup boi dedup_key (probe_id:signal_type:provider:consumer). W2.3 la authoritative cho API-layer drift; W2.2 la authoritative cho import-level drift.

---

## Signal Schema Examples

### api_contract_breaking_change

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-api-contract-drift",
  "dimension_id": "QD10",
  "signal_type": "api_contract_breaking_change",
  "severity": "high",
  "title": "API contract breaking change: QUOTATION→CRM.Customer.customerId",
  "description": "Provider 'MOD-CRM' da xoa field 'customerId' khoi spec cua entity 'Customer', nhung consumer 'MOD-QUOTATION' van co DTO field nay. Consumer se gap loi khi truong du lieu bi xoa.",
  "location": {
    "provider_module": "MOD-CRM",
    "consumer_module": "MOD-QUOTATION",
    "file_path": "apps/quotation/src/dto/customer.dto.ts",
    "line_range": [12, 12]
  },
  "evidence": [
    {"type": "field_diff", "content": "drift_type=field_removed_from_spec field=customerId spec_value=<not_present> dto_value=string"}
  ],
  "dedup_key": "P-QD10-api-contract-drift:api_contract_breaking_change:MOD-CRM:MOD-QUOTATION"
}
```

### api_contract_type_mismatch

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-api-contract-drift",
  "dimension_id": "QD10",
  "signal_type": "api_contract_type_mismatch",
  "severity": "medium",
  "title": "API contract type mismatch: QUOTATION→CRM.Customer.creditLimit",
  "description": "Field 'creditLimit' cua entity 'Customer' co type khac nhau: provider spec khai bao 'integer' nhung consumer DTO dung 'string'. Co the chuyen doi tu dong nhung cung co the gay runtime error.",
  "location": {
    "provider_module": "MOD-CRM",
    "consumer_module": "MOD-QUOTATION",
    "file_path": "apps/quotation/src/dto/customer.dto.ts",
    "line_range": [18, 18]
  },
  "evidence": [
    {"type": "type_diff", "content": "field=creditLimit provider_type=integer consumer_type=string"}
  ],
  "dedup_key": "P-QD10-api-contract-drift:api_contract_type_mismatch:MOD-CRM:MOD-QUOTATION"
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile=quick | SKIP lane (QD10 quick=skip — probe khong duoc goi) |
| binding_type=api pairs = 0 | SKIP probe, emit WARN "skipped_no_api_binding_dependencies" → exit 0 |
| SOURCE_DIR khong ton tai | WARN + fallback SOURCE_DIR=. — probe tiep tuc voi han che |
| Khong tim thay OpenAPI/GraphQL/AsyncAPI spec | LOG WARN "no_spec_files_found" — chi so sanh DTO-to-DTO (han che hon) |
| Khong tim thay consumer DTO | LOG WARN "consumer_dto_not_found:{consumer}/{entity}" — skip field checks cho pair, tiep tuc |
| Serena unavailable | Fallback grep via wf-fix-probe-contract-drift.sh — LOG WARN, khong block |
| GitNexus unavailable | Skip API endpoint cross-ref — LOG WARN, khong block |
| wf-fix-probe-contract-drift.sh fail | LOG WARN + empty diffs — probe tiep tuc voi 0 signals cho pair do |
| > 30 api pairs | Priority queue (nhieu required_fields truoc), sample top 30, emit_sampling_note |
| > 100 signals | Stop emitting, LOG WARN "max_signals_reached (100)" |
| Registry parse error (jq fail) | ERROR E100 + exit 1 — registry corrupt la blocker real |
| --pair format invalid | ERROR + exit 1 — inform user format MODULE_A-MODULE_B |
| Spec file parse error | Log WARNING per file, skip file do, tiep tuc cac file khac |

---

## Cache Policy

**allowed** — probe nay la pure static analysis (KHONG co runtime component: browser, DB, API call).

Cache TTL: 24h (per `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §3.5).

Ly do: OpenAPI spec va consumer DTO khong thay doi tru khi co code commit. Cache hieu qua khi chay nhieu profile consecutively. Key: `{PROJECT_ROOT_SHA}:{registry_api_pairs_count}:{spec_files_mtime_hash}`.

---

## Profile-Resolver Entry

```yaml
# Trong procedures/probes/_shared.md (QD10 Profile-Resolver section):
P-QD10-api-contract-drift:
  quick: skip
  standard: run (field_existence + type_compatibility + required_ness checks)
  deep: run + nullability_check
  exhaustive: run + nullability_check + enum_value_check
  parallel_class: static
  optional: false
  max_pairs: 30
  nullability_check_profiles: [deep, exhaustive]
  enum_check_profiles: [exhaustive]
```

---

## Acceptance Test

**Synthetic test (CI):**
1. Setup registry voi cross_module_dependency binding_type=api:
   ```json
   {
     "cross_module_dependencies": [{
       "consumer_module": "MOD-QUOTATION",
       "provider_module": "MOD-CRM",
       "entity": "Customer",
       "binding_type": "api",
       "required_fields": ["customerId", "customerName", "creditLimit"]
     }]
   }
   ```
2. Setup provider spec: `apps/crm/openapi.yaml` voi endpoint `/customers/{id}` response schema:
   - Fields: `customerName` (string), `creditLimit` (integer) — **khong co `customerId`** (da xoa)
3. Setup consumer DTO: `apps/quotation/dto/customer.dto.ts`:
   - `customerId: string` (van con — drift!)
   - `customerName: string` (ok)
   - `creditLimit: string` (type mismatch — probe spec: integer)
4. Run probe voi `--profile=standard`
5. **Expected:**
   - `api_contract_breaking_change` signal (severity=HIGH) cho field `customerId` (field_removed_from_spec)
   - `api_contract_type_mismatch` signal (severity=MEDIUM) cho field `creditLimit` (integer vs string)
   - `customerName` → PASS (no drift)
6. Verify: `jq 'select(.signal_type == "api_contract_breaking_change")' "$SIGNALS_FILE"`

**EUREKA acceptance (W2.E2E):**
- Author cross_module_dependency binding_type=api trong EUREKA registry (entity Customer, consumer=MOD-QUOTATION, provider=MOD-CRM)
- Ensure provider openapi.yaml ton tai trong apps/crm/ hoac apps/backend/
- Run `/wf-fix-bugs --lane=QD10 --pair=CRM-QUOTATION --profile=standard`
- Expect: Probe complete; signals hoac PASS rõ; performance <= 3 phut cho 1 pair (static)
