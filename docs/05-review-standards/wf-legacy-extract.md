# Tiêu chuẩn rà soát — `wf-legacy-extract` v2.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-legacy-extract/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Stage 3 của legacy pipeline — extract requirements + features per module từ classified data; tạo `module-code-mapping.json` (CORE-013) |
| **Entry point** | `procedures/phase0-context.md` |
| **Kiến trúc** | Lazy-load procedures; 6 phase files (0-5) + `_shared.md` |
| **Execution mode** | Phase 2 **PARALLEL per group** (≤3 agents: `business-analyst` + domain expert); Phase 0/1/3/4/5 SEQUENTIAL |
| **Đặc trưng** | `--module=<name>` filter; `--resume`, `--status`; maturity skip mode (JUMP thẳng Phase 5); strategy S5 divergence; checkpoint sau mỗi module |
| **Stage 3.5 — ownership đặc biệt** | **Phase 4 là nơi sinh thực tế `module-code-mapping.json`** (CORE-013) — `wf-legacy-scan` chỉ forward cho downstream |
| **Output** | 7 files: status, plan, checkpoint, `{module}.json` (per module), dedup-report, `module-code-mapping.json`, phase-summary + conditional `{module}-divergences.json` (S5 only) |
| **Cross-skill** | 2 producers (scan, classify), 5 consumers (brainstorm, analyze-req, define-features, design, annotate-code) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-legacy-extract
  version: 2.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-legacy-extract/

profile:
  is_orchestrator: false
  has_procedures: true
  has_templates: true
  has_phases: true                # 6 phase files

  has_state_machine: true         # share ledger.json + extract-status.json + extract-checkpoint.json
  has_resume: true                # --resume
  has_status: true                # --status
  is_multi_run: false             # ghi vào .mc-data/work/legacy-scan/ chung

  spawns_agents: true             # Phase 2 business-analyst + domain expert (≤3 parallel), Phase 5 auto-fix
  has_strategy_routing: false     # strategy (S1-S7) inherit từ scan, không tự routing

  writes_registry: false          # fields_owned: []
  registry_role: NONE

contracts:
  producers_count: 2              # wf-legacy-scan + wf-legacy-classify
  consumers_count: 5              # wf-brainstorm, wf-analyze-requirements, wf-define-features, wf-design, wf-annotate-code
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ Toàn bộ A1-A10 | Lưu ý: `allowed-tools` thiếu frontmatter check `disable-model-invocation` — check A4 |
| **B** Workflow Integrity | ✅ B1-B8 | B5 cho skip mode + S5 divergence conditional; B9-B10 SKIP |
| **C** Output & Template | ✅ C1-C7 | 4 templates + 3 inline schema (dedup-report, module-code-mapping, divergences) — C6 áp dụng |
| **D** Cross-Skill | ✅ D1-D4 | 2 producers + 5 consumers — đây là **điểm phân luồng quan trọng** sang DEVKIT flow |
| **E** Protocol & CORE | ✅ E1-E11, E13-E14 | E12 SKIP; E15-E16 SKIP (không registry); **E17 áp dụng** (LEGACY_MODE), **E18 áp dụng** (đọc legacy-decisions.json nếu có) |
| **F** Determinism/Agent | ✅ F1-F4 | F5-F7 SKIP |
| **H** Error Handling | ✅ H1-H5 | 7 error codes (E001, E004, E007, E008, E015, E020, E022) |
| **I** Testability | ✅ I1-I5 | Cover skip mode, --module filter, resume, S5 divergence, E020 auto-fix |
| **J** Idempotency | ✅ J1-J3 | J4 SKIP |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Extraction & Module Resolution (Stage 3.5)

