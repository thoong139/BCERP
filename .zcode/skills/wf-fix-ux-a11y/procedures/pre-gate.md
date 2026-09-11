# PRE-GATE — wf-fix-ux-a11y (QD5 Lane)

> **Reference:** `_shared/lane/pre-gate.md` (steps 1-7 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §5 (lane-status-v1)
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-ux-a11y"
DIMENSION="QD5"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y"
```

## Steps Chuẩn (1-7)

Đọc và thực hiện đầy đủ theo `_shared/lane/pre-gate.md`:

1. Verify orchestrator handoff (`SESSION_DIR`, `fix-status.json`)
2. Verify input data (registry + source dirs)
3. Verify dimension scope (QD5 trong dimensions_resolved)
4. Resolve profile → probe subset (Pattern A inline, xem `_shared/lane/profile-resolver.md` §QD5)
5. Initialize lane working dir
6. Init `lane-status.json` từ shared template
7. Init `signals.json` từ shared template

## QD5-Specific Extension Steps

### Step 8 — Detect interface_type (api-only skip)

```bash
INTERFACE_TYPE=$(jq -r '.interface_type // "web"' "$REGISTRY_PATH")
if [ "$INTERFACE_TYPE" = "api-only" ]; then
  jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.status = "completed" | .completed_at = $now | .skip_reason = "interface_type=api-only"' \
     "$LANE_DIR/lane-status.json" > "$LANE_DIR/lane-status.json.tmp" && \
     mv "$LANE_DIR/lane-status.json.tmp" "$LANE_DIR/lane-status.json"
  echo "QD5 lane bo qua (project la api-only — khong co UI de check accessibility)." > "$LANE_DIR/phase-summary.md"
  exit 0
fi
```

### Step 9 — Verify a11y tools available

```bash
AXE_CORE_AVAILABLE=$([ -f "package.json" ] && grep -q "axe-core\|@axe-core" package.json && echo true || echo false)
PLAYWRIGHT_AVAILABLE=$([ -f "package.json" ] && grep -q "@playwright/test\|playwright" package.json && echo true || echo false)

[ "$AXE_CORE_AVAILABLE" = "false" ] && echo "INFO: axe-core khong installed — P-QD5-accessibility-check se fallback static aria scan" >&2
[ "$PLAYWRIGHT_AVAILABLE" = "false" ] && echo "INFO: Playwright khong installed — P-QD5-keyboard-nav-check + P-QD5-responsive-layout se skip" >&2
```

### Step 10 — Verify --base-url cho runtime probes

```bash
if [ -z "${BASE_URL:-}" ]; then
  echo "INFO: BASE_URL khong set, runtime probes (P-QD5-accessibility-check, P-QD5-keyboard-nav-check, P-QD5-responsive-layout, P-QD5-ui-traversal-deep) se skip" >&2
fi
```

### Step 11 — Resolve probe list theo profile (QD5)

```bash
case "$PROFILE" in
  quick)
    PROBES=("P-QD5-aria-attribute-scan" "P-QD5-label-consistency")
    ;;
  standard)
    PROBES=("P-QD5-aria-attribute-scan" "P-QD5-label-consistency"
            "P-QD5-color-contrast-audit" "P-QD5-keyboard-nav-check")
    ;;
  deep)
    PROBES=("P-QD5-aria-attribute-scan" "P-QD5-label-consistency"
            "P-QD5-color-contrast-audit" "P-QD5-keyboard-nav-check"
            "P-QD5-accessibility-check" "P-QD5-responsive-layout")
    ;;
  exhaustive)
    PROBES=("P-QD5-aria-attribute-scan" "P-QD5-label-consistency"
            "P-QD5-color-contrast-audit" "P-QD5-keyboard-nav-check"
            "P-QD5-accessibility-check" "P-QD5-responsive-layout"
            "P-QD5-ui-traversal-deep")
    ;;
esac
```

## PRE-GATE Failure Handling

Theo `_shared/lane/pre-gate.md` §"PRE-GATE Failure Handling".

## Resume Behavior

Theo `_shared/lane/pre-gate.md` §"Resume Behavior".
