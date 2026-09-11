# Phase 3.5: Master Plan Components Verification [v1.2]

> Cross-check tính nhất quán nội bộ của 7 thành phần Master Optimization Plan + 3 bridge chain checks.
> Chỉ chạy khi `$SCOPE` ∈ { `master-plan`, `all` }. Skip hoàn toàn khi `$SCOPE = "skill"`.
>
> **Điều kiện chạy:** Kiểm tra `$INDEX.master_plan_components`.
> - Nếu **TẤT CẢ** trường = `"NOT_FOUND"` → skip với log `"Master Plan components not deployed — skip Phase 3.5"`
> - Nếu **ÍT NHẤT 1** trường non-NOT_FOUND → chạy đầy đủ V1-V6
>
> **V7-V9 (bridge chain)** chạy ĐỒNG THỜI với V1-V5 (không phụ thuộc master_plan_components — luôn chạy khi Phase 3.5 active).
>
> **Backward compatible:** Thành phần chưa triển khai (`"NOT_FOUND"`) → skip check tương ứng, KHÔNG tạo finding. Findings chỉ tạo khi thành phần đã tồn tại nhưng inconsistent/broken.

## PRE-GATE

- Phase 0 POST-GATE pass
- (nếu `$SCOPE = all`) Phase 3 POST-GATE pass
- (nếu `$SCOPE = master-plan`) Phase 0 enough

## Kiểm tra điều kiện chạy

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.5.0 | Đọc `$INDEX.master_plan_components` → lưu `$MP_COMPONENTS` | Read | loaded |
| 3.5.0a | Kiểm tra: có bất kỳ giá trị non-`"NOT_FOUND"` nào không? → set `$SKIP_PHASE_3_5` | - | flag set |
| 3.5.0b | Nếu `$SKIP_PHASE_3_5 = true` → ghi log, tạo `findings-masterplan-verify.json` RỖNG với `skip_reason`, nhảy tới POST-GATE | Write | file created |

## V1-V5 + V7-V9 (SONG SONG) + V6 (SAU V1-V5)

Chạy V1 + V2 + V3 + V4 + V5 + V7 + V8 + V9 ĐỒNG THỜI (8 Bash/Grep checks độc lập). V6 chạy sau.

> Mỗi V1-V5 có **trigger condition** riêng. Nếu trigger không met → skip check đó (không tạo findings).
> Có thể có <5 checks chạy thực tế.

---

### V1: Hook 2-Tầng Integrity

> **Trigger:** `$MP_COMPONENTS.hook_2tier.hook_utils_exists != "NOT_FOUND"`

| Step | Cross-check | Tool | Điều kiện PASS | Finding nếu FAIL |
|------|-------------|------|----------------|-----------------|
| V1.1 | `_hook-utils.sh` PHẢI tồn tại nếu bất kỳ hook nào trong `hooks_with_tier[]` reference `hook_detect_tier_mode` | Glob | File tồn tại | CRITICAL: `_hook-utils.sh` missing nhưng hooks đã reference nó |
| V1.2 | Mỗi hook trong `hooks_with_tier[]`: source/`. ` path trỏ đúng tới `_hook-utils.sh` | Grep per file | `source.*_hook-utils` hoặc `\. .*_hook-utils` match | MAJOR: source path sai — hook có thể fail runtime |
| V1.3 | `_hook-utils.sh` export `MCV3_HOOK_TIER` — giá trị chỉ được là `1` hoặc `2` | Grep | pattern `MCV3_HOOK_TIER=` không có giá trị ngoài 1 và 2 | MINOR: tier variable có thể nhận giá trị ngoài spec |
| V1.4 | Hooks trong `hooks_without_tier[]`: xác nhận không gọi `hook_detect_tier_mode` trực tiếp | Grep | pattern không có trong hooks_without_tier files | MINOR: function gọi trực tiếp — tier logic có thể bị duplicate |

**Output:** Findings với prefix `F-MPV-V1-`.

---

### V2: Checkpoint Schema ↔ Protocol ↔ Skill Consistency

> **Trigger:** `$MP_COMPONENTS.checkpoint_digest.schema_has_context_digest == true`

