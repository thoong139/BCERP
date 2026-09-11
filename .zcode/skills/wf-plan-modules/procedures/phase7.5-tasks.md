# Phase 7.5: Tạo Implementation Task Files

> Tạo file implementation plan cho từng feature — bao gồm A6-EXT (Executable Spec) + A7-EXT (Micro-Tasks).

> **Shared context:** xem `_shared.md` — State Variables (`$LAYERS`, `$FEATURE_IMPL_MAP`, `$DEPRECATED_MODULES`).

---

## PRE-GATE

Phase 7 output files đã được tạo (steps 7.1–7.7 hoàn tất).

---

## 📥 INPUT

- Registry (features, modules)
- Feature specs (`phase2-features/[sys]/[mod]/*.md`)
- Roadmap data (`$LAYERS` từ Phase 4)
- `$FEATURE_IMPL_MAP` (chỉ LEGACY_MODE — từ Phase 1.5)
- `$DEPRECATED_MODULES` (chỉ LEGACY_MODE — từ Phase 0)
- Template: `.claude/doc-framework/phase5-implementation/tasks/[system]/[module]/[feature]-impl.md`
- Template A6-EXT (BẮT BUỘC): `.claude/doc-framework/_meta/a6-ext-fragment.md` — structured fragment để architect POPULATE
- Template (LEGACY): `templates/implementation-strategy.md.tpl`

## 📤 OUTPUT

| File | Đường dẫn | Template |
|------|-----------|---------|
| Implementation task files | `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md` | `.claude/doc-framework/phase5-implementation/tasks/[system]/[module]/[feature]-impl.md` |

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 7.5.1 | `mkdir -p .mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/` cho mỗi module. `mkdir -p $SESSION_DIR/lanes/` | Directories exist |
| 7.5.2 | Đọc template `[feature]-impl.md` từ doc-framework | Template loaded |
| 7.5.2a | **[v5.1+ Quality Sections]** Compute `$QUALITY_SECTIONS` và `$ENV_NOTES` cho từng feature (xem §Quality Sections Computation). Inject vào lane context để architect POPULATE A2.5 + A2.6. | Quality context computed |
| 7.5.3 | **Topological Lane Dispatch (ADR-OPT-01):** Dispatch per topological level (xem §Topological Lane Dispatch). **LEGACY:** inject Implementation Strategy section vào mỗi task file. **v5.1+:** architect POPULATE A2.5 Quality Requirements + A2.6 Environment Notes trong mỗi task file. | Task files exist, levels processed sequentially |
| 7.5.3a | **Verify lane outputs per-level:** Sau mỗi level complete, kiểm tra `$SESSION_DIR/lanes/L{level}/{module-slug}/signals.json` non-empty cho tất cả modules trong level. | `test -s $SESSION_DIR/lanes/L{level}/{module-slug}/signals.json` |
| 7.5.3b | **L2 Checkpoint per lane:** Sau MỖI lane complete: update `$SESSION_DIR/session-state.json` → `phases.P7_5.batches[L{level}-{module}].status = "completed"` | session-state.json updated (L2 checkpoint) |
| 7.5.4 | Gán sprint number dựa trên layer assignment từ Phase 4 (đã được inject trong lane context ở Step 7.5.3) | Sprint mapped |
| 7.5.5 | **[Phiên 7 - A6-EXT] Spawn architect agent** sinh A6-EXT (Executable Implementation Spec) cho MỖI feature (xem §A6-EXT Generation) | Task files có A6-EXT |
| 7.5.6 | **[Phiên 8 - A7-EXT] Spawn architect agent** sinh A7-EXT (Micro-Task Breakdown) nếu feature có ≥ 3 files HOẶC estimated time > 15 phút (xem §A7-EXT Generation) | Task files có A7-EXT (hoặc skipped nếu < 3 files) |

---

## §Topological Lane Dispatch (Step 7.5.3 chi tiết)

Thay thế parallel-per-system pattern bằng **topological lane dispatch** (ADR-OPT-01).

