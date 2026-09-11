# impl-status.json — Schema & Enum Constraints

> Constraints không hardcode trong template values (vì làm JSON content invalid).
> Skill code phải tham chiếu file này để validate trước khi WRITE.
>
> **v2.0 (Sprint 3, 2026-04-28):** Thêm `schema_version`, `session_id`, `profile`, `cache_hits`, `consumer_hints`.
> Backward compat: skill đọc cả v1 (không có `schema_version` field) và v2. Khi write → luôn dùng v2.0.

## Top-level fields

| Field | Type | Allowed values | Required |
|-------|------|----------------|----------|
| `$schema` | string | `"impl-status-v1"` (legacy) hoặc `"impl-status-v2"` (v2.0+) | yes |
| `schema_version` | string | `"2.0"` (literal) — absent trong v1 files | v2.0+ |
| `impl_id` | string | Pattern `IMPL-YYYYMMDD-NNN` | yes |
| `session_id` | string | Format `{YYYY-MM-DD}-{HHMMSS}-{shorthost}` (v4.0+ session isolation) | v2.0+ |
| `scenario` | enum | `new` \| `extend` \| `modify` | yes |
| `status` | enum | `not_started` \| `in_progress` \| `completed` \| `error` \| `paused` | yes |
| `progress_pct` | int | 0-100 | yes |
| `current_session` | int | ≥1 | yes |
| `last_qa_attempt_number` | int | ≥0 | yes |
| `profile` | enum | `quick` \| `standard` \| `deep` \| `exhaustive` (Sprint 2 v4.0) | v2.0+ |
| `cache_hits` | object | `{existing_patterns: bool, saved_tokens_estimated: int}` | v2.0+ |
| `consumer_hints` | object | xem `consumer_hints` section bên dưới | v2.0+ |

## `feature` object

| Field | Type | Allowed values |
|-------|------|----------------|
| `req_id` | string | Pattern `REQ-[A-Z]+-[A-Z0-9-]+` |
| `name` | string | non-empty |
| `module` | string | non-empty (module ID hoặc name) |
| `system` | string | non-empty (system ID hoặc name) |
| `complexity` | enum | `simple` \| `medium` \| `complex` |

### Complexity derivation rule (BẮT BUỘC trong Phase 1.8)

Áp dụng theo thứ tự ưu tiên:

```
1. NẾU task file có "Effort Estimate" field:
   - ≤ 1h → "simple"
   - ≤ 4h → "medium"
   - > 4h → "complex"

2. NẾU không có effort estimate, fallback theo file count trong A2.4:
   - ≤ 3 files → "simple"
   - ≤ 10 files → "medium"
   - > 10 files → "complex"

3. NẾU không xác định được → default "medium"
```

## `phases.*.status` (mỗi phase)

Allowed values: `pending` | `in_progress` | `completed` | `skipped` | `error`

> **Phase 5a** thêm: `iterations_run`, `errors_found`, `errors_fixed` etc. — xem template chính.

## `phases.phase_5a.validation_details.*`

Allowed values: `pending` | `passed` | `fixed` | `failed`

## `tasks[].status`

Allowed values: `pending` | `in_progress` | `completed`

## `reviews.*.status`

Allowed values: `pending` | `in_progress` | `completed` | `skipped`

## `consumer_hints` (v2.0+ — Sprint 3)

Populated by phase6-finalize Step 6.5b. Consumer skills đọc qua `--from-impl` flag (Q1: chưa modify trong v4.0).

### `consumer_hints["wf-prepare-deployment"]`

| Field | Type | Mô tả | Constraint |
|-------|------|-------|------------|
| `files_for_changelog` | string[] | Files tạo/sửa exclude tests (`.test.*`, `.spec.*`) | ≤ 50 entries |
| `breaking_changes` | string[] | Decision IDs có `is_breaking=true` | ≤ 50 entries |
| `migrations_required` | bool | True nếu có file trong `/migrations/` path | — |
| `feature_summary_vi` | string | Tiếng Việt, ≤ 200 chars (default = `feature.name`) | non-empty khi populate |

### `consumer_hints["wf-fix-bugs"]`

