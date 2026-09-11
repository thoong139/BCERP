# 03 — Kiến Trúc (Pipeline 7-Phase + Lazy-Load + CI-First + Playwright)

> **Đọc trước:** [02-quality-dimensions.md](02-quality-dimensions.md)
> **Đọc tiếp:** [04-contracts-data-model.md](04-contracts-data-model.md)
> **Trạng thái:** v2.0 · Phản ánh skill `wf-fix-bugs v10.18.0` (2026-05-16)
> **Tiền thân:** [99-archive/wf-fix-bugs-design-v1.0/03-architecture.md](../../99-archive/wf-fix-bugs-design-v1.0/03-architecture.md) (v6 dimension-based pipeline tuyến tính)

---

## 1. Bản Đồ Tổng Thể (v10.x)

```
┌─────────────────────────────────────────────────────────────────────┐
│  /wf-fix-bugs $ARGUMENTS                                            │
│                                                                     │
│            ┌───────────────────────────────────────┐                │
│            │  SKILL.md (~540 dòng lean router)     │                │
│            │  Parse args → Route to phase          │                │
│            └────────────────────┬──────────────────┘                │
│                                 │                                   │
│                                 ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  PHASE 1: Init (18 steps, 7 groups)                         │    │
│  │  - CLI parse + LEGACY_MODE detect                           │    │
│  │  - CI PRE-GATE Na/Nb/Nc (Protocol 20)                       │    │
│  │  - Session + lock + heartbeat                               │    │
│  │  - ISG fast-path → DIMS_ARRAY                               │    │
│  │  - Bundle: state files + bug-dashboard (parallel)           │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                 │                                   │
│                                 ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  PHASE 2: Scan (5 steps)                                    │    │
│  │  - Interface detect (web/mobile/hybrid/api-only)            │    │
│  │  - Code inventory (CI-ROUTE: Serena/GitNexus/Glob)          │    │
│  │  - Doc inventory (req-registry + .mc-data/docs/)            │    │
│  │  - Scope analysis                                           │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                 │                                   │
│                                 ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  PHASE 3: Plan (7 steps, 6 groups)                          │    │
│  │  - ISG + Partition Planner                                  │    │
│  │  - Workload Gate CDG-11 (INLINE AskUserQuestion)            │    │
│  │  - Route 11 dims → lanes                                    │    │
│  │  - Write work-plan + dimension-plan                         │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                 │                                   │
│                                 ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  PHASE 4: Find Bugs (9 steps, 7 groups + POST-GATE)         │    │
│  │  - Browser CDG E090/E090b (INLINE)                          │    │
│  │  - Create lane dirs + render N prompts                      │    │
│  │  - Verify prompt (6-check anti-fantasy)                     │    │
│  │  - **PARALLEL** N×Agent({subagent_type:"claude"}) ≤10       │    │
│  │  - Monitor + validate POST-GATE T1-T4                       │    │
│  │  - Generate Phase4-report.md + phase4-summary.json (v10.10) │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                 │                                   │
│                                 ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  PHASE 5: Triage (10 steps, 7 groups)                       │    │
│  │  - E005 healthy check (N=0 → jump Phase 7)                  │    │
│  │  - Aggregate + Spot-check + PI1-PI5 integrity               │    │
│  │  - CDG critical violations (CONTINUE/ABORT)                 │    │
│  │  - **Spawn `wf-fix-triage`** (Agent delegation)             │    │
│  │  - CDG Pre-Execute (ACCEPT/REJECT/CANCEL)                   │    │
│  │  - Safety Check 4-point (CORE-020)                          │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                 │                                   │
│                                 ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  PHASE 6: Execute (7 steps, 7 groups)                       │    │
│  │  - Dry-run preview (skip nếu --dry-run)                     │    │
│  │  - CI impact analysis (GitNexus impact())                   │    │
│  │  - CDG HIGH/CRITICAL risk                                   │    │
│  │  - **Spawn `wf-fix-execute`** (Agent delegation)            │    │
│  │  - Validate POST-GATE T1-T5 + dashboard update              │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                 │                                   │
│                                 ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  PHASE 7: Verify (8 steps, 7 groups)                        │    │
│  │  - CQG-1 Numeric (deviation ≤5% expected vs actual)         │    │
│  │  - CQG-2 Browser+Integration (INLINE CDG REJECT)            │    │
│  │  - Mobile gate + dashboard finalize                         │    │
│  │  - Generate 4 reports (orchestrator-summary, fix-impact,    │    │
│  │    phase-summary, Phase7-report)                            │    │
│  │  - fix-impact.json audit_chain sha256 (CORE-036)            │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                 │                                   │
│                                 ▼                                   │
│                            Pipeline DONE                            │
│              → /wf-verify-sync --from-fix-bugs → /status            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Quy Ước Phân Loại Phase

| Phase | Steps | Mode | Spawn agents? | Critical Gates |
|-------|-------|------|---------------|----------------|
| **1 Init** | 18 | HYBRID (2 parallel waves) | Không | CI PRE-GATE Na/Nb/Nc; POST-GATE T1-T4 |
| **2 Scan** | 5 | HYBRID (script delegation) | Không | POST-GATE T1-T4 (3 inventory + interface_type) |
| **3 Plan** | 7 | HYBRID (script + CDG-11 INLINE) | Không | CDG-11 Workload; POST-GATE T1-T4 |
| **4 Find Bugs** | 9 | **PARALLEL** (max 10) | **YES** (lane agents) | E090/E090b Browser CDG; E040-E049 lane errors; POST-GATE T1-T4 |
| **5 Triage** | 10 | Agent Delegation + INLINE CDG | **YES** (wf-fix-triage) | E005 healthy; CDG Pre-Execute; Safety Check |
| **6 Execute** | 7 | Agent Delegation + INLINE CDG | **YES** (wf-fix-execute) | CDG HIGH/CRITICAL; POST-GATE T1-T5 + retry x1 |
| **7 Verify** | 8 | SEQUENTIAL (script + INLINE CDG) | Không | CQG-1 Numeric (5% threshold); CQG-2 Browser+Integration; CDG REJECT missing QD9/QD10 evidence |

---

## 3. Lazy-Load Procedures (CORE-032)

> **Triết lý:** SKILL.md là **lean routing hub** (≤500 dòng), KHÔNG chứa code thực thi. Toàn bộ logic chi tiết nằm trong `procedures/phase{N}-{name}.md` (index router) + `procedures/phase{N}-{name}/X-{group}.md` (group sub-files). Orchestrator load TỪNG group khi tới execution.

### 3.1 Cấu Trúc Thư Mục

```
.claude/skills/workflow/wf-fix-bugs/
├── SKILL.md                                      # ~540 dòng lean router
├── _contract.json                                # Skill contract (43 outputs, 50 errors, 2 orchestrates)
├── procedures/
│   ├── _shared.md                                # 30-dòng redirect (backward-compat)
│   ├── _shared/                                  # 21 protocol files
│   │   ├── README.md                             # Index + per-phase load profile
│   │   ├── 01-state-vars.md → 21-atomic-call-wrapper.md
│   ├── _optimization-playbook.md                 # 10 techniques T1-T10
│   ├── phase1-init.md                            # Phase 1 INDEX (~80 dòng)
│   ├── phase1-init/                              # Group sub-files
│   │   ├── A-bootstrap.md
│   │   ├── B-wave1.md (CI + Registry + Paths PARALLEL)
│   │   ├── C-decision.md
│   │   ├── D-session-setup.md
│   │   ├── E-isg.md
│   │   ├── F-wave4.md (init-state + dashboard PARALLEL)
│   │   ├── G-finalize.md
│   │   └── POST-GATE.md
│   ├── phase2-scan.md                            # Phase 2 (5 steps, KHÔNG split — grandfathered)
│   ├── phase3-plan.md                            # Phase 3 INDEX
│   ├── phase3-plan/                              # 6 group files + POST-GATE
│   ├── phase4-find-bugs.md                       # Phase 4 INDEX (~135 dòng)
│   ├── phase4-find-bugs/                         # 7 group files + POST-GATE
│   ├── phase5-triage.md                          # Phase 5 INDEX
│   ├── phase5-triage/                            # 7 group files + POST-GATE
│   ├── phase6-execute.md                         # Phase 6 INDEX
│   ├── phase6-execute/                           # 7 group files + POST-GATE
│   ├── phase7-verify.md                          # Phase 7 INDEX
│   ├── phase7-verify/                            # 7 group files + POST-GATE
│   └── resume-status.md                          # --resume + --status handlers
├── templates/                                    # 38 templates
│   ├── _common/                                  # session-log, error-ledger
│   ├── phase1-init/ → phase7-verify/             # Per-phase templates
└── evals/                                        # 73 evals + regression tests
```

### 3.2 Per-Phase Context Saving

| Phase | Monolithic (cũ) | Lazy-load (v10.x) | Saving |
|-------|------------------|--------------------|---------|
| Phase 1 | 1106 dòng / ~9K tokens | 80-dòng index + 8 groups (load 500-1200/group) | **-83%** initial |
| Phase 3 | 515 dòng / ~5K tokens | 80-dòng index + 6 groups | **-85%** initial |
| Phase 4 | 782 dòng / ~8K tokens | 135-dòng index + 7 groups + POST-GATE | **-85%** initial |
| Phase 5 | 648 dòng / ~7K tokens | 135-dòng index + 7 groups + POST-GATE | **-85%** initial |
| Phase 6 | 619 dòng / ~6K tokens | 90-dòng index + 7 groups + POST-GATE | **-85%** initial |
| Phase 7 | 657 dòng / ~6.5K tokens | 120-dòng index + 7 groups + POST-GATE | **-85%** initial |
| **Peak per phase** | **~19K tokens** | **~2.5K tokens** | **-87%** |

> Phase 2 KHÔNG split (5 steps, <300 dòng — grandfathered per T6 rule).

### 3.3 Routing Pattern

```
Orchestrator workflow per phase:
  1. Read procedures/phase{N}-{name}.md (index ~80-140 dòng)
  2. Verify PRE-GATE
  3. Đọc procedures/phase{N}-{name}/A-{group}.md → execute → Group A POST-GATE
  4. Đọc procedures/phase{N}-{name}/B-{group}.md → execute → Group B POST-GATE
  5. ... (incremental load per group)
  6. Đọc procedures/phase{N}-{name}/POST-GATE.md → validate T1-T4/T5
  7. Update fix-status.phase{N}.status = "completed"
  8. Advance Phase {N+1}
