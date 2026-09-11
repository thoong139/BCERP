---
name: wf-fix-triage
version: 1.5.0
last_updated: 2026-05-12
description: |
  Triage phase cho wf-fix-bugs. Phan loai issues theo severity va fixability → bug-triage.md + fix-plan.md + enriched issue-registry.json + fix-log.json init + phase-summary.md.
  Nhan issue-registry.json (initial) tu wf-fix-bugs orchestrator (Lane Dispatch Phase 0-2), enrich severity/fixability/domain, tao execution plan cho wf-fix-execute.

  TRIGGER khi: spawned boi /wf-fix-bugs (khong goi truc tiep).
  De resume session bi gian doan: /wf-fix-triage --resume

  Output: $SESSION_DIR/bug-triage.md, fix-plan.md, issue-registry.json (updated: severity+fixability+domain), fix-log.json (init), phase-summary.md (CORE-028)

argument-hint: "[--resume] [--status]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__serena__replace_symbol_body, mcp__serena__insert_before_symbol, mcp__serena__insert_after_symbol, mcp__serena__replace_content, mcp__serena__rename_symbol, mcp__serena__safe_delete_symbol, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, mcp__plugin_gitnexus_gitnexus__rename, mcp__plugin_gitnexus_gitnexus__route_map, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-triage: Triage Phase

## Overview

| Muc | Noi dung |
|-----|----------|
| **Muc dich** | Phan loai issues (severity + fixability + domain) va chuan bi execution plan |
| **Entry point** | Spawned boi wf-fix-bugs (khong goi truc tiep) hoac `--resume` |
| **Prerequisites** | `$SESSION_DIR/issue-registry.json` (initial, tu wf-fix-bugs Lane Dispatch), `fix-status.json` voi `phases.phase_1.status == "completed"` |
| **Duration** | 1 session (nhe, khong chay agents) |
| **Phases** | Phase 2 (Triage only) |
| **Output** | `bug-triage.md` + `fix-plan.md` + `issue-registry.json` (updated) + `fix-log.json` (init) + `phase-summary.md` (CORE-028) |

### Workflow Position

```
wf-fix-bugs (Phase 0-2: Lane Dispatch)
  -> [spawn] wf-fix-triage <- YOU ARE HERE
        |
  wf-fix-execute (Phase 3-6)
```

---

## Entry Point

**Khi duoc spawn boi wf-fix-bugs:**

wf-fix-bugs truyen context qua `$SESSION_DIR`. wf-fix-triage nhan:
- `$SESSION_DIR` = path den session directory (co fix-status.json + issue-registry.json initial)

**Khi user dung `--resume`:**

wf-fix-triage tu tim latest session bang cach scan `.mc-data/work/wf-fix-bugs -maxdepth 4 -name fix-status.json` (bao phu ca scope=all tai ROOT run-*/ va scope=system/module tai sessions/**/run-*/), sau do loc: `phases.phase_2.status != "completed"`.

---

## Arguments

| Argument | Mo ta | Default |
|----------|-------|---------|
| `--resume` | Resume tu checkpoint truoc | - |
| `--status` | Hien thi trang thai Phase 2 roi STOP | - |

---

## Protocols & Strategy

> **Protocol:** Xem `.claude/skills/protocols/` — `01-accuracy-assurance`, `02-auto-correction` (T007 retry loop), `03-context-checkpoint`, `06-token-limit`, `08-content-quality-gate` (CQG cho bug-triage.md + fix-plan.md), `09-task-planning` (Step 2.6), `10-post-gate-schema` (T1–T4), `14-phase-summary` (Step 2.8), `15-execution-trace` (append-only), `16-critical-decision-gate` (Step 2.7 user confirm), `18-session-isolation`, `19-template-usage`.

### Priority Ladder (BAT BUOC)

1. **Do chinh xac, chat luong, tinh nhat quan** — phan loai dung severity va fixability
2. **Toc do** — chi sau khi mục 1 được bảo vệ

### Execution Strategy

| Condition | Mode |
|-----------|------|
| Tat ca steps | **SEQUENTIAL** — triage la nhe, phu thuoc tuan tu |

Khong spawn agents. Tat ca xu ly trong main conversation.

### Template Usage Rule (BAT BUOC — CORE-031)

> Moi output file PHAI duoc tao tu template: READ template -> POPULATE -> WRITE.

