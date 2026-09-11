# 10 — Improvement Roadmap

> **Status:** 🔒 **LOCKED (G2 — Phiên 42, 2026-05-09)**. Tất cả 26 global IMPs (+ 1 infra) có `evidence_status: verified`. 0 tentative còn lại. Gate G2 ✅ PASS.
> **Format:** YAML frontmatter per IMP (DEC-005) — vừa human-readable vừa machine-parseable bằng `yq`.
> **Gate G2 đạt:** Tất cả IMP ∈ {verified, dropped}. 26 verified global IMPs ≥ 15 yêu cầu. Stage 3 có thể bắt đầu.

## Cấu trúc roadmap (3 sections)

- **Section C — Infrastructure Pre-requisites:** Adapter framework, scaffolding cần build trước IMP impl. ✅ DONE (Stage 0).
- **Section A — Verified IMPs:** Có file:line evidence từ Stage 1 audit (QD1-QD7) → ready for Stage 3 impl.
- **Section B — Tentative IMPs:** ✅ **EMPTY** — tất cả tentative IMPs đã được promoted sang Section A với Stage 1 evidence.

## YAML frontmatter chuẩn (DEC-005)

```yaml
---
id: IMP-NNN
title: ...
priority: P0|P1|P2|P3
effort: XS|S|M|L|XL
owner: skill-author|agent-author|domain-expert|user
evidence_status: verified|tentative|inferred|dropped
affected_probes: [...]
gate: G0|G1|G2|G3
acceptance_test: <path>
dependencies: [IMP-..., ...]
cross_skill_impact: []
notes: ...
---
```

Semantic chi tiết: xem [13-definition-of-done.md §IMP DoD](./13-definition-of-done.md).

---

# Section C — Infrastructure Pre-requisites ✅ DONE (Stage 0)

> Build TRƯỚC IMP-001/003/010/022/025. ✅ Hoàn thành Stage 0 (47/47 smoke tests pass).

## IMP-000: Adapter Framework Scaffolding

```yaml
---
id: IMP-000
title: Build adapter framework cho stack/PM/ORM detection + dispatcher
priority: P0
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-route-config-parse, P-QD3-dependency-vuln-scan, P-QD4-db-query-analysis, P-QD6-orm-model-sync, P-QD6-migration-integrity]
gate: G0
acceptance_test: .claude/skills/workflow/_shared/adapters/tests/
dependencies: []
cross_skill_impact: []
notes: |
  ✅ IMPLEMENTED (Stage 0, Phiên 1). 47/47 smoke tests pass.
  Cấu trúc: .claude/skills/workflow/_shared/adapters/
    ├── README.md
    ├── _dispatcher.sh   # Detect stack/PM/ORM, route adapter
    ├── stack/           # node.sh, dotnet.sh, java.sh, python.sh, go.sh
    ├── package-manager/ # npm.sh, pip.sh, nuget.sh, maven.sh, go-mod.sh
    └── orm/             # prisma.sh, ef-core.sh, sqlalchemy.sh, hibernate.sh, ...
  Đơn giản hoá IMP-001/003/010 thành "thêm adapter file" thay vì refactor probe.
---
```

---

# Section A — Verified IMPs

> Tất cả IMPs có `evidence_status: verified` từ Stage 1 audit (QD1-QD7 Phase 1-5). Ready for Stage 3.

## P0 — Blocker (Critical)

### IMP-001: Multi-stack route detection

```yaml
---
id: IMP-001
title: Bổ sung .NET/Java/Python/Go route detection vào P-QD1-route-config-parse
priority: P0
effort: L
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-route-config-parse, P-QD1-api-smoke]
gate: G2
acceptance_test: fixtures/qd1-test/positive/case-multi-stack/
dependencies: [IMP-000]
cross_skill_impact: []
notes: |
  Evidence: P-QD1-route-config-parse.md:17-28 chỉ có Express/NestJS/Next.js patterns.
  Stage 1 QD1 Phase 2 fixture pos-03: .NET missed 100% (FN-001).
  Stage 1 Theme 1 (5 dims): EUREKA-2026 ASP.NET Core = 0% route detection.
  Note EUREKA-2026 priority: .NET 9 backend → IMP-001 ASP.NET Core adapter P0.
  Acceptance:
  - Detect routes ASP.NET Core ([HttpGet], [Route], Minimal API .MapGet())
  - Detect routes Spring Boot (@GetMapping, @RequestMapping)
  - Detect routes Django (urlpatterns, path(...))
  - Detect routes FastAPI (@app.get, @router.get)
  - Test fixture có 4 stacks → emit signals đúng
  Workaround: dùng adapter framework IMP-000.
---
```

### IMP-002: i18n CTA dictionary (expanded scope)

