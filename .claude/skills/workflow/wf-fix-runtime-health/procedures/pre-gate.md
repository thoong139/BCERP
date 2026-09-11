# PRE-GATE — wf-fix-runtime-health (QD9 Lane)

> **Reference:** `_shared/lane/pre-gate.md` (steps 1-7 chuan cho moi lane)
> **Schema:** `_shared/lane/_shared.md` §5 (lane-status-v1)
> **Phien ban:** v1.0 (2026-05-10 — QD9 Runtime Health Verification)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-runtime-health"
DIMENSION="QD9"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health"
```

## Steps Chuan (1-7)

Doc va thuc hien day du theo `_shared/lane/pre-gate.md`:

1. Verify orchestrator handoff (`SESSION_DIR`, `fix-status.json`)
2. Verify input data (registry + source dirs)
3. Verify dimension scope (QD9 trong dimensions_resolved)
4. Resolve profile → probe subset (Pattern A inline, xem Step 11 ben duoi)
5. Initialize lane working dir
6. Init `lane-status.json` tu shared template
7. Init `signals.json` tu shared template

## QD9-Specific Extension Steps

### Step 8 — Detect interface_type (SKIP lane neu api-only)

```bash
# Doc interface_type tu fix-status.json
INTERFACE_TYPE=$(jq -r '.project_context.interface_type // "unknown"' "$SESSION_DIR/fix-status.json" 2>/dev/null)

if [ "$INTERFACE_TYPE" = "api-only" ]; then
  echo "INFO: interface_type=api-only — QD9 Runtime Health se SKIP (khong co browser UI)" >&2
  jq -n --arg reason "interface_type=api-only" \
    '{status: "skipped", dimension: "QD9", skip_reason: $reason}' \
    > "$LANE_DIR/lane-status.json"
  exit 0
fi
```

### Step 9 — Detect --no-browser flag (SKIP lane neu set)

```bash
# Kiem tra flag tu fix-status.json
NO_BROWSER=$(jq -r '.flags.no_browser // "false"' "$SESSION_DIR/fix-status.json" 2>/dev/null)

if [ "$NO_BROWSER" = "true" ]; then
  echo "INFO: --no-browser set — QD9 Runtime Health se SKIP" >&2
  jq -n --arg reason "--no-browser flag set by user" \
    '{status: "skipped", dimension: "QD9", skip_reason: $reason}' \
    > "$LANE_DIR/lane-status.json"
  exit 0
fi
```

### Step 10 — Detect BASE_URL cho runtime probes

```bash
# Uu tien: --base-url arg > detect-base-url.sh
BASE_URL="${BASE_URL:-}"

if [ -z "$BASE_URL" ]; then
  # Chay detect script (W1.2)
  DETECT_OUT=$(bash .claude/scripts/wf-fix-detect-base-url.sh --project-root="$(pwd)" 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$DETECT_OUT" ]; then
    # Lay app dau tien khong phai mobile_skip
    BASE_URL=$(echo "$DETECT_OUT" | jq -r '.apps[] | select(.status == "detected") | .base_url' | head -1)
  fi
fi

if [ -z "$BASE_URL" ]; then
  echo "WARN: Khong detect duoc BASE_URL — lane se chay voi limitation E094" >&2
  # Emit signal HIGH "app_unreachable" va SKIP lane
  emit_signal_no_location "P-QD9-dev-server-bootstrap" "high" \
    "App URL khong detect duoc" \
    "Khong tim thay BASE_URL qua detect script. Set --url hoac start dev server truoc." \
    "[]"
  jq '.status = "skipped" | .skip_reason = "BASE_URL undetectable"' \
    "$LANE_DIR/lane-status.json" > "$LANE_DIR/lane-status.json.tmp" && \
    mv "$LANE_DIR/lane-status.json.tmp" "$LANE_DIR/lane-status.json"
  exit 0
fi

export BASE_URL
echo "INFO: BASE_URL=$BASE_URL" >&2
```

### Step 11 — Resolve probe list theo profile (QD9)

```bash
case "$PROFILE" in
  quick)
    # SKIP hoan toan — khong co browser execution trong quick
    PROBES=()
    echo "INFO: profile=quick — QD9 Runtime Health SKIP (no browser in quick)" >&2
    jq -n --arg reason "profile=quick: no browser execution" \
      '{status: "skipped", dimension: "QD9", skip_reason: $reason}' \
      > "$LANE_DIR/lane-status.json"
    exit 0
    ;;
  standard)
    PROBES=(
      "P-QD9-dev-server-bootstrap"
      "P-QD9-console-network-monitor"
      "P-QD9-auth-aware-smoke"
    )
    MAX_ROUTES=20
    MAX_FEATURES=20
    ;;
  deep)
    PROBES=(
      "P-QD9-dev-server-bootstrap"
      "P-QD9-console-network-monitor"
      "P-QD9-auth-aware-smoke"
      "P-QD9-feature-checklist-smoke"
      "P-QD9-interactive-smoke"
      "P-QD9-spa-route-coverage"
      "P-QD9-form-validation-smoke"
    )
    MAX_ROUTES=50
    MAX_FEATURES=50
    ;;
  exhaustive)
    PROBES=(
      "P-QD9-dev-server-bootstrap"
      "P-QD9-console-network-monitor"
      "P-QD9-auth-aware-smoke"
      "P-QD9-feature-checklist-smoke"
      "P-QD9-interactive-smoke"
      "P-QD9-spa-route-coverage"
      "P-QD9-form-validation-smoke"
    )
    MAX_ROUTES=100
    MAX_FEATURES=100
    ;;
esac

export MAX_ROUTES MAX_FEATURES
echo "INFO: QD9 probes: ${PROBES[*]}, MAX_ROUTES=$MAX_ROUTES" >&2
```

## PRE-GATE Failure Handling

Theo `_shared/lane/pre-gate.md` §"PRE-GATE Failure Handling".

## Resume Behavior

Theo `_shared/lane/pre-gate.md` §"Resume Behavior".
