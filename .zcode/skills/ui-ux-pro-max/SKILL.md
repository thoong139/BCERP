---
name: ui-ux-pro-max
version: 2.2.0
last_updated: 2026-03-22
description: |
  UI/UX design intelligence với 50+ styles, 97 color palettes, 57 font pairings, và 9 tech stacks.

  TRIGGER khi:
  - Làm việc với UI code (.html, .css, .tsx, .vue, .svelte)
  - Thiết kế websites, landing pages, dashboards, admin panels
  - E-commerce, SaaS, mobile apps
  - Individual components (buttons, forms, cards, tables, charts, navbars)
  - Styles: glassmorphism, minimalism, brutalism
  - Accessibility, animation, responsive design

  KHÔNG trigger khi:
  - Backend logic không liên quan UI
  - Database design
  - API implementation

compatibility:
  - python3
argument-hint: "[--design-system] [--domain=<domain>] [--stack=<stack>] <query>"
disable-model-invocation: true
allowed-tools: Read, Bash, Write
---

# UI/UX Pro Max - Design Intelligence

## Overview

| Mục | Nội dung |
|-----|----------|
| **Domain** | UI/UX Design |
| **Capabilities** | Design system generation, Style recommendations, Color palettes, Font pairings |
| **Use Cases** | New UI projects, Design system creation, Component styling |

```
Khi cần: UI/UX design guidance
Dùng: /ui-ux-pro-max "[query]" [--design-system] [--domain=<domain>] [--stack=<stack>]

Input:  Product description, style keywords
Output: Design recommendations, color palettes, typography
```

---

## Workflow Position

```
/wf-design (Phase 3: UX) → /ui-ux-pro-max ← STANDALONE TOOL → /wf-implement-feature
```

> Skill bổ trợ — có thể dùng độc lập hoặc kết hợp với `/wf-design` Phase 3 UX.
> KHÔNG phải bước bắt buộc trong workflow chính.

## Prerequisites

| Prerequisite | Bắt buộc? | Mô tả |
|-------------|-----------|-------|
| Python 3 | Có | Cần để chạy search scripts |
| Data files | Có | `data/*.csv` phải tồn tại |
| UI project | Không | Không bắt buộc — có thể dùng cho planning |

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `query` | Keywords mô tả product/style | — (bắt buộc) |
| `--design-system` | Generate full design system | `false` |
| `--domain=<domain>` | Lọc theo domain (style/chart/ux/typography/landing) | `all` |
| `--stack=<stack>` | Tech stack cụ thể | `html-tailwind` |

## Context & Checkpoint

> **Protocol:** Xem `.claude/skills/protocols/` — mục 3. Context & Checkpoint Protocol

Skill này thường hoàn thành trong 1 session.
Nếu design system phức tạp, hỗ trợ `--resume` để tiếp tục và `--status` để xem trạng thái.

## Execution Strategy

| Điều kiện | Chế độ |
|-----------|--------|
| Design system generation (3 searches) | SEQUENTIAL |
| Multiple domain searches | PARALLEL nếu independent |

> **Retry:** Mỗi script call retry tối đa 3 lần. Nếu Python unavailable → fallback to inline recommendations.

### Fix Rules (Skill-specific)

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| Script trả về empty result | Retry với broader keywords | 3 lần vẫn empty |
| Color contrast không đạt 4.5:1 | Tự điều chỉnh shade darker/lighter | Palette yêu cầu brand color cố định |
| Font không available trên Google Fonts | Suggest fallback font | User yêu cầu font cụ thể |
| Stack không hỗ trợ | Default `html-tailwind` | User insist stack khác |
| CSV data corrupt/missing columns | Skip corrupt row, log warning | >50% rows corrupt |

---

## Phase 1: Input Analysis

**PRE-GATE:**
- `test -n "$QUERY"` — Query phải được cung cấp

| Step | Action | Verify |
|------|--------|--------|
| 1.1 | Parse query keywords | Keywords extracted |
| 1.2 | Detect domain từ context | Domain set |
| 1.3 | Detect tech stack từ project hoặc flag | Stack set |
| 1.4 | Map color name requests thành search keywords | Color intent mapped |
| 1.5 | Detect dark/light mode intent từ query | Mode preference set |

