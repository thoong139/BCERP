# LLM Probe — QD7 Compatibility & i18n (v2.0)

Vai tro: Senior platform engineer + i18n specialist.

> **v2.0:** mo rong 10 → 15 categories — them 5 patterns mobile/PWA/email/print/screen-reader. Severity matrix.

---

## 1. Tap trung phat hien

### 1.1 Core (10 categories ban dau)

1. **Browser API khong supported**: Code dung `navigator.share`, `crypto.randomUUID`, `structuredClone` ma target browser khong support.
2. **Polyfill missing**: Project target IE11/Safari old nhung khong polyfill `Promise.allSettled`, `Array.flat`.
3. **i18n key incompleteness**: Translation file chi co tieng Viet, ma user co the chuyen sang en — UI hien raw key.
4. **Locale-specific bugs**: Number format `Intl.NumberFormat()` thieu locale, currency hardcoded `'VND'`.
5. **Date format inconsistency**: `new Date(string)` voi format khong ISO → khac timezone parse khac.
6. **Pluralization missing**: "1 bug" vs "5 bugs" hardcode, khong dung ICU MessageFormat.
7. **Right-to-left (RTL) breaking layout**: CSS `padding-left` thay vi `padding-inline-start`, fixed `direction: ltr`.
8. **Mobile vs desktop divergence**: Touch event khong kem mouse fallback, hover-only interaction.
9. **Server-Side Rendering (SSR) mismatch**: Code reference `window`/`document` khong check `typeof window !== 'undefined'`.
10. **Deprecated API silent fallback**: Code dung `componentWillMount` (React 17 deprecated), `String.prototype.substr` (deprecated).

### 1.2 Mo rong (5 categories moi — v2.0)

11. **Mobile native gesture conflicts**: Swipe gesture cua app conflict voi swipe-to-go-back cua iOS/Android. Pull-to-refresh disable scroll. Touch event khong cancel gesture default.
12. **PWA offline mode bugs**: Service Worker cache strategy sai (cache-first cho API → user nhin data cu mai), offline page khong fallback cho API errors, IndexedDB schema migration miss.
13. **Print stylesheet bugs**: `@media print` thieu → user print invoice ra giay den nguoc; element `display:none` cho web hien tren print; page-break-inside chay du lieu.
14. **Email client compatibility**: HTML email dung `flexbox`/`grid` (nhieu client khong support — Outlook), inline CSS thieu, image alt text thieu, CSS link external (Outlook strip).
15. **Screen reader specific bugs**: NVDA/JAWS doc sai do dynamic content khong update aria-live, custom widget thieu role/state, focus visible khong rõ rang.

---

## 2. Severity Calibration (QD7-specific)

| Pattern | Default severity | Bump khi |
|---------|------------------|----------|
| Browser API khong support | **medium** | Target user > 5% browser do → high |
| Polyfill missing | **medium** | Target old browser → high |
| i18n key missing | **medium** | Production locale active → high |
| Locale format (currency, number) | **high** | Multi-locale market → critical |
| Date timezone | **high** | Cross-region scheduled task → critical |
| Pluralization missing | **low** | Locale plural rules complex (Russian, Arabic) → medium |
| RTL layout breaking | **medium** | RTL market (Arabic, Hebrew) → high |
| Mobile/desktop divergence | **medium** | Mobile-first product → high |
| SSR mismatch (hydration) | **high** | Always (gay flash + a11y issue) |
| Deprecated API | **medium** | Library bump major → high |
| Mobile gesture conflict | **medium** | Primary action → high |
| PWA offline cache wrong | **high** | Offline-promised feature → critical |
| Print stylesheet | **low** | B2B invoice/receipt → high |
| Email HTML compat | **medium** | Transactional email → high |
| Screen reader bug | **high** | Always (a11y compliance) |

---

## 3. KHONG focus (tranh duplicate)

- Deprecated API names static check → static probe (P-QD7-deprecated-api-usage)
- i18n key existence → static probe (P-QD7-i18n-key-audit)
- Browser compat static check → static probe (P-QD7-browser-compat-check)
- Polyfill static coverage → static probe (P-QD7-polyfill-coverage)
- Device breakpoint runtime → playwright probe (P-QD7-device-breakpoint-test)
- API version compat → static probe (P-QD7-api-version-compat)

---

## 4. Negative Patterns — KHONG emit (QD7-specific)

> Bo sung cho `_shared.md` §5.

1. **Browser API khong support KHI** project chi target modern browsers (Chrome/Firefox/Safari latest 2 versions) va da declare trong `browserslist`.
2. **i18n key missing KHI** locale chi enable trong dev/staging.
3. **RTL bug KHI** product khong phuc vu RTL market.
4. **Print stylesheet KHI** product la pure SaaS dashboard khong co print use case.
5. **PWA bug KHI** project chua khai bao la PWA (no service worker).
6. **Email compat KHI** project chi dung 1 client (Gmail) cho transactional.

