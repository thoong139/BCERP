# POST-GATE — wf-fix-ux-a11y (QD5 Lane)

> **Reference:** `_shared/lane/post-gate.md` (T1-T4 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §1, §5
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-ux-a11y"
DIMENSION="QD5"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y"
```

## Tier Validation Chuẩn (T1-T4)

Đọc và thực hiện đầy đủ theo `_shared/lane/post-gate.md`.

## QD5-Specific T3 Extension Rules

### T3.5 — WCAG 2.2 AA compliance signals

QD5 signals PHẢI map đúng WCAG criterion:

```bash
# axe-core signals phai co axe_violation_id trong evidence (description hoac evidence path)
AXE_NO_ID=$(jq '[.signals[] | select(.probe_id == "P-QD5-accessibility-check") | select(.description | test("axe|WCAG|2\\.\\d\\.\\d") | not)] | length' "$LANE_DIR/signals.json")
[ "$AXE_NO_ID" -le 2 ] || {
  echo "T3 WARN: $AXE_NO_ID accessibility signals thieu axe_violation_id hoac WCAG ref" >&2
}

# Color contrast signals phai co contrast_ratio numeric trong description
CONTRAST_NO_RATIO=$(jq '[.signals[] | select(.probe_id == "P-QD5-color-contrast-audit") | select(.description | test("[0-9]+(\\.[0-9]+)?:1") | not)] | length' "$LANE_DIR/signals.json")
[ "$CONTRAST_NO_RATIO" = "0" ] || {
  echo "T3 WARN: $CONTRAST_NO_RATIO contrast signals thieu ratio (vi du 4.5:1) trong description" >&2
}
```

### T3.6 — WCAG severity threshold rules

| Issue | Severity |
|-------|----------|
| Keyboard trap | HIGH |
| Contrast text < 3:1 | HIGH |
| Contrast text 3:1 - 4.5:1 (AA fail) | MEDIUM |
| Touch target < 24x24px (WCAG 2.5.8) | MEDIUM |
| Focus not visible (WCAG 2.4.7) | HIGH |
| Missing alt text on informative image | MEDIUM |
| Missing aria-label on icon button | MEDIUM |
| Inconsistent label | LOW |

```bash
# Keyboard trap signals phai severity == HIGH
KEYBOARD_TRAP_LOW=$(jq '[.signals[] | select(.description | test("keyboard.*trap|focus.*trap"; "i")) | select(.severity != "high" and .severity != "critical")] | length' "$LANE_DIR/signals.json")
[ "$KEYBOARD_TRAP_LOW" = "0" ] || {
  echo "T3 FAIL: $KEYBOARD_TRAP_LOW keyboard trap signals voi severity != high" >&2; return 1;
}
```

### T3.7 — UI element location.selector required

UI signals (axe + visual) PHẢI có `location.selector` (CSS selector):

```bash
UI_NO_SELECTOR=$(jq '[.signals[] | select(.probe_id == "P-QD5-aria-attribute-scan" or .probe_id == "P-QD5-color-contrast-audit" or .probe_id == "P-QD5-accessibility-check") | select(.location.selector == null or .location.selector == "")] | length' "$LANE_DIR/signals.json")
[ "$UI_NO_SELECTOR" -le 2 ] || {
  echo "T3 WARN: $UI_NO_SELECTOR UI signals thieu CSS selector trong location" >&2
}
```

## POST-GATE Pass Criteria

Theo `_shared/lane/post-gate.md` §"POST-GATE Pass Criteria".

## CORE-028 Phase Summary

Populate template với:

- `[DIMENSION]` = QD5, `[DIMENSION_NAME]` = "Accessibility & UX"
- `[ADVICE]` = e.g. "$a critical WCAG violations can fix de dat AA conformance"

## Failure Handling

Theo `_shared/lane/post-gate.md`. UI traversal fail (Playwright unavailable) → fallback static aria scan only.
