# 09 — Session & Checkpoint (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC (CORE-026, CORE-030, CORE-035, CORE-038)
> **File gốc canonical:** [`.claude/skills/protocols/18-session-isolation.md`](../../.claude/skills/protocols/18-session-isolation.md), [`.claude/skills/protocols/03-context-checkpoint.md`](../../.claude/skills/protocols/03-context-checkpoint.md)
> **Mục đích:** Định nghĩa cấu trúc session, checkpoint, resume cho skill multi-phase + context budget management

---

## 1. Triết lý — tại sao cần session?

Skills MCV3 thường:
- Chạy 30-90 phút, vượt 1 session Claude (~3-4 giờ context budget)
- Có thể bị interrupt (user dừng, crash, context overflow)
- User muốn chạy lại cùng skill với scope/profile khác → cần isolate
- Multi-developer: 2 user chạy cùng skill cùng project → không được race condition

Session isolation chốt: **mỗi lần chạy skill = 1 session directory riêng biệt** với checkpoint + lock + heartbeat.

---

## 2. Session ID format (CORE-035)

```
SESSION_ID = YYYY-MM-DD-{scope}-{slug}-{NN}
```

| Component | Mô tả | Ví dụ |
|-----------|-------|-------|
| `YYYY-MM-DD` | Ngày tạo (local TZ) | `2026-05-15` |
| `{scope}` | Scope mode | `all`, `system`, `module`, `feature` |
| `{slug}` | Target slug (kebab) | `crm`, `customer-mgmt` |
| `{NN}` | Sequence 2 digits | `01`, `02`, `15` |

**Ví dụ:**
- `2026-05-15-all-mcv3-01` (full scope, lần 1 trong ngày)
- `2026-05-15-module-customer-mgmt-03` (module scan, lần 3)
- `2026-05-15-feature-feat-crm-cust-001-01`

**Quy tắc:**
- Lowercase-kebab-case (CORE-016)
- Date dùng local TZ — phải nhất quán trong cùng skill
- NN auto-increment trong cùng (date + scope + slug)

**Lưu ý:** Một số skill cũ (vd: wf-manage-change) dùng format đơn giản hơn `YYYY-MM-DD-{scope-label}` — đang migrate sang format chuẩn.

---

## 3. Session directory structure (CORE-035)

```
.mc-data/work/{skill}/
├── _index/
│   └── sessions.jsonl                # APPEND-only — mỗi session 1 entry
├── _shared/                          # (optional) Cross-session aggregate
│   ├── history.json
│   └── latest-summary.md
├── sessions/
│   ├── {SESSION_ID}/                 # MỖI SESSION ISOLATED
│   │   ├── .lock                     # Session lock + heartbeat daemon
│   │   ├── fix-status.json           # SSOT pipeline state (Atomic Write)
│   │   ├── session-log.json          # CORE-026 trace (APPEND-only)
│   │   ├── error-ledger.json         # CORE-034 errors (APPEND-only)
│   │   ├── checkpoint.json           # Resume data (digest + state)
│   │   ├── phase1-init/              # Phase subdirectory
│   │   │   ├── Phase1-report.md      # CORE-028 tiếng Việt ≤15 dòng
│   │   │   └── [output files]
│   │   ├── phase2-{name}/
│   │   │   └── ...
│   │   └── phase-summary.md          # Accumulated từ Phase reports
│   ├── {SESSION_ID_2}/
│   │   └── ...
│   └── current.txt                   # (optional) pointer tới session active
└── [legacy flat files đang migrate sang sessions/]
```

### 3.1. SSOT pipeline state — `fix-status.json` (hoặc tương đương)

Mỗi skill có 1 file SSOT state — vd:
- `wf-fix-bugs`: `fix-status.json`
- `wf-legacy-scan`: `scan-state.json`
- `wf-implement-feature`: `impl-status.json`
- `wf-preflight`: `preflight-status.json`

**Pattern chung:**
```json
{
  "$schema": "fix-status-v1",
  "session_id": "2026-05-15-all-mcv3-01",
  "skill": "wf-fix-bugs",
  "version": "10.2.1",
  "created_at": "2026-05-15T14:32:00+07:00",
  "phases": {
    "phase1": {"status": "completed", "started_at": "...", "completed_at": "..."},
    "phase2": {"status": "completed", "..."},
    "phase3": {"status": "in_progress", "..."},
    "phase4": {"status": "pending"}
  },
  "current_phase": "phase3",
  "next_action": "Continue phase3-plan step 3.2"
}
```

### 3.2. APPEND-only files (CORE-026)

3 file APPEND-only mọi skill PHẢI có:

