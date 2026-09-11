# Playbook: Thiết kế Page Layouts

> **Type**: Agent Skill Playbook
> **Agent**: ui-designer
> **Triggered by**: /wf-design-ux Phase 4 khi cần thiết kế page / screen layouts
> **Output**: `.mc-data/docs/phase4-ux/layouts/[page-name]-layout.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design-ux` sau khi design system / component library đã có
- Khi cần translate UX wireframes sang pixel-level layout specifications
- Khi cần define grid system, breakpoints, spacing application cho từng page type
- Khi cần spec responsive behavior và layout patterns (sidebar, modal, drawer, v.v.)

---

## Procedure

### Bước 1: Đọc context và dependencies

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3, PHASE4

Cần đọc trước:
□ UX wireframes: PHASE4/wireframes/ (do ux-designer tạo)
□ Design system tokens: PHASE4/design-system/component-library.md (do ui-designer tạo ở playbook trước)
□ Feature specs: PHASE2/features/ → xác định danh sách pages cần design
□ Architecture docs: PHASE3/ → xác định loại app (SPA, MPA, mobile, dashboard)

Xác định:
□ Danh sách tất cả page types cần layout spec
□ Interface type: Web app / Dashboard / Mobile / Landing page
□ Navigation pattern: Top nav / Sidebar / Bottom nav / Hybrid
□ User roles khác nhau có layout riêng không?
□ Có màn hình authenticated vs unauthenticated khác nhau không?
```

### Bước 2: Load knowledge references

```
READ: .claude/references/team-expert/design/design-system-patterns.md
  → Section 7: Spacing system (4px/8px grid)
  → Section 6: Typography scale

READ: .claude/references/team-expert/design/accessibility-checklist.md
  → Section 1: WCAG 1.4.10 Reflow (responsive ở 320px không horizontal scroll)
  → Section 4: Keyboard navigation (skip link, focus order)
  → Section 1: WCAG 1.3.4 Orientation (không lock orientation)
```

### Bước 3: Định nghĩa Grid System

**Column Grid:**
```
Mobile (< 640px):
  Columns: 4
  Column width: fluid
  Gutter: --spacing-4 (16px)
  Margin: --spacing-4 (16px) mỗi bên

Tablet (640px – 1023px):
  Columns: 8
  Column width: fluid
  Gutter: --spacing-6 (24px)
  Margin: --spacing-6 (24px) mỗi bên

Desktop (1024px – 1279px):
  Columns: 12
  Column width: fluid
  Gutter: --spacing-6 (24px)
  Max content width: 1200px, căn giữa

Large Desktop (≥ 1280px):
  Columns: 12
  Column width: fluid
  Gutter: --spacing-8 (32px)
  Max content width: 1440px, căn giữa
```

**Lý do chọn mobile-first vs desktop-first:**
- Web app / Dashboard với user chính là desktop worker → desktop-first (min-width breakpoints)
- Consumer app / E-commerce / Marketing site → mobile-first (max-width → min-width breakpoints)
- Ghi rõ lý do vào layout spec document

### Bước 4: Định nghĩa Breakpoints

```css
/* Mobile-first (recommended cho consumer apps) */
/* Base: 320px – 639px */
@media (min-width: 640px)  { /* Tablet */ }
@media (min-width: 1024px) { /* Desktop */ }
@media (min-width: 1280px) { /* Large Desktop */ }

/* Desktop-first (cho enterprise/dashboard apps) */
/* Base: ≥ 1280px */
@media (max-width: 1279px) { /* Desktop */ }
@media (max-width: 1023px) { /* Tablet */ }
@media (max-width: 639px)  { /* Mobile */ }
```

**Critical breakpoints cần test:**
- 320px — minimum mobile width (iPhone SE cũ)
- 375px — iPhone standard
- 390px — iPhone Pro
- 768px — iPad portrait
- 1024px — iPad landscape / small desktop
- 1280px — standard desktop
- 1440px — large desktop / MacBook Pro

### Bước 5: Layout Patterns — Định nghĩa từng pattern

**Pattern 1: App Shell (Authenticated Layout)**
```
┌─────────────────────────────────────┐
│         Top Navigation Bar          │  Height: 64px (desktop), 56px (mobile)
├──────────────┬──────────────────────┤
│              │                      │
│   Sidebar    │    Main Content      │
│  (240px)     │    (fluid)          │
│              │                      │
│              │                      │
└──────────────┴──────────────────────┘

Desktop: Sidebar visible, collapsible to 64px icon-only
Tablet:  Sidebar hidden by default, slide-in overlay khi toggle
Mobile:  Sidebar hidden, bottom navigation hoặc hamburger menu

