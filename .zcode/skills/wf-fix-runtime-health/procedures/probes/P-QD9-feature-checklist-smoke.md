# P-QD9-feature-checklist-smoke — Feature Checklist Smoke Test

> **Type:** runtime (Playwright bash-level) | **Profile:** deep, exhaustive | **Cache:** skip (always runtime)
> **Parallel class:** runtime → sequential (browser session; chay sau P-QD9-auth-aware-smoke)
> **Signal types:** `feature_route_broken` (HIGH), `feature_cta_missing` (HIGH), `feature_state_not_changed` (MEDIUM), `runtime_console_error` (MEDIUM), `runtime_uncaught_exception` (CRITICAL)
> **Error code:** E098 (feature_route_broken)

Doc `req-registry.json` features co `impl_status == "done"`, loc nhung feature co UI route (co FEAT- prefix UI- artifacts hoac route_map), navigate, kiem tra CTA visible + clickable, verify state change. Emit signal `feature_route_broken` (HIGH) khi impl_status=done nhung UI bi hong. Ghi `flow-unreliable.json` de QD10 skip broken flows. CI-ROUTE: GitNexus `query("{feature_name}")` PRIMARY de trace feature → UI route; Serena `find_referencing_symbols` REQ-ID PRIMARY de verify code reference.

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| Navigation spec parsing (`$NAV_SPEC_FILES` + `$SPEC_ROUTES[]`) | `QD1 P-QD1-orphan-ui-detect.md` | `:62-65` | `NAV_SPEC_FILES=$(find .mc-data/docs/phase4-ux -name "Navigation-*.md" 2>/dev/null)` → parse routes |
| Feature spec discovery (`$FEATURE_SPEC_FILES` + `$FEATURE_UI_REFS[]`) | `QD1 P-QD1-orphan-ui-detect.md` | `:70-75` | `find .mc-data/docs/phase2-features -name "*.md"` → scan UI sections |
| Registry query (`impl_status == "done"` filter) | `QD1 P-QD1-req-registry-xref.md` | `:38-40` | `jq '.requirements[] \| select(.impl_status == "done")'` pattern |
| Browser launch + close | `procedures/probes/_shared.md` | `:26-44` | `pw_launch` / `pw_close` + trap EXIT |
| `emit_signal_browser` pattern | `procedures/probes/_shared.md` | `:51-86` | signal-v2 schema, atomic append toi RAW_DIR/probe_id.jsonl |
| `emit_signal_no_location` pattern | `procedures/probes/_shared.md` | `:88-106` | Cho feature-level signals khong co URL cu the |
| Common variables + `FLOW_UNRELIABLE` | `procedures/probes/_shared.md` | `:7-18` | `LANE_DIR, RAW_DIR, SESSION_FILE, AUTH_SESSION, FLOW_UNRELIABLE, DEV_SERVER_STATE` |
| Console/network polling sau moi navigate | `QD9 P-QD9-console-network-monitor.md` | `:186-305` | pw_console + pw_network sau moi page navigate |
| Auth session reuse | `QD9 P-QD9-auth-aware-smoke.md` | `:1-8 (PRE-GATE)` | Doc `AUTH_SESSION` de inject vao Playwright truoc khi traverse feature routes |
| DEV_SERVER_STATE check | `QD9 P-QD9-auth-aware-smoke.md` | `:52-57 (PRE-GATE)` | Verify dev server ready truoc khi chay browser probe |

