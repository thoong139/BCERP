# F0a — Phase 3: API MAPPING (FIND only)

## Mục tiêu

Scan controllers, routes, validators để lập bản đồ API. KHÔNG live-test. Nếu không tìm thấy → ghi N/A.

---

## FIND — Nguồn scan

```bash
# 1. Controllers liên quan module
find apps/backend/ -name "*Controller*.cs" | grep -i "$MODULE_ID" | head -20

# 2. Route attributes
grep -r "\[Route\]\|\[HttpGet\]\|\[HttpPost\]\|\[HttpPut\]\|\[HttpDelete\]\|\[HttpPatch\]" \
  apps/backend/Eureka.Modules.${MODULE_ID}/ --include="*.cs" -l | head -10

# 3. Validators (FluentValidation)
find apps/backend/ -name "*Validator*.cs" | grep -i "$MODULE_ID" | head -10

# 4. RBAC / Authorization attributes
grep -r "\[Authorize\]\|\[RequirePermission\]\|HasPermission" \
  apps/backend/Eureka.Modules.${MODULE_ID}/ --include="*.cs" | head -20

# 5. Nếu CI available: GitNexus route map
[ "$GITNEXUS_AVAILABLE" = "true" ] && mcp__gitnexus__route_map

# 6. API contract từ Phase 3 design doc
find .mc-data/docs/phase3-architecture/ -name "*.md" | xargs grep -l "$FEAT_ID\|$MODULE_ID" 2>/dev/null | head -3
```

---

## ASSESS — Checklist tự đánh giá

```
[ ] Tìm được ≥1 endpoint (route + method)
[ ] Biết handler class + method name
[ ] Biết validator class (hoặc N/A nếu không validate)
[ ] Biết RBAC permission required (hoặc anonymous)
[ ] Biết response schema cơ bản (success + error)
```

Nếu chưa đủ → BỔ SUNG:

```bash
# Serena: tìm theo class name từ controller list
[ "$SERENA_AVAILABLE" = "true" ] && \
  mcp__serena__find_symbol --name_path_pattern="*Controller" --relative_path="apps/backend/Eureka.Modules.${MODULE_ID}/"

# Grep command/query dispatchers
grep -r "ISender\|IMediator\|Send(\|Query(" apps/backend/Eureka.Modules.${MODULE_ID}/ --include="*.cs" | head -20
```

---

## Output — Ghi 1 file

### api-mapping.md

Từ template `templates/api-mapping.template.md`. Điền endpoint matrix:

| Route | Method | Handler class | Validator | RBAC Permission | Request schema | Response schema |
|-------|--------|---------------|-----------|-----------------|----------------|-----------------|
| `/api/v1/...` | POST | `CreateXyzCommand` | `CreateXyzValidator` | `xyz.create` | `{fields}` | `{XyzDto}` |

Ghi thêm:
- Dependency chain (handler → repository → domain service)
- Error response mapping (validation error format, business error format)
- Pagination support nếu có (GET list endpoints)

Nếu không tìm thấy API artifacts → ghi rõ lý do + E024 warning.

---

## POST-GATE Phase 3

```bash
# T1: file tồn tại
test -f "$FINDINGS_DIR/api-mapping.md" || { log_error "E024" "phase3" "api-mapping.md không tồn tại"; return 1; }

# T2: size > 200 bytes
SIZE=$(wc -c < "$FINDINGS_DIR/api-mapping.md")
[ "$SIZE" -gt 200 ] || { log_error "E024" "phase3" "api-mapping.md quá nhỏ"; return 1; }
```

---

## Cập nhật status.json

```bash
update_phase_status "p3_api" "done"
advance_phase 4 "run P4 UI mapping"
log_event "COMPLETE" "phase3" "API mapping generated"
check_context_budget
```
