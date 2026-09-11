# wf-fix-bugs — Thiết Kế Lại v10.0

> **Status:** DESIGN — chờ phê duyệt để triển khai
> **Last updated:** 2026-05-12
> **Reference architecture:** wf-legacy-scan v5.0.1 (SKILL.md 391 dòng, _shared.md 721 dòng, 9 phase files)
> **User ideas:** wf-fix-bugs-idea.md (7 phase, Phase reports, Agent reports, templates)

---

## 1. Mục Tiêu & Phạm Vi

### 1.1 Vấn đề hiện tại (v9.2.0)

| # | Vấn đề | Root Cause |
|---|--------|-----------|
| 1 | SKILL.md 730 dòng — quá nặng, khó đọc | Phase 0 (~400 dòng bash) nằm inline |
| 2 | Không có `_shared.md` — cross-cutting concerns rải rác | Không có SSOT cho state variables, error handling, atomic write |
| 3 | `phase1-engine.md` 870 dòng — gộp 6 bước khác nhau | Session init, ISG, partition, dispatch, aggregate, verify dồn 1 file |
| 4 | Error codes phẳng, không namespace | Khó trace nguồn gốc lỗi |
| 5 | POST-GATE không uniform | Mỗi procedure define khác nhau |
| 6 | Thiếu Phase Routing Map | Không thấy flow giữa các procedure |
| 7 | 17 procedure files rải rác, nhiều "mini file" | session-dir, lock, bash-delegation, agent-dispatch, workload-gate... |
| 8 | Không có phase subdirectories | Output nằm phẳng trong `$SESSION_DIR/` |
| 9 | Không có báo cáo từng phase + agent | Không biết từng bước/agent kết quả ra sao |
| 10 | CI tools dùng ad-hoc, không systemized | GitNexus/Serena không được tích hợp nhất quán qua mọi phase |

### 1.2 Yêu cầu thiết kế lại

**Từ người dùng (wf-fix-bugs-idea.md):**
1. SKILL.md **chỉ chứa**: overview, arguments, phase routing map, condensed summaries, output files, error lookup. **KHÔNG chứa code thực thi**
2. 7 Phase tuần tự (1→7): Init → Scan → Plan → Find Bugs → Triage → Execute → Verify
3. Mỗi Phase có báo cáo: `Phase1-report.md` → `Phase7-report.md`
4. Phase 4 (Find Bugs) mỗi Agent có báo cáo: `QD1-functional-report.md` → `QD11-report.md`
5. Thư mục tổ chức theo Phase subdirectories
6. Song song tối đa 10 Agent trong Phase 4
7. Luôn hỗ trợ `--resume` tại mọi phase
8. Templates cho **mọi** file output
9. Kế thừa kết quả Phase trước — không đoán

**Bổ sung từ người dùng (2026-05-12):**
10. **CI-First:** Tận dụng GitNexus + Serena tối đa trong mọi phase qua Protocol 20
11. **Playwright:** Mặc định chạy headless (ẩn). Có flag `--show-browser` để chạy visible
12. **Mobile:** Hỗ trợ test & fix app giao diện trên điện thoại qua Playwright device emulation

### 1.3 Mục tiêu

- **Gọn:** 9 procedure files (8 phase + resume-status), SKILL.md ~350 dòng
- **Rõ:** Mỗi phase self-contained: PRE-GATE → INPUT → OUTPUT → Steps → POST-GATE (T1-T4) → Phase Report → Next Phase
- **Có tổ chức:** Phase subdirectories, mỗi phase có báo cáo riêng, mỗi agent có report
- **CI-First:** Mọi phase dùng GitNexus/Serena qua CI-ROUTE matrix (Protocol 20 §20.5), graceful degradation Grep/Glob
- **Chuẩn MCV3:** Tuân thủ CORE rules + Protocols + Template Usage Rule + Atomic Write + CDG
- **Vận hành được:** Doanh nghiệp đọc hiểu flow, AI đọc hiểu context

---

## 2. Kiến Trúc Tổng Quan

### 2.1 Cấu trúc thư mục skill

```
wf-fix-bugs/
├── SKILL.md                       # Lean routing hub (~350 dòng, KHÔNG code)
├── _contract.json                 # Procedure paths + output paths + templates
├── procedures/
│   ├── _shared.md                 # Cross-cutting SSOT (16 sections)
│   ├── phase1-init.md             # Entry, flags, CI PRE-GATE, CDG, session init
│   ├── phase2-scan.md             # Scan code + docs + CI tools → context
│   ├── phase3-plan.md             # ISG → partition → workloads → dispatch plan
│   ├── phase4-find-bugs.md        # Lane dispatch PARALLEL max 10 → signals
│   ├── phase5-triage.md           # Aggregate + dedup + triage + CDG + safety
│   ├── phase6-execute.md          # Execute spawn → fix + docs + verify
│   ├── phase7-verify.md           # CQG + summaries + fix-impact + completion
│   └── resume-status.md           # --resume & --status handlers
├── templates/                     # Templates cho MỌI output file (30+ files)
│   ├── phase1-init/               # fix-status.json, Phase1-report.md
│   ├── phase2-scan/               # scope-analysis.json, code-inventory.json, ...
│   ├── phase3-plan/               # work-plan.json, dimension-plan.json, ...
│   ├── phase4-find-bugs/          # lane-signals.json, lane-status.json, QD-report.md, ...
│   ├── phase5-triage/             # issue-registry.json, bug-triage.md, fix-plan.md, ...
│   ├── phase6-execute/            # fix-report.md, docs-sync-report.json, ...
│   ├── phase7-verify/             # orchestrator-summary.md, fix-impact.json, ...
│   └── _common/                   # session-log.json, error-ledger.json
├── prompts/                       # LLM probe prompts (giữ nguyên, bổ sung mobile)
└── evals/                         # Evals + regression tests (giữ nguyên, bổ sung)
```

### 2.2 Session directory structure

```
$SESSION_DIR/                              # .mc-data/work/wf-fix-bugs/sessions/{SESSION_ID}/
├── fix-status.json                        # SSOT phase state
├── session-log.json                       # Execution trace (CORE-026)
├── error-ledger.json                      # Error tracking
├── .lock                                  # Session lock
│
├── phase1-init/
│   └── Phase1-report.md
│
├── phase2-scan/
│   ├── Phase2-report.md
│   ├── scope-analysis.json
│   ├── code-inventory.json
│   └── doc-inventory.json
│
├── phase3-plan/
│   ├── Phase3-report.md
│   ├── work-plan.json
│   ├── dimension-plan.json
│   └── workloads/
│       └── W{N}/fix-workload.json
│
├── phase4-find-bugs/
│   ├── Phase4-report.md
│   ├── lanes/
│   │   └── QD{n}-{name}/
│   │       ├── static-scan/signals.json    # 1 file = 1 writer contract
│   │       ├── runtime/signals.json
│   │       ├── llm-scan/signals.json       # opt-in (--llm-scan)
│   │       ├── lane-status.json
│   │       └── QD{n}-{name}-report.md      # Agent báo cáo riêng
│   └── probe-failures.log
│
├── phase5-triage/
│   ├── Phase5-report.md
│   ├── issue-registry.json
│   ├── bug-triage.md
│   ├── fix-plan.md
│   ├── fix-log.json
│   ├── cdg-tokens.json
│   ├── safety-check.json
│   ├── process-violations.json
│   └── coverage-report.md
│
├── phase6-execute/
│   ├── Phase6-report.md
│   ├── fix-report.md
│   └── docs-sync-report.json
│
└── phase7-verify/
    ├── Phase7-report.md
    ├── orchestrator-summary.md
    ├── fix-impact.json
    └── phase-summary.md
```

### 2.3 Số lượng so sánh

| Thành phần | v9.2.0 (hiện tại) | v10.0 (thiết kế) |
|-----------|-------------------|-------------------|
| Procedure files | 17 | **9** (8 phase + resume-status) |
| Phases | Ẩn (inline + rải rác) | **7 phase (1→7)** |
| SKILL.md dòng | ~730 | **~350** |
| Error code ranges | Phẳng (35+ codes) | **10 namespace (50+ codes)** |
| Templates | 1 (`fix-impact.json`) | **30+** (mọi output) |
| Phase reports | 1 (`phase-summary.md`) | **7** (1 per phase) |
| Agent reports | 0 | **11** (QD1-QD11) |
| CI integration | Ad-hoc per phase | **CI-first qua Protocol 20** (mọi phase) |
| Playwright modes | Headless only | **Headless (default) + --show-browser + --mobile** |

### 2.4 Pipeline State Machine

