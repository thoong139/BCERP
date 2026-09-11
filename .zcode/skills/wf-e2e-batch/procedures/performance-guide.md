# Performance Optimization Guide (Tier 7)

## P2: Playwright Worker Pool Native

```
CONFIG trong playwright.config.ts:
  workers: process.env.CI ? 4 : Math.max(cpus().length - 1, 1)

PER-FEAT PORT MAPPING:
  FIN-001: BE=5048, FE=3000
  FIN-002: BE=5049, FE=3001
  ...

KHÔNG share Playwright MCP giữa FEATs — mỗi FEAT có worker riêng
```

## P3: Resource-Aware Dispatcher

```bash
get_available_slot():
  # Check CPU + memory
  cpu_usage=$(top -bn1 | grep '%Cpu' | awk '{print $2}' | tr -d '%' 2>/dev/null || echo "50")
  mem_available=$(free -m 2>/dev/null | grep Mem | awk '{print $7}' || echo "2048")

  # Nếu CPU > 80% hoặc memory < 1GB → wait
  if [ "${cpu_usage%.*}" -gt 80 ] || [ "$mem_available" -lt 1024 ]; then
    echo "WAIT"
    return
  fi
  echo "OK"

Phase pipelining:
  Light phases (F0/F0a): 5 parallel (CPU-bound, ít I/O)
  Heavy phases (F1-F8): 2-3 parallel (Playwright, DB, agent-heavy)
```

## P4: Phase Pipelining

```
LEVEL 1 — Light (5 parallel):
  F0 infra check: bash-only, cực nhanh
  F0a finding: code scan, no network

LEVEL 2 — Medium (3 parallel):
  F1 test: DB + API calls
  F2 browser: Playwright

LEVEL 3 — Heavy (2 parallel):
  F7 scenario: Playwright full
  F8 demo: Playwright + screenshots
```

## P5: Aggressive Caching

```
CACHE KEYS:
  Registry reads: TTL 5 min
  Feature spec files: TTL 10 min (invalidate on git change)
  CI detect (Serena/GitNexus): TTL 24h available, 4h absent

CACHE LOCATIONS:
  .mc-data/work/_meta/code-intelligence.json (CI tools cache)
  .mc-data/work/_meta/registry-cache.json (registry reads)
```

## P6: Async I/O Pattern

```
Principles:
- Đọc nhiều files cùng lúc (parallel Glob)
- Ghi atomic (tmp → mv), không block
- Agent spawns: parallel khi có thể (CORE-037)
- Database queries: use connection pool, không per-query connect
```

## P7: Profiling Feedback Loop

```
Sau go-live: thu thập metrics từ session-log.json
  - Top 5 phases chậm nhất (average runtime)
  - Top 3 agents spawn nhiều nhất
  - Cache hit rate

Iterate: tăng cache TTL, tăng parallelism cho phases consistently fast
```

## P8: Lock Granularity Reduction

```
TRƯỚC: 1 global lock per FEAT session
SAU: Granular locks per output file
  - issues.json.lock — chỉ lock khi append
  - implement-required.json.lock — chỉ lock khi append
  - e2e-status.json.lock — chỉ lock khi update step status

Lock timeout: 30s (giảm từ 60s)
Stale detection: 5 min (giảm từ 30 min)
```

## Target: 5 FEAT Parallel ≤2h

```
Conservative path (CF7 + CF8):
  - Simple FEAT: ~25-30 min
  - Complex FEAT với deps: ~60-75 min
  - Batch 5 FEATs (2 parallel max): ~2-2.5h

Note: Dep nặng (A→B→C chain) vẫn 4-5h nếu tất cả serial deps.
User nên plan upstream FEAT chạy trước batch để đạt 2h target.
```