```yaml
---
id: IMP-002
title: i18n CTA dictionary (VI/EN/JP/ZH) + locale-aware probe + QD5 i18n skip + QD7 i18n probe
priority: P0
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-deep-ui-traversal, P-QD5-label-consistency, P-QD7-i18n-locale-check]
gate: G2
acceptance_test: fixtures/qd1-test/positive/case-vi-cta/
dependencies: []
cross_skill_impact: [wf-brainstorm]
notes: |
  Evidence: P-QD1-deep-ui-traversal.md:73 hardcoded EN-only CTA list → app Việt = 0% CTA detect.
  Stage 1 Theme 3 (3 dims — QD1/QD5/QD7):
  - QD5 IMP-QD5-012: label-consistency massive FP khi app có i18n message files (QD5 Stage 1 §4 FP-05)
  - QD7 IMP-QD7-009: no i18n locale probe — Date(), currency, locale strings = 0% detect (QD7 Phase 1 D-005)
  Cross-dim merge: IMP-QD1-002 + IMP-QD5-012 + IMP-QD7-009 → 1 global IMP-002.
  CROSS-SKILL IMPACT: Cần thêm field `project.locale` vào req-registry.json.
  Đây là CORE-006 Registry Safe-Write contract change → coordinate với wf-brainstorm (PRIMARY owner).
  
  Acceptance (3 components):
  [QD1] File _shared/locales/{en,vi,ja,zh}/cta-keywords.json
  [QD1] Probe đọc locale từ registry (default: en); app Việt → CTA detection ≥ 80%
  [QD5] label-consistency detect i18n message files (.json, .po) → skip orphan check + emit INFO
  [QD7] Thêm P-QD7-i18n-locale-check: grep hardcoded Date(), currency symbols, locale strings
---
```

### IMP-003: Multi-PM dependency vuln scan

```yaml
---
id: IMP-003
title: Multi-package-manager dependency vuln scan
priority: P0
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [P-QD3-dependency-vuln-scan]
gate: G2
acceptance_test: fixtures/qd3-test/positive/case-multi-pm/
dependencies: [IMP-000]
cross_skill_impact: []
notes: |
  Evidence: Stage 1 Theme 1 (5 dims). QD3 Phase 2: probe assume npm only.
  QD3 Phase 3 P=0.83 confirms npm-only scope → miss .NET/Python/Java deps.
  Acceptance:
  - Support npm, yarn, pnpm, pip-audit, dotnet list package --vulnerable, mvn dependency-check
  - Detect PM từ lockfile (package-lock.json, requirements.txt, *.csproj, pom.xml)
  - Tools may not be installed → graceful skip với SPEC-ONLY-PROBE-SKIP signal
---
```

### IMP-022: Signal Schema Unification (global) [NEW]

```yaml
---
id: IMP-022
title: Unify signal-v2 schema — lane-to-bus translator/adapter (P0 orchestration fix)
priority: P0
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [all dimensions — aggregation layer]
gate: G2
acceptance_test: fixtures/signal-schema-test/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence: Stage 1 Theme 8 (4 dims: QD1/QD2/QD3/QD6) — dual signal-v2 schema fork P0.
  Cross-dim merge: IMP-QD1-007 + IMP-QD2-006 + IMP-QD3-006 + IMP-QD6-009.
  Root cause: lane bash output uses `severity`, `location`, `evidence: [array]`, fingerprint 5-6 tokens
             vs bus schema `suggested_severity`, `target`, `evidence: {dict}`, `dedup_hints`, `emitted_at`.
  Impact: Signal.from_dict() → ValueError khi lane signals feed bus → orchestrator aggregate fails ALL lanes.
  Approach A (recommended): lane-to-bus.py translator tại aggregation step (less invasive).
  Canonical fingerprint: 5-token {probe_id|file_path|line_start|issue_class|dim} — unified across bash+spec.
  Acceptance:
  - lane-to-bus.py: severity→suggested_severity, location→target, evidence[]→evidence{}, fingerprint→dedup_hints
  - Canonical 5-token fingerprint enforced across all 7 dims bash + probe specs
  - All 7 dims: lane→bus schema conversion pass (no ValueError)
  - PRE-GATE schema contract validation added (catch future drift)
---
```

### IMP-024: CDG Canonical Pattern (global) [NEW]

```yaml
---
id: IMP-024
title: CDG governance canonical pattern — fix DATA LOSS RISK + all dim CDG gaps
priority: P0
effort: L
owner: skill-author
evidence_status: verified
affected_probes: [P-QD3-secret-detection+auth-flow+sql-injection, P-QD4-api-latency+db-query+cwv, P-QD5-keyboard-nav+wcag-a, P-QD6-migration-integrity, P-QD7-api-version-compat]
gate: G2
acceptance_test: fixtures/qd6-test/positive/case-drop-table-cdg/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence: Stage 1 Theme 9 (5 dims: QD3 partial / QD4 broken / QD5 missing / QD6 triple-blocked / QD7 missing).
  Cross-dim merge: IMP-QD3-003 + IMP-QD4-005 + IMP-QD5-003 + IMP-QD6-001 + IMP-QD7-001/007.
  **CRITICAL DATA LOSS RISK:** QD6 migration-integrity DROP TABLE → auto-fix không cần CDG approval.
  CDG canonical rule: per-probe `cdg_flags` in probe spec wins over dimension.json `cdg` gate.
  Implementation phases:
  - Phase 1 (P0 CRITICAL first — 3 file edits):
      dim.json: cdg=true for QD6 migration-integrity
      probe spec: cdg_triggers add CDG-DELETE-DATA
      bash: EMIT() calls pass cdg_flags=["CDG-DELETE-DATA"] (IMP-QD6-001 D11 wf-fix-probe-static-data.sh:79)
  - Phase 2: _shared/cdg-canonical.md + per-probe CDG spec template
  - Phase 3: Wire QD3 (6 probes auth bypass+SQL+deser+cors+headers+deps), QD4 (3: api-latency+db+cwv), QD5 (keyboard trap+WCAG A), QD7 (api-version breaking change)
  - Phase 4: CDG dedup key {file_path, session_id} — fire CDG once per file (IMP-QD3-012)
  Acceptance:
  - QD6 DROP TABLE → CDG-DELETE-DATA fires, user must approve before auto-fix
  - QD3 SQL injection → CDG-SECURITY-LIVE fires
  - QD4 dim.json cdg=true for api-latency/db-query/cwv probes
  - QD5 keyboard trap → CDG-A11Y-CRITICAL fires
  - All 7 dims: no CDG contradiction between dim.json and probe spec
---
```