**Diff so voi P-QD9-auth-aware-smoke:**
- Probe nay focus vao *feature-level* check (impl_status=done → smoke visible + CTA + state change).
- Traverse chi *feature routes* (tu registry), khong traverse tat ca routes tu homepage.
- Ghi `FLOW_UNRELIABLE` de coordinate voi QD10 downstream.
- Dung registry + feature specs lam input list (khong chi `<a href>` traversal).
- Sampling khi > 50 features: priority queue (CRITICAL features first) → max 50.

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Trace feature → UI route | **GitNexus** `query("{feature_name}")` | Grep REQ-ID trong source + phase4-ux route specs | Xac dinh route path tuong ung voi FEAT-ID trong registry |
| Verify feature co code reference | **Serena** `find_referencing_symbols({name_path: "REQ-ID-value", relative_path: null})` | Grep REQ-ID trong source | Dam bao feature impl_status=done co annotation trong code |
| Locate primary CTA handler | **Serena** `find_symbol({name_path_pattern: "feature-keyword", relative_path: null, include_body: false})` | Grep click handler / onClick trong component dir | Map CTA text → component → verify onClick logic |
| Map broken route → source | **Serena** `find_symbol({relative_path: "<file-tu-stack>"})` | Parse file:line tu stack trace | Populate evidence.location khi co crash/error |

**Khi CI unavailable:** Set `$GITNEXUS_AVAILABLE` / `$SERENA_AVAILABLE` tu `ci-detect.sh` output. Log warning:
```bash
echo "WARN: CI tool unavailable, fell back to Grep — feature route coverage may degrade" >&2
```
Khong block probe. Graceful fallback: Grep REQ-ID annotations + Navigation spec parsing.

---

## PRE-GATE

```
1. IF profile=quick OR profile=standard: SKIP probe, note "QD9-deep-only-feature-checklist-skip"
   → Chi chay khi profile=deep hoac exhaustive
2. IF --no-browser: SKIP probe (da SKIP toan lane E093 — probe nay khong duoc goi)
3. IF DEV_SERVER_STATE khong ton tai HOAC DEV_SERVER_STATE.status == "fail":
     SKIP probe, note "skipped_dev_server_not_ready (E095 upstream)"
4. Read BASE_URL tu DEV_SERVER_STATE.url
5. IF BASE_URL == null hoac "": SKIP probe, note "skipped_no_base_url"
6. Load CI availability:
     source <(bash .claude/scripts/ci-detect.sh --project-root "$PROJECT_ROOT" 2>/dev/null) || true
     GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
     SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"
7. Read REGISTRY_FILE=".mc-data/docs/_meta/req-registry.json"
   IF khong ton tai HOAC empty: SKIP probe, note "skipped_no_registry"
8. IF AUTH_SESSION ton tai va non-empty:
     LOG "INFO: AUTH_SESSION found — will inject cookies for protected routes"
   ELSE:
     LOG "INFO: AUTH_SESSION khong co — traverse feature routes without auth (some may return 401)"
```

---

## SENSE

### S1: Query registry — lay done features co UI

```bash
REGISTRY_FILE=".mc-data/docs/_meta/req-registry.json"

# Doc features/requirements voi impl_status=done
# (Reuse registry query pattern tu QD1 P-QD1-req-registry-xref.md:38-40)
DONE_FEATURES=$(jq -r '
  .requirements[]?
  | select(.impl_status == "done")
  | select(
      (.feature_ids // []) | length > 0
      or (.ui_routes // []) | length > 0
    )
  | {
      req_id: .req_id,
      title: (.title // .description // "unknown"),
      feature_ids: (.feature_ids // []),
      ui_routes: (.ui_routes // []),
      impl_status: .impl_status
    }
' "$REGISTRY_FILE" 2>/dev/null || echo "[]")

# Fallback: neu khong co ui_routes field → scan features[] structure
if [ "$DONE_FEATURES" = "[]" ] || [ -z "$DONE_FEATURES" ]; then
  DONE_FEATURES=$(jq -r '
    .features[]?
    | select(.impl_status == "done")
    | select((.route // "") != "")
    | {
        feat_id: .feat_id,
        title: (.title // "unknown"),
        route: .route,
        impl_status: .impl_status
      }
  ' "$REGISTRY_FILE" 2>/dev/null || echo "[]")
fi

FEATURE_COUNT=$(echo "$DONE_FEATURES" | jq 'length' 2>/dev/null || echo 0)
```

