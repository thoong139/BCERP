# Tiêu chuẩn rà soát — `wf-fix-bugs` v5.1.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-fix-bugs/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section**. Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | **Pure orchestrator** — điều phối tuần tự 3 sub-skills: `wf-fix-discover` → `wf-fix-triage` → `wf-fix-execute` |
| **Entry point** | Chỉ có `SKILL.md` (không có `procedures/`); orchestrator flow nằm inline trong SKILL.md |
| **Kiến trúc** | Delegate 100% cho sub-skills; orchestrator CHỈ làm 3 việc: (1) PRE-GATE tổng, (2) spawn tuần tự & chờ POST-GATE, (3) xử lý `--dry-run`/`--resume` routing |
| **Execution mode** | Sequential 3-step pipeline với wait-between-steps |
| **Strategy routing** | Không có strategy scoring — chỉ có `--resume` routing qua `fix-status.json.active_skill` |
| **Đặc trưng** | KHÔNG có `procedures/`, KHÔNG có `templates/`, KHÔNG ghi registry |
| **Output** | `outputs.working[]` = `[]` (rỗng). Mọi output thực tế sinh bởi sub-skills trong `$SESSION_DIR` chung |
| **Cross-skill** | Orchestrates 3 sub-skills; produces_for (via sub-skills) 3 consumers (`wf-verify-sync`, `wf-define-features`, `wf-design-ux` stubs); consumes_from 2 producers (`wf-preflight`, `wf-brainstorm` legacy) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-fix-bugs
  version: 5.1.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-fix-bugs/

profile:
  # Kiến trúc — ĐẶC BIỆT
  is_orchestrator: true           # PURE orchestrator — delegate 100%
  has_procedures: false           # KHÔNG có procedures/
  has_templates: false            # KHÔNG có templates/
  has_phases: false               # Orchestrator flow inline; 3 "bước" = 3 sub-skills

  # State & Resume
  has_state_machine: true         # fix-status.json state shared với sub-skills (active_skill field)
  has_resume: true                # --resume → route theo active_skill
  has_status: true                # --status
  is_multi_run: true              # Share session isolation contract với sub-skills (SESSION_DIR theo scope)

  # Execution
  spawns_agents: false            # KHÔNG spawn subagent_type — chỉ spawn Skill (sub-skill)
  has_strategy_routing: false     # Không có S1-S7; chỉ có linear pipeline

  # Registry
  writes_registry: false          # fields_owned: [] (NONE role)
  registry_role: NONE

contracts:
  producers_count: 2              # wf-preflight (optional), wf-brainstorm (LEGACY)
  consumers_count: 3              # wf-verify-sync (chính), wf-define-features (stubs --deep), wf-design-ux (stubs --deep)
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | Phần — A1/A2/A3/A4/A5/A9/A10 | A6 đánh theo nhánh `is_orchestrator=true` (tối thiểu SKILL.md + _contract.json + evals/). A7 SKIP (không phân tách SKILL.md vs procedures). A8 SKIP (không có routing map/procedures) |
| **B** Workflow Integrity | SKIP B1-B6, B9-B10 | Áp dụng B7 (--status/--resume dispatch), B8 (transition rule giữa sub-skills qua `fix-status.json.active_skill`) |
| **C** Output & Template | SKIP C1-C7 | `outputs.working[] = []`; không có template. CHỈ kiểm tra `_contract.json.cross_skill_contracts.orchestrates[]` |
| **D** Cross-Skill | Áp dụng D1-D4 | Orchestrates 3 sub-skills + forward produces_for từ sub-skills. Kiểm tra drift với §4b |
| **E** Protocol & CORE | Áp dụng E1, E5, E8, E9, E10, E14; SKIP E2-E4, E6-E7, E11-E13, E15-E18 | E1 verify sau mỗi sub-skill POST-GATE. E5 Task Planning (TodoWrite 3 items). E8 CDG cho destructive forward (confirm trước Phase 3 execute). E10 trace bắt buộc |
| **F** Determinism/Agent | SKIP F1-F7 | Không spawn agent trực tiếp. Delegate qua Skill tool |
| **H** Error Handling | Áp dụng H1, H3, H4, H5 | H2 SKIP (không tự write state — `fix-status.json` do sub-skills quản) |
| **I** Testability | Áp dụng I1-I5 | 15 test cases có sẵn — cần cover: dry-run, resume routing, scope system/module, --deep forward |
| **J** Idempotency | Áp dụng J2, J4 | J1 SKIP (orchestrator không write state). J3 SKIP (không generate script output) |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Orchestration Contract với 3 sub-skills

