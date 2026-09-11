# P-QD10-cache-staleness-probe — Kiem tra Cache Staleness / Denormalized Copy Sync

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD10-cache-staleness-probe |
| **Loai** | runtime (mutation + measurement) |
| **Profile** | exhaustive (opt-in `--test-cache-sync` — mac dinh OFF) |
| **Muc dich** | Phat hien stale data khi provider entity duoc update ma consumer denormalized copy khong sync trong thoi gian cho phep (>5s). Thuc hien: mutate provider via API PATCH → wait → poll consumer view → so sanh → emit signal neu stale. |
| **Cache** | NOT allowed (runtime mutation — ket qua khac nhau theo state) |
| **Error codes** | E100 (registry corrupt — QD10 base), E104 (production env block — mutation catastrophic), E110 (API mutation fail — mutation returned non-2xx) |
| **Side effect** | YES — probe thuc hien HTTP PATCH/PUT tren provider entity. Rollback duoc attempt sau test. Opt-in mandatory. |
| **Migrates from** | (new in v9) |

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| HTTP timing loop | `QD4 P-QD4-api-latency-probe.md` | `:68-85 (SENSE B1 curl loop)` | Reuse curl timing + response capture pattern. Thay do latency thanh poll for update (up to STALENESS_TIMEOUT). |
| curl GET response capture | `QD1 P-QD1-api-smoke.md` | `:59-81 (ACT curl)` | Reuse ERP_BODY + ERP_CODE extract pattern cho GET calls (ACT A1, A3). |
| emit_signal_runtime_integration() | `procedures/probes/_shared.md` (QD10) | `:98-133` | Signal emit voi runtime context (table/endpoint). |
| iterate_module_pairs() + binding_type filter | `procedures/probes/_shared.md` (QD10) | `:139-160` | Reuse pair iteration; filter WHERE binding_type=denormalized_copy. |
| E104 production env HARD BLOCK | `P-QD10-orphan-reference-runtime.md` | `:PRE-GATE Step 2` | Reuse exact same pattern — mutation tren production = catastrophic (P1 Safety). |
| with_runtime_cap timeout wrapper | `.claude/scripts/wf-fix-common.sh` | `:with_runtime_cap` | Enforced timeout cho moi curl call (KHONG hardcode). |
| jq_int JSON helper | `.claude/scripts/wf-fix-common.sh` | `:jq_int` | CRLF-safe JSON int extraction. |
| QD9 auth-session reuse | `procedures/probes/_shared.md` (QD10) | `_shared.md:19` | QD9_AUTH_SESSION optional var — reuse auth cookie/token de mutate. |

**Diff so voi QD4 api-latency:**
- QD4: do latency GET request (read-only, no mutation)
- W3.3: do freshness sau MUTATION (write then measure read-through; cleanup rollback; exhaustive opt-in only)
- Safety level cao hon: QD4 read-only; W3.3 PATCH/PUT → E104 block + rollback mandatory

---

## CI-ROUTE

| Task | Primary | Fallback | Ghi chu |
|------|---------|----------|---------|
| Identify cache invalidation chain | **GitNexus** `impact()` tren mutation handler symbol | Grep `cache.invalidate\|cache.del\|evict\|flush` | Tim cac function/event handle cache invalidation sau mutation |
| Locate mutation endpoint handler | **Serena** `find_symbol(update{Entity}\|patch{Entity}\|PUT handler)` | Grep `router.put\|router.patch\|@Put\|@Patch` | Tim endpoint handler de xac nhan co mutation API |
| Locate consumer read endpoint | **Serena** `find_symbol(get{Entity}\|findAll\|list{Entity})` | Grep `router.get\|@Get\|@Query` | Tim consumer view endpoint de query sau mutation |
| Xac nhan denormalized_copy deps | Registry `cross_module_dependencies[]` binding_type=denormalized_copy | Manual inspect code | PRIMARY source — registry la SSOT |

**CI-ROUTE PRE-GATE (mandatory):**
Neu khong co Serena/GitNexus → ghi chu "CI_UNAVAILABLE: using grep fallback" vao RAW output. Khong block probe execution.

---

## PRE-GATE

