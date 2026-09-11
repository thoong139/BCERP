# P-QD7-polyfill-coverage — Polyfill Coverage Check

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD7-polyfill-coverage |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Kiem tra modern JS/CSS features co polyfill tuong ung cho target browsers. Phat hien missing polyfills va coverage gaps. |
| **Cache** | **allowed** |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co source code (Glob src/**/*.{ts,tsx,js,jsx} tra 0 results):
  SKIP probe, note "skipped_no_source_code"
```

## SENSE

### B1: Xac dinh polyfill setup hien tai

```bash
# Check polyfill configuration
POLYFILL_STATUS="none"

# 1. core-js
if grep -rq "core-js" --include="*.ts" --include="*.js" package.json src/ 2>/dev/null; then
  POLYFILL_STATUS="core-js"
  COREJS_VERSION=$(jq -r '.dependencies["core-js"] // "unknown"' package.json 2>/dev/null)
fi

# 2. @babel/polyfill (deprecated)
if grep -rq "@babel/polyfill" --include="*.ts" --include="*.js" package.json src/ 2>/dev/null; then
  POLYFILL_STATUS="babel-polyfill-deprecated"
fi

# 3. polyfill.io / cdn polyfill
if grep -rq "polyfill.io\|cdn.polyfill" --include="*.html" --include="*.tsx" --include="*.jsx" src/ 2>/dev/null; then
  POLYFILL_STATUS="cdn-polyfill"
fi

# 4. Vite/Webpack polyfill config
if grep -rq "polyfill" vite.config.* webpack.config.* 2>/dev/null; then
  echo "Build-tool polyfill config found"
fi

# 5. browserslist → determine what polyfills are needed
BROWSERSLIST=$(cat .browserslistrc 2>/dev/null || jq -r '.browserslist[]?' package.json 2>/dev/null || echo "defaults")
```

### B2: Quet modern JS features su dung trong code

```bash
# ES2020+ features can polyfill cho older browsers
MODERN_FEATURES=(
  "?. "                               # Optional Chaining
  "??"                                # Nullish Coalescing
  "Promise.allSettled"                # Promise.allSettled
  "Promise.any"                       # Promise.any
  "String.prototype.matchAll"         # matchAll
  "BigInt("                           # BigInt
  "globalThis"                        # globalThis
  "import.meta"                       # import.meta
  "export * as"                       # Namespace export
  "#private"                          # Private class fields
  "Array.prototype.at("              # .at() method
  "Object.hasOwn"                     # Object.hasOwn
  "structuredClone("                  # structuredClone
  ".replaceAll("                      # String.replaceAll
  "AggregateError"                    # AggregateError
)

for FEATURE in "${MODERN_FEATURES[@]}"; do
  COUNT=$(grep -rn "$FEATURE" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ 2>/dev/null | wc -l)
  if [ "$COUNT" -gt 0 ]; then
    FILES=$(grep -rl "$FEATURE" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ 2>/dev/null | head -5 | tr '\n' ',')
    echo "{\"feature\":\"$FEATURE\",\"usage_count\":$COUNT,\"files\":\"$FILES\"}"
  fi
done
```

### B3: Check scan cache (neu --use-cache)

```bash
CACHE_KEY="polyfill-coverage-$(find src/ -name '*.ts' -o -name '*.tsx' | sort | xargs cat | md5sum | cut -d' ' -f1)"
```

## THINK

1. **Polyfill gap analysis**:
   - Feature su dung + khong co polyfill + target browser khong support = GAP
   - Feature su dung + co polyfill nhung khong import = GAP
   - Feature su dung + polyfill imported + version match = OK
2. **Build tool transform check**:
   - Babel preset-env co transform optional chaining? (usually yes for syntax, polyfill needed for APIs)
   - Vite co target ES version config?
   - TypeScript target co khop voi browserslist?
3. **Severity logic**:
   - Feature gap anh huong >50% users (based on browserslist) → CRITICAL
   - Feature gap anh huong 10-50% users → HIGH
   - Feature gap anh huong <10% users → MEDIUM
   - Deprecated polyfill library (babel/polyfill) → MEDIUM

## ACT

### Emit signals cho polyfill gaps

```json
{
  "probe_id": "P-QD7-polyfill-coverage",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-compat",
  "dimension_id": "QD7",
  "signal_type": "missing_polyfill",
  "target": {
    "kind": "config",
    "file_path": "package.json",
    "line_range": [1, 1]
  },
  "description": "Su dung structuredClone() (ES2022) tai 3 locations nhung khong co core-js polyfill. Target browsers Safari 14 khong support structuredClone.",
  "evidence": {
    "feature": "structuredClone",
    "usage_count": 3,
    "affected_files": "src/utils/clone.ts,src/services/data.ts,src/hooks/useDeepCopy.ts",
    "caniuse_support": "91.2%",
    "browserslist_target": "Safari 14 (khong support)"
  },
  "suggested_severity": "high",
  "dedup_hints": ["polyfill:structuredClone"]
}
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat/raw/P-QD7-polyfill-coverage.json" << 'EOF'
{
  "$schema": "lane-signals-v1",
  "lane": "wf-fix-compat",
  "dimension": "QD7",
  "generated_at": "<ISO>",
  "signals": []
}
EOF
```

## VERIFY

- [ ] Moi Signal co `dimension_id = "QD7"`
- [ ] Moi Signal co `evidence` khong rong (it nhat `feature` + `usage_count`)
- [ ] `suggested_severity` trong [CRITICAL, HIGH, MEDIUM, LOW]
- [ ] `probe_id` match `^P-QD7-[a-z0-9-]+$`
- [ ] `dedup_hints` chua feature name de aggregate
- [ ] Signal target chi ra file can fix (code hoac config)

## Severity Rules

| Pattern | Severity |
|---------|----------|
| Modern feature khong co polyfill cho required browser | CRITICAL |
| Missing core-js import cho used feature | HIGH |
| Deprecated polyfill library (@babel/polyfill) | MEDIUM |
| Polyfill version mismatch | MEDIUM |
| Optional polyfill cho edge-case browser | LOW |

## Fallback

| Tinh huong | Xu ly |
|-----------|-------|
| Khong co source code | Skip probe, emit 0 signals |
| Khong co package.json | WARNING: cannot check polyfill config, run B2 only |
| Babel/Vite config not parseable | Log warning, skip transform check |
