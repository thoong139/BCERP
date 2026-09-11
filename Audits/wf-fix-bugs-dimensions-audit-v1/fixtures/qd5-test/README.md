# QD5 Test Fixture — UX Consistency + Accessibility

> **Status:** ✅ Phase 3 DONE (Phiên 32 — 2026-05-08) — P=R=F1=1.00
> **Lane skill:** `wf-fix-ux-a11y` v2.0.0-alpha.s4
> **Số probes (audit spec):** 7 — chỉ 1 live-testable bash (`wf-fix-probe-static-a11y.sh`)
> **Owner agent:** `ux-researcher` + `accessibility-auditor`
> **Audit report:** [06-qd5-ux-a11y-audit.md](../../06-qd5-ux-a11y-audit.md)
> **Accuracy report:** [accuracy-report.md](./accuracy-report.md)

## Mục đích

Đo precision/recall của bash probe `wf-fix-probe-static-a11y.sh` (5 static checks WCAG 2.2 AA). 6 probes còn lại trong audit spec yêu cầu axe-core/Playwright runtime → SPEC_GAP, document ở accuracy-report §5.

## Expected signals (live-testable: 1 probe, 5 checks)

| Check | Issue type | Severity | Positive case | Negative case | WCAG ref |
|---|---|:-:|---|---|:-:|
| Check 1 | `img_no_alt` | HIGH | pos-01-img-no-alt.tsx | neg-01-img-decorative.tsx (alt=""), neg-02 (aria-hidden) | 1.1.1 |
| Check 2 | `input_no_label` | HIGH | pos-02-input-no-label.tsx | neg-03-input-with-label.tsx (aria-label) | 1.3.1 |
| Check 3 | `tabindex_positive` | MEDIUM | pos-03-positive-tabindex.html | (none — anti-pattern detection only) | 2.4.3 |
| Check 4 | `invalid_role` | MEDIUM | pos-04-invalid-role.tsx | neg-05-valid-role.tsx (toolbar/button/dialog) | WAI-ARIA |
| Check 5 | `href_anti_pattern` | LOW | pos-05-href-anti-pattern.tsx | (none — anti-pattern detection only) | 2.1.1 |
| Path filter | (any) | — | — | neg-04-test-file.test.tsx (EXCLUDE_PATTERN bypasses 5 violations) | — |

> Probe ID emitted: `P-QD5-static-a11y-check`. Audit spec dùng tên riêng cho từng check; mapping ở `06-qd5-ux-a11y-audit.md` Spec↔Impl Tables A-G.

## Cases

### Positive (5, mỗi case 1 issue type)

- `pos-01-img-no-alt.tsx` — `<img src="/logo.png" />` (no alt)
- `pos-02-input-no-label.tsx` — `<input type="text" name="email" />` (no aria-label, type=text)
- `pos-03-positive-tabindex.html` — `<button tabindex="2">Submit</button>`
- `pos-04-invalid-role.tsx` — `<div role="buttonn">Click me</div>`
- `pos-05-href-anti-pattern.tsx` — `<a href="#">Read more</a>`

### Negative (5, demonstrates probe filters)

- `neg-01-img-decorative.tsx` — `alt=""` (Check 1 alt= filter)
- `neg-02-img-aria-hidden.tsx` — `aria-hidden="true"` (Check 1 aria-hidden filter)
- `neg-03-input-with-label.tsx` — `aria-label="Email address"` (Check 2 aria-label filter)
- `neg-04-test-file.test.tsx` — bad markup (5 violations) BUT path matches `\.test\.` (EXCLUDE_PATTERN bypass)
- `neg-05-valid-role.tsx` — `role="toolbar"`, `role="button"`, `role="dialog"` (Check 4 VALID_ROLES whitelist)

### Advanced (optional)

Skipped — runtime checks (color-contrast/focus-trap/keyboard-nav/modal-mgmt/screen-reader/dynamic-ARIA) tracked as SPEC_GAP cho Phase 4 DAG analysis.

## Run

```bash
cd plans/wf-fix-bugs-dimensions-audit-v1/fixtures/qd5-test
bash run.sh                # full positive + negative scan
bash run.sh --dry-run      # preflight only
```

Outputs:
- `.actual-signals-positive.json` — live signals từ positive scan
- `.actual-signals-negative.json` — live signals từ negative scan (expect 0)

## Caveats

- Probe `EXCLUDE_PATTERN` chứa `fixtures` → bắt buộc `cd "$FIXTURE_DIR"` trước khi gọi probe để grep paths không có `fixtures/` prefix.
- Display Precision/Recall dạng `0.100` trong run.sh là cosmetic (integer division) — thực tế 1.00.
- Coverage: 1/7 probes audit spec đo được tĩnh; 6 probes runtime-only document ở accuracy-report §5.

## Liên quan

- Audit report: [06-qd5-ux-a11y-audit.md](../../06-qd5-ux-a11y-audit.md)
- Lane skill: `.claude/skills/workflow/wf-fix-ux-a11y/`
- Fixture catalog: [fixtures/README.md](../README.md)
- DoD per fixture: [13-definition-of-done.md §Phase 3](../../13-definition-of-done.md)
