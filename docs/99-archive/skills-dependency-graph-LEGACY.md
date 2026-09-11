# MCV3 Skills Dependency Graph

> 32 workflow skills (gồm 13 spawned dimension lanes) · 3 legacy pipelines · 2 incremental skills · 2 standalone (scan + diagram) · 1 linear phases system
>
> Auto-generated from `_contract.json` files in `.claude/skills/workflow/*/`
> Source: `cross_skill_contracts.produces_for` / `consumes_from`

---

## Dependency Graph (Linear Flow)

```
[LEGACY PATH — optional]
wf-legacy-scan (pre-phase0)
  └── wf-legacy-classify (pre-phase0)
        └── wf-legacy-extract (pre-phase0)
              ├──→ wf-brainstorm (phase0)
              ├──→ wf-analyze-requirements (phase1)
              ├──→ wf-define-features (phase2)
              ├──→ wf-design (phase3)
              └──→ wf-annotate-code (post-phase3)

[STANDARD PATH]
wf-brainstorm (phase0-brainstorm)
  └──→ wf-analyze-requirements (phase1-business)
          └──→ wf-define-features (phase2-features)
                    └──→ wf-design (phase3-architecture)
                              ├──→ wf-design-ux (phase4-ux)
                              │         └──→ wf-plan-modules (phase5-implementation)
                              └──→ wf-plan-modules (phase5-implementation)
                                          └──→ wf-implement-feature (phase5)
                                                    ├──→ wf-preflight (cross-phase)
                                                    │         ├──→ wf-fix-bugs (pure orchestrator — spawns 11 dimension lanes QD1–QD11 → wf-fix-triage → wf-fix-execute)
                                                    │         └──→ wf-verify-sync (cross-phase)
                                                    └──→ wf-verify-sync (cross-phase)
                                                                  └──→ wf-prepare-deployment (phase6)

[POST-PHASE3 — legacy annotation]
wf-annotate-code (post-phase3)
  ├──→ wf-design-ux
  └──→ wf-plan-modules

[INCREMENTAL — cross-phase]
wf-add-scope (incremental scope)
  └──→ wf-define-features (flesh-out)
  └──→ wf-plan-modules (re-run)

wf-manage-change (cross-phase — after registry)
  ├──→ wf-preflight (verify after change)
  └──→ wf-verify-sync (sync check)

[STANDALONE — không thuộc main pipeline]
wf-scan-target (any time, optional inputs cho consumer skills via --from-scan)
  ├──→ wf-add-scope (--from-scan — auto-seed modules + features)
  ├──→ wf-define-features (--from-scan — feature suggestions)
  ├──→ wf-design (--from-scan — gap-analysis baseline)
  └──→ wf-implement-feature (context priming)
```

---

## Phase Layers

### pre-phase0 — Legacy Discovery (optional)

| Skill | Description | Produces for |
|-------|-------------|-------------|
| **wf-legacy-scan** | Scan toàn diện dự án hiện có | wf-legacy-classify, wf-legacy-extract, wf-brainstorm..wf-annotate-code |
| **wf-legacy-classify** | Phân loại files thành systems/modules, tạo glossary | wf-legacy-extract |
| **wf-legacy-extract** | Trích xuất requirements và features từ classified modules | wf-brainstorm, wf-analyze-requirements, wf-define-features, wf-design, wf-annotate-code |

### phase0-brainstorm

| Skill | Description | Consumes from | Produces for |
|-------|-------------|---------------|-------------|
| **wf-brainstorm** | Entry point — chốt khung dự án và tạo Phase 0 docs | *(entry — no deps)* | wf-analyze-requirements |

**Key outputs:**
- `.mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md`
- `.mc-data/docs/phase0-brainstorm/P0-02-systems-users.md`
- `.mc-data/docs/_meta/req-registry.json` *(seeded)*
- `.mc-data/docs/_meta/project-digest.json`

### phase1-business

| Skill | Description | Consumes from | Produces for |
|-------|-------------|---------------|-------------|
| **wf-analyze-requirements** | Multi-agent requirements analysis | wf-brainstorm | wf-define-features |

