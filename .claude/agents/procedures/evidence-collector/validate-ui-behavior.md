# Playbook: Validate UI Behavior

> **Type**: Agent Skill Playbook
> **Agent**: evidence-collector
> **Triggered by**: Khi cần validate UI behavior qua screenshots/evidence so với design spec
> **Output**: UI Behavior Validation Report với approval decision

---

## Khi nào dùng playbook này

- Sau khi developer hoàn thành UI implementation của một feature
- Khi QA cần verify implementation có match design spec không
- Khi stakeholder yêu cầu demo trước release với bằng chứng visual
- Khi có tranh cãi về "spec có yêu cầu điều này không"
- Trước khi integration-certifier đưa ra certification decision

---

## Procedure

### Bước 1: Load design spec

```
INPUT: Paths do skill cung cấp qua prompt (design spec, UX files, requirements)
FALLBACK: tra .claude/references/path-registry.md → PHASE4 (UX design), PHASE2 (features)
READ: .claude/references/team-expert/testing/qa-templates.md

Cần đọc:
□ UX spec tại .mc-data/docs/phase4-ux/ — wireframes, mockups, behavior specs
□ Feature specs tại .mc-data/docs/phase2-features/ — functional requirements
□ req-registry.json — danh sách REQ-IDs cần validate
□ Nếu có Figma/design files → đọc export hoặc spec sheet

Trích xuất từ spec (quote nguyên văn):
□ Component states được mô tả (default, hover, active, disabled, error, loading)
□ Layout và spacing expectations
□ Color và typography requirements
□ Responsive behavior per breakpoint
□ Animation/transition descriptions
□ Empty states và edge cases

QUAN TRỌNG: Ghi lại quote nguyên văn spec — khi so sánh sẽ dùng chính những quote này.
Không paraphrase, không interpretation — spec nói gì, ghi đúng vậy.
```

### Bước 2: Capture current implementation

```
Dùng Playwright để capture trạng thái hiện tại của implementation.

Dùng Playwright capture screenshots ở 3 viewports: desktop (1920×1080), tablet (768×1024), mobile (375×667).
Naming: [component]-[state]-[viewport].png

States cần capture theo spec:
□ Default state (page vừa load)
□ Hover states (các elements có hover effect)
□ Error states (validation errors, API errors)
□ Loading states (skeleton, spinner)
□ Empty states (no data)
□ Success states (confirmation)
□ Interactive states (accordion open/close, tab switch, modal)
□ Dark mode nếu spec yêu cầu

Capture file naming: [component]-[state]-[viewport].png
```

### Bước 3: So sánh layout fidelity

```
So sánh từng element trong screenshots vs spec.

Phương pháp so sánh:
□ Nếu có Figma export: overlay hoặc side-by-side
□ Nếu chỉ có written spec: đọc spec → nhìn screenshot → so sánh

Kiểm tra layout fidelity từng element:

TYPOGRAPHY:
□ Font family có khớp không?
□ Font size tương đối có đúng không? (h1 > h2 > body)
□ Font weight: regular vs bold vs semibold
□ Line height và letter spacing (tương đối)
□ Text alignment (left/center/right)
□ Text truncation — có ellipsis đúng chỗ không?

SPACING:
□ Padding bên trong components (đặc biệt buttons, cards, inputs)
□ Gap giữa elements
□ Section margins
□ Không được hardcode so sánh pixel — nhìn proportionality

COLORS:
□ Primary colors đúng không?
□ Background colors đúng không?
□ Border colors đúng không?
□ Text colors đúng không?
□ Error state màu đỏ / Success state màu xanh?

LAYOUT STRUCTURE:
□ Number of columns đúng không?
□ Sidebar có đúng bên (left/right) không?
□ Header, main, footer layout đúng không?
□ Grid/flex alignment đúng không?

ICONS:
□ Icon đúng loại không (trashcan cho delete, pencil cho edit)?
□ Icon size tương đối với text
□ Icon color đúng không?

Với mỗi element so sánh:
→ MATCH: implementation khớp spec
→ GAP: spec có nhưng implementation không có hoặc sai
→ EXTRA: implementation thêm thứ gì đó không có trong spec
```

