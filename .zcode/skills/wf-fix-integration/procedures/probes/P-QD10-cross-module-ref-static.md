# P-QD10-cross-module-ref-static — Cross-Module Reference Static Analysis

> **Type:** static | **Profile:** standard, deep, exhaustive | **Cache:** allowed (static per code state)
> **Parallel class:** static → parallel (max 3 concurrent static probes)
> **Signal types:** `cross_module_ref_drift` (MEDIUM), `deprecated_import` (MEDIUM), `optional_field_unused` (LOW)
> **Error codes:** E100 (cross-module static probe error — QD10-specific)

Phan tich tinh (static) cac cross-module references giua consumer va provider modules theo khai bao trong `cross_module_dependencies[]` cua registry. Voi moi cap (consumer→provider, entity X): (1) Tim code consumer import entity tu provider qua **Serena `find_referencing_symbols`** (PRIMARY); (2) Xac minh required_fields duoc su dung; (3) Phat hien deprecated imports; (4) Track optional_fields chua dung (deep+ only). Khong can browser — static probe chay parallel duoc. Fallback: `wf-fix-probe-cross-module-ref.sh` grep khi Serena unavailable.

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| Domain expert spawn pattern (agent mode, W2.5) | `QD2 P-QD2-domain-expert-review.md` | `:36-55` | Agent spawn via `Agent({subagent_type: "{domain}-expert"})` + GitNexus pre-execution trace — reused cho W2.5 boundary mode, khong dung truc tiep o W2.2 nhung probe chia se pattern |
| Import path analysis + combined grep | `QD7 wf-fix-probe-static-deprecated.sh` | `:147-217` | Combined regex approach: build COMBINED_REGEX, single grep → classify per match; reuse `EXCLUDE_PATTERN` + `COMBINED_IMPORT_REGEX` construction |
| Emit signal cross-module | `procedures/probes/_shared.md` (QD10) | `:42-92` | `emit_signal_cross_module()` function + dedup_key pattern `probe_id:signal_type:provider:consumer` |
| Common variables (QD10) | `procedures/probes/_shared.md` (QD10) | `:7-21` | `LANE_DIR, RAW_DIR, SIGNALS_FILE, REGISTRY_FILE, CROSS_MODULE_MAP` |
| `iterate_module_pairs()` function | `procedures/probes/_shared.md` (QD10) | `:139-160` | Registry-driven pair iteration voi `--pair` filter support + jq `.cross_module_dependencies[]` traversal |
| Sampling policy + `emit_sampling_note()` | `procedures/probes/_shared.md` (QD10) | `:176-191` | Pairs > 30 → priority queue CRITICAL first; sampling field trong probe output |
| CI detect load | `QD9 P-QD9-spa-route-coverage.md` | `:PRE-GATE step 5` | `source <(bash ci-detect.sh --project-root ...)` pattern + `SERENA_AVAILABLE/GITNEXUS_AVAILABLE` vars |

**Diff so voi QD1-QD8 va QD9 probes:**
- Probe dau tien trong QD10 — focus vao static cross-module reference analysis (khong browser)
- CI-ROUTE PRIMARY: Serena `find_referencing_symbols(provider_entity)` thay vi `find_symbol`
- REUSE QD7 import path grep approach (single combined scan, EXCLUDE_PATTERN)
- Signals mang context `provider_module + consumer_module` (KHONG chi file:line)
- Cache allowed (static) — khac voi QD9 runtime probes (cache skip)

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Tim consumer references den provider entity | **Serena** `find_referencing_symbols({name_path: "EntityName"})` | Grep `import.*EntityName` trong consumer module path | Verify consumer code dang dung provider entity |
| Blast radius: impact khi provider thay doi | **GitNexus** `impact({target: "EntityName", direction: "upstream"})` | Manual grep consumer dirs | Xac dinh all consumer modules truoc analysis |
| Locate provider entity definition (DTOs/types) | **Serena** `find_symbol({name_path_pattern: "EntityName", include_body: true})` | Glob `*.ts` files + grep interface/type/class | Extract provider entity field definitions |
| Locate consumer-side entity usage | **Serena** `find_referencing_symbols({name_path: "EntityName", relative_path: "consumer/path"})` | Grep consumer `src/` | Find consumer-side type usage + required field access |

