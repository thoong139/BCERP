# P-QD10-business-flow-runtime — E2E Business Flow Runtime Driver

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD10-business-flow-runtime |
| **Loai** | runtime (sequential E2E driver — per-step HTTP + optional Playwright) |
| **Profile** | exhaustive |
| **Muc dich** | Parse business-flow-spec YAML → execute steps sequentially (HTTP API calls or Playwright UI driver) → verify per-step assertions + global invariants → emit signals on failure. Consumes `.mc-data/docs/phase3-architecture/business-flows/*.yaml`. Validated against `.claude/doc-framework/_meta/business-flow-spec-schema.json`. |
| **Cache** | NOT allowed (runtime, creates fixture data) |
| **Error codes** | E100 (registry corrupt — QD10 base), E104 (production env block — creates data catastrophic), E107 (YAML/schema parse error), E111 (fixture setup fail — POST non-2xx), E112 (step wait_for timeout) |
| **Side effects** | YES — probe creates fixture entities via HTTP POST. Cleanup attempted after each flow (step.cleanup=true / fixture.cleanup_after_flow=true). Opt-in NOT required (no mutation of existing data; only creates new test entities). |
| **Migrates from** | (new in v9 — W4.4) |

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| HTTP curl GET/POST pattern | `QD1 P-QD1-api-smoke.md` | `:59-81 (ACT curl)` | Reuse curl with `-w "\n%{http_code}"` + BODY/CODE extraction; adapt for POST/PATCH/DELETE |
| Python3 YAML parse + glob | `P-QD10-state-machine-correctness.md` | `SENSE S1 (Python3 yaml.safe_load loop)` | Reuse yaml.safe_load glob pattern for business-flow-spec YAML |
| E104 production HARD BLOCK | `P-QD10-cache-staleness-probe.md` | `PRE-GATE Step 4` | Creates data — production block mandatory; DEPLOY_ENV + URL heuristic |
| QD9 auth session reuse | `procedures/probes/_shared.md` (QD10) | `_shared.md:19 (QD9_AUTH_SESSION)` | Optional token/cookie for API calls |
| QD9 flow-unreliable skip | `procedures/probes/_shared.md` (QD10) | `_shared.md:19 (FLOW_UNRELIABLE)` | Skip flows already known broken from QD9 |
| emit_signal_runtime_integration() | `procedures/probes/_shared.md` (QD10) | `:98-133` | Runtime signal emit with context JSON |
| with_runtime_cap timeout wrapper | `.claude/scripts/wf-fix-common.sh` | `:with_runtime_cap` | Enforced timeout per curl call |
| BASE_URL_ERP detection | `P-QD10-cache-staleness-probe.md` | `PRE-GATE Step 5` | QD9 dev-server-state → wf-fix-detect-base-url.sh fallback |

**Diff so voi P-QD10-cache-staleness-probe:**
- Cache-staleness: MUTATES existing entity, rollback sau test (PATCH)
- Business-flow-runtime: CREATES new test entities, delete sau flow (POST + DELETE cleanup)
- Business-flow-runtime: sequential step DAG (step N may depend on step N-1 output)
- Business-flow-runtime: assertion DSL (field/operator/expected — 10 operators)

---

## CI-ROUTE

| Task | Primary | Fallback | Ghi chu |
|------|---------|----------|---------|
| Locate step API handler | **Serena** `find_symbol(action_name, relative_path="apps/api/")` | Grep `router\.\|@Post\|@Get` + endpoint slug | Map spec action (e.g. create_quotation) to actual route |
| Trace step data flow | **GitNexus** `query("flow step {action}")` | Inspect API response body | Understand what entity a step creates (for ${step_id.field} resolution) |
| Locate cleanup endpoint | **Serena** `find_symbol(delete{Entity}\|remove{Entity})` | Grep `router.delete\|@Delete` | Find DELETE route for fixture teardown |
| Validate state change | **GitNexus** `query("state transition {entity}")` | Grep status assignment | Verify expected_state_change.to matches code transition |

**CI-ROUTE PRE-GATE (mandatory):**
Neu khong co Serena/GitNexus → ghi chu "CI_UNAVAILABLE: using API convention fallback" vao RAW output. Khong block probe execution.

---

## PRE-GATE