| Field | Type | Mô tả | Constraint |
|-------|------|-------|------------|
| `scope_modules` | string[] | Module slugs (e.g. `["crm/customer"]`) | ≤ 10 entries |
| `test_files_added` | string[] | Files matching `\.(test\|spec)\.[a-z]+$` | ≤ 50 entries |
| `decision_ids_new` | string[] | Decisions thêm trong session (vào global registry) | ≤ 50 entries |
| `implementation_strategy_used` | enum | `IMPLEMENT_NEW` \| `COMPLETE_EXISTING` \| `VERIFY_ONLY` | yes |

### `consumer_hints["wf-verify-sync"]`

| Field | Type | Mô tả | Constraint |
|-------|------|-------|------------|
| `req_ids_completed` | string[] | REQ-IDs có `impl_status=done` sau session | ≥ 1 entry |
| `files_with_req_id` | int | Đếm files có comment `REQ-ID:` | ≥ 0 |
| `session_dir` | string | Absolute hoặc relative path từ project root | non-empty |

### Sub-section size cap

Mỗi sub-section ≤ 500 bytes khi serialize. Arrays cap 50 entries. Khi vượt cap → truncate + log warning (E102).

## `cache_hits` (v2.0+ — Sprint 3, populated bởi Phase 0 Pattern Cache Sprint 2)

| Field | Type | Mô tả |
|-------|------|-------|
| `existing_patterns` | bool | True khi pattern cache HIT (`implement-cache-resolver.sh --validate`) |
| `saved_tokens_estimated` | int | Estimate (default 8000 khi HIT, 0 khi MISS) — observability |

## `_state_mapping` (registry mapping — CORE-010)

| working file `status` | registry `impl_status` |
|----------------------|------------------------|
| `completed` | `done` |
| `in_progress` | `in_progress` |
| `not_started` | `not_started` |
| `error` | `in_progress` (chưa done) |
| `paused` | `in_progress` (chưa done) |

## Validation lệnh (Phase 1 POST-WRITE)

```bash
SCHEMA=".claude/skills/workflow/wf-implement-feature/templates/impl-status.schema.md"
TARGET=".mc-data/work/wf-implement-feature/$SYSTEM_SLUG/$FEATURE_SLUG/impl-status.json"

# Check enum: scenario
jq -e '.scenario as $s | ["new","extend","modify"] | index($s)' "$TARGET" >/dev/null \
  || { echo "INVALID scenario"; exit 1; }

# Check enum: status
jq -e '.status as $s | ["not_started","in_progress","completed","error","paused"] | index($s)' "$TARGET" >/dev/null \
  || { echo "INVALID status"; exit 1; }

# Check enum: complexity
jq -e '.feature.complexity as $c | ["simple","medium","complex"] | index($c)' "$TARGET" >/dev/null \
  || { echo "INVALID complexity"; exit 1; }

# Check pattern: impl_id
jq -e '.impl_id | test("^IMPL-[0-9]{8}-[0-9]{3}$")' "$TARGET" >/dev/null \
  || { echo "INVALID impl_id format"; exit 1; }

# Check pattern: req_id
jq -e '.feature.req_id | test("^REQ-[A-Z]+-[A-Z0-9-]+$")' "$TARGET" >/dev/null \
  || { echo "INVALID req_id format"; exit 1; }

# v2.0+ checks (skip nếu file là v1 — không có schema_version field)
HAS_VER=$(jq -r 'has("schema_version")' "$TARGET")
if [[ "$HAS_VER" == "true" ]]; then
  # schema_version literal "2.0"
  jq -e '.schema_version == "2.0"' "$TARGET" >/dev/null \
    || { echo "INVALID schema_version (expected 2.0)"; exit 1; }

  # profile enum
  jq -e '.profile as $p | ["quick","standard","deep","exhaustive"] | index($p)' "$TARGET" >/dev/null \
    || { echo "INVALID profile"; exit 1; }

  # consumer_hints structure (3 sub-sections required)
  jq -e '.consumer_hints | has("wf-prepare-deployment") and has("wf-fix-bugs") and has("wf-verify-sync")' "$TARGET" >/dev/null \
    || { echo "INVALID consumer_hints structure"; exit 1; }
fi
```
