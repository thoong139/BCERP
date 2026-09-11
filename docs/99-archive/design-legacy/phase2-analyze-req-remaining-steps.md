# Phase 2 — wf-analyze-requirements: Remaining Implementation Steps

> **Tạo:** 2026-04-23
> **Mục đích:** Prompt-ready checklist cho phiên tiếp theo — update 6 procedure files để hoàn thiện SKILL.md v3.0.0
> **Prerequisite:** SKILL.md v3.0.0 + _contract.json v3.0.0 đã cập nhật (xong trong phiên trước)

---

## Context (đọc trước khi bắt đầu)

Phase 2 ADR-OPT rollout cho `wf-analyze-requirements` đã hoàn thành **bước 1** (design docs):

**ĐÃ XONG:**
- `SKILL.md` bump v2.1.0 → v3.0.0 — thêm 5 ADR-OPT techniques vào design
- `_contract.json` bump v2.2.0 → v3.0.0 — thêm session-state, lane outputs, gate report, aggregation result, latest pointer
- All backward-compat checks PASS, registry_scope.fields_owned unchanged

**CÒN LẠI:** Update 6 procedure files để AI agent thực thi theo SKILL.md v3.0.0 mới.

**Key references:**
- ADR đầy đủ: `docs/design/skills/ADR-downstream-skills-optimization.md`
- Phase 1 hạ tầng: `docs/design/skills/phase1-prereq-shared-infrastructure.md`
- _shared protocol: `.claude/skills/workflow/_shared/_shared.md`
- _shared module map: `.claude/skills/workflow/_shared/README.md` §4-§5

---

## Tasks (thực hiện theo thứ tự)

### Task 1: Tạo `procedures/phase0.5-workload-gate.md` (MỚI)

**Vị trí:** `.claude/skills/workflow/wf-analyze-requirements/procedures/phase0.5-workload-gate.md`

**Nội dung cần có:**

```
PRE-GATE: Phase 0 POST-GATE PASS
INPUT: $REGISTRY_DATA (systems, modules, requirements, departments counts)
OUTPUT: sessions/{id}/workload-report.md

Steps:
| Step | Action | Verify |
|------|--------|--------|
| 0.5.1 | Import _shared/partition/planner.py → plan_partitions(items=$ACTIVE_DEPTS, group_key="department", max_per_partition=5) | Partitions generated |
| 0.5.2 | Import _shared/partition/workload_gate.py → estimate_workload(partitions, est_minutes_per_item=3.0). Factor: ×1.0 normal, ×1.5 LEGACY_MODE, ×2.0 multi-system+compliance | WorkloadEstimate calculated |
| 0.5.3 | check_workload_gate(estimate, threshold_minutes=45). Ratio = estimated/45 | GateResult obtained |
| 0.5.4 | IF dead_zone (<0.8) → silent continue. IF warn (0.8-1.5) → AskUserQuestion: "Estimated {X} min. Continue?". IF block (>1.5) → Plan A/B menu (narrow scope / override+CDG-A02 / partition sequential) | User decision recorded |
| 0.5.5 | WRITE workload-report.md từ template _shared/templates/workload-report.md | test -s workload-report.md |
| 0.5.6 | Update session-state.json: phases.P0_5.status, next_action | State persisted |

POST-GATE: Workload estimate recorded, user acknowledged (if WARN/BLOCK).
Next phase: phase1-scope.md
```

**Lưu ý:**
- Template strip (`_shared/_shared.md §1`) trước khi ghi workload-report.md
- Atomic write (`_shared/_shared.md §2`) cho mọi JSON output
- CDG-A02 trigger khi user chọn override gate BLOCK (import `_shared/cdg/cdg_handler.py`)

---

### Task 2: Cập nhật `procedures/_shared.md`

**Vị trí:** `.claude/skills/workflow/wf-analyze-requirements/procedures/_shared.md`

**Thay đổi cần thực hiện:**