### IMP-025: Bash Dispatch Standardization (global) [NEW]

```yaml
---
id: IMP-025
title: Add case "$PROBE_ID" dispatch to QD2/QD4/QD6 bash scripts (fix phantom PROBE_IDs)
priority: P0
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [all QD2/QD4/QD6 bash probes]
gate: G2
acceptance_test: fixtures/qd2-test/positive/case-probe-dispatch/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence: Stage 1 Theme 10 (3 dims: QD2/QD4/QD6) — bash dispatch missing P0.
  Cross-dim merge: IMP-QD2-001 + IMP-QD4-010 + IMP-QD6-010/011.
  QD2: PROBE_ID="P-QD2-business-logic-audit" phantom (not in dimension.json) → static layer INVISIBLE to orchestrator.
  QD6: PROBE_ID="P-QD6-data-integrity-audit" phantom → 6× invocations × 3 checks = 18 signals (wrong) per session.
  QD4: hybrid architecture, inconsistent dispatch.
  Reference: QD3 bash uses correct `case "$PROBE_ID"` dispatch — copy pattern to QD2/QD4/QD6.
  Acceptance:
  - QD2/QD4/QD6 bash: `case "$PROBE_ID"` dispatch block routing to correct check per probe
  - Unknown PROBE_ID → fail-fast with clear error (exit 1)
  - Phantom PROBE_ID linter added to validate-schema-sync.sh
  - QD2: static layer signals visible in orchestrator output
  - QD6: signal count = 3 per session (not 18)
---
```

---

## P1 — High Priority

### IMP-004: Configurable thresholds

```yaml
---
id: IMP-004
title: Move hardcoded thresholds vào _shared/profiles.json + flag override
priority: P1
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-deep-ui-traversal, P-QD1-infra-preflight, P-QD1-api-smoke, P-QD4-bundle-size-audit, P-QD4-api-latency-probe, P-QD5-color-contrast-audit]
gate: G2
acceptance_test: fixtures/qd1-test/positive/case-large-module/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence: Stage 1 Theme 2 (4 dims: QD1/QD4/QD5/QD7).
  3-way mismatch confirmed: QD4 DISCREPANCY-3 (dim.json 200KB / probe 500KB=MEDIUM 1000KB=HIGH / SKILL.md "gzip ambiguous").
  QD4 dim.json missing 3 CWV critical_triggers (DISCREPANCY-8).
  QD7 api-version severity_default CRITICAL overaggressive (IMP-QD7-004).
  Rule: probe spec wins per-threshold (canonical source).
  Acceptance:
  - profiles.json `thresholds` section per profile (quick/standard/deep/exhaustive)
  - Override: --threshold-overrides='{"max_pages":100}'
  - QD4 bundle canonical: probe spec (500KB/1000KB) → update dim.json+SKILL.md to match
  - QD7 api-version severity_default → HIGH (not CRITICAL)
---
```

### IMP-005: MAX_PAGES scale theo profile

```yaml
---
id: IMP-005
title: MAX_PAGES theo profile (quick=10, standard=30, deep=100, exhaustive=300)
priority: P1
effort: XS
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-deep-ui-traversal]
gate: G2
acceptance_test: fixtures/qd1-test/positive/case-large-module/
dependencies: [IMP-004]
cross_skill_impact: []
notes: |
  Evidence: P-QD1-deep-ui-traversal.md:100 + Stage 1 QD1 FN-004 (MAX_PAGES=20 hardcoded → miss 75% ERP).
  Module > limit → log warning (WARN) + truncate.
---
```

### IMP-006: Auth-aware api-smoke

```yaml
---
id: IMP-006
title: Auth-aware api-smoke (credentials, retry với token)
priority: P1
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-api-smoke]
gate: G2
acceptance_test: fixtures/qd1-test/positive/case-protected-api/
dependencies: [IMP-001]
cross_skill_impact: []
notes: |
  Evidence: Stage 1 QD1 EC-004 (401/403 bị flag là api_error). Theme 1 auth gaps QD3.
  Acceptance:
  - Probe nhận credentials từ orchestrator (env hoặc .mc-data/work/wf-fix-bugs/auth.json)
  - Login flow OAuth/JWT/Session, lưu token
  - Retry với token nếu lần đầu 401
  - 3 auth schemes: bearer, cookie, API key header
---
```

### IMP-007: Retry logic cho infra-preflight

```yaml
---
id: IMP-007
title: Retry logic 3×5s cho infra-preflight tránh false CRITICAL khi cold start
priority: P1
effort: XS
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-infra-preflight]
gate: G2
acceptance_test: fixtures/qd1-test/positive/case-cold-start/
dependencies: [IMP-004]
cross_skill_impact: []
notes: |
  Evidence: Stage 1 QD1 FP-005 (cold start timeout). Theme 2 curl timeout 10s hardcoded.
  Configurable: --infra-retry-count (default 3), --infra-retry-interval (default 5s).
---
```

