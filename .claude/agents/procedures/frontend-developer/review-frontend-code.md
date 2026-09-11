# Playbook: Frontend Code Review

> **Type**: Agent Skill Playbook
> **Agent**: frontend-developer
> **Triggered by**: Frontend code review request từ `/wf-implement-feature` hoặc code-reviewer agent
> **Output**: Frontend code review report với phân loại vấn đề theo severity

---

## Khi nào dùng playbook này

- Khi review frontend code trước khi merge (self-review hoặc peer review)
- Khi code-reviewer agent yêu cầu domain-specific frontend review
- Khi audit frontend codebase để tìm technical debt
- Khi cần validate implementation đạt chuẩn performance + accessibility + security

---

## Procedure

### Bước 1: Xác định scope review

```
INPUT: File paths hoặc PR diff do skill / code-reviewer cung cấp

Xác định:
□ Loại thay đổi: Component mới / Page mới / Store / Bug fix / Refactor
□ REQ-ID liên quan (đối chiếu với req-registry.json)
□ Framework đang dùng (React / Vue / Angular) → áp dụng checklist đúng
□ Đây là code mới hay refactor code hiện có?

Load context:
□ Đọc feature spec liên quan tại .mc-data/docs/phase5-implementation/tasks/
□ Đọc UX spec nếu review UI component (PHASE4)
□ Đọc API spec nếu review data fetching (PHASE3)
```

### Bước 2: Core Web Vitals impact analysis

```
Phân tích ảnh hưởng đến performance metrics:

LCP (Largest Contentful Paint — target < 2.5s):
□ Có thêm ảnh lớn không? → kiểm tra có width/height, WebP, fetchpriority="high"
□ Có font load mới không? → kiểm tra font-display: swap, preload
□ Có render-blocking script không? → kiểm tra defer/async
□ Hero image có lazy load không? → NẾU CÓ → đây là bug (hero image không được lazy)

FID/INP (Interaction to Next Paint — target < 100ms):
□ Có long task (>50ms) trên main thread không?
□ Event handler có heavy computation không? → cần debounce hoặc Web Worker
□ Có synchronous localStorage read trong render không? → cần cache trong memory

CLS (Cumulative Layout Shift — target < 0.1):
□ Images có width/height attributes không?
□ Dynamic content có reserved space không? (min-height, aspect-ratio)
□ Web font có fallback size khớp không? → tránh font swap gây shift
□ Ad slots có kích thước cố định không?

Bundle size:
□ Có import heavy library mới không? → dùng bundle analyzer check
□ Import toàn bộ hay named import? (import _ từ lodash vs import { debounce })
□ Dynamic import cho code splitting đúng chỗ chưa?
□ Có trùng lặp dependency không? (2 version của cùng 1 thư viện)
```

### Bước 3: Bundle size analysis

```
Phát hiện bundle size issues:

□ Kiểm tra import statements:
  SAI: import * as _ from 'lodash'          → +70KB
  ĐÚNG: import { debounce } from 'lodash'   → +2KB
  TỐT NHẤT: import debounce from 'lodash/debounce'

□ Heavy libraries không cần thiết:
  - moment.js → thay bằng date-fns hoặc dayjs
  - full antd/mui import → dùng tree-shaking
  - lodash full → lodash-es hoặc individual methods

□ Dynamic import đúng chỗ:
  - Route-level: lazy(() => import('./Page')) ✅
  - Heavy component (editor, chart): lazy import ✅
  - Utility function: KHÔNG cần dynamic import

□ Image và media:
  - SVG: inline nếu < 1KB, external nếu > 1KB
  - Ảnh placeholder / skeleton không được là real image lớn

Budget threshold:
□ Page bundle (initial JS): < 150KB gzipped
□ Vendor bundle: < 200KB gzipped
□ Thêm mới per page: < 50KB gzipped
Nếu vượt → mark là IMPORTANT ISSUE
```

### Bước 4: Accessibility audit