Tiêu chuẩn này **không tổng quát hóa** được — đặc thù extract + alignment logic.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | Module Resolution normalize đúng (CORE-017) | `phase1-resolution.md` + `_shared.md §Module Name Normalization` | Áp dụng lowercase-kebab-case; apply `classify-naming-fixes.json` (nếu có) trước khi group; dedup theo normalized name |
| **G2** | Topological ordering cho parallel groups | `phase1-resolution.md` | Đọc `inventory/dependency-graph.json` → topological sort → chia parallel groups (leaf modules trước); max 3 agents per group |
| **G3** | Domain Expert Selection đúng | `_shared.md §Domain Expert Selection` | Mapping module → 1 trong 7 experts: finance/procurement/sales/hr/ecommerce/operations/compliance. Mapping rule công khai |
| **G4** | Extract template đủ acceptance_criteria | `templates/extracted-module.json` + agent prompt | Output `{module}.json` có `requirements[]`, `features[].acceptance_criteria[]`, `confidence_score`. Template POPULATE đầy đủ (CORE-031) |
| **G5** | **Stage 3.5 Module-Code Alignment (CORE-013)** | `phase4-alignment.md` | Phase 4 scan code projects thực tế → map module → code files → ghi `module-code-mapping.json`. Có user confirmation cho cross-cutting modules (CORE-027) |
| **G6** | Confidence Tier threshold | `_shared.md §Confidence Tiers` + E022 | Có tiers: HIGH (>=0.8), MEDIUM (0.5-0.8), LOW (<0.5). Avg confidence < 0.6 → WARN; <0.4 → escalate |
| **G7** | Dedup cross-module | `phase3-dedup.md` | Phase 3 dedup requirements trùng giữa các modules: 85-100% → merge; 70-85% → giữ cả hai + WARN (E008); <70% → giữ riêng |
| **G8** | Strategy S5 Divergence conditional | `phase3-dedup.md` + `_contract.json.outputs.working[]` | S5 (DIVERGENCE-RESOLVE) hoặc maturity `CODE_PLUS_*` → tạo `{module}-divergences.json` so sánh `from_code` vs `from_docs`. Guard tồn tại ở Phase 3 |
| **G9** | Skip mode JUMP thẳng Phase 5 | `phase0-context.md` routing | `$MATURITY_MODE == "skip"` → JUMP Phase 5 (bỏ Phase 1-4), Phase 5 mark `completed (skipped_maturity)` + phase-summary.md |
| **G10** | Auto-fix missing modules max 3 retries | `phase5-verify.md` + E020 | Self-diagnostic: missing extracted modules → retry re-extract ≤3 lần; vẫn thiếu → ASK user |
| **G11** | Checkpoint sau mỗi module (Phase 2) | `phase2-extraction.md` | Context >=80% → STOP sau module hiện tại + flush `extract-checkpoint.json` atomic. Resume từ đúng module chưa xong |
| **G12** | UI manifest cho Bước 2U (conditional) | `_contract.json.inputs` + `phase2-extraction.md` | `inventory/ui-manifest.json` (optional, LEGACY_MODE only) được consume trong Phase 2 Bước 2U UI Screen Analysis |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | **`module-code-mapping.json` OWNERSHIP** | `00-core.md §4b` cross-check với `wf-legacy-scan.md` CS4 | File này **sinh thực tế tại Phase 4 của extract** (Stage 3.5), NOT từ scan. Cả 2 entries trong §4b (scan forward + extract produce) đều hợp lệ — đây là điểm drift check với wf-legacy-scan.md CS4 |
| **CS2** | Share state dir với scan/classify | SKILL.md §Work Directory | Extract ghi vào `.mc-data/work/legacy-scan/` (chung với scan + classify). Chỉ `phase-summary.md` ở `.mc-data/work/wf-legacy-extract/` |
| **CS3** | 5 consumers khác nhau, đều đọc `{module}.json` | `_contract.json.produces_for` | brainstorm/analyze-requirements/define-features/design đều đọc `extracted/{module}.json`; annotate-code CHỈ đọc `module-code-mapping.json`. Phân biệt rõ trong produces_for |
| **CS4** | `glossary.json` là input BẮT BUỘC | `_contract.json.inputs` | `classified/glossary.json` required; thiếu → STOP E001 (prerequisites check) |
| **CS5** | `classify-naming-fixes.json` input optional | `_contract.json.inputs` | Optional, nhưng nếu có → PHẢI apply trong Phase 1 Module Resolution (G1) để đồng bộ với classify POST-GATE output |
| **CS6** | Ledger update phạm vi `stages.extract` | `phase5-verify.md` | Phase 5 chỉ update `ledger.stages.extract.*` (started_at, completed_at, modules_done, requirements_count, features_count, avg_confidence…). Không đụng stage khác. Safe-write CORE-006 |
| **CS7** | Per-module filename normalized | `_contract.json.outputs.working[]` notes | `{module}.json` filename PHẢI lowercase-kebab-case (aligned với CORE-017). Tên file = normalized module name |

### 2.3 Constraint đặc biệt

