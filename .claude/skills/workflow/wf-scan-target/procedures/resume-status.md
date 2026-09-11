# Phase 0.0 — Resume / Status Dispatch

> **Sprint 3 lazy-load refactor.** Tách dispatch logic (Sprint 2 — GAP-05) từ flow.md
> thành file riêng. Chạy TRƯỚC khi parse args đầy đủ. Detect `--resume` / `--status` flags
> và route phù hợp. Fresh run (không có flags) → bỏ qua, vào `phase0-setup.md` trực tiếp.

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Helper Functions (`compute_fingerprint`, `trace_resume_event`, `elapsed`)

## Load Condition

SKILL.md routing dispatch vào file này khi `$ARGUMENTS` chứa `--status` hoặc `--resume`.
Nếu fresh run (không có flags) → bỏ qua, vào thẳng `phase0-setup.md`.

---

## Dispatch Logic

```bash
# Detect flags từ $ARGUMENTS (best-effort grep)
HAS_STATUS=$(echo "$ARGUMENTS" | grep -qE '(^|[[:space:]])--status([[:space:]]|$|=)' && echo "true" || echo "false")
HAS_RESUME=$(echo "$ARGUMENTS" | grep -qE '(^|[[:space:]])--resume([[:space:]]|$|=)' && echo "true" || echo "false")

SESSIONS_DIR=".mc-data/work/wf-scan-target/sessions"
```

---

## CASE A: --status — hiển thị status các sessions, KHÔNG scan

```bash
IF HAS_STATUS == "true":

  # 1) Liệt kê sessions/ (nếu thư mục chưa tồn tại → "Chưa có session nào")
  IF NOT test -d "$SESSIONS_DIR":
    Display: "Chưa có session nào. Chạy /wf-scan-target --target=<path|url> để bắt đầu."
    STOP (exit 0)

  # 2) Build status table — sort latest 5 theo started_at desc
  Display header:
    "Trạng thái Sessions — wf-scan-target"
    ""
    "| Session ID | Target | Status | Phase | Started | Duration |"
    "|-----------|--------|--------|-------|---------|----------|"

  # 3) Scan tất cả sessions, lấy data từ scan-status.json
  FOR each dir in $(ls -t $SESSIONS_DIR/ | head -5):
    STATUS_FILE="$SESSIONS_DIR/$dir/scan-status.json"
    IF NOT test -s "$STATUS_FILE":
      continue

    SID=$(jq -r '.session_id // "(missing)"' "$STATUS_FILE")
    TGT=$(jq -r '.target // "—"' "$STATUS_FILE")
    ST=$(jq -r '.status // "—"' "$STATUS_FILE")
    STARTED=$(jq -r '.started_at // "—"' "$STATUS_FILE")
    COMPLETED=$(jq -r '.completed_at // empty' "$STATUS_FILE")

    # Phase đang ở: phase nào in_progress, hoặc phase cuối completed
    CURRENT_PHASE=$(jq -r '
      [.phases | to_entries[] | select(.value.status == "in_progress")] as $ip |
      if ($ip | length) > 0 then ($ip[0].key) else
        [.phases | to_entries[] | select(.value.status == "completed")] as $cp |
        if ($cp | length) > 0 then ($cp[-1].key) else "phase_0" end
      end' "$STATUS_FILE" | sed 's/phase_/P/')

    # Duration tính được nếu completed_at có
    IF [ -n "$COMPLETED" ]; then
      DUR="$(elapsed $STARTED $COMPLETED)"
    else
      DUR="—"
    fi

    Display row: "| $SID | $TGT | $ST | $CURRENT_PHASE | $STARTED | $DUR |"

  # 4) Footer hint
  Display: ""
          "Tip: Dùng --resume để tiếp tục session in_progress."
          "     Dùng --target=<path> để bắt đầu session mới."

  STOP (exit 0)
```

---

## CASE B: --resume — tiếp tục session in_progress

