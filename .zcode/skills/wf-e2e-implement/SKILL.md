---
name: wf-e2e-implement
version: 2.0.0
last_updated: 2026-05-15
description: |
  F4 trong chuỗi wf-e2e-* (NEW skill — không có trong wf-e2e-verify cũ).
  Đọc implement-required.json (entries status=pending) → DELEGATE sang /wf-implement-feature cho từng item →
  verify completion → UPDATE registry.impl_status (SAFE-UPDATE) → mark entry status=done.
  KHÔNG inline implement — DELEGATE để giữ PRIMARY ownership của wf-implement-feature.
  YÊU CẦU --session=<id>.

  v2.0.0: Thay --max-items bằng --max-time (time-based budget). P0 PHẢI hoàn thành 100%.
  P1 BẮT BUỘC ≥80% trong budget. P2/P3 best-effort. Nếu P1 rate < 80% → f4_status=partial,
  KHÔNG advance F5. Items cần quyết định → DECISION-REQUIRED queue (KHÔNG silent defer).
  --max-items DEPRECATED (silent accept + WARN).

  TRIGGER khi: "implement code cho blocked tests", "delegate implement-required", "F4 implement".
  KHÔNG trigger: fix bugs (F6), full implement-feature workflow (dùng /wf-implement-feature trực tiếp).

argument-hint: "<FEAT-ID> --session=<id> [--resume] [--status] [--max-time=<duration>]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, Agent,
  mcp__serena__find_symbol, mcp__serena__find_referencing_symbols,
  mcp__serena__search_for_pattern,
  mcp__gitnexus__query, mcp__gitnexus__context, mcp__gitnexus__impact
---

# /wf-e2e-implement: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Loop qua implement-required.json → DELEGATE wf-implement-feature → update registry + entry status |
| **Standalone** | NO — require `--session=<id>` |
| **Input** | `implement-required.json` (entries status=pending) |
| **Output** | `impl-log.json`, UPDATE `implement-required.json`, UPDATE `req-registry.json.requirements[].impl_status` (SAFE-UPDATE) |
| **Strategy** | DELEGATE — KHÔNG inline implement (giữ PRIMARY ownership của wf-implement-feature) |

### Flow

```
[--session] → [PRE-GATE: implement-required.json có ≥1 pending entry + registry valid]
→ FOR each IMPL-REQ-NNN entry (sort by priority P0→P1→P2):
    1. UPDATE entry status: pending → in_progress
    2. Search-existing-code (CORE-020): xác định strategy VERIFY_ONLY|COMPLETE_EXISTING|IMPLEMENT_NEW
    3. SPAWN Agent (subagent_type=general-purpose) với prompt invoke /wf-implement-feature <REQ-ID hoặc FEAT-ID>
    4. WAIT delegate session complete
    5. READ delegate session impl-status.json → verify code committed
    6. IF success:
       - UPDATE entry: status=done, implemented_at, implementer=wf-implement-feature, delegate_session_id, code_refs[]
       - UPDATE registry.requirements[req_id].impl_status (SAFE-UPDATE, CORE-008 không downgrade)
       - APPEND impl-log.json
    7. IF fail (delegate timeout / error):
       - UPDATE entry: status=skipped, note error
       - APPEND issues.json (escalate)
    8. RETEST after impl: mark retest_after_impl=true → orchestrator spawn F5 sau F4 done
→ Write Phase-report.md → DONE
```

---

## Workflow Position

```
F1/F2 (implement-required.json populated)
        │
        ▼
   ┌─────────┐
   │   F4    │ ← wf-e2e-implement (skill này)
   │ Implement│ DELEGATE pattern
   │ delegate │
   └────┬────┘
        │ spawns
        ▼
   /wf-implement-feature (PRIMARY owner registry.impl_status)
        │
        ▼
   F5 retest (verify implementations work)
```

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `<FEAT-ID>` | Feature ID | required |
| `--session=<id>` | Session ID | required |
| `--resume` | Resume từ entry chưa implement | - |
| `--status` | Display impl progress + STOP | - |
| `--max-time=<duration>` | Time budget cho toàn bộ F4 run (vd: `60m`, `90m`, `120m`). P0 luôn hoàn thành, P1 cần ≥80% trong budget, P2/P3 best-effort. | `60m` |
| `--max-items=<N>` | **DEPRECATED** — dùng `--max-time` thay thế. Silent accept + WARN. | - |

---

## CI PRE-GATE (CORE-033)

> CI tools auto-detect. F4 can CI cho impact analysis + code search truoc khi delegate.

| Step | Action | Verify |
|------|--------|--------|
| **Na** | Load CI Capabilities: Run `bash .claude/scripts/ci-detect.sh`. | CI flags set |
| **Nb** | Index Freshness Check: Run `bash .claude/scripts/ci-freshness-check.sh`. | Freshness status set |
| **Nc** | Agent Context Injection: Run `bash .claude/scripts/ci-inject-context.sh` -> `$CI_CONTEXT` pass to delegate agents. | CI context ready |

