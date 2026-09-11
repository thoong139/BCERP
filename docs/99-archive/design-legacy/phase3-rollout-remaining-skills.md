# Phase 3 — ADR-OPT Rollout: 4 Linear Skills Còn Lại

> **Tạo:** 2026-04-23
> **Mục đích:** Prompt-ready plan cho phiên triển khai — áp dụng 5 ADR-OPT techniques vào `wf-define-features`, `wf-design`, `wf-design-ux`, `wf-plan-modules`
> **Prerequisite:** Phase 2 Validation + Tests PASS F1-F10 (xem `phase2-validation-tests.md`)
> **Output của phiên này:** Chỉ là tài liệu triển khai — không viết code/procedure trong phiên này. Mỗi skill sẽ có phiên riêng để thực thi.

---

## Context (đọc trước khi bắt đầu)

Phase 2 đã validate thành công pattern ADR-OPT trên `wf-analyze-requirements` v3.0.0. Pattern này cần **nhân rộng** sang 4 skills linear còn lại trong `.claude/skills/workflow/`:

| Skill | Phase hiện tại | Version cần bump | Lane type |
|-------|---------------|------------------|-----------|
| `wf-define-features` | phase2-features | → v3.0.0 | feature-lane per module |
| `wf-design` | phase3-architecture | → v3.0.0 | system-lane per system |
| `wf-design-ux` | phase4-ux | → v3.0.0 | screen-lane per module (conditional) |
| `wf-plan-modules` | phase5-implementation | → v3.0.0 | module-lane theo DAG |

**5 ADR-OPT techniques áp dụng cho mỗi skill:**
1. **ADR-OPT-01 Lane Dispatch** — parallel execution với write-scope isolation
2. **ADR-OPT-02 Session Isolation** — `sessions/{id}/` + `latest` pointer + cleanup policy
3. **ADR-OPT-03 Workload Gate** — `phase0.5-workload-gate.md` per skill với threshold riêng
4. **ADR-OPT-04 Signal Aggregation** — dedup theo ID type (FEAT-ID / COMPONENT-ID / SCREEN-ID / TASK-ID)
5. **ADR-OPT-05 Template Strip + Atomic Write** — digest outputs không leak `_template_notes`

**Key references:**
- ADR đầy đủ: `docs/design/skills/ADR-downstream-skills-optimization.md`
- Phase 2 template (reference): `docs/design/skills/phase2-analyze-req-remaining-steps.md`
- Phase 2 validation: `docs/design/skills/phase2-validation-tests.md`
- _shared modules: `.claude/skills/workflow/_shared/README.md`
- _shared protocol: `.claude/skills/workflow/_shared/_shared.md`

---

## Tasks (thực hiện theo thứ tự)

### Task 1: Tạo `phase3-rollout-design-principles.md`

**Vị trí:** `docs/design/skills/phase3-rollout-design-principles.md`

**Mục tiêu:** Chốt nguyên tắc thiết kế chung cho 4 skills — tránh drift giữa các skill khi triển khai.

**Nội dung cần có:**

1. **Pattern tổng quát (từ wf-analyze-requirements v3.0.0):**
   ```
   SKILL.md v3.0.0 bump:
     - changelog entry mô tả 5 ADR-OPT
     - "Phases" row: thêm 0.5 vào phase ordering
     - "Session" row: sessions/{id}/ + latest pointer
     - "_shared" row: list imports
     - Template Usage Rule table: thêm 4 rows cho _shared/templates/*

   _contract.json v3.0.0 bump:
     - version 3.0.0
     - procedure_files[]: +phase0.5-workload-gate.md
     - outputs.working[]: +4 session artifacts (session-state, workload-report, lane-signal, aggregation-result)
     - outputs.working[]: +latest pointer
     - registry_scope.fields_owned: UNCHANGED

   procedures/:
     - +phase0.5-workload-gate.md (NEW)
     - +_shared.md updates: 4 session vars, Session Isolation section, _shared Module Imports section
     - +phase0-*.md: Step 0.2b session init
     - +phase-experts-*.md (or equivalent): Lane Dispatch
     - +phase-consolidate-*.md (or equivalent): Signal Aggregation
     - +phase-handoff-*.md: Template Strip + Atomic Write
   ```

