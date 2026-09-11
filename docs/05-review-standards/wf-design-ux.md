# Tiêu chuẩn rà soát — `wf-design-ux` v3.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-design-ux/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Phase 4 UX/UI design — design system, navigation per system, screen groups per module |
| **Entry point** | `procedures/phase0-context.md` (routing block trong SKILL.md) |
| **Kiến trúc** | Lazy-load procedures, 9 phase files + `_shared.md`; có conditional Phase 0.5 (LEGACY) |
| **Execution mode** | Hỗn hợp SEQUENTIAL (Phase 1, 4, 6) + PARALLEL (Phase 2, 3, 5 — multi-agent UX) |
| **Conditional skip** | Toàn bộ skill skip khi `interface_type == "api-only"` (E002 exit) |
| **Đặc trưng** | Có `--resume`, `--status`; LPM auto-detect (`systems >= 5 OR features >= 40`); legacy UI extraction branch |
| **Output** | 4 doc files + 5 working files + 4 legacy-only outputs + 1 digest + registry `ux_design_status` |
| **Cross-skill** | 1 downstream (`wf-plan-modules`); 3 upstream (design, annotate-code, fix-bugs) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-design-ux
  version: 3.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-design-ux/

profile:
  is_orchestrator: false
  has_procedures: true
  has_templates: true
  has_phases: true

  has_state_machine: true          # checkpoint.json position.current_phase + systems_state
  has_resume: true                 # --resume (có fallback ux-checkpoint.json cho legacy)
  has_status: true                 # --status
  is_multi_run: false              # ghi trực tiếp vào work/wf-design-ux/ root

  spawns_agents: true              # ux-designer, ux-researcher, brand-guardian, ux-architect,
                                   # accessibility-auditor, architect (Phase 1/2/3/4/5)
  has_strategy_routing: false      # không multi-strategy; có LPM mode (không phải strategy)

  writes_registry: true
  registry_role: PRIMARY           # ux_design_status (§4a 00-core.md)

contracts:
  producers_count: 3               # wf-design (primary), wf-annotate-code, wf-fix-bugs
  consumers_count: 1               # wf-plan-modules
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | Toàn bộ A1-A10 | |
| **B** Workflow Integrity | B1-B8 (SKIP B9-B10 vì không strategy routing) | Có state machine + resume |
| **C** Output & Template | C1-C7 | Nhiều conditional outputs (LEGACY + API-only exit) |
| **D** Cross-Skill | D1-D4 | 1 consumer nhưng có conditional path (api-only) |
| **E** Protocol & CORE | E1-E16, E17-E18 (legacy branch) | E12 SKIP (không multi-run) |
| **F** Determinism/Agent | F1-F4 | Phase 6 deterministic không spawn agent; F5-F7 SKIP (không scan code, không strategy) |
| **H** Error Handling | H1-H5 | Error codes E000-E012 đầy đủ |
| **I** Testability | I1-I5 | Cần cover: new project, api-only exit, resume, LEGACY |
| **J** Idempotency | J1-J2 (SKIP J3, J4) | |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Conditional Skip & LPM Logic

