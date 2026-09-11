# §9 Context & Checkpoint (CORE-038)

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục |
| 65-80% | Chuẩn bị checkpoint (prep_checkpoint) |
| 80-90% | Lưu checkpoint + STOP sau phase hiện tại, hướng dẫn `--resume` |
| > 90% | FORCE STOP (E009) — checkpoint bắt buộc, không advance |

Checkpoint files: `fix-status.json` + `session-log.json` + current `Phase{N}-report.md`.

## Canonical Helper: `_context_budget_check()`

Áp dụng tại các điểm context spike cao: Phase 4 monitor, Phase 5 agent spawn, Phase 6 agent spawn, Phase 7 generate reports.

```bash
# _context_budget_check <phase_num> [<step_id>]
# Đọc context % từ env MCV3_CONTEXT_PCT (orchestrator set), trả về:
#   0 = OK (< 65%)
#   1 = PREP_CHECKPOINT (65-80%)
#   2 = STOP_AFTER_PHASE (80-90%)
#   3 = FORCE_STOP_E009 (>90%) — orchestrator phải exit
_context_budget_check() {
  local phase="$1" step="${2:-unknown}"
  local pct="${MCV3_CONTEXT_PCT:-0}"
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [ "$pct" -ge 90 ]; then
    echo "E009: Context > 90% — FORCE STOP @phase${phase} step ${step}" >&2
    # Append CHECKPOINT event
    jq --arg ts "$ts" --argjson p "$phase" --arg s "$step" --argjson pct "$pct" \
       '.events += [{phase:("phase"+($p|tostring)), event:"CHECKPOINT", timestamp:$ts, step:$s, context_pct:$pct, reason:"force_stop_E009"}]' \
       "$SESSION_DIR/session-log.json" > "$SESSION_DIR/session-log.json.tmp.$$" \
      && mv "$SESSION_DIR/session-log.json.tmp.$$" "$SESSION_DIR/session-log.json" 2>/dev/null || true
    return 3
  elif [ "$pct" -ge 80 ]; then
    echo "WARN: Context $pct% (80-90%) — STOP sau phase${phase}, dùng --resume để tiếp tục" >&2
    return 2
  elif [ "$pct" -ge 65 ]; then
    echo "INFO: Context $pct% (65-80%) — chuẩn bị checkpoint @phase${phase} step ${step}" >&2
    return 1
  fi
  return 0
}
```

**Usage cho caller:**

```bash
_context_budget_check 5 "5.5" || rc=$?
case "${rc:-0}" in
  3) exit 9 ;;        # E009 FORCE STOP
  2) STOP_FLAG=true ;; # Lưu state, finish phase rồi STOP
  1) ;;                # WARN only, tiếp tục
  0) ;;                # OK
esac
```