### IMP-009: Multi-locale form fill

```yaml
---
id: IMP-009
title: Multi-locale form fill respect HTML5 input pattern
priority: P1
effort: S
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-deep-ui-traversal]
gate: G2
acceptance_test: fixtures/qd1-test/positive/case-vat-phone-vn/
dependencies: [IMP-002]
cross_skill_impact: []
notes: |
  Evidence: Stage 1 QD1 i18n bias section (form fill defaults EN). Theme 3 i18n (QD1/QD5/QD7).
  Acceptance:
  - Đọc HTML5 input pattern attribute
  - Generate fill data theo pattern (VAT regex, phone VN, email)
  - Fixture form custom validation → fill pass
---
```

### IMP-010: ORM adapter pattern [PROMOTED từ Section B]

```yaml
---
id: IMP-010
title: ORM adapter cho Prisma/TypeORM/Sequelize/EF Core/SQLAlchemy/Hibernate
priority: P1
effort: L
owner: skill-author
evidence_status: verified
affected_probes: [P-QD4-db-query-analysis, P-QD6-orm-model-sync, P-QD6-migration-integrity]
gate: G2
acceptance_test: fixtures/qd6-test/positive/case-multi-orm/
dependencies: [IMP-000]
cross_skill_impact: []
notes: |
  Evidence Stage 1 (QD6 Phase 2 + QD4 Phase 2):
  - QD6 IMP-QD6-005 §6.1: stack matrix 4/11 ORM stacks supported (Prisma partial ✅, TypeORM partial ✅, EF Core partial ✅, 7 others ❌ = 64% unsupported)
  - QD4 Phase 2: db-query-analysis SPEC-ONLY for non-Prisma/TypeORM stacks
  - Theme 1 (5 dims): QD6 data integrity check silent miss cho 64% ORM stacks
  EUREKA-2026 priority: .NET 9 EF Core → ef-core.sh adapter P1 first.
  Acceptance:
  - ORM adapters: Prisma (complete), TypeORM (complete), EF Core (complete), SQLAlchemy, Hibernate
  - Detect ORM từ lockfile/csproj/pom.xml via IMP-000 dispatcher
  - QD4 db-query-analysis route to correct ORM adapter
---
```

### IMP-021: Execution Order DAG (global) [NEW]

```yaml
---
id: IMP-021
title: Add execution_order/parallel_groups to all 7 dimension.json files (global DAG fix)
priority: P1
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [all 7 dimensions]
gate: G2
acceptance_test: fixtures/dim-exec-order-test/
dependencies: [IMP-011]
cross_skill_impact: []
notes: |
  Evidence: Stage 1 Theme 5 — execution_order 7/7 dims (STRONGEST cross-dim evidence).
  Cross-dim merge: IMP-QD1-008 + IMP-QD2-007 + IMP-QD3-009 + IMP-QD4-004/011/012 + IMP-QD5-013 + IMP-QD6-015 + IMP-QD7-002.
  Quantified savings: QD3 375s→195s (-48%), QD5 280s→168s (-40%), QD6 285s→135s (-53%), QD7 36s→12s (-67%).
  Reference design: QD4 (most complex parallel_groups — Playwright concurrency blast fix IMP-QD4-004).
  Approach: add `execution_order` + `parallel_groups` to each dimension.json; dispatcher uses topological sort.
  Acceptance:
  - All 7 dimension.json have `execution_order` and `parallel_groups` fields
  - Dispatcher respects ordering (static-before-agent, infra-preflight-before-ui-traversal)
  - CASCADE-QD4-001 (Playwright concurrency blast P2r ∥ P6) non-reproducible after fix
  - Deep profile scan time reduced ≥ 40% on reference fixture (any dim)
  - Cycle detection: dim.json with circular deps → validation error at load time
---
```

---

## P2 — Medium Priority

### IMP-008: Strengthen schema validation (CORE-029)

```yaml
---
id: IMP-008
title: Strengthen CORE-029 spot-check (description min length, file path validation, severity consistency)
priority: P2
effort: S
owner: skill-author
evidence_status: verified
affected_probes: [all]
gate: G2
acceptance_test: fixtures/qd1-test/negative/case-spotcheck-validation/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence: Stage 1 Theme 4 (3 dims: QD1/QD2/QD6).
  QD2 D1: description inconsistency 20 chars (probe spec) vs 50 chars (SKILL.md) → signals lost.
  QD2 D10 bash line 78: EMIT() `description: "Line N"` — no code_snippet → T3.6 semantic FAIL.
  QD6 D11 wf-fix-probe-static-data.sh:79: EMIT() cdg_flags:[] hardcoded → CDG-DELETE-DATA not set.
  Canonical: description ≥ 50 chars per SKILL.md (update probe specs to match).
  Acceptance:
  - description min 50 chars (canonical SKILL.md value — update probe specs)
  - evidence.file_path validation (exists on disk)
  - severity consistency check vs severity_rules in dim.json
  - confidence range [0.0, 1.0] enforced
  - code_snippet required in EMIT() (not just line number)
  - sample size = min(10, total * 0.1) instead of hardcode 3
  - --probe arg validates vs valid probe list (fail-fast on phantom)
---
```

