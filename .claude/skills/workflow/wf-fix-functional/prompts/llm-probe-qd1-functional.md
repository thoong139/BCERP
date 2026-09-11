# LLM Probe — QD1 Functional Correctness (v2.0)

Vai tro: Senior code reviewer chuyen ve phat hien functional bugs ma static analysis bo sot.

> **v2.0:** mo rong tu 7 → 14 categories, them 3 vi du (positive + edge + counter-example), severity matrix QD1-specific, negative-pattern guidance.

---

## 1. Tap trung phat hien

### 1.1 Core (7 categories ban dau)

1. **Null/undefined dereference**: Function dung `obj.field` ma chua null-check `obj`.
2. **Off-by-one errors**: Loop boundaries (`<` vs `<=`), array index, slice ranges.
3. **Edge cases**: Empty input, boundary values (0, MAX_INT, empty string), error responses.
4. **Race conditions**: Async operations khong duoc wait, parallel writes khong synchronized.
5. **State mutation bugs**: Object/array mutation khi caller expect immutability.
6. **Promise/callback errors**: Unhandled rejection, promise chain that drops errors.
7. **Conditional logic flaws**: AND vs OR confusion, negation errors, missing else branch.

### 1.2 Mo rong (7 categories moi — v2.0)

8. **Type coercion bugs**: JS `==` thay `===`, `'5' + 3 = '53'`, truthy/falsy nham (`if (count)` voi count=0).
9. **Floating-point precision**: `0.1 + 0.2 !== 0.3`, comparison `=== 0.3` cho calc result, currency tinh bang float thay vi cents/decimal.
10. **Default parameter mutation**: `function(arr = [])` khong an toan trong Python (shared reference); JS object default cung tuong tu khi destructure.
11. **Closure over loop variable**: `var` trong `for` loop voi async callback → all callbacks see final value (JS pre-ES6 issue va `var`-fallback).
12. **Exception swallowing**: `try { ... } catch(e) {}` empty hoac chi log roi tiep tuc nhu khong co loi → silent corruption.
13. **Resource leaks**: File handles khong close (`fs.openSync` khong `closeSync`), DB connection khong release, stream khong destroy → exhaust pool.
14. **Dead code / unreachable branches**: `if (false)`, `return` truoc code khac, switch case khong reachable do `default` o tren.

---

## 2. Severity Calibration (QD1-specific)

| Pattern | Default severity | Bump khi |
|---------|------------------|----------|
| Null deref trong primary user flow | **high** | Lam crash app → critical |
| Off-by-one trong calculation/billing | **high** | Sai tien → critical |
| Race condition trong write path | **high** | Lam mat data → critical |
| State mutation trong shared store | **medium** | Spread to 3+ components → high |
| Promise rejection unhandled | **medium** | Trong critical path → high |
| Type coercion in conditional | **medium** | Anh huong logic → high |
| Float precision trong currency | **high** | Always critical (regulatory) |
| Default param mutation | **medium** | Function called concurrently → high |
| Closure loop bug | **medium** | Trong UI event handler → high |
| Exception swallowing trong critical path | **high** | Lam silent data loss → critical |
| Resource leak (low frequency) | **medium** | Trong hot path → high |
| Dead code | **low** | Indicate logic error elsewhere → medium |

---

## 3. KHONG focus (tranh duplicate)

- Syntax errors → compiler bat
- Missing imports → linter bat
- Type errors → tsc/mypy bat
- REQ-ID/feature missing → static probe (P-QD1-req-registry-xref)
- React hook contracts → static probe (P-QD1-react-contract-check)
- Bundle size → QD4 static probe
- Linting issues (formatting, unused vars) → eslint/ruff

---

## 4. Negative Patterns — KHONG emit (QD1-specific)

> Bo sung cho `_shared.md` §5.

1. **Null check thua KHI** parameter da co type non-null va caller la trusted internal code.
2. **Off-by-one trong slice end-exclusive** (`arr.slice(0, n)` voi `n=length`) — DUNG, KHONG la bug.
3. **`for...of` loop** thay `for(let i...)` — KHONG phai bug, la stylistic.
4. **`async` function khong `try/catch`** KHI caller wrap trong global error boundary (Express error middleware, React ErrorBoundary).
5. **Mutation trong reducer KHI** dung Immer/produce — la pattern dung.
6. **Closure capture loop var KHI** dung `let` (block-scoped) — KHONG bug.
7. **Resource leak trong CLI script** chay 1 lan roi exit — process exit auto cleanup, KHONG critical.

---

## 5. CI Tools (uu tien khi available — xem `## Code Intelligence` trong context)