Templates dung boi skill nay:
- `.claude/skills/workflow/wf-fix-triage/templates/bug-triage.md` — bug-triage.md
- `.claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/fix-plan.md` — fix-plan.md (canonical v10, Sprint 3 F07.010)
- `.claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/fix-log.json` — fix-log.json init (canonical schema fix-log-v2, Sprint 3 XF-03)
- `$SESSION_DIR/issue-registry.json` — UPDATE (khong CREATE — da tao boi wf-fix-bugs orchestrator)
- `phase-summary.md` — inline template (xem Phase 2 Step 2.8), tuan thu `protocols/14-phase-summary.md`

---

## Phase 0: PRE-GATE

> **Chi tiet execution:** READ `procedures/phase2-triage.md` (PRE-GATE section) + `procedures/_shared.md §T1` (CI-ROUTE Bug Investigation). CI PRE-GATE 3-step (Na/Nb/Nc) per wf-fix-bugs/procedures/_shared.md §12.

### Summary

| # | Step | Verify |
|---|------|--------|
| 0.Na | **CI Load Capabilities** — IF orchestrator passed CI context → reuse; ELSE (`--resume` standalone) auto-detect qua `ci-detect.sh` | `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE` set |
| 0.Nb | **Index Freshness Check** — `ci-freshness-check.sh` (ok/light/strong/severe) | SEVERE → user warning |
| 0.Nc | **CI Context Injection** — `ci-inject-context.sh` → bug investigation context | `$CI_CONTEXT` ready |
| 1 | **Session Resolution** — caller-provided `$SESSION_DIR` HOẶC `--resume` auto-discover latest non-completed session | `$SESSION_DIR` valid |
| 2 | **fix-status.json Validation** — JSON valid, `phases.phase_1.status == "completed"`, `phases.phase_2.status != "completed"` | PRE-GATE pass |
| 2a | **v6 Mode Detection** — `$ENGINE_VERSION = "v6"` → load `dimensions_run`, `profile_used` | `$V6_MODE` set |
| 3 | **issue-registry.json Validation** — file exists, valid JSON, has issues (rỗng → STOP "Khong co issues") | issues loaded |
| 4-5 | **Context Load** — `$TARGET_SCOPE`, `$TARGET_DIRS`, `$FLAGS`, `$DISCOVERED_ISSUES`, `$ORPHAN_UI_ISSUES` (if `flags.deep`), `$LARGE_PROJECT` | all variables set |
| 6 | **LEGACY_MODE Detect** (CORE-021) — log only, không ảnh hưởng triage logic | logged |

**Graceful:** CI lock held → fallback Grep. Tool unavailable → Grep. Non-git → skip CI.

**FAIL handling:**
- `fix-status.json` missing → "Chay /wf-fix-bugs truoc."
- Phase 1 chưa xong → "Chay /wf-fix-bugs --resume truoc."
- Phase 2 đã completed → "Chay /wf-fix-execute de tiep tuc."
- issue-registry empty → "Khong co issues. Co the skip qua Phase 6 report."

**Post-PRE-GATE update:** `fix-status.json.phases.phase_2.status = "in_progress"`, `started_at = NOW` (atomic write per `_shared.md §3`).

---

## Phase 2: Triage — Phan loai Loi

> Chi tiet: READ `procedures/phase2-triage.md` — scope filter, domain detection, fixability rules, dry-run handling.

**PRE-GATE:** PRE-GATE passed, `$DISCOVERED_ISSUES` loaded

> **(Protocol 6 — 6.2/6.4)** Neu scan files vuot `$COMPRESSION_THRESHOLD` (LPM: >2 files, standard: >3 files):
> main conversation Grep key sections (REQ-IDs, error patterns) → tao digest theo `$DIGEST_SIZE` → triage agent nhan digest thay vi full files.

### CI-ROUTE: Bug Investigation (Protocol 20 §20.5) — BẮT BUỘC khi CI available

> **Khi `$GITNEXUS_AVAILABLE == "true"` hoac `$SERENA_AVAILABLE == "true"`:** PHẢI dùng GitNexus + Serena de trace bug flows. KHÔNG dùng Grep/Read thu cong khi CI tools available.
> **Graceful:** CI unavailable → fallback Grep/Read (current behavior, zero regression).

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `understand_flow` | **GitNexus** `query("{bug_description}", task_context="fixing bug")` | Grep + Read | Tim execution flows lien quan den bug |
| `find_definition` | **Serena** `find_definition` | Grep | Xac dinh vi tri chinh xac cua suspected function |
| `symbol_overview` | **Serena** `get_symbols_overview` | Read file | Hieu cau truc file chua bug |