Tiêu chuẩn này **không tổng quát hóa** — chỉ áp dụng cho `wf-fix-bugs` (pure orchestrator pattern).

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | 3 bước orchestrate đầy đủ & đúng thứ tự | `_contract.json.cross_skill_contracts.orchestrates[]` | Có 3 entries theo thứ tự `step: 1 (wf-fix-discover)` → `step: 2 (wf-fix-triage)` → `step: 3 (wf-fix-execute)`. Mỗi entry có `trigger` và `validation` rõ |
| **G2** | Mỗi bước có POST-GATE validation cụ thể (jq) | Parse `orchestrates[].validation` | Entry 1: check `phases.phase_1.status=="completed"` + `issue-registry.json` tồn tại. Entry 2: `phase_2.status=="completed"` + `bug-triage.md` + `fix-plan.md` + `fix-log.json`. Entry 3: `status=="completed"` + `phase_6.status=="completed"` + `fix-report.md` + `fix-history.md` |
| **G3** | Arguments pass-through rõ ràng | `orchestrates[1].passes_inline` | Liệt kê đầy đủ arguments orchestrator forward cho `wf-fix-discover`: `mo-ta-loi`, `--scope`, `--name`, `--dry-run`, `--deep`, `--full-test`, `--responsive`, `--no-browser`, `--browser-only`, `--url`, `--credentials` |
| **G4** | `--dry-run` được forward đúng sub-skill xử lý | SKILL.md flag handling + `_contract.json.orchestrates[].passes_inline` | `--dry-run` pass inline cho `wf-fix-discover`; `wf-fix-triage` và `wf-fix-execute` đọc `dry_run` từ `fix-status.json.flags.dry_run`. Orchestrator KHÔNG tự skip step nào — wf-fix-execute tự skip Phase 3-5 khi `dry_run=true` |
| **G5** | `--resume` routing qua `active_skill` | `_contract.json.resume_routing.rules[]` | 4 rules cho 4 giá trị `active_skill` (`wf-fix-discover`/`wf-fix-triage`/`wf-fix-execute`/`wf-fix-bugs`). Nếu `active_skill != 'wf-fix-bugs'` → STOP và nhắc user chạy `/<sub-skill> --resume` |
| **G6** | Version compatibility matrix công khai | SKILL.md §Version Alignment | Bảng liệt kê version hiện tại của từng sub-skill và compatible orchestrator range; orchestrator version (5.x) KHÔNG bắt buộc bump khi sub-skill patch |
| **G7** | Orchestrator KHÔNG ghi output riêng | `jq '.outputs.working' _contract.json` | Mảng rỗng `[]`. Nếu có entry → sai kiến trúc pure orchestrator (BLOCKER) |
| **G8** | Sub-skill chain tuân thủ `active_skill` lifecycle | `fix-status.json` schema | `active_skill` tuần tự set: `wf-fix-discover` (start P0) → `wf-fix-bugs` (sau POST-GATE P1, next_action=`phase_2_triage`) → `wf-fix-triage` → `wf-fix-bugs` (next=`phase_3_execute`) → `wf-fix-execute` → `wf-fix-bugs` (next=`done`). Check qua evals coverage |

### 2.2 NHÓM CS — Cross-skill contract đặc thù (SESSION_DIR shared)

