# Phase 0: Context Loading

> Khởi tạo session, load registry + handoff context, detect LEGACY_MODE, tạo `define-features-status.json`.
> Entry point cho cả flow mới và `--resume`.

**PRE-GATE:**

```bash
test -f .mc-data/docs/_meta/req-registry.json         # E000 nếu FAIL
jq '.requirements | length' .mc-data/docs/_meta/req-registry.json  # > 0, E001 nếu FAIL
```

> **Forensic validation (Protocol 10.4):** `departments/**/*.md`: >= 4 headings, >= 300 words, chứa "REQ-". Nếu FAIL → "Department docs không đạt yêu cầu nội dung. Chạy `/wf-analyze-requirements` để hoàn thiện."

> **(CORE-026)** Append START entry vào `.mc-data/work/_trace/session-log.json` với `$SESSION_ID` (xem `_shared.md §Execution Trace Protocol`).

**INPUT:** Registry + `project-intent-digest.json` (nếu có) + `phase1-handoff.json` (nếu có) + `deferred-issues.md` (nếu có) + `stakeholder-review.md` (Phase 1, nếu có) + checkpoint (nếu `--resume`)

**OUTPUT:** `.mc-data/work/wf-define-features/define-features-status.json`

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.1  | Check `--status`, `--resume` flags | Args validated |
| 0.2  | `mkdir -p .mc-data/work/wf-define-features/sessions/` | `test -d .mc-data/work/wf-define-features` |
| 0.2b | **Session Isolation (ADR-OPT-02):** Tạo session dir `.mc-data/work/wf-define-features/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`. Set `$SESSION_DIR` và `$SESSION_ID`. Tạo `session-state.json` từ template `_shared/templates/session-state.json` (Template Usage Rule CORE-031). Tạo `latest` pointer: ghi `$SESSION_DIR` vào `.mc-data/work/wf-define-features/latest`. Cleanup: đếm sessions hiện có — nếu > 5 → xoá session cũ nhất. | `test -d $SESSION_DIR && test -s $SESSION_DIR/session-state.json` |
| 0.3  | Tạo `$SESSION_DIR/define-features-status.json` từ template `.claude/skills/workflow/wf-define-features/templates/define-features-status.json` (Template Usage Rule). Tạo symlink hoặc copy về root `.mc-data/work/wf-define-features/define-features-status.json` cho backward-compat. | `test -s $SESSION_DIR/define-features-status.json` |
| 0.4  | Đọc `req-registry.json` → `$REGISTRY_DATA`. Validate required fields (`requirements[]` non-empty) | Content loaded + structure valid |
| 0.5  | Detect `$LEGACY_MODE` (CORE-021): `test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes`. Nếu true → load `$LEGACY_CONTEXT` từ project-context.md | `$LEGACY_MODE` set |
| 0.5b | **(Protocol 6.6)** Kiểm tra Large Project Mode: `$LARGE_PROJECT = True` nếu `systems.length >= 5 OR departments.length >= 10 OR requirements.length >= 50 OR features.length >= 40`. Log kết quả. Nếu True → apply overrides: `compression_threshold=2`, `digest_size=300`, `max_parallel_agents=3`, `skeleton_threshold=2000`, checkpoint after EVERY phase. Ghi `flags.large_project = true/false` vào `define-features-status.json` | LPM flag set + logged |
| 0.5c | Nếu `$LEGACY_MODE = true` → đọc `.mc-data/work/wf-brainstorm/legacy-decisions.json` → `$LEGACY_DECISIONS`. Extract `$DEPRECATED_MODULES` = array module IDs có action=DEPRECATE. **GRACEFUL DEGRADATION (CORE-022):** Nếu file không tồn tại → LOG WARNING: "⚠️ legacy-decisions.json not found — user decisions từ wf-brainstorm chưa được propagate. Khuyến nghị chạy lại /wf-brainstorm Phase 0.5." Set `$DEPRECATED_MODULES = []`, tiếp tục không enforce scope exclusion | `$DEPRECATED_MODULES` loaded |
| 0.6  | Đọc `.mc-data/work/wf-analyze-requirements/deferred-issues.md` (nếu tồn tại) | Deferred issues loaded (hoặc empty) |
| 0.6b | Đọc `.mc-data/docs/phase1-business/stakeholder-review.md` (nếu tồn tại) — context từ /wf-analyze-requirements | Stakeholder review loaded (hoặc empty) |
| 0.6c | Đọc `.mc-data/work/wf-brainstorm/project-intent-digest.json` (nếu tồn tại) — handoff gọn từ /wf-brainstorm | Project intent loaded (hoặc empty) |
| 0.6d | Đọc `.mc-data/work/wf-analyze-requirements/phase1-handoff.json` (nếu tồn tại) — handoff chốt từ /wf-analyze-requirements | Phase 1 handoff loaded (hoặc empty) |
| 0.7  | Nếu `--resume`: load `checkpoint.json` | Checkpoint loaded |
| 0.7b | **(RESUME RECONCILIATION — chỉ khi `--resume`)** Xem `_shared.md §Resume Reconciliation` để đếm file thực tế và cập nhật `features_completed` + `current_batch` | Checkpoint đã reconcile |