2. **Mỗi skill có 1 bảng "Variable Map" riêng:**
   - Lane type (feature-lane / system-lane / screen-lane / module-lane)
   - Lane key format (e.g., `{system}-{module}` hay chỉ `{module}`)
   - Partition grouping (max_per_partition)
   - Workload factor (LEGACY_MODE + compliance)
   - Dedup ID type
   - Aggregation conflict handling

3. **Shared constraints (không đổi giữa các skills):**
   - Threshold 45 phút (ADR-OPT-03)
   - max_parallel: 3 (LPM) / 5 (Standard)
   - Cleanup policy: giữ 5 sessions
   - Atomic write pattern: tmp → validate → mv
   - CDG-A02 workload override

4. **Decision log template** (để 4 phiên sau dùng cùng format):
   ```markdown
   ## Skill: wf-XXX
   | Field | Value |
   |-------|-------|
   | Lane type | ... |
   | Lane key format | ... |
   | Partition grouping | max=N per partition |
   | Workload est_minutes_per_item | ... |
   | Dedup key | ... |
   | Conditional phases | ... |
   ```

---

### Task 2: Tạo `phase3-wf-define-features.md` — Spec cho skill 1/4

**Vị trí:** `docs/design/skills/phase3-wf-define-features.md`

**Nội dung cần có (đầy đủ giống phase2-analyze-req-remaining-steps.md):**

1. **Context section:**
   - Current state: SKILL.md version, _contract.json version, procedures/ list
   - Target state: v3.0.0 với 5 ADR-OPT
   - Lane type: **feature-lane per module** — mỗi module trong `modules[]` spawn 1 lane viết feature specs

2. **Workload Gate spec (Phase 0.5):**
   - Partition items: `modules[]` (group_key="module")
   - `max_per_partition = 5` (≤5 modules/partition)
   - `est_minutes_per_item = 5.0` (features nặng hơn BA analysis)
   - Factor: 1.0 normal, 1.5 LEGACY, 2.0 nếu có nhiều sub-features (>3 features/module trung bình)
   - Threshold 45 phút

3. **Lane Dispatch spec (Phase thay thế):**
   - Thay Phase "spawn feature-writer agents parallel per module" thành Lane Dispatch
   - `LaneConfig.key = {system-slug}-{module-slug}`
   - `LaneConfig.agent_type = business-analyst` (default) hoặc domain expert tương ứng
   - Output path: `$SESSION_DIR/lanes/{system}-{module}/signals.json`
   - Write scope: `phase2-features/{system}/{module}/*.md`

4. **Signal Aggregation spec:**
   - Dedup key: `feat_id` (FEAT-ID)
   - Conflict: 2 lanes cùng produce FEAT-ID → flag conflict, fallback priority = lane owning module
   - Output: `$SESSION_DIR/aggregation-result.json`

5. **Procedure files cần update:**
   - `procedures/phase0-context.md` — Step 0.2b session init
   - `procedures/phase0.5-workload-gate.md` — NEW
   - `procedures/phase2-write-features.md` (hoặc tên hiện tại) — Lane Dispatch
   - `procedures/phase-consolidate-*.md` (nếu có) — Signal Aggregation
   - `procedures/phase-handoff-*.md` — Template Strip
   - `procedures/_shared.md` — 4 session vars + 2 sections mới

6. **Task checklist** (đúng format phase2-analyze-req-remaining-steps.md):
   - Task 1: Tạo phase0.5-workload-gate.md
   - Task 2: Update procedures/_shared.md
   - Task 3: Update phase0-context.md
   - Task 4: Update phase-write-features.md (hoặc equivalent — cần check tên hiện tại)
   - Task 5: Update phase-consolidate.md (nếu có)
   - Task 6: Update phase-handoff.md

7. **Verify Checklist V1-V10** (cùng format phase2-analyze-req-remaining-steps.md)

8. **Constraints BẮT BUỘC** (copy từ phase2)

**Step trước khi viết:**
- READ `.claude/skills/workflow/wf-define-features/SKILL.md` để biết current phase structure
- READ `.claude/skills/workflow/wf-define-features/_contract.json` để biết current version + outputs
- LIST `.claude/skills/workflow/wf-define-features/procedures/` để map phases
- Map Phase 2 pattern sang procedure files hiện có

