# 07 — Skills Catalog (44 skills)

> **Mức độ ràng buộc:** Tham khảo (overview)
> **File gốc:** [`docs/skills-reference.md`](../skills-reference.md) (sẽ thay thế trong W4) — slim rewrite ở đây
> **Mục đích:** Inventory đầy đủ các skills MCV3 — phân nhóm theo function, có mô tả ngắn + skill phụ trách phase nào

---

## 1. Tóm tắt

| Nhóm | Count | Folder |
|------|-------|--------|
| Main pipeline (Phase 0-6) | 8 | `workflow/wf-*` |
| Quality gates | 2 | `workflow/wf-preflight`, `wf-verify-sync` |
| Fix Bugs pipeline | 13 (1 orchestrator + 11 lane + 1 execute + 1 triage) | `workflow/wf-fix-*` |
| E2E Testing | 9 | `workflow/wf-e2e-*` |
| Legacy / Existing project | 4 | `workflow/wf-legacy-*`, `wf-annotate-code` |
| Change management | 3 | `wf-add-scope`, `wf-manage-change`, `wf-migrate-module` |
| Standalone tools | 5 | `wf-scan-target`, `wf-diagram`, `wf-cmi`, `wf-test-business-workflow`, `ui-ux-pro-max` |
| Status + tracking | 1 | `status` |
| Orchestrator workflows | 3 | `workflows/{new-project,existing-project,feature-addition}` |
| Self-audit (DEVKIT) | 6 | `audit-devkit-*`, `audit-agents`, `audit-skill-output` |

**Tổng:** 44 wf-* skills + 6 audit skills + 3 orchestrators + 1 status + 1 standalone = 55 entries trong `.claude/skills/`. CLAUDE.md công bố "47 wf-* skills" (đếm cả lane sub-skills) — count đầy đủ.

---

## 2. Main Pipeline — Phase 0-6 (8 skills)

| Skill | Lệnh | Phase | Đầu ra chính |
|-------|------|-------|--------------|
| wf-brainstorm | `/wf-brainstorm` | 0 | `phase0-brainstorm/`, init registry, `project-digest.json` |
| wf-analyze-requirements | `/wf-analyze-requirements` | 1 | `phase1-business/`, `dept-digests.json` |
| wf-define-features | `/wf-define-features` | 2 | `phase2-features/[sys]/[mod]/[feat].md`, `feature-briefs.json` |
| wf-design | `/wf-design` | 3 | `phase3-architecture/`, `design-input-digest.json` |
| wf-design-ux | `/wf-design-ux` | 4 (conditional) | `phase4-ux/design-system.md`, navigation specs |
| wf-plan-modules | `/wf-plan-modules` | 5.1 | `phase5-implementation/{module-plan, dependency-graph, sprints/, tasks/}` |
| wf-implement-feature | `/wf-implement-feature [name]` | 5.2 | Source code + `impl-status.json` per feature |
| wf-prepare-deployment | `/wf-prepare-deployment` | 6 | `phase6-deployment/` deployment + user guide |

**Ước lượng thời gian (per skill, 1 lần chạy):**
- `wf-brainstorm`: 15-30 min (interactive với user)
- `wf-analyze-requirements`: 30-90 min (multi-agent analysis)
- `wf-define-features`: 30-60 min
- `wf-design`: 20-45 min
- `wf-design-ux`: 30-90 min
- `wf-plan-modules`: 15-30 min
- `wf-implement-feature`: 20-60 min / feature
- `wf-prepare-deployment`: 20-45 min

---

## 3. Quality Gates (2 skills)

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| wf-preflight | `/wf-preflight [--scope] [--fix] [--run-tests]` | Health check toàn diện → PASS/WARN/FAIL |
| wf-verify-sync | `/wf-verify-sync` | Verify requirement-to-code traceability, update `impl_status` |

---

## 4. Fix Bugs Pipeline (13 skills)

### 4.1. Orchestrator (1)

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| wf-fix-bugs | `/wf-fix-bugs [mô-tả] [--scope] [--dims=QD1,..] [--profile=quick\|standard\|deep\|exhaustive] [--dry-run] [--resume] [--migrate]` | **v10.2.1** Pure orchestrator. ISG → partition → 11 dimension lanes → triage → execute → verify. 32 templates, Playwright 3 modes |

### 4.2. Pipeline executors (2)

| Skill | Trigger | Mục đích |
|-------|---------|----------|
| wf-fix-triage | (spawned bởi wf-fix-bugs) | Phase 2 Triage — classify severity, fixability, generate fix-plan.md + bug-triage.md |
| wf-fix-execute | (spawned bởi wf-fix-bugs) | Phase 3-5 Fix + Docs Sync + Verify loop + Phase 6 Report |

