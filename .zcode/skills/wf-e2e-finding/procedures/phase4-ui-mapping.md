# F0a — Phase 4: UI MAPPING (FIND only)

## Mục tiêu

Scan pages, components, hooks, i18n để lập bản đồ UI. KHÔNG live-test browser. Nếu API-only → ghi N/A.

---

## FIND — Nguồn scan

```bash
# 1. Pages liên quan module
find apps/frontend/src/ -name "*.tsx" -o -name "*.jsx" | xargs grep -l "$MODULE_ID\|${MODULE_ID,,}\|${FEAT_NAME}" 2>/dev/null | head -20

# 2. Routes/navigation
grep -r "path.*${MODULE_ID,,}\|route.*${MODULE_ID,,}" apps/frontend/src/ --include="*.tsx" --include="*.ts" | head -20

# 3. React hooks
find apps/frontend/src/ -name "use*.ts" -o -name "use*.tsx" | xargs grep -l "$MODULE_ID\|$FEAT_NAME" 2>/dev/null | head -10

# 4. State management (Zustand stores)
find apps/frontend/src/ -name "*store*.ts" -o -name "*store*.tsx" | xargs grep -l "$MODULE_ID" 2>/dev/null | head -5

# 5. i18n keys
find apps/frontend/src/ -name "*.json" -path "*/locales/*" | xargs grep -l "${MODULE_ID,,}" 2>/dev/null | head -5

# 6. Nếu CI available: Serena overview
[ "$SERENA_AVAILABLE" = "true" ] && \
  mcp__serena__search_for_pattern --pattern="${MODULE_ID}" --relative_path="apps/frontend/src/"
```

---

## ASSESS — Checklist tự đánh giá

```
[ ] Tìm được ≥1 page/route liên quan feature
[ ] Biết components chính (form, table, modal)
[ ] Biết hooks gọi API nào (từ api-mapping.md)
[ ] Biết i18n keys cho labels + error messages
[ ] Biết RBAC UI (button hidden/disabled theo role)
```

Nếu chưa đủ → BỔ SUNG:

```bash
# Serena: tìm component từ tên feature
[ "$SERENA_AVAILABLE" = "true" ] && \
  mcp__serena__find_symbol --name_path_pattern="*${FEAT_NAME}*" --relative_path="apps/frontend/src/"

# Grep API calls trong frontend
grep -r "api.${MODULE_ID,,}\|fetch.*${MODULE_ID,,}\|axios.*${MODULE_ID,,}" apps/frontend/src/ | head -20
```

API-only check:
```bash
# Nếu không có frontend (api-only dự án)
if [ ! -d "apps/frontend" ]; then
  echo "N/A: Dự án này là API-only, không có UI layer"
  UI_MAPPING_NA=true
fi
```

---

## Output — Ghi 1 file

### ui-mapping.md

Từ template `templates/ui-mapping.template.md`. Điền:

**Pages & Routes:**
| Route | Page component | Module | Permission guard |
|-------|---------------|--------|-----------------|

**Components:**
| Component | Loại | Dùng trong trang | Kết nối API |
|-----------|------|-----------------|-------------|

**Hooks:**
| Hook name | Gọi API endpoints | State managed |
|-----------|------------------|---------------|

**Zustand stores:**
| Store | State keys | Actions |
|-------|-----------|---------|

**i18n keys:**
| Key | Loại | Dùng trong |
|-----|------|-----------|

Nếu không tìm thấy UI artifacts → ghi rõ "N/A: API-only / UI chưa implement" + E025 warning.

---

## POST-GATE Phase 4

```bash
# T1: file tồn tại
test -f "$FINDINGS_DIR/ui-mapping.md" || { log_error "E025" "phase4" "ui-mapping.md không tồn tại"; return 1; }

# T2: size > 200 bytes
SIZE=$(wc -c < "$FINDINGS_DIR/ui-mapping.md")
[ "$SIZE" -gt 200 ] || { log_error "E025" "phase4" "ui-mapping.md quá nhỏ"; return 1; }
```

---

## Cập nhật status.json

```bash
update_phase_status "p4_ui" "done"
advance_phase 5 "run P5 completion + consolidate"
log_event "COMPLETE" "phase4" "UI mapping generated"
check_context_budget
```
