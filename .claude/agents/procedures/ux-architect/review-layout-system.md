# Playbook: Review Layout System

> **Type**: Agent Skill Playbook
> **Agent**: ux-architect
> **Triggered by**: `/wf-implement-feature` sau khi implement CSS/layout system, hoặc khi được yêu cầu review
> **Output**: Layout system review report (ghi vào path do skill cung cấp, hoặc console output nếu không có path)

---

## Khi nào dùng playbook này

- Sau khi developer implement CSS architecture / design system lần đầu
- Khi phát hiện visual inconsistency trong UI
- Khi chuẩn bị handoff từ development sang QA
- Khi có PR/MR liên quan đến global styles, design tokens, hoặc layout system

---

## Procedure

### Bước 1: Xác định scope review

```
INPUT: Paths đến code được review (do skill cung cấp qua prompt)
FALLBACK: Hỏi developer hoặc đọc git diff

Xác định:
□ CSS methodology đang dùng: Tailwind / CSS Modules / CSS-in-JS / Vanilla
□ Đọc CSS architecture doc tại: .mc-data/docs/phase4-ux/css-architecture.md (nếu tồn tại)
□ Đọc: .claude/references/team-expert/design/design-system-patterns.md → Section 1-3 (tokens, naming, components)

Scope cần review:
□ Design token definitions và usage
□ File structure theo spec
□ Responsive behavior
□ Dark mode consistency
□ Animation performance
□ CSS specificity
□ Bundle size / performance metrics
□ Component style isolation
□ Cross-browser rendering
```

### Bước 2: Design token usage audit — không được có "magic numbers"

```
Tìm kiếm hardcoded values trong codebase:

Bash commands để scan (chạy từ project root):
---
# Tìm hardcoded colors (hex, rgb, rgba, hsl)
grep -rn --include="*.css" --include="*.scss" --include="*.tsx" --include="*.ts" \
  -E '(#[0-9a-fA-F]{3,8}|rgb\(|rgba\(|hsl\()' src/ \
  | grep -v "//.*#" | grep -v "__tests__"

# Tìm hardcoded pixel values trong CSS (trừ 0px, 1px, 2px border)
grep -rn --include="*.css" --include="*.scss" \
  -E '[^0-9][3-9][0-9]px|[1-9][0-9]{2,}px' src/styles/

# Tìm hardcoded font-size
grep -rn --include="*.css" --include="*.tsx" \
  -E 'font-size:\s*[0-9]+px' src/
---

Issues cần flag:
□ Hardcoded color values → Thay bằng semantic token
□ Hardcoded pixel spacing → Thay bằng spacing scale token
□ Hardcoded font-size → Thay bằng typography token
□ Magic z-index numbers → Định nghĩa z-index scale (overlay: 100, modal: 200, toast: 300)

Severity:
- CRITICAL: Hardcoded colors (sẽ vỡ dark mode)
- HIGH: Hardcoded spacing > 8px (sẽ vỡ layout consistency)
- MEDIUM: Hardcoded z-index (sẽ gây stacking issues)
- LOW: Hardcoded border-radius (aesthetic inconsistency)
```

### Bước 3: CSS specificity issues

```
Review CSS specificity để đảm bảo không có specificity wars:

Kiểm tra:
□ Có selector nào dùng ID (#id) để style không? → Chuyển sang class
□ Có !important nào ngoài utility classes không? → Xem xét lại
□ Có selector dài hơn 3 cấp không? (.parent .child .grandchild) → Refactor
□ Có selector nesting quá sâu không? (nếu dùng SCSS/Sass)

Dấu hiệu specificity conflict:
□ Style override không hoạt động → Dev thêm !important → cascade bị phá vỡ
□ Component style bị ảnh hưởng bởi global styles → Style isolation không tốt
□ Order-dependent styles: Di chuyển import order là vỡ → Cần fix

Specificity scoring:
□ Inline style: (1,0,0,0) — tránh dùng trừ dynamic values
□ ID: (0,1,0,0) — không dùng cho styling
□ Class: (0,0,1,0) — đây là mức mục tiêu
□ Element: (0,0,0,1) — chỉ dùng trong reset/base styles
```

### Bước 4: Responsive behavior testing

