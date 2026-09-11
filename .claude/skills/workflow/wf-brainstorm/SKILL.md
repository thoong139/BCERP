---
name: wf-brainstorm
version: 8.1.0
last_updated: 2026-04-19
description: |
  Entry point của DEVKIT workflow — Chốt khung dự án và tạo tài liệu Phase 0 (P0-01-brainstorm.md, P0-02-systems-users.md).
  Hỗ trợ cả dự án mới (interactive conversation) và dự án có sẵn (legacy — đọc từ extracted data).
  Tự động phát hiện loại dự án và load flow phù hợp.

  LUÔN dùng skill này ngay khi user:
  - Muốn xây dựng app/phần mềm/hệ thống/nền tảng/website mới (bất kể quy mô hay ngành nghề)
  - Mô tả pain point cần giải quyết bằng phần mềm: "đang dùng Excel", "thủ công", "lộn xộn", "không đồng bộ", "cần giải pháp số"
  - Muốn số hóa (digitalize) quy trình kinh doanh: bán hàng, kho, nhân sự, kế toán, vận hành, giao nhận
  - Nhắc đến loại phần mềm cần xây dựng hoặc triển khai: ERP, CRM, WMS, HRM, POS, MES, EMR, LMS, TMS, SaaS, marketplace
  - Có ý tưởng startup/sản phẩm: "có ý tưởng về", "muốn làm", "đang nghĩ đến", "chưa biết bắt đầu từ đâu"
  - Mô tả bối cảnh doanh nghiệp cần phần mềm: chuỗi cửa hàng, phòng khám, trường học, công ty XNK, startup, SME
  - Gọi lệnh trực tiếp: /wf-brainstorm [tên-dự-án]
  - Đã chạy /wf-legacy-extract xong và cần tạo Phase 0 docs cho dự án có sẵn

  KHÔNG trigger khi: đã có requirements/features/spec sẵn sàng, đang implement code, fix bug, review PR, hỏi kiến thức thuần túy (VD: "ERP là gì"), hoặc brainstorm đã xong và đang hỏi bước tiếp theo.

argument-hint: "[project-name] [--force] (optional)"
disable-model-invocation: true
allowed-tools: Write, Read, Bash, Glob, TodoWrite, Agent, AskUserQuestion
---

# /wf-brainstorm: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Entry point — chốt khung dự án và tạo Phase 0 docs (P0-01, P0-02) |
| **Prerequisites** | Không có (entry point của workflow) |
| **Duration** | Conversational (15-30 min) |
| **Phases** | Phase 0: Auto-Detection → Load phase files (procedures/phaseN-*.md) theo pipeline tuyến tính |
| **Input** | Mô tả ý tưởng dự án (hoặc extracted data từ `/wf-legacy-extract`) |
| **Output** | `phase0-brainstorm/P0-01-brainstorm.md`, `P0-02-systems-users.md` |

### Workflow Position

```
[new project] → /wf-brainstorm ← YOU ARE HERE → /wf-analyze-requirements
[legacy]      → /wf-legacy-extract → /wf-brainstorm
```

---

## Phase 0: Auto-Detection & Routing (BẮT BUỘC — chạy trước tiên)

> Tự động phát hiện loại dự án và inject context phù hợp.
> Skill này chia thành nhiều phase files (procedures/phaseN-*.md) để giảm context per-phase.
> Pipeline tuyến tính: mỗi phase đọc file kế tiếp khi POST-GATE PASS.

**Bước 1 — Load `procedures/phase0-detect-route.md` ngay:**

```
Tool: Read
  file_path: .claude/skills/workflow/wf-brainstorm/procedures/phase0-detect-route.md
```

File này thực hiện:
- Detect LEGACY_MODE theo CORE-021 (check `.mc-data/work/legacy-scan/project-context.md` > 500 bytes)
- Set `$PROJECT_TYPE` (NEW/LEGACY) và `$LEGACY_CONTEXT`
- Parse `$ARGUMENTS` (project_name, --force)
- Route đến phase file kế tiếp theo bảng dưới

### Phase File Map (Pipeline Tuyến Tính)

