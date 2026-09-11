# Phase 3 — ADR-OPT Rollout: `wf-define-features` (Skill 1/4)

> **Tạo:** 2026-04-23
> **Mục đích:** Prompt-ready checklist cho phiên rollout — bump `wf-define-features` lên v3.0.0 với 5 ADR-OPT techniques.
> **Prerequisite:** Phase 2 sign-off PASS + đọc `phase3-rollout-design-principles.md` (Variable Map §3.1 + Shared Constraints §4).
> **Output của phiên này:** SKILL.md v3.0.0 + _contract.json v3.0.0 + 6 procedure files updated/created.

---

## Context (đọc trước khi bắt đầu)

Phase 3 rollout cho `wf-define-features` áp dụng **5 ADR-OPT techniques** (tham chiếu `phase3-rollout-design-principles.md §2`). Skill này đứng **đầu chuỗi** của 4 linear skills còn lại — pattern tương tự nhất với `wf-analyze-requirements` v3.0.0.

**Current state (từ `_contract.json` + `procedures/` listing — 2026-04-23):**
- SKILL.md: v2.1.0 (refactor phase-per-file từ v2.0.0)
- _contract.json: v2.1.0
- Procedures (10 files):
  - `_shared.md`
  - `phase0-context.md`
  - `phase0.5-impl-status.md` (LEGACY only — đặt tên trùng với phase workload gate sẽ thêm!)
  - `phase1-scope-mapping.md`
  - `phase2-create-specs.md` (primary agent dispatch)
  - `phase2.5-feat-mapping.md` (LEGACY)
  - `phase2.7-ui-coverage.md` (LEGACY + screens)
  - `phase3-cross-validation.md`
  - `phase4-stakeholder-review.md`
  - `phase5-registry-update.md`

**⚠️ Naming conflict:** `phase0.5-impl-status.md` đã tồn tại (LEGACY only, seed impl_status từ legacy scan). Phiên rollout PHẢI:
- **Option A (ưu tiên):** Rename hiện `phase0.5-impl-status.md` → `phase0.5-legacy-impl-seed.md`, thêm mới `phase0.5-workload-gate.md`.
- **Option B:** Ghép 2 logic vào 1 file `phase0.5-workload-gate.md` với branch condition `if LEGACY_MODE → also seed impl_status`.
- **Quyết định:** Chọn **Option A** — giữ Single Responsibility Principle. 2 phase files khác nhau: workload gate (mọi skill) vs legacy impl-status seed (chỉ LEGACY).

**Target state:** v3.0.0 với 5 ADR-OPT. `registry_scope.fields_owned` UNCHANGED = `["features", "features.impl_status", "impl_status"]`.

**Key references:**
- Design principles: `docs/design/skills/phase3-rollout-design-principles.md`
- ADR đầy đủ: `docs/design/skills/ADR-downstream-skills-optimization.md`
- Phase 2 template (reference): `docs/design/skills/phase2-analyze-req-remaining-steps.md`
- _shared protocol: `.claude/skills/workflow/_shared/_shared.md`
- _shared module map: `.claude/skills/workflow/_shared/README.md` §4-§5

---

## Decision Log — Skill: `wf-define-features`

