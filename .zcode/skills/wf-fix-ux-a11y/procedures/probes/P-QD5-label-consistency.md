# P-QD5-label-consistency — UI Label vs Spec Label Cross-Reference

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD5-label-consistency |
| **Loai** | static+runtime |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Cross-reference UI labels (button text, aria-labels, form labels, headings) against spec labels trong phase2-features/.md. Phat hien inconsistent naming, missing labels, labels that changed without spec update. |
| **Cache** | allowed (1h TTL — spec labels rarely change mid-session) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co phase2-features/ AND khong co req-registry.json: SKIP, note "no_spec_labels_to_compare"
IF khong co frontend source: SKIP, note "no_frontend_source"
IF profile=standard: chi compare hardcoded UI label strings vs spec
IF profile=deep: bo sung dynamic labels extracted via Playwright
IF profile=exhaustive: bo sung i18n/messages file cross-reference
```

## SENSE

### B1: Static — extract UI labels from source vs spec labels from docs

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/raw/P-QD5-label-consistency.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'
SOURCE="${SOURCE_DIR:-src/}"

# Extract spec labels from phase2-features
SPEC_LABELS="$RAW_OUT.spec_labels"
mkdir -p "$(dirname "$SPEC_LABELS")"

if [ -d ".mc-data/docs/phase2-features" ]; then
  # Extract button/label/form label references from feature specs
  grep -rnE '"(label|button|title|heading|text)\s*[:=]|UI label:|text displayed:' \
    .mc-data/docs/phase2-features/ 2>/dev/null | \
    grep -oE '"[^"]{3,60}"' | sort -u | head -50 > "$SPEC_LABELS" 2>/dev/null || true
fi

if [ ! -f "$SPEC_LABELS" ] || [ ! -s "$SPEC_LABELS" ]; then
  echo "[]" > "$SPEC_LABELS"
fi

# Extract UI labels from source code
UI_LABELS="$RAW_OUT.ui_labels"
grep -rnE '(aria-label\s*[=:]\s*"|label\s*[=:]\s*"|children\s*[=:]\s*")' "$SOURCE" \
  --include='*.tsx' --include='*.jsx' --include='*.vue' --include='*.html' \
  2>/dev/null | grep -vE '(node_modules|\.test\.|\.spec\.)' | \
  grep -oE '"[^"]{3,60}"' | sort -u | head -100 > "$UI_LABELS" 2>/dev/null || true

# --- Check: labels that appear in UI but NOT in any spec → possible orphan UI ---
if [ -s "$SPEC_LABELS" ] && [ -s "$UI_LABELS" ]; then
  while IFS= read -r ui_label; do
    [ -z "$ui_label" ] && continue
    if ! grep -qF "$ui_label" "$SPEC_LABELS" 2>/dev/null; then
      # Find file location of this label
      label_escaped=$(echo "$ui_label" | sed 's/"/\\"/g')
      location=$(grep -rn "$label_escaped" "$SOURCE" \
        --include='*.tsx' --include='*.jsx' --include='*.vue' \
        2>/dev/null | grep -vE '(node_modules|\.test\.)' | head -1 || echo "unknown:0")
      file=$(echo "$location" | cut -d: -f1)
      line=$(echo "$location" | cut -d: -f2)
      [ -z "$line" ] && continue
      
      fp=$(echo -n "QD5|$file|$line|P-QD5-label-consistency|orphan_label" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
      sig=$(jq -nc --arg label "$ui_label" --arg file "$file" --argjson line "$line" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-label-consistency",severity:"medium",fixability:"agent_fix",domain:"ux",
          title:"UI label khong co trong spec", description:("Label \""+$label+"\" xuat hien trong UI nhung khong thay trong phase2-features spec. Co the orphan UI element hoac spec chua duoc update."),
          location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:("Label: "+$label)}],
          cdg_flags:[],fingerprint:$fp,
          remediation:{suggested_action:"Verify this UI element co corresponding spec requirement. Update spec hoac remove orphan UI element.",suggested_agent:"frontend-developer",estimated_effort:"low"},
          detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-label-consistency"}')
      SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
    fi
  done < "$UI_LABELS"
fi

# Also check: key terms that appear differently in UI vs spec
# Example: "Sign In" vs "Login", "My Account" vs "Profile"
TERM_VARIANTS=("Sign In|Login|Sign in|Log in" "Log Out|Sign Out|Logout|Sign out" "My Account|Profile|Account Settings" "Cart|Basket|Shopping Cart" "Submit|Send|Save" "Cancel|Close|Dismiss" "Settings|Preferences|Options|Configuration")
for variant_set in "${TERM_VARIANTS[@]}"; do
  IFS='|' read -ra terms <<< "$variant_set"
  found_terms=()
  for term in "${terms[@]}"; do
    if grep -rq "$term" "$SOURCE" --include='*.tsx' --include='*.jsx' 2>/dev/null; then
      found_terms+=("$term")
    fi
  done
  # If multiple variants found in UI → inconsistency
  if [ ${#found_terms[@]} -gt 1 ]; then
    term_list=$(IFS=','; echo "${found_terms[*]}")
    fp=$(echo -n "QD5|label|inconsistency|$variant_set|P-QD5-label-consistency" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc --arg terms "$term_list" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-label-consistency",severity:"low",fixability:"agent_fix",domain:"ux",
        title:"Inconsistent terminology across UI", description:("Multiple term variants found: "+$terms+". Choose one variant va su dung consistently."),
        location:{file:"N/A",line:null}, evidence:[{type:"search",path:"N/A",description:("Inconsistent terms: "+$terms)}],
        cdg_flags:[],fingerprint:$fp,
        remediation:{suggested_action:"Standardize terminology across UI. Choose one variant per concept. Update design system / glossary.",suggested_agent:"frontend-developer",estimated_effort:"medium"},
        detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-label-consistency"}')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  fi
done

rm -f "$SPEC_LABELS" "$UI_LABELS"

jq -nc \
  --arg lane "wf-fix-ux-a11y" --arg probe "P-QD5-label-consistency" --arg pver "v1.0" \
  --arg profile "${PROFILE:-standard}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson signals "$SIGNALS_JSON" \
  '{$schema:"lane-signals-v1",lane:$lane,dimension:"QD5",probe_id:$probe,
    probe_version:$pver,profile:$profile,generated_at:$now,signals:$signals}' \
  > "$RAW_OUT"
```