---

### Task 3: Tạo `phase3-wf-design.md` — Spec cho skill 2/4

**Vị trí:** `docs/design/skills/phase3-wf-design.md`

**Nội dung cần có (cùng format Task 2):**

1. **Lane type: system-lane per system** — mỗi system trong `systems[]` spawn 1 lane viết architecture + API + DB design

2. **Workload Gate spec:**
   - Partition items: `systems[]` (group_key="system")
   - `max_per_partition = 3` (systems nặng hơn)
   - `est_minutes_per_item = 15.0` (design toàn diện)
   - Factor: 1.0 normal, 1.5 LEGACY, 2.0 nếu multi-tier architecture (microservices, event-driven)
   - Threshold 45 phút (có thể nâng lên 60 nếu cần — review trong Task 1)

3. **Lane Dispatch:**
   - `LaneConfig.key = {system-slug}`
   - `LaneConfig.agent_type = architect` (default) + spawn child lanes cho `dba`, `security`, `api-tester`
   - Output path: `$SESSION_DIR/lanes/{system}/signals.json`
   - Write scope: `phase3-architecture/{system}/*.md`

4. **Signal Aggregation:**
   - Dedup key: `component_id` (COMPONENT-ID) hoặc `api_id`
   - Conflict: cross-system dependency conflicts → flag, defer to stakeholder review

5. **Legacy mode consideration:**
   - Gap analysis outputs (`gap-report.md`, `action-items.json`) cần integrate vào lane context
   - Module-code-mapping cung cấp existing code refs

6. **Procedure files cần update** (check actual names khi viết spec):
   - phase0-context.md
   - phase0.5-workload-gate.md (NEW)
   - phase-design-*.md (system-lane dispatch)
   - phase-consolidate-*.md (nếu có)
   - phase-handoff.md
   - _shared.md

7. **Task checklist + Verify Checklist + Constraints** (như Task 2)

---

### Task 4: Tạo `phase3-wf-design-ux.md` — Spec cho skill 3/4

**Vị trí:** `docs/design/skills/phase3-wf-design-ux.md`

**Nội dung cần có:**

1. **Conditional execution:** Skill skip hoàn toàn nếu `interface_type == "api-only"` — workload gate Phase 0.5 PHẢI check trước khi chạy
   - Nếu skip → ghi `phases.P0_5.skipped = true, reason = "api-only interface"` vào session-state
   - Workload gate không spawn prompt

2. **Lane type: screen-lane per module (non-api)**
   - Chỉ modules có UI components
   - `max_per_partition = 5`
   - `est_minutes_per_item = 4.0`

3. **Lane Dispatch:**
   - `LaneConfig.key = {module-slug}-screens`
   - `LaneConfig.agent_type = ui-designer` (hoặc `ux-designer` tùy phase)
   - Output path: `$SESSION_DIR/lanes/{module}-screens/signals.json`
   - Write scope: `phase4-ux/{system}/{module}/*.md`

4. **Signal Aggregation:**
   - Dedup key: `screen_id` (SCREEN-ID)
   - Conflict: reuse component cross-module → aggregate into shared design system

5. **Procedure files:** LIST current structure trước khi viết spec (vì wf-design-ux có thể có phase split khác 2 skills trên)

6. **Task checklist + Verify Checklist + Constraints**

---

### Task 5: Tạo `phase3-wf-plan-modules.md` — Spec cho skill 4/4

**Vị trí:** `docs/design/skills/phase3-wf-plan-modules.md`

**Nội dung cần có:**

1. **Lane type: module-lane theo dependency DAG**
   - Chạy theo topological order từ dependency graph
   - `max_per_partition = 5` per topological level
   - `est_minutes_per_item = 8.0` (task breakdown + sprint planning)

2. **Workload Gate spec:**
   - Partition items: `modules[]` đã qua topological sort
   - Factor: 1.0 normal, 1.5 LEGACY, 2.0 nếu có cross-module dependencies phức tạp

3. **Lane Dispatch:**
   - `LaneConfig.key = {module-slug}`
   - `LaneConfig.agent_type = architect` (planning role)
   - Output path: `$SESSION_DIR/lanes/{module}/signals.json`
   - Write scope: `phase5-implementation/tasks/{system}/{module}/*.md`