### CI-ROUTE

| CI Task | Primary Tool | Fallback |
|---------|-------------|----------|
| `impact_analysis` | GitNexus `impact({target})` | Grep |
| `find_by_annotation` | GitNexus `cypher` + Serena `find_referencing_symbols` | Grep REQ-ID |
| `symbol_overview` | Serena `get_symbols_overview` | Read |

---
## Session Structure

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── implement-required.json          ← F4 READ + UPDATE
├── issues.json                      ← APPEND nếu delegate fail
├── F4-implement/
│   ├── status.json                  ← F4 own state
│   ├── impl-log.json                ← Per-entry delegate receipt
│   ├── delegate-receipts/           ← Raw receipts từ wf-implement-feature sessions
│   │   ├── IMPL-REQ-001-receipt.json
│   │   ├── IMPL-REQ-002-receipt.json
│   │   └── ...
│   └── Phase-report.md              ← CORE-028
└── (registry update at .mc-data/docs/_meta/req-registry.json — SAFE-UPDATE)
```

---

## Delegate Pattern

Cho mỗi IMPL-REQ-NNN entry status=pending:

### Step 1: Search-existing-code (CORE-020)

```bash
LOCATION_HINT=$(jq -r --arg id "$IMPL_REQ_ID" '.entries[] | select(.id==$id) | .location_hint' implement-required.json)
EXPECTED=$(jq -r --arg id "$IMPL_REQ_ID" '.entries[] | select(.id==$id) | .expected_behavior' implement-required.json)

# Search related code
mcp__serena__find_symbol --name_path="$RELATED_SYMBOL"
mcp__serena__search_for_pattern --substring_pattern="$KEYWORD" --paths_include_glob="$LOCATION_HINT"

# Determine strategy:
# - VERIFY_ONLY: code đã tồn tại + đúng → mark done immediately, skip delegate
# - COMPLETE_EXISTING: code có nhưng thiếu phần → delegate với strategy=complete
# - IMPLEMENT_NEW: code chưa có → delegate với strategy=new
```

### Step 2: Spawn wf-implement-feature

```bash
# Use Agent tool with subagent_type=general-purpose
PROMPT="
Bạn là delegate agent cho wf-e2e-implement F4.

Task: Run /wf-implement-feature cho REQ-ID=${REQ_ID} (linked từ IMPL-REQ entry ${IMPL_REQ_ID}).

Context:
- Parent session: ${SESSION_ID}
- Implementation strategy: ${STRATEGY}
- Location hint: ${LOCATION_HINT}
- Expected behavior: ${EXPECTED}
- Existing code refs: ${CODE_REFS[@]}

Instructions:
1. Invoke /wf-implement-feature ${REQ_ID} với strategy=${STRATEGY}
2. Đảm bảo registry.impl_status được update sau khi code committed
3. Return JSON receipt: {
    \"delegate_session_id\": \"<session-id>\",
    \"impl_status_after\": \"done|in_progress|skipped\",
    \"code_refs\": [\"file:line\"],
    \"errors\": [\"...\"]
   }

Save receipt vào ${F4_DIR}/delegate-receipts/${IMPL_REQ_ID}-receipt.json
"

# Spawn
Agent --subagent_type=general-purpose --description="F4 delegate IMPL-REQ-${IMPL_REQ_ID}" --prompt="$PROMPT"
```

### Step 3: Wait + Verify

```bash
# Receipt file expected at known path
RECEIPT_FILE="$F4_DIR/delegate-receipts/${IMPL_REQ_ID}-receipt.json"

# Timeout 30 min per item
TIMEOUT=1800
WAITED=0
while [ ! -f "$RECEIPT_FILE" ] && [ "$WAITED" -lt "$TIMEOUT" ]; do
  sleep 30
  WAITED=$((WAITED + 30))
done

if [ ! -f "$RECEIPT_FILE" ]; then
  # Delegate timeout → mark skipped + escalate
  update_impl_req "$IMPL_REQ_ID" "skipped" "delegate_timeout"
  append_issue "ISS-NNN" "F4 delegate timeout for $IMPL_REQ_ID"
  continue
fi

# Read receipt
RECEIPT=$(cat "$RECEIPT_FILE")
IMPL_STATUS=$(echo "$RECEIPT" | jq -r '.impl_status_after')
CODE_REFS=$(echo "$RECEIPT" | jq -r '.code_refs')

if [ "$IMPL_STATUS" = "done" ]; then
  # Success → update entry
  update_impl_req "$IMPL_REQ_ID" "done" "wf-implement-feature" "$CODE_REFS"
  # Update registry (SAFE-UPDATE)
  registry_safe_update "$REQ_ID" "done"