> **Freshness caveat:** Neu index behind > 0 → "Results based on index N commits behind HEAD."

**Output:** `$SESSION_DIR/bug-triage.md` + `fix-plan.md` + `issue-registry.json` (updated) + `fix-log.json` (init)

### Steps

> **Chi tiet execution:** READ `procedures/phase2-triage.md` — day la single source cho step logic, verify commands, va error codes.

| Step | Action | Verify |
|------|--------|--------|
| 2.0  | **SCOPE FILTER:** Loc issues theo source + target dirs/routes. Fallback: scope=all → PASS tat ca. | Issues scoped |
| 2.0a | **Deep scan orphan issues** (chi khi `flags.deep == true`) | Orphan issues verified |
| 2.0b | **Issue ID Assignment:** ISSUE-001, ISSUE-002, ... (zero-padded 3-digit) | IDs assigned |
| 2.1  | Phan loai issues theo severity: CRITICAL → HIGH → MEDIUM → LOW | Issues categorized |
| 2.1a | **Domain Detection:** Map issue → module → domain | Domains mapped |
| 2.1b | **v6 Dimension-Aware Severity Hints** (chi khi $V6_MODE): Map issue dimension → severity adjustment. Dimensions QD3 (security) va QD6 (data integrity) issues tự động bump severity +1 (VD: MEDIUM → HIGH) trừ khi da CRITICAL. Hien thi dimension coverage summary. | Severity adjusted |
| 2.1c | **User Journey Impact Detection (v9.0 — chi tiet: `procedures/phase2-triage.md` §Step 2.1d):** FOR each issue: xac dinh `cross_module_impact` (module IDs bi anh huong khi issue.dimensions chua "QD10" hoac issue.type thuoc cross-module signal list), `affected_flows` (tu issue.metadata.flow_ids hoac cross-module pair context), `user_journey_broken` (true khi cross_module_impact > 0 OR affected_flows > 0), `data_consistency_risk` (high/medium/low theo issue.type mapping). **Severity bump rule (v9):** `user_journey_broken=true` VA severity ∉ {CRITICAL, HIGH} → bump severity → HIGH + ghi `severity_bump_reason`. | user_journey_broken + data_consistency_risk populated; severity bumped if needed |
| 2.2  | Phan loai theo fixability (AUTO_FIX / AGENT_FIX / MANUAL_FIX / ESCALATE / SKIP) | Fixability determined |
| 2.3  | **BAT BUOC — bug-triage.md** tu template | File ton tai, co Summary + Execution Plan |
| 2.3a | **BAT BUOC — fix-plan.md** tu cross-skill template | File ton tai, placeholders replaced |
| 2.3b | **BAT BUOC — issue-registry.json UPDATE** (KHONG CREATE) | Issues co severity + fixability + domain + user_journey_broken + data_consistency_risk |
| 2.3c | **BAT BUOC — fix-log.json Init** tu cross-skill template | File ton tai, fix_id set, entries=[] |
| 2.3d | **v6 Coverage-Aware Triage Summary** (chi khi $V6_MODE): Hien thi dimensions nào co issues, issues per dimension, coverage gaps. Bao gom trong bug-triage.md section "Dimension Coverage". | Coverage summary visible |
| 2.4  | Hien thi triage summary cho user | User sees summary |
| 2.5  | Dry-run mode handling (van tao day du files) | — |
| 2.6  | **Token & Checkpoint Planning** (Protocol 9) | Plan documented |
| 2.7  | **User confirmation** (Protocol 16 — CDG, chi khi dry_run=false) | User confirmed |
| 2.8  | **BAT BUOC — phase-summary.md** (CORE-028 + Protocol 14, tieng Viet ≤20 dong) | File ton tai, ≤20 lines, co required sections |

---

## Fix Rules

