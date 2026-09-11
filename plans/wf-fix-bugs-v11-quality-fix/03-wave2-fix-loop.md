# Wave 2 — Aggressive Auto-Loop + Defer Validation (G2 + G3)

> **Mục tiêu**: Đẩy fixed_count cao bằng cách re-spawn execute agent cho deferred items có quyền fix. Đây là wave giải quyết pain point chính của user.
>
> **ETA**: 11-16h
> **Đầu vào**: v10.19.0 (sau Wave 1)
> **Đầu ra**: v11.0.0 (major bump do behavior change Phase 6)
> **Direction đã chốt qua AskUserQuestion**: **Aggressive auto-loop** — skill tự quyết định, CDG chỉ hỏi khi sắp exhaust budget.

## Vấn đề cần giải quyết

**R3 — Max-Retry 3 không enforced**: Step 6.5 hardcode 1 retry (file `.retry-count-step-6.5`). CORE-034 nói max 3. Skill exit sớm khi còn nhiều deferred items.

**R4 — Quick-fix bị defer**: wf-fix-triage Anti-Invention Rule rất rõ ràng cấm "defer to backlog" (POST-GATE T6 enforce). Nhưng wf-fix-execute agent có quyền tự quyết viết `result="deferred"` cho bất kỳ item nào trong fix-report. Không có hard check sau-hoc cross-validate fix-log result vs issue fixability.

**Session settings 2026-05-16**: 104 items được plan với action="fix" (fixability=auto/agent_fix), nhưng execute agent chỉ fix 45, defer 59. CQG-1 v11 strict mode đã expose defect, Wave 2 sẽ FIX defect.

## Tasks

### W2-T1: `verify-defer-reasons.sh` (NEW script)

**Mục đích**: Cross-join `fix-log.json` (deferred items) × `fix-plan.md` (action column) × `issue-registry.json` (fixability) → emit `unsanctioned-defers.json`.

**File mới**: `.claude/scripts/wf-fix-bugs/verify-defer-reasons.sh`

**Logic**:
```bash
#!/usr/bin/env bash
# Input: $SESSION_DIR
# Output:
#   - $SESSION_DIR/phase6-execute/unsanctioned-defers.json (schema unsanctioned-defers-v1)
#   - stdout: summary JSON
#
# Cross-join:
#   1. From fix-log.json: extract entries with result="deferred"
#   2. From issue-registry.json: get fixability per issue_id
#   3. UNSANCTIONED: issue có fixability ∈ {auto_fix, agent_fix} nhưng kết quả deferred
#   4. LEGITIMATE: issue có fixability ∈ {manual_fix, escalate, skip} → defer là OK
#
# Fallback nếu fix-log không có per-issue entries (như session settings):
#   - Parse fix-report.md "## Deferred Issues" section
#   - Đếm items với issue_id trong bảng
#
# Exit codes:
#   0 — Analysis complete (kể cả có unsanctioned hay không)
#   1 — Required env missing
#   3 — Atomic write fail
```

**Output schema `unsanctioned-defers-v1`**:
```json
{
  "$schema": "unsanctioned-defers-v1",
  "generated_at": "<ISO>",
  "summary": {
    "total_deferred": <int>,
    "unsanctioned_count": <int>,  // issues với fixability=auto/agent_fix nhưng defer
    "legitimate_count": <int>,
    "data_source": "fix_log_per_issue|fix_report_table"
  },
  "unsanctioned_items": [
    {
      "issue_id": "ISS-...",
      "fixability_in_registry": "auto_fix",
      "plan_action": "fix",
      "exec_result": "deferred",
      "exec_reason": "<from fix-report narrative>",
      "severity": "HIGH",
      "files": [...]
    }
  ],
  "legitimate_items": [<same structure>]
}
```

**Acceptance**:
```bash
SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/2026-05-16-module-settings-01" \
  bash .claude/scripts/wf-fix-bugs/verify-defer-reasons.sh

# Expected on session settings:
#   unsanctioned_count > 0 (many items có fixability=auto/agent_fix nhưng defer)
#   legitimate_count nhỏ (false positives + true ESCALATE)
```

---

### W2-T2: `fix-iteration-loop.sh` (NEW script)

**Mục đích**: Orchestrator-side helper xử lý loop logic. Đọc state, decide tiếp tục/dừng/CDG.

**File mới**: `.claude/scripts/wf-fix-bugs/fix-iteration-loop.sh`

**Inputs**:
- `$SESSION_DIR/phase6-execute/unsanctioned-defers.json` (từ T1)
- `$SESSION_DIR/phase6-execute/.fix-iteration-count` (counter file)
- Env vars: `MCV3_FIX_LOOP_MAX_ITER` (default 3), `MCV3_FIX_LOOP_AUTO_ESCALATE` (default true)