```
Review responsive breakpoints và behavior:

Đọc CSS architecture spec để biết breakpoints đã được định nghĩa:
□ Mobile: < 768px
□ Tablet: 768px - 1023px
□ Desktop: 1024px+
□ Large: 1280px+ (nếu có)

Kiểm tra từng breakpoint:

MOBILE (375px — iPhone SE):
□ Không có horizontal overflow (dùng max-width: 100% cho images)
□ Touch targets ≥ 44×44px
□ Text không bị truncate quan trọng
□ Navigation collapsible và functional
□ Forms single-column, input size phù hợp
□ Không có fixed elements che content chính

TABLET (768px):
□ Layout transition mượt (không bị jump)
□ 2-column layouts hoạt động đúng
□ Sidebar behavior: inline hay overlay?

DESKTOP (1024px+):
□ Max-width container không bị vỡ
□ Sidebar fully expanded
□ Tables đủ columns không bị ẩn

Content reflow test (WCAG 1.4.10):
□ Zoom 200% không cần horizontal scroll trên viewport 1280px
□ Font resize (browser setting) không vỡ layout
□ Text spacing override không vỡ layout (WCAG 1.4.12)
```

### Bước 5: Performance audit

```
A. Bundle size check:

Bash commands:
---
# Nếu Vite build
npx vite build --mode production 2>&1 | grep -E "(css|js)\s+[0-9]"

# Phân tích CSS bundle
npx vite-bundle-visualizer

# Nếu Webpack
npx webpack-bundle-analyzer dist/stats.json
---

Targets cần đạt:
□ Total CSS bundle: < 50KB gzipped
□ Critical (above-fold) CSS: < 14KB
□ Không có CSS được load mà không dùng > 30%

B. Render-blocking CSS check:
□ Critical CSS có được inline trong <head> không?
□ Non-critical stylesheets có dùng media="print" preload trick không?
□ Google Fonts có dùng display=swap không?

C. Unused CSS check:
---
# Với PurgeCSS
npx purgecss --css dist/assets/*.css --content src/**/*.tsx src/**/*.html --output /tmp/purge-report

# Với Tailwind (check coverage report)
npx tailwindcss --content './src/**/*.{tsx,html}' -o /tmp/tw-used.css
wc -c /tmp/tw-used.css
---

□ Unused CSS < 5% sau purge (nếu Tailwind: check config content paths)
```

### Bước 6: Component isolation verification

```
Kiểm tra style encapsulation boundaries:

Test 1: Style leak test
□ Thêm class test vào một component → CSS có ảnh hưởng component khác không?
□ Nếu có → Style isolation bị vỡ → Cần fix scoping

Test 2: Global pollution check
---
# Tìm selectors quá rộng trong component files
grep -rn --include="*.module.css" -E '^(div|p|span|h[1-6]|a|button|input)\s*\{' src/components/
---
□ Component CSS không được select bare HTML elements (div, p, span)
□ Chỉ select .class-name bên trong component scope

Test 3: CSS Modules hash verification (nếu dùng CSS Modules)
□ Build và inspect DOM — class names có dạng Button_primary__abc123 không?
□ Nếu không có hash → CSS Modules không được apply đúng

Test 4: Theme inheritance
□ Component không hardcode theme colors → inherit từ CSS variables
□ Swap [data-theme] attribute → component tự động update appearance
```

### Bước 7: Dark mode consistency

```
Systematic dark mode review:

Bước 1: Toggle dark mode và scan toàn bộ app
□ Sử dụng browser DevTools → Emulate prefers-color-scheme: dark
□ Hoặc toggle [data-theme="dark"] trên <html>

Checklist per component:
□ Background colors cập nhật đúng
□ Text colors đủ contrast (minimum 4.5:1 text, 3:1 large text)
□ Border colors visible
□ Shadow visible (shadows cần adjust trong dark mode)
□ Icon colors (SVG stroke/fill) cập nhật
□ Placeholder text có đủ contrast
□ Disabled states vẫn đủ contrast (lower nhưng không invisible)
□ Focus rings visible trên dark background

Common dark mode bugs:
□ Hardcoded color không wrap trong theme token → CRITICAL
□ Box shadow quá nhạt → MEDIUM
□ Placeholder text quá tối → MEDIUM
□ Images quá bright → LOW (có thể fix với CSS filter: brightness(0.8) trong dark mode)

Contrast ratio check:
---
# Dùng browser extension: axe DevTools hoặc Colour Contrast Analyser
# Hoặc check programmatically:
# Text trên background: WCAG AA = 4.5:1, AAA = 7:1
# Large text (18pt+ / 14pt bold): WCAG AA = 3:1
---
```

### Bước 8: Animation performance

