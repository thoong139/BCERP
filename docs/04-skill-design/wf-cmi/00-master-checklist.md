# 00 — Master Checklist (wf-cmi)

> **Mục đích file:** Checklist 10-step BẮT BUỘC trước khi PR/commit skill `wf-cmi` (wf-cmi). Gating cho reviewer.

---

## Checklist tổng quan

| # | Step | Trạng thái | Note |
|---|------|-----------|------|
| 1 | Quyết định template variant: **❸ ORCHESTRATOR** | [x] | Skill spawn 10 lanes CD1-CD10 → ORCHESTRATOR variant |
| 2 | Tạo `SKILL.md` từ `.claude/skills/workflow-skill.md` | [x] | Session 2 — 498 dòng (≤500 CORE-032), 16 sections, 8 `### Phase N` sub-sections |
| 3 | Tạo `procedures/` (lazy-load — CORE-032) — 10 files | [x] | Session 4 — 10 files / 5344 dòng, mỗi phase A-H structure |
| 4 | Tạo `_contract.json` + validate schema | [x] | Session 3 — skill-contract-v1, 15 inputs, 10 procedures, 37 outputs, 108 errors, 6 produces_for, 9 consumes_from |
| 5 | Tạo `templates/` (output từ template — CORE-031) — 12 templates | [x] | Session 5 — 29 files thực tế (16 JSON + 13 MD), 8 Phase reports + 4 helper templates |
| 6 | Tạo `evals/evals.json` ≥3 test cases + fixtures | [x] | Session 6 — 5 test cases TC-cmi-001..005, 31 assertions, 4 fixtures (minimal/realistic/corrupt/concurrent) |
| 7 | Tạo `docs/04-skill-design/wf-cmi/` (12 file design canon ORCHESTRATOR — gồm 03-architecture + 03-phase-routing) | [x] | Session 1 — 15 files / ~245 KB (vượt 12 file vì variant ORCHESTRATOR có 05b-execution-profiles + 08b-user-scenarios + agent-prompt). Session 11 (2026-05-16) bổ sung `03-architecture.md` theo template mới (CORE-032 lazy-load + 10 components + session output layout) |
| 8 | Cập nhật `CLAUDE.md` skills table + `docs/01-architecture/07-skills-catalog.md` + `docs/05-review-standards/wf-cmi.md` | [x] | Session 7 (CLAUDE.md + 07-skills-catalog + Protocol 21 + output-path-contract + error-code-registry) + Session 9 (review checklist `wf-cmi.md` 188 dòng) |
| 9 | Tạo `.claude/commands/wf-cmi.md` (slash command entry) | [x] | Tạo Session 8 — 1-line routing pattern, đã verify trong skills registry |
| 10 | Chạy 4 audit scripts → tất cả PASS | [x] | **Session 10** — skill-compliance: **GRADE PASS** (12/12 CRITICAL · 13/13 REQUIRED · 5/5 CONDITIONAL) + validate-schema-sync: 1/1 PASS + validate-pipeline-naming: PASS + check-skill-design-populated: PASS (10 files OK) |

---

## Chi tiết từng step

### Step 1 — Variant: ORCHESTRATOR ❸

Lý do chọn ORCHESTRATOR (theo decision tree §4.1 trong [04-skill-design/README.md](../README.md)):
- Skill có 8 phases (>3) ✅
- Skill spawn ≥3 lane agents (10 lanes CD1-CD10 + 1 triage) ✅
- Skill produce ≥3 cross-skill artifacts (`integrity-impact.json`, `coverage-matrix.json`, `business-invariants.json`, `regression-map.json`) ✅

**Files thêm cho variant ORCHESTRATOR:**
- `08-user-scenarios-solutions.md` (đổi tên từ `.alt`) — UX flows
- `agent-prompt.md` — Template 8-section cho 10 lane agents

### Step 2 — Tạo `SKILL.md` (CHỜ CONFIRM)

```bash
# Sau khi user duyệt design canon:
mkdir -p .claude/skills/workflow/wf-cmi
cp .claude/skills/workflow-skill.md .claude/skills/workflow/wf-cmi/SKILL.md
# Edit: name=wf-cmi, version=1.0.0, theo 02-arguments.md
```

**Verify:**
- `wc -l SKILL.md` ≤ 500 dòng (CORE-032)
- 7 sections bắt buộc: Header + Arguments + Phase Routing + File Contract + Error Codes + Context Budget + Cross-Skill

### Step 3 — Tạo `procedures/` (CHỜ CONFIRM)

```
procedures/
├── _shared.md
├── phase1-init.md
├── phase2-discovery.md
├── phase3-invariant-registry.md
├── phase4-coverage-dispatch.md
├── phase5-aggregate.md
├── phase6-regression.md
├── phase7-gap-cdg.md
├── phase8-report.md
└── resume-status.md
```

Xem outline chi tiết tại [07-procedures-structure.md](07-procedures-structure.md).

### Step 4 — `_contract.json` (CHỜ CONFIRM)