**Output JSON** (stdout):
```json
{
  "decision": "continue_loop|escalate_cdg|done",
  "current_iteration": <int>,
  "max_iterations": 3,
  "unsanctioned_count": <int>,
  "next_action": "spawn_execute_with_unsanctioned|ask_user_question|finalize_phase6"
}
```

**Decision tree**:
- iteration < max AND unsanctioned > 0 → `continue_loop` + next_action `spawn_execute_with_unsanctioned`
- iteration >= max AND unsanctioned > 0 → `escalate_cdg` + next_action `ask_user_question` (CDG E095)
- unsanctioned == 0 → `done` + next_action `finalize_phase6`

**Acceptance**: Standalone test với fixed unsanctioned-defers.json (3 unsanctioned) + iteration_count=0 → expect "continue_loop".

---

### W2-T3: Integrate loop check vào `phase6-execute/E-validate-dashboard.md` Step 6.5

**File**: `procedures/phase6-execute/E-validate-dashboard.md`

**Thay đổi**: Sau khi verify-execute-outputs.sh + dashboard update PASS, thêm bước check loop:

```bash
# Step 6.5 mở rộng (v11):
# (a) verify-execute-outputs.sh (existing)
# (b) verify-defer-reasons.sh (W2-T1) — detect unsanctioned defers
# (c) fix-iteration-loop.sh (W2-T2) — decide tiếp tục/dừng

bash .claude/scripts/wf-fix-bugs/verify-defer-reasons.sh > /dev/null
LOOP_DECISION=$(bash .claude/scripts/wf-fix-bugs/fix-iteration-loop.sh)
ACTION=$(echo "$LOOP_DECISION" | jq -r '.next_action')

case "$ACTION" in
  spawn_execute_with_unsanctioned)
    # Re-spawn wf-fix-execute với scope thu hẹp (chỉ unsanctioned items)
    # Update fix-status.json: phases.phase6.loop_iteration += 1
    # GOTO: re-execute Group D (D-spawn-execute) với unsanctioned items
    ;;
  ask_user_question)
    # CDG E095 (W2-T5) — AskUserQuestion 3 options
    ;;
  finalize_phase6)
    # Tiếp tục bình thường sang Group F
    ;;
esac
```

---

### W2-T4: Update agent prompt template trong `phase6-execute/D-spawn-execute.md`

**File**: `procedures/phase6-execute/D-spawn-execute.md`

**Thêm vào Section 7 "Ownership Rules"**:

```
   FORBIDDEN DEFERS (v11):
   - KHÔNG được defer items có fixability ∈ {AUTO_FIX, AGENT_FIX, auto_fix, agent_fix}
     trong fix-report.md hoặc fix-log.json
   - Nếu KHÔNG THỂ fix (technical blocker, env issue, etc.) → ghi vào
     `phase6-execute/fix-blockers.md` với rationale rõ ràng + đề xuất escalation
   - Agent ghi `result="deferred"` CHỈ KHI fixability ∈ {MANUAL_FIX, ESCALATE, SKIP,
     manual_fix, escalate, skip}
   - Vi phạm sẽ bị block bởi POST-GATE T6 (Step 6.5 verify-defer-reasons.sh)
```

**Thêm vào Section 8 "Completion Criteria"**:
```
   - Mọi item trong fix-plan.md với action="fix" và fixability=auto_fix/agent_fix
     PHẢI có fix-log entry với result="fixed" hoặc "resolved" hoặc "verified_resolved"
   - Items với result="deferred" MUST kèm exec_reason trong fix-log notes field
```

---

### W2-T5: CDG E095 — AskUserQuestion khi budget exhausted

**File**: Thêm INLINE block vào `phase6-execute/E-validate-dashboard.md` cho case `ACTION=ask_user_question`.

**CDG structure**:
```javascript
// E095 — Unsanctioned defers vẫn còn sau MAX_ITER iterations
AskUserQuestion({
  questions: [{
    question: "Còn [N] items defer dù được phép fix sau [MAX_ITER] iterations. Hành động?",
    header: "Defer escalation",
    multiSelect: false,
    options: [
      { 
        label: "Force-fix với expert agent (Recommended)",
        description: "Spawn domain expert agent (architect/security/etc.) để cố fix manual scope thu hẹp"
      },
      {
        label: "Accept defer — chuyển sang sprint planning",
        description: "Mark items là 'requires_human_decision', ghi vào fix-blockers.md để team review sau"
      },
      {
        label: "Spawn cross-scope session ngay",
        description: "Mở /wf-fix-bugs --scope=cross-module session mới — phù hợp khi items vượt scope hiện tại"
      }
    ]
  }]
})

// Token: cdg-tokens.json append {"gate": "E095", "decision": "<user_choice>"}
```