Sidebar:
  Width mở:    240px (desktop), 280px (tablet overlay)
  Width đóng:  64px (icon-only mode)
  Transition:  width var(--duration-normal) var(--easing-standard)
  Background:  --color-surface-subtle
  Border-right: 1px solid --color-border-default
```

**Pattern 2: Dashboard Layout**
```
┌─────────────────────────────────────┐
│         Top Navigation Bar          │
├──────────────┬──────────────────────┤
│   Sidebar    │  ┌─────┬─────┬─────┐ │
│              │  │ KPI │ KPI │ KPI │ │  Stats row
│              │  └─────┴─────┴─────┘ │
│              │  ┌──────────┬───────┐ │
│              │  │  Chart   │ Table │ │  Content row
│              │  └──────────┴───────┘ │
└──────────────┴──────────────────────┘

Grid cho Dashboard content area:
  Desktop: 12 columns, KPI cards 4-col each, charts 8-col + 4-col
  Tablet:  KPI cards full-width stacked, charts stacked
  Mobile:  Single column, tất cả elements stacked
```

**Pattern 3: List + Detail (Master-Detail)**
```
Desktop:
┌─────────────────────────────────────┐
│  List Panel (420px) │ Detail Panel  │
│  [Search + Filters] │ [Record View] │
│  [List items]       │               │
└─────────────────────────────────────┘

Mobile/Tablet:
  List view → navigate → Detail view (full screen)
  Back button trong detail view để trở lại list
```

**Pattern 4: Modal và Drawer**
```
Modal — Centered Overlay:
  Mobile:   Full-screen (100vw × 100vh)
  Tablet:   Max-width 560px, centered, max-height 80vh, scrollable body
  Desktop:  Sizes: sm(480px) / md(640px) / lg(800px) / xl(1024px)
  Overlay:  --color-surface-overlay với blur nhẹ (backdrop-filter: blur(4px))
  Z-index:  1000 (modal overlay), 1001 (modal dialog)

Drawer — Side Panel:
  Right Drawer:  Width 400px (desktop), 100% (mobile)
  Bottom Sheet:  Mobile-only, height 50vh–90vh, drag để expand/collapse
  Transition:    transform var(--duration-slow) var(--easing-enter)
```

**Pattern 5: Form Layout**
```
Single Column (mobile-first):
  Max-width: 480px, căn giữa
  Label trên Input (không inline label trừ compact tables)
  Gap giữa fields: --spacing-6 (24px)
  Gap giữa groups: --spacing-8 (32px)

Two Column (desktop, nếu fields ngắn):
  Column 1: First name | Column 2: Last name
  Không chia 2 cột cho fields dài (textarea, address)

Action buttons:
  Align: right (forms trong modal) / left với cancel right (standalone forms)
  Spacing: --spacing-3 (12px) giữa primary và secondary button
  Mobile: Stack buttons full-width, primary trên
```

### Bước 6: Responsive Strategy — Typography và Spacing

**Typography responsive:**
```css
/* Display và H1: dùng clamp() để scale mượt */
.text-display { font-size: clamp(2rem, 4vw + 1rem, 3rem); }
.text-h1      { font-size: clamp(1.75rem, 3vw + 0.5rem, 2.25rem); }

/* H2–H4: step down 1 size trên mobile */
/* Desktop H2: 28px (--font-size-2xl) → Mobile H2: 22px (--font-size-xl) */
/* Desktop H3: 22px (--font-size-xl) → Mobile H3: 18px (--font-size-lg) */
```

**Spacing responsive:**
```
Section spacing:
  Desktop: --spacing-16 (64px)
  Tablet:  --spacing-12 (48px)
  Mobile:  --spacing-8  (32px)

Component padding:
  Desktop: --spacing-6 (24px)
  Tablet:  --spacing-4 (16px)
  Mobile:  --spacing-4 (16px)

Không scale spacing quá nhỏ trên mobile — người dùng vẫn cần không gian đọc.
```

### Bước 7: Spec Page-by-Page Layout

Với mỗi page type trong danh sách (từ Bước 1), viết spec:

```markdown
## Layout: [Tên Page] — [ví dụ: Dashboard / User List / Product Detail]

**Pattern áp dụng**: [App Shell + Dashboard / List-Detail / Form / v.v.]
**Columns sử dụng**: [8-col content / 4-col sidebar + 8-col content]
**URL pattern**: [/dashboard / /users/:id]

