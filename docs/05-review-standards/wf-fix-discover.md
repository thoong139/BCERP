# Tiêu chuẩn rà soát — `wf-fix-discover` v2.5.1

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-fix-discover/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section**. Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Step 1/3 của pipeline `wf-fix-bugs` — Session Init + Discovery (static + runtime 5-Layer) |
| **Entry point** | `procedures/phase0-init.md` (Phase 0 Session Init) |
| **Kiến trúc** | Multi-phase, lazy-load procedures. 12 procedure files + `_shared.md`. Terminology mapping phase0-11 ↔ Phase/Layer/PASS business-level |
| **Execution mode** | Hybrid — deterministic (Phase 0, 1a, Layer 0, Layer 1, Layer 4) + Agent-delegated (Phase 1b user scan) + Runtime Playwright browser (Phase 1c PASS 1-4, chỉ khi `--deep`/`--full-test`) |
| **Strategy routing** | Có — flags `--deep`, `--full-test`, `--no-browser`, `--browser-only`, `--responsive` quyết định chạy static-only vs static+runtime |
| **Đặc trưng** | Owner của `$SESSION_DIR` (Phase 0 creator). Session isolation theo scope (3 variants). Có `--resume`, `--status`, checkpoint.json state restore |
| **Output** | `fix-status.json`, `checkpoint.json`, `issue-registry.json` (initial), `feature-states.json` (optional), `discovery-report.md`, `catalog/{page-slug}.json` (conditional), `e2e-results.json` (conditional), `phase-summary.md`, `evidence/*.png` |
| **Cross-skill** | Spawned by `wf-fix-bugs`; returns to orchestrator; shares SESSION_DIR với `wf-fix-triage`/`wf-fix-execute` |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-fix-discover
  version: 2.5.1
  review_version: 1.0
  path: .claude/skills/workflow/wf-fix-discover/

profile:
  # Kiến trúc
  is_orchestrator: false
  has_procedures: true            # 12 phase files + _shared.md
  has_templates: true             # 6 template files (fix-status, checkpoint, issue-registry, feature-states, catalog-page, discovery-report)
  has_phases: true                # Phase 0 + Phase 1 (Phase 1a/1b/Layer 0-1/Phase 1c PASS 1-4/Layer 4)

  # State & Resume
  has_state_machine: true         # fix-status.json + checkpoint.json
  has_resume: true                # --resume (checkpoint restore)
  has_status: true                # --status
  is_multi_run: true              # SESSION_DIR có 3 variants theo scope (CORE-030)

  # Execution
  spawns_agents: true             # Explore, developer agents (phase 1b user scan — hybrid, NOT fully deterministic), Agent validation (phase 10/11)
  has_strategy_routing: true      # Flag-based routing: --deep → enable runtime, --no-browser → disable, --browser-only → skip static

  # Registry
  writes_registry: false          # fields_owned: [] (NONE)
  registry_role: NONE

contracts:
  producers_count: 2              # wf-preflight (optional), wf-brainstorm (legacy-decisions.json)
  consumers_count: 3              # wf-fix-triage (chính), wf-fix-execute (qua SESSION_DIR), wf-fix-bugs (status display + resume routing)
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | A1-A10 đầy đủ | |
| **B** Workflow Integrity | B1-B8 | B9/B10 áp dụng nhẹ (strategy là flag-based, không scoring formula) |
| **C** Output & Template | C1-C7 | C5 quan trọng — có nhiều conditional outputs (`feature-states.json`, `catalog/*`, `e2e-results.json`) |
| **D** Cross-Skill | D1-D4 | Producer của `fix-status.json`, `issue-registry.json`, `checkpoint.json`, `e2e-results.json` (PASS 3 init) |
| **E** Protocol & CORE | E1-E14; E17/E18 khi LEGACY | E15-E16 SKIP (không writes_registry) |
| **F** Determinism/Agent | F1-F7 | F5 (tech discovery ưu tiên) áp dụng Layer 0 Infrastructure |
| **H** Error Handling | H1-H5 | Phase 1c có aggressive error handling (Playwright failures, network timeouts) |
| **I** Testability | I1-I5 | 15 test cases — cần cover: static only, --deep, --no-browser, --scope system/module, --resume, DOCS_ONLY legacy |
| **J** Idempotency | J1-J4 đầy đủ | J4 CRUCIAL — multi-run isolation bắt buộc (3 SESSION_DIR variants) |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Discovery Architecture (5-Layer + Runtime PASS)

