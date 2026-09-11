# Accessibility - WCAG 2.2 Quick Reference & Component Patterns

> **Domain**: Design / Accessibility
> **Last Updated**: 2026-03-15
> **Nguồn**: WCAG 2.2 specification, WAI-ARIA Authoring Practices 1.2, MDN Accessibility Guide

---

## 1. WCAG 2.2 Level AA Requirements Summary

| Principle | Criterion | Level | Mô tả ngắn |
|-----------|-----------|-------|------------|
| **Perceivable** | 1.1.1 Non-text Content | A | Alt text cho images |
| | 1.3.1 Info and Relationships | A | Semantic HTML, labels liên kết với controls |
| | 1.3.4 Orientation | AA | Không lock orientation |
| | 1.3.5 Identify Input Purpose | AA | Autocomplete attributes cho form fields |
| | 1.4.1 Use of Color | A | Không dùng màu làm cách duy nhất truyền thông tin |
| | 1.4.3 Contrast (Minimum) | AA | 4.5:1 text, 3:1 large text |
| | 1.4.4 Resize Text | AA | Text resize 200% không mất chức năng |
| | 1.4.10 Reflow | AA | Responsive ở 320px không horizontal scroll |
| | 1.4.11 Non-text Contrast | AA | 3:1 cho UI components và graphics |
| | 1.4.12 Text Spacing | AA | Spacing override không vỡ layout |
| | 1.4.13 Content on Hover/Focus | AA | Tooltip dismissible, hoverable, persistent |
| **Operable** | 2.1.1 Keyboard | A | Mọi chức năng accessible via keyboard |
| | 2.1.2 No Keyboard Trap | A | Focus không bị kẹt |
| | 2.4.3 Focus Order | A | Focus order logic |
| | 2.4.4 Link Purpose | A | Link text mô tả được đích đến |
| | 2.4.7 Focus Visible | AA | Focus indicator visible |
| | 2.4.11 Focus Not Obscured | AA (WCAG 2.2) | Focused element không bị che khuất |
| | 2.5.3 Label in Name | A | Visual label nằm trong accessible name |
| | 2.5.8 Target Size | AA (WCAG 2.2) | Minimum 24×24px touch target |
| **Understandable** | 3.1.1 Language of Page | A | `lang` attribute trên `<html>` |
| | 3.2.2 On Input | A | Không thay đổi context khi user input |
| | 3.3.1 Error Identification | A | Mô tả rõ lỗi |
| | 3.3.2 Labels or Instructions | A | Form có labels |
| | 3.3.3 Error Suggestion | AA | Gợi ý sửa lỗi khi biết |
| **Robust** | 4.1.2 Name, Role, Value | A | ARIA đúng cho custom controls |
| | 4.1.3 Status Messages | AA | Status messages announce qua ARIA |

---

## 2. Color Contrast Ratios

| Text Type | Minimum (AA) | Enhanced (AAA) |
|-----------|:------------:|:--------------:|
| Normal text (< 18pt / 14pt bold) | **4.5:1** | 7:1 |
| Large text (≥ 18pt / 14pt bold) | **3:1** | 4.5:1 |
| UI components (border, icon) | **3:1** | — |
| Decorative elements | N/A | N/A |

**Công cụ kiểm tra:** [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/), Figma plugin "Contrast", Chrome DevTools CSS Overview.

