# P-QD5-responsive-layout — Responsive Layout Test

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD5-responsive-layout |
| **Loai** | runtime |
| **Profile** | deep, exhaustive |
| **Muc dich** | Test responsive layout across 4 viewport breakpoints: mobile (320px), tablet (768px), desktop (1024px), wide (1440px). Phat hien horizontal overflow, overlapping elements, touch target size issues, unreadable font sizes. |
| **Cache** | skip (runtime probe) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co BASE_URL va khong co Playwright MCP -> SKIP, note "no_responsive_test_tooling"
IF profile=standard: SKIP probe (chi deep/exhaustive)
IF khong co frontend source dir -> SKIP
```

## SENSE

### B1: Static pre-check — grep for non-responsive patterns

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/raw/P-QD5-responsive-layout.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'
SOURCE="${SOURCE_DIR:-src/}"

# Static Check: Fixed pixel widths for containers (often breaks at mobile)
grep -rnE '(width\s*:\s*(6[4-9][0-9]|[7-9][0-9]{2}|[1-9][0-9]{3,})px|min-width\s*:\s*(6[4-9][0-9]|[7-9][0-9]{2}|[1-9][0-9]{3,})px|max-width\s*:\s*(6[4-9][0-9]|[7-9][0-9]{2}|[1-9][0-9]{3,})px)' "$SOURCE" \
  --include='*.css' --include='*.scss' --include='*.tsx' --include='*.jsx' \
  2>/dev/null | grep -vE '(node_modules|\.test\.|\.spec\.|viewport|breakpoint|media)' | head -20 | \
while IFS=: read -r file line match; do
  fp=$(echo -n "QD5|$file|$line|P-QD5-responsive-layout|fixed_width" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc --arg file "$file" --argjson line "$line" --arg snip "${match:0:100}" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-responsive-layout",severity:"medium",fixability:"agent_fix",domain:"ux",
      title:"Large fixed pixel width may break responsive layout", description:("Fixed width > 640px tai "+$file+":"+($line|tostring)+". May cause horizontal overflow on mobile devices."),
      location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:$snip}],
      cdg_flags:[],fingerprint:$fp,
      remediation:{suggested_action:"Replace fixed pixel width voi responsive units (%, vw, min/max) hoac add media query breakpoint.",suggested_agent:"frontend-developer",estimated_effort:"low"},
      detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-responsive-layout"}')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done
```

### B2: Runtime — Playwright multi-viewport test

