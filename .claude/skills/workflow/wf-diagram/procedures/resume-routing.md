# /wf-diagram — Resume / Status Dispatch (Phase 0.0)

> Lazy-loaded từ `phase0-setup.md` Step 0.0 khi `$ARGUMENTS` chứa `--status` hoặc `--resume`.
> Fresh run (không có flags) → bỏ qua, tiếp tục `phase0-setup.md`.
> Xem `_shared.md` cho state vars, helpers, error matrix.

---

## Load Condition

`phase0-setup.md` Step 0.0 dispatch vào file này khi detect `--status` hoặc `--resume`.
Nếu fresh run → KHÔNG load file này.

```bash
SESSIONS_DIR=".mc-data/work/wf-diagram/sessions"
HAS_STATUS=$(echo "$ARGUMENTS" | grep -qE '(^|[[:space:]])--status([[:space:]]|$)' && echo "true" || echo "false")
HAS_RESUME=$(echo "$ARGUMENTS" | grep -qE '(^|[[:space:]])--resume([[:space:]]|$)' && echo "true" || echo "false")
```

---

## CASE A: --status — Hiển thị sessions, KHÔNG generate

```bash
IF HAS_STATUS == "true":

  IF NOT test -d "$SESSIONS_DIR":
    Display: "Chưa có session nào. Chạy /wf-diagram --module=<name> để bắt đầu."
    STOP (exit 0)

  # Build table — sort by started_at desc, latest 5
  Display:
    "Trạng thái Sessions — wf-diagram"
    ""
    "| Session ID | Module | Scope | Status | Phase | Started |"
    "|-----------|--------|-------|--------|-------|---------|"

  FOR each dir in $(ls -t "$SESSIONS_DIR/" | head -5):
    STATUS_FILE="$SESSIONS_DIR/$dir/diagram-status.json"
    IF NOT test -s "$STATUS_FILE": continue

    SID=$(jq -r '.session_id // "(missing)"' "$STATUS_FILE")
    MOD=$(jq -r '.module // "—"' "$STATUS_FILE")
    SC=$(jq -r  '.scope  // "full"' "$STATUS_FILE")
    ST=$(jq -r  '.status // "—"' "$STATUS_FILE")
    STARTED=$(jq -r '.started_at // "—"' "$STATUS_FILE")

    # Phase hiện tại: in_progress → phase đó; nếu không có → phase cuối done
    CURRENT_PHASE=$(jq -r '
      [.phases | to_entries[] | select(.value.status == "in_progress")] as $ip |
      if ($ip | length) > 0 then ($ip[0].key)
      else [.phases | to_entries[] | select(.value.status == "completed")] as $cp |
        if ($cp | length) > 0 then ($cp[-1].key) else "phase_0" end
      end' "$STATUS_FILE" | sed 's/phase_/P/')

    Display row: "| $SID | $MOD | $SC | $ST | $CURRENT_PHASE | $STARTED |"

  Display:
    ""
    "Tip: Dùng --resume để tiếp tục session in_progress."
    "     Dùng --module=<name> để bắt đầu session mới."

  STOP (exit 0)
```

---

## CASE B: --resume — Tiếp tục session in_progress / paused

