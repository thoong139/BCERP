# Playbook: Audit UX Hệ thống Hiện có

> **Type**: Agent Skill Playbook
> **Agent**: ux-designer
> **Triggered by**: /wf-legacy-scan khi có UI, hoặc yêu cầu UX audit định kỳ
> **Output**: `.mc-data/docs/phase4-ux/ux-audit-report.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có UI — cần đánh giá UX hiện trạng trước khi thiết kế lại
- Khi nhận feedback "UX kém" nhưng chưa biết vấn đề cụ thể ở đâu
- Audit định kỳ sau khi deploy feature mới
- Khi cần tạo UX debt inventory để lên kế hoạch refactor

---

## Procedure

### Bước 1: Thu thập context và scope audit

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0 (project type), PHASE2 (features)

Xác định scope:
□ Audit toàn bộ ứng dụng hay một số flows cụ thể?
□ Platform: Web / Mobile / Both?
□ User segments quan trọng nhất cần focus?
□ Có dữ liệu analytics không? (conversion rate, drop-off, error rates)
□ Có feedback từ users không? (complaints, support tickets, reviews)
□ Design system hiện tại có documented không?

Thu thập materials:
□ Danh sách screens / pages hiện có
□ Các user flows quan trọng (login, onboarding, core tasks, payment...)
□ Analytics data nếu có
□ Support tickets / user complaints nếu có
□ Screenshots hoặc mô tả UI nếu có (Claude không thể chạy app)
```

### Bước 2: Heuristic Evaluation — Nielsen's 10 Heuristics

```
READ: ux-research-methods.md → Section 1: Heuristic Evaluation

Đánh giá hệ thống theo 10 heuristics của Nielsen Norman Group.
Với mỗi heuristic, liệt kê violations tìm thấy.

Severity Rating:
0 = Không phải vấn đề
1 = Cosmetic (sửa nếu có thời gian)
2 = Minor (ưu tiên thấp)
3 = Major (ưu tiên cao)
4 = Catastrophic (phải sửa trước khi release)

---

Với mỗi heuristic (H1-H10), liệt kê violations tìm thấy:
H1: Visibility of System Status (loading, progress, feedback)
H2: Match Real World (terminology, icons, metaphors, locale)
H3: User Control & Freedom (undo, cancel, escape states)
H4: Consistency & Standards (buttons, nav, errors, forms nhất quán)
H5: Error Prevention (confirmation, inline validation, hints)
H6: Recognition > Recall (breadcrumb, summaries, context visible)
H7: Flexibility & Efficiency (shortcuts, bulk actions, favorites)
H8: Aesthetic & Minimalist (information density, hierarchy, whitespace)
H9: Error Recovery (specific messages, gợi ý fix, plain language)
H10: Help & Docs (tooltips, onboarding, FAQ, support)
```

### Bước 3: User Task Completion Analysis

```
READ: ux-research-methods.md → Section 4: Usability Test Plan Template

Chọn 5-10 critical tasks quan trọng nhất của hệ thống.
Với mỗi task, phân tích qua "cognitive walkthrough":

Critical tasks thường là:
□ Onboarding / tạo tài khoản
□ Core task 1 (chức năng chính nhất)
□ Core task 2
□ Thanh toán / mua hàng (nếu có)
□ Quản lý account / settings

Với mỗi task, hỏi:
1. User có biết họ cần làm gì ở bước này không?
   (nếu không → visibility problem)
2. User có thấy control/element cần dùng không?
   (nếu không → discoverability problem)
3. User có hiểu control này làm gì không?
   (nếu không → affordance / labeling problem)
4. User có nhận được feedback đúng sau khi thực hiện không?
   (nếu không → feedback problem)

Đánh giá từng task:
- Difficulty: Easy / Medium / Hard / Impossible
- Friction points: Liệt kê cụ thể
- Estimated drop-off risk: Low / Medium / High
```

### Bước 4: Error Frequency Hotspots

```
Phân tích các điểm user hay bị lỗi hoặc nhầm lẫn nhất:

Từ analytics (nếu có):
□ Pages có bounce rate cao bất thường
□ Forms có abandonment rate cao
□ Buttons ít được click dù được expect là CTA chính
□ Error pages xuất hiện nhiều
□ Support tickets về feature nào nhiều nhất

Từ code review / UI inspection:
□ Forms không có validation feedback rõ ràng
□ Loading states thiếu → user click nhiều lần
□ Success/error states không rõ → user không biết thành công chưa
□ Destructive actions không có confirmation
□ Actions không reversible mà không warning

Với mỗi hotspot:
- Mô tả vấn đề cụ thể
- Severity: Critical / High / Medium / Low
- Estimated user impact
- Quick fix recommendation
```