### 4.3. Dimension lanes — 11 quality dimensions (QD1-QD11)

| Skill | QD | Mục đích | Owner |
|-------|----|----|-------|
| wf-fix-functional | QD1 | Functional Correctness — 7 probes feature đúng spec | architect + developer |
| wf-fix-business | QD2 | Business Correctness — 5 probes nghiệp vụ + domain rules | business-analyst + domain experts |
| wf-fix-security | QD3 | Security & Privacy — 7 probes OWASP Top 10 | security |
| wf-fix-performance | QD4 | Performance & Efficiency — 6 probes CWV, query, bundle | performance-benchmarker |
| wf-fix-ux-a11y | QD5 | Accessibility & UX — 7 probes WCAG 2.2 AA | accessibility-auditor + ux-designer |
| wf-fix-data | QD6 | Data Integrity & Resilience — 6 probes schema drift, migration | dba + data-engineer |
| wf-fix-compat | QD7 | Compatibility — 5 probes deprecated API, browser, responsive, i18n | frontend-developer |
| wf-fix-observability | QD8 (v8.2.0+) | Observability & Reliability — 7 probes retry/circuit-breaker, log, metrics | sre + devops |
| wf-fix-runtime-health | QD9 (v9.0.2+) | Runtime Health Verification — 7 probes browser-runtime bugs | qa-lead + frontend-developer |
| wf-fix-integration | QD10 (v9.0.2+) | Cross-Module Integration — API contract, event handler, FK | architect + data-engineer |
| wf-fix-business-completeness | QD11 (v9.1.0+) | Business Completeness — 3-pass LLM cross-module pattern + domain heuristic | business-analyst + domain experts |

**Routing:**
- QD9 SKIP nếu `interface_type=api-only` hoặc `--no-browser`
- QD10 SKIP nếu không có `cross_module_dependencies[]` hoặc `profile=quick`
- QD11 SKIP nếu single module, api-only, hoặc `profile=quick`

---

## 5. E2E Testing Pipeline (9 skills)

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| wf-e2e-verify | `/wf-e2e-verify <FEAT-ID> [--no-playwright] [--auto] [--resume] [--legacy]` | **v8.0.0** Pipeline F0→F0a→F0b→F1-F8 (11 steps) |
| wf-e2e-finding | `/wf-e2e-finding <FEAT-ID>` | F0a — Phân tích business + mapping (KHÔNG live test) |
| wf-e2e-batch | `/wf-e2e-batch [--scope=<module>] [--feats=IDs]` | Batch orchestrator N FEATs với dependency graph |
| wf-e2e-credentials | (spawned) | OS keychain integration, secure test credential storage |
| wf-e2e-scenario | `/wf-e2e-scenario` | Định nghĩa & quản lý E2E scenarios |
| wf-e2e-browser | `/wf-e2e-browser` | Browser-based E2E testing qua Playwright |
| wf-e2e-test | `/wf-e2e-test` | Thực thi E2E tests |
| wf-e2e-demo | `/wf-e2e-demo` | Demo scenario với dữ liệu mẫu |
| wf-e2e-fix | `/wf-e2e-fix` | Auto-fix E2E test failures |
| wf-e2e-implement | `/wf-e2e-implement` | Implement code changes dựa trên E2E results |
| wf-e2e-unblock | `/wf-e2e-unblock` | Xử lý blocked E2E scenarios |
| wf-e2e-retest | `/wf-e2e-retest` | Re-run failed E2E tests sau khi fix |

**Shared infra:** `.claude/scripts/wf-e2e-shared/` — 4 scripts (`ensure-infra.sh`, `global-rw-lock.sh`, `lock-daemon.sh`, `version-snapshot.sh`). Áp dụng Protocol 22.

---

## 6. Legacy / Existing Project (4 skills)

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| wf-legacy-scan | `/wf-legacy-scan [path] [--profile=surface\|standard\|deep\|exhaustive]` | **v5.0** All-in-one scan: detect → classify → extract → synthesize. 4 profiles + IPS 2-phase + session isolation |
| wf-legacy-classify | `/wf-legacy-classify` | Phân loại modules theo business value vs technical health |
| wf-legacy-extract | `/wf-legacy-extract` | Trích xuất knowledge từ legacy codebase |
| wf-annotate-code | `/wf-annotate-code [--module] [--dry-run]` | Inject REQ-ID vào existing code |

---