### Bước 4: Kiểm tra component state coverage

```
Validate TỪNG state đã được implement theo spec.

State checklist theo component type:

Per component type, verify states được implement đúng theo spec:
□ BUTTONS: default, hover, active, disabled, loading, success
□ FORMS: default, focus, filled, error, valid, disabled, read-only
□ CARDS: default, hover, selected, loading skeleton
□ NAVIGATION: default, active, hover, mobile collapse
□ LIST/TABLE: default, hover, selected, empty, loading, sorted
□ MODAL: closed, open (overlay), loading, confirmation

Ghi nhận: state nào implemented đúng, state nào thiếu, state nào sai
```

### Bước 5: Kiểm tra responsive behavior evidence

```
Responsive là thường xuyên bị bỏ qua — capture và validate kỹ.

Desktop (1920×1080):
□ Layout đầy đủ: sidebar, multi-column, full navigation
□ Tables hiển thị đủ columns
□ Images đúng kích thước
□ Typography đọc được

Tablet (768×1024):
□ Layout có điều chỉnh không? (2 columns → 1 column? sidebar ẩn?)
□ Navigation có collapse không?
□ Touch targets đủ lớn (tối thiểu 44×44px — bắt buộc theo WCAG 2.5.8)
□ Không có horizontal scroll (trừ khi intentional như table)

Mobile (375×667):
□ Single column layout
□ Navigation collapse thành hamburger (hoặc bottom bar)
□ Font size readable (tối thiểu 16px body text để tránh iOS zoom)
□ Buttons đủ to để tap
□ Images không bị distort (object-fit: cover/contain đúng)
□ Không có text overflow ra ngoài container
□ Fixed elements không che khuất content

Breakpoint transitions (nếu có):
□ Resize browser từ mobile → tablet → desktop
□ Layout có snap đúng tại breakpoints không?
□ Content không bị "flash" hoặc nhảy khi resize

Ghi nhận per viewport: PASS / FAIL kèm screenshot evidence
```

### Bước 6: Capture animation evidence (video)

```
Dùng Playwright recordVideo để capture animations (transitions, modals, dropdowns, loading states).
Format: .webm, 3-10 giây, naming: [component]-[animation-name].webm
Nếu không có animation spec → skip bước này
```

### Bước 7: Annotate discrepancies

```
Với mỗi GAP tìm thấy (Bước 3, 4, 5): annotate rõ ràng.

Format annotation:

GAP-[NNN]: [Mô tả ngắn]
- Component: [tên component, page]
- Spec (quote nguyên văn): "[trích dẫn từ UX spec hoặc feature spec]"
- Screenshot thực tế: [link đến screenshot file]
- Observation: [mô tả CHÍNH XÁC những gì nhìn thấy trong screenshot]
  → Không interpretation, không "có vẻ như", không "tôi nghĩ là"
  → "Trong screenshot desktop-login-default.png, button có background #333 thay vì màu primary xanh như spec yêu cầu"
- REQ-ID: [REQ-ID liên quan nếu có]

Phân biệt rõ:
□ GAP có ảnh hưởng đến functionality (Critical/High)
□ GAP chỉ về visual aesthetics (Medium/Low)
□ EXTRA feature không có trong spec (ghi nhận, không nhất thiết là lỗi)

KHÔNG được:
□ Thêm yêu cầu không có trong spec
□ So sánh với "tiêu chuẩn ngành" nếu spec không đề cập
□ Judgment call về design taste — chỉ so sánh với spec gốc
```

### Bước 8: Đánh giá severity per issue

