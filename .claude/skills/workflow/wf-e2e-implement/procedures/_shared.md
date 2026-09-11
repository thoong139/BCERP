# F4 wf-e2e-implement — Shared Protocols

## State Variables

```
$SESSION_DIR = .mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
$F4_DIR = $SESSION_DIR/F4-implement/
$IMPL_REQ = $SESSION_DIR/implement-required.json
$REGISTRY = .mc-data/docs/_meta/req-registry.json
$IMPL_LOG = $F4_DIR/impl-log.json
$STATUS = $F4_DIR/status.json
$RECEIPTS_DIR = $F4_DIR/delegate-receipts/
$ISSUES = $SESSION_DIR/issues.json
```

## PRE-GATE Forensic

```bash
test -f "$IMPL_REQ" || exit_with E040

PENDING=$(jq -r '[.entries[] | select(.status=="pending")] | length' "$IMPL_REQ")
[ "$PENDING" -gt 0 ] || { echo "No pending entries, nothing to implement"; exit 0; }

# Registry valid
jq -e '.requirements | length > 0' "$REGISTRY" > /dev/null || exit_with E046
```

## Entry Iteration (v2.0.0 — Time-Budget)

> v2.0.0: Thay --max-items bằng time-budget. Xem chi tiết: `procedures/time-budget.md`.

```bash
# Xử lý deprecated --max-items
if [ -n "${MAX_ITEMS:-}" ]; then
  echo "WARN: --max-items deprecated kể từ v2.0.0. Dùng --max-time thay thế. Ví dụ: --max-time=60m"
  # Ignore, dùng MAX_TIME default
fi

# LOAD time-budget logic (CORE-032 lazy-load)
# procedures/time-budget.md §parse_max_time, §check_time_budget, §check_p1_completion_rate

# Khởi tạo budget
parse_max_time  # Set $MAX_TIME_SECONDS
START_TIME=$(date +%s)

# Sort by severity (P0 → P1 → P2 → P3) — không còn sort by .priority field cũ
ENTRIES=$(jq '[.entries[] | select(.status=="pending")] | sort_by(.severity | (if . == "P0" then 0 elif . == "P1" then 1 elif . == "P2" then 2 else 3 end))' "$IMPL_REQ")

# Iterate với time-budget check
echo "$ENTRIES" | jq -c '.[]' | while IFS= read -r entry; do
  IMPL_REQ_ID=$(echo "$entry" | jq -r '.id')
  REQ_ID=$(echo "$entry" | jq -r '.req_id')
  SEVERITY=$(echo "$entry" | jq -r '.severity')
  
  # Kiểm tra budget TRƯỚC khi bắt đầu item (P0 luôn pass)
  if ! check_time_budget "$SEVERITY"; then
    echo "INFO: Budget hết hoặc P1 rate < 80% — dừng tại $IMPL_REQ_ID ($SEVERITY)"
    break
  fi
  
  # Process per-entry (delegate-impl-feature.md)
done

# Finalize
finalize_f4
```

## Delegate Spawn (Agent tool)

```bash
spawn_delegate() {
  local IMPL_REQ_ID="$1"
  local REQ_ID="$2"
  local STRATEGY="$3"
  local LOCATION_HINT="$4"
  local EXPECTED="$5"
  
  PROMPT="
Bạn là delegate agent cho wf-e2e-implement F4. Task: Run /wf-implement-feature cho REQ-ID=${REQ_ID}.

Context:
- Parent session: ${SESSION_ID}
- IMPL-REQ entry: ${IMPL_REQ_ID}
- Implementation strategy: ${STRATEGY}
- Location hint: ${LOCATION_HINT}
- Expected behavior: ${EXPECTED}

Instructions:
1. Read .mc-data/docs/_meta/req-registry.json để load REQ ${REQ_ID}
2. Invoke /wf-implement-feature ${REQ_ID}
3. Đảm bảo registry.impl_status được update sau khi code committed
4. Khi hoàn tất, save receipt vào ${RECEIPTS_DIR}/${IMPL_REQ_ID}-receipt.json:
{
  \"delegate_session_id\": \"<wf-implement-feature session id>\",
  \"impl_status_after\": \"done|in_progress|skipped\",
  \"code_refs\": [\"file:line\"],
  \"registry_updated\": true,
  \"errors\": [\"...\"],
  \"completed_at\": \"<ISO-8601>\"
}

Trả về session ID + summary.
  "
  
  # Use Agent tool
  # NOTE: Trong thực tế, F4 dùng Task tool / Agent tool spawn subagent
  # Pseudo-call:
  # Agent --subagent_type=general-purpose --description="F4 delegate ${IMPL_REQ_ID}" --prompt="$PROMPT"
}
```

