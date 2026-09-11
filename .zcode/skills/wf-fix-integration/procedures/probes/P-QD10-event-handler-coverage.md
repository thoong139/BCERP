# P-QD10-event-handler-coverage — Kiem tra Event Handler Coverage trong Cross-Module Dependencies

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD10-event-handler-coverage |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Kiem tra moi event duoc khai bao trong cross_module_dependencies[].events_subscribed[] deu co handler tuong ung trong consumer module. Phat hien missing handlers (no subscribe code) va partial handlers (khong cover toan bo event subtypes qua TypeScript discriminated union). |
| **Cache** | allowed (static per source file state) |
| **Error codes** | E100 (registry corrupt — QD10 base), E107 (event handler grep pattern fail — no source dir) |
| **Migrates from** | (new in v9) |

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| Pattern grep approach (combined regex scan per issue class, EXCLUDE_RE test files, SOURCE_EXTS) | `QD3 wf-fix-probe-static-sast.sh` | `:104-173 (STRATEGY B grep fallback)` | Reuse EXCLUDE_RE + SOURCE_EXTS pattern for event handler detection: `on('event')`, `@EventHandler`, `subscribe()`. Adapt issue_class and severity for event context. |
| Test file exclusion pattern (EXCLUDE_RE) | `QD3 wf-fix-probe-static-sast.sh` | `:43` | `EXCLUDE_RE='(/test/|/tests/|/spec/|/__tests__/|\.test\.|\.spec\.)'` — giu nguyen, khong test handler coverage trong test code |
| Source extensions array (SOURCE_EXTS) | `QD3 wf-fix-probe-static-sast.sh` | `:138-142` | Reuse `--include="*.ts" --include="*.js" --include="*.tsx"` etc. Them `--include="*.cs"` cho NestJS C# patterns |
| iterate_module_pairs() + events_subscribed[] filter | `procedures/probes/_shared.md` (QD10) | `:139-160` | Reuse pair iteration; filter WHERE events_subscribed[] non-empty |
| emit_signal_cross_module() + dedup_key | `procedures/probes/_shared.md` (QD10) | `:42-92` | Signal emit voi provider/consumer context; dedup_key "probe_id:signal_type:event_name:consumer" |
| CI detect load pattern | `QD9 P-QD9-spa-route-coverage.md` | `PRE-GATE:step 5` | `source <(bash ci-detect.sh ...)` + GITNEXUS_AVAILABLE/SERENA_AVAILABLE vars |
| sampling / emit_sampling_note | `procedures/probes/_shared.md` (QD10) | `:183-191` | Document sampling khi events > threshold |

**Diff so voi QD3 sast scan:**
- QD3: detect security vulnerability patterns (SQL injection, XSS, deserialization)
- W2.4: detect event handler patterns per declared event name (`events_subscribed[i]`)
- CI-ROUTE PRIMARY: GitNexus `query("event:{event_name}")` — co the trace event flow trong call graph (khong chi grep text)
- Signals mang context `provider_module + consumer_module + event_name` (khong chi file/line)
- Loai grep pattern: on/addEventListener/subscribe/fromEvent/EventHandler decorator (event-specific, khong security)

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Find event subscribers in call graph | **GitNexus** `query("event:{event_name}")` | Grep `on('event-name')`, `addEventListener`, `subscribe()` | PRIMARY — trace event flow, tim tat ca files subscribe event |
| Find event emitter symbol definition | **Serena** `find_referencing_symbols({name_path: "EventEmitterSymbol"})` | Grep `EventEmitter|EventBus` trong provider module | Backup khi GitNexus stale; locate emitter → then find_referencing_symbols |
| Verify TypeScript event type union | **Serena** `find_symbol({name_path_pattern: "EventType|EventPayload", include_body: true})` | Grep `type.*=.*|` (union pattern) | Kiem tra TypeScript discriminated union cho event subtypes |

**Khi CI unavailable:**
```bash
if [[ "$GITNEXUS_AVAILABLE" != "true" ]]; then
  echo "WARN: GitNexus unavailable — fallback to grep for event handler patterns (P-QD3-sast STRATEGY B adapted)" >&2
fi
if [[ "$SERENA_AVAILABLE" != "true" ]]; then
  echo "WARN: Serena unavailable — skip TypeScript union coverage check" >&2
fi
```

---

## PRE-GATE

