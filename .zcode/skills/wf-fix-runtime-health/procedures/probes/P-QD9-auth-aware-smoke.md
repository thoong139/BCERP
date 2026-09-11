# P-QD9-auth-aware-smoke — Auth-Aware Smoke Test

> **Type:** runtime (Playwright bash-level) | **Profile:** standard, deep, exhaustive | **Cache:** skip (always runtime)
> **Parallel class:** runtime → sequential (browser session; chay sau P-QD9-console-network-monitor)
> **Signal types:** `auth_login_failed` (HIGH), `runtime_console_error` (MEDIUM), `runtime_network_failure` (HIGH/MEDIUM), `runtime_uncaught_exception` (CRITICAL)
> **Error code:** E097 (auth_login_failed)

Thuc hien dang nhap vao ung dung bang credentials cung cap, capture session state, va re-traverse cac route protected de phat hien loi xay ra khi co auth context. CI-ROUTE: Serena `find_symbol("login", "auth", "signin")` PRIMARY de locate login form component.

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| `fill_value_for_input` locale-aware pattern | `QD1 P-QD1-deep-ui-traversal.md` | `:153-184` | IMP-009 — load locale patterns, fallback generic fill theo type |
| Form field detection + fill loop | `QD1 P-QD1-deep-ui-traversal.md` | `:186-216` | pw_snapshot → lay form fields → pw_type/fill/select → submit |
| Navigation traversal (B1-B3) | `QD9 P-QD9-console-network-monitor.md` | `:64-105` | Sau auth, reuse B1 (navigate homepage), B2 (build queue), B3 (GitNexus augment) de traverse protected routes |
| Browser launch + close | `procedures/probes/_shared.md` | `:26-44` | `pw_launch` / `pw_close` + trap EXIT |
| `emit_signal_browser` pattern | `procedures/probes/_shared.md` | `:51-86` | signal-v2 schema, atomic append toi RAW_DIR/probe_id.jsonl |
| `emit_signal_no_location` pattern | `procedures/probes/_shared.md` | `:88-106` | Cho auth_login_failed (khong co URL location) |
| Common variables + `AUTH_SESSION` | `procedures/probes/_shared.md` | `:7-18` | `LANE_DIR, RAW_DIR, SESSION_FILE, AUTH_SESSION, DEV_SERVER_STATE` |
| Output truncation | `procedures/probes/_shared.md` | `:171-179` | Console msg max 500 chars, stack max 20 frames |
| Console/network polling pattern | `QD9 P-QD9-console-network-monitor.md` | `:186-305` | pw_console + pw_network + pw_evaluate sau moi navigate |
| Pageerror injection pattern | `QD9 P-QD9-console-network-monitor.md` | `:161-180` | `window.__QD9_UNCAUGHT__` inject + `window.addEventListener('error')` + unhandledrejection |

**Diff so voi P-QD9-console-network-monitor:**
- Probe nay them buoc dang nhap truoc khi traverse.
- Focus vao protected routes (401/403 auth wall) thay vi all routes tu homepage.
- `AUTH_SESSION` capture → ghi ra file cho QD10 reuse.
- Credential hai dang: `email:password` (fill form) va `cookie:NAME=VALUE` (bypass form — inject cookie).
- Fallback 2-lan: neu login fail 2 lan lien tiep → emit E097 + skip traversal.

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Locate login form component | **Serena** `find_symbol({name_path_pattern: "login\|auth\|signin", relative_path: null, include_body: false})` | Grep `/login\|/auth\|/signin` trong source | Xac dinh file login form component de hieu cau truc fields (email, password selectors) |
| Xac dinh login URL tu router config | **Serena** `find_symbol({name_path_pattern: "Route\|routes\|createBrowserRouter", relative_path: null})` | Grep `href.*login\|path.*login` | Tim route path cho login page |
| Map login failure → source (neu stack) | **Serena** `find_symbol({relative_path: "<file-tu-stack>"})` | Parse file:line truc tiep | Populate location trong signal auth_login_failed |
| Augment protected route list | **GitNexus** `query("protected, auth, middleware, guard")` | Doc `auth_protected_routes[]` tu console-monitor summary | Tim them routes can auth ma khong visible tu homepage links |