else
  # Partial / failed
  update_impl_req "$IMPL_REQ_ID" "skipped" "delegate returned $IMPL_STATUS"
  append_issue "..."
fi
```

### Step 4: Registry SAFE-UPDATE

```bash
registry_safe_update() {
  local REQ_ID="$1"
  local NEW_STATUS="$2"
  local REGISTRY=".mc-data/docs/_meta/req-registry.json"
  
  # Read current status
  CURRENT=$(jq -r --arg id "$REQ_ID" '.requirements[] | select(.req_id==$id) | .impl_status' "$REGISTRY")
  
  # CORE-008: không downgrade từ "done"
  if [ "$CURRENT" = "done" ] && [ "$NEW_STATUS" != "done" ]; then
    echo "WARN: Refused to downgrade $REQ_ID from done to $NEW_STATUS"
    return 1
  fi
  
  # Atomic update
  jq --arg id "$REQ_ID" --arg status "$NEW_STATUS" '
    (.requirements[] | select(.req_id==$id) | .impl_status) = $status
  ' "$REGISTRY" > "$REGISTRY.tmp"
  
  # Validate
  jq -e '.requirements | length > 0' "$REGISTRY.tmp" > /dev/null || { rm "$REGISTRY.tmp"; return 1; }
  
  # Move atomic
  mv "$REGISTRY.tmp" "$REGISTRY"
}
```

---

## PRE-GATE (CORE-011)

1. **T1:** `implement-required.json` tồn tại
2. **T2:** Schema valid
3. **T3:** Có ≥1 entry status=pending
4. **T4:** Mỗi entry có `id`, `test_ref`, `req_id` (nullable), `suggested_action`

Fail → E040 (no pending entries) hoặc E041 (schema).

---

## POST-GATE (CORE-012)

1. **T1:** `impl-log.json` tồn tại
2. **T2:** `implement-required.json` summary counts khớp
3. **T3:** Mỗi entry đã processed có status ∈ {done, skipped}
4. **T4:** Registry impl_status đã update cho entries có req_id (chỉ upgrade, không downgrade)

Fail → auto-fix retry x3 → E048.

---

## Registry SAFE-UPDATE Rules (CORE-008)

- **CHỈ upgrade** `impl_status`: `not_started` → `in_progress` → `done`
- **KHÔNG downgrade** từ `done`
- **CHỈ field `impl_status`** được modify, các fields khác giữ nguyên (CORE-006 safe-write)
- Atomic write (build → jq validate → tmp+mv)
- IF entry không có `req_id` (nullable) → KHÔNG update registry, chỉ update implement-required.json

---

## --status

```
================================================================
F4 wf-e2e-implement — Status Dashboard
================================================================

Implement-Required Queue:
- Total entries: 5
- Status:
  - pending: 2
  - in_progress: 1
  - done: 1
  - skipped: 1

Current item: IMPL-REQ-003 (in_progress)
  Strategy: COMPLETE_EXISTING
  Delegate session: 20260513-2100-wf-implement-feature

Progress detail:
| IMPL-REQ | Priority | Status | Delegate | Result |
|----------|----------|--------|----------|--------|
| IMPL-REQ-001 | P0 | done | session-001 | impl_status=done |
| IMPL-REQ-002 | P0 | skipped | session-002 | timeout 30m |
| IMPL-REQ-003 | P1 | in_progress | session-003 | (waiting) |
| IMPL-REQ-004 | P1 | pending | - | - |
| IMPL-REQ-005 | P2 | pending | - | - |

Registry updates:
- REQ-CRM-001: not_started → done
- REQ-CRM-005: not_started → done
================================================================
STOP
```

---

## Error Codes (E040-E049)

| Code | Mô tả |
|------|-------|
| E040 | implement-required.json không có pending entries |
| E041 | --session thiếu |
| E042 | Schema invalid |
| E043 | Delegate spawn fail |
| E044 | Delegate timeout 30 min |
| E045 | Registry SAFE-UPDATE refused (downgrade attempt) |
| E046 | Registry update fail (corrupted) |
| E047 | Delegate receipt malformed |
| E048 | POST-GATE T4 registry mismatch |
| E049 | Atomic write fail |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| F1 wf-e2e-test / F2 wf-e2e-browser | Producer implement-required.json entries (Nhóm 3 block classification) |
| **wf-implement-feature** | F4 DELEGATE — primary owner registry.impl_status |
| F5 wf-e2e-retest | Verify implementations work sau F4 done |
| F3 wf-e2e-unblock | F3 SKIP Group 3 (delegate F4) |
| wf-e2e-verify orchestrator | Spawn F4 sau F3 nếu implement-required có pending |
