# POST-GATE — wf-fix-compat (QD7 Lane)

> **Reference:** `_shared/lane/post-gate.md` (T1-T4 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §1, §5
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-compat"
DIMENSION="QD7"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat"
```

## Tier Validation Chuẩn (T1-T4)

Đọc và thực hiện đầy đủ theo `_shared/lane/post-gate.md`.

## QD7-Specific T3 Extension Rules

### T3.5 — Browser identity required cho runtime probes

Runtime probe signals PHẢI có browser identification trong description hoặc evidence:

```bash
# Browser compat signals phai mention chromium/firefox/webkit
BROWSER_NO_ID=$(jq '[.signals[] | select(.probe_id == "P-QD7-browser-compat-check") | select(.description | test("chromium|firefox|webkit|safari|edge"; "i") | not)] | length' "$LANE_DIR/signals.json")
[ "$BROWSER_NO_ID" = "0" ] || {
  echo "T3 WARN: $BROWSER_NO_ID browser-compat signals thieu browser identifier" >&2
}

# Device breakpoint signals phai mention viewport hoac breakpoint name
VIEWPORT_NO_DIM=$(jq '[.signals[] | select(.probe_id == "P-QD7-device-breakpoint-test") | select(.description | test("[0-9]+(px|x[0-9]+)|mobile|tablet|laptop|desktop"; "i") | not)] | length' "$LANE_DIR/signals.json")
[ "$VIEWPORT_NO_DIM" = "0" ] || {
  echo "T3 WARN: $VIEWPORT_NO_DIM viewport signals thieu dimension/breakpoint info" >&2
}
```

### T3.6 — Severity threshold rules

| Issue | Severity |
|-------|----------|
| Layout vỡ trên mobile (CLS > 0.25) | HIGH |
| Firefox/WebKit feature crash | HIGH |
| Required env var missing | HIGH |
| Optional env var missing | MEDIUM |
| Hard-coded locale/date format | MEDIUM |
| Deprecated API ( still working) | MEDIUM |
| Polyfill missing for IE11 | LOW (modern apps) hoặc MEDIUM (legacy support) |

```bash
# Layout vỡ tren mobile signals phai severity HIGH minimum
MOBILE_BREAK_LOW=$(jq '[.signals[] | select(.description | test("mobile.*broke|CLS|layout.*shift"; "i")) | select(.severity == "low")] | length' "$LANE_DIR/signals.json")
[ "$MOBILE_BREAK_LOW" = "0" ] || {
  echo "T3 WARN: $MOBILE_BREAK_LOW mobile-layout signals voi severity == low (should be MEDIUM+)" >&2
}
```

### T3.7 — Env var parity check

P-QD7-deprecated-api-usage và env var parity issues PHẢI reference file path:

```bash
ENV_NO_FILE=$(jq '[.signals[] | select(.description | test("env.*missing|env var"; "i")) | select(.location.file == null or .location.file == "")] | length' "$LANE_DIR/signals.json")
[ "$ENV_NO_FILE" = "0" ] || {
  echo "T3 WARN: $ENV_NO_FILE env-var signals thieu file path (.env.example or .env.local)" >&2
}
```

### T3.8 — Browser compat matrix coverage (deep+)

```bash
if [ "$PROFILE" = "deep" ] || [ "$PROFILE" = "exhaustive" ]; then
  # Deep+ phai test it nhat 3 browsers (Chromium + Firefox + WebKit)
  BROWSERS_TESTED=$(jq -r '[.signals[] | select(.probe_id == "P-QD7-browser-compat-check") | .description | scan("chromium|firefox|webkit|safari|edge"; "ig") | ascii_downcase] | unique | length' "$LANE_DIR/signals.json")
  [ "$BROWSERS_TESTED" -ge 2 ] || {
    echo "T3 WARN: deep profile chi test $BROWSERS_TESTED browser (yeu cau >=2)" >&2
  }
fi
```

## POST-GATE Pass Criteria

Theo `_shared/lane/post-gate.md` §"POST-GATE Pass Criteria".

## CORE-028 Phase Summary

Populate template với:

- `[DIMENSION]` = QD7, `[DIMENSION_NAME]` = "Compatibility & Portability"
- `[ADVICE]` = e.g. "$a browser-specific issues — uu tien fix Firefox/WebKit truoc release"

## Failure Handling

Theo `_shared/lane/post-gate.md`. Playwright unavailable → fallback static check, mark probe `skipped`.
