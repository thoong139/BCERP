# Playbook: Audit WCAG Compliance

> **Type**: Agent Skill Playbook
> **Agent**: accessibility-auditor
> **Triggered by**: Pre-deployment accessibility audit hoặc periodic review
> **Output**: WCAG Compliance Audit Report với pass/fail per criterion

---

## Khi nào dùng playbook này

- Trước khi deploy lên production (pre-deployment accessibility gate)
- Cuối mỗi sprint có UI changes đáng kể
- Khi nhận được yêu cầu accessibility audit từ stakeholder hoặc compliance team
- Sau khi team fix accessibility issues từ audit trước (re-audit)
- Khi dự án cần chứng nhận ADA / Section 508 / European Accessibility Act

---

## Procedure

### Bước 1: Xác định phạm vi audit

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE4 (UX design), PHASE3 (architecture)

Cần xác định:
□ Danh sách pages/views trong scope (không audit toàn bộ nếu scope lớn — ưu tiên critical paths)
□ Critical user journeys: đăng nhập, checkout, form submit, search, navigation chính
□ Custom interactive components: date picker, modal, accordion, tab, dropdown, carousel
□ Loại sản phẩm: web app / mobile web / desktop — ảnh hưởng đến test approach
□ Mức target: WCAG 2.2 AA (mặc định) hay AA+AAA (nếu yêu cầu đặc biệt)
□ REQ-ID liên quan đến accessibility — đọc req-registry.json

→ Ghi lại scope rõ ràng trong phần Overview của report
```

### Bước 2: Load knowledge và chuẩn bị criteria mapping

```
READ: .claude/references/team-expert/design/accessibility-checklist.md
READ: .claude/references/team-expert/testing/accessibility-testing-protocols.md

Tạo WCAG 2.2 AA criteria mapping cho scope đã xác định:

Nhóm tiêu chí theo 4 nguyên tắc POUR:
- PERCEIVABLE (1.x): Thông tin trình bày theo nhiều hình thức
- OPERABLE (2.x): Điều khiển được với nhiều thiết bị đầu vào
- UNDERSTANDABLE (3.x): Nội dung và hoạt động có thể hiểu được
- ROBUST (4.x): Tương thích với assistive technology

Đánh dấu criteria nào áp dụng cho scope hiện tại:
□ 1.1.1 — Non-text Content (alt text, ARIA labels)
□ 1.3.1 — Info and Relationships (semantic structure)
□ 1.3.2 — Meaningful Sequence (reading/navigation order)
□ 1.3.3 — Sensory Characteristics (không chỉ dùng hình dạng/màu sắc)
□ 1.3.4 — Orientation (không lock orientation) [WCAG 2.1+]
□ 1.3.5 — Identify Input Purpose (autocomplete attributes) [WCAG 2.1+]
□ 1.4.1 — Use of Color (không truyền thông tin chỉ bằng màu)
□ 1.4.2 — Audio Control (nếu có audio)
□ 1.4.3 — Contrast (Minimum) — 4.5:1 normal text, 3:1 large text
□ 1.4.4 — Resize Text (zoom 200% không mất nội dung)
□ 1.4.5 — Images of Text (tránh text dạng ảnh)
□ 1.4.10 — Reflow (zoom 400% không horizontal scroll) [WCAG 2.1+]
□ 1.4.11 — Non-text Contrast (UI components 3:1) [WCAG 2.1+]
□ 1.4.12 — Text Spacing (spacing override không phá layout) [WCAG 2.1+]
□ 1.4.13 — Content on Hover or Focus (tooltip behavior) [WCAG 2.1+]
□ 2.1.1 — Keyboard (mọi chức năng thực hiện được bằng bàn phím)
□ 2.1.2 — No Keyboard Trap
□ 2.1.4 — Character Key Shortcuts [WCAG 2.1+]
□ 2.4.1 — Bypass Blocks (skip links)
□ 2.4.2 — Page Titled
□ 2.4.3 — Focus Order (tab order hợp lý)
□ 2.4.4 — Link Purpose in Context
□ 2.4.7 — Focus Visible
□ 2.4.11 — Focus Not Obscured (Minimum) [WCAG 2.2+]
□ 2.4.12 — Focus Not Obscured (Enhanced) [WCAG 2.2+]
□ 2.4.13 — Focus Appearance [WCAG 2.2+]
□ 2.5.3 — Label in Name [WCAG 2.1+]
□ 2.5.4 — Motion Actuation [WCAG 2.1+]
□ 2.5.7 — Dragging Movements [WCAG 2.2+]
□ 2.5.8 — Target Size (Minimum) — 24x24px [WCAG 2.2+]
□ 3.1.1 — Language of Page
□ 3.2.1 — On Focus (không thay đổi context khi focus)
□ 3.2.2 — On Input (không thay đổi context khi input)
□ 3.3.1 — Error Identification
□ 3.3.2 — Labels or Instructions
□ 3.3.7 — Redundant Entry [WCAG 2.2+]
□ 3.3.8 — Accessible Authentication (Minimum) [WCAG 2.2+]
□ 4.1.2 — Name, Role, Value (ARIA completeness)
□ 4.1.3 — Status Messages [WCAG 2.1+]
```

### Bước 3: Chạy automated scan (Baseline)

```
Automated scan chỉ phát hiện ~30% vấn đề — đây là điểm khởi đầu, không phải kết luận.

