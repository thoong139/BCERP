# Shared Protocols — wf-legacy-classify

> Cross-cutting protocols, state variables glossary, agent prompt templates và classification reference được chia sẻ bởi nhiều Phase trong wf-legacy-classify.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Maturity Modes](#maturity-modes)
- [DOCS_ONLY Mode](#docs_only-mode)
- [Classification Types (Source Mode)](#classification-types-source-mode)
- [Classification Types (DOCS_ONLY Mode)](#classification-types-docs_only-mode)
- [Classified Item Schema](#classified-item-schema)
- [System vs Module Detection](#system-vs-module-detection)
- [Agent Prompt Templates](#agent-prompt-templates)
- [Fix Rules](#fix-rules)
- [Error Codes](#error-codes)
- [Scan-State Integration (v5.0 Phase D)](#scan-state-integration-v50-phase-d)
- [Checkpoint Protocol](#checkpoint-protocol)
- [Naming Convention](#naming-convention)

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$ARGS` | Phase 0 | All | Parsed arguments — `{resume, batch_size, status}` |
| `$BATCH_SIZE` | Phase 0 | 1, 2 | Số items mỗi batch (10-500, default 100) |
| `$MATURITY_MODE` | Phase 0 | 1, 2, 3, 5, 6 | `full` / `delta` / `skip` từ `ledger.maturity.stage_modes.classify` |
| `$MATURITY_LEVEL` | Phase 0 | 1, 2 | `FULL` / `DOCS_ONLY` / `EARLY_PROTOTYPE` / ... từ ledger |
| `$DOCS_ONLY_MODE` | Phase 0 | 1, 2 | Boolean — true nếu `maturity_level == "DOCS_ONLY"` (source_count == 0) |
| `$INVENTORY_FILE` | Phase 1 | 1, 2 | `source-files.json` (default) hoặc `doc-classified.json` (DOCS_ONLY) |
| `$BATCH_OFFSET` | Phase 0 (resume), 1 | 2 | Số batches đã hoàn thành — bắt đầu từ `batch_offset+1` |
| `$TOTAL_BATCHES` | Phase 1 | 2, 4, 6 | `ceil(unclassified_count / batch_size)` (lần đầu) hoặc giữ nguyên (resume) |
| `$UNCLASSIFIED_LIST` | Phase 1 | 2 | Array paths chưa có trong bất kỳ `classified/batch-*.json` |
| `$EXISTING_MODULES` | Phase 2 (per batch) | 2 (next batch) | Unique `(system, module)` pairs từ các batch đã hoàn thành |
| `$TOTAL_ITEMS` | Phase 1 | 4, 6 | Tổng items trong inventory (`ledger.summary.total_items`) |
| `$ITEMS_CLASSIFIED` | Phase 2 (cumulative) | 4, 6 | Sum stats.total từ tất cả `classified/batch-*.json` |
| `$NEW_MODULES_LOG` | Phase 2 (per batch) | 6 | Array module names mới phát hiện qua các batches |
| `$NAMING_FIXES` | Phase 5 | 5, 6 | Array fixes áp dụng theo CORE-016 (case dedup, kebab-case) |
| `$CONTEXT_PERCENT` | Every phase | 2 | Context budget — trigger checkpoint at 65/80% |
| `error_log[]` | All phases | 6 | Array errors — dùng cho report + auto-fix decision |

---

## Cross-Phase Data Flow

```
Phase 0 (init)        → $ARGS, $BATCH_SIZE, $MATURITY_MODE, $MATURITY_LEVEL,
                        $DOCS_ONLY_MODE, $BATCH_OFFSET (nếu resume),
                        legacy-scan-status.json (init)
Phase 1 (prepare)     → $UNCLASSIFIED_LIST, $TOTAL_BATCHES, $TOTAL_ITEMS,
                        classify-plan.md
Phase 2 (classify)    → classified/batch-N.json (loop), $EXISTING_MODULES (cumulative),
                        $ITEMS_CLASSIFIED (cumulative), $NEW_MODULES_LOG,
                        checkpoint.json (per 3 batches)
Phase 3 (glossary)    → classified/glossary.json
Phase 4 (verify)      → Auto-fix re-classify (nếu < 95%)
Phase 5 (postgate)    → classify-naming-fixes.json (nếu CORE-016 fires),
                        $NAMING_FIXES
Phase 6 (finalize)    → ledger.json (status=completed),
                        legacy-scan-status.json (current_stage=extract),
                        phase-summary.md
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước. KHÔNG được SET lại variables của phase khác.

---

## Maturity Modes

`$MATURITY_MODE` đến từ `ledger.maturity.stage_modes.classify`:

| Mode | Hành vi |
|------|---------|
| `full` | Classify TẤT CẢ items trong inventory (lần đầu hoặc fresh re-run) |
| `delta` | Chỉ classify items CHƯA có trong bất kỳ `classified/batch-*.json` (incremental) |
| `skip` | Bỏ qua toàn bộ Stage 2, đánh dấu `stages.classify.status = "completed"` với note `"skipped_maturity"` |

**Quy tắc:**
- `skip` mode: chỉ chạy Phase 0 (mark skipped) + Phase 6 (finalize), KHÔNG chạy Phase 1-5
- `delta` mode: Phase 1 compute `$UNCLASSIFIED_LIST` bằng cách so sánh inventory vs existing batches
- `full` mode: Phase 1 set `$UNCLASSIFIED_LIST` = toàn bộ inventory (nếu chưa resume)

---

## DOCS_ONLY Mode

Khi `ledger.maturity.maturity_level == "DOCS_ONLY"` (`source_count == 0`):

- `$DOCS_ONLY_MODE = true`
- `$INVENTORY_FILE = inventory/doc-classified.json` (thay vì `source-files.json`)
- Classification dùng **doc_type** thay vì source code categories
- Agent code-reviewer nhận prompt biến thể (DOCS_ONLY block — xem [Agent Prompt Templates](#agent-prompt-templates))
- Glossary vẫn được tạo từ domain terms trong docs

---

## Classification Types (Source Mode)

| Type | Mô tả | Ví dụ file |
|------|-------|------------|
| `screen` | UI component, page, view | `LoginPage.tsx`, `Dashboard.vue` |
| `api` | Route handler, controller, endpoint | `auth.controller.ts`, `routes/users.py` |
| `doc` | README, wiki, markdown, spec | `README.md`, `API.md`, `CHANGELOG` |
| `source` | Service, repository, utility, helper | `auth.service.ts`, `user.repo.go` |
| `config` | Cấu hình, env, docker | `.env.example`, `docker-compose.yml` |
| `test` | Unit test, integration test, e2e | `auth.test.ts`, `test_user.py` |
| `asset` | Ảnh, font, file tĩnh | `logo.svg`, `fonts/`, `public/` |
| `migration` | DB migration files | `20240101_create_users.sql`, `*.migration.ts` |
| `type` | Type definitions, interfaces | `*.d.ts`, `types/index.ts`, `*.interface.ts` |
| `UNKNOWN` | Khi confidence < 0.7 | — |

**Lưu ý classify:** Agent classify THEO CHỨC NĂNG, không theo đuôi file hay tên thư mục.
Ví dụ: `utils/auth-helper.ts` → type=`source` (không phải `config` dù nằm trong `utils/`).

---

## Classification Types (DOCS_ONLY Mode)

| Doc Type | Mô tả | Ví dụ |
|----------|-------|-------|
| `prd` | Product requirements, BRD, user stories | `PRD-v2.md`, `requirements.md` |
| `spec` | Technical specification, architecture | `system-design.md`, `tech-spec.md` |
| `wireframe` | UI mockups, wireframe descriptions | `wireframes.md`, `mockup-notes.md` |
| `meeting_notes` | Meeting minutes, brainstorm notes | `meeting-2026-01.md`, `notes.md` |
| `api_spec` | API documentation, OpenAPI specs | `api-docs.md`, `openapi.yaml` |
| `user_guide` | User manuals, tutorials, how-tos | `user-guide.md`, `tutorial.md` |
| `process_doc` | SOP, workflow descriptions, process maps | `workflow.md`, `sop-onboard.md` |
| `general` | Không xác định được loại cụ thể | `misc.md`, `draft.md` |
| `UNKNOWN` | Khi confidence < 0.7 | — |

---

## Classified Item Schema

Mỗi item trong `classified/batch-N.json` `items[]` PHẢI có đầy đủ các fields sau:

```json
{
  "path": "string — đường dẫn file tương đối từ project root",
  "system": "string — tên system (top-level app/package, vd: erp-backend, erp-frontend)",
  "module": "string — tên module chức năng (vd: auth, sales, inventory)",
  "type": "screen|api|doc|source|config|test|asset|migration|type (HOẶC doc_type khi DOCS_ONLY)",
  "importance": "high|medium|low",
  "confidence": 0.0-1.0
}
```

**importance** — mức độ quan trọng của file đối với hệ thống:
- `high`: Core business logic, API endpoints chính, database models
- `medium`: Utilities, helpers, UI components phụ
- `low`: Assets, configs, test fixtures, generated files

**confidence** — độ tin cậy của phân loại (0.0-1.0). Nếu < 0.7 → type = `UNKNOWN`

### Batch File Schema

```json
{
  "batch_number": N,
  "stats": {
    "total": N,
    "by_category": { "screen": N, "api": N, ... },
    "by_system": { "[sys]": N, ... },
    "by_module": { "[mod]": N, ... }
  },
  "items": [ {classified item}, ... ],
  "new_modules": ["list module names MỚI chưa có trong existing_modules_list"]
}
```

---

## System vs Module Detection

Agent code-reviewer phân biệt system và module theo quy tắc:

- **System** = top-level app hoặc package có thể deploy độc lập. Nhận diện qua:
  - Thư mục gốc (`apps/backend`, `apps/frontend`, `packages/shared`)
  - Hoặc `package.json` / `build.gradle` / `Cargo.toml` riêng
- **Module** = nhóm chức năng nghiệp vụ trong 1 system. Nhận diện qua:
  - Thư mục con có chung domain (`auth/`, `sales/`, `inventory/`)
  - Hoặc naming pattern (`*-service`, `*-controller`, `*-module`)

**Ví dụ:** `apps/backend/src/auth/auth.service.ts` → system=`backend`, module=`auth`

---

## Naming Convention

`system` và `module` names PHẢI tuân thủ:

- **lowercase-kebab-case** (vd: `erp-backend`, `order-management`)
- KHÔNG dùng: `PascalCase`, `camelCase`, `UPPERCASE`, tiếng Việt có dấu
- KHÔNG viết tắt tùy ý: dùng tên đầy đủ, nhất quán
- KHI gặp module mới: log "NEW_MODULE" trong batch output `new_modules[]`
- KHÔNG tạo tên tương tự tên đã có (vd: đã có `auth` → KHÔNG tạo `authentication`)

---

## Agent Prompt Templates

### code-reviewer Agent — Classify Batch (Phase 2)

```
Bạn là code-reviewer. Phân loại [batch_size] files từ dự án [project_name].

INPUT:
- Danh sách files cần classify (paths + extensions)
- Project profile: [tech_stack], [frameworks]
- EXISTING MODULE NAMES (từ các batch trước): [existing_modules_list]
  → Nếu list rỗng (batch đầu tiên): tự do đặt tên theo NAMING CONVENTION bên dưới
  → Nếu list có entries: BẮT BUỘC dùng CHÍNH XÁC tên đã có. Chỉ tạo tên MỚI khi file
    KHÔNG thuộc bất kỳ module nào trong danh sách.

NAMING CONVENTION (BẮT BUỘC):
- system: lowercase-kebab-case (vd: erp-backend, erp-frontend, mobile-app)
- module: lowercase-kebab-case (vd: auth, sales, order-management, inventory)
- KHÔNG dùng: PascalCase, camelCase, UPPERCASE, tiếng Việt có dấu
- KHÔNG viết tắt tùy ý: dùng tên đầy đủ, nhất quán (vd: "authentication" KHÔNG viết "auth"
  NẾU batch trước đã dùng "auth")

SYSTEM vs MODULE:
- System = top-level app hoặc package có thể deploy độc lập.
  Nhận diện qua: thư mục gốc (apps/backend, apps/frontend, packages/shared),
  hoặc package.json/build.gradle/Cargo.toml riêng.
- Module = nhóm chức năng nghiệp vụ trong 1 system.
  Nhận diện qua: thư mục con có chung domain (auth/, sales/, inventory/),
  hoặc naming pattern (*-service, *-controller, *-module).
  Ví dụ: apps/backend/src/auth/auth.service.ts → system=backend, module=auth

NHIỆM VỤ:
Với mỗi file, xác định:
1. system: (theo NAMING CONVENTION + EXISTING MODULE NAMES)
2. module: (theo NAMING CONVENTION + EXISTING MODULE NAMES)
3. type: một trong [screen, api, doc, source, config, test, asset, migration, type]
   [DOCS_ONLY override] doc_type: một trong [prd, spec, wireframe, meeting_notes, api_spec, user_guide, process_doc, general]
4. importance: high (core business) | medium (utilities, UI phụ) | low (assets, configs, generated)
5. confidence: 0.0-1.0 (độ tin cậy). Nếu < 0.7 → type = "UNKNOWN"

Khi gặp MODULE MỚI chưa có trong EXISTING MODULE NAMES:
- Dùng lowercase-kebab-case
- Ghi note "NEW_MODULE" trong batch output metadata
- KHÔNG tạo tên tương tự tên đã có (vd: đã có "auth" → KHÔNG tạo "authentication")

CLASSIFY THEO CHỨC NĂNG, không theo đuôi file hay tên thư mục.
Ví dụ: utils/auth-helper.ts → type=source (không phải config)

OUTPUT: Ghi vào classified/batch-[N].json theo schema:
{
  "batch_number": N,
  "stats": { "total": N, "by_category": { "screen": N, ... }, "by_system": {}, "by_module": {} },
  "items": [{ "path", "system", "module", "type", "importance", "confidence" }],
  "new_modules": ["list các module names MỚI chưa có trong existing_modules_list"]
}
```

### business-analyst Agent — Glossary (Phase 3)

```
Bạn là business-analyst. Tạo glossary thuật ngữ domain từ dự án [project_name].

INPUT: Tất cả classified/batch-*.json files

TEMPLATE SCHEMA (BẮT BUỘC tuân thủ — đọc từ templates/glossary.json):
{
  "$schema": "legacy-scan-glossary-v1",
  "project": "[project_name]",
  "created_at": "[ISO date]",
  "created_by": "business-analyst",
  "terms": [...],
  "abbreviations": [...],
  "domain_concepts": [...],
  "stats": { "total_terms": N, "total_abbreviations": N, "total_domain_concepts": N, "modules_covered": [] }
}

NHIỆM VỤ:
1. Scan items để phát hiện domain terms (từ chuyên ngành, viết tắt, khái niệm)
2. Nhóm theo 3 categories: terms, abbreviations, domain_concepts
3. Mỗi term entry có: term, definition, context, source_files (1-3 files tiêu biểu), related_modules, frequency
4. Mỗi abbreviation entry có: abbr, full_form, context
5. Mỗi domain_concept entry có: concept, description, related_modules
6. Điền stats: total_terms, total_abbreviations, total_domain_concepts, modules_covered

OUTPUT: Ghi vào classified/glossary.json theo template schema trên (BẮT BUỘC có $schema, project, created_at, created_by, stats).
```

---

## Fix Rules

| Loại lỗi | Auto-Fix | Escalate nếu |
|----------|----------|--------------|
| Classify batch timeout (E006) | Giảm batch_size / 2, retry (100→50→25→12) | batch_size < 10 |
| Classified < 95% (E019) | Auto-fix x3: re-classify missing files | Vẫn < 95% sau 3 attempts |
| Batch JSON corrupt (E020) | Xóa batch file, re-classify batch đó | Corrupt > 2 batches liên tiếp |
| Glossary failed (E021) | Retry business-analyst agent (max 2) | Vẫn fail sau 2 retries → tạo glossary từ template (empty values) |
| Naming inconsistency CORE-016 | Auto-fix lowercase-kebab-case + dedup case-insensitive | Fuzzy match (Levenshtein <=2) → ASK user |

> **Retry:** Mỗi step retry tối đa 3 lần. Nếu vẫn fail → escalate với thông báo đầy đủ vào `error_log[]`.

---

## Error Codes

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001 | PRE-GATE fail — `ledger.json` không tồn tại HOẶC inventory chưa completed | STOP, hướng dẫn chạy `/wf-legacy-scan` |
| E006 | Classify batch timeout hoặc agent fail | Giảm batch_size / 2, retry. Escalate nếu batch_size < 10 |
| E019 | Post-Stage 2: classified < 95% inventory | Auto-fix x3, log vào `error-ledger.json`, ASK user |
| E020 | Batch JSON file corrupt (invalid JSON hoặc partial write) | Xóa batch file, re-classify batch đó. Escalate nếu > 2 batches liên tiếp |
| E021 | Glossary creation failed (business-analyst agent error) | Retry agent tối đa 2 lần. Nếu vẫn fail → tạo glossary rỗng với warning |
| E022 | 0 unclassified items nhưng mode != skip (có thể inventory rỗng hoặc lỗi logic) | WARNING, ASK user xác nhận tiếp tục hay STOP |
| E023 | Invalid `--batch-size` argument (< 10 hoặc > 500) | STOP, hiển thị message lỗi với valid range [10-500] |

---

## Scan-State Integration (v5.0 Phase D)

> **Áp dụng:** khi skill chạy trong orchestrator mode (có scan-state.json session) HOẶC
> chạy standalone sau khi v5.0 đã migrate (helper auto-detect).
> Legacy mode (chỉ có ledger.json v4.1) — helper tự migrate → scan-state qua 1 call.

### Helper Module

```
Module:  .claude/skills/workflow/_shared/ips/scan_state_reader.py
Public API dùng trong skill này:
- init_or_load_session(project_path) → session_id
  • Active session → return luôn
  • Chỉ có ledger.json v4.1 → migrate + init session mới
  • Không có gì → RuntimeError("No prior scan")
- update_layer_status("L4", status)  # state machine: not_started→in_progress→completed|failed
- update_batch_progress("L4", {current, total, completed_batches})
- append_layer_output("L4", "classified/batch-N.json")  # dedup idempotent
- append_error("L4", {code, message, context})
```

### Usage Pattern trong Phase 0 (init)

```
# Pseudo-code — gọi trong phase0-init.md Step 0.7
SESSION_ID = init_or_load_session(project_path=".")
update_layer_status("L4", "in_progress")
# Log thông báo cho user: "Session [SESSION_ID] — L4 classification started"
```

### Usage Pattern trong Phase 2 (per batch)

```
# Sau khi ghi classified/batch-N.json thành công:
append_layer_output("L4", "classified/batch-{N}.json")
update_batch_progress("L4", {
  "current": N,
  "total": $TOTAL_BATCHES,
  "completed_batches": list(1..N)
})
```

### Usage Pattern trong Phase 6 (finalize)

```
# Normal completion:
update_layer_status("L4", "completed")

# Skip mode:
update_layer_status("L4", "skipped_by_profile")

# Failure sau retry exhaust:
update_layer_status("L4", "failed")
append_error("L4", {code: "E019", message: "<95% coverage sau 3 auto-fix"})
```

### Backward Compat (Dual-write Transition)

- Sub-skill TIẾP TỤC ghi ledger.json fields (`stages.classify.*`) trong transition period
  (v5.0 → v5.1) để không break v4.1 consumer scripts.
- Khi scan-state.json có mặt: CẢ HAI đều được update (dual-write).
- Khi chỉ có ledger.json (standalone sau v4.1 scan): helper tự migrate → scan-state xong rồi dual-write.
- Rationale: canonical state sẽ là scan-state.json. ledger.json chuyển thành projection-only
  do wf-legacy-scan Phase 4 tự sinh (ADR-LS04 revised).

### Khi KHÔNG Gọi Helper

- Khi skill kết thúc bằng E001 (PRE-GATE fail) trước khi biết session.
- Khi `--status` handler chỉ đọc (không mutate state).
- Khi hoàn toàn không có scan-state.json VÀ không có ledger.json (trường hợp orphan).

---

## Checkpoint Protocol

Multi-session skill (LARGE projects). Checkpoint sau mỗi 3 batches.

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục |
| 65-80% | Chuẩn bị checkpoint |
| 80-90% | Lưu checkpoint, STOP sau batch hiện tại |
| > 90% | FORCE STOP |

### Checkpoint File

Path: `.mc-data/work/legacy-scan/checkpoint.json` (sử dụng template `templates/checkpoint.json`)

Checkpoint chứa:
- `position.current_phase`, `position.current_batch`, `position.next_action`
- `progress.batches_completed[]`, `progress.items_classified`
- `state.maturity_mode`, `state.docs_only_mode`, `state.batch_size`
- `resume_instructions.command = "/wf-legacy-classify --resume"`

### Resume Process

1. READ `checkpoint.json` (nếu tồn tại) → `legacy-scan-status.json` (fallback) → `next_action`
2. LOAD `ledger.json` — `batch_offset = stages.classify.completed_batches`
3. **RECONCILIATION:** `actual_batches = find .mc-data/work/legacy-scan/classified/ -name "batch-*.json" | wc -l`. Tìm `first_missing_batch` = N nhỏ nhất mà `classified/batch-N.json` chưa tồn tại. Cập nhật `ledger.stages.classify.completed_batches = actual_batches` + `legacy-scan-status.json`. Log: "Reconciled: [actual_batches] batch files trên disk, tiếp tục từ batch [first_missing_batch]"
4. Validate existing `classified/batch-*.json` files (JSON valid, no partial writes)
5. Nếu batch file corrupt → xóa và đánh dấu để re-classify (E020)
6. CONTINUE từ `first_missing_batch` — **KHÔNG ghi đè batch files cũ**
