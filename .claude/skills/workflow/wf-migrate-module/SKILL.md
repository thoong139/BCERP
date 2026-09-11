---
name: wf-migrate-module
version: 1.1.0
last_updated: 2026-05-11
description: |
  Orchestrator di chuyen chuc nang tu he thong cu sang he thong moi EUREKA.
  Tu scan docs cua module cu → phan tich gap → seed registry → define features →
  design → plan modules → implement code → bao cao tong ket.
  Dam bao day du chuc nang nhu he thong cu, tuong thich voi kien truc he thong moi.

  v1.1 UPGRADES:
  - GitNexus/Serena CI code intelligence trong Phase 1 gap analysis
  - Automated feature parity check (so sanh output cu vs moi cho feature Keep)
  - Sub-skill interface pre-flight check (verify contract truoc khi goi sub-skill)
  - Rollback mechanism voi registry snapshots + per-task change tracking
  - --auto-approve flag de skip CDG gates (cho automated pipeline)

  TRIGGER khi:
  - User muon chuyen 1 module/chuc nang tu he thong cu sang EUREKA
  - User da scan module cu bang /wf-scan-target va co session ID
  - User goi truc tiep: /wf-migrate-module --from-scan=<session-id> --to-system=<SYS-XXX> --to-module=<MOD-XXX>
  - Keywords: "chuyen chuc nang", "migrate module", "dua tinh nang tu he thong cu sang",
    "copy feature tu old system", "chuyen module cu sang ERP moi"

  KHONG trigger khi:
  - Chua scan module cu (chua chay /wf-scan-target)
  - Muon sua tinh nang DA CO trong EUREKA → dung /wf-manage-change
  - Muon them feature moi tu dau (khong tu he thong cu) → dung /wf-add-scope hoac /feature-addition
  - Fix bug → dung /wf-fix-bugs
  - Scan toan bo du an cu → dung /wf-legacy-scan

argument-hint: "--from-scan=<session-id> --to-system=<SYS-ID> --to-module=<MOD-ID> [mo-ta-yeu-cau] [--auto-approve] [--skip-phase=<phase>] [--resume] [--status]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion, TodoWrite
---

# /wf-migrate-module: $ARGUMENTS

## Overview

| Muc | Noi dung |
|-----|----------|
| **Muc dich** | Di chuyen chuc nang tu he thong cu sang EUREKA — tu scan docs den code hoat dong, day du, tuong thich |
| **Prerequisites** | `/wf-scan-target` da hoan thanh + `req-registry.json` ton tai |
| **Duration** | Multi-session (30-120 phut, phu thuoc do phuc tap module) |
| **Phases** | 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 (8 phase files, lazy-loaded) |
| **Input** | Scan docs (`target-map.json`, `feature-inventory.md`, `module-map.md`) + yeu cau nguoi dung + registry |
| **Output** | Code hoat dong + registry updated + feature specs + design docs + task plan + bao cao tong ket |

### Workflow Position

```
[Standalone orchestrator — khong thuoc main DEVKIT pipeline]

/wf-scan-target (ban tu chay) → /wf-migrate-module ← YOU ARE HERE
                                      ↓
                            /wf-add-scope → /wf-define-features → /wf-design
                            → /wf-plan-modules → /wf-implement-feature
                                      ↓
                            Bao cao tong ket → handoff dev
```

---

## Arguments

| Argument | Mo ta | Required | Default |
|----------|-------|----------|---------|
| `--from-scan=<session-id>` | Session ID cua `wf-scan-target` da hoan thanh (VD: `2026-05-11-crm-module`) | **BAT BUOC** | — |
| `--to-system=<SYS-ID>` | System dich trong EUREKA (VD: `SYS-BACKEND`). Lay ID tu registry hoac `/status`. | **BAT BUOC** | — |
| `--to-module=<MOD-ID>` | Module dich trong EUREKA. Neu chua ton tai → skill se tao moi. | **BAT BUOC** | — |
| `[mo-ta-yeu-cau]` | Mo ta bang ngon ngu tu nhien — "toi muon chuyen chuc nang X tu he thong cu sang module Y cua EUREKA" | **BAT BUOC** | — |
| `--auto-approve` | **NEW v1.1** — Tu dong phe duyet tat ca CDG (strategy, entity mapping, scope), skip hoi user. Dung cho automated pipeline. | Optional | `false` |
| `--dry-run` | **NEW v1.1** — Chay Phase 0 + 1 (gap analysis + strategy) roi STOP. Hien thi preview: strategy matrix, entity mapping, danh sach sub-skill se duoc goi, scope uoc tinh. KHONG ghi registry, KHONG goi sub-skill. | Optional | `false` |
| `--auto-rollback` | **NEW v1.1** — Tu dong revert registry + code khi E017 CRITICAL (>5 parity FAIL). Khong hoi user. | Optional | `false` |
| `--resume-task=<n>` | **NEW v1.1** — Resume Phase 6 tu task so n (0-indexed). Bo qua cac task da hoan thanh, bat dau tu task n. | Optional | — |
| `--skip-phase=<phase>` | Bo qua phase cu the. Dung nhieu lan: `--skip-phase=design --skip-phase=plan-modules`. Phase co the skip: `design`, `plan-modules`, `implement`. | Optional | _(khong skip)_ |
| `--resume` | Tiep tuc session in_progress/paused gan nhat | Optional | — |
| `--status` | Hien thi trang thai cac sessions gan nhat → STOP | Optional | — |

