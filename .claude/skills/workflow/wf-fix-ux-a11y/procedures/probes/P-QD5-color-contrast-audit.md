# P-QD5-color-contrast-audit — Color Contrast Ratio Audit

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD5-color-contrast-audit |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Extract CSS color definitions, parse hex/rgb/hsl values, tinh toan WCAG contrast ratio, phat hien text/background combos below 4.5:1 (AA) or 3:1 (large text AA). |
| **Cache** | allowed (1h TTL — CSS rarely changes mid-session) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co CSS/SCSS files (no .css/.scss/.less files in src/): SKIP, note "no_stylesheet_found"
IF profile=standard: chi check inline color values via grep
IF profile=deep: bo sung file-level contrast analysis
IF profile=exhaustive: bo sung component-level context (check background color inheritance)
```

## SENSE

### B1: Static CSS color extraction + contrast calculation

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/raw/P-QD5-color-contrast-audit.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'
SOURCE="${SOURCE_DIR:-src/}"

# Heuristic: extract hex colors with their context
# Pattern: color, background-color, background properties
grep -rnE '(color\s*:\s*#|background(-color)?\s*:\s*#|--[a-z-]*color\s*:\s*#)' "$SOURCE" \
  --include='*.css' --include='*.scss' --include='*.less' --include='*.tsx' --include='*.jsx' --include='*.vue' \
  2>/dev/null | grep -vE '(node_modules|\.test\.|\.spec\.|dist/|build/)' | head -50 > "$RAW_OUT.colors"

# --- Pattern 1: Low-contrast known bad combos ---
# Common problematic pairs: light gray text on white, dark gray on dark bg
grep -rnE '(color\s*:\s*#(ccc|ddd|eee|f[0-9a-f]f[0-9a-f]f[0-9a-f]|aaa|999)|background(-color)?\s*:\s*#fff.*color\s*:\s*#f[a-f0-9]{3,5})' "$SOURCE" \
  --include='*.css' --include='*.scss' --include='*.tsx' --include='*.jsx' \
  2>/dev/null | grep -vE '(node_modules|\.test\.)' | head -20 | \
while IFS=: read -r file line match; do
  fp=$(echo -n "QD5|$file|$line|P-QD5-color-contrast-audit|low_contrast_heuristic" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc --arg file "$file" --argjson line "$line" --arg snip "${match:0:100}" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-color-contrast-audit",severity:"high",fixability:"agent_fix",domain:"accessibility",
      title:"Potential low-contrast color combination", description:("Low-contrast color detected tai "+$file+":"+($line|tostring)+". Co the gay readability issues cho users voi low vision."),
      location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:$snip}],
      cdg_flags:[],fingerprint:$fp,
      remediation:{suggested_action:"Verify contrast ratio ≥ 4.5:1 cho normal text, ≥ 3:1 cho large text (18px+). Use WebAIM Contrast Checker.",suggested_agent:"frontend-developer",estimated_effort:"low"},
      detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-color-contrast-audit"}')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done

# --- Pattern 2: Inline styles with hardcoded colors (deep+) ---
if [ "$PROFILE" != "standard" ]; then
  grep -rnE 'style\s*=\s*\{.*(color|background).*:#' "$SOURCE" \
    --include='*.tsx' --include='*.jsx' --include='*.vue' \
    2>/dev/null | grep -vE '(node_modules|\.test\.|\.spec\.)' | head -20 | \
  while IFS=: read -r file line match; do
    fp=$(echo -n "QD5|$file|$line|P-QD5-color-contrast-audit|hardcoded_color" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc --arg file "$file" --argjson line "$line" --arg snip "${match:0:100}" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-color-contrast-audit",severity:"medium",fixability:"agent_fix",domain:"accessibility",
        title:"Hardcoded color trong inline style", description:("Hardcoded color value trong inline style tai "+$file+":"+($line|tostring)+". Kho kiem soat contrast va theme consistency."),
        location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:$snip}],
        cdg_flags:[],fingerprint:$fp,
        remediation:{suggested_action:"Replace hardcoded color voi design token / CSS variable tu theme.",suggested_agent:"frontend-developer",estimated_effort:"low"},
        detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-color-contrast-audit"}')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  done
fi

# --- Pattern 3: opacity usage that reduces contrast (exhaustive) ---
if [ "$PROFILE" = "exhaustive" ]; then
  grep -rnE 'opacity\s*:\s*0\.[0-5]' "$SOURCE" \
    --include='*.css' --include='*.scss' --include='*.tsx' --include='*.jsx' \
    2>/dev/null | grep -vE '(node_modules|\.test\.|\.spec\.)' | head -15 | \
  while IFS=: read -r file line match; do
    fp=$(echo -n "QD5|$file|$line|P-QD5-color-contrast-audit|low_opacity" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc --arg file "$file" --argjson line "$line" --arg snip "${match:0:100}" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-color-contrast-audit",severity:"medium",fixability:"agent_fix",domain:"accessibility",
        title:"Low opacity text — potential contrast issue", description:("Opacity ≤ 0.5 tai "+$file+":"+($line|tostring)+". Reduces perceived contrast, affects readability."),
        location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:$snip}],
        cdg_flags:[],fingerprint:$fp,
        remediation:{suggested_action:"Use direct color value thay vi opacity for text. Hoac increase opacity to ≥ 0.8.",suggested_agent:"frontend-developer",estimated_effort:"low"},
        detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-color-contrast-audit"}')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  done
fi

rm -f "$RAW_OUT.colors"

jq -nc \
  --arg lane "wf-fix-ux-a11y" --arg probe "P-QD5-color-contrast-audit" --arg pver "v1.0" \
  --arg profile "${PROFILE:-standard}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson signals "$SIGNALS_JSON" \
  '{$schema:"lane-signals-v1",lane:$lane,dimension:"QD5",probe_id:$probe,
    probe_version:$pver,profile:$profile,generated_at:$now,signals:$signals}' \
  > "$RAW_OUT"
```

