# Playbook: Test Keyboard Navigation

> **Type**: Agent Skill Playbook
> **Agent**: accessibility-auditor
> **Triggered by**: Khi cần test keyboard-only navigation cho một trang hoặc component
> **Output**: Keyboard Navigation Test Report với danh sách pass/fail per navigation path

---

## Khi nào dùng playbook này

- Trước khi release bất kỳ page hoặc interactive component mới
- Khi team báo cáo "không dùng được bằng bàn phím"
- Trong quá trình `/wf-implement-feature` khi component có keyboard interaction
- Khi audit toàn bộ application cho WCAG 2.1.1 (Keyboard) và 2.1.2 (No Keyboard Trap)
- Khi testing modal dialogs, dropdowns, date pickers, complex widgets

---

## Procedure

### Bước 1: Xác định navigation paths cần test

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE4 (UX), PHASE2 (features)
READ: .claude/references/team-expert/testing/accessibility-testing-protocols.md (Section keyboard)

Lập danh sách navigation paths theo thứ tự ưu tiên:

Critical paths (test trước):
□ Login / Authentication flow
□ Primary navigation (main menu)
□ Core feature workflows (đặc thù theo dự án)
□ Form submission flows
□ Modal dialogs và overlays
□ Checkout / Payment flow (nếu có)

Standard paths (test sau):
□ Secondary navigation (sidebar, tabs, breadcrumbs)
□ Search functionality
□ Filters và sorting
□ Pagination
□ Dropdown menus
□ Accordion panels
□ Date pickers / Time pickers

Ghi lại: page name, start point, end point, actions giữa chừng
```

### Bước 2: Thiết lập test environment

```
Setup cho keyboard-only test:
□ Tắt hoặc không dùng chuột trong suốt quá trình test
□ Dùng tab/shift+tab để di chuyển — KHÔNG click
□ Bật "Show keyboard navigation" trong browser nếu có
□ Resize browser về viewport thông thường (1280x800 là baseline)

Phím tắt cơ bản cần biết:
Tab          → focus phần tử tiếp theo
Shift+Tab    → focus phần tử trước đó
Enter        → kích hoạt link, button; submit form
Space        → kích hoạt button, checkbox; scroll page
Arrow keys   → di chuyển trong widget (menu, listbox, tablist, radiogroup)
Escape       → đóng modal, dropdown, tooltip
Home/End     → đầu/cuối danh sách (trong listbox, combobox)
Page Up/Down → scroll trong scrollable regions

Browsers cần test (ưu tiên):
□ Chrome (Windows/macOS) — baseline
□ Firefox (Windows/macOS) — thường expose focus issues khác Chrome
□ Safari (macOS) — cần bật Keyboard Navigation trong Settings > Accessibility
```

### Bước 3: Kiểm tra tab order

```
Test từng page trong scope:

Quy trình:
1. Load page
2. Nhấn Tab liên tục — ghi lại thứ tự focus di chuyển
3. So sánh với thứ tự visual (từ trái sang phải, từ trên xuống dưới)

Tab order phải thỏa mãn:
□ Thứ tự focus khớp với thứ tự đọc visual (không nhảy loạn)
□ Không bỏ qua elements tương tác (tất cả links, buttons, inputs có thể focus)
□ Không focus vào elements không tương tác (decorative text, icons, containers)
□ tabindex="0" chỉ dùng khi thực sự cần — không lạm dụng
□ tabindex > 0 là anti-pattern — ghi lại nếu phát hiện

Common tab order issues:
□ CSS position: absolute/fixed elements bị tách khỏi DOM order → focus nhảy
□ display: none ẩn nhưng element vẫn trong tab order (bug)
□ Visually hidden elements (opacity: 0, visibility: hidden) vẫn focusable (bug)
□ Fixed header che khuất focused element khi scroll (WCAG 2.4.11 — Focus Not Obscured)

Ghi nhận: số thứ tự của từng element theo tab order thực tế
```

### Bước 4: Kiểm tra focus indicator visibility

```
Focus indicator là yêu cầu bắt buộc WCAG 2.4.7 (Focus Visible) và 2.4.13 (Focus Appearance) [WCAG 2.2].

Kiểm tra cho mỗi loại element:
□ Links: focus indicator rõ ràng (outline, underline, hoặc background change)
□ Buttons: focus ring visible, không bị CSS override thành outline: none
□ Inputs: border highlight hoặc outline khi focused
□ Custom components (tab, accordion, dropdown): có custom focus style không?
□ Skip link: visible khi focused (thường ẩn khi không focus)

WCAG 2.4.13 Focus Appearance requirements (WCAG 2.2 AA):
□ Focus indicator có diện tích tối thiểu bao quanh component
□ Contrast ratio của focus indicator ≥ 3:1 so với adjacent unfocused state
□ Focus indicator không bị che khuất hoàn toàn bởi author-created content

