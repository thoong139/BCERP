# P-QD1-deep-ui-traversal — Deep UI Traversal + Interaction Smoke

> **Type:** runtime (Playwright bash-level, session-isolated) | **Profile:** standard, deep, exhaustive | **Cache:** skip (always runtime)
> **Signal types:** `ui_cta_no_response`, `ui_page_error`, `ui_form_submit_fail`, `missing_nav_link`, `extra_nav_link`
> **Error codes:** E046 (browser unavailable — tu `_shared.md`)

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD1-deep-ui-traversal |
| **Loai** | runtime |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Navigate pages, click CTAs, fill forms smoke test — phat hien UI functional bugs |
| **Cache** | skip (runtime probe) |
| **Migrates from** | (v5 legacy — removed in v6) phase7+8 (pass1+2) |

---

## Reuses from

| Aspect | Source | Notes |
|--------|--------|-------|
| Browser launch + close + pw_* wrappers | `../wf-fix-runtime-health/procedures/probes/_shared.md` | `pw_launch` / `pw_close` + trap EXIT, all bash wrappers (pw_navigate, pw_snapshot, pw_screenshot, pw_evaluate, pw_click, pw_type, pw_select, pw_wait, pw_console, pw_network) |
| Common variables | `../wf-fix-runtime-health/procedures/probes/_shared.md` | `SESSION_DIR`, `SESSION_FILE`, `PW_CMD` pattern — QD1 adapts voi `LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional"` |
| `emit_signal_browser` base pattern | `../wf-fix-runtime-health/procedures/probes/_shared.md` | signal-v2 schema — QD1 uses inline JSON templates instead |

> **QD1 diff:** QD1 probes emit signals inline (JSON templates trong probe file) thay vi goi `emit_signal_browser()` wrapper. Ly do: QD1 signal schema co them fields `dedup_hints`, `suggested_severity`, `confidence` khong co trong QD9 `emit_signal_browser`.
> **Browser tools:** Tat ca `pw_*` wrappers duoc dinh nghia trong QD9 `_shared.md` — QD1 reuse thong qua `playwright-session.js` CLI (`node .claude/skills/workflow/_shared/playwright-session.js --session-dir="$SESSION_DIR"`).

---

## PRE-GATE

```
IF $BASE_URL == null:
  SKIP probe, note "skipped_no_base_url"
  WRITE lane-status.json voi probe status="skipped"
  EMIT 0 signals

IF $INFRA_STATUS.frontend == "unreachable" (tu P-QD1-infra-preflight):
  SKIP probe, note "skipped_frontend_unreachable"
  WRITE lane-status.json voi probe status="skipped"
  EMIT 0 signals

IF $INFRA_STATUS.cors == "blocked":
  SKIP probe, note "skipped_cors_blocked"
  WRITE lane-status.json voi probe status="skipped"
  EMIT 0 signals

-- Browser launch (bash-level, session-isolated):
pw_launch || {
  echo "E046: browser_unavailable" >&2
  SKIP probe, note "skipped_browser_unavailable"
  EMIT 0 signals
  exit 1
}
trap "pw_close" EXIT

-- Init working dirs:
mkdir -p "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw" "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/evidence"
```

## SENSE

### B1: Navigate den app va capture initial state

```
1. NAV_RESULT=$(pw_navigate "$BASE_URL/" "networkidle")
2. pw_wait "2"  — cho page load xong
3. SNAPSHOT_JSON=$(pw_snapshot)
   PAGE_URL=$(echo "$SNAPSHOT_JSON" | jq -r '.url // ""')
4. PAGE_TITLE=$(pw_evaluate "document.title" | jq -r '.result // ""')
5. pw_screenshot "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/evidence/00-homepage.png"
```

