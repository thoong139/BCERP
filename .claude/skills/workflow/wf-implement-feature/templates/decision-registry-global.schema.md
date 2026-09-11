# decision-registry.global.json — Schema & Constraints

> **Mục đích:** Cross-feature decision consistency. Single source of truth cho project/module-level decisions của toàn workspace.
>
> **Path:** `.mc-data/docs/_meta/decision-registry.global.json`
>
> **Owner (CORE-006):** `/wf-implement-feature` PRIMARY APPEND-only — Phase 3.5 (sau mỗi batch).
> Feature-level decisions vẫn ghi vào `$SESSION_DIR/decision-registry.json` (không thay thế).
>
> **Lock:** `.mc-data/docs/_meta/.decision-registry.lock` (cùng pattern Mutex của `_shared.md` Section §Cross-Process Mutex).

---

## Top-level fields

| Field | Type | Allowed values | Required |
|-------|------|----------------|----------|
| `$schema` | string | `"decision-registry-global-v1"` (literal) | yes |
| `schema_version` | string | `"1.0"` (literal) | yes |
| `created_at` | string | ISO-8601 UTC timestamp (`YYYY-MM-DDTHH:mm:ssZ`) | yes |
| `last_updated` | string | ISO-8601 UTC timestamp | yes |
| `decisions` | array | xem § Decision entry schema | yes (≥0 entries) |

## Decision entry schema

| Field | Type | Allowed values | Required |
|-------|------|----------------|----------|
| `id` | string | Pattern `D-GLOBAL-NNN` (sequential per file) | yes |
| `category` | enum | `data_modeling` \| `api_design` \| `error_handling` \| `testing` \| `breaking` \| `security` \| `performance` \| `other` | yes |
| `rule` | string | One-sentence imperative rule (≤ 200 chars) | yes |
| `reason` | string | Brief justification (≤ 500 chars) | yes |
| `scope` | string | `project` \| `module:<slug>` \| `feature:<slug>` | yes |
| `is_breaking` | bool | True nếu break existing API/contract | optional (default false) |
| `added_by` | object | xem § `added_by` object | yes |
| `feature_specific_overrides` | array | List feature slugs có override decision này | optional (default []) |

### `added_by` object

| Field | Type | Constraint |
|-------|------|------------|
| `skill` | string | `"wf-implement-feature"` (literal cho v4.0) |
| `feature_slug` | string | Feature slug (v3.3+ Vietnamese-safe slug) |
| `session_id` | string | Format `{YYYY-MM-DD}-{HHMMSS}-{shorthost}` |
| `timestamp` | string | ISO-8601 UTC |

### Scope semantics

- **`project`** — Áp dụng toàn project (e.g. "All deletions are soft delete"). High-priority constraint cho mọi future feature.
- **`module:<slug>`** — Áp dụng cho 1 module cụ thể (e.g. `module:crm/customer`). Future features cùng module phải tuân thủ.
- **`feature:<slug>`** — Áp dụng cho 1 feature riêng. **KHÔNG nên append** vào global registry — đã có per-feature `decision-registry.json`. Chỉ dùng khi feature có cross-cutting concern affect future implementations.

## APPEND-only safe-write rule (CORE-006)

```
QUY TẮC:
1. Acquire lock `.decision-registry.lock` qua `implement-acquire-lock.sh --type=registry --target=decision-registry`
2. Read existing decisions[] (preserve nguyên vẹn)
3. Conflict check (Protocol 12.2): rule mới không được contradict existing rules cùng scope
4. Append new entry vào cuối decisions[] với id = "D-GLOBAL-{N+1}" (N = current length)
5. Update `last_updated`
6. Atomic write: tmp → mv
7. Release lock
8. Validate: jq -e '.decisions | length > 0' decision-registry.global.json
```

## Conflict detection (Protocol 12.2)

Trước khi append, kiểm tra:

```bash
# Cùng scope + cùng category → có thể conflict
EXISTING_RULES=$(jq -r --arg sc "$NEW_SCOPE" --arg cat "$NEW_CATEGORY" \
  '.decisions[] | select(.scope == $sc and .category == $cat) | .rule' \
  decision-registry.global.json)

# Nếu có rule existing similar → escalate user (CDG-04 hoặc warn)
if [[ -n "$EXISTING_RULES" ]]; then
  echo "WARN: Existing rule(s) in scope=$NEW_SCOPE category=$NEW_CATEGORY:"
  echo "$EXISTING_RULES"
  echo "New rule: $NEW_RULE"
  echo "Append anyway? (y/N)"
fi
```

## Validation lệnh

```bash
TARGET=".mc-data/docs/_meta/decision-registry.global.json"

# JSON valid
jq empty "$TARGET" || { echo "INVALID JSON"; exit 1; }

# Schema_version literal
jq -e '.schema_version == "1.0"' "$TARGET" >/dev/null \
  || { echo "INVALID schema_version"; exit 1; }

# Decision IDs pattern + uniqueness
jq -e '
  .decisions
  | map(.id | test("^D-GLOBAL-[0-9]+$"))
  | all
' "$TARGET" >/dev/null \
  || { echo "INVALID decision IDs format"; exit 1; }

jq -e '
  .decisions | map(.id) | (length == (unique | length))
' "$TARGET" >/dev/null \
  || { echo "DUPLICATE decision IDs"; exit 1; }

# Scope enum
jq -e '
  .decisions
  | map(.scope | test("^(project|module:[a-z0-9/-]+|feature:[a-z0-9/-]+)$"))
  | all
' "$TARGET" >/dev/null \
  || { echo "INVALID scope values"; exit 1; }

# Category enum
jq -e '
  .decisions[]?.category as $c
  | ["data_modeling","api_design","error_handling","testing","breaking","security","performance","other"]
  | index($c)
' "$TARGET" >/dev/null \
  || { echo "INVALID category"; exit 1; }
```

## Initialization (lazy)

File chỉ được tạo khi có decision đầu tiên cần append. Phase 0.5b read flow phải graceful nếu file chưa tồn tại:

```bash
GLOBAL_REG=".mc-data/docs/_meta/decision-registry.global.json"
if [[ -f "$GLOBAL_REG" ]]; then
  GLOBAL_DECISIONS=$(jq -c '[.decisions[] | select(.scope == "project" or (.scope | startswith("module:")))]' "$GLOBAL_REG")
else
  GLOBAL_DECISIONS="[]"
fi
```

Tạo file lần đầu (idempotent):

```bash
if [[ ! -f "$GLOBAL_REG" ]]; then
  TS=$(date -u +%FT%TZ)
  jq -n --arg ts "$TS" '{
    "$schema": "decision-registry-global-v1",
    schema_version: "1.0",
    created_at: $ts,
    last_updated: $ts,
    decisions: []
  }' > "$GLOBAL_REG"
fi
```

---

## Sample entry

```json
{
  "id": "D-GLOBAL-001",
  "category": "data_modeling",
  "rule": "All deletions use soft-delete (deleted_at TIMESTAMPTZ NULL column)",
  "reason": "Audit trail + data recovery requirement (compliance ERM)",
  "scope": "project",
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