Tiêu chuẩn này **không tổng quát hóa** — chỉ áp dụng cho `wf-fix-discover`.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | 5-Layer discovery định nghĩa đầy đủ | SKILL.md §Terminology Mapping | Có đủ: Phase 1a (Static Preflight) → Phase 1b (User Scan) → Layer 0 (Infrastructure) → Layer 1 (API + Feature Coverage) → Phase 1c (Runtime PASS 1-4) → Layer 4 (Cross-Validation & Gap Analysis) |
| **G2** | Terminology mapping Phase file ↔ business-level | SKILL.md §Terminology Mapping | Bảng 12 rows: `phase0-init` ↔ §Phase 0, `phase11-crossval` ↔ §Layer 4. Không có procedure file nào thiếu ánh xạ |
| **G3** | Runtime PASS 1-4 có conditional guard | `procedures/phase7-pass1-catalog.md` trở đi | Guard đầu mỗi phase: `if flags.deep == false AND flags.full_test == false → SKIP`. `--no-browser` → force `flags.deep=false` (xử lý tại Phase 0 Step 0.1b) |
| **G4** | PASS 3 E2E chỉ chạy khi có Phase 2 feature docs có Luong/State Machine | `phase9-pass3-e2e.md` | Guard kiểm tra `.mc-data/docs/phase2-features/**/*.md` có section "Luong Nguoi Dung" hoặc "State Machine" → mới chạy; nếu không → SKIP và KHÔNG tạo `e2e-results.json` (ownership CORE-007) |
| **G5** | PASS 1 Catalog sinh per-page JSON | `phase7-pass1-catalog.md` + `templates/catalog-page.json` | Mỗi page visited → 1 file `$SESSION_DIR/catalog/{page-slug}.json`. Sau Layer 4 → scan `inconsistent_labels` → sinh `ui_label_inconsistent` issues vào issue-registry |
| **G6** | Layer 1 Feature Coverage classify 8-state | `phase5-feature-coverage.md` | Mỗi feature trong registry được classify theo 8 states (implemented/partial/orphan/missing/...). Output `feature-states.json` conditional trên `registry.features` không rỗng |
| **G7** | Flag conflict resolution tại Phase 0 | `phase0-init.md` Step 0.1b | IF `flags.deep` AND `flags.no_browser` → LOG E023, SET `flags.deep=false`. IF `flags.full_test` → expand `flags.deep=true, flags.responsive=true` |
| **G8** | URL auto-detection fallback chain | `phase0-init.md` Step 0.1a | Fallback đầy đủ 5 bước: (1) `--url`, (2) `.env` NEXT_PUBLIC_URL, (3) PORT, (4) VITE_PORT, (5) package.json scripts, (6) hardcoded `http://localhost:3000`. KHÔNG có trường hợp `$APP_URL` null khi `--no-browser` KHÔNG active |
| **G9** | Auto-login aggressive 4-stage | `phase6-runtime-setup.md` §Step 1c.0a | 4 stages: (1) form-fill credentials, (2) cookie injection, (3) API token header, (4) manual prompt. Mỗi stage có timeout + fallback |
| **G10** | PASS 4 validate multi-dimension | `phase10-pass4-validate.md` | 3 sub-passes: PASS 4a (chart data), PASS 4b (visual), PASS 4c (responsive). Chỉ PASS 4c khi `flags.responsive=true` |

### 2.2 NHÓM CS — Cross-skill contract đặc thù (SESSION_DIR owner)

`wf-fix-discover` là **owner** của `$SESSION_DIR` và `fix-status.json` — các sub-skills khác chỉ UPDATE.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | `$SESSION_DIR` creator — 3 variants theo scope | `00-core.md §4b` + `phase0-init.md` Step 0.3a | Phase 0 Step 0.3a định nghĩa SESSION_DIR Resolution với 3 variants: `scope=all` → ROOT `run-NNN--YYYYMMDD/`, `scope=system` → `sessions/{sys-id}/run-NNN--YYYYMMDD/`, `scope=module` → `sessions/{sys-id}/{mod-id}/run-NNN--YYYYMMDD/`. Tên run incremental sequential |
| **CS2** | `fix-status.json` CREATOR ownership | `_contract.json.outputs.working[0]` | wf-fix-discover là **DUY NHẤT** tạo file (Phase 0 Step 0.5). wf-fix-triage và wf-fix-execute CHỈ UPDATE (merge fields). Template `templates/fix-status.json` là single source |
| **CS3** | `issue-registry.json` initial owner | `_contract.json.outputs.working[3]` | Phase 1 Layer 4 POST-GATE tạo file với schema đầy đủ nhưng `severity`/`fixability`/`domain`/`batch` CHƯA SET (để wf-fix-triage enrich). Không overwrite bởi triage/execute |
| **CS4** | `e2e-results.json` CREATE owner (conditional) | `_contract.json.outputs.working[7]` | wf-fix-discover PASS 3 = **INIT owner** (CREATE khi chạy). wf-fix-execute Phase 5 = **UPDATE owner** (APPEND verify_iterations). Template cross-skill: `../wf-fix-execute/templates/e2e-results.json` |
| **CS5** | `checkpoint.json` resume state restore | `templates/checkpoint.json` | Chứa `partial_state.layer_state`, `deep_scan_state`, `runtime_discovery_state`, `$ORPHAN_UI_ISSUES`. `--resume` PHẢI restore ĐỦ 4 blocks trước khi tiếp tục phase |
| **CS6** | `feature-states.json` input cho wf-fix-triage | `00-core.md §4b` | Conditional output (chỉ khi Layer 1 chạy và `registry.features` không rỗng). wf-fix-triage dùng làm context, KHÔNG block khi thiếu |
| **CS7** | `discovery-report.md` là summary document | `templates/discovery-report.md` | Viết sau Layer 4 complete; là context cho wf-fix-triage và user review severity calibration |
| **CS8** | Evidence folder ownership | `_contract.json.outputs.working[2]` | Phase 0 tạo empty `evidence/`. Phase 1c populate screenshots/console logs. wf-fix-execute Phase 5 re-compare (read-only access, KHÔNG xóa) |