**Vi du:**

```bash
/wf-migrate-module --from-scan=2026-05-11-crm-customer360 --to-system=SYS-BACKEND --to-module=MOD-CRM "Chuyen chuc nang Customer 360 tu he thong cu sang module CRM cua EUREKA, giu nguyen logic tinh toan va data model"

/wf-migrate-module --from-scan=2026-05-10-inventory --to-system=SYS-BACKEND --to-module=MOD-WMS --skip-phase=design "Module WMS da co design san, chi can define features + plan + implement"

/wf-migrate-module --from-scan=2026-05-11-crm-legacy --to-system=SYS-BACKEND --to-module=MOD-CRM --auto-approve "Chuyen toan bo CRM, auto duyet tat ca CDG"

/wf-migrate-module --from-scan=2026-05-11-crm-legacy --to-system=SYS-BACKEND --to-module=MOD-CRM --dry-run "Xem truoc strategy truoc khi chay that"

/wf-migrate-module --from-scan=2026-05-11-crm-legacy --to-system=SYS-BACKEND --to-module=MOD-CRM --auto-rollback "Chuyen CRM, tu dong rollback neu parity fail CRITICAL"

/wf-migrate-module --resume-task=5

/wf-migrate-module --status
/wf-migrate-module --resume
```

---

## Protocols & Strategy

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 5 (Registry Safe-Write), Protocol 10 (POST-GATE Schema Validation), Protocol 14 (Phase Summary), Protocol 15 (Execution Trace), Protocol 16 (CDG — Phase 1 strategy quyet dinh), Protocol 18 (Session Isolation), Protocol 19 (Template Usage Rule), Protocol 20 (Code Intelligence).

### Priority Ladder (BAT BUOC)

1. **Do chinh xac, chat luong, tinh nhat quan, bao mat**
2. **Toc do va song song hoa** — chi sau khi muc 1 duoc bao ve

### Execution Strategy

| Phase | Mode | Agent | Ghi chu |
|-------|------|-------|---------|
| 0 — Intake | SEQUENTIAL | 0 | Parse args + CI detect + sub-skill pre-flight |
| 1 — Gap Analysis | **HYBRID** | 2 (business-analyst + architect) | CI code intelligence + CDG (auto-approve skip) |
| 2 — Add Scope | SEQUENTIAL | 0 | Goi `/wf-add-scope --from-scan` + registry snapshot |
| 3 — Define Features | SEQUENTIAL | 0 | Goi `/wf-define-features --from-scan` |
| 4 — Design | SEQUENTIAL | 0 | Goi `/wf-design` |
| 5 — Plan Modules | SEQUENTIAL | 0 | Goi `/wf-plan-modules` |
| 6 — Implement | SEQUENTIAL per task | 0 | Goi `/wf-implement-feature` + automated parity + per-task snapshot |
| 7 — Report | SEQUENTIAL | 0 | Tong ket + rollback guide + phase-summary |

### Template Usage Rule (CORE-031)

> **BAT BUOC:** Moi file co Template PHAI duoc tao bang pattern:
> 1. **READ** template file tu `templates/`
> 2. **POPULATE** — thay the placeholders bang gia tri thuc te
> 3. **WRITE** output file den destination path
>
> **NEU SKIP buoc READ template → STOP skill.**
>
> Ap dung cho:
> - **Internal templates**: `templates/migrate-status.json`, `templates/gap-analysis.md`, `templates/strategy-matrix.md`, `templates/entity-mapping.md`, `templates/migrate-report.md`, `templates/phase-summary.md`, `templates/checkpoint.json`, `templates/index.json`, `templates/parity-check.md`, `templates/rollback-guide.md`

### Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `scan_session_not_found` | Hoi user xac nhan lai session ID | User khong tim thay |
| `registry_conflict` | Doc lai registry, de xuat ten module khac | Van conflict |
| `sub_skill_fail` | Retry sub-skill 1 lan, log warning | Van fail |
| `cdg_user_no_response` | Dung, cho user phan hoi | — |
| `feature_parity_fail` | Log chi tiet sai lech, hoi user chap nhan khong | User khong chap nhan |
| `context_overflow` (>80%) | Luu checkpoint → STOP, bao user `--resume` | — |
| `preflight_fail` (E016) | Hien thi sub-skill contract gap, hoi user | User khong fix |
| `parity_critical` (E017) | Trigger rollback protocol, khoi phuc snapshot | Rollback fail |
| `snapshot_write_fail` (E018) | Retry 1 lan voi timestamp moi, log warning | Van fail |
| `rollback_revert_fail` (E020) | Thu revert tung file thu cong, ghi log chi tiet | Khong the revert >50% files |
| `resume_task_invalid` (E021) | Hien thi danh sach task, hoi user nhap lai | User khong xac dinh duoc |

---

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools duoc auto-detect, khong hoi user. Lock held → fallback Grep/Glob ngay.

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → check per-tool TTL. Read `.mc-data/work/_meta/code-intelligence.json` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh`. SEVERE (>20 behind) → warning. | Freshness status set |

### CI-ROUTE: Migration Stages

| Stage | CI Task | Primary Tool | Fallback |
|-------|---------|-------------|----------|
| Phase 1 (Gap Analysis) | `understand_target` | **GitNexus** `query` (target module) + **Serena** `find_symbol` | Grep + Read |
| Phase 1 (Gap Analysis) | `impact_check` | **GitNexus** `impact` (system dich) | Grep |
| Phase 6 (Implement) | `pre_edit_impact` | **GitNexus** `impact` + **Serena** `find_referencing_symbols` | Grep |
| Phase 6 (Implement) | `detect_changes` | **GitNexus** `detect_changes` | `git diff` |

---

## Phase 0: Entry & Routing

**PRE-GATE:**
```bash
test -f .mc-data/docs/_meta/req-registry.json
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json
```
Neu fail → STOP: *"Du an chua co registry. Chay `/wf-brainstorm` truoc."*

```
STEP 1: Handle --status / --resume flags
  IF $ARGUMENTS chua "--status":
    → Read procedures/phase0-intake.md §Flag Handlers §--status → STOP sau khi hien thi

  IF $ARGUMENTS chua "--resume":
    → Read procedures/phase0-intake.md §Flag Handlers §--resume
    → Route theo procedures/_shared.md §Resume Logic & Routing → STOP sau khi route

STEP 2: Normal entry (khong flag)
  → Read procedures/phase0-intake.md → execute Phase 0 → return
  → Continue theo Phase 1-7 Routing Map duoi
```

| Step | Action |
|------|--------|
| 1 | PRE-GATE: kiem tra registry ton tai va co noi dung |
| 2 | Xu ly flags --status / --resume neu co |
| 3 | Phase 0: session init + parse args + load scan docs + validate input |
| 4 | Phase 1-7: gap analysis → add scope → define features → design → plan → implement → report |

---

## Phase 1-7 Routing Map (lazy-loaded)

> SKILL.md routing block KHONG chua execution steps. Toan bo logic chi tiet duoc lazy-load
> qua cac phase files rieng. Read MOI phase file CHI KHI toi phase tuong ung de giam context load.

| Phase | Procedure file | Dieu kien | Muc dich |
|-------|---------------|-----------|----------|
| **1** | `procedures/phase1-gap-analysis.md` | Always | Phan tich gap cu vs moi + strategy per feature + CDG user duyet |
| **2** | `procedures/phase2-add-scope.md` | Always | Goi `/wf-add-scope --from-scan` → seed registry |
| **3** | `procedures/phase3-define-features.md` | Always | Goi `/wf-define-features --from-scan` → feature specs |
| **4** | `procedures/phase4-design.md` | `design` NOT trong `--skip-phase` | Goi `/wf-design` → thiet ke kien truc |
| **5** | `procedures/phase5-plan-modules.md` | `plan-modules` NOT trong `--skip-phase` | Goi `/wf-plan-modules` → task plan |
| **6** | `procedures/phase6-implement.md` | `implement` NOT trong `--skip-phase` | Goi `/wf-implement-feature` → code |
| **7** | `procedures/phase7-report.md` | Always | Tong ket + migrate-report + phase-summary |

**Routing flow:**

```
SKILL.md Phase 0 Entry → Read procedures/phase0-intake.md → execute → return
   ↓