Công cụ ưu tiên:
□ axe-core (accuracy cao, ít false positive): npx axe [url] --reporter json
□ Lighthouse: lighthouse [url] --only-categories=accessibility --output=json
□ WAVE (browser extension): chạy thủ công trên từng trang

Khi chạy automated scan:
□ Scan từng trang trong scope (không chỉ homepage)
□ Capture output JSON đầy đủ
□ Ghi nhận: số violations, incomplete checks (cần xác nhận thủ công), passes

Phân loại kết quả automated:
- Violations confirmed: axe đã xác định chắc chắn → ghi vào findings ngay
- Incomplete (needs review): axe không chắc → đưa vào manual testing list
- Passes: xác nhận nhưng không tin hoàn toàn — manual verify nếu critical

Các loại vấn đề automated thường phát hiện được:
□ Missing alt text trên img elements
□ Form inputs không có label liên kết
□ Contrast ratio violations (text trên background)
□ Missing lang attribute trên html element
□ Missing page title
□ Buttons/links không có accessible name
□ Skip link thiếu
□ Invalid ARIA roles hoặc attributes
```

### Bước 4: Kiểm tra color contrast (thủ công)

```
Automated tools thường miss: overlay states, gradient backgrounds, disabled states.

Contrast ratios bắt buộc (WCAG 2.2 AA):
□ Normal text (< 18pt hoặc < 14pt bold): tối thiểu 4.5:1
□ Large text (≥ 18pt hoặc ≥ 14pt bold): tối thiểu 3:1
□ UI components (button border, input border, icon): tối thiểu 3:1
□ Focus indicator: tối thiểu 3:1 so với adjacent background

Các trạng thái cần check riêng:
□ Default state
□ Hover state (hover color thay đổi contrast?)
□ Disabled state (thường fail — cần note là intentional nếu có rationale)
□ Error state (red có đủ contrast trên white không?)
□ Placeholder text (thường fail 4.5:1 — cần fix)
□ Link text vs surrounding body text (đủ contrast để phân biệt?)
□ Text trên hình nền gradient hoặc ảnh

Tools để đo contrast:
- Browser DevTools: color picker trong Accessibility panel
- WebAIM Contrast Checker: https://webaim.org/resources/contrastchecker/
- Figma plugin: Contrast hoặc Able

Ghi lại: component, state, foreground hex, background hex, ratio hiện tại, ratio yêu cầu
```

### Bước 5: Kiểm tra form accessibility

```
Forms là khu vực lỗi phổ biến nhất — kiểm tra kỹ.

Label liên kết đúng:
□ Mỗi input, select, textarea có label rõ ràng (for/id hoặc aria-labelledby)
□ Placeholder KHÔNG thay thế label — chỉ là gợi ý
□ Required fields có dấu hiệu rõ ràng không chỉ bằng màu (dấu *, text "(bắt buộc)")
□ Group liên quan dùng fieldset + legend (radio groups, checkbox groups)

Error handling:
□ Error message không chỉ dùng màu đỏ — phải có text mô tả lỗi
□ Error message liên kết với input qua aria-describedby
□ Input có aria-invalid="true" khi có lỗi
□ Error message xuất hiện gần input bị lỗi (không chỉ ở đầu trang)
□ Screen reader thông báo lỗi khi submit — dùng aria-live="polite" hoặc focus vào error

Validation messages:
□ Rõ ràng: "Email không hợp lệ" tốt hơn "Nhập sai"
□ Gợi ý cách sửa: "Email phải có định dạng example@domain.com"
□ Không biến mất ngay khi user bắt đầu gõ (tối thiểu hiển thị cho đến khi fix xong)

WCAG 2.2 Accessible Authentication (3.3.8):
□ Login form không yêu cầu cognitive test (puzzle, CAPTCHA phức tạp)
□ Nếu có CAPTCHA → phải có phương án thay thế (audio CAPTCHA, support contact)

Autocomplete attributes (1.3.5):
□ Các field thông dụng có đúng autocomplete attribute:
   name → autocomplete="name"
   email → autocomplete="email"
   phone → autocomplete="tel"
   password mới → autocomplete="new-password"
   password hiện tại → autocomplete="current-password"