```bash
IF HAS_RESUME == "true":

  # 1) Detect --session=<id> override (optional)
  SESSION_OVERRIDE=$(echo "$ARGUMENTS" | grep -oE '\-\-session=[^[:space:]]+' | sed 's/--session=//')

  # 2) Tìm candidates (status = "in_progress" hoặc "paused")
  IF [ -n "$SESSION_OVERRIDE" ]:
    IF NOT test -d "$SESSIONS_DIR/$SESSION_OVERRIDE":
      Display: "ERROR: Session '$SESSION_OVERRIDE' không tồn tại trong $SESSIONS_DIR"
      STOP (exit 2)
    candidates=("$SESSION_OVERRIDE")
  ELSE:
    candidates=()
    FOR each dir in $(ls "$SESSIONS_DIR/" 2>/dev/null):
      ST=$(jq -r '.status // ""' "$SESSIONS_DIR/$dir/diagram-status.json" 2>/dev/null)
      IF [ "$ST" = "in_progress" ] || [ "$ST" = "paused" ]:
        candidates+=("$dir")

  # 3) Xử lý số lượng candidates
  IF [ ${#candidates[@]} -eq 0 ]:
    Display: "Không có session nào in_progress/paused để resume."
    Display: "Dùng /wf-diagram --status để xem danh sách sessions."
    STOP (exit 0)

  IF [ ${#candidates[@]} -gt 1 ]:
    Display: "Có ${#candidates[@]} sessions chưa hoàn thành:"
    FOR each c in "${candidates[@]}":
      MOD=$(jq -r '.module // "—"' "$SESSIONS_DIR/$c/diagram-status.json")
      PHASE=$(jq -r '
        [.phases | to_entries[] | select(.value.status == "in_progress")][0].key // "?"
        ' "$SESSIONS_DIR/$c/diagram-status.json")
      Display: "  - $c (module: $MOD, phase: $PHASE)"
    AskUserQuestion: "Resume session nào? (nhập session ID đầy đủ)"
    RESUME_SESSION_ID = user_answer
    IF RESUME_SESSION_ID NOT IN candidates:
      Display: "ERROR: Session ID không hợp lệ"
      STOP (exit 2)
  ELSE:
    RESUME_SESSION_ID="${candidates[0]}"

  # 4) Set SESSION_DIR + kiểm tra checkpoint
  SESSION_DIR="$SESSIONS_DIR/$RESUME_SESSION_ID"
  SESSION_ID="$RESUME_SESSION_ID"

  IF NOT test -s "$SESSION_DIR/checkpoint.json":
    Display: "⚠️ checkpoint.json không tồn tại — fallback routing từ diagram-status.json"
    HAS_CHECKPOINT=false
  ELSE:
    HAS_CHECKPOINT=true

  # 5) Load args_snapshot để restore biến session
  IF HAS_CHECKPOINT:
    module=$(jq -r '.args_snapshot.module // ""' "$SESSION_DIR/checkpoint.json")
    source_path=$(jq -r '.args_snapshot.source_path // "."' "$SESSION_DIR/checkpoint.json")
    output_path=$(jq -r '.args_snapshot.output_path // ".mc-data/docs/diagrams"' "$SESSION_DIR/checkpoint.json")
    scope=$(jq -r '.args_snapshot.scope // "full"' "$SESSION_DIR/checkpoint.json")
  ELSE:
    module=$(jq -r '.module // ""' "$SESSION_DIR/diagram-status.json")
    scope=$(jq -r  '.scope  // "full"' "$SESSION_DIR/diagram-status.json")
    source_path="."
    output_path=".mc-data/docs/diagrams"

  Log: "Resuming session: $RESUME_SESSION_ID (module: $module, scope: $scope)"

  # 6) Append trace RESUME (Protocol 15)
  trace_file=".mc-data/work/_trace/session-log.json"
  [ -f "$trace_file" ] || echo '{"entries":[]}' > "$trace_file"
  tmp=$(mktemp)
  jq --arg sid "$SESSION_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.entries += [{"skill":"/wf-diagram","session_id":$sid,"phase":"resume",
                    "event":"RESUME","timestamp":$ts}]' \
     "$trace_file" > "$tmp" && mv "$tmp" "$trace_file"

  # 7) Load intermediate analysis nếu Phase 2+ đã hoàn thành
  [ -s "$SESSION_DIR/analysis.json" ] && ANALYSIS_LOADED=true && Log: "analysis.json loaded"

  # 8) Route đến phase từ checkpoint.next_action.phase
  IF HAS_CHECKPOINT:
    NEXT_PHASE=$(jq -r '.next_action.phase // empty' "$SESSION_DIR/checkpoint.json")
  ELSE:
    # Fallback: phase đầu tiên chưa completed/skipped
    NEXT_PHASE=$(jq -r '
      [.phases | to_entries[] | select(.value.status != "completed" and .value.status != "skipped")] as $p |
      if ($p | length) > 0 then $p[0].key else "phase_7" end
      ' "$SESSION_DIR/diagram-status.json")
    Log: "Routing (fallback): $NEXT_PHASE (từ diagram-status.json)"

  Display: "Resuming /wf-diagram từ $NEXT_PHASE (session: $RESUME_SESSION_ID)"
  GOTO phase theo bảng routing bên dưới
```

---

## Routing Table (CASE B)

| `next_action.phase` | Load procedure |
|---------------------|----------------|
| `phase_0` | `procedures/phase0-setup.md` |
| `phase_1` | `procedures/phase1-precheck.md` |
| `phase_2` | `procedures/phase2-source-analysis.md` |
| `phase_3` | `procedures/phase3-plan.md` |
| `phase_4` | `procedures/phase4-system.md` |
| `phase_5` | `procedures/phase5-module.md` |
| `phase_6` | `procedures/phase6-detail.md` |
| `phase_7` | `procedures/phase7-validation.md` |

---

## CASE C: Fresh run

```
IF HAS_STATUS == "false" && HAS_RESUME == "false":
  # File này không được load — phase0-setup.md tiếp tục thẳng từ Step 0.1
  Continue → phase0-setup.md Step 0.1 (parse args)
```

---

## Next Phase

| Case | Kết quả |
|------|---------|
| CASE A `--status` | STOP |
| CASE B `--resume` | Route theo bảng trên |
| CASE C fresh run | `procedures/phase0-setup.md` (tiếp tục) |
