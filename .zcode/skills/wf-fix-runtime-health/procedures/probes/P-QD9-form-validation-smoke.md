# P-QD9-form-validation-smoke — Form Validation Smoke Test

> **Type:** runtime (browser) | **Profile:** exhaustive only | **Cache:** skip (always runtime)
> **Parallel class:** runtime → sequential (browser session; chay sau P-QD9-spa-route-coverage)
> **Signal types:** `form_validation_bypass` (HIGH), `form_validation_missing` (MEDIUM)
> **Error codes:** E096 (browser lock fail — tu `_shared.md`)

Kiem tra validation cua moi form tren cac trang da traverse. Test 2 truong hop: (1) Submit rong khi co required fields — expect error message hien thi; (2) Fill du lieu sai dinh dang (email="abc", phone="abc", number="abc") → submit — expect error message hien thi. Emit `form_validation_bypass` (HIGH) neu form CHAP NHAN du lieu khong hop le (khong co loi, URL doi hoac success message xuat hien). Emit `form_validation_missing` (MEDIUM) neu form KHONG hien thi error message sau khi submit sai.

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| Browser launch + close | `procedures/probes/_shared.md` | `:26-44` | `pw_launch` / `pw_close` + trap EXIT |
| `emit_signal_browser` pattern | `procedures/probes/_shared.md` | `:51-86` | signal-v2 schema, atomic append toi RAW_DIR/probe_id.jsonl |
| Common variables | `procedures/probes/_shared.md` | `:7-18` | `LANE_DIR, RAW_DIR, SIGNALS_FILE, SESSION_FILE, DEV_SERVER_STATE, AUTH_SESSION` |
| Auth session reuse (PRE-GATE) | `QD9 P-QD9-auth-aware-smoke.md` | `:PRE-GATE step 1-8` | Doc AUTH_SESSION de inject cookies truoc khi test forms |
| DEV_SERVER_STATE check | `QD9 P-QD9-auth-aware-smoke.md` | `:PRE-GATE step 52-57` | Verify dev server ready truoc khi chay browser probe |
| CI detection load | `QD9 P-QD9-interactive-smoke.md` | `:PRE-GATE step 5` | `source <(bash ci-detect.sh)` pattern |
| Page traversal + form discovery | `QD1 P-QD1-deep-ui-traversal.md` | `:B1-B2 (lines 32-59)` | Navigation graph builder, `$NAV_ROUTES[]`, `$FORMS[]` tu snapshot |
| `fill_value_for_input` locale-aware | `QD1 P-QD1-deep-ui-traversal.md` | `:A3-locale (lines 153-184)` | Locale-aware fill pattern (IMP-009) — REUSE cho happy-path baseline |

**Diff so voi QD1-QD8 va QD9 probes khac:**
- Probe nay test NEGATIVE cases (invalid input) — QD1 A3 chi test happy-path (valid fill)
- Them buoc "fill invalid" sau buoc "submit empty" → 2 pass per form
- CI-ROUTE: Serena `find_symbol` Zod/Yup/Joi schemas PRIMARY — lay validation rules de biet "invalid" value nao phu hop
- Profile EXHAUSTIVE ONLY (khac W1.5a-c la deep+) — form validation test ton nhieu browser interaction time

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Locate Zod/Yup/Joi schemas | **Serena** `find_symbol({name_path_pattern: "z.object\|yup.object\|Joi.object", include_body: true})` | Grep `z\.object\|yup\.object\|Joi\.object` trong src/ | Lay validation rules de biet fields gi la required va format gi la valid |
| Locate form component validators | **Serena** `find_symbol({name_path_pattern: "validate\|schema\|resolver", include_body: true})` | Grep `resolver=\|validationSchema=` trong src/ | Tim react-hook-form/Formik resolver de biet schema duoc ap dung |
| Cross-ref form submission handlers | **Serena** `find_symbol({name_path_pattern: "onSubmit\|handleSubmit", include_body: false})` | Grep `onSubmit\|handleSubmit` | Tim handlers de biet form co validation logic hay khong |