| Step | Cross-check | Tool | Điều kiện PASS | Finding nếu FAIL |
|------|-------------|------|----------------|-----------------|
| V2.1 | `checkpoint-schema.json` có đủ 6 subfields bắt buộc: `feature_summary`, `architectural_decisions`, `interfaces_established`, `patterns_in_use`, `cross_batch_contracts`, `gotchas_and_warnings` | Grep per field | 6/6 fields tìm thấy | MAJOR per field missing: schema không đủ để store session context |
| V2.2 | `protocols/` Protocol 3: các fields PHẢI khớp tên với schema | Read + cross-check | Mỗi field có tên tương ứng | MAJOR: tên field không đồng bộ |
| V2.3 | `wf-implement-feature/SKILL.md` Phase 3: có reference ít nhất `feature_summary` và `architectural_decisions` | Grep | pattern trong Phase 3 section | MAJOR: skill generate digest nhưng không dùng đúng field names |
| V2.4 | `wf-implement-feature/SKILL.md` Phase 1 (resume): có bước đọc `context_digest` từ checkpoint | Grep | pattern `context_digest` trong Phase 1 | MAJOR: resume flow không load digest → context bị mất |

> **Lưu ý V2.1:** 6 fields dựa trên spec v1.1. Nếu schema mở rộng sau này, cập nhật danh sách.

**Output:** Findings với prefix `F-MPV-V2-`.

---

### V3: Digest Artifacts Pipeline Integrity

> **Trigger:** `$MP_COMPONENTS.digest_pipeline.templates_dir_exists != "NOT_FOUND"`

| Step | Cross-check | Tool | Điều kiện PASS | Finding nếu FAIL |
|------|-------------|------|----------------|-----------------|
| V3.1 | 6 digest templates (`project-digest`, `dept-digests`, `phase1-handoff`, `feature-briefs`, `design-input-digest`, `ux-input-digest`) PHẢI có ≥1 skill trong `producer_skills_with_digest_step[]` tạo nó | Cross-check index | producer_count ≥ 1 per template | MAJOR per orphan: template không có skill tạo |
| V3.2 | Mỗi digest template PHẢI có ≥1 skill trong `consumer_skills_with_digest_step[]` đọc nó | Cross-check index | consumer_count ≥ 1 per template | MAJOR per orphan: không có skill dùng |
| V3.3 | Digest file paths trong `00-core.md §4b` PHẢI khớp actual template filenames trong `_digests/` | Read §4b + Glob | Mỗi path §4b tìm thấy file tương ứng | MAJOR per mismatch |
| V3.4 | CONSUMER skills: PHẢI có fallback logic khi digest file không tồn tại | Grep pattern `if.*digest\|fallback\|nếu.*digest\|digest.*không\|bỏ qua.*digest` trong PRE-GATE | Fallback tìm thấy (EN hoặc VN) | MINOR per skill: consumer fail nếu digest chưa được tạo |

**Output:** Findings với prefix `F-MPV-V3-`.

---

### V4: A6-EXT ↔ A7-EXT Consistency

> **Trigger:** `$MP_COMPONENTS.executable_spec_a6ext.task_template_has_a6ext == true`

| Step | Cross-check | Tool | Điều kiện PASS | Finding nếu FAIL |
|------|-------------|------|----------------|-----------------|
| V4.1 | A6-EXT fields (`file_paths`, `req_ids`, `methods`, `test_cases`) PHẢI được reference trong `wf-plan-modules/SKILL.md` Phase 7.5.5 | Read template + Read plan-modules | Fields khớp | MAJOR: fields không có trong template |
| V4.2 | A7-EXT fields (`micro_task_id`, `estimated_time`, `input`, `output`, `success_criteria`) PHẢI có trong `wf-plan-modules/SKILL.md` Phase 7.5.6 | Grep per field | 5/5 fields referenced | MAJOR per field missing |
| V4.3 | A7-EXT micro-task specs KHÔNG mâu thuẫn với A6-EXT file paths (relative vs absolute consistent) | Read task template | Path format consistent | MINOR: path format mismatch |
| V4.4 | `wf-implement-feature/SKILL.md` `--micro-task` flag: documented trong cả (a) Arguments table VÀ (b) Phase logic | Grep `--micro-task` trong 2 sections | Tìm thấy ở cả 2 nơi | MAJOR: flag documented nhưng không có phase logic |

**Output:** Findings với prefix `F-MPV-V4-`.

---

### V5: Parallel Execution Safety

> **Trigger:** `$MP_COMPONENTS.parallel_execution.implement_feature_has_phase2_5 != "NOT_FOUND"`

