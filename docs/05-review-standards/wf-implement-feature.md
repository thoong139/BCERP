# Tiêu chuẩn rà soát — `wf-implement-feature` v3.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-implement-feature/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Core coding skill — TDD implementation + parallel review (code/security/qa) cho 1 hoặc nhiều features |
| **Entry point** | `procedures/phase0-existing-analysis.md` (conditional) hoặc `phase0-5-context-setup.md` |
| **Kiến trúc** | v3.0 refactor: 10 phase files + `_shared.md` + `flow-multi.md` (multi-feature) |
| **Execution mode** | Hỗn hợp: phase deterministic (0.5, 0.7, 1, 6) + agent-spawn (phase 2.5, 3, 4-5, 5a) |
| **Đặc trưng** | Multi-session/resume; multi-feature qua `--features`; micro-task qua `--micro-task`; parallel mode `--parallel`; scenario NEW/EXTEND/MODIFY |
| **Output** | Source code + tests trong repo + 8 working files per feature (impl-status, impl-plan, impl-report, checkpoint, qa-review-attempt-N, decision-registry, existing-patterns, phase-summary) + registry `impl_status` update |
| **Registry** | PRIMARY owner `impl_status` per REQ-ID |
| **Safety** | CORE-020 Pre-Implementation Safety Gate (Phase 0.7) — search code trước khi write |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-implement-feature
  version: 3.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-implement-feature/

profile:
  is_orchestrator: false
  has_procedures: true
  has_templates: true
  has_phases: true

  has_state_machine: true           # impl-status.json (pending/in_progress/paused/error/completed)
                                    # + checkpoint.json per feature
  has_resume: true                  # --resume (multi-session)
  has_status: true                  # --status
  is_multi_run: true                # session isolation qua $FEATURE_SLUG subdir
                                    # (CORE-030): .mc-data/work/wf-implement-feature/$FEATURE_SLUG/

  spawns_agents: true               # developer, code-reviewer, security, qa-lead,
                                    # api-tester, architect (multi-phase)
  has_strategy_routing: true        # Phase 0.7 Safety Gate → 3 confirmed strategies:
                                    # VERIFY_ONLY / COMPLETE_EXISTING / IMPLEMENT_NEW

  writes_registry: true
  registry_role: PRIMARY            # impl_status (§4a — owner chính lifecycle)

