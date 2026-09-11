# Playbook: Implement Page / View

> **Type**: Agent Skill Playbook
> **Agent**: frontend-developer
> **Triggered by**: `/wf-implement-feature` khi cần implement toàn bộ page hoặc view
> **Output**: Page implementation hoàn chỉnh với route, data fetching, layout, và REQ-ID coverage

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi task yêu cầu tạo page/view mới (Dashboard, Product List, Profile Page, Checkout, v.v.)
- Khi cần refactor page hiện có theo kiến trúc mới (chuyển CSR → SSR, thêm caching, v.v.)
- Phân biệt với `implement-ui-component.md`: Page là đơn vị route-level, component là đơn vị reusable

---

## Procedure

### Bước 1: Đọc UX flow và wireframe

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE4 (UX), PHASE3 (Architecture)

Cần xác định:
□ Tên page / route path
□ User flow: page này nằm ở đâu trong user journey?
□ Entry points: user đến page này từ đâu? (navigation, deep link, redirect)
□ Exit points: user đi đâu sau page này?
□ Data cần hiển thị: danh sách, chi tiết, form, mix?
□ Permissions: ai được xem page này? (auth guard, role check)
□ REQ-ID liên quan — đọc req-registry.json hoặc context từ skill
□ Linked feature spec tại .mc-data/docs/phase5-implementation/tasks/
```

### Bước 2: Setup route

```
Xác định routing strategy của dự án:
□ React: React Router v6 / Next.js App Router / Pages Router
□ Vue: Vue Router / Nuxt
□ Angular: Angular Router

Implement route:
□ Route path (dynamic segments nếu cần: /products/:id)
□ Route guard (auth required? role required?)
□ Lazy loading: import() thay vì static import
□ Route metadata: title, breadcrumb, permissions

Ví dụ lazy route (React Router):
---
const ProductDetailPage = lazy(() => import('./pages/ProductDetailPage'))

<Route
  path="/products/:productId"
  element={
    <AuthGuard requiredRole="VIEWER">
      <Suspense fallback={<PageSkeleton />}>
        <ProductDetailPage />
      </Suspense>
    </AuthGuard>
  }
/>
---
```

### Bước 3: Chọn data fetching strategy

```
Quyết định dựa trên requirements:

SSR (Server-Side Rendering):
→ Khi: SEO critical, data thay đổi per-request, auth-sensitive data
→ Dùng: Next.js getServerSideProps / App Router server components / Nuxt useAsyncData
→ Trade-off: Server load tăng, TTFB cao hơn SSG

SSG (Static Site Generation):
→ Khi: Data ít thay đổi, SEO quan trọng, performance tối đa
→ Dùng: Next.js getStaticProps / Nuxt generate
→ Trade-off: Build time dài hơn, không phù hợp dữ liệu real-time

CSR (Client-Side Rendering):
→ Khi: Data cá nhân hóa, behind auth wall, real-time updates
→ Dùng: TanStack Query / SWR / Apollo Client
→ Trade-off: Flash of loading state, không SEO-friendly

ISR (Incremental Static Regeneration):
→ Khi: Mix giữa SSG và SSR (Next.js specific)
→ Dùng: revalidate option trong getStaticProps

Checklist sau khi chọn:
□ Loading state đã được handle (skeleton / spinner)
□ Error state đã được handle (error boundary hoặc error component)
□ Empty state đã được handle (empty data message / illustration)
□ Stale data handling (cache invalidation strategy rõ ràng)
```

### Bước 4: Page layout

```
Xác định layout structure:
□ Page có dùng shared layout không? (Header, Sidebar, Footer)
□ Grid system: CSS Grid / Flexbox — chọn 1 và nhất quán
□ Max-width container: thường 1280px hoặc 1440px với padding ngang

Implement theo thứ tự:
1. Layout wrapper (shared layout component nếu có)
2. Page-specific wrapper với max-width + padding
3. Semantic sections: <main>, <aside>, <header>, <section>, <article>
4. Responsive layout: mobile (1 cột) → tablet (2 cột) → desktop (N cột)

Lưu ý:
□ <main> chỉ có 1 trên page — chứa nội dung chính
□ Skip navigation link ở đầu page (cho screen reader và keyboard user)
□ Landmark regions đúng: <header>, <nav>, <main>, <aside>, <footer>
```

### Bước 5: Component composition

```
Phân tích UI của page → identify components cần dùng:

□ Shared components: Đã có trong component library? → import, không duplicate
□ Page-specific components: Cần tạo mới? → follow implement-ui-component.md
□ Third-party components: Wrap lại với local interface, không dùng trực tiếp trong page
  (WHY: dễ swap library sau này, tránh lock-in)

Tổ chức file:
---
pages/
  ProductDetailPage/
    index.tsx              ← Page component (entry point)
    ProductDetailPage.tsx  ← Actual implementation
    ProductDetailPage.test.tsx
    components/
      ProductImages.tsx    ← Page-specific components
      ProductReviews.tsx
    hooks/
      useProductDetail.ts  ← Data fetching + business logic
---

Separation of concerns:
□ Page component: chỉ compose — không chứa business logic
□ Custom hooks: data fetching, side effects, complex state
□ Pure components: nhận props, render UI
```

### Bước 6: State management (local vs global)

```
Nguyên tắc: Scope state càng hẹp càng tốt.

Local state (useState / ref):
→ Dùng cho: UI state (modal open, tab selected, form input)
→ KHÔNG dùng cho: data cần share cross-page

