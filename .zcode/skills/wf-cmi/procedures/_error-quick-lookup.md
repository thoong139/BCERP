# Error Quick Lookup — wf-cmi v3.0

> **Mục đích:** Bảng tra cứu nhanh 30+ error codes của wf-cmi (E001-E199). Extract từ SKILL.md để giảm context budget (CORE-038) và giữ SKILL.md ≤500 dòng (CORE-032).
>
> **Cách dùng:**
> - Phase procedure files reference codes của mình ở `§F Error Code Quick Reference`
> - Skill orchestrator (SKILL.md) chỉ cần namespace overview + link đến file này
> - Đầy đủ E001-E199 detail + auto-fix strategy: `docs/04-skill-design/wf-cmi/05-error-codes.md`

---

## Namespace Convention

```
E001-E009   → Pipeline/session/lock (shared)
E010-E019   → Phase 1 Init (args, CI PRE-GATE, registry, lock)
E020-E029   → Phase 2 Discovery (6 graph builds)
E030-E039   → Phase 3 Invariant (LLM, domain expert, schema)
E040-E049   → Phase 4 Coverage Dispatch (lane spawn, signals)
E050-E059   → Phase 5 Aggregate (compute, matrix, threshold)
E060-E069   → Phase 6 Regression (impact, predict, test plan)
E070-E079   → Phase 7 GAP + CDG (suggestion, decision log)
E080-E089   → Phase 8 Report (artifact write, audit chain)
E090-E099   → CDG User-Facing Gates (coverage, conflict, compliance)
E100-E109   → Warnings (CI degrade, stale cache, low confidence)
E110-E112   → v2.0 Migration (E110 v1 session resume / E111 skeleton dim / E112 SKIPPED override)
E120-E123   → Phase 4 Wave gate (E120-E122 per-wave ≥3 fail STOP / E123 1-2 fail WARN)
E130-E135   → v2 lane-specific (CD11-CD18 FE/BE graph deps fail)
E140-E148   → v2 lane SSOT deps (CD28/CD30/CD31/CD37 logistics critical, CD38-CD40 ★ implementations)
E149        → v3.0 prep (CD32-CD36 skeleton WARN)
E150-E159   → v3 Phase 9 PRE-GATE / setup (Playwright unavailable, FE down, lock conflict, manifest invalid)
E160-E169   → v3 Phase 9 Execute (step fail, snapshot fail, timeout, navigate fail)
E170-E179   → v3 Phase 9 Stability (lint fail, flakiness check, quarantine, stable-registry)
E180-E189   → v3 Phase 10 Analysis (classify UNKNOWN, evidence partial)
E190-E199   → v3 Phase 10 Auto-fix (spawn agent fail, HMR timeout, post-fix verify fail)
E195        → v3 Phase 10 CDG user-facing (require `--auto-fix-source` confirm)
E195b       → v3 Phase 1 CDG user-facing (subset E2E execute confirm khi profile=quick|standard + --exec-scenarios)
```

---

## Quick Lookup Table