**Khi CI unavailable:** Set `$GITNEXUS_AVAILABLE` / `$SERENA_AVAILABLE` tu `ci-detect.sh` output. Log warning, fallback Grep. Khong block probe.

---

## PRE-GATE

```
1. IF profile=quick: SKIP probe, note "QD9-quick-no-browser"
2. IF --no-browser: SKIP probe (da SKIP toan lane E093 — probe nay khong duoc goi)
3. IF DEV_SERVER_STATE khong ton tai HOAC DEV_SERVER_STATE.status == "fail":
     SKIP probe, note "skipped_dev_server_not_ready (E095 upstream)"
4. Read BASE_URL tu DEV_SERVER_STATE.url
5. IF BASE_URL == null hoac "": SKIP probe, note "skipped_no_base_url"
6. IF --credentials khong set AND --cookie khong set:
     LOG "WARN: P-QD9-auth-aware-smoke skip (no credentials provided). Re-run voi --credentials=email:pass hoac --cookie=NAME=VALUE" >&2
     Write LANE_DIR/raw/P-QD9-auth-aware-smoke-skip.json: {reason: "no_credentials", skipped: true}
     SKIP probe (khong emit signal — credentials la optional config)
7. Parse credentials:
   IF --credentials bat dau bang "cookie:":
     CRED_TYPE = "cookie"
     COOKIE_HEADER = --credentials sau "cookie:" prefix
     — Format: NAME=VALUE (single) hoac NAME=VALUE;NAME2=VALUE2 (multiple)
   ELSE:
     CRED_TYPE = "form"
     CRED_EMAIL = phan truoc ":" dau tien trong --credentials
     CRED_PASSWORD = phan con lai (sau ":" dau tien)
     IF CRED_EMAIL == "" HOAC CRED_PASSWORD == "": SKIP probe, note "skipped_invalid_credentials_format"
8. pw_launch — tra ve E096 neu fail sau 30s
9. trap "pw_close" EXIT
```

---

## SENSE

### S1 — Auto-detect login URL

```
LOGIN_URL = null

1. IF --login-url set:
   LOGIN_URL = --login-url
   LOG "INFO: Login URL tu --login-url: $LOGIN_URL" >&2

ELSE:
   # Thu cac candidates pho bien
   LOGIN_CANDIDATES = [
     "$BASE_URL/login",
     "$BASE_URL/auth/login",
     "$BASE_URL/signin",
     "$BASE_URL/auth/signin",
     "$BASE_URL/dang-nhap",
     "$BASE_URL/user/login"
   ]

   FOR moi candidate trong LOGIN_CANDIDATES:
     pw_navigate "candidate
     pw_wait "1500"
     snap = pw_snapshot
     # Kiem tra co form login khong (input[type=password])
     IF snap contains 'input[type="password"]' HOAC snap contains "input[name*=password]":
       LOGIN_URL = candidate
       LOG "INFO: Auto-detected login URL: $LOGIN_URL" >&2
       BREAK

2. IF $SERENA_AVAILABLE == "true" AND LOGIN_URL == null:
   # CI-ROUTE: Serena tim login component → suy ra URL
   serena_results = serena_find_symbol({name_path_pattern: "login|auth|signin", relative_path: null, include_body: false})
   FOR moi sym trong serena_results:
     IF sym.name matches /[Ll]ogin[Pp]age|[Ll]ogin[Cc]omponent|[Aa]uth[Pp]age/:
       # Suy ra URL tu file path (Next.js pages/ convention)
       IF sym.file_path matches /pages\/login|pages\/auth\/login|pages\/signin/:
         LOGIN_URL = parse_url_from_pages_path(sym.file_path, BASE_URL)
         LOG "INFO: Login URL tu Serena: $LOGIN_URL" >&2
         BREAK

3. IF LOGIN_URL == null:
   LOG "WARN: Khong the auto-detect login URL. Thu BASE_URL truc tiep." >&2
   # Thu navigate BASE_URL — co the redirect ve login
   pw_navigate "$BASE_URL/"
   pw_wait "2000"
   current_url = pw_tabs[0].url
   snap = pw_snapshot
   IF snap contains 'input[type="password"]':
     LOGIN_URL = current_url
     LOG "INFO: BASE_URL redirect toi login: $LOGIN_URL" >&2
   ELSE:
     emit_signal_no_location(
       probe_id = "P-QD9-auth-aware-smoke"
       severity = "MEDIUM"
       title = "Khong the xac dinh login URL"
       description = "Auto-detect login URL that bai. Thu cac candidates: " + LOGIN_CANDIDATES.join(", ") + ". Cung cap --login-url=<url> de chi dinh."
       cdg_flags = "[]"
     )
     SKIP probe (traverse khong co auth → probe nay khong co gia tri)
```

