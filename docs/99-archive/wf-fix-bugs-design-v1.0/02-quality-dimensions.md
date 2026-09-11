# 02 — 7 Quality Dimensions (Core)

> **Đọc trước:** [01-vision-principles.md](01-vision-principles.md)
> **Đọc tiếp:** [03-architecture.md](03-architecture.md)

---

## Bối cảnh & Phạm Vi File Này

Đây là file **lõi** của bộ design. Mọi quyết định khác (architecture, contracts, profiles, migration) dựa trên 7 dimension được định nghĩa ở đây.

Mỗi Quality Dimension (QD) được mô tả theo 8 trường:

1. **Scope** — phạm vi chất lượng dimension chịu trách nhiệm.
2. **Definition of Done (DoD)** — khi nào coi là "đã kiểm đủ" cho dimension đó ở một profile nhất định.
3. **Probes** — các đơn vị phát hiện (static rule, runtime check, LLM review, external tool).
4. **Exit Criteria (per profile)** — điều kiện dừng.
5. **Severity Rules** — cách gán severity khi có vi phạm.
6. **Evidence Requirements** — loại bằng chứng bắt buộc khi emit Signal.
7. **External Tools (opt-in)** — công cụ bên ngoài có thể dùng, graceful degrade khi thiếu.
8. **Agents Used** — agent DEVKIT được gọi (nếu có).

---

## Map Nhanh — 7 QD × 12 Bug Categories Cũ

Bảng ánh xạ từ 12 category của `plans/coverage-expansion/01-strategy.md §5` sang 7 QD:

| Category (cũ) | QD1 Functional | QD2 Business | QD3 Security | QD4 Perf | QD5 A11y/UX | QD6 Data | QD7 Compat |
|---------------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| C01 UI interaction broken | **★** | | | | ● | | |
| C02 API mismatch FE-BE | **★** | | | | | ● | |
| C03 Infrastructure down | **★** | | ● | ● | | | |
| C04 Feature coverage gap | **★** | ● | | | | | |
| C05 Security (OWASP) | | | **★** | | | ● | |
| C06 Performance | | | | **★** | ● | | |
| C07 Accessibility | | | | | **★** | | ● |
| C08 Business correctness | | **★** | | | | ● | |
| C09 Edge-case data | ● | ● | | | | **★** | |
| C10 Concurrency | ● | | | ● | | **★** | |
| C11 Cross-browser | | | | ● | ● | | **★** |
| C12 Unit test coverage | **★** | | ● | ● | ● | ● | ● |

Chú thích: `★` = owner chính; `●` = có liên quan nhưng không phải owner.

Observations:

- Không có category nào bị orphan — tất cả đều có ít nhất 1 owner.
- C12 (unit test coverage) cross-cut 7 dimensions — được mô hình hoá thành **cross-dimensional probe** chứ không phải lane riêng (xem §10).
- C03 (infrastructure) primarily QD1 (app có chạy không) nhưng có hệ quả QD3/QD4 — giữ trong QD1 vì đây là "feature hoạt động được hay không" là điều kiện tiên quyết.

---

## QD1 — Functional Correctness (Đúng chức năng)

### Scope
Feature code chạy đúng với spec đã viết trong `phase2-features/**` và theo `req-registry.json`. Bao gồm:

- UI control hoạt động (click, fill, submit đi đúng route).
- API endpoint tồn tại + trả về HTTP status khớp contract.
- Infrastructure availability (FE/BE/DB/CORS có up).
- Feature được impl đúng REQ-ID đã `done` — không drift so với spec.
- Navigation khớp design (Navigation-*.md).

### Definition of Done
Ở profile `standard`: 100% feature có `impl_status == "done"` trong scope được quét đều có ít nhất 1 runtime evidence (HTTP 2xx trên happy path) HOẶC đánh dấu `skipped_due_to_missing_runtime`.

### Probes

| Probe ID | Loại | Mô tả | Nguồn | Map Category cũ |
|---------|------|-------|-------|-----------------|
| P1.01 | static | Cross-ref `req-registry.json` với file code có REQ-ID annotation | Grep + jq | C04 |
| P1.02 | static | Parse route config (FE + BE) → so với Navigation-*.md + API contract trong `phase3-architecture/` | AST/config parser | C01, C02 |
| P1.03 | runtime | Preflight infra (FE/BE/DB/CORS alive) | bash + curl | C03 |
| P1.04 | runtime | Deep UI traversal → click primary CTAs, fill forms smoke | Playwright | C01 |
| P1.05 | runtime | API smoke (happy path) per endpoint có trong spec | curl / fetch | C02 |
| P1.06 | static + runtime | Detect orphan UI (UI có nhưng không trong Navigation spec) | Playwright catalog vs spec | C01 (deep) |
| P1.07 | agent | `general-purpose` agent đọc `phase2-features/[feat].md` + runtime evidence → verify happy path khớp | Agent | C04 |