```bash
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD10-integration"
RAW_DIR="$LANE_DIR/raw"
SIGNALS_FILE="$LANE_DIR/signals.json"
REGISTRY_FILE=".mc-data/docs/_meta/req-registry.json"

# Step 1: Profile gate — exhaustive only
if [ "${PROFILE:-standard}" != "exhaustive" ]; then
  echo "P-QD10-cache-staleness-probe: SKIP profile=${PROFILE:-standard} (requires exhaustive)" >&2
  exit 0
fi

# Step 2: Opt-in flag gate — default OFF
if [ "${TEST_CACHE_SYNC:-0}" != "1" ] && [ "${OPT_TEST_CACHE_SYNC:-}" != "true" ]; then
  echo "P-QD10-cache-staleness-probe: SKIP opt-in flag not set (use --test-cache-sync to enable)" >&2
  echo "  WARNING: This probe performs HTTP PATCH mutations on provider entities." >&2
  echo "  Only enable after confirming test environment and rollback capability." >&2
  exit 0
fi

# Step 3: Safety warning — mutation side effect
echo "=== CACHE STALENESS PROBE: MUTATION MODE ===" >&2
echo "  This probe will PATCH provider entities and attempt rollback after test." >&2
echo "  Ensure: test environment, not production, rollback-capable API." >&2

# Step 4: E104 production env HARD BLOCK (mutation catastrophic on production)
DEPLOY_ENV="${DEPLOY_ENV:-${NODE_ENV:-${RAILS_ENV:-${APP_ENV:-}}}}"
if echo "$DEPLOY_ENV" | grep -qiE '^(production|prod|live)$'; then
  echo "E104: HARD BLOCK — DEPLOY_ENV=$DEPLOY_ENV matches production pattern. Mutation probe REFUSED." >&2
  exit 1
fi
# Additional heuristic: BASE_URL contains prod domain
if echo "${BASE_URL_ERP:-}" | grep -qiE '\.(prod|live|erktransport\.com|production)'; then
  echo "E104: HARD BLOCK — BASE_URL_ERP appears to be production URL. Mutation probe REFUSED." >&2
  exit 1
fi

# Step 5: Load BASE_URL_ERP
if [ -z "${BASE_URL_ERP:-}" ]; then
  # Try QD9 dev-server-state first
  if [ -n "${QD9_DEV_SERVER_STATE:-}" ] && [ -f "$QD9_DEV_SERVER_STATE" ]; then
    BASE_URL_ERP=$(jq -r '.primary_url // .apps[0].url // empty' "$QD9_DEV_SERVER_STATE" 2>/dev/null | tr -d '\r' || true)
  fi
  # Fallback: detect-base-url.sh
  if [ -z "$BASE_URL_ERP" ] && [ -f ".claude/scripts/wf-fix-detect-base-url.sh" ]; then
    DETECTED=$(bash .claude/scripts/wf-fix-detect-base-url.sh --project-root="${PROJECT_ROOT:-.}" 2>/dev/null || true)
    BASE_URL_ERP=$(echo "$DETECTED" | jq -r '.apps[] | select(.framework != "mobile") | .base_url' 2>/dev/null | head -1 | tr -d '\r' || true)
  fi
  if [ -z "$BASE_URL_ERP" ]; then
    echo "P-QD10-cache-staleness-probe: SKIP no BASE_URL_ERP available" >&2
    exit 0
  fi
fi

# Step 6: Check denormalized_copy deps exist
DEDUP_COUNT=$(jq -r '[.cross_module_dependencies // [] | .[] | select(.binding_type == "denormalized_copy")] | length' \
  "$REGISTRY_FILE" 2>/dev/null | tr -d '\r' || echo 0)
if [ "$DEDUP_COUNT" -lt 1 ]; then
  echo "E100: SKIP no denormalized_copy dependencies in registry. Add cross_module_dependencies[] binding_type=denormalized_copy to enable." >&2
  exit 0
fi

# Step 7: Load auth (optional — from QD9)
AUTH_HEADER=""
if [ -n "${QD9_AUTH_SESSION:-}" ] && [ -f "$QD9_AUTH_SESSION" ]; then
  TOKEN=$(jq -r '.token // .access_token // empty' "$QD9_AUTH_SESSION" 2>/dev/null | tr -d '\r' || true)
  COOKIE=$(jq -r '.cookie // empty' "$QD9_AUTH_SESSION" 2>/dev/null | tr -d '\r' || true)
  if [ -n "$TOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $TOKEN"
  elif [ -n "$COOKIE" ]; then
    AUTH_HEADER="Cookie: $COOKIE"
  fi
fi

# Step 8: Init directories
mkdir -p "$RAW_DIR"
[ -f "$SIGNALS_FILE" ] || echo '[]' > "$SIGNALS_FILE"

# Step 9: CI tool detection (non-blocking)
CI_AVAILABLE=false
if command -v serena &>/dev/null 2>&1; then CI_AVAILABLE=true; fi

echo "P-QD10-cache-staleness-probe: PRE-GATE OK — BASE_URL=$BASE_URL_ERP dedup_pairs=$DEDUP_COUNT auth=$([ -n "$AUTH_HEADER" ] && echo "yes" || echo "no")" >&2
```

---

## SENSE

### S1: Load denormalized_copy pairs from registry

```bash
PAIR_PAIRS=()  # array of "consumer_module:provider_module:entity"

# REUSE iterate_module_pairs pattern (_shared.md:139-160) — filter denormalized_copy
while IFS=$'\t' read -r consumer_module provider_module entity; do
  # CRLF fix (Windows jq)
  consumer_module=$(echo "$consumer_module" | tr -d '\r')
  provider_module=$(echo "$provider_module" | tr -d '\r')
  entity=$(echo "$entity" | tr -d '\r')
  [ -z "$consumer_module" ] && continue
  PAIR_PAIRS+=("${consumer_module}:${provider_module}:${entity}")
done < <(jq -r --argjson max "${MAX_PAIRS:-5}" \
  '[.cross_module_dependencies // [] | .[] |
    select(.binding_type == "denormalized_copy") |
    [.consumer_module, .provider_module, (.entity // "Unknown")]] |
   .[:$max][] | @tsv' \
  "$REGISTRY_FILE" 2>/dev/null || true)

if [ "${#PAIR_PAIRS[@]}" -eq 0 ]; then
  echo "P-QD10-cache-staleness-probe: SENSE S1 — 0 denormalized_copy pairs loaded (registry empty post-load)" >&2
  exit 0
fi
echo "P-QD10-cache-staleness-probe: SENSE S1 — ${#PAIR_PAIRS[@]} pairs loaded" >&2
```

