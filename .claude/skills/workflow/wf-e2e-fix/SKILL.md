---
name: wf-e2e-fix
version: 1.1.0
last_updated: 2026-09-12
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
| **Prerequisites** | `issues.json` (hoặc `--path=<file>`) có ≥1 entry status=open + `--session=<id>` BẮT BUỘC + Serena/GitNexus khả dụng hoặc fallback (PRE-GATE T1-T4) |
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

## Phase 0: Load & Sort Issues (BẮT BUỘC — entry point)

> Chi tiết: `procedures/fix-loop.md` ROUND header. Tóm tắt bước thực thi:

| Step | Action | Verify |
|------|--------|--------|
| 1 | PRE-GATE T1-T4: issues.json tồn tại + schema valid + ≥1 status=open + required fields | Fail → E060 |
| 2 | CI PRE-GATE Na-Nc (impact analysis cần GitNexus; surgical fix cần Serena) | CI flags set |
| 3 | READ issues.json → filter status=open (exclude still_fail/deferred-locked/unfixable) → SORT severity critical→low | Danh sách sort sẵn sàng |
| 4 | Route vào fix loop ROUND N (fix-loop.md) | Round entry ghi fix-log.json |

## Phase Routing Map (CORE-032 lazy-load)

| # | Phase | Procedure file | Mô tả |
|---|-------|---------------|-------|
| **0** | Load + Sort | `procedures/fix-loop.md` §ROUND | PRE-GATE + filter + sort issues |
| **1** | Fix per issue | `procedures/fix-loop.md` | Impact check → lock → surgical fix (Serena) → UPDATE issues.json atomic |
| **2** | Spawn retest | `procedures/fix-loop.md` §F5 | SPAWN F5 wf-e2e-retest --scope=<type> → đọc retest-report → fixed/retry |
| **3** | Retry budget | `procedures/retry-budget.md` | Retry 0-3 per issue; hết → still_fail SKIP forever |
| **R** | Resume/Status | `procedures/resume-status.md` | --resume / --status handlers |

CI PRE-GATE steps (Na-Nc):

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

## Error Handling

Codes E060-E069 (per-skill namespace):

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

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| Retest FAIL sau fix (retry 0-2) | Re-read code, re-analyze với context khác; retry 2 spawn Agent subagent_type=developer 2nd opinion | Retry 3 → status=still_fail, SKIP forever |
| Surgical fix fail (E063) | Retry với replace_content (narrower scope) nếu replace_symbol_body fail | Vẫn fail → mark issue unfixable candidate, hỏi user |
| Impact HIGH/CRITICAL (E066) | KHÔNG auto-fix — log WARN + user confirm bắt buộc | User từ chối → defer issue (deferred-locked) |
| Lock conflict (E064) | Chờ source-{hash}.lock release rồi retry acquire | Vẫn conflict → SKIP issue này round hiện tại |
| Anti-loop F6↔F5 (E068) | Orchestrator đếm vòng; F6 tự STOP khi detect loop | Max 3 vòng → E068 escalate orchestrator |
| Atomic write fail (E069) | Restore từ temp rồi write lại | Temp hỏng — STOP |

---

## Output Files

| File | Path (trong session) | Loại |
|------|----------------------|------|
| fix-log.json + Phase-report.md (CORE-028) | `F6-fix/` | CREATE |
| status.json | `F6-fix/` | CREATE + UPDATE |
| issues.json | session root | READ + UPDATE (open → fixed/still_fail/deferred-locked/unfixable) |
| Code patches | source tree | EDIT (surgical qua Serena) |

> **Next:** F6 xong → F5 `/wf-e2e-retest` xác nhận (hoặc F6 tự spawn trong loop); hết open → orchestrator `/wf-e2e-verify` tiếp F7/F8.

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