```
START
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Phase 1: Init                                                     │
│   Parse flags → Flag dispatch (--status/--resume/--migrate)      │
│   Deprecation BLOCK → CI PRE-GATE (Na/Nb/Nc)                     │
│   Browser/Scope/Cost CDG → QD9/10/11 Recommendation              │
│   Sub-skill path validation → Session init (dir + lock)           │
│   Profile → dimensions → TodoWrite init                          │
│   Output: fix-status.json, Phase1-report.md                      │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Phase 2: Scan Scope                                               │
│   CI-ROUTE: project_structure → understand_flow                   │
│   Scan code (inventory, structure, dependencies)                 │
│   Scan docs (.mc-data/docs/ nếu có)                               │
│   interface_type detection (web / mobile / api-only / hybrid)    │
│   CI context injection cho Phase 3 planning                      │
│   Output: scope-analysis.json, code/doc inventories,             │
│           Phase2-report.md                                       │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Phase 3: Plan                                                     │
│   ISG Recommender → dimensions                                   │
│   Partition planner → workloads                                  │
│   Workload Gate (dead_zone <0.8 / warn 0.8-1.5 / block >1.5)    │
│   Agent Dispatch Threshold (inline vs agent_dispatch)            │
│   Playwright planning: nếu web/mobile interface → reserve slot   │
│   Output: work-plan.json, workloads/W*/fix-workload.json,        │
│           dimension-plan.json, Phase3-report.md                  │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Phase 4: Find Bugs (PARALLEL, max 10 agents)                     │
│   Static probes per dimension → static-scan/signals.json         │
│   Runtime probes per dimension → runtime/signals.json            │
│     ├── Playwright headless (default) → browser probes           │
│     ├── --show-browser → Playwright visible                      │
│     └── --mobile → Playwright device emulation                   │
│   LLM probes (opt-in) → llm-scan/signals.json                    │
│   Mỗi Agent tạo QD-report.md riêng                               │
│   Playwright SEQUENTIAL across lanes (1 instance global)          │
│   Output: lanes/QD*/.../signals.json, QD*-report.md,             │
│           Phase4-report.md                                       │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Phase 5: Classify & Triage                                        │
│   Signal aggregation → issue-registry.json                       │
│   CORE-029 spot-check                                            │
│   Process integrity check (C1-C5) → process-violations.json      │
│   Spawn wf-fix-triage → bug-triage.md, fix-plan.md               │
│   CDG Pre-Execute Handoff                                        │
│   Safety Check (CORE-020)                                        │
│   Early exit: N=0 → E005 → jump Phase 7                          │
│   Output: issue-registry.json, bug-triage.md,                    │
│           fix-plan.md, cdg-tokens.json, Phase5-report.md         │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Phase 6: Execute Fix                                              │
│   CI-ROUTE: impact_analysis before edits                         │
│   Spawn wf-fix-execute → fix + docs + verify                     │
│   Dry-run: skip fix, chỉ preview                                 │
│   Output: fix-report.md, docs-sync-report.json,                  │
│           Phase6-report.md                                       │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Phase 7: Verify & Report                                          │
│   CQG-1 Numeric Metric Verification                              │
│   CQG-2 Browser + Integration Gate                               │
│   orchestrator-summary.md (CORE-028)                             │
│   fix-impact.json (cross-skill artifact)                         │
│   Completion display + next step suggestions                     │
│   Output: orchestrator-summary.md, fix-impact.json,              │
│           Phase7-report.md                                       │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
DONE → /wf-verify-sync hoặc /status
```

### 2.5 Phase Routing Map

| # | Phase | Procedure File | Điều kiện | Mode | Agent Count |
|---|-------|---------------|-----------|------|-------------|
| 1 | Init | `phase1-init.md` | Always | SEQUENTIAL — flags → CDG → CI PRE-GATE → session | 0 |
| 2 | Scan Scope | `phase2-scan.md` | Phase 1 POST-GATE pass | HYBRID — bash scripts + CI-ROUTE tools | 0 |
| 3 | Plan | `phase3-plan.md` | Phase 2 POST-GATE pass | HYBRID — Python CLI + CDG (AskUserQuestion) | 0 |
| 4 | Find Bugs | `phase4-find-bugs.md` | Phase 3 POST-GATE pass | **PARALLEL** — max 10 lanes (Playwright SEQUENTIAL) | 0-10 |
| 5 | Classify & Triage | `phase5-triage.md` | Phase 4 POST-GATE pass (N>0) | Agent Delegation (inline hoặc agent_dispatch) | 1 (triage) |
| 6 | Execute Fix | `phase6-execute.md` | Phase 5 POST-GATE pass | Agent Delegation | 1 (execute) |
| 7 | Verify & Report | `phase7-verify.md` | Always (kể cả N=0 từ Phase 5) | SEQUENTIAL — CQG → summaries | 0 |

### 2.6 File cũ → File mới

| File cũ (17) | Hấp thụ vào |
|-------------|------------|
| `ci-pre-gate.md` | `_shared.md` §CI Detection Pattern |
| `session-dir.md` | `phase1-init.md` |
| `lock-management.md` | `_shared.md` §Lock/Heartbeat Pattern |
| `bash-delegation.md` | `_shared.md` §Bash Delegation Pattern |
| `step-verification.md` | `phase5-triage.md` §Step Verification |
| `process-integrity-check.md` | `phase5-triage.md` §Process Integrity |
| `workload-gate.md` | `phase3-plan.md` |
| `agent-dispatch.md` | `phase3-plan.md` |
| `cdg-handoff.md` | `phase5-triage.md` |
| `phase1-engine.md` | `phase1-init.md` + `phase2-scan.md` + `phase3-plan.md` + `phase4-find-bugs.md` + `phase5-triage.md` |
| `phase2-triage.md` | `phase5-triage.md` |
| `phase3-execute.md` | `phase6-execute.md` |
| `post-gate-completion.md` | `phase7-verify.md` |
| `status-display.md` | `resume-status.md` |
| `resume-routing.md` | `resume-status.md` |
| `examples.md` | SKILL.md (ví dụ ngắn gọn) |

---

## 3. `_shared.md` — Cross-Cutting SSOT

File nền tảng được tham chiếu bởi mọi phase. Cấu trúc theo chuẩn wf-legacy-scan v5.0.1.

### 3.1 16 Sections

| § | Tên | Nội dung |
|---|-----|---------|
| §1 | State Variables Glossary | Mọi biến: tên, set bởi phase, đọc bởi phase, mô tả |
| §2 | Cross-Phase Data Flow | Data flow diagram giữa 7 phase |
| §3 | Atomic Write Pattern | `jq edit > tmp && mv tmp target` cho shared state files |
| §4 | Error Handling Canonical | SSOT cho tất cả error codes + 10 namespace ranges |
| §5 | Auto-Fix & Escalation Protocol | Retry budget per-phase (max 3), escalation format |
| §6 | On Failure Standard Format | APPEND error-ledger → auto-fix → escalate → STOP |
| §7 | Execution Trace (CORE-026) | START/COMPLETE/FAIL/CHECKPOINT — dual-write |
| §8 | Phase Summary (CORE-028) | Tiếng Việt ≤15 dòng cho mỗi phase report |
| §9 | Context & Checkpoint | Ngưỡng 65/80/90% + quy trình checkpoint |
| §10 | Template Usage Rule (CORE-031) | READ→POPULATE→WRITE, 3 placeholder patterns |
| §11 | Task Planning (Protocol 9) | TodoWrite init 7 items + update pattern |
| §12 | **CI Detection Pattern (Protocol 20)** | CI PRE-GATE Na/Nb/Nc + CI-ROUTE matrix + Agent context injection |
| §13 | Lock/Heartbeat Pattern | acquire_lock + start_heartbeat_daemon + cleanup trap |
| §14 | Bash Delegation Pattern | CLI invocation: `cd _shared && python -m <module>` |
| §15 | Agent Prompt Templates | Prompt template cho triage + execute + lane agent spawn |
| §16 | Session Isolation Protocol | SESSION_DIR structure, phase subdirectories, naming |
| §17 | **Playwright Integration Pattern** | Headless/visible/mobile modes, session isolation, SEQUENTIAL scheduling |

### 3.2 State Variables Glossary (trích)

| Variable | Set by Phase | Read by Phase | Description |
|----------|-------------|---------------|-------------|
| `$SESSION_ID` | 1 | All | `YYYY-MM-DD-{scope}-{slug}-{NN}` |
| `$SESSION_DIR` | 1 | All | `.mc-data/work/wf-fix-bugs/sessions/$SESSION_ID` |
| `$PROFILE` | 1 | 2-7 | `quick` / `standard` / `deep` / `exhaustive` |
| `$DIMS_ARRAY` | 1 | 2-7 | Array QD1..QD11 |
| `$SCOPE` | 1 | 2-4 | `all` / `system` / `module` |
| `$NAME` | 1 | 2-3 | Scope target ID |
| `$LEGACY_MODE` | 1 | 2-6 | Boolean — CORE-021 |
| `$LLM_SCAN` | 1 | 3-5 | Boolean — `--llm-scan` |
| `$DRY_RUN` | 1 | 5-6 | Boolean — `--dry-run` |
| `$SHOW_BROWSER` | 1 | 4 | Boolean — `--show-browser` |
| `$MOBILE_MODE` | 1 | 2,4,7 | Boolean — `--mobile` |
| `$GITNEXUS_AVAILABLE` | 1 (CI PRE-GATE) | 2-7 | Boolean — Protocol 20 |
| `$SERENA_AVAILABLE` | 1 (CI PRE-GATE) | 2-7 | Boolean — Protocol 20 |
| `$CI_CONTEXT` | 1 (CI PRE-GATE) | 2,5,6 | CI context string cho sub-skill spawn |
| `$INTERFACE_TYPE` | 2 | 3-7 | `web` / `mobile` / `api-only` / `hybrid` |
| `$TOTAL_ISSUES` | 5 | 6-7 | Integer — từ `issue-registry.json` |
| `$EXECUTION_MODE` | 3 | 5-6 | `inline` / `agent_dispatch` |
| `$SCOPE_INVENTORY` | 2 | 3 | Code + doc inventory results |