MAX_PAIRS default: exhaustive=5 (mutation is slow; cap at 5 to stay within time budget).

### S2: Endpoint detection per pair

Per pair, detect provider mutation endpoint and consumer read endpoint:

```bash
detect_endpoints() {
  local entity="$1"       # e.g. "Customer"
  local provider_mod="$2" # e.g. "MOD-CRM"
  local consumer_mod="$3" # e.g. "MOD-QUOTATION"

  # Derive slug from entity name (e.g. Customer → customers)
  local entity_slug
  entity_slug=$(echo "$entity" | sed 's/\([A-Z]\)/-\1/g' | sed 's/^-//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
  local entity_plural="${entity_slug}s"

  # CI PRIMARY: Serena find_symbol(update{Entity}) → extract URL from handler
  # (manual step — recorded in CI-ROUTE table; probe uses heuristic if CI absent)

  # Heuristic fallback: convention-based endpoints
  local provider_slug
  provider_slug=$(echo "$provider_mod" | sed 's/^MOD-//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
  local consumer_slug
  consumer_slug=$(echo "$consumer_mod" | sed 's/^MOD-//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')

  # Provider mutation endpoint (PATCH preferred; fallback PUT)
  PROVIDER_LIST_URL="${BASE_URL_ERP}/api/${entity_plural}"
  PROVIDER_PATCH_URL="${BASE_URL_ERP}/api/${entity_plural}"  # + /{id} appended after entity lookup

  # Consumer read endpoint (consumer module slug)
  CONSUMER_READ_URL="${BASE_URL_ERP}/api/${consumer_slug}/${entity_plural}"
  # Alternative: same base, different path prefix
  CONSUMER_READ_URL_ALT="${BASE_URL_ERP}/api/${entity_plural}"

  echo "P-QD10-cache-staleness-probe: S2 entity=$entity provider_list=$PROVIDER_LIST_URL consumer_read=$CONSUMER_READ_URL" >&2
}
```

### S3: Staleness threshold configuration

```bash
STALENESS_THRESHOLD_MS="${CACHE_STALENESS_THRESHOLD_MS:-5000}"  # 5s default
STALENESS_TIMEOUT_MS="${CACHE_STALENESS_TIMEOUT_MS:-10000}"    # 10s max poll window
POLL_INTERVAL_MS="${CACHE_POLL_INTERVAL_MS:-500}"              # 500ms between polls
MUTATE_FIELD="${CACHE_MUTATE_FIELD:-}"  # Optional override: which field to mutate
```

---

## THINK

Per pair, build mutation + comparison plan:

```
MUTATION PLAN:
1. field_to_mutate: prefer 'notes' or 'description' (low-impact, string field)
   - If MUTATE_FIELD env set → use that
   - Else: try 'notes', 'description', 'remarks', 'comments' in order
   - Fallback: skip pair with warn "no safe mutation field detected"
2. test_value: "cache-staleness-test-" + timestamp (unique to detect)
3. mutation_method: PATCH (preferred) → fallback PUT
4. entity_id: GET provider list → take first item's id field
5. original_value: capture BEFORE mutation for rollback

COMPARISON PLAN:
1. consumer_endpoint: try CONSUMER_READ_URL first → fallback CONSUMER_READ_URL_ALT
2. comparison_strategy: jq path search for entity.field_to_mutate in consumer response
   - If response is array → search items[].field_to_mutate
   - If response is object → consumer_response.field_to_mutate or consumer_response.{entity}.field_to_mutate
3. detection: field value == test_value → SYNCED (compute staleness = T1 - T0)
   field value == original_value after 10s → STALE (cache_staleness_detected)
   field not found in consumer response → cache_sync_missing

CI AUGMENTATION:
- GitNexus impact(mutation_handler) → trace cache invalidation chain
  If chain exists → note "cache_invalidation_chain: [symbols]" in evidence
  If chain absent → high confidence cache_sync_missing (no code path to invalidate)
```

---

## ACT

### A0: Pre-mutation audit log

```bash
AUDIT_LOG="$RAW_DIR/P-QD10-cache-staleness-audit.jsonl"
echo '{"event":"probe_start","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","env":"'"${DEPLOY_ENV:-unknown}"'","base_url":"'"$BASE_URL_ERP"'"}' >> "$AUDIT_LOG"
```

### A1: Capture original value + entity ID

Per pair:

```bash
act_capture_original() {
  local provider_list_url="$1"
  local field="$2"

  # GET provider entity list (REUSE QD1 api-smoke:59-81 curl pattern)
  local LIST_HTTP
  LIST_HTTP=$(with_runtime_cap 10 curl -s -w "\n%{http_code}" \
    -H "Accept: application/json" \
    ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
    "$provider_list_url" --max-time 10 2>/dev/null \
    || echo -e "\n000")
  local LIST_BODY LIST_CODE
  LIST_BODY=$(echo "$LIST_HTTP" | head -n -1)
  LIST_CODE=$(echo "$LIST_HTTP" | tail -1 | tr -d '[:space:]')

  if [ "$LIST_CODE" = "000" ] || [ "$LIST_CODE" -lt 200 ] || [ "$LIST_CODE" -ge 300 ] 2>/dev/null; then
    echo "  WARN: provider list GET failed code=$LIST_CODE — skipping pair" >&2
    echo ""  # empty entity_id signals skip
    return
  fi

  # Extract first entity ID
  ENTITY_ID=$(echo "$LIST_BODY" | jq -r \
    'if type == "array" then .[0].id // .[0]._id // .[0].uuid // empty
     elif .data | type == "array" then .data[0].id // .data[0]._id // empty
     elif .results | type == "array" then .results[0].id // .results[0]._id // empty
     else .id // ._id // empty end' 2>/dev/null | tr -d '\r' || true)

  if [ -z "$ENTITY_ID" ]; then
    echo "  WARN: cannot extract entity ID from provider list — skipping pair" >&2
    echo ""
    return
  fi

  # Extract original field value
  ORIGINAL_VALUE=$(echo "$LIST_BODY" | jq -r \
    --arg field "$field" \
    'if type == "array" then .[0][$field] // ""
     elif .data | type == "array" then .data[0][$field] // ""
     else .[$field] // "" end' 2>/dev/null | tr -d '\r' || true)

  echo "$ENTITY_ID|$ORIGINAL_VALUE"
}
```

### A2: Mutate via PATCH

```bash
act_mutate() {
  local patch_url="$1"  # e.g. /api/customers/42
  local field="$2"
  local test_value="$3"

  local PATCH_HTTP
  PATCH_HTTP=$(with_runtime_cap 15 curl -s -w "\n%{http_code}" \
    -X PATCH \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
    -d "{\"${field}\": \"${test_value}\"}" \
    "$patch_url" --max-time 15 2>/dev/null \
    || echo -e "\n000")
  local PATCH_CODE
  PATCH_CODE=$(echo "$PATCH_HTTP" | tail -1 | tr -d '[:space:]')

  if [ "$PATCH_CODE" = "000" ] || [ "$PATCH_CODE" -lt 200 ] || [ "$PATCH_CODE" -ge 300 ] 2>/dev/null; then
    echo "E110: mutation PATCH failed code=$PATCH_CODE url=$patch_url" >&2
    echo "fail"
    return
  fi

  echo "$PATCH_CODE"
}
```

### A3: Poll consumer view for sync (REUSE QD4 latency loop pattern :68-85)

```bash
act_poll_consumer() {
  local consumer_url="$1"
  local field="$2"
  local test_value="$3"
  local timeout_ms="$4"
  local interval_ms="$5"
  local t0="$6"  # Unix ms

  local elapsed=0
  local interval_s
  interval_s=$(echo "scale=3; $interval_ms / 1000" | bc -l 2>/dev/null || echo "0.5")

  while [ "$elapsed" -le "$timeout_ms" ]; do
    # GET consumer view (REUSE QD1 api-smoke:59-81)
    local GET_HTTP
    GET_HTTP=$(with_runtime_cap 10 curl -s -w "\n%{http_code}" \
      -H "Accept: application/json" \
      ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
      "$consumer_url" --max-time 10 2>/dev/null \
      || echo -e "\n000")
    local GET_BODY GET_CODE
    GET_BODY=$(echo "$GET_HTTP" | head -n -1)
    GET_CODE=$(echo "$GET_HTTP" | tail -1 | tr -d '[:space:]')

    if [ "$GET_CODE" != "000" ] && [ "$GET_CODE" -ge 200 ] && [ "$GET_CODE" -lt 300 ] 2>/dev/null; then
      # Check if field in consumer response matches test_value
      local found_value
      found_value=$(echo "$GET_BODY" | jq -r \
        --arg field "$field" --arg tv "$test_value" \
        '(if type == "array" then .[0]
         elif .data | type == "array" then .data[0]
         elif .results | type == "array" then .results[0]
         else . end) | .[$field] // ""' 2>/dev/null | tr -d '\r' || true)

      if [ "$found_value" = "$test_value" ]; then
        # Synced! Compute staleness
        local t1
        t1=$(date +%s%N 2>/dev/null | head -c 13 || python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
        local staleness_ms=$(( t1 - t0 ))
        echo "synced:$staleness_ms"
        return
      fi
    fi

    sleep "$interval_s" 2>/dev/null || true
    elapsed=$(( elapsed + interval_ms ))
  done

  echo "timeout:$timeout_ms"
}
```

### A4: Emit signals based on poll result

