# P-QD1-multitenant-isolation-audit — Multi-Tenant Data Isolation Audit

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD1-multitenant-isolation-audit |
| **Version** | 1.0.0 |
| **Loai** | static |
| **Profile** | deep, exhaustive |
| **Muc dich** | Kiem tra entity/query co CompanyId/TenantId field khong — phat hien multi-tenant data isolation gap. So sanh pattern giua cac entity cung module. |
| **Cache** | allowed (--use-cache) |
| **Migrates from** | (new in v2.1.0) |

---

## CI-ROUTE: Multi-Tenant Isolation Analysis (Protocol 20 §20.5)

> **PRIMARY:** Serena find_symbol tim entity class + find_referencing_symbols tim query filter.
> **GitNexus:** Trace query flow tu entity → repository → endpoint de xac dinh isolation enforcement.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `find_entities` | **Serena** `find_symbol({name_path_pattern: "Entity\|AggregateRoot", include_body: true})` | Grep `class.*:.*Entity` | Tim tat ca entity/aggregate root |
| `check_companyid_field` | **Serena** `find_symbol({name_path_pattern: "CompanyId"})` trong entity file | Grep `CompanyId\|TenantId` | Kiem tra entity co CompanyId field khong |
| `trace_query_filter` | **GitNexus** `query("CompanyId filter")` | Grep `.Where(.*CompanyId)` | Tim query nao thieu CompanyId filter |
| `find_referencing_queries` | **Serena** `find_referencing_symbols({entity_name})` | Grep entity name | Tim tat ca query/repository dung entity nay |

**Khi Serena available:** Dung `get_symbols_overview` tren entity file → kiem tra properties.
**Khi GitNexus available:** Trace execution flow → xac dinh CRITICAL neu entity khong co CompanyId nhung duoc truy van khong filter.

---

## SENSE

### B1: Phat hien entity/aggregate root

```bash
# .NET — Entity Framework entities
grep -rn "class\s\+\w\+\s*:\s*\(Entity\|AggregateRoot\|IAggregateRoot\)" \
  apps/backend/ --include="*.cs" 2>/dev/null || true

# TypeScript/DTO types — interface/type co "Entity" hoac mapping DB table
grep -rn "interface\s\+\w*Entity\|type\s\+\w*Entity\|interface\s\+\w*Aggregate" \
  apps/erp-web/src/ --include="*.ts" --include="*.tsx" 2>/dev/null || true

# Tim cac class trong Domain/Entities/
find apps/backend/ -path "*/Domain/Entities/*.cs" 2>/dev/null
```

Parse ra `$ENTITIES[]` voi: `{entity_name, file_path, module, base_class}`

### B2: Phat hien CompanyId/TenantId field — per entity

```bash
for ENTITY_FILE in $ENTITY_FILES; do
  MODULE=$(echo "$ENTITY_FILE" | grep -oE "Modules\.[A-Za-z]+" | head -1 || echo "unknown")
  ENTITY_NAME=$(grep -oE "class\s+(\w+)" "$ENTITY_FILE" | head -1 | sed 's/class //')

  HAS_COMPANY_ID=$(grep -c "CompanyId\|TenantId\|company_id\|tenant_id" "$ENTITY_FILE" 2>/dev/null || echo 0)
  HAS_COMPANY_FK=$(grep -c "Company\s*Company\|Tenant\s*Tenant" "$ENTITY_FILE" 2>/dev/null || echo 0)

  echo "$MODULE|$ENTITY_NAME|$ENTITY_FILE|$HAS_COMPANY_ID|$HAS_COMPANY_FK"
done
```

Parse ra `$ENTITY_ISOLATION[]` voi: `{entity_name, file_path, module, has_company_id, has_company_fk}`

### B3: Phat hien query/repository thieu CompanyId filter

```bash
# Tim LINQ/EF queries — kiem tra co .Where() voi CompanyId khong
grep -rn "\.Where\s*(" apps/backend/ --include="*.cs" 2>/dev/null | \
  grep -v "CompanyId\|TenantId\|companyId\|tenantId" | \
  grep -v "\.Where\s*(\s*$" | \
  head -100 || true

# Tim repository methods tra ve IEnumerable/List — co filter CompanyId khong?
grep -rn "interface\s\+I\w*Repository\|interface\s\+I\w*Reader" \
  apps/backend/ --include="*.cs" 2>/dev/null | \
  while read -r line; do
    FILE=$(echo "$line" | cut -d: -f1)
    # Kiem tra interface co method nao reference CompanyId khong
    HAS_FILTER=$(grep -c "CompanyId\|TenantId" "$FILE" 2>/dev/null || echo 0)
    echo "$FILE|$HAS_FILTER"
  done
```

