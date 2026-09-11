# P-QD9-interactive-smoke — Interactive CTA Smoke Test

> **Type:** runtime (Playwright bash-level) | **Profile:** standard, deep, exhaustive (v10.2: promoted to standard) | **Cache:** skip (always runtime)
> **Parallel class:** runtime → sequential (browser session; chay sau P-QD9-console-network-monitor)
> **Signal types:** `ui_cta_no_response` (MEDIUM), `runtime_uncaught_exception` (CRITICAL khi CTA trigger crash)
> **Error codes:** E096 (browser lock fail — tu `_shared.md`)
> **v10.2 changes:** Promoted to standard profile. Mo rong modal/sheet selector (Radix/headlessui/shadcn/MUI). Sidebar/menu expand pre-step (B0). Loai "cancel/reset/clear" khoi destructive skip-list (source bug pho bien). Cap MAX_ROUTES/BUTTONS theo profile.

Traverse cac route tu homepage (cung B1/B2 algorithm nhu W1.5), tim ALL primary CTAs (button, role=button, .btn class) — gioi han 10 per route, click tung CTA non-destructive, wait 2s, compare DOM/URL/modal state change. Emit `ui_cta_no_response` (MEDIUM) khi khong co thay doi. Capture screenshot moi CTA failed. CI-ROUTE PRIMARY: Serena `find_symbol("onClick", event handlers)` de map button → handler, xac nhan expected behavior truoc khi click.

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| A2 "Test primary CTAs" core pattern (click + DOM/URL diff + signal) | `QD1 P-QD1-deep-ui-traversal.md` | `:125-151` | button text matching, `pw_click` → `pw_wait "2s` → snapshot → compare → emit `ui_cta_no_response` |
| Navigation graph builder B1 (homepage → snapshot → NAV_LINKS[]) | `QD1 P-QD1-deep-ui-traversal.md` | `:36-48` | `browser_navigate → pw_wait "2000" → pw_snapshot → parse NAV_LINKS[]` |
| Navigation graph builder B2 (dedup, exclusion list, NAV_ROUTES[]) | `QD1 P-QD1-deep-ui-traversal.md` | `:49-59` | dedup by href, exclusion list (`/login /auth /api /_next`), build NAV_ROUTES[] queue |
| MAX_PAGES traversal guard | `QD1 P-QD1-deep-ui-traversal.md` | `:103-106` | `MAX_PAGES=20/50/100` per profile, VISITED set, PAGE_QUEUE.shift() |
| Browser launch + close | `procedures/probes/_shared.md` | `:26-44` | `pw_launch` / `pw_close` + trap EXIT |
| `emit_signal_browser` pattern | `procedures/probes/_shared.md` | `:51-86` | signal-v2 schema, atomic append toi RAW_DIR/probe_id.jsonl |
| Common variables | `procedures/probes/_shared.md` | `:7-18` | `LANE_DIR, RAW_DIR, SIGNALS_FILE, SESSION_FILE, DEV_SERVER_STATE, AUTH_SESSION` |
| Auth session reuse (cookie inject) | `QD9 P-QD9-auth-aware-smoke.md` | `:PRE-GATE step 1-8` | Doc `AUTH_SESSION` de inject cookies truoc khi traverse, bao ve protected routes |
| DEV_SERVER_STATE check | `QD9 P-QD9-auth-aware-smoke.md` | `:PRE-GATE step 52-57` | Verify dev server ready (status != "fail") truoc khi chay browser probe |