Tiêu chuẩn đặc thù cho logic skip toàn bộ skill khi `interface_type == "api-only"` và Large Project Mode.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | API-Only Exit Guard ở Phase 0 | Grep `interface_type` + `api-only` trong `phase0-context.md` | Phase 0 Step kiểm tra `registry.interface_type == "api-only"` → tạo stakeholder-review.md placeholder + `design-ux-status.json {status:"skipped"}` → STOP |
| **G2** | E002 route đúng đường | Kiểm tra error handling | E002 không tạo docs/* (chỉ placeholder), route user sang `/wf-plan-modules` |
| **G3** | Phase 0.5 LEGACY conditional guard | `phase0-5-legacy-ui.md` đầu file | Chỉ chạy khi `$LEGACY_MODE = true` (CORE-021 detection). Có early-return cho non-legacy |
| **G4** | LEGACY UI outputs tách biệt | `_contract.json outputs.working[]` có `condition: "LEGACY_MODE only"` | 4 files legacy (`existing-ui-analysis.md`, `screen-inventory.md`, `design-tokens-baseline.md`, `ux-implementation-gap.md`) + `ux-checkpoint.json` đều có condition guard |
| **G5** | LPM auto-detect đúng ngưỡng | Grep `systems >= 5` hoặc `features >= 40` trong `phase0-context.md` | Detect đúng; khi LPM=true → giảm `max_parallel_agents` (Standard 5 → LPM 3), skeleton-first, checkpoint per system |
| **G6** | Parallel per system PARALLEL (Phase 3) | Đọc `phase3-screen-groups.md` | Mỗi system 1 agent ux-designer chạy đồng thời; sequential per module trong cùng system |
| **G7** | Auto-correction Phase 4 max 3 iterations | `phase4-crossval.md` | Cross-validation có 10 checks (8 + 2 CQG); retry ≤ 3 → E007/E008 nếu fail |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | Conditional consumer path khớp §4b | Cross-check `00-core.md §4b` dòng 200-201 | `produces_for.wf-plan-modules` bao gồm `stakeholder-review.md` + `ux-input-digest.json`. §4b ghi rõ "only if interface_type != api-only" — contract khớp ghi chú này |
| **CS2** | API-Only skipped flow không break downstream | Đọc §4b dòng 201 | Khi api-only → `wf-plan-modules` PRE-GATE phải đọc trực tiếp `/wf-design` output, KHÔNG đọc `ux-input-digest.json` (không tồn tại). Contract này nằm §4b, skill tự không tạo file |
| **CS3** | `ux-checkpoint.json` dual-role | `_contract.json` outputs.working[] + inputs[] | File vừa là output (LEGACY only) vừa là input resume (LEGACY only) — resume path có fallback khi `checkpoint.json` không tồn tại |
| **CS4** | `wf-annotate-code` consumer `<annotated-source-code-files>` | `_contract.json.cross_skill_contracts.consumes_from` | Input là source code (không phải `.mc-data/` path); notes rõ đây là placeholder ảo, không phải file cụ thể |
| **CS5** | `wf-fix-bugs` consumer screens path | Cross-check §4b | `consumes_from.wf-fix-bugs` = `phase4-ux/[sys]/[mod]/screens-[slug].md` khớp §4b dòng 253 (wf-fix-execute Phase 4b stub output) |

### 2.3 Constraint đặc biệt

- **Registry PRIMARY cho `ux_design_status`** — tuân thủ E15-E16 đầy đủ. KHÔNG được ghi field khác ngoài `ux_design_status`.
- **Skip toàn bộ khi api-only** — cần đảm bảo placeholder file (`stakeholder-review.md {status: "Skipped (API-Only)"}` + `design-ux-status.json {status: "skipped"}`) tồn tại để downstream `wf-plan-modules` không bị "silent missing input". POST-GATE đặc biệt cho api-only: file placeholder phải tồn tại dù nội dung rỗng.
- **LEGACY dual-branch** — Phase 0.5 chỉ chạy khi `$LEGACY_MODE` true; nếu LEGACY nhưng chưa chạy → skill vẫn chạy design mới (new project flow). Kiểm tra `legacy-decisions.json` graceful degradation (CORE-022).
- **Parallel agents per system, sequential per module trong system** — Phase 3 không đơn thuần parallel; có governance riêng. Khi review cần xác nhận contract đồng nhất.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: `phase0-context.md` có API-Only exit guard (grep `api-only` + stakeholder-review placeholder)
- [ ] G3: `phase0-5-legacy-ui.md` có early-return nếu `$LEGACY_MODE != true`
- [ ] G5: LPM ngưỡng đúng `>= 5 systems OR >= 40 features`
- [ ] CS1: `produces_for.wf-plan-modules` khớp ghi chú "api-only" trong §4b
- [ ] CS2: API-only path không tạo `ux-input-digest.json` — `wf-plan-modules` đọc từ wf-design thay thế
- [ ] E16: `registry_scope.fields_owned = ["ux_design_status"]` khớp §4a PRIMARY

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-design-ux/SKILL.md) | Overview, Phase Routing Map, Output Files, Arguments |
| [_contract.json](../../.claude/skills/workflow/wf-design-ux/_contract.json) | Schema-level contract, cross_skill_contracts |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-design-ux/procedures/_shared.md) | State vars, LEGACY injection, agent prompts |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-design-ux/procedures/) | 9 phase files (0, 0.5, 1-7) |
| [templates/](../../.claude/skills/workflow/wf-design-ux/templates/) | 3 internal templates |
| [evals/evals.json](../../.claude/skills/workflow/wf-design-ux/evals/evals.json) | Test cases (cần cover api-only exit + LEGACY) |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE rules — §4a `ux_design_status` PRIMARY, §4b api-only conditional |

---

## 5. Ghi chú bảo trì riêng file này

- Khi skill bump version (3.1, 4.0…) → cập nhật `skill.version` §1 + review G/CS.
- Khi thêm consumer mới cho wf-design-ux → cập nhật `contracts.consumers_count` + CS1-CS5.
- Khi LPM threshold đổi → cập nhật G5 số ngưỡng.
- Khi `interface_type` mở thêm option (ví dụ "voice", "cli") → cập nhật G1/G2 và CS1/CS2.
- File này là **read-only** trong quá trình review — không tự chỉnh findings; dùng file report riêng.