| Phase File | Vai trò | Điều kiện chạy |
|------------|--------|----------------|
| `procedures/_shared.md` | Protocols + reference tables (load section khi cần) | Tham chiếu — không thực thi |
| `procedures/phase0-detect-route.md` | Auto-detect NEW/LEGACY + parse args | LUÔN — entry point |
| `procedures/phase0-5-legacy-snapshot.md` | Legacy snapshot, user intent, tạo legacy-decisions.json | CHỈ khi `LEGACY_MODE = true` |
| `procedures/phase1-collect-basic.md` | 4 câu hỏi cơ bản + init brainstorm-status.json | LUÔN |
| `procedures/phase2-ba-departments.md` | BA + departments + complexity + policy survey | LUÔN |
| `procedures/phase3-brainstorm-policy.md` | Spawn experts PARALLEL + tổng hợp + policy gap | LUÔN |
| `procedures/phase4-write-docs.md` | Soạn & ghi P0-01, P0-02, policies + cross-check | LUÔN |
| `procedures/phase5-init-registry.md` | Seed req-registry.json + project-intent-digest.json | LUÔN |
| `procedures/phase6-generate-digest.md` | Sinh project-digest.json + finalize status | LUÔN |

> **Hand-off rule:** Mỗi phase file kết thúc bằng section `## Next Phase` chỉ rõ file kế tiếp. KHÔNG nhảy phase ngoài thứ tự.

### Phase Mapping: SKILL.md ↔ Phase Files

> SKILL.md chia execution thành 3 logical phases (Thực thi → Cross-validation → Digest).
> Mỗi logical phase tương ứng với 1 hoặc nhiều phase files. Phase files có PRE/POST-GATE riêng, chi tiết hơn.

| SKILL.md Phase | Phase File(s) (thực thi) | Nội dung |
|----------------|---------------|----------|
| **Phase 1** — Thực thi pipeline | `phase0-detect-route.md` → `phase0-5-legacy-snapshot.md` (nếu LEGACY) → `phase1-collect-basic.md` → `phase2-ba-departments.md` → `phase3-brainstorm-policy.md` → `phase4-write-docs.md` → `phase5-init-registry.md` | Auto-detection + Thu thập + BA + Brainstorm + Soạn docs + Registry seed |
| **Phase 2** — Cross-validation | `phase4-write-docs.md` POST-GATE (Protocol 8) — đã chạy trong Phase 1 | Verify `crosscheck-report.md` + handoff `project-intent-digest.json` |
| **Phase 3** — Digest | `phase6-generate-digest.md` | Digest + phase-summary.md (CORE-028) + session-log COMPLETE (CORE-026) |

---

## Arguments

| Argument | Mô tả | Default | Áp dụng |
|----------|--------|---------|---------|
| `project-name` | Tên dự án hoặc domain | _(hỏi trong flow)_ | Cả hai flows |
| `--force` | Xóa .mc-data/ và tạo lại từ đầu | — | phase1-collect-basic.md |

> Quick skill — khong ho tro --resume / --status.

---

## Output Files

> Cả hai flows tạo ra cùng cấu trúc Phase 0 docs.

| # | File | Path | Mô tả |
|---|------|------|-------|
| 1 | P0-01-brainstorm.md | `.mc-data/docs/phase0-brainstorm/` | Thông tin tổ chức, phòng ban, phân hệ, chính sách |
| 2 | P0-02-systems-users.md | `.mc-data/docs/phase0-brainstorm/` | Bản đồ hệ thống, users/roles, NFR, tech stack |
| 3 | [policy].md | `.mc-data/docs/phase0-brainstorm/policies/` | Chính sách cần xây dựng (0-N files, tùy project_complexity) |
| 4 | req-registry.json | `.mc-data/docs/_meta/req-registry.json` | Registry seed (project, departments, interface_type) |
| 5 | project-digest.json | `.mc-data/docs/_meta/` | Digest artifact cho downstream skills |

### Working Files

| # | File | Path | Mô tả |
|---|------|------|-------|
| 1 | brainstorm-status.json | `.mc-data/work/wf-brainstorm/` | Status tracking — init từ Phase 1 step 1.0b |
| 2 | brainstorm-notes.md | `.mc-data/work/wf-brainstorm/` | Tổng hợp brainstorm từ experts |
| 3 | policy-analysis.md | `.mc-data/work/wf-brainstorm/` | Phân tích chính sách (STANDARD/ENTERPRISE) |
| 4 | complexity-assessment.md | `.mc-data/work/wf-brainstorm/` | Đánh giá mức phức tạp + lý do (TẤT CẢ complexity levels) |
| 5 | crosscheck-report.md | `.mc-data/work/wf-brainstorm/` | Kết quả POST-GATE Protocol 8 |
| 6 | legacy-decisions.json | `.mc-data/work/wf-brainstorm/` | Bridge file legacy decisions — chỉ tạo khi LEGACY_MODE = true |
| 7 | project-intent-digest.json | `.mc-data/work/wf-brainstorm/` | Handoff gọn cho `/wf-analyze-requirements` |
| 8 | phase-summary.md | `.mc-data/work/wf-brainstorm/` | Tóm tắt tiếng Việt cho non-specialist (CORE-028, tạo ở Phase 6) |
| 9 | session-log.json | `.mc-data/work/_trace/` | Execution trace START/COMPLETE (CORE-026, output-only, append) |

