# P-QD9-console-network-monitor — Console & Network Error Monitor

> **Type:** runtime (Playwright bash-level) | **Profile:** standard, deep, exhaustive | **Cache:** skip (always runtime)
> **Parallel class:** runtime → sequential (browser session; chay sau P-QD9-dev-server-bootstrap)
> **Signal types:** `runtime_console_error` (MEDIUM), `runtime_uncaught_exception` (CRITICAL), `runtime_network_failure` (HIGH/MEDIUM)

Traverse cac route tu homepage, inject error tracking, thu thap console errors + network failures + uncaught exceptions. Moi loi phat sinh 1 signal rieng (KHONG gop chung). CI-ROUTE: Serena `find_symbol` de map stack trace → source file; GitNexus `query("navigation, route, link")` de augment route list.

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| Console listener pattern | `QD5 P-QD5-ui-traversal-deep.md` | `:62-65` | `msg.type()==='error'` filter, `.text().substring(0,200)`, `.url()` capture |
| Pageerror listener pattern | `QD5 P-QD5-ui-traversal-deep.md` | `:67-70` | `err.message.substring(0,200)`, `uncaught:true` flag |
| Navigation graph builder (B1) | `QD1 P-QD1-deep-ui-traversal.md` | `:36-48` | `browser_navigate → snapshot → extract NAV_LINKS[]` pattern |
| Navigation graph builder (B2) | `QD1 P-QD1-deep-ui-traversal.md` | `:49-59` | dedup by href, exclusion list (`/login /auth /api /_next`), NAV_ROUTES[] queue |
| MAX_PAGES traversal guard | `QD1 P-QD1-deep-ui-traversal.md` | `:103-106` | `MAX_PAGES=20`, VISITED set, `PAGE_QUEUE.shift()` pattern |
| Browser launch + close | `procedures/probes/_shared.md` | `:26-44` | `pw_launch` / `pw_close` + trap EXIT |
| `emit_signal_browser` pattern | `procedures/probes/_shared.md` | `:51-86` | signal-v2 schema, atomic append toi RAW_DIR/probe_id.jsonl |
| Common variables | `procedures/probes/_shared.md` | `:7-18` | `LANE_DIR, RAW_DIR, SIGNALS_FILE, SESSION_FILE, DEV_SERVER_STATE` |
| Output truncation | `procedures/probes/_shared.md` | `:171-179` | Console msg max 500 chars, stack max 20 frames |
| Playwright bash-level polling | `procedures/probes/_shared.md` | `:109-143` | `pw_console`, `pw_network`, `pw_evaluate` cho pageerror |

**Diff so voi QD5 P-QD5-ui-traversal-deep:**
- QD5 dung standalone Node.js script (`traversal.js`) voi `page.on('console')` event listeners.
- QD9 dung Playwright bash-level tools (polling `pw_console` + `pw_network` sau moi navigate) vi QD9 dung MCP protocol.
- QD9 phat sinh 1 signal rieng moi loi (khong gop nhu QD5 emit count metric).
- QD9 map stack trace → source file qua Serena `find_symbol` (CI-ROUTE PRIMARY).

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Map console error stack trace → source file | **Serena** `find_symbol({name_path_pattern: "<ClassName>.<method>", relative_path: null, include_body: false})` | Grep `file:line` pattern trong stack trace | Khi console error co stack trace, xac dinh file nguon de populate `location.file_path + line_range` trong signal |
| Augment navigation route list | **GitNexus** `query("navigation, route, link")` | Parse `<a href>` tu `pw_snapshot` (B2 fallback) | Tim them routes khong reachable qua link traversal (SPA dynamic routes) |
| Check source file exists cho stack reference | **Serena** `find_symbol` exact file match | Glob file path | Validate stack trace file reference ton tai trong codebase |

**Khi CI unavailable:** Set `$GITNEXUS_AVAILABLE` / `$SERENA_AVAILABLE` tu `ci-detect.sh` output. Log warning neu fallback. Khong block probe.

---

## PRE-GATE

