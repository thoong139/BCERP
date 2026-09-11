# 02 — 11 Quality Dimensions (Canonical v2.0)

> **Đọc trước:** [01-vision-principles.md](01-vision-principles.md)
> **Đọc tiếp:** [03-architecture.md](03-architecture.md)
> **Trạng thái:** v2.0 · Phản ánh skill `wf-fix-bugs v10.18.0` (2026-05-16) · 11 dimensions (mở rộng từ 7 dim v1.0)
> **Tiền thân:** [99-archive/wf-fix-bugs-design-v1.0/02-quality-dimensions.md](../../99-archive/wf-fix-bugs-design-v1.0/02-quality-dimensions.md) (7 dim QD1-QD7)

---

## Bối Cảnh — Vì Sao 11 Dimensions

v6.0 (2026-04-21) khởi đầu với **7 dimensions QD1-QD7**. Trong các đợt overhaul sau, 4 dimensions mới được thêm để vá những blindspot lớn:

| Dimension mới | Phiên bản skill | Lý do |
|---------------|-----------------|-------|
| **QD8 Observability & Reliability** | v8.2.0 (2026-05-09) | Production incident: payment service không có retry + timeout → flaky failures trong giờ cao điểm. QD3 không cover. |
| **QD9 Runtime Health** (Playwright) | v9.0.x (2026-05-10) | Bug chỉ xuất hiện qua browser runtime (uncaught exceptions, broken CTAs, network failures) — static analysis không thấy. |
| **QD10 Cross-Module Integration** | v9.0.x (2026-05-10) | Bug do orphan FK, API contract drift, cross-module reference broken — single-module probe không thấy. |
| **QD11 Business Completeness** | v9.1.0 (2026-05-10) | Missing business logic phát hiện qua 3-pass LLM analysis (cross-module pattern, domain heuristic, registry gap). |

Mỗi QD vẫn giữ nguyên 8 trường mô tả (Scope / DoD / Probes / Exit Criteria / Severity / Evidence / External Tools / Agents).

---

## Bảng Tổng Hợp 11 Dimensions

| # | Slug | Lane Skill | Owner Team | Default Profile | Playwright |
|---|------|------------|------------|------------------|-------------|
| QD1 | functional | `wf-fix-functional` | qa-lead + developer | quick, standard, deep, exhaustive | Optional |
| QD2 | business | `wf-fix-business` | business-analyst + domain expert | standard, deep, exhaustive | — |
| QD3 | security | `wf-fix-security` | security + developer | deep, exhaustive | — |
| QD4 | performance | `wf-fix-performance` | performance-benchmarker + sre | deep, exhaustive | Optional (Lighthouse) |
| QD5 | ux-a11y | `wf-fix-ux-a11y` | accessibility-auditor + ux-designer | quick, standard, deep, exhaustive | **Required** |
| QD6 | data | `wf-fix-data` | dba + data-engineer | deep, exhaustive | — |
| QD7 | compat | `wf-fix-compat` | frontend-developer + qa-lead | deep, exhaustive | **Required** (responsive) |
| QD8 | observability | `wf-fix-observability` | sre + devops | deep, exhaustive | — |
| QD9 | runtime-health | `wf-fix-runtime-health` | qa-lead + frontend-developer | deep, exhaustive | **Required** (3 modes) |
| QD10 | integration | `wf-fix-integration` | architect + data-engineer | deep, exhaustive | — |
| QD11 | business-completeness | `wf-fix-business-completeness` | business-analyst + domain expert + architect | deep, exhaustive | — |

**Skip rules:**
- QD9 SKIP nếu `--no-browser` hoặc `interface_type=api-only`
- QD10 SKIP nếu không có `cross_module_dependencies[]` hoặc `profile=quick`
- QD11 SKIP nếu single module, api-only, hoặc `profile=quick`
- QD3/QD8 KHÔNG dùng scan cache (security-sensitive, no false-pass acceptable)