```

### Bước 6: Kiểm tra alt text và media

```
Images:
□ Ảnh mang thông tin (content images): alt text mô tả đầy đủ nội dung
□ Ảnh trang trí (decorative): alt="" (empty string — bắt buộc có attr)
□ Ảnh là link: alt text mô tả đích đến, không phải nội dung ảnh
□ Infographic/biểu đồ: alt text hoặc text alternative chi tiết ở gần đó
□ Icons chỉ dùng icon (không có text): aria-label hoặc aria-labelledby bắt buộc
□ Icon kèm text label: icon là decorative → aria-hidden="true"

Alt text quality check:
□ Không bắt đầu bằng "Ảnh của", "Hình ảnh", "Image of" — screen reader đã thông báo đây là ảnh
□ Không quá dài (≤ 150 ký tự cho content images đơn giản)
□ Không dùng filename làm alt (img_001.jpg là alt xấu)
□ Không lặp lại caption hoặc surrounding text

Video/Audio (nếu có):
□ Video có captions (phụ đề) cho audio content
□ Audio có transcript
□ Autoplay: KHÔNG autoplay với âm thanh (hoặc có control để dừng ngay)
□ Embedded video player có keyboard controls
```

### Bước 7: Kiểm tra ARIA roles correctness

```
Nguyên tắc: Semantic HTML trước, ARIA chỉ bổ sung khi HTML không đủ.

Landmark roles:
□ <header> hoặc role="banner": chỉ 1 per page
□ <nav> hoặc role="navigation": có aria-label nếu có nhiều nav
□ <main> hoặc role="main": chỉ 1 per page
□ <footer> hoặc role="contentinfo": chỉ 1 per page
□ <aside> hoặc role="complementary": có aria-label nếu không rõ context
□ <section> nếu không có accessible name → không có landmark role → thêm aria-labelledby

Custom widget ARIA patterns (theo WAI-ARIA Authoring Practices Guide):
□ Modal dialog: role="dialog", aria-modal="true", aria-labelledby trỏ đến title
□ Tab panel: role="tablist" > role="tab" (có aria-selected) + role="tabpanel"
□ Accordion: button với aria-expanded, aria-controls trỏ đến panel
□ Dropdown menu: button với aria-expanded, aria-haspopup, role="menu" > role="menuitem"
□ Combobox: role="combobox" với aria-expanded, aria-controls, aria-autocomplete
□ Listbox: role="listbox" > role="option" (có aria-selected)
□ Tooltip: role="tooltip", trigger có aria-describedby

Common ARIA mistakes cần kiểm tra:
□ KHÔNG dùng role="button" trên <button> — redundant
□ KHÔNG dùng role="text" — không phải ARIA role hợp lệ
□ KHÔNG đặt interactive role (button, link) trong role="list" trừ khi là list items
□ aria-label phải ngắn gọn và mô tả hành động (không phải mô tả trạng thái)
□ aria-hidden="true" KHÔNG được bao giờ áp dụng lên element đang có focus
□ Presentational roles (role="none", role="presentation") không áp dụng cho interactive elements
```

### Bước 8: ARIA state management

```
Trạng thái động (cần update bằng JavaScript):
□ Modal mở: aria-expanded="true" trên trigger, aria-hidden="false" trên dialog
□ Modal đóng: aria-expanded="false" trên trigger, aria-hidden="true" trên dialog
□ Accordion item mở: aria-expanded="true" trên button
□ Tab active: aria-selected="true" trên tab, tabindex="0"; inactive: tabindex="-1"
□ Checkbox checked: aria-checked="true"
□ Loading: aria-busy="true" trên container đang load
□ Error: aria-invalid="true" trên input

Live regions cho dynamic content:
□ Thông báo không quan trọng (thành công, cập nhật): aria-live="polite"
□ Thông báo khẩn cấp (lỗi, cảnh báo): aria-live="assertive" (dùng hạn chế)
□ aria-atomic="true" khi cần đọc toàn bộ vùng, không chỉ phần thay đổi
□ KHÔNG dùng aria-live="off" — không có tác dụng gì

Kiểm tra JavaScript update:
□ Khi state thay đổi (click, submit, navigate) → ARIA attributes có được update không?
□ Dùng DevTools để inspect attributes trước và sau interaction
```

### Bước 9: Screen reader testing checklist

```
KHÔNG bỏ qua bước này — automated tools không thể replace.

Công cụ ưu tiên theo OS:
- Windows: NVDA (miễn phí) + Firefox/Chrome
- macOS/iOS: VoiceOver (built-in) + Safari
- Android: TalkBack + Chrome