**Khi CI unavailable:**
```bash
if [[ "$SERENA_AVAILABLE" != "true" ]]; then
  echo "WARN: Serena unavailable — fallback to Grep for schema detection (coverage degrades)" >&2
fi
```

**Serena usage note:** Khi Serena available, load schema context TRUOC khi test forms. Schema context giup probe biet:
- Fields nao la required → test submit-empty cho truong hop ro rang nhat
- Fields nao co format constraint (email, phone, URL, number range) → test fill-invalid voi gia tri sai dinh dang
- Khong co schema → test generic invalid values (email="abc", phone="abc", number="abc", text="")

---

## PRE-GATE

```
1. IF profile=quick OR profile=standard OR profile=deep:
     SKIP probe, note "QD9-exhaustive-only-form-validation-skip"
     → Chi chay khi profile=exhaustive

2. IF --no-browser: SKIP probe (da SKIP toan lane E093 — probe nay khong duoc goi)

3. IF DEV_SERVER_STATE khong ton tai HOAC status == "fail":
     SKIP probe, note "skipped_dev_server_not_ready (E095 upstream)"

4. Read BASE_URL tu DEV_SERVER_STATE.url
   IF BASE_URL == null hoac "": SKIP probe, note "skipped_no_base_url"

5. Load CI availability:
     source <(bash .claude/scripts/ci-detect.sh --project-root "$PROJECT_ROOT" 2>/dev/null) || true
     SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"

6. IF AUTH_SESSION ton tai va non-empty:
     LOG "INFO: AUTH_SESSION found — will inject cookies to access auth-gated forms"
   ELSE:
     LOG "INFO: No AUTH_SESSION — may skip forms behind auth"
```

---

## SENSE

### S1: Serena Schema Context Load (CI-ROUTE PRIMARY)

```bash
SCHEMA_CONTEXT=""
VALIDATED_FIELDS=()   # [{field_name, type, required, format_hint}]

if [[ "$SERENA_AVAILABLE" == "true" ]]; then
  # (Pseudocode — orchestrator agent thuc hien):
  # ZOD_RESULT = serena_find_symbol({name_path_pattern: "z.object", include_body: true})
  # YUP_RESULT = serena_find_symbol({name_path_pattern: "yup.object", include_body: true})
  # JOI_RESULT = serena_find_symbol({name_path_pattern: "Joi.object", include_body: true})
  # SCHEMA_CONTEXT = merge(ZOD_RESULT, YUP_RESULT, JOI_RESULT)
  # VALIDATED_FIELDS = parse required fields + format hints tu SCHEMA_CONTEXT
  LOG "INFO: Serena schema context loaded for form validation context" >&2
else
  # Fallback: grep validation schemas
  SCHEMA_FILES=$(grep -rl "z\.object\|yup\.object\|Joi\.object\|validationSchema" \
    "$PROJECT_ROOT/src" "$PROJECT_ROOT/apps" 2>/dev/null | \
    grep -v node_modules | head -10)
  LOG "WARN: Serena unavailable — schema context limited (fallback grep found: $(echo "$SCHEMA_FILES" | wc -l) files)" >&2
fi
```

### S2: Page Discovery va Form Catalog

Reuse QD1 B1-B2 navigation graph builder:

```bash
MAX_PAGES=50   # exhaustive profile limit
MAX_FORMS=20   # toi da forms de test
FORMS_CATALOG=()   # [{page_url, form_selector, fields[]}]

# B1: Navigate homepage, lay initial snapshot
# pw_ url="$BASE_URL/" wait_until="networkidle"
# pw_ time=2000
# INITIAL_SNAPSHOT = pw_snapshot

# Parse NAV_ROUTES tu INITIAL_SNAPSHOT
# NAV_LINKS = tat ca a[href] bat dau bang "/" (khong phai "#", "_next/", "/api/")

# B2: Build navigation queue (dedup theo href)
# PAGE_QUEUE = NAV_ROUTES deduped
```

Cho moi trang trong PAGE_QUEUE:

```bash
PAGES_TRAVERSED=0

WHILE PAGE_QUEUE khong rong AND PAGES_TRAVERSED < $MAX_PAGES:
  ROUTE = PAGE_QUEUE.shift()
  IF ROUTE.href trong VISITED: continue

  # Navigate toi trang
  # pw_ url="$BASE_URL$ROUTE.href" wait_until="domcontentloaded"
  # pw_ time=1500
  # PAGE_SNAPSHOT = pw_snapshot

  PAGES_TRAVERSED++

  # Tim forms trong snapshot
  # FORM_ELEMENTS = extract_forms_from_snapshot(PAGE_SNAPSHOT)
  # Lay: form element selector, input fields, submit button

  FOR moi FORM trong FORM_ELEMENTS:
    IF len(FORMS_CATALOG) >= MAX_FORMS:
      LOG "INFO: max_forms_reached ($MAX_FORMS) — stop discovery" >&2
      break
    FORMS_CATALOG.append({
      page_url: "$BASE_URL$ROUTE.href",
      form_selector: FORM.selector,
      fields: extract_fields(FORM)   # [{name, type, required, placeholder, label}]
      has_submit: FORM.has_submit_button
    })

  # Append more nav links to queue (BFS traversal)
  MORE_LINKS = extract_nav_links_from_snapshot(PAGE_SNAPSHOT)
  FOR link IN MORE_LINKS:
    IF link.href NOT IN VISITED AND len(PAGE_QUEUE) < MAX_PAGES:
      PAGE_QUEUE.append(link)

LOG "INFO: SENSE: ${#FORMS_CATALOG[@]} forms found across $PAGES_TRAVERSED pages" >&2
```

**Form filter — chi test forms co kha nang validation:**
```
TESTABLE_FORMS = [form FOR form IN FORMS_CATALOG IF:
  len(form.fields) >= 1     # Co it nhat 1 input field
  AND form.has_submit        # Co submit button
  AND NOT form_is_search(form)   # Loai search forms (1 text input + submit)
  AND NOT form_is_filter(form)   # Loai filter/sort forms
]
```

Search form detection:
```
form_is_search(form):
  RETURN len(form.fields) == 1 AND form.fields[0].type == "search"
         OR any(btn.text.lower() IN ["search", "tim kiem", "tim"] FOR btn IN form.buttons)
```

---

## THINK

### Validation Test Strategy per Form

Load `fill_value_for_input` locale-aware pattern (REUSE QD1 A3-locale:153-184):

```bash
LOCALE=$(jq -r '.locale // "en"' ".mc-data/docs/_meta/req-registry.json" 2>/dev/null || echo "en")

fill_value_for_input_INVALID(input, label_text):
  # INVERSE of QD1 A3-locale — tim invalid value cho moi type
  label_lower = label_text.lower()

  # Email field
  IF type=email OR "email" IN label_lower OR "mail" IN label_lower:
    RETURN "invalid-not-an-email"

  # Phone field
  IF type=tel OR any(hint IN label_lower FOR hint IN ["phone", "dien thoai", "so dien", "sdt", "mobile"]):
    RETURN "not-a-phone"

  # Number field
  IF type=number OR any(hint IN label_lower FOR hint IN ["quantity", "so luong", "amount", "price", "gia"]):
    RETURN "not-a-number"

  # URL field
  IF type=url OR "url" IN label_lower OR "website" IN label_lower:
    RETURN "not-a-valid-url"

  # Date field
  IF type=date OR type=datetime-local OR any(hint IN label_lower FOR hint IN ["date", "ngay", "birthday"]):
    RETURN "not-a-date"

  # Generic text — too short (2 chars khi min length likely higher)
  IF type=text OR type=textarea:
    RETURN "ab"

  # Password
  IF type=password:
    RETURN "x"

  # Select — khong co invalid test (browser ko submit invalid options)
  IF type=select:
    RETURN null  # SKIP

  RETURN "invalid_value"
```

### Priority Queue (form importance)

```
Priority 1: Forms co required fields EXPLICITLY marked (required attr, aria-required=true)
Priority 2: Forms duoc Serena phat hien co validation schema
Priority 3: Forms con lai (test generic invalid)
```

---

## ACT

### A0: Acquire Browser Singleton

```bash
pw_launch || {
  echo "ERROR: Cannot launch browser (E096)" >&2
  exit 1
}
trap "pw_close" EXIT
```