### 3.3 Error Code Namespace

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

| Code | Severity | Tình huống | Xử lý | Phase |
|------|---------|-----------|-------|-------|
| E001 | high | POST-GATE fail sau 3 retries | DỪNG, escalate | All |
| E002 | medium | User từ chối tiếp tục (CDG reject) | Checkpoint, `--resume` | 3,5,7 |
| E003 | high | Registry thiếu/rỗng | STOP — chạy `/wf-brainstorm` trước | 1 |
| E004 | high | Sub-skill SKILL.md không tồn tại | Báo lỗi path, dừng | 1 |
| E005 | info | N=0 issues sau Phase 5 | "Healthy!" → jump Phase 7 | 5 |
| E009 | high | Context > 90% | FORCE checkpoint, STOP | All |
| E010 | medium | `--status` dispatched | Hiển thị status → STOP | 1 |
| E011 | medium | `--resume` dispatched | Enter resume path | 1 |
| E012 | medium | `--migrate` dispatched | Delegate migration script | 1 |
| E013 | high | Deprecation block (legacy v6.x) | CDG render, escape hatch | 1 |
| E014 | high | CI detection fail | Graceful degrade → Grep/Glob fallback | 1 |
| E015 | high | CI tools unavailable + non-git project | Skip CI, dùng Grep/Glob | 1 |
| E020 | medium | Code scan empty (0 files) | WARN, continue với docs-only | 2 |
| E021 | low | Doc scan empty (0 docs) | INFO, continue | 2 |
| E022 | high | CI tools stale >20 commits | WARN, continue với Grep fallback | 2 |
| E023 | low | interface_type undetectable | Default `web`, WARN | 2 |
| E030 | medium | Profile resolve fail | Fallback profile=standard | 3 |
| E031 | high | Lock acquire fail | STOP — process khác active | 3 |
| E032 | high | Partition planner fail | Auto-generate fallback | 3 |
| E033 | high | Workload Gate aborted | UPDATE fix-status, hướng dẫn resume | 3 |
| E040 | high | Lane dispatch static probe fail | Retry x3, escalate | 4 |
| E041 | medium | Non-static probe fail | Record → probe-failures.log | 4 |
| E042 | medium | LLM probe fail | Record → probe-failures.log | 4 |
| E043 | medium | Agent report missing (sau spawn) | WARN, generate stub | 4 |
| E044 | high | Playwright launch fail | Retry x2, escalate nếu vẫn fail | 4 |
| E045 | medium | Mobile device emulation not supported | WARN, fallback desktop viewport | 4 |
| E050 | high | Aggregator fail | Retry x3, escalate | 5 |
| E051 | high | Step verification fail (sau 3 retries) | CDG render | 5 |
| E052 | medium | Process violation detected | Ghi violation, evaluate severity | 5 |
| E053 | high | Triage spawn fail | Re-spawn x1, escalate | 5 |
| E054 | high | CDG Rejected Critical | Quay lại triage, anti-loop guard | 5 |
| E055 | high | Safety Check blockers | CDG render, reject 2 lần → ESCALATE | 5 |
| E060 | high | Execute spawn fail | Re-spawn x1, escalate | 6 |
| E061 | high | Fix report missing/broken | Retry, escalate | 6 |
| E070 | high | CQG-1 numeric mismatch | Retry up to 3 → E001 | 7 |
| E071 | high | CQG-2 browser/integration gate | CDG render, max 2 reject → E001 | 7 |
| E090 | info | Browser CDG: user dừng | DỪNG — hướng dẫn start dev server | 1 |
| E091 | info | Scope CDG: user thu hẹp | DỪNG — hướng dẫn re-run | 1 |
| E092 | info | Cost CDG: user hạ profile | DỪNG — hướng dẫn re-run | 1 |
| E093 | info | Mobile CDG: user chọn devices | Ghi nhận, pass to Phase 4 | 1 |
| E100 | low | QD9/QD10/QD11 recommendation warned | LOG warning, continue | 1 |
| E_LEGACY_BLOCK | fatal | Legacy v6.x paths | Exit 78 | 1 |
| EDLG | high | Sub-skill không hoàn thành | LOG error, FAIL trace | 5,6 |

---

## 4. Chi Tiết Từng Phase

### 4.1 Phase 1: Init

**File:** `procedures/phase1-init.md`
**Mode:** SEQUENTIAL
**Mục đích:** Parse flags, validate environment, CI PRE-GATE (Protocol 20), CDG gates, khởi tạo session, resolve profile → dimensions.

**PRE-GATE:**
```
test -f .claude/scripts/wf-fix-common.sh
```

**INPUT:**
- Tất cả CLI arguments (`$ARGUMENTS`)
- `req-registry.json` (kiểm tra tồn tại)
- Source code directories (`src/` hoặc `apps/`)

**OUTPUT:**
- `$SESSION_DIR/fix-status.json` — SSOT phase state (từ template)
- `$SESSION_DIR/.lock` + heartbeat daemon
- `$SESSION_DIR/session-log.json` + `error-ledger.json`
- `$SESSION_DIR/phase1-init/Phase1-report.md`
- `.mc-data/work/wf-fix-bugs/_index/sessions.jsonl` — APPEND
- In-memory: `$SESSION_ID`, `$DIMS_ARRAY`, `$PROFILE`, `$SCOPE`, `$LEGACY_MODE`, `$CI_CONTEXT`, `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$SHOW_BROWSER`, `$MOBILE_MODE`

**Steps:**

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.0 | **Source helpers:** `source .claude/scripts/wf-fix-common.sh` + register cleanup trap | Bash | Functions available |
| 1.1 | **Parse flags:** Tất cả CLI arguments → in-memory variables | Bash | All flags parsed |
| 1.2 | **Flag dispatch:** `--status` → route `resume-status.md` §Status → STOP. `--resume` → route `resume-status.md` §Resume. `--migrate` → delegate script → STOP. | Read | Dispatched or continue |
| 1.3 | **Deprecation BLOCK:** `bash .claude/scripts/wf-fix-deprecation-block.sh` | Bash | Legacy check pass |
| 1.4 | **CI PRE-GATE Na — Load CI Capabilities (Protocol 20 §20.8):** `bash .claude/scripts/ci-detect.sh` → check per-tool TTL. IF `needs_scan` → MCP detect GitNexus + Serena → `ci-detect.sh --write-cache`. Set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Graceful: lock held → fallback Grep/Glob. | Bash + MCP | CI flags set |
| 1.5 | **CI PRE-GATE Nb — Index Freshness Check:** `bash .claude/scripts/ci-freshness-check.sh` → compare HEAD vs index_commit. Parse 4 mức (ok/light/strong/severe). | Bash | Freshness status set |
| 1.6 | **CI PRE-GATE Nc — Agent Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → auto-select 1 of 4 templates → inject vào CI_CONTEXT. | Bash | CI context ready |
| 1.7 | **PRE-GATE validation:** `bash .claude/scripts/wf-fix-phase0-init.sh` → export `$LEGACY_MODE`, `$DEPRECATED_MODULES` | Bash | Registry + code validated |
| 1.8 | **Flag conflict detection:** `--deep` + `--no-browser` → WARN; `--llm-scan` + profile not deep/exhaustive → WARN; `--mobile` → auto-set `--show-browser` (mobile test requires visible inspection) | — | Conflicts logged |
| 1.9 | **Browser CDG (E090):** Nếu QD9 trong dims + interface_type ≠ api-only → kiểm tra BASE_URL → AskUserQuestion | AskUserQuestion | Decision recorded |
| 1.10 | **Scope CDG (E091):** Nếu scope=all + module_count > 20 → AskUserQuestion | AskUserQuestion | Decision recorded |
| 1.11 | **Cost CDG (E092):** Nếu cost over threshold → AskUserQuestion | AskUserQuestion | Decision recorded |
| 1.12 | **Mobile CDG (E093):** Nếu `--mobile` → AskUserQuestion chọn devices (iPhone 14 / Pixel 7 / iPad / all) | AskUserQuestion | Mobile devices selected |
| 1.13 | **QD9/QD10/QD11 Recommendation Gate (E100):** Nếu recommended nhưng không trong dims → AskUserQuestion | AskUserQuestion | Decision recorded |
| 1.14 | **Sub-skill path validation:** Kiểm tra 13 SKILL.md paths (triage + execute + 11 lane skills) | Read | All paths exist |
| 1.15 | **Generate SESSION_ID** + tạo `$SESSION_DIR` với tất cả phase subdirectories | Bash | Dirs exist |
| 1.16 | **Acquire lock** + **Start heartbeat daemon** | Bash | Lock + heartbeat active |
| 1.17 | **Append session index:** `append_session_index` → `sessions.jsonl` | Bash | Entry appended |
| 1.18 | **Profile → dimensions:** Run `profile_resolver.py` → `$DIMS_ARRAY` | Bash (Python CLI) | DIMS_ARRAY non-empty |
| 1.19 | **[CORE-031]** READ `templates/phase1-init/fix-status.json` → POPULATE → WRITE (Atomic Write) | Write | File valid |
| 1.20 | Init `session-log.json` + `error-ledger.json` từ templates | Write | Files exist |
| 1.21 | **[CORE-028]** Tạo `phase1-init/Phase1-report.md` từ template | Write | Report written |
| 1.22 | **[TRACE START]** Append START event → `session-log.json` (dual-write: global + session) | Bash | Event appended |
| 1.23 | **TodoWrite init:** 7 items (Phase 1-7). Mark Phase 1 = in_progress | TodoWrite | 7 todos created |