Read procedures/phase1-gap-analysis.md → execute →
   IF $DRY_RUN: Dry-Run Preview → STOP (khong goi sub-skill, khong ghi registry)
   ELSE: CDG user duyet (hoac auto-approve skip) → return
   ↓
Read procedures/phase2-add-scope.md → execute → return
   ↓
Read procedures/phase3-define-features.md → execute → return
   ↓
IF "design" NOT IN $SKIP_PHASES:
   Read procedures/phase4-design.md → execute → return
   ↓
IF "plan-modules" NOT IN $SKIP_PHASES:
   Read procedures/phase5-plan-modules.md → execute → return
   ↓
IF "implement" NOT IN $SKIP_PHASES:
   Read procedures/phase6-implement.md → execute → return
   ↓
Read procedures/phase7-report.md → Step 7.0 Cross-Validation → Tao reports → STOP
```

> **Moi phase file la self-contained** — chua PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE, Next Phase.
> Phase file tham chieu `procedures/_shared.md` cho cross-cutting concerns.

---

## Output Files

> **Session Isolation (CORE-030):** Moi lan chay tao session rieng biet.
> `$SESSION_DIR` = `.mc-data/work/wf-migrate-module/sessions/$MIGRATE_ID/` (VD: `sessions/MIG-20260511-001/`)

| # | File | Path | Phase | Template |
|---|------|------|-------|----------|
| 0 | Index | `.mc-data/work/wf-migrate-module/index.json` | 0 | `templates/index.json` |
| 1 | Status | `$SESSION_DIR/migrate-status.json` | 0 | `templates/migrate-status.json` |
| 2 | Pre-flight Results | `$SESSION_DIR/preflight-results.json` | 0 | _(new v1.1)_ |
| 3 | Gap Analysis | `$SESSION_DIR/gap-analysis.md` | 1 | `templates/gap-analysis.md` |
| 4 | Strategy Matrix | `$SESSION_DIR/strategy-matrix.md` | 1 | `templates/strategy-matrix.md` |
| 5 | Entity Mapping | `$SESSION_DIR/entity-mapping.md` | 1 | `templates/entity-mapping.md` |
| 6 | Checkpoint | `$SESSION_DIR/checkpoint.json` | moi phase | `templates/checkpoint.json` |
| 7 | Parity Check | `$SESSION_DIR/parity-check-{feature}.md` | 6 | `templates/parity-check.md` |
| 8 | Registry Snapshots | `$SESSION_DIR/snapshots/registry-phase*.json` | 2, 6 | _(new v1.1)_ |
| 9 | Migrate Report | `$SESSION_DIR/migrate-report.md` | 7 | `templates/migrate-report.md` |
| 10 | Phase Summary | `$SESSION_DIR/phase-summary.md` | 7 | `templates/phase-summary.md` |
| 11 | Rollback Guide | `$SESSION_DIR/rollback-guide.md` | 7 | `templates/rollback-guide.md` |

---

## Error Handling

| Code | Tinh huong | Hanh dong |
|------|------------|-----------|
| E001 | PRE-GATE fail: thieu registry | STOP — *"Chay `/wf-brainstorm` truoc."* |
| E002 | Scan session khong ton tai | STOP — hoi user xac nhan lai `--from-scan` session ID |
| E003 | Scan session chua hoan thanh (status != completed) | STOP — *"Session scan chua hoan thanh. Doi scan xong hoac chay lai."* |
| E004 | `--to-system` khong tim thay trong registry | Hoi user: tao system moi hay nhap lai ID? |
| E005 | User prompt trong, khong co noi dung | STOP — hoi user mo ta them |
| E006 | Registry JSON invalid | STOP — bao user fix registry |
| E007 | Sub-skill (`wf-add-scope`/`wf-define-features`/...) fail | Retry 1 lan → neu van fail → checkpoint + STOP |
| E008 | Phase 1 CDG user khong dong y strategy | Quay lai Phase 1 — dieu chinh strategy |
| E009 | Feature parity fail (output moi != output cu) > 3 | Log chi tiet sai lech → hoi user |
| E010 | Context overflow (>80%) | Luu checkpoint → STOP — *"Dung `--resume` de tiep tuc."* |
| E011 | `--skip-phase` khong hop le | STOP — liet ke phase co the skip |
| E012 | Template khong tim thay (CORE-031) | STOP — bao thieu template file |
| E013 | Sub-skill timeout | Retry 1 lan voi scope nho hon → neu van fail → checkpoint + STOP |
| E014 | Circular dependency phat hien giua module cu va moi | WARNING — ghi lai, tiep tuc |
| E015 | Entity mapping incomplete — co field unmapped khong co rationale | STOP — hoi user bo sung rationale |
| **E016** | **NEW v1.1** — Sub-skill pre-flight check fail | Hien thi contract gap → hoi user fix hoac tiep tuc |
| **E017** | **NEW v1.1** — Parity CRITICAL (>5 FAIL) | Trigger rollback protocol → auto-rollback neu `--auto-rollback` |
| **E018** | **NEW v1.1** — Rollback snapshot write fail | Retry 1 lan → neu van fail → WARNING + continue |
| **E019** | **NEW v1.1** — Cross-validation CRITICAL (>5 mismatches) | STOP — hien thi danh sach mismatches, bao user investigate |
| **E020** | **NEW v1.1** — Auto-rollback revert fail | Thu revert tung file thu cong → log chi tiet → STOP |
| **E021** | **NEW v1.1** — --resume-task invalid (task khong ton tai) | Hien thi danh sach task → hoi user nhap lai |

---

## Context & Checkpoint

| Context Usage | Hanh dong |
|---------------|-----------|
| < 65% | Tiep tuc binh thuong |
| 65-80% | Chuan bi checkpoint |
| 80-90% | Luu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bat buoc |

> Resume Process chi tiet → `procedures/_shared.md` §Resume Logic.

---

## Related Skills

| Skill | Quan he |
|-------|---------|
| `/wf-scan-target` | **Prerequisite** — ban tu chay de quet module cu, skill nay doc output |
| `/wf-add-scope` | **Delegate** — goi trong Phase 2 de seed module/features vao registry |
| `/wf-define-features` | **Delegate** — goi trong Phase 3 de tao feature specs |
| `/wf-design` | **Delegate** — goi trong Phase 4 de thiet ke kien truc |
| `/wf-plan-modules` | **Delegate** — goi trong Phase 5 de tao task plan |
| `/wf-implement-feature` | **Delegate** — goi trong Phase 6 de implement code |
| `/wf-brainstorm` | **Prerequisite** — tao registry ban dau |
| `/wf-manage-change` | **Alternative** — sua tinh nang DA CO (khong phai migrate tu cu) |
| `/wf-legacy-scan` | **Alternative** — scan TOAN BO du an cu (khong phai tung module) |
| `/wf-fix-bugs` | **Alternative** — fix bug code bi loi |
| `/status` | Kiem tra tien do du an |

---

## Output Report

```markdown
## /wf-migrate-module Hoan tat!