---

## Map 11 QD × 12 Bug Categories Cũ + Bug Types Mới

Bảng kế thừa mapping v1.0 và mở rộng cho 4 QD mới:

| Category (cũ) | QD1 | QD2 | QD3 | QD4 | QD5 | QD6 | QD7 | QD8 | QD9 | QD10 | QD11 |
|---------------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| C01 UI interaction broken | ★ | | | | ● | | | | ● | | |
| C02 API mismatch FE-BE | ★ | | | | | ● | | | | ● | |
| C03 Infrastructure down | ★ | | ● | ● | | | | ★ | ● | | |
| C04 Feature coverage gap | ★ | ● | | | | | | | | | ★ |
| C05 Security (OWASP) | | | ★ | | | ● | | | | | |
| C06 Performance | | | | ★ | ● | | | ● | | | |
| C07 Accessibility | | | | | ★ | | ● | | | | |
| C08 Business correctness | | ★ | | | | ● | | | | | ★ |
| C09 Edge-case data | ● | ● | | | | ★ | | | | | |
| C10 Concurrency | ● | | | ● | | ★ | | ● | | | |
| C11 Cross-browser | | | | ● | ● | | ★ | | ★ | | |
| C12 Unit test coverage | ★ | | ● | ● | ● | ● | ● | | | | |
| **NEW v8** Retry/Circuit-breaker missing | | | ● | ● | | | | ★ | | | |
| **NEW v8** Trace propagation broken | | | | | | | | ★ | | ● | |
| **NEW v9** Console errors runtime | ★ | | | | ● | | | | ★ | | |
| **NEW v9** Auth flow broken (Playwright) | ★ | ★ | ● | | | | | | ★ | | |
| **NEW v9** Cross-module reference drift | | | | | | | | | | ★ | ● |
| **NEW v9** API contract violation | | | | | | ● | | | | ★ | |
| **NEW v9.1** Missing business field | | ★ | | | | | | | | | ★ |
| **NEW v9.1** Missing compliance check | | ★ | ● | | | | | | | | ★ |

Chú thích: `★` = owner chính; `●` = liên quan nhưng không phải owner.

---

## QD1 — Functional Correctness (Đúng chức năng)

### Scope
Feature code chạy đúng spec đã viết trong `phase2-features/**` và theo `req-registry.json`.

### Definition of Done
Ở profile `standard`: 100% feature có `impl_status == "done"` trong scope được quét đều có ≥1 runtime evidence (HTTP 2xx trên happy path) HOẶC `skipped_due_to_missing_runtime` flag.

### Probes (7)
| ID | Loại | Mô tả |
|----|------|-------|
| P1.01 | static | Cross-ref `req-registry.json` với REQ-ID annotation |
| P1.02 | static | Parse route config (FE+BE) ↔ Navigation-*.md + API contract |
| P1.03 | runtime | Preflight infra (FE/BE/DB/CORS) |
| P1.04 | runtime | Deep UI traversal (Playwright click CTA, fill form smoke) |
| P1.05 | runtime | API smoke (happy path per endpoint) |
| P1.06 | static+runtime | Orphan UI detect (UI có nhưng không trong Navigation spec) |
| P1.07 | agent | LLM verify happy path khớp `phase2-features/[feat].md` |

### Exit Criteria
- `quick`: P1.01 + P1.03 only
- `standard`: + P1.02 + P1.04 + P1.05
- `deep`: + P1.06
- `exhaustive`: + P1.07

### Severity Default
HIGH (feature broken), MEDIUM (spec drift), LOW (orphan UI).

---

## QD2 — Business Correctness (Đúng nghiệp vụ)

### Scope
Business logic khớp domain rules (finance/healthcare/retail/...). Yêu cầu domain expert agent.

### Definition of Done
≥1 domain rule kiểm tra per feature có `impl_status == "done"` trong scope domain. Phát hiện vi phạm domain phải có evidence (test case reproducible).