### S2 — Doc `auth_protected_routes[]` tu console-monitor output (neu co)

```
PROTECTED_ROUTES = []
CNM_SUMMARY = "$LANE_DIR/raw/P-QD9-console-network-monitor-summary.json"

IF file ton tai(CNM_SUMMARY):
  cnm = parse JSON(CNM_SUMMARY)
  IF cnm.auth_protected_routes:
    PROTECTED_ROUTES = cnm.auth_protected_routes
    LOG "INFO: Doc duoc $N protected routes tu console-monitor summary" >&2
```

---

## THINK

### Xac dinh auth strategy

```
IF CRED_TYPE == "cookie":
  AUTH_STRATEGY = "cookie_inject"
  — Set cookie truc tiep, bypass form login
  — Nhanh hon, khong can interact voi UI login form
ELSE:
  AUTH_STRATEGY = "form_login"
  — Fill form + submit + verify redirect
  — Phat hien duoc form login issues
```

### Xac dinh protected route list

```
POST_AUTH_ROUTES = []

# Uu tien routes da biet la protected (tu console-monitor 401/403)
FOR route trong PROTECTED_ROUTES:
  POST_AUTH_ROUTES.append(route)

# Them cac routes pho bien can auth
COMMON_AUTH_ROUTES = ["/dashboard", "/admin", "/settings", "/profile", "/app"]
FOR r trong COMMON_AUTH_ROUTES:
  IF BASE_URL + r khong trong POST_AUTH_ROUTES:
    POST_AUTH_ROUTES.append(BASE_URL + r)

# Augment tu GitNexus (neu available)
IF $GITNEXUS_AVAILABLE == "true":
  gi_results = gitnexus_query("protected, auth, middleware, guard")
  FOR route trong gi_results.results:
    IF route.path bat dau bang "/" AND route.path khong trong POST_AUTH_ROUTES:
      POST_AUTH_ROUTES.append(route.path)

MAX_PROTECTED_ROUTES = 10  — standard
MAX_PROTECTED_ROUTES = 25  — deep
MAX_PROTECTED_ROUTES = 50  — exhaustive
POST_AUTH_ROUTES = POST_AUTH_ROUTES[0..MAX_PROTECTED_ROUTES]
```

---

## ACT

### A1 — Auth: Cookie inject (neu CRED_TYPE == "cookie")

```
1. pw_navigate "$BASE_URL/"
   pw_wait "1000"

2. # Parse cookie string: NAME=VALUE[;NAME2=VALUE2...]
   FOR moi cookie_pair trong COOKIE_HEADER.split(";"):
     [name, value] = cookie_pair.strip().split("=", 1)
     pw_evaluate "
       document.cookie = "${name}=${value}; path=/; SameSite=Lax";
     """)

3. pw_navigate "$BASE_URL/"
   pw_wait "2000"

4. # Verify: thu navigate toi 1 protected route, expect khong bi redirect ve login
   test_route = POST_AUTH_ROUTES[0] if POST_AUTH_ROUTES else "$BASE_URL/dashboard"
   pw_navigate "test_route
   pw_wait "2000"
   final_url = pw_tabs[0].url
   snap = pw_snapshot

   IF snap contains 'input[type="password"]' HOAC final_url contains "/login" HOAC final_url contains "/signin":
     LOGIN_SUCCESS = false
     LOG "WARN: Cookie inject: navigate toi $test_route van redirect ve login" >&2
   ELSE:
     LOGIN_SUCCESS = true
     LOG "INFO: Cookie inject thanh cong — khong bi redirect" >&2

5. IF NOT LOGIN_SUCCESS:
   # Retry lan 2 (co the cookie expire, thu lai)
   pw_evaluate("document.cookie=''; localStorage.clear(); sessionStorage.clear();")
   pw_navigate "$BASE_URL/"
   pw_wait "1000"
   FOR moi cookie_pair trong COOKIE_HEADER.split(";"):
     [name, value] = cookie_pair.strip().split("=", 1)
     pw_evaluate "
       document.cookie = "${name}=${value}; path=/; SameSite=Lax";
     """)
   pw_navigate "test_route
   pw_wait "2000"
   final_url_2 = pw_tabs[0].url
   snap_2 = pw_snapshot
   IF snap_2 contains 'input[type="password"]' HOAC final_url_2 contains "/login":
     LOG "ERROR: Cookie inject fail 2 lan. Emit E097." >&2
     GOTO AUTH_FAIL_HANDLER
   ELSE:
     LOGIN_SUCCESS = true
```