**Diff so voi QD1 A2:**
- QD9 W1.5b mo rong CTA discovery sang **ALL buttons** (button, [role=button], .btn class) — khong chi text-matched primary CTAs
- **Gioi han 10 CTAs per route** (QD1 khong co gioi han per-route)
- **Route list** xay tu traversal tu homepage (same B1/B2 pattern) — KHONG phu thuoc catalog file tu W1.5
- **Severity:** MEDIUM (default per `_shared.md` severity table cho `ui_cta_no_response`) — QD1 dung HIGH unconditionally
- **Destructive skip list mo rong:** delete, remove, destroy, logout, sign-out, log out, clear, reset, cancel — QD1 chi skip "delete, logout"
- **CI-ROUTE PRIMARY:** Serena `find_symbol("onClick")` de xac nhan button co handler truoc khi click (QD1 khong co CI-ROUTE)
- **Screenshot mandatory** cho moi CTA no-response signal (QD1: "capture screenshot per failed CTA")

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Map button → onClick handler | **Serena** `find_symbol({name_path_pattern: "onClick", relative_path: null, include_body: false})` | Grep `onClick\|handleClick\|onPress` trong component dir | Xac nhan button co handler truoc khi click — neu khong co handler → expected no-response, skip signal |
| Locate component file cho button | **Serena** `find_symbol({name_path_pattern: "<button-text>", relative_path: null, include_body: false})` | Grep button text trong tsx/jsx | Map visual button → source component de populate `location` trong signal |
| Augment navigation route list | **GitNexus** `query("navigation, route, link")` | Parse `<a href>` tu `pw_snapshot` (B2 fallback) | Tim them routes SPA dynamic khong reachable qua link traversal |

**Khi CI unavailable:** Set `$GITNEXUS_AVAILABLE` / `$SERENA_AVAILABLE` tu `ci-detect.sh` output. Log warning. Khong block probe — fallback Grep.

```bash
if [[ "$SERENA_AVAILABLE" != "true" ]]; then
  echo "WARN: Serena unavailable — CTA handler check degraded (fallback to no-handler-check)" >&2
fi
```

---

## PRE-GATE

```
1. IF profile=quick:
     SKIP probe, note "QD9-quick-skip-interactive-smoke"
     → v10.2: standard tro len SE chay probe nay (truoc day chi deep+)

2. v10.2 — Resolve per-profile caps:
     case "$PROFILE" in
       standard)   MAX_ROUTES=10; BUTTONS_PER_ROUTE=8;  MAX_SIGNALS=50 ;;
       deep)       MAX_ROUTES=25; BUTTONS_PER_ROUTE=20; MAX_SIGNALS=100 ;;
       exhaustive) MAX_ROUTES=50; BUTTONS_PER_ROUTE=30; MAX_SIGNALS=200 ;;
     esac

3. IF --no-browser: SKIP probe (da SKIP toan lane E093 — probe nay khong duoc goi)

4. IF DEV_SERVER_STATE khong ton tai HOAC status == "fail":
     SKIP probe, note "skipped_dev_server_not_ready (E095 upstream)"

5. Read BASE_URL tu DEV_SERVER_STATE.url
   IF BASE_URL == null hoac "": SKIP probe, note "skipped_no_base_url"

6. Load CI availability:
     source <(bash .claude/scripts/ci-detect.sh --project-root "$PROJECT_ROOT" 2>/dev/null) || true
     GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
     SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"

7. IF AUTH_SESSION ton tai va non-empty:
     LOG "INFO: AUTH_SESSION found — will inject cookies for protected routes"
   ELSE:
     LOG "INFO: No AUTH_SESSION — traverse routes without auth (some may 401)"
```

---

## SENSE

### B0 (v10.2): Sidebar/Menu Expand Pre-Step

Truoc khi enumerate buttons tren MOI route, phai expand cac container an de expose nut bi che:

```bash
# Pseudo-code (run truoc moi route trong A2 loop):
# 1. Detect collapsed sidebar/menu containers
COLLAPSE_SELECTORS=(
  'button[aria-label*="menu" i]'      # Burger menu
  'button[aria-label*="sidebar" i]'   # Sidebar toggle
  'button[aria-haspopup="true"][aria-expanded="false"]'  # Generic popover trigger
  '[role="button"][aria-expanded="false"]'
  '.hamburger, .menu-toggle, .nav-toggle, .sidebar-toggle'  # Common class names
)

# 2. Try expand (timeout 2s each, skip if no match)
for sel in "${COLLAPSE_SELECTORS[@]}"; do
  COUNT=$(pw_evaluate "document.querySelectorAll('$sel').length" 2>/dev/null | jq -r '.result // 0')
  if [ "$COUNT" -gt 0 ]; then
    pw_click "$sel" 2>/dev/null || true
    pw_wait "500" 2>/dev/null || true  # wait CSS transition
    LOG "INFO: Expanded $sel ($COUNT match)" >&2
  fi
done

# 3. Re-snapshot DOM sau khi expand → bay gio enumerate buttons SE bao gom items moi
```

**Lý do:** Nhiều UI patterns có sidebar collapsed/menu hidden default. Không expand → buttons sidebar không xuất hiện trong DOM snapshot → bỏ sót bug "sidebar item không click được".

**Try/catch guard:** Step B0 không block — nếu expand fail (selector không match, click fail) → log warning, tiếp tục bình thường. Không emit signal.

---

### B1: Navigate homepage, capture NAV_LINKS (REUSE QD1 B1 :36-48)

```bash
# pw_ url="$BASE_URL/" wait_until="networkidle"
# pw_ time=2000
# INITIAL_SNAPSHOT = pw_snapshot
# pw_screenshot output_path="$LANE_DIR/evidence/P-QD9-is-homepage.png"

# Parse INITIAL_SNAPSHOT de lay NAV_LINKS[]: all a[href] chua "/"
# Exclusion: #anchor, javascript:, /logout, /sign-out, /_next/, /api/, /auth/, /login, /signin
```

### B2: Build NAV_ROUTES queue (REUSE QD1 B2 :49-59)

```bash
NAV_ROUTES=()
# v10.2 — MAX_ROUTES resolved tu PRE-GATE step 2 (standard=10, deep=25, exhaustive=50)
# MAX_ROUTES da duoc set, default fallback 20 neu chua resolve
: "${MAX_ROUTES:=20}"

FOR moi link trong NAV_LINKS[]:
  href = normalize_to_relative_path(link.href)
  IF href trong exclusion_list → skip
  IF href da trong NAV_ROUTES → skip (dedup)
  NAV_ROUTES+=("$href")
```

### B3: CI Enrichment — GitNexus augment routes

```bash
if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # gitnexus_query("navigation, route, link") → lay them SPA routes
  # Append routes khong co trong NAV_ROUTES vao cuoi queue
  LOG "INFO: GitNexus augmenting route list" >&2
else
  LOG "WARN: GitNexus unavailable — only link-traversal routes" >&2
fi
```

---

## THINK

### Xac dinh CTA discovery scope

**Primary CTAs** trong W1.5b la tat ca interactive elements:
1. `button` (tat ca — khong chi text match)
2. `[role="button"]` (ARIA button role)
3. `.btn` class elements
4. `input[type="submit"]`, `input[type="button"]`

**Destructive skip list (v10.2 reduce — bỏ cancel/reset/clear vì là nguồn bug phổ biến):**
```
delete | remove | destroy | logout | sign.?out | log.?out
dang xuat | xoa | xoa het
```

**Lý do bỏ cancel/reset/clear:**
- Cancel button không xóa data, chỉ huỷ thao tác — test an toàn
- Bug điển hình: "Cancel" không đóng modal/form, "Reset" không reset state, "Clear" không clear input
- Vẫn giữ delete/destroy/logout vì có thể destroy data thật

**Gioi han:** Max `$BUTTONS_PER_ROUTE` CTAs per route (theo profile cap v10.2: standard=8, deep=20, exhaustive=30)

**Priority order (cho tat ca CTAs tren trang):**
1. Loai tru destructive buttons truoc
2. Lay 10 buttons dau tien tu DOM order (tren xuong duoi, trai sang phai)

### CI: Serena handler check (optional enrichment)

Neu Serena available: `find_symbol("onClick")` → kiem tra moi button text co handler reference.
- Button khong co handler → kha nang cao la display-only → ghi note nhung KHONG emit signal (tranh false positive)
- Button co handler → proceed click normally