| Rule | Ap dung | Ghi chu |
|------|---------|---------|
| Severity chi co 4 muc | CRITICAL / HIGH / MEDIUM / LOW | KHONG them bucket moi |
| Fixability chi co 5 loai | AUTO_FIX / AGENT_FIX / MANUAL_FIX / ESCALATE / SKIP | Anti-Invention Rule |
| MEDIUM AUTO_FIX/AGENT_FIX | LUON vao batch | KHONG defer vi "budget" |
| --profile=quick | Chi xu ly CRITICAL + HIGH | MEDIUM/LOW → fixability=SKIP |
| --profile=exhaustive | TAT CA severity vao batch | KHONG skip MEDIUM/LOW |
| QD3/QD6 bump | +1 severity (tru CRITICAL) | Security + Data Integrity domain |
| user_journey_broken + severity ∉ {HIGH,CRITICAL} | Bump → HIGH | v9.0 Cross-Module Impact |
| **Source-aware fixability (v9.2.0)** | `static-scan` → uu tien auto_fix; `runtime` → uu tien agent_fix; `llm-scan` → can scrutiny, escalate neu mo ho | Signal source tu signal_aggregator.py tag |
| **QD11 enhancement (v9.1.0)** | QD11 signals (MISSING_FIELD, MISSING_FEATURE, ...) → fixability LUON = `escalate` | Can user ACCEPT/REJECT qua CDG gate |
| Triage la idempotent | Chay lai tu Step 2.0 neu resume | Consistent voi --resume |

---

## Fixability Categories (CANONICAL — KHONG mo rong, KHONG che thay tu)

| Category  | Mo ta | Action |
|-----------|-------|--------|
| AUTO_FIX  | Compile errors, type errors, lint, orphan code, registry format | Skill (wf-fix-execute) tu fix |
| AGENT_FIX | Test failures, logic bugs, security issues, **tao moi UI component/helper co spec ro rang** | Developer / Security / Frontend-developer agent fix |
| MANUAL_FIX | Architectural changes, multi-module refactors, complex config changes — can developer review + approve truoc khi auto-fix | Developer review + manual intervention (escalations.json artifact) |
| ESCALATE  | Missing docs, design issues, UI component can UX/business decision truoc | Log + recommend skill/action (escalations.json artifact) |
| SKIP      | **Thuan tuy** informational warnings, style suggestions — KHONG co code change | Log only |

> **QUY TAC PHAN LOAI BAT BUOC:**
> - Issue "can tao UI component moi" → chi la **SKIP** khi: (a) spec chua duoc thiet ke va can UX/business decision truoc, HOAC (b) nam ngoai scope $TARGET_DIRS.
> - Issue "can tao UI component moi" nhung mo ta du ro (biet duoc component name, behavior, input/output) → **AGENT_FIX** (spawn `frontend-developer`), **KHONG PHAI SKIP**.

### Anti-Invention Rule (BAT BUOC — BHV-002 Simplicity First)

> **CAM** che thay tu cua Fixability Categories hoac Severity. Triage PHAI dung dung 4 severity (CRITICAL/HIGH/MEDIUM/LOW) + 5 fixability (AUTO_FIX/AGENT_FIX/MANUAL_FIX/ESCALATE/SKIP) o tren — KHONG duoc tao bucket moi.

CAM dung cac thuat ngu sau trong bug-triage.md, fix-plan.md, fix-log.json, fix-report.md, phase-summary.md:

| Cam dung | Phai dung | Ly do |
|----------|-----------|-------|
| "FIX NOW" | "Batch 1/2/3" hoac severity | Bucket khong co trong taxonomy |
| "FIX IF BUDGET" | "Batch 3" (MEDIUM AUTO_FIX/AGENT_FIX) | Tat ca MEDIUM AUTO_FIX/AGENT_FIX phai vao Batch 3, KHONG defer |
| "DEFER MANUAL" | "MANUAL_FIX" + escalations.json entry | MANUAL_FIX la fixability, khong phai severity bucket |
| "DEFER BACKLOG" | "LOW + AUTO_FIX/AGENT_FIX/SKIP" | LOW van vao batch (neu agent_fix/auto_fix), khong defer |
| "TODO LATER", "FOLLOW-UP", "POSTPONE" | severity + fixability concrete | Vague terms, gay confusion |

**Profile-aware semantics:**

- `--profile=quick`: Chi xu ly CRITICAL + HIGH (AUTO_FIX/AGENT_FIX). MEDIUM/LOW van triage nhung fixability set thanh `SKIP` voi reason="profile=quick".
- `--profile=standard` (default): CRITICAL + HIGH + MEDIUM (AUTO_FIX/AGENT_FIX) phai vao batches. LOW SKIP gracefully.
- `--profile=deep`: Same as standard + deep UI traversal stub creation.
- `--profile=exhaustive`: TAT CA severity (CRITICAL/HIGH/MEDIUM/LOW) co fixability=AUTO_FIX/AGENT_FIX phai vao batches. Khong "defer to backlog". MANUAL_FIX/ESCALATE van di vao escalations.json (vi can stakeholder review).