```
1. IF profile=quick: SKIP probe, note "QD9-quick-no-browser"
2. IF --no-browser: SKIP probe (da SKIP toan lane E093 — probe nay khong duoc goi)
3. IF DEV_SERVER_STATE khong ton tai HOAC DEV_SERVER_STATE.status == "fail":
     SKIP probe, note "skipped_dev_server_not_ready (E095 upstream)"
4. Read BASE_URL tu DEV_SERVER_STATE.url (KHONG chay detect lai)
5. IF BASE_URL == null hoac "": SKIP probe, note "skipped_no_base_url"
6. pw_launch — tra ve E096 neu fail sau 30s
7. trap "pw_close" EXIT
```

---

## SENSE

### B1 — Navigate homepage, capture snapshot (REUSE QD1 B1 pattern)

```
1. pw_navigate "$BASE_URL/"
   → wait_until="networkidle" (hoac domcontentloaded cho SPA nhanh hon)
2. pw_wait "2000"
3. pw_screenshot "$LANE_DIR/evidence/P-QD9-cnm-homepage.png"
4. snapshot = pw_snapshot
5. Parse snapshot → lay $NAV_LINKS[]: tat ca a[href] chua "/" (same-origin)
```

Parse NAV_LINKS theo pattern QD1 B1:
- Chi lay href bat dau bang "/" (relative) hoac bat dau bang BASE_URL (absolute)
- Loai bo: `#anchor`, `javascript:`, `/logout`, `/sign-out`
- Loai bo: `/_next/`, `/api/`, `/auth/`, `/login`, `/signin` (exclusion list)

### B2 — Build navigation queue (REUSE QD1 B2 pattern)

```
NAV_ROUTES = []
FOR moi link trong NAV_LINKS[]:
  href = link.href (normalize ve relative path)
  IF href trong exclusion list → skip
  IF href da trong NAV_ROUTES → skip (dedup)
  NAV_ROUTES.append({href, text: link.textContent})

MAX_ROUTES = 20  — profile=standard
MAX_ROUTES = 50  — profile=deep
MAX_ROUTES = 100 — profile=exhaustive
```

### B3 — CI-ROUTE: Augment routes via GitNexus (neu available)

```
IF $GITNEXUS_AVAILABLE == "true":
  gi_routes = gitnexus_query("navigation, route, link")
  FOR moi route trong gi_routes.results:
    IF route.path bat dau bang "/" AND khong trong NAV_ROUTES:
      NAV_ROUTES.append({href: route.path, text: route.label, source: "gitnexus"})
  LOG "INFO: GitNexus augmented route list to N routes" >&2
ELSE:
  LOG "WARN: GitNexus unavailable — only link traversal routes (CI degraded)" >&2
```

---

## THINK

### Xac dinh traversal scope

1. `$TRAVERSAL_ROUTES = NAV_ROUTES[0..MAX_ROUTES]` (respect MAX_ROUTES cap)
2. Homepage (`$BASE_URL/`) luon nam trong scope (even if NAV_ROUTES rong)
3. Uu tien routes co text match: Dashboard, Home, List, Create, Edit, Report, Settings
4. Skip: /logout, /sign-out, /auth/callback (ttranh logout session)

### Per-error signal policy

- **KHONG gop signals** — moi console error rieng 1 signal, moi network failure rieng 1 signal
- Dedup key: `sha256(probe_id + signal_type + page_url + message[0:100])`
- Neu cung URL + cung message type → ghi first occurrence, skip duplicate (dedup_hints check)
- Max signals per probe: 50 (neu vuot → truncate, emit WARNING "max_signals_reached")

### Stack trace → source file (CI-ROUTE)

Khi console error hoac pageerror co stack trace:
```
1. Parse stack trace: tim dong co pattern "at Classname.method (file.ts:line:col)" hoac "/path/to/file.ts:line"
2. IF $SERENA_AVAILABLE == "true":
   Serena find_symbol({name_path_pattern: "<ClassName>", relative_path: "<file.ts>"})
   → lay file_path va line range chinh xac
   → populate signal.location.file_path + signal.location.line_range
3. ELSE: parse file:line truc tiep tu stack text → populate location (fallback)
4. Max stack frames: 20 (truncation per _shared.md)
```

---

## ACT

### A1 — Traverse + Monitor moi route

