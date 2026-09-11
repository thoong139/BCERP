# Phase 2 — wf-analyze-requirements: Validation + Tests (Sign-off)

> **Tạo:** 2026-04-23
> **Mục đích:** Prompt-ready checklist cho phiên tiếp theo — chạy compliance audit, update evals, audit-devkit-scan/verify cho `wf-analyze-requirements` v3.0.0
> **Prerequisite:** Phase 2 design + procedures đã hoàn tất (xem `phase2-analyze-req-remaining-steps.md`)

---

## Context (đọc trước khi bắt đầu)

Phase 2 ADR-OPT rollout cho `wf-analyze-requirements` đã hoàn thành **2 bước đầu**:

**ĐÃ XONG:**
- SKILL.md bump v2.1.0 → v3.0.0 + _contract.json v3.0.0 (5 ADR-OPT techniques)
- 6 procedure files updated: phase0-context, phase0.5-workload-gate (mới), phase4-experts-partb, phase6-consolidate, phase8c-handoff, _shared
- Verify checklist V1-V10 PASS (grep counts, JSON valid, registry_scope unchanged)

**CÒN LẠI (bước 3 — validation):**
Chạy validation tools để xác nhận skill định nghĩa hợp lệ + không phá vỡ cross-skill contracts, sau đó bổ sung test cases để bảo vệ behavior.

**Key references:**
- ADR đầy đủ: `docs/design/skills/ADR-downstream-skills-optimization.md`
- Phase 2 procedures log: `docs/design/skills/phase2-analyze-req-remaining-steps.md`
- _shared protocol: `.claude/skills/workflow/_shared/_shared.md`
- Shared module map: `.claude/skills/workflow/_shared/README.md` §4-§5
- Compliance script: `.claude/scripts/skill-compliance-audit.sh`
- Schema sync script: `.claude/scripts/validate-schema-sync.sh`

---

## Tasks (thực hiện theo thứ tự)

### Task 1: Skill Compliance Audit

**Mục tiêu:** Xác nhận `wf-analyze-requirements` v3.0.0 tuân thủ skill compliance rules (frontmatter, _contract.json fields, templates tồn tại, evals có ≥3 test cases).

**Command:**
```bash
./.claude/scripts/skill-compliance-audit.sh wf-analyze-requirements
```

**Expected outcomes:**
- PASS: Tất cả checks đều OK — tiến sang Task 2
- FAIL: Đọc từng finding, fix inline (trong SKILL.md hoặc _contract.json), re-run audit
- Common issues cần chú ý sau v3.0.0:
  - `outputs.working[].template` PHẢI có path cho mọi entry mới: `_shared/templates/session-state.json`, `_shared/templates/workload-report.md`, `_shared/templates/lane-signal.json`, `_shared/templates/aggregation-result.json`
  - `procedure_files[]` phải include `procedures/phase0.5-workload-gate.md`
  - Frontmatter fields: `name`, `version`, `description`, `argument-hint`, `allowed-tools`

**Verify:**
```bash
./.claude/scripts/skill-compliance-audit.sh wf-analyze-requirements | tail -5 | grep -E "PASS|OK"
```

---

### Task 2: Schema Sync Validation

**Mục tiêu:** Xác nhận `_contract.json` khớp với SKILL.md mô tả (outputs, phases, registry_scope).

**Command:**
```bash
./.claude/scripts/validate-schema-sync.sh wf-analyze-requirements
```

**Expected outcomes:**
- PASS: `_contract.json` v3.0.0 khớp SKILL.md v3.0.0
- FAIL: drift giữa 2 files → fix bên nào lỗi thời
  - Kiểm tra: `version`, `phase`, `procedure_files[]`, `outputs.working[]`, `registry_scope.fields_owned`
  - `cross_skill_contracts.produces_for` / `consumes_from` phải match §4b trong `.claude/rules/00-core.md`

**Verify:**
```bash
./.claude/scripts/validate-schema-sync.sh wf-analyze-requirements 2>&1 | grep -E "OK|FAIL"
```