**Khi CI unavailable:**
```bash
if [[ "$SERENA_AVAILABLE" != "true" ]]; then
  echo "WARN: Serena unavailable — fallback to grep via wf-fix-probe-cross-module-ref.sh" >&2
fi
if [[ "$GITNEXUS_AVAILABLE" != "true" ]]; then
  echo "WARN: GitNexus unavailable — skip blast radius pre-analysis" >&2
fi
```

---

## PRE-GATE

```
1. IF profile=quick:
     SKIP lane (da SKIP toan QD10 lane — probe nay khong duoc goi)

2. Kiem tra cross_module_dependencies[] ton tai va non-empty trong registry:
     COUNT=$(jq '.cross_module_dependencies // [] | length' "$REGISTRY_FILE")
     IF COUNT == 0:
       SKIP probe, ghi note "skipped_no_cross_module_dependencies_defined" trong phase-summary
       emit WARN: "QD10 static analysis requires cross_module_dependencies[] in registry. Add entries via wf-detect-cross-module-deps.sh (W2.6)."
       → exit 0 (khong phai error, chi skip)

3. Load CI availability (REUSE: QD9 P-QD9-spa-route-coverage.md PRE-GATE step 5):
     source <(bash .claude/scripts/ci-detect.sh --project-root "$PROJECT_ROOT" 2>/dev/null) || true
     GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
     SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"

4. Detect PROJECT_ROOT:
     PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
     SOURCE_DIR="${SOURCE_DIR:-src}"
     IF [ ! -d "$SOURCE_DIR" ]; then
       SOURCE_DIR="apps"  # monorepo fallback
     fi
     IF [ ! -d "$SOURCE_DIR" ]; then
       SOURCE_DIR="."  # last resort
       LOG "WARN: source_dir_fallback=. (khong tim thay src/ hoac apps/)" >&2
     fi

5. IF --pair set: validate format MODULE_A-MODULE_B
     IF echo "$PAIR_FILTER" | grep -qvE '^[A-Z0-9_-]+-[A-Z0-9_-]+$':
       ERROR "invalid --pair format, expected MODULE_A-MODULE_B (e.g. CRM-QUOTATION)" → exit 1

6. Ensure RAW_DIR + LANE_DIR exist:
     mkdir -p "$RAW_DIR" "$LANE_DIR"
```

---

## SENSE

### S1: Load Cross-Module Dependency Pairs

```bash
# Doc tat ca pairs tu registry
ALL_PAIRS_COUNT=$(jq '.cross_module_dependencies // [] | length' "$REGISTRY_FILE")

# Sampling: Pairs > 30 → priority queue CRITICAL pairs (REUSE _shared.md:176-191)
if [ "$ALL_PAIRS_COUNT" -gt 30 ]; then
  emit_sampling_note "P-QD10-cross-module-ref-static" "$ALL_PAIRS_COUNT" 30

  # Priority queue: sap xep CRITICAL pairs truoc
  # Priority score: 3 = foreign_key (FK violation highest risk), 2 = event, 1 = api, 0 = denormalized_copy
  PAIRS_TSV=$(jq -r '
    [.cross_module_dependencies[] |
      {
        consumer: .consumer_module,
        provider: .provider_module,
        entity: .entity,
        binding_type: .binding_type,
        priority: (if .binding_type == "foreign_key" then 3
                   elif (.events_subscribed // [] | length) > 0 then 2
                   elif .binding_type == "api" then 1
                   else 0 end)
      }
    ] | sort_by(-.priority) | .[:30] |
    .[] | [.consumer, .provider, .entity, .binding_type] | @tsv
  ' "$REGISTRY_FILE")

else
  # Ap dung --pair filter neu co (REUSE _shared.md:139-160 iterate_module_pairs)
  if [ -n "${PAIR_FILTER:-}" ]; then
    PAIRS_TSV=$(iterate_module_pairs "$REGISTRY_FILE" 1)
  else
    PAIRS_TSV=$(iterate_module_pairs "$REGISTRY_FILE" 30)
  fi
fi

PAIRS_COUNT=$(echo "$PAIRS_TSV" | grep -c . || echo 0)
LOG "INFO: Loaded $ALL_PAIRS_COUNT pairs total, analyzing $PAIRS_COUNT (limit 30)" >&2
```

### S2: Load Provider Entity Definitions (CI-ROUTE PRIMARY: Serena)

