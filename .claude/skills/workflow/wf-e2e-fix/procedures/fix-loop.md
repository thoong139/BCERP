# F6 — Fix Loop Procedure

**Áp dụng:** Single continuous loop của F6 wf-e2e-fix.

---

## Main Loop

```
ROUND_NUM = 0
MAX_ROUNDS = 50  # safety net, thực tế ít khi vượt 5-10

WHILE true:
  ROUND_NUM++
  
  # Load actionable issues
  OPEN_ISSUES = jq '[.signals[] | select(.status=="open" and (.fix_attempts | length < 3))]' $ISSUES
  
  IF empty(OPEN_ISSUES):
    BREAK  # done
  
  IF ROUND_NUM > MAX_ROUNDS:
    LOG "Safety net hit, escalate"
    BREAK
  
  # Sort by severity
  SORTED = sort OPEN_ISSUES by severity (critical → high → medium → low)
  
  ROUND_FIXED = 0
  
  FOR each issue in SORTED:
    # Pre-fix checks
    Check fix_attempts.length < 3 OR mark still_fail + continue
    Check gitnexus_impact OR WARN (continue if --auto)
    Acquire source lock OR mark deferred-locked + continue
    
    # Apply surgical fix
    fix_result = apply_serena_fix(issue)
    
    IF fix_result == "applied":
      atomic_update_issues_json(status="fixed", fix_attempts append)
      ROUND_FIXED++
      
      # Spawn F5 retest
      retest_result = spawn_f5_retest(scope=issue.type, session=$SESSION)
      
      IF retest_result == "PASS":
        keep status="fixed"
      ELSE IF retest_result == "FAIL":
        atomic_update_issues_json(status="open", fix_attempts append retry)
        ROUND_FIXED--
      ELSE IF retest_result == "ERROR":
        atomic_update_issues_json(retest_result="PENDING")
    ELSE IF fix_result == "failed":
      atomic_update_issues_json(fix_attempts append retry, keep status="open")
    
    # Release lock
    release source lock
  END FOR
  
  # Round summary
  append_fix_log(round=ROUND_NUM, fixed=ROUND_FIXED, total=OPEN_ISSUES.length)
  
  IF ROUND_FIXED == 0:
    # No progress in this round → escalate
    LOG "No progress, all remaining issues are deferred or fix-failing"
    BREAK
  
  # Continue next round
END WHILE

# Final POST-GATE
verify all issues either fixed OR still_fail/deferred-locked/unfixable OR fix_attempts >= 3
write fix-log.json final summary
write F6-fix/Phase-report.md (CORE-028)
```

---

## F5 Retest Spawn (CORE-037 Agent Prompt)

Sau moi fix thanh cong, spawn F5 wf-e2e-retest de verify:

```bash
# CORE-037 Agent Prompt Template: 8 required sections
RETEST_PROMPT=$(cat <<'AGENT_PROMPT'
1. ROLE: Ban la retest agent cho wf-e2e-fix F6, spawned de verify fix cho issue ${ISSUE_ID}.

2. TASK: Doc file .claude/skills/workflow/wf-e2e-retest/SKILL.md va thuc thi day du.
   Scope retest: ${ISSUE_TYPE} (chi test lai loai issue vua duoc fix).
   Khong chay full F5 pipeline — chi retest item cu the.

3. SESSION CONTEXT:
   - SESSION_DIR: ${SESSION_DIR}
   - Session ID: ${SESSION_ID}
   - Issue duoc fix: ${ISSUE_ID} (type: ${ISSUE_TYPE}, file: ${FILE}, line: ${LINE})
   - Fix method: ${FIX_METHOD}
   - Scope: ${ISSUE_TYPE} (ui | api | db | integration | code-bug)

4. CI CONTEXT (CORE-033):
   ${CI_CONTEXT:-"CI khong kha dung — fallback Grep/Glob."}

5. PLAYWRIGHT CONTEXT:
   - Mode: ${SHOW_BROWSER:-headless}
   - Browser lock: ${SESSION_DIR}/_locks/browser-mcp.lock (acquisition required neu scope=ui)
   - Skip Playwright neu scope != ui

6. OUTPUT CONTRACT:
   - Retest report: ${SESSION_DIR}/F5-retest/retest-report.md (APPEND ket qua cho ${ISSUE_ID})
   - Update issues.json neu retest FAIL: status open -> open, fix_attempts append retry
   - Neu retest PASS: issues.json signals[].status giu nguyen "fixed"
   - KHONG ghi de F6 fix-log.json

7. OWNERSHIP RULES (CORE-037):
   - 1 file = 1 writer
   - F5 chi ghi vao F5-retest/ directory
   - F5 duoc phep UPDATE issues.json signals[].retest_result field
   - F5 KHONG duoc sua fix_attempts cua F6 (F6 se tu update dua tren retest_result)

8. COMPLETION CRITERIA:
   - Retest report chua ket qua PASS/FAIL cho ${ISSUE_ID}
   - Neu PASS -> return "PASS"
   - Neu FAIL -> return "FAIL" + failure details
   - Neu ERROR -> return "ERROR" + error message
AGENT_PROMPT
)

# Spawn F5
# Agent --subagent_type=general-purpose --description="F6 retest ${ISSUE_ID}" --prompt="$RETEST_PROMPT"
```

---
## Per-Issue Fix Detail

```
function apply_serena_fix(issue):
  file = issue.location.split(':')[0]
  line = issue.location.split(':')[1]
  
  # Detect fix strategy by issue.type
  case issue.type:
    "db":
      # EF migration / constraint fix
      # Read entity config, identify wrong constraint
      # Use mcp__serena__replace_symbol_body to fix
      
    "api":
      # Endpoint handler fix
      # Read handler code, identify wrong logic (missing validation, wrong status code, BR violation)
      # mcp__serena__replace_content for targeted line replacement
      
    "ui":
      # Component/hook fix
      # Read component, identify missing state handling / wrong validation
      # mcp__serena__replace_content
      
    "integration":
      # Service layer / event handler fix
      # Read service, identify chain logic issue
      # mcp__serena__replace_symbol_body
      
    "seed-data":
      # Regenerate seed SQL
      # Read findings/db-seed-data.md, identify gap
      # Update md file + re-run via psql
      
    "code-bug":
      # Generic code fix
      # Use Serena replace based on description + expected/actual
  
  # All paths: validate fix didn't break compile (best-effort)
  
  # Return: "applied" | "failed" | "skipped"
```

---

## Output: fix-log.json

```json
{
  "$schema": "wf-e2e-fix-log-v1",
  "session_id": "{SESSION_ID}",
  "rounds": [
    {
      "round_num": 1,
      "started_at": "2026-05-13T16:00:00Z",
      "completed_at": "2026-05-13T16:15:00Z",
      "issues_attempted": 8,
      "issues_fixed": 5,
      "issues_retest_fail": 2,
      "issues_locked": 1,
      "details": [
        {
          "issue_id": "ISS-001",
          "type": "api",
          "severity": "high",
          "file": "apps/backend/Eureka.Api/Endpoints/CrmEndpoints.cs",
          "fix_method": "serena_replace_content",
          "result": "fixed",
          "retest_result": "PASS",
          "retry_count": 0
        }
      ]
    }
  ],
  "summary": {
    "total_rounds": 1,
    "total_issues_fixed": 5,
    "total_still_fail": 1,
    "total_deferred_locked": 1,
    "remaining_open": 0
  }
}
```