## 7. Change Management (3 skills)

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| wf-add-scope | `/wf-add-scope --system=<id> [...]` | Thêm modules/features (APPEND-only) |
| wf-manage-change | `/wf-manage-change [mô-tả] [--scope=all\|system\|module] [--mode=quick\|deep] [--dry-run]` | **v3.0.0** Phân tích change → impact → plan → execute → verify. 11 bash scripts, lock/heartbeat |
| wf-migrate-module | `/wf-migrate-module [--source=<path>] [--target=<name>]` | Di chuyển module giữa systems, update registry + docs + refs |

---

## 8. Standalone Tools (4 skills)

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| wf-scan-target | `/wf-scan-target [--target=<path\|url>] [--compare=<spec>] [--profile=...]` | Quét 1 target → `module-map.md`, `target-map.json`, `feature-inventory.md`, `gap-report.md`. Standalone, không trong main pipeline. Optional consume bởi nhiều skills qua `--from-scan` |
| wf-diagram | `/wf-diagram --module=<name> [--source-path=<path>] [--scope=full\|module-only\|system-only]` | Sinh UML + ERD từ source code. Output: Mermaid + DBML. Quy tắc lọc nghiêm ngặt (activity ≥3 bước, state ≥3 trạng thái) |
| wf-cmi | `/wf-cmi [--scope=system\|module=<id>\|feat=<id>] [--profile=quick\|standard\|deep\|exhaustive] [--dims=CD1,CD11,CD28,...] [--since=<git-ref>] [--auto-suggest] [--dry-run] [--ci] [--resume] [--status]` | **v2.0.0 — Gói C++ Logistics 26 lanes** Cross-Module Integrity Orchestrator — system-wide ERP integrity check. 8 phases: Init → Discovery (**13 graphs** = 6 core + 7 plugin: fe-component/fe-api-client/fe-permission/fe-route/be-domain/be-db-schema/be-cqrs) → Invariant Artifact (3-pass LLM) → **Coverage Dispatch 3-WAVE** (W1=10/W2=10/W3=6 lanes parallel max 10, via `wave-coordinator.sh`) → Aggregate (35-dim matrix v2: 26 active + 9 SKIPPED) → Regression Map → GAP + CDG → Report. Output: `integrity-report.md` (≤55 dòng v2 top 10 violations severity-weighted) + `coverage-matrix.json` (schema `coverage-matrix-v2`) + sidecar `business-invariants.json` (KHÔNG bump registry) + `regression-map.json` + cross-skill `integrity-impact.json` (schema **`integrity-impact-v2`** với 5 v2 fields mới: lanes_v2/wave_breakdown/group_breakdown/logistics_critical_signals_count/schema_version_compat; ALL v1 fields preserved backward-compat). **26 active lanes** Gói C++ (CD1-CD7, CD9, CD11, CD13, CD15-CD18, CD23-CD26, CD28-CD31, CD37-CD40) + 9 SKIPPED + 5 skeleton v3-deferred. Standalone — không thuộc main pipeline. Consumers (opt-in `--from-cmi`): wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment, wf-design, wf-add-scope |
| wf-test-business-workflow | `/wf-test-business-workflow [--scenario=<name>]` | Kiểm thử business workflow end-to-end |
| ui-ux-pro-max | `/ui-ux-pro-max` | UI/UX design nâng cao (50+ styles, 97 palettes, 57 font pairings) |

---

## 9. Status & Tracking (1 skill)

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| status | `/status` | Tổng quan dashboard, sprint progress, feature completion từ registry |

---

## 10. Orchestrator Workflows (3 skills)

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| new-project | `/new-project` | Full STANDARD path: idea → deployment |
| existing-project | `/existing-project` | Onboard codebase + full workflow EXISTING path |
| feature-addition | `/feature-addition` | Thêm feature vào dự án đã có (Phase 3+) |

---

## 11. Self-Audit (6 skills)

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| audit-devkit | `/audit-devkit` | MCV3 self-audit: scan → verify → fix |
| audit-devkit-scan | `/audit-devkit-scan` | Scan components, build ground truth |
| audit-devkit-verify | `/audit-devkit-verify` | Cross-validate references + consistency |
| audit-devkit-fix | `/audit-devkit-fix` | Auto-fix với per-fix verification |
| audit-skill-output | `/audit-skill-output` | Kiểm tra output chất lượng vs SKILL.md design |
| audit-agents | `/audit-agents` | Audit agent/knowledge definitions compliance |

---

## 12. Skill version overview