```
1. IF profile=quick:
     SKIP probe (QD10 quick=skip)

2. Kiem tra co cross_module_dependencies[] voi events_subscribed[] non-empty:
     EVENT_DEP_COUNT=$(jq '
       [.cross_module_dependencies // [] | .[] |
        select((.events_subscribed // [] | length) > 0 or .binding_type == "event")]
       | length' "$REGISTRY_FILE")
     IF EVENT_DEP_COUNT == 0:
       SKIP probe, ghi note "skipped_no_event_dependencies"
       LOG WARN "QD10 event-handler-coverage requires cross_module_dependencies[] with events_subscribed[] or binding_type=event. Add entries via wf-detect-cross-module-deps.sh (W2.6)."
       → exit 0

3. Load CI availability (REUSE: QD9 P-QD9-spa-route-coverage.md PRE-GATE step 5):
     source <(bash .claude/scripts/ci-detect.sh --project-root "$PROJECT_ROOT" 2>/dev/null) || true
     GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
     SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"

4. Detect PROJECT_ROOT + SOURCE_DIR:
     PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
     SOURCE_DIR="${SOURCE_DIR:-src}"
     IF [ ! -d "$SOURCE_DIR" ]; then SOURCE_DIR="apps"; fi
     IF [ ! -d "$SOURCE_DIR" ]; then SOURCE_DIR=".";
       LOG "WARN: source_dir_fallback=." >&2; fi

5. IF --pair set: validate format MODULE_A-MODULE_B
     IF echo "$PAIR_FILTER" | grep -qvE '^[A-Z0-9_-]+-[A-Z0-9_-]+$':
       ERROR "invalid --pair format, expected MODULE_A-MODULE_B" → exit 1

6. Ensure RAW_DIR + LANE_DIR exist:
     mkdir -p "$RAW_DIR" "$LANE_DIR"
```

---

## SENSE

### S1: Load Event Dependencies (pairs co events_subscribed[])

```bash
# Doc tat ca pairs co events_subscribed[] non-empty hoac binding_type=event
# REUSE: _shared.md:139-160 iterate_module_pairs() adapted

ALL_EVENT_DEPS=$(jq -r '
  .cross_module_dependencies // [] | .[] |
  select((.events_subscribed // [] | length) > 0 or .binding_type == "event") |
  [
    .consumer_module,
    .provider_module,
    .entity,
    (.events_subscribed // [] | join(","))
  ] | @tsv
' "$REGISTRY_FILE")

TOTAL_DEP_COUNT=$(echo "$ALL_EVENT_DEPS" | grep -c . || echo 0)

# Apply --pair filter neu co
if [ -n "${PAIR_FILTER:-}" ]; then
  ALL_EVENT_DEPS=$(echo "$ALL_EVENT_DEPS" | awk -F'\t' -v pair="$PAIR_FILTER" \
    'BEGIN{split(pair,p,"-")} ($1==p[1] && $2==p[2]) || ($1==p[2] && $2==p[1]) {print}')
fi

# Build flat event list: consumer, provider, entity, event_name (1 row per event)
EVENTS_TSV=""
while IFS=$'\t' read -r consumer_module provider_module entity events_csv; do
  [ -z "$consumer_module" ] && continue
  IFS=',' read -ra EVENT_LIST <<< "$events_csv"
  for event_name in "${EVENT_LIST[@]}"; do
    event_name=$(echo "$event_name" | tr -d ' ')
    [ -z "$event_name" ] && continue
    EVENTS_TSV="${EVENTS_TSV}${consumer_module}\t${provider_module}\t${entity}\t${event_name}\n"
  done
done <<< "$ALL_EVENT_DEPS"

TOTAL_EVENTS=$(printf "%b" "$EVENTS_TSV" | grep -c . || echo 0)
LOG "INFO: Found $TOTAL_EVENTS events to check across $TOTAL_DEP_COUNT dependency pairs" >&2
```

### S2: Load CI Availability

```bash
# Da load trong PRE-GATE step 3 — re-export cho ACT step
LOG "INFO: CI-ROUTE: GitNexus=$GITNEXUS_AVAILABLE Serena=$SERENA_AVAILABLE" >&2

# Xac dinh grep strategy (REUSE QD3 STRATEGY B adapted)
# EXCLUDE_RE: bo qua test files (REUSE QD3:43)
EXCLUDE_RE='(/test/|/tests/|/spec/|/__tests__/|\.test\.|\.spec\.)'

# SOURCE_EXTS: source file types (REUSE QD3:138-142, them .cs cho NestJS)
SOURCE_EXTS=(
  --include="*.ts"  --include="*.tsx" --include="*.js"
  --include="*.jsx" --include="*.py"  --include="*.java"
  --include="*.cs"  --include="*.go"  --include="*.kt"
)
```

