# Phase 4: Module-Code Alignment (CORE-013)

> Cross-validate extracted modules với actual code project boundaries.
> Scan backend/frontend/mobile projects, map modules → code projects,
> detect cross-cutting concerns, confirm với user, update extracted data.

**PRE-GATE:**
- [ ] Phase 3 POST-GATE PASS
- [ ] `extracted/*.json` files tồn tại
- [ ] `$EXTRACTED_MODULES` không rỗng

**INPUT:**
- `.mc-data/work/legacy-scan/extracted/{module}.json`
- Project root (scan code boundaries)

**OUTPUT:**
- `.mc-data/work/legacy-scan/module-code-mapping.json`
- Updated: `extracted/{module}.json` (nếu user confirm merge/reclassify)
- In-memory: `$MODULE_CODE_MAPPING`

---

## Reference Sections

- `_shared.md` §State Variables Glossary

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.1 | **Scan actual project boundaries:** Backend — tìm `*.csproj`, `*.sln` files → list project names. Frontend — tìm `package.json` locations (trong `apps/`, `packages/`, root) → list apps. Mobile — tìm `app.json`/`package.json` trong mobile folders | Glob/Read | Project list built |
| 4.2 | **Map extracted modules → code projects:** Cho mỗi module trong `$EXTRACTED_MODULES`, tìm code project chứa nó (match qua `source_files` trong extracted/{module}.json). Xem §Mapping Algorithm | Read | Mappings computed |
| 4.3 | **Detect cross-cutting concerns:** Phát hiện code patterns thuộc về shared/infra nhưng bị đưa vào business module. Xem §Cross-Cutting Detection | Grep | Flags set |
| 4.4 | **Write module-code-mapping.json:** Xem §Mapping Schema | Write | `test -f module-code-mapping.json` |
| 4.5 | **User confirmation:** Hiển thị mapping table + warnings. Hỏi: "Có muốn merge subdomain modules vào parent? (Y/N)" và "Có muốn re-classify cross-cutting modules? (Y/N)" | AskUserQuestion | User responses captured |
| 4.6 | **Apply user decisions:** Nếu user confirm merge/reclassify → update extracted data tương ứng (merge requirements vào parent, đổi system cho cross-cutting, etc.) | Read/Write | Data updated |
| 4.7 | **Validate final JSON:** `jq '.' module-code-mapping.json` pass + `jq '.mappings | length > 0'` pass | Bash | Validation pass |

---

## Mapping Algorithm (Step 4.2)

```
FOR each module IN $EXTRACTED_MODULES:
  module_data = read extracted/{module}.json
  source_files = collect unique source_files từ all requirements
  
  # Tìm code project chứa module
  matching_projects = []
  FOR project IN code_projects:
    project_root = dirname của project manifest (csproj, package.json, ...)
    IF any source_file starts with project_root:
      matching_projects.append(project.name)
  
  IF len(matching_projects) == 1:
    type = "standalone"
    code_project = matching_projects[0]
  ELIF len(matching_projects) > 1:
    # Module spans nhiều code projects
    # Kiểm tra naming variants (case-insensitive, edit distance <= 2)
    variants = group_by_similarity(matching_projects)
    IF all variants của 1 canonical project:
      AUTO-MERGE thành 1 module (chọn tên theo code project)
      type = "standalone"
      code_project = canonical name
      log_merge_event(original_modules, canonical)
    ELSE:
      # Thực sự là subdomains khác nhau
      type = "subdomain"
      code_project = primary_match (nhiều source_files nhất)
      parent = canonical_parent (theo business-domain hierarchy)
  ELSE:
    type = "planned" hoặc "cross-cutting"
    code_project = null
```

---

## Cross-Cutting Detection (Step 4.3)

| Flag | Khi nào | Grep pattern |
|------|---------|--------------|
| `AUTH_MISPLACED` | Auth code (login, JWT, bcrypt, session) trong business module | `(LoginCommand\|JwtService\|AuthService\|bcrypt\|password)` |
| `INFRA_AS_FEATURE` | Infrastructure code (database, cache, queue) list là feature | `(Repository\|DbContext\|Migration\|CacheService\|QueueClient)` |
| `SHARED_LIB_AS_MODULE` | Shared libraries (utils, common, core, shared) list là module | Module name matches `^(shared|common|utils|core|kernel)` |
| `PHANTOM_MODULE` | Module không có code project tương ứng | Từ mapping algorithm |

---

## Mapping Schema (Step 4.4)