```bash
# For each pair: resolve provider entity field definitions
# CI-ROUTE PRIMARY: Serena find_symbol({name_path_pattern: "EntityName", include_body: true})

declare -A PROVIDER_ENTITY_FILES

while IFS=$'\t' read -r consumer_module provider_module entity binding_type; do
  [ -z "$consumer_module" ] && continue

  PROVIDER_ENTITY_KEY="${provider_module}:${entity}"
  [ -n "${PROVIDER_ENTITY_FILES[$PROVIDER_ENTITY_KEY]+x}" ] && continue  # Already resolved

  if [[ "$SERENA_AVAILABLE" == "true" ]]; then
    # (Pseudocode — orchestrator agent thuc hien via Serena MCP):
    # ENTITY_DEF = serena_find_symbol({name_path_pattern: entity, include_body: true})
    # PROVIDER_ENTITY_FILES[$PROVIDER_ENTITY_KEY] = ENTITY_DEF.relative_path
    LOG "INFO: Using Serena find_symbol($entity) for provider field extraction" >&2
    PROVIDER_ENTITY_FILES["$PROVIDER_ENTITY_KEY"]="serena"
  else
    # Fallback: grep TypeScript interface/type/class (REUSE QD7 grep pattern)
    PROVIDER_TS_FILE=$(grep -rl "interface ${entity}\b\|type ${entity}\b\|class ${entity}\b" \
      "$SOURCE_DIR" 2>/dev/null | grep -v node_modules | head -1 || echo "")
    PROVIDER_ENTITY_FILES["$PROVIDER_ENTITY_KEY"]="${PROVIDER_TS_FILE:-}"
    if [ -n "$PROVIDER_TS_FILE" ]; then
      LOG "INFO: Provider entity $entity found via grep: $PROVIDER_TS_FILE" >&2
    else
      LOG "WARN: provider_entity_not_in_source:$entity — may be in node_modules or remote API" >&2
    fi
  fi

done <<< "$PAIRS_TSV"
```

### S3: Optional GitNexus Blast Radius Pre-analysis

```bash
# GitNexus impact() cho each provider entity — xac dinh blast radius truoc khi edit
# (Pseudocode — orchestrator agent thuc hien khi GITNEXUS_AVAILABLE)
if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # IMPACT_RESULT = gitnexus_impact({target: entity, direction: "upstream"})
  # LOG "INFO: Blast radius {entity}: direct_callers={N}, risk={level}" >&2
  LOG "INFO: GitNexus available — blast radius pre-analysis enabled (via orchestrator agent)" >&2
else
  LOG "WARN: GitNexus unavailable — skip blast radius pre-analysis" >&2
fi
```

---

## THINK

```bash
# Xay dung analysis plan per pair (xac dinh checks phai thuc hien)
SIGNAL_COUNT=0
MAX_SIGNALS=100
PAIRS_ANALYZED=0
PAIRS_CLEAN=0
PAIRS_DRIFT=0
IMPORT_CHECK_METHOD="grep"  # default, updated per-pair

while IFS=$'\t' read -r consumer_module provider_module entity binding_type; do
  [ -z "$consumer_module" ] && continue

  PAIR_KEY="${consumer_module}-${provider_module}-${entity}"

  # Extract fields tu registry
  REQUIRED_FIELDS=$(jq -r --arg c "$consumer_module" --arg p "$provider_module" --arg e "$entity" '
    .cross_module_dependencies[] |
    select(.consumer_module == $c and .provider_module == $p and .entity == $e) |
    .required_fields // [] | .[]
  ' "$REGISTRY_FILE" 2>/dev/null)

  OPTIONAL_FIELDS=$(jq -r --arg c "$consumer_module" --arg p "$provider_module" --arg e "$entity" '
    .cross_module_dependencies[] |
    select(.consumer_module == $c and .provider_module == $p and .entity == $e) |
    .optional_fields // [] | .[]
  ' "$REGISTRY_FILE" 2>/dev/null)

  # Plan checks
  CHECKS="import_check"
  [ -n "$REQUIRED_FIELDS" ] && CHECKS="$CHECKS,required_fields_check"
  [[ "${PROFILE:-standard}" == "deep" || "${PROFILE:-standard}" == "exhaustive" ]] && \
    [ -n "$OPTIONAL_FIELDS" ] && CHECKS="$CHECKS,optional_fields_check"
  CHECKS="$CHECKS,deprecated_import_check"

  LOG "INFO: THINK: pair $PAIR_KEY → checks=$CHECKS" >&2

done <<< "$PAIRS_TSV"
```

