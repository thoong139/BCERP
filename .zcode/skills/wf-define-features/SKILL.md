---
name: wf-define-features
version: 3.2.0
last_updated: 2026-05-10
changelog:
  v3.2.0 (2026-05-10) — W4.7 Cross-Module Entity Detection (wf-fix-bugs v9 Wave 4):
    - Phase 3 Cross-Validation: thêm check 3.8 (Non-blocking, SAU POST-GATE)
      * Quét feature specs tìm MOD-[A-Z0-9-]+ refs từ module khác
      * Kiểm tra cross_module_dependencies[] trong registry — suggest nếu undeclared
      * Interactive: AskUserQuestion với 3 options (Có/Không/Deferred)
      * Headless: append to deferred-findings.md
      * Graceful skip: khi registry chưa có cross_module_dependencies field
      * KHÔNG block POST-GATE — suggest only
    - Chi tiết: procedures/phase3-cross-validation.md §W4.7 Cross-Module Entity Detection
  v3.1.0 (2026-04-28) — Referential Integrity Fix (root cause Finding #1 từ wf-implement-feature E2E):
    - Phase 5 step 5.3c MỚI: Referential Integrity Check TRƯỚC atomic write (5.4)
      * Compute orphan REQ-IDs: features[].req_ids[] − requirements[].req_id
      * Default behavior: BLOCK với error E020, hướng dẫn 3 lựa chọn (auto-stub flag /
        re-run wf-analyze-requirements / wf-manage-change)
      * Optional flag --auto-stub-requirements: APPEND stub entries vào requirements[]
        với tracking flags (auto_generated_by, needs_user_review, source, referenced_by)
        + description derive từ feature.title+notes
      * Output debug: $SESSION_DIR/referential-integrity-violations.json
    - POST-GATE thêm check jq referential integrity (BẮT BUỘC pass trước khi END)
    - _shared.md Error Codes thêm E020
    - _shared.md Registry Safe-Write thêm "Exception: requirements[] APPEND-ONLY" section
      documenting narrow exception cho stubs (CORE-006 §4a update needed)
    - SKILL.md argument-hint thêm --auto-stub-requirements flag
    - **Lý do:** Trước v3.1.0, wf-define-features có thể tạo features reference REQ-IDs
      không tồn tại trong requirements[] (bug khi user skip /wf-analyze-requirements step
      hoặc registry bị corrupt). Downstream wf-implement-feature gặp Finding #1 (lookup
      requirements[req_id] → null). Fix tại upstream để root cause không propagate.
  v3.0.0 (2026-04-23):
    - ADR-OPT rollout Phase 3.1: Session isolation (ADR-OPT-02), Workload Gate (ADR-OPT-03), Lane Dispatch (ADR-OPT-01), CDG (ADR-OPT-08)
    - Them phase0.5-workload-gate.md moi — tach rieng workload estimation khoi context loading
    - Doi ten phase0.5-impl-status.md -> phase0.5-legacy-impl-seed.md — ro rang hon ve scope (LEGACY only)
    - Session isolation: $SESSION_DIR = .mc-data/work/wf-define-features/sessions/{YYYYMMDD-HHMMSS}-{hash4}/
    - _contract.json dong bo v3.0.0 (session-scoped working outputs, template fields)
    - Template Usage Rule (CORE-031) enforce cho tat ca output files
    - Tat ca procedure files update: phase0-context, phase2-create-specs, phase2.5-feat-mapping, phase3-cross-validation, phase5-registry-update, _shared
  v2.1.0 (2026-04-19):
    - Tai cau truc procedures/ theo pattern phase-per-file (giong wf-analyze-requirements v2.1, wf-fix-bugs)
    - Tach flow-new.md (830 dong) thanh _shared.md + 10 phase files — tiet kiem ~85-90% token khi AI load per-phase
    - Them State Variables Glossary, Phase Ordering by Mode, Agent Context Templates trong _shared.md
    - Tach Agent Context Templates (BA Phase 2, BA Phase 4, Product-Expert Phase 4) ra _shared.md de tranh duplicate
    - Giu nguyen templates, _contract.json outputs, evals test cases — backward compatible
  v2.0.0 (2026-03-31):
    - Merge legacy + new flows thanh single procedures/flow-new.md voi LEGACY_MODE auto-detect