---

## ACT

### A0: Acquire browser session

```bash
pw_launch || {
  echo "ERROR: Cannot launch browser (E096)" >&2
  exit 1
}
trap "pw_close" EXIT
```

### A1: Auth inject (neu AUTH_SESSION co san)

```bash
if [ -s "$AUTH_SESSION" ]; then
  AUTH_COOKIES=$(jq -r '.cookies // [] | .[] | "\(.name)=\(.value)"' "$AUTH_SESSION" 2>/dev/null || echo "")
  if [ -n "$AUTH_COOKIES" ]; then
    # Inject cookies qua document.cookie (Playwright bash-level compatible)
    # pw_evaluate expression="
    #   var cookies = $AUTH_COOKIES;
    #   cookies.forEach(function(c){ document.cookie = c + '; path=/'; });
    # "
    LOG "INFO: Auth cookies injected from AUTH_SESSION" >&2
  fi
fi
```

### A2: Per-route CTA interaction loop (REUSE QD1 A2 :125-151)

```bash
VISITED=()
SIGNAL_COUNT=0
# v10.2 — MAX_SIGNALS resolved tu PRE-GATE (standard=50, deep=100, exhaustive=200)
: "${MAX_SIGNALS:=50}"
: "${BUTTONS_PER_ROUTE:=10}"  # v10.2 — replace hardcoded 10

ROUTE_QUEUE=("$BASE_URL/")
for route in "${NAV_ROUTES[@]}"; do
  ROUTE_QUEUE+=("$BASE_URL$route")
done

while [ "${#ROUTE_QUEUE[@]}" -gt 0 ] && [ "${#VISITED[@]}" -lt "$MAX_ROUTES" ]; do
  PAGE_URL="${ROUTE_QUEUE[0]}"
  ROUTE_QUEUE=("${ROUTE_QUEUE[@]:1}")  # shift

  # Dedup
  already_visited=false
  for v in "${VISITED[@]}"; do [ "$v" = "$PAGE_URL" ] && { already_visited=true; break; }; done
  $already_visited && continue
  VISITED+=("$PAGE_URL")

  LOG "INFO: Interactive smoke: $PAGE_URL" >&2

  # A2.1 — Navigate toi route
  NAV_RESULT=$(pw_ --url "$PAGE_URL" --wait_until "domcontentloaded" 2>&1 || echo "NAV_ERROR")
  if [[ "$NAV_RESULT" == *"NAV_ERROR"* ]] || [[ "$NAV_RESULT" == *"ERR_CONNECTION"* ]]; then
    LOG "WARN: Cannot navigate $PAGE_URL — skip route" >&2
    continue
  fi
  # pw_ time=2000

  # A2.2 — Snapshot: lay danh sach all CTAs
  SNAPSHOT=$(pw_snapshot 2>&1 || echo "")

  # Tim buttons tu snapshot (loai destructive)
  # Parse buttons theo 4 selector types: button, [role=button], .btn, input[type=submit/button]
  # Simple grep approach tu snapshot text (tuong tu QD1 button parsing):
  # Extract button entries tu snapshot (moi dong chua "button", "role=button", "class=btn")
  BUTTONS_RAW=$(echo "$SNAPSHOT" | grep -iE 'button|role="button"|class="btn|input.*type="(submit|button)"' | head -20 || echo "")

  if [ -z "$BUTTONS_RAW" ]; then
    LOG "INFO: No CTAs found on $PAGE_URL — skip" >&2
    continue
  fi

  # Loc va gioi han 10 CTAs
  CTA_COUNT=0

  while IFS= read -r BUTTON_LINE && [ "$CTA_COUNT" -lt "$BUTTONS_PER_ROUTE" ]; do
    [ -z "$BUTTON_LINE" ] && continue

    # Extract button text tu snapshot line
    BUTTON_TEXT=$(echo "$BUTTON_LINE" | grep -oE '"[^"]{1,50}"' | head -1 | tr -d '"' || echo "")
    [ -z "$BUTTON_TEXT" ] && BUTTON_TEXT=$(echo "$BUTTON_LINE" | sed 's/<[^>]*>//g' | tr -d '[:space:]' | head -c 30 || echo "button-$CTA_COUNT")

    # Check destructive
    # v10.2: bỏ cancel/reset/clear khỏi destructive list (xem rationale dòng 184)
    IS_DESTRUCTIVE=$(echo "$BUTTON_TEXT" | grep -iE 'delete|remove|destroy|logout|sign.?out|log.?out|dang xuat|xoa' | wc -l || echo 0)
    if [ "$IS_DESTRUCTIVE" -gt 0 ]; then
      LOG "INFO: Skip destructive CTA '$BUTTON_TEXT' (BHV-002)" >&2
      continue
    fi

    CTA_COUNT=$((CTA_COUNT + 1))

    # CI-ROUTE (optional): Serena find_symbol check button has handler
    HAS_HANDLER="unknown"
    if [[ "$SERENA_AVAILABLE" == "true" ]] && [ -n "$BUTTON_TEXT" ]; then
      # Serena find_symbol(name_path_pattern="onClick") → kiem tra co handler match button text
      # (Pseudocode — orchestrator agent thuc hien):
      # HANDLER_CHECK = serena_find_symbol({name_path_pattern: "onClick", relative_path: null, include_body: false})
      # IF HANDLER_CHECK matches button_text keyword → HAS_HANDLER="true"
      HAS_HANDLER="checked_via_serena"
    fi

    # A2.3 — Capture state TRUOC click
    DOM_LEN_BEFORE=$(pw_evaluate ""document.body.innerHTML.length" 2>&1 || echo "0"
    URL_BEFORE=$(pw_evaluate ""window.location.href" 2>&1 || echo "$PAGE_URL"

    # A2.4 — Click CTA (dung ARIA/text selector tu snapshot)
    # Extract ref/selector tu snapshot line neu co, fallback: text selector
    CTA_SELECTOR=$(echo "$BUTTON_LINE" | grep -oE 'ref="[^"]+"' | head -1 || echo "")
    if [ -z "$CTA_SELECTOR" ]; then
      CTA_SELECTOR="text=\"$BUTTON_TEXT\""
    fi

    pw_click "$CTA_SELECTOR" 2>/dev/null || \
      LOG "WARN: Click failed on '$BUTTON_TEXT' — selector may not match snapshot ref" >&2

    # pw_ time=2000

    # A2.5 — Capture state SAU click (REUSE QD1 A2 :138-150)
    DOM_LEN_AFTER=$(pw_evaluate ""document.body.innerHTML.length" 2>&1 || echo "0"
    URL_AFTER=$(pw_evaluate ""window.location.href" 2>&1 || echo "$PAGE_URL"
    AFTER_SNAPSHOT=$(pw_snapshot 2>&1 || echo "")
    # v10.2 — Mở rộng selector cho Radix/headlessui/shadcn/MUI/Mantine patterns
    MODAL_COUNT=$(echo "$AFTER_SNAPSHOT" | grep -iE 'role="dialog"|role="menu"|role="tooltip"|role="listbox"|modal|popup|overlay|drawer|sheet|aria-expanded="true"|data-state="open"|data-radix-portal|data-headlessui-state="open"|data-portal|data-popper-placement|data-mantine-portal|MuiDialog|MuiDrawer|MuiMenu|MuiPopover' | wc -l || echo 0)

    # A2.6 — Compare state (REUSE QD1 A2 :139-144)
    DOM_CHANGED=$([[ "$DOM_LEN_BEFORE" != "$DOM_LEN_AFTER" ]] && echo "true" || echo "false")
    URL_CHANGED=$([[ "$URL_BEFORE" != "$URL_AFTER" ]] && echo "true" || echo "false")

    if [[ "$DOM_CHANGED" == "false" ]] && [[ "$URL_CHANGED" == "false" ]] && [ "$MODAL_COUNT" -eq 0 ]; then
      # Khong co state change — emit ui_cta_no_response (MEDIUM per _shared.md severity table)
      [ "$SIGNAL_COUNT" -ge "$MAX_SIGNALS" ] && {
        LOG "WARN: max_signals_reached ($MAX_SIGNALS) — skipping further signals" >&2
        break 2
      }

      SCREENSHOT_PATH="$RAW_DIR/screenshot-P-QD9-is-$(echo "$PAGE_URL" | md5sum | cut -c1-8)-${CTA_COUNT}.png"
      pw_screenshot "$SCREENSHOT_PATH" 2>/dev/null || \
        SCREENSHOT_PATH="null"

      emit_signal_browser "P-QD9-interactive-smoke" \
        "ui_cta_no_response" "medium" \
        "CTA khong phan ung: '$BUTTON_TEXT' tren $PAGE_URL" \
        "Sau khi click CTA '$BUTTON_TEXT' ($CTA_SELECTOR) tren $PAGE_URL va cho 2s, khong co thay doi: DOM length $DOM_LEN_BEFORE → $DOM_LEN_AFTER, URL khong doi ($URL_BEFORE), khong co modal/dialog. CTA co the bi hong hoac selector sai." \
        "$PAGE_URL" \
        "screenshot" \
        "CTA: '$BUTTON_TEXT' | selector: $CTA_SELECTOR | DOM: $DOM_LEN_BEFORE→$DOM_LEN_AFTER | URL: $URL_BEFORE→$URL_AFTER | modal: $MODAL_COUNT | has_handler: $HAS_HANDLER" \
        "\"$SCREENSHOT_PATH\""

      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      LOG "INFO: Signal emitted — ui_cta_no_response: '$BUTTON_TEXT' on $PAGE_URL" >&2
    else
      LOG "INFO: CTA '$BUTTON_TEXT' OK — state changed (DOM:$DOM_CHANGED URL:$URL_CHANGED modal:$MODAL_COUNT)" >&2
    fi

    # Navigate back ve page sau moi CTA test (tranh stuck tren modal/new page)
    CURRENT_URL=$(pw_evaluate ""window.location.href" 2>&1 || echo ""
    if [[ "$CURRENT_URL" != "$PAGE_URL" ]]; then
      pw_ --url "$PAGE_URL" --wait_until "domcontentloaded" 2>/dev/null || true
      # pw_ time=1000
    fi

  done <<< "$BUTTONS_RAW"

  # Thu them nav links cho depth traversal
  if [ "${#VISITED[@]}" -lt "$MAX_ROUTES" ]; then
    NEW_SNAP=$(pw_snapshot 2>&1 || echo "")
    NEW_LINKS=$(echo "$NEW_SNAP" | grep -oE 'href="/[^"]{1,100}"' | grep -v -E '(/_next/|/api/|/auth/|/login|/signin|/logout|/sign-out)' | head -10 || echo "")
    while IFS= read -r LINK; do
      HREF=$(echo "$LINK" | grep -oE '"[^"]+"' | tr -d '"')
      NEW_URL="$BASE_URL$HREF"
      already_queued=false
      for v in "${VISITED[@]}" "${ROUTE_QUEUE[@]}"; do [ "$v" = "$NEW_URL" ] && { already_queued=true; break; }; done
      $already_queued || ROUTE_QUEUE+=("$NEW_URL")
    done <<< "$NEW_LINKS"
  fi

done
```