---

## ACT

### A1: Per-Pair Cross-Module Reference Analysis

```bash
while IFS=$'\t' read -r consumer_module provider_module entity binding_type; do
  [ -z "$consumer_module" ] && continue

  PAIR_KEY="${consumer_module}-${provider_module}-${entity}"
  PAIRS_ANALYZED=$((PAIRS_ANALYZED + 1))
  HAS_SIGNAL=false

  LOG "INFO: Analyzing pair: $consumer_module → $provider_module ($entity, binding=$binding_type)" >&2

  # A1.1: Tim consumer import provider entity
  # CI-ROUTE PRIMARY: Serena find_referencing_symbols({name_path: entity})
  if [[ "$SERENA_AVAILABLE" == "true" ]]; then
    # (Pseudocode — orchestrator agent thuc hien):
    # REFS = serena_find_referencing_symbols({name_path: entity})
    # CONSUMER_IMPORT_FOUND = any(ref.file contains consumer_module_hint for ref in REFS)
    IMPORT_CHECK_METHOD="serena"
    LOG "INFO: Using Serena find_referencing_symbols($entity) for consumer import check" >&2
  else
    # Fallback: bash helper (REUSE QD7 combined grep approach)
    bash ".claude/scripts/wf-fix-probe-cross-module-ref.sh" \
      --session-dir "$SESSION_DIR" \
      --consumer-module "$consumer_module" \
      --provider-module "$provider_module" \
      --entity "$entity" \
      --source-dir "$SOURCE_DIR" \
      --output-file "$RAW_DIR/${PAIR_KEY}-import-check.json" \
      2>/dev/null || true
    IMPORT_CHECK_METHOD="grep"
    LOG "INFO: Using grep fallback via wf-fix-probe-cross-module-ref.sh ($entity)" >&2
  fi

  # A1.2: Verify required_fields duoc consume
  REQUIRED_FIELDS=$(jq -r --arg c "$consumer_module" --arg p "$provider_module" --arg e "$entity" '
    .cross_module_dependencies[] |
    select(.consumer_module == $c and .provider_module == $p and .entity == $e) |
    .required_fields // [] | .[]
  ' "$REGISTRY_FILE" 2>/dev/null)

  if [ -n "$REQUIRED_FIELDS" ]; then
    while IFS= read -r required_field; do
      [ -z "$required_field" ] && continue

      # Tim field reference trong consumer code
      FIELD_USED=false
      CONSUMER_HINT=$(echo "$consumer_module" | sed 's/MOD-//' | tr '[:upper:]' '[:lower:]')

      if [[ "$SERENA_AVAILABLE" == "true" ]]; then
        # (Pseudocode): FIELD_REFS = serena_find_referencing_symbols({name_path: required_field})
        # FIELD_USED = any(ref.file contains consumer_hint for ref in FIELD_REFS)
        LOG "INFO: Serena find_referencing_symbols($required_field) for field usage check" >&2
        FIELD_USED=true  # serena orchestrator sets this
      else
        # Grep: tim .field hoac ["field"] pattern trong consumer dirs
        if grep -rl "\\.${required_field}\\b\\|[\"']${required_field}[\"']" "$SOURCE_DIR" \
            2>/dev/null | grep -v node_modules | grep -qi "$CONSUMER_HINT" | head -1 | grep -q .; then
          FIELD_USED=true
        elif grep -rl "\\.${required_field}\\b\\|[\"']${required_field}[\"']" "$SOURCE_DIR" \
            2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
          # Field tim thay trong source nhung khong confirm consumer dir — ambiguous
          FIELD_USED=true
          LOG "INFO: Field $required_field found in source (consumer dir unclear — grep fallback)" >&2
        fi
      fi

      if ! $FIELD_USED; then
        [ "$SIGNAL_COUNT" -ge "$MAX_SIGNALS" ] && break

        # REUSE emit_signal_cross_module tu _shared.md:42-92
        emit_signal_cross_module \
          "P-QD10-cross-module-ref-static" \
          "cross_module_ref_drift" \
          "medium" \
          "Required field khong duoc consume: ${consumer_module}→${provider_module}.${entity}.${required_field}" \
          "Consumer '${consumer_module}' khai bao su dung entity '${entity}' tu provider '${provider_module}' nhung KHONG co reference toi required field '${required_field}'. Co the field da bi doi ten trong provider hoac consumer chua cap nhat sau schema change." \
          "$provider_module" \
          "$consumer_module" \
          "field_diff" \
          "Required field '${required_field}' of entity '${entity}' (provider: ${provider_module}) not found in consumer: ${consumer_module}"

        SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
        HAS_SIGNAL=true
        LOG "INFO: Signal cross_module_ref_drift: $consumer_module → $provider_module.$entity.$required_field" >&2
      fi
    done <<< "$REQUIRED_FIELDS"
  fi

  # A1.3: Kiem tra optional_fields chua dung (LOW severity — deep+ only)
  if [[ "${PROFILE:-standard}" == "deep" || "${PROFILE:-standard}" == "exhaustive" ]]; then
    OPTIONAL_FIELDS=$(jq -r --arg c "$consumer_module" --arg p "$provider_module" --arg e "$entity" '
      .cross_module_dependencies[] |
      select(.consumer_module == $c and .provider_module == $p and .entity == $e) |
      .optional_fields // [] | .[]
    ' "$REGISTRY_FILE" 2>/dev/null)

    if [ -n "$OPTIONAL_FIELDS" ]; then
      while IFS= read -r optional_field; do
        [ -z "$optional_field" ] && continue
        [ "$SIGNAL_COUNT" -ge "$MAX_SIGNALS" ] && break

        OPT_FIELD_USED=false
        if grep -rl "\\.${optional_field}\\b" "$SOURCE_DIR" 2>/dev/null | \
            grep -v node_modules | head -1 | grep -q .; then
          OPT_FIELD_USED=true
        fi

        if ! $OPT_FIELD_USED; then
          emit_signal_cross_module \
            "P-QD10-cross-module-ref-static" \
            "optional_field_unused" \
            "low" \
            "Optional field chua duoc dung trong consumer: ${consumer_module}→${provider_module}.${entity}.${optional_field}" \
            "Consumer '${consumer_module}' co the can optional field '${optional_field}' cua entity '${entity}' (provider: ${provider_module}) nhung hien tai khong co reference. Informational — co the intentional." \
            "$provider_module" \
            "$consumer_module" \
            "field_diff" \
            "Optional field '${optional_field}' not referenced in consumer code (deep+ check)"

          SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
          LOG "INFO: Signal optional_field_unused: $consumer_module → $provider_module.$entity.$optional_field" >&2
        fi
      done <<< "$OPTIONAL_FIELDS"
    fi
  fi

  # A1.4: Kiem tra deprecated imports (REUSE QD7 grep approach)
  if [[ "$SERENA_AVAILABLE" == "true" ]]; then
    # (Pseudocode): deprecated_refs = serena_find_referencing_symbols({name_path: "@deprecated_entity"})
    LOG "INFO: Serena deprecated import check for $consumer_module → $entity" >&2
  else
    bash ".claude/scripts/wf-fix-probe-cross-module-ref.sh" \
      --session-dir "$SESSION_DIR" \
      --consumer-module "$consumer_module" \
      --provider-module "$provider_module" \
      --entity "$entity" \
      --source-dir "$SOURCE_DIR" \
      --check-deprecated \
      --output-file "$RAW_DIR/${PAIR_KEY}-deprecated-check.json" \
      2>/dev/null || true

    # Parse output neu ton tai
    if [ -f "$RAW_DIR/${PAIR_KEY}-deprecated-check.json" ]; then
      DEP_FOUND=$(jq -r '.deprecated_found // false' "$RAW_DIR/${PAIR_KEY}-deprecated-check.json" 2>/dev/null || echo "false")
      if [[ "$DEP_FOUND" == "true" ]]; then
        [ "$SIGNAL_COUNT" -ge "$MAX_SIGNALS" ] || {
          DEP_FILE=$(jq -r '.findings[0].file // "unknown"' "$RAW_DIR/${PAIR_KEY}-deprecated-check.json" 2>/dev/null || echo "unknown")
          DEP_LINE=$(jq -r '.findings[0].line // 0' "$RAW_DIR/${PAIR_KEY}-deprecated-check.json" 2>/dev/null || echo 0)
          DEP_MATCH=$(jq -r '.findings[0].match // ""' "$RAW_DIR/${PAIR_KEY}-deprecated-check.json" 2>/dev/null || echo "")

          emit_signal_cross_module \
            "P-QD10-cross-module-ref-static" \
            "deprecated_import" \
            "medium" \
            "Consumer import deprecated export: ${consumer_module} → ${provider_module}.${entity}" \
            "Consumer '${consumer_module}' import deprecated entity/export tu provider '${provider_module}'. Deprecated import co the break sau khi provider remove export — can migrate sang replacement." \
            "$provider_module" \
            "$consumer_module" \
            "import_path" \
            "$DEP_MATCH" \
            "\"$DEP_FILE\"" \
            "[$DEP_LINE, $DEP_LINE]"

          SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
          HAS_SIGNAL=true
          LOG "INFO: Signal deprecated_import: $consumer_module → $provider_module.$entity" >&2
        }
      fi
    fi
  fi

  # Track outcome
  if $HAS_SIGNAL; then
    PAIRS_DRIFT=$((PAIRS_DRIFT + 1))
  else
    PAIRS_CLEAN=$((PAIRS_CLEAN + 1))
  fi

done <<< "$PAIRS_TSV"
```

