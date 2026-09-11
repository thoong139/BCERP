# Design System - Architecture Patterns & Standards

> **Domain**: Design / Design System
> **Last Updated**: 2026-03-15
> **Nguồn**: Design system best practices từ Material Design 3, Apple HIG, Atlassian Design System, Radix UI

---

## 1. Design Token Hierarchy

Token được tổ chức theo 3 tầng, từ giá trị thô đến ý nghĩa ngữ cảnh:

```
Primitive Tokens (Raw values)
  ↓
Semantic Tokens (Meaning-based)
  ↓
Component Tokens (Component-specific)
```

### Ví dụ Token Cascade

```
primitive.color.blue.500 = #3B82F6
  ↓
semantic.color.action.primary = {primitive.color.blue.500}
  ↓
component.button.background.primary = {semantic.color.action.primary}
```

**Nguyên tắc:** Component không reference trực tiếp primitive token — qua semantic layer. Điều này cho phép rebrand toàn bộ hệ thống chỉ bằng cách thay đổi semantic mapping.

---

## 2. Token Naming Convention

### Color Tokens

| Tầng | Format | Ví dụ |
|------|--------|-------|
| Primitive | `color.[hue].[scale]` | `color.blue.500`, `color.neutral.100` |
| Semantic | `color.[role].[variant]` | `color.surface.primary`, `color.text.muted` |
| Component | `[component].color.[element].[state]` | `button.color.background.hover` |

### Typography Tokens

| Token | Format | Ví dụ |
|-------|--------|-------|
| Font family | `font.family.[type]` | `font.family.sans`, `font.family.mono` |
| Font size | `font.size.[step]` | `font.size.sm`, `font.size.2xl` |
| Font weight | `font.weight.[name]` | `font.weight.regular`, `font.weight.bold` |
| Line height | `font.lineHeight.[density]` | `font.lineHeight.tight`, `font.lineHeight.relaxed` |

### Spacing Tokens

| Token | Value | Use case |
|-------|-------|----------|
| `spacing.1` | 4px | Internal component padding nhỏ |
| `spacing.2` | 8px | Gap giữa elements inline |
| `spacing.3` | 12px | Padding nội tại vừa |
| `spacing.4` | 16px | Padding chuẩn (base unit) |
| `spacing.6` | 24px | Section spacing nhỏ |
| `spacing.8` | 32px | Section spacing vừa |
| `spacing.12` | 48px | Section spacing lớn |
| `spacing.16` | 64px | Layout-level spacing |

### Elevation & Border Radius Tokens

| Token | Value | Dùng cho |
|-------|-------|---------|
| `elevation.0` | none | Flat surface |
| `elevation.1` | `0 1px 3px rgba(0,0,0,0.12)` | Card, dropdown |
| `elevation.2` | `0 4px 12px rgba(0,0,0,0.15)` | Modal, panel |
| `elevation.3` | `0 8px 24px rgba(0,0,0,0.20)` | Popover, toast |
| `radius.sm` | 4px | Badge, chip |
| `radius.md` | 8px | Button, input |
| `radius.lg` | 12px | Card, modal |
| `radius.full` | 9999px | Pill, avatar |

---

## 3. Component Maturity Model

| Stage | Icon | Ý nghĩa | Sử dụng được? |
|-------|------|---------|---------------|
| **Planned** | 📋 | Đang trong roadmap, chưa có design | Không |
| **Draft** | 🔶 | Có design, đang viết spec | Chỉ prototype |
| **Beta** | 🔵 | Có code, đang test trong production | Có — với caveat |
| **Stable** | ✅ | Đã test, documented, stable API | Có — khuyến khích |
| **Deprecated** | 🚫 | Sẽ bị xóa — có migration guide | Không dùng mới |

