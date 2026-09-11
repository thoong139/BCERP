# Playbook: Thiết kế Component Library

> **Type**: Agent Skill Playbook
> **Agent**: ui-designer
> **Triggered by**: /wf-design-ux Phase 4 khi cần thiết kế design system / component library
> **Output**: `.mc-data/docs/phase4-ux/design-system/component-library.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design-ux` khi dự án có UI (web app, mobile app, dashboard)
- Khi chưa có component library hoặc cần define lại từ đầu
- Khi brand guidelines mới cần được translate sang design tokens
- Khi cần chuẩn hóa component inventory trước khi handoff cho developer

---

## Procedure

### Bước 1: Đọc context và brand guidelines

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE3, PHASE4

Cần xác định:
□ Tên dự án và loại interface (web app / mobile / dashboard / marketing site)
□ Brand identity: màu sắc chính, typography, logo style
□ Design system hiện có chưa? (từ ui-ux-pro-max hoặc PHASE4/design-system/MASTER.md)
□ UX specs và wireframes từ ux-designer agent (PHASE4/wireframes/)
□ Tech stack frontend (React / Vue / React Native / Flutter) → ảnh hưởng component API design
□ Có yêu cầu dark mode không?
□ Target accessibility level (WCAG AA tối thiểu / AAA nếu có yêu cầu đặc biệt)
```

**Load design system nếu có:**
```bash
if [ -f "<PHASE4_PATH>/design-system/MASTER.md" ]; then
  cat <PHASE4_PATH>/design-system/MASTER.md
fi
```

### Bước 2: Load knowledge references

```
READ: .claude/references/team-expert/design/design-system-patterns.md
  → Section 1: Token hierarchy (Primitive → Semantic → Component)
  → Section 2: Token naming conventions
  → Section 4: Component API design principles
  → Section 5: Color system architecture

READ: .claude/references/team-expert/design/accessibility-checklist.md
  → Section 2: Color contrast ratios (4.5:1 normal, 3:1 large text)
  → Section 4: Keyboard navigation checklist
  → Section 5: Touch target sizes
  → Section 8: Common component accessibility patterns
```

### Bước 3: Audit existing components (nếu có)

Nếu dự án đã có component code hoặc design system một phần:

```
□ Liệt kê components hiện có (Glob/Grep source code)
□ Đánh giá mức độ đồng nhất (consistent naming? consistent props API?)
□ Check hardcoded values vs token usage
□ Xác định components nào giữ lại / refactor / thay thế
□ Ghi lại Design Debt: những inconsistency cần track

Format audit entry:
  - Component: [Tên]
  - Trạng thái: Stable / Cần refactor / Thay thế
  - Vấn đề: [Mô tả cụ thể]
  - Action: [Giữ / Refactor / Replace với [component mới]]
```

### Bước 4: Định nghĩa Design Tokens

Tổ chức theo 3 tầng từ design-system-patterns.md (Section 1):

**Tầng 1 — Primitive Tokens (raw values, không dùng trực tiếp trong component):**
```css
/* Màu sắc thô */
--color-blue-100: <value>;
--color-blue-500: <value>;   /* brand primary */
--color-blue-900: <value>;

/* Neutral scale */
--color-neutral-0:   #FFFFFF;
--color-neutral-50:  <value>;
--color-neutral-100: <value>;
--color-neutral-200: <value>;
--color-neutral-500: <value>;
--color-neutral-700: <value>;
--color-neutral-900: <value>;
--color-neutral-950: <value>;

/* Semantic colors (raw) */
--color-green-500: <value>;   /* success */
--color-amber-500: <value>;   /* warning */
--color-red-500:   <value>;   /* error */
--color-sky-500:   <value>;   /* info */
```

**Tầng 2 — Semantic Tokens (ý nghĩa ngữ cảnh, component dùng tầng này):**
```css
/* Màu hành động */
--color-action-primary:      var(--color-blue-500);
--color-action-primary-hover: var(--color-blue-600);
--color-action-destructive:  var(--color-red-500);

