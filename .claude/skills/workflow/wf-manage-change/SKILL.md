---
name: wf-manage-change
version: 3.0.0
last_updated: 2026-04-29
description: |
  Xu ly yeu cau thay doi/bo sung/sua doi tinh nang trong du an dang phat trien.
  Skill phan tich prompt nguoi dung → trien chuyen gia phan tich → danh gia impact →
  lap ke hoach → thuc hien thay doi (docs + code) → verify khong regression.

  Use cases:
  - Thay doi logic/cach hoat dong cua tinh nang da co (VD: thay doi cach tinh phi don hang)
  - Bo sung thong tin/chi tiet cho yeu cau/tinh nang da co nhung chua day du
  - Them feature moi vao module da co
  - Xoa feature hoac deprecate module
  - Sua doi yeu cau business anh huong nhieu he thong
  - Lam ro/bo sung yeu cau khi AI lam chua dung y nguoi dung

  TRIGGER khi:
  - User mo ta thay doi ve tinh nang: "thay doi cach...", "sua...", "bo sung logic..."
  - User muon update feature da co: "update feature X", "thay doi feature Y"
  - User muon them logic cho module da co: "them tinh nang X vao module Y"
  - User muon xoa tinh nang: "xoa feature X", "bo tinh nang Y"
  - User muon thay doi ma khong ro can lam gi: "toi muon...", "can thay..."
  - Keywords: "thay doi", "sua tinh nang", "change", "modify", "update feature",
    "them logic", "bo sung", "xoa tinh nang", "manage change", "thay doi logic",
    "sua lai", "cap nhat", "adjust", "thay doi requirement", "chinh sua"

  LUON trigger khi user muon thay doi bat ky dieu gi ve du an da co,
  ke ca khi user khong ro rang ve can thay doi gi.
  Day la skill danh cho nguoi KHONG CHUYEN — chi can mo ta y muon.

  KHONG trigger khi:
  - Du an moi hoan toan → dung /new-project
  - Chi can them feature moi hoan toan (da biet ro) → dung /feature-addition
  - Fix bug (code bi loi) → dung /wf-fix-bugs
  - Them modules moi vao registry → dung /wf-add-scope
  - Chi kiem tra suc khoe → dung /wf-preflight

argument-hint: "[mo-ta-thay-doi] [--scope=all|system|module] [--name=<id>] [--mode=quick|deep] [--dry-run] [--run-tests] [--resume] [--status]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, AskUserQuestion, TodoWrite
---

# /wf-manage-change: $ARGUMENTS

## Overview

| Muc | Noi dung |
|-----|----------|
| **Muc dich** | Phan tich yeu cau thay doi → danh gia impact → thuc hien thay doi docs + code → verify khong regression |
| **Prerequisites** | `.mc-data/docs/_meta/req-registry.json` ton tai (du an da qua brainstorm) |
| **Duration** | Multi-session (30-120 phut, phu thuoc do phuc tap thay doi) |
| **Phases** | 10 phase files (0, 1, 2, 3, 4a, 4b, 4c, 5, 6, _shared) — lazy-loaded qua routing |
| **Input** | User prompt + registry + project docs + source code |
| **Output** | Updated docs + code + `change-report.md` + `phase-summary.md` |

### Workflow Position

```
Bat ky luc nao sau khi du an co registry:
  /wf-analyze-requirements (done) → ... → /wf-manage-change ← YOU ARE HERE
                                                       ↓
                                               /wf-preflight → /wf-verify-sync
```

### Relationship voi existing skills

| Skill | So sanh |
|-------|---------|
| `/feature-addition` | Them feature MOI (da biet ro). Khong phan tich, khong impact assessment. |
| `/wf-fix-bugs` | Fix bug (code bi loi). Khong thay doi business logic. |
| `/wf-add-scope` | Them modules/features moi vao registry. Append-only, khong sua. |
| `/wf-manage-change` (skill nay) | Xu ly moi loai thay doi: sua, bo sung, xoa, tach, gop. Co phan tich + impact. |

---

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `[mo-ta-thay-doi]` | Mo ta yeu cau thay doi bang ngon ngu tu nhien | — |
| `--scope` | `all` / `system` / `module` — pham vi quet. **Khong biet ID → chay `/status` de xem danh sach system/module IDs, hoac de trong (default `all`)** | `all` |
| `--name` | ID cua system/module khi scope hep (VD: `SYS-BACKEND`, `MOD-ORDERS`). **Lay ID tu `/status` hoac tu registry** | — |
| `--mode` | `quick` / `deep` — che do phan tich. Quick: AI phan tich truc tiep. Deep: trien chuyen gia. **Neu khong ro → bo trong de AI tu chon** | auto (dua do phuc tap) |
| `--dry-run` | Chi phan tich + impact, KHONG thuc hien thay doi. **Khuyen dung khi thay doi co rui ro cao** | false |
| `--run-tests` | Chay test suite sau Phase 4c (neu co test runner). Neu khong co → WARNING + skip | false |
| `--resume` | Resume tu checkpoint. **Dung khi skill bi ngat giua chung** | — |
| `--status` | Hien thi tien do hien tai va danh sach sessions | — |