### Probes (5)
| ID | Loại | Mô tả |
|----|------|-------|
| P2.01 | agent | Domain expert agent đọc spec + code, đánh giá khớp domain rule |
| P2.02 | static | Detect missing domain validation (vd: tax calc, currency conversion) |
| P2.03 | agent | Cross-check requirement docs ↔ implementation (LLM) |
| P2.04 | runtime | Simulate business workflow E2E (vd: order → payment → fulfillment) |
| P2.05 | static | Compliance check (GDPR, PCI-DSS, HIPAA tùy domain) |

### Exit Criteria
- `standard`: P2.01 + P2.02
- `deep`: + P2.03 + P2.04
- `exhaustive`: + P2.05

---

## QD3 — Security & Privacy (An toàn & Riêng tư)

### Scope
OWASP Top 10: Auth, authz, injection, secrets, data leakage, CSRF, XSS, broken access control, ...

### Definition of Done
Không có CRITICAL/HIGH security signals chưa được triage trong scope.

### Probes (7)
| ID | Loại | Mô tả |
|----|------|-------|
| P3.01 | static | Regex secret detection (API keys, tokens, passwords) |
| P3.02 | static | Auth/authz check (route protection, role enforcement) |
| P3.03 | static | Injection detection (SQL, NoSQL, command, LDAP) |
| P3.04 | runtime | XSS/CSRF (Playwright inject + verify sanitization) |
| P3.05 | external | Semgrep security rules (opt-in) |
| P3.06 | agent | Security agent review auth flow |
| P3.07 | static | CORS / CSP / security headers check |

### Special: KHÔNG dùng scan cache (security-sensitive, không chấp nhận false-pass).

### Exit Criteria
- `deep`: P3.01 + P3.02 + P3.06
- `exhaustive`: + all

---

## QD4 — Performance & Efficiency (Hiệu năng)

### Scope
Core Web Vitals (LCP/FID/CLS), query perf, memory leak, bundle size, rendering.

### Definition of Done
Trang trong scope có LCP <2.5s, CLS <0.1, bundle size <500KB initial (configurable per project).

### Probes (6)
| ID | Loại | Mô tả |
|----|------|-------|
| P4.01 | runtime | Lighthouse CWV measurement (Playwright) |
| P4.02 | static | N+1 query detection (ORM patterns) |
| P4.03 | static | Bundle size analysis (webpack stats) |
| P4.04 | runtime | Memory leak detect (long-running session) |
| P4.05 | external | Web Vitals API in production traces |
| P4.06 | agent | Performance agent review critical path |

### Exit Criteria
- `deep`: P4.01 + P4.02 + P4.03
- `exhaustive`: + all

---

## QD5 — Accessibility & UX (Khả dụng & Trải nghiệm)

### Scope
WCAG 2.2 AA + UX heuristics (Nielsen) + content quality.

### Definition of Done
0 WCAG AA violations CRITICAL/SERIOUS trong scope. Content rõ ràng cho người không chuyên.

### Probes (7)
| ID | Loại | Mô tả |
|----|------|-------|
| P5.01 | runtime | axe-core scan (Playwright) |
| P5.02 | static | Color contrast check |
| P5.03 | static | Alt text presence (img + svg + canvas) |
| P5.04 | runtime | Keyboard navigation test (Tab order, focus trap) |
| P5.05 | agent | UX agent review heuristics (Nielsen 10) |
| P5.06 | runtime | Screen reader smoke (Playwright + ARIA) |
| P5.07 | agent | Content review (tiếng Việt clarity per CORE-005, CORE-028) |

### Exit Criteria
- `quick`: P5.01 + P5.02 + P5.03
- `standard`: + P5.04
- `deep`: + P5.05 + P5.06
- `exhaustive`: + P5.07

---

## QD6 — Data Integrity & Resilience (Toàn vẹn dữ liệu & Chịu lỗi)

