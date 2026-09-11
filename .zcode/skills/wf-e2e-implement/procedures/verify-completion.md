# F4 — Verify Delegate Completion Procedure

## Verification Flow per Receipt

```bash
# Receipt parsed (từ delegate-impl-feature.md)
IMPL_REQ_ID=$(echo "$RECEIPT" | jq -r '.impl_req_id')
REQ_ID=$(echo "$RECEIPT" | jq -r '.req_id')
IMPL_STATUS=$(echo "$RECEIPT" | jq -r '.impl_status_after')
REGISTRY_UPDATED=$(echo "$RECEIPT" | jq -r '.registry_updated')
CODE_REFS=$(echo "$RECEIPT" | jq -c '.code_refs')

# 1. Verify code files exist
echo "$CODE_REFS" | jq -c '.[]' | while read -r ref; do
  PATH=$(echo "$ref" | jq -r '.path')
  test -f "$PATH" || {
    echo "WARN: Code ref $PATH không tồn tại sau delegate"
    VERIFY_OK=false
  }
done

# 2. Verify registry update (if delegate claims registry_updated=true)
if [ "$REGISTRY_UPDATED" = "true" ]; then
  ACTUAL_STATUS=$(jq -r --arg id "$REQ_ID" '.requirements[] | select(.req_id==$id) | .impl_status' "$REGISTRY")
  EXPECTED_STATUS=$(echo "$RECEIPT" | jq -r '.registry_status_after')
  
  if [ "$ACTUAL_STATUS" != "$EXPECTED_STATUS" ]; then
    echo "WARN: Registry mismatch. Claimed=$EXPECTED_STATUS, Actual=$ACTUAL_STATUS"
    # F4 might need to fix (rare race condition)
    registry_safe_update "$REQ_ID" "$EXPECTED_STATUS"
  fi
fi

# 3. Verify wf-implement-feature impl-status.json (đọc delegate session)
DELEGATE_SESSION=$(echo "$RECEIPT" | jq -r '.delegate_session_id')
DELEGATE_IMPL_STATUS_FILE=".mc-data/work/wf-implement-feature/${DELEGATE_SESSION}/impl-status.json"

if [ -f "$DELEGATE_IMPL_STATUS_FILE" ]; then
  DELEGATE_FINAL_STATUS=$(jq -r '.final_status' "$DELEGATE_IMPL_STATUS_FILE")
  echo "Delegate final status: $DELEGATE_FINAL_STATUS"
fi
```

## Decision Tree

```
SWITCH IMPL_STATUS_AFTER:
  
  "done":
    Verify code refs exist + registry updated correctly
    → update_impl_req_entry status=done + implementer + delegate_session + code_refs
    → IF registry not updated → F4 do registry_safe_update fallback
    → append_impl_log success
    → continue next entry
  
  "in_progress":
    Delegate didn't finish completely (timeout suspected)
    → update_impl_req_entry status=skipped + note "delegate incomplete"
    → append_issue (medium severity)
    → continue
  
  "skipped":
    Delegate decided cannot implement (out of scope, missing dependency, etc.)
    → update_impl_req_entry status=skipped + note from receipt.errors
    → append_issue if appropriate (medium severity)
    → continue
```

## Registry Fallback Update

Nếu delegate claims `registry_updated=true` nhưng actual mismatch:

```bash
# F4 fallback (rare, but SAFE-UPDATE):
registry_safe_update "$REQ_ID" "$EXPECTED_STATUS"

# Log this discrepancy:
append_impl_log "$IMPL_REQ_ID" "registry_fallback" "F4 had to update registry manually due to delegate race"
```

## Update implement-required.json Final

```bash
# Success case
update_impl_req_entry "$IMPL_REQ_ID" "done" \
  "wf-implement-feature" \
  "$DELEGATE_SESSION" \
  "$CODE_REFS" \
  "Implemented + registry updated successfully"

# Skipped case
update_impl_req_entry "$IMPL_REQ_ID" "skipped" \
  "wf-implement-feature" \
  "$DELEGATE_SESSION" \
  "[]" \
  "Delegate could not complete: <reason>"
```

## Append impl-log.json

```jsonc
{
  "$schema": "wf-e2e-impl-log-v1",
  "session_id": "{SESSION_ID}",
  "entries": [
    {
      "impl_req_id": "IMPL-REQ-001",
      "req_id": "REQ-CRM-001",
      "started_at": "2026-05-13T18:00:00Z",
      "completed_at": "2026-05-13T18:25:00Z",
      "strategy": "COMPLETE_EXISTING",
      "delegate_session_id": "wf-implement-feature/sessions/...",
      "delegate_result": "done",
      "registry_updated": true,
      "code_refs_count": 2,
      "tests_added_count": 1,
      "result": "success"
    },
    {
      "impl_req_id": "IMPL-REQ-002",
      "started_at": "2026-05-13T18:25:00Z",
      "completed_at": "2026-05-13T18:55:00Z",
      "strategy": "IMPLEMENT_NEW",
      "delegate_session_id": "wf-implement-feature/sessions/...",
      "delegate_result": "skipped",
      "errors": ["Out of scope, requires architectural decision"],
      "result": "skipped"
    }
  ],
  "summary": {
    "total_processed": 2,
    "done": 1,
    "skipped": 1,
    "registry_updates": 1,
    "code_changes_total": 2
  }
}
```
