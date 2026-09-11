# Tiêu chuẩn rà soát — `wf-design` v3.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-design/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section**. Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Sinh technical design đầy đủ — architecture, API contract, database, infra, integration + gap analysis (LEGACY) |
| **Entry point** | `procedures/phase0-context.md` |
| **Kiến trúc** | 9 phase files (phase0 → phase8) + `_shared.md` — lazy-loaded; Phase 7 LEGACY-only |
| **Execution mode** | HYBRID — PARALLEL nặng (Phase 1/2/5: multi-agent architect+security+dba+devops); SEQUENTIAL Phase 3/4/6/8 |
| **Branching** | NEW vs LEGACY; 4 conditional agents Phase 1 (ai-engineer, data-engineer, automation-architect); Large Project Mode (LPM) |
| **Đặc trưng** | `--resume`, `--status`, multi-session, LPM auto-detect (systems≥5 OR features≥40), auto-correction loop 8-check Phase 4, Stakeholder Review 3 tiers (SO-01/02/03) |
| **Output** | 6 docs + 12 working files; registry `design_status` PRIMARY (+legacy flow extended fields) |
| **Cross-skill** | 2 producer (define-features, legacy-extract), 3 consumer (design-ux, plan-modules, annotate-code) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-design
  version: 3.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-design/

profile:
  is_orchestrator: false
  has_procedures: true
  has_templates: true             # 3 internal templates (+ 6 doc-framework templates)
  has_phases: true                # 9 phases (0-8) + _shared.md

  has_state_machine: true         # checkpoint.json + design-status.json + phase state transitions
  has_resume: true                # --resume
  has_status: true                # --status
  is_multi_run: false

  spawns_agents: true             # Phase 1/2/3/5 nhiều agents: architect, ai-engineer, data-engineer,
                                  # automation-architect, dba, devops, security (PARALLEL/SEQUENTIAL theo strategy)
  has_strategy_routing: false     # LPM auto-detect (size-based threshold) — KHÔNG phải multi-strategy scoring

  writes_registry: true
  registry_role: PRIMARY          # design_status (primary); legacy flow extension: systems/modules/departments/
                                  # requirements/features/interface_type (khi registry chưa seeded đầy đủ) +
                                  # requirements[].impl_status (FIX-INVALID → not_started, CORE-010)

