# Tiêu chuẩn rà soát — `wf-verify-sync` v2.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-verify-sync/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Verify REQ-ID traceability giữa requirements ↔ code; safe-update `impl_status` trong registry |
| **Entry point** | `procedures/phase0-init.md` |
| **Kiến trúc** | Lazy-load procedures; 7 phase files (0, 1, 2, 3, 4, 5, 6) + `_shared.md` + scripts helper |
| **Execution mode** | Scan-based — Phase 1 PARALLEL (Group A collect REQ-IDs + Group B scan code); Phase 2-6 SEQUENTIAL |
| **Đặc trưng** | `--status`, `--resume`, `--fix` (orphan REQ-ID comment); Phase 3 UI coverage conditional; Phase 5 auto-correction loop 3 iter |
| **Output primary** | `verify-sync.md` (single doc output) + registry safe-update |
| **Output working** | 6 working files (status, checkpoint, history, ui-coverage, ui-snapshot, phase-summary) |
| **Cross-skill** | 4 producers (consumes: wf-implement-feature, wf-preflight, wf-fix-bugs, wf-manage-change), 1 consumer (`wf-prepare-deployment`) |
| **Registry role** | **SAFE-UPDATE** — chỉ `impl_status` per REQ-ID, KHÔNG downgrade từ `"done"` (CORE-008) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-verify-sync
  version: 2.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-verify-sync/

profile:
  is_orchestrator: false
  has_procedures: true
  has_templates: true
  has_phases: true                # 7 phase files

  has_state_machine: true         # verify-sync-status.json + checkpoint.json
  has_resume: true                # --resume
  has_status: true                # --status
  is_multi_run: false             # ghi trực tiếp vào .mc-data/work/wf-verify-sync/ root

  spawns_agents: false            # Scan-based — Phase 1 Grep trực tiếp, không spawn agent
  has_strategy_routing: false

  writes_registry: true           # SAFE-UPDATE impl_status (CORE-008)
  registry_role: SAFE-UPDATE      # chỉ impl_status, KHÔNG downgrade "done"

contracts:
  producers_count: 4              # wf-implement-feature, wf-preflight, wf-fix-bugs, wf-manage-change
  consumers_count: 1              # wf-prepare-deployment (Release/Go-Live)
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ Toàn bộ A1-A10 | |
| **B** Workflow Integrity | ✅ B1-B8 | B5 (conditional phase) cho Phase 3 UI coverage + Phase 4 `--fix`; B9-B10 SKIP |
| **C** Output & Template | ✅ C1-C7 | 1 primary doc (`verify-sync.md`) + 6 working; `verify-sync.md` `template: null` — áp dụng C6 (schema = Output Report section trong SKILL.md) |
| **D** Cross-Skill | ✅ D1-D4 | 4 producers, 1 consumer |
| **E** Protocol & CORE | ✅ E1-E10, E13-E16 | E4/E11 SKIP (`spawns_agents=false`); E12 SKIP (`is_multi_run=false`); **E15-E16 BẮT BUỘC** (writes_registry + SAFE-UPDATE); E17/E18 N/A (không có legacy branch) |
| **F** Determinism/Agent | ✅ F1, F5-F6 | F2-F4 SKIP (không spawn agent); F7 SKIP |
| **H** Error Handling | ✅ H1-H5 | 13 error codes (E001-E013 + W001) |
| **I** Testability | ✅ I1-I5 | Cần cover scope × `--fix` × `--resume` × UI-coverage conditional |
| **J** Idempotency | ✅ J1-J3 | J4 SKIP (không multi-run) |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — SAFE-UPDATE Registry & Traceability

Tiêu chuẩn này **không tổng quát hóa** được — đặc thù safe-update contract của verify-sync.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | SAFE-UPDATE chỉ động đến `impl_status` | Đọc `_shared.md §Registry Safe-Write Rule` + Phase 6 | Phase 6 chỉ modify `requirements[].impl_status`. KHÔNG modify bất kỳ field khác (description, priority, notes…) |
| **G2** | **CORE-008: KHÔNG downgrade `"done"`** | Grep Phase 6 + `_contract.json.registry_scope.notes` | Logic tường minh: nếu code scan không tìm thấy REQ-ID đã `done` → WARN W001 + hỏi user, KHÔNG tự set về `not_started`/`in_progress` |
| **G3** | W001 warning format đầy đủ | Output Report template (Warnings table) | W001 entries có: `REQ-ID`, `classification` (`format_mismatch`/`code_refactored`/`genuine_missing`), `candidate_file_or_fix`, `action` (không downgrade) |
| **G4** | impl_status states valid (CORE-010) | Phase 6 safe-update | Chỉ set 4 giá trị: `not_started` / `in_progress` / `done` / `skipped`. Không tự sinh giá trị khác |
| **G5** | Sync Rate vs Coverage Rate tách biệt | Phase 2 `_shared.md` + Output Report | Sync Rate chỉ đếm `done`; Coverage Rate đếm `done + in_progress`; `skipped` không tính vào sync rate (ghi rõ trong report) |
| **G6** | Phase 5 Auto-correction max 3 iter | `phase5-crossval.md` | Cross-validation 10 checks; fail → retry ≤3; vẫn fail → escalate (không tự cheat số liệu) |
| **G7** | Phase 4 `--fix` không sửa semantic | `phase4-fix.md` | `--fix` chỉ auto-add REQ-ID comment vào orphan code files (header). KHÔNG tự gán REQ-ID không chắc chắn (ambiguous → escalate) |
| **G8** | Atomic registry write | Phase 6 step sequence | Dùng pattern `tmp file + mv` hoặc equivalent; validate `jq -e '.requirements | length > 0'` sau ghi; rollback nếu JSON invalid (E006) |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | `verify-sync.md` xuất phát `phase6-report.md` | `_contract.json.outputs.docs` + SKILL.md Output Files | Primary output `.mc-data/docs/_meta/verify-sync.md`, `template: null` (schema = Output Report section trong SKILL.md, C6 áp dụng). File Phase 6 sinh |
| **CS2** | Registry update là gate cho `wf-prepare-deployment` | `00-core.md §4b` | `produces_for.wf-prepare-deployment` gồm `verify-sync.md` + `req-registry.json` (impl_status đã safe-update) |
| **CS3** | UI coverage Phase 3 là conditional output | `_contract.json.outputs.working[]` có condition | `ui-coverage-report.md` có `condition: "interface_type != api-only"` và `required: false`; phase file có guard early-return cho api-only |
| **CS4** | Input `wf-fix-bugs` optional context | `_contract.json.consumes_from.wf-fix-bugs` | `fix-report-[date].md` là optional context (không required); verify-sync chạy độc lập được |
| **CS5** | Input `wf-preflight` optional context | `_contract.json.consumes_from.wf-preflight` | `preflight-report.md` optional — verify-sync không block nếu chưa có preflight |
| **CS6** | Utility scripts `scripts/` tự chứa | `scripts/find-orphans.sh`, `scripts/scan-reqs.sh` | Scripts có comment tiếng Việt giải thích + input/output rõ; được gọi từ Phase 1 scan (không phải inline bash phức tạp) |