| Field | Value | Rationale |
|-------|-------|-----------|
| Current version | 2.1.0 | Từ `_contract.json` |
| Target version | **3.0.0** | SemVer MAJOR — phase structure change (thêm Phase 0.5 workload gate) + breaking session path |
| Lane type | **feature-lane per module** | Mỗi module là đơn vị viết specs tự nhiên; không cần lane theo system vì feature specs gắn chặt với module |
| Lane key format | `{system-slug}-{module-slug}` | Bảo đảm unique cross-system; phù hợp output path `phase2-features/{sys}/{mod}/*.md` |
| Partition grouping | `group_key="module"`, `max_per_partition = 5` | Mỗi partition ≤5 modules để respect `max_parallel=5` Standard profile |
| Workload `est_minutes_per_item` | **5.0** | Feature spec nặng hơn BA analysis (3.0) — mỗi module phải tạo ≥1 feature spec + FEAT-ID mapping |
| Workload factor | 1.0 normal, 1.5 LEGACY, 2.0 nếu trung bình `>3 features/module` | LEGACY chậm do cần cross-check extracted data; nhiều features → nhiều file write |
| Dedup key | `feat_id` (FEAT-ID) | Conflict khi 2 lanes produce cùng FEAT-ID (hiếm nhưng có thể xảy ra khi cross-module feature) |
| Aggregation conflict | Flag, fallback priority = lane owning module | Module owner có quyền quyết định spec nội bộ |
| Conditional phases (skip triggers) | Phase 2.5 + 2.7 chỉ LEGACY | Không thay đổi — giữ nguyên skip logic hiện có |
| Expert dispatch phase file | `phase2-create-specs.md` + `phase2.5-feat-mapping.md` | Primary lane phase — thay parallel spawn hiện tại bằng Lane Dispatch |
| Consolidate phase file | `phase3-cross-validation.md` | Signal Aggregation cho FEAT-ID deduplication |
| Handoff phase file | `phase5-registry-update.md` + digest output (Phiên 6 ở cuối Phase 5) | Template Strip + Atomic Write cho `feature-briefs.json` |
| Breaking change risk | **LOW** | `registry_scope.fields_owned` unchanged; downstream consumers (wf-design, wf-design-ux, wf-plan-modules, wf-implement-feature) chỉ đọc feature-briefs.json + phase2-features files — path không đổi |

---

## Tasks (thực hiện theo thứ tự)

### Task 1: Rename `phase0.5-impl-status.md` → `phase0.5-legacy-impl-seed.md` + tạo mới `phase0.5-workload-gate.md`

**Vị trí:**
- Rename: `.claude/skills/workflow/wf-define-features/procedures/phase0.5-impl-status.md` → `phase0.5-legacy-impl-seed.md`
- Tạo mới: `.claude/skills/workflow/wf-define-features/procedures/phase0.5-workload-gate.md`

**Nội dung `phase0.5-workload-gate.md`:**

```
PRE-GATE: Phase 0 POST-GATE PASS
INPUT: $REGISTRY_DATA (modules, features count estimate từ requirements, LEGACY_MODE flag)
OUTPUT: sessions/{id}/workload-report.md

Steps:
| Step | Action | Verify |
|------|--------|--------|
| 0.5.1 | Import _shared/partition/planner.py → plan_partitions(items=$ACTIVE_MODULES, group_key="module", max_per_partition=5) | Partitions generated |
| 0.5.2 | Import _shared/partition/workload_gate.py → estimate_workload(partitions, est_minutes_per_item=5.0). Factor: ×1.0 normal, ×1.5 LEGACY_MODE, ×2.0 nếu trung bình >3 features/module (dựa trên requirements → module ratio) | WorkloadEstimate calculated |
| 0.5.3 | check_workload_gate(estimate, threshold_minutes=45). Ratio = estimated/45 | GateResult obtained |
| 0.5.4 | IF dead_zone (<0.8) → silent continue. IF warn (0.8-1.5) → AskUserQuestion: "Estimated {X} min for {N} modules. Continue?". IF block (>1.5) → Plan A/B menu (narrow scope to 1 system / override+CDG-A02 / partition sequential) | User decision recorded |
| 0.5.5 | WRITE workload-report.md từ template _shared/templates/workload-report.md | test -s workload-report.md |
| 0.5.6 | Update session-state.json: phases.P0_5.status, next_action = "phase0.5-legacy-impl-seed" (IF LEGACY_MODE) else "phase1-scope-mapping" | State persisted |

POST-GATE: Workload estimate recorded, user acknowledged (if WARN/BLOCK).
Next phase: phase0.5-legacy-impl-seed.md (IF LEGACY_MODE) → phase1-scope-mapping.md
```

**Sau khi rename `phase0.5-legacy-impl-seed.md`:**
- Update internal references trong SKILL.md + _contract.json + các phase files khác.
- Không thay đổi logic bên trong — chỉ rename file + update references.

