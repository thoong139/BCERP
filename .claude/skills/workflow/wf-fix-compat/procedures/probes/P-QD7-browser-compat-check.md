# P-QD7-browser-compat-check — Browser Compatibility Check

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD7-browser-compat-check |
| **Loai** | static+runtime |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | Kiem tra browser compatibility: CSS features, JS APIs, browserslist config. Phat hien code khong tuong thich voi target browsers. |
| **Cache** | **allowed** (static portion) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co source code (Glob src/**/*.{ts,tsx,js,jsx,css} tra 0 results):
  SKIP probe, note "skipped_no_source_code"
```

## SENSE

### B1: Xac dinh target browsers

```bash
# Priority: browserslist config > package.json > default
BROWSERSLIST=""
if test -f .browserslistrc; then
  BROWSERSLIST=$(cat .browserslistrc)
elif grep -q '"browserslist"' package.json 2>/dev/null; then
  BROWSERSLIST=$(jq -r '.browserslist[]?' package.json 2>/dev/null)
else
  BROWSERSLIST="defaults"  # fallback: >0.5%, not dead
fi
```

### B2: Quet CSS features khong tuong thich

```bash
# Modern CSS features co kha nang khong ho tro tren old browsers
CSS_PATTERNS=(
  "container-type:"                    # CSS Container Queries
  "container-name:"                     # CSS Container Queries
  ":has("                              # CSS :has() selector
  "color-mix("                         # CSS color-mix()
  "accent-color:"                      # CSS accent-color
  "subgrid"                            # CSS Subgrid
  "@layer "                            # CSS Cascade Layers
  "selector("                          # CSS selector()
  "text-wrap: balance"                 # CSS text-wrap balance
  "field-sizing:"                      # CSS field-sizing
  "dialog::backdrop"                   # dialog element
)

for PATTERN in "${CSS_PATTERNS[@]}"; do
  RESULTS=$(grep -rn "$PATTERN" --include="*.css" --include="*.scss" --include="*.less" src/ 2>/dev/null || true)
  if [ -n "$RESULTS" ]; then
    echo "{\"pattern\":\"$PATTERN\",\"matches\":\"$(echo "$RESULTS" | head -5 | tr '\n' '|')\"}"
  fi
done
```

### B3: Quet JS APIs khong tuong thich

```bash
# Modern JS/Browser APIs co kha nang can polyfill
JS_PATTERNS=(
  "structuredClone("                   # structuredClone
  "navigator.clipboard"                # Clipboard API
  "Intl.Segmenter"                     # Intl.Segmenter
  "AbortSignal.timeout"                # AbortSignal.timeout
  "crypto.randomUUID"                  # crypto.randomUUID
  "new EyeDropper"                     # EyeDropper API
  "navigator.usb"                      # WebUSB
  "navigator.serial"                   # Web Serial API
  "document PictureInPicture"          # Document PiP
  "ViewTransition"                     # View Transitions API
)

for PATTERN in "${JS_PATTERNS[@]}"; do
  RESULTS=$(grep -rn "$PATTERN" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ 2>/dev/null || true)
  if [ -n "$RESULTS" ]; then
    echo "{\"pattern\":\"$PATTERN\",\"matches\":\"$(echo "$RESULTS" | head -5 | tr '\n' '|')\"}"
  fi
done
```

### B4: Check scan cache (neu --use-cache)

```bash
CACHE_KEY="browser-compat-$(find src/ -name '*.css' -o -name '*.ts' -o -name '*.tsx' | sort | xargs cat | md5sum | cut -d' ' -f1)"
# Follow cache protocol tu _shared.md
```

## THINK

1. **Target browser baseline**: Parse browserslist → identify minimum browser versions
2. **CSS compat matrix**:
   - `:has()` → Chrome 105+, Firefox 121+, Safari 15.4+
   - `container-type:` → Chrome 105+, Firefox 110+, Safari 16+
   - `subgrid` → Chrome 117+, Firefox 71+, Safari 16+
   - `@layer` → Chrome 99+, Firefox 97+, Safari 15.4+
3. **JS API compat matrix**:
   - `structuredClone` → Chrome 98+, Firefox 94+, Safari 15.4+
   - `crypto.randomUUID` → Chrome 92+, Firefox 95+, Safari 15.4+
   - `navigator.clipboard` → Chrome 66+, Firefox 63+, Safari 13.1+
4. **Severity mapping**:
   - Feature used ma target browser khong ho tro VA khong co polyfill → CRITICAL
   - Feature used ma target browser khong ho tro NHUNG co polyfill → MEDIUM
   - Feature used chi ho tro tren recent browsers (duoi 5% global usage) → LOW

## ACT

### Emit signals cho tung compat issue

```json
{
  "probe_id": "P-QD7-browser-compat-check",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-compat",
  "dimension_id": "QD7",
  "signal_type": "browser_compat",
  "target": {
    "kind": "code",
    "file_path": "src/styles/components.css",
    "line_range": [42, 45]
  },
  "description": "Su dung CSS :has() selector ma khong co fallback cho Safari <15.4 (target browsers bao gom Safari 14)",
  "evidence": {
    "code_snippet": ".card:has(.badge) { border: 2px solid gold; }",
    "caniuse_coverage": "85.3%"
  },
  "suggested_severity": "high",
  "dedup_hints": ["css:has:src/styles/components.css"]
}
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat/raw/P-QD7-browser-compat-check.json" << 'EOF'
{
  "$schema": "lane-signals-v1",
  "lane": "wf-fix-compat",
  "dimension": "QD7",
  "generated_at": "<ISO>",
  "signals": [/* populated by ACT step */]
}
EOF
```

## VERIFY

- [ ] Moi Signal co `dimension_id = "QD7"`
- [ ] Moi Signal co `evidence` khong rong (it nhat `code_snippet` hoac `caniuse_coverage`)
- [ ] Moi Signal co `suggested_severity` trong [CRITICAL, HIGH, MEDIUM, LOW]
- [ ] `probe_id` match `^P-QD7-[a-z0-9-]+$`
- [ ] `target.file_path` ton tai tren disk
- [ ] `dedup_hints` khong rong cho moi signal

## Severity Rules

| Pattern | Severity |
|---------|----------|
| Modern feature khong co polyfill va target browser khong ho tro | CRITICAL |
| Modern feature co polyfill nhung chua install | HIGH |
| Feature chi support tren browsers <5% global usage | MEDIUM |
| CSS vendor prefix thieu (-webkit-, -moz-) | LOW |

## Fallback

| Tinh huong | Xu ly |
|-----------|-------|
| Khong co source code | Skip probe, emit 0 signals |
| Khong co browserslist config | Dung default "defaults", continue |
| Parse error tren CSS/JS files | Log warning per file, continue |
| CanIUse data khong available | Dung built-in compat matrix, continue |
