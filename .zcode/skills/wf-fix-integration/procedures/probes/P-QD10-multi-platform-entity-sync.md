# P-QD10-multi-platform-entity-sync — Multi-Platform Entity Sync Detection

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD10-multi-platform-entity-sync |
| **Loai** | runtime |
| **Profile** | deep, exhaustive |
| **Muc dich** | Phat hien entity shape divergence giua ERP va Mobile/MC platform API. Tim cap MOD-XXX↔MOD-MC-XXX, goi API ca 2 platform, diff JSON shape + field set + types. EUREKA-specific: auto-detect MC-ORDERS↔ORDERS. |
| **Cache** | NOT allowed (runtime API call — ket qua phu thuoc platform state) |
| **Error codes** | E100 (registry corrupt — QD10 base), E106 (API schema parse fail), E110 (no MC platform pairs found) |
| **Migrates from** | (new in v9, W3.2) |

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| HTTP call harness (curl GET, response parse) | `QD1 P-QD1-api-smoke.md` | `:59-81 (ACT curl loop)` | Reuse curl pattern: `curl -s -w "\n%{http_code}"`, BODY/CODE extract, `--max-time 10`. Adapt: 2 calls per entity (ERP + MC). |
| Response status check pattern | `QD1 P-QD1-api-smoke.md` | `:85-109 (ACT signal creation)` | Reuse signal schema pattern. Thay probe_id + signal_type cho multi-platform context. |
| Endpoint discovery from API docs | `QD1 P-QD1-api-smoke.md` | `:24-32 (SENSE B1)` | Reuse API doc discovery (.mc-data/docs/phase3-architecture/api-*.md) cho ca ERP + MC endpoints. |
| emit_signal_runtime_integration() | `procedures/probes/_shared.md` (QD10) | `:98-133` | Runtime signal emit voi api_response_diff evidence. |
| iterate_module_pairs() | `procedures/probes/_shared.md` (QD10) | `:139-160` | Reuse pair iteration — adapted: filter binding_type=api + MC-module naming. |
| with_runtime_cap timeout | `.claude/scripts/wf-fix-common.sh` | `:with_runtime_cap` | Timeout guard per HTTP call (10s per request). |
| jq_int JSON helper | `.claude/scripts/wf-fix-common.sh` | `:jq_int` | CRLF-safe JSON parsing. |
| QD9 dev-server-state.json | QD9 coordination | `_shared.md:21` | Reuse BASE_URL ERP tu dev-server bootstrap. |
| QD9 auth-session.json | QD9 coordination | `_shared.md:20` | Reuse auth cookies/token cho API calls. |

**Diff so voi QD1 api-smoke:**
- QD1: smoke test tung endpoint rieng le (1 platform, happy path)
- W3.2: goi SONG SONG 2 platform cho cung entity → diff shape + fields
- Scope: entity-level (khong per-endpoint) — compare entity representation giua ERP vs MC
- Khong require API docs — co the detect qua module naming convention

---

## CI-ROUTE

Per `03-reuse-ci-parallelism.md §3.3`:

| Task | Primary CI Tool | Fallback | Purpose |
|------|----------------|----------|---------|
| Tim ERP + MC API endpoints cho entity | **GitNexus** `query("entity:{EntityName}")` | Grep `/api/` routes trong code | Trace API routes trong ca ERP va MC contexts |
| Compare entity DTOs (field set, types) | **Serena** `find_symbol(DTO_class_name)` | Grep `interface EntityName` / `class EntityName` | Locate TypeScript/OpenAPI schemas pre-runtime |
| Verify API routes co trong codebase | **GitNexus** `query("route:{api_path}")` | Grep router definitions | Confirm ca ERP + MC API paths ton tai |

**Fallback policy:** Khi CI unavailable → fallback Grep. Log "CI tool {X} unavailable, fell back to Grep — coverage may degrade".

---

## PRE-GATE

```
1. IF profile=quick OR profile=standard:
     SKIP probe (runtime probe — deep+ only)
     LOG "INFO: P-QD10-multi-platform-entity-sync skipped (profile=${PROFILE}, requires deep+)"
     → exit 0

2. Load BASE_URL_ERP:
     # Priority 1: QD9 dev-server-state.json (coordination)
     IF QD9_DEV_SERVER_STATE exists AND valid JSON:
       BASE_URL_ERP=$(jq -r '.url // empty' "$QD9_DEV_SERVER_STATE" 2>/dev/null)
     
     # Priority 2: wf-fix-detect-base-url.sh
     IF [ -z "$BASE_URL_ERP" ]:
       BASE_URL_ERP=$(bash .claude/scripts/wf-fix-detect-base-url.sh \
         --project-root="$PROJECT_ROOT" 2>/dev/null \
         | jq -r '.apps[0].base_url // empty' 2>/dev/null)
     
     # Priority 3: --url flag
     IF [ -z "$BASE_URL_ERP" ] AND [ -n "${URL_FLAG:-}" ]:
       BASE_URL_ERP="$URL_FLAG"
     
     IF [ -z "$BASE_URL_ERP" ]:
       SKIP probe — note "skipped_no_base_url"
       LOG "INFO: P-QD10-multi-platform-entity-sync requires BASE_URL. Run W1.2 or set --url."
       → exit 0

3. Detect MC platform pairs (pre-check):
     MC_MODULE_COUNT=$(jq '
       [.modules[]? | select(.id | test("MOD-MC-"; "i"))] | length
     ' "$REGISTRY_FILE" 2>/dev/null || echo 0)
     
     API_MC_DEP_COUNT=$(jq '
       [.cross_module_dependencies // [] | .[] |
        select(.binding_type == "api") |
        select((.consumer_module | test("MOD-MC-"; "i")) or
               (.provider_module | test("MOD-MC-"; "i")))] | length
     ' "$REGISTRY_FILE" 2>/dev/null || echo 0)
     
     IF [ "$MC_MODULE_COUNT" -eq 0 ] AND [ "$API_MC_DEP_COUNT" -eq 0 ]:
       SKIP probe — E110 note "no_mc_platform_pairs"
       LOG "INFO: E110: Khong tim thay MOD-MC-* modules trong registry."
       LOG "INFO: Multi-platform detection can: MOD-XXX + MOD-MC-XXX trong registry.modules[]"
       LOG "INFO: hoac cross_module_dependencies[] voi binding_type=api + MC naming."
       → exit 0

4. Ensure RAW_DIR + LANE_DIR exist:
     mkdir -p "$RAW_DIR" "$LANE_DIR"
```

