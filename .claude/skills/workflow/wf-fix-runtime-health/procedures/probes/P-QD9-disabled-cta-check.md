# P-QD9-disabled-cta-check — Disabled/Obstructed CTA Detection (v10.2 NEW)

> **Type:** runtime (Playwright bash-level) | **Profile:** standard, deep, exhaustive | **Cache:** skip (always runtime)
> **Parallel class:** runtime → sequential (browser session; chay sau P-QD9-interactive-smoke)
> **Signal types:** `ui_cta_disabled_unexpected` (MEDIUM), `ui_cta_obstructed` (HIGH)
> **Error codes:** E096 (browser launch fail)
> **v10.2 NEW** — Phát hiện chính xác bug "feature có nhưng button không click được": disabled prop, pointer-events:none, opacity:0, overlay che.

## Rationale

User báo "feature đã có nhưng không click được" thường có root cause:

| Root cause | Detect by |
|------------|-----------|
| Button `disabled={!isValid}` luôn true | `getAttribute('disabled') !== null` |
| `aria-disabled="true"` (custom disabled) | `getAttribute('aria-disabled') === "true"` |
| `pointer-events: none` (CSS hidden click) | `getComputedStyle(el).pointerEvents === "none"` |
| `opacity: 0` hoặc gần 0 | `parseFloat(getComputedStyle(el).opacity) < 0.3` |
| `display: none` / `visibility: hidden` | `getComputedStyle(el).display === "none"` etc |
| Overlay loading/spinner che button | `document.elementFromPoint(rect.x+w/2, rect.y+h/2) !== el` |
| `<fieldset disabled>` ancestor | `el.closest('fieldset:disabled, [disabled], [aria-disabled="true"]')` |

→ Probe này dò TẤT CẢ buttons trên trang, lọc ra cái có handler nhưng bị block.

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Locate button source file | **Serena** `find_symbol("<button-text>")` | Grep | Để populate `location.file` trong signal |
| Find handler reference | **Serena** `find_symbol("onClick")` + grep button text | Grep | Confirm button có handler |

## PRE-GATE

```
1. IF profile=quick: SKIP probe, note "QD9-quick-skip-disabled-cta"

2. IF --no-browser: SKIP (lane đã skip)

3. IF DEV_SERVER_STATE.status != "ready": SKIP với note "skipped_dev_server_not_ready"

4. Per-profile caps:
     standard)   MAX_ROUTES=10; MAX_BUTTONS=30 ;;   # 30 buttons / route (full enumeration)
     deep)       MAX_ROUTES=25; MAX_BUTTONS=50 ;;
     exhaustive) MAX_ROUTES=50; MAX_BUTTONS=80 ;;
   MAX_SIGNALS_PER_ROUTE=10

5. Load BASE_URL, AUTH_SESSION (reuse như P-QD9-interactive-smoke)

6. Load CI availability — fallback Grep nếu thiếu Serena/GitNexus
```

## SENSE — Build route list

REUSE B1/B2/B3 từ `P-QD9-interactive-smoke.md` (navigate homepage → snapshot → NAV_LINKS[] → exclude logout/api → build NAV_ROUTES queue).

## THINK — Strategy

KHÔNG click button — chỉ **dò trạng thái** qua DOM/CSS. An toàn hoàn toàn (read-only).

Severity logic:

| Condition | Severity | Signal type |
|-----------|----------|-------------|
| Button có handler nhưng `disabled` luôn true (no relevant form state) | MEDIUM | `ui_cta_disabled_unexpected` |
| Button bị overlay che (elementFromPoint khác button) | HIGH | `ui_cta_obstructed` |
| Button `pointer-events:none` không có CSS rule giải thích | MEDIUM | `ui_cta_disabled_unexpected` |
| Button `opacity:0` hoặc `display:none` nhưng có handler | LOW (info) | `ui_cta_hidden_with_handler` |

**Loại trừ:**
- Button có `aria-label`/`aria-description`/textContent chứa: "loading", "saving", "wait", "đang xử lý", "vui lòng đợi" → expected disabled state, skip
- Button trong `<form>` chưa được điền (validate state) → skip nếu có sibling input `:invalid`

