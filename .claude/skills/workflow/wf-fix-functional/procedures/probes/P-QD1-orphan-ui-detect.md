# P-QD1-orphan-ui-detect — Orphan UI Detection

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD1-orphan-ui-detect |
| **Loai** | static+runtime |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | So sanh UI elements voi Navigation spec va feature specs — phat hien orphan UI, dead code, va missing UI |
| **Cache** | allowed (--use-cache) |
| **Migrates from** | (v5 legacy — removed in v6) phase11-crossval.md |

## PRE-GATE

```
IF khong co Navigation specs VA khong co Playwright catalog:
  Chi chay static-only mode (grep-based)
  NOTE "no_runtime_catalog" trong lane-status.json
```

## SENSE

### B1: Thu thap UI elements — Runtime catalog (uu tien)

Neu co runtime catalog tu P-QD1-deep-ui-traversal (playwright-session.js bash-level):

```bash
CATALOG_FILE="$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/catalog-ui-pages.json"
test -s "$CATALOG_FILE" || echo "no_catalog"
```

Parse `$CATALOG_FILE` → lay `$RUNTIME_ELEMENTS[]` voi: `{page_url, element_type, element_text, element_ref}`

### B2: Thu thap UI elements — Static grep (fallback hoac bo sung)

```bash
# React components
grep -rn "<Button" src/ apps/ --include="*.tsx" --include="*.jsx" 2>/dev/null | \
  grep -oE '<Button[^>]*>[^<]+' || true

# Navigation links
grep -rn "<Link\s\+to=" src/ apps/ --include="*.tsx" --include="*.jsx" 2>/dev/null | \
  grep -oE 'to="[^"]+"' || true

# Router links
grep -rn "router-link\|<NavLink\|<RouterLink" src/ apps/ \
  --include="*.vue" --include="*.tsx" --include="*.jsx" 2>/dev/null | \
  grep -oE 'to="[^"]+"\|href="[^"]+"' || true

# HTML anchors voi internal href
grep -rn '<a\s\+href="/' src/ apps/ --include="*.tsx" --include="*.jsx" --include="*.html" 2>/dev/null | \
  grep -oE 'href="[^"]+"' || true

# Form elements
grep -rn "<form\|<Form" src/ apps/ --include="*.tsx" --include="*.jsx" --include="*.vue" 2>/dev/null
```

Parse ra `$STATIC_ELEMENTS[]` voi: `{element_type, file_path, line_number, text/href}`

### B3: Doc Navigation specs

```bash
NAV_SPEC_FILES=$(find .mc-data/docs/phase4-ux -name "Navigation-*.md" 2>/dev/null)
```

Parse moi Navigation spec → lay `$SPEC_ROUTES[]` voi: `{path, label, parent, visible_in_nav}`

### B4: Doc feature specs de xac dinh UI requirements

```bash
FEATURE_SPEC_FILES=$(find .mc-data/docs/phase2-features -name "*.md" 2>/dev/null)
```

Parse moi feature spec → tim cac section lien quan den UI:
- "UI Components", "Screens", "Pages", "Navigation"
- Lay `$FEATURE_UI_REFS[]` voi: `{feature_id, ui_component, route_hint}`

### B5: Scan Cache check (khi --use-cache, static grep only)

```bash
for FILE in $UI_SOURCE_FILES; do
  FP=$(python -m _shared.scan_cache.fingerprint --probe-id P-QD1-orphan-ui-detect --probe-version 1.0.0 --file "$FILE")
  HIT=$(python -m _shared.scan_cache.cache_lookup --cache-root .mc-data/cache/wf-fix-bugs/probes/ --fingerprint "$FP")
  if [ -n "$HIT" ]; then
    cat "$HIT" >> "$ACCUMULATED_SIGNALS"
    continue
  fi
  SCAN_FILES+=("$FILE")
done
```

## THINK

### Build 3 sets de so sanh

1. **`$ALL_UI_ELEMENTS[]`** — merge runtime + static elements (dedup by element_type + text/href)
2. **`$SPEC_ROUTES[]`** — routes tu Navigation specs
3. **`$FEATURE_UI_REFS[]`** — UI requirements tu feature specs

### Orphan detection logic

**Orphan UI element (co trong code/page nhung khong trong spec):**
```
FOR moi element trong $ALL_UI_ELEMENTS[]:
  IF element la navigation link:
    — Kiem tra element.href co trong $SPEC_ROUTES[].path?
    — IF khong → ORPHAN (co the la dead code hoac chua document)
  IF element la button/action:
    — Kiem tra element co map duoc bat ky feature nao trong $FEATURE_UI_REFS[]?
    — IF khong → ORPHAN (co the la left-over tu feature da remove)
  IF element la form:
    — Kiem tra form co map voi endpoint trong API contract?
    — IF khong → ORPHAN (form khong co backend handler)
```

**Missing UI (co trong spec nhung khong trong code/page):**
```
FOR moi route trong $SPEC_ROUTES[]:
  IF route.visible_in_nav == true:
    — Kiem tra route.path co trong $ALL_UI_ELEMENTS[] (dang link)?
    — IF khong → MISSING_NAV_LINK (spec yeu cau nhung chua implement)
```