```
Severity rating dựa trên impact với user và business:

CRITICAL (block release):
□ Feature không hoạt động: button không submit form, link không navigate
□ Data loss risk: form submit mất data
□ Security concern: login page render sai, sensitive data exposed
□ Core user journey broken

HIGH (fix trước release):
□ Major visual discrepancy trên critical components (error state missing)
□ Responsive layout broken trên một viewport (mobile unreadable)
□ Wrong state implementation (error styling dùng cho success)
□ Missing required states (loading state không có → user không biết đang xử lý)

MEDIUM (fix trong sprint):
□ Minor visual gap từ spec (spacing sai 4–8px)
□ Hover effect missing trên non-critical elements
□ Secondary viewport (tablet) có nhỏ issues
□ Animation không khớp spec nhưng còn acceptable

LOW (backlog):
□ Pixel-perfect differences không ảnh hưởng UX
□ Font rendering khác nhau giữa OS
□ Anti-aliasing differences
□ Color differences nhỏ (< 10% luminance)

Mỗi finding: gán severity + justification
```

### Bước 9: Approval decision

```
Dựa trên tất cả findings, đưa ra decision:

APPROVED:
- Không có Critical hoặc High findings
- Mọi core states đã implement đúng theo spec
- 3 viewports hoạt động đúng
- REQ-IDs trong scope đã validated

APPROVED WITH CONDITIONS:
- Không có Critical findings
- Có High findings NHƯNG có plan fix rõ ràng trước release
- Conditions phải được ghi rõ: "Approved nếu GAP-003 và GAP-007 được fix trước merge"

REJECTED:
- Có một hoặc nhiều Critical findings
- Core user journey không hoạt động đúng
- Số lượng High findings quá lớn (> 3 High)
- Bằng chứng visual không đủ để đánh giá (screenshot thiếu)

Grading thực tế (không fantasy A+):
A: APPROVED, < 2 Low findings
B+: APPROVED WITH CONDITIONS, 1-3 High cần fix
B: APPROVED WITH CONDITIONS, 4-6 Medium cần fix
B-: APPROVED WITH CONDITIONS, nhiều Medium
C+: REJECTED, 1-2 Critical hoặc nhiều High
C: REJECTED, multiple Critical
F: REJECTED, core functionality broken

Quy tắc: REJECTED là default — chỉ APPROVED khi evidence áp đảo chứng minh
```

### Bước 10: Tổng hợp UI Behavior Validation Report

```
Cấu trúc: Overview (feature, date, REQ-IDs, screenshot count) → Executive Summary
(findings count, decision, grade) → Component State Coverage (table) →
Responsive Results (table per viewport) → Findings List (GAP-NNN) →
Animations (nếu có) → Approval Decision + Conditions → Evidence Index
```

---

## Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/work/wf-implement-feature/evidence/[feature]/validation-report.md

Cấu trúc output:
1. UI Behavior Validation Report (đầy đủ theo template Bước 10)
2. Screenshots tổ chức theo folder structure
3. Videos cho animated interactions (nếu có)
4. Approval decision rõ ràng: APPROVED / APPROVED WITH CONDITIONS / REJECTED kèm grade
```

---

## Checklist trước khi submit

```
□ Design spec đã đọc và quote nguyên văn các requirements
□ REQ-IDs trong scope đã identify
□ Implementation đã capture trên 3 viewports
□ Tất cả states trong spec đã captured: default, hover, error, loading, empty, success
□ Mỗi GAP có quote spec gốc + screenshot evidence + observation chính xác
□ Không thêm yêu cầu ngoài spec gốc
□ Animations đã capture video nếu spec mô tả
□ Mỗi finding có severity rating kèm justification
□ Approval decision dựa trên evidence, không phải cảm tính
□ Grading thực tế (không inflate lên A khi còn issues)
□ Conditions cho APPROVED WITH CONDITIONS đã ghi rõ ràng
□ Evidence index đầy đủ — mọi file screenshot được liệt kê
```
