# wf-fix-triage — Resume & Status Handlers

> **Sub-skill notice:** Pattern dispatch chung với wf-fix-bugs `procedures/resume-status.md`.
> Khác biệt: wf-fix-triage chỉ có Phase 2 (Triage) — không có Phase 1/3-7.

## --status Handler

**Entry point:** User chạy `/wf-fix-triage --status` (hiếm — thường dùng `/wf-fix-bugs --status` cho full pipeline).

```
1. Tìm session đang chạy:
   LATEST_STATUS=$(find .mc-data/work/wf-fix-bugs -maxdepth 4 -type f -name "fix-status.json" 2>/dev/null \
     | xargs -I{} sh -c 'echo "$(jq -r ".timestamps.started_at // empty" "{}" 2>/dev/null) {}"' \
     | sort -r | head -1 | awk '{print $NF}')

   IF $LATEST_STATUS empty:
     → "Khong tim thay session wf-fix-bugs nao. Chay /wf-fix-bugs truoc."
     → STOP

2. READ $LATEST_STATUS → hien thi:
   - SESSION_ID
   - phases.phase_1.status (Lane Dispatch) — completed | in_progress | pending
   - phases.phase_2.status (Triage — CỦA TRIAGE SKILL) — completed | in_progress | pending | not_started
   - issues counts (nếu phases.phase_2.status == "completed"):
     · by_severity (critical/high/medium/low)
     · by_action (auto_fix/agent_fix/manual_fix/escalate/skip)
     · escalation_count
   - output_files paths
   - progress_pct (sau triage = 30)

3. STOP — KHÔNG advance Phase 2.
```

## --resume Handler

**Entry point:** User chạy `/wf-fix-triage --resume` để tiếp tục từ checkpoint.

```
1. Tìm session cần resume (giống --status §1, nhưng filter):
   - phases.phase_1.status == "completed" (Lane Dispatch phải xong)
   - phases.phase_2.status != "completed" (chưa triage hoặc đang dở)

   IF không tìm thấy:
     → "Khong co session nao can resume. Chay /wf-fix-bugs --resume de re-run from latest checkpoint."
     → STOP

2. Stale lock check (per wf-fix-bugs §13):
   - Đọc .lock file trong $SESSION_DIR
   - PATH A: lock.host == current_host → kill -0 lock.pid:
     · Process alive → ERROR (E031): "Session lock conflict — có process khác đang chạy."
     · Process dead → auto-release lock, takeover (E008 WARN)
   - PATH B: khác host hoặc thiếu PID → filesystem mtime:
     · age < MCV3_LOCK_STALE_MINUTES (default 60) → ERROR (E031)
     · age ≥ stale window → auto-release, takeover (E008 WARN)

3. Acquire lock + start heartbeat daemon (per wf-fix-bugs §13):
   bash .claude/scripts/wf-fix-common.sh; acquire_lock "$SESSION_DIR"; start_heartbeat_daemon "$SESSION_DIR"
   trap cleanup EXIT INT TERM

4. Route theo phase_2 sub-state (chi tiết trong $SESSION_DIR/fix-status.json):
   - phase_2.checkpoint == "step_2_0" (scope filter) → restart Phase 2 từ Step 2.0
   - phase_2.checkpoint == "step_2_3_outputs" (đang tạo outputs) → resume Step 2.3 series
   - phase_2.checkpoint == "step_2_7_cdg" (đang chờ user confirm) → re-prompt CDG
   - phase_2.checkpoint == "step_2_8_summary" (đang viết phase-summary) → restart Step 2.8
   - phase_2.checkpoint absent → restart Phase 2 từ Step 2.0 (idempotent)

5. Re-validate PRE-GATE (per SKILL.md §Phase 0: PRE-GATE):
   - fix-status.json valid
   - issue-registry.json (initial) tồn tại
   - phases.phase_1.status == "completed"

6. Tiếp tục thực thi Phase 2 từ checkpoint resolved ở §4.
```

## Resume Edge Cases

| Tình huống | Hành động |
|-----------|-----------|
| issue-registry.json missing | E_RESUME_MISSING_INPUT — hướng dẫn `/wf-fix-bugs --resume` để regenerate |
| phases.phase_1.status == "in_progress" (Lane Dispatch chưa xong) | E_RESUME_PHASE1_INCOMPLETE — hướng dẫn `/wf-fix-bugs --resume` để hoàn tất Lane Dispatch trước |
| phases.phase_2.status == "completed" | "Triage đã hoàn tất. Chạy `/wf-fix-execute --resume` để tiếp tục pipeline." → STOP |
| Multiple sessions không completed | Hiển thị danh sách + AskUserQuestion chọn session cụ thể |

---

> **Notice (XF-07b extraction):** File này tạo theo F01.017 + audit 2026-05-15 Sprint 4. Trước đây wf-fix-triage không có `procedures/resume-status.md`. Pattern dispatch theo `wf-fix-bugs/procedures/resume-status.md`.
