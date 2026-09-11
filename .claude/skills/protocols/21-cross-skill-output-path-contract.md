<!-- Canonical source: .claude/rules/00-core.md §4b. Protocol 21 là mirror đồng bộ — khi mâu thuẫn, §4b thắng. -->
# Protocol 21 — Cross-Skill Output Path Contract

Paths giữa các skills PHẢI khớp nhau. Bảng này định nghĩa toàn bộ producer→consumer relationships trong MCV3 pipeline.

> **Quy tắc:** Mỗi consumer skill PHẢI đọc đúng path từ producer skill. KHÔNG tự ý thay đổi output path hoặc expect path khác.

## 21.1 Bảng Contract

| Producer Skill | Output Path | Consumer Skill |
|----------------|-------------|----------------|
| `/wf-brainstorm` Phase 3 (Phiên 6 — Digest) | `.mc-data/docs/_meta/project-digest.json` | `/wf-analyze-requirements` Phase 0.1 (PRE-GATE digest loading) |
| `/wf-analyze-requirements` Phase 3 (Phiên 6 — Digest) | `.mc-data/docs/_meta/dept-digests.json` | `/wf-define-features` Phase 0.1 (PRE-GATE digest loading) |
| `/wf-analyze-requirements` Phase 3 (Phiên 6 — Digest) | `.mc-data/docs/_meta/phase1-handoff.json` | `/wf-define-features` Phase 0.1 (PRE-GATE digest loading) |
| `/wf-define-features` Phase 3 (Phiên 6 — Digest) | `.mc-data/docs/_meta/feature-briefs.json` | `/wf-design` Phase 0.5 (PRE-GATE digest loading), `/wf-implement-feature` Phase 0 (digest loading) |
| `/wf-design` Phase 3 (Phiên 6 — Digest) | `.mc-data/docs/_meta/design-input-digest.json` | `/wf-design-ux` (PRE-GATE digest loading), `/wf-plan-modules` Phase 0.5 (digest loading), `/wf-implement-feature` Phase 0 (digest loading) |
| `/wf-design-ux` Phase 3 (Phiên 6 — Digest) | `.mc-data/docs/_meta/ux-input-digest.json` | `/wf-plan-modules` Phase 0.5 (PRE-GATE digest loading — CHỈ khi `interface_type != "api-only"`) |
| `/wf-analyze-requirements` Phase 6c | `.mc-data/docs/phase1-business/stakeholder-review.md` | `/wf-define-features` Phase 0 (context) |
| `/wf-analyze-requirements` Phase 6d | `.mc-data/work/wf-analyze-requirements/deferred-issues.md` | `/wf-define-features` Phase 0 (input) |
| `/wf-define-features` Phase 4 | `.mc-data/work/wf-define-features/deferred-findings.md` | `/wf-design` Phase 0 (optional input) |
| `/wf-define-features` Phase 2 | `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md` | `/wf-design` Phase 0 |
| `/wf-define-features` Phase 2 | `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md` | `/wf-implement-feature` Phase 0 (feature spec reading) |
| `/wf-define-features` Phase 5 | `req-registry.json` (features[]) | `/wf-design` Phase 0 |
| `/wf-design` Phase 4b | `.mc-data/docs/phase3-architecture/stakeholder-review.md` | `/wf-design-ux` Phase 0 |
| `/wf-design` Phase 4c | `.mc-data/work/wf-design/deferred-findings.md` | `/wf-plan-modules` Phase 0 (blocking items) |
| `/wf-design-ux` Phase 1 | `.mc-data/docs/phase4-ux/design-system.md` | `/wf-plan-modules` Phase 0 *(conditional: only if interface_type != api-only)* |
| `/wf-design-ux` Phase 2 | `.mc-data/docs/phase4-ux/*/Navigation-*.md` | `/wf-plan-modules` Phase 0 *(conditional: only if interface_type != api-only)* |
| `/wf-design-ux` Phase 5 | `.mc-data/docs/phase4-ux/stakeholder-review.md` | `/wf-plan-modules` Phase 0 *(conditional: only if interface_type != api-only)* |
| IF `interface_type == "api-only"` → `/wf-design-ux` SKIPPED | N/A | `/wf-plan-modules` **PRE-GATE**: đọc trực tiếp từ `/wf-design` output |
| `/wf-plan-modules` Phase 7 | `.mc-data/docs/phase5-implementation/module-plan.md` | `/wf-implement-feature` (reference) |
| `/wf-plan-modules` Phase 7 | `.mc-data/docs/phase5-implementation/dependency-graph.md` | `/wf-implement-feature` (reference) |
| `/wf-plan-modules` Phase 7 | `.mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md` | `/wf-implement-feature` (reference) |
| `/wf-plan-modules` Phase 7 | `.mc-data/docs/phase5-implementation/sprints/S[NN]-[name].md` | `/wf-implement-feature` (sprint context) |
| `/wf-plan-modules` Phase 7.5 | `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md` | `/wf-implement-feature` Phase 1+2 |
| `/wf-plan-modules` Phase 7b | `.mc-data/docs/phase5-implementation/stakeholder-review.md` | `/wf-implement-feature` Phase 0 |
| `/wf-implement-feature` Phase 6 | `req-registry.json` (impl_status) | `/wf-preflight` Phase 4 (input) |
| `/wf-implement-feature` Session-aware (v4.0+) | `.mc-data/work/wf-implement-feature/{$SYSTEM_SLUG}/{$FEATURE_SLUG}/sessions/{$SESSION_ID}/impl-status.json` | `/wf-preflight`, `/wf-verify-sync` (resolve qua current.txt) |
| `/wf-implement-feature` History (v4.0+) | `.mc-data/work/wf-implement-feature/.history/implementations-index.jsonl` | Audit trail (multi-dev visibility), `/status` skill |
| `/wf-implement-feature` Current pointer (v4.0+) | `.mc-data/work/wf-implement-feature/{$SYSTEM_SLUG}/{$FEATURE_SLUG}/current.txt` | `--resume` routing |
| `/wf-implement-feature` Phase 3.5 (v4.0+ Sprint 3) | `.mc-data/docs/_meta/decision-registry.global.json` (APPEND-only) | All future implementations Phase 0.5b (cross-feature consistency) |
| `/wf-implement-feature` Phase 6 (v4.0+ Sprint 3) | `.mc-data/work/wf-implement-feature/{$SYSTEM_SLUG}/{$FEATURE_SLUG}/sessions/{$SESSION_ID}/impl-status.json` (schema v2.0) | OPTIONAL: `/wf-prepare-deployment --from-impl`, `/wf-fix-bugs --from-impl`, `/wf-verify-sync --from-impl` |
| `/wf-preflight` Phase 7 (v3.0+) | `.mc-data/work/wf-preflight/sessions/{session_id}/preflight-report.md` | `/wf-fix-bugs` Phase 1, `/wf-verify-sync` (context) |
| `/wf-preflight` Phase 7 (v3.0+) | `.mc-data/work/wf-preflight/sessions/{session_id}/preflight-impact.json` (schema `preflight-impact-v1`) | OPT-IN: `/wf-fix-bugs --from-preflight`, `/wf-prepare-deployment --from-preflight`, `/wf-verify-sync --from-preflight` |
| `/wf-preflight` Session (v3.0+) | `.mc-data/work/wf-preflight/sessions/{session_id}/preflight-status.json` | Session state (CORE-030) — observability only |
| `/wf-preflight` Session (v3.0+) | `.mc-data/work/wf-preflight/sessions/{session_id}/phase-summary.md` | CORE-028 phase summary — consumed by user |
| `/wf-preflight` Index (v3.0+) | `.mc-data/work/wf-preflight/_index/sessions.jsonl` | `--status` display and `--resume` discovery |
| `/wf-fix-bugs` (orchestrator) | N/A — delegate toàn bộ cho sub-skills | N/A |
| `/wf-fix-triage` Phase 2 | `$SESSION_DIR/bug-triage.md`, `$SESSION_DIR/fix-plan.md` | `/wf-fix-execute` Phase 3 (input) |
| `/wf-fix-triage` Phase 2 | `$SESSION_DIR/issue-registry.json` (updated: severity+fixability) | `/wf-fix-execute` Phase 3 (input) |
| `/wf-fix-triage` Phase 2 | `$SESSION_DIR/fix-log.json` (initialized) | `/wf-fix-execute` Phase 3 (APPEND) |
| `/wf-fix-triage` Phase 2 | `$SESSION_DIR/phase-summary.md` (CORE-028) | `/wf-fix-bugs` orchestrator (status display) |
| `/wf-fix-execute` Phase 3+4+5 | `$SESSION_DIR/fix-log.json` (APPEND per batch + verify loop) | `/wf-fix-execute` Phase 6 (report metrics) |
| `/wf-fix-execute` Phase 5 | `$SESSION_DIR/issue-registry.json` (final: verify results) | `/wf-fix-execute` Phase 6 (report metrics) |
| `/wf-fix-execute` Phase 4 | `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md` (cập nhật nếu behavior đổi) | `/wf-verify-sync` Phase 2 (context) |
| `/wf-fix-execute` Phase 6 | `$SESSION_DIR/fix-report.md`, `.mc-data/work/wf-fix-bugs/fix-history.md`, `$SESSION_DIR/phase-summary.md` | `/wf-verify-sync` (optional context) |
| `/wf-fix-bugs` Phase 1 step 1.1 | `$SESSION_DIR/lanes/QD*/signals.json` | `/wf-fix-bugs` Phase 1 step 1.2 (aggregation) |
| `/wf-fix-bugs` Phase 1 step 1.2 | `$SESSION_DIR/issue-registry.json` (v2 schema) | `/wf-fix-triage`, `/wf-fix-execute` |
| `/wf-fix-bugs` Phase 1 step 1.3 | `$SESSION_DIR/coverage-report.md` | User, `/wf-verify-sync` |
| `/wf-fix-bugs` Phase 1 step 1.3 | `$SESSION_DIR/lanes/QD*/lane-report.md` | User |
| Lane skill (QD1-QD8) | `$SESSION_DIR/lanes/QD*/lane-status.json` | `/wf-fix-bugs` (lane completion check) |
| Lane skill (CORE-028) | `$SESSION_DIR/lanes/QD*/phase-summary.md` | User |
| `/wf-fix-bugs` Phase 1 step 5 | `$SESSION_DIR/fix-status.json` | `/wf-fix-triage`, `/wf-fix-execute`, orchestrator resume routing |
| `/wf-fix-bugs` Phase 1 step 1.4 | `$SESSION_DIR/workloads/W*/fix-workload.json` | `/wf-fix-bugs` Step 1.5 Workload Gate |
| `/wf-fix-bugs` Step 2.5 (CDG Handoff) | `$SESSION_DIR/cdg-tokens.json` | `/wf-fix-execute` Phase 3 (respect reject tokens) |
| `/wf-fix-bugs` POST-GATE (orchestrator) | `$SESSION_DIR/orchestrator-summary.md` (CORE-028) | User |
| `/wf-fix-bugs` POST-GATE step 3.5 (S7) | `$SESSION_DIR/fix-impact.json` (schema fix-impact-v1) | **S9 WIRED:** `/wf-verify-sync --from-fix-bugs` v2.1+, `/wf-prepare-deployment --from-fix-bugs`, `/wf-implement-feature --from-fix-bugs` v5.2+ |
| `/wf-fix-bugs` Step 2.6 Safety Check (S8) | `$SESSION_DIR/safety-check.json` (schema wf-fix-safety-check-v1) | Internal — wf-fix-bugs orchestrator |
| `/wf-fix-execute` Phase 4a hook (S8) | `$SESSION_DIR/docs-sync-report.json` (schema docs-sync-report-v1) | **S9 WIRED:** `/wf-verify-sync --from-fix-bugs` v2.1.0+ |
| `/wf-fix-execute` Phase 6 pre-POST-GATE (S8) | `$SESSION_DIR/cqg-verify.json` (schema wf-fix-cqg-verify-v1) | Internal — wf-fix-execute block POST-GATE |
| `/wf-verify-sync` Phase 7 | `.mc-data/docs/_meta/verify-sync.md` | `/wf-prepare-deployment` Phase 0 (inform) |
| `/wf-verify-sync` Phase 7 | `req-registry.json` (impl_status safe-update) | Release/Go-Live |
| `/wf-verify-sync` Phase 6 (v3.0+) | `.mc-data/work/wf-verify-sync/sessions/{session_id}/verify-sync.md` | Session-scoped copy |
| `/wf-verify-sync` Phase 6 (v3.0+) | `.mc-data/work/wf-verify-sync/sessions/{session_id}/verify-sync-impact.json` | OPT-IN: `/wf-prepare-deployment --from-verify-sync`, `/wf-fix-bugs --from-verify-sync`, `/wf-implement-feature --from-verify-sync` |
| `/wf-prepare-deployment` Phase 5a | `.mc-data/docs/phase6-deployment/stakeholder-review.md` | Release/Go-Live |
| `/wf-legacy-scan` | `.mc-data/work/legacy-scan/ledger.json`, `inventory/*` | `/wf-legacy-classify` |
| `/wf-legacy-scan` Stage 0 | `.mc-data/work/legacy-scan/project-profile.json` | `/wf-legacy-classify`, `/wf-legacy-extract`, `/wf-annotate-code` |
| `/wf-legacy-scan` Stage 1 | `.mc-data/work/legacy-scan/inventory/dependency-graph.json` | `/wf-legacy-extract` (topological ordering) |
| `/wf-legacy-classify` | `.mc-data/work/legacy-scan/classified/*`, `glossary.json` | `/wf-legacy-extract` |
| `/wf-legacy-extract` | `.mc-data/work/legacy-scan/extracted/*`, `dedup-report.json` | `/wf-brainstorm` (legacy flow) |
| `/wf-legacy-extract` Stage 3.5 | `.mc-data/work/legacy-scan/module-code-mapping.json` | `/wf-analyze-requirements` (legacy), `/wf-annotate-code`, `/wf-design` (legacy — gap analysis) |
| `/wf-annotate-code` | `<annotated-source-code-files>` | `/wf-plan-modules` Phase 1.5 (LEGACY) |
| `/wf-annotate-code` | `.mc-data/work/legacy-scan/annotation-report.md` | `/wf-plan-modules` Phase 1.5 (LEGACY) |
| `/wf-legacy-scan` Stage 1 | `.mc-data/work/legacy-scan/inventory/external-docs.json` | `/wf-legacy-extract`, `/wf-brainstorm` (legacy flow) |
| `/wf-brainstorm` (legacy flow) | `.mc-data/docs/phase0-brainstorm/` | `/wf-analyze-requirements`, `/wf-design-ux`, `/wf-plan-modules` |
| `/wf-analyze-requirements` (legacy flow) | `.mc-data/docs/phase1-business/` | `/wf-design-ux` context |
| `/wf-define-features` (legacy flow) | `.mc-data/docs/phase2-features/**` | `/wf-plan-modules` |
| `/wf-design` (legacy flow) | `.mc-data/docs/phase3-architecture/**` + `req-registry.json` | `/wf-design-ux`, `/wf-plan-modules`, All downstream skills |
| `/wf-design` (legacy flow — gap analysis) | `.mc-data/work/legacy-scan/gap-report.md` | `/wf-plan-modules` (priority input), `/wf-annotate-code` |
| `/wf-design` (legacy flow — gap analysis) | `.mc-data/work/legacy-scan/action-items.json` | `/wf-plan-modules` Phase 0 |
| `/wf-design-ux` (legacy flow) | `.mc-data/docs/phase4-ux/existing-ui-analysis.md` | `/wf-plan-modules` |
| `/wf-legacy-scan` Stage 4 | `.mc-data/work/legacy-scan/project-context.md` | Tất cả shared skills + wf-plan-modules + wf-implement-feature |
| `/wf-legacy-scan` Stage 4 | `.mc-data/work/legacy-scan/doc-quality-map.json` | `/wf-brainstorm` Phase 0.5, `/wf-analyze-requirements` |
| `/wf-legacy-scan` Stage 4 | `.mc-data/work/legacy-scan/impl-status-snapshot.json` | `/wf-define-features` Phase 0.5 |
| `/wf-brainstorm` Phase 0.5.7 | `.mc-data/work/wf-brainstorm/legacy-decisions.json` | 13 downstream skills |
| `/wf-legacy-extract` Stage 3.5 | `.mc-data/work/legacy-scan/module-code-mapping.json` | `/wf-add-scope` (--from-mapping), `/wf-analyze-requirements`, `/wf-annotate-code`, `/wf-design` |
| `/wf-legacy-scan` IPS-B (v5.0) | `.mc-data/work/legacy-scan/domain-hints.json` | `/wf-legacy-classify`, `/wf-legacy-extract`, `/wf-design` |
| `/wf-legacy-scan` Session (v5.0) | `.mc-data/work/legacy-scan/sessions/{id}/scan-state.json` | `/wf-legacy-classify`, `/wf-legacy-extract` |
| `/wf-legacy-scan` Session (v5.0) | `.mc-data/work/legacy-scan/sessions/{id}/scan-plan.md` | Internal phase planning |
| `/wf-legacy-scan` Session (v5.0) | `.mc-data/work/legacy-scan/sessions/{id}/phase-summary.md` | CORE-028 — consumed by user |
| `/wf-legacy-scan` Session (v5.0) | `.mc-data/work/legacy-scan/sessions/{id}/session-log.json` | Session-scoped observability (CORE-026) |
| `/wf-legacy-scan` Session (v5.0) | `.mc-data/work/legacy-scan/sessions/{id}/session-digest.md` | Session digest cuối pipeline |
| `/wf-legacy-scan` L6 (v5.0, conditional) | `.mc-data/work/legacy-scan/impact-graph.json` | `/wf-verify-sync` (ripple analysis), `/wf-fix-bugs` |
| `/wf-add-scope` Phase 4 | `.mc-data/docs/_meta/req-registry.json` (append-only: modules[], features[]) | `/wf-define-features`, `/wf-plan-modules`, `/wf-annotate-code` |
| `/wf-add-scope` Phase 5 | `.mc-data/docs/phase2-features/[sys-slug]/[mod-slug]/[feat-slug].md` (stubs) | `/wf-define-features` |
| `/wf-add-scope` Phase 6 (v3.0+) | `.mc-data/work/wf-add-scope/sessions/{id}/scope-impact.json` | OPT-IN: `/wf-verify-sync --from-add-scope`, `/wf-preflight --from-add-scope`, `/wf-implement-feature` |
| `/wf-add-scope` Session (v3.0+) | `.mc-data/work/wf-add-scope/sessions/{id}/add-scope-status.json` | Session state + audit_chain — observability only |
| `/wf-add-scope` Session (v3.0+) | `.mc-data/work/wf-add-scope/sessions/{id}/phase-summary.md` | CORE-028 — consumed by user |
| `/wf-add-scope` Index (v3.0+) | `.mc-data/work/wf-add-scope/_index/sessions.jsonl` | `--status` display and `--resume` discovery |
| `/wf-scan-target` Phase 5 | `.mc-data/work/wf-scan-target/sessions/{session_id}/target-map.json` (v2 schema) | OPTIONAL: `/wf-add-scope --from-scan`, `/wf-define-features --from-scan`, `/wf-design --from-scan`, `/wf-implement-feature` |
| `/wf-scan-target` Phase 5 | `.mc-data/work/wf-scan-target/sessions/{session_id}/feature-inventory.md` | OPTIONAL: `/wf-define-features --from-scan`, `/wf-implement-feature` |
| `/wf-scan-target` Phase 5 | `.mc-data/work/wf-scan-target/sessions/{session_id}/module-map.md` | OPTIONAL: `/wf-design --from-scan` |
| `/wf-fix-execute` Phase 4b (--deep only) | `.mc-data/docs/phase2-features/[sys]/[mod]/[slug].md` (stub) | `/wf-define-features` (flesh-out) |
| `/wf-fix-execute` Phase 4b (--deep only) | `.mc-data/docs/phase2-features/[sys]/[mod]/flow-[slug].md` (stub) | `/wf-define-features` (flesh-out) |
| `/wf-fix-execute` Phase 4b (--deep only) | `.mc-data/docs/phase4-ux/[sys]/[mod]/screens-[slug].md` (stub) | `/wf-design-ux` (flesh-out) |
| `/wf-legacy-scan` Stage 1 (Inventory) | `.mc-data/work/legacy-scan/inventory/ui-manifest.json` | `/wf-legacy-extract`, `/wf-define-features` Phase 2.7 |
| `/wf-define-features` Phase 2.7 | `.mc-data/work/wf-define-features/ui-coverage-gaps.json` | `/wf-design-ux`, `/wf-plan-modules` |
| `/wf-verify-sync` Phase 5b | `.mc-data/work/wf-verify-sync/ui-coverage-report.md` | `/wf-prepare-deployment` Phase 0, Release/Go-Live |
| `/wf-manage-change` Phase 0 | `.mc-data/docs/_meta/req-registry.json` (read) + legacy-decisions.json (LEGACY_MODE) | `/wf-manage-change` consumes từ upstream |
| `/wf-manage-change` Phase 4a | `.mc-data/docs/_meta/req-registry.json` (UPDATE), phase1-4 docs (UPDATE) | `/wf-preflight` Phase 4, `/wf-verify-sync` Phase 2 |
| `/wf-manage-change` Phase 6 | `.mc-data/work/wf-manage-change/$CHANGE_ID/change-report.md`, `phase-summary.md` | `/wf-preflight` (inform) |
| `/wf-analyze-requirements` Session (v3.0+) | `.mc-data/work/wf-analyze-requirements/sessions/{id}/session-state.json` | Checkpoint/resume state (CORE-030) — observability only |
| `/wf-analyze-requirements` Session (v3.0+) | `.mc-data/work/wf-analyze-requirements/sessions/{id}/phase-summary.md` | CORE-028 — consumed by user |
| `/wf-define-features` Session (v3.0+) | `.mc-data/work/wf-define-features/sessions/{id}/session-state.json` | Checkpoint/resume state (CORE-030) — observability only |
| `/wf-define-features` Session (v3.0+) | `.mc-data/work/wf-define-features/sessions/{id}/phase-summary.md` | CORE-028 — consumed by user |
| `/wf-design` Session (v4.0+) | `.mc-data/work/wf-design/sessions/{id}/session-state.json` | Checkpoint/resume state (CORE-030) — observability only |
| `/wf-design` Session (v4.0+) | `.mc-data/work/wf-design/sessions/{id}/phase-summary.md` | CORE-028 — consumed by user |
| `/wf-design-ux` Session (v4.0+) | `.mc-data/work/wf-design-ux/sessions/{id}/session-state.json` | Checkpoint/resume state (CORE-030) — observability only |
| `/wf-design-ux` Session (v4.0+) | `.mc-data/work/wf-design-ux/sessions/{id}/phase-summary.md` | CORE-028 — consumed by user |
| `/wf-plan-modules` Session (v3.0+) | `.mc-data/work/wf-plan-modules/sessions/{id}/session-state.json` | Checkpoint/resume state (CORE-030) — observability only |
| `/wf-plan-modules` Session (v3.0+) | `.mc-data/work/wf-plan-modules/sessions/{id}/phase-summary.md` | CORE-028 — consumed by user |
| `/wf-manage-change` Phase 6 | `.mc-data/work/wf-manage-change/$CHANGE_ID/change-impact.json` (schema `change-impact-v1`) | **WIRED:** `/wf-verify-sync --from-manage-change`, `/wf-preflight`, `/wf-implement-feature` v4.1.0+ |
| `/wf-manage-change` Session (v3.0+) | `.mc-data/work/wf-manage-change/_index/sessions.jsonl` | Internal session lookup, `--status` display |
| `/wf-manage-change` Session (v3.0+) | `$SESSION_DIR/.session.lock` + `.mc-data/work/wf-manage-change/.locks/registry.lock` | Internal — multi-developer safety |
| `/wf-cmi` Phase 2 (Discovery) | `$SESSION_DIR/phase2-discovery/{entity,module,workflow,api,event}-graph.json` + `rbac-matrix.json` (6 graphs schema versioned) | `/wf-cmi` Phase 3-7 (internal cross-reference) |
| `/wf-cmi` Phase 3 (Invariant Artifact) | `$SESSION_DIR/phase3-invariant-artifact/business-invariants.json` (DRAFT, before CDG E094) | `/wf-cmi` Phase 4-7 (internal) |
| `/wf-cmi` Phase 4 (Coverage Dispatch) | `$SESSION_DIR/phase4-coverage-dispatch/lanes/CD*/signals.json` + `lane-status.json` + `CD-report.md` (10 lanes CD1-CD10) | `/wf-cmi` Phase 5 (aggregate) |
| `/wf-cmi` Phase 5 (Aggregate) | `$SESSION_DIR/phase5-aggregate/coverage-matrix.json` (schema `coverage-matrix-v1`) + `coverage-report.md` | `/wf-cmi` Phase 7-8 |
| `/wf-cmi` Phase 6 (Regression) | `$SESSION_DIR/phase6-regression/regression-map.json` (schema `regression-map-v1`, SKIP nếu profile=quick OR no `--since`) + `regression-report.md` | `/wf-cmi` Phase 8 |
| `/wf-cmi` Phase 7 (GAP + CDG) | `$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json` (schema `gap-suggestions-v1`) + `gap-report.md` | `/wf-cmi` Phase 8 |
| `/wf-cmi` Phase 7 (CDG E094 ACCEPT) | `.mc-data/work/wf-cmi/business-invariants.json` (★ CANONICAL SIDECAR, APPEND-only, schema `business-invariants-v1`, `audit_chain.source_registry_checksum`) | **OPT-IN:** `/wf-fix-bugs --from-cmi`, `/wf-verify-sync --from-cmi`, `/wf-implement-feature --from-cmi`, `/wf-prepare-deployment --from-cmi`, `/wf-design --from-cmi`, `/wf-add-scope --from-cmi` |
| `/wf-cmi` Phase 8 (Report) | `$SESSION_DIR/phase8-report/integrity-report.md` (≤30 dòng tiếng Việt, 6 sections user-facing PRIMARY) | User-facing |
| `/wf-cmi` Phase 8 POST-GATE | `$SESSION_DIR/phase8-report/integrity-impact.json` (schema `integrity-impact-v1`, có `$schema` + `audit_chain.source` + checksum) | **OPT-IN:** `/wf-fix-bugs --from-cmi`, `/wf-verify-sync --from-cmi`, `/wf-implement-feature --from-cmi`, `/wf-prepare-deployment --from-cmi` |
| `/wf-cmi` Session | `$SESSION_DIR/integrity-status.json` (SSOT pipeline state) + `session-log.json` (CORE-026) + `error-ledger.json` (E001-E109) + `.lock` (heartbeat daemon) | Internal — resume routing, multi-session safety (Protocol 22) |
| `/wf-cmi` Session | `$SESSION_DIR/Phase{N}-report.md` (N=1..8, CORE-028 ≤15 dòng tiếng Việt) | User progress check |
| `/wf-cmi` Index | `.mc-data/work/wf-cmi/_index/sessions.jsonl` (APPEND-only) | `--status` display + `--resume` discovery |

## 21.2 Quy tắc sử dụng

1. Consumer skill PHẢI đọc đúng path từ producer skill được liệt kê trong bảng trên
2. KHÔNG tự ý thay đổi output path — nếu cần đổi, cập nhật cả producer VÀ consumer
3. Khi thêm skill mới → thêm entry vào bảng này + cập nhật `00-core.md` §4b reference

> **Ưu tiên khi conflict:** `00-core.md` §4b luôn là canonical. Nếu bảng trên lạc hậu, fix Protocol 21 để khớp §4b.
