# PRE-GATE — wf-fix-performance (QD4 Lane)

> **Reference:** `_shared/lane/pre-gate.md` (steps 1-7 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §5 (lane-status-v1)
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-performance"
DIMENSION="QD4"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance"
```

## Steps Chuẩn (1-7)

Đọc và thực hiện đầy đủ theo `_shared/lane/pre-gate.md`:

1. Verify orchestrator handoff (`SESSION_DIR`, `fix-status.json`)
2. Verify input data (registry + source dirs)
3. Verify dimension scope (QD4 trong dimensions_resolved)
4. Resolve profile → probe subset (Pattern A inline, xem `_shared/lane/profile-resolver.md` §QD4)
5. Initialize lane working dir
6. Init `lane-status.json` từ shared template
7. Init `signals.json` từ shared template

## QD4-Specific Extension Steps

### Step 8 — Verify perf tools available

```bash
LIGHTHOUSE_AVAILABLE=$(command -v lighthouse > /dev/null 2>&1 && echo true || echo false)
K6_AVAILABLE=$(command -v k6 > /dev/null 2>&1 && echo true || echo false)
BUNDLE_ANALYZER_AVAILABLE=$([ -f "package.json" ] && grep -q "webpack-bundle-analyzer\|vite-bundle-visualizer" package.json && echo true || echo false)

[ "$LIGHTHOUSE_AVAILABLE" = "false" ] && echo "INFO: Lighthouse CLI khong cai dat — P-QD4-core-web-vitals + P-QD4-render-perf-check se fallback static check" >&2
[ "$K6_AVAILABLE" = "false" ] && echo "INFO: k6 khong cai dat — P-QD4-api-latency-probe se dung curl loop fallback" >&2
[ "$BUNDLE_ANALYZER_AVAILABLE" = "false" ] && echo "INFO: bundle analyzer khong configured — P-QD4-bundle-size-audit se dung du size estimation" >&2
```

### Step 9 — Verify --base-url cho runtime probes

```bash
if [ -z "${BASE_URL:-}" ]; then
  echo "INFO: BASE_URL khong set, runtime probes (P-QD4-render-perf-check, P-QD4-api-latency-probe, P-QD4-core-web-vitals) se skip" >&2
fi
```

### Step 10 — Resolve probe list theo profile (QD4)

```bash
case "$PROFILE" in
  quick)
    PROBES=("P-QD4-bundle-size-audit")
    ;;
  standard)
    PROBES=("P-QD4-bundle-size-audit" "P-QD4-render-perf-check"
            "P-QD4-api-latency-probe" "P-QD4-db-query-analysis")
    ;;
  deep)
    PROBES=("P-QD4-bundle-size-audit" "P-QD4-render-perf-check"
            "P-QD4-api-latency-probe" "P-QD4-db-query-analysis"
            "P-QD4-core-web-vitals")
    ;;
  exhaustive)
    PROBES=("P-QD4-bundle-size-audit" "P-QD4-render-perf-check"
            "P-QD4-api-latency-probe" "P-QD4-db-query-analysis"
            "P-QD4-core-web-vitals" "P-QD4-memory-leak-scan")
    ;;
esac
```

## PRE-GATE Failure Handling

Theo `_shared/lane/pre-gate.md` §"PRE-GATE Failure Handling".

## Resume Behavior

Theo `_shared/lane/pre-gate.md` §"Resume Behavior".
