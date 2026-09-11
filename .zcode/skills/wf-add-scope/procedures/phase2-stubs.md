# Phase 2 — Feature Stub Generation (LEGACY_MODE only)

> **Self-contained phase file.** CHỈ chạy khi `$LEGACY_MODE == true`.
> Với NEW project, feature creation được defer sang `/wf-define-features`.

---

## PRE-GATE

- Phase 1 POST-GATE PASSED
- `$LEGACY_MODE == true`
- `scope-spec.json` tồn tại và có `modules_to_add` non-empty

**Condition check:**

```
IF $LEGACY_MODE != true:
  SKIP Phase 2 entirely
  SET scope-spec.features_to_add = []
  UPDATE add-scope-status.json: phase_2.status = "skipped"
  → Jump to phase3-dryrun.md
```

---

## 📥 INPUT

- `$SESSION_DIR/scope-spec.json` (modules_to_add với code_refs)
- `.mc-data/work/legacy-scan/module-code-mapping.json`
- `.mc-data/docs/_meta/req-registry.json` (để inherit req_ids từ parent backend features)
- Code files trong `code_refs[]` của mỗi module

---

## 📤 OUTPUT

- `$SESSION_DIR/scope-spec.json` — **cập nhật** `features_to_add[]` + `summary`

---

## Steps

### Step 2.1 — [PAR] PARALLEL scan per module

**Execution mode:** PARALLEL (mỗi module độc lập).

```
FOR each module IN modules_to_add ([PAR] PARALLEL per module):
  code_path = module.code_refs[0]  # primary code reference

  IF !code_path OR !exists(code_path):
    LOG: "No code refs for module [module.id] → skip feature detection"
    CONTINUE

  # Detect sub-directories (mỗi sub = 1 feature)
  sub_dirs = glob("$code_path/*/")   # hoặc screens/ cho mobile apps
```

---

### Step 2.2 — Group code files theo sub-directory

```
FOR each sub_dir IN sub_dirs:
  sub_name = basename(sub_dir)   # VD: "activities", "campaigns", "customers"

  # Detect loose files (nếu có) — group theo file-prefix
  # VD: crm/activity-*.tsx → group thành "activity" feature
```

---

### Step 2.3 — Generate feature stub per sub-group

```
FOR each sub_dir (hoặc file-group):
  feature_id   = auto-increment "FEAT-[SYS_SHORT]-[MOD_SHORT]-NNN"
  feature_name = human-readable từ sub_name (VD: "activities" → "Quản lý Hoạt động CRM")

  # Inherit req_ids từ parent backend module (P1-5 fix: guard empty depends_on)
  IF module.depends_on.length > 0:
    parent_backend_mod = module.depends_on[0]   # VD: MOD-BACKEND-CRM
    parent_features    = registry.features WHERE module_id == parent_backend_mod
    req_ids_inherited  = UNION of parent_features.req_ids
  ELSE:
    LOG: "Module [module.id] has no backend dependency — req_ids will be empty"
    req_ids_inherited = []

  feature_stub = {
    id:            feature_id,
    module_id:     module.id,
    name:          feature_name,
    file:          "phase2-features/[sys-slug]/[mod-slug]/[feat-slug].md",
    dependencies:  [parent_backend_features],   # UI depends on backend features
    req_ids:       req_ids_inherited,
    priority:      "MEDIUM",
    phase:         1,
    cross_system:  true,                         # UI cross-references backend
    impl_status:   "not_started",                # Will be updated bởi legacy code scan later
    code_refs:     [sub_dir],
    stub:          true                          # Mark as auto-generated cho review
  }
```

---

### Step 2.4 — Append vào scope-spec.json

```
MERGE all feature_stubs across all modules
UPDATE scope-spec.json:
  features_to_add = [all generated features]
  summary.total_features_proposed = count
  summary.total_features_to_add   = count
  summary.total_features_skipped  = 0
```

**Atomic write pattern:**

```bash
tmp=$(mktemp)
jq --argjson new_features "$NEW_FEATURES" \
   '.features_to_add = $new_features | .summary.total_features_proposed = ($new_features | length) | .summary.total_features_to_add = ($new_features | length)' \
   "$SESSION_DIR/scope-spec.json" > "$tmp" && \
mv "$tmp" "$SESSION_DIR/scope-spec.json"
```

---

## Ví dụ

```
Input:
  MOD-ERPWEB-CRM với code_refs = ["apps/erp-web/src/app/[locale]/(dashboard)/crm/"]

Sub-dirs detected:
  - crm/activities/    → FEAT-ERPWEB-CRM-001 "Quản lý Hoạt động CRM (UI)"
  - crm/campaigns/     → FEAT-ERPWEB-CRM-002 "Quản lý Chiến dịch CRM (UI)"
  - crm/customers/     → FEAT-ERPWEB-CRM-003 "Quản lý Khách hàng (UI)"
  - crm/contracts/     → FEAT-ERPWEB-CRM-004 "Quản lý Hợp đồng CRM (UI)"
  - crm/feedback/      → FEAT-ERPWEB-CRM-005 "Quản lý Phản hồi KH (UI)"
```

---

## POST-GATE

- `scope-spec.json.features_to_add` non-empty (HOẶC user confirmed không cần features)
- Mỗi feature entry có đủ: `id`, `module_id`, `name`, `file`, `req_ids`, `stub: true`
- `summary.total_features_*` consistent
- `add-scope-status.json.phases.phase_2.status` = `"completed"`

---

## Next Phase

→ Load `phase3-dryrun.md` để generate diff preview.