```
VISITED = Set()
ROUTE_QUEUE = [$BASE_URL + "/"] + [($BASE_URL + route.href) FOR route IN $TRAVERSAL_ROUTES]
SIGNAL_COUNT = 0

WHILE ROUTE_QUEUE khong rong AND |VISITED| < MAX_ROUTES:
  page_url = ROUTE_QUEUE.shift()
  IF page_url trong VISITED → continue
  VISITED.add(page_url)

  LOG "INFO: Traverse route: $page_url" >&2

  # A1.1 — Navigate
  pw_navigate "page_url
  pw_wait "2000"

  # A1.2 — Inject pageerror tracking (REUSE _shared.md:109-125)
  pw_evaluate "
    if (!window.__QD9_UNCAUGHT__) {
      window.__QD9_UNCAUGHT__ = [];
      window.addEventListener('error', function(e) {
        window.__QD9_UNCAUGHT__.push({
          type: 'uncaught_exception',
          message: (e.message || '').substring(0, 500),
          filename: e.filename || '',
          lineno: e.lineno || 0,
          colno: e.colno || 0,
          stack: (e.error && e.error.stack) ? e.error.stack.split('\\n').slice(0,20).join('\\n') : ''
        });
      });
      window.addEventListener('unhandledrejection', function(e) {
        var msg = String(e.reason || '').substring(0, 500);
        var stack = (e.reason && e.reason.stack) ? e.reason.stack.split('\\n').slice(0,20).join('\\n') : '';
        window.__QD9_UNCAUGHT__.push({type: 'unhandled_rejection', message: msg, stack: stack});
      });
    }
  """)

  # A1.3 — Wait short moment for async errors
  pw_wait "1000"

  # A1.4 — Poll console messages (REUSE QD5 :62-65 listener intent → MCP poll)
  console_msgs = pw_console
  FOR moi msg trong console_msgs:
    IF msg.type == "error":
      text = msg.text[0:500]  — truncation per _shared.md
      url_from_loc = msg.location.url if available else page_url

      # CI-ROUTE: map stack → source nếu có location info
      file_path = null
      line_range = [0, 0]
      IF msg.location AND msg.location.url AND msg.location.lineNumber:
        # Try Serena find_symbol (chu y: 0-based lines tu Serena)
        IF $SERENA_AVAILABLE == "true":
          # parse relative path tu msg.location.url
          rel = parse_relative_path(msg.location.url, PROJECT_ROOT)
          sym_info = serena_find_symbol({relative_path: rel})
          IF sym_info.line == msg.location.lineNumber:
            file_path = rel
            line_range = [msg.location.lineNumber, msg.location.lineNumber]
        ELSE:
          file_path = msg.location.url
          line_range = [msg.location.lineNumber, msg.location.lineNumber]

      EMIT_SIGNAL_BROWSER(
        probe_id = "P-QD9-console-network-monitor"
        signal_type = "runtime_console_error"
        severity = "MEDIUM"
        title = "Console error tai " + page_url + ": " + text[0:80]
        description = "JavaScript console.error() detected tai " + page_url + ". Message: " + text
        page_url = page_url
        location = {file_path, line_range}
        evidence_type = "log_excerpt"
        evidence_content = text
        screenshot_path = null  — screenshot chi khi CRITICAL
      )

      SIGNAL_COUNT++
      IF SIGNAL_COUNT >= 50: BREAK (max_signals_reached)

  # A1.5 — Poll uncaught exceptions (REUSE QD5 :67-70 pageerror intent → MCP evaluate)
  uncaught_list = pw_evaluate "return (window.__QD9_UNCAUGHT__ || [].splice(0)")
  FOR moi err trong uncaught_list:
    msg_text = err.message[0:500]
    stack_text = err.stack[0:2000] if err.stack else ""
    # 20-frame truncation per _shared.md

    # CI-ROUTE: Serena map stack → source
    file_path = null; line_range = [0, 0]
    IF err.filename:
      rel = parse_relative_path(err.filename, PROJECT_ROOT)
      IF $SERENA_AVAILABLE == "true" AND err.lineno:
        sym_info = serena_find_symbol({relative_path: rel, include_body: false})
        file_path = rel
        line_range = [err.lineno, err.lineno]
      ELSE:
        file_path = rel
        line_range = [err.lineno or 0, err.lineno or 0]

    # Screenshot cho CRITICAL signals
    shot_path = "$LANE_DIR/evidence/P-QD9-cnm-uncaught-{hash(page_url+msg_text)[:8]}.png"
    pw_screenshot "shot_path

    EMIT_SIGNAL_BROWSER(
      probe_id = "P-QD9-console-network-monitor"
      signal_type = "runtime_uncaught_exception"
      severity = "CRITICAL"
      title = "Uncaught exception tai " + page_url + ": " + msg_text[0:80]
      description = (err.type + " detected tai " + page_url + ". " +
                     "Message: " + msg_text +
                     (". Stack: " + stack_text[0:500] if stack_text else ""))
      page_url = page_url
      location = {file_path, line_range}
      evidence_type = "log_excerpt"
      evidence_content = msg_text + ("|stack:" + stack_text[0:500] if stack_text else "")
      screenshot_path = shot_path
    )
    SIGNAL_COUNT++

  # A1.6 — Poll network requests (status >= 400)
  net_reqs = pw_network
  FOR moi req trong net_reqs:
    status = req.status
    IF status < 400: continue
    url_req = req.url[0:200]
    method = req.method

    IF req.url contains "$BASE_URL" OR req.url starts_with "/":
      # Same-origin request — emit signal
      sig_type = "runtime_network_failure"
      IF status >= 500:
        sev = "HIGH"
      ELIF status == 401 OR status == 403:
        sev = "MEDIUM"  # Auth wall — expected cho protected routes
      ELSE:  # 4xx non-auth
        sev = "MEDIUM"

      EMIT_SIGNAL_BROWSER(
        probe_id = "P-QD9-console-network-monitor"
        signal_type = sig_type
        severity = sev
        title = (method + " " + url_req + " returned HTTP " + status + " tai " + page_url)
        description = ("Network request " + method + " " + url_req +
                       " returned HTTP " + str(status) +
                       " while on page " + page_url + "." +
                       (" Server error — kiem tra API handler." if status >= 500 else
                        " Client error — kiem tra API path, params."))
        page_url = page_url
        evidence_type = "network_trace"
        evidence_content = method + " " + url_req + " → HTTP " + str(status)
        screenshot_path = null
      )
      SIGNAL_COUNT++

  # A1.7 — Collect additional nav links cho depth traversal (tuong tu QD1 B2)
  IF |VISITED| < MAX_ROUTES:
    snap = pw_snapshot
    new_links = parse_same_origin_links(snap, BASE_URL, exclusion_list)
    FOR link trong new_links:
      IF link khong trong VISITED AND link khong trong ROUTE_QUEUE:
        ROUTE_QUEUE.append(link)
```

