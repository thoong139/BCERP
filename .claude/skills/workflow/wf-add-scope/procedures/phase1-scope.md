# Phase 1 — Scope Specification

> **Self-contained phase file.** Build `scope-spec.json` — danh sách modules cần thêm, từ 3 nguồn input khác nhau.

---

## PRE-GATE

- Phase 0 POST-GATE PASSED
- `$SYSTEM_ID` set và đã validate
- `$LEGACY_MODE`, `$FROM_MAPPING`, `$MODULES_LIST`, `$INTERACTIVE` flags đã parse

---

## 📥 INPUT

- Flags từ `$ARGUMENTS` (đã parse ở Phase 0)
- `.mc-data/docs/_meta/req-registry.json` (cho dedup check)
- **Conditional:** `.mc-data/work/legacy-scan/module-code-mapping.json` (chỉ khi `$FROM_MAPPING`)
- **Conditional:** `.mc-data/work/wf-brainstorm/legacy-decisions.json` (CORE-022 enforcement)

---

## 📤 OUTPUT

| File | Template |
|---|---|
| `$SESSION_DIR/scope-spec.json` | `templates/scope-spec.json` |

---

## Steps

### Step 1.1 — Chọn input source

```
IF $FROM_SCAN non-empty:
  # Sprint 5 cross-skill — OPTIONAL flag
  source = "from-scan"
ELIF $FROM_MAPPING:
  assert $LEGACY_MODE == true  # (đã check ở Phase 0)
  source = "from-mapping"
ELIF $MODULES_LIST non-empty:
  source = "modules-list"
ELIF $INTERACTIVE:
  source = "interactive"
ELSE:
  STOP E002: "Cần --from-scan HOẶC --from-mapping HOẶC --modules HOẶC --interactive"
```

---

### Step 1.2 — Build `scope-spec.json` (Template Usage Rule)

**📋 Áp dụng Template Usage Rule:**

```
READ templates/scope-spec.json

# Build modules_to_add[] theo source logic (xem Input Source Logic bên dưới)
# Mỗi module entry BẮT BUỘC có:
#   id, sys_id, name, description, project, depends_on, depts, code_refs

# Module ID format: MOD-[SYS_SHORT]-[DOMAIN] — xem _shared.md §4

POPULATE:
  - version: "1.0"
  - created_at: ISO timestamp
  - source: $source
  - target_system: $SYSTEM_ID
  - legacy_mode: $LEGACY_MODE
  - modules_to_add: [...] (từ Input Source Logic)
  - features_to_add: []          # Phase 2 sẽ fill nếu LEGACY_MODE
  - existing_conflicts: []       # Step 1.3 sẽ fill
  - summary: { all counts = 0 }  # Step 1.3 sẽ update

WRITE $SESSION_DIR/scope-spec.json
```

---

#### Input Source Logic

**D) `--from-scan=<session-id|path>` (Sprint 5 cross-skill — OPTIONAL):**

