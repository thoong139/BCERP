# Playbook: Thiết kế Wireframes

> **Type**: Agent Skill Playbook
> **Agent**: ux-designer
> **Triggered by**: /wf-design-ux Phase 4 khi cần wireframe / mockup text-based cho features
> **Output**: `.mc-data/docs/phase4-ux/wireframes/[feature-name]-wireframes.md`

---

## Khi nào dùng playbook này

- Khi cần wireframe cho screens mới trong `/wf-design-ux`
- Khi cần mô tả layout, information hierarchy và component placement ở dạng text/ASCII
- Khi cần spec các interaction states trước khi bàn giao cho frontend-developer
- Sau khi `design-user-flow.md` đã hoàn thành — wireframe là bước tiếp theo

---

## Procedure

### Bước 1: Đọc context đầu vào

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE4 (user flows), PHASE2 (feature specs)

Cần đọc trước:
□ User flow file tương ứng (.mc-data/docs/phase4-ux/user-flows/[feature]-flow.md)
□ Feature spec (.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md)
□ Design system hiện có (PHASE4/design-system/MASTER.md nếu có)
□ Requirements gốc để hiểu data cần hiển thị

READ: design-system-patterns.md → Section 7: Spacing System (để dùng spacing tokens nhất quán)
```

### Bước 2: Quyết định layout grid

```
Dựa vào platform (xác định từ feature spec hoặc requirements):

Mobile (375px width):
□ Single column layout
□ Stacked components theo chiều dọc
□ Bottom navigation hoặc hamburger menu
□ Touch target tối thiểu 44×44px

Tablet (768px width):
□ 2-column grid (nội dung + sidebar)
□ Hoặc single column với wider content area
□ Có thể dùng tab bar navigation

Desktop (1280px+ width):
□ 12-column grid system
□ Sidebar navigation cố định
□ Content area 8-col, sidebar 4-col (hoặc biến thể)
□ Hover states có ý nghĩa

Responsive:
□ Xác định breakpoints chính: 375px, 768px, 1280px
□ Mô tả layout thay đổi tại mỗi breakpoint

READ: accessibility-checklist.md → Section 1: WCAG 1.4.10 Reflow (320px không horizontal scroll)
```

### Bước 3: Xác định information hierarchy

```
Với mỗi screen cần wireframe:

□ Primary content: Thông tin quan trọng nhất — user cần thấy đầu tiên
□ Secondary content: Hỗ trợ hiểu primary content
□ Tertiary content: Metadata, actions phụ, navigation phụ

Mapping thứ tự ưu tiên → vị trí trên màn hình:
- Cao nhất: Top-left (reading direction) hoặc above the fold
- Trung bình: Mid-page, trong vùng nhìn thấy
- Thấp nhất: Below the fold, sidebar, footer, collapsed section

Hỏi: Nếu user chỉ có 3 giây để scan page, họ sẽ lấy được thông tin gì?
→ Đó là thứ phải ở primary position
```

### Bước 4: Inventory components cần dùng

```
READ: design-system-patterns.md → Section 4: Component API Design Principles

Liệt kê tất cả components cần thiết cho feature:

Layout components:
□ Page container, grid, columns
□ Card, panel, section
□ Header, footer, sidebar

Navigation:
□ Breadcrumb, tabs, pagination
□ Back button, step indicator (wizard)

Data display:
□ Table / list / grid view
□ Status badge, tag, chip
□ Avatar, icon, image

Forms:
□ Text input, textarea, select, checkbox, radio, toggle
□ Date picker, file upload
□ Form validation messages

Actions:
□ Buttons (primary, secondary, ghost, danger)
□ Link, icon button, FAB
□ Dropdown menu, context menu

Feedback:
□ Toast notification, alert banner
□ Loading state (skeleton, spinner)
□ Empty state
□ Error state

Ghi chú component nào đã có trong design system, component nào cần tạo mới.
```

### Bước 5: Wireframe từng màn hình

```
Với mỗi screen trong user flow, vẽ wireframe dạng ASCII:

Quy ước ASCII wireframe:
┌─────────────────────────────┐  ← Container border
│ [HEADER / NAVIGATION]       │  ← Mô tả khu vực
├─────────────────────────────┤
│ [BREADCRUMB: A > B > C]     │
│                             │
│  [PAGE TITLE - H1]          │  ← Typography level
│                             │
│  ┌──────────┐ ┌──────────┐  │  ← Card components
│  │ CARD A   │ │ CARD B   │  │
│  │ [icon]   │ │ [icon]   │  │
│  │ Label    │ │ Label    │  │
│  │ Value    │ │ Value    │  │
│  └──────────┘ └──────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │ [TABLE / LIST]        │  │
│  │ Col 1 | Col 2 | Col 3 │  │
│  │ ------+-------+------ │  │
│  │ Data  | Data  | Data  │  │
│  └───────────────────────┘  │
│                             │
│  [Pagination: < 1 2 3 >]    │
│                             │
│  [BTN Primary] [BTN Ghost]  │  ← Action buttons
└─────────────────────────────┘

Dùng annotation bên dưới mỗi wireframe:
(1) Khu vực này: mô tả chi tiết hành vi
(2) Button này: label, action khi click
(3) Field này: type input, validation rules
```

### Bước 6: Document interaction states

```
READ: design-system-patterns.md → Section 4: States cần cover

Với mỗi interactive element, document đủ 7 states:

STATE: Default
→ [Mô tả visual appearance]

STATE: Hover (desktop only)
→ [Màu sắc thay đổi? Cursor? Tooltip xuất hiện?]

STATE: Focus (keyboard navigation)
→ [Focus ring style theo design system]
→ READ: accessibility-checklist.md → Section 4: Keyboard Navigation

STATE: Active (đang click/press)
→ [Visual feedback khi đang nhấn]

STATE: Disabled
→ [Opacity? Cursor not-allowed? Tooltip giải thích tại sao disabled?]

STATE: Loading
→ [Skeleton loader? Spinner? Disabled trong khi load?]
→ Text thay đổi gì? ("Đang lưu..." thay vì "Lưu")

STATE: Error
→ [Border đỏ? Icon error? Error message ở đâu?]
→ READ: accessibility-checklist.md → Section 6: Error Identification Pattern

Document dưới dạng bảng:
| Component | Default | Hover | Focus | Active | Disabled | Loading | Error |
|-----------|---------|-------|-------|--------|----------|---------|-------|
| [Name]    | ...     | ...   | ...   | ...    | ...      | ...     | ...   |
```

### Bước 7: Responsive layout notes

```
Với mỗi screen đã wireframe, mô tả cách layout thay đổi:

Mobile (375px):
[ASCII wireframe cho mobile layout]

Tablet (768px):
[Mô tả thay đổi so với mobile — chỉ ghi những điểm khác]

Desktop (1280px):
[Mô tả thay đổi so với tablet — chỉ ghi những điểm khác]

Các thay đổi thường gặp:
□ Sidebar collapse → hidden (mobile) hoặc drawer
□ Table → card list (mobile)
□ Multi-column grid → single column (mobile)
□ Navigation bar → bottom tabs (mobile)
□ Hover states → chỉ có từ tablet trở lên
```

### Bước 8: Annotation với UX rationale

```
Với mỗi quyết định thiết kế quan trọng, giải thích WHY:

Format annotation:
> ✏️ UX Rationale: [Quyết định] — [Lý do]

Ví dụ:
> ✏️ UX Rationale: Đặt primary CTA ở bottom-right thay vì top-right
>    — Người dùng scan theo Z-pattern; bottom-right là điểm dừng tự nhiên
>    sau khi đọc xong nội dung form

> ✏️ UX Rationale: Dùng inline validation thay vì validate-on-submit
>    — Giảm cognitive load; user sửa lỗi ngay khi blur khỏi field
>    thay vì phải tìm lại field bị lỗi sau khi submit

> ✏️ UX Rationale: Skeleton loader thay vì spinner cho danh sách
>    — Skeleton preserve layout → giảm layout shift → cảm giác nhanh hơn

Các quyết định cần annotate:
□ Lựa chọn navigation pattern
□ Progressive disclosure vs show all
□ Inline edit vs edit page riêng
□ Confirmation dialog vs undo pattern
□ Pagination vs infinite scroll
□ Search vs filter vs sort priority
```

---

## Cấu trúc File Output

```markdown
# Wireframes: [Feature Name]

