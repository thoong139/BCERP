# audit-skill-output — Shared Reference

> Shared rules, dimension specs, skill lookup table, registry schemas, và error codes dùng chung cho mọi phase.
> Load **1 lần** ở Phase 0 — các phase sau tham chiếu ngắn, không re-load.

---

## 1. 8 Audit Dimensions

> Mỗi dimension kiểm tra 1 khía cạnh chất lượng. Kết quả: PASS / WARN / FAIL per check.

### D1: File Existence & Completeness

> Tất cả expected output files tồn tại và non-empty.

| Check | Mô tả | Severity |
| ----- | ----- | -------- |
| D1.1 | Mỗi file trong skill's Output Files list tồn tại | CRITICAL |
| D1.2 | Mỗi file > 0 bytes (non-empty) | CRITICAL |
| D1.3 | Status file tồn tại tại `.mc-data/work/[skill]/` | MAJOR |
| D1.4 | Report file tồn tại (nếu skill có report step) | MAJOR |
| D1.5 | Stakeholder review tồn tại (nếu skill tạo phase docs) | MAJOR |

> **D1.5 Exception:** `wf-brainstorm` KHÔNG tạo stakeholder-review — D1.5 SKIP cho skill này.

### D2: Template Compliance

> Output files tuân thủ doc-framework templates. Sử dụng `_contract.json` từ `.claude/doc-framework/[phase]/` để xác định required sections — KHÔNG hardcode.

| Check | Mô tả | Severity |
| ----- | ----- | -------- |
| D2.0 | Đọc `_contract.json` cho phase tương ứng | CRITICAL |
| D2.1 | Mỗi output file match với template trong contract (theo `output_pattern` glob) | MAJOR |
| D2.2 | Mỗi `required_sections` trong contract tồn tại (startswith matching) | MAJOR |
| D2.3 | File có READS/USED BY metadata nếu `required_metadata` trong contract yêu cầu | MINOR |
| D2.4 | Không có placeholder/TODO/TBD còn lại trong final docs | MINOR |

> **Legacy exception (D2.4):** Placeholder `[UNKNOWN]` trong docs legacy flow là kết quả E009 (template_unfillable). Severity = **WARN** (không FAIL/MINOR), report ghi: "Legacy E009 placeholder — cần manual review".
>
> **Legacy exception (D2.2):** `[UNKNOWN]` chỉ ảnh hưởng D2.4, KHÔNG ảnh hưởng D2.2. Section heading vẫn phải có đủ.
>
> **Startswith matching:** `"## Phan A"` match `"## Phan A: Dashboard & Trang Thai"` — OK. Chỉ FAIL khi không có line nào bắt đầu bằng pattern.
>
> **Fallback nếu chưa có `_contract.json`:** Log WARNING + fallback: grep "## Phan A/B/C/D" trong stakeholder-review. Không FAIL D2.0.

### D3: Registry Schema Validation

> Fields ghi bởi skill phải đúng schema, đúng type, không thiếu.

| Check | Mô tả | Severity |
| ----- | ----- | -------- |
| D3.1 | Registry JSON valid (`jq '.'`) | CRITICAL |
| D3.2 | Skill chỉ ghi fields được phép (Safe-Write Protocol) | CRITICAL |
| D3.3 | Field names đúng schema (không dùng alias sai) | CRITICAL |
| D3.4 | Field types đúng (number vs string, array vs object) | CRITICAL |
| D3.5 | Required fields tồn tại (vd: `dependencies` trong features[]) | MAJOR |
| D3.6 | Không có duplicate entries (id trùng) | MAJOR |
| D3.7 | Count khớp: entries trong registry = content files (chỉ áp dụng skills có 1:1 mapping) | MAJOR (SKIP nếu N:M) |

> **D3.7 Scope Note — "Content files" định nghĩa:** files chứa nội dung chính (feature specs, requirement docs...) — **KHÔNG bao gồm:** stakeholder-review.md, deferred-findings.md, status.json, cross-validation-report.md, gap-report.md.