---

## VERIFY

```
1. Kiem tra moi signal co dimension_id == "QD9" va probe_id == "P-QD9-interactive-smoke"
2. Kiem tra moi signal co signal_type == "ui_cta_no_response"
3. Kiem tra moi signal co severity == "medium" (hoac "critical" khi CTA trigger pageerror)
4. Kiem tra moi signal co evidence[] non-empty voi content >= 10 chars
5. Kiem tra moi signal co screenshot path (file exists hoac "null" khi capture failed)
6. Kiem tra moi signal co dedup_hints array (khong rong)
7. Kiem tra pages_visited va cta_tested duoc log trong summary.json
8. Tong signals per probe <= 50 (hoac co WARNING "max_signals_reached")
9. Dedup: khong co 2 signals voi cung (page_url + button_text) pair

Ghi summary:
  cat > "$RAW_DIR/P-QD9-interactive-smoke-summary.json" << EOF
  {
    "probe_id": "P-QD9-interactive-smoke",
    "pages_visited": N,
    "cta_tested": M,
    "cta_skipped_destructive": K,
    "signals_emitted": SIGNAL_COUNT,
    "serena_used": true/false,
    "gitnexus_used": true/false
  }
  EOF
```

---

## Severity Rules

| Dieu kien | Severity | Ly do |
|-----------|----------|-------|
| CTA click khong co state change (DOM + URL khong doi, khong co modal) | **MEDIUM** | Per `_shared.md` severity table: `ui_cta_no_response` = MEDIUM. CTA co the la display-only view hoac selector sai (khong chac chan la critical bug). |
| CTA click trigger uncaught JS exception (pageerror) | **CRITICAL** | App crash — CRITICAL per `_shared.md`. Emit `runtime_uncaught_exception` kem `ui_cta_no_response`. |
| CTA click trigger console.error() | **MEDIUM** | Emit bonus `runtime_console_error` ngoai `ui_cta_no_response`. |
| Click fail (selector khong match snapshot) | WARN log | Khong emit signal — selector issue, khong phai app bug. |

