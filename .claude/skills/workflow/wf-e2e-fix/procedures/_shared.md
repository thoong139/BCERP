# F6 wf-e2e-fix — Shared Protocols

## State Variables

```
$SESSION_DIR = .mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
$F6_DIR = $SESSION_DIR/F6-fix/
$ISSUES = ${--path:-$SESSION_DIR/issues.json}
$FIX_LOG = $F6_DIR/fix-log.json
$STATUS = $F6_DIR/status.json
$RETEST_REPORT = $SESSION_DIR/F5-retest/retest-report.md  # F5 sẽ write
```

## PRE-GATE Forensic (CORE-011)

```bash
test -f "$ISSUES" || exit_with E060
jq -e '.signals' "$ISSUES" > /dev/null || exit_with E060
OPEN=$(jq -r '[.signals[] | select(.status=="open")] | length' "$ISSUES")
[ "$OPEN" -gt 0 ] || { echo "No open issues, nothing to fix"; exit 0; }
```

## Issue Filtering

```bash
# Filter chỉ status="open" (exclude still_fail, deferred-locked, unfixable)
ACTIONABLE=$(jq '[.signals[] | select(.status=="open")] | sort_by(.severity | (if . == "critical" then 0 elif . == "high" then 1 elif . == "medium" then 2 else 3 end))' "$ISSUES")

# Iterate
echo "$ACTIONABLE" | jq -c '.[]' | while read -r issue; do
  ID=$(echo "$issue" | jq -r '.id')
  RETRY=$(echo "$issue" | jq -r '.fix_attempts | length // 0')
  if [ "$RETRY" -ge 3 ]; then
    # Mark still_fail
    jq --arg id "$ID" '(.signals[] | select(.id==$id) | .status) = "still_fail"' "$ISSUES" > "$ISSUES.tmp"
    mv "$ISSUES.tmp" "$ISSUES"
    continue
  fi
  # ... fix logic
done
```

## Surgical Fix Pattern (BHV-003)

```bash
# 1. Determine fix method based on issue.type
case $TYPE in
  "db") METHOD="EF migration / SQL constraint";;
  "api") METHOD="Endpoints/.cs handler logic";;
  "ui") METHOD="React component / hook";;
  "integration") METHOD="Service layer / event handler";;
  "seed-data") METHOD="db-seed-data.md regen";;
  "code-bug") METHOD="Serena replace_symbol_body";;
esac

# 2. Locate file
LOCATION=$(echo "$ISSUE" | jq -r '.location')
FILE=$(echo "$LOCATION" | cut -d: -f1)
LINE=$(echo "$LOCATION" | cut -d: -f2)

# 3. Impact check
mcp__gitnexus__impact --target=$FILE --direction=upstream
# IF HIGH/CRITICAL → log WARN, prompt user (skip if --auto)

# 4. Acquire lock
HASH=$(echo "$FILE" | sha1sum | cut -c1-12)
LOCK="$SESSION_DIR/_locks/source-$HASH.lock"
# fcntl exclusive lock, wait max 30s
flock -x -w 30 "$LOCK" -c "
  # 5. Apply fix via Serena
  mcp__serena__replace_content --file=$FILE --old=... --new=...
"
# Lock auto-released after block

# 6. Atomic update issues.json
jq --arg id "$ID" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  (.signals[] | select(.id==$id) | .status) = "fixed" |
  (.signals[] | select(.id==$id) | .fixed_at) = $now |
  (.signals[] | select(.id==$id) | .fix_attempts) += [{
    "at": $now,
    "method": "serena_replace_content",
    "result": "applied"
  }]
' "$ISSUES" > "$ISSUES.tmp"
jq '.' "$ISSUES.tmp" > /dev/null || exit_with E069
mv "$ISSUES.tmp" "$ISSUES"
```

## F5 Spawn Pattern

```bash
# After each fix, spawn F5 retest
SCOPE=$(echo "$ISSUE" | jq -r '.type')
# Use Agent tool with general-purpose subagent_type
# Pass: --session=<id> --scope=$SCOPE

# F5 will write retest-report.md → F6 reads result
if grep -q "PASS" "$F5_DIR/retest-report.md" -A1 "ISS-$ID"; then
  echo "Retest PASS for ISS-$ID"
else
  # Revert status to open, increment retry
  jq --arg id "$ID" '(.signals[] | select(.id==$id) | .status) = "open"' "$ISSUES" > "$ISSUES.tmp"
  mv "$ISSUES.tmp" "$ISSUES"
fi
```

## Anti-Loop Check (orchestrator coordination)

F6 chỉ chạy 1 lần per orchestrator pipeline. Orchestrator-level anti-loop check `f6_f5_loop_count` (max 3 vòng F6↔F5). F6 KHÔNG self-loop.

Mỗi lần orchestrator gọi F6 → F6 chạy continuous fix loop NỘI BỘ → F6 return → orchestrator gọi F5 standalone → nếu F5 reveals new issues → orchestrator gọi F6 lại (vòng 2/3).

## CI Detection (CORE-033)

> CI detection chay boi orchestrator. Sub-skill doc `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$CI_CONTEXT`.
> F6 can CI cho impact analysis (GitNexus) + surgical fix (Serena).

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
| 65-80% | Chuan bi checkpoint (luu status.json + fix-log.json) |
| 80-90% | STOP sau issue hien tai -> huong dan --resume |
| > 90% | FORCE STOP (E069 style) |

## Error Handling

| Error | Action |
|-------|--------|
| E063 | Surgical fix fail → retry x3 → still_fail |
| E064 | Lock timeout 30s → DEFER (`status="deferred-locked"`, `locked_by=<session>`) |
| E066 | gitnexus_impact HIGH/CRITICAL → AskUserQuestion (skip nếu --auto) |
| E067 | F5 spawn fail → log, không retest, mark `retest_result=PENDING` |
| E069 | Atomic write fail → restore .tmp, retry |