### Scope
Validation, constraints, edge cases, concurrency, idempotency, transaction integrity.

### Definition of Done
Mọi mutation API có validation + error handling. Không có race condition trên hot paths.

### Probes (6)
| ID | Loại | Mô tả |
|----|------|-------|
| P6.01 | static | Validation schema presence (Zod/Joi/Yup/Pydantic) |
| P6.02 | static | DB constraints check (FK, UNIQUE, CHECK) |
| P6.03 | static | Migration safety (irreversible, downtime) |
| P6.04 | runtime | Concurrent write test (race condition) |
| P6.05 | static | Idempotency key presence (payment/order APIs) |
| P6.06 | agent | DBA agent review schema |

### Exit Criteria
- `deep`: P6.01 + P6.02
- `exhaustive`: + all

---

## QD7 — Compatibility & Portability (Tương thích)

### Scope
Cross-browser, responsive, i18n, env parity (dev/staging/prod).

### Definition of Done
Test pass trên Chrome + Firefox + Safari (latest 2 versions) + Mobile Chrome/Safari. i18n keys không miss.

### Probes (5)
| ID | Loại | Mô tả |
|----|------|-------|
| P7.01 | runtime | Cross-browser smoke (Playwright Chromium + Firefox + WebKit) |
| P7.02 | runtime | Responsive viewport test (4 breakpoints) |
| P7.03 | static | Deprecated API usage (per browserlist) |
| P7.04 | static | i18n key coverage (tất cả ngôn ngữ có cùng keys) |
| P7.05 | runtime | Env config parity (.env.example ↔ actual env) |

### Exit Criteria
- `deep`: P7.01 + P7.02
- `exhaustive`: + all

---

## QD8 — Observability & Reliability (v8.2.0 — mới)

### Scope
Retry/circuit-breaker, timeout, log coverage, metrics, health-check, trace propagation, alert rules.

### Definition of Done
- 100% external API calls có retry config + timeout
- 100% endpoints có health-check
- Critical path có structured logging + correlation ID

### Probes (7)
| ID | Loại | Mô tả |
|----|------|-------|
| P8.01 | static | Retry/circuit-breaker presence (HTTP clients, MQ consumers) |
| P8.02 | static | Timeout configuration check |
| P8.03 | static | Log coverage (error paths, business events) |
| P8.04 | static | Metrics emission (Prometheus / OpenTelemetry) |
| P8.05 | runtime | Health-check endpoint test |
| P8.06 | static | Trace propagation (correlation ID through layers) |
| P8.07 | static | Alert rules existence (per-service SLO) |

### Special: KHÔNG dùng scan cache. CDG-RELIABILITY-RISK trigger trên payment/auth modules.

### Exit Criteria
- `deep`: P8.01 + P8.02 + P8.05
- `exhaustive`: + all

---

## QD9 — Runtime Health Verification (v9.0.x — mới, Playwright-heavy)

### Scope
Bugs chỉ thấy được qua browser runtime: console errors, network failures, uncaught exceptions, broken auth flows, SPA routes unreachable, CTAs không hoạt động, form validation thiếu.

### Definition of Done
- Mỗi route trong scope có ≥1 smoke test (Playwright) PASS
- 0 console errors (severity=error) trên happy path
- 0 network 5xx trên happy path

### Probes (7 — 3 core Wave 1 + 4 deep Wave 1.5)
| ID | Loại | Wave | Mô tả |
|----|------|------|-------|
| P9.01 | runtime | 1 | Console errors detection (Playwright onConsole) |
| P9.02 | runtime | 1 | Network failure detection (4xx/5xx + timeouts) |
| P9.03 | runtime | 1 | Uncaught exceptions (onPageError) |
| P9.04 | runtime | 1.5 | Auth flow test (login → protected route → logout) |
| P9.05 | runtime | 1.5 | SPA route reachability (all routes click-through) |
| P9.06 | runtime | 1.5 | CTAs working (click + verify state change) |
| P9.07 | runtime | 1.5 | Form validation present (submit empty + invalid inputs) |