**Color Name Mapping:** Khi user yêu cầu màu cụ thể (VD: "professional blue"), map thành keywords phù hợp cho search:

| Color Intent | Search Keywords | Palette Match Hint |
|-------------|----------------|--------------------|
| professional blue | `trust corporate business blue` | SaaS, Enterprise palettes |
| vibrant/playful | `vibrant bright fun colorful` | Creative, Gen Z palettes |
| dark/moody | `dark premium night sophisticated` | Dark theme, Luxury palettes |
| warm/organic | `warm natural earth organic` | Wellness, Food palettes |
| neutral/minimal | `minimal clean neutral monochrome` | Swiss, Corporate palettes |
| luxury/gold | `premium luxury gold elegant` | Luxury, Fashion palettes |

Sau khi search, **điều chỉnh palette** theo intent user nếu kết quả chưa khớp tông màu yêu cầu (VD: search trả về cyan nhưng user muốn blue → shift palette sang blue shades).

**POST-GATE:**
- `test -n "$KEYWORDS"` — Có keywords để search

---

## Phase 2: Design Intelligence Search

**PRE-GATE:**
- Keywords available từ Phase 1

| Step | Action | Verify |
|------|--------|--------|
| 2.1 | Search `styles.csv` cho pattern match | Style found |
| 2.2 | Search `colors.csv` cho palette | Palette selected |
| 2.3 | Search `typography.csv` cho font pairing | **2-font pairing** verified |
| 2.4 | Search domain-specific data (nếu `--domain`) | Domain data loaded |
| 2.5 | Load stack guidelines (nếu `--stack`) | Stack guidelines loaded |
| 2.6 | Nếu query chứa "dark" hoặc dark theme intent → search thêm `--domain ux` với "dark theme contrast" | Dark mode data loaded |

**2-Font Pairing Rule:** Typography data (`typography.csv`) chứa 57 font pairings, mỗi pair có **Heading Font** và **Body Font** riêng biệt. Khi synthesize:
- Ưu tiên dùng **2 fonts khác nhau** cho heading và body để tạo visual hierarchy rõ ràng
- Nếu search trả về single-font result (VD: "Minimal Swiss" = Inter+Inter), vẫn chấp nhận nhưng ghi chú alternative 2-font pairing phù hợp
- Chạy thêm `--domain typography` search nếu kết quả ban đầu chỉ có single font

**POST-GATE:**
- Tối thiểu style + palette + typography có kết quả
- Typography phải có heading + body font

---

## Phase 3: Design System Generation

**PRE-GATE:**
- Search results available từ Phase 2

| Step | Action | Verify |
|------|--------|--------|
| 3.1 | Synthesize design system từ search results | System generated |
| 3.2 | Apply accessibility rules (contrast, touch targets) | Rules applied |
| 3.3 | Apply stack-specific guidelines | Guidelines applied |
| 3.4 | Generate dark mode variant (nếu web project) | Dark mode palette included |
| 3.5 | Generate code examples cho stack | Code snippets included |
| 3.6 | Run Quality Checklist | All checks pass |

