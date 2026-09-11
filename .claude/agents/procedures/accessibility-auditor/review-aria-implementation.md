# Playbook: Review ARIA Implementation

> **Type**: Agent Skill Playbook
> **Agent**: accessibility-auditor
> **Triggered by**: Code review cho ARIA attributes hoặc audit component accessibility
> **Output**: ARIA Review Report với danh sách issues và code fixes cụ thể

---

## Khi nào dùng playbook này

- Khi developer submit PR có thêm ARIA attributes
- Khi audit custom interactive components (date picker, combobox, carousel, tree view)
- Sau khi `/wf-implement-feature` tạo component mới có ARIA implementation
- Khi nhận report "screen reader không đọc đúng"
- Khi cần verify component conform với WAI-ARIA Authoring Practices Guide (APG)

---

## Procedure

### Bước 1: Đọc component code và xác định scope

```
INPUT: Paths do skill cung cấp qua prompt (file code, PR diff, hoặc component folder)
FALLBACK: tra .claude/references/path-registry.md → CODE_PATHS (phase5)
READ: .claude/references/team-expert/design/accessibility-checklist.md (ARIA section)
READ: .claude/references/team-expert/testing/accessibility-testing-protocols.md (ARIA section)

Cần xác định:
□ Danh sách components trong scope review
□ Loại widget của từng component (button, dialog, tab, combobox, menu, v.v.)
□ Framework đang dùng (React, Vue, Angular, Svelte) — cú pháp ARIA khác nhau
□ Screen reader target: NVDA+Firefox, VoiceOver+Safari, hay cả hai
□ REQ-ID liên quan đến accessibility

Ghi nhận framework-specific patterns:
- React: aria-* props, htmlFor (không phải for), className (không phải class)
- Vue: :aria-* hoặc v-bind, :for
- Angular: [attr.aria-*]
- Svelte: aria-* trực tiếp
```

### Bước 2: Kiểm tra landmark regions

```
Kiểm tra cấu trúc landmark của page hoặc layout component:

Landmark requirements:
□ Có <header> hoặc role="banner" — chứa logo, site nav, search
□ Có <nav> hoặc role="navigation" — menu navigation chính
□ Có <main> hoặc role="main" — nội dung chính của page
□ Có <footer> hoặc role="contentinfo" — footer site
□ <aside> hoặc role="complementary" nếu có sidebar/related content

Nếu có nhiều nav:
□ Mỗi <nav> phải có aria-label phân biệt:
   <nav aria-label="Điều hướng chính">
   <nav aria-label="Điều hướng trang">
   KHÔNG được: hai nav không có label

Nếu có nhiều section/article:
□ <section> cần aria-labelledby hoặc aria-label để có landmark role
□ <section> không có accessible name → không là landmark (chỉ là generic)
□ <article> cho nội dung độc lập có thể tái sử dụng

Anti-patterns cần ghi lại:
□ role="banner" được đặt trong <article> hoặc <section> (không hợp lệ — chỉ trong <body> level)
□ Nhiều <main> trên cùng page
□ <nav> wrap toàn bộ page (không phải chỉ navigation links)
□ Lạm dụng role="region" cho mọi div container
```

### Bước 3: Kiểm tra heading hierarchy

```
Heading structure là "table of contents" cho screen reader user.

Rules:
□ Chỉ có một <h1> per page
□ Không skip levels: sau h2 phải là h3, không nhảy thành h4
□ Heading text mô tả đúng nội dung section bên dưới
□ Dùng heading vì cấu trúc, không vì visual style (đừng dùng h1 chỉ vì font to)

Kiểm tra:
□ Page title = h1
□ Section headers = h2
□ Sub-section headers = h3
□ Heading không bị ẩn (display: none) làm mất structure cho screen reader

Nhắc nhở team:
□ Nếu cần text lớn mà không phải heading → dùng CSS styling, không dùng h-tag
□ Nếu cần heading ẩn visual nhưng còn cho screen reader → .visually-hidden class

Ví dụ đúng:
<h1>Trang chủ - ERP System</h1>
  <h2>Danh sách đơn hàng</h2>
    <h3>Đơn hàng chờ xử lý</h3>
    <h3>Đơn hàng đã hoàn thành</h3>
  <h2>Thống kê tháng này</h2>
```

### Bước 4: Kiểm tra ARIA labels vs visible labels