### B4: So sanh isolation pattern trong cung module

```bash
# Trong moi module: entity nao CO CompanyId vs entity nao KHONG?
for MODULE in $MODULE_LIST; do
  ENTITIES_WITH=$(echo "$ENTITY_ISOLATION" | grep "$MODULE" | awk -F'|' '$4 > 0 {print $2}')
  ENTITIES_WITHOUT=$(echo "$ENTITY_ISOLATION" | grep "$MODULE" | awk -F'|' '$4 == 0 {print $2}')

  # Neu module co entity WITH CompanyId nhung co entity KHONG → flag inconsistency
  if [ -n "$ENTITIES_WITH" ] && [ -n "$ENTITIES_WITHOUT" ]; then
    echo "ISOLATION_GAP: $MODULE — entities WITH CompanyId: $ENTITIES_WITH — entities WITHOUT: $ENTITIES_WITHOUT"
  fi
done
```

### B5: Scan Cache check (khi --use-cache)

```bash
for FILE in $SCAN_FILES; do
  FP=$(python -m _shared.scan_cache.fingerprint --probe-id P-QD1-multitenant-isolation-audit --probe-version 1.0.0 --file "$FILE")
  HIT=$(python -m _shared.scan_cache.cache_lookup --cache-root .mc-data/cache/wf-fix-bugs/probes/ --fingerprint "$FP")
  if [ -n "$HIT" ]; then
    cat "$HIT" >> "$ACCUMULATED_SIGNALS"
    continue
  fi
  SCAN_FILES+=("$FILE")
done
```

---

## THINK

### Phan loai isolation gap

1. **CRITICAL — Entity thieu CompanyId nhung khong co filter trong query:**
   - Entity khong co CompanyId field
   - Query/repository fetch entity khong filter CompanyId
   - Data cua company A co the bi leak sang company B

2. **HIGH — Entity thieu CompanyId, cung module co entity da co:**
   - Module co ≥1 entity da co CompanyId
   - Nhung entity nay thieu → inconsistency → co the la gap

3. **MEDIUM — Entity thieu CompanyId, module chua co entity nao co:**
   - Module moi, chua co pattern multi-tenant
   - Co the la intentional (module global/settings)

4. **LOW — Repository co CompanyId nhung 1 method thieu:**
   - Repository interface co method CompanyId filter
   - Nhung 1 method cu the thieu → co the intentional (admin function)

### Exclusion list (KHONG flag)

- Lookup/Reference entities (vi du: `Country`, `Currency`, `UnitOfMeasure`) — global data, khong can isolation
- System entities (`AuditLog`, `MigrationHistory`, `EventLog`) — cross-tenant by design
- Entities trong module `Settings` hoac `System` — mac dinh la global
- Entities co annotation `[IgnoreMultiTenant]` hoac `[GlobalEntity]`

### Confidence mapping

| Loai gap | Confidence | Ghi chu |
|-----------|-----------|---------|
| Entity thieu CompanyId + query khong filter | 0.90 | CRITICAL — chac chan data leak |
| Entity thieu CompanyId + module co inconsistency | 0.80 | HIGH — pattern gap |
| Entity thieu CompanyId, module chua co pattern | 0.50 | MEDIUM — co the intentional |
| Repository method thieu CompanyId filter | 0.75 | HIGH — data leak risk |

---

## ACT

### Tao Signals

**Entity thieu CompanyId + co inconsistency trong module (HIGH):**
```json
{
  "probe_id": "P-QD1-multitenant-isolation-audit",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "multitenant_isolation_gap",
  "target": {
    "kind": "code",
    "file_path": "apps/backend/Eureka.Modules.CRM/Domain/Entities/Customer.cs",
    "line_range": [1, 30],
    "symbol": "Customer"
  },
  "description": "Entity 'Customer' trong module CRM thieu CompanyId field. Cac entity khac trong cung module (Lead, Opportunity) da co CompanyId — inconsistency pattern. Query ICrmCustomerBirthdayReader khong filter CompanyId → data leak cross-tenant.",
  "evidence": {
    "entity_name": "Customer",
    "module": "Eureka.Modules.CRM",
    "has_company_id": false,
    "sibling_entities_with_company_id": ["Lead", "Opportunity"],
    "affected_query": "ICrmCustomerBirthdayReader.cs:6"
  },
  "suggested_severity": "high",
  "dedup_hints": ["multitenant:Customer:CRM:missing_companyid"]
}
```