**Vi du:**

```bash
/wf-manage-change "Thay doi cach tinh phi don hang — them phi van chuyen theo khoang cach"
/wf-manage-change "Bo sung xac thuc 2 lop cho module login" --scope=system --name=SYS-BACKEND
/wf-manage-change "Xoa tinh nang xuat Excel" --mode=quick
/wf-manage-change "Toi muon thay doi luong cong viec cua don hang" --dry-run
/wf-manage-change --status
/wf-manage-change --resume
```

### Template Usage Rule (CORE-031)

> **BAT BUOC:** Moi file co Template PHAI duoc tao bang pattern:
> 1. **READ** template file tu `templates/`
> 2. **POPULATE** — thay the placeholders bang gia tri thuc te
> 3. **WRITE** output file den destination path
>
> **NEU SKIP buoc READ template → STOP skill.** Khong viet output tu dau khi template ton tai.

---

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 1 (POST-GATE), Protocol 6 (Token Limit), Protocol 7 (PAR), Protocol 8 (CQG), Protocol 9 (PLN), Protocol 10 (POST-GATE Schema Validation), Protocol 10.4 (Forensic PRE-GATE), Protocol 11 (Rollback), Protocol 14 (Phase Summary), Protocol 15 (Session Log), Protocol 16 (CDG — Phase 4a DELETE_FEATURE), Protocol 17 (Agent Spot-Check — Phase 1 DEEP), Protocol 18 (Session Isolation — CORE-030), Protocol 19 (Template Usage Rule).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables, Expert Selection Map, Registry Safe-Write Rules, Agent Prompt Templates (Phase 5), Checkpoint Protocol, Resume Routing Table (→ procedures/resume-routing.md), CORE-026/028.

### Priority Ladder (BAT BUOC)

1. **Do chinh xac, chat luong, tinh nhat quan, bao mat**
2. **Toc do va song song hoa** — chi sau khi muc 1 duoc bao ve

### Execution Strategy

| Condition | Mode |
|-----------|------|
| Phase 0-3 (Intake → Plan) | **SEQUENTIAL** — moi phase phu thuoc phase truoc |
| Phase 1 DEEP — spawn experts | **PARALLEL** (max 3 experts dong thoi) |
| Phase 2 — code scan + doc check | **PARALLEL** neu 3 dieu kien dat (xem phase2 file) |
| Phase 4a — docs update (per doc) | **SEQUENTIAL** — moi doc la input cho buoc sau |
| Phase 4b — code update (per module) | **SEQUENTIAL** trong module, **PARALLEL** giua modules doc lap |
| Phase 5 — verify (preflight + verify-sync) | **SEQUENTIAL** |

### Fix Rules (tom tat)

| Error Type | Auto-Fix | Escalate If |
|-----------|----------|-------------|
| User prompt khong ro | AskUserQuestion (max 2 vong) | User khong phan hoi du |
| Doc update fail | Retry 3 lan | Van fail |
| Code update fail | Rollback + retry 1 lan | Van fail |
| Context overflow (>80%) | Checkpoint ngay | — |

> Chi tiet day du: `procedures/_shared.md` §Fix Rules.

---

## Phase 0 Entry & Routing

**PRE-GATE:**
```bash
test -f .mc-data/docs/_meta/req-registry.json
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json
```
Neu fail → STOP: *"Du an chua co registry. Chay `/wf-brainstorm` truoc."*

### CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools duoc auto-detect, khong hoi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → check per-tool TTL. ALL fresh → load cache. ANY stale + lock acquired → scan MCP tools → write cache → release. Lock held → exit 2 → fallback Grep/Glob (current behavior). Read `.mc-data/work/_meta/code-intelligence.json` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sanh HEAD vs index_commit. SEVERE (>20 behind) → warning: "Impact analysis may miss recent changes." | Freshness status set |

```
STEP 1: Handle --status / --resume flags
  IF $ARGUMENTS chua "--status":
    → Read procedures/phase0-intake.md §Flag Handlers §--status → STOP sau khi hien thi

  IF $ARGUMENTS chua "--resume":
    → Read procedures/phase0-intake.md §Flag Handlers §--resume
    → Route theo procedures/_shared.md §Resume Logic & Routing Table → STOP sau khi route

STEP 2: Normal entry (khong flag)
  → Read procedures/phase0-intake.md → execute Phase 0 → return
  → Continue theo Phase Routing Map duoi
```