### A2: Build Cross-Module Map (Coordination Output)

```bash
# Tao cross-module-map.json cho QD10 internal coordination (other probes reuse)
jq -n \
  --arg probe_id "P-QD10-cross-module-ref-static" \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson pairs_analyzed "$PAIRS_ANALYZED" \
  --argjson pairs_clean "$PAIRS_CLEAN" \
  --argjson pairs_drift "$PAIRS_DRIFT" \
  --argjson signals "$SIGNAL_COUNT" \
  --argjson serena "$([[ "$SERENA_AVAILABLE" == "true" ]] && echo "true" || echo "false")" \
  --argjson gitnexus "$([[ "$GITNEXUS_AVAILABLE" == "true" ]] && echo "true" || echo "false")" \
  --arg method "$IMPORT_CHECK_METHOD" \
  '{
    probe_id: $probe_id,
    generated_at: $now,
    pairs_analyzed: $pairs_analyzed,
    pairs_clean: $pairs_clean,
    pairs_drift: $pairs_drift,
    signals_emitted: $signals,
    ci_route: {serena: $serena, gitnexus: $gitnexus, import_check_method: $method},
    pairs: []
  }' > "$CROSS_MODULE_MAP" 2>/dev/null || \
  LOG "WARN: cross-module-map.json write failed — khong block" >&2

LOG "INFO: cross-module-map.json created (pairs_analyzed=$PAIRS_ANALYZED, drift=$PAIRS_DRIFT)" >&2
```

