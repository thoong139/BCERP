# Auto-Resolve — Agent-Based Decision Engine (v1.0.0)

## Mục đích

Khi `--auto` được set và pipeline gặp CDG point (decision gate), `spawn_auto_resolve_agent()`
thay thế user input bằng một decision agent. KHÔNG đoán mò — agent nhận đủ context và
trả về hành động cụ thể. Deferred items KHÔNG được để lại mà không giải quyết.

## Decision Types

| Type | Trigger | Options |
|------|---------|---------|
| `cf2_dep_miss` | FEAT B depend FEAT A chưa implement | `IMPLEMENT_A\|SKIP_B\|FORCE_DISPATCH` |
| `cf3_gate_fail` | Gate check fail sau 3 FEATs | `CONTINUE_WARN\|ABORT_BATCH\|SKIP_GATE` |
| `cf5_rollback` | FEAT B fail, FEAT A bị suspect | `ROLLBACK_A\|CONTINUE_SUSPECT\|SKIP_FEAT_B` |
| `verify_block` | wf-e2e-verify FEAT fail sau hết retry | `SKIP_FEAT\|RETRY_ONCE\|FAIL_BATCH` |

## Decision Schema

Ghi vào `$SESSION_DIR/auto-decisions.jsonl` (APPEND-only):

```json
{
  "decision_id": "ARA-YYYYMMDD-NNN",
  "type": "cf2_dep_miss|cf3_gate_fail|cf5_rollback|verify_block",
  "feat_ids": ["FEAT-xxx"],
  "selected_action": "...",
  "reason": "...",
  "confidence": 0.0,
  "side_effects": [],
  "decided_at": "ISO-8601"
}
```

---

## `spawn_auto_resolve_agent()`

```bash
spawn_auto_resolve_agent() {
  local decision_type="$1"   # cf2_dep_miss | cf3_gate_fail | cf5_rollback | verify_block
  local feat_context="$2"    # JSON string: {feat_ids:[...], issue:"...", ...}
  local options_list="$3"    # pipe-separated: "OPT_A|OPT_B|OPT_C"

  mkdir -p "$SESSION_DIR/auto-resolve"
  local SEQ
  SEQ=$(ls "$SESSION_DIR/auto-resolve/"*.json 2>/dev/null | wc -l)
  local DECISION_ID="ARA-$(date -u +%Y%m%d)-$(printf '%03d' $((SEQ + 1)))"

  # Registry context — lấy excerpt cho các feat_ids trong context
  local FEAT_IDS_LIST
  FEAT_IDS_LIST=$(echo "$feat_context" | jq -r '.feat_ids // [] | .[]' 2>/dev/null || echo "")
  local REGISTRY_EXCERPT=""
  if [ -n "$FEAT_IDS_LIST" ] && [ -f "$REGISTRY_PATH" ]; then
    REGISTRY_EXCERPT=$(jq --argjson fids "$(echo "$FEAT_IDS_LIST" | jq -R . | jq -sc '.')" \
      '[.features[] | select(.id as $id | $fids | contains([$id])) | {id, name, impl_status, module}]' \
      "$REGISTRY_PATH" 2>/dev/null | head -c 2048 || echo "[]")
  fi

  # Spawn decision agent
  local RAW_DECISION
  RAW_DECISION=$(Agent \
    --subagent_type "architect" \
    --description "Auto-resolve: ${decision_type} trong batch ${BATCH_ID}" \
    --prompt "Bạn là Auto-Resolve Agent cho wf-e2e-batch (batch: ${BATCH_ID}).

## Nhiệm vụ
Phân tích tình huống và chọn hành động phù hợp nhất từ danh sách options.

## Context
Decision type: ${decision_type}
Tình huống: ${feat_context}
Registry state: ${REGISTRY_EXCERPT:-không có}
Options: ${options_list}

## Output (ONLY JSON — không text khác)
{
  \"decision_id\": \"${DECISION_ID}\",
  \"type\": \"${decision_type}\",
  \"feat_ids\": [...],
  \"selected_action\": \"<MỘT OPTION TRONG: ${options_list}>\",
  \"reason\": \"<1-2 câu tiếng Việt giải thích>\",
  \"confidence\": <0.0-1.0>,
  \"side_effects\": [\"<effect1>\", \"...\"],
  \"decided_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
}

Quy tắc:
- selected_action PHẢI là một option trong: ${options_list}
- confidence < 0.6 → chọn option conservative nhất (SKIP/CONTINUE ưu tiên)
- side_effects: liệt kê tác động nếu có ([] nếu không có)" 2>/dev/null || echo "")

  # Parse selected_action
  local SELECTED
  SELECTED=$(echo "$RAW_DECISION" | jq -r '.selected_action // empty' 2>/dev/null)

  # Fallback nếu agent fail hoặc output không parse được
  if [ -z "$SELECTED" ] || ! echo "$options_list" | tr '|' '\n' | grep -qx "$SELECTED"; then
    SELECTED=$(echo "$options_list" | tr '|' '\n' | grep -E 'SKIP|CONTINUE|WARN' | head -1 \
      || echo "${options_list%%|*}")
    RAW_DECISION=$(jq -n \
      --arg did "$DECISION_ID" --arg dt "$decision_type" --arg sel "$SELECTED" \
      --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{decision_id:$did, type:$dt, feat_ids:[],
        selected_action:$sel,
        reason:"Agent fallback — output không parse được, chọn option conservative nhất",
        confidence:0.3, side_effects:["fallback_applied"], decided_at:$now}')
  fi

  # Ghi output file + audit log
  atomic_write_json "$SESSION_DIR/auto-resolve/${DECISION_ID}.json" \
    "$(echo "$RAW_DECISION" | jq '.' 2>/dev/null || echo "$RAW_DECISION")"
  echo "$RAW_DECISION" >> "$SESSION_DIR/auto-decisions.jsonl"

  local CONFIDENCE REASON
  CONFIDENCE=$(echo "$RAW_DECISION" | jq -r '.confidence // "?"' 2>/dev/null)
  REASON=$(echo "$RAW_DECISION" | jq -r '.reason // "no reason"' 2>/dev/null)
  log_event "AUTO_DECISION" "$decision_type" \
    "${DECISION_ID}: ${SELECTED} (conf=${CONFIDENCE}) — ${REASON}"

  # Return selected action via stdout
  echo "$SELECTED"
}
```

