# Phase 1 Group B — Wave 1 Parallel Discovery (Steps 1.5 + 1.6 + 1.9)

> **Entry condition:** Group A POST-GATE PASS (`$PROFILE`, `$SCOPE` set, helpers sourced).
> **Exit condition:** Wave 1 dispatcher returns + all 3 workers PASS (registry+source+paths valid).
> **Next:** [phase1-init/C-decision.md](C-decision.md) (Decision Resolution).
>
> **Shared protocols cần thiết:**
> - [`_shared/12-ci-detection.md`](../_shared/12-ci-detection.md) — Reference cho CI PRE-GATE behavior
> - [`_shared/13-lock-heartbeat.md`](../_shared/13-lock-heartbeat.md) — KHÔNG dùng ở Wave 1 (defer Group D)
>
> 3 sub-steps độc lập về dữ liệu chạy SONG SONG qua 1 bash tool call. Sub-steps 1.5, 1.6, 1.9 KHÔNG có section riêng — gói trong wave dispatch.

## Input contract (env vars từ Group A)

| Variable | Description |
|----------|-------------|
| `$PROFILE`, `$SCOPE`, `$NAME` | CLI flags parsed |
| Helpers sourced | wf-fix-common.sh |

## Output contract (env vars truyền sang Group C)

| Variable | Set by Worker | Mô tả |
|----------|---------------|------|
| `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$FRESHNESS_STATUS`, `$CI_ROUTE`, `$CI_CONTEXT_FILE`, `$CI_CONTEXT` | W1 (Step 1.5) | CI detection results |
| `$REGISTRY_VALID`, `$REQ_COUNT`, `$SOURCE_VALID`, `$SOURCE_DIR`, `$LEGACY_MODE`, `$INTERFACE_TYPE` | W2 (Step 1.6) | Registry + source + LEGACY |
| `$PATHS_OK`, `$PATHS_MISSING_COUNT`, `$PATHS_CACHED` | W3 (Step 1.9) | Sub-skill paths validation |
| `$WAVE1_DURATION_MS` | All | Telemetry |

---

## Wave 1: Parallel Discovery (Steps 1.5 + 1.6 + 1.9 — gộp v10.12.0)

> **v10.12.0 optimization:** 3 sub-steps độc lập về dữ liệu (CI PRE-GATE, Registry+Source+LEGACY, Sub-skill paths) dispatch PARALLEL qua wrapper. Giảm 1 bash tool call + tận dụng I/O parallel (~50% nhanh hơn vs sequential).

### Thực thi (1 bash call → 3 parallel workers internally)

```bash
# Wrapper dispatch — trả env-style stdout (eval-friendly)
eval "$(bash .claude/scripts/wf-fix-bugs/phase1-wave1-dispatch.sh)"
WAVE1_EXIT=$?

# Sau eval: các env vars sau đã set
# Worker 1 CI PRE-GATE (Step 1.5):   $GITNEXUS_AVAILABLE, $SERENA_AVAILABLE,
#                                     $FRESHNESS_STATUS, $CI_ROUTE, $CI_CONTEXT_FILE
# Worker 2 Registry+Source+LEGACY:   $REGISTRY_VALID, $REQ_COUNT, $SOURCE_VALID,
#                                     $SOURCE_DIR, $LEGACY_MODE, $INTERFACE_TYPE
# Worker 3 Sub-skill paths:          $PATHS_OK, $PATHS_MISSING_COUNT, $PATHS_CACHED
# Telemetry:                         $WAVE1_DURATION_MS
[ -n "$CI_CONTEXT_FILE" ] && CI_CONTEXT=$(cat "$CI_CONTEXT_FILE") || CI_CONTEXT=""
```

### Cache miss → MCP detection (chỉ khi `ci-pregate.sh` báo `needs_scan`)

> ⚠️ MCP tools gọi qua **tool call interface** (`mcp__plugin_gitnexus_gitnexus__query`, `mcp__serena__find_symbol`), KHÔNG phải bash. Sau khi detect xong: `bash .claude/scripts/ci-detect.sh --write-cache "$MCP_RESULT_JSON"` rồi re-run wave1 dispatcher để pick up cache mới.

### VERIFY (per-worker)

```bash
# W1 CI PRE-GATE (Step 1.5)
test -n "$GITNEXUS_AVAILABLE" && test -n "$SERENA_AVAILABLE"
echo "CI_ROUTE=$CI_ROUTE (primary=có CI, fallback=Grep/Glob)"

# W2 Registry + Source + LEGACY (Step 1.6)
test "$REGISTRY_VALID" = "true" || echo "FAIL: Registry invalid"
test "$SOURCE_VALID" = "true" || echo "FAIL: Source code missing"
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json
echo "LEGACY_MODE=$LEGACY_MODE INTERFACE_TYPE=$INTERFACE_TYPE SOURCE_DIR=$SOURCE_DIR"

# W3 Sub-skill paths (Step 1.9)
test "$PATHS_MISSING_COUNT" -eq 0 || echo "FAIL: $PATHS_MISSING_COUNT sub-skill paths missing"
echo "PATHS_OK=$PATHS_OK (cached=$PATHS_CACHED)"

# Telemetry
echo "Wave 1 duration: ${WAVE1_DURATION_MS}ms (parallel)"
```

### Xử lý lỗi (priority cao→thấp)

| Lỗi | Code | Worker | Hành động |
|------|------|--------|-----------|
| req-registry.json không tồn tại / 0 requirements | E003 | W2 | STOP — hướng dẫn `/wf-brainstorm` |
| Không tìm thấy source code | E003 | W2 | STOP — kiểm tra `src/` hoặc `apps/` |
| ≥1 sub-skill SKILL.md missing | E004 | W3 | STOP — kiểm tra installation, list `$PATHS_MISSING_COUNT` |
| CI detection fail | E014 | W1 | WARN — graceful degrade Grep/Glob (`CI_ROUTE=fallback`), pipeline tiếp tục |
| CI index severe stale | E016 | W1 | WARN — fallback Grep |

### Sub-skill paths cache (Layer 3)

Worker 3 dùng cache 24h tại `~/.cache/mcv3-fix-bugs/skill-paths-{md5}.json` — paths hầu như immutable, cache hit ~10ms vs 13 syscalls.

---

## Group B POST-GATE Verify

```bash
[ "$WAVE1_EXIT" -eq 0 ] && \
[ "$REGISTRY_VALID" = "true" ] && \
[ "$SOURCE_VALID" = "true" ] && \
[ "$PATHS_MISSING_COUNT" -eq 0 ] && \
  echo "Group B PASS" || echo "Group B FAIL"
```

## Next Group

→ Group C Decision Resolution — đọc [`phase1-init/C-decision.md`](C-decision.md)
