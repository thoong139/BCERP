---
name: wf-fix-bugs
version: 11.2.0
last_updated: 2026-05-17
description: >
  Orchestrator workflow cho fix bugs — 7-phase pipeline: Init → Scan → Plan → Find Bugs → Triage → Execute → Verify.
  Dimension-based lane dispatch (QD1-QD11) với CI-first (GitNexus + Serena) và Playwright (headless/visible/mobile).
  9 procedure files (8 phase + resume-status), 38 templates (v10.11 thêm coverage-report.json), CI PRE-GATE (Protocol 20), POST-GATE per phase (CORE-012 T1-T4), PRE-GATE/POST-GATE File Contract, Playwright modes.
  
  TRIGGER: User báo có lỗi / bug / fix / sửa lỗi / không chạy được / bị crash / "fix all bugs" / gọi lệnh /wf-fix-bugs

  KHÔNG trigger: /wf-preflight, /wf-verify-sync, /wf-implement-feature, refactor lớn (dùng --modify)

argument-hint: "[mô-tả-lỗi] [--scope=all|system|module] [--name=<id>] [--dry-run] [--resume] [--status] [--migrate] [--session=<SESSION_ID>] [--resume-strategy=prompt|auto|force-fresh] [--profile=quick|standard|deep|exhaustive] [--dims=QD1,QD3,QD5,QD11] [--llm-scan] [--show-browser] [--mobile] [--url=<app-url>] [--credentials=email:password|cookie:NAME=VALUE] [--no-browser] [--deep] [--full-test] [--responsive]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, AskUserQuestion, Agent, mcp__serena__check_onboarding_performed, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-bugs: $ARGUMENTS

## Overview

| Mục                    | Nội dung                                                                                                           |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Mục đích**   | Orchestrate fix bugs workflow — 7-phase pipeline: Init → Scan → Plan → Find Bugs → Triage → Execute → Verify |
| **Prerequisites** | Code tồn tại (`src/` hoặc `apps/`), `req-registry.json` có `.requirements` non-empty                    |
| **Input**         | Mô tả lỗi (optional) +`req-registry.json` + source code                                                        |
| **Output**        | Fixed code +`fix-impact.json` (cross-skill artifact) + `orchestrator-summary.md` (CORE-028)                     |
| **Phases**        | `1 → 2 → 3 → 4 → 5 → 6 → 7`                                                                                 |
| **Duration**      | Multi-session (có thể resume với `--resume`)                                                                   |

### Workflow Position

```
[Entry] → /wf-fix-bugs → /wf-verify-sync → /status
               |
          YOU ARE HERE
               |
        7-Phase Pipeline (lazy-loaded procedures)
```

### Relationship với existing skills

| Skill                                                       | So sánh                                                                                                                                 |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `/wf-fix-bugs` (skill này)                               | **Orchestrator** — dispatch 11 dimension lanes (QD1-QD11) để tìm và sửa mọi loại bug. Multi-session, CI-first, Playwright. |
| `/wf-manage-change`                                       | Xử lý**thay đổi business logic** (sửa, bổ sung, xóa tính năng). Có impact assessment + user approval. Không tìm bug.   |
| `/wf-preflight`                                           | **Health check** nhanh — PASS/WARN/FAIL. Không sửa code.                                                                        |
| `/wf-fix-triage`                                          | **Phase 5 delegate** của skill này — classify + triage bugs. Không chạy độc lập.                                           |
| `/wf-fix-execute`                                         | **Phase 6 delegate** của skill này — thực thi fixes. Không chạy độc lập.                                                  |
| `/wf-fix-functional` → `/wf-fix-business-completeness` | **Lane skills QD1-QD11** — spawned bởi Phase 4. Mỗi skill phụ trách 1 dimension. Không chạy độc lập.                     |

---

## Arguments

| Argument              | Mô tả                                                                              | Default      |
| --------------------- | ------------------------------------------------------------------------------------ | ------------ |
| `[mô-tả-lỗi]`    | Mô tả lỗi (optional) — pass inline đến Phase 1                                 | —           |
| `--scope=<s>`       | Phạm vi:`all`, `system`, `module`                                             | `all`      |
| `--name=<id>`       | Scope target ID (required nếu `--scope=system\|module`)                            | —           |
| `--profile=<p>`     | Execution profile:`quick`, `standard`, `deep`, `exhaustive`                  | `standard` |
| `--dims=<list>`     | Comma-separated dimensions:`QD1,QD3,QD5`                                           | auto (ISG)   |
| `--dry-run`         | Preview mode — skip fix execution, chỉ preview plan                                | false        |
| `--resume`          | Resume từ session checkpoint gần nhất                                             | —           |
| `--status`          | Hiển thị trạng thái pipeline hiện tại → STOP                                  | —           |
| `--migrate`         | Migrate sessions v6.x → v7.0 layout                                                 | —           |
| `--session=<ID>`    | Chỉ định SESSION_ID cụ thể khi dùng `--resume`/`--status` (P4)             | latest       |
| `--resume-strategy` | Hành vi `--resume`:`prompt` (default) /`auto` (CI/cron) /`force-fresh` (P6) | `prompt`   |
| `--llm-scan`        | Enable LLM-Augmented Scan (yêu cầu profile=deep\|exhaustive)                       | false        |
| `--show-browser`    | Playwright visible mode (default: headless)                                          | false        |
| `--mobile`          | Playwright device emulation (iPhone 14, Pixel 7, iPad Pro)                           | false        |
| `--url=<url>`       | Base URL cho browser tests (QD9)                                                     | —           |
| `--credentials=<c>` | Credentials:`email:password` hoặc `cookie:NAME=VALUE`                           | —           |
| `--no-browser`      | Skip browser-based probes (QD5/QD7/QD9)                                              | false        |
| `--deep`            | Shorthand: kích hoạt deep mode cho tất cả probes                                 | false        |
| `--full-test`       | Expand →`--deep` + `--responsive`                                               | false        |
| `--responsive`      | Kích hoạt responsive tests (QD7)                                                   | false        |

