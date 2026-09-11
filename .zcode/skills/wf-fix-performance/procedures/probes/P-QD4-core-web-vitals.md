# P-QD4-core-web-vitals — Kiem tra Core Web Vitals (LCP/INP/CLS)

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD4-core-web-vitals |
| **Loai** | runtime (playwright) |
| **Profile** | deep, exhaustive |
| **Muc dich** | Do 3 Core Web Vitals metrics: Largest Contentful Paint (LCP), Interaction to Next Paint (INP), Cumulative Layout Shift (CLS). So sanh voi Google nguong: LCP < 2.5s, INP < 200ms, CLS < 0.1. |
| **Cache** | **skip** (runtime probe — moi lan do khac nhau) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF --base-url khong duoc cung cap (BASE_URL empty) -> SKIP, note "no_base_url"
IF playwright not available -> SKIP, note "playwright_unavailable"
IF profile=quick OR profile=standard -> SKIP (chi chay deep+)
IF --base-url khong phai la HTTP URL hop le -> SKIP, note "invalid_base_url"
```

## SENSE

### B1: Delegate to inline playwright runtime measurement (S5 v7.0)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/raw/P-QD4-core-web-vitals.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'

BASE_URL="${BASE_URL:-}"
[ -z "$BASE_URL" ] && {
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-performance","dimension":"QD4",
 "probe_id":"P-QD4-core-web-vitals","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_base_url"}
EOF
  exit 0
}

# Verify playwright CLI
if ! command -v npx &>/dev/null || ! npx playwright --version &>/dev/null 2>&1; then
  # Check with node directly
  if ! node -e "require('playwright')" 2>/dev/null; then
    cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-performance","dimension":"QD4",
 "probe_id":"P-QD4-core-web-vitals","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"playwright_unavailable"}
EOF
    exit 0
  fi
fi

RUNTIME_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/runtime"
mkdir -p "$RUNTIME_DIR"

# Launch shared browser session (playwright-session.js — xem _shared.md §0)
pw_launch || { echo "E096: browser_unavailable" >&2; exit 1; }

# Create Playwright script for CWV measurement (connects to shared browser)
CW_SCRIPT="$RUNTIME_DIR/cwv_measure.js"

cat > "$CW_SCRIPT" <<'PLAYWRIGHT_CWV'
const { chromium } = require('playwright');
const fs = require('fs');
const baseUrl = process.env.BASE_URL || 'http://localhost:3000';

(async () => {
  const state = JSON.parse(fs.readFileSync(process.env.SESSION_FILE, 'utf-8'));
  const browser = await chromium.connectOverCDP(state.wsEndpoint);
  const context = browser.contexts()[0] || await browser.newContext({
    viewport: { width: 1350, height: 940 },
    deviceScaleFactor: 1
  });
  const page = await context.newPage();

  // Collect CWV metrics
  const metrics = { lcp: 0, cls: 0, inp: 0, fcp: 0, ttfb: 0 };
  let clsEntries = [];
  let lcpEntries = [];

  // Inject web-vitals collection via PerformanceObserver
  await page.addInitScript(() => {
    // LCP observer
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      if (entries.length > 0) {
        const lastEntry = entries[entries.length - 1];
        window.__LCP = lastEntry.startTime;
        window.__LCP_ELEMENT = lastEntry.element ? (lastEntry.element.tagName + (lastEntry.element.id ? '#' + lastEntry.element.id : '')) : 'unknown';
      }
    }).observe({ type: 'largest-contentful-paint', buffered: true });

    // CLS observer
    let clsValue = 0;
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (!entry.hadRecentInput) {
          clsValue += entry.value;
          window.__CLS = clsValue;
        }
      }
    }).observe({ type: 'layout-shift', buffered: true });

    // FCP observer
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (entry.name === 'first-contentful-paint') {
          window.__FCP = entry.startTime;
        }
      }
    }).observe({ type: 'paint', buffered: true });

    // TTFB from Navigation Timing
    window.addEventListener('load', () => {
      const nav = performance.getEntriesByType('navigation')[0];
      if (nav) {
        window.__TTFB = nav.responseStart;
      }
    });
  });

  // Navigate to the page
  try {
    await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 60000 });
  } catch (e) {
    // Network idle may timeout for slow pages, that's ok
    await page.goto(baseUrl, { waitUntil: 'load', timeout: 60000 }).catch(() => {});
  }

  // Wait for LCP to settle (images may load after networkidle)
  await page.waitForTimeout(3000);

  // Read collected metrics
  metrics.lcp = await page.evaluate(() => window.__LCP || 0).catch(() => 0);
  metrics.cls = await page.evaluate(() => window.__CLS || 0).catch(() => 0);
  metrics.fcp = await page.evaluate(() => window.__FCP || 0).catch(() => 0);
  metrics.ttfb = await page.evaluate(() => window.__TTFB || 0).catch(() => 0);
  metrics.lcpElement = await page.evaluate(() => window.__LCP_ELEMENT || '').catch(() => '');

  // Measure INP by simulating interactions
  // Click on various interactive elements
  const interactiveSelectors = ['button', 'a', 'input', 'select', '[role="button"]', '[tabindex]'];
  let totalInp = 0;
  let inpCount = 0;

  for (const selector of interactiveSelectors) {
    const elements = await page.$$(selector).catch(() => []);
    for (const el of elements.slice(0, 3)) { // Test up to 3 per type
      try {
        const box = await el.boundingBox();
        if (box && box.width > 0 && box.height > 0) {
          // Measure interaction duration
          const startTime = Date.now();
          await el.click({ timeout: 5000 }).catch(() => {});
          const duration = Date.now() - startTime;
          if (duration > 0 && duration < 5000) {
            totalInp += duration;
            inpCount++;
          }
        }
      } catch (e) { /* skip non-interactable */ }
    }
  }

  metrics.inp = inpCount > 0 ? Math.round(totalInp / inpCount) : 0;
  metrics.interactions = inpCount;

  // Run a second pass: scroll down to trigger lazy images for LCP
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await page.waitForTimeout(2000);
  const lcpAfterScroll = await page.evaluate(() => window.__LCP || 0).catch(() => 0);
  if (lcpAfterScroll > metrics.lcp) {
    metrics.lcp = lcpAfterScroll;
  }

  // Final CLS reading (should include scroll-induced shifts)
  const clsAfterScroll = await page.evaluate(() => window.__CLS || 0).catch(() => 0);
  if (clsAfterScroll > metrics.cls) {
    metrics.cls = clsAfterScroll;
  }

  console.log(JSON.stringify(metrics));
  // Browser stays alive — shared session managed by playwright-session.js
})().catch(e => {
  console.error(JSON.stringify({ error: e.message }));
  process.exit(1);
});
PLAYWRIGHT_CWV

# Execute the Playwright script
BASE_URL="$BASE_URL" SESSION_FILE="$SESSION_DIR/playwright-session.json" node "$CW_SCRIPT" > "$RUNTIME_DIR/cwv_results.json" 2>"$RUNTIME_DIR/cwv_results.err" || true

# Read results
if [ -f "$RUNTIME_DIR/cwv_results.json" ] && [ -s "$RUNTIME_DIR/cwv_results.json" ]; then
  LCP=$(jq -r '.lcp // 0' "$RUNTIME_DIR/cwv_results.json" 2>/dev/null)
  CLS=$(jq -r '.cls // 0' "$RUNTIME_DIR/cwv_results.json" 2>/dev/null)
  INP=$(jq -r '.inp // 0' "$RUNTIME_DIR/cwv_results.json" 2>/dev/null)
  FCP=$(jq -r '.fcp // 0' "$RUNTIME_DIR/cwv_results.json" 2>/dev/null)
  TTFB=$(jq -r '.ttfb // 0' "$RUNTIME_DIR/cwv_results.json" 2>/dev/null)
  LCP_EL=$(jq -r '.lcpElement // ""' "$RUNTIME_DIR/cwv_results.json" 2>/dev/null)
  INTERACTIONS=$(jq -r '.interactions // 0' "$RUNTIME_DIR/cwv_results.json" 2>/dev/null)
  ERROR=$(jq -r '.error // ""' "$RUNTIME_DIR/cwv_results.json" 2>/dev/null)

  if [ -n "$ERROR" ] && [ "$ERROR" != "null" ] && [ "$ERROR" != "" ]; then
    # Script failed
    cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-performance","dimension":"QD4",
 "probe_id":"P-QD4-core-web-vitals","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"playwright_error","error":"$ERROR"}
EOF
    exit 0
  fi

  # --- Signal 1: LCP ---
  if [ "$(echo "$LCP > 0" | bc -l 2>/dev/null)" = "1" ]; then
    lcp_severity="low"
    lcp_seconds=$(echo "scale=2; $LCP / 1000" | bc -l 2>/dev/null || echo 0)
    [ "$(echo "$lcp_seconds > 4.0" | bc -l 2>/dev/null)" = "1" ] && lcp_severity="critical"
    [ "$(echo "$lcp_seconds > 2.5" | bc -l 2>/dev/null)" = "1" ] && [ "$lcp_severity" = "low" ] && lcp_severity="medium"

    fp=$(echo -n "QD4|runtime|lcp|P-QD4-core-web-vitals|lcp" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --argjson lcp "$LCP" --arg lcp_str "$(printf "%.2f" "$lcp_seconds")" \
      --arg lcp_el "$LCP_EL" --arg severity "$lcp_severity" --arg fp "$fp" \
      --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-core-web-vitals",
        probe_version: "v1.0", severity: $severity, fixability: "agent_fix", domain: "frontend",
        title: ("LCP: " + $lcp_str + "s - " + $severity),
        description: ("Largest Contentful Paint = " + $lcp_str + "s. Element: " + $lcp_el + ". Google threshold: good < 2.5s, poor > 4.0s."),
        location: {file: "runtime", line: null, column: null, selector: null, url: $BASE_URL},
        evidence: [{type: "metric", path: "runtime", description: "LCP: " + $lcp_str + "s, Element: " + $lcp_el}],
        cdg_flags: ([if $severity == "critical" then "CDG-LCP-CRITICAL" else empty end]),
        remediation: {suggested_action: "Optimize LCP: reduce server response time (TTFB), preload hero image, eliminate render-blocking resources, optimize image compression", suggested_agent: "frontend-developer", estimated_effort: "medium"},
        detected_at: $now, detected_by: "wf-fix-performance/P-QD4-core-web-vitals"
      }')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  fi

  # --- Signal 2: CLS ---
  if [ "$(echo "$CLS > 0" | bc -l 2>/dev/null)" = "1" ]; then
    cls_severity="low"
    [ "$(echo "$CLS > 0.25" | bc -l 2>/dev/null)" = "1" ] && cls_severity="critical"
    [ "$(echo "$CLS > 0.1" | bc -l 2>/dev/null)" = "1" ] && [ "$cls_severity" = "low" ] && cls_severity="high"

    fp=$(echo -n "QD4|runtime|cls|P-QD4-core-web-vitals|cls" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --argjson cls "$CLS" --arg severity "$cls_severity" --arg fp "$fp" \
      --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-core-web-vitals",
        probe_version: "v1.0", severity: $severity, fixability: "agent_fix", domain: "frontend",
        title: ("CLS: " + ($cls | tostring) + " - " + $severity),
        description: ("Cumulative Layout Shift = " + ($cls | tostring) + ". Google threshold: good < 0.1, poor > 0.25."),
        location: {file: "runtime", line: null, column: null, selector: null, url: $BASE_URL},
        evidence: [{type: "metric", path: "runtime", description: "CLS: " + ($cls | tostring)}],
        cdg_flags: ([if $severity == "critical" then "CDG-CLS-CRITICAL" else empty end]),
        remediation: {suggested_action: "Fix CLS: set explicit width/height on images and embeds, reserve space for ads/dynamic content, use transform animations instead of layout-triggering properties", suggested_agent: "frontend-developer", estimated_effort: "medium"},
        detected_at: $now, detected_by: "wf-fix-performance/P-QD4-core-web-vitals"
      }')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  fi

  # --- Signal 3: INP ---
  if [ "$INP" -gt 0 ] 2>/dev/null; then
    inp_severity="low"
    [ "$INP" -gt 500 ] && inp_severity="critical"
    [ "$INP" -gt 200 ] && [ "$inp_severity" = "low" ] && inp_severity="high"

    fp=$(echo -n "QD4|runtime|inp|P-QD4-core-web-vitals|inp" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --argjson inp "$INP" --argjson interactions "$INTERACTIONS" \
      --arg severity "$inp_severity" --arg fp "$fp" \
      --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-core-web-vitals",
        probe_version: "v1.0", severity: $severity, fixability: "agent_fix", domain: "frontend",
        title: ("INP: " + ($inp | tostring) + "ms - " + $severity),
        description: ("Interaction to Next Paint = " + ($inp | tostring) + "ms avg across " + ($interactions | tostring) + " interactions. Google threshold: good < 200ms, poor > 500ms."),
        location: {file: "runtime", line: null, column: null, selector: null, url: $BASE_URL},
        evidence: [{type: "metric", path: "runtime", description: "INP: " + ($inp | tostring) + "ms, Interactions sampled: " + ($interactions | tostring)}],
        cdg_flags: ([if $severity == "critical" then "CDG-INP-CRITICAL" else empty end]),
        remediation: {suggested_action: "Optimize INP: reduce JS main thread blocking, code-split heavy interactions, debounce event handlers, use web workers for computation", suggested_agent: "frontend-developer", estimated_effort: "medium"},
        detected_at: $now, detected_by: "wf-fix-performance/P-QD4-core-web-vitals"
      }')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  fi

  # --- Signal 4: FCP (supplemental) ---
  if [ "$(echo "$FCP > 0" | bc -l 2>/dev/null)" = "1" ]; then
    fcp_seconds=$(echo "scale=2; $FCP / 1000" | bc -l 2>/dev/null || echo 0)
    fp=$(echo -n "QD4|runtime|fcp|P-QD4-core-web-vitals|fcp" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --argjson fcp "$FCP" --arg fcp_str "$(printf "%.2f" "$fcp_seconds")" \
      --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-core-web-vitals",
        probe_version: "v1.0", severity: "info", fixability: "agent_fix", domain: "frontend",
        title: ("FCP: " + $fcp_str + "s (supplemental)"),
        description: ("First Contentful Paint = " + $fcp_str + "s. Cung cap context cho LCP optimization."),
        location: {file: "runtime", line: null, column: null, selector: null, url: $BASE_URL},
        evidence: [{type: "metric", path: "runtime", description: "FCP: " + $fcp_str + "s"}],
        cdg_flags: [], fingerprint: $fp,
        remediation: {suggested_action: "Reduce FCP: eliminate render-blocking CSS/JS, server-side render critical content, use CDN for static assets", suggested_agent: "frontend-developer", estimated_effort: "medium"},
        detected_at: $now, detected_by: "wf-fix-performance/P-QD4-core-web-vitals"
      }')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  fi
fi

# If no metrics were collected at all
if [ "$SIGNALS_JSON" = "[]" ]; then
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-performance","dimension":"QD4",
 "probe_id":"P-QD4-core-web-vitals","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_cwv_metrics_collected"}
EOF
  exit 0
fi

# Final output
jq -nc \
  --arg lane "wf-fix-performance" --arg probe "P-QD4-core-web-vitals" --arg pver "v1.0" \
  --arg profile "${PROFILE:-deep}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson signals "$SIGNALS_JSON" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD4", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now, signals: $signals}' \
  > "$RAW_OUT"
```