### Templates

Tất cả output theo mẫu tại `.claude/doc-framework/phase0-brainstorm/`:

- `P0-01-brainstorm.md` — 6 sections
- `P0-02-systems-users.md` — 4 sections
- `policies/_policy-template.md` — template cho từng chính sách

---

## Workflow Position

```
DỰ ÁN MỚI:
  Idea → /wf-brainstorm (phase0 → phase6) → /wf-analyze-requirements

DỰ ÁN CÓ SẴN:
  /wf-legacy-scan → /wf-brainstorm (phase0 → phase0.5 → phase1 → ... → phase6, CORE-021) → /wf-analyze-requirements
```

---

## Protocols & Strategy

> Protocol: Xem `.claude/skills/protocols/` — `05-registry-safe-write`, `08-content-quality-gate`, `10-post-gate-schema`, `14-phase-summary`, `15-execution-trace`, `19-template-usage`. Triển khai chi tiết tại các file `procedures/phaseN-*.md`.

### Execution Strategy

| Condition | Mode |
|-----------|------|
| Thu thập context ban đầu | **SEQUENTIAL** |
| Brainstorm theo experts, policy analysis | **PARALLEL** |
| Tổng hợp docs, cross-check, seed registry | **HYBRID** |

### Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `missing_context` | Hỏi bù theo flow, dùng context đã có trước | User từ chối cung cấp thêm |
| `agent_timeout` | Spawn lại 1 lần, giảm context nếu cần | Lặp lại lần 2 vẫn fail |
| `policy_mismatch` | Chạy lại cross-check và sửa source doc gần nhất | Không xác định được source of truth |
| `registry_seed_invalid` | Ghi lại seed fields và validate sau ghi | JSON vẫn lỗi sau 3 lần |

---

## Phase 1: Thực Thi Pipeline Phase Files

<!-- PRE-GATE: Phase 1 -->
- [ ] Xác định được `PROJECT_TYPE` (NEW/LEGACY)
- [ ] Đã load `procedures/phase0-detect-route.md`
- [ ] Context đầy đủ cho brainstorm execution

**PRE-GATE:** Xác định được `PROJECT_TYPE` và route vào phase file đầu tiên.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | Đã load `procedures/phase0-detect-route.md` ngay từ Phase 0 router | Read | Procedure loaded |
| 1.2 | Thực thi pipeline tuần tự: phase0 → phase0.5 (nếu LEGACY) → phase1 → phase2 → phase3 → phase4 → phase5. Mỗi phase đọc file kế tiếp khi POST-GATE PASS | Write + Agent | Output Phase 0 được tạo trong `.mc-data/` |

**POST-GATE:** `P0-01-brainstorm.md`, `P0-02-systems-users.md`, `req-registry.json` và `project-intent-digest.json` đã tồn tại hoặc được cập nhật.

<!-- POST-GATE: Phase 1 -->
- T1: test -f .mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md — file existence
- T2: test -f .mc-data/docs/phase0-brainstorm/P0-02-systems-users.md — file existence
- T3: test -f .mc-data/docs/_meta/req-registry.json — registry seed created
- T4: test -s .mc-data/work/wf-brainstorm/project-intent-digest.json — handoff file non-empty

---

## Phase 2: Cross-Validation & Handoff (thực thi bởi `phase4-write-docs.md` POST-GATE)

<!-- PRE-GATE: Phase 2 -->
- [ ] Phase 1 POST-GATE PASS
- [ ] Tất cả Phase 0 docs đã được tạo thành công
- [ ] Registry seed đã được validate

**PRE-GATE:** Phase 1 POST-GATE PASS.

> Cross-validation chạy tự động trong `phase4-write-docs.md` POST-GATE (Protocol 8).
> SKILL.md Phase 2 verify kết quả crosscheck + handoff.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | Verify `crosscheck-report.md` đã được tạo (Protocol 8 ran trong `phase4-write-docs.md` POST-GATE) | Read | Không còn mismatch blocking |
| 2.2 | Verify artifact handoff `project-intent-digest.json` đã được tạo (`phase5-init-registry.md` Step 5.3c) | Read | Handoff sẵn sàng cho skill sau |

