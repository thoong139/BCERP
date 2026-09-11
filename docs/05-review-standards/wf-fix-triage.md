# Tiêu chuẩn rà soát — `wf-fix-triage` v1.1.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-fix-triage/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section**. Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Step 2/3 của pipeline `wf-fix-bugs` — Triage: classify severity + fixability + domain, tạo execution plan |
| **Entry point** | `procedures/phase2-triage.md` (single-phase) |
| **Kiến trúc** | Single-phase, sequential, KHÔNG spawn agents. Nhẹ, xử lý trong main conversation |
| **Execution mode** | Deterministic — classify logic dựa trên issue type, severity mapping bảng có sẵn |
| **Strategy routing** | Không có — linear flow |
| **Đặc trưng** | Share SESSION_DIR với wf-fix-discover (UPDATE `issue-registry.json`, không CREATE). Dùng 2 cross-skill template từ wf-fix-execute (`fix-plan.md`, `fix-log.json`) |
| **Output** | `bug-triage.md`, `fix-plan.md`, `issue-registry.json` (enriched — UPDATE), `fix-log.json` (init — empty entries), `phase-summary.md` |
| **Cross-skill** | Spawned by `wf-fix-bugs`; consumes từ `wf-fix-discover` POST-GATE; produces cho `wf-fix-execute` |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-fix-triage
  version: 1.1.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-fix-triage/

profile:
  # Kiến trúc
  is_orchestrator: false
  has_procedures: true            # 1 file: phase2-triage.md
  has_templates: true             # 1 file: bug-triage.md (2 template cross-skill từ wf-fix-execute)
  has_phases: true                # Single-phase (Phase 2 only)

  # State & Resume
  has_state_machine: true         # Update fix-status.json.phases.phase_2
  has_resume: true                # --resume (scan SESSION_DIR có phase_2 != completed)
  has_status: true                # --status
  is_multi_run: true              # Share SESSION_DIR với discover/execute (inherit isolation)

  # Execution
  spawns_agents: false            # Khong spawn agents — classify trong main conversation
  has_strategy_routing: false

  # Registry
  writes_registry: false          # fields_owned: [] (NONE)
  registry_role: NONE

contracts:
  producers_count: 1              # wf-fix-discover
  consumers_count: 1              # wf-fix-execute
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | A1-A10 | Single-phase nhưng vẫn có procedures/ |
| **B** Workflow Integrity | B1-B4, B6-B8 | B5 (conditional phase) SKIP. B9/B10 (strategy) SKIP |
| **C** Output & Template | C1-C7 | CS: 2 template cross-skill từ wf-fix-execute |
| **D** Cross-Skill | D1-D4 | 1 producer + 1 consumer — verify paths rất chặt |
| **E** Protocol & CORE | E1-E10, E13, E14; SKIP E4/E11 (no agents), E15-E16 (no registry), E17/E18 nếu không có LEGACY flow | |
| **F** Determinism/Agent | F1 (phase deterministic KHÔNG spawn agent) — F2-F4 SKIP | |
| **H** Error Handling | H1-H5 | |
| **I** Testability | I1-I5 | 6 test cases — cần cover mix severity, all-CRITICAL, empty issues, escalate cases |
| **J** Idempotency | J1, J2, J4 | J3 SKIP (không script output). Re-run PHẢI overwrite bug-triage/fix-plan, UPDATE issue-registry fields (không duplicate) |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Triage Taxonomy (Severity + Fixability + Domain)

Tiêu chuẩn này **không tổng quát hóa** — chỉ áp dụng cho `wf-fix-triage`.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | Severity taxonomy đầy đủ 4 levels | `procedures/phase2-triage.md` | Có đủ: CRITICAL, HIGH, MEDIUM, LOW. Mỗi level có định nghĩa rõ (CRITICAL: block build/production; HIGH: security/data loss; MEDIUM: lint/performance; LOW: cosmetic) |
| **G2** | Fixability taxonomy rõ ràng | Triage logic | Có đủ các giá trị: AUTO_FIX (lint, formatter), AGENT_FIX (logic/refactor), MANUAL_FIX (architectural), ESCALATE (out-of-scope), SKIP (deprecated/out-of-scope) |
| **G3** | Domain classification từ issue source | Triage logic | Domain set theo issue.type: `security`, `finance`, `auth`, `ui`, `api`, `db`, `general`. Dùng cho route agent phù hợp ở wf-fix-execute |
| **G4** | Severity mapping deterministic | Bảng mapping trong `_shared.md` hoặc `phase2-triage.md` | Cùng một `issue.type` + `source` → cùng severity. Không AI subjective. Reproducible |
| **G5** | Batch assignment theo severity | Triage logic | `issues[].batch`: batch_1 = CRITICAL, batch_2 = HIGH, batch_3 = MEDIUM+LOW. Align với wf-fix-execute Phase 3 batches |
| **G6** | Out-of-scope marking (CORE-022 LEGACY) | Procedure | Issues thuộc module có `$DEPRECATED_MODULES` → `out_of_scope=true`, fixability=SKIP. Graceful degradation khi `legacy-decisions.json` không tồn tại |
| **G7** | CDG user confirmation trước fix plan | `phase2-triage.md` Step 2.7 | Sau khi triage xong, display summary + ask user xác nhận before route sang wf-fix-execute (Protocol 16 — Critical Decision Gate) |
| **G8** | Execution Plan có ordering | `bug-triage.md` template | Execution plan liệt kê batches theo thứ tự + estimated duration + ai-owner per batch |

### 2.2 NHÓM CS — Cross-skill contract đặc thù (shared SESSION_DIR)