**Vi pham se bi POST-GATE T5 chan** (xem POST-GATE section).

---

## POST-GATE

> **Chi tiet bash scripts:** READ `procedures/phase2-triage.md` (POST-GATE section) — canonical T1→T6 validation + escalations.json jq builder + fix-status update.
> **Summary table:** `procedures/_shared.md §T2 Tiered Validation Pattern`.

### Summary (Protocol 10 T1→T6 + Steps P1-P4)

| # | Check / Step | Mục đích | FAIL → |
|---|--------------|----------|--------|
| T1 | File existence (`test -s` cho 5 outputs) | bug-triage.md, fix-plan.md, issue-registry.json, fix-log.json, phase-summary.md | E_T001 retry max 3 → T007 |
| T2-T3 | Structure + content depth | issue-registry.json[0] có `severity+fixability+domain`; phase-summary.md ≤20 lines + required sections | E_T002/E_T003 retry |
| T4 | Schema gate | skip nếu `.issues == []`, otherwise jq schema check | E_T004 |
| T5 | **Anti-Invention** | bug-triage.md/fix-plan.md KHÔNG chứa FORBIDDEN_PATTERN; fixability ∈ canonical 5 | E_T005 retry max 3 → T012 |
| T6 | **Profile Coverage** | `exhaustive` profile KHÔNG skip MEDIUM/LOW vì 'budget' | E_T006 retry → T013 |
| P1 | User Confirmation (CDG Protocol 16) | applicable nếu `!flags.dry_run`, render ở Step 2.7 | re-prompt |
| P2 | escalations.json builder | tạo `$SESSION_DIR/escalations.json` (schema `escalations-v1`) nếu có MANUAL_FIX/ESCALATE | log + continue |
| P3 | UPDATE fix-status.json (atomic) | `phases.phase_2.status="completed"`, counts, output_files, `progress_pct=30`, `next_action="phase_3_execute"` | retry atomic write |
| P4 | Display + Return Control | Hiển thị phase-summary.md inline + orchestrator summary, return về wf-fix-bugs | — |

**FAIL Handling Summary** (chi tiết: `procedures/phase2-triage.md §FAIL Handling`):
- T1-T3 fail → retry tạo lại output (max 3) → T007 escalate
- T5 fail → retry tạo lại bug-triage.md + fix-plan.md (max 3) → T012 escalate
- T6 fail → retry với exhaustive profile rule (max 3) → T013 escalate
- phase-summary.md fail sau 3 iterations → VẪN tạo với status='THAT BAI' (Protocol 14.1 exception)

---

## Phase Summary Template (inline — CORE-028)

> Tao o Step 2.8 sau khi POST-GATE T1-T4 pass (hoac fail voi status=THAT BAI).
> Tieng Viet, <=20 dong, non-technical.

```markdown
# Tom Tat: /wf-fix-triage

**Thoi gian:** [YYYY-MM-DD HH:mm:ss]
**Trang thai:** HOAN THANH | HOAN THANH CO LUU Y | THAT BAI

## Da lam gi
- Phan loai [N] loi theo muc do nghiem trong va kha nang tu sua.
- Len ke hoach thuc thi [N] batch, uoc tinh [N] tokens.

## Ket qua
- CRITICAL: [X] | HIGH: [Y] | MEDIUM: [Z] | LOW: [W]
- Tu sua tu dong: [N] | Can agent ho tro: [N] | Chuyen nguoi xu ly: [N]
- [N] loi ngoai pham vi (neu co scope filter)

## Can luu y
- [Chi ghi items can user action. Vi du: N loi can agent chuyen gia,
  M loi ngoai pham vi, K loi can thiet ke lai UX. Neu khong co: "Khong co"]

## Buoc tiep theo
- Quay lai `/wf-fix-bugs` de tiep tuc (spawn `/wf-fix-execute`)
```

---

## Registry Safe-Write (CORE-006)

> **wf-fix-triage KHONG ghi vao `req-registry.json`** — Safe-Write Protocol khong ap dung cho req-registry.

