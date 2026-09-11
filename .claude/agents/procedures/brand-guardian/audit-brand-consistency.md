# Playbook: Audit Brand Consistency

> **Type**: Agent Skill Playbook
> **Agent**: brand-guardian
> **Triggered by**: Periodic brand audit hoặc sau khi team implement nhiều features
> **Output**: `.mc-data/docs/phase4-ux/brand/brand-consistency-audit.md`

---

## Khi nào dùng playbook này

- Định kỳ sau mỗi sprint hoặc major release
- Sau khi nhiều developer / designer đã implement UI trong một thời gian dài
- Khi stakeholder phản hồi "UI trông không nhất quán"
- Trước khi ra mắt product (go-live audit)
- Khi onboard dự án đã có UI để đánh giá brand health

---

## Procedure

### Bước 1: Đọc Brand Identity Reference

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK:
  → Đọc .mc-data/docs/phase4-ux/brand/brand-identity-guide.md (nếu tồn tại)
  → Đọc .mc-data/docs/phase4-ux/brand/brand-guidelines.md (nếu tồn tại)
  → Nếu không có file nào → ghi chú "Chưa có brand baseline" và
    thực hiện audit ở mức best-practices chung (WCAG, design consistency)

Cần extract từ brand docs:
□ Approved color values (hex codes)
□ Approved fonts và weights
□ Logo usage rules
□ Tone of voice characteristics
□ Icon style và specs
```

### Bước 2: Inventory tất cả UI Touchpoints

Lập danh sách tất cả màn hình và UI surfaces cần audit:

```
□ Landing page / Marketing pages
□ Authentication flows (login, signup, forgot password, onboarding)
□ Dashboard / Home screen
□ Core feature screens (theo từng module trong req-registry.json)
□ Settings / Profile pages
□ Error pages (404, 500, unauthorized)
□ Empty states (khi chưa có data)
□ Loading states (skeleton, spinner, progress bars)
□ Forms (input, select, checkbox, radio, date picker...)
□ Modals và dialogs
□ Notifications (toast, alerts, banners)
□ Email templates (transactional, marketing, notification emails)
□ Navigation (header, sidebar, mobile bottom nav, breadcrumbs)
□ Data tables và lists
□ Charts và data visualizations
□ Mobile views (nếu responsive hoặc mobile app)
```

### Bước 3: Kiểm tra Color Usage

Với mỗi touchpoint, đối chiếu màu đang dùng vs brand palette:

```markdown
Checklist Color Audit:
□ Primary color có đúng hex value không? (sai 1 ký tự là sai)
□ Hover/active states có dùng đúng Primary Dark không?
□ Background màu có nằm trong Neutral palette không?
□ Semantic colors nhất quán? (success luôn xanh lá, error luôn đỏ)
□ Có màu nào hardcode ngoài brand palette không?
□ Dark mode (nếu có): token mapping có nhất quán không?

WCAG Re-check (vì implementors có thể thay đổi):
□ Text trên brand primary background: contrast ≥ 4.5:1?
□ Text trên neutral backgrounds: contrast ≥ 4.5:1?
□ Success/warning/error icons: contrast ≥ 3:1?
□ Placeholder text: contrast ≥ 4.5:1? (thường fail)
□ Disabled state text: intentionally low contrast — có document không?
```

### Bước 4: Kiểm tra Typography Consistency

```markdown
Checklist Typography Audit:
□ Heading font có khớp với brand font không?
□ Body font có khớp không?
□ Font weights có đúng không? (600 vs 700 — sai weight là off-brand)
□ Font sizes có theo type scale không? (không dùng sizes lẻ ngoài scale)
□ Line heights có nhất quán không?
□ Letter spacing (đặc biệt với overline/caption) có đúng không?
□ Responsive: font size có scale đúng trên mobile không?
□ Có screen nào dùng system font thay vì brand font không?
```

### Bước 5: Kiểm tra Icon Consistency

```markdown
Checklist Icon Audit:
□ Tất cả icons có cùng visual style (outline / filled / duotone)?
□ Icon size có nhất quán theo grid (16/24/32px)?
□ Stroke width có nhất quán?
□ Có icons từ nhiều thư viện khác nhau không? (mix Heroicons + Material + custom)
□ Có icons custom sai grid hoặc sai style không?
□ Icons có màu đúng brand palette không?
□ Icons có SVG format đúng không? (viewBox, accessible title)
```

### Bước 6: Kiểm tra Spacing Consistency

```markdown
Checklist Spacing Audit:
□ Spacing giữa components có theo 4px/8px grid không?
□ Padding bên trong cards/panels có nhất quán không?
□ Gap giữa form elements có nhất quán không?
□ Section spacing (major layout sections) có nhất quán không?
□ Có spacing magic number nào (ví dụ: margin: 13px, padding: 7px) không?
□ Mobile: spacing có đủ cho touch targets (min 44px)?
```

### Bước 7: Kiểm tra Tone of Voice trong Microcopy

```markdown
Checklist Tone Audit (đọc tất cả text trong UI):
□ Error messages: có helpful và non-blaming không?
   Vi phạm thường gặp: "Invalid input" (không helpful) vs "Email phải có dạng name@example.com"