> **Rationale severity MEDIUM (khong HIGH):** QD1 A2 dung HIGH cho `ui_cta_no_response`. QD9 W1.5b ha xuong MEDIUM vi:
> (a) Probe nay click ALL buttons (broad) — ti le false positive cao hon; (b) `_shared.md` severity table canonical = MEDIUM; (c) P1 Correctness: false HIGH signal gây noise, làm dev bỏ qua.

---

## Dedup Hints

Moi signal phai co `dedup_hints` array:

| Signal Type | Dedup Hint Pattern |
|-------------|-------------------|
| `ui_cta_no_response` | `["cta-no-response:{page_url}:{button_text_first_20chars}"]` |
| `runtime_uncaught_exception` | `["uncaught:{page_url}:{message_prefix_20chars}"]` (reuse QD9 pattern) |

Cross-probe dedup: `ui_cta_no_response` tu W1.5b co the trung voi `feature_state_not_changed` tu W1.5a khi feature route bi affect. Aggregator dedup boi (probe_id, signal_type, page_url, button_text) fingerprint.

---

## Signal Schema Examples

### ui_cta_no_response

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-interactive-smoke",
  "dimension_id": "QD9",
  "signal_type": "ui_cta_no_response",
  "severity": "medium",
  "title": "CTA khong phan ung: 'Save' tren /dashboard/settings",
  "description": "Sau khi click CTA 'Save' (selector: text=\"Save\") tren /dashboard/settings va cho 2s, khong co thay doi: DOM length 45230 → 45230, URL khong doi (/dashboard/settings), khong co modal/dialog. CTA co the bi hong hoac selector sai.",
  "location": {"url": "/dashboard/settings"},
  "evidence": [
    {"type": "screenshot", "content": "/session/phase4-find-bugs/lanes/QD9-runtime-health/raw/screenshot-P-QD9-is-abc12345-1.png"},
    {"type": "log_excerpt", "content": "CTA: 'Save' | selector: text=\"Save\" | DOM: 45230→45230 | URL: same | modal: 0 | has_handler: checked_via_serena"}
  ],
  "screenshot": "/session/phase4-find-bugs/lanes/QD9-runtime-health/raw/screenshot-P-QD9-is-abc12345-1.png",
  "cdg_flags": [],
  "fixability": "agent_fix",
  "dedup_hints": ["cta-no-response:/dashboard/settings:Save"]
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile=quick hoac standard | SKIP probe, note "QD9-deep-only-interactive-smoke-skip" |
| DEV_SERVER_STATE khong co hoac failed | SKIP probe, note "skipped_dev_server_not_ready (E095 upstream)" |
| BASE_URL null | SKIP probe, note "skipped_no_base_url" |
| Homepage unreachable (NAV_ROUTES empty) | SKIP probe, note "skipped_homepage_unreachable" — khong emit signal |
| Route navigate fail (NAV_ERROR) | Skip route, log WARN, continue toi route tiep theo |
| Snapshot parse ra 0 buttons | Skip route, log INFO "no_cta_found_{url}" — continue |
| Browser click fail (selector mismatch) | Log WARN "click_failed_{button_text}" — khong emit signal (selector issue) |
| CTA la destructive (delete/remove/logout/...) | Skip click, log INFO "destructive_skip_{button_text}" (BHV-002) |
| Dom compare fail (JS eval error) | Skip state-check step, log WARN — khong emit signal |
| Serena unavailable | Skip handler check, fallback to no-handler-check — log WARN, khong block |
| GitNexus unavailable | Fallback to link-traversal only — log WARN, khong block |
| > 10 CTAs tren 1 route | Lay 10 dau tien tu DOM order (P3 economy) — log INFO "cta_capped_10_{url}" |
| > 50 signals tong | Stop emitting, log WARN "max_signals_reached" |
| CTA trigger pageerror | Emit CRITICAL "runtime_uncaught_exception" + continue CTA loop |
| AUTH_SESSION khong co | Traverse unauthenticated — some routes co the 401, bo qua CTA check tren protected routes |
| Quay lai page fail sau CTA click | Re-navigate truc tiep toi page_url — tiep tuc CTA loop |

