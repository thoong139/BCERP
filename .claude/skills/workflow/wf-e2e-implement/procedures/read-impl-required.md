# F4 — Read & Prioritize Implement-Required Entries

## Read implement-required.json

```bash
test -f "$IMPL_REQ" || exit_with E040

# Read schema
SCHEMA=$(jq -r '."$schema" // ""' "$IMPL_REQ")
[ "$SCHEMA" = "wf-e2e-implement-required-v1" ] || echo "WARN: schema mismatch"

# Read entries
TOTAL=$(jq -r '.entries | length' "$IMPL_REQ")
PENDING=$(jq -r '[.entries[] | select(.status=="pending")] | length' "$IMPL_REQ")
echo "Total: $TOTAL, Pending: $PENDING"
```

## Prioritize Entries

```bash
# Sort by priority: P0 → P1 → P2, then by discovered_at (oldest first)
PRIORITIZED=$(jq '[.entries[] | select(.status=="pending")] | sort_by(
  (.priority | (if . == "P0" then 0 elif . == "P1" then 1 elif . == "P2" then 2 else 9 end)),
  .discovered_at
)' "$IMPL_REQ")
```

## Strategy Determination (CORE-019, CORE-020)

Cho mỗi entry, F4 phải xác định `implementation_strategy`:

```bash
determine_strategy() {
  local LOCATION_HINT="$1"
  local EXPECTED="$2"
  local ACTION="$3"
  
  # Step 1: Search existing code (CORE-020)
  if [ -n "$LOCATION_HINT" ]; then
    # Check file exists
    if [ -f "$LOCATION_HINT" ]; then
      # Check if related symbol/code exists
      SYMBOL_FOUND=$(mcp__serena__search_for_pattern --substring_pattern="$EXPECTED_KEYWORD" --paths_include_glob="$LOCATION_HINT")
      
      if [ -n "$SYMBOL_FOUND" ]; then
        # Code exists, check if matches expected behavior
        # Use Serena to verify logic
        echo "COMPLETE_EXISTING"
      else
        echo "IMPLEMENT_NEW"
      fi
    else
      # File doesn't exist
      echo "IMPLEMENT_NEW"
    fi
  else
    # No location hint
    # Try GitNexus query
    RESULT=$(mcp__gitnexus__query --query="$EXPECTED")
    if [ -n "$RESULT" ]; then
      echo "VERIFY_ONLY"  # Might exist somewhere, verify first
    else
      echo "IMPLEMENT_NEW"
    fi
  fi
}
```

## VERIFY_ONLY Fast-Path

Nếu strategy = VERIFY_ONLY:

```bash
# Code có thể đã tồn tại + work — verify trực tiếp KHÔNG cần delegate
# Use Serena to read code body + compare với expected_behavior

CODE_BODY=$(mcp__serena__find_symbol --name_path="$SYMBOL" --include_body=true)

# Static analysis: does code match expected?
# - Has validation? grep "throw|exception|errorCode"
# - Has business rule? grep "BR-NNN" hoặc pattern matching
# - Has correct status code? grep "200|400|404"

if matches_expected; then
  # Mark done immediately, skip delegate
  update_impl_req_entry "$IMPL_REQ_ID" "done" "F4-verify-only" "" '[]' "Code verified PASS, no impl needed"
  registry_safe_update "$REQ_ID" "done"
  append_impl_log "$IMPL_REQ_ID" "verify_only" "PASS"
  continue  # next entry
else
  # Fallback to delegate
  STRATEGY="COMPLETE_EXISTING"
fi
```

## Pre-Delegate Checks

```bash
# 1. REQ_ID exists in registry?
[ -z "$REQ_ID" ] && {
  echo "WARN: IMPL-REQ-$IMPL_REQ_ID không có req_id linked, F4 skip registry update"
}

# 2. wf-implement-feature available?
test -d ".claude/skills/workflow/wf-implement-feature" || exit_with E043

# 3. Impact check (gitnexus)
mcp__gitnexus__impact --target="$RELATED_FILE" --direction=upstream
# IF HIGH/CRITICAL → log WARN, user confirm
```

## Update Entry to in_progress

Before delegate spawn:

```bash
update_impl_req_entry "$IMPL_REQ_ID" "in_progress" "wf-e2e-implement" "" '[]' "Delegate spawning"
```