### A1: Auth Inject (neu AUTH_SESSION co san)

```bash
if [ -s "$AUTH_SESSION" ]; then
  AUTH_COOKIES=$(jq -r '.cookies // [] | .[] | "\(.name)=\(.value)"' "$AUTH_SESSION" 2>/dev/null || echo "")
  if [ -n "$AUTH_COOKIES" ]; then
    # pw_evaluate expression="
    #   var c = '$AUTH_COOKIES'; document.cookie = c + '; path=/';
    # "
    LOG "INFO: Auth cookies injected from AUTH_SESSION" >&2
  fi
fi
```

### A2: Navigate Homepage (establish session)

```bash
# pw_ url="$BASE_URL/" wait_until="networkidle"
# pw_ time=2000
LOG "INFO: Homepage loaded — starting form validation tests" >&2
```

### A3: Per-Form Test (2 passes)

```bash
SIGNAL_COUNT=0
MAX_SIGNALS=50
FORMS_TESTED=0
BYPASS_SIGNALS=0
MISSING_SIGNALS=0

FOR form IN TESTABLE_FORMS:
  FORMS_TESTED=$((FORMS_TESTED + 1))
  PAGE_URL = form.page_url
  LOG "INFO: Testing form on $PAGE_URL (form_selector=${form.form_selector})" >&2

  # --- PASS 1: Submit Empty (required validation test) ---
  # Kiem tra: form co hien error khi submit rong khong?

  # Navigate toi trang chua form
  # pw_ url="$PAGE_URL" wait_until="domcontentloaded"
  # pw_ time=2000
  URL_BEFORE_EMPTY = current_url()

  # Khong fill gi ca, submit thang
  SUBMIT_BTN = form.submit_button
  # pw_click ref=SUBMIT_BTN.ref
  # pw_ time=2000
  # SNAPSHOT_AFTER_EMPTY = pw_snapshot
  URL_AFTER_EMPTY = current_url()

  # Kiem tra ket qua:
  FORM_ACCEPTED_EMPTY = false
  FORM_SHOWED_ERROR_EMPTY = false

  # URL thay doi (redirect) = form accepted empty (bypass validation)
  IF URL_AFTER_EMPTY != URL_BEFORE_EMPTY AND NOT is_auth_redirect(URL_AFTER_EMPTY):
    FORM_ACCEPTED_EMPTY = true

  # Neu URL khong doi: kiem tra co error message khong
  IF URL_AFTER_EMPTY == URL_BEFORE_EMPTY:
    ERROR_ELEMENTS = query_snapshot(
      selectors=["[role=alert]", "[aria-invalid=true]", ".error", ".invalid",
                 ".field-error", "[class*=error]", "[class*=invalid]",
                 ".help-text", ".form-error", ".validation-message"]
    )
    IF len(ERROR_ELEMENTS) > 0:
      FORM_SHOWED_ERROR_EMPTY = true

  # Phat hien loi:
  IF FORM_ACCEPTED_EMPTY:
    # HIGH — form chap nhan du lieu rong (bypass validation)
    IF SIGNAL_COUNT < MAX_SIGNALS:
      SCREENSHOT_PATH="$RAW_DIR/screenshot-bypass-empty-$(echo "$PAGE_URL" | md5sum | cut -c1-8).png"
      # pw_screenshot output_path="$SCREENSHOT_PATH" || SCREENSHOT_PATH="null"
      emit_signal_browser "P-QD9-form-validation-smoke" \
        "form_validation_bypass" "high" \
        "Form chap nhan submit rong (bypass required validation): $PAGE_URL" \
        "Form tai '$PAGE_URL' cho phep submit khi cac required fields rong. URL thay doi tu '$URL_BEFORE_EMPTY' sang '$URL_AFTER_EMPTY' — form da chap nhan du lieu khong hop le. Validation bi bypass hoan toan, du lieu rong co the duoc luu vao backend." \
        "$PAGE_URL" \
        "screenshot" \
        "Form: ${form.form_selector} | URL_before: $URL_BEFORE_EMPTY | URL_after: $URL_AFTER_EMPTY | Test: submit_empty" \
        "\"$SCREENSHOT_PATH\""
      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      BYPASS_SIGNALS=$((BYPASS_SIGNALS + 1))
      LOG "INFO: Signal emitted — form_validation_bypass (empty submit accepted): $PAGE_URL" >&2
    fi

  ELIF NOT FORM_SHOWED_ERROR_EMPTY:
    # MEDIUM — form khong show error sau submit rong
    IF SIGNAL_COUNT < MAX_SIGNALS:
      SCREENSHOT_PATH="$RAW_DIR/screenshot-missing-empty-$(echo "$PAGE_URL" | md5sum | cut -c1-8).png"
      # pw_screenshot output_path="$SCREENSHOT_PATH" || SCREENSHOT_PATH="null"
      emit_signal_browser "P-QD9-form-validation-smoke" \
        "form_validation_missing" "medium" \
        "Form khong hien thi error message sau submit rong: $PAGE_URL" \
        "Form tai '$PAGE_URL' khong hien thi bat ky validation error nao sau khi submit voi required fields rong. URL khong doi ('$URL_BEFORE_EMPTY') nhung cung khong co error element [role=alert] hoac [aria-invalid=true]. User se khong biet tai sao form khong submit." \
        "$PAGE_URL" \
        "screenshot" \
        "Form: ${form.form_selector} | URL_unchanged: $URL_BEFORE_EMPTY | Test: submit_empty_no_error_shown" \
        "\"$SCREENSHOT_PATH\""
      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      MISSING_SIGNALS=$((MISSING_SIGNALS + 1))
      LOG "INFO: Signal emitted — form_validation_missing (no error on empty submit): $PAGE_URL" >&2
    fi
  fi

  # --- PASS 2: Fill Invalid Data (format validation test) ---
  # Kiem tra: form co reject invalid-format data khong?

  # Loc fields co the test invalid (loai select, checkbox, radio)
  TESTABLE_FIELDS = [f FOR f IN form.fields IF f.type NOT IN ["select", "checkbox", "radio", "hidden", "file"]]

  IF len(TESTABLE_FIELDS) == 0:
    LOG "INFO: No testable fields for invalid-fill on $PAGE_URL — skip pass 2" >&2
    continue

  # Navigate lai (fresh state)
  # pw_ url="$PAGE_URL" wait_until="domcontentloaded"
  # pw_ time=2000
  URL_BEFORE_INVALID = current_url()

  HAS_INVALID_FIELDS = false
  FOR input IN TESTABLE_FIELDS:
    label_text = input.label // input.placeholder // input.name // ""
    INVALID_VAL = fill_value_for_input_INVALID(input, label_text)
    IF INVALID_VAL == null: continue   # Select fields skip
    HAS_INVALID_FIELDS = true
    # pw_type ref=input.ref text=INVALID_VAL
    LOG "INFO: Filled invalid: ${input.name}=${INVALID_VAL}" >&2

  IF NOT HAS_INVALID_FIELDS:
    LOG "INFO: No invalid-fillable fields on $PAGE_URL — skip pass 2" >&2
    continue

  # Submit form voi invalid data
  # pw_click ref=SUBMIT_BTN.ref
  # pw_ time=2000
  # SNAPSHOT_AFTER_INVALID = pw_snapshot
  URL_AFTER_INVALID = current_url()

  # Kiem tra ket qua:
  FORM_ACCEPTED_INVALID = false
  FORM_SHOWED_ERROR_INVALID = false

  IF URL_AFTER_INVALID != URL_BEFORE_INVALID AND NOT is_auth_redirect(URL_AFTER_INVALID):
    FORM_ACCEPTED_INVALID = true

  IF URL_AFTER_INVALID == URL_BEFORE_INVALID:
    ERROR_ELEMENTS = query_snapshot(
      selectors=["[role=alert]", "[aria-invalid=true]", ".error", ".invalid",
                 ".field-error", "[class*=error]", "[class*=invalid]",
                 ".help-text", ".form-error", ".validation-message"]
    )
    IF len(ERROR_ELEMENTS) > 0:
      FORM_SHOWED_ERROR_INVALID = true

  IF FORM_ACCEPTED_INVALID:
    IF SIGNAL_COUNT < MAX_SIGNALS:
      SCREENSHOT_PATH="$RAW_DIR/screenshot-bypass-invalid-$(echo "$PAGE_URL" | md5sum | cut -c1-8).png"
      # pw_screenshot output_path="$SCREENSHOT_PATH" || SCREENSHOT_PATH="null"
      INVALID_SUMMARY = build_invalid_summary(TESTABLE_FIELDS)   # "email=invalid-not-an-email, phone=not-a-phone"
      emit_signal_browser "P-QD9-form-validation-smoke" \
        "form_validation_bypass" "high" \
        "Form chap nhan du lieu sai dinh dang (bypass format validation): $PAGE_URL" \
        "Form tai '$PAGE_URL' cho phep submit voi du lieu sai dinh dang: ${INVALID_SUMMARY}. URL thay doi tu '$URL_BEFORE_INVALID' sang '$URL_AFTER_INVALID' — form da chap nhan invalid data. Du lieu sai co the duoc luu vao backend, gay ra loi logic hoac data corruption." \
        "$PAGE_URL" \
        "screenshot" \
        "Form: ${form.form_selector} | URL_before: $URL_BEFORE_INVALID | URL_after: $URL_AFTER_INVALID | Invalid fields: $INVALID_SUMMARY" \
        "\"$SCREENSHOT_PATH\""
      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      BYPASS_SIGNALS=$((BYPASS_SIGNALS + 1))
      LOG "INFO: Signal emitted — form_validation_bypass (invalid data accepted): $PAGE_URL — $INVALID_SUMMARY" >&2
    fi

  ELIF NOT FORM_SHOWED_ERROR_INVALID:
    IF SIGNAL_COUNT < MAX_SIGNALS:
      SCREENSHOT_PATH="$RAW_DIR/screenshot-missing-invalid-$(echo "$PAGE_URL" | md5sum | cut -c1-8).png"
      # pw_screenshot output_path="$SCREENSHOT_PATH" || SCREENSHOT_PATH="null"
      INVALID_SUMMARY = build_invalid_summary(TESTABLE_FIELDS)
      emit_signal_browser "P-QD9-form-validation-smoke" \
        "form_validation_missing" "medium" \
        "Form khong hien thi error sau khi fill du lieu sai dinh dang: $PAGE_URL" \
        "Form tai '$PAGE_URL' khong hien thi error message sau khi fill invalid data: ${INVALID_SUMMARY}. URL khong thay doi ('$URL_BEFORE_INVALID') nhung khong co element [role=alert] hoac [aria-invalid=true] xuat hien. User se khong biet truong nao bi sai va tai sao." \
        "$PAGE_URL" \
        "screenshot" \
        "Form: ${form.form_selector} | URL_unchanged: $URL_BEFORE_INVALID | Invalid fields: $INVALID_SUMMARY | Test: fill_invalid_no_error_shown" \
        "\"$SCREENSHOT_PATH\""
      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      MISSING_SIGNALS=$((MISSING_SIGNALS + 1))
      LOG "INFO: Signal emitted — form_validation_missing (no error on invalid fill): $PAGE_URL" >&2
    fi
  fi
done
```

