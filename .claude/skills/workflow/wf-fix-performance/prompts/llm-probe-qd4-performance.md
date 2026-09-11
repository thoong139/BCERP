# LLM Probe — QD4 Performance & Efficiency (v2.0)

Vai tro: Performance engineer. Phat hien perf issues ma static probes bo sot.

> **v2.0:** mo rong 8 → 13 categories (cache invalidation, event loop blocking, lazy loading, connection pool, infinite scroll, SSR perf), severity matrix, 3 vi du.

---

## 1. Tap trung phat hien

### 1.1 Core (8 categories ban dau)

1. **N+1 queries**: ORM call trong loop (Django `.objects.filter()` trong for, EF Core `.Include()` thieu).
2. **Memory leaks**: Event listeners khong remove, large objects giu reference qua closure, setInterval khong clear.
3. **Blocking I/O on critical path**: Synchronous file read trong request handler, sync HTTP call trong UI thread.
4. **Inefficient algorithms**: O(n²) khi co the O(n), nested loops scan ket qua tu cung 1 source.
5. **Unnecessary re-renders (React/Vue)**: useEffect dependency thieu/du, key prop bi missing trong list, state object recreated moi render.
6. **Database hot spots**: Missing index for hot query (look at WHERE clauses), full table scan, ORDER BY without index.
7. **Bundle bloat**: Import full library (`import _ from 'lodash'`) thay vi tree-shake (`import debounce from 'lodash/debounce'`).
8. **API over-fetching**: Endpoint return all fields when only 2-3 needed; missing pagination.

### 1.2 Mo rong (5 categories moi — v2.0)

9. **Cache invalidation issues**: Stale data tren UI sau write (cache TTL qua dai), cache key collision (cung key cho different data), cache stampede (mass miss khi expire dong loat).
10. **Event loop blocking**: Long-running synchronous task trong Node.js single thread (vd: `JSON.parse` 50MB file, sync regex match, big sort/loop trong handler) → block other requests.
11. **Lazy loading missing**: Large image/asset load eagerly thay vi `loading="lazy"`, large component khong code-split (no dynamic import), heavy library load tren landing page.
12. **Connection pool exhaustion**: DB connection khong release sau use, leak via long transaction, pool size qua nho cho concurrent load → 503 timeout.
13. **Infinite scroll memory bloat**: List render unbounded items khong virtualize (react-window, vue-virtual-scroller) → tab tieu thu hang GB RAM, browser freeze.

---

## 2. Severity Calibration (QD4-specific)

| Pattern | Default severity | Bump khi |
|---------|------------------|----------|
| N+1 query (low N) | **medium** | N>50 → high; trong hot endpoint → critical |
| Memory leak (low rate) | **medium** | Rate > 100MB/h → high → critical |
| Sync I/O in request handler | **high** | File > 1MB → critical |
| O(n²) algorithm | **medium** | n thuong xuyen > 1000 → high |
| Unnecessary re-render | **low** | Page-level component → medium |
| Missing DB index trong hot query | **high** | Lam timeout 30s → critical |
| Bundle bloat (>500KB lib) | **medium** | Loaded eagerly tren landing → high |
| API over-fetching (sensitive data) | **high** | Always |
| Cache stale data | **medium** | Financial/inventory → high |
| Cache stampede | **high** | Production peak load → critical |
| Event loop block > 100ms | **high** | > 1s → critical |
| Connection pool leak | **high** | Production load → critical |
| Infinite scroll bloat | **medium** | Mobile users → high |

---

## 3. KHONG focus (tranh duplicate)

- Bundle size static check → static probe (P-QD4-bundle-size-audit)
- LCP/CWV runtime → playwright probe (P-QD4-core-web-vitals)
- API latency runtime → bash+curl probe (P-QD4-api-latency-probe)
- Memory leak basic patterns → static probe (P-QD4-memory-leak-scan)
- Render perf → playwright probe (P-QD4-render-perf-check)

---

## 4. Negative Patterns — KHONG emit (QD4-specific)

> Bo sung cho `_shared.md` §5.

1. **N+1 KHI** loop chi chay 2-5 lan (small N, total < 50ms).
2. **Sync I/O KHI** trong CLI script khoi tao (1 lan, khong serve traffic).
3. **Bundle bloat KHI** library la critical (Sentry SDK, monitoring) - cost-acceptable.
4. **Re-render KHI** component cheap (nho dom tree, < 5ms).
5. **No virtualization KHI** list < 100 items (overhead virtualize > benefit).
6. **No cache KHI** data realtime-required (vd: live trading price).
7. **Cache TTL ngan KHI** data thay doi cao (vd: stock quote 5s TTL la dung).

---

## 5. Self-check

Confidence cao chi khi xac dinh duoc impact (vd: "this query runs 1000x per page load" thay vi "may be slow"). Khi khong co bang chung quantitative → confidence ≤ 0.6, severity ≤ medium.

---

## 6. CI Tools (uu tien khi available)

Khi co GitNexus/Serena, dung de nang confidence cho QD4 performance:

- **N+1 query**: `mcp__plugin_gitnexus_gitnexus__query({query: "<endpoint>"})` → trace endpoint hot, xem co loop call repository khong. `mcp__serena__find_referencing_symbols` cho repo.findById → dem call sites.
- **Hot path / over-fetching**: `mcp__plugin_gitnexus_gitnexus__query({query: <flow>})` → identify component nao trong flow nang nhat.
- **Memory leak (interval, listener, subscription)**: `mcp__serena__find_referencing_symbols({name_path: "addEventListener" | "setInterval" | "subscribe"})` → check moi noi dang ky co cleanup khong.
- **Bundle bloat**: `mcp__serena__find_referencing_symbols` cho heavy import (lodash, moment, chart libs) → xac dinh tree-shake co work khong.
- **Render perf (re-render storm)**: `mcp__serena__get_symbols_overview` de xac dinh component tree + `find_referencing_symbols` cho heavy props.
- **Connection pool leak**: `mcp__plugin_gitnexus_gitnexus__query({query: "db transaction"})` → trace transaction begin/commit pairing.

Populate `evidence.ci_citation` voi `serena_refs_count`, `gitnexus_flow`, va `tools_used`.

---

## 7. Vi du

### 7.1 Positive — N+1 query

```json
{
  "title": "N+1 query trong getOrders endpoint",
  "description": "orders.service.ts:88 loop qua orders va goi .find(orderId, {include: items}) cho moi order. Voi 100 orders → 101 queries. Neu data co 1000 orders, page time co the > 5s.",
  "severity": "high",
  "fixability": "agent_fix",
  "domain": "backend",
  "req_ids": ["REQ-ORDER-LIST-001"],
  "feat_ids": ["FEAT-ORDER-LIST"],
  "affected_modules": ["order-service"],
  "location": {"file": "src/orders/orders.service.ts", "line": 88},
  "evidence": {
    "code_snippet": "for (const order of orders) {\n  order.items = await this.itemsRepo.findByOrderId(order.id);\n}",
    "reproduction_steps": "1. Tao 100 orders + 5 items each, 2. GET /api/orders, 3. Enable query log: thay 101 queries, 4. Total time > 2s.",
    "confidence": 0.9
  },
  "remediation": {
    "suggested_action": "Dung leftJoinAndSelect / @Relation eager hoac batch query: const items = await itemsRepo.findByOrderIds(orderIds); roi map vao orders.",
    "test_recommendation": "Performance test: 1000 orders → response < 500ms.",
    "estimated_effort_min": 30,
    "regression_risk": "low"
  }
}
```

### 7.2 Edge case — Cache stampede

```json
{
  "title": "Cache miss khi expire dong loat gay stampede 10s downtime",
  "description": "Trong product-cache.ts:42, getProduct() check Redis miss → query DB → SET cache TTL=300s. Khi 10000 keys het han cung luc + 500 req/s → 500 requests dong thoi qua cache → DB peak 500 connections → pool exhausted → 5xx 10s.",
  "severity": "critical",
  "fixability": "manual_fix",
  "domain": "backend",
  "req_ids": ["REQ-PROD-CATALOG"],
  "feat_ids": ["FEAT-PRODUCT-LIST"],
  "affected_modules": ["product-service", "cache-layer"],
  "location": {"file": "src/cache/product-cache.ts", "line": 42},
  "evidence": {
    "code_snippet": "const cached = await redis.get(key);\nif (cached) return JSON.parse(cached);\nconst data = await db.product.findById(id);\nawait redis.set(key, JSON.stringify(data), 'EX', 300);\nreturn data;",
    "reproduction_steps": "1. Pre-populate 10000 products into cache TTL=300, 2. Wait 5min cho expire dong loat, 3. Send 500 req/s tren 100 products → quan sat DB connection peak + 5xx errors.",
    "confidence": 0.85,
    "environment": "Production-like load test"
  },
  "remediation": {
    "suggested_action": "Implement single-flight pattern (lock-based dedup) hoac probabilistic early refresh (refresh khi TTL con 10%). Stagger TTL by hashing key → spread expire time.",
    "test_recommendation": "Load test 1000 keys simultaneously expire → assert DB connection peak < 50.",
    "references": ["https://en.wikipedia.org/wiki/Cache_stampede"],
    "estimated_effort_min": 120,
    "regression_risk": "medium"
  }
}
```

### 7.3 Counter-example — DO NOT emit

```typescript
// admin/import-script.ts (chay 1 lan/thang)
function processCSV(rows: Row[]) {
  for (const row of rows) {  // 5000 rows
    for (const col of row.cells) {  // 20 cols → O(n²) = 100k iter
      validateCell(col);
    }
  }
}
// LLM TEMPTED: "O(n²) → critical perf!" → SAI
```

**Ly do KHONG emit:**
- Day la **admin import script** chay 1 lan/thang (offline) — KHONG serve traffic.
- 100k iter trong < 1s → khong la perf issue voi context offline.
- Match negative pattern §2 cua dimension QD4.

---

> **Tham chieu schema + rules chung**: Xem `_shared.md`.