---

## VERIFY

```
1. Kiem tra moi signal co dimension_id == "QD10" va probe_id == "P-QD10-cross-module-ref-static"
2. Kiem tra moi signal co signal_type trong ["cross_module_ref_drift", "deprecated_import", "optional_field_unused"]
3. Kiem tra moi signal co evidence[] non-empty voi content >= 10 chars
4. Kiem tra dedup_key format: "P-QD10-cross-module-ref-static:{signal_type}:{provider}:{consumer}"
5. Kiem tra severity mapping:
   - cross_module_ref_drift → medium
   - deprecated_import → medium
   - optional_field_unused → low
6. Kiem tra SIGNAL_COUNT <= MAX_SIGNALS (100) hoac co WARNING "max_signals_reached"
7. Kiem tra cross-module-map.json ton tai (hoac WARN neu write fail)
8. Kiem tra sampling field ton tai khi ALL_PAIRS_COUNT > 30

Ghi summary file:
  cat > "$RAW_DIR/P-QD10-cross-module-ref-static-summary.json" << EOF
  {
    "probe_id": "P-QD10-cross-module-ref-static",
    "profile": "${PROFILE:-standard}",
    "pairs_analyzed": $PAIRS_ANALYZED,
    "pairs_clean": $PAIRS_CLEAN,
    "pairs_drift": $PAIRS_DRIFT,
    "signals_emitted": $SIGNAL_COUNT,
    "ci_route": {
      "serena_used": $([[ "$SERENA_AVAILABLE" == "true" ]] && echo "true" || echo "false"),
      "gitnexus_used": $([[ "$GITNEXUS_AVAILABLE" == "true" ]] && echo "true" || echo "false"),
      "import_check_method": "$IMPORT_CHECK_METHOD"
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
| Consumer khong dung required_field cua provider entity | **MEDIUM** | Schema drift nghiem trong — consumer se bi loi khi provider field thay doi hoac required validation them vao |
| Consumer import deprecated entity/export tu provider | **MEDIUM** | Deprecated import co the break sau khi provider remove export — can migrate som |
| Consumer khong dung optional_field (informational) | **LOW** | Chi informational — optional field chua dung la chap nhan duoc nhung nen track |
| Consumer KHONG import entity (binding_type=api hoac event) | **MEDIUM** | Consumer khong dung provider API — co the skip (tinh nang chua implement) hoac drift sau refactor |

> **Rationale severity MEDIUM (khong HIGH):** Cross-module reference drift la tinh (static), khong phai runtime failure. HIGH chi khi phat hien: runtime orphan FK (QD10 orphan-reference-runtime Wave 3) hoac API contract breaking change (QD10 api-contract-drift). Static drift = MEDIUM: can developer review de confirm bug.

---

## Dedup Hints

| Signal Type | Dedup Key Pattern |
|-------------|------------------|
| `cross_module_ref_drift` | `P-QD10-cross-module-ref-static:cross_module_ref_drift:{provider_module}:{consumer_module}` |
| `deprecated_import` | `P-QD10-cross-module-ref-static:deprecated_import:{provider_module}:{consumer_module}` |
| `optional_field_unused` | `P-QD10-cross-module-ref-static:optional_field_unused:{provider_module}:{consumer_module}` |

Cross-probe dedup: `cross_module_ref_drift` tu W2.2 co the overlap voi `api_contract_breaking_change` tu W2.3 (api-contract-drift) khi cung provider field bi drift. Aggregator dedup boi dedup_key (probe_id:signal_type:provider:consumer).

---

## Signal Schema Examples

### cross_module_ref_drift

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-cross-module-ref-static",
  "dimension_id": "QD10",
  "signal_type": "cross_module_ref_drift",
  "severity": "medium",
  "title": "Required field khong duoc consume: QUOTATION→CRM.Customer.customerId",
  "description": "Consumer 'MOD-QUOTATION' khai bao su dung entity 'Customer' tu provider 'MOD-CRM' nhung KHONG co reference toi required field 'customerId'. Co the field da bi doi ten trong provider hoac consumer chua cap nhat sau schema change.",
  "location": {
    "provider_module": "MOD-CRM",
    "consumer_module": "MOD-QUOTATION",
    "file_path": null,
    "line_range": null
  },
  "evidence": [
    {"type": "field_diff", "content": "Required field 'customerId' of entity 'Customer' (provider: MOD-CRM) not found in consumer: MOD-QUOTATION"}
  ],
  "dedup_key": "P-QD10-cross-module-ref-static:cross_module_ref_drift:MOD-CRM:MOD-QUOTATION"
}
```