### Exit Criteria (per profile)

| Profile | Điều kiện dừng QD1 |
|---------|---------------------|
| quick | P1.01 + P1.03 + P1.05 (happy path API) |
| standard | quick + P1.02 + P1.04 (UI smoke) + P1.06 (nếu có UI) |
| deep | standard + P1.07 (agent verify) + Playwright traversal ≥2 levels |
| exhaustive | deep + mutate input boundary per endpoint + full navigation graph traversal |

### Severity Rules

- Infrastructure down (P1.03 fail) → **CRITICAL**.
- Feature impl_status=done nhưng endpoint không tồn tại / HTTP 5xx → **CRITICAL**.
- UI primary CTA không click được / form không submit → **HIGH**.
- Orphan UI element → **MEDIUM** (không ảnh hưởng user, nhưng có thể dead-code).
- Coverage gap (REQ-ID không có code ref) → **MEDIUM** (impl_status khác `done`) hoặc **HIGH** (impl_status=`done`).

### Evidence Requirements

- `code_ref`: path:line khi static.
- `http_response`: status + body excerpt khi runtime.
- `screenshot`: Playwright capture nếu UI.
- `reproducer`: command `curl -X ...` hoặc step list Playwright.

### External Tools (opt-in)

- Playwright (mặc định đã có).
- Optional: Cypress adapter nếu project dùng Cypress.

### Agents Used

- `general-purpose` (đọc doc + reason) cho P1.07.
- `fullstack-developer` (secondary) nếu cần inspect code.

---

## QD2 — Business Correctness (Đúng nghiệp vụ)

### Scope
Business logic khớp domain rules. Nơi feature chạy "đúng kỹ thuật" nhưng **sai nghiệp vụ**:

- Tính toán tài chính sai (số dư, thuế, phí).
- Quy trình nghiệp vụ skip bước (ví dụ: duyệt đơn trước khi xuất kho).
- HS Code sai cho logistics.
- Policy vi phạm (ví dụ: medicare drug coverage rule).

### Definition of Done
Ở `standard`: domain expert agent review **tất cả feature thuộc departments đã khai báo trong registry** + tìm ít nhất 3 business rule vi phạm tiềm ẩn HOẶC confirm clean.

### Probes

| Probe ID | Loại | Mô tả | Nguồn | Map Category cũ |
|---------|------|-------|-------|-----------------|
| P2.01 | agent | Domain expert agent (business/[domain].md) đọc feature spec + code → review logic theo domain | Agent | C08 |
| P2.02 | static | Check calculation code vs reference formulas (nếu có trong references/team-expert/[domain]/) | AST + reference cross-ref | C08 |
| P2.03 | runtime + fixture | Execute domain-specific test fixtures (GL balance, posting flow, ...) | Fixture runner | C08 |
| P2.04 | agent | `business-analyst` review flow-[feat].md vs code path | Agent | C04 + C08 |
| P2.05 | static | Detect hard-coded values nên là config (tax rate, interest, ...) | Pattern match | C08 |

### Exit Criteria

| Profile | Điều kiện dừng QD2 |
|---------|---------------------|
| quick | **SKIP** (QD2 tốn agent token nhất; skip mặc định trong quick) |
| standard | P2.01 per department trong scope + P2.02 + P2.05 |
| deep | standard + P2.03 (domain fixture) + P2.04 |
| exhaustive | deep + expand fixture set + cross-dept workflow review |

### Severity Rules

- Calculation sai dẫn đến sai số tiền/quyết định → **CRITICAL**.
- Quy trình skip bước compliance (audit trail) → **CRITICAL**.
- Hard-coded value nên config → **MEDIUM**.
- Ambiguous logic (agent low confidence) → **LOW** + flag "needs SME".

### Evidence Requirements

- `agent_output`: JSON từ agent (bắt buộc schema theo CORE-029).
- `reference_rule`: link tới file trong `.claude/references/team-expert/[domain]/`.
- `code_ref`: path:line.
- `fixture_result`: diff expected vs actual (nếu P2.03).