### IMP-011: Cross-probe DAG explicit [PROMOTED từ Section B — scope refined]

```yaml
---
id: IMP-011
title: File _shared/lane/probe-dag.json declarative probe dependencies
priority: P2
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [all]
gate: G2
acceptance_test: fixtures/qd1-test/advanced/case-cascade-skip/
dependencies: [IMP-021]
cross_skill_impact: []
notes: |
  Evidence Stage 1: Theme 5 execution_order 7/7 dims (IMP-QD1-008, QD2-007, QD3-009, QD4-004/011/012, QD5-013, QD6-015, QD7-002).
  Note: IMP-021 (global) adds execution_order fields TO dimension.json (static config).
        IMP-011 (this IMP) creates probe-dag.json as CANONICAL SOURCE OF TRUTH for complex ordering + cycle detection.
  Scope: declarative probe-dag.json listing all inter-probe dependencies across all dims + cycle detection.
  Acceptance:
  - _shared/lane/probe-dag.json với all-dim probe dependency graph
  - Dispatcher: load probe-dag.json → topological sort → respect order
  - Cycle detection at load time → validation error
  - Case: infra-preflight fail → api-smoke skip (CC-001 documented in DAG)
  - Dependency: IMP-021 provides execution_order fields; IMP-011 provides declarative source
---
```

### IMP-012: Probe overlap consolidation [PROMOTED từ Section B]

```yaml
---
id: IMP-012
title: Rename ambiguous probes + dedup signals khi 2 probes flag same location
priority: P2
effort: S
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-deep-ui-traversal, P-QD5-ui-traversal-deep, all overlap pairs]
gate: G2
acceptance_test: fixtures/qd5-test/advanced/case-cross-dim-overlap/
dependencies: [IMP-023]
cross_skill_impact: []
notes: |
  Evidence Stage 1: Theme 5 cross-probe dedup 6 dims (IMP-QD1-011, QD2-013, QD3-011, QD5-014, QD6-004+014, QD7-013).
  QD5 Phase 4: ui-traversal-deep vs QD1 deep-ui-traversal same name root → CC-007.
  Signal inflation 2-3× confirmed cross-dim.
  IMP-012 implements dedup logic at probe level; IMP-023 provides namespace infrastructure.
  Acceptance:
  - Rename: P-QD1-deep-ui-traversal + P-QD5-ui-traversal-deep → unique names with dim prefix
  - Dedup at signal layer: 2 probes flag same (file, line_range, issue_class) → 1 signal, log both sources
  - Signal inflation test: confirmed 2-3× → 1× for known overlap pairs
  - Dependency: IMP-023 namespace must be implemented first
---
```

### IMP-013: SAST tool integration [PROMOTED từ Section B]

```yaml
---
id: IMP-013
title: Optional Semgrep integration cho QD3 (giảm false positive grep)
priority: P2
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [P-QD3-owasp-top-ten, P-QD3-dangerous-deserialize]
gate: G2
acceptance_test: fixtures/qd3-test/positive/case-sast-vs-grep/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence Stage 1: QD3 Phase 3 accuracy-report P=0.83 (1 FP from `test_scan_function()` — grep pattern matched test code).
  QD3 Phase 2 confirmed: grep patterns `eval\|exec\|os\.system` produce FPs from test fixtures + comments.
  Semgrep provides AST-based pattern matching → eliminates comment/string/test FPs.
  License note: Semgrep free tier OK for open source; commercial use → Pro tier or alternative (CodeQL).
  Fallback: grep (current) khi Semgrep unavailable → graceful degradation.
  Acceptance:
  - Detect Semgrep availability → use if present
  - QD3 owasp-top-ten + dangerous-deserialize via Semgrep rules
  - Fixture với legit SQL trong test file → grep flags it (FP), Semgrep skips (correct)
  - P target ≥ 0.95 with Semgrep (from 0.83 baseline)
---
```

### IMP-014: Bundle analyzer integration [PROMOTED từ Section B]

```yaml
---
id: IMP-014
title: Đọc webpack-stats.json hoặc vite stats để identify largest deps
priority: P2
effort: S
owner: skill-author
evidence_status: verified
affected_probes: [P-QD4-bundle-size-audit]
gate: G2
acceptance_test: fixtures/qd4-test/positive/case-bundle-deps/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence Stage 1: QD4 Phase 3 SPEC_GAP bundle-size-audit — probe uses `du -sh` approximation only (SPEC-ONLY for analyzer).
  QD4 Phase 2 DISCREPANCY-3: 3-way threshold mismatch → probe spec canonical decision.
  QD4 Phase 2 confirmed: no webpack-stats.json/vite-bundle-report.json parsing implemented.
  Acceptance:
  - Parse webpack-stats.json (if --profile deep/exhaustive)
  - Parse vite bundle report (if --profile deep/exhaustive)
  - Identify top 10 largest deps by size
  - Suggest: identify tree-shakable deps vs required
  - Fallback: du -sh (current) khi stats file absent
---
```

### IMP-015: Improve agent prompts với CI tools