description: |
  Chuyen requirements (Phase 1) thanh feature specifications (Phase 2) — mapping REQ-IDs sang FEAT-IDs, tao feature specs voi user stories, business rules, permissions — 11 phases chi tiet trong procedures/. Ho tro ca du an moi (interactive) va legacy (impl_status inheritance); tu dong phat hien loai du an. Session isolation, workload gate truoc khi chay, lane dispatch parallel per module.

  TRIGGER khi:
  - Sau khi /wf-analyze-requirements hoan thanh (ca legacy flow)
  - User noi: "define features", "tao feature specs", "chuyen requirements thanh features"
  - Keywords: "feature definition", "feature specs", "FEAT-ID"
  - Goi lenh: /wf-define-features [scope] [--status] [--resume]

  LUON trigger khi user can tao feature specifications tu requirements, du khong dung tu "define-features".

  KHONG trigger khi:
  - Chua co requirements → dung /wf-analyze-requirements truoc
  - Da co feature specs → dung /wf-design
argument-hint: "[all | system-name | module-name] [--status] [--resume] [--from-scan=<session-id|path>] [--auto-stub-requirements]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---

# /wf-define-features: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Chuyển requirements thành feature specifications — mapping REQ-IDs sang FEAT-IDs |
| **Prerequisites** | `phase1-business/` + `req-registry.json` (requirements[]) |
| **Duration** | Multi-session |
| **Phases** | Phase 0: Auto-Detection → Phase 1-N: Feature Specs → Phase 2.7: UI Coverage Cross-Check (LEGACY only) |
| **Input** | Phase 1 business docs + `req-registry.json` |
| **Output** | `phase2-features/[sys]/[mod]/*.md` + `req-registry.json` (features[]) |

### Workflow Position

```
/wf-analyze-requirements → /wf-define-features ← YOU ARE HERE → /wf-design
```

### Phase Mapping: SKILL.md ↔ procedures/

> SKILL.md là high-level overview. Procedures được tách thành nhiều phase files (v2.1 restructure) để giảm context load mỗi phase. `_shared.md` chứa cross-cutting protocols, state variables, agent templates.

| SKILL.md Phase | Nội dung | procedures/ file |
|---------------|----------|------------------|
| Phase 0 | Auto-Detection & Routing | `phase0-context.md` |
| Phase 0.5 | Workload Gate (MỌI mode) | `phase0.5-workload-gate.md` |
| Phase 0.5 | Legacy Impl Seed (LEGACY only) | `phase0.5-legacy-impl-seed.md` |
| Phase 1 | Tạo Feature Specifications | `phase1-scope-mapping.md` + `phase2-create-specs.md` + `phase2.5-feat-mapping.md` (LEGACY) + `phase2.7-ui-coverage.md` (LEGACY + có screens) |
| Phase 2 | Cross-Validation, Review & Registry | `phase3-cross-validation.md` + `phase4-stakeholder-review.md` + `phase5-registry-update.md` |
| Phase 3 | Generate Digest Artifacts | (POST-GATE — Phiên 6, thực thi tại cuối Phase 5) |

> **Shared content:** Agent context templates, state variables, fix rules, registry schema, error codes → `procedures/_shared.md`. Phase files reference section cụ thể (ví dụ: `_shared.md §Agent Context Templates`), KHÔNG load toàn bộ.

### Load-on-Demand Pattern

AI chỉ đọc phase file đang thực thi + `_shared.md` (cho protocols/templates chung) — KHÔNG đọc toàn bộ procedures/ 1 lần. Điều này tiết kiệm ~85-90% tokens so với monolithic flow-new.md cũ (830 dòng).