```bash
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD10-integration"
RAW_DIR="$LANE_DIR/raw"
SIGNALS_FILE="$LANE_DIR/signals.json"
REGISTRY_FILE=".mc-data/docs/_meta/req-registry.json"
FLOW_SPEC_DIR=".mc-data/docs/phase3-architecture/business-flows"
FLOW_SCHEMA=".claude/doc-framework/_meta/business-flow-spec-schema.json"

# Step 1: Profile gate — exhaustive only
if [ "${PROFILE:-standard}" != "exhaustive" ]; then
  echo "P-QD10-business-flow-runtime: SKIP profile=${PROFILE:-standard} (requires exhaustive)" >&2
  exit 0
fi

# Step 2: E104 production env HARD BLOCK (creates fixture data — catastrophic on production)
DEPLOY_ENV="${DEPLOY_ENV:-${NODE_ENV:-${RAILS_ENV:-${APP_ENV:-}}}}"
if echo "$DEPLOY_ENV" | grep -qiE '^(production|prod|live)$'; then
  echo "E104: HARD BLOCK — DEPLOY_ENV=$DEPLOY_ENV matches production pattern. Business flow probe creates data — REFUSED." >&2
  exit 1
fi
# Additional heuristic: BASE_URL contains prod domain
if echo "${BASE_URL_ERP:-}" | grep -qiE '\.(prod|live|erktransport\.com|production)'; then
  echo "E104: HARD BLOCK — BASE_URL_ERP appears to be production URL. Business flow probe creates data — REFUSED." >&2
  exit 1
fi

# Step 3: Python3 availability check
if ! command -v python3 &>/dev/null 2>&1; then
  echo "P-QD10-business-flow-runtime: SKIP python3 not available (required for YAML parse)" >&2
  exit 0
fi

# PyYAML check
if ! python3 -c "import yaml" 2>/dev/null; then
  echo "P-QD10-business-flow-runtime: SKIP PyYAML not installed (pip install pyyaml)" >&2
  exit 0
fi

# Step 4: Glob business-flow YAML specs
SPEC_COUNT=$(find "$FLOW_SPEC_DIR" \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | wc -l | tr -d '[:space:]')
if [ "${SPEC_COUNT:-0}" -eq 0 ]; then
  echo "P-QD10-business-flow-runtime: SKIP no business-flow specs found in $FLOW_SPEC_DIR" >&2
  echo "  Add .yaml files to $FLOW_SPEC_DIR to enable this probe." >&2
  exit 0
fi
echo "P-QD10-business-flow-runtime: PRE-GATE found $SPEC_COUNT flow spec(s)" >&2

# Step 5: Validate each spec against JSON schema (E107 on fail)
if [ -f "$FLOW_SCHEMA" ]; then
  validate_ok=true
  while IFS= read -r spec_file; do
    python3 - "$spec_file" "$FLOW_SCHEMA" <<'PYEOF' 2>&1 | head -5 >&2
import sys, json, yaml
spec_path, schema_path = sys.argv[1], sys.argv[2]
try:
    import jsonschema
    with open(spec_path, encoding="utf-8") as f: spec = yaml.safe_load(f)
    with open(schema_path, encoding="utf-8") as f: schema = json.load(f)
    jsonschema.validate(spec, schema)
except jsonschema.ValidationError as e:
    print(f"E107: Schema validation failed in {spec_path}: {e.message}", file=sys.stderr); sys.exit(1)
except (yaml.YAMLError, json.JSONDecodeError) as e:
    print(f"E107: Parse error in {spec_path}: {e}", file=sys.stderr); sys.exit(1)
except ImportError:
    pass  # jsonschema not installed — skip validation
PYEOF
    if [ $? -ne 0 ]; then
      echo "E107: ABORT — spec validation failed for $spec_file. Fix spec before running probe." >&2
      exit 1
    fi
  done < <(find "$FLOW_SPEC_DIR" \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null)
fi

# Step 6: QD9 flow_unreliable load (flows to skip)
FLOW_UNRELIABLE_LIST=""
if [ -n "${FLOW_UNRELIABLE:-}" ] && [ -f "$FLOW_UNRELIABLE" ]; then
  FLOW_UNRELIABLE_LIST=$(jq -r '.[] | .flow_id // .id // empty' "$FLOW_UNRELIABLE" \
    2>/dev/null | tr -d '\r' | paste -sd ',' - || true)
fi

# Step 7: BASE_URL_ERP load
if [ -z "${BASE_URL_ERP:-}" ]; then
  if [ -n "${QD9_DEV_SERVER_STATE:-}" ] && [ -f "$QD9_DEV_SERVER_STATE" ]; then
    BASE_URL_ERP=$(jq -r '.primary_url // .apps[0].url // empty' "$QD9_DEV_SERVER_STATE" \
      2>/dev/null | tr -d '\r' || true)
  fi
  if [ -z "$BASE_URL_ERP" ] && [ -f ".claude/scripts/wf-fix-detect-base-url.sh" ]; then
    DETECTED=$(bash .claude/scripts/wf-fix-detect-base-url.sh --project-root="${PROJECT_ROOT:-.}" 2>/dev/null || true)
    BASE_URL_ERP=$(echo "$DETECTED" | jq -r '.apps[] | select(.framework != "mobile") | .base_url' \
      2>/dev/null | head -1 | tr -d '\r' || true)
  fi
  if [ -z "$BASE_URL_ERP" ]; then
    echo "P-QD10-business-flow-runtime: SKIP no BASE_URL_ERP available" >&2
    exit 0
  fi
fi

# Step 8: Load auth session (optional — from QD9)
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

# Step 9: Init directories
mkdir -p "$RAW_DIR"
[ -f "$SIGNALS_FILE" ] || echo '[]' > "$SIGNALS_FILE"

# Step 10: Playwright availability (optional — MCP plugin; probe continues without it)
PLAYWRIGHT_AVAILABLE=false
if [ "${MCP_PLAYWRIGHT_AVAILABLE:-0}" = "1" ]; then
  PLAYWRIGHT_AVAILABLE=true
fi

echo "P-QD10-business-flow-runtime: PRE-GATE OK — url=$BASE_URL_ERP specs=$SPEC_COUNT auth=$([ -n "$AUTH_HEADER" ] && echo yes || echo no) playwright=$PLAYWRIGHT_AVAILABLE unreliable_skip='$FLOW_UNRELIABLE_LIST'" >&2
```

---

## SENSE

### S1: Parse business flow specs (Python3 — REUSE state-machine-correctness SENSE S1 pattern)