□ Empty states: có actionable prompt không?
   Vi phạm: "No data" vs "Chưa có dự án. Tạo dự án đầu tiên →"
□ Button labels: có verb + object rõ ràng không?
   Vi phạm: "Submit" vs "Lưu thay đổi", "OK" vs "Xác nhận xóa"
□ Loading messages: có informative không?
   Vi phạm: "Loading..." vs "Đang tải danh sách..."
□ Success messages: có ngắn gọn và affirming không?
□ Confirmation dialogs: có nêu rõ hậu quả không?
   Ví dụ: "Bạn có chắc?" vs "Xóa sẽ xóa vĩnh viễn, không khôi phục được."
□ Terminology nhất quán: cùng 1 khái niệm có dùng nhiều tên khác nhau không?
```

### Bước 8: Kiểm tra Logo Usage

```markdown
Checklist Logo Audit:
□ Logo có xuất hiện đúng trong header, favicon, email header không?
□ Clear space có bị vi phạm không?
□ Logo có bị resize sai tỷ lệ không?
□ Logo trên dark background có dùng white variant không?
□ Favicon có đúng icon-only variant không?
□ Logo trong email có hiển thị đúng không?
```

### Bước 9: Kiểm tra Error/Empty States và Loading

```markdown
Checklist State Design Audit:
□ Error pages (404, 500): có dùng brand colors không? Có logo không? Có helpful message không?
□ Empty states: có illustration/icon đúng brand style không?
□ Loading skeleton: có dùng brand neutral colors không?
□ Spinner/progress: có dùng brand primary color không?
□ Form validation errors: styling có nhất quán không?
□ Network error states: có fallback UI không?
```

### Bước 10: Kiểm tra Email và Notification Templates

```markdown
Checklist Communications Audit:
□ Transactional emails: có logo đúng không?
□ Email header background: có dùng brand primary không?
□ Email body font: có phải web-safe font fallback không? (email clients không load custom fonts)
□ CTA buttons trong email: có brand colors không?
□ Email footer: có đủ unsubscribe link, company info không?
□ Push notifications (nếu có): title và body có đúng brand voice không?
□ In-app notifications: có icon, màu đúng semantic colors không?
```

### Bước 11: Ghi Audit Report

```
OUTPUT PATH: .mc-data/docs/phase4-ux/brand/brand-consistency-audit.md

Cấu trúc report:
```

```markdown
# Brand Consistency Audit Report

**Ngày audit**: [date]
**Phiên bản audit**: [version]
**Auditor**: brand-guardian
**Scope**: [Danh sách màn hình/touchpoints đã audit]

---

## Executive Summary

**Brand Health Score**: [X/10]
[2-3 dòng: nhận xét tổng thể — điểm mạnh, điểm yếu chính]

**Critical Issues**: [Số lượng]
**Warnings**: [Số lượng]
**Passes**: [Số lượng]

---

## Color Consistency

| Touchpoint | Issue | Severity | Recommendation |
|-----------|-------|----------|----------------|
| [Screen] | [Mô tả vi phạm] | Critical/Warning/Pass | [Cách sửa] |

### WCAG Violations
| Element | Foreground | Background | Actual Ratio | Required | Status |
|---------|-----------|-----------|-------------|---------|--------|
| [element] | #hex | #hex | X:1 | 4.5:1 | FAIL |

---

## Typography Consistency

| Touchpoint | Issue | Severity | Recommendation |
|-----------|-------|----------|----------------|

---

## Icon Consistency

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|

---

## Spacing Consistency

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|

---

## Microcopy & Tone of Voice

| Current Text | Issue | Suggested Replacement |
|-------------|-------|----------------------|

---

## Logo Usage

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|

---

## State Design (Error/Empty/Loading)

| State | Touchpoint | Issue | Recommendation |
|-------|-----------|-------|----------------|

---

## Priority Fix List

### Critical (sửa ngay — ảnh hưởng brand credibility và accessibility)
1. [Issue + location + fix]

### High (sửa trong sprint tiếp theo)
1. [Issue + location + fix]

### Medium (backlog — cải thiện dần)
1. [Issue + location + fix]

---

## Điểm cần ghi nhận (Passes)
[Những gì đang làm tốt — để maintain]
```

---

## Checklist trước khi submit

```
□ Đã audit đủ tất cả touchpoints trong scope
□ Mọi WCAG violation có contrast ratio số cụ thể
□ Priority list phân loại rõ Critical / High / Medium
□ Suggested replacement text cho mọi microcopy issue
□ Executive summary phản ánh đúng tình trạng tổng thể
□ File output ghi vào đúng path: .mc-data/docs/phase4-ux/brand/brand-consistency-audit.md
```
