# P-QD9-dev-server-bootstrap — Dev Server Bootstrap Probe

> **Type:** runtime (bash+curl) | **Profile:** standard/deep/exhaustive | **Severity default:** HIGH | **Cache:** skip (always runtime)
> **Error code:** E095 (dev_server_bootstrap_fail — timeout 30s hoac no dev cmd)
> **Parallel class:** runtime → sequential (phai chay truoc cac probes browser khac)

Xac nhan dev server da start va accessible truoc khi cac probes browser chay. Output `dev-server-state.json` cho probes downstream reuse (QD9 console-network-monitor, auth-aware-smoke; QD10 multi-platform-entity-sync).

---

## Reuses from

**Pattern:** Process spawn hoc tu `_shared/concurrency/` background spawn convention. Probe nay la NEW (khong co precedent trong QD1-QD8) — nhung follow pattern concurrency utility cua _shared.

| Aspect | Source | Notes |
|--------|--------|-------|
| `with_runtime_cap` guard | `.claude/scripts/wf-fix-common.sh:134-148` | 600s cap chong hang probe |
| `atomic_write_json` | `.claude/scripts/wf-fix-common.sh:86-102` | Atomic write dev-server-state.json |
| `json_escape` helper | `.claude/scripts/wf-fix-common.sh:82-84` | JSON-safe string |
| `emit_signal_no_location` pattern | `procedures/probes/_shared.md:88-106` | Dev server fail khong co URL location |
| BASE_URL detect output | `.claude/scripts/wf-fix-detect-base-url.sh` | Doc JSON result tu W1.2 detect |
| Background spawn + trap EXIT | `_shared/concurrency/` spawn pattern | Cleanup spawned process |

**Diff:** QD8 `P-QD8-health-check-probe.md` kiem tra existing health endpoint — probe nay bootstrap server TRUOC khi test, tao tien de cho moi probe browser.

---

## CI-ROUTE

| Task | CI Tool | Fallback | Notes |
|------|---------|----------|-------|
| *(khong can code analysis)* | — | — | Pure runtime probe — server da chay hay chua la runtime fact, khong the detect qua static analysis |

---

## Detection Logic

Variables duoc source tu `procedures/probes/_shared.md`:

```
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health"
RAW_DIR="$LANE_DIR/raw"
DEV_SERVER_STATE="$LANE_DIR/dev-server-state.json"
```

### Step 1 — Doc BASE_URL tu detect output hoac orchestrator

```bash
# BASE_URL duoc orchestrator truyen qua --base-url arg (tu W1.2 detect output)
# Neu khong co: chay detect-base-url.sh de tim

if [ -z "${BASE_URL:-}" ]; then
  echo "INFO: BASE_URL chua set, chay wf-fix-detect-base-url.sh..." >&2
  DETECT_JSON=$(bash .claude/scripts/wf-fix-detect-base-url.sh \
    --project-root="${PROJECT_ROOT:-.}")
  # Lay app dau tien co status != mobile_skip
  BASE_URL=$(echo "$DETECT_JSON" | jq -r \
    '.apps[] | select(.status != "mobile_skip") | .base_url' | head -1)
  APP_NAME=$(echo "$DETECT_JSON" | jq -r \
    '.apps[] | select(.status != "mobile_skip") | .name' | head -1)
  APP_DIR=$(echo "$DETECT_JSON" | jq -r \
    '.apps[] | select(.status != "mobile_skip") | .name' | head -1)
fi

if [ -z "${BASE_URL:-}" ] || [ "$BASE_URL" = "null" ]; then
  # E094: BASE_URL khong detect duoc → emit signal + skip
  emit_signal_no_location \
    "P-QD9-dev-server-bootstrap" "HIGH" \
    "App URL khong detect duoc — browser probes se bi skip (E094)" \
    "Khong tim duoc URL app web. Cung cap --base-url hoac kiem tra config: package.json scripts.dev, vite.config.ts, next.config.mjs." \
    "[]"
  atomic_write_json "$DEV_SERVER_STATE" \
    '{"status":"skipped","reason":"E094_BASE_URL_UNKNOWN","pid":null,"url":null}'
  exit 0
fi

echo "INFO: BASE_URL=$BASE_URL" >&2
```

### Step 2 — HTTP HEAD check (dev server co dang chay khong?)