```yaml
---
id: IMP-015
title: Agent prompts dùng GitNexus + Serena, cite file:line
priority: P2
effort: S
owner: agent-author
evidence_status: verified
affected_probes: [P-QD1-agent-feature-verify, P-QD2-domain-expert-review, P-QD2-business-analyst-review, P-QD3-auth-flow-verify, P-QD5-accessibility-check]
gate: G2
acceptance_test: fixtures/qd1-test/positive/case-agent-citation/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence: Stage 1 Theme 6 (4 dims: QD1/QD2/QD3/QD5).
  QD1 IMP-QD1-006: agent prompt generic (SENSE: "list all features") → no file:line → hallucination risk HIGH.
  QD2 IMP-QD2-004: 25 domain agents (SKILL.md) vs 7 in dim.json → E044 skip rate unknown.
  QD3 IMP-QD3-010: auth-flow-verify silent skip khi phase3-architecture docs missing.
  QD5 IMP-QD5-004: dim.json missing accessibility-auditor → spawn failure.
  Acceptance:
  - Prompts yêu cầu GitNexus query() trace flow + cite execution paths
  - Prompts yêu cầu Serena find_symbol/find_references → cite file:line
  - QD2 dim.json: fix 7→25 domain agents count match
  - QD5 dim.json: add accessibility-auditor to dependencies.agents
  - QD3: auth-flow-verify emit AUTH-FLOW-SKIP-NO-ARCH WARN signal (visible in lane-report)
  - P1→P4 context handoff (QD2): Probe 1 findings → enrichment context for Probe 4
---
```

### IMP-016: axe-core integration [PROMOTED từ Section B]

```yaml
---
id: IMP-016
title: Inject axe-core qua Playwright cho automated WCAG scan
priority: P2
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [P-QD5-accessibility-check]
gate: G2
acceptance_test: fixtures/qd5-test/positive/case-axe-vs-agent/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence Stage 1 (QD5 Phase 1 + Phase 3):
  - QD5 IMP-QD5-004 Phase 1 D-007: dim.json missing accessibility-auditor → spawn failure in production
  - QD5 Phase 3 accuracy-report: live bash covers 1/7 probes only; 5 SPEC-ONLY probes
  - Theme 6 (4 dims): agent a11y check tốn 15K-20K tokens + hallucination risk
  axe-core via Playwright: runtime WCAG scan without agent token cost.
  IMP-024 (CDG) prerequisite: axe-core findings may trigger CDG if WCAG Level A violations.
  Acceptance:
  - Playwright inject axe-core → scan page → extract violations by rule ID (WCAG level)
  - Map axe violations → QD5 signal schema
  - Fixture với known WCAG violations → axe detects; agent alternative as fallback
  - Token cost comparison: axe-core vs agent baseline documented
---
```

### IMP-023: Cross-Probe Dedup Namespace (global) [NEW]

```yaml
---
id: IMP-023
title: Unified dedup_hints namespace — prevent 2-3× signal inflation from probe overlap
priority: P2
effort: S
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-static-xref+orphan-ui, P-QD2-domain-expert+ba-review, P-QD3-deps+owasp, P-QD5-img-alt+input-label, P-QD6-type-mismatch+default-mismatch, P-QD7-deprecated-api]
gate: G2
acceptance_test: fixtures/case-cross-probe-dedup/
dependencies: [IMP-022]
cross_skill_impact: []
notes: |
  Evidence: Stage 1 Theme 5 cross-probe dedup — 6 dims confirmed signal inflation 2-3×.
  Cross-dim merge: IMP-QD1-011 + IMP-QD2-013 + IMP-QD3-011 + IMP-QD5-014 + IMP-QD6-004+014 + IMP-QD7-013.
  Specific overlaps confirmed: QD1 orphan_api↔missing_nav_link same fingerprint; QD2 P1+P4 double-signal;
  QD3 CVE↔OWASP-A06, DESER↔OWASP-A08; QD5 img-alt 2-3× per element; QD6 type_mismatch P1↔P4; QD7 execCommand HIGH+MEDIUM.
  Dedup key: {file_path, line_range, issue_class} — canonical cross-probe namespace.
  max_aggregation: keep highest severity, log all probe sources in evidence (audit trail).
  Dependency: IMP-022 translator provides dedup_hints field in bus schema.
  Acceptance:
  - Signal aggregator deduplicates: same (file_path, line_range, issue_class) from 2+ probes → 1 signal
  - evidence.sources: [probe_a, probe_b] preserved
  - Signal inflation test: 2× fixture → 1× output confirmed for each known overlap pair
  - IMP-012 uses this namespace for probe-level dedup
---
```

### IMP-026: Config-driven Exclude Patterns (global) [NEW]

```yaml
---
id: IMP-026
title: Config-driven EXCLUDE_PATTERN via project-overrides.json (replace hardcoded)
priority: P2
effort: S
owner: skill-author
evidence_status: verified
affected_probes: [P-QD5-label-consistency, P-QD7-deprecated-api-usage]
gate: G2
acceptance_test: fixtures/qd5-test/positive/case-custom-exclude/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence: Stage 1 Theme 5 EXCLUDE_PATTERN — 2 dims hardcoded causing issues.
  Cross-dim merge: IMP-QD5-015 + IMP-QD7-010.
  QD5: \\.test\\. hardcoded exclude → production files with .test. naming → false negative (Phase 3 neg-04).
  QD7: node_modules|dist|coverage hardcoded → test files with intentional deprecated APIs → FP flooding.
  Config: .mc-data/work/wf-fix-bugs/exclude-overrides.json
    { "additional_excludes": [...], "remove_excludes": [...] }
  Acceptance:
  - QD5/QD7 bash: read exclude-overrides.json if exists; merge with default list
  - Project with production *.test.ts files: remove \\.test\\. → correctly included in scan
  - Project with test fixtures needing deprecated APIs: add custom exclude → removed from report
  - Default behavior unchanged (backward compatible)
---
```

