# Playbook: Thiết kế UX Feature hoàn chỉnh

> **Type**: Agent Skill Playbook
> **Agent**: ux-designer
> **Triggered by**: /wf-design-ux Phase 4 khi cần complete UX design cho một feature cụ thể
> **Output**: `.mc-data/docs/phase4-ux/features/[feature-name]-ux-spec.md`

---

## Khi nào dùng playbook này

- Playbook tổng hợp — bao gồm user flow + wireframe + interaction design trong một deliverable
- Dùng khi feature đủ phức tạp để cần full UX spec (từ goal đến handoff spec)
- Thường là output chính của `/wf-design-ux` cho mỗi feature quan trọng
- Input cho frontend-developer khi implement UI

---

## Procedure

### Bước 1: Đọc context đầy đủ

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2, PHASE1, PHASE4

Thu thập đủ các inputs:
□ Requirements gốc → .mc-data/docs/phase2-features/[sys]/[mod]/[feat].md
□ Personas từ phase1-business (nếu có)
□ Design system → PHASE4/design-system/MASTER.md (nếu đã generate)
□ Architecture constraints → phase3-architecture/ (API endpoints, data types)
□ User flows đã có → phase4-ux/user-flows/ (nếu đã chạy design-user-flow.md)

READ:
□ design-system-patterns.md → Toàn bộ (để biết tokens, components, spacing, motion)
□ accessibility-checklist.md → Section 1, 4, 5, 6 (WCAG AA, keyboard, forms)
□ ux-research-methods.md → Section 3: Persona Template, Section 5: Journey Map
```

### Bước 2: Define UX goals

```
Trước khi thiết kế, chốt rõ:

□ Primary UX Goal: Điều quan trọng nhất user cần đạt được qua feature này
  Ví dụ: "User tạo được đơn hàng trong <3 phút mà không cần hỗ trợ"

□ Secondary UX Goals:
  - Giảm cognitive load (bao nhiêu fields cần điền?)
  - Tăng confidence (user có chắc họ đang làm đúng không?)
  - Error prevention (làm sao ngăn lỗi phổ biến nhất?)
  - Discoverability (tính năng có tìm được không?)

□ Anti-goals (điều không ưu tiên trong iteration này):
  - "Chưa cần support bulk actions"
  - "Chưa cần offline mode"

□ Success metrics:
  - Task completion rate: >X%
  - Time-on-task: <Y phút
  - Error rate: <Z errors/session
  - SUS score target: >68

REF: ux-research-methods.md → Section 8: SUS Scale
```

### Bước 3: User flow design

```
Xây dựng user flow hoặc tham chiếu file đã có:

OPTION A: Đã có user flow file
→ Read phase4-ux/user-flows/[feature]-flow.md
→ Verify flow còn đúng với requirements hiện tại
→ Note bất kỳ gap nào cần bổ sung

OPTION B: Chưa có user flow file
→ Chạy inline flow design theo quy trình trong design-user-flow.md
→ Tóm tắt flow chính vào section "User Flow" của UX spec

Flow cần document:
□ Happy path (đường chính khi mọi thứ hoạt động tốt)
□ Error paths (ít nhất 3 error scenarios phổ biến nhất)
□ Edge cases (first-time user, empty state, permission issues)

Dùng ASCII flow diagram:
[Start] → [Step 1] → [Decision?] → [Step 2A / Step 2B] → [End]
                                         ↓
                                    [Error State]
```

### Bước 4: Wireframes chính

```
Thiết kế wireframe cho mỗi screen trong flow:

READ: design-system-patterns.md → Section 7: Spacing System

Với mỗi screen:
□ Desktop layout (1280px) — ASCII wireframe
□ Mobile layout (375px) — ASCII wireframe
□ Ghi rõ các components được dùng

Screens cần có wireframe:
□ Screen chính (entry point của flow)
□ Mọi screen intermediate trong happy path
□ Success state
□ Empty state
□ Critical error states

Không cần wireframe cho:
□ Screens giữ nguyên từ feature khác (tham chiếu)
□ System pages như 404, 500 (dùng global design)
```

### Bước 5: Interaction design

```
Chỉ định rõ interactions, không để developer tự suy luận:

5a. Transitions và animations

□ Khi navigate giữa screens: slide? fade? không animate?
□ Khi modal mở/đóng: fade-in? scale-in? slide-up (mobile)?
□ Khi submit form: button loading state → thời gian → redirect
□ Khi data load: skeleton loader duration → content appears

REF: design-system-patterns.md → Section 9: Motion & Animation Tokens
Quy tắc: duration.normal = 200ms cho component transitions, duration.slow = 300ms cho modal