**Dark Mode Variant (Step 3.4):** Cho mọi web project (html-tailwind, react, nextjs, vue, svelte, shadcn):
- Tạo bảng dark mode colors tương ứng với light palette
- Background tối dùng slate-900/800 (KHÔNG dùng pure #000000)
- Text sáng dùng slate-100/200
- Giữ nguyên brand/accent colors, chỉ điều chỉnh lightness
- Validate contrast ratios cho dark mode riêng
- Nếu user đã yêu cầu dark theme → dark là primary, light là variant

**Code Examples (Step 3.5):** Output phải có ít nhất 1 code example thể hiện:
- Design tokens/theme config cho stack
- 1 component mẫu áp dụng design system
- Responsive + accessibility patterns

**POST-GATE:**
- Design system complete, accessibility validated
- Code examples included (design tokens + component mẫu)

---

## Capabilities

> Reference documentation (Design System Generation, Domain-Specific Search, Stack-Specific Guidelines
> + ví dụ lệnh search.py): đã tách sang [procedures/capabilities.md](procedures/capabilities.md).

## Critical Rules

### Priority 1: Accessibility (CRITICAL)

| Rule | Requirement |
|------|-------------|
| Color contrast | Minimum 4.5:1 ratio for normal text |
| Focus states | Visible focus rings on all interactive elements |
| Alt text | Descriptive alt for meaningful images |
| ARIA labels | aria-label for icon-only buttons |
| Keyboard nav | Tab order matches visual order |
| Form labels | Use `<label for="...">` attribute |

### Priority 2: Touch & Interaction (CRITICAL)

| Rule | Requirement |
|------|-------------|
| Touch targets | Minimum 44x44px |
| Loading states | Disable buttons during async operations |
| Error feedback | Clear messages near the problem |
| Cursor | Add `cursor-pointer` to clickable elements |

### Priority 3: Performance (HIGH)

| Rule | Requirement |
|------|-------------|
| Images | Use WebP, srcset, lazy loading |
| Motion | Check `prefers-reduced-motion` |
| Layout shift | Reserve space for async content |

### Priority 4: Layout (HIGH)

| Rule | Requirement |
|------|-------------|
| Viewport | `width=device-width, initial-scale=1` |
| Font size | Minimum 16px body text on mobile |
| z-index | Use scale: 10, 20, 30, 50 |

---

## Common Mistakes to Avoid

### Icons
- Never use emojis as UI icons
- Dùng SVG icons (Heroicons, Lucide, Simple Icons)

### Hover States
- Never use scale transforms that shift layout
- Dùng color/opacity transitions với `transition-colors duration-200`

### Light Mode Contrast
- Never use `bg-white/10` in light mode (invisible)
- Never use `text-gray-400` for body text
- Dùng `bg-white/80` minimum for glass effects
- Dùng `text-slate-900` for body, `text-slate-600` for muted

### Interactive Elements
- Never leave default cursor on clickable elements
- Thêm `cursor-pointer` class
- Cung cấp visual feedback on hover (color, shadow, border)

---

## Quality Checklist

Chạy trước khi deliver bất kỳ UI code nào (Phase 3, Step 3.4):

**Design System:**
- [ ] Design system generated (if --design-system)
- [ ] Accessibility rules checked — color contrast validated
- [ ] Typography: **2-font pairing** (heading ≠ body), hoặc ghi chú alternative nếu single font
- [ ] Color palette: **8+ colors** với đầy đủ hex codes (#XXXXXX)
- [ ] Contrast ratios ghi rõ cho mỗi text color (AA/AAA)

**Visual Quality:**
- [ ] No emojis as icons
- [ ] Consistent icon set (Heroicons/Lucide/Simple Icons)
- [ ] Hover states don't cause layout shift

**Interaction:**
- [ ] All clickable elements have `cursor-pointer`
- [ ] Transitions are 150-300ms
- [ ] Focus states visible for keyboard nav

**Light/Dark Mode:**
- [ ] Text contrast 4.5:1 minimum in both modes
- [ ] Dark mode variant included (web projects) — hoặc ghi rõ lý do skip
- [ ] Glass elements visible in light mode
- [ ] Borders visible in both modes

**Accessibility:**
- [ ] All images have alt text
- [ ] Form inputs have labels
- [ ] `prefers-reduced-motion` respected

**Code & Implementation:**
- [ ] Code example included (design tokens + component mẫu)
- [ ] Stack-specific config (Tailwind config / theme.js / etc.)
- [ ] Google Fonts import code provided

---

## Output Report

**Lưu kết quả:** `.mc-data/work/ui-ux-pro-max/design-system-[YYYY-MM-DD].md` (nếu có `.mc-data/`)

ALWAYS dùng template này khi hoàn thành:

```markdown
## Design System: [Project/Query]

### Recommended Pattern
**Style:** [Style Name] | **Domain:** [Domain]
**Reasoning:** [Why this style fits — 2-3 câu giải thích context-aware]

### Color Palette
| Name | Hex | Usage | Contrast vs BG |
|------|-----|-------|----------------|
| Primary | #XXXXXX | Buttons, links | X.X:1 (AA/AAA) |
| Secondary | #XXXXXX | Accents | X.X:1 |
| Background | #XXXXXX | Page background | — |
| Surface | #XXXXXX | Cards, panels | — |
| Text | #XXXXXX | Body text | X.X:1 (AAA) |
| Muted | #XXXXXX | Secondary text | X.X:1 (AA) |
| Success | #XXXXXX | Positive states | X.X:1 |
| Error | #XXXXXX | Error states | X.X:1 |

> Tối thiểu 8 colors. Contrast ratios phải validate WCAG AA (4.5:1) cho text.

### Dark Mode Variant (cho web projects)
| Name | Light | Dark | Usage |
|------|-------|------|-------|
| Background | #XXXXXX | #XXXXXX | Page BG |
| Surface | #XXXXXX | #XXXXXX | Cards |
| Text | #XXXXXX | #XXXXXX | Body text |
| Border | #XXXXXX | #XXXXXX | Dividers |

> Nếu user yêu cầu dark theme → dark là primary palette, bảng này là light variant.
> Skip nếu mobile-only (swiftui, react-native, flutter — dark mode do OS quản lý).

### Typography
| Role | Font | Weight | Size |
|------|------|--------|------|
| Heading | [Heading Font] | 700 | 32-48px |
| Subheading | [Heading Font] | 600 | 20-24px |
| Body | [Body Font] | 400 | 16-18px |
| Caption | [Body Font] | 400 | 12-14px |

> Heading Font và Body Font nên là **2 fonts khác nhau** để tạo visual hierarchy.
> Nếu dùng single font (VD: Inter), ghi chú alternative 2-font pairing.

**Google Fonts Import:** [CSS import code]
**Tailwind/Stack Config:** [Config snippet]

### Effects
- [Effect 1 — mô tả + CSS/implementation]

### Anti-patterns to Avoid
| Anti-pattern | Thay thế bằng |
|-------------|---------------|
| [Pattern] | [Better approach] |

### Stack: [Stack Name]
[Architecture recommendations]
[Recommended libraries]
[Code example: component mẫu áp dụng design system]

### Quality Checklist
- [ ] 2-font pairing (hoặc ghi chú alternative)
- [ ] 8+ colors với hex codes
- [ ] Contrast ratios validated (text >= 4.5:1)
- [ ] Dark mode variant included (web)
- [ ] Code example included
- [ ] Accessibility rules applied

Next: Implement design trong `/wf-implement-feature` hoặc tiếp tục với `/wf-design`
```

---

## Data Files Reference

| File | Content |
|------|---------|
| `data/styles.csv` | 50+ UI styles with CSS keywords |
| `data/colors.csv` | 97 color palettes by product type |
| `data/typography.csv` | 57 font pairings |
| `data/products.csv` | Product type recommendations |
| `data/landing.csv` | Landing page structures |
| `data/charts.csv` | 25 chart types with use cases |
| `data/ux-guidelines.csv` | 99 UX best practices |
| `data/ui-reasoning.csv` | Decision logic for recommendations |
| `data/stacks/*.csv` | Stack-specific guidelines |

Scripts: `scripts/search.py` (main), `scripts/core.py`, `scripts/design_system.py`

---

## Example Workflow

**User:** "Làm landing page cho dịch vụ spa"

```bash
# 1. Generate design system
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "beauty spa wellness elegant" --design-system -p "Serenity Spa"

# 2. Get UX guidelines
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "animation accessibility" --domain ux

# 3. Get stack-specific tips
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "layout responsive" --stack html-tailwind
```

Then synthesize all results and implement the design.

---

## Error Handling

| Code | Situation | Action |
|------|-----------|--------|
| E001 | Python not available | Fallback to inline recommendations |
| E002 | Data files missing | Use built-in defaults |
| E003 | Invalid stack | Default to html-tailwind |
| E004 | Query too vague | Ask for clarification |
| E005 | CSV data corrupt | Skip corrupt rows, use built-in defaults for missing data |

---

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-design` | UI design integration |
| `/wf-implement-feature` | UI implementation |

---

### POST-GATE

> Minimal validation cho quick skill

- T1: test -f .mc-data/work/ui-ux-pro-max/design-system-*.md — Output file exists
- T2: test -s .mc-data/work/ui-ux-pro-max/design-system-*.md — Non-empty output

> Lưu ý: Nếu không có `.mc-data/` directory, output được trả về trực tiếp trong chat — không cần file check.