---

## 5. CI Tools (uu tien khi available)

Khi co GitNexus/Serena, dung de nang confidence cho QD7 compatibility:

- **Deprecated API usage**: `mcp__serena__find_referencing_symbols({name_path: <deprecated_function>, relative_path})` → list moi noi goi → severity dua tren so callers.
- **Polyfill coverage**: `mcp__serena__find_referencing_symbols` cho polyfill imports → confirm coverage.
- **API version compat (bump major lib)**: `mcp__plugin_gitnexus_gitnexus__impact({target: <wrapper_function>, direction:"upstream"})` → blast radius khi bump.
- **Browser API support (Web API moi)**: `mcp__serena__find_referencing_symbols` cho Web API call.
- **i18n message key missing trong locale**: `mcp__serena__find_referencing_symbols({name_path: <t_function>})` → list tat ca key dang dung.
- **SSR mismatch**: `mcp__plugin_gitnexus_gitnexus__query({query: "client component"})` → trace xem co `'use client'` directive khong va `window` access pattern.

Populate `evidence.ci_citation` voi `serena_refs_count`, `gitnexus_impact_callers` (cho deprecated API — quyet dinh impact), va `tools_used`.

---

## 6. Vi du

### 6.1 Positive — navigator.share fallback

```json
{
  "title": "navigator.share() khong fallback cho desktop browsers",
  "description": "ShareButton.tsx:34 truc tiep goi navigator.share() nhung khong check support. Tren Firefox desktop / Chrome cu tren Windows → throw TypeError: navigator.share is not a function. Bug se silent fail vi try/catch.",
  "severity": "medium",
  "fixability": "agent_fix",
  "domain": "frontend",
  "req_ids": ["REQ-SHARE-001"],
  "feat_ids": ["FEAT-CONTENT-SHARE"],
  "affected_modules": ["share-component"],
  "location": {"file": "src/components/ShareButton.tsx", "line": 34},
  "evidence": {
    "code_snippet": "const handleShare = () => {\n  navigator.share({ title, url });\n};",
    "reproduction_steps": "1. Mo app tren Firefox desktop (no Web Share API), 2. Click Share button, 3. Quan sat: nothing happens, console: TypeError.",
    "confidence": 0.87
  },
  "remediation": {
    "suggested_action": "Check support truoc: if (navigator.share) { navigator.share(...) } else { copyToClipboard(url); toast.success('Link copied'); }. Hoac dung feature detection lib.",
    "test_recommendation": "Test trong Firefox desktop + Chrome desktop + Safari iOS — confirm ca 3 path hoat dong.",
    "estimated_effort_min": 15,
    "regression_risk": "low"
  }
}
```

### 6.2 Edge case — PWA stale cache

```json
{
  "title": "Service Worker cache-first cho API gay user thay data cu mai",
  "description": "Trong service-worker.ts:55, fetch event handler match all `/api/*` routes va dung cache-first strategy: if (cached) return cached; else fetch + cache. Result: user thay data cu sau khi backend update → bao quan gia lien lac. Compliance/financial impact neu data la price/inventory.",
  "severity": "high",
  "fixability": "agent_fix",
  "domain": "frontend",
  "req_ids": ["REQ-PWA-OFFLINE"],
  "feat_ids": ["FEAT-OFFLINE-MODE"],
  "affected_modules": ["pwa-shell", "all-api-consumers"],
  "location": {"file": "src/service-worker.ts", "line": 55},
  "evidence": {
    "code_snippet": "self.addEventListener('fetch', (event) => {\n  if (event.request.url.includes('/api/')) {\n    event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request).then(res => { cache.put(event.request, res.clone()); return res; })));\n  }\n});",
    "reproduction_steps": "1. Visit page goi GET /api/products, 2. Backend update product price, 3. Refresh page, 4. Quan sat: UI van hien gia cu (cached).",
    "confidence": 0.88
  },
  "remediation": {
    "suggested_action": "Doi sang network-first cho API: try fetch fresh → fall back to cache khi offline. Hoac stale-while-revalidate: return cached + fetch background to update. Read-only static assets dung cache-first.",
    "test_recommendation": "Lighthouse PWA audit + manual test offline/online scenarios.",
    "references": ["https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Caching_strategies"],
    "estimated_effort_min": 60,
    "regression_risk": "high"
  }
}
```

### 6.3 Counter-example — DO NOT emit

```typescript
// internal-dashboard/Charts.tsx
import { ResizeObserver } from 'resize-observer-polyfill';
// LLM TEMPTED: "ResizeObserver da widely supported, polyfill thua → bug!" → SAI
```

**Ly do KHONG emit:**
- Day la tool **internal** voi user IT su dung Chrome enterprise (co the cu).
- Polyfill khong harm — khong gay bug, chi them ~2KB bundle.
- Pattern §1 negative: target old browser thi co polyfill la dung.

---

> **Tham chieu schema + rules chung**: Xem `_shared.md`.
