# Tiêu chuẩn rà soát — `wf-fix-execute` v3.1.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-fix-execute/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section**. Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Step 3/3 của pipeline `wf-fix-bugs` — Execute fixes + docs sync + verify loop + final report |
| **Entry point** | Lazy-load theo phase: `procedures/phase3-batch1.md` ... `phase6-report.md` |
| **Kiến trúc** | Multi-phase lazy-load. 10 procedure files + `_shared.md`. Phase 3 (3 batches) → Phase 4 (4a docs-sync + 4b stubs) → Phase 5 (scan + loop + final) → Phase 6 (report) |
| **Execution mode** | Hybrid — sequential batches + PARALLEL agents trong Batch 2 (HIGH) + state machine verify loop (max 3 iterations) |
| **Strategy routing** | Flag-based: `--dry-run` skip Phase 3-5 (chỉ Phase 6 preview), `--deep` enable Phase 4b stubs, `--resume` → load checkpoint + continue từ phase/batch/verify-loop state |
| **Đặc trưng** | **DUY NHẤT** writes registry trong pipeline (SAFE-UPDATE `impl_status`). Share SESSION_DIR với discover/triage. Verify loop có state machine (INIT→SCAN→EVALUATE→FIX/DOCS/RESCAN→FINAL) |
| **Output** | `fix-log.json` (APPEND), `issue-registry.json` (UPDATE verify), `fix-status.json` (UPDATE per-phase), `e2e-results.json` (UPDATE-only, append iterations), `fix-report.md`, `fix-history.md` (APPEND), `phase-summary.md`, Phase 4a docs updates, Phase 4b stub docs |
| **Cross-skill** | Spawned by `wf-fix-bugs` (final sub-skill); produces_for `wf-verify-sync`, `wf-define-features` (stubs), `wf-design-ux` (stubs) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-fix-execute
  version: 3.1.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-fix-execute/

profile:
  # Kiến trúc
  is_orchestrator: false
  has_procedures: true            # 10 phase files + _shared.md (lazy loading)
  has_templates: true             # 5 templates (e2e-results, fix-history, fix-log, fix-plan, fix-report)
  has_phases: true                # Phase 3 (3 batches) + Phase 4 (a/b) + Phase 5 (scan/loop/final) + Phase 6

  # State & Resume
  has_state_machine: true         # fix-status.json per-phase update + Phase 5 verify state machine
  has_resume: true                # --resume: load checkpoint → continue từ phase/batch/iteration
  has_status: true                # --status
  is_multi_run: true              # Share SESSION_DIR với discover/triage (inherit isolation)

  # Execution
  spawns_agents: true             # Phase 3 Batch 2 PARALLEL: developer + security + domain expert; reality-checker (Phase 5)
  has_strategy_routing: true      # --dry-run / --deep / --resume route khác nhau

  # Registry
  writes_registry: true           # fields_owned: ["impl_status"] (Phase 4a only)
  registry_role: SAFE-UPDATE      # CORE-006/008: KHONG downgrade done

contracts:
  producers_count: 2              # wf-fix-discover + wf-fix-triage (qua SESSION_DIR)
  consumers_count: 3              # wf-verify-sync, wf-define-features (stubs --deep), wf-design-ux (stubs --deep)
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | A1-A10 đầy đủ | |
| **B** Workflow Integrity | B1-B10 | B5 áp dụng (Phase 4a conditional on behavior_changed, Phase 4b conditional on --deep). B6/B8 quan trọng — Phase 5 verify loop có state machine rõ |
| **C** Output & Template | C1-C7 | C5 quan trọng (nhiều conditional docs outputs). C2 quan trọng (fix-status.json, issue-registry.json template=null + notes) |
| **D** Cross-Skill | D1-D4 | 2 producers + 3 consumers. Owner của stub docs contract (Phase 4b) |
| **E** Protocol & CORE | E1-E16 đầy đủ | E15/E16 ÁP DỤNG (writes_registry=true, role=SAFE-UPDATE). E8 CDG quan trọng (Phase 4b stub creation). E17/E18 áp dụng khi LEGACY |
| **F** Determinism/Agent | F1-F4 | F1: Phase 3 Batch 3 AUTO_FIX deterministic. F2-F4: Phase 3 Batch 2 PARALLEL agents |
| **H** Error Handling | H1-H5 | H2 atomic write quan trọng — fix-status.json update per-phase theo contract trong `_shared.md` |
| **I** Testability | I1-I5 | 4 test cases (hiện tại) — cần cover: CRITICAL pass, verify loop iteration 2, dry-run, --resume mid-batch, --deep stubs |
| **J** Idempotency | J1-J4 đầy đủ | J2 quan trọng — --resume không duplicate fix-log entries. J3 — fix-report.md deterministic từ cùng fix-log |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Batch Strategy + Verify Loop State Machine

