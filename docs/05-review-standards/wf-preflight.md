# Tiêu chuẩn rà soát — `wf-preflight` v2.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-preflight/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Health check toàn diện trước khi deploy/release — verdict PASS / WARN / FAIL với score + action list |
| **Entry point** | `procedures/phase1-setup.md` (Phase 0 routing inline trong SKILL.md) |
| **Kiến trúc** | Lazy-load procedures; 9 phase files (1, 2, 3, 4, 5, 5a, 5b, 6, 7) + `_shared.md` |
| **Execution mode** | Scan-based (DETERMINISTIC) — Phase 2+3 và Phase 4+5 chạy PARALLEL; Phase 5a conditional spawn `qa-lead` |
| **Scope routing** | `--scope=all/system/module/feature` + `--name=<id>` — filter 4 cấp |
| **Đặc trưng** | `--fix` (auto-fix limited set), `--run-tests`, `--status`, `--resume`; checkpoint 65/80/90% |
| **Output** | 4 files: `preflight-report.md`, `preflight-status.json`, `preflight-history.md`, `checkpoint.json` |
| **Verdict taxonomy** | PASS / WARN / FAIL với score numeric |
| **Cross-skill** | 2 producers, 2 consumers (`wf-fix-bugs`, `wf-verify-sync`) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-preflight
  version: 2.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-preflight/

profile:
  is_orchestrator: false          # có procedures riêng, self-contained
  has_procedures: true
  has_templates: true
  has_phases: true                # 9 phase files

  has_state_machine: true         # preflight-status.json + checkpoint.json
  has_resume: true                # --resume
  has_status: true                # --status
  is_multi_run: false             # ghi trực tiếp vào .mc-data/work/wf-preflight/ root

  spawns_agents: true             # chỉ Phase 5a.5 spawn qa-lead (conditional, nhỏ)
  has_strategy_routing: false     # không multi-strategy; scope filter không tính là strategy

  writes_registry: false          # fields_owned: []
  registry_role: NONE             # --fix chỉ sửa JSON syntax, không semantic fields

contracts:
  producers_count: 2              # wf-implement-feature, wf-manage-change
  consumers_count: 2              # wf-fix-bugs, wf-verify-sync
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ Toàn bộ A1-A10 | |
| **B** Workflow Integrity | ✅ B1-B8 | B9-B10 SKIP (không có strategy routing) |
| **C** Output & Template | ✅ C1-C7 | 4 output đều có template |
| **D** Cross-Skill | ✅ D1-D4 | 2 consumers — kiểm 2 path trong `produces_for` |
| **E** Protocol & CORE | ✅ E1-E11, E13-E14 | E8 chỉ áp dụng cho `--fix` mode; E12 SKIP (`is_multi_run=false`); E15-E16 SKIP (`writes_registry=false`); E17 N/A (Phase 0 chỉ detect LEGACY_MODE để log, không branch); E18 N/A |
| **F** Determinism/Agent | ✅ F1-F4 | F5-F7 SKIP — Phase 5 là code compile check (chạy tsc/eslint/go build), không phải discovery; không có strategy scoring |
| **H** Error Handling | ✅ H1-H5 | 13 error codes (E001-E013) |
| **I** Testability | ✅ I1-I5 | Phải cover 3 scope × verdict matrix |
| **J** Idempotency | ✅ J1-J3 | J4 SKIP (không multi-run) |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Verdict & Scoring (PASS/WARN/FAIL taxonomy)

Tiêu chuẩn này **không tổng quát hóa** được sang skill khác — chỉ áp dụng cho `wf-preflight`.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | Verdict rõ 3 trạng thái | `phase7-report.md` | Định nghĩa rõ 3 verdict: `PASS` (>=90%), `WARN` (60-89%), `FAIL` (<60%). Ngưỡng công khai trong `_shared.md §Scoring Formulas` |
| **G2** | Scoring deterministic, reproducible | `_shared.md §Scoring Formulas` | Formula công khai với weights per category (registry 20% + docs 20% + code-sync 30% + quality 20% + tests 10%…). Cùng input → cùng score (F7) |
| **G3** | Scope filter 4 cấp hoạt động đúng | `phase1-setup.md` Scope Resolution | `--scope={all,system,module,feature}` có mapping rõ → `$SCOPE_FILTER` (glob pattern hoặc ID list). `--name` validate tồn tại trong registry (E003) |
| **G4** | `--fix` limited set — KHÔNG sửa semantic fields | Fix Rules table trong SKILL.md + `phase6-autofix.md` | `--fix` chỉ áp dụng cho: `registry_json_invalid`, `orphan_code_file`, `id_format_error`. KHÔNG tự sửa: `test_failure`, `type_error`, `duplicate_id`, `stale_impl_status` (luôn escalate) |
| **G5** | `--fix` có Phase 6.5 Re-score | `phase6-autofix.md` cuối phase | Sau fix → re-scan các items đã fix → re-calculate score → update verdict. Tránh false PASS sau fix |
| **G6** | Test runner guard + timeout | `phase5a-tests.md` | Guard `test -d src || test -d apps`; nếu không có `node/npm/go` → skip Phase 5 (E005); timeout 5 phút (E006) |
| **G7** | Parallel Group A/B đúng dependency | SKILL.md §Execution Strategy | Group A (Phase 2+3) chạy sau Phase 1 done; Group B (Phase 4+5) chạy sau Group A validated; Phase 5a/5b/6/7 SEQUENTIAL |
| **G8** | Phase 5b Cross-Validation kiểm consistency | `phase5b-crossval.md` | Verify inter-phase consistency: sync_rate (Phase 4) không mâu thuẫn registry done count (Phase 2); quality errors (Phase 5) không thiếu REQ-ID orphans (Phase 4). Có auto-correction max 3 iterations |
| **G9** | Issue format kèm action | `preflight-report.md` template | Mọi issue trong report có: `severity`, `location`, `suggested_fix`, `action_command` (e.g., `/wf-fix-bugs REQ-XXX`) |