| Skill | Mapping | D3.7 áp dụng? | Content file pattern |
|-------|---------|---------------|----------------------|
| `wf-define-features` | 1 feature = 1 .md | ✓ CÓ (exact) | `phase2-features/**/*.md` (exclude stakeholder*, _*) |
| `wf-analyze-requirements` | N requirements → 3-5 P1-*.md | ✗ KHÔNG (N:M) | SKIP D3.7 |
| `wf-design` | N modules → architecture docs | ✓ PARTIAL (lower bound) | Mỗi system trong registry có ≥1 doc trong `phase3-architecture/` → WARN nếu thiếu |
| `wf-plan-modules` | Modules + tasks per feature | ✓ PARTIAL (lower bound) | Task files count ≥ features count → WARN nếu ít hơn |
| `wf-brainstorm` | Không có registry entries | ✗ KHÔNG | SKIP D3.7 |
| `wf-design-ux` | Screen groups per system | ✗ KHÔNG (N:M) | SKIP D3.7 |
| `wf-prepare-deployment` | Không có registry entries | ✗ KHÔNG | SKIP D3.7 |

> **D3.7 PARTIAL checks (lower-bound):**
> - `wf-design`: `jq '.systems[] | .id' registry` → mỗi system cần ≥1 file trong `phase3-architecture/` → WARN (không FAIL) nếu system thiếu docs
> - `wf-plan-modules`: `jq '.features | length' registry` → task files count (`phase5-implementation/tasks/**/*.md`) ≥ feature count → WARN nếu ít hơn

### D4: Content Quality (CQG Protocol 8)

> Nội dung thực sự có chất lượng, không chỉ structure.

| Check | Mô tả | Severity |
| ----- | ----- | -------- |
| D4.1 | **Completeness**: Mỗi section có >= 2 câu nội dung thực | MAJOR |
| D4.2 | **Consistency**: REQ-IDs trong docs = REQ-IDs trong registry | CRITICAL |
| D4.3 | **Traceability**: Mỗi feature/module tham chiếu được REQ-ID nguồn | MAJOR |
| D4.4 | **Coherence**: Docs cùng phase không mâu thuẫn (counts, names) | MAJOR |
| D4.5 | **Freshness**: Docs phản ánh registry state mới nhất | MINOR |
| D4.6 | **Content Scoring** (optional): điểm 0-100 theo CQG 8.4 | INFO |

> **Legacy exception matrix (D4):**
>
> | Skill | D4.1 | D4.2 | D4.3 | D4.4 | D4.6 |
> |-------|------|------|------|------|------|
> | Shared skills (legacy flow — Phase 0-3 docs) | **WARN** (Legacy thin content) | Bình thường | Bình thường | Bình thường | Tính bình thường |
> | `wf-design` (legacy — gap analysis) | Bình thường | **SKIP** | **SKIP** | Bình thường | Tính (D4.1+D4.4) |
> | `wf-design-ux` (legacy flow) | Bình thường | Bình thường | Bình thường | Bình thường | Bình thường |
>
> D4 subagent PHẢI ghi chú khi apply exception: "Legacy exception applied — [lý do cụ thể]."

### D5: Cross-Phase Consistency

> Output của phase hiện tại nhất quán với phase trước.

| Check | Mô tả | Severity |
| ----- | ----- | -------- |
| D5.1 | Số lượng modules/features/REQ-IDs khớp giữa phases | CRITICAL |
| D5.2 | Tên modules/features/systems giống nhau (case-insensitive) | MAJOR |
| D5.3 | Phase sau KHÔNG mở rộng scope ngoài phase trước | CRITICAL |
| D5.4 | Cross-refs đến docs phase trước đúng path | MAJOR |
| D5.5 | Deferred findings từ phase trước được integrate | MINOR |

### D6: POST-GATE Re-execution

> Chạy lại tất cả POST-GATE checks của skill như khi skill thực thi.

| Check | Mô tả | Severity |
| ----- | ----- | -------- |
| D6.1 | Mỗi POST-GATE check trong SKILL.md được re-run | varies |
| D6.2 | `test -f` checks cho required files | CRITICAL |
| D6.3 | `test -s` checks cho non-empty files | CRITICAL |
| D6.4 | `jq` validation checks cho registry | CRITICAL |
| D6.5 | `grep` checks cho required content (Phan A/B/C/D, etc.) | MAJOR |

> **Legacy path note (D6):** `wf-design` (legacy — gap analysis) và `wf-design-ux` (legacy) dùng base path `.mc-data/work/legacy-scan/` — POST-GATE re-run verbatim từ SKILL.md (absolute path), tự động xử lý đúng.

### D7: Status & Report Integrity

> Status file và report file có đủ thông tin, đúng schema.