```

**Quy tắc:**
- KHÔNG đọc trước tất cả group files — chỉ load khi tới group đó
- Mỗi group file có "Next Group" pointer ở cuối → orchestrator route theo
- Phase có branching (vd: Phase 6 DRY_RUN → skip C/D/E → F) follow pointer
- Resume scenario: đọc index → đọc POST-GATE.md §Resume Logic → route vào group cuối cùng completed

---

## 4. Shared Protocols Split (CORE-032 + T5)

> **Triết lý:** `_shared.md` (1227 dòng monolithic, ~10K tokens) split thành 21 file riêng trong `_shared/` (lazy-load per use-site). Mỗi phase chỉ load 1-4 section cần thiết.

### Per-Phase Load Profile

| Phase | Sections cần | Lines load | vs monolithic | Saving |
|-------|--------------|------------|---------------|--------|
| Phase 1 | §13 lock-heartbeat + §19 bug-dashboard | ~115 | -1112 | **-91%** |
| Phase 2 | §7 execution-trace | ~40 | -1187 | **-97%** |
| Phase 3 | §13 (lock-only) | ~45 | -1182 | **-96%** |
| Phase 4 | §15 agent-prompts + §18 playwright + §20 cdg-tokens + §16 sub-probe | ~390 | -837 | **-68%** |
| Phase 5 | §15 (Triage) + §20 (CDG-PRE-EXECUTE) | ~170 | -1057 | **-86%** |
| Phase 6 | §15 (Execute) + §20.1 (verify accepted) | ~150 | -1077 | **-88%** |
| Phase 7 | §6 on-failure + §19 bug-dashboard | ~100 | -1127 | **-92%** |

> Chi tiết: [`_shared/README.md`](../../.claude/skills/workflow/wf-fix-bugs/procedures/_shared/README.md).

---

## 5. CI-First Integration (CORE-033 + Protocol 20)

> **Triết lý:** Auto-detect GitNexus + Serena ở Phase 1 Init. Lock held / index stale / tool absent → fallback Grep/Glob. KHÔNG hỏi user.

### CI PRE-GATE (3 steps, Phase 1)

| Step | Action | Output |
|------|--------|--------|
| **Na** | `bash .claude/scripts/ci-detect.sh` | `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE` |
| **Nb** | `bash .claude/scripts/ci-freshness-check.sh` | `$FRESHNESS_STATUS` ∈ {ok, light, strong, severe} |
| **Nc** | `bash .claude/scripts/ci-inject-context.sh` | `$CI_CONTEXT` string cho spawned agents |

### CI-ROUTE Matrix

| Stage | CI Task | Primary | Secondary | Fallback |
|-------|---------|---------|-----------|----------|
| **Scan** | `project_structure` | Serena `onboarding` | GitNexus `clusters` | Glob |
| **Scan** | `understand_flow` | GitNexus `query({key_concept})` | Serena `get_symbols_overview` | Grep + Read |
| **Scan** | `find_by_annotation` | GitNexus `cypher` + Serena `find_refs` | — | Grep REQ-ID |
| **Scan** | `api_routes` | GitNexus `route_map` | — | Grep |
| **Execute** | `impact_analysis` | GitNexus `impact({target})` | — | Grep |
| **Pre-commit** | `detect_changes` | GitNexus `detect_changes()` | — | `git diff --stat` |

### Cache TTL

| Tool | Available TTL | Absent TTL |
|------|--------------|------------|
| GitNexus | 24h | 4h |
| Serena | 24h | 1h |

Cache location: `.mc-data/work/_meta/code-intelligence.json`. Concurrency: lock-protected write (60s stale timeout). Lock held → fallback Grep (không block).

---

## 6. Phase Output Organization (CORE-035)

> Session subdirectories `phase{N}-{name}/` cô lập output mỗi phase + chuẩn hoá Phase{N}-report.md.

### Session Structure

```
.mc-data/work/wf-fix-bugs/sessions/{SESSION_ID}/
├── .lock                                # Lock + heartbeat daemon
├── fix-status.json                      # SSOT pipeline state (Atomic Write)
├── session-log.json                     # Execution trace (CORE-026, APPEND-only)
├── error-ledger.json                    # Error tracking (CORE-034, APPEND-only)
├── bug-dashboard.md                     # Cross-phase shared state (1/5/6/7 writers)
├── cdg-tokens.json                      # CDG decisions persist (Phase 1/4/5)
├── phase1-init/
│   └── Phase1-report.md
├── phase2-scan/
│   ├── scope-analysis.json              # schema scope-analysis-v2
│   ├── code-inventory.json              # schema code-inventory-v1
│   ├── doc-inventory.json               # schema doc-inventory-v1
│   └── Phase2-report.md
├── phase3-plan/
│   ├── work-plan.json
│   ├── dimension-plan.json
│   ├── workloads/W{N}/fix-workload.json
│   └── Phase3-report.md
├── phase4-find-bugs/
│   ├── lanes/QD{n}-{slug}/              # 1 dir per dimension lane
│   │   ├── lane-status.json
│   │   ├── static-scan/signals.json
│   │   ├── runtime/signals.json
│   │   ├── llm-scan/signals.json        # QD2, QD11
│   │   └── QD{n}-report.md
│   ├── Phase4-report.md
│   ├── phase4-summary.json              # schema phase4-summary-v1 (CORE-036 cross-skill)
│   └── probe-failures-log.json
├── phase5-triage/
│   ├── issue-registry.json
│   ├── bug-triage.md
│   ├── fix-plan.md
│   ├── fix-log.json
│   ├── safety-check.json
│   ├── process-violations.json          # PI1-PI5 check
│   ├── coverage-report.{md,json}        # schema coverage-report-v1
│   └── Phase5-report.md
├── phase6-execute/
│   ├── fix-report.md
│   ├── docs-sync-report.json            # schema docs-sync-report-v2
│   ├── fix-execution-result.json        # schema fix-execution-result-v2
│   └── Phase6-report.md
└── phase7-verify/
    ├── orchestrator-summary.md          # CORE-028 tiếng Việt ≤40 dòng
    ├── fix-impact.json                  # schema fix-impact-v1 (CORE-036 cross-skill)
    ├── phase-summary.md                 # Gộp head 8 dòng × 7 phase
    └── Phase7-report.md                 # CORE-028 tiếng Việt ≤15 dòng
