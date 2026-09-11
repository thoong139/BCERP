# F0a wf-e2e-finding — Resume & Status Handlers

## --status Handler

```bash
handle_status() {
  # Tìm session
  if [ -n "${SESSION_ARG:-}" ]; then
    SESSION_DIR=".mc-data/work/wf-e2e-verify/sessions/${SESSION_ARG}"
  else
    SESSION_DIR=$(ls -td ".mc-data/work/wf-e2e-verify/sessions/${FEAT_ID}-"* 2>/dev/null | head -1)
  fi

  if [ -z "$SESSION_DIR" ] || [ ! -d "$SESSION_DIR" ]; then
    echo "Không có session nào cho $FEAT_ID"
    exit 0
  fi

  STATUS="$SESSION_DIR/status.json"
  if [ ! -f "$STATUS" ]; then
    echo "Session tồn tại nhưng status.json không tìm thấy: $SESSION_DIR"
    exit 0
  fi

  SESSION_ID=$(jq -r '.session_id' "$STATUS")
  CURRENT_PHASE=$(jq -r '.current_phase' "$STATUS")
  OVERALL=$(jq -r '.overall_status' "$STATUS")
  NEXT=$(jq -r '.next_action' "$STATUS")
  CONTEXT_PCT=$(jq -r '.context_estimate_pct' "$STATUS")

  echo "=========================================="
  echo "wf-e2e-finding (F0a) — Status Dashboard"
  echo "Session: $SESSION_ID"
  echo "FEAT-ID: $FEAT_ID"
  echo "=========================================="
  echo ""
  echo "Trạng thái tổng thể: $OVERALL"
  echo "Phase hiện tại: $CURRENT_PHASE / 5"
  echo "Context estimate: ${CONTEXT_PCT}%"
  echo ""
  echo "Phase Progress:"
  jq -r '.phases | to_entries[] | "  \(.key): \(.value.status)"' "$STATUS"
  echo ""

  # Kiểm tra findings tồn tại
  FINDINGS_DIR="$SESSION_DIR/findings"
  echo "Finding Files:"
  for F in business-understanding.md business-rule-catalog.md state-machine.md cross-module-map.md \
            db-mapping.md db-seed-data.md api-mapping.md ui-mapping.md finding-summary.md; do
    if [ -f "$FINDINGS_DIR/$F" ]; then
      SIZE=$(wc -c < "$FINDINGS_DIR/$F")
      echo "  $F: OK (${SIZE} bytes)"
    else
      echo "  $F: MISSING"
    fi
  done
  echo ""

  echo "SSOT JSONs:"
  for J in issues.json block-test.json implement-required.json manual.json; do
    if [ -f "$SESSION_DIR/$J" ]; then
      echo "  $J: OK (init rỗng)"
    else
      echo "  $J: MISSING"
    fi
  done
  echo ""
  echo "Hành động tiếp theo: $NEXT"
  echo "=========================================="
  exit 0
}
```

---

## --resume Handler

```bash
handle_resume() {
  # Resolve session (từ _shared.md)
  resolve_session

  STATUS="$SESSION_DIR/status.json"
  if [ ! -f "$STATUS" ]; then
    echo "ERROR: status.json không tồn tại — không thể resume"
    exit 1
  fi

  # Acquire lock
  LOCK="$SESSION_DIR/.lock"
  acquire_lock

  # Detect phase để resume
  CURRENT_PHASE=$(jq -r '.current_phase' "$STATUS")
  OVERALL=$(jq -r '.overall_status' "$STATUS")

  echo "Resume session: $SESSION_ID (phase $CURRENT_PHASE, status: $OVERALL)"

  if [ "$OVERALL" = "completed" ]; then
    echo "Session đã hoàn tất. Dùng --status để xem kết quả."
    exit 0
  fi

  # Re-validate output phase trước khi resume
  case "$CURRENT_PHASE" in
    1) # Resume tại P1: không cần validate gì thêm (P0 đã done)
       RESUME_FROM="phase1-business"
       ;;
    2) # Resume tại P2: validate P1 outputs
       for F in business-understanding.md business-rule-catalog.md state-machine.md cross-module-map.md; do
         test -f "$SESSION_DIR/findings/$F" || {
           echo "ERROR: $F thiếu — cần re-run từ P1"
           RESUME_FROM="phase1-business"
           break
         }
       done
       RESUME_FROM="${RESUME_FROM:-phase2-db-mapping}"
       ;;
    3) # Resume tại P3: validate P2 outputs
       test -f "$SESSION_DIR/findings/db-mapping.md" || RESUME_FROM="phase2-db-mapping"
       RESUME_FROM="${RESUME_FROM:-phase3-api-mapping}"
       ;;
    4) # Resume tại P4: validate P3 outputs
       test -f "$SESSION_DIR/findings/api-mapping.md" || RESUME_FROM="phase3-api-mapping"
       RESUME_FROM="${RESUME_FROM:-phase4-ui-mapping}"
       ;;
    5) # Resume tại P5: validate P4 outputs
       test -f "$SESSION_DIR/findings/ui-mapping.md" || RESUME_FROM="phase4-ui-mapping"
       RESUME_FROM="${RESUME_FROM:-phase5-completion}"
       ;;
    *) RESUME_FROM="phase0-setup" ;;
  esac

  echo "Resume từ procedure: $RESUME_FROM"
  log_event "RESUME" "$RESUME_FROM" "Resume session $SESSION_ID"

  # Route đến procedure phù hợp
  source "procedures/$RESUME_FROM.md"
}
```

---

## --phase= Override

```bash
handle_phase_override() {
  local TARGET_PHASE="$1"

  case "$TARGET_PHASE" in
    0) RESUME_FROM="phase0-setup" ;;
    1) RESUME_FROM="phase1-business" ;;
    2) RESUME_FROM="phase2-db-mapping" ;;
    3) RESUME_FROM="phase3-api-mapping" ;;
    4) RESUME_FROM="phase4-ui-mapping" ;;
    5) RESUME_FROM="phase5-completion" ;;
    *)
      echo "ERROR: --phase phải là 0-5 (nhận được: $TARGET_PHASE)"
      exit 1
      ;;
  esac

  echo "WARN: --phase=$TARGET_PHASE override — bỏ qua auto-detect"
  log_event "PHASE_OVERRIDE" "$RESUME_FROM" "User force phase $TARGET_PHASE"
}
```