> **Canonical input spec:** `_contract.json §inputs`. Bảng trên là bản rút gọn — types, defaults, và descriptions đầy đủ trong contract.

---

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 9 (Task Planning), Protocol 10 (POST-GATE Schema),
> Protocol 16 (Critical Decision Gate), Protocol 19 (Template Usage Rule), Protocol 20 (Code Intelligence).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Error Handling Canonical,
> CI Detection Pattern, Playwright Integration, Agent Prompt Templates.

### Priority Ladder (BẮT BUỘC)

1. **Độ chính xác, tính nhất quán, tính đầy đủ, chất lượng kỹ thuật, bảo mật**
2. **Tốc độ xử lý và song song hóa** — CHỈ SAU KHI mục 1 được bảo vệ

- KHÔNG đánh đổi correctness, completeness, security để lấy tốc độ (CORE-023)
- Mọi output downstream PHẢI bám upstream docs + registry (CORE-024)
- Song song hóa CHỈ khi có owner rõ, write scope tách biệt, contract ổn định, re-verification (CORE-025)

### Template Usage Rule (CORE-031)

> **BẮT BUỘC:** Mọi file có Template PHẢI được tạo bằng pattern:
>
> 1. **READ** template file từ `templates/`
> 2. **POPULATE** — thay thế placeholders bằng giá trị thực tế
> 3. **WRITE** output file đến destination path
>
> **NẾU SKIP bước READ template → STOP skill.** Không viết output từ đầu khi template tồn tại.
>
> **Protocol:** `.claude/skills/protocols/19-template-usage.md`

### Execution Strategy

| Phase       | Mode               | Agent Count | Ghi chú                               |
| ----------- | ------------------ | ----------- | -------------------------------------- |
| 1 Init      | SEQUENTIAL         | 0           | Flags → CI PRE-GATE → CDG → session |
| 2 Scan      | HYBRID             | 0           | CI-ROUTE tools + bash                  |
| 3 Plan      | HYBRID             | 0           | Python CLI + CDG (AskUserQuestion)     |
| 4 Find Bugs | **PARALLEL** | 0-10        | Lane dispatch (Playwright SEQUENTIAL)  |
| 5 Triage    | Agent Delegation   | 1           | wf-fix-triage spawn                    |
| 6 Execute   | Agent Delegation   | 1           | wf-fix-execute spawn                   |
| 7 Verify    | SEQUENTIAL         | 0           | CQG gates + summaries                  |

---

## CI PRE-GATE (Protocol 20 §20.8)

> CI tools auto-detect, không hỏi user. Lock held → fallback Grep/Glob.

| Step | Action                                                                                                                                                                      | Verify               |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| Na   | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Graceful: lock held → fallback Grep/Glob. | CI flags set         |
| Nb   | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → ok/light/strong/severe.                                                              | Freshness status set |
| Nc   | **Agent Context Injection:** Run `bash .claude/scripts/ci-inject-context.sh` → `$CI_CONTEXT` for sub-skill spawn.                                                | CI context ready     |

### CI-ROUTE: Orchestrator Stages

| Stage   | CI Task                | Primary Tool                                                      | Fallback    |
| ------- | ---------------------- | ----------------------------------------------------------------- | ----------- |
| Scan    | `project_structure`  | **Serena** `onboarding` / **GitNexus** `clusters` | Glob        |
| Scan    | `understand_flow`    | **GitNexus** `query({key_concept})`                       | Grep + Read |
| Scan    | `find_by_annotation` | **GitNexus** `cypher` + **Serena** `find_refs`    | Grep        |
| Execute | `impact_analysis`    | **GitNexus** `impact({target})`                           | Grep        |

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load qua các phase files riêng.
> Nguyên tắc bắt buộc: Read MỖI phase file CHỈ KHI tới phase tương ứng (Làm tới Phase nào thì READ `procedures` của phase đó)