| File | Định dạng | Nội dung |
|------|-----------|---------|
| `session-log.json` | JSONL (1 entry/line) | START / COMPLETE / FAIL events cho mỗi step |
| `error-ledger.json` | JSONL | Error events (CORE-034) |
| `_index/sessions.jsonl` | JSONL | 1 entry/session khi tạo hoặc cập nhật status |

**Quy tắc CORE-026:**
- KHÔNG đọc lại làm input context — output-only
- KHÔNG xóa entries cũ — append forever (cleanup là task riêng, ngoài runtime)
- Mỗi entry có `timestamp` ISO-8601

---

## 4. Lock & Heartbeat (CORE-030)

### 4.1. Vì sao cần lock?

Multi-user/multi-process có thể chạy cùng skill cùng project. Lock đảm bảo:
- Chỉ 1 process active tại một thời điểm
- Process khác phát hiện được session đang running → graceful wait hoặc fail fast

### 4.2. Lock structure

```
$SESSION_DIR/.lock
```

File `.lock` chứa:
```json
{
  "pid": 12345,
  "started_at": "2026-05-15T14:32:00+07:00",
  "last_heartbeat": "2026-05-15T14:35:00+07:00",
  "hostname": "dev-machine-01"
}
```

### 4.3. Heartbeat daemon

```
- Process chính spawn heartbeat daemon (background)
- Mỗi 30s, daemon update last_heartbeat trong .lock
- Khi process chính exit → cleanup trap xóa .lock
```

### 4.4. Stale lock handling

```
Khi acquire lock:
  IF .lock tồn tại:
    age = now - last_heartbeat
    IF age > 30 phút:
      → E008: Stale lock detected → auto-release, WARN, continue
    ELSE:
      → STOP: "Session đang running tại PID {pid}. Chờ kết thúc hoặc kill PID."
```

### 4.5. Cross-session R/W lock (Protocol 22)

E2E skills + parallel-safe skills dùng global R/W lock:
- `.mc-data/work/_locks/{resource}.lock` — read/write coordination
- Multi-session đọc cùng resource → OK (read lock)
- Multi-session ghi cùng resource → block (write lock)
- Chi tiết: [Protocol 22](../../.claude/skills/protocols/22-infrastructure-rw-lock.md)

---

## 5. Context Budget (CORE-038)

```
CONTEXT BUDGET TIERS:
  < 65%    → Tiếp tục bình thường
  65-80%   → Chuẩn bị checkpoint (lưu state files)
  80-90%   → Lưu checkpoint, STOP sau phase hiện tại → hướng dẫn --resume
  > 90%    → FORCE STOP (E009) — checkpoint bắt buộc, không advance
```

### 5.1. Implementation pattern

```bash
# Sau mỗi step lớn, check context budget
context_pct=$(estimate_context_usage)

if [ "$context_pct" -gt 90 ]; then
  # FORCE STOP — không cố gắng làm tiếp
  echo "E009: Context > 90%. FORCE STOP. Dùng --resume để tiếp tục."
  save_checkpoint
  exit 9
elif [ "$context_pct" -gt 80 ]; then
  # Hoàn thành phase hiện tại rồi STOP
  echo "WARN: Context 80-90%. Sẽ STOP sau phase hiện tại."
  flag_stop_after_phase=1
elif [ "$context_pct" -gt 65 ]; then
  # Chuẩn bị checkpoint — lưu state nhưng không stop
  save_checkpoint_minimal
fi
```

### 5.2. Checkpoint files tối thiểu

Khi context > 65%, BẮT BUỘC lưu:
- `fix-status.json` (hoặc state file tương đương) — phase + next_action
- `session-log.json` — trace đến thời điểm hiện tại
- Current `Phase{N}-report.md` — báo cáo phase đang dở (status: in_progress)
- `checkpoint.json` (nếu skill dùng digest)

---

## 6. Checkpoint với Context Digest (Protocol 3)

### 6.1. Triết lý — tại sao cần digest?

Khi `--resume`, skill phải đọc lại state. Nếu chỉ có raw state file:
- Đọc 5-10 file để hiểu context → tốn context budget mới
- Mất 10 phút mới hiểu xong session trước làm gì

**Digest** = tóm tắt cô đọng kiến trúc + decisions + interfaces + warnings. Khi resume, inject digest TRƯỚC khi đọc raw files → giảm 50% context.

### 6.2. Checkpoint schema