| Code | Severity | Tình huống | Xử lý |
| ---- | -------- | ---------- | ----- |
| E001 | critical | POST-GATE fail sau 3 retries | DỪNG, escalate AskUserQuestion |
| E003 | critical | Registry thiếu/rỗng | STOP — chạy `/wf-brainstorm` hoặc `/existing-project` |
| E005 | info | 0 violations + 100% coverage | Early exit OK — system healthy |
| E008 | medium | Stale lock detected (≥30 min) | Auto-release, WARN, continue |
| E009 | critical | Context budget > 90% | FORCE checkpoint, STOP — dùng `--resume` |
| E010-E013 | critical | Registry/architecture docs missing | STOP, hướng dẫn prerequisite skill |
| E014-E016 | high | Args invalid (`--since`/`--session-id`/conflict flags) | ESCALATE — user fix args |
| E016b | high | v3 mutual-exclusive flag combination invalid | STOP, hướng dẫn user fix |
| E018 | high | Lock acquire fail (peer session) | Retry x3 với 5s delay, ESCALATE |
| E020-E029 | medium | Graph build fail | Per-graph retry, fallback heuristic Grep |
| E030-E039 | medium-high | Invariant inference fail | Retry, fallback business-analyst, CDG E091 cho conflict |
| E040-E049 | medium-high | Lane spawn/timeout/schema fail | Per-lane retry x1, batch retry nếu ≥3 fail |
| E050-E059 | medium | Aggregate/matrix fail | Re-aggregate, re-format |
| E060-E069 | medium | Regression scope/predict fail | Fallback diff-aware, WARN |
| E070-E079 | medium | CDG decision/suggestion fail | Retry x1, escalate |
| E080-E089 | high | Artifact write/audit chain fail | Retry x3, ESCALATE |
| E090-E099 | info | CDG user-facing gates | DỪNG, AskUserQuestion |
| E100-E109 | low | Warnings — CI degrade/cache/confidence | LOG, continue |
| E110 | high | v2.0 Migration: resume v1 session với v2 binary | AskUser fresh start hoặc continue legacy 10-lane |
| E111 | medium | v2.0 Migration: --dims=CD32-CD36 skeleton requested | WARN, drop từ active set |
| E112 | medium | v2.0 Migration: --dims=CD{SKIPPED} override SKIPPED | WARN, dispatch as exhaustive |
| E120-E122 | medium | Phase 4 Wave gate ≥3 fail/timeout per wave | STOP wave dispatch, ESCALATE batch |
| E130-E135 | medium-high | Lane CD11-CD18 graph dep fail (FE/BE) | Fallback Grep, downgrade signals confidence |
| E140-E143 | high | Lane CD28/CD30/CD31/CD37 ★★★ SSOT missing | ESCALATE — yêu cầu logistics/finance/compliance expert define |
| E144-E148 | medium | Lane CD23-CD26/CD29/CD38-CD40 SSOT missing | WARN, partial coverage fallback heuristic |
| E149 | low | CD32-CD36 skeleton v3-deferred in --dims | WARN, skip — v3 sẽ activate |
| E150 | info | v3 Playwright MCP unavailable | SKIP Phase 9-10, xuất integrity-report v3 với e2e_execution_summary=null, WARN |
| E150b | info | v3 CD41 skipped (profile=quick|standard, no scenarios synth) | SKIP Phase 9-10, WARN |
| E151 | high | v3 Phase 9 Lint scenarios FAIL | BLOCK Phase 9, ghi lint-fixes.md, AskUser fix/skip |
| E152 | medium | v3 Scenario flaky (≤3/5 pre-flight PASS) | Auto-quarantine, SKIP scenario, continue others |
| E153 | high | v3 browser-mcp.lock conflict 30 min+ | Auto-release stale, retry x1, ESCALATE |
| E160 | medium | v3 Scenario step execute fail | Retry x3, mark FAIL, defer Phase 10 |
| E170 | low | v3 Stable-registry corruption | Re-init registry, WARN |
| E180 | medium | v3 Failure classification UNKNOWN | Log, manual triage prompt |
| E190 | high | v3 Phase 10 Spawn agent fail | Retry x1, ESCALATE |
| E195 | info | v3 Phase 10 CDG source-fix confirm (`--auto-fix-source`) | AskUserQuestion accept/reject/skip-this-time |
| E195b | info | v3 Phase 1 CDG subset E2E confirm (profile=quick|standard + --exec-scenarios) | AskUserQuestion execute-all/execute-MUST-only/cancel; --no-prompt → default execute-MUST-only |

---

## Cross-References

| Reference | Section |
| --------- | ------- |
| `SKILL.md §Error Handling` | Namespace overview + link đến file này |
| `procedures/_shared.md §Error Handling Canonical` | Auto-fix strategy chi tiết per phase |
| `procedures/phase{N}-*.md §F Error Code Quick Reference` | Per-phase namespace detail |
| `docs/04-skill-design/wf-cmi/05-error-codes.md` | Full table E001-E199 + auto-fix matrix |

---

**END _error-quick-lookup.md**