Parse `$SNAPSHOT_JSON` de lay (playwright-session.js DOM structural output):
- `$PAGE_TITLE` — page title (tu pw_evaluate)
- `$NAV_LINKS[]` — tat ca navigation links: `echo "$SNAPSHOT_JSON" | jq -r '.links[]? | "\(.href)|\(.text)"'`
- `$BUTTONS[]` — tat ca buttons: `echo "$SNAPSHOT_JSON" | jq -r '.buttons[]? | "\(.text)|\(.id)|\(.name)"'`
- `$FORMS[]` — tat ca forms: `echo "$SNAPSHOT_JSON" | jq -r '.forms[]? | "\(.action)|\(.method)|\(.inputs)"'`

### B2: Build navigation graph tu snapshot

```
NAV_ROUTES=[]
FOR moi link trong $NAV_LINKS[]:
  href = link.href
  text = link.text
  IF href bat dau bang "/" va khong phai "#" va khong phai "_next/":
    NAV_ROUTES.append({href, text, visited: false})
DEDUP NAV_ROUTES theo href
```

### B3: Doc Navigation specs (neu co)

```bash
NAV_SPEC_FILES=$(find .mc-data/docs/phase4-ux -name "Navigation-*.md" 2>/dev/null)
```

Neu co Navigation specs → parse ra `$SPEC_ROUTES[]` voi: `{path, label, parent}`

## THINK

### Xac dinh interactive elements can test

1. **Primary CTAs** — buttons co text match: Submit, Save, Create, Add, Delete, Edit, Update, Confirm, Send, Login, Register
2. **Navigation links** — links trong main navigation (header/sidebar)
3. **Form fields** — inputs trong forms co action handlers
4. **Priority order**: Primary CTAs > Forms > Navigation links

### So sanh voi Navigation spec

1. `$NAV_ROUTES[]` vs `$SPEC_ROUTES[]` → xac dinh:
   - Routes trong spec nhung khong co trong page → `missing_nav_link`
   - Routes trong page nhung khong trong spec → `extra_nav_link`
