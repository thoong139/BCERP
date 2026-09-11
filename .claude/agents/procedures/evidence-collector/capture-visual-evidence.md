# Playbook: Capture Visual Evidence

> **Type**: Agent Skill Playbook
> **Agent**: evidence-collector
> **Triggered by**: Khi cần thu thập visual evidence cho QA approval hoặc bug report
> **Output**: Visual Evidence Report với screenshots đầy đủ per page, per viewport, per state

---

## Khi nào dùng playbook này

- Trước khi submit QA approval cho một feature
- Khi tạo bug report cần visual proof
- Sau khi implement UI component — capture trạng thái hiện tại
- Để tạo visual regression baseline (before state)
- Khi `/wf-implement-feature` hoàn thành một page hoặc component có UI
- Khi stakeholder yêu cầu visual verification

---

## Procedure

### Bước 1: Xác định evidence scope

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE4 (UX spec), PHASE2 (features)
READ: .claude/references/team-expert/testing/qa-templates.md (evidence section)

Cần xác định:
□ Danh sách pages/views cần capture
□ Danh sách flows cần document (login flow, checkout flow, v.v.)
□ Components cần capture tất cả states
□ REQ-ID liên quan — đọc req-registry.json
□ Application URL và environment (localhost, staging, production)
□ Authentication cần thiết để access pages (credentials nếu có)

Ưu tiên capture:
1. Critical paths (checkout, authentication, core feature)
2. Pages với thay đổi từ last release
3. Components có nhiều states (form, button, error states)
4. Responsive layouts (3 viewports bắt buộc)

Ghi scope rõ ràng: [N pages] × [3 viewports] × [M states] = ước tính số screenshots
```

### Bước 2: Setup Playwright

```
Playwright là công cụ chính — ưu tiên automated capture để:
- Consistent viewport sizes
- Reproducible capture
- Không phụ thuộc vào manual drag/crop

Kiểm tra Playwright setup:
□ Node.js + Playwright đã cài chưa: npx playwright --version
□ Nếu chưa: npm init playwright@latest

Cấu trúc thư mục evidence:
mkdir -p evidence/screenshots/{desktop,tablet,mobile}
mkdir -p evidence/video
mkdir -p evidence/diffs

Tạo file Playwright config:
// playwright.config.js
const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({
  use: {
    screenshot: 'on',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'desktop', use: { viewport: { width: 1920, height: 1080 } } },
    { name: 'tablet', use: { viewport: { width: 768, height: 1024 } } },
    { name: 'mobile', use: { viewport: { width: 375, height: 667 } } },
  ],
});

Viewport chuẩn 3 kích thước:
- Desktop: 1920×1080 (Full HD — baseline)
- Tablet: 768×1024 (iPad portrait)
- Mobile: 375×667 (iPhone SE — smallest common)
```

### Bước 3: Xây dựng screenshot capture script

```
Viết Playwright script có cấu trúc rõ ràng:

// evidence-capture.spec.js
const { test, expect } = require('@playwright/test');

// Đặt tên file: [page]-[state]-[viewport].png
// Ví dụ: login-default-desktop.png, login-error-mobile.png

test.describe('Evidence: [Feature/Page Name]', () => {

  test.beforeEach(async ({ page }) => {
    // Setup: login nếu cần, reset state
    await page.goto(process.env.BASE_URL || 'http://localhost:3000');
    // await loginAsUser(page); // nếu cần authentication
  });

  test('capture default state', async ({ page }) => {
    await page.goto('/target-page');
    await page.waitForLoadState('networkidle'); // chờ content load xong
    await expect(page).toHaveScreenshot('page-default.png', {
      fullPage: true, // capture entire page, not just viewport
      animations: 'disabled', // dừng animations để screenshot ổn định
    });
  });

  // Capture từng state
  test('capture hover state - button', async ({ page }) => {
    await page.hover('button.submit-btn');
    await page.waitForTimeout(200); // chờ transition
    await expect(page).toHaveScreenshot('button-hover.png');
  });

});

