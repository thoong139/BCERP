# Playbook: Review UI Implementation

> **Type**: Agent Skill Playbook
> **Agent**: ui-designer
> **Triggered by**: /wf-implement-feature (post-implementation) khi review UI code
> **Output**: UI implementation review report tại `.mc-data/docs/phase4-ux/reviews/[feature-name]-ui-review.md`

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` sau khi developer implement xong UI component hoặc page
- Khi cần validate implementation so với design spec
- Khi cần kiểm tra design token usage (không có hardcoded values)
- Khi cần audit accessibility của UI đã implement
- Khi cần detect design debt trước khi merge

---

## Procedure

### Bước 1: Xác định scope review

```
INPUT: Paths do skill cung cấp qua prompt
Cần xác định:
□ Feature/component nào đang được review?
□ Đây là component riêng lẻ hay full page?
□ Đường dẫn source code cần review
□ Design spec tham chiếu ở đâu (PHASE4/layouts/ hoặc PHASE4/design-system/)

Load design spec:
□ Component spec: .mc-data/docs/phase4-ux/design-system/component-library.md
□ Page layout spec: .mc-data/docs/phase4-ux/layouts/[page-name]-layout.md
□ UX spec gốc: .mc-data/docs/phase4-ux/wireframes/ (nếu có)
```

### Bước 2: Load knowledge references

```
READ: .claude/references/team-expert/design/design-system-patterns.md
  → Section 2: Token naming conventions (để verify đúng tên)
  → Section 10: Design-to-Code Handoff Checklist

READ: .claude/references/team-expert/design/accessibility-checklist.md
  → Section 2: Color contrast ratios
  → Section 4: Keyboard navigation checklist
  → Section 5: Touch target sizes
  → Section 7: ARIA quick reference
  → Section 8: Common component accessibility patterns
```

### Bước 3: Review Design Token Usage

Đây là bước quan trọng nhất — không hardcode giá trị là nguyên tắc cốt lõi.

```
SCAN source code (CSS/SCSS/styled-components/Tailwind/inline styles):