```
WCAG 2.5.3 Label in Name: accessible name phải chứa visible label text.

Accessible name sources (theo thứ tự ưu tiên):
1. aria-labelledby (tham chiếu đến element khác)
2. aria-label (string trực tiếp)
3. <label for="..."> liên kết với input
4. title attribute (fallback cuối cùng, ít dùng)
5. Nội dung text của element (cho button, link)
6. alt attribute (cho img)

Kiểm tra cho từng interactive element:
□ Mỗi button có accessible name không? (text content, aria-label, hoặc aria-labelledby)
□ Icon-only buttons: aria-label bắt buộc ("Đóng", "Tìm kiếm", "Xóa")
□ Inputs: có <label for> liên kết đúng không?
□ aria-label có match với visible text không? (nếu button text là "Đặt hàng", aria-label không được là "Submit order" — WCAG 2.5.3 vi phạm)

Lỗi phổ biến:
□ aria-label override visible text bằng text khác ngôn ngữ
□ Dùng aria-label trên <div> không tương tác — vô nghĩa
□ aria-labelledby trỏ đến ID không tồn tại trong DOM
□ Button chỉ có icon, không có aria-label và không có title
□ Input có placeholder nhưng không có label — khi user điền xong placeholder mất, không biết field này là gì

aria-labelledby pattern đúng:
<h2 id="section-title">Thông tin giao hàng</h2>
<section aria-labelledby="section-title">...</section>

aria-label cho icon button:
<button aria-label="Đóng dialog" type="button">
  <svg aria-hidden="true">...</svg>
</button>
```

### Bước 5: Kiểm tra ARIA roles correctness

```
Kiểm tra từng role có trong code:

Native HTML vs ARIA role mapping (ưu tiên native):
□ <button> tốt hơn <div role="button">
□ <a href="..."> tốt hơn <span role="link">
□ <input type="checkbox"> tốt hơn <div role="checkbox">
□ <ul> + <li> tốt hơn <div role="list"> + <div role="listitem">

Nếu buộc phải dùng custom role — kiểm tra:
□ Role có hợp lệ trong ARIA spec không? (tham khảo WAI-ARIA Roles model)
□ Role có phù hợp với behavior của element không?
□ Required ARIA attributes của role có đủ không?
   - role="checkbox" → cần aria-checked
   - role="combobox" → cần aria-expanded, aria-controls
   - role="dialog" → cần aria-labelledby hoặc aria-label
   - role="progressbar" → cần aria-valuenow, aria-valuemin, aria-valuemax
   - role="slider" → cần aria-valuenow, aria-valuemin, aria-valuemax, aria-valuetext
   - role="tab" → cần aria-selected, aria-controls
   - role="tabpanel" → cần aria-labelledby

Roles không được đặt trên:
□ role="button" trên <input>, <select>, <textarea>
□ role="list" trên <table> elements
□ role="presentation" hoặc role="none" trên interactive elements (họ vẫn focusable — confusing)
□ role="heading" không có aria-level

Ví dụ pattern đúng cho modal:
<div
  role="dialog"
  aria-modal="true"
  aria-labelledby="modal-title"
  aria-describedby="modal-desc"
>
  <h2 id="modal-title">Xác nhận xóa</h2>
  <p id="modal-desc">Hành động này không thể hoàn tác.</p>
  ...
</div>
```

### Bước 6: Kiểm tra ARIA state management

```
ARIA states phải được cập nhật bằng JavaScript khi UI thay đổi.

Đọc code JavaScript để verify:

Toggle states:
□ Accordion header button: aria-expanded="true"/"false" (toggle khi click)
□ Dropdown trigger: aria-expanded="true"/"false", aria-haspopup="true"/"menu"/"listbox"
□ Tab: aria-selected="true" (active tab), aria-selected="false" (inactive)
□ Checkbox (custom): aria-checked="true"/"false"/"mixed"

Loading/Busy states:
□ Form button khi submit: aria-busy="true", aria-label thay đổi thành "Đang xử lý..."
□ Container đang load data: aria-busy="true"
□ aria-busy="false" sau khi load xong (không chỉ remove attribute)

Error states:
□ Input validation fail: aria-invalid="true"
□ Input validation pass: aria-invalid="false" (không chỉ remove)
□ Error message element: aria-live="polite" hoặc được link qua aria-describedby

Disabled states:
□ Custom disabled: aria-disabled="true" (khác với HTML disabled — vẫn focusable)
□ HTML disabled: input/button disabled — không cần aria-disabled (redundant)
□ Khi aria-disabled="true": element vẫn focusable nhưng không active — đảm bảo keyboard handler check

Hidden/Shown states:
□ Element ẩn hoàn toàn (không cần announce): aria-hidden="true"
□ Element hiện trở lại: aria-hidden="false" hoặc xóa attribute
□ NGUY HIỂM: aria-hidden="true" KHÔNG BAO GIỜ được apply lên element có focus
□ Modal overlay background: aria-hidden="true" là ĐÚNG (content background khi modal mở)
□ Page content khi modal mở: aria-hidden="true" trên #root/app container là ĐÚNG

Kiểm tra trong code: tìm các event handlers (onClick, onChange, onToggle) → xem có update ARIA attributes không
```

### Bước 7: Kiểm tra live regions