Required fields:
- `$schema: "skill-contract-v1"`
- `skill: "wf-cmi"`
- `version: "1.0.0"`
- `registry_scope.fields_owned[]`: `sidecar `business-invariants.json` (APPEND-only, KHONG touch registry)`, `requirements[].cross_module_dependencies[] (NEW field)`
- `outputs.working[]` với template paths
- `orchestrates[]`: 10 lane sub-skills (TBD nếu tách thành sub-skill)
- `produces_for{}`: wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment
- `consumes_from{}`: wf-brainstorm, wf-analyze-requirements, wf-define-features, wf-design, wf-implement-feature

**Validate:**
```bash
bash .claude/scripts/validate-schema-sync.sh wf-cmi
```

### Step 5 — `templates/` (CHỜ CONFIRM)

12 templates (xem [06-templates-list.md](06-templates-list.md)):
- `integrity-status.json` (SSOT pipeline state)
- `coverage-matrix.json`
- `business-invariants.json`
- `entity-graph.json`
- `module-graph.json`
- `workflow-graph.json`
- `event-graph.json`
- `rbac-matrix.json`
- `regression-map.json`
- `integrity-report.md`
- `coverage-report.md`
- `integrity-impact.json` (cross-skill artifact, schema `integrity-impact-v1`)
- `Phase{N}-report.md` (8 phase reports)

### Step 6 — `evals/evals.json`

5 test cases planned (xem [09-evals-test-cases.md](09-evals-test-cases.md)):
- TC-cmi-001: smoke (EUREKA-2026 1 module, `--profile=quick`)
- TC-cmi-002: integration (EUREKA-2026 3 modules CRM+Orders+Finance, `--profile=standard`)
- TC-cmi-003: edge (registry corruption mid-Phase 3, auto-fix recovery)
- TC-cmi-004: resume (interrupt at Phase 4 lane dispatch)
- TC-cmi-005: concurrent (2 sessions cùng máy)

### Step 7 — Design canon ✅ DONE

`docs/04-skill-design/wf-cmi/` — 15 files populated (12 design canon + 3 alt/extra cho ORCHESTRATOR: `05-execution-profiles.md`, `08-user-scenarios-solutions.md`, `agent-prompt.md`).

**Session 11 (2026-05-16):** Thêm `03-architecture.md` theo template mới — chứa kiến trúc tổng quan 10 components, parallelism model, data flow, state machine, session output layout. Cập nhật `README.md` §3 Files + persona reading paths.

### Step 8 — Cập nhật catalog

| File | Cập nhật |
|------|---------|
| `CLAUDE.md` | Thêm row trong "Standalone Skills" table (gần wf-scan-target, wf-diagram) |
| `docs/01-architecture/07-skills-catalog.md` | Thêm entry wf-cmi với output paths + contracts |
| `docs/04-skill-design/README.md` §3 | Tick wf-cmi ở status table |
| `docs/05-review-standards/wf-cmi.md` | Tạo review checklist riêng (từ `_template-common.md`) |
| `docs/02-standards/08-error-code-registry.md` §4 | Thêm wf-cmi vào bảng "Skills support" |
| `docs/02-standards/11-output-path-contract.md` §3 | Thêm section 3.14 — Cross-Module Integrity paths |
| `.claude/skills/protocols/21-cross-skill-output-path-contract.md` | Update với paths của wf-cmi |

### Step 9 — Slash command

```bash
cp .claude/commands/wf-scan-target.md .claude/commands/wf-cmi.md
# Edit: tên, mô tả, arguments
```

Slash command syntax: `/wf-cmi [args]` (alias cho `/wf-cmi` viết gọn).

### Step 10 — Audit scripts

```bash
./.claude/scripts/skill-compliance-audit.sh wf-cmi
./.claude/scripts/validate-schema-sync.sh wf-cmi
./.claude/scripts/validate-pipeline-naming.sh
bash .claude/scripts/check-skill-design-populated.sh docs/04-skill-design/wf-cmi/
```

**Tất cả 4 phải PASS** — Reviewer reject PR nếu có 1 script fail.

---

## Gating reviewer

PR sẽ **REJECT** nếu:
- Bất kỳ step nào trong bảng tổng quan `[ ]` mà không có Note giải thích
- Bất kỳ audit script nào FAIL
- File này còn chứa unresolved placeholder hoặc `_template_notes` block

**Trạng thái hiện tại:** ✅ **HOÀN THÀNH 10/10 STEPS** (Sessions 1-10). wf-cmi v1.0.0 ready for PR/commit. 4/4 audit scripts PASS. Reviewer accept theo gating rules §3.

---

## Liên kết

- Skill source template: [`.claude/skills/workflow-skill.md`](../../../.claude/skills/workflow-skill.md)
- Validation script: [`.claude/scripts/check-skill-design-populated.sh`](../../../.claude/scripts/check-skill-design-populated.sh)
- README design canon: [`../README.md`](../README.md)
- Standard skill anatomy: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md)
- Plan gốc: [`../../../plans/wf-cmi/wf-cmi.md`](../../../plans/wf-cmi/wf-cmi.md)