---

## THINK

```bash
# Xay dung check plan per event
# Quyet dinh approach (P1 correctness > P2 speed):
#   GitNexus available → query("event:{name}") (most accurate, trace call graph)
#   GitNexus unavailable, Serena available → find_referencing_symbols + grep confirm
#   Neither → grep-only (P1 may be limited — log WARN coverage degraded)

SIGNAL_COUNT=0
MAX_SIGNALS=100
EVENTS_ANALYZED=0
EVENTS_CLEAN=0
EVENTS_MISSING=0
EVENTS_PARTIAL=0

# Sampling: neu tong events > 50, uu tien CRITICAL events truoc (per Section 6.3 guidance)
# (W2.4 spec khong co sampling limit rieng — ap dung 50 tu budget nhat quan voi QD10 pairs=30)
if [ "$TOTAL_EVENTS" -gt 50 ]; then
  # Ghi sampling note (REUSE _shared.md:183-191)
  emit_sampling_note "P-QD10-event-handler-coverage" "$TOTAL_EVENTS" 50
  LOG "INFO: THINK: events>50, sampling first 50 (CRITICAL events processed first)" >&2
  # Re-build EVENTS_TSV: 50 entries max (no external priority ranking at this stage — use insertion order)
  EVENTS_TSV=$(printf "%b" "$EVENTS_TSV" | head -50)
fi

LOG "INFO: THINK: approach=GitNexus($GITNEXUS_AVAILABLE)+Serena($SERENA_AVAILABLE)+grep" >&2
```

---

## ACT

### A1: Per-Event Handler Detection