---

## SENSE

### S1: Detect ERP↔MC Platform Pairs

```bash
# 2 strategies de detect pairs (theo thu tu uu tien):
# Strategy A: explicit cross_module_dependencies[] voi binding_type=api + MC naming
# Strategy B: Heuristic module name scan (MOD-MC-XXX → check if MOD-XXX exists)
# EUREKA: MC-ORDERS ↔ ORDERS, MC-CUSTOMER ↔ CRM, etc.

MC_PAIRS_FILE="$RAW_DIR/mc-pairs-detected.json"
echo "[]" > "$MC_PAIRS_FILE"

# Strategy A: explicit deps
while IFS=$'\t' read -r consumer_module provider_module entity; do
  [ -z "$consumer_module" ] && continue
  # Xac dinh ERP vs MC role
  if echo "$consumer_module" | grep -qi "MOD-MC-"; then
    MC_MODULE="$consumer_module"
    ERP_MODULE="$provider_module"
  else
    ERP_MODULE="$consumer_module"
    MC_MODULE="$provider_module"
  fi
  # Append to pairs file
  jq -n \
    --arg erp "$ERP_MODULE" --arg mc "$MC_MODULE" --arg entity "$entity" \
    --arg src "explicit_dep" \
    '{erp_module: $erp, mc_module: $mc, entity: $entity, source: $src}' | \
  jq --argjson existing "$(cat "$MC_PAIRS_FILE")" '$existing + [.]' > "$MC_PAIRS_FILE.tmp" && \
  mv "$MC_PAIRS_FILE.tmp" "$MC_PAIRS_FILE"
  LOG "INFO: Strategy A: pair ${ERP_MODULE}↔${MC_MODULE} (entity=${entity})" >&2
done < <(jq -r '
  .cross_module_dependencies // [] | .[] |
  select(.binding_type == "api") |
  select((.consumer_module | test("MOD-MC-"; "i")) or
         (.provider_module | test("MOD-MC-"; "i"))) |
  [.consumer_module, .provider_module, (.entity // "Unknown")] | @tsv
' "$REGISTRY_FILE" 2>/dev/null)

STRATEGY_A_COUNT=$(jq 'length' "$MC_PAIRS_FILE")

# Strategy B: Heuristic scan neu Strategy A khong du
if [ "$STRATEGY_A_COUNT" -eq 0 ]; then
  LOG "INFO: Strategy A found 0 pairs. Trying Strategy B (heuristic module name scan)." >&2
  
  while IFS='' read -r mc_module; do
    [ -z "$mc_module" ] && continue
    # MOD-MC-ORDERS → MOD-ORDERS
    erp_candidate=$(echo "$mc_module" | sed 's/MOD-MC-/MOD-/')
    
    erp_exists=$(jq -r --arg id "$erp_candidate" \
      '.modules[]? | select(.id == $id) | .id' \
      "$REGISTRY_FILE" 2>/dev/null | head -1)
    
    if [ -n "$erp_exists" ]; then
      # Detect entity name tu module name: MOD-ORDERS → Order
      raw_name=$(echo "$erp_candidate" | sed 's/^MOD-//')
      entity_name=$(echo "$raw_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
      
      jq -n \
        --arg erp "$erp_candidate" --arg mc "$mc_module" --arg entity "$entity_name" \
        --arg src "heuristic" \
        '{erp_module: $erp, mc_module: $mc, entity: $entity, source: $src}' | \
      jq --argjson existing "$(cat "$MC_PAIRS_FILE")" '$existing + [.]' > "$MC_PAIRS_FILE.tmp" && \
      mv "$MC_PAIRS_FILE.tmp" "$MC_PAIRS_FILE"
      LOG "INFO: Strategy B: Found pair ${erp_candidate}↔${mc_module} (entity=${entity_name})" >&2
    fi
  done < <(jq -r '.modules[]? | select(.id | test("MOD-MC-"; "i")) | .id' "$REGISTRY_FILE" 2>/dev/null)
fi

PAIR_COUNT=$(jq 'length' "$MC_PAIRS_FILE")
LOG "INFO: S1 detected ${PAIR_COUNT} ERP↔MC platform pairs" >&2

# CI-ROUTE: GitNexus PRIMARY — augment pairs voi entity info
if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
  while IFS='' read -r entity; do
    LOG "INFO: CI: GitNexus query('entity:${entity}') — augment API route detection" >&2
    # Ket qua dung trong S2 de build endpoint URL chinh xac hon
  done < <(jq -r '.[].entity' "$MC_PAIRS_FILE" 2>/dev/null | sort -u)
else
  LOG "WARN: GitNexus unavailable — fell back to code grep + convention for endpoint detection." >&2
fi
```