**POST-GATE:** Cross-Validation PASS hoặc đã auto-correct; handoff cho `/wf-analyze-requirements` sẵn sàng.

<!-- POST-GATE: Phase 2 -->
- T1: test -f .mc-data/work/wf-brainstorm/crosscheck-report.md — cross-check completed
- T2: test -f .mc-data/work/wf-brainstorm/project-intent-digest.json — handoff file exists
- T3: jq empty .mc-data/work/wf-brainstorm/project-intent-digest.json — valid JSON
- T4: jq -e '.next_skill == "/wf-analyze-requirements"' .mc-data/work/wf-brainstorm/project-intent-digest.json — correct handoff target

---

## Phase 3: Generate Digest Artifacts (thực thi bởi `phase6-generate-digest.md`)

<!-- PRE-GATE: Phase 3 -->
- [ ] Phase 2 POST-GATE PASS
- [ ] P0-01 và P0-02 docs đã được validate

> Tạo project-digest.json từ Phase 0 output để downstream skills load nhanh.
> Bước này được thực thi tự động trong `phase6-generate-digest.md` sau khi `phase5-init-registry.md` hoàn thành.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | Verify `phase6-generate-digest.md` đã tạo `.mc-data/docs/_meta/project-digest.json` | Read | Digest file exists |
| 3.2 | Verify digest content hợp lệ (JSON, có project_summary) | Read | Digest valid |

**Fallback:** Nếu digest generation fail → log warning, tiếp tục (backward compatible — consumer skill sẽ đọc full docs).

<!-- POST-GATE: Phase 3 -->
- T1: test -f .mc-data/docs/_meta/project-digest.json — digest file created
- T2: test -s .mc-data/docs/_meta/project-digest.json — digest non-empty (~200 words)
- T3: jq empty .mc-data/docs/_meta/project-digest.json — valid JSON schema
- T4: grep -q "project_summary" .mc-data/docs/_meta/project-digest.json — meaningful content present

---

## Registry Update (Conditional)

> Registry Safe-Write: chỉ seed các field khởi tạo trong Phase 0.

- Chỉ modify: `project`, `departments[]`, `interface_type`, metadata khởi tạo.
- Không modify: `requirements[]`, `features[]`, `design_status`, `ux_design_status`, `implementation_order`, `impl_status`.
- Ghi atomic và validate lại registry sau mỗi lần seed/cross-fix.

---

## Output Report

- Phase 0 docs: `.mc-data/docs/phase0-brainstorm/`
- Registry seed: `.mc-data/docs/_meta/req-registry.json`
- Digest: `.mc-data/docs/_meta/project-digest.json`
- Handoff: `.mc-data/work/wf-brainstorm/project-intent-digest.json`

#### Utility Scripts

- **Phase 0 Cross-Check**: `.claude/scripts/phase0-cross-check.sh`
  - Validates consistency between P0-01, P0-02, policies, and registry
  - Run after wf-brainstorm to verify Phase 0 document integrity
  - Usage: `bash .claude/scripts/phase0-cross-check.sh [.mc-data]`

Next: /wf-analyze-requirements

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/wf-analyze-requirements` | **Next step** sau brainstorm |
| `/wf-legacy-extract` | Predecessor (legacy flow) — tạo extracted data |
| `/wf-legacy-scan` | Entry point cho dự án có sẵn |
| `/existing-project` | Orchestrator workflow |
| `/status` | Kiểm tra tiến độ |

---

## Error Handling

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E001 | `.mc-data/` chưa tồn tại | Tạo directory structure ngay — đây là skill khởi tạo |
| E002 | Agent timeout / không trả output | Re-spawn 1 lần; nếu vẫn fail → skip + WARNING |
| E003 | User cung cấp thông tin không đủ | Hỏi clarifying questions trước khi tiếp tục |
| E004 | Output file write fail | Retry 3 lần, sau đó escalate to user |
| E005 | User cancel giữa workflow | Working files đã tạo được giữ lại trong `.mc-data/work/wf-brainstorm/`. Skill này là quick skill — không hỗ trợ `--resume`. User chạy lại từ đầu, context có thể lấy từ working files nếu cần |
| E006 | Flow detection fail (new vs legacy) | Hỏi user xác nhận mode trước khi chạy |