**Lưu ý:**
- Template strip trước khi ghi workload-report.md (`_shared/_shared.md §1`).
- Atomic write cho mọi JSON output (`_shared/_shared.md §2`).
- CDG-A02 trigger khi user chọn override gate BLOCK (`_shared/cdg/cdg_handler.py`).

---

### Task 2: Cập nhật `procedures/_shared.md`

**Vị trí:** `.claude/skills/workflow/wf-define-features/procedures/_shared.md`

**Thay đổi cần thực hiện:**

1. **Thêm section mới** sau `## State Variables Glossary`:
   - `$SESSION_DIR` — Set by Phase 0, Read by ALL — `.mc-data/work/wf-define-features/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`
   - `$SESSION_ID` — Set by Phase 0, Read by ALL — `YYYYMMDD-HHMMSS-hash4`
   - `$WORKLOAD_ESTIMATE` — Set by Phase 0.5, Read by Phase 1,2,3 — WorkloadEstimate object từ `_shared/partition/`
   - `$GATE_RESULT` — Set by Phase 0.5, Read by Phase 1,2 — GateResult (dead_zone/warn/block)

2. **Cập nhật `## Phase → File Mapping`** — thêm dòng:
   - `| Phase 0.5 workload | phase0.5-workload-gate.md | Workload estimation + gate evaluation (ADR-OPT-03) |`
   - Sửa dòng hiện tại: `| Phase 0.5 impl-status | phase0.5-legacy-impl-seed.md | Seed impl_status từ legacy scan (LEGACY only) |`

3. **Cập nhật `## Phase Ordering by Mode`** — thêm Phase 0.5 workload:
   - `new`: `0 → 0.5-workload → 1 → 2 → 3 → 4 → 5`
   - `legacy`: `0 → 0.5-workload → 0.5-legacy-impl-seed → 1 → 2 → 2.5 → 2.7 → 3 → 4 → 5`

4. **Thêm section mới** `## Session Isolation Protocol (ADR-OPT-02)`:
   ```
   Session dir structure:
   sessions/{YYYYMMDD-HHMMSS}-{hash4}/
   ├── session-state.json        ← 3-level checkpoint state machine
   ├── define-features-status.json
   ├── checkpoint.json           ← Legacy checkpoint (backward-compat)
   ├── lanes/                    ← Lane outputs (Phase 2)
   │   ├── {system}-{module}/
   │   │   └── signals.json
   │   └── ...
   ├── workload-report.md        ← Workload gate report (Phase 0.5)
   ├── aggregation-result.json   ← Signal aggregation result (Phase 3)
   ├── feature-briefs.json       ← Working copy (post-strip copy to _meta/)
   └── phase-summary.md          ← CORE-028 append-only

   latest pointer: .mc-data/work/wf-define-features/latest (text file = session dir path)

   3-level checkpoint:
   - L1 Phase: session-state.json phases.P{N}.status
   - L2 Batch: session-state.json phases.P{N}.batches[{K}].status (module-batch)
   - L3 Item: session-state.json phases.P{N}.batches[{K}].items[{I}].status (feat-item, optional)

   Cleanup policy: giữ 5 sessions mới nhất per skill
   ```

5. **Thêm section mới** `## _shared Module Imports (ADR-OPT Integration)`:
   - Import convention: `from {module} import {function}` — xem `_shared/_shared.md §3-4`
   - Module map: `lane` (Phase 2), `partition` (Phase 0.5), `aggregate` (Phase 3), `cache` (Phase 0.5), `cdg` (Phase 0.5)

6. **Cập nhật `## Token Budget & Checkpoint`:**
   - Thay `checkpoint.json` → `session-state.json` là primary checkpoint
   - `checkpoint.json` vẫn tạo cho backward-compat
   - SAVE CHECKPOINT = update session-state.json phases + checkpoint.json (dual write)

---

### Task 3: Cập nhật `procedures/phase0-context.md`

