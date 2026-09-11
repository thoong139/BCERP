# 06 — Checkpoint + Resume

> **Mức độ ràng buộc:** BẮT BUỘC cho skill multi-session hoặc xử lý dữ liệu lớn
> **Rule liên quan:** CORE-038
> **Khi nào dùng:** Skill có thể bị interrupt (context limit, user dừng, lỗi tạm thời), cần `--resume`

---

## 1. Vấn đề pattern giải quyết

Skill MCV3 lớn (vd: wf-fix-bugs, wf-legacy-scan) có thể chạy 30-120 phút. Trong khoảng đó:
- User có thể đóng terminal → context loss
- Context window approach 100% → must stop
- Lỗi tạm thời (network, lock) → skill abort

**Anti-pattern:** Bắt user chạy lại từ đầu → mất 30-120 phút công sức.

**Pattern giải quyết:** Skill **lưu state** tại checkpoint thresholds → user có thể `--resume` từ điểm dừng.

---

## 2. Pattern definition

### 2.1. Context budget tiers (CORE-038)

```
< 65%   → Tiếp tục bình thường
65-80%  → Chuẩn bị checkpoint (lưu state files)
80-90%  → Lưu checkpoint, STOP sau phase hiện tại
        → Hướng dẫn user --resume
> 90%   → FORCE STOP (E009)
        → Checkpoint bắt buộc, không advance
```

### 2.2. Checkpoint files tối thiểu

Mỗi skill checkpoint phải có:

| File | Mục đích |
|------|----------|
| `fix-status.json` (hoặc state file tương đương) | Phase hiện tại + next_action |
| `session-log.json` (APPEND-only) | Execution trace đến thời điểm checkpoint |
| Current `Phase{N}-report.md` | Báo cáo phase đang dở |
| `.lock` | Lock file với heartbeat |

### 2.3. State file structure (vd: fix-status.json)

```json
{
  "$schema": "fix-status-v1",
  "session_id": "2026-05-15-crm-payment-01",
  "skill": "wf-fix-bugs",
  "version": "10.2.1",
  "started_at": "2026-05-15T10:00:00+07:00",
  "last_checkpoint": "2026-05-15T10:45:23+07:00",
  "status": "interrupted | running | completed | failed",
  "current_phase": "phase4-find-bugs",
  "completed_phases": ["phase1-init", "phase2-scan", "phase3-plan"],
  "next_action": {
    "type": "resume_phase | re_run_phase | advance",
    "phase": "phase4-find-bugs",
    "step": "step-2-dispatch-lanes",
    "lanes_completed": ["QD1", "QD2", "QD3"],
    "lanes_pending": ["QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"]
  },
  "args": {
    "scope": "module:crm/payment",
    "profile": "standard",
    "dims": null
  },
  "context_budget_at_checkpoint": "82%"
}
```

### 2.4. Resume flow (7 steps)

```
User: /wf-fix-bugs --resume
   │
   ▼
1. Skill detect resume mode → load procedures/resume-status.md
   │
   ▼
2. Scan .mc-data/work/wf-fix-bugs/_index/sessions.jsonl
   - Find latest session với status="interrupted"
   - Display: "Resume session 2026-05-15-crm-payment-01? (Y/n)"
   │
   ▼
3. Load $SESSION_DIR/fix-status.json
   - Read current_phase, completed_phases, next_action
   │
   ▼
4. Stale check: lock age > 30 min → auto-release
   - rm -f $SESSION_DIR/.lock
   - Start new heartbeat daemon
   │
   ▼
5. Re-validate PRE-GATE của current_phase
   - T1→T4 cho upstream artifacts
   - Fail → ESCALATE (rewind to previous phase)
   │
   ▼
6. Inject context_digest từ Protocol 3
   - Compressed summary of completed phases
   - Avoid re-reading full files
   │
   ▼
7. Route to next_action.phase + next_action.step
   - Tiếp tục từ điểm dừng (vd: lanes_pending → dispatch only those)
```

---

## 3. Case study — wf-fix-bugs --resume

**Scenario:**
```
Phase 4 chạy đến lane QD6 → context = 87%
   ↓
Step Nc context check → "Save checkpoint, STOP after phase 4"
   ↓
fix-status.json updated:
{
  "status": "interrupted",
  "current_phase": "phase4-find-bugs",
  "next_action": {
    "type": "resume_phase",
    "step": "step-2-dispatch-lanes",
    "lanes_completed": ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6"],
    "lanes_pending": ["QD7", "QD8", "QD9", "QD10", "QD11"]
  },
  "context_budget_at_checkpoint": "87%"
}
   ↓
Skill output: "Đã lưu checkpoint. Chạy '/wf-fix-bugs --resume' để tiếp tục."
```