### S2: Thu thap Navigation specs — xac dinh route_map (REUSE QD1 orphan-ui-detect B3)

```bash
# Reuse NAV_SPEC_FILES pattern tu QD1 P-QD1-orphan-ui-detect.md:62-65
NAV_SPEC_FILES=$(find .mc-data/docs/phase4-ux -name "Navigation-*.md" 2>/dev/null)

# Build SPEC_ROUTES[] tu Navigation specs
SPEC_ROUTES=()
for NAV_FILE in $NAV_SPEC_FILES; do
  # Extract route paths tu markdown tables (format: | /path | label | parent | visible |)
  while IFS='|' read -r _ path label parent visible _; do
    path=$(echo "$path" | tr -d ' ')
    [[ "$path" =~ ^/ ]] && SPEC_ROUTES+=("$path")
  done < <(grep '^\s*|' "$NAV_FILE" | grep -v 'path\|---' 2>/dev/null || true)
done
```

### S3: Thu thap Feature specs — xac dinh UI requirements (REUSE QD1 orphan-ui-detect B4)

```bash
# Reuse FEATURE_SPEC_FILES pattern tu QD1 P-QD1-orphan-ui-detect.md:70-75
FEATURE_SPEC_FILES=$(find .mc-data/docs/phase2-features -name "*.md" 2>/dev/null)

# Parse feature specs de lay route hints
FEATURE_ROUTE_MAP=()  # array: "FEAT_ID:route"
for SPEC_FILE in $FEATURE_SPEC_FILES; do
  # Tim route mentions trong sections: UI, Screens, Pages, Navigation
  FEAT_ID=$(grep -oE 'FEAT-[A-Z]+-[A-Z]+-[0-9]+' "$SPEC_FILE" | head -1 || true)
  ROUTE_HINT=$(grep -oE '/[a-z][a-z0-9/-]*' "$SPEC_FILE" | head -3 | tr '\n' ',' || true)
  [ -n "$FEAT_ID" ] && [ -n "$ROUTE_HINT" ] && FEATURE_ROUTE_MAP+=("$FEAT_ID:$ROUTE_HINT")
done
```

### S4: CI Enrichment — GitNexus trace feature → UI route (PRIMARY)

```bash
if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # Per feature: GitNexus query("feature_id") de augment route hint
  # Pseudocode (orchestrator agent thuc hien):
  # FOR each done_feature trong DONE_FEATURES (sampled):
  #   IF ui_routes[] empty hoac route khong ro:
  #     result = mcp__gitnexus__gitnexus_query({query: done_feature.title})
  #     IF result has route-like paths:
  #       done_feature.ui_routes += result.routes
  LOG "INFO: GitNexus available — augmenting feature route discovery"
fi
```

---

## THINK

### Build feature checklist voi route priority

```bash
# Sampling: neu > 50 features (P3 economy, Section 6.3)
MAX_FEATURES=50
if [ "$FEATURE_COUNT" -gt "$MAX_FEATURES" ]; then
  LOG "WARN: $FEATURE_COUNT done features found, sampling $MAX_FEATURES (CRITICAL priority first)"
  # Priority queue: features co priority=CRITICAL hoac severity=HIGH tu registry truoc
  DONE_FEATURES=$(echo "$DONE_FEATURES" | jq --argjson max "$MAX_FEATURES" '
    sort_by((.priority // "NORMAL") | if . == "CRITICAL" then 0 elif . == "HIGH" then 1 else 2 end)
    | .[0:$max]
  ')
fi

# Build CHECKLIST[]: [{feat_id, title, route, req_id}]
# Priority route resolution:
#   1. registry.ui_routes[0] → su dung truc tiep
#   2. SPEC_ROUTES[] match theo feat title keywords
#   3. FEATURE_ROUTE_MAP match theo FEAT_ID
#   4. GitNexus augmented (S4)
#   5. Fallback: skip feature neu khong co route
CHECKLIST=$(echo "$DONE_FEATURES" | jq '
  map(
    . + {
      route: (
        (.ui_routes[0] // null)
        // (.route // null)
        // null
      )
    }
  )
  | map(select(.route != null))
')
CHECKLIST_COUNT=$(echo "$CHECKLIST" | jq 'length')
LOG "INFO: $CHECKLIST_COUNT features scheduled for UI smoke check"
```

