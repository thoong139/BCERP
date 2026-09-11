# P-QD5-accessibility-check — WCAG 2.2 AA Accessibility Audit

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD5-accessibility-check |
| **Loai** | runtime+agent |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Run WCAG 2.2 AA accessibility audit using Playwright + axe-core. Phat hien violations ve: button name, image alt text, form labels, link text, landmark structure, heading order, ARIA attributes. |
| **Cache** | skip (runtime probe) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co frontend source dir (src/, app/, components/, pages/, ui/) -> SKIP
IF khong co BASE_URL va khong co Playwright MCP -> SKIP, note "no_accessibility_tooling"
IF profile=standard: chi chay static grep checks, skip axe-core runtime
IF profile=deep: chay axe-core basic (wcag2a + wcag2aa + wcag22aa)
IF profile=exhaustive: chay axe-core full (wcag2a + wcag2aa + wcag22aa + wcag21aa + best-practice)
```

## SENSE

### B1: Static pre-check — grep for common a11y issues

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/raw/P-QD5-accessibility-check.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'
SOURCE="${SOURCE_DIR:-src/}"

# Static Check 1: Images missing alt attribute
grep -rn '<img[^>]*>' "$SOURCE" \
  --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' --include='*.svelte' \
  2>/dev/null | grep -vE 'alt\s*=' | grep -vE '(node_modules|\.test\.|\.spec\.)' | head -30 | \
while IFS=: read -r file line match; do
  fp=$(echo -n "QD5|$file|$line|P-QD5-accessibility-check|missing_alt" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc --arg file "$file" --argjson line "$line" --arg snip "${match:0:100}" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-accessibility-check",severity:"high",fixability:"agent_fix",domain:"accessibility",
      title:"Thieu alt attribute tren image", description:("Image element khong co alt attribute tai "+$file+":"+($line|tostring)+". Screen reader user khong nhan duoc image description."),
      location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:$snip}],
      cdg_flags:[],fingerprint:$fp,
      remediation:{suggested_action:"Add descriptive alt text to <img>. Neu la decorative image, dung alt=\"\".",suggested_agent:"frontend-developer",estimated_effort:"low"},
      detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-accessibility-check"}')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done

# Static Check 2: Button elements without accessible name
grep -rn '<button[^>]*>' "$SOURCE" \
  --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' \
  2>/dev/null | grep -vE '(aria-label|aria-labelledby|>[^<]+<)' | grep -vE '(node_modules|\.test\.)' | head -20 | \
while IFS=: read -r file line match; do
  fp=$(echo -n "QD5|$file|$line|P-QD5-accessibility-check|no_button_name" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc --arg file "$file" --argjson line "$line" --arg snip "${match:0:100}" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-accessibility-check",severity:"high",fixability:"agent_fix",domain:"accessibility",
      title:"Button thieu accessible name", description:("Button element khong co text content hoac aria-label tai "+$file+":"+($line|tostring)+". Screen reader se announce la 'button' khong co context."),
      location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:$snip}],
      cdg_flags:[],fingerprint:$fp,
      remediation:{suggested_action:"Add text content inside <button> hoac aria-label attribute.",suggested_agent:"frontend-developer",estimated_effort:"low"},
      detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-accessibility-check"}')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done

# Static Check 3: Input fields without associated labels
grep -rn '<input[^>]*>' "$SOURCE" \
  --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' \
  2>/dev/null | grep -vE '(type\s*=\s*"hidden"|aria-label|aria-labelledby|id\s*=|htmlFor)' | grep -vE '(node_modules|\.test\.)' | head -20 | \
while IFS=: read -r file line match; do
  fp=$(echo -n "QD5|$file|$line|P-QD5-accessibility-check|no_input_label" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc --arg file "$file" --argjson line "$line" --arg snip "${match:0:100}" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-accessibility-check",severity:"medium",fixability:"agent_fix",domain:"accessibility",
      title:"Input field thieu associated label", description:("Input element co the thieu <label> hoac aria-label tai "+$file+":"+($line|tostring)),
      location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:$snip}],
      cdg_flags:[],fingerprint:$fp,
      remediation:{suggested_action:"Add <label htmlFor={id}> hoac aria-label to input element.",suggested_agent:"frontend-developer",estimated_effort:"low"},
      detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-accessibility-check"}')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done

# Static Check 4: Empty heading tags
grep -rnE '<h[1-6]\s*[^>]*>\s*</h[1-6]>' "$SOURCE" \
  --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' \
  2>/dev/null | grep -vE '(node_modules|\.test\.)' | head -10 | \
while IFS=: read -r file line match; do
  fp=$(echo -n "QD5|$file|$line|P-QD5-accessibility-check|empty_heading" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc --arg file "$file" --argjson line "$line" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-accessibility-check",severity:"low",fixability:"agent_fix",domain:"accessibility",
      title:"Empty heading element", description:("Heading tag empty tai "+$file+":"+($line|tostring)+". Gay confusion cho screen reader navigation."),
      location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:"Empty heading element"}],
      cdg_flags:[],fingerprint:$fp,
      remediation:{suggested_action:"Remove empty heading hoac populate voi content.",suggested_agent:"frontend-developer",estimated_effort:"low"},
      detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-accessibility-check"}')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done
```