### Bước 5: Consistency Audit Across Screens

```
READ: design-system-patterns.md → Section 4: Component API Design Principles

Kiểm tra tính nhất quán:

Buttons:
□ Primary action button: Có cùng style không? Label pattern nhất quán?
□ Destructive button: Có always dùng màu đỏ / danger variant không?
□ Ghost/Secondary: Có dùng nhất quán cho secondary actions không?

Forms:
□ Input style nhất quán (border, radius, padding)
□ Label position nhất quán (above / left)
□ Error state nhất quán (color, position, icon)
□ Required field indicator nhất quán (*)

Navigation:
□ Active state nhất quán
□ Hover state nhất quán
□ Breadcrumb format nhất quán

Typography:
□ H1, H2, H3 consistent across pages
□ Body text size/color consistent
□ Link style consistent

Colors:
□ Success luôn = green?
□ Error luôn = red?
□ Warning luôn = yellow/orange?
□ Info luôn = blue?

Spacing:
□ Section spacing nhất quán
□ Card padding nhất quán
□ Form field gaps nhất quán
```

### Bước 6: Accessibility Audit — WCAG 2.1 AA

```
READ: accessibility-checklist.md → Toàn bộ document (chi tiết đầy đủ ở đó)

Kiểm tra 4 nguyên tắc: Perceivable (alt text, contrast ≥4.5:1, semantic HTML),
Operable (keyboard, focus, touch targets ≥24px), Understandable (labels, errors),
Robust (ARIA, status messages)

Đếm violations: Critical (sửa ngay) / Major (sprint này) / Minor (backlog)
```

### Bước 7: Mobile & Performance Perception Audit

```
MOBILE: Touch targets ≥44×44px, không hover-dependent, text ≥16px,
không horizontal scroll, đúng keyboard type cho inputs

PERFORMANCE UX: Skeleton loaders, optimistic updates, lazy loading images,
list virtualization/pagination, search debounce, form auto-save, progress indicators
```

### Bước 9: UX Debt Inventory

```
Tổng hợp tất cả issues tìm thấy thành inventory:

Phân loại:
- CRITICAL: Block users, gây data loss, security risk → Fix trước release
- HIGH: Major friction, high drop-off risk → Sprint này
- MEDIUM: Noticeable issues, affect satisfaction → Next 2 sprints
- LOW: Polish, nice-to-have → Backlog
- WONT_FIX: Acknowledged but won't address (ghi lý do)

Với mỗi issue:
□ ID: UX-DEBT-NNN
□ Heuristic vi phạm (H1-H10)
□ Screen / location
□ Mô tả vấn đề
□ Severity
□ Estimated effort: XS / S / M / L / XL
□ Recommendation
```

### Bước 10: Priority Matrix và Output

```
Sắp xếp issues theo Impact × Effort matrix:

HIGH Impact / LOW Effort  → Quick Wins (làm ngay)
HIGH Impact / HIGH Effort → Major Projects (plan sprint)
LOW Impact / LOW Effort   → Fill-ins (làm khi rảnh)
LOW Impact / HIGH Effort  → Avoid / Deprioritize

Output: Viết audit report vào path do skill cung cấp.
Fallback: .mc-data/docs/phase4-ux/ux-audit-report.md
```

---

## Cấu trúc File Output

```markdown
# UX Audit Report: [Project / Feature Name]
> Phase 4, Ngày, Auditor, Scope, Platform

## Executive Summary (UX Health Score + category scores table)
## Critical Issues (UX-DEBT-NNN: Location, Heuristic, Vấn đề, Impact, Recommendation, Effort)
## High/Medium Priority Issues (table format cho medium)
## Accessibility Report (WCAG violations table + summary counts)
## Consistency Audit Summary (inconsistencies found table)
## UX Debt Inventory (full table: ID, Vấn đề, Severity, Effort, Priority)
## Priority Matrix (Quick Wins / Major Projects / Backlog)
## Implementation Roadmap (phases + expected improvement)
## Next Steps (action items với deadline)
```

---

## Checklist trước khi submit

```
□ Scope audit đã được định nghĩa rõ
□ Tất cả 10 heuristics đã được evaluate
□ Task analysis đã làm cho ít nhất 5 critical flows
□ Accessibility checklist WCAG 2.1 AA đã check
□ Mobile usability đã được review
□ Consistency audit đã done
□ UX Debt Inventory đầy đủ với severity và effort
□ Priority matrix rõ ràng (Quick Wins vs Major Projects)
□ Implementation roadmap có timeline
□ File lưu đúng path: phase4-ux/ux-audit-report.md
```