**Query thieu CompanyId filter (HIGH):**
```json
{
  "probe_id": "P-QD1-multitenant-isolation-audit",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "query_missing_tenant_filter",
  "target": {
    "kind": "code",
    "file_path": "apps/backend/Eureka.Modules.Marketing/Infrastructure/Jobs/ZaloBirthdayCampaignJob.cs",
    "line_range": [110, 125],
    "symbol": "ZaloBirthdayCampaignJob"
  },
  "description": "ZaloBirthdayCampaignJob truy van campaign data khong filter theo CompanyId. TODO o line 117 xac nhan day la gap da biet. Campaign data co the bi gui sai company.",
  "evidence": {
    "code_snippet": "// TODO: filter CompanyId per-campaign\nvar campaigns = await _campaignRepo.GetAllAsync();",
    "has_todo": true,
    "module": "Eureka.Modules.Marketing"
  },
  "suggested_severity": "high",
  "dedup_hints": ["multitenant:ZaloBirthdayCampaignJob:Marketing:missing_filter"]
}
```

**Entity thieu CompanyId, module chua co pattern (MEDIUM):**
```json
{
  "probe_id": "P-QD1-multitenant-isolation-audit",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "multitenant_isolation_undetermined",
  "target": {
    "kind": "code",
    "file_path": "apps/backend/Eureka.Modules.NewModule/Domain/Entities/NewEntity.cs",
    "line_range": [1, 20],
    "symbol": "NewEntity"
  },
  "description": "Entity 'NewEntity' trong module NewModule thieu CompanyId field. Module chua co entity nao co CompanyId — chua xac dinh duoc day la intentional hay gap. Khuyen nghi: review xem module co can multi-tenant isolation khong.",
  "evidence": {
    "entity_name": "NewEntity",
    "module": "Eureka.Modules.NewModule",
    "has_company_id": false,
    "module_has_any_company_id": false
  },
  "suggested_severity": "medium",
  "dedup_hints": ["multitenant:NewEntity:NewModule:undetermined"]
}
```

### Scan Cache store

```bash
for FILE in $SCAN_FILES; do
  python -m _shared.scan_cache.cache_store store \
    --probe-id P-QD1-multitenant-isolation-audit --probe-version 1.0.0 \
    --file "$FILE" --signals-file "$TMP" \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/
done
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/P-QD1-multitenant-isolation-audit.json" << 'EOF'
$ISOLATION_SIGNALS
EOF
```

---

## VERIFY

1. Kiem tra moi Signal co `evidence` voi it nhat 1 field non-empty
   - `entity_name` + `module` cho entity signals
   - `code_snippet` cho query signals
2. Kiem tra moi Signal co `signal_type` trong ["multitenant_isolation_gap","query_missing_tenant_filter","multitenant_isolation_undetermined"]
3. Kiem tra isolation_gap signals co `sibling_entities_with_company_id` (inconsistency evidence)
4. Loai bo signals cho entities trong exclusion list (lookup, audit, system)
5. Drop signals voi confidence < 0.5

---

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| Entity thieu CompanyId + query khong filter | **CRITICAL** |
| Entity thieu CompanyId + module co inconsistency (entity khac CO) | **HIGH** |
| Repository query thieu CompanyId filter + co TODO xac nhan | **HIGH** |
| Entity thieu CompanyId + module chua co pattern | **MEDIUM** |
| Repository method thieu filter — co the intentional | **MEDIUM** |

---

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong tim thay entity nao | Skip probe, note "no_entities_found" |
| Khong tim thay CompanyId pattern trong toan bo codebase | Skip probe, note "no_multitenant_pattern" — project co the la single-tenant |
| Module structure khong theo convention `Modules.*/Domain/Entities/` | Fallback grep toan bo `src/` va `apps/backend/` cho entity class |
| Serena unavailable | Fallback grep cho entity class + CompanyId field |
| GitNexus unavailable | Skip query flow trace — chi flag entity isolation gap |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
