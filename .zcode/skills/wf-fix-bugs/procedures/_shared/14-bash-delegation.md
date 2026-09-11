# §14 Bash Delegation Pattern

> Python CLI invocation pattern cho `_shared/` modules.

```bash
# Pattern chung cho Python CLI:
cd .claude/skills/workflow/_shared
python -m <module> --session-dir="$SESSION_DIR" [other args]

# Ví dụ:
python -m isg --session-dir="$SESSION_DIR" --dims="$DIMS_ARRAY" --profile="$PROFILE"
python -m partition --session-dir="$SESSION_DIR" --inventory="$SCOPE_INVENTORY"
python -m aggregate --session-dir="$SESSION_DIR"
python -m dashboard_generator --template ../wf-fix-bugs/templates/phase5-triage/bug-dashboard.md --output "$SESSION_DIR/bug-dashboard.md" --session-id "$SESSION_ID" --project-name "$PROJECT_NAME" --scope "$SCOPE" --profile "$PROFILE" --current-phase "$CURRENT_PHASE" --issue-registry "$SESSION_DIR/phase5-triage/issue-registry.json" --fix-log "$SESSION_DIR/phase5-triage/fix-log.json" --total-signals "$TOTAL_SIGNALS" --dimensions-covered "$DIMS_COVERED" --dimensions-total "$DIMS_TOTAL"

# Bash scripts:
bash .claude/scripts/wf-fix-common.sh
bash .claude/scripts/wf-fix-<step>.sh [args]
```