| Step | Cross-check | Tool | Điều kiện PASS | Finding nếu FAIL |
|------|-------------|------|----------------|-----------------|
| V5.1 | Phase 2.5 (Contract Generation) PHẢI TRƯỚC Phase 3 trong `wf-implement-feature/SKILL.md` | Read file, check ordering | Phase 2.5 xuất hiện trước Phase 3 | CRITICAL: contracts chưa sẵn sàng khi parallel agents bắt đầu |
| V5.2 | Safety rules PHẢI có: "agent chỉ write scope riêng" và "contracts immutable sau Phase 2.5" | Grep `write.*scope\|immutable\|không được sửa.*contract` | Cả 2 rules tìm thấy | MAJOR: thiếu safety rule |
| V5.3 | `--features` flag: dependency analysis PHẢI xác định parallel vs sequential dựa trên feature deps | Grep `dependency\|depends_on\|sequential\|parallel` | Dependency logic tìm thấy | MAJOR: không analyze deps → vi phạm dependency order |
| V5.4 | `orchestrator.md` Multi-Feature Orchestration section: logic scheduling nhất quán với --features | Read orchestrator + cross-check | Cùng approach | MINOR: inconsistent descriptions |

**Output:** Findings với prefix `F-MPV-V5-`.

---

### V6: Backward Compatibility (SAU V1-V5)

> **Trigger:** Chạy khi ít nhất 1 Master Plan component đã triển khai (bất kỳ non-NOT_FOUND nào).
> V6 verify rằng MCV3 vẫn hoạt động đúng khi các components MỚI chưa có.

| Step | Cross-check | Component | Tool | Điều kiện PASS | Finding nếu FAIL |
|------|-------------|-----------|------|----------------|-----------------|
| V6.1 | **Checkpoint resume without digest:** `wf-implement-feature/SKILL.md` Phase 1 (resume) PHẢI check `context_digest` tồn tại trước khi dùng | Grep | Pattern `if.*context_digest\|context_digest.*?` hoặc null-check | MAJOR: resume fail với checkpoint cũ |
| V6.2 | **Consumer skills without digest files:** Mỗi consumer skill PRE-GATE có fallback "nếu digest không tồn tại → đọc full docs" | Grep per consumer skill | `if.*exists.*digest\|digest.*not.*found\|fallback` trong PRE-GATE | MAJOR: skill hard-fail khi chạy lần đầu |
| V6.3 | **Task files without A6-EXT:** `wf-implement-feature/SKILL.md`: A6-EXT PHẢI optional (fallback khi task file không có A6-EXT section) | Grep | Pattern `if.*A6-EXT\|A6-EXT.*optional\|không có A6-EXT` | MAJOR: skill fail khi task files cũ |
| V6.4 | **Sequential default without flags:** Khi không có `--parallel`/`--features`/`--micro-task` → default sequential. Phase 2.5 KHÔNG chạy khi `--parallel` absent | Grep trigger condition | Phase 2.5 có explicit `if --parallel` | MAJOR: Phase 2.5 chạy không cần thiết |

**Output:** Findings với prefix `F-MPV-V6-`.

---

### V7: Digest Pipeline Chain Integrity

> **Trigger:** Luôn chạy khi Phase 3.5 active (không phụ thuộc master_plan_components).
> Validate 7 digest chain links từ `00-core.md §4b`.

| Step | Cross-check | Tool | Điều kiện PASS | Finding nếu FAIL |
|------|-------------|------|----------------|-----------------|
| V7.1 | brainstorm → analyze-requirements: `project-digest.json` path khớp giữa producer POST-GATE và consumer PRE-GATE | Grep `project-digest` trong cả 2 skills | Path string match | MAJOR: digest path mismatch |
| V7.2 | analyze-requirements → define-features: `dept-digests.json` + `phase1-handoff.json` paths match | Grep `dept-digests\|phase1-handoff` | 2/2 paths match | MAJOR per mismatch |
| V7.3 | define-features → design: `feature-briefs.json` path match | Grep `feature-briefs` | Path match | MAJOR: digest path mismatch |
| V7.4 | design → design-ux: `design-input-digest.json` path match | Grep `design-input-digest` | Path match | MAJOR: digest path mismatch |
| V7.5 | design-ux → plan-modules: `ux-input-digest.json` path match (conditional: interface_type != api-only) | Grep `ux-input-digest` | Path match (nếu không api-only) | MAJOR: conditional digest missing |
| V7.6 | plan-modules → implement-feature: task files path pattern `[sys]/[mod]/[feat]-impl.md` match | Grep task file pattern | Pattern match | MINOR: task path convention mismatch |