```python
# wf-fix-flow-driver.sh invokes this as embedded Python3 block

import glob, json, sys, os
try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

FLOW_SPEC_DIR = ".mc-data/docs/phase3-architecture/business-flows"

flows = []
for path in sorted(
    glob.glob(f"{FLOW_SPEC_DIR}/*.yaml") +
    glob.glob(f"{FLOW_SPEC_DIR}/*.yml")
):
    try:
        with open(path, "r", encoding="utf-8") as f:
            spec = yaml.safe_load(f)
        flows.append({
            "flow_id": spec.get("flow_id", os.path.splitext(os.path.basename(path))[0]),
            "name": spec.get("name", ""),
            "flow_type": spec.get("flow_type", "general"),
            "modules_involved": spec.get("modules_involved", []),
            "prerequisites": spec.get("prerequisites", []),
            "steps": spec.get("steps", []),
            "expected_invariants": spec.get("expected_invariants", []),
            "timeout_minutes": spec.get("timeout_minutes", 10),
            "_spec_path": path
        })
    except yaml.YAMLError as e:
        print(f"E107: Failed to parse {path}: {e}", file=sys.stderr)
        sys.exit(1)

print(f"SENSE S1: loaded {len(flows)} flow spec(s)", file=sys.stderr)
# Output as JSON for bash/driver consumption
print(json.dumps(flows))
```

### S2: Filter unreliable flows

```bash
# FLOW_UNRELIABLE_LIST = comma-separated flow_ids from QD9 flow-unreliable.json
# flows_to_run[] / flows_skipped[] built from S1 output filtered by FLOW_UNRELIABLE_LIST

FLOWS_JSON=$(python3 -c "..." 2>/dev/null)   # S1 output
FLOWS_TO_RUN=()
FLOWS_SKIPPED=()

for flow_id in $(echo "$FLOWS_JSON" | jq -r '.[].flow_id' 2>/dev/null | tr -d '\r'); do
  if echo ",$FLOW_UNRELIABLE_LIST," | grep -q ",$flow_id,"; then
    FLOWS_SKIPPED+=("$flow_id")
    echo "SENSE S2: skipping flow=$flow_id (in flow-unreliable.json from QD9)" >&2
  else
    FLOWS_TO_RUN+=("$flow_id")
  fi
done

echo "SENSE S2: flows_to_run=${#FLOWS_TO_RUN[@]} flows_skipped=${#FLOWS_SKIPPED[@]}" >&2
```

---

## THINK

Per flow, build execution plan:

```
EXECUTION PLAN:
1. fixture_map: {step_id → {entity_id, response_body}} — tracks created entities for cross-step reference
2. step_results: {step_id → {status: pass|fail|skip, http_code, response_body, assertions_failed[], skip_reason}}
3. cleanup_queue: [{step_id, cleanup_url}] — DELETE endpoints queued for post-flow teardown

REFERENCE RESOLUTION (at execution time):
- In fixture.data values: "${step_id.field}" → step_results[step_id].response_body.field
- In assert.expected values: "${step_id.field}" → same resolution
- In step.api_endpoint path: "${step_id.id}" → fixture_map[step_id].entity_id

STEP ROUTING:
- step.api_endpoint set → HTTP mode (curl)
- step.api_endpoint absent + PLAYWRIGHT_AVAILABLE=true → Playwright MCP UI driver (REUSE QD9 auth-aware-smoke nav pattern)
- step.api_endpoint absent + PLAYWRIGHT_AVAILABLE=false → skip step, warn "no_api_endpoint_playwright_unavailable"

SKIP_IF EVALUATION:
- step.skip_if expression like "steps.{step_id}.skipped == true"
  → lookup step_results[step_id].status == "skip" → skip this step
- If skip_if evaluates true → record status=skip, do NOT emit signal

FIXTURE CLEANUP DECISION:
- Per step: if fixture.cleanup_after_flow=true (default) OR step.cleanup=true
  → add DELETE URL to cleanup_queue (executed in A6 after all steps)
- Convention DELETE URL: api_endpoint path with entity ID appended
  e.g. "POST /api/customers" → "DELETE /api/customers/{entity_id}"
```

---

## ACT

### A0: Per-flow checkpoint init

```bash
act_init_checkpoint() {
  local flow_id="$1"
  local CHECKPOINT_FILE="$RAW_DIR/P-QD10-flow-${flow_id}-checkpoint.json"

  echo '{"flow_id":"'"$flow_id"'","steps_done":[],"fixture_map":{},"status":"in_progress","started_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' \
    > "$CHECKPOINT_FILE"
  echo "$CHECKPOINT_FILE"
}
```

### A1: Check prerequisites

```python
def check_prerequisites(prerequisites, base_url, auth_header, fixture_map):
    """
    Per prerequisite:
    - If check absent → assume satisfied
    - If check present → HTTP call to verify
    - If not satisfied + setup_if_missing=False → return skip_reason (don't emit signal)
    - If not satisfied + setup_if_missing=True → attempt to setup via POST
    Returns: (can_proceed: bool, skip_reason: str|None)
    """
    for prereq in prerequisites:
        check = prereq.get("check", "")
        setup_if_missing = prereq.get("setup_if_missing", False)
        description = prereq.get("description", "")

        if not check:
            continue  # No check expression — assume satisfied

        # Parse: "GET /api/endpoint?q=v returns 200"
        parts = check.strip().split()
        if len(parts) >= 2 and parts[0].upper() in ("GET", "POST"):
            method, path = parts[0].upper(), parts[1]
            expected_code = int(parts[-1]) if parts[-1].isdigit() else 200
            code, body = http_call(method, f"{base_url}{path}", auth_header)
            if code != expected_code:
                if setup_if_missing:
                    # Attempt POST to create prerequisite entity
                    return True, None  # Caller handles setup
                else:
                    return False, f"prerequisite_not_satisfied: {description} — expected {expected_code} got {code}"
    return True, None
```

### A2: Resolve template references