### Exclusion list (KHONG flag)

- Error pages (404, 500)
- Modal/Dialog trigger buttons (co the la dynamic)
- Loading indicators, progress bars
- Accessibility-only elements (sr-only, aria-live)
- Development/debug UI (devtools, storybook links)
- Framework-generated elements (Next.js _next, React DevTools)

### Confidence mapping

| Loai orphan | Confidence | Ghi chu |
|-------------|-----------|---------|
| Nav link khong trong spec | 0.80 | Co the la spec chua update |
| Button/action khong map feature | 0.70 | Can manual review |
| Form khong co backend handler | 0.85 | High confidence — form se fail khi submit |
| Missing nav link (spec yeu cau) | 0.75 | Co the la conditional rendering |

## ACT

### Tao Signals

**Orphan navigation link:**
```json
{
  "probe_id": "P-QD1-orphan-ui-detect",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "orphan_nav_link",
  "target": {
    "kind": "code",
    "file_path": "src/components/Sidebar.tsx",
    "line_range": [42, 45],
    "url": "/admin/audit-logs"
  },
  "description": "Navigation link '/admin/audit-logs' ton tai trong Sidebar component nhung khong duoc dinh nghia trong bat ky Navigation spec nao — co the la orphan UI hoac spec chua cap nhat",
  "evidence": {
    "code_snippet": "<Link to=\"/admin/audit-logs\">Audit Logs</Link>",
    "spec_ref": "Khong tim thay trong .mc-data/docs/phase4-ux/**/Navigation-*.md"
  },
  "suggested_severity": "medium",
  "dedup_hints": ["orphan-nav:/admin/audit-logs"]
}
```

**Missing navigation link (spec yeu cau nhung chua co trong code):**
```json
{
  "probe_id": "P-QD1-orphan-ui-detect",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "missing_nav_link",
  "target": {
    "kind": "ui_page",
    "file_path": "N/A",
    "line_range": [0, 0]
  },
  "description": "Navigation spec dinh nghia route '/reports/monthly' voi label 'Monthly Reports' nhung khong tim thay link tuong ung trong bat ky component nao — feature co the chua duoc implement",
  "evidence": {
    "spec_ref": "Navigation-AdminPanel.md route /reports/monthly (visible_in_nav=true)"
  },
  "suggested_severity": "high",
  "dedup_hints": ["missing-nav:/reports/monthly"]
}
```

**Orphan form (khong co backend handler):**
```json
{
  "probe_id": "P-QD1-orphan-ui-detect",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "orphan_form",
  "target": {
    "kind": "code",
    "file_path": "src/pages/Settings.tsx",
    "line_range": [88, 120]
  },
  "description": "Form trong Settings.tsx (action POST /api/settings/profile) khong tim thay endpoint tuong ung trong API contract hoac code routes — form se fail khi submit",
  "evidence": {
    "code_snippet": "<form action=\"/api/settings/profile\" method=\"POST\">",
    "spec_ref": "Khong tim thay API-*.md dinh nghia POST /api/settings/profile"
  },
  "suggested_severity": "high",
  "dedup_hints": ["orphan-form:/api/settings/profile:POST"]
}
```

### Scan Cache store (khi --use-cache, cho MISS files)

```bash
for FILE in $SCAN_FILES; do
  python -m _shared.scan_cache.cache_store store \
    --probe-id P-QD1-orphan-ui-detect --probe-version 1.0.0 \
    --file "$FILE" --signals-file "$TMP" \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/
done
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/P-QD1-orphan-ui-detect.json" << 'EOF'
$ORPHAN_SIGNALS
EOF
```

## VERIFY

1. Kiem tra moi Signal co `evidence` voi it nhat 1 field non-empty
   - `code_snippet` min 10 chars
   - `spec_ref` min 1 char
   - `screenshot_path` min 1 char
2. Kiem tra moi Signal co `signal_type` trong `["orphan_nav_link", "missing_nav_link", "orphan_form", "orphan_button"]`
3. Kiem tra moi Signal co `target.file_path` (co the "N/A" cho missing items)
4. Kiem tra moi Signal co `dedup_hints` voi element identifier
5. Loai bo signals cho elements trong exclusion list
6. Drop signals voi confidence < 0.5

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| Form khong co backend handler | HIGH |
| Missing nav link (spec yeu cau visible) | HIGH |
| Orphan nav link (khong trong spec) | MEDIUM |
| Orphan button/action (khong map feature) | MEDIUM |
| Orphan static text/decorative element | LOW |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong co runtime catalog | Chay static-only mode (grep), note "no_runtime_catalog" |
| Khong co Navigation specs | Skip spec cross-ref, chi flag orphan forms va orphan buttons |
| Khong co feature specs | Skip feature mapping, note "no_feature_specs" |
| Static grep khong tim thay UI components | Skip probe, note "no_ui_components_found" |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
| Qua nhieu orphan signals (>50) | Cap max_signals_per_probe tu dimension.json, drop lowest confidence |