```bash
HTTP_STATUS=$(curl --max-time 5 --silent \
  -o /dev/null -w "%{http_code}" "$BASE_URL" 2>/dev/null || echo "000")

if echo "$HTTP_STATUS" | grep -qE '^[23]'; then
  echo "INFO: Dev server da accessible: $BASE_URL (HTTP $HTTP_STATUS) — skip spawn" >&2
  atomic_write_json "$DEV_SERVER_STATE" \
    "$(jq -nc \
      --arg url "$BASE_URL" \
      '{status:"already_running",pid:null,url:$url,spawned:false}')"
  exit 0
fi

echo "INFO: Dev server chua accessible (HTTP $HTTP_STATUS) — can spawn" >&2
```

### Step 3 — Parse package.json scripts.dev → spawn background process

```bash
# Tim package.json: thu uu tien app dir truoc, sau do project root
PKG_JSON=""
for candidate in \
  "${APP_DIR:+$PROJECT_ROOT/apps/$APP_DIR}/package.json" \
  "$PROJECT_ROOT/package.json"; do
  [ -f "${candidate:-}" ] && PKG_JSON="$candidate" && break
done

DEV_CMD=""
if [ -n "${PKG_JSON:-}" ]; then
  DEV_CMD=$(jq -r '.scripts.dev // .scripts.start // empty' "$PKG_JSON" 2>/dev/null || true)
fi

if [ -z "${DEV_CMD:-}" ]; then
  emit_signal_no_location \
    "P-QD9-dev-server-bootstrap" "HIGH" \
    "Khong tim duoc dev server command — browser probes se bi skip (E095)" \
    "package.json tai '${PKG_JSON:-project root}' khong co scripts.dev hoac scripts.start. Cannot auto-bootstrap dev server. Hay start thu cong truoc khi chay /wf-fix-bugs." \
    "[]"
  atomic_write_json "$DEV_SERVER_STATE" \
    "$(jq -nc \
      --arg url "$BASE_URL" \
      --arg pkg "${PKG_JSON:-unknown}" \
      '{status:"fail",reason:"E095_NO_DEV_CMD",pid:null,url:$url,pkg:$pkg}')"
  exit 0
fi

echo "INFO: Spawning dev server: [$DEV_CMD]" >&2

# Spawn background (dung npm run dev trong du-an dir)
PKG_DIR=$(dirname "$PKG_JSON")
(cd "$PKG_DIR" && eval "$DEV_CMD" >/dev/null 2>&1) &
DEV_SERVER_PID=$!
echo "INFO: Spawned PID=$DEV_SERVER_PID in $PKG_DIR" >&2

# Cleanup trap: kill spawned server khi probe session ket thuc
# Luu y: orchestrator co the tiep tuc dung server — probe chi kill khi EXIT
trap "kill $DEV_SERVER_PID 2>/dev/null || true; echo 'INFO: killed dev server PID=$DEV_SERVER_PID' >&2" EXIT
```

### Step 4 — Retry HTTP check max 30s

```bash
MAX_WAIT=30
ELAPSED=0
BOOTSTRAPPED=0

while [ "$ELAPSED" -lt "$MAX_WAIT" ]; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  HTTP_STATUS=$(curl --max-time 3 --silent \
    -o /dev/null -w "%{http_code}" "$BASE_URL" 2>/dev/null || echo "000")
  if echo "$HTTP_STATUS" | grep -qE '^[23]'; then
    BOOTSTRAPPED=1
    echo "INFO: Dev server ready sau ${ELAPSED}s (HTTP $HTTP_STATUS)" >&2
    break
  fi
  echo "DEBUG: Wait ${ELAPSED}/${MAX_WAIT}s — HTTP $HTTP_STATUS" >&2
done
```

### Step 5 — Emit signal neu bootstrap fail

```bash
if [ "$BOOTSTRAPPED" = "0" ]; then
  emit_signal_no_location \
    "P-QD9-dev-server-bootstrap" "HIGH" \
    "Dev server khong start sau ${MAX_WAIT}s — browser probes se bi skip (E095)" \
    "Chay [$DEV_CMD] (PID=$DEV_SERVER_PID) nhung $BASE_URL van unreachable sau ${MAX_WAIT}s. Kiem tra: port conflict, missing node_modules, env vars thieu. Cac probes browser (console-monitor, auth-smoke) se bi skip." \
    "[]"
  atomic_write_json "$DEV_SERVER_STATE" \
    "$(jq -nc \
      --arg url "$BASE_URL" \
      --argjson pid "$DEV_SERVER_PID" \
      --argjson waited "$MAX_WAIT" \
      '{status:"fail",reason:"E095_TIMEOUT",pid:$pid,url:$url,waited_seconds:$waited}')"
  # Trap se kill pid khi exit
  exit 0
fi
```