- **Entry:** Luôn load `procedures/phase0-context.md` + `procedures/_shared.md`
- **Resume:** Đọc `checkpoint.json` → `position.current_phase` → load phase file tương ứng
- **Branching:** Cuối mỗi phase file có "Next phase" link — branching theo `$LEGACY_MODE` / `$HAS_SCREENS` (xem `_shared.md §Phase Ordering by Mode`)
- **Shared content** (State Variables, Agent Templates, LEGACY Context Injection, Fix Rules, Registry Schema, Error Codes, Output Report): tất cả ở `_shared.md` — phase files reference section cụ thể, không inline duplicate

### Template Usage Rule (BẮT BUỘC)

Mọi working file PHẢI tuân thủ: **ĐỌC** template từ `.claude/skills/workflow/wf-define-features/templates/` → **ĐIỀN** dữ liệu thực tế → **GHI** đến output path.

| Template | Output path | Được tạo ở procedures/ Phase |
|---|---|---|
| `templates/define-features-status.json` | `.mc-data/work/wf-define-features/define-features-status.json` | `phase0-context.md` Step 0.3 |
| `templates/define-features-plan.md` | `.mc-data/work/wf-define-features/define-features-plan.md` | `phase1-scope-mapping.md` Step 1.4 |
| `templates/feature-briefs.json` | `.mc-data/work/wf-define-features/feature-briefs.json` | `phase1-scope-mapping.md` Step 1.5b |
| `templates/checkpoint.json` | `.mc-data/work/wf-define-features/checkpoint.json` | Mỗi lần SAVE CHECKPOINT (Phase 2 step 2.5, Phase 4 step 4.10, hoặc LPM after-each-phase) |
| `templates/ui-coverage-gaps.json` | `.mc-data/work/wf-define-features/ui-coverage-gaps.json` | `phase2.7-ui-coverage.md` Step 2.7.6 (LEGACY only) |

> **Lưu ý về `_digests/` templates:** `.claude/doc-framework/_digests/feature-briefs.template.json` là **schema reference** cho digest output (Phase 6 — Phiên 6). Working `templates/feature-briefs.json` có schema KHÁC (xem CLAUDE.md notes về dual-schema).

---

## Phase 0: Auto-Detection & Routing (BAT BUOC — chay truoc tien)

> Tu dong phat hien loai du an va inject context phu hop.
> LEGACY_MODE detection theo CORE-021: check `project-context.md` (> 500 bytes).

```
STEP 1: Detect LEGACY_MODE (CORE-021)
  LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes

  IF LEGACY_MODE:
    LEGACY_CONTEXT = read .mc-data/work/legacy-scan/project-context.md
    → PROJECT_TYPE = LEGACY
    → Thong bao: "Phat hien du an co san (project-context.md). Chay flow voi legacy context injection."
    → Load procedures/phase0-context.md (entry point)
    → Phase sequencing theo procedures/_shared.md §Phase Ordering by Mode (mode=LEGACY)

STEP 2: Kiem tra .mc-data/
  ELSE IF test -d .mc-data:
    → PROJECT_TYPE = NEW
    → Load procedures/phase0-context.md (entry point)
    → Phase sequencing theo procedures/_shared.md §Phase Ordering by Mode (mode=NEW)

STEP 3: Du an moi hoan toan
  ELSE:
    → STOP: "Chua co du an. Chay `/wf-brainstorm` de bat dau."
```

**Dac biet — `--resume` handler:**

```
IF $ARGUMENTS chua "--resume":
  IF test -f .mc-data/work/wf-define-features/checkpoint.json:
    checkpoint = doc checkpoint.json
    → Load procedures/phase0-context.md (entry point, LEGACY_MODE tu detect tu project-context.md — CORE-021)
    → Sau Phase 0 jump toi phase theo checkpoint.position.current_phase
  ELSE:
    → STOP: "Khong tim thay checkpoint. Chay `/wf-define-features` tu dau."
```

> **Lưu ý:** Handler này là overview ngắn. Chi tiết đầy đủ — bao gồm session isolation (ADR-OPT-02), `latest` pointer trong `define-features-status.json`, và session-state.json reconciliation — xem `procedures/phase0-context.md §Resume Handler`.