4. **Signal Aggregation:**
   - Dedup key: `task_id` (TASK-ID)
   - Conflict: shared task across modules → flag for dependency review

5. **Legacy mode:**
   - `implementation_strategy` per task (VERIFY_ONLY / COMPLETE_EXISTING / IMPLEMENT_NEW) — CORE-019
   - Phase 1.5 code verification vẫn giữ nguyên, chỉ lane-ify

6. **Task checklist + Verify Checklist + Constraints**

---

### Task 6: Tạo `phase3-rollout-order.md` — Thứ tự triển khai + dependency matrix

**Vị trí:** `docs/design/skills/phase3-rollout-order.md`

**Nội dung cần có:**

1. **Thứ tự đề xuất (critical path):**
   ```
   wf-define-features  (task 2 spec) — ít phụ thuộc nhất, pattern gần analyze-req
         ↓
   wf-design           (task 3 spec) — phụ thuộc features
         ↓
   wf-design-ux        (task 4 spec) — conditional, phụ thuộc design
         ↓
   wf-plan-modules     (task 5 spec) — phụ thuộc tất cả trên
   ```

2. **Mỗi skill rollout cần session riêng** — không gộp, tránh scope creep

3. **Sau mỗi skill DONE:**
   - Chạy compliance audit + schema sync
   - Update sign-off doc
   - Integration test với consumer skill tiếp theo

4. **Dependency matrix:**
   | Skill | Produces (cho downstream) | Consumes (từ upstream) | Breaking change risk |
   |-------|---------------------------|------------------------|---------------------|
   | wf-define-features | `feature-briefs.json` digest | `dept-digests.json`, `phase1-handoff.json` | LOW |
   | wf-design | `design-input-digest.json` | `feature-briefs.json` | MEDIUM (nếu đổi schema) |
   | wf-design-ux | `ux-input-digest.json` | `design-input-digest.json` | LOW |
   | wf-plan-modules | module-plan + sprints | `design-input-digest.json`, `ux-input-digest.json` | HIGH (nhiều outputs) |

5. **Rollback plan:** Nếu skill N fail → rollback về v2.x, skills N+1...4 không chạy cho đến khi resolve

---

### Task 7: Tạo `phase4-documentation-signoff.md` — Placeholder

**Vị trí:** `docs/design/skills/phase4-documentation-signoff.md`

**Nội dung cần có (ngắn, chỉ khung):**

1. **Mục tiêu Phase 4:**
   - Cập nhật `ADR-downstream-skills-optimization-signoff.md` với evidence từ cả 5 skills
   - Cập nhật `CLAUDE.md` nếu có thay đổi skill descriptions
   - Cập nhật `docs/project-description.md` nếu cần
   - Cập nhật `.claude/skills/workflows/*` orchestrators (new-project, existing-project, feature-addition) — đảm bảo reference đúng skill versions

2. **Sign-off template:** (như phase 2, nhân 5 skills)
   ```
   | Skill | Version | F1 Compliance | F2 Schema Sync | F3 Evals | F4-F7 Audit | Sign-off Date |
   |-------|---------|---------------|----------------|----------|-------------|---------------|
   ```

3. **Cross-skill integration tests:**
   - Full `/new-project` workflow E2E
   - Full `/existing-project` workflow E2E
   - Full `/feature-addition` workflow E2E

4. **Deferred:** Chi tiết sẽ fill sau khi Phase 3 gần xong (phiên phase4 riêng)

---

### Task 8: Tạo `phase5-integration-test-plan.md` — Placeholder

**Vị trí:** `docs/design/skills/phase5-integration-test-plan.md`

**Nội dung cần có (ngắn, chỉ khung):**

1. **Mục tiêu Phase 5:**
   - E2E test trên 1 project thật (nhỏ, 3-5 modules)
   - Kiểm tra session dir structure + latest pointer chuyển đúng giữa các skills
   - Verify `--resume` ở mọi skill (kill giữa chừng → resume đúng)
   - Verify multi-run không đè session cũ

2. **Test scenarios:**
   - Scenario A: New project full path (`/wf-brainstorm` → `/wf-prepare-deployment`)
   - Scenario B: Existing project full path (legacy scan → full workflow)
   - Scenario C: Feature addition (`/wf-add-scope` → `/wf-define-features` → ...)
   - Scenario D: Resume tại mỗi phase (kill + resume, verify consistency)
   - Scenario E: Workload gate BLOCK + CDG override + anti-loop guard