### A2 — Auth: Form login (neu CRED_TYPE == "form")

```
LOGIN_ATTEMPT = 0
LOGIN_SUCCESS = false

WHILE LOGIN_ATTEMPT < 2 AND NOT LOGIN_SUCCESS:
  LOGIN_ATTEMPT++
  LOG "INFO: Login attempt #$LOGIN_ATTEMPT..." >&2

  1. pw_navigate "$LOGIN_URL"
     pw_wait "2000"
     snap = pw_snapshot

  2. # Lay danh sach input fields trong form
     # Tim input[type=email], input[name*=email], input[name*=user], input[placeholder*=mail]
     email_field = snap.query('input[type="email"], input[name*="email"], input[name*="user"], input[name*="username"]')[0]
     password_field = snap.query('input[type="password"]')[0]

     IF email_field == null HOAC password_field == null:
       LOG "WARN: Khong tim thay email/password fields (attempt $LOGIN_ATTEMPT)" >&2
       # Serena fallback: tim login form component de hieu structure
       IF $SERENA_AVAILABLE == "true":
         serena_find_symbol({name_path_pattern: "login|Login|signin|SignIn", include_body: true})
         LOG "INFO: Serena found login symbol — dung snapshot selector truc tiep" >&2
       # Thu generic fill
       email_field = snap.query('input[type="text"]')[0]  -- fallback
       IF email_field == null HOAC password_field == null:
         CONTINUE  -- lan sau

  3. # Fill credentials (REUSE QD1 A3-locale fill_value_for_input — IMP-009)
     # Cho login form: override locale lookup bang credentials thuc
     pw_type "email_field.ref, text=CRED_EMAIL
     pw_type "password_field.ref, text=CRED_PASSWORD

  4. # Submit form
     submit_btn = snap.query('button[type="submit"], input[type="submit"], button:contains("Login"), button:contains("Sign in"), button:contains("Dang nhap")')[0]
     IF submit_btn:
       pw_click "submit_btn.ref
     ELSE:
       pw_press_key "Enter"
     pw_wait "5000"  -- wait 5s per spec

  5. # Verify redirect hoac cookie set
     post_login_url = pw_tabs[0].url
     post_snap = pw_snapshot

     # Success conditions:
     URL_CHANGED = (post_login_url != "$LOGIN_URL" AND post_login_url not contains "/login" AND post_login_url not contains "/signin")
     HAS_ERROR_MSG = (post_snap contains "Invalid" HOAC contains "sai mat khau" HOAC contains "incorrect" HOAC contains "Unauthorized")
     STILL_ON_LOGIN = (post_snap contains 'input[type="password"]')

     IF URL_CHANGED AND NOT HAS_ERROR_MSG AND NOT STILL_ON_LOGIN:
       LOGIN_SUCCESS = true
       LOG "INFO: Login thanh cong — redirect toi: $post_login_url" >&2
     ELSE:
       LOG "WARN: Login attempt $LOGIN_ATTEMPT fail (URL: $post_login_url, error_msg: $HAS_ERROR_MSG)" >&2
       # Clear va thu lai
       pw_evaluate("localStorage.clear(); sessionStorage.clear();")
```

### A3 — Auth fail handler