### B2: Runtime axe-core scan (Playwright, profile != standard)

```bash
if [ "${PROFILE:-standard}" != "standard" ] && [ -n "${BASE_URL:-}" ]; then
  # Playwright with axe-core injection
  AXE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/runtime"
  mkdir -p "$AXE_DIR"
  
  # Launch shared browser session (playwright-session.js — xem _shared.md §0)
  pw_launch || { echo "E096: browser_unavailable" >&2; exit 1; }
  
  cat > "$AXE_DIR/axe-scan.js" <<'AXE_SCRIPT'
const { chromium } = require('playwright');
const fs = require('fs');
const baseUrl = process.env.BASE_URL;

(async () => {
  const state = JSON.parse(fs.readFileSync(process.env.SESSION_FILE, 'utf-8'));
  const browser = await chromium.connectOverCDP(state.wsEndpoint);
  const context = browser.contexts()[0] || await browser.newContext();
  const page = await context.newPage();
  let violations = [];
  
  try {
    await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(2000);
    
    violations = await page.evaluate(async () => {
      // @ts-ignore
      const results = await window.axe.run(document, {
        runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag22aa'] }
      });
      return results.violations.map(v => ({
        id: v.id,
        impact: v.impact,
        description: v.description,
        help: v.help,
        helpUrl: v.helpUrl,
        nodes: v.nodes.map(n => ({
          html: n.html.substring(0, 150),
          target: n.target.join(' '),
          failureSummary: n.failureSummary
        }))
      }));
    });
  } catch (e) {
    console.error('axe-core scan failed:', e.message);
  }
  
  console.log(JSON.stringify({ violations }));
  // Browser stays alive — shared session managed by playwright-session.js
})().catch(e => { console.error(e); process.exit(1); });
AXE_SCRIPT

  if command -v npx &>/dev/null && npx playwright --version &>/dev/null 2>&1; then
    SESSION_FILE="$SESSION_DIR/playwright-session.json" BASE_URL="$BASE_URL" node "$AXE_DIR/axe-scan.js" > "$AXE_DIR/axe-results.json" 2>/dev/null || true
    
    if [ -f "$AXE_DIR/axe-results.json" ]; then
      AXE_COUNT=$(jq '.violations | length' "$AXE_DIR/axe-results.json" 2>/dev/null || echo 0)
      if [ "$AXE_COUNT" -gt 0 ] 2>/dev/null; then
        # Emit per-violation signals
        jq -c '.violations[]' "$AXE_DIR/axe-results.json" 2>/dev/null | while read -r violation; do
          vid=$(echo "$violation" | jq -r '.id')
          impact=$(echo "$violation" | jq -r '.impact')
          vcount=$(echo "$violation" | jq '.nodes | length')
          severity="medium"
          [ "$impact" = "critical" ] && severity="high"
          [ "$impact" = "minor" ] && severity="low"
          
          fp=$(echo -n "QD5|axe|$vid|P-QD5-accessibility-check" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
          sig=$(jq -nc \
            --arg id "$vid" --arg impact "$impact" --arg severity "$severity" --argjson count "$vcount" \
            --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-accessibility-check",severity:$severity,fixability:"agent_fix",domain:"accessibility",
              title:("axe-core: "+$id+" ("+$impact+" impact, "+($count|tostring)+" nodes)"),
              description:("WCAG violation: "+$id+" - "+$impact+" impact. "+($count|tostring)+" instances found by axe-core."),
              location:{file:"runtime",line:null,url:null},
              evidence:[{type:"axe_core",path:"runtime",description:"axe violation "+$id+" ("+($count|tostring)+" nodes)"}],
              cdg_flags:[],fingerprint:$fp,
              remediation:{suggested_action:("Fix WCAG violation '"+$id+"'. Xem axe-core help URL cho guidance."),suggested_agent:"frontend-developer",estimated_effort:"medium"},
              detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-accessibility-check"}')
          SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
        done
      fi
    fi
    rm -f "$AXE_DIR/axe-scan.js"
  fi
fi
```