**POST-GATE (T1-T4):**
```
T1: test -s "$SESSION_DIR/fix-status.json"
T2: jq -e '.session_id and .phases' "$SESSION_DIR/fix-status.json"
T3: test -f "$SESSION_DIR/.lock"
T4: jq -e '.dimensions | length > 0' "$SESSION_DIR/fix-status.json"
```

**Phase Report (`Phase1-report.md`):**
- Session ID, scope, profile, dimensions đã chọn
- CI tools status (GitNexus: ✓/✗, Serena: ✓/✗, freshness level)
- Playwright config (headless/visible, mobile devices nếu có)
- Các CDG decisions (Browser/Scope/Cost/Mobile)

**On Failure:** E003 → STOP. E004 → STOP. E013 → CDG render. E014 → Graceful degrade. E031 → STOP.

**Next Phase:** Phase 2 (`phase2-scan.md`)

---

### 4.2 Phase 2: Scan Scope

**File:** `procedures/phase2-scan.md`
**Mode:** HYBRID — bash scripts + CI-ROUTE tools (Protocol 20 §20.5)
**Mục đích:** Scan và phân tích phạm vi công việc. Quét code + tài liệu để tạo context cho Phase 3 Planning. Phát hiện interface_type.

**PRE-GATE:**
```
Phase 1 POST-GATE pass
test -s "$SESSION_DIR/fix-status.json"
```

**INPUT:**
- `$SESSION_DIR/fix-status.json` (từ Phase 1)
- `$SCOPE`, `$NAME`, `$DIMS_ARRAY`, `$PROFILE`, `$CI_CONTEXT`
- `req-registry.json` (nếu tồn tại)
- `.mc-data/docs/` (nếu có)

**OUTPUT:**
- `$SESSION_DIR/phase2-scan/scope-analysis.json` (từ template)
- `$SESSION_DIR/phase2-scan/code-inventory.json` (từ template)
- `$SESSION_DIR/phase2-scan/doc-inventory.json` (từ template)
- `$SESSION_DIR/phase2-scan/Phase2-report.md` (CORE-028)
- In-memory: `$INTERFACE_TYPE`, `$SCOPE_INVENTORY`

**CI-ROUTE cho Phase 2 (Protocol 20 §20.5):**

| CI Task | Primary Tool | Secondary | Fallback |
|---------|-------------|-----------|----------|
| `project_structure` | **Serena** `onboarding` | **GitNexus** `clusters` | Glob |
| `understand_flow` | **GitNexus** `query({key_concept})` | **Serena** `get_symbols_overview` | Grep + Read |
| `api_routes` | **GitNexus** `route_map()` | — | Grep |
| `find_by_annotation` | **GitNexus** `cypher` + **Serena** `find_refs` | — | Grep REQ-ID |
| `symbol_overview` | **Serena** `get_symbols_overview` | — | Read |

**Steps:**

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | **PRE-GATE:** Read Phase 1 output → verify `fix-status.json.phase1 = completed` | Read | Phase 1 done |
| 2.2 | **Interface type detection:** Scan code structure → detect `web` / `mobile` / `api-only` / `hybrid`. Mobile detection: check `mobile/` dir, React Native, Flutter, Capacitor, Expo, Swift/Kotlin. | CI-ROUTE + Grep | `$INTERFACE_TYPE` set |
| 2.3 | **Code inventory:** Enumerate source files, modules, dependencies theo scope. Dùng CI-ROUTE: `project_structure` → Serena onboarding + GitNexus clusters. | CI-ROUTE + Bash | `code-inventory.json` valid |
| 2.4 | **Doc inventory:** Scan `.mc-data/docs/`, `docs/`, specs, README. Dùng CI-ROUTE: `find_by_annotation` → REQ-ID locations. | CI-ROUTE + Bash | `doc-inventory.json` valid |
| 2.5 | **Scope analysis:** Xác định phạm vi chính xác — modules, files, LOC, dependency count. Dùng CI-ROUTE: `understand_flow` → key concepts. | CI-ROUTE + Bash | `scope-analysis.json` valid |
| 2.6 | **[TRACE CHECKPOINT]** Append CHECKPOINT event → `session-log.json` | Bash | Event appended |
| 2.7 | **[CORE-028]** Tạo `phase2-scan/Phase2-report.md` từ template | Write | Report written |
| 2.8 | **[TRACE COMPLETE]** Append COMPLETE event | Bash | Event appended |

**POST-GATE (T1-T4):**
```
T1: test -s "$SESSION_DIR/phase2-scan/scope-analysis.json"
T2: jq -e '.modules and .total_files' "$SESSION_DIR/phase2-scan/scope-analysis.json"
T3: test -s "$SESSION_DIR/phase2-scan/code-inventory.json"
T4: jq -e '.interface_type' "$SESSION_DIR/phase2-scan/scope-analysis.json"
```

**Phase Report (`Phase2-report.md`):**
- Interface type detected (web/mobile/api-only/hybrid)
- Code inventory summary (modules, files, LOC, languages)
- Doc inventory summary (available docs, phases present)
- CI tools used (GitNexus tasks, Serena tasks, fallback count)

**On Failure:** E020 (code empty) → WARN, continue. E022 (CI stale) → WARN, Grep fallback.

**Next Phase:** Phase 3 (`phase3-plan.md`)

---

### 4.3 Phase 3: Plan

**File:** `procedures/phase3-plan.md`
**Mode:** HYBRID — Python CLI + CDG (AskUserQuestion)
**Mục đích:** ISG Recommender → dimensions → partition planner → workloads → workload gate → dispatch plan.

**PRE-GATE:**
```
Phase 2 POST-GATE pass
test -s "$SESSION_DIR/phase2-scan/scope-analysis.json"
```

**INPUT:**
- `$SESSION_DIR/fix-status.json` + Phase 2 outputs
- `$DIMS_ARRAY`, `$PROFILE`, `$SCOPE`, `$INTERFACE_TYPE`, `$MOBILE_MODE`

**OUTPUT:**
- `$SESSION_DIR/phase3-plan/work-plan.json` (từ template)
- `$SESSION_DIR/phase3-plan/dimension-plan.json` (từ template)
- `$SESSION_DIR/phase3-plan/workloads/W{N}/fix-workload.json` (từ template)
- `$SESSION_DIR/phase3-plan/Phase3-report.md`

**Steps:**

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | **PRE-GATE:** Read Phase 2 outputs + verify `fix-status.json.phase2 = completed` | Read | Phase 2 done |
| 3.2 | **ISG Recommender:** Run `python -m isg --session-dir="$SESSION_DIR" --dims="$DIMS_ARRAY" --profile="$PROFILE"` → refined dimensions + weights | Bash (Python CLI) | ISG output valid |
| 3.3 | **Partition planner:** Run `python -m partition --session-dir="$SESSION_DIR" --inventory="$SCOPE_INVENTORY"` → workloads | Bash (Python CLI) | Workloads generated |
| 3.4 | **Workload Gate:** Calculate workload ratio. Nếu >1.5 → CDG-11 (AskUserQuestion: options A/B/C/D). Nếu 0.8-1.5 → WARN + continue. Nếu <0.8 → continue. | Bash + AskUserQuestion | Gate decision |
| 3.5 | **Agent Dispatch Threshold:** IF total_issues_est > 200 OR context > 70% → `$EXECUTION_MODE = agent_dispatch`. ELSE → `$EXECUTION_MODE = inline`. | Bash | Mode set |
| 3.6 | **Playwright planning:** IF `$INTERFACE_TYPE ∈ {web, mobile, hybrid}` AND QD5/QD7/QD9 in dims → reserve 1 Playwright slot. Mobile devices from Phase 1 E093. | Bash | Playwright plan ready |
| 3.7 | **Dimension → lane routing:** Map mỗi dimension → sub-skill path + agent type + probe count. Respect CORE-025 (parallel safety). | Bash | Routing table valid |
| 3.8 | **[CORE-031]** WRITE `work-plan.json`, `dimension-plan.json`, `workloads/W{N}/fix-workload.json` từ templates | Write | All files valid |
| 3.9 | **[CORE-028]** Tạo `phase3-plan/Phase3-report.md` từ template | Write | Report written |
| 3.10 | **[TRACE COMPLETE]** Append COMPLETE event | Bash | Event appended |