## ACT

```bash
pw_launch || { echo "E096: browser_unavailable" >&2; exit 1; }
trap "pw_close" EXIT

VISITED=()
ROUTE_QUEUE=("$BASE_URL/")
for route in "${NAV_ROUTES[@]}"; do
  ROUTE_QUEUE+=("$BASE_URL$route")
done

for PAGE_URL in "${ROUTE_QUEUE[@]:0:$MAX_ROUTES}"; do
  pw_navigate "$PAGE_URL" "domcontentloaded" >/dev/null 2>&1 || continue
  pw_wait "1500" >/dev/null 2>&1 || true

  # v10.2 — Inject probe script tìm disabled/obstructed CTAs trong DOM
  DISABLED_BUTTONS_JSON=$(pw_evaluate '
    (function() {
      const results = [];
      const exclude_re = /loading|saving|wait|đang xử lý|vui lòng đợi|please wait|processing/i;
      const buttons = document.querySelectorAll("button, [role=\"button\"], input[type=\"submit\"], input[type=\"button\"], .btn");

      for (const btn of Array.from(buttons).slice(0, '"$MAX_BUTTONS"')) {
        const text = (btn.textContent || btn.value || btn.getAttribute("aria-label") || "").trim().substring(0, 50);
        if (!text || exclude_re.test(text)) continue;

        const cs = getComputedStyle(btn);
        const rect = btn.getBoundingClientRect();
        if (rect.width === 0 || rect.height === 0) continue;  // not visible at all

        const hasHandler = btn.onclick !== null || btn.hasAttribute("onclick") ||
                           btn.closest("a[href]") !== null ||
                           btn.type === "submit";

        const issues = [];

        // Check 1: disabled attribute
        if (btn.hasAttribute("disabled") || btn.getAttribute("aria-disabled") === "true") {
          // Skip nếu có form invalid sibling (legitimate disabled)
          const form = btn.closest("form");
          const hasInvalidInput = form && form.querySelector("input:invalid, select:invalid, textarea:invalid");
          if (!hasInvalidInput && hasHandler) {
            issues.push({type: "disabled_always", severity: "medium"});
          }
        }

        // Check 2: pointer-events:none
        if (cs.pointerEvents === "none" && hasHandler) {
          issues.push({type: "pointer_events_none", severity: "medium"});
        }

        // Check 3: opacity very low + handler
        const opacity = parseFloat(cs.opacity);
        if (opacity < 0.3 && opacity > 0 && hasHandler) {
          issues.push({type: "near_invisible", severity: "low"});
        }

        // Check 4: obstruction via elementFromPoint
        const cx = Math.floor(rect.left + rect.width / 2);
        const cy = Math.floor(rect.top + rect.height / 2);
        if (cx >= 0 && cy >= 0 && cx < window.innerWidth && cy < window.innerHeight) {
          const topEl = document.elementFromPoint(cx, cy);
          if (topEl && topEl !== btn && !btn.contains(topEl) && !topEl.contains(btn)) {
            // Overlay/spinner đang che — HIGH severity
            issues.push({
              type: "obstructed",
              severity: "high",
              top_el: topEl.tagName + (topEl.className ? "." + topEl.className.substring(0, 30) : "")
            });
          }
        }

        // Check 5: fieldset ancestor disabled
        if (btn.closest("fieldset:disabled") && hasHandler) {
          issues.push({type: "fieldset_disabled", severity: "medium"});
        }

        if (issues.length > 0) {
          results.push({
            text,
            tag: btn.tagName,
            id: btn.id || null,
            className: (btn.className || "").substring(0, 80),
            issues
          });
        }
      }
      return JSON.stringify(results.slice(0, '"$MAX_SIGNALS_PER_ROUTE"'));
    })()
  ' 2>/dev/null | jq -r '.result // "[]"')

  # Parse và emit signals
  if [ -n "$DISABLED_BUTTONS_JSON" ] && [ "$DISABLED_BUTTONS_JSON" != "[]" ]; then
    echo "$DISABLED_BUTTONS_JSON" | jq -c '.[]' 2>/dev/null | while IFS= read -r btn; do
      BTEXT=$(echo "$btn" | jq -r '.text')
      BCLASS=$(echo "$btn" | jq -r '.className')
      echo "$btn" | jq -c '.issues[]' | while IFS= read -r issue; do
        ITYPE=$(echo "$issue" | jq -r '.type')
        ISEV=$(echo "$issue" | jq -r '.severity')

        case "$ITYPE" in
          obstructed)
            STYPE="ui_cta_obstructed"
            TOP_EL=$(echo "$issue" | jq -r '.top_el // "unknown"')
            TITLE="CTA bị che: '$BTEXT' trên $PAGE_URL"
            DESC="Button '$BTEXT' (class='$BCLASS') không click được vì overlay đang che. elementFromPoint trả về: $TOP_EL — không phải button. Có thể là loading spinner, modal backdrop, hoặc z-index conflict."
            ;;
          disabled_always|fieldset_disabled)
            STYPE="ui_cta_disabled_unexpected"
            TITLE="CTA disabled bất thường: '$BTEXT' trên $PAGE_URL"
            DESC="Button '$BTEXT' (class='$BCLASS') có handler nhưng bị disabled. Loại: $ITYPE. Form không có input invalid → có thể bug logic state."
            ;;
          pointer_events_none)
            STYPE="ui_cta_disabled_unexpected"
            TITLE="CTA pointer-events:none bất thường: '$BTEXT'"
            DESC="Button '$BTEXT' (class='$BCLASS') có handler nhưng CSS pointer-events:none → click không hoạt động."
            ;;
          near_invisible)
            STYPE="ui_cta_hidden_with_handler"
            TITLE="CTA gần như vô hình: '$BTEXT'"
            DESC="Button '$BTEXT' (class='$BCLASS') có opacity rất thấp — có handler nhưng user khó thấy/click."
            ;;
        esac

        emit_signal_browser "P-QD9-disabled-cta-check" \
          "$STYPE" "$ISEV" "$TITLE" "$DESC" "$PAGE_URL" \
          "dom_snapshot" "$btn" "null"
      done
    done
  fi
done
```

