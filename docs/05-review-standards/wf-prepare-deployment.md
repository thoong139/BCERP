# Tiêu chuẩn rà soát — `wf-prepare-deployment` v2.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-prepare-deployment/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Phase 6 — tạo 4 deployment docs + stakeholder review (entry cuối DEVKIT workflow trước Release) |
| **Entry point** | `procedures/phase0-flags.md` (lazy-load v2.0 — tách từ monolithic) |
| **Kiến trúc** | 10 phase files + `_shared.md` lazy-loaded; 10 phases (0/1/2/3a/3b/3c/4/4a/5/5a) |
| **Execution mode** | Hỗn hợp: Phase 1 main context, Phase 2 ∥ 3a PARALLEL agents, Phase 5a 4 agents (3 parallel + 1 sequential) |
| **Phases** | 10 phases; 2 PARALLEL checkpoint (Phase 2∥3a, Phase 5a multi-agent) |
| **Đặc trưng** | LPM auto-detect (Large Project Mode: systems≥5 OR depts≥10 OR reqs≥50 OR features≥40); sync rate gate ≥80% |
| **Output** | 4 doc outputs + 3 working files (status/plan/checkpoint); không ghi registry |
| **Cross-skill** | Consumes từ 1 skill (wf-verify-sync); không produce cho DEVKIT skill nào (chỉ cho Release/Go-Live) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-prepare-deployment
  version: 2.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-prepare-deployment/

profile:
  is_orchestrator: false
  has_procedures: true             # 10 phase files + _shared.md (v2.0 lazy-load)
  has_templates: true              # 3 internal templates + 4 doc-framework templates
  has_phases: true                 # 10 phases với routing map

  has_state_machine: true          # prepare-deployment-status.json + checkpoint.json cho LPM
  has_resume: true                 # --resume từ checkpoint (LPM multi-session)
  has_status: true                 # --status
  is_multi_run: false              # ghi thẳng vào .mc-data/work/wf-prepare-deployment/ root

  spawns_agents: true              # devops, tech-writer, sre, qa-lead, integration-certifier, reality-checker
  has_strategy_routing: false      # có --scope={all, deployment, user-guide, maintenance} nhưng không phải scoring

  writes_registry: false           # fields_owned: []
  registry_role: NONE

contracts:
  producers_count: 1               # wf-verify-sync
  consumers_count: 0               # không consumer DEVKIT nào — terminal skill trước Release/Go-Live
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ A1-A10 | |
| **B** Workflow Integrity | ✅ B1-B8 | B9-B10 SKIP (không strategy scoring); B7 quan trọng cho `--resume` LPM |
| **C** Output & Template | ✅ C1-C7 | 4 doc-framework templates trong `phase6-deployment/` + 3 internal templates |
| **D** Cross-Skill | ⚠️ D1 SKIP | `consumers_count=0` → `produces_for: {}`. Chỉ check D2 (consumes_from wf-verify-sync) + D3-D4 |
| **E** Protocol & CORE | ✅ E1-E14 | E15-E16 SKIP (`writes_registry=false`); E12 SKIP (`is_multi_run=false`); E17/E18 N/A (không legacy flow) |
| **F** Determinism/Agent | ✅ F2-F4 | F1, F5-F7 N/A (không có deterministic enumeration, không strategy scoring) |
| **H** Error Handling | ✅ H1-H5 | 12 error codes (E001-E012); E008 context threshold; E011 deployment env mismatch MANUAL REVIEW |
| **I** Testability | ✅ I1-I5 | Cần cover: happy path small, LPM multi-session, sync rate <80% gate |
| **J** Idempotency | ✅ J1-J3 | J4 SKIP (không multi-run) |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Large Project Mode + Parallel Agent Orchestration

