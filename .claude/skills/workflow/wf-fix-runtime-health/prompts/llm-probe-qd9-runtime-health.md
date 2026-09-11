# LLM Probe — QD9 Runtime Health Verification (v1.0)

Vai tro: Senior QA lead + frontend developer. Phat hien bugs chi thay duoc qua **browser runtime** — console errors, network failures, uncaught exceptions, broken auth flows, SPA routes unreachable, CTAs khong hoat dong, form validation thieu.

> **v1.0 (2026-05-11):** moi-them LLM probe cho QD9. Bo sung cho 7 Playwright-based probes. LLM phan tich code de tim cac pattern gay runtime failure TRUOC khi browser chay — giup giam thoi gian debug.

---

## 1. Tap trung phat hien

### 1.1 Console & Error Boundary

1. **Missing Error Boundary trong React**: Component tree khong co `<ErrorBoundary>` wrapper → 1 component throw → white screen crash toan bo app. Dac biet critical cho SPA.
2. **Unhandled promise rejection**: `async function` goi tu event handler khong `try/catch`, Promise chain khong `.catch()` → `UnhandledPromiseRejectionWarning` trong console → co the crash Node.js process (tuy version).
3. **`console.error` thay vi proper error handling**: Goi `console.error(e)` roi return null thay vi throw/redirect → UI silent fail, user khong biet co loi.
4. **`window.onerror` / `addEventListener('error')` thieu**: Global error handler khong duoc setup → uncaught errors khong duoc report → kho debug production.

### 1.2 Network & API

5. **Fetch/XHR khong check `response.ok`**: `fetch(url).then(r => r.json())` khong check `r.ok` → parse JSON tu 4xx/5xx response → code nhan sai data type → crash sau.
6. **Network error khong retry/handle**: `fetch` fall on network failure (offline, DNS, CORS) → khong co retry logic hoac offline fallback → user thay infinite spinner.
7. **WebSocket reconnect thieu**: WS connection drop → khong reconnect → real-time feature ngung hoat dong, user khong biet.
8. **SSE (Server-Sent Events) reconnect thieu**: EventSource close khong reconnect → live feed ngung.

### 1.3 SPA Navigation & Routing

9. **Route guard thieu/loi**: Protected route khong check auth → redirect loop (login → dashboard → login) hoac white screen khi token expired.
10. **Dynamic import fail khong fallback**: `React.lazy(() => import('./Heavy'))` fail (network, chunk hash mismatch) → khong co `<Suspense fallback>` → white screen.
11. **Route params type mismatch**: `useParams()` tra ve string, code treat as number → `NaN` propagate → UI sai.
12. **Hash/anchor link broken**: `#section` link khong scroll vi element render sau navigate.

### 1.4 User Interaction & CTA

13. **CTA button khong disabled khi loading**: Submit button khong `disabled={isLoading}` → user click 2+ lan → duplicate POST/charge.
14. **Form submit handler khong `preventDefault`**: `onSubmit` handler thieu `e.preventDefault()` → page reload → mat form state.
15. **Debounce/throttle missing cho expensive input**: Search input goi API moi keystroke → 50 req/s → rate limit + lag.
16. **Click-outside handler thieu**: Dropdown/modal khong close khi click outside → UX stuck.

### 1.5 Form & Validation

17. **Client-side validation thieu**: Form chi validate o server → user submit → wait 2s → server reject → UX cham + unnecessary server load.
18. **Conditional field logic broken**: "If payment method = bank-transfer, show bank fields" → toggle logic sai → hidden required fields van validate + block submit.
19. **File input khong validate client-side**: Upload file 50MB → wait upload → server reject → UX cham. Can validate size + type o client.
20. **Form dirty state khong track**: User fill form 5 min → navigate away → khong confirm dialog → mat data.

### 1.6 Browser API & Feature Detection

21. **Browser API thieu feature detection**: `navigator.clipboard`, `navigator.geolocation`, `Notification.requestPermission()` goi truc tiep khong `if ('...' in navigator)` → throw TypeError tren browser cu.
22. **LocalStorage/SessionStorage quota exceeded**: `localStorage.setItem()` khong try/catch → quota exceeded → crash.
23. **`matchMedia` listener khong cleanup**: `window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', ...)` khong remove → memory leak khi component unmount.

---

## 2. Severity Calibration (QD9-specific)

