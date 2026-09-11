# P-QD7-device-breakpoint-test — Device Breakpoint Responsive Test

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD7-device-breakpoint-test |
| **Loai** | runtime |
| **Profile** | deep, exhaustive |
| **Muc dich** | Kiem tra responsive design tai cac breakpoints thong dung. Phat hien horizontal overflow, clipped content, layout breaks, va touch target issues. |
| **Cache** | **skip** (runtime probe) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF $BASE_URL == null:
  SKIP probe, note "skipped_no_base_url"

IF khong co UI code (Glob src/**/*.{tsx,jsx,vue,svelte,css} tra 0 results):
  SKIP probe, note "skipped_no_ui_code"

IF khong co Playwright available:
  npx playwright --version 2>/dev/null || SKIP probe, note "skipped_no_playwright"
```

## SENSE

### B1: Xac dinh breakpoints tu design system

```bash
# Doc breakpoints tu code
BREAKPOINTS=""
# 1. Tu tailwind.config
if test -f tailwind.config.*; then
  BREAKPOINTS=$(grep -A 10 "screens" tailwind.config.* 2>/dev/null)
fi

# 2. Tu CSS custom properties / media queries
if [ -z "$BREAKPOINTS" ]; then
  BREAKPOINTS=$(grep -rn "@media\|breakpoint\|--bp-" --include="*.css" --include="*.scss" src/ 2>/dev/null | head -20)
fi

# 3. Default breakpoints (mobile-first convention)
DEFAULT_BREAKPOINTS='[
  {"name":"xs","width":320,"height":568,"device":"iPhone SE"},
  {"name":"sm","width":375,"height":667,"device":"iPhone 8"},
  {"name":"md","width":768,"height":1024,"device":"iPad"},
  {"name":"lg","width":1280,"height":800,"device":"Laptop"},
  {"name":"xl","width":1440,"height":900,"device":"Desktop"},
  {"name":"2xl","width":1920,"height":1080,"device":"Large Desktop"}
]'
```

### B2: Build page list

```bash
# Doc routes tu app code
PAGES=""
# 1. Tu Next.js pages/app directory
if test -d src/app; then
  PAGES=$(find src/app -name "page.tsx" -o -name "page.jsx" | sed 's|src/app||;s|/page.tsx||;s|/page.jsx||;s|^$|/|' | head -20)
elif test -d src/pages; then
  PAGES=$(find src/pages -name "*.tsx" -o -name "*.jsx" | sed 's|src/pages||;s|.tsx||;s|.jsx||;s|index||;s|//|/|' | head -20)
fi

# Limit pages for deep profile: top 10 most linked
# Limit for exhaustive: all pages
```

### B3: N/A (runtime probe — skip cache check)

## THINK

1. **Breakpoint coverage**: Kiem tra tat ca breakpoints co media query tuong ung
2. **Layout integrity at each breakpoint**:
   - Horizontal overflow (> viewport width) → layout break
   - Elements overlap khong mong muon
   - Text clipped hoac truncated bi mat meaning
   - Touch targets < 44px (iOS HIG) hoac < 48px (Material)
   - Fixed elements cover content khi scroll
3. **Cross-device patterns**:
   - iPhone SE (320px) — nho nhat mobile, hay bi overflow
   - iPad (768px) — tablet, check 2-column lai 1-column
   - Desktop (1280px+) — check wide layout, whitespace
4. **Severity mapping**:
   - Horizontal scroll required → CRITICAL (broken UX)
   - Content invisible/hidden → HIGH
   - Touch target < 44px → MEDIUM
   - Minor spacing issue → LOW

## ACT

### Run Playwright responsive tests

```bash
# Chay Playwright de test tung breakpoint
for BP in "$BREAKPOINTS"; do
  WIDTH=$(echo "$BP" | jq -r '.width')
  HEIGHT=$(echo "$BP" | jq -r '.height')
  DEVICE=$(echo "$BP" | jq -r '.device')

  for PAGE in $PAGES; do
    URL="$BASE_URL$PAGE"

    # Resize viewport va check
    RESULT=$(npx playwright test --config=- << 'PWEOF'
    import { test, expect } from '@playwright/test';
    test('responsive at ${WIDTH}x${HEIGHT}', async ({ page }) => {
      await page.setViewportSize({ width: ${WIDTH}, height: ${HEIGHT} });
      await page.goto('${URL}', { waitUntil: 'networkidle' });

      // Check horizontal overflow
      const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
      const clientWidth = await page.evaluate(() => document.documentElement.clientWidth);
      if (scrollWidth > clientWidth) {
        return { overflow: scrollWidth - clientWidth };
      }

      // Check touch targets
      const smallTargets = await page.evaluate(() => {
        const interactives = document.querySelectorAll('button, a, input, select, [role="button"]');
        return Array.from(interactives)
          .filter(el => el.getBoundingClientRect().width < 44 || el.getBoundingClientRect().height < 44)
          .map(el => ({ tag: el.tagName, text: el.textContent?.slice(0, 30), w: el.getBoundingClientRect().width, h: el.getBoundingClientRect().height }));
      });

      return { overflow: 0, smallTargets };
    });
PWEOF
    )
  done
done
```

### Emit signals cho layout issues

```json
{
  "probe_id": "P-QD7-device-breakpoint-test",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-compat",
  "dimension_id": "QD7",
  "signal_type": "responsive_break",
  "target": {
    "kind": "page",
    "file_path": "src/app/dashboard/page.tsx",
    "line_range": [0, 0],
    "url": "/dashboard"
  },
  "description": "Horizontal overflow 47px tai viewport 320px (iPhone SE). Layout bi break — user phai scroll ngang.",
  "evidence": {
    "viewport": "320x568",
    "device": "iPhone SE",
    "overflow_px": 47,
    "screenshot_path": "$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat/evidence/dashboard-320-overflow.png"
  },
  "suggested_severity": "critical",
  "dedup_hints": ["responsive:/dashboard:320"]
}
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat/raw/P-QD7-device-breakpoint-test.json" << 'EOF'
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
- [ ] Moi Signal co `evidence` khong rong (viewport + overflow_px hoac screenshot_path)
- [ ] `suggested_severity` trong [CRITICAL, HIGH, MEDIUM, LOW]
- [ ] `probe_id` match `^P-QD7-[a-z0-9-]+$`
- [ ] `evidence.screenshot_path` ton tai (neu co) hoac `evidence.overflow_px` > 0
- [ ] `dedup_hints` chua page + breakpoint combination

## Severity Rules

| Pattern | Severity |
|---------|----------|
| Horizontal overflow > 20px (user phai scroll ngang) | CRITICAL |
| Content invisible hoac clipped o viewport thuong | HIGH |
| Touch target < 44px (iOS) hoac < 48px (Material) | MEDIUM |
| Minor spacing/sizing issue (< 10px offset) | LOW |
| Fixed header/footer cover content | MEDIUM |

## Fallback

| Tinh huong | Xu ly |
|-----------|-------|
| Khong co $BASE_URL | Skip probe, emit 0 signals |
| Playwright khong available | Skip probe, note "skipped_no_playwright" |
| Page load timeout (>30s) | Log warning, skip page, continue |
| Network error | Skip page, continue with remaining pages |