contracts:
  producers_count: 4                # wf-plan-modules, wf-define-features,
                                    # wf-brainstorm (legacy), wf-legacy-scan (legacy)
  consumers_count: 2                # wf-preflight, wf-verify-sync
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | Toàn bộ A1-A10 | |
| **B** Workflow Integrity | B1-B10 | B7 `--status`/`--resume` đặc biệt quan trọng; B9-B10 cho `$CONFIRMED_STRATEGY` routing |
| **C** Output & Template | C1-C7 | 1 output `template: null` (`phase-summary.md` — có `notes`) |
| **D** Cross-Skill | D1-D4 | 4 upstream, 2 downstream |
| **E** Protocol & CORE | Toàn bộ E1-E16 + **E12 MULTI-RUN**, E17-E18 (legacy) | |
| **F** Determinism/Agent | F1-F5 (F5 khi scan existing code — CORE-020) | F6-F7 SKIP |
| **H** Error Handling | H1-H5 | E001-E014 đầy đủ; fix rules đặc thù trong SKILL.md |
| **I** Testability | I1-I5 | Cần cover: NEW, EXTEND, MODIFY, --resume, --features, --component, --micro-task, LEGACY |
| **J** Idempotency | J1-J2, **J4** (session isolation) | J3 SKIP |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — TDD + Safety Gate + Multi-Feature Logic

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | Pre-Implementation Safety Gate (CORE-020) | `phase0-7-safety-gate.md` | LUÔN chạy sau Phase 1. Search entity/endpoint/component names từ feature spec trong codebase TRƯỚC write. Strategy mismatch → STOP + hỏi user |
| **G2** | Strategy Routing sau Safety Gate | `phase0-7-safety-gate.md` → `$CONFIRMED_STRATEGY` | 3 modes explicit: VERIFY_ONLY (skip coding, jump Phase 6) / COMPLETE_EXISTING (fill gaps) / IMPLEMENT_NEW (clean) |
| **G3** | TDD Order Enforcement | `phase3-tdd.md` | Test file tạo TRƯỚC hoặc cùng lúc source file; không được tạo source trước rồi test sau |
| **G4** | REQ-ID comment bắt buộc trong mọi source file (CORE-003) | `phase3-tdd.md` Step check | Mỗi `.ts/.py/.cs/...` có `// REQ-ID: REQ-XXX-NNN` hoặc equivalent comment. Validate sau write |
| **G5** | Parallel Review Phase 4-5 | `phase4-5-review-fix.md` | SPAWN đồng thời: code-reviewer + security + qa-lead (+ optional api-tester). Retry loop max 3 attempts. E010 agent timeout → retry 1× → skip với warning |
| **G6** | Review-Fix Loop có convergence | `phase4-5-review-fix.md` | Max 3 attempts; attempt N > 3 → E009 escalate user |
| **G7** | Decision Registry Protocol 12 | `phase0-5-context-setup.md` | Load `decision-registry.json`, track architectural decisions, enforce trong Phase 3 Developer agent prompt |
| **G8** | A6-EXT + A7-EXT support | `phase1-feature-context.md` Step 1.6a | Đọc A6-EXT (executable spec) từ task file → `$EXECUTABLE_SPEC`; fallback A1-A6 nếu không có |
| **G9** | Multi-Feature Scheduling (`--features`) | `flow-multi.md` | PAR-09 (Protocol 7): features độc lập PARALLEL; features có dep SEQUENTIAL. Check không share source files |
| **G10** | Micro-task support (`--micro-task`) | Require A7-EXT | Chỉ implement 1 micro-task (MT-FEAT-NNN); require A7-EXT trong task file |
| **G11** | Partial component (`--component=X`) | Arguments table | `impl_status = "done"` CHỈ khi TẤT CẢ components = "done" (không done sớm) |
| **G12** | GATE-13 Tests Must Pass | Protocol 13 reference | Tests PHẢI pass trước khi tiếp tục phase; fail → Review-Fix Loop |
| **G13** | Context digest injection on resume (Protocol 3.4) | `phase0-5-context-setup.md` | Resume → inject context_digest để tránh AI quên context qua session |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | Session isolation per feature (CORE-030) | `_contract.json outputs.working[]` paths | Mọi working file có prefix `$FEATURE_SLUG/` → multi-run không ghi đè. Kiểm `mkdir -p` trong Phase 0.2b |
| **CS2** | FEATURE_SLUG derivation deterministic | `SKILL.md §FEATURE_SLUG Derivation` | Derive từ feature NAME (lowercase + hyphen), KHÔNG dùng FEAT-ID làm slug. Consistent qua registry lookup |
| **CS3** | Registry PRIMARY `impl_status` chỉ set cho REQ-ID có trong registry | `_contract.json.registry_scope.notes` | KHÔNG tạo REQ-ID mới (CORE-004). Chỉ update existing REQ-ID |
| **CS4** | Source code output KHÔNG liệt kê trong `outputs.docs[]` | `_contract.json outputs.docs = []` | `outputs.docs = []` đúng; source code là output nhưng không dùng doc-framework template. Làm ở Phase 3 TDD |
| **CS5** | Task file path path `[sys]/[mod]/[feat]-impl.md` khớp wf-plan-modules | `consumes_from.wf-plan-modules` | Path khớp §4b dòng 203 — "`tasks/[sys]/[mod]/[feat]-impl.md`" |
| **CS6** | Downstream outputs via registry update duy nhất | `produces_for` | Cả `wf-preflight` và `wf-verify-sync` consume cùng `req-registry.json` (impl_status) — khớp §4b dòng 205 |

### 2.3 Constraint đặc biệt