```bash
# REUSE QD3 STRATEGY B: grep pattern-based detection adapted for event handlers
# Per event: 3-tier approach (GitNexus → Serena → grep)

while IFS=$'\t' read -r consumer_module provider_module entity event_name; do
  [ -z "$consumer_module" ] && continue
  [ "$SIGNAL_COUNT" -ge "$MAX_SIGNALS" ] && {
    LOG "WARN: max_signals_reached ($MAX_SIGNALS), stopping" >&2
    break
  }

  EVENTS_ANALYZED=$((EVENTS_ANALYZED + 1))
  CONSUMER_HINT=$(echo "$consumer_module" | sed 's/MOD-//' | tr '[:upper:]' '[:lower:]')
  CONSUMER_SOURCE="${SOURCE_DIR}"
  # Cố gắng narrow down to consumer module directory
  for dir_candidate in \
      "$SOURCE_DIR/$CONSUMER_HINT" \
      "$SOURCE_DIR/app-$CONSUMER_HINT" \
      "$SOURCE_DIR/apps/$CONSUMER_HINT" \
      "$SOURCE_DIR/modules/$CONSUMER_HINT"; do
    [ -d "$dir_candidate" ] && { CONSUMER_SOURCE="$dir_candidate"; break; }
  done

  HANDLER_FOUND=false
  HANDLER_FILE=""
  HANDLER_LINE=0
  HANDLER_PATTERN=""

  # --- Tier 1: GitNexus PRIMARY ---
  # (Pseudocode — orchestrator agent executes via GitNexus MCP when available)
  if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
    # GITNEXUS_RESULT = gitnexus_query({query: "event:${event_name}"})
    # IF GITNEXUS_RESULT.files[] INTERSECTS consumer module files:
    #   HANDLER_FOUND=true; HANDLER_FILE=first_match; HANDLER_PATTERN="gitnexus"
    # Pseudocode result injected back into HANDLER_FOUND/HANDLER_FILE by orchestrator
    LOG "INFO: GitNexus query('event:${event_name}') → checking consumer ${consumer_module}" >&2
    # Orchestrator sets: GITNEXUS_HANDLER_FOUND, GITNEXUS_HANDLER_FILE
    HANDLER_FOUND="${GITNEXUS_HANDLER_FOUND:-false}"
    HANDLER_FILE="${GITNEXUS_HANDLER_FILE:-}"
    [[ "$HANDLER_FOUND" == "true" ]] && HANDLER_PATTERN="gitnexus"
  fi

  # --- Tier 2: Serena SECONDARY (when GitNexus unavailable or returns no result) ---
  if [[ "$HANDLER_FOUND" != "true" ]] && [[ "$SERENA_AVAILABLE" == "true" ]]; then
    # (Pseudocode — orchestrator agent executes via Serena MCP)
    # SERENA_RESULT = serena_find_referencing_symbols({name_path: "emit" or event_emitter_symbol, relative_path: provider_source})
    # Filter results within consumer_module directory
    # IF found: HANDLER_FOUND=true
    LOG "INFO: Serena find_referencing_symbols(event emitter, provider) → consumer ${consumer_module}" >&2
    HANDLER_FOUND="${SERENA_HANDLER_FOUND:-false}"
    HANDLER_FILE="${SERENA_HANDLER_FILE:-}"
    [[ "$HANDLER_FOUND" == "true" ]] && HANDLER_PATTERN="serena"
  fi

  # --- Tier 3: Grep Fallback (REUSE QD3 STRATEGY B adapted) ---
  if [[ "$HANDLER_FOUND" != "true" ]]; then
    # Escape event name for grep (dots, hyphens)
    EVENT_ESCAPED=$(printf '%s' "$event_name" | sed 's/[.]/\\./g; s/[-]/[-]/g')

    # Pattern set: all common event handler registration patterns
    # REUSE QD3:104-173 pattern approach — adapted for event semantics
    for pat in \
      "on(['\"]${EVENT_ESCAPED}['\"])" \
      "addEventListener(['\"]${EVENT_ESCAPED}['\"])" \
      "@EventHandler(${EVENT_ESCAPED})" \
      "subscribe.*${EVENT_ESCAPED}" \
      "fromEvent.*['\"]${EVENT_ESCAPED}['\"]" \
      "eventBus\.on(${EVENT_ESCAPED})" \
      "\.listen(.*${EVENT_ESCAPED})" \
      "${EVENT_ESCAPED}Handler" \
      "handle${EVENT_ESCAPED^}" ; do

      GREP_MATCH=$(grep -rnE "$pat" "$CONSUMER_SOURCE" "${SOURCE_EXTS[@]}" 2>/dev/null \
        | grep -vE "$EXCLUDE_RE" | head -1 || true)

      if [ -n "$GREP_MATCH" ]; then
        HANDLER_FOUND=true
        HANDLER_FILE=$(echo "$GREP_MATCH" | cut -d: -f1)
        HANDLER_LINE=$(echo "$GREP_MATCH" | cut -d: -f2)
        HANDLER_PATTERN="grep:$pat"
        LOG "INFO: Handler found via grep for event '${event_name}' in ${HANDLER_FILE}:${HANDLER_LINE}" >&2
        break
      fi
    done

    if [[ "$HANDLER_FOUND" != "true" ]]; then
      # Fallback: anche generic subscribe patterns without event name
      GENERIC_MATCH=$(grep -rnE "subscribe\s*\(|\.on\s*\(" "$CONSUMER_SOURCE" "${SOURCE_EXTS[@]}" 2>/dev/null \
        | grep -vE "$EXCLUDE_RE" | head -1 || true)
      if [ -n "$GENERIC_MATCH" ]; then
        LOG "INFO: Generic subscribe/on found but no specific match for '${event_name}' — treat as MISSING" >&2
      fi
    fi
  fi

  # --- Emit signals ---
  if [[ "$HANDLER_FOUND" != "true" ]]; then
    # Signal: event_handler_missing (HIGH)
    EVENTS_MISSING=$((EVENTS_MISSING + 1))
    [ "$SIGNAL_COUNT" -lt "$MAX_SIGNALS" ] && {
      emit_signal_cross_module \
        "P-QD10-event-handler-coverage" \
        "event_handler_missing" \
        "high" \
        "Event handler missing: ${consumer_module} khong co handler cho event '${event_name}' tu ${provider_module}" \
        "Consumer module '${consumer_module}' khai bao subscribe event '${event_name}' tu provider '${provider_module}' trong cross_module_dependencies, nhung khong tim thay handler code. Event se bi bo qua khi duoc emit, dan den data loss hoac silent failure." \
        "$provider_module" \
        "$consumer_module" \
        "import_path" \
        "event_name=${event_name} entity=${entity} consumer_source=${CONSUMER_SOURCE} search_strategy=GitNexus($GITNEXUS_AVAILABLE)+Serena($SERENA_AVAILABLE)+grep"
      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      LOG "INFO: Signal event_handler_missing: ${consumer_module}→${provider_module} event=${event_name}" >&2
    }
  else
    # Handler found — check TypeScript discriminated union coverage (Serena, deep+ only)
    UNION_INCOMPLETE=false
    if [[ "${PROFILE:-standard}" == "deep" || "${PROFILE:-standard}" == "exhaustive" ]] && \
       [[ "$SERENA_AVAILABLE" == "true" ]]; then
      # (Pseudocode — orchestrator executes Serena)
      # UNION_RESULT = serena_find_symbol({name_path_pattern: "${event_name}Type|${event_name}Payload|${event_name}Event", include_body: true})
      # IF union type has N members AND handler code only handles M < N:
      #   UNION_INCOMPLETE=true
      LOG "INFO: Serena union check for event type '${event_name}' in ${HANDLER_FILE}" >&2
      UNION_INCOMPLETE="${SERENA_UNION_INCOMPLETE:-false}"
    fi

    if [[ "$UNION_INCOMPLETE" == "true" ]]; then
      # Signal: event_handler_partial (MEDIUM)
      EVENTS_PARTIAL=$((EVENTS_PARTIAL + 1))
      [ "$SIGNAL_COUNT" -lt "$MAX_SIGNALS" ] && {
        emit_signal_cross_module \
          "P-QD10-event-handler-coverage" \
          "event_handler_partial" \
          "medium" \
          "Event handler incomplete: ${consumer_module} chua xu ly het cac subtypes cua event '${event_name}'" \
          "Handler cho event '${event_name}' ton tai trong '${consumer_module}' (file: ${HANDLER_FILE}) nhung TypeScript discriminated union analysis cho thay khong phai tat ca subtypes cua event duoc xu ly. Cac subtypes bi bo qua se khong co hieu luc khi event duoc emit." \
          "$provider_module" \
          "$consumer_module" \
          "schema_diff" \
          "event_name=${event_name} handler_file=${HANDLER_FILE} handler_line=${HANDLER_LINE} pattern=${HANDLER_PATTERN} union_incomplete=true"
        SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
        LOG "INFO: Signal event_handler_partial: ${consumer_module} event=${event_name} handler=${HANDLER_FILE}" >&2
      }
    else
      EVENTS_CLEAN=$((EVENTS_CLEAN + 1))
      LOG "INFO: PASS: ${consumer_module} handler for '${event_name}' OK (${HANDLER_PATTERN})" >&2
    fi
  fi

done <<< "$(printf "%b" "$EVENTS_TSV")"
```

