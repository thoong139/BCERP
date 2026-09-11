# Tiêu chuẩn rà soát — `wf-legacy-scan` v4.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-legacy-scan/`
> **Phiên bản rà soát:** 2.0 (2026-04-19) — refactor kế thừa common template

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Orchestrator cho legacy scan pipeline (Phase 0 → 0A → 0.5 → 1 → 2 → 3 → 4) |
| **Entry point** | `procedures/phase0-detection.md` |
| **Kiến trúc** | Lazy-load procedures, mỗi phase self-contained (PRE-GATE → STEPS → POST-GATE) |
| **Execution mode** | Hỗn hợp DETERMINISTIC (Phase 0/0A/0.5/1/4) + Agent Delegation (Phase 2/3) |
| **Strategy routing** | 7 strategies (S1-S7) dựa trên assessment maturity × vision × code/doc ratio |
| **Đặc trưng** | Có `--resume`, `--status`, `--re-vision`; multi-mode: fresh/partial/near-complete/docs-only |
| **Output** | ~20 files (12 entries trong `_contract.json.outputs.working[]`, trong đó `inventory/*.json` expand thành 8 file con) |
| **Cross-skill** | Produces cho 11 consumer skills |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-legacy-scan
  version: 4.0.0
  review_version: 2.0
  path: .claude/skills/workflow/wf-legacy-scan/

profile:
  is_orchestrator: false          # có procedures riêng, không phải orchestrator thuần
  has_procedures: true
  has_templates: true
  has_phases: true

  has_state_machine: true         # ledger.json states 0/0A/0.5/1/2/3/4/DONE
  has_resume: true                # --resume
  has_status: true                # --status
  is_multi_run: false             # ghi trực tiếp vào .mc-data/work/legacy-scan/ root

  spawns_agents: true             # Phase 2 → wf-legacy-classify, Phase 3 → wf-legacy-extract
  has_strategy_routing: true      # 7 strategies (S1-S7)

  writes_registry: false          # fields_owned: []
  registry_role: NONE

contracts:
  producers_count: 0              # entry point skill trên legacy path
  consumers_count: 11             # legacy-classify, legacy-extract, brainstorm, analyze-req,
                                  # define-features, design, design-ux, plan-modules,
                                  # implement-feature, annotate-code, add-scope
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ Toàn bộ A1-A10 | |
| **B** Workflow Integrity | ✅ Toàn bộ B1-B10 | Có state machine + resume + strategy routing |
| **C** Output & Template | ✅ C1-C7 | Có conditional outputs (`ui-manifest.json`, `doc-classified.json`) |
| **D** Cross-Skill | ✅ D1-D4 | 11 consumers — check drift rất quan trọng |
| **E** Protocol & CORE | ✅ Toàn bộ E1-E14, E17, E18 | E15-E16 SKIP (`writes_registry=false`); E12 SKIP (`is_multi_run=false`) |
| **F** Determinism/Agent | ✅ F1-F7 | Phase 0/0A/0.5/1/4 deterministic; Phase 2/3 delegate |
| **H** Error Handling | ✅ H1-H5 | `error-ledger.json`, atomic write `ledger.json` |
| **I** Testability | ✅ I1-I5 | Cần cover 7 strategies |
| **J** Idempotency | ✅ J1-J3 | J4 SKIP (không multi-run) |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Strategy & Assessment Logic (S1-S7)

Tiêu chuẩn này **không tổng quát hóa** được sang skill khác — chỉ áp dụng cho `wf-legacy-scan`.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | 7 strategies định nghĩa đầy đủ | `phase0a-assessment.md` | Có danh sách S1-S7 với điều kiện routing rõ ràng (maturity × code-doc ratio × vision alignment) |
| **G2** | Mỗi strategy có use case minh họa | Đọc assessment | Mỗi S1-S7 có ví dụ thực tế (e.g., S1: "dự án hoàn toàn mới chỉ có code"; S7: "DOCS_ONLY repo") |
| **G3** | `--re-vision` kích hoạt đúng S6 | Grep argument handler ở `phase0-detection.md` | `--re-vision` → force strategy=S6, bypass auto-scoring, require user confirmation (CORE-027) |
| **G4** | DOCS_ONLY branch (S7) tồn tại | Phase 1 `phase1-inventory.md` + S7 | Khi `source_file_count == 0 AND doc_file_count > 0` → chạy `doc-classified.json` branch |
| **G5** | Assessment score tính đúng | Scoring formula | Formula công khai, có weights cho từng factor; output `assessment-report.json` có breakdown |
| **G6** | NEAR_COMPLETE strategy có fast-track | S4/S5 | Dự án gần hoàn thiện → có đường tắt sang `/wf-verify-sync` thay vì chạy full pipeline |
| **G7** | Phase 0.5 conditional guard | `phase05-maturity.md` flow đầu | Phase 0.5 chỉ chạy khi `$MATURITY_LEVEL ∈ {DEVKIT_PARTIAL, DEVKIT_COMPLETE, NEAR_COMPLETE}`. Có early-return cho case khác |
| **G8** | Strategy → STAGE_MODES explicit | `phase0a-assessment.md` | Mỗi strategy S1-S7 có mapping rõ ràng: `{detect, classify, extract, synthesize}` mỗi key giá trị `run`/`fast-track`/`skip` |
| **G9** | Phase 2/3 skip theo STAGE_MODES | Đầu `phase2-classify.md`, `phase3-extract.md` | Có guard: `if $STAGE_MODES.classify == "skip"` → skip phase; transition state machine đúng |