1. **Thêm section mới** sau `## State Variables Glossary`:
   - `$SESSION_DIR` — Set by Phase 0, Read by ALL — `.mc-data/work/wf-analyze-requirements/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`
   - `$SESSION_ID` — Set by Phase 0, Read by ALL — `YYYYMMDD-HHMMSS-hash4`
   - `$WORKLOAD_ESTIMATE` — Set by Phase 0.5, Read by 1,2,3,4 — WorkloadEstimate object from `_shared/partition/`
   - `$GATE_RESULT` — Set by Phase 0.5, Read by 1,2 — GateResult (dead_zone/warn/block)

2. **Cập nhật `## Phase → File Mapping`** — thêm dòng:
   - `| Phase 0.5 | phase0.5-workload-gate.md | Workload estimation + gate evaluation (ADR-OPT-03) |`

3. **Cập nhật `## Phase Ordering by Scope`** — thêm Phase 0.5 vào mỗi scope:
   - `all`: `0→0.5→1→2→...`
   - `business`: `0→0.5→1→2→...`
   - `[module-name]`: `0→0.5→1→2→...`

4. **Thêm section mới** `## Session Isolation Protocol (ADR-OPT-02)`:
   ```
   Session dir structure:
   sessions/{YYYYMMDD-HHMMSS}-{hash4}/
   ├── session-state.json     ← 3-level checkpoint state machine
   ├── analyze-status.json    ← Phase status tracking
   ├── checkpoint.json        ← Legacy checkpoint (backward-compat)
   ├── lanes/                 ← Lane outputs (Phase 4)
   │   ├── {dept-key}/
   │   │   └── signals.json
   │   └── ...
   ├── workload-report.md     ← Workload gate report (Phase 0.5)
   ├── aggregation-result.json ← Signal aggregation result (Phase 6)
   ├── department-digests.json
   ├── phase1-handoff.json
   └── phase-summary.md       ← CORE-028 append-only

   latest pointer: .mc-data/work/wf-analyze-requirements/latest (text file = session dir path)

   3-level checkpoint:
   - L1 Phase: session-state.json phases.P{N}.status
   - L2 Batch: session-state.json phases.P{N}.batches[{K}].status (dept-batch)
   - L3 Item: session-state.json phases.P{N}.batches[{K}].items[{I}].status (req-item, optional)

   Cleanup policy: giữ 5 sessions mới nhất per skill (Sign-off Item #3)
   ```

5. **Thêm section mới** `## _shared Module Imports (ADR-OPT Integration)`:
   - Import convention: `from {module} import {function}` — xem `_shared/_shared.md §3-4`
   - Module map: lane (Phase 4), partition (Phase 0.5), aggregate (Phase 6), cache (Phase 0.5), cdg (Phase 0.5, 6d)

6. **Cập nhật `## Token Budget & Checkpoint`**:
   - Thay `checkpoint.json` → `session-state.json` là primary checkpoint
   - `checkpoint.json` vẫn tạo cho backward-compat, nhưng session-state.json là source of truth mới
   - SAVE CHECKPOINT = update session-state.json phases + checkpoint.json (dual write)

---

### Task 3: Cập nhật `procedures/phase0-context.md`

**Vị trí:** `.claude/skills/workflow/wf-analyze-requirements/procedures/phase0-context.md`

**Thay đổi cần thực hiện:**

1. **Sau Step 0.2 (mkdir)** — thêm:
   ```
   | 0.2b | Session Isolation (ADR-OPT-02): Tạo session dir `.mc-data/work/wf-analyze-requirements/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`. Set $SESSION_DIR và $SESSION_ID. Tạo session-state.json từ template _shared/templates/session-state.json. Tạo `latest` pointer: echo "$SESSION_DIR" > .mc-data/work/wf-analyze-requirements/latest. Cleanup: đếm sessions hiện có, nếu > 5 → xoá cũ nhất. | test -d $SESSION_DIR && test -f session-state.json |
   ```

2. **Cập nhật Step 0.3** — `analyze-status.json` ghi vào `$SESSION_DIR/analyze-status.json` (thêm symlink hoặc copy về root cho backward-compat)