- **CORE-020 Pre-Implementation Safety Gate** — bắt buộc MỌI dự án (không chỉ LEGACY). `wf-implement-feature` là skill BẮT BUỘC thực thi. Safety gate phải search codebase TRƯỚC write; strategy mismatch → STOP + user confirmation (CORE-027).
- **CORE-030 Session Isolation** — đây là skill tiêu biểu cho multi-run pattern với `$FEATURE_SLUG`. Kiểm tra E12 nghiêm ngặt: mọi working file có `$FEATURE_SLUG/` prefix; không ghi đè session cũ.
- **Registry PRIMARY lifecycle** — owner chính của `impl_status`. Các skills khác (verify-sync, fix-execute) chỉ SAFE-UPDATE. Đây là skill duy nhất có quyền transition full: `not_started` → `in_progress` → `done`.
- **CDG (Critical Decision Gate) trigger points** — Safety Gate mismatch (CORE-027), Re-run completed feature (E014), Regression rollback (E012).
- **`outputs.docs = []`** — không tạo file trong `.mc-data/docs/`; output chính là source code trong repo + working files. Điều này phá vỡ pattern chung của workflow skills khác (thường có doc output).
- **Multi-feature orchestration tách biệt** — `flow-multi.md` là sub-flow riêng (không phải phase-in-phase); khi `--features` flag → delegate hoàn toàn, không chạy phase-per-file.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Safety Gate (Phase 0.7) chạy SAU Phase 1, có search codebase
- [ ] G2: `$CONFIRMED_STRATEGY` ∈ {VERIFY_ONLY, COMPLETE_EXISTING, IMPLEMENT_NEW}
- [ ] G3: TDD — test file xuất hiện TRƯỚC hoặc cùng lúc với source file
- [ ] G4: Mọi source file output có REQ-ID comment
- [ ] CS1: Session isolation — grep `$FEATURE_SLUG` trong mọi output path working files
- [ ] CS4: `_contract.json outputs.docs = []`
- [ ] E12: Multi-run — 2 features paralel không ghi đè nhau (session dir riêng)
- [ ] E16: `fields_owned = ["impl_status"]` khớp §4a PRIMARY

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [`../04-skill-design/wf-implement-feature/`](../04-skill-design/wf-implement-feature/) | **Skill design canon (9 files + README)** — vision, arguments, phase routing, file contract, error codes, templates, procedures, ADRs, evals |
| [SKILL.md](../../.claude/skills/workflow/wf-implement-feature/SKILL.md) | Overview, Phase Orchestration, Arguments, FEATURE_SLUG derivation, Error handling |
| [_contract.json](../../.claude/skills/workflow/wf-implement-feature/_contract.json) | Schema, 12-item `procedure[]` array |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-implement-feature/procedures/_shared.md) | Agent contexts (6 agents) + protocols + error codes |
| [procedures/phase*.md](../../.claude/skills/workflow/wf-implement-feature/procedures/) | 10 phase files |
| [procedures/flow-multi.md](../../.claude/skills/workflow/wf-implement-feature/procedures/flow-multi.md) | Multi-feature orchestration (sub-flow) |
| [templates/](../../.claude/skills/workflow/wf-implement-feature/templates/) | 7 templates (status, plan, report, checkpoint, qa-review, decision-registry, existing-patterns) |
| [evals/evals.json](../../.claude/skills/workflow/wf-implement-feature/evals/evals.json) | Test cases |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE — §4a PRIMARY impl_status, CORE-020 Safety Gate, CORE-030 Session Isolation |

---

## 5. Ghi chú bảo trì riêng file này

- Khi skill bump version → cập nhật §1 + xem G-section có lỗi thời không (Safety Gate wording, Strategy labels).
- Khi thêm phase mới → cập nhật A8 (routing), B1 (routing map), G-section nếu có logic đặc thù.
- Khi `$CONFIRMED_STRATEGY` mở rộng (ví dụ thêm `SKIP` hay `FORK`) → cập nhật G2 + evals I2.
- Khi thêm agent mới (ví dụ performance-engineer) → cập nhật profile spawns_agents + G5 parallel review.
- Khi A6-EXT schema đổi → cập nhật G8.
- File này là **read-only** trong quá trình review — không tự chỉnh findings.
