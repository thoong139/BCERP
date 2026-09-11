# Tiêu chuẩn rà soát — `wf-plan-modules` v1.7.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-plan-modules/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Phase 5 Implementation planning — dependency graph, topological sort, sprint plans, task files per feature |
| **Entry point** | `procedures/phase0-init.md` |
| **Kiến trúc** | Lazy-load 14 phase files + `_shared.md` (v1.7.0 refactor từ flow-new.md monolithic 962 dòng) |
| **Execution mode** | Chủ yếu DETERMINISTIC (Phase 0-7a); Phase 7.5 + 7b spawn `architect`/`qa-lead` agents |
| **Đặc trưng** | Có `--resume`, `--status`, 5 modes: `--graph` / `--mvp` / `--impact=<mod>` / `--skip-sprints` / default |
| **Output** | 7 doc files (module-plan, dep-graph, roadmap, sprints/*, tasks/*-impl, stakeholder-review, orphan placeholder) + 4 working files |
| **Registry** | PRIMARY `implementation_order` + SAFE-UPDATE `impl_status` (chỉ "skipped" cho DEPRECATED) |
| **Cross-skill** | 3 upstream, 1 downstream (`wf-implement-feature`) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-plan-modules
  version: 1.7.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-plan-modules/

profile:
  is_orchestrator: false
  has_procedures: true
  has_templates: true
  has_phases: true

  has_state_machine: true           # planmod-status.json + checkpoint.json
  has_resume: true                  # --resume
  has_status: true                  # --status
  is_multi_run: false               # single working dir work/wf-plan-modules/

  spawns_agents: true               # architect (Phase 7.5 per feature), architect + qa-lead
                                    # (Phase 7b Stakeholder Review)
  has_strategy_routing: false       # có modes (--graph/--mvp/--impact) nhưng không phải
                                    # scoring-based strategy

  writes_registry: true
  registry_role: PRIMARY            # implementation_order (PRIMARY) +
                                    # impl_status (SAFE-UPDATE, chỉ "skipped")

contracts:
  producers_count: 3                # wf-define-features, wf-design, wf-design-ux
  consumers_count: 1                # wf-implement-feature
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | Toàn bộ A1-A10 | |
| **B** Workflow Integrity | B1-B8 (SKIP B9-B10 — không strategy scoring) | |
| **C** Output & Template | C1-C7 | 1 output `template: null` (`module-plan.md` inline) + 1 optional (`_index.md`) cần kiểm C2/C6 |
| **D** Cross-Skill | D1-D4 | `consumes_from` có 3 producers; `produces_for.wf-implement-feature` có 6 paths |
| **E** Protocol & CORE | E1-E16, E17-E18 (legacy Phase 1.5) | E12 SKIP |
| **F** Determinism/Agent | F1-F4 | Phase 0-7a deterministic; F5-F7 SKIP (không scan) |
| **H** Error Handling | H1-H5 | E001-E012 đầy đủ, E012 có escalation 3 options |
| **I** Testability | I1-I5 | Cần cover: new + LEGACY + --mvp + --impact + orphan |
| **J** Idempotency | J1-J2 (SKIP J4) | |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Dependency & Implementation Strategy Logic

Tiêu chuẩn đặc thù không tổng quát hóa — chỉ áp dụng `wf-plan-modules`.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | Implementation Strategy Verification (CORE-019) | Grep `implementation_strategy` trong `phase1.5-legacy-impl.md` + `phase7.5-tasks.md` | Mỗi task file có `implementation_strategy ∈ {VERIFY_ONLY, COMPLETE_EXISTING, IMPLEMENT_NEW}` + `existing_code_refs[]` + `gaps_identified[]` nếu COMPLETE_EXISTING. Xác định dựa trên cross-reference code thực tế (CORE-019), không chỉ registry impl_status |
| **G2** | Feature-Level Code Verification khi LEGACY | `phase1.5-legacy-impl.md` | Khi `$LEGACY_MODE=true` → read `module-code-mapping.json`, cross-reference Glob/Grep thực tế; KHÔNG dựa vào registry `impl_status` một chiều |
| **G3** | Circular Dependency Detection | `phase3-cycles.md` | Phát hiện cycle → hiển thị options + chờ user chọn (E002). Không auto-break |
| **G4** | Topological sort đúng thứ tự | `phase4-topo.md` | Output `$LAYERS`: module ở layer N không phụ thuộc module ở layer >N; parallel modules cùng layer |
| **G5** | Upstream Coverage Gap (Phase 1.7) | `phase1-validate.md` | Phát hiện orphan systems (trong `systems[]` nhưng không có modules/features) → 3 options STOP/placeholders/thin_clients. Strategy `placeholders` → Phase 7.5.0 tạo `_NO-FEATURES.md` |
| **G6** | Orphan Placeholder Format | `phase7.5.0-orphan.md` + `templates/orphan-no-features.md.tpl` | Mỗi orphan system có 1 `_NO-FEATURES.md` trong `tasks/[sys-slug]/` với content explaining gap |
| **G7** | MVP mode Scope Minimalization | `phase5-mvp.md` | `--mvp` flag → chỉ chọn modules critical path tối thiểu; output MVP subset trong roadmap |
| **G8** | Impact mode cho specific module | `phase6-impact.md` | `--impact=<mod>` → phân tích downstream modules bị ảnh hưởng khi thay đổi module chỉ định |
| **G9** | A6-EXT + A7-EXT trong task file | `phase7.5-tasks.md` | Mỗi feature spawn `architect` để generate EXT sections; task file chứa A6-EXT (executable spec) + A7-EXT (micro-tasks) |
| **G10** | Parallel Review Phase 7b | `phase7b-review.md` | Spawn architect + qa-lead PARALLEL (+ optional 1 domain expert); E011 agent timeout → retry 1× → skip với warning log |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | UX digest conditional path | `_contract.json inputs[]` | `ux-input-digest.json` có `condition: "interface_type != 'api-only'"`. Khi api-only → bỏ qua, đọc trực tiếp từ wf-design output (khớp §4b dòng 201) |
| **CS2** | LEGACY inputs optional 4 files | `_contract.json inputs[]` | 4 inputs (`project-context.md`, `action-items.json`, `gap-report.md`, `module-code-mapping.json`) đều `required: false, condition: "LEGACY_MODE only"` |
| **CS3** | `legacy-decisions.json` DEPRECATE enforcement | `phase0-init.md` + `phase7-outputs.md` | DEPRECATED modules bị loại khỏi `implementation_order`; features thuộc DEPRECATED modules set `impl_status: "skipped"` (SAFE-UPDATE) |
| **CS4** | Registry SAFE-UPDATE scope hẹp | §4a + `_contract.json.registry_scope.notes` | `impl_status` CHỈ được set `"skipped"` và CHỈ cho features thuộc `$DEPRECATED_MODULES`. KHÔNG downgrade `done` → khác |
| **CS5** | Task file path canonical | `_contract.json outputs.docs[]` + §4b dòng 203 | Path `tasks/[sys]/[mod]/[feat]-impl.md` khớp `wf-implement-feature` Phase 1+2 consumer. Contract key `feature-impl` |
| **CS6** | Sprints folder isolation | `_contract.json outputs.docs[]` notes | Tất cả sprint/remediation plan files nằm trong `sprints/`, KHÔNG tạo ở root `phase5-implementation/` |

### 2.3 Constraint đặc biệt

- **CORE-019 Feature-Level Code Verification** — `wf-plan-modules` là skill BẮT BUỘC thực thi CORE-019. Mỗi task file phải có `implementation_strategy` + cross-reference code thực tế; không được chỉ dựa vào registry `impl_status` (có thể sai).
- **Parse JSON, KHÔNG parse Markdown** — CORE-004 bắt buộc. `wf-plan-modules` PHẢI đọc `req-registry.json` trực tiếp cho modules/features/impl_status.
- **Dual registry role** — PRIMARY cho `implementation_order` (tự do ghi) + SAFE-UPDATE cho `impl_status` (chỉ `skipped` cho DEPRECATED). Review cần kiểm tra 2 permissions không bị nhầm lẫn trong code.
- **`module-plan.md` không có template file** — inline schema (từ LAYERS data); C2 PASS khi có `notes` giải thích. `_NO-FEATURES.md` có template (`templates/orphan-no-features.md.tpl`). `dependency-graph.md` có template (`doc-framework/_meta/dependency-graph.md`) phải tồn tại.
- **Phase count cao (15 phase files)** — cần đảm bảo A8 (routing map khớp folder) và B2 (mỗi phase self-contained) chặt chẽ. Có phase 1.5 (legacy), 7.5.0 (orphan), 7a/7b/7c phân đoạn hậu-output.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Mỗi task file có `implementation_strategy` (grep `VERIFY_ONLY|COMPLETE_EXISTING|IMPLEMENT_NEW`)
- [ ] G4: `$LAYERS` topological sort đúng — test case 1 CRM 5 modules
- [ ] G5: Phase 1.7 Upstream Coverage Gap hoạt động; phát hiện orphan system
- [ ] CS3: DEPRECATED modules bị loại + features set `impl_status: "skipped"`
- [ ] CS4: SAFE-UPDATE không downgrade `done` → khác; chỉ set `"skipped"` cho DEPRECATED
- [ ] E16: `fields_owned = ["implementation_order", "impl_status"]` khớp §4a (PRIMARY + SAFE-UPDATE)

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-plan-modules/SKILL.md) | Overview, Phase Routing Map, Output Files |
| [_contract.json](../../.claude/skills/workflow/wf-plan-modules/_contract.json) | Schema-level contract, `procedure_files[]` liệt kê 14 procedures |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-plan-modules/procedures/_shared.md) | State vars, Fix Rules, Cross-Phase Data Flow |
| [procedures/phase*.md](../../.claude/skills/workflow/wf-plan-modules/procedures/) | 14 phase files (0, 1, 1.5, 2-7, 7.5.0, 7.5, 7a, 7b, 7c) |
| [templates/](../../.claude/skills/workflow/wf-plan-modules/templates/) | 5 templates: status, plan, checkpoint, orphan-no-features.tpl, implementation-strategy.tpl |
| [evals/evals.json](../../.claude/skills/workflow/wf-plan-modules/evals/evals.json) | Test cases |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE — §4a registry roles (PRIMARY + SAFE-UPDATE), CORE-019 |

---

## 5. Ghi chú bảo trì riêng file này

- Khi skill bump version → cập nhật `skill.version` §1 + review G1-G10 (CORE-019 wording thay đổi?).
- Khi thêm mode mới (`--profile=X`…) → cập nhật G7/G8 + evals I2 coverage.
- Khi `implementation_order` schema đổi → cập nhật G4 + CS4.
- Khi thêm consumer cho task files → cập nhật `contracts.consumers_count` + CS5.
- File này là **read-only** trong quá trình review — không tự chỉnh findings.
