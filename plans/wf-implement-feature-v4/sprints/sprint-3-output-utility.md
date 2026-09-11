# Sprint 3 — Output Utility

**Goal:** impl-status.json schema v2.0 + consumer_hints + global decision registry
**Estimated effort:** 3h
**Dependencies:** Sprint 2 complete (profile + cache established)
**Output:** v4.0.0-rc1 — output usable by downstream skills

---

## Mục tiêu cụ thể

1. **G7 fix:** impl-status.json `schema_version="2.0"` + `consumer_hints` section
2. **G9 fix:** Global decision registry tại `.mc-data/docs/_meta/decision-registry.global.json`
3. impl-report.md template v2.0 với "For Downstream Skills" section
4. phase-summary.md template v2.0 với "Cho skill kế tiếp" section
5. CLAUDE.md §4a + §4b cập nhật cho global decision-registry

---

## Steps chi tiết

### Step 3.1 — Bump templates/impl-status.json schema

**File:** `.claude/skills/workflow/wf-implement-feature/templates/impl-status.json`

**Add fields:**
```json
{
  "schema_version": "2.0",
  "session_id": "<auto-populated>",

  // ... existing fields v3.4.0 ...

  "profile": "<resolved profile: quick|standard|deep|exhaustive>",
  "cache_hits": {
    "existing_patterns": false,
    "saved_tokens_estimated": 0
  },

  "consumer_hints": {
    "wf-prepare-deployment": {
      "files_for_changelog": [],
      "breaking_changes": [],
      "migrations_required": false,
      "feature_summary_vi": ""
    },
    "wf-fix-bugs": {
      "scope_modules": [],
      "test_files_added": [],
      "decision_ids_new": [],
      "implementation_strategy_used": ""
    },
    "wf-verify-sync": {
      "req_ids_completed": [],
      "files_with_req_id": 0,
      "session_dir": ""
    }
  }
}
```

**Update templates/impl-status.schema.md:**
- Add schema_version field constraint: `enum: ["2.0"]`
- Add consumer_hints schema definition
- Update validation jq commands

---

### Step 3.2 — Update phase6-finalize.md: populate consumer_hints

**Add Step 6.5b:** Populate consumer_hints

```bash
# Files for changelog: changed source files (excluding tests)
FILES_FOR_CHANGELOG=$(jq -c '[.files_created[]?, .files_modified[]?] | map(select(. | endswith(".test.ts") or endswith(".spec.ts") | not))' impl-status.json)

# Breaking changes detection: parse decision-registry for breaking decisions
BREAKING=$(jq -c '[.decisions[] | select(.is_breaking == true) | .id]' decision-registry.json)

# Migrations required
MIGRATIONS_REQUIRED=$(jq -e '[.files_created[]?] | any(test("/migrations/"))' impl-status.json)

# Update impl-status.json
TMP=$(mktemp)
jq --argjson fc "$FILES_FOR_CHANGELOG" \
   --argjson br "$BREAKING" \
   --argjson mr "$MIGRATIONS_REQUIRED" \
   '.consumer_hints["wf-prepare-deployment"] = {
       files_for_changelog: $fc,
       breaking_changes: $br,
       migrations_required: $mr,
       feature_summary_vi: .feature.title
    }
    | .consumer_hints["wf-fix-bugs"] = {
       scope_modules: [.feature.module_path],
       test_files_added: [.files_created[]? | select(test("\\.test\\.|\\.spec\\."))],
       decision_ids_new: $br,
       implementation_strategy_used: .scenario
    }
    | .consumer_hints["wf-verify-sync"] = {
       req_ids_completed: [.feature.req_id],
       files_with_req_id: (.files_created | length),
       session_dir: $ENV.SESSION_DIR
    }' impl-status.json > "$TMP" && mv "$TMP" impl-status.json
```

---

### Step 3.3 — Update impl-report.md template

**Add section:**

```markdown
## For Downstream Skills

This implementation produces machine-readable hints for downstream skills:

### `/wf-prepare-deployment --from-impl=$FEATURE_SLUG`
- Files for CHANGELOG: see `consumer_hints.wf-prepare-deployment.files_for_changelog`
- Breaking changes: see `consumer_hints.wf-prepare-deployment.breaking_changes`
- Migrations required: see `consumer_hints.wf-prepare-deployment.migrations_required`

### `/wf-fix-bugs --from-impl=$FEATURE_SLUG`
- Scope: limited to module(s) in `consumer_hints.wf-fix-bugs.scope_modules`
- Test files added: tracked
- New decisions registered: tracked

### `/wf-verify-sync --from-impl=$FEATURE_SLUG`
- REQ-IDs completed: tracked
- Files with REQ-ID comment: tracked
```

---

### Step 3.4 — Tạo decision-registry.global.json schema + template

**File:** `.claude/skills/workflow/wf-implement-feature/templates/decision-registry-global.json`

```json
{
  "schema_version": "1.0",
  "decisions": []
}
```

**Decision entry schema:**
```json
{
  "id": "D-GLOBAL-001",
  "category": "data_modeling | api_design | error_handling | testing | other",
  "rule": "All deletions are soft delete (deleted_at column)",
  "reason": "Audit + recovery requirement",
  "scope": "project | module:<name> | feature:<slug>",
  "is_breaking": false,
  "added_by": {
    "skill": "wf-implement-feature",
    "feature_slug": "customer-management",
    "session_id": "2026-04-28-103045-laptop",
    "timestamp": "2026-04-28T10:35:00Z"
  },
  "feature_specific_overrides": []
}
```