```
AUTH_FAIL_HANDLER:
IF NOT LOGIN_SUCCESS:
  pw_screenshot "$LANE_DIR/evidence/P-QD9-auth-fail.png"
  emit_signal_no_location(
    probe_id = "P-QD9-auth-aware-smoke"
    severity = "HIGH"
    title = "Auth login that bai sau 2 lan thu (E097)"
    description = ("Login that bai 2 lan lien tiep voi credentials cung cap. " +
                   "Auth strategy: $AUTH_STRATEGY. Login URL: $LOGIN_URL. " +
                   "Kiem tra credentials hoac neu dung form, kiem tra UI login form co hoat dong khong.")
    cdg_flags = "[]"
  )
  # Emit voi error code E097 trong evidence
  APPEND to RAW_DIR/P-QD9-auth-aware-smoke.jsonl:
    {... signal..., evidence: [{type: "log_excerpt", content: "E097: auth_login_failed — 2 attempts exhausted. Strategy: $AUTH_STRATEGY"}]}
  SKIP remaining (return early — khong traverse)
```

### A4 — Capture auth session state

```
IF LOGIN_SUCCESS:
  # Lay cookies hien tai tu browser
  cookies_json = pw_evaluate("""
    return document.cookie;
  """)

  # Lay localStorage tokens (JWT, access_token, etc.)
  local_storage_json = pw_evaluate("""
    var data = {};
    for (var i = 0; i < localStorage.length; i++) {
      var k = localStorage.key(i);
      if (k && (k.includes('token') || k.includes('auth') || k.includes('session') || k.includes('user'))) {
        data[k] = localStorage.getItem(k);
      }
    }
    return data;
  """)

  # Ghi auth-session.json (REUSE _shared.md AUTH_SESSION variable :17)
  atomic_write_json(
    path = "$AUTH_SESSION",
    content = {
      "captured_at": now_iso(),
      "strategy": AUTH_STRATEGY,
      "base_url": BASE_URL,
      "login_url": LOGIN_URL,
      "cookies": cookies_json,
      "local_storage": local_storage_json
    }
  )
  LOG "INFO: Auth session captured → $AUTH_SESSION" >&2
```

### A5 — Traverse protected routes sau auth