Quy trình test từng user journey:
□ Mở screen reader → load page → không nhìn màn hình → hoàn thành task
□ Navigation bằng headings (H, Shift+H với NVDA)
□ Navigation bằng landmarks (D, Shift+D với NVDA)
□ Navigation bằng form fields (F, Shift+F với NVDA)
□ Navigation bằng links (K, Shift+K với NVDA)

Critical flows cần test với screen reader:
□ Login flow: điền form, submit, nhận thông báo thành công/thất bại
□ Form chính: điền từng field, nhận validation messages
□ Navigation chính: di chuyển qua các section
□ Modal/Dialog: mở, điều hướng nội dung, đóng, focus trả về
□ Dynamic content: sorting table, filter results, pagination

Ghi nhận:
□ Page có đọc được heading hierarchy rõ ràng không?
□ Tên của mỗi interactive element có mô tả đúng không?
□ Thứ tự đọc có khớp với thứ tự visual không?
□ Error messages có được thông báo ngay không?
□ Custom components có hoạt động theo expected keyboard pattern không?
```

### Bước 10: Tổng hợp WCAG Compliance Report

```
Cấu trúc report:

1. AUDIT OVERVIEW
   - Scope: pages/components đã audit
   - Date, auditor, WCAG version: 2.2 AA
   - Tools used: axe-core vX.X, Lighthouse vX, VoiceOver/NVDA
   - Test environment: browser versions, OS

2. EXECUTIVE SUMMARY
   - Tổng số findings: Critical / High / Medium / Low
   - Overall conformance verdict: PASS / PARTIAL / FAIL
   - Top 3 vấn đề nghiêm trọng nhất

3. WCAG CRITERIA RESULTS TABLE
   Format mỗi criterion:
   | Criterion | Title | Status | Findings |
   |-----------|-------|--------|---------|
   | 1.1.1     | Non-text Content | FAIL | 3 images missing alt |
   | 1.4.3     | Contrast | PASS | — |
   ...

   Status: PASS / FAIL / NOT APPLICABLE / NOT TESTED

4. FINDINGS LIST
   Mỗi finding:
   - ID: AUD-[NNN]
   - Severity: Critical / High / Medium / Low
   - WCAG Criterion: [số] [tên]
   - Component/Page: [tên page, component cụ thể]
   - Description: mô tả vấn đề rõ ràng
   - User Impact: ai bị ảnh hưởng, mức độ block
   - Evidence: screenshot, code snippet, hoặc screen reader output
   - Recommendation: cách sửa cụ thể kèm code example

5. POSITIVE FINDINGS
   - Patterns tốt cần giữ nguyên (để team không vô tình xóa)

6. REMEDIATION PRIORITY
   Critical → sửa trước khi deploy
   High → sửa trong sprint hiện tại
   Medium → sửa trong sprint tiếp theo
   Low → backlog, sửa khi có thời gian

7. RE-AUDIT RECOMMENDATION
   Đề xuất thời điểm re-audit sau khi fixes hoàn thành

Severity definitions cho Accessibility:
- Critical: Chặn hoàn toàn task completion cho user khuyết tật (keyboard trap, missing form label, broken screen reader flow)
- High: Gây khó khăn nghiêm trọng — user khuyết tật phải nỗ lực gấp nhiều lần (contrast fail, missing error msg)
- Medium: Không conform WCAG nhưng workaround tồn tại (sub-optimal ARIA, minor tab order issue)
- Low: Best practice violation, ảnh hưởng nhỏ (redundant alt text, minor landmark issue)
```

---

## Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase4-ux/accessibility-audit-[scope]-[date].md

Cấu trúc output:
1. WCAG Compliance Audit Report (đầy đủ theo template Bước 10)
2. Verdict: CONFORMANT / PARTIALLY CONFORMANT / NON-CONFORMANT
   - CONFORMANT: không có Critical/High findings
   - PARTIALLY CONFORMANT: có High issues với plan fix rõ ràng
   - NON-CONFORMANT: có Critical issues hoặc nhiều High issues chưa có plan
3. Action items với priority, WCAG criterion, và owner gợi ý
```

---

## Checklist trước khi submit

```
□ Scope đã được define rõ ràng (pages, components, user journeys)
□ Automated scan đã chạy (axe-core + Lighthouse) và kết quả được ghi nhận
□ Color contrast đã kiểm tra thủ công cho tất cả states (không chỉ default)
□ Forms đã kiểm tra: labels, errors, autocomplete, required fields
□ Alt text và media alternatives đã kiểm tra
□ ARIA roles và state management đã review
□ Screen reader testing đã thực hiện cho critical flows
□ Mỗi finding có WCAG criterion cụ thể (số + tên)
□ Mỗi finding có code fix example
□ Positive patterns đã ghi nhận
□ Verdict rõ ràng kèm remediation priority
□ Re-audit plan đã đề xuất
```