**Vị trí:** `.claude/skills/workflow/wf-define-features/procedures/phase0-context.md`

**Thay đổi cần thực hiện:**

1. **Sau Step 0.2 (mkdir)** — thêm Step 0.2b:
   ```
   | 0.2b | Session Isolation (ADR-OPT-02): Tạo session dir `.mc-data/work/wf-define-features/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`. Set $SESSION_DIR và $SESSION_ID. Tạo session-state.json từ template `_shared/templates/session-state.json`. Tạo `latest` pointer: echo "$SESSION_DIR" > `.mc-data/work/wf-define-features/latest`. Cleanup: đếm sessions hiện có, nếu > 5 → xoá cũ nhất. | test -d $SESSION_DIR && test -f session-state.json |
   ```

2. **Cập nhật Step 0.3** — `define-features-status.json` ghi vào `$SESSION_DIR/define-features-status.json` (thêm symlink hoặc copy về root cho backward-compat).

3. **Cập nhật `--resume` handler:**
   - Đọc `$SESSION_DIR/session-state.json` → `next_action` → dispatch phase.
   - Fallback: nếu session-state.json không có → fallback checkpoint.json (backward-compat).

4. **Thêm CORE-026 trace:** Append START entry với `$SESSION_ID` vào metadata.

5. **Cập nhật Next phase:** thêm `phase0.5-workload-gate.md` (thay vì nhảy thẳng tới phase0.5-legacy-impl-seed / phase1-scope-mapping).

---

### Task 4: Cập nhật `procedures/phase2-create-specs.md` + `procedures/phase2.5-feat-mapping.md`

**Vị trí:** `.claude/skills/workflow/wf-define-features/procedures/phase2-create-specs.md` (primary) + `procedures/phase2.5-feat-mapping.md` (LEGACY extension)

**Thay đổi cần thực hiện (phase2-create-specs.md):**

1. **Cập nhật Step 2.1** — formalize lane dispatch:
   ```
   | 2.1 | Lane Dispatch (ADR-OPT-01): Import _shared/lane/dispatcher.py.
        Build LaneConfig list: mỗi (system, module) pair → LaneConfig(
          key="{system-slug}-{module-slug}",
          agent_type="business-analyst",
          prompt=BA Phase 2 template từ _shared.md,
          output_path=$SESSION_DIR/lanes/{system}-{module}/signals.json,
          context={module requirements from registry, feature template, LEGACY context nếu có}
        ).
        dispatch_lanes(lanes, max_parallel=$LPM_PARAMS.max_parallel_agents, timeout_sec=300).
        TRƯỚC KHI spawn: check nếu feature spec đã tồn tại → skip lane (giữ logic skip hiện tại). | Lanes dispatched, max_parallel enforced |
   ```

2. **Cập nhật Step 2.2-2.3** — verify lane outputs:
   ```
   | 2.2 | Mỗi lane: verify signals.json tồn tại + non-empty | test -s lanes/{sys}-{mod}/signals.json |
   | 2.3 | Mỗi lane: verify feature .md files được viết vào phase2-features/{sys}/{mod}/*.md (no placeholders) | grep -rL "TODO\|TBD" phase2-features/{sys}/{mod}/ |
   ```

3. **Cập nhật Step 2.4** — checkpoint update:
   ```
   | 2.4 | Sau MỖI lane complete: update session-state.json phases.P2.batches[{sys}-{mod}].status = "completed" (L2). Cập nhật lanes_completed[]. | session-state.json updated |
   ```

4. **Thêm note** ở cuối:
   ```
   Lane output schema: _shared/templates/lane-signal.json (lane_key, lane_type="feature", items[]=[{feat_id, module, system, ...}], metadata)
   Write-scope isolation: mỗi lane viết vào phase2-features/{sys}/{mod}/ riêng → không lock contention (CORE-025)
   ```

**Thay đổi cần thực hiện (phase2.5-feat-mapping.md — LEGACY only):**

