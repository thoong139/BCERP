# F4 — Delegate to /wf-implement-feature Procedure

## Delegate Spawn Pattern

F4 dùng Agent tool spawn subagent thực hiện `/wf-implement-feature`.

```bash
# For each entry status=pending:

# CORE-037 Agent Prompt Template: 8 required sections
PROMPT=$(cat <<'AGENT_PROMPT'
1. ROLE: Bạn là delegate agent cho wf-e2e-implement F4, spawned bởi wf-e2e-verify orchestrator.
   Nhiệm vụ của bạn: implement missing features thông qua /wf-implement-feature.

2. TASK: Đọc file .claude/skills/workflow/wf-e2e-implement/SKILL.md và thực thi đầy đủ.
   Đọc .claude/skills/workflow/wf-implement-feature/SKILL.md trước khi invoke.
   REQ-ID: ${REQ_ID} | IMPL-REQ entry: ${IMPL_REQ_ID}
   Strategy: ${STRATEGY} (VERIFY_ONLY | COMPLETE_EXISTING | IMPLEMENT_NEW)

3. SESSION CONTEXT:
   - Parent orchestrator session: ${SESSION_ID}
   - Shared session dir: ${SESSION_DIR}
   - FEAT_ID: ${FEAT_ID}
   - IMPL-REQ ID: ${IMPL_REQ_ID}
   - Location hint: ${LOCATION_HINT}
   - Expected behavior: ${EXPECTED_BEHAVIOR}
   - Existing code refs: ${EXISTING_CODE_REFS}

4. CI CONTEXT (CORE-033):
   ${CI_CONTEXT:-"CI không khả dụng — fallback Grep/Glob cho code analysis."}

5. PLAYWRIGHT CONTEXT: Không áp dụng cho F4 implementation delegate.

6. OUTPUT CONTRACT:
   - Receipt: ${RECEIPTS_DIR}/${IMPL_REQ_ID}-receipt.json (schema: wf-e2e-implement-receipt-v1)
   - Registry update: .mc-data/docs/_meta/req-registry.json
     (field: requirements[req_id==${REQ_ID}].impl_status, role: PRIMARY của wf-implement-feature)
   - KHÔNG ghi vào implement-required.json (F4 sẽ tự update)
   - KHÔNG ghi vào F4-implement/ files khác

7. OWNERSHIP RULES (CORE-037):
   - 1 file = 1 writer — KHÔNG ghi đè output của agent khác
   - Chỉ ghi receipt vào ${RECEIPTS_DIR}/${IMPL_REQ_ID}-receipt.json
   - Delegate /wf-implement-feature xử lý registry update (PRIMARY role)
   - TUÂN THỦ CORE-006 safe-write registry (chỉ field impl_status)
   - Timeout 30 phút — nếu không complete kịp, save partial receipt với impl_status_after="in_progress"

8. COMPLETION CRITERIA:
   - Receipt tồn tại và pass schema validation (jq '."$schema" == "wf-e2e-implement-receipt-v1"')
   - impl_status_after là "done" hoặc "in_progress" hoặc "skipped"
   - code_refs[] không rỗng nếu strategy != VERIFY_ONLY
   - Return: "Delegate complete. Receipt at ${RECEIPTS_DIR}/${IMPL_REQ_ID}-receipt.json. impl_status_after=<status>."
AGENT_PROMPT
)

# Spawn via Agent tool (background mode hoặc foreground)
# NOTE: Agent tool spec — agent will run /wf-implement-feature workflow + write receipt
RECEIPT_PATH="${RECEIPTS_DIR}/${IMPL_REQ_ID}-receipt.json"
```

## Receipt Schema

```jsonc
{
  "$schema": "wf-e2e-implement-receipt-v1",
  "impl_req_id": "IMPL-REQ-001",
  "req_id": "REQ-CRM-001",
  "feat_id": "FEAT-EW-CRM-001",
  "delegate_session_id": "wf-implement-feature/sessions/2026-05-13-...",
  "started_at": "2026-05-13T18:00:00Z",
  "completed_at": "2026-05-13T18:25:00Z",
  "impl_status_after": "done|in_progress|skipped",
  "code_refs": [
    {
      "path": "apps/backend/Eureka.Modules.CRM/Application/Commands/CreateCustomerCommandHandler.cs",
      "line": 87,
      "change_type": "modified"
    },
    {
      "path": "apps/backend/Eureka.Modules.CRM/Application/Commands/CreateCustomerCommandValidator.cs",
      "line": 23,
      "change_type": "added"
    }
  ],
  "registry_updated": true,
  "registry_field_changed": "requirements[req_id==REQ-CRM-001].impl_status",
  "registry_status_before": "not_started",
  "registry_status_after": "done",
  "tests_added": [
    "apps/backend/Eureka.UnitTests/CRM/CreateCustomerCommandHandlerTests.cs#DuplicateEmailValidation"
  ],
  "errors": [],
  "warnings": []
}
```

## Verify Delegate Completion

```bash
RECEIPT_FILE="${RECEIPTS_DIR}/${IMPL_REQ_ID}-receipt.json"
TIMEOUT_SEC=1800  # 30 min

# Wait for receipt
WAITED=0
while [ ! -f "$RECEIPT_FILE" ] && [ "$WAITED" -lt "$TIMEOUT_SEC" ]; do
  sleep 30
  WAITED=$((WAITED + 30))
  echo "Waiting delegate ${IMPL_REQ_ID}... ${WAITED}s"
done

# Check timeout
if [ ! -f "$RECEIPT_FILE" ]; then
  echo "ERROR E044: Delegate timeout for ${IMPL_REQ_ID}"
  
  # Mark skipped + escalate
  update_impl_req_entry "$IMPL_REQ_ID" "skipped" "wf-e2e-implement" "" '[]' "Delegate timeout 30 min"
  
  # Append issue
  append_issue "
    type: integration
    severity: medium
    title: F4 delegate timeout cho ${IMPL_REQ_ID}
    description: wf-implement-feature không hoàn tất trong 30 phút
    related_impl_req: ${IMPL_REQ_ID}
  "
  
  continue
fi

# Parse receipt
RECEIPT=$(cat "$RECEIPT_FILE")

# Validate schema
SCHEMA=$(echo "$RECEIPT" | jq -r '."$schema"')
[ "$SCHEMA" = "wf-e2e-implement-receipt-v1" ] || exit_with E047

# Extract
IMPL_STATUS=$(echo "$RECEIPT" | jq -r '.impl_status_after')
DELEGATE_SESSION=$(echo "$RECEIPT" | jq -r '.delegate_session_id')
CODE_REFS=$(echo "$RECEIPT" | jq -c '.code_refs')
REGISTRY_UPDATED=$(echo "$RECEIPT" | jq -r '.registry_updated')
REGISTRY_AFTER=$(echo "$RECEIPT" | jq -r '.registry_status_after')

# Handle result (chuyển sang verify-completion.md)
```

## Max Concurrency

F4 spawn delegates SEQUENTIAL (không parallel) để:
- Tránh registry write conflict (multiple wf-implement-feature ghi cùng impl_status)
- Source code lock contention (cùng module)
- Easier debug + audit trail

Mỗi entry: spawn → wait complete → update → next entry.