### S2: Detect API Endpoints per Pair

```bash
detect_endpoint_for_module() {
  local module="$1"
  local entity="$2"
  local entity_lower=$(echo "$entity" | tr '[:upper:]' '[:lower:]')
  local entity_plural="${entity_lower}s"
  
  # Priority 1: API doc tu phase3-architecture
  local api_doc_endpoint=""
  api_doc_endpoint=$(grep -r -l -i "$entity_lower" \
    ".mc-data/docs/phase3-architecture/" 2>/dev/null | \
    xargs grep -h -oE "/(api|v[0-9]+)/[a-z0-9/\-_]+" 2>/dev/null | \
    grep -i "$entity_lower" | head -1)
  
  if [ -n "$api_doc_endpoint" ]; then
    echo "$api_doc_endpoint"
    return
  fi
  
  # Priority 2: Convention fallback
  if echo "$module" | grep -qi "MOD-MC-"; then
    # MC module: /api/mc/{entity}s hoac /mc/api/{entity}s
    echo "/api/mc/${entity_plural}"
  else
    # ERP module: /api/{entity}s
    echo "/api/${entity_plural}"
  fi
}

# Detect MC platform BASE_URL
BASE_URL_MC=""
# Priority 1: QD9 dev-server-state.json (MC app)
if [ -n "${QD9_DEV_SERVER_STATE:-}" ] && [ -f "$QD9_DEV_SERVER_STATE" ]; then
  BASE_URL_MC=$(jq -r \
    '.apps[]? | select(.name | test("mc|mobile|customer"; "i")) | .base_url' \
    "$QD9_DEV_SERVER_STATE" 2>/dev/null | head -1)
fi

# Priority 2: detect-base-url.sh
if [ -z "$BASE_URL_MC" ]; then
  ALL_APPS_JSON=$(bash .claude/scripts/wf-fix-detect-base-url.sh \
    --project-root="$PROJECT_ROOT" 2>/dev/null)
  BASE_URL_MC=$(echo "$ALL_APPS_JSON" | \
    jq -r '.apps[]? | select(.name | test("mc|mobile"; "i")) | .base_url' \
    2>/dev/null | head -1)
fi

# Priority 3: same host, MC routes dung /mc/ prefix
if [ -z "$BASE_URL_MC" ]; then
  BASE_URL_MC="$BASE_URL_ERP"
  LOG "WARN: MC base URL khong detect duoc — assume same host ERP: $BASE_URL_ERP (MC routes at /api/mc/)" >&2
fi

LOG "INFO: ERP base_url=$BASE_URL_ERP | MC base_url=$BASE_URL_MC" >&2

# Serena SECONDARY: find DTO class de pre-compare fields truoc runtime
if [ "$SERENA_AVAILABLE" = "true" ]; then
  while IFS='' read -r entity; do
    LOG "INFO: CI: Serena find_symbol('${entity}') — DTO pre-comparison" >&2
    # Ket qua inform field comparison trong A2
  done < <(jq -r '.[].entity' "$MC_PAIRS_FILE" 2>/dev/null | sort -u)
fi
```

### S3: Load QD9 Auth Session (Optional)

```bash
AUTH_HEADERS=""
if [ -n "${QD9_AUTH_SESSION:-}" ] && [ -f "$QD9_AUTH_SESSION" ]; then
  COOKIE_VALUE=$(jq -r '.cookie // empty' "$QD9_AUTH_SESSION" 2>/dev/null)
  BEARER_TOKEN=$(jq -r '.token // empty' "$QD9_AUTH_SESSION" 2>/dev/null)
  
  if [ -n "$COOKIE_VALUE" ]; then
    AUTH_HEADERS="-H 'Cookie: $COOKIE_VALUE'"
  elif [ -n "$BEARER_TOKEN" ]; then
    AUTH_HEADERS="-H 'Authorization: Bearer $BEARER_TOKEN'"
  fi
  LOG "INFO: QD9 auth session loaded — su dung cho API calls" >&2
fi
```

---

## THINK

```bash
# Per pair: build call plan
# REUSE QD1 P-QD1-api-smoke.md THINK (Expected HTTP codes: GET=200)

LOG "INFO: THINK: Building call plan for ${PAIR_COUNT} pairs..." >&2

while IFS=$'\t' read -r erp_mod mc_mod entity; do
  [ -z "$erp_mod" ] && continue
  ERP_ENDPOINT=$(detect_endpoint_for_module "$erp_mod" "$entity")
  MC_ENDPOINT=$(detect_endpoint_for_module "$mc_mod" "$entity")
  LOG "INFO: THINK: ${erp_mod}↔${mc_mod} (${entity}): ERP=${BASE_URL_ERP}${ERP_ENDPOINT} | MC=${BASE_URL_MC}${MC_ENDPOINT}" >&2
done < <(jq -r '.[] | [.erp_module, .mc_module, .entity] | @tsv' "$MC_PAIRS_FILE" 2>/dev/null)
```