| Check | Mô tả | Severity |
| ----- | ----- | -------- |
| D7.1 | Status file có fields: phase, status, verdict | MAJOR |
| D7.2 | Status verdict phản ánh thực tế (không "PASS" khi còn lỗi) | CRITICAL |
| D7.3 | Report file có error_log[] (nếu có lỗi trong quá trình chạy) | MINOR |
| D7.4 | Report file có output summary (files created, checks passed) | MINOR |
| D7.5 | Timestamps trong status file hợp lệ (không tương lai) | MINOR |

### D8: Master Plan Compliance (OPTIONAL)

> Kiểm tra output tuân thủ Master Optimization Plan — digest artifacts, executable specs, micro-task decomposition, stateful checkpoints. **CHỈ active khi Master Plan enabled.**
>
> **Detection:** Master Plan enabled khi ÍT NHẤT 1 trong 2 điều kiện:
> - `test -f .mc-data/work/shared-metrics/baseline-schema.json`
> - `test -f .mc-data/docs/_meta/project-digest.json` (output file thực tế, KHÔNG phải template)
>
> Nếu KHÔNG enabled → D8 hoàn toàn SKIP, không tính điểm, không ảnh hưởng verdict.
>
> **Anti-pattern:** KHÔNG check `.claude/doc-framework/_digests/*.template.json` — template files luôn tồn tại trong DEVKIT, gây false positive.
>
> **Scoring:** Khi enabled, D8 chiếm 10% tổng điểm. D1-D7 giảm proportionally (nhân 0.9).

| Check | Skill | Mô tả | Severity |
| ----- | ----- | ----- | -------- |
| D8.1 | `wf-brainstorm` | `project-digest.json` tồn tại tại `.mc-data/docs/_meta/` + non-empty | MAJOR |
| D8.2 | `wf-brainstorm` | `project-digest.json` có: `project_name`, `project_summary`, `departments`, `interface_type`, `tech_stack_summary` | MAJOR |
| D8.3 | `wf-analyze-requirements` | `dept-digests.json` tồn tại + non-empty | MAJOR |
| D8.4 | `wf-analyze-requirements` | `dept-digests.json` — mỗi dept có: `dept_name`, `dept_id`, `key_requirements`, `business_rules`, `priority_workflows` | MAJOR |
| D8.5 | `wf-analyze-requirements` | `phase1-handoff.json` tồn tại + non-empty | MAJOR |
| D8.6 | `wf-analyze-requirements` | `phase1-handoff.json` có: `key_decisions`, `scope_boundaries` | MAJOR |
| D8.7 | `wf-define-features` | `feature-briefs.json` tồn tại + non-empty | MAJOR |
| D8.8 | `wf-define-features` | Mỗi feature có: `feature_id`, `name`, `summary` (≤100 words), `acceptance_criteria` | MAJOR |
| D8.9 | `wf-design` | `design-input-digest.json` tồn tại + non-empty | MAJOR |
| D8.10 | `wf-design` | Có: `architecture_summary`, `tech_stack`, `api_summary` | MAJOR |
| D8.11 | `wf-design-ux` | `ux-input-digest.json` tồn tại + non-empty | MAJOR |
| D8.12 | `wf-design-ux` | Có: `design_system_summary`, `navigation_structure`, `responsive_strategy` | MAJOR |
| D8.13 | `wf-plan-modules` | Task files có section `A6-EXT` | MAJOR |
| D8.14 | `wf-plan-modules` | `A6-EXT` có: file paths, REQ-IDs, methods, test cases | MAJOR |
| D8.15 | `wf-plan-modules` | Task files có section `A7-EXT` (nếu feature ≥ 3 files trong A6-EXT) | MINOR |
| D8.16 | `wf-plan-modules` | `A7-EXT` micro-task: `MT-*` id, `estimated_time` ≤ 15 phút, input, output, success_criteria | MINOR |
| D8.17 | `wf-implement-feature` | Checkpoint có `context_digest` object | MAJOR |
| D8.18 | `wf-implement-feature` | `context_digest` có 6 subfields: `feature_summary`, `architectural_decisions`, `interfaces_established`, `patterns_in_use`, `cross_batch_contracts`, `gotchas_and_warnings` | MAJOR |

> **D8 chỉ kiểm tra checks LIÊN QUAN đến skill đang audit.** Ví dụ khi audit `wf-brainstorm`, chỉ chạy D8.1 + D8.2.
>
> **Backward compatibility:** Skills chạy TRƯỚC Master Plan enabled → SKIP (không FAIL), report ghi: "D8 SKIP — skill chạy trước Master Plan."

