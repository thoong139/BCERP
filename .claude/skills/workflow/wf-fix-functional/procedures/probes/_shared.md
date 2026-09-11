# _shared.md — Cross-Probe Protocols cho QD1 Lane

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
pw_type() { $PW_CMD --action=type --selector="$1" --text="$2" 2>&1; }
pw_wait() { $PW_CMD --action=wait ${1:+--time="$1"} ${2:+--selector="$2"} 2>&1; }
pw_console() { $PW_CMD --action=console 2>&1; }
pw_network() { $PW_CMD --action=network 2>&1; }
pw_select() { $PW_CMD --action=select --selector="$1" --values="$2" 2>&1; }
pw_press_key() { $PW_CMD --action=press_key --key="$1" 2>&1; }
pw_resize() { $PW_CMD --action=resize --width="$1" --height="$2" 2>&1; }
pw_tabs() { $PW_CMD --action=tabs 2>&1; }
pw_back() { $PW_CMD --action=back 2>&1; }
```

## 1. Signal Emission Protocol

Moi probe emit signals theo schema `signal-v2`. Signal dict:

```json
{
  "probe_id": "P-QD1-<probe-slug>",
  "probe_version": "1.0.0",
  "emitted_at": "2026-04-21T08:00:00Z",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "target": {
    "kind": "code|route|ui_page|config_file",
    "file_path": "src/...",
    "line_range": [42, 58],
    "symbol": "functionName"
  },
  "description": "Mo ta issue >= 20 ky tu",
  "evidence": {
    "code_snippet": "...",
    "screenshot_path": "...",
    "log_excerpt": "...",
    "spec_ref": "..."
  },
  "suggested_severity": "critical|high|medium|low",
  "dedup_hints": ["REQ-XXX", "feature-slug"]
}
```

### Rang buoc:
- `probe_id` phai match `^P-QD[1-8]-[a-z0-9-]+$`
- `description` phai >= 20 ky tu
- It nhat 1 evidence field non-empty:
  - `code_snippet` min 10 chars
  - `log_excerpt` min 20 chars
  - `stacktrace` min 50 chars
  - `screenshot_path`, `spec_ref`, `test_failure_ref` min 1 char
- `target.kind` bat buoc
- `suggested_severity` ∈ {critical, high, medium, low}

### Signal accumulation:
1. Moi probe viet signals vao `$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/P-QD1-<probe>.json`
2. Sau tat ca probes, lane gop vao `$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/signals.json`

## 2. Scan Cache Protocol

Chi ap dung khi `$USE_CACHE=true` va `cache_policy != "skip"` trong dimension.json.

```bash
# Truoc khi scan file
FP=$(python -m _shared.scan_cache.fingerprint \
  --probe-id "$PROBE_ID" \
  --probe-version "1.0.0" \
  --file "$FILE")

HIT=$(python -m _shared.scan_cache.cache_lookup \
  --cache-root ".mc-data/cache/wf-fix-bugs/probes/" \
  --fingerprint "$FP")

if [ -z "$HIT" ]; then
  # MISS — chay probe binh thuong
  # ...
  # Luu ket qua vao cache:
  python -m _shared.scan_cache.cache_store store \
    --probe-id "$PROBE_ID" \
    --probe-version "1.0.0" \
    --file "$FILE" \
    --signals-file "$RAW_OUTPUT" \
    --cache-root ".mc-data/cache/wf-fix-bugs/probes/"
else
  # HIT — reuse cached signals
  echo "Cache HIT cho $PROBE_ID / $FILE"
  cat "$HIT" >> "$ACCUMULATED_SIGNALS"
fi
```

### Cache policies (tu dimension.json):
- `allowed` — cache khi `--use-cache` set
- `skip` — khong bao gio cache (runtime probes, security probes)

## 3. Severity Mapping (QD1)

| Dieu kien | Severity | Confidence |
|-----------|----------|-----------|
| Infrastructure down | CRITICAL | 0.95 |
| impl_status=done + endpoint HTTP 5xx | CRITICAL | 0.90 |
| impl_status=done + endpoint khong ton tai | CRITICAL | 0.90 |
| UI primary CTA khong click duoc | HIGH | 0.85 |
| impl_status=done + REQ-ID khong co code ref | HIGH | 0.90 |
| impl_status=done + route mismatch spec | HIGH | 0.85 |
| Orphan UI element | MEDIUM | 0.70 |
| impl_status!=done + REQ-ID khong co code ref | MEDIUM | 0.80 |
| Route config minor discrepancy | LOW | 0.60 |

## 4. Profile-Based Probe Selection

```
PROFILE="$PROFILE"

case "$PROFILE" in
  quick)
    PROBES="P-QD1-req-registry-xref P-QD1-infra-preflight P-QD1-api-smoke"
    ;;
  standard)
    PROBES="P-QD1-req-registry-xref P-QD1-route-config-parse P-QD1-stub-todo-aggregate P-QD1-infra-preflight P-QD1-deep-ui-traversal P-QD1-api-smoke P-QD1-orphan-ui-detect"
    ;;
  deep)
    PROBES="P-QD1-req-registry-xref P-QD1-route-config-parse P-QD1-stub-todo-aggregate P-QD1-multitenant-isolation-audit P-QD1-infra-preflight P-QD1-deep-ui-traversal P-QD1-api-smoke P-QD1-orphan-ui-detect P-QD1-spec-completeness-check P-QD1-agent-feature-verify"
    ;;
  exhaustive)
    PROBES="ALL"
    ;;
esac
```

## 5. Checkpoint Protocol

Sau moi probe hoan thanh, cap nhat lane-status.json:
```bash
jq --arg probe "$PROBE_ID" --arg status "completed" --arg signals "$SIGNAL_COUNT" \
  '.probes[$probe] = {"status": $status, "signals_emitted": ($signals|tonumber)}' \
  "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/lane-status.json" > tmp.json && mv tmp.json "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/lane-status.json"
```