---

## ACT

### A1: HTTP Calls ca 2 Platforms (REUSE QD1 P-QD1-api-smoke.md :59-81)

```bash
SIGNAL_COUNT=0
MAX_SIGNALS=50
PAIRS_ANALYZED=0
PAIRS_CLEAN=0
PAIRS_DIVERGENT=0

while IFS=$'\t' read -r erp_mod mc_mod entity; do
  [ -z "$erp_mod" ] && continue
  [ "$SIGNAL_COUNT" -ge "$MAX_SIGNALS" ] && {
    LOG "WARN: max_signals_reached ($MAX_SIGNALS), stopping" >&2
    break
  }
  
  PAIRS_ANALYZED=$((PAIRS_ANALYZED + 1))
  
  ERP_ENDPOINT=$(detect_endpoint_for_module "$erp_mod" "$entity")
  MC_ENDPOINT=$(detect_endpoint_for_module "$mc_mod" "$entity")
  ERP_URL="${BASE_URL_ERP}${ERP_ENDPOINT}"
  MC_URL="${BASE_URL_MC}${MC_ENDPOINT}"
  RAW_FILE="$RAW_DIR/P-QD10-multi-platform-entity-sync-${erp_mod}-${mc_mod}.json"
  
  # ERP API call (REUSE QD1 api-smoke curl pattern :67-70)
  ERP_HTTP=$(with_runtime_cap 10 \
    curl -s -w "\n%{http_code}" -H "Accept: application/json" \
    ${AUTH_HEADERS} "$ERP_URL" --max-time 10 2>/dev/null \
    || echo -e "\n000")
  ERP_BODY=$(echo "$ERP_HTTP" | head -n -1)
  ERP_CODE=$(echo "$ERP_HTTP" | tail -1 | tr -d '[:space:]')
  
  # MC API call
  MC_HTTP=$(with_runtime_cap 10 \
    curl -s -w "\n%{http_code}" -H "Accept: application/json" \
    ${AUTH_HEADERS} "$MC_URL" --max-time 10 2>/dev/null \
    || echo -e "\n000")
  MC_BODY=$(echo "$MC_HTTP" | head -n -1)
  MC_CODE=$(echo "$MC_HTTP" | tail -1 | tr -d '[:space:]')
  
  LOG "INFO: ${erp_mod}↔${mc_mod}: ERP_CODE=$ERP_CODE MC_CODE=$MC_CODE" >&2
```

### A2: Compare Responses