□ Chỉ animate transform và opacity (GPU-accelerated)
□ Tránh animate width/height/top/left

5b. Feedback và micro-interactions

□ Mỗi user action phải có phản hồi tức thì (<100ms) hoặc loading state nếu async
□ Thành công: Toast notification (3 giây auto-dismiss) + state update
□ Lỗi: Inline error message + error toast nếu cần
□ Loading: Skeleton loader cho data fetch, spinner cho button action

5c. Error handling

□ Client-side validation: Validate on blur (không on-change để tránh annoying)
□ Server-side error: Hiển thị message cụ thể, không chỉ "Có lỗi xảy ra"
□ Network error: Retry button + "Kiểm tra kết nối mạng"
□ Permission error: Giải thích tại sao không có quyền + link để request quyền

REF: accessibility-checklist.md → Section 6: Form Accessibility Requirements
```

### Bước 6: Microcopy và labels

```
Viết text cho tất cả UI elements:

□ Page titles và headings (H1, H2, H3)
□ Button labels (hành động rõ ràng: "Lưu thay đổi" tốt hơn "OK")
□ Form field labels và placeholder text
□ Help text / hint (text nhỏ dưới field giải thích format)
□ Error messages (cụ thể: "Email phải có định dạng name@domain.com")
□ Empty state messages (friendly, có CTA)
□ Confirmation dialog text ("Xóa vĩnh viễn?" + warning về hậu quả)
□ Toast notifications ("Đã lưu thành công" / "Không thể xóa — item đang được sử dụng")
□ Loading messages ("Đang xử lý..." / "Đang tải dữ liệu...")

Nguyên tắc microcopy:
- Dùng ngôn ngữ của user, không dùng jargon kỹ thuật
- Cụ thể: "Xóa campaign 'Q1 Promo'?" tốt hơn "Xóa item đã chọn?"
- Tích cực: "Vui lòng nhập email" tốt hơn "Bạn quên nhập email"
- Có action: Empty state nên có hướng dẫn bước tiếp theo
```

### Bước 7: Accessibility considerations

```
READ: accessibility-checklist.md → Toàn bộ document

Với mỗi screen, kiểm tra:

WCAG 2.1 AA Checklist:
□ Color contrast ≥ 4.5:1 cho text thường, ≥ 3:1 cho large text và UI components
□ Không dùng màu là cách DUY NHẤT truyền thông tin (thêm icon hoặc text)
□ Focus indicator visible (2px solid outline, contrast ≥ 3:1 với nền)
□ Keyboard navigation: Tab order logic, không có keyboard trap
□ Form labels: Mỗi input có label (không chỉ placeholder)
□ Error messages: Cụ thể + linked với field bằng aria-describedby
□ Images: Alt text theo Alt Text Decision Tree
□ ARIA: Dùng semantic HTML trước, ARIA chỉ khi cần

Components cần chú ý đặc biệt:
□ Modal: Focus trap, Escape key đóng, focus restore về trigger
□ Dropdown/Select: Arrow keys navigate, Escape đóng
□ Tab component: Arrow keys switch tabs
□ Toast/Alert: aria-live="polite" cho info, aria-live="assertive" cho error

Touch target:
□ Mọi interactive element: tối thiểu 44×44px (iOS HIG standard)
□ Dùng padding để expand touch area nếu visual size nhỏ hơn
```

### Bước 8: Design handoff spec

```
Tổng hợp thông tin để developer implement được mà không cần hỏi lại:

Với mỗi screen:
□ Layout: Grid system, breakpoints, spacing values (dùng tokens)
□ Typography: Token name cho mỗi text element
□ Colors: Token name, không hardcode hex
□ Component specs: Variant, size, state cho mỗi component
□ Spacing: Giữa mỗi element (dùng spacing tokens)
□ Border radius: Token name
□ Shadow/elevation: Token name
□ Animation: Duration, easing (token hoặc CSS values cụ thể)
□ Icon: Tên icon, size, color token

REF: design-system-patterns.md → Section 10: Design-to-Code Handoff Checklist

Verification checklist (bắt buộc trước submit):
□ Mọi color, spacing, typography dùng token — không hardcode value
□ Đủ 7 states cho mỗi interactive component
□ Có breakpoint design cho mobile (375px), tablet (768px), desktop (1280px)
□ Có design cho empty state, error state, loading state
□ Accessibility đã check
```

### Bước 9: Output — viết file

```
Ghi vào: .mc-data/docs/phase4-ux/features/[feature-name]-ux-spec.md
(Sử dụng path do skill cung cấp; fallback theo quy tắc trên)
```

---

## Cấu trúc File Output

```markdown
# UX Spec: [Feature Name]

