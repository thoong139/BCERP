# 11 — Output Path Contract (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC (CORE-007, CORE-030, CORE-035)
> **File gốc canonical:** [`.claude/skills/protocols/21-cross-skill-output-path-contract.md`](../../.claude/skills/protocols/21-cross-skill-output-path-contract.md), [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4b
> **Mục đích:** Bảng tổng kết toàn bộ paths `.mc-data/` — ai tạo, ai consume, format chuẩn

---

## 1. Triết lý — tại sao cần Output Path Contract?

Trước CORE-007, mỗi skill tự đặt output path. Hệ quả:
- Skill A đổi path output → Skill B (downstream) PRE-GATE fail
- 2 skills cùng ghi 1 path → race condition, output không deterministic
- User không biết đâu là canonical path khi đọc reports

**CORE-007** chốt: paths giữa các skills PHẢI khớp 1-1 contract. Mỗi path có **đúng 1 producer + ≥1 consumers**.

File này là **mirror tổng kết** từ Protocol 21 — bảng đầy đủ tại canonical file.

---

## 2. Cấu trúc tổng thể `.mc-data/`

```
.mc-data/
├── docs/                                # ★ TÀI LIỆU CHÍNH THỨC (Phase 0-6)
│   ├── _meta/                           # Metadata + SSOT
│   │   ├── req-registry.json            # ★ SSOT (CORE-004)
│   │   ├── project-digest.json          # wf-brainstorm Phase 3
│   │   ├── dept-digests.json            # wf-analyze-requirements Phase 3
│   │   ├── phase1-handoff.json          # wf-analyze-requirements Phase 3
│   │   ├── feature-briefs.json          # wf-define-features Phase 3
│   │   ├── design-input-digest.json     # wf-design Phase 3
│   │   ├── ux-input-digest.json         # wf-design-ux Phase 3
│   │   ├── verify-sync.md               # wf-verify-sync Phase 7
│   │   └── decision-registry.global.json # wf-implement-feature Phase 3.5
│   │
│   ├── phase0-brainstorm/               # wf-brainstorm output
│   ├── phase1-business/                 # wf-analyze-requirements output
│   │   ├── departments/
│   │   ├── stakeholder-review.md
│   │   └── ...
│   ├── phase2-features/                 # wf-define-features output
│   │   └── [sys]/[mod]/[feat].md
│   ├── phase3-architecture/             # wf-design output
│   ├── phase4-ux/                       # wf-design-ux output
│   ├── phase5-implementation/           # wf-plan-modules output
│   │   ├── module-plan.md
│   │   ├── dependency-graph.md
│   │   ├── P5-00-implementation-roadmap.md
│   │   ├── sprints/S[NN]-[name].md
│   │   └── tasks/[sys]/[mod]/[feat]-impl.md
│   └── phase6-deployment/               # wf-prepare-deployment output
│
├── work/                                # ★ RUNTIME ARTIFACTS (per-skill)
│   ├── _trace/
│   │   └── session-log.json             # CORE-026 — global trace
│   │
│   ├── wf-brainstorm/
│   │   └── legacy-decisions.json        # Phase 0.5.7 — bridge LEGACY
│   │
│   ├── wf-analyze-requirements/
│   │   ├── deferred-issues.md
│   │   └── sessions/{id}/...
│   │
│   ├── wf-define-features/
│   │   ├── deferred-findings.md
│   │   ├── ui-coverage-gaps.json
│   │   └── sessions/{id}/...
│   │
│   ├── wf-design/
│   │   ├── deferred-findings.md
│   │   └── sessions/{id}/...
│   │
│   ├── wf-design-ux/
│   │   └── sessions/{id}/...
│   │
│   ├── wf-plan-modules/
│   │   └── sessions/{id}/...
│   │
│   ├── wf-implement-feature/
│   │   ├── {sys-slug}/{feat-slug}/
│   │   │   ├── sessions/{id}/impl-status.json
│   │   │   └── current.txt
│   │   └── .history/implementations-index.jsonl
│   │
│   ├── wf-preflight/
│   │   ├── sessions/{id}/
│   │   │   ├── preflight-report.md
│   │   │   ├── preflight-impact.json    # schema preflight-impact-v1
│   │   │   ├── preflight-status.json
│   │   │   └── phase-summary.md
│   │   └── _index/sessions.jsonl
│   │
│   ├── wf-fix-bugs/
│   │   ├── sessions/{YYYY-MM-DD-{scope}-{slug}-{NN}}/
│   │   │   ├── fix-status.json
│   │   │   ├── session-log.json
│   │   │   ├── error-ledger.json
│   │   │   ├── .lock
│   │   │   ├── bug-dashboard.md
│   │   │   ├── phase1-init/...
│   │   │   ├── phase2-scan/...
│   │   │   ├── phase3-plan/...
│   │   │   ├── phase4-find-bugs/lanes/QD*/...
│   │   │   ├── phase5-triage/...
│   │   │   ├── phase6-execute/...
│   │   │   └── phase7-verify/
│   │   │       └── fix-impact.json      # schema fix-impact-v1
│   │   ├── _index/sessions.jsonl
│   │   └── fix-history.md
│   │
│   ├── wf-verify-sync/
│   │   ├── sessions/{id}/
│   │   │   ├── verify-sync.md
│   │   │   └── verify-sync-impact.json
│   │   └── ui-coverage-report.md
│   │
│   ├── wf-manage-change/
│   │   ├── {change-id}/
│   │   │   ├── change-report.md
│   │   │   ├── change-impact.json       # schema change-impact-v1
│   │   │   └── phase-summary.md
│   │   ├── _index/sessions.jsonl
│   │   └── .locks/registry.lock
│   │
│   ├── wf-add-scope/
│   │   ├── sessions/{id}/
│   │   │   ├── scope-impact.json
│   │   │   └── add-scope-status.json
│   │   └── _index/sessions.jsonl
│   │
│   ├── wf-scan-target/
│   │   └── sessions/{id}/
│   │       ├── target-map.json
│   │       ├── feature-inventory.md
│   │       └── module-map.md
│   │
│   ├── wf-cmi/                          # Cross-Module Integrity
│   │   ├── business-invariants.json     # ★ CANONICAL SIDECAR (APPEND-only, audit_chain)
│   │   ├── sessions/{YYYY-MM-DD-{scope}-{slug}-{NN}}/
│   │   │   ├── integrity-status.json
│   │   │   ├── session-log.json
│   │   │   ├── error-ledger.json
│   │   │   ├── .lock
│   │   │   ├── phase1-init/...
│   │   │   ├── phase2-discovery/
│   │   │   │   ├── entity-graph.json
│   │   │   │   ├── module-graph.json
│   │   │   │   ├── workflow-graph.json
│   │   │   │   ├── api-graph.json
│   │   │   │   ├── event-graph.json
│   │   │   │   └── rbac-matrix.json
│   │   │   ├── phase3-invariant-artifact/business-invariants.json  # DRAFT
│   │   │   ├── phase4-coverage-dispatch/lanes/CD*/signals.json + lane-status.json + CD-report.md
│   │   │   ├── phase5-aggregate/coverage-matrix.json + coverage-report.md
│   │   │   ├── phase6-regression/regression-map.json + regression-report.md
│   │   │   ├── phase7-gap-cdg/gap-suggestions.json + gap-report.md
│   │   │   └── phase8-report/
│   │   │       ├── integrity-report.md  # PRIMARY user-facing
│   │   │       └── integrity-impact.json  # schema integrity-impact-v1
│   │   └── _index/sessions.jsonl
│   │
│   ├── legacy-scan/                     # wf-legacy-* skills shared
│   │   ├── ledger.json
│   │   ├── project-profile.json
│   │   ├── project-context.md           # CORE-021 LEGACY_MODE anchor
│   │   ├── assessment-report.json
│   │   ├── domain-hints.json
│   │   ├── impact-graph.json            # ADR-LS14
│   │   ├── doc-quality-map.json
│   │   ├── impl-status-snapshot.json
│   │   ├── module-code-mapping.json     # Stage 3.5
│   │   ├── annotation-report.md
│   │   ├── inventory/
│   │   │   ├── screens.json
│   │   │   ├── api-endpoints.json
│   │   │   ├── source-files.json
│   │   │   ├── dependency-graph.json
│   │   │   ├── doc-files.json
│   │   │   ├── external-docs.json
│   │   │   ├── doc-classified.json
│   │   │   └── ui-manifest.json
│   │   ├── classified/
│   │   ├── extracted/
│   │   └── sessions/{id}/scan-state.json
│   │
│   ├── _e2e/                            # E2E pipeline shared
│   │   └── wf-fix-bugs-v7.4-e2e-report.md
│   │
│   └── _locks/                          # Cross-session R/W locks (Protocol 22)
│       └── {resource}.lock
│
├── sync/                                # REQ-ID sync tracking
│   └── ...
│
├── knowledge-base/                      # Optional notes
│   └── ...
│
└── cache/                               # Cross-session cache (opt-in)
    └── wf-legacy-scan/...
```

---

## 3. Bảng path chính theo phase

### 3.1. Phase 0 — Brainstorm

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/docs/phase0-brainstorm/` | wf-brainstorm | wf-analyze-requirements, wf-design-ux, wf-plan-modules |
| `.mc-data/docs/_meta/project-digest.json` | wf-brainstorm Phase 3 | wf-analyze-requirements Phase 0.1 |
| `.mc-data/work/wf-brainstorm/legacy-decisions.json` | wf-brainstorm Phase 0.5.7 | 13 downstream skills (LEGACY) |

### 3.2. Phase 1 — Business Requirements

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/docs/phase1-business/` | wf-analyze-requirements | wf-design-ux (legacy context) |
| `.mc-data/docs/phase1-business/stakeholder-review.md` | wf-analyze-requirements Phase 6c | wf-define-features Phase 0 |
| `.mc-data/docs/_meta/dept-digests.json` | wf-analyze-requirements Phase 3 | wf-define-features Phase 0.1 |
| `.mc-data/docs/_meta/phase1-handoff.json` | wf-analyze-requirements Phase 3 | wf-define-features Phase 0.1 |
| `.mc-data/work/wf-analyze-requirements/deferred-issues.md` | wf-analyze-requirements Phase 6d | wf-define-features Phase 0 |

### 3.3. Phase 2 — Features

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md` | wf-define-features Phase 2 | wf-design, wf-implement-feature, wf-fix-execute Phase 4 |
| `.mc-data/docs/_meta/feature-briefs.json` | wf-define-features Phase 3 | wf-design Phase 0.5, wf-implement-feature Phase 0 |
| `.mc-data/work/wf-define-features/deferred-findings.md` | wf-define-features Phase 4 | wf-design Phase 0 (optional) |
| `.mc-data/work/wf-define-features/ui-coverage-gaps.json` | wf-define-features Phase 2.7 | wf-design-ux, wf-plan-modules |

### 3.4. Phase 3 — Architecture

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/docs/phase3-architecture/` | wf-design | wf-design-ux, wf-plan-modules, all downstream |
| `.mc-data/docs/phase3-architecture/stakeholder-review.md` | wf-design Phase 4b | wf-design-ux Phase 0 |
| `.mc-data/docs/_meta/design-input-digest.json` | wf-design Phase 3 | wf-design-ux, wf-plan-modules, wf-implement-feature |
| `.mc-data/work/wf-design/deferred-findings.md` | wf-design Phase 4c | wf-plan-modules Phase 0 |
| `req-registry.json` (`design_status`) | wf-design | wf-plan-modules |

### 3.5. Phase 4 — UX

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/docs/phase4-ux/design-system.md` | wf-design-ux Phase 1 | wf-plan-modules Phase 0 (if not api-only) |
| `.mc-data/docs/phase4-ux/[sys]/Navigation-*.md` | wf-design-ux Phase 2 | wf-plan-modules |
| `.mc-data/docs/phase4-ux/stakeholder-review.md` | wf-design-ux Phase 5 | wf-plan-modules |
| `.mc-data/docs/phase4-ux/existing-ui-analysis.md` (legacy) | wf-design-ux (legacy flow) | wf-plan-modules |
| `.mc-data/docs/_meta/ux-input-digest.json` | wf-design-ux Phase 3 | wf-plan-modules Phase 0.5 |

### 3.6. Phase 5 — Implementation Plans

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/docs/phase5-implementation/module-plan.md` | wf-plan-modules Phase 7 | wf-implement-feature (reference) |
| `.mc-data/docs/phase5-implementation/dependency-graph.md` | wf-plan-modules Phase 7 | wf-implement-feature (reference) |
| `.mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md` | wf-plan-modules Phase 7 | wf-implement-feature (reference) |
| `.mc-data/docs/phase5-implementation/sprints/S[NN]-[name].md` | wf-plan-modules Phase 7 | wf-implement-feature (sprint context) |
| `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md` | wf-plan-modules Phase 7.5 | wf-implement-feature Phase 1-2 |
| `.mc-data/docs/phase5-implementation/stakeholder-review.md` | wf-plan-modules Phase 7b | wf-implement-feature Phase 0 |

### 3.7. Implementation runtime

| Path | Producer | Consumer |
|------|----------|----------|
| `req-registry.json` (`impl_status`) | wf-implement-feature Phase 6 (PRIMARY) | wf-preflight Phase 4, wf-verify-sync |
| `.mc-data/work/wf-implement-feature/{sys}/{feat}/sessions/{id}/impl-status.json` (schema v2.0) | wf-implement-feature Session | wf-preflight, wf-verify-sync, wf-prepare-deployment, wf-fix-bugs (via `--from-impl`) |
| `.mc-data/work/wf-implement-feature/.history/implementations-index.jsonl` | wf-implement-feature | Audit trail, status skill |
| `.mc-data/work/wf-implement-feature/{sys}/{feat}/current.txt` | wf-implement-feature | `--resume` routing |
| `.mc-data/docs/_meta/decision-registry.global.json` (APPEND) | wf-implement-feature Phase 3.5 | All future implementations Phase 0.5b |

### 3.8. Preflight & Verify Sync

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/work/wf-preflight/sessions/{id}/preflight-report.md` | wf-preflight Phase 7 | wf-fix-bugs Phase 1, wf-verify-sync |
| `.mc-data/work/wf-preflight/sessions/{id}/preflight-impact.json` (schema preflight-impact-v1) | wf-preflight Phase 7 | OPT-IN: wf-fix-bugs, wf-prepare-deployment, wf-verify-sync (via `--from-preflight`) |
| `.mc-data/docs/_meta/verify-sync.md` | wf-verify-sync Phase 7 | wf-prepare-deployment Phase 0 |
| `.mc-data/work/wf-verify-sync/sessions/{id}/verify-sync-impact.json` | wf-verify-sync Phase 6 | OPT-IN: wf-prepare-deployment, wf-fix-bugs, wf-implement-feature (via `--from-verify-sync`) |

### 3.9. Fix Bugs pipeline

| Path | Producer | Consumer |
|------|----------|----------|
| `$SESSION_DIR/fix-status.json` | wf-fix-bugs Phase 1 step 5 | wf-fix-triage, wf-fix-execute, resume routing |
| `$SESSION_DIR/issue-registry.json` (v2 schema) | wf-fix-bugs Phase 1 step 1.2 | wf-fix-triage, wf-fix-execute |
| `$SESSION_DIR/phase4-find-bugs/lanes/QD*/signals.json` | Lane agents (QD1-QD11) | Aggregator Phase 1 step 1.2 |
| `$SESSION_DIR/phase5-triage/bug-triage.md`, `fix-plan.md` | wf-fix-triage Phase 2 | wf-fix-execute Phase 3 |
| `$SESSION_DIR/phase6-execute/fix-report.md` | wf-fix-execute Phase 6 | wf-verify-sync (optional) |
| `$SESSION_DIR/phase6-execute/docs-sync-report.json` | wf-fix-execute Phase 4a | wf-verify-sync (via `--from-fix-bugs` v2.1+) |
| `$SESSION_DIR/phase7-verify/fix-impact.json` (schema fix-impact-v1) | wf-fix-bugs Phase 7 | wf-verify-sync, wf-prepare-deployment, wf-implement-feature (via `--from-fix-bugs`) |
| `.mc-data/work/wf-fix-bugs/fix-history.md` | wf-fix-execute | Cross-session audit log |
| `.mc-data/work/wf-fix-bugs/_index/sessions.jsonl` | wf-fix-bugs | `--status`, `--resume` discovery |

### 3.10. Phase 6 — Deployment

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/docs/phase6-deployment/` | wf-prepare-deployment | Release/Go-Live |
| `.mc-data/docs/phase6-deployment/stakeholder-review.md` | wf-prepare-deployment Phase 5a | Release/Go-Live |

### 3.11. Legacy pipeline

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/work/legacy-scan/project-context.md` | wf-legacy-scan Stage 4 | CORE-021 LEGACY_MODE detection — tất cả shared skills |
| `.mc-data/work/legacy-scan/ledger.json` | wf-legacy-scan | wf-legacy-classify |
| `.mc-data/work/legacy-scan/project-profile.json` | wf-legacy-scan Stage 0 | wf-legacy-classify, wf-legacy-extract, wf-annotate-code |
| `.mc-data/work/legacy-scan/inventory/*.json` | wf-legacy-scan Stage 1 | wf-legacy-extract |
| `.mc-data/work/legacy-scan/module-code-mapping.json` | wf-legacy-extract Stage 3.5 | wf-analyze-requirements, wf-annotate-code, wf-design (legacy gap analysis), wf-add-scope |
| `.mc-data/work/legacy-scan/domain-hints.json` | wf-legacy-scan IPS-B (v5.0) | wf-legacy-classify, wf-legacy-extract, wf-design |
| `.mc-data/work/legacy-scan/gap-report.md` | wf-design (legacy gap analysis) | wf-plan-modules, wf-annotate-code |
| `.mc-data/work/legacy-scan/impact-graph.json` (v5.0) | wf-legacy-scan L6 (conditional) | wf-verify-sync, wf-fix-bugs (optional seed) |
| `.mc-data/work/legacy-scan/annotation-report.md` | wf-annotate-code | wf-plan-modules Phase 1.5 |

### 3.12. Scope changes

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/work/wf-add-scope/sessions/{id}/scope-impact.json` | wf-add-scope Phase 6 | OPT-IN: wf-verify-sync, wf-preflight, wf-implement-feature (via `--from-add-scope`) |
| `req-registry.json` (modules[], features[] APPEND) | wf-add-scope Phase 4 | wf-define-features, wf-plan-modules, wf-annotate-code |
| `.mc-data/work/wf-manage-change/{change-id}/change-impact.json` (schema change-impact-v1) | wf-manage-change Phase 6 | WIRED: wf-verify-sync, wf-preflight, wf-implement-feature (via `--from-manage-change`) |
| `.mc-data/work/wf-scan-target/sessions/{id}/target-map.json` | wf-scan-target Phase 5 | OPTIONAL: wf-add-scope, wf-define-features, wf-design, wf-implement-feature (via `--from-scan`) |

### 3.13. UI Coverage

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/work/legacy-scan/inventory/ui-manifest.json` | wf-legacy-scan Stage 1 | wf-legacy-extract, wf-define-features Phase 2.7 |
| `.mc-data/work/wf-verify-sync/ui-coverage-report.md` | wf-verify-sync Phase 5b | wf-prepare-deployment Phase 0 |

### 3.14. Cross-Module Integrity (wf-cmi)

> **Skill:** [`wf-cmi`](../../.claude/skills/workflow/wf-cmi/) v1.0.0 — Standalone Orchestrator, 8 phases, 10 lanes CD1-CD10. Sidecar artifact pattern (ADR-cmi-002 Revised — KHÔNG bump registry).

**Canonical sidecar (APPEND-only, ngoài sessions/{id}/):**

| Path | Producer | Consumer |
|------|----------|----------|
| `.mc-data/work/wf-cmi/business-invariants.json` (schema `business-invariants-v1`, APPEND-only sau CDG E094 ACCEPT, có `audit_chain.source_registry_checksum`) | wf-cmi Phase 7 (GAP + CDG) | OPT-IN: wf-fix-bugs `--from-cmi`, wf-verify-sync `--from-cmi`, wf-implement-feature `--from-cmi`, wf-prepare-deployment `--from-cmi`, wf-design `--from-cmi`, wf-add-scope `--from-cmi` |

**Session-scoped runtime (`$SESSION_DIR = .mc-data/work/wf-cmi/sessions/{YYYY-MM-DD-{scope}-{slug}-{NN}}/`):**

| Path | Producer | Consumer |
|------|----------|----------|
| `$SESSION_DIR/integrity-status.json` (schema `integrity-status-v1`, SSOT pipeline state) | wf-cmi Phase 1 step Init | wf-cmi (all subsequent phases + resume routing) |
| `$SESSION_DIR/phase2-discovery/entity-graph.json` (schema `entity-graph-v1`) | wf-cmi Phase 2 step #1 | Phase 3-7 (cross-reference) |
| `$SESSION_DIR/phase2-discovery/module-graph.json` (schema `module-graph-v1`) | wf-cmi Phase 2 step #2 | Phase 3-7 |
| `$SESSION_DIR/phase2-discovery/workflow-graph.json` (schema `workflow-graph-v1`) | wf-cmi Phase 2 step #3 | Phase 3-7 |
| `$SESSION_DIR/phase2-discovery/api-graph.json` (schema `api-graph-v1`, 3 clients erp-web/mobile-customer/mobile-staff) | wf-cmi Phase 2 step #4 | Phase 3-7 |
| `$SESSION_DIR/phase2-discovery/event-graph.json` (schema `event-graph-v1`, RabbitMQ + SignalR) | wf-cmi Phase 2 step #5 | Phase 3-7 |
| `$SESSION_DIR/phase2-discovery/rbac-matrix.json` (schema `rbac-matrix-v1`) | wf-cmi Phase 2 step #6 | Phase 3-7 |
| `$SESSION_DIR/phase3-invariant-artifact/business-invariants.json` (DRAFT, before CDG ACCEPT) | wf-cmi Phase 3 (3-pass LLM kế thừa QD11) | wf-cmi Phase 4-7 + canonical sidecar merge |
| `$SESSION_DIR/phase4-coverage-dispatch/lanes/CD*/signals.json` (schema `signals-v1`) | Lane agents CD1-CD10 | wf-cmi Phase 5 (aggregate) |
| `$SESSION_DIR/phase4-coverage-dispatch/lanes/CD*/lane-status.json` (schema `lane-status-v1`) | Lane agents CD1-CD10 | wf-cmi Phase 5 (completion check) |
| `$SESSION_DIR/phase5-aggregate/coverage-matrix.json` (schema `coverage-matrix-v1`, 10 dims + threshold) | wf-cmi Phase 5 | wf-cmi Phase 7 (gap detect), Phase 8 (report) |
| `$SESSION_DIR/phase6-regression/regression-map.json` (schema `regression-map-v1`, predictive/diff-aware) | wf-cmi Phase 6 (SKIP nếu profile=quick OR no `--since`) | wf-cmi Phase 8 (report) |
| `$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json` (schema `gap-suggestions-v1`, per-kind: test/invariant/contract/doc/validation) | wf-cmi Phase 7 | wf-cmi Phase 8 (report) |
| `$SESSION_DIR/phase8-report/integrity-report.md` (≤30 dòng tiếng Việt, 6 sections: coverage + violations + suggestions + regression + recommendation) | wf-cmi Phase 8 | User-facing PRIMARY |
| `$SESSION_DIR/phase8-report/integrity-impact.json` (schema `integrity-impact-v1`, $schema + `audit_chain.source` + checksum) | wf-cmi Phase 8 POST-GATE | **CROSS-SKILL:** wf-fix-bugs `--from-cmi`, wf-verify-sync `--from-cmi`, wf-implement-feature `--from-cmi`, wf-prepare-deployment `--from-cmi` |
| `$SESSION_DIR/Phase{N}-report.md` (N=1..8, CORE-028 ≤15 dòng tiếng Việt) | wf-cmi Phase {N} POST-GATE | User progress check |
| `.mc-data/work/wf-cmi/_index/sessions.jsonl` (APPEND-only) | wf-cmi (all phases) | `--status` display + `--resume` discovery |

---

## 4. Variable convention

```
$SESSION_DIR                = .mc-data/work/{skill}/sessions/{SESSION_ID}/
$SESSION_ID                 = YYYY-MM-DD-{scope}-{slug}-{NN}
{sys}, {mod}, {feat}        = slug từ registry (lowercase-kebab)
{NN}                        = sequence 2 digits
{id}                        = generic session ID
{change-id}                 = wf-manage-change session ID
{phase-name}                = init / scan / plan / find-bugs / triage / execute / verify
```

---

## 5. Path patterns

### 5.1. Documentation (read by humans + future skills)

```
.mc-data/docs/{phase-prefix}/{topic-or-slug}.md
```

| Phase | Prefix | Example |
|-------|--------|---------|
| 0 | `phase0-brainstorm/` | `P0-01-project-brief.md` |
| 1 | `phase1-business/` | `departments/sales/feature.md` |
| 2 | `phase2-features/` | `[sys]/[mod]/[feat].md` |
| 3 | `phase3-architecture/` | `P3-01-architecture.md` |
| 4 | `phase4-ux/` | `[sys]/Navigation-{topic}.md` |
| 5 | `phase5-implementation/` | `tasks/[sys]/[mod]/[feat]-impl.md` |
| 6 | `phase6-deployment/` | `deployment-{topic}.md` |
| meta | `_meta/` | `req-registry.json`, `*-digest.json` |

### 5.2. Runtime artifacts (skill internal)

```
.mc-data/work/{skill}/sessions/{SESSION_ID}/...
.mc-data/work/{skill}/_index/sessions.jsonl
.mc-data/work/{skill}/{global-aggregate}.md
```

### 5.3. Cross-skill artifacts (`*-impact.json` family)

| Artifact | Schema | Producer | Consumers (flag) |
|----------|--------|----------|------------------|
| `fix-impact.json` | fix-impact-v1 | wf-fix-bugs | `--from-fix-bugs` |
| `preflight-impact.json` | preflight-impact-v1 | wf-preflight | `--from-preflight` |
| `verify-sync-impact.json` | (TBD) | wf-verify-sync | `--from-verify-sync` |
| `change-impact.json` | change-impact-v1 | wf-manage-change | `--from-manage-change` |
| `scope-impact.json` | (TBD) | wf-add-scope | `--from-add-scope` |
| `integrity-impact.json` | integrity-impact-v1 | wf-cmi | `--from-cmi` |
| `business-invariants.json` (sidecar, canonical APPEND-only) | business-invariants-v1 | wf-cmi (CDG E094 ACCEPT) | `--from-cmi` |

**Quy tắc:**
- `--from-{skill}` flag để consume artifact tự nguyện (OPT-IN)
- Một số đã WIRED đầy đủ (vd: `--from-fix-bugs` v2.1+, `--from-manage-change` v4.1.0+)
- Schema PHẢI có `$schema` field + `audit_chain.source` + `audit_chain.checksum`

---

## 6. Quy tắc cứng

| ID | Quy tắc |
|----|---------|
| OPC-1 | Mỗi path có ĐÚNG 1 producer skill (mặc dù có thể có ≥1 consumers) |
| OPC-2 | Consumer skill PHẢI đọc đúng path từ producer skill — KHÔNG tự đổi path |
| OPC-3 | Khi cần đổi path → update CẢ producer + consumer + bảng này trong cùng 1 PR |
| OPC-4 | Cross-skill artifact (`*-impact.json`) PHẢI versioned + `audit_chain` (CORE-036) |
| OPC-5 | Session-scoped paths PHẢI dùng `$SESSION_DIR/...` không hardcode absolute |
| OPC-6 | Doc paths trong `.mc-data/docs/` là **canonical** — work paths có thể có copy (vd: phase-summary mirror) |
| OPC-7 | `_index/sessions.jsonl` PHẢI có cho mọi multi-session skill |
| OPC-8 | `.lock` PHẢI có heartbeat, stale check >30 min auto-release |

---

## 7. Ví dụ Pass/Fail

### ✅ PASS — Producer/Consumer khớp contract

```
wf-define-features writes:
  .mc-data/docs/phase2-features/crm/customer-mgmt/feat-create-cust.md

wf-design reads:
  .mc-data/docs/phase2-features/crm/customer-mgmt/feat-create-cust.md
  → Cùng path, contract OK
  → wf-design PRE-GATE T1 PASS (file exists)
```

### ❌ FAIL — Skill tự đổi path

```
wf-design output mới (v4.0):
  .mc-data/docs/phase3-design/architecture.md   ← path mới

wf-plan-modules vẫn đọc:
  .mc-data/docs/phase3-architecture/...         ← path cũ

→ wf-plan-modules PRE-GATE FAIL (file missing)
→ Vi phạm CORE-007 — path không khớp Protocol 21
```

---

## 8. Anti-patterns — KHÔNG được làm

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Skill tự đổi output path không sync Protocol 21 | Sync cả producer + consumer + bảng này trong 1 PR |
| Hardcode absolute path trong code | Dùng `$SESSION_DIR/...` cho session-scoped |
| 2 skills cùng ghi 1 path | 1 path = 1 producer |
| Cross-skill artifact thiếu `$schema` | Bắt buộc (CORE-036) |
| Session path không có `sessions/{id}/` cấu trúc | Tuân thủ CORE-035 |
| Consumer hardcode path khác producer | Đọc Protocol 21 trước khi assume |
| Path Vietnamese có dấu: `khách-hàng/` | Strip dấu: `khach-hang/` |
| Path UPPERCASE: `Phase2-Features/CRM/` | lowercase-kebab: `phase2-features/crm/` |

---

## 9. Checklist khi thêm output path mới

- [ ] Path tuân thủ pattern `.mc-data/docs/...` (docs) hoặc `.mc-data/work/{skill}/...` (work)
- [ ] Lowercase-kebab-case (CORE-016)
- [ ] Nếu session-scoped: dùng `$SESSION_DIR/...`
- [ ] Đăng ký vào `_contract.json.outputs.working[]` hoặc `outputs.docs[]`
- [ ] Đăng ký vào `produces_for{}` nếu cross-skill
- [ ] Nếu là `*-impact.json`: có `$schema` + `audit_chain`
- [ ] Update Protocol 21 + bảng §3 này trong cùng PR
- [ ] Consumer skill update PRE-GATE đọc path mới

---

## 10. Compliance audit

Script `./.claude/scripts/validate-schema-sync.sh --all` kiểm tra:

- ✅ Mọi output path trong `_contract.json` xuất hiện trong Protocol 21
- ✅ Producer-consumer relationships đối ngẫu (mỗi consumer path có producer)
- ✅ Cross-skill artifacts có `$schema`
- ✅ Session paths dùng `$SESSION_DIR/...` variable

Manual cross-check:
```bash
# Tìm path xuất hiện ở >1 producer (vi phạm OPC-1):
grep -h '"path":' .claude/skills/workflow/*/\_contract.json \
  | sort | uniq -c | awk '$1 > 1'
```

---

## 11. Liên kết

- **Canonical Protocol 21:** [`.claude/skills/protocols/21-cross-skill-output-path-contract.md`](../../.claude/skills/protocols/21-cross-skill-output-path-contract.md)
- **Canonical §4b:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4b (CORE-007)
- **Related standards:**
  - [`04-contract-schema.md`](04-contract-schema.md) — `_contract.json` outputs
  - [`06-safe-write-protocol.md`](06-safe-write-protocol.md) — registry path write rules
  - [`09-session-checkpoint.md`](09-session-checkpoint.md) — `$SESSION_DIR` structure
  - [`07-naming-conventions.md`](07-naming-conventions.md) — slug rules