```
Import _shared/lane/dispatcher.py

FOR each level L IN $TOPOLOGICAL_LEVELS:   # L = 0, 1, 2, ...
  # Build LaneConfig list cho modules trong level L
  lanes = []
  FOR each module_slug IN $TOPOLOGICAL_LEVELS[L]:
    module_features = [f for f in registry.features if f.module_slug == module_slug
                       AND NOT ($LEGACY_MODE AND f.module_id IN $DEPRECATED_MODULES)]

    IF len(module_features) == 0:
      LOG "Skip module [module_slug] level L[{L}] — no active features"
      CONTINUE

    lane_output_path = "$SESSION_DIR/lanes/L{L}/{module_slug}/signals.json"
    mkdir -p dirname(lane_output_path)

    lanes.append(LaneConfig(
      key        = "{module_slug}",
      agent_type = "architect",
      prompt     = TASK_GENERATION_PROMPT_TEMPLATE.format(
        module_slug     = module_slug,
        module_features = module_features,
        dependencies    = $LAYERS[layer=L].dependencies,
        sprint_number   = $LAYERS[layer=L].sprint,
        feature_impl_map = $FEATURE_IMPL_MAP.get(module_slug, {}) if $LEGACY_MODE else {},
      ),
      output_path = lane_output_path,
      context = {
        "doc_template": ".claude/doc-framework/phase5-implementation/tasks/[system]/[module]/[feature]-impl.md",
        "task_output_dir": ".mc-data/docs/phase5-implementation/tasks/{sys}/{mod}/",
        "impl_strategy_tpl": "templates/implementation-strategy.md.tpl" if $LEGACY_MODE else null,
        "quality_sections": $QUALITY_SECTIONS.get(module_slug, {}),  # v5.1+ A2.5
        "env_notes": $ENV_NOTES.get(module_slug, {}),                # v5.1+ A2.6
        "domain_checklist": $DOMAIN_CHECKLIST.get(module_slug, []),   # v5.1+ domain-specific
      }
    ))

  # Dispatch lanes cho level L (parallel within level)
  dispatch_lanes(lanes, max_parallel=$LPM_PARAMS.max_parallel_agents, timeout_sec=600)

  # WAIT for ALL lanes in level L to complete (topological invariant)
  WAIT_LEVEL_COMPLETE(L)

  # Per-level verify (Step 7.5.3a)
  FOR each module_slug IN $TOPOLOGICAL_LEVELS[L]:
    ASSERT test -s "$SESSION_DIR/lanes/L{L}/{module_slug}/signals.json"

  # L2 Checkpoint (Step 7.5.3b)
  FOR each module_slug IN $TOPOLOGICAL_LEVELS[L]:
    UPDATE $SESSION_DIR/session-state.json:
      phases.P7_5.batches["L{L}-{module_slug}"].status = "completed"

# Mỗi lane agent thực hiện:
# 1. FOR each feature IN module_features:
#    IF test -f task_path AND test -s task_path → skip (idempotent)
#    READ template → POPULATE → WRITE task_path (Template Usage Rule CORE-031)
#    IF LEGACY: READ impl-strategy.md.tpl → POPULATE → INJECT (sau A1-A6, trước A7)
# 2. WRITE signals.json (lane output — danh sách task_ids đã tạo + strategies)
```

**Lane output schema (`signals.json`):**

```json
{
  "lane_type": "module",
  "module_slug": "{module-slug}",
  "topological_level": 0,
  "items": [
    {
      "task_id": "TASK-MOD-001",
      "feat_id": "FEAT-CRM-001",
      "module_slug": "crm",
      "implementation_strategy": "IMPLEMENT_NEW",
      "existing_code_refs": [],
      "estimated_hours": 4
    }
  ]
}
```

**Topological constraint:** Level L+1 PHẢI WAIT tới khi TẤT CẢ level L lanes complete (enforce trong dispatcher). KHÔNG skip constraint này.

**Write-scope isolation:** Mỗi module lane ghi vào `phase5-implementation/tasks/{sys}/{mod}/` riêng — không conflict.

---

## §Quality Sections Computation (Step 7.5.2a chi tiết — v5.1+)

> Trước khi spawn architect agents, compute `$QUALITY_SECTIONS` và `$ENV_NOTES` cho từng feature.
> Inject vào lane context để architect POPULATE A2.5 Quality Requirements + A2.6 Environment Notes.