**POST-GATE (T1-T4):**
```
T1: test -s "$SESSION_DIR/phase3-plan/work-plan.json"
T2: jq -e '.phases and .dimensions' "$SESSION_DIR/phase3-plan/work-plan.json"
T3: test $(ls "$SESSION_DIR/phase3-plan/workloads/"W*/fix-workload.json 2>/dev/null | wc -l) -gt 0
T4: jq -e '.dimensions | length > 0' "$SESSION_DIR/phase3-plan/dimension-plan.json"
```

**Phase Report (`Phase3-report.md`):**
- Dimensions selected + weights
- Workload partition (N workloads, estimated issues)
- Workload Gate decision (ratio, user choice)
- Execution mode (inline vs agent_dispatch)
- Playwright plan (nếu applicable)

**On Failure:** E030 → Fallback profile=standard. E032 → Auto-generate fallback. E033 → CDG render.

**Next Phase:** Phase 4 (`phase4-find-bugs.md`)

---

### 4.4 Phase 4: Find Bugs

**File:** `procedures/phase4-find-bugs.md`
**Mode:** **PARALLEL** — max 10 agents (Playwright SEQUENTIAL across lanes)
**Mục đích:** Dispatch lane agents để tìm bugs qua static + runtime + LLM probes.

**PRE-GATE:**
```
Phase 3 POST-GATE pass
test -s "$SESSION_DIR/phase3-plan/dimension-plan.json"
```

**INPUT:**
- `$SESSION_DIR/fix-status.json` + Phase 3 outputs
- `$DIMS_ARRAY`, `$PROFILE`, `$EXECUTION_MODE`, `$CI_CONTEXT`
- `$SHOW_BROWSER`, `$MOBILE_MODE`

**OUTPUT (per dimension QD{n}):**
- `lanes/QD{n}-{name}/static-scan/signals.json`
- `lanes/QD{n}-{name}/runtime/signals.json` (nếu có non-static probes)
- `lanes/QD{n}-{name}/llm-scan/signals.json` (nếu `--llm-scan`)
- `lanes/QD{n}-{name}/lane-status.json`
- `lanes/QD{n}-{name}/QD{n}-{name}-report.md` — Agent báo cáo riêng
- `probe-failures.log` (nếu có probe fail)

**Signal Directory Structure (anti-overwrite):**
```
lanes/QD9-runtime-health/
├── static-scan/signals.json     ← writer: static probes only
├── runtime/signals.json         ← writer: runtime probes only (Playwright)
├── llm-scan/signals.json        ← writer: LLM probes only
├── lane-status.json
└── QD9-runtime-health-report.md
```

**Playwright Integration:**

| Mode | Flag | Behavior |
|------|------|----------|
| **Headless** (default) | — | Chromium headless, invisible. Session-isolated via `playwright-session.js`. |
| **Visible** | `--show-browser` | Chromium visible window. Dùng cho debug + user observation. |
| **Mobile** | `--mobile` | Playwright device emulation (iPhone 14, Pixel 7, iPad Pro). Auto-set `--show-browser`. |

Playwright chạy **SEQUENTIAL** across lanes (max 1 browser instance global). Thứ tự ưu tiên: QD9 (runtime-health) → QD5 (ux-a11y) → QD7 (compatibility) → others. Mobile apps tự động chạy với device emulation.

**Steps:**

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.1 | **PRE-GATE:** Read Phase 3 outputs + verify dimension plan | Read | Phase 3 done |
| 4.2 | **Prepare Playwright:** IF applicable → init `playwright-session.js` với `--headless` (default) hoặc `--headed` (nếu `--show-browser`). Mobile → device config. | Bash | Playwright ready |
| 4.3 | **Dispatch lanes PARALLEL:** Spawn max 10 Agent concurrently. Mỗi Agent: đọc sub-skill SKILL.md → chạy probes → emit signals → tạo QD-report.md. Playwright lanes SEQUENTIAL hóa (1 at a time). | Agent (max 10) | All lanes started |
| 4.4 | **Monitor progress:** Định kỳ check lane-status.json per dimension. | Read | Progress tracked |
| 4.5 | **Collect results:** Sau khi tất cả lanes complete → aggregate per-lane results. Check agent report existence (E043 nếu thiếu). | Read + Bash | All results collected |
| 4.6 | **[CORE-028]** Tạo `phase4-find-bugs/Phase4-report.md` — tổng hợp kết quả từ tất cả lanes | Write | Report written |
| 4.7 | **[TRACE COMPLETE]** Append COMPLETE event với metadata (signals per dim) | Bash | Event appended |

**Agent Prompt Template (cho lane agent):**

```
Bạn là lane agent cho dimension [{DIM_ID}] — {DIM_NAME}.
Đọc file .claude/skills/workflow/wf-fix-{dim-slug}/SKILL.md và thực thi đầy đủ.

Session directory: {SESSION_DIR}
Profile: {PROFILE}
Scope: {SCOPE} {NAME}

[CI CONTEXT]
{CI_CONTEXT}

[PLAYWRIGHT CONTEXT — nếu applicable]
- Mode: {headless | visible}
- Devices: {mobile devices nếu có}
- Base URL: {BASE_URL}
- Playwright session: playwright-session.js (session-isolated)

Quy tắc:
1. Chạy tất cả probes theo profile routing trong SKILL.md
2. Static probes → static-scan/signals.json
3. Runtime probes → runtime/signals.json (dùng Playwright nếu applicable)
4. LLM probes → llm-scan/signals.json
5. KHÔNG ghi đè signals của probe khác (1 file = 1 writer)
6. Sử dụng CI-ROUTE matrix (Protocol 20 §20.5) cho code analysis
7. Tạo {DIM_ID}-report.md báo cáo kết quả

Khi hoàn tất, cập nhật lane-status.json = "completed".
```

**POST-GATE (T1-T4):**
```
T1: jq -e '.lanes | length > 0' "$SESSION_DIR/fix-status.json"
T2: FOR each dim in DIMS_ARRAY: test -f "lanes/$dim/lane-status.json"
T3: FOR each dim: jq -e '.status == "completed" or .status == "skipped" or .status == "failed"' "lanes/$dim/lane-status.json"
T4: FOR each dim: test -f "lanes/$dim/QD*-report.md"
```

**Phase Report (`Phase4-report.md`):**
- Số lanes dispatched + completed
- Total signals found (per source: static/runtime/LLM)
- Signals breakdown by dimension
- Playwright execution log (nếu applicable)
- Probe failures (nếu có)

**On Failure:** E040 (static probe fail) → Retry x3. E041/E042 (non-static/LLM fail) → Log + continue. E044 (Playwright fail) → Retry x2, escalate.

**Next Phase:** Phase 5 (`phase5-triage.md`)

---

### 4.5 Phase 5: Classify & Triage

**File:** `procedures/phase5-triage.md`
**Mode:** Agent Delegation (inline hoặc agent_dispatch)
**Mục đích:** Aggregate signals → dedup → process integrity → spawn triage → CDG handoff → safety check.

**PRE-GATE:**
```
Phase 4 POST-GATE pass
Total signals collected (có thể = 0 → E005 jump Phase 7)
```

**INPUT:**
- Tất cả `lanes/QD*/{static-scan,runtime,llm-scan}/signals.json` (từ Phase 4)
- `$SESSION_DIR/fix-status.json` + Phase 3 work-plan

**OUTPUT:**
- `$SESSION_DIR/phase5-triage/issue-registry.json`
- `$SESSION_DIR/phase5-triage/bug-triage.md` (spawned agent)
- `$SESSION_DIR/phase5-triage/fix-plan.md` (spawned agent)
- `$SESSION_DIR/phase5-triage/fix-log.json`
- `$SESSION_DIR/phase5-triage/cdg-tokens.json`
- `$SESSION_DIR/phase5-triage/safety-check.json`
- `$SESSION_DIR/phase5-triage/process-violations.json`
- `$SESSION_DIR/phase5-triage/coverage-report.md`
- `$SESSION_DIR/phase5-triage/Phase5-report.md`