### B2: Scan cache check (khi --use-cache)

```bash
if [ "${USE_CACHE:-0}" -eq 1 ]; then
  python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ \
    --probe-id P-QD5-color-contrast-audit --probe-version 1.0.0 \
    >> "$RAW_OUT.cache" 2>/dev/null || true
fi
```

## THINK

1. **Low contrast heuristic:** Light gray text (#ccc-#eee) on white (#fff) background → ratio ~1.5:1 to ~3:1 → below WCAG AA 4.5:1 → HIGH. Common in footer text, placeholder text, disabled states.
2. **Hardcoded inline colors:** Color values in JSX style={{color:"#xxx"}} → undocumented, hard to audit → MEDIUM. Should use CSS variables / design tokens.
3. **Low opacity:** Opacity ≤ 0.5 on text elements → perceived contrast reduced → MEDIUM. Use direct color with proper contrast instead.
4. **WCAG thresholds:** AA Normal: 4.5:1, AA Large (≥18px bold or ≥24px): 3:1, AAA Normal: 7:1, AAA Large: 4.5:1
5. **Domain:** `accessibility`
6. **Fixability:** `agent_fix` (frontend-developer)

## ACT

Output schema `signal-v2`:
- `dimension_id: "QD5"`, `domain: "accessibility"`
- `evidence[].type: "code"` voi CSS snippet
- `remediation.suggested_action`: WCAG ratio threshold guidance
- `remediation.suggested_agent: "frontend-developer"`

## VERIFY

1. Moi Signal co `dimension_id == "QD5"` va `domain == "accessibility"`
2. Signals co CSS snippet trong evidence
3. Severity theo WCAG thresholds: below 4.5:1 normal text→HIGH, below 3:1 large text→MEDIUM
4. Hardcoded colors without theme variable→MEDIUM
5. Moi signal co `remediation.suggested_action` non-empty

## Severity Rules

| Pattern | Severity | Ly do |
|---------|----------|-------|
| Light gray text on white (ratio < 3:1) | HIGH | Unreadable for low-vision users |
| Text contrast 3:1 to 4.5:1 | MEDIUM | Meets large-text AA only, not normal |
| Hardcoded color in inline style | MEDIUM | Hard to audit system-wide contrast |
| Opacity ≤ 0.5 on text content | MEDIUM | Perceived contrast reduced |
| Text contrast 4.5:1 to 7:1 | LOW | Meets AA but not AAA |
| Background-image with text overlay | LOW | Possible contrast issue with image |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong co CSS/SCSS files | Skip probe, note "no_stylesheet_found" |
| CSS variables / design tokens (complex calculation) | Chi heuristic grep, note "approximate_only" |
| Preprocessor (SCSS variable) colors | Grep chi bat hex/rgb literal, miss variable-based colors → note "scss_variables_not_resolved" |
| Scan Cache corrupt | Fallback: scan fresh, log WARNING |
| Empty grep (all colors fine) | Emit empty signals, note "no_low_contrast_found" |
