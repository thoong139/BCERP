# QD4 Shared Probe Protocols

## 0. Playwright Session (Bash-Level)

Session-isolated browser qua `playwright-session.js`. Moi `wf-fix-bugs` session co Chromium rieng biet.

```bash
SHARED_DIR=".claude/skills/workflow/_shared"
PW_CMD="node $SHARED_DIR/playwright-session.js --session-dir=$SESSION_DIR"
SESSION_FILE="$SESSION_DIR/playwright-session.json"

pw_launch() {
  local result
  result=$($PW_CMD --action=launch 2>&1) || { echo "E096: browser_unavailable" >&2; return 1; }
  echo "$result" | jq -r '.status' | grep -qE 'launched|already_running' || { echo "E096: browser_unavailable" >&2; return 1; }
  return 0
}
pw_close() { $PW_CMD --action=close 2>/dev/null || true; }
pw_navigate() { $PW_CMD --action=navigate --url="$1" ${2:+--wait-until="$2"} 2>&1; }
pw_snapshot() { $PW_CMD --action=snapshot ${1:+--selector="$1"} 2>&1; }
pw_screenshot() { mkdir -p "$(dirname "$1")"; $PW_CMD --action=screenshot --path="$1" ${2:+--full-page="$2"} 2>&1; }
pw_evaluate() { $PW_CMD --action=evaluate --expr="$1" 2>&1; }
pw_click() { $PW_CMD --action=click --selector="$1" 2>&1; }
pw_wait() { $PW_CMD --action=wait ${1:+--time="$1"} ${2:+--selector="$2"} 2>&1; }
pw_console() { $PW_CMD --action=console 2>&1; }
pw_network() { $PW_CMD --action=network 2>&1; }
pw_resize() { $PW_CMD --action=resize --width="$1" --height="$2" 2>&1; }
```

## 1. Signal Emission Protocol

Signal schema signal-v2. Moi signal phai co:
- `dimension_id: "QD4"`
- `probe_id` match `^P-QD4-[a-z0-9-]+$`
- `description` >= 10 ky tu
- It nhat 1 evidence field non-empty (ADR-09)

Raw output: `$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/raw/P-QD4-<probe>.json`

## 2. Scan Cache Protocol

Cache policy: **allowed** cho static probes. Runtime probes luon skip cache.

## 3. Severity Mapping (QD4)

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