```bash
IF HAS_RESUME == "true":

  # 1) Detect --session=<id> override (optional)
  SESSION_OVERRIDE=$(echo "$ARGUMENTS" | grep -oE '\-\-session=[^[:space:]]+' | sed 's/--session=//')

  # 2) Tìm candidates (status IN ("in_progress", "paused"))
  IF [ -n "$SESSION_OVERRIDE" ]; then
    candidates=("$SESSION_OVERRIDE")
    IF NOT test -d "$SESSIONS_DIR/$SESSION_OVERRIDE":
      ERROR "Session '$SESSION_OVERRIDE' không tồn tại trong $SESSIONS_DIR"
      STOP (exit 2)
  else
    candidates=()
    FOR each dir in $(ls $SESSIONS_DIR/ 2>/dev/null); do
      ST=$(jq -r '.status // ""' "$SESSIONS_DIR/$dir/scan-status.json" 2>/dev/null)
      IF [ "$ST" = "in_progress" ] || [ "$ST" = "paused" ]; then
        candidates+=("$dir")
      fi
    done
  fi

  # 3) Xử lý số lượng candidates
  IF [ ${#candidates[@]} -eq 0 ]:
    Display: "Không có session nào in_progress/paused để resume."
    Display: "Dùng /wf-scan-target --status để xem danh sách sessions."
    STOP (exit 0)

  IF [ ${#candidates[@]} -gt 1 ]:
    # AskUserQuestion
    Display: "Có ${#candidates[@]} sessions chưa hoàn thành:"
    FOR each c in "${candidates[@]}":
      TGT=$(jq -r '.target // "—"' "$SESSIONS_DIR/$c/scan-status.json")
      PHASE=$(jq -r '[.phases | to_entries[] | select(.value.status=="in_progress")][0].key // "P?"' "$SESSIONS_DIR/$c/scan-status.json")
      Display: "  - $c (target: $TGT, phase: $PHASE)"
    AskUserQuestion: "Resume session nào? (nhập session ID đầy đủ)"
    RESUME_SESSION_ID = user input
    IF RESUME_SESSION_ID NOT IN candidates:
      ERROR "Session ID không hợp lệ"
      STOP (exit 2)
  ELSE:
    RESUME_SESSION_ID="${candidates[0]}"

  # 4) Set SESSION_DIR + load state
  SESSION_DIR="$SESSIONS_DIR/$RESUME_SESSION_ID"
  SESSION_ID="$RESUME_SESSION_ID"

  IF NOT test -s "$SESSION_DIR/checkpoint.json":
    WARN "checkpoint.json không tồn tại — fallback dùng scan-status.json để route"
    HAS_CHECKPOINT=false
  else:
    HAS_CHECKPOINT=true

  # 5) Load args_snapshot từ checkpoint (nếu có), nếu không thì lấy từ scan-status.json
  IF HAS_CHECKPOINT:
    target=$(jq -r '.args_snapshot.target // ""' "$SESSION_DIR/checkpoint.json")
    module_name=$(jq -r '.args_snapshot.module // ""' "$SESSION_DIR/checkpoint.json")
    compare_path=$(jq -r '.args_snapshot.compare // empty' "$SESSION_DIR/checkpoint.json")
    scan_depth=$(jq -r '.args_snapshot.depth // "deep"' "$SESSION_DIR/checkpoint.json")
    output_dir=$(jq -r '.args_snapshot.output // empty' "$SESSION_DIR/checkpoint.json")
    OLD_FINGERPRINT=$(jq -r '.target_fingerprint // ""' "$SESSION_DIR/checkpoint.json")
  else:
    target=$(jq -r '.target // ""' "$SESSION_DIR/scan-status.json")
    module_name=$(jq -r '.module_name // ""' "$SESSION_DIR/scan-status.json")
    scan_depth=$(jq -r '.scan_depth // "deep"' "$SESSION_DIR/scan-status.json")
    OLD_FINGERPRINT=$(jq -r '.target_fingerprint // ""' "$SESSION_DIR/scan-status.json")

  Log: "Resuming session: $RESUME_SESSION_ID (target: $target)"

  # 6) Verify target_fingerprint chưa đổi (GAP-12 — Sprint 2)
  # Compute fingerprint mới TRƯỚC KHI tiếp tục scan
  # (compute_fingerprint helper — xem _shared.md §Helper Functions)
  NEW_FINGERPRINT=$(compute_fingerprint "$target" "$detected_tech_stack_csv" "$scan_depth")

  IF [ -n "$OLD_FINGERPRINT" ] && [ "$OLD_FINGERPRINT" != "$NEW_FINGERPRINT" ]:
    # CDG (custom — thuộc nhóm Resume Validation)
    Display:
      "⚠️ Target đã thay đổi từ lúc scan trước:
         Cũ:  ${OLD_FINGERPRINT:0:16}...
         Mới: ${NEW_FINGERPRINT:0:16}...

       Lý do có thể: code thay đổi, git checkout branch khác, manifest update, depth khác.

       Bạn muốn:
       - Có: Tiếp tục resume (dùng kết quả cũ + scan tiếp phần còn lại — có thể stale)
       - Không: Hủy resume, chạy lại từ đầu (bắt buộc /wf-scan-target --target=$target mới)"

    AskUserQuestion → user_choice
    IF user_choice == "Không":
      Log: "User hủy resume do fingerprint mismatch — STOP"
      STOP (exit 0)
    ELSE:
      Log: "User chấp nhận resume mặc dù fingerprint mismatch — mark stale_target=true"
      STALE_TARGET_WARNING=true

  # 7) Lock file check (Sprint 2 = light handling, đầy đủ ở Sprint 6)
  LOCK_FILE="$SESSION_DIR/.lock"
  IF test -f "$LOCK_FILE":
    OLD_PID=$(jq -r '.pid // 0' "$LOCK_FILE" 2>/dev/null)
    IF [ "$OLD_PID" -gt 0 ] && kill -0 "$OLD_PID" 2>/dev/null; then
      ERROR "Session đang chạy bởi process $OLD_PID — đợi process hoàn tất hoặc kill nó trước khi --resume"
      STOP (exit 1)
    else
      Log: "Cleanup dead lock (pid=$OLD_PID không còn chạy)"
      rm -f "$LOCK_FILE"
    fi

  # 8) Tạo lock mới (Sprint 2 = minimal, full heartbeat ở Sprint 6)
  echo "{\"pid\": $$, \"host\": \"$(hostname)\", \"started_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"session_id\": \"$SESSION_ID\"}" > "$LOCK_FILE"

  # 9) Append session-log.json: event "RESUME"
  trace_resume_event "$SESSION_ID" "$target"  # helper xem _shared.md

  # 10) Route đến phase tương ứng từ checkpoint.next_action.phase
  IF HAS_CHECKPOINT:
    NEXT_PHASE=$(jq -r '.next_action.phase // empty' "$SESSION_DIR/checkpoint.json")
    NEXT_LAYER=$(jq -r '.next_action.layer // empty' "$SESSION_DIR/checkpoint.json")
    NEXT_STEP=$(jq -r '.next_action.step // empty' "$SESSION_DIR/checkpoint.json")
    Log: "Routing: phase=$NEXT_PHASE layer=$NEXT_LAYER step=$NEXT_STEP"
  else:
    # Fallback: route đến phase đầu tiên có status != completed
    NEXT_PHASE=$(jq -r '
      [.phases | to_entries[] | select(.value.status != "completed" and .value.status != "skipped")] as $pending |
      if ($pending | length) > 0 then $pending[0].key else "phase_5" end' "$SESSION_DIR/scan-status.json")
    Log: "Routing (fallback): phase=$NEXT_PHASE (từ scan-status.json)"

  # 11) Load intermediate outputs (nếu có)
  IF test -d "$SESSION_DIR/intermediate":
    [ -s "$SESSION_DIR/intermediate/tech-stack.json" ] && TECH_STACK_JSON="$SESSION_DIR/intermediate/tech-stack.json"
    [ -s "$SESSION_DIR/intermediate/l1-structure.json" ] && L1_RESULT_FILE="$SESSION_DIR/intermediate/l1-structure.json"
    [ -s "$SESSION_DIR/intermediate/l2-api.json" ] && L2_RESULT_FILE="$SESSION_DIR/intermediate/l2-api.json"
    [ -s "$SESSION_DIR/intermediate/l3-ui.json" ] && L3_RESULT_FILE="$SESSION_DIR/intermediate/l3-ui.json"
    [ -s "$SESSION_DIR/intermediate/l4-db.json" ] && L4_RESULT_FILE="$SESSION_DIR/intermediate/l4-db.json"
    Log: "Loaded intermediate outputs từ $SESSION_DIR/intermediate/"

  # 12) Skip Phase 0.1-0.5 (đã chạy trước đó), jump thẳng đến NEXT_PHASE
  Display: "Resuming /wf-scan-target từ $NEXT_PHASE..."
  GOTO Phase ${NEXT_PHASE/phase_/}
```

---

## CASE C: Fresh run — không có --resume / --status

```bash
IF HAS_STATUS == "false" && HAS_RESUME == "false":
  # KHÔNG load file này — SKILL.md routing đã không dispatch vào đây
  Continue → Read procedures/phase0-setup.md
```

---

## Next Phase

Sau dispatch:
- CASE A `--status` → STOP (không phase tiếp theo)
- CASE B `--resume` → Route đến phase từ `checkpoint.next_action.phase`:
  - `phase_1` → Read `procedures/phase1-detect.md`
  - `phase_2` (+ layer) → Read `procedures/phase2-l{1,2,3,4}-*.md`
  - `phase_3` → Read `procedures/phase3-synthesis.md`
  - `phase_4` → Read `procedures/phase4-gap.md`
  - `phase_5` → Read `procedures/phase5-output.md`
- CASE C fresh run → Read `procedures/phase0-setup.md`