Server state (TanStack Query / SWR / Apollo):
→ Dùng cho: API data — tự động caching, background refetch, optimistic update
→ Key phải deterministic và stable: ['products', productId]

Global client state (Zustand / Pinia / Redux):
→ Dùng cho: Auth user, cart, theme, app-wide settings
→ KHÔNG put server state vào global store (antipattern — gây stale data)

Form state (React Hook Form / FormKit / Angular Reactive Forms):
→ Dùng cho: Complex forms với validation
→ KHÔNG dùng useState cho từng input field

Checklist:
□ Server state: có cache key đúng không?
□ Global state: có persist khi cần không? (localStorage / sessionStorage)
□ Form state: validation rules đã defined chưa?
□ URL state: filters/pagination có sync với URL params không?
  (WHY: shareable links, browser back/forward works correctly)
```

### Bước 7: Loading, error, và empty states

```
Ba trạng thái BẮT BUỘC phải implement — không để blank screen:

Loading state:
□ Skeleton screen thay vì spinner khi layout đã biết trước (tốt hơn cho CLS)
□ Spinner khi operation ngắn (<1s) hoặc layout không xác định trước
□ aria-busy="true" trên container đang load

Error state:
□ Error boundary bắt unexpected errors (React) / errorCaptured (Vue)
□ API error: hiển thị message thân thiện + nút retry
□ Network error: offline indicator
□ 404: redirect hoặc inline not-found component
□ KHÔNG expose technical error details cho user (log ra console/server only)

Empty state:
□ Danh sách trống: illustration + message + call-to-action
□ Search/filter không có kết quả: gợi ý thay đổi filter hoặc reset
□ Phân biệt "empty vì chưa có data" vs "empty vì filter quá hẹp"
```

### Bước 8: Performance — lazy loading và code splitting

```
Bundle size discipline:
□ Dynamic import cho page-level components (route-based splitting)
□ Dynamic import cho heavy components (rich text editor, chart library, map)
□ Bundle analyzer: kiểm tra output sau khi thêm dependency nặng
□ Tree shaking: import { specificFunction } thay vì import entireLibrary

Core Web Vitals targets cho page:
□ LCP < 2.5s: Optimize hero image (WebP/AVIF, srcset, priority hint)
□ FID/INP < 100ms: Không block main thread (defer non-critical JS)
□ CLS < 0.1: Đặt width/height cho images, reserved space cho dynamic content

Image optimization:
□ Dùng <img> với width + height attributes (tránh CLS)
□ loading="lazy" cho ảnh below the fold
□ fetchpriority="high" cho hero image (LCP candidate)
□ Dùng srcset/sizes cho responsive images
□ WebP với fallback JPEG/PNG

Font optimization:
□ font-display: swap (tránh FOIT)
□ Preload critical fonts: <link rel="preload" as="font">
□ Subset fonts nếu dùng nhiều ký tự đặc biệt
```

### Bước 9: SEO metadata

```
Áp dụng khi page cần SEO (public pages, không phải behind auth wall):

□ <title> tag: unique, mô tả, <60 ký tự
□ <meta name="description">: 120-160 ký tự
□ Open Graph: og:title, og:description, og:image, og:url
□ Twitter Card: twitter:card, twitter:title, twitter:description, twitter:image
□ Canonical URL (tránh duplicate content)
□ Structured data (JSON-LD) nếu page có product, article, breadcrumb
□ Robots meta: index/noindex theo business logic (auth pages: noindex)

Framework-specific:
□ Next.js: <Head> component / Metadata API (App Router)
□ Nuxt: useHead() / definePageMeta()
□ Angular: Title service + Meta service
```

### Bước 10: REQ-ID coverage và output

```
Trước khi submit, trace coverage:

□ Mỗi REQ-ID trong task đã được implement không?
□ File page: // REQ-ID: [REQ-XXX-NNN] ở đầu file
□ Các hook và sub-component cũng reference REQ-ID tương ứng

Ghi output vào path do skill cung cấp.
Fallback paths:
□ React/Next.js: src/pages/[page-name]/index.tsx hoặc app/[route]/page.tsx
□ Vue/Nuxt: pages/[page-name].vue hoặc pages/[page-name]/index.vue
□ Angular: src/app/[feature]/[page-name]/[page-name].component.ts
```

---

## Checklist trước khi submit

```
□ Route setup đúng (lazy load, guard)
□ Data fetching strategy phù hợp với requirements
□ Loading / Error / Empty states đã implement đầy đủ
□ URL state sync (filters, pagination) nếu cần
□ Layout semantic HTML (main, nav, header, aside)
□ Responsive mobile-first
□ LCP candidate image được optimize (WebP, priority, width/height)
□ Code splitting đúng (dynamic import cho page và heavy components)
□ SEO metadata (nếu public page)
□ REQ-ID reference có mặt trong mọi file liên quan
□ Unit tests cho custom hooks và logic phức tạp
□ Không để lại console.log, hardcoded strings, magic numbers
```

---

## Ngưỡng chấp nhận (Acceptance Thresholds)

| Metric | Ngưỡng tối thiểu |
|--------|-----------------|
| LCP | < 2.5 giây |
| FID / INP | < 100ms |
| CLS | < 0.1 |
| Lighthouse Performance | > 85 điểm |
| Lighthouse Accessibility | > 90 điểm |
| Lighthouse SEO (public pages) | > 90 điểm |
| Bundle size tăng thêm | < 50KB gzipped per page |
