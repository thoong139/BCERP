# Stage D Prompt — Dimension Lanes QD3-QD7

## Context

Stage C hoàn tất (PASS). Bellweather lanes QD1 (Functional) + QD2 (Business) đã build + test thành công:
- 28 files mới, ~1,690 LOC
- 16/16 E2E tests pass, 337 total tests (0 failures)
- Signal Bus dedup, Impact Graph ripple, Scan Cache wiring hoạt động
- Golden fixture: sample-project với 4 known issues → 4 signals (100% precision)
- CI path filters updated cho wf-fix-functional/** và wf-fix-business/**

Giờ mở rộng toàn bộ dimension lane model: build 5 lanes còn lại (QD3-QD7).

---

## Stage D: Dimension Lanes QD3-QD7

### Mục tiêu

Xây dựng 5 dimension lanes còn lại theo bellweather pattern từ Stage C:

| Lane | Dimension | Focus | Profile quick | Probes |
|------|-----------|-------|---------------|--------|
| wf-fix-security | QD3 | Security vulnerabilities | 3 probes | 7 probes |
| wf-fix-performance | QD4 | Performance bottlenecks | 3 probes | 6 probes |
| wf-fix-ux-a11y | QD5 | UX consistency + Accessibility | 3 probes | 7 probes |
| wf-fix-data | QD6 | Data integrity + schema drift | 3 probes | 6 probes |
| wf-fix-compat | QD7 | Browser/API/device compatibility | 3 probes | 5 probes |

### Key Constraints

1. **ADR-22 Rule 6**: QD3 (Security) **KHÔNG BAO GIỜ cache** — luôn re-scan để tránh stale security results
2. **Probe ID format**: `P-QD[3-7]-<slug>` matching regex `^P-QD[3-7]-[a-z0-9-]+$`
3. **Signal Bus**: mỗi lane emit signals → `SignalBus.ingest()` → `flush()` with POST-GATE T1-T4
4. **Scan Cache**: static probes sử dụng cache (TRỪ QD3), runtime probes skip cache
5. **Impact Graph**: mỗi lane call `verify_ripple()` sau khi propose fixes
6. **CORE-028**: phase-summary.md ≤15 dòng
7. **CORE-029**: agent probes phải spot-check output schema
8. **CORE-030**: session isolation — mỗi lane writes vào `lanes/QD[N]/`
9. **CORE-031**: mọi output từ template

### Critical Files to Reuse

| Module | Path | Use |
|--------|------|-----|
| Signal Bus | `_shared/signal_bus/signal_bus.py` | `ingest()` + `flush()` |
| Scan Cache | `_shared/scan_cache/` | `fingerprint()` → `cache_lookup()` → `cache_store()` |
| Impact Graph | `_shared/impact_graph/builder.py` | `build()` + `emit()` |
| Impact Graph | `_shared/impact_graph/ripple.py` | `verify_ripple()` |
| ISG | `_shared/isg/` | Issue Signal Generator |
| Concurrency | `_shared/concurrency/` | Backpressure + AdaptiveBackpressure |
| Workload Estimator | `_shared/workload_estimator/` | Probe count + time estimation |
| Test conftest | `_shared/tests/conftest.py` | Fixtures: `sample_signal_dict`, `tmp_session_dir` |
| E2E tests | `_shared/tests/test_e2e_qd1_qd2.py` | Pattern reference |
| Golden fixture | `_shared/tests/fixtures/sample-project/` | Extend with QD3-QD7 known issues |
| QD1 probes | `wf-fix-functional/probes/` | Pattern reference for probe structure |
| QD2 probes | `wf-fix-business/probes/` | Pattern reference for agent probes |
| Design docs | `docs/design/skills/wf-fix-bugs/` | 02-quality-dimensions.md (probe specs), 03-architecture.md |
| CI config | `.github/workflows/wf-fix-bugs-ci.yml` | Add new lane path filters |

### Agent Definitions to Use

| Lane | Agent | subagent_type |
|------|-------|---------------|
| QD3 Security | security | `security` |
| QD4 Performance | performance-benchmarker | `performance-benchmarker` |
| QD5 UX/A11y | ux-researcher, accessibility-auditor | `ux-researcher`, `accessibility-auditor` |
| QD6 Data | dba, data-engineer | `dba`, `data-engineer` |
| QD7 Compat | frontend-developer, mobile-developer | `frontend-developer`, `mobile-developer` |

---

## D1: QD3 Security Lane Skeleton

Create `.claude/skills/workflow/wf-fix-security/`.

### Files (mirror QD1 structure)

| File | LOC est | Purpose |
|------|---------|---------|
| `SKILL.md` | ~350 | Lane procedure + ADR-22 Rule 6 enforcement (no cache) |
| `_contract.json` | ~100 | role=NONE, phase=lane, cross-skill contracts |
| `dimension.json` | ~100 | 7 probes, exit criteria, severity rules, cache_policy=NEVER |
| `probes/P-QD3-dependency-vuln-scan.md` | ~30 stub | Dependency vulnerability audit |
| `probes/P-QD3-owasp-top-ten.md` | ~30 stub | OWASP Top 10 static analysis |
| `probes/P-QD3-dangerous-deserialize.md` | ~30 stub | Unsafe code evaluation + HTML injection detection |
| `probes/P-QD3-secret-detection.md` | ~30 stub | Hard-coded secrets/credentials scanning |
| `probes/P-QD3-auth-flow-verify.md` | ~30 stub | Authentication/authorization flow verification |
| `probes/P-QD3-cors-policy-check.md` | ~30 stub | CORS configuration review |
| `probes/P-QD3-security-header-audit.md` | ~30 stub | Security headers verification |
| `probes/_shared.md` | ~100 | Cross-probe protocols: NO caching (ADR-22 R6), signal emission |
| `templates/signals.json` | ~20 | Lane signals template |
| `templates/lane-report.md` | ~30 | Lane report template |
| `templates/phase-summary.md` | ~15 | CORE-028 phase summary |
| `evals/evals.json` | ~20 | Empty eval skeleton |

### dimension.json probes

```json
{
  "cache_policy": "NEVER",
  "cache_policy_reason": "ADR-22 Rule 6: QD3 security results must always be fresh",
  "probes": [
    {"id": "P-QD3-dependency-vuln-scan", "type": "static+runtime", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD3-owasp-top-ten", "type": "static", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD3-dangerous-deserialize", "type": "static", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD3-secret-detection", "type": "static", "depth": ["standard","deep","exhaustive"]},
    {"id": "P-QD3-auth-flow-verify", "type": "runtime+agent", "depth": ["standard","deep","exhaustive"]},
    {"id": "P-QD3-cors-policy-check", "type": "runtime", "depth": ["standard","deep","exhaustive"]},
    {"id": "P-QD3-security-header-audit", "type": "runtime", "depth": ["deep","exhaustive"]}
  ]
}
```

### Profile exit criteria

- quick: P-QD3-dependency-vuln-scan + P-QD3-owasp-top-ten + P-QD3-dangerous-deserialize
- standard: quick + P-QD3-secret-detection + P-QD3-auth-flow-verify + P-QD3-cors-policy-check
- deep: standard + P-QD3-security-header-audit
- exhaustive: deep + full penetration test suite

### Severity rules

- CRITICAL: exposed secrets, authentication bypass, SQL/command injection
- HIGH: XSS, CSRF, insecure deserialization
- MEDIUM: missing security headers, overly permissive CORS
- LOW: informational findings

---

## D2: QD4 Performance Lane Skeleton

Create `.claude/skills/workflow/wf-fix-performance/`.

### Files

Same structure as QD3, with:

| File | LOC est |
|------|---------|
| `SKILL.md` | ~300 |
| `_contract.json` | ~90 |
| `dimension.json` | ~90 |
| `probes/P-QD4-bundle-size-audit.md` | ~30 stub |
| `probes/P-QD4-render-perf-check.md` | ~30 stub |
| `probes/P-QD4-api-latency-probe.md` | ~30 stub |
| `probes/P-QD4-db-query-analysis.md` | ~30 stub |
| `probes/P-QD4-memory-leak-scan.md` | ~30 stub |
| `probes/P-QD4-core-web-vitals.md` | ~30 stub |
| `probes/_shared.md` | ~100 |
| `templates/` | ~65 |
| `evals/evals.json` | ~20 |

### dimension.json probes

```json
{
  "probes": [
    {"id": "P-QD4-bundle-size-audit", "type": "static", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD4-render-perf-check", "type": "runtime", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD4-api-latency-probe", "type": "runtime", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD4-db-query-analysis", "type": "static+runtime", "depth": ["standard","deep","exhaustive"]},
    {"id": "P-QD4-memory-leak-scan", "type": "static", "depth": ["standard","deep","exhaustive"]},
    {"id": "P-QD4-core-web-vitals", "type": "runtime", "depth": ["deep","exhaustive"]}
  ]
}
```

### Profile exit criteria

- quick: P-QD4-bundle-size-audit + P-QD4-render-perf-check + P-QD4-api-latency-probe
- standard: quick + P-QD4-db-query-analysis + P-QD4-memory-leak-scan
- deep: standard + P-QD4-core-web-vitals
- exhaustive: deep + stress test + capacity planning

---

## D3: QD5 UX/A11y Lane Skeleton

Create `.claude/skills/workflow/wf-fix-ux-a11y/`.

### Files

| File | LOC est |
|------|---------|
| `SKILL.md` | ~350 |
| `_contract.json` | ~90 |
| `dimension.json` | ~100 |
| `probes/P-QD5-ui-traversal-deep.md` | ~30 stub |
| `probes/P-QD5-label-consistency.md` | ~30 stub |
| `probes/P-QD5-accessibility-check.md` | ~30 stub |
| `probes/P-QD5-color-contrast-audit.md` | ~30 stub |
| `probes/P-QD5-keyboard-nav-check.md` | ~30 stub |
| `probes/P-QD5-responsive-layout.md` | ~30 stub |
| `probes/P-QD5-aria-attribute-scan.md` | ~30 stub |
| `probes/_shared.md` | ~100 |
| `templates/` | ~65 |
| `evals/evals.json` | ~20 |

### dimension.json probes

```json
{
  "probes": [
    {"id": "P-QD5-ui-traversal-deep", "type": "runtime", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD5-label-consistency", "type": "static+runtime", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD5-accessibility-check", "type": "runtime+agent", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD5-color-contrast-audit", "type": "static", "depth": ["standard","deep","exhaustive"]},
    {"id": "P-QD5-keyboard-nav-check", "type": "runtime", "depth": ["standard","deep","exhaustive"]},
    {"id": "P-QD5-responsive-layout", "type": "runtime", "depth": ["deep","exhaustive"]},
    {"id": "P-QD5-aria-attribute-scan", "type": "static", "depth": ["standard","deep","exhaustive"]}
  ]
}
```

### Profile exit criteria

- quick: P-QD5-ui-traversal-deep + P-QD5-label-consistency + P-QD5-accessibility-check
- standard: quick + P-QD5-color-contrast-audit + P-QD5-keyboard-nav-check + P-QD5-aria-attribute-scan
- deep: standard + P-QD5-responsive-layout
- exhaustive: deep + multi-device + cross-browser Playwright matrix

---

## D4: QD6 Data Integrity Lane Skeleton

Create `.claude/skills/workflow/wf-fix-data/`.

### Files

| File | LOC est |
|------|---------|
| `SKILL.md` | ~300 |
| `_contract.json` | ~90 |
| `dimension.json` | ~90 |
| `probes/P-QD6-schema-drift-detect.md` | ~30 stub |
| `probes/P-QD6-migration-integrity.md` | ~30 stub |
| `probes/P-QD6-constraint-violation.md` | ~30 stub |
| `probes/P-QD6-data-type-mismatch.md` | ~30 stub |
| `probes/P-QD6-orm-model-sync.md` | ~30 stub |
| `probes/P-QD6-seed-data-audit.md` | ~30 stub |
| `probes/_shared.md` | ~100 |
| `templates/` | ~65 |
| `evals/evals.json` | ~20 |

### dimension.json probes

```json
{
  "probes": [
    {"id": "P-QD6-schema-drift-detect", "type": "static+runtime", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD6-migration-integrity", "type": "static", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD6-constraint-violation", "type": "runtime", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD6-data-type-mismatch", "type": "static", "depth": ["standard","deep","exhaustive"]},
    {"id": "P-QD6-orm-model-sync", "type": "static", "depth": ["standard","deep","exhaustive"]},
    {"id": "P-QD6-seed-data-audit", "type": "static", "depth": ["deep","exhaustive"]}
  ]
}
```

### Profile exit criteria

- quick: P-QD6-schema-drift-detect + P-QD6-migration-integrity + P-QD6-constraint-violation
- standard: quick + P-QD6-data-type-mismatch + P-QD6-orm-model-sync
- deep: standard + P-QD6-seed-data-audit
- exhaustive: deep + full data integrity test suite + referential integrity check

---

## D5: QD7 Compatibility Lane Skeleton

Create `.claude/skills/workflow/wf-fix-compat/`.

### Files

| File | LOC est |
|------|---------|
| `SKILL.md` | ~280 |
| `_contract.json` | ~90 |
| `dimension.json` | ~80 |
| `probes/P-QD7-browser-compat-check.md` | ~30 stub |
| `probes/P-QD7-api-version-compat.md` | ~30 stub |
| `probes/P-QD7-deprecated-api-usage.md` | ~30 stub |
| `probes/P-QD7-polyfill-coverage.md` | ~30 stub |
| `probes/P-QD7-device-breakpoint-test.md` | ~30 stub |
| `probes/_shared.md` | ~100 |
| `templates/` | ~65 |
| `evals/evals.json` | ~20 |

### dimension.json probes

```json
{
  "probes": [
    {"id": "P-QD7-browser-compat-check", "type": "static+runtime", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD7-api-version-compat", "type": "static+runtime", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD7-deprecated-api-usage", "type": "static", "depth": ["quick","standard","deep","exhaustive"]},
    {"id": "P-QD7-polyfill-coverage", "type": "static", "depth": ["standard","deep","exhaustive"]},
    {"id": "P-QD7-device-breakpoint-test", "type": "runtime", "depth": ["deep","exhaustive"]}
  ]
}
```

### Profile exit criteria

- quick: P-QD7-browser-compat-check + P-QD7-api-version-compat + P-QD7-deprecated-api-usage
- standard: quick + P-QD7-polyfill-coverage
- deep: standard + P-QD7-device-breakpoint-test
- exhaustive: deep + full Playwright device matrix + browser stack

---

## D6: QD3 Probe Implementation

Implement 4 priority QD3 probes (NO caching per ADR-22 Rule 6).

### Probes to implement

1. **P-QD3-dependency-vuln-scan** (~120 LOC)
   - Sense: Read `package.json` / `requirements.txt` / `go.mod` / `pom.xml` → extract dependencies
   - Think: Compare versions against known vulnerability databases (npm audit, pip audit, etc.)
   - Act: Run audit command, parse output, emit Signals for vulnerable deps
   - Verify: Each Signal has `evidence.log_excerpt` with CVE reference
   - **NO Scan Cache** (ADR-22 R6)

2. **P-QD3-owasp-top-ten** (~120 LOC)
   - Sense: Grep source code for OWASP Top 10 patterns:
     - Injection patterns (concatenated queries, shell commands)
     - Broken auth patterns (missing session validation)
     - Sensitive data exposure (logging sensitive fields)
     - XML external entities
     - Broken access control (missing role checks)
   - Think: Classify by OWASP category, assess exploitability
   - Act: Emit Signals with OWASP category in metadata
   - Verify: Each Signal has `evidence.code_snippet` + OWASP category
   - **NO Scan Cache** (ADR-22 R6)

3. **P-QD3-dangerous-deserialize** (~100 LOC)
   - Sense: Grep for unsafe code patterns — unsafe HTML injection props in React, dynamic code execution functions, JSON parse without validation, object deserialization from untrusted input
   - Think: Classify by risk level, check if input is sanitized before use
   - Act: Emit Signals for unsanitized dangerous patterns
   - Verify: Each Signal has `evidence.code_snippet` showing the pattern
   - **NO Scan Cache** (ADR-22 R6)

4. **P-QD3-secret-detection** (~100 LOC)
   - Sense: Grep for hard-coded secrets — API keys, database passwords, JWT secrets, private keys, tokens in source code
   - Think: Validate against environment variable usage, filter known false positives (test fixtures, docs)
   - Act: Emit CRITICAL Signals for exposed secrets
   - Verify: Each Signal has `evidence.code_snippet` (masked partial content)
   - **NO Scan Cache** (ADR-22 R6)

### probes/_shared.md for QD3

Key differences from QD1/QD2 `_shared.md`:
- **Cache section**: Override with "QD3 does NOT use Scan Cache (ADR-22 Rule 6). All probes must re-scan every time."
- **Severity mapping**: CRITICAL for exposed secrets/auth bypass, HIGH for injection/XSS, MEDIUM for misconfig, LOW for info
- **Signal metadata**: Include `owasp_category` field in signals where applicable

---

## D7: QD4 Probe Implementation

Implement 3 priority QD4 probes.

1. **P-QD4-bundle-size-audit** (~100 LOC)
   - Sense: Read build config (webpack/vite/rollup), check bundle output files
   - Think: Compare sizes against thresholds (total < 500KB, chunk < 200KB, asset < 100KB)
   - Act: Emit Signals for oversized bundles/chunks
   - Wire Scan Cache for static bundle analysis
   - Verify: Each Signal has `evidence.code_snippet` or `evidence.log_excerpt`

2. **P-QD4-api-latency-probe** (~100 LOC)
   - Sense: Read API routes from phase3-architecture/, hit each endpoint
   - Think: Measure response time, compare against thresholds (p95 < 500ms for CRUD, < 2s for reports)
   - Act: Emit Signals for slow endpoints with `evidence.log_excerpt`
   - No caching (runtime probe)
   - Verify: Latency measurements are reproducible (±10%)

3. **P-QD4-db-query-analysis** (~120 LOC)
   - Sense: Grep ORM query patterns (N+1, missing indexes, SELECT *)
   - Think: Cross-ref with schema from phase3-architecture/
   - Act: Emit Signals for potential query performance issues
   - Wire Scan Cache for static query pattern analysis
   - Verify: Each Signal has `evidence.code_snippet` with the query pattern

---

## D8: QD5-QD7 Probe Implementation (Priority Probes Only)

Implement top 2 probes per lane.

### QD5 (wf-fix-ux-a11y)

1. **P-QD5-label-consistency** (~100 LOC)
   - Sense: Extract labels from UI components (React/Vue/Angular), read Navigation specs from phase4-ux/
   - Think: Cross-ref UI labels with Navigation spec labels, detect mismatches
   - Act: Emit Signals for inconsistent labels
   - Wire Scan Cache for static label extraction
   - Verify: Each Signal has `evidence.code_snippet` + `evidence.spec_ref`

2. **P-QD5-accessibility-check** (~120 LOC)
   - Sense: Spawn accessibility-auditor agent with page/component context
   - Think: Agent reviews WCAG 2.2 compliance (color contrast, alt text, ARIA labels, keyboard nav)
   - Act: Convert agent findings to signals
   - CORE-029: Validate agent output schema before emission
   - Verify: Each Signal has WCAG criterion reference

### QD6 (wf-fix-data)

1. **P-QD6-schema-drift-detect** (~120 LOC)
   - Sense: Read DB schema from phase3-architecture/, compare with ORM models / migration files
   - Think: Identify columns/tables in code but not in schema, or vice versa
   - Act: Emit Signals for schema drift
   - Wire Scan Cache for static schema comparison
   - Verify: Each Signal has both `evidence.code_snippet` (model) and `evidence.spec_ref` (schema doc)

2. **P-QD6-migration-integrity** (~100 LOC)
   - Sense: Grep migration files for up/down pairs, check sequential ordering
   - Think: Verify each migration has reversible down(), no gaps in sequence numbers
   - Act: Emit Signals for broken migration chains
   - Wire Scan Cache
   - Verify: Each Signal identifies the specific migration file issue

### QD7 (wf-fix-compat)

1. **P-QD7-deprecated-api-usage** (~100 LOC)
   - Sense: Grep for deprecated API calls in source code
   - Think: Cross-ref with API changelog/breaking changes from phase3-architecture/
   - Act: Emit Signals for deprecated API usage
   - Wire Scan Cache
   - Verify: Each Signal has deprecation notice reference

2. **P-QD7-api-version-compat** (~100 LOC)
   - Sense: Read API version headers/paths from code, compare with version policy
   - Think: Check if all API endpoints follow versioning convention
   - Act: Emit Signals for unversioned or mismatched API endpoints
   - Wire Scan Cache
   - Verify: Each Signal identifies the endpoint and expected vs actual version

---

## D9: Integration Tests + Golden Fixture Extension

### Extend golden fixture

Add to `_shared/tests/fixtures/sample-project/`:

| File | Purpose | Known issues |
|------|---------|-------------|
| `src/features/customer/service.ts` | (existing) | Add: SQL injection pattern, missing auth check |
| `src/db/migrations/001-create-customer.sql` | Migration file | Missing down(), non-sequential |
| `src/db/models/customer.model.ts` | ORM model | Schema drift: extra column not in migration |
| `src/api/customer.controller.ts` | API controller | Missing version header, deprecated endpoint |
| `.env.example` | Env template | Document required env vars (for secret-detection false positive test) |

### Known issues per dimension

| Issue | Dimension | Probe | Severity |
|-------|-----------|-------|----------|
| SQL concatenation in query | QD3 | P-QD3-owasp-top-ten | HIGH |
| Missing auth middleware on endpoint | QD3 | P-QD3-auth-flow-verify | CRITICAL |
| Hard-coded API key in service.ts | QD3 | P-QD3-secret-detection | CRITICAL |
| Bundle chunk > 300KB (simulated) | QD4 | P-QD4-bundle-size-audit | MEDIUM |
| N+1 query pattern in customer listing | QD4 | P-QD4-db-query-analysis | MEDIUM |
| Missing alt text on icon button | QD5 | P-QD5-accessibility-check | HIGH |
| Label mismatch: "Save" vs "Submit" | QD5 | P-QD5-label-consistency | LOW |
| Schema drift: extra column `nickname` | QD6 | P-QD6-schema-drift-detect | HIGH |
| Migration missing down() function | QD6 | P-QD6-migration-integrity | HIGH |
| Deprecated API call: `/api/v1/...` | QD7 | P-QD7-deprecated-api-usage | MEDIUM |
| Unversioned endpoint: `/api/customer/...` | QD7 | P-QD7-api-version-compat | MEDIUM |

### Test file

`.claude/skills/workflow/_shared/tests/test_e2e_qd3_qd7.py` (~500 LOC)

### Test cases

1. **TestQD3NoCache** (3 tests) — Verify QD3 dimension.json has cache_policy=NEVER, probes don't call Scan Cache, second scan produces fresh results
2. **TestQD3SecurityProbes** (3 tests) — owasp-top-ten detects SQL injection, secret-detection finds API key, dangerous-deserialize finds unsafe patterns
3. **TestQD4PerformanceProbes** (3 tests) — bundle-size threshold check, db-query N+1 detection, api-latency measurement
4. **TestQD5UxA11yProbes** (2 tests) — label-consistency cross-ref, accessibility-check agent invocation (mocked)
5. **TestQD6DataProbes** (2 tests) — schema-drift between model and migration, migration integrity check
6. **TestQD7CompatProbes** (2 tests) — deprecated API detection, version mismatch detection
7. **TestCrossLaneDedup** (2 tests) — Same file+line produces separate issues per dimension; 3+ dimensions merge correctly
8. **TestParallelAllLanes** (1 test) — All 7 lanes write to isolated dirs without conflict
9. **TestGoldenFixtureExtended** (3 tests) — All 11 known issues detected, no false positives, severity distribution correct
10. **TestPostGateAllLanes** (2 tests) — T1-T4 for QD3-QD7 signals.json
11. **TestDimensionManifestAll** (3 tests) — Probe IDs match patterns, all probe files exist, profile exit criteria for all 5 lanes

---

## D10: D Review Report + CI Update

### CI Update

Update `.github/workflows/wf-fix-bugs-ci.yml` path filters to add:
- `.claude/skills/workflow/wf-fix-security/**`
- `.claude/skills/workflow/wf-fix-performance/**`
- `.claude/skills/workflow/wf-fix-ux-a11y/**`
- `.claude/skills/workflow/wf-fix-data/**`
- `.claude/skills/workflow/wf-fix-compat/**`

### Review Report

`docs/design/skills/wf-fix-bugs/reviews/D-review-20260421.md`

### Content
- Summary: 5 new lanes, ~2,500 LOC estimated
- File manifest per lane
- Test results + coverage
- Migration mapping for remaining probes
- Acceptance criteria checklist (adapted from C review)
- ADR-22 compliance verification (especially Rule 6 for QD3)
- Recommendations for Stage E (orchestrator integration + lane dispatch)

---

## Execution Order

```
D1 → D2 → D3 → D4 → D5  (skeletons — sequential but fast)
     ↓
D6 (QD3 probes — highest priority, NO cache)
     ↓
D7 (QD4 probes)
     ↓
D8 (QD5-QD7 probes — 2 per lane)
     ↓
D9 (integration tests + golden fixture)
     ↓
D10 (review + CI)
```

CORE-025: D1-D5 skeletons have isolated write scopes (separate directories). D6-D8 implementations touch separate probe files.

---

## Acceptance Criteria

| # | Criteria | Target |
|---|----------|--------|
| 1 | QD3 coverage >=80% vs design doc probes | 4/7 probes fleshed out |
| 2 | QD4 coverage >=80% vs design doc probes | 3/6 probes fleshed out |
| 3 | QD5-QD7 each >=2 probes fleshed out | 2 probes per lane = 6 total |
| 4 | QD3 NEVER cache (ADR-22 Rule 6) | Verified in tests |
| 5 | Signal Bus dedup across 7 dimensions | Test coverage |
| 6 | False positive rate <15% | Golden fixture: 11 known issues → 11 signals |
| 7 | POST-GATE T1-T4 pass for all lanes | Test coverage |
| 8 | Coverage gate 80% | All existing + new tests pass |
| 9 | CI pipeline pass | All path filters updated |
| 10 | CORE-028 phase summary ≤15 lines | All lanes |
| 11 | CORE-031 template usage | All outputs |
| 12 | Total test count >=400 | ~80 new tests |
| 13 | All 5 lanes run in parallel safely | CORE-025 verified |

---

## Verification (End-to-End)

1. `ls -la .claude/skills/workflow/wf-fix-security/` — all files present
2. `ls -la .claude/skills/workflow/wf-fix-performance/` — all files present
3. `ls -la .claude/skills/workflow/wf-fix-ux-a11y/` — all files present
4. `ls -la .claude/skills/workflow/wf-fix-data/` — all files present
5. `ls -la .claude/skills/workflow/wf-fix-compat/` — all files present
6. `jq '.' dimension.json` — valid for each lane
7. `pytest _shared/tests/ -v --tb=short` — all tests pass
8. Coverage gate: `pytest --cov=_shared --cov-fail-under=80`
9. CI: `.github/workflows/wf-fix-bugs-ci.yml` includes all 5 new lanes
10. QD3 `_shared.md` explicitly states NO cache (ADR-22 Rule 6)