| Muc | Gia tri |
|-----|---------|
| Module cu | [$SOURCE_MODULE] |
| Module moi | [$TARGET_MODULE trong $TARGET_SYSTEM] |
| Features migrated | [$FEATURE_COUNT features] |
| Strategy | [Keep: $K, Redesign: $R, Deprecate: $D, Merge: $M] |
| Registry | [UPDATED — $NEW_FEAT_COUNT features moi] |
| Code | [IMPLEMENTED — $TASK_COUNT tasks hoan thanh] |
| Parity | [PASS: $P / PARTIAL: $P / FAIL: $F] |
| CI | [GitNexus: $G, Serena: $S] |
| Auto-Approve | [$AUTO_APPROVE] |

**Output files:**
- Gap analysis: `.mc-data/work/wf-migrate-module/$MIGRATE_ID/gap-analysis.md`
- Strategy matrix: `.mc-data/work/wf-migrate-module/$MIGRATE_ID/strategy-matrix.md`
- Entity mapping: `.mc-data/work/wf-migrate-module/$MIGRATE_ID/entity-mapping.md`
- Parity reports: `.mc-data/work/wf-migrate-module/$MIGRATE_ID/parity-check-*.md`
- Migrate report: `.mc-data/work/wf-migrate-module/$MIGRATE_ID/migrate-report.md`
- Phase summary: `.mc-data/work/wf-migrate-module/$MIGRATE_ID/phase-summary.md`
- Rollback guide: `.mc-data/work/wf-migrate-module/$MIGRATE_ID/rollback-guide.md`
- Rollback snapshots: `.mc-data/work/wf-migrate-module/$MIGRATE_ID/snapshots/`

Next: `/status` de kiem tra tien do, hoac `/wf-preflight` de kiem tra chat luong.
```