### External Tools (opt-in)

- Domain fixtures repo (project-specific).
- Không bắt buộc tool ngoài.

### Agents Used

- `business/[domain]` agents (25 agents trong `.claude/agents/business/`).
- `business-analyst` (general).

---

## QD3 — Security & Privacy (An toàn & Riêng tư)

### Scope
Vulnerability trực tiếp — auth, authz, injection, secrets, data leakage; bám OWASP Top 10 + privacy baseline.

### Definition of Done
Ở `standard`: mọi endpoint có authz check; không có secret hard-coded; mọi input user-controlled có validation ở BE; session/cookie settings đúng.

### Probes

| Probe ID | Loại | Mô tả | Nguồn | Map Category cũ |
|---------|------|-------|-------|-----------------|
| P3.01 | static | Scan secret patterns (API key, token, password, private key) | gitleaks / regex | C05 |
| P3.02 | static | Detect missing authz middleware per route | AST + config | C05 |
| P3.03 | static | Detect SQL concat / dynamic query without param | AST pattern | C05 |
| P3.04 | static | Detect dangerous deserialize / eval / innerHTML user-data | AST pattern | C05 |
| P3.05 | static (ext) | Run Semgrep OSS rules (p/owasp-top-ten) | Semgrep | C05 |
| P3.06 | runtime | Auth bypass test (truy cập endpoint bảo mật không token) | curl scripted | C05 |
| P3.07 | runtime | CSRF / CORS misconfig probe | curl + header analysis | C05 |
| P3.08 | static | Cookie/session flags (httpOnly, secure, sameSite) | Config parser | C05 |
| P3.09 | agent | `security-engineer` agent review auth flow + threat model | Agent | C05 |

### Exit Criteria

| Profile | Điều kiện dừng QD3 |
|---------|---------------------|
| quick | P3.01 + P3.02 + P3.08 (static nhanh) |
| standard | quick + P3.03 + P3.04 + P3.05 (nếu Semgrep có) + P3.07 |
| deep | standard + P3.06 + P3.09 |
| exhaustive | deep + brute authz matrix test + fuzz input per endpoint |

### Severity Rules

- Hard-coded secret → **CRITICAL** (không bao giờ auto-fix — ESCALATE per CORE-027 CDG).
- Missing authz trên endpoint business → **CRITICAL**.
- SQL injection vector xác nhận được → **CRITICAL**.
- CSRF/CORS open → **HIGH**.
- Cookie flags thiếu → **MEDIUM** (trừ production = HIGH).

### Evidence Requirements

- `code_ref` + `pattern_matched`.
- `http_trace` khi runtime.
- `cvss_vector` (optional) — nếu Semgrep/agent tính được.
- `mitigation_hint` bắt buộc.

### External Tools (opt-in)

- Semgrep OSS (free).
- gitleaks (free).
- trufflehog (free, optional).
- Semgrep Cloud (paid, optional).

### Agents Used

- `security-engineer`.
- `architect` (cho threat model).

---

## QD4 — Performance & Efficiency (Hiệu năng)

### Scope
Latency, throughput, memory, bundle size, rendering perf. CWV (LCP, INP, CLS) cho web; p50/p95/p99 cho API; N+1, slow query, memory leak.

### Definition of Done
Ở `standard`: chạy Lighthouse trên 3 trang quan trọng nhất + khảo sát SQL top slow queries + detect N+1 pattern tĩnh.

### Probes

| Probe ID | Loại | Mô tả | Nguồn | Map Category cũ |
|---------|------|-------|-------|-----------------|
| P4.01 | runtime (ext) | Lighthouse CLI → CWV + bundle size | Lighthouse | C06 |
| P4.02 | static | N+1 detector (loop chứa ORM call) | AST | C06 |
| P4.03 | static | Detect SELECT * / missing index hint / large LIMIT | SQL parser | C06 |
| P4.04 | runtime | API latency sample (N requests × critical endpoints) | k6 / curl loop | C06 |
| P4.05 | runtime (ext) | Load test (k6) theo profile | k6 | C06, C10 |
| P4.06 | static | Bundle analyzer (webpack/vite) detect large dep | webpack-bundle-analyzer | C06 |
| P4.07 | agent | `performance-engineer` review hot path | Agent | C06 |
| P4.08 | static | Detect missing memoization (React.memo, useMemo, Select cache) | AST | C06 |