Tiêu chuẩn này **không tổng quát hóa** — chỉ áp dụng cho `wf-fix-execute`.

#### G.A Phase 3 Batch Strategy

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | 3 batches định nghĩa rõ ràng theo severity | `procedures/phase3-batch*.md` | Batch 1 = CRITICAL (sequential), Batch 2 = HIGH (PARALLEL: developer + security + domain expert), Batch 3 = MEDIUM+LOW (AUTO_FIX + AGENT_FIX). Align với triage batch assignment |
| **G2** | Batch 2 PARALLEL có owner + isolation | `phase3-batch2.md` | Mỗi agent write scope tách biệt (security → auth files, developer → logic, domain → business). Contract rõ. Verify re-read sau merge (CORE-025) |
| **G3** | fix-log.json APPEND-only theo batch | `_shared.md §fix-status.json Update Contract` | Mỗi batch complete → APPEND entries vào fix-log.json (không overwrite). Fallback: init từ template nếu file missing (wf-fix-triage đã tạo) |
| **G4** | Checkpoint sau mỗi batch khi context > 80% | `phase3-batch*.md` | Nếu context usage > 80% → force checkpoint flush + update fix-status.json.phases.phase_3.batch_N.status = "completed" |

#### G.B Phase 4 Docs Sync + Stubs

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G5** | Phase 4a scan behavior changes | `phase4a-docs-sync.md` | Scan fix-log.json cho `behavior_changed: true` → UPDATE `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md`. Nếu không có behavior change → SKIP Phase 4a |
| **G6** | Phase 4a update registry (SAFE-UPDATE) | `phase4a-docs-sync.md` | CHỈ update `impl_status` cho REQ-ID có code verified. Read-before-write. KHÔNG downgrade `done`. Atomic write. Phase 4a only |
| **G7** | Phase 4b CONDITIONAL trên --deep | `phase4b-stubs.md` | Guard đầu phase: `if flags.deep != true OR ORPHAN_UI_* empty → SKIP`. Chỉ tạo stub docs (status: "stub") — full content để wf-define-features/wf-design-ux |
| **G8** | Phase 4b CDG user confirmation | `phase4b-stubs.md` | Trước khi CREATE stub files → hỏi user xác nhận (Protocol 16). Stub path cross-phase (phase2-features, phase4-ux) đụng ownership skill khác |

#### G.C Phase 5 Verify Loop State Machine

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G9** | State machine rõ ràng | `phase5-scan.md` + `phase5-loop.md` + `phase5-final.md` | States: VERIFY_INIT → VERIFY_SCAN → VERIFY_EVALUATE → {VERIFY_FIX/VERIFY_DOCS/VERIFY_RESCAN | VERIFY_FINAL}. Transitions explicit |
| **G10** | `current_iteration` owner duy nhất | `_shared.md` + `phase5-scan.md` §Step 5.14 | **VERIFY_INIT la owner DUY NHAT** — tăng iteration counter. VERIFY_RESCAN quay lại INIT để tăng iter. v3.1.0 Fix A+B đã clarify — kiểm lại code/docs không bị tăng kép |
| **G11** | Max 3 iterations, không infinite loop | `phase5-loop.md` | `if current_iteration > 3 → FORCE VERIFY_FINAL with status=PARTIAL`. CDG user override khả dụng |
| **G12** | `e2e-results.json` UPDATE-only (CORE-007) | `_contract.json.outputs.working[3]` + `phase5-scan.md §Step 5.14b` | wf-fix-execute CHỈ UPDATE (APPEND verify_iterations[]), KHÔNG CREATE. Nếu file không tồn tại (PASS 3 skip) → ghi summary vào fix-status.phases.phase_5.playwright_verify, KHÔNG tự CREATE file (v3.1.0 Fix C) |
| **G13** | CQG numeric metrics verify sau report | `phase6-report.md` | Sau WRITE fix-report.md → kiểm tra Content Quality Gate (Protocol 8): metrics trong report KHỚP với fix-log.json + issue-registry.json. Chống "fantasy reporting" (v3.1.0 Fix F) |

