# Tiêu chuẩn rà soát — `wf-annotate-code` v2.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-annotate-code/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Inject REQ-ID/FEAT-ID comments vào source code files legacy để thiết lập traceability |
| **Entry point** | `procedures/phase0-context.md` |
| **Kiến trúc** | v2.0 refactor: 5 phase files (0, 1, 2, 3, 4) + `_shared.md` |
| **Execution mode** | 100% MAIN CONVERSATION — KHÔNG spawn agent ở bất kỳ phase nào |
| **Vị trí pipeline** | Stage 5.5 legacy pipeline — sau `/wf-design` gap analysis, trước `/wf-design-ux`/`/wf-plan-modules` |
| **Đặc trưng** | Có `--resume`, `--status`, `--dry-run`, `--module`, `--batch-size`; batched injection per-file với existence check idempotent |
| **Output** | Annotated source code (Edit in place) + 10 working files (`annotate-*`, `annotation-*`, `phase-summary`, session log, ledger/status updates) |
| **Registry** | NONE — READ-ONLY, `fields_owned = []` |
| **Special** | GHI TRỰC TIẾP vào source code (khác tất cả wf-* khác) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-annotate-code
  version: 2.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-annotate-code/

profile:
  is_orchestrator: false
  has_procedures: true
  has_templates: true
  has_phases: true

  has_state_machine: true            # annotate-status.json + annotate-checkpoint.json
                                     # per-batch state (Phase 3)
  has_resume: true                   # --resume (multi-session for LARGE projects)
  has_status: true                   # --status
  is_multi_run: false                # ghi trực tiếp .mc-data/work/legacy-scan/ shared workspace
                                     # (không session isolation — chỉ có 1 annotation run tại 1 thời điểm)

  spawns_agents: false               # KHÔNG spawn agent ở phase nào (SKILL.md §Execution Strategy)
  has_strategy_routing: false

  writes_registry: false             # READ-ONLY access
  registry_role: NONE                # §4a dòng 139

contracts:
  producers_count: 4                 # wf-design (gap-report), wf-legacy-extract (mapping),
                                     # wf-brainstorm (legacy-decisions), wf-legacy-scan (context+profile+ledger+status)
  consumers_count: 2                 # wf-design-ux, wf-plan-modules
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | Toàn bộ A1-A10 | |
| **B** Workflow Integrity | B1-B8 | B9-B10 SKIP (không strategy routing) |
| **C** Output & Template | C1-C7 | 3 outputs `template: null` (`annotation-map.json`, `legacy-scan-status.json`, `ledger.json` — có `description`) |
| **D** Cross-Skill | D1-D4 | 4 upstream, 2 downstream; path trong `legacy-scan/` shared workspace |
| **E** Protocol & CORE | E1-E14, E17, E18 | **E4, E11 SKIP (không spawn agent)**; E12 SKIP (không multi-run); **E15-E16 SKIP (READ-ONLY registry)** |
| **F** Determinism/Agent | F1, F6 | **F2-F4 SKIP (không spawn agent)**; F5-F7 SKIP |
| **H** Error Handling | H1-H5 | E001, E040-E046 đặc thù annotation |
| **I** Testability | I1-I5 | Cần cover: happy path, --dry-run, --resume, DEPRECATE filter, E046 existence conflict |
| **J** Idempotency | J1, J2 | J3 SKIP; J4 SKIP |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Annotation Injection Logic

