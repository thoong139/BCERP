# Procedure: Audit Browser Runtime Health

> **Owner agent:** `qa-lead`
> **Use case:** Khi `qa-lead` được spawn từ `/wf-fix-bugs` lane QD9 (Runtime Health) cho
> Playwright-based probes, hoặc khi cần verify SPA runtime quality trước go-live.

## Khi nào dùng

- QD9 lane probes: feature-checklist-smoke, interactive-smoke, spa-route-coverage,
  form-validation-smoke, console-network-monitor, auth-aware-smoke
- Pre-deployment: smoke test toàn bộ critical user flows
- Post-fix: verify fix không introduce regression ở browser runtime

## Đầu vào

- `$SESSION_DIR/scope.json` — modules / pages trong scope
- `req-registry.json` — feature specs với route mapping
- App URL (từ `$URL_VAL` của fix-status.flags.url) hoặc app server local
- Credentials (nếu cần login flow): từ `$SESSION_DIR/.credentials.txt` (HIGH-8 fix)

## Đầu ra

JSON array signals theo CORE-029, với `signal_type` runtime-specific:
- `runtime_console_error` — console.error / uncaught exception detected
- `runtime_uncaught_exception` — `window.onerror` triggered
- `runtime_network_failure` — fetch/XHR fail (status >= 500 hoặc timeout)
- `runtime_navigation_broken` — route load fail / 404
- `runtime_form_validation_skip` — form submit không validate
- `runtime_a11y_blocker` — keyboard nav broken / focus trap broken

## Quy trình audit

### Bước 1 — Setup Playwright session

1. Read `--url` từ fix-status.json
2. Load credentials từ `$SESSION_DIR/.credentials.txt` (nếu cần auth)
3. Launch headless browser với:
   - `permissions: ['notifications']` (skip dialog block)
   - `userAgent` standard (không đè custom)
   - Viewport: 1280x720 (default), responsive override nếu `--responsive`

### Bước 2 — Probe execution

#### Feature Checklist Smoke (P-QD9-feature-checklist-smoke)
- Parse `req-registry.json.features[].ui_specs[].route`
- Cho mỗi route → navigate → expect title/heading element xuất hiện
- Fail nếu: 404, blank page, console error trong load

#### Interactive Smoke (P-QD9-interactive-smoke)
- Reuse logic từ QD1 deep-ui-traversal A2
- Click buttons / submit forms / open dropdowns
- Verify: no uncaught exception, network requests succeed

#### SPA Route Coverage (P-QD9-spa-route-coverage)
- Use Serena `find_symbol` Routes config (React Router, Vue Router)
- Navigate qua mỗi route → verify render
- Fail nếu route defined nhưng không reachable, hoặc reachable nhưng render error

#### Form Validation Smoke (P-QD9-form-validation-smoke)
- Reuse QD1 form discovery + Serena validator analysis
- Submit form với invalid data → expect validation message
- Submit form với valid data → expect success
- Fail nếu: validation skip, server-side validation reject mà UI không show error

#### Console + Network Monitor
- Listen `page.on('console')` cho mọi `console.error`
- Listen `page.on('pageerror')` cho uncaught exception
- Listen `page.on('requestfailed')` cho network failure
- Group failures by route → emit signal per route

#### Auth-aware Smoke (P-QD9-auth-aware-smoke)
- Login với credential từ `.credentials.txt`
- Verify: session cookie set, protected routes accessible
- Logout → verify: session cleared, protected routes redirect to login
- Fail nếu: login form không submit, post-login redirect loop, logout không clear session

### Bước 3 — Severity assignment

| Tình huống | Severity |
|---|---|
| Uncaught exception trên payment/checkout flow | CRITICAL |
| Console.error spam trên homepage | HIGH |
| Network 5xx trên feature critical | HIGH |
| 404 trên route documented trong feature specs | HIGH |
| Form skip validation, submit invalid data thành công | CRITICAL |
| Auth flow broken (login/logout không hoạt động) | CRITICAL |
| Keyboard nav broken (Tab không navigate) | HIGH |
| Console warning (deprecation, etc.) | LOW |

### Bước 4 — Multi-app coordination

Trong monorepo có multi web apps (`erp-web`, `smarttax-web`, ...):
- Tuân thủ `wf-fix-multi-app-coordinator.sh` — chạy tuần tự per-app, max 1 browser
- Browser lock convention: `$SESSION_DIR/.browser.lock/`

## CDG flag

Findings trên payment / auth flow:
- `cdg_flags: ["CDG-RUNTIME-RISK"]` để orchestrator escalate trước khi mark fixed.

## Anti-patterns to ignore

- KHÔNG flag console.warn từ third-party libs (vendor warning ngoài control)
- KHÔNG flag network failure trên routes intentionally protected (401 expected pre-login)
- KHÔNG flag missing route nếu route được gate sau feature flag và flag OFF trong session

## Output validation (CORE-029)

- `evidence` PHẢI bao gồm: route URL + console output snippet hoặc network response
- `severity` enum chỉ critical/high/medium/low
- `affected_pages` array (≥ 1 URL) thay vì single file_path
- Kèm screenshot path nếu evidence-collector dispatch (`$SESSION_DIR/evidence/screenshots/`)
