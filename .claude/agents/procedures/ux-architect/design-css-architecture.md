# Playbook: Thiết kế CSS Architecture

> **Type**: Agent Skill Playbook
> **Agent**: ux-architect
> **Triggered by**: `/wf-design` hoặc `/wf-design-ux` khi cần thiết kế CSS/styling architecture (Phase 4-5)
> **Output**: `.mc-data/docs/phase4-ux/css-architecture.md`

---

## Khi nào dùng playbook này

- Khi dự án có UI và cần quyết định CSS methodology trước khi implement
- Khi cần thiết kế design token system và file structure cho frontend
- Khi cần xác lập component style encapsulation strategy cho toàn bộ project
- Khi tech stack chưa có CSS architecture được định nghĩa

---

## Procedure

### Bước 1: Đọc design system specs và tech stack

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture), PHASE4 (UX design)

Cần xác định:
□ Tech stack frontend: React / Vue / Angular / Svelte / plain HTML?
□ Build tool: Vite / Webpack / Turbopack?
□ Đã có design system chưa? (Figma tokens, Storybook, component library?)
□ Team size và CSS familiarity: Lớn (cần low-barrier) hay nhỏ (có thể phức tạp hơn)?
□ Performance budget: Target Lighthouse score? Critical CSS có required không?
□ Dark mode yêu cầu? Multi-theme?
□ Đọc: .claude/references/team-expert/design/design-system-patterns.md → Section 1 (Token Hierarchy)
```

### Bước 2: Chọn CSS methodology với trade-offs rõ ràng

Đánh giá 4 methodology dựa trên context dự án:

**Tailwind CSS (Utility-First)**
```
PHÙ HỢP khi:
□ Team muốn tốc độ cao, prototyping nhanh
□ Không có design system phức tạp
□ Component isolation không quan trọng
□ Developer đã quen Tailwind

KHÔNG PHÙ HỢP khi:
□ Cần white-label / multi-theme phức tạp
□ Design tokens cần sync hai chiều với Figma
□ Bundle size là priority tuyệt đối (Tailwind purge cần config đúng)

TRADE-OFFS:
+ Không cần đặt tên class → tốc độ cao
+ PurgeCSS tích hợp → bundle nhỏ khi config đúng
- HTML dài, khó đọc với complex components
- Custom design values cần thêm vào tailwind.config.js
```

**CSS Modules**
```
PHÙ HỢP khi:
□ Team cần style scoping per-component (không global leakage)
□ Dự án có nhiều devs, tránh naming conflict
□ Component library / design system có boundary rõ ràng

KHÔNG PHÙ HỢP khi:
□ Cần utility classes dùng chung (sẽ duplicate)
□ Server-side rendering với dynamic class names phức tạp

TRADE-OFFS:
+ Zero runtime overhead (build-time hashing)
+ True style isolation per component
- Khó chia sẻ styles giữa components nếu không có shared module
- Composition phức tạp hơn
```

**CSS-in-JS (styled-components / Emotion)**
```
PHÙ HỢP khi:
□ Dynamic theming runtime (color scheme switch không reload)
□ Props-based styling phức tạp
□ Design tokens cần sync với JavaScript values

KHÔNG PHÙ HỢP khi:
□ SSR performance critical (runtime overhead, FOUC risk)
□ Bundle size priority (runtime library ~30KB+)
□ Team không muốn JS-heavy styling approach

TRADE-OFFS:
+ Co-location tuyệt đối: style và component cùng file
+ Dynamic styling với props rất tự nhiên
- Runtime JS execution cho mỗi render
- Khó debug CSS specificity
```

**Vanilla CSS với Custom Properties**
```
PHÙ HỢP khi:
□ Ưu tiên zero dependencies
□ Cần CSS cascade control tuyệt đối
□ Đội có strong CSS expertise

TRADE-OFFS:
+ Không có build dependencies
+ Native browser support, no transpilation
- Cần naming discipline nghiêm ngặt (BEM hoặc custom convention)
- Thiếu tooling hỗ trợ (autocomplete kém hơn)
```

**Quyết định:** Ghi rõ methodology được chọn và lý do dựa trên context dự án.

### Bước 3: Thiết kế file structure

Dựa trên methodology đã chọn, define file structure cụ thể:

**Nếu Tailwind:**
```
src/styles/
├── tokens.css          # Design tokens (CSS custom properties)
├── base.css            # Reset + base element styles
├── components.css      # Component-level utilities không có trong Tailwind
└── index.css           # Entry point, import theo thứ tự