```bash
act_emit_signals() {
  local pair_str="$1"      # "consumer:provider:entity"
  local result_str="$2"    # "synced:1234" or "timeout:10000" or "field_not_found"
  local consumer_url="$3"
  local provider_patch_url="$4"
  local field="$5"
  local test_value="$6"

  local consumer_module provider_module entity
  IFS=':' read -r consumer_module provider_module entity <<< "$pair_str"

  if echo "$result_str" | grep -q "^synced:"; then
    local staleness_ms="${result_str#synced:}"
    if [ "$staleness_ms" -gt "$STALENESS_THRESHOLD_MS" ]; then
      # cache_staleness_detected MEDIUM — REUSE emit_signal_runtime_integration (_shared.md:98-133)
      emit_signal_runtime_integration \
        "P-QD10-cache-staleness-probe" \
        "cache_staleness_detected" \
        "medium" \
        "Cache staleness ${consumer_module}←${provider_module}: ${entity} stale ${staleness_ms}ms (threshold ${STALENESS_THRESHOLD_MS}ms)" \
        "Consumer ${consumer_module} denormalized copy of ${entity} from ${provider_module} took ${staleness_ms}ms to sync after provider mutation (threshold: ${STALENESS_THRESHOLD_MS}ms = 5s)" \
        "api_response_diff" \
        "mutation field=${field} at ${provider_patch_url}; consumer ${consumer_url} updated after ${staleness_ms}ms (>${STALENESS_THRESHOLD_MS}ms threshold)" \
        "{\"consumer_module\": \"$consumer_module\", \"provider_module\": \"$provider_module\", \"entity\": \"$entity\", \"consumer_endpoint\": \"$consumer_url\", \"provider_endpoint\": \"$provider_patch_url\", \"staleness_ms\": $staleness_ms, \"threshold_ms\": $STALENESS_THRESHOLD_MS}"
    fi
    # else: synced within threshold — no signal (PASS)

  elif echo "$result_str" | grep -q "^timeout:"; then
    # cache_sync_missing HIGH — consumer never updated within STALENESS_TIMEOUT
    emit_signal_runtime_integration \
      "P-QD10-cache-staleness-probe" \
      "cache_sync_missing" \
      "high" \
      "Cache sync MISSING ${consumer_module}←${provider_module}: ${entity} never updated after ${STALENESS_TIMEOUT_MS}ms" \
      "Consumer ${consumer_module} denormalized copy of ${entity} from ${provider_module} was NOT updated within ${STALENESS_TIMEOUT_MS}ms after provider mutation. Possible missing cache invalidation handler or event subscription." \
      "api_response_diff" \
      "mutation field=${field} at ${provider_patch_url}; consumer ${consumer_url} polled ${STALENESS_TIMEOUT_MS}ms — field never changed from original value" \
      "{\"consumer_module\": \"$consumer_module\", \"provider_module\": \"$provider_module\", \"entity\": \"$entity\", \"consumer_endpoint\": \"$consumer_url\", \"timeout_ms\": $STALENESS_TIMEOUT_MS}"

  elif [ "$result_str" = "field_not_found" ]; then
    # cache_sync_missing HIGH — consumer response does not contain the field at all
    emit_signal_runtime_integration \
      "P-QD10-cache-staleness-probe" \
      "cache_sync_missing" \
      "high" \
      "Cache field ABSENT ${consumer_module}←${provider_module}: ${entity}.${field} not in consumer response" \
      "Consumer ${consumer_module} response does not expose field '${field}' from ${provider_module} ${entity}. Denormalized copy may not be implemented or field mapping is incorrect." \
      "api_response_diff" \
      "consumer ${consumer_url} response missing field=${field} (expected to expose provider ${entity}.${field} via denormalized copy)" \
      "{\"consumer_module\": \"$consumer_module\", \"provider_module\": \"$provider_module\", \"entity\": \"$entity\", \"missing_field\": \"$field\", \"consumer_endpoint\": \"$consumer_url\"}"
  fi
}
```

### A5: Rollback — restore original value

```bash
act_rollback() {
  local patch_url="$1"
  local field="$2"
  local original_value="$3"

  echo "  ROLLBACK: restoring ${field}='${original_value}' at ${patch_url}" >&2

  local ROLLBACK_HTTP
  ROLLBACK_HTTP=$(with_runtime_cap 15 curl -s -w "\n%{http_code}" \
    -X PATCH \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
    -d "{\"${field}\": \"${original_value}\"}" \
    "$patch_url" --max-time 15 2>/dev/null \
    || echo -e "\n000")
  local ROLLBACK_CODE
  ROLLBACK_CODE=$(echo "$ROLLBACK_HTTP" | tail -1 | tr -d '[:space:]')

  if [ "$ROLLBACK_CODE" = "000" ] || [ "$ROLLBACK_CODE" -lt 200 ] || [ "$ROLLBACK_CODE" -ge 300 ] 2>/dev/null; then
    echo "  WARN: rollback FAILED code=$ROLLBACK_CODE — entity ${patch_url} may have test value '${original_value}' persisted" >&2
    echo "fail:$ROLLBACK_CODE"
  else
    echo "  ROLLBACK: OK (code=$ROLLBACK_CODE)" >&2
    echo "ok:$ROLLBACK_CODE"
  fi
}
```

### A6: Per-pair main loop