**Output:** Findings với prefix `F-MPV-V7-`.

---

### V8: Bridge File Existence

> **Trigger:** Luôn chạy khi Phase 3.5 active.
> Validate 10 critical bridge file templates tồn tại.

| Step | Cross-check | Tool | Điều kiện PASS | Finding nếu FAIL |
|------|-------------|------|----------------|-----------------|
| V8.1 | `req-registry.json` template: `.claude/doc-framework/_meta/req-registry.json` tồn tại | Glob | File tồn tại | CRITICAL: SSOT template missing |
| V8.2 | `project-digest.json` template: `.claude/doc-framework/_digests/project-digest.json` tồn tại | Glob | File tồn tại | MAJOR: digest template missing |
| V8.3 | `dept-digests.json` template tồn tại | Glob | File tồn tại | MAJOR: digest template missing |
| V8.4 | `phase1-handoff.json` template tồn tại | Glob | File tồn tại | MAJOR: handoff template missing |
| V8.5 | `feature-briefs.json` template tồn tại | Glob | File tồn tại | MAJOR: digest template missing |
| V8.6 | `design-input-digest.json` template tồn tại | Glob | File tồn tại | MAJOR: digest template missing |
| V8.7 | `ux-input-digest.json` template tồn tại | Glob | File tồn tại | MAJOR: digest template missing |
| V8.8 | `legacy-decisions.json` template: null by design (LEGACY_MODE only) — skip | - | Skip | N/A |
| V8.9 | `project-context.md` template tồn tại | Glob | File tồn tại | MAJOR: legacy anchor template missing |
| V8.10 | `module-code-mapping.json` template tồn tại | Glob | File tồn tại | MINOR: schema-only template |

**Output:** Findings với prefix `F-MPV-V8-`.

---

### V9: Registry Ownership Uniqueness

> **Trigger:** Luôn chạy khi Phase 3.5 active.
> Verify không có overlapping PRIMARY fields_owned giữa skills.

| Step | Cross-check | Tool | Điều kiện PASS | Finding nếu FAIL |
|------|-------------|------|----------------|-----------------|
| V9.1 | Đọc `registry_scope.fields_owned` từ tất cả `_contract.json` files | Glob + Grep | Loaded | MAJOR: cannot read contracts |
| V9.2 | Build ownership map: {field → [list of skills declaring PRIMARY write_role]} | Parse | Map built | N/A |
| V9.3 | Verify: mỗi field có tối đa 1 PRIMARY owner | Cross-check | count ≤ 1 per field | CRITICAL: overlapping PRIMARY — race condition risk |
| V9.4 | Verify: SEED role chỉ xuất hiện 1 lần per field (initial write) | Cross-check | count ≤ 1 per field | MAJOR: multiple SEEDs — conflict risk |

**Output:** Findings với prefix `F-MPV-V9-`.

---

## Master Plan Verify — POST-GATE

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.5.1 | Gộp tất cả findings từ V1-V6 (nếu `$SKIP_PHASE_3_5 = false`) | - | merged |
| 3.5.2 | Write `$VERIFY_DIR/findings-masterplan-verify.json` (schema `audit-findings-v1`) | Write | File created |
| 3.5.3 | Validate JSON: `jq '.'` | Bash | exit code 0 |
| 3.5.4 | Update `verify-status.json`: mark `phase3_5-master-plan` completed | Write | Updated |

## POST-GATE

- `$VERIFY_DIR/findings-masterplan-verify.json` tồn tại (kể cả khi skipped — với `skip_reason`)
- JSON valid, schema `audit-findings-v1`

## Routing sau Phase 3.5

- Nếu `$SCOPE == "master-plan"` → chuyển `phase4-merge.md` (partial scope)
- Nếu `$SCOPE == "all"` → chuyển `phase4-merge.md` (full merge)

## Errors liên quan

- **E014** — `$INDEX.master_plan_components` không tồn tại (scan version cũ) → log WARNING, skip Phase 3.5
- **E015** — V1-V6 không đọc được file (VD: `protocols/` missing) → skip check + finding MINOR
- **E016** — V3 digest path §4b không khớp template filename → MAJOR per mismatch, không auto-fix

Chi tiết: `_shared.md §Error Handling Reference`.