```bash
if [ -n "${BASE_URL:-}" ]; then
  RESP_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/runtime"
  mkdir -p "$RESP_DIR"
  
  # Launch shared browser session (playwright-session.js — xem _shared.md §0)
  pw_launch || { echo "E096: browser_unavailable" >&2; exit 1; }
  
  cat > "$RESP_DIR/responsive-test.js" <<'RESP_SCRIPT'
const { chromium } = require('playwright');
const fs = require('fs');
const baseUrl = process.env.BASE_URL;

const VIEWPORTS = [
  { name: 'mobile', width: 320, height: 568 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1024, height: 768 },
  { name: 'wide', width: 1440, height: 900 }
];

(async () => {
  const state = JSON.parse(fs.readFileSync(process.env.SESSION_FILE, 'utf-8'));
  const browser = await chromium.connectOverCDP(state.wsEndpoint);
  const results = { viewports: {}, summary: { overflowDetected: false, issues: [] } };
  
  for (const vp of VIEWPORTS) {
    const context = await browser.newContext({ viewport: vp });
    const page = await context.newPage();
    const vpResult = { name: vp.name, width: vp.width, height: vp.height, issues: [] };
    
    try {
      await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 30000 });
      await page.waitForTimeout(1000);
      
      // Check horizontal overflow
      const overflow = await page.evaluate(() => {
        const docWidth = document.documentElement.scrollWidth;
        const viewportWidth = window.innerWidth;
        const bodyWidth = document.body.scrollWidth;
        const hasHorizontalOverflow = docWidth > viewportWidth + 5; // 5px tolerance
        
        // Find elements causing overflow
        const offenders = [];
        document.querySelectorAll('*').forEach(el => {
          const rect = el.getBoundingClientRect();
          if (rect.width > viewportWidth + 20) {
            const tag = el.tagName.toLowerCase();
            const cls = el.className?.toString?.().substring(0, 50) || '';
            offenders.push({ tag, cls, width: Math.round(rect.width) });
          }
        });
        
        return { hasHorizontalOverflow, docWidth, viewportWidth, offenders: offenders.slice(0, 5) };
      });
      
      if (overflow.hasHorizontalOverflow) {
        results.summary.overflowDetected = true;
        vpResult.issues.push({
          type: 'horizontal_overflow',
          severity: 'high',
          description: `Viewport ${vp.width}px: document width ${overflow.docWidth}px exceeds viewport ${overflow.viewportWidth}px`,
          offenders: overflow.offenders
        });
      }
      
      // Check touch target sizes (min 44x44px for WCAG 2.5.5)
      const touchTargets = await page.evaluate(() => {
        const small = [];
        document.querySelectorAll('button, a, [role="button"], input[type="submit"]').forEach(el => {
          const rect = el.getBoundingClientRect();
          if (rect.width > 0 && rect.height > 0 && (rect.width < 44 || rect.height < 44)) {
            small.push({
              tag: el.tagName.toLowerCase(),
              text: el.textContent?.trim().substring(0, 40) || '',
              width: Math.round(rect.width),
              height: Math.round(rect.height)
            });
          }
        });
        return small.slice(0, 10);
      });
      
      if (touchTargets.length > 0) {
        vpResult.issues.push({ type: 'small_touch_targets', severity: 'medium', targets: touchTargets });
      }
      
      // Check minimum font size readability
      const smallFonts = await page.evaluate(() => {
        const small = [];
        document.querySelectorAll('p, span, a, li, td, div').forEach(el => {
          const style = window.getComputedStyle(el);
          const fontSize = parseFloat(style.fontSize);
          if (fontSize > 0 && fontSize < 12 && el.textContent?.trim().length > 10) {
            small.push({
              tag: el.tagName.toLowerCase(),
              text: el.textContent.trim().substring(0, 60),
              fontSize: fontSize + 'px'
            });
          }
        });
        return small.slice(0, 10);
      });
      
      if (smallFonts.length > 0) {
        vpResult.issues.push({ type: 'small_font_size', severity: 'medium', elements: smallFonts });
      }
      
    } catch (e) {
      vpResult.issues.push({ type: 'navigation_error', severity: 'error', error: e.message });
    }
    
    results.viewports[vp.name] = vpResult;
    await context.close();
  }
  
  console.log(JSON.stringify(results));
  // Browser stays alive — shared session managed by playwright-session.js
})().catch(e => { console.error(e); process.exit(1); });
RESP_SCRIPT

  if command -v npx &>/dev/null && npx playwright --version &>/dev/null 2>&1; then
    SESSION_FILE="$SESSION_DIR/playwright-session.json" BASE_URL="$BASE_URL" node "$RESP_DIR/responsive-test.js" > "$RESP_DIR/resp-results.json" 2>/dev/null || true
    
    if [ -f "$RESP_DIR/resp-results.json" ]; then
      # Emit per-viewport per-issue signals
      for vp_name in mobile tablet desktop wide; do
        VP_ISSUES=$(jq -c --arg vp "$vp_name" '.viewports[$vp].issues[]?' "$RESP_DIR/resp-results.json" 2>/dev/null || echo "")
        
        while IFS= read -r issue; do
          [ -z "$issue" ] && continue
          issue_type=$(echo "$issue" | jq -r '.type')
          issue_sev=$(echo "$issue" | jq -r '.severity')
          
          if [ "$issue_type" = "horizontal_overflow" ]; then
            offenders_count=$(echo "$issue" | jq '.offenders | length' 2>/dev/null || echo 0)
            fp=$(echo -n "QD5|$vp_name|overflow|P-QD5-responsive-layout" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
            sig=$(jq -nc \
              --arg vp "$vp_name" --argjson count "$offenders_count" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-responsive-layout",severity:"high",fixability:"agent_fix",domain:"ux",
                title:("Horizontal overflow at "+$vp+" viewport"), description:("Page has horizontal scrollbar at "+$vp+" ("+($count|tostring)+" overflowing elements). Users must scroll horizontally to see content."),
                location:{file:"runtime",line:null,url:null}, evidence:[{type:"metric",path:"runtime",description:"Overflow at "+$vp+": "+($count|tostring)+" offenders"}],
                cdg_flags:[],fingerprint:$fp,
                remediation:{suggested_action:"Fix overflowing elements. Use max-width: 100%, overflow-x: hidden on parent, hoac responsive sizing.",suggested_agent:"frontend-developer",estimated_effort:"medium"},
                detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-responsive-layout"}')
            SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
          fi
          
          if [ "$issue_type" = "small_touch_targets" ]; then
            target_count=$(echo "$issue" | jq '.targets | length' 2>/dev/null || echo 0)
            if [ "$target_count" -gt 0 ] 2>/dev/null; then
              fp=$(echo -n "QD5|$vp_name|touch_target|P-QD5-responsive-layout" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
              sig=$(jq -nc \
                --arg vp "$vp_name" --argjson count "$target_count" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-responsive-layout",severity:"medium",fixability:"agent_fix",domain:"accessibility",
                  title:("Touch targets below 44x44px at "+$vp), description:($count|tostring)+" interactive elements smaller than WCAG 2.5.5 minimum 44x44px touch target size at "+$vp+" viewport.",
                  location:{file:"runtime",line:null,url:null}, evidence:[{type:"metric",path:"runtime",description:($count|tostring)+" small touch targets at "+$vp}],
                  cdg_flags:[],fingerprint:$fp,
                  remediation:{suggested_action:"Increase touch target size to ≥ 44x44px. Add padding or increase element dimensions.",suggested_agent:"frontend-developer",estimated_effort:"medium"},
                  detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-responsive-layout"}')
              SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
            fi
          fi
          
          if [ "$issue_type" = "small_font_size" ]; then
            font_count=$(echo "$issue" | jq '.elements | length' 2>/dev/null || echo 0)
            if [ "$font_count" -gt 0 ] 2>/dev/null; then
              fp=$(echo -n "QD5|$vp_name|small_font|P-QD5-responsive-layout" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
              sig=$(jq -nc \
                --arg vp "$vp_name" --argjson count "$font_count" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-responsive-layout",severity:"medium",fixability:"agent_fix",domain:"ux",
                  title:("Font size below 12px at "+$vp), description:($count|tostring)+" text elements have font-size < 12px at "+$vp+" viewport. May be unreadable on small screens.",
                  location:{file:"runtime",line:null,url:null}, evidence:[{type:"metric",path:"runtime",description:($count|tostring)+" small text elements at "+$vp}],
                  cdg_flags:[],fingerprint:$fp,
                  remediation:{suggested_action:"Increase minimum font size to ≥ 12px (14px recommended). Use relative units (rem) for responsive typography.",suggested_agent:"frontend-developer",estimated_effort:"low"},
                  detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-responsive-layout"}')
              SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
            fi
          fi
        done < <(echo "$VP_ISSUES" | jq -c '.' 2>/dev/null || true)
      done
    fi
    rm -f "$RESP_DIR/responsive-test.js"
  fi
fi

jq -nc \
  --arg lane "wf-fix-ux-a11y" --arg probe "P-QD5-responsive-layout" --arg pver "v1.0" \
  --arg profile "${PROFILE:-deep}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson signals "$SIGNALS_JSON" \
  '{$schema:"lane-signals-v1",lane:$lane,dimension:"QD5",probe_id:$probe,
    probe_version:$pver,profile:$profile,generated_at:$now,signals:$signals}' \
  > "$RAW_OUT"
```