**Promotion Criteria từ Beta → Stable:**
- Unit test coverage ≥ 90%
- Accessibility audit pass (WCAG AA)
- Đã dùng trong ≥ 2 product surfaces
- API stable (không breaking changes 2 sprints)
- Documentation đầy đủ (props, examples, do/don't)

---

## 4. Component API Design Principles

### Props Naming Conventions

| Pattern | Đúng | Sai | Lý do |
|---------|------|-----|-------|
| Boolean | `isDisabled`, `isLoading` | `disabled`, `loading` | Rõ ràng type, tránh nhầm lẫn |
| Event handler | `onPress`, `onChange` | `click`, `handleChange` | Nhất quán với React conventions |
| Variant | `variant="primary"` | `isPrimary`, `type="primary"` | Scale tốt khi thêm variants |
| Size | `size="md"` | `isSmall`, `large` | Dễ extend |
| Children | `label` (text) / `children` (React node) | `content`, `text` | Semantic rõ ràng |

### Composition Patterns

**Slots Pattern** — Cho phép inject nội dung vào vị trí xác định:
```tsx
<Card>
  <Card.Header>Title</Card.Header>
  <Card.Body>Content</Card.Body>
  <Card.Footer>Actions</Card.Footer>
</Card>
```

**Compound Components** — Chia sẻ state ngầm giữa các sub-components:
```tsx
<Tabs defaultValue="tab1">
  <Tabs.List>
    <Tabs.Trigger value="tab1">Tab 1</Tabs.Trigger>
  </Tabs.List>
  <Tabs.Content value="tab1">...</Tabs.Content>
</Tabs>
```

### Variant × Size × State Matrix Template

| | `sm` | `md` | `lg` |
|--|------|------|------|
| `primary` | ✅ | ✅ | ✅ |
| `secondary` | ✅ | ✅ | ✅ |
| `ghost` | ✅ | ✅ | ✅ |
| `destructive` | ❌ | ✅ | ✅ |

**States cần cover cho mọi interactive component:** `default`, `hover`, `focus`, `active`, `disabled`, `loading`, `error`

---

## 5. Color System Architecture

### Brand → Semantic → Component

```
Brand Colors (Identity)
├── brand.primary   = #6366F1   (Indigo)
├── brand.secondary = #EC4899   (Pink)
└── brand.accent    = #F59E0B   (Amber)
  ↓
Semantic Colors (Meaning)
├── color.action.primary    → brand.primary
├── color.action.destructive → #EF4444
├── color.feedback.success  → #22C55E
├── color.feedback.warning  → #F59E0B
├── color.feedback.error    → #EF4444
├── color.feedback.info     → #3B82F6
├── color.surface.default   → #FFFFFF (light) / #0F172A (dark)
├── color.surface.subtle    → #F8FAFC (light) / #1E293B (dark)
└── color.text.default      → #0F172A (light) / #F1F5F9 (dark)
```

### Light/Dark Mode Token Mapping

| Semantic Token | Light Mode | Dark Mode |
|----------------|------------|-----------|
| `surface.default` | `#FFFFFF` | `#0F172A` |
| `surface.subtle` | `#F8FAFC` | `#1E293B` |
| `surface.overlay` | `rgba(0,0,0,0.5)` | `rgba(0,0,0,0.7)` |
| `text.default` | `#0F172A` | `#F1F5F9` |
| `text.muted` | `#64748B` | `#94A3B8` |
| `text.disabled` | `#CBD5E1` | `#334155` |
| `border.default` | `#E2E8F0` | `#1E293B` |
| `border.strong` | `#94A3B8` | `#475569` |

---

## 6. Typography Scale (Type Ramp)

| Step | Token | Size | Weight | Line Height | Dùng cho |
|------|-------|------|--------|-------------|---------|
| Display | `text.display` | 48px / 3rem | 700 | 1.1 | Hero headings |
| H1 | `text.h1` | 36px / 2.25rem | 700 | 1.2 | Page title |
| H2 | `text.h2` | 28px / 1.75rem | 600 | 1.25 | Section title |
| H3 | `text.h3` | 22px / 1.375rem | 600 | 1.3 | Subsection |
| H4 | `text.h4` | 18px / 1.125rem | 600 | 1.35 | Card title |
| Body LG | `text.body.lg` | 18px / 1.125rem | 400 | 1.6 | Lead text |
| Body | `text.body` | 16px / 1rem | 400 | 1.6 | Default body |
| Body SM | `text.body.sm` | 14px / 0.875rem | 400 | 1.5 | Secondary text |
| Caption | `text.caption` | 12px / 0.75rem | 400 | 1.4 | Labels, meta |
| Overline | `text.overline` | 11px / 0.6875rem | 500 | 1.4 | Category tags (uppercase) |

**Responsive scaling:** Dùng `clamp()` cho display và h1:
```css
font-size: clamp(2rem, 4vw + 1rem, 3rem);
```

---

## 7. Spacing System (4px/8px Grid)

**Base unit:** 4px. Mọi spacing value là bội số của 4.

```
Micro  (4px)  → spacing giữa icon và label
Small  (8px)  → gap inline, padding tight
Base   (16px) → padding chuẩn, gap grid
Medium (24px) → gap giữa components
Large  (32px) → section padding
XL     (48px) → layout section gap
2XL    (64px) → page-level padding
```

**8px grid rule:** Các major layout elements (cards, panels, containers) align theo 8px grid. Các micro-elements (icon padding, badge) có thể dùng 4px.

---

## 8. Icon System Guidelines

| Property | Specification |
|----------|--------------|
| Grid size | 24×24px (default), 16×16 (small), 32×32 (large) |
| Stroke width | 1.5px (default), scale proportionally |
| Corner radius | 2px cho các góc cạnh thẳng |
| Naming | `[category]-[name]` → `arrow-right`, `user-circle` |
| Format | SVG với viewBox="0 0 24 24" |
| Stroke vs Fill | Stroke icons cho UI, Fill icons cho decorative |

---

## 9. Motion & Animation Tokens

| Token | Value | Dùng cho |
|-------|-------|---------|
| `duration.instant` | 0ms | State toggle không animate |
| `duration.fast` | 100ms | Micro-interactions (hover, focus) |
| `duration.normal` | 200ms | Component transitions (dropdown open) |
| `duration.slow` | 300ms | Page transitions, modal open |
| `duration.deliberate` | 500ms | Onboarding, celebrations |
| `easing.standard` | `cubic-bezier(0.4, 0, 0.2, 1)` | Mọi transitions thông thường |
| `easing.enter` | `cubic-bezier(0, 0, 0.2, 1)` | Elements xuất hiện |
| `easing.exit` | `cubic-bezier(0.4, 0, 1, 1)` | Elements biến mất |
| `easing.spring` | `cubic-bezier(0.16, 1, 0.3, 1)` | Bounce/magnetic effects |

**GPU-accelerated properties:** Chỉ animate `transform` và `opacity` để đảm bảo 60fps. Tránh animate `width`, `height`, `top`, `left`.

---

## 10. Design-to-Code Handoff Checklist

Trước khi bàn giao design cho developer, designer phải verify:

| Hạng mục | Kiểm tra |
|---------|---------|
| **Tokens** | Mọi color, spacing, typography dùng token — không hardcode value |
| **States** | Đủ 7 states: default, hover, focus, active, disabled, loading, error |
| **Responsive** | Có breakpoint design cho mobile (375px), tablet (768px), desktop (1280px) |
| **Dark mode** | Token mapping đã define (nếu yêu cầu dark mode) |
| **Accessibility** | Contrast ratio đã check, focus indicator visible |
| **Empty state** | Có design cho trạng thái không có data |
| **Error state** | Có design cho lỗi validation, lỗi server |
| **Loading state** | Skeleton hoặc spinner đã design |
| **Naming** | Layer và component đặt tên rõ ràng, không có "Group 1", "Rectangle 3" |
| **Specs** | Auto-layout hoặc annotation rõ spacing, sizing |
| **Assets** | Icon, image đã export đúng format (SVG, WebP/PNG 2x) |
