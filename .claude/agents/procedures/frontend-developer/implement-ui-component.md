# Playbook: Implement UI Component

> **Type**: Agent Skill Playbook
> **Agent**: frontend-developer
> **Triggered by**: `/wf-implement-feature` khi cần implement một UI component
> **Output**: UI component có tests, accessibility đầy đủ, và documentation

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi task yêu cầu tạo component mới (Button, Modal, Form, Table, Card, v.v.)
- Khi cần refactor component hiện có để đạt chuẩn accessibility và performance
- Khi cần build reusable component cho design system / component library

---

## Procedure

### Bước 1: Đọc UX design spec và wireframes

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE4 (UX design)

Cần xác định:
□ Component name và mục đích sử dụng
□ Visual states: default, hover, active, disabled, loading, error
□ Responsive behavior: breakpoints, stacking order, hide/show rules
□ Animation/transition expectations
□ Dark mode / theme requirements (nếu có)
□ REQ-ID liên quan — đọc req-registry.json hoặc context từ skill
```

### Bước 2: Đọc design system tokens

```
Xác định design system đang dùng (Tailwind CSS / CSS Modules / styled-components / MUI / v.v.)

Cần extract:
□ Color tokens: primary, secondary, semantic (error, success, warning, info)
□ Typography scale: font-size, font-weight, line-height per role
□ Spacing scale: margin, padding, gap values
□ Border radius, shadow levels
□ Breakpoints: mobile (<768px), tablet (768–1024px), desktop (>1024px)
□ Z-index layer system (dropdown, modal, toast, overlay)

Không hardcode values — luôn dùng token/class từ design system.
```

### Bước 3: Thiết kế Component API

```
Xác định contract của component trước khi viết code:

Props / Inputs:
□ Tên prop rõ ràng, self-explanatory (label thay vì txt)
□ Default values cho props optional
□ Prop types nghiêm ngặt (TypeScript interface / PropTypes)
□ Destructure props với defaults rõ ràng

Events / Outputs / Emits:
□ Convention nhất quán: onClick, onChange, onSubmit (React) / @click, @update (Vue)
□ Event payload shape được định nghĩa rõ

Slots / Children:
□ Có cần slot nội dung không? (compound components, render props, named slots)

Ví dụ API template:
---
interface ButtonProps {
  label: string
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger'
  size?: 'sm' | 'md' | 'lg'
  disabled?: boolean
  loading?: boolean
  onClick?: (event: MouseEvent) => void
}
---
```

### Bước 4: Implement markup và styles

```
Thứ tự implement:
1. Semantic HTML structure (đúng element: button vs div, nav vs ul, article vs div)
2. Base styles → variants → states (hover, focus, disabled, loading)
3. Mobile-first CSS — viết mobile styles trước, dùng min-width media queries
4. Animation/transition — dùng transform + opacity (GPU-accelerated)
   Bắt buộc: @media (prefers-reduced-motion: reduce) { animation: none }

Kiểm tra markup:
□ Dùng đúng HTML element (button cho click, a cho navigation, input cho data entry)
□ Không dùng div/span cho interactive elements trừ khi bắt buộc
□ Form elements có label liên kết đúng (for/id hoặc aria-labelledby)
```

### Bước 5: Responsive breakpoints

```
Mobile-first approach — LUÔN bắt đầu từ màn hình nhỏ nhất:

□ Mobile (<768px): Layout cơ bản, touch target tối thiểu 44×44px
□ Tablet (768px+): Điều chỉnh layout nếu cần (2 cột, sidebar, v.v.)
□ Desktop (1024px+): Layout đầy đủ

Kiểm tra:
□ Text không bị overflow hay truncate sai chỗ
□ Interactive elements đủ touch target size
□ Images có max-width: 100% và không bị stretch
□ Tables có horizontal scroll khi quá hẹp (không vỡ layout)
```

### Bước 6: Accessibility (WCAG 2.1 AA)

```
Checklist bắt buộc — KHÔNG được skip vì deadline:

ARIA roles và attributes:
□ Nếu không dùng semantic HTML → thêm role tương ứng
□ Interactive state: aria-expanded, aria-selected, aria-checked, aria-disabled
□ Loading state: aria-busy="true" + aria-label mô tả hành động
□ Error state: aria-invalid="true" + aria-describedby trỏ đến error message
□ Icon-only buttons: aria-label hoặc aria-labelledby bắt buộc
□ Decorative images: alt="" (empty string, không bỏ attr)