---

### Task 3: Update `evals/evals.json` — thêm ≥3 test cases cho ADR-OPT-02/03/04/05

**Vị trí:** `.claude/skills/workflow/wf-analyze-requirements/evals/evals.json`

**Yêu cầu:** Mỗi test case cần có `name`, `description`, `input`, `expected_outputs[]`, `expected_artifacts[]` (file paths phải exist sau khi run).

**Test cases bắt buộc:**

1. **`session-isolation-multi-run`** — chạy skill 2 lần liên tiếp
   - Input: cùng project, run 1 rồi run 2 (không `--resume`)
   - Expected: 2 session dirs riêng tại `sessions/{id1}/` và `sessions/{id2}/`
   - Expected: `latest` pointer trỏ đến session dir mới nhất (run 2)
   - Expected: session cũ vẫn nguyên vẹn (không bị overwrite)
   - Verify: `ls -1d sessions/*/ | wc -l >= 2` và `cat latest = sessions/{id2}/`

2. **`workload-gate-dead-zone`** — project nhỏ (≤3 depts, ≤10 requirements)
   - Input: brainstorm chỉ 2 departments, 5 requirements
   - Expected: `workload-report.md` có `gate_status = "dead_zone"`, `ratio < 0.8`
   - Expected: không prompt user (silent continue)
   - Expected: `phases.P0_5.status = "completed"` trong `session-state.json`

3. **`workload-gate-block-override-cdg`** — project lớn (≥10 depts, ≥50 requirements)
   - Input: brainstorm ≥10 departments với nhiều requirements
   - Expected: `workload-report.md` có `gate_status = "block"`, `ratio > 1.5`
   - Expected: `AskUserQuestion` spawned với Plan A/B options
   - Expected: nếu user chọn "Override + CDG" → `cdg-tokens.json` có entry `cdg_id = "CDG-A02-workload-override"`, `decision = "accept"`

4. **`lane-dispatch-parallel-writes`** — verify write-scope isolation
   - Input: 5 departments với 5 domain-experts khác nhau
   - Expected: `lanes/` có 5 subdirs, mỗi subdir có `signals.json` non-empty
   - Expected: mỗi `signals.json` có `lane_key` unique, `items[]` không overlap giữa lanes
   - Expected: không có file lock errors trong `session-log.json`

5. **`signal-aggregation-dedup`** — REQ-ID duplicates giữa 2+ lanes
   - Input: mock scenario 2 dept-lanes cùng produce REQ-SHARED-001
   - Expected: `aggregation-result.json` có `duplicates >= 1`, `total_output < total_input`
   - Expected: `conflicts[]` log conflict entry nếu duplicate có nội dung khác nhau
   - Expected: Phase 6d receive flag cho conflict xử lý

6. **`template-strip-no-leak`** — verify ADR-OPT-05
   - Input: chạy full skill tới Phase 8c
   - Expected: `.mc-data/docs/_meta/dept-digests.json` **KHÔNG** chứa key `_template_notes`, `_comments`, `_examples`, `_placeholder`, `_description`
   - Verify: `jq -e 'has("_template_notes") | not' dept-digests.json` return true

**Format evals.json entry:**
```json
{
  "name": "session-isolation-multi-run",
  "description": "Verify ADR-OPT-02: 2 runs tạo 2 session dirs riêng, latest pointer trỏ đúng",
  "input": {
    "scope": "all",
    "registry_seed": ".claude/skills/workflow/wf-analyze-requirements/evals/fixtures/small-project-registry.json"
  },
  "expected_artifacts": [
    ".mc-data/work/wf-analyze-requirements/sessions/{id1}/session-state.json",
    ".mc-data/work/wf-analyze-requirements/sessions/{id2}/session-state.json",
    ".mc-data/work/wf-analyze-requirements/latest"
  ],
  "assertions": [
    "ls -1d sessions/*/ | wc -l >= 2",
    "test $(cat latest) = sessions/{id2}/"
  ]
}
```