Tiêu chuẩn **không tổng quát hóa** — chỉ áp dụng cho `wf-prepare-deployment`.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | LPM auto-detect formula | `procedures/phase1-prereq.md` + `_shared.md` | Formula rõ: `systems>=5 OR depts>=10 OR reqs>=50 OR features>=40`. Nếu ANY condition met → LPM=true |
| **G2** | Sync rate gate ≥80% | Phase 1 + E003 | Đọc `verify-sync.md` → extract sync_rate. Nếu < 80% → E003 WARNING + AskUserQuestion. Nếu >= 80% → continue |
| **G3** | Parallel Phase 2 ∥ 3a | Phase 2 + 3a specs | Hai phase ghi 2 file khác nhau (deployment-guide.md vs user-guide.md) → đủ điều kiện PARALLEL (CORE-025); spawn 2 agents đồng thời |
| **G4** | Cross-File Write Conflict Avoidance | Phase 3b + 4 note | Phase 3b (Muc 9) và Phase 4 (Muc 10) đều append vào `deployment-guide.md` → PHẢI dùng Edit (append) không Write overwrite; E012 rollback nếu ghi đè |
| **G5** | Phase 5a 4-agent orchestration | Phase 5a spec | 3 agents PARALLEL (devops, qa-lead, integration-certifier) + 1 SEQUENTIAL sau (reality-checker) vì reality-checker cần output 3 agents trước |
| **G6** | LPM checkpoint threshold chặt hơn | Phase 3c context check | LPM=true → checkpoint ngay khi context >= 65% (chặt hơn normal 80%); E008 FORCE STOP khi >= 90% |
| **G7** | Skeleton-first cho doc lớn | Phase 2/3a agent prompt | Nếu dự kiến output > 3000 từ (deployment-guide) hoặc > 2000 từ (user-guide) → agent dùng skeleton-first approach (outline trước, content sau) |
| **G8** | Architecture digest re-use | Phase 2 input | Nếu `design-input-digest.json` tồn tại → inject vào agent prompt (tránh re-read toàn bộ P3-01); nếu không tồn tại → pre-compress bằng Grep (Protocol 6.2 fallback) |
| **G9** | Content Quality Gate Phase 5 | Phase 5 spec | Auto-correction loop check: 10 Muc đầy đủ + cross-ref API + service names + section depth + registry freshness. Max 3 iterations; E009 escalate nếu vẫn fail |
| **G10** | Scope routing đúng | Phase 1 + routing map | `--scope=deployment` → chạy Phase 2 skip 3a; `--scope=user-guide` → chạy 3a skip 2; `--scope=maintenance` → chỉ chạy 4; `--scope=all` → tất cả |
| **G11** | `runbook.md` là optional output | `_contract.json` outputs.docs | `incident-response-runbook.md` có `required: false`. Nếu `$SCOPE != all` và không cần runbook → Phase 4a có thể skip |
| **G12** | Stakeholder Review 4 Phần | Phase 5a output template | `stakeholder-review.md` có đủ: Phần A (Summary) + Phần B (Deployment Review) + Phần C (Consistency Check) + Phần D (Gap Analysis) + Production Readiness Final |
| **G13** | E_DEPLOY_ENV_MISMATCH manual review | E011 | Phát hiện env vars mismatch giữa deployment-guide và reality → KHÔNG auto-fix; hiển thị bảng so sánh; escalate user review |

### 2.2 NHÓM CS — Cross-skill & Terminal Skill đặc thù

Mở rộng NHÓM D cho pattern terminal skill (không có DEVKIT consumer):

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | `produces_for` đúng là empty `{}` | `jq '.cross_skill_contracts.produces_for' _contract.json` | Giá trị `{}` — terminal skill không produce cho DEVKIT skill nào. Output đi Release/Go-Live (out-of-scope DEVKIT) |
| **CS2** | Sync rate gate từ wf-verify-sync | Phase 1 prereq | Input `verify-sync.md` PHẢI tồn tại; parse `sync_rate >= 0.80`. Nếu file thiếu → E002 STOP (khuyên chạy `/wf-verify-sync` trước) |
| **CS3** | `registry_role: NONE` strictly | `_contract.json` + Phase execution | `fields_owned: []`; không có bất kỳ phase nào ghi registry. Chỉ đọc registry để lấy project info (systems, modules, features) |
| **CS4** | Doc-framework templates là authoritative | Output docs | 4 doc outputs dùng templates trong `.claude/doc-framework/phase6-deployment/` — KHÔNG dùng template trong `templates/` (chỉ internal status/plan/checkpoint) |
| **CS5** | `doc_framework_ref` trỏ đúng contract | `_contract.json.doc_framework_ref` | Giá trị: `.claude/doc-framework/phase6-deployment/_contract.json` — phải tồn tại và định nghĩa 4 doc templates |
| **CS6** | stakeholder-review cuối pipeline | §4b row 228 | `produces_for` = `Release/Go-Live` (không phải DEVKIT skill). Là file anchor cho Go-Live decision |