---

## Usage Patterns

### CF2 — FEAT A dep miss

```bash
if [ "${AUTO:-false}" = "true" ]; then
  ACTION=$(spawn_auto_resolve_agent "cf2_dep_miss" \
    "{\"feat_ids\":[\"${FEAT_B}\",\"${FEAT_A}\"],
      \"issue\":\"FEAT_A impl_status=${FEAT_A_STATUS}, tier_failed=${FAILED_TIER}\"}" \
    "IMPLEMENT_A|SKIP_B|FORCE_DISPATCH")

  case "$ACTION" in
    IMPLEMENT_A)
      spawn_subskill "auto-impl-${FEAT_A}" "wf-implement-feature" "--feat=${FEAT_A} --auto"
      # Retry CF2 sau khi implement xong (max 1 retry)
      ;;
    SKIP_B)
      mark_feat_skipped "$FEAT_B" "cf2_dep_miss_auto_skip"
      ;;
    FORCE_DISPATCH)
      log_event "WARN" "CF2" "Force dispatch ${FEAT_B} — dep miss acknowledged by auto-resolve"
      # Tiếp tục dispatch bình thường
      ;;
  esac
fi
```

### CF3 — Gate fail

```bash
if [ "${AUTO:-false}" = "true" ]; then
  GATE_CONTEXT=$(jq -n \
    --arg gnum "$gate_num" \
    --argjson feats "$(printf '%s\n' "${feats_in_gate[@]}" | jq -R . | jq -sc '.')" \
    --argjson issues "$(printf '%s\n' "${gate_issues[@]}" | jq -R . | jq -sc '.')" \
    '{gate_num:($gnum|tonumber), feats:$feats, issues:$issues}')

  ACTION=$(spawn_auto_resolve_agent "cf3_gate_fail" "$GATE_CONTEXT" \
    "CONTINUE_WARN|ABORT_BATCH|SKIP_GATE")

  case "$ACTION" in
    CONTINUE_WARN)
      log_event "WARN" "CF3-AUTO" "Gate #${gate_num} fail được auto-continue — issues ghi log"
      ;;
    ABORT_BATCH)
      log_error "E054" "CF3-AUTO" "Auto-resolve quyết định ABORT batch tại gate #${gate_num}"
      finalize_batch "aborted_by_auto_resolve"
      exit 1
      ;;
    SKIP_GATE)
      log_event "WARN" "CF3-AUTO" "Gate #${gate_num} bị skip theo auto-resolve decision"
      ;;
  esac
fi
```