```python
def resolve_refs(value, fixture_map):
    """
    Replace ${step_id.field} placeholders with actual values from fixture_map.
    fixture_map: {step_id: {entity_id: str, response_body: dict}}
    """
    import re
    if not isinstance(value, str):
        return value
    pattern = re.compile(r'\$\{([a-z][a-z0-9-]*)\.([a-zA-Z0-9_]+)\}')

    def replacer(m):
        step_id, field = m.group(1), m.group(2)
        step_data = fixture_map.get(step_id, {})
        if field == "id" or field == "_id":
            return str(step_data.get("entity_id", m.group(0)))
        body = step_data.get("response_body", {})
        val = body.get(field, m.group(0))
        # Navigate nested field
        if isinstance(val, dict):
            return m.group(0)  # Complex — keep placeholder
        return str(val)

    return pattern.sub(replacer, value)
```

### A3: Execute step (HTTP mode — REUSE QD1 api-smoke:59-81 curl pattern)

```bash
execute_step_http() {
  local step_id="$1"
  local api_endpoint="$2"   # e.g. "POST /api/quotations/submit"
  local body_json="$3"      # resolved fixture data as JSON (or empty)
  local timeout_s="${4:-30}"

  # Parse method + path
  local METHOD PATH_PART URL
  METHOD=$(echo "$api_endpoint" | awk '{print $1}' | tr '[:lower:]' '[:upper:]')
  PATH_PART=$(echo "$api_endpoint" | awk '{print $2}')
  URL="${BASE_URL_ERP}${PATH_PART}"

  local HTTP_RESP HTTP_CODE HTTP_BODY

  case "$METHOD" in
    GET|DELETE)
      HTTP_RESP=$(with_runtime_cap "$timeout_s" curl -s -w "\n%{http_code}" \
        -X "$METHOD" \
        -H "Accept: application/json" \
        ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
        "$URL" --max-time "$timeout_s" 2>/dev/null \
        || echo -e "\n000")
      ;;
    POST|PUT|PATCH)
      HTTP_RESP=$(with_runtime_cap "$timeout_s" curl -s -w "\n%{http_code}" \
        -X "$METHOD" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
        ${body_json:+-d "$body_json"} \
        "$URL" --max-time "$timeout_s" 2>/dev/null \
        || echo -e "\n000")
      ;;
    *)
      echo "WARN: unknown method $METHOD in step $step_id — skipping" >&2
      echo "skip:unknown_method"
      return ;;
  esac

  HTTP_BODY=$(echo "$HTTP_RESP" | head -n -1)
  HTTP_CODE=$(echo "$HTTP_RESP" | tail -1 | tr -d '[:space:]')

  echo "${HTTP_CODE}|||${HTTP_BODY}"
}
```

### A4: Poll wait_for condition (E112 on timeout)

```bash
poll_condition() {
  local condition="$1"      # e.g. "order.status == CONFIRMED"
  local timeout_s="$2"      # e.g. 30
  local poll_interval="${3:-2}"
  local check_url="$4"      # GET URL to poll

  local elapsed=0
  while [ "$elapsed" -le "$timeout_s" ]; do
    local POLL_HTTP POLL_BODY POLL_CODE
    POLL_HTTP=$(with_runtime_cap 10 curl -s -w "\n%{http_code}" \
      -H "Accept: application/json" \
      ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
      "$check_url" --max-time 10 2>/dev/null || echo -e "\n000")
    POLL_BODY=$(echo "$POLL_HTTP" | head -n -1)
    POLL_CODE=$(echo "$POLL_HTTP" | tail -1 | tr -d '[:space:]')

    # Simple condition parse: "entity.field == VALUE"
    if echo "$condition" | grep -q " == "; then
      local FIELD EXPECTED_VAL
      FIELD=$(echo "$condition" | cut -d' ' -f1)
      EXPECTED_VAL=$(echo "$condition" | cut -d' ' -f3)
      FIELD_PART=$(echo "$FIELD" | cut -d. -f2-)  # strip entity prefix

      local ACTUAL
      ACTUAL=$(echo "$POLL_BODY" | jq -r \
        --arg f "$FIELD_PART" \
        'if type == "object" then .[$f] // "" else "" end' \
        2>/dev/null | tr -d '\r' || echo "")

      if [ "$ACTUAL" = "$EXPECTED_VAL" ]; then
        echo "satisfied:$elapsed"
        return
      fi
    fi

    sleep "$poll_interval" 2>/dev/null || true
    elapsed=$(( elapsed + poll_interval ))
  done

  echo "timeout:$timeout_s"  # E112 signal emitted by caller
}
```

### A5: Evaluate assertions (Python3)