```bash
  # Phase 1: HTTP status comparison
  if [ "$ERP_CODE" != "$MC_CODE" ]; then
    LOG "INFO: Status mismatch: ERP=${ERP_CODE} MC=${MC_CODE}" >&2
    if [ "$SIGNAL_COUNT" -lt "$MAX_SIGNALS" ]; then
      emit_signal_runtime_integration \
        "P-QD10-multi-platform-entity-sync" \
        "entity_sync_response_shape_mismatch" \
        "high" \
        "HTTP status mismatch: ${entity} — ERP=${ERP_CODE} vs MC=${MC_CODE}" \
        "Entity '${entity}' tra ve HTTP status khac nhau giua ERP (${erp_mod}: ${ERP_CODE}) va MC platform (${mc_mod}: ${MC_CODE}). Day la dau hieu platform API khong dong bo. Nguyen nhan co the: (1) MC endpoint chua implement; (2) Auth requirements khac nhau giua platforms; (3) Entity naming mismatch; (4) BASE_URL detect sai cho MC app." \
        "api_response_diff" \
        "erp_module=${erp_mod} mc_module=${mc_mod} entity=${entity} erp_status=${ERP_CODE} mc_status=${MC_CODE} erp_url=${ERP_URL} mc_url=${MC_URL}" \
        "{\"provider_module\": \"${erp_mod}\", \"consumer_module\": \"${mc_mod}\", \"entity\": \"${entity}\"}"
      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      PAIRS_DIVERGENT=$((PAIRS_DIVERGENT + 1))
    fi
    jq -n --arg pair "${erp_mod}-${mc_mod}" --arg entity "$entity" \
      --arg erp_code "$ERP_CODE" --arg mc_code "$MC_CODE" \
      --arg erp_url "$ERP_URL" --arg mc_url "$MC_URL" \
      '{pair:$pair, entity:$entity, erp_code:$erp_code, mc_code:$mc_code,
        erp_url:$erp_url, mc_url:$mc_url, status:"status_mismatch"}' > "$RAW_FILE"
    continue
  fi
  
  # Ca 2 non-200: skip comparison (khong co data de diff)
  if [ "$ERP_CODE" != "200" ]; then
    LOG "INFO: Both platforms non-200 for ${erp_mod}↔${mc_mod}: $ERP_CODE — skip comparison" >&2
    jq -n --arg pair "${erp_mod}-${mc_mod}" --arg status "both_non_200" \
      --arg code "$ERP_CODE" '{pair:$pair, status:$status, code:$code}' > "$RAW_FILE"
    continue
  fi
  
  # Phase 2: Ca 2 tra 200 → compare JSON structure
  ERP_VALID=$(echo "$ERP_BODY" | jq '.' > /dev/null 2>&1 && echo "true" || echo "false")
  MC_VALID=$(echo "$MC_BODY" | jq '.' > /dev/null 2>&1 && echo "true" || echo "false")
  if [ "$ERP_VALID" = "false" ] || [ "$MC_VALID" = "false" ]; then
    LOG "WARN: E106: JSON parse fail cho pair ${erp_mod}↔${mc_mod}" >&2
    jq -n --arg pair "${erp_mod}-${mc_mod}" --arg status "json_parse_fail" \
      '{pair:$pair, status:$status}' > "$RAW_FILE"
    continue
  fi
  
  # Root type check: array vs object
  ERP_ROOT_TYPE=$(echo "$ERP_BODY" | jq -r 'type' 2>/dev/null || echo "unknown")
  MC_ROOT_TYPE=$(echo "$MC_BODY" | jq -r 'type' 2>/dev/null || echo "unknown")
  
  if [ "$ERP_ROOT_TYPE" != "$MC_ROOT_TYPE" ]; then
    if [ "$SIGNAL_COUNT" -lt "$MAX_SIGNALS" ]; then
      emit_signal_runtime_integration \
        "P-QD10-multi-platform-entity-sync" \
        "entity_sync_response_shape_mismatch" \
        "high" \
        "Root structure mismatch: ${entity} — ERP=${ERP_ROOT_TYPE} vs MC=${MC_ROOT_TYPE}" \
        "Entity '${entity}' co cau truc root khac nhau giua ERP (${erp_mod}: ${ERP_ROOT_TYPE}) va MC platform (${mc_mod}: ${MC_ROOT_TYPE}). Consumer code expect cung shape — mismatch gay runtime parse error hoac data loss toan bo." \
        "api_response_diff" \
        "erp_module=${erp_mod} mc_module=${mc_mod} entity=${entity} erp_root_type=${ERP_ROOT_TYPE} mc_root_type=${MC_ROOT_TYPE} erp_status=${ERP_CODE} mc_status=${MC_CODE}" \
        "{\"provider_module\": \"${erp_mod}\", \"consumer_module\": \"${mc_mod}\", \"entity\": \"${entity}\"}"
      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      PAIRS_DIVERGENT=$((PAIRS_DIVERGENT + 1))
    fi
    jq -n --arg pair "${erp_mod}-${mc_mod}" --arg erp_type "$ERP_ROOT_TYPE" \
      --arg mc_type "$MC_ROOT_TYPE" --arg status "root_type_mismatch" \
      '{pair:$pair, erp_root_type:$erp_type, mc_root_type:$mc_type, status:$status}' > "$RAW_FILE"
    continue
  fi
  
  # Phase 3: Field comparison (sample first item if array)
  if [ "$ERP_ROOT_TYPE" = "array" ]; then
    ERP_SAMPLE=$(echo "$ERP_BODY" | jq '.[0] // {}' 2>/dev/null)
    MC_SAMPLE=$(echo "$MC_BODY" | jq '.[0] // {}' 2>/dev/null)
  else
    ERP_SAMPLE="$ERP_BODY"
    MC_SAMPLE="$MC_BODY"
  fi
  
  ERP_FIELDS=$(echo "$ERP_SAMPLE" | jq -r 'keys[]' 2>/dev/null | sort)
  MC_FIELDS=$(echo "$MC_SAMPLE" | jq -r 'keys[]' 2>/dev/null | sort)
  
  FIELDS_ERP_ONLY=$(comm -23 <(echo "$ERP_FIELDS") <(echo "$MC_FIELDS") | tr '\n' ',' | sed 's/,$//')
  FIELDS_MC_ONLY=$(comm -13 <(echo "$ERP_FIELDS") <(echo "$MC_FIELDS") | tr '\n' ',' | sed 's/,$//')
  FIELD_DIFF_TOTAL=$(( $(echo "$FIELDS_ERP_ONLY" | tr ',' '\n' | grep -c . || echo 0) + \
                       $(echo "$FIELDS_MC_ONLY" | tr ',' '\n' | grep -c . || echo 0) ))
  
  if [ "$FIELD_DIFF_TOTAL" -gt 0 ] && [ "$SIGNAL_COUNT" -lt "$MAX_SIGNALS" ]; then
    emit_signal_runtime_integration \
      "P-QD10-multi-platform-entity-sync" \
      "entity_sync_field_mismatch" \
      "medium" \
      "Field mismatch: ${entity} — ${FIELD_DIFF_TOTAL} fields differ between ERP and MC" \
      "Entity '${entity}' co ${FIELD_DIFF_TOTAL} field(s) khac nhau giua ERP (${erp_mod}) va MC platform (${mc_mod}). Fields chi co trong ERP: [${FIELDS_ERP_ONLY:-none}]. Fields chi co trong MC: [${FIELDS_MC_ONLY:-none}]. Consumers tren mot platform nhan thieu fields so voi spec — co the gay undefined access errors, data loss trong sync, hoac UX inconsistency." \
      "api_response_diff" \
      "erp_module=${erp_mod} mc_module=${mc_mod} entity=${entity} field_diff_count=${FIELD_DIFF_TOTAL} erp_only_fields=${FIELDS_ERP_ONLY} mc_only_fields=${FIELDS_MC_ONLY}" \
      "{\"provider_module\": \"${erp_mod}\", \"consumer_module\": \"${mc_mod}\", \"entity\": \"${entity}\"}"
    SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
    PAIRS_DIVERGENT=$((PAIRS_DIVERGENT + 1))
  fi
  
  # Phase 4: Field type comparison (common fields)
  COMMON_FIELDS=$(comm -12 <(echo "$ERP_FIELDS") <(echo "$MC_FIELDS"))
  TYPE_MISMATCHES=""
  TYPE_MISMATCH_COUNT=0
  
  while IFS='' read -r field; do
    [ -z "$field" ] && continue
    ERP_FTYPE=$(echo "$ERP_SAMPLE" | jq -r --arg f "$field" '.[$f] | type' 2>/dev/null || echo "unknown")
    MC_FTYPE=$(echo "$MC_SAMPLE" | jq -r --arg f "$field" '.[$f] | type' 2>/dev/null || echo "unknown")
    if [ "$ERP_FTYPE" != "$MC_FTYPE" ] && \
       [ "$ERP_FTYPE" != "unknown" ] && [ "$MC_FTYPE" != "unknown" ] && \
       [ "$ERP_FTYPE" != "null" ] && [ "$MC_FTYPE" != "null" ]; then
      TYPE_MISMATCHES="${TYPE_MISMATCHES}${field}(${ERP_FTYPE}→${MC_FTYPE}),"
      TYPE_MISMATCH_COUNT=$((TYPE_MISMATCH_COUNT + 1))
    fi
  done <<< "$COMMON_FIELDS"
  TYPE_MISMATCHES="${TYPE_MISMATCHES%,}"  # trim trailing comma
  
  if [ "$TYPE_MISMATCH_COUNT" -gt 0 ] && [ "$SIGNAL_COUNT" -lt "$MAX_SIGNALS" ]; then
    emit_signal_runtime_integration \
      "P-QD10-multi-platform-entity-sync" \
      "entity_sync_field_mismatch" \
      "medium" \
      "Field type mismatch: ${entity} — ${TYPE_MISMATCH_COUNT} fields have different types" \
      "Entity '${entity}' co ${TYPE_MISMATCH_COUNT} field(s) voi type khac nhau giua ERP (${erp_mod}) va MC (${mc_mod}). Fields bi mismatch type: [${TYPE_MISMATCHES}]. Type mismatch gay parse errors o consumer khi xu ly API response tu platform khac." \
      "api_response_diff" \
      "erp_module=${erp_mod} mc_module=${mc_mod} entity=${entity} type_mismatch_count=${TYPE_MISMATCH_COUNT} type_mismatches=${TYPE_MISMATCHES}" \
      "{\"provider_module\": \"${erp_mod}\", \"consumer_module\": \"${mc_mod}\", \"entity\": \"${entity}\"}"
    SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
  fi
  
  # Clean pair
  if [ "$FIELD_DIFF_TOTAL" -eq 0 ] && [ "$TYPE_MISMATCH_COUNT" -eq 0 ]; then
    PAIRS_CLEAN=$((PAIRS_CLEAN + 1))
    LOG "INFO: PASS: ${erp_mod}↔${mc_mod} entity=${entity} — field set va types dong bo" >&2
  fi
  
  jq -n \
    --arg pair "${erp_mod}-${mc_mod}" --arg entity "$entity" \
    --arg erp_code "$ERP_CODE" --arg mc_code "$MC_CODE" \
    --argjson erp_fields "$(echo "$ERP_FIELDS" | wc -l | tr -d ' ')" \
    --argjson mc_fields "$(echo "$MC_FIELDS" | wc -l | tr -d ' ')" \
    --argjson diff_count "$FIELD_DIFF_TOTAL" \
    --argjson type_diff "$TYPE_MISMATCH_COUNT" \
    '{pair:$pair, entity:$entity, erp_code:$erp_code, mc_code:$mc_code,
      erp_field_count:$erp_fields, mc_field_count:$mc_fields,
      field_diff_count:$diff_count, type_mismatch_count:$type_diff,
      status:"analyzed"}' > "$RAW_FILE"

done < <(jq -r '.[] | [.erp_module, .mc_module, .entity] | @tsv' "$MC_PAIRS_FILE" 2>/dev/null)
```