---

## P3 — Low Priority (Polish)

### IMP-017: caniuse-lite integration [PROMOTED từ Section B]

```yaml
---
id: IMP-017
title: caniuse-lite database cho browser-compat-check + polyfill-coverage
priority: P3
effort: S
owner: skill-author
evidence_status: verified
affected_probes: [P-QD7-browser-compat-check, P-QD7-polyfill-coverage]
gate: G2
acceptance_test: fixtures/qd7-test/positive/case-browserslist/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence Stage 1: QD7 Phase 2 D3 + D4: browser-compat-check + polyfill-coverage both SPEC-ONLY.
  QD7 accuracy-report SPEC_GAP: 4/5 probes runtime-only (only deprecated-api-usage bash live).
  D15 CRITICAL: heredoc PWEOF bug in existing bash → fix prerequisite.
  caniuse-lite provides offline browser support database → no HTTP needed.
  Acceptance:
  - bundle caniuse-lite (npm) → check feature support vs browserslist targets
  - Emit HIGH when feature used but browser support < 85% baseline
  - polyfill-coverage: verify polyfills match detected feature gaps
  - Prerequisite: fix D15 heredoc PWEOF bug first
---
```

### IMP-018: Lighthouse CI cho CWV [PROMOTED từ Section B]

```yaml
---
id: IMP-018
title: Lighthouse CI cho Core Web Vitals
priority: P3
effort: S
owner: skill-author
evidence_status: verified
affected_probes: [P-QD4-core-web-vitals]
gate: G2
acceptance_test: fixtures/qd4-test/positive/case-cwv-baseline/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence Stage 1: QD4 Phase 3 SPEC_GAP: core-web-vitals probe = SPEC-ONLY (no bash, Playwright runtime needed).
  QD4 IMP-QD4-009 DISCREPANCY-8: dim.json missing 3 critical CWV: LCP>4.0s, CLS>0.25, INP>500ms.
  Lighthouse CI provides LCP/CLS/INP/FCP/TTFB from actual browser render.
  Acceptance:
  - @lhci/cli via Playwright → extract CWV from page render
  - LCP/CLS/INP/FCP/TTFB mapped to dim.json severity thresholds (post IMP-004 fix)
  - Baseline mode: first run saves baseline, subsequent runs compare delta
  - Fallback: static heuristics (current) when Lighthouse unavailable
---
```

### IMP-019: Schema diff tool [PROMOTED từ Section B]

```yaml
---
id: IMP-019
title: Atlas/dbmate diff cho schema-drift-detect
priority: P3
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [P-QD6-schema-drift-detect]
gate: G2
acceptance_test: fixtures/qd6-test/positive/case-schema-drift/
dependencies: []
cross_skill_impact: []
notes: |
  Evidence Stage 1: QD6 Phase 2 D4 IMPL-REFUTED: schema-drift-detect = SPEC-ONLY (no implementation).
  QD6 Phase 2 IMP-QD6-007: cache policy conflict (probe B cache:never adjacent probe A cache:allowed).
  Atlas (MIT), dbmate (MIT) — both open source, no license concern.
  EF Core migration support: dotnet ef migrations list → compare vs actual DB schema.
  Acceptance:
  - Atlas diff: planned schema (migration files) vs actual DB → report drift
  - EF Core: dotnet ef migrations list + compare Entity models
  - Require DB connection from .mc-data/work/wf-fix-bugs/db-connection.json (opt-in)
  - Fallback: static migration file analysis (current SPEC-ONLY mode)
---
```

### IMP-020: Cross-dim catalog sharing [PROMOTED từ Section B]

```yaml
---
id: IMP-020
title: catalog-v1 schema cho UI/route catalog dùng chung giữa dims
priority: P3
effort: M
owner: skill-author
evidence_status: verified
affected_probes: [P-QD1-deep-ui-traversal, P-QD5-ui-traversal-deep, P-QD7-device-breakpoint-test]
gate: G2
acceptance_test: fixtures/qd1-test/advanced/case-catalog-handoff/
dependencies: [IMP-011]
cross_skill_impact: []
notes: |
  Evidence Stage 1:
  - CC-006: QD5 responsive-layout vs QD7 device-breakpoint-test viewport sharing → same Playwright session wasted twice (IMP-QD5-016 + IMP-QD7-011 Phase 4 confirmed)
  - CC-007: QD5 ui-traversal-deep vs QD1 deep-ui-traversal — same function name root → naming collision (Phase 1 D-001 QD5)
  - CC-002: QD1 catalog-ui-pages.json emitted by Probe 5, consumed by Probe 6 — no schema enforcement (IMP-QD1-009)
  catalog-v1 schema: {pages: [{url, title, components, routes}], generated_at, dim_source}.
  Acceptance:
  - QD1 Probe 5 emit catalog-ui-pages.json (catalog-v1 schema)
  - QD5 ui-traversal-deep + QD7 device-breakpoint-test: if catalog-v1 present → skip re-crawl
  - Schema validation at handoff (no silent corruption)
  - Playwright session sharing: QD5 + QD7 viewport test → 1 session (not 2)
---
```