**Key outputs:**
- `.mc-data/docs/phase1-business/P1-01-project-overview.md`
- `.mc-data/docs/phase1-business/P1-02-business-workflow.md`
- `.mc-data/docs/phase1-business/departments/**/*.md`
- `.mc-data/docs/_meta/dept-digests.json`
- `.mc-data/docs/_meta/phase1-handoff.json`

### phase2-features

| Skill | Description | Consumes from | Produces for |
|-------|-------------|---------------|-------------|
| **wf-define-features** | Map requirements → feature specs | wf-analyze-requirements | wf-design |

**Key outputs:**
- `.mc-data/docs/phase2-features/**/**/*.md`
- `.mc-data/docs/_meta/feature-briefs.json`

### phase3-architecture

| Skill | Description | Consumes from | Produces for |
|-------|-------------|---------------|-------------|
| **wf-design** | Architecture, API, database design | wf-define-features | wf-design-ux, wf-plan-modules |
| **wf-annotate-code** | Inject REQ-ID comments vào code *(legacy only)* | wf-design, wf-legacy-extract | wf-design-ux, wf-plan-modules |

**Key outputs (wf-design):**
- `.mc-data/docs/phase3-architecture/P3-01-architecture.md`
- `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md`
- `.mc-data/docs/phase3-architecture/technical-specs/database-design.md`
- `.mc-data/docs/phase3-architecture/technical-specs/integration-map.md`
- `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md`
- `.mc-data/docs/_meta/design-input-digest.json`

### phase4-ux

| Skill | Description | Consumes from | Produces for |
|-------|-------------|---------------|-------------|
| **wf-design-ux** | UX/UI design (skip nếu api-only) | wf-design, wf-annotate-code | wf-plan-modules |

**Key outputs:**
- `.mc-data/docs/phase4-ux/design-system.md`
- `.mc-data/docs/phase4-ux/*/Navigation-*.md`
- `.mc-data/docs/_meta/ux-input-digest.json`

### phase5-implementation

| Skill | Description | Consumes from | Produces for |
|-------|-------------|---------------|-------------|
| **wf-plan-modules** | Dependency analysis, implementation plans | wf-design, wf-design-ux | wf-implement-feature |
| **wf-add-scope** | Thêm scope vào registry (append-only) | wf-legacy-scan (optional), req-registry.json | wf-define-features, wf-plan-modules |
| **wf-implement-feature** | Triển khai code theo TDD | wf-plan-modules, wf-define-features | wf-preflight, wf-verify-sync |

**Key outputs (wf-plan-modules):**
- `.mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md`
- `.mc-data/docs/phase5-implementation/tasks/**/**/*-impl.md`

### cross-phase — Quality Gates

| Skill | Description | Consumes from | Produces for |
|-------|-------------|---------------|-------------|
| **wf-preflight** | Health check: registry + docs + code + tests | wf-implement-feature | wf-fix-bugs, wf-verify-sync |
| **wf-fix-bugs** | **Pure orchestrator (v5.0):** delegate tuần tự wf-fix-discover → wf-fix-triage → wf-fix-execute. KHÔNG có procedures/templates riêng | wf-preflight | wf-verify-sync |
| **wf-fix-discover** *(spawned)* | Phase 0 Session Init + Phase 1 Discovery 5-Layer — produces fix-status + issue-registry + feature-states | wf-fix-bugs (spawner) | wf-fix-triage |
| **wf-fix-triage** *(spawned)* | Phase 2 Triage — classify severity + fixability, generate bug-triage.md + fix-plan.md + init fix-log | wf-fix-discover output | wf-fix-execute |
| **wf-fix-execute** *(spawned)* | Phase 3 Fix + Phase 4 Docs Sync + Phase 5 Verify Loop + Phase 6 Report — produces fix-log + fix-report + phase-summary + registry safe-update | wf-fix-triage output | wf-verify-sync |
| **wf-verify-sync** | Kiểm tra đồng bộ REQ-IDs giữa requirements và code | wf-implement-feature, wf-preflight, wf-fix-bugs | wf-prepare-deployment |