### B3: KHONG check scan cache

Runtime probe — results vary per page state.

## THINK

1. **Missing alt text:** Images without alt → screen reader announces "image" with no context → HIGH. Decorative images: alt="" is correct.
2. **Empty buttons:** Button elements without text or aria-label → screen reader announces "button" → HIGH. Every interactive element must have accessible name.
3. **Input without label:** Form fields without label association → user doesn't know what to enter → MEDIUM.
4. **Empty headings:** h1-h6 without content → broken document structure for screen readers → LOW.
5. **axe-core violations:** Automated WCAG 2.2 AA scanning → severity based on axe impact (critical→high, serious→medium, moderate→low, minor→low).
6. **Domain:** `accessibility`
7. **Fixability:** `agent_fix` (frontend-developer)

## ACT

Output schema `signal-v2`:
- `dimension_id: "QD5"`, `domain: "accessibility"`
- Static signals: `evidence[].type: "code"` voi HTML snippet
- Runtime signals: `evidence[].type: "axe_core"` voi violation ID + node count
- `remediation.suggested_action`: specific fix with ARIA guidance
- `remediation.suggested_agent: "frontend-developer"`

## VERIFY

1. Moi Signal co `dimension_id == "QD5"` va `domain == "accessibility"`
2. Static signals co `evidence[].path` tro den file ton tai
3. Runtime signals co axe-core violation ID trong evidence
4. Severity mapped tu axe impact: critical→HIGH, serious→MEDIUM, moderate→LOW, minor→LOW
5. Moi signal co `remediation.suggested_action` non-empty
6. Standard profile chi co static signals (khong axe-core)

## Severity Rules

| Pattern | Severity | Ly do |
|---------|----------|-------|
| Missing alt on functional image | HIGH | Screen reader loses context |
| Button without accessible name | HIGH | User cannot identify button purpose |
| axe-core critical impact violation | HIGH | Blocks screen reader users |
| Input without label | MEDIUM | User unsure what to input |
| axe-core serious impact violation | MEDIUM | Significant accessibility barrier |
| Empty heading element | LOW | Navigation structure issue |
| axe-core moderate/minor violation | LOW | Minor accessibility improvement |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong tim thay frontend source dir | Skip probe, note "no_frontend_source_dir" |
| Playwright khong available | Chi chay static checks, note "runtime_skipped_playwright_unavailable" |
| Khong co BASE_URL | Chi chay static checks, note "runtime_skipped_no_base_url" |
| axe-core injection fail | Chi emit static signals, log warning |
| Static grep returns empty | Emit empty signals, note "no_static_a11y_issues" |