```python
import json, re

OPERATORS = {
    "eq":         lambda a, e: str(a) == str(e),
    "ne":         lambda a, e: str(a) != str(e),
    "gt":         lambda a, e: _num(a) > _num(e),
    "lt":         lambda a, e: _num(a) < _num(e),
    "gte":        lambda a, e: _num(a) >= _num(e),
    "lte":        lambda a, e: _num(a) <= _num(e),
    "exists":     lambda a, e: a is not None,
    "not_exists": lambda a, e: a is None,
    "contains":   lambda a, e: str(e) in str(a) if a is not None else False,
    "matches":    lambda a, e: bool(re.match(str(e), str(a))) if a is not None else False,
    "starts_with":lambda a, e: str(a).startswith(str(e)) if a is not None else False,
}

def _num(v):
    try: return float(v)
    except: return 0.0

def navigate_json(obj, dotted_path):
    """Navigate a.b.c path through JSON object."""
    for part in dotted_path.split("."):
        if isinstance(obj, dict): obj = obj.get(part)
        elif isinstance(obj, list):
            try: obj = obj[int(part)]
            except: obj = None
        else: return None
        if obj is None: return None
    return obj

def evaluate_assertions(assertions, http_code, response_body_str, fixture_map):
    """
    Returns list of {assertion, actual, severity} for FAILED assertions.
    String assertions are doc-only — always pass.
    """
    failures = []
    try:
        body = json.loads(response_body_str) if response_body_str else {}
    except:
        body = {}

    for assertion in assertions:
        if isinstance(assertion, str):
            continue  # doc-only string assertion — skip evaluation

        field_path = assertion.get("field", "")
        operator = assertion.get("operator", "eq")
        expected = assertion.get("expected")
        severity = assertion.get("severity_on_fail", "HIGH")
        desc = assertion.get("description", f"{field_path} {operator} {expected}")

        # Resolve ${step_id.field} in expected
        if isinstance(expected, str):
            expected = resolve_refs(expected, fixture_map)

        # Resolve actual value from response
        actual = None
        if field_path in ("response.status", "status"):
            actual = str(http_code)
        elif field_path.startswith("body.") or field_path.startswith("response.body."):
            sub = field_path.replace("response.body.", "").replace("body.", "")
            actual = navigate_json(body, sub)
        elif field_path.startswith("response."):
            sub = field_path[len("response."):]
            actual = navigate_json(body, sub)
        else:
            actual = navigate_json(body, field_path)

        # Evaluate
        op_fn = OPERATORS.get(operator)
        if op_fn is None:
            continue  # Unknown operator — skip
        try:
            passed = op_fn(actual, expected)
        except:
            passed = False

        if not passed:
            failures.append({
                "description": desc,
                "field": field_path,
                "operator": operator,
                "expected": str(expected),
                "actual": str(actual),
                "severity": severity.upper()
            })

    return failures
```

### A5b: Emit step failure signal

```bash
emit_step_failure() {
  local flow_id="$1"
  local step_id="$2"
  local action="$3"
  local failure_reason="$4"
  local evidence_content="$5"
  local severity="${6:-high}"

  # REUSE emit_signal_runtime_integration (_shared.md:98-133)
  emit_signal_runtime_integration \
    "P-QD10-business-flow-runtime" \
    "business_flow_step_failed" \
    "$severity" \
    "Flow ${flow_id}: step ${step_id} (${action}) FAILED" \
    "Business flow step '${step_id}' in flow '${flow_id}' failed during E2E execution. Action: ${action}. Reason: ${failure_reason}" \
    "api_response_diff" \
    "$evidence_content" \
    "{\"flow_id\": \"$flow_id\", \"step_id\": \"$step_id\", \"action\": \"$action\"}"
}
```

### A5c: Emit invariant violation signal

```bash
emit_invariant_violation() {
  local flow_id="$1"
  local inv_description="$2"
  local inv_check="$3"
  local inv_idx="$4"
  local evidence_content="$5"
  local severity="${6:-critical}"

  emit_signal_runtime_integration \
    "P-QD10-business-flow-runtime" \
    "business_flow_invariant_violated" \
    "$severity" \
    "Flow ${flow_id}: invariant '${inv_description}' VIOLATED" \
    "Global invariant check failed after flow '${flow_id}' completed. Invariant: '${inv_description}'. Check: ${inv_check}" \
    "api_response_diff" \
    "$evidence_content" \
    "{\"flow_id\": \"$flow_id\", \"invariant\": \"${inv_description}\", \"invariant_index\": $inv_idx}"
}
```

### A6: Cleanup fixtures

```bash
act_cleanup() {
  local flow_id="$1"
  local cleanup_queue_json="$2"   # JSON array of {step_id, cleanup_url}

  local cleanup_count=0 cleanup_fail=0

  while IFS=$'\t' read -r step_id cleanup_url; do
    [ -z "$cleanup_url" ] && continue
    echo "  CLEANUP: step=$step_id DELETE $cleanup_url" >&2

    local DEL_HTTP DEL_CODE
    DEL_HTTP=$(with_runtime_cap 15 curl -s -w "\n%{http_code}" \
      -X DELETE \
      -H "Accept: application/json" \
      ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
      "$cleanup_url" --max-time 15 2>/dev/null \
      || echo -e "\n000")
    DEL_CODE=$(echo "$DEL_HTTP" | tail -1 | tr -d '[:space:]')

    if [ "$DEL_CODE" = "000" ] || { [ "$DEL_CODE" -lt 200 ] || [ "$DEL_CODE" -ge 300 ]; } 2>/dev/null; then
      echo "  WARN: cleanup DELETE failed code=$DEL_CODE url=$cleanup_url (non-blocking)" >&2
      cleanup_fail=$(( cleanup_fail + 1 ))
    else
      cleanup_count=$(( cleanup_count + 1 ))
    fi
  done < <(echo "$cleanup_queue_json" | jq -r '.[] | [.step_id, .cleanup_url] | @tsv' 2>/dev/null || true)

  echo "  CLEANUP: ok=$cleanup_count fail=$cleanup_fail" >&2
}
```

### A7: Check global invariants