### A2 — Cleanup

```
pw_close()
LOG "INFO: P-QD9-console-network-monitor DONE. Routes visited: N, Signals: SIGNAL_COUNT" >&2
```

---

## VERIFY

1. Moi signal co `dimension_id == "QD9"` va `probe_id == "P-QD9-console-network-monitor"`
2. Moi `runtime_uncaught_exception` signal co `severity == "CRITICAL"`
3. Moi `runtime_console_error` signal co `severity == "MEDIUM"`
4. `runtime_network_failure` co `severity == "HIGH"` khi status >= 500, `"MEDIUM"` khi 4xx
5. Moi signal co `evidence[]` non-empty voi `content` >= 10 chars
6. CRITICAL signals co `screenshot` path (file exists hoac note "capture_failed")
7. Dedup: khong co 2 signals co cung (signal_type + page_url + message[0:100])
8. Tong signals per probe <= 50 (hoac co WARNING signal "max_signals_reached")
9. Routes visited: ghi vao `$LANE_DIR/raw/P-QD9-console-network-monitor-summary.json`

```json
{
  "probe_id": "P-QD9-console-network-monitor",
  "routes_visited": N,
  "routes_max": MAX_ROUTES,
  "console_errors": C,
  "uncaught_exceptions": U,
  "network_failures": F,
  "signals_emitted": S,
  "gitnexus_used": true/false,
  "serena_used": true/false
}
```

---

## Severity Rules