```
# Resolve target-map.json path
IF $FROM_SCAN matches "{YYYY-MM-DD}-..." pattern:
  TARGET_MAP=".mc-data/work/wf-scan-target/sessions/$FROM_SCAN/target-map.json"
ELSE:
  # P0-2 fix: restrict to .mc-data/ directory only
  IF $FROM_SCAN does NOT start with ".mc-data/" AND NOT start with "/":
    STOP E008: "--from-scan path phải trong .mc-data/ directory. Got: $FROM_SCAN"
  TARGET_MAP="$FROM_SCAN"

# Validate file exists
IF NOT test -f "$TARGET_MAP":
  STOP E008: "target-map.json không tìm thấy tại: $TARGET_MAP"

# Validate v2 schema (Sprint 5 — backward-compat: chấp nhận v1 nhưng warn)
SCHEMA=$(jq -r '.["$schema"] // "v1"' "$TARGET_MAP")
IF SCHEMA != "target-map-v2":
  WARN: "target-map.json là $SCHEMA — Sprint 5 expect target-map-v2.
        consumer_hints có thể không đầy đủ — tiếp tục với best-effort."

# P1-6 fix: validate consumer_hints exists before proceeding
CONSUMER_HINTS_EXISTS=$(jq -r 'has("consumer_hints") and (.consumer_hints | has("wf-add-scope"))' "$TARGET_MAP")
IF CONSUMER_HINTS_EXISTS != "true":
  STOP E008: "target-map.json không chứa consumer_hints cho wf-add-scope.
  Đảm bảo /wf-scan-target chạy với Sprint 5+ version."

# Read consumer_hints + module_code_mapping
READY=$(jq -r '.consumer_hints["wf-add-scope"].ready // false' "$TARGET_MAP")
IF READY != "true":
  WARN: "consumer_hints['wf-add-scope'].ready = false — scan có thể chưa map modules.
        Kiểm tra modules_to_seed manual."

MODULES_TO_SEED=$(jq -r '.consumer_hints["wf-add-scope"].modules_to_seed // [] | .[]' "$TARGET_MAP")
MODULE_CODE_MAPPING=$(jq -c '.module_code_mapping // {}' "$TARGET_MAP")
SCAN_TARGET=$(jq -r '.target' "$TARGET_MAP")
SCAN_TECH=$(jq -r '.tech_stack | join(", ")' "$TARGET_MAP")

# Build module entries từ MODULES_TO_SEED
FOR each mod_slug IN MODULES_TO_SEED:
  paths=$(jq -r --arg s "$mod_slug" '.[$s] // [] | .[]' <<< "$MODULE_CODE_MAPPING")
  module_id   = "MOD-[SYS_SHORT]-[MOD_UPPER]"  # giống logic A
  name        = "[SYSTEM_NAME] — [mod_slug] (từ scan-target)"
  sys_id      = $SYSTEM_ID
  description = "Module derived from /wf-scan-target session $FROM_SCAN. Target: $SCAN_TARGET. Tech: $SCAN_TECH"
  depends_on  = []          # user bổ sung sau
  depts       = []
  project     = first path từ paths
  code_refs   = paths       # tất cả paths từ module_code_mapping[mod_slug]

# Optional: append features_to_seed (nếu consumer_hints có)
features_to_seed = jq -c '.consumer_hints["wf-add-scope"].features_to_seed // []' "$TARGET_MAP"
# Phase 2 sẽ pickup nếu LEGACY_MODE; nếu không, defer sang /wf-define-features
```

**A) `--from-mapping` (LEGACY_MODE required):**

```
READ module-code-mapping.json
FILTER mappings WHERE code_path MATCHES "apps/[sys-slug]/" pattern của $SYSTEM_ID

FOR each mapping:
  module_id   = "MOD-[SYS_SHORT]-[MODULE_UPPER]"  # VD: MOD-ERPWEB-CRM
  name        = "[SYSTEM_NAME] — [Module Name] UI"  # VD: "ERP Web — CRM UI"
  sys_id      = $SYSTEM_ID
  description = "Frontend [tech_stack] cho [domain]. Code: [code_path]"
  depends_on  = auto-detect từ backend mapping (nếu có MOD-BACKEND-[UPPER])
  depts       = inherit từ parent backend module (nếu có)
  project     = code_path
  code_refs   = [code_path]  # custom field cho downstream skills
```

**B) `--modules=<list>`:**

```
SPLIT list by comma → [mod1, mod2, ...]

FOR each mod_name:
  module_id   = "MOD-[SYS_SHORT]-[MOD_UPPER]"
  name        = prompt nếu $INTERACTIVE, else "[SYSTEM_NAME] — [mod_name] Module"
  sys_id      = $SYSTEM_ID
  description = prompt nếu $INTERACTIVE, else "[mod_name] module cho [system_name]"
  depends_on  = []  # user bổ sung sau nếu cần
  depts       = []
  project     = prompt nếu $INTERACTIVE, else null
  code_refs   = []
```

**C) `--interactive`:**

```
AskUserQuestion: "Bạn muốn thêm bao nhiêu modules cho $SYSTEM_ID?"
FOR each module (theo số user đã nhập):
  AskUserQuestion cho: id, name, description, depends_on, depts, project
```