```bash
pairs_analyzed=0
pairs_clean=0
pairs_stale=0
pairs_missing=0
pairs_error=0
signals_emitted=0
rollback_success=0
rollback_fail=0

SAFE_MUTATION_FIELDS=("notes" "description" "remarks" "comments" "internal_notes")

for pair_str in "${PAIR_PAIRS[@]}"; do
  IFS=':' read -r consumer_module provider_module entity <<< "$pair_str"
  pairs_analyzed=$(( pairs_analyzed + 1 ))

  detect_endpoints "$entity" "$provider_module" "$consumer_module"

  # Step 1: Detect safe mutation field
  target_field="${MUTATE_FIELD:-}"
  if [ -z "$target_field" ]; then
    for f in "${SAFE_MUTATION_FIELDS[@]}"; do
      # Try GET to see if field exists in provider list response
      PROBE_HTTP=$(with_runtime_cap 5 curl -s -w "\n%{http_code}" \
        -H "Accept: application/json" ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
        "$PROVIDER_LIST_URL" --max-time 5 2>/dev/null || echo -e "\n000")
      PROBE_BODY=$(echo "$PROBE_HTTP" | head -n -1)
      field_check=$(echo "$PROBE_BODY" | jq -r \
        --arg f "$f" \
        'if type == "array" then (.[0] | has($f)) elif .data | type == "array" then (.data[0] | has($f)) else has($f) end' \
        2>/dev/null | tr -d '\r' || echo "false")
      if [ "$field_check" = "true" ]; then
        target_field="$f"
        break
      fi
    done
  fi

  if [ -z "$target_field" ]; then
    echo "  WARN: no safe mutation field detected for ${entity} — skipping pair ${consumer_module}←${provider_module}" >&2
    pairs_error=$(( pairs_error + 1 ))
    continue
  fi

  # Step 2: Capture original value + entity ID
  id_and_value=$(act_capture_original "$PROVIDER_LIST_URL" "$target_field")
  if [ -z "$id_and_value" ]; then
    pairs_error=$(( pairs_error + 1 ))
    continue
  fi
  ENTITY_ID="${id_and_value%%|*}"
  ORIGINAL_VALUE="${id_and_value#*|}"

  PATCH_URL="${PROVIDER_LIST_URL}/${ENTITY_ID}"
  TEST_VALUE="cache-staleness-test-$(date +%s)"

  # Step 3: Audit log mutation intent
  echo '{"event":"mutation_intent","pair":"'"$pair_str"'","entity_id":"'"$ENTITY_ID"'","field":"'"$target_field"'","patch_url":"'"$PATCH_URL"'","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' >> "$AUDIT_LOG"

  # Step 4: Mutate
  t0=$(date +%s%N 2>/dev/null | head -c 13 || python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
  mutate_result=$(act_mutate "$PATCH_URL" "$target_field" "$TEST_VALUE")

  if [ "$mutate_result" = "fail" ]; then
    pairs_error=$(( pairs_error + 1 ))
    echo '{"event":"mutation_failed","pair":"'"$pair_str"'","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' >> "$AUDIT_LOG"
    continue
  fi

  # Step 5: Poll consumer
  poll_result=$(act_poll_consumer "$CONSUMER_READ_URL" "$target_field" "$TEST_VALUE" \
    "$STALENESS_TIMEOUT_MS" "$POLL_INTERVAL_MS" "$t0")

  # Step 6: Check if field_not_found (consumer response lacks the field)
  if echo "$poll_result" | grep -q "^timeout:"; then
    # Check if field actually exists in consumer response (vs truly stale)
    CONSUMER_CHECK=$(with_runtime_cap 5 curl -s \
      -H "Accept: application/json" ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
      "$CONSUMER_READ_URL" --max-time 5 2>/dev/null || true)
    field_present=$(echo "$CONSUMER_CHECK" | jq -r \
      --arg f "$target_field" \
      'if type == "array" then (.[0] | has($f)) elif .data | type == "array" then (.data[0] | has($f)) else has($f) end' \
      2>/dev/null | tr -d '\r' || echo "false")
    if [ "$field_present" = "false" ]; then
      poll_result="field_not_found"
    fi
  fi

  # Step 7: Emit signals
  act_emit_signals "$pair_str" "$poll_result" "$CONSUMER_READ_URL" "$PATCH_URL" \
    "$target_field" "$TEST_VALUE"

  # Track stats
  if echo "$poll_result" | grep -q "^synced:"; then
    staleness_ms="${poll_result#synced:}"
    if [ "$staleness_ms" -gt "$STALENESS_THRESHOLD_MS" ]; then
      pairs_stale=$(( pairs_stale + 1 ))
      signals_emitted=$(( signals_emitted + 1 ))
    else
      pairs_clean=$(( pairs_clean + 1 ))
    fi
  else
    pairs_missing=$(( pairs_missing + 1 ))
    signals_emitted=$(( signals_emitted + 1 ))
  fi

  # Step 8: Rollback (always attempt — P1 Safety)
  echo '{"event":"rollback_intent","pair":"'"$pair_str"'","entity_id":"'"$ENTITY_ID"'","original_value":"'"$ORIGINAL_VALUE"'","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' >> "$AUDIT_LOG"
  rollback_result=$(act_rollback "$PATCH_URL" "$target_field" "$ORIGINAL_VALUE")
  if echo "$rollback_result" | grep -q "^ok:"; then
    rollback_success=$(( rollback_success + 1 ))
    echo '{"event":"rollback_ok","pair":"'"$pair_str"'","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' >> "$AUDIT_LOG"
  else
    rollback_fail=$(( rollback_fail + 1 ))
    echo '{"event":"rollback_failed","pair":"'"$pair_str"'","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' >> "$AUDIT_LOG"
    echo "  CRITICAL WARN: rollback failed for ${pair_str} — manual check required" >&2
  fi
done
```