### Source Detection

| Step | Action | Source |
|------|--------|--------|
| QS1 | Đọc `req-registry.json` → `departments[]`, `interface_type`, module prefix | Registry |
| QS2 | Đọc `project-profile.json` (LEGACY_MODE) hoặc scan `package.json` (new) | Tech stack |
| QS3 | Map module prefix → checklist items (xem §Module Prefix Checklist Mapping) | Derived |
| QS4 | Map `interface_type` → sections enabled (xem §Interface Type Section Mapping) | Derived |
| QS5 | Map `departments[]` → domain-specific items (xem §Domain-Specific Checklist) | Derived |

### Module Prefix Checklist Mapping

| Module prefix | Extra security items | Extra data items | Notes |
|---------------|---------------------|------------------|-------|
| `auth` | AUTH-01, AUTH-02, INPUT-01, RATE-01 | — | Auth-focused security |
| `payment`, `wallet` | INPUT-01, SQL-01 | DATA-01 (audit trail), CONS-01 | Financial data integrity |
| `crm`, `profile` | INPUT-01 | VALID-01, FK-01 | Customer data + i18n/a11y enabled |
| `admin` | INPUT-01, SQL-01 | CONS-01 | Admin dashboard + a11y enabled |
| `api`, `webhook` | ENV-01, RATE-01, INPUT-01 | — | API-focused |
| `default` | INPUT-01, SQL-01, XSS-01 | VALID-01, FK-01 | Standard security + data |

### Interface Type Section Mapping

| interface_type | A2.5 Sections enabled | A2.6 enabled |
|----------------|----------------------|--------------|
| `web` | Tất cả (Security + Data Integrity + i18n + Accessibility + Performance) | Yes |
| `mobile` | Security + Data Integrity + i18n (skip A11Y web-specific như focus trap, htmlFor) | Yes |
| `api-only` | Security + Data Integrity only | Yes (server-focused) |

### Domain-Specific Checklist (v5.1+)

| Domain | Module IDs (prefix match) | Extra checklist items |
|--------|--------------------------|----------------------|
| **E-commerce** | `orders`, `products`, `cart`, `checkout` | Payment security (PCI-DSS), inventory sync, order idempotency |
| **Finance** | `finance`, `accounting`, `tax`, `wallet`, `debt` | Audit trail, tính chính xác số học, currency rounding |
| **Logistics** | `tms`, `wms`, `customs`, `sourcing` | HS Code accuracy, Incoterms, container tracking |
| **HR** | `hrm`, `payroll` | Labor law compliance, tax withholding, data privacy |
| **CRM** | `crm`, `marketing`, `loyalty` | Customer data privacy, consent management, campaign attribution |
| **Healthcare** | `patient`, `emr`, `clinic`, `prescription` | Data privacy (HIPAA-equivalent), audit trail, consent |
| **Insurance** | `policy`, `claims`, `underwriting`, `premium` | Policy compliance, premium calculation accuracy, claims audit |
| **Real Estate** | `property`, `lease`, `contract` | Legal compliance, document management, payment tracking |
| **Education** | `course`, `student`, `teacher`, `exam` | Student data privacy, grading accuracy, attendance tracking |
| **Manufacturing** | `production`, `bom`, `workorder`, `quality` | BOM accuracy, MRP integrity, production traceability |
| **Procurement** | `vendor`, `sourcing`, `rfq`, `po` | Vendor due diligence, contract compliance, spend controls |
| **Retail** | `store`, `pos`, `inventory`, `loyalty` | POS reliability, inventory sync, loyalty program compliance |

**Mapping logic:** Đọc `req-registry.json` → `departments[]` field → map sang domain (case-insensitive prefix match với domain tên) → inject domain-specific checklist items.

### Environment Notes Detection