---

## ACT

### A0: Acquire browser session

```bash
pw_launch || {
  echo "ERROR: Cannot acquire browser lock E096" >&2
  exit 1
}
trap "pw_close; cleanup_dev_server_if_owned" EXIT
```

### A1: Inject auth session (neu co)

```bash
if [ -s "$AUTH_SESSION" ]; then
  # Doc cookies tu auth-session.json va inject vao browser context
  # (Reuse pattern tu P-QD9-auth-aware-smoke step A1 cookie inject)
  AUTH_COOKIES=$(jq -r '.cookies // []' "$AUTH_SESSION")
  if [ "$AUTH_COOKIES" != "[]" ]; then
    # Inject via pw_evaluate
    # pw_evaluate({expression: "document.cookie = '...';"})
    LOG "INFO: Auth cookies injected from AUTH_SESSION"
  fi
fi
```

### A2: Navigate homepage de set context truoc khi traverse features

```bash
# pw_navigate "{url: "$BASE_URL", wait_until: "networkidle"}
# pw_snapshot
LOG "INFO: Homepage loaded at $BASE_URL"
```

### A3: Per-feature smoke loop

```bash
BROKEN_FEATURES=()
FLOW_UNRELIABLE_MAP="{}"

while IFS= read -r FEAT_ENTRY; do
  FEAT_ID=$(echo "$FEAT_ENTRY" | jq -r '.feat_id // .req_id // "unknown"')
  FEAT_TITLE=$(echo "$FEAT_ENTRY" | jq -r '.title // "unknown"')
  ROUTE=$(echo "$FEAT_ENTRY" | jq -r '.route')
  ROUTE_URL="$BASE_URL$ROUTE"

  LOG "INFO: Checking feature $FEAT_ID ($FEAT_TITLE) → $ROUTE_URL"

  # Step 1: Navigate toi feature route
  NAV_RESULT=$(pw_ --url "$ROUTE_URL" --wait_until "networkidle" 2>&1 || echo "NAV_ERROR")
  if [[ "$NAV_RESULT" == *"NAV_ERROR"* ]] || [[ "$NAV_RESULT" == *"ERR_"* ]]; then
    emit_signal_browser "P-QD9-feature-checklist-smoke" \
      "feature_route_broken" "high" \
      "Feature route unreachable: $FEAT_TITLE ($FEAT_ID)" \
      "Navigate toi route $ROUTE_URL that bai (network error). Feature impl_status=done nhung route khong accessible." \
      "$ROUTE_URL" "log_excerpt" "NAV_ERROR: $NAV_RESULT" "null"
    BROKEN_FEATURES+=("$FEAT_ID")
    FLOW_UNRELIABLE_MAP=$(echo "$FLOW_UNRELIABLE_MAP" | jq --arg fid "$FEAT_ID" '. + {($fid): true}')
    continue
  fi

  # Step 2: Snapshot DOM va check HTTP status
  SNAPSHOT=$(pw_snapshot 2>&1 || echo "")
  CURRENT_URL=$(pw_evaluate ""window.location.href" 2>&1 || echo ""
  NETWORK_REQS=$(pw_network 2>&1 || echo "[]")

  # Check redirect to login (401/403 → auth wall → signal MEDIUM, khong BROKEN)
  PAGE_STATUS=$(echo "$NETWORK_REQS" | jq -r --arg url "$ROUTE_URL" '
    .[] | select(.url | startswith($url)) | .status
  ' 2>/dev/null | head -1 || echo "")

  if [[ "$PAGE_STATUS" == "401" ]] || [[ "$PAGE_STATUS" == "403" ]]; then
    LOG "INFO: Feature $FEAT_ID route $ROUTE requires auth (got $PAGE_STATUS) — skipping (auth context may be insufficient)"
    continue
  fi

  if [[ "$PAGE_STATUS" == "404" ]] || [[ "$PAGE_STATUS" == "500" ]]; then
    SCREENSHOT_PATH="$RAW_DIR/screenshot-$FEAT_ID-broken.png"
    pw_screenshot "$SCREENSHOT_PATH" 2>/dev/null || true
    emit_signal_browser "P-QD9-feature-checklist-smoke" \
      "feature_route_broken" "high" \
      "Feature route returns HTTP $PAGE_STATUS: $FEAT_TITLE ($FEAT_ID)" \
      "Route $ROUTE tra ve HTTP $PAGE_STATUS. Feature impl_status=done nhung trang hien loi — nguoi dung khong truy cap duoc." \
      "$ROUTE_URL" "screenshot" "HTTP $PAGE_STATUS at $ROUTE_URL" "\"$SCREENSHOT_PATH\""
    BROKEN_FEATURES+=("$FEAT_ID")
    FLOW_UNRELIABLE_MAP=$(echo "$FLOW_UNRELIABLE_MAP" | jq --arg fid "$FEAT_ID" '. + {($fid): true}')
    continue
  fi

  # Check console errors sau navigate (REUSE console-monitor polling pattern :186-305)
  CONSOLE_MSGS=$(pw_console 2>&1 || echo "[]")
  CONSOLE_ERRORS=$(echo "$CONSOLE_MSGS" | jq -r '.[] | select(.type == "error") | .text' 2>/dev/null || echo "")
  if [ -n "$CONSOLE_ERRORS" ]; then
    # Truncate theo Output Truncation rules (max 500 chars)
    CONSOLE_TRUNCATED="${CONSOLE_ERRORS:0:500}"
    emit_signal_browser "P-QD9-feature-checklist-smoke" \
      "runtime_console_error" "medium" \
      "Console error khi load feature: $FEAT_TITLE ($FEAT_ID)" \
      "Sau khi navigate toi feature route $ROUTE, phat hien console error: ${CONSOLE_TRUNCATED}..." \
      "$ROUTE_URL" "log_excerpt" "$CONSOLE_TRUNCATED" "null"
    # Console error alone khong mark BROKEN — tiep tuc check CTA
  fi

  # Step 3: Check feature primary CTA visible + clickable
  # Tim button/CTA lien quan den feature (theo title keywords)
  FEAT_KEYWORDS=$(echo "$FEAT_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '|')
  CTA_FOUND=$(echo "$SNAPSHOT" | grep -iE "button|btn|submit|action" | grep -iE "$FEAT_KEYWORDS" | head -1 || echo "")

  if [ -z "$CTA_FOUND" ]; then
    # Fallback: tim any primary action button tren trang
    CTA_FOUND=$(echo "$SNAPSHOT" | grep -iE '<button[^>]*>|role="button"' | head -1 || echo "")
  fi

  if [ -z "$CTA_FOUND" ]; then
    LOG "INFO: Feature $FEAT_ID: Khong tim thay primary CTA tren route $ROUTE — co the la view-only page (skip CTA check)"
    continue
  fi

  # Step 4: Click CTA + wait + verify state change
  # (chi click neu CTA khong phai destructive action)
  IS_DESTRUCTIVE=$(echo "$CTA_FOUND" | grep -iE "delete|remove|destroy|logout|dang xuat" | wc -l || echo 0)
  if [ "$IS_DESTRUCTIVE" -gt 0 ]; then
    LOG "INFO: Feature $FEAT_ID: CTA la destructive action — skip click (BHV-002: khong thay doi state production)"
    continue
  fi

  # Capture DOM hash truoc click
  DOM_BEFORE=$(pw_evaluate ""document.body.innerHTML.length" 2>&1 || echo "0"
  URL_BEFORE=$(pw_evaluate ""window.location.href" 2>&1 || echo ""

  # Click CTA (dung ARIA/text selector)
  CTA_SELECTOR=$(echo "$CTA_FOUND" | grep -oE 'text="[^"]+"' | head -1 || echo "button")
  pw_click "$CTA_SELECTOR" 2>/dev/null || true
  pw_ --time 2000 2>/dev/null || true

  # Capture state sau click
  DOM_AFTER=$(pw_evaluate ""document.body.innerHTML.length" 2>&1 || echo "0"
  URL_AFTER=$(pw_evaluate ""window.location.href" 2>&1 || echo ""

  # Step 5: Verify state change
  DOM_CHANGED=$([[ "$DOM_BEFORE" != "$DOM_AFTER" ]] && echo "true" || echo "false")
  URL_CHANGED=$([[ "$URL_BEFORE" != "$URL_AFTER" ]] && echo "true" || echo "false")
  MODAL_APPEARED=$(pw_snapshot 2>&1 | grep -iE "modal|dialog|popup" | wc -l || echo 0)

  if [[ "$DOM_CHANGED" == "false" ]] && [[ "$URL_CHANGED" == "false" ]] && [ "$MODAL_APPEARED" -eq 0 ]; then
    # CTA click khong co effect → feature_state_not_changed (MEDIUM)
    SCREENSHOT_PATH="$RAW_DIR/screenshot-$FEAT_ID-cta-no-response.png"
    pw_screenshot "$SCREENSHOT_PATH" 2>/dev/null || true
    emit_signal_browser "P-QD9-feature-checklist-smoke" \
      "feature_state_not_changed" "medium" \
      "CTA khong phan ung: $FEAT_TITLE ($FEAT_ID)" \
      "Sau khi click primary CTA ($CTA_SELECTOR) tren route $ROUTE, khong co thay doi: DOM length $DOM_BEFORE→$DOM_AFTER, URL: $URL_BEFORE→$URL_AFTER, khong co modal. Feature co the bi broken hoac CTA selector khong chinh xac." \
      "$ROUTE_URL" "screenshot" "CTA_SELECTOR: $CTA_SELECTOR | DOM: $DOM_BEFORE→$DOM_AFTER | URL: $URL_BEFORE→$URL_AFTER" "\"$SCREENSHOT_PATH\""
    # feature_state_not_changed = MEDIUM → khong mark BROKEN (co the la expected behavior)
  fi

  # Navigate back cho feature tiep theo
  pw_back 2>/dev/null || \
    pw_ --url "$BASE_URL" --wait_until "domcontentloaded" 2>/dev/null || true

done < <(echo "$CHECKLIST" | jq -c '.[]')
```

