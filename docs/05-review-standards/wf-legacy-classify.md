# Tiêu chuẩn rà soát — `wf-legacy-classify` v2.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-legacy-classify/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Stage 2 của legacy pipeline — phân loại inventory thành systems/modules + types; sinh glossary thuật ngữ domain |
| **Entry point** | `procedures/phase0-init.md` |
| **Kiến trúc** | Lazy-load procedures; 7 phase files (0-6) + `_shared.md` |
| **Execution mode** | Agent delegation mỗi batch (Phase 2: `code-reviewer`) + Phase 3 (`business-analyst`) — SEQUENTIAL 1 agent/batch |
| **Đặc trưng** | `--resume`, `--status`, `--batch-size=N` (10-500, default 100); maturity-based skip mode; DOCS_ONLY mode |
| **State sharing** | **Chia sẻ `ledger.json`, `legacy-scan-status.json`, `checkpoint.json` với `wf-legacy-scan`** — KHÔNG tạo ledger riêng |
| **Output** | 7 files: `classify-plan.md`, `batch-N.json`, `glossary.json`, `classify-naming-fixes.json` (conditional), `checkpoint.json`, `phase-summary.md`, ledger updates |
| **Cross-skill** | 1 producer (`wf-legacy-scan`), 1 consumer (`wf-legacy-extract`) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-legacy-classify
  version: 2.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-legacy-classify/

profile:
  is_orchestrator: false          # có procedures riêng
  has_procedures: true
  has_templates: true
  has_phases: true                # 7 phase files

  has_state_machine: true         # share ledger.json với wf-legacy-scan + per-skill checkpoint.json
  has_resume: true                # --resume
  has_status: true                # --status
  is_multi_run: false             # ghi vào .mc-data/work/legacy-scan/ chung (share path với scan)

  spawns_agents: true             # Phase 2 code-reviewer (per batch), Phase 3 business-analyst
  has_strategy_routing: false     # không multi-strategy; maturity skip/DOCS_ONLY KHÔNG phải strategy routing

  writes_registry: false          # fields_owned: []
  registry_role: NONE

contracts:
  producers_count: 1              # wf-legacy-scan
  consumers_count: 1              # wf-legacy-extract
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ Toàn bộ A1-A10 | |
| **B** Workflow Integrity | ✅ B1-B8 | B5 (conditional) cho skip mode + DOCS_ONLY mode; B9-B10 SKIP |
| **C** Output & Template | ✅ C1-C7 | 3 templates + 2 inline schema (batch-N.json, classify-naming-fixes.json) — C6 áp dụng |
| **D** Cross-Skill | ✅ D1-D4 | 1 producer + 1 consumer; đặc thù: share path với scan (CS1) |
| **E** Protocol & CORE | ✅ E1-E14 | E12 SKIP (`is_multi_run=false`); E15-E16 SKIP (`writes_registry=false`); **E17/E18 áp dụng** (legacy pipeline) |
| **F** Determinism/Agent | ✅ F1-F4 | F5-F7 SKIP (không strategy routing; không discovery) |
| **H** Error Handling | ✅ H1-H5 | 7 error codes (E001, E006, E019-E023); chia sẻ `error-ledger.json` với scan |
| **I** Testability | ✅ I1-I5 | Cần cover: skip mode, DOCS_ONLY, multi-session resume, naming fix CORE-016 |
| **J** Idempotency | ✅ J1-J3 | J4 SKIP (không multi-run) |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Classification Taxonomy & Batch Processing

Tiêu chuẩn này **không tổng quát hóa** được — đặc thù classify logic.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | 9 classification types đầy đủ | `_shared.md §Classification Types` | Đủ 9 types: `screen`, `api`, `doc`, `source`, `config`, `test`, `asset`, `migration`, `type`. Schema `batch-N.json` items có `type` enum-bound |
| **G2** | System vs Module detection rõ ràng | `_shared.md §System vs Module Detection` | Có quy tắc rõ (scope breadth, naming pattern…) phân biệt system-level vs module-level; code-reviewer agent prompt include quy tắc này |
| **G3** | Maturity-based skip mode | `phase0-init.md §Skip Mode Handler` | PROTOTYPE / DEVKIT_COMPLETE → `stage_modes.classify == "skip"`; phase 0 early-return với status `completed (skipped_maturity)`, skip phase 1-5, vẫn chạy phase 6 |
| **G4** | DOCS_ONLY mode branch | `phase0-init.md` + `_shared.md §DOCS_ONLY Mode` | `maturity_level == "DOCS_ONLY"` và `source_count == 0` → `INVENTORY_FILE = doc-classified.json` thay vì `source-files.json`; Phase 2 classify theo `doc_type` |
| **G5** | Batch-size validation | `phase0-init.md` + E023 | `--batch-size ∈ [10, 500]`; invalid → STOP E023. Default 100 |
| **G6** | Batch timeout auto-tier | `_shared.md §Large Project Mode` + E006 | Khi timeout / agent fail → giảm batch_size: 100 → 50 → 25 → 12. Escalate nếu < 10 |
| **G7** | Coverage >= 95% check | `phase4-verify.md` + E019 | Self-diagnostic: `items_classified / total_items >= 95%`. Nếu < 95% → auto-fix x3. Vẫn thấp → log `error-ledger.json` + ASK user |
| **G8** | CORE-016 Naming Consistency | `phase5-postgate.md` | POST-GATE check naming: case-insensitive dedup (CRM ↔ crm) + kebab-case enforcement (OrderMgmt → order-management). Fix list ghi vào `classify-naming-fixes.json` (conditional output) |
| **G9** | Checkpoint mỗi 3 batches | `phase2-classify.md` | Phase 2 flush checkpoint.json mỗi 3 batches hoàn thành (H4 atomic). Context >= 80% → STOP sau batch hiện tại |
| **G10** | `--status` display format chuẩn | `phase0-init.md §--status Handler` | Output theo format SKILL.md §--status Display Format: có `Stage`, `Mode`, `Progress`, `Disk`, `Items`, `Systems`, `Modules`, `Categories`, `Errors`, `Next` |

