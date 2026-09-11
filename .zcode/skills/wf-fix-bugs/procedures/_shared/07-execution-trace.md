# §7 Execution Trace (CORE-026)

> Mọi phase ghi START/COMPLETE/FAIL events vào **HAI** session log.
> CORE-026: output-only — KHÔNG đọc lại file này làm input context.

```
EVENT FORMAT:
{
  "timestamp": "ISO-8601",
  "skill": "wf-fix-bugs",
  "phase": "1-7",
  "event": "START|COMPLETE|FAIL|CHECKPOINT",
  "duration_ms": 0,
  "metadata": {}
}

WHEN TO WRITE:
- START: ngay sau PRE-GATE pass, trước Step đầu tiên
- COMPLETE: ngay sau POST-GATE pass
- FAIL: trong On Failure flow §3.b
- CHECKPOINT: sau mỗi milestone quan trọng

PATTERN (atomic append — dual-write, schema session-log-v1):
GLOBAL_TRACE=".mc-data/work/_trace/session-log.json"
SESSION_TRACE="${SESSION_DIR}/session-log.json"

mkdir -p "$(dirname "$GLOBAL_TRACE")"
for TARGET in "$GLOBAL_TRACE" "$SESSION_TRACE"; do
  [ ! -s "$TARGET" ] && echo '{"skill":"wf-fix-bugs","events":[]}' > "$TARGET"
  TMP="${TARGET}.tmp.$$"
  jq --arg ts "$(date -Iseconds)" --arg ph "$PHASE" --arg ev "START" \
     '.events += [{timestamp:$ts, skill:"wf-fix-bugs", phase:$ph, event:$ev}]' \
     "$TARGET" > "$TMP" && mv "$TMP" "$TARGET"
done
```
