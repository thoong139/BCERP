# F4 — Registry SAFE-UPDATE Procedure (CORE-008, CORE-006)

## Quy tắc SAFE-UPDATE

| Rule | Bắt buộc |
|------|----------|
| Chỉ field `impl_status` được modify | YES (CORE-006) |
| KHÔNG downgrade từ `done` | YES (CORE-008) |
| `impl_status` chỉ 4 giá trị: `not_started`, `in_progress`, `done`, `skipped` | YES (CORE-010) |
| Atomic write (build → validate → tmp+mv) | YES (CORE-035) |
| Chỉ update REQ-ID có trong registry.requirements[] | YES |

## Implementation

```bash
registry_safe_update() {
  local REQ_ID="$1"
  local NEW_STATUS="$2"
  local REGISTRY=".mc-data/docs/_meta/req-registry.json"
  
  # Skip if no REQ_ID (entry không link tới registry)
  [ -z "$REQ_ID" ] || [ "$REQ_ID" = "null" ] && return 0
  
  # Validate NEW_STATUS enum
  case "$NEW_STATUS" in
    "not_started"|"in_progress"|"done"|"skipped") ;;
    *) echo "ERROR E045: Invalid impl_status $NEW_STATUS"; return 1;;
  esac
  
  # Read current status
  CURRENT=$(jq -r --arg id "$REQ_ID" '.requirements[] | select(.req_id==$id) | .impl_status // "not_found"' "$REGISTRY")
  
  if [ "$CURRENT" = "not_found" ]; then
    echo "WARN: REQ-ID $REQ_ID không tồn tại trong registry, skip update"
    return 0
  fi
  
  # CORE-008: không downgrade từ "done"
  if [ "$CURRENT" = "done" ] && [ "$NEW_STATUS" != "done" ]; then
    echo "WARN E045: Refused to downgrade $REQ_ID from done to $NEW_STATUS"
    return 1
  fi
  
  # Build new content (chỉ update impl_status field, giữ nguyên các field khác — CORE-006)
  jq --arg id "$REQ_ID" --arg status "$NEW_STATUS" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    (.requirements[] | select(.req_id==$id) | .impl_status) = $status |
    (.requirements[] | select(.req_id==$id) | .last_updated) = $now
  ' "$REGISTRY" > "$REGISTRY.tmp"
  
  # Validate (CORE-009 schema check)
  jq -e '.requirements | length > 0' "$REGISTRY.tmp" > /dev/null || {
    rm "$REGISTRY.tmp"
    exit_with E046
  }
  
  # Verify schema_version unchanged
  SCHEMA_BEFORE=$(jq -r '.schema_version' "$REGISTRY")
  SCHEMA_AFTER=$(jq -r '.schema_version' "$REGISTRY.tmp")
  [ "$SCHEMA_BEFORE" = "$SCHEMA_AFTER" ] || {
    echo "ERROR E046: schema_version changed unexpectedly"
    rm "$REGISTRY.tmp"
    exit_with E046
  }
  
  # Atomic move
  mv "$REGISTRY.tmp" "$REGISTRY"
  
  echo "Registry updated: $REQ_ID impl_status $CURRENT → $NEW_STATUS"
}
```

## Multi-REQ Update (Batch — same FEAT-ID)

Nếu IMPL-REQ entry có multiple req_ids (rare nhưng possible):

```bash
# Read req_ids array
REQ_IDS=$(jq -r '.entries[] | select(.id==$id) | .req_ids[]?' "$IMPL_REQ" --arg id "$IMPL_REQ_ID")

for RID in $REQ_IDS; do
  registry_safe_update "$RID" "done"
done
```

## FEAT-ID impl_status Update

Some features track impl_status at feature level (in addition to requirements):

```bash
# Update FEAT-ID impl_status nếu tất cả REQ-IDs of feature đều done
FEAT_REQ_IDS=$(jq -r --arg fid "$FEAT_ID" '.features[] | select(.feat_id==$fid) | .req_ids[]' "$REGISTRY")

ALL_DONE=true
for RID in $FEAT_REQ_IDS; do
  STATUS=$(jq -r --arg id "$RID" '.requirements[] | select(.req_id==$id) | .impl_status' "$REGISTRY")
  [ "$STATUS" != "done" ] && ALL_DONE=false
done

if [ "$ALL_DONE" = "true" ]; then
  jq --arg fid "$FEAT_ID" '
    (.features[] | select(.feat_id==$fid) | .impl_status) = "done"
  ' "$REGISTRY" > "$REGISTRY.tmp"
  jq -e '.features | length > 0' "$REGISTRY.tmp" > /dev/null && mv "$REGISTRY.tmp" "$REGISTRY"
fi
```

## POST-GATE Cross-Reference Check

Sau F4 complete, verify:

```bash
# 1. Mỗi IMPL-REQ status=done → REQ-ID đã có impl_status=done trong registry
DONE_IMPL_REQS=$(jq -r '.entries[] | select(.status=="done") | .req_id // ""' "$IMPL_REQ")
for RID in $DONE_IMPL_REQS; do
  [ -z "$RID" ] && continue
  STATUS=$(jq -r --arg id "$RID" '.requirements[] | select(.req_id==$id) | .impl_status' "$REGISTRY")
  if [ "$STATUS" != "done" ]; then
    echo "ERROR E048: $RID impl_status=$STATUS, expected done"
    exit_with E048
  fi
done

# 2. Không có IMPL-REQ status=done nhưng REQ-ID impl_status còn not_started (mismatch)
# 3. Tất cả impl-log.json entries có valid delegate_session_id
```

## Anti-Pattern Prevention

- ❌ KHÔNG modify other fields ngoài impl_status + last_updated
- ❌ KHÔNG batch update nhiều REQ trong 1 jq (mỗi REQ-ID 1 atomic operation)
- ❌ KHÔNG hardcode `not_started` → `done` mà không qua `in_progress`
- ❌ KHÔNG silent fail khi REQ-ID không tồn tại (luôn log WARN)
