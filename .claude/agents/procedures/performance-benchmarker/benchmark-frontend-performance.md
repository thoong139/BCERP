# Playbook: Benchmark hiệu năng Frontend

> **Type**: Agent Skill Playbook
> **Agent**: performance-benchmarker
> **Triggered by**: Frontend Core Web Vitals testing và optimization
> **Output**: Frontend Performance Benchmark Report

---

## Khi nào dùng playbook này

- Trước production deployment của web application mới
- Khi Google Search Console báo Core Web Vitals failing
- Sau major UI changes (redesign, new feature)
- Khi monitoring phát hiện performance regression trên frontend
- Khi `frontend-developer` cần performance baseline trước optimization

---

## Procedure

### Bước 1: Xác định targets và pages cần test

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3, PHASE4 (UX)

READ: .claude/references/team-expert/testing/load-testing-examples.md (CWV section)
READ: .claude/references/team-expert/testing/performance-benchmarks.md

Core Web Vitals thresholds (Google standards):
LCP (Largest Contentful Paint) — perceived load speed:
  GOOD:    < 2.5s
  NEEDS IMPROVEMENT: 2.5s - 4.0s
  POOR:    > 4.0s

INP (Interaction to Next Paint) — interactivity responsiveness:
  GOOD:    < 200ms
  NEEDS IMPROVEMENT: 200ms - 500ms
  POOR:    > 500ms

CLS (Cumulative Layout Shift) — visual stability:
  GOOD:    < 0.1
  NEEDS IMPROVEMENT: 0.1 - 0.25
  POOR:    > 0.25

Xác định pages cần test:
□ Homepage / Landing page (highest traffic)
□ Core user journey pages (checkout, dashboard, product detail)
□ Form-heavy pages (registration, checkout)
□ Data-heavy pages (reports, listings)

Test conditions bắt buộc:
□ Desktop (1920x1080, fast connection)
□ Mobile (375px, throttled 4G — 9Mbps download, 9Mbps upload, 170ms RTT)
□ Cả authenticated và unauthenticated pages
```

### Bước 2: Lighthouse audit

```
Chạy Lighthouse với cấu hình chuẩn:

□ Mode: Navigation (simulated throttling cho consistent results)
□ Device: Mobile VÀ Desktop (báo cáo cả hai)
□ Categories: Performance, Accessibility, Best Practices, SEO

Thu thập 5 metrics chính của Lighthouse:
□ Performance score (0-100)
□ LCP
□ INP/FID
□ CLS
□ FCP (First Contentful Paint) — người dùng thấy gì đầu tiên
□ TTFB (Time to First Byte) — server response time

⚠️ Chạy ít nhất 3 lần và lấy median — Lighthouse có variance cao.
⚠️ Không so sánh Lighthouse score với PageSpeed Insights score nếu không cùng điều kiện.

Ghi nhận:
PAGE | DEVICE | LCP | INP | CLS | FCP | TTFB | PERF_SCORE | RUN_COUNT
```

### Bước 3: Đo LCP, INP, CLS thực tế (field data)

```
Lab data (Lighthouse) ≠ Field data (Real User Monitoring)

Nếu có production traffic:
□ Thu thập Core Web Vitals từ Real User Monitoring (RUM)
   - Google Analytics 4: có CWV data tích hợp
   - Chrome User Experience Report (CrUX): public dataset theo domain
   - Vercel Analytics, Sentry Performance, Datadog RUM, etc.
□ Phân tích phân phối (không chỉ median):
   - 75th percentile thường được Google dùng để đánh giá
   - Phân loại % users trong GOOD/NI/POOR categories

Nếu chưa có production traffic (pre-launch):
□ WebPageTest với multiple locations và real devices
□ Playwright với performance metrics collection
□ Lab data from Lighthouse là baseline

So sánh Lab vs. Field data — nếu gap lớn → có performance issue trong real conditions
```

### Bước 4: Bundle size analysis

```
JavaScript bundle là nguyên nhân phổ biến nhất của LCP và INP regression.

□ Analyze bundle composition:
   Tool: webpack-bundle-analyzer, vite-bundle-visualizer, source-map-explorer
   Câu hỏi cần trả lời:
   - Library nào to nhất? Có alternative nhẹ hơn không?
   - Có dead code không? (tree shaking hoạt động không?)
   - Có duplicate packages không? (cùng library nhiều versions)
   - Vendor chunk có được split không?

□ Measure với budgets:
   JavaScript (initial): < 200KB gzipped (cho 3G connection)
   CSS (critical): < 50KB gzipped
   Total page weight: < 1.5MB

□ Code splitting:
   - Route-based splitting implement chưa?
   - Heavy components (charts, editors, maps) lazy load chưa?
   - Dynamic imports cho non-critical features không?

□ Third-party scripts:
   List tất cả third-party scripts (analytics, chat, ads, etc.)
   Tổng third-party contribution đến initial load là bao nhiêu?
   Có thể defer/async load không?
```

### Bước 5: Image optimization

```
Images thường là nguyên nhân số 1 của LCP cao.

□ Format:
   - Có dùng modern formats không? (WebP, AVIF)
   - AVIF = tốt nhất (nhỏ hơn WebP 30-50%)
   - Fallback cho Safari < 14 (chưa support AVIF)