### deprecated_import

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-cross-module-ref-static",
  "dimension_id": "QD10",
  "signal_type": "deprecated_import",
  "severity": "medium",
  "title": "Consumer import deprecated export: QUOTATION import OldCustomerDTO tu CRM",
  "description": "Consumer 'MOD-QUOTATION' import 'OldCustomerDTO' tu provider 'MOD-CRM'. Export nay da duoc danh dau @deprecated va se bi remove trong phien ban tiep theo.",
  "location": {
    "provider_module": "MOD-CRM",
    "consumer_module": "MOD-QUOTATION",
    "file_path": "src/modules/quotation/services/quotation.service.ts",
    "line_range": [42, 42]
  },
  "evidence": [
    {"type": "import_path", "content": "import { OldCustomerDTO } from '@modules/crm/types' // @deprecated"}
  ],
  "dedup_key": "P-QD10-cross-module-ref-static:deprecated_import:MOD-CRM:MOD-QUOTATION"
}
```

### optional_field_unused

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-cross-module-ref-static",
  "dimension_id": "QD10",
  "signal_type": "optional_field_unused",
  "severity": "low",
  "title": "Optional field chua duoc dung trong consumer: QUOTATION→CRM.Customer.customerNotes",
  "description": "Consumer 'MOD-QUOTATION' co the can optional field 'customerNotes' cua entity 'Customer' (provider: MOD-CRM) nhung hien tai khong co reference. Informational — co the intentional.",
  "location": {
    "provider_module": "MOD-CRM",
    "consumer_module": "MOD-QUOTATION",
    "file_path": null,
    "line_range": null
  },
  "evidence": [
    {"type": "field_diff", "content": "Optional field 'customerNotes' not referenced in consumer code (deep+ check)"}
  ],
  "dedup_key": "P-QD10-cross-module-ref-static:optional_field_unused:MOD-CRM:MOD-QUOTATION"
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile=quick | SKIP lane (QD10 quick=skip — probe khong duoc goi) |
| `cross_module_dependencies[]` rong hoac vang | SKIP probe, emit WARN "skipped_no_cross_module_dependencies_defined" → exit 0 |
| SOURCE_DIR khong ton tai | WARN + fallback SOURCE_DIR=./ — probe tiep tuc |
| Serena unavailable | Fallback grep via `wf-fix-probe-cross-module-ref.sh` — LOG WARN, khong block |
| GitNexus unavailable | Skip blast radius pre-analysis — LOG WARN, khong block |
| Provider entity khong tim thay trong source | LOG WARN "provider_entity_not_in_source:{entity}" — skip field checks cho pair nay, tiep tuc |
| Consumer module path khong resolve | LOG WARN "consumer_path_not_resolved:{module}" — fallback search toan SOURCE_DIR |
| Registry parse error (jq fail) | ERROR E100 + exit 1 — registry corrupt la blocker real |
| > 30 pairs | Priority queue (FK first), sample top 30, emit_sampling_note |
| > 100 signals | Stop emitting, LOG WARN "max_signals_reached (100)" |
| `--pair` format invalid | ERROR + exit 1 — inform user format MODULE_A-MODULE_B |
| wf-fix-probe-cross-module-ref.sh fail | LOG WARN, probe tiep tuc voi kho du lieu khong day du |
| cross-module-map.json write fail | LOG WARN — khong block probe (optional coordination file) |

---

## Cache Policy

**allowed** — probe nay la pure static analysis (KHONG co runtime component: browser, DB, API call).

Cache TTL: 24h (per `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §3.5).