| Step | Detection | A2.6 Row |
|------|-----------|----------|
| EN1 | `"vite"` in devDependencies | Build tool: Vite — dùng `import.meta.env.VITE_*` cho client, KHÔNG dùng `process.env` |
| EN2 | `"react"` in dependencies | Framework: React — Strict Mode, hooks exhaustive-deps, useEffect cleanup |
| EN3 | `"tailwindcss"` in devDependencies | CSS: Tailwind — dùng `@apply` trong CSS modules, KHÔNG CDN trong production |
| EN4 | `"hono"` or `"express"` in dependencies | Server: [name] — validate env vars at startup, throw nếu thiếu |
| EN5 | `"better-sqlite3"` in dependencies | Database: SQLite — PRAGMA foreign_keys = ON, parameterized queries |
| EN6 | `"prisma"` in dependencies | Database: Prisma — migrate dev trước generate, KHÔNG push trực tiếp |
| EN7 | `"typeorm"` in dependencies | Database: TypeORM — synchronize=false trong production |
| EN8 | `"next"` in dependencies | Build tool: Next.js — `NEXT_PUBLIC_*` cho client, server components dùng `process.env` |

### Inject vào Lane Context

```
Trong TASK_GENERATION_PROMPT_TEMPLATE (Step 7.5.3), thêm:
  quality_sections     = $QUALITY_SECTIONS[module_slug]   # A2.5 content per module
  env_notes            = $ENV_NOTES[module_slug]          # A2.6 table per module
  domain_checklist     = $DOMAIN_CHECKLIST[module_slug]   # Domain-specific items

Architect POPULATE:
  1. A2.5 Quality Requirements: render Security + Data Integrity + conditional sections
  2. A2.6 Environment Notes: render table từ env_notes
  3. Append domain-specific items vào Security checklist (nếu có)
```

---

## §Implementation Strategy Inject (LEGACY only)

> ⚠️ **FORMAT BẮT BUỘC:** Heading PHẢI là `## ⚠️ Implementation Strategy: [VERIFY_ONLY | COMPLETE_EXISTING | IMPLEMENT_NEW]`
> KHÔNG dùng "Strategi", "Strategy" (thiếu ⚠️), hay bất kỳ biến thể nào khác.
> Section wrapper "Phần 0" là KHÔNG hợp lệ — dùng đúng heading trên.

Template chi tiết: `templates/implementation-strategy.md.tpl`

Khi POPULATE:
- `[VERIFY_ONLY | COMPLETE_EXISTING | IMPLEMENT_NEW]` → strategy từ `$FEATURE_IMPL_MAP[feature.id].strategy`
- `[file_path]`, `[X]-[Y]` → từ `$FEATURE_IMPL_MAP[feature.id].existing_code_refs`
- `[gap 1]`, `[gap 2]` → từ `$FEATURE_IMPL_MAP[feature.id].gaps_identified`

---

## §A6-EXT Generation (Step 7.5.5 chi tiết)

**Architect đọc (BẮT BUỘC theo thứ tự):**
1. Template `.claude/doc-framework/_meta/a6-ext-fragment.md` (CORE-031 — structured fragment)
2. Feature spec (Phase 2): `phase2-features/[sys]/[mod]/[feat].md`
3. Design docs (Phase 3): `phase3-architecture/`
4. UX design nếu có (Phase 4): `phase4-ux/`

**Architect POPULATE template a6-ext-fragment.md (KHÔNG viết tự do), bao gồm:**
- A6-EXT.0 Coverage Summary (BẮT BUỘC) — total files, methods, test cases, REQ-IDs
- A6-EXT.1 File Specifications — mỗi file: Imports, Fields/Relations (Entity), Methods + Test Cases (Service/Repo/Controller), DTOs, API Endpoints (Controller)
- A6-EXT.2 Cross-File Contracts — interfaces share giữa các files
- A6-EXT.3 Verification Checklist — architect tự check 8 items TRƯỚC khi APPEND

**Đồng thời architect POPULATE section A2.4 Scope Files & Parallel Safety (BẮT BUỘC — phục vụ multi-session parallel):**
- Liệt kê TẤT CẢ files feature này tạo/sửa với mode chính xác:
  - `EXCLUSIVE_WRITE` — chỉ feature này ghi (entity, service, controller, test riêng)
  - `EXCLUSIVE_CREATE` — file mới (migration với timestamp unique)
  - `SHARED_APPEND` — file shared (src/shared/types.ts, registry, ...) — append-only
  - `SHARED_READ` — chỉ đọc