---

## VERIFY

```
1. Kiem tra moi signal co dimension_id == "QD9" va probe_id == "P-QD9-form-validation-smoke"
2. Kiem tra signal_type chi co "form_validation_bypass" hoac "form_validation_missing"
3. Kiem tra form_validation_bypass co severity == "high"
4. Kiem tra form_validation_missing co severity == "medium"
5. Kiem tra moi signal co evidence[] non-empty voi content >= 10 chars
6. Kiem tra total signals per probe <= 50
7. Kiem tra FORMS_TESTED <= MAX_FORMS (20)

Ghi summary:
  cat > "$RAW_DIR/P-QD9-form-validation-smoke-summary.json" << EOF
  {
    "probe_id": "P-QD9-form-validation-smoke",
    "pages_traversed": $PAGES_TRAVERSED,
    "forms_discovered": ${#FORMS_CATALOG[@]},
    "forms_tested": $FORMS_TESTED,
    "bypass_signals": $BYPASS_SIGNALS,
    "missing_signals": $MISSING_SIGNALS,
    "total_signals": $SIGNAL_COUNT,
    "serena_schema_context_loaded": $SERENA_SCHEMA_LOADED,
    "locale": "$LOCALE",
    "profile": "exhaustive"
  }
  EOF
```

---

## Severity Rules