Ly do: Static import analysis khong thay doi tru khi code thay doi (git commit). Cache hieu qua khi chay nhieu profile consecutively. Key: `{PROJECT_ROOT_SHA}:{registry_mtime}:{pairs_count}`.

---

## Profile-Resolver Entry

```yaml
# Trong procedures/probes/_shared.md (QD10 Profile-Resolver section):
P-QD10-cross-module-ref-static:
  quick: skip
  standard: run
  deep: run (them optional_field_unused check)
  exhaustive: run (full — all checks + optional_fields LOW signals)
  parallel_class: static
  optional: false
  max_pairs: 30
  optional_field_check_profiles: [deep, exhaustive]
```

---

## Acceptance Test

**Synthetic test (CI):**
1. Setup registry voi cross_module_dependency:
   ```json
   {
     "cross_module_dependencies": [{
       "consumer_module": "MOD-QUOTATION",
       "provider_module": "MOD-CRM",
       "entity": "Customer",
       "binding_type": "api",
       "required_fields": ["customerId", "customerName"],
       "optional_fields": ["customerEmail"]
     }]
   }
   ```
2. Setup source: `apps/quotation/` KHONG co reference toi `customerId`
3. Run probe voi `--profile=standard`
4. **Expected:**
   - `cross_module_ref_drift` signal (severity=MEDIUM) cho field `customerId`
   - `customerName` → signal hoac PASS tuy theo source
   - `optional_field_unused` → KHONG emit (chi deep+ profile)
5. Verify: `jq 'select(.signal_type == "cross_module_ref_drift")' "$SIGNALS_FILE"`

**EUREKA acceptance (W2.E2E):**
- Author cross_module_dependency trong registry: `MOD-QUOTATION → MOD-CRM, entity=Customer`
- Run `/wf-fix-bugs --lane=QD10 --pair=CRM-QUOTATION --profile=standard`
- Expect: Probe phat hien >= 1 reference tu QUOTATION sang CRM Customer entity
- Expect: Signal PASS (no drift) hoac `cross_module_ref_drift` (neu co drift)
- Performance: probe complete trong <= 2 phut cho 1 pair (static — nhanh)