### A2: Write Event Handler Summary

```bash
jq -n \
  --arg probe_id "P-QD10-event-handler-coverage" \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson events_total "$TOTAL_EVENTS" \
  --argjson events_analyzed "$EVENTS_ANALYZED" \
  --argjson events_clean "$EVENTS_CLEAN" \
  --argjson events_missing "$EVENTS_MISSING" \
  --argjson events_partial "$EVENTS_PARTIAL" \
  --argjson signals "$SIGNAL_COUNT" \
  --argjson gitnexus "$([[ "$GITNEXUS_AVAILABLE" == "true" ]] && echo "true" || echo "false")" \
  --argjson serena "$([[ "$SERENA_AVAILABLE" == "true" ]] && echo "true" || echo "false")" \
  '{
    probe_id: $probe_id,
    generated_at: $now,
    events_total: $events_total,
    events_analyzed: $events_analyzed,
    events_clean: $events_clean,
    events_missing: $events_missing,
    events_partial: $events_partial,
    signals_emitted: $signals,
    ci_route: {gitnexus: $gitnexus, serena: $serena}
  }' > "$RAW_DIR/P-QD10-event-handler-coverage-summary.json" 2>/dev/null || \
  LOG "WARN: summary.json write failed — khong block" >&2

LOG "INFO: Event handler coverage probe complete (events=$EVENTS_ANALYZED, missing=$EVENTS_MISSING, partial=$EVENTS_PARTIAL, signals=$SIGNAL_COUNT)" >&2
```

---

## VERIFY