Keyboard navigation:
□ Tab order hợp lý (theo visual order)
□ Enter/Space trigger action cho button-like elements
□ Escape đóng modal/dropdown/overlay
□ Arrow keys cho composite widgets (menu, listbox, tablist, radiogroup)
□ Focus không bị trapped ngoài modal (focus trap trong modal là ĐÚNG)

Focus management:
□ Focus visible — custom :focus-visible styles rõ ràng (outline 2px minimum)
□ Sau khi modal đóng → trả focus về trigger element
□ Sau khi nội dung mới load (SPA navigation) → set focus đúng chỗ

Màu sắc và contrast:
□ Text trên background: contrast ratio tối thiểu 4.5:1 (AA)
□ Large text (18pt+ hoặc 14pt bold): contrast 3:1
□ Không truyền thông tin chỉ bằng màu sắc (luôn kèm icon hoặc text)
```

### Bước 7: Viết unit tests

```
Framework: Vitest/Jest + Testing Library (React Testing Library / Vue Test Utils)

Test structure — mỗi component cần cover:

Render tests:
□ Render thành công với props mặc định (smoke test)
□ Render đúng với mỗi variant (primary, secondary, danger, v.v.)
□ Render đúng với disabled state
□ Render đúng với loading state
□ Snapshot test nếu UI phức tạp và stable

Interaction tests:
□ Click/keyboard trigger đúng event handler
□ Disabled state không trigger event
□ Form validation message hiển thị đúng khi submit sai
□ Toggle state hoạt động đúng (accordion expand/collapse, tab switch, v.v.)

Accessibility tests:
□ Dùng @testing-library/jest-dom → toBeVisible(), toBeDisabled()
□ getByRole() thay vì getByTestId() — test như user thực sự dùng
□ Check aria-label, aria-describedby present khi cần

Ví dụ test pattern:
---
describe('Button', () => {
  it('render với label đúng', () => { ... })
  it('gọi onClick khi click', () => { ... })
  it('không gọi onClick khi disabled', () => { ... })
  it('hiển thị loading spinner khi loading=true', () => { ... })
  it('có aria-label khi icon-only', () => { ... })
})
---

Coverage target: >80% lines + branches cho component mới
```

### Bước 8: Documentation / Storybook

```
Nếu dự án dùng Storybook:
□ Tạo [ComponentName].stories.tsx với tất cả variants
□ Default story với props đầy đủ
□ Controls panel configured (argTypes)
□ A11y addon pass (no violations)

Nếu không có Storybook:
□ JSDoc comment cho component function — props, return value
□ Ví dụ sử dụng trong comment hoặc README của module

Trong mọi trường hợp:
□ PropTypes / TypeScript interface được export (consumer cần import)
□ CHANGELOG hoặc commit message ghi rõ breaking changes nếu có
```

### Bước 9: REQ-ID reference và output

```
Trong file component:
□ Dòng đầu (hoặc ngay trước function declaration): // REQ-ID: [REQ-XXX-NNN]
□ Nếu nhiều REQ-ID: // REQ-ID: REQ-UI-BTN-001, REQ-ACCESS-001

Ghi output vào path do skill cung cấp.
Fallback: src/components/[ComponentName]/[ComponentName].tsx (hoặc .vue/.component.ts)
```

---

## Checklist trước khi submit

```
□ Component có đầy đủ props interface / TypeScript types
□ Tất cả visual states đã implement (default, hover, active, disabled, loading, error)
□ Mobile-first responsive đã apply
□ prefers-reduced-motion đã xử lý
□ WCAG 2.1 AA: ARIA roles, keyboard navigation, focus management, contrast
□ Unit tests pass (>80% coverage)
□ Không hardcode color, spacing — dùng design tokens
□ REQ-ID reference có mặt trong file
□ Không để lại console.log, TODO comment chưa ghi chú lý do
```

---

## Ngưỡng chấp nhận (Acceptance Thresholds)

| Metric | Ngưỡng tối thiểu |
|--------|-----------------|
| Unit test coverage | >80% lines + branches |
| Lighthouse Accessibility | >90 điểm |
| Touch target size | Tối thiểu 44×44px |
| Color contrast (normal text) | 4.5:1 |
| Color contrast (large text) | 3:1 |
| Animation: GPU-accelerated | transform / opacity only |