Naming convention bắt buộc:
[page]-[component]-[state]-[viewport].png
Ví dụ:
- checkout-form-default-desktop.png
- checkout-form-error-mobile.png
- product-card-hover-tablet.png
- modal-open-desktop.png
```

### Bước 4: Capture từng state cần thiết

```
Với mỗi page và component trong scope, capture đủ các states:

DEFAULT STATE:
□ Trang vừa load, không có user interaction
□ Full page screenshot (fullPage: true)
□ Trên cả 3 viewports

HOVER STATE (nếu có hover effects):
□ hover từng interactive element quan trọng
□ Button primary, button secondary
□ Link hover
□ Card hover (nếu có animation/shadow)

ERROR STATE:
□ Form submit thiếu required fields → validation errors xuất hiện
□ API error → error message display
□ Network offline → offline indicator
□ Input invalid → inline error message

LOADING STATE:
□ Skeleton loading (nếu có)
□ Spinner/loading indicator
□ Disabled state của buttons khi đang submit

EMPTY STATE:
□ Danh sách không có dữ liệu (empty list)
□ Search không có kết quả
□ Dashboard trước khi có data

SUCCESS STATE:
□ Form submit thành công → success message
□ Thao tác hoàn thành → confirmation UI

INTERACTIVE STATES (cho components phức tạp):
□ Accordion: collapsed (default) + expanded
□ Tab panel: tab 1 active, tab 2 active
□ Modal: closed (context) + open
□ Dropdown: closed + open
□ Tooltip: hover trigger + tooltip visible
□ Pagination: page 1, page 2, last page

SCROLL STATES (nếu cần):
□ Header behavior khi scroll (sticky, hide/show)
□ Infinite scroll: before load + after load
□ Back-to-top button (hidden at top, visible when scrolled)

Với mỗi state: capture trên tối thiểu desktop + mobile
```

### Bước 5: Visual regression baseline

```
Baseline = set screenshots "chuẩn" để so sánh sau này.

Khi nào tạo baseline:
□ First time capture (không có baseline cũ)
□ Sau khi intentional UI changes được approve

Playwright baseline update:
npx playwright test --update-snapshots

Lưu baseline vào version control:
□ Tạo thư mục: evidence/baseline/[date-of-release]/
□ Copy current screenshots vào đó
□ Commit vào git với message: "evidence: baseline for [feature] v[version]"

Baseline file structure:
evidence/
  baseline/
    2026-03-19/           ← date của release
      login-default-desktop.png
      login-error-mobile.png
      ...
  current/               ← screenshots lần chạy hiện tại
    login-default-desktop.png
    ...
  diffs/                 ← generated diffs (nếu có)
    login-default-desktop-diff.png
    ...
```

### Bước 6: Diff generation

```
So sánh screenshots hiện tại với baseline để phát hiện visual regressions.

Playwright built-in diff:
npx playwright test --reporter=html
# Mở: playwright-report/index.html → xem diff trực quan

Manual diff với pixelmatch (nếu cần):
npm install pixelmatch pngjs
// compare.js
const { PNG } = require('pngjs');
const pixelmatch = require('pixelmatch');
const fs = require('fs');

function compareScreenshots(baselinePath, currentPath, diffPath) {
  const baseline = PNG.sync.read(fs.readFileSync(baselinePath));
  const current = PNG.sync.read(fs.readFileSync(currentPath));
  const { width, height } = baseline;
  const diff = new PNG({ width, height });

  const numDiffPixels = pixelmatch(
    baseline.data, current.data, diff.data,
    width, height, { threshold: 0.1 }
  );

  fs.writeFileSync(diffPath, PNG.sync.write(diff));
  return { numDiffPixels, percentDiff: (numDiffPixels / (width * height)) * 100 };
}

Ngưỡng chấp nhận:
- 0% diff: perfect match
- < 1% diff: acceptable (anti-aliasing, font rendering differences)
- 1–5% diff: review manually — có thể intentional change
- > 5% diff: flag as regression — cần xác nhận với developer