| #            | Phase         | Procedure File                     | Điều kiện                 | Mode              |
| ------------ | ------------- | ---------------------------------- | ---------------------------- | ----------------- |
| **1**  | Init          | `procedures/phase1-init.md`      | Always (entry)               | SEQUENTIAL        |
| **2**  | Scan Scope    | `procedures/phase2-scan.md`      | Phase 1 POST-GATE pass       | HYBRID            |
| **3**  | Plan          | `procedures/phase3-plan.md`      | Phase 2 POST-GATE pass       | HYBRID            |
| **4**  | Find Bugs     | `procedures/phase4-find-bugs.md` | Phase 3 POST-GATE pass       | PARALLEL (max 10) |
| **5**  | Triage        | `procedures/phase5-triage.md`    | Phase 4 POST-GATE pass (N>0) | Agent Delegation  |
| **6**  | Execute       | `procedures/phase6-execute.md`   | Phase 5 POST-GATE pass       | Agent Delegation  |
| **7**  | Verify        | `procedures/phase7-verify.md`    | Always (kể cả E005)        | SEQUENTIAL        |
| **—** | Resume/Status | `procedures/resume-status.md`    | `--status` or `--resume` | Dispatch          |

### Routing Flow

```
SKILL.md entry → Parse arguments
  ├── --status → Read procedures/resume-status.md §--status → STOP
  ├── --resume → Read procedures/resume-status.md §--resume → route to last checkpoint
  └── Fresh run → Read procedures/phase1-init.md → execute → return
       ↓
Read procedures/phase2-scan.md → execute → return
       ↓
Read procedures/phase3-plan.md → execute → return
       ↓
Read procedures/phase4-find-bugs.md → PARALLEL spawn → collect → return
       ↓ (IF N=0 → E005 jump Phase 7)
Read procedures/phase5-triage.md → aggregate → spawn triage → CDG → return
       ↓
Read procedures/phase6-execute.md → spawn execute → return
       ↓
Read procedures/phase7-verify.md → CQG → summaries → fix-impact → DONE
       ↓
→ /wf-verify-sync hoặc /status
```

---

## Phase Summary (condensed — chi tiết trong procedure files)