tailwind.config.js      # Extend theme với custom tokens
```

**Nếu CSS Modules:**
```
src/
├── styles/
│   ├── tokens.css          # Primitive + semantic design tokens
│   ├── base.css            # Reset và typography base
│   ├── animations.css      # Shared keyframes
│   └── utilities.css       # Utility classes dùng chung
└── components/
    └── Button/
        ├── Button.tsx
        └── Button.module.css   # Scoped styles per component
```

**Nếu CSS-in-JS:**
```
src/
├── theme/
│   ├── tokens.ts       # Design tokens as TypeScript constants
│   ├── theme.ts        # Theme object (light + dark)
│   └── ThemeProvider.tsx
└── components/
    └── Button/
        ├── Button.tsx  # Styles co-located trong file
        └── Button.test.tsx
```

### Bước 4: Thiết kế token layer

Luôn theo 3-tầng từ `.claude/references/team-expert/design/design-system-patterns.md`:

```
Tầng 1 — Primitive Tokens (Raw values — không dùng trực tiếp trong components):
--color-blue-500: #3B82F6
--color-neutral-100: #F1F5F9
--space-4: 1rem
--radius-md: 8px

Tầng 2 — Semantic Tokens (Meaning-based — dùng trong components):
--color-surface-default: var(--color-neutral-100)
--color-action-primary: var(--color-blue-500)
--color-text-default: var(--color-neutral-900)

Tầng 3 — Component Tokens (Component-specific overrides — optional):
--button-bg-primary: var(--color-action-primary)
--button-radius: var(--radius-md)
```

**Rule bắt buộc:** Components chỉ được reference Semantic Tokens hoặc Component Tokens — KHÔNG BAO GIỜ reference Primitive Tokens trực tiếp. Lý do: cho phép rebrand toàn bộ chỉ bằng thay đổi semantic mapping.

**Dark mode token mapping:**
```css
/* Light mode (default) */
:root {
  --color-surface-default: #FFFFFF;
  --color-text-default: #0F172A;
  --color-border-default: #E2E8F0;
}

/* Dark mode via data attribute (user preference) */
[data-theme="dark"] {
  --color-surface-default: #0F172A;
  --color-text-default: #F1F5F9;
  --color-border-default: #1E293B;
}

/* Dark mode via OS preference (khi chưa có user preference) */
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --color-surface-default: #0F172A;
    --color-text-default: #F1F5F9;
  }
}
```

### Bước 5: Thiết kế component style encapsulation strategy

```
Xác định boundaries giữa:
□ Global styles: reset, base typography, scrollbar → KHÔNG scoped
□ Layout components: grid, container, section → Scoped nhẹ, allow override
□ UI components: button, input, card → Fully scoped, không global leak
□ Utility classes: text-center, flex, hidden → Global, stateless

Naming convention (nếu dùng Vanilla CSS / CSS Modules):
□ Component classes: .component-name → .button, .card, .modal
□ Element classes: .component__element → .button__icon, .card__title
□ Modifier classes: .component--variant → .button--primary, .card--elevated
□ State classes: .is-state hoặc data attribute → .is-loading, [data-disabled]

CSS specificity rules:
□ Giữ specificity thấp nhất có thể (1 class selector)
□ Không dùng !important trừ utility classes override
□ Không nest selector quá 2 cấp
□ Component styles không được select element bên ngoài boundary của nó
```

### Bước 6: Thiết kế animation system

```
Đọc: .claude/references/team-expert/design/design-system-patterns.md → Section 9 (Motion Tokens)

Định nghĩa animation tokens:
□ duration.fast: 100ms — micro-interactions (hover, focus ring)
□ duration.normal: 200ms — component transitions (dropdown, tooltip)
□ duration.slow: 300ms — page transitions, modal, drawer
□ easing.standard: cubic-bezier(0.4, 0, 0.2, 1) — mặc định
□ easing.enter: cubic-bezier(0, 0, 0.2, 1) — elements xuất hiện
□ easing.exit: cubic-bezier(0.4, 0, 1, 1) — elements biến mất