```
Kiểm tra GPU acceleration và jank:

A. GPU layer check (Chrome DevTools):
□ Mở DevTools → More tools → Layers
□ Animated elements nên có composited layer (màu xanh trong Layers panel)
□ Quá nhiều layers → memory pressure → check necessary

B. Properties being animated (BẮT BUỘC):
---
# Tìm animation của non-GPU properties
grep -rn --include="*.css" --include="*.ts" \
  -E 'transition:.*(width|height|top|left|margin|padding|border-width)' src/
---

□ Chỉ animate: transform, opacity, filter → GPU-composited
□ KHÔNG animate: width, height, top, left, margin, padding → trigger layout
□ Nếu cần thay đổi size → dùng transform: scale() thay vì width/height

C. Jank check (Chrome DevTools):
□ Performance tab → Record → Trigger animations
□ Frame rate nên stable 60fps (16ms per frame)
□ Tìm "Long frames" (>50ms) → xem stack trace để tìm bottleneck

D. will-change abuse:
---
grep -rn --include="*.css" "will-change" src/
---
□ will-change: transform chỉ áp dụng cho elements animate thực sự
□ Không apply will-change cho toàn bộ card/container

E. prefers-reduced-motion:
---
grep -rn --include="*.css" "prefers-reduced-motion" src/styles/
---
□ Mọi keyframe animation PHẢI có @media (prefers-reduced-motion: reduce) fallback
□ Transition duration có thể reduce, nhưng không remove hoàn toàn (UX cần feedback)
```

### Bước 9: Cross-browser rendering

```
Target: Chrome/Edge latest 2, Firefox latest 2, Safari 15+
□ Verify CSS features support: Container Queries (Chrome 105+), :has() (Safari 15.4+), @layer
□ Autoprefixer configured đúng (.browserslistrc)
□ Safari issues: sticky in flex, backdrop-filter prefix, gap in flex
□ iOS: 100vh → dùng dvh, font-size ≥16px tránh zoom khi focus input
```

### Bước 10: Output — Review Report

```
Ghi vào path do skill cung cấp.
Nếu không có path: in ra console output trong response.

Format output:
```

---

## Layout System Review Report

**Reviewed by**: ux-architect
**Date**: [current date]
**Scope**: [CSS methodology + files reviewed]
**CSS Architecture spec**: [Có / Không — link nếu có]

---

### Tổng quan: [PASS / NEEDS ATTENTION / FAIL]

| Hạng mục | Status | Critical Issues |
|---------|--------|----------------|
| Design token usage | ✅ / ⚠️ / ❌ | [count] |
| CSS specificity | ✅ / ⚠️ / ❌ | [count] |
| Responsive behavior | ✅ / ⚠️ / ❌ | [count] |
| Bundle performance | ✅ / ⚠️ / ❌ | [count] |
| Component isolation | ✅ / ⚠️ / ❌ | [count] |
| Dark mode consistency | ✅ / ⚠️ / ❌ | [count] |
| Animation performance | ✅ / ⚠️ / ❌ | [count] |
| Cross-browser | ✅ / ⚠️ / ❌ | [count] |

---

### Critical Issues (Cần fix trước khi merge/deploy)

- [ ] **[Issue title]**: [Location: file:line] → [Required fix]
- [ ] ...

### Important Issues (Fix trong sprint tiếp theo)

- [ ] **[Issue title]**: [Location] → [Recommendation]
- [ ] ...

### Suggestions (Nice-to-have)

- [ ] [Suggestion]
- [ ] ...

---

### Chi tiết theo hạng mục

#### Design Tokens
[List magic numbers tìm thấy và đề xuất token thay thế]

#### Responsive
[Screenshot/description của issues tìm thấy per breakpoint]

#### Performance Metrics
- Total CSS bundle: [X]KB gzipped (target: <50KB)
- Critical CSS: [X]KB (target: <14KB)
- Unused CSS: [X]% (target: <5%)

#### Dark Mode Issues
[List components cần fix với contrast ratio cụ thể]

#### Animation Issues
[List animated properties không phải GPU-composited]

---

### Sign-off

```
□ Design token usage: OK / ISSUE ([n] magic numbers found)
□ Specificity: OK / ISSUE
□ Responsive: OK / ISSUE
□ Performance: OK / ISSUE
□ Component isolation: OK / ISSUE
□ Dark mode: OK / ISSUE
□ Animation: OK / ISSUE
□ Cross-browser: OK / ISSUE
```

**Verdict**: APPROVED / APPROVED WITH CONDITIONS / BLOCKED

[Nếu BLOCKED: Liệt kê cụ thể điều kiện để approve]

```

---

## Checklist trước khi submit report

```
□ Đã kiểm tra tất cả 8 hạng mục
□ Critical issues có location cụ thể (file:line)
□ Severity được phân loại đúng (Critical / Important / Suggestion)
□ Performance metrics có số liệu cụ thể, không chỉ "chậm" hay "nặng"
□ Dark mode: contrast ratio được check bằng tool, không chỉ nhìn bằng mắt
□ Verdict rõ ràng và có action items cụ thể
```
