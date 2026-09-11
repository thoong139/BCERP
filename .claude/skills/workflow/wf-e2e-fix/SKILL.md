---
name: wf-e2e-fix
version: 1.0.0
last_updated: 2026-05-13
description: |
  F6 trong chuỗi wf-e2e-* (chia tách từ wf-e2e-verify v6.5.0 cờ --fix).
  Continuous fix loop: đọc issues.json (status=open) → sort severity → fix surgical → spawn F5 retest → update issues → lặp.
  Max 3 retry/issue. DỪNG khi: hết open OR tất cả còn lại đều still_fail/deferred-locked/unfixable.
  YÊU CẦU --session=<id>.

  TRIGGER khi: "fix bugs", "sửa lỗi", "fix loop", "auto-fix issues".
  KHÔNG trigger: cần thiết kế lại (manual review), cross-module fix (orchestrator coordinate).

argument-hint: "<FEAT-ID> --session=<id> [--path=<issues.json|report.md>] [--auto] [--resume] [--status]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, Agent,
  mcp__serena__find_symbol, mcp__serena__find_referencing_symbols,
  mcp__serena__replace_content, mcp__serena__replace_symbol_body,
  mcp__gitnexus__impact, mcp__gitnexus__detect_changes
---

# /wf-e2e-fix: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Continuous fix loop cho issues phát hiện bởi F1/F2/F5/F7/F8 |
| **Standalone** | NO — require `--session=<id>` |
| **Input** | `issues.json` (default) HOẶC `--path=<custom>` |
| **Output** | `fix-log.json`, code patches, UPDATE `issues.json` (open → fixed/still_fail/deferred-locked/unfixable) |
| **Strategy** | Surgical changes (BHV-003) qua Serena. Max 3 retry/issue. Spawn F5 retest sau mỗi fix |

### Flow

```
[--session] → [LOAD issues.json status=open] → [SORT severity critical→low]
→ FOR each issue:
    1. gitnexus_impact check (HIGH/CRITICAL → WARN)
    2. Acquire source-{hash}.lock (nếu cần)
    3. SURGICAL fix qua Serena replace_symbol_body/replace_content
    4. RELEASE lock
    5. UPDATE issues.json status: open → fixed (atomic)
    6. SPAWN F5 wf-e2e-retest --scope=<issue-type>
    7. IF retest FAIL → fix_attempts[]++ retry (max 3)
    8. IF retest FAIL 3 lần → status=still_fail
→ Cuối loop: còn issue open + fix-able? → LẶP LẠI
→ STOP khi hết open OR tất cả still_fail/deferred-locked/unfixable
```

---

## Workflow Position

```
F1 (issues.json initial) → F2 (more issues) → F5 (retest reveals more)
        │                                            │
        └────────────────────────┬───────────────────┘
                                 ▼
                          ┌─────────┐
                          │   F6    │ ← wf-e2e-fix (skill này)
                          │ Fix loop│
                          └────┬────┘
                               ▼
                       F5 retest (spawned per fix)
                               │
                               ▼
                          Orchestrator anti-loop check (max 3 vòng F6↔F5)
```

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `<FEAT-ID>` | Feature ID | required |
| `--session=<id>` | Session ID (BẮT BUỘC) | required |
| `--path=<file>` | Path tới issues.json hoặc report.md (legacy --fix=<path>) | `$SESSION_DIR/issues.json` |
| `--auto` | Auto-confirm fixes không hỏi user | disabled |
| `--resume` | Resume fix loop từ checkpoint | - |
| `--status` | Display fix progress + STOP | - |

---

## CI PRE-GATE (CORE-033)

> CI tools auto-detect. F6 can CI cho impact analysis (GitNexus) + surgical fix (Serena).

| Step | Action | Verify |
|------|--------|--------|
| **Na** | Load CI Capabilities: Run `bash .claude/scripts/ci-detect.sh`. | CI flags set |
| **Nb** | Index Freshness Check: Run `bash .claude/scripts/ci-freshness-check.sh`. | Freshness status set |
| **Nc** | Agent Context Injection: Run `bash .claude/scripts/ci-inject-context.sh` -> `$CI_CONTEXT`. | CI context ready |

### CI-ROUTE

| CI Task | Primary Tool | Fallback |
|---------|-------------|----------|
| `impact_analysis` | GitNexus `impact({target})` | Grep |
| `symbol_overview` | Serena `get_symbols_overview` | Read |
| `find_by_annotation` | Serena `find_referencing_symbols` | Grep REQ-ID |