**Dac biet — `--status` handler:**

```
IF $ARGUMENTS chua "--status":
  IF test -f .mc-data/work/wf-define-features/checkpoint.json:
    checkpoint = doc checkpoint.json
    // Filesystem reconciliation: scan actual files de hien thi so that
    actual_files = find .mc-data/docs/phase2-features/ -name "*.md" ! -name "stakeholder-review.md" | wc -l
    // So sanh voi checkpoint.features_completed
    // Hien thi ca hai: checkpoint state VA actual_files count
    → Hien thi trang thai theo project_type (legacy hoac new):
      - Bao gom dong: "Files tren disk: [actual_files] / [total_features]"
      - Neu actual_files != checkpoint.features_completed → "(checkpoint chua dong bo — chay --resume de cap nhat)"
    → STOP
  ELSE IF test -f .mc-data/work/wf-define-features/define-features-status.json:
    → Hien thi trang thai tu define-features-status.json
    → STOP
  ELSE:
    → "Chua co define-features session nao."
    → STOP
```

> **Lưu ý:** Handler này là overview ngắn. Chi tiết đầy đủ — bao gồm đọc `latest` pointer từ `define-features-status.json.session.latest` để tìm session hiện tại, và session-state.json per-phase breakdown — xem `procedures/phase0-context.md §Status Handler`.

---

## Arguments

| Argument | Mo ta | Default | Ap dung |
|----------|-------|---------|---------|
| `scope` | `all` / `[system-name]` / `[module-name]` | `all` | Ca hai flows |
| `--status` | Hien thi tien do, khong thuc thi | — | Ca hai flows |
| `--resume` | Resume tu checkpoint da luu | — | Ca hai flows |
| `--from-scan=<session-id\|path>` | **OPTIONAL (Sprint 5 cross-skill).** Doc `feature-inventory.md` + `target-map.json` tu wf-scan-target session de SUGGEST features cho user review (suggest-only, KHONG auto-import). Giup BA/PO co context khi viet feature specs. | — | Ca hai flows |

> **Sprint 5 cross-skill — `--from-scan`:** OPTIONAL flag. Khi co flag, skill load
> `feature-inventory.md` tu session wf-scan-target tai
> `.mc-data/work/wf-scan-target/sessions/<id>/feature-inventory.md` va inject vao agent context
> de business-analyst suggest features (user co the accept/reject tung suggestion).
> KHONG auto-import — chi la suggestion. KHONG thay doi default behavior — khong pass flag thi
> skill chay nhu cu.

---

## Output Files

> Ca hai flows tao ra cung cau truc Phase 2 docs.

| # | File | Path | Mo ta |
|---|------|------|-------|
| 1 | [feature].md | `.mc-data/docs/phase2-features/[sys]/[mod]/` | Feature spec per feature (1 file per FEAT-ID) |
| 2 | stakeholder-review.md | `.mc-data/docs/phase2-features/` | Review specs (Phan A-D) |

### Working Files

| # | File | Path | Mo ta |
|---|------|------|-------|
| 1 | define-features-status.json | `.mc-data/work/wf-define-features/` | Trang thai chi tiet tung phase |
| 2 | define-features-plan.md | `.mc-data/work/wf-define-features/` | Feature mapping + batch strategy |
| 3 | cross-validation-report.md | `.mc-data/work/wf-define-features/` | Ket qua cross-validation |
| 4 | define-features-report.md | `.mc-data/work/wf-define-features/` | Bao cao tong ket |
| 5 | checkpoint.json | `.mc-data/work/wf-define-features/` | Checkpoint cho resume |
| 6 | feature-briefs.json | `.mc-data/work/wf-define-features/` | Brief ngan cho creation, review va validation |
| 7 | feature-briefs.json (digest) | `.mc-data/docs/_meta/` | Digest artifact cho downstream skills (schema khac working) |
| 8 | deferred-findings.md | `.mc-data/work/wf-define-features/` | Deferred findings tu Phase 4 — consume boi wf-design |
| 9 | ui-coverage-gaps.json | `.mc-data/work/wf-define-features/` | UI coverage gaps report — chi tao khi LEGACY_MODE va co screens |