> **REQ-ID**: [REQ-XXX-NNN]
> **Feature**: [Tên đầy đủ của feature]
> **Phase**: 4 — UX Design
> **Ngày tạo**: YYYY-MM-DD
> **Designer**: ux-designer
> **Status**: Draft / Review / Approved

## 1. UX Goals

| Mục tiêu | Mô tả | Metric |
|----------|-------|--------|
| Primary | [Goal chính] | Task completion >X% |
| Secondary | [Goal phụ] | Time-on-task <Y phút |

**Anti-goals iteration này:**
- [Điều chưa làm trong scope này]

## 2. Personas

### Persona: [Tên]
- **Vai trò**: [Job title]
- **Mục tiêu**: [Muốn đạt gì với feature này]
- **Pain points**: [Khó khăn hiện tại]
- **Tech savviness**: Beginner / Intermediate / Power user

## 3. User Flow

### Happy Path: [Tên flow]

**Trigger**: [Điều gì bắt đầu flow]

```
[ASCII flow diagram]
[Start] → [Step 1] → [Step 2] → [Success State]
                        ↓
                   [Error State] → [Recovery]
```

### Error Flows

**Error: [Tên error]**
- Trigger: [Khi nào xảy ra]
- User thấy: [Message / UI]
- Recovery: [Cách sửa]

## 4. Wireframes

### Screen: [Tên màn hình] — Desktop (1280px)

**Mục đích**: [User cần làm gì ở đây]

```
┌──────────────────────────────────────────────────┐
│ [ASCII wireframe đầy đủ]                         │
└──────────────────────────────────────────────────┘
```

**(1)** [Annotation cho element 1]
**(2)** [Annotation cho element 2]

### Screen: [Tên màn hình] — Mobile (375px)

```
┌─────────────────────────┐
│ [ASCII wireframe mobile] │
└─────────────────────────┘
```

### Interaction States

| Component | Default | Hover | Focus | Active | Disabled | Loading | Error |
|-----------|---------|-------|-------|--------|----------|---------|-------|
| [Name]    | ...     | ...   | ...   | ...    | ...      | ...     | ...   |

## 5. Interaction Design

### Transitions & Animations

| Transition | Duration | Easing | Ghi chú |
|-----------|----------|--------|---------|
| Modal open | 300ms | ease-out | scale-in từ 95% → 100% |
| Form submit | 200ms | — | Button loading state |

### Error Handling

| Error type | UI hiển thị | User action |
|-----------|-------------|-------------|
| Validation | Inline error dưới field | Sửa và re-submit |
| Network | Toast + Retry button | Click retry |

## 6. Microcopy

| Element | Text | Ghi chú |
|---------|------|---------|
| Page title | "[Title]" | H1 |
| Submit button | "[Label]" | Rõ ràng action |
| Empty state | "[Message]" | Có CTA |
| Error: required field | "[Message]" | Cụ thể |

## 7. Accessibility Checklist

- [ ] Color contrast ≥ 4.5:1 tất cả text thường
- [ ] Color contrast ≥ 3:1 UI components
- [ ] Focus indicator visible trên mọi interactive element
- [ ] Keyboard navigation hoạt động đúng
- [ ] Form labels linked với inputs
- [ ] Error messages linked với fields (aria-describedby)
- [ ] Touch targets ≥ 44×44px
- [ ] Không dùng màu là cách duy nhất truyền thông tin
- [ ] Alt text cho mọi ảnh có ý nghĩa
- [ ] Modal: focus trap + Escape key + focus restore

## 8. Design Handoff Specs

### Tokens Used

| Element | Color token | Typography token | Spacing token |
|---------|------------|-----------------|--------------|
| Page background | surface.default | — | — |
| Body text | text.default | text.body | — |
| Primary button | action.primary | text.body.sm | spacing.4 |

### Component Specs

**[Component Name]**
- Variant: [primary / secondary / ...]
- Size: [sm / md / lg]
- States: [list states cần implement]
- ARIA: [role, aria-* attributes cần thiết]
```

---

## Checklist trước khi submit

```
□ Tất cả REQ-ID đã được reference
□ UX Goals và metrics đã định nghĩa rõ
□ Personas đã document
□ Happy path và ít nhất 3 error flows
□ Wireframe cho mọi screen (desktop + mobile)
□ Interaction states đầy đủ 7 states
□ Transition/animation specs
□ Microcopy đầy đủ cho mọi text element
□ Accessibility checklist đã pass
□ Design handoff spec đủ chi tiết để developer implement
□ File lưu đúng path: phase4-ux/features/[feature-name]-ux-spec.md
```