Tìm kiếm hardcoded values:
□ Grep màu hex: /#[0-9a-fA-F]{3,6}/
□ Grep pixel values: /\d+px/ (ngoại trừ border-width 1px, border-radius nhỏ)
□ Grep rgba/rgb: /rgb(a?)\(/
□ Grep hardcoded font-size px
□ Grep hardcoded font-weight numbers ngoài token

Mỗi hardcoded value tìm thấy:
  → Ghi lại: File, dòng, value
  → Đề xuất token thay thế: --color-*, --spacing-*, --font-size-*, v.v.
  → Severity: ERROR (màu sắc quan trọng, spacing lớn) / WARNING (giá trị nhỏ)

Verify token names đúng convention:
  Đúng:  --color-action-primary, --spacing-4, --font-size-base
  Sai:   --primary-color, --space-medium, --text-size
```

### Bước 4: Review Component Consistency

```
So sánh implementation với component spec (component-library.md):

□ VARIANTS: Đủ variants đã spec chưa? (primary, secondary, ghost, v.v.)
□ SIZES: Size props hoạt động đúng không? (sm/md/lg mapping đúng px)
□ STATES:
    □ Hover state: có transition? Dùng đúng token?
    □ Focus state: :focus-visible có outline đúng spec? (2px solid, offset 2px)
    □ Active state: có visual feedback không?
    □ Disabled: cursor: not-allowed? opacity đúng không?
    □ Loading: spinner hiển thị, button disabled?
    □ Error: border màu error, icon error, error message text?
□ SPACING: Padding/margin dùng đúng spacing tokens không?
□ TYPOGRAPHY: Font-size, weight dùng đúng tokens không?
□ BORDER RADIUS: Dùng --radius-* tokens không?
□ SHADOW: Dùng --shadow-* tokens không?
```

### Bước 5: Review Responsive Behavior

```
Kiểm tra tại các breakpoints quan trọng:

□ 320px:
    □ Không có horizontal overflow
    □ Text không bị cắt
    □ Buttons vẫn readable
    □ Forms vẫn usable

□ 375px (mobile standard):
    □ Layout chính xác theo layout spec (mobile)
    □ Navigation pattern đúng (bottom nav / hamburger)
    □ Touch targets ≥ 44px

□ 768px (tablet portrait):
    □ Layout transition mượt từ mobile
    □ Grid columns thay đổi đúng spec

□ 1024px (desktop breakpoint):
    □ Desktop layout active
    □ Sidebar, navigation đúng vị trí

□ 1280px+ (large desktop):
    □ Max-width container hoạt động
    □ Không có content quá rộng

Cách kiểm tra (ghi lại method dùng):
  - Browser DevTools responsive mode
  - CSS media query logic review
  - Verify breakpoint values khớp với layout spec
```

### Bước 6: Review Accessibility Implementation

```
READ: accessibility-checklist.md → áp dụng toàn bộ

**6.1 Color Contrast:**
□ Text thường: contrast ratio ≥ 4.5:1
□ Text lớn (≥ 18pt hoặc 14pt bold): contrast ratio ≥ 3:1
□ UI components (border, icon, input): contrast ratio ≥ 3:1
□ Placeholder text: THƯỜNG FAIL (mặc định #9CA3AF trên #FFF = 2.4:1) — cần check
□ Disabled state text: ghi rõ nếu dưới 3:1 (acceptable nhưng phải documented)

Công cụ verify: Chrome DevTools CSS Overview → Colors → Contrast issues

**6.2 Focus Indicators:**
□ :focus-visible có visible outline không? (outline: none mà không có replacement = FAIL)
□ Outline đúng spec: 2px solid, offset 2px, contrast ≥ 3:1 với nền
□ Không có element interactive bị mất focus indicator

**6.3 ARIA Implementation:**
□ Modals: role="dialog" + aria-modal + aria-labelledby
□ Buttons icon-only: aria-label mô tả action
□ Form inputs: label liên kết (for/id) hoặc aria-label
□ Form errors: aria-invalid="true" + aria-describedby trỏ tới error message
□ Dropdowns: aria-haspopup + aria-expanded
□ Loading states: aria-busy="true" trên element đang load
□ Status messages: aria-live="polite" container
□ Error alerts: role="alert" hoặc aria-live="assertive"

**6.4 Keyboard Navigation:**
□ Tab order logic (trái → phải, trên → xuống)
□ Không có keyboard trap (trừ modal — trap là đúng khi modal mở)
□ Modal focus trap: Tab/Shift+Tab không thoát ra ngoài modal
□ Modal close: Escape key hoạt động
□ Dropdown: Arrow keys navigate items, Escape đóng
□ Tabs component: Arrow keys chuyển tab, Enter/Space activate

**6.5 Touch Targets:**
□ Interactive elements có minimum 44×44px touch area
□ Nếu visual size nhỏ hơn → dùng padding hoặc ::after pseudo-element mở rộng

**6.6 Semantic HTML:**
□ Buttons dùng <button>, không dùng <div onClick>
□ Links dùng <a href>, không dùng <span onClick>
□ Forms dùng <form>, <label>, <input> đúng
□ Navigation dùng <nav>
□ Lists dùng <ul>/<ol>/<li> khi là danh sách thực sự
□ Headings theo đúng hierarchy (H1 → H2 → H3, không skip)
```

### Bước 7: Review Animation và Transition

```
□ Chỉ animate transform và opacity (GPU-accelerated) — không animate width/height/top/left
□ Duration dùng đúng token:
    Hover/focus: --duration-fast (100ms)
    Component state change: --duration-normal (200ms)
    Modal/drawer open: --duration-slow (300ms)
□ Easing dùng đúng token:
    Transitions thông thường: --easing-standard
    Elements xuất hiện: --easing-enter
    Elements biến mất: --easing-exit
□ prefers-reduced-motion: animation bị disable hoặc reduce khi user setting này active
    @media (prefers-reduced-motion: reduce) { animation: none; transition: none; }
□ Không có animation gây distraction hoặc flicker
□ Loading animations: không quá 3 giây continuous, có thể dừng/pause
```

### Bước 8: Review Cross-Browser Consistency

```
Các CSS properties cần verify cross-browser:
□ CSS Custom Properties (IE11 không support — kiểm tra có fallback không nếu cần support)
□ CSS Grid / Flexbox — verify trên Safari cũ (gap trong flex)
□ :focus-visible — Safari cũ cần polyfill
□ backdrop-filter (blur) — cần fallback cho Firefox cũ
□ clamp() — check browser support nếu dùng
□ aspect-ratio — cần fallback

Browsers cần test (theo yêu cầu dự án):
□ Chrome (latest)
□ Firefox (latest)
□ Safari (latest — đặc biệt các CSS features mới)
□ Edge (latest)
□ Mobile Safari (iOS)
□ Chrome Android
```

### Bước 9: Review Performance

```
□ Images:
    □ Dùng định dạng WebP với PNG fallback
    □ Có width + height attributes để tránh CLS (Cumulative Layout Shift)
    □ Loading lazy cho images không trong viewport đầu
    □ srcset cho responsive images

□ Fonts:
    □ font-display: swap để tránh FOIT
    □ Preload critical fonts
    □ Không load quá 2-3 font families

□ CSS:
    □ Không có unused CSS nặng
    □ Critical CSS inline (nếu SSR)

□ Icons:
    □ Dùng SVG sprite hoặc icon component, không individual img requests
    □ SVG có aria-hidden="true" khi decorative
```

### Bước 10: Design Debt Tracking

```
Ghi lại tất cả issues không block go-live nhưng cần track:

Format mỗi debt item:
  - ID: DEBT-UI-[NNN]
  - Component/Page: [tên]
  - Vấn đề: [mô tả ngắn]
  - Impact: Low / Medium / High
  - Effort to fix: Small (< 1h) / Medium (1-4h) / Large (> 4h)
  - Recommended fix: [đề xuất cụ thể]
  - Sprint suggested: [sprint nào nên fix]
```

### Bước 11: Output — Review Report

```
Ghi vào: .mc-data/docs/phase4-ux/reviews/[feature-name]-ui-review.md

Format report:
```

```markdown
# UI Implementation Review: [Feature / Component Name]

**Ngày review**: [date]
**Reviewer**: ui-designer
**Scope**: [Mô tả những gì đã review]
**Design spec tham chiếu**: [paths]
**Source code reviewed**: [paths]

---

## Kết quả tổng quan

| Hạng mục | Trạng thái |
|----------|-----------|
| Design Token Usage | PASS / FAIL / PARTIAL |
| Component Consistency | PASS / FAIL / PARTIAL |
| Responsive Behavior | PASS / FAIL / PARTIAL |
| Accessibility | PASS / FAIL / PARTIAL |
| Animation/Transition | PASS / FAIL / PARTIAL |
| Performance | PASS / FAIL / PARTIAL |

**Verdict**: ✅ APPROVED / ❌ BLOCKED / ⚠️ APPROVED WITH CONDITIONS

---

## Lỗi Critical (Block merge)

> Lỗi này phải sửa trước khi merge vào main branch.

| ID | File | Dòng | Vấn đề | Token/Fix đề xuất |
|----|------|------|--------|-------------------|
| C-001 | components/Button.css | 24 | Hardcoded `color: #3B82F6` | `var(--color-action-primary)` |
| C-002 | pages/Dashboard.tsx | 87 | Button có touch target 28px | Thêm min-height: 44px |

---

## Lỗi Important (Sửa trước sprint kế tiếp)

| ID | File | Vấn đề | Đề xuất |
|----|------|--------|---------|
| I-001 | | | |

---

## Design Debt (Track và fix theo kế hoạch)

| ID | Component | Vấn đề | Impact | Effort | Sprint |
|----|-----------|--------|--------|--------|--------|
| DEBT-UI-001 | | | | | |

---

## Điểm tốt (ghi nhận để nhân rộng)

- [Điều nào đó implementation làm đúng / tốt hơn spec]

---

## Accessibility Checklist

| Tiêu chí | Status | Ghi chú |
|----------|--------|---------|
| Color contrast ≥ 4.5:1 (normal text) | PASS / FAIL | |
| Color contrast ≥ 3:1 (large text + UI) | PASS / FAIL | |
| Focus indicators visible (2px outline) | PASS / FAIL | |
| Keyboard navigation đầy đủ | PASS / FAIL | |
| ARIA labels đúng | PASS / FAIL | |
| Touch targets ≥ 44px | PASS / FAIL | |
| prefers-reduced-motion respected | PASS / FAIL | |
| Semantic HTML correct | PASS / FAIL | |
| Heading hierarchy đúng | PASS / FAIL | |

---

## Sign-off

□ Design token usage: OK / ISSUES FOUND
□ Component spec compliance: OK / ISSUES FOUND
□ Responsive behavior: OK / ISSUES FOUND
□ Accessibility: OK / ISSUES FOUND
□ Performance: OK / ISSUES FOUND
```

---

## Checklist trước khi submit review

```
□ Đã đọc design spec trước khi review code
□ Đã check tất cả hardcoded values (hex, px)
□ Đã verify focus indicators cho mọi interactive element
□ Đã check contrast ratio của text và UI components
□ Đã verify responsive tại 320px, 768px, 1024px
□ Đã check ARIA attributes cho custom interactive components
□ Đã note tất cả design debt với ID và estimated effort
□ Verdict rõ ràng: APPROVED / BLOCKED / APPROVED WITH CONDITIONS
□ Critical issues có đề xuất fix cụ thể (không chỉ nói "sai")
```