```
VISITED = Set()
SIGNAL_COUNT = 0
ROUTE_QUEUE = POST_AUTH_ROUTES[0..MAX_PROTECTED_ROUTES]

# Them homepage (de collect errors sau auth)
IF BASE_URL + "/" khong trong ROUTE_QUEUE:
  ROUTE_QUEUE.prepend(BASE_URL + "/")

WHILE ROUTE_QUEUE khong rong AND |VISITED| < MAX_PROTECTED_ROUTES:
  page_url = ROUTE_QUEUE.shift()
  IF page_url trong VISITED: continue
  VISITED.add(page_url)

  LOG "INFO: Auth-traverse: $page_url" >&2

  # A5.1 — Navigate
  pw_navigate "page_url
  pw_wait "2000"

  # A5.2 — Kiem tra redirect ve login (auth session expired?)
  current_url = pw_tabs[0].url
  snap = pw_snapshot
  IF snap contains 'input[type="password"]' HOAC current_url contains "/login":
    emit_signal_browser(
      probe_id = "P-QD9-auth-aware-smoke"
      signal_type = "runtime_network_failure"
      severity = "HIGH"
      title = "Route $page_url yeu cau re-auth (session mat?)"
      description = "Navigate toi $page_url sau khi login thanh cong bi redirect ve login page. Session co the mat hoac cookie khong duoc giuu."
      page_url = page_url
      evidence_type = "log_excerpt"
      evidence_content = "Redirect toi login: $current_url"
      screenshot_path = null
    )
    SIGNAL_COUNT++
    continue

  # A5.3 — Inject pageerror tracking (REUSE console-monitor :161-180)
  pw_evaluate "
    if (!window.__QD9_UNCAUGHT__) {
      window.__QD9_UNCAUGHT__ = [];
      window.addEventListener('error', function(e) {
        window.__QD9_UNCAUGHT__.push({
          type: 'uncaught_exception',
          message: (e.message || '').substring(0, 500),
          filename: e.filename || '',
          lineno: e.lineno || 0,
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
  pw_wait "1000"

  # A5.4 — Poll console messages (REUSE console-monitor :186-222)
  console_msgs = pw_console
  FOR moi msg trong console_msgs:
    IF msg.type == "error":
      text = msg.text[0:500]
      emit_signal_browser(
        probe_id = "P-QD9-auth-aware-smoke"
        signal_type = "runtime_console_error"
        severity = "MEDIUM"
        title = "Console error tai " + page_url + " (post-auth): " + text[0:80]
        description = "JavaScript console.error() sau auth tai " + page_url + ". Message: " + text
        page_url = page_url
        evidence_type = "log_excerpt"
        evidence_content = text
        screenshot_path = null
      )
      SIGNAL_COUNT++

  # A5.5 — Poll uncaught exceptions (REUSE console-monitor :224-261)
  uncaught_list = pw_evaluate "return (window.__QD9_UNCAUGHT__ || [].splice(0)")
  FOR moi err trong uncaught_list:
    msg_text = err.message[0:500]
    stack_text = err.stack[0:2000] if err.stack else ""
    shot_path = "$LANE_DIR/evidence/P-QD9-auth-uncaught-{hash(page_url+msg_text)[:8]}.png"
    pw_screenshot "shot_path
    emit_signal_browser(
      probe_id = "P-QD9-auth-aware-smoke"
      signal_type = "runtime_uncaught_exception"
      severity = "CRITICAL"
      title = "Uncaught exception tai " + page_url + " (post-auth): " + msg_text[0:80]
      description = ("Post-auth " + err.type + " tai " + page_url + ". Message: " + msg_text +
                     (". Stack: " + stack_text[0:500] if stack_text else ""))
      page_url = page_url
      evidence_type = "log_excerpt"
      evidence_content = msg_text + ("|stack:" + stack_text[0:500] if stack_text else "")
      screenshot_path = shot_path
    )
    SIGNAL_COUNT++

  # A5.6 — Poll network requests (REUSE console-monitor :263-297)
  net_reqs = pw_network
  FOR moi req trong net_reqs:
    status = req.status
    IF status < 400: continue
    IF status == 401 OR status == 403:
      # Sau auth: 401/403 → HIGH (khac voi console-monitor MEDIUM — vi da login roi)
      sev = "HIGH"
      desc_extra = " Post-auth 401/403 — API endpoint khong chap nhan session token."
    ELIF status >= 500:
      sev = "HIGH"
      desc_extra = " Server error."
    ELSE:
      sev = "MEDIUM"
      desc_extra = ""
    url_req = req.url[0:200]
    emit_signal_browser(
      probe_id = "P-QD9-auth-aware-smoke"
      signal_type = "runtime_network_failure"
      severity = sev
      title = (req.method + " " + url_req + " returned HTTP " + str(status) + " tai " + page_url + " (post-auth)")
      description = ("Post-auth request " + req.method + " " + url_req +
                     " returned HTTP " + str(status) +
                     " tren page " + page_url + "." + desc_extra)
      page_url = page_url
      evidence_type = "network_trace"
      evidence_content = req.method + " " + url_req + " → HTTP " + str(status)
      screenshot_path = null
    )
    SIGNAL_COUNT++

  IF SIGNAL_COUNT >= 50: BREAK
```

### A6 — Cleanup

```
pw_close()
LOG "INFO: P-QD9-auth-aware-smoke DONE. Routes visited: |VISITED|, Signals: SIGNAL_COUNT" >&2
```

---

## VERIFY

1. Neu `LOGIN_SUCCESS = true`: `$AUTH_SESSION` file ton tai voi `strategy` va `base_url` fields
2. Neu `LOGIN_SUCCESS = false`: co signal `auth_login_failed` voi severity="HIGH" va E097 trong evidence
3. Moi signal co `dimension_id == "QD9"` va `probe_id == "P-QD9-auth-aware-smoke"`
4. Post-auth 401/403 → severity="HIGH" (KHAC console-monitor MEDIUM)
5. `runtime_uncaught_exception` → severity="CRITICAL" + screenshot
6. Moi signal co `evidence[]` non-empty voi `content` >= 10 chars
7. Tong signals per probe <= 50 (hoac WARNING "max_signals_reached")
8. Ghi summary JSON:

```json
{
  "probe_id": "P-QD9-auth-aware-smoke",
  "auth_strategy": "form_login|cookie_inject",
  "login_success": true,
  "routes_traversed": N,
  "routes_max": MAX_PROTECTED_ROUTES,
  "console_errors": C,
  "uncaught_exceptions": U,
  "network_failures": F,
  "signals_emitted": S,
  "auth_session_captured": true,
  "gitnexus_used": true,
  "serena_used": true
}
```

---

## Severity Rules

