# Tiêu chuẩn rà soát — `wf-brainstorm` v8.1.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-brainstorm/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section**. Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Entry point DEVKIT workflow — chốt khung dự án + tạo Phase 0 docs (P0-01, P0-02, policies) + seed registry |
| **Entry point** | `procedures/phase0-detect-route.md` |
| **Kiến trúc** | Pipeline tuyến tính 7-9 phase files (detect-route → [0.5 legacy] → collect-basic → ba-departments → brainstorm-policy → write-docs → init-registry → generate-digest) |
| **Execution mode** | HYBRID — SEQUENTIAL (context collection) + PARALLEL (experts brainstorm, policy analysis) |
| **Branching** | NEW flow vs LEGACY flow (Phase 0.5 chỉ chạy khi LEGACY_MODE=true) |
| **Đặc trưng** | Không có `--resume`/`--status` (quick skill); `--force` xóa `.mc-data/` khởi tạo lại |
| **Output** | 4 docs + 9 working files; seed registry (SEED role) |
| **Cross-skill** | 0 producer (entry point), 11 consumer skills (qua `legacy-decisions.json` + Phase 0 docs + `project-digest.json`) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-brainstorm
  version: 8.1.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-brainstorm/

profile:
  is_orchestrator: false          # có procedures/ với 9 phase files
  has_procedures: true
  has_templates: true             # 2 working templates
  has_phases: true                # pipeline tuyến tính 7-9 phases

  has_state_machine: false        # chỉ có brainstorm-status.json phẳng, không phải ledger state transitions
  has_resume: false               # không có --resume (quick skill — xem E005)
  has_status: false               # không có --status
  is_multi_run: false             # ghi trực tiếp vào .mc-data/work/wf-brainstorm/

  spawns_agents: true             # Phase 2 BA solo; Phase 3 domain experts PARALLEL
  has_strategy_routing: false     # NEW/LEGACY là branch detect, không phải scoring strategy

  writes_registry: true           # seed project, departments, interface_type
  registry_role: SEED             # 00-core.md §4a — Phase 5.3 ghi 1 lần, PRIMARY (analyze-requirements) override sau

contracts:
  producers_count: 0              # entry point — hoặc consume từ legacy-scan/legacy-extract khi LEGACY
  consumers_count: 11             # analyze-req, define-features, design, design-ux, plan-modules,
                                  # implement-feature, add-scope, annotate-code, fix-bugs, fix-discover, manage-change
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ Toàn bộ A1-A10 | A4 — kiểm tra frontmatter có `disable-model-invocation: true` |
| **B** Workflow Integrity | ✅ B1-B5 | B6-B8 SKIP (no state machine); B7 SKIP (no --resume/--status); B9-B10 SKIP (no strategy) |
| **C** Output & Template | ✅ C1-C7 | Có nhiều conditional outputs (LEGACY-only, STANDARD/ENTERPRISE-only) |
| **D** Cross-Skill | ✅ D1-D4 | 10 consumers — check drift quan trọng; `legacy-decisions.json` shared path |
| **E** Protocol & CORE | ✅ E1-E11, E13-E18 | E12 SKIP (no multi-run); E15-E16 áp dụng (SEED role) |
| **F** Determinism/Agent | ✅ F1-F4 | F5-F7 SKIP (không scan code, không strategy) |
| **H** Error Handling | ✅ H1, H3, H5 | H2+H4 SKIP (no state machine checkpoint) |
| **I** Testability | ✅ I1-I5 | Có 6 test cases (4 original + 2 edge: --force, LEGACY_MODE) |
| **J** Idempotency | ✅ J1 | J2-J4 SKIP (no resume, no script output, no multi-run) |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Branching NEW vs LEGACY + Complexity Classification

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | LEGACY detect dùng CORE-021 | `phase0-detect-route.md` | Detect bằng `project-context.md` > 500 bytes; KHÔNG dùng ledger.json hoặc check khác |
| **G2** | Phase 0.5 chỉ chạy khi LEGACY_MODE | `phase0-5-legacy-snapshot.md` đầu file | Guard `IF LEGACY_MODE=false → skip` rõ ràng, có early-return |
| **G3** | legacy-decisions.json BẮT BUỘC tạo khi LEGACY (CORE-022) | `phase0-5-legacy-snapshot.md` Step | File tạo ra kể cả khi rỗng (empty `divergence_resolutions[]` + `deprecated_modules[]`) |
| **G4** | Complexity classification (SIMPLE/STANDARD/ENTERPRISE) | `phase2-ba-departments.md` Step 2.4a + `phase3-brainstorm-policy.md` Step 3.3a | `complexity-assessment.md` tạo cho TẤT CẢ levels; rule: keywords ERP/enterprise/đa-quốc-gia → ENTERPRISE, else STANDARD, else SIMPLE |
| **G5** | Policy generation conditional | `phase3-brainstorm-policy.md` | Policies files chỉ tạo khi STANDARD hoặc ENTERPRISE; SIMPLE KHÔNG tạo policy |
| **G6** | Phase 2 BA SOLO + Phase 3 experts PARALLEL | `phase2-ba-departments.md` vs `phase3-brainstorm-policy.md` | Phase 2 spawn 1 agent `business-analyst`; Phase 3 spawn N domain experts PARALLEL (retail-expert, hr-expert, ...) |
| **G7** | AskUserQuestion multiSelect cho phòng ban | `phase2-ba-departments.md` | Dùng `AskUserQuestion` tool với `multiSelect:true` để chọn `active_depts[]`, không hỏi free-text |
| **G8** | 4 phiên hỏi SEQUENTIAL (1 câu/turn) | `phase1-collect-basic.md` | Phase 1 hỏi tối đa 4 câu, mỗi câu một turn; KHÔNG batch nhiều câu |
| **G9** | Cross-check Protocol 8 chạy trong phase4-write-docs POST-GATE | `phase4-write-docs.md` POST-GATE | `crosscheck-report.md` được tạo; mismatches blocking → auto-fix source docs |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | `legacy-decisions.json` là bridge file (CORE-022) | `_contract.json` `produces_for` + 00-core.md §4b | File được 11 downstream consumer đọc; wf-brainstorm là owner DUY NHẤT (READ-ONLY sau Phase 0.5.7) |
| **CS2** | SEED role — override sau bởi PRIMARY | 00-core.md §4a | `project`, `departments[]`, `interface_type` ghi Phase 5.3 (SEED); analyze-requirements sẽ override → không conflict |
| **CS3** | `project-intent-digest.json` vs `project-digest.json` | `_contract.json.outputs.working[]` | 2 files khác nhau: intent-digest = working handoff nội bộ (Phase 5.2); project-digest = downstream digest canonical tại `_meta/` (Phase 6) |
| **CS4** | Consume từ legacy-scan + legacy-extract khi LEGACY | `_contract.json.consumes_from` | Paths đúng: `project-context.md`, `doc-quality-map.json`, `external-docs.json`, `extracted/{module}.json`, `dedup-report.json` |

