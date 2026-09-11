# QD7 Shared Probe Protocols

## 0. Playwright Session (Bash-Level)

Session-isolated browser qua `playwright-session.js`. Cac probe can browser (device-breakpoint-test) dung chung session.

```bash
SHARED_DIR=".claude/skills/workflow/_shared"
SESSION_FILE="$SESSION_DIR/playwright-session.json"

# v10.2 — Propagate flags --show-browser / --mobile / --device tu orchestrator
if [ -z "${SHOW_BROWSER:-}" ] && [ -f "$SESSION_DIR/fix-status.json" ]; then
  SHOW_BROWSER=$(jq -r '.show_browser // false' "$SESSION_DIR/fix-status.json" 2>/dev/null)
  MOBILE_MODE=$(jq -r '.mobile_mode // false' "$SESSION_DIR/fix-status.json" 2>/dev/null)
  MOBILE_DEVICE=$(jq -r '.mobile_device // "iPhone 14"' "$SESSION_DIR/fix-status.json" 2>/dev/null)
fi
SHOW_BROWSER="${SHOW_BROWSER:-false}"
MOBILE_MODE="${MOBILE_MODE:-false}"
MOBILE_DEVICE="${MOBILE_DEVICE:-iPhone 14}"

PW_BASE_ARGS="--session-dir=$SESSION_DIR"
PW_LAUNCH_ARGS=""
[ "$SHOW_BROWSER" = "true" ] && PW_LAUNCH_ARGS="$PW_LAUNCH_ARGS --show-browser=true"
[ "$MOBILE_MODE" = "true" ] && PW_LAUNCH_ARGS="$PW_LAUNCH_ARGS --mobile=true --device=\"$MOBILE_DEVICE\""

PW_CMD="node $SHARED_DIR/playwright-session.js $PW_BASE_ARGS"
PW_LAUNCH_CMD="node $SHARED_DIR/playwright-session.js $PW_BASE_ARGS $PW_LAUNCH_ARGS"

pw_launch() {
  local result
  result=$($PW_LAUNCH_CMD --action=launch 2>&1) || { echo "E096: browser_unavailable" >&2; return 1; }
  echo "$result" | jq -r '.status' | grep -qE 'launched|already_running' || { echo "E096: browser_unavailable" >&2; return 1; }
  return 0
}
pw_close() { $PW_CMD --action=close 2>/dev/null || true; }
pw_navigate() { $PW_CMD --action=navigate --url="$1" ${2:+--wait-until="$2"} 2>&1; }
pw_evaluate() { $PW_CMD --action=evaluate --expr="$1" 2>&1; }
pw_resize() { $PW_CMD --action=resize --width="$1" --height="$2" 2>&1; }
pw_screenshot() { mkdir -p "$(dirname "$1")"; $PW_CMD --action=screenshot --path="$1" ${2:+--full-page="$2"} 2>&1; }
```

## 1. Signal Emission Protocol

Signal schema signal-v2. Moi signal phai co:
- `dimension_id: "QD7"`
- `probe_id` match `^P-QD7-[a-z0-9-]+$`
- `description` >= 10 ky tu
- It nhat 1 evidence field non-empty (ADR-09)

Raw output: `$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat/raw/P-QD7-<probe>.json`

## 2. Scan Cache Protocol

Cache policy: **allowed** cho static probes. Runtime probes luon skip cache.

## 3. Severity Mapping (QD7)

| Pattern | Severity |
|---------|----------|
| Critical trigger | CRITICAL |
| High trigger | HIGH |
| Medium trigger | MEDIUM |
| Informational | LOW |

## 4. Profile-Based Probe Selection

Chay probes theo profile (quick/standard/deep/exhaustive).
Xem dimension.json exit_criteria cho probe list chinh xac.

## 5. Checkpoint Protocol

Sau moi probe, update lane-status.json voi probe status va signal count.