### SKIP Rules
- `interface_type=api-only` → SKIP toàn QD9
- `--no-browser` → SKIP toàn QD9
- `profile=quick` → SKIP toàn QD9

### CDG Trigger
- **E090** Missing URL — `$URL` chưa set → AskUserQuestion: nhập URL / SKIP QD9 / Cancel
- **E090b** BASE_URL Conflict — 2 phiên cùng URL không có isolation → AskUserQuestion: tiếp tục risk / đợi peer / Cancel

### Exit Criteria
- `deep`: P9.01 + P9.02 + P9.03 (Wave 1 core)
- `exhaustive`: + Wave 1.5

---

## QD10 — Cross-Module Integration (v9.0.x — mới)

### Scope
Cross-module reference drift, API contract violations, event handler coverage gaps, orphan FK references, multi-platform entity sync, cache staleness, state machine errors, business flow violations, auth matrix violations.

### Definition of Done
- Mọi cross-module dependency declare trong `cross_module_dependencies[]` registry
- 0 orphan FK trong DB
- API contract giữa modules có schema test PASS

### Probes (9)
| ID | Loại | Mô tả |
|----|------|-------|
| P10.01 | static | Cross-module reference drift (caller ↔ callee signature) |
| P10.02 | static | API contract violation (OpenAPI/GraphQL schema sync) |
| P10.03 | static | Event handler coverage (publisher ↔ subscriber) |
| P10.04 | static | Orphan FK detection (DB → code) |
| P10.05 | static | Multi-platform entity sync (web/mobile/desktop) |
| P10.06 | runtime | Cache staleness test (write → read after TTL) |
| P10.07 | static | State machine error (invalid transitions in spec) |
| P10.08 | agent | Business flow violation review (LLM cross-module) |
| P10.09 | static | Auth matrix violation (role × resource × action) |

### SKIP Rules
- Single module project → SKIP toàn QD10
- `profile=quick` → SKIP toàn QD10

### Exit Criteria
- `deep`: P10.01 + P10.02 + P10.04 + P10.09
- `exhaustive`: + all

---

## QD11 — Business Completeness & Enhancement (v9.1.0 — mới, LLM-heavy)

### Scope
**3-pass LLM analysis** phát hiện missing business logic:

- **Pass 1** Cross-module pattern comparison — pattern A có ở module X nhưng thiếu ở module Y với cùng vai trò
- **Pass 2** Domain heuristic analysis — domain rule thường có (vd: invoice cần tax line) nhưng thiếu trong implementation
- **Pass 3** Registry gap detection — REQ-ID có trong `req-registry.json` nhưng chưa map sang code, hoặc code có FEAT chưa link REQ

### Definition of Done
≥1 LLM pass mỗi feature trong scope. Enhancement suggestions PASS qua CDG gate (user ACCEPT/REJECT).

### Signal Types (11)
- `MISSING_FIELD` — field thiếu so với pattern domain
- `MISSING_FEATURE` — feature thiếu so với module tương tự
- `TYPE_MISMATCH` — kiểu dữ liệu không khớp
- `VALIDATION_GAP` — thiếu validation cho input
- `MISSING_DOMAIN_FIELD` — field bắt buộc của domain (vd: SKU cho product)
- `MISSING_COMPLIANCE_CHECK` — thiếu check compliance (GDPR, SOX)
- `MISSING_AUDIT_TRAIL` — thiếu audit log cho action quan trọng
- `MISSING_BUSINESS_RULE` — thiếu rule mô tả trong spec
- `UNIMPLEMENTED_REQ` — REQ-ID `impl_status=not_started`
- `ORPHAN_REQ_ID` — code có REQ-ID không có trong registry
- `GAP_REQ_TO_FEAT` — REQ-ID không có FEAT-ID nào link