**Steps:**

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5.1 | **PRE-GATE:** Read Phase 4 outputs. Count total signals. IF N=0 → E005 → jump Phase 7. | Read + Bash | Signals counted |
| 5.2 | **Signal aggregation:** Run `python -m aggregate --session-dir="$SESSION_DIR"` → merge all lane signals → dedup (fingerprint collision) → `issue-registry.json` | Bash (Python CLI) | `issue-registry.json` valid |
| 5.3 | **[CORE-029] Spot-check:** Sample 3 random signals → verify schema compliance, fingerprint uniqueness, probe_id validity. | Bash | Spot-check pass |
| 5.4 | **Process integrity check (C1-C5):** Step completeness, empty result recording, signal overwrite detection, dimension execution completeness, cross-source consistency → `process-violations.json` | Bash | Integrity check done |
| 5.5 | **Evaluate violations:** IF critical violation → E029 hard-stop + CDG render. IF high → E029 warning + continue. | Bash | Severity evaluated |
| 5.6 | **Spawn wf-fix-triage:** Agent với CI context injection. Prompt: đọc `wf-fix-triage/SKILL.md` → classify severity + fixability → generate `bug-triage.md` + `fix-plan.md` + `fix-log.json`. | Agent (1) | Triage outputs valid |
| 5.7 | **POST-GATE (T1-T4):** Validate triage outputs. Nếu fail → E053 → re-spawn x1. | Read + Bash | POST-GATE pass |
| 5.8 | **CDG Pre-Execute Handoff:** Render fix-plan summary → AskUserQuestion: ACCEPT / REJECT / MODIFY. Anti-loop guard: REJECT 3 lần → ESCALATE. | AskUserQuestion | Decision recorded |
| 5.9 | **Safety Check (CORE-020):** 4 checks: collision detection, xref validation, uncommitted changes, deprecated modules. IF blockers → E055 → CDG render. | Bash | Safety pass |
| 5.10 | **Coverage report:** Generate coverage metrics (probes run / issues found / dimensions covered) | Bash | `coverage-report.md` written |
| 5.11 | **[CORE-028]** Tạo `phase5-triage/Phase5-report.md` | Write | Report written |
| 5.12 | **[TRACE COMPLETE]** Append COMPLETE event | Bash | Event appended |

**POST-GATE (T1-T4):**
```
T1: test -s "$SESSION_DIR/phase5-triage/issue-registry.json"
T2: jq -e '.issues and .total_issues' "$SESSION_DIR/phase5-triage/issue-registry.json"
T3: test -s "$SESSION_DIR/phase5-triage/bug-triage.md"
T4: test -s "$SESSION_DIR/phase5-triage/fix-plan.md"
```

**On Failure:** E050 → Retry x3. E053 → Re-spawn x1. E054 → Anti-loop. E055 → CDG render.

**Next Phase:** Phase 6 (`phase6-execute.md`) hoặc Phase 7 (nếu E005 hoặc N=0)

---

### 4.6 Phase 6: Execute Fix

**File:** `procedures/phase6-execute.md`
**Mode:** Agent Delegation
**Mục đích:** Spawn wf-fix-execute để thực hiện fix bugs theo fix-plan.md.

**PRE-GATE:**
```
Phase 5 POST-GATE pass
test -s "$SESSION_DIR/phase5-triage/fix-plan.md"
```

**INPUT:**
- `$SESSION_DIR/phase5-triage/issue-registry.json`
- `$SESSION_DIR/phase5-triage/bug-triage.md`
- `$SESSION_DIR/phase5-triage/fix-plan.md`
- `$DRY_RUN`, `$CI_CONTEXT`

**OUTPUT:**
- `$SESSION_DIR/phase6-execute/fix-report.md` (spawned agent)
- `$SESSION_DIR/phase6-execute/docs-sync-report.json` (spawned agent)
- `$SESSION_DIR/phase6-execute/Phase6-report.md`

**Steps:**

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 6.1 | **PRE-GATE:** Read Phase 5 outputs. IF `--dry-run` → skip execution, tạo preview. | Read | Phase 5 done |
| 6.2 | **Dry-run preview (nếu applicable):** Render fix plan summary → STOP (không sửa code). | — | Preview displayed |
| 6.3 | **CI-ROUTE: Pre-execution impact analysis:** For each fix target → `gitnexus_impact({target, direction: "upstream"})`. HIGH/CRITICAL risk → WARN user CDG. | GitNexus | Impact assessed |
| 6.4 | **Spawn wf-fix-execute:** Agent với CI context injection. Prompt: đọc `wf-fix-execute/SKILL.md` → execute fix → docs sync → verify. | Agent (1) | Execute complete |
| 6.5 | **POST-GATE (T1-T4):** Validate fix outputs. Nếu fail → E060 → re-spawn x1. | Read + Bash | POST-GATE pass |
| 6.6 | **[CORE-028]** Tạo `phase6-execute/Phase6-report.md` | Write | Report written |
| 6.7 | **[TRACE COMPLETE]** Append COMPLETE event | Bash | Event appended |

**POST-GATE (T1-T4):**
```
T1: test -s "$SESSION_DIR/phase6-execute/fix-report.md"
T2: grep -q "## " "$SESSION_DIR/phase6-execute/fix-report.md"
T3: test -s "$SESSION_DIR/phase6-execute/docs-sync-report.json"
T4: jq -e '.fixed_count >= 0' "$SESSION_DIR/phase6-execute/fix-report.md" (parse structured data)
```

**On Failure:** E060 → Re-spawn x1. E061 → Retry.

**Next Phase:** Phase 7 (`phase7-verify.md`)

---

### 4.7 Phase 7: Verify & Report

**File:** `procedures/phase7-verify.md`
**Mode:** SEQUENTIAL — CQG → summaries → impact → completion
**Mục đích:** Kiểm tra toàn bộ kết quả, tạo báo cáo tổng hợp, cross-skill artifact.

**PRE-GATE:**
```
Phase 6 POST-GATE pass (hoặc E005 từ Phase 5)
```

**INPUT:**
- Tất cả phase reports (Phase1-report.md → Phase6-report.md)
- `issue-registry.json`, `fix-plan.md`, `fix-report.md`
- `$MOBILE_MODE` (cho CQG-2 mobile gate)

**OUTPUT:**
- `$SESSION_DIR/phase7-verify/orchestrator-summary.md` (CORE-028)
- `$SESSION_DIR/phase7-verify/fix-impact.json` (cross-skill artifact)
- `$SESSION_DIR/phase7-verify/phase-summary.md`
- `$SESSION_DIR/phase7-verify/Phase7-report.md`
- `fix-status.json.phases.phase7.status = "completed"`

**Steps:**

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 7.1 | **PRE-GATE:** Verify all previous phases completed. IF E005 (N=0) → skip CQG, tạo "Healthy" summary. | Read | All done or E005 |
| 7.2 | **CQG-1 Numeric Metric Verification:** Compare fix-plan expected vs fix-report actual. Nếu mismatch >5% → E070 → retry up to 3. | Bash | Metrics match |
| 7.3 | **CQG-2 Browser + Integration Gate:** IF QD9 run → verify browser evidence. IF QD10 run → verify integration signals fixed. IF mobile → verify device coverage. Nếu fail → E071 → CDG render. | Read + Bash | CQG-2 pass |
| 7.4 | **Mobile Gate:** IF `--mobile` → verify mobile-specific signals được cover trong fix-report. | Read | Mobile coverage OK |
| 7.5 | **[CORE-028]** Generate `orchestrator-summary.md` — tiếng Việt, ≤40 dòng: tổng quan, signals found, bugs fixed, dimensions covered, next steps. | Write | Summary written |
| 7.6 | **Generate `fix-impact.json`:** Cross-skill artifact (schema fix-impact-v1) — fixed_count, dimensions_run, audit_chain checksum, CI tools used. | Write | fix-impact.json valid |
| 7.7 | **Generate `phase-summary.md`:** Accumulated summary từ 7 phase reports. | Write | Summary written |
| 7.8 | **[CORE-028]** Tạo `phase7-verify/Phase7-report.md` | Write | Report written |
| 7.9 | **Update fix-status.json:** Mark phase7 = completed, pipeline_status = DONE. | Write (Atomic) | Status updated |
| 7.10 | **[TRACE COMPLETE]** Append COMPLETE event → dual-write | Bash | Event appended |
| 7.11 | **TodoWrite:** Mark Phase 7 = completed. | TodoWrite | All 7 done |
| 7.12 | **Completion display:** Hiển thị summary + next step suggestions (`/wf-verify-sync`, `/status`) | — | Displayed |

**POST-GATE (T1-T4):**
```
T1: test -s "$SESSION_DIR/phase7-verify/orchestrator-summary.md"
T2: grep -q "## " "$SESSION_DIR/phase7-verify/orchestrator-summary.md"
T3: test -s "$SESSION_DIR/phase7-verify/fix-impact.json"
T4: jq -e '.phases.phase7.status == "completed"' "$SESSION_DIR/fix-status.json"
```