### A7: Write summary JSON

```bash
SUMMARY_FILE="$RAW_DIR/P-QD10-cache-staleness-summary.json"
jq -n \
  --argjson analyzed "$pairs_analyzed" \
  --argjson clean "$pairs_clean" \
  --argjson stale "$pairs_stale" \
  --argjson missing "$pairs_missing" \
  --argjson error "$pairs_error" \
  --argjson signals "$signals_emitted" \
  --argjson rollback_ok "$rollback_success" \
  --argjson rollback_fail "$rollback_fail" \
  --arg threshold_ms "${STALENESS_THRESHOLD_MS}" \
  --arg timeout_ms "${STALENESS_TIMEOUT_MS}" \
  --arg base_url "$BASE_URL_ERP" \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    probe_id: "P-QD10-cache-staleness-probe",
    dimension: "QD10",
    generated_at: $now,
    base_url: $base_url,
    thresholds: {staleness_ms: $threshold_ms, timeout_ms: $timeout_ms},
    pairs_analyzed: $analyzed,
    pairs_clean: $clean,
    pairs_stale: $stale,
    pairs_sync_missing: $missing,
    pairs_error: $error,
    signals_emitted: $signals,
    rollback: {success: $rollback_ok, failed: $rollback_fail}
  }' > "$SUMMARY_FILE"

echo "P-QD10-cache-staleness-probe: DONE analyzed=$pairs_analyzed clean=$pairs_clean stale=$pairs_stale missing=$pairs_missing signals=$signals_emitted rollback_ok=$rollback_success rollback_fail=$rollback_fail" >&2
```

---

## VERIFY

10-item per-probe DoD checklist:

1. **Profile gate enforced** — probe exits 0 with note khi profile != exhaustive
2. **Opt-in gate enforced** — probe exits 0 with warning khi --test-cache-sync NOT set
3. **E104 hard block** — probe exits 1 khi DEPLOY_ENV matches production pattern (test via echo 'production' to DEPLOY_ENV)
4. **E104 URL heuristic** — probe exits 1 khi BASE_URL_ERP contains `.prod` or `.live` domain
5. **Rollback always attempted** — EVERY successful mutation has a corresponding rollback attempt (verify audit log pairs)
6. **cache_staleness_detected severity=MEDIUM** — stale but eventually synced
7. **cache_sync_missing severity=HIGH** — never synced or field absent
8. **Evidence includes timing** — t0/t1/staleness_ms or timeout_ms in evidence content
9. **Dedup key format correct** — `P-QD10-cache-staleness-probe:{signal_type}:{consumer}:{provider}` per pair
10. **SIGNALS_FILE is valid JSON array after probe** — `jq '.' "$SIGNALS_FILE"` exits 0

---

## Severity Rules

| Pattern | Severity | Rationale |
|---------|----------|-----------|
| Consumer syncs but stale > 5s | MEDIUM | Data eventually consistent — user may see stale data briefly; requires cache tuning |
| Consumer never updates within 10s | HIGH | Silent stale data — user cannot see provider updates; possible missing event handler |
| Consumer response missing field entirely | HIGH | Denormalized copy not implemented or field mapping wrong — functional gap |
| Mutation API fails (E110) | SKIP pair | Cannot measure staleness without mutation; log E110, continue to next pair |

---

## Dedup Hints

| Signal type | Dedup key pattern |
|-------------|------------------|
| `cache_staleness_detected` | `P-QD10-cache-staleness-probe:cache_staleness_detected:{consumer_module}:{provider_module}` (1 per pair) |
| `cache_sync_missing` | `P-QD10-cache-staleness-probe:cache_sync_missing:{consumer_module}:{provider_module}` (1 per pair) |

---

## Signal Schema Examples

**cache_staleness_detected (MEDIUM):**

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-cache-staleness-probe",
  "dimension_id": "QD10",
  "signal_type": "cache_staleness_detected",
  "severity": "medium",
  "title": "Cache staleness MOD-QUOTATION←MOD-CRM: Customer stale 7200ms (threshold 5000ms)",
  "description": "Consumer MOD-QUOTATION denormalized copy of Customer from MOD-CRM took 7200ms to sync after provider mutation (threshold: 5000ms = 5s)",
  "location": {
    "consumer_module": "MOD-QUOTATION",
    "provider_module": "MOD-CRM",
    "entity": "Customer",
    "consumer_endpoint": "http://localhost:3000/api/quotation/customers",
    "provider_endpoint": "http://localhost:3000/api/customers/42",
    "staleness_ms": 7200,
    "threshold_ms": 5000
  },
  "evidence": [{
    "type": "api_response_diff",
    "content": "mutation field=notes at /api/customers/42; consumer /api/quotation/customers updated after 7200ms (>5000ms threshold)"
  }],
  "dedup_key": "P-QD10-cache-staleness-probe:cache_staleness_detected:MOD-QUOTATION:MOD-CRM"
}
```

**cache_sync_missing (HIGH):**

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-cache-staleness-probe",
  "dimension_id": "QD10",
  "signal_type": "cache_sync_missing",
  "severity": "high",
  "title": "Cache sync MISSING MOD-QUOTATION←MOD-CRM: Customer never updated after 10000ms",
  "description": "Consumer MOD-QUOTATION denormalized copy of Customer from MOD-CRM was NOT updated within 10000ms after provider mutation. Possible missing cache invalidation handler or event subscription.",
  "location": {
    "consumer_module": "MOD-QUOTATION",
    "provider_module": "MOD-CRM",
    "entity": "Customer",
    "consumer_endpoint": "http://localhost:3000/api/quotation/customers",
    "timeout_ms": 10000
  },
  "evidence": [{
    "type": "api_response_diff",
    "content": "mutation field=notes at /api/customers/42; consumer /api/quotation/customers polled 10000ms — field never changed from original value"
  }],
  "dedup_key": "P-QD10-cache-staleness-probe:cache_sync_missing:MOD-QUOTATION:MOD-CRM"
}
```