Skill nay chi ghi vao **session artifacts** (khong phai registry SSOT):
- `$SESSION_DIR/issue-registry.json` — UPDATE (enrich severity/fixability/domain), KHONG ghi de fields cua wf-fix-bugs orchestrator
- `$SESSION_DIR/bug-triage.md`, `fix-plan.md`, `fix-log.json` — CREATE tu template
- `$SESSION_DIR/fix-status.json` — UPDATE phases.phase_2.* ONLY

> **Protocol:** Xem `.claude/skills/protocols/05-registry-safe-write.md` — wf-fix-triage role = NONE (req-registry).

**Rules:**
- Orchestrator family: ghi vao `$SESSION_DIR/phase-summary.md` (overwrite summary cua phase truoc)
- Resume (--resume): giu nguyen summary cu, chi update khi phase complete
- Hien thi inline cho user sau khi WRITE (Protocol 14.4)

---

## Resume Logic (--resume)

```
1. Resolve $SESSION_DIR:
   (a) Neu co --scope/--name: dung SESSION_DIR Resolution trong wf-fix-bugs/SKILL.md
   (b) Khong co: fallback scan qua find -maxdepth 4 (xem PRE-GATE §1) — bao phu ca scope=all + system/module
2. READ $SESSION_DIR/fix-status.json
3. VALIDATE:
   phases.phase_1.status == "completed"
   phases.phase_2.status != "completed"
4. Neu phases.phase_2.status == "in_progress" va co bug-triage.md partial:
   Hien thi "Bug-triage.md da co phan tich one-phase nhung chua xong" -> Offer: regenerate tu dau hoac reuse?
5. Run tu Step 2.0 (scope filter) lai — triage la idempotent, chay lai de dam bao tinh nhat quan.
```

---

## Context & Checkpoint

| Context Usage | Hanh dong |
|---------------|-----------|
| < 65% | Tiep tuc binh thuong |
| 65-80% | Chuan bi checkpoint |
| 80-90% | Luu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bat buoc |

Triage la phase nhe, hiem khi chua den 65% context. LPM can them note neu issues > 100.

---

## Output Files

| # | File | Duong dan | Phase | Template |
|---|------|-----------|-------|----------|
| 1 | Bug triage | `$SESSION_DIR/bug-triage.md` | 2 | `.claude/skills/workflow/wf-fix-triage/templates/bug-triage.md` |
| 2 | Fix plan | `$SESSION_DIR/fix-plan.md` | 2 | `.claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/fix-plan.md` (canonical v10, Sprint 3 F07.010) |
| 3 | Issue registry (updated) | `$SESSION_DIR/issue-registry.json` | 2 | UPDATE (tao boi wf-fix-bugs orchestrator) |
| 4 | Fix log (init) | `$SESSION_DIR/fix-log.json` | 2 | `.claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/fix-log.json` (canonical schema fix-log-v2, Sprint 3 XF-03) |
| 5 | Phase summary (CORE-028) | `$SESSION_DIR/phase-summary.md` | 2 (Step 2.8) | Inline template (tieng Viet, <=20 dong) — xem §Phase Summary Template |

---

## Domain Expert Routing (Tham khao)

> Triage gan `domain` field cho moi issue de wf-fix-execute biet agent nao cham. Xem `procedures/phase2-triage.md` §Domain Expert Routing cho day du danh sach mapping module -> domain -> agent.

| Module | Domain | Agent |
|--------|--------|-------|
| CRM, Sales, Customer | sales | sales-expert |
| ERP Finance, Accounting | finance | finance-expert |
| Manufacturing, MES | manufacturing | manufacturing-expert |
| Healthcare, EMR | healthcare | healthcare-expert |
| ... | ... | ... |

Neu khong match domain cu the → domain = "general" → developer agent.

---

## Error Handling

> Ma loi T### (task-level) va E0## (severe/escalation) — cung 1 bang, ap dung theo protocol.