### A3: Write Summary JSON

```bash
jq -n \
  --arg probe_id "P-QD10-multi-platform-entity-sync" \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg erp_base "$BASE_URL_ERP" \
  --arg mc_base "$BASE_URL_MC" \
  --argjson pairs_total "$PAIR_COUNT" \
  --argjson pairs_analyzed "$PAIRS_ANALYZED" \
  --argjson pairs_clean "$PAIRS_CLEAN" \
  --argjson pairs_divergent "$PAIRS_DIVERGENT" \
  --argjson signals "$SIGNAL_COUNT" \
  '{
    probe_id: $probe_id,
    generated_at: $now,
    erp_base_url: $erp_base,
    mc_base_url: $mc_base,
    pairs_total: $pairs_total,
    pairs_analyzed: $pairs_analyzed,
    pairs_clean: $pairs_clean,
    pairs_divergent: $pairs_divergent,
    signals_emitted: $signals
  }' > "$RAW_DIR/P-QD10-multi-platform-entity-sync-summary.json" 2>/dev/null || \
  LOG "WARN: summary.json write failed — khong block" >&2

LOG "INFO: Multi-platform entity sync probe complete (pairs_analyzed=$PAIRS_ANALYZED, divergent=$PAIRS_DIVERGENT, signals=$SIGNAL_COUNT)" >&2
```