**Phase Report (`Phase7-report.md`):** Báo cáo tổng kết cuối cùng.

**On Failure:** E070 (CQG-1 mismatch) → Retry x3 → E001. E071 (CQG-2 fail) → CDG render.

**Next Step:** `/wf-verify-sync` hoặc `/status`

---

### 4.8 Resume & Status

**File:** `procedures/resume-status.md`
**Mục đích:** Xử lý `--status` (hiển thị trạng thái) và `--resume` (resume từ checkpoint).

**--status Handler:**
1. Đọc `fix-status.json` → hiển thị trạng thái từng phase (completed/in_progress/pending/failed)
2. Hiển thị CI tools status
3. Hiển thị session info (SESSION_ID, scope, profile, dimensions)
4. Hiển thị summary metrics (signals found, bugs fixed)
5. Gợi ý next action

**--resume Handler:**
1. Đọc `fix-status.json` → tìm phase cuối cùng có status = `completed`
2. Đọc `session-log.json` → xác định checkpoint gần nhất
3. Kiểm tra stale (E013: >30% stale → WARN)
4. Route tới phase tiếp theo (phase sau completed cuối cùng)
5. Nếu phase đang `in_progress` → re-run phase đó từ đầu (step-level resume not supported)
6. Nếu `pipeline_status = DONE` → E005: "Pipeline đã hoàn thành. Re-run?"

---

## 5. Templates

### 5.1 Template Inventory

| # | Template | Output Path | Phase |
|---|----------|------------|-------|
| | **Phase 1 Init** | | |
| 1 | `templates/phase1-init/fix-status.json` | `$SESSION_DIR/fix-status.json` | 1 |
| 2 | `templates/phase1-init/Phase1-report.md` | `$SESSION_DIR/phase1-init/Phase1-report.md` | 1 |
| | **Phase 2 Scan** | | |
| 3 | `templates/phase2-scan/scope-analysis.json` | `$SESSION_DIR/phase2-scan/scope-analysis.json` | 2 |
| 4 | `templates/phase2-scan/code-inventory.json` | `$SESSION_DIR/phase2-scan/code-inventory.json` | 2 |
| 5 | `templates/phase2-scan/doc-inventory.json` | `$SESSION_DIR/phase2-scan/doc-inventory.json` | 2 |
| 6 | `templates/phase2-scan/Phase2-report.md` | `$SESSION_DIR/phase2-scan/Phase2-report.md` | 2 |
| | **Phase 3 Plan** | | |
| 7 | `templates/phase3-plan/work-plan.json` | `$SESSION_DIR/phase3-plan/work-plan.json` | 3 |
| 8 | `templates/phase3-plan/dimension-plan.json` | `$SESSION_DIR/phase3-plan/dimension-plan.json` | 3 |
| 9 | `templates/phase3-plan/fix-workload.json` | `$SESSION_DIR/phase3-plan/workloads/W{N}/fix-workload.json` | 3 |
| 10 | `templates/phase3-plan/Phase3-report.md` | `$SESSION_DIR/phase3-plan/Phase3-report.md` | 3 |
| | **Phase 4 Find Bugs** | | |
| 11 | `templates/phase4-find-bugs/lane-signals.json` | `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}/{static-scan,runtime,llm-scan}/signals.json` | 4 |
| 12 | `templates/phase4-find-bugs/lane-status.json` | `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}/lane-status.json` | 4 |
| 13 | `templates/phase4-find-bugs/QD-report.md` | `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}/QD{n}-report.md` | 4 |
| 14 | `templates/phase4-find-bugs/Phase4-report.md` | `$SESSION_DIR/phase4-find-bugs/Phase4-report.md` | 4 |
| | **Phase 5 Triage** | | |
| 15 | `templates/phase5-triage/issue-registry.json` | `$SESSION_DIR/phase5-triage/issue-registry.json` | 5 |
| 16 | `templates/phase5-triage/bug-triage.md` | `$SESSION_DIR/phase5-triage/bug-triage.md` | 5 |
| 17 | `templates/phase5-triage/fix-plan.md` | `$SESSION_DIR/phase5-triage/fix-plan.md` | 5 |
| 18 | `templates/phase5-triage/fix-log.json` | `$SESSION_DIR/phase5-triage/fix-log.json` | 5 |
| 19 | `templates/phase5-triage/cdg-tokens.json` | `$SESSION_DIR/phase5-triage/cdg-tokens.json` | 5 |
| 20 | `templates/phase5-triage/safety-check.json` | `$SESSION_DIR/phase5-triage/safety-check.json` | 5 |
| 21 | `templates/phase5-triage/process-violations.json` | `$SESSION_DIR/phase5-triage/process-violations.json` | 5 |
| 22 | `templates/phase5-triage/coverage-report.md` | `$SESSION_DIR/phase5-triage/coverage-report.md` | 5 |
| 23 | `templates/phase5-triage/Phase5-report.md` | `$SESSION_DIR/phase5-triage/Phase5-report.md` | 5 |
| | **Phase 6 Execute** | | |
| 24 | `templates/phase6-execute/fix-report.md` | `$SESSION_DIR/phase6-execute/fix-report.md` | 6 |
| 25 | `templates/phase6-execute/docs-sync-report.json` | `$SESSION_DIR/phase6-execute/docs-sync-report.json` | 6 |
| 26 | `templates/phase6-execute/Phase6-report.md` | `$SESSION_DIR/phase6-execute/Phase6-report.md` | 6 |
| | **Phase 7 Verify** | | |
| 27 | `templates/phase7-verify/orchestrator-summary.md` | `$SESSION_DIR/phase7-verify/orchestrator-summary.md` | 7 |
| 28 | `templates/phase7-verify/fix-impact.json` | `$SESSION_DIR/phase7-verify/fix-impact.json` | 7 |
| 29 | `templates/phase7-verify/phase-summary.md` | `$SESSION_DIR/phase7-verify/phase-summary.md` | 7 |
| 30 | `templates/phase7-verify/Phase7-report.md` | `$SESSION_DIR/phase7-verify/Phase7-report.md` | 7 |
| | **_Common** | | |
| 31 | `templates/_common/session-log.json` | `$SESSION_DIR/session-log.json` | All |
| 32 | `templates/_common/error-ledger.json` | `$SESSION_DIR/error-ledger.json` | All |

### 5.2 Placeholder Convention

| File type | Pattern | Ví dụ |
|-----------|---------|-------|
| JSON templates | `{{VAR_NAME}}` | `"session_id": "{{SESSION_ID}}"` |
| Markdown templates | `[VAR_NAME]` | `# Phase Report: [PHASE_NAME]` |
| JSON legacy (v9.x) | Empty strings / 0 / [] | Populate by jq field assignment |

---

## 6. SKILL.md — Lean Routing Hub

Tham chiếu mẫu: wf-legacy-scan/SKILL.md (391 dòng).

### 6.1 Cấu trúc

```
---
frontmatter (name, version, description, argument-hint, etc.)
---

# /wf-fix-bugs: $ARGUMENTS

## Overview                            (~20 dòng)
## Arguments                           (~30 dòng — bảng flags + mô tả)

## Protocols                           (~10 dòng — protocol references)

## CI PRE-GATE (Protocol 20 §20.8)     (~20 dòng — Na/Nb/Nc steps + CI-ROUTE table)

## Phase Routing Map (lazy-loaded)     (~30 dòng — bảng 7 phase + routing flow diagram)

## Phase Summary (condensed)           (~100 dòng — 1 dòng/step per phase)

## CI-ROUTE: Orchestrator Stages       (~20 dòng — task→tool matrix cho orchestrator)

## Playwright Integration              (~15 dòng — headless/visible/mobile modes)

## Fix Rules                           (~10 dòng — auto-fix strategy table)
## Error Handling                      (~70 dòng — namespace + quick lookup table)
## Output Files                        (~50 dòng — 2 bảng: session-scoped + standard)

## Next Step                           (~5 dòng)
## Related Skills                      (~10 dòng)
## References                          (~10 dòng — procedure files + templates + protocols)
```

**Tổng: ~350 dòng, 0 code thực thi.**

### 6.2 Playwright Section

```markdown
## Playwright Integration

| Mode | Flag | Behavior |
|------|------|----------|
| **Headless** (default) | — | Chromium headless, invisible. Session-isolated via `playwright-session.js`. |
| **Visible** | `--show-browser` | Chromium visible window for debugging + user observation. |
| **Mobile** | `--mobile` | Playwright device emulation (iPhone 14, Pixel 7, iPad Pro). Auto-sets `--show-browser`. |

Playwright runs SEQUENTIALLY across lanes (max 1 browser instance globally).
Priority: QD9 → QD5 → QD7 → others. Mobile apps auto-use device emulation.

CI-ROUTE for browser tasks: GitNexus trace navigation + Serena find auth handlers.
```

