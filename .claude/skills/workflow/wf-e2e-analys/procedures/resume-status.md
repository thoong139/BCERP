# Resume + Status Handlers (F1 wf-e2e-analys)

**Áp dụng:** Khi F1 nhận `--resume` hoặc `--status` flag.

---

## 1. `--status` Handler (read-only, KHÔNG execute phase)

**Mục tiêu:** Đọc state file, hiển thị dashboard tiến độ + dừng ngay (không advance phase).

### Bước 1: Resolve session

```
IF --session=<id> → SESSION_DIR = .mc-data/work/wf-e2e-verify/sessions/<id>/
ELSE IF --resume + <FEAT-ID> → tìm latest session matching FEAT-ID:
    Glob .mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-* → sort theo mtime DESC → lấy mới nhất
ELSE → E001 "Thiếu --session hoặc --resume + <FEAT-ID>"
```

### Bước 2: Read state files

- `$SESSION_DIR/status.json` (F1 own state)
- `$SESSION_DIR/e2e-status.json` (orchestrator state nếu có)
- `$SESSION_DIR/issues.json`, `block-test.json`, `implement-required.json`, `manual.json` (summary)

### Bước 3: Display dashboard

```
================================================================
F1 wf-e2e-analys — Status Dashboard
Session: {SESSION_DIR}
FEAT-ID: {feat_id}
Created: {created_at}
Last updated: {last_updated}
================================================================

Phase Progress:
| Phase | Name           | Status      | sub_state | Duration |
|-------|----------------|-------------|-----------|----------|
| P0    | SETUP          | completed   | DONE      | 2m       |
| P1    | BUSINESS       | completed   | DONE      | 8m       |
| P2    | DB             | completed   | DONE      | 12m      |
| P3    | API            | in_progress | LIVE-TEST | 5m       |
| P4    | UI             | pending     | -         | -        |
| P5    | INTEGRATION    | pending     | -         | -        |
| P6    | OUTPUT         | pending     | -         | -        |

SSOT Counters:
- issues.json: {open=X, fixed=Y, total=Z}
- block-test.json: {blocked=X, resolved=Y, unblocked=Z}
- implement-required.json: {pending=X, done=Y, skipped=Z}
- manual.json: {pending=X, verified=Y}

Context Estimate: {context_estimate_pct}%
Bo Sung Count: {bo_sung_count}
Verify Attempts: {verify_attempts}

Next action: continue Phase {current_phase} sub_state={sub_state}
================================================================
```

### Bước 4: STOP

KHÔNG advance phase. Exit gracefully sau khi display.

---

## 2. `--resume` Handler

**Mục tiêu:** Tiếp tục pipeline F1 từ checkpoint hiện tại.

### Bước 1: Resolve session (giống --status)

### Bước 2: Acquire lock

```
$LOCK = $SESSION_DIR/.lock
IF $LOCK exists:
    IF lock_age > 30 min → auto-release (stale lock E008)
    ELSE → E007 "Session đang chạy bởi process khác"
ELSE → Acquire (write PID + ISO timestamp vào .lock)
```

### Bước 3: Read state

```
status = jq '.' $SESSION_DIR/status.json
current_phase = status.current_phase  // 0-6
sub_state = status.sub_state  // FIND|ASSESS|BO_SUNG|TEST|VERIFY|DONE
```

### Bước 4: PRE-GATE T1-T4 re-validate output phase trước

```
IF current_phase > 0:
    Validate output phase N-1 tồn tại + schema valid + content depth pass
    IF fail → E0X1 "Output phase N-1 corrupted, không resume được"
```

### Bước 5: Route theo current_phase + sub_state

```
SWITCH current_phase:
    CASE 0: GOTO procedures/phase0-setup.md (re-run nếu sub_state != DONE)
    CASE 1: GOTO procedures/phase1-business.md sub_state={sub_state}
    CASE 2: GOTO procedures/phase2-db.md sub_state={sub_state}
    CASE 3: GOTO procedures/phase3-api.md sub_state={sub_state}
    CASE 4: GOTO procedures/phase4-ui.md sub_state={sub_state}
    CASE 5: GOTO procedures/phase5-integration.md sub_state={sub_state}
    CASE 6: GOTO procedures/phase6-output.md sub_state={sub_state}
    CASE 7+: F1 hoàn tất → return success → orchestrator sẽ spawn F2
```

### Bước 6: Context budget check (CORE-038)

```
IF context_estimate_pct > 80% → DỪNG ngay sau phase hiện tại, hướng dẫn user /clear + --resume tiếp
IF context_estimate_pct > 90% → FORCE STOP (E009), KHÔNG advance
```

---

## 3. Idempotency Rules

- **--resume KHÔNG xóa data cũ**. Đọc `findings/`, `outputs/`, `issues.json`, ... và tiếp tục từ điểm dừng.
- **Phase đã DONE → skip**. Chỉ re-run nếu sub_state ≠ DONE.
- **BỔ SUNG count + verify_attempts không reset**. Giữ counter để biết đã iterate bao nhiêu lần.
- **Atomic write pattern (CORE-035) đảm bảo state không corrupt khi user crash giữa write**.

---

## 4. Error Codes (cho resume-status)

| Code | Mô tả |
|------|-------|
| E001 | Thiếu --session hoặc --resume + <FEAT-ID> |
| E007 | Lock đang active (process khác đang chạy) |
| E008 | Stale lock (>30 min) — auto-released, retry |
| E009 | Context budget > 90% — FORCE STOP |
| E0X1 | Output phase N-1 corrupted (X = phase number) |

---

## 5. Standalone Invocation Note

F1 wf-e2e-analys cho phép standalone:

- Nếu user gọi `/wf-e2e-analys <FEAT-ID>` mà KHÔNG có `--session` → tạo session MỚI tại `.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/`
- Nếu user gọi `/wf-e2e-analys <FEAT-ID> --session=<id>` → reuse session đã có (vd: từ orchestrator)
- Nếu user gọi `/wf-e2e-analys <FEAT-ID> --resume` → tìm latest session của FEAT-ID, tiếp tục

Khác với F2-F8 (require `--session` từ orchestrator/F1). F1 là entry point độc lập.