### phase6-deployment

| Skill | Description | Consumes from | Produces for |
|-------|-------------|---------------|-------------|
| **wf-prepare-deployment** | Tạo deployment guide, user guide, maintenance | wf-verify-sync | *(terminal)* |

### incremental — Scope & Change Management

| Skill | Description | Consumes from | Produces for |
|-------|-------------|---------------|-------------|
| **wf-add-scope** | Thêm modules + features vào registry (append-only) | wf-legacy-scan (module-code-mapping), req-registry.json | wf-define-features (flesh-out), wf-plan-modules (re-run) |
| **wf-manage-change** | Xử lý thay đổi/bổ sung/sửa đổi tính năng — phân tích impact → execute → verify | req-registry.json, docs, code | wf-preflight, wf-verify-sync |

### standalone — Target Scanning

| Skill | Description | Consumes from | Produces for |
|-------|-------------|---------------|-------------|
| **wf-scan-target** | Standalone — quét 1 module/hệ thống/URL/path; trả về module-map, feature-inventory, target-map.json (v2 schema), gap-report (khi `--compare`) | *(entry — no deps)* | wf-add-scope (--from-scan), wf-define-features (--from-scan), wf-design (--from-scan), wf-implement-feature (context priming) |

**Key outputs:**
- `.mc-data/work/wf-scan-target/sessions/{id}/module-map.md`
- `.mc-data/work/wf-scan-target/sessions/{id}/target-map.json` *(v2 schema: scan_fingerprint, scan_diff, traceability, module_code_mapping, consumer_hints)*
- `.mc-data/work/wf-scan-target/sessions/{id}/feature-inventory.md`
- `.mc-data/work/wf-scan-target/sessions/{id}/phase-summary.md`
- `.mc-data/work/wf-scan-target/sessions/{id}/gap-report.md` *(chỉ khi `--compare`)*

---

## Cross-Skill Data Flow (Key Contracts)

```
wf-brainstorm
  produces: req-registry.json (seed), project-digest.json, P0-01, P0-02
  ──────────────────────────────────────────────────────────────────────→
                                                        wf-analyze-requirements
                                                          consumes: P0-01, P0-02, req-registry
                                                          produces: dept-digests, phase1-handoff
                                                        ──────────────────→
                                                                        wf-define-features
                                                                          consumes: phase1-handoff, dept-digests
                                                                          produces: feature-briefs
                                                                        ──────────────→
                                                                                wf-design
                                                                                  consumes: feature-briefs
                                                                                  produces: design-input-digest
```

---

## Registry as Shared State

`req-registry.json` is the central shared mutable artifact — written by multiple skills:

| Stage | Writer | Fields added |
|-------|--------|-------------|
| wf-brainstorm | seed | project, departments, interface_type |
| wf-analyze-requirements | update | requirements[], REQ-IDs |
| wf-define-features | update | features[] |
| wf-design | update | architecture decisions |
| wf-implement-feature | update | implementation status |

All reads must go through registry. NEVER create standalone docs that bypass it.

---

## Skill Count Summary

| Phase | Skills |
|-------|--------|
| pre-phase0 (legacy) | 3 |
| phase0–phase6 (standard) | 11 |
| cross-phase (quality) | 3 |
| post-phase3 (annotation) | 1 |
| incremental (scope + change) | 2 |
| standalone (scan-target + diagram) | 2 |
| spawned by wf-fix-bugs (triage + execute + 11 dimension lanes QD1–QD11) | 13 |

> **Total wf-* skills (workflow/):** 11 standard + 4 legacy + 2 incremental + 2 standalone + 13 spawned = **32**.
> Plus 8 utility + 3 orchestrator = **43 lệnh tổng**.

---

*Generated: 2026-04-12 (updated 2026-05-12 — wf-fix-bugs v9.1.x: 11 dimension lanes QD1–QD11 + wf-diagram standalone) | Source: `.claude/skills/workflow/*/_contract.json`*