```json
{
  "checkpoint_id": "CP-20260515-003",
  "phase": "phase_3",
  "batch": 2,
  "next_action": "implement_service_layer",

  "context_digest": {
    "feature_summary": "Quản lý khách hàng với soft-delete và audit trail",
    "architectural_decisions": [
      {
        "decision": "Dùng TypeORM Repository pattern",
        "reason": "Project đã có TypeORM setup",
        "affects": ["entity", "repository", "service"]
      }
    ],
    "interfaces_established": {
      "ICustomerRepository": {
        "file": "src/repositories/customer.repository.interface.ts",
        "key_methods": ["findById", "findByEmail", "softDelete"],
        "notes": "Tất cả query PHẢI filter deletedAt IS NULL"
      }
    },
    "patterns_in_use": {
      "error_handling": "throw AppError(code, httpStatus)",
      "naming": "camelCase variables, PascalCase classes"
    },
    "cross_batch_contracts": {
      "batch_1_exports": ["CustomerEntity"],
      "batch_2_imports": ["Cần CustomerEntity type"]
    },
    "gotchas_and_warnings": [
      "Email UNIQUE constraint — check duplicate",
      "deletedAt nullable Date, không phải boolean"
    ]
  }
}
```

### 6.3. Fields trong digest

| Field | Bắt buộc | Mô tả |
|-------|---------|-------|
| `feature_summary` | ✅ | 100-200 từ — feature đang làm gì |
| `architectural_decisions[]` | ≥1 | Các quyết định đã chốt + lý do |
| `interfaces_established{}` | Nếu có | Interface/contract đã định nghĩa |
| `patterns_in_use{}` | ≥1 | Pattern coding (naming, error handling) |
| `cross_batch_contracts{}` | Nếu có batch sau | Exports/imports giữa batches |
| `gotchas_and_warnings[]` | ≥1 | Cảnh báo cần nhớ (UNIQUE constraint, edge cases) |

---

## 7. Resume flow (CORE-038)

```
KHI USER CHẠY: /wf-{skill} --resume

  1. SCAN sessions/ → tìm session với status = in_progress OR paused
     → Nếu có nhiều: ưu tiên session mới nhất hoặc dùng --session=ID
     → Nếu không có: STOP, "Không có session nào để resume"

  2. READ fix-status.json
     → Xác định last completed phase
     → Xác định next_action

  3. STALE CHECK:
     → IF lock age > 30 phút: auto-release (E008)
     → ELSE: STOP, "Session đang chạy ở PID {pid}"

  4. ACQUIRE LOCK + start heartbeat daemon

  5. READ checkpoint.json:
     → Extract context_digest
     → INJECT digest vào prompt chính (đầu phase tiếp theo)

  6. RE-VALIDATE PRE-GATE phase tiếp theo
     → File upstream còn nguyên không?
     → Schema khớp không?

  7. ROUTE đến next_action:
     → Continue phase đang dở (resume mid-phase)
     → Hoặc bắt đầu phase tiếp theo
```

### 7.1. Resume strategies (CORE-038)

Một số skill có `--resume-strategy`:

| Strategy | Hành vi |
|---------|---------|
| `prompt` (default) | Khi gặp session DONE/FAILED → AskUser |
| `auto` | DONE → cancel, FAILED → resume từ phase failed, in_progress → continue |
| `force-fresh` | Luôn tạo session mới, bỏ qua session cũ |

---

## 8. `--status` flag

Mọi multi-phase skill nên có `--status`:

```
/wf-{skill} --status
```

Output (read-only, không sửa state):
- Latest session ID
- Phase table với trạng thái (completed/in_progress/pending/failed)
- Time spent per phase
- Next action suggestion
- Lock status (active/stale/released)

---

## 9. Skills KHÔNG cần session isolation (Protocol 18.6)

Không phải mọi skill cần session structure. Skills sau dùng pattern khác:

| Skill | Lý do |
|-------|-------|
| `wf-implement-feature` | Đã có per-feature subdirs (`$FEATURE_SLUG/sessions/{id}/`) |
| `wf-add-scope` | Idempotent — re-run an toàn |
| `wf-plan-modules` | SKIP-IF-EXISTS cho task files |
| `wf-legacy-scan/classify/extract` | Pipeline state machine, dùng `scan-state.json` |
| `wf-annotate-code` | Annotation check prevent duplicate |
| `wf-prepare-deployment` | Skip files đã tồn tại |
| `wf-brainstorm` | Entry point, chạy 1 lần |
| `new-project`, `existing-project` | Orchestrator workflows |

---

## 10. Ví dụ Pass/Fail

### ✅ PASS — Full session flow

