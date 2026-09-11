# Playwright Runner — Invocation Procedure (v8.2.0)

## Mục đích

Đây là entry point cho **Playwright Orchestrator** — xử lý queue tuần tự, trả kết
quả về cho các session đang chờ. Được gọi bởi:

```bash
# Từ wf-e2e-batch với flag --run-queue
/wf-e2e-batch --run-queue [--feat=FEAT-xxx]

# Hoặc standalone (xử lý toàn bộ queue)
/wf-playwright-runner

# Hoặc từ wf-e2e-batch phase3-execute.md cuối pipeline nếu có queued jobs
```

---

## PRE-GATE

```bash
# P1: Playwright MCP available?
PLAYWRIGHT_OK=$(jq -r '.checks.playwright_mcp.status // "unknown"' \
  "$SESSION_DIR/infra-blockers.json" 2>/dev/null || echo "unknown")

if [ "$PLAYWRIGHT_OK" != "ok" ]; then
  echo "❌ STOP: Playwright MCP không available (E013)"
  echo "   Restart Claude Code với Playwright MCP plugin, rồi chạy lại"
  exit 1
fi

# P2: Queue file tồn tại và có pending jobs?
QUEUE=".mc-data/work/playwright-queue/queue.json"
PENDING=$(jq -r '[.jobs[] | select(.status=="pending")] | length' "$QUEUE" 2>/dev/null || echo "0")

if [ "$PENDING" -eq 0 ]; then
  echo "ℹ️  Không có pending Playwright jobs trong queue"
  playwright_queue_status
  exit 0
fi

# P3: Không có running job đang bị treo > 30 min
STALE=$(jq -r --arg threshold "$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '[.jobs[] | select(.status=="running" and .started_at < $threshold)] | length' \
  "$QUEUE" 2>/dev/null || echo "0")

if [ "$STALE" -gt 0 ]; then
  echo "⚠️  Phát hiện $STALE stale running job(s) (> 30 min) — auto-reset to pending"
  jq --arg threshold "$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)" '
    (.jobs[] | select(.status=="running" and .started_at < $threshold)) |= . + {
      status: "pending", started_at: null,
      error: "stale-reset: was running > 30min without completion"
    }
  ' "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
fi
```

---

## Execution

```bash
# Load queue functions
source .claude/skills/workflow/wf-e2e-batch/procedures/playwright-queue.md

# Optional: filter theo --feat flag
if [ -n "${TARGET_FEAT:-}" ]; then
  echo "🎯 Filter: chỉ xử lý jobs cho ${TARGET_FEAT}"
  # process_playwright_queue sẽ skip jobs không match
fi

echo "=== Playwright Queue Runner Start ==="
playwright_queue_status
echo ""

# Process all pending jobs sequentially
process_playwright_queue

echo ""
echo "=== Playwright Queue Runner Done ==="
playwright_queue_status
```

---

## POST-GATE

```bash
# Kiểm tra: tất cả jobs đã done hoặc failed (không còn pending/running)?
REMAINING=$(jq -r '[.jobs[] | select(.status=="pending" or .status=="running")] | length' "$QUEUE" 2>/dev/null || echo "0")

if [ "$REMAINING" -gt 0 ]; then
  echo "⚠️  $REMAINING job(s) chưa xử lý xong — runner có thể bị interrupt"
  echo "   Chạy lại /wf-playwright-runner để tiếp tục"
fi

# Tóm tắt sessions cần --resume
echo ""
echo "=== Sessions cần --resume ==="
jq -r '.jobs[] | select(.status=="done" or .status=="failed") | "\(.session_id) [\(.feat_id)/\(.step)] → \(.status)"' \
  "$QUEUE" 2>/dev/null | sort -u || echo "(không có)"

echo ""
echo "Lệnh resume:"
jq -r '.jobs[] | select(.status=="done" or .status=="failed") | .session_id' \
  "$QUEUE" 2>/dev/null | sort -u | while read sid; do
  feat=$(jq -r --arg s "$sid" '.jobs[] | select(.session_id==$s) | .feat_id' "$QUEUE" 2>/dev/null | head -1)
  echo "  /wf-e2e-verify $feat --session=$sid --resume"
done
```

---

## Phase Report

```
## Playwright Runner — DONE
Thời gian: {ISO-8601}
**Đã làm:** Xử lý {N} Playwright jobs từ queue tuần tự. {Done} done, {Failed} failed.
**Kết quả:** Results ghi vào playwright-results/{step}/ trong từng session directory.
**Tiếp theo:** Chạy --resume cho {K} session(s) để load results và hoàn tất pipeline.
```