| Signal Type | Dieu kien | Severity | Ly do |
|-------------|-----------|----------|-------|
| `runtime_uncaught_exception` | pageerror (uncaught JS exception) | **CRITICAL** | Loi nghiem trong nhat — app crash |
| `runtime_uncaught_exception` | unhandledrejection | **CRITICAL** | Promise reject khong duoc xu ly |
| `runtime_network_failure` | HTTP 5xx | **HIGH** | Server error — tac dong truc tiep |
| `runtime_network_failure` | HTTP 4xx (401/403 auth wall) | **MEDIUM** | Expected cho protected routes; non-critical |
| `runtime_network_failure` | HTTP 4xx (non-auth: 404/400/422) | **MEDIUM** | Client error — API path/params sai |
| `runtime_console_error` | console.error() | **MEDIUM** | JS exception co the anh huong tinh nang |

> **DEC-W1.5-A:** pageerror → CRITICAL (follow `_shared.md` severity table), KHONG phai HIGH nhu W1.5 spec goc. Rationale: uncaught exception = app crash — CRITICAL la dung (P1 Correctness > spec literal).

---

## Dedup Hints

```json
{
  "dedup_key": "sha256(probe_id + \"|\" + signal_type + \"|\" + page_url + \"|\" + message[0:100])",
  "merge_scope": "session",
  "notes": "Cung URL + cung message type + cung message prefix → ghi first occurrence. Cross-probe dedup voi QD5 P-QD5-ui-traversal-deep: console error o QD5 co the trung voi QD9 — aggregator dedup boi (dimension_id, probe_id, fingerprint). QD9 signals mang location chi tiet hon (Serena stack mapping)."
}
```

---

## Signal Schema Examples

**runtime_console_error:**
```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-console-network-monitor",
  "dimension_id": "QD9",
  "signal_type": "runtime_console_error",
  "severity": "MEDIUM",
  "title": "Console error tai /dashboard/crm: TypeError: Cannot read property 'id' of undefined",
  "description": "JavaScript console.error() detected tai http://localhost:3000/dashboard/crm. Message: TypeError: Cannot read property 'id' of undefined at CustomerList.render (customer-list.tsx:45)",
  "location": {
    "file_path": "apps/erp-web/src/components/customer-list.tsx",
    "line_range": [45, 45],
    "url": "http://localhost:3000/dashboard/crm"
  },
  "evidence": [
    {"type": "log_excerpt", "content": "TypeError: Cannot read property 'id' of undefined at CustomerList.render (customer-list.tsx:45:12)"}
  ],
  "screenshot": null,
  "cdg_flags": [],
  "fixability": "agent_fix"
}
```

**runtime_uncaught_exception:**
```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-console-network-monitor",
  "dimension_id": "QD9",
  "signal_type": "runtime_uncaught_exception",
  "severity": "CRITICAL",
  "title": "Uncaught exception tai /quotes/new: ReferenceError: fetchQuote is not defined",
  "description": "uncaught_exception detected tai http://localhost:3000/quotes/new. Message: ReferenceError: fetchQuote is not defined. Stack: ReferenceError: fetchQuote is not defined\\n    at QuoteForm.handleSubmit (quote-form.tsx:102:5)...",
  "location": {
    "file_path": "apps/erp-web/src/pages/quotes/new.tsx",
    "line_range": [102, 102],
    "url": "http://localhost:3000/quotes/new"
  },
  "evidence": [
    {"type": "log_excerpt", "content": "ReferenceError: fetchQuote is not defined|stack:ReferenceError: fetchQuote is not defined\\n    at QuoteForm.handleSubmit (quote-form.tsx:102:5)"}
  ],
  "screenshot": "$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/evidence/P-QD9-cnm-uncaught-a1b2c3d4.png",
  "cdg_flags": [],
  "fixability": "agent_fix"
}
```

**runtime_network_failure (5xx):**
```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-console-network-monitor",
  "dimension_id": "QD9",
  "signal_type": "runtime_network_failure",
  "severity": "HIGH",
  "title": "GET /api/customers returned HTTP 500 tai /dashboard/crm",
  "description": "Network request GET /api/customers returned HTTP 500 while on page http://localhost:3000/dashboard/crm. Server error — kiem tra API handler.",
  "location": {
    "url": "http://localhost:3000/dashboard/crm"
  },
  "evidence": [
    {"type": "network_trace", "content": "GET /api/customers → HTTP 500"}
  ],
  "screenshot": null,
  "cdg_flags": [],
  "fixability": "agent_fix"
}
```