### Exit Criteria

| Profile | Điều kiện dừng QD4 |
|---------|---------------------|
| quick | P4.02 + P4.03 (static nhanh) |
| standard | quick + P4.01 (3 page) + P4.04 (1 sample) |
| deep | standard + P4.05 (smoke load) + P4.06 + P4.08 |
| exhaustive | deep + P4.07 + long-run load test |

### Severity Rules

- LCP > 4s / INP > 500ms trên page chính → **HIGH**.
- N+1 xác nhận được trên endpoint hot → **HIGH**.
- API p95 > 1000ms → **HIGH**.
- Bundle > 500KB gzip → **MEDIUM**.
- Missing memoization → **LOW** (trừ khi ảnh hưởng render cụ thể).

### Evidence Requirements

- `lighthouse_score` (JSON excerpt).
- `query_plan` (EXPLAIN) nếu SQL.
- `latency_stats` (min/p50/p95/p99/max).
- `flame_graph_url` (optional).

### External Tools (opt-in)

- Lighthouse CLI.
- k6 (recommended) / Artillery.
- webpack-bundle-analyzer / vite-bundle-visualizer.

### Agents Used

- `performance-engineer`.

---

## QD5 — Accessibility & UX (Khả dụng & Trải nghiệm)

### Scope
Accessibility WCAG 2.2 AA + UX heuristics (Nielsen 10) + content quality (microcopy, error message, empty state).

### Definition of Done
Ở `standard`: axe-core chạy trên mỗi page có UI + auto-traversal check focus order/keyboard/contrast + content pattern review.

### Probes

| Probe ID | Loại | Mô tả | Nguồn | Map Category cũ |
|---------|------|-------|-------|-----------------|
| P5.01 | runtime (ext) | axe-core scan per page | axe-core | C07 |
| P5.02 | runtime | Keyboard traversal (Tab order, focus visible) | Playwright | C07 |
| P5.03 | runtime | Color contrast check (dark + light theme) | axe / tool | C07 |
| P5.04 | static | Detect missing aria-label / alt / form label | HTML parser | C07 |
| P5.05 | agent | `ux-designer` hoặc `design-critique` agent review flow | Agent | C01 (UX deep) |
| P5.06 | static | Detect inconsistent label (plan cũ — `ui_label_inconsistent`) | Catalog cross-ref | C01 |
| P5.07 | runtime | Error state + empty state test (trigger N/A, empty list, offline) | Playwright | C01/C07 |
| P5.08 | agent | `ux-copy` agent review microcopy | Agent | (QD5 subset) |

### Exit Criteria

| Profile | Điều kiện dừng QD5 |
|---------|---------------------|
| quick | P5.04 + P5.06 (static) |
| standard | quick + P5.01 + P5.02 + P5.03 |
| deep | standard + P5.05 + P5.07 |
| exhaustive | deep + P5.08 + screen reader smoke test (tool-dependent) |

### Severity Rules

- axe violation CRITICAL/SERIOUS → **HIGH**.
- axe MODERATE → **MEDIUM**.
- Missing primary label / empty alt → **MEDIUM**.
- Keyboard trap → **HIGH**.
- Contrast ratio fail text < 3:1 → **HIGH**.
- Inconsistent label (non-critical) → **LOW**.

### Evidence Requirements

- `axe_violation_id` + `impact`.
- `screenshot` (before/after focus).
- `contrast_ratio` value.
- `agent_output` (UX review).

### External Tools (opt-in)

- axe-core CLI.
- Playwright (core).
- pa11y (alternative).

### Agents Used

- `ux-designer`, `design-critique`, `ux-copy`.

---

## QD6 — Data Integrity & Resilience (Toàn vẹn dữ liệu & Chịu lỗi)

### Scope
Validation đầu vào, constraint DB, edge-case (null/empty/unicode/boundary), concurrency (race, idempotency, stale read, deadlock), retry & timeout policies.

### Definition of Done
Ở `standard`: fuzz các endpoint POST/PUT với dataset edge-case mẫu; kiểm tra constraint DB (NOT NULL, UNIQUE, FK) match với schema; phân tích idempotency key trên mutation endpoint.

### Probes