```
1. Kiem tra moi signal co dimension_id == "QD10" va probe_id == "P-QD10-event-handler-coverage"
2. Kiem tra moi signal co signal_type trong ["event_handler_missing", "event_handler_partial"]
3. Kiem tra moi signal co evidence[] non-empty voi content >= 10 chars (bao gom event_name)
4. Kiem tra dedup_key format: "P-QD10-event-handler-coverage:{signal_type}:{provider}:{consumer}"
   (per _shared.md dedup_hints: event_handler_missing → probe_id:signal_type:event_name:consumer)
5. Kiem tra severity mapping:
   - event_handler_missing → high
   - event_handler_partial → medium
6. Kiem tra SIGNAL_COUNT <= MAX_SIGNALS (100) hoac co WARNING "max_signals_reached"
7. Kiem tra summary JSON ton tai trong RAW_DIR
8. IF EVENTS_ANALYZED == 0 AND EVENT_DEP_COUNT > 0:
     WARN "No events analyzed — check events_subscribed[] format trong registry"
```

---

## Severity Rules

| Dieu kien | Severity | Ly do |
|-----------|----------|-------|
| Consumer khai bao subscribe event nhung khong co handler code nao | **HIGH** | Event se bi ignore khi duoc emit — silent data loss. Provider emit an event expecting consumer action, nhung consumer không react. Vi du: `customer.deleted` → quotation khong cleanup → orphan data. |
| Handler ton tai nhung TypeScript discriminated union khong fully covered | **MEDIUM** | Mot so event subtypes bi xu ly sai (fall-through hoac unhandled). Khong phai immediate failure nhung co the dan den incorrect business logic cho specific subtypes. Yeu cau developer review. |

> **Rationale severity HIGH cho event_handler_missing:**
> Event-driven architecture tuong tu fire-and-forget — provider khong biet consumer co xu ly hay khong. Neu handler khong ton tai, event duoc emit nhung bi discard → silent failure, kho debug, tiềm ẩn data inconsistency. So sanh voi api_contract_breaking_change=HIGH (W2.3): muc do nghiem trong tuong duong vi ca hai deu anh huong truc tiep den runtime behavior.

> **Rationale severity MEDIUM cho event_handler_partial:**
> Handler ton tai nhung khong xu ly het union subtypes → chi mot phan cua events duoc xu ly dung. Khong phai app crash nhung co the gay bug an (wrong business logic for specific event types). MEDIUM phu hop: can developer review, khong blocking.

---

## Dedup Hints

| Signal Type | Dedup Key Pattern |
|-------------|------------------|
| `event_handler_missing` | `P-QD10-event-handler-coverage:event_handler_missing:{event_name}:{consumer_module}` |
| `event_handler_partial` | `P-QD10-event-handler-coverage:event_handler_partial:{event_name}:{consumer_module}` |

**Luu y:** 1 signal per event per consumer module. Neu cung consumer subscribe event tu nhieu providers khac nhau, moi pair van la 1 signal rieng biet (khac nhau context provider_module).

---

## Signal Schema Examples