**Bash script handles:**
- Playwright script generation: tao file `cwv_measure.js` voi Playwright code de do CWV
- LCP measurement: inject PerformanceObserver for `largest-contentful-paint`, doc element info
- CLS measurement: track cumulative layout shifts via `PerformanceObserver({ type: 'layout-shift' })`
- INP measurement: simulate user interactions (click buttons, links, inputs, interactive elements) va do response time
- FCP measurement: First Contentful Paint tu Paint Timing API
- TTFB measurement: navigation timing `responseStart`
- Second pass scrolling: scroll to bottom de trigger lazy-loaded images -> cap nhat LCP/CLS
- Error handling: playwright scripts timeout (60s), error logging, fallback JSON
- CDG flags: LCP > 4.0s, CLS > 0.25, INP > 500ms trigger critical CDG flags

### B2: Base URL validation and page discovery

```bash
# The probe only measures the --base-url page
# For multi-page sites, the orchestrator should run this probe per page
echo "CWV measurement for: $BASE_URL"
echo "LCP threshold: 2.5s (medium), 4.0s (critical)"
echo "CLS threshold: 0.1 (high), 0.25 (critical)"
echo "INP threshold: 200ms (high), 500ms (critical)"
```

## THINK

Playwright script + inline bash logic:
1. **LCP:** Largest Contentful Paint = thoi gian render element lon nhat (hinh anh, text, video). LCP > 4.0s => user thay trang trong >4s => CRITICAL (CDG). 2.5-4.0s => MEDIUM.
2. **CLS:** Cumulative Layout Shift = do di chuyen layout khong mong muon. CLS > 0.25 => trai nghiem xau (noi dung nhay loan) => CRITICAL (CDG). 0.1-0.25 => HIGH.
3. **INP:** Interaction to Next Paint = do tre khi tuong tac. INP > 500ms => CRITICAL (CDG). 200-500ms => HIGH.
4. **FCP:** First Contentful Paint = supplemental metric. Cung cap context, khong co severity rieng.
5. **Interaction simulation:** Playwright tu dong tim button, a, input, select, role="button" elements va click de do INP. Moi selector type test toi da 3 elements.
6. **Scroll pass:** Scroll to bottom de trigger lazy images (improves LCP accuracy) va capture scroll-induced layout shifts (improves CLS accuracy).
7. **Domain:** `frontend`
8. **Fixability:** `agent_fix` (frontend-developer)