```
Run 1: /wf-fix-bugs --scope=module --name=customer-mgmt --profile=deep
  → SESSION_ID = "2026-05-15-module-customer-mgmt-01"
  → mkdir sessions/2026-05-15-module-customer-mgmt-01/
  → Acquire .lock, start heartbeat
  → Run Phase 1, 2, 3, 4 (context 60%)
  → POST-GATE Phase 4 PASS
  → Phase 5 starting (context 78%)
  → CHECKPOINT triggered: save state, digest "12 issues found, classify per dimension QD1-QD11"
  → Phase 5 STOP, write Phase report "PARTIAL"
  → Exit cleanly

Run 2: /wf-fix-bugs --resume
  → Find sessions/2026-05-15-module-customer-mgmt-01/ (status = in_progress)
  → Stale check: lock age 5 min → OK, acquire
  → Read checkpoint.json → inject digest
  → Re-validate Phase 4 outputs → OK
  → Continue Phase 5 from step 5.3
  → Run Phase 5, 6, 7 → COMPLETED
  → Update _index/sessions.jsonl, write final summary
```

### ❌ FAIL — Skip session isolation

```
Run 1: skill ghi đè `.mc-data/work/wf-bad-skill/state.json`
Run 2: skill khác chạy song song → cùng ghi `state.json`
  → Race condition: state corrupted
  → User --resume: state.json đã bị overwrite, không thể recover

Vi phạm:
  - CORE-030: không session isolation
  - CORE-035: không session subdirectory
  - CORE-026: không có session-log → không trace được lỗi
```

---

## 11. Anti-patterns — KHÔNG được làm

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Ghi đè `state.json` mỗi run | Mỗi run = 1 session directory mới |
| Lock không có heartbeat → stale forever | Heartbeat daemon update mỗi 30s |
| Không stale check → process crashed → lock kẹt | Stale check: age > 30 min → auto-release |
| Resume không inject digest → đọc lại 10 files | Inject digest từ checkpoint trước khi đọc raw |
| Đọc `session-log.json` làm input context | session-log OUTPUT-ONLY (CORE-026) |
| Context > 90% vẫn cố advance phase | FORCE STOP, E009, checkpoint bắt buộc |
| Session ID có UPPERCASE hoặc dấu cách | Lowercase-kebab-case |
| Không có `--status` flag | Mọi multi-phase skill PHẢI có `--status` |
| Migration session cũ → mới mà không atomic | Atomic: tạo new → copy → confirm → delete old |
| 2 user chạy cùng skill cùng project → race | Lock + heartbeat đảm bảo 1 process active |

---

## 12. Checklist khi skill có multi-phase

- [ ] SESSION_ID format chuẩn: `YYYY-MM-DD-{scope}-{slug}-{NN}`
- [ ] Session directory tại `.mc-data/work/{skill}/sessions/{id}/`
- [ ] `_index/sessions.jsonl` APPEND-only
- [ ] `.lock` + heartbeat daemon implementation
- [ ] Stale lock check (>30 min → auto-release E008)
- [ ] `fix-status.json` (hoặc state file) Atomic Write
- [ ] `session-log.json` APPEND-only (CORE-026)
- [ ] `error-ledger.json` APPEND-only (CORE-034)
- [ ] Phase subdirectories `phase{N}-{name}/` (CORE-035)
- [ ] `Phase{N}-report.md` tiếng Việt ≤15 dòng (CORE-028)
- [ ] Context budget check 65/80/90% (CORE-038)
- [ ] `--resume` handler với digest injection
- [ ] `--status` flag display
- [ ] `--session=ID` flag (optional, chọn session cụ thể)

---

## 13. Compliance audit

Script `./.claude/scripts/skill-compliance-audit.sh {skill}` kiểm tra:

- ✅ Có `sessions/` directory pattern trong `_contract.json` outputs
- ✅ Có `_index/sessions.jsonl` registered
- ✅ Có `.lock` mechanism
- ✅ `--resume` và `--status` flags trong inputs

---

## 14. Liên kết

- **Protocol 18 (Session Isolation):** [`.claude/skills/protocols/18-session-isolation.md`](../../.claude/skills/protocols/18-session-isolation.md)
- **Protocol 3 (Context & Checkpoint):** [`.claude/skills/protocols/03-context-checkpoint.md`](../../.claude/skills/protocols/03-context-checkpoint.md)
- **Protocol 15 (Execution Trace):** [`.claude/skills/protocols/15-execution-trace.md`](../../.claude/skills/protocols/15-execution-trace.md)
- **Protocol 22 (R/W Lock):** [`.claude/skills/protocols/22-infrastructure-rw-lock.md`](../../.claude/skills/protocols/22-infrastructure-rw-lock.md)
- **CORE rules:** CORE-026, CORE-030, CORE-035, CORE-038
- **Related standards:**
  - [`05-quality-gates.md`](05-quality-gates.md) — Phase gates
  - [`07-naming-conventions.md`](07-naming-conventions.md) — SESSION_ID format
  - [`08-error-code-registry.md`](08-error-code-registry.md) — E008, E009
- **Pattern:** [`../03-design-patterns/06-checkpoint-resume.md`](../03-design-patterns/06-checkpoint-resume.md)