/* Màu phản hồi */
--color-feedback-success: var(--color-green-500);
--color-feedback-warning: var(--color-amber-500);
--color-feedback-error:   var(--color-red-500);
--color-feedback-info:    var(--color-sky-500);

/* Màu bề mặt */
--color-surface-default:  var(--color-neutral-0);
--color-surface-subtle:   var(--color-neutral-50);
--color-surface-overlay:  rgba(0, 0, 0, 0.5);

/* Màu chữ */
--color-text-default:   var(--color-neutral-900);
--color-text-muted:     var(--color-neutral-500);
--color-text-disabled:  var(--color-neutral-300);
--color-text-inverse:   var(--color-neutral-0);

/* Border */
--color-border-default: var(--color-neutral-200);
--color-border-strong:  var(--color-neutral-400);
--color-border-focus:   var(--color-blue-500);
```

**Typography Tokens:**
```css
--font-family-sans: 'Inter', system-ui, -apple-system, sans-serif;
--font-family-mono: 'JetBrains Mono', 'Fira Code', monospace;

--font-size-xs:   0.75rem;    /* 12px — caption, label */
--font-size-sm:   0.875rem;   /* 14px — body small, helper text */
--font-size-base: 1rem;       /* 16px — body default */
--font-size-lg:   1.125rem;   /* 18px — body large, H4 */
--font-size-xl:   1.375rem;   /* 22px — H3 */
--font-size-2xl:  1.75rem;    /* 28px — H2 */
--font-size-3xl:  2.25rem;    /* 36px — H1 */
--font-size-4xl:  3rem;       /* 48px — Display */

--font-weight-regular: 400;
--font-weight-medium:  500;
--font-weight-semibold: 600;
--font-weight-bold:    700;

--line-height-tight:   1.2;
--line-height-snug:    1.35;
--line-height-normal:  1.5;
--line-height-relaxed: 1.625;
```

**Spacing Tokens (base unit 4px):**
```css
--spacing-1:  0.25rem;  /* 4px  — micro: icon-label gap */
--spacing-2:  0.5rem;   /* 8px  — small: inline gap */
--spacing-3:  0.75rem;  /* 12px — padding nhỏ */
--spacing-4:  1rem;     /* 16px — base unit */
--spacing-6:  1.5rem;   /* 24px — section gap nhỏ */
--spacing-8:  2rem;     /* 32px — section gap vừa */
--spacing-12: 3rem;     /* 48px — section gap lớn */
--spacing-16: 4rem;     /* 64px — layout-level */
```

**Border Radius Tokens:**
```css
--radius-sm:   0.25rem;  /* 4px  — badge, chip */
--radius-md:   0.5rem;   /* 8px  — button, input */
--radius-lg:   0.75rem;  /* 12px — card, modal */
--radius-xl:   1rem;     /* 16px — panel lớn */
--radius-full: 9999px;   /* pill, avatar */
```

**Elevation (Shadow) Tokens:**
```css
--shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.12);   /* card nhỏ, dropdown */
--shadow-md: 0 4px 12px rgba(0, 0, 0, 0.15);  /* modal, panel */
--shadow-lg: 0 8px 24px rgba(0, 0, 0, 0.20);  /* popover, toast */
```

**Motion Tokens:**
```css
--duration-fast:       100ms;  /* micro-interactions: hover, focus */
--duration-normal:     200ms;  /* component transitions: dropdown open */
--duration-slow:       300ms;  /* page transitions, modal open */
--duration-deliberate: 500ms;  /* onboarding, celebrations */

