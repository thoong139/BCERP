# Tiêu chuẩn rà soát — `wf-add-scope` v1.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-add-scope/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Incremental scope addition — safe-append modules + features vào registry đã có |
| **Entry point** | `procedures/flow-new.md` (monolithic — chưa tách phase files) |
| **Kiến trúc** | SKILL.md chứa phase steps inline (pattern cũ, chưa refactor sang lazy-load v3.0) |
| **Execution mode** | 100% DETERMINISTIC — không spawn agents (pure data manipulation) |
| **Phases** | 8 phases (0-7): Context → Scope Spec → Stub Gen (LEGACY) → Dry-Run → Safe-Append → Docs → Report → Summary |
| **Đặc trưng** | 3 input modes: `--from-mapping` / `--modules=<list>` / `--interactive`; APPEND-ONLY registry; idempotent |
| **Output** | 6 working files + optional Phase 2 stubs + registry safe-append |
| **Cross-skill** | Consumes từ 3 skills, produces cho 3 skills |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-add-scope
  version: 1.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-add-scope/

profile:
  is_orchestrator: false
  has_procedures: true             # có procedures/flow-new.md (monolithic legacy pattern)
  has_templates: true              # 4 internal templates
  has_phases: true                 # 8 phases inline trong SKILL.md

  has_state_machine: false         # chỉ có checkpoint.json, không có ledger states
  has_resume: true                 # --resume flag (dù pattern nhẹ)
  has_status: true                 # --status flag
  is_multi_run: false              # ghi thẳng vào .mc-data/work/wf-add-scope/ root (không sessions/)

  spawns_agents: false             # SKILL.md khai: "Skill này xử lý trực tiếp (không spawn agents)"
  has_strategy_routing: false      # có 3 input modes nhưng không phải strategy scoring

  writes_registry: true
  registry_role: APPEND            # §4a: APPEND chỉ cho modules[] + features[]

contracts:
  producers_count: 3               # wf-legacy-scan, wf-brainstorm, wf-analyze-requirements
  consumers_count: 3               # wf-define-features, wf-plan-modules, wf-annotate-code
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ A1-A10 | A7 có risk: SKILL.md hiện CÒN chứa execution steps (phases 0-7 viết inline), chưa refactor sang lazy-load — cần ghi finding |
| **B** Workflow Integrity | ⚠️ B1-B5 | B6-B10 SKIP (không state machine, không strategy routing); B7 áp dụng cho `--status`/`--resume` |
| **C** Output & Template | ✅ C1-C7 | 4 internal + 1 doc-framework + 2 meta templates. C5 quan trọng: `dry-run-diff.md`, `checkpoint.json`, Phase 2 stubs đều conditional |
| **D** Cross-Skill | ✅ D1-D4 | Check drift với §4b rows cho add-scope (2 producer + 2 consumer entries) |
| **E** Protocol & CORE | ✅ E1-E10, E13-E16 | E4/E11 SKIP (`spawns_agents=false`); E12 SKIP (`is_multi_run=false`); E17/E18 áp dụng khi `--from-mapping` |
| **F** Determinism/Agent | ⚠️ F1, F5, F6 | F2-F4 SKIP (không spawn); F7 SKIP |
| **H** Error Handling | ✅ H1-H5 | Đặc biệt H2 (atomic registry write + rollback từ backup) |
| **I** Testability | ✅ I1-I5 | Cần cover 3 input modes + idempotency re-run |
| **J** Idempotency | ✅ J1-J3 | J4 SKIP; J1 CỰC KỲ QUAN TRỌNG — đặc thù APPEND skill |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — APPEND-Only Semantics & Idempotency

Tiêu chuẩn **không tổng quát hóa** — chỉ áp dụng cho `wf-add-scope`.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | APPEND-only rule tuyệt đối | Grep `modules[]`/`features[]` trong Phase 4 | Chỉ dùng `jq '.modules += $new'` và `.features += $new`; KHÔNG có `|=`, `map(if)`, xóa, rename existing entries |
| **G2** | Safe-Write fields_owned giới hạn đúng 2 fields | `jq '.registry_scope.fields_owned' _contract.json` | Giá trị chính xác: `["modules", "features"]`. Không phải `requirements[]`, `systems[]`, `impl_status` |
| **G3** | Dedup by ID trước khi append | Phase 1.3 logic | Match by `id` HOẶC `name+sys_id`; đưa vào `existing_conflicts[]` với `action:"skip"` — KHÔNG overwrite |
| **G4** | Idempotency: re-run skill KHÔNG tạo duplicate | Test case | Chạy 2 lần liên tiếp cùng input → lần 2 có 0 new entries, `summary.total_modules_skipped == total_modules_proposed` |
| **G5** | Backup + Rollback on validation fail | Phase 4.1, 4.8 | `cp registry.json.pre-addscope-<timestamp>` TRƯỚC write; rollback nếu post-write `jq` validation fail (E005) |
| **G6** | 3 input modes mutual exclusion | Phase 1 logic | Input source logic chọn đúng 1 trong 3: `--from-mapping` / `--modules=<list>` / `--interactive`. Thiếu cả 3 → E002 |
| **G7** | `--from-mapping` gắn chặt LEGACY_MODE | Phase 1 ELIF branch + E003 | Nếu `--from-mapping` nhưng `$LEGACY_MODE == false` → STOP E003 với hướng dẫn chạy `/wf-legacy-scan` trước |
| **G8** | Module ID naming convention | Phase 1 §Module ID Naming | Format `MOD-[SYS_SHORT]-[DOMAIN]`; `SYS_SHORT` = drop prefix `SYS-` + drop dashes; DOMAIN uppercase |
| **G9** | Dry-run STOP gate | Phase 3.3 | `--dry-run` → skill STOP ngay sau `dry-run-diff.md`, KHÔNG chạy Phase 4 (không ghi registry) |
| **G10** | Phase 2 Feature Stub CHỈ LEGACY_MODE | Phase 2 PRE-GATE | NEW project → `features_to_add` rỗng → defer sang `/wf-define-features`; Phase 5 tự SKIP theo guard |
| **G11** | Legacy decisions DEPRECATE filter | Contract inputs + Phase 0/1 | Modules nằm trong `legacy-decisions.json` với `action: "DEPRECATE"` KHÔNG được append vào registry (CORE-022) |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