```json
{
  "generated_at": "ISO 8601",
  "mappings": [
    {
      "doc_module": "crm",
      "code_project": "Eureka.Modules.CRM",
      "type": "standalone",
      "file_count": 246,
      "source_file_prefixes": ["src/Modules/CRM/"]
    },
    {
      "doc_module": "delivery",
      "code_project": "Eureka.Modules.TMS",
      "type": "subdomain",
      "parent": "tms",
      "file_count": 35
    },
    {
      "doc_module": "auth",
      "code_project": "Eureka.Infrastructure/Authentication",
      "type": "cross-cutting",
      "file_count": 18
    },
    {
      "doc_module": "shared-kernel",
      "code_project": "Eureka.SharedKernel",
      "type": "shared-library",
      "file_count": 42
    }
  ],
  "warnings": [
    {
      "type": "AUTH_MISPLACED",
      "detail": "LoginCommand.cs found in CRM module",
      "files": ["src/Modules/CRM/Features/Login/LoginCommand.cs"]
    },
    {
      "type": "PHANTOM_MODULE",
      "modules": ["delivery", "driver", "transport"],
      "reason": "Các modules này không map được với code project nào — có thể là sub-domain của TMS"
    },
    {
      "type": "INFRA_AS_FEATURE",
      "modules": ["infrastructure-persistence", "shared-kernel"],
      "reason": "Các modules này là infrastructure/shared libraries, không phải business features"
    },
    {
      "type": "NAMING_VARIANTS_MERGED",
      "canonical": "crm",
      "merged_from": ["CRM", "Crm", "customer-relationship-management"]
    }
  ],
  "stats": {
    "standalone_modules": 5,
    "subdomain_modules": 3,
    "cross_cutting": 2,
    "shared_libraries": 1,
    "phantom_modules": 0
  }
}
```

---

## User Confirmation UI (Step 4.5)

Hiển thị bảng summary trước khi hỏi:

```
## Module-Code Alignment Summary

| Module | Code Project | Type | Action Suggestion |
|--------|-------------|------|-------------------|
| crm | Eureka.Modules.CRM | standalone | Keep as-is |
| delivery | Eureka.Modules.TMS | subdomain | Merge into 'tms' |
| auth | Eureka.Infrastructure/Authentication | cross-cutting | Move to system='infrastructure' |
| shared-kernel | Eureka.SharedKernel | shared-library | Exclude from business modules |

## Warnings
- AUTH_MISPLACED: LoginCommand.cs found in CRM module (1 file)
- PHANTOM_MODULE: 'driver' module không có code project tương ứng

## Questions

Q1: Có muốn merge subdomain modules vào parent? (Y/N)
    → Y sẽ merge 'delivery' → 'tms'

Q2: Có muốn re-classify cross-cutting modules? (Y/N)
    → Y sẽ chuyển 'auth' sang system='infrastructure'
```

**AskUserQuestion call:** hỏi 2 questions trên.

**Xử lý response:**
- Q1=Y → merge logic: append requirements/features của subdomain vào parent module, xóa subdomain file
- Q1=N → giữ nguyên, chỉ log note trong mapping
- Q2=Y → update `system` field trong extracted/{module}.json cho cross-cutting modules
- Q2=N → giữ nguyên

---

## Merge Logic (Step 4.6 — khi user confirm Q1=Y)

```
FOR each subdomain IN mappings where type == "subdomain" AND user confirms:
  parent_file = extracted/{parent}.json
  subdomain_file = extracted/{subdomain}.json
  
  parent_data = read parent_file
  subdomain_data = read subdomain_file
  
  # Append requirements + features
  parent_data.requirements.extend(subdomain_data.requirements)
  parent_data.features.extend(subdomain_data.features)
  
  # Update IDs để tránh conflict — prefix với parent module
  # TMP-DELIVERY-001 → TMP-TMS-DELIVERY-001
  FOR r IN subdomain_data.requirements:
    r.id = r.id.replace(f"TMP-{subdomain.upper()}-", f"TMP-{parent.upper()}-{subdomain.upper()}-")
  
  # Update stats
  parent_data.stats = recompute_stats(parent_data)
  
  write parent_file
  delete subdomain_file
  
  Log: "Merged {subdomain} → {parent} (N requirements, M features)"
```

---

## POST-GATE

- [ ] `module-code-mapping.json` tồn tại và non-empty
- [ ] `jq '.' module-code-mapping.json` pass (valid JSON)
- [ ] `jq '.mappings | length > 0'` pass (có ít nhất 1 mapping)
- [ ] Tất cả `doc_module` trong mappings khớp normalized names từ Phase 1
- [ ] `warnings[]` được populate (ít nhất empty array)
- [ ] `stats` object hoàn chỉnh
- [ ] `$MODULE_CODE_MAPPING` set cho Phase 5
- [ ] Nếu user confirm merges → tương ứng extracted files đã được update/deleted

**Next phase:** `phase5-verify.md`