| Step | Action |
|------|--------|
| 1 | PRE-GATE: kiểm tra registry tồn tại và có nội dung |
| 2 | Xử lý flags --status / --resume nếu có |
| 3 | Phase 0: session init + classify change type |
| 4 | Phase 1-5: analyze → impact → plan → execute → verify (lazy-load từng phase) |
| 5 | Phase 6: POST-GATE T1-T4 + change-report + phase-summary |

---

## Phase 1-6 Routing Map (lazy-loaded)

> SKILL.md routing block KHONG chua execution steps. Toan bo logic chi tiet duoc lazy-load
> qua cac phase files rieng. Read MOI phase file CHI KHI toi phase tuong ung de giam context load.

| Phase | Procedure file | Dieu kien | Muc dich |
|-------|---------------|-----------|----------|
| **0** | `procedures/phase0-intake.md` | Always (entry point) | Session init + LEGACY detect + argument parse + classify change type + clarification |
| **1** | `procedures/phase1-analyze.md` | Always | QUICK hoac DEEP analyze — spawn experts (max 3) + aggregate + spot-check |
| **2** | `procedures/phase2-impact.md` | Always | Impact assessment: code scan + doc check + risk classify + **USER GATE** |
| **3** | `procedures/phase3-plan.md` | Always | Ordered task list + **USER GATE approve** |
| **4a** | `procedures/phase4a-registry-docs.md` | `$DRY_RUN == false` | Registry backup + CDG DELETE + docs update + mini-verify |
| **4b** | `procedures/phase4b-code.md` | `$DRY_RUN == false` | Code backup + parallel eligibility + apply + mini-verify + merge checkpoint |
| **4c** | `procedures/phase4c-tests.md` | `$DRY_RUN == false` | Test update + run-tests prompt + run |
| **5** | `procedures/phase5-verify.md` | `$DRY_RUN == false` | Invoke wf-preflight + wf-verify-sync + cross-validation |
| **6** | `procedures/phase6-report.md` | Always | change-report.md + phase-summary.md + T1→T4 + NEXT STEP |

**Routing flow:**

```
SKILL.md Phase 0 Entry → Read procedures/phase0-intake.md → execute → return
   ↓
Read procedures/phase1-analyze.md → execute → return
   ↓
Read procedures/phase2-impact.md → execute → USER GATE → return
   ↓
Read procedures/phase3-plan.md → execute → USER GATE → return
   ↓
IF $DRY_RUN == true:
   Read procedures/phase4a-registry-docs.md §DRY-RUN STOP GATE → tạo report/summary inline → append sessions.jsonl → release lock → STOP (không tạo change-impact.json)
ELSE:
   Read procedures/phase4a-registry-docs.md → execute → return
   Read procedures/phase4b-code.md → execute → return
   Read procedures/phase4c-tests.md → execute → return
   Read procedures/phase5-verify.md → execute → return
   ↓
Read procedures/phase6-report.md → execute → STOP
```

> **Moi phase file la self-contained** — chua PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE rieng.
> Phase file tham chieu `procedures/_shared.md` cho cross-cutting: State Variables, Safe-Write, LEGACY Injection, Expert Map, Agent Prompts, Resume Routing.

---

## Output Files

> **Session Isolation (CORE-030):** Moi lan chay tao session rieng biet.
> `$SESSION_DIR` = `.mc-data/work/wf-manage-change/$CHANGE_ID/` (VD: `CHG-20260419-001/`)

| # | File | Path | Phase | Template |
|---|------|------|-------|----------|
| 0 | Index | `.mc-data/work/wf-manage-change/index.json` | 0 | `templates/index.json` |
| 1 | Status | `$SESSION_DIR/change-status.json` | 0 | `templates/change-status.json` |
| 2 | Intake | `$SESSION_DIR/change-intake.json` | 0 | `templates/change-intake.json` |
| 3 | Analysis | `$SESSION_DIR/change-analysis.md` | 1 | `templates/change-analysis.md` |
| 4 | Artifacts | `$SESSION_DIR/affected-artifacts.json` | 1 | `templates/affected-artifacts.json` |
| 5 | Impact | `$SESSION_DIR/impact-report.md` | 2 | `templates/impact-report.md` |
| 6 | Plan | `$SESSION_DIR/change-plan.md` | 3 | `templates/change-plan.md` |
| 7 | Report | `$SESSION_DIR/change-report.md` | 6 | `templates/change-report.md` |
| 8 | Change Impact | `$SESSION_DIR/change-impact.json` | 6 | `templates/change-impact.json` |
| 9 | Checkpoint | `$SESSION_DIR/checkpoint.json` | any | `templates/checkpoint.json` |
| 10 | Phase Summary | `$SESSION_DIR/phase-summary.md` | 6 | `templates/phase-summary.md` |