3. **Cập nhật `--resume` handler** trong Step 0.7:
   - Thêm: đọc `$SESSION_DIR/session-state.json` → `next_action` → dispatch phase
   - Fallback: nếu session-state.json không có → fallback checkpoint.json (backward-compat)

4. **Thêm CORE-026 trace**: Append START entry vào `session-state.json` (thêm `$SESSION_ID` vào trace metadata)

5. **Cập nhật Next phase** — thêm `phase0.5-workload-gate.md` (thay vì trực tiếp phase1-scope.md)

---

### Task 4: Cập nhật `procedures/phase4-experts-partb.md`

**Vị trí:** `.claude/skills/workflow/wf-analyze-requirements/procedures/phase4-experts-partb.md`

**Thay đổi cần thực hiện:**

1. **Cập nhật Step 4.1** — formalize lane dispatch:
   ```
   | 4.1 | Lane Dispatch (ADR-OPT-01): Import _shared/lane/dispatcher.py.
        Build LaneConfig list: mỗi dept → LaneConfig(key=dept-slug, agent_type=domain-expert, prompt=expert template, output_path=$SESSION_DIR/lanes/{dept-slug}/signals.json, context={dept BA output, legacy context}).
        dispatch_lanes(lanes, max_parallel=3, timeout_sec=300).
        TRƯỚC KHI spawn: check nếu Phần B đã tồn tại → skip lane (giữ nguyên logic skip hiện tại).
        Heavyweight depts (>= 4 areas): Split Strategy vẫn áp dụng trong lane — lane spawn 2 calls tuần tự. | Lanes dispatched, max_parallel=3 enforced |
   ```

2. **Cập nhật Step 4.2-4.3** — verify lane outputs:
   ```
   | 4.2 | Mỗi lane: verify signals.json tồn tại + non-empty | test -s lanes/{dept}/signals.json |
   | 4.3 | Mỗi lane: verify no placeholders trong dept .md file | grep -rL "TODO\|TBD" |
   ```

3. **Cập nhật Step 4.4** — checkpoint update dùng session-state.json:
   ```
   | 4.4 | Sau MỖI lane complete: update session-state.json phases.P4.batches[{dept}].status = "completed" (L2 checkpoint). Cập nhật lanes_completed[]. | session-state.json updated |
   ```

4. **Thêm note** ở cuối:
   ```
   Lane output schema: _shared/templates/lane-signal.json (lane_key, lane_type="department", items[], metadata)
   Write-scope isolation: mỗi lane viết vào dir riêng → không lock contention (CORE-025)
   ```

---

### Task 5: Cập nhật `procedures/phase6-consolidate.md`

**Vị trí:** `.claude/skills/workflow/wf-analyze-requirements/procedures/phase6-consolidate.md`

**Thay đổi cần thực hiện:**

1. **Thêm step mới sau Step 6.2** — signal aggregation:
   ```
   | 6.2b | Signal Aggregation (ADR-OPT-04): Import _shared/aggregate/aggregator.py.
          aggregate_lane_signals(lane_outputs=$SESSION_DIR/lanes/*/signals.json, dedup_key_fn=dedup_by_id("req_id")).
          Dedup key: REQ-ID normalized (lowercase, strip dept prefix mismatch).
          Output: $SESSION_DIR/aggregation-result.json (total_input, total_output, duplicates, conflicts[]).
          IF conflicts[] non-empty → flag cho Phase 6d xử lý (thêm vào conflict log). | aggregation-result.json written |
   ```

2. **Cập nhật Step 6.3** — chuẩn hóa REQ-ID dựa trên aggregation result:
   ```
   | 6.3 | Chuẩn hóa REQ-ID scheme theo aggregation result — loại duplicates, flag conflicts | All IDs unique or flagged |
   ```

3. **Cập nhật Step 6.5** — checkpoint:
   ```
   | 6.5 | SAVE CHECKPOINT: update session-state.json phases.P6.status = "completed". Append aggregation metrics (dedup_input_count, dedup_output_count, conflict_count). | session-state.json updated |
   ```

---

### Task 6: Cập nhật `procedures/phase8c-handoff.md`

**Vị trí:** `.claude/skills/workflow/wf-analyze-requirements/procedures/phase8c-handoff.md`