### 2.2 NHÓM CS — Cross-skill contract đặc thù

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | `preflight-report.md` là single consumer gate | `_contract.json.produces_for` + `00-core.md §4b` | Cả `wf-fix-bugs` (Phase 1a inline input) và `wf-verify-sync` (optional context) đều đọc `preflight-report.md`. Path đồng bộ cả 2 nơi |
| **CS2** | KHÔNG ghi registry — contract rõ ràng | `_contract.json.registry_scope.fields_owned` | `fields_owned: []`, `notes` ghi rõ "Preflight chỉ đọc registry"; Phase 6 `--fix` chỉ sửa JSON syntax (không semantic fields) |
| **CS3** | Input `wf-manage-change` optional | `_contract.json.consumes_from.wf-manage-change` | Path `change-report.md` có condition hoặc không require (preflight chạy độc lập được, không cần chờ change management) |
| **CS4** | Phase 5a spawn `qa-lead` có bounded output | `phase5a-tests.md` agent prompt | Prompt có INPUT/OUTPUT/return format. Output ~300-500 từ, không spam context (Protocol 6.1) |

### 2.3 Constraint đặc biệt

- **Scan-based, KHÔNG execution plan** — Protocol 9 (PLN) không áp dụng (workload cố định, dự đoán được). Ghi rõ note trong SKILL.md §Protocols.
- **Không ghi registry** (`fields_owned: []`). Bỏ qua E15-E16 của common template.
- **`--fix` là CDG action** — Phase 6 modify files có thể gây regression (E010 rollback). Phải có user confirmation hoặc pre-flag warning khi `--fix` kết hợp với scope hẹp. Áp dụng E8 (Protocol 16).
- **4 output đều required=true** trong `_contract.json` — mỗi phase chạy phải tạo đủ file.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Ngưỡng PASS/WARN/FAIL rõ (3 mức) trong `_shared.md`
- [ ] G2: Formula scoring có weights công khai + reproducible
- [ ] G4: `--fix` không đụng vào `impl_status`, `test_failure`, `type_error`, `duplicate_id`
- [ ] G5: Phase 6.5 Re-score tồn tại khi `--fix` đã chạy
- [ ] G7: Dependency Graph Parallel Group A/B đúng (Phase 1 → A → B → 5a → 5b → 6 → 7)
- [ ] CS1: `preflight-report.md` xuất hiện 2 entries `produces_for` trong `00-core.md §4b`
- [ ] CS2: `registry_scope.fields_owned == []`

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-preflight/SKILL.md) | Overview, routing, Execution Strategy, Fix Rules |
| [_contract.json](../../.claude/skills/workflow/wf-preflight/_contract.json) | Output contract, cross-skill contracts |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-preflight/procedures/_shared.md) | State vars, Scope Resolution, Scoring Formulas, Fix Rules |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-preflight/procedures/) | 9 phase files (1, 2, 3, 4, 5, 5a, 5b, 6, 7) |
| [templates/](../../.claude/skills/workflow/wf-preflight/templates/) | 4 templates (status/report/history/checkpoint) |
| [evals/evals.json](../../.claude/skills/workflow/wf-preflight/evals/evals.json) | Test cases (200 dòng) |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE rules — §4b Cross-Skill, CORE-011/012/021/026/027/028/031 |
| [`.claude/skills/protocols/`](../../.claude/skills/protocols/) | Protocol 1/2/3/6/7/8/10/19 |

---

## 5. Ghi chú bảo trì riêng file này

- Khi skill nâng lên **version mới** → update `skill.version` ở §1 + review G1-G9 (nhất là scoring thresholds).
- Khi **Fix Rules** table trong SKILL.md đổi (thêm/bớt error type) → cập nhật G4.
- Khi `--fix` mở rộng sang semantic fields → vi phạm G4/CS2, cần cập nhật `registry_role` profile.
- Khi thêm/xóa consumer của `preflight-report.md` → cập nhật `consumers_count` + CS1 + NHÓM D của common.
- Khi parallel group layout đổi → cập nhật G7 và check lại F1 (phase deterministic không spawn agent ngoài Phase 5a).
- File này là **read-only** trong quá trình review — findings ghi ra `reports/YYYY-MM-DD-wf-preflight.md`.