**Next step:** `/wf-preflight` (neu co code changes) hoac `/status` (neu chi doc changes).

---

## Error Handling

| Code | Tinh huong | Xu ly |
|------|------------|-------|
| E001 | PRE-GATE fail: thieu registry | STOP — *"Chay `/wf-brainstorm` truoc."* |
| E002 | User prompt trong, khong co noi dung | STOP — hoi user mo ta them |
| E003 | Change type UNCLEAR sau Phase 0 | Chuyen sang DEEP mode, hoi user lam ro |
| E004 | Artifact khong tim thay trong registry | WARNING — co the la yeu cau moi, hoi user |
| E005 | Registry JSON invalid khi doc | STOP — bao user fix registry |
| E006 | Impact report: tat ca artifacts khong tim thay | WARNING — lai qua tu vung, hoi user |
| E007 | User tu choi impact report | Quay lai Phase 1 — dieu chinh scope |
| E008 | User tu choi plan | Dieu chinh plan va hoi lai |
| E009 | Doc update fail sau 3 lan | STOP — log loi chi tiet, hoi user |
| E010 | Code update fail (compile error) | Rollback file → retry 1 lan → escalate |
| E011 | Mini-verify fail | Log + continue (WARNING). 3+ lien tiep → STOP |
| E012 | Registry update fail (validation) | Rollback tu backup → STOP |
| E013 | Preflight fail sau execute | WARNING — present issues, hoi user co muon fix |
| E014 | Context overflow (>80%) | Luu checkpoint → STOP — `"Dung --resume"` |
| E015 | Status file mat/corrupt | Rebuild tu index.json + $SESSION_DIR files (xem phase0-intake §Status rebuild) |

---

## Context & Checkpoint

| Context Usage | Hanh dong |
|---------------|-----------|
| < 65% | Tiep tuc binh thuong |
| 65-80% | Chuan bi checkpoint |
| 80-90% | Luu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bat buoc |

> Resume Process va routing table chi tiet → `procedures/_shared.md` §Resume Logic & Routing Table.

---

## Related Skills

| Skill | Quan he |
|-------|---------|
| `/wf-brainstorm` | Prerequisite — tao registry |
| `/wf-analyze-requirements` | Alternative — phan tich requirements tu scratch |
| `/feature-addition` | Alternative — them feature moi da biet ro |
| `/wf-fix-bugs` | Alternative — fix bug (code bi loi) |
| `/wf-add-scope` | Delegate — them modules moi vao registry |
| `/wf-preflight` | Used trong Phase 5; consumes `change-impact.json` qua `--from-manage-change` (S6) |
| `/wf-verify-sync` | Used trong Phase 5; consumes `change-impact.json` qua `--from-manage-change` (S6) |
| `/status` | Check project progress |

---

## Design Rationale

### Tai sao can skill nay?

1. `/feature-addition` chi them features MOI — khong xu ly thay doi features da co
2. `/wf-fix-bugs` chi sua bug — khong xu ly thay doi business logic
3. `/wf-add-scope` chi them modules — khong sua/xoa/phan tich
4. Khong co skill nao phan tich prompt user de hieu y dinh truoc khi thuc hien
5. Khong co skill nao danh gia impact truoc khi thay doi code/docs

### Design Principles

1. **User-first:** Nguoi dung khong chuyen — chi can mo ta y muon
2. **An toan truoc:** Impact assessment + user approval truoc moi thay doi
3. **Mini-verify:** Check sau moi buoc nho, khong doi den cuoi
4. **Multi-session:** Checkpoint sau moi phase, --resume tu bat ky dau
5. **Traceability:** Moi thay doi map nguoc ve REQ-ID va requirement
6. **Lazy-load procedures (v2.0.0):** 10 phase files (0, 1, 2, 3, 4a, 4b, 4c, 5, 6, _shared) — AI chi load phase file can thiet, giam 60%+ context usage so voi monolithic flow-new.md
7. **Bash delegation (v3.0):** 11 bash scripts trong `.claude/scripts/wf-manage-change/` — lock, heartbeat, session ID, index append, registry backup/validate, safety check, postgate check, change-impact builder. Giảm context inline bash ~40%.
8. **Lock/Heartbeat (v3.0):** Session lock + registry lock + heartbeat daemon ngăn concurrent write corruption trong môi trường multi-developer.
9. **change-impact.json (v3.0):** Machine-readable artifact sau mỗi session — consumed bởi wf-verify-sync, wf-preflight, wf-implement-feature qua `--from-manage-change` flag.