---

### Step 1.3 — Dedup + Legacy Decisions Respect

**A) Dedup với registry hiện có:**

```
FOR each module IN modules_to_add:
  IF module.id EXISTS in registry.modules[]:
    MOVE module from modules_to_add → existing_conflicts[]
    APPEND conflict: {
      entry_type: "module",
      entry_id:   module.id,
      reason:     "Already exists in registry",
      action:     "skip"
    }
  ELIF EXISTS registry.modules[] WHERE .name == module.name AND .sys_id == module.sys_id:
    RENAME module.id → module.id + "-2"
    LOG: "Renamed duplicate name: [module.name] → [module.id]-2"
```

**B) Legacy Decisions Respect (CORE-022):**

Xem `_shared.md §8`. Nếu `legacy-decisions.json` tồn tại:

```
deprecated_modules = jq '.deprecated_modules // []' legacy-decisions.json

FOR each module IN modules_to_add:
  IF module.id IN deprecated_modules:
    REMOVE from modules_to_add
    APPEND conflict: {
      entry_type: "module",
      entry_id:   module.id,
      reason:     "Marked DEPRECATED in legacy-decisions.json",
      action:     "skip"
    }
    LOG: "Module [module.id] is DEPRECATED per legacy-decisions — skipped"
```

**C) Update summary:**

```
UPDATE scope-spec.json.summary:
  total_modules_proposed = original count (trước dedup)
  total_modules_to_add   = modules_to_add.length (sau dedup)
  total_modules_skipped  = existing_conflicts.length
```

---

### Step 1.4 — Validate module entries

```
FOR each module IN modules_to_add:
  ASSERT module.id non-empty
  ASSERT module.name non-empty
  ASSERT module.sys_id == $SYSTEM_ID
  ASSERT module.description non-empty

IF any assertion fails → STOP, hiển thị invalid entries cho user.
```

---

## scope-spec.json Schema (Reference)

```json
{
  "version": "1.0",
  "created_at": "YYYY-MM-DDTHH:mm:ssZ",
  "source": "from-mapping | modules-list | interactive | from-scan",
  "target_system": "SYS-ERP-WEB",
  "legacy_mode": false,
  "modules_to_add": [
    {
      "id": "MOD-ERPWEB-CRM",
      "sys_id": "SYS-ERP-WEB",
      "name": "ERP Web — CRM UI",
      "description": "Frontend Next.js cho quản lý khách hàng — kết nối MOD-BACKEND-CRM",
      "project": "apps/erp-web",
      "depends_on": ["MOD-BACKEND-CRM"],
      "depts": ["DEPT-SALES", "DEPT-CSKH"],
      "code_refs": ["apps/erp-web/src/app/[locale]/(dashboard)/crm/"]
    }
  ],
  "features_to_add": [],
  "existing_conflicts": [
    {
      "entry_type": "module",
      "entry_id": "MOD-ERPWEB-CRM",
      "reason": "Already exists in registry",
      "action": "skip"
    }
  ],
  "summary": {
    "total_modules_proposed": 0,
    "total_modules_to_add": 0,
    "total_modules_skipped": 0,
    "total_features_proposed": 0,
    "total_features_to_add": 0,
    "total_features_skipped": 0
  }
}
```

---

## POST-GATE

- `scope-spec.json` tồn tại và valid JSON (`jq '.' scope-spec.json`)
- `modules_to_add` non-empty (hoặc WARNING E006 nếu tất cả đã tồn tại)
- Mọi entry có đủ fields bắt buộc
- `summary.total_modules_*` consistent với `modules_to_add.length` + `existing_conflicts.length`
- `add-scope-status.json.phases.phase_1.status` = `"completed"`

---

## Next Phase

- **IF `$LEGACY_MODE == true`:** → Load `phase2-stubs.md` để auto-detect features
- **ELSE:** → Load `phase3-dryrun.md` (skip Phase 2, features defer sang `/wf-define-features`)