**Verify:**
```bash
node -e "const e=JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-analyze-requirements/evals/evals.json')); console.log('Test cases:', e.test_cases.length); console.log('Names:', e.test_cases.map(t=>t.name))"
# Expected: >= 3 new test cases covering session/workload/lane/aggregate/template-strip
```

---

### Task 4: Run `/audit-devkit-scan`

**Mục tiêu:** Scan toàn DEVKIT tìm structural issues sau khi sửa 6 procedure files.

**Command trong phiên mới:**
```
/audit-devkit-scan
```

**Expected outputs:**
- `.mc-data/work/audit-devkit/scan-result.json` — list findings
- Các finding cần chú ý:
  - Broken cross-refs tới `procedures/phase0.5-workload-gate.md` (file mới)
  - Missing template refs: `_shared/templates/*.json`
  - Naming convention (CORE-016): tất cả file kebab-case
  - REQ-ID format trong docs

**Verify:** Đọc `scan-result.json`, phân loại findings thành:
- `wf-analyze-requirements` related → xử lý ở Task 5-6
- Unrelated (các skill khác) → defer sang phiên audit riêng

---

### Task 5: Run `/audit-devkit-verify`

**Mục tiêu:** Cross-validate findings từ Task 4 — verify integrity, không false positive.

**Command:**
```
/audit-devkit-verify --skill=wf-analyze-requirements
```

**Expected outputs:**
- `.mc-data/work/audit-devkit/verify-result.json` — findings đã xác nhận
- V1-V6 cross-checks PASS (Master Plan Components Verification, Phase 3.5)
- `category` field: `functional` (liên quan ADR-OPT) vs `structural` (format/naming)

**Verify:** 
```bash
jq '.findings | map(select(.status == "confirmed")) | length' .mc-data/work/audit-devkit/verify-result.json
# Expected: số confirmed findings cần fix ở Task 6
```

---

### Task 6: Run `/audit-devkit-fix`

**Mục tiêu:** Auto-fix verified findings với per-fix verification (Read → Edit → Grep verify → Pass/Revert).

**Command:**
```
/audit-devkit-fix
```

**Expected outputs:**
- `.mc-data/work/audit-devkit/fix-log.json` — mỗi fix có entry `{finding_id, status: fixed|reverted|skipped, verify_output}`
- Files đã sửa (chỉ những findings confirmed + auto-fixable)
- Manual issues → LOG: "Requires human review" → KHÔNG auto-fix

**Verify:**
```bash
jq '.fixes | group_by(.status) | map({status: .[0].status, count: length})' fix-log.json
# Expected: fixed > 0, reverted = 0 (nếu có revert → re-investigate)
```

---

### Task 7: Run `/audit-skill-output` cho wf-analyze-requirements

**Mục tiêu:** Verify output thực tế của skill v3.0.0 khớp với SKILL.md design (post-Phase 2 rollout).

**Prerequisite:** Có 1 project đã chạy `/wf-analyze-requirements` xong với v3.0.0 (session dir + canonical outputs đầy đủ).

**Command:**
```
/audit-skill-output wf-analyze-requirements
```

**Expected verifications:**
- Session dir structure đúng (xem `_shared.md §Session Isolation Protocol`)
- `workload-report.md` có 6 placeholders filled (skill_name, profile_used, timestamp, ...)
- `lanes/*/signals.json` đúng schema `lane-signal-v1`
- `aggregation-result.json` đúng schema `aggregation-result-v1`
- Canonical `_meta/dept-digests.json` + `phase1-handoff.json` **KHÔNG** chứa `_template_notes`
- `session-state.json` có tất cả phases marked completed

**Report output:** `.mc-data/work/audit-skill-output/wf-analyze-requirements-report.md`

---

### Task 8: Update Sign-off Document

**Vị trí:** `docs/design/skills/ADR-downstream-skills-optimization-signoff.md`

**Thay đổi cần thực hiện:**