## ACT

Output schema `signal-v2`:
- LCP: `title: "LCP: X.XXs - severity"`, `description` includes target element tag, `remediation: "Optimize LCP: reduce TTFB, preload hero image, eliminate render-blocking resources"`
- CLS: `title: "CLS: X.XXXX - severity"`, `remediation: "Set explicit width/height, reserve space for dynamic content"`
- INP: `title: "INP: Xms - severity"`, `description` includes interaction count, `remediation: "Reduce main thread blocking, code-split, use web workers"`
- FCP: `title: "FCP: X.XXs (supplemental)"`, severity=info, `remediation: "Reduce render-blocking resources, SSR critical content"`

All signals have `severity` = critical (CDG flagged) | high | medium | info.

## VERIFY

1. Moi Signal co `dimension_id == "QD4"`
2. Moi signal co `evidence[]` voi metric values
3. LCP signal co lcp_str va lcp_element trong description
4. CLS signal co numeric CLS value trong evidence
5. INP signal co inp_ms va interactions count trong evidence
6. Severity trong [CRITICAL, HIGH, MEDIUM, INFO] (nguong Google)
7. Critical signals co `cdg_flags` populated
8. Remediation present va specific cho tung metric

## Severity Rules

| Pattern | Severity |
|---------|----------|
| LCP > 4.0s | CRITICAL (CDG-LCP-CRITICAL) |
| CLS > 0.25 | CRITICAL (CDG-CLS-CRITICAL) |
| INP > 500ms | CRITICAL (CDG-INP-CRITICAL) |
| CLS 0.1-0.25 | HIGH |
| INP 200-500ms | HIGH |
| LCP 2.5-4.0s | MEDIUM |
| FCP (supplemental) | INFO |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| --base-url khong co | Skip probe, note "no_base_url" |
| playwright khong installed | Skip probe, note "playwright_unavailable" |
| Page load timeout >60s | Emit timeout note, skip metric collection |
| Playwright crash / Node error | Doc error tu stderr, emit empty signals voi error message |
| LCP = 0 (khong co Paint timing) | Note "lcp_not_measured", van co the emit CLS/INP neu co |
| CLS = 0 (khong co layout shift) | Note "cls_zero", khong emit CLS signal (normal) |
| Khong tim thay interactive elements (INP = 0) | Note "inp_no_interactive_elements", skip INP signal |
| Cross-platform bc unavailable | Fallback integer comparison, note "no_bc_loss_precision" |
| URL khong phai HTTP | Skip probe, note "invalid_base_url" |