---

## Fallback Table

| Failure Mode | Hanh vi | Signal | Code |
|--------------|---------|--------|------|
| DEV_SERVER_STATE.status = "fail" | SKIP probe, note "skipped_dev_server_not_ready" | none | E095 upstream |
| BASE_URL null | SKIP probe, note "skipped_no_base_url" | none | E094 upstream |
| Browser launch fail E096 | Retry 3 lan, SKIP neu fail | none | E096 |
| Homepage navigate timeout (>15s) | Emit MEDIUM signal "page_load_timeout", SKIP traversal | `runtime_network_failure` | — |
| pw_console unavailable | Fallback: skip console monitoring, note "console_poll_unavailable" | none (degrade) | — |
| pw_network unavailable | Fallback: skip network monitoring, note "network_poll_unavailable" | none (degrade) | — |
| Serena unavailable | Fallback: parse stack trace text trc tiep (file:line pattern) | — (degraded location) | — |
| GitNexus unavailable | Fallback: chi dung link traversal (B2) | WARN log | — |
| SIGNAL_COUNT >= 50 | STOP collecting, emit WARNING `max_signals_reached` (MEDIUM) | `max_signals_reached` | — |
| Auth wall (all routes 401/403) | Note "auth_required_skipped", emit MEDIUM per 4xx | `runtime_network_failure` MEDIUM | — |
| Redirect loop | Detect (URL pops lien tuc trong VISITED), skip route | WARN log | — |
| External link (cross-origin) | Skip — chi crawl same-origin | none | — |

---

## Cache Policy

**skip** — always runtime. Console errors va network failures thay doi theo code. Khong cache.

---

## Output

| File | Required | Content |
|------|----------|---------|
| `$RAW_DIR/P-QD9-console-network-monitor.jsonl` | yes (khi co signals) | JSONL signals (signal-v2) per error |
| `$RAW_DIR/P-QD9-console-network-monitor-summary.json` | yes | Routes visited, signal counts, CI tool usage |
| `$LANE_DIR/evidence/P-QD9-cnm-homepage.png` | yes | Homepage screenshot |
| `$LANE_DIR/evidence/P-QD9-cnm-uncaught-*.png` | khi co CRITICAL | Per-CRITICAL screenshot |

**Cross-probe coordination:**
- Signals duoc aggregator merge vao `$SIGNALS_FILE` (lane-signals-v1 format)
- `runtime_network_failure` signals tu probe nay cung cap context cho `P-QD9-auth-aware-smoke`: neu 401/403 bat gap tren route → ghi route vao `auth_protected_routes[]` trong summary json, P-QD9-auth-aware-smoke doc de biet can login truoc
- QD5 `P-QD5-ui-traversal-deep` co the emit cung console errors → cross-lane aggregator dedup qua fingerprint

---

## Profile-Resolver Entry

```
P-QD9-console-network-monitor:
  quick: skip
  standard: run (max_routes=20)
  deep: run (max_routes=50)
  exhaustive: run (max_routes=100)
  parallel_class: runtime
  depends_on: P-QD9-dev-server-bootstrap
```

---

## Acceptance Test (W1.5 DoD)

**Synthetic test:** Inject page co `console.error('QD9-test-error')` → probe phat sinh 1 signal `runtime_console_error` MEDIUM voi `title` chua "QD9-test-error".

**EUREKA acceptance:**
```bash
# Chay probe voi EUREKA erp-web
bash .claude/scripts/wf-fix-probe-dev-server.sh --base-url=http://localhost:3000 --project-root=D:/Working/EUREKA-2026
# Sau do chay probe console-network-monitor theo QD9 lane procedure
# Expect: RAW_DIR/P-QD9-console-network-monitor-summary.json co routes_visited >= 1
# Expect: neu app co console errors → signals.jsonl co entries; neu 0 errors → summary co console_errors:0
```