- Cột `Shared with Features` — list FEAT-IDs của features khác cũng touch file đó (cross-reference với các features trong cùng layer/sprint)
- Cuối section: `Parallel-Safe Verdict` = `SAFE_PARALLEL` HOẶC `REQUIRES_SEQUENTIAL_WITH: FEAT-XXX-NNN` (kèm lý do)

**Quy tắc:** KHÔNG modify A1-A6 sections — chỉ THÊM A6-EXT.

**Quality gates (architect tự enforce, Phase 7a check 7a.12 verify):**
- ≥1 file spec
- Mỗi Service/Repository/Controller có ≥1 method với ≥1 happy + ≥1 error test case
- Mỗi Entity có Fields table ≥1 row
- Mỗi Controller có API Endpoints table
- Tổng word count ≥200 từ
- KHÔNG còn placeholder `[...]` sau POPULATE

**Execution:** `[PAR]` PARALLEL per system. Mỗi feature = 1 agent spawn (architect).

**Agent prompt (sample):**
```
Bạn là architect. POPULATE Section A6-EXT (Executable Implementation Spec) cho task file:
[task_path]

BẮT BUỘC:
1. READ template `.claude/doc-framework/_meta/a6-ext-fragment.md` TRƯỚC TIÊN.
2. POPULATE template với data thực tế từ feature spec + architecture + UX.
3. Self-check Verification Checklist (A6-EXT.3) — 8 items PHẢI pass.
4. APPEND vào task file (KHÔNG modify A1-A6).

Context inputs:
- Template: .claude/doc-framework/_meta/a6-ext-fragment.md
- Feature spec: [path tới phase2-features/[sys]/[mod]/[feat].md]
- Architecture: [path tới phase3-architecture/]
- UX (nếu có): [path tới phase4-ux/]

Quality gates (Phase 7a 7a.12 sẽ verify):
- ≥1 file spec với Imports table
- Mỗi Service/Repo/Controller: ≥1 method + ≥1 happy + ≥1 error test case
- Mỗi Entity: Fields table ≥1 row
- Mỗi Controller: API Endpoints table
- Coverage Summary đầy đủ (total_files, methods, test_cases, REQ-IDs)
- Tổng ≥200 từ, KHÔNG còn `[...]` placeholder

A2.4 Scope Files quality gates (Phase 7a 7a.13 sẽ verify):
- A2.4 section tồn tại trong task file
- Bảng có ≥1 row file với mode hợp lệ (EXCLUSIVE_WRITE/CREATE, SHARED_APPEND/READ)
- Mỗi row có path absolute (bắt đầu `src/`, `apps/`, `tests/`, ...)
- `Parallel-Safe Verdict` line tồn tại với 1 trong 2 giá trị: SAFE_PARALLEL hoặc REQUIRES_SEQUENTIAL_WITH:

Output mục tiêu: ~500-1500 từ section A6-EXT, structured theo template, đủ depth để
developer agent (wf-implement-feature) code mà KHÔNG cần load Phase 2/3 docs.
```

---

## §A7-EXT Generation (Step 7.5.6 chi tiết)

**Trigger condition:** feature có ≥ 3 files HOẶC estimated time > 15 phút.

**Skip condition:** feature có ≤ 2 files → SKIP A7-EXT (feature quá nhỏ để chia).

**Architect tạo Section A7-EXT chứa:**
- Micro-task IDs (`MT-[FEAT]-[NNN]`)
- Names + estimated times (≤ 15 min mỗi)
- Input specs (cụ thể section nào của A6-EXT)
- Output files
- Success criteria
- Dependencies giữa micro-tasks
- `context_from_previous` (state nào cần load)

**Quy tắc:** KHÔNG modify A1-A6-EXT sections — chỉ THÊM A7-EXT.

**Execution:** `[PAR]` PARALLEL per system (cùng architect agent từ 7.5.5).

**Agent prompt (sample):**
```
Bạn là architect. Tạo Section A7-EXT (Micro-Task Breakdown) cho task file:
[task_path]

Pre-condition: A6-EXT đã có. Đọc A6-EXT → tách thành micro-tasks ≤ 15 min.

A7-EXT phải bao gồm:
- Micro-task IDs (MT-[FEAT]-[NNN])
- Names, estimated times (≤ 15 min)
- Input specs (section A6-EXT nào)
- Output files
- Success criteria
- Dependencies giữa micro-tasks
- context_from_previous

Sequential micro-tasks → đánh số (1, 2, 3); parallel → đánh chữ (a, b, c).

Template Usage Rule: READ task file → APPEND A7-EXT section → WRITE.
```