```
Live regions dùng cho dynamic content cần thông báo với screen reader.

Các loại live regions:
□ aria-live="polite": thông báo khi screen reader rảnh (kết quả search, success message)
□ aria-live="assertive": thông báo ngay lập tức (lỗi quan trọng, cảnh báo khẩn)
□ aria-live="off" (default): không thông báo

Built-in live region roles (ngắn gọn hơn):
□ role="status" = aria-live="polite" (cho status messages)
□ role="alert" = aria-live="assertive" + aria-atomic="true" (cho error messages)
□ role="log" = aria-live="polite" + aria-relevant="additions" (cho chat/activity feed)
□ role="timer" = live content thay đổi theo thời gian (countdown timer)

aria-atomic:
□ aria-atomic="true": đọc toàn bộ region khi có bất kỳ thay đổi (dùng cho short messages)
□ aria-atomic="false" (default): chỉ đọc phần thay đổi (dùng cho long lists)

aria-relevant:
□ "additions" (default): chỉ announce khi thêm node
□ "removals": announce khi xóa node
□ "text": announce khi text thay đổi
□ "all": announce tất cả thay đổi

Lỗi phổ biến:
□ Tạo live region sau khi inject content (phải tồn tại trong DOM trước khi content thay đổi)
□ Lạm dụng aria-live="assertive" cho mọi thứ — interrupt screen reader liên tục
□ Cập nhật aria-live region quá nhanh/nhiều lần → screen reader bỏ sót announcements
□ Toast notification không có live region → screen reader không biết

Ví dụ đúng:
<!-- Pattern: tạo sẵn trong DOM, inject content sau -->
<div role="status" aria-live="polite" aria-atomic="true" class="visually-hidden">
  <!-- JavaScript inject: "Đã lưu thành công" vào đây -->
</div>
```

### Bước 8: Kiểm tra widget patterns theo WAI-ARIA APG

```
Kiểm tra từng widget theo APG keyboard patterns:
□ Button: Enter+Space trigger, ưu tiên native <button>
□ Dialog: role="dialog" + aria-modal + focus trap + Escape close + focus restore
□ Tab: Arrow keys giữa tabs, Tab key ra ngoài, aria-selected state
□ Menu: Arrow navigation, Enter/Space select, Escape close, type-ahead
□ Combobox: aria-expanded + aria-controls, Arrow+Enter+Escape
□ Accordion: button + aria-expanded, aria-controls trỏ panel

Ghi nhận deviation khỏi APG pattern và mức độ nghiêm trọng
```

### Bước 9: Screen reader testing

```
Test NVDA+Firefox hoặc VoiceOver+Safari:
□ Landmarks, headings, form controls đọc đúng
□ Custom components: role, name, state đọc chính xác
□ State changes được announce (expanded, selected, invalid)
□ Error messages đọc khi focus vào field
```

### Bước 10: Tổng hợp ARIA Review Report

```
Cấu trúc report:

1. REVIEW OVERVIEW
   - Components/pages đã review
   - Date, reviewer, framework, screen readers dùng để test
   - WCAG 2.2 AA target

2. SUMMARY
   - Số issues: Critical / High / Medium / Low
   - Components conform WAI-ARIA APG: X/Y
   - Verdict: APPROVED / CHANGES REQUIRED / BLOCKED

3. FINDINGS LIST
   Mỗi finding:
   - ID: ARIA-[NNN]
   - Severity: Critical / High / Medium / Low
   - Category: Landmark / Heading / Label / Role / State / Live Region / Widget Pattern
   - WCAG Criterion: 1.3.1 / 4.1.2 / 4.1.3 / v.v.
   - Component: [tên component, file, line number]
   - Current implementation: code snippet hiện tại
   - Issue: mô tả vấn đề
   - Impact: screen reader user bị ảnh hưởng thế nào
   - Fix recommendation: code snippet đúng

4. POSITIVE FINDINGS
   - ARIA patterns đúng, đáng học hỏi

5. CODE FIX SUMMARY
   - Danh sách changes cần thiết theo priority

Verdict definitions:
- APPROVED: Không có Critical/High issues, component comply WAI-ARIA APG
- CHANGES REQUIRED: Có Medium/Low issues hoặc deviations nhỏ khỏi APG
- BLOCKED: Có Critical/High issues — screen reader users không dùng được component
```

---

## Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase4-ux/aria-review-[component]-[date].md

Cấu trúc output:
1. ARIA Review Report (đầy đủ theo template Bước 10)
2. Verdict: APPROVED / CHANGES REQUIRED / BLOCKED
3. Code fix snippets cho từng issue (copy-paste ready)
```

---

## Checklist trước khi submit

```
□ Landmark regions đã review (banner, nav, main, contentinfo)
□ Heading hierarchy đã kiểm tra (h1 duy nhất, không skip levels)
□ Mọi interactive element đều có accessible name
□ aria-label match với visible text (WCAG 2.5.3)
□ ARIA roles hợp lệ theo ARIA spec
□ Required attributes của mỗi role đã đủ
□ JavaScript state updates đã verify (expanded, selected, invalid, busy, hidden)
□ Live regions: polite cho status, assertive chỉ cho urgent alerts
□ Custom widgets so với WAI-ARIA APG pattern — deviations đã ghi nhận
□ Đã test với screen reader (NVDA hoặc VoiceOver) cho custom components
□ Mỗi finding có code snippet hiện tại VÀ code fix đúng
□ Không có finding nào thiếu WCAG criterion
□ Verdict rõ ràng: APPROVED / CHANGES REQUIRED / BLOCKED
```
