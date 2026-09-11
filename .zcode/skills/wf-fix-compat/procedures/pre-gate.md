# PRE-GATE — wf-fix-compat (QD7 Lane)

> **Reference:** `_shared/lane/pre-gate.md` (steps 1-7 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §5 (lane-status-v1)
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-compat"
DIMENSION="QD7"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat"
```

## Steps Chuẩn (1-7)

Đọc và thực hiện đầy đủ theo `_shared/lane/pre-gate.md`:

1. Verify orchestrator handoff (`SESSION_DIR`, `fix-status.json`)
2. Verify input data (registry + source dirs)
3. Verify dimension scope (QD7 trong dimensions_resolved)
4. Resolve profile → probe subset (Pattern A inline, xem `_shared/lane/profile-resolver.md` §QD7)
5. Initialize lane working dir
6. Init `lane-status.json` từ shared template
7. Init `signals.json` từ shared template

## QD7-Specific Extension Steps

### Step 8 — Detect interface_type

```bash
INTERFACE_TYPE=$(jq -r '.interface_type // "web"' "$REGISTRY_PATH")
if [ "$INTERFACE_TYPE" = "api-only" ]; then
  echo "INFO: Project la api-only — P-QD7-browser-compat-check + P-QD7-device-breakpoint-test + P-QD7-polyfill-coverage se skip" >&2
fi
```

### Step 9 — Verify Playwright cho multi-browser tests

```bash
PLAYWRIGHT_AVAILABLE=$([ -f "package.json" ] && grep -q "@playwright/test\|playwright" package.json && echo true || echo false)
if [ "$PLAYWRIGHT_AVAILABLE" = "false" ]; then
  echo "INFO: Playwright khong installed — P-QD7-browser-compat-check + P-QD7-device-breakpoint-test se fallback static check" >&2
fi
```

### Step 10 — Verify env files cho parity check

```bash
# P-QD7 family check env var parity
ENV_FILES_FOUND=$(ls .env.example .env.local .env.development .env.production 2>/dev/null | head -1)
if [ -z "$ENV_FILES_FOUND" ]; then
  echo "INFO: Khong tim thay .env files — env var parity check skip" >&2
fi
```

### Step 11 — Verify --base-url cho runtime probes

```bash
if [ -z "${BASE_URL:-}" ]; then
  echo "INFO: BASE_URL khong set, runtime probes (P-QD7-browser-compat-check, P-QD7-device-breakpoint-test) se skip" >&2
fi
```

### Step 12 — Resolve probe list theo profile (QD7)

```bash
case "$PROFILE" in
  quick)
    PROBES=("P-QD7-deprecated-api-usage")
    ;;
  standard)
    PROBES=("P-QD7-deprecated-api-usage" "P-QD7-api-version-compat"
            "P-QD7-browser-compat-check")
    ;;
  deep)
    PROBES=("P-QD7-deprecated-api-usage" "P-QD7-api-version-compat"
            "P-QD7-browser-compat-check" "P-QD7-polyfill-coverage")
    ;;
  exhaustive)
    PROBES=("P-QD7-deprecated-api-usage" "P-QD7-api-version-compat"
            "P-QD7-browser-compat-check" "P-QD7-polyfill-coverage"
            "P-QD7-device-breakpoint-test")
    ;;
esac
```

## PRE-GATE Failure Handling

Theo `_shared/lane/pre-gate.md` §"PRE-GATE Failure Handling".

## Resume Behavior

Theo `_shared/lane/pre-gate.md` §"Resume Behavior".