2. Skip routes trong exclusion list:
   - `/login`, `/auth/*` (auth flow)
   - `/_next/*`, `/api/*` (framework/internal)
   - External links (http:// or https:// khong phai $BASE_URL)

### Confidence mapping

- Primary CTA khong phan hoi: 0.85
- Form submit fail: 0.85
- Navigation link 404: 0.80
- Extra/missing nav link: 0.70

## ACT

### A1: Traverse navigation pages

```
MAX_PAGES=20  — gioi han de tranh infinite traversal
VISITED=new Set()
PAGE_QUEUE=$NAV_ROUTES[]

WHILE PAGE_QUEUE khong rong VA |VISITED| < MAX_PAGES:
  route = PAGE_QUEUE.shift()
  IF route.href trong VISITED → continue
  VISITED.add(route.href)

  1. pw_navigate "$BASE_URL$route.href" "domcontentloaded"
  2. pw_wait "2"
  3. READY_STATE=$(pw_evaluate "document.readyState" | jq -r '.result // ""')
  4. SNAPSHOT_JSON=$(pw_snapshot)

  IF page co error (404, 500, blank):
    EMIT signal (severity theo page type)
    pw_screenshot "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/evidence/page-error-$(echo $route.href | tr '/' '-').png"
    continue

  pw_screenshot "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/evidence/page-$(echo $route.href | tr '/' '-').png"

  — Moi page moi: lay them nav links tu SNAPSHOT_JSON.links[], append vao PAGE_QUEUE
  — WRITE page catalog vao $SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/catalog-$(echo $route.href | tr '/' '-').json
```

### A2: Test primary CTAs

```
FOR moi page da traverse:
  1. pw_navigate "$page.url" "domcontentloaded"
  2. SNAPSHOT_JSON=$(pw_snapshot)
     BUTTONS=$(echo "$SNAPSHOT_JSON" | jq -r '.buttons[]? | "\(.text)|\(.id)"')

  FOR moi primary CTA button (match text pattern):
    button_text = button.text
    1. CLICK_RESULT=$(pw_click "button:has-text('$button_text')")
    2. pw_wait "2"
    3. AFTER_SNAPSHOT=$(pw_snapshot)
       AFTER_URL=$(echo "$AFTER_SNAPSHOT" | jq -r '.url // ""')
       AFTER_BUTTONS=$(echo "$AFTER_SNAPSHOT" | jq -r '.buttons[]?.text // ""')

    — Check response:
    a) Page URL thay doi? → navigate thanh cong
    b) Modal/dialog xuat hien? → UI interaction OK
    c) Success/error message xuat hien? → feedback OK
    d) KHONG co thay doi gi? → potential bug

    IF khong co thay doi:
      EMIT Signal (HIGH — UI primary CTA khong phan hoi)
      pw_screenshot "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/evidence/cta-no-response-$button_text.png"

    IF error message xuat hien:
      EMIT Signal (severity theo error type)
      pw_screenshot "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/evidence/cta-error-$button_text.png"
```

### A3-locale: Locale-aware pattern fill (IMP-009)

Truoc khi fill form fields, load locale fill patterns neu co:

```
LOCALE = registry.locale // "en"

IF LOCALE != "en":
  LOCALE_PATTERNS_FILE = "_shared/locales/{LOCALE}/form-fill-patterns.json"
  IF file ton tai:
    FILL_PATTERNS = parse JSON .form_fill_patterns[]
  ELSE:
    FILL_PATTERNS = []

fill_value_for_input(input, label_text):
  input_pattern = input.getAttribute("pattern") // ""
  label_lower = label_text.lower() // input.placeholder.lower() // ""

  IF FILL_PATTERNS defined:
    FOR entry trong FILL_PATTERNS:
      IF any(hint.lower() IN label_lower FOR hint IN entry.label_hints):
        RETURN entry.sample_values[0]
      IF input_pattern != "" AND any(hint IN input_pattern FOR hint IN entry.html5_pattern_hints):
        RETURN entry.sample_values[0]

  — Fallback: generic fill theo type
  IF type=text/email: RETURN "test@example.com"
  IF type=tel: RETURN IF LOCALE=="vi" THEN "0912345678" ELSE "555-0100"
  IF type=password: RETURN "Test1234!"
  IF type=number: RETURN "1"
  RETURN "test-value"
```

### A3: Test form submissions (happy path)

```
FOR moi form tren cac pages da traverse:
  1. pw_navigate "$form.page_url" "domcontentloaded"
  2. SNAPSHOT_JSON=$(pw_snapshot)
     FORM_ELEMENTS=$(echo "$SNAPSHOT_JSON" | jq -r '.forms[]?')

  — Fill form voi locale-aware valid data (IMP-009):
  FOR moi required input:
    label_text = form.getLabel(input.id) // input.placeholder // ""
    fill_val = fill_value_for_input(input, label_text)
    IF type=select → pw_select "select[name='$input.name']" "first_option_value"
    IF type=checkbox → pw_click "input[type='checkbox'][name='$input.name']"
    ELSE → pw_type "input[name='$input.name']" "$fill_val"

  — Submit form:
  pw_click "button[type='submit'], input[type='submit']"
  pw_wait "3"
  AFTER_SUBMIT=$(pw_snapshot)
  AFTER_URL=$(echo "$AFTER_SUBMIT" | jq -r '.url // ""')

  — Check result:
  a) URL thay doi (redirect)? → submit thanh cong
  b) Success toast/message? → submit thanh cong
  c) Validation error? → form co validation, check logic
  d) KHONG co thay doi? → submit fail

  IF submit fail:
    EMIT Signal (HIGH — form submit khong phan hoi)
    pw_screenshot "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/evidence/form-submit-fail-${form.id}.png"
```

### Tao Signals

**Primary CTA khong phan hoi:**
```json
{
  "probe_id": "P-QD1-deep-ui-traversal",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "ui_cta_no_response",
  "target": {
    "kind": "ui_page",
    "file_path": "N/A",
    "line_range": [0, 0],
    "url": "/dashboard/settings",
    "element": "button[Submit]"
  },
  "description": "Primary CTA 'Submit' tren page /dashboard/settings khong tao ra bat ky phan hoi nao sau khi click — khong co page change, modal, hoac success/error message",
  "evidence": {
    "screenshot_path": "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/evidence/cta-no-response-Submit.png",
    "log_excerpt": "pw_click(button:has-text('Submit')) → no DOM change detected after 2s wait"
  },
  "suggested_severity": "high",
  "dedup_hints": ["cta:/dashboard/settings:Submit"]
}
```

**Page 404/500 error:**
```json
{
  "probe_id": "P-QD1-deep-ui-traversal",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "ui_page_error",
  "target": {
    "kind": "ui_page",
    "file_path": "N/A",
    "line_range": [0, 0],
    "url": "/dashboard/analytics"
  },
  "description": "Navigation den page /dashboard/analytics tra ve trang loi (404 Not Found) — page duoc link tu nhung khong ton tai hoac chua deploy",
  "evidence": {
    "screenshot_path": "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/evidence/page-error-dashboard-analytics.png",
    "log_excerpt": "pw_navigate(/dashboard/analytics) → 404 page displayed"
  },
  "suggested_severity": "high",
  "dedup_hints": ["page:/dashboard/analytics"]
}
```

**Form submit khong phan hoi:**
```json
{
  "probe_id": "P-QD1-deep-ui-traversal",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "ui_form_submit_fail",
  "target": {
    "kind": "ui_page",
    "file_path": "N/A",
    "line_range": [0, 0],
    "url": "/dashboard/settings",
    "element": "form#settings-form"
  },
  "description": "Form 'settings-form' tren page /dashboard/settings khong phan hoi sau khi submit — khong co redirect, toast, hoac error message",
  "evidence": {
    "screenshot_path": "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/evidence/form-submit-fail-settings-form.png",
    "log_excerpt": "pw_click(submit) → no DOM change after 3s wait"
  },
  "suggested_severity": "high",
  "dedup_hints": ["form:/dashboard/settings:settings-form"]
}
```

### Write raw signals va page catalog

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/P-QD1-deep-ui-traversal.json" << 'EOF'
$TRAVERSAL_SIGNALS
EOF

— Page catalog cho P-QD1-orphan-ui-detect su dung:
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/catalog-ui-pages.json" << 'EOF'
{
  "probe_id": "P-QD1-deep-ui-traversal",
  "tool": "playwright-session.js (bash-level)",
  "pages_visited": $VISITED_PAGES,
  "elements_found": {
    "buttons": $BUTTON_COUNT,
    "forms": $FORM_COUNT,
    "links": $LINK_COUNT
  }
}
EOF
```

## VERIFY

1. Kiem tra moi Signal co `evidence.screenshot_path` hoac `evidence.log_excerpt` non-empty (min 20 chars)
2. Kiem tra moi Signal co `target.url` voi page path
3. Kiem tra moi Signal co `signal_type` trong `["ui_cta_no_response", "ui_page_error", "ui_form_submit_fail", "missing_nav_link", "extra_nav_link"]`
4. Kiem tra moi Signal co `dedup_hints` voi element identifier
5. Kiem tra page catalog duoc tao cho P-QD1-orphan-ui-detect
6. Dem: tong pages visited, tong CTAs tested, tong forms tested → ghi vao lane-status.json

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| `$BASE_URL == null` | Skip toan bo probe, note "skipped_no_base_url" |
| Frontend unreachable | Skip toan bo probe, note "skipped_frontend_unreachable" |
| Browser unavailable (pw_launch fail) | Skip toan bo probe, note "skipped_browser_unavailable" |
| Page timeout (>10s load) | Emit HIGH signal "page_load_timeout", skip page |
| Redirect loop | Emit HIGH signal, STOP traversal cho route do |
| Qua nhieu pages (>20) | STOP traversal, ghi WARNING "max_pages_reached" |
| Form yeu cau captcha/2FA | Skip form, note "skipped_captcha_protected" |
| `--no-browser` flag set | Skip toan bo probe, note "skipped_no_browser" |
