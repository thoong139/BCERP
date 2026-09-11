# Tiêu chuẩn rà soát — `wf-define-features` v2.1.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-define-features/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section**. Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Chuyển requirements (Phase 1) → feature specs (Phase 2) — mapping REQ-IDs → FEAT-IDs, catalog features |
| **Entry point** | `procedures/phase0-context.md` |
| **Kiến trúc** | 10 phase files + `_shared.md` — load-on-demand |
| **Execution mode** | HYBRID — SEQUENTIAL (scope/mapping) + PARALLEL (feature specs per module/batch) |
| **Branching** | NEW mode vs LEGACY mode (Phase 0.5, 2.5, 2.7 chỉ chạy LEGACY) |
| **Đặc trưng** | `--resume`, `--status`, filesystem reconciliation, stub detection (từ `/wf-fix-bugs --deep`), dual-schema `feature-briefs.json` |
| **Output** | 2 docs (per-feature spec + stakeholder-review) + 9 working files; registry PRIMARY write (features[]) |
| **Cross-skill** | 3 producer (analyze-req, legacy-extract, add-scope, fix-bugs), 4 consumer (design, design-ux, plan-modules, implement-feature) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-define-features
  version: 2.1.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-define-features/

profile:
  is_orchestrator: false
  has_procedures: true
  has_templates: true             # 5 templates
  has_phases: true                # 10 phases + _shared.md

  has_state_machine: true         # checkpoint.json + define-features-status.json
  has_resume: true                # --resume
  has_status: true                # --status + filesystem reconciliation
  is_multi_run: false

  spawns_agents: true             # Phase 2 (create-specs) spawn BA + product-expert per feature/batch
  has_strategy_routing: false     # NEW/LEGACY branch, không scoring

  writes_registry: true
  registry_role: PRIMARY          # features[] + features[].impl_status; SAFE-UPDATE cho impl_status (chỉ "skipped" cho DEPRECATE)

contracts:
  producers_count: 6              # wf-analyze-requirements, wf-legacy-extract (legacy),
                                  # wf-legacy-scan (impl-status, ui-manifest), wf-brainstorm (legacy-decisions),
                                  # wf-add-scope (append stubs), wf-fix-execute (deep scan stubs)
  consumers_count: 4              # wf-design, wf-design-ux, wf-plan-modules, wf-implement-feature
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ Toàn bộ A1-A10 | |
| **B** Workflow Integrity | ✅ B1-B8 | B5 conditional phase rất nhiều (0.5, 2.5, 2.7 LEGACY-only); B9-B10 SKIP (no strategy) |
| **C** Output & Template | ✅ C1-C7 | C1 đặc biệt: `feature-briefs.json` có 2 schema khác nhau (working vs digest) |
| **D** Cross-Skill | ✅ D1-D4 | 4 producer + 4 consumer — scope rộng, cần chú ý stub input từ add-scope/fix-bugs |
| **E** Protocol & CORE | ✅ Toàn bộ E1-E18 | E15-E16 PRIMARY + SAFE-UPDATE; E17-E18 áp dụng |
| **F** Determinism/Agent | ✅ F1-F4 | F5-F7 SKIP |
| **H** Error Handling | ✅ H1-H5 | |
| **I** Testability | ✅ I1-I5 | 3 test cases (tối thiểu) — cần bổ sung cho LEGACY mode + Phase 2.7 |
| **J** Idempotency | ✅ J1-J2 | J3-J4 SKIP |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Dual-Schema Briefs + Stub Detection + UI Coverage

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | Dual-schema `feature-briefs.json` | `_contract.json` 2 entries + SKILL.md §Lưu ý | Working `.mc-data/work/wf-define-features/feature-briefs.json` (schema A: feat_id/actors/business_rules/output_path) ≠ Digest `.mc-data/docs/_meta/feature-briefs.json` (schema B: feature_id/summary/acceptance_criteria/technical_complexity). 2 template khác nhau |
| **G2** | Stub detection từ `/wf-fix-bugs --deep` | `phase2-create-specs.md` + SKILL.md §Stub Detection | Phát hiện files có frontmatter `status: stub` → fill content theo template, remove `status: stub`, giữ `related_feature_id` |
| **G3** | Phase 0.5 LEGACY-only: impl_status seed 1 lần | `phase0.5-impl-status.md` | Guard LEGACY; seed `impl_status` từ `impl-status-snapshot.json` — chạy 1 lần DUY NHẤT, idempotent; sau đó KHÔNG update lại |
| **G4** | Phase 2.5 LEGACY-only: feat-mapping | `phase2.5-feat-mapping.md` | Tạo `.mc-data/work/legacy-scan/feat-mapping.json` — map FEAT-ID → {title, module, system, doc_path} |
| **G5** | Phase 2.7 UI Coverage Cross-Check conditional | `phase2.7-ui-coverage.md` | Chỉ chạy khi `LEGACY_MODE=true AND ui-manifest.json exists AND total_screens > 0`; có early-return rõ |
| **G6** | File naming convention khác giữa NEW vs LEGACY | SKILL.md §File Naming Difference | NEW: kebab-case tiếng Việt (`quan-ly-khach-hang.md`); LEGACY: FEAT-ID (`FEAT-CRM-CUST-001.md`) — intentional cho consistency với feat-mapping |
| **G7** | Phase 3 Cross-Validation auto-correction | `phase3-cross-validation.md` | Loop max 3 iterations; fix types: `missing_feature_file`, `duplicate_feat_id`, `coverage_gap`, `stakeholder_review_gap` |
| **G8** | Phase 4 Stakeholder Review A-D parts | `phase4-stakeholder-review.md` | Review 4 phần (A: coverage, B: business rules, C: permissions, D: gaps); Critical/High sau 3 vòng → escalate |
| **G9** | Phase 5 Registry Safe-Write — 2 permissions | `phase5-registry-update.md` | PRIMARY cho `features[]` (append only), SAFE-UPDATE cho `impl_status` (CHỈ set "skipped" cho DEPRECATE modules) |
| **G10** | UI coverage classify 4 loại | `phase2.7-ui-coverage.md` Step 2.7.4 | COVERED / INFRASTRUCTURE / GAP / AMBIGUOUS — mỗi loại có handling rõ; GAP → tạo stub |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | 4 stub producers vào `phase2-features/` | `_contract.json.consumes_from` + `produces_for` | Producers: `wf-add-scope` (stubs), `wf-fix-bugs --deep` (stubs). Consumer flesh-out stubs trong Phase 1. Kiểm xử lý stub không break flesh-out |
| **CS2** | `ui-coverage-gaps.json` shared giữa 3 consumer | `_contract.json.produces_for` | Đọc bởi `wf-design-ux` (inform UI analysis) + `wf-plan-modules` (gap priority); CHỈ tạo khi LEGACY + có screens |
| **CS3** | `feature-briefs.json` canonical dùng `_digests/` template | 00-core.md §4b | Consumer đọc tại `.mc-data/docs/_meta/feature-briefs.json`; wf-design + wf-plan-modules + wf-implement-feature đọc ở PRE-GATE digest loading |
| **CS4** | `impl-status-snapshot.json` READ-ONLY 1-shot consume | 00-core.md §4b | Nguồn từ `wf-legacy-scan` Stage 4; consume 1 LẦN ở Phase 0.5 (SAFE-UPDATE); không ghi đè sau đó |
| **CS5** | Path consumer riêng per-entity | `_contract.json.produces_for.wf-implement-feature` | Path dùng placeholder: `.mc-data/docs/phase2-features/[sys-slug]/[mod-slug]/[feat-slug].md` — consumer resolve bằng registry |