--easing-standard: cubic-bezier(0.4, 0, 0.2, 1);   /* transitions thông thường */
--easing-enter:    cubic-bezier(0, 0, 0.2, 1);      /* elements xuất hiện */
--easing-exit:     cubic-bezier(0.4, 0, 1, 1);      /* elements biến mất */
```

**Dark Mode Tokens (nếu applicable):**
```css
[data-theme="dark"] {
  --color-surface-default:  var(--color-neutral-950);
  --color-surface-subtle:   var(--color-neutral-900);
  --color-text-default:     var(--color-neutral-50);
  --color-text-muted:       var(--color-neutral-400);
  --color-border-default:   var(--color-neutral-800);
  /* action và feedback colors thường giữ nguyên hoặc adjust tone */
}
```

### Bước 5: Component Inventory — Atomic Design

Tổ chức theo 3 cấp: Atomic → Molecular → Organism.

**Atomic Components (không phụ thuộc component khác):**

| Component | Variants | States | Priority |
|-----------|----------|--------|----------|
| Button | primary, secondary, ghost, destructive, link | default, hover, active, focus, disabled, loading | Must-have |
| Input | text, password, email, number, search | default, focus, filled, error, disabled | Must-have |
| Textarea | — | default, focus, error, disabled | Must-have |
| Select | — | default, open, selected, error, disabled | Must-have |
| Checkbox | — | unchecked, checked, indeterminate, disabled | Must-have |
| Radio | — | unselected, selected, disabled | Must-have |
| Toggle / Switch | — | off, on, disabled | Must-have |
| Badge | default, success, warning, error, info, neutral | — | Must-have |
| Avatar | image, initials, icon | — | Must-have |
| Icon | — | — | Must-have |
| Spinner / Loader | sm, md, lg | — | Must-have |
| Divider | horizontal, vertical | — | Should-have |
| Tooltip | — | default, visible | Should-have |

**Molecular Components (kết hợp từ atomics):**

| Component | Mô tả | Priority |
|-----------|-------|----------|
| FormField | Input + Label + HelperText + ErrorMessage | Must-have |
| SearchBar | Input + Icon button | Must-have |
| Card | Header + Body + Footer slots | Must-have |
| Alert / Banner | Icon + Message + Action | Must-have |
| Breadcrumb | List of navigation links | Should-have |
| Pagination | Previous / Page numbers / Next | Should-have |
| Tag / Chip | Badge + close button | Should-have |
| Skeleton | Placeholder loading states | Should-have |
| EmptyState | Illustration + Title + Description + Action | Should-have |
| Toast / Notification | Alert với auto-dismiss | Should-have |

**Organism Components (kết hợp từ molecular + atomic):**

| Component | Mô tả | Priority |
|-----------|-------|----------|
| Modal / Dialog | Overlay + Container + Header + Body + Footer | Must-have |
| DataTable | Header + Rows + Sort + Pagination | Must-have |
| NavigationBar | Logo + Links + Actions | Must-have |
| Sidebar | Navigation tree + collapse | Must-have |
| Dropdown Menu | Trigger + Menu items | Must-have |
| Form | Multiple FormFields + Submit | Must-have |
| DatePicker | Calendar + Input | Should-have |
| FileUpload | Drag-drop + Preview | Should-have |
| Tabs | TabList + TabPanels | Should-have |
| Accordion | Multiple collapsible sections | Should-have |

### Bước 6: Component API Specification

Với mỗi component ưu tiên Must-have, viết API spec theo format:

```markdown
## Component: Button

### Variants × Sizes
| | sm | md | lg |
|--|:--:|:--:|:--:|
| primary | ✅ | ✅ | ✅ |
| secondary | ✅ | ✅ | ✅ |
| ghost | ✅ | ✅ | ✅ |
| destructive | ❌ | ✅ | ✅ |

### Props
| Prop | Type | Default | Mô tả |
|------|------|---------|-------|
| variant | 'primary' \| 'secondary' \| 'ghost' \| 'destructive' \| 'link' | 'primary' | Visual style |
| size | 'sm' \| 'md' \| 'lg' | 'md' | Kích thước |
| isDisabled | boolean | false | Vô hiệu hóa tương tác |
| isLoading | boolean | false | Hiển thị spinner, vô hiệu hóa click |
| leftIcon | ReactNode | — | Icon bên trái label |
| rightIcon | ReactNode | — | Icon bên phải label |
| onPress | () => void | — | Handler khi click |
| children | ReactNode | — | Label text |