---

### W2-T6: `fix-iterations.json` schema + template

**File mới template**: `.claude/skills/workflow/wf-fix-bugs/templates/phase6-execute/fix-iterations.json`

**Schema `fix-iterations-v1`**:
```json
{
  "$schema": "fix-iterations-v1",
  "session_id": "<SESSION_ID>",
  "max_iterations": 3,
  "current_iteration": 0,
  "started_at": "<ISO>",
  "iterations": [
    {
      "iteration": 1,
      "started_at": "<ISO>",
      "completed_at": "<ISO>",
      "input_unsanctioned_count": <int>,
      "after_fix_count": <int>,
      "after_deferred_count": <int>,
      "agent_decisions": [
        {"issue_id": "ISS-...", "action": "fixed|deferred|blocked", "rationale": "..."}
      ]
    }
  ],
  "final_decision": "completed|cdg_escalated|max_exhausted",
  "cdg_token": null
}
```

**Audit trail**: Mỗi iteration ghi 1 entry. Visible trong Phase6-report.md + bug-dashboard.md.

---

### W2-T7: Update `generate-phase6-report.sh` include iteration summary

**File**: `.claude/scripts/wf-fix-bugs/generate-phase6-report.sh`

**Thay đổi**: Thêm section "## Fix Iteration Loop" vào Phase6-report.md:

```markdown
## Vòng lặp Fix Iteration (v11)

| Iteration | Input unsanctioned | After fix | After defer | Agent quyết định |
|-----------|-------------------|-----------|-------------|------------------|
| 1 | 59 | 30 | 29 | Fix 30, defer 29 (technical blockers) |
| 2 | 29 | 18 | 11 | Fix 18, defer 11 (needs DBA review) |
| 3 | 11 | 5 | 6 | Fix 5, defer 6 → CDG E095 |

**Tổng cộng**: 53 fixed (45 first-run + 8 từ loops), 11 unsanctioned final → CDG E095 trigger.
```

---

## Smoke tests Wave 2

### W2-S1: Loop iteration enforcement
```bash
# Mock: tạo unsanctioned-defers.json có 5 items, set iteration_count=0
# Expected: 3 iterations xảy ra, sau đó CDG E095 trigger nếu vẫn còn

# Verify .fix-iteration-count tăng đúng (0 → 1 → 2 → 3)
# Verify CDG token cdg-tokens.json có entry E095 sau iteration 3
```

### W2-S2: Real session settings test
```bash
# Re-run session settings sau Wave 2 ship
cd "D:/Working/EUREKA-2026"
/wf-fix-bugs --resume --session=2026-05-16-module-settings-01

# Expected:
# - Iteration 1 picks up ~30-40 unsanctioned items (entity guards, perf opt)
# - Iteration 2 picks up 15-25 more (resiliency, compat)
# - Iteration 3 OR CDG E095 nếu vẫn còn
# - fixed_count tăng từ 45 lên ≥ 70 (target)
```

### W2-S3: Backward-compat
```bash
# Set MCV3_FIX_LOOP_MAX_ITER=1 (giả lập behavior v10.x)
# Expected: chỉ 1 iteration (như cũ), không CDG E095
# Phase 6 vẫn complete bình thường, không break
```

---

## Files thay đổi (Wave 2 summary)

| File | Loại | Tạo bởi task |
|------|------|--------------|
| `.claude/scripts/wf-fix-bugs/verify-defer-reasons.sh` | CREATE | W2-T1 |
| `.claude/scripts/wf-fix-bugs/fix-iteration-loop.sh` | CREATE | W2-T2 |
| `.claude/skills/workflow/wf-fix-bugs/templates/phase6-execute/fix-iterations.json` | CREATE | W2-T6 |
| `.claude/skills/workflow/wf-fix-bugs/procedures/phase6-execute/E-validate-dashboard.md` | MODIFY | W2-T3 + W2-T5 |
| `.claude/skills/workflow/wf-fix-bugs/procedures/phase6-execute/D-spawn-execute.md` | MODIFY | W2-T4 |
| `.claude/scripts/wf-fix-bugs/generate-phase6-report.sh` | MODIFY | W2-T7 |
| `.claude/skills/workflow/wf-fix-bugs/SKILL.md` | MODIFY | Version bump v10.19.0 → v11.0.0 |
| `.claude/skills/workflow/wf-fix-bugs/_contract.json` | MODIFY | Add unsanctioned-defers + fix-iterations outputs |
| `CHANGELOG.md` | MODIFY | Wave 2 release notes |
| `plans/wf-fix-bugs-v11-quality-fix/progress.md` | MODIFY | Mark Wave 2 done |

**Total**: 10 files (3 new, 7 modified)