| Probe ID | Loại | Mô tả | Nguồn | Map Category cũ |
|---------|------|-------|-------|-----------------|
| P6.01 | runtime | Edge-case data fuzz (null, "", "   ", unicode, boundary int, SQL special chars) | Scripted fuzzer | C09 |
| P6.02 | static | Compare request DTO validation vs DB constraint | AST + schema parse | C09 |
| P6.03 | static | Detect missing idempotency key on write endpoint | AST pattern | C10 |
| P6.04 | runtime | Concurrent request race (2-N parallel calls cùng id) | scripted | C10 |
| P6.05 | static | Detect lock / transaction scope trong business code | AST | C10 |
| P6.06 | runtime | Retry / timeout behavior probe (BE chậm → FE có timeout đúng?) | scripted | C10 |
| P6.07 | agent | `database-engineer` review schema + constraint | Agent | C09 |
| P6.08 | static | Detect missing migration for DDL change (drift) | Migration vs schema diff | C09 |

### Exit Criteria

| Profile | Điều kiện dừng QD6 |
|---------|---------------------|
| quick | P6.02 + P6.03 |
| standard | quick + P6.01 (basic fuzz) + P6.05 + P6.08 |
| deep | standard + P6.04 + P6.06 + P6.07 |
| exhaustive | deep + property-based test generation + chaos mode (optional) |

### Severity Rules

- Missing DB constraint khiến data corrupt → **CRITICAL**.
- No idempotency trên payment / order endpoint → **CRITICAL**.
- Race condition xác nhận được trên business mutation → **CRITICAL**.
- Edge-case crash (500) → **HIGH**.
- Validation mismatch FE-BE → **MEDIUM**.
- Missing retry/timeout → **MEDIUM**.

### Evidence Requirements

- `payload_case` + `response_observed`.
- `schema_diff`.
- `race_reproducer` script.
- `agent_output` (database review).

### External Tools (opt-in)

- Optional property-based libs (fast-check, hypothesis).

### Agents Used

- `database-engineer`, `backend-developer`.

---

## QD7 — Compatibility & Portability (Tương thích)

### Scope
Cross-browser (Chromium/Firefox/WebKit), responsive (breakpoints), i18n (locale, RTL, timezone), env parity (dev/stage/prod env var).

### Definition of Done
Ở `standard`: smoke 3 critical page trên 2 browser (Chromium + 1 khác) + test 4 breakpoints; check i18n fallback.

### Probes

| Probe ID | Loại | Mô tả | Nguồn | Map Category cũ |
|---------|------|-------|-------|-----------------|
| P7.01 | runtime | Playwright multi-browser smoke | Playwright | C11 |
| P7.02 | runtime | Responsive snapshot 4 breakpoints (mobile/tablet/laptop/desktop) | Playwright | C11 |
| P7.03 | static | Detect hard-coded locale / date format / currency | Grep pattern | — |
| P7.04 | runtime | i18n fallback test (locale chưa có → fallback đúng?) | Playwright | — |
| P7.05 | static | Env var parity (`.env.example` vs `.env.local` vs secret store) | Config diff | — |
| P7.06 | agent | `accessibility-reviewer` verify RTL layout nếu có ar/he locale | Agent | — |

### Exit Criteria

| Profile | Điều kiện dừng QD7 |
|---------|---------------------|
| quick | P7.03 + P7.05 (static) |
| standard | quick + P7.01 (Chromium + 1 khác) + P7.02 |
| deep | standard + full 3-browser + P7.04 |
| exhaustive | deep + P7.06 + mobile real-device (optional) |

### Severity Rules

- Layout vỡ trên mobile (CLS > 0.25) → **HIGH**.
- Firefox/WebKit crash hoặc feature không chạy → **HIGH**.
- Hard-coded locale → **MEDIUM**.
- Env var missing → **HIGH** (nếu là required) / **MEDIUM** (optional).

### Evidence Requirements

- `browser` (chromium/firefox/webkit).
- `viewport` dimensions.
- `screenshot` per breakpoint.
- `env_diff` (key missing list).

### External Tools (opt-in)

- Playwright multi-browser (core).
- BrowserStack / SauceLabs (optional, out of scope default).

### Agents Used

- `accessibility-reviewer` (shared với QD5 nhưng focus RTL).

---

## Cross-Dimensional Probes

Một số probe không thuộc lane duy nhất mà cross-cut:

### XP1 — Test Coverage Cross-Check (C12 mapping)

