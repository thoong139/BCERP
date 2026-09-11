# QD7 Test Fixture — Browser/API/Device Compatibility

> **Status:** ✅ Phase 3 DONE (Phiên 37 — 2026-05-08) — P=R=F1=1.00 (live-testable subset)
> **Lane skill:** `wf-fix-compat` v2.0.0-alpha.s4
> **Số probes (audit spec):** 5 — chỉ 1 live-testable bash (`wf-fix-probe-static-deprecated.sh`)
> **Owner agent:** `frontend-developer`
> **Audit report:** [08-qd7-compat-audit.md](../../08-qd7-compat-audit.md)
> **Accuracy report:** [accuracy-report.md](./accuracy-report.md)

## Mục đích

Đo precision/recall của bash probe `wf-fix-probe-static-deprecated.sh` (P-QD7-deprecated-api-usage — 3 detection categories: deprecated_api / deprecated_css / deprecated_pkg). 4 probes còn lại trong audit spec yêu cầu runtime runtime hoặc bị broken (D15) → SPEC_GAP, document ở accuracy-report §5.

## Expected signals (live-testable: 1 probe, 3 categories)

| Signal | Issue type | Severity | Positive case | Negative case | Notes |
|---|---|:-:|---|---|---|
| deprecated_api #1 | `document.execCommand('copy')` | HIGH | pos-01-deprecated-execcommand.tsx | neg-01-modern-clipboard.ts | Regex Step 1 |
| deprecated_api #2 | `componentWillMount` React lifecycle | HIGH | pos-02-componentwillmount.tsx | neg-02-modern-hooks.tsx | Regex Step 1 |
| deprecated_css | `zoom: 1.5` CSS property | LOW | pos-03-zoom-css.css | neg-03-transform-css.css | CSS Step 1 |
| deprecated_api #3 | `new Buffer()` Node.js CRITICAL | CRITICAL | pos-04-new-buffer.ts | neg-04-buffer-alloc.ts | Regex Step 1 |
| deprecated_pkg | `moment` in package.json | MEDIUM | positive/package.json | negative/package.json | Package Step 2 |

> **Fingerprint (D17):** probe emits 6-token `QD7|file|line|probe_id|type|label` (vs 5-token spec) — still `sha256:<64-hex>` format.
> **CDG (D10):** `deprecated_pkg` signals include `cdg_flags: ["CDG-DEPS-DOWN"]` — no handler in wf-fix-common.sh (same pattern as QD4 D4).

## Cases

### Positive (4 code files + 1 package.json, 5 expected signals)

- `pos-01-deprecated-execcommand.tsx` — `document.execCommand('copy')` (HIGH deprecated_api)
- `pos-02-componentwillmount.tsx` — `componentWillMount()` React class lifecycle (HIGH deprecated_api)
- `pos-03-zoom-css.css` — `zoom: 1.5` (LOW deprecated_css)
- `pos-04-new-buffer.ts` — `new Buffer(data)` (CRITICAL deprecated_api — security risk)
- `package.json` — `"moment": "^2.29.4"` (MEDIUM deprecated_pkg + CDG-DEPS-DOWN)

### Negative (4 code files + 1 package.json, 0 expected signals)

- `neg-01-modern-clipboard.ts` — `navigator.clipboard.writeText` (no execCommand → 0 signals)
- `neg-02-modern-hooks.tsx` — `useEffect` hook (no componentWillMount → 0 signals)
- `neg-03-transform-css.css` — `transform: scale()` (no zoom: → 0 signals)
- `neg-04-buffer-alloc.ts` — `Buffer.alloc()` + `Buffer.from()` (no new Buffer( → 0 signals)
- `package.json` — `date-fns`, `axios` (not in deprecated list → 0 signals)

### Advanced (optional)

Skipped — runtime probe checks (browser-compat/api-version/polyfill/device-breakpoint) tracked as SPEC_GAP cho Phase 4 DAG analysis.

## Run

```bash
cd plans/wf-fix-bugs-dimensions-audit-v1/fixtures/qd7-test
bash run.sh                # full positive + negative scan
bash run.sh --dry-run      # preflight only
```

Outputs:
- `.actual-signals-positive.json` — live signals từ positive scan
- `.actual-signals-negative.json` — live signals từ negative scan (expect 0)

## SPEC_GAP Probes (4/5 — không live-testable)

| Probe ID | Reason |
|---|---|
| `P-QD7-browser-compat-check` | No Playwright launch in probe spec — static grep only (D1) |
| `P-QD7-api-version-compat` | No HTTP runtime check in spec — static grep only (D1) |
| `P-QD7-polyfill-coverage` | Browserslist analysis runtime-only — no bash wrapper |
| `P-QD7-device-breakpoint-test` | **D15 CRITICAL heredoc PWEOF bug** — probe fundamentally broken (cannot run as-spec'd) |

## Caveats

- `EXCLUDE_PATTERN = '(node_modules|\.git/|dist/|build/|\.next/|coverage/)'` — no `.test.` exclusion (unlike QD5). Test files with deprecated APIs will be flagged (D14: FP-09 flooding risk).
- Package probe checks `package.json` via `--package-json` flag — must pass explicitly to each scan (positive/negative use separate package.json files).
- `new Buffer()` may appear in `.js/.ts` files in node_modules → EXCLUDE_PATTERN guards against this.

## Liên quan

- Audit report: [08-qd7-compat-audit.md](../../08-qd7-compat-audit.md)
- Lane skill: `.claude/skills/workflow/wf-fix-compat/`
- Fixture catalog: [fixtures/README.md](../README.md)
- DoD per fixture: [13-definition-of-done.md §Phase 3](../../13-definition-of-done.md)