> **REQ-ID**: [REQ-XXX-NNN]
> **Feature**: [Tên feature]
> **Phase**: 4 — UX Design
> **Depends on**: `user-flows/[feature-name]-flow.md`
> **Ngày tạo**: YYYY-MM-DD
> **Designer**: ux-designer

## Platform & Breakpoints

| Platform | Breakpoint | Layout |
|----------|-----------|--------|
| Mobile   | 375px     | Single column |
| Tablet   | 768px     | 2-column |
| Desktop  | 1280px    | 12-column grid |

## Component Inventory

### Components dùng từ Design System
- [Component A] — stable
- [Component B] — stable

### Components cần tạo mới
- [Component C] — [Mô tả ngắn, tại sao không dùng existing]

## Screens

### Screen 1: [Tên màn hình]

**Mục đích**: [User cần hoàn thành gì ở screen này]
**User story**: [Liên kết tới step nào trong user flow]

#### Desktop Wireframe (1280px)

```
┌──────────────────────────────────────────────────────┐
│ [NAVIGATION]                           [User Avatar] │
├──────────────────────────────────────────────────────┤
│ Breadcrumb > Path > Current                          │
│                                                      │
│ [PAGE TITLE]                    [BTN: Tạo mới +]    │
│                                                      │
│ [Filter bar: ___Search___ | Status ▾ | Date ▾]      │
│                                                      │
│ ┌──────────────────────────────────────────────────┐ │
│ │ Tên       | Trạng thái | Ngày tạo  | Hành động  │ │
│ │ ──────────+────────────+───────────+─────────── │ │
│ │ Item A    | ● Active   | 01/03     | Edit Delete │ │
│ │ Item B    | ○ Draft    | 02/03     | Edit Delete │ │
│ └──────────────────────────────────────────────────┘ │
│                                                      │
│ Hiển thị 1-10 / 45 kết quả    [< 1 2 3 4 5 >]      │
└──────────────────────────────────────────────────────┘
```

#### Mobile Wireframe (375px)

```
┌─────────────────────────┐
│ [☰]  [Page Title]  [👤] │
├─────────────────────────┤
│ [🔍 Tìm kiếm...]        │
│                         │
│ ┌─────────────────────┐ │
│ │ Item A              │ │
│ │ ● Active            │ │
│ │ 01/03/2026     [...] │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ Item B              │ │
│ │ ○ Draft             │ │
│ │ 02/03/2026     [...] │ │
│ └─────────────────────┘ │
│                         │
│ [        + Tạo mới    ] │
└─────────────────────────┘
```

#### Interaction States

| Component | Default | Hover | Focus | Disabled | Loading | Error |
|-----------|---------|-------|-------|----------|---------|-------|
| [Name]    | ...     | ...   | ...   | ...      | ...     | ...   |

#### UX Rationale

> ✏️ UX Rationale: [Quyết định thiết kế] — [Lý do]

---

### Screen 2: [Tên màn hình]

[Tiếp tục pattern tương tự]

---

## Empty State

```
┌──────────────────────────────┐
│                              │
│        [Empty Icon]          │
│                              │
│   Chưa có dữ liệu nào        │
│   [Mô tả ngắn tại sao]       │
│                              │
│   [BTN: Tạo mới ngay]        │
│                              │
└──────────────────────────────┘
```

## Error States

### Network Error
[Wireframe + mô tả]

### Permission Error
[Wireframe + mô tả]
```

---

## Checklist trước khi submit

```
□ Mỗi screen có REQ-ID tham chiếu rõ ràng
□ Desktop và Mobile wireframe đã có cho mọi screen quan trọng
□ Interaction states đã document đủ (default, hover, focus, disabled, loading, error)
□ Empty state đã design
□ Error states đã design
□ UX Rationale đã annotation cho quyết định quan trọng
□ Component inventory đã list đầy đủ (existing vs cần tạo mới)
□ Wireframe ASCII đủ rõ để developer hiểu layout
□ File lưu đúng path: phase4-ux/wireframes/[feature-name]-wireframes.md
□ READ accessibility-checklist.md đã done — không có vi phạm WCAG trong design
```