| Pattern | Default severity | Bump khi |
|---------|------------------|----------|
| Missing Error Boundary | **high** | SPA production → critical |
| Unhandled promise rejection | **high** | Payment/auth path → critical |
| console.error thay proper handling | **medium** | Critical user path → high |
| Global error handler thieu | **medium** | Production monitoring → high |
| fetch khong check ok | **high** | Mutation endpoint (POST/PUT/DELETE) → critical |
| Network error khong retry | **medium** | Critical real-time feature → high |
| WebSocket reconnect thieu | **high** | Live trading/chat → critical |
| SSE reconnect thieu | **medium** | Live feed → high |
| Route guard broken | **critical** | Always (auth bypass) |
| Dynamic import fail no fallback | **high** | Landing page → critical |
| Route params type mismatch | **medium** | Calculation path → high |
| CTA khong disabled khi loading | **high** | Payment/submit → critical |
| preventDefault thieu | **high** | Always (form broken) |
| Debounce thieu tren search | **medium** | Autocomplete → high |
| Client validation thieu | **medium** | Multi-field form → high |
| Conditional field logic broken | **high** | Always (block submit) |
| File input no client-side validate | **medium** | Public upload → high |
| Form dirty state khong track | **medium** | Long form (>10 fields) → high |
| Browser API no feature detection | **medium** | Core feature dependency → high |
| LocalStorage quota exceeded | **medium** | Critical data persist → high |
| matchMedia listener leak | **low** | Frequent mount/unmount → medium |

> **Quy tac chung:** Bug gay crash toan bo app → severity floor `high`. Bug gay silent data loss → severity `critical`.

---

## 3. KHONG focus (tranh duplicate)

- Console errors runtime → Playwright probe (P-QD9-console-network-monitor)
- Network failure runtime → Playwright probe (P-QD9-console-network-monitor)
- SPA route 404 → Playwright probe (P-QD9-spa-route-coverage)
- Form validation runtime → Playwright probe (P-QD9-form-validation-smoke)
- Auth flow browser test → Playwright probe (P-QD9-auth-aware-smoke)
- CTA click runtime → Playwright probe (P-QD9-interactive-smoke)
- Dev server start fail → bootstrap probe (P-QD9-dev-server-bootstrap)

---

## 4. Negative Patterns — KHONG emit (QD9-specific)

> Bo sung cho `_shared.md` §5.

1. **WebSocket reconnect thieu KHI** la one-shot data fetch (vd: load initial data roi close) — khong can reconnect.
2. **`preventDefault` thieu KHI** form dung AJAX library tu dong prevent (vd: Axios interceptor, React Hook Form).
3. **Error Boundary thieu KHI** la static landing page khong co React tree.
4. **Client validation thieu KHI** form chi co 1-2 fields + back-end <200ms (UX acceptable).
5. **Feature detection thieu KHI** `browserslist` target >= 95% coverage cho API do.
6. **Debounce thieu KHI** input chi goi backend khi user click Submit (khong search-as-you-type).
7. **`localStorage.setItem` khong try/catch KHI** storage usage < 100KB (far from 5-10MB limit).

---

## 5. CI Tools (uu tien khi available)

Khi co GitNexus/Serena, dung de nang confidence cho QD9:

- **Error Boundary coverage**: `mcp__serena__find_referencing_symbols({name_path: "ErrorBoundary", relative_path})` → dem usage vs component count → coverage estimate.
- **fetch/axios call sites**: `mcp__serena__find_referencing_symbols({name_path: "fetch"})` → check moi call site co check `response.ok` khong.
- **Route guard completeness**: `mcp__plugin_gitnexus_gitnexus__query({query: "protected route"})` → trace middleware chain → confirm moi route co guard.
- **Event handler leak risk**: `mcp__serena__find_referencing_symbols({name_path: "addEventListener"})` → check moi noi co tuong ung `removeEventListener` khong.
- **Browser API usage**: `mcp__serena__find_referencing_symbols` cho `navigator.*`, `localStorage.*`, `matchMedia` → audit feature detection pattern.
- **Unhandled rejection path**: `mcp__plugin_gitnexus_gitnexus__query({query: "async error handling"})` → trace async call chain → confirm catch.

Populate `evidence.ci_citation` voi `serena_refs_count`, `gitnexus_flow`, va `tools_used`.

---

## 6. Vi du

### 6.1 Positive — Missing Error Boundary