---

## 2. Skill Audit Lookup Table

| Skill | Registry Fields | Key Output Files | Template |
| ----- | --------------- | ---------------- | -------- |
| `wf-brainstorm` | `project`, `departments[]`, `interface_type` (initial seed) | `phase0-brainstorm/P0-*.md` | `doc-framework/phase0-brainstorm/` |
| `wf-analyze-requirements` | `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type` | `phase1-business/P1-*.md`, stakeholder-review | `doc-framework/phase1-business/` |
| `wf-define-features` | `features[]` | `phase2-features/[sys]/[mod]/[feat].md`, stakeholder-review, cross-validation-report | `doc-framework/phase2-features/` |
| `wf-design` | `design_status` | `phase3-architecture/P3-*.md`, `technical-specs/*.md`, stakeholder-review | `doc-framework/phase3-architecture/` |
| `wf-design-ux` | `ux_design_status` | `phase4-ux/*.md`, stakeholder-review | `doc-framework/phase4-ux/` |
| `wf-plan-modules` | `implementation_order` | `phase5-implementation/P5-*.md`, `tasks/[sys]/[mod]/[feat]-impl.md`, stakeholder-review | `doc-framework/phase5-implementation/` |
| `wf-implement-feature` | `impl_status` | Source code + test files | *(không có doc template)* |
| `wf-preflight` | *(không ghi registry)* | `work/wf-preflight/preflight-report.md` | *(inline)* |
| `wf-fix-bugs` | `impl_status` | `work/wf-fix-bugs/fix-report-[date].md` | *(inline)* |
| `wf-verify-sync` | `impl_status` (safe-update) | `docs/_meta/verify-sync.md` | *(inline)* |
| `wf-prepare-deployment` | *(không ghi registry)* | `phase6-deployment/*.md`, stakeholder-review | `doc-framework/phase6-deployment/` |
| Shared skills (legacy flow) | `systems[], modules[], departments[], requirements[], features[], interface_type, design_status` | Phase 0-3 docs, stakeholder-review stubs, `req-registry.json`, `work/legacy-scan/gap-report.md`, `gap-categories.json`, `action-items.json` | Multi-phase: `doc-framework/phase0-3/` contracts |
| `wf-design-ux` (legacy flow) | *(read-only)* | `docs/phase4-ux/existing-ui-analysis.md`, `design-tokens-baseline.md`, `[system]/screen-inventory.md` | `doc-framework/phase4-ux/` |

---

## 3. Registry Schema per Skill

### `wf-brainstorm` — initial seed

```json
{
  "project": { "name": "string", "description": "string" },
  "departments": ["DEPT-..."],
  "interface_type": "web | mobile | web+mobile | api-only"
}
```

> **Seed-only check:** D3 chỉ validate field existence + type, KHÔNG deep schema check.

```bash
jq '.project and .departments and .interface_type' registry.json  # = true
jq '.departments | type == "array" and .interface_type | type == "string"' registry.json  # = true
```

### `wf-analyze-requirements` — requirements[]

```json
{
  "id": "REQ-[DEPT]-[NNN]",
  "dept": "DEPT-[ID]",
  "title": "string",
  "description": "string",
  "priority": "HIGH|MEDIUM|LOW",
  "phase": "MVP|Phase2|Phase3",
  "status": "DRAFT|APPROVED",
  "systems": ["SYS-..."],
  "primary_module": "MOD-..."
}
```

> **Schema Guard:** Field names đúng: `dept`, `title`, `phase`, `status`, `systems`, `primary_module`. Optional: `description`, `source`, `impl_status` — không FAIL D3.3.
> Alias SAI: `department`, `source_file` → FAIL D3.3.

```bash
# D3.3: Field names sai
jq '[.requirements[] | select(has("department") or has("source_file"))] | length' registry.json  # = 0
# D3.5: Required fields
jq '[.requirements[] | select(.id == null or .dept == null or .title == null or .priority == null or .primary_module == null)] | length' registry.json  # = 0
# D3.5: systems[] là array
jq '[.requirements[] | select(.systems == null or (.systems | type) != "array")] | length' registry.json  # = 0
# D3.4: interface_type enum
jq '.interface_type | type == "string" and (. == "web" or . == "mobile" or . == "web+mobile" or . == "api-only")' registry.json  # = true
```

### `wf-define-features` — features[]