1. **Cập nhật Step 2.5.x** — nếu có parallel agent spawn cho legacy FEAT-ID mapping, cũng dùng Lane Dispatch (lane_key={module-slug}-mapping).
2. **Giữ nguyên** nếu phase này hiện tại là sequential — không force lane-ify nếu không cần.

---

### Task 5: Cập nhật `procedures/phase3-cross-validation.md`

**Vị trí:** `.claude/skills/workflow/wf-define-features/procedures/phase3-cross-validation.md`

**Thay đổi cần thực hiện:**

1. **Thêm step mới sau Step 3.1** — signal aggregation:
   ```
   | 3.1b | Signal Aggregation (ADR-OPT-04): Import _shared/aggregate/aggregator.py.
          aggregate_lane_signals(lane_outputs=$SESSION_DIR/lanes/*/signals.json, dedup_key_fn=dedup_by_id("feat_id")).
          Dedup key: FEAT-ID normalized (uppercase, strip sys/mod prefix mismatch).
          Output: $SESSION_DIR/aggregation-result.json (total_input, total_output, duplicates, conflicts[]).
          IF conflicts[] non-empty → flag cho Phase 4 stakeholder review (thêm vào conflict log). | aggregation-result.json written |
   ```

2. **Cập nhật cross-validation logic** — dựa trên aggregation result:
   ```
   | 3.2 | Chuẩn hóa FEAT-ID scheme theo aggregation result — loại duplicates, flag conflicts. | All IDs unique or flagged |
   ```

3. **Cập nhật checkpoint:**
   ```
   | 3.X | SAVE CHECKPOINT: update session-state.json phases.P3.status = "completed". Append aggregation metrics (dedup_input_count, dedup_output_count, conflict_count). | session-state.json updated |
   ```

---

### Task 6: Cập nhật `procedures/phase5-registry-update.md` (Phiên 6 — digest output)

**Vị trí:** `.claude/skills/workflow/wf-define-features/procedures/phase5-registry-update.md`

**Thay đổi cần thực hiện:**

1. **Cập nhật step tạo `feature-briefs.json`** — thêm template strip:
   ```
   | 5.X | Tạo $SESSION_DIR/feature-briefs.json từ template `_digests/feature-briefs.template.json` → **Template Strip (ADR-OPT-05)**:
          jq 'del(._template_notes, ._comments, ._examples, ._placeholder, ._description)' digest.json > digest-stripped.json.
          **Atomic Write**: write to $SESSION_DIR/feature-briefs.json.tmp → jq validate → mv to final.
          (xem _shared/_shared.md §1-2 cho protocol chi tiết) | Digest hợp lệ JSON, không chứa _template_notes |
   ```

2. **Thêm step sync canonical:**
   ```
   | 5.X+1 | SYNC sang canonical _meta/ path:
          cp $SESSION_DIR/feature-briefs.json .mc-data/docs/_meta/feature-briefs.json
          (Note: source giờ từ $SESSION_DIR thay vì fixed working dir) | canonical file exists |
   ```

3. **Thêm POST-GATE check mới:**
   ```bash
   # Verify no _template_notes in digest outputs
   jq -e 'has("_template_notes")' .mc-data/docs/_meta/feature-briefs.json → false
   jq -e '.features | length > 0' .mc-data/docs/_meta/feature-briefs.json → true
   ```

4. **Registry Safe-Write (Phase 5 registry update — giữ nguyên):**
   - CORE-006: chỉ update `features`, `features.impl_status`, top-level `impl_status` (chỉ `skipped` cho features thuộc DEPRECATE modules).
   - KHÔNG đổi write scope — bảo toàn contract.

---

## Constraints (BẮT BUỘC)