```json
{
  "title": "App component tree thieu Error Boundary → 1 component crash → white screen toan bo SPA",
  "description": "Trong App.tsx:15, component tree root khong wrap <ErrorBoundary>. Neu UserAvatar throw (vd: null user object tu cache), toan bo React tree unmount → ngay ca nav bar, footer bien mat. User thay white screen, khong co cach recover ngoai refresh page. Vi pham 'graceful degradation' principle.",
  "severity": "high",
  "fixability": "agent_fix",
  "domain": "frontend",
  "req_ids": ["REQ-FE-RUNTIME"],
  "feat_ids": ["FEAT-APP-SHELL"],
  "affected_modules": ["app-shell"],
  "location": {"file": "src/App.tsx", "line": 15},
  "evidence": {
    "code_snippet": "function App() {\n  return (\n    <Providers>\n      <Router>\n        <Routes />\n      </Router>\n    </Providers>\n  );\n}",
    "reproduction_steps": "1. Open app, 2. Trigger bug trong UserAvatar (vd: corrupt localStorage), 3. Quan sat: toan bo app crash → white screen, 4. Console: 'Uncaught TypeError: Cannot read properties of null'.",
    "confidence": 0.88
  },
  "remediation": {
    "suggested_action": "Wrap content trong <ErrorBoundary fallback={<ErrorFallback />}>: function App() { return (<Providers><ErrorBoundary><Router><Routes /></Router></ErrorBoundary></Providers>); }",
    "test_recommendation": "E2E test: force throw trong child component → assert ErrorFallback renders + nav van hoat dong.",
    "estimated_effort_min": 15,
    "regression_risk": "low"
  }
}
```

### 6.2 Edge case — Route guard redirect loop

```json
{
  "title": "Protected route guard gay infinite redirect loop khi token expired",
  "description": "Trong auth-guard.tsx:25, PrivateRoute check `token && user` → redirect `/login` khi thieu. Nhưng `/login` cung trong `<PrivateRoute>` wrapper → login page check auth → redirect `/dashboard` → loop. User thay flickering URL + 'Too many redirects' browser error.",
  "severity": "critical",
  "fixability": "agent_fix",
  "domain": "frontend",
  "req_ids": ["REQ-AUTH-GUARD"],
  "feat_ids": ["FEAT-AUTH-ROUTING"],
  "affected_modules": ["auth-routing"],
  "location": {"file": "src/guards/auth-guard.tsx", "line": 25},
  "evidence": {
    "code_snippet": "function PrivateRoute({ children }) {\n  const { user, token } = useAuth();\n  if (!token || !user) return <Navigate to=\"/login\" />;\n  return children;\n}\n// Router:\n<PrivateRoute>\n  <Route path=\"/login\" element={<Login />} />  {/* <-- login inside guard! */}\n  <Route path=\"/dashboard\" element={<Dashboard />} />\n</PrivateRoute>",
    "reproduction_steps": "1. Login user, 2. Clear token manually (simulate expiry), 3. Navigate to /dashboard, 4. Quan sat: redirect loop /login<->/dashboard, 5. Browser error 'ERR_TOO_MANY_REDIRECTS'.",
    "confidence": 0.92
  },
  "remediation": {
    "suggested_action": "Tach router: Public routes (login, register) nam NGOAI PrivateRoute. Chi wrap routes can auth: <Routes><Route path=\"/login\" element={<Login />} /><PrivateRoute><Route path=\"/dashboard\" element={<Dashboard />} /></PrivateRoute></Routes>",
    "test_recommendation": "Test: expired token → redirect /login, assert /login render (not loop). Verify no redirect count > 3.",
    "estimated_effort_min": 20,
    "regression_risk": "medium"
  }
}
```

### 6.3 Counter-example — DO NOT emit

```typescript
// SearchInput.tsx
function SearchInput() {
  const [query, setQuery] = useState('');
  
  return (
    <input 
      value={query}
      onChange={(e) => setQuery(e.target.value)}
      placeholder="Search..."
    />
  );
  // LLM TEMPTED: "onChange goi setState moi keystroke khong debounce → perf bug!" → SAI
}
```

**Ly do KHONG emit:**
- `setState` la sync React operation — khong goi API, khong re-render toan bo tree.
- Debounce chi can khi onChange trigger side-effect (API call, filter large list).
- Match negative pattern §6 cua dimension QD9.

---

> **Tham chieu schema + rules chung**: Xem `_shared.md`.