### 2.2 NHÓM CS — Cross-skill contract đặc thù (pipeline share)

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | **Share state dir `.mc-data/work/legacy-scan/` với wf-legacy-scan** | SKILL.md §Work Directory | Classify ghi vào `.mc-data/work/legacy-scan/` (chung với scan) chứ KHÔNG phải `.mc-data/work/wf-legacy-classify/`. Chỉ `phase-summary.md` nằm ở `.mc-data/work/wf-legacy-classify/` |
| **CS2** | Ledger write đúng phạm vi | `phase6-finalize.md` | Chỉ update `ledger.stages.classify.*` (status, started_at, completed_at, batches, items_classified…). KHÔNG đụng `stages.inventory.*` hoặc `stages.extract.*`. Safe-write per CORE-006 |
| **CS3** | Inventory input đủ 2 formats | `_contract.json.inputs` + `phase1-prepare.md` | Đọc `inventory/source-files.json` (normal) hoặc `inventory/doc-classified.json` (DOCS_ONLY). Branch logic rõ ở Phase 0 → 1 |
| **CS4** | Glossary consumer là extract (không phải skill khác) | `produces_for` trong `_contract.json` | `glossary.json` + `batch-N.json` + `classify-naming-fixes.json` chỉ forward cho `wf-legacy-extract`. Không có downstream nào khác đọc trực tiếp |
| **CS5** | Classify-naming-fixes optional output | `_contract.json.outputs.working[]` | `classify-naming-fixes.json` có `required: false`, chỉ tạo khi CORE-016 fires (có fix); extract (CS4) đọc optional |

### 2.3 Constraint đặc biệt

- **Pipeline stage — share state với scan/extract** — áp dụng E17/E18 (CORE-021 LEGACY_MODE, CORE-022 legacy-decisions) nếu có branch đọc decisions. Hiện tại classify KHÔNG branch theo legacy-decisions nhưng vẫn bắt buộc chạy sau scan (PRE-GATE `ledger.stages.inventory.status == "completed"`).
- **KHÔNG ghi registry** — `fields_owned: []`. Bỏ qua E15-E16.
- **Batch JSON có inline schema** — `batch-N.json` và `classify-naming-fixes.json` không có template file; schema mô tả trong `_contract.json.notes` (C6 áp dụng — POST-GATE T3-T4 lấy schema từ description).
- **Agent prompts là CDG khi classify sai module** — misclassify có thể kéo theo extract sai, cần validate spot-check trước ghi (E11 — CORE-029).

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: `_shared.md §Classification Types` có đủ 9 types
- [ ] G3: Skip mode handler tồn tại ở `phase0-init.md`, early-return đúng
- [ ] G4: DOCS_ONLY branch: switch sang `doc-classified.json` tại Phase 0
- [ ] G7: Coverage check 95% + auto-fix x3 trong Phase 4
- [ ] G8: CORE-016 naming check + `classify-naming-fixes.json` conditional
- [ ] CS1: `classify-plan.md`, `classified/*`, `checkpoint.json` nằm trong `legacy-scan/` (share với scan), không tạo folder riêng
- [ ] CS2: Phase 6 chỉ update `ledger.stages.classify.*` — không đụng stage khác

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-legacy-classify/SKILL.md) | Overview, routing, --status Display Format, Output Report |
| [_contract.json](../../.claude/skills/workflow/wf-legacy-classify/_contract.json) | Output contract, cross-skill (scan → classify → extract) |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-legacy-classify/procedures/_shared.md) | Classification Types, System/Module Detection, Agent Prompts, Error Codes |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-legacy-classify/procedures/) | 7 phase files (0-6) |
| [templates/](../../.claude/skills/workflow/wf-legacy-classify/templates/) | 3 templates (plan/glossary/checkpoint) |
| [evals/evals.json](../../.claude/skills/workflow/wf-legacy-classify/evals/evals.json) | Test cases (517 dòng — phong phú) |
| [`wf-legacy-scan.md`](./wf-legacy-scan.md) | Peer skill — state sharing pipeline |
| [`wf-legacy-extract.md`](./wf-legacy-extract.md) | Consumer downstream |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE rules — §4b Cross-Skill, CORE-006/011/012/016/021/022/026-031 |
| [`.claude/skills/protocols/`](../../.claude/skills/protocols/) | Protocol 1/2/3/6/8/9/10/19 |

---

## 5. Ghi chú bảo trì riêng file này

- Khi skill nâng lên **version mới** → update `skill.version` + review G1-G10 (naming fixes, coverage threshold).
- Khi **Classification Types** đổi (thêm/bớt type) → cập nhật G1 và schema `batch-N.json` trong `_contract.json.notes`.
- Khi batch-size range đổi → cập nhật G5 + E023.
- Khi CORE-016 rule đổi → cập nhật G8; đảm bảo `wf-legacy-extract` Stage 3.5 Module Resolution (CORE-017) vẫn align với classify output.
- Khi `wf-legacy-scan` đổi location `legacy-scan/` → cập nhật CS1 + tất cả peer skills (scan/extract).
- File này là **read-only** trong quá trình review — findings ghi ra `reports/YYYY-MM-DD-wf-legacy-classify.md`.