```bash
act_check_invariants() {
  local flow_id="$1"
  local invariants_json="$2"   # JSON array from spec.expected_invariants
  local fixture_map_json="$3"  # JSON for ${ref} resolution

  local inv_idx=0
  local invariants_violated=0

  while IFS=$'\t' read -r description check severity; do
    [ -z "$description" ] && { inv_idx=$(( inv_idx + 1 )); continue; }
    severity="${severity:-CRITICAL}"

    # Parse check expression: "GET /api/path returns 200"
    local METHOD PATH_PART EXPECTED_CODE
    METHOD=$(echo "$check" | awk '{print $1}' | tr '[:lower:]' '[:upper:]')
    PATH_PART=$(echo "$check" | awk '{print $2}')
    EXPECTED_CODE=$(echo "$check" | awk '{print $NF}')

    if [ "$METHOD" = "GET" ] && echo "$PATH_PART" | grep -q "^/"; then
      local inv_url="${BASE_URL_ERP}${PATH_PART}"
      # Resolve ${step_id.id} refs in URL
      # (simplified: replace ${step_id.id} with fixture_map[step_id].entity_id via Python3)
      inv_url=$(python3 -c "
import json, re, sys
url = '$inv_url'
fm = json.loads('''$fixture_map_json''')
def resolve(m):
    sid, field = m.group(1), m.group(2)
    return str(fm.get(sid, {}).get('entity_id', m.group(0)))
print(re.sub(r'\\\$\{([a-z][a-z0-9-]*)\.([a-zA-Z0-9_]+)\}', resolve, url))
" 2>/dev/null || echo "$inv_url")

      local INV_HTTP INV_CODE INV_BODY
      INV_HTTP=$(with_runtime_cap 20 curl -s -w "\n%{http_code}" \
        -H "Accept: application/json" \
        ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
        "$inv_url" --max-time 20 2>/dev/null || echo -e "\n000")
      INV_BODY=$(echo "$INV_HTTP" | head -n -1)
      INV_CODE=$(echo "$INV_HTTP" | tail -1 | tr -d '[:space:]')

      local satisfied=false
      if echo "$EXPECTED_CODE" | grep -qE '^[0-9]+$' && [ "$INV_CODE" = "$EXPECTED_CODE" ]; then
        satisfied=true
      fi

      if [ "$satisfied" = "false" ]; then
        emit_invariant_violation \
          "$flow_id" \
          "$description" \
          "$check" \
          "$inv_idx" \
          "GET $inv_url → HTTP $INV_CODE (expected $EXPECTED_CODE). Response: $(echo "$INV_BODY" | head -c 200)" \
          "$(echo "$severity" | tr '[:upper:]' '[:lower:]')"
        invariants_violated=$(( invariants_violated + 1 ))
      fi
    fi

    inv_idx=$(( inv_idx + 1 ))
  done < <(echo "$invariants_json" | jq -r \
    '.[] | if type == "string" then [., "", "CRITICAL"] elif type == "object" then [.description // "", .check // "", .severity_on_fail // "CRITICAL"] else ["","","CRITICAL"] end | @tsv' \
    2>/dev/null || true)

  echo "$invariants_violated"
}
```

### A8: Per-flow orchestration (delegates to wf-fix-flow-driver.sh)

```bash
# Main per-flow loop — delegates step execution to helper script
# (wf-fix-flow-driver.sh encapsulates Python3 YAML parse + step loop + assertion eval + cleanup)

flows_analyzed=0; flows_pass=0; flows_fail=0; flows_skip=0
total_steps_pass=0; total_steps_fail=0; total_signals=0

for flow_id in "${FLOWS_TO_RUN[@]}"; do
  spec_path=$(echo "$FLOWS_JSON" | jq -r \
    --arg fid "$flow_id" '.[] | select(.flow_id == $fid) | ._spec_path' 2>/dev/null | tr -d '\r')
  flows_analyzed=$(( flows_analyzed + 1 ))

  echo "=== FLOW: $flow_id ===" >&2

  # Delegate to helper script (carries Python3 + full step loop logic)
  FLOW_OUT=$(bash .claude/scripts/wf-fix-flow-driver.sh \
    --spec        "$spec_path" \
    --base-url    "$BASE_URL_ERP" \
    --session-dir "$SESSION_DIR" \
    --signals-file "$SIGNALS_FILE" \
    --checkpoint-dir "$RAW_DIR" \
    ${AUTH_HEADER:+--auth-header "$AUTH_HEADER"} \
    ${PLAYWRIGHT_AVAILABLE:+--playwright} \
    2>&1)
  FLOW_EXIT=$?

  echo "$FLOW_OUT" >> "$RAW_DIR/P-QD10-flow-${flow_id}.log"

  # Parse structured metrics from driver stdout (STEPS_PASS=N STEPS_FAIL=N SIGNALS_EMITTED=N)
  flow_steps_pass=$(echo "$FLOW_OUT" | grep -o "STEPS_PASS=[0-9]*" | cut -d= -f2 | tail -1 || echo 0)
  flow_steps_fail=$(echo "$FLOW_OUT" | grep -o "STEPS_FAIL=[0-9]*" | cut -d= -f2 | tail -1 || echo 0)
  flow_signals=$(echo "$FLOW_OUT" | grep -o "SIGNALS_EMITTED=[0-9]*" | cut -d= -f2 | tail -1 || echo 0)

  total_steps_pass=$(( total_steps_pass + ${flow_steps_pass:-0} ))
  total_steps_fail=$(( total_steps_fail + ${flow_steps_fail:-0} ))
  total_signals=$(( total_signals + ${flow_signals:-0} ))

  if [ "${flow_steps_fail:-0}" -gt 0 ] || [ "$FLOW_EXIT" -ne 0 ]; then
    flows_fail=$(( flows_fail + 1 ))
  else
    flows_pass=$(( flows_pass + 1 ))
  fi
done

for flow_id in "${FLOWS_SKIPPED[@]}"; do
  flows_skip=$(( flows_skip + 1 ))
  echo "SKIP: flow=$flow_id (flow-unreliable.json)" >&2
done
```

