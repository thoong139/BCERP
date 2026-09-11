# Tiêu chuẩn rà soát — `wf-analyze-requirements` v2.1.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-analyze-requirements/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section**. Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Multi-agent requirements analysis — huy động BA + Domain Experts sinh Phase 1 business docs + registry PRIMARY |
| **Entry point** | `procedures/phase0-context.md` |
| **Kiến trúc** | 14 phase files + `_shared.md` — load-on-demand (~85-90% token saving vs monolithic cũ) |
| **Execution mode** | HYBRID — SEQUENTIAL (BA scope/plan) + PARALLEL (experts per department, batch) |
| **Branching** | NEW flow vs LEGACY flow (Phase 3.5 + phase5 existing-docs conditional) |
| **Đặc trưng** | `--resume`, `--status`, multi-session, auto-correction loop 8-check (Phase 8b), checkpoint filesystem reconciliation |
| **Output** | 5 docs + 10 working files; registry PRIMARY write (requirements[], systems[], modules[], departments[], interface_type) |
| **Cross-skill** | 2 producer (brainstorm, legacy-extract), 2 consumer (define-features, add-scope) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-analyze-requirements
  version: 2.1.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-analyze-requirements/

profile:
  is_orchestrator: false          # có 14 procedures phase files
  has_procedures: true
  has_templates: true             # 5 templates
  has_phases: true                # 14 phases + _shared.md

  has_state_machine: true         # checkpoint.json + analyze-status.json + phase state transitions
  has_resume: true                # --resume (argument-hint)
  has_status: true                # --status (argument-hint) với filesystem reconciliation
  is_multi_run: false             # ghi trực tiếp vào .mc-data/work/wf-analyze-requirements/

  spawns_agents: true             # Phase 3 BA (solo) + Phase 4 domain experts PARALLEL per dept
  has_strategy_routing: false     # NEW/LEGACY là branch, không scoring

  writes_registry: true           # PRIMARY cho requirement model
  registry_role: PRIMARY          # 00-core.md §4a — owner chính systems/modules/requirements/departments/interface_type

contracts:
  producers_count: 2              # wf-brainstorm (new+legacy), wf-legacy-extract (legacy)
  consumers_count: 2              # wf-define-features, wf-add-scope
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ Toàn bộ A1-A10 | |
| **B** Workflow Integrity | ✅ B1-B8 | B9-B10 SKIP (no strategy routing) |
| **C** Output & Template | ✅ C1-C7 | Có conditional outputs (legacy-specific) + dual-location digest |
| **D** Cross-Skill | ✅ D1-D4 | 2 producer + 2 consumer — scope nhỏ nhưng digest artifact rất quan trọng (dept-digests, phase1-handoff) |
| **E** Protocol & CORE | ✅ Toàn bộ E1-E18 | E15-E16 PRIMARY role; E17-E18 áp dụng (legacy flow) |
| **F** Determinism/Agent | ✅ F1-F4 | F5-F7 SKIP (không scan code, không scoring) |
| **H** Error Handling | ✅ H1-H5 | Đầy đủ checkpoint + atomic write |
| **I** Testability | ✅ I1-I5 | 14 test cases |
| **J** Idempotency | ✅ J1-J2 | J3-J4 SKIP (no script output, no multi-run) |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Multi-Agent Parallelization + 7-Check Auto-Correction Loop

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | Phase 3 BA Part A (PARALLEL per dept) + Phase 4 Domain Experts (PARALLEL per department) | `phase3-ba-parta.md` vs `phase4-experts-partb.md` | Phase 3 spawn N BA agents PARALLEL (1 per dept, batch ≤ `max_parallel_agents`); Phase 4 spawn N domain expert agents PARALLEL (1 agent/department, batch ≤ `max_parallel_agents`) |
| **G2** | Agent context chia 2 phần — Part A (BA overview) + Part B (expert depth) | `phase3-ba-parta.md` + `phase4-experts-partb.md` | Mỗi department có 2 giai đoạn: BA tạo khung (Part A) → expert đào sâu (Part B), output merged vào `departments/[dept]/[dept].md` |
| **G3** | Phase 8b Cross-Validation auto-correction loop max 3 iterations × 8 checks | `phase8b-crossval.md` | 8 checks (8b.1→8b.7 + 8b.3b: coverage, REQ-ID uniqueness, deferred no critical, decision records, JSON valid, no duplicates, no placeholders, traceability); loop tối đa 3 lần; ≥3 lần vẫn fail → escalate |
| **G4** | Phase 3.5 LEGACY only | `phase3.5-legacy.md` đầu file | Guard `IF $LEGACY_MODE=false → skip`; naming normalization (CORE-015) chạy TRƯỚC consolidation |
| **G5** | Phase 5 (existing docs) conditional | `phase5-existing-docs.md` | Chỉ chạy khi `$HAS_EXISTING_DOCS=true` (có `external-docs.json` từ legacy-scan) |
| **G6** | Phase 6b/6c/6d chỉ chạy khi `scope=all` | `phase6b-workflow.md`, `phase6c-stakeholder.md`, `phase6d-conflict.md` | Guard đầu file; scope ≠ all → skip; scope=all → P1-02 + stakeholder-review.md + deferred-issues.md |
| **G7** | Phase 6d conflict resolution tracks explicit | `_shared.md §Resolution Tracks` | Có định nghĩa rõ: Track A (auto-merge), Track B (spawn arbiter), Track C (defer to user); mỗi conflict có decision log |
| **G8** | Filesystem reconciliation ở `--status` | SKILL.md `--status` handler | So sánh `actual_dept_files` (scan disk) vs `checkpoint.depts_completed`; hiển thị cả hai; báo "checkpoint chưa đồng bộ" nếu khác |
| **G9** | Phase 3 (Handoff) chạy SAU Phase 2 (Registry) | SKILL.md Phase mapping | `phase8c-handoff.md` chạy sau `phase8-registry.md` + `phase8b-crossval.md` vì digests phải phản ánh registry cuối |
| **G10** | Dual-schema digest: working `templates/` vs canonical `_digests/` | `_contract.json.outputs.working[]` | Working path tại `.mc-data/work/` dùng `templates/*.json` (starter); canonical path tại `.mc-data/docs/_meta/` dùng `_digests/*.template.json` (schema reference); Phase 3.4 copy working → canonical |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | Registry PRIMARY owner 5 fields | 00-core.md §4a + `_contract.json.registry_scope.fields_owned` | Ghi `systems`, `modules`, `departments`, `requirements`, `interface_type` — KHÔNG ghi `features[]`, `design_status`, `ux_design_status`, `implementation_order`, `impl_status` |
| **CS2** | `dept-digests.json` + `phase1-handoff.json` tại `_meta/` | `_contract.json` + 00-core.md §4b | 2 files canonical tại `.mc-data/docs/_meta/`; consumer (define-features) đọc tại PRE-GATE Phase 0.1; dual-location với working copies |
| **CS3** | `deferred-issues.md` là optional input của define-features | `_contract.json.produces_for.wf-define-features` | File tạo ở Phase 6d (scope=all only); consumer coi là optional (required:false) |
| **CS4** | PRIMARY override SEED từ brainstorm | 00-core.md §4a | `project`, `departments[]`, `interface_type` được brainstorm SEED Phase 5.3; analyze-requirements OVERRIDE với data đầy đủ ở Phase 8 — không append, replace |