---

# Section B — Tentative IMPs

> ✅ **EMPTY** — Tất cả 10 tentative IMPs (IMP-010 through IMP-020) đã được PROMOTED sang Section A với Stage 1 evidence (Phiên 42, 2026-05-09).
>
> Promoted list: IMP-010 (ORM adapter), IMP-011 (cross-probe DAG), IMP-012 (probe overlap), IMP-013 (SAST Semgrep), IMP-014 (bundle analyzer), IMP-016 (axe-core), IMP-017 (caniuse-lite), IMP-018 (Lighthouse CI), IMP-019 (schema diff), IMP-020 (catalog sharing).
>
> 6 new global cross-dim IMPs added: IMP-021 (execution_order), IMP-022 (signal schema), IMP-023 (dedup namespace), IMP-024 (CDG governance), IMP-025 (bash dispatch), IMP-026 (exclude patterns).
>
> 0 dropped — all tentative had Stage 1 evidence.

---

## Tổng quan (LOCKED)

| Section | Số IMPs | Priority breakdown | Status |
|---|---:|---|---|
| C — Infrastructure (verified) | 1 | P0 ×1 | ✅ DONE Stage 0 |
| A — Verified (original) | 10 | P0 ×3, P1 ×5, P2 ×2 | ✅ Stage 3 ready |
| A — Promoted từ B | 10 | P1 ×2, P2 ×4, P3 ×4 | ✅ Stage 3 ready |
| A — New global cross-dim | 6 | P0 ×3, P1 ×1, P2 ×2 | ✅ Stage 3 ready |
| B — Tentative | 0 | — | ✅ Empty |
| **Total** | **27** | | |

| Priority | Count | Status |
|---|---:|---|
| P0 | 7 | ✅ All verified (IMP-001, 002, 003, 022, 024, 025 + IMP-000) |
| P1 | 7 | ✅ All verified (IMP-004, 005, 006, 007, 009, 010, 021) |
| P2 | 9 | ✅ All verified (IMP-008, 011, 012, 013, 014, 015, 016, 023, 026) |
| P3 | 4 | ✅ All verified (IMP-017, 018, 019, 020) |
| **Total global** | **27** | **≥15 requirement: ✅ PASS** |

## Sprint allocation đề xuất (Stage 3 — updated sau G2 lock)

| Sprint | Tuần | Items | Goal |
|---|---|---|---|
| **Sprint 0** | 0 | IMP-000 (infra) | ✅ DONE — adapter framework |
| **Sprint 1** | 1-2 | IMP-022, IMP-025 | 🔧 Orchestration correctness: signal schema + bash dispatch (fix invisible/corrupted signals) |
| **Sprint 2** | 2-3 | IMP-024 (Phase 1 first: QD6 CDG P0 CRITICAL) | 🛡️ Data safety: CDG canonical pattern (DATA LOSS RISK first) |
| **Sprint 3** | 4-5 | IMP-001, IMP-002, IMP-003 | 📡 Coverage P0: multi-stack + i18n + multi-PM |
| **Sprint 4** | 6-7 | IMP-004, IMP-005, IMP-006, IMP-007, IMP-009 | ⚙️ Configurability + P1 verified |
| **Sprint 5** | 8-9 | IMP-010, IMP-021 | 🔗 ORM adapters + Execution Order DAG |
| **Sprint 6** | 10-11 | IMP-008, IMP-012, IMP-013, IMP-014, IMP-015, IMP-016 | 🔎 P2 quality: schema validation + SAST + agents |
| **Sprint 7** | 12 | IMP-011, IMP-023, IMP-026 | 🌐 P2 global: probe DAG + dedup namespace + exclude config |
| **Sprint 8** | 13 | IMP-017, IMP-018, IMP-019, IMP-020 | ✨ P3 polish: caniuse + Lighthouse + schema diff + catalog |

**Sprint 1 rationale:** IMP-022 (signal schema) + IMP-025 (bash dispatch) must come FIRST — without correct signal routing, all downstream metric data is corrupted. IMP-022 blocks all lanes; IMP-025 makes QD2/QD6 invisible.

**Sprint 2 rationale:** IMP-024 CDG Phase 1 (QD6 DROP TABLE 3-file fix) is DATA LOSS RISK → fix before any auto-fix features enabled.

## Open Questions — RESOLVED (G2)

1. **"Có IMP nào trong Section B nên drop?"** → Không drop. 10/10 tentative IMPs có Stage 1 evidence → tất cả promoted.

2. **"EUREKA-2026 .NET 9 — IMP-001 priority ASP.NET Core?"** → Confirmed. IMP-001 + IMP-010 phải ưu tiên ASP.NET Core/EF Core adapter (QD2 bash 100% C# → EUREKA-2026 backend = 0% static coverage).

3. **"Test fixtures: EUREKA-2026 thật hay mock?"** → Stage 1 dùng generic mock (C# EF Core cho QD6, generic cho các dims khác). EUREKA-2026 là reference nhưng không dùng production data trong fixtures.

4. **"Semgrep license blocker?"** → Semgrep free tier OK cho open source. Commercial: Pro tier hoặc CodeQL alternative. Noted trong IMP-013 notes.