---

## Fallback Table

| Situation | Behavior |
|-----------|----------|
| Profile != exhaustive | SKIP exit 0 — note "profile_not_exhaustive" |
| `--test-cache-sync` NOT set | SKIP exit 0 — print mutation warning to stderr |
| DEPLOY_ENV = production | E104 HARD BLOCK exit 1 — no mutation attempted |
| BASE_URL_ERP contains prod domain | E104 HARD BLOCK exit 1 |
| BASE_URL_ERP not available | SKIP exit 0 — note "no_base_url" |
| No denormalized_copy deps in registry | SKIP exit 0 — E100 note |
| Auth not available (QD9 session absent) | Continue without auth header — APIs may return 401 (log E110 per call) |
| Provider list GET fails | Skip pair — note "provider_list_fail" |
| Cannot find entity ID in list | Skip pair — note "no_entity_id" |
| No safe mutation field detected | Skip pair — note "no_mutation_field" |
| PATCH mutation fails (E110) | Skip pair — log E110, no rollback needed |
| Rollback fails | WARN stderr — audit log entry "rollback_failed"; probe continues (data may be dirty) |
| Consumer read endpoint 404 | Try CONSUMER_READ_URL_ALT; if both fail → "field_not_found" → cache_sync_missing HIGH |
| jq not available | SKIP probe — note "jq_unavailable" |
| bc not available (Windows) | Use python3 fallback for timestamp math; log "no_bc" |

---

## Cache Policy

**NOT allowed.** Probe thuc hien mutation runtime — ket qua thay doi theo state cua system. Moi lan chay phai do lai.
Set `CACHE_TTL=0` neu cache framework duoc load.

---

## Profile-Resolver Entry

```yaml
probe: P-QD10-cache-staleness-probe
class: runtime        # sequential (cannot parallelize — mutation then poll)
profiles:
  quick: SKIP
  standard: SKIP
  deep: SKIP
  exhaustive:
    run: true
    opt_in: "--test-cache-sync"   # Must be explicitly set
    max_pairs: 5
uses_browser: false
requires_db: false
requires_api: true    # HTTP PATCH + GET
mutation: true        # Side effect — rollback attempted
parallel_safe: false  # Sequential only (mutation + poll sequence)
```

---

## Acceptance Tests

### Test 1: Opt-in flag not set → SKIP

```bash
# Setup
unset TEST_CACHE_SYNC
unset OPT_TEST_CACHE_SYNC
PROFILE=exhaustive

# Run
bash procedures/probes/P-QD10-cache-staleness-probe.md 2>&1 | grep -i skip

# Expected
# "SKIP opt-in flag not set"
# Exit code: 0
# No signals emitted
```

### Test 2: Production env → E104 HARD BLOCK

```bash
# Setup
DEPLOY_ENV=production
TEST_CACHE_SYNC=1
PROFILE=exhaustive

# Expected
# "E104: HARD BLOCK"
# Exit code: 1
# No mutation attempted (verify audit log is empty or not created)
```

### Test 3: Synthetic denormalized_copy → detect cache_sync_missing

```bash
# Setup: registry has denormalized_copy dep MOD-QUOTATION←MOD-CRM entity=Customer
# Provider /api/customers: returns [{id: "1", notes: "original"}]
# Consumer /api/quotation/customers: returns [{notes: "original"}] and NEVER updates
# TEST_CACHE_SYNC=1, PROFILE=exhaustive, DEPLOY_ENV=test

# Run probe

# Expected:
# signals.json has cache_sync_missing HIGH for MOD-QUOTATION←MOD-CRM
# audit log shows: mutation_intent, rollback_intent, rollback_ok entries
# summary.json: pairs_sync_missing=1, rollback.success=1
```

### Test 4: EUREKA acceptance (manual — requires test environment)

```bash
# Pre-condition: EUREKA-2026 dev env running; DEPLOY_ENV=development
# Registry seeded with denormalized_copy dep (e.g., MOD-QUOTATION←MOD-CRM Customer)
# --test-cache-sync set

# Run: /wf-fix-bugs --dims=QD10 --profile=exhaustive --test-cache-sync --scope=cross-module

# Expected:
# Update customer notes in CRM → quotation list reflects update within 5s → pairs_clean++
# OR probe detects staleness/missing → signals emitted with timing evidence
```