**Khi user --resume:**
```
1. Load latest session → 2026-05-15-crm-payment-01
2. Read fix-status.json → next_action.lanes_pending = [QD7-QD11]
3. PRE-GATE re-check → OK (registry không đổi)
4. Inject context_digest:
   - Summary Phase 1-3 (init, scan, plan)
   - Aggregated signals từ QD1-QD6 đã có
5. Skip lanes QD1-QD6 (đã có signals.json)
6. Dispatch only QD7-QD11
7. Aggregate all 11 lanes → Phase 5
```

**Lợi ích:** Tiết kiệm ~40-50% time vs chạy lại từ đầu.

### 3.1. wf-legacy-scan resume

wf-legacy-scan v5.0 có **4 levels checkpoint:**

| Level | Tần suất | Granularity |
|-------|---------|-------------|
| L1 | Mỗi 5 phút | Coarse — phase boundary |
| L2 | Sau mỗi 1000 files scanned | Medium — stage progress |
| L3 | Sau mỗi 100 files | Fine — file-level |
| L4 | Real-time | Continuous — per file (incremental) |

User choose level via `--checkpoint-level=N`. Default L2.

---

## 4. Variations / Edge cases

### 4.1. Resume sau >30 min (stale lock)

```
Lock heartbeat > 30 min old
→ Auto-release: rm -f .lock
→ Start new daemon
→ WARN user: "Lock was stale (45 min) — assuming previous session crashed"
```

### 4.2. Source file changed during interrupt

```
checkpoint at 10:45 → user --resume at 14:30
git log shows 5 commits between 10:45-14:30 in scope
   ↓
PRE-GATE T4 cross-ref → suspect outdated signals
   ↓
ESCALATE: AskUserQuestion
  "5 commits since checkpoint. Re-scan affected files? (Yes/No)"
  Yes → invalidate cached lanes, re-dispatch
  No → proceed with cached (risky)
```

### 4.3. Context digest pattern (Protocol 3)

```
Thay vì reload full P1-P3 outputs (5000+ dòng):
   ↓
Build digest: 200-500 dòng compressed
  - Phase 1: summary departments + counts
  - Phase 2: summary features + critical findings
  - Phase 3: summary architecture + key decisions

Inject digest vào Phase 4 context → giảm 90% load
```

---

## 5. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Skill không có checkpoint → user mất 1 giờ công sức | BẮT BUỘC cho skill ≥30 min |
| State file format không versioned | Có `$schema` field |
| Resume không re-validate PRE-GATE | Phải re-check (state có thể stale) |
| Resume reload full upstream files | Dùng context digest (Protocol 3) |
| Lock không heartbeat → stuck forever | Heartbeat + 30 min stale check |
| Resume không inform user về thay đổi (source changed) | WARN + escalate |
| Checkpoint chỉ lưu phase name, thiếu step | Phải có next_action.phase + step + sub-state |
| Force re-run từ phase 1 mặc dù phase 1-3 done | Resume tôn trọng completed_phases |
| 80-90% threshold không trigger checkpoint | Bắt buộc lưu trong tier này |
| 90%+ vẫn force advance phase | FORCE STOP E009 — không advance |

---

## 6. Checklist áp dụng

**Khi thiết kế skill multi-session:**

- [ ] Định nghĩa state file schema (`fix-status.json` hoặc tương đương)
- [ ] State file versioned (`$schema`)
- [ ] `procedures/resume-status.md` cho `--resume` + `--status` handlers
- [ ] Implement context budget check tại mỗi phase boundary
- [ ] 65-80% → save checkpoint, log to session-log.json
- [ ] 80-90% → complete current phase, STOP, instruct --resume
- [ ] >90% → FORCE STOP (E009)
- [ ] Lock file với heartbeat (mỗi 30s update)
- [ ] Stale lock detection (>30 min → auto-release)
- [ ] `_index/sessions.jsonl` để discover sessions
- [ ] Resume flow: load state → re-validate PRE-GATE → digest inject → route
- [ ] Document `--resume` trong SKILL.md arguments table
- [ ] Test eval: simulate interrupt → resume → verify continuity

---

## 7. Liên kết

- **Standard:** [`../02-standards/09-session-checkpoint.md`](../02-standards/09-session-checkpoint.md)
- **Rule:** CORE-038 trong [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4o
- **Protocol 3 (Context Checkpoint):** [`.claude/skills/protocols/03-context-checkpoint.md`](../../.claude/skills/protocols/03-context-checkpoint.md)
- **Protocol 18 (Session Isolation):** [`.claude/skills/protocols/18-session-isolation.md`](../../.claude/skills/protocols/18-session-isolation.md)
- **Case study:** `.claude/skills/workflow/wf-fix-bugs/procedures/resume-status.md`
- **Related patterns:**
  - [`09-multi-session-locking.md`](09-multi-session-locking.md) — Lock + heartbeat
  - [`01-lazy-load-procedures.md`](01-lazy-load-procedures.md) — Resume cần procedure files