---

### Step 3.5 — Update phase0-5-context-setup.md: read global

**Add new step:** 0.5b.1.5 — Read global decisions

```
Step 0.5b.1.5:
  IF test -f .mc-data/docs/_meta/decision-registry.global.json:
    GLOBAL_DECISIONS=$(jq '[.decisions[] | select(.scope == "project" or (.scope | startswith("module:")))]' .mc-data/docs/_meta/decision-registry.global.json)
  ELSE:
    GLOBAL_DECISIONS="[]"

  Append to $CONSTRAINT_LIST: format global decisions thành text rules
  Inject vào developer agent context (Phase 3 Agent prompt)
```

---

### Step 3.6 — Update phase3-tdd.md (Step 3.5): append global decisions

**Modify Step 3.5.2:**

```
Step 3.5.2: Với mỗi NEW DECISION:
  - Run Protocol 12.2 conflict check (đã có)
  - Append to $SESSION_DIR/decision-registry.json (đã có)
  - **NEW:** Determine scope:
    - Nếu decision chỉ áp dụng feature này → scope="feature:$FEATURE_SLUG"
    - Nếu áp dụng module → scope="module:$MODULE_SLUG"
    - Nếu áp dụng project → scope="project"
  - **NEW:** Acquire .decision-registry.lock → APPEND to .mc-data/docs/_meta/decision-registry.global.json → Release lock
```

---

### Step 3.7 — Update phase-summary.md template (CORE-028)

**Add section "Cho skill kế tiếp" (For Next Skill):**

```markdown
## Cho skill kế tiếp

Implementation này có thể được sử dụng bởi các skill sau:

### Triển khai (deployment)
- `/wf-prepare-deployment --from-impl=<FEATURE_SLUG>` để tự động tạo CHANGELOG và release notes

### Sửa lỗi (fix bugs)
- `/wf-fix-bugs --from-impl=<FEATURE_SLUG>` để focus fix scope vào features mới implement này

### Xác minh đồng bộ (verify sync)
- `/wf-verify-sync --from-impl=<FEATURE_SLUG>` để skip re-scan, chỉ verify REQ-IDs liệt kê

### Quyết định kiến trúc mới
- N decisions đã append vào `.mc-data/docs/_meta/decision-registry.global.json` (project-level)
- Future implementations sẽ tự động consume các decisions này
```

---

### Step 3.8 — Update CLAUDE.md §4a registry safe-write table

**Add row:**

```markdown
| `/wf-implement-feature` | `decision-registry.global.json` (decisions[]) | APPEND | Phase 3.5 — append project/module-level decisions. Per-feature decisions vẫn ghi vào $SESSION_DIR/decision-registry.json. Conflict check qua Protocol 12.2 trước khi append. Lock: `.decision-registry.lock`. |
```

---

### Step 3.9 — Update CLAUDE.md §4b output paths

**Update existing row + add new row:**

```markdown
| `/wf-implement-feature` Phase 6 | `.mc-data/docs/_meta/req-registry.json` (impl_status — UPDATE) | wf-preflight, wf-verify-sync |
| `/wf-implement-feature` Phase 6 | `.mc-data/work/wf-implement-feature/$FEATURE_SLUG/sessions/$SESSION_ID/impl-status.json` (v2.0 schema with consumer_hints) | OPTIONAL: `/wf-prepare-deployment --from-impl`, `/wf-fix-bugs --from-impl`, `/wf-verify-sync --from-impl` |
| `/wf-implement-feature` Phase 3.5 | `.mc-data/docs/_meta/decision-registry.global.json` (APPEND-only) | Future implementations (cross-feature consistency) |
```

---

## Definition of Done — Sprint 3

- [ ] `impl-status.json` schema v2.0 với `schema_version` + `consumer_hints` 3 sub-sections
- [ ] phase6-finalize.md populate consumer_hints khi finalize
- [ ] `impl-report.md` template có "For Downstream Skills" section
- [ ] `phase-summary.md` template có "Cho skill kế tiếp" section (Vietnamese)
- [ ] `decision-registry.global.json` schema defined + template
- [ ] phase0-5: read global decisions → inject vào constraints
- [ ] phase3-tdd: append global decisions với scope tag
- [ ] CLAUDE.md §4a + §4b cập nhật
- [ ] Smoke test: 2 implementations → global registry có decisions từ cả 2

---

## Risks Sprint 3

| Risk | Mitigation |
|------|-----------|
| Schema v2.0 break consumer skills cũ | Consumer skills CHƯA có --from-impl (Sprint 5+) → no break |
| Global decisions registry corrupt từ concurrent writes | Mutex `.decision-registry.lock` (đã có pattern trong _shared.md) |
| consumer_hints quá rộng → bloat impl-status.json | Mỗi sub-section ≤ 500 bytes; arrays cap 50 entries |
| Decision scope ambiguity (project vs module vs feature) | Default=feature; user prompt khi developer agent log decision không rõ scope |

---

## Output cho Sprint 4

- consumer_hints established → Sprint 4 thêm error-ledger references vào consumer_hints (e.g. "warnings_for_review")
- Global decisions có scope tags → Sprint 4 namespace error codes có thể reference scope
