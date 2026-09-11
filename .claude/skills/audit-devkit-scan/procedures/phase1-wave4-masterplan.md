# Phase 1 — Wave 4: Master Plan Components (Bash verify, SEQUENTIAL)

> Kiểm tra 7 nhóm thành phần từ Master Optimization Plan bằng Bash/Grep. Không cần agent.
>
> **Backward compatible:** thành phần chưa tồn tại → ghi `NOT_FOUND` vào `audit-index.json:master_plan_components`, KHÔNG tạo finding CRITICAL/MAJOR. Findings chỉ tạo khi thành phần TỒN TẠI nhưng SAI/THIẾU.

**PRE-GATE:** Wave 1, 2, 3, 3.5 hoàn thành (sequential vì nhẹ)

**📤 OUTPUT:** Up to 7 files `findings-masterplan-*.json` (optional — chỉ tạo khi thành phần tồn tại)

> Wave 4 chạy **SEQUENTIAL** (MP-1 → MP-2 → ... → MP-7), không cần parallel vì mỗi check rất nhẹ.

---

## MP Index

| Check | Tên | Scope | Output field trong audit-index | Output file |
|-------|-----|-------|--------------------------------|-------------|
| MP-1 | Hook 2-Tầng | `.claude/hooks/_hook-utils.sh` + `*.sh` | `hook_2tier.*` | `findings-masterplan-hooks.json` |
| MP-2 | Baseline Metrics | `.mc-data/work/shared-metrics/` | `baseline_metrics.*` | `findings-masterplan-metrics.json` |
| MP-3 | Checkpoint Context Digest | `checkpoint-schema.json` + `protocols/` + wf-implement-feature | `checkpoint_digest.*` | `findings-masterplan-checkpoint.json` |
| MP-4 | Digest Artifacts Pipeline | `.claude/doc-framework/_digests/` + 11 skills | `digest_pipeline.*` | `findings-masterplan-digests.json` |
| MP-5 | Executable Specification A6-EXT | task template + wf-plan-modules + wf-implement-feature | `executable_spec_a6ext.*` | `findings-masterplan-execspec.json` |
| MP-6 | Micro-Task A7-EXT | task template + wf-implement-feature + wf-plan-modules | `micro_task_a7ext.*` | `findings-masterplan-microtask.json` |
| MP-7 | Parallel Execution | wf-implement-feature + orchestrator.md | `parallel_execution.*` | `findings-masterplan-parallel.json` |

---

## MP-1: Hook 2-Tầng

| Step | Check | Tool | PASS Condition | Nếu NOT_FOUND |
|------|-------|------|----------------|---------------|
| 1.6.1 | `.claude/hooks/_hook-utils.sh` tồn tại | Glob | tồn tại | `hook_utils_exists = "NOT_FOUND"` — skip MP-1 |
| 1.6.2 | `_hook-utils.sh` chứa hàm `hook_detect_tier_mode` | Grep | pattern tìm thấy | `hook_detect_tier_mode_defined = false` → finding MAJOR |
| 1.6.3 | `_hook-utils.sh` chứa biến `MCV3_HOOK_TIER` | Grep | pattern tìm thấy | finding MINOR |
| 1.6.4 | Mỗi hook `*.sh` (trừ `_hook-utils.sh`): chứa `source _hook-utils.sh` hoặc `. _hook-utils.sh` | Grep per file | tìm thấy `_hook-utils` | `hooks_without_tier[]` += hook → finding MINOR per hook |
| 1.6.5 | Populate `hook_2tier.*` vào audit-index, WRITE `findings-masterplan-hooks.json` | Write | JSON valid | - |

---

## MP-2: Baseline Metrics

| Step | Check | Tool | PASS | Nếu NOT_FOUND |
|------|-------|------|------|---------------|
| 1.7.1 | `.mc-data/work/shared-metrics/baseline-schema.json` tồn tại | Glob | tồn tại | `schema_exists = "NOT_FOUND"` — skip MP-2 |
| 1.7.2 | `baseline-schema.json` valid JSON | `node -e JSON.parse` | exit 0 | `schema_valid_json = false` → finding MAJOR |
| 1.7.3 | `baseline-S.json` tồn tại | Glob | tồn tại | `baseline_s_exists = "NOT_FOUND"` → finding MINOR (M/L optional) |
| 1.7.4 | `benchmark-{S,M,L}.md` tồn tại | Glob | tất cả 3 | finding MINOR per file missing |
| 1.7.5 | Populate `baseline_metrics.*`, WRITE `findings-masterplan-metrics.json` | Write | JSON valid | - |

---

## MP-3: Checkpoint Context Digest

| Step | Check | Tool | PASS | Nếu NOT_FOUND |
|------|-------|------|------|---------------|
| 1.8.1 | `.claude/skills/schemas/checkpoint-schema.json` tồn tại | Glob | tồn tại | `schema_has_context_digest = "NOT_FOUND"` — skip 1.8.2 |
| 1.8.2 | `checkpoint-schema.json` chứa field `context_digest` | Grep | pattern `"context_digest"` tìm thấy | `schema_has_context_digest = false` → finding MAJOR |
| 1.8.3 | `.claude/skills/protocols/` tồn tại | Glob | tồn tại | `protocols_mention_context_digest = "NOT_FOUND"` |
| 1.8.4 | `protocols/` Protocol 3 mention `context_digest` | Grep | pattern tìm thấy | `protocols_mention_context_digest = false` → finding MAJOR |
| 1.8.5 | `wf-implement-feature/SKILL.md` chứa step generate hoặc load digest | Grep | pattern `context_digest\|generate.*digest` tìm thấy | `implement_feature_generates_digest = false` → finding MAJOR |
| 1.8.6 | Populate `checkpoint_digest.*`, WRITE `findings-masterplan-checkpoint.json` | Write | JSON valid | - |