### Desktop (≥ 1024px)
[Mô tả layout: vị trí các khu vực, width, spacing]
[ASCII art hoặc mô tả text rõ ràng]

### Tablet (640px – 1023px)
[Những gì thay đổi so với desktop]

### Mobile (< 640px)
[Layout mobile — thường single column]
[Navigation pattern thay đổi thế nào]

### Spacing Application
| Element | Desktop | Mobile |
|---------|---------|--------|
| Page padding | --spacing-8 | --spacing-4 |
| Section gap | --spacing-12 | --spacing-8 |
| Card padding | --spacing-6 | --spacing-4 |

### Typography trên page này
| Role | Desktop | Mobile |
|------|---------|--------|
| Page title | --font-size-2xl, bold | --font-size-xl, bold |
| Section header | --font-size-xl, semibold | --font-size-lg, semibold |
| Body text | --font-size-base | --font-size-sm |

### Lưu ý đặc biệt
[Interactions, animations, edge cases đặc thù của page này]
```

### Bước 8: Dark Mode Considerations

```
Nếu dark mode được yêu cầu:

□ Semantic tokens đã define dark mode mapping trong component-library.md
□ Images: dùng version filter hoặc cung cấp dark variant riêng
□ Shadows: trong dark mode thường cần tăng opacity của shadow hoặc dùng glow effect
□ Charts và graphs: màu sắc cần adjust để đảm bảo contrast trên nền tối
□ OS-level auto-detect: @media (prefers-color-scheme: dark) làm default,
  user có thể override bằng data-theme attribute

Background hierarchy trong dark mode:
  Surface default:  --color-neutral-950 (#0A0A0F hoặc tương đương)
  Surface subtle:   --color-neutral-900
  Surface elevated: --color-neutral-850 (card trên surface)
  Elevated shadow: dùng subtle glow thay vì drop shadow tối
```

### Bước 9: Accessibility trong Layouts

```
READ: accessibility-checklist.md Section 4: Keyboard navigation

□ Skip link: "Bỏ qua điều hướng, đến nội dung chính"
  - Element đầu tiên có thể focus trên mỗi page
  - Visible khi focused, ẩn khi không focused
  - href="#main-content", target có id="main-content"

□ Landmark regions:
  <header role="banner">  → Top navigation
  <nav aria-label="Main"> → Primary navigation / Sidebar
  <main id="main-content"> → Main content area
  <aside>                  → Secondary content (nếu có)
  <footer>                 → Footer

□ Heading hierarchy:
  H1: Tên page / Tên section chính (duy nhất 1 per page)
  H2: Các sections chính
  H3: Subsections
  Không skip level (không nhảy từ H1 sang H3)

□ Focus management:
  Modal mở: focus vào close button hoặc first focusable element
  Modal đóng: focus trả về trigger button
  Route change (SPA): focus chuyển về H1 của page mới hoặc skip link

□ Reflow (WCAG 1.4.10):
  Tất cả layouts phải hoạt động ở 320px width mà không cần horizontal scroll
  Loại trừ: data tables với nhiều columns (dùng horizontal scroll container có role="region")
```

### Bước 10: Output

```
Ghi output vào:
  - Nếu là general layout spec: .mc-data/docs/phase4-ux/layouts/layout-system.md
  - Nếu là page-specific:       .mc-data/docs/phase4-ux/layouts/[page-name]-layout.md

Cấu trúc file output:
1. Header: dự án, ngày, version, phase, author (ui-designer)
2. Grid System Definition (Bước 3)
3. Breakpoints (Bước 4) + lý do chọn strategy
4. Layout Patterns Library (Bước 5)
5. Responsive Typography + Spacing Rules (Bước 6)
6. Page-by-Page Layout Specs (Bước 7)
7. Dark Mode Considerations (Bước 8, nếu applicable)
8. Accessibility in Layouts (Bước 9)
9. Implementation Notes cho developer
```

---

## Checklist trước khi submit

```
□ Grid system: columns + gutters + margins cho mọi breakpoint đã define
□ Mọi page type trong feature specs đã có layout spec
□ Responsive: mô tả rõ thay đổi từ mobile → tablet → desktop
□ Layout hoạt động tại 320px (WCAG 1.4.10 Reflow)
□ Skip link và landmark regions đã include trong spec
□ Heading hierarchy được ghi rõ cho mỗi page
□ Focus management cho modals/drawers đã spec
□ Dark mode: đã note rõ đâu cần adjust (nếu applicable)
□ Spacing và typography dùng token names, không hardcode px values
□ Lý do chọn mobile-first vs desktop-first đã ghi lại
```