### A4: Ghi flow-unreliable.json cho QD10

```bash
# Ghi FLOW_UNRELIABLE map ra file (QD10 P-QD10-business-flow-runtime se doc)
# (Declared trong _contract.json: $SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/flow-unreliable.json)
FLOW_UNRELIABLE_OUT="{
  \"\$schema\": \"flow-unreliable-v1\",
  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"probe_id\": \"P-QD9-feature-checklist-smoke\",
  \"broken_count\": ${#BROKEN_FEATURES[@]},
  \"flows\": $FLOW_UNRELIABLE_MAP
}"

echo "$FLOW_UNRELIABLE_OUT" | jq '.' > "$FLOW_UNRELIABLE" 2>/dev/null || \
  echo "$FLOW_UNRELIABLE_OUT" > "$FLOW_UNRELIABLE"

LOG "INFO: flow-unreliable.json written — ${#BROKEN_FEATURES[@]} broken features. QD10 will skip these flows."
```

### A5: Write raw signals JSONL

```bash
# Atomic write signals file (CORE-031 + signal-emit.md pattern)
jq -n \
  --arg probe "P-QD9-feature-checklist-smoke" \
  --arg lane "wf-fix-runtime-health" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson checklist_count "$CHECKLIST_COUNT" \
  --argjson broken_count "${#BROKEN_FEATURES[@]}" \
  '{
    "$schema": "lane-signals-v1",
    probe_id: $probe,
    lane: $lane,
    generated_at: $ts,
    meta: {
      features_checked: $checklist_count,
      features_broken: $broken_count,
      sampling: null
    }
  }' > "$RAW_DIR/P-QD9-feature-checklist-smoke.meta.json"
```