```json
{
  "id": "FEAT-SYS-MOD-NNN",
  "module_id": "MOD-SYS-MOD",
  "name": "string",
  "req_ids": ["REQ-..."],
  "priority": "HIGH|MEDIUM|LOW",
  "phase": 1,
  "dependencies": [],
  "file": "string",
  "cross_system": false
}
```

```bash
# D3.3: Field names
jq '[.features[] | keys[] | select(. == "feat_id" or . == "module" or . == "file_path" or . == "status" or . == "system")] | length' registry.json  # = 0
# D3.4: phase = number
jq '[.features[] | select(.phase | type != "number")] | length' registry.json  # = 0
# D3.5: dependencies = array
jq '[.features[] | select(.dependencies == null or (.dependencies | type) != "array")] | length' registry.json  # = 0
# D3.6: Duplicates
jq '[.features | group_by(.id) | .[] | select(length > 1) | .[0].id] | length' registry.json  # = 0
# D3.7: Count match
jq '.features | length' registry.json
# vs: find .mc-data/docs/phase2-features -name "*.md" -not -name "stakeholder*" -not -name "_*" | wc -l
```

### `wf-design` — design_status

```json
{ "design_status": "pending | in_progress | completed" }
```

### `wf-plan-modules` — implementation_order

```json
{
  "implementation_order": [
    { "order": 1, "module_id": "MOD-...", "dependencies": [...] }
  ]
}
```

```bash
jq '.implementation_order | type' registry.json  # = "array"
jq '[.implementation_order[] | select(.order == null or .module_id == null)] | length' registry.json  # = 0
```

> **Authoritative source:** Đọc SKILL.md của target skill, tìm section "Registry Update" hoặc POST-GATE checks có `jq` commands. Schema trên là reference — SKILL.md là nguồn chính.

### Shared skills (legacy flow)

> Khi chạy legacy flow, shared skills (wf-brainstorm, wf-analyze-requirements, wf-define-features, wf-design) ghi registry theo cùng Safe-Write rules như standard path. D3 checks áp dụng riêng per skill dựa trên fields của nó.

### `wf-design` (legacy — gap analysis)

> Gap analysis output là work reports, không ghi fields ngoài `design_status`. Output files (`gap-report.md`, `gap-categories.json`, `action-items.json`) nằm trong `work/legacy-scan/` — không có template, dùng fallback mode cho D2.

---

## 4. Phase → Contract Path Mapping

```
wf-brainstorm      → .claude/doc-framework/phase0-brainstorm/_contract.json
wf-analyze-req     → .claude/doc-framework/phase1-business/_contract.json
wf-define-features → .claude/doc-framework/phase2-features/_contract.json
wf-design          → .claude/doc-framework/phase3-architecture/_contract.json
wf-design-ux       → .claude/doc-framework/phase4-ux/_contract.json
wf-plan-modules    → .claude/doc-framework/phase5-implementation/_contract.json
wf-prepare-deploy  → .claude/doc-framework/phase6-deployment/_contract.json

Shared skills (legacy flow) — MULTI-PHASE (load 4 contracts):
  wf-brainstorm output (phase0-brainstorm/) → phase0-brainstorm/_contract.json
  wf-analyze-requirements (phase1-business/) → phase1-business/_contract.json
  wf-define-features (phase2-features/) → phase2-features/_contract.json
  wf-design (phase3-architecture/) → phase3-architecture/_contract.json

wf-design-ux (legacy flow) → phase4-ux/_contract.json
wf-design (legacy — gap analysis) → KHÔNG contract — skip D2.0, fallback grep
```

---

## 5. Fix Rules (Skill-specific Auto-Fix)

| Error Type | Auto-Fix Strategy | Escalate If |
| ---------- | ----------------- | ----------- |
| Registry field name sai (`feat_id` → `id`) | Rename theo alias table | Ambiguous mapping |
| Registry field type sai (`phase: "MVP"` → `1`) | Convert theo schema | Không biết mapping |
| File thiếu (report, stakeholder-review) | Tạo từ template + context | Không đủ context |
| Template section thiếu | Thêm section header + placeholder | Section cần expert input |
| Status file thiếu field | Thêm field với default | Field cần computed value |
| Cross-reference broken | Fix path nếu đổi tên, flag nếu xóa | Target không tồn tại |
| JSON invalid | Fix syntax (trailing comma, etc.) | Structure corruption |

**Auto-Fix Priority:**