Ghi nhận: tên file, % diff, verdict (ok/review/regression)
```

### Bước 7: Tổ chức evidence folder structure

```
Tổ chức rõ ràng giúp QA và stakeholder review dễ dàng.

Cấu trúc chuẩn:
evidence/
  [feature-name]/
    [date]/
      desktop/
        [page]-[state].png
        ...
      tablet/
        [page]-[state].png
        ...
      mobile/
        [page]-[state].png
        ...
      diffs/                 ← nếu có so sánh với baseline
        [page]-[state]-diff.png
        ...
      videos/                ← cho interactive flows
        [flow-name].webm
        ...
      report.md              ← evidence report file

Naming convention file:
□ Chỉ dùng chữ thường, số, và dấu gạch ngang
□ Không dùng space, ký tự đặc biệt
□ Format: [page]-[component?]-[state]-[viewport?].png
□ Ví dụ:
   - homepage-hero-default.png (không cần viewport nếu không test responsive)
   - checkout-form-validation-error-desktop.png
   - product-card-hover-mobile.png

Index file (README.md trong evidence folder):
□ Liệt kê tất cả screenshots và mô tả ngắn
□ Highlight screenshots quan trọng nhất
□ Link đến report.md
```

### Bước 8: Tổng hợp Evidence Report

```
Cấu trúc report:

1. EVIDENCE OVERVIEW
   - Feature/Sprint: [tên]
   - Date captured: [date]
   - Environment: [localhost/staging/production] + URL
   - Playwright version, browser
   - Total screenshots: [N]
   - REQ-IDs covered: [list]

2. CAPTURE SCOPE
   | Page | States Captured | Viewports | Screenshots Count |
   |------|----------------|-----------|-------------------|
   | Login | default, error, success | D/T/M | 9 |
   ...

3. SCREENSHOTS INDEX
   Nhóm theo page/feature:
   [Page/Feature Name]
   - [state] — Desktop: ![thumbnail](path) | Tablet: ![thumbnail](path) | Mobile: ![thumbnail](path)
   - Notes: ghi chú nếu có gì đặc biệt

4. VISUAL REGRESSION RESULTS (nếu có baseline)
   | File | % Diff | Verdict |
   |------|--------|---------|
   | login-default-desktop.png | 0% | OK |
   | checkout-form-desktop.png | 12% | REGRESSION |

5. FINDINGS (issues phát hiện từ screenshots)
   Mỗi finding:
   - ID: VIS-[NNN]
   - Severity: Critical / Medium / Low
   - Screenshot: [link]
   - Description: mô tả CHÍNH XÁC những gì nhìn thấy
   - REQ-ID liên quan (nếu có)

6. OVERALL VERDICT
   EVIDENCE COMPLETE / INCOMPLETE (thiếu states) / REGRESSION FOUND
```

---

## Output

```
Ghi vào path do skill cung cấp.
Fallback:
  Screenshots: .mc-data/work/wf-implement-feature/evidence/[feature]/
  Report: .mc-data/work/wf-implement-feature/evidence/[feature]/report.md

Cấu trúc output:
1. Screenshots organized theo folder structure (Bước 7)
2. Visual Evidence Report (report.md theo template Bước 8)
3. Diff images nếu có baseline so sánh
```

---

## Checklist trước khi submit

```
□ Scope đã define rõ (pages, flows, components)
□ Playwright setup hoạt động và có thể chạy script
□ Tất cả pages đã capture full page screenshot
□ Tất cả states đã capture: default, hover, error, loading, empty, success
□ 3 viewports: desktop (1920x1080), tablet (768x1024), mobile (375x667)
□ Animations đã disable trong capture (--animations=disabled)
□ Baseline đã tạo hoặc diff đã chạy so với baseline cũ
□ Folder structure rõ ràng và naming convention nhất quán
□ Evidence report có đủ sections
□ REQ-ID coverage đã verify
□ Mọi finding trong report có screenshot evidence tương ứng
□ Verdict rõ ràng: EVIDENCE COMPLETE / INCOMPLETE / REGRESSION FOUND
```