## VERIFY

```bash
# Check ít nhất 1 signal được emit hoặc đã skip với lý do
test -f "$RAW_DIR/P-QD9-disabled-cta-check.jsonl" && echo "OK: signals or empty raw file"
```

## Severity Quick Reference

| Signal Type | Severity | Fixability |
|-------------|----------|------------|
| `ui_cta_obstructed` | HIGH | agent_fix (z-index/overlay state) |
| `ui_cta_disabled_unexpected` (disabled_always, pointer_events_none, fieldset_disabled) | MEDIUM | agent_fix (state logic) |
| `ui_cta_hidden_with_handler` (near_invisible) | LOW | batch fix |

## CDG Flags

KHÔNG có CDG flags đặc biệt cho probe này. False-positive risk MEDIUM — user có thể intentionally disable button (e.g., loading state). Triage sẽ classify thêm.

## Output

Append vào `$RAW_DIR/P-QD9-disabled-cta-check.jsonl`. Probe completion marker:
```bash
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TMP="$RAW_DIR/P-QD9-disabled-cta-check.json.tmp.$$"
jq -s '. + [{completed_at: "'"$TS"'", probe_complete: true}]' \
  "$RAW_DIR/P-QD9-disabled-cta-check.jsonl" > "$TMP"
jq '.' "$TMP" >/dev/null && mv "$TMP" "$RAW_DIR/P-QD9-disabled-cta-check.json"
```

## Resume support

Trước khi chạy: check `raw/P-QD9-disabled-cta-check.json` có `probe_complete: true` → SKIP nếu đã xong.

## Reuses from

| Aspect | Source | Notes |
|--------|--------|-------|
| Navigation graph (B1/B2/B3) | `P-QD9-interactive-smoke.md` | Same algorithm — reuse exclusion list |
| Browser launch + close | `procedures/probes/_shared.md` | `pw_launch` / `pw_close` |
| Auth cookie inject | `P-QD9-auth-aware-smoke.md` PRE-GATE | Inject vào protected routes |
| `emit_signal_browser` | `procedures/probes/_shared.md` | signal-v2 schema |
