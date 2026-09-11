# wf-fix-bugs Shared Protocols — Index (v10.13.0+)

> Cross-cutting protocols, state variables glossary, error handling, CI detection, Playwright integration, và các pattern được dùng bởi nhiều Phase trong wf-fix-bugs.
>
> **v10.13.0 split:** Trước đây gộp trong 1 file `_shared.md` (~1227 dòng / ~10K tokens). Từ v10.13.0 tách thành 21 file riêng để phase files chỉ load section cần thiết → giảm ~80-95% context per phase invocation.
>
> **KHÔNG đọc toàn bộ folder** — phase files chỉ reference section cụ thể cần dùng.

## Prerequisite cho mọi phase

> **BẮT BUỘC trước khi invoke bất kỳ helper function nào:**
> `source .claude/scripts/wf-fix-common.sh` đã được gọi tại Phase 1 Init (Step 1.1).
> Nếu invoke procedure file standalone (test/debug), tự source từ repo root trước.

## Sections Index

| § | File | Mô tả | Lines | Phases dùng |
|---|------|------|-------|------------|
| §1 | [01-state-vars.md](01-state-vars.md) | State Variables Glossary + _contract.json reference | ~50 | All |
| §2 | [02-data-flow.md](02-data-flow.md) | Cross-Phase Data Flow diagram | ~50 | All |
| §3 | [03-atomic-write.md](03-atomic-write.md) | Atomic Write Pattern (CORE-006) | ~25 | All |
| §4 | [04-error-handling.md](04-error-handling.md) | Error Handling Canonical — namespace + codes table | ~100 | All |
| §5 | [05-auto-fix.md](05-auto-fix.md) | Auto-Fix & Escalation Protocol | ~40 | All |
| §6 | [06-on-failure.md](06-on-failure.md) | On Failure Standard Format | ~30 | All |
| §7 | [07-execution-trace.md](07-execution-trace.md) | Execution Trace (CORE-026) | ~40 | All |
| §8 | [08-phase-summary.md](08-phase-summary.md) | Phase Summary (CORE-028) | ~30 | All |
| §9 | [09-context-checkpoint.md](09-context-checkpoint.md) | Context & Checkpoint (CORE-038) | ~65 | 4,5,6,7 |
| §10 | [10-template-usage.md](10-template-usage.md) | Template Usage Rule (CORE-031) | ~35 | All |
| §11 | [11-task-planning.md](11-task-planning.md) | Task Planning (Protocol 9) | ~30 | 1 |
| §12 | [12-ci-detection.md](12-ci-detection.md) | CI Detection Pattern (Protocol 20) | ~35 | 1,2,5,6 |
| §13 | [13-lock-heartbeat.md](13-lock-heartbeat.md) | Lock/Heartbeat Pattern | ~45 | 1,3 |
| §14 | [14-bash-delegation.md](14-bash-delegation.md) | Bash Delegation Pattern | ~25 | All |
| §15 | [15-agent-prompts.md](15-agent-prompts.md) | Agent Prompt Templates (Lane/Triage/Execute) | ~60 | 4,5,6 |
| §16 | [16-sub-probe-template.md](16-sub-probe-template.md) | Sub-Probe Template (cross-skill cho lane skills) | ~140 | 4 |
| §17 | [17-session-isolation.md](17-session-isolation.md) | Session Isolation Protocol | ~25 | 1 |
| §18 | [18-playwright.md](18-playwright.md) | Playwright Integration Pattern | ~80 | 4 |
| §19 | [19-bug-dashboard.md](19-bug-dashboard.md) | Bug Dashboard Update Pattern | ~70 | 1,5,6,7 |
| §20 | [20-cdg-tokens.md](20-cdg-tokens.md) | CDG Token Persist Pattern | ~110 | 1,4,5 |
| §21 | [21-atomic-call-wrapper.md](21-atomic-call-wrapper.md) | Atomic-Call Wrapper Pattern (meta) | ~150 | All (reference) |

**Tổng:** 21 file, ~1300 dòng (split + slim). Trước v10.13: 1 file `_shared.md` 1227 dòng monolithic.

## Per-phase load profile (estimated)

| Phase | Sections cần | Tổng lines load | vs old (1227) | Saving |
|-------|-------------|-----------------|--------------|--------|
| Phase 1 | §13 + §19 | ~115 | -1112 | **91%** |
| Phase 2 | §7 | ~40 | -1187 | **97%** |
| Phase 3 | §13 (lock-only) | ~45 | -1182 | **96%** |
| Phase 4 | §15 + §18 + §20 + §16 (sub-probes) | ~390 | -837 | **68%** |
| Phase 5 | §15 (Triage) + §20 (Phase 5 pattern) | ~170 | -1057 | **86%** |
| Phase 6 | §15 (Execute) + §20.1 | ~150 | -1077 | **88%** |
| Phase 7 | §6 + §19 | ~100 | -1127 | **92%** |

## Slim notes (v10.13.0)

4 sections đã được slim hóa thành 1-line pointers vì duplicate với `rules/00-core.md`:
- **§1** State Vars — phần variable types đã canonical trong CORE rules
- **§4** Error Handling — namespace convention canonical CORE-034, codes table giữ lại
- **§10** Template Usage — quy tắc canonical CORE-031 + Protocol 19
- **§17** Session Isolation — quy tắc canonical CORE-030 + CORE-035

## Backward Compatibility

File `_shared.md` cũ vẫn tồn tại làm **redirect file** (~30 dòng) — pointer đến `_shared/` folder. Bất kỳ phase file nào còn reference `_shared.md §NN` vẫn hoạt động trong giai đoạn transition. Migration sang `_shared/NN-name.md` được khuyến nghị.
