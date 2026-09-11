# Shared Protocols — wf-fix-bugs (REDIRECT FILE)

> **v10.13.0 (2026-05-16):** File này đã được TÁCH thành 21 file riêng trong [`_shared/`](_shared/) folder để giảm context load per phase invocation từ ~10K tokens xuống ~1-3K tokens (saving 80-95%).
>
> **KHÔNG đọc file này khi chạy runtime** — phase files giờ reference trực tiếp `_shared/NN-name.md` cụ thể.
>
> **Mục đích file này:** Backward compatibility cho các file cũ còn reference `_shared.md §NN`. Index pointer đến file mới.

## Quick Index → New Paths

| Section cũ | File mới | Mô tả |
|------------|----------|-------|
| §1 State Variables Glossary | [_shared/01-state-vars.md](_shared/01-state-vars.md) | Variable table + _contract.json reference |
| §2 Cross-Phase Data Flow | [_shared/02-data-flow.md](_shared/02-data-flow.md) | Phase 1→7 data flow |
| §3 Atomic Write Pattern | [_shared/03-atomic-write.md](_shared/03-atomic-write.md) | CORE-006 |
| §4 Error Handling Canonical | [_shared/04-error-handling.md](_shared/04-error-handling.md) | Namespace + codes table |
| §5 Auto-Fix & Escalation Protocol | [_shared/05-auto-fix.md](_shared/05-auto-fix.md) | Budget model |
| §6 On Failure Standard Format | [_shared/06-on-failure.md](_shared/06-on-failure.md) | Per-phase flow |
| §7 Execution Trace (CORE-026) | [_shared/07-execution-trace.md](_shared/07-execution-trace.md) | Dual-write pattern |
| §8 Phase Summary (CORE-028) | [_shared/08-phase-summary.md](_shared/08-phase-summary.md) | ≤15 dòng tiếng Việt |
| §9 Context & Checkpoint | [_shared/09-context-checkpoint.md](_shared/09-context-checkpoint.md) | CORE-038 helper |
| §10 Template Usage Rule | [_shared/10-template-usage.md](_shared/10-template-usage.md) | CORE-031 + strip pattern |
| §11 Task Planning | [_shared/11-task-planning.md](_shared/11-task-planning.md) | TodoWrite init |
| §12 CI Detection Pattern | [_shared/12-ci-detection.md](_shared/12-ci-detection.md) | Protocol 20 |
| §13 Lock/Heartbeat Pattern | [_shared/13-lock-heartbeat.md](_shared/13-lock-heartbeat.md) | Acquire/release pseudocode |
| §14 Bash Delegation Pattern | [_shared/14-bash-delegation.md](_shared/14-bash-delegation.md) | Python CLI invocation |
| §15 Agent Prompt Templates | [_shared/15-agent-prompts.md](_shared/15-agent-prompts.md) | Lane/Triage/Execute |
| §16 Sub-Probe Template | [_shared/16-sub-probe-template.md](_shared/16-sub-probe-template.md) | 8 CORE-037 sections |
| §17 Session Isolation Protocol | [_shared/17-session-isolation.md](_shared/17-session-isolation.md) | SESSION_ID format |
| §18 Playwright Integration | [_shared/18-playwright.md](_shared/18-playwright.md) | Lock-based serialization |
| §19 Bug Dashboard Update | [_shared/19-bug-dashboard.md](_shared/19-bug-dashboard.md) | 4-site canonical pattern |
| §20 CDG Token Persist | [_shared/20-cdg-tokens.md](_shared/20-cdg-tokens.md) | Anti-loop tracking |
| §21 Atomic-Call Wrapper | [_shared/21-atomic-call-wrapper.md](_shared/21-atomic-call-wrapper.md) | Meta documentation |

**Index canonical:** [_shared/README.md](_shared/README.md) — bảng load profile per-phase, slim notes, migration guide.

## Migration Note

Phase files chưa migrate sang reference path mới vẫn hoạt động nhờ file này. Khi sửa phase file, **update reference path** từ `_shared.md §NN` sang `_shared/NN-name.md` để bỏ qua file redirect này.