### 2.3 Constraint đặc biệt

- **Playwright tools trong `allowed-tools`** — 20+ MCP Playwright tools. Cần đảm bảo khi `--no-browser` active thì KHÔNG invoke bất kỳ tool Playwright nào (tiêu chuẩn F riêng).
- **Terminology legacy note** — "Layer 2" = "Phase 1c PASS 1", "Layer 3" = "Phase 1c PASS 2". Khi review procedures cũ, phải tham chiếu terminology mapping, tránh nhầm L2/L3 với Layer 0/1/4.
- **Phase filename numbers (phase0-11) KHÔNG KHỚP phase names** — đây là lịch sử codebase. Test I2 (coverage) phải dùng business-level tên, không procedure filename.
- **2 cross-skill templates được REFERENCE (không own)** — `e2e-results.json` (cross-skill từ wf-fix-execute), `session-log.template.json` (từ doc-framework). Validator phải resolve đúng relative path.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: Đủ 5 layers + 4 runtime PASSes trong terminology mapping
- [ ] G3: Mỗi runtime phase có guard `flags.deep || flags.full_test`
- [ ] G4: PASS 3 KHÔNG CREATE `e2e-results.json` khi skip (ownership CORE-007)
- [ ] G7: Flag conflict `--deep + --no-browser` log E023 + auto-disable deep
- [ ] CS1: 3 SESSION_DIR variants documented chính xác trong phase0-init Step 0.3a
- [ ] CS4: `e2e-results.json` template là cross-skill (reference từ wf-fix-execute)
- [ ] CS5: checkpoint.json restore đủ 4 state blocks cho `--resume`
- [ ] evals ≥ 3 cases cover: static-only, --deep, --no-browser, scope=system, scope=module, --resume

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-fix-discover/SKILL.md) | Overview + Terminology Mapping + Phase 0 + 5-Layer discovery |
| [_contract.json](../../.claude/skills/workflow/wf-fix-discover/_contract.json) | Outputs + cross-skill contracts |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-fix-discover/procedures/_shared.md) | Token budget, test isolation, severity mapping, route resolution |
| [procedures/phase0-init.md](../../.claude/skills/workflow/wf-fix-discover/procedures/phase0-init.md) | Session init (fix-status.json, checkpoint.json, SESSION_DIR resolution) |
| [procedures/phase11-crossval.md](../../.claude/skills/workflow/wf-fix-discover/procedures/phase11-crossval.md) | Layer 4 Gap Analysis (owner của issue-registry.json) |
| [templates/](../../.claude/skills/workflow/wf-fix-discover/templates/) | 6 template files |
| [evals/evals.json](../../.claude/skills/workflow/wf-fix-discover/evals/evals.json) | 15 test cases |
| [wf-fix-bugs.md](./wf-fix-bugs.md) | Orchestrator spawning skill này |
| [wf-fix-triage.md](./wf-fix-triage.md) | Downstream consumer |
| [`_template-common.md`](./_template-common.md) | Tiêu chuẩn chung |

---

## 5. Ghi chú bảo trì riêng file này

- Khi thêm layer/PASS mới → cập nhật G1, G2 (terminology mapping), evals I2.
- Khi thêm runtime flag (ví dụ: `--mobile-only`) → thêm vào G3, G7 flag conflict matrix.
- Khi đổi SESSION_DIR schema (thêm scope variant 4) → cập nhật CS1 + CS3 `sessions/{path}` structure + 00-core.md §4b.
- Khi Playwright MCP API thay đổi → kiểm tra `allowed-tools` còn đồng bộ với phase6/7/8/9 usage.
- File này là **read-only** trong quá trình review — findings ghi vào `reports/`.