---

## §Generate parallel-safe-groups.md (Step 7.5.7 — BẮT BUỘC sau A2.4 populated)

> **Mục đích:** Tổng hợp A2.4 Scope Files từ TẤT CẢ task files → sinh `parallel-safe-groups.md`
> hướng dẫn user chạy multi-session `/wf-implement-feature` an toàn.

| Step | Action | Verify |
|------|--------|--------|
| 7.5.7 | **[Template Rule + Atomic Write]** READ template `.claude/doc-framework/phase5-implementation/parallel-safe-groups.md` → POPULATE bằng aggregation logic dưới → WRITE `.mc-data/docs/phase5-implementation/parallel-safe-groups.md` | `test -s parallel-safe-groups.md` |

**Aggregation logic:**

```bash
# 1. Đọc tất cả task files
TASK_FILES=$(find .mc-data/docs/phase5-implementation/tasks -name "*-impl.md")

# 2. Cho mỗi task file, extract A2.4 Scope Files table → build feature_scope_map
#    feature_scope_map[FEAT-ID] = {
#      exclusive_write: [list paths],
#      exclusive_create: [list paths],
#      shared_append: [list paths],
#      shared_read: [list paths],
#      parallel_safe_verdict: "SAFE_PARALLEL" | "REQUIRES_SEQUENTIAL_WITH:..."
#    }

# 3. Cross-reference với $LAYERS (Phase 4 output) để group theo Layer
#    GROUP_N = features cùng Layer N

# 4. Trong mỗi GROUP_N, detect conflict:
#    FOR each pair (FEAT-A, FEAT-B) trong group:
#      IF intersection(A.exclusive_write, B.exclusive_write OR B.exclusive_create) non-empty:
#        → mark cặp này SEQUENTIAL_REQUIRED, ghi vào "Sequential-Required Pairs"
#      IF FEAT-B listed trong FEAT-A.A2.3 Dependencies (hoặc ngược lại):
#        → SEQUENTIAL_REQUIRED (depends-on)
#      ELSE:
#        → cặp này SAFE_PARALLEL trong group

# 5. Populate template:
#    - Section "2. Parallel-Safe Groups" — mỗi Layer là 1 group
#    - Mỗi feature có bảng EXCLUSIVE_WRITE Files + SHARED_APPEND Files
#    - Section "3. Sequential-Required Pairs" — list cặp conflict + lý do
#    - Estimated parallel speedup: tính từ feature count + avg time

# 6. Verify aggregation:
#    - Mọi feature trong registry (trừ DEPRECATED) phải xuất hiện trong ít nhất 1 group
#    - Tổng features trong groups = total active features
```

**Backward compatibility:** Nếu A2.4 thiếu trong 1 task file → log WARNING + treat feature đó là `REQUIRES_SEQUENTIAL` (conservative default) thay vì block toàn bộ skill.

---

## POST-GATE

- Mỗi feature trong registry có file `-impl.md` tương ứng (trừ DEPRECATED modules nếu LEGACY)
- LEGACY: mỗi task file có Implementation Strategy section
- Feature có ≥ 3 files: task file có A6-EXT section
- Mỗi task file có A2.4 Scope Files section + Parallel-Safe Verdict (BẮT BUỘC v3.2+)
- **(v5.1+):** Mỗi task file có A2.5 Quality Requirements section (Security + Data Integrity checklists populated; i18n/Accessibility/Performance conditional)
- **(v5.1+):** Mỗi task file có A2.6 Environment Notes section (table populated với build tool, framework, CSS, server, database)
- File `.mc-data/docs/phase5-implementation/parallel-safe-groups.md` tồn tại + non-empty
- Feature có ≥ 3 files HOẶC estimated time > 15 min: task file có A7-EXT section (hoặc rõ ràng skip)

---

## Next

→ Checkpoint: position → `phase_7a`
→ Read `procedures/phase7a-verify.md`
