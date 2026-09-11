# Testing - Accessibility Testing Protocols

> **Domain**: Testing / Accessibility (a11y)
> **Last Updated**: 2026-03-15

---

## 1. Giao thức Test Screen Reader

```markdown
# Phiên Test Screen Reader

## Cấu hình
**Screen Reader**: [VoiceOver / NVDA / JAWS]
**Trình duyệt**: [Safari / Chrome / Firefox]
**Hệ điều hành**: [macOS / Windows / iOS / Android]

## Test Điều Hướng
**Cấu trúc Heading**: [h1 → h2 → h3 logic không?]
**Landmark Regions**: [main, nav, banner, contentinfo có nhãn?]
**Skip Links**: [Bỏ qua đến nội dung chính được?]
**Tab Order**: [Focus di chuyển logic?]
**Hiển thị Focus**: [Focus indicator rõ ràng?]

## Test Component Tương Tác
**Buttons**: [Role + label? State changes thông báo?]
**Links**: [Phân biệt với buttons? Đích đến rõ ràng?]
**Forms**: [Labels liên kết? Required thông báo? Errors xác định?]
**Modals/Dialogs**: [Focus trap? Escape đóng? Focus trả về?]
**Custom Widgets**: [ARIA roles + keyboard patterns đúng?]

## Test Nội Dung Động
**Live Regions**: [Status messages thông báo tự động?]
**Loading States**: [Tiến trình truyền đạt?]
**Error Messages**: [Thông báo ngay? Liên kết field?]
**Toast/Notifications**: [aria-live? Dismiss được?]

## Kết Quả
| Component | Screen Reader đọc | Mong đợi | Status |
|-----------|-------------------|----------|--------|
| [Tên] | [Nội dung đọc] | [Nội dung nên là] | PASS/FAIL |
```

---

## 2. Audit Điều Hướng Bàn Phím

### Checklist Toàn cục
- [ ] Tất cả elements tương tác reachable qua Tab
- [ ] Tab order tuân theo logic bố cục
- [ ] Skip navigation link hoạt động
- [ ] Không có keyboard traps
- [ ] Focus indicator hiển thị mọi lúc
- [ ] Escape đóng modals/dropdowns/overlays
- [ ] Focus trả về trigger element sau khi đóng

### Component-Specific Patterns

**Tabs:**
- [ ] Tab key di chuyển vào/ra tablist
- [ ] Arrow keys di chuyển giữa tab buttons
- [ ] Home/End → tab đầu/cuối
- [ ] aria-selected chỉ thị tab active

**Menus:**
- [ ] Arrow keys điều hướng menu items
- [ ] Enter/Space kích hoạt item
- [ ] Escape đóng menu, trả focus

**Carousels/Sliders:**
- [ ] Arrow keys di chuyển slides
- [ ] Pause/stop control accessible
- [ ] Vị trí hiện tại thông báo

**Data Tables:**
- [ ] Headers liên kết cells qua scope/headers
- [ ] Caption hoặc aria-label mô tả mục đích
- [ ] Sortable columns thao tác bằng bàn phím

---

## 3. WCAG 2.2 AA Quick Reference

### Perceivable
| Criterion | Tên | Target |
|-----------|-----|--------|
| 1.1.1 | Non-text Content | Alt text cho mọi hình ảnh |
| 1.3.1 | Info and Relationships | Semantic HTML, ARIA |
| 1.4.1 | Use of Color | Không dùng color alone |
| 1.4.3 | Contrast Minimum | Text ≥4.5:1, large text ≥3:1 |
| 1.4.4 | Resize Text | Zoom 200% không mất content |
| 1.4.11 | Non-text Contrast | UI components ≥3:1 |

### Operable
| Criterion | Tên | Target |
|-----------|-----|--------|
| 2.1.1 | Keyboard | Mọi chức năng bằng keyboard |
| 2.1.2 | No Keyboard Trap | Luôn Tab ra được |
| 2.4.3 | Focus Order | Tab order logic |
| 2.4.7 | Focus Visible | Focus indicator rõ ràng |
| 2.5.8 | Target Size (Minimum) | Touch targets ≥24x24px |

### Understandable
| Criterion | Tên | Target |
|-----------|-----|--------|
| 3.1.1 | Language of Page | lang attribute |
| 3.2.1 | On Focus | Không thay đổi context khi focus |
| 3.3.1 | Error Identification | Lỗi mô tả bằng text |
| 3.3.2 | Labels or Instructions | Form fields có label |

### Robust
| Criterion | Tên | Target |
|-----------|-----|--------|
| 4.1.2 | Name, Role, Value | ARIA đúng cho custom components |
| 4.1.3 | Status Messages | Live regions cho dynamic content |

---

## 4. Severity Classification

| Severity | Định nghĩa | Ví dụ |
|----------|------------|-------|
| Critical | Chặn hoàn toàn access | Form submit button không keyboard accessible |
| Serious | Rào cản lớn, cần workaround | Missing form labels |
| Moderate | Gây khó khăn | Contrast ratio 3.5:1 (target 4.5:1) |
| Minor | Bất tiện | Thiếu skip link |

---

## 5. Pháp lý & Quy định

| Quy định | Phạm vi | Tiêu chuẩn |
|----------|---------|-----------|
| ADA Title III | US web applications | WCAG 2.1 AA |
| European Accessibility Act | EU digital products | EN 301 549 (WCAG 2.1 AA) |
| Section 508 | US government | WCAG 2.0 AA |