### 2.2 NHÓM C+ — Cross-skill contract đặc thù

Mở rộng NHÓM D của common template cho paths đặc biệt của `wf-legacy-scan`:

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | `project-context.md` là LEGACY_MODE anchor | Kiểm tra template + CORE-021 | Template `project-context.md` đầy đủ content, populate xong > 500 bytes; là file test của CORE-021 |
| **CS2** | `impl-status-snapshot.json` owner độc quyền | Grep các downstream ghi đè | Chỉ `wf-define-features` Phase 0.5 consume (1 lần seed); không skill nào modify sau đó |
| **CS3** | `impl-status-snapshot.json` READ-ONLY contract | Contract note | `_contract.json` hoặc `notes` ghi rõ READ-ONLY; không consumer nào ghi đè sau Phase 4 |
| **CS4** | `module-code-mapping.json` ownership rõ ràng | Cross-skill contract `produces_for.wf-add-scope` + `00-core.md §4b` | File được **sinh thực tế** bởi `wf-legacy-extract` Stage 3.5. `wf-legacy-scan` chỉ **forward** cho `wf-add-scope`, KHÔNG có script riêng tạo file này trong Phase 0-4 của scan. Cả 2 entries trong `00-core.md §4b` là hợp lệ. Kiểm tra: scan không có Stage 3.5 trong procedures |
| **CS5** | Phase 2/3 agent prompt delegate đúng sub-skill | Đọc `_shared.md §Agent Prompt Templates` | Phase 2 prompt có `subagent_type` → `/wf-legacy-classify`; Phase 3 → `/wf-legacy-extract` |

### 2.3 Constraint đặc biệt

- **Không ghi registry** (`fields_owned: []`) — khác với các `wf-*` skill khác. Bỏ qua toàn bộ tiêu chuẩn E15-E16 của common template.
- **Tự có pipeline contracts riêng** (`legacy-scan-contract.json`, `legacy-pipeline-contract.json`) ngoài `_contract.json` cấp skill. Khi review, kiểm tra đồng bộ giữa 3 contract files.
- **Nhiều script output** — template đóng vai trò **schema reference** cho POST-GATE T3-T4, không phải template render. Áp dụng C6 (script output có schema reference).

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Đủ 7 strategies S1-S7 trong `phase0a-assessment.md`
- [ ] G8: STAGE_MODES mapping đầy đủ cho mọi strategy
- [ ] CS1: `project-context.md` populate > 500 bytes (LEGACY_MODE trigger)
- [ ] CS4: Không có Stage 3.5 trong `procedures/` của scan (xác định scan chỉ forward, extract mới sinh)
- [ ] 3 contract files đồng bộ: `_contract.json`, `legacy-scan-contract.json`, `legacy-pipeline-contract.json`

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-legacy-scan/SKILL.md) | Overview, routing, Output Files table |
| [_contract.json](../../.claude/skills/workflow/wf-legacy-scan/_contract.json) | Output contract, cross-skill contracts |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-legacy-scan/procedures/_shared.md) | State vars, tech stack, agent prompts |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-legacy-scan/procedures/) | Phase execution detail |
| [templates/](../../.claude/skills/workflow/wf-legacy-scan/templates/) | Output templates + schema ref |
| [evals/evals.json](../../.claude/skills/workflow/wf-legacy-scan/evals/evals.json) | Test cases |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE rules — §4 Structured Contract, §4b Cross-Skill, CORE-011/012/021/022/026-031 |
| [`.claude/skills/protocols/`](../../.claude/skills/protocols/) | Protocol 1/2/3/6/9/10/16/19 |

---

## 5. Ghi chú bảo trì riêng file này

- Khi skill nâng lên **version mới** (4.1, 5.0…) → cập nhật `skill.version` ở §1 + review extension G/CS có lỗi thời không.
- Khi `_template-common.md` bump version → kiểm tra §1 Skill Profile flags còn đầy đủ không; `consumers_count` có đúng không.
- Khi cross-skill path thay đổi (thêm/xóa consumer) → cập nhật `contracts.consumers_count` + rerun NHÓM D của common + CS1-CS5.
- Khi thêm strategy mới (S8…) → cập nhật G1 + G8; cập nhật evals I2 coverage.
- File này là **read-only** trong quá trình review — không tự chỉnh sửa findings; dùng file report riêng trong `reports/`.
