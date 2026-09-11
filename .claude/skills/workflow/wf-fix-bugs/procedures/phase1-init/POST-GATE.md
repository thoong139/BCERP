# Phase 1 POST-GATE + Error Reference

> **Entry condition:** Group G PASS (TRACE START + TodoWrite init complete).
> **Exit condition:** All T1-T5 checks PASS → advance Phase 2.
> **Next:** Phase 2 — `procedures/phase2-scan.md`.

## POST-GATE T1-T5 Validation

```bash
# T1 — File existence
test -s "$SESSION_DIR/fix-status.json"

# T2 — Structure validation
jq -e '.session_id and .phases' "$SESSION_DIR/fix-status.json"

# T3 — Content depth
test -f "$SESSION_DIR/.lock"
test -s "$SESSION_DIR/session-log.json"

# T4 — Cross-reference matching
jq -e '.dimensions | length > 0' "$SESSION_DIR/fix-status.json"

# T5 — Dashboard initialized
test -s "$SESSION_DIR/bug-dashboard.md"
```

**Tất cả T1-T5 PASS → Phase 1 hoàn tất, advance sang Phase 2.**

## Phase 1 Report Summary

Sau POST-GATE pass, `phase1-init/Phase1-report.md` đã được tạo (qua Wave 4) với:

- Session ID, scope, profile, dimensions đã chọn
- CI tools status (GitNexus: available/unavailable, Serena: available/unavailable, freshness level)
- Playwright config (mode: headless/visible, mobile devices nếu có)
- Các CDG decisions (defer Phase 4) + Auto-resolve notes (E091/E092/E093)
- Bug dashboard initialized at `$SESSION_DIR/bug-dashboard.md`

## On Failure — Quick Reference

| Code | Xử lý |
|------|-------|
| E001 | Script prerequisite missing → STOP, kiểm tra installation |
| E002 | Flag parse fail → Fallback default values + WARN |
| E003 | Registry thiếu hoặc source code thiếu → STOP, hướng dẫn `/wf-brainstorm` |
| E004 | Sub-skill SKILL.md missing → STOP, kiểm tra installation |
| E008 | Stale lock detected (≥30 phút) → Auto-release, re-acquire |
| E010 | `--status` dispatch → Route `resume-status.md §--status Handler` |
| E011 | `--resume` dispatch → Route `resume-status.md §--resume Handler` |
| E012 | `--migrate` dispatch → Delegate `scripts/wf-fix-migrate-sessions.sh` |
| E013 | Legacy deprecation block → CDG render + escape hatch `MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK=1` |
| E014 | CI detection fail → Graceful degrade Grep/Glob, continue |
| E015 | Non-git + no CI → Skip CI, continue |
| E016 | Severe index staleness (>50 commits) → WARN, fallback Grep |
| E019 | Lock acquire fail → STOP, process khác active |
| E023 | Flag conflict (--deep + --no-browser) → WARN, log |
| E030 | Profile resolve fail → Fallback `standard` dimensions |
| E035 | File write fail → Retry x1, nếu vẫn fail → STOP |
| E090 | (Phase 4) Browser CDG → AskUserQuestion URL hoặc skip QD9 |
| E091 | Scope auto-resolve (no CDG v10.3+) → WARN log |
| E092 | Cost auto-resolve (no CDG v10.3+) → WARN log |
| E093 | Mobile auto-resolve (no CDG v10.3+) → INFO log |

## Resume Logic

Phase 1 KHÔNG hỗ trợ resume. Nếu bị interrupt:
- Chạy lại từ đầu (re-parse flags, re-create session với SESSION_ID khác)
- Session dir cleanup được xử lý bởi cleanup trap

**Lý do:** Phase 1 là khởi tạo thuần túy — không có intermediate state đáng để resume. Re-run Phase 1 an toàn (idempotent với SESSION_ID khác).

## Next Phase

Phase 2 — `procedures/phase2-scan.md`