4 skills (`wf-fix-bugs` + 3 sub-skills) share **cùng 1 session directory** — đây là nhóm có cross-skill contract RẤT chặt.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | `$SESSION_DIR` resolution duy nhất, nhất quán | `00-core.md §4b` | Orchestrator KHÔNG tự resolve `$SESSION_DIR` — `wf-fix-discover` Phase 0 là **owner**. Orchestrator chỉ re-locate bằng `find -maxdepth 4` (latest timestamp) khi `--resume` |
| **CS2** | `fix-status.json` ownership rõ ràng (shared file) | `_contract.json.outputs` của 4 skills | `wf-fix-discover` = **CREATOR** (Phase 0). `wf-fix-triage` = **UPDATER** (Phase 2 status + active_skill). `wf-fix-execute` = **UPDATER** (Phase 3-6). `wf-fix-bugs` = **READER only** (check POST-GATE giữa các step) |
| **CS3** | 3 variants `$SESSION_DIR` theo scope | `00-core.md §4b` + `wf-fix-triage/_contract.json.prerequisites.session_dir_variants` | `scope=all` → `.mc-data/work/wf-fix-bugs/run-NNN--YYYYMMDD/` (root). `scope=system` → `.mc-data/work/wf-fix-bugs/sessions/{sys-id}/run-NNN--YYYYMMDD/`. `scope=module` → `.mc-data/work/wf-fix-bugs/sessions/{sys-id}/{mod-id}/run-NNN--YYYYMMDD/` |
| **CS4** | `produces_for` của orchestrator = union(sub-skills) | Diff `_contract.json.cross_skill_contracts.produces_for` vs produces_for từng sub-skill | Mọi entry trong produces_for orchestrator PHẢI ghi rõ `(via wf-fix-<sub>)` — để auditor biết file thực sinh bởi sub-skill nào |
| **CS5** | Orchestrator KHÔNG sở hữu template của sub-skills | Verify không có `templates/` folder | `ls .claude/skills/workflow/wf-fix-bugs/templates/` → directory không tồn tại |

### 2.3 Constraint đặc biệt

- **KHÔNG có `procedures/`** — toàn bộ flow nằm inline trong SKILL.md (~25K). Đây là ngoại lệ duy nhất với template v3.0 (vốn yêu cầu procedures/). Tiêu chuẩn A7/A8 SKIP.
- **KHÔNG có `templates/`** — skill không sinh output. Tiêu chuẩn C1-C7 SKIP.
- **KHÔNG ghi registry** — `fields_owned: []`. Tiêu chuẩn E15-E16 SKIP. CHỈ `wf-fix-execute` (sub-skill) mới có quyền update `impl_status`.
- **Không spawn subagent** — delegate qua Skill tool (invoke sub-skill), không qua Agent tool. Tiêu chuẩn F2-F4 SKIP.
- **Orchestrator version có thể lệch với sub-skills** — version alignment matrix cần bảo trì khi sub-skill patch lớn.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: 3 entries trong `orchestrates[]` đúng thứ tự discover → triage → execute
- [ ] G2: Mỗi entry có `validation` jq expression kiểm POST-GATE sub-skill
- [ ] G5: `resume_routing.rules[]` đủ 4 `active_skill` giá trị
- [ ] G7: `outputs.working` = `[]` (rỗng — pure orchestrator)
- [ ] CS3: 3 variants SESSION_DIR documented rõ trong cross-skill contract
- [ ] CS4: Mọi `produces_for[*]` ghi rõ `(via wf-fix-<sub>)`
- [ ] `procedures/` KHÔNG tồn tại, `templates/` KHÔNG tồn tại (đúng profile `is_orchestrator=true`)
- [ ] evals ≥ 3 test cases cover: basic (all scope), dry-run, resume routing, scope=system/module

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-fix-bugs/SKILL.md) | Orchestrator flow inline (~25K, Overview + 3 steps + resume routing) |
| [_contract.json](../../.claude/skills/workflow/wf-fix-bugs/_contract.json) | Pure orchestrator contract (outputs=[], orchestrates[]) |
| [evals/evals.json](../../.claude/skills/workflow/wf-fix-bugs/evals/evals.json) | 15 test cases |
| [`_template-common.md`](./_template-common.md) | Tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) |
| [wf-fix-discover.md](./wf-fix-discover.md) | Sub-skill step 1 |
| [wf-fix-triage.md](./wf-fix-triage.md) | Sub-skill step 2 |
| [wf-fix-execute.md](./wf-fix-execute.md) | Sub-skill step 3 |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4a/§4b | Registry scope (NONE role) + SESSION_DIR paths |

---

## 5. Ghi chú bảo trì riêng file này

- Khi orchestrator bump **major** (6.0…) → re-check G3 (arguments), G6 (version matrix), G8 (active_skill lifecycle).
- Khi sub-skill thay đổi output (thêm/bớt file) → update CS4 (produces_for forwarding).
- Khi thêm sub-skill thứ 4 → update G1/G2 (thêm entry `orchestrates[]`), cập nhật `contracts.consumers_count`.
- Khi template v3.0 mở rộng hỗ trợ pattern "orchestrator" chính thức → xem lại A7/A8 có cần apply hay không.
- File này là **read-only** trong quá trình review — findings ghi vào `reports/`.