---

## VERIFY

```
1. Kiem tra FLOW_UNRELIABLE file ton tai va la valid JSON:
   jq '.' "$FLOW_UNRELIABLE" > /dev/null 2>&1 || LOG "ERROR: flow-unreliable.json invalid JSON"
2. Kiem tra moi signal co evidence.content non-empty
3. Kiem tra moi signal co signal_type trong:
   [feature_route_broken, feature_cta_missing, feature_state_not_changed,
    runtime_console_error, runtime_uncaught_exception]
4. Kiem tra feature_route_broken signals co screenshot_path non-null
5. Kiem tra moi signal co dedup_hints voi feature_id identifier
6. Drop signals voi confidence = 0 (skipped features, auth-walled routes)
7. Verify CHECKLIST_COUNT duoc log trong meta.json
```

---

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| Feature impl_status=done nhung route returns 4xx/5xx | HIGH |
| Feature impl_status=done nhung navigate that bai (network error) | HIGH |
| CTA missing sau navigate (khong tim thay button/action) | HIGH |
| Runtime console error khi load feature page | MEDIUM |
| CTA click khong co state change (DOM + URL khong doi) | MEDIUM |
| Runtime uncaught exception (pageerror) | CRITICAL |

---

## Dedup Hints

Moi signal phai co `dedup_hints` array:

| Signal Type | Dedup Hint Pattern |
|-------------|-------------------|
| `feature_route_broken` | `["feature-broken:{feat_id}:{route}:{status_code}"]` |
| `feature_cta_missing` | `["feature-cta-missing:{feat_id}:{route}"]` |
| `feature_state_not_changed` | `["feature-no-state:{feat_id}:{cta_selector}"]` |
| `runtime_console_error` | `["console-error:{route}:{error_prefix_20chars}"]` (reuse QD9 pattern) |
| `runtime_uncaught_exception` | `["uncaught:{route}:{message_prefix_20chars}"]` |

Aggregator dedup theo array intersection: 2 signals la duplicate neu cung feat_id + signal_type.

---

## Signal Schemas

### feature_route_broken

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-feature-checklist-smoke",
  "dimension_id": "QD9",
  "signal_type": "feature_route_broken",
  "severity": "high",
  "title": "Feature route broken: <FEAT_ID> — <FEAT_TITLE>",
  "description": "Feature voi impl_status=done nhung route <ROUTE> tra ve HTTP <STATUS>. Nguoi dung khong truy cap duoc tinh nang da duoc implement.",
  "location": {"url": "<ROUTE_URL>"},
  "evidence": [
    {"type": "screenshot", "content": "<screenshot_path>"},
    {"type": "log_excerpt", "content": "HTTP <STATUS> at <ROUTE_URL>"}
  ],
  "screenshot": "<screenshot_path>",
  "cdg_flags": [],
  "fixability": "agent_fix",
  "dedup_hints": ["feature-broken:<FEAT_ID>:<ROUTE>:<STATUS>"]
}
```

### feature_state_not_changed

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-feature-checklist-smoke",
  "dimension_id": "QD9",
  "signal_type": "feature_state_not_changed",
  "severity": "medium",
  "title": "CTA khong co phan ung: <FEAT_ID> — <FEAT_TITLE>",
  "description": "Sau khi click primary CTA (<CTA_SELECTOR>), khong co state change. DOM length: <BEFORE> → <AFTER>. Co the la broken handler hoac selector sai.",
  "location": {"url": "<ROUTE_URL>"},
  "evidence": [
    {"type": "screenshot", "content": "<screenshot_path>"},
    {"type": "log_excerpt", "content": "CTA: <CTA_SELECTOR> | DOM: <BEFORE>→<AFTER> | URL: <URL_BEFORE>→<URL_AFTER>"}
  ],
  "screenshot": "<screenshot_path>",
  "cdg_flags": [],
  "fixability": "agent_fix",
  "dedup_hints": ["feature-no-state:<FEAT_ID>:<CTA_SELECTOR>"]
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile=quick hoac standard | SKIP probe, note "QD9-deep-only-feature-checklist-skip" |
| DEV_SERVER_STATE khong co hoac failed | SKIP probe, note "skipped_dev_server_not_ready" |
| Registry file khong co | SKIP probe, note "skipped_no_registry" |
| Registry co < 1 done feature | Skip loop, note "no_done_features" — khong emit signal |
| Feature khong co route | Skip feature, note "no_route_{feat_id}" — continue loop |
| Navigate that bai (network error) | Emit feature_route_broken HIGH, add to FLOW_UNRELIABLE |
| CTA khong tim thay (view-only page) | Skip CTA step, note "no_cta_{feat_id}" — continue |
| CTA la destructive action | Skip click (BHV-002) — khong emit signal |
| Auth-walled route (401/403) | Skip feature, note "auth_required_{feat_id}" — khong mark BROKEN |
| GitNexus unavailable | Fallback to Grep + Navigation spec parsing — log warning |
| Serena unavailable | Fallback to Grep REQ-ID in source — log warning |
| > 50 done features | Priority sampling: CRITICAL first, max 50. Log sampling stats |
| DOM compare fail (JS eval error) | Skip state-check step, emit MEDIUM signal "state_check_failed" |
| Qua nhieu signals (> 50) | Cap max_signals_per_probe, drop lowest severity |
| FLOW_UNRELIABLE write fail | Log error — khong block probe (QD10 graceful degrade) |

---

## Cache Policy

**skip** — probe nay la runtime (Playwright browser execution). KHONG cache results.

Ly do: feature smoke kiem tra *state tai thoi diem chay* — cache sai se mask broken features moi.

Exception: S3 (feature spec parsing tu `.mc-data/docs/phase2-features/`) co the cache voi TTL 24h per spec file (su dung `_shared/scan_cache/` neu available va `--use-cache` flag set).

---

## Profile-Resolver Entry

```yaml
# Trong _shared/lane/profile-resolver.md (QD9 section):
P-QD9-feature-checklist-smoke:
  quick: skip
  standard: skip
  deep: run
  exhaustive: run (extended limits: max_features=100 thay vi 50)
  parallel_class: runtime
  optional: false
  max_features_by_profile:
    deep: 50
    exhaustive: 100