### 2.3 Constraint đặc biệt

- **Registry có 2 role đồng thời** — PRIMARY cho `features[]`, SAFE-UPDATE cho top-level `impl_status` (chỉ "skipped" cho DEPRECATE). Khi review, kiểm Phase 5 Safe-Write chỉ set "skipped" CHO features thuộc module trong `$DEPRECATED_MODULES` từ `legacy-decisions.json`.
- **Dual-schema `feature-briefs.json`** là **intentional design** (CORE-007 complex case) — 2 files khác nhau ở 2 location. Đây là phát hiện drift phổ biến; review phải đối chiếu schema 2 template trong `_contract.json`.
- **4 producers** — cao bất thường cho Phase 2 skill. Cần verify skill xử lý đúng:
  - Từ `analyze-req`: full requirements input (primary producer)
  - Từ `legacy-extract`: extracted data (LEGACY)
  - Từ `add-scope`: stubs append-only (consume path: `[sys-slug]/[mod-slug]/[feat-slug].md`)
  - Từ `fix-bugs --deep`: stubs với frontmatter `status: stub` (flesh-out ở Phase 1)
- **File naming difference NEW vs LEGACY** — không phải bug mà là intentional. Test case phải cover cả 2 convention; tools downstream (plan-modules, implement-feature) phải resolve bằng FEAT-ID từ registry chứ không rely filename.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: 2 schema `feature-briefs.json` khác nhau — templates có đúng schema
- [ ] G2: Stub detection logic tồn tại trong `phase2-create-specs.md` (SKILL.md §Stub Detection)
- [ ] G9: Phase 5 Safe-Write chỉ set `impl_status="skipped"` cho features trong `$DEPRECATED_MODULES`
- [ ] CS1: Phase 1 flesh-out logic cho stubs từ add-scope + fix-bugs không break
- [ ] I1: Evals ≥ 3 test cases — nhưng cần bổ sung LEGACY mode + Phase 2.7 coverage

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [`../04-skill-design/wf-define-features/`](../04-skill-design/wf-define-features/) | **Skill design canon (9 files + README)** — vision, arguments, phase routing, file contract, error codes, templates, procedures, ADRs (incl. Referential Integrity v3.1 + W4.7 + CF6), evals |
| [SKILL.md](../../.claude/skills/workflow/wf-define-features/SKILL.md) | Overview, Phase Mapping, dual-schema notes |
| [_contract.json](../../.claude/skills/workflow/wf-define-features/_contract.json) | Contract + cross-skill paths |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-define-features/procedures/_shared.md) | State vars, agent templates, phase ordering by mode |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-define-features/procedures/) | 10 phase files |
| [templates/](../../.claude/skills/workflow/wf-define-features/templates/) | 5 templates (plan, status, checkpoint, feature-briefs, ui-coverage-gaps) |
| [evals/evals.json](../../.claude/skills/workflow/wf-define-features/evals/evals.json) | 3 test cases |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE-006 §4a (PRIMARY + SAFE-UPDATE), CORE-021/022 |

---

## 5. Ghi chú bảo trì

- Khi skill bump version (2.2, 3.0…) → cập nhật `skill.version` + kiểm số phase files.
- Khi thêm producer mới đổ stubs vào `phase2-features/` → cập nhật CS1 + tăng `producers_count`.
- Khi dual-schema `feature-briefs.json` thay đổi → cập nhật G1 + kiểm đồng bộ `_contract.json` 2 entries.
- Khi thêm classification mới cho UI Coverage (Phase 2.7) → cập nhật G10.
- File này là **read-only** trong quá trình review — findings ghi vào `reports/YYYY-MM-DD-wf-define-features.md`.