> **Lazy-load:** Mỗi phase có procedure file riêng (`procedures/phaseN-name.md`). SKILL.md chỉ giữ summary để routing nhanh.
> Input/Output detailed paths đã có trong [§Output Files](#output-files) và `_contract.json §outputs.working[]`.
> Optimization history (v10.3–v10.16: parallel waves, wrapper scripts, sub-step refactors) đã document đầy đủ trong frontmatter `description` + CHANGELOG. KHÔNG lặp lại trong bảng dưới đây để tránh nhiễu.

| Phase                  | Steps | Mode                      | Key Milestones                                                                                                                           | Critical Gates                                                                                                    | Procedure File                                         |
| ---------------------- | ----- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| **1 Init**       | 18    | HYBRID (2 parallel waves) | Parse flags → CI PRE-GATE → session+lock+heartbeat → ISG fast-path → state init                                                      | CI PRE-GATE Na/Nb/Nc; POST-GATE T1-T4                                                                             | [`phase1-init.md`](procedures/phase1-init.md)           |
| **2 Scan Scope** | 5     | HYBRID                    | Interface detect + code/doc inventory + scope analysis                                                                                   | POST-GATE T1-T4 (3 inventory files + interface_type)                                                              | [`phase2-scan.md`](procedures/phase2-scan.md)           |
| **3 Plan**       | 7     | HYBRID                    | ISG + Partition → Workload Gate → Route + Write work-plan/dimension-plan                                                               | **CDG-11 Workload**; POST-GATE T1-T4 (≥1 workload valid + cross-ref T4)                                    | [`phase3-plan.md`](procedures/phase3-plan.md)           |
| **4 Find Bugs**  | 9     | PARALLEL (max 10)         | Browser CDG → render+verify prompts → parallel lane dispatch → monitor + collect + validate                                           | **E090/E090b Browser CDG**; E040-E049 lane errors; POST-GATE T1-T4                                          | [`phase4-find-bugs.md`](procedures/phase4-find-bugs.md) |
| **5 Triage**     | 10    | Agent Delegation          | Aggregate + spot-check (CORE-029) → spawn wf-fix-triage → CDG Pre-Execute → Safety Check                                              | **E005 healthy** (N=0 → jump Phase 7); **CDG Pre-Execute**; **Safety Check (CORE-020)**        | [`phase5-triage.md`](procedures/phase5-triage.md)       |
| **6 Execute**    | 7     | Agent Delegation          | Dry-run preview → CI impact analysis → spawn wf-fix-execute → verify outputs + dashboard                                              | **CDG HIGH/CRITICAL** (Step 6.4); POST-GATE T1-T4 + retry x1 (Step 6.5)                                     | [`phase6-execute.md`](procedures/phase6-execute.md)     |
| **7 Verify**     | 8     | SEQUENTIAL                | CQG-1/CQG-2 → mobile gate + dashboard finalize → 4 reports (orchestrator-summary + fix-impact + phase-summary + Phase7-report) → DONE | **CQG-1 Numeric** (5% threshold); **CQG-2 Browser+Integration**; CDG REJECT missing QD9/QD10 evidence | [`phase7-verify.md`](procedures/phase7-verify.md)       |

> **Input/Output chi tiết per phase:** Mở procedure file → §"Input" + §"Output". Tất cả output paths đã document trong [§Output Files](#output-files) bảng 35 rows + `_contract.json §outputs.working[]`.
>
> **Execution details per phase** (sub-step breakdown, bash script wrappers, version notes): xem từng procedure file — mỗi file đã có header version + step-by-step logic.

---

## PRE-GATE / POST-GATE File Contract

> **Protocol:** CORE-012 (POST-GATE T1-T4: exists → structure → content depth → cross-reference).
> Mỗi phase transition có điều kiện PRE-GATE (files phải tồn tại) và POST-GATE (validate T1-T4 trước khi sang phase sau).
> Phase 1 có thêm CI PRE-GATE (Protocol 20) chạy trước PRE-GATE validation.

| #                 | Transition          | PRE-GATE (files must exist)                                                                    | POST-GATE (T1-T4 validate)                                             | Error |
| ----------------- | ------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ----- |
| **1→2**    | Init → Scan        | `fix-status.json`, `Phase1-report.md`, session dir + lock active                           | T1-T4: fix-status.json structure valid, session-log.json writable      | E010  |
| **2→3**    | Scan → Plan        | `scope-analysis.json`, `code-inventory.json`, `doc-inventory.json`, `Phase2-report.md` | T1-T4: all 3 inventory files non-empty + interface_type detected       | E020  |
| **3→4**    | Plan → Find Bugs   | `work-plan.json`, `dimension-plan.json`, `Phase3-report.md`                              | T1-T4: ≥1 fix-workload.json valid, dimension→lane routing complete   | E030  |
| **4→5**    | Find Bugs → Triage | ≥1 lane `signals.json` non-empty, all lane `lane-status.json`                             | T1-T4: signal count > 0, per-lane status COMPLETE/FAIL                 | E040  |
| **5→6**    | Triage → Execute   | `issue-registry.json`, `bug-triage.md`, `fix-plan.md`, `cdg-tokens.json` (CDG ACCEPT)  | T1-T4: issue-registry ≥1 entry, fix-plan non-empty, safety-check PASS | E050  |
| **6→7**    | Execute → Verify   | `fix-report.md`, `docs-sync-report.json`, `Phase6-report.md`                             | T1-T4: fix-report ≥1 fix recorded, docs-sync valid                    | E060  |
| **7→DONE** | Verify → Complete  | `orchestrator-summary.md`, `fix-impact.json`, `phase-summary.md`, `Phase7-report.md`   | T1-T4 + CQG-1 numeric + CQG-2 browser/integration                      | E070  |

### Gate Flow Diagram

```
Phase 1 Init ──[POST-GATE]──→ Phase 2 Scan ──[POST-GATE]──→ Phase 3 Plan ──[POST-GATE]──→
Phase 4 Find Bugs ──[POST-GATE]──→ Phase 5 Triage ──[POST-GATE + CDG]──→
Phase 6 Execute ──[POST-GATE]──→ Phase 7 Verify ──[POST-GATE + CQG]──→ DONE
                                                                      ↑
                                              Phase 5 (N=0 E005) ────┘
```

### Gate File Traceability

> Mỗi PRE-GATE check T1 (file exists) xác minh output của phase trước đã được tạo.
> Mỗi POST-GATE T1-T4 đảm bảo output của phase hiện tại đạt chuẩn trước khi sang phase sau.
> Nếu POST-GATE fail → retry x1 verbose → vẫn fail → E001 escalate.
> Nếu PRE-GATE fail → DỪNG, ghi error code tương ứng vào error-ledger.json.

---

## Playwright Integration

| Mode                         | Flag               | Behavior                                                                                                    |
| ---------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------- |
| **Headless** (default) | —                 | Chromium headless, invisible. Session-isolated.                                                             |
| **Visible**            | `--show-browser` | Chromium visible window for debugging + user observation.                                                   |
| **Mobile**             | `--mobile`       | Device emulation (iPhone 14 390×844, Pixel 7 412×915, iPad Pro 1024×1366). Auto-sets `--show-browser`. |

Playwright runs SEQUENTIALLY across lanes WITHIN session (max 1 browser instance per session). Priority: QD9 → QD5 → QD7 → others. Mobile apps auto-use device emulation.

### Multi-Session Notes (v10.2)

Có thể chạy NHIỀU phiên `wf-fix-bugs` song song trên CÙNG máy cho các module/hệ thống khác nhau:

| Scenario                                                    | An toàn? | Lý do                                                                     |
| ----------------------------------------------------------- | --------- | -------------------------------------------------------------------------- |
| 2 phiên, BASE_URL khác nhau (e.g., :3000 vs :4000)        | ✅        | Browser session-isolated qua per-session port + user-data-dir              |
| 2 phiên, cùng BASE_URL, test data isolated (multi-tenant) | ⚠️      | E090b CDG cảnh báo — chỉ tiếp tục nếu chắc chắn isolated          |
| 2 phiên, cùng BASE_URL, shared state                      | ❌        | Flaky results — race conditions trong SUT. E090b sẽ block, dùng "Đợi" |
| 1 phiên, profile=exhaustive                                | ✅        | Chạy bình thường                                                       |
| N phiên parallel, profile=quick/standard                   | ✅        | Low CPU/RAM contention                                                     |

**Hardening v10.2:**

- Port hash collision: `findFreePort()` retry tự động (max 50 tries) khi port busy
- BASE_URL conflict: Step 1.9 E090b CDG hỏi user khi phát hiện peer session cùng URL
- Escape hatch: `MCV3_PW_ALLOW_SHARED_URL=1` bypass E090b cho CI/CD

---

## Fix Rules

| Error Type           | Auto-Fix Strategy                   | Escalate If        |
| -------------------- | ----------------------------------- | ------------------ |
| Template missing     | Đọc lại template từ git history | Không có history |
| POST-GATE T1-T4 fail | Retry phase x1 verbose              | Vẫn fail          |
| Agent output invalid | Re-spawn x1 nhấn mạnh schema      | Vẫn invalid       |
| Context overflow     | FORCE checkpoint, STOP              | —                 |
| CI detection fail    | Fallback Grep/Glob                  | —                 |

---

## Error Handling

> **Canonical table:** xem `procedures/_shared.md §Error Handling Canonical`. Bảng dưới đây
> chỉ là reference quick lookup. Nếu mâu thuẫn → `_shared.md` là SSOT.

### Namespace Convention (v10.0)

```
E001-E009   → Pipeline/session/lock (shared)
E010-E019   → Phase 1 Init (flags, CI PRE-GATE, CDG, session)
E020-E029   → Phase 2 Scan (scan code, scan docs, CI tools)
E030-E039   → Phase 3 Plan (ISG, partition, workload gate, dispatch)
E040-E049   → Phase 4 Find Bugs (lane dispatch, probes, Playwright)
E050-E059   → Phase 5 Triage (aggregate, dedup, triage, CDG, safety)
E060-E069   → Phase 6 Execute (fix spawn, docs, verify)
E070-E079   → Phase 7 Verify (CQG, summaries, impact)
E090-E099   → CDG User-Facing Gates (Browser, Scope, Cost, Mobile)
E100-E109   → Recommendations (QD9/QD10/QD11)
```

### Quick Lookup

| Code           | Severity | Tình huống                                            | Xử lý                      |
| -------------- | -------- | ------------------------------------------------------- | ---------------------------- |
| E001           | high     | POST-GATE fail sau 3 retries                            | DỪNG, escalate              |
| E003           | high     | Registry thiếu/rỗng                                   | STOP — chạy /wf-brainstorm |
| E004           | high     | Sub-skill SKILL.md không tồn tại                     | STOP                         |
| E005           | info     | N=0 issues sau Phase 5                                  | "Healthy!" → jump Phase 7   |
| E009           | high     | Context > 90%                                           | FORCE checkpoint, STOP       |
| E010-E012      | medium   | Flag dispatch (`--status`/`--resume`/`--migrate`) | Route handler → STOP        |
| E013           | high     | Legacy deprecation block                                | CDG render, escape hatch     |
| E014-E015      | high     | CI detection fail                                       | Graceful degrade Grep/Glob   |
| E020-E023      | medium   | Scan empty/stale/undetectable                           | WARN, continue               |
| E030-E033      | high     | Plan fail (profile/partition/gate)                      | Fallback/CGD render          |
| E040-E045      | high     | Find Bugs fail (probe/Playwright/agent)                 | Retry/Log/Escalate           |
| E050-E055      | high     | Triage fail (aggregate/triage/CDG/safety)               | Retry/CDG/Escalate           |
| E060-E061      | high     | Execute fail (spawn/report)                             | Re-spawn/Retry               |
| E070-E071      | high     | Verify fail (CQG-1/CQG-2)                               | Retry/CDG                    |
| E090-E093      | info     | CDG user-facing gates                                   | DỪNG, hướng dẫn          |
| E100           | low      | Recommendation warning                                  | LOG, continue                |
| E_LEGACY_BLOCK | fatal    | Legacy v6.x paths                                       | Exit 78                      |
| EDLG           | high     | Sub-skill incomplete                                    | LOG error, FAIL trace        |

---

## Context & Checkpoint

| Context Usage | Hành động                               |
| ------------- | ------------------------------------------ |
| < 65%         | Tiếp tục bình thường                  |
| 65-80%        | Chuẩn bị checkpoint                      |
| 80-90%        | Lưu checkpoint ngay                       |
| > 90%         | FORCE STOP — checkpoint bắt buộc (E009) |

> Resume process chi tiết → `procedures/resume-status.md`

---

## Output Files

### Session-scoped outputs (tại `sessions/{SESSION_ID}/`)

| #   | File                                                                                          | Phase   | Template                                               |
| --- | --------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------ |
| 1   | `fix-status.json`                                                                           | 1       | `templates/phase1-init/fix-status.json`              |
| 2   | `session-log.json`                                                                          | All     | `templates/_common/session-log.json`                 |
| 3   | `error-ledger.json`                                                                         | All     | `templates/_common/error-ledger.json`                |
| 4   | `phase1-init/Phase1-report.md`                                                              | 1       | `templates/phase1-init/Phase1-report.md`             |
| 5   | `phase2-scan/scope-analysis.json`                                                           | 2       | `templates/phase2-scan/scope-analysis.json`          |
| 6   | `phase2-scan/code-inventory.json`                                                           | 2       | `templates/phase2-scan/code-inventory.json`          |
| 7   | `phase2-scan/doc-inventory.json`                                                            | 2       | `templates/phase2-scan/doc-inventory.json`           |
| 8   | `phase2-scan/Phase2-report.md`                                                              | 2       | `templates/phase2-scan/Phase2-report.md`             |
| 9   | `phase3-plan/work-plan.json`                                                                | 3       | `templates/phase3-plan/work-plan.json`               |
| 10  | `phase3-plan/dimension-plan.json`                                                           | 3       | `templates/phase3-plan/dimension-plan.json`          |
| 11  | `phase3-plan/workloads/W{N}/fix-workload.json`                                              | 3       | `templates/phase3-plan/fix-workload.json`            |
| 12  | `phase3-plan/Phase3-report.md`                                                              | 3       | `templates/phase3-plan/Phase3-report.md`             |
| 13  | `phase4-find-bugs/lanes/QD{n}/*/signals.json`                                               | 4       | `templates/phase4-find-bugs/lane-signals.json`       |
| 14  | `phase4-find-bugs/lanes/QD{n}/lane-status.json`                                             | 4       | `templates/phase4-find-bugs/lane-status.json`        |
| 15  | `phase4-find-bugs/lanes/QD{n}/QD{n}-report.md`                                              | 4       | `templates/phase4-find-bugs/QD-report.md`            |
| 16  | `phase4-find-bugs/Phase4-report.md`                                                         | 4       | `templates/phase4-find-bugs/Phase4-report.md`        |
| 17  | `phase4-find-bugs/probe-failures-log.json`                                                  | 4       | `templates/phase4-find-bugs/probe-failures-log.json` |
| 17b | `phase4-find-bugs/phase4-summary.json` (v10.10 cross-lane rollup, schema phase4-summary-v1) | 4       | `templates/phase4-find-bugs/phase4-summary.json`     |
| 17c | (prompt template, read-only by orchestrator — KHÔNG ghi)                                    | 4       | `templates/phase4-find-bugs/lane-agent-prompt.md`    |
| 18  | `phase5-triage/issue-registry.json`                                                         | 5       | `templates/phase5-triage/issue-registry.json`        |
| 19  | `phase5-triage/bug-triage.md`                                                               | 5       | `templates/phase5-triage/bug-triage.md`              |
| 20  | `phase5-triage/fix-plan.md`                                                                 | 5       | `templates/phase5-triage/fix-plan.md`                |
| 21  | `phase5-triage/fix-log.json`                                                                | 5       | `templates/phase5-triage/fix-log.json`               |
| 22  | `phase5-triage/cdg-tokens.json`                                                             | 5       | `templates/phase5-triage/cdg-tokens.json`            |
| 23  | `phase5-triage/safety-check.json`                                                           | 5       | `templates/phase5-triage/safety-check.json`          |
| 24  | `phase5-triage/process-violations.json`                                                     | 5       | `templates/phase5-triage/process-violations.json`    |
| 25  | `phase5-triage/coverage-report.md`                                                          | 5       | `templates/phase5-triage/coverage-report.md`         |
| 25b | `phase5-triage/coverage-report.json` (v10.11 machine-readable, schema coverage-report-v1)   | 5       | `templates/phase5-triage/coverage-report.json`       |
| 26  | `bug-dashboard.md` (SESSION_DIR root — cross-phase shared state, v10.10.0 path fix)        | 1/5/6/7 | `templates/phase5-triage/bug-dashboard.md`           |
| 27  | `phase5-triage/Phase5-report.md`                                                            | 5       | `templates/phase5-triage/Phase5-report.md`           |
| 28  | `phase6-execute/fix-report.md`                                                              | 6       | `templates/phase6-execute/fix-report.md`             |
| 29  | `phase6-execute/docs-sync-report.json`                                                      | 6       | `templates/phase6-execute/docs-sync-report.json`     |
| 30  | `phase6-execute/fix-execution-result.json`                                                  | 6       | `templates/phase6-execute/fix-execution-result.json` |
| 31  | `phase6-execute/Phase6-report.md`                                                           | 6       | `templates/phase6-execute/Phase6-report.md`          |
| 32  | `phase7-verify/orchestrator-summary.md`                                                     | 7       | `templates/phase7-verify/orchestrator-summary.md`    |
| 33  | `phase7-verify/fix-impact.json`                                                             | 7       | `templates/phase7-verify/fix-impact.json`            |
| 34  | `phase7-verify/phase-summary.md`                                                            | 7       | `templates/phase7-verify/phase-summary.md`           |
| 35  | `phase7-verify/Phase7-report.md`                                                            | 7       | `templates/phase7-verify/Phase7-report.md`           |

> **CORE-031:** Mọi output path và template PHẢI khớp với `_contract.json §outputs.working[]`.
> Trước khi thêm/sửa output → cập nhật `_contract.json` trước, rồi mới code.

### Index & Lock

| File           | Path                                                                    |
| -------------- | ----------------------------------------------------------------------- |
| Sessions index | `.mc-data/work/wf-fix-bugs/_index/sessions.jsonl` (APPEND-only JSONL) |
| Session lock   | `sessions/{SESSION_ID}/.lock` + heartbeat daemon                      |

---

## Next Step:

Next: `/wf-verify-sync` (đồng bộ requirement-to-code) → `/status` (xem tổng quan dự án).

```
→ /wf-verify-sync  (đồng bộ requirement-to-code)
→ /status           (xem tổng quan dự án)
```

---

## Related Skills

| Skill                             | Quan hệ                                       |
| --------------------------------- | ---------------------------------------------- |
| `/wf-fix-triage`                | Phase 5 delegate — classify + triage bugs     |
| `/wf-fix-execute`               | Phase 6 delegate — execute fixes              |
| `/wf-fix-functional`            | Lane QD1 — functional correctness probes      |
| `/wf-fix-business`              | Lane QD2 — business correctness probes        |
| `/wf-fix-security`              | Lane QD3 — security probes                    |
| `/wf-fix-performance`           | Lane QD4 — performance probes                 |
| `/wf-fix-ux-a11y`               | Lane QD5 — accessibility & UX probes          |
| `/wf-fix-data`                  | Lane QD6 — data integrity probes              |
| `/wf-fix-compat`                | Lane QD7 — compatibility probes               |
| `/wf-fix-observability`         | Lane QD8 — observability probes               |
| `/wf-fix-runtime-health`        | Lane QD9 — runtime health probes (Playwright) |
| `/wf-fix-integration`           | Lane QD10 — cross-module integration probes   |
| `/wf-fix-business-completeness` | Lane QD11 — business completeness probes      |
| `/wf-verify-sync`               | Downstream — verify requirement-to-code       |
| `/wf-prepare-deployment`        | Downstream — consume fix-impact.json          |
| `/wf-implement-feature`         | Downstream — enhanced safety gate             |

---

## References

| File                               | Purpose                                                                                                                                                                            |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `procedures/_shared.md`          | Cross-cutting protocols, state vars, CI detection, Playwright, agent prompts, error handling                                                                                       |
| `procedures/phase1-init.md`      | Phase 1 Init detail (18 steps v10.12 — Wave 1 + Wave 4 parallel waves, ISG fast-path bash bypass)                                                                                 |
| `procedures/phase2-scan.md`      | Phase 2 Scan detail (5 steps v10.4 — scan-and-analyze wrapper)                                                                                                                    |
| `procedures/phase3-plan.md`      | Phase 3 Plan detail (7 steps v10.5 — ISG + Partition + Route wrappers)                                                                                                            |
| `procedures/phase4-find-bugs.md` | Phase 4 Find Bugs detail (9 steps v10.6 — PARALLEL lane dispatch, Playwright)                                                                                                     |
| `procedures/phase5-triage.md`    | Phase 5 Triage detail (10 steps v10.7 — aggregate, triage, CDG, safety)                                                                                                           |
| `procedures/phase6-execute.md`   | Phase 6 Execute detail (7 steps v10.8 — CI impact, execute spawn, verify)                                                                                                         |
| `procedures/phase7-verify.md`    | Phase 7 Verify detail (8 steps v10.9 — CQG-1, CQG-2, 4 reports, finalize)                                                                                                         |
| `procedures/resume-status.md`    | --resume & --status handlers                                                                                                                                                       |
| `_contract.json`                 | Structured skill contract — inputs, outputs, templates, error codes, procedures, cross-skill contracts                                                                            |
| `.claude/skills/protocols/`      | Shared protocols (09, 10, 16, 19, 20)                                                                                                                                              |
| **Templates (36 files):**    |                                                                                                                                                                                    |
| `templates/phase1-init/`         | fix-status.json, Phase1-report.md                                                                                                                                                  |
| `templates/phase2-scan/`         | scope-analysis.json, code-inventory.json, doc-inventory.json, Phase2-report.md                                                                                                     |
| `templates/phase3-plan/`         | work-plan.json, dimension-plan.json, fix-workload.json, Phase3-report.md                                                                                                           |
| `templates/phase4-find-bugs/`    | lane-agent-prompt.md (v10.2 — canonical lane agent prompt), lane-signals.json, lane-status.json, QD-report.md, Phase4-report.md, probe-failures-log.json                          |
| `templates/phase5-triage/`       | issue-registry.json, bug-triage.md, fix-plan.md, fix-log.json, cdg-tokens.json, safety-check.json, process-violations.json, coverage-report.md, bug-dashboard.md, Phase5-report.md |
| `templates/phase6-execute/`      | fix-report.md, docs-sync-report.json, fix-execution-result.json, Phase6-report.md                                                                                                  |
| `templates/phase7-verify/`       | orchestrator-summary.md, fix-impact.json, phase-summary.md, Phase7-report.md                                                                                                       |
| `templates/_common/`             | session-log.json, error-ledger.json                                                                                                                                                |

---

## Design Rationale

### Tại sao cần skill này?

1. **11 dimensions (QD1-QD11)** — không skill nào khác cover toàn diện từ functional correctness (QD1) đến business completeness (QD11)
2. **Orchestrator pattern** — dispatch song song 10+ lane agents, aggregate signals, triage, execute — một mình user không thể làm manual
3. **CI-first** — GitNexus + Serena auto-detect giúp impact analysis chính xác trước khi sửa, tránh regression
4. **Playwright browser testing** — QD5/QD7/QD9 cần browser thật để phát hiện lỗi runtime, không thể làm bằng static analysis
5. **Multi-session** — pipeline 7 phase có thể kéo dài nhiều session, checkpoint + resume là bắt buộc

### Design Principles

1. **Lazy-load procedures (v10.0):** SKILL.md ~400 dòng routing, toàn bộ logic trong 9 procedure files + 37 templates. Giảm 70%+ context so với monolithic.
2. **CI-first (Protocol 20):** Mọi scan/impact analysis dùng GitNexus + Serena trước, graceful degradation về Grep/Glob
3. **Dimension isolation:** Mỗi QD lane chạy độc lập, không shared state, không cần coordination
4. **Signal aggregation:** Python CLI aggregate signals từ 11 lanes → dedup → severity classification → triage
5. **Safety gates:** CDG tại mọi critical decision point (E090-E093 browser/scope/cost/mobile, E100 recommendation)
6. **Cross-skill artifact:** `fix-impact.json` consumed bởi wf-verify-sync, wf-prepare-deployment, wf-implement-feature
7. **Playwright integration:** Headless default, visible với `--show-browser`, mobile emulation với `--mobile`. SEQUENTIAL across lanes để tránh conflict browser instances.
8. **Session isolation (CORE-030):** `sessions/{SESSION_ID}/` + lock + heartbeat + JSONL index

---

## Phase Anchors (Audit Compliance)

> Markers tham chiếu nhanh cho audit tooling + reader navigation. Chi tiết execution xem [§Phase Summary](#phase-summary) table + procedure files.

## Phase 1: Init — 18 steps, **2 parallel waves (v10.12)** + CI PRE-GATE wrapper, session+lock+heartbeat → [phase1-init.md](procedures/phase1-init.md)

## Phase 2: Scan — 5 steps, interface detect + code/doc inventory → [phase2-scan.md](procedures/phase2-scan.md)

## Phase 3: Plan — 7 steps, ISG + Partition + Workload Gate → [phase3-plan.md](procedures/phase3-plan.md)

## Phase 4: Find Bugs — 9 steps, PARALLEL 11 lanes dispatch (max 10 concurrent) → [phase4-find-bugs.md](procedures/phase4-find-bugs.md)

## Phase 5: Triage — 10 steps, aggregate + spawn wf-fix-triage + CDG handoff (v10.17.0 lazy-load split) → [phase5-triage.md](procedures/phase5-triage.md)

## Phase 6: Execute — 7 steps, CI impact + spawn wf-fix-execute + dashboard → [phase6-execute.md](procedures/phase6-execute.md)

## Phase 7: Verify — 8 steps, CQG-1/2 + generate 4 reports + finalize DONE (v10.17.0 lazy-load split) → [phase7-verify.md](procedures/phase7-verify.md)

---

## Cross-Validation & Auto-Correction (CORE-034)

> wf-fix-bugs có **multi-layer validation & auto-correction loop** ở mọi phase boundary:

- **POST-GATE T1-T4 validation check** mỗi phase: T1 file exists → T2 structure → T3 content depth → T4 cross-reference. Fail → auto-fix retry (max 3 per phase). Iteration MAX=3 hard limit (CORE-034 auto-fix budget).
- **Cross-Validation Phase 7 CQG-1 Numeric:** Compare expected (fix-plan.md) vs actual (fix-report.md) metrics. Deviation > 5% → auto-fix retry x3 → escalate E070.
- **Cross-Validation Phase 7 CQG-2 Browser+Integration:** Verify QD9/QD10 coverage qua fix-log.json structured check (v10.10.0 — thay grep keyword fragile).
- **Auto-Correction Phase 6 Step 6.5:** verify-execute-outputs.sh fail → re-spawn wf-fix-execute x1 (enforced max-retry counter qua `.retry-count-step-6.5` file).
- **Cross-Reference validation Phase 5 Step 5.10 Safety Check:** Collision detection + REQ-ID xref + uncommitted changes + deprecated modules (4-check audit).
- **Resume validation R9.5 + R9.6:** Preserve retry budget across resume + re-validate prior phase outputs PRE-GATE trước khi tiếp tục.

> Tất cả error codes đều có defined retry strategy trong `_shared.md §4 Canonical Codes` + `_contract.json §errors`.

---

## Registry Safe-Write Delegation (CORE-006)

> **wf-fix-bugs là ORCHESTRATOR** — `registry_scope.fields_owned = []`, `write_role = "NONE"`. KHÔNG ghi `req-registry.json` trực tiếp.

- **Registry write được delegate sang `wf-fix-execute` (Phase 6 sub-skill)**: Khi fix code có impact đến REQ-IDs (vd: implement_status thay đổi), wf-fix-execute áp dụng Safe-Write Protocol theo `protocols/05-registry-safe-write.md`.
- **Fields được phép update bởi wf-fix-execute** (CORE-006 SAFE-UPDATE role): `impl_status` (chỉ upgrade not_started → in_progress → done, KHÔNG downgrade per CORE-008), `last_modified`. **KHÔNG modify** fields của skills khác (Safe-Write rules).
- **Atomic write pattern** (CORE-006 quy ước): build tmp → validate jq → mv atomic. Áp dụng cho mọi fields được phép update.
- **Verification sau ghi:** `wf-fix-execute` chạy `jq '.' req-registry.json` PASS + check `impl_status ∈ {not_started, in_progress, done, skipped}` (CORE-010).
- **Audit chain:** Mọi registry write được log vào `fix-log.json` với `action:"registry_update"`. Cross-skill verify qua `wf-verify-sync --from-fix-bugs`.

> Chi tiết Safe-Write rules + role matrix: `.claude/skills/protocols/05-registry-safe-write.md`.