| Signal Type | Dieu kien | Severity | Ly do |
|-------------|-----------|----------|-------|
| `auth_login_failed` | 2 lan thu that bai | **HIGH** | Auth broken = moi protected feature khong test duoc (E097) |
| `runtime_uncaught_exception` | pageerror post-auth | **CRITICAL** | App crash sau auth — nghiem trong nhat |
| `runtime_network_failure` | HTTP 401/403 post-auth | **HIGH** | Sau login ma van 401/403 = session/token bug |
| `runtime_network_failure` | HTTP 5xx post-auth | **HIGH** | Server error sau auth |
| `runtime_network_failure` | HTTP 4xx non-auth post-auth | **MEDIUM** | Client error |
| `runtime_console_error` | console.error() post-auth | **MEDIUM** | JS error sau auth |

> **Luu y:** Post-auth 401/403 la HIGH (khac voi console-monitor MEDIUM). Ly do: khi da login thanh cong ma API van tra 401/403, do la session/token bug nghiem trong — khong phai auth wall binh thuong (P1 Correctness).

---

## Dedup Hints

```json
{
  "dedup_key": "sha256(probe_id + \"|\" + signal_type + \"|\" + page_url + \"|\" + message[0:100])",
  "merge_scope": "session",
  "notes": "Post-auth signals cung URL + cung message → ghi first occurrence. Cross-probe voi console-monitor: neu cung URL + cung error → giuu QD9-auth signal vi co auth context (chi tiet hon). auth_login_failed khong dedup — unique per attempt."
}
```

---

## Signal Schema Examples

**auth_login_failed (E097):**
```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-auth-aware-smoke",
  "dimension_id": "QD9",
  "signal_type": "auth_login_failed",
  "severity": "HIGH",
  "title": "Auth login that bai sau 2 lan thu (E097)",
  "description": "Login that bai 2 lan lien tiep voi credentials cung cap. Auth strategy: form_login. Login URL: http://localhost:3000/login. Kiem tra credentials hoac form login co hoat dong khong.",
  "location": {},
  "evidence": [
    {"type": "log_excerpt", "content": "E097: auth_login_failed — 2 attempts exhausted. Strategy: form_login"}
  ],
  "screenshot": "$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/evidence/P-QD9-auth-fail.png",
  "cdg_flags": [],
  "fixability": "agent_fix"
}
```

**runtime_network_failure (post-auth 401):**
```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-auth-aware-smoke",
  "dimension_id": "QD9",
  "signal_type": "runtime_network_failure",
  "severity": "HIGH",
  "title": "GET /api/customers returned HTTP 401 tai /dashboard/crm (post-auth)",
  "description": "Post-auth request GET /api/customers returned HTTP 401 tren page http://localhost:3000/dashboard/crm. Post-auth 401/403 — API endpoint khong chap nhan session token.",
  "location": {
    "url": "http://localhost:3000/dashboard/crm"
  },
  "evidence": [
    {"type": "network_trace", "content": "GET /api/customers → HTTP 401"}
  ],
  "screenshot": null,
  "cdg_flags": [],
  "fixability": "agent_fix"
}
```

**runtime_uncaught_exception (post-auth):**
```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-auth-aware-smoke",
  "dimension_id": "QD9",
  "signal_type": "runtime_uncaught_exception",
  "severity": "CRITICAL",
  "title": "Uncaught exception tai /dashboard (post-auth): TypeError: user.profile is undefined",
  "description": "Post-auth uncaught_exception tai http://localhost:3000/dashboard. Message: TypeError: user.profile is undefined. Stack: TypeError: user.profile is undefined\\n    at Dashboard.render (dashboard.tsx:88:15)...",
  "location": {
    "url": "http://localhost:3000/dashboard"
  },
  "evidence": [
    {"type": "log_excerpt", "content": "TypeError: user.profile is undefined|stack:TypeError: user.profile is undefined\\n    at Dashboard.render (dashboard.tsx:88:15)"}
  ],
  "screenshot": "$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/evidence/P-QD9-auth-uncaught-a1b2c3d4.png",
  "cdg_flags": [],
  "fixability": "agent_fix"
}
```

---

## Fallback Table