- Input: coverage report từ test runner (Jest, Vitest, pytest, ...).
- Output: per-dimension coverage score = % file test touched / file impl trong dimension đó.
- Emit Signal `test_coverage_gap` tag với dimension tương ứng.
- Owner: `wf-fix-bugs` orchestrator (không thuộc lane nào).
- Severity: LOW/MEDIUM tuỳ dimension (security = MEDIUM, perf/a11y = LOW).

### XP2 — Documentation Drift

- Input: `phase2-features/*.md` + code annotation.
- Output: Signal nếu spec viết feature X có behavior Y, nhưng code không có (hoặc ngược lại).
- Map: QD1 (Functional) + QD2 (Business).
- Owner: shared utility, emit dưới cờ dimension của Signal gốc.

### XP3 — Tech Debt Smell

- Input: TODO/FIXME/XXX comment scan.
- Output: Signal nếu TODO > 6 tháng hoặc đặt trong code path critical (security, payment).
- Map: QD1 default; escalate sang QD3/QD6 nếu path nhạy cảm.
- Owner: shared utility.

---

## Exit Criteria Tổng (Coverage Report)

Mỗi run phải xuất `coverage-report.md` (đã có trong plan cũ) — nhưng **format mới** dimension-first:

```
# Coverage Report — run-NNN--YYYYMMDD

Profile: standard
Scope: all (hoặc system=X / module=Y)
Wall clock: 47 min

Dimension Coverage
──────────────────────────────────────────────
QD1 Functional Correctness   ✓ 6/6 probes   12 signals   8 issues
QD2 Business Correctness     ⏭ skipped (quick profile)
QD3 Security & Privacy       ✓ 5/5 probes    3 signals   2 issues
QD4 Performance              ⚠ 3/4 probes    tool missing: k6
QD5 Accessibility & UX       ✓ 4/4 probes    7 signals   5 issues
QD6 Data Integrity           ✓ 5/5 probes    4 signals   3 issues
QD7 Compatibility            ⚠ partial — Firefox runner timeout

Total: 29 unique issues (after dedup across dimensions)
Critical: 3 · High: 11 · Medium: 12 · Low: 3

Next Action
  - Install k6 to enable load test probe (QD4)
  - Check Firefox runner config for QD7
```

> Format chính thức xem [04-contracts-data-model.md §Coverage Report](04-contracts-data-model.md).

---

## Severity Aggregation Rule (Cross-Dimension)

Khi 1 Issue thuộc nhiều dimension:

```
final_severity = MAX(severity_per_dimension)
final_impact   = UNION(impact_tag_per_dimension)
```

Ví dụ:

- Issue "endpoint `/admin/reset-password` không check authz" → QD1 (CRITICAL: feature gap) + QD3 (CRITICAL: auth bypass) → final = CRITICAL.
- Issue "form ngày sinh accept tương lai 9999" → QD1 (MEDIUM) + QD2 (HIGH nếu ngành y tế) + QD6 (HIGH) → final = HIGH.

Triage service (xem [03-architecture.md](03-architecture.md)) chịu trách nhiệm compute final_severity khi merge.

---

## Checklist Implementer

Khi thêm 1 dimension mới hoặc sửa dimension hiện có:

- [ ] Viết rõ Scope + DoD + Exit Criteria per profile.
- [ ] Khai báo probes với `probe_id` unique pattern `P<dim>.<NN>`.
- [ ] Mỗi probe chỉ rõ: loại (static/runtime/agent/ext), evidence yêu cầu, tool dependency.
- [ ] Severity rules có đủ 4 mức (CRITICAL/HIGH/MEDIUM/LOW) với ví dụ.
- [ ] Agents dùng phải có trong `.claude/agents/*` (không tạo agent mới trong dimension doc — làm PR riêng).
- [ ] Cập nhật bảng map "7 QD × 12 Category" ở §2 nếu thay đổi category.
- [ ] Cập nhật `dimension.json` manifest (schema xem [04-contracts-data-model.md §Dimension Manifest](04-contracts-data-model.md)).

---

## Liên Kết

- Kiến trúc implement các lane này → [03-architecture.md](03-architecture.md).
- Signal/Issue schema chi tiết → [04-contracts-data-model.md](04-contracts-data-model.md).
- Map profile → exit criteria → runtime budget → [05-execution-profiles.md](05-execution-profiles.md).
- Tranh luận tại sao 7 chứ không 5 hoặc 10 → [07-tradeoffs-adr.md §ADR-01](07-tradeoffs-adr.md).