| Skill | Version hiện tại | Highlight |
|-------|------------------|-----------|
| wf-fix-bugs | v10.2.1 | Pure orchestrator, 11 dimension lanes, 32 templates, Playwright 3 modes |
| wf-legacy-scan | v5.0 | 4 profiles + IPS 2-phase + session isolation + 4-level checkpoint |
| wf-manage-change | v3.0.0 | 11 bash scripts, sessions.jsonl concurrent-safe |
| wf-e2e-verify | v8.0.0 | F0→F0a→F0b→F1-F8 (11 steps), B1-B3 + G1-G2 |
| wf-preflight | v3.x | Health check toàn diện |
| wf-implement-feature | v4.0 | TDD + decision-registry per implementation |
| wf-cmi | **v2.0.0** | 8 phases, **26 lanes Gói C++ Logistics** (CD1-7, CD9, CD11, CD13, CD15-18, CD23-26, CD28-31, CD37-40), **3-WAVE dispatch** (W1=10/W2=10/W3=6 via `wave-coordinator.sh`), **13 graphs** (6 core + 7 plugin FE/BE), sidecar `business-invariants.json` (Engine #4 không bump registry), cross-skill `integrity-impact.json` **schema v2 backward-compat** (v1 reader OK với v2 artifact) |

---

## 13. Skill có phụ thuộc — Quick map

| Khi chạy skill này | Cần có sẵn |
|--------------------|------------|
| wf-analyze-requirements | `phase0-brainstorm/`, `project-digest.json`, `req-registry.json` (init) |
| wf-define-features | `phase1-business/`, `dept-digests.json`, `phase1-handoff.json` |
| wf-design | `phase2-features/`, `feature-briefs.json` |
| wf-design-ux | `phase3-architecture/`, `design-input-digest.json` |
| wf-plan-modules | `phase3-architecture/` + (optional) `phase4-ux/` |
| wf-implement-feature | `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md` |
| wf-preflight | Code + registry |
| wf-verify-sync | Code + registry |
| wf-fix-bugs | Code (post Phase 5) |
| wf-e2e-verify | FEAT-ID có trong registry + code + (optional) running infra |
| wf-cmi | `req-registry.json` non-empty + `phase3-architecture/` tồn tại (≥Phase 3 Design done) + code scannable. Optional: CI index (GitNexus/Serena) cho fast graph build |

Chi tiết dependency graph: [`09-dependencies-graph.md`](09-dependencies-graph.md).

---

## 14. Khi nào dùng skill nào — Decision tree

```
User intent
│
├─ Dự án MỚI hoàn toàn → /new-project (orchestrator)
│   hoặc chạy từng phase: /wf-brainstorm → /wf-analyze-requirements → ...
│
├─ Có codebase, muốn tài liệu hóa → /existing-project (orchestrator)
│   hoặc /wf-legacy-scan → /wf-brainstorm → ...
│
├─ Thêm feature cụ thể vào dự án có → /feature-addition
│   hoặc /wf-add-scope → /wf-define-features → /wf-design → ...
│
├─ Sửa đổi tính năng đã có → /wf-manage-change
│
├─ Bug trong code → /wf-fix-bugs
│
├─ Test feature end-to-end → /wf-e2e-verify FEAT-XXX
│
├─ Health check trước deploy → /wf-preflight
│
├─ Cần sơ đồ UML/ERD → /wf-diagram
│
├─ Audit module/URL/path cụ thể → /wf-scan-target
│
├─ Kiểm tra toàn vẹn liên module ERP (system-wide) → /wf-cmi
│
└─ Audit MCV3 self-quality → /audit-devkit
```

---

## 15. Anti-patterns chọn skill

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Chạy `/wf-fix-bugs` để "verify" code | Dùng `/wf-verify-sync` hoặc `/wf-preflight` |
| Chạy `/wf-manage-change` để thêm scope mới | Dùng `/wf-add-scope` (append-only) |
| Chạy `/wf-implement-feature` không có task file | PRE-GATE block — cần Phase 5.1 trước |
| Chạy `/wf-design-ux` cho api-only project | Skip phase này |
| Chạy `/audit-devkit-fix` không qua `/audit-devkit-verify` trước | Verify trước fix — fix mù = nguy hiểm |

---

## 16. Liên kết

- **Workflow model:** [`02-workflow-model.md`](02-workflow-model.md)
- **Dependencies graph:** [`09-dependencies-graph.md`](09-dependencies-graph.md)
- **Agents catalog:** [`08-agents-catalog.md`](08-agents-catalog.md)
- **Skill standard:** [`../02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md)
- **Output path contract:** [`../02-standards/11-output-path-contract.md`](../02-standards/11-output-path-contract.md)
- **Source legacy:** [`../skills-reference.md`](../skills-reference.md) (sẽ migrate W4)