| Failure Mode | Hanh vi | Signal | Code |
|--------------|---------|--------|------|
| `--credentials` khong set | SKIP probe, log WARN (optional config) | none | — |
| Credentials format sai (khong co ":") | SKIP probe, log error | none | — |
| DEV_SERVER_STATE.status = "fail" | SKIP probe, note "skipped_dev_server_not_ready" | none | E095 upstream |
| BASE_URL null | SKIP probe | none | E094 upstream |
| Browser launch fail E096 | Retry 3 lan, SKIP neu fail | none | E096 |
| Login URL auto-detect fail | Emit MEDIUM "login_url_detect_fail", SKIP traversal | `runtime_network_failure` MEDIUM | — |
| Login form fields khong tim thay | Retry lan 2 generic selectors; neu fail 2x → AUTH_FAIL_HANDLER | `auth_login_failed` HIGH | E097 |
| Login fail 2 lan | Emit E097, skip traversal | `auth_login_failed` HIGH | E097 |
| Cookie inject khong duoc chap nhan | Retry; neu fail 2x → AUTH_FAIL_HANDLER | `auth_login_failed` HIGH | E097 |
| Session expired mid-traversal (401/403 redirect) | Emit HIGH per route, ghi log | `runtime_network_failure` HIGH | — |
| Serena unavailable | Fallback Grep cho login form locate | — (degraded) | — |
| GitNexus unavailable | Chi dung PROTECTED_ROUTES tu console-monitor + common list | WARN log | — |
| SIGNAL_COUNT >= 50 | STOP collecting, emit WARNING | `max_signals_reached` MEDIUM | — |
| auth-session.json ghi fail | Log ERROR; tiep tuc traverse (session van active trong browser) | WARN log | — |
| Redirect loop post-auth | Detect (URL pops lien tuc), skip route, log | WARN log | — |

---

## Cache Policy

**skip** — always runtime. Auth session va post-auth errors thay doi theo credentials va code. Khong cache.

---

## Output

| File | Required | Content |
|------|----------|---------|
| `$RAW_DIR/P-QD9-auth-aware-smoke.jsonl` | khi co signals | JSONL signals (signal-v2) per error |
| `$RAW_DIR/P-QD9-auth-aware-smoke-summary.json` | yes | Auth strategy, login success, routes traversed, signal counts |
| `$AUTH_SESSION` (`$LANE_DIR/auth-session.json`) | khi login thanh cong | Auth session (cookies + localStorage tokens) |
| `$LANE_DIR/evidence/P-QD9-auth-fail.png` | khi login fail | Screenshot trang login luc fail |
| `$LANE_DIR/evidence/P-QD9-auth-uncaught-*.png` | khi co CRITICAL | Per-CRITICAL screenshot post-auth |

**Cross-probe coordination:**
- `$AUTH_SESSION` duoc QD10 `P-QD10-multi-platform-entity-sync` doc de call API voi session token.
- `P-QD9-feature-checklist-smoke` (deep+) se reuse browser session nay de traverse feature routes sau auth.
- Signals tu probe nay duoc aggregator merge vao `$SIGNALS_FILE`.

---

## Profile-Resolver Entry

```
P-QD9-auth-aware-smoke:
  quick: skip
  standard: run (max_protected_routes=10)
  deep: run (max_protected_routes=25)
  exhaustive: run (max_protected_routes=50)
  parallel_class: runtime
  depends_on: P-QD9-console-network-monitor
  optional: true  # skip neu --credentials khong set (khong block lane)
```

---

## Acceptance Test (W1.6 DoD)

**Synthetic test:**
1. Start EUREKA `erp-web` dev server
2. Run probe voi `--credentials=test@erktransport.com:Test123!`
3. Expect: `auth-session.json` duoc tao
4. Expect: traverse duoc `/dashboard` sau login (khong bi redirect lai `/login`)
5. Neu app co console errors post-auth → signals emitted
6. Neu zero errors post-auth → summary co `signals_emitted: 0`

**EUREKA acceptance (W1.6 spec):**
```bash
# Probe yeu cau --credentials wire qua orchestrator
# Khi chay qua wf-fix-bugs:
/wf-fix-bugs --lane=QD9 --scope=module --name=MOD-CRM \
  --url=http://localhost:3000 \
  --credentials="test@erktransport.com:Test123!"
# Expect: fix-report.md co "Auth flows tested: [login → /dashboard]"
# Expect: auth-session.json ton tai trong SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/
# Expect: neu co post-auth API 401 → signal HIGH duoc emit
```