---

## MP-4: Digest Artifacts Pipeline

| Step | Check | Tool | PASS | Nếu NOT_FOUND |
|------|-------|------|------|---------------|
| 1.9.1 | `.claude/doc-framework/_digests/` directory tồn tại | Glob | ≥1 file | `templates_dir_exists = "NOT_FOUND"` — skip MP-4 |
| 1.9.2 | Đủ 6 digest templates: `project-digest`, `dept-digests`, `phase1-handoff`, `feature-briefs`, `design-input-digest`, `ux-input-digest` | Glob per file | tất cả 6 | finding MAJOR per template missing |
| 1.9.3 | **PRODUCER skills** có step tạo digest ở POST-GATE: `wf-brainstorm`, `wf-analyze-requirements`, `wf-define-features`, `wf-design`, `wf-design-ux` | Grep `digest\|*-digest` trong SKILL.md POST-GATE section | tìm thấy | `producer_skills_with_digest_step[]` không có skill → finding MAJOR per skill |
| 1.9.4 | **CONSUMER skills** có step đọc digest ở PRE-GATE: `wf-analyze-requirements`, `wf-define-features`, `wf-design`, `wf-design-ux`, `wf-plan-modules`, `wf-implement-feature` | Grep tương tự, PRE-GATE section | tìm thấy | finding MINOR per skill |
| 1.9.5 | Populate `digest_pipeline.*`, WRITE `findings-masterplan-digests.json` | Write | JSON valid | - |

---

## MP-5: Executable Specification A6-EXT

| Step | Check | Tool | PASS | Nếu NOT_FOUND |
|------|-------|------|------|---------------|
| 1.10.1 | Task template (`.claude/doc-framework/phase5-implementation/tasks/**/*.md`) chứa section `A6-EXT` | Glob+Grep | tìm thấy | `task_template_has_a6ext = "NOT_FOUND"` — skip 1.10.2-1.10.3 |
| 1.10.2 | `wf-plan-modules/SKILL.md` chứa step sinh A6-EXT | Grep | tìm thấy | `plan_modules_generates_a6ext = false` → finding MAJOR |
| 1.10.3 | `wf-implement-feature/SKILL.md` chứa step đọc A6-EXT | Grep | tìm thấy | `implement_feature_loads_a6ext = false` → finding MAJOR |
| 1.10.4 | Populate `executable_spec_a6ext.*`, WRITE `findings-masterplan-execspec.json` | Write | JSON valid | - |

---

## MP-6: Micro-Task A7-EXT

| Step | Check | Tool | PASS | Nếu NOT_FOUND |
|------|-------|------|------|---------------|
| 1.11.1 | Task template chứa section `A7-EXT` | Grep | tìm thấy | `task_template_has_a7ext = "NOT_FOUND"` — skip 1.11.2-1.11.4 |
| 1.11.2 | `wf-implement-feature/SKILL.md` chứa flag `--micro-task` | Grep | tìm thấy | `implement_feature_has_microtask_flag = false` → finding MAJOR |
| 1.11.3 | `wf-plan-modules/SKILL.md` chứa Phase 7.5.6 (micro-task structure) | Grep | tìm thấy | `plan_modules_has_microtask_step = false` → finding MAJOR |
| 1.11.4 | `docs/microtask-schema.md` tồn tại | Glob | tồn tại | `microtask_schema_exists = "NOT_FOUND"` → finding MINOR |
| 1.11.5 | Populate `micro_task_a7ext.*`, WRITE `findings-masterplan-microtask.json` | Write | JSON valid | - |

---

## MP-7: Parallel Execution

| Step | Check | Tool | PASS | Nếu NOT_FOUND |
|------|-------|------|------|---------------|
| 1.12.1 | `wf-implement-feature/SKILL.md` chứa `Phase 2.5` (Contract Generation) | Grep | tìm thấy | `implement_feature_has_phase2_5 = "NOT_FOUND"` — skip 1.12.2-1.12.4 |
| 1.12.2 | `wf-implement-feature/SKILL.md` chứa flag `--parallel` | Grep | tìm thấy | `implement_feature_has_parallel_flag = false` → finding MAJOR |
| 1.12.3 | `wf-implement-feature/SKILL.md` chứa flag `--features` | Grep | tìm thấy | `implement_feature_has_features_flag = false` → finding MAJOR |
| 1.12.4 | `wf-implement-feature/SKILL.md` chứa safety rules R1-R5 | Grep | tìm thấy | `implement_feature_has_safety_rules = false` → finding MINOR |
| 1.12.5 | `.claude/agents/orchestrator.md` chứa "Multi-Feature Orchestration" | Grep | tìm thấy | `orchestrator_has_multifeature = false` → finding MINOR |
| 1.12.6 | Populate `parallel_execution.*`, WRITE `findings-masterplan-parallel.json` | Write | JSON valid | - |

---

## POST-GATE (toàn Wave 4)

- **Sau tất cả MP-1 → MP-7:** UPDATE `audit-index.json:master_plan_components` với tất cả kết quả populated.
- Tất cả `findings-masterplan-*.json` tạo thành công (hoặc skip nếu NOT_FOUND)
- Mỗi file tạo là valid JSON với `$schema: "audit-findings-v1"`
- UPDATE `scan-status.json`: `wave_4_masterplan.completed_batches` += 7 IDs (mp-1 ... mp-7), status = "completed"

---

## Cross-references

- audit-index master_plan_components schema: `templates/audit-index.json` §master_plan_components
- Findings schema: `templates/findings.json`
- Next phase: `phase2-merge.md`