□ Sizing:
   - Có responsive images không? (srcset + sizes attributes)
   - Image có bị serve lớn hơn display size không?
   - Với Retina displays, có 2x images không?

□ Loading:
   - Above-the-fold images có fetchpriority="high" không?
   - Below-the-fold images có lazy loading không?
   - LCP image có preload link trong <head> không?
   - Có width + height attributes để tránh CLS không?

□ Compression:
   - JPEG quality 80-85% (không cần 100%)
   - PNG với transparency → WebP (nhỏ hơn nhiều)
   - SVG đã được optimized (svgo) chưa?

Ghi nhận LCP image cụ thể:
LCP_ELEMENT | FILE_SIZE | FORMAT | PRELOADED | LAZY_LOAD | ACTION
```

### Bước 6: Network waterfall analysis

```
Phân tích Network tab trong DevTools (hoặc WebPageTest waterfall):

□ Identify critical rendering path:
   - HTML → CSS → JS → render
   - Có render-blocking resources không? (CSS/JS trong <head> không async/defer)
   - Có request chains dài không? (request A → response → trigger request B → ...)

□ Connection optimization:
   - Preconnect cho critical third-party origins không? (<link rel="preconnect">)
   - DNS prefetch cho non-critical origins không?
   - HTTP/2 hay HTTP/3 đang dùng không? (server push không còn recommended)
   - CDN được dùng cho static assets không?

□ Caching:
   - Static assets có Cache-Control headers đúng không?
   - Immutable cache cho hashed assets (bundle.abc123.js)
   - ETag/Last-Modified cho dynamic content

□ Compression:
   - Server có enable gzip/brotli không? (brotli tốt hơn gzip ~15%)
   - Text assets (HTML, CSS, JS) đều được nén không?
```

### Bước 7: JavaScript execution time

```
Long tasks (> 50ms trên main thread) là nguyên nhân của INP cao.

□ Identify long tasks:
   Chrome DevTools Performance tab → "Long Tasks" (màu đỏ)
   Total Blocking Time (TBT) trong Lighthouse

□ Analyze main thread usage:
   - Parsing/compiling JS mất bao lâu?
   - Event handlers có synchronous expensive operations không?
   - Layout thrashing — đọc DOM property sau write property trong loop không?

□ Web Workers:
   - CPU-intensive operations đã được offload sang Web Worker chưa?
   - Applicable cho: data transformation, cryptography, complex calculations

□ React/Vue/Angular specific:
   - Unnecessary re-renders? (React DevTools Profiler)
   - Virtualization cho long lists (react-virtual, vue-virtual-scroller)?
   - Memoization (useMemo, useCallback) được dùng đúng không?
```

### Bước 8: Rendering performance

```
CLS (Cumulative Layout Shift) analysis:

□ Identify shift sources:
   Chrome DevTools → Layout Shift Regions (click icon trong Rendering tab)
   PerformanceObserver với LayoutShift entries

□ Common CLS causes:
   - Images/videos không có width/height → fix: add explicit dimensions
   - Ad slots không có reserved space → fix: min-height
   - Web fonts gây FOUT/FOIT → fix: font-display: swap + preload
   - Dynamically injected content (banners, alerts) → fix: reserve space
   - Animations sử dụng top/left thay vì transform → fix: dùng transform

□ Paint performance:
   - Có layers quá nhiều không? (GPU memory)
   - will-change property bị lạm dụng không?
   - Compositor-friendly animations (transform, opacity) thay vì layout-affecting (width, height)?
```

### Bước 9: Mobile performance

```
Mobile performance thường tệ hơn desktop 3-5x — không được bỏ qua.

□ Test trên real device nếu có thể (DevTools throttling là approximation)
□ CPU throttling: 4x slowdown để simulate mid-range Android phone
□ Network throttling: Fast 3G hoặc Slow 4G

Mobile-specific concerns:
□ Touch targets ít nhất 44x44px (accessibility + usability)
□ Font size >= 16px (tránh auto-zoom trên iOS)
□ Không dùng hover-only interactions
□ Swipe gestures có conflict với scroll không?
□ Keyboard không che input fields khi hiển thị không?
```

### Bước 10: Output Frontend Performance Benchmark Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/frontend-performance-benchmark.md

Cấu trúc output:
1. Performance Assessment: MEETS CWV / NEEDS IMPROVEMENT / FAILING CWV
2. Core Web Vitals Summary (table: page | device | LCP | INP | CLS | score | status)
3. Bundle Size Analysis (current sizes vs. targets)
4. Image Optimization Findings
5. Network Waterfall Insights (critical issues)
6. JavaScript Execution Time
7. Mobile Performance
8. Prioritized Recommendations (ordered bởi: impact × effort⁻¹)
9. REQ-IDs compliance
10. Before/After Comparison (nếu có)
```

---

## Checklist trước khi submit

```
□ Cả Desktop VÀ Mobile đều được test
□ LCP, INP, CLS đều được đo riêng biệt (không chỉ Lighthouse score)
□ Lighthouse chạy ít nhất 3 lần (lấy median)
□ Bundle size analysis đã được thực hiện với visualization
□ LCP element đã được identify cụ thể (không chỉ nói "images chậm")
□ CLS sources đã được identify cụ thể
□ Recommendations có priority và effort estimate
□ p95/p99 field data được collect nếu đã có production traffic
```