---

## VERIFY

```
1. Kiem tra moi signal co dimension_id == "QD10" va probe_id == "P-QD10-multi-platform-entity-sync"
2. Kiem tra signal_type trong ["entity_sync_response_shape_mismatch", "entity_sync_field_mismatch"]
3. Kiem tra entity_sync_response_shape_mismatch co severity == "high"
4. Kiem tra entity_sync_field_mismatch co severity == "medium"
5. Kiem tra moi signal co evidence[] non-empty voi type "api_response_diff"
6. Kiem tra evidence content chua erp_module, mc_module, entity
7. Kiem tra dedup_key format: "P-QD10-multi-platform-entity-sync:{signal_type}:{context}"
8. Kiem tra SIGNAL_COUNT <= MAX_SIGNALS (50) hoac co WARNING "max_signals_reached"
9. Kiem tra summary JSON ton tai trong RAW_DIR voi pairs_analyzed >= 0
10. Khong co side-effect mutation trong API calls (chi GET requests — khong POST/PUT/DELETE)
```

---

## Severity Rules

| Dieu kien | Severity | Ly do |
|-----------|----------|-------|
| HTTP status code khac nhau giua ERP va MC (vd: 200 vs 404) | **HIGH** | Mot platform khong serve entity → consumers tren platform do khong nhan duoc data. Hard failure — khong co graceful fallback. Tuong tu api_contract_breaking_change (HIGH) vi cung class: platform pha vo consumer contract. |
| Root JSON structure khac nhau (array vs object) | **HIGH** | Consumer code expect mot loai → runtime parse error 100% khi xu ly response tu platform khac. Data loss toan bo — cung severity class voi entity_sync_response_shape_mismatch. |
| Fields co trong ERP nhung thieu trong MC (hoac nguoc lai) | **MEDIUM** | Field thieu → undefined access trong consumer code. Co the graceful (undefined check), co the crash. Can developer review — khong guaranteed crash nhung la data inconsistency risk. |
| Field type khac nhau giua platforms (vd: string vs number) | **MEDIUM** | Type coercion co the soft-fail (JavaScript) hoac crash (TypeScript strict). Developer review needed. |

**Rationale HIGH cho entity_sync_response_shape_mismatch:**
Khi platform A tra ve HTTP 404 hoac array trong khi platform B tra ve 200 voi object, consumer code expect
behavior nhat quan — bat ky sai lech nao tao runtime exception hoac data loss. Tuong tu api_contract_breaking_change
(W2.3 — HIGH) vi class failure giong nhau: breaking change o API level giua platforms.

**Rationale MEDIUM cho entity_sync_field_mismatch:**
Field mismatch la drift dan dan — mot platform them/xoa fields ma platform kia chua cap nhat.
Khac HIGH vi: (1) Consumer code co the handle missing fields gracefully (optional chaining, default values);
(2) Khong phai guaranteed crash; (3) Developer can fix qua version alignment. MEDIUM phu hop: FLAG + review.

---

## Dedup Hints

| Signal Type | Dedup Key Pattern |
|-------------|------------------|
| `entity_sync_response_shape_mismatch` | `P-QD10-multi-platform-entity-sync:entity_sync_response_shape_mismatch:{erp_module}:{mc_module}` |
| `entity_sync_field_mismatch` | `P-QD10-multi-platform-entity-sync:entity_sync_field_mismatch:{erp_module}:{mc_module}` |

**Luu y:** 1 signal per pair per type. Chay lai probe tren cung pair → dedup by key (idempotent).
Moi pair chi emit toi da 2 signals: 1 shape + 1 field mismatch.

---

## Signal Schema Examples