### 2.3 Constraint đặc biệt

- **Không có `--resume` / `--status`** (E005 Error Handling ghi rõ "quick skill — không hỗ trợ `--resume`") → toàn bộ NHÓM B7, E3 (Context & Checkpoint), H2, H4 KHÔNG áp dụng. J2 SKIP.
- **SEED registry role** khác với PRIMARY/APPEND/SAFE-UPDATE — chỉ ghi 1 lần ở Phase 5.3, các field này sẽ bị PRIMARY (analyze-requirements) override. Khi review, cần xác nhận Phase 5.3 chỉ ghi 3 fields (`project`, `departments`, `interface_type`) chứ KHÔNG ghi `systems`/`modules`/`requirements`.
- **Branching path rõ** NEW vs LEGACY ở Phase 0.5 — cần kiểm: `phase0-5-legacy-snapshot.md` KHÔNG được chạy khi NEW; các output conditional (`user_intent.md`, `divergence-resolution.json`, `vision-reconciliation.json`) phải có guard `LEGACY_MODE only`.
- **Frontmatter đã có `disable-model-invocation: true`** — đã được thêm ở v8.1.0. Khi bump version → kiểm tra field vẫn còn.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Phase 0 detect dùng `project-context.md > 500 bytes` (CORE-021)
- [ ] G3: `legacy-decisions.json` tạo cả khi rỗng (CORE-022 graceful degradation)
- [ ] G6: Phase 2 spawn BA SOLO, Phase 3 spawn domain experts PARALLEL
- [ ] CS2: Registry seed Phase 5.3 chỉ ghi đúng 3 fields (`project`, `departments`, `interface_type`)
- [ ] A4: Kiểm tra frontmatter có `disable-model-invocation: true` không (v8.1 SKILL.md hiện thiếu)
- [ ] I3: Kiểm tra evals có LEGACY_MODE test case (case 6) và --force test case (case 5)

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-brainstorm/SKILL.md) | Overview, routing map, Output Files |
| [_contract.json](../../.claude/skills/workflow/wf-brainstorm/_contract.json) | Contract + cross-skill paths |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-brainstorm/procedures/_shared.md) | Protocols + reference tables |
| [procedures/phase0-detect-route.md](../../.claude/skills/workflow/wf-brainstorm/procedures/phase0-detect-route.md) | Entry point — auto-detect NEW/LEGACY |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-brainstorm/procedures/) | 9 phase files |
| [templates/](../../.claude/skills/workflow/wf-brainstorm/templates/) | `brainstorm-status.json`, `project-intent-digest.json` |
| [evals/evals.json](../../.claude/skills/workflow/wf-brainstorm/evals/evals.json) | 6 test cases (NEW, vague, ENTERPRISE, complexity edge, --force, LEGACY_MODE) |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE-006 §4a (SEED role), CORE-021/022 |

---

## 5. Ghi chú bảo trì

- Khi skill bump version (8.2, 9.0…) → cập nhật `skill.version` + kiểm `disable-model-invocation` đã được thêm vào frontmatter chưa.
- Khi thêm phase file mới trong `procedures/` → cập nhật `procedure_files[]` trong `_contract.json`, kiểm Phase File Map trong SKILL.md.
- Khi consumer mới đọc `legacy-decisions.json` → tăng `consumers_count` trong §0, §1 và §2.2 CS1.
- Khi Phase 5.3 registry seed schema đổi → kiểm CS2 (chỉ ghi 3 fields); nếu thêm field → cần xin SEED role mở rộng trong `00-core.md §4a`.
- File này là **read-only** trong quá trình review — findings ghi vào `reports/YYYY-MM-DD-wf-brainstorm.md`.