## Registry SAFE-UPDATE (CORE-008)

```bash
registry_safe_update() {
  local REQ_ID="$1"
  local NEW_STATUS="$2"
  
  [ -z "$REQ_ID" ] && return 0  # nullable, skip
  
  CURRENT=$(jq -r --arg id "$REQ_ID" '.requirements[] | select(.req_id==$id) | .impl_status' "$REGISTRY")
  
  # CORE-008: không downgrade
  if [ "$CURRENT" = "done" ] && [ "$NEW_STATUS" != "done" ]; then
    echo "WARN E045: Refused to downgrade $REQ_ID from done to $NEW_STATUS"
    return 1
  fi
  
  # Atomic
  jq --arg id "$REQ_ID" --arg status "$NEW_STATUS" '
    (.requirements[] | select(.req_id==$id) | .impl_status) = $status
  ' "$REGISTRY" > "$REGISTRY.tmp"
  
  jq -e '.requirements | length > 0' "$REGISTRY.tmp" > /dev/null || { rm "$REGISTRY.tmp"; return 1; }
  
  mv "$REGISTRY.tmp" "$REGISTRY"
}
```

## implement-required.json Update

```bash
update_impl_req_entry() {
  local IMPL_REQ_ID="$1"
  local STATUS="$2"  # in_progress | done | skipped
  local IMPLEMENTER="$3"
  local DELEGATE_SESSION="$4"
  local CODE_REFS="$5"  # JSON array string
  local NOTE="$6"
  
  ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  jq --arg id "$IMPL_REQ_ID" --arg s "$STATUS" --arg t "$ISO" --arg i "$IMPLEMENTER" --arg ds "$DELEGATE_SESSION" --argjson cr "$CODE_REFS" --arg n "$NOTE" '
    (.entries[] | select(.id==$id) | .status) = $s |
    (.entries[] | select(.id==$id) | .implemented_at) = (if $s == "done" then $t else null end) |
    (.entries[] | select(.id==$id) | .implementer) = $i |
    (.entries[] | select(.id==$id) | .delegate_session_id) = $ds |
    (.entries[] | select(.id==$id) | .code_refs) = $cr |
    (.entries[] | select(.id==$id) | .note) = $n |
    .last_updated = $t
  ' "$IMPL_REQ" > "$IMPL_REQ.tmp"
  
  jq '.' "$IMPL_REQ.tmp" > /dev/null || { rm "$IMPL_REQ.tmp"; exit_with E049; }
  mv "$IMPL_REQ.tmp" "$IMPL_REQ"
}
```

## CI Detection (CORE-033)

> CI detection chay boi orchestrator. Sub-skill doc `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$CI_CONTEXT`.
> F4 can CI cho impact analysis truoc khi delegate wf-implement-feature.

```bash
GITNEXUS_AVAILABLE=${GITNEXUS_AVAILABLE:-false}
SERENA_AVAILABLE=${SERENA_AVAILABLE:-false}
CI_CONTEXT=${CI_CONTEXT:-""}
```

## Error Ledger (CORE-034)

```bash
ERROR_LEDGER="$SESSION_DIR/error-ledger.json"

log_error() {
  local CODE="$1"; local PHASE="$2"; local MSG="$3"; local RETRY="${4:-0}"
  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"timestamp\":\"$ISO\",\"code\":\"$CODE\",\"phase\":\"$PHASE\",\"message\":\"$MSG\",\"retry_count\":$RETRY}" >> "$ERROR_LEDGER"
}
```

## Context & Checkpoint (CORE-038)

| Context Usage | Hanh dong |
|---------------|-----------|
| < 65% | Tiep tuc binh thuong |
| 65-80% | Chuan bi checkpoint (luu status.json + impl-log.json) |
| 80-90% | STOP sau entry hien tai -> huong dan --resume |
| > 90% | FORCE STOP (E049 style) |

## Error Handling

| Error | Action |
|-------|--------|
| E043 Delegate spawn fail | Retry x1, then skip + escalate ISSUE |
| E044 Delegate timeout 30m | Mark skipped + escalate |
| E045 SAFE-UPDATE refused | Log WARN, không re-attempt |
| E047 Receipt malformed | Mark skipped, log issue |