1. **KHÔNG thay đổi `registry_scope.fields_owned`** — vẫn là `["features", "features.impl_status", "impl_status"]`.
2. **KHÔNG thay đổi Phase 2.7 UI coverage logic** — chỉ lane-ify Phase 2 primary + Phase 2.5 nếu cần.
3. **Rename phase0.5-impl-status.md → phase0.5-legacy-impl-seed.md PHẢI atomic** — `git mv` + update tất cả references cùng commit.
4. **Tiếng Việt cho docs/comments, English cho code/names** (CORE-005).
5. **Template Usage Rule (CORE-031)** — mọi output file phải READ template → POPULATE → WRITE.
6. **Surgical changes only (BHV-003)** — chỉ thêm/sửa đúng những gì ADR-OPT yêu cầu, không refactor thêm.
7. **Import convention** theo `_shared/_shared.md §3-4`.
8. **KHÔNG viết Python code** — procedure files là Markdown instructions.
9. **Backward compatibility** — `feature-briefs.json` schema UNCHANGED (chỉ thêm session isolation path).

---

## Verify Checklist (sau khi hoàn tất)

| # | Check | Command |
|---|-------|---------|
| V1 | `phase0.5-workload-gate.md` tồn tại, có PRE-GATE + Steps + POST-GATE | `test -f .claude/skills/workflow/wf-define-features/procedures/phase0.5-workload-gate.md` |
| V2 | `phase0.5-legacy-impl-seed.md` tồn tại (renamed từ impl-status.md), không còn `phase0.5-impl-status.md` | `test -f .claude/skills/workflow/wf-define-features/procedures/phase0.5-legacy-impl-seed.md && ! test -e .claude/skills/workflow/wf-define-features/procedures/phase0.5-impl-status.md` |
| V3 | `_shared.md` có Session Isolation Protocol section | `grep -q "Session Isolation Protocol" .claude/skills/workflow/wf-define-features/procedures/_shared.md` |
| V4 | `_shared.md` Phase→File Mapping có Phase 0.5 workload | `grep -q "phase0.5-workload-gate" .claude/skills/workflow/wf-define-features/procedures/_shared.md` |
| V5 | `phase0-context.md` có Step 0.2b session creation | `grep -q "0.2b" .claude/skills/workflow/wf-define-features/procedures/phase0-context.md` |
| V6 | `phase2-create-specs.md` có Lane Dispatch reference | `grep -q "Lane Dispatch" .claude/skills/workflow/wf-define-features/procedures/phase2-create-specs.md` |
| V7 | `phase3-cross-validation.md` có Signal Aggregation step | `grep -qE "Signal Aggregation\|3.1b" .claude/skills/workflow/wf-define-features/procedures/phase3-cross-validation.md` |
| V8 | `phase5-registry-update.md` có template strip + atomic write | `grep -qE "_template_notes\|Atomic Write" .claude/skills/workflow/wf-define-features/procedures/phase5-registry-update.md` |
| V9 | `_contract.json` JSON valid + version = 3.0.0 | `node -e "const c=JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-define-features/_contract.json')); console.log(c.version)"` → `3.0.0` |
| V10 | `registry_scope.fields_owned` không thay đổi | `node -e "const c=JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-define-features/_contract.json')); console.log(JSON.stringify(c.registry_scope.fields_owned))"` → `["features","features.impl_status","impl_status"]` |

---

## Post-Rollout Validation (chạy trong phiên riêng sau khi V1-V10 PASS)

Sau khi V1-V10 PASS, chạy tương tự `phase2-validation-tests.md` nhưng cho skill này:
1. Skill Compliance Audit: `./.claude/scripts/skill-compliance-audit.sh wf-define-features`
2. Schema Sync Validation: `./.claude/scripts/validate-schema-sync.sh wf-define-features`
3. Update evals: thêm ≥3 test cases (session-isolation, workload-gate, lane-dispatch, signal-aggregation, template-strip)
4. `/audit-devkit-scan` + `/audit-devkit-verify --skill=wf-define-features` + `/audit-devkit-fix`
5. `/audit-skill-output wf-define-features` (cần 1 project đã chạy xong v3.0.0)
6. Update sign-off doc với evidence block

Chi tiết test cases: copy format từ `phase2-validation-tests.md` Task 3, thay `dept` bằng `module`, thay `REQ-ID` bằng `FEAT-ID`.