### 2.3 Constraint đặc biệt

- **Terminal skill** — `consumers_count=0` trong DEVKIT; output đi thẳng Release/Go-Live. Review D1 skip; thay bằng CS1-CS6.
- **registry_role: NONE** — tuyệt đối không ghi registry. E15-E16 skip. Nhưng vẫn phải đọc registry (systems/modules/features) để render docs — review forensic PRE-GATE (E7) quan trọng.
- **LPM là distinguishing feature** — quyết định checkpoint/resume behavior. Review G1, G6, E3 (Context & Checkpoint) phải đồng nhất với LPM formula.
- **4-agent orchestration Phase 5a** — phức tạp nhất DEVKIT: 3 parallel + 1 sequential (reality-checker chờ 3 output). Review F2-F4 + G5 kỹ.
- **2 PARALLEL gates** (Phase 2∥3a, Phase 5a) + 1 SEQUENTIAL merge (Phase 3b cross-file write) — review H2 (atomic write), G4 (cross-file conflict avoidance).
- **Scope flag có impact lớn** — `--scope` quyết định phase skip/run (G10). evals I2 phải cover 4 scope values.
- **Không có LEGACY branch** — E17/E18 skip. Terminal skill sau verify-sync, không cần đọc legacy-decisions.json.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: LPM formula `systems>=5 OR depts>=10 OR reqs>=50 OR features>=40` đúng trong `phase1-prereq.md`
- [ ] G2: Sync rate gate ≥80% check trong Phase 1 (E003 WARNING)
- [ ] G4: Phase 3b + 4 dùng Edit append (không Write overwrite) vào deployment-guide.md
- [ ] G5: Phase 5a có đúng 4 agents (3 parallel + 1 sequential reality-checker)
- [ ] G10: 4 scope values (`all`/`deployment`/`user-guide`/`maintenance`) đều có routing rõ
- [ ] G12: stakeholder-review.md có đủ 4 Phần A/B/C/D + Production Readiness
- [ ] CS1: `produces_for == {}` đúng (terminal skill)
- [ ] CS3: `fields_owned: []` strictly; không phase nào ghi registry
- [ ] CS5: `doc_framework_ref` = `.claude/doc-framework/phase6-deployment/_contract.json` tồn tại
- [ ] Evals cover: happy path small + LPM multi-session + sync rate <80% gate

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-prepare-deployment/SKILL.md) | Overview, Phase Routing Map (lazy-load v2.0) |
| [_contract.json](../../.claude/skills/workflow/wf-prepare-deployment/_contract.json) | Output contract, registry NONE, 10-phase mapping |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-prepare-deployment/procedures/_shared.md) | State vars, Agent prompts, Checkpoint, LPM overrides, Cross-File Write conflict |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-prepare-deployment/procedures/) | 10 phase files (0/1/2/3a/3b/3c/4/4a/5/5a) |
| [templates/](../../.claude/skills/workflow/wf-prepare-deployment/templates/) | 3 internal templates (status, plan, checkpoint) |
| [.claude/doc-framework/phase6-deployment/](../../.claude/doc-framework/phase6-deployment/) | 4 doc output templates (authoritative source) |
| [evals/evals.json](../../.claude/skills/workflow/wf-prepare-deployment/evals/evals.json) | Test cases |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4b rows 226, 228, 256 | Cross-skill: input từ verify-sync, output stakeholder-review |

---

## 5. Ghi chú bảo trì riêng file này

- Khi LPM threshold đổi (vd: `features>=50`) → cập nhật G1 formula.
- Khi thêm doc output mới (vd: `rollback-guide.md`) → cập nhật outputs.docs + C1 + G12.
- Khi Phase 5a đổi agent composition → cập nhật G5 + agents table §SKILL.md.
- Khi scope values thay đổi → cập nhật G10 + evals I2.
- Khi sync rate threshold đổi (vd: 85%) → cập nhật G2 + E003.
- Khi skill có thêm producer (vd: wf-ui-coverage) → cập nhật `contracts.producers_count` + D2.
- File này là **read-only** trong quá trình review — findings đi file report riêng.