| Dieu kien | Severity | Ly do |
|-----------|----------|-------|
| Form submit rong → URL doi (accepted) | **HIGH** | Du lieu rong duoc luu vao backend — data integrity risk |
| Form fill invalid format → URL doi (accepted) | **HIGH** | Invalid data duoc luu — co the gay data corruption |
| Form submit rong → khong co error message | **MEDIUM** | UX gap — user khong biet loi, UI van lam viec |
| Form fill invalid → khong co error message | **MEDIUM** | UX gap — user khong biet du lieu sai |
| Form hien thi error dung (bao ve) | **PASS** — khong emit signal | Behavior dung — form co validation |
| Search form (1 input + submit) | **SKIP** — khong test | Search form it khi co strict validation |
| Filter/sort form | **SKIP** — khong test | Filter forms design de accept bat ky gia tri |
| Auth-gated page (redirect /login) | **SKIP** — khong test | Khong co AUTH_SESSION → protected form |
| Select, checkbox, radio, hidden, file | **SKIP** — khong fill invalid | Browser constraint → khong submit invalid option |

> **Rationale HIGH cho bypass:** Form chap nhan invalid data = backend co the nhan invalid data → data integrity risk quan trong.
> Khac voi `form_validation_missing` (MEDIUM) — form co the van validate o backend, chi thieu UX feedback.