---

## 7. Kế Hoạch Triển Khai

### 7.1 13 Sprints

| Sprint | Nội dung | Files | Est. |
|--------|---------|-------|------|
| **S0** | Tạo 30+ template files (nền tảng cho mọi output) | 32 files mới | 3-4h |
| **S1** | Tạo `procedures/_shared.md` (17 sections — thêm §17 Playwright) | 1 file mới | 3-4h |
| **S2** | Tạo `procedures/phase1-init.md` (23 steps + CI PRE-GATE Na/Nb/Nc) | 1 file mới | 3-4h |
| **S3** | Tạo `procedures/phase2-scan.md` (scan + interface_type + CI-ROUTE) | 1 file mới | 3-4h |
| **S4** | Tạo `procedures/phase3-plan.md` (ISG + partition + workload gate + Playwright plan) | 1 file mới | 2-3h |
| **S5** | Tạo `procedures/phase4-find-bugs.md` (PARALLEL max 10 + Playwright SEQUENTIAL + Agent prompt) | 1 file mới | 4-5h |
| **S6** | Tạo `procedures/phase5-triage.md` (aggregate + integrity + triage + CDG + safety) | 1 file mới | 3-4h |
| **S7** | Tạo `procedures/phase6-execute.md` (CI impact + execute spawn) | 1 file mới | 1-2h |
| **S8** | Tạo `procedures/phase7-verify.md` (CQG-1/2 + mobile gate + summaries) | 1 file mới | 2-3h |
| **S9** | Tạo `procedures/resume-status.md` (merge resume + status handlers) | 1 file mới | 2-3h |
| **S10** | Viết lại `SKILL.md` — lean routing hub ~350 dòng | 1 file sửa | 2-3h |
| **S11** | Cập nhật `_contract.json` (paths + templates + new flags) | 1 file sửa | 1-2h |
| **S12** | Xóa 17 file cũ, migrate scripts tham chiếu paths mới | Cleanup | 1h |
| **S13** | Validate: compliance audit + schema sync + regression tests + Playwright smoke test | Validation | 2-3h |
| **Tổng** | | **13 sprints, 32 templates, 9 procedure files** | **~32-45h** |

### 7.2 Thứ tự triển khai

```
S0 (templates/) ── nền tảng cho mọi phase
  │
  ▼
S1 (_shared.md) ── SSOT cho mọi phase
  │
  ├── S2 (phase1-init.md) ── S3 (phase2-scan.md) ── S4 (phase3-plan.md)
  │                                                      │
  │                                                      ▼
  ├── S5 (phase4-find-bugs.md) ── S6 (phase5-triage.md) ── S7 (phase6-execute.md)
  │                                                      │
  │                                                      ▼
  └── S8 (phase7-verify.md) ── S9 (resume-status.md)
                                    │
                                    ▼
                      S10 (SKILL.md) ── S11 (_contract.json) ── S12 (cleanup) ── S13 (validate)
```

---

## 8. Tiêu Chí Thành Công

| # | Tiêu chí | Đo lường |
|---|---------|---------|
| 1 | Mọi phase file có PRE-GATE → Steps → POST-GATE (T1-T4) → Phase Report → Next Phase | Visual inspection |
| 2 | `_shared.md` 17 sections — SSOT cho error codes, state variables, atomic write, CI, Playwright | Không duplicate định nghĩa |
| 3 | SKILL.md ≤ 400 dòng, **KHÔNG chứa code thực thi** | `wc -l` |
| 4 | Error codes namespace theo 10 ranges | Grep error codes |
| 5 | 9 procedure files (8 phase + resume-status) | `ls procedures/ | wc -l` |
| 6 | Mọi output file tạo qua CORE-031 (READ template → POPULATE → WRITE) | Audit Write/Edit calls |
| 7 | Mọi shared state file dùng Atomic Write Pattern | Audit jq + tmp + mv |
| 8 | Phase 4 PARALLEL max 10 agents, Playwright SEQUENTIAL 1 instance | Code inspection |
| 9 | Mỗi Phase có Phase{N}-report.md | File existence |
| 10 | Mỗi Agent trong Phase 4 có {DIM}-report.md | File existence |
| 11 | CI PRE-GATE 3-step (Na/Nb/Nc) trong Phase 1, CI-ROUTE trong mọi phase | Code inspection |
| 12 | Playwright headless mặc định, --show-browser cho visible, --mobile cho device emulation | Flag behavior test |
| 13 | interface_type detection (web/mobile/api-only/hybrid) trong Phase 2 | Detection logic |
| 14 | Early-exit E005 từ Phase 5 → jump Phase 7 | Flow diagram match |
| 15 | --resume hoạt động với state contract + phase inheritance | Test cases |
| 16 | _contract.json validate qua `validate-schema-sync.sh` | Script pass |
| 17 | Templates ≥30 files, bao phủ mọi output | `find templates/ -type f | wc -l` |

---

## 9. Rủi Ro & Giảm Thiểu

| Rủi ro | Impact | Mitigation |
|--------|--------|-----------|
| Phase subdirectories thay đổi output paths → break downstream consumers | High | Ánh xạ path cũ→mới trong `_contract.json`. Downstream đọc qua contract. |
| 32 templates cần maintain | Medium | Templates tổ chức theo phase, mỗi template có schema comment. `validate-schema-sync.sh` verify. |
| Phase 2 (Scan) là logic mới hoàn toàn | Medium | Bắt đầu đơn giản: scan code structure + docs inventory. CI-ROUTE fallback Grep/Glob. |
| Phase 4 max 10 agents → token cost cao | Medium | Cost CDG (E092) cảnh báo trước. User chọn profile thấp hơn. |
| Playwright headless/visible/mobile thêm complexity | Medium | Playwright đã hoạt động trong QD9 v1.0. Mở rộng flag-based, không thay đổi cốt lõi. |
| Mobile device emulation chưa từng test trên production project | Medium | Feature gate: `--mobile` là opt-in. Fallback desktop viewport nếu fail (E045). |
| Migration từ v9.2.0 → v10.0 | High | Giữ nguyên bash scripts (`scripts/wf-fix-*.sh`), Python modules (`_shared/`). Chỉ thay đổi procedure files + output paths. |
| CI tools unavailable trên target project | Low | Graceful degradation Grep/Glob (Protocol 20 §20.6). Zero regression. |

---

## 10. Flags Mới

| Flag | Mô tả | Phase ảnh hưởng |
|------|-------|----------------|
| `--show-browser` | Chạy Playwright visible (default: headless) | 1 (CDG), 4 (runtime probes) |
| `--mobile` | Kích hoạt Playwright device emulation (iPhone 14, Pixel 7, iPad Pro). Auto-set `--show-browser`. | 1 (CDG), 2 (interface_type), 4 (runtime probes), 7 (mobile gate) |

### 10.1 Mobile Device Defaults

| Device | Viewport | Pixel Ratio | User Agent |
|--------|----------|-------------|------------|
| **iPhone 14** | 390×844 | 3 | Mobile Safari iOS 16 |
| **Pixel 7** | 412×915 | 2.625 | Chrome Android |
| **iPad Pro** | 1024×1366 | 2 | Mobile Safari iPadOS 16 |

User có thể chọn 1 device hoặc "all" (chạy tuần tự 3 devices). Mỗi device là 1 Playwright context riêng, session-isolated.

---

## 11. Tham Chiếu

| Tài liệu | Path |
|---------|------|
| Ý tưởng người dùng | `docs/architect-skill/wf-fix-bugs-idea.md` |
| wf-legacy-scan SKILL.md (reference architecture) | `.claude/skills/workflow/wf-legacy-scan/SKILL.md` |
| wf-legacy-scan _shared.md (reference SSOT) | `.claude/skills/workflow/wf-legacy-scan/procedures/_shared.md` |
| wf-fix-bugs v9.2.0 SKILL.md | `.claude/skills/workflow/wf-fix-bugs/SKILL.md` |
| wf-fix-bugs v9.2.0 _contract.json | `.claude/skills/workflow/wf-fix-bugs/_contract.json` |
| wf-fix-runtime-health v1.0.0 (Playwright reference) | `.claude/skills/workflow/wf-fix-runtime-health/SKILL.md` |
| Protocol 20 — Code Intelligence | `.claude/skills/protocols/20-code-intelligence.md` |
| Protocol 19 — Template Usage Rule | `.claude/skills/protocols/19-template-usage.md` |
| Protocol 16 — Critical Decision Gate | `.claude/skills/protocols/16-critical-decision-gate.md` |
| Protocol 10 — POST-GATE Schema | `.claude/skills/protocols/10-post-gate-schema.md` |
| Protocol 9 — Task Planning | `.claude/skills/protocols/09-task-planning.md` |
| Core Rules | `.claude/rules/00-core.md` |
| Behavioral Principles | `.claude/rules/00-behavioral.md` |
