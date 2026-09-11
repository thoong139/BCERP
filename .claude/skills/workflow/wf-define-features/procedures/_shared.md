# Shared Protocols — wf-define-features

> Cross-cutting protocols, state variables, agent templates, fix rules và reference data
> được sử dụng bởi nhiều Phase trong wf-define-features.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Phase → File Mapping](#phase--file-mapping)
- [Phase Ordering by Mode](#phase-ordering-by-mode)
- [Protocol 6.6 — Large Project Mode](#protocol-66--large-project-mode)
- [LEGACY_MODE Context Injection](#legacy_mode-context-injection)
- [Agent Context Templates](#agent-context-templates)
- [Stub Detection & Flesh-out Rules](#stub-detection--flesh-out-rules)
- [Scan Method Selection](#scan-method-selection)
- [Fix Rules](#fix-rules)
- [WARN Triage Decision](#warn-triage-decision)
- [Registry Schema — features[]](#registry-schema--features)
- [Field Name Aliases](#field-name-aliases)
- [Registry Safe-Write](#registry-safe-write)
- [Token Budget & Checkpoint](#token-budget--checkpoint)
- [Resume Reconciliation](#resume-reconciliation)
- [Content Quality Checks (CQG-07)](#content-quality-checks-cqg-07)
- [Error Codes](#error-codes)
- [Phase Summary Protocol (CORE-028)](#phase-summary-protocol-core-028)
- [Execution Trace Protocol (CORE-026)](#execution-trace-protocol-core-026)
- [Structured Error Log Protocol](#structured-error-log-protocol)
- [On Failure Template](#on-failure-template)
- [Output Report Template](#output-report-template)

---

## State Variables Glossary

Biến in-memory được set/đọc xuyên suốt skill execution. Phải persist vào `session-state.json.flags{}` khi có resume risk.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$LEGACY_MODE` | Phase 0 | 0.5, 2, 2.5, 2.7, ALL agent spawns | Boolean — true nếu `.mc-data/work/legacy-scan/project-context.md > 500 bytes` (CORE-021) |
| `$LEGACY_CONTEXT` | Phase 0 | ALL agent spawns | Nội dung `project-context.md` (LEGACY) |
| `$LEGACY_DECISIONS` | Phase 0 | 2, 5 | Nội dung `.mc-data/work/wf-brainstorm/legacy-decisions.json` — DEPRECATE modules, divergence resolutions, scope exclusions (CORE-022) |
| `$DEPRECATED_MODULES` | Phase 0 | 2, 5 | Array module IDs từ `legacy-decisions.json` action=DEPRECATE |
| `$REGISTRY_DATA` | Phase 0 | 1, 3, 5 | Parsed registry JSON (in-memory) |
| `$SESSION_DIR` | Phase 0 | ALL | Path session dir — `.mc-data/work/wf-define-features/sessions/{YYYYMMDD-HHMMSS}-{hash4}/` |
| `$SESSION_ID` | Phase 0 | ALL | Session identifier — `YYYYMMDD-HHMMSS-{hash4}` |
| `$LARGE_PROJECT` | Phase 0.5b | 1, 2, 3, 4, 5 | Boolean — true nếu LPM active (xem Protocol 6.6) |
| `$MAX_PARALLEL_AGENTS` | Phase 0.5b | 2, 4 | 5 (Standard) hoặc 3 (LPM) |
| `$WORKLOAD_ESTIMATE` | Phase 0.5 workload | 1, 2, 3 | WorkloadEstimate object từ `_shared/partition/workload_gate.py` |
| `$GATE_RESULT` | Phase 0.5 workload | 1, 2 | GateResult — `dead_zone` / `warn` / `block` |
| `$SCOPE` | Phase 1 | 2, 3, 4, 5 | `all` / `[system-name]` / `[module-name]` |
| `$FEAT_IDS` | Phase 1 | 2, 3, 5 | Array FEAT-ID đã được assign |
| `$IMPL_STATUS_MAP` | Phase 0.5 legacy-seed (LEGACY) | 5 | Map `{FEAT-ID → impl_status}` — done/in_progress/not_started — seed từ snapshot |
| `$STUB_FILES` | Phase 1 | 2 | Array phase2-features files có `status: stub` (từ `/wf-fix-bugs --deep`). PHẢI persist vào `session-state.json.flags.stub_files[]` sau Phase 1 để resume không mất thông tin stub. |
| `$HAS_SCREENS` | Phase 2.5 (check trước khi branch) | 2.7 | Boolean — true nếu `ui-manifest.json` tồn tại VÀ `total_screens > 0`. PHẢI persist vào `session-state.json.flags.has_screens`. Phase 2.5 set trước khi branch → phase2.7 / phase3. |
| `error_log[]` | All phases | 3, 4 | Array errors — dùng cho Auto-Correction Loop |

---

## Phase → File Mapping

| Phase | File | Vai trò |
|-------|------|---------|
| Phase 0 | `phase0-context.md` | Context loading, PRE-GATE registry + brainstorm, LEGACY detect, session init (ADR-OPT-02) |
| Phase 0.5 workload | `phase0.5-workload-gate.md` | Workload estimation + gate evaluation (ADR-OPT-03) — MỌI mode |
| Phase 0.5 impl-seed | `phase0.5-legacy-impl-seed.md` | Seed impl_status từ legacy scan (CHỈ LEGACY_MODE) |
| Phase 1 | `phase1-scope-mapping.md` | Scope parsing, FEAT-ID assignment, plan + briefs |
| Phase 2 | `phase2-create-specs.md` | Lane Dispatch per module, tạo feature specs (MAIN WORK, ADR-OPT-01) |
| Phase 2.5 | `phase2.5-feat-mapping.md` | Tạo feat-mapping.json (CHỈ LEGACY_MODE) |
| Phase 2.7 | `phase2.7-ui-coverage.md` | UI coverage cross-check (CHỈ LEGACY_MODE + có screens) |
| Phase 3 | `phase3-cross-validation.md` | Signal Aggregation + validation auto-correction loop (ADR-OPT-04) |
| Phase 4 | `phase4-stakeholder-review.md` | Parallel SO review (BA + product-expert) |
| Phase 5 | `phase5-registry-update.md` | Safe-Write features[], template strip + atomic write digest (ADR-OPT-05) |

---

## Phase Ordering by Mode

| Mode | Phases chạy | Mô tả |
|------|-------------|-------|
| **NEW** | 0 → 0.5-workload → 1 → 2 → 3 → 4 → 5 | Dự án mới hoàn toàn |
| **LEGACY** | 0 → 0.5-workload → 0.5-legacy-impl-seed → 1 → 2 → 2.5 → 2.7(S) → 3 → 4 → 5 | Dự án có sẵn |

> `(S)` = chỉ chạy nếu `$HAS_SCREENS = true` (ui-manifest tồn tại + total_screens > 0).

**Branching logic ở cuối mỗi phase file:**

- Phase 0 → (luôn) → `phase0.5-workload-gate.md`
- Phase 0.5 workload → nếu `$LEGACY_MODE` → `phase0.5-legacy-impl-seed.md`; không → `phase1-scope-mapping.md`
- Phase 0.5 legacy-seed → `phase1-scope-mapping.md`
- Phase 1 → `phase2-create-specs.md`
- Phase 2 → nếu `$LEGACY_MODE` → `phase2.5-feat-mapping.md`; không → `phase3-cross-validation.md`
- Phase 2.5 → `phase2.7-ui-coverage.md` (hoặc skip check bên trong phase)
- Phase 2.7 → `phase3-cross-validation.md`
- Phase 3 → `phase4-stakeholder-review.md`
- Phase 4 → `phase5-registry-update.md`
- Phase 5 → END (print Output Report)

---

## Session Isolation Protocol (ADR-OPT-02)

> Mỗi invocation của skill tạo session dir riêng — không ghi đè sessions cũ (CORE-030).

**Session dir structure:**

```
.mc-data/work/wf-define-features/sessions/{YYYYMMDD-HHMMSS}-{hash4}/
├── session-state.json        ← 3-level checkpoint state machine (PRIMARY)
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
```

**Latest pointer:** `.mc-data/work/wf-define-features/latest` — text file chứa path `$SESSION_DIR`.

**3-level checkpoint:**

| Level | Field | Granularity |
|-------|-------|-------------|
| L1 Phase | `session-state.json phases.P{N}.status` | Per phase |
| L2 Batch | `session-state.json phases.P{N}.batches[{K}].status` | Per module-batch |
| L3 Item | `session-state.json phases.P{N}.batches[{K}].items[{I}].status` | Per feat-item (optional) |

**Cleanup policy:** Giữ 5 sessions mới nhất per skill — xoá cũ nhất khi vượt quá.

---

## _shared Module Imports (ADR-OPT Integration)

> Procedure files reference các module Python trong `.claude/skills/workflow/_shared/` bằng convention `from {module} import {function}`.
> Không viết Python code trong procedure files — chỉ reference module + function name.

| Module | Dùng ở Phase | Functions chính |
|--------|-------------|-----------------|
| `_shared/lane/dispatcher.py` | Phase 2 (Lane Dispatch) | `dispatch_lanes(lanes, max_parallel, timeout_sec)` |
| `_shared/partition/planner.py` | Phase 0.5 workload | `plan_partitions(items, group_key, max_per_partition)` |
| `_shared/partition/workload_gate.py` | Phase 0.5 workload | `estimate_workload(partitions, est_minutes_per_item)`, `check_workload_gate(estimate, threshold_minutes)` |
| `_shared/aggregate/aggregator.py` | Phase 3 (Signal Aggregation) | `aggregate_lane_signals(lane_outputs, dedup_key_fn)` |
| `_shared/cache/cache_adapter.py` | Phase 0.5 workload | Cache module data (optional) |
| `_shared/cdg/cdg_handler.py` | Phase 0.5 workload (block gate) | CDG-A02 trigger khi override block |

> Xem `.claude/skills/workflow/_shared/README.md` §4-§5 cho module map đầy đủ.

---

## Protocol 6.6 — Large Project Mode

**Detection (tại Phase 0 Step 0.5b):**

```
$LARGE_PROJECT = (
  registry.systems.length >= 5 OR
  registry.departments.length >= 10 OR
  registry.requirements.length >= 50 OR
  registry.features.length >= 40
)
```

**LPM Overrides:**

| Setting | Standard | Large Project Mode |
|---------|----------|---------------------|
| `max_parallel_agents` | 5 | 3 |
| `compression_threshold` | > 3 input files | > 2 input files |
| `digest_size` | ~150 từ/dept | ~300 từ/dept (Extended) |
| `skeleton_threshold` | > 3000 từ output | > 2000 từ output |
| `checkpoint_frequency` | sau phases chính (1, 2, 3, 4, 5) | sau MỖI phase (0, 0.5, 1, 2 per-system, 2.7, 3, 4, 5) |
| Feature spec output target | ~800–1500 từ/feature | ~1500–3000 từ/feature |
| SO review output target (Phần B+C) | ~1000–1500 từ | ~1500–2500 từ |
| SO review output target (Phần D) | ~800–1200 từ | ~1200–1800 từ |

**Áp dụng:** Ghi `large_project_mode: true/false` vào `define-features-plan.md` + `define-features-status.json.flags.large_project`.

---

## LEGACY_MODE Context Injection

> Áp dụng cho TẤT CẢ agent spawns trong skill này (Phase 2, Phase 4).
> Mỗi lần spawn agent, nếu `$LEGACY_MODE = true` thì PHẢI thêm block sau vào prompt.

```
---
## PROJECT REFERENCE MATERIAL (Dự án cũ — tham chiếu)
[Nội dung project-context.md — Sections 1-6]

## Ý định của User
[Nội dung .mc-data/work/wf-brainstorm/user_intent.md]

## Quyết định Cấu Trúc Dự Án (legacy-decisions.json)
[Đọc .mc-data/work/wf-brainstorm/legacy-decisions.json]
- Modules DEPRECATE: [list] → KHÔNG spec feature cho các modules này
- Modules IMPROVE: spec feature với note "Improve existing — không viết từ đầu"
- Divergence resolutions: [list] → follow decision khi encounter conflict
- Scope exclusions: [list] → loại khỏi feature definitions

Hướng dẫn xử lý DEPRECATE:
- Gặp feature thuộc module DEPRECATE → skip + log "Feature skipped: module deprecated per user decision"
- impl_status của feature thuộc module DEPRECATE → set "skipped"

## Hướng dẫn sử dụng Reference Material:
- trust_level = HIGH → ưu tiên sử dụng
- trust_level = MEDIUM → kiểm chứng với code trước khi dùng
- trust_level = LOW → chỉ tham khảo
- Thiếu/sai → xây dựng từ best practices
- KHÔNG bị giới hạn bởi reference material — hãy CẢI THIỆN nếu cần
---
```

**Graceful degradation (CORE-022):** Nếu `legacy-decisions.json` không tồn tại → hiển thị cảnh báo, set `$DEPRECATED_MODULES = []`, tiếp tục không enforce scope exclusion.

---

## Agent Context Templates

### Template Business-Analyst Phase 2 (Feature Spec Creation, per feature)

```
Bạn là business-analyst. Tạo Feature Specification cho [feature-name].
Context: Module [FEAT-SYS-MOD-NNN], System [SYS-XXX] (target system), REQ-IDs: [list]
Lưu ý: Nếu REQ-IDs thuộc multi-system requirement (vd REQ-CX-001 cho cả web-customer và mobile-customer), đây là bản của feature dành RIÊNG cho system [SYS-XXX]. Cross-reference sibling features ở các systems khác có thể có cùng REQ-ID gốc nhưng UI/touchpoint khác biệt — hãy mô tả theo đặc thù touchpoint của [SYS-XXX] (web: responsive browser UI; mobile: offline-capable React Native; api-only: headless endpoint).

Input (BẮT BUỘC đọc trước khi viết):
- .mc-data/docs/_meta/req-registry.json (requirements[], modules[])
- .mc-data/work/wf-brainstorm/project-intent-digest.json (nếu tồn tại)
- .mc-data/work/wf-analyze-requirements/phase1-handoff.json (nếu tồn tại)
- .mc-data/work/wf-define-features/feature-briefs.json
- [NẾU CÓ DIGEST]: Dept digest đã được pre-compress (xem bên dưới). Chỉ đọc full file khi cần xác nhận chi tiết cụ thể.
- [NẾU KHÔNG CÓ DIGEST]: .mc-data/docs/phase1-business/departments/[dept]/[dept].md (Phần A + B)
- .mc-data/docs/phase1-business/P1-02-business-workflow.md
- .mc-data/work/wf-analyze-requirements/deferred-issues.md (nếu tồn tại)

[Dept digest — chỉ khi compression threshold áp dụng:]
[Paste digest ở đây — standard ~150 từ/dept, LPM ~300 từ/dept Extended — gồm: REQ-IDs, quy trình chính, điểm giao dept, vấn đề nổi bật]
Nếu cần chi tiết cụ thể từ dept doc → đọc file gốc tại path trên — CHỈ section cần thiết.

BẮT BUỘC — Template: .claude/doc-framework/phase2-features/[system-name]/[module-name]/[feature-name].md

9 sections bắt buộc: Heading → Metadata blockquotes → Bảng Thông Tin Chung →
Mô Tả Tính Năng → Luồng Người Dùng (User Stories) → Quy Tắc Nghiệp Vụ →
Phân Quyền → Trường Hợp Đặc Biệt → Tài Liệu Kỹ Thuật Liên Quan
(Optional sections: Trạng Thái & Chuyển Đổi — chỉ khi entity có state machine; Tóm Tắt Entity)

Nếu dept doc có mục A7 (Expert Review notes) → tóm tắt vào dòng "Ghi chú Expert (A7)" trong Bảng Thông Tin Chung.

NGÔN NGỮ: Viết tiếng Việt CÓ DẤU (Unicode) — section headings và nội dung PHẢI dùng dấu tiếng Việt như template
(vd: "Thông Tin Chung" KHÔNG PHẢI "Thong Tin Chung", "Luồng Người Dùng" KHÔNG PHẢI "Luong Nguoi Dung").

KHÔNG ĐƯỢC: YAML front-matter, gộp features, bỏ/thêm sections ngoài template.

Output: .mc-data/docs/phase2-features/[sys]/[mod]/[feature-name].md
Quality: Non-empty, REQ-IDs format REQ-[DEPT]-[NNN], FEAT-ID format FEAT-[SYS]-[MOD]-NNN, không có TODO/TBD
Output mục tiêu: standard ~800–1500 từ/feature, LPM ~1500–3000 từ/feature. Súc tích, đủ ý, không lặp context.

Tiêu chí thành công (POST-GATE): File output phải pass T1 (test -s non-empty) + T3 (đủ 9 sections, mỗi section ≥ 2 câu nội dung thực). Nếu không đạt → sẽ được gửi lại để sửa.
```

> **LEGACY_MODE:** Khi spawn, chèn thêm LEGACY_MODE Context Injection block (xem section trên) vào đầu prompt.
> **Stub flesh-out:** Nếu file target đã có frontmatter `status: stub` → prompt thêm: "File đã có stub — giữ `related_feature_id` nếu có, fill nội dung theo template, xoá `status: stub` khi xong."

### Template Business-Analyst Phase 4 (Stakeholder Review SO-01/02)

```
Bạn là business-analyst. Thực hiện Stakeholder Review cho Phase 2 Feature Specs.

Input:
- [NẾU CÓ DIGEST]: Feature digest đã được pre-compress (xem bên dưới). Chỉ đọc full feature file khi cần xác nhận chi tiết.
- [NẾU KHÔNG CÓ DIGEST]: Đọc trực tiếp tất cả feature specs + registry + dept docs
- .mc-data/docs/_meta/req-registry.json (requirements[], features[])
- .mc-data/docs/phase2-features/**/*.md (feature specs)
- .mc-data/docs/phase1-business/departments/[dept]/[dept].md

[Feature digest — chỉ khi compression threshold áp dụng:]
[Paste digest ở đây — ~100 từ/feature, gồm: FEAT-ID, REQ-IDs mapped, key BRs, permissions]
Nếu cần chi tiết cụ thể → đọc file gốc tại path — CHỈ section cần thiết.

Tasks:
1. Phần B (SO-01): REQ→FEAT Coverage — mỗi REQ-ID có feature spec? Mỗi feature có đủ user stories?
2. Phần C (SO-02): Consistency Check — entities nhất quán, permissions nhất quán, terminology nhất quán

BẮT BUỘC — Template: Đọc và tuân thủ CHÍNH XÁC cấu trúc từ:
`.claude/doc-framework/phase2-features/stakeholder-review.md` (Phần B và Phần C)

Output: `.mc-data/work/wf-define-features/_tmp-so-bc.md` (KHÔNG ghi trực tiếp vào stakeholder-review.md)
Quality: Actionable findings, severity (Critical/High/Medium/Low), No TODO/TBD, đúng template
Output mục tiêu: standard ~1000–1500 từ, LPM ~1500–2500 từ. Súc tích, đủ ý, không lặp context đã biết.

Tiêu chí thành công (POST-GATE): Output phải có đủ Phần B (REQ→FEAT Coverage) và Phần C (Consistency Check), mỗi phần có ≥ 1 finding. Nếu thiếu phần → sẽ được gửi lại để bổ sung.
```

### Template Product-Expert Phase 4 (Gap Analysis SO-03)

```
Bạn là product-expert. Thực hiện Gap Analysis cho Phase 2 Feature Specs.

Input:
- [NẾU CÓ DIGEST]: Feature digest đã được pre-compress (xem bên dưới). Chỉ đọc full feature file khi cần xác nhận chi tiết.
- [NẾU KHÔNG CÓ DIGEST]: Đọc trực tiếp tất cả feature specs + registry + dept docs
- .mc-data/docs/_meta/req-registry.json (requirements[], features[])
- .mc-data/docs/phase2-features/**/*.md (feature specs)
- .mc-data/docs/phase1-business/departments/[dept]/[dept].md

[Feature digest — chỉ khi compression threshold áp dụng:]
[Paste digest ở đây]
Nếu cần chi tiết cụ thể → đọc file gốc tại path — CHỈ section cần thiết.

Tasks:
1. Phần D (SO-03): Gap Analysis — features còn thiếu, user stories bị bỏ sót, BRs chưa được đặc tả

BẮT BUỘC — Template: Đọc và tuân thủ CHÍNH XÁC cấu trúc từ:
`.claude/doc-framework/phase2-features/stakeholder-review.md` (Phần D)

Output: `.mc-data/work/wf-define-features/_tmp-so-d.md` (KHÔNG ghi trực tiếp vào stakeholder-review.md)
Quality: Actionable findings, severity (Critical/High/Medium/Low), No TODO/TBD, đúng template
Output mục tiêu: standard ~800–1200 từ, LPM ~1200–1800 từ. Súc tích, đủ ý, không lặp context đã biết.

Tiêu chí thành công (POST-GATE): Output phải có đủ Phần D (Gap Analysis) với ≥ 1 finding. Nếu thiếu → sẽ được gửi lại để bổ sung.
```

> **Subagent context fallback:** Nếu Agent tool không khả dụng (đang chạy trong subagent context): thực hiện role inline — đọc templates từ `.claude/doc-framework/`, tạo/update files trực tiếp. Ghi chú vào transcript: "[role] executed inline (no Agent tool)."

---

## Stub Detection & Flesh-out Rules

> Áp dụng khi phát hiện files trong `phase2-features/` có frontmatter `status: stub` (từ `/wf-fix-bugs --deep` hoặc `/wf-add-scope`).

**Detection (Phase 1 Step 1.5 — sau khi tạo plan):**

```bash
grep -l "^status: stub" .mc-data/docs/phase2-features/**/*.md 2>/dev/null
```

**Behavior:**
- Hiển thị: "Found N stub files from deep scan/add-scope. These will be fleshed-out during Phase 2."
- Ghi vào `$STUB_FILES`.
- Phase 2 step "spawn BA": TRƯỚC KHI spawn → check nếu file target thuộc `$STUB_FILES` → prompt thêm instruction flesh-out:
  - Fill content theo template (9 sections)
  - Giữ `related_feature_id` nếu có trong frontmatter
  - XÓA `status: stub` khỏi frontmatter khi content đầy đủ

**Phase 3 cross-validation interaction:** Stubs còn `status: stub` sau Phase 2 → đánh dấu "awaiting flesh-out" trong cross-validation-report, KHÔNG auto-fix content (chỉ validate metadata).

---

## Scan Method Selection

Dùng cho Phase 3 Cross-Validation (check 3.4 section completeness).

**Lựa chọn A — Full Grep Scan (khuyến nghị khi ≤ 20 features):**

```bash
# Check 3.4: 9 sections bắt buộc phải có mặt trong tất cả feature files
grep -rl "## Quy Tắc Nghiệp Vụ" .mc-data/docs/phase2-features/ --include="*.md" | grep -v stakeholder-review | wc -l
grep -rl "## Luồng Người Dùng" .mc-data/docs/phase2-features/ --include="*.md" | grep -v stakeholder-review | wc -l
grep -rl "## Phân Quyền" .mc-data/docs/phase2-features/ --include="*.md" | grep -v stakeholder-review | wc -l
# Mỗi lệnh phải trả về số bằng tổng số features
```

**Lựa chọn B — Sampling (khi > 20 features và token budget tight):**

- Random sample ≥ 50% features (min 10 files)
- Phân bố đều: ít nhất 1 file/system
- BẮT BUỘC ghi rõ trong cross-validation-report: `Sampling-based: [N]/[total] files ([%])`

> Spot-check tùy ý < 30% là KHÔNG chấp nhận được — phải sử dụng Lựa chọn A hoặc B.

---

## Fix Rules

### Phase 3 Cross-Validation Fix Rules

| Loại lỗi | Auto-Fix |
|----------|----------|
| `missing_req_ref` | Tìm feature spec phù hợp nhất → thêm REQ-ID reference |
| `duplicate_feat_id` | Gán FEAT-ID mới, cập nhật references trong file |
| `orphan_feature` | Link với REQ-ID gần nhất theo module context |
| `empty_section` | Điền section từ registry/dept doc context |
| `missing_business_rule` | Extract từ dept doc → thêm vào Quy Tắc Nghiệp Vụ |
| `permission_inconsistency` | Chuẩn hóa theo permission matrix của module |
| `scope_expansion` | Xoá feature không có REQ-ID gốc, hoặc escalate nếu không rõ nguồn gốc |
| `thin_section` | Điền thêm nội dung từ dept doc/registry cho section < 2 câu |

### Phase 4 Stakeholder Review Fix Rules

| Loại Finding | Ví dụ | Auto-Fix? | Strategy |
|--------------|-------|-----------|----------|
| Missing user story | Actor/goal/outcome chưa được mô tả | ✅ | Thêm user story từ REQ-ID context |
| Missing business rule | Điều kiện validation chưa được đặc tả | ✅ | Extract từ dept doc → thêm vào BR section |
| Terminology inconsistency | Tên entity không đồng nhất | ✅ | Chuẩn hoá theo registry terminology |
| Permission gap | Role chưa được định nghĩa trong feature | ✅ | Thêm role vào permission matrix |
| Missing feature | REQ-ID không có feature spec nào | ✅ | Tạo feature spec stub từ context |
| Complex domain gap | NFR, scalability, compliance spec | ❌ | → DEFERRED cho `/wf-design` |
| Architectural decision | Cross-system integration spec | ❌ | → DEFERRED cho `/wf-design` |

### Overall SKILL-level Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|------------|-------------------|-------------|
| `missing_feature_file` | Tạo lại từ feature brief + registry + dept docs | Context nguồn không đủ |
| `duplicate_feat_id` | Gán lại FEAT-ID và cập nhật tham chiếu | Trùng lặp lan rộng nhiều module |
| `coverage_gap` | Bổ sung feature hoặc thêm REQ mapping đúng nguồn | Không xác định được REQ gốc |
| `stakeholder_review_gap` | Auto-fix source spec rồi regenerate phần review liên quan | Còn Critical/High sau 3 vòng |

---

## WARN Triage Decision

> **BẮT BUỘC phân loại sau mỗi iteration — trước khi kết thúc Phase 3:**
>
> Nguyên tắc: NẾU resolve bằng (Read + Edit) hoặc (Read + xác nhận no-fix-needed) trong < 5 phút → AUTO-FIX NGAY, không defer.
> Chỉ defer khi cần: (a) stakeholder decision, (b) Architect design, hoặc (c) file không tồn tại.

| WARN type | Điều kiện Auto-Fix | Điều kiện Defer |
|-----------|--------------------|-----------------|
| File reference inconsistency (WARN-CS) | Chỉnh sửa notation trong 1–2 files — AUTO-FIX NGAY | Nếu cần Architect review pattern toàn hệ thống |
| File content unverified (WARN-CS style) | Đọc file → verify/chỉnh FEAT-ID — AUTO-FIX NGAY | Nếu file không tồn tại |
| Deferred issue PARTIAL (DI-NNN) | Đọc section cụ thể trong file target — AUTO-VERIFY + kết luận PASS/FAIL NGAY | Nếu cần stakeholder confirm nội dung |
| De-dup cross-reference missing | Thêm cross-reference vào BR section — AUTO-FIX NGAY | Nếu cần Architect quyết định de-dup strategy |
| Architecture SSOT ownership | → DEFER luôn — cần Architect confirm | Always defer |
| Notification/event routing | → DEFER — cần Phase 3 design decision | Always defer |

---

## Registry Schema — features[]

Schema chuẩn cho entries trong `features[]` (dùng khi extract + Schema Guard Phase 5.3b):

```json
{
  "id": "FEAT-CRM-CUST-001",
  "module_id": "MOD-CRM-CUST",
  "name": "Quan ly thong tin khach hang",
  "req_ids": ["REQ-SALES-001"],
  "priority": "HIGH",
  "phase": 1,
  "dependencies": ["FEAT-CRM-CUST-001"],
  "file": "phase2-features/crm/customer-management/quan-ly-thong-tin-khach-hang.md",
  "impl_status": "not_started",
  "cross_system": ["SYS-MOB"]
}
```

| Field | Bắt buộc | Mô tả |
|-------|----------|-------|
| `id` | CÓ | FEAT-ID đúng format `FEAT-[SYS]-[MOD]-NNN` |
| `module_id` | CÓ | MOD-ID từ registry modules[] |
| `name` | CÓ | Tên tính năng (tiếng Việt không dấu) |
| `req_ids` | CÓ | Danh sách REQ-IDs được map |
| `priority` | CÓ | HIGH / MEDIUM / LOW (lấy từ REQ priority cao nhất) |
| `phase` | CÓ | Giai đoạn triển khai: HIGH priority → 1, MEDIUM → 2, LOW → 3 |
| `dependencies` | CÓ | FEAT-IDs phải hoàn thành trước ([] nếu không có) |
| `file` | CÓ | Relative path từ .mc-data/docs/ |
| `impl_status` | CÓ | one of: `not_started` (default), `in_progress`, `done`, `skipped`. Legacy: seed từ Phase 0.5. DEPRECATE modules: `skipped` |
| `cross_system` | KHÔNG | Chỉ khi feature liên quan đến system khác |

---

## Field Name Aliases

**SAI → ĐÚNG — auto-rename nếu gặp:**

| Sai (KHÔNG dùng) | Đúng (PHẢI dùng) | Ghi chú |
|------------------|------------------|---------|
| `feat_id` | `id` | Sai prefix |
| `module` | `module_id` | Thiếu `_id` suffix |
| `file_path` | `file` | Sai tên |
| `system` | *(không có trong schema)* | Xoá — thông tin đã có trong `id` prefix |
| `status` | `impl_status` | Rename → `impl_status` (BẮT BUỘC — 4 giá trị: not_started/in_progress/done/skipped) |
| `"MVP"` / `"PHASE_2"` (string) | `1` / `2` / `3` (number) | `phase` PHẢI là number: HIGH→1, MEDIUM→2, LOW→3 |

> **BẮT BUỘC:** Nếu extract từ feature docs trả về sai field names → RENAME theo bảng trên TRƯỚC KHI ghi vào registry.
> Nếu thiếu `dependencies` → thêm `[]` (mảng rỗng).

---

## Registry Safe-Write

> Áp dụng cho mọi lần ghi registry trong skill này (Phase 5 only).

```
1. ĐỌC registry NGAY TRƯỚC KHI GHI — không cache từ đầu session
2. CHỈ MODIFY features[] + impl_status (per REQ-ID) — giữ nguyên systems[], modules[], departments[], requirements[], interface_type, design_status, ux_design_status, implementation_order
3. APPEND-ONLY cho features[]: thêm entries mới, upsert by id, không modify/delete existing
4. impl_status: chỉ set "skipped" cho features thuộc DEPRECATED modules
5. GHI ATOMIC — ghi vào temp file trước, rồi rename:
   WRITE → `.mc-data/docs/_meta/req-registry.json.tmp` → validate `jq '.'` → RENAME → `req-registry.json`
6. VALIDATE sau ghi — `jq '.' registry.json` phải pass
```

**Fields được phép update:** `features[]`, `impl_status` (per REQ-ID, chỉ "skipped" cho DEPRECATE).

**Fields TUYỆT ĐỐI KHÔNG modify:** `systems[]`, `modules[]`, `departments[]`, `interface_type`, `design_status`, `ux_design_status`, `implementation_order`.

### Exception: `requirements[]` APPEND-ONLY (v3.1+ — narrow exception, opt-in via flag)

> **Lý do:** Khi `features[].req_ids[]` reference REQ-IDs không tồn tại trong `requirements[]`
> (root cause Finding #1 từ wf-implement-feature E2E test 2026-04-28), wf-define-features
> cần option để auto-create stub requirement entries → tránh để bug propagate xuống
> wf-implement-feature. PRIMARY của `requirements[]` vẫn là wf-analyze-requirements —
> exception này chỉ APPEND stubs có flag `auto_generated_by`, không modify/delete existing.

**Quy tắc Exception:**

1. **Opt-in BẮT BUỘC** — chỉ áp dụng khi user truyền flag `--auto-stub-requirements`. Default behavior là BLOCK (E020) — buộc user fix qua wf-analyze-requirements / wf-manage-change.
2. **APPEND ONLY** — chỉ thêm entries mới với `req_id` chưa tồn tại trong `requirements[]`. KHÔNG modify/delete existing entries.
3. **Mỗi stub PHẢI có flag tracking:**
   - `auto_generated_by: "wf-define-features"`
   - `needs_user_review: true`
   - `source: "auto-generated"`
   - `created_at: <ISO timestamp>`
   - `referenced_by: [<FEAT-IDs reference REQ-ID này>]`
4. **Description derive từ feature** — `feature.title + ". " + (feature.notes hoặc feature.acceptance_criteria join)`. KHÔNG đoán bừa.
5. **Default `priority: "P2"`** — user phải xác nhận lại qua `/wf-manage-change CLARIFY_REQ` hoặc `/wf-analyze-requirements --refine-req=<X>`.
6. **Downstream propagation** — sau khi append stub, `wf-design`/`wf-implement-feature` đọc registry sẽ tìm thấy entry, KHÔNG fallback. Nhưng `needs_user_review: true` flag báo các skill này log warning về quality.

**CORE-006 Update:** §4a Safe-Write Protocol bảng cần thêm row:
```
| /wf-define-features | requirements[] (stubs only) | APPEND | Chỉ append entries với auto_generated_by="wf-define-features" + needs_user_review=true. Opt-in qua flag --auto-stub-requirements. Narrow exception cho referential integrity (E020 alternative path). |
```

---

## Phase Summary Protocol (CORE-028)

> **BẮT BUỘC** — mỗi phase PHẢI tạo `phase-summary.md` trước khi chuyển sang phase tiếp theo.

**Template:** `.claude/doc-framework/_meta/phase-summary.template.md`
**Output:** `$SESSION_DIR/phase-summary.md` (overwrite mỗi phase trong cùng session)

**Nội dung (tiếng Việt, ≤15 dòng, non-specialist):**

1. Phase ID + tên phase
2. Trạng thái: HOÀN THÀNH / HOÀN THÀNH CÓ LƯU Ý / THẤT BẠI
3. Số lượng items xử lý (files created/updated, errors found, etc.)
4. Findings chính (nếu có)
5. Bước tiếp theo

**Pattern (thêm vào cuối mỗi phase, trước "Next phase"):**

```
## Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id, status, items_processed, key_findings, next_action
3. WRITE atomic: `$SESSION_DIR/phase-summary.md`
```

---

## Execution Trace Protocol (CORE-026)

> **BẮT BUỘC** — mỗi phase ghi START/COMPLETE/FAIL vào session-log.json (append-only).
> KHÔNG Read toàn bộ file — chỉ append.

**File:** `.mc-data/work/_trace/session-log.json`
**Template:** `.claude/doc-framework/_meta/session-log.template.json`

**Format mỗi entry (Protocol 15):**

```json
{
  "timestamp": "ISO-8601",
  "skill": "wf-define-features",
  "phase": "phase-X-name",
  "event": "START|COMPLETE|FAIL",
  "details": { "key": "value" }
}
```

**Pattern (thêm vào mỗi phase):**

- **Đầu phase** (sau PRE-GATE): Append START entry vào session-log.json
- **Cuối phase** (trước "Next phase"): Append COMPLETE entry (hoặc FAIL nếu POST-GATE fail)
- **Lỗi không recoverable**: Append FAIL entry + STOP

---

## Structured Error Log Protocol

> Thêm structured entries vào `define-features-status.json` error_log[] khi gặp lỗi.

**Format mỗi entry:**

```json
{
  "phase": "phase-X-name",
  "error_code": "EXXX",
  "message": "mô tả lỗi bằng tiếng Việt",
  "timestamp": "ISO-8601",
  "resolution": "auto-fix|retry|escalated|deferred"
}
```

**Pattern (khi gặp lỗi trong bất kỳ phase nào):**

1. Append entry vào `define-features-status.json.error_log[]`
2. Nếu `resolution = "auto-fix"` → thực hiện fix → retry POST-GATE
3. Nếu `resolution = "escalated"` → STOP + in chi tiết cho user

---

## On Failure Template

> Mỗi phase phải có section "### Khi Thất Bại" định nghĩa xử lý khi fail.

**Template (thêm trước "Next phase" trong mỗi phase file):**

```markdown
### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| Retryable error (E003, E004, E006, E007) | Retry ≤ 3 lần, ghi error_log, append session-log FAIL |
| Max retry reached | STOP + báo cáo findings → user quyết định |
| Non-retryable error (E000, E001, E008, E009) | STOP ngay + hướng dẫn user |
| Auto-fix regression (E010) | Rollback fix → escalate với context |
```

---

## Token Budget & Checkpoint

### Token Threshold (Protocol 9 — PLN-03)

| Context usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| ≥ 65% | Ưu tiên finish batch hiện tại → SAVE CHECKPOINT → dừng session |
| ≥ 80% | KHÔNG spawn thêm agent |
| ≥ 90% | FORCE STOP |

### Checkpoint Creation (Template Usage Rule)

**Primary checkpoint (session-state.json):**

```
1. READ template: .claude/skills/workflow/_shared/templates/session-state.json
2. FILL: phases.P{N}.status, phases.P{N}.batches[].status (L2), next_action,
         workload_estimate, gate_result, user_decision, lanes_completed[]
3. WRITE atomic: $SESSION_DIR/session-state.json
```

**Legacy checkpoint (backward-compat — dual write):**

```
1. READ template: .claude/skills/workflow/wf-define-features/templates/checkpoint.json
2. FILL: position.current_phase, position.next_phase, progress.phases_completed,
         progress.files_completed, feat_id_state, coverage_state, validation_state,
         systems_state, next_action, resume_instructions
3. WRITE atomic: $SESSION_DIR/checkpoint.json
```

**SAVE CHECKPOINT** = cập nhật cả hai files (dual write). Đọc từ session-state.json khi resume.

### Checkpoint Frequency

- **Standard:** checkpoint sau Phase 1 (bắt buộc), sau mỗi system ở Phase 2, sau Phase 3, sau Phase 4, sau Phase 5
- **LPM (Protocol 6.6 LPM-05):** checkpoint sau MỖI phase (0, 0.5-workload, 0.5-legacy-seed, 1, 2 per-system, 2.7, 3, 4, 5)

---

## Resume Reconciliation

Sau khi load checkpoint ở Phase 0 (khi `--resume`):

```bash
# Đếm files thực tế trên disk
actual_files=$(find .mc-data/docs/phase2-features/ -name "*.md" ! -name "stakeholder-review.md" | wc -l)
```

- So sánh `actual_files` với `checkpoint.features_completed` (từ `define-features-plan.md`).
- Xác định:
  - `actual_completed` = số FEAT-ID đã có file non-empty trên disk
  - `first_incomplete_batch` = batch đầu tiên còn thiếu ít nhất 1 file
- Nếu `actual_completed != checkpoint.features_completed` → cập nhật checkpoint:
  - `features_completed = actual_completed`
  - `current_batch = first_incomplete_batch`
- Log: "Reconciled: tìm thấy [N]/[total] file trên disk — tiếp tục từ batch [B]"

---

## Content Quality Checks (CQG-07)

Chạy sau Phase 5 registry write:

```
1. TRACEABILITY: Mỗi FEAT-ID trong registry có ít nhất 1 REQ-ID mapped (features[].req_ids.length >= 1)
2. CONSISTENCY: features[] count trong registry = số actual feature files trong phase2-features/
   (đếm files *.md, loại trừ stakeholder-review.md và _index.md)
3. NẾU FAIL: Auto-fix — bổ sung missing mappings từ context, tạo missing feature files, hoặc xoá orphan entries
```

---

## Error Codes

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E000 | `req-registry.json` không tìm thấy | STOP → chạy `/wf-brainstorm` trước |
| E001 | `requirements[]` rỗng trong registry | STOP → chạy `/wf-analyze-requirements` trước |
| E002 | Scope argument không hợp lệ | Dùng default `all` + log warning |
| E003 | Feature spec file không tạo được | Retry affected phase (max 3x) |
| E004 | Agent timeout | Retry, hoặc spawn agent với context nhỏ hơn |
| E005 | FEAT-ID trùng lặp sau assignment | Re-run Phase 1 FEAT-ID mapping |
| E006 | Registry JSON invalid sau write | Fix JSON syntax, retry Phase 5 |
| E007 | Cross-validation mismatch (Phase 3) | Auto-fix loop (max 3 iterations) → escalate nếu vẫn fail |
| E008 | Stakeholder review Critical/High PENDING sau 3 iterations (Phase 4) | STOP + báo cáo findings → user quyết định |
| E009 | POST-GATE fail sau 3 retries | STOP — báo cáo chi tiết → user quyết định |
| E010 | Auto-fix gây regression (lỗi mới) | Rollback fix → escalate với context |
| E011 | Registry features[] schema sai field names (vd: `feat_id` thay vì `id`, thiếu `dependencies`) | Quay lại step 5.3b — rename fields theo bảng Field Name Aliases, retry Phase 5 |
| E012 | Per-system feature coverage FAIL — có system phase=MVP với 0 features (trong khi `/wf-analyze-requirements` đã verify REQ coverage) | STOP → rerun Phase 1 scope-mapping với fan-out đúng. Kiểm tra `requirements[].systems[]` đã được wf-analyze-requirements set chưa. Nếu không → rerun `/wf-analyze-requirements` trước |
| E020 | Referential Integrity Failure (v3.1+) — `features[].req_ids[]` reference REQ-IDs không tồn tại trong `requirements[]` | STOP → 3 lựa chọn: (a) chạy lại với `--auto-stub-requirements` để auto-create stubs (cần user review); (b) chạy `/wf-analyze-requirements` để bổ sung requirement entries thật; (c) chạy `/wf-manage-change CLARIFY_REQ` để add missing entries. Output `$SESSION_DIR/referential-integrity-violations.json` để debug. Root cause Finding #1 từ wf-implement-feature E2E — phải block ở wf-define-features để wf-implement-feature không gặp inconsistency |

---

## Output Report Template

ALWAYS dùng template này khi hoàn thành (sau Phase 5):

**Trước khi in report:** Cập nhật `define-features-status.json`:
- `status = "completed"`
- `progress_pct = 100`
- `timestamps.completed_at = <ISO timestamp>`
- Tất cả phases chưa được đánh dấu → `status = "completed"`

```markdown
## Define Features hoàn tất!

| Scope | [scope] | Systems | [count] |
|-------|---------|---------|---------|

### Kết quả
| Mục | Số lượng |
|-----|---------|
| Feature files tạo mới | [count] |
| FEAT-IDs đăng ký | [count] |
| REQ-IDs đã map | [count] |
| Feature briefs | `.mc-data/work/wf-define-features/feature-briefs.json` |
| Validation iterations | [N] |
| Findings RESOLVED | [count] |
| Findings DEFERRED | [count] |

**Stakeholder Review:** [APPROVED / APPROVED_WITH_CONDITIONS]

[Nếu LEGACY_MODE và có screens:]
### UI Coverage
| Mục | Giá trị |
|-----|---------|
| Tổng UI screens | [total_screens] |
| Screens đã cover | [covered] ([coverage_pct]%) |
| UI gaps | [gaps count] |
| Report | `.mc-data/work/wf-define-features/ui-coverage-gaps.json` |

**Next:** `/wf-design` để thiết kế architecture
```