```
WCAG 2.1 AA checklist — kiểm tra từng file:

Semantic HTML:
□ Interactive elements dùng đúng tag: <button> (action), <a> (link), <input> (data entry)
□ KHÔNG dùng <div onClick> hay <span onClick> trừ khi có role + keyboard handler đi kèm
□ Heading hierarchy đúng (h1 → h2 → h3, không skip level)
□ Lists dùng <ul>/<ol>/<li> thay vì div
□ Tables có <thead>, <th scope>, <caption> nếu cần

ARIA:
□ ARIA attributes đúng cú pháp và giá trị hợp lệ
□ Không dùng ARIA khi semantic HTML đã đủ (ARIA redundant)
□ Icon-only interactive elements có aria-label
□ Dynamic regions có aria-live nếu cần (thông báo, status updates)
□ Modal có role="dialog", aria-labelledby, aria-modal="true"
□ Form inputs có label liên kết (for/id hoặc aria-labelledby)
□ Error messages có aria-describedby từ input

Keyboard:
□ Tất cả interactive elements có thể focus bằng Tab
□ Custom components có keyboard handler đúng:
  - Button: Enter + Space
  - Link: Enter
  - Dropdown menu: Arrow keys + Escape
  - Dialog: Trap focus, Escape đóng
□ Tab order theo visual order (không bị nhảy lung tung)
□ Focus không disappear (không outline: none nếu không có replacement)

Color và contrast:
□ Text contrast ≥ 4.5:1 (normal), ≥ 3:1 (large text)
□ Không truyền thông tin CHỈ bằng màu (có kèm icon hoặc text)
□ Focus indicator visible (outline tối thiểu 2px)

Severity:
- Thiếu ARIA label cho icon button → CRITICAL (screen reader users bị blocked)
- Contrast < 3:1 → CRITICAL
- Không thể navigate bằng keyboard → CRITICAL
- Heading hierarchy sai → IMPORTANT
```

### Bước 5: Security issues

```
Frontend security checklist:

XSS (Cross-Site Scripting):
□ KHÔNG dùng dangerouslySetInnerHTML (React) / v-html (Vue) với user input
□ Nếu bắt buộc phải render HTML → sanitize trước bằng DOMPurify
□ URL parameters được sanitize trước khi render
□ KHÔNG eval() hay Function() với user data

CSRF:
□ Form submissions có CSRF token không?
□ State-changing requests dùng POST/PUT/DELETE (không GET)
□ SameSite cookie attribute được set đúng

Sensitive data:
□ KHÔNG log user data, tokens, passwords ra console
□ KHÔNG store sensitive data trong localStorage (tokens → httpOnly cookie)
□ KHÔNG expose API keys, secrets trong client bundle
□ Environment variables: chỉ NEXT_PUBLIC_ / VITE_ prefix mới expose ra client

Content Security Policy:
□ Không có inline scripts không cần thiết (tránh script-src 'unsafe-inline')
□ External resources từ trusted domains

Third-party:
□ Dependencies có known vulnerabilities không? (npm audit)
□ Analytics scripts không leak PII (user email, ID trong event properties)
```

### Bước 6: Component re-render patterns

```
Performance antipatterns cần phát hiện:

React:
□ useEffect với missing/wrong dependencies → stale closures hoặc infinite loop
□ Object/Array literals trong JSX props → mới mỗi render, gây re-render child
  SAI: <Component style={{ padding: 16 }} />
  ĐÚNG: const style = useMemo(() => ({ padding: 16 }), [])
□ Function trong JSX không được memoize → gây re-render child
  SAI: <Component onClick={() => doSomething(id)} />
  ĐÚNG: const handleClick = useCallback(() => doSomething(id), [id])
□ Context value không memoize → mọi consumer re-render khi provider re-render
□ List không có key hoặc key là array index (khi list có thể reorder/delete)
□ Component quá lớn (>200 LOC) → cần split để tránh unnecessary re-renders

Vue:
□ Computed properties thiếu dependencies → stale value
□ Watchers quá broad (watch toàn bộ object thay vì specific path)
□ v-if/v-show dùng sai chỗ (v-if cho rare toggle, v-show cho frequent toggle)

Angular:
□ Component không dùng OnPush strategy khi có thể → unnecessary change detection
□ Observable không được unsubscribe → memory leak
□ trackBy thiếu trong *ngFor với dynamic lists
```

### Bước 7: State mutation correctness

```
Kiểm tra state management:

Immutability:
□ Không mutate state trực tiếp (state.items.push() là antipattern)
□ Array operations: map, filter, spread (...) thay vì push, splice, sort (mutating)
□ Object update: { ...state, field: newValue } thay vì state.field = newValue

Store integrity:
□ Actions naming rõ ràng (động từ + noun)
□ Loading state per-action (không dùng chung 1 isLoading)
□ Error state được clear khi retry
□ Async actions có finally block (loading = false ngay cả khi error)

Selector correctness:
□ Selectors không có side effects
□ Derived state được compute, không store riêng (tránh stale)
□ Memoized selectors dùng đúng (reselect / computed) khi expensive

Race conditions:
□ Multiple rapid API calls → có debounce hoặc cancel previous request không?
□ Async action kết quả đến sai thứ tự → có check obsolete response không?
   (ví dụ: search kết quả cũ ghi đè kết quả mới)
```

### Bước 8: Test coverage check