---

## Cache Policy

**skip** — probe nay la runtime (Playwright browser execution). KHONG cache results.

Ly do: interactive smoke kiem tra *state hien tai cua CTA* — cache sai se mask broken handlers moi. Moi run phai reflect trang thai thuc cua app tai thoi diem kiem tra.

---

## Profile-Resolver Entry

```yaml
# Trong _shared/lane/profile-resolver.md (QD9 section):
P-QD9-interactive-smoke:
  quick: skip
  standard: skip
  deep: run
  exhaustive: run (extended limits: max_routes=50, max_cta_per_route=10 giu nguyen)
  parallel_class: runtime
  optional: false
  max_routes_by_profile:
    deep: 20
    exhaustive: 50
  max_cta_per_route: 10  # constant across profiles
```

---

## Acceptance Test

**Synthetic test (CI):**
1. Setup mock app tai BASE_URL voi 2 routes:
   - `/test-page-working`: button "Submit" → onClick handler → show modal
   - `/test-page-broken`: button "Save" → khong co onClick → khong co thay doi
2. Run probe voi `--profile=deep`
3. **Expected:**
   - `/test-page-working` → KHONG co signal (button co response — modal appeared)
   - `/test-page-broken` → `ui_cta_no_response` signal severity=MEDIUM trong signals.jsonl
   - `pages_visited: 2` trong summary.json
   - `cta_tested: 2` trong summary.json
4. Verify: `jq '.signal_type == "ui_cta_no_response"' RAW_DIR/P-QD9-interactive-smoke.jsonl`

**EUREKA real-world acceptance (W1.5.E2E):**
- Chay `/wf-fix-bugs --lane=QD9 --profile=deep --scope=module --name=MOD-CRM` tren EUREKA erp-web
- Expect: ≥1 route duoc kiem tra CTA
- Expect: Moi CTA khong phan ung duoc ghi trong signals.jsonl + screenshot
- Expect: lane-status.json chua probe P-QD9-interactive-smoke status="completed"
- Performance: probe complete trong ≤ 8 phut cho module scope (20 routes × max 10 CTAs × 2s wait)