### A9: Write summary JSON

```bash
SUMMARY_FILE="$RAW_DIR/P-QD10-business-flow-summary.json"
jq -n \
  --argjson analyzed "$flows_analyzed" \
  --argjson pass     "$flows_pass" \
  --argjson fail     "$flows_fail" \
  --argjson skip     "$flows_skip" \
  --argjson steps_p  "$total_steps_pass" \
  --argjson steps_f  "$total_steps_fail" \
  --argjson signals  "$total_signals" \
  --arg base_url     "$BASE_URL_ERP" \
  --arg now          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    probe_id: "P-QD10-business-flow-runtime",
    dimension: "QD10",
    generated_at: $now,
    base_url: $base_url,
    flows: {analyzed: $analyzed, pass: $pass, fail: $fail, skipped: $skip},
    steps: {pass: $steps_p, fail: $steps_f},
    signals_emitted: $signals
  }' > "$SUMMARY_FILE"

echo "P-QD10-business-flow-runtime: DONE flows=analyzed:$flows_analyzed pass:$flows_pass fail:$flows_fail skip:$flows_skip steps=pass:$total_steps_pass fail:$total_steps_fail signals=$total_signals" >&2
```

---

## VERIFY

10-item per-probe DoD checklist:

1. **Profile gate enforced** — probe exits 0 with note khi profile != exhaustive
2. **E104 hard block** — probe exits 1 khi DEPLOY_ENV matches production pattern (no fixture creation)
3. **No spec → SKIP** — exits 0 khi không có business-flow YAML spec nào
4. **Schema validation** — each spec validated against business-flow-spec-schema.json; E107 ABORT on fail
5. **flow_unreliable.json skip** — flows in QD9 unreliable list skipped (not a signal — documented in summary)
6. **Per-step checkpoint updated** — checkpoint JSON written after each step execution (for resume/audit)
7. **business_flow_step_failed severity=HIGH** — step execution fail (HTTP non-2xx, assertion fail, E112 timeout)
8. **business_flow_invariant_violated severity=CRITICAL** — global invariant violated after flow complete
9. **Cleanup attempted** — fixtures with cleanup=true / cleanup_after_flow=true deleted after flow (non-blocking fail)
10. **SIGNALS_FILE is valid JSON array after probe** — `jq '.' "$SIGNALS_FILE"` exits 0

---

## Severity Rules

| Pattern | Severity | Rationale |
|---------|----------|-----------|
| Step HTTP call returns non-2xx (not timeout) | HIGH | Business flow broken at step — user journey interrupted |
| Step assertion fails (default severity_on_fail=HIGH) | HIGH | Expected state/value not reached after step |
| Step assertion fails with severity_on_fail=CRITICAL | CRITICAL | Critical business invariant at step level |
| Step wait_for timeout (E112) | HIGH | Step did not complete — possible deadlock or missing async handler |
| Fixture setup fails (E111) | HIGH | Cannot execute flow without test data — structural gap |
| Global invariant violated (default CRITICAL) | CRITICAL | End-to-end consistency broken — most severe |
| Prerequisite not satisfied, setup_if_missing=false | SKIP | Flow cannot start — document as skip, not a signal |
| Step api_endpoint absent, Playwright unavailable | SKIP | Cannot execute step — document, no signal |

---

## Dedup Hints

| Signal type | Dedup key pattern |
|-------------|------------------|
| `business_flow_step_failed` | `P-QD10-business-flow-runtime:business_flow_step_failed:{flow_id}:{step_id}` |
| `business_flow_invariant_violated` | `P-QD10-business-flow-runtime:business_flow_invariant_violated:{flow_id}:{invariant_idx}` |

---

## Signal Schema Examples

**business_flow_step_failed (HIGH):**

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-business-flow-runtime",
  "dimension_id": "QD10",
  "signal_type": "business_flow_step_failed",
  "severity": "high",
  "title": "Flow quote-to-cash: step submit-quotation (submit_quotation) FAILED",
  "description": "Business flow step 'submit-quotation' in flow 'quote-to-cash' failed during E2E execution. Action: submit_quotation. Reason: assertion 'response.status eq 201' failed — actual: 422",
  "location": {
    "flow_id": "quote-to-cash",
    "step_id": "submit-quotation",
    "action": "submit_quotation"
  },
  "evidence": [{
    "type": "api_response_diff",
    "content": "POST /api/quotations/submit → HTTP 422 {\"error\":\"Validation failed\",\"details\":\"customer_id required\"}"
  }],
  "dedup_key": "P-QD10-business-flow-runtime:business_flow_step_failed:quote-to-cash:submit-quotation"
}
```

**business_flow_invariant_violated (CRITICAL):**

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-business-flow-runtime",
  "dimension_id": "QD10",
  "signal_type": "business_flow_invariant_violated",
  "severity": "critical",
  "title": "Flow quote-to-cash: invariant 'Order persisted after cash collection' VIOLATED",
  "description": "Global invariant check failed after flow 'quote-to-cash' completed. Invariant: 'Order persisted after cash collection'. Check: GET /api/orders/123 returns 200",
  "location": {
    "flow_id": "quote-to-cash",
    "invariant": "Order persisted after cash collection",
    "invariant_index": 0
  },
  "evidence": [{
    "type": "api_response_diff",
    "content": "GET /api/orders/123 → HTTP 404 (order not found after cash-collection step completed)"
  }],
  "dedup_key": "P-QD10-business-flow-runtime:business_flow_invariant_violated:quote-to-cash:0"
}
```

---

## Fallback Table