```
1. D3 Registry schema (field names, types, missing) — ưu tiên cao nhất
2. D1 File thiếu (tạo từ template nếu có context)
3. D2 Template sections thiếu (thêm headers)
4. D7 Status file thiếu fields (thêm defaults)

KHÔNG BAO GIỜ auto-fix:
- D6 POST-GATE failures → phải re-run skill
- D4 Content quality thấp → phải re-run skill
- D5 Cross-phase scope mismatch → phải re-run phase trước
- D8 Digest/A6-EXT/A7-EXT/context_digest thiếu → phải re-run skill
```

---

## 6. Error Handling

| Code | Situation | Action |
| ---- | --------- | ------ |
| E001 | Skill chưa chạy (không có output) | STOP — "Skill [name] chưa có output. Chạy skill trước." |
| E002 | SKILL.md không tìm thấy | STOP — "Không tìm thấy SKILL.md cho [name]" |
| E003 | Registry không tồn tại | STOP — "req-registry.json không tồn tại. Chạy /wf-brainstorm trước." |
| E004 | Registry JSON invalid | Báo D3.1 FAIL, tiếp tục các dimensions khác |
| E005 | SKILL.md không có POST-GATE | Kiểm tra procedures/. Nếu thấy → chạy D6. Nếu không → Skip D6 = N/A |
| E006 | Auto-fix gặp lỗi không fix được | Log ESCALATED, tiếp tục |
| E007 | `--all` nhưng không có skill nào đã chạy | STOP — "Chưa có workflow skill nào đã chạy." |
| E008 | Dimension không hợp lệ (--dimension=D9) | WARN + ignore, chạy dimensions hợp lệ |
| E009 | File permission error khi fix | Retry 3 lần, sau đó ESCALATE |
| E010 | Output dir không tạo được | Fallback → hiển thị report inline |
| E011 | Subagent D4/D5 timeout/fail | Retry x1, sau đó skip dimension + WARNING |
| E012 | Subagent trả về sai format | Parse best-effort, flag WARN |
| E013 | User gọi `/audit-skill-output audit-skill-output` (self-audit) | STOP — "Không thể tự audit. Dùng `/audit-devkit`." |

### Best-Effort Parsing Rules (E012)

```
1. Tìm ---BEGIN-DX-RESULTS--- / ---END-DX-RESULTS--- markers
2. Nếu có BEGIN nhưng không có END → lấy từ BEGIN đến hết response
3. Nếu không có markers → tìm patterns: [D4.X], [D5.X], SCORE:, SUMMARY:, PASS/WARN/FAIL
4. Nếu không parse được gì hữu ích → skip dimension, ghi E012 WARNING
5. Content Score (D4.6): chỉ tính khi có SCORE: marker rõ ràng → nếu không → N/A
```

Khi parse best-effort, report PHẢI ghi: "DX format không chuẩn, kết quả có thể không đầy đủ."

---

## 7. Verdict Logic

| Điều kiện | Verdict |
| --------- | ------- |
| CRITICAL = 0, MAJOR = 0 | **PASS** — output chất lượng tốt |
| CRITICAL = 0, MAJOR > 0 | **PASS_WITH_WARN** — hoạt động được nhưng cần cải thiện |
| CRITICAL > 0 | **FAIL** — output có lỗi nghiêm trọng |

**Skipped dimensions:**
- Dimensions bị skip (--dimension filter, E011, SKIP conditions) → KHÔNG tính vào verdict.
- Report ghi rõ: "Verdict dựa trên [N]/7 dimensions" và list dimensions bị skip.
- Nếu CẢ D4 và D5 fail (E011):
  - **Structural CRITICAL > 0** → Verdict = **FAIL** (structural findings luôn ưu tiên)
  - **Structural CRITICAL = 0** → Verdict = **PASS_WITH_WARN** (semantic không xác minh được)
  - Report ghi: "Semantic audit không thể hoàn thành. Kết quả chỉ phản ánh structural checks."
- Khi dimension bị skip chứa CRITICAL checks (D4.2, D5.1, D5.3) → Report recommend user chạy lại với `--dimension=D4` hoặc `--dimension=D5`.

**Chế độ `--no-fix`:**
- Phase 2 bị SKIP → findings từ Phase 1+3 KHÔNG được fix.
- Verdict tính trên **unfixed findings**: CRITICAL > 0 → FAIL (kể cả CRITICAL từ D3 chưa fix).
- Report KHÔNG có "Fix Results" section. Status ghi `phases.phase_2.skipped = true, skip_reason = "--no-fix flag"`.