```
Kiểm tra test quality (không chỉ số lượng):

Coverage:
□ Critical paths (happy path + error path) đã test chưa?
□ Edge cases: empty state, max values, special characters
□ Async code: có test loading state, error state?

Test quality:
□ Test titles mô tả behavior, không mô tả implementation
  ĐÚNG: 'hiển thị error message khi submit form thiếu email'
  SAI: 'setState được gọi với { error: true }'
□ getByRole() thay vì getByTestId() (test từ user perspective)
□ Không mock quá nhiều → integration tests quan trọng hơn unit tests biệt lập
□ Snapshot tests: chỉ dùng cho stable UI, không cho logic-heavy components

Red flags:
□ 0% test coverage cho component mới → IMPORTANT ISSUE
□ Test chỉ test implementation (spy on setState) không test behavior → WARNING
□ Flaky tests (pass/fail ngẫu nhiên) → CRITICAL (fix trước khi merge)
```

### Bước 9: Design system compliance

```
Kiểm tra nhất quán với design system:

Tokens:
□ Không hardcode colors, spacing, font-size → phải dùng CSS variables / tokens
□ Breakpoints đúng với design system (không tự đặt breakpoint lạ)
□ Z-index dùng trong layer system (không random number)

Component reuse:
□ Không tự implement lại component đã có trong design system
□ Component props tuân thủ interface chuẩn (size: 'sm'|'md'|'lg', không string tự do)

Naming:
□ CSS class names nhất quán với naming convention (BEM / utility-first / CSS Modules)
□ Component file names: PascalCase (Button.tsx) thay vì kebab-case (button.tsx)
```

### Bước 10: Mobile và responsive checks

```
□ Mobile-first CSS: styles nhỏ nhất trước, min-width media queries
□ Touch targets: tối thiểu 44×44px cho mọi interactive element
□ Không dùng :hover-only states cho mobile (user không có hover)
□ Scroll: overflow-x: auto cho tables, không bị vỡ layout
□ Font size: tối thiểu 16px cho body text trên mobile (tránh auto-zoom iOS)
□ Viewport meta: <meta name="viewport" content="width=device-width, initial-scale=1">
□ Safe area insets cho iOS notch: env(safe-area-inset-bottom)
□ Orientation: test cả portrait và landscape
```

### Bước 11: Output — Review Report

```markdown
# Frontend Code Review: [Feature / File Name]

> REQ-ID: [REQ-XXX-NNN]
> Reviewer: frontend-developer agent
> Date: [date]
> Framework: [React / Vue / Angular]

## Overall Status: ✅ APPROVED / ⚠️ APPROVED WITH COMMENTS / ❌ CHANGES REQUIRED

## Summary
[2-3 câu tóm tắt chất lượng code và vấn đề chính]

---

## Critical Issues (BẮT BUỘC FIX trước khi merge)

| # | File | Dòng | Vấn đề | Tác động | Fix đề xuất |
|---|------|------|--------|----------|-------------|
| 1 | | | | | |

## Important Issues (Fix trong sprint này)

| # | File | Dòng | Vấn đề | Fix đề xuất |
|---|------|------|--------|-------------|
| 1 | | | | |

## Suggestions (Nice-to-have, tech debt)

| # | File | Dòng | Gợi ý |
|---|------|------|-------|
| 1 | | | |

---

## Checklist Summary

| Hạng mục | Status | Ghi chú |
|----------|--------|---------|
| Core Web Vitals impact | ✅/⚠️/❌ | |
| Bundle size | ✅/⚠️/❌ | |
| Accessibility (WCAG AA) | ✅/⚠️/❌ | |
| Security (XSS, CSRF) | ✅/⚠️/❌ | |
| Re-render patterns | ✅/⚠️/❌ | |
| State mutation | ✅/⚠️/❌ | |
| Test coverage | ✅/⚠️/❌ | |
| Design system compliance | ✅/⚠️/❌ | |
| Mobile/Responsive | ✅/⚠️/❌ | |
| REQ-ID references | ✅/⚠️/❌ | |

---

## Performance Metrics (nếu đo được)

| Metric | Trước | Sau | Target |
|--------|-------|-----|--------|
| LCP | | | < 2.5s |
| FID/INP | | | < 100ms |
| CLS | | | < 0.1 |
| Bundle size delta | | | < +50KB gz |

## Sign-off

□ Không có Critical Issues
□ Important Issues được acknowledged (fix trong sprint này)
□ REQ-ID đầy đủ
```

---

## Severity Definitions

| Severity | Nghĩa | Action |
|----------|-------|--------|
| **Critical** | Block user hoàn toàn, security vulnerability, data loss | BẮT BUỘC fix trước merge |
| **Important** | Ảnh hưởng performance/UX đáng kể, accessibility violation | Fix trong sprint này |
| **Suggestion** | Code quality, technical debt, minor improvement | Tech debt backlog |

---

## Checklist trước khi submit review

```
□ Đã đọc tất cả files trong scope review
□ Đã test mental model: chạy code trong đầu qua happy path
□ Critical issues: có reproduce steps cụ thể
□ Fix suggestions: có code example, không chỉ nói "cần fix"
□ REQ-ID đối chiếu với registry đã xong
□ Không block merge vì nitpick — Suggestion không phải CHANGES REQUIRED
```