| Code | Tinh huong | Xu ly |
|------|------------|-------|
| E001 | POST-GATE fail sau 3 retries | STOP — escalate voi bao cao chi tiet |
| E002 | User tu choi tiep tuc | Ghi checkpoint, thong bao resume bang `--resume` |
| E010 | Template bug-triage.md missing sau 3 retries (tu T005 escalate) | STOP — check wf-fix-triage/templates/ |
| E011 | --deep flag nhung checkpoint.json missing/invalid (tu T008 escalate) | STOP — "Checkpoint bi loi hoac chua tao. Chay /wf-fix-bugs --resume de regenerate" |
| E012 | Cross-skill template missing sau 3 retries (tu T006 escalate) | STOP — check _shared/lane/templates/ |
| T001 | issue-registry.json khong ton tai | STOP — "Chay /wf-fix-bugs truoc" |
| T002 | Phase 1 chua completed | STOP — "Chay /wf-fix-bugs --resume" |
| T003 | Phase 2 da completed | SKIP — "Chay /wf-fix-execute de tiep tuc" |
| T004 | Khong co issues sau scope filter | Tao bug-triage.md trang (Total=0, khong co tables), fix-plan.md (No batches), fix-log.json (init voi entries=[]), phase-summary.md ("Khong co loi can fix"). **KHONG UPDATE issue-registry.json** (giu nguyen do wf-fix-bugs orchestrator tao — skip schema check T4 neu .issues rong). Update fix-status.json: phase_2.status='completed', issues.by_severity tat ca 0, issues.out_of_scope=N. Orchestrator SKIP qua Phase 6 report. |
| T005 | Template bug-triage.md khong ton tai | Retry 3 lan (Protocol 2). Neu fail → STOP voi E010 |
| T006 | Cross-skill template (fix-plan.md, fix-log.json) khong ton tai | Retry 3 lan (Protocol 2). Neu fail → STOP voi E012 — Check _shared/lane/templates/ |
| T007 | POST-GATE jq/grep validation fail | Protocol 2 Auto-Correction: retry triage x3, escalate voi E001 neu van fail |
| T008 | --deep flag nhung checkpoint.json missing/invalid | STOP (E011) — "Checkpoint bi loi hoac chua tao. Chay /wf-fix-bugs --resume de regenerate" |
| T009 | checkpoint.json valid nhung deep_scan_state missing | WARN — Tiep tuc voi $ORPHAN_UI_ISSUES=[] (Phase 4b se skip stub creation) |
| T010 | issue-registry.json co pre-assigned issue_id (contract violation) | STOP — "Expected all issue_id to be null. wf-fix-triage Step 2.0b la owner duy nhat assign IDs." |
| T011 | phase-summary.md khong duoc tao / line count > 20 / thieu required sections | Protocol 2: retry Step 2.8 x3. Neu van fail → VAN tao phase-summary.md voi status='THAT BAI' (Protocol 14.1 exception), do day la observability output bat buoc. |
| T012 | Anti-Invention violation (T5 fail) — bug-triage.md/fix-plan.md chua thuat ngu cam ("FIX NOW", "FIX IF BUDGET", "DEFER MANUAL", "DEFER BACKLOG"...) hoac issue-registry.json co fixability ngoai canonical taxonomy | Protocol 2: retry Step 2.3 + 2.3a (re-render bug-triage.md va fix-plan.md theo template) x3. Neu van fail → STOP voi E_TAXONOMY_INVENTION, ESCALATE. |
| T013 | Profile Coverage violation (T6 fail) — exhaustive profile co MEDIUM/LOW skip voi reason='budget'/'backlog'/'defer' | Protocol 2: retry Step 2.2 voi profile-aware fixability rule x3. Neu van fail → STOP voi E_PROFILE_DRIFT, ESCALATE. |

---

## Related Skills

| Skill | Quan he |
|-------|---------|
| `/wf-fix-bugs` | **Parent orchestrator** — chay Lane Dispatch (Phase 0-2), spawn wf-fix-triage sau khi issue-registry.json san sang |
| `/wf-fix-execute` | **Next** — doc bug-triage.md, fix-plan.md, enriched issue-registry.json, fix-log.json |

**Next:** `/wf-fix-bugs` tiep tuc: spawn `/wf-fix-execute` (neu khong dry-run) hoac Phase 6 Report.

---

## Execution Trace (CORE-026)

> File: `.mc-data/work/_trace/session-log.json` — **append-only** (Protocol 15).
> KHONG bao gio Read toan bo session-log.json trong skill execution. Chi append entry moi.

| Thoi diem | Event | Fields skill-specific |
|-----------|-------|------------------------|
| Sau PRE-GATE pass | START | `session_dir`, `issues_input=N`, `flags: { scope, deep, dry_run }` |
| Sau POST-GATE pass | COMPLETE | `issues_triaged=N, by_severity={...}, by_action={...}, out_of_scope=N` |
| Fail | FAIL | `error_code`, `error_message`, `phase_stopped_at` |