### 2.2 NHÓM CS — Cross-skill contract đặc thù (shared SESSION_DIR + Registry writer)

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | PRE-GATE check wf-fix-triage POST-GATE | `_contract.json.prerequisites` | 3 files: `issue-registry.json` + `fix-plan.md` + `fix-status.json`. `phases.phase_2.status == "completed"` + issues có severity set. Dry-run → SKIP Phase 3-5 ngay, chạy Phase 6 |
| **CS2** | fix-status.json UPDATE contract per-phase | `_shared.md §fix-status.json Update Contract` | 8 update points: Phase 3 BAT DAU, sau Batch 1/2/3, Phase 4a/4b POST-GATE, Phase 5 LOOP START/LOOP/POST-GATE, Phase 6 POST-GATE. Atomic write, merge fields, KHÔNG overwrite (v3.1.0 Fix E: thêm fix-status.json vào outputs.working) |
| **CS3** | issue-registry.json UPDATE-only (final verify) | `_contract.json.outputs.working[1]` | Template null. Notes: "UPDATE file đã có tu wf-fix-discover — them fix details (Phase 3) + verify results (Phase 5). KHONG overwrite, chi modify per-issue fields" |
| **CS4** | 2 template cross-skill được share với wf-fix-triage | `wf-fix-triage/_contract.json.cross_skill_contracts.uses_templates_from` | `fix-plan.md` + `fix-log.json` — wf-fix-execute là OWNER (templates/), wf-fix-triage chỉ cross-skill reference |
| **CS5** | `e2e-results.json` ownership split | CS4 wf-fix-discover + G12 | **CREATE owner** = wf-fix-discover PASS 3. **UPDATE owner** = wf-fix-execute Phase 5. Phân tách qua 2 role rõ ràng. v3.1.0 Fix C bảo đảm không bị mâu thuẫn |
| **CS6** | Registry SAFE-UPDATE — CHỈ Phase 4a | `registry_scope.safe_write_rule: CORE-006` | Update `impl_status` ONLY. KHÔNG downgrade from "done". Read-before-write. Atomic write. Dry-run → KHÔNG touch registry |
| **CS7** | Stub docs cross-ownership (CDG) | `_contract.json.outputs.docs[]` Phase 4b | 3 stub paths: `phase2-features/[sys]/[mod]/[slug].md`, `flow-[slug].md`, `phase4-ux/.../screens-[slug].md`. Status "stub" rõ ràng; wf-define-features/wf-design-ux là owner full content. CDG trước khi write |
| **CS8** | fix-history.md cross-run log APPEND | `_contract.json.outputs.working[5]` | Append 1 dòng per run vào `.mc-data/work/wf-fix-bugs/fix-history.md` (OUTSIDE SESSION_DIR — shared across all sessions). Dry-run: APPEND với mode="DRY-RUN" |

### 2.3 Constraint đặc biệt