### 2.3 Constraint đặc biệt

- **14 phase files** — lớn nhất trong các workflow skills; Load-on-Demand quan trọng, phase files phải self-contained (B2) và chỉ reference `_shared.md §<section>` cụ thể.
- **Phase 3 (Handoff) chạy SAU Phase 2 (Registry)** — ngược với các skill khác thường Registry cuối. Nguyên nhân: digest phản ánh registry post-crossval cuối cùng. Cần kiểm routing map trong SKILL.md khớp.
- **Checkpoint filesystem reconciliation** ở `--status` — pattern đặc biệt để phát hiện checkpoint ↔ disk mismatch. Khi review cần kiểm bash scan `find departments/` hoạt động chính xác.
- **Registry PRIMARY** role — ghi đầy đủ 5 fields; phải ĐỌC registry fresh trước ghi, ghi ATOMIC, validate với `jq` sau ghi (Safe-Write CORE-006).

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Phase 3 BA SOLO + Phase 4 experts PARALLEL per dept
- [ ] G3: 8-check Cross-Validation loop max 3 iterations (8b.1→8b.7 + 8b.3b)
- [ ] G9: Phase 8c (Handoff) chạy SAU Phase 8 (Registry) + 8b (Crossval)
- [ ] G10: Dual-schema digest — working templates vs canonical `_digests/` templates
- [ ] CS1: Registry Safe-Write chỉ ghi đúng 5 fields được phân công

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [`../04-skill-design/wf-analyze-requirements/`](../04-skill-design/wf-analyze-requirements/) | **Skill design canon (9 files + README)** — vision, arguments, phase routing, file contract, error codes, templates, procedures, ADRs, evals |
| [SKILL.md](../../.claude/skills/workflow/wf-analyze-requirements/SKILL.md) | Overview, routing, Phase Mapping |
| [_contract.json](../../.claude/skills/workflow/wf-analyze-requirements/_contract.json) | Contract + cross-skill paths |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-analyze-requirements/procedures/_shared.md) | State vars, agent templates, fix rules, registry schema |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-analyze-requirements/procedures/) | 14 phase files (phase0-context → phase8c-handoff) |
| [templates/](../../.claude/skills/workflow/wf-analyze-requirements/templates/) | 5 templates (analyze-plan, status, checkpoint, dept-digests, phase1-handoff) |
| [evals/evals.json](../../.claude/skills/workflow/wf-analyze-requirements/evals/evals.json) | 14 test cases |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE-006 §4a (PRIMARY), CORE-015 (naming), CORE-021/022 |

---

## 5. Ghi chú bảo trì

- Khi skill bump version (2.2, 3.0…) → cập nhật `skill.version` + kiểm số phase files trong `_contract.json.procedure_files[]`.
- Khi thêm cross-validation check mới (≥ 9 checks) → cập nhật G3 + evals coverage + analyze-status.json validation_details.
- Khi thêm producer/consumer → cập nhật `contracts.producers_count` / `consumers_count` + rerun NHÓM D.
- Khi dual-schema digest thay đổi → cập nhật G10 + kiểm `_contract.json.outputs.working[]` có cả 2 entries (working + canonical).
- File này là **read-only** trong quá trình review — findings ghi vào `reports/YYYY-MM-DD-wf-analyze-requirements.md`.