1. **Đánh dấu Phase 2 DONE** cho `wf-analyze-requirements`:
   - Checklist: `[x] SKILL.md v3.0.0`, `[x] _contract.json v3.0.0`, `[x] 6 procedure files`, `[x] V1-V10 verify`, `[x] compliance audit PASS`, `[x] schema sync PASS`, `[x] evals ≥6 test cases`, `[x] audit-devkit-scan/verify/fix`, `[x] audit-skill-output`
2. **Evidence block:**
   - Grep counts V1-V10 (từ phiên trước đã có)
   - Compliance audit exit code + tail output
   - Schema sync exit code
   - Evals test_cases count
   - audit-devkit findings breakdown (scan/verify/fix)
3. **Next milestone:** Phase 3 — 4 skills linear còn lại (`wf-define-features`, `wf-design`, `wf-design-ux`, `wf-plan-modules`)

---

## Constraints (BẮT BUỘC)

1. **KHÔNG thay đổi SKILL.md v3.0.0 hoặc _contract.json v3.0.0** ngoại trừ fix từ compliance audit
2. **KHÔNG modify procedure files** ngoại trừ fix từ audit-devkit-fix
3. **KHÔNG thay đổi `registry_scope.fields_owned`** — vẫn là `["systems", "modules", "departments", "requirements", "interface_type"]`
4. **Tiếng Việt cho docs/comments, English cho code/names** (CORE-005)
5. **Surgical changes only (BHV-003)** — chỉ fix findings confirmed, không refactor thêm
6. **Evals thêm, không xóa** — giữ nguyên test cases hiện có
7. **Ngắn gọn** — các báo cáo intermediate (audit results) lưu trong `.mc-data/work/audit-*` không commit vào git

---

## Verify Checklist Final (sau khi hoàn tất 8 tasks)

| # | Check | Command |
|---|-------|---------|
| F1 | Compliance audit PASS | `./.claude/scripts/skill-compliance-audit.sh wf-analyze-requirements \| tail -1` |
| F2 | Schema sync PASS | `./.claude/scripts/validate-schema-sync.sh wf-analyze-requirements 2>&1 \| tail -1` |
| F3 | Evals có ≥6 test cases mới | `node -e "console.log(JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-analyze-requirements/evals/evals.json')).test_cases.length)"` |
| F4 | audit-devkit-scan result exists | `test -f .mc-data/work/audit-devkit/scan-result.json` |
| F5 | audit-devkit-verify PASS | `jq '.status == "completed"' .mc-data/work/audit-devkit/verify-result.json` |
| F6 | audit-devkit-fix: 0 reverts | `jq '[.fixes[] \| select(.status == "reverted")] \| length == 0' .mc-data/work/audit-devkit/fix-log.json` |
| F7 | audit-skill-output report exists | `test -f .mc-data/work/audit-skill-output/wf-analyze-requirements-report.md` |
| F8 | Sign-off updated | `grep -c "Phase 2 DONE" docs/design/skills/ADR-downstream-skills-optimization-signoff.md` |
| F9 | Registry scope unchanged | `node -e "console.log(JSON.stringify(JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-analyze-requirements/_contract.json')).registry_scope.fields_owned))"` → `["systems","modules","departments","requirements","interface_type"]` |
| F10 | Version vẫn 3.0.0 | `grep "version: 3.0.0" .claude/skills/workflow/wf-analyze-requirements/SKILL.md` |

---

## Nếu Validation FAIL

Nếu bất kỳ task nào FAIL:
1. **DỪNG** — không proceed sang Phase 3 rollout
2. **Phân loại root cause:**
   - Bug trong procedure files → fix, re-run verify checklist V1-V10
   - Bug trong SKILL.md / _contract.json → fix, re-run compliance + schema sync
   - Bug trong `_shared/` module → escalate (ảnh hưởng cả Phase 3)
3. **Ghi lại findings** vào `docs/design/skills/phase2-validation-findings.md`
4. **Chỉ khi tất cả F1-F10 PASS** mới chạy `phase3-rollout-remaining-skills.md`