3. **Success criteria:**
   - Tất cả canonical `_meta/*.json` không chứa `_template_notes`
   - `latest` pointer trỏ đúng session mới nhất ở mỗi skill
   - `req-registry.json` không bị downgrade `impl_status`
   - Session dirs cleanup giữ đúng 5 sessions mới nhất

4. **Deferred:** Chi tiết test script sẽ viết trong phiên phase 5 riêng

---

## Deliverables của phiên này (tài liệu Phase 3 → 5)

Sau phiên này, folder `docs/design/skills/` cần có thêm:

```
docs/design/skills/
├── phase3-rollout-design-principles.md       (Task 1)
├── phase3-wf-define-features.md              (Task 2)
├── phase3-wf-design.md                       (Task 3)
├── phase3-wf-design-ux.md                    (Task 4)
├── phase3-wf-plan-modules.md                 (Task 5)
├── phase3-rollout-order.md                   (Task 6)
├── phase4-documentation-signoff.md           (Task 7 — khung)
└── phase5-integration-test-plan.md           (Task 8 — khung)
```

Mỗi file Task 2-5 là **prompt-ready** (AI có thể đọc và triển khai ngay trong phiên riêng).
Task 1, 6, 7, 8 là **tài liệu kế hoạch** — không trực tiếp thực thi, chỉ dẫn hướng.

---

## Constraints (BẮT BUỘC)

1. **Chỉ viết tài liệu** — KHÔNG modify SKILL.md, _contract.json, procedures/ của 4 skills trong phiên này
2. **Đọc hiện trạng trước khi viết spec** — mỗi skill có cấu trúc procedures/ khác nhau, cần map đúng
3. **Format nhất quán với `phase2-analyze-req-remaining-steps.md`** — 4 task specs (Task 2-5) phải cùng structure
4. **Tiếng Việt cho docs/comments, English cho code/names** (CORE-005)
5. **Surgical — không refactor Phase 2 docs** — Phase 2 là reference, không sửa
6. **Reference consistent** — mọi ADR/Protocol/CORE reference phải chính xác (kiểm tra tồn tại)

---

## Verify Checklist (sau khi hoàn tất)

| # | Check | Command |
|---|-------|---------|
| V1 | 8 files đều được tạo | `ls docs/design/skills/phase3-*.md docs/design/skills/phase4-documentation-signoff.md docs/design/skills/phase5-integration-test-plan.md \| wc -l` → 8 |
| V2 | Task 1 có Variable Map template | `grep -c "Variable Map" docs/design/skills/phase3-rollout-design-principles.md` |
| V3 | Task 2-5 đều có Task checklist | `for f in phase3-wf-*.md; do grep -c "### Task 1:" docs/design/skills/$f; done` |
| V4 | Task 2-5 đều có Verify Checklist V1-V10 | `for f in phase3-wf-*.md; do grep -c "Verify Checklist" docs/design/skills/$f; done` |
| V5 | Task 6 có thứ tự rollout + dependency matrix | `grep -c "Dependency matrix\|Thứ tự" docs/design/skills/phase3-rollout-order.md` |
| V6 | Task 7-8 là placeholder (ngắn, khung) | `wc -l docs/design/skills/phase4-documentation-signoff.md docs/design/skills/phase5-integration-test-plan.md` → mỗi file < 100 dòng |
| V7 | Không modify files của 4 skills | `git status .claude/skills/workflow/wf-define-features .claude/skills/workflow/wf-design .claude/skills/workflow/wf-design-ux .claude/skills/workflow/wf-plan-modules` → clean |
| V8 | Reference ADR-OPT đúng | `grep -c "ADR-OPT-0[1-9]" docs/design/skills/phase3-*.md` |
| V9 | Reference _shared modules đúng | `grep -c "_shared/partition\|_shared/lane\|_shared/aggregate\|_shared/cdg" docs/design/skills/phase3-*.md` |
| V10 | Phase 2 docs không bị modify | `git status docs/design/skills/phase2-*.md docs/design/skills/ADR-*.md` → clean |