> **Lưu ý dual-location + dual-schema:** Một số files có 2 location — working dir (`.mc-data/work/wf-define-features/`) cho runtime và canonical `_meta/` path (`.mc-data/docs/_meta/`) cho handoff digest. Phiên 6 sẽ copy digest từ working → canonical.
>
> **Đặc biệt `feature-briefs.json`** tồn tại ở cả 2 location nhưng với **schema KHÁC NHAU**:
> - **Working** (`templates/feature-briefs.json`): dùng cho Phase 1 creation — fields: `feat_id`, `actors`, `business_rules`, `output_path`
> - **Digest** (`_digests/feature-briefs.template.json`): dùng cho downstream skills — fields: `feature_id`, `summary`, `acceptance_criteria`, `technical_complexity`
>
> Phase 1 tạo working briefs, Phase 3 (Digest) generate digest bản riêng theo schema khác.

### Legacy-specific Output (LEGACY_MODE — procedures/phase2.5-feat-mapping.md + phase2.7-ui-coverage.md)

| # | File | Path | Mo ta |
|---|------|------|-------|
| 1 | feat-mapping.json | `.mc-data/work/legacy-scan/` | Map FEAT-ID → { title, module, system, doc_path } |
| 2 | ui-coverage-gaps.json | `.mc-data/work/wf-define-features/` | UI coverage gaps report — chỉ tạo khi LEGACY_MODE và có screens (Phase 2.7) |

### File Naming Difference

| Mode | File naming convention | Vi du |
|------|----------------------|-------|
| NEW | Kebab-case tieng Viet | `quan-ly-thong-tin-khach-hang.md` |
| LEGACY_MODE | FEAT-ID lam ten file | `FEAT-CRM-CUST-001.md` |

> Day la **intentional difference** — legacy pipeline dung FEAT-ID de nhat quan voi feat-mapping.json va downstream legacy tools.

### Templates

Tat ca output theo mau tai `.claude/doc-framework/phase2-features/` va `.claude/skills/workflow/wf-define-features/templates/`.

---

## Workflow Position

```
DU AN MOI:
  /wf-analyze-requirements → /wf-define-features (NEW mode: phase 0→1→2→3→4→5) → /wf-design

DU AN CO SAN:
  /wf-analyze-requirements → /wf-define-features (LEGACY mode: phase 0→0.5→1→2→2.5→2.7→3→4→5, CORE-021/022) → /wf-design
```

---

## Protocols & Strategy

> Protocol: Xem `.claude/skills/protocols/`; phần thi hành chi tiết nằm trong `procedures/phaseN-*.md` (skill-specific protocols trong `procedures/_shared.md`).

### Execution Strategy

| Condition | Mode |
|-----------|------|
| Load context, group requirements, assign FEAT-ID | **SEQUENTIAL** |
| Tạo feature specs theo module hoặc batch | **PARALLEL** |
| Cross-validation, stakeholder review, registry write-back | **HYBRID** |

### Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `missing_feature_file` | Tạo lại từ feature brief + registry + dept docs | Context nguồn không đủ |
| `duplicate_feat_id` | Gán lại FEAT-ID và cập nhật tham chiếu | Trùng lặp lan rộng nhiều module |
| `coverage_gap` | Bổ sung feature hoặc thêm REQ mapping đúng nguồn | Không xác định được REQ gốc |
| `stakeholder_review_gap` | Auto-fix source spec rồi regenerate phần review liên quan | Còn Critical/High sau 3 vòng |

---

## Phase 1: Tạo Feature Specifications

**PRE-GATE:** Requirements Phase 1 đã sẵn sàng trong registry và department docs.