**Thay đổi cần thực hiện:**

1. **Cập nhật Step 8c.1** — thêm template strip:
   ```
   | 8c.1 | Tạo department-digests.json từ template → **Template Strip (ADR-OPT-05)**:
          jq 'del(._template_notes, ._comments, ._examples, ._placeholder, ._description)' digest.json > digest-stripped.json.
          **Atomic Write**: write to $SESSION_DIR/department-digests.json.tmp → jq validate → mv to final.
          (xem _shared/_shared.md §1-2 cho protocol chi tiết) | Digest hợp lệ JSON, không chứa _template_notes |
   ```

2. **Cập nhật Step 8c.2** — thêm template strip:
   ```
   | 8c.2 | Tạo phase1-handoff.json từ template → **Template Strip** → **Atomic Write** (cùng pattern 8c.1) | Digest hợp lệ JSON, không chứa _template_notes |
   ```

3. **Cập nhật Step 8c.2b** — sync từ session dir:
   ```
   | 8c.2b | SYNC sang canonical _meta/ paths:
          cp $SESSION_DIR/department-digests.json .mc-data/docs/_meta/dept-digests.json
          cp $SESSION_DIR/phase1-handoff.json .mc-data/docs/_meta/phase1-handoff.json
          (Note: source giờ từ $SESSION_DIR thay vì fixed working dir) | canonical files exist |
   ```

4. **Thêm POST-GATE check mới**:
   ```bash
   # Verify no _template_notes in digest outputs
   jq -e 'has("_template_notes")' .mc-data/docs/_meta/dept-digests.json → false
   jq -e 'has("_template_notes")' .mc-data/docs/_meta/phase1-handoff.json → false
   ```

---

## Constraints (BẮT BUỘC)

1. **KHÔNG thay đổi behavior của standard profile** — backward-compat 100%
2. **KHÔNG thay đổi registry_scope.fields_owned** — vẫn là `["systems", "modules", "departments", "requirements", "interface_type"]`
3. **Tiếng Việt cho docs/comments, English cho code/names** (CORE-005)
4. **Template Usage Rule (CORE-031)** — mọi output file phải READ template → POPULATE → WRITE
5. **Surgical changes only (BHV-003)** — chỉ thêm/sửa đúng những gì ADR-OPT yêu cầu, không refactor thêm
6. **Import convention** theo `_shared/_shared.md §3-4` — `from {module} import {function}`
7. **KHÔNG viết Python code** — procedure files là Markdown instructions cho AI agent, không phải executable code

---

## Verify Checklist (sau khi hoàn tất)

| # | Check | Command |
|---|-------|---------|
| V1 | phase0.5-workload-gate.md tồn tại, có PRE-GATE + Steps + POST-GATE | `test -f procedures/phase0.5-workload-gate.md` |
| V2 | _shared.md có session isolation protocol section | `grep "Session Isolation" procedures/_shared.md` |
| V3 | _shared.md Phase→File Mapping có Phase 0.5 | `grep "phase0.5" procedures/_shared.md` |
| V4 | phase0-context.md có Step 0.2b session creation | `grep "0.2b" procedures/phase0-context.md` |
| V5 | phase4-experts-partb.md có Lane Dispatch reference | `grep "Lane Dispatch" procedures/phase4-experts-partb.md` |
| V6 | phase6-consolidate.md có Signal Aggregation step | `grep "Signal Aggregation\|6.2b" procedures/phase6-consolidate.md` |
| V7 | phase8c-handoff.md có template strip + atomic write | `grep "_template_notes\|Atomic Write" procedures/phase8c-handoff.md` |
| V8 | _contract.json JSON valid | `node -e "JSON.parse(require('fs').readFileSync('_contract.json')); console.log('OK')"` |
| V9 | SKILL.md version vẫn 3.0.0 | `grep "version: 3.0.0" SKILL.md` |
| V10 | registry_scope.fields_owned không thay đổi | `node -e "const c=JSON.parse(require('fs').readFileSync('_contract.json')); console.log(c.registry_scope.fields_owned)"` |
