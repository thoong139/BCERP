# Procedure: --status & --resume Handlers — wf-implement-feature

> Tách từ SKILL.md (compliance ≤500 dòng). Logic handler đầy đủ:

## --status Handler

```
IF $ARGUMENTS chứa "--status":
  → Derive FEATURE_SLUG (xem "FEATURE_SLUG Derivation" bên dưới)
  → Auto-migrate (idempotent chain v3→v4→v5):
      bash .claude/scripts/wf-implement-feature/implement-migrate-v3-to-v4.sh
      bash .claude/scripts/wf-implement-feature/implement-migrate-v4-to-v5.sh
  → Derive SYSTEM_SLUG (v5.0):
      source .claude/scripts/wf-implement-feature/implement-common.sh
      SYSTEM_SLUG=$(derive_system_slug "$FEAT_ID_OR_SLUG" "$SYSTEM_OVERRIDE")
      # SYSTEM_OVERRIDE = parsed từ --system=<slug>; empty → auto-derive
  → SESSION_DIR resolution (v5.0):
      FEATURE_DIR=$(get_feature_dir "$SYSTEM_SLUG" "$FEATURE_SLUG")
      IF test -f "$FEATURE_DIR/current.txt":
        REL=$(cat "$FEATURE_DIR/current.txt")
        SESSION_DIR="$FEATURE_DIR/$REL"
      ELIF test -d "$FEATURE_DIR/sessions":
        NEWEST=$(ls -1 "$FEATURE_DIR/sessions" | sort -r | head -1)
        SESSION_DIR="$FEATURE_DIR/sessions/$NEWEST"
      ELSE:
        # Có thể feature đã bị move vào _orphan (system không match registry)
        ORPHAN_DIR="$FEATURE_BASE_DIR/_orphan/$FEATURE_SLUG"
        IF test -d "$ORPHAN_DIR/sessions":
          SESSION_DIR="$ORPHAN_DIR/sessions/$(ls -1 $ORPHAN_DIR/sessions | sort -r | head -1)"
  IF test -f $SESSION_DIR/impl-status.json:
    → Hiển thị tiến độ từ impl-status.json → STOP
  ELSE:
    → "Chưa có session nào cho feature này." → STOP
```

## --resume Handler

```
IF $ARGUMENTS chứa "--resume":
  → Derive FEATURE_SLUG (xem "FEATURE_SLUG Derivation" bên dưới)
  → Auto-migrate (idempotent chain v3→v4→v5):
    bash .claude/scripts/wf-implement-feature/implement-migrate-v3-to-v4.sh
    bash .claude/scripts/wf-implement-feature/implement-migrate-v4-to-v5.sh
  → Derive SYSTEM_SLUG (parse --system=<slug> OR auto-derive từ registry):
    source .claude/scripts/wf-implement-feature/implement-common.sh
    SYSTEM_OVERRIDE=$(echo "$ARGUMENTS" | grep -oP -- '--system=\K[^ ]+' || echo "")
    SYSTEM_SLUG=$(derive_system_slug "$FEAT_ID_OR_SLUG" "$SYSTEM_OVERRIDE")
  → SESSION_DIR=$(resolve_session_dir "$SYSTEM_SLUG" "$FEATURE_SLUG" "true")
  IF test -f $SESSION_DIR/checkpoint.json:
    → Load checkpoint
    → IF $ARGUMENTS chứa "--features": Load procedures/flow-multi.md → resume
    → ELSE: Tiếp tục Phase Orchestration từ checkpoint.next_action (phase file phù hợp)
  ELIF test -f $SESSION_DIR/impl-status.json \
       && jq -e '.status | IN("in_progress","paused","error")' \
          $SESSION_DIR/impl-status.json >/dev/null:
    # A2-M1 soft-resume fallback: checkpoint.json chưa tạo (crash trước Phase 3 TDD) nhưng
    # impl-status.json có state resumable. Resume từ current_phase thay vì hard-stop.
    → Load impl-status.json → extract `current_phase` (default: phase_1_context)
    → Hiển thị: "Soft resume từ impl-status.json (checkpoint.json chưa tồn tại). Phase khởi đầu: $CURRENT_PHASE"
    → AskUserQuestion:
        (a) Continue từ $CURRENT_PHASE (khuyến nghị)
        (b) Restart từ Phase 0 (lost Phase 1-2 context)
        (c) Abort
    → continue → goto Phase $CURRENT_PHASE
    → restart → set impl-status.json status="not_started", proceed as fresh
    → abort → STOP
  ELSE:
    → "Không tìm thấy checkpoint.json và impl-status.json không có state resumable. Chạy lại từ đầu." → STOP
```

---

## --resume Handler

```
IF $ARGUMENTS chứa "--resume":
  → Derive FEATURE_SLUG (xem "FEATURE_SLUG Derivation" bên dưới)
  → Auto-migrate (idempotent chain v3→v4→v5):
    bash .claude/scripts/wf-implement-feature/implement-migrate-v3-to-v4.sh
    bash .claude/scripts/wf-implement-feature/implement-migrate-v4-to-v5.sh
  → Derive SYSTEM_SLUG (parse --system=<slug> OR auto-derive từ registry):
    source .claude/scripts/wf-implement-feature/implement-common.sh
    SYSTEM_OVERRIDE=$(echo "$ARGUMENTS" | grep -oP -- '--system=\K[^ ]+' || echo "")
    SYSTEM_SLUG=$(derive_system_slug "$FEAT_ID_OR_SLUG" "$SYSTEM_OVERRIDE")
  → SESSION_DIR=$(resolve_session_dir "$SYSTEM_SLUG" "$FEATURE_SLUG" "true")
  IF test -f $SESSION_DIR/checkpoint.json:
    → Load checkpoint
    → IF $ARGUMENTS chứa "--features": Load procedures/flow-multi.md → resume
    → ELSE: Tiếp tục Phase Orchestration từ checkpoint.next_action (phase file phù hợp)
  ELIF test -f $SESSION_DIR/impl-status.json \
       && jq -e '.status | IN("in_progress","paused","error")' \
          $SESSION_DIR/impl-status.json >/dev/null:
    # A2-M1 soft-resume fallback: checkpoint.json chưa tạo (crash trước Phase 3 TDD) nhưng
    # impl-status.json có state resumable. Resume từ current_phase thay vì hard-stop.
    → Load impl-status.json → extract `current_phase` (default: phase_1_context)
    → Hiển thị: "Soft resume từ impl-status.json (checkpoint.json chưa tồn tại). Phase khởi đầu: $CURRENT_PHASE"
    → AskUserQuestion:
        (a) Continue từ $CURRENT_PHASE (khuyến nghị)
        (b) Restart từ Phase 0 (lost Phase 1-2 context)
        (c) Abort
    → continue → goto Phase $CURRENT_PHASE
    → restart → set impl-status.json status="not_started", proceed as fresh
    → abort → STOP
  ELSE:
    → "Không tìm thấy checkpoint.json và impl-status.json không có state resumable. Chạy lại từ đầu." → STOP
```