## Argument Handling

### `--status` handler

```
# Ưu tiên: đọc từ latest session
IF test -f .mc-data/work/wf-define-features/latest:
  SESSION_DIR = cat .mc-data/work/wf-define-features/latest
  IF test -f $SESSION_DIR/session-state.json:
    state = đọc $SESSION_DIR/session-state.json
    actual_files=$(find .mc-data/docs/phase2-features/ -name "*.md" ! -name "stakeholder-review.md" | wc -l)
    → Hiển thị trạng thái từ session-state.json (phases[], next_action, session_id):
      - "Session: $SESSION_ID"
      - "Files trên disk: [actual_files] / [total_features]"
      - Nếu actual_files != features_completed → "(checkpoint chưa đồng bộ — chạy --resume để cập nhật)"
    → STOP

# Fallback: backward-compat
ELIF test -f .mc-data/work/wf-define-features/checkpoint.json:
  checkpoint = đọc checkpoint.json
  actual_files=$(find .mc-data/docs/phase2-features/ -name "*.md" ! -name "stakeholder-review.md" | wc -l)
  → Hiển thị trạng thái từ checkpoint.json → STOP
ELIF test -f .mc-data/work/wf-define-features/define-features-status.json:
  → Hiển thị trạng thái từ define-features-status.json → STOP
ELSE:
  → "Chưa có define-features session nào." → STOP
```

### `--resume` handler

```
# Ưu tiên: đọc từ session-state.json (latest session)
IF test -f .mc-data/work/wf-define-features/latest:
  SESSION_DIR = cat .mc-data/work/wf-define-features/latest
  IF test -f $SESSION_DIR/session-state.json:
    state = đọc $SESSION_DIR/session-state.json
    next_action = state.next_action
    → Khôi phục $SESSION_DIR, $SESSION_ID
    → LEGACY_MODE tự detect từ project-context.md (CORE-021)
    → Jump tới phase = next_action
    STOP

# Fallback: backward-compat với checkpoint.json cũ
ELIF test -f .mc-data/work/wf-define-features/checkpoint.json:
  checkpoint = đọc checkpoint.json
  → Tiếp tục Phase 0 (LEGACY_MODE tự detect từ project-context.md — CORE-021)
  → Sau đó jump tới phase được ghi trong checkpoint.position.current_phase

ELSE:
  → STOP: "Không tìm thấy checkpoint. Chạy `/wf-define-features` từ đầu."
```

**POST-GATE:**

```bash
test -f .mc-data/work/wf-define-features/define-features-status.json
test -n "$REGISTRY_DATA"
jq '.requirements | length' .mc-data/docs/_meta/req-registry.json  # > 0
```

> Nếu `requirements[]` rỗng → STOP với thông báo: "Chưa có requirements. Chạy `/wf-analyze-requirements` trước." (E001)

> **(Protocol 6.6 — LPM-05)** Nếu `$LARGE_PROJECT = true`: **SAVE CHECKPOINT** (dùng template `templates/checkpoint.json`) sau Phase 0. Ở Standard mode, checkpoint Phase 0 là optional.

**Status update:** `$SESSION_DIR/session-state.json` → `phases.P0.status = "completed"`, `completed_at = <ISO timestamp>`, `flags.legacy_mode`, `flags.large_project`. Cũng update `$SESSION_DIR/define-features-status.json` `phase_0.status`.

### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| Retryable error (E003, E004, E006) | Retry ≤ 3 lần, ghi error_log |
| Max retry reached | STOP + báo cáo findings → user quyết định |
| Non-retryable (E000, E001) | STOP ngay + hướng dẫn user |

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id, status, items_processed, key_findings, next_action
3. WRITE: `$SESSION_DIR/phase-summary.md`

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json` với `$SESSION_ID`.

**Next phase:** `phase0.5-workload-gate.md` (mọi mode)