contracts:
  producers_count: 2              # wf-define-features, wf-legacy-extract
  consumers_count: 3              # wf-design-ux, wf-plan-modules, wf-annotate-code (LEGACY — gap-report)
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ Toàn bộ A1-A10 | |
| **B** Workflow Integrity | ✅ B1-B8 | B5 conditional phase nhiều (Phase 7 LEGACY, Phase 1 conditional agents); B9-B10 SKIP (LPM is threshold không phải strategy scoring) |
| **C** Output & Template | ✅ C1-C7 | 3 internal + 6 doc-framework + 2 digest template — đồng bộ 3 nơi |
| **D** Cross-Skill | ✅ D1-D4 | 2 producer + 3 consumer (LEGACY có thêm wf-annotate-code) |
| **E** Protocol & CORE | ✅ Toàn bộ E1-E18 | E15-E16 PRIMARY + FIX-INVALID (legacy); E17-E18 áp dụng |
| **F** Determinism/Agent | ✅ F1-F4 | Nhiều agent nhất trong các skills; F5-F7 SKIP |
| **H** Error Handling | ✅ H1-H5 | 17 error codes (E000-E016) — đầy đủ nhất |
| **I** Testability | ✅ I1-I5 | 5 test cases |
| **J** Idempotency | ✅ J1-J2 | J3-J4 SKIP |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Multi-Agent Design + LPM + Conditional Agents + Gap Analysis

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | Phase 1 Architecture — architect + conditional agents | `phase1-architecture.md` | Spawn `architect` (always) + conditional: `ai-engineer` (`$HAS_AI_ML=true`), `data-engineer` (`$HAS_DATA_PIPELINE=true`), `automation-architect` (`$HAS_AUTOMATION=true`). Flags detect từ registry/features |
| **G2** | Phase 2 Technical Specs PARALLEL 3 docs | `phase2-specs-parallel.md` | Spawn PARALLEL: api-contract (architect) + database-design (dba+architect) + infra-spec (devops+architect); max 3-5 agents |
| **G3** | Phase 3 Integration Map SEQUENTIAL sau Phase 2 | `phase3-integration.md` | Đợi phase 2 POST-GATE PASS; đọc outputs 2.1 + 2.2 làm input |
| **G4** | Phase 4 Cross-Validation 8-check auto-correction loop | `phase4-crossval.md` | 8 validation checks; loop max 3 iterations; mỗi iteration log vào `design-report.md`; CQG-05 freshness check |
| **G5** | Phase 5 Stakeholder Review 3 tiers (SO-01/02/03) + PARALLEL | `phase5-review.md` | SO-01 architect self-review, SO-02 cross-review (architect Phần B+C), SO-03 gap analysis (security Phần D); 2 agents PARALLEL; Critical/High sau 3 vòng → escalate |
| **G6** | Phase 6 Compressed Spec cho `wf-implement-feature` | `phase6-finalize.md` | Tạo `design-summary.json` (~200 tokens/module), giảm context load từ ~3300 words; consumer là implement-feature Phase 1 step 1.9 |
| **G7** | Phase 7 Gap Analysis LEGACY-only | `phase7-gap.md` | Guard `$LEGACY_MODE=true`; cross-reference design với `module-code-mapping.json` từ legacy-extract; output: gap-report.md + gap-categories.json + action-items.json + final-report.md |
| **G8** | Phase 8 Digest + Phase Summary + Session Log close | `phase8-digest-summary.md` | Sinh `design-input-digest.json` tại `_meta/`; tạo `phase-summary.md` (CORE-028 ≤15 dòng tiếng Việt); append session-log COMPLETE |
| **G9** | LPM auto-detect threshold size-based (4 điều kiện) | `phase0-context.md` + `_shared.md` | `$LPM = (systems >= 5 OR departments >= 10 OR requirements >= 50 OR features >= 40)`; LPM=true → compression sớm hơn, skeleton-first, checkpoint per phase, `max_parallel_agents=3` (vs Standard 5) |
| **G10** | 3 Architecture Documentation Labels (LEGACY only) | `_shared.md §Architecture Labels` | `[VERIFIED]` (từ code/extracted), `[INFERRED]` (AI suy luận), `[RECOMMENDED]` (best practice đề xuất); mọi section P3-01 LEGACY phải có label |
| **G11** | Registry Safe-Write 2 mode (new vs legacy) | `phase6-finalize.md` | NEW flow: chỉ update `design_status`. LEGACY flow (khi registry chưa seeded đầy đủ): được phép update `systems`, `modules`, `departments`, `requirements`, `features`, `interface_type` + FIX-INVALID `requirements[].impl_status → not_started` |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | `design-input-digest.json` tại `_meta/` cho 3 consumer | 00-core.md §4b + `_contract.json` | Consumer: design-ux (UI-only), plan-modules (always), implement-feature (reference); đọc tại PRE-GATE digest loading |
| **CS2** | `design-summary.json` working-only, CHỈ cho implement-feature | `_contract.json.outputs.working[]` + notes | Tại `.mc-data/work/wf-design/` (không lên `_meta/`); implement-feature đọc trực tiếp; KHÔNG phải cross-skill digest chuẩn |
| **CS3** | `action-items.json` LEGACY-only cho plan-modules priority | `_contract.json.produces_for.wf-plan-modules` (conditional) | Chỉ tồn tại khi LEGACY; consumer (plan-modules Phase 0) đọc làm priority input machine-readable; KHÔNG block nếu NEW mode |
| **CS4** | `gap-report.md` cho wf-annotate-code | `_contract.json.produces_for.wf-annotate-code` | LEGACY-only; annotation gaps input cho annotate-code — xác định code files cần inject REQ-ID |
| **CS5** | Registry role kép (PRIMARY vs FIX-INVALID) | 00-core.md §4a bảng Safe-Write | NEW flow PRIMARY; LEGACY flow (gap-filling) FIX-INVALID cho impl_status — chỉ fix invalid → "not_started"; KHÔNG tạo REQ-ID mới |

### 2.3 Constraint đặc biệt

