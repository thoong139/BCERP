# Resume Logic & Routing Table

> Tách từ `_shared.md` (S5 refactor — G7 fix). Gọi từ Phase 0 Step 0.2 §--resume handler.

> **Shared:** Xem `procedures/_shared.md` — State Variables, Lock Protocol (S2).

---

## Resume Process

1. **Read `.mc-data/work/wf-manage-change/index.json`**
   - Nếu không tồn tại → STOP: *"Không tìm thấy session nào. Chạy `/wf-manage-change` từ đầu."*

2. **Lấy active session:** `$CHANGE_ID = index.json.active_session` → set `$SESSION_DIR`
   - Nếu `active_session == null` hoặc session status == "completed" → STOP: *"Không có session nào đang tiến hành."*

3. **[S2] Lock-aware resume guard:**

   Kiểm tra trạng thái session lock TRƯỚC khi load state. Mục đích: tránh hai process cùng resume một session đang chạy → corrupt checkpoint/registry.

   ```
   IF test -f $SESSION_DIR/.session.lock:
     → Thử acquire lại lock: bash .claude/scripts/wf-manage-change/mc-acquire-lock.sh --type=session --id=$CHANGE_ID

     CASE 1 — Acquire SUCCESS (exit 0):
       → Lock cũ stale (PID dead, hoặc heartbeat > MC_LOCK_STALE_MIN phút,
         hoặc cross-host age > stale threshold). Script tự takeover.
       → Tiếp tục Step 4.

     CASE 2 — Acquire FAIL (exit 1):
       → Lock đang active (PID alive + heartbeat fresh) — session khác đang chạy.
       → STOP với WARNING:
         "⚠️ Session $CHANGE_ID đang chạy ở process khác (owner: <user>@<host>, PID: <pid>).
          Resume bị từ chối để tránh xung đột.
          Nếu chắc chắn process kia đã chết, xóa thủ công:
            rm $SESSION_DIR/.session.lock
          Hoặc đợi heartbeat stale (>$MC_LOCK_STALE_MIN phút) rồi thử lại."

   ELSE (lock không tồn tại):
     → Session đã release lock đúng cách (Phase 6 Step 6.4b hoặc EXIT trap).
     → Acquire lock mới: bash .claude/scripts/wf-manage-change/mc-acquire-lock.sh --type=session --id=$CHANGE_ID
     → Tiếp tục Step 4.
   ```

4. **Read `$SESSION_DIR/change-status.json`**

5. **RE-BIND TẤT CẢ STATE VARIABLES từ change-status.json (BẮT BUỘC — GAP-2 fix):**

   > **Lý do bắt buộc:** Các biến in-memory không tồn tại xuyên session. Nếu thiếu bước này, các phase sau (đặc biệt Phase 4b Step 4b.6) sẽ không có `$CHANGE_TYPE` đúng → impl_status lifecycle bị hỏng.

   Đọc `$SESSION_DIR/change-status.json` và re-bind:
   - `$DRY_RUN = change-status.json.flags.dry_run`
   - `$RUN_TESTS = change-status.json.flags.run_tests`
   - `$CHANGE_TYPE = change-status.json.intake.change_type_confirmed` ← **CRITICAL cho Phase 4b.6**
   - `$MATURITY = change-status.json.intake.maturity`
   - `$LEGACY_MODE = change-status.json.intake.legacy_mode`
   - `$DEPRECATED_MODULES = change-status.json.intake.deprecated_modules` (default: `[]`)
   - `$REFERENCED_ARTIFACTS = change-status.json.intake.referenced_artifacts` (default: `[]`)
   - `$CHANGE_ID = change-status.json.change_id` (nếu chưa set từ bước 2)
   - `$SESSION_DIR = .mc-data/work/wf-manage-change/$CHANGE_ID/`

   **Fallback khi field thiếu (change-status.json từ version cũ):**
   - `$CHANGE_TYPE` thiếu → default `MODIFY_FEATURE` + WARNING
   - `$MATURITY` thiếu → default `implementing` + WARNING
   - `$LEGACY_MODE` thiếu → default `false` + WARNING
   - `$DEPRECATED_MODULES` thiếu → default `[]`
   - `$REFERENCED_ARTIFACTS` thiếu → default `[]`
   - `$RUN_TESTS` thiếu → default `false`

   Sau re-bind: Nếu `$DRY_RUN == true` VÀ `current_phase >= phase4a` → thông báo "Trước đó là dry-run, skip Phase 4-5, nhảy sang Phase 6 report"

6. **[S2] Restart heartbeat daemon + EXIT trap:**

   Sau khi re-acquire session lock thành công ở Step 3, restart heartbeat để giữ lock fresh:

   ```bash
   bash .claude/scripts/wf-manage-change/mc-heartbeat.sh --id=$CHANGE_ID &
   HEARTBEAT_PID=$!
   trap "kill $HEARTBEAT_PID 2>/dev/null; bash .claude/scripts/wf-manage-change/mc-release-lock.sh --type=session --id=$CHANGE_ID" EXIT
   ```

   Đảm bảo: nếu resume crash → trap release lock → lần resume sau không bị block.

7. **Read `$SESSION_DIR/checkpoint.json`** — inject `context_digest` nếu có

8. **VALIDATE:** `current_phase` ∈ `["phase0","phase1","phase2","phase3","phase4a","phase4b","phase4c","phase5","phase6"]`

9. **LOAD context** từ `checkpoint.resume_instructions.load_files[]`

10. **Route theo bảng dưới → CONTINUE từ `checkpoint.resume_instructions.next_action`**

### Routing Table

| `current_phase` | Nhảy đến | File procedure |
|-----------------|----------|----------------|
| `phase0` | Phase 0: Intake | `procedures/phase0-intake.md` |
| `phase1` | Phase 1: Analyze | `procedures/phase1-analyze.md` |
| `phase2` | Phase 2: Impact | `procedures/phase2-impact.md` |
| `phase3` | Phase 3: Plan | `procedures/phase3-plan.md` |
| `phase4a` | Phase 4a: Registry + Docs | `procedures/phase4a-registry-docs.md` |
| `phase4b` | Phase 4b: Code | `procedures/phase4b-code.md` |
| `phase4c` | Phase 4c: Tests | `procedures/phase4c-tests.md` |
| `phase5` | Phase 5: Verify | `procedures/phase5-verify.md` |
| `phase6` | Phase 6: Report | `procedures/phase6-report.md` |
