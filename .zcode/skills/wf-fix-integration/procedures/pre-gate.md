# PRE-GATE — wf-fix-integration (QD10 Lane)

> **Reference:** `_shared/lane/pre-gate.md` (steps 1-7 chuan cho moi lane)
> **Schema:** `_shared/lane/_shared.md` §5 (lane-status-v1)
> **Phien ban:** v1.0 (2026-05-10 — QD10 Cross-Module Integration)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-integration"
DIMENSION="QD10"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD10-integration"
```

## Steps Chuan (1-7)

Doc va thuc hien day du theo `_shared/lane/pre-gate.md`:

1. Verify orchestrator handoff (`SESSION_DIR`, `fix-status.json`)
2. Verify input data (registry + source dirs)
3. Verify dimension scope (QD10 trong dimensions_resolved)
4. Resolve profile → probe subset (Pattern A inline, xem Step 10 ben duoi)
5. Initialize lane working dir
6. Init `lane-status.json` tu shared template
7. Init `signals.json` tu shared template

## QD10-Specific Extension Steps

### Step 8 — Detect cross_module_dependencies (SKIP neu empty)

```bash
# Doc cross_module_dependencies tu registry
REGISTRY_FILE=".mc-data/docs/_meta/req-registry.json"
DEPS_COUNT=$(jq -r '(.cross_module_dependencies // []) | length' "$REGISTRY_FILE" 2>/dev/null || echo "0")

if [ "$DEPS_COUNT" = "0" ]; then
  echo "INFO: cross_module_dependencies khong ton tai hoac rong — QD10 se SKIP (E100)" >&2
  jq -n --arg reason "cross_module_dependencies[] chua duoc dinh nghia trong registry. Chay /wf-manage-change hoac them thu cong de bat QD10." \
    '{status: "skipped", dimension: "QD10", skip_reason: $reason, error_code: "E100"}' \
    > "$LANE_DIR/lane-status.json"
  exit 0
fi

export DEPS_COUNT
echo "INFO: cross_module_dependencies: $DEPS_COUNT pairs" >&2
```

### Step 9 — Load QD9 coordination files (optional)

```bash
QD9_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health"

# Flow unreliable map — QD10 business-flow-runtime skip broken flows
FLOW_UNRELIABLE_FILE="$QD9_DIR/flow-unreliable.json"
if [ -f "$FLOW_UNRELIABLE_FILE" ]; then
  export FLOW_UNRELIABLE="$FLOW_UNRELIABLE_FILE"
  BROKEN_COUNT=$(jq 'length' "$FLOW_UNRELIABLE_FILE" 2>/dev/null || echo "0")
  echo "INFO: QD9 flow-unreliable.json loaded — $BROKEN_COUNT flows marked unreliable" >&2
else
  export FLOW_UNRELIABLE=""
  echo "INFO: QD9 flow-unreliable.json khong co — business-flow-runtime se chay tat ca flows" >&2
fi

# Auth session — reuse cho runtime API probes
AUTH_SESSION_FILE="$QD9_DIR/auth-session.json"
if [ -f "$AUTH_SESSION_FILE" ]; then
  export QD9_AUTH_SESSION="$AUTH_SESSION_FILE"
  echo "INFO: QD9 auth-session.json loaded — se reuse cho API calls" >&2
else
  export QD9_AUTH_SESSION=""
fi

# Dev server state — reuse pid + url
DEV_SERVER_FILE="$QD9_DIR/dev-server-state.json"
if [ -f "$DEV_SERVER_FILE" ]; then
  export QD9_DEV_SERVER_STATE="$DEV_SERVER_FILE"
  BASE_URL_FROM_QD9=$(jq -r '.url // ""' "$DEV_SERVER_FILE" 2>/dev/null)
  if [ -n "$BASE_URL_FROM_QD9" ]; then
    export BASE_URL="${BASE_URL:-$BASE_URL_FROM_QD9}"
    echo "INFO: QD9 dev-server URL reused: $BASE_URL" >&2
  fi
fi
```

### Step 10 — Resolve probe list theo profile (QD10)

```bash
case "$PROFILE" in
  quick)
    # SKIP hoan toan — khong co integration analysis trong quick
    PROBES=()
    echo "INFO: profile=quick — QD10 Cross-Module Integration SKIP" >&2
    jq -n --arg reason "profile=quick: cross-module analysis skip (resource intensive)" \
      '{status: "skipped", dimension: "QD10", skip_reason: $reason}' \
      > "$LANE_DIR/lane-status.json"
    exit 0
    ;;
  standard)
    # 3 static probes (Wave 2)
    PROBES=(
      "P-QD10-cross-module-ref-static"
      "P-QD10-api-contract-drift"
      "P-QD10-event-handler-coverage"
    )
    MAX_PAIRS=10
    ;;
  deep)
    # standard + 3 runtime probes (Wave 3)
    PROBES=(
      "P-QD10-cross-module-ref-static"
      "P-QD10-api-contract-drift"
      "P-QD10-event-handler-coverage"
      "P-QD10-orphan-reference-runtime"
      "P-QD10-multi-platform-entity-sync"
    )
    MAX_PAIRS=20
    ;;
  exhaustive)
    # deep + cache-staleness + business flow (Wave 4)
    PROBES=(
      "P-QD10-cross-module-ref-static"
      "P-QD10-api-contract-drift"
      "P-QD10-event-handler-coverage"
      "P-QD10-orphan-reference-runtime"
      "P-QD10-multi-platform-entity-sync"
      "P-QD10-cache-staleness-probe"
      "P-QD10-state-machine-correctness"
      "P-QD10-business-flow-runtime"
    )
    MAX_PAIRS=30
    ;;
esac

export MAX_PAIRS
echo "INFO: QD10 probes: ${PROBES[*]}, MAX_PAIRS=$MAX_PAIRS" >&2
```

### Step 11 — Filter pairs theo --pair flag (neu co)

```bash
PAIR_FILTER="${PAIR_FILTER:-}"  # Set by orchestrator neu --pair=MODULE_A-MODULE_B

if [ -n "$PAIR_FILTER" ]; then
  # Validate pair ton tai trong cross_module_dependencies
  MODULE_A="${PAIR_FILTER%-*}"
  MODULE_B="${PAIR_FILTER#*-}"

  PAIR_EXISTS=$(jq --arg a "$MODULE_A" --arg b "$MODULE_B" \
    '[.cross_module_dependencies[] | select(
      (.consumer_module == $a and .provider_module == $b) or
      (.consumer_module == $b and .provider_module == $a)
    )] | length' "$REGISTRY_FILE" 2>/dev/null || echo "0")

  if [ "$PAIR_EXISTS" = "0" ]; then
    echo "WARN: Pair '$PAIR_FILTER' khong tim thay trong cross_module_dependencies (E101)" >&2
    jq -n --arg reason "Pair $PAIR_FILTER khong duoc dinh nghia trong registry cross_module_dependencies" \
      --arg err "E101" \
      '{status: "skipped", dimension: "QD10", skip_reason: $reason, error_code: $err}' \
      > "$LANE_DIR/lane-status.json"
    exit 0
  fi

  export PAIR_FILTER MODULE_A MODULE_B
  echo "INFO: Filter pair: $MODULE_A <-> $MODULE_B" >&2
fi
```

## PRE-GATE Failure Handling

Theo `_shared/lane/pre-gate.md` §"PRE-GATE Failure Handling".

## Resume Behavior

Theo `_shared/lane/pre-gate.md` §"Resume Behavior".