```

### Phase{N}-report.md Format (CORE-028, tiếng Việt, ≤15 dòng)

```markdown
## Phase [N]: [Tên phase] — PASS|FAIL
Thời gian: [ISO-8601]
**Đã làm:** [1-2 câu]
**Kết quả:** [Số liệu chính] + [File đầu ra]
**Tiếp theo:** [Phase kế tiếp hoặc hành động user]
```

**Quy tắc:** KHÔNG dùng jargon kỹ thuật — viết cho người không chuyên.

### Atomic Write Pattern (mọi JSON state file)

```bash
TMP="$TARGET.tmp.$$"
jq <filter> "$SOURCE" > "$TMP" && jq '.' "$TMP" >/dev/null && mv "$TMP" "$TARGET"
```

---

## 7. Agent Dispatch (CORE-037 — 8 Sections Required)

Mọi agent prompt PHẢI có 8 sections:

| # | Section | Mục đích |
|---|---------|---------|
| 1 | **Role declaration** | "Bạn là [role] cho [skill]" |
| 2 | **Task instruction** | "Đọc file [SKILL.md path] và thực thi đầy đủ" |
| 3 | **Session context** | `$SESSION_DIR`, `$PROFILE`, `$SCOPE`, `$NAME` |
| 4 | **CI context injection** | `$CI_CONTEXT` (nếu CI available) |
| 5 | **Playwright context** | mode (`headless/visible/mobile`), devices, base URL |
| 6 | **Output contract** | path cụ thể + schema reference |
| 7 | **Ownership rules** | 1 file = 1 writer, KHÔNG ghi đè |
| 8 | **Completion criteria** | "Outputs PHẢI pass POST-GATE T1-T4" |

### Spawn Rules (CORE-025)

- `subagent_type` = `"claude"` (chỉ "claude" có đủ MCP tools)
- `model` = `"opus"` (Sonnet hết quota → bắt buộc opus)
- Max concurrency: 10 (harness limit)
- 1 file = 1 writer (Safe-Write Protocol)
- Phase 4 N×Agent({...}) trong **MỘT response duy nhất** (single-response parallel) — gửi riêng lẻ sẽ tuần tự

### Phase 4 PARALLEL Lane Dispatch

```
Orchestrator response duy nhất:
  Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-functional ..."})
  Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-business ..."})
  Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-security ..."})
  Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-performance ..."})
  Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-ux-a11y ..."})
  Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-data ..."})
  Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-compat ..."})
  Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-observability ..."})
  Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-runtime-health ..."})  // Playwright
  Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-integration ..."})
  // N=11: 11th queued automatically (harness max 10)