```

---

## Acceptance Test

**Synthetic test (CI):**
1. Tao mock registry voi 2 features co `impl_status: "done"`:
   - Feature A: route "/test-feature-working" → page 200 OK, button "Submit" → click → modal appear
   - Feature B: route "/test-feature-broken" → page 404
2. Run probe voi `--profile=deep` tren mock BASE_URL
3. **Expected:**
   - Feature A: khong co `feature_route_broken` signal
   - Feature B: `feature_route_broken` signal voi severity=HIGH trong signals.jsonl
   - `flow-unreliable.json` chua `{"FEAT-B": true}` (khong chua FEAT-A)
   - `broken_count: 1` trong meta.json
4. Verify `jq '.flows | keys | length == 1' flow-unreliable.json`

**EUREKA real-world acceptance (W1.5.E2E):**
- Chay `/wf-fix-bugs --lane=QD9 --profile=deep --scope=module --name=MOD-CRM` tren EUREKA erp-web
- Expect: ≥1 feature duoc kiem tra (MOD-CRM co features voi impl_status=done)
- Expect: Moi feature broken duoc ghi trong flow-unreliable.json
- Expect: lane-status.json chua probe P-QD9-feature-checklist-smoke status="completed"
- Performance: probe complete trong ≤ 5 phut cho module scope