Tiêu chuẩn đặc thù — chỉ áp dụng `wf-annotate-code`.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | Existence Check Idempotent | `phase3-inject.md` Step 3.3b | Grep REQ-ID TRƯỚC inject. Nếu đã có → SKIP (không double-annotate). E046: tồn tại nhưng khác target → `AskUserQuestion` UPDATE/SKIP |
| **G2** | Comment Format theo Language | `_shared.md §Comment Format Table` | Format đúng per language: `// REQ-ID` (C#/TS/JS/Go/Java), `# REQ-ID` (Python/Ruby/Shell), `-- REQ-ID` (SQL/Lua), etc. Inject sau file header — KHÔNG sửa logic code |
| **G3** | Batched Injection với checkpoint per batch | `phase3-inject.md` | Default `--batch-size=50`. Sau mỗi batch: checkpoint flush → context check. 80-90% context → STOP sau batch hiện tại. E043 batch fail ≥2 liên tiếp → STOP |
| **G4** | Dry-Run Exit ở Phase 2 | `phase2-review.md` | `--dry-run` → tạo `annotation-report.md` với DRY-RUN banner + diff preview; SKIP Phase 3-4 |
| **G5** | User Confirmation Phase 2 | `phase2-review.md` | Display map → user APPROVE_ALL / CANCEL / SELECTIVE. CANCEL → SKILL EXIT |
| **G6** | DEPRECATE Filter (CORE-022) | `_shared.md §LEGACY Decisions Filter` | Khi có `legacy-decisions.json` + module action=DEPRECATE → loại files thuộc module đó khỏi map (Phase 1 step). Graceful degradation khi file không tồn tại |
| **G7** | Traceability Score Baseline + Final | `_shared.md §Traceability Score` + `phase0-context.md` + `phase4-verify-report.md` | Phase 0 tính `traceability_before`; Phase 4 tính `traceability_after`; report có delta (+N%) |
| **G8** | File corrupt rollback (E042) | `phase3-inject.md` fix rules | Post-annotation validation fail → ROLLBACK (restore original), log; không để lại corrupt file |
| **G9** | Unsupported language skip (E045) | `phase3-inject.md` | Language extension không có format mapping → SKIP file, log. > 20% skip → STOP |
| **G10** | Maturity-aware mode (DOCS_ONLY skip) | `phase0-context.md` | `$MATURITY_LEVEL = "DOCS_ONLY"` → SKILL EXIT với message (không có code để annotate) |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | Shared workspace paths (không tạo `work/wf-annotate-code/` riêng cho main outputs) | `_contract.json outputs.working[]` | 7/9 outputs nằm trong `work/legacy-scan/` (shared pipeline), CHỈ `phase-summary.md` nằm trong `work/wf-annotate-code/`. Khác pattern chung (mỗi skill có subdir riêng) |
| **CS2** | Source code `<annotated-source-code-files>` placeholder output | `produces_for.wf-design-ux/wf-plan-modules` | Output chính là source code trong repo (không trong `.mc-data/`). `_contract.json` dùng placeholder `<...>` — không phải path cụ thể |
| **CS3** | `ledger.json` + `legacy-scan-status.json` shared update | `_contract.json outputs.working[]` | GHI vào 2 files nhưng KHÔNG là owner — chỉ update `stages.annotate.status`. Phải tuân thủ append-only / scoped-update pattern của legacy pipeline |
| **CS4** | `gap-report.md` là input quan trọng nhất | `_contract.json prerequisites + inputs` | Prerequisites yêu cầu `ledger.stages.gap_analysis.status = "completed"` — Phase 0 PRE-GATE phải kiểm tra forensic |
| **CS5** | `legacy-decisions.json` optional với graceful degradation | `_contract.json inputs[]` | `required: false`, `condition: "LEGACY_MODE only — nếu không tồn tại → không filter DEPRECATE"` — khớp CORE-022 graceful degradation |

### 2.3 Constraint đặc biệt

- **Registry READ-ONLY** — `fields_owned = []` (§4a dòng 139). E15-E16 SKIP hoàn toàn. Đây là skill DUY NHẤT trong nhóm Phase 5 có registry_role = NONE.
- **Không spawn agent** — F2-F4, E4, E11 SKIP. Kiểm tra nghiêm ngặt: không có dòng nào có `subagent_type` trong procedures/. Đây là feature đặc thù — annotate là deterministic, không cần AI reasoning phức tạp.
- **Ghi TRỰC TIẾP vào source code** — output `<annotated-source-code-files>` là file REAL trong repo (không qua `.mc-data/`). Đây là skill DUY NHẤT có behavior này. Kiểm tra atomic write, rollback E042, existence check G1 rất quan trọng.
- **Shared workspace pattern** — 7/9 outputs nằm trong `legacy-scan/` shared với các skills khác (legacy-scan, legacy-classify, legacy-extract, design legacy). KHÔNG có `sessions/{id}/` isolation (is_multi_run=false).
- **Idempotency là critical** — khác skills khác, re-run annotate phải hoàn toàn safe: đã annotate → skip. G1 là tiêu chuẩn sống còn.
- **Vị trí non-standard trong workflow** — Phase identifier `"post-phase3"` (trong `_contract.json`), không phải `phase5-implementation` như các skill ngang hàng. Nó là legacy-specific skill, không có cho dự án mới.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: `phase3-inject.md` Step 3.3b có Grep check REQ-ID trước Edit (idempotent)
- [ ] G2: Comment format table trong `_shared.md` đủ các language phổ biến (TS/JS/Python/C#/Go/Java/Ruby/SQL)
- [ ] G6: Khi có `legacy-decisions.json` DEPRECATE → Phase 1 filter files thuộc module đó
- [ ] CS2: `produces_for` dùng placeholder `<annotated-source-code-files>` (không dùng path cụ thể)
- [ ] E15/E16 N/A: Confirm `registry_scope.fields_owned = []` và notes ghi "READ-ONLY"
- [ ] F2-F4 N/A: Confirm procedures/ không có `subagent_type` hoặc `Agent(` call

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-annotate-code/SKILL.md) | Overview, Phase Routing Map, Output Files |
| [_contract.json](../../.claude/skills/workflow/wf-annotate-code/_contract.json) | Schema, `procedures_structure` với 5 phases |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-annotate-code/procedures/_shared.md) | State vars, Comment Format Table, LEGACY Filter, Checkpoint, Fix Rules |
| [procedures/phase*.md](../../.claude/skills/workflow/wf-annotate-code/procedures/) | 5 phase files |
| [templates/](../../.claude/skills/workflow/wf-annotate-code/templates/) | 4 templates (status, plan, checkpoint, annotation-report) |
| [evals/evals.json](../../.claude/skills/workflow/wf-annotate-code/evals/evals.json) | Test cases |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE — §4a NONE role, CORE-003 REQ-ID, CORE-022 legacy-decisions |

---

## 5. Ghi chú bảo trì riêng file này

- Khi skill bump version → cập nhật `skill.version` §1 + review G1-G10.
- Khi thêm language mới → cập nhật G2 + Comment Format Table.
- Khi thêm mode mới (ví dụ `--format=jsdoc`) → cập nhật G-section + evals I2.
- Khi `ledger.json` / `legacy-scan-status.json` schema đổi → cập nhật CS3.
- Khi Stage 5.5 vị trí đổi trong legacy pipeline → cập nhật §0 workflow position.
- Nếu skill chuyển sang spawn agent (ví dụ để detect context cho commment) → re-activate E4/E11/F2-F4 tiêu chuẩn.
- File này là **read-only** trong quá trình review — không tự chỉnh findings.