### PRE-GATE Digest Loading (Phiên 6 — Digest Pipeline)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | Kiểm tra dept-digests.json + phase1-handoff.json tồn tại ở `.mc-data/docs/_meta/` | Bash | Nếu tồn tại → đọc; nếu không → fallback read full phase1 docs |
| 0.2 | Nếu digests có → inject context vào flow; nếu không → tiếp tục với phase1 docs đầy đủ | Read | Context sẵn sàng (gọn từ digests hoặc đầy đủ từ docs) |

> **Stub Detection (v1.8.0+):** Nếu phát hiện files trong `phase2-features/` có frontmatter `status: stub` (từ `/wf-fix-bugs --deep`),
> hiển thị: "Found N stub files from deep scan. These will be fleshed-out during feature definition."
> Flesh-out stub: fill content theo template, remove `status: stub`, giữ `related_feature_id` nếu có.

### Main Phase 1 Execution

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | Nạp `procedures/phase1-scope-mapping.md`, tạo `define-features-plan.md` và `feature-briefs.json` | Read + Write | Plan và briefs đã được tạo |
| 1.2 | Sinh feature specs theo batch, dùng handoff/briefs để giảm context downstream | Agent + Write | Feature files được tạo trong `.mc-data/docs/phase2-features/` |

**POST-GATE:** Feature files đã tồn tại, `feature-briefs.json` tồn tại và FEAT-ID mapping đã được ghi nhận.

---

## Phase 2: Cross-Validation, Review & Registry Update

**PRE-GATE:** Phase 1 POST-GATE PASS.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | Chạy Cross-Validation và auto-correction loop trên feature specs | Read + Edit | Không còn lỗi blocking |
| 2.1b | **(W4.7 — Non-blocking, SAU POST-GATE)** Cross-Module Entity Detection: phát hiện feature refs `MOD-XXX` từ module khác chưa khai báo trong `cross_module_dependencies[]`. Graceful skip khi registry chưa có field. Chi tiết: `procedures/phase3-cross-validation.md §W4.7`. | AskUserQuestion (interactive) / Write deferred-findings (headless) | Undeclared deps prompted hoặc logged — không block |
| 2.1c | **(CF6 — Non-blocking, v3.3.0+)** Cross-FEAT Ref Detection: scan feature specs tìm mention "FEAT-XXX" hoặc "REQ-XXX" trong description/business_rules/dependencies → auto-generate đề xuất `cross_feat_refs[]` entry cho registry. User review/accept từng suggestion tại step này. Accepted → append vào `features[].cross_feat_refs[]` khi Safe-Write ở step 2.2. Graceful skip khi không tìm thấy cross-FEAT references. KHÔNG block. | AskUserQuestion (interactive) / Deferred (headless) | Cross-feat refs được đề xuất + user review |
| 2.2 | Tạo stakeholder review, sau đó Safe-Write `features[]` vào registry (bao gồm cross_feat_refs[] đã accept từ 2.1c) | Agent + Write | Stakeholder review hoàn tất; registry valid |

**POST-GATE:** `stakeholder-review.md` tồn tại, `features[]` đã được cập nhật và validation PASS.

---

## Phase 2.7: UI Coverage Cross-Check (LEGACY_MODE only)

> So sánh UI screens thực tế với features đã defined. Phát hiện orphan screens.
> CHỈ chạy khi LEGACY_MODE = true VÀ ui-manifest.json tồn tại VÀ total_screens > 0.
> Nếu không thỏa → SKIP Phase 2.7.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.7.1 | Đọc ui-manifest.json → build screen list với routes | Read | Screen list loaded |
| 2.7.2 | Đọc defined features → extract screen/UI references | Read | Feature refs collected |
| 2.7.3 | Cross-check: mỗi screen → tìm matching feature (exact/fuzzy) | Bash | Gaps identified |
| 2.7.4 | Phân loại: COVERED / INFRASTRUCTURE / GAP / AMBIGUOUS | — | Gaps classified |
| 2.7.5 | Nếu có GAP → tạo feature spec stub từ screen context | Write | Stubs created |
| 2.7.6 | Ghi ui-coverage-gaps.json | Write | Report exists |