### States
| State | Visual | Token sử dụng |
|-------|--------|---------------|
| Default | Solid background | --color-action-primary |
| Hover | Tối hơn 10% | --color-action-primary-hover |
| Active | Tối hơn 20%, scale(0.98) | --color-action-primary-active |
| Focus | 2px outline offset 2px | --color-border-focus |
| Disabled | 40% opacity, cursor not-allowed | -- |
| Loading | Spinner replace icon/text | -- |

### Sizes
| Size | Padding | Font Size | Height | Min Touch Target |
|------|---------|-----------|--------|-----------------|
| sm | 6px 12px | --font-size-sm | 32px | 44px (padding area) |
| md | 10px 20px | --font-size-base | 40px | 44px |
| lg | 14px 28px | --font-size-lg | 48px | 48px |

### Accessibility
- role="button" (native `<button>` element ưu tiên)
- aria-disabled="true" khi isDisabled (không dùng disabled attribute để giữ focus)
- aria-busy="true" khi isLoading
- aria-label khi chỉ có icon (không có children)
- Keyboard: Enter + Space activate
- Focus: :focus-visible outline 2px solid, offset 2px, contrast ≥ 3:1

### Usage Guidelines
✅ Dùng primary cho hành động chính duy nhất trên trang
✅ Dùng ghost/secondary cho hành động phụ
✅ Dùng destructive chỉ cho actions không thể hoàn tác
❌ Không đặt 2 primary buttons cạnh nhau
❌ Không dùng button cho navigation — dùng Link
```

### Bước 7: Token Naming Convention Summary

Ghi lại quy ước đặt tên cho toàn dự án (developers phải follow):

```
CSS Custom Properties:
  Primitive:  --color-[hue]-[scale]          → --color-blue-500
  Semantic:   --color-[role]-[variant]        → --color-action-primary
  Component:  --[component]-[element]-[state] → --button-bg-hover

Spacing:      --spacing-[step]               → --spacing-4
Typography:   --font-[property]-[variant]    → --font-size-base
Radius:       --radius-[size]                → --radius-md
Shadow:       --shadow-[level]               → --shadow-md
Duration:     --duration-[speed]             → --duration-normal
Easing:       --easing-[type]                → --easing-standard

Quy tắc:
- Dùng kebab-case (không camelCase, không underscore)
- Tầng primitive KHÔNG xuất hiện trong component code
- Component chỉ reference semantic tokens
- Không hardcode giá trị hex/px trong component CSS
```

### Bước 8: Documentation format

Mỗi component trong component-library.md theo cấu trúc:
1. Tên + Mô tả ngắn (1 câu)
2. Maturity stage (Draft / Beta / Stable) — theo component-maturity-model
3. Props table
4. Variants × Sizes matrix
5. States table với visual description + token mapping
6. Accessibility spec (ARIA roles + keyboard interactions)
7. Usage guidelines (Do / Don't)
8. Token dependencies (tokens nào component này reference)

### Bước 9: Output

```
Ghi vào: .mc-data/docs/phase4-ux/design-system/component-library.md

Cấu trúc file output:
1. Header: dự án, ngày, version, author (ui-designer)
2. Design Token System (toàn bộ tokens định nghĩa ở Bước 4)
3. Token Naming Conventions (Bước 7)
4. Component Inventory (Bước 5 — summary table)
5. Component Specifications (Bước 6 — chi tiết từng component)
6. Design Debt Log (Bước 3 — nếu có audit)
7. Checklist trước handoff
```

---

## Checklist trước khi submit

```
□ Token hierarchy đủ 3 tầng: Primitive → Semantic → Component
□ CSS custom properties dùng đúng naming convention (--color-*, --spacing-*, v.v.)
□ Dark mode tokens đã define (nếu có yêu cầu)
□ Mọi component Must-have có đủ: props, variants, states, accessibility spec
□ Color contrast đã check: 4.5:1 cho normal text, 3:1 cho large text và UI components
□ Touch targets: minimum 44px (web), 48px (Android), 44px (iOS)
□ Focus indicators: 2px outline, contrast ≥ 3:1 với nền
□ Không có hardcoded hex/px value trong component tokens
□ Naming convention document đã ghi rõ cho developer reference
□ Maturity stage gán cho từng component (Draft / Beta / Stable)
```