```

### Playwright Serialization

Lane agent có Playwright (QD5/QD7/QD9) TỰ acquire writer-lock `playwright` qua `global-rw-lock.sh` (Protocol 22) — orchestrator KHÔNG split wave. Lock release sau khi lane complete.

---

## 8. Context Budget Management (CORE-038)

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint (lưu state files) |
| 80-90% | Lưu checkpoint, STOP sau phase hiện tại → hướng dẫn `--resume` |
| > 90% | **FORCE STOP** (E009) — checkpoint bắt buộc |

### Checkpoint Files Tối Thiểu

- `fix-status.json` — phase hiện tại + next_action
- `session-log.json` — execution trace đến checkpoint
- Current `Phase{N}-report.md`

### Resume Flow

1. Đọc `fix-status.json` → xác định last completed phase
2. Stale check: lock age > 30 min → auto-release
3. Route đến next_action (phase tiếp theo hoặc re-run phase hiện tại nếu interrupt)
4. Re-validate PRE-GATE trước khi tiếp tục

> Chi tiết: [resume-status.md](../../.claude/skills/workflow/wf-fix-bugs/procedures/resume-status.md).

---

## 9. Multi-Session Safety (Protocol 22)

> Cho phép N phiên `wf-fix-bugs` song song trên cùng máy cho module/hệ thống khác nhau.

### Session Isolation

- Mỗi session có `$SESSION_DIR` riêng + `.lock` riêng + heartbeat daemon riêng
- Sessions index: `.mc-data/work/wf-fix-bugs/_index/sessions.jsonl` (APPEND-only JSONL)
- Lock JSON: `{pid, host, started_at}`. R7 lock check PID-aware (kill -0) hoặc mtime fallback

### Cross-Session R/W Lock (Protocol 22)

Khi 2+ session cùng dùng resource shared (Playwright browser, BE/FE/DB):

- **Reader-lock `source`** — Lane đọc code source (multiple readers OK)
- **Writer-lock `playwright`** — Lane chạy Playwright (1 writer at a time, blocks readers)
- **Writer-lock `BE`/`FE`/`DB`** — Lane mutate backend/frontend/database (1 writer at a time)

Implementation: `.claude/scripts/wf-e2e-shared/global-rw-lock.sh`. Lock timeout 30s, retry 3x.

### Multi-Session Scenarios

| Scenario | An toàn? | Lý do |
|----------|---------|-------|
| 2 phiên, BASE_URL khác nhau (`:3000` vs `:4000`) | ✅ | Browser session-isolated qua port + user-data-dir |
| 2 phiên, cùng BASE_URL, test data isolated (multi-tenant) | ⚠️ E090b CDG | Chỉ tiếp tục nếu user chắc chắn isolated |
| 2 phiên, cùng BASE_URL, shared state | ❌ E090b BLOCK | Flaky results — dùng "Đợi" |
| 1 phiên, profile=exhaustive | ✅ | Chạy bình thường |
| N phiên parallel, profile=quick/standard | ✅ | Low CPU/RAM contention |

### Hardening (v10.2)

- Port hash collision: `findFreePort()` retry tự động (max 50 tries)
- BASE_URL conflict: Step 4.3 E090b CDG hỏi user khi phát hiện peer session cùng URL
- Escape hatch: `MCV3_PW_ALLOW_SHARED_URL=1` bypass E090b cho CI/CD

---

## 10. Resume — Phase 4 Selective Archive (v10.18.0)

> **Vấn đề (PB-21):** Phase 4 dispatch 11 parallel lane agents — mỗi lane ~15 phút work + 1 model quota. Wholesale archive khi phase `in_progress` → re-spawn ALL 11 = ~2.7h lost + 11× quota waste.
>
> **Giải pháp:** Selective archive — scan `lanes/QD*/lane-status.json` → archive CHỈ lanes `failed`/`in_progress`, GIỮ `completed`/`skipped` nguyên vẹn.

### Why Critical

- `finalize-phase4.sh` aggregate `signals_total` từ `lanes/QD*/{static-scan,runtime,llm-scan}/signals.json` filesystem scan
- Mất `lanes/QD*/` → aggregate return 0 → `fix-status.signals_total = 0`
- Downstream Phase 5 `setup-triage.sh` thấy 0 signals → trigger E005 healthy path **INCORRECTLY** → SKIP Phase 6/7 → false PASS (bug không được fix nhưng pipeline mark DONE)

### Selective Archive Logic

```bash
# Resume Phase 4 in_progress:
for LANE_DIR in lanes/QD*/; do
  LANE_STATUS=$(jq -r '.status' "$LANE_DIR/lane-status.json")
  case "$LANE_STATUS" in
    completed|skipped)   PRESERVE ;;
    failed|in_progress)  ARCHIVE to lanes-partial-{ts}/ ;;
    *)                   ARCHIVE (invalid status — safety) ;;
  esac
