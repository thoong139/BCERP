# 09 — Cross-Cutting Findings (Vấn đề xuyên-dim)

> **Status:** ✅ Stage 2 ENRICHED (Phiên 41 — 2026-05-09). 10 themes × per-dim evidence từ Stage 1 (QD1-QD7 §8 MERGE tables). Tất cả themes đã VERIFIED với ≥2 dim evidence — G2 evidence gate PASS.
>
> **Evidence status legend:**
> - ✅ **VERIFIED** — Có file:line evidence từ ≥2 dims (Stage 1 confirmed)
> - ❌ **DROPPED** — Audit Stage 1 confirm không phải vấn đề
>
> **Tất cả themes trong file này ∈ {VERIFIED, DROPPED} — đáp ứng Gate G2 yêu cầu.**

## Mục đích

Tổng hợp các vấn đề **xuất hiện ở > 1 dimension** để tránh fix lặp lại + xác định root cause chung.

---

## Theme 1: Tech Stack Detection Bias (Node-centric) ✅ VERIFIED (5 dims: QD1/QD2/QD3/QD4/QD6)

> **Stage 1 evidence:** QD1 confirmed (pre-seed). QD2 IMP-QD2-005 (bash 100% C#-only). QD3 IMP-QD3-004 (auth-flow-verify 2/7 stacks, cors 3/7, headers 3/7). QD4 §6 bundle/ORM analysis. QD6 IMP-QD6-005 (ORM stacks 4/11 supported).

### Mô tả
Skill được thiết kế chủ yếu cho Node.js/JavaScript ecosystem. Các backend/framework khác (.NET, Java, Python, Go, Ruby, PHP) không được cover đầy đủ trong probe scripts và detection patterns.

### Affected dims & probes (Stage 1 confirmed)

| Dim | Probe / Finding | Tác động | Evidence |
|---|---|---|---|
| QD1 | route-config-parse | Miss 100% .NET/Java/Python routes | IMP-QD1-001 §3 P2 D2 + FN-001 pos-03 .NET |
| QD1 | api-smoke (fallback parse) | Không build được endpoint list từ .NET | IMP-QD1-001 |
| QD2 | bash static probes | 100% C#-only checks — non-C# stacks = 0% static detection | IMP-QD2-005 §6 stack matrix |
| QD3 | auth-flow-verify | Chỉ cover JS/PY 2/7 stacks — Java Spring, .NET Identity, Go gin = 0% | IMP-QD3-004 §6.1 |
| QD3 | cors-policy-check | 3/7 stacks — miss Java/Go/PHP | IMP-QD3-004 §6.1 |
| QD3 | security-header-audit | 3/7 stacks | IMP-QD3-004 §6.1 |
| QD4 | bundle-size-audit | Chỉ webpack/vite stats, miss .NET Razor, Gradle | IMP-QD4 §6 |
| QD4 | db-query-analysis | Chỉ Prisma/TypeORM, miss EF Core/SQLAlchemy/Hibernate | IMP-QD4 §6 |
| QD6 | orm-model-sync + migration-integrity | 4/11 ORM stacks (Prisma/TypeORM/EF Core partial, 7 others unsupported) | IMP-QD6-005 §6.1 |
| QD6 | schema-drift-detect | 4/11 stacks — Alembic/Hibernate unsupported | IMP-QD6-005 |

### Impact
- Trên project .NET (như EUREKA-2026 backend): **mất 30-50% coverage**
- Trên project Python/Django: **mất 40-60% coverage**
- Trên project Java/Spring: **mất 50%+ coverage** (QD3 auth scan = 0%)
- QD6: 7/11 ORM stacks = **64% unsupported** → data integrity check silent miss cho majority

### Root cause
- Probe regex patterns được thiết kế cho Node.js conventions
- `.claude/scripts/wf-fix-probe-static-*.sh` không có conditional logic per stack
- Không có abstraction "language adapter" để plug vào
- QD2 bash checks dùng C# `namespace`/`class` patterns → 0% cho TS/PY/Java

### Recommendation tổng quát
- Tạo "language adapter" pattern: mỗi stack có 1 file `adapters/<stack>.sh` với regex specific
- Probe core gọi adapter dispatcher dựa trên detected stack
- Min support: Node, .NET, Java, Python, Go
- Unify qua IMP-QD1-001 + IMP-QD2-005 + IMP-QD3-004 + IMP-QD6-005 (cross-dim effort phối hợp)

---

## Theme 2: Hardcoded Thresholds ✅ VERIFIED (4 dims: QD1/QD4/QD5/QD7)

> **Stage 1 evidence:** QD1 confirmed (pre-seed). QD4 IMP-QD4-007 triple mismatch + IMP-QD4-009 CWV missing + DISCREPANCY-2. QD5 IMP-QD5-006 severity misalign. QD7 IMP-QD7-004 CRITICAL overaggressive.

### Mô tả
Các threshold được hardcode trong probe spec, SKILL.md, và dimension.json — nhiều trường hợp có 3-way mismatch giữa các nguồn. Không có config override per project size.

### Affected (Stage 1 confirmed)

| Threshold | Default | Probe | Vấn đề | Evidence |
|---|---|---|---|---|
| MAX_PAGES | 20 | QD1 deep-ui-traversal | Module ERP > 80 pages → miss 75% | IMP-QD1-003 FN-004 |
| Wait time post-action | 2-3s | QD1 deep-ui-traversal | App slow legit → false positive | IMP-QD1 §4 |
| Curl timeout | 10s | QD1 infra-preflight, api-smoke | Cold start → false negative/positive | IMP-QD1-005 |
| Bundle size threshold | **3-way mismatch** dim.json 200KB / probe 500KB=MEDIUM 1000KB=HIGH / SKILL.md "gzip ambiguous" | QD4 bundle-size-audit | User config `--bundle-warn-kb` không rõ nguồn canonical | IMP-QD4-007 DISCREPANCY-3 |
| CWV critical_triggers | Thiếu LCP>4.0s, CLS>0.25, INP>500ms | QD4 dim.json | dim.json thiếu 3 critical conditions → severity routing sai | IMP-QD4-009 DISCREPANCY-8 |
| API latency | 2s p95 | QD4 api-latency-probe | Report endpoint slow legit → false CRITICAL | IMP-QD4 §3 Probe 3 |
| Color contrast | HIGH (heuristic-only) | QD5 color-contrast-audit | Heuristic-only match nên MEDIUM, không HIGH | IMP-QD5-006 Phase 1 D-009 |
| api-version severity_default | CRITICAL | QD7 api-version-compat | Chỉ 1 case match CRITICAL, phần lớn HIGH/MEDIUM → triage over-prioritize | IMP-QD7-004 Phase 1 D-002 |
| max_signals_per_probe | 100-500 | All | Không scale theo project size | QD1 §7 |

### Impact
- False positive ở project lớn / app phức tạp
- False negative khi threshold quá lỏng
- User không thể tune → QD4 `--bundle-warn-kb` ambiguous
- Triage over-prioritize P0 khi severity_default quá aggressive (QD7)

### Recommendation tổng quát
- Single source of truth per threshold: probe spec wins (IMP-QD4-007 decision)
- Move thresholds vào `_shared/profiles.json` per profile
- Allow override qua flag `--threshold-overrides`
- Tạo `.mc-data/work/wf-fix-bugs/profile-overrides.json` cho project-specific tuning

---

## Theme 3: i18n / l10n Issues ✅ VERIFIED (3 dims: QD1/QD5/QD7)

> **Stage 1 evidence:** QD1 confirmed (pre-seed). QD5 IMP-QD5-012 label-consistency massive FP risk cho i18n apps. QD7 IMP-QD7-009 no i18n probe, FP-09 deprecated keyword matching.

### Mô tả
Probe assume English-only text trong UI và content patterns. Apps với i18n message files (VI/JP/ZH) bị miss hoặc false-positive massively.

### Affected (Stage 1 confirmed)

| Hardcoded text | Probe | Dim | Impact | Evidence |
|---|---|---|---|---|
| CTA list (Submit/Save/Create/...) | deep-ui-traversal | QD1 | App Việt → miss 100% CTAs | IMP-QD1-002 FN-003 pos-05 |
| Form fill defaults (`test@example.com`) | deep-ui-traversal | QD1 | App có format custom (VAT, phone VN) fail | IMP-QD1 §4 |
| Orphan label check | label-consistency | QD5 | Nếu app có i18n message files → massive FP (probe flag tất cả labels là orphan vì không match static text) | IMP-QD5-012 Phase 1 §4 FP-05 |
| Severity trigger keywords ("deprecated") | deprecated-api-usage | QD7 | Comment trong tiếng Việt/JP có thể match regex | IMP-QD7 §4 FP patterns |
| i18n locale probe (Date(), currency, locale strings) | **Không có probe** | QD7 | Hardcoded `new Date()`, currency symbols, locale strings hoàn toàn không được detect | IMP-QD7-009 Phase 1 D-005 |
| Error message detection | deep-ui-traversal, accessibility-check | QD1/QD5 | Vietnamese/Chinese/Japanese error text miss | QD1 §7, QD5 §5 |

### Impact
- Tất cả app Việt hóa (như ERP EUREKA-2026): **CTA detection ~0%** (QD1)
- App với i18n message files: **label-consistency = false alarm** (QD5 FP-05)
- App Việt dùng date/currency: **QD7 i18n check = 0%** (no probe)

### Recommendation tổng quát
- Tạo `_shared/locales/{en, vi, ja, zh, ...}/keywords.json` chứa CTA dictionary
- Probe đọc locale từ `req-registry.json.project.locale` (cần thêm field)
- QD5 label-consistency: detect i18n message file patterns (.json) → skip orphan check + emit INFO signal
- QD7: Add `P-QD7-i18n-locale-check` (static grep cho hardcoded locale patterns) hoặc remove i18n claim

---

## Theme 4: Schema Validation Strictness ✅ VERIFIED (3 dims: QD1/QD2/QD6)

> **Stage 1 evidence:** QD1 IMP-QD1-010 skip-list contract agent. QD2 D1 CORE-029 inconsistency (20 vs 50 chars) + D10 EMIT() no code_snippet → T3.6 semantic fail. QD6 D11 cdg_flags:[] hardcoded + IMP-QD6-013 invocation guard.

### Mô tả
CORE-029 spot-check chỉ validate **structure** (fields exist, types match), không validate **semantic correctness**. EMIT() functions thiếu fields quan trọng. Thêm vào đó: CORE-029 spec không nhất quán giữa probe specs và SKILL.md.

### Affected (Stage 1 confirmed)

| Validation gap | Dim | Impact | Evidence |
|---|---|---|---|
| `description` min-length inconsistency: probe spec `>= 20 chars` vs SKILL.md `>= 50 ký tự` | QD2 | Agent output drops incorrectly: 50-char gate rejects 30-char descriptions mà probe spec approved → signals lost | IMP-QD2-003 D1 |
| EMIT() `description: "Line N"` (line number only, no code_snippet) | QD2 | Post-gate T3.6 semantic requirement "hard-coded value visible in evidence" FAIL → evidence quality insufficient | IMP-QD2-010 D10 bash line 78 |
| EMIT() `cdg_flags: []` hardcoded — field not populated in bash | QD6 | CDG-DELETE-DATA không được set → skip mechanism không nhận escalation | IMP-QD6-001 D11 `wf-fix-probe-static-data.sh:79` |
| `evidence.screenshot_path` không verify file tồn tại | QD1 | Reference file gone, signal vẫn pass validation | QD1 §4 spot-check gap |
| `severity` không cross-check với `severity_rules` | QD1/QD2 | Severity inconsistent; QD2 D9 fingerprint 4th variant | QD2 D9 AF-QD2-02 |
| `confidence` không enforce range 0-1 | All | Có thể thấy 1.5 hay -0.3 | QD1 §4 |
| Sample 3 issues quá nhỏ | All | Miss issues outside sample | CORE-029 IMP-QD1-010 |
| Invocation guard: `--probe` arg không validate vs valid probe list | QD6 | Phantom PROBE_ID → wrong attribution tất cả signals | IMP-QD6-013 D10 D9 |

### Impact
- Signals pass schema validation nhưng không actionable (QD2 code_snippet missing)
- Triage spend time trên signals thiếu evidence
- CDG gate broken cho QD6 destructive operations (data loss risk)
- Sample-3 spot-check miss systematic issues

### Recommendation tổng quát
- Strengthen CORE-029 spot-check:
  - Min description length: chọn canonical (≥50 chars per SKILL.md) + update probe specs
  - File path validation (exist on disk) cho screenshot_path + file_path
  - Severity consistency check vs `severity_rules` per dim.json
  - Range validation cho confidence [0.0, 1.0]
  - Sample size = `min(10, total * 0.1)` thay vì hardcode 3
- Fix EMIT() helpers: add `code_snippet` field + `cdg_flags` parameter support
- Add `--probe` required validation in all bash scripts (IMP-QD6-013 pattern → all dims)

---

## Theme 5: Cross-Probe Interaction Issues ✅ VERIFIED (7 dims — execution_order/dedup/cascade/EXCLUDE)

> **Stage 1 evidence:** QD1 pre-seed CC-001/007. **execution_order missing: 7/7 dims confirmed** (IMP-QD1-008, QD2-007, QD3-009, QD4-004, QD5-013, QD6-015, QD7-002 — canonical evidence). **Cross-probe dedup: 6 dims** (QD1-011, QD2-013, QD3-011, QD5-014, QD6-004+014, QD7-013). **EXCLUDE_PATTERN hardcoded: 2 dims** (QD5-015, QD7-010).

### Mô tả
Probes có dependencies nhưng không có centralized DAG management. Side-effects + race conditions tiềm ẩn. **Stage 1 audit xác nhận 3 systemic patterns xuất hiện trên tất cả 7 dims.**

### Execution Order Gap (7/7 dims — STRONGEST evidence)

All 7 `dimension.json` files thiếu `execution_order` / `parallel_groups` field:

| Dim | Quantified waste (naive vs DAG) | Evidence |
|---|---|---|
| QD1 | Cited ORDER-001/002 race condition risk | IMP-QD1-008 Phase 4 §4.6 |
| QD2 | 54% token savings nếu static-before-agent ordering | IMP-QD2-007 §4.8 |
| QD3 | 375s deep → 195s DAG-optimized (-48%) | IMP-QD3-009 Phase 4 §4.8 ORDER-QD3-001 |
| QD4 | CASCADE-QD4-001: Playwright concurrency blast (P2r ∥ P6 → flaky LCP/FCP) | IMP-QD4-004/011/012 Phase 4 §4.4 |
| QD5 | 280s deep → 168s DAG-optimized (-40%) | IMP-QD5-013 Phase 4 §4.8 ORDER-001 |
| QD6 | 285s deep → 135s DAG-optimized (-53%) | IMP-QD6-015 Phase 4 §4.8 ORDER-QD6-001 |
| QD7 | ~36s current → ~12s DAG-optimized (-67%) | IMP-QD7-002 Phase 4 ORDER-QD7-001 |

**Recommendation:** 1 global IMP tại Stage 2 G2 fix tất cả 7 `dimension.json` files — thêm `execution_order` + `parallel_groups` fields (QD4 design là complex nhất → dùng làm reference).

### Cross-Probe Dedup Namespace (6 dims confirmed)

Probes overlap → same defect flagged 2-3×, severity inflated via `max_aggregation:true`:

| Dim | Overlap pair | Inflation | Evidence |
|---|---|---|---|
| QD1 | `orphan_api` (P3-static-xref) ↔ `missing_nav_link` (orphan-ui-detect) — same fingerprint formula mismatch | 2× signals, severity inflate | IMP-QD1-011 REDUN-001/002/003 |
| QD2 | Probe 1 (domain-expert) ↔ Probe 4 (BA-review) — both agent, no handoff → double-signal | 2× inflation | IMP-QD2-013 REDUN-QD2-001 + IMP-QD2-011 |
| QD3 | CVE↔OWASP-A06, DESER↔OWASP-A08, CORS↔HDR — 3 overlap pairs | 2× signals per pair | IMP-QD3-011 Phase 4 §4.5 REDUN-001/002/003 |
| QD5 | img alt (P7+P3-static), input label (P2+P3-static+P7) — 2 and 3× inflation | 2-3× per element | IMP-QD5-014 Phase 4 §4.5 REDUN-001/002 |
| QD6 | type_mismatch (P1↔P4), default_mismatch (P1↔P5), FK overlap (P3↔P5) | 2× metrics inflation | IMP-QD6-004+014 Phase 4 §4.5 REDUN-001/002/003 |
| QD7 | execCommand (HIGH pattern #1 + MEDIUM pattern #3 cascade) → 2 signals for 1 defect | 2× per deprecated call | IMP-QD7-013 Phase 3 + Phase 4 §4.5 REDUN-QD7-003 |

**Recommendation:** 1 global IMP — unified `dedup_hints` namespace trong signal aggregation layer. QD1/QD3/QD5 MERGE confirmed → define key strategy: `{file_path, line_range, issue_class}`.

### EXCLUDE_PATTERN Hardcoded (2 dims)

| Dim | Hardcoded pattern | Risk | Evidence |
|---|---|---|---|
| QD5 | `\.test\.|\.spec\.|node_modules` | Production code dùng `.test.` naming convention → miss 5+ violations | IMP-QD5-015 Phase 3 neg-04 + Phase 4 CASCADE-QD5-003 |
| QD7 | `(node_modules\|\.git/\|dist/\|build/\|\.next/\|coverage/)` | Test files using deprecated APIs intentionally → FP flooding | IMP-QD7-010 Phase 1 §4 FP-09 |

### Cascade Issues (updated from pre-seed)

| # | Issue | Dims | Evidence |
|---|---|---|---|
| **CC-001** | Cascade skip: infra-preflight fail → api-smoke + deep-ui-traversal skip → orphan-ui-detect mất catalog | QD1/QD4 | IMP-QD1-005 Phase 4 §4.4 CASCADE-001, IMP-QD4 CASCADE-001 |
| **CC-002** | Catalog handoff: Probe 5 emit `catalog-ui-pages.json`, Probe 6 consume — không có schema enforcement | QD1 | IMP-QD1-009 Phase 4 §4.3 E4 |
| **CC-003** | Severity max_aggregation: 2 probes flag same code, lấy max nhưng không log conflict | All dims | All REDUN findings above |
| **CC-004** | Cache policy collision: probe A `cache: allowed` next to probe B `cache: never` cùng dim | QD3 | IMP-QD3-001 + IMP-QD6-007 |
| **CC-005** | Cross-dim overlap: QD4 api-latency vs QD1 api-smoke — same endpoints, different metrics, double-flag | QD1 vs QD4 | IMP-QD4-012 cascade + QD1 EC-004 |
| **CC-006** | Cross-dim overlap: QD5 responsive-layout vs QD7 device-breakpoint-test (Playwright viewport sharing) | QD5 vs QD7 | IMP-QD5-016 + IMP-QD7-011 Phase 4 confirmed |
| **CC-007** | Cross-dim overlap: QD5 ui-traversal-deep vs QD1 deep-ui-traversal — cùng tên! | QD1 vs QD5 | Phase 1 D-001 QD5 + QD1 naming |

### Impact
- Skill behavior unpredictable khi probes có dependencies (execution_order)
- Performance overhead đáng kể: QD3 +180s/scan, QD6 +150s/scan, QD4 flaky results
- Signal inflation 2-3× → triage noise → wrong sprint planning
- False negative khi EXCLUDE_PATTERN quá broad (silent miss production violations)

---

## Theme 6: Agent Probe Cost & Quality ✅ VERIFIED (4 dims: QD1/QD2/QD3/QD5)

> **Stage 1 evidence:** QD1 IMP-QD1-006 (agent prompt generic, no CI tools). QD2 IMP-QD2-004 (agent count mismatch) + IMP-QD2-011 (P1→P4 no handoff → double-signal). QD3 IMP-QD3-010 (auth-flow-verify silent skip). QD5 IMP-QD5-004 (missing accessibility-auditor in dim.json).

### Mô tả
Agent probes đắt (15K-20K tokens) với prompts generic, không tận dụng CI tools (GitNexus, Serena). Metadata về agent requirements trong `dimension.json` không đầy đủ → scheduling failures. Agent probes có hallucination risk cao khi thiếu structured context.

### Affected (Stage 1 confirmed)

| Dim | Probe | Issue | Evidence |
|---|---|---|---|
| QD1 | `agent-feature-verify` | Prompt generic (SENSE: "list all features") → không cite file:line → hallucination risk HIGH. Token cost 15K-20K/run không tận dụng GitNexus/Serena | IMP-QD1-006 + IMP-QD1-010 §3 P7 SENSE generic |
| QD2 | `domain-expert-review` (P1) + `ba-review` (P4) | 25 domain agents (SKILL.md) vs 7 entries (dim.json) → E044 skip rate unknown → QD2 coverage unknown | IMP-QD2-004 D6 |
| QD2 | P1→P4 agent handoff | Both agent probes analyze same violations independently → REDUN-QD2-001 double-signal + P4 wastes tokens re-discovering P1 findings | IMP-QD2-011 E6 GAP §4.3 |
| QD3 | `auth-flow-verify` | CASCADE-QD3-003: probe DUY NHẤT detect auth bypass CRITICAL, nhưng silent skip khi phase3-architecture docs missing. Skip không visible trong lane-report.md → user tin auth đã checked | IMP-QD3-010 Phase 4 §4.4 CASCADE-QD3-003 |
| QD5 | `accessibility-check` (P3-agent) | `dim.json dependencies.agents` chỉ có `ux-researcher`, thiếu `accessibility-auditor` → spawn failure khi P3-agent layer chạy | IMP-QD5-004 Phase 1 D-007 |

### Impact
- Agent spawn failure: QD5 accessibility-auditor, QD2 E044 skip
- Token waste: QD2 P1+P4 double-classify cùng violations
- Security blind spot: QD3 auth-flow-verify silent skip → false confidence
- False findings: QD1 agent hallucinate features without file:line evidence

### Recommendation tổng quát
- Enrich agent prompts với CI tools: `GitNexus query() + Serena find_symbol()` → require cite file:line
- P1→P4 context handoff (QD2): pass Probe 1 findings as enrichment context to Probe 4
- QD3 auth-flow-verify: emit `AUTH-FLOW-SKIP-NO-ARCH` WARN signal visible trong lane-report + partial JWT/RBAC static fallback
- Fix dim.json `dependencies.agents` cho QD2 (25 vs 7) + QD5 (thêm accessibility-auditor)

---

## Theme 7: SPEC-ONLY Probe Coverage Gap ✅ VERIFIED (7 dims — all dims affected)

> **Stage 1 evidence:** Accuracy reports từ 7 dim fixtures confirm systemic pattern: phần lớn probes ở mọi dim là SPEC-ONLY (bash không implement được). Theme renamed từ "Test Fixture Coverage" (plan concern) → "SPEC-ONLY Probe Coverage Gap" (production finding).

### Mô tả
Phần lớn probe specifications tồn tại chỉ trên paper (SPEC-ONLY). Bash scripts implement chỉ 1-2 static checks per dim, trong khi probe specs define 5-7 probes. Accuracy reports từ Stage 1 cho thấy SPEC_GAP là pattern nhất quán cross-dim.

### Affected (per accuracy-report.md)

| Dim | Total probes | Live (bash) | SPEC-ONLY | Key metric | Evidence |
|---|---|---|---|---|---|
| QD1 | 7 | 1-2 live (static-xref partial) | 5-6 | P=1.0, R=0.80, F1=0.89; FN-004 = MAX_PAGES limit | fixtures/qd1-test/accuracy-report.md |
| QD2 | 5 | 1 (bash live but wrong checks) | 4+ | Static checks = C# architecture, not business logic | IMP-QD2-002 "bash implements wrong checks" |
| QD3 | 7 | 1 live (secret-detection) | 6 SPEC-ONLY | P=0.83, R=1.00, F1=0.91; DISCREPANCY-2: 6 cells routing wrong | fixtures/qd3-test/accuracy-report.md |
| QD4 | 6 | 1-2 live (render-perf static partial) | 4-5 SPEC-ONLY | DISCREPANCY-1/2/3 routing errors → wrong probes at quick | fixtures/qd4-test/accuracy-report.md |
| QD5 | 7 | 1-2 (aria-scan bash live) | 5 SPEC-ONLY | SPEC_GAP 4/7 probes runtime-only noted | fixtures/qd5-test/accuracy-report.md |
| QD6 | 6 | 1 (bash live, EF Core only) | 5+ SPEC-ONLY | P=0.75, R=0.67; IMP-QD6-010 bash runs wrong checks | fixtures/qd6-test/accuracy-report.md |
| QD7 | 5 | 1 live (deprecated-api-usage bash) | 4 SPEC-ONLY | P=R=F1=1.00 file-level; SPEC_GAP 4/5 probes runtime-only | fixtures/qd7-test/accuracy-report.md |

### Impact
- Skill user chạy wf-fix-bugs nhưng nhận output chủ yếu từ SPEC-ONLY probes → **false confidence về audit completeness**
- Coverage gap: khi không có bash implementation → probe silently skip → lane-report.md incomplete
- Stage 3 implementation effort SUBSTANTIAL: cần implement 30-35 SPEC-ONLY probes

### Recommendation tổng quát
- Emit `SPEC-ONLY-PROBE-SKIP` signal visible per probe skipped → user biết coverage limited
- Stage 3 prioritize implementing top 5 highest-impact SPEC-ONLY probes (dựa trên IMP priority)
- Hoặc: document tường minh trong SKILL.md "probes hiện live vs SPEC-ONLY" per profile

---

## Theme 8: Signal Schema Fork (dual signal-v2) ✅ VERIFIED (4 dims: QD1/QD2/QD3/QD6) [NEW]

> **Stage 1 evidence:** QD1 IMP-QD1-007 (Phase 2 architectural finding). QD2 IMP-QD2-006 (D5 + D9). QD3 IMP-QD3-006 (AF-QD3-02). QD6 IMP-QD6-009. Đây là architectural blocker P0 cho toàn bộ orchestration layer.

### Mô tả
Tồn tại 2 incompatible versions của `signal-v2` schema đang được dùng song song:
- **Lane-local schema** (bash output): fields `severity`, `location`, `evidence: [array]`, `fingerprint` (5-6 tokens)
- **Signal bus schema** (signal_bus/schemas/signal.v2.schema.json): fields `suggested_severity`, `target`, `evidence: {dict}`, `dedup_hints`, `emitted_at`, `lane`

Cả 2 đều khai báo `"$schema": "signal-v2"` nhưng KHÔNG tương thích.

### Evidence per dim

| Dim | Specific discrepancy | Risk | Evidence |
|---|---|---|---|
| QD1 | Lane bash output `severity` field vs bus schema `suggested_severity`; fingerprint formula mismatch (5-token vs 6-token) | `Signal.from_dict()` → ValueError when lane signals feed bus | IMP-QD1-007 Phase 2 architectural finding `_shared/lane/_shared.md §1` |
| QD2 | D5 bash line 72 `severity: $s` vs probe spec `suggested_severity`; D9 line 61 `title`-based fingerprint (4th variant) | Downstream aggregation reads wrong severity field | IMP-QD2-006 D5+D9 |
| QD3 | Spec-only probes use `_shared.md §1` (bus schema); bash uses lane-signals-v1; fingerprint 3-way split (spec=4 tokens, protocol=5, bash=6) | Aggregation fails when 6 SPEC-ONLY probes implement | IMP-QD3-006 AF-QD3-02 |
| QD6 | Dùng cùng dual-schema fork pattern; mọi probe ACT dùng `signal-emit.md` helper nhưng helper targets bus schema | 6× invocation × schema mismatch → corrupted aggregation | IMP-QD6-009 §3.1-3.6 |

### Impact
- **Orchestrator aggregate phase fail toàn lane** khi ráp 7 lane signals → issue-registry (QD1-007 P0)
- Severity fields được aggregate sai → triage nhận wrong priority → wrong sprint planning
- Build trên foundation broken: mọi new probe implementation sẽ thêm sai schema cho đến khi fix

### Root cause
- `_shared/lane/_shared.md` và `signal_bus/schemas/signal.v2.schema.json` developed independently
- Không có cross-file schema contract validation tại PRE-GATE hoặc POST-GATE
- Lane scripts không import bus schema → silent incompatibility

### Recommendation tổng quát
- **Giải pháp A (recommended):** Build translator/adapter `lane-to-bus.py` — lane bash output → bus schema conversion tại aggregation step
- **Giải pháp B:** Unified schema cho cả lane-local và bus — phải resolve field naming + fingerprint formula
- Unify fingerprint formula: chọn 1 canonical N-token spec + enforce across bash + probe specs + bus
- MERGE IMPs: QD1-007 + QD2-006 + QD3-006 + QD6-009 → 1 global IMP

---

## Theme 9: CDG Governance Gap ✅ VERIFIED (4 dims: QD3 partial / QD4 broken / QD5 missing / QD7 missing) [NEW]

> **Stage 1 evidence:** QD3 IMP-QD3-001/003 (cache policy + CDG flag policy). QD4 IMP-QD4-005 DISCREPANCY-4 (dim.json cdg=false, probes emit CDG flags). QD5 IMP-QD5-003 (all 7 cdg_flags:[] hardcoded). QD7 IMP-QD7-001 + IMP-QD7-007 D-010. **Plus QD6 IMP-QD6-001 (CDG-DELETE-DATA triple-blocked).**

### Mô tả
CDG (Critical Decision Gate, CORE-027) là governance mechanism quan trọng — user phải approve TRƯỚC KHI auto-fix áp dụng CRITICAL changes. **4 dims xác nhận CDG không được wire hoặc bị broken** → auto-fix chạy mà không cần user approval cho critical operations.

### CDG Gap per dim

| Dim | Status | Specific gap | Risk level | Evidence |
|---|---|---|---|---|
| QD3 | **Partial** — only `secret-detection` cdg=true | 6/7 probes spec khai báo `CDG-SECURITY-LIVE` cho CRITICAL signals nhưng dim.json chỉ enable secret-detection | CDG breaks for auth bypass, SQL injection, deserialization when implemented | IMP-QD3-003 DISCREPANCY-3 Phase 2 AF-QD3-05 |
| QD4 | **Broken** — dim.json cdg=false nhưng probes emit CDG flags | `api-latency-probe`, `db-query-analysis`, `core-web-vitals` dim.json `cdg=false` mâu thuẫn probe behavior | Orchestrator không biết QD4 có CDG → CDG decisions bypass QD4 signals | IMP-QD4-005 Phase 1 DISCREPANCY-4 |
| QD5 | **Fully missing** — all 7 probes `cdg_flags: []` | Keyboard trap, focus loss trên primary flow, WCAG Level A violations không trigger CDG | CRITICAL a11y issues → auto-fix không có user review | IMP-QD5-003 Phase 2 Tables A-G all confirm cdg_flags:[] + Phase 4 CASCADE-QD5-002 |
| QD6 | **Triple blocked** — D5 dim.json cdg=false + D11 cdg_flags:[] + IMPL-REFUTED | P-QD6-migration-integrity: `DROP TABLE`/`DROP COLUMN` signals emitted, CDG-DELETE-DATA triple-blocked | **DATA LOSS RISK** — destructive migration auto-fixed without user approval | IMP-QD6-001 CDG-DELETE-DATA CASCADE-QD6-001 **P0 CRITICAL** |
| QD7 | **Missing + conflict** — IMP-QD7-001 fully missing + IMP-QD7-007 bash conflict | Bash line 210 emits `CDG-DEPS-DOWN` nhưng dim.json `cdg: false`; api-version breaking change CRITICAL blocks release | CDG orchestration layer inconsistent for QD7 | IMP-QD7-001 + IMP-QD7-007 Phase 1 D-006 + D-010 |

### Impact
- **DATA LOSS RISK (P0 CRITICAL):** QD6 migration signals với DROP TABLE → auto-fix không cần approval (IMP-QD6-001)
- Security blind spot: QD3 auth bypass, SQL injection auto-fixed (CORE-027 violation)
- A11y regressions: QD5 keyboard trap removed without user review → WCAG compliance
- Performance: QD4 CDG bypass → high-impact perf regressions auto-applied

### Root cause
- Không có CDG canonical pattern được define cho lanes
- dim.json `cdg` field có thể sai (QD4 broken), absent (QD5), hay contradictory (QD7)
- Bash EMIT() helpers không pass `cdg_flags` parameter (QD6 D11)
- Per-probe CDG vs dimension-level CDG gate chưa được clarify (QD3 DISCREPANCY-3)

### Recommendation tổng quát
- **Phase 1:** Fix QD6 CDG-DELETE-DATA ngay (DATA LOSS RISK — 3 file edits: dim.json + probe spec + bash EMIT())
- **Phase 2:** Define CDG canonical pattern cross-lane: per-signal CDG decision (probe spec) wins over dim.json gate
- **Phase 3:** Wire CDG cho QD3 (6 probes), QD4 (3 probes), QD5 (keyboard trap + WCAG A), QD7 (api-version breaking)
- Per-file CDG dedup key `{file_path, session_id}` — fire CDG once per file (IMP-QD3-012)

---

## Theme 10: Bash Probe Dispatch Missing ✅ VERIFIED (3 dims: QD2/QD4/QD6) [NEW]

> **Stage 1 evidence:** QD2 IMP-QD2-001 (phantom PROBE_ID + no dispatch). QD4 IMP-QD4-010 (hybrid dispatch inconsistency). QD6 IMP-QD6-010/011 (no dispatch + phantom PROBE_ID — 6× signal inflation confirmed).

### Mô tả
Bash scripts không implement probe-ID dispatch: tất cả probe IDs nhận same bash execution path, phantom PROBE_IDs không có trong `dimension.json`. Kết quả: sai signals gán cho sai probe, metrics hoàn toàn không đáng tin.

### Evidence per dim

| Dim | Issue | Impact | Evidence |
|---|---|---|---|
| QD2 | `PROBE_ID="P-QD2-business-logic-audit"` hardcoded phantom không có trong dimension.json 5 probes. Không có `case "$PROBE_ID"` dispatch | Mọi bash signals emitted với sai probe_id → triage/aggregation broken → QD2 static results INVISIBLE to orchestrator | IMP-QD2-001 D2 Phase 1 bash line 29 |
| QD4 | Hybrid architecture: `render-perf-check` + `memory-leak-scan` static checks KHÔNG trong `wf-fix-probe-static-perf.sh` — separate logic, no `--probe` dispatch consistent với QD2/QD3 pattern | Hard to maintain; probe routing unclear; static checks can't be called per probe ID | IMP-QD4-010 Phase 1 DISCREPANCY-10 |
| QD6 | `PROBE_ID="P-QD6-data-integrity-audit"` (line 30) phantom. `--probe` arg chỉ override label không dispatch logic. Orchestrator call bash 1 lần per probe ID = **6× invocations × 3 EF Core checks = 18 signals** per session với wrong attribution | 6× signal inflation, metrics completely unreliable | IMP-QD6-010/011 D9/D10 Phase 2 + Phase 4 CASCADE-QD6-003 CONFIRMED |

### Impact
- QD2 entire static layer INVISIBLE to orchestrator (triage/aggregate broken)
- QD6 18 signals per session thay vì 3 → metrics inflation 6× → wrong priority all findings
- QD4 dispatch inconsistency → maintainability burden khi add new probes

### Root cause
- Bash scripts thiếu `case "$PROBE_ID"` dispatch block (như QD3 pattern which works correctly)
- Default `PROBE_ID` hardcoded với phantom values không verify vs `dimension.json`
- Orchestrator không enforce valid probe IDs trước khi call bash

### Recommendation tổng quát
- Standardize: copy QD3 `case "$PROBE_ID"` dispatch pattern cho QD2/QD4/QD6
- Add `--probe` required validation + fail-fast when probe_id not in valid dispatch list
- MERGE: IMP-QD2-001 + IMP-QD6-010/011 + IMP-QD4-010 → 1 global IMP "Bash Dispatch Standardization"
- Phantom PROBE_ID linter: add to `validate-schema-sync.sh` check

---

## Tổng số findings cross-cutting (Stage 2 Updated)

| Theme | Findings | Priority | Evidence Status | Dims confirmed |
|---|---:|:-:|:-:|:-:|
| 1. Stack detection bias | 10 | P0 | ✅ VERIFIED | 5 (QD1/QD2/QD3/QD4/QD6) |
| 2. Hardcoded thresholds | 9 | P1 | ✅ VERIFIED | 4 (QD1/QD4/QD5/QD7) |
| 3. i18n/l10n | 6 | P1 | ✅ VERIFIED | 3 (QD1/QD5/QD7) |
| 4. Schema validation | 8 | P2 | ✅ VERIFIED | 3 (QD1/QD2/QD6) |
| 5. Cross-probe interaction | 17 | P1 | ✅ VERIFIED | 7 (ALL dims) |
| 6. Agent cost/quality | 5 | P2 | ✅ VERIFIED | 4 (QD1/QD2/QD3/QD5) |
| 7. SPEC-ONLY probe gap | 7 | P1 | ✅ VERIFIED | 7 (ALL dims) |
| 8. Signal schema fork | 6 | **P0** | ✅ VERIFIED | 4 (QD1/QD2/QD3/QD6) |
| 9. CDG governance gap | 5 | **P0** | ✅ VERIFIED | 5 (QD3/QD4/QD5/QD6/QD7) |
| 10. Bash dispatch missing | 3 | **P0** | ✅ VERIFIED | 3 (QD2/QD4/QD6) |

**Tổng Stage 2: 76 cross-cutting findings** (tăng từ 34 pre-seed), **10 themes ALL VERIFIED** — Gate G2 evidence requirement ✅ PASS.

**Themes ∈ {VERIFIED, DROPPED}: 10/10 VERIFIED, 0 DROPPED, 0 TENTATIVE.**

**Gate G2 ready:** Tất cả themes VERIFIED → `10-improvement-roadmap.md` có thể lock IMPs dựa trên cross-cutting evidence này.

### Merge summary cho roadmap

| Global Cluster | Dims | IMPs to merge | Description |
|---|---|---|---|
| **execution_order** | 7/7 | QD1-008 + QD2-007 + QD3-009 + QD4-004/011/012 + QD5-013 + QD6-015 + QD7-002 | 1 global IMP add `execution_order/parallel_groups` to all dim.json |
| **signal schema fork** | 4 | QD1-007 + QD2-006 + QD3-006 + QD6-009 | 1 global IMP unify signal-v2 schema (translator/adapter) |
| **cross-probe dedup** | 6 | QD1-011 + QD2-013 + QD3-011 + QD5-014 + QD6-004+014 + QD7-013 | 1 global IMP unified dedup_hints namespace |
| **CDG governance** | 5 | QD3-003 + QD4-005 + QD5-003 + QD6-001 + QD7-001/007 | 1 global IMP CDG canonical pattern (QD6-001 P0 CRITICAL first) |
| **bash dispatch** | 3 | QD2-001 + QD4-010 + QD6-010/011 | 1 global IMP bash dispatch standardization |
| **EXCLUDE_PATTERN** | 2 | QD5-015 + QD7-010 | 1 global IMP config-driven exclude patterns |
| **tech stack** | 5 | QD1-001 + QD2-005 + QD3-004 + QD6-005 | Language adapter framework |
| **i18n CTA/locale** | 3 | QD1-002 + QD5-012 + QD7-009 | Locale-aware probe dictionary |