Lỗi phổ biến:
□ * { outline: none } hoặc *:focus { outline: none } → xóa focus indicator hoàn toàn
□ :focus style có nhưng không :focus-visible → xuất hiện với cả mouse click (ít sao)
□ Focus bị sticky header che khuất (scroll xảy ra nhưng element vẫn bị che)
□ Focused element bị tooltip/toast che khuất

Ghi nhận: element type, pass/fail, screenshot nếu có vấn đề
```

### Bước 5: Kiểm tra focus trap trong modals và dialogs

```
Focus trap là BẮT BUỘC cho modal dialogs — người dùng bàn phím không được "thoát" khỏi modal.

Test quy trình modal:

Khi modal mở:
□ Focus có tự động chuyển vào modal không? (vào element đầu tiên focusable, hoặc title)
□ Tab di chuyển trong modal — có bị thoát ra ngoài không? (phải bị trap)
□ Shift+Tab đi ngược lại — có thoát ra ngoài không? (phải bị trap)
□ Escape đóng modal không?

Khi modal đóng:
□ Focus có trả về trigger element (button đã mở modal) không?
□ Focus có bị mất (không focus đâu cả) không? (là lỗi)
□ Nếu trigger bị xóa khỏi DOM → focus về đâu? (phải có fallback)

Modal anti-patterns cần ghi lại:
□ Overlay backdrop có thể focus bằng Tab (không nên)
□ Close button ở đầu modal nhưng focus vào cuối (khó tìm)
□ Focus trap implement nhưng bỏ sót iframe bên trong modal
□ Multiple modals stack — focus trap của modal dưới vẫn active?

Tương tự cho: drawer/sidebar overlays, tooltip với interactive content, popover
```

### Bước 6: Kiểm tra skip links functionality

```
Skip links giúp keyboard user bỏ qua navigation lặp lại — WCAG 2.4.1 (Bypass Blocks).

Test quy trình:
□ Load page → Tab lần đầu → skip link có xuất hiện không?
□ Skip link visible khi focused (không phải invisible)
□ Nhấn Enter trên skip link → focus có nhảy đến main content không?
□ Sau khi skip → Tab tiếp theo có đúng chỗ (bên trong main) không?

Các skip link cần có:
□ "Skip to main content" (bắt buộc nếu có navigation header)
□ "Skip to navigation" (tùy chọn, hữu ích nếu có large content before nav)

Common skip link bugs:
□ href="#main" nhưng không có element với id="main" → không làm gì
□ Skip link visible nhưng focus không thực sự move (chỉ scroll, không set focus)
□ Skip link ẩn hoàn toàn ngay cả khi focused (display: none trong mọi state)
□ Multiple skip links không có label phân biệt

Kiểm tra trên mỗi page riêng biệt (homepage vs interior pages thường khác nhau)
```

### Bước 7: Kiểm tra keyboard shortcuts (non-conflicting)

```
Nếu application có keyboard shortcuts (hotkeys):

WCAG 2.1.4 Character Key Shortcuts [WCAG 2.1+]:
□ Single-character shortcuts (letters, numbers, punctuation) có thể:
   - Tắt (turn off)
   - Remapping (user có thể đổi sang key khác)
   - Chỉ active khi component có focus (không global)
□ Nếu không thỏa — ghi là WCAG 2.1.4 violation

Kiểm tra xung đột với screen reader shortcuts:
□ Các phím screen reader dùng: H (heading), B (button), F (form), L (list)
□ Custom shortcuts không được overwrite các phím đơn thông dụng khi global
□ Shortcuts cần Ctrl/Alt modifier là an toàn hơn

Ghi nhận: tên shortcut, phím, có thể remapping không, có xung đột không
```

### Bước 8: Kiểm tra dynamic content keyboard access

```
Dynamic content = nội dung thay đổi sau initial load.

Infinite scroll / Load more:
□ "Load more" button có focusable không?
□ Sau khi load → focus có tự jump xuống content mới không? (thường không nên — confusing)
□ Keyboard user có biết content mới đã load không? (aria-live announcement)

Tab panels:
□ Tab key di chuyển giữa tabs không? (KHÔNG — phải dùng arrow keys theo APG pattern)
□ Arrow keys di chuyển giữa tabs (left/right hoặc up/down)
□ Tab key chuyển focus vào tabpanel nội dung
□ Inactive tabs có tabindex="-1" không?

Accordion:
□ Tab di chuyển giữa accordion headers
□ Enter/Space expand/collapse panel
□ Expanded panel: Tab tiếp theo đi vào nội dung panel
□ Collapse panel: focus trả về header

Dropdown menu:
□ Enter/Space mở menu
□ Arrow keys di chuyển giữa menu items
□ Escape đóng menu, focus trả về trigger
□ Home/End nhảy đến item đầu/cuối
□ Click outside hoặc focus out đóng menu

Live search / Autocomplete:
□ Kết quả hiện ra khi gõ
□ Arrow keys di chuyển trong suggestions list
□ Enter chọn suggestion
□ Escape đóng suggestions list
□ Không có keyboard results thì thông báo (aria-live)

