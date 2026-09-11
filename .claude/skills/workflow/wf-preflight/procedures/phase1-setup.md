# Phase 1: Setup & Scope Resolution

> **Protocol:** Xem `.claude/skills/protocols/`
> **Shared:** Xem `procedures/_shared.md` — State Variables, Scope Resolution, Checkpoint, Error Handling
> **Session Lifecycle:** Xem `procedures/session-init.md` — SI.1-SI.9 chạy TRƯỚC phase này

**Prerequisites:** Session đã được init qua `session-init.md`. `$SESSION_ID`, `$SESSION_DIR`, `$SCOPE_TYPE` đã set.

---

## PRE-GATE

Đã xử lý trong `session-init.md` SI.1 (forensic validation) và SI.7 (session dir created).

**Verify inherited state:**
```
test -n "$SESSION_ID"
test -n "$SESSION_DIR"
test -f "$SESSION_DIR/preflight-status.json"
```

**Working Directory:** Phải chạy từ project root (có `.mc-data/`). Đã check ở SI.1.

## 📥 INPUT

| File | Đường dẫn |
|------|-----------|
| Registry | `.mc-data/docs/_meta/req-registry.json` |
| Session status | `$SESSION_DIR/preflight-status.json` |
| Checkpoint (nếu resume) | `$SESSION_DIR/checkpoint.json` |

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 1.1 | Flags đã parse trong session-init.md SI.1. Confirm: `$SCOPE_TYPE`, `$SCOPE_NAME`, `$HAS_FIX_FLAG`, `$HAS_RUN_TESTS_FLAG` set | Flags inherited |
| 1.2 | Nếu `--resume`: RESTORE in-memory state từ `$SESSION_DIR/checkpoint.json` (xem §State Restore on Resume). Nếu không: state đã được khởi tạo ở SI.7 | State ready |
| 1.3 | Load registry → resolve scope targets (xem `_shared.md` §Scope Resolution Logic) → set `$TARGET_SYSTEMS`, `$TARGET_MODULES`, `$TARGET_FEATURES`, `$TARGET_REQS` | Scope IDs resolved |
| 1.4 | Đọc `registry.interface_type` → set `$INTERFACE_TYPE` (`ui` / `api-only` / `hybrid`). Default `ui` nếu field absent. | `$INTERFACE_TYPE` set |
| 1.5 | Detect tech stack: check `package.json`, `tsconfig.json`, `go.mod`, `requirements.txt`, `.eslintrc*`, `eslint.config.*` → set `$TECH_STACK` | Stack detected |
| 1.6 | Log: "✓ Preflight started — session: [$SESSION_ID], scope: [all / system=X / module=Y / feature=Z], interface_type: [$INTERFACE_TYPE]" | — |
| 1.7 | **Execution Trace (CORE-026):** APPEND START entry vào `.mc-data/work/_trace/session-log.json`: `{"skill":"wf-preflight","event":"START","timestamp":"[ISO]","session_id":"$SESSION_ID","scope":"[scope_type/scope_name]","flags":"[fix/run_tests]"}`. Nếu file chưa tồn tại → tạo mới với JSON array wrapper. | File exists + valid JSON |

---

## State Restore on Resume

Khi `--resume` flag được dùng, PHẢI rebuild in-memory state từ checkpoint trước khi tiếp tục:

```
1. Đọc $SESSION_DIR/checkpoint.json
2. Restore $SCORES:
     $SCORES.registry_score = checkpoint.partial_state.scores_snapshot.registry_score
     $SCORES.docs_score     = checkpoint.partial_state.scores_snapshot.docs_score
     $SCORES.sync_score     = checkpoint.partial_state.scores_snapshot.sync_score
     $SCORES.quality_score  = checkpoint.partial_state.scores_snapshot.quality_score
     $SCORES.test_score     = checkpoint.partial_state.scores_snapshot.test_score

3. Restore issues arrays:
     $REGISTRY_ISSUES = checkpoint.partial_state.issues_snapshot.registry_issues ([] nếu null)
     $DOC_ISSUES      = checkpoint.partial_state.issues_snapshot.doc_issues ([] nếu null)
     $SYNC_ISSUES     = checkpoint.partial_state.issues_snapshot.sync_issues ([] nếu null)
     $QUALITY_ISSUES  = checkpoint.partial_state.issues_snapshot.quality_issues ([] nếu null)

4. Restore context flags từ context_summary:
     $SCOPE_TYPE         = checkpoint.context_summary.scope_type
     $SCOPE_NAME         = checkpoint.context_summary.scope_name
     $HAS_FIX_FLAG       = checkpoint.context_summary.fix_flag
     $HAS_RUN_TESTS_FLAG = checkpoint.context_summary.run_tests_flag
     $INTERFACE_TYPE     = checkpoint.context_summary.interface_type (default "ui" nếu null)

5. Re-resolve $TARGET_* từ registry mới nhất (đọc lại req-registry.json) —
   KHÔNG dùng cached targets vì registry có thể thay đổi giữa sessions

6. Đọc checkpoint.position.next_action → bắt đầu từ phase tương ứng
```

> **Lưu ý:** Nếu checkpoint.partial_state.issues_snapshot null (session cũ chưa có field quality_issues) → khởi tạo `$QUALITY_ISSUES = []` và tiếp tục — không STOP.

---

## Scope Resolution

> Xem `procedures/_shared.md` §Scope Resolution Logic để đọc pseudocode chi tiết.

**Tóm tắt:**
- `--scope=all` → toàn bộ systems/modules/features/reqs
- `--scope=system --name=SYS-X` → chỉ SYS-X và modules/features/reqs thuộc system đó
- `--scope=module --name=MOD-X` → chỉ MOD-X và features/reqs thuộc module đó
- `--scope=feature --name=FEAT-X` → chỉ FEAT-X và req_ids của feature đó

**Validation bắt buộc:** Nếu `--name` không tồn tại trong registry hoặc scope hẹp thiếu `--name` → STOP (E003/E004). Xem `_shared.md` §Error Handling Matrix.

---

## POST-GATE

```
test -f ".mc-data/docs/_meta/req-registry.json"
test -f "$SESSION_DIR/preflight-status.json"
```

Status file `$SESSION_DIR/preflight-status.json` phải có:
- `session_id` = `$SESSION_ID`
- `scope.type` và `scope.name` set đúng theo arguments
- `flags.fix` và `flags.run_tests` set đúng
- `phases.phase_1.status = "completed"`
- `timestamps.started_at` set

Biến in-memory phải set:
- `$INTERFACE_TYPE` ∈ {"ui", "api-only", "hybrid"} (không được null)

---

## Output → Next Phase

- `$SCOPE_TYPE`, `$SCOPE_NAME`, `$HAS_FIX_FLAG`, `$HAS_RUN_TESTS_FLAG` — global state
- `$INTERFACE_TYPE` — dùng cho Phase 3 step 3.5
- `$TARGET_SYSTEMS`, `$TARGET_MODULES`, `$TARGET_FEATURES`, `$TARGET_REQS` — global state
- `$TECH_STACK` — dùng cho Phase 5/5a
- `$SESSION_DIR/preflight-status.json` — session tracking

**Next:** Parallel Group A = Phase 2 (Registry) + Phase 3 (Docs). Chạy ĐỒNG THỜI.