- **DUY NHẤT writes registry trong pipeline** — `wf-fix-bugs`, `wf-fix-discover`, `wf-fix-triage` đều `fields_owned: []`. Chỉ wf-fix-execute Phase 4a update `impl_status` (SAFE-UPDATE). Tiêu chuẩn E15/E16 CHỈ áp dụng cho skill này.
- **Playwright tools trong `allowed-tools`** — 20+ MCP tools dùng cho Phase 5 verify (browser re-test sau fix). Constraint: khi dry-run hoặc PASS 3 skipped → không invoke.
- **Lazy-load 10 procedure files** — giảm ~70% context load (v3.0.0 refactor). Main context CHỈ load 1 phase tại thời điểm.
- **Dry-run chạy đầy đủ Phase 6** — khác với các skill khác (thường skip report). Dry-run Phase 6 = preview mode: metrics từ triage, không có fixes. Tạo fix-report.md với prefix "DRY-RUN".
- **v3.1.0 bug fixes** — 5 bugs từ audit 2026-04-19: (A+B) VERIFY_INIT ownership, (C) e2e-results.json UPDATE-only, (D) stale ref phase5-verify.md→phase5-scan.md, (E) fix-status.json trong outputs, (F) CQG numeric verify. Review phải kiểm tất cả 5 fixes.
- **PARALLEL safe-parallel conditions (Phase 3 Batch 2)** — owner/isolation/contract/verify đủ (CORE-025). Mỗi expert agent write scope riêng, không ghi đè, có verify re-read sau merge.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: 3 batches theo severity (CRITICAL/HIGH/MEDIUM+LOW) khớp triage batch assignment
- [ ] G2: Batch 2 PARALLEL có owner + isolation + verify sau merge (CORE-025)
- [ ] G6: Phase 4a SAFE-UPDATE `impl_status` — không downgrade `done`
- [ ] G7: Phase 4b guard `flags.deep == true` — skip nếu không --deep
- [ ] G8: Phase 4b CDG user confirmation trước CREATE stub docs
- [ ] G9: Phase 5 state machine rõ ràng 5 states + transitions explicit
- [ ] G10: VERIFY_INIT là owner DUY NHẤT của `current_iteration` counter
- [ ] G11: Max 3 iterations, force VERIFY_FINAL với status=PARTIAL
- [ ] G12: `e2e-results.json` UPDATE-only (CORE-007), KHÔNG tự CREATE
- [ ] G13: CQG numeric verify sau fix-report.md (v3.1.0 Fix F)
- [ ] CS2: fix-status.json update contract có 8 explicit update points
- [ ] CS6: Registry update CHỈ Phase 4a, CHỈ `impl_status`, CHỈ không-downgrade-done
- [ ] evals ≥ 3 cases cover: CRITICAL pass, verify loop iter 2+, dry-run, --resume mid-batch, --deep stubs

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-fix-execute/SKILL.md) | Overview + Procedure Files table (lazy loading) |
| [_contract.json](../../.claude/skills/workflow/wf-fix-execute/_contract.json) | Outputs (7 working + 4 docs conditional), registry_scope, cross-skill contracts |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-fix-execute/procedures/_shared.md) | State vars, agent templates, fix-status contract, CDG, error codes |
| [procedures/phase3-batch2.md](../../.claude/skills/workflow/wf-fix-execute/procedures/phase3-batch2.md) | Batch 2 PARALLEL (developer + security + domain) |
| [procedures/phase4a-docs-sync.md](../../.claude/skills/workflow/wf-fix-execute/procedures/phase4a-docs-sync.md) | Docs update + registry SAFE-UPDATE |
| [procedures/phase4b-stubs.md](../../.claude/skills/workflow/wf-fix-execute/procedures/phase4b-stubs.md) | Stub docs (--deep + CDG) |
| [procedures/phase5-scan.md](../../.claude/skills/workflow/wf-fix-execute/procedures/phase5-scan.md) | VERIFY_INIT + VERIFY_SCAN + e2e-results UPDATE |
| [procedures/phase5-loop.md](../../.claude/skills/workflow/wf-fix-execute/procedures/phase5-loop.md) | VERIFY_EVALUATE + FIX/DOCS/RESCAN |
| [procedures/phase6-report.md](../../.claude/skills/workflow/wf-fix-execute/procedures/phase6-report.md) | Report + CQG numeric verify |
| [templates/](../../.claude/skills/workflow/wf-fix-execute/templates/) | 5 templates (2 share với wf-fix-triage) |
| [evals/evals.json](../../.claude/skills/workflow/wf-fix-execute/evals/evals.json) | 4 test cases (cần bổ sung) |
| [wf-fix-bugs.md](./wf-fix-bugs.md) | Orchestrator spawning skill này |
| [wf-fix-discover.md](./wf-fix-discover.md) | Upstream producer (e2e-results CREATE owner) |
| [wf-fix-triage.md](./wf-fix-triage.md) | Upstream producer (fix-plan + fix-log init) |
| [`_template-common.md`](./_template-common.md) | Tiêu chuẩn chung |

---

## 5. Ghi chú bảo trì riêng file này

- Khi bump **major** (4.x) → re-check G9-G13 (verify state machine), CS2 (fix-status update contract).
- Khi thêm batch thứ 4 (ví dụ: SECURITY_CRITICAL) → cập nhật G1 + align với triage G5.
- Khi thay đổi registry scope (ví dụ: thêm `fix_history`) → cập nhật CS6 + E15/E16 trong profile.
- Khi Playwright MCP API đổi → kiểm `allowed-tools` + phase5-scan.md browser operations.
- Khi evals bổ sung (hiện 4 cases, target ≥6) → track I2 coverage cho các flag combinations.
- File này là **read-only** trong quá trình review — findings ghi vào `reports/`.