## THINK

1. **Horizontal overflow:** Document wider than viewport → horizontal scrollbar → HIGH. Users on mobile must scroll sideways to read content. Primary responsive layout failure.

2. **Fixed pixel widths:** Large fixed widths (>640px) without media queries → MEDIUM. May cause overflow on smaller screens. Use relative units or breakpoints.

3. **Touch target size:** Interactive elements < 44x44px → MEDIUM. Violates WCAG 2.5.5 (Target Size). Users with motor disabilities fail to tap accurately.

4. **Small font size:** Text < 12px → MEDIUM. Unreadable on mobile, users must zoom. Minimum should be 12px, ideally 14-16px.

5. **4 viewport breakpoints:** 320px (mobile), 768px (tablet), 1024px (desktop), 1440px (wide). Issues detected per-viewport for targeted fixes.

6. **Domain:** `ux` (overflow, font) + `accessibility` (touch targets)
7. **Fixability:** `agent_fix` (frontend-developer)

## ACT

Output schema `signal-v2`:
- `dimension_id: "QD5"`, domain varies by issue type (`ux` or `accessibility`)
- `evidence[].type: "metric"` voi viewport name + measurement value
- `remediation.suggested_action`: responsive design fix guidance
- Per-viewport per-issue signals for precise targeting

## VERIFY

1. Moi Signal co `dimension_id == "QD5"`
2. Overflow signals co viewport name + offender count in evidence
3. Touch target signals domain = "accessibility"
4. Overflow/font signals domain = "ux"
5. Signals emitted per viewport (max 4 viewports × 3 issue types = 12 signals)
6. Severity: overflow→HIGH, touch_targets→MEDIUM, small_font→MEDIUM

## Severity Rules

| Pattern | Severity | Ly do |
|---------|----------|-------|
| Horizontal overflow at mobile (320px) | HIGH | Core responsive failure, user cannot read |
| Horizontal overflow at tablet/desktop | HIGH | Layout broken even on common screen sizes |
| Fixed >640px width without responsive | MEDIUM | Will break on smaller screens |
| Touch targets < 44x44px | MEDIUM | WCAG 2.5.5 failure, accessibility issue |
| Font size < 12px on mobile | MEDIUM | Unreadable without zooming |
| Overlapping elements at any breakpoint | MEDIUM | Content collision, broken layout |
| Horizontal overflow at wide (1440px) | LOW | Only affects very narrow windows |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong co BASE_URL | Chi chay static checks, note "runtime_skipped_no_base_url" |
| Playwright khong available | Chi chay static checks, note "runtime_skipped_playwright_unavailable" |
| Viewport test timeout > 30s | Skip viewport do, log warning |
| JavaScript errors on page | Note in evidence, continue with partial results |
| Element targeting fails (SPA dynamic content) | Extend wait timeout, retry once |