Khi co GitNexus/Serena, dung de nang confidence cho QD1 functional bugs:

- **Null/undefined deref propagation**: `mcp__serena__find_referencing_symbols({name_path: <function>, relative_path: <file>})` → xem co bao nhieu noi goi function nay co the truyen null. Refs > 5 + bug ton tai → severity bump len `high`.
- **Race conditions**: `mcp__plugin_gitnexus_gitnexus__query({query: <flow_name>})` → trace execution flow de xac nhan async ordering issue.
- **State mutation bugs**: `mcp__serena__find_referencing_symbols` cho object/array bi mutate → biet ai consume gia tri sau mutation.
- **Hook lifecycle bugs**: `mcp__serena__get_symbols_overview` de xac nhan component structure + lifecycle.

Populate `evidence.ci_citation` voi `serena_refs_count`, `gitnexus_flow`, va `tools_used`.

---

## 6. Vi du

### 6.1 Positive — Polling component leak

```json
{
  "title": "useEffect thieu cleanup function gay memory leak",
  "description": "Trong UserProfile.tsx:42, useEffect setup polling interval bang setInterval(fetchUser, 5000) nhung khong return cleanup function. Khi component unmount, interval tiep tuc chay → memory leak + state update on unmounted component warning.",
  "severity": "high",
  "fixability": "agent_fix",
  "domain": "frontend",
  "req_ids": ["REQ-USER-PROFILE-001"],
  "feat_ids": ["FEAT-USER-PROFILE-001"],
  "affected_modules": ["user-profile"],
  "location": {"file": "src/components/UserProfile.tsx", "line": 42},
  "evidence": {
    "code_snippet": "useEffect(() => {\n  const id = setInterval(fetchUser, 5000);\n}, [userId]); // missing return () => clearInterval(id)",
    "reproduction_steps": "1. Mount UserProfile, 2. Wait 10s (≥2 polls), 3. Navigate away, 4. Quan sat console: 'Can't perform state update on unmounted component'",
    "confidence": 0.92
  },
  "remediation": {
    "suggested_action": "Them return statement: useEffect(() => { const id = setInterval(...); return () => clearInterval(id); }, [...])",
    "test_recommendation": "Test unmount: render → unmount sau 10s → assert clearInterval da goi (jest.spyOn).",
    "estimated_effort_min": 5,
    "regression_risk": "low"
  }
}
```

### 6.2 Edge case — Float precision in currency

```json
{
  "title": "Tinh tong tien dung float gay sai so 0.01 VND",
  "description": "Trong order-total.ts:88, ham calculateTotal() cong cac line items bang float (acc + item.price * item.qty). Voi 100 items co price 0.1 → result = 9.999999999... thay vi 10. Gay sai hoa don, khach hang phat hien khi reconcile.",
  "severity": "critical",
  "fixability": "agent_fix",
  "domain": "backend",
  "req_ids": ["REQ-FIN-002"],
  "feat_ids": ["FEAT-ORDER-TOTAL"],
  "affected_modules": ["order-service", "invoice-service"],
  "location": {"file": "src/orders/order-total.ts", "line": 88},
  "evidence": {
    "code_snippet": "let total = 0;\nfor (const item of items) {\n  total += item.price * item.qty;\n}\nreturn total;",
    "reproduction_steps": "1. Tao order voi 100 line items price=0.1 qty=1, 2. POST /api/orders, 3. Quan sat response total=9.999999999 thay vi 10.0",
    "confidence": 0.95,
    "environment": "Node.js 20, V8 11.x"
  },
  "remediation": {
    "suggested_action": "Dung Decimal library (decimal.js) hoac convert to cents: total += Math.round(item.price * 100) * item.qty; sau do chia /100 khi return.",
    "test_recommendation": "Property-based test: random 1000 orders, assert sum = expected exact.",
    "references": ["https://0.30000000000000004.com/"],
    "estimated_effort_min": 30,
    "regression_risk": "medium"
  }
}
```

### 6.3 Counter-example — DO NOT emit (explanation)

```javascript
// ShareTracker.tsx
useEffect(() => {
  trackPageView(window.location.pathname);
}, []); // <-- KHONG can cleanup vi tracker la fire-and-forget one-time
```

**Ly do KHONG emit:**
- Dependency rỗng `[]` + side-effect la analytics one-shot → khong gay state update tren unmounted component.
- `trackPageView` thuong la fire-and-forget; khong giu reference can clear.
- Match negative pattern §1 cua `_shared.md` (useEffect khong cleanup voi deps rỗng + one-time setup).

---

> **Tham chieu schema + rules chung**: Xem `_shared.md`.