---

## Dedup Hints

Moi signal phai co `dedup_hints` array:

| Signal Type | Dedup Hint Pattern |
|-------------|-------------------|
| `form_validation_bypass` | `["form-validation-bypass:{page_url_hash}:{test_type}"]` |
| `form_validation_missing` | `["form-validation-missing:{page_url_hash}:{test_type}"]` |

Trong do `test_type` = `empty_submit` hoac `invalid_fill`.

---

## Signal Schema Examples

### form_validation_bypass (HIGH)

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-form-validation-smoke",
  "dimension_id": "QD9",
  "signal_type": "form_validation_bypass",
  "severity": "high",
  "title": "Form chap nhan du lieu sai dinh dang (bypass format validation): /customers/new",
  "description": "Form tai '/customers/new' cho phep submit voi du lieu sai dinh dang: email=invalid-not-an-email, phone=not-a-phone. URL thay doi tu 'http://localhost:3000/customers/new' sang 'http://localhost:3000/customers/1' — form da chap nhan invalid data. Du lieu sai co the duoc luu vao backend, gay ra loi logic hoac data corruption.",
  "location": {"url": "http://localhost:3000/customers/new"},
  "evidence": [
    {"type": "screenshot", "content": "/session/phase4-find-bugs/lanes/QD9-runtime-health/raw/screenshot-bypass-invalid-abc12345.png"},
    {"type": "log_excerpt", "content": "Form: form.customer-form | URL_before: http://localhost:3000/customers/new | URL_after: http://localhost:3000/customers/1 | Invalid fields: email=invalid-not-an-email, phone=not-a-phone"}
  ],
  "screenshot": "/session/phase4-find-bugs/lanes/QD9-runtime-health/raw/screenshot-bypass-invalid-abc12345.png",
  "cdg_flags": [],
  "fixability": "agent_fix",
  "dedup_hints": ["form-validation-bypass:a1b2c3d4:invalid_fill"]
}
```

### form_validation_missing (MEDIUM)

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-form-validation-smoke",
  "dimension_id": "QD9",
  "signal_type": "form_validation_missing",
  "severity": "medium",
  "title": "Form khong hien thi error sau khi fill du lieu sai dinh dang: /quotes/create",
  "description": "Form tai '/quotes/create' khong hien thi error message sau khi fill invalid data: email=invalid-not-an-email. URL khong thay doi ('http://localhost:3000/quotes/create') nhung khong co element [role=alert] hoac [aria-invalid=true] xuat hien. User se khong biet truong nao bi sai va tai sao.",
  "location": {"url": "http://localhost:3000/quotes/create"},
  "evidence": [
    {"type": "screenshot", "content": "/session/phase4-find-bugs/lanes/QD9-runtime-health/raw/screenshot-missing-invalid-b2c3d4e5.png"},
    {"type": "log_excerpt", "content": "Form: form.quote-form | URL_unchanged: http://localhost:3000/quotes/create | Invalid fields: email=invalid-not-an-email | Test: fill_invalid_no_error_shown"}
  ],
  "screenshot": "/session/phase4-find-bugs/lanes/QD9-runtime-health/raw/screenshot-missing-invalid-b2c3d4e5.png",
  "cdg_flags": [],
  "fixability": "agent_fix",
  "dedup_hints": ["form-validation-missing:b2c3d4e5:invalid_fill"]
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile=quick/standard/deep | SKIP probe, note "QD9-exhaustive-only-form-validation-skip" |
| DEV_SERVER_STATE khong co hoac failed | SKIP probe, note "skipped_dev_server_not_ready (E095 upstream)" |
| BASE_URL null | SKIP probe, note "skipped_no_base_url" |
| FORMS_CATALOG rong (0 forms found) | Log INFO "no_forms_discovered" — khong emit signal, probe complete cleanly |
| Search form (1 field + search button) | Skip form — log INFO "search_form_skip" |
| Filter/sort form detection | Skip form — log INFO "filter_form_skip" |
| Auth-gated form page (redirect /login) | Skip page — log INFO "auth_gated_form_skip" |
| pw_launch fail (E096) | STOP probe — exit 1, ghi error >&2 |
| Serena unavailable | Fallback Grep schema detection — log WARN, coverage degrades but khong block |
| Form khong co submit button | Skip form — log INFO "no_submit_button_skip" |
| Select/checkbox/radio/hidden/file fields | Skip invalid-fill cho field nay — chi test text/email/tel/number/url |
| browser_navigate fail (connection) | Skip page — log WARN "page_unreachable_skip_{url}" |
| Screenshot capture fail | Set screenshot: "null" — tiep tuc, khong block |
| > 50 signals tong | Stop emitting — log WARN "max_signals_reached", tiep tuc traverse nhung khong emit |
| > 20 forms tested | Stop testing — log INFO "max_forms_reached" |

---

## Cache Policy

**skip** — probe nay la runtime (browser interaction). KHONG cache results.

Ly do: Form validation logic co the thay doi sau bao gio. Cache se mask bugs moi duoc introduce.
Schema context tu Serena co cache 24h (per Protocol 20 §3.5) — nhung navigation + submit la fresh.

---

## Profile-Resolver Entry

```yaml
# Trong _shared/lane/profile-resolver.md (QD9 section):
P-QD9-form-validation-smoke:
  quick: skip
  standard: skip
  deep: skip
  exhaustive: run (max_pages=50, max_forms=20, max_signals=50)
  parallel_class: runtime
  optional: false
```

---

## Acceptance Test

**Synthetic test (CI):**
1. Setup form voi email field (khong co validation):
   ```html
   <form onsubmit="return true">
     <input type="email" name="email" required>
     <button type="submit">Submit</button>
   </form>
   ```
2. Run probe voi `--profile=exhaustive`
3. **Expected:**
   - Pass 1 (empty submit): form submits without redirect → kiem tra loi message
   - Pass 2 (invalid fill): email="invalid-not-an-email" → submit → neu form redirect/accept → `form_validation_bypass` signal severity=HIGH
   - `P-QD9-form-validation-smoke-summary.json` duoc tao voi forms_tested >= 1

**EUREKA real-world acceptance (W1.5.E2E):**
- Chay `/wf-fix-bugs --lane=QD9 --profile=exhaustive --scope=module --name=MOD-CRM` tren EUREKA erp-web
- Expect: forms discovered tren cac pages CRM (customer create, quote form, etc.)
- Expect: form registration / quote form duoc test
- Expect: neu form co Zod validation → PASS (no signal); neu form thieu validation → signal emitted
- Performance: probe complete trong <= 10 phut cho module scope (20 forms × 2 passes × 3s each)