---
## Session Structure

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── issues.json                      ← F6 READ + UPDATE
├── F6-fix/
│   ├── status.json                  ← F6 own state
│   ├── fix-log.json                 ← Per-round, per-issue log
│   ├── delegate-receipts/           ← (rare) nếu F6 spawn F5 standalone
│   └── Phase-report.md              ← CORE-028 summary
```

---

## Continuous Fix Loop (canonical)

```
ROUND N:
  1. READ issues.json → filter status=="open" (exclude still_fail, deferred-locked, unfixable)
  2. IF empty → DONE, STOP
  3. SORT by severity (critical → high → medium → low)
  4. FOR each issue:
      a. CHECK fix_attempts.length >= 3 → MARK still_fail, SKIP
      b. CHECK gitnexus_impact(issue.location) → IF HIGH/CRITICAL: log WARN
      c. ACQUIRE source-{hash}.lock (file-level fcntl)
      d. SURGICAL FIX qua mcp__serena__replace_content / replace_symbol_body
      e. RELEASE lock
      f. UPDATE issues.json (atomic): status="open"→"fixed", append fix_attempts[], fixed_at, fix_note
      g. SPAWN F5 wf-e2e-retest --scope=<issue.type> --session=<id>
      h. WAIT F5 complete → READ F5-retest/retest-report.md
      i. IF retest PASS → keep status="fixed"
      j. IF retest FAIL → status="open" again, increment fix_attempts.retry_count
  5. END FOR
  6. APPEND fix-log.json round entry
  7. IF còn open + retry_count < 3 → ROUND N+1
  8. ELSE → DONE
```

---

## PRE-GATE (CORE-011)

1. **T1:** `issues.json` (or `--path=<file>`) tồn tại
2. **T2:** Schema valid — `jq -e '.signals' issues.json` pass
3. **T3:** Có ≥1 entry status=open
4. **T4:** Mỗi entry có `id`, `type`, `severity`, `location`, `status`

Fail → E060 "issues.json invalid hoặc rỗng".

---

## POST-GATE (CORE-012)

1. **T1:** `fix-log.json` tồn tại
2. **T2:** `issues.json` summary counts khớp với entries
3. **T3:** Mỗi issue có ≥1 fix_attempts entry hoặc status=still_fail
4. **T4:** Không có status=open còn lại (hoặc tất cả còn lại đều có retry_count >= 3)

Fail → auto-fix retry (max 3) → E065.

---

## Retry Budget per Issue (CORE-034)

| Retry | Action |
|-------|--------|
| 0 | First fix attempt |
| 1 | Re-read code, re-analyze, fix lại với context khác |
| 2 | Spawn Agent với subagent_type=developer cho 2nd opinion |
| 3 | Max — mark status=still_fail, SKIP forever |

`status="still_fail"` không trigger F5 retest nữa.

---

## --resume + --status

Xem `procedures/resume-status.md`.

**--status:** Display fix progress (issue count by status + round count) + STOP.
**--resume:** Tiếp tục từ round N hiện tại, skip issues đã fixed/still_fail.

---

## Error Codes (E060-E069)

| Code | Mô tả |
|------|-------|
| E060 | issues.json invalid hoặc rỗng |
| E061 | --session thiếu |
| E062 | --path file không tồn tại |
| E063 | Surgical fix fail (Serena không apply được) |
| E064 | Lock conflict (parallel-safe luôn ON) |
| E065 | POST-GATE T4 fail (còn open ngoài retry budget) |
| E066 | gitnexus_impact HIGH/CRITICAL → user confirm cần thiết |
| E067 | F5 spawn fail |
| E068 | Anti-loop F6↔F5 max 3 vòng (escalate orchestrator) |
| E069 | Atomic write fail |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `wf-e2e-test` / F2 / F5 / F7 / F8 | Producer issues.json entries |
| `wf-e2e-retest` (F5) | F6 spawn F5 sau mỗi fix |
| `wf-e2e-verify` orchestrator | Anti-loop check (max 3 vòng F6↔F5) |

---

## Backward Compatibility

Legacy `/wf-e2e-verify <FEAT-ID> --fix=<path>` → orchestrator detect → spawn F6 với `--path=<path> --session=<id>`.