done
```

Phase 4 POST-GATE Resume Logic sau đó skip lanes completed, chỉ re-dispatch pending. Top-level files (`Phase4-report.md`, `phase4-summary.json`, `cdg-tokens.json`) regenerated sau resume.

---

## 11. Optimization Playbook (v10.15 — T1-T10)

> 10 kỹ thuật canonical đúc kết từ Phase 1 v10.11→v10.14, áp dụng tuần tự khi optimize phase mới.

| # | Kỹ thuật | Saving | Risk |
|---|----------|--------|------|
| T1 | Parallel Wave Dispatchers | -30-50% exec time | Low |
| T2 | Fast-Path Bash Bypass | -200-500ms/call | Low |
| T3 | Caching for Idempotent Validations | -50-90% repeat ops | Low |
| T4 | Heavy Inline Bash Extraction | -30-40% procedure size | Low |
| T5 | Shared Protocols Split | -80-95% shared context | Medium |
| T6 | Phase Lazy-Load Split | -83% initial phase context | Medium |
| T7 | Group Banners + Execution Flow Map | (clarity) | Very Low |
| T8 | Smoke Test for Routing Chain | (correctness gate) | Very Low |
| T9 | Cross-Platform Defensive Scripts | (reliability) | Very Low |
| T10 | Versioned Schemas with Audit Trail | (compatibility) | Low |

### Áp Dụng Tuần Tự

1. Đo baseline (`wc -l phaseN.md`, count bash blocks, identify big steps)
2. T9 + T10 — Foundation (defensive scripts + versioned schemas)
3. T4 — Extract heavy inline bash (low risk, immediate -30-40%)
4. T1 — Identify parallel opportunities → wave dispatcher
5. T2 — Identify Python spawns có thể bypass
6. T3 — Identify idempotent validations cần cache
7. T7 — Add group banners + flow map (improve readability)
8. T6 — Split phase >500 dòng (biggest win)
9. T5 — Update shared protocol references nếu cần
10. T8 — Write smoke test, run before commit

### Khi NÀO không áp dụng

- Phase <300 dòng → SKIP T6 (overhead split không đáng)
- 1-2 sub-steps → SKIP T1 (parallel không có ý nghĩa)
- Validation chạy 1 lần/session → SKIP T3 (cache miss rate 100%)
- Python script làm complex logic → SKIP T2 (bash không thể replace)
- User-interaction code (CDG, AskUserQuestion) → SKIP T4 (phải INLINE)

> Chi tiết: [`_optimization-playbook.md`](../../.claude/skills/workflow/wf-fix-bugs/procedures/_optimization-playbook.md).

---

## 12. Cross-Skill Artifact (CORE-036)

> Artifact được skill khác consume PHẢI schema versioned + `audit_chain.checksum_sha256`.

### Artifacts Produced

| Artifact | Schema | Generator | Consumers |
|----------|--------|-----------|-----------|
| `phase4-summary.json` | `phase4-summary-v1` | `generate-phase4-report.sh` | Phase 5 fast-path, Phase 7 CQG-2, external audit |
| `fix-impact.json` | `fix-impact-v1` | `generate-phase7-reports.sh` | `wf-verify-sync`, `wf-prepare-deployment`, `wf-implement-feature`, `wf-cmi` |
| `coverage-report.json` | `coverage-report-v1` | `generate-phase5-reports.sh` | `wf-prepare-deployment` (opt-in) |

### Artifact Schema Template

```json
{
  "$schema": "fix-impact-v1",
  "session_id": "2026-05-16-ALL-fix-bugs-01",
  "skill": "wf-fix-bugs",
  "version": "10.18.0",
  "generated_at": "2026-05-16T10:30:00Z",
  "data": { ... },
  "audit_chain": {
    "source_file": "$SESSION_DIR/phase6-execute/fix-report.md",
    "checksum_sha256": "abc123...",
    "generated_at": "2026-05-16T10:30:00Z",
    "generated_by": "generate-phase7-reports.sh"
  }
}
```

### Artifacts Consumed (with `--from-*` flags)

| Producer Skill | Artifact | When | `--from-*` Flag |
|----------------|----------|------|-----------------|
| `wf-brainstorm` | legacy-decisions.json (CORE-022) | LEGACY_MODE PRE-GATE | (implicit) |
| `wf-legacy-scan` | project-context.md, ledger.json | LEGACY_MODE detection | (implicit) |
| `wf-preflight` | preflight-impact.json | Phase 1 health hint | `--from-preflight` |
| `wf-cmi` | integrity-impact.json | Phase 3 ISG hint | `--from-cmi` |

---

## 13. Critical Decision Gates (CDG — Protocol 16)

Mọi user-facing decision dùng `AskUserQuestion` (INLINE, không delegate script):

| CDG | Where | Trigger | Options |
|-----|-------|---------|---------|
| **CDG-11 Workload** | Phase 3 Step 3.4 | Workload ratio ≥1.5× budget | Chia chunk / Continue full / Cancel |
| **E090 Missing URL** | Phase 4 Step 4.3 | `$URL` chưa set + PW_LANE_COUNT > 0 | Nhập URL / SKIP QD9 / Cancel |
| **E090b BASE_URL Conflict** | Phase 4 Step 4.3 | 2 phiên cùng URL | Tiếp tục risk / Đợi peer / Cancel |
| **CDG Critical Violations** | Phase 5 Step 5.4 | PI1-PI5 critical >0 | CONTINUE / ABORT |
| **CDG Pre-Execute** | Phase 5 Step 5.7 | Trước handoff Phase 6 | ACCEPT / REJECT / CANCEL (REJECT 2 lần → E054) |
| **CDG Safety Blockers** | Phase 5 Step 5.8 | Safety check blocker | Continue / Cancel (REJECT 2 lần → ESCALATE) |
| **CDG HIGH/CRITICAL Risk** | Phase 6 Step 6.3 | GitNexus impact HIGH/CRITICAL | Proceed / Skip target / Cancel |
| **CDG REJECT QD9/QD10** | Phase 7 Step 7.3 | CQG-2 missing evidence | Accept gap / Re-spawn lane / Cancel |

CDG tokens persist vào `cdg-tokens.json` (schema `cdg-tokens-v1`) cho audit trail.

---

## 14. Liên Kết

| Tài liệu | Lý do |
|----------|-------|
| [01-vision-principles.md](01-vision-principles.md) | 11 design principles |
| [02-quality-dimensions.md](02-quality-dimensions.md) | 11 QDs canonical |
| [04-contracts-data-model.md](04-contracts-data-model.md) | Output paths, schemas, error codes |
| [05-execution-profiles.md](05-execution-profiles.md) | 4 profiles × 11 dims |
| [07-tradeoffs-adr.md](07-tradeoffs-adr.md) | ADR-30 (lazy-load), ADR-31 (CI-first), ADR-37 (Playwright), ADR-38 (multi-session), ADR-39 (Playbook), ADR-40 (selective archive) |
| `.claude/skills/workflow/wf-fix-bugs/SKILL.md` | Routing canonical |
| `.claude/skills/protocols/20-code-intelligence.md` | Protocol 20 CI integration |
| `.claude/skills/protocols/22-cross-session-rw-lock.md` | Protocol 22 multi-session lock |
| `.claude/rules/00-core.md` | CORE-032 → CORE-039 |
