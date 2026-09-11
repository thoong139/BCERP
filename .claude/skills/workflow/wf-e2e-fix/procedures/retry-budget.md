# F6 — Retry Budget Management (CORE-034)

## Budget per Issue

| Attempt | Action | Threshold |
|---------|--------|-----------|
| **0** | First fix attempt với strategy mặc định (Serena replace_content) | - |
| **1** | Re-analyze code context, retry với strategy khác | retest FAIL từ attempt 0 |
| **2** | Spawn Agent subagent_type=developer cho 2nd opinion + retry | retest FAIL từ attempt 1 |
| **3+** | MAX → status="still_fail", SKIP forever | retest FAIL từ attempt 2 |

## fix_attempts[] Schema

```jsonc
{
  "fix_attempts": [
    {
      "at": "ISO",
      "round": 1,
      "method": "serena_replace_content",
      "strategy": "default",
      "applied": true,
      "retest_result": "FAIL",
      "fail_reason": "Migration syntax error: missing semicolon"
    },
    {
      "at": "ISO",
      "round": 2,
      "method": "serena_replace_symbol_body",
      "strategy": "rewrite_entire_method",
      "applied": true,
      "retest_result": "FAIL",
      "fail_reason": "EF Core complains about FK reference"
    },
    {
      "at": "ISO",
      "round": 3,
      "method": "agent_delegate",
      "strategy": "developer_agent_2nd_opinion",
      "delegate_session": ".mc-data/work/agent-sessions/...",
      "applied": false,
      "retest_result": "FAIL",
      "fail_reason": "Agent suggests architectural change, out of F6 scope"
    }
  ]
}
```

## Status Lifecycle

```
status=open
  ↓ first fix attempt → applied → retest
  ↓ retest PASS → status=fixed (final)
  ↓ retest FAIL → status=open + fix_attempts++ (loop)
  
After 3 fix_attempts retest FAIL:
  → status=still_fail (mark, SKIP next round)

If lock contention:
  → status=deferred-locked + locked_by=<session> (SKIP, no retry budget consumed)
  
If user judges unfixable:
  → status=unfixable (manual override, SKIP)
```

## When to Escalate

F6 KHÔNG escalate trực tiếp tới user — orchestrator-level check sau khi F6 return.

Orchestrator-level anti-loop:
- `f6_f5_loop_count >= 3` → ESCALATE: AskUserQuestion "Continue F6 (risky) / Skip (still_fail) / Cancel pipeline"
- Default: skip → mark all remaining open as `still_fail`

## Fix Strategy Selection

```
function select_strategy(attempt_num, issue):
  IF attempt_num == 0:
    return "default_serena_replace"
  
  IF attempt_num == 1:
    # Re-analyze with more context
    return "serena_replace_with_full_symbol_body"
  
  IF attempt_num == 2:
    # Delegate to developer agent
    return "agent_delegate_developer"
  
  IF attempt_num >= 3:
    return "skip_mark_still_fail"
```

## Anti-Pattern Prevention

- ❌ KHÔNG fix issue mà không có retest (BHV-004 verifiable goal)
- ❌ KHÔNG bypass retry budget (always check fix_attempts.length)
- ❌ KHÔNG ghi đè fix_attempts[] (APPEND only)
- ❌ KHÔNG remove status=still_fail / deferred-locked / unfixable (immutable terminal states)
- ❌ KHÔNG fix issue có severity=critical mà không gitnexus_impact check