**POST-GATE (chỉ khi Phase 2.7 chạy):** `ui-coverage-gaps.json` tồn tại, valid JSON, `coverage_stats.gaps >= 0`.

> Chi tiết đầy đủ: `.claude/skills/workflow/wf-define-features/procedures/phase2.7-ui-coverage.md`

---

## Phase 3: Generate Digest Artifacts (POST-GATE — Phiên 6)

> Tạo feature-briefs.json từ Phase 2 output để downstream skills load nhanh.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | Đọc feature files từ `phase2-features/[sys]/[mod]/[feat].md` | Read | Context sẵn sàng |
| 3.2 | Sinh feature-briefs.json theo template `.claude/doc-framework/_digests/feature-briefs.template.json` | Write | Digest hợp lệ JSON, ~100 words per feature |
| 3.3 | Lưu vào `.mc-data/docs/_meta/feature-briefs.json` | Write | File tồn tại, readable |

**Fallback:** Nếu digest generation fail → log warning, tiếp tục (backward compatible — consumer skill sẽ đọc full docs).

---

## Registry Update (Safe-Write)

> Registry Safe-Write áp dụng cho `/wf-define-features`.

- **Fields được phép update:** `features[]`, `impl_status` (per REQ-ID)
- **Append-only cho features[]:** Thêm entries mới, không modify/delete existing
- **impl_status:** Chỉ set "skipped" cho features thuộc DEPRECATED modules
- **Read-before-write:** Luôn đọc registry fresh ngay trước khi ghi
- **Atomic write:** Ghi toàn bộ JSON trong 1 operation, validate sau khi ghi

> KHÔNG modify bất kỳ field nào khác trong registry, đặc biệt `requirements[]`, `design_status`, `ux_design_status`, `implementation_order`.

**cross_feat_refs[] (CF6 — v3.3.0+):** Khi feature spec đề cập "FEAT-XXX" hoặc "REQ-XXX" trong description/business_rules/dependencies → Phase 2.1c tự động đề xuất `cross_feat_refs[]` entries. Sau khi user accept, append vào `features[feat].cross_feat_refs[]` tại bước Safe-Write. Schema cross_feat_ref entry: `{target_req_id, target_feat_id, relationship: "consume|produce|coordinate", reason, blocking_level: "hard|soft", min_completion: "test_passed|impl_done"}`. wf-verify-sync (Phase 5 CF6) sẽ validate các refs này về sau.

---

## Output Report

- Phase 2 docs: `.mc-data/docs/phase2-features/`
- Feature briefs: `.mc-data/work/wf-define-features/feature-briefs.json`
- Registry updated: `.mc-data/docs/_meta/req-registry.json`
- UI coverage gaps: `.mc-data/work/wf-define-features/ui-coverage-gaps.json` (LEGACY_MODE only, khi có screens)

Next: /wf-design

---

## Related Skills

| Skill | Quan he |
|-------|---------|
| `/wf-analyze-requirements` | **Prerequisite** — cung cấp requirements[] |
| `/wf-legacy-extract` | Upstream (legacy flow) — tạo extracted data |
| `/wf-design` | **Next step** — dùng feature specs để thiết kế architecture |
| `/status` | Kiểm tra tiến độ |

---

## Error Handling

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E001 | PRE-GATE fail — req-registry.json thiếu requirements[] | STOP — hướng dẫn chạy `/wf-analyze-requirements` trước |
| E002 | REQ-ID không tồn tại trong registry | KHÔNG tạo mới — flag cho user review |
| E003 | Agent timeout / không trả output | Re-spawn 1 lần; nếu vẫn fail → skip + WARNING |
| E004 | Feature spec conflict với requirements | Flag conflict, hỏi user clarify trước khi ghi |
| E005 | Output file write fail | Retry 3 lần, sau đó escalate to user |
| E006 | User cancel giữa workflow | Lưu checkpoint, hướng dẫn dùng `--resume` |