### Step 6 — Write dev-server-state.json cho downstream probes

```bash
# dev-server-state.json: QD9 downstream probes + QD10 doc de reuse
atomic_write_json "$DEV_SERVER_STATE" \
  "$(jq -nc \
    --arg url "$BASE_URL" \
    --argjson pid "$DEV_SERVER_PID" \
    '{status:"running",pid:$pid,url:$url,spawned:true}')"
echo "INFO: dev-server-state.json ghi OK — $DEV_SERVER_STATE" >&2

# Giai phong trap: probe thanh cong, orchestrator chiu trach nhiem manage server
# Neu muon kill sau probe: orchestrator doc pid tu dev-server-state.json
trap - EXIT
echo "INFO: Trap cleared — dev server PID=$DEV_SERVER_PID con chay (orchestrator manage)" >&2
```

### Step 7 — Cleanup contract (EXIT trap)

```bash
# Neu chay wf-fix-probe-dev-server.sh standalong (khong phai qua orchestrator):
#   Exit trap tu Step 3 van hieu luc neu BOOTSTRAPPED=0
#   Neu BOOTSTRAPPED=1: trap da bi clear o Step 6 → server con song
#
# Orchestrator flow:
#   - Doc dev-server-state.json.pid sau tat ca probes xong
#   - Kill: kill $(jq -r '.pid' dev-server-state.json) 2>/dev/null
#
# Trong standalone (bash helper) mode: server bi kill khi script exit (trap tu Step 3 van hieu luc neu Bootstrap=0)
```

---

## Negative Patterns (KHONG emit signal)

1. Dev server da chay (HTTP 2xx/3xx truoc Step 3) → skip spawn, ghi `already_running`.
2. `interface_type=api-only` → lane QD9 bi SKIP truoc khi probe nay chay (E092).
3. `--no-browser` flag → lane QD9 bi SKIP truoc khi probe nay chay (E093).
4. curl khong co tren system → emit signal voi evidence "curl missing", suggest install.

---

## Dedup Hints

```json
{
  "dedup_key": "dev_server_bootstrap_fail|{base_url}|{reason}",
  "merge_scope": "session",
  "notes": "Chi 1 probe nay emit E094/E095 per session per app. Cac signals khong trung lap voi probes khac."
}
```

---

## Signal Schema (signal-v2)

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-dev-server-bootstrap",
  "dimension_id": "QD9",
  "signal_type": "dev_server_bootstrap_fail",
  "severity": "HIGH",
  "title": "Dev server khong start sau 30s — browser probes se bi skip (E095)",
  "description": "Chay [npm run dev] nhung http://localhost:PORT van unreachable sau 30s...",
  "location": {},
  "evidence": [
    {"type": "log_excerpt", "content": "curl HTTP=000 sau 30s retry"}
  ],
  "cdg_flags": [],
  "fixability": "agent_fix"
}
```

---

## Fallback Table

| Failure Mode | Signal Type | Severity | Code | Next Action |
|--------------|-------------|----------|------|-------------|
| BASE_URL khong detect | `app_unreachable` | HIGH | E094 | Skip remaining browser probes |
| package.json thieu scripts.dev | `dev_server_bootstrap_fail` | HIGH | E095 | Skip remaining browser probes |
| Timeout 30s chay | `dev_server_bootstrap_fail` | HIGH | E095 | Skip remaining browser probes |
| curl khong co | `dev_server_bootstrap_fail` | HIGH | E095 | Emit + note "curl missing" |
| Spawn fail (port conflict) | `dev_server_bootstrap_fail` | HIGH | E095 | Kill + retry hoac skip |

---

## Cache Policy

**skip** — always runtime. Trang thai dev server thay doi theo session. Khong cache.

---

## Output

| File | Required | Content |
|------|----------|---------|
| `$LANE_DIR/dev-server-state.json` | yes | `{status, pid, url, spawned}` |
| `$RAW_DIR/P-QD9-dev-server-bootstrap.jsonl` | if fail | Signals JSONL |

**Cross-lane coordination:** QD10 `P-QD10-multi-platform-entity-sync` doc `dev-server-state.json.url` de reuse BASE_URL va `pid` de biet server co dang chay khong.