### CF5 — Rollback decision

```bash
if [ "${ENABLE_CHAIN_ROLLBACK:-false}" = "true" ] && [ "${AUTO:-false}" = "true" ]; then
  ACTION=$(spawn_auto_resolve_agent "cf5_rollback" \
    "{\"feat_ids\":[\"${feat_b}\",\"${feat_a}\"],
      \"feat_b_status\":\"${feat_b_status}\",
      \"blocking_level\":\"${blocking_level}\",
      \"min_completion\":\"${min_completion}\"}" \
    "ROLLBACK_A|CONTINUE_SUSPECT|SKIP_FEAT_B")

  case "$ACTION" in
    ROLLBACK_A)
      bash .claude/scripts/wf-e2e-batch/feat-schema-cleanup.sh \
        "$feat_a" "batch-${BATCH_ID}-${feat_a}" --rollback
      log_event "ROLLBACK" "CF5-AUTO" "Auto-rollback ${feat_a} theo quyết định agent"
      ;;
    CONTINUE_SUSPECT)
      log_event "WARN" "CF5-AUTO" "${feat_a} giữ trạng thái SUSPECT, tiếp tục batch"
      ;;
    SKIP_FEAT_B)
      mark_feat_skipped "$feat_b" "cf5_auto_skip_after_a_suspect"
      ;;
  esac
fi
```

### verify_block — Sau FEAT fail từ wf-e2e-verify

```bash
# Sau khi đọc e2e-status.json của một FEAT:
if [ "$FEAT_STATUS" = "failed" ] && [ "${AUTO:-false}" = "true" ]; then
  FAIL_CONTEXT=$(jq -n \
    --arg fid "$feat_id" \
    --arg reason "$(jq -r '.fail_reason // "unknown"' "$FEAT_E2E_STATUS" 2>/dev/null)" \
    --arg retries "$(jq -r '.retry_count // 0' "$FEAT_E2E_STATUS" 2>/dev/null)" \
    '{feat_ids:[$fid], fail_reason:$reason, retry_count:($retries|tonumber)}')

  ACTION=$(spawn_auto_resolve_agent "verify_block" "$FAIL_CONTEXT" \
    "SKIP_FEAT|RETRY_ONCE|FAIL_BATCH")

  case "$ACTION" in
    SKIP_FEAT)
      mark_feat_skipped "$feat_id" "auto_resolve_skip_after_fail"
      ;;
    RETRY_ONCE)
      # Re-dispatch wf-e2e-verify lần nữa (max 1 retry per FEAT)
      if [ "$(jq -r '.retry_count // 0' "$FEAT_E2E_STATUS")" -lt 1 ]; then
        spawn_subskill "retry-${feat_id}" "wf-e2e-verify" \
          "--feat=${feat_id} --session=batch-${BATCH_ID}-${feat_id}-retry --auto"
      else
        log_event "WARN" "AUTO-RESOLVE" "${feat_id} đã retry 1 lần — đánh dấu failed"
        mark_feat_failed "$feat_id" "max_retry_reached"
      fi
      ;;
    FAIL_BATCH)
      log_error "E054" "AUTO-RESOLVE" "${feat_id} fail → auto-resolve quyết định FAIL toàn batch"
      finalize_batch "failed"
      exit 1
      ;;
  esac
fi
```

---

## Audit Log

`$SESSION_DIR/auto-decisions.jsonl` — APPEND-only, mỗi dòng 1 JSON decision.

Dùng để:
- Trace lại mọi quyết định auto trong batch
- Debug khi kết quả không như mong đợi
- Input cho batch-summary.md (số lượng auto-decisions)

```bash
# Đọc tóm tắt auto-decisions:
jq -c '{id:.decision_id, type:.type, action:.selected_action, conf:.confidence}' \
  "$SESSION_DIR/auto-decisions.jsonl" 2>/dev/null
```
