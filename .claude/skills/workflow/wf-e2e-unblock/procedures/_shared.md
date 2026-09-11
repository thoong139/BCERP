# F3 wf-e2e-unblock — Shared Protocols

## State Variables

```
$SESSION_DIR = .mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
$F3_DIR = $SESSION_DIR/F3-unblock/
$BLOCK_TEST = $SESSION_DIR/block-test.json
$MANUAL = $SESSION_DIR/manual.json
$ISSUES = $SESSION_DIR/issues.json
$REPORT = $F3_DIR/unblock-report.md
$STATUS = $F3_DIR/status.json
```

## PRE-GATE Forensic (CORE-011)

```bash
# T1: file existence
test -f "$BLOCK_TEST" || exit_with E030

# T2: schema valid
jq -e '.blocked_tests' "$BLOCK_TEST" > /dev/null || exit_with E030

# T3: content depth (≥1 blocked entry)
COUNT=$(jq -r '[.blocked_tests[] | select(.status=="blocked")] | length' "$BLOCK_TEST")
[ "$COUNT" -gt 0 ] || exit_with E030

# T4: enum valid
jq -e '.blocked_tests[] | .blocking_reason | IN("missing_seed_data","missing_cross_module_data","seed_accounts_unavailable","actor_account_missing","backend_not_running","fe_not_running","missing_permissions","feature_deferred","feature_not_implemented","requires_visual_inspection","requires_manual_interaction","external_dependency","flaky_test","requires_human_judgment","other")' "$BLOCK_TEST" > /dev/null || exit_with E012
```

## LOAD blocks

```bash
# Load + group entries
GROUPS=$(jq -r '.blocked_tests[] | select(.status=="blocked") | .blocking_reason' "$BLOCK_TEST" | sort | uniq -c)

# Route per blocking_reason:
# Nhóm 1: missing_seed_data, missing_cross_module_data, seed_accounts_unavailable, actor_account_missing
# Nhóm 2: backend_not_running, fe_not_running, missing_permissions  
# Nhóm 3: feature_deferred, feature_not_implemented (SKIP)
# Nhóm 4: requires_visual_inspection, requires_manual_interaction, external_dependency, flaky_test, requires_human_judgment, other
```

## Atomic Write Pattern (CORE-035)

Mỗi lần update `block-test.json` hoặc append `manual.json`:

```bash
# 1. READ current
CURRENT=$(cat "$FILE")

# 2. Build new (jq filter)
NEW=$(echo "$CURRENT" | jq --arg id "BLK-NNN" '...')

# 3. Validate temp
echo "$NEW" > "$FILE.tmp"
jq '.' "$FILE.tmp" > /dev/null || exit_with E036

# 4. Atomic move
mv "$FILE.tmp" "$FILE"
```

## Group 3 SKIP + Strict Task Generation (v2.0.0)

> v2.0.0: F3 không chỉ SKIP mà còn BẮT BUỘC generate đầy đủ thông tin cho F4.
> Logic chi tiết: `procedures/unblock-group3-impl.md`.

```
# Bước 1: Collect Group 3 entries
GROUP3_ENTRIES = filter blocked_tests WHERE blocking_reason ∈ {feature_deferred, feature_not_implemented}
GROUP3_COUNT = len(GROUP3_ENTRIES)

# Bước 2: AUTO-FLAG nếu ≥5 tasks (CDG-07)
IF GROUP3_COUNT >= 5:
  LOAD procedures/unblock-group3-impl.md §Bước 2
  AskUserQuestion → user chọn: tiếp tục F4 | dừng arch review | chỉ P0/P1
  
# Bước 3-4: Với MỖI Group 3 entry, generate strict fields
FOR each BLK-NNN in GROUP3_ENTRIES:
  LOAD procedures/unblock-group3-impl.md §Bước 3 + 4
  resolve target_file, target_line, proposed_signature, acceptance_criteria
  append_group3_impl_req() → write vào implement-required.json (schema v2)
  update block-test.json: unblock_attempts += [{action: "skip — delegate to F4", ...}]
  KEEP status="blocked" + retest_result="PENDING"

# POST-GATE T3: Validate strict fields
LOAD procedures/unblock-group3-impl.md §Bước 5
validate_group3_strict_fields() → CHECK 4 fields per entry
IF FAIL → E030 → BLOCK F3, retry max 3
IF PASS → group3_processing="completed"
```

## CI Detection (CORE-033)

> CI detection chay boi orchestrator. Sub-skill doc `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$CI_CONTEXT`.
> F3 can CI cho Group 4 code verification (Serena find_symbol, GitNexus impact).

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
| 65-80% | Chuan bi checkpoint (luu status.json + block-test.json) |
| 80-90% | STOP sau group hien tai -> huong dan --resume |
| > 90% | FORCE STOP (E039 style) |

## Error Handling

| Error | Action |
|-------|--------|
| E030 | block-test invalid → STOP, suggest F1/F2 first |
| E031 | --session missing → STOP, ask user |
| E032 | Group 1 fix fail | Keep blocked, log fix-log |
| E033 | Group 2 fix fail | Alert user, keep blocked |
| E034 | Group 4 code FAIL → ISSUE | Append issues.json + escalate |
| E035 | POST-GATE fail | Auto-fix retry x3 |
| E036-E039 | Write/lock errors | Retry với backoff |

## Report Section Structure

`unblock-report.md` từ template `templates/unblock-report.template.md`. Sections:

1. **Tổng quan** — số block ban đầu, số đã unblock, số còn block
2. **Bảng kết quả** — BLK-ID | Test | Nhóm | Hành động | Kết quả (PASS/FAIL/SKIP/DEFERRED)
3. **Thống kê by_status** — blocked/unblocked/resolved counts
4. **Thống kê by_reason** — counts per enum
5. **Cần Implement (Group 3)** — list BLK-NNN delegate F4 + link IMPL-REQ-NNN
6. **Cần Người (Group 4 needs-human)** — list MAN-NNN với code_verification context
7. **Phase summary** (CORE-028) — tiếng Việt ≤15 dòng