Mở rộng NHÓM D cho ownership paths đặc biệt:

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | Producer `module-code-mapping.json` ownership rõ ràng | §4b cross-check | File được **sinh thực tế** bởi `wf-legacy-extract` Stage 3.5 (hoặc forward qua `wf-legacy-scan`). `wf-add-scope` chỉ **consume**, không sinh |
| **CS2** | APPEND registry → trigger re-run downstream | Contract note + Report Phase 6 | Output report ghi rõ "Next Steps: chạy `/wf-plan-modules` re-run" và `/wf-define-features` cho flesh-out stubs |
| **CS3** | Phase 2 stub banner mandatory | Phase 5.4 + template `feature-stub.md` | Mỗi stub file bắt đầu bằng `> [STUB AUTO-GENERATED BY /wf-add-scope] — Review và flesh-out cần thiết.` |
| **CS4** | Stub conflict không overwrite user content | Phase 5 + E007 | Nếu `phase2-features/.../[feat-slug].md` đã tồn tại (non-stub) → SKIP + log, KHÔNG ghi đè |
| **CS5** | Downstream consumer detect `stub: true` flag | Feature entry schema | Mỗi feature stub có field `stub: true` để `/wf-define-features` biết cần flesh-out |

### 2.3 Constraint đặc biệt

- **APPEND role duy nhất trong §4a** — khác PRIMARY/SEED/UPDATE-MODE. Validation chặt hơn: không chỉ check safe-write mà còn check "count_after == count_before + count_added" (Phase 4.6).
- **Không spawn agents** — đơn giản hóa review (F2-F4 SKIP), nhưng G3-G4 phức tạp hơn (data manipulation logic đúng).
- **Monolithic procedures pattern** — khác v2.0+ skills (wf-manage-change, wf-prepare-deployment đã tách phase files). Finding suggest: refactor SKILL.md sang lazy-load pattern để đồng nhất v3.0 template.
- **3 input modes → test coverage chặt** — evals PHẢI cover cả 3 modes + dry-run + idempotency re-run.
- **Không multi-run session isolation** (`is_multi_run=false`) — skill ghi thẳng vào root folder. Chấp nhận được vì APPEND idempotent, nhưng cần J1 nghiêm ngặt.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Phase 4 chỉ dùng `jq '.modules += $new'` — không có operator modify existing
- [ ] G2: `fields_owned == ["modules", "features"]` (không thừa field khác)
- [ ] G4: Test case idempotency (chạy 2 lần → lần 2 zero new)
- [ ] G7: `--from-mapping` + non-LEGACY → STOP E003 đúng
- [ ] G11: DEPRECATE modules bị filter out ở Phase 1
- [ ] CS1: `module-code-mapping.json` KHÔNG sinh bởi skill này (chỉ consume)
- [ ] CS3: Mỗi Phase 2 stub có banner `[STUB AUTO-GENERATED]`
- [ ] Registry backup file pattern `req-registry.json.pre-addscope-<timestamp>` tồn tại sau Phase 4

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-add-scope/SKILL.md) | Overview, Arguments, 8 phases inline |
| [_contract.json](../../.claude/skills/workflow/wf-add-scope/_contract.json) | Output contract, APPEND registry scope |
| [procedures/flow-new.md](../../.claude/skills/workflow/wf-add-scope/procedures/flow-new.md) | Monolithic procedures (pattern cũ) |
| [templates/](../../.claude/skills/workflow/wf-add-scope/templates/) | 4 internal templates (status, plan, scope-spec, feature-stub) |
| [evals/evals.json](../../.claude/skills/workflow/wf-add-scope/evals/evals.json) | Test cases |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4a | Registry role APPEND definition |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4b | Cross-skill rows: wf-add-scope Phase 4 + Phase 5 |

---

## 5. Ghi chú bảo trì riêng file này

- Khi skill refactor SKILL.md sang lazy-load pattern (v2.0.0) → xóa cảnh báo A7 + cập nhật `has_phases`/`procedures` structure.
- Khi thêm input mode mới (vd: `--from-code-scan`) → cập nhật G6 + evals I2 coverage.
- Khi APPEND semantics mở rộng (vd: append `departments[]`) → cập nhật G2 `fields_owned` list.
- Nếu `module-code-mapping.json` ownership đổi (vd: sinh bởi add-scope Phase 1.x) → cập nhật CS1.
- File này là **read-only** trong quá trình review — findings đi file report riêng.