Date picker:
□ Keyboard accessible? (nhiều date pickers chỉ dùng được với chuột)
□ Arrow keys di chuyển giữa dates
□ Enter chọn date
□ Page Up/Down chuyển tháng
□ Fallback text input hoạt động không?
```

### Bước 9: Kiểm tra error và success feedback không cần chuột

```
Thông báo kết quả cần được keyboard user nhận biết — không chỉ visual.

Form submission errors:
□ Submit form thiếu fields → error messages xuất hiện
□ Focus có nhảy về field đầu tiên có lỗi không? (tốt nhất)
□ Hoặc focus về summary error ở đầu form (chấp nhận)
□ Mỗi error message có ID và input có aria-describedby trỏ đến?
□ Error message readable khi focus vào input (screen reader đọc ra)

Success notifications:
□ Toast/snackbar thành công — keyboard user có biết không?
□ aria-live="polite" cho success messages → screen reader đọc khi rảnh
□ Redirect sau submit — page title rõ ràng nói về trạng thái mới

Loading states:
□ Button click → button có thông báo "đang xử lý" không? (aria-busy + aria-label)
□ Nếu disabled trong khi loading → có aria-disabled="true" không?
□ Load xong → focus đi đâu? (phải có intent rõ ràng)

In-page navigation (anchor links):
□ Click internal link → focus có move đến target section không?
□ Target section có thể focus không? (cần tabindex="-1" hoặc focusable element)
```

### Bước 10: Test cross-browser

```
Keyboard behavior khác nhau giữa browsers:

Chrome (Windows/macOS):
□ Tab behavior chuẩn
□ Spacebar scroll default (có thể conflict với page scroll)

Firefox (Windows/macOS):
□ Đôi khi focus order khác Chrome do CSS rendering
□ Tốt hơn Chrome cho một số ARIA patterns

Safari (macOS):
□ Mặc định: Tab chỉ focus form elements — cần bật "Press Tab to highlight each item" trong System Preferences > Keyboard > Shortcuts
□ Option+Tab (macOS) thay vì Tab thông thường trong một số configs
□ VoiceOver + Safari là combination quan trọng nhất cho iOS

Edge (Windows):
□ Chạy Chromium engine — behavior giống Chrome

Ghi nhận: browser nào có vấn đề riêng, vấn đề cụ thể là gì
```

### Bước 11: Tổng hợp Keyboard Navigation Test Report

```
Cấu trúc report:

1. TEST OVERVIEW
   - Pages/components đã test
   - Date, tester, browsers tested
   - Test method: keyboard-only (không dùng chuột)

2. SUMMARY TABLE
   | Navigation Path | Tab Order | Focus Visible | Focus Trap | Skip Links | Overall |
   |----------------|-----------|---------------|------------|------------|---------|
   | Login flow      | PASS      | FAIL          | N/A        | PASS       | FAIL    |
   ...

3. FINDINGS LIST
   Mỗi finding:
   - ID: KEY-[NNN]
   - Severity: Critical / High / Medium / Low
   - WCAG Criterion: 2.1.1 / 2.1.2 / 2.4.1 / 2.4.3 / 2.4.7 / 2.4.11 / 2.4.13
   - Location: page, component, interaction step
   - Description: mô tả vấn đề cụ thể
   - Steps to reproduce: keyboard actions cụ thể để tái hiện
   - Expected behavior: keyboard user kỳ vọng gì
   - Actual behavior: thực tế xảy ra gì
   - Recommendation: cách sửa kèm code example

4. PASSES (POSITIVE FINDINGS)
   - Liệt kê những gì đã làm tốt

5. VERDICT: PASS / FAIL
   - PASS: Không có Critical/High issues
   - FAIL: Có Critical hoặc High issues
```

---

## Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase4-ux/keyboard-navigation-test-[scope]-[date].md

Cấu trúc output:
1. Keyboard Navigation Test Report (đầy đủ theo template Bước 11)
2. Verdict: PASS / FAIL
3. Priority action items cho developer
```

---

## Checklist trước khi submit

```
□ Đã test keyboard-only (không dùng chuột trong suốt quá trình test)
□ Tab order đã verify cho tất cả pages trong scope
□ Focus indicator visibility đã kiểm tra cho mọi loại interactive element
□ Focus trap trong modals đã test (open, trap, close, focus return)
□ Skip links đã test (visibility, functionality, target)
□ Keyboard shortcuts đã kiểm tra conflict nếu có
□ Dynamic content (tabs, accordions, dropdowns, live search) đã test
□ Error/success feedback đã test không cần chuột
□ Đã test trên ít nhất Chrome + Firefox
□ Mỗi finding có WCAG criterion và steps to reproduce cụ thể
□ Mỗi finding có code fix recommendation
□ Verdict rõ ràng: PASS / FAIL
```