**Thường gặp fail:** Placeholder text (#9CA3AF trên #FFFFFF = 2.4:1 — FAIL), disabled state text quá nhạt.

---

## 3. Alt Text Decision Tree

```
Hình ảnh có truyền tải thông tin không?
├── Không (decorative) → alt="" (empty string, KHÔNG bỏ thuộc tính)
├── Có → Hình ảnh là gì?
│   ├── Informative (photo, illustration) → Mô tả nội dung và context ngắn gọn
│   ├── Functional (button icon, logo link) → Mô tả chức năng ("Search", "Go to homepage")
│   ├── Complex (chart, diagram, infographic) → alt ngắn + longdesc hoặc nội dung text bên dưới
│   └── Text image → Viết lại chính xác text trong ảnh
```

**Ví dụ tốt:**
- `alt="Biểu đồ doanh thu Q1 2026 tăng 23% so với Q4 2025"` — mô tả insight, không chỉ mô tả hình thức
- `alt="Thêm vào giỏ hàng"` — cho icon button mua hàng

**Ví dụ sai:**
- `alt="image.jpg"` — tên file
- `alt="icon"` — mô tả hình thức

---

## 4. Keyboard Navigation Checklist

| Yêu cầu | Kiểm tra |
|---------|---------|
| Tab order logic | Đi từ trái → phải, trên → dưới, theo luồng đọc |
| Skip link | Link "Skip to main content" là phần tử đầu tiên có thể focus |
| Focus trap | Modal/dialog trap focus bên trong khi mở |
| Focus restore | Khi đóng modal, focus trả về trigger element |
| Escape key | Đóng modal, dropdown, tooltip khi nhấn Escape |
| Arrow keys | Navigation trong component phức tạp (menu, tab, listbox) |
| Enter/Space | Activate buttons và interactive elements |
| Home/End | Jump to first/last item trong list |

**Focus Indicator Requirements (WCAG 2.2):**
- Minimum 2px solid outline, contrast ≥ 3:1 với nền
- Không dùng `outline: none` mà không thay thế bằng custom style

```css
/* Đúng */
:focus-visible {
  outline: 2px solid #6366F1;
  outline-offset: 2px;
}

/* Sai */
:focus { outline: none; }
```

---

## 5. Touch Target Sizes

| Category | Minimum | Recommended | Áp dụng |
|----------|:-------:|:-----------:|--------|
| WCAG 2.2 AA | 24×24px | — | Mọi interactive element |
| iOS HIG | — | 44×44px | iOS apps |
| Material Design | — | 48×48px | Android apps |
| Web best practice | — | 44×44px | Mobile web |

**Lưu ý:** Touch target có thể lớn hơn visual size bằng cách dùng padding hoặc pseudo-element.

```css
/* Expand touch target mà không thay đổi visual */
.small-icon-button {
  position: relative;
}
.small-icon-button::after {
  content: '';
  position: absolute;
  inset: -10px; /* Mở rộng 10px mọi phía */
}
```

---

## 6. Form Accessibility Requirements

### Labeling Requirements

```html
<!-- Đúng: label liên kết với input -->
<label for="email">Email address <span aria-label="required">*</span></label>
<input id="email" type="email" autocomplete="email" aria-required="true" />

<!-- Đúng: aria-label khi không có visible label -->
<input type="search" aria-label="Search products" />

<!-- Sai: placeholder thay thế label -->
<input type="email" placeholder="Email address" />
```

### Error Identification Pattern

```html
<div>
  <label for="username">Username</label>
  <input
    id="username"
    type="text"
    aria-invalid="true"
    aria-describedby="username-error"
  />
  <span id="username-error" role="alert">
    Username must be at least 3 characters
  </span>
</div>
```

### Autocomplete Attributes (WCAG 1.3.5)

| Field type | `autocomplete` value |
|------------|---------------------|
| Họ tên đầy đủ | `name` |
| Email | `email` |
| Số điện thoại | `tel` |
| Địa chỉ | `street-address` |
| Thành phố | `address-level2` |
| Mã bưu chính | `postal-code` |
| Số thẻ tín dụng | `cc-number` |
| Mật khẩu hiện tại | `current-password` |

---

## 7. ARIA Quick Reference

### Thường dùng nhất

| ARIA attribute | Dùng khi | Ví dụ |
|----------------|---------|-------|
| `role` | HTML element không đủ semantic | `role="dialog"`, `role="status"` |
| `aria-label` | Không có visible text label | `aria-label="Close dialog"` |
| `aria-labelledby` | Label là element khác | `aria-labelledby="modal-title"` |
| `aria-describedby` | Có text mô tả thêm | `aria-describedby="field-hint"` |
| `aria-expanded` | Toggle state (dropdown, accordion) | `aria-expanded="true/false"` |
| `aria-selected` | Selected state (tabs, listbox) | `aria-selected="true"` |
| `aria-checked` | Checked state (checkbox, radio) | `aria-checked="true/false/mixed"` |
| `aria-disabled` | Disabled state | `aria-disabled="true"` |
| `aria-invalid` | Validation error | `aria-invalid="true"` |
| `aria-required` | Required field | `aria-required="true"` |
| `aria-live` | Dynamic content announcements | `aria-live="polite"` |
| `aria-hidden` | Ẩn với screen reader | `aria-hidden="true"` |

### Semantic HTML Trước, ARIA Sau

```
Thứ tự ưu tiên:
1. Dùng native HTML element (button, nav, main, article)
2. Nếu không thể → thêm role vào div/span
3. Không bao giờ dùng ARIA để "fix" semantic HTML sai
```

---

## 8. Common Component Accessibility Patterns

### Modal / Dialog

```
- role="dialog" + aria-modal="true"
- aria-labelledby trỏ tới tiêu đề modal
- Focus trap: Tab/Shift+Tab không ra ngoài
- Escape key → đóng modal
- Khi mở: focus vào element đầu tiên có thể focus trong modal
- Khi đóng: focus trả về trigger button
```

### Dropdown / Menu

```
- Trigger: aria-haspopup="listbox|menu" + aria-expanded
- Menu: role="menu", items: role="menuitem"
- Arrow Up/Down: navigate items
- Home/End: jump to first/last
- Enter/Space: select item
- Escape: đóng menu, focus về trigger
- Type-ahead: nhập ký tự để jump tới item khớp
```

### Tabs

```
- Tab list: role="tablist"
- Tab: role="tab" + aria-selected + aria-controls
- Panel: role="tabpanel" + aria-labelledby
- Tab key: di chuyển focus vào/ra khỏi tablist
- Arrow Left/Right: chuyển giữa các tabs (automatic hoặc manual activation)
```

### Accordion

```
- Header button: aria-expanded + aria-controls
- Panel: id khớp với aria-controls
- Enter/Space: toggle accordion
- Tab: di chuyển giữa accordion headers
```

### Tooltip

```
- Trigger: aria-describedby trỏ tới tooltip
- Tooltip: role="tooltip"
- Dismiss: Escape key
- Hoverable: chuột có thể di chuyển vào tooltip mà không mất (WCAG 1.4.13)
- Persistent: tooltip không tự đóng sau timeout
```

### Toast / Notification

```
- Container: aria-live="polite" (info/success) hoặc aria-live="assertive" (error)
- role="status" (info) hoặc role="alert" (error)
- Không dùng aria-live trên element mà inject nội dung vào sau
- Dùng aria-live trên container rỗng, sau đó insert content
```

---

## 9. Screen Reader Testing Checklist

| Test | NVDA (Windows) | VoiceOver (Mac) | VoiceOver (iOS) |
|------|:--------------:|:---------------:|:---------------:|
| Đọc page title | ✅ | ✅ | ✅ |
| Navigate bằng headings | H key | VO+Command+H | Swipe up/down |
| Navigate bằng landmarks | D key | VO+Command+L | Rotor |
| Form fields đọc label | Tab | Tab | Swipe |
| Buttons mô tả action | Enter | VO+Space | Double-tap |
| Error messages announce | Automatic | Automatic | Automatic |
| Images có alt text | Automatic | Automatic | Automatic |
| Modals trap focus | Tab | Tab | Swipe |

---

## 10. Testing Tools Reference

| Tool | Type | Bắt được | Không bắt được |
|------|------|---------|----------------|
| **axe DevTools** | Automated | ~30% WCAG issues | Ngữ nghĩa, context |
| **Lighthouse** | Automated | Accessibility score | Manual checks |
| **WAVE** | Automated | Structure, ARIA | Keyboard flow |
| **NVDA + Firefox** | Manual | Keyboard, screen reader | Visual issues |
| **VoiceOver + Safari** | Manual | iOS/Mac experience | Windows |
| **Keyboard-only** | Manual | Tab order, focus | Screen reader text |
| **Color Contrast Analyzer** | Manual | Exact contrast ratios | — |

**Quy trình test recommend:**
1. Chạy axe để bắt automated issues
2. Keyboard-only navigation (không nhìn screen reader)
3. NVDA test cho Windows users
4. VoiceOver test cho Mac/iOS users
5. Zoom 200% test
6. Thay đổi text spacing CSS và kiểm tra layout