- **9 phase files với Phase 7 LEGACY-only** — là skill duy nhất có Phase 7 condition; procedures/phase7-gap.md phải guard `LEGACY_MODE=true` ngay đầu, early-return nếu NEW.
- **Nhiều agent nhất trong các workflow skills** — 7 agent types (architect, ai-engineer, data-engineer, automation-architect, dba, devops, security). F3 (agent prompt template đầy đủ contract) quan trọng: mỗi agent cần có INPUT paths, OUTPUT paths, POST-GATE expectation rõ.
- **Registry có 2 role tùy flow**: NEW = PRIMARY (chỉ `design_status`), LEGACY gap-filling = PRIMARY mở rộng (6 fields) + FIX-INVALID (impl_status → not_started). Khi review LEGACY flow, cần kiểm: registry đã seeded đủ chưa trước khi Phase 6 write; nếu đã đủ → CHỈ ghi `design_status`, không chạy extended write.
- **LPM không phải strategy routing** — là size-based threshold đơn giản (boolean flag), không có scoring/multi-strategy. Profile flag `has_strategy_routing: false` đúng; không áp dụng G/F7 scoring standards.
- **3 levels template nguồn** — `templates/` (3 internal), `doc-framework/phase3-architecture/` (6 doc output), `doc-framework/_digests/` (1 digest). Cả 3 phải đồng bộ; CORE-031 Template Usage Rule áp dụng mọi output. SKILL.md có ghi rõ "NẾU SKIP bước READ template → STOP skill".

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Conditional agents Phase 1 có guard explicit ($HAS_AI_ML, $HAS_DATA_PIPELINE, $HAS_AUTOMATION)
- [ ] G7: Phase 7 Gap Analysis có guard `LEGACY_MODE=true` + check `module-code-mapping.json` tồn tại (E013)
- [ ] G9: LPM threshold logic — `(systems >= 5 OR departments >= 10 OR requirements >= 50 OR features >= 40)` trong `phase0-context.md` + `_shared.md` (4 điều kiện, đồng bộ SKILL.md)
- [ ] G10: LEGACY Architecture Docs có đủ 3 labels [VERIFIED]/[INFERRED]/[RECOMMENDED]
- [ ] CS5: Phase 6 LEGACY flow chỉ ghi extended fields khi registry chưa seeded đủ; FIX-INVALID chỉ "not_started"

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [`../04-skill-design/wf-design/`](../04-skill-design/wf-design/) | **Skill design canon (9 files + README)** — vision, arguments, phase routing, file contract, error codes, templates, procedures, ADRs, evals |
| [SKILL.md](../../.claude/skills/workflow/wf-design/SKILL.md) | Overview, Phase Routing Map, Output Files, Agents Spawned |
| [_contract.json](../../.claude/skills/workflow/wf-design/_contract.json) | Contract + procedure_map + cross-skill paths |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-design/procedures/_shared.md) | State vars, architecture labels, LEGACY injection, agent prompts, checkpoint, token limit, safe-write |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-design/procedures/) | 9 phase files (phase0-context → phase8-digest-summary) |
| [templates/](../../.claude/skills/workflow/wf-design/templates/) | 3 templates (status, plan, checkpoint) |
| [evals/evals.json](../../.claude/skills/workflow/wf-design/evals/evals.json) | 5 test cases |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE-006 §4a (PRIMARY + FIX-INVALID), CORE-010/013/021/022 |

---

## 5. Ghi chú bảo trì

- Khi skill bump version (3.1, 4.0…) → cập nhật `skill.version` + kiểm agent list trong SKILL.md §Agents Spawned.
- Khi thêm conditional agent mới Phase 1 → cập nhật G1 + `procedures/phase1-architecture.md`.
- Khi LPM threshold thay đổi (systems/features count) → cập nhật G9 + evals.
- Khi thêm consumer mới (ví dụ new skill đọc `design-input-digest.json`) → tăng `consumers_count` + rerun NHÓM D.
- Khi LEGACY gap analysis logic đổi (Phase 7) → cập nhật G7 + CS3/CS4/CS5.
- File này là **read-only** trong quá trình review — findings ghi vào `reports/YYYY-MM-DD-wf-design.md`.