- **`module-code-mapping.json` là ownership vàng** — đây là file duy nhất dùng ngang qua 5 consumers và cross-skill với `wf-legacy-scan` (forward). Mọi thay đổi schema phải update cả 2 contracts + downstream skills (`wf-annotate-code`, `wf-add-scope` v.v.).
- **Frontmatter thiếu `disable-model-invocation`** — kiểm tra lại A4 (hiện `wf-legacy-extract/SKILL.md` KHÔNG có field này trong frontmatter). Đây có thể là finding khi audit.
- **Pipeline skill — share state với scan/classify** — áp dụng E17 (CORE-021) và E18 (CORE-022 legacy-decisions) nếu Phase 1 đọc decisions để filter DEPRECATE modules.
- **Phase 2 PARALLEL per group** — áp dụng F2-F4 nghiêm ngặt: mỗi agent prompt có full contract, main context validate output schema (jq `extracted-module.json` template) trước khi mark module done.
- **Strategy S5 không tự routing** — S5 được inherited từ scan assessment. Extract chỉ đọc `$STRATEGY` từ ledger/status file để quyết định có tạo `{module}-divergences.json` hay không.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Module Resolution apply `classify-naming-fixes.json` nếu tồn tại (CORE-017)
- [ ] G4: Output `{module}.json` match template `extracted-module.json` (có acceptance_criteria)
- [ ] G5: Phase 4 thực tế scan code và sinh `module-code-mapping.json` (CORE-013) — KHÔNG phải forward từ scan
- [ ] G8: Strategy S5 guard tồn tại ở Phase 3 → tạo `{module}-divergences.json`
- [ ] G9: Skip mode JUMP Phase 5 (không chạy 1-4)
- [ ] G12: `ui-manifest.json` input có condition `LEGACY_MODE only` trong `_contract.json`
- [ ] CS1: `module-code-mapping.json` xuất hiện 2 entries `produces_for` trong §4b (scan forward + extract produce) — đồng bộ với wf-legacy-scan.md CS4
- [ ] CS3: `produces_for.wf-annotate-code` CHỈ có `module-code-mapping.json`
- [ ] CS7: `{module}.json` filename lowercase-kebab-case
- [ ] A4: Frontmatter có `disable-model-invocation: true` (hiện đang thiếu — flag finding)

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-legacy-extract/SKILL.md) | Overview, routing, Work Directory, Error Handling |
| [_contract.json](../../.claude/skills/workflow/wf-legacy-extract/_contract.json) | Output contract, 5 consumers cross-skill |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-legacy-extract/procedures/_shared.md) | State vars, Module Normalization, Domain Experts, Confidence Tiers |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-legacy-extract/procedures/) | 6 phase files (0-5) |
| [templates/](../../.claude/skills/workflow/wf-legacy-extract/templates/) | 4 templates (status/plan/checkpoint/extracted-module) |
| [evals/evals.json](../../.claude/skills/workflow/wf-legacy-extract/evals/evals.json) | Test cases (366 dòng) |
| [`wf-legacy-scan.md`](./wf-legacy-scan.md) | Peer skill — CS4 cross-check về module-code-mapping ownership |
| [`wf-legacy-classify.md`](./wf-legacy-classify.md) | Producer upstream |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE rules — **CORE-013 (Module-Code Alignment)**, CORE-017 (Normalization), CORE-021/022, CORE-027 (CDG), CORE-028/031 |
| [`.claude/skills/protocols/`](../../.claude/skills/protocols/) | Protocol 6/7/9/10/14/15/19 |

---

## 5. Ghi chú bảo trì riêng file này

- Khi skill nâng lên **version mới** → update `skill.version` + review G1-G12 (nhất là Module Resolution và confidence tiers).
- Khi **`module-code-mapping.json` schema** đổi → cập nhật cả CS1 + `wf-legacy-scan.md` CS4 + 2 consumer skills (`wf-annotate-code`, `wf-add-scope`).
- Khi thêm/bớt consumer (hiện 5) → cập nhật `consumers_count` + CS3.
- Khi **Domain Expert list** mở rộng (thêm domain thứ 8…) → cập nhật G3 + agent list + evals.
- Khi strategy S5 logic đổi (divergence detection) → cập nhật G8 + conditional output schema.
- Khi skill thêm **frontmatter fields** bị thiếu (e.g. `disable-model-invocation`) → update quick-check A4.
- File này là **read-only** trong quá trình review — findings ghi ra `reports/YYYY-MM-DD-wf-legacy-extract.md`.
