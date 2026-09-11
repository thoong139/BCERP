# Next Session Prompt — Code Intelligence Integration

> **Last updated:** 2026-05-06 (Sprint 7 DONE — ALL COMPLETE)
> **Plan dir:** `plans/code-intelligence-integration/`

---

## Status: COMPLETE — Tất cả 7/7 Sprints DONE

**26/26 findings resolved (100%), 12/12 design decisions implemented, ~11h total actual.**

---

## Sprint 7 deliverables (final)

| File | Status | Purpose |
|------|--------|---------|
| `CLAUDE.md` | MODIFIED | Added `## Code Intelligence Integration` section (auto-detect, freshness, concurrency 60s, CI-ROUTE quick ref, cache TTL) |
| `.claude/skills/protocols/evals/ci-evals.json` | CREATED | 26 eval test cases (detection, per-tool TTL, lock, freshness, migration, injection, degradation, concurrency) |
| `plans/code-intelligence-integration/progress.md` | MODIFIED | S7 marked DONE, all findings resolved, session log added |
| `.mc-data/work/_meta/code-intelligence.json` | CREATED | Live cache from E2E test (schema v2, per-tool TTL, index_commit matches HEAD) |

### E2E test results (all PASS on MCV3)

| Test | Result |
|------|--------|
| ci-detect.sh Phase 1: all_fresh | PASS |
| ci-detect.sh Phase 1: needs_scan (cache miss) | PASS |
| ci-detect.sh Phase 1: lock_held → exit 2 | PASS |
| ci-detect.sh Phase 1: no_git → exit 1 | PASS |
| ci-detect.sh Phase 2: --write-cache v2 | PASS |
| ci-detect.sh: MCV3_CI_RESCAN=1 force | PASS |
| ci-detect.sh: cache v1→v2 migration | PASS |
| ci-detect.sh: corrupt cache recovery | PASS |
| ci-freshness-check.sh: ok (HEAD == index) | PASS |
| ci-freshness-check.sh: warning light (1 behind) | PASS |
| ci-freshness-check.sh: unknown (missing index_commit) | PASS |
| ci-freshness-check.sh: skipped (non-git) | PASS |
| ci-inject-context.sh: Both-OK (265 chars) | PASS |
| ci-inject-context.sh: Both-Stale (390 chars) | PASS |
| ci-inject-context.sh: GitNexus-only | PASS |
| ci-inject-context.sh: Serena-only | PASS |
| ci-inject-context.sh: Neither → exit 1 | PASS |
| Lock acquire → write → release cycle | PASS |
| Stale lock > 60s → break + re-acquire | PASS |
| Serena absent TTL 1h → re-scan | PASS |
| GitNexus absent TTL 4h → re-scan | PASS |

### Multi-dev tests (all PASS)

| Test | Result |
|------|--------|
| Test 1: 2-terminal concurrency (lock_held→exit 2→fallback) | PASS |
| Test 2: Terminal 2 (10s later) → cache HIT | PASS |
| Test 3: Index stale after git pull → WARNING | PASS |
| Test 4: Serena absent TTL 1h → re-check → update | PASS |
| Test 5: Non-git → short-circuit, no ERROR | PASS |

### Compliance

| Check | Result |
|------|--------|
| wf-implement-feature | PASS |
| wf-fix-bugs | PASS |
| wf-fix-triage | PASS |
| wf-fix-execute | PASS |
| wf-manage-change | PASS |
| wf-legacy-scan | PASS |
| wf-design | PASS |
| wf-verify-sync | PASS |
| wf-plan-modules | PASS |
| Schema sync (9 modified) | 7/9 PASS (2 pre-existing template gaps: wf-design, wf-plan-modules) |

---

## Key deliverables (entire project)

| Deliverable | File |
|------|------|
| Protocol 20 (11 sections) | `.claude/skills/protocols/20-code-intelligence.md` |
| CI detection script | `.claude/scripts/ci-detect.sh` |
| Freshness check script | `.claude/scripts/ci-freshness-check.sh` |
| Agent injection script | `.claude/scripts/ci-inject-context.sh` |
| Cache schema v2 | `.claude/skills/templates/code-intelligence.schema.json` |
| CI evals (26 tests) | `.claude/skills/protocols/evals/ci-evals.json` |
| CLAUDE.md CI section | `CLAUDE.md` |
| 9 integrated skills | `wf-implement-feature`, `wf-fix-bugs`, `wf-fix-triage`, `wf-fix-execute`, `wf-manage-change`, `wf-legacy-scan`, `wf-design`, `wf-verify-sync`, `wf-plan-modules` |
| Protocols README | `.claude/skills/protocols/README.md` (updated to 20 protocols) |

## Lưu ý cho tương lai

- Cache file `.mc-data/work/_meta/code-intelligence.json` là local per máy, không git-sync
- Sau `git pull` lớn, user nên chạy `gitnexus analyze` để refresh index
- `MCV3_CI_RESCAN=1` cho phép force re-detect tất cả CI tools
- Lock timeout 60s — có thể điều chỉnh qua biến `STALE_TIMEOUT_SEC` trong ci-detect.sh
- 2 pre-existing schema sync issues (wf-design digest templates, wf-plan-modules shared templates) — not blocking