### B2: Runtime — Playwright text content extraction (deep+)

```bash
if [ "${PROFILE:-standard}" != "standard" ] && [ -n "${BASE_URL:-}" ]; then
  LABEL_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/runtime"
  mkdir -p "$LABEL_DIR"
  
  # Launch shared browser session (playwright-session.js — xem _shared.md §0)
  pw_launch || { echo "E096: browser_unavailable" >&2; exit 1; }
  
  cat > "$LABEL_DIR/extract-labels.js" <<'LABEL_SCRIPT'
const { chromium } = require('playwright');
const fs = require('fs');
const baseUrl = process.env.BASE_URL;

(async () => {
  const state = JSON.parse(fs.readFileSync(process.env.SESSION_FILE, 'utf-8'));
  const browser = await chromium.connectOverCDP(state.wsEndpoint);
  const context = browser.contexts()[0] || await browser.newContext();
  const page = await context.newPage();
  let uiText = [];
  try {
    await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 30000 });
    uiText = await page.evaluate(() => {
      const texts = [];
      document.querySelectorAll('button, a, label, h1, h2, h3, h4, h5, h6, [aria-label]').forEach(el => {
        const tag = el.tagName.toLowerCase();
        const text = el.textContent?.trim().substring(0, 80) || '';
        const ariaLabel = el.getAttribute('aria-label') || '';
        if (text) texts.push({ tag, type: 'text', value: text });
        if (ariaLabel) texts.push({ tag, type: 'aria-label', value: ariaLabel });
      });
      return texts;
    });
  } catch(e) { console.error(e.message); }
  console.log(JSON.stringify(uiText));
  // Browser stays alive — shared session managed by playwright-session.js
})().catch(e => { console.error(e); process.exit(1); });
LABEL_SCRIPT

  if command -v npx &>/dev/null && npx playwright --version &>/dev/null 2>&1; then
    SESSION_FILE="$SESSION_DIR/playwright-session.json" BASE_URL="$BASE_URL" node "$LABEL_DIR/extract-labels.js" > "$LABEL_DIR/page-labels.json" 2>/dev/null || true
  fi
  rm -f "$LABEL_DIR/extract-labels.js"
  # Runtime labels stored for manual comparison - no auto-signals generated here
  # (text extraction is noisy; signals generated via static cross-ref above)
fi
```

## THINK

1. **Orphan UI labels:** Labels in code that don't appear in spec → MEDIUM. Could be orphan UI (needs removal) or missing spec (needs update). Requires human judgment.

2. **Inconsistent terminology:** Multiple term variants for same concept ("Sign In" vs "Login") → LOW. Confuses users, weakens brand. Standardize via design system glossary.

3. **Label vs spec mismatch:** Spec says "Submit Order" but UI says "Place Order" → inconsistency → MEDIUM (if functional), LOW (if cosmetic). Both should match requirements.

4. **Runtime text extraction:** Deep+ only, stored for manual cross-ref. Text extraction from DOM is noisy but useful for diff with spec labels.

5. **Domain:** `ux`
6. **Fixability:** `agent_fix` (frontend-developer)

## ACT

Output schema `signal-v2`:
- `dimension_id: "QD5"`, `domain: "ux"`
- `evidence[].type: "code"` voi label text value
- `remediation.suggested_action`: terminology standardization guidance
- `remediation.suggested_agent: "frontend-developer"`

## VERIFY

1. Moi Signal co `dimension_id == "QD5"` va `domain == "ux"`
2. Orphan label signals co file location + label text in evidence
3. Terminology inconsistency signals co all variant terms listed
4. Severity based on impact: functional inconsistency → MEDIUM, cosmetic → LOW
5. Empty signals when UI labels match spec (healthy state)

## Severity Rules

| Pattern | Severity | Ly do |
|---------|----------|-------|
| UI label refers to feature not in spec (orphan) | MEDIUM | Possible scope creep or missing spec |
| UI label disagrees with spec on key action verb | MEDIUM | "Save" vs "Submit" can change expectations |
| Inconsistent terminology across pages | MEDIUM | "Delete" vs "Remove" — user confusion |
| UI label spelling/grammar differs from spec | LOW | Minor cosmetic issue |
| Multiple term variants for same concept | LOW | "Settings" vs "Preferences" |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong co phase2-features/ docs | Skip probe, note "no_spec_labels_to_compare" |
| Khong co frontend source code | Skip probe, note "no_frontend_source" |
| Spec labels extraction fail | Emit empty signals, note "spec_parse_failed" |
| i18n projects (labels in .json message files) | Read messages file for label extraction (exhaustive only) |
| All labels match spec | Emit empty signals, note "all_labels_consistent" |