| Situation | Behavior |
|-----------|----------|
| Profile != exhaustive | SKIP exit 0 — note "profile_not_exhaustive" |
| DEPLOY_ENV = production | E104 HARD BLOCK exit 1 — no fixture created |
| BASE_URL_ERP contains prod domain | E104 HARD BLOCK exit 1 |
| python3 not available | SKIP probe exit 0 — note "python3_unavailable" |
| PyYAML not installed | SKIP probe exit 0 — note "pyyaml_unavailable" |
| No business-flow YAML specs | SKIP exit 0 — note "no_specs_found" |
| Spec schema validation fails | E107 ABORT exit 1 — fix spec first |
| Flow in flow-unreliable.json (QD9) | Skip flow — status=skip, continue to next flow |
| Prerequisite not satisfied + setup_if_missing=false | Skip flow — skip_reason recorded in summary |
| Fixture POST fails (E111) | Skip remaining steps in flow — emit HIGH signal; proceed to next flow |
| Step api_endpoint absent + Playwright unavailable | Skip step — warn "no_api_endpoint_playwright_unavailable", no signal |
| Step HTTP call returns non-2xx | Emit business_flow_step_failed HIGH; continue to next step |
| Step assertion fails | Emit business_flow_step_failed with assertion.severity_on_fail; continue |
| wait_for timeout (E112) | Emit business_flow_step_failed HIGH; skip remaining steps in flow |
| Global invariant check fails | Emit business_flow_invariant_violated CRITICAL (severity from spec) |
| Cleanup DELETE fails | WARN stderr — non-blocking; record in summary.cleanup_fail_count |
| jq not available | SKIP probe — note "jq_unavailable" |
| wf-fix-flow-driver.sh not found | SKIP probe — note "driver_script_missing" |

---

## Cache Policy

**NOT allowed.** Probe thực hiện HTTP POST (fixture creation) và runtime assertions — kết quả thay đổi theo state của system. Mỗi lần chạy phải thực thi lại.
Set `CACHE_TTL=0` nếu cache framework được load.

---

## Profile-Resolver Entry

```yaml
probe: P-QD10-business-flow-runtime
class: runtime        # sequential per flow; per-step dependencies prevent intra-flow parallelism
profiles:
  quick: SKIP
  standard: SKIP
  deep: SKIP
  exhaustive:
    run: true
    max_flows: 10      # cap at 10 flows per run (time budget)
uses_browser: optional   # Playwright for UI steps (steps without api_endpoint)
requires_db: false
requires_api: true       # HTTP POST/GET/DELETE for fixture + step execution
mutation: true           # Side effect — creates and deletes fixture entities; E104 enforced
parallel_safe: false     # Sequential per flow (inter-step fixture dependencies)
```

---

## Acceptance Tests

### Test 1: Profile != exhaustive → SKIP

```bash
PROFILE=standard SIGNALS_FILE=/tmp/sig.json \
  bash procedures/probes/P-QD10-business-flow-runtime.md 2>&1 | grep -i skip

# Expected: "SKIP profile=standard (requires exhaustive)"
# Exit code: 0
```

### Test 2: Production env → E104 HARD BLOCK

```bash
DEPLOY_ENV=production PROFILE=exhaustive \
  bash procedures/probes/P-QD10-business-flow-runtime.md 2>&1

# Expected: "E104: HARD BLOCK"
# Exit code: 1
```

### Test 3: No specs → SKIP

```bash
PROFILE=exhaustive DEPLOY_ENV=development \
  FLOW_SPEC_DIR=/tmp/empty-dir \
  bash procedures/probes/P-QD10-business-flow-runtime.md 2>&1

# Expected: "SKIP no business-flow specs found"
# Exit code: 0
# 0 signals emitted
```

### Test 4: Assertion fail → business_flow_step_failed HIGH

```yaml
# Synthetic flow: simple-create-flow.yaml
flow_id: simple-create-flow
name: "Simple Create Flow"
modules_involved: [MOD-CRM]
steps:
  - id: create-customer
    module: MOD-CRM
    action: create_customer
    actor: test
    api_endpoint: "POST /api/customers"
    fixture:
      entity_type: Customer
      data: {name: "Test Customer", email: "test@probe.com"}
    assert:
      - field: "response.status"
        operator: "eq"
        expected: "201"
        severity_on_fail: HIGH
```

```bash
# Setup: server returns 422 for POST /api/customers (validation error)
# PROFILE=exhaustive, DEPLOY_ENV=development

# Expected:
# signals.json has business_flow_step_failed HIGH
# evidence: "POST /api/customers → HTTP 422 ..."
# summary.json: flows.fail=1, steps.fail=1, signals_emitted=1
```

### Test 5: Invariant violation → business_flow_invariant_violated CRITICAL

```yaml
# Synthetic flow with invariant check
expected_invariants:
  - description: "Customer exists after flow"
    check: "GET /api/customers/999 returns 200"  # 999 doesn't exist
    severity_on_fail: CRITICAL
```

```bash
# Expected:
# signals.json has business_flow_invariant_violated CRITICAL
# evidence: "GET /api/customers/999 → HTTP 404"
```

### Test 6: EUREKA acceptance (manual — requires W4.6)

```bash
# Pre-condition: EUREKA-2026 dev env running; W4.6 YAML specs authored
# PROFILE=exhaustive, DEPLOY_ENV=development

# Run: /wf-fix-bugs --dims=QD10 --profile=exhaustive --scope=cross-module

# Expected:
# Q2C flow: all steps 2xx → assertions pass → flows.pass >= 1
# OR specific steps fail → signals emitted with HTTP evidence
# summary.json: flows.analyzed >= 1, steps.pass >= 1
```