GPU-accelerated rule (BẮT BUỘC):
□ Chỉ animate: transform, opacity, filter
□ KHÔNG animate: width, height, top, left, margin, padding (trigger layout)
□ Dùng will-change: transform CHỈ khi cần — quá nhiều sẽ tốn VRAM

Accessibility cho animation:
□ Bọc mọi animation trong @media (prefers-reduced-motion: no-preference)
□ Hoặc provide fallback: @media (prefers-reduced-motion: reduce) { animation: none }
```

### Bước 7: Chiến lược Dark Mode

Chọn một trong hai approach và document lý do:

**Approach A: CSS Custom Properties (khuyến nghị cho hầu hết dự án)**
```
Cơ chế: Swap token values qua [data-theme="dark"] attribute
Ưu điểm: Zero JS runtime, instant switch, SSR-friendly
Nhược điểm: Cần define tất cả tokens hai lần
Phù hợp khi: Static site, SSR app, cần SEO tốt
```

**Approach B: CSS-in-JS Theme Provider**
```
Cơ chế: ThemeProvider inject theme object vào styled-components/Emotion
Ưu điểm: Dynamic theming, props access dễ
Nhược điểm: JS runtime overhead, FOUC nếu không handle SSR
Phù hợp khi: SPA, runtime theming phức tạp
```

**User preference persistence:**
```
□ Đọc localStorage trước khi render (tránh flash)
□ Fallback về OS preference nếu chưa có localStorage value
□ Apply theme class/attribute trên <html> hoặc <body>
□ Expose API: setTheme('light' | 'dark' | 'system')
```

### Bước 8: Performance — Critical CSS và tree-shaking

```
Critical CSS:
□ Xác định "above-the-fold" components: header, hero, navigation
□ Extract critical CSS thành inline <style> trong <head>
□ Defer non-critical CSS: <link rel="stylesheet" media="print" onload="this.media='all'">
□ Target: First Contentful Paint < 1.5s trên 4G

Tree-shaking (loại bỏ CSS không dùng):
□ Nếu Tailwind: cấu hình content paths đúng trong tailwind.config.js
□ Nếu CSS Modules: automatically tree-shaken bởi bundler
□ Nếu CSS-in-JS: styled-components v6+ tự động

Bundle size targets:
□ Critical CSS (inline): < 14KB (1 TCP packet)
□ Total CSS bundle: < 50KB gzipped
□ Mỗi lazy-loaded route: < 10KB CSS riêng
```

### Bước 9: Build tooling integration

```
Xác định build tooling config cần thiết:

Vite:
□ CSS Modules: built-in, không cần config thêm
□ Tailwind: plugin @tailwindcss/vite
□ PostCSS: vite.config.ts → css.postcss

Webpack:
□ css-loader + style-loader (development)
□ MiniCssExtractPlugin (production)
□ postcss-loader cho autoprefixer

PostCSS plugins nên có:
□ autoprefixer: thêm vendor prefixes tự động
□ postcss-custom-properties: polyfill cho IE (nếu cần)
□ cssnano: minify cho production

Linting:
□ Stylelint với config phù hợp (stylelint-config-standard hoặc stylelint-config-tailwindcss)
□ Define rules: max-nesting-depth: 2, no-duplicate-selectors
```

### Bước 10: Ghi output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase4-ux/css-architecture.md

Cấu trúc output:
1. Executive Summary — methodology được chọn + lý do (1 đoạn)
2. CSS Methodology Decision (với trade-off analysis)
3. File Structure (tree view đầy đủ)
4. Token System (3-layer với ví dụ cụ thể theo project)
5. Component Style Encapsulation Rules
6. Animation System
7. Dark Mode Implementation Strategy
8. Performance Checklist
9. Build Tooling Config cần thiết
10. Developer Onboarding — "Bắt đầu từ đâu?" (dành cho dev implement)
```

---

## Checklist trước khi submit

```
□ Methodology được chọn có lý do rõ ràng (WHY, không chỉ WHAT)
□ Token system đủ 3 tầng (primitive → semantic → component)
□ Dark mode strategy được document rõ ràng
□ Animation tokens defined, GPU-accelerated rule ghi rõ
□ prefers-reduced-motion được xử lý
□ Critical CSS strategy có target numbers cụ thể
□ File structure phản ánh đúng tech stack của project
□ Developer onboarding section có để dev tự implement không cần hỏi thêm
```