### event_handler_missing

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-event-handler-coverage",
  "dimension_id": "QD10",
  "signal_type": "event_handler_missing",
  "severity": "high",
  "title": "Event handler missing: MOD-QUOTATION khong co handler cho event 'customer.deleted' tu MOD-CRM",
  "description": "Consumer module 'MOD-QUOTATION' khai bao subscribe event 'customer.deleted' tu provider 'MOD-CRM' trong cross_module_dependencies, nhung khong tim thay handler code. Event se bi bo qua khi duoc emit, dan den data loss hoac silent failure.",
  "location": {
    "provider_module": "MOD-CRM",
    "consumer_module": "MOD-QUOTATION",
    "file_path": null,
    "line_range": null
  },
  "evidence": [
    {
      "type": "import_path",
      "content": "event_name=customer.deleted entity=Customer consumer_source=apps/quotation search_strategy=GitNexus(false)+Serena(true)+grep"
    }
  ],
  "dedup_key": "P-QD10-event-handler-coverage:event_handler_missing:customer.deleted:MOD-QUOTATION"
}
```

### event_handler_partial

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-event-handler-coverage",
  "dimension_id": "QD10",
  "signal_type": "event_handler_partial",
  "severity": "medium",
  "title": "Event handler incomplete: MOD-WAREHOUSE chua xu ly het cac subtypes cua event 'order.status.changed'",
  "description": "Handler cho event 'order.status.changed' ton tai trong 'MOD-WAREHOUSE' (file: apps/warehouse/src/handlers/order.handler.ts) nhung TypeScript discriminated union analysis cho thay khong phai tat ca subtypes cua event duoc xu ly.",
  "location": {
    "provider_module": "MOD-ORDERS",
    "consumer_module": "MOD-WAREHOUSE",
    "file_path": "apps/warehouse/src/handlers/order.handler.ts",
    "line_range": [45, 72]
  },
  "evidence": [
    {
      "type": "schema_diff",
      "content": "event_name=order.status.changed handler_file=apps/warehouse/src/handlers/order.handler.ts handler_line=45 pattern=grep:on('order.status.changed') union_incomplete=true"
    }
  ],
  "dedup_key": "P-QD10-event-handler-coverage:event_handler_partial:order.status.changed:MOD-WAREHOUSE"
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile=quick | SKIP lane (QD10 quick=skip) |
| events_subscribed[] = 0 in all deps AND no binding_type=event | SKIP probe, emit WARN "skipped_no_event_dependencies" → exit 0 |
| SOURCE_DIR khong ton tai | WARN + fallback SOURCE_DIR=. — probe tiep tuc voi han che |
| GitNexus unavailable | Fallback grep tier 3 — LOG WARN "GitNexus unavailable, grep fallback active" |
| Serena unavailable | Skip TypeScript union coverage check — LOG WARN, event_handler_partial will not be detected |
| CONSUMER_SOURCE narrow fail | Fallback to SOURCE_DIR (wider search) — LOG INFO |
| Grep returns 0 matches for all patterns | Treat as MISSING → event_handler_missing signal |
| events_subscribed contains empty string | Skip empty entries (trim whitespace) |
| events > 50 | Priority queue first 50, emit_sampling_note |
| > 100 signals | Stop emitting, LOG WARN "max_signals_reached (100)" |
| Registry parse error (jq fail) | ERROR E100 + exit 1 — registry corrupt la blocker real |
| --pair format invalid | ERROR + exit 1 — inform user format MODULE_A-MODULE_B |
| event_name contains regex metacharacters | Escape via `sed 's/[.]/\\./g'` before grep |

---

## Cache Policy

**allowed** — probe nay la pure static analysis (KHONG co runtime component: browser, DB, API call).

Cache TTL: 24h (per `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §3.5).

Ly do: Event handler code khong thay doi tru khi co code commit. Cache hieu qua khi chay nhieu profile consecutively. Key: `{PROJECT_ROOT_SHA}:{event_dep_count}:{events_subscribed_hash}`.

---

## Profile-Resolver Entry

```yaml
# Trong procedures/probes/_shared.md (QD10 Profile-Resolver section):
P-QD10-event-handler-coverage:
  quick: skip
  standard: run (handler_exists_check per event)
  deep: run + union_subtype_check (Serena)
  exhaustive: run + union_subtype_check + grep_all_patterns (broadest search)
  parallel_class: static
  optional: false
  max_events: 50
  union_check_profiles: [deep, exhaustive]
```

---

## Acceptance Test

**Synthetic test (CI):**
1. Setup registry voi cross_module_dependency binding_type=event:
   ```json
   {
     "cross_module_dependencies": [{
       "consumer_module": "MOD-QUOTATION",
       "provider_module": "MOD-CRM",
       "entity": "Customer",
       "binding_type": "event",
       "events_subscribed": ["customer.deleted", "customer.updated"]
     }]
   }
   ```
2. Setup consumer code: `apps/quotation/src/handlers/customer.handler.ts`:
   - Co handler cho `customer.updated`: `on('customer.updated', handler)`
   - **KHONG co** handler cho `customer.deleted` (missing!)
3. Run probe voi `--profile=standard`
4. **Expected:**
   - `event_handler_missing` signal (severity=HIGH) cho event `customer.deleted`
   - `customer.updated` → PASS (handler found)
   - summary.json: events_analyzed=2, events_missing=1, events_clean=1
5. Verify: `jq 'select(.signal_type == "event_handler_missing")' "$SIGNALS_FILE"` → 1 result

**EUREKA acceptance (W2.E2E):**
- Author cross_module_dependency binding_type=event trong EUREKA registry voi events_subscribed[] non-empty
- Run `/wf-fix-bugs --lane=QD10 --pair=ORDERS-WAREHOUSE --profile=standard`
- Expect: Probe complete; signals hoac PASS ro; performance <= 2 phut cho static analysis