`wf-fix-triage` là **UPDATE-only** cho `issue-registry.json` và `fix-status.json` — không CREATE.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | PRE-GATE check wf-fix-discover POST-GATE | `_contract.json.prerequisites` + SKILL.md PRE-GATE | `jq -e '.phases.phase_1.status == "completed"' $SESSION_DIR/fix-status.json` + `test -s $SESSION_DIR/issue-registry.json`. Không chỉ file existence (CORE-011) |
| **CS2** | `issue-registry.json` UPDATE-only | `_contract.json.outputs.working[2].template==null` + notes | Template null. Notes ghi rõ "UPDATE (KHONG CREATE) — enrich severity/batch/fixability/domain. Giu nguyen cac fields khac". File đã tồn tại từ wf-fix-discover |
| **CS3** | 2 cross-skill templates từ wf-fix-execute | `_contract.json.outputs.working[1,3].template` | `fix-plan.md` template = `../wf-fix-execute/templates/fix-plan.md`. `fix-log.json` template = `../wf-fix-execute/templates/fix-log.json`. Có `uses_templates_from` block ở cross_skill_contracts |
| **CS4** | `$SESSION_DIR` shell variable, KHÔNG bracket placeholder | Template cross-skill rendering | Khi render fix-plan.md từ template, GIỮ NGUYÊN `$SESSION_DIR` — đây là shell variable runtime, không replace như `{{placeholder}}` |
| **CS5** | `fix-log.json` init với entries rỗng | Step 2.3c | Khởi tạo `entries: []` + `fix_id` set. wf-fix-execute sẽ APPEND sau. Không duplicate entries khi re-run |
| **CS6** | Orchestrator-aware phase-summary | `phase2-triage.md` Step 2.8 | Sub-skill của wf-fix-bugs orchestrator → ghi vào shared SESSION_DIR, OVERWRITE phase-summary.md của phase trước. Nếu POST-GATE fail 3 iter → VẪN tạo với status "THAT BAI" |
| **CS7** | Resume scan theo phase_2 completion | SKILL.md §Entry Point --resume | `find .mc-data/work/wf-fix-bugs -maxdepth 4 -name fix-status.json` + filter `phases.phase_2.status != "completed"` → đa dạng scope coverage (ROOT + sessions/**) |

### 2.3 Constraint đặc biệt

- **KHÔNG spawn agents** — classify là deterministic logic; tất cả xử lý main conversation. F1 áp dụng.
- **KHÔNG ghi registry** — `fields_owned: []`. Chỉ wf-fix-execute Phase 4 mới có quyền update `impl_status`.
- **UPDATE-only pattern** — `issue-registry.json` và `fix-status.json` đã có từ wf-fix-discover. Phải dùng merge/enrich pattern, không overwrite (tránh mất data từ discover).
- **2 cross-skill templates** — thuộc về wf-fix-execute nhưng được consume bởi wf-fix-triage. Rationale: `fix-plan.md` + `fix-log.json` là **input** của wf-fix-execute → template là owner của execute.
- **Single-phase architecture** — chỉ Phase 2. `procedures/` chỉ có 1 file. Nhưng vẫn tuân thủ pattern PRE-GATE → STEPS → POST-GATE → Next Phase.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Severity taxonomy đủ 4 levels (CRITICAL/HIGH/MEDIUM/LOW)
- [ ] G2: Fixability đủ 5 giá trị (AUTO_FIX/AGENT_FIX/MANUAL_FIX/ESCALATE/SKIP)
- [ ] G5: Batch assignment align với wf-fix-execute Phase 3 batch structure
- [ ] G7: CDG user confirmation trước khi hoàn thành triage (Step 2.7)
- [ ] CS1: PRE-GATE kiểm nội dung `phases.phase_1.status == "completed"` (CORE-011 forensic)
- [ ] CS2: `issue-registry.json` UPDATE-only (không overwrite fields từ discover)
- [ ] CS3: 2 cross-skill templates reference đúng path `../wf-fix-execute/templates/`
- [ ] CS5: `fix-log.json` init với `entries: []` — KHÔNG prefill data
- [ ] evals ≥ 3 cases cover: mix severity, all-CRITICAL, empty, --resume sau fail, escalate

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-fix-triage/SKILL.md) | Overview, Entry Point (spawned + --resume) |
| [_contract.json](../../.claude/skills/workflow/wf-fix-triage/_contract.json) | Outputs (4 working + 1 phase-summary), cross-skill contracts |
| [procedures/phase2-triage.md](../../.claude/skills/workflow/wf-fix-triage/procedures/phase2-triage.md) | Single phase — classify logic + steps 2.1-2.8 |
| [templates/bug-triage.md](../../.claude/skills/workflow/wf-fix-triage/templates/bug-triage.md) | Template bug-triage output |
| [evals/evals.json](../../.claude/skills/workflow/wf-fix-triage/evals/evals.json) | 6 test cases |
| [wf-fix-bugs.md](./wf-fix-bugs.md) | Orchestrator spawning skill này |
| [wf-fix-discover.md](./wf-fix-discover.md) | Upstream producer |
| [wf-fix-execute.md](./wf-fix-execute.md) | Downstream consumer (templates owner) |
| [`_template-common.md`](./_template-common.md) | Tiêu chuẩn chung |

---

## 5. Ghi chú bảo trì riêng file này

- Khi thêm severity level mới (ví dụ: CATASTROPHIC) → cập nhật G1 + batch mapping G5 + evals I2.
- Khi wf-fix-execute thay schema `fix-plan.md` / `fix-log.json` template → verify CS3/CS4/CS5 còn khớp.
- Khi domain list G3 mở rộng → align với wf-fix-execute agent routing table.
- Khi thay đổi CDG trigger points → cập nhật G7 + Protocol 16 reference.
- File này là **read-only** trong quá trình review — findings ghi vào `reports/`.