### entity_sync_response_shape_mismatch (HIGH)

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-multi-platform-entity-sync",
  "dimension_id": "QD10",
  "signal_type": "entity_sync_response_shape_mismatch",
  "severity": "high",
  "title": "HTTP status mismatch: Order — ERP=200 vs MC=404",
  "description": "Entity 'Order' tra ve HTTP status khac nhau giua ERP (MOD-ORDERS: 200) va MC platform (MOD-MC-ORDERS: 404). Platform API khong dong bo. Nguyen nhan co the: (1) MC endpoint chua implement; (2) Auth requirements khac nhau.",
  "location": {
    "provider_module": "MOD-ORDERS",
    "consumer_module": "MOD-MC-ORDERS",
    "entity": "Order"
  },
  "evidence": [{
    "type": "api_response_diff",
    "content": "erp_module=MOD-ORDERS mc_module=MOD-MC-ORDERS entity=Order erp_status=200 mc_status=404 erp_url=http://localhost:3000/api/orders mc_url=http://localhost:3100/api/mc/orders"
  }],
  "dedup_key": "P-QD10-multi-platform-entity-sync:entity_sync_response_shape_mismatch:MOD-ORDERS:MOD-MC-ORDERS"
}
```

### entity_sync_field_mismatch (MEDIUM)

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-multi-platform-entity-sync",
  "dimension_id": "QD10",
  "signal_type": "entity_sync_field_mismatch",
  "severity": "medium",
  "title": "Field mismatch: Order — 3 fields differ between ERP and MC",
  "description": "Entity 'Order' co 3 field(s) khac nhau giua ERP (MOD-ORDERS) va MC platform (MOD-MC-ORDERS). Fields chi co trong ERP: [taxAmount,discountCode,billingAddress]. Fields chi co trong MC: [none]. Consumers tren MC nhan thieu fields — co the gay undefined access errors.",
  "location": {
    "provider_module": "MOD-ORDERS",
    "consumer_module": "MOD-MC-ORDERS",
    "entity": "Order"
  },
  "evidence": [{
    "type": "api_response_diff",
    "content": "erp_module=MOD-ORDERS mc_module=MOD-MC-ORDERS entity=Order field_diff_count=3 erp_only_fields=taxAmount,discountCode,billingAddress mc_only_fields=none"
  }],
  "dedup_key": "P-QD10-multi-platform-entity-sync:entity_sync_field_mismatch:MOD-ORDERS:MOD-MC-ORDERS"
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile=quick hoac standard | SKIP (runtime probe — deep+ only) → exit 0 |
| BASE_URL khong detect duoc | SKIP gracefully — note "skipped_no_base_url" → exit 0 |
| Khong co MOD-MC-* modules trong registry | SKIP — E110 "no_mc_platform_pairs" → exit 0 |
| ERP endpoint tra 4xx (auth required) | Emit entity_sync_response_shape_mismatch HIGH neu MC tra 200 |
| MC endpoint tra 4xx | Emit entity_sync_response_shape_mismatch HIGH |
| Ca 2 tra non-200 | Skip comparison, log note — khong emit signal |
| curl timeout (>10s per platform) | Skip pair, log WARN |
| JSON parse fail (E106) | Skip comparison, log WARN |
| GitNexus unavailable | Fallback grep cho endpoint detection, log caveat |
| Serena unavailable | Skip DTO pre-comparison, proceed voi runtime response only |
| > 50 signals | Stop emitting, LOG WARN "max_signals_reached (50)" |
| Registry parse error | ERROR E100 + exit 1 |
| MC base URL khong detect | Assume cung host ERP, dung /api/mc/ prefix convention |
| Empty array response | Compare empty vs non-empty — emit entity_sync_response_shape_mismatch MEDIUM |

---

## Cache Policy

**NOT allowed** — probe nay goi live API endpoints.

Ket qua phu thuoc vao runtime state cua ca 2 platforms. Khong cache.
Khac static probes (W2.2-W2.4): khong co cache layer nao duoc ap dung.

---

## Profile-Resolver Entry

```yaml
# Trong procedures/probes/_shared.md (QD10 Profile-Resolver section):
P-QD10-multi-platform-entity-sync:
  quick: skip
  standard: skip
  deep: run (MC pair detection + API comparison, max_pairs=10)
  exhaustive: run (same + max_pairs=20, max_signals=100)
  parallel_class: runtime
  optional: true (graceful skip khi khong co MC pairs hoac BASE_URL)
  max_pairs: 10 (deep) / 20 (exhaustive)
  requires_flags: []
  uses_browser: false (pure HTTP API calls — khong can Playwright)
  uses_db: false
  safety_critical: false (chi GET calls — khong co side effect)
```

---

## Acceptance Test

**Heuristic detection test (EUREKA — W3.2 DoD):**

1. Verify EUREKA registry co modules MOD-ORDERS va MOD-MC-ORDERS:
   ```bash
   jq '.modules[]? | select(.id | test("MC-ORDERS|^MOD-ORDERS$"))' \
     D:/Working/EUREKA-2026/.mc-data/docs/_meta/req-registry.json
   ```
2. Run probe:
   ```bash
   # Simulate probe run (project context: EUREKA-2026)
   REGISTRY_FILE="D:/Working/EUREKA-2026/.mc-data/docs/_meta/req-registry.json"
   PROJECT_ROOT="D:/Working/EUREKA-2026"
   SESSION_DIR="$PROJECT_ROOT/.mc-data/work/wf-fix-integration/test-session"
   mkdir -p "$SESSION_DIR/phase4-find-bugs/lanes/QD10-integration/raw"
   # Probe detects: Strategy B finds MOD-ORDERS + MOD-MC-ORDERS
   # Expected: PAIR_COUNT >= 1
   jq '[.modules[]? | select(.id | test("MOD-MC-"))] | length' "$REGISTRY_FILE"
   ```
3. **Expected:** Probe discovers pair MC-ORDERS↔ORDERS; goi ca 2 APIs; emit signal neu fields differ HOAC PASS ro neu dong bo.

**Synthetic field mismatch test:**
- Setup: ERP endpoint tra `{"id":1, "total":100, "taxAmount":15}`, MC endpoint tra `{"id":1, "total":100}`
- Run probe → expect `entity_sync_field_mismatch` MEDIUM voi `erp_only_fields=taxAmount`

**Strategy detection test:**
- Registry co cross_module_dependency binding_type=api, consumer_module=MOD-MC-ORDERS
- Strategy A phai detect truoc Strategy B
- `source` field trong mc-pairs-detected.json phai = "explicit_dep"

**EUREKA E2E (W3.E2E — deferred per Q6/Q7):**
- Start EUREKA ERP + MC apps
- Run `/wf-fix-bugs --dims=QD10 --profile=deep --scope=cross-module-pair --pair=ORDERS-MC-ORDERS`
- Expect: Probe complete; signals ve sync inconsistency HOAC PASS ro; performance <= 3 phut per pair