### 2.3 Constraint đặc biệt

- **`writes_registry: true` với `registry_role: SAFE-UPDATE`** — kích hoạt NHÓM E15-E16 của common template. Đây là skill duy nhất (cùng `wf-implement-feature`, `wf-fix-execute`) được động vào `impl_status`, nhưng chỉ mình verify-sync có CORE-008 non-downgrade rule.
- **`verify-sync.md` `template: null`** — schema được định nghĩa trong SKILL.md §Output Report (table layout). Áp dụng C6: `notes` trong `_contract.json` PHẢI refer tới section này làm schema reference cho POST-GATE T3-T4.
- **W001 là warning không block report generation** — verify-sync vẫn PASS POST-GATE dù có W001. Warning chỉ chuyển thành action (không downgrade) và chờ user quyết định sau.
- **Không spawn agent** — toàn bộ scan và phân tích chạy trong main context bằng Grep/Read/Bash. E4/E11 không áp dụng.
- **Không có LEGACY_MODE branch** riêng — verify-sync chạy giống nhau mọi project type (dựa trên registry + code annotations).

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Phase 6 chỉ modify `impl_status`, không field khác
- [ ] G2: Grep Phase 6 không có logic `set impl_status = "not_started"` cho REQ có `done` trước đó
- [ ] G4: impl_status values trong code chỉ dùng 4 enum (CORE-010)
- [ ] G5: Sync Rate ≠ Coverage Rate — 2 công thức khác nhau trong Phase 2
- [ ] G8: Phase 6 có atomic write + post-write validation
- [ ] CS1: `verify-sync.md` có `template: null` + schema ref section tồn tại trong SKILL.md
- [ ] CS2: `produces_for.wf-prepare-deployment` đủ 3 path (verify-sync.md + registry + ui-coverage optional)

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-verify-sync/SKILL.md) | Overview, Output Report template, Execution Strategy |
| [_contract.json](../../.claude/skills/workflow/wf-verify-sync/_contract.json) | Output contract, cross-skill, registry_scope |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-verify-sync/procedures/_shared.md) | State vars, Safe-Write Rule, Fix Rules, Checkpoint |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-verify-sync/procedures/) | 7 phase files (0-6) |
| [scripts/](../../.claude/skills/workflow/wf-verify-sync/scripts/) | `find-orphans.sh`, `scan-reqs.sh` |
| [templates/](../../.claude/skills/workflow/wf-verify-sync/templates/) | 3 templates (status/checkpoint/ui-coverage) |
| [evals/evals.json](../../.claude/skills/workflow/wf-verify-sync/evals/evals.json) | Test cases |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE rules — **CORE-008 (SAFE-UPDATE không downgrade)**, CORE-006, CORE-010, CORE-011/012/028/031 |
| [`.claude/skills/protocols/`](../../.claude/skills/protocols/) | Protocol 1/2/6/7/8/9/10/11/14/15/19 |

---

## 5. Ghi chú bảo trì riêng file này

- Khi skill nâng lên **version mới** → update `skill.version` + review G1-G8 (nhất là W001 handling và safe-update rule).
- Khi **CORE-008 có exception mới** (ví dụ: downgrade allowed trong một số edge case) → cập nhật G2 + E16 mapping.
- Khi **Output Report schema** trong SKILL.md đổi → cập nhật CS1 + C6 check.
- Khi thêm producer/consumer (e.g., `wf-fix-execute` producer mới) → cập nhật `producers_count` + NHÓM D + CS.
- Khi thêm registry field mới vào scope (hiện chỉ `impl_status`) → đọc kỹ CORE-006 §4a, cập nhật `fields_owned` và G1.
- File này là **read-only** trong quá trình review — findings ghi ra `reports/YYYY-MM-DD-wf-verify-sync.md`.