### SKIP Rules
- Single module project → SKIP Pass 1
- `interface_type=api-only` → SKIP UI-related signals
- `profile=quick` → SKIP toàn QD11

### Exit Criteria
- `deep`: Pass 1 + Pass 3
- `exhaustive`: + Pass 2

### Enhancement Workflow
LLM suggest fix → CDG gate hỏi user ACCEPT/REJECT từng suggestion → ACCEPT → bug-triage.md ghi như issue thường → Phase 6 execute fix.

---

## Severity Aggregation (Cross-Dimension)

Một issue có thể được nhiều dim probe cùng signal. Triage agent (`wf-fix-triage`) aggregate:

```
issue.severity = MAX(signal.severity_hint for signal in matched_signals)
issue.dimensions = UNION(signal.dimension for signal in matched_signals)
issue.fixability = derive from severity + signal count + automation hint
```

**Quy tắc:**
- 1 issue → 1-N dimensions (vd: SQL injection trong payment → QD3 + QD6)
- Severity là MAX (không average) — để tránh underweight
- Fixability `auto` chỉ khi confidence ≥0.9 + low-risk (CORE-006 safety)

---

## Evidence Requirements (Cross-Dimension)

Mọi Signal PHẢI có ≥1 evidence field non-empty:

| Field | Loại bug |
|-------|---------|
| `code_ref` (file:line) | Static rule, LLM review |
| `screenshot` (PNG path) | UI bug, a11y, runtime health |
| `har` (HTTP archive) | Network failure, API contract |
| `log` (text) | Runtime exception, error log |
| `artifact` (any file path) | Lighthouse report, Semgrep report, axe report |
| `query_plan` | Performance N+1 |
| `trace` (OpenTelemetry) | Observability, cross-module |

Phase 7 CQG-2 verify mỗi issue có evidence file tồn tại + readable.

---

## Lane Skill Pattern

Mỗi dim là một skill `wf-fix-{slug}/SKILL.md` riêng biệt:

```
.claude/skills/workflow/wf-fix-{slug}/
├── SKILL.md                      # Lazy-load router (≤300 dòng)
├── _contract.json                # Skill contract
├── dimension.json                # Probe definitions + metadata
├── procedures/                   # Per-probe procedures
│   ├── _shared.md                # Shared utilities
│   ├── static-scan.md            # Static probes
│   ├── runtime.md                # Runtime probes (Playwright nếu cần)
│   └── llm-scan.md               # LLM probes (chỉ QD2, QD11, ...)
├── templates/                    # Output templates
│   ├── lane-status.json
│   ├── signals.json
│   └── QD{n}-report.md
└── evals/                        # Test cases
```

**Contract bắt buộc:**
- Input env: `SESSION_DIR`, `PROFILE`, `SCOPE`, `NAME`, `DIMS_ARRAY`, `CI_CONTEXT`, `URL`, `SHOW_BROWSER`, `MOBILE_MODE`
- Output: `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}-{slug}/{static-scan,runtime,llm-scan}/signals.json` + `lane-status.json` + `QD{n}-report.md`
- Lock: acquire reader-lock `source` (Protocol 22); Playwright lanes acquire writer-lock `playwright`

---

## Liên Kết

| Tài liệu | Lý do |
|----------|-------|
| [01-vision-principles.md](01-vision-principles.md) | Vision + 11 design principles |
| [03-architecture.md](03-architecture.md) | Pipeline 7-phase + Phase 4 PARALLEL dispatch |
| [04-contracts-data-model.md](04-contracts-data-model.md) | Signal/Issue schemas, output paths |
| [05-execution-profiles.md](05-execution-profiles.md) | Profile × Dim matrix |
| [07-tradeoffs-adr.md](07-tradeoffs-adr.md) | ADR-26 (QD8), ADR-27 (QD9), ADR-28 (QD10), ADR-29 (QD11) |
| `.claude/skills/workflow/wf-fix-{slug}/dimension.json` | Probe definitions canonical per lane |
